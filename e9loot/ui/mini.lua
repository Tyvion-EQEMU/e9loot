-- Mini overlay: no title bar, animated running/paused toggle, logo click to restore main window

local mq     = require('mq')
local ImAnim = require('ImAnim')

local Mini = {}

local _config  = nil
local _version = nil

local _INST_ID  = ImHashStr('e9mini_toggle')
local _THUMB_CH = ImHashStr('e9mini_thumb')
local _BG_CH    = ImHashStr('e9mini_bg')

local COL_ON   = ImVec4(0.18, 0.70, 0.18, 1.0)
local COL_OFF  = ImVec4(0.65, 0.14, 0.14, 1.0)
local COL_KNOB = ImVec4(1.00, 1.00, 1.00, 1.0)

local function getDt()
    local dt = ImGui.GetIO().DeltaTime
    if dt <= 0 then dt = 1/60 end
    if dt > 0.1 then dt = 0.1 end
    return dt
end

local function renderToggle(value)
    local dt  = getDt()
    local dl  = ImGui.GetWindowDrawList()
    local pos = ImGui.GetCursorScreenPosVec()
    local w, h = 32, 16

    if ImGui.InvisibleButton('##e9mini_tgl', ImVec2(w, h)) then
        value = not value
        _config:SetAndSave('LootEnabled', value)
    end

    local target = value and 1.0 or 0.0
    local thumb  = ImAnim.TweenFloat(_INST_ID, _THUMB_CH, target, 0.25,
        ImAnim.EasePreset(IamEaseType.OutBack), IamPolicy.Crossfade, dt)
    local bg     = ImAnim.TweenColor(_INST_ID, _BG_CH, value and COL_ON or COL_OFF, 0.2,
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
end

function Mini.Init(config, version)
    _config  = config
    _version = version
end

function Mini.Render(onClose)
    if not _config then return end

    local flags = bit32.bor(
        ImGuiWindowFlags.NoTitleBar,
        ImGuiWindowFlags.NoScrollbar,
        ImGuiWindowFlags.AlwaysAutoResize
    )
    ImGui.Begin('##e9mini', nil, flags)

    -- Logo placeholder — click to restore main window
    local sp = ImGui.GetCursorScreenPosVec()
    local dl = ImGui.GetWindowDrawList()
    dl:AddRectFilled(sp, ImVec2(sp.x + 32, sp.y + 32), IM_COL32(40, 80, 140, 200))
    dl:AddRect(sp,       ImVec2(sp.x + 32, sp.y + 32), IM_COL32(100, 150, 210, 180))
    if ImGui.InvisibleButton('##e9mini_logo', ImVec2(32, 32)) then
        if onClose then onClose() end
    end
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text('Click to restore main window')
        ImGui.EndTooltip()
    end

    ImGui.SameLine()
    ImGui.BeginGroup()

    local enabled = _config:Get('LootEnabled')
    renderToggle(enabled)

    ImGui.SameLine()
    if enabled then
        ImGui.TextColored(0.3, 1.0, 0.3, 1.0, 'Running')
    else
        ImGui.TextColored(1.0, 0.4, 0.4, 1.0, 'Paused')
    end

    ImGui.EndGroup()
    ImGui.End()
end

return Mini
