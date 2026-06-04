-- Currency list: coins, tokens, and tradeable monetary items that are always looted regardless of other rules

local Base = require('loot_e9.lists._base')

return Base.new('currency', {
    -- Platinum/gold/silver/copper drop as coin, not items, but server-specific tokens go here
    { name='Astrial Token' },
    { name='Deva Token' },
    { name='Mark of Valor' },
    { name='Stone of Advancement' },
    { name='Coin of the Realm' },
    { name='War Coin' },
    { name='Crystallized Experience' },
})
