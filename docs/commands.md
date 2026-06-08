# Slash Command Reference

All e9loot commands start with `/e9loot` followed by a subcommand.

---

## Starting and Stopping

| Command | Description |
|---------|-------------|
| `/lua run e9loot` | Start e9loot |
| `/lua run e9loot framework=rgmercs channel=dannet` | Start with specific framework and channel |
| `/lua stop e9loot` | Stop e9loot completely |

---

## Looting

| Command | Description |
|---------|-------------|
| `/e9loot loot` | Trigger an immediate loot sweep right now, regardless of the 5-second timer |
| `/e9loot enable` | Resume looting (same as clicking the Running/Paused button in the panel) |
| `/e9loot disable` | Pause looting (same as clicking the Running/Paused button in the panel) |
| `/e9loot reload` | Reload all loot list files from disk without restarting the script |

---

## Banking

| Command | Description |
|---------|-------------|
| `/e9loot bankstuff` | Open the bank confirmation window (or deposit immediately if Auto Deposit is on). Navigates to a nearby banker, then deposits all `bank`, `astrial`, and `deva` items from your bags. After depositing, automatically consolidates coins CP→PP if Auto Consolidate Coins is enabled. |

---

## Interface

| Command | Description |
|---------|-------------|
| `/e9loot show` | Restore the main panel if it has been closed or minimized |
| `/e9loot mini` | Toggle mini mode on/off |
| `/e9loot mini on` | Force mini mode on for this character |
| `/e9loot mini off` | Force mini mode off for this character |
| `/e9loot editor` | Open the List Editor window |
| `/e9loot setup` | Re-open the first-run setup dialog |

---

## Group Features

| Command | Description |
|---------|-------------|
| `/e9loot toggledone` | Toggle the "Done Looting" group announce on or off for all characters in the group simultaneously (broadcasts via DanNet/EQBC) |

The **Running/Paused** button in the panel also supports group control: **Shift+Click** broadcasts
pause or resume to all group members at once (requires DanNet or EQBC).

---

## Settings

```
/e9loot set <setting> <value>
```

Changes a config setting by name. Setting names are case-insensitive.

### Examples

```
/e9loot set lootrange 300
/e9loot set usewarp false
/e9loot set weaponmode 2H
/e9loot set rangedmode bows
/e9loot set trashprice 50
/e9loot set warpdist 150
/e9loot set lootpets true
/e9loot set announcedone false
/e9loot set autodeposit true
/e9loot set autoconsolidatecoins false
```

### All Settable Keys

| Key | Type | Example Values |
|-----|------|----------------|
| `Framework` | string | `none`, `rgmercs`, `e3`, `kissassist` |
| `Channel` | string | `none`, `dannet`, `eqbc` |
| `WeaponMode` | string | `DW`, `2H`, `SNB`, `ANY` |
| `RangedMode` | string | `any`, `bows` |
| `LootRange` | number | `200` |
| `WarpDist` | number | `100` |
| `UseWarp` | boolean | `true`, `false` |
| `TrashPrice` | number | `50` |
| `LootEnabled` | boolean | `true`, `false` |
| `LootCorpses` | boolean | `true`, `false` |
| `LootPets` | boolean | `true`, `false` |
| `LootGroup` | boolean | `true`, `false` |
| `AnnounceGroup` | boolean | `true`, `false` |
| `AnnounceDone` | boolean | `true`, `false` |
| `AutoConsolidateCoins` | boolean | `true`, `false` |
| `BankAutoDeposit` | boolean | `true`, `false` |
| `LogLevel` | number | `1` (Error), `2` (Warn), `3` (Info), `4` (Debug) |
| `LogToFile` | boolean | `true`, `false` |
| `LogTimestamps` | boolean | `true`, `false` |

---

## Help

```
/e9loot
```

Running `/e9loot` with no subcommand prints a summary of available commands to chat.
