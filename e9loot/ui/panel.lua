-- Main ImGui panel: header, pause/resume, two-column settings, history, mini-mode

local mq     = require('mq')
local Icons  = require('mq.ICONS')
local Corpse = require('e9loot.core.corpse')
local Mini   = require('e9loot.ui.mini')

local Panel = {}

local _config    = nil
local _loot      = nil
local _setup     = nil
local _editor    = nil
local _framework = nil
local _adapters  = nil
local _channel   = nil
local _version   = nil

-- Weapon mode
local WEAPONMODES       = { 'DW', '2H', 'SNB', 'ANY' }
local WEAPONMODE_LABELS = {
    DW      = 'Dual Wield',
    ['2H']  = 'Two-Handed',
    SNB     = 'Sword and Board',
    ANY     = 'Any / No Restriction',
}
local _wmIdx = 1

local function wmIndexOf(val)
    for i, v in ipairs(WEAPONMODES) do if v == val then return i end end
    return 1
end

-- Framework / channel combo lists
local FRAMEWORKS = { 'none', 'rgmercs', 'e3', 'kissassist' }
local FRAMEWORK_LABELS = { none='None', rgmercs='RG Mercs', e3='E3', kissassist='Kiss Assist' }

local CHANNELS = { 'none', 'dannet', 'eqbc' }
local CHANNEL_LABELS = { none='None', dannet='DanNet', eqbc='EQBC' }

local function indexOfStr(tbl, val)
    for i, v in ipairs(tbl) do if v == val then return i end end
    return 1
end

-- Panel open state (tracks X button)
local _panelOpen = true

-- History state
local _histOpen           = false
local _histFilter         = ''
local _histDecisionFilter = { keep=false, sell=false, destroy=false, skip=false }

-- Restart modal
local _wantRestartModal = false

-- Mini mode
local _miniMode = false

local DECISION_COLORS = {
    keep    = { 0.3, 1.0, 0.3, 1.0 },
    sell    = { 1.0, 0.8, 0.2, 1.0 },
    destroy = { 0.6, 0.6, 0.6, 1.0 },
    skip    = { 0.5, 0.5, 0.5, 0.7 },
}

-- Active / inactive button colors for decision filter toggles
local FILTER_BTNCOLS = {
    keep    = { a={ 0.20, 0.75, 0.20, 1.0 }, i={ 0.07, 0.26, 0.07, 1.0 } },
    sell    = { a={ 0.82, 0.62, 0.10, 1.0 }, i={ 0.28, 0.21, 0.04, 1.0 } },
    destroy = { a={ 0.60, 0.60, 0.60, 1.0 }, i={ 0.20, 0.20, 0.20, 1.0 } },
    skip    = { a={ 0.80, 0.80, 0.80, 1.0 }, i={ 0.24, 0.24, 0.24, 1.0 } },
}

local DECISION_ORDER  = { 'keep', 'sell', 'destroy', 'skip' }
local DECISION_LABELS = { keep='Keep', sell='Sell', destroy='Destroy', skip='Skip' }

