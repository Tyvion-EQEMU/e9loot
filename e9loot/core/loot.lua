-- Core loot logic: evaluates items against all list types, dispatches loot/sell/destroy decisions, tracks history

local mq      = require('mq')
local Corpse  = require('e9loot.core.corpse')
local Upgrade = require('e9loot.core.upgrade')
local Logger  = require('e9loot.utils.logger')

local Loot = {}

local _history = {}
local HIST_MAX = 200

local _config
local _lists
local _framework
local _channel
local _logFile   = nil
local _looting   = false  -- re-entrancy guard: prevents overlapping LootNearby calls via mq.delay yields
local _inCombat  = false  -- true while combat suppresses looting; never affects LootEnabled

local DECISION = {
    KEEP    = 'keep',
    BANK    = 'bank',
    SELL    = 'sell',
    DESTROY = 'destroy',
    SKIP    = 'skip',   -- no-drop item we don't want; leave on corpse
    IGNORE  = 'ignore',
}

-----------------------------------------------------------------------
-- Persistent log file (appended each session)
-----------------------------------------------------------------------
local _lootDir = nil
local function e9lootDir()
    if not _lootDir then
        _lootDir = mq.configDir .. '/e9loot'
        local ok, _, code = os.rename(_lootDir, _lootDir)
        if not ok and code ~= 13 then
            os.execute('mkdir "' .. _lootDir .. '"')
        end
    end
    return _lootDir
end

local function openLog()
    local server = mq.TLO.EverQuest.Server():gsub(' ', '_')
    local path = string.format('%s/CharLogs_%s_%s.log', e9lootDir(), server, mq.TLO.Me.CleanName())
    _logFile = io.open(path, 'a')
    if _logFile then
        _logFile:write(string.format('\n=== Session %s ===\n', os.date('%Y-%m-%d %H:%M:%S')))
        _logFile:flush()
    end
end

local function writeLog(toon, decision, name, reason)
    if not _logFile then return end
    _logFile:write(string.format('[%s] %-14s %-8s %s (%s)\n',
        os.date('%Y-%m-%d %H:%M:%S'), toon, decision:upper(), name, reason))
    _logFile:flush()
end

-----------------------------------------------------------------------
-- History (in-memory, shown in the panel)
-----------------------------------------------------------------------
local function pushHistory(entry)
    table.insert(_history, 1, entry)
    if #_history > HIST_MAX then
        table.remove(_history, HIST_MAX + 1)
    end
    writeLog(entry.toon or '?', entry.decision, entry.name, entry.reason or '')
end

-----------------------------------------------------------------------
-- KEEP announcements go to the in-game group channel (/g).
-- All other decisions are silent in MQ chat — history panel and log only.
-----------------------------------------------------------------------
local function announceLoot(decision, name, reason, toon)
    local tag = decision:upper()
    local msg = string.format('e9loot | %s: %s (%s)', tag, name, reason)
    if mq.TLO.Me.Grouped() then
        mq.cmdf('/g %s', msg)
    else
        printf('\age9loot\aw | \a-w[%s]\aw %-7s | %s \a-w(%s)\aw', toon, tag, name, reason)
    end
end

