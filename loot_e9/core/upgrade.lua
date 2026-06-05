-- Weapon/armor upgrade evaluation: compares item stats against equipped gear by slot, decides keep-or-destroy

local mq = require('mq')

local Upgrade = {}

-- Numeric worn-slot IDs (from item.WornSlot(i)) that are weapon or shield slots
local PRIMARY_SLOT   = 13
local SECONDARY_SLOT = 14

-- Slots we skip entirely — non-gear equippables
local SKIP_SLOTS = { [0]=true, [21]=true, [22]=true }  -- Charm, Powersource, Ammo

-- Weapon quality: higher damage-to-delay ratio is better
local function weaponScore(item)
    local dmg = item.Damage()   or 0
    local dly = item.ItemDelay() or item.Delay() or 1
    if dly == 0 then dly = 1 end
    return (dmg / dly) * 100
end

-- Armor quality: weighted AC + HP + Mana
local function armorScore(item)
    return (item.AC()   or 0) * 3
         + (item.HP()   or 0) * 0.5
         + (item.Mana() or 0) * 0.3
end

-- True if newItem beats whatever is currently in numeric slot slotId
local function isUpgrade(newItem, slotId)
    local equipped = mq.TLO.Me.Inventory(slotId)
    if not equipped or not equipped.ID() or equipped.ID() == 0 then return true end

    if slotId == PRIMARY_SLOT or slotId == SECONDARY_SLOT then
        return weaponScore(newItem) > weaponScore(equipped)
    else
        return armorScore(newItem) > armorScore(equipped)
    end
end

local function itemType(item)
    return (item.Type() or ''):lower()
end

-- EQ reports types as '2h slashing', '2h blunt', '2h piercing', '1h slashing', etc.
local function is2H(t)     return t:sub(1,2) == '2h' end
local function is1H(t)     return t:sub(1,2) == '1h' or t == 'piercing' or t == 'hand to hand' or t == 'martial' end
local function isShield(t) return t:find('shield') ~= nil end

-- True if the item can go in Primary or Secondary slot
local function fitsWeaponSlot(item)
    for i = 1, (item.WornSlots() or 0) do
        local sid = tonumber(item.WornSlot(i)()) or -1
        if sid == PRIMARY_SLOT or sid == SECONDARY_SLOT then return true end
    end
    return false
end

-- False when weaponMode forbids this item's weapon category; armor always passes
local function allowedByMode(item, weaponMode)
    if not fitsWeaponSlot(item) then return true end

    local t = itemType(item)

    if isShield(t) then
        -- DW and 2H modes don't want shields
        return weaponMode ~= 'DW' and weaponMode ~= '2H'
    end

    if weaponMode == 'DW'  then return not is2H(t) end
    if weaponMode == '2H'  then return not is1H(t) end
    if weaponMode == 'SNB' then return not is2H(t) end
    return true  -- ANY
end

-- Returns the first worn slotId where item beats what is currently equipped, or nil.
-- Respects weapon mode filtering. Returns nil for 'always'/'never' modes.
function Upgrade.FindUpgradeSlot(item, weaponMode)
    if not item or not item.ID() or item.ID() == 0 then return nil end
    weaponMode = weaponMode or 'DW'
    if weaponMode == 'always' or weaponMode == 'never' then return nil end
    if not allowedByMode(item, weaponMode) then return nil end

    local wornCount = item.WornSlots() or 0
    if wornCount == 0 then return nil end

    for i = 1, wornCount do
        local slotId = tonumber(item.WornSlot(i)()) or -1
        if slotId >= 0 and not SKIP_SLOTS[slotId] then
            if isUpgrade(item, slotId) then
                return slotId
            end
        end
    end
    return nil
end

-- Public API: true if item is worth keeping given current weapon mode.
-- weaponMode: 'DW' | '2H' | 'SNB' | 'ANY' | 'always' | 'never'
function Upgrade.ShouldKeep(item, weaponMode)
    if not item or not item.ID() or item.ID() == 0 then return false end
    weaponMode = weaponMode or 'DW'
    if weaponMode == 'always' then return true  end
    if weaponMode == 'never'  then return false end
    return Upgrade.FindUpgradeSlot(item, weaponMode) ~= nil
end

return Upgrade
