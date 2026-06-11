-- Mini overlay: no title bar, animated running/paused toggle, logo click to restore main window

local mq     = require('mq')
local Widgets = require('proloot.ui.widgets')

local Mini = {}

local _config  = nil
local _loot    = nil
local _version = nil
local _channel = nil
local _logoTex = nil

function Mini.Init(config, loot, version, channel)
    _config  = config
    _loot    = loot
    _version = version
    _channel = channel

    _logoTex = mq.CreateTexture(mq.TLO.Lua.Dir() .. '/proloot/profusion_logo_32x32.png')
end

function Mini.Render(onClose)
    if not _config then return end

    local flags = bit32.bor(
        ImGuiWindowFlags.NoTitleBar,
        ImGuiWindowFlags.NoScrollbar,
        ImGuiWindowFlags.AlwaysAutoResize
    )
    ImGui.Begin('##e9mini', nil, flags)

    -- Logo — click to restore main window
    if _logoTex then
        ImGui.Image(_logoTex:GetTextureID(), ImVec2(32, 32))
    else
        local sp = ImGui.GetCursorScreenPosVec()
        local dl = ImGui.GetWindowDrawList()
        dl:AddRectFilled(sp, ImVec2(sp.x + 32, sp.y + 32), IM_COL32(40, 80, 140, 200))
        dl:AddRect(sp,       ImVec2(sp.x + 32, sp.y + 32), IM_COL32(100, 150, 210, 180))
        ImGui.InvisibleButton('##e9mini_logo', ImVec2(32, 32))
    end
    if ImGui.IsItemClicked() then
        if onClose then onClose() end
    end
    if ImGui.IsItemHovered() then
        ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
        ImGui.BeginTooltip()
        ImGui.Text('Click to restore main window')
        ImGui.EndTooltip()
    end

    ImGui.SameLine()
    ImGui.BeginGroup()
        ImGui.Text('E9 Loot')

        local enabled  = _config:Get('LootEnabled')
        local inCombat = _loot.IsInCombat()
        local newEnabled, toggled = Widgets.Toggle('##proloot_enable', enabled)
        if toggled then
            if _channel then _channel:Broadcast({ type='set_enabled', value=newEnabled }) end
            _loot.SetEnabled(newEnabled)
        end
        ImGui.SameLine()
        if not enabled then
            ImGui.TextColored(1.0, 0.4, 0.4, 1.0, 'Paused')
        elseif inCombat then
            ImGui.TextColored(1.0, 0.55, 0.1, 1.0, 'Combat')
        else
            ImGui.TextColored(0.3, 1.0, 0.3, 1.0, 'Running')
        end
    ImGui.EndGroup()

    -- Red border when in combat — double rect for a pronounced glow effect
    if inCombat then
        local wpos  = ImGui.GetWindowPosVec()
        local wsize = ImGui.GetWindowSizeVec()
        local x2    = wpos.x + wsize.x
        local y2    = wpos.y + wsize.y
        local dl    = ImGui.GetWindowDrawList()
        dl:AddRect(wpos, ImVec2(x2, y2),
            IM_COL32(255, 30, 30, 255), 0, 0, 3.0)
        dl:AddRect(ImVec2(wpos.x + 2, wpos.y + 2), ImVec2(x2 - 2, y2 - 2),
            IM_COL32(255, 80, 80, 180), 0, 0, 1.5)
    end

    ImGui.End()
end

return Mini
