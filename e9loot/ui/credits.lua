-- Credits window: animated developer and inspiration listings

local Credits = {}

local _open = false

local _colorWheel = {}
local _colorTimer = {}

local DATA = {
    Devs = {
        'Tyvion',
        'Claude',
    },
    Inspirations = {
        'Enine',
        'Grimmier',
        'Derple & Algar',
    },
}

local function renderName(name)
    local now = os.clock()
    _colorWheel[name] = _colorWheel[name] or math.random(10000)
    _colorTimer[name] = _colorTimer[name] or now

    if now - _colorTimer[name] > 0.25 then
        _colorWheel[name] = _colorWheel[name] + 1
        _colorTimer[name] = now
    end

    local cw  = _colorWheel[name]
    local len = #name
    for i = 1, len do
        local v   = math.floor(math.sin(0.4 * (cw + i)) * 80 + 160)
        local col = IM_COL32(v, v, v, 255)
        if i > 1 then ImGui.SameLine() end
        ImGui.PushStyleColor(ImGuiCol.Text, col)
        ImGui.Text(name:sub(i, i))
        ImGui.PopStyleColor()
    end
end

function Credits.Open()
    _open = true
end

function Credits.IsOpen()
    return _open
end

function Credits.Render()
    if not _open then return end

    ImGui.SetNextWindowSize(ImVec2(240, 160), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot - Credits', _open)
    _open = open

    if shouldDraw then
        if ImGui.CollapsingHeader('Developed By', ImGuiTreeNodeFlags.DefaultOpen) then
            for _, name in ipairs(DATA.Devs) do
                renderName(name)
            end
        end

        ImGui.Spacing()

        if ImGui.CollapsingHeader('Inspirations & Acknowledgments', ImGuiTreeNodeFlags.DefaultOpen) then
            for _, name in ipairs(DATA.Inspirations) do
                renderName(name)
            end
        end
    end

    ImGui.End()
end

return Credits
