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

-----------------------------------------------------------------------
-- Snake border
-----------------------------------------------------------------------
local function perimeterPoint(pos, size, t)
    local w, h = size.x, size.y
    local d    = (t % 1.0) * (2 * (w + h))
    if d < w then
        return ImVec2(pos.x + d,             pos.y)
    elseif d < w + h then
        return ImVec2(pos.x + w,             pos.y + d - w)
    elseif d < 2 * w + h then
        return ImVec2(pos.x + w - (d - w - h), pos.y + h)
    else
        return ImVec2(pos.x,                 pos.y + h - (d - 2 * w - h))
    end
end

local function snakeDraw(pos, size, lineW)
    if size.x < 4 or size.y < 4 then return end
    local phase = (os.clock() / 1.5) % 1.0
    local dl    = ImGui.GetForegroundDrawList()
    local STEPS = 64
    local TAIL  = 0.28
    for i = 0, STEPS - 1 do
        local t1   = i / STEPS
        local dist = (phase - t1) % 1.0
        if dist < TAIL then
            local bright = 1.0 - (dist / TAIL)
            bright = bright * bright
            local v   = math.min(255, math.floor(bright * 220 + 55))
            local a   = math.floor(bright * 255)
            local p1  = perimeterPoint(pos, size, t1)
            local p2  = perimeterPoint(pos, size, (i + 1) / STEPS)
            dl:AddLine(p1, p2, IM_COL32(v, v, v, a), lineW)
        end
    end
end

-- Called from panel.lua with the button's screen rect
function Credits.DrawSnake(pos, size)
    snakeDraw(pos, size, 2.0)
end

-----------------------------------------------------------------------

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

    -- Snake border around the tooltip window
    snakeDraw(ImGui.GetWindowPosVec(), ImGui.GetWindowSizeVec(), 1.5)

    ImGui.EndTooltip()
end

return Credits
