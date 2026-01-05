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
- **Location:** GM Island (Map 1, Kalimdor)
    - Hardcoded in `src/mod_guildhouse.cpp` (Case 100: 16222.9, 16267.8, 13.1)
    - Uses phasing (`player->SetPhaseMask`) to separate instances
- Teleport to private guild instance
- Purchase NPCs: Bank, Vendor, Trainer, Auctioneer
- Cost in gold (Configurable in `guildhouse.conf`)

---

## Deep Dive: Technical Evaluation & Scalability

### 1. Phasing vs. Instancing
The current module uses **Phasing** (PhaseMasks) on a shared map (Map 1).

*   **Phasing Limits:** AzerothCore uses a `uint32` (or `SMALLINT UNSIGNED`) for PhaseMasks, theoretically allowing ~65,000 distinct phases. This effectively limits us to ~65k guild houses, which is sufficient for scale.
*   **Performance Risk:** Phasing executes on a *shared grid*. If 500 players are in their own guild houses (phases) but physically located at the same X/Y/Z coordinates on GM Island, the server still loads all 500 players into the same grid cells and iterates over them for visibility checks. This **will** cause exponential CPU load increase with population.

### 2. Proposed Solution: Map Instancing
To ensure a "Premium" lag-free experience, we should move from **Phasing** to **Instancing**.
*   **Concept:** Create a new custom Map ID (e.g., `900`) that is flagged as an `Instance`.
*   **Mechanism:** When a player enters, `sMapMgr->CreateInstance(900)` generates a completely isolated copy of the map.
*   **Benefit:** Zero CPU overhead from other guilds.
*   **Implementation:** Requires changing the module to manage `InstanceId` instead of `PhaseMask`.

### 3. Database Standardization
We will enforce the `dc_` prefix convention to avoid conflicts and maintain cleanliness.
*   `guild_house` -> `dc_guild_house`
*   `guild_house_spawns` -> `dc_guild_house_spawns`
*   All C++ queries in `mod_guildhouse.cpp` must be updated to reflect these changes.

### 4. Known Module Issues (GitHub Analysis)
*   **NPC Spawning:** Reports of NPCs not spawning correctly or missing data.
*   **Exploits:** GMs/Players using generic teleport commands to enter others' instances. *Instancing solves this naturally.*
*   **Restart Persistence:** Issues with phase masks not persisting (rare).

---

## Map Proposals (Alternatives to GM Island)

To provide a unique and premium feel, we can clone an existing scenic map ID to a new Instance Map ID (e.g., 900+).

### 1. The Eye of Eternity (Map 527)
*   **Description:** Malygos's raid instance. A massive floating platform surrounded by a magical/celestial void.
*   **Why:** "Premium" aesthetic, contained space, perfect for a guild "Hall of Fame".
*   **Vibe:** Cosmic, Magical, Epic.

### 2. Designer Island (Map 451)
*   **Description:** "Development Land" used by Blizzard. A completely flat, empty grid/grassland.
*   **Why:** The ultimate "Sandbox". Perfect for players who want to build everything from scratch using the `.go` system.
*   **Vibe:** Blank Canvas, Builder's Paradise.

### 3. The Emerald Dream (Map 169)
*   **Description:** Requires a client patch or specific MPQ, but contains "Verdant Fields" - huge green open spaces.
*   **Why:** Extremely unique, magical atmosphere.
*   **Note:** Might require client-side patch distribution to ensure stability.

### 4. Nagrand Floating Island (Custom Clone)
*   **Description:** Clone the Nagrand map (530) but spawn players on one of the large floating islands.
*   **Why:** Iconic view, natural isolation (falling off = teleport back up).
*   **Implementation:** Use Map 530 scenery but restrict movement to the island.

---

## Feature Expansion (Phase 3 Content)

### 1. Guild Currency: "Construction Tokens"
*   **Concept:** A custom Item (ID: 90000+, e.g., "Guild Construction Token") used to purchase housing upgrades and furniture.
*   **Why Item-based?**
    *   **Storage:** Can be stored in the **Guild Bank** (Tab 1) for shared access.
    *   **Simplicity:** No core hacking required for complex "Guild Money" databases. Vendors use standard `ItemExtendedCost`.
    *   **Tradability:** Can be traded between members or donated to the Guild Master.

### 2. New NPC Vendors
*   **The "Mythic+ Room"**:
    *   **Keystone Master (NPC):** Sells Keystones, upgrades keys, and offers weekly M+ chests.
    *   **Dungeon Porter:** Teleports group to M+ dungeon entrances.
    *   **Valor Vendor:** Sells M+ gearing rewards.
*   **Seasonal/Event Vendors**:
    *   **Rotating Trader:** Changes stock every month (Darkmoon Faire style).
    *   **Holiday Ambassadors:** Spawns during events (Winter Veil, Hallow's End) to sell unique decorations (Snowman, Pumpkins).
*   **Profession Center:**
    *   **Omni-Crafter:** A universal trade goods vendor (Vellums, Threads, Vials).
    *   **Repair Bot:** Standard repair/reagent vendor.

### 3. Configuration Upgrade
*   Integration of `mod-guildhouse` settings into `darkchaos-custom.conf.dist` for unified management.


### 1. Joining a House
*   **Command:** Any player can type `.gh tele` or `.guildhouse teleport`.
*   **Logic:** Server checks `player->GetGuildId()`.
*   **Routing:** It finds the active **Instance ID** linked to *that specific guild*.
    *   Guild A -> Instance 101
    *   Guild B -> Instance 102
*   **Result:** You land in your guild's private dimension.

### 2. Visibility (Guild-Only)
*   **Who do you see?** Only members of **YOUR** guild (and invited guests).
*   **Privacy:** Guild A members CANNOT see Guild B members, because they are in completely different Instance IDs (World 101 vs World 102), even if they are using the same "Map ID".
*   **Mechanic:** It works exactly like a Raid Instance (e.g., ICC). Thousands of guilds run ICC simultaneously, but they never see each other.

### 3. Grouping & Raid Logic
*   **No Group Needed:** You do **NOT** need to be in a party or raid group to enter or see guildmates.
*   **Seamless:** It functions like a private capital city. You can walk in, chat, trade, and duel freely.

### 1. Custom Location Integration
Instead of the generic "GM Island", utilizing DC's custom maps:
- **Giant Isles Phasing:** Phase a highly scenic part of the Giant Isles as the housing zone.
- **Azshara Crater:** Use the unused areas of the Azshara Crater map.

### 2. Collection System "Trophy Room"
Leverage the **DC-Collection** addon:
- Automatically display distinct visual trophies for completed item sets.
- "Armor Stands" that load the display ID of saved Wardrobe Outfits.

### 3. PlayerBot Guards
Utilize the **Playerbots** system:
- Assign your own alts (or guild members' alts) as NPC guards patrolling the house.
- " Barracks" upgrade to station offline guild members as defenders.

### 4. Progression Integration
- **Prestige System:** Unlock specific housing tiers or architectural styles based on Character Prestige.
- **WOTLK+:** Housing vendors selling custom WOTLK+ consumables or patterns.

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

