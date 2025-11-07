# 📋 File Deployment Manifest

## Source Files (Server Folder)

### Server Code (Already Fixed)
```
✅ MODIFIED: src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommands.cpp
   - All PSendSysMessage() → player->Say() conversions
   - Ready to compile
```

### Addon Files (NEW - Ready to Deploy)

```
Location: Custom\Client addons needed\DC-ItemUpgrade\

NEW FILES:
  ✅ DarkChaos_ItemUpgrade_COMPLETE.lua  (500 lines, complete addon)
  ✅ DarkChaos_ItemUpgrade_NEW.xml       (300 lines, professional UI)
  ✅ DC-ItemUpgrade_NEW.toc              (updated manifest)

DOCUMENTATION:
  ✅ ADDON_FIX_COMPLETE_GUIDE.md         (comprehensive guide)
```

---

## Deployment Steps

### Step 1: Rebuild Server (C++)

```bash
cd c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255

# Clean and rebuild
./acore.sh compiler clean
./acore.sh compiler build

# Time: ~10 minutes
# Result: Updated worldserver executable
```

---

### Step 2: Prepare Client Addon Folder

```bash
# Navigate to client addon folder
cd Interface\AddOns\DC-ItemUpgrade

# BACKUP old files
ren DarkChaos_ItemUpgrade.lua DarkChaos_ItemUpgrade.lua.backup
ren DarkChaos_ItemUpgrade.xml DarkChaos_ItemUpgrade.xml.backup
ren DC-ItemUpgrade.toc DC-ItemUpgrade.toc.backup

# Verify backups
dir *.backup
# Should show 3 .backup files
```

---

### Step 3: Copy New Addon Files

**Source Path:**
```
c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\
Custom\Client addons needed\DC-ItemUpgrade\
```

**Destination Path:**
```
Interface\AddOns\DC-ItemUpgrade\
```

**Files to Copy:**

| Source File | Destination File | Action |
|-------------|------------------|--------|
| `DarkChaos_ItemUpgrade_COMPLETE.lua` | `DarkChaos_ItemUpgrade.lua` | Copy & Rename |
| `DarkChaos_ItemUpgrade_NEW.xml` | `DarkChaos_ItemUpgrade.xml` | Copy & Rename |
| `DC-ItemUpgrade_NEW.toc` | `DC-ItemUpgrade.toc` | Copy & Rename |

**Using Windows Explorer:**
```
1. Open source folder (server\Custom\Client addons needed\DC-ItemUpgrade\)
2. Copy: DarkChaos_ItemUpgrade_COMPLETE.lua
3. Paste to: Interface\AddOns\DC-ItemUpgrade\
4. Rename to: DarkChaos_ItemUpgrade.lua
5. Repeat for other 2 files
```

**Using Command Prompt:**
```bash
cd Interface\AddOns\DC-ItemUpgrade

# Copy new files
copy "c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\Client addons needed\DC-ItemUpgrade\DarkChaos_ItemUpgrade_COMPLETE.lua" "DarkChaos_ItemUpgrade.lua"

copy "c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\Client addons needed\DC-ItemUpgrade\DarkChaos_ItemUpgrade_NEW.xml" "DarkChaos_ItemUpgrade.xml"

copy "c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\Client addons needed\DC-ItemUpgrade\DC-ItemUpgrade_NEW.toc" "DC-ItemUpgrade.toc"

# Verify
dir DC-ItemUpgrade.*
# Should show: DC-ItemUpgrade.toc, DarkChaos_ItemUpgrade.lua, DarkChaos_ItemUpgrade.xml
```

---

## Final File Structure

### After Deployment

```
Interface\AddOns\DC-ItemUpgrade\
├── TEXTURES\                    (existing textures)
├── TOOLS\                       (existing tools)
├── Textures\                    (existing textures)
│
├── DarkChaos_ItemUpgrade.lua    ✅ NEW (from _COMPLETE.lua)
├── DarkChaos_ItemUpgrade.xml    ✅ NEW (from _NEW.xml)
├── DC-ItemUpgrade.toc           ✅ NEW (from _NEW.toc)
│
├── DarkChaos_ItemUpgrade.lua.backup   (old - keep for safety)
├── DarkChaos_ItemUpgrade.xml.backup   (old - keep for safety)
├── DC-ItemUpgrade.toc.backup          (old - keep for safety)
│
├── [Other existing files]       (unchanged)
└── [Old broken files]           (archived)
```

---

## Verification Checklist

### After Copying Files

- [ ] `DarkChaos_ItemUpgrade.lua` exists (should be ~500 lines)
- [ ] `DarkChaos_ItemUpgrade.xml` exists (should be ~300 lines)
- [ ] `DC-ItemUpgrade.toc` exists (should reference the Lua/XML files)
- [ ] File sizes reasonable (not empty)
- [ ] Old `.backup` files present (safety)

