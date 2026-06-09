-- Restock Status window: shows each toon's outstanding restock needs in real time.

local RestockStatus = {}

local _open           = false
local _loot           = nil
local _pendingRefresh = false

function RestockStatus.Open(loot)
    _loot           = loot
    _open           = true
    _pendingRefresh = true
end

function RestockStatus.IsOpen()
    return _open
end

function RestockStatus.ConsumePendingRefresh()
    if _pendingRefresh then
        _pendingRefresh = false
        return true
    end
    return false
end

function RestockStatus.Render()
    if not _open or not _loot then return end

    ImGui.SetNextWindowSize(ImVec2(480, 380), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot \xe2\x80\x94 Restock Status', _open, ImGuiWindowFlags.None)
    _open = open
    if not shouldDraw then ImGui.End(); return end

    local responses = _loot.GetRestockStatusResponses()
    local charCount = 0
    for _ in pairs(responses) do charCount = charCount + 1 end

    local footerH = ImGui.GetTextLineHeight() + ImGui.GetStyle().ItemSpacing.y * 2 + 10

    if charCount == 0 then
        ImGui.Spacing()
        ImGui.TextDisabled('Waiting for responses...')
    elseif ImGui.BeginTable('##statustbl', 5,
        bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                  ImGuiTableFlags.ScrollY, ImGuiTableFlags.SizingStretchProp),
        ImVec2(0, -footerH)) then

        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Character', ImGuiTableColumnFlags.WidthFixed,  110)
        ImGui.TableSetupColumn('Item',      ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Have',      ImGuiTableColumnFlags.WidthFixed,   42)
        ImGui.TableSetupColumn('Want',      ImGuiTableColumnFlags.WidthFixed,   42)
        ImGui.TableSetupColumn('Need',      ImGuiTableColumnFlags.WidthFixed,   42)
        ImGui.TableHeadersRow()

        local chars = {}
        for name in pairs(responses) do chars[#chars+1] = name end
        table.sort(chars, function(a, b) return a:lower() < b:lower() end)

        for _, charName in ipairs(chars) do
            local needs = responses[charName].needs or {}

            if #needs == 0 then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.TextColored(ImVec4(0.4, 0.8, 0.4, 1.0), charName)
                ImGui.TableNextColumn()
                ImGui.TextColored(ImVec4(0.4, 0.8, 0.4, 0.7), 'all stocked \xe2\x9c\x93')
                ImGui.TableNextColumn(); ImGui.TableNextColumn(); ImGui.TableNextColumn()
            else
                for i, r in ipairs(needs) do
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    if i == 1 then
                        ImGui.TextColored(ImVec4(1.0, 0.85, 0.4, 1.0), charName)
                    end
                    ImGui.TableNextColumn()
                    ImGui.Text(r.name)
                    ImGui.TableNextColumn()
                    ImGui.Text(tostring(r.have))
                    ImGui.TableNextColumn()
                    ImGui.Text(tostring(r.want))
                    ImGui.TableNextColumn()
                    ImGui.TextColored(ImVec4(1.0, 0.75, 0.2, 1.0), tostring(r.need))
                end
            end
        end

        ImGui.EndTable()
    end

    ImGui.Separator()
    if ImGui.Button('Refresh') then
        _pendingRefresh = true
    end
    ImGui.SameLine()
    if ImGui.Button('Close') then
        _open = false
    end

    ImGui.End()
end

return RestockStatus