-----------------------------------------------------------------------
-- Item evaluation
-----------------------------------------------------------------------
local function evaluateItem(item)
    if not item or not item.ID() or item.ID() == 0 then
        return DECISION.IGNORE, 'null item'
    end

    local name = item.Name() or ''
    local id   = item.ID()

    -- User override lists take absolute priority over all automated logic
    if _lists.skip    and _lists.skip:Has(name, id)    then return DECISION.SKIP,    'skip-list'    end
    if _lists.destroy and _lists.destroy:Has(name, id) then return DECISION.DESTROY, 'destroy-list' end
    if _lists.keep    and _lists.keep:Has(name, id)    then return DECISION.KEEP,    'keep-list'    end
    if _lists.bank    and _lists.bank:Has(name, id)    then return DECISION.BANK,    'bank-list'    end

    -- Named category lists
    if _lists.sell:Has(name, id)      then return DECISION.SELL, 'sell-list' end
    if _lists.quest:Has(name, id)     then return DECISION.KEEP, 'quest'     end
    if _lists.event:Has(name, id)     then return DECISION.KEEP, 'event'     end
    if _lists.lore:Has(name, id)      then return DECISION.KEEP, 'lore'      end
    if _lists.astrial:Has(name, id)   then return DECISION.BANK, 'astrial'   end
    if _lists.deva:Has(name, id)      then return DECISION.BANK, 'deva'      end
    if _lists.specials:Has(name, id)  then return DECISION.KEEP, 'special'   end
    if _lists.tiered:Has(name, id)    then return DECISION.KEEP, 'tiered'    end
    if _lists.beasts:Has(name, id)    then return DECISION.KEEP, 'beast'     end

    local weaponMode  = _config:Get('WeaponMode')
    local rangedMode  = _config:Get('RangedMode')
    local trashPrice  = _config:Get('TrashPrice')
    local val         = item.Value() or 0
    local isNoDrop    = item.NoDrop() == true

    if item.Stackable() or item.Tradeskills() then
        if trashPrice > 0 and val >= trashPrice * 1000 then return DECISION.SELL, 'trash-sell' end
        if isNoDrop then return DECISION.SKIP, 'nodrop-worthless' end
        return DECISION.SKIP, 'worthless-stack'
    end

    local upgradeSlot = Upgrade.FindUpgradeSlot(item, weaponMode, rangedMode)
    if upgradeSlot ~= nil then
        return DECISION.KEEP, 'upgrade', upgradeSlot
    end
    if weaponMode == 'always' and item.WornSlots() and item.WornSlots() > 0 then
        return DECISION.KEEP, 'upgrade', nil
    end

    -- Not an upgrade: no-drop items can't be picked up to destroy, so leave them
    if isNoDrop then return DECISION.SKIP, 'nodrop-no-upgrade' end

    if trashPrice > 0 and val >= trashPrice * 1000 then return DECISION.SELL, 'sell-value' end

    return DECISION.SKIP, 'no-match'
end

-- Handle the no-drop confirmation dialog that EQ shows when looting a no-drop item.
local function handleNoDropDialog(answer)
    local deadline = mq.gettime() + 1500
    while mq.gettime() < deadline do
        mq.delay(50)
        if mq.TLO.Window('ConfirmationDialogBox').Open() then
            local btn = answer and 'CD_Yes_Button' or 'CD_No_Button'
            mq.cmdf('/notify ConfirmationDialogBox %s leftmouseup', btn)
            mq.delay(100)
            return
        end
    end
end