-----------------------------------------------------------------------
-- History window
-----------------------------------------------------------------------
local function renderHistory()
    if not _histOpen then return end

    ImGui.SetNextWindowSize(ImVec2(660, 400), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot — Loot History', _histOpen,
        ImGuiWindowFlags.None)
    _histOpen = open

    if shouldDraw then
        ImGui.SetNextItemWidth(220)
        local newFilter, _ = ImGui.InputText('##histfilter', _histFilter)
        _histFilter = newFilter
        local filterLow = newFilter:lower()

        ImGui.SameLine()
        if ImGui.Button('Clear Filter') then
            _histFilter = ''
            for _, d in ipairs(DECISION_ORDER) do
                _histDecisionFilter[d] = false
            end
        end

        -- Decision filter toggles
        for _, d in ipairs(DECISION_ORDER) do
            ImGui.SameLine()
            local active = _histDecisionFilter[d]
            local bc     = active and FILTER_BTNCOLS[d].a or FILTER_BTNCOLS[d].i
            ImGui.PushStyleColor(ImGuiCol.Button,
                bc[1], bc[2], bc[3], bc[4])
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered,
                math.min(1.0, bc[1]*1.25), math.min(1.0, bc[2]*1.25), math.min(1.0, bc[3]*1.25), 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,
                bc[1]*0.8, bc[2]*0.8, bc[3]*0.8, 1.0)
            if ImGui.Button(DECISION_LABELS[d]) then
                _histDecisionFilter[d] = not _histDecisionFilter[d]
            end
            ImGui.PopStyleColor(3)
        end

        ImGui.Separator()

        local history = _loot.GetHistory()
        local kept, sold, destroyed = 0, 0, 0

        local anyDecision = _histDecisionFilter.keep or _histDecisionFilter.sell
            or _histDecisionFilter.destroy or _histDecisionFilter.skip

        if ImGui.BeginTable('##histtbl', 6,
            bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                      ImGuiTableFlags.ScrollY, ImGuiTableFlags.SizingStretchProp),
            ImVec2(0, -22)) then

            ImGui.TableSetupScrollFreeze(0, 1)
            ImGui.TableSetupColumn('Date',   ImGuiTableColumnFlags.WidthFixed,  42)
            ImGui.TableSetupColumn('Time',   ImGuiTableColumnFlags.WidthFixed,  50)
            ImGui.TableSetupColumn('Toon',   ImGuiTableColumnFlags.WidthFixed,  75)
            ImGui.TableSetupColumn('Action', ImGuiTableColumnFlags.WidthFixed,  55)
            ImGui.TableSetupColumn('Item',   ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn('Reason', ImGuiTableColumnFlags.WidthFixed, 100)
            ImGui.TableHeadersRow()

            for i, entry in ipairs(history) do
                if     entry.decision == 'keep'    then kept      = kept    + 1
                elseif entry.decision == 'sell'    then sold      = sold    + 1
                elseif entry.decision == 'destroy' then destroyed = destroyed + 1
                end

                local toonLow      = (entry.toon or ''):lower()
                local decisionPass = not anyDecision or _histDecisionFilter[entry.decision]
                local textPass     = filterLow == ''
                    or entry.name:lower():find(filterLow, 1, true)
                    or toonLow:find(filterLow, 1, true)

                if decisionPass and textPass then
                    local col = DECISION_COLORS[entry.decision] or { 1, 1, 1, 1 }

                    ImGui.TableNextRow()

                    ImGui.TableNextColumn()
                    ImGui.TextDisabled(entry.date or '')

                    ImGui.TableNextColumn()
                    ImGui.TextDisabled(entry.time or '')

                    ImGui.TableNextColumn()
                    ImGui.Text(entry.toon or '?')

                    ImGui.TableNextColumn()
                    ImGui.TextColored(col[1], col[2], col[3], col[4], (entry.decision or ''):upper())

                    ImGui.TableNextColumn()
                    local canInspect = entry.decision == 'keep' or entry.decision == 'sell'
                    ImGui.TextColored(col[1], col[2], col[3], col[4], entry.name)
                    if canInspect then
                        local rmin = ImGui.GetItemRectMinVec()
                        local rmax = ImGui.GetItemRectMaxVec()
                        local dl2  = ImGui.GetWindowDrawList()
                        dl2:AddLine(ImVec2(rmin.x, rmax.y), rmax,
                            ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], col[4])), 1.0)
                        if ImGui.IsItemHovered() then
                            ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
                            if ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                                local found = mq.TLO.FindItem('=' .. entry.name)
                                if found and found.ID() and found.ID() > 0 then
                                    found.Inspect()
                                else
                                    printf('\aye9loot: %s is not in your inventory', entry.name)
                                end
                            end
                        end
                    end

                    ImGui.TableNextColumn()
                    ImGui.TextDisabled(entry.reason or '')
                end
            end

            ImGui.EndTable()
        end

        ImGui.TextDisabled(string.format(
            'Session: %d kept  |  %d sold  |  %d destroyed', kept, sold, destroyed))
    end

    ImGui.End()
end

-----------------------------------------------------------------------
-- Panel API
-----------------------------------------------------------------------
function Panel.Init(config, loot, setup, editor, framework, adapters, channel, version)
    _config    = config
    _loot      = loot
    _setup     = setup
    _editor    = editor
    _framework = framework
    _adapters  = adapters
    _channel   = channel
    _version   = version
    _histOpen  = config:Get('HistoryOpen')
    _wmIdx     = wmIndexOf(config:Get('WeaponMode'))
    Mini.Init(config, loot, version)
end

function Panel.ToggleMini()
    _miniMode = not _miniMode
end

function Panel.Show()
    _panelOpen = true
    _miniMode  = false
end

