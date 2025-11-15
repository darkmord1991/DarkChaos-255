# Mythic+ System - Technical Implementation Guide

**Document:** Architecture & Code Reference  
**Target:** AzerothCore Implementation  
**Language:** C++/SQL

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    PLAYER INTERFACE                      │
│  (LFG Tool, NPC Gossip, Quest Log, Leaderboard)        │
└────────────┬────────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────────┐
│              MYTHIC+ GAME SYSTEMS                        │
├─────────────────────────────────────────────────────────┤
│ • Keystone Management (item, level tracking)            │
│ • Timer System (per-instance countdown)                 │
│ • Affix Engine (apply modifiers to creatures)           │
│ • Scaling Engine (HP/Damage adjustments)                │
│ • Loot Distribution (item level scaling)                │
│ • Rating System (ELO-like calculations)                 │
└────────────┬────────────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────────────┐
│              DATABASE LAYER                              │
├─────────────────────────────────────────────────────────┤
│ • mythic_keystone (item data)                           │
│ • mythic_dungeon_instance (runtime data)                │
│ • mythic_plus_rating (player ratings/season)            │
│ • mythic_plus_runs (historical data)                    │
│ • mythic_plus_leaderboard (seasonal rankings)           │
└─────────────────────────────────────────────────────────┘
```

---

## 📝 Database Schema (Complete)

### **1. Keystone Item Management**

```sql
CREATE TABLE mythic_keystone (
  item_entry INT NOT NULL PRIMARY KEY,
  dungeon_id INT NOT NULL,
  mythic_level TINYINT NOT NULL DEFAULT 1,
  affixes VARCHAR(100),  -- e.g., "Tyrannical,Explosive"
  used BOOLEAN DEFAULT FALSE,
  player_guid INT,
  created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_date TIMESTAMP,
  KEY (player_guid),
  KEY (dungeon_id)
);
```

**Sample Data:**
```sql
INSERT INTO mythic_keystone VALUES
(182750, 2, 3, 'Tyrannical,Explosive', FALSE, NULL, NOW(), DATE_ADD(NOW(), INTERVAL 7 DAY));
```

### **2. Mythic Dungeon Instance Tracking**

```sql
CREATE TABLE mythic_dungeon_instance (
  instance_id INT NOT NULL PRIMARY KEY,
  dungeon_id INT NOT NULL,
  mythic_level TINYINT NOT NULL,
  affixes VARCHAR(100),
  start_time INT NOT NULL,
  end_time INT,
  team_size TINYINT,
  completed BOOLEAN DEFAULT FALSE,
  timer_met BOOLEAN DEFAULT FALSE,
  time_used INT,  -- seconds
  time_limit INT,  -- seconds
  players VARCHAR(500),  -- comma-separated GUIDs
  loot_items VARCHAR(500),  -- items awarded
  created_date TIMESTAMP,
  KEY (dungeon_id),
  KEY (completed),
  KEY (created_date)
);
```

### **3. Player Rating & Progression**

```sql
CREATE TABLE mythic_plus_player_rating (
  guid INT NOT NULL,
  season INT NOT NULL,
  rating FLOAT DEFAULT 0,
  best_run INT,  -- FK to mythic_dungeon_instance
  best_level INT,
  total_runs INT DEFAULT 0,
  weekly_runs INT DEFAULT 0,
  last_run_date TIMESTAMP,
  updated_date TIMESTAMP,
  PRIMARY KEY (guid, season),
  KEY (rating DESC),
  KEY (best_level DESC)
);
```

### **4. Historical Run Data**

```sql
CREATE TABLE mythic_plus_runs (
  run_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
  instance_id INT NOT NULL,
  character_guid INT NOT NULL,
  character_name VARCHAR(12),
  dungeon_id INT,
  dungeon_name VARCHAR(50),
  mythic_level TINYINT,
  affixes VARCHAR(100),
  timer_completed BOOLEAN,
  time_taken INT,  -- seconds
  time_limit INT,
  rating_change FLOAT,
  loot_awarded VARCHAR(500),
  keystone_upgrade_level TINYINT,
  season INT,
  completion_date TIMESTAMP,
  KEY (character_guid, season),
  KEY (completion_date),
  KEY (rating_change)
);
```

### **5. Leaderboard Data**

```sql
CREATE TABLE mythic_plus_leaderboard (
  leaderboard_id INT PRIMARY KEY AUTO_INCREMENT,
  rank INT UNIQUE,
  character_guid INT,
  character_name VARCHAR(12),
  character_level INT,
  rating FLOAT,
  best_run INT,
  best_level INT,
  season INT,
  faction INT,
  realm_id INT,
  updated_date TIMESTAMP,
  KEY (season, rating DESC, realm_id),
  UNIQUE KEY (season, character_guid)
);
```

### **6. Affix Configuration**

```sql
CREATE TABLE mythic_affixes (
  affix_id INT PRIMARY KEY,
  affix_name VARCHAR(50),
  description VARCHAR(255),
  icon_id INT,
  difficulty_modifier FLOAT,  -- 1.0 = no change
  effects JSON,  -- Flexible effect data
  boss_affix BOOLEAN,  -- Only affects bosses?
  min_mythic_level TINYINT,  -- Available from M+X
  active BOOLEAN DEFAULT TRUE
);

