-- Temporary icon picker — open with /e9loot icontest, remove after selection

local IconTest = {}
local _open = false

-- Font Awesome 4 candidates for the restock broadcast button.
-- All grouped by theme. Tell Claude which ID to keep.
local ICONS = {
    -- A: arrows / directions
    { id='A1', glyph='\xef\x81\xa1', name='arrow-right' },
    { id='A2', glyph='\xef\x85\xb8', name='long-arrow-right' },
    { id='A3', glyph='\xef\x82\xa9', name='arrow-circle-right' },
    { id='A4', glyph='\xef\x82\x8e', name='external-link' },
    { id='A5', glyph='\xef\x82\x8b', name='sign-out' },
    -- B: share / send
    { id='B1', glyph='\xef\x81\xa4', name='share' },
    { id='B2', glyph='\xef\x87\xa0', name='share-alt' },
    { id='B3', glyph='\xef\x87\x98', name='paper-plane' },
    { id='B4', glyph='\xef\x87\x99', name='paper-plane-o (outline)' },
    { id='B5', glyph='\xef\x82\x93', name='upload' },
    -- C: broadcast / comms
    { id='C1', glyph='\xef\x82\xa1', name='bullhorn' },
    { id='C2', glyph='\xef\x82\x9e', name='rss' },
    { id='C3', glyph='\xef\x87\xab', name='wifi' },
    { id='C4', glyph='\xef\x82\xac', name='globe' },
    { id='C5', glyph='\xef\x83\x80', name='users / group' },
    -- D: misc
    { id='D1', glyph='\xef\x83\x81', name='link / chain' },
    { id='D2', glyph='\xef\x81\xb4', name='random / shuffle' },
    { id='D3', glyph='\xef\x81\xb9', name='retweet' },
    { id='D4', glyph='\xef\x83\xac', name='exchange' },
    { id='D5', glyph='\xef\x80\xae', name='bookmark  (current col 6)' },
}

function IconTest.Open()
    _open = true
end

function IconTest.Render()
    if not _open then return end

    ImGui.SetNextWindowSize(ImVec2(320, 520), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot \xe2\x80\x94 Icon Test', _open, ImGuiWindowFlags.None)
    _open = open
    if not shouldDraw then ImGui.End(); return end

    ImGui.TextDisabled('Tell Claude which ID to use for the broadcast button.')
    ImGui.Separator()

    if ImGui.BeginTable('##icontbl', 3,
        bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY),
        ImVec2(0, -1)) then

        ImGui.TableSetupColumn('ID',   ImGuiTableColumnFlags.WidthFixed,   36)
        ImGui.TableSetupColumn('Icon', ImGuiTableColumnFlags.WidthFixed,   52)
        ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableHeadersRow()

        for _, ic in ipairs(ICONS) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text(ic.id)
            ImGui.TableNextColumn()
            ImGui.SmallButton(ic.glyph .. '##it_' .. ic.id)
            ImGui.TableNextColumn()
            ImGui.TextDisabled(ic.name)
        end

        ImGui.EndTable()
    end

    ImGui.End()
end

return IconTest
