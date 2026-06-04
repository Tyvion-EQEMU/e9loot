-- Main ImGui panel: status bar, enable toggle, Change Setup button, loot history pop-out, editor pop-out launcher

local mq    = require('mq')
local imgui = require('ImGui')

local Panel = {}

local _config    = nil
local _loot      = nil   -- core/loot module ref
local _setup     = nil   -- ui/setup module ref
local _editor    = nil   -- ui/editor module ref
local _framework = nil

-- Weapon mode combo state
local WEAPONMODES       = { 'DW', '2H', 'SNB', 'ANY' }
local WEAPONMODE_LABELS = {
    DW       = 'Dual Wield',
    ['2H']   = 'Two-Handed',
    SNB      = 'Sword and Board',
    ANY      = 'Any / No Restriction',
}
local _wmIdx = 1

local function wmIndexOf(val)
    for i, v in ipairs(WEAPONMODES) do if v == val then return i end end
    return 1
end

-- History window state
local _histOpen     = false
local _histFilter   = ''

-- Color coding for history rows by decision
local DECISION_COLORS = {
    keep    = { 0.3, 1.0, 0.3, 1.0 },
    sell    = { 1.0, 0.8, 0.2, 1.0 },
    destroy = { 0.6, 0.6, 0.6, 1.0 },
}

local function renderHistory()
    if not _histOpen then return end

    imgui.SetNextWindowSize(480, 360, imgui.Cond.FirstUseEver)
    local show, closeBtn = imgui.Begin('e9loot — Loot History', true,
        imgui.WindowFlags.NoCollapse)

    if not show or not closeBtn then
        _histOpen = false
        imgui.End()
        return
    end

    -- Filter box
    imgui.SetNextItemWidth(220)
    local newFilter, _ = imgui.InputText('##histfilter', _histFilter)
    _histFilter = newFilter
    local filterLow = newFilter:lower()

    imgui.SameLine()
    if imgui.Button('Clear Filter') then _histFilter = '' end

    imgui.Separator()

    -- Scrollable history
    imgui.BeginChild('##hist', 0, -40, false)
    local history = _loot.GetHistory()
    local kept, sold, destroyed = 0, 0, 0

    for _, entry in ipairs(history) do
        if filterLow == '' or entry.name:lower():find(filterLow, 1, true) then
            local col = DECISION_COLORS[entry.decision] or { 1,1,1,1 }
            imgui.TextColored(col[1], col[2], col[3], col[4],
                string.format('[%s] %-8s %s (%s)',
                    entry.time, entry.decision:upper(), entry.name, entry.reason))
        end
        if     entry.decision == 'keep'    then kept    = kept    + 1
        elseif entry.decision == 'sell'    then sold    = sold    + 1
        elseif entry.decision == 'destroy' then destroyed = destroyed + 1
        end
    end
    imgui.EndChild()

    imgui.Separator()
    imgui.TextDisabled(string.format(
        'Session: %d kept  |  %d sold  |  %d destroyed',
        kept, sold, destroyed))

    imgui.End()
end

function Panel.Init(config, loot, setup, editor, framework)
    _config    = config
    _loot      = loot
    _setup     = setup
    _editor    = editor
    _framework = framework
    _histOpen  = config:Get('HistoryOpen')
    _wmIdx     = wmIndexOf(config:Get('WeaponMode'))
end

function Panel.Render()
    if not _config then return end

    imgui.SetNextWindowSize(340, 160, imgui.Cond.FirstUseEver)
    local show, closeBtn = imgui.Begin('e9loot', true,
        imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar)

    if not show or not closeBtn then
        imgui.End()
        return
    end

    -- Enable/disable toggle
    local enabled = _config:Get('LootEnabled')
    local newEnabled, _ = imgui.Checkbox('Loot Enabled', enabled)
    if newEnabled ~= enabled then
        _config:SetAndSave('LootEnabled', newEnabled)
    end

    imgui.SameLine()

    -- Framework indicator
    local fw = _config:Get('Framework')
    local ch = _config:Get('Channel')
    imgui.TextDisabled(string.format('[%s/%s]', fw, ch))

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- Weapon mode combo
    imgui.Text('Weapon Mode:')
    imgui.SameLine()
    imgui.SetNextItemWidth(160)
    local wmLabels = {}
    for _, key in ipairs(WEAPONMODES) do
        table.insert(wmLabels, WEAPONMODE_LABELS[key])
    end
    local newWmIdx, wmChanged = imgui.Combo('##wm', _wmIdx, wmLabels, #wmLabels)
    if wmChanged then
        _wmIdx = newWmIdx
        _config:SetAndSave('WeaponMode', WEAPONMODES[_wmIdx])
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- Action buttons row 1
    if imgui.Button('Change Setup', 110, 0) then
        _setup.Open(_config, _framework)
    end

    imgui.SameLine()

    if imgui.Button('List Editor', 95, 0) then
        if _editor.IsOpen() then
            -- already open; bring to front by toggling
        else
            _editor.Open(_config._lists)
        end
    end

    imgui.SameLine()

    local histLabel = _histOpen and 'History [on]' or 'History'
    if imgui.Button(histLabel, 95, 0) then
        _histOpen = not _histOpen
        _config:SetAndSave('HistoryOpen', _histOpen)
    end

    imgui.Spacing()

    -- Status line
    local corpses = #require('loot_e9.core.corpse').FindNearby(200)
    local paused  = _framework and _framework:IsPaused() or false
    local statusTxt = paused and '\arPAUSED' or '\ag'
    imgui.Text(string.format('Nearby corpses: %d  |  %s', corpses,
        paused and 'Framework PAUSED' or 'Running'))

    imgui.End()

    -- Sub-windows
    renderHistory()
    _editor.Render()
    _setup.Render()
end

return Panel
