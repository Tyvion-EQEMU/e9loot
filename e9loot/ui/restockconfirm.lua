-- Restock confirmation / management window: edit the restock list, review inventory
-- counts, and trigger a buy run at Costco (or any targeted vendor).

local mq = require('mq')

local RestockConfirm = {}

local _open         = false
local _rows         = {}   -- {name, want, have, need} — refreshed on open/rescan
local _loot         = nil
local _restockList  = nil
local _pendingItems = nil  -- consumed by main loop to trigger RestockStuff

local _addName = ''
local _addQty  = 1

function RestockConfirm.Open(loot, restockList)
    _loot        = loot
    _restockList = restockList
    _rows        = loot.ScanRestockNeeds(restockList)
    _open        = true
end

function RestockConfirm.IsOpen()
    return _open
end

function RestockConfirm.ConsumePending()
    local items = _pendingItems
    _pendingItems = nil
    return items
end

-- Returns a sorted copy of _rows: need > 0 first (alpha), satisfied last (alpha)
local function sortedRows()
    local display = {}
    for _, r in ipairs(_rows) do display[#display+1] = r end
    table.sort(display, function(a, b)
        local aNeed = a.need > 0
        local bNeed = b.need > 0
        if aNeed ~= bNeed then return aNeed end
        return a.name:lower() < b.name:lower()
    end)
    return display
end

function RestockConfirm.Render()
    if not _open then return end

    ImGui.SetNextWindowSize(ImVec2(500, 400), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot \xe2\x80\x94 Restock', _open, ImGuiWindowFlags.None)
    _open = open

    if not shouldDraw then ImGui.End(); return end

    -- Count summary
    local totalNeed, totalOk = 0, 0
    for _, r in ipairs(_rows) do
        if r.need > 0 then totalNeed = totalNeed + 1 else totalOk = totalOk + 1 end
    end

    if totalNeed > 0 then
        ImGui.Text(('%d need restocking'):format(totalNeed))
        ImGui.SameLine()
        ImGui.TextDisabled(('  |  %d satisfied'):format(totalOk))
    else
        ImGui.TextColored(ImVec4(0.3, 0.9, 0.3, 1.0), 'All stocked!')
        ImGui.SameLine()
        ImGui.TextDisabled(('  %d items'):format(totalOk))
    end

    ImGui.Separator()

    -- Reserve space for add-row + buttons at the bottom
    local footerH = ImGui.GetTextLineHeight() * 2 + ImGui.GetStyle().ItemSpacing.y * 4 + 8
    ImGui.BeginChild('##restocklist', ImVec2(0, -footerH), ImGuiChildFlags.None)

    if #_rows == 0 then
        ImGui.Spacing()
        ImGui.TextDisabled('No items in restock list. Add items below.')
    elseif ImGui.BeginTable('##restocktbl', 5,
        bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                  ImGuiTableFlags.ScrollY, ImGuiTableFlags.SizingStretchProp),
        ImVec2(0, -1)) then

        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Item',  ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Have',  ImGuiTableColumnFlags.WidthFixed, 42)
        ImGui.TableSetupColumn('Want',  ImGuiTableColumnFlags.WidthFixed, 62)
        ImGui.TableSetupColumn('Need',  ImGuiTableColumnFlags.WidthFixed, 42)
        ImGui.TableSetupColumn('',      ImGuiTableColumnFlags.WidthFixed, 18)
        ImGui.TableHeadersRow()

        local display      = sortedRows()
        local drewDivider  = false

        for _, r in ipairs(display) do
            local isSatisfied = r.need == 0

            -- Group divider between needs and satisfied
            if isSatisfied and not drewDivider then
                drewDivider = true
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.PushStyleColor(ImGuiCol.Text, 0.35, 0.35, 0.35, 1.0)
                ImGui.Text('\xe2\x94\x80\xe2\x94\x80 satisfied \xe2\x94\x80\xe2\x94\x80')
                ImGui.PopStyleColor()
                -- fill remaining columns so borders render cleanly
                ImGui.TableNextColumn(); ImGui.TableNextColumn()
                ImGui.TableNextColumn(); ImGui.TableNextColumn()
            end

            ImGui.TableNextRow()

            -- Item name (clickable inspect)
            ImGui.TableNextColumn()
            if isSatisfied then
                ImGui.TextColored(ImVec4(0.4, 0.7, 0.4, 0.8), r.name)
            else
                ImGui.Text(r.name)
            end
            if ImGui.IsItemHovered() then
                ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
                if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                    local found = mq.TLO.FindItem('=' .. r.name)
                    if found and found.ID() and found.ID() > 0 then
                        found.Inspect()
                    end
                end
            end

            -- Have
            ImGui.TableNextColumn()
            if isSatisfied then
                ImGui.TextColored(ImVec4(0.4, 0.7, 0.4, 0.8), tostring(r.have))
            else
                ImGui.Text(tostring(r.have))
            end

            -- Want (DragInt — drag or Ctrl+Click to edit)
            ImGui.TableNextColumn()
            ImGui.SetNextItemWidth(-1)
            local newWant, wantChanged = ImGui.DragInt('##want_' .. r.name, r.want, 1, 1, 9999, '%d')
            if wantChanged and newWant >= 1 then
                _restockList.Set(r.name, newWant)
                r.want = newWant
                r.need = math.max(0, newWant - r.have)
            end

            -- Need
            ImGui.TableNextColumn()
            if r.need > 0 then
                ImGui.TextColored(ImVec4(1.0, 0.75, 0.2, 1.0), tostring(r.need))
            else
                ImGui.TextColored(ImVec4(0.4, 0.7, 0.4, 0.8), '—')
            end

            -- Remove button
            ImGui.TableNextColumn()
            if ImGui.SmallButton('\xc3\x97##rm_' .. r.name) then
                _restockList.Remove(r.name)
                _rows = _loot.ScanRestockNeeds(_restockList)
                break  -- _rows changed; restart render next frame
            end
        end

        ImGui.EndTable()
    end

    ImGui.EndChild()

    -- Add-item row
    ImGui.SetNextItemWidth(220)
    local newName, _ = ImGui.InputText('##addname', _addName)
    _addName = newName
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    local newQty, _ = ImGui.InputInt('##addqty', _addQty, 1, 10)
    _addQty = math.max(1, newQty)
    ImGui.SameLine()
    local canAdd = _addName ~= ''
    if not canAdd then
        ImGui.BeginDisabled()
    end
    if ImGui.Button('Add') and canAdd then
        _restockList.Set(_addName, _addQty)
        _rows  = _loot.ScanRestockNeeds(_restockList)
        _addName = ''
    end
    if not canAdd then ImGui.EndDisabled() end

    ImGui.Separator()

    -- Action buttons
    local needItems = {}
    for _, r in ipairs(_rows) do
        if r.need > 0 then needItems[#needItems+1] = r end
    end

    if #needItems > 0 then
        if ImGui.Button(('Restock Now (%d)'):format(#needItems)) then
            _pendingItems = needItems
            _open = false
        end
    else
        ImGui.BeginDisabled()
        ImGui.Button('All Stocked')
        ImGui.EndDisabled()
    end

    ImGui.SameLine()
    if ImGui.Button('Rescan') then
        _rows = _loot.ScanRestockNeeds(_restockList)
    end
    ImGui.SameLine()
    if ImGui.Button('Close') then
        _open = false
    end

    ImGui.End()
end

return RestockConfirm