local function lootSlot(slotIndex)
    local item = mq.TLO.Corpse.Item(slotIndex)
    if not item or not item.ID() or item.ID() == 0 then return end

    local name                         = item.Name() or '(unknown)'
    local isNoDrop                     = item.NoDrop() == true
    local decision, reason, equipSlot  = evaluateItem(item)
    local myToon                       = mq.TLO.Me.CleanName()
    local id                           = item.ID()

    Logger.Debug('%s -> %s (%s)', name, decision, reason)

    if decision == DECISION.IGNORE then return end

    -- SKIP: leave on corpse, history + log only, no chat echo
    if decision == DECISION.SKIP then
        pushHistory({ date=os.date('%m/%d'), time=os.date('%H:%M:%S'), name=name, id=id, decision='skip', reason=reason, toon=myToon })
        _channel:Broadcast({ type='loot_event', name=name, id=id, decision='skip', reason=reason,
                              date=os.date('%m/%d'), time=os.date('%H:%M:%S'), toon=myToon })
        return
    end

    -- Pick up the item
    mq.cmdf('/itemnotify loot%d leftmouseup', slotIndex)
    mq.delay(150)

    -- No-drop confirmation dialog
    if isNoDrop then
        handleNoDropDialog(decision == DECISION.KEEP or decision == DECISION.BANK or decision == DECISION.SELL)
        mq.delay(200)
    else
        mq.delay(150)
    end

    -- Verify item landed on cursor
    local cursor = mq.TLO.Cursor
    if not cursor or not cursor.ID() or cursor.ID() == 0 then return end

    if decision == DECISION.KEEP then
        if equipSlot then
            -- Swap new item into worn slot; old item comes to cursor
            mq.cmdf('/itemnotify %d leftmouseup', equipSlot)
            mq.delay(500)
            if mq.TLO.Window('ConfirmationDialogBox').Open() then
                mq.cmdf('/notify ConfirmationDialogBox CD_Yes_Button leftmouseup')
                mq.delay(200)
            end
            -- Old displaced item (or new item if swap failed) → inventory
            if mq.TLO.Cursor.ID() and mq.TLO.Cursor.ID() > 0 then
                mq.cmd('/autoinventory')
                mq.delay(200)
            end
            reason = 'upgrade-equipped'
        else
            mq.cmd('/autoinventory')
            mq.delay(200)
        end
        announceLoot(decision, name, reason, myToon)
    elseif decision == DECISION.BANK then
        mq.cmd('/autoinventory')
        mq.delay(200)
        announceLoot(decision, name, reason, myToon)
    elseif decision == DECISION.SELL then
        mq.cmd('/autoinventory')
        mq.delay(200)
        announceLoot(decision, name, reason, myToon)
    else
        mq.cmd('/destroy')
        mq.delay(200)
    end

    -- History + log (all decisions); broadcast for shared history panel on other toons
    pushHistory({ date=os.date('%m/%d'), time=os.date('%H:%M:%S'), name=name, id=id, decision=decision, reason=reason, toon=myToon })
    _channel:Broadcast({
        type     = 'loot_event',
        name     = name,
        id       = id,
        decision = decision,
        reason   = reason,
        date     = os.date('%m/%d'),
        time     = os.date('%H:%M:%S'),
        toon     = myToon,
    })
end

local function lootOpenCorpse()
    local count = mq.TLO.Corpse.Items() or 0
    for i = count, 1, -1 do
        if mq.TLO.Corpse.Open() then
            lootSlot(i)
        end
    end
end

function Loot.LootCorpse(corpseId, useWarp)
    if not Corpse.SafeToLoot() then return false end

    local reached = Corpse.ApproachCorpse(corpseId, useWarp)
    if not reached then return false end

    if not Corpse.OpenCorpse(corpseId) then return false end
    mq.delay(300)

    lootOpenCorpse()

    Corpse.CloseCorpse()
    Corpse.MarkDone(corpseId)
    return true
end

local function hasLiveXTargets()
    local xtCount = mq.TLO.Me.XTarget() or 0
    for i = 1, xtCount do
        local xt = mq.TLO.Me.XTarget(i)
        if xt and xt.ID() and xt.ID() > 0 and (xt.PctHPs() or 0) > 0 then
            return true
        end
    end
    return false
end

function Loot.SetEnabled(value)
    _config:SetAndSave('LootEnabled', value)
end

function Loot.IsInCombat()
    return _inCombat
end

-- Call once per main-loop tick to track combat state without touching LootEnabled.
function Loot.CombatTick()
    local wasInCombat = _inCombat
    _inCombat = mq.TLO.Me.Combat() or hasLiveXTargets()
    if _inCombat and not wasInCombat then
        Logger.Debug('Combat Entered - Looting Suspended')
    elseif not _inCombat and wasInCombat then
        Logger.Debug('Combat Ended - Looting Resumed')
    end
end

