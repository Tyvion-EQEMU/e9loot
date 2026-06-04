-- Entry point: wires together config, adapters, core, UI, and lists; drives the main loop via /lua run loot_e9

local mq     = require('mq')
local imgui  = require('ImGui')

local Config  = require('loot_e9.config')
local Lists   = require('loot_e9.lists.init')
local Loot    = require('loot_e9.core.loot')
local Corpse  = require('loot_e9.core.corpse')
local Setup   = require('loot_e9.ui.setup')
local Editor  = require('loot_e9.ui.editor')
local Panel   = require('loot_e9.ui.panel')

-- Framework adapter map
local FRAMEWORK_ADAPTERS = {
    none       = require('loot_e9.adapters.framework.none'),
    rgmercs    = require('loot_e9.adapters.framework.rgmercs'),
    e3         = require('loot_e9.adapters.framework.e3'),
    kissassist = require('loot_e9.adapters.framework.kissassist'),
}

-- Channel adapter map
local CHANNEL_ADAPTERS = {
    none   = require('loot_e9.adapters.channel.none'),
    dannet = require('loot_e9.adapters.channel.dannet'),
    eqbc   = require('loot_e9.adapters.channel.eqbc'),
}

-----------------------------------------------------------------------
-- Parse command-line args: /lua run loot_e9 framework=xxx channel=yyy
-----------------------------------------------------------------------
local function parseArgs(args)
    local opts = {}
    if args then
        for _, arg in ipairs(args) do
            local k, v = arg:match('^(%w+)=(.+)$')
            if k and v then opts[k:lower()] = v:lower() end
        end
    end
    return opts
end

-----------------------------------------------------------------------
-- Startup
-----------------------------------------------------------------------
local opts = parseArgs(arg)

Config:Init()

-- CLI overrides take precedence over saved config
if opts.framework then Config:Set('Framework', opts.framework) end
if opts.channel   then Config:Set('Channel',   opts.channel)   end

-- Resolve adapters
local frameworkName = Config:Get('Framework')
local channelName   = Config:Get('Channel')
local framework = FRAMEWORK_ADAPTERS[frameworkName] or FRAMEWORK_ADAPTERS.none
local channel   = CHANNEL_ADAPTERS[channelName]     or CHANNEL_ADAPTERS.none

-- Load all lists from disk
Lists.LoadAll()

-- Boot channel
channel:Init()

-- Boot core loot engine
Loot.Init(Config, Lists, framework, channel)

-- Wire panel (pass lists ref into config for editor access)
Config._lists = Lists.All()

Panel.Init(Config, Loot, Setup, Editor, framework)

-- Register /e9loot slash command for manual triggers
mq.bind('/e9loot', function(subcmd, ...)
    subcmd = (subcmd or ''):lower()
    if subcmd == 'loot' then
        Loot.LootNearby()
    elseif subcmd == 'setup' then
        Setup.Open(Config, FRAMEWORK_ADAPTERS)
    elseif subcmd == 'editor' then
        Editor.Open(Lists.All())
    elseif subcmd == 'enable' then
        Config:SetAndSave('LootEnabled', true)
        printf('\age9loot enabled')
    elseif subcmd == 'disable' then
        Config:SetAndSave('LootEnabled', false)
        printf('\are9loot disabled')
    elseif subcmd == 'reload' then
        Lists.LoadAll()
        printf('\age9loot: lists reloaded')
    else
        printf('\aye9loot commands: loot | setup | editor | enable | disable | reload')
    end
end)

-- Show setup dialog on first run
if not Config:Get('SetupDone') then
    Setup.Open(Config, FRAMEWORK_ADAPTERS)
end

-----------------------------------------------------------------------
-- ImGui render callback
-----------------------------------------------------------------------
mq.imgui.init('e9loot', function()
    Panel.Render()
end)

-----------------------------------------------------------------------
-- Main loop
-----------------------------------------------------------------------
local LOOT_INTERVAL  = 5000  -- ms between automatic loot sweeps
local lastLootTime   = 0
local lastZone       = mq.TLO.Zone.ID()

printf('\age9loot started — framework: %s  channel: %s', frameworkName, channelName)
printf('\ayType /e9loot for command help.')

while true do
    mq.doevents()
    channel:Tick()

    -- Zone change: clear corpse done-set
    local curZone = mq.TLO.Zone.ID()
    if curZone ~= lastZone then
        Corpse.ResetDone()
        lastZone = curZone
    end

    -- Periodic auto-loot
    local now = mq.gettime()
    if Config:Get('LootEnabled') and (now - lastLootTime) >= LOOT_INTERVAL then
        -- Pause framework while looting, resume after
        local needPause = frameworkName ~= 'none'
        if needPause then framework:PauseAndTrack() end

        Loot.LootNearby()

        if needPause then framework:ResumeAndTrack() end
        lastLootTime = now
    end

    mq.delay(100)
end
