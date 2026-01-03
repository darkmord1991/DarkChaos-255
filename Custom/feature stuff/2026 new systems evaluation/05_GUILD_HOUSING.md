# Housing System (Guild + Player)

**Priority:** A1 (High)  
**Effort:** High (6-8 weeks)  
**Impact:** Very High  
**Client Required:** No (AIO addon for UI)  
**Available Module:** `mod-guildhouse` (base to extend)

---

## Overview

Private instanced areas for **guilds** and individual **players/accounts** with NPCs, decorations, and player-placeable objects. Builds community and provides gold sink.

---

## Two Housing Types

| Type | Scope | Instance | Scalability |
|------|-------|----------|-------------|
| **Guild Housing** | Per guild | 1 instance per guild | ~50-200 guilds |
| **Account Housing** | Per account | 1 instance per account | ~100-500 accounts |

> [!TIP]
> **Account-Wide Player Housing** reduces effort significantly:
> - 1 house per account (not per character)
> - Shared across all characters on account
> - Fewer instances to manage
> - All characters contribute to same house

---

## Available Module: mod-guildhouse

**GitHub:** [azerothcore/mod-guildhouse](https://github.com/azerothcore/mod-guildhouse)  
**Stars:** 35 | **Forks:** 55

### Module Features (Out of Box)
- Teleport to private guild instance
- Purchase NPCs: Bank, Vendor, Trainer, Auctioneer
- Guild-only access
- Multiple location options
- Cost in gold

---

## Player-Placeable GameObjects (GO Placement UI)

### Concept: ".go move" Style Decoration

Allow players to place and move decorative GameObjects in their housing instance via AIO addon UI.

### How It Works

```
PLAYER GO PLACEMENT FLOW
├── Player enters house instance
├── Opens "Decoration Mode" via addon button
├── Selects GO from unlocked catalog (furniture, trophies, etc.)
├── GO spawns at player position (ghosted/preview)
├── Player uses arrow keys / addon sliders to move/rotate
├── Confirms placement → Server spawns permanent GO
└── GO saved to DB, persists across sessions
```

### Technical Implementation

```cpp
// Player housing GO storage
struct HousingGameObject
{
    uint32 goEntry;
    float x, y, z, o;
    uint32 scale; // 0-200 (100 = normal)
};

class PlayerHousingMgr
{
public:
    void PlaceGameObject(Player* player, uint32 goEntry, float x, float y, float z, float o);
    void MoveGameObject(Player* player, uint32 goGuid, float dx, float dy, float dz, float dO);
    void RemoveGameObject(Player* player, uint32 goGuid);
    void LoadHousingGOs(uint32 accountId, Map* housingMap);
    
    bool CanPlaceMore(uint32 accountId); // Check GO limit
    bool IsValidGOEntry(uint32 goEntry); // Check if GO is unlocked
    
private:
    std::map<uint32, std::vector<HousingGameObject>> _accountGOs; // accountId -> GOs
};
```

```sql
-- Player housing GO storage
CREATE TABLE `dc_housing_gameobjects` (
    `id` INT UNSIGNED AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `go_entry` INT UNSIGNED NOT NULL,
    `pos_x` FLOAT,
    `pos_y` FLOAT,
    `pos_z` FLOAT,
    `orientation` FLOAT,
    `scale` INT UNSIGNED DEFAULT 100,
    `placed_time` DATETIME,
    PRIMARY KEY (`id`),
    INDEX (`account_id`)
);

-- Unlockable GO catalog
CREATE TABLE `dc_housing_go_catalog` (
    `go_entry` INT UNSIGNED NOT NULL,
    `display_name` VARCHAR(100),
    `category` ENUM('furniture', 'trophy', 'seasonal', 'vendor', 'utility'),
    `unlock_type` ENUM('default', 'purchase', 'achievement', 'seasonal', 'battle_pass'),
    `unlock_param` INT UNSIGNED, -- Gold cost, achievement ID, BP tier, etc.
    `max_per_house` INT UNSIGNED DEFAULT 0, -- 0 = unlimited
    PRIMARY KEY (`go_entry`)
);
```

### AIO Addon UI: Decoration Mode

```lua
-- Decoration Mode Frame
DecorationFrame = CreateFrame("Frame", "DCHousingDecor", UIParent)
DecorationFrame:SetSize(300, 400)

-- GO Catalog (scrollable list)
-- Categories: Furniture, Trophies, Seasonal, Utility
-- Each item shows: Icon, Name, Unlock status

-- Placement Controls
-- [Rotate Left] [Rotate Right]
-- X: [<] [slider] [>]
-- Y: [<] [slider] [>]
-- Z: [<] [slider] [>]
-- [Confirm] [Cancel]

-- Preview: Ghosted GO follows adjustments in real-time
```

### GO Limits (Per Account Housing)

| Housing Tier | Max GOs | Unlock Cost |
|--------------|---------|-------------|
| Basic | 10 | Free |
| Standard | 25 | 10,000g |
| Advanced | 50 | 50,000g |
| Premium | 100 | 150,000g |
| Legendary | 200 | 500,000g |

---

## Scalability: Hundreds of Houses

### Challenge

If 500 accounts have houses, that's 500 potential instances + GO storage.

### Solutions

| Approach | Description | Pros | Cons |
|----------|-------------|------|------|
| **On-Demand Instances** | Only create instance when owner online | Low memory | Loading time |
| **Shared Template Map** | All houses use same map, different instance IDs | Simple | Less unique |
| **Phased Single Map** | One map, phased per account | No new instances | Phase complexity |
| **Lazy Loading** | Load GOs only when entering | Memory efficient | Initial delay |

### Recommended: On-Demand + Lazy Loading

```cpp
// Only create instance when player tries to enter
Map* PlayerHousingMgr::GetOrCreateHouse(uint32 accountId)
{
    if (_activeInstances.find(accountId) != _activeInstances.end())
        return _activeInstances[accountId];
    
    // Create new instance of housing map
    Map* house = sMapMgr->CreateHousingInstance(HOUSING_MAP_ID, accountId);
    
    // Lazy load GOs from DB
    LoadHousingGOs(accountId, house);
    
    _activeInstances[accountId] = house;
    
    // Schedule cleanup after 30 min of inactivity
    ScheduleInstanceCleanup(accountId, 30 * MINUTE);
    
    return house;
}
```

### Instance Cleanup

```cpp
// Clean up inactive housing instances
void PlayerHousingMgr::CleanupInactiveHouses()
{
    for (auto& [accountId, lastActivity] : _activityTracker)
    {
        if (GetMSTimeDiffToNow(lastActivity) > 30 * MINUTE * IN_MILLISECONDS)
        {
            // Save GO state to DB
            SaveHousingGOs(accountId);
            
            // Destroy instance
            sMapMgr->DestroyInstance(_activeInstances[accountId]);
            _activeInstances.erase(accountId);
        }
    }
}
```

---

## Housing Features Summary

### Guild Housing (mod-guildhouse base)

| Feature | Description |
|---------|-------------|
| Location Options | Karazhan, Hyjal, Black Temple, Dalaran, etc. |
| NPCs | Bank, Vendor, Trainer, Auctioneer, Transmog |
| Tiers | Basic → Legendary (gold upgrades) |
| Seasonal | Holiday decorations from Battle Pass |
| Trophies | Achievement-based display items |

### Account Player Housing (New)

| Feature | Description |
|---------|-------------|
| 1 House per Account | Shared across all characters |
| GO Placement | Player-controlled decoration via UI |
| Catalog Unlocks | Furniture via gold, achievements, BP |
| Visitor Mode | Invite friends to see your house |
| Storage | Personal bank chest (upgrade slot count) |

---

## Implementation Phases

### Phase 1 (Week 1-2): Guild Housing Base
- Integrate mod-guildhouse
- Configure locations
- Set up tier upgrades

### Phase 2 (Week 3-4): Account Housing
- Create housing map template
- Instance management system
- Basic teleport/access

### Phase 3 (Week 5-6): GO Placement System
- GO catalog database
- Placement/move server logic
- AIO addon decoration UI

### Phase 4 (Week 7-8): Polish
- Unlock integrations (BP, achievements)
- Visitor mode
- Seasonal decorations
- Performance optimization

---

*Expanded housing spec with player housing and GO placement - January 2026*

