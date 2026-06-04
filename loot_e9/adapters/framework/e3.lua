-- E3Next adapter: pause via /e3p on, resume via /e3p off; detects E3Next via MQ2Mono plugin

local mq = require('mq')

local Adapter = {}
Adapter.name = 'e3'

-- E3Next runs as a MQ2Mono C# plugin. Its pause command is:
--   /e3p on   → pauses all E3 bots on this client
--   /e3p off  → resumes all E3 bots on this client
--   /e3p      → toggles (no args)
-- Source confirmed from E3Next/Processors/Basics.cs EventProcessor.RegisterCommand("/e3p", ...)

function Adapter:Detect()
    -- MQ2Mono is the plugin that hosts E3Next; if loaded, E3 is likely running
    return mq.TLO.Plugin('MQ2Mono').IsLoaded() == true
end

function Adapter:Pause()
    mq.cmd('/e3p on')
end

function Adapter:Resume()
    mq.cmd('/e3p off')
end

-- E3 exposes IsPaused via its ExposedData mechanism but querying it from Lua
-- requires the MQ2Mono TLO bridge. Track locally as a reliable fallback.
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
