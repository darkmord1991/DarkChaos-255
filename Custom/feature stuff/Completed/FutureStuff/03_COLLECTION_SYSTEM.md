# Collection & Achievement System

**Priority:** S3 - Critical  
**Effort:** Medium (2-3 weeks)  
**Impact:** High  
**Base:** Custom development with existing achievement framework

---

## Overview

A Collection & Achievement System tracks player progress across mounts, pets, titles, appearances, and custom DarkChaos content. This creates long-term goals, encourages exploration, and provides visible progression beyond gear.

---

## Why It Fits DarkChaos-255

### Synergies with Existing Systems

| Existing System | Integration Point |
|-----------------|-------------------|
| **Seasonal System** | Seasonal achievements, collection rewards |
| **Mythic+ System** | Achievement: Complete +15 all dungeons |
| **HLBG** | Achievement: Win 100 matches, reach rating X |
| **Item Upgrade** | Track total upgrades, milestone rewards |
| **Prestige** | Prestige achievements, milestone titles |
| **Transmogrification** | Track collected appearances |

### Player Engagement Value
- Long-term goals beyond max level
- "Gotta catch 'em all" psychology
- Visible progress and bragging rights
- Encourages content exploration

---

## Feature Highlights

### Core Collection Types

1. **Mount Collection**
   - Track all learned mounts
   - Display count: "X/Y Mounts Collected"
   - Milestone rewards (25, 50, 100, 150 mounts)

2. **Pet Collection** (Companion Pets)
   - Track non-combat pets
   - Similar milestone structure
   - Pet rarity tracking

3. **Title Collection**
   - Track earned titles
   - Display earned vs available
   - Seasonal title tracking

4. **Appearance Collection**
   - Track transmogrification appearances
   - Per-slot completion
   - Set completion bonuses

5. **Custom DarkChaos Achievements**
   - Mythic+ achievements
   - HLBG achievements
   - Item upgrade milestones
   - Seasonal achievements

### Achievement Categories
- General (exploration, quests)
- Dungeons & Raids
- PvP
- Professions
- Reputation
- **DarkChaos Special** (custom category)

### Milestone Rewards
| Milestone | Reward |
|-----------|--------|
| 25 Mounts | Title: "Stable Master" |
| 50 Mounts | Unique Mount (custom) |
| 100 Mounts | Tabard + Achievement Points |
| 25 Pets | Title: "Menagerie Keeper" |
| 50 Pets | Unique Pet |
| 100 Titles | Title: "The Collector" |
| All M+15 | Mount + Title |
| All HLBG Achievements | PvP Transmog Set |

---

## Technical Implementation

### Database Schema

```sql
-- Player collection tracking
CREATE TABLE dc_player_collections (
    player_guid INT UNSIGNED NOT NULL,
    collection_type ENUM('mount', 'pet', 'title', 'appearance', 'toy') NOT NULL,
    item_id INT UNSIGNED NOT NULL,
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50),  -- 'drop', 'vendor', 'achievement', 'quest'
    PRIMARY KEY (player_guid, collection_type, item_id),
    KEY idx_player (player_guid),
    KEY idx_type (collection_type)
);

-- Collection milestones
CREATE TABLE dc_collection_milestones (
    milestone_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    collection_type ENUM('mount', 'pet', 'title', 'appearance', 'toy'),
    required_count INT UNSIGNED,
    reward_type ENUM('title', 'mount', 'pet', 'item', 'spell', 'achievement_points'),
    reward_id INT UNSIGNED,
    reward_description VARCHAR(255)
);

-- Custom achievements
CREATE TABLE dc_custom_achievements (
    achievement_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    achievement_name VARCHAR(100),
    achievement_description TEXT,
    category ENUM('mythic_plus', 'hlbg', 'item_upgrade', 'seasonal', 'collection', 'general'),
    criteria_type VARCHAR(50),  -- 'counter', 'flag', 'list'
    criteria_data JSON,
    reward_points INT DEFAULT 10,
    reward_title_id INT UNSIGNED NULL,
    reward_item_id INT UNSIGNED NULL,
    icon_id INT UNSIGNED DEFAULT 0,
    is_hidden TINYINT DEFAULT 0
);

-- Player achievement progress
CREATE TABLE dc_player_achievement_progress (
    player_guid INT UNSIGNED NOT NULL,
    achievement_id INT UNSIGNED NOT NULL,
    progress INT DEFAULT 0,
    completed TINYINT DEFAULT 0,
    completed_at TIMESTAMP NULL,
    PRIMARY KEY (player_guid, achievement_id),
    KEY idx_completed (completed)
);

-- Achievement points total
CREATE TABLE dc_player_achievement_points (
    player_guid INT UNSIGNED PRIMARY KEY,
    total_points INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Sample Custom Achievements

```sql
INSERT INTO dc_custom_achievements VALUES
-- Mythic+ Achievements
(1, 'Keystone Initiate', 'Complete a Mythic+ dungeon at keystone level 2', 'mythic_plus', 
 'counter', '{"type": "mplus_complete", "min_level": 2}', 10, NULL, NULL, 0, 0),
