# Phase 3C.3 — DBC Integration Guide

**Objective:** Add client-side currency display and enhanced economy support  
**Status:** Ready for Implementation  
**Difficulty:** Medium  
**Time Estimate:** 1-2 hours

---

## 📋 Overview

DBC (Data Block Container) files contain binary game data that the WoW client reads. By updating the following DBC files, you enable:

- ✅ Client-side currency display in inventory/tooltips
- ✅ Custom currency types for tokens and essence
- ✅ Item cost displays showing token requirements
- ✅ Economy-wide currency tracking
- ✅ Professional UI without server-side workarounds

---

## 🛠️ Tools Required

### WDBXEditor (Primary Tool)
**Download:** https://github.com/TOM-CHIAN/WDBXEditor/releases  
**Description:** Visual DBC editor - easiest option  
**Support:** WoW 3.3.5a, most common version

**Steps to Use:**
1. Download WDBXEditor.exe
2. Open: `File → Open` → Select DBC file
3. Add/Edit rows
4. Save: `File → Save`

### CASCExplorer (For Finding Files)
**Download:** https://github.com/WoWTools/CASCExplorer/releases  
**Description:** Browse game data files  
**Use:** Extract DBC files from your WoW installation

### Alternative: Python Script
If you prefer command-line editing, DBC files can be edited with Python scripts using libraries like `blender_io_mesh_obj_import` or custom parsers.

---

## 📁 Required DBC Files

### 1. CurrencyTypes.dbc
**Purpose:** Define custom currency types  
**Location:** `DBFilesClient/CurrencyTypes.dbc`

**Fields to Add (New Row):**

| Field | Value | Type |
|-------|-------|------|
| ID | 395 | INT |
| CategoryID | 15 | INT |
| Flags | 0 | INT |
| Description | Upgrade Token | STRING |
| Name | Upgrade Token | STRING |

**Then add another row for essence:**

| Field | Value | Type |
|-------|-------|------|
| ID | 396 | INT |
| CategoryID | 15 | INT |
| Flags | 0 | INT |
| Description | Artifact Essence | STRING |
| Name | Artifact Essence | STRING |

**Notes:**
- ID 395 & 396 are typically unused in 3.3.5a
- CategoryID 15 = Custom category
- Flags 0 = Normal visibility

---

### 2. CurrencyCategory.dbc
**Purpose:** Organize currency types into categories  
**Location:** `DBFilesClient/CurrencyCategory.dbc`

**Fields (Check if ID 15 exists, if not add):**

| Field | Value | Type |
|-------|-------|------|
| ID | 15 | INT |
| Flags | 0 | INT |
| Name | Custom Upgrades | STRING |

**Notes:**
- This groups related currencies
- Name appears in game menus if UI shows categories

---

### 3. Item.dbc
**Purpose:** Link items to currency costs  
**Location:** `DBFilesClient/Item.dbc`

**For Upgrade Tokens:**
Find all items that can be purchased with tokens and update:
- `ContainedItemCount[0]` = 2 (for cost type = currency)
- `ContainedItemId[0]` = 395 (currency ID)
- `ContainedItemCount` = quantity required

**Example: T1 Upgrade Item (ID 50001)**

| Field | Current | New | Type |
|-------|---------|-----|------|
| ContainedItemCount[0] | 0 | 50 | INT |
| ContainedItemId[0] | 0 | 395 | INT |

**For Artifact Essence:**

| Field | Current | New | Type |
|-------|---------|-----|------|
| ContainedItemCount[1] | 0 | 100 | INT |
| ContainedItemId[1] | 0 | 396 | INT |

---

### 4. ItemExtendedCost.dbc
**Purpose:** Define upgrade costs as currency requirements  
**Location:** `DBFilesClient/ItemExtendedCost.dbc`

**Add New Rows for Each Upgrade Tier:**

**T1 Upgrade Cost:**

| Field | Value | Type | Notes |
|-------|-------|------|-------|
| ID | 2001 | INT | Unique ID |
| RequiredHonorPoints | 0 | INT | Not used |
| RequiredArenaPoints | 0 | INT | Not used |
| RequiredItem[0] | 395 | INT | Upgrade Token |
| RequiredItemCount[0] | 50 | INT | Quantity required |
| CurrencyID[0] | 395 | INT | Currency type |
| CurrencyCount[0] | 50 | INT | Currency amount |

