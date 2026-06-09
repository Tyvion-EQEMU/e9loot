-- Sell Stuff confirmation window: scan inventory for sell-list items, let the user review, then sell.

local mq = require('mq')

local SellConfirm = {}

local _open        = false
local _items       = {}
local _loot        = nil
local _iconAnim    = nil
local _pendingItems = nil  -- set by Sell All button, consumed by main loop

local EQ_ICON_OFFSET = 500
local ICON_SIZE      = 40

local function getIconAnim()
    if not _iconAnim then
        _iconAnim = mq.FindTextureAnimation('A_DragItem')
    end
    return _iconAnim
end

local function formatCopper(cp)
    if cp <= 0 then return '—' end
    local pp = math.floor(cp / 1000); cp = cp % 1000
    local gp = math.floor(cp / 100);  cp = cp % 100
    local sp = math.floor(cp / 10);   local c = cp % 10
    local parts = {}
    if pp > 0 then parts[#parts+1] = pp .. 'p' end
    if gp > 0 then parts[#parts+1] = gp .. 'g' end
    if sp > 0 then parts[#parts+1] = sp .. 's' end
    if c  > 0 then parts[#parts+1] = c  .. 'c' end
    return table.concat(parts, ' ')
end

function SellConfirm.Open(loot)
    _loot  = loot
    _items = loot.ScanSellItems()
    _open  = true
end

function SellConfirm.IsOpen()
    return _open
end

function SellConfirm.ConsumePending()
    local items = _pendingItems
    _pendingItems = nil
    return items
end

function SellConfirm.Render()
    if not _open then return end

    ImGui.SetNextWindowSize(ImVec2(500, 320), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot \xe2\x80\x94 Sell Stuff', _open, ImGuiWindowFlags.None)
    _open = open

    if shouldDraw then
        if #_items == 0 then
            ImGui.Spacing()
            ImGui.TextDisabled('No sell-list items found in inventory.')
            ImGui.Spacing()
            if ImGui.Button('Rescan') then
                _items = _loot.ScanSellItems()
            end
            local maxX0 = select(1, ImGui.GetContentRegionMax())
            local closeW0 = 60
            ImGui.SameLine()
            ImGui.SetCursorPosX(maxX0 - closeW0)
            if ImGui.Button('Close', closeW0, 0) then
                _open = false
            end
        else
            -- Total value summary line
            local totalCopper = 0
            for _, e in ipairs(_items) do totalCopper = totalCopper + e.value end
            ImGui.Text(('%d item(s) ready to sell  \xe2\x80\x94  est. total: %s'):format(
                #_items, formatCopper(totalCopper)))
            ImGui.Separator()

            ImGui.BeginChild('##selllist', ImVec2(0, -36), ImGuiChildFlags.None)
            if ImGui.BeginTable('##selltbl', 5,
                bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                          ImGuiTableFlags.SizingStretchProp)) then

                ImGui.TableSetupColumn('Item',  ImGuiTableColumnFlags.WidthStretch)
                ImGui.TableSetupColumn('Bag',   ImGuiTableColumnFlags.WidthFixed, 36)
                ImGui.TableSetupColumn('Slot',  ImGuiTableColumnFlags.WidthFixed, 36)
                ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.WidthFixed, 80)
                ImGui.TableSetupColumn('ID',    ImGuiTableColumnFlags.WidthFixed, 56)
                ImGui.TableHeadersRow()

                for _, e in ipairs(_items) do
                    ImGui.TableNextRow()

                    ImGui.TableNextColumn()
                    local canSell = e.value > 0
                    if canSell then
                        ImGui.Text(e.name)
                    else
                        ImGui.TextDisabled(e.name)
                    end
                    if ImGui.IsItemHovered() then
                        if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                            local found = mq.TLO.FindItem('=' .. e.name)
                            if found and found.ID() and found.ID() > 0 then
                                found.Inspect()
                            end
                        end
                        local item = mq.TLO.InvSlot('pack' .. e.bag).Item.Item(e.slot)
                        if item and item.ID() and item.ID() > 0 then
                            ImGui.BeginTooltip()

                            local iconId = item.Icon()
                            local anim   = getIconAnim()
                            if iconId and iconId > 0 and anim then
                                anim:SetTextureCell(iconId - EQ_ICON_OFFSET)
                                ImGui.DrawTextureAnimation(anim, ICON_SIZE, ICON_SIZE)
                                ImGui.SameLine()
                                ImGui.SetCursorPosY(ImGui.GetCursorPosY() + (ICON_SIZE - ImGui.GetTextLineHeight()) * 0.5)
                            end
                            ImGui.TextColored(ImVec4(1.0, 1.0, 0.4, 1.0), item.Name() or e.name)

                            ImGui.Separator()
                            ImGui.PushTextWrapPos(300)

                            local itype = item.Type()
                            if itype then ImGui.Text('Type:   ' .. itype) end

                            local flags = {}
                            if item.NoDrop()    then flags[#flags+1] = 'No Drop'   end
                            if item.Lore()      then flags[#flags+1] = 'Lore'      end
                            if item.Stackable() then flags[#flags+1] = 'Stackable' end
                            if #flags > 0 then
                                ImGui.TextDisabled(table.concat(flags, '   '))
                            end

                            if e.value > 0 then
                                ImGui.Text('Value:  ' .. formatCopper(e.value))
                            else
                                ImGui.TextColored(ImVec4(1.0, 0.4, 0.4, 1.0), 'No vendor value — will be skipped')
                            end

                            local wt = item.Weight()
                            if wt and wt > 0 then
                                ImGui.Text(('Weight: %.1f'):format(wt))
                            end

                            local loreText = item.LoreText and item.LoreText() or nil
                            if loreText and loreText ~= '' then
                                ImGui.Spacing()
                                ImGui.TextDisabled(loreText)
                            end

                            ImGui.PopTextWrapPos()
                            ImGui.EndTooltip()
                        end
                    end

                    ImGui.TableNextColumn(); ImGui.TextDisabled(tostring(e.bag))
                    ImGui.TableNextColumn(); ImGui.TextDisabled(tostring(e.slot))
                    ImGui.TableNextColumn()
                    if e.value > 0 then
                        ImGui.Text(formatCopper(e.value))
                    else
                        ImGui.TextColored(ImVec4(0.6, 0.3, 0.3, 1.0), 'no value')
                    end
                    ImGui.TableNextColumn(); ImGui.TextDisabled(tostring(e.id))
                end

                ImGui.EndTable()
            end
            ImGui.EndChild()

            if ImGui.Button('Rescan') then
                _items = _loot.ScanSellItems()
            end
            ImGui.SameLine()
            if ImGui.Button('Cancel') then
                _open = false
            end
            local maxX   = select(1, ImGui.GetContentRegionMax())
            local sellW  = 75
            ImGui.SameLine()
            ImGui.SetCursorPosX(maxX - sellW)
            if ImGui.Button('Sell All', sellW, 0) then
                _pendingItems = _items
                _open = false
            end
        end
    end

    ImGui.End()
end

return SellConfirm
