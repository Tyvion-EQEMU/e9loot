-- DanNet channel adapter: broadcast/observe loot events via mq.TLO.DanNet; peer status queries

local mq     = require('mq')
local json   = require('mq.Utils') -- MQ2 ships mq.Utils with JSON helpers

-- DanNet uses observed variables: each toon sets a named var in its own namespace,
-- and peers read it via DanNet[peername][varname]. We use a single string var
-- "e9loot_event" that holds a JSON-encoded event payload.

local VARNAME   = 'e9loot_event'
local GROUPNAME = 'all'          -- DanNet group; 'all' covers every logged-in client

local Adapter   = {}
Adapter.name    = 'dannet'

-- Callbacks registered by the caller
local _observers = {}
-- Sequence number so peers can detect duplicate delivery
local _seq = 0

local function myName()
    return mq.TLO.Me.CleanName()
end

local function dannetAvailable()
    return mq.TLO.Plugin('MQ2DanNet').IsLoaded() == true
end

function Adapter:Init()
    if not dannetAvailable() then
        printf('\arDanNet not loaded — channel adapter disabled')
        return
    end
    -- Observe our own variable so we can self-test; observe peers' vars dynamically in Tick()
    mq.cmdf('/dnet observe %s %s', GROUPNAME, VARNAME)
end

-- Broadcast a table payload to all DanNet peers by setting our local observed var.
-- Peers read it next Tick() via DanNet observation.
function Adapter:Broadcast(payload)
    if not dannetAvailable() then return end
    _seq = _seq + 1
    payload.seq   = _seq
    payload.from  = myName()
    local encoded = mq.Utils.TableToJson(payload)
    mq.cmdf('/dnet set %s %s', VARNAME, encoded)
end

-- Register a callback(payload_table) for incoming events from peers
function Adapter:Observe(cb)
    table.insert(_observers, cb)
end

-- Call once per main loop iteration to poll peers' observed vars
function Adapter:Tick()
    if not dannetAvailable() then return end

    local me = myName()
    -- Iterate over members of the DanNet group
    local count = mq.TLO.DanNet.GroupCount(GROUPNAME)()
    if not count or count == 0 then return end

    for i = 1, count do
        local peer = mq.TLO.DanNet.GroupMember(GROUPNAME, i)()
        if peer and peer ~= me then
            local raw = mq.TLO.DanNet.Observe(peer, VARNAME)()
            if raw and raw ~= '' then
                local ok, payload = pcall(mq.Utils.JsonToTable, raw)
                if ok and payload and payload.from ~= me then
                    for _, cb in ipairs(_observers) do
                        cb(payload)
                    end
                end
            end
        end
    end
end

return Adapter
