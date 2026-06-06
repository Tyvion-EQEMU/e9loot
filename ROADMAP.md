# e9loot Roadmap

## Not Yet Built — Backend Exists, No UI

These settings are fully wired in config.lua and the loot engine but have no controls in the main panel yet.

- **Trash Price** (`TrashPrice`) — sell any item worth >= this value in platinum; 0 = sell nothing. Needs a number input in the panel.
- **Warp Distance** (`WarpDist`) — max distance before warping to a corpse (0 = always warp). Needs a slider or input alongside Use Warp.
- **Loot Corpses** (`LootCorpses`) — toggle whether to loot corpses at all (master on/off for corpse looting vs. other loot sources). Needs a checkbox.
- **Loot Pets** (`LootPets`) — toggle whether to loot pet corpses. Needs a checkbox.
- **Loot Group** (`LootGroup`) — toggle whether to loot nearby group members' corpses. Needs a checkbox.
- **Announce Group** (`AnnounceGroup`) — broadcast loot events to group chat. Needs a checkbox.

## Not Yet Built — Weapon Mode Gaps

- **WeaponMode `always` / `never`** — exist in the upgrade engine but are not exposed in the panel dropdown. `always` = keep every equippable item regardless of stats; `never` = never keep gear upgrades. Worth adding to the Weapon Mode combo once we decide on display labels.

## Ideas / Not Yet Defined

_Add things here as they come to you — no need to be ready to build them yet._

## Maybe Someday

- **Server Profiles** — On first run (setup dialog), user selects their server from a dropdown. Each server ships with its own pre-populated loot lists (the `.txt` files backing the lua list system). Planned servers: Profusion EMU, Ascendant, Lazarus. A "Custom" option loads no pre-populated lists — blank slate for players on unlisted servers or those who want full manual control. Selecting a server would copy the appropriate list files into place; switching servers would require a decision on whether to overwrite existing lists or merge. This likely means duplicating the list file tree per server (e.g., `lists/profusion/`, `lists/ascendant/`, `lists/custom/`) and having the loader pick the right path based on the saved server setting.
