# Pet Collection System

**Priority:** B8 (Medium Priority)  
**Effort:** Medium (2 weeks)  
**Impact:** Low-Medium  
**Base:** Custom AIO Addon + Server Database

---

## Overview

A companion pet collection system (NOT pet battles) that tracks collected pets, provides a pet journal UI, enables "summon random pet," and adds pet-related achievements. A lighter-weight collection feature than full pet battles.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Achievements** | Pet collection achievements |
| **Seasonal** | Season-exclusive pets |
| **Mythic+** | M+ reward pets |
| **Reputation** | Faction-specific pets |
| **Events** | Event reward pets |

### Benefits
- Collection endgame content
- Low complexity (no battles)
- Complements mount collection
- Vanity/social feature
- Achievement integration

---

## Features

### 1. **Pet Journal UI**
- Grid view of all pets
- Collected vs uncollected display
- Filter by source
- Search by name
- Pet preview 3D model

### 2. **Account-Wide Collection**
- Pets shared across characters
- Some pets character-bound
- One database for all

### 3. **Summon Random Pet**
- Auto-summon random pet
- Favorite pets list
- Rotate pet on rest
- Smart selection

### 4. **Pet Sources**
- Where to obtain each pet
- Drop rates displayed
- Quest chains indicated
- Vendor prices shown

---

## Implementation

### Database Schema
```sql
-- Account pet collection
CREATE TABLE dc_pet_collection (
    account_id INT UNSIGNED NOT NULL,
    pet_entry INT UNSIGNED NOT NULL,
    obtained_by INT UNSIGNED NOT NULL,  -- Character GUID
    obtained_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pet_name VARCHAR(50) DEFAULT NULL,
    is_favorite BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (account_id, pet_entry)
);

-- Pet definitions
CREATE TABLE dc_pets (
    pet_entry INT UNSIGNED PRIMARY KEY,
    pet_name VARCHAR(100) NOT NULL,
    pet_spell_id INT UNSIGNED NOT NULL,
    pet_source ENUM('drop', 'vendor', 'achievement', 'quest', 'profession', 'event', 'promotion') NOT NULL,
    source_details TEXT,  -- JSON
    faction_required ENUM('alliance', 'horde', 'both') DEFAULT 'both',
    display_id INT UNSIGNED NOT NULL,
    icon_path VARCHAR(255) DEFAULT '',
    rarity ENUM('common', 'uncommon', 'rare', 'epic', 'legendary') DEFAULT 'common'
);

-- Pet achievements
CREATE TABLE dc_pet_achievements (
    achievement_id INT UNSIGNED PRIMARY KEY,
    pet_count INT UNSIGNED NOT NULL,
    reward_pet_id INT UNSIGNED DEFAULT 0,
    reward_title_id INT UNSIGNED DEFAULT 0,
    achievement_name VARCHAR(100) NOT NULL
);

-- Sample pets
INSERT INTO dc_pets (pet_entry, pet_name, pet_spell_id, pet_source, source_details, rarity) VALUES
(10000, 'Mini Mythic Drake', 800100, 'achievement', '{"achievement": "M+10 Complete"}', 'epic'),
(10001, 'Hinterland Hatchling', 800101, 'achievement', '{"achievement": "100 HLBG Wins"}', 'rare'),
(10002, 'Season 1 Companion', 800102, 'event', '{"season": 1}', 'epic'),
(10003, 'Upgrade Sprite', 800103, 'achievement', '{"achievement": "Upgrade 100 items"}', 'uncommon'),
(10004, 'Prestige Phantom', 800104, 'achievement', '{"achievement": "Reach Prestige 5"}', 'legendary');

-- Sample achievements
INSERT INTO dc_pet_achievements VALUES
(9101, 10, 0, 610, 'Can I Keep Him?'),
(9102, 25, 0, 611, 'Pet Collector'),
(9103, 50, 10050, 612, 'Plenty of Pets'),
(9104, 100, 10051, 613, 'That\'s a Lot of Pets'),
(9105, 150, 10052, 614, 'Pet Hoarder');
```

