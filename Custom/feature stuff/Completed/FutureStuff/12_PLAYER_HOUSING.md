# Player Housing System

**Priority:** S4 - Lower Priority  
**Effort:** Very High (6-8 weeks)  
**Impact:** High  
**Base:** Custom development (no existing module)

---

## Overview

A Player Housing system gives each player a personal instanced space they can decorate, invite friends to, and use as a hub for various activities. This is a major feature that provides long-term engagement through customization and social features.

---

## Why It Fits DarkChaos-255

### Engagement Value
- Personal progression beyond gear
- Gold sink for economy
- Social gathering space
- Trophy/achievement display
- Long-term player retention

### Funserver Appeal
- Showcase character achievements
- AFK in style
- Social status symbol
- Unique feature vs other servers

### Synergies
| System | Integration |
|--------|-------------|
| **Seasonal** | Seasonal housing decorations |
| **Achievements** | Display achievement trophies |
| **Collection** | Show off mounts/pets |
| **Guild Housing** | Extend to guild halls |

---

## Feature Highlights

### Core Features

1. **Personal Instance**
   - Private phased zone
   - Multiple house styles
   - Upgradeable size

2. **Decoration System**
   - Place furniture/objects
   - Move/rotate items
   - Color customization
   - Seasonal themes

3. **Functional Objects**
   - Bank access
   - Mailbox
   - Profession stations
   - Teleporter to house

4. **Social Features**
   - Invite players
   - Guest permissions
   - Party in house

5. **Trophy System**
   - Display raid boss kills
   - Achievement monuments
   - M+ leaderboard plaques

---

## Technical Implementation

### Database Schema

```sql
-- Player house instances
CREATE TABLE dc_player_houses (
    house_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED UNIQUE,
    house_style INT UNSIGNED DEFAULT 1,  -- 1=small, 2=medium, 3=large
    house_theme INT UNSIGNED DEFAULT 0,  -- Decoration theme
    phase_id INT UNSIGNED,  -- Unique phase for this house
    
    -- Location within house instance
    spawn_x FLOAT, spawn_y FLOAT, spawn_z FLOAT, spawn_o FLOAT,
    
    -- Upgrade levels
    storage_level INT DEFAULT 1,  -- Bank slots
    crafting_level INT DEFAULT 0, -- Profession stations
    garden_level INT DEFAULT 0,   -- Optional garden feature
    
    -- Stats
    visitors_total INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_visited TIMESTAMP NULL
);

-- Placed decorations
CREATE TABLE dc_house_decorations (
    decoration_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    house_id INT UNSIGNED,
    item_id INT UNSIGNED,  -- Decoration item entry
    gameobject_entry INT UNSIGNED,  -- GO to spawn
    
    -- Position relative to house origin
    pos_x FLOAT, pos_y FLOAT, pos_z FLOAT,
    rot_x FLOAT DEFAULT 0, rot_y FLOAT DEFAULT 0, rot_z FLOAT DEFAULT 0,
    scale FLOAT DEFAULT 1.0,
    
    placed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (house_id) REFERENCES dc_player_houses(house_id) ON DELETE CASCADE,
    INDEX idx_house (house_id)
);

-- Decoration items (catalog)
CREATE TABLE dc_decoration_catalog (
    item_id INT UNSIGNED PRIMARY KEY,
    decoration_name VARCHAR(100),
    gameobject_entry INT UNSIGNED,
    category ENUM('furniture', 'lighting', 'trophy', 'functional', 'seasonal', 'misc'),
    price_gold INT UNSIGNED DEFAULT 0,
    price_tokens INT UNSIGNED DEFAULT 0,
    required_achievement INT UNSIGNED NULL,
    is_seasonal TINYINT DEFAULT 0,
    season_id INT UNSIGNED NULL
);

-- House visitors log
CREATE TABLE dc_house_visitors (
    visit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    house_id INT UNSIGNED,
    visitor_guid INT UNSIGNED,
    visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (house_id) REFERENCES dc_player_houses(house_id)
);

-- Guest permissions
CREATE TABLE dc_house_permissions (
    house_id INT UNSIGNED,
    guest_guid INT UNSIGNED,
    can_visit TINYINT DEFAULT 1,
    can_use_bank TINYINT DEFAULT 0,
    can_use_crafting TINYINT DEFAULT 0,
    PRIMARY KEY (house_id, guest_guid)
);

-- House styles
CREATE TABLE dc_house_styles (
    style_id INT UNSIGNED PRIMARY KEY,
    style_name VARCHAR(50),
    map_id INT UNSIGNED,
    base_x FLOAT, base_y FLOAT, base_z FLOAT, base_o FLOAT,
    decoration_slots INT DEFAULT 20,
    price_gold INT UNSIGNED DEFAULT 0,
    required_achievement INT UNSIGNED NULL
);

-- Sample data
INSERT INTO dc_house_styles VALUES
(1, 'Cozy Cottage', 35, 0, 0, 0, 0, 20, 0, NULL),
(2, 'Stone Manor', 35, 50, 0, 0, 0, 40, 10000, NULL),
(3, 'Grand Estate', 35, 100, 0, 0, 0, 80, 100000, 500);

INSERT INTO dc_decoration_catalog (item_id, decoration_name, gameobject_entry, category, price_gold) VALUES
(80001, 'Wooden Chair', 180000, 'furniture', 100),
(80002, 'Oak Table', 180001, 'furniture', 500),
(80003, 'Candle Holder', 180002, 'lighting', 50),
(80004, 'Trophy: Lich King', 180010, 'trophy', 0),  -- Earned by killing LK
(80005, 'Mailbox', 180020, 'functional', 5000),
(80006, 'Forge', 180021, 'functional', 10000),
(80007, 'Winter Veil Tree', 180100, 'seasonal', 0);
```

