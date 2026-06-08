# Configuration

e9loot stores settings in two INI files in your MacroQuest config directory:

- `SharedSettings_<Server>.ini` — group-wide settings; one file shared across all characters
- `CharSettings_<Server>_<CharName>.ini` — per-character overrides

You rarely need to edit these directly. All settings are accessible from the main panel
or via the `/e9loot set` command.

---

## Integration (Framework)

**Setting:** `Framework`  
**Shared:** Yes  
**Options:** `None` | `RG Mercs` | `E3` | `Kiss Assist`  
**Location:** System Settings (collapsed section in the main panel)

Which bot framework e9loot works alongside. When a loot sweep starts, e9loot pauses
the framework so it doesn't interfere with movement to corpses, then resumes it when
the sweep is done.

Set to `None` if you are running e9loot standalone without a bot framework.

---

## Broadcast (Channel)

**Setting:** `Channel`  
**Shared:** Yes  
**Options:** `None` | `DanNet` | `EQBC`  
**Location:** System Settings (collapsed section in the main panel)

The network channel used to share loot events and group pause/resume commands across
characters. With DanNet or EQBC enabled, loot history from all group members appears
in each character's history window, and **Shift+Click** on the Running/Paused button
broadcasts pause/resume to the whole group.

Requires the corresponding MQ2 plugin to be loaded (MQ2DanNet or MQ2EQBC).

---

## Weapon Mode

**Setting:** `WeaponMode`  
**Shared:** No (per-character)  
**Options:** `Dual Wield` | `Two-Handed` | `Sword and Board` | `Any / No Restriction`

Controls which weapon types are considered when evaluating gear upgrades for the
Primary and Secondary slots. Items that don't match the mode are not kept as upgrades
even if the stats are better.

| Mode | Primary slot | Secondary slot |
|------|-------------|----------------|
| Dual Wield | 1H weapons only | 1H weapons only |
| Two-Handed | 2H weapons only | N/A (2H occupies both) |
| Sword and Board | 1H weapons only | Shields only |
| Any / No Restriction | Any weapon | Any weapon |

Armor slots (head, chest, legs, etc.) are always evaluated regardless of weapon mode.

---

## Ranged Slot

**Setting:** `RangedMode`  
**Shared:** No (per-character)  
**Options:** `Any Ranged` | `Only Bows`

Controls how items that fit the Ranged equipment slot are evaluated.

- **Any Ranged** — standard upgrade logic using AC/HP/Mana comparison. Any ranged item
  that beats your current equipped item by stats will be kept.
- **Only Bows** — only bow-type items (archery, crossbow) are considered for the ranged
  slot. Non-bow ranged items are skipped entirely. When a bow does compete, it is scored
  on damage/delay ratio rather than AC/HP. Recommended for Rangers and melee characters
  that pull with bows.

---

## Loot Range

**Setting:** `LootRange`  
**Shared:** Yes  
**Range:** 50 – 600 units  
**Default:** 200

The radius around your character that e9loot scans for NPC corpses. Corpses beyond this
distance are ignored until you move closer.

Use **Ctrl+Click** on the slider in the panel to type an exact value.

---

## Use Warp

**Setting:** `UseWarp`  
**Shared:** Yes  
**Default:** `true`

When enabled, e9loot uses `/warp target` (MQ2RWarp) to teleport directly to a corpse
or banker. When disabled, it uses `/nav` to walk there. Requires **MQ2RWarp.dll** to
be loaded.

---

## Warp Distance

**Setting:** `WarpDist`  
**Shared:** Yes  
**Default:** 100

*UI control coming soon — currently set via `/e9loot set warpdist <value>`.*

Maximum distance at which e9loot will warp to a corpse. Corpses closer than this value
are walked to even when Use Warp is enabled. Set to `0` to always warp regardless of
distance.

---

## Done Looting

**Setting:** `AnnounceDone`  
**Shared:** Yes  
**Default:** `true`

When enabled, each character broadcasts `/g Done Looting` in group chat after a sweep
that clears all nearby corpses. Useful for coordinating when the group can move on.

---

## Trash Price

**Setting:** `TrashPrice`  
**Shared:** Yes  
**Default:** 0  

*UI control coming soon — currently set via `/e9loot set trashprice <value>`.*

Minimum platinum value for an item to be automatically sold rather than skipped. Items
worth less than this value that aren't on any keep list are left on the corpse. Set to
`0` to never auto-sell by price.

---

## Loot Enabled

**Setting:** `LootEnabled`  
**Shared:** No (per-character)  
**Default:** `true`

Whether this character is currently looting. Controlled by the **Running/Paused** toggle
button in the panel (click to toggle; Shift+Click broadcasts to the whole group). Saved
per-character so each toon can be individually paused.

---

## Auto Consolidate Coins

**Setting:** `AutoConsolidateCoins`  
**Shared:** Yes  
**Default:** `true`  
**Location:** Bank & Vendor settings pane

When enabled, e9loot automatically converts all carried coins to the highest denomination
(copper → silver → gold → platinum) after each BankStuff deposit. Requires the bank
window to be open — this is why it runs as part of the bank visit rather than on demand.

The **Consolidate Coins** button in the BankStuff confirmation window always runs
regardless of this setting.

---

## Auto Deposit (Bank)

**Setting:** `BankAutoDeposit`  
**Shared:** No (per-character)  
**Default:** `false`  
**Location:** Bank & Vendor settings pane

When enabled, `/e9loot bankstuff` skips the confirmation window and immediately deposits
all `bank`, `astrial`, and `deva` items without prompting. Useful for characters on
scheduled bank runs where you always want to deposit everything.

---

## Console

The **Console** section in the main panel (collapsed by default) provides in-panel log
output and controls for the logging system.

### Log Level

**Setting:** `LogLevel`  
**Shared:** No (per-character)  
**Options:** `1` Error | `2` Warn | `3` Info | `4` Debug  
**Default:** `3` (Info)

Controls how verbose the console output is. Debug shows every item evaluation decision.

### Log to File

**Setting:** `LogToFile`  
**Shared:** No (per-character)  
**Default:** `false`

When enabled, all console output is also written to:
```
<MQ2 config dir>/e9loot/ConsoleLogs_<Server>_<CharName>.log
```

### Show Timestamps

**Setting:** `LogTimestamps`  
**Shared:** No (per-character)  
**Default:** `false`

Prepends a `HH:MM:SS` timestamp to each line in the console output.

---

## Other Toggles (UI coming soon)

These settings exist in the config engine and can be set via `/e9loot set <key> <value>`:

| Setting | Default | Description |
|---------|---------|-------------|
| `LootCorpses` | `true` | Master toggle for NPC corpse looting |
| `LootPets` | `false` | Whether to loot pet corpses |
| `LootGroup` | `false` | Whether to loot nearby group members' corpses |
| `AnnounceGroup` | `false` | Broadcast every loot event to group chat |
