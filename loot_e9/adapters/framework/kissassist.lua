-- KISSAssist adapter: pause via /posse pause, resume via /posse resume; detects running KISSAssist macro

local mq = require('mq')

local Adapter = {}
Adapter.name = 'kissassist'

-- KISSAssist is an MQ2 macro. Its pause/resume commands are registered
-- via the /posse command group when the KA macro is active.
-- /posse pause  → halts KISSAssist combat assistance
-- /posse resume → resumes KISSAssist combat assistance

function Adapter:Detect()
    -- KISSAssist sets the running macro name; check for it
    local macro = mq.TLO.Macro.Name()
    if macro == nil then return false end
    return macro:lower():find('kiss') ~= nil or macro:lower():find('ka') ~= nil
end

function Adapter:Pause()
    mq.cmd('/posse pause')
end

function Adapter:Resume()
    mq.cmd('/posse resume')
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
