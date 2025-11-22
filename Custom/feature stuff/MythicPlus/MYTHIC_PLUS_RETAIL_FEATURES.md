# Mythic+ Retail-Like Features - Implementation Status

## Date: November 18, 2025

## ✅ IMPLEMENTED FEATURES

### Core Systems
1. **Keystone Items (M+2 to M+20)** ✅
   - Items 190001-190019 represent keystones from +2 to +20
   - Gossip menu shows detailed information when used
   - Shows scaling, rewards, and usage instructions

2. **Font of Power Activation** ✅
   - Interact with Font of Power to activate keystone
   - 10-second countdown before run starts
   - Teleports all players to dungeon entrance
   - Keystone consumed on activation

3. **Difficulty Scaling** ✅
   - Base: 2.0x multiplier (Mythic 0)
   - Each keystone level: +0.25x multiplier
   - Affects enemy HP and damage
   - Formula: 2.0 + (level × 0.25)

4. **Death Budget System** ✅
   - Maximum 15 deaths per run
   - 15th death = instant failure
   - Tracked throughout run
   - Affects keystone upgrade

5. **Boss Loot Generation** ✅
   - Spec-based loot filtering
   - Class/armor/role filtering
   - 1 item per normal boss
   - 2 items from final boss
   - Item level scales with keystone level

6. **Item Level Scaling** ✅
   - Base: 226 ilvl (configurable)
   - Levels 1-10: Base + (Level × 3)
   - Levels 11+: Base + 30 + ((Level-10) × 4)
   - Example M+20: 226 + 30 + 40 = 296 ilvl

7. **Token Rewards** ✅
   - Awarded at final boss kill
   - Formula: Base × (2.0 + (level × 0.25))
   - Used for gear upgrades
   - Logged to database

8. **Automated Keystone Upgrades** ✅
   - 0-5 deaths: +2 levels
   - 6-10 deaths: +1 level
   - 11-14 deaths: Same level
   - 15+ deaths: -1 level (run failed)
   - New keystone auto-created in inventory

9. **Weekly Vault Progress** ✅
   - Tracks dungeon completions per week
   - 1 run = Slot 1 (50 tokens)
   - 4 runs = Slot 2 (100 tokens)
   - 10 runs = Slot 3 (150 tokens)

10. **Run Cancellation System** ✅
    - Vote-based cancellation (2+ votes)
    - Auto-cancel after 3 minutes if abandoned
    - Manual cancel via `.mplus cancel` command
    - Keystones downgrade on cancellation

11. **Loot Suppression** ✅
    - Only final boss drops loot
    - Trash mobs drop nothing
    - Mini-bosses drop nothing
    - Retail-like loot lockout

12. **Run Statistics & Summary** ✅
    - Bosses killed tracking
    - Death/wipe tracking
    - Duration tracking
    - Comprehensive end-of-run summary

---

## 🚧 PARTIALLY IMPLEMENTED / NEEDS ENHANCEMENT

### 1. **Affixes System** ⚠️ (Planned, not yet implemented)
**Retail Mechanic:** Weekly rotating modifiers that change dungeon mechanics

**What's Missing:**
- No affix rotation system
- No affix difficulty modifiers
- No affix visual effects

**Suggested Implementation:**
```cpp
// Affixes unlock at certain keystone levels:
// +2-3: No affixes
// +4-6: 1 affix (Fortified or Tyrannical)
// +7-9: 2 affixes (+ Bolstering/Raging/etc.)
// +10-13: 3 affixes (+ Necrotic/Volcanic/etc.)
// +14+: 4 affixes (+ Seasonal affix)

enum MythicPlusAffixes
{
    AFFIX_FORTIFIED = 1,      // +20% HP/dmg to non-bosses
    AFFIX_TYRANNICAL = 2,     // +40% HP/dmg to bosses
    AFFIX_BOLSTERING = 3,     // Enemies empower nearby allies on death
    AFFIX_RAGING = 4,         // Enemies enrage at 30% HP
    AFFIX_NECROTIC = 5,       // Melee attacks apply stacking heal reduction
    AFFIX_VOLCANIC = 6,       // Volcanoes spawn under players
    AFFIX_EXPLOSIVE = 7,      // Explosive orbs spawn during combat
    AFFIX_QUAKING = 8,        // Periodic AoE damage + interrupt
    AFFIX_GRIEVOUS = 9,       // Stacking DoT below 90% HP
    AFFIX_BURSTING = 10,      // AoE damage when enemies die
    AFFIX_SANGUINE = 11,      // Healing pools on enemy death
    AFFIX_SEASONAL = 12       // Rotating seasonal mechanic
};
```

