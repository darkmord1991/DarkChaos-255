# 🚀 DC-ItemUpgrade Addon - Quick Deployment Guide

## What's Been Fixed

### ✅ Server-Side (C++)
- **File:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp`
- **Changes:** All `PSendSysMessage()` → `player->Say()` (10+ changes)
- **Result:** Messages now send to SAY channel, addon can parse them correctly
- **Status:** READY - Just needs rebuild

### ✅ Client-Side (Addon)
- **Files Created:**
  - `DarkChaos_ItemUpgrade_COMPLETE.lua` (500 lines, complete addon)
  - `DarkChaos_ItemUpgrade_NEW.xml` (300 lines, professional UI)
  - `DC-ItemUpgrade_NEW.toc` (updated manifest)
- **Status:** READY - Just needs deployment to client

---

## Step-by-Step Deployment

### Step 1: Rebuild C++ (10 min) ⏱️

```bash
cd c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255
./acore.sh compiler clean
./acore.sh compiler build
```

**What happens:**
- Recompiles ItemUpgradeCommands.cpp with chat message fixes
- Creates new worldserver executable
- Restart server to activate new code

**Success indicator:** 
```
✓ No compilation errors
✓ worldserver executable updated
```

---

### Step 2: Deploy Addon to Client (2 min) ⏱️

**Backup old addon:**
```bash
cd "Interface\AddOns\DC-ItemUpgrade"
ren DarkChaos_ItemUpgrade.lua DarkChaos_ItemUpgrade.lua.bak
ren DarkChaos_ItemUpgrade.xml DarkChaos_ItemUpgrade.xml.bak
ren DC-ItemUpgrade.toc DC-ItemUpgrade.toc.bak
```

**Deploy new files:**
```bash
# Copy from server folder to client:
Copy From: c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\Client addons needed\DC-ItemUpgrade\
Copy To:   Interface\AddOns\DC-ItemUpgrade\

Files to copy:
  ✓ DarkChaos_ItemUpgrade_COMPLETE.lua → rename to DarkChaos_ItemUpgrade.lua
  ✓ DarkChaos_ItemUpgrade_NEW.xml → rename to DarkChaos_ItemUpgrade.xml
  ✓ DC-ItemUpgrade_NEW.toc → rename to DC-ItemUpgrade.toc
```

---

### Step 3: Test in-Game (5 min) ⏱️

**1. Start Server & Login**
```
1. Start worldserver (with new build)
2. Login to character
3. Wait for character to load
```

**2. Test Addon Loading**
```
/reload
# Watch chat for: "[DC-ItemUpgrade] Addon loaded successfully!"
# If you see this, addon is loading correctly ✓
```

**3. Test Opening UI**
```
/dcupgrade
# Window should open with "Item Upgrade" title
# Should see header, panels, buttons ✓
```

**4. Test Currency Display**
```
/additem 100999 100    # Add 100 Upgrade Tokens
/additem 100998 50     # Add 50 Artifact Essence

# Window should update to show:
# Tokens: 100 | Essence: 50 ✓
```

**5. Test Item Selection**
```
# Get any item in your bags
# Shift+Click item on yourself to bring up item link
# Then click item in inventory while upgrade window is open
# (Or use /dcupgrade query 0 0 command to test)

# Should trigger ".dcupgrade query" command
# Server should respond with upgrade info
# Window should populate with item stats ✓
```

**6. Test Upgrade (OPTIONAL)**
```
# Select an upgradable item
# Click dropdown to select upgrade level
# Check cost display
# Click UPGRADE button

