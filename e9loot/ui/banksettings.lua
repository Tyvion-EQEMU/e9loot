-- Bank & Vendor settings window

local Widgets = require('e9loot.ui.widgets')

local BankSettings = {}

local _open   = false
local _config = nil

function BankSettings.Open(config)
    _config = config
    _open   = true
end

function BankSettings.IsOpen()
    return _open
end

function BankSettings.Render()
    if not _open or not _config then return end

    ImGui.SetNextWindowSize(ImVec2(420, 160), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot \xe2\x80\x94 Bank & Vendor', _open, ImGuiWindowFlags.None)
    _open = open

    if shouldDraw then
        ImGui.Spacing()

        if ImGui.BeginTable('##bvsettings', 2, 0) then
            ImGui.TableSetupColumn('##bvlbl', ImGuiTableColumnFlags.WidthFixed,  175)
            ImGui.TableSetupColumn('##bvctl', ImGuiTableColumnFlags.WidthStretch)

            -- Auto Consolidate Coins
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Auto Consolidate Coins')
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.PushTextWrapPos(300)
                ImGui.TextWrapped('Automatically convert CP \xe2\x86\x92 SP \xe2\x86\x92 GP \xe2\x86\x92 PP after a Bank Stuff deposit. The Consolidate Coins button always runs regardless of this setting.')
                ImGui.PopTextWrapPos()
                ImGui.EndTooltip()
            end
            ImGui.TableNextColumn()
            local autoConsolidate, consolidateChanged = Widgets.Toggle('##autoconsolidate', _config:Get('AutoConsolidateCoins'))
            if consolidateChanged then _config:SetAndSave('AutoConsolidateCoins', autoConsolidate) end

            -- Auto Deposit
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Auto Deposit')
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.PushTextWrapPos(300)
                ImGui.TextWrapped('Skip the Bank Stuff confirmation window and deposit bank-list items immediately when running /e9loot bankstuff.')
                ImGui.PopTextWrapPos()
                ImGui.EndTooltip()
            end
            ImGui.TableNextColumn()
            local autoDeposit, depositChanged = Widgets.Toggle('##autodeposit', _config:Get('BankAutoDeposit'))
            if depositChanged then _config:SetAndSave('BankAutoDeposit', autoDeposit) end

            ImGui.EndTable()
        end
    end

    ImGui.End()
end

return BankSettings