INSERT INTO mythic_affixes VALUES
(1, 'Tyrannical', 'Bosses are much stronger', 1234, 1.15, '{"boss_hp":1.15,"boss_dmg":1.15}', TRUE, 0),
(2, 'Fortified', 'Non-boss enemies are much stronger', 1235, 1.12, '{"trash_hp":1.12,"trash_dmg":1.12}', FALSE, 0),
(3, 'Explosive', 'Explosive orbs spawn on trash dies', 1236, 1.10, '{}', FALSE, 2);
```

### **7. Achievement Tracking**

```sql
CREATE TABLE mythic_plus_achievements (
  achievement_id INT PRIMARY KEY,
  achievement_name VARCHAR(100),
  description VARCHAR(255),
  category VARCHAR(50),  -- bronze, silver, gold
  requirement_type VARCHAR(50),  -- 'complete_level', 'complete_timer', 'affix_combo'
  requirement_value INT,
  min_mythic_level INT,
  awarded_to INT,  -- players who earned
  icon_id INT
);
```

---

## 💻 C++ Implementation

### **1. Keystone Management System**

```cpp
// File: src/server/scripts/Custom/MythicPlus/MythicKeystoneManager.h
#pragma once

class MythicKeystoneManager {
public:
  static MythicKeystoneManager* instance();
  
  // Keystone operations
  void CreateKeystone(uint32 playerGuid, uint32 dungeonId, uint32 level);
  bool UseKeystone(uint32 playerGuid, uint32 keystoneItemEntry);
  void ConsumeKeystone(uint32 playerGuid);
  void UpgradeKeystone(uint32 playerGuid, bool twoChest = false);
  
  // Info retrieval
  struct KeystoneInfo {
    uint32 dungeonId;
    uint32 level;
    std::string affixes;
    uint32 remainingRuns;
  };
  
  KeystoneInfo GetKeystoneInfo(uint32 playerGuid);
  std::vector<uint32> GetRandomAffixes(uint32 level);
  
private:
  std::unordered_map<uint32, KeystoneInfo> keystoneCache;
};

// File: src/server/scripts/Custom/MythicPlus/MythicKeystoneManager.cpp
#include "MythicKeystoneManager.h"
#include "Database.h"

MythicKeystoneManager* MythicKeystoneManager::instance() {
  static MythicKeystoneManager instance;
  return &instance;
}

