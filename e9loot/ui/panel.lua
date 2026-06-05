-- Main ImGui panel: status bar, pause/resume, weapon mode, history table, editor/setup launchers

local mq     = require('mq')
local Corpse = require('e9loot.core.corpse')

local Panel = {}

local _config    = nil
local _loot      = nil
local _setup     = nil
local _editor    = nil
local _framework = nil
local _adapters  = nil
local _channel   = nil

-- Weapon mode combo state
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

-- History window state
local _histOpen   = false
local _histFilter = ''

local DECISION_COLORS = {
    keep    = { 0.3, 1.0, 0.3, 1.0 },
    sell    = { 1.0, 0.8, 0.2, 1.0 },
    destroy = { 0.6, 0.6, 0.6, 1.0 },
    skip    = { 0.5, 0.5, 0.5, 0.7 },
}

local function renderHistory()
    if not _histOpen then return end

    ImGui.SetNextWindowSize(ImVec2(660, 400), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot — Loot History', _histOpen,
        ImGuiWindowFlags.NoCollapse)
    _histOpen = open

    if shouldDraw then
        ImGui.SetNextItemWidth(220)
        local newFilter, _ = ImGui.InputText('##histfilter', _histFilter)
        _histFilter = newFilter
        local filterLow = newFilter:lower()

        ImGui.SameLine()
        if ImGui.Button('Clear Filter') then _histFilter = '' end

        ImGui.Separator()

        local history = _loot.GetHistory()
        local kept, sold, destroyed = 0, 0, 0

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

                local toonLow = (entry.toon or ''):lower()
                if filterLow == '' or entry.name:lower():find(filterLow, 1, true) or toonLow:find(filterLow, 1, true) then
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
                    ImGui.PushStyleColor(ImGuiCol.Text, col[1], col[2], col[3], col[4])
                    local _, nameClicked = ImGui.Selectable(entry.name .. '##h' .. i, false)
                    ImGui.PopStyleColor()
                    if nameClicked and entry.name then
                        mq.cmdf('/itemdisplay "%s"', entry.name)
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

function Panel.Init(config, loot, setup, editor, framework, adapters, channel)
    _config    = config
    _loot      = loot
    _setup     = setup
    _editor    = editor
    _framework = framework
    _adapters  = adapters
    _channel   = channel
    _histOpen  = config:Get('HistoryOpen')
    _wmIdx     = wmIndexOf(config:Get('WeaponMode'))
end

function Panel.Render()
    if not _config then return end

    ImGui.SetNextWindowSize(ImVec2(340, 210), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot', true,
        bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoScrollbar))

    if shouldDraw then
        local enabled = _config:Get('LootEnabled')

        -- Pause button: bright red when running (actionable), dim when already paused
        ImGui.PushStyleColor(ImGuiCol.Button,
            enabled and 0.72 or 0.28,
            enabled and 0.22 or 0.12,
            enabled and 0.12 or 0.08,
            1.0)
        if ImGui.Button('Pause', 100, 0) then
            _config:SetAndSave('LootEnabled', false)
        end
        ImGui.PopStyleColor()

        ImGui.SameLine()

        -- Resume button: bright green when paused (actionable), dim when already running
        ImGui.PushStyleColor(ImGuiCol.Button,
            enabled and 0.12 or 0.15,
            enabled and 0.28 or 0.60,
            enabled and 0.10 or 0.12,
            1.0)
        if ImGui.Button('Resume', 100, 0) then
            _config:SetAndSave('LootEnabled', true)
        end
        ImGui.PopStyleColor()

        ImGui.SameLine()

        local fw = _config:Get('Framework')
        local ch = _config:Get('Channel')
        ImGui.TextDisabled(string.format('[%s/%s]', fw, ch))

        -- Group pause/resume: broadcast to all group members + apply to self
        if _channel and mq.TLO.Me.Grouped() then
            ImGui.PushStyleColor(ImGuiCol.Button,
                enabled and 0.60 or 0.22,
                enabled and 0.18 or 0.10,
                enabled and 0.10 or 0.06,
                1.0)
            if ImGui.Button('Pause All', 100, 0) then
                _channel:Broadcast({ type='set_enabled', value=false })
                _config:SetAndSave('LootEnabled', false)
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
                _config:SetAndSave('LootEnabled', true)
            end
            ImGui.PopStyleColor()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Weapon mode combo
        ImGui.Text('Weapon Mode:')
        ImGui.SameLine()
        ImGui.SetNextItemWidth(160)
        local wmLabels = {}
        for _, key in ipairs(WEAPONMODES) do
            table.insert(wmLabels, WEAPONMODE_LABELS[key])
        end
        local newWmIdx, wmChanged = ImGui.Combo('##wm', _wmIdx, wmLabels, #wmLabels)
        if wmChanged then
            _wmIdx = newWmIdx
            _config:SetAndSave('WeaponMode', WEAPONMODES[_wmIdx])
        end

        -- Loot range slider
        ImGui.Text('Loot Range: ')
        ImGui.SameLine()
        ImGui.SetNextItemWidth(160)
        local curRange = _config:Get('LootRange')
        local newRange, rangeChanged = ImGui.SliderInt('##lootrange', curRange, 50, 600)
        if rangeChanged then
            _config:SetAndSave('LootRange', newRange)
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Navigation mode toggle
        local useWarp = _config:Get('UseWarp')
        local newUseWarp, _ = ImGui.Checkbox('Use /warp (uncheck for /nav)', useWarp)
        if newUseWarp ~= useWarp then
            _config:SetAndSave('UseWarp', newUseWarp)
        end

        local announceDone = _config:Get('AnnounceDone')
        local newAnnounceDone, _ = ImGui.Checkbox('/g Done Looting when sweep clears', announceDone)
        if newAnnounceDone ~= announceDone then
            _config:SetAndSave('AnnounceDone', newAnnounceDone)
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Action buttons
        if ImGui.Button('Change Setup', 110, 0) then
            _setup.Open(_config, _adapters)
        end

        ImGui.SameLine()

        if ImGui.Button('List Editor', 95, 0) then
            if not _editor.IsOpen() then
                _editor.Open(_config._lists)
            end
        end

        ImGui.SameLine()

        local histLabel = _histOpen and 'History [on]' or 'History'
        if ImGui.Button(histLabel, 95, 0) then
            _histOpen = not _histOpen
            _config:SetAndSave('HistoryOpen', _histOpen)
        end

        ImGui.Spacing()

        local corpses = #Corpse.FindNearby(_config:Get('LootRange'))
        local paused  = _framework and _framework:IsPaused() or false
        ImGui.Text(string.format('Nearby corpses: %d  |  %s', corpses,
            paused and 'Framework PAUSED' or 'Running'))
    end

    ImGui.End()

    renderHistory()
    _editor.Render()
    _setup.Render()
end

return Panel
