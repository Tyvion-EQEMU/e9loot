-- Main ImGui panel: status bar, enable toggle, Change Setup button, loot history pop-out, editor pop-out launcher

local mq     = require('mq')
local Corpse = require('loot_e9.core.corpse')

local Panel = {}

local _config    = nil
local _loot      = nil
local _setup     = nil
local _editor    = nil
local _framework = nil
local _adapters  = nil

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
}

local function renderHistory()
    if not _histOpen then return end

    ImGui.SetNextWindowSize(ImVec2(480, 360), ImGuiCond.FirstUseEver)
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

        ImGui.BeginChild('##hist', ImVec2(0, -40), ImGuiChildFlags.None)
        local history = _loot.GetHistory()
        local kept, sold, destroyed = 0, 0, 0

        for _, entry in ipairs(history) do
            local toonLow = (entry.toon or ''):lower()
            if filterLow == '' or entry.name:lower():find(filterLow, 1, true) or toonLow:find(filterLow, 1, true) then
                local col = DECISION_COLORS[entry.decision] or { 1, 1, 1, 1 }
                ImGui.TextColored(col[1], col[2], col[3], col[4],
                    string.format('[%s] %-12s %-8s %s (%s)',
                        entry.time, entry.toon or '?', entry.decision:upper(), entry.name, entry.reason))
            end
            if     entry.decision == 'keep'    then kept      = kept    + 1
            elseif entry.decision == 'sell'    then sold      = sold    + 1
            elseif entry.decision == 'destroy' then destroyed = destroyed + 1
            end
        end
        ImGui.EndChild()

        ImGui.Separator()
        ImGui.TextDisabled(string.format(
            'Session: %d kept  |  %d sold  |  %d destroyed', kept, sold, destroyed))
    end

    ImGui.End()
end

function Panel.Init(config, loot, setup, editor, framework, adapters)
    _config    = config
    _loot      = loot
    _setup     = setup
    _editor    = editor
    _framework = framework
    _adapters  = adapters
    _histOpen  = config:Get('HistoryOpen')
    _wmIdx     = wmIndexOf(config:Get('WeaponMode'))
end

function Panel.Render()
    if not _config then return end

    ImGui.SetNextWindowSize(ImVec2(340, 200), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot', true,
        bit32.bor(ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoScrollbar))

    if shouldDraw then
        -- Enable/disable toggle
        local enabled = _config:Get('LootEnabled')
        local newEnabled, _ = ImGui.Checkbox('Loot Enabled', enabled)
        if newEnabled ~= enabled then
            _config:SetAndSave('LootEnabled', newEnabled)
        end

        ImGui.SameLine()

        local fw = _config:Get('Framework')
        local ch = _config:Get('Channel')
        ImGui.TextDisabled(string.format('[%s/%s]', fw, ch))

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

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        -- Navigation mode toggle
        local useWarp = _config:Get('UseWarp')
        local newUseWarp, _ = ImGui.Checkbox('Use /warp (uncheck for /nav)', useWarp)
        if newUseWarp ~= useWarp then
            _config:SetAndSave('UseWarp', newUseWarp)
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

        local corpses = #Corpse.FindNearby(200)
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