void MythicKeystoneManager::CreateKeystone(uint32 playerGuid, uint32 dungeonId, uint32 level) {
  std::vector<uint32> affixes = GetRandomAffixes(level);
  std::string affixString;
  
  for (auto affix : affixes) {
    // Get affix name from mythic_affixes table
    if (!affixString.empty()) affixString += ",";
    // affixString += GetAffixName(affix);
  }
  
  // Generate unique item GUID
  uint32 itemEntry = 182750 + level;  // Custom M+ item entries
  
  // Store in database
  CharacterDatabase.PExecute(
    "INSERT INTO mythic_keystone (player_guid, dungeon_id, mythic_level, affixes) "
    "VALUES (%u, %u, %u, '%s')",
    playerGuid, dungeonId, level, affixString.c_str()
  );
  
  LOG_INFO("mythic", "Created keystone for player %u: Dungeon %u, Level M+%u, Affixes: %s",
    playerGuid, dungeonId, level, affixString.c_str());
}

std::vector<uint32> MythicKeystoneManager::GetRandomAffixes(uint32 level) {
  std::vector<uint32> result;
  
  // Lower levels = fewer affixes
  uint32 affixCount = std::min(3U, (level / 4) + 1);  // 1 affix every 4 levels, max 3
  
  // Query available affixes
  QueryResult res = CharacterDatabase.Query(
    "SELECT affix_id FROM mythic_affixes WHERE min_mythic_level <= %u ORDER BY RAND() LIMIT %u",
    level, affixCount
  );
  
  if (res) {
    do {
      result.push_back(res->Fetch()[0].Get<uint32>());
    } while (res->NextRow());
  }
  
  return result;
}
```

### **2. Timer System Implementation**

```cpp
// File: src/server/scripts/Custom/MythicPlus/MythicDungeonTimer.h
#pragma once

class MythicDungeonTimer {
public:
  MythicDungeonTimer(uint32 instanceId, uint32 dungeonId, uint32 mythicLevel);
  
  void Start();
  void Stop();
  void Update(uint32 diff);
  
  bool IsExpired() const { return timeUsed >= timeLimit; }
  bool IsSuccess() const { return completed && !IsExpired(); }
  bool IsTwoChest() const { return timeUsed <= (timeLimit / 2); }
  bool IsThreeChest() const { return timeUsed <= (timeLimit / 3); }
  
  void OnPlayerDeath();
  void OnBossDefeated();
  void OnDungeonComplete();
  
  uint32 GetTimeRemaining() const { return timeLimit - timeUsed; }
  uint32 GetProgress() const { return (timeUsed * 100) / timeLimit; }
  
private:
  uint32 instanceId;
  uint32 dungeonId;
  uint32 mythicLevel;
  uint32 timeUsed = 0;
  uint32 timeLimit = 0;
  bool running = false;
  bool completed = false;
  
  void CalculateTimeLimit();
  void BroadcastUpdate();
};

// File: src/server/scripts/Custom/MythicPlus/MythicDungeonTimer.cpp
#include "MythicDungeonTimer.h"
#include "Instance.h"
#include "Map.h"

MythicDungeonTimer::MythicDungeonTimer(uint32 id, uint32 dung, uint32 level)
  : instanceId(id), dungeonId(dung), mythicLevel(level) {
  CalculateTimeLimit();
}

void MythicDungeonTimer::CalculateTimeLimit() {
  // Base times (in seconds)
  const uint32 baseTimes[] = {
    1800,   // M0: 30 min
    1500,   // M+1: 25 min
    1380,   // M+2: 23 min
    1260,   // M+3: 21 min
    1080,   // M+4: 18 min
    960,    // M+5: 16 min
    900,    // M+6: 15 min
    840,    // M+7: 14 min
    720,    // M+8: 12 min
    600,    // M+9: 10 min
    540,    // M+10: 9 min
    480,    // M+11: 8 min
    420,    // M+12: 7 min
    360,    // M+13: 6 min
    300,    // M+14: 5 min
    240,    // M+15+: 4 min
  };
  
  uint32 idx = std::min(mythicLevel, 15U);
  timeLimit = baseTimes[idx];
  
  LOG_DEBUG("mythic.timer", "Timer set for M+%u: %u seconds (%u minutes)",
    mythicLevel, timeLimit, timeLimit / 60);
}