**Verify file sizes:**
```bash
dir /l DC-ItemUpgrade.*
# DarkChaos_ItemUpgrade.lua  ~20-25 KB  ✓
# DarkChaos_ItemUpgrade.xml  ~12-15 KB  ✓
# DC-ItemUpgrade.toc         <1 KB      ✓
```

---

## Testing After Deployment

### Step 1: In-Game Reload
```
/reload
# Watch chat for: "[DC-ItemUpgrade] Addon loaded successfully!"
```

### Step 2: Open Addon
```
/dcupgrade
# Window should appear with proper layout
```

### Step 3: Test Commands
```
/additem 100999 100     # Add tokens
# Chat should show: "[DC-ItemUpgrade] Tokens: 100 | Essence: ..."

/dcupgrade query 0 0    # Query first item
# Chat should show: "DCUPGRADE_QUERY:..." message
```

---

## Rollback Procedure

If anything goes wrong:

```bash
cd Interface\AddOns\DC-ItemUpgrade

# Restore backups
ren DarkChaos_ItemUpgrade.lua DarkChaos_ItemUpgrade.lua.new
ren DarkChaos_ItemUpgrade.lua.backup DarkChaos_ItemUpgrade.lua

ren DarkChaos_ItemUpgrade.xml DarkChaos_ItemUpgrade.xml.new
ren DarkChaos_ItemUpgrade.xml.backup DarkChaos_ItemUpgrade.xml

ren DC-ItemUpgrade.toc DC-ItemUpgrade.toc.new
ren DC-ItemUpgrade.toc.backup DC-ItemUpgrade.toc

# In-game
/reload
```

---

## File Details

### DarkChaos_ItemUpgrade_COMPLETE.lua
```
Lines: ~500
Size: ~20 KB
Purpose: Complete addon logic

Key Sections:
- Lines 1-30: Header and constants
- Lines 40-100: Frame initialization
- Lines 140-200: Server message parsing
- Lines 250-350: UI update functions
- Lines 400-450: Item stats functions
- Lines 480-500: Slash commands

Includes:
✓ Event handling
✓ Message parsing
✓ UI updates
✓ Stat calculations
✓ Item selection
✓ Error handling
```

### DarkChaos_ItemUpgrade_NEW.xml
```
Lines: ~300
Size: ~15 KB
Purpose: Professional UI frame structure

Key Sections:
- Main frame definition
- Header with item preview
- Comparison panels (left/right)
- Control panel with dropdown
- Currency display
- Upgrade button
- Styling and anchoring

Features:
✓ Professional layout
✓ Proper anchoring
✓ Styled backgrounds
✓ Color-coded text
✓ Icon displays
✓ Button definitions
```

### DC-ItemUpgrade_NEW.toc
```
Lines: ~10
Size: <1 KB
Purpose: Addon manifest

Contents:
- Interface version (30300)
- Title and author
- File references
- Version number
```

---

## Quick Reference Commands

```bash
# Check if files exist
dir Interface\AddOns\DC-ItemUpgrade\DC-ItemUpgrade.toc

# Check file size
dir /l Interface\AddOns\DC-ItemUpgrade\*.lua

# Open addon folder
start Interface\AddOns\DC-ItemUpgrade

# View file content
type DarkChaos_ItemUpgrade.lua | more
```

---

## Troubleshooting File Issues

### Problem: "File not found"
```
Solution:
1. Verify source path exists
2. Check destination folder exists
3. Ensure file names match exactly (case-sensitive on Linux)
4. Try manual copy via Windows Explorer
```

### Problem: "File seems empty"
```
Solution:
1. Check source file size before copying
2. Verify copy operation completed
3. Compare file size in destination
4. Delete and retry copy
```

### Problem: "Addon won't load"
```
Solution:
1. Check DC-ItemUpgrade.toc exists
2. Verify Lua file name matches TOC
3. Check XML file name matches TOC
4. Look for Lua errors: /console scriptErrors 1
```

---

## Summary

| Step | File | Action | Result |
|------|------|--------|--------|
| 1 | ItemUpgradeCommands.cpp | Rebuild | New worldserver |
| 2 | Old addon files | Backup | .backup versions |
| 3 | _COMPLETE.lua | Copy & Rename | DarkChaos_ItemUpgrade.lua |
| 4 | _NEW.xml | Copy & Rename | DarkChaos_ItemUpgrade.xml |
| 5 | _NEW.toc | Copy & Rename | DC-ItemUpgrade.toc |
| 6 | Addon files | Test | /reload, /dcupgrade |

**Total time: ~20 minutes**

---

*Next: Start the rebuild! See ADDON_DEPLOYMENT_QUICK_GUIDE.md for next steps.*

