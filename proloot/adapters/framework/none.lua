-- Null framework adapter: no-op pause/resume/detect; used when running standalone without a combat framework

local Adapter = {}
Adapter.name = 'none'

function Adapter:Detect()  return false end
function Adapter:Pause()   end
function Adapter:Resume()  end
function Adapter:IsPaused() return false end

return Adapter