void MythicDungeonTimer::Update(uint32 diff) {
  if (!running || completed || IsExpired()) return;
  
  timeUsed += diff;
  
  // Broadcast updates
  BroadcastUpdate();
  
  // Check for time warnings (Warn at 50%, 25%, 10%, 0%)
  uint32 progress = GetProgress();
  if (progress >= 50 && progress < 51) {
    // Broadcast: "50% time remaining"
  }
  if (progress >= 75 && progress < 76) {
    // Broadcast: "25% time remaining"
  }
}

void MythicDungeonTimer::BroadcastUpdate() {
  Map* map = sMapMgr->FindMap(instanceId & 0xFFFF, instanceId >> 16);
  if (!map) return;
  
  // Send timer update to all players in instance
  // Custom packet with current time, remaining time, progress
  // Players would see timer UI update
}
```

### **3. Scaling Engine**

```cpp
// File: src/server/scripts/Custom/MythicPlus/MythicScalingEngine.h
#pragma once

class MythicScalingEngine {
public:
  static MythicScalingEngine* instance();
  
  // Calculate scaling multipliers
  float GetHealthMultiplier(uint32 mythicLevel, bool isBoss);
  float GetDamageMultiplier(uint32 mythicLevel, bool isBoss);
  uint32 GetLootItemLevel(uint32 mythicLevel, bool chestBonus = false);
  
  // Apply to creature
  void ApplyScaling(Creature* creature, uint32 mythicLevel);
  
private:
  struct ScalingConfig {
    float baseHealthMod = 1.0f;
    float baseDamageMod = 1.0f;
    float perLevelHealthIncrease = 0.02f;  // +2% per level
    float perLevelDamageIncrease = 0.015f;  // +1.5% per level
  };
  
  ScalingConfig config;
};

// File: src/server/scripts/Custom/MythicPlus/MythicScalingEngine.cpp
#include "MythicScalingEngine.h"
#include "Creature.h"

MythicScalingEngine* MythicScalingEngine::instance() {
  static MythicScalingEngine instance;
  return &instance;
}

float MythicScalingEngine::GetHealthMultiplier(uint32 mythicLevel, bool isBoss) {
  if (mythicLevel == 0) return 1.0f;  // M0 = normal
  
  float baseMul = 1.10f;  // Base 110% for M0
  if (isBoss) baseMul = 1.25f;  // Mythic base for bosses
  
  // Add per-level scaling
  float perLevel = config.perLevelHealthIncrease;
  return baseMul + (mythicLevel * perLevel);
}

float MythicScalingEngine::GetDamageMultiplier(uint32 mythicLevel, bool isBoss) {
  if (mythicLevel == 0) return 1.0f;
  
  float baseMul = 1.08f;  // Base 108% for M0
  if (isBoss) baseMul = 1.20f;  // Mythic base for bosses
  
  float perLevel = config.perLevelDamageIncrease;
  return baseMul + (mythicLevel * perLevel);
}

uint32 MythicScalingEngine::GetLootItemLevel(uint32 mythicLevel, bool chestBonus) {
  // Base item level (M0 or regular mythic dungeon)
  uint32 baseiLvl = 480;
  
  // Scaling per level
  uint32 increment = 2;  // +2 ilvl per level
  uint32 iLvl = baseiLvl + (mythicLevel * increment);
  
  // Bonus for timer
  if (chestBonus) iLvl += 3;
  
  return iLvl;
}