(2, 'Keystone Hero', 'Complete all dungeons at Mythic+10 or higher', 'mythic_plus',
 'list', '{"type": "mplus_complete_all", "min_level": 10}', 50, 1001, NULL, 0, 0),
(3, 'Keystone Master', 'Complete all dungeons at Mythic+15 within the timer', 'mythic_plus',
 'list', '{"type": "mplus_timed_all", "min_level": 15}', 100, 1002, 500001, 0, 0),

-- HLBG Achievements  
(10, 'Hinterland Initiate', 'Win your first Hinterland Battleground', 'hlbg',
 'counter', '{"type": "hlbg_wins", "count": 1}', 10, NULL, NULL, 0, 0),
(11, 'Hinterland Veteran', 'Win 100 Hinterland Battlegrounds', 'hlbg',
 'counter', '{"type": "hlbg_wins", "count": 100}', 50, 1003, NULL, 0, 0),
(12, 'Gladiator', 'Reach 2400 rating in HLBG', 'hlbg',
 'counter', '{"type": "hlbg_rating", "min_rating": 2400}', 100, 1004, 500002, 0, 0),

-- Item Upgrade Achievements
(20, 'Upgrade Apprentice', 'Apply 10 item upgrades', 'item_upgrade',
 'counter', '{"type": "upgrades_applied", "count": 10}', 10, NULL, NULL, 0, 0),
(21, 'Upgrade Master', 'Fully upgrade an item to tier 3', 'item_upgrade',
 'counter', '{"type": "max_upgrade_tier", "tier": 3}', 50, NULL, NULL, 0, 0),

-- Seasonal Achievements
(30, 'Season 1 Participant', 'Complete any seasonal activity in Season 1', 'seasonal',
 'flag', '{"type": "season_participation", "season_id": 1}', 10, NULL, NULL, 0, 0),
(31, 'Season 1 Champion', 'Finish in the top 100 of Season 1', 'seasonal',
 'counter', '{"type": "season_rank", "season_id": 1, "max_rank": 100}', 100, 1005, 500003, 0, 0);
```

### Server-Side (C++)

```cpp
class CollectionManager {
public:
    // Collection tracking
    void OnMountLearned(Player* player, uint32 spellId);
    void OnPetLearned(Player* player, uint32 spellId);
    void OnTitleEarned(Player* player, uint32 titleId);
    void OnAppearanceCollected(Player* player, uint32 itemId);
    
    // Queries
    uint32 GetCollectionCount(uint32 playerGuid, CollectionType type);
    std::vector<uint32> GetMissingItems(uint32 playerGuid, CollectionType type);
    
    // Milestones
    void CheckMilestones(Player* player, CollectionType type);
    void AwardMilestone(Player* player, MilestoneDef* milestone);
    
    // Achievement progress
    void UpdateAchievementProgress(Player* player, AchievementCriteria criteria, int32 value);
    void CheckAchievementCompletion(Player* player, uint32 achievementId);
    void AwardAchievement(Player* player, uint32 achievementId);
    
    // Points
    uint32 GetAchievementPoints(uint32 playerGuid);
};

// Hook into existing systems
class CollectionPlayerScript : public PlayerScript {
public:
    void OnLearnSpell(Player* player, uint32 spellId) override {
        // Check if spell is a mount or pet
        if (IsMountSpell(spellId))
            sCollectionMgr->OnMountLearned(player, spellId);
        else if (IsPetSpell(spellId))
            sCollectionMgr->OnPetLearned(player, spellId);
    }
    