### Pet Manager (Server)
```cpp
class PetCollectionManager
{
public:
    static PetCollectionManager* instance();
    
    // Collection
    void LoadAccountPets(uint32 accountId);
    bool HasPet(uint32 accountId, uint32 petEntry) const;
    void AddPet(Player* player, uint32 petEntry);
    std::vector<uint32> GetCollectedPets(uint32 accountId) const;
    uint32 GetPetCount(uint32 accountId) const;
    
    // Random pet
    uint32 GetRandomPet(uint32 accountId) const;
    uint32 GetRandomFavorite(uint32 accountId) const;
    
    // Naming
    void RenamePet(uint32 accountId, uint32 petEntry, const std::string& name);
    std::string GetPetName(uint32 accountId, uint32 petEntry) const;
    
    // Favorites
    void SetFavorite(uint32 accountId, uint32 petEntry, bool favorite);
    std::vector<uint32> GetFavorites(uint32 accountId) const;
    
    // Achievements
    void CheckPetAchievements(Player* player);
    
private:
    std::unordered_map<uint32, AccountPetData> _accountPets;
    std::unordered_map<uint32, PetDefinition> _pets;
    
    void LoadPetDefinitions();
};

#define sPetCollectionMgr PetCollectionManager::instance()
```

### AIO Addon (Client)
```lua
-- Pet Journal Frame
local PetJournal = CreateFrame("Frame", "DCPetJournal", UIParent)
PetJournal:SetSize(500, 400)
PetJournal:SetPoint("CENTER")

-- Pet list (scrollable grid)
PetJournal.grid = CreateScrollFrame(PetJournal, 6, 5)  -- 6 rows, 5 cols

-- Pet display (right panel)
PetJournal.preview = CreateModelFrame(PetJournal)
PetJournal.name = CreateFontString("GameFontNormalLarge")
PetJournal.source = CreateFontString("GameFontNormal")
PetJournal.summonButton = CreateButton("Summon")
PetJournal.favoriteButton = CreateButton("☆")
PetJournal.renameButton = CreateButton("Rename")

-- Filter buttons
PetJournal.filterAll = CreateButton("All")
PetJournal.filterCollected = CreateButton("Collected")
PetJournal.filterNotCollected = CreateButton("Missing")
PetJournal.filterRarity = CreateDropdown("Rarity")

-- Auto-summon option
local function OnZoneChange()
    if PetJournalSettings.autoSummon then
        local pet = GetRandomPet()
        SummonCompanion(pet)
    end
end
```

---

## Pet Categories

### By Source
| Source | Example Pets |
|--------|--------------|
| Drops | Whelpling pets, Rare spawns |
| Vendors | Faction pets, Trainer pets |
| Achievements | M+ pets, PvP pets |
| Quests | Quest reward pets |
| Professions | Engineering pets |
| Events | Holiday pets |
| DarkChaos Exclusive | Season pets, Mythic pets |

### By Rarity
| Rarity | Count | Color |
|--------|-------|-------|
| Common | 50+ | Gray |
| Uncommon | 30+ | Green |
| Rare | 20+ | Blue |
| Epic | 10+ | Purple |
| Legendary | 5 | Orange |

---

## Collection Achievements

| Achievement | Pets | Reward |
|-------------|------|--------|
| Can I Keep Him? | 10 | Title |
| Pet Collector | 25 | Title |
| Plenty of Pets | 50 | Exclusive Pet |
| That's a Lot of Pets | 100 | Exclusive Pet + Title |
| Pet Hoarder | 150 | Ultimate Pet + Title |

---

## Commands

### Player Commands
```
.pet list             - Show pet count
.pet summon <name>    - Summon specific pet
.pet random           - Summon random pet
.pet favorite <id>    - Toggle favorite
.pet rename <id> <n>  - Rename a pet
.pet journal          - Open pet journal
```

### GM Commands
```
.pet add <p> <id>     - Give pet to player
.pet remove <p> <id>  - Remove pet
.pet count <p>        - Show player's collection
.pet reload           - Reload pet database
```

---

## Integration with Existing Content

### DarkChaos-Exclusive Pets
| Pet | Source |
|-----|--------|
| Mini Mythic Drake | Complete M+10 |
| Hinterland Hatchling | 100 HLBG Wins |
| Season Companion | Season participation |
| Upgrade Sprite | Upgrade 100 items |
| Prestige Phantom | Reach Prestige 5 |
| Token Toad | Collect 10000 tokens |

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| PetCollectionManager | 2 days |
| Account-wide logic | 1 day |
| Random pet system | 4 hours |
| AIO Journal addon | 3 days |
| Pet definitions | 1 day |
| Achievements | 1 day |
| Testing | 2 days |
| **Total** | **~2 weeks** |

---

## Future Enhancements

1. **Pet Battles Lite** - Simple rock-paper-scissors battles
2. **Pet Leveling** - Pets gain XP and grow
3. **Pet Transmog** - Change pet appearance
4. **Pet Abilities** - Small buffs from certain pets
5. **Pet Parade** - Summon multiple pets