void MythicScalingEngine::ApplyScaling(Creature* creature, uint32 mythicLevel) {
  if (!creature) return;
  
  bool isBoss = creature->GetCreatureType() == CREATURE_TYPE_HUMANOID;  // Simplified
  
  // Calculate multipliers
  float healthMul = GetHealthMultiplier(mythicLevel, isBoss);
  float damageMul = GetDamageMultiplier(mythicLevel, isBoss);
  
  // Apply to creature
  uint32 baseHealth = creature->GetMaxHealth();
  creature->SetMaxHealth((uint32)(baseHealth * healthMul));
  creature->SetHealth((uint32)(baseHealth * healthMul));
  
  creature->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, 
    creature->GetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE) * damageMul);
  creature->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE,
    creature->GetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE) * damageMul);
  
  LOG_DEBUG("mythic.scaling", "Applied M+%u scaling to creature %u: HP x%.2f, DMG x%.2f",
    mythicLevel, creature->GetEntry(), healthMul, damageMul);
}
```

### **4. Affix System**

```cpp
// File: src/server/scripts/Custom/MythicPlus/MythicAffixSystem.h
#pragma once

enum MythicAffix : uint32 {
  AFFIX_NONE = 0,
  AFFIX_TYRANNICAL = 1,
  AFFIX_FORTIFIED = 2,
  AFFIX_EXPLOSIVE = 3,
  AFFIX_RAGING = 4,
  AFFIX_BOLSTERING = 5,
  AFFIX_SANGUINE = 6,
  AFFIX_VOLCANIC = 7,
  AFFIX_QUAKING = 8,
  AFFIX_TEEMING = 9,
  AFFIX_BURSTING = 10,
};

class MythicAffixSystem {
public:
  static MythicAffixSystem* instance();
  
  void ApplyAffixes(Creature* creature, std::vector<MythicAffix> affixes);
  void RemoveAffixes(Creature* creature);
  
  // Affix-specific logic hooks
  void OnCreatureDie(Creature* creature, std::vector<MythicAffix> affixes);
  void OnPlayerHurt(Player* player, std::vector<MythicAffix> affixes);
  
private:
  std::unordered_map<uint32, std::vector<MythicAffix>> creatureAffixes;
};

// Key Affix Implementations:

// TYRANNICAL: Boss +15% HP, +15% Damage
void ApplyTyrannical(Creature* creature) {
  creature->SetMaxHealth((uint32)(creature->GetMaxHealth() * 1.15f));
  creature->SetHealth((uint32)(creature->GetHealth() * 1.15f));
  // Apply damage modifier via spell/aura
}

// EXPLOSIVE: Spawn orbs on trash death
void OnCreatureDieTeeming(Creature* creature) {
  // Create 3-4 "Explosive Orb" GameObjects at corpse location
  // Orbs explode after 5 seconds dealing AoE damage
}

// RAGING: Creature gets rage meter, higher damage when enraged
void ImplementRaging(Creature* creature) {
  // Add custom rage mechanic
  // At 100 rage: +25% damage
  // Rage increases over time and from being hit
}

// BOLSTERING: When trash dies, nearby trash heal and get +5% stats
void OnTrashDieBolstering(Creature* dying) {
  std::list<Creature*> nearby = dying->FindNearestCreatures(15.0f);
  for (auto nearby_creature : nearby) {
    nearby_creature->SetMaxHealth((uint32)(nearby_creature->GetMaxHealth() * 1.05f));
    nearby_creature->HealBySpell(nearby_creature, nearby_creature->GetMaxHealth() * 0.5f);
  }
}
```

### **5. Rating System**

```cpp
// File: src/server/scripts/Custom/MythicPlus/MythicRatingSystem.h
#pragma once

class MythicRatingSystem {
public:
  static MythicRatingSystem* instance();
  
  // Calculate rating change after dungeon completion
  float CalculateRatingGain(const MythicRunData& runData);
  void UpdatePlayerRating(uint32 playerGuid, float ratingChange, uint32 season);
  
  // Leaderboard management
  void UpdateLeaderboard(uint32 season);
  std::vector<LeaderboardEntry> GetLeaderboard(uint32 season, uint32 limit = 100);
  
private:
  struct RatingCalcParams {
    float baseRating = 10.0f;
    float multiplierPerLevel = 1.5f;  // M+5 = 1.5x rating gain vs M+1
    float timerBonus = 0.5f;  // +50% if timer met
    float deathPenalty = -2.0f;  // -2 rating per death
  };
  
  RatingCalcParams params;
};

