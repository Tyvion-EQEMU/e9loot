-- Loot list editor pop-out: tabbed ImGui window per list type, Add-from-Cursor, live filter, Save/Revert per tab

local mq    = require('mq')
local imgui = require('ImGui')

local Editor = {}

local _open   = false
local _lists  = nil
local _filter = {}   -- [listName] = filter string

-- Tab display order and labels
local TAB_ORDER = {
    'currency', 'quest', 'event', 'lore', 'astrial',
    'tiered', 'beasts', 'deva', 'specials',
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
}

-- Per-tab unsaved working copy (list of {name, id})
local _working = {}

local function initWorking(listName)
    local lst    = _lists[listName]
    local copy   = {}
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
    local lst     = _lists[listName]
    local work    = _working[listName]
    local filterKey = '##filter_' .. listName

    -- Live filter input
    imgui.SetNextItemWidth(200)
    local newFilter, _ = imgui.InputText(filterKey, _filter[listName] or '')
    _filter[listName]  = newFilter
    local filterLow    = newFilter:lower()

    imgui.SameLine()

    -- Add from Cursor button
    if imgui.Button('Add from Cursor##' .. listName) then
        local cursor = mq.TLO.Cursor
        if cursor and cursor.ID() and cursor.ID() > 0 then
            local name = cursor.Name() or ''
            local id   = cursor.ID()   or 0
            -- Check not already in working list
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

    imgui.SameLine()

    -- Save tab
    if imgui.Button('Save##' .. listName) then
        -- Apply working list to the real list object
        lst._byName  = {}
        lst._byId    = {}
        lst._ordered = {}
        for _, e in ipairs(work) do
            lst:_add(e.name, e.id, false)
        end
        lst:Save()
    end

    imgui.SameLine()

    -- Revert tab
    if imgui.Button('Revert##' .. listName) then
        lst:Load()
        initWorking(listName)
    end

    imgui.Separator()

    -- Scrollable item list
    imgui.BeginChild('##list_' .. listName, 0, -30, false)

    local toRemove = nil
    for i, entry in ipairs(work) do
        if filterLow == '' or entry.name:lower():find(filterLow, 1, true) then
            imgui.Text(string.format('%d.', i))
            imgui.SameLine()
            imgui.Text(entry.name)
            if entry.id and entry.id > 0 then
                imgui.SameLine()
                imgui.TextDisabled(string.format('[%d]', entry.id))
            end
            imgui.SameLine()
            if imgui.SmallButton('X##' .. listName .. i) then
                toRemove = i
            end
        end
    end

    if toRemove then
        table.remove(work, toRemove)
    end

    imgui.EndChild()
end

function Editor.Render()
    if not _open or not _lists then return end

    imgui.SetNextWindowSize(520, 480, imgui.Cond.FirstUseEver)
    local show, closeBtn = imgui.Begin('e9loot — List Editor', true,
        imgui.WindowFlags.NoCollapse)

    if not show or not closeBtn then
        _open = false
        imgui.End()
        return
    end

    if imgui.BeginTabBar('##tabs') then
        for _, name in ipairs(TAB_ORDER) do
            if imgui.BeginTabItem(TAB_LABELS[name] .. '##' .. name) then
                renderTab(name)
                imgui.EndTabItem()
            end
        end
        imgui.EndTabBar()
    end

    imgui.End()
end

return Editor
