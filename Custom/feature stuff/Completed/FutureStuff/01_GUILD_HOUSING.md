# Guild Housing System

**Priority:** S1 - Critical  
**Effort:** High (4-6 weeks)  
**Impact:** Very High  
**AzerothCore Module:** `mod-guildhouse` (base, needs extension)

---

## Overview

A Guild Housing system provides guilds with a private instanced space that can be customized, upgraded, and used for social activities. This is one of the most requested features on private servers and creates strong guild retention.

---

## Why It Fits DarkChaos-255

### Synergies with Existing Systems

| Existing System | Integration Point |
|-----------------|-------------------|
| **Seasonal System** | Season-exclusive decorations, guild achievements |
| **Item Upgrade Tokens** | Use tokens to purchase guild upgrades |
| **Mythic+ System** | Guild leaderboards displayed in hall |
| **HLBG** | PvP trophies displayed in guild hall |
| **Prestige System** | Guild prestige levels unlock features |

### Player Retention Value
- Guilds invest time/resources → less likely to quit
- Social hub keeps players logged in
- Guild competition drives engagement
- Customization satisfies collectors

---

## Feature Highlights

### Core Features
1. **Guild Hall Instance**
   - Private phased zone for guild members
   - Teleport via guild perk or item
   - Base map: Karazhan lower levels OR custom instanced area

2. **Vendors & Services**
   - Guild Bank access
   - Repair vendor (reduced costs)
   - Transmog vendor
   - Profession trainers (unlockable)
   - Portal NPCs to major cities

3. **Upgradeable Rooms**
   - Trophy Room (displays guild achievements)
   - Armory (displays top guild gear)
   - War Room (guild calendar, raid planning)
   - Garden/Stable (vanity pets, mounts)
   - Vault (extra guild bank tabs)

4. **Guild Perks**
   - +XP bonus for members
   - +reputation gain
   - Reduced repair costs
   - Summon to guild hall
   - Mass resurrection

### Advanced Features (Phase 2)
- Guild Arena (internal dueling)
- Training Dummies with DPS meters
- Guild quests (daily/weekly)
- Inter-guild visiting (with permission)
- Seasonal decorations

---

## Technical Implementation

### Database Schema

```sql
-- Guild house configuration
CREATE TABLE dc_guild_house (
    guild_id INT UNSIGNED PRIMARY KEY,
    house_level TINYINT DEFAULT 1,
    house_style TINYINT DEFAULT 1,  -- Visual theme
    currency_balance INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_upgraded TIMESTAMP NULL
);

-- Purchased upgrades
CREATE TABLE dc_guild_house_upgrades (
    guild_id INT UNSIGNED,
    upgrade_id INT UNSIGNED,
    purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (guild_id, upgrade_id)
);

-- Available upgrades
CREATE TABLE dc_guild_house_upgrade_defs (
    upgrade_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    upgrade_name VARCHAR(100),
    upgrade_description TEXT,
    category ENUM('vendor', 'room', 'perk', 'cosmetic'),
    required_level TINYINT DEFAULT 1,
    cost_gold INT DEFAULT 0,
    cost_tokens INT DEFAULT 0,
    prereq_upgrade_id INT UNSIGNED NULL
);

-- Decorations/trophies
CREATE TABLE dc_guild_house_decorations (
    guild_id INT UNSIGNED,
    decoration_id INT UNSIGNED,
    slot_id INT UNSIGNED,  -- Position in house
    placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (guild_id, slot_id)
);
```

### Server-Side (C++)

```cpp
class GuildHouseManager {
public:
    // Instance management
    void CreateGuildHouse(uint32 guildId);
    void TeleportToGuildHouse(Player* player);
    void LeaveGuildHouse(Player* player);
    
    // Upgrades
    bool PurchaseUpgrade(uint32 guildId, uint32 upgradeId);
    std::vector<Upgrade> GetAvailableUpgrades(uint32 guildId);
    bool HasUpgrade(uint32 guildId, uint32 upgradeId);
    
    // NPC spawning
    void SpawnNPCsForGuild(uint32 guildId);
    void UpdateNPCVisibility(uint32 guildId);
    
    // Perks
    void ApplyGuildPerks(Player* player);
    float GetXPBonus(uint32 guildId);
    float GetRepBonus(uint32 guildId);
};
```

