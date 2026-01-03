# Mount Collection Journal

**Priority:** B7 (Medium Priority)  
**Effort:** Medium (2 weeks)  
**Impact:** Medium  
**Base:** Custom AIO Addon + Server Database

---

## Overview

A retail-inspired mount journal that tracks collected mounts, shows acquisition sources, enables "summon random mount," and adds mount-related achievements. Adds collection gameplay to DarkChaos.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Achievements** | Mount collection achievements |
| **Seasonal** | Season-exclusive mounts |
| **Prestige** | Prestige mounts |
| **Mythic+** | M+ achievement mounts |
| **HLBG** | PvP achievement mounts |

### Benefits
- Collection endgame content
- Visible progression goal
- Social prestige (mount count)
- Random mount convenience
- Encourages content completion

---

## Features

### 1. **Mount Journal UI**
- Grid view of all mounts
- Collected vs uncollected display
- Filter by type (flying, ground, aquatic)
- Filter by source (raid, achievement, vendor)
- Search by name

### 2. **Account-Wide Collection**
- Mounts shared across characters
- Faction-specific mounts respected
- Class-specific mounts respected
- One database for all

### 3. **Summon Random Mount**
- Macro/button for random mount
- Favorite mounts list
- Smart selection (ground/flying based on zone)
- Weight system for preferences

### 4. **Mount Sources**
- Where to obtain each mount
- Drop rates displayed
- Quest chains indicated
- Vendor prices shown

---

## Implementation

### Database Schema
```sql
-- Account mount collection
CREATE TABLE dc_mount_collection (
    account_id INT UNSIGNED NOT NULL,
    mount_spell_id INT UNSIGNED NOT NULL,
    obtained_by INT UNSIGNED NOT NULL,  -- Character GUID
    obtained_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    times_used INT UNSIGNED DEFAULT 0,
    is_favorite BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (account_id, mount_spell_id)
);

-- Mount definitions (for UI)
CREATE TABLE dc_mounts (
    mount_spell_id INT UNSIGNED PRIMARY KEY,
    mount_name VARCHAR(100) NOT NULL,
    mount_type ENUM('ground', 'flying', 'aquatic', 'all') DEFAULT 'ground',
    mount_source ENUM('drop', 'vendor', 'achievement', 'quest', 'profession', 'event', 'promotion') NOT NULL,
    source_details TEXT,  -- JSON with location, drop rate, cost, etc.
    faction_required ENUM('alliance', 'horde', 'both') DEFAULT 'both',
    class_required TINYINT UNSIGNED DEFAULT 0,  -- 0 = all classes
    display_id INT UNSIGNED NOT NULL,
    icon_path VARCHAR(255) DEFAULT ''
);

-- Mount achievements
CREATE TABLE dc_mount_achievements (
    achievement_id INT UNSIGNED PRIMARY KEY,
    mount_count INT UNSIGNED NOT NULL,
    reward_mount_id INT UNSIGNED DEFAULT 0,
    reward_title_id INT UNSIGNED DEFAULT 0,
    achievement_name VARCHAR(100) NOT NULL
);

-- Sample mounts
INSERT INTO dc_mounts (mount_spell_id, mount_name, mount_type, mount_source, source_details) VALUES
(48778, 'Acherus Deathcharger', 'ground', 'quest', '{"quest": "Death Knight Intro"}'),
(458, 'Brown Horse', 'ground', 'vendor', '{"vendor": "Katie Hunter", "cost": 10000}'),
(32235, 'Golden Gryphon', 'flying', 'vendor', '{"vendor": "Brunn Flamebeard", "cost": 500000}'),
(63963, 'Rusted Proto-Drake', 'flying', 'achievement', '{"achievement": "Glory of the Ulduar Raider"}'),
(800001, 'Mythic Challenger', 'flying', 'achievement', '{"achievement": "Complete M+15"}');

-- Sample achievements
INSERT INTO dc_mount_achievements VALUES
(9001, 10, 0, 600, 'Stable Keeper'),
(9002, 25, 0, 601, 'Leading the Cavalry'),
(9003, 50, 800050, 602, 'Mountain o\' Mounts'),
(9004, 100, 800051, 603, 'We\'re Going to Need More Saddles'),
(9005, 200, 800052, 604, 'Mount Parade');
```

