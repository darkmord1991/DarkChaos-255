# Party Sync / Level Sync / Mentor System

**Priority:** A3 (High)  
**Effort:** Medium-High (4-6 weeks)  
**Impact:** Medium-High  
**Client Required:** No (can enhance with AIO addon)

---

## Overview

A system that allows players of different levels to play together meaningfully. Higher-level players can sync down to lower-level friends, making quests and content relevant for both. Includes a mentor/apprentice system for rewarding help.

---

## Why This Feature?

### Player Psychology
- **Friend Recruitment**: Biggest barrier is "my friends are max level already"
- **Community Building**: Veterans help newbies, creating bonds
- **Content Relevance**: Old content becomes viable again
- **Alt-Friendly**: Max level mains can join alt runs

### Competitor Examples
- **Retail WoW**: Party Sync (since 8.2.5), Mentor Guide System
- **FFXIV**: Level Sync, Duty Roulette
- **ESO**: One Tamriel (all zones scale to player)
- **ChromieCraft**: Progressive level caps

### DC Context
- Already have **Hotspot XP** for dynamic leveling bonuses
- Integrates with **Prestige System** (prestige players as mentors)
- Complements **Mythic+** (sync for teaching runs)

---

## Available Modules & Building Blocks

### AzerothCore Modules

| Module | Relevance | Notes |
|--------|-----------|-------|
| **mod-autobalance** | ⭐⭐⭐ HIGH | Scales dungeon content to player count/level - can be adapted |
| **mod-zone-difficulty** | ⭐⭐ MEDIUM | Per-zone difficulty modifiers |
| **mod-individual-xp** | ⭐⭐ MEDIUM | Players set own XP rate |
| **mod-solocraft** | ⭐ LOW | Solo dungeon scaling |
| **mod-playerbots** | ⭐ LOW | Can fill party spots |

### Custom Development Required

No direct "Party Sync" module exists for AzerothCore/TrinityCore. This would need custom implementation building on:
- Stat scaling from `mod-autobalance`
- Temporary aura application for level reduction
- Quest synchronization logic

---

## Feature Specification

### Core Mechanics

```
PARTY SYNC SYSTEM
├── Sync Trigger: Command /partysync or UI button
├── Sync Target: Lowest level member in group
├── Synced Stats: All stats scaled to target level
├── Duration: Until party disbands or /partysync off
├── Cooldown: None (can toggle freely)
└── Restrictions: Only in open world, not in M+ or HLBG
```

### Sync Levels

| Sync Type | Description | Use Case |
|-----------|-------------|----------|
| **Full Sync** | Stats, abilities, gear scaled to target | Questing with newbies |
| **Dungeon Sync** | Enter old dungeons at scaled level | Run friends through content |
| **XP Share** | Synced player grants bonus XP to lower | Speed leveling help |
| **Mentor Mode** | Permanent mentor designation | Teaching new players |

### Stat Scaling Formula

When a Level 255 player syncs to a Level 50 player:

```
Synced Stats = Base Stats at Sync Level × (1 + Gear Bonus%)

Where:
- Base Stats = What a fresh character would have at that level
- Gear Bonus = 0-30% based on gear quality (rewards having good gear)

Example:
- Level 255 player has 50,000 Attack Power
- Level 50 base = 500 Attack Power
- With Epic gear = 500 × 1.30 = 650 Attack Power (synced)
```

---

## 3.3.5a Equipment Handling (Critical Technical Consideration)

### The Problem

In WoW 3.3.5a, items have **RequiredLevel** checks. Setting `Player::SetLevel(50)` forcibly unequips high-level gear. We need a **transparent, automatic** solution like retail Timewalking.

---

## ⭐ RECOMMENDED: Timewalking-Style Automatic Approach

The goal: **Player does nothing, server handles everything, client sees nothing unusual.**

### How Retail Timewalking Works

In retail, when you enter a Timewalking dungeon:
1. Your level is scaled down to match content
2. Your gear stats are automatically scaled
3. You keep your gear equipped (visually)
4. High-level abilities may be restricted
5. When you leave, everything reverts

### 3.3.5a Implementation: "Invisible Scaling"

**The trick:** Don't change player level at all. Instead, **scale creature stats UP** to match the player, while **scaling player effective stats DOWN** via auras.