    void OnAuraApply(Player* player, Aura* aura) override {
        // Track title auras
        if (IsTitleAura(aura))
            sCollectionMgr->OnTitleEarned(player, GetTitleIdFromAura(aura));
    }
};
```

### Client Addon

```lua
-- Collection UI
local CollectionFrame = CreateFrame("Frame", "DCCollections", UIParent)
CollectionFrame:SetSize(800, 600)

-- Tabs
local tabs = {"Mounts", "Pets", "Titles", "Appearances", "Achievements"}

function CollectionFrame:DisplayMounts()
    local collected, total = GetMountCounts()
    self.header:SetText(string.format("Mounts: %d / %d", collected, total))
    
    -- Display grid of mount icons
    -- Collected = full color, Missing = greyed out
end

function CollectionFrame:DisplayAchievements()
    local categories = {"Mythic+", "PvP", "Collection", "Seasonal"}
    for _, cat in ipairs(categories) do
        -- Display achievement list with progress bars
    end
end

-- Minimap button or slash command
SLASH_COLLECTION1 = "/collection"
SLASH_COLLECTION2 = "/collect"
SlashCmdList["COLLECTION"] = function()
    CollectionFrame:Show()
end
```

---

## Integration with DarkChaos Systems

### Mythic+ Achievement Tracking
```cpp
// In MythicPlusRunManager.cpp
void OnDungeonComplete(Player* player, uint32 keystoneLevel, bool timed) {
    // Update achievement progress
    sCollectionMgr->UpdateAchievementProgress(player, 
        {"mplus_complete", keystoneLevel, timed});
    
    // Check category achievements
    sCollectionMgr->CheckAchievementCompletion(player, ACHIEVE_KEYSTONE_INITIATE);
    sCollectionMgr->CheckAchievementCompletion(player, ACHIEVE_KEYSTONE_HERO);
}
```

### Seasonal Achievement Integration
```cpp
// In SeasonalSystem.cpp
void OnSeasonEnd(uint32 seasonId) {
    // Award seasonal participation achievement
    for (auto& player : GetSeasonParticipants(seasonId)) {
        sCollectionMgr->UpdateAchievementProgress(player,
            {"season_participation", seasonId});
    }
    
    // Award top 100 achievement
    auto topPlayers = GetSeasonLeaderboard(seasonId, 100);
    for (auto& entry : topPlayers) {
        sCollectionMgr->UpdateAchievementProgress(entry.playerGuid,
            {"season_rank", seasonId, entry.rank});
    }
}
```

---

## Implementation Phases

### Phase 1 (Week 1): Core Framework
- [ ] Create database schema
- [ ] Implement CollectionManager class
- [ ] Add PlayerScript hooks
- [ ] Basic mount/pet tracking

### Phase 2 (Week 2): Achievements
- [ ] Custom achievement system
- [ ] Progress tracking
- [ ] Reward distribution
- [ ] Integration with existing systems (M+, HLBG)

### Phase 3 (Week 3): UI & Polish
- [ ] Client addon for collections
- [ ] Achievement display UI
- [ ] Milestone notifications
- [ ] Tooltips and icons

---

## Existing Resources

### WoW Achievement Data
- Achievement DBC files (reference for icons, structure)
- Existing character_achievement tables

### Similar Implementations
- Retail WoW Collections tab
- mod-achievements (AC module, basic)
- ChromieCraft achievement extensions

---

## Estimated Costs

| Resource | Estimate |
|----------|----------|
| Development Time | 2-3 weeks |
| Database Size | ~10KB per player |
| Server Memory | Minimal (cached queries) |
| Client Addon | 1 week |

---

## Success Metrics

- Achievement completion rates
- Collection progress averages
- Player engagement with collection UI
- Milestone reward claims

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Achievement exploits | Validate all progress server-side |
| Database bloat | Efficient schema, cleanup old data |
| UI complexity | Start simple, add tabs incrementally |
| Balance issues | Carefully tune milestone rewards |

---

**Recommendation:** Start with Mount/Pet tracking and Mythic+ achievements as proof of concept. Expand to full system based on player feedback.
