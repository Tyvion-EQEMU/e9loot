-- KISSAssist adapter: pause via /mqp on, resume via /mqp off; detects running KISSAssist macro

local mq = require('mq')

local Adapter = {}
Adapter.name = 'kissassist'

-- KISSAssist uses the MQ2 macro pause command:
-- /mqp on  → pauses the running macro (KISSAssist stops acting)
-- /mqp off → resumes the running macro

function Adapter:Detect()
    -- KISSAssist sets the running macro name; check for it
    local macro = mq.TLO.Macro.Name()
    if macro == nil then return false end
    return macro:lower():find('kiss') ~= nil or macro:lower():find('ka') ~= nil
end

function Adapter:Pause()
    mq.cmd('/mqp on')
end

function Adapter:Resume()
    mq.cmd('/mqp off')
end

Adapter._paused = false

function Adapter:PauseAndTrack()
    if not self._paused then
        self:Pause()
        self._paused = true
    end
end

function Adapter:ResumeAndTrack()
    if self._paused then
        self:Resume()
        self._paused = false
    end
end

function Adapter:IsPaused()
    return self._paused
end

return Adapter
