-- RGMercs adapter: pause via /rglua pause, resume via /rglua resume; detects running rgmercs lua script

local mq = require('mq')

local Adapter = {}
Adapter.name = 'rgmercs'

-- RGMercs exposes its pause state as a TLO via the Lua actor system.
-- We can't write Globals.PauseMain directly from another script's context,
-- so we use the registered /rglua bind which routes to Config:UpdateCommandHandlers().
-- The commands /rglua pause and /rglua resume are the public API.

function Adapter:Detect()
    -- rgmercs registers the /rglua command when running
    return mq.TLO.Alias('/rglua')() ~= nil
end

function Adapter:Pause()
    mq.cmd('/rglua pause')
end

function Adapter:Resume()
    mq.cmd('/rglua resume')
end

-- No reliable TLO to query pause state from outside; track it locally
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