```
TIMEWALKING-STYLE SYNC
├── Player Level: UNCHANGED (stays 255)
├── Gear: STAYS EQUIPPED (no changes visible)
├── Player Stats: REDUCED via hidden auras (server-side calculation)
├── Creature Stats: SCALED to player's "effective" level
├── Spells: High-level spells blocked server-side (no UI change)
└── Client: Sees NOTHING unusual - gear stays on, level stays 255
```

### Technical Implementation

```

### Health Scaling

The stat aura reduces **Stamina**, which naturally reduces max health:

| Sync Level | Health Reduction | Example HP (from 500k) |
|------------|------------------|------------------------|
| 255 → 100 | -61% | ~195,000 HP |
| 255 → 50 | -80% | ~100,000 HP |
| 255 → 20 | -92% | ~40,000 HP |

For more authentic "low level feel", add a health cap:

```cpp
// Cap to approximate level-50-like health
uint32 targetHP = GetBaseHealthForLevel(syncLevel, player->GetClass());
player->SetMaxHealth(targetHP);
player->SetHealth(targetHP);
```

---

### Dungeon/Creature Scaling

**Two approaches depending on use case:**

#### Option 1: Player Syncs Down to Dungeon Level (Timewalking)

NPCs stay at their **original level**. Player stats are reduced to match.

```
Synced Player (255→50) enters Scarlet Monastery (Level 30-45 mobs)
├── Player effective level: 50
├── Player stats: Reduced ~80%
├── Mob levels: Unchanged (30-45)
├── Experience: Scales based on original player level
└── Result: Player fights mobs as if they were level 50
```

**Use case:** Timewalking dungeons, helping friends in old content.

#### Option 2: Content Scales to Synced Group (DC Dungeons)

NPCs **scale dynamically** based on group's highest effective level. Uses `mod-autobalance` style scaling.

```cpp
// Hook creature spawn or UpdateStats
void ScaleCreatureToSyncGroup(Creature* creature, Map* map)
{
    Group* group = GetLeaderGroup(map);
    if (!group) return;
    
    // Find highest EFFECTIVE level in group
    uint32 targetLevel = 0;
    for (GroupReference* itr = group->GetFirstMember(); itr; itr = itr->next())
    {
        Player* member = itr->GetSource();
        uint32 effectiveLevel = sPartySyncMgr->GetEffectiveLevel(member);
        targetLevel = std::max(targetLevel, effectiveLevel);
    }
    
    // Scale creature to match
    float healthMod = GetHealthModForLevel(creature->GetLevel(), targetLevel);
    float damageMod = GetDamageModForLevel(creature->GetLevel(), targetLevel);
    
    creature->SetMaxHealth(creature->GetMaxHealth() * healthMod);
    creature->SetHealth(creature->GetMaxHealth());
    // Apply damage modifier via aura or direct stat change
}
```

**Use case:** Leveling dungeons where mixed groups need fair challenge.

#### Option 3: Hybrid - Level Bracket Scaling

Scale to **level brackets** for simpler implementation:

| Bracket | Effective Level | Dungeon Range |
|---------|-----------------|---------------|
| 1-60 | 60 | Classic dungeons |
| 60-80 | 80 | TBC/WotLK dungeons |
| 80-160 | 160 | DC custom content |
| 160-255 | Player's actual | Endgame |

When a synced group enters Deadmines (level 15-21), all scale to bracket 60.

---

### Recommended: Separation of Concerns

| Content Type | Player Scaling | NPC Scaling |
|--------------|----------------|-------------|
| **Open World** | Sync to lowest party member | NPCs unchanged |
| **Timewalking** | Sync to dungeon bracket | NPCs unchanged |
| **Leveling Dungeon** | Sync to lowest | NPCs scale UP to effective level |
| **Mythic+** | No sync allowed | M+ scaling applies |
| **HLBG** | No sync allowed | N/A |

```cpp
bool PartySyncMgr::ShouldScaleNPCs(Map* map)
{
    // Only scale NPCs in leveling dungeons, not timewalking
    return map->IsNonRaidDungeon() && !IsTimewalkingDungeon(map->GetId());
}
```cpp
// When player enters synced content (e.g., via queue or group sync)
class PartySyncScaling
{
public:
    // Calculate effective level for combat calculations
    uint32 GetEffectiveLevel(Player* player)
    {
        if (IsSynced(player))
            return _syncData[player->GetGUID()].effectiveLevel;
        return player->GetLevel();
    }
    
    // Apply on sync start (completely transparent to client)
    void ApplySync(Player* player, uint32 targetLevel)
    {
        SyncData& data = _syncData[player->GetGUID()];
        data.originalLevel = player->GetLevel();
        data.effectiveLevel = targetLevel;
        data.isActive = true;
        
        // Apply HIDDEN stat scaling aura
        // This aura has no visual/icon - purely stat modifier
        ApplyInvisibleScalingAura(player, targetLevel);
        
        // Register player for spell restriction checks
        RegisterSpellFilter(player, targetLevel);
        
        // NO SetLevel() call - player stays 255
        // NO gear changes - equipment stays on
        // NO visible auras - completely transparent
    }
    
    void RemoveSync(Player* player)
    {
        RemoveInvisibleScalingAura(player);
        UnregisterSpellFilter(player);
        _syncData.erase(player->GetGUID());
    }

private:
    void ApplyInvisibleScalingAura(Player* player, uint32 targetLevel)
    {
        float ratio = (float)targetLevel / player->GetLevel();
        
        // Create dynamic aura with calculated values
        // Use spell with SPELL_ATTR0_HIDDEN_CLIENTSIDE
        SpellInfo const* syncSpell = sSpellMgr->GetSpellInfo(SPELL_PARTY_SYNC_HIDDEN);
        
        // Apply with calculated values:
        // Effect 0: SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE (all stats)
        // Effect 1: SPELL_AURA_MOD_DAMAGE_PERCENT_DONE
        // Effect 2: SPELL_AURA_MOD_HEALING_DONE_PERCENT
        
        int32 statMod = (int32)((ratio - 1.0f) * 100); // e.g., -80 for 255→50
        
        Aura* aura = player->AddAura(SPELL_PARTY_SYNC_HIDDEN, player);
        if (aura)
        {
            // Set dynamic values for scaling
            aura->SetAmount(0, statMod);  // Stats
            aura->SetAmount(1, statMod);  // Damage
            aura->SetAmount(2, statMod);  // Healing
        }
    }
};
```

