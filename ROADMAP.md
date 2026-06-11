# ProLoot Roadmap

## Completed

- ~~**BankStuff** — `/proloot bankstuff` walks to a banker, deposits all items tagged `bank`, `astrial`, or `deva`, and optionally consolidates coins (CP→SP→GP→PP). Includes a confirmation window with item hover-tooltips (icon, lore, flags, value, weight), click-to-inspect, coin consolidation warning overlay, auto-target of known bankers, nav/warp to banker if out of range, `BankAutoDeposit` setting to skip the confirm window, `AutoConsolidateCoins` setting, and a **Bank & Vendor** settings pane accessible from the main panel.~~

---

## Documentation — High Priority

- **GitHub Wiki** — README and in-repo docs are in good shape. A GitHub Wiki would go deeper: per-setting explanations, weapon mode and ranged mode guide, how the list editor works, FAQ. Should be written for someone who has never used MQ2 Lua before, not just existing EQ bot users.

---

## Not Yet Built — Backend Exists, No UI

These settings are fully wired in config.lua and the loot engine but have no controls in the main panel yet.

- **Trash Price** (`TrashPrice`) — sell any item worth >= this value in platinum; 0 = sell nothing. Needs a number input in the panel.
- **Warp Distance** (`WarpDist`) — max distance before warping to a corpse (0 = always warp). Needs a slider or input alongside Use Warp.
- **Loot Corpses** (`LootCorpses`) — toggle whether to loot corpses at all (master on/off for corpse looting vs. other loot sources). Needs a checkbox.
- **Loot Pets** (`LootPets`) — toggle whether to loot pet corpses. Needs a checkbox.
- **Loot Group** (`LootGroup`) — toggle whether to loot nearby group members' corpses. Needs a checkbox.
- **Announce Group** (`AnnounceGroup`) — broadcast loot events to group chat. Needs a checkbox.

---

## Not Yet Built — Weapon Mode Gaps

- **WeaponMode `always` / `never`** — exist in the upgrade engine but are not exposed in the panel dropdown. `always` = keep every equippable item regardless of stats; `never` = never keep gear upgrades. Worth adding to the Weapon Mode combo once we decide on display labels.

---

## Ideas / Not Yet Defined

- **Import Loot List** — Add an Import button to each list tab in the in-game List Editor. Clicking it would let the user paste or load a newline-separated list of item names, bulk-adding them to that list without having to enter items one at a time. Open questions: input method (multi-line text input popup vs. file path field pointing to a .txt on disk), duplicate handling (skip silently or warn), and whether imported entries should be validated against known item names or accepted as-is.

- **Slot Exclusions / BIS Pinning** — Two related use cases:
  1. *Ignore a slot entirely* — user marks a slot (e.g. Waist) as off-limits and ProLoot never evaluates or replaces whatever is equipped there. Useful for custom/server-specific items with abnormal stats that would otherwise get displaced by standard upgrade logic.
  2. *Pin a target item per slot* — user specifies a "best in slot" item name for a given slot. If that exact item is already equipped, the slot is locked and ignored. If it is not yet equipped, normal upgrade logic runs until the pinned item is found and equipped.
  - Open questions: where does this live in the UI (new tab in editor? per-slot config table in the panel?), how are slots identified to the user (slot name vs slot number), and how does it interact with WeaponMode filtering.

- **Deeper RGMercs Integration — Camp-Aware Looting** — Current framework pause stops pulls but does not stop RGMercs from running toons back to camp. With a small aggro radius and camphard off, this creates a loop: ProLoot warps a toon to a corpse → RGMercs immediately runs them back to camp → loot never completes → repeat. The fix likely requires ProLoot to do more than just pause before a loot sweep:
  1. Record the current camp location (RGMercs command TBD — needs research into what RGMercs exposes)
  2. Fully stop the camp (not just pause pulls) so toons stay where they are during looting
  3. Complete the loot sweep
  4. Re-establish the camp at the saved location
  5. Resume pulls
  - **Reference implementation**: `C:\games\mq-rekka\lua\rgmercs\modules\lootnscoot.lua` shows exactly how RGMercs integrates with an external loot script.

- **Diagnostics / Debug Output** — The Console panel is built. Remaining ideas: a session stats summary (items kept/sold/destroyed, plat value); exporting loot history to CSV; a `/proloot debug` slash command to dump current config, list sizes, and script state in one shot.

- **SellStuff / Restock** — Two remaining LootNScoot features:
  - *SellStuff* — Walk to a vendor and sell everything in bags tagged as `sell`. Would need a merchant-proximity check, iteration over inventory, and `/sellitem` or equivalent commands.
  - *Restock* — After selling, buy back configured consumables (arrows, food, drink, potions) from the vendor. Requires a separate "buy list" data structure.
  - ~~*Bank* — Walk to a banker and deposit items tagged as `bank`. **Implemented as `/proloot bankstuff`** — see Completed above.~~
  - All three would benefit from a `/proloot sell`, `/proloot restock` slash command as well as buttons in the panel.

---

## Maybe Someday

- **Server Profiles** — On first run (setup dialog), user selects their server from a dropdown. Each server ships with its own pre-populated loot lists (the `.txt` files backing the lua list system). Planned servers: Profusion EMU, Ascendant, Lazarus. A "Custom" option loads no pre-populated lists — blank slate for players on unlisted servers or those who want full manual control.
