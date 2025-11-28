# Reputation Overhaul System

**Priority:** B5 (Medium Priority)  
**Effort:** Medium (2 weeks)  
**Impact:** Medium  
**Base:** Core Reputation System + Custom Factions

---

## Overview

Custom factions for DarkChaos-255 content with meaningful rewards at each reputation level. Each custom zone and system gets its own faction with unique progression and rewards.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Custom Zones** | Zone-specific factions |
| **Mythic+** | M+ faction for rewards |
| **HLBG** | PvP faction |
| **Seasonal** | Season-specific rep bonuses |
| **Item Upgrades** | Rep-gated upgrade recipes |

### Benefits
- Structured progression path
- Zone-relevant rewards
- Encourages content exploration
- Faction-specific vendors
- Account-wide benefits (optional)

---

## Custom Factions

### Zone Factions
| Faction | Zone | Level Range |
|---------|------|-------------|
| Azshara Reclamation | Azshara Crater | 1-80 |
| Hyjal Guardians | Mount Hyjal | 80-130 |
| Stratholme Vanguard | Stratholme Outside | 130-160 |
| Jadeforest Explorers | Jadeforest | 160-200 |
| Nexus of Eternity | Endgame Zone | 200-255 |

### Activity Factions
| Faction | Activity |
|---------|----------|
| Mythic Challengers | M+ Dungeon completions |
| Hinterland Champions | HLBG participation |
| Upgrade Masters | Item upgrade activities |
| Season Elite | Seasonal achievements |

---

## Reputation Levels

| Level | Points | Perks |
|-------|--------|-------|
| Hated | -42000 | N/A |
| Hostile | -6000 | N/A |
| Unfriendly | -3000 | N/A |
| Neutral | 0 | Basic vendor access |
| Friendly | 3000 | Recipes, basic gear |
| Honored | 9000 | Blue gear, tabard |
| Revered | 21000 | Epic gear, patterns |
| Exalted | 42000 | Mount, title, BiS items |

---

## Implementation

### Database Schema
```sql
-- Custom faction definitions
CREATE TABLE dc_factions (
    faction_id INT UNSIGNED PRIMARY KEY,
    faction_name VARCHAR(100) NOT NULL,
    description TEXT,
    faction_type ENUM('zone', 'activity', 'seasonal') NOT NULL,
    zone_id INT UNSIGNED DEFAULT 0,
    tabard_item INT UNSIGNED DEFAULT 0,
    mount_item INT UNSIGNED DEFAULT 0,
    title_id INT UNSIGNED DEFAULT 0
);

-- Reputation gain sources
CREATE TABLE dc_faction_sources (
    source_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    faction_id INT UNSIGNED NOT NULL,
    source_type ENUM('kill', 'quest', 'dungeon', 'pvp', 'item', 'weekly') NOT NULL,
    source_entry INT UNSIGNED DEFAULT 0,
    rep_gain INT NOT NULL,
    max_rep_level ENUM('friendly', 'honored', 'revered', 'exalted') DEFAULT 'exalted',
    FOREIGN KEY (faction_id) REFERENCES dc_factions(faction_id)
);

-- Faction vendors
CREATE TABLE dc_faction_vendors (
    vendor_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    faction_id INT UNSIGNED NOT NULL,
    item_entry INT UNSIGNED NOT NULL,
    item_cost INT UNSIGNED DEFAULT 0,  -- Gold cost in copper
    token_cost INT UNSIGNED DEFAULT 0, -- Token cost
    rep_required ENUM('neutral', 'friendly', 'honored', 'revered', 'exalted') NOT NULL,
    stock_count INT DEFAULT -1,
    FOREIGN KEY (faction_id) REFERENCES dc_factions(faction_id)
);

-- Sample factions
INSERT INTO dc_factions VALUES
(800001, 'Mythic Challengers', 'Masters of keystone dungeons', 'activity', 0, 800101, 800201, 800),
(800002, 'Hinterland Champions', 'Veterans of the Hinterland battleground', 'activity', 0, 800102, 800202, 801),
(800003, 'Azshara Reclamation', 'Defenders of Azshara Crater', 'zone', 16, 800103, 800203, 802);

-- Sample rep gains
INSERT INTO dc_faction_sources (faction_id, source_type, source_entry, rep_gain) VALUES
(800001, 'dungeon', 0, 75),      -- Any M+ completion
(800001, 'weekly', 0, 500),      -- Weekly M+ quest
(800002, 'pvp', 0, 25),          -- HLBG kill
(800002, 'pvp', 1, 100),         -- HLBG win
(800003, 'kill', 0, 5),          -- Azshara creature kill
(800003, 'quest', 0, 250);       -- Azshara quest completion
```