**T2 Upgrade Cost:**

| Field | Value | Type |
|-------|-------|------|
| ID | 2002 | INT |
| RequiredItem[0] | 395 | INT |
| RequiredItemCount[0] | 100 | INT |
| CurrencyID[0] | 395 | INT |
| CurrencyCount[0] | 100 | INT |

**T3 Upgrade Cost:**

| Field | Value | Type |
|-------|-------|------|
| ID | 2003 | INT |
| RequiredItem[0] | 395 | INT |
| RequiredItemCount[0] | 150 | INT |
| CurrencyID[0] | 395 | INT |
| CurrencyCount[0] | 150 | INT |

**T4 Upgrade Cost:**

| Field | Value | Type |
|-------|-------|------|
| ID | 2004 | INT |
| RequiredItem[0] | 395 | INT |
| RequiredItemCount[0] | 250 | INT |
| CurrencyID[0] | 395 | INT |
| CurrencyCount[0] | 250 | INT |

**T5/Artifact Upgrade (Uses Essence):**

| Field | Value | Type |
|-------|-------|------|
| ID | 2005 | INT |
| RequiredItem[0] | 396 | INT |
| RequiredItemCount[0] | 200 | INT |
| CurrencyID[0] | 396 | INT |
| CurrencyCount[0] | 200 | INT |

---

## 🔧 Step-by-Step Implementation

### Method 1: Using WDBXEditor (Easiest)

**Step 1: Extract DBC Files**
```bash
# Use CASCExplorer to extract from your WoW installation
# Or copy from: World of Warcraft/Data/DBFilesClient/
```

**Step 2: Open CurrencyTypes.dbc**
```
1. Launch WDBXEditor.exe
2. File → Open
3. Navigate to DBFilesClient/CurrencyTypes.dbc
4. Click "Show Table"
```

**Step 3: Add Upgrade Token**
```
1. Right-click table → "Add new record"
2. Fill in values:
   - ID: 395
   - Name: Upgrade Token
   - Description: Used to upgrade items T1-T4
   - CategoryID: 15
3. File → Save
```

**Step 4: Add Artifact Essence**
```
1. Right-click table → "Add new record"
2. Fill in values:
   - ID: 396
   - Name: Artifact Essence
   - Description: Used to upgrade artifacts and T5 items
   - CategoryID: 15
3. File → Save
```

**Step 5: Edit Item.dbc**
```
1. File → Open → Item.dbc
2. Find items in range 50001-50004 (T1-T4 upgrades)
3. For each item, set:
   - ContainedItemId[0] = 395
   - ContainedItemCount[0] = (tier specific cost, 50-250)
4. Save
```

**Step 6: Edit ItemExtendedCost.dbc**
```
1. File → Open → ItemExtendedCost.dbc
2. Add 5 new rows (one for each tier)
3. Fill values as shown in table above
4. Save
```

### Method 2: Using Python Script

If you prefer command-line:

```python
#!/usr/bin/env python3
"""
Simple DBC editor for Phase 3C.3 upgrades
Requires: struct, os
"""

import struct
import os

def edit_currency_types(filepath):
    """Add upgrade token and essence entries"""
    # This would require full DBC format knowledge
    # Recommend using WDBXEditor instead for safety
    pass

# Usage:
# python3 edit_dbc.py --add-currencies
```

---

## 📊 DBC File Structure Reference

### CurrencyTypes.dbc Structure
```
Record Format (ID, CategoryID, Flags, Description, Name)
Fixed Strings: NAME, DESCRIPTION
Integer Fields: ID, CategoryID, Flags
```

### Item.dbc Structure
```
Contains fields:
- ContainedItemId[0-2]: Item ID to give cost
- ContainedItemCount[0-2]: Quantity of item
- MaxCount: Stack size limitation
```

