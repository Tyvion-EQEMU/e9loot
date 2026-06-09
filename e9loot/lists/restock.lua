-- Restock list: item name → target quantity, backed by RestockList_<Server>.txt
-- File format: one entry per line as "ItemName=Qty" (lines starting with # are comments)

local mq = require('mq')

local Restock = {}

local _entries = {}   -- array of {name, qty}, insertion-ordered
local _byName  = {}   -- [lowercase name] -> index in _entries
local _path    = nil

local function dataPath()
    if not _path then
        local server = mq.TLO.EverQuest.Server():gsub(' ', '_')
        local char   = mq.TLO.Me.CleanName()
        _path = string.format('%s/e9loot/RestockList_%s_%s.txt', mq.configDir, server, char)
    end
    return _path
end

local function ensureDir()
    local dir = mq.configDir .. '/e9loot'
    local ok, _, code = os.rename(dir, dir)
    if not ok and code ~= 13 then os.execute('mkdir "' .. dir .. '"') end
end

function Restock.Load()
    _entries = {}
    _byName  = {}
    local f = io.open(dataPath(), 'r')
    if not f then return end
    for line in f:lines() do
        line = line:match('^%s*(.-)%s*$')
        if line ~= '' and line:sub(1,1) ~= '#' then
            local name, qty = line:match('^(.-)%s*=%s*(%d+)%s*$')
            if name and qty then
                name = name:match('^%s*(.-)%s*$')
                local e = { name=name, qty=tonumber(qty) }
                _entries[#_entries+1] = e
                _byName[name:lower()] = #_entries
            end
        end
    end
    f:close()
end

function Restock.Save()
    ensureDir()
    local f = io.open(dataPath(), 'w')
    if not f then return end
    for _, e in ipairs(_entries) do
        f:write(string.format('%s=%d\n', e.name, e.qty))
    end
    f:close()
end

function Restock.GetAll()
    return _entries
end

function Restock.Set(name, qty)
    local key = name:lower()
    if _byName[key] then
        _entries[_byName[key]].qty = qty
    else
        _entries[#_entries+1] = { name=name, qty=qty }
        _byName[key] = #_entries
    end
    Restock.Save()
end

function Restock.Remove(name)
    local key = name:lower()
    local idx = _byName[key]
    if not idx then return end
    table.remove(_entries, idx)
    _byName = {}
    for i, e in ipairs(_entries) do _byName[e.name:lower()] = i end
    Restock.Save()
end

function Restock.Has(name)
    return _byName[(name or ''):lower()] ~= nil
end

function Restock.GetQty(name)
    local idx = _byName[(name or ''):lower()]
    if not idx then return nil end
    return _entries[idx].qty
end

return Restock
