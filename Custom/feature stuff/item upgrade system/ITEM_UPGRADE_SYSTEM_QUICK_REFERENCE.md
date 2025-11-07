# Item Upgrade System - Quick Reference

## The Complete Journey of an Item Upgrade

### 1️⃣ Player Actions (What They Do)

```
/dcupgrade                          → Opens the UI
Drag item to slot                   → Selects item for upgrade
Choose level from dropdown          → Sets target upgrade level
Click "UPGRADE" button              → Sends request to server
[Server processes upgrade]          → Stats increase permanently
Inspect item in inventory           → See increased stats
Log out and back in                 → Upgrade persists!
```

### 2️⃣ Network Messages

```
CLIENT → SERVER:
├─ ".dcupgrade init"
│  └─ Server responds: "DCUPGRADE_INIT:500:250"
│     (You have 500 tokens, 250 essence)
│
├─ ".dcupgrade query <bag> <slot>"
│  └─ Server responds: "DCUPGRADE_QUERY:12345:0:3:245"
│     (Item GUID, current level, tier, base item level)
│
└─ ".dcupgrade perform <bag> <slot> <target_level>"
   └─ Server responds: "DCUPGRADE_SUCCESS:12345:5"
      (Upgrade successful! Item now level 5)
```

### 3️⃣ Database Changes During Upgrade

```
BEFORE UPGRADE:
├─ dc_item_upgrade_state (EMPTY - no record)
└─ Player inventory: Item (245 ilvl, 0 upgrade)

[User clicks UPGRADE to level 5]

AFTER UPGRADE:
├─ dc_item_upgrade_state:
│  └─ player_guid=X, item_guid=Y, upgrade_level=5, tier=3
├─ item_instance: [unchanged]
└─ Player inventory: Item (260 ilvl, 5 upgrade, +25% stats)
```

### 4️⃣ What Actually Happens on Server

```
✅ VALIDATE
   ├─ Item exists in inventory?
   ├─ Player has enough tokens (100999)?
   ├─ Player has enough essence (100998)?
   └─ Target level is valid?

✅ LOOK UP COST
   └─ SELECT token_cost, essence_cost FROM db
      WHERE tier=3 AND upgrade_level=5
      Result: 35 tokens, 0 essence

✅ DEDUCT COSTS
   ├─ Destroy 35 tokens (item 100999)
   ├─ Destroy 0 essence (item 100998)
   └─ Items vanish from inventory

✅ STORE UPGRADE
   └─ INSERT/UPDATE dc_item_upgrade_state:
      player_guid=X, item_guid=Y, upgrade_level=5

✅ NOTIFY CLIENT
   └─ Send: "DCUPGRADE_SUCCESS:Y:5"
```

### 5️⃣ How Stats Are Calculated

```
FORMULA FOR ALL STATS:
   upgraded_stat = base_stat × (1 + bonus%)
   
WHERE:
   bonus% = (upgrade_level / 5) × 0.25

EXAMPLES:
   Level 1: (1/5) × 0.25 = 5%     → Stats 105% of base
   Level 5: (5/5) × 0.25 = 25%    → Stats 125% of base
   Level 10: (10/5) × 0.25 = 50%  → Stats 150% of base
   Level 15: (15/5) × 0.25 = 75%  → Stats 175% of base

ITEM LEVEL:
   new_ilvl = base_ilvl + (upgrade_level × 3)
   
   Example: 245 base
   ├─ Level 1: 245 + 3 = 248
   ├─ Level 5: 245 + 15 = 260
   ├─ Level 10: 245 + 30 = 275
   └─ Level 15: 245 + 45 = 290
```

### 6️⃣ How Upgrades Persist

```
LOGOUT:
   1. Item has upgrade_level = 5 in memory
   2. Server saves to dc_item_upgrade_state table
   3. Table stores: player_guid, item_guid, upgrade_level=5

CHARACTER OFFLINE:
   → Upgrade data stays in database

LOGIN:
   1. Server loads character from database
   2. Server loads dc_item_upgrade_state for all items
   3. For your item: upgrade_level = 5
   4. Client calculates: stats × 1.25, ilvl = 260
   5. Item appears with FULL UPGRADE APPLIED
```

### 7️⃣ The Key Insight

```
UPGRADE STATE LIVES HERE:
   
   dc_item_upgrade_state table
   ├─ player_guid = Your character ID
   ├─ item_guid = Unique item ID
   ├─ upgrade_level = 0-15
   └─ tier = 1-5

EVERY TIME YOU:
├─ Open the addon → Server queries this table
├─ Close the addon → Data still there
├─ Log out → Data saved in this table
├─ Log in → Data reloaded from this table
└─ Delete the item → Data gets orphaned (harmless)

THE ITEM GUID NEVER CHANGES:
   ├─ Item has same GUID before upgrade
   ├─ Item has same GUID after upgrade
   ├─ Database has one row: GUID → upgrade_level
   └─ Stats calculated from this value whenever needed
```

---

## 📊 Your Screenshot Explained

