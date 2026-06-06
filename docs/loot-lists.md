# Loot Lists

e9loot uses a set of named item lists to decide what to do with every item it finds on
a corpse. Lists are checked in a strict priority order — the first match wins.

---

## How Item Evaluation Works

When e9loot opens a corpse it checks each item in this order:

1. **Skip list** — if the item is here, leave it on the corpse (no-loot override)
2. **Destroy list** — if the item is here, pick it up and destroy it
3. **Keep lists** — if the item is on any keep list, pick it up and put it in inventory
4. **Upgrade check** — if the item could replace equipped gear with better stats, keep it
5. **Trash Price** — if the item's vendor value meets your configured threshold, sell it
6. **Default** — skip (leave on corpse)

The skip and destroy lists override everything. If an item is on the skip list it will
never be looted regardless of its value or whether it appears on a keep list.

---

## List Types

### Keep Lists (highest priority after overrides)

| List | Purpose |
|------|---------|
| **Currency** | Platinum, gold, and server-specific coin items |
| **Quest** | Items needed for quests |
| **Event** | Event-specific drops you want to collect |
| **Lore** | Lore items (typically no-drop, high value) |
| **Astrial** | Astrial-tier gear specific to Profusion EMU |
| **Tiered** | Tiered gear sets |
| **Beasts** | Beast-specific drops |
| **Deva** | Deva-tier gear specific to Profusion EMU |
| **Specials** | Catch-all for special/unique items |

Any item on any of these lists is always looted and put into inventory regardless of
your weapon mode or upgrade settings.

### Override Lists

| List | Purpose |
|------|---------|
| **Force Skip** | Never loot these items — leave them on every corpse |
| **Force Destroy** | Always loot and immediately destroy these items |

Use **Force Skip** for items you never want cluttering your inventory. Use **Force
Destroy** for items you want off the corpse (to prevent others from looting) but have
no use for yourself.

---

## The Upgrade Check

After list matching, items not on any list go through the upgrade evaluator. e9loot
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

Click **List Editor** in the main panel to open the editor window.

### Adding an Item

1. Pick up the item you want to add (it should be on your cursor)
2. Switch to the relevant tab (Currency, Quest, Destroy, etc.)
3. Click **Add from Cursor** — the item name and ID are added and the item goes to inventory automatically

### Removing an Item

Find the item in the list and click the **X** button on its row.

### Filtering

Use the search box at the top of each tab to filter by name as you type.

### Saving

Changes are **not saved automatically**. Click **Save** on the tab you edited before
switching tabs or closing the window. Click **Revert** to undo unsaved changes on the
current tab.

---

## List Files

Each list is stored as a plain text file in the `lists/` folder inside the e9loot
directory. Files are created automatically on first run if they don't exist.

```
e9loot/lists/
├── currency.txt
├── quest.txt
├── event.txt
├── lore.txt
├── astrial.txt
├── tiered.txt
├── beasts.txt
├── deva.txt
├── specials.txt
├── destroy.txt
└── skip.txt
```

Each file contains one item per line in the format:
```
Item Name|ItemID
```

You can edit these files directly in a text editor — just restart e9loot or use
`/e9loot reload` for changes to take effect.

---

## Tips

- **Currency items** (platinum coins, server tokens) should always be in the Currency list
  so they are never accidentally skipped by the upgrade check.
- **Known-bad items** (vendor junk you never want) go in Force Destroy — this keeps
  corpses clean faster than leaving them.
- **Equipped custom gear** you never want replaced should go in Force Skip until the
  Slot Exclusion feature is built (see ROADMAP).
- Use `/e9loot reload` after manually editing list files to pick up changes without
  restarting the script.
