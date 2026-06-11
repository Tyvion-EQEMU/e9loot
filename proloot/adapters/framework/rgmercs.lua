-- RGMercs adapter: pause via /rgl pause, resume via /rgl unpause; detects running rgmercs lua script

local mq = require('mq')

local Adapter = {}
Adapter.name = 'rgmercs'

-- RGMercs registers the /rgl command when running.
-- /rgl pause   → pauses RGMercs combat assistance
-- /rgl unpause → resumes RGMercs combat assistance

function Adapter:Detect()
    -- rgmercs registers the /rgl command when running
    return mq.TLO.Alias('/rgl')() ~= nil
end

function Adapter:Pause()
    mq.cmd('/rgl pause')
end

function Adapter:Resume()
    mq.cmd('/rgl unpause')
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