### Client Addon (Lua)

```lua
-- Guild House UI
local GuildHouseFrame = CreateFrame("Frame", "DCGuildHouse", UIParent)

function GuildHouseFrame:ShowUpgradeMenu()
    -- Display purchasable upgrades
    -- Show costs in gold and tokens
    -- Preview button for cosmetics
end

function GuildHouseFrame:ShowDecorationPlacer()
    -- Drag-and-drop decoration placement
    -- Grid-based positioning
end

-- Slash command
SLASH_GUILDHOUSE1 = "/guildhouse"
SLASH_GUILDHOUSE2 = "/gh"
SlashCmdList["GUILDHOUSE"] = function()
    -- Request teleport or open menu
end
```

---

## Integration with DarkChaos Systems

### Seasonal Integration
```cpp
// On season end, award guild decorations
void OnSeasonEnd(uint32 seasonId) {
    auto topGuilds = GetTopGuildsByScore(seasonId, 10);
    for (auto& guild : topGuilds) {
        uint32 trophyId = GetSeasonTrophy(seasonId, guild.rank);
        AwardGuildDecoration(guild.id, trophyId);
    }
}
```

### Token Integration
```cpp
// Use upgrade tokens for guild upgrades
bool PurchaseUpgrade(uint32 guildId, uint32 upgradeId, Player* purchaser) {
    auto upgrade = GetUpgradeDef(upgradeId);
    
    if (upgrade.cost_tokens > 0) {
        if (!DeductTokens(purchaser, upgrade.cost_tokens)) {
            return false;
        }
    }
    
    if (upgrade.cost_gold > 0) {
        if (!DeductGuildBankGold(guildId, upgrade.cost_gold)) {
            return false;
        }
    }
    
    return ApplyUpgrade(guildId, upgradeId);
}
```

---

## Implementation Phases

### Phase 1 (Week 1-2): Base System
- [ ] Set up guild house instance map
- [ ] Implement teleportation system
- [ ] Create database schema
- [ ] Basic NPC spawning (bank, repair)

### Phase 2 (Week 3-4): Upgrades
- [ ] Implement upgrade purchase system
- [ ] Add vendor upgrades
- [ ] Add room unlocks
- [ ] Create upgrade UI addon

### Phase 3 (Week 5-6): Polish
- [ ] Guild perks implementation
- [ ] Decoration system
- [ ] Seasonal integration
- [ ] Trophy displays

---

## Existing Resources

### AzerothCore Module
- **mod-guildhouse**: https://github.com/azerothcore/mod-guildhouse
- Provides basic framework
- Needs extension for decoration system
- Needs seasonal integration

### Reference Implementations
- Retail WoW Garrison (WoD)
- FFXIV Housing System
- GW2 Guild Halls

---

## Estimated Costs

| Resource | Estimate |
|----------|----------|
| Development Time | 4-6 weeks |
| Database Size | ~100KB per guild |
| Instance Memory | ~5MB per active instance |
| Map/DBC Changes | Minimal (use existing maps) |

---

## Success Metrics

- Guild retention rate increase
- Average login time per guild member
- Number of guilds with houses
- Upgrade purchase frequency
- Player survey satisfaction

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Instance lag | Limit decorations, unload inactive |
| Database bloat | Cleanup inactive guilds |
| Exploit abuse | Rate limit purchases, audit logs |
| Complexity creep | Start minimal, expand based on feedback |

---

**Recommendation:** Start with `mod-guildhouse` base and extend incrementally. Focus on core functionality first (teleport, bank, vendors) before adding cosmetic features.