**Database Schema:**
```sql
CREATE TABLE dc_mplus_weekly_affixes (
    week_id INT PRIMARY KEY AUTO_INCREMENT,
    season_id INT NOT NULL,
    start_time INT UNSIGNED NOT NULL,
    affix_1 TINYINT UNSIGNED,  -- Level 4+ affix
    affix_2 TINYINT UNSIGNED,  -- Level 7+ affix
    affix_3 TINYINT UNSIGNED,  -- Level 10+ affix
    affix_4 TINYINT UNSIGNED,  -- Level 14+ seasonal affix
    INDEX idx_season_week (season_id, start_time)
);
```

**Config:**
```ini
MythicPlus.Affixes.Enabled = 1
MythicPlus.Affixes.RotationWeeks = 10  # Number of weeks before affix rotation repeats
MythicPlus.Affixes.Level1Threshold = 4   # First affix at +4
MythicPlus.Affixes.Level2Threshold = 7   # Second affix at +7
MythicPlus.Affixes.Level3Threshold = 10  # Third affix at +10
MythicPlus.Affixes.Level4Threshold = 14  # Seasonal affix at +14
```

---

### 2. **Timer System** ⚠️ (Partially Implemented)
**Retail Mechanic:** Timed dungeon runs with bronze/silver/gold chest upgrades

**What's Implemented:**
- Timer starts after countdown
- Timer tracked throughout run
- Duration logged to database

**What's Missing:**
- No timer display to players during run
- No "timer expired" notification
- No chest quality (bronze/silver/gold)
- No bonus keystone upgrades for beating timer

**Suggested Enhancement:**
```cpp
struct TimerThresholds
{
    uint32 goldTime;    // +3 keystone levels
    uint32 silverTime;  // +2 keystone levels
    uint32 bronzeTime;  // +1 keystone level
};

// Per-dungeon timer thresholds
std::map<uint32, TimerThresholds> dungeonTimers = {
    {574, {25*60, 30*60, 35*60}},  // Utgarde Keep: 25/30/35 min
    {575, {30*60, 35*60, 40*60}},  // Utgarde Pinnacle: 30/35/40 min
    // ... etc
};
```

**Config:**
```ini
MythicPlus.Timer.ShowOnScreen = 1          # Show timer to players
MythicPlus.Timer.UpdateInterval = 5        # Update every 5 seconds
MythicPlus.Timer.BonusUpgrades.Gold = 3    # +3 levels for gold time
MythicPlus.Timer.BonusUpgrades.Silver = 2  # +2 levels for silver time
MythicPlus.Timer.BonusUpgrades.Bronze = 1  # +1 level for bronze time
MythicPlus.Timer.FailOnTimeout = 0         # Allow completion after timer (depleted keystone)
```

---

### 3. **Depleted Keystones** ⚠️ (Not Implemented)
**Retail Mechanic:** Keystones become "depleted" if timer expires, can still complete for loot but no upgrade

**What's Missing:**
- No depleted keystone state
- No distinction between timed/untimed completion

**Suggested Implementation:**
```sql
ALTER TABLE dc_player_keystones 
ADD COLUMN is_depleted TINYINT(1) DEFAULT 0;
```