### Eluna Implementation

```lua
-- Player Housing Manager
local Housing = {}
Housing.PHASE_BASE = 2000000
Housing.HOUSE_MAP = 35  -- Instance map ID (custom or repurposed)
Housing.ActiveHouses = {}  -- phase_id -> house_data

-- Get or create player house
function Housing.GetHouse(player)
    local guid = player:GetGUIDLow()
    
    local query = CharDBQuery([[
        SELECT house_id, house_style, phase_id, spawn_x, spawn_y, spawn_z, spawn_o
        FROM dc_player_houses WHERE player_guid = ]] .. guid)
    
    if query then
        return {
            id = query:GetUInt32(0),
            style = query:GetUInt32(1),
            phase = query:GetUInt32(2),
            x = query:GetFloat(3),
            y = query:GetFloat(4),
            z = query:GetFloat(5),
            o = query:GetFloat(6)
        }
    end
    
    return nil
end

-- Create house for new player
function Housing.CreateHouse(player, styleId)
    local guid = player:GetGUIDLow()
    
    -- Check if already has house
    if Housing.GetHouse(player) then
        player:SendBroadcastMessage("|cffff0000You already have a house!|r")
        return nil
    end
    
    -- Get style info
    local style = Housing.GetStyle(styleId)
    if not style then
        player:SendBroadcastMessage("|cffff0000Invalid house style.|r")
        return nil
    end
    
    -- Check gold
    if player:GetCoinage() < style.price * 10000 then
        player:SendBroadcastMessage("|cffff0000Not enough gold.|r")
        return nil
    end
    
    -- Generate unique phase
    local phaseId = Housing.PHASE_BASE + guid
    
    -- Create house record
    CharDBExecute(string.format([[
        INSERT INTO dc_player_houses 
        (player_guid, house_style, phase_id, spawn_x, spawn_y, spawn_z, spawn_o)
        VALUES (%d, %d, %d, %f, %f, %f, %f)
    ]], guid, styleId, phaseId, style.x, style.y, style.z, style.o))
    
    -- Deduct gold
    player:ModifyMoney(-style.price * 10000)
    
    player:SendBroadcastMessage("|cff00ff00House purchased! Use .house to teleport there.|r")
    
    return Housing.GetHouse(player)
end

-- Teleport player to their house
function Housing.GoHome(player)
    local house = Housing.GetHouse(player)
    if not house then
        player:SendBroadcastMessage("|cffff0000You don't have a house. Visit a housing vendor to purchase one.|r")
        return
    end
    
    -- Save return position
    player:SetData("house_return_map", player:GetMapId())
    player:SetData("house_return_x", player:GetX())
    player:SetData("house_return_y", player:GetY())
    player:SetData("house_return_z", player:GetZ())
    
    -- Set phase and teleport
    player:SetPhaseMask(house.phase, true)
    player:Teleport(Housing.HOUSE_MAP, house.x, house.y, house.z, house.o)
    
    -- Spawn decorations
    Housing.SpawnDecorations(player, house.id, house.phase)
    
    -- Update stats
    CharDBExecute("UPDATE dc_player_houses SET last_visited = NOW() WHERE house_id = " .. house.id)
end

-- Leave house and return to world
function Housing.LeaveHouse(player)
    local returnMap = player:GetData("house_return_map")
    if returnMap then
        player:SetPhaseMask(1, true)  -- Normal phase
        player:Teleport(returnMap,
            player:GetData("house_return_x"),
            player:GetData("house_return_y"),
            player:GetData("house_return_z"),
            0)
    else
        -- Default to mall or capital
        player:SetPhaseMask(1, true)
        player:Teleport(0, -8830, 634, 94, 0)  -- Default location
    end
end

-- Spawn house decorations
function Housing.SpawnDecorations(player, houseId, phaseId)
    local query = CharDBQuery([[
        SELECT d.gameobject_entry, d.pos_x, d.pos_y, d.pos_z, d.rot_z, d.scale
        FROM dc_house_decorations d
        WHERE d.house_id = ]] .. houseId)
    
    if not query then return end
    
    repeat
        local goEntry = query:GetUInt32(0)
        local x, y, z = query:GetFloat(1), query:GetFloat(2), query:GetFloat(3)
        local rot = query:GetFloat(4)
        local scale = query:GetFloat(5)
        
        -- Spawn gameobject in player's phase
        local go = PerformIngameSpawn(2, goEntry, Housing.HOUSE_MAP, phaseId, x, y, z, rot, false, 0)
        if go then
            go:SetScale(scale)
        end
    until not query:NextRow()
end

-- Place decoration
function Housing.PlaceDecoration(player, itemId)
    local house = Housing.GetHouse(player)
    if not house then
        player:SendBroadcastMessage("|cffff0000You don't have a house.|r")
        return false
    end
    
    -- Check if in house
    if player:GetMapId() ~= Housing.HOUSE_MAP then
        player:SendBroadcastMessage("|cffff0000You must be in your house to place decorations.|r")
        return false
    end
    
    -- Get decoration info
    local decor = Housing.GetDecorationInfo(itemId)
    if not decor then
        player:SendBroadcastMessage("|cffff0000Invalid decoration item.|r")
        return false
    end
    
    -- Check if has item
    if not player:HasItem(itemId, 1) then
        player:SendBroadcastMessage("|cffff0000You don't have that decoration.|r")
        return false
    end
    
    -- Place at player's current position
    local x, y, z = player:GetX(), player:GetY(), player:GetZ()
    local rot = player:GetO()
    
    CharDBExecute(string.format([[
        INSERT INTO dc_house_decorations 
        (house_id, item_id, gameobject_entry, pos_x, pos_y, pos_z, rot_z)
        VALUES (%d, %d, %d, %f, %f, %f, %f)
    ]], house.id, itemId, decor.goEntry, x, y, z, rot))
    
    -- Remove item from inventory
    player:RemoveItem(itemId, 1)
    
    -- Spawn immediately
    PerformIngameSpawn(2, decor.goEntry, Housing.HOUSE_MAP, house.phase, x, y, z, rot, false, 0)
    
    player:SendBroadcastMessage("|cff00ff00Decoration placed!|r")
    return true
end

-- Visit another player's house
function Housing.VisitHouse(visitor, ownerName)
    local owner = GetPlayerByName(ownerName)
    if not owner then
        visitor:SendBroadcastMessage("|cffff0000Player not found or offline.|r")
        return
    end
    
    local house = Housing.GetHouse(owner)
    if not house then
        visitor:SendBroadcastMessage("|cffff0000That player doesn't have a house.|r")
        return
    end
    
    -- Check permissions
    local canVisit = Housing.CheckPermission(house.id, visitor:GetGUIDLow(), "visit")
    if not canVisit then
        visitor:SendBroadcastMessage("|cffff0000You don't have permission to visit that house.|r")
        return
    end
    
    -- Save return position
    visitor:SetData("house_return_map", visitor:GetMapId())
    visitor:SetData("house_return_x", visitor:GetX())
    visitor:SetData("house_return_y", visitor:GetY())
    visitor:SetData("house_return_z", visitor:GetZ())
    
    -- Teleport to house
    visitor:SetPhaseMask(house.phase, true)
    visitor:Teleport(Housing.HOUSE_MAP, house.x, house.y, house.z, house.o)
    
    -- Log visit
    CharDBExecute(string.format(
        "INSERT INTO dc_house_visitors (house_id, visitor_guid) VALUES (%d, %d)",
        house.id, visitor:GetGUIDLow()))
    
    -- Update total visitors
    CharDBExecute("UPDATE dc_player_houses SET visitors_total = visitors_total + 1 WHERE house_id = " .. house.id)
    
    visitor:SendBroadcastMessage("|cff00ff00Welcome to " .. ownerName .. "'s house!|r")
end

-- Slash commands
local function HandleHouseCommand(player, command, args)
    if command ~= "house" and command ~= "home" then
        return true
    end
    
    local subCmd, param = args:match("(%S+)%s*(.*)")
    subCmd = subCmd or ""
    
    if subCmd == "" or subCmd == "go" then
        Housing.GoHome(player)
        
    elseif subCmd == "leave" or subCmd == "exit" then
        Housing.LeaveHouse(player)
        
    elseif subCmd == "visit" then
        if param ~= "" then
            Housing.VisitHouse(player, param)
        else
            player:SendBroadcastMessage("Usage: .house visit <playername>")
        end
        
    elseif subCmd == "place" then
        local itemId = tonumber(param)
        if itemId then
            Housing.PlaceDecoration(player, itemId)
        else
            player:SendBroadcastMessage("Usage: .house place <itemid>")
        end
        
    elseif subCmd == "info" then
        local house = Housing.GetHouse(player)
        if house then
            player:SendBroadcastMessage("|cff00ff00=== Your House ===|r")
            player:SendBroadcastMessage("  Style: " .. Housing.GetStyleName(house.style))
            player:SendBroadcastMessage("  Decorations: " .. Housing.GetDecorationCount(house.id))
            player:SendBroadcastMessage("  Total Visitors: " .. Housing.GetVisitorCount(house.id))
        else
            player:SendBroadcastMessage("You don't have a house.")
        end
        
    elseif subCmd == "permit" then
        local targetName, perm = param:match("(%S+)%s+(%S+)")
        if targetName and perm then
            Housing.SetPermission(player, targetName, perm, true)
        else
            player:SendBroadcastMessage("Usage: .house permit <player> <visit/bank/craft>")
        end
        
    else
        player:SendBroadcastMessage("Usage: .house [go|leave|visit|place|info|permit]")
    end
    
    return false
end
RegisterPlayerEvent(42, HandleHouseCommand)
```

