# Phase 3 Deployment & Testing Guide

**Status:** Code complete, UI improved, ready for DB deployment and in-game testing.

## Summary of Changes (Phase 3A & 3B)

### Phase 3A: Chat Commands
- **File:** `src/server/scripts/DC/ItemUpgrades/ItemUpgradeCommand.cpp`
- **Command:** `.upgrade`
- **Subcommands:**
  - `.upgrade status` — Check current upgrade status and token balance
  - `.upgrade list` — View available upgrades for your current gear
  - `.upgrade info [itemId]` — Get detailed info about a specific upgrade

### Phase 3B: NPC Vendor & Curator
- **Files:**
  - `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Vendor.cpp` (ID: 190001)
  - `src/server/scripts/DC/ItemUpgrades/ItemUpgradeNPC_Curator.cpp` (ID: 190002)
- **Features:**
  - Improved gossip menus with **icons** and **WoW color codes**
  - Vendor: Item Upgrades, Token Exchange, Artifact Shop, Help
  - Curator: Artifact Collection, Discovery Info, Cosmetics, Statistics, Help
  - Professional UI appearance matching premium addon standard

### Build Status
- ✅ Local build: **PASSED** (no errors, no warnings)
- ✅ Code committed: Commit hash `971d92e8d`
- ✅ Remote repo synced: Latest code pushed to `origin/master`

---

## Next Steps: Database Deployment & Testing

### Step 1: Execute NPC SQL on World Database

**Order matters!** Execute files in this sequence:

1. **`dc_npc_creature_templates.sql`** (creates creature templates)
   - Path: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_npc_creature_templates.sql`
   - Creates creature_template entries for IDs 190001 and 190002
   - Sets up visual models, names, and basic NPC properties

2. **`dc_npc_spawns.sql`** (spawns the NPCs)
   - Path: `Custom/Custom feature SQLs/worlddb/ItemUpgrades/dc_npc_spawns.sql`
   - Inserts three spawn instances (2 vendors, 1 curator)
   - Vendor locations: Stormwind (map 0), Orgrimmar (map 1)
   - Curator location: Shattrath (map 530)

### Step 2: Restart World Server

After executing both SQL files:
```
1. Stop worldserver
2. Run: worldserver
3. Wait for full startup
```

### Step 3: In-Game Verification

#### A. Check NPC Spawns
- Open game client and log in
- Travel to NPC locations:
  - **Vendor (Stormwind):** Main square area (Stormwind coordinates: -8835, 531, 96)
  - **Vendor (Orgrimmar):** Main square area (Orgrimmar coordinates: 1632, -4251, 41)
  - **Curator (Shattrath):** Central location (Shattrath coordinates: -1860, 5435, -12)
- Verify NPCs appear and are selectable (green text, glowing nameplate)

#### B. Test Gossip Menus
- Click each NPC to open gossip dialog
- **Vendor menu should show:**
  - 🟢 Green "Item Upgrades" — Vendor icon, colored text
  - 🟡 Yellow "Token Exchange" — Vendor icon, colored text
  - 🔵 Blue "Artifact Shop" — Vendor icon, colored text
  - ⚪ White "Help" — Chat icon, colored text
  - Back buttons with Chat icon
- **Curator menu should show:**
  - 🔵 Blue "Artifact Collection" — Chat icon
  - 🟡 Yellow "Discovery Info" — Chat icon
  - 🟢 Green "Cosmetics" — Vendor icon
  - ⚪ White "Statistics" — Chat icon
  - ⚪ White "Help" — Chat icon
  - Back buttons with Chat icon

#### C. Test Chat Commands
- Open chat and execute:
  ```
  .upgrade status       # Check status
  .upgrade list         # List available upgrades
  .upgrade info 1234    # Info about item 1234
  ```
- Verify command responses appear in chat window without errors

### Step 4: Document Testing Results

Once testing is complete, note:
- [ ] NPC spawns visible in-game
- [ ] Gossip menus display correctly with colors and icons
- [ ] Back/navigation buttons work
- [ ] Chat commands respond without errors
- [ ] No console errors or crashes during interaction

---

## Remote Build & Deploy (Optional)

If you haven't already run a remote build:

1. **Push code to remote:** ✅ Done (commit 971d92e8d)
2. **Build on remote server:** 
   ```
   ssh wowcore@192.168.178.45
   cd /home/wowcore/azerothcore/build
   make -j$(nproc)
   ```
3. **Deploy binaries:** Copy compiled `worldserver` and `authserver` to production
4. **Run SQL files:** Connect to world DB and execute the two SQL files in order
5. **Restart servers:** Restart authserver and worldserver

---

## Database Connection Details

**World Database:** (obtain from your `.env` or database config)
- Host: `localhost` or remote DB IP
- Database: `azerothcore_world` (or your custom name)
- User: `azeroth` (or your custom user)
- Port: `3306` (default MySQL)

**SQL Execution Command (via MySQL CLI):**
```bash
mysql -h <host> -u <user> -p <database> < dc_npc_creature_templates.sql
mysql -h <host> -u <user> -p <database> < dc_npc_spawns.sql
```

Or use MySQL Workbench / DBeaver to execute scripts via GUI.

---

## Troubleshooting

### NPCs don't appear in-game
- [ ] Verify SQL executed successfully (check world DB tables)
- [ ] Check console for SQL errors
- [ ] Verify spawn coordinates are valid (inside world boundaries)
- [ ] Reload realm (` .reload creatures` command if available)

### Gossip menus don't show colors
- [ ] Client may not support color codes (update WoW client)
- [ ] Check creature_template entries were created (query table)
- [ ] Verify script loader registered NPC scripts

### Chat commands return errors
- [ ] Check console for script load errors
- [ ] Verify script compilation succeeded (local build status)
- [ ] Try `.upgrade` without arguments for help text

### Server crash on interaction
- [ ] Check worldserver console for crash/error messages
- [ ] Verify script syntax in ItemUpgradeCommand.cpp
- [ ] Check core pointer validity (ObjectMgr, ItemTemplate access)

---

## What's Next After Testing?

### Phase 3C: Database Integration (Token System)
- Hooks to award tokens on item upgrade/progression
- Automatic token accrual from gameplay activities
- Integration with character stats and inventory management

### Phase 4: Advanced Features (Optional)
- Upgrade cosmetics (visual effects, animations)
- Artifact collection UI
- Transmog/appearance customization
- Crafting recipes for upgrade tokens

---

## Summary Checklist

- [x] Phase 3A: Commands implemented and compiled
- [x] Phase 3B: NPC scripts implemented and compiled  
- [x] UI: Gossip menus improved with icons and colors
- [x] Local build: Passed with 0 errors
- [x] Code committed and pushed
- [ ] NPC SQL executed on world DB
- [ ] Worldserver restarted
- [ ] NPCs verified in-game
- [ ] Gossip menus verified visually
- [ ] Chat commands tested
- [ ] Phase 3C started (if desired)

---

**Last Updated:** November 4, 2025  
**Phase 3 Status:** Ready for database deployment and live testing  
**Code Version:** Commit 971d92e8d (UI improvements)