```cpp
// If timer expires but run completes:
keystone->SetDepleted(true);
keystone->ResetToSameLevel(); // No upgrade, stays at current level
player->SendNotification("Keystone completed but timer expired. Keystone depleted.");
```

**Config:**
```ini
MythicPlus.DepletedKeystones.Enabled = 1
MythicPlus.DepletedKeystones.AllowRecharge = 1  # Can recharge by completing +1 level lower
MythicPlus.DepletedKeystones.LootReduction = 0  # Full loot even if depleted
```

---

### 4. **Dungeon Specific Mechanics** ⚠️ (Not Implemented)
**Retail Mechanic:** Special dungeon-specific mechanics that appear in M+ but not normal/heroic

**Examples:**
- **Halls of Reflection:** Lich King chase sequence timer pressure
- **Trial of the Champion:** Mount combat buffs
- **Culling of Stratholme:** Arthas timer urgency

**Suggested Implementation:**
- Flag certain bosses/events as "M+ Enhanced"
- Add custom scripts per dungeon
- Scale mechanics with keystone level

---

### 5. **Seasonal Rotation** ⚠️ (Partially Implemented)
**Retail Mechanic:** Only certain dungeons available each season

**What's Implemented:**
- Season ID tracking in database
- Config option: `MythicPlus.FeaturedOnly`

**What's Missing:**
- No automatic dungeon rotation
- No season start/end dates
- No UI indication of which dungeons are "in season"

**Suggested Enhancement:**
```sql
CREATE TABLE dc_mplus_seasonal_dungeons (
    season_id INT NOT NULL,
    map_id INT NOT NULL,
    display_order INT DEFAULT 0,
    PRIMARY KEY (season_id, map_id)
);

CREATE TABLE dc_mplus_seasons (
    season_id INT PRIMARY KEY AUTO_INCREMENT,
    season_name VARCHAR(100),
    start_time INT UNSIGNED,
    end_time INT UNSIGNED,
    active TINYINT(1) DEFAULT 1
);
```

**Config:**
```ini
MythicPlus.Seasons.Enabled = 1
MythicPlus.Seasons.AutoRotate = 1       # Auto-switch seasons
MythicPlus.Seasons.DurationWeeks = 16   # 16 weeks per season
MythicPlus.Seasons.ShowCalendar = 1     # Show season schedule to players
```

---

### 6. **Death Penalty (Time Addition)** ⚠️ (Config exists, not enforced)
**Retail Mechanic:** Each death adds 5 seconds to the timer

**What's Implemented:**
- Config option exists: `MythicPlus.DeathPenalty.Seconds = 5`
- Death tracking works

**What's Missing:**
- Time penalty not actually applied to timer
- No notification when penalty added

**Suggested Implementation:**
```cpp
void MythicPlusRunManager::HandlePlayerDeath(Player* player, Creature* killer)
{
    // ... existing death tracking ...
    
    if (sConfigMgr->GetOption<bool>("MythicPlus.DeathPenalty.Enabled", true))
    {
        uint32 penaltySeconds = sConfigMgr->GetOption<uint32>("MythicPlus.DeathPenalty.Seconds", 5);
        state->timerPenaltySeconds += penaltySeconds;
        
        AnnounceToInstance(map, 
            "|cffff0000[Mythic+]|r Death penalty: +" + std::to_string(penaltySeconds) + " seconds added to timer.");
    }
}
```

---

### 7. **Leaderboards & Statistics** ✅ (Implemented via NPC)
**Retail Mechanic:** Track fastest clear times per dungeon per keystone level

**What's Implemented:**
- ✅ **NPC: Archivist Serah (100060)** - Statistics Board NPC
- ✅ **Database tables:** `dc_mplus_scores` tracks best levels, scores, total runs
- ✅ **Player stats:** View personal best key, total runs, best score
- ✅ **Top 10 leaderboard:** Shows best players by highest keystone cleared
- ✅ **Per-dungeon details:** Shows best clear per dungeon with run counts
- ✅ **Seasonal tracking:** Separates stats by season ID
- ✅ **Weekly vault progress:** Shows current week's runs and highest level