function Loot.LootNearby()
    if not _config:Get('LootEnabled') then return end
    if _inCombat then return end
    if _looting then return end

    local useWarp = _config:Get('UseWarp')
    local corpses = Corpse.FindNearby(_config:Get('LootRange'))
    if #corpses == 0 then return end

    Logger.Debug('sweep started - %d corpse(s) in range', #corpses)
    _looting = true
    for _, c in ipairs(corpses) do
        if not _config:Get('LootEnabled') then break end
        if not Corpse.SafeToLoot() then break end
        Loot.LootCorpse(c.id, useWarp)
        mq.delay(250)
    end
    _looting = false

    -- Announce done only when the sweep leaves no corpses remaining
    if #Corpse.FindNearby(_config:Get('LootRange')) == 0 and mq.TLO.Me.Grouped() and _config:Get('AnnounceDone') then
        mq.cmd('/g Done Looting')
    end
end

function Loot.GetHistory()
    return _history
end

function Loot.ScanBankItems()
    local results = {}
    for bag = 1, 10 do
        local bagSlot = mq.TLO.InvSlot('pack' .. bag).Item
        if bagSlot and bagSlot.ID() and bagSlot.ID() > 0 then
            local size = bagSlot.Container()
            if size and size > 0 then
                for slot = 1, size do
                    local item = bagSlot.Item(slot)
                    if item and item.ID() and item.ID() > 0 then
                        local name = item.Name() or ''
                        local id   = item.ID()
                        if _lists.bank and _lists.bank:Has(name, id) then
                            results[#results + 1] = { name=name, id=id, bag=bag, slot=slot }
                        end
                    end
                end
            end
        end
    end
    return results
end

function Loot.BankStuff(items)
    mq.cmdf('/nomodkey /click right target')
    mq.delay(2000, function() return mq.TLO.Window('BigBankWnd').Open() end)

    if not mq.TLO.Window('BigBankWnd').Open() then
        Logger.Warn('BankStuff: bank window did not open — target a banker first')
        printf('\are9loot: Bank window did not open. Target a banker and try again.')
        return
    end

    local count = 0
    for _, entry in ipairs(items) do
        mq.cmdf('/shift /itemnotify in pack%d %d leftmouseup', entry.bag, entry.slot)
        mq.delay(2000, function() return mq.TLO.Cursor.ID() ~= nil and mq.TLO.Cursor.ID() > 0 end)

        if mq.TLO.Cursor.ID() and mq.TLO.Cursor.ID() > 0 then
            mq.cmdf('/notify BigBankWnd BIGB_AutoButton leftmouseup')
            mq.delay(1000, function() return not mq.TLO.Cursor.ID() or mq.TLO.Cursor.ID() == 0 end)

            if mq.TLO.Cursor.ID() and mq.TLO.Cursor.ID() > 0 then
                mq.cmd('/autoinventory')
                Logger.Warn('BankStuff: bank may be full — inventoried %s', entry.name)
            else
                count = count + 1
                Logger.Info('BankStuff: deposited %s', entry.name)
            end
        else
            Logger.Warn('BankStuff: could not pick up %s (bag %d slot %d)', entry.name, entry.bag, entry.slot)
        end
    end

    if mq.TLO.Window('BigBankWnd').Open() then
        mq.TLO.Window('BigBankWnd').DoClose()
    end

    printf('\age9loot: BankStuff complete \xe2\x80\x94 deposited %d/%d item(s)', count, #items)
    Logger.Info('BankStuff: deposited %d/%d item(s)', count, #items)
end

function Loot.Init(cfg, lists, framework, channel)
    _config    = cfg
    _lists     = lists
    _framework = framework
    _channel   = channel

    openLog()

    channel:Observe(function(payload)
        if payload.type == 'loot_event' then
            pushHistory({
                date     = payload.date or os.date('%m/%d'),
                time     = payload.time or os.date('%H:%M:%S'),
                name     = payload.name,
                id       = payload.id or 0,
                decision = payload.decision,
                reason   = payload.reason,
                toon     = payload.toon or payload.from,
            })
        elseif payload.type == 'set_enabled' then
            if type(payload.value) == 'boolean' then
                Loot.SetEnabled(payload.value)
            end
        elseif payload.type == 'set_announcedone' then
            if type(payload.value) == 'boolean' then
                _config:SetAndSave('AnnounceDone', payload.value)
            end
        elseif payload.type == 'reload_lists' then
            _lists.LoadAll()
            Logger.Info('Lists reloaded via group broadcast from %s', payload.from or '?')
        end
    end)
end

return Loot
