-- Lists bootstrap: loads all list modules, exposes unified lookup API used by core/loot.lua

local Lists = {}

local modules = {
    'sell', 'quest', 'event', 'lore', 'astrial',
    'tiered', 'beasts', 'deva', 'specials',
    'keep', 'bank',      -- explicit keep/bank override lists
    'destroy', 'skip',   -- explicit user override lists (highest eval priority)
}

for _, m in ipairs(modules) do
    Lists[m] = require('proloot.lists.' .. m)
end

function Lists.All()
    local result = {}
    for _, m in ipairs(modules) do result[m] = Lists[m] end
    return result
end

function Lists.LoadAll()
    for _, m in ipairs(modules) do Lists[m]:Load() end
end

function Lists.SaveAll()
    for _, m in ipairs(modules) do Lists[m]:Save() end
end

return Lists