// File: src/server/scripts/Custom/MythicPlus/MythicRatingSystem.cpp
#include "MythicRatingSystem.h"
#include "Database.h"

float MythicRatingSystem::CalculateRatingGain(const MythicRunData& runData) {
  float rating = params.baseRating;
  
  // Base rating per mythic level
  rating += (runData.mythicLevel * params.multiplierPerLevel);
  
  // Timer bonus
  if (runData.timerMet) {
    rating *= (1.0f + params.timerBonus);
  }
  
  // Death penalty (for each death)
  rating += (runData.deathCount * params.deathPenalty);
  
  // Minimum 0 rating gain (can't lose rating on completion)
  return std::max(0.0f, rating);
}

void MythicRatingSystem::UpdatePlayerRating(uint32 playerGuid, float ratingChange, uint32 season) {
  QueryResult res = CharacterDatabase.Query(
    "SELECT rating FROM mythic_plus_player_rating WHERE guid = %u AND season = %u",
    playerGuid, season
  );
  
  float newRating = ratingChange;  // Default new player
  
  if (res) {
    newRating = res->Fetch()[0].Get<float>() + ratingChange;
  }
  
  // Upsert into database
  CharacterDatabase.PExecute(
    "INSERT INTO mythic_plus_player_rating (guid, season, rating, updated_date) "
    "VALUES (%u, %u, %.2f, NOW()) "
    "ON DUPLICATE KEY UPDATE rating = %.2f, updated_date = NOW()",
    playerGuid, season, newRating, newRating
  );
  
  LOG_INFO("mythic.rating", "Updated rating for player %u: +%.2f new total: %.2f",
    playerGuid, ratingChange, newRating);
}
```

---

## 🎮 Integration Points

### **1. LFG/LFR Tool Integration**

```cpp
// In LFGMgr.cpp - Add mythic+ queue type
void LFGMgr::SetupGroupForDungeon(uint32 guidLeader, LFGDungeonData const* dungeon) {
  // Check if M+ dungeon
  if (dungeon->type == DUNGEON_TYPE_MYTHIC_PLUS) {
    uint32 mythicLevel = GetQueueMythicLevel(dungeon);  // Extract from queue
    MythicScalingEngine::instance()->PrepareInstance(dungeon->map, mythicLevel);
    MythicKeystoneManager::instance()->ApplyKeystone(guidLeader);
  }
}
```

### **2. Instance Creation Hook**

```cpp
// In InstanceMap::CreateInstanceScript()
void InstanceScript::OnInstanceCreated() {
  // Check if mythic+
  if (GetDifficulty() == RAID_DIFFICULTY_10MAN_HEROIC + 5) {  // Custom mythic+ flag
    uint32 mythicLevel = GetCustomDifficulty();
    timers.push_back(new MythicDungeonTimer(GetInstanceId(), GetDungeonId(), mythicLevel));
    
    // Apply initial scaling to all creatures
    auto creatures = instance->GetCreatures();
    for (auto creature : creatures) {
      MythicScalingEngine::instance()->ApplyScaling(creature, mythicLevel);
    }
  }
}
```

### **3. Loot Distribution Hook**

```cpp
// In Loot::FillLoot()
void Loot::FillLoot(uint32 lootId, LootStore const* store, Player* player) {
  // Check for mythic+ loot
  if (player && player->GetMap()->IsMythicPlus()) {
    uint32 mythicLevel = player->GetMap()->GetMythicLevel();
    
    // Apply item level scaling
    for (LootItem & item : items) {
      uint32 scaledILvl = MythicScalingEngine::instance()->GetLootItemLevel(mythicLevel);
      item.itemid = GetScaledItemByIlevel(item.itemid, scaledILvl);
    }
  }
}
```

---

## 🔧 Configuration File

**File: mythic_plus.conf**

```ini
# Mythic+ System Configuration

# Enable Mythic+ system
MythicPlus.Enabled = 1

