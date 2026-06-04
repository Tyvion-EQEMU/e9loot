-- Core loot logic: evaluates items against all list types, dispatches loot/sell/destroy decisions, tracks history

local mq     = require('mq')
local Corpse = require('loot_e9.core.corpse')
local Upgrade = require('loot_e9.core.upgrade')

local Loot = {}

-- History ring buffer (most recent 200 entries)
local _history  = {}
local HIST_MAX  = 200

-- Injected at runtime by main.lua
local _config
local _lists
local _framework
local _channel

-- Decisions
local DECISION = {
    KEEP    = 'keep',
    SELL    = 'sell',
    DESTROY = 'destroy',
    IGNORE  = 'ignore',
}

local function pushHistory(entry)
    table.insert(_history, 1, entry)
    if #_history > HIST_MAX then
        table.remove(_history, HIST_MAX + 1)
    end
end

-- Evaluate a single item (MQ item TLO on the cursor or in the corpse window)
-- Returns DECISION, reason string
local function evaluateItem(item)
    if not item or not item.ID() or item.ID() == 0 then
        return DECISION.IGNORE, 'null item'
    end

    local name = item.Name() or ''
    local id   = item.ID()

    -- Priority order: explicit lists override upgrade logic
    if _lists.currency:Has(name, id)  then return DECISION.KEEP,    'currency'  end
    if _lists.quest:Has(name, id)     then return DECISION.KEEP,    'quest'     end
    if _lists.event:Has(name, id)     then return DECISION.KEEP,    'event'     end
    if _lists.lore:Has(name, id)      then return DECISION.KEEP,    'lore'      end
    if _lists.astrial:Has(name, id)   then return DECISION.KEEP,    'astrial'   end
    if _lists.deva:Has(name, id)      then return DECISION.KEEP,    'deva'      end
    if _lists.specials:Has(name, id)  then return DECISION.KEEP,    'special'   end
    if _lists.tiered:Has(name, id)    then return DECISION.KEEP,    'tiered'    end
    if _lists.beasts:Has(name, id)    then return DECISION.KEEP,    'beast'     end

    -- Upgrade logic
    local weaponMode = _config:Get('WeaponMode')
    if item.Stackable() or item.Tradeskills() then
        -- Tradeskill/stackable: keep if valuable enough
        local val = item.Value() or 0
        local trashPrice = _config:Get('TrashPrice')
        if trashPrice > 0 and val >= trashPrice then return DECISION.SELL, 'trash-sell' end
        return DECISION.DESTROY, 'worthless-stack'
    end

    if Upgrade.ShouldKeep(item, weaponMode) then
        return DECISION.KEEP, 'upgrade'
    end

    -- Sell if above trash threshold, else destroy
    local val = item.Value() or 0
    local trashPrice = _config:Get('TrashPrice')
    if trashPrice > 0 and val >= trashPrice then
        return DECISION.SELL, 'sell-value'
    end

    return DECISION.DESTROY, 'no-match'
end

-- Loot one item from the open corpse window by slot index (1-based)
local function lootSlot(slotIndex)
    local item = mq.TLO.Corpse.Item(slotIndex)
    if not item or not item.ID() or item.ID() == 0 then return end

    local name     = item.Name() or '(unknown)'
    local decision, reason = evaluateItem(item)

    if decision == DECISION.IGNORE then return end

    -- Pick the item up from the corpse
    mq.cmdf('/itemnotify loot%d leftmouseup', slotIndex)
    mq.delay(300)

    -- Cursor should now hold the item
    local cursor = mq.TLO.Cursor
    if not cursor or not cursor.ID() or cursor.ID() == 0 then return end

    local entry = {
        time     = os.date('%H:%M:%S'),
        name     = name,
        decision = decision,
        reason   = reason,
    }

    if decision == DECISION.KEEP then
        mq.cmd('/autoinventory')
        mq.delay(200)
    elseif decision == DECISION.SELL then
        -- Flag for later vendor sell; for now put it away
        mq.cmd('/autoinventory')
        mq.delay(200)
    else -- DESTROY
        mq.cmd('/destroy')
        mq.delay(200)
    end

    pushHistory(entry)

    -- Announce to group channel if configured
    if _config:Get('AnnounceGroup') and decision == DECISION.KEEP then
        _channel:Broadcast({ type='loot', name=name, decision=decision })
    end
end

-- Loot all items in the currently open corpse window
local function lootOpenCorpse()
    local count = mq.TLO.Corpse.Items() or 0
    -- Loot from last slot to first to avoid index shifting as items disappear
    for i = count, 1, -1 do
        if mq.TLO.Corpse.Open() then
            lootSlot(i)
        end
    end
end

-- Public: process a single nearby corpse by ID
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

-- Public: scan and loot all nearby corpses
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

-- Public: read-only access to loot history
function Loot.GetHistory()
    return _history
end

-- Injected dependencies
function Loot.Init(cfg, lists, framework, channel)
    _config    = cfg
    _lists     = lists
    _framework = framework
    _channel   = channel
end

return Loot