**Features:**
```
Archivist Serah Menu:
├─ My Statistics (personal best key, total runs, best score)
├─ Top 10 Leaderboard (season rankings by keystone level)
└─ Per-Dungeon Best Times (best clear per dungeon)
```

**Database Schema (Already Exists):**
```sql
-- dc_mplus_scores: Tracks player performance per dungeon
CREATE TABLE dc_mplus_scores (
    character_guid BIGINT UNSIGNED,
    season_id INT,
    map_id INT,
    best_level TINYINT UNSIGNED,
    best_score INT UNSIGNED,
    total_runs INT UNSIGNED,
    PRIMARY KEY (character_guid, season_id, map_id)
);

-- dc_weekly_vault: Tracks weekly progress
CREATE TABLE dc_weekly_vault (
    character_guid BIGINT UNSIGNED,
    season_id INT,
    week_start INT UNSIGNED,
    runs_completed TINYINT UNSIGNED,
    highest_level TINYINT UNSIGNED,
    slot1_unlocked BOOLEAN,
    slot2_unlocked BOOLEAN,
    slot3_unlocked BOOLEAN,
    reward_claimed BOOLEAN,
    claimed_slot TINYINT UNSIGNED
);
```

**Potential Enhancements:**
- Add `.mplus stats` command (in addition to NPC)
- Track fastest clear times (duration) in addition to level
- Add weekly/monthly leaderboards
- Show group composition for top runs
- Add "First to Clear +20" achievements

---

### 8. **Great Vault Gear Selection** ✅ (Implemented via NPC)
**Retail Mechanic:** Choose from 3 gear options per unlocked vault slot

**What's Implemented:**
- ✅ **NPC: Great Vault Manager** - Weekly vault rewards interface
- ✅ **Database:** `dc_vault_loot_table` with 308+ items (weapons, armor, trinkets)
- ✅ **3 gear choices per slot:** Shows item name, item level, stats
- ✅ **Token fallback:** Supports legacy token mode (item 101000) for backward compatibility
- ✅ **Spec-appropriate filtering:** Uses class_mask, spec_name, armor_type, role_mask
- ✅ **Unlock thresholds:** 1 run = Slot 1, 4 runs = Slot 2, 10 runs = Slot 3
- ✅ **Weekly reset:** Resets claims every Wednesday 9 AM server time
- ✅ **Item level scaling:** Higher keystone levels = better gear ilvls

**Features:**
```
Great Vault UI (via NPC):
├─ Slot 1 (1 run): Shows 3 gear options with ilvls
├─ Slot 2 (4 runs): Shows 3 gear options with ilvls
├─ Slot 3 (10 runs): Shows 3 gear options with ilvls
└─ Claim system: Click item to claim (one choice per slot)

Example Display:
━━━━━ SLOT 1 (Unlocked: 3 runs) ━━━━━
  → [Thunderfury, Blessed Blade] (ilvl 284)
  → [Quel'Serrar, Sword of Valor] (ilvl 284)
  → [Bloodrazor, Axe of Fury] (ilvl 284)
```