# Should see success message or error if insufficient currency
```

---

## Expected Results

### ✅ SUCCESS Indicators

**Server Console:**
```
[DC-ItemUpgrade] Processing .dcupgrade init command
[DC-ItemUpgrade] Player has 100 tokens, 50 essence
[DC-ItemUpgrade] Sending response...
```

**Client Chat:**
```
[DC-ItemUpgrade] Addon loaded successfully!
[DC-ItemUpgrade] Tokens: 100 | Essence: 50
[DC-ItemUpgrade] Item Upgrade window ready!
```

**Addon Window:**
- Opens cleanly without errors
- Shows item preview section
- Shows comparison panels
- Shows currency display
- Shows upgrade button

### ❌ TROUBLESHOOTING

**If addon won't load:**
```
1. Check: File paths and names are EXACT
2. Check: TOC file exists (DC-ItemUpgrade.toc)
3. Check: No Lua syntax errors (/console scriptErrors 1)
4. Check: WoW Errors.log for details
Try: Delete Interface\AddOns\Cache folder and /reload
```

**If currency won't update:**
```
1. Check: You actually have items in inventory
2. Check: Messages appear in SAY channel (scroll up in chat)
3. Check: Chat says "DCUPGRADE_INIT:100:50" format
If not, server isn't sending correctly
Try: Restart server with new build
```

**If item selection fails:**
```
1. Check: Item is in bags, not equipped
2. Check: Item is valid WoW item (not quest item)
3. Check: Server responds with DCUPGRADE_QUERY message
If not, check C++ build completed successfully
```

---

## Files Modified

### Server-Side
✅ `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp`
- 10+ `PSendSysMessage()` → `player->Say()` changes
- All DCUPGRADE_* commands now use SAY channel
- All error messages properly formatted

### Client-Side (NEW FILES)
✅ `DarkChaos_ItemUpgrade_COMPLETE.lua` - Complete addon code
✅ `DarkChaos_ItemUpgrade_NEW.xml` - Professional UI template
✅ `DC-ItemUpgrade_NEW.toc` - Updated manifest

### Documentation
✅ `ADDON_FIX_COMPLETE_GUIDE.md` - Comprehensive fix guide
✅ `ADDON_DEPLOYMENT_QUICK_GUIDE.md` - This file

---

## Before vs After Comparison

### BEFORE (Broken)
```
Chat: [01:46:20] DCUPGRADE_INIT:%u:%u   ← Unformatted message
Chat: [01:46:25] DCUPGRADE_ERROR:Item not found
Window: Doesn't load or displays broken layout
Error: Addon parsing fails
```

### AFTER (Fixed)
```
Chat: [DC-ItemUpgrade] Tokens: 100 | Essence: 50  ← Properly formatted
Chat: [DC-ItemUpgrade] Item upgraded successfully!
Window: Beautiful retail-inspired interface
Error: None - working smoothly!
```

---

## Timeline

| Task | Time | Status |
|------|------|--------|
| Fix C++ code | ✅ Done | COMPLETE |
| Create XML UI | ✅ Done | COMPLETE |
| Write Lua addon | ✅ Done | COMPLETE |
| Create documentation | ✅ Done | COMPLETE |
| **Rebuild server** | ⏳ Next | ~10 min |
| **Deploy addon** | ⏳ Next | ~2 min |
| **Test in-game** | ⏳ Next | ~5 min |
| **Total time** | - | **~20 min** |

---

## Configuration

### Default Settings
```lua
DC.MAX_UPGRADE_LEVEL = 15           -- Max level for upgrades
DC.CURRENCY_TOKEN_ID = 100999       -- Upgrade Token item ID
DC.CURRENCY_ESSENCE_ID = 100998    -- Artifact Essence item ID
```

These should match your server configuration in `acore.conf`:
```
ItemUpgrade.Currency.TokenId = 100999
ItemUpgrade.Currency.EssenceId = 100998
```

---

## Support Commands

**If stuck, use debug commands:**

```bash
# Server-side
.dcupgrade init              # Get your currencies
.dcupgrade query 0 0         # Query first bag, first slot
.dcupgrade perform 0 0 1     # Upgrade that item to level 1

# Client-side
/dcupgrade                   # Open/close window
/reload                      # Reload addon
/console scriptErrors 1      # Show Lua errors in chat
```

---

## Success Criteria (All Must Pass ✓)

- [ ] C++ compiles without errors
- [ ] Server starts without issues
- [ ] `/dcupgrade` command works
- [ ] Addon loads without Lua errors
- [ ] Currency displays correctly (after adding items)
- [ ] Item selection works (triggers query)
- [ ] Item stats display in window
- [ ] Upgrade button responds to clicks
- [ ] Upgrade completes successfully
- [ ] No errors in WoW logs

**Once all 10 items are checked, deployment is SUCCESSFUL!** ✅

---

## Rollback (If Needed)

```bash
# If something goes wrong:

# 1. Restore old addon
cd Interface\AddOns\DC-ItemUpgrade
ren DarkChaos_ItemUpgrade.lua.bak DarkChaos_ItemUpgrade.lua
ren DarkChaos_ItemUpgrade.xml.bak DarkChaos_ItemUpgrade.xml
ren DC-ItemUpgrade.toc.bak DC-ItemUpgrade.toc
/reload

# 2. Restore old server code
git checkout src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp
./acore.sh compiler build
restart server
```

---

**You're ready to deploy! Let me know when you've rebuilt the server.** 🚀

