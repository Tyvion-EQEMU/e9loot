-- DanNet channel adapter: broadcast loot events via /dge, receive via mq.event()

local mq = require('mq')

-- Prefix tags our messages so the event handler ignores unrelated DanNet traffic
local PREFIX = '#e9loot#'

local Adapter    = {}
Adapter.name     = 'dannet'

local _observers       = {}
local _seq             = 0
local _eventRegistered = false

local function myName()
    return mq.TLO.Me.CleanName()
end

local function dannetAvailable()
    return mq.TLO.Plugin('MQ2DanNet').IsLoaded() == true
end

local function onMessage(line)
    local msg = line:match(PREFIX .. '(.*)')
    if not msg then return end
    local ok, payload = pcall(function() return load('return ' .. msg)() end)
    if not ok or type(payload) ~= 'table' then return end
    if payload.from == myName() then return end  -- ignore self-echo from /dgge
    for _, cb in ipairs(_observers) do
        cb(payload)
    end
end

function Adapter:Init()
    if not dannetAvailable() then
        printf('\arDanNet not loaded — channel adapter disabled')
        return
    end

    if not _eventRegistered then
        -- DanNet group echo messages arrive in chat; catch any line containing our prefix
        mq.event('e9loot_dannet', '*' .. PREFIX .. '*', onMessage)
        _eventRegistered = true
    end
end

-- Broadcast a table payload to all DanNet peers via group echo
function Adapter:Broadcast(payload)
    if not dannetAvailable() then return end
    _seq         = _seq + 1
    payload.seq  = _seq
    payload.from = myName()
    -- Serialize as a Lua table literal (no JSON dependency needed)
    local parts = {}
    for k, v in pairs(payload) do
        if type(v) == 'string' then
            table.insert(parts, string.format('%s="%s"', k, v:gsub('"', '\\"')))
        else
            table.insert(parts, string.format('%s=%s', k, tostring(v)))
        end
    end
    local encoded = '{' .. table.concat(parts, ',') .. '}'
    -- /dgge executes the argument as a command on all group peers except self.
    -- Sender already records its own events via pushHistory(), so self-exclusion is fine.
    -- Wrap in /echo so peers receive it as chat text for the event handler to catch.
    mq.cmdf('/squelch /dgge /echo %s%s', PREFIX, encoded)
end

function Adapter:Observe(cb)
    table.insert(_observers, cb)
end

-- Events are processed by mq.doevents() in the main loop
function Adapter:Tick()
    mq.doevents()
end

return Adapter
