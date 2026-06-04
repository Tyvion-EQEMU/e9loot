-- Lore items list: no-drop lore gear worth keeping; checked before upgrade logic to force-keep specific pieces

local Base = require('loot_e9.lists._base')

return Base.new('lore', {
    -- Force-keep specific named lore drops regardless of upgrade math
    { name='Eye of the Zburator' },
    { name='Heartstone of Ro' },
    { name='Tear of Solusek' },
})