### Mount Manager (Server)
```cpp
class MountManager
{
public:
    static MountManager* instance();
    
    // Collection
    void LoadAccountMounts(uint32 accountId);
    bool HasMount(uint32 accountId, uint32 mountSpellId) const;
    void AddMount(Player* player, uint32 mountSpellId);
    std::vector<uint32> GetCollectedMounts(uint32 accountId) const;
    uint32 GetMountCount(uint32 accountId) const;
    
    // Random mount
    uint32 GetRandomMount(Player* player, bool preferFlying) const;
    uint32 GetRandomFavorite(Player* player) const;
    
    // Favorites
    void SetFavorite(uint32 accountId, uint32 mountSpellId, bool favorite);
    std::vector<uint32> GetFavorites(uint32 accountId) const;
    
    // Usage tracking
    void IncrementUsage(uint32 accountId, uint32 mountSpellId);
    uint32 GetMostUsedMount(uint32 accountId) const;
    
    // Achievements
    void CheckMountAchievements(Player* player);
    
private:
    std::unordered_map<uint32, AccountMountData> _accountMounts;
    std::unordered_map<uint32, MountDefinition> _mounts;
    
    void LoadMountDefinitions();
    bool CanUseMount(Player* player, uint32 mountSpellId) const;
};

#define sMountMgr MountManager::instance()
```

### AIO Addon (Client)
```lua
-- Mount Journal Frame
local MountJournal = CreateFrame("Frame", "DCMountJournal", UIParent)
MountJournal:SetSize(600, 500)
MountJournal:SetPoint("CENTER")

-- Mount list (scrollable grid)
MountJournal.grid = CreateScrollFrame(MountJournal, 8, 6)  -- 8 rows, 6 cols

-- Mount display (right panel)
MountJournal.preview = CreateModelFrame(MountJournal)
MountJournal.name = CreateFontString("GameFontNormalLarge")
MountJournal.source = CreateFontString("GameFontNormal")
MountJournal.summonButton = CreateButton("Summon")
MountJournal.favoriteButton = CreateButton("☆")

-- Filter buttons
MountJournal.filterAll = CreateButton("All")
MountJournal.filterGround = CreateButton("Ground")
MountJournal.filterFlying = CreateButton("Flying")
MountJournal.filterCollected = CreateButton("Collected")
MountJournal.filterNotCollected = CreateButton("Missing")

-- Random mount macro
/run SummonRandomMount()
/run SummonRandomFavorite()

function SummonRandomMount()
    local mounts = GetCollectedMounts()
    local canFly = CanFlyInCurrentZone()
    local eligible = FilterMountsByType(mounts, canFly and "flying" or "ground")
    local chosen = eligible[math.random(#eligible)]
    CastSpellByID(chosen)
end
```

---

## Mount Categories

### By Source
| Source | Example Mounts |
|--------|----------------|
| Drops | Rivendare's Deathcharger, Ashes of Al'ar |
| Vendors | Faction mounts, Flying mounts |
| Achievements | Proto-Drakes, Glory mounts |
| Quests | Argent Tournament, Epic quest chains |
| Professions | Engineering rockets, Tailoring carpets |
| Events | Brewfest Ram, Headless Horseman |
| DarkChaos Exclusive | Mythic mounts, HLBG mounts, Season mounts |

### Collection Achievements
| Achievement | Mounts | Reward |
|-------------|--------|--------|
| Stable Keeper | 10 | Title: Stable Keeper |
| Leading the Cavalry | 25 | Title: Leading the Cavalry |
| Mountain o' Mounts | 50 | Albino Drake mount |
| We're Going to Need More Saddles | 100 | Blue Dragonhawk mount |
| Mount Parade | 200 | Unique DarkChaos mount |

---

## Commands

### Player Commands
```
.mount list           - Show mount count
.mount random         - Summon random mount
.mount favorite <id>  - Toggle favorite
.mount journal        - Open mount journal (alternative)
```

### GM Commands
```
.mount add <p> <id>   - Give mount to player
.mount remove <p> <id> - Remove mount
.mount count <p>      - Show player's collection count
.mount reload         - Reload mount database
```

---

## Keybind Support

```lua
-- Suggested keybind: Shift+Y
BINDING_HEADER_MOUNTJOURNAL = "Mount Journal"
BINDING_NAME_TOGGLEMOUNTJOURNAL = "Toggle Mount Journal"
BINDING_NAME_SUMMONRANDOMMOUNT = "Summon Random Mount"
BINDING_NAME_SUMMONRANDOMFAVORITE = "Summon Random Favorite"
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| MountManager C++ | 3 days |
| Account-wide logic | 1 day |
| Random mount system | 1 day |
| AIO Journal addon | 4 days |
| Mount definitions | 1 day |
| Achievements | 1 day |
| Testing | 2 days |
| **Total** | **~2 weeks** |

---

## Future Enhancements

1. **Mount Equipment** - Equipment slots for mounts
2. **Mount Races** - Racing minigame
3. **Mount Transmog** - Change mount appearance
4. **Mount Trading** - Trade rare mount tokens
5. **Guild Mounts** - Guild achievement mounts
