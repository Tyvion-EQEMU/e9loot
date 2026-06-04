-- INI-based settings: load/save defaults for framework, channel, weaponmode, warpdist, trashprice, and all user toggles

local mq = require('mq')

local function fileExists(path)
    local f = io.open(path, 'r')
    if f then f:close(); return true end
    return false
end

local Config = {}

-- Resolved path: MQ configDir + character name so each toon has its own INI
local function iniPath()
    return string.format('%s/%s_e9loot.ini', mq.configDir, mq.TLO.Me.CleanName())
end

-- Default values — all settings live here; add new keys here first
Config.Defaults = {
    -- Adapter selection
    Framework    = 'none',   -- rgmercs | e3 | kissassist | none
    Channel      = 'none',   -- dannet | eqbc | none

    -- Loot behaviour
    WeaponMode   = 'DW',      -- DW | 2H | SNB | ANY | always | never
    WarpDist     = 100,       -- max distance before warping to corpse (0 = warp always)
    TrashPrice   = 0,         -- sell anything ≥ this value (pp); 0 = sell nothing

    -- Feature toggles
    LootEnabled  = true,
    LootCorpses  = true,
    LootPets     = false,
    LootGroup    = false,     -- loot group members' nearby corpses
    AnnounceGroup = false,    -- broadcast loot events to group channel

    -- UI state (not shown in setup dialog)
    SetupDone    = false,     -- true after first-launch setup is saved
    PanelOpen    = true,
    HistoryOpen  = false,
    EditorOpen   = false,
}

-- Live config table — starts as a copy of defaults, then overwritten by INI
Config.Settings = {}

local function toBool(v)
    if type(v) == 'boolean' then return v end
    if v == nil then return false end
    return tostring(v):lower() == 'true' or tostring(v) == '1'
end

local function coerce(default, raw)
    if raw == nil then return default end
    local t = type(default)
    if t == 'boolean' then return toBool(raw) end
    if t == 'number'  then return tonumber(raw) or default end
    return tostring(raw)
end

function Config:Load()
    -- Start from defaults
    for k, v in pairs(self.Defaults) do
        self.Settings[k] = v
    end

    local ini = iniPath()
    if not fileExists(ini) then return end

    -- mq.ini read helper: mq.TLO.Ini[section][key][default]
    local function get(key, def)
        local val = mq.TLO.Ini(ini, 'e9loot', key, tostring(def))()
        return val
    end

    for k, default in pairs(self.Defaults) do
        local raw = get(k, default)
        self.Settings[k] = coerce(default, raw)
    end
end

function Config:Save()
    local ini = iniPath()
    for k, v in pairs(self.Settings) do
        mq.cmdf('/ini "%s" "e9loot" "%s" "%s"', ini, k, tostring(v))
    end
end

function Config:Get(key)
    if self.Settings[key] == nil then
        return self.Defaults[key]
    end
    return self.Settings[key]
end

function Config:Set(key, value)
    self.Settings[key] = coerce(self.Defaults[key], value)
end

function Config:SetAndSave(key, value)
    self:Set(key, value)
    self:Save()
end

-- Call once at startup
function Config:Init()
    self:Load()
end

return Config
