-- Shared UI widgets used across panel and mini

local ImAnim = require('ImAnim')

local Widgets = {}

local COL_ON   = ImVec4(0.18, 0.70, 0.18, 1.0)
local COL_OFF  = ImVec4(0.65, 0.14, 0.14, 1.0)
local COL_KNOB = ImVec4(1.00, 1.00, 1.00, 1.0)

local function getDt()
    local dt = ImGui.GetIO().DeltaTime
    if dt <= 0 then dt = 1/60 end
    if dt > 0.1 then dt = 0.1 end
    return dt
end

-- Animated toggle switch. id must be unique per toggle (e.g. '##myToggle').
-- Returns newValue (bool), changed (bool).
function Widgets.Toggle(id, value)
    local dt  = getDt()
    local dl  = ImGui.GetWindowDrawList()
    local pos = ImGui.GetCursorScreenPosVec()
    local w, h    = 32, 16
    local changed = false

    if ImGui.InvisibleButton(id, ImVec2(w, h)) then
        value   = not value
        changed = true
    end

    local instId  = ImHashStr(id)
    local thumbCh = ImHashStr(id .. '_thumb')
    local bgCh    = ImHashStr(id .. '_bg')

    local target = value and 1.0 or 0.0
    local thumb  = ImAnim.TweenFloat(instId, thumbCh, target, 0.25,
        ImAnim.EasePreset(IamEaseType.OutBack), IamPolicy.Crossfade, dt)
    local bg     = ImAnim.TweenColor(instId, bgCh, value and COL_ON or COL_OFF, 0.2,
        ImAnim.EasePreset(IamEaseType.OutCubic), IamPolicy.Crossfade, IamColorSpace.OKLAB, dt)

    local r  = h * 0.5
    dl:AddRectFilled(pos, ImVec2(pos.x + w, pos.y + h),
        ImGui.ColorConvertFloat4ToU32(bg), r)

    local tx = pos.x + r + thumb * (w - h)
    local ty = pos.y + r
    local tr = r - 2.5
    dl:AddCircleFilled(ImVec2(tx + 1, ty + 1.5), tr, IM_COL32(0, 0, 0, 35))
    dl:AddCircleFilled(ImVec2(tx, ty),            tr, ImGui.ColorConvertFloat4ToU32(COL_KNOB))
    dl:AddCircle(ImVec2(tx, ty),                  tr, IM_COL32(0, 0, 0, 60), 32, 0.5)

    return value, changed
end

return Widgets
