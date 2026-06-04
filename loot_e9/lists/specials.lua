-- Specials list: user-curated one-off items that don't fit other categories; manual add/remove only

local Base = require('loot_e9.lists._base')

-- Intentionally empty seeds — user adds items via the editor's Add from Cursor button
return Base.new('specials', {})
