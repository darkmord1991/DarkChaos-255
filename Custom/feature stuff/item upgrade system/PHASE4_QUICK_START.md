# 🚀 Quick Start Guide - Phase 4 Complete System

## ⚡ Fast Track Deployment (15 minutes)

### Step 1: Database Setup (5 min)
```bash
cd "Custom/Custom feature SQLs"

# Execute Phase 4A database
mysql -u root -p acore_characters < dc_item_upgrade_phase4a.sql

# Execute Phase 4B/C/D database
mysql -u root -p acore_characters < dc_item_upgrade_phase4bcd.sql
```

### Step 2: Add Files to Build (2 min)
The following files are already created in `src/server/scripts/DC/ItemUpgrades/`:
- ✅ ItemUpgradeProgressionImpl.cpp
- ✅ ItemUpgradeSeasonalImpl.cpp
- ✅ ItemUpgradeAdvancedImpl.cpp

These need to be added to the build system. The files are already in place!

### Step 3: Build (5 min)
```bash
# Remote build (your current setup)
# Let the build run and check for any errors

# OR local build:
./acore.sh compiler build
```

### Step 4: Spawn NPCs (3 min)
```sql
-- Already have NPC IDs 190001 and 190002 from Phase 4A
-- Just verify they exist in your world
```

### Step 5: Test (5 min)
```
# Login as admin
.upgradeprog prestige       # Should show your prestige (0 if new)
.season info                # Should show Season 1
.upgradeadv achievements    # Should show 6 available achievements
.upgradeadv guild           # Should show guild stats
```

---

## 📋 What's New in This Update

### Phase 4B: Progression System ✨
- **Prestige System**: Earn ranks and titles through upgrades
- **Tier Unlocking**: Epic and Legendary tiers can be gated
- **Weekly Caps**: Prevent excessive spending (soft/hard caps)
- **Commands**: `.upgradeprog prestige`, `.upgradeprog weekcap`

### Phase 4C: Seasonal System ✨
- **Seasons**: Track progression per season
- **Leaderboards**: Compete on upgrades, prestige, efficiency
- **History**: Full upgrade timeline for every player
- **Commands**: `.season info`, `.season leaderboard`, `.season history`

### Phase 4D: Advanced Features ✨
- **Respec System**: Reset upgrades with currency refund
- **Achievements**: 6 upgrade achievements with rewards
- **Guild Progression**: Track guild-wide statistics
- **Commands**: `.upgradeadv respec`, `.upgradeadv achievements`, `.upgradeadv guild`

---

## 🎮 Player Experience Flow

1. **Player earns tokens/essence** from quests, PvP, raids
2. **Player talks to Upgrade Vendor (190001)** to see token balance
3. **Player talks to Item Upgrader (900500)** to upgrade items
4. **System awards prestige points** automatically
5. **Player checks progress** with `.upgradeprog prestige`
6. **Player competes** on seasonal leaderboards
7. **Player earns achievements** for milestones
8. **Guild benefits** from collective progression

---

## 📊 Database Tables Created

**23 new tables**:
- 5 Progression tables (prestige, caps, unlocks)
- 6 Seasonal tables (seasons, history, leaderboards)
- 9 Advanced tables (respec, achievements, guild, loadouts)
- 3 Token/currency tables (from Phase 4A)

**4 analytics views**:
- Player progression summary
- Top upgraders leaderboard
- Recent upgrades feed
- Guild leaderboard

**3 stored procedures**:
- Reset weekly caps
- Update guild statistics
- Archive completed seasons

---

## 🔧 Admin Quick Reference

### Give Tokens/Essence to Player
```sql
-- Give 1000 tokens and 500 essence to player
UPDATE dc_player_upgrade_tokens 
SET tokens = tokens + 1000, essence = essence + 500 
WHERE player_guid = <PLAYER_GUID>;
```

### Unlock Tier for Player
```
.upgradeprog unlocktier 4    # Unlock Epic tier
.upgradeprog unlocktier 5    # Unlock Legendary tier
```

### Check Weekly Spending
```
.upgradeprog weekcap         # For yourself
# Or check database directly:
SELECT * FROM dc_weekly_spending WHERE player_guid = <PLAYER_GUID>;
```

### View Leaderboards
```
.season leaderboard upgrades    # Most upgrades
.season leaderboard prestige    # Most prestige
.season leaderboard efficiency  # Best efficiency
```

### Award Achievement Manually
```sql
-- Award achievement to player
INSERT INTO dc_player_achievements (player_guid, achievement_id, earned_timestamp)
VALUES (<PLAYER_GUID>, 1, UNIX_TIMESTAMP());

-- Give achievement rewards
UPDATE dc_player_prestige 
SET total_prestige_points = total_prestige_points + 10 
WHERE player_guid = <PLAYER_GUID>;

UPDATE dc_player_upgrade_tokens 
SET tokens = tokens + 50 
WHERE player_guid = <PLAYER_GUID>;
```

### Start New Season
```sql
-- Archive Season 1
CALL sp_archive_season(1);

-- Create Season 2
INSERT INTO dc_seasons (season_id, season_name, start_timestamp, is_active)
VALUES (2, 'Season 2: Renewal', UNIX_TIMESTAMP(), 1);
```

---

## ⚠️ Important Notes

1. **Season 1 Auto-Created**: The database migration creates Season 1 automatically
2. **Prestige Auto-Initialized**: Players get prestige records on first upgrade
3. **Weekly Reset**: Caps reset every Sunday at 00:00 server time
4. **Respec Costs**: Default 50% refund, 1 hour cooldown, 3 per day limit
5. **Guild Stats**: Auto-calculated from member upgrades

---

## 🎯 Success Indicators

✅ All 23 tables created in database  
✅ Season 1 is active in `dc_seasons`  
✅ Commands work: `.upgradeprog prestige`, `.season info`, `.upgradeadv respec`  
✅ NPCs show correct menus with content  
✅ Players can earn prestige from upgrades  
✅ Leaderboards populate with data  
✅ Achievements track progress  

---

## 📞 Troubleshooting

**Problem**: "Unknown command .upgradeprog"  
**Solution**: Files not compiled or not registered in script loader

**Problem**: "Table doesn't exist"  
**Solution**: Run `dc_item_upgrade_phase4bcd.sql` on database

**Problem**: "Season info shows nothing"  
**Solution**: Check `SELECT * FROM dc_seasons WHERE is_active = 1;`

**Problem**: "Leaderboard is empty"  
**Solution**: Need players to perform upgrades first

**Problem**: "Guild stats show 0"  
**Solution**: Run `CALL sp_update_guild_stats(<guild_id>);`

---

## 🎉 You're Done!

The complete Phase 4 Item Upgrade System is now ready to use!

**Features Available**:
- ✅ Core upgrade mechanics (Phase 4A)
- ✅ Prestige system (Phase 4B)
- ✅ Seasonal competition (Phase 4C)
- ✅ Respec and achievements (Phase 4D)

**Total System Scope**:
- 3,500+ lines of C++ code
- 23 database tables
- 15+ commands
- 3 NPCs
- 6 achievements
- 5 item tiers
- 15 upgrade levels

**Enjoy the complete endgame progression system!** 🎮