### Hidden Spell Design

Create a spell that is **invisible to the client**:

```sql
INSERT INTO `spell_dbc` VALUES
(90001, -- SpellID: SPELL_PARTY_SYNC_HIDDEN
 0x00000100, -- Attributes: SPELL_ATTR0_HIDDEN_CLIENTSIDE
 0, 0, 0, 0, 0, 0, 0, -- Other attributes
 'Party Sync Scaling', -- Name (never shown)
 -- Effects:
 -- 1: SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE
 -- 2: SPELL_AURA_MOD_DAMAGE_PERCENT_DONE (all schools)
 -- 3: SPELL_AURA_MOD_HEALING_DONE_PERCENT
);
```

**Key attribute:** `SPELL_ATTR0_HIDDEN_CLIENTSIDE` ensures the buff icon never appears.

### Spell Restriction (Transparent)

```cpp
// Hook into SpellMgr or Player::CastSpell
class PartySyncSpellFilter : public PlayerScript
{
public:
    void OnSpellCast(Player* player, Spell* spell, bool& cancel) override
    {
        if (!sPartySyncMgr->IsSynced(player))
            return;
        
        uint32 effectiveLevel = sPartySyncMgr->GetEffectiveLevel(player);
        SpellInfo const* info = spell->GetSpellInfo();
        
        // Block spells learned after effective level
        if (info->SpellLevel > effectiveLevel)
        {
            // Send "You cannot use that ability while synced" error
            player->SendEquipError(EQUIP_ERR_CANT_DO_RIGHT_NOW, nullptr);
            cancel = true;
        }
    }
};

// Alternative: Hook Spell::CheckCast() for cleaner integration
SpellCastResult Spell::CheckCast(bool strict)
{
    if (sPartySyncMgr->IsSynced(m_caster->ToPlayer()))
    {
        uint32 effectiveLevel = sPartySyncMgr->GetEffectiveLevel(m_caster);
        if (m_spellInfo->SpellLevel > effectiveLevel)
            return SPELL_FAILED_NOT_READY; // Or custom error
    }
    // ... rest of CheckCast
}
```

### When Does Sync Apply?

| Trigger | Behavior |
|---------|----------|
| **Join Group with Lower Player** | Auto-prompt: "Sync to [Name]'s level?" |
| **Enter Timewalking Queue** | Automatic on dungeon entry |
| **Enable Mentor Mode** | Always synced when with apprentice |
| **Manual Toggle** | `/sync on` or UI button |

