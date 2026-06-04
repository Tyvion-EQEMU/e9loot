-- First-launch ImGui setup dialog: auto-detects frameworks, lets user pick framework/channel, saves to config

local mq    = require('mq')
local imgui = require('ImGui')

local Setup = {}

-- Framework and channel options in display order
local FRAMEWORKS = { 'none', 'rgmercs', 'e3', 'kissassist' }
local CHANNELS   = { 'none', 'dannet', 'eqbc' }

local FRAMEWORK_LABELS = {
    none      = 'None (standalone)',
    rgmercs   = 'RGMercs',
    e3        = 'E3Next',
    kissassist = 'KISSAssist',
}
local CHANNEL_LABELS = {
    none   = 'None (solo)',
    dannet = 'DanNet',
    eqbc   = 'EQBC',
}

-- State
local _open          = false
local _config        = nil
local _adapters      = nil  -- { rgmercs=adapter, e3=adapter, kissassist=adapter }
local _fwIdx         = 1    -- selected framework combo index (1-based)
local _chIdx         = 1    -- selected channel combo index (1-based)
local _detected      = {}   -- [name] = true for auto-detected frameworks

local function indexOf(t, val)
    for i, v in ipairs(t) do if v == val then return i end end
    return 1
end

-- Run detection on all framework adapters and mark which are running
local function detect()
    _detected = {}
    for name, adapter in pairs(_adapters) do
        if adapter.Detect and adapter:Detect() then
            _detected[name] = true
        end
    end
end

function Setup.Open(cfg, adapters)
    _config   = cfg
    _adapters = adapters
    _open     = true
    detect()

    -- Pre-select the first detected framework, or the saved one
    local saved = cfg:Get('Framework')
    _fwIdx = indexOf(FRAMEWORKS, saved)
    _chIdx = indexOf(CHANNELS,   cfg:Get('Channel'))

    -- If nothing saved and something detected, auto-select it
    if saved == 'none' then
        for i, name in ipairs(FRAMEWORKS) do
            if _detected[name] then _fwIdx = i; break end
        end
    end
end

function Setup.IsOpen()
    return _open
end

function Setup.Render()
    if not _open then return end

    imgui.SetNextWindowSize(420, 320, imgui.Cond.FirstUseEver)
    local show, closeBtn = imgui.Begin('e9loot — First Time Setup', true,
        imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)

    if not show or not closeBtn then
        imgui.End()
        return
    end

    imgui.TextWrapped('Welcome to e9loot! Choose your combat framework and communication channel.')
    imgui.Separator()
    imgui.Spacing()

    -- Framework picker
    imgui.Text('Combat Framework:')
    imgui.SameLine()
    imgui.SetNextItemWidth(180)
    local fwLabels = {}
    for _, name in ipairs(FRAMEWORKS) do
        local label = FRAMEWORK_LABELS[name]
        if _detected[name] then label = label .. '  [detected]' end
        table.insert(fwLabels, label)
    end
    local changed
    _fwIdx, changed = imgui.Combo('##fw', _fwIdx, fwLabels, #fwLabels)

    imgui.Spacing()

    -- Channel picker
    imgui.Text('Group Channel:   ')
    imgui.SameLine()
    imgui.SetNextItemWidth(180)
    local chLabels = {}
    for _, name in ipairs(CHANNELS) do
        table.insert(chLabels, CHANNEL_LABELS[name])
    end
    _chIdx, changed = imgui.Combo('##ch', _chIdx, chLabels, #chLabels)

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- Detection status
    local anyDetected = false
    for _, v in pairs(_detected) do if v then anyDetected = true; break end end
    if anyDetected then
        imgui.TextColored(0.4, 1.0, 0.4, 1.0, 'Auto-detected: ')
        for name, v in pairs(_detected) do
            if v then
                imgui.SameLine()
                imgui.TextColored(0.4, 1.0, 0.4, 1.0, FRAMEWORK_LABELS[name])
            end
        end
    else
        imgui.TextColored(0.8, 0.8, 0.2, 1.0, 'No running framework detected.')
    end

    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()

    -- Save button
    if imgui.Button('Save & Start', 120, 0) then
        local fw = FRAMEWORKS[_fwIdx]
        local ch = CHANNELS[_chIdx]
        _config:Set('Framework', fw)
        _config:Set('Channel',   ch)
        _config:Set('SetupDone', true)
        _config:Save()
        _open = false
    end

    imgui.SameLine()

    if imgui.Button('Cancel', 80, 0) then
        _open = false
    end

    imgui.End()
end

return Setup
