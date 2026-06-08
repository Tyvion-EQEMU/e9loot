-- Entry point: wires together config, adapters, core, UI, and lists; drives the main loop via /lua run e9loot

local mq     = require('mq')
local imgui  = require('ImGui')

-- Version block — single source of truth
local Version = {
    _AppName = 'e9loot',
    _version = '0.7.0',
    _author  = 'Tyvion',
}

local Config  = require('e9loot.config')
local Logger  = require('e9loot.utils.logger')
local Lists   = require('e9loot.lists.init')
local Loot    = require('e9loot.core.loot')
local Corpse  = require('e9loot.core.corpse')
local Setup   = require('e9loot.ui.setup')
local Editor  = require('e9loot.ui.editor')
local Panel   = require('e9loot.ui.panel')

-- Framework adapter map
local FRAMEWORK_ADAPTERS = {
    none       = require('e9loot.adapters.framework.none'),
    rgmercs    = require('e9loot.adapters.framework.rgmercs'),
    e3         = require('e9loot.adapters.framework.e3'),
    kissassist = require('e9loot.adapters.framework.kissassist'),
}

-- Channel adapter map
local CHANNEL_ADAPTERS = {
    none   = require('e9loot.adapters.channel.none'),
    dannet = require('e9loot.adapters.channel.dannet'),
    eqbc   = require('e9loot.adapters.channel.eqbc'),
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
Logger.Init(Config)

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

mq.cmd('/hidecorpse looted')

-- Boot core loot engine
Loot.Init(Config, Lists, framework, channel)

-- Wire panel (pass lists ref into config for editor access)
Config._lists = Lists.All()

Panel.Init(Config, Loot, Setup, Editor, framework, FRAMEWORK_ADAPTERS, channel, Version)

-- Register /e9loot slash command for manual triggers
mq.bind('/e9loot', function(subcmd, ...)
    subcmd = (subcmd or ''):lower()
    local args = { ... }
    if subcmd == 'loot' then
        Loot.LootNearby()
    elseif subcmd == 'setup' then
        Setup.Open(Config, FRAMEWORK_ADAPTERS)
    elseif subcmd == 'editor' then
        Editor.Open(Lists.All())
    elseif subcmd == 'enable' then
        Loot.SetEnabled(true)
        printf('\age9loot enabled')
    elseif subcmd == 'disable' then
        Loot.SetEnabled(false)
        printf('\are9loot disabled')
    elseif subcmd == 'reload' then
        Lists.LoadAll()
        printf('\age9loot: lists reloaded')
    elseif subcmd == 'set' then
        local rawKey = args[1]
        local value  = args[2]
        if rawKey and value then
            local key = nil
            for k in pairs(Config.Defaults) do
                if k:lower() == rawKey:lower() then key = k; break end
            end
            if key then
                Config:SetAndSave(key, value)
                printf('\age9loot: %s = %s', key, tostring(Config:Get(key)))
            else
                printf('\are9loot: unknown setting "%s"', rawKey)
            end
        else
            printf('\aye9loot set <setting> <value>  (e.g. /e9loot set usewarp false)')
        end
    elseif subcmd == 'mini' then
        local miniArg = (args[1] or ''):lower()
        if miniArg == 'on' then
            Panel.SetMini(true)
        elseif miniArg == 'off' then
            Panel.SetMini(false)
        else
            Panel.ToggleMini()
        end
    elseif subcmd == 'show' then
        Panel.Show()
    elseif subcmd == 'toggledone' then
        local newVal = not Config:Get('AnnounceDone')
        Config:SetAndSave('AnnounceDone', newVal)
        channel:Broadcast({ type='set_announcedone', value=newVal })
        printf('\age9loot: Done Looting announce %s (all toons)', newVal and 'ON' or 'OFF')
    else
        printf('\aye9loot commands: loot | mini [on|off] | show | editor | enable | disable | reload | set <setting> <value> | toggledone')
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
local LOOT_INTERVAL = 5000  -- ms between automatic loot sweeps
local lastLootTime  = 0
local lastZone      = mq.TLO.Zone.ID()

printf('\age9loot v%s by %s — framework: %s  channel: %s', Version._version, Version._author, frameworkName, channelName)
printf('\ayType /e9loot for command help.')
Logger.Info('v%s started - framework: %s  channel: %s', Version._version, frameworkName, channelName)

while true do
    mq.doevents()
    channel:Tick()

    -- Zone change: clear corpse done-set
    local curZone = mq.TLO.Zone.ID()
    if curZone and curZone ~= lastZone then
        Corpse.ResetDone()
        lastZone = curZone
    end

    Loot.CombatTick()

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