### What the Player Experiences

```
PLAYER A (Level 255) groups with PLAYER B (Level 50)

1. System message: "Party Sync enabled. Your effective level is now 50."
2. PLAYER A's gear: STILL EQUIPPED (no visual change)
3. PLAYER A's level display: Still shows 255 in UI
4. PLAYER A's damage: Scaled down to level 50 equivalent
5. PLAYER A's spells: High-level ones show "Not available while synced" on cast
6. When PLAYER B leaves group: "Party Sync disabled."
```

### Client Addon Enhancement (Optional)

For better UX, the AIO addon can show sync status:

```lua
-- Show sync indicator in player frame
SyncIndicator = CreateFrame("Frame", nil, PlayerFrame)
SyncIndicator:SetSize(24, 24)
SyncIndicator:SetPoint("LEFT", PlayerFrame, "RIGHT", 5, 0)

SyncIndicator.icon = SyncIndicator:CreateTexture()
SyncIndicator.icon:SetTexture("Interface\\Icons\\spell_holy_borrowedtime")

SyncIndicator.text = SyncIndicator:CreateFontString()
SyncIndicator.text:SetFont("Fonts\\FRIZQT__.TTF", 12)
SyncIndicator.text:SetText("Lv 50")

-- Update from server message
function OnSyncMessage(effectiveLevel)
    if effectiveLevel then
        SyncIndicator:Show()
        SyncIndicator.text:SetText("Lv " .. effectiveLevel)
    else
        SyncIndicator:Hide()
    end
end
```

---

## Alternative Approaches (For Reference)

### Approach A: Visual-Only Sync (Recommended for 3.3.5a)

The player's **actual level stays 255**, but stats are modified via auras. Equipment remains equipped.

```cpp
// DON'T change actual level
// player->SetLevel(syncLevel); // WRONG - unequips gear!

// Instead, apply stat reduction auras
void PartySyncMgr::ApplyStatScaling(Player* player)
{
    SyncData& data = _syncedPlayers[player->GetGUID()];
    uint32 syncLevel = data.syncLevel;
    
    // Calculate reduction percentage
    // Level 255 → 50 = reduce stats by ~80%
    float reductionPct = 1.0f - ((float)syncLevel / player->GetLevel());
    
    // Apply custom aura that reduces all stats
    // Use SPELL_AURA_MOD_STAT with negative values
    // Or custom SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE
    
    int32 statReduction = -(int32)(reductionPct * 100);
    
    // Custom spell with effects:
    // - Reduce all stats by X%
    // - Reduce damage dealt by X%
    // - Reduce healing done by X%
    // - Reduce armor by X%
    player->CastCustomSpell(player, SPELL_PARTY_SYNC_DEBUFF, 
                            &statReduction, nullptr, nullptr, 
                            TRIGGERED_FULL_MASK);
    
    // Fake the displayed level for group UI
    // This is client addon work, not actual SetLevel
    data.displayedLevel = syncLevel;
}
```

**Pros:**
- Equipment stays on
- No inventory management issues
- Simple for players to understand
- Visually the character looks the same (familiar)

**Cons:**
- Character "looks" level 255 but acts level 50
- Requires careful aura math for balance
- High-level abilities still usable (may need separate restrictions)

---

#### Approach B: Temporary Gear Storage (Complex but Authentic)

Store gear in a temporary "sync bag", equip level-appropriate scaled items.

```cpp
struct SyncData
{
    ObjectGuid playerGuid;
    uint32 originalLevel;
    uint32 syncLevel;
    std::vector<Item*> storedGear; // Original equipment
    std::vector<uint32> syncGearEntries; // Template items to equip
};

void PartySyncMgr::ApplyFullSync(Player* player, uint32 targetLevel)
{
    SyncData& data = _syncedPlayers[player->GetGUID()];
    
    // Step 1: Store all current equipment
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
    {
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
        {
            data.storedGear.push_back(item);
            player->RemoveItem(INVENTORY_SLOT_BAG_0, slot, false);
        }
    }
    
    // Step 2: Actually change level (now safe, gear is removed)
    data.originalLevel = player->GetLevel();
    player->SetLevel(targetLevel);
    
    // Step 3: Equip "sync gear" - template items appropriate for level
    // These are special items with no stats that just provide visuals
    // Or we generate scaled versions of their original items
    EquipSyncGear(player, data);
    
    // Step 4: Apply bonus stats based on original gear quality
    ApplyGearQualityBonus(player, data.storedGear);
}

void PartySyncMgr::RemoveSync(Player* player)
{
    SyncData& data = _syncedPlayers[player->GetGUID()];
    
    // Remove sync gear
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        player->DestroyItem(INVENTORY_SLOT_BAG_0, slot, true);
    
    // Restore original level
    player->SetLevel(data.originalLevel);
    
    // Re-equip original gear
    for (Item* item : data.storedGear)
        player->EquipItem(item->GetSlot(), item, true);
    
    data.storedGear.clear();
}
```

