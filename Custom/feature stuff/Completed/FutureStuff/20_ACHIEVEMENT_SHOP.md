# Achievement Points Shop

**Priority:** A8 (High Priority)  
**Effort:** Low (3 days)  
**Impact:** Medium  
**Base:** Custom NPC + Eluna Script

---

## Overview

An NPC vendor where players can spend their accumulated achievement points to purchase cosmetic rewards, convenience items, and exclusive gear. Gives achievement points real value beyond bragging rights.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Achievements** | Uses existing achievement points |
| **Seasonal System** | Season-exclusive shop items |
| **Transmog** | Exclusive transmog appearances |
| **Prestige** | Prestige-only shop tier |

### Benefits
- Makes achievements meaningful
- New currency sink
- Exclusive cosmetic rewards
- Simple implementation
- Encourages achievement hunting

---

## Features

### 1. **Shop Tiers**
Based on total achievement points earned:
- Bronze Tier: 0-1000 points
- Silver Tier: 1001-3000 points
- Gold Tier: 3001-6000 points
- Platinum Tier: 6001-10000 points
- Legendary Tier: 10001+ points

### 2. **Item Categories**
- Mounts (unique achievement mounts)
- Pets (companion pets)
- Titles (purchasable titles)
- Transmog (exclusive appearances)
- Toys (fun items)
- Bags (large bags)
- Consumables (buffs, scrolls)

### 3. **Currency System**
- Spend actual achievement points
- Points are NOT consumed (checked against total)
- OR: Use separate "achievement currency"
- Configurable per-server preference

---

## Implementation

### NPC Vendor
```sql
-- Create Achievement Shop NPC
INSERT INTO creature_template (entry, name, subname, minlevel, maxlevel, faction, npcflag) VALUES
(800100, 'Accolade Keeper', 'Achievement Vendor', 80, 80, 35, 128);

-- Spawn in major cities
INSERT INTO creature (guid, id, map, position_x, position_y, position_z, orientation) VALUES
(8001001, 800100, 0, -8826.56, 626.358, 94.0756, 3.75), -- Stormwind
(8001002, 800100, 1, 1630.29, -4420.64, 16.4524, 2.45); -- Orgrimmar
```

### Shop Items Table
```sql
CREATE TABLE dc_achievement_shop (
    item_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    item_entry INT UNSIGNED NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    category ENUM('mount', 'pet', 'title', 'transmog', 'toy', 'bag', 'consumable') NOT NULL,
    points_required INT UNSIGNED NOT NULL,
    tier_required ENUM('bronze', 'silver', 'gold', 'platinum', 'legendary') DEFAULT 'bronze',
    stock_limit INT DEFAULT -1,  -- -1 = unlimited
    seasonal_only BOOLEAN DEFAULT FALSE,
    season_id INT UNSIGNED DEFAULT 0,
    prestige_required TINYINT UNSIGNED DEFAULT 0,
    description TEXT
);

-- Sample items
INSERT INTO dc_achievement_shop (item_entry, item_name, category, points_required, tier_required, description) VALUES
(50001, 'Achiever''s Steed', 'mount', 500, 'bronze', 'A modest mount for the budding achiever'),
(50002, 'Champion''s Charger', 'mount', 2000, 'silver', 'For those who have proven their worth'),
(50003, 'Legendary Warhorse', 'mount', 5000, 'gold', 'A mount befitting a true champion'),
(50004, 'Mythic Netherwing', 'mount', 10000, 'legendary', 'Only the greatest achieve this honor'),

(50010, 'Mini Achiever', 'pet', 300, 'bronze', 'A tiny companion that celebrates your victories'),
(50011, 'Golden Trophy', 'pet', 1500, 'silver', 'A floating golden trophy pet'),

(50020, 'the Accomplished', 'title', 1000, 'silver', 'A title showing dedication'),
(50021, 'the Legendary', 'title', 8000, 'platinum', 'Reserved for the elite'),

(50030, 'Achievement Cloak', 'transmog', 750, 'bronze', 'A cloak with achievement motif'),
(50031, 'Champion''s Regalia Set', 'transmog', 4000, 'gold', 'Full transmog set');
```

