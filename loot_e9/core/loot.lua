-- Core loot logic: evaluates items against all list types, dispatches loot/sell/destroy decisions, tracks history

local mq      = require('mq')
local Corpse  = require('loot_e9.core.corpse')
local Upgrade = require('loot_e9.core.upgrade')

local Loot = {}

local _history = {}
local HIST_MAX = 200

local _config
local _lists
local _framework
local _channel

local DECISION = {
    KEEP    = 'keep',
    SELL    = 'sell',
    DESTROY = 'destroy',
    SKIP    = 'skip',   -- no-drop item we don't want; leave on corpse
    IGNORE  = 'ignore',
}

-- Color prefixes for MQ2 chat output
local COLOR = {
    keep    = '\ag',   -- green
    sell    = '\ay',   -- yellow
    destroy = '\ar',   -- red
    skip    = '\a-w',  -- grey
}

local function pushHistory(entry)
    table.insert(_history, 1, entry)
    if #_history > HIST_MAX then
        table.remove(_history, HIST_MAX + 1)
    end
end

local function announce(name, decision, reason, toon)
    local col  = COLOR[decision] or '\aw'
    local who  = toon and ('\a-w[' .. toon .. ']\aw ') or ''
    printf('%se9loot\aw | %s%-7s | %s \a-w(%s)\aw', col, who, decision:upper(), name, reason)
end

local function evaluateItem(item)
    if not item or not item.ID() or item.ID() == 0 then
        return DECISION.IGNORE, 'null item'
    end

    local name = item.Name() or ''
    local id   = item.ID()

    -- Explicit lists take priority over upgrade math
    if _lists.currency:Has(name, id)  then return DECISION.KEEP, 'currency'  end
    if _lists.quest:Has(name, id)     then return DECISION.KEEP, 'quest'     end
    if _lists.event:Has(name, id)     then return DECISION.KEEP, 'event'     end
    if _lists.lore:Has(name, id)      then return DECISION.KEEP, 'lore'      end
    if _lists.astrial:Has(name, id)   then return DECISION.KEEP, 'astrial'   end
    if _lists.deva:Has(name, id)      then return DECISION.KEEP, 'deva'      end
    if _lists.specials:Has(name, id)  then return DECISION.KEEP, 'special'   end
    if _lists.tiered:Has(name, id)    then return DECISION.KEEP, 'tiered'    end
    if _lists.beasts:Has(name, id)    then return DECISION.KEEP, 'beast'     end

    local weaponMode  = _config:Get('WeaponMode')
    local trashPrice  = _config:Get('TrashPrice')
    local val         = item.Value() or 0
    local isNoDrop    = item.NoDrop() == true

    if item.Stackable() or item.Tradeskills() then
        if trashPrice > 0 and val >= trashPrice then return DECISION.SELL, 'trash-sell' end
        if isNoDrop then return DECISION.SKIP, 'nodrop-worthless' end
        return DECISION.DESTROY, 'worthless-stack'
    end

    local upgradeSlot = Upgrade.FindUpgradeSlot(item, weaponMode)
    if upgradeSlot ~= nil then
        return DECISION.KEEP, 'upgrade', upgradeSlot
    end
    if weaponMode == 'always' and item.WornSlots() and item.WornSlots() > 0 then
        return DECISION.KEEP, 'upgrade', nil
    end

    -- Not an upgrade: no-drop items can't be picked up to destroy, so leave them
    if isNoDrop then return DECISION.SKIP, 'nodrop-no-upgrade' end

    if trashPrice > 0 and val >= trashPrice then return DECISION.SELL, 'sell-value' end

    return DECISION.DESTROY, 'no-match'
end

-- Handle the no-drop confirmation dialog that EQ shows when looting a no-drop item.
-- answer: true = click Yes, false = click No
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

    local name                      = item.Name() or '(unknown)'
    local isNoDrop                  = item.NoDrop() == true
    local decision, reason, equipSlot = evaluateItem(item)

    if decision == DECISION.IGNORE then return end

    -- No-drop items we don't want: announce and leave on corpse
    if decision == DECISION.SKIP then
        announce(name, 'skip', reason)
        pushHistory({ time=os.date('%H:%M:%S'), name=name, decision='skip', reason=reason })
        return
    end

    -- Pick up the item
    mq.cmdf('/itemnotify loot%d leftmouseup', slotIndex)
    mq.delay(150)

    -- If no-drop: EQ will show a confirmation dialog; answer based on our decision
    if isNoDrop then
        handleNoDropDialog(decision == DECISION.KEEP)
        mq.delay(200)
    else
        mq.delay(150)
    end

    -- Verify item landed on cursor
    local cursor = mq.TLO.Cursor
    if not cursor or not cursor.ID() or cursor.ID() == 0 then return end

    if decision == DECISION.KEEP then
        if equipSlot then
            -- Swap new item into the worn slot; old item comes to cursor
            mq.cmdf('/itemnotify %d leftmouseup', equipSlot)
            mq.delay(500)
            -- Handle any confirm dialog (rare on equip, but be safe)
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
    elseif decision == DECISION.SELL then
        mq.cmd('/autoinventory')
        mq.delay(200)
    else
        mq.cmd('/destroy')
        mq.delay(200)
    end

    local myToon = mq.TLO.Me.CleanName()

    -- Only KEEP echoes to MQ chat (locally on sender; broadcast delivers it to all other toons).
    -- Skip/destroy/sell are silent — visible only in the History panel.
    if decision == DECISION.KEEP then
        announce(name, decision, reason, myToon)
    end

    pushHistory({ time=os.date('%H:%M:%S'), name=name, decision=decision, reason=reason, toon=myToon })

    -- Broadcast every event: all toons share history; KEEP events also echo to their chat
    _channel:Broadcast({
        type     = 'loot_event',
        name     = name,
        decision = decision,
        reason   = reason,
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

function Loot.LootCorpse(corpseId, warpDist, useWarp)
    if not Corpse.SafeToLoot() then return false end

    local reached = Corpse.ApproachCorpse(corpseId, warpDist, useWarp)
    if not reached then return false end

    if not Corpse.OpenCorpse(corpseId) then return false end
    mq.delay(300)

    lootOpenCorpse()

    Corpse.CloseCorpse()
    Corpse.MarkDone(corpseId)
    return true
end

function Loot.LootNearby()
    if not _config:Get('LootEnabled') then return end

    local warpDist = _config:Get('WarpDist') or 100
    local useWarp  = _config:Get('UseWarp')
    local corpses  = Corpse.FindNearby(200)

    for _, c in ipairs(corpses) do
        if not Corpse.SafeToLoot() then break end
        Loot.LootCorpse(c.id, warpDist, useWarp)
        mq.delay(250)
    end
end

function Loot.GetHistory()
    return _history
end

function Loot.Init(cfg, lists, framework, channel)
    _config    = cfg
    _lists     = lists
    _framework = framework
    _channel   = channel

    -- Receive loot events from other toons:
    --   KEEP  → echo to local chat so every toon sees group upgrades
    --   all   → push into shared history panel
    channel:Observe(function(payload)
        if payload.type ~= 'loot_event' then return end
        if payload.decision == DECISION.KEEP then
            announce(payload.name, payload.decision, payload.reason, payload.toon)
        end
        pushHistory({
            time     = payload.time or os.date('%H:%M:%S'),
            name     = payload.name,
            decision = payload.decision,
            reason   = payload.reason,
            toon     = payload.toon or payload.from,
        })
    end)
end

return Loot
