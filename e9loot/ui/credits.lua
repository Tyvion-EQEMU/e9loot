-- Credits tooltip: hover the Credits button in the panel header to show

local Credits = {}

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
        'Derple',
        'Algar',
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
        if i > 1 then ImGui.SameLine(0, 1) end
        ImGui.PushStyleColor(ImGuiCol.Text, col)
        ImGui.Text(name:sub(i, i))
        ImGui.PopStyleColor()
    end
end

function Credits.RenderTooltip()
    local io  = ImGui.GetIO()
    local cx  = io.DisplaySize.x * 0.5
    local cy  = io.DisplaySize.y * 0.33
    ImGui.SetNextWindowPos(ImVec2(cx, cy), ImGuiCond.Always, ImVec2(0.5, 0.5))
    ImGui.SetNextWindowSize(ImVec2(220, 0), ImGuiCond.Always)
    ImGui.BeginTooltip()

    if ImGui.CollapsingHeader('Developed By', ImGuiTreeNodeFlags.DefaultOpen) then
        for _, name in ipairs(DATA.Devs) do
            renderName(name)
        end
    end

    ImGui.Spacing()

    if ImGui.CollapsingHeader('Acknowledgments', ImGuiTreeNodeFlags.DefaultOpen) then
        for _, name in ipairs(DATA.Inspirations) do
            renderName(name)
        end
    end

    ImGui.EndTooltip()
end

return Credits
