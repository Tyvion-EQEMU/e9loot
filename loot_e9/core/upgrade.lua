-- Weapon/armor upgrade evaluation: compares item stats against equipped gear by slot, decides keep-or-destroy

local mq = require('mq')

local Upgrade = {}

-- Slots we evaluate for upgrades (EQ slot bit values)
-- We compare by primary stat: AC for armor, damage/ratio for weapons
local ARMOR_SLOTS = {
    Head=1, Chest=2, Arms=3, Wrists=4, Hands=5,
    Legs=6, Feet=7, Back=8, Shoulder=9, Waist=10,
    Neck=11, Ear1=12, Ear2=13, Face=14, Ring1=15, Ring2=16,
}

local WEAPON_SLOTS = {
    Primary=17, Secondary=18, Range=19,
}

-- Returns the equipped item in a named slot, or nil
local function equippedItem(slotName)
    local item = mq.TLO.Me.Inventory(slotName)
    if item and item.ID() and item.ID() > 0 then return item end
    return nil
end

-- Weapon quality metric: lower is better ratio (dmg/dly)
-- We want higher damage-to-delay ratio, so a lower ratio number means faster weapon.
-- For our purposes: score = Damage / Delay * 100 (higher = better)
local function weaponScore(item)
    local dmg = item.Damage() or 0
    local dly = item.Delay()  or 1
    if dly == 0 then dly = 1 end
    return (dmg / dly) * 100
end

-- Armor quality metric: total AC + (heroics and HP weighted)
local function armorScore(item)
    local ac  = item.AC()    or 0
    local hp  = item.HP()    or 0
    local mana= item.Mana()  or 0
    return ac * 3 + hp * 0.5 + mana * 0.3
end

-- Returns true if newItem is a strict upgrade over what is currently equipped in slot
-- slotName must be a string matching EQ's slot name (e.g. "Primary", "Chest")
local function isUpgrade(newItem, slotName)
    local equipped = equippedItem(slotName)
    if not equipped then return true end -- empty slot: always keep

    local isWeapon = WEAPON_SLOTS[slotName] ~= nil
    if isWeapon then
        local newScore = weaponScore(newItem)
        local oldScore = weaponScore(equipped)
        return newScore > oldScore
    else
        local newScore = armorScore(newItem)
        local oldScore = armorScore(equipped)
        return newScore > oldScore
    end
end

-- item.Type() values for weapon classification (lowercased for comparison)
-- 2H types: "two hand slash", "two hand blunt", "two hand pierce"
-- 1H types: "one hand slash", "one hand blunt", "piercing", "hand to hand"
-- Shield types: "shield", "large shield", "medium shield", "small shield"
local function itemType(item)
    return (item.Type() or ''):lower()
end

local function is2H(t)
    return t:find('two hand') ~= nil
end

local function is1H(t)
    return t:find('one hand') ~= nil or t == 'piercing' or t == 'hand to hand'
end

local function isShield(t)
    return t:find('shield') ~= nil
end

-- Returns false when weaponMode forbids this weapon/shield category, true otherwise.
-- Non-weapon items (armor) are always allowed through.
local function allowedByMode(item, weaponMode)
    -- Only gate items that occupy a weapon slot
    local fitsWeapon = item.WornSlot('Primary')() == true
                    or item.WornSlot('Secondary')() == true

    if not fitsWeapon then return true end  -- armor: no restriction

    local t = itemType(item)

    -- Shields are not weapons; gate them per mode
    if isShield(t) then
        -- DW and 2H modes don't want shields; SNB and ANY do
        if weaponMode == 'DW' or weaponMode == '2H' then return false end
        return true
    end

    if weaponMode == 'DW' then
        return not is2H(t)      -- reject 2H weapons
    elseif weaponMode == '2H' then
        return not is1H(t)      -- reject 1H weapons
    elseif weaponMode == 'SNB' then
        return not is2H(t)      -- reject 2H weapons; shields ok
    end
    -- ANY: no restriction
    return true
end

-- Public API: given a cursor item TLO, return true if it's worth keeping as an upgrade.
-- weaponMode: 'DW' | '2H' | 'SNB' | 'ANY' | 'always' | 'never'
function Upgrade.ShouldKeep(item, weaponMode)
    if not item or not item.ID() or item.ID() == 0 then return false end

    weaponMode = weaponMode or 'DW'

    if weaponMode == 'always' then return true  end
    if weaponMode == 'never'  then return false end

    -- Weapon mode gate: reject items incompatible with the player's combat style
    if not allowedByMode(item, weaponMode) then return false end

    -- Determine which slot(s) this item fits
    local slotBitmask = item.ItemSlots()
    if not slotBitmask then return false end

    -- Check each slot the item can go in; keep if it upgrades ANY worn slot
    local allSlots = {}
    for k in pairs(ARMOR_SLOTS)  do allSlots[k] = true end
    for k in pairs(WEAPON_SLOTS) do allSlots[k] = true end

    for slotName, _ in pairs(allSlots) do
        -- item.WornSlot(slotName) returns true when the item fits that slot
        if item.WornSlot(slotName)() == true then
            if isUpgrade(item, slotName) then
                return true
            end
        end
    end

    return false
end

return Upgrade