```
UI SHOWS:
┌─────────────────────────────┐
│ Item Upgrade               │
├─────────────────────────────┤
│ [Item Icon]                │
│ Velen's Pants of Triumph   │
│                            │
│ Upgrade 0/[5]              │ ← Currently level 0, max 15 (example shows [5])
│ Item Level 245             │ ← Base level (245 + 0×3)
│                            │
│ Cost: 15 Tokens            │ ← From db_item_upgrade_costs
│ [UPGRADE BUTTON]           │
│                            │
└─────────────────────────────┘

WHEN YOU CLICK UPGRADE:
   1. Server: Looks up tier 3, level 1 → 15 tokens needed
   2. Server: Checks you have 15 tokens ✅
   3. Server: Destroys 15 tokens from inventory
   4. Server: Updates dc_item_upgrade_state:
      ├─ Before: (no record or level 0)
      └─ After: level 1, tier 3
   5. Addon: Shows success message
   6. Your UI: Item now shows "Upgrade 1/15"
   7. Your stats: Increased by 5% (+5 to all stats)
   8. Your ilvl: Now 248 (245 + 1×3)

PERMANENT:
   ├─ Close addon → Item stays level 1
   ├─ Switch characters → Item stays level 1 (other char not affected)
   ├─ Logout → Item stays level 1 (data in db)
   ├─ Server restart → Item stays level 1 (db persists)
   └─ Next week → Item still level 1 forever!
```

---

## The Three Key Components

### 1. CLIENT (Your Addon)
```
├─ Sends commands to server
├─ Receives responses via chat
├─ Calculates and displays stats client-side
├─ Shows UI to player
└─ Never actually processes upgrades
```

### 2. SERVER (ItemUpgradeCommands.cpp)
```
├─ Receives commands
├─ Validates everything
├─ Deducts costs from inventory
├─ Updates database
├─ Sends response to addon
└─ This is where real upgrades happen
```

### 3. DATABASE (Two Tables)
```
dc_item_upgrade_state (characters DB):
├─ Stores: Which items belong to which player
├─ Stores: What level each item is upgraded to
├─ Stores: What tier each item is
└─ Used: When loading character, when applying upgrades

dc_item_upgrade_costs (world DB):
├─ Stores: Cost matrix for all upgrade levels
├─ Stores: How many tokens/essence each level costs
├─ Stores: Data for all 5 tiers × 15 levels = 75 rows
└─ Used: When looking up upgrade cost
```

---

## Common Questions Answered

### Q: Where is my upgrade saved?
**A:** In the `dc_item_upgrade_state` table in your character's database. One row per upgraded item, storing the upgrade level.

### Q: Do I lose the upgrade if I drop the item?
**A:** Yes - if you drop it, another player picks it up, the upgrade goes away (item GUID changes). The old GUID still exists in the database but points to nothing.

### Q: Can I downgrade/refund an upgrade?
**A:** No - upgrades are permanent and one-way only. No refunds of tokens/essence.

### Q: Does the upgrade show in tooltips?
**A:** Yes - the addon (or custom code) can display a tooltip line showing the upgrade level.

### Q: What if I delete my character?
**A:** The dc_item_upgrade_state rows for that character's items stay in the database (harmless orphaned data).

### Q: What if server crashes during upgrade?
**A:** The transaction either completes (tokens deducted + db updated) or fails completely (rollback, tokens stay, db unchanged). No partial upgrades possible.

---

## The Path from Click to Permanent Change

```
1. CLICK UPGRADE in UI
   ↓
2. Addon sends: ".dcupgrade perform 0 5 1"
   ↓
3. Server receives command
   ↓
4. Server validates (has tokens? item exists? level valid?)
   ↓
5. Server queries: "How much does level 1 cost?"
   ↓
6. Database responds: "15 tokens, 0 essence"
   ↓
7. Server checks inventory: "Does player have 15 tokens?"
   ↓
8. Server destroys tokens: 15 × item 100999 deleted
   ↓
9. Server updates database:
   INSERT INTO dc_item_upgrade_state (player_guid, item_guid, upgrade_level, tier)
   VALUES (123456, 9876543211, 1, 3)
   ↓
10. Server sends response: "DCUPGRADE_SUCCESS:9876543211:1"
    ↓
11. Addon receives success message
    ↓
12. Addon updates UI: "Level 1/15 ✅"
    ↓
13. YOUR ITEM IS NOW UPGRADED FOREVER
    ├─ Stats increased by 5%
    ├─ Item level is 248 (was 245)
    ├─ Stored in database persistently
    └─ Will load with this upgrade forever

```

---

## Visual: What Happens in Memory vs Database

```
CLIENT MEMORY (Addon UI):
├─ Selected item: "Velen's Pants"
├─ Current level: 0
├─ Current ilvl: 245
├─ Target level: 1
├─ Preview stats: +5%
└─ Preview ilvl: 248

SERVER MEMORY (While Processing):
├─ Found item: GUID=9876543211
├─ Current upgrade: 0
├─ Cost to upgrade: 15 tokens
├─ Player has: 500 tokens ✅
├─ Processing: Deduct tokens
├─ Processing: Update database
├─ Done: Send success

SERVER DATABASE (Permanent):
dc_item_upgrade_state table:
├─ Row: player=123456, item=9876543211
├─ Before: upgrade_level=0
└─ After: upgrade_level=1 ← STAYS HERE FOREVER

NEXT LOGIN (Days Later):
├─ Server loads character 123456
├─ Queries dc_item_upgrade_state for all items
├─ Finds: item 9876543211 has upgrade_level=1
├─ Client calculates: stats × 1.05, ilvl = 248
├─ Item appears in inventory with upgrade
└─ Player sees: "This item is upgraded!" (if UI shows it)
```

---

**That's how your item upgrades work - stored in database, displayed on-the-fly, permanent forever!** ✅

