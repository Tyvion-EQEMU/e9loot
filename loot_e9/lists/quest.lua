-- Quest items list: items needed for active or anticipated quests; always looted, never destroyed

local Base = require('loot_e9.lists._base')

return Base.new('quest', {
    -- Populate via the editor; seeds are intentionally sparse
    { name='Relic Fragment' },
    { name='Ancient Tablet' },
    { name='Sigil of the Fallen' },
})