### Eluna Script
```lua
local AchievementShop = {}

-- Check if player can afford item
function AchievementShop.CanAfford(player, itemId)
    local query = CharDBQuery("SELECT points_required, tier_required, prestige_required FROM dc_achievement_shop WHERE item_id = " .. itemId)
    if not query then return false end
    
    local pointsRequired = query:GetUInt32(0)
    local tierRequired = query:GetString(1)
    local prestigeRequired = query:GetUInt32(2)
    
    local playerPoints = player:GetAchievementPoints()
    local playerTier = AchievementShop.GetTier(playerPoints)
    local playerPrestige = GetPrestigeLevel(player:GetGUIDLow())
    
    -- Check tier
    if not AchievementShop.MeetsTier(playerTier, tierRequired) then
        return false, "Your tier is too low"
    end
    
    -- Check prestige
    if playerPrestige < prestigeRequired then
        return false, "Requires Prestige " .. prestigeRequired
    end
    
    return true
end

-- Get player's tier
function AchievementShop.GetTier(points)
    if points >= 10001 then return "legendary"
    elseif points >= 6001 then return "platinum"
    elseif points >= 3001 then return "gold"
    elseif points >= 1001 then return "silver"
    else return "bronze"
    end
end

-- Purchase item
function AchievementShop.Purchase(player, itemId)
    local canAfford, reason = AchievementShop.CanAfford(player, itemId)
    if not canAfford then
        player:SendBroadcastMessage("|cFFFF0000Cannot purchase: " .. reason .. "|r")
        return false
    end
    
    local query = CharDBQuery("SELECT item_entry, item_name FROM dc_achievement_shop WHERE item_id = " .. itemId)
    local itemEntry = query:GetUInt32(0)
    local itemName = query:GetString(1)
    
    if player:AddItem(itemEntry, 1) then
        player:SendBroadcastMessage("|cFF00FF00Purchased: " .. itemName .. "|r")
        return true
    else
        player:SendBroadcastMessage("|cFFFF0000Inventory full!|r")
        return false
    end
end

-- NPC Gossip
function AchievementShop.OnGossipHello(event, player, creature)
    local points = player:GetAchievementPoints()
    local tier = AchievementShop.GetTier(points)
    
    player:GossipMenuAddItem(0, "Your Points: " .. points .. " (" .. tier .. " tier)", 1, 0)
    player:GossipMenuAddItem(0, "[Browse Mounts]", 1, 1)
    player:GossipMenuAddItem(0, "[Browse Pets]", 1, 2)
    player:GossipMenuAddItem(0, "[Browse Titles]", 1, 3)
    player:GossipMenuAddItem(0, "[Browse Transmog]", 1, 4)
    player:GossipMenuAddItem(0, "[Browse Toys]", 1, 5)
    player:GossipMenuAddItem(0, "[Browse Consumables]", 1, 6)
    player:GossipSendMenu(1, creature)
end

RegisterCreatureGossipEvent(800100, 1, AchievementShop.OnGossipHello)
```

---

## Shop Catalog

### Mounts (Sample)
| Item | Points | Tier |
|------|--------|------|
| Achiever's Steed | 500 | Bronze |
| Champion's Charger | 2000 | Silver |
| Golden Achievement Dragon | 5000 | Gold |
| Mythic Netherwing | 10000 | Legendary |

### Titles (Sample)
| Title | Points | Tier |
|-------|--------|------|
| the Dedicated | 500 | Bronze |
| the Accomplished | 1000 | Silver |
| Champion of Achievements | 3500 | Gold |
| the Legendary | 8000 | Platinum |
| Realm First Achiever | 15000 | Legendary |

### Pets (Sample)
| Pet | Points | Tier |
|-----|--------|------|
| Mini Achiever | 300 | Bronze |
| Golden Trophy | 1500 | Silver |
| Achievement Dragon Whelp | 4000 | Gold |

---

## Commands

```
.achieveshop browse    - Open shop (alternative to NPC)
.achieveshop points    - Show your achievement points
.achieveshop tier      - Show your current tier
```

---

## Configuration

```conf
# worldserver.conf
AchievementShop.Enable = 1
AchievementShop.ConsumePoints = 0    # 0 = check only, 1 = consume points
AchievementShop.SeasonalItems = 1    # Enable seasonal items
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 1 hour |
| NPC creation | 1 hour |
| Eluna shop script | 4 hours |
| Item catalog creation | 4 hours |
| Testing | 4 hours |
| **Total** | **~2-3 days** |

---

## Future Enhancements

1. **Dynamic Pricing** - Prices change based on demand
2. **Limited Edition** - Time-limited items
3. **Bundles** - Discounted item packs
4. **Prestige Exclusives** - Items only for high prestige
5. **Guild Achievements** - Guild-wide shop items