# Scaling Configuration
MythicPlus.BaseHealthModifier = 1.10
MythicPlus.BaseDamageModifier = 1.08
MythicPlus.PerLevelHealthIncrease = 0.02
MythicPlus.PerLevelDamageIncrease = 0.015

# Boss Scaling (higher than trash)
MythicPlus.BossHealthModifier = 1.25
MythicPlus.BossDamageModifier = 1.20

# Rating System
MythicPlus.BaseRatingGain = 10.0
MythicPlus.RatingMultiplierPerLevel = 1.5
MythicPlus.RatingTimerBonus = 0.5
MythicPlus.RatingDeathPenalty = -2.0

# Timer Configuration (in seconds)
MythicPlus.TimerM0 = 1800
MythicPlus.TimerM1 = 1500
MythicPlus.TimerM2 = 1380
# ... etc

# Loot Configuration
MythicPlus.BaseLootIlvl = 480
MythicPlus.IlvlIncrementPerLevel = 2
MythicPlus.TimerBonusIlvl = 3

# Season Configuration
MythicPlus.CurrentSeason = 1
MythicPlus.SeasonDuration = 2592000  # 30 days in seconds
MythicPlus.WeeklyResetDay = 3  # Wednesday = 3

# Difficulty Limits
MythicPlus.MinimumPlayerLevel = 80
MythicPlus.MaximumMythicLevel = 20
MythicPlus.StarterMythicLevel = 2

# Affix Configuration
MythicPlus.AffixCount.M0toM3 = 0
MythicPlus.AffixCount.M4to6 = 1
MythicPlus.AffixCount.M7to9 = 2
MythicPlus.AffixCount.M10Plus = 3
```

---

## 📊 Testing Checklist

### **Unit Tests**

- [ ] Scaling calculations correct for all levels
- [ ] Timer starts and stops correctly
- [ ] Affixes apply/remove properly
- [ ] Rating gains calculated accurately
- [ ] Loot scaling to correct item levels
- [ ] Keystone upgrade logic works
- [ ] Database queries optimize properly

### **Integration Tests**

- [ ] Players can queue M+ dungeons
- [ ] Dungeons spawn with correct scaling
- [ ] Timer displays correctly for all players
- [ ] Affixes visible in UI
- [ ] Loot awarded at dungeon end
- [ ] Rating updates after completion
- [ ] Leaderboards update hourly

### **Load Tests**

- [ ] 100 concurrent M+ runs
- [ ] Database query times <100ms
- [ ] No memory leaks over 24 hour period
- [ ] CPU usage stays <15% for M+ systems

---

## 🚀 Deployment Script

```bash
#!/bin/bash
# deploy_mythic_plus.sh

echo "Deploying Mythic+ System..."

# 1. Backup database
echo "Backing up database..."
mysqldump -u $DB_USER -p$DB_PASS world > world_backup_$(date +%Y%m%d).sql

# 2. Apply SQL schema
echo "Applying database schema..."
mysql -u $DB_USER -p$DB_PASS world < mythic_plus_schema.sql

# 3. Copy C++ files
echo "Copying source files..."
cp -r src/scripts/Custom/MythicPlus/* $WOW_SOURCE/src/server/scripts/Custom/

# 4. Rebuild
echo "Rebuilding authserver and worldserver..."
cd $WOW_BUILD
cmake -DCMAKE_INSTALL_PREFIX=$WOW_INSTALL ..
make -j4
make install

# 5. Load config
echo "Copying configuration..."
cp mythic_plus.conf $WOW_INSTALL/etc/

# 6. Restart servers
echo "Restarting world server..."
systemctl restart azerothcore-worldserver

echo "✅ Mythic+ System Deployed Successfully!"
```

---

## 📋 Success Criteria

✅ **System Ready When:**
- All database tables created and indexed
- C++ compilation succeeds without warnings
- All unit tests pass
- Integration tests complete successfully
- Load tests show acceptable performance
- Soft launch to test group successful
- Documentation complete

---

**Status: ✅ COMPLETE TECHNICAL BLUEPRINT READY FOR DEVELOPMENT**
