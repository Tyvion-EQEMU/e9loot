# e9loot

Automated loot management for EverQuest EMU servers running MacroQuest2. e9loot handles
corpse detection, item evaluation, gear upgrades, and loot history — designed to run
alongside bot frameworks like RGMercs, E3, and KissAssist.

## Requirements

- **MacroQuest2** with Lua support (MQ2Lua plugin loaded)
- **MQ2Nav** — required for walking to corpses when warp is disabled
- **MQ2DanNet** *(optional)* — enables group-wide broadcast of loot events and pause/resume
- **MQ2EQBC** *(optional)* — alternative to DanNet for group broadcast
- **MQ2RWarp** *(optional)* — enables instant warp to corpses instead of walking

## Installation

1. Download or clone this repository.
2. Copy the `e9loot` folder into your MacroQuest `lua` directory:
   ```
   <MQ2 install path>\lua\e9loot\
   ```
   The folder should contain `init.lua` directly inside it — not nested deeper.

3. Verify the structure looks like this:
   ```
   lua/
   └── e9loot/
       ├── init.lua
       ├── config.lua
       ├── core/
       ├── ui/
       ├── lists/
       └── adapters/
   ```

## First Launch

In the EverQuest chat window, type:

```
/lua run e9loot
```

On your very first run, a **Setup dialog** will appear asking you to choose your bot
framework (RGMercs, E3, KissAssist, or None) and broadcast channel (DanNet, EQBC, or
None). These can be changed later from the main panel.

To start e9loot with a specific framework or channel without going through setup:

```
/lua run e9loot framework=rgmercs channel=dannet
```

## The Main Window

Once running, a small panel appears with:

- **Pause / Resume** — stop or start looting for this character only
- **Pause All / Resume All** — broadcast pause/resume to your whole group (requires DanNet or EQBC)
- **Settings** — Integration, Broadcast, Weapon Mode, Ranged Slot, Loot Range, Use Warp, Done Looting
- **History** — opens the loot history window showing every item decision this session
- **List Editor** — opens the item list manager to add/remove items from all loot categories
- **Status bar** — shows nearby corpse count and current state: `Running`, `Paused`, or `Combat`

The **minimize button** (top-right of the panel) collapses e9loot into a small overlay
showing just the enable toggle and status. A red border on the mini window means your
character is in combat and looting is temporarily suspended.

## How Looting Works

Every 5 seconds e9loot scans for NPC corpses within your configured **Loot Range**.
For each corpse it finds (closest first), it:

1. Checks it is safe to loot (not dead, not casting, not moving)
2. Approaches the corpse (warp or walk depending on your setting)
3. Opens the corpse and evaluates each item against your loot lists and upgrade logic
4. Keeps, sells, destroys, or skips each item based on the decision
5. Closes the corpse and marks it done for this zone session

Looting is automatically suspended while your character is in combat and resumes once
all enemies are gone. Your **Pause/Resume** setting is separate from combat — pausing
manually stays paused until you resume manually.

## Loot Lists

Items are matched against named lists in priority order. See [Loot Lists](docs/loot-lists.md)
for a full explanation of each list type and how to manage them.

## Configuration

All settings are explained in [Configuration](docs/configuration.md).

## Slash Commands

Full command reference in [Commands](docs/commands.md).

## Per-Character vs Shared Settings

Some settings (Framework, Channel, Loot Range, Use Warp, etc.) are **shared** — changing
them on one character updates all characters on the next restart. Others (Weapon Mode,
Ranged Slot, Loot Enabled) are **per-character** so each toon can have its own values.

## Config Files

All e9loot files are kept in their own subfolder so they don't clutter the main config directory:

```
<MQ2 config dir>/e9loot/
├── e9loot_<Server>_shared.ini
├── e9loot_<Server>_<CharName>.ini
├── e9loot_<Server>_<CharName>.log
├── e9loot_<Server>_currency.txt
├── e9loot_<Server>_quest.txt
└── ... (one .txt per list type)
```

The folder is created automatically on first run.

## Support

- Report bugs or request features via [GitHub Issues](../../issues)
- Future plans in [ROADMAP.md](ROADMAP.md)
