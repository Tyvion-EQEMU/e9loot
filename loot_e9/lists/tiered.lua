-- Tiered gear list: named tier items (T1-T5 etc.) evaluated against tier thresholds for keep/destroy decisions

local Base = require('loot_e9.lists._base')

-- Tiered uses the same name/id lookup as other lists; tier classification is encoded in item names.
-- Items in this list are ALWAYS kept (the tier threshold logic lives in core/loot.lua if needed).
return Base.new('tiered', {
    -- T1 gear
    { name='Bloodforged Helm' },
    { name='Bloodforged Chestplate' },
    { name='Bloodforged Greaves' },
    { name='Bloodforged Gauntlets' },
    { name='Bloodforged Boots' },
    -- T2 gear
    { name='Voidtouched Helm' },
    { name='Voidtouched Chestplate' },
    { name='Voidtouched Greaves' },
    { name='Voidtouched Gauntlets' },
    { name='Voidtouched Boots' },
    -- T3 gear
    { name='Ascendant Helm' },
    { name='Ascendant Chestplate' },
    { name='Ascendant Greaves' },
    { name='Ascendant Gauntlets' },
    { name='Ascendant Boots' },
})
