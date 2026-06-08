-- Bank Stuff confirmation window: scan inventory for bank-list items, let the user review, then deposit.

local mq = require('mq')

local BankConfirm = {}

local _open     = false
local _items    = {}
local _loot     = nil
local _iconAnim = nil

local EQ_ICON_OFFSET = 500
local ICON_SIZE      = 40

local function getIconAnim()
    if not _iconAnim then
        _iconAnim = mq.FindTextureAnimation('A_DragItem')
    end
    return _iconAnim
end

function BankConfirm.Open(loot)
    _loot  = loot
    _items = loot.ScanBankItems()
    _open  = true
end

function BankConfirm.IsOpen()
    return _open
end

function BankConfirm.Render()
    if not _open then return end

    ImGui.SetNextWindowSize(ImVec2(480, 320), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot \xe2\x80\x94 Bank Stuff', _open, ImGuiWindowFlags.None)
    _open = open

    if shouldDraw then
        if #_items == 0 then
            ImGui.Spacing()
            ImGui.TextDisabled('No bank-list items found in inventory.')
            ImGui.Spacing()
            if ImGui.Button('Rescan') then
                _items = _loot.ScanBankItems()
            end
            ImGui.SameLine()
            if ImGui.Button('Close') then
                _open = false
            end
        else
            ImGui.Text(('%d item(s) ready to deposit:'):format(#_items))
            ImGui.Separator()

            ImGui.BeginChild('##banklist', ImVec2(0, -36), ImGuiChildFlags.None)
            if ImGui.BeginTable('##banktbl', 4,
                bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                          ImGuiTableFlags.SizingStretchProp)) then

                ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.WidthStretch)
                ImGui.TableSetupColumn('Bag',  ImGuiTableColumnFlags.WidthFixed, 40)
                ImGui.TableSetupColumn('Slot', ImGuiTableColumnFlags.WidthFixed, 40)
                ImGui.TableSetupColumn('ID',   ImGuiTableColumnFlags.WidthFixed, 60)
                ImGui.TableHeadersRow()

                for _, e in ipairs(_items) do
                    ImGui.TableNextRow()

                    ImGui.TableNextColumn()
                    ImGui.Text(e.name)
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

                            -- Icon + name header
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

                            local val = item.Value() or 0
                            if val > 0 then
                                local rem = val
                                local pp  = math.floor(rem / 1000); rem = rem % 1000
                                local gp  = math.floor(rem / 100);  rem = rem % 100
                                local sp  = math.floor(rem / 10);   local cp = rem % 10
                                local parts = {}
                                if pp > 0 then parts[#parts+1] = pp .. 'p' end
                                if gp > 0 then parts[#parts+1] = gp .. 'g' end
                                if sp > 0 then parts[#parts+1] = sp .. 's' end
                                if cp > 0 then parts[#parts+1] = cp .. 'c' end
                                if #parts > 0 then
                                    ImGui.Text('Value:  ' .. table.concat(parts, ' '))
                                end
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
                    ImGui.TableNextColumn(); ImGui.TextDisabled(tostring(e.id))
                end

                ImGui.EndTable()
            end
            ImGui.EndChild()

            if ImGui.Button('Bank All') then
                _open = false
                _loot.BankStuff(_items)
            end
            ImGui.SameLine()
            if ImGui.Button('Rescan') then
                _items = _loot.ScanBankItems()
            end
            ImGui.SameLine()
            if ImGui.Button('Cancel') then
                _open = false
            end
        end
    end

    ImGui.End()
end

return BankConfirm
