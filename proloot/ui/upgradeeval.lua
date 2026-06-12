-- Upgrade Evaluator window: scans bag inventory for equippable items and reports upgrade verdicts

local mq      = require('mq')
local Upgrade = require('proloot.core.upgrade')

local UpgradeEval = {}

local _open    = false
local _config  = nil
local _results = {}

local COL_UPGRADE = ImVec4(0.3, 1.0, 0.3, 1.0)
local COL_NOUP    = ImVec4(0.5, 0.5, 0.5, 0.7)

local function scan()
    _results = {}
    if not _config then return end

    local weaponMode    = _config:Get('WeaponMode')
    local rangedMode    = _config:Get('RangedMode')
    local excludedSlots = Upgrade.ParseExcludedSlots(_config:Get('ExcludedSlots'))

    for bag = 1, 10 do
        local bagSlot = mq.TLO.InvSlot('pack' .. bag).Item
        if bagSlot and bagSlot.ID() and bagSlot.ID() > 0 then
            local size = bagSlot.Container()
            if size and size > 0 then
                for slot = 1, size do
                    local item = bagSlot.Item(slot)
                    if item and item.ID() and item.ID() > 0 then
                        if (item.WornSlots() or 0) > 0 then
                            local upgradeSlot = Upgrade.FindUpgradeSlot(item, weaponMode, rangedMode, excludedSlots)
                            local slotName    = upgradeSlot and (Upgrade.SLOT_NAMES[upgradeSlot] or ('Slot ' .. upgradeSlot)) or nil
                            local equippedName = nil
                            if upgradeSlot then
                                local eq = mq.TLO.Me.Inventory(upgradeSlot)
                                if eq and eq.ID() and eq.ID() > 0 then
                                    equippedName = eq.Name()
                                end
                            end
                            _results[#_results+1] = {
                                name         = item.Name() or '(unknown)',
                                isUpgrade    = upgradeSlot ~= nil,
                                slotName     = slotName,
                                equippedName = equippedName,
                            }
                        end
                    end
                end
            end
        end
    end

    -- Upgrades first, then alphabetical within each group
    table.sort(_results, function(a, b)
        if a.isUpgrade ~= b.isUpgrade then return a.isUpgrade end
        return a.name:lower() < b.name:lower()
    end)
end

function UpgradeEval.Open(config)
    _config = config
    _open   = true
    scan()
end

function UpgradeEval.Close()
    _open = false
end

function UpgradeEval.IsOpen()
    return _open
end

function UpgradeEval.Render()
    if not _open then return end

    ImGui.SetNextWindowSize(ImVec2(600, 380), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('ProLoot \xe2\x80\x94 Upgrade Evaluator', _open, ImGuiWindowFlags.None)
    _open = open
    if not shouldDraw then ImGui.End(); return end

    local upgradeCount = 0
    for _, r in ipairs(_results) do if r.isUpgrade then upgradeCount = upgradeCount + 1 end end

    if ImGui.Button('Refresh') then scan() end
    ImGui.SameLine()
    ImGui.TextDisabled(string.format('%d item(s) scanned  |  %d upgrade(s) found', #_results, upgradeCount))

    ImGui.Separator()

    if ImGui.BeginTable('##evalresults', 4,
        bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                  ImGuiTableFlags.ScrollY, ImGuiTableFlags.SizingStretchProp),
        ImVec2(0, -1)) then

        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Item',               ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Slot',               ImGuiTableColumnFlags.WidthFixed,   80)
        ImGui.TableSetupColumn('Currently Equipped', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('Verdict',            ImGuiTableColumnFlags.WidthFixed,   90)
        ImGui.TableHeadersRow()

        for _, r in ipairs(_results) do
            local col = r.isUpgrade and COL_UPGRADE or COL_NOUP

            ImGui.TableNextRow()

            ImGui.TableNextColumn()
            ImGui.TextColored(col, r.name)

            ImGui.TableNextColumn()
            if r.slotName then
                ImGui.TextColored(col, r.slotName)
            else
                ImGui.TextDisabled('\xe2\x80\x94')
            end

            ImGui.TableNextColumn()
            if r.equippedName then
                ImGui.TextColored(col, r.equippedName)
            elseif r.isUpgrade then
                ImGui.TextDisabled('(empty slot)')
            else
                ImGui.TextDisabled('\xe2\x80\x94')
            end

            ImGui.TableNextColumn()
            if r.isUpgrade then
                ImGui.TextColored(COL_UPGRADE, 'Upgrade')
            else
                ImGui.TextColored(COL_NOUP, 'No Upgrade')
            end
        end

        ImGui.EndTable()
    end

    ImGui.End()
end

return UpgradeEval
