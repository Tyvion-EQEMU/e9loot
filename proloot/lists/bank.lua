-- Bank list: items flagged for future bank deposit; autoinventoried until bank-run feature is implemented

local Base = require('proloot.lists._base')

return Base.new('bank', {
    { name='Epic Gemstone of Immortality' },
    { name='Astrial Token' },
    { name='Deva Token' },
})