**Database Schema (Already Exists):**
```sql
-- dc_vault_loot_table: Loot pool for vault rewards
CREATE TABLE dc_vault_loot_table (
    item_id INT UNSIGNED PRIMARY KEY,
    item_name VARCHAR(255),
    class_mask INT UNSIGNED,           -- Bitmask: Warrior=1, Paladin=2, etc.
    spec_name VARCHAR(50),              -- Arms, Fury, Protection, etc.
    armor_type VARCHAR(20),             -- Plate, Mail, Leather, Cloth, Misc
    role_mask TINYINT UNSIGNED,         -- Tank=1, Healer=2, DPS=4, Hybrid=5
    item_slot VARCHAR(20),              -- Head, Chest, Weapon, Trinket, etc.
    base_ilvl SMALLINT UNSIGNED,
    min_keystone_level TINYINT UNSIGNED,
    INDEX idx_class_spec (class_mask, spec_name),
    INDEX idx_armor_role (armor_type, role_mask)
);

-- dc_weekly_vault: Player vault progress
CREATE TABLE dc_weekly_vault (
    character_guid BIGINT UNSIGNED,
    season_id INT,
    week_start INT UNSIGNED,
    runs_completed TINYINT UNSIGNED,     -- Tracks total runs this week
    highest_level TINYINT UNSIGNED,      -- Best keystone cleared this week
    slot1_unlocked BOOLEAN,              -- Unlocked after 1 run
    slot2_unlocked BOOLEAN,              -- Unlocked after 4 runs
    slot3_unlocked BOOLEAN,              -- Unlocked after 10 runs
    reward_claimed BOOLEAN,
    claimed_slot TINYINT UNSIGNED,       -- Which slot was claimed (1-3)
    PRIMARY KEY (character_guid, season_id, week_start)
);
```

**How It Works:**
1. Players complete M+ keys to unlock vault slots (1/4/10 runs)
2. NPC displays 3 gear choices per unlocked slot
3. Gear is filtered by player's class, spec, armor type, role
4. Item levels scale based on highest keystone cleared
5. Player clicks item to claim (one choice per slot)
6. Vault resets weekly - unclaimed rewards are lost

**Potential Enhancements:**
- ✅ Server-side implementation complete
- ⚠️ **Client-side UI addon** - Create WoW addon for better visualization
  - Show item tooltips on hover
  - Compare with currently equipped gear
  - Preview secondary stats before claiming
  - Display "BiS" markers for optimal choices
- Add item preview window (3D model)
- Add "seal of fate" reroll mechanic

---

### 9. **Keystone Trading** ⚠️ (Not Implemented)
**Retail Mechanic:** Players can trade keystones within 2 hours of acquisition

**What's Missing:**
- Keystones are soulbound immediately
- No trading window
- No trade restrictions

**Suggested Implementation:**
```sql
ALTER TABLE dc_player_keystones 
ADD COLUMN acquired_time INT UNSIGNED,
ADD COLUMN tradeable_until INT UNSIGNED;
```

```cpp
// Make keystone tradeable for 2 hours
item->SetBinding(false);
item->SetTradeableUntil(time(nullptr) + 7200);  // 2 hours
```

**Config:**
```ini
MythicPlus.Keystones.Tradeable = 1
MythicPlus.Keystones.TradeWindowHours = 2
```

---

### 10. **Dungeon Portal Creation** ⚠️ (Not Implemented)
**Retail Mechanic:** Completing a keystone creates a portal back to your current location

**What's Missing:**
- No portal spawn on completion
- Players must use hearthstone/fly back

**Suggested Implementation:**
```cpp
// Spawn portal at completion
GameObject* portal = player->SummonGameObject(
    195142,  // Portal gameobject entry
    player->GetPositionX(), 
    player->GetPositionY(), 
    player->GetPositionZ(),
    player->GetOrientation(),
    0, 0, 0, 0,
    300  // 5 minute duration
);
```

---

## 🎯 ADDITIONAL RETAIL-LIKE FEATURES TO CONSIDER

### 1. **Pride/Prideful Affix** (Seasonal)
- Mob that spawns at 20%/40%/60%/80% trash cleared
- Grants powerful buff on kill
- Adds strategic routing considerations

### 2. **Tormented Lieutenants** (Seasonal)
- Mini-bosses throughout dungeon
- Optional but provide anima powers
- Adds risk/reward decisions

### 3. **Score System (Raider.IO equivalent)**
- Score based on keystone level + timing
- Tracks best score per dungeon
- Overall score displayed in `.mplus stats`

### 4. **Valor Points**
- Currency for upgrading M+ gear
- Earned per dungeon completion
- Cap per week

### 5. **Seasonal Achievements**
- "Keystone Master" (+15 all dungeons in season)
- "Keystone Hero" (+20 all dungeons in season)
- "Cutting Edge" (First guild to complete +25)

