-- Corpse management: scan for nearby corpses, approach/warp logic, lock/unlock, safety checks before looting

local mq = require('mq')

local Corpse = {}

-- Corpses we have already processed this session (by spawn ID) to avoid revisiting
local _done = {}

-- Returns list of nearby lootable corpse spawn IDs within maxDist
function Corpse.FindNearby(maxDist)
    maxDist = maxDist or 200
    local found = {}

    local count = mq.TLO.SpawnCount(string.format('npccorpse radius %d', maxDist))()
    for i = 1, (count or 0) do
        local sp = mq.TLO.NearestSpawn(i, string.format('npccorpse radius %d', maxDist))
        if sp and sp.ID() and sp.ID() > 0 and not _done[sp.ID()] then
            table.insert(found, {
                id   = sp.ID(),
                name = sp.Name(),
                dist = sp.Distance3D() or 999,
            })
        end
    end

    -- Closest first
    table.sort(found, function(a, b) return a.dist < b.dist end)
    return found
end

-- Safety checks before approaching or opening a corpse
function Corpse.SafeToLoot()
    local me = mq.TLO.Me
    if me.Dead()       then return false end
    if me.Casting.ID() then return false end -- mid-cast
    if me.Moving()     then return false end
    if mq.TLO.Stick.Active() then return false end -- nav/stick in progress
    return true
end

-- Navigate to a corpse. useWarp=true => /warp target, useWarp=false => /nav always.
-- warpDist is ignored when useWarp=false.
function Corpse.ApproachCorpse(corpseId, warpDist, useWarp)
    local sp = mq.TLO.Spawn(string.format('id %d', corpseId))
    if not sp or not sp.ID() or sp.ID() == 0 then return false end

    local dist = sp.Distance3D() or 999

    if useWarp and (warpDist == 0 or dist > warpDist) then
        mq.cmdf('/tgt id %d', corpseId)
        mq.delay(200)
        mq.cmd('/warp target')
        mq.delay(500)
    elseif dist > 15 then
        mq.cmdf('/nav id %d', corpseId)
        -- Wait until adjacent or stuck for max 10 s
        local deadline = os.clock() + 10
        while os.clock() < deadline do
            mq.delay(250)
            local cur = mq.TLO.Spawn(string.format('id %d', corpseId))
            if not cur or (cur.Distance3D() or 999) <= 15 then break end
            if mq.TLO.Navigation.Active() == false then break end
        end
        mq.cmd('/nav stop')
    end

    return (mq.TLO.Spawn(string.format('id %d', corpseId)).Distance3D() or 999) <= 20
end

-- Open a corpse window for looting
function Corpse.OpenCorpse(corpseId)
    mq.cmdf('/target id %d', corpseId)
    mq.delay(150)
    mq.cmd('/loot')
    mq.delay(500)
    return mq.TLO.Corpse.Open() == true
end

-- Close whatever corpse window is open
function Corpse.CloseCorpse()
    if mq.TLO.Corpse.Open() then
        mq.cmd('/notify LootWnd DoneButton leftmouseup')
        mq.delay(200)
    end
end

-- Mark a corpse ID as processed so we don't revisit it
function Corpse.MarkDone(corpseId)
    _done[corpseId] = true
end

-- Clear the done set (call on zone change)
function Corpse.ResetDone()
    _done = {}
end

return Corpse