**Pros:**
- Authentic level feeling
- Cannot use high-level abilities (naturally restricted)
- XP/loot drops work correctly for displayed level
- Could use level-appropriate enemy threat tables

**Cons:**
- Complex item management
- Risk of gear "loss" on crash/disconnect
- Need to create template sync items
- Inventory space concerns

---

#### Approach C: Hybrid (Recommended Implementation)

Use **Approach A** (stat auras) but combine with **ability restrictions**:

```cpp
void PartySyncMgr::ApplyHybridSync(Player* player, uint32 syncLevel)
{
    SyncData& data = _syncedPlayers[player->GetGUID()];
    data.syncLevel = syncLevel;
    
    // 1. Apply stat reduction aura (keeps gear equipped)
    ApplyStatReductionAura(player, syncLevel);
    
    // 2. Restrict spells learned above sync level
    RestrictHighLevelSpells(player, syncLevel);
    
    // 3. Show sync indicator in addon UI
    SendSyncStatus(player, true, syncLevel);
}

void PartySyncMgr::RestrictHighLevelSpells(Player* player, uint32 syncLevel)
{
    // Create a "spell lockout" that prevents casting spells
    // with SpellLevels.BaseLevel > syncLevel
    
    // Option 1: Apply aura that intercepts spell casts
    // Option 2: Temporarily unlearn and restore spells
    // Option 3: Use SPELL_AURA_DISABLE_SPELL for each high spell
    
    for (auto& spellPair : player->GetSpellMap())
    {
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellPair.first);
        if (spellInfo && spellInfo->BaseLevel > syncLevel)
        {
            // Add to restricted list (prevent casting server-side)
            data.restrictedSpells.insert(spellPair.first);
        }
    }
}

// Hook into spell cast validation
bool PartySyncMgr::CanCastSpell(Player* player, uint32 spellId)
{
    if (!IsSynced(player))
        return true;
    
    SyncData& data = _syncedPlayers[player->GetGUID()];
    return data.restrictedSpells.find(spellId) == data.restrictedSpells.end();
}
```

---

### Stat Aura Design (Approach A/C)

Create a custom spell with these effects:

| Aura Effect | Value | Purpose |
|-------------|-------|---------|
| `SPELL_AURA_MOD_STAT` | -X% per stat | Reduce primary stats |
| `SPELL_AURA_MOD_DAMAGE_PERCENT_DONE` | -X% | Reduce damage |
| `SPELL_AURA_MOD_HEALING_PERCENT` | -X% | Reduce healing |
| `SPELL_AURA_MOD_RESISTANCE_PCT` | -X% | Reduce resistances |
| `SPELL_AURA_MOD_ATTACK_POWER_PCT` | -X% | Reduce attack power |
| `SPELL_AURA_MOD_SPELL_POWER_PCT` | -X% | Reduce spell power |

**Scaling Table:**

| Sync From | Sync To | Stat Reduction |
|-----------|---------|----------------|
| 255 | 200 | -22% |
| 255 | 150 | -41% |
| 255 | 100 | -61% |
| 255 | 80 | -69% |
| 255 | 50 | -80% |
| 255 | 20 | -92% |

---

### XP Rewards When Synced

| Activity | Synced Player | Lower Player |
|----------|---------------|--------------|
| Quest Completion | Gold only (no XP) | 100% XP |
| Mob Kill | Gold only | 100% XP + 20% bonus |
| Dungeon Boss | Upgrade Tokens | 100% XP + 50% bonus |
| Achievement | Normal | Normal + mentor bonus |

---

## Mentor System

### Becoming a Mentor