### ItemExtendedCost.dbc Structure
```
Contains fields:
- RequiredHonorPoints: PvP honor cost
- RequiredArenaPoints: Arena points cost
- RequiredItem[0-2]: Item ID costs
- RequiredItemCount[0-2]: Item quantities
- CurrencyID[0-2]: Currency types
- CurrencyCount[0-2]: Currency amounts
```

---

## ✅ Verification Checklist

After implementing DBC changes:

- [ ] CurrencyTypes.dbc has IDs 395 & 396 added
- [ ] CurrencyCategory.dbc has category 15 defined
- [ ] Item.dbc items 50001-50004 reference currency 395
- [ ] ItemExtendedCost.dbc has entries 2001-2005 defined
- [ ] DBC files are in correct location (`DBFilesClient/`)
- [ ] WoW client can read files without errors
- [ ] Currency displays in inventory when earned
- [ ] Tooltips show token costs for upgradeable items

---

## 🎮 Client-Side Behavior After DBC Update

### In-Game Display:
```
Player opens inventory → Currency section shows:
┌─────────────────────────┐
│ Upgrade Token: 247      │
│ Artifact Essence: 50    │
└─────────────────────────┘
```

### Item Tooltips:
```
When hovering over upgrade item:
┌────────────────────────────────┐
│ T1 Weapon Upgrade              │
│ Requires: 50 Upgrade Tokens    │
│ Requires: 0 Artifact Essence   │
└────────────────────────────────┘
```

### NPC Shop Display:
```
Vendor NPC (Enhanced with Phase 3C.3):
Upgrade Token Cost: [shown visually]
Item Available Price: 50 Upgrade Tokens
```

---

## 🐛 Troubleshooting DBC Issues

### Issue: DBC Won't Open
**Solution:** Use WDBXEditor - ensure file is from same WoW version

### Issue: Client Crashes on Login
**Solution:** 
- Validate DBC syntax
- Check ID conflicts (ensure 395-396 unused)
- Rebuild cache (delete WoW cache folder)

### Issue: Currency Not Showing
**Solution:**
- Verify CurrencyTypes.dbc was edited
- Check ContainedItemId in Item.dbc
- Ensure files in correct location

### Issue: Item Costs Don't Display
**Solution:**
- Verify ItemExtendedCost.dbc IDs
- Check Item.dbc ContainedItemId/Count fields
- Ensure currency IDs match (395/396)

---

## 📝 Optional Enhancements

### Enhancement 1: Currency Vendors
Add NPC that sells tokens for gold:
- Set CurrencyID in shop data
- Define gold-to-token conversion rate

### Enhancement 2: Seasonal Currencies
Different currencies per season:
- Use IDs 397+ for seasonal variants
- Track separately in db_token_event_config

### Enhancement 3: Currency Exchange
Allow converting tokens to essence:
- Create NPC with custom script
- Implement exchange rates

---

## 🚀 Deployment Checklist

Before going live:

- [ ] DBC files backed up
- [ ] New entries don't conflict with existing IDs
- [ ] Test in development environment first
- [ ] Verify client doesn't crash on load
- [ ] Check currency displays in inventory
- [ ] Test NPC shop functionality
- [ ] Verify item costs show in tooltips
- [ ] Roll back plan ready (old DBC files saved)

---

## 📚 Reference Links

- **WoW DBC Format:** https://wowdev.wiki/DBC
- **CurrencyTypes.dbc:** https://wowdev.wiki/DB/CurrencyTypes
- **ItemExtendedCost.dbc:** https://wowdev.wiki/DB/ItemExtendedCost
- **WDBXEditor GitHub:** https://github.com/TOM-CHIAN/WDBXEditor

---

## Summary

**Phase 3C.3 DBC Integration adds:**
- ✅ Client-side currency tracking
- ✅ Professional item cost display
- ✅ Inventory currency section
- ✅ Enhanced economy visibility
- ✅ Complete game integration

**Estimated Implementation Time:** 1-2 hours  
**Complexity:** Medium (copying values from guide)  
**Tools Needed:** WDBXEditor or CASCExplorer  

**All DBCs can be rolled back** by restoring original files from WoW installation.

---

**Ready to implement? Start with WDBXEditor! 🚀**
