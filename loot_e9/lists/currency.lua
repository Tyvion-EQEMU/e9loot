-- Currency list: coins, tokens, and tradeable monetary items that are always looted regardless of other rules

local Base = require('loot_e9.lists._base')

return Base.new('currency', {
    -- Server tokens / advancement stones
    { name='Astrial Token' },
    { name='Deva Token' },
    { name='Mark of Valor' },
    { name='Stone of Advancement' },
    { name='Coin of the Realm' },
    { name='War Coin' },
    { name='Crystallized Experience' },
    { name='Green Stone of Minor Advancement' },
    { name='Frosty Stone of Hearty Advancement' },
    { name='Fiery Stone of Incredible Advancement' },
    { name='Epic Gemstone of Immortality' },
    { name='Overlords Anguish Stone' },
    { name="Stone of Fusion's Horror" },
    { name='Token of Discord' },
    -- Timekeeper tokens
    { name='Timekeeper Credit Token - 50 Timekeeper Credits' },
    { name='Timekeeper Credit Token - 100 Timekeeper Credits' },
    { name='Timekeeper Credit Token - 500 Timekeeper Credits' },
    -- AA tokens
    { name="Advancement Token - 50 AA's" },
    { name="Advancement Token - 100 AA's" },
    { name="Advancement Token - 500 AA's" },
    -- Platinum bags
    { name='Heavy Bag of Platinum' },
    { name='Huge Bag of Platinum' },
    { name='Moneybags - Bag of Platinum Pieces' },
    { name='Moneybags - Heavy Bag of Platinum!' },
    -- Unidentified / special drops
    { name='Unidentified item' },
})