---

## Implementation Phases

### Phase 1 (Weeks 1-2): Core System
- [ ] Database schema
- [ ] Phase management
- [ ] Basic teleportation
- [ ] House purchase

### Phase 2 (Weeks 3-4): Decorations
- [ ] Decoration placement
- [ ] Gameobject spawning
- [ ] Decoration catalog
- [ ] Position editing

### Phase 3 (Weeks 5-6): Features
- [ ] Functional objects (bank, mail)
- [ ] Visiting system
- [ ] Permissions
- [ ] Trophies

### Phase 4 (Weeks 7-8): Polish
- [ ] Client addon
- [ ] Seasonal decorations
- [ ] House styles
- [ ] Leaderboard (most visitors)

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `.house` or `.house go` | Teleport to your house |
| `.house leave` | Return to world |
| `.house visit <name>` | Visit player's house |
| `.house place <itemid>` | Place decoration |
| `.house info` | Show house stats |
| `.house permit <name> <type>` | Grant permissions |

---

## Considerations

### Technical Challenges
- Phase management at scale
- Gameobject persistence
- Instance map selection
- Performance with many decorations

### Economy Balance
- House prices should be significant
- Decoration costs as gold sink
- Premium decorations for revenue

---

## Success Metrics

- House ownership rate
- Decoration placement count
- Visit frequency
- Gold spent on housing

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Performance issues | Limit decorations per house |
| Phase leaking | Strict phase cleanup |
| Exploit decorations | Server-side validation |
| Complexity | Phased rollout, simple first |

---

**Recommendation:** This is a very ambitious feature. Start with a minimal viable product: basic house + teleport + 5 decoration slots. Expand based on player demand. Consider as a Season 2+ feature after core systems are stable.