function Panel.Render()
    if not _config then return end

    -- Mini mode: show compact overlay, hide main window
    if _miniMode then
        Mini.Render(function() _miniMode = false end)
        renderHistory()
        _editor.Render()
        _setup.Render()
        return
    end

    ImGui.SetNextWindowSize(ImVec2(340, 380), ImGuiCond.FirstUseEver)
    local _lootEnabled = _config:Get('LootEnabled')
    if not _lootEnabled then
        ImGui.PushStyleColor(ImGuiCol.TitleBg,       0.40, 0.10, 0.08, 1.0)
        ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.55, 0.12, 0.08, 1.0)
    end
    local open, shouldDraw = ImGui.Begin('e9loot', _panelOpen, ImGuiWindowFlags.NoScrollbar)
    if not _lootEnabled then ImGui.PopStyleColor(2) end
    _panelOpen = open
    if not open then mq.exit() end

    if shouldDraw then
        -- Minimize button — top right, y aligned to content start, FA_COMPRESS (core glyph range)
        local _savedPos = ImGui.GetCursorPosVec()
        ImGui.SetCursorPos(ImVec2(ImGui.GetWindowWidth() - 26, _savedPos.y))
        if ImGui.SmallButton(Icons.FA_COMPRESS) then
            _miniMode = true
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text('Activate Mini Mode')
            ImGui.EndTooltip()
        end
        ImGui.SetCursorPos(_savedPos)

        -- Header: logo placeholder + version info
        if _version then
            local sp = ImGui.GetCursorScreenPosVec()
            local dl = ImGui.GetWindowDrawList()
            dl:AddRectFilled(sp, ImVec2(sp.x + 60, sp.y + 60), IM_COL32(40, 80, 140, 200))
            dl:AddRect(sp,       ImVec2(sp.x + 60, sp.y + 60), IM_COL32(100, 150, 210, 180))
            ImGui.Dummy(ImVec2(60, 68))
            ImGui.SameLine()
            ImGui.BeginGroup()
            ImGui.Text(string.format('%s  v%s', _version._AppName, _version._version))
            ImGui.TextDisabled('by ' .. _version._author)
            ImGui.EndGroup()
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
        end

        local enabled = _config:Get('LootEnabled')

        -- Pause / Resume with state labels
        ImGui.PushStyleColor(ImGuiCol.Button,
            enabled and 0.72 or 0.28,
            enabled and 0.22 or 0.12,
            enabled and 0.12 or 0.08,
            1.0)
        if ImGui.Button(enabled and 'Pause' or 'Paused', 100, 0) then
            _loot.SetEnabled(false)
        end
        ImGui.PopStyleColor()

        ImGui.SameLine()

        ImGui.PushStyleColor(ImGuiCol.Button,
            enabled and 0.12 or 0.15,
            enabled and 0.28 or 0.60,
            enabled and 0.10 or 0.12,
            1.0)
        if ImGui.Button(enabled and 'Running' or 'Resume', 100, 0) then
            _loot.SetEnabled(true)
        end
        ImGui.PopStyleColor()

        -- Group pause / resume (static labels — no cross-toon state awareness)
        if _channel and mq.TLO.Me.Grouped() then
            ImGui.PushStyleColor(ImGuiCol.Button,
                enabled and 0.60 or 0.22,
                enabled and 0.18 or 0.10,
                enabled and 0.10 or 0.06,
                1.0)
            if ImGui.Button('Pause All', 100, 0) then
                _channel:Broadcast({ type='set_enabled', value=false })
                _loot.SetEnabled(false)
            end
            ImGui.PopStyleColor()

            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button,
                enabled and 0.10 or 0.12,
                enabled and 0.22 or 0.50,
                enabled and 0.08 or 0.10,
                1.0)
            if ImGui.Button('Resume All', 100, 0) then
                _channel:Broadcast({ type='set_enabled', value=true })
                _loot.SetEnabled(true)
            end
            ImGui.PopStyleColor()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Two-column settings table
        if ImGui.BeginTable('##settings', 2, 0) then
            ImGui.TableSetupColumn('##lbl', ImGuiTableColumnFlags.WidthFixed,   90)
            ImGui.TableSetupColumn('##ctl', ImGuiTableColumnFlags.WidthStretch)

            -- Integration (Framework)
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Integration')
            ImGui.TableNextColumn()
            ImGui.SetNextItemWidth(-1)
            local fwIdx = indexOfStr(FRAMEWORKS, _config:Get('Framework'))
            local fwDisplayLabels = {}
            for _, k in ipairs(FRAMEWORKS) do table.insert(fwDisplayLabels, FRAMEWORK_LABELS[k] or k) end
            local newFwIdx, fwChanged = ImGui.Combo('##fw', fwIdx, fwDisplayLabels, #fwDisplayLabels)
            if fwChanged then
                _config:SetAndSave('Framework', FRAMEWORKS[newFwIdx])
                _wantRestartModal = true
            end

            -- Broadcast (Channel)
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Broadcast')
            ImGui.TableNextColumn()
            ImGui.SetNextItemWidth(-1)
            local chIdx = indexOfStr(CHANNELS, _config:Get('Channel'))
            local chDisplayLabels = {}
            for _, k in ipairs(CHANNELS) do table.insert(chDisplayLabels, CHANNEL_LABELS[k] or k) end
            local newChIdx, chChanged = ImGui.Combo('##ch', chIdx, chDisplayLabels, #chDisplayLabels)
            if chChanged then
                _config:SetAndSave('Channel', CHANNELS[newChIdx])
                _wantRestartModal = true
            end

            -- Weapon Mode
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Weapon Mode')
            ImGui.TableNextColumn()
            ImGui.SetNextItemWidth(-1)
            local wmLabels = {}
            for _, key in ipairs(WEAPONMODES) do
                table.insert(wmLabels, WEAPONMODE_LABELS[key])
            end
            local newWmIdx, wmChanged = ImGui.Combo('##wm', _wmIdx, wmLabels, #wmLabels)
            if wmChanged then
                _wmIdx = newWmIdx
                _config:SetAndSave('WeaponMode', WEAPONMODES[_wmIdx])
            end

            -- Loot Range
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Loot Range')
            ImGui.TableNextColumn()
            ImGui.SetNextItemWidth(-1)
            local curRange = _config:Get('LootRange')
            local newRange, rangeChanged = ImGui.SliderInt('##lootrange', curRange, 50, 600)
            if rangeChanged then
                _config:SetAndSave('LootRange', newRange)
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text('Ctrl+Click to type a value')
                ImGui.EndTooltip()
            end

            -- Use Warp
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Use Warp')
            ImGui.TableNextColumn()
            local useWarp = _config:Get('UseWarp')
            local newUseWarp, _ = ImGui.Checkbox('##usewarp', useWarp)
            if newUseWarp ~= useWarp then
                _config:SetAndSave('UseWarp', newUseWarp)
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text('MQ2RWarp.dll required')
                ImGui.EndTooltip()
            end

            -- Done Looting
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text('Done Looting')
            ImGui.TableNextColumn()
            local announceDone = _config:Get('AnnounceDone')
            local newAnnounceDone, _ = ImGui.Checkbox('##announcedone', announceDone)
            if newAnnounceDone ~= announceDone then
                _config:SetAndSave('AnnounceDone', newAnnounceDone)
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.PushTextWrapPos(280)
                ImGui.TextWrapped('When enabled, characters will broadcast via /g (group chat) when they are finished looting all available corpses')
                ImGui.PopTextWrapPos()
                ImGui.EndTooltip()
            end

            ImGui.EndTable()
        end

        -- Restart required modal
        if _wantRestartModal then
            ImGui.OpenPopup('##e9restart')
            _wantRestartModal = false
        end

        if ImGui.BeginPopupModal('##e9restart', nil, ImGuiWindowFlags.AlwaysAutoResize) then
            ImGui.Text('Restart required — restart e9loot now?')
            ImGui.Spacing()
            if ImGui.Button('Confirm', 80, 0) then
                mq.cmd('/multiline ; /lua stop e9loot ; /timed 50 /lua run e9loot')
                ImGui.CloseCurrentPopup()
            end
            ImGui.SameLine()
            if ImGui.Button('Cancel', 80, 0) then
                ImGui.CloseCurrentPopup()
            end
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text('Setting saved. Will take effect on next restart.')
                ImGui.EndTooltip()
            end
            ImGui.EndPopup()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Action buttons
        local histLabel = _histOpen and 'History [on]' or 'History'
        if ImGui.Button(histLabel, 95, 0) then
            _histOpen = not _histOpen
            _config:SetAndSave('HistoryOpen', _histOpen)
        end

        ImGui.SameLine()

        if ImGui.Button('List Editor', 95, 0) then
            if not _editor.IsOpen() then
                _editor.Open(_config._lists)
            end
        end

        -- Status line anchored to bottom-left of window
        local statusY = ImGui.GetWindowHeight()
            - ImGui.GetTextLineHeight()
            - ImGui.GetStyle().WindowPadding.y
        ImGui.SetCursorPosY(statusY)
        local corpses = #Corpse.FindNearby(_config:Get('LootRange'))
        if _lootEnabled then
            ImGui.TextDisabled(string.format('Nearby corpses: %d  |  Running', corpses))
        else
            ImGui.TextColored(0.9, 0.3, 0.2, 1.0,
                string.format('Nearby corpses: %d  |  Paused', corpses))
        end
    end

    ImGui.End()

    renderHistory()
    _editor.Render()
    _setup.Render()
end

return Panel
