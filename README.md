# e9loot

Automated loot management for EverQuest EMU servers running MacroQuest2. e9loot handles
corpse detection, item evaluation, gear upgrades, bank runs, and loot history — designed
to run alongside bot frameworks like RGMercs, E3, and KissAssist.

---

## Use Cases

### Solo or Casual Play
Run e9loot in the background while you grind. It scans for corpses every 5 seconds,
walks or warps to them, evaluates every item against your keep/sell/destroy lists and
gear upgrade logic, and handles the loot window — all without you touching a thing.

### Multi-Toon Boxing with a Bot Framework
e9loot integrates with RGMercs, E3, and KissAssist. When a loot sweep starts it pauses
the framework so bots don't interfere with corpse movement, then resumes when done. A
single **Shift+Click** on the pause button broadcasts pause or resume to your entire
group at once. Loot history from all toons streams into each character's history window
via DanNet or EQBC.

### EMU Progression Gear Collection
On Profusion EMU, the **Astrial** and **Deva** lists automatically collect every
progression-tier item and book page as you kill. When you are ready, `/e9loot bankstuff`
walks you to a banker, shows you everything it found, and deposits it all in one step —
no bag-sorting required.

### Bank Runs
At the end of a session, run `/e9loot bankstuff` on each toon. e9loot auto-targets a
nearby banker (or navigates to one), shows a confirmation window with item details on
hover, deposits everything tagged `bank`, `astrial`, or `deva`, then consolidates your
coins from copper up to platinum automatically.

### Gear Upgrading
Tell e9loot your weapon style (Dual Wield, Two-Handed, Sword and Board) and it scores
every piece of gear it finds against what you have equipped. Items that beat your current
stats are kept; everything else is sold or left behind based on your Trash Price threshold.

---

## Requirements

- **MacroQuest** with Lua support (MQ2Lua plugin loaded)
- **MQ2Nav** — required for walking to corpses or bankers when warp is disabled
- **MQ2DanNet** *(optional)* — enables group-wide broadcast of loot events and pause/resume
- **MQ2EQBC** *(optional)* — alternative to DanNet for group broadcast
- **MQ2RWarp** *(optional)* — enables instant warp to corpses instead of walking

---

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

---

## First Launch

In the EverQuest chat window, type:

```
/lua run e9loot
```

On your very first run, a **Setup dialog** will appear asking you to choose your automation
framework (RGMercs, E3, KissAssist, or None) and broadcast channel (DanNet, EQBC, or
None). These can be changed later from the main panel.

To start e9loot with a specific framework or channel without going through setup:

```
/lua run e9loot framework=rgmercs channel=dannet
```

---

## The Main Window

Once running, a panel appears with:

- **Running / Paused button** — single wide toggle. Click to pause or resume looting for
  this character. **Shift+Click** broadcasts pause/resume to your whole group (requires
  DanNet or EQBC). The button is green when running and red when paused.
- **Settings** — Weapon Mode, Ranged Slot, Loot Range, Use Warp, Done Looting
- **History** — opens the loot history window showing every item decision this session
- **List Editor** — opens the item list manager to add/remove items from all loot categories
- **Bank & Vendor** — opens the Bank & Vendor settings pane (Auto Consolidate Coins, Auto Deposit)
- **System Settings** *(collapsed)* — Integration (framework) and Broadcast (channel); rarely changed after setup
- **Console** *(collapsed)* — scrollable in-panel log output with Log Level, Log to File, and Show Timestamps controls
- **Status** — shows nearby corpse count and current state: `Running`, `Paused`, or `Combat`

The **minimize button** (top-right of the panel) collapses e9loot into a small overlay
showing just the enable toggle and status. A red border on the mini window means your
character is in combat and looting is temporarily suspended.

---

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

---

## BankStuff

Run `/e9loot bankstuff` to deposit your collected items at a banker.

1. e9loot searches for a nearby banker and navigates to them (auto-targets known bankers
   such as Gordon Gekko in Nexus, Banker Ceridan in Plane of Knowledge, or a bank broker
   in the Guild Hall)
2. A confirmation window lists everything it found in your bags tagged as `bank`, `astrial`,
   or `deva` — hover any item name for a full tooltip with icon, lore, stats, and value
3. Click **Bank All** to deposit, **Consolidate Coins** to convert CP/SP/GP → PP only,
   or **Rescan** to refresh the list
4. After depositing, coins are automatically consolidated (configurable in Bank & Vendor settings)

Enable **Auto Deposit** in Bank & Vendor settings to skip the confirmation window entirely.

---

## Loot Lists

Items are matched against named lists in priority order. See [Loot Lists](docs/loot-lists.md)
for a full explanation of each list type and how to manage them.

---

## Configuration

All settings are explained in [Configuration](docs/configuration.md).

---

## Slash Commands

Full command reference in [Commands](docs/commands.md).

---

## Per-Character vs Shared Settings

Some settings (Framework, Channel, Loot Range, Use Warp, etc.) are **shared** — changing
them on one character updates all characters on the next restart. Others (Weapon Mode,
Ranged Slot, Loot Enabled) are **per-character** so each toon can have its own values.

---

## Config Files

All e9loot files are kept in their own subfolder so they don't clutter the main config directory:

```
<MQ2 config dir>/e9loot/
├── SharedSettings_<Server>.ini
├── CharSettings_<Server>_<CharName>.ini
├── CharLogs_<Server>_<CharName>.log
├── LootList_<Server>_currency.txt
├── LootList_<Server>_quest.txt
└── ... (one LootList txt per list type)
```

The folder is created automatically on first run.

---

## Support

- Report bugs or request features via [GitHub Issues](../../issues)
- Future plans in [ROADMAP.md](ROADMAP.md)
