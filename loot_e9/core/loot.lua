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

local function announce(name, decision, reason)
    local col = COLOR[decision] or '\aw'
    printf('%se9loot\aw | %-7s | %s \a-w(%s)\aw', col, decision:upper(), name, reason)
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

    if Upgrade.ShouldKeep(item, weaponMode) then
        return DECISION.KEEP, 'upgrade'
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

    local name            = item.Name() or '(unknown)'
    local isNoDrop        = item.NoDrop() == true
    local decision, reason = evaluateItem(item)

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
        mq.cmd('/autoinventory')
        mq.delay(200)
    elseif decision == DECISION.SELL then
        mq.cmd('/autoinventory')
        mq.delay(200)
    else
        mq.cmd('/destroy')
        mq.delay(200)
    end

    announce(name, decision, reason)
    pushHistory({ time=os.date('%H:%M:%S'), name=name, decision=decision, reason=reason })

    if _config:Get('AnnounceGroup') and decision == DECISION.KEEP then
        _channel:Broadcast({ type='loot', name=name, decision=decision })
    end
end

local function lootOpenCorpse()
    local count = mq.TLO.Corpse.Items() or 0
    for i = count, 1, -1 do
        if mq.TLO.Corpse.Open() then
            lootSlot(i)
        end
    end
end

function Loot.LootCorpse(corpseId, warpDist)
    if not Corpse.SafeToLoot() then return false end

    local reached = Corpse.ApproachCorpse(corpseId, warpDist)
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
    local corpses  = Corpse.FindNearby(200)

    for _, c in ipairs(corpses) do
        if not Corpse.SafeToLoot() then break end
        Loot.LootCorpse(c.id, warpDist)
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
end

return Loot