**Requirements:**
- Level 255
- Completed main story achievements
- 10+ dungeons completed
- No recent player reports

**Benefits of Being a Mentor:**
- Special "Mentor" title and chat icon
- +10% gold from synced content
- Monthly mentor leaderboard
- Exclusive mentor transmog set (seasonal)
- Battle Pass XP for helping newbies

### Apprentice System

**Auto-Detection:**
- New accounts (< 7 days)
- Characters under level 80
- First character on account

**Apprentice Benefits:**
- Paired with active mentor on login
- Special chat channel access
- Weekly care package (gold, potions)
- Free talent respec

### Mentor-Apprentice Pairing

```
PAIRING LOGIC:
1. New player creates character
2. System offers "Want a mentor?" prompt
3. Accept → Added to mentor queue
4. Active mentor logs in → Notification: "New apprentice needs help!"
5. Mentor accepts → Permanent pairing until graduation
6. Graduation at Level 160 → Both get rewards
```

---

## Technical Implementation

### Database Schema

```sql
-- Party sync state
CREATE TABLE `dc_party_sync` (
    `guid` INT UNSIGNED NOT NULL,
    `synced_to_guid` INT UNSIGNED, -- Who they're synced to
    `original_level` INT UNSIGNED,
    `synced_level` INT UNSIGNED,
    `sync_start_time` DATETIME,
    `is_active` TINYINT(1) DEFAULT 0,
    PRIMARY KEY (`guid`)
);

-- Mentor registration
CREATE TABLE `dc_mentors` (
    `guid` INT UNSIGNED NOT NULL,
    `mentor_since` DATETIME,
    `total_apprentices` INT UNSIGNED DEFAULT 0,
    `graduated_apprentices` INT UNSIGNED DEFAULT 0,
    `mentor_score` FLOAT DEFAULT 0,
    `is_active` TINYINT(1) DEFAULT 1,
    PRIMARY KEY (`guid`)
);

-- Apprentice tracking
CREATE TABLE `dc_apprentices` (
    `guid` INT UNSIGNED NOT NULL,
    `mentor_guid` INT UNSIGNED,
    `assigned_date` DATETIME,
    `graduation_date` DATETIME,
    `current_level` INT UNSIGNED,
    `hours_with_mentor` FLOAT DEFAULT 0,
    `is_graduated` TINYINT(1) DEFAULT 0,
    PRIMARY KEY (`guid`)
);

-- Mentor-apprentice session tracking
CREATE TABLE `dc_mentor_sessions` (
    `session_id` INT UNSIGNED AUTO_INCREMENT,
    `mentor_guid` INT UNSIGNED NOT NULL,
    `apprentice_guid` INT UNSIGNED NOT NULL,
    `session_start` DATETIME,
    `session_end` DATETIME,
    `xp_earned` BIGINT UNSIGNED,
    `levels_gained` INT UNSIGNED,
    PRIMARY KEY (`session_id`)
);
```

### Server Components

```cpp
// PartySyncMgr.h
class PartySyncMgr
{
public:
    static PartySyncMgr* Instance();
    
    // Sync Management
    bool CanSync(Player* player);
    void StartSync(Player* player, Player* target);
    void EndSync(Player* player);
    void UpdateSyncedStats(Player* player);
    
    // Stat Calculation
    uint32 CalculateSyncedLevel(Player* syncer, Player* target);
    Stats CalculateSyncedStats(Player* player, uint32 syncLevel);
    void ApplyStatScaling(Player* player);
    void RemoveStatScaling(Player* player);
    
    // Group Integration
    void OnGroupFormed(Group* group);
    void OnGroupDisbanded(Group* group);
    void OnMemberJoin(Group* group, Player* player);
    void OnMemberLeave(Group* group, Player* player);
    
    // Quest Sync
    void SyncQuestStates(Group* group);
    bool CanPlayerShareQuest(Player* sharer, Player* receiver);

private:
    std::unordered_map<ObjectGuid, SyncData> _syncedPlayers;
};

// MentorMgr.h
class MentorMgr
{
public:
    static MentorMgr* Instance();
    
    // Mentor Management
    bool CanBecomeMentor(Player* player);
    void RegisterMentor(Player* player);
    void UnregisterMentor(Player* player);
    
    // Pairing
    void AssignApprentice(Player* mentor, Player* apprentice);
    void RemoveApprentice(Player* mentor, ObjectGuid apprenticeGuid);
    void GraduateApprentice(ObjectGuid apprenticeGuid);
    
    // Session Tracking
    void StartSession(Player* mentor, Player* apprentice);
    void EndSession(ObjectGuid mentorGuid, ObjectGuid apprenticeGuid);
    void UpdateSessionStats(Player* mentor, Player* apprentice, uint32 xp);
    
    // Rewards
    void GrantMentorReward(Player* mentor, MentorRewardType type);
    void GrantGraduationRewards(Player* mentor, Player* apprentice);

private:
    std::unordered_map<ObjectGuid, MentorData> _mentors;
    std::unordered_map<ObjectGuid, ApprenticeData> _apprentices;
};
```

