# Loot Lists

ProLoot uses a set of named item lists to decide what to do with every item it finds on
a corpse. Lists are checked in a strict priority order — the first match wins.

---

## How Item Evaluation Works

When ProLoot opens a corpse it checks each item in this order:

1. **Skip list** — if the item is here, leave it on the corpse (no-loot override)
2. **Destroy list** — if the item is here, pick it up and destroy it
3. **Keep list** — explicit user override to always keep this item
4. **Bank list** — explicit user override to always keep for banking (see BankStuff below)
5. **Named category lists** — Sell, Quest, Event, Lore, Astrial, Tiered, Beasts, Deva, Specials
6. **Upgrade check** — if the item could replace equipped gear with better stats, keep it
7. **Trash Price** — if the item's vendor value meets your configured threshold, sell it
8. **Default** — skip (leave on corpse)

The skip and destroy lists override everything. If an item is on the skip list it will
never be looted regardless of its value or whether it appears on a keep list.

---

## List Types

### Override Lists (highest priority)

| List | Purpose |
|------|---------|
| **Force Skip** | Never loot these items — leave them on every corpse |
| **Force Destroy** | Always loot and immediately destroy these items |
| **Keep** | Always loot and keep these items |
| **Bank** | Always loot and keep for later banking via `/proloot bankstuff` |

### Named Category Lists

| List | Purpose |
|------|---------|
| **Currency** | Platinum, gold, and server-specific coin items |
| **Sell** | Items to pick up and sell at a vendor |
| **Quest** | Items needed for quests |
| **Event** | Event-specific drops you want to collect |
| **Lore** | Lore items (typically no-drop, high value) |
| **Astrial** | Astrial-tier progression gear and book pages (Profusion EMU) |
| **Tiered** | Tiered gear sets |
| **Beasts** | Beast-specific drops |
| **Deva** | Deva-tier progression gear and book pages (Profusion EMU) |
| **Specials** | Catch-all for special/unique items |

Any item on any of these lists is always looted and put into inventory regardless of
your weapon mode or upgrade settings.

---

## BankStuff and the Bank, Astrial, and Deva Lists

`/proloot bankstuff` scans your bags for items on the **Bank**, **Astrial**, and **Deva**
lists and deposits them all in one bank visit. You do not need to duplicate items across
lists — anything in Astrial or Deva is automatically included in a BankStuff run.

This means you can loot progression gear through your normal loot pass (Astrial/Deva
lists handle the keep decision) and then bank it all at the end of a session with a
single command.

---

## The Upgrade Check

After list matching, items not on any list go through the upgrade evaluator. ProLoot
compares the item's stats against what you currently have equipped in each slot:

- **Weapon slots** (Primary, Secondary) — scored by damage/delay ratio
- **Ranged slot** — scored by damage/delay if Ranged Slot is set to "Only Bows",
  otherwise by AC/HP/Mana
- **All other slots** — scored by a weighted AC + HP + Mana formula

If the item beats what's equipped in any valid slot, it is kept as an upgrade. Your
**Weapon Mode** setting filters which weapon types are considered for Primary/Secondary.
No-drop items that aren't upgrades are always skipped (they can't be picked up to destroy).

---

## The List Editor

Click **List Editor** in the main panel (or `/proloot editor`) to open the editor window.
Click again to close it — the button turns gold when the window is open.

### Adding an Item

1. Pick up the item you want to add (it should be on your cursor)
2. Switch to the relevant tab (Currency, Quest, Destroy, etc.)
3. Click **Add from Cursor** — the item name and ID are added and the item goes to inventory automatically

### Removing an Item

Find the item in the list and click the **X** button on its row.

### Filtering

Use the search box at the top of each tab to filter by name as you type.

### Saving

Changes are **saved automatically** the moment you add or remove an item. Use
**Update For All** to broadcast the updated list to all characters in your group so
they reload immediately without restarting.

---

## List Files

Each list is stored as a plain text file under your MacroQuest config directory.
Files are created automatically on first run if they don't exist.

```
<MQ2 config dir>/proloot/
├── SharedSettings_<Server>.ini
├── CharSettings_<Server>_<CharName>.ini
├── LootList_<Server>_bank.txt
├── LootList_<Server>_currency.txt
├── LootList_<Server>_quest.txt
├── LootList_<Server>_event.txt
├── LootList_<Server>_lore.txt
├── LootList_<Server>_astrial.txt
├── LootList_<Server>_tiered.txt
├── LootList_<Server>_beasts.txt
├── LootList_<Server>_deva.txt
├── LootList_<Server>_specials.txt
├── LootList_<Server>_destroy.txt
└── LootList_<Server>_skip.txt
```

Each file contains one item per line in the format:
```
Item Name|ItemID
```

You can edit these files directly in a text editor — just restart ProLoot or use
`/proloot reload` for changes to take effect.

---

## Tips

- **Currency items** (platinum coins, server tokens) should always be in the Currency list
  so they are never accidentally skipped by the upgrade check.
- **Progression items** (Astrial books, Deva pages) belong in the Astrial or Deva lists —
  they will be looted normally AND automatically included in every BankStuff run.
- **Known-bad items** (vendor junk you never want) go in Force Destroy — this keeps
  corpses clean faster than leaving them.
- **Equipped custom gear** you never want replaced should go in Force Skip until the
  Slot Exclusion feature is built (see ROADMAP).
- Use `/proloot reload` after manually editing list files to pick up changes without
  restarting the script.