### Reputation Manager (C++)
```cpp
class DCReputationManager
{
public:
    static DCReputationManager* instance();
    
    // Rep modifications
    void ModifyReputation(Player* player, uint32 factionId, int32 amount);
    void SetReputation(Player* player, uint32 factionId, int32 standing);
    
    // Queries
    int32 GetReputation(Player* player, uint32 factionId) const;
    ReputationRank GetReputationRank(Player* player, uint32 factionId) const;
    bool HasReputationRank(Player* player, uint32 factionId, ReputationRank rank) const;
    
    // Vendor checks
    bool CanBuyFromVendor(Player* player, uint32 factionId, ReputationRank required) const;
    
    // Source tracking
    void OnCreatureKill(Player* player, Creature* victim);
    void OnQuestComplete(Player* player, Quest const* quest);
    void OnDungeonComplete(Player* player, uint32 mapId, uint32 difficulty);
    void OnPvPAction(Player* player, uint32 actionType);
    
private:
    std::unordered_map<uint32, DCFaction> _factions;
    
    void LoadFactions();
    void LoadFactionSources();
    void LoadFactionVendors();
    int32 GetRepGain(uint32 factionId, FactionSourceType type, uint32 entry) const;
};

#define sDCRepMgr DCReputationManager::instance()
```

---

## Faction Rewards

### Mythic Challengers

| Rep Level | Rewards |
|-----------|---------|
| Friendly | Basic M+ consumables |
| Honored | M+ Tabard, Blue Keystone Bag |
| Revered | Epic M+ Gear, Keystone Recipes |
| Exalted | Mythic Challenger Mount, Title |

### Hinterland Champions

| Rep Level | Rewards |
|-----------|---------|
| Friendly | PvP consumables |
| Honored | HLBG Tabard, Honor gear |
| Revered | Epic PvP gear, Vanity items |
| Exalted | War Charger Mount, "the Champion" |

### Zone Factions (Example: Azshara)

| Rep Level | Rewards |
|-----------|---------|
| Friendly | Zone-specific consumables |
| Honored | Tabard, Blue zone gear |
| Revered | Epic zone gear, Recipes |
| Exalted | Zone Mount, Title, Transmog Set |

---

## Commands

### Player Commands
```
.rep list             - Show all custom factions
.rep <faction>        - Show standing with faction
.rep progress         - Show all rep progress
```

### GM Commands
```
.rep add <f> <p> <amt>   - Add rep to player
.rep set <f> <p> <level> - Set rep level
.rep reset <f> <p>       - Reset faction rep
.rep reload              - Reload faction data
```

---

## Vendor NPCs

```sql
-- Create faction vendors
INSERT INTO creature_template (entry, name, subname, npcflag) VALUES
(800501, 'Keystone Quartermaster', 'Mythic Challengers', 128),
(800502, 'Hinterland Supplier', 'Hinterland Champions', 128),
(800503, 'Azshara Provisioner', 'Azshara Reclamation', 128);
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| DCReputationManager | 3 days |
| Faction definitions | 1 day |
| Rep gain hooks | 2 days |
| Vendor NPCs | 1 day |
| Item rewards | 2 days |
| Tabards & mounts | 1 day |
| Testing | 2 days |
| **Total** | **~2 weeks** |

---

## Future Enhancements

1. **Paragon Reputation** - Beyond Exalted rewards
2. **Account-Wide Rep** - Share rep across characters
3. **Rep Tokens** - Tradeable rep items
4. **Faction Wars** - Opposing factions
5. **Diplomatic Missions** - Daily rep quests