### Stat Scaling Implementation

Building on `mod-autobalance` concepts:

```cpp
void PartySyncMgr::ApplyStatScaling(Player* player)
{
    SyncData& data = _syncedPlayers[player->GetGUID()];
    uint32 syncLevel = data.syncedLevel;
    
    // Store original stats
    data.originalStats = CaptureStats(player);
    
    // Calculate scaled values
    float levelRatio = (float)syncLevel / player->GetLevel();
    float gearBonus = CalculateGearBonus(player); // 1.0 to 1.3
    
    // Apply stat aura (custom aura that modifies all stats)
    int32 statMod = -(100 - (int32)(levelRatio * gearBonus * 100));
    player->CastCustomSpell(player, SPELL_PARTY_SYNC_AURA, &statMod, nullptr, nullptr, true);
    
    // Update displayed level (visual only)
    data.displayLevel = syncLevel;
    player->SetLevel(syncLevel); // Server treats as this level
    
    // Restrict high-level abilities
    RestrictAbilities(player, syncLevel);
}
```

---

## UI Integration (AIO Addon)

### Party Frame Addition

```lua
-- Add sync button to party frames
PartyMemberFrame_CreateSyncButton = function(frame)
    local syncBtn = CreateFrame("Button", nil, frame)
    syncBtn:SetSize(16, 16)
    syncBtn:SetPoint("TOPLEFT", 0, 0)
    syncBtn:SetNormalTexture("Interface\\Icons\\spell_holy_crusade")
    
    syncBtn:SetScript("OnClick", function()
        SendAddonMessage("DC_PSYNC", "TOGGLE", "PARTY")
    end)
    
    syncBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Party Sync")
        GameTooltip:AddLine("Click to sync your level to the lowest party member", 1, 1, 1)
        GameTooltip:Show()
    end)
end
```

### Sync Status Frame

```
┌─────────────────────────────────────┐
│  🔄 PARTY SYNC ACTIVE               │
├─────────────────────────────────────┤
│  Your Level: 255 → 52 (synced)      │
│  Synced To: [PlayerName] (Lv 52)    │
│  XP Bonus: +20% to party members    │
│                                     │
│  [🔓 End Sync]                      │
└─────────────────────────────────────┘
```

---

## Integration Points

| System | Integration |
|--------|-------------|
| **Prestige** | Prestige players auto-qualify as mentors |
| **Hotspot** | Synced groups get bonus hotspot XP |
| **Battle Pass** | Mentoring activities grant BP XP |
| **Leaderboards** | Top mentors displayed |
| **Seasonal** | Seasonal mentor rewards |

---

## Implementation Phases

### Phase 1: Basic Sync (Week 1-2)
- Command-based sync toggle
- Stat scaling calculations
- Group detection
- Dungeon support

### Phase 2: Mentor System (Week 3-4)
- Mentor registration
- Apprentice detection
- Pairing system
- Session tracking

### Phase 3: UI + Polish (Week 5-6)
- AIO addon UI
- Sync indicators
- Graduation rewards
- Leaderboards

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Exploitation (sync for PvP) | Disable sync in PvP areas/HLBG |
| Confusing stats | Clear UI showing original vs synced |
| Mentor abuse | Report system, activity requirements |
| Performance (stat recalculation) | Cache scaled stats, update only on level change |

---

## Success Metrics

- **Sync Usage**: 30% of groups use sync weekly
- **New Player Retention**: +25% at 7-day mark
- **Mentor Participation**: 100+ active mentors
- **Graduation Rate**: 50% of apprentices reach 160

---

*Detailed specs for Dark Chaos Party Sync & Mentor System - January 2026*