### 6. **Dungeon Portals in Oribos/Major City**
- Talk to NPC to open portal to any M+ dungeon
- Retail-like convenience
- Requires keystone for that dungeon

### 7. **M+ Specific Gear Sets**
- Custom items only obtainable from M+
- Tier sets with set bonuses
- Cosmetic rewards for high keys

### 8. **"Thundering" / Environmental Hazards**
- Environmental effects based on dungeon
- Scales with keystone level
- Adds visual variety

---

## 📊 CONFIGURATION SUMMARY

### Current Config (darkchaos-custom.conf.dist)
All existing config options are documented in the main config file under Section 4: Mythic+ System.

### Recommended Additions
```ini
###########################################################################
# MYTHIC+ AFFIXES (FUTURE)
###########################################################################
MythicPlus.Affixes.Enabled = 0                    # Not yet implemented
MythicPlus.Affixes.RotationWeeks = 10
MythicPlus.Affixes.ShowInKeystoneTooltip = 1

###########################################################################
# MYTHIC+ TIMER SYSTEM
###########################################################################
MythicPlus.Timer.ShowOnScreen = 1
MythicPlus.Timer.UpdateInterval = 5
MythicPlus.Timer.BonusUpgrades.Enabled = 1
MythicPlus.Timer.FailOnTimeout = 0                # Allow depleted completions

###########################################################################
# MYTHIC+ DEPLETED KEYSTONES
###########################################################################
MythicPlus.DepletedKeystones.Enabled = 0          # Not yet implemented
MythicPlus.DepletedKeystones.AllowRecharge = 1
MythicPlus.DepletedKeystones.LootReduction = 0

###########################################################################
# MYTHIC+ LEADERBOARDS
###########################################################################
MythicPlus.Leaderboards.Enabled = 0               # Not yet implemented
MythicPlus.Leaderboards.ShowTop = 10
MythicPlus.Leaderboards.ResetWithSeason = 1

###########################################################################
# MYTHIC+ SCORE SYSTEM
###########################################################################
MythicPlus.Score.Enabled = 0                      # Not yet implemented
MythicPlus.Score.ShowInStats = 1
MythicPlus.Score.TimingBonus = 1.5                # 1.5x score for timed runs
```

---

## 🔧 IMPLEMENTATION PRIORITY

### High Priority (Most Impact)
1. **Affixes System** - Core retail mechanic, adds weekly variety
2. **Timer Bonuses** - Incentivizes skilled play
3. **Depleted Keystones** - Retail-accurate failure state

### Medium Priority (Quality of Life)
4. **Leaderboards** - Community engagement
5. **Death Penalty Enforcement** - Balance adjustment
6. **Seasonal Rotation** - Content freshness

### Low Priority (Nice to Have)
7. **Score System** - Player prestige
8. **Keystone Trading** - Social feature
9. **Dungeon Portals** - Convenience

---

## 📝 NOTES

- All suggested SQL schemas are compatible with AzerothCore
- Config options follow existing naming conventions
- Implementation suggestions include code snippets where applicable
- Features marked ⚠️ are partially done and need completion
- Features marked ❌ are completely missing

**Total Implementation:** ~60% complete for retail-parity
**Core Systems:** ~90% complete
**Polish/QoL Features:** ~30% complete

---

## 🎯 CONCLUSION

The current Mythic+ system has a strong foundation with:
- ✅ Full keystone range (M+2 to M+20)
- ✅ Proper scaling and loot
- ✅ Automated upgrades
- ✅ Spec-based loot generation
- ✅ Death budget system
- ✅ Vote-based cancellation

**To achieve full retail parity, the biggest gaps are:**
1. **Affixes** (weekly modifiers)
2. **Timer bonuses** (bronze/silver/gold)
3. **Depleted keystones** (failed timer state)
4. **Leaderboards** (competitive aspect)
5. **Seasonal content** (rotation system)

All of these are implementable with the current codebase architecture!
