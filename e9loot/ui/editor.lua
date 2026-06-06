-- Loot list editor pop-out: tabbed ImGui window per list type, Add-from-Cursor, live filter, Save/Revert per tab

local mq = require('mq')

local Editor = {}

local _open   = false
local _lists  = nil
local _filter = {}

local TAB_ORDER = {
    'currency', 'quest', 'event', 'lore', 'astrial',
    'tiered', 'beasts', 'deva', 'specials',
    'destroy', 'skip',
}
local TAB_LABELS = {
    currency = 'Currency',
    quest    = 'Quest',
    event    = 'Event',
    lore     = 'Lore',
    astrial  = 'Astrial',
    tiered   = 'Tiered',
    beasts   = 'Beasts',
    deva     = 'Deva',
    specials = 'Specials',
    destroy  = 'Force Destroy',
    skip     = 'Force Skip',
}

local _working = {}

local function initWorking(listName)
    local lst  = _lists[listName]
    local copy = {}
    for _, entry in ipairs(lst:Entries()) do
        table.insert(copy, { name=entry.name, id=entry.id })
    end
    _working[listName] = copy
    _filter[listName]  = ''
end

function Editor.Open(lists)
    _lists = lists
    _open  = true
    for _, name in ipairs(TAB_ORDER) do
        initWorking(name)
    end
end

function Editor.IsOpen()
    return _open
end

local function renderTab(listName)
    local lst       = _lists[listName]
    local work      = _working[listName]
    local filterKey = '##filter_' .. listName

    ImGui.SetNextItemWidth(200)
    local newFilter, _ = ImGui.InputText(filterKey, _filter[listName] or '')
    _filter[listName]  = newFilter
    local filterLow    = newFilter:lower()

    ImGui.SameLine()

    if ImGui.Button('Add from Cursor##' .. listName) then
        local cursor = mq.TLO.Cursor
        if cursor and cursor.ID() and cursor.ID() > 0 then
            local name = cursor.Name() or ''
            local id   = cursor.ID()   or 0
            local found = false
            for _, e in ipairs(work) do
                if e.name:lower() == name:lower() then found = true; break end
            end
            if not found then
                table.insert(work, { name=name, id=id })
            end
            mq.cmd('/autoinventory')
        end
    end

    ImGui.SameLine()

    if ImGui.Button('Save##' .. listName) then
        lst._byName  = {}
        lst._byId    = {}
        lst._ordered = {}
        for _, e in ipairs(work) do
            lst:_add(e.name, e.id, false)
        end
        lst:Save()
    end

    ImGui.SameLine()

    if ImGui.Button('Revert##' .. listName) then
        lst:Load()
        initWorking(listName)
    end

    ImGui.Separator()

    ImGui.BeginChild('##list_' .. listName, ImVec2(0, -30), ImGuiChildFlags.None)

    if ImGui.BeginTable('##tbl_' .. listName, 4,
        bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg,
                  ImGuiTableFlags.SizingStretchProp)) then

        ImGui.TableSetupColumn('#',    ImGuiTableColumnFlags.WidthFixed,  30)
        ImGui.TableSetupColumn('Item', ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn('ID',   ImGuiTableColumnFlags.WidthFixed,  65)
        ImGui.TableSetupColumn('',     ImGuiTableColumnFlags.WidthFixed,  22)
        ImGui.TableHeadersRow()

        local toRemove = nil
        for i, entry in ipairs(work) do
            if filterLow == '' or entry.name:lower():find(filterLow, 1, true) then
                ImGui.TableNextRow()

                ImGui.TableNextColumn()
                ImGui.TextDisabled(tostring(i))

                ImGui.TableNextColumn()
                local _, nameClicked = ImGui.Selectable(entry.name .. '##e' .. i, false)
                if nameClicked then
                    mq.cmdf('/itemdisplay "%s"', entry.name)
                end

                ImGui.TableNextColumn()
                if entry.id and entry.id > 0 then
                    ImGui.TextDisabled(tostring(entry.id))
                end

                ImGui.TableNextColumn()
                if ImGui.SmallButton('X##' .. listName .. i) then
                    toRemove = i
                end
            end
        end

        if toRemove then
            table.remove(work, toRemove)
        end

        ImGui.EndTable()
    end

    ImGui.EndChild()
end

function Editor.Render()
    if not _open or not _lists then return end

    ImGui.SetNextWindowSize(ImVec2(520, 480), ImGuiCond.FirstUseEver)
    local open, shouldDraw = ImGui.Begin('e9loot — List Editor', _open,
        ImGuiWindowFlags.None)
    _open = open

    if shouldDraw then
        if ImGui.BeginTabBar('##tabs') then
            for _, name in ipairs(TAB_ORDER) do
                if ImGui.BeginTabItem(TAB_LABELS[name] .. '##' .. name) then
                    renderTab(name)
                    ImGui.EndTabItem()
                end
            end
            ImGui.EndTabBar()
        end
    end

    ImGui.End()
end

return Editor
