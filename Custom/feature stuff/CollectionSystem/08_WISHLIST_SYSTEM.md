# Wishlist System Design

**Feature:** Track desired collectables with source information  
**Priority:** Medium (Phase 3)  
**Related:** 06_ADVANCED_FEATURES_EVALUATION.md

---

## Overview

The Wishlist System allows players to track collectables they want to obtain. A key feature is **source tracking** - telling players exactly where and how to obtain each item.

---

## Key Features

### 1. Add to Wishlist
- Right-click any uncollected item → "Add to Wishlist"
- Optional note/priority setting
- Limit: 50 items per wishlist

### 2. Source Information Display
- Shows WHERE to get the collectable
- Shows HOW to get it (drop, vendor, achievement, quest, etc.)
- Shows REQUIREMENTS (reputation, profession, class, etc.)
- Shows DROP RATE if applicable

### 3. Wishlist Notifications
- Alert when entering zone with wishlist item source
- Alert when party member has wishlist item to trade
- Weekly digest of "easy to obtain" wishlist items

---

## Database Schema

### dc_collection_wishlist

```sql
CREATE TABLE IF NOT EXISTS `dc_collection_wishlist` (
    `account_id` INT UNSIGNED NOT NULL,
    `collection_type` ENUM('mount','pet','toy','transmog','title') NOT NULL,
    `item_id` INT UNSIGNED NOT NULL COMMENT 'spell_id for mount/pet, item_id for toy/transmog',
    `added_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `priority` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=low, 2=medium, 3=high',
    `note` VARCHAR(255) DEFAULT NULL COMMENT 'Player note',
    `obtained` TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Auto-set when collected',
    `obtained_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`account_id`, `collection_type`, `item_id`),
    KEY `idx_priority` (`account_id`, `priority` DESC),
    KEY `idx_added` (`account_id`, `added_at` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Player wishlist for collectables';
```

---

## Source Data Structure

The `source` column in definition tables uses JSON to store structured source information:

### Source Types

| Type | JSON Structure |
|------|----------------|
| **Drop** | `{"type":"drop","location":"Zone","boss":"NPC","dropRate":1.5,"difficulty":"heroic"}` |
| **Vendor** | `{"type":"vendor","npc":"NPC Name","cost":50000,"currency":"gold","rep":"Faction","repLevel":"exalted"}` |
| **Achievement** | `{"type":"achievement","name":"Achievement Name","id":1234}` |
| **Quest** | `{"type":"quest","name":"Quest Name","id":5678,"chain":true}` |
| **Profession** | `{"type":"profession","skill":"Engineering","level":450,"recipe":"Recipe Name"}` |
| **PvP** | `{"type":"pvp","rating":1800,"season":1,"currency":"arena_points","cost":350}` |
| **Event** | `{"type":"event","name":"Brewfest","available":"September"}` |
| **TCG** | `{"type":"tcg","card":"Spectral Tiger"}` |
| **Promotion** | `{"type":"promo","source":"Collector's Edition"}` |
| **DarkChaos** | `{"type":"darkChaos","feature":"Mythic+","requirement":"Complete M+15"}` |

### Complete Source Example

```json
{
    "type": "drop",
    "location": "Tempest Keep",
    "instance": "The Eye",
    "boss": "Kael'thas Sunstrider",
    "dropRate": 1.0,
    "difficulty": "normal",
    "raidSize": 25,
    "requirements": {
        "level": 70,
        "attunement": false
    },
    "coordinates": {
        "map": 550,
        "x": 50.0,
        "y": 50.0
    },
    "tips": [
        "Solo farmable at 80",
        "Weekly lockout",
        "Clear trash optional"
    ]
}
```

---

## Source Display in Addon

### Tooltip Format

```
╔══════════════════════════════════════╗
║ Ashes of Al'ar                       ║
║ ─────────────────────────────────────║
║ ★★★★☆ Epic Mount                     ║
║                                      ║
║ Source: Boss Drop                    ║
║ ├─ Location: The Eye (Tempest Keep)  ║
║ ├─ Boss: Kael'thas Sunstrider        ║
║ ├─ Drop Rate: ~1%                    ║
║ └─ Raid Size: 25-man                 ║
║                                      ║
║ Requirements:                        ║
║ ├─ Level 70+ (soloable at 80)        ║
║ └─ No attunement needed              ║
║                                      ║
║ Tips:                                ║
║ • Weekly lockout per character       ║
║ • Trash clearing optional            ║
║                                      ║
║ [Right-click to add to Wishlist]     ║
╚══════════════════════════════════════╝
```

### Wishlist Panel Format

```
╔═══════════════════════════════════════════════════════════╗
║  ★ MY WISHLIST (7/50)                          [Settings] ║
╠═══════════════════════════════════════════════════════════╣
║  Priority: ★★★ High                                       ║
╟───────────────────────────────────────────────────────────╢
║  🐴 Invincible's Reins                                    ║
║     └─ ICC 25 HC - The Lich King (~1%)                    ║
║     └─ Note: "Farm every week!"                           ║
╟───────────────────────────────────────────────────────────╢
║  🐴 Ashes of Al'ar                                        ║
║     └─ Tempest Keep - Kael'thas (~1%)                     ║
╟───────────────────────────────────────────────────────────╢
║  Priority: ★★ Medium                                      ║
╟───────────────────────────────────────────────────────────╢
║  🐱 Phoenix Hatchling                                     ║
║     └─ Magister's Terrace HC - Kael'thas (~8%)            ║
╟───────────────────────────────────────────────────────────╢
║  🎪 Orb of Deception                                      ║
║     └─ World Drop (Level 55-60 zones)                     ║
╟───────────────────────────────────────────────────────────╢
║  Priority: ★ Low                                          ║
╟───────────────────────────────────────────────────────────╢
║  🐴 Raven Lord                                            ║
║     └─ Sethekk Halls HC - Anzu (~1%)                      ║
║     └─ Note: "Need Druid for summon pre-3.3"              ║
╚═══════════════════════════════════════════════════════════╝
```

---

## Source Resolution Functions

### Lua Helper (Client)

```lua
-- Parse source JSON and return formatted string
function DCCollections:FormatSource(sourceJson)
    if not sourceJson or sourceJson == "" then
        return "Unknown Source"
    end
    
    local source = DC.JSON:Decode(sourceJson)
    if not source then return "Unknown Source" end
    
    local formatters = {
        drop = function(s)
            local str = s.location or "Unknown"
            if s.boss then str = str .. " - " .. s.boss end
            if s.dropRate then str = str .. string.format(" (~%.1f%%)", s.dropRate) end
            return str
        end,
        vendor = function(s)
            local str = "Vendor: " .. (s.npc or "Unknown")
            if s.cost then 
                str = str .. " (" .. DCCollections:FormatCost(s.cost, s.currency) .. ")"
            end
            if s.rep then
                str = str .. "\n  └─ Requires: " .. s.rep .. " " .. (s.repLevel or "")
            end
            return str
        end,
        achievement = function(s)
            return "Achievement: " .. (s.name or "Unknown")
        end,
        quest = function(s)
            local str = "Quest: " .. (s.name or "Unknown")
            if s.chain then str = str .. " (quest chain)" end
            return str
        end,
        profession = function(s)
            return string.format("Profession: %s (%d)", s.skill or "Unknown", s.level or 0)
        end,
        pvp = function(s)
            local str = "PvP"
            if s.rating then str = str .. string.format(" (Rating %d+)", s.rating) end
            if s.cost then str = str .. " - " .. s.cost .. " " .. (s.currency or "") end
            return str
        end,
        event = function(s)
            return "World Event: " .. (s.name or "Unknown")
        end,
        tcg = function(s)
            return "Trading Card: " .. (s.card or "Unknown")
        end,
        promo = function(s)
            return "Promotion: " .. (s.source or "Unknown")
        end,
        darkChaos = function(s)
            return "DC: " .. (s.feature or "Unknown") .. " - " .. (s.requirement or "")
        end,
    }
    
    local formatter = formatters[source.type]
    if formatter then
        return formatter(source)
    end
    
    return "Unknown Source"
end
```

---

## Zone-Based Notifications

When player enters a zone, check if any wishlist items are obtainable there:

### Server Logic (Eluna)

```lua
local function OnZoneChange(event, player, newZone, newArea)
    local accountId = player:GetAccountId()
    
    -- Query wishlist items with matching zone
    local query = CharDBQuery(string.format([[
        SELECT w.collection_type, w.item_id, 
               COALESCE(md.name, pd.name, td.name) as item_name,
               COALESCE(md.source, pd.source, td.source) as source
        FROM dc_collection_wishlist w
        LEFT JOIN dc_mount_definitions md ON w.collection_type = 'mount' AND w.item_id = md.spell_id
        LEFT JOIN dc_pet_definitions pd ON w.collection_type = 'pet' AND w.item_id = pd.pet_entry
        LEFT JOIN dc_toy_definitions td ON w.collection_type = 'toy' AND w.item_id = td.item_id
        WHERE w.account_id = %d AND w.obtained = 0
    ]], accountId))
    
    if query then
        repeat
            local source = query:GetString(3)
            -- Parse source JSON, check if location matches current zone
            -- If match, send notification to player
        until not query:NextRow()
    end
end

RegisterPlayerEvent(27, OnZoneChange) -- PLAYER_EVENT_ON_UPDATE_ZONE
```

---

## DCAddonProtocol Messages

### Add to Wishlist
```json
{
    "module": "COLL",
    "opcode": 32,
    "data": {
        "action": "add",
        "type": "mount",
        "id": 32458,
        "priority": 3,
        "note": "Farm every week"
    }
}
```

### Get Wishlist
```json
{
    "module": "COLL",
    "opcode": 33,
    "data": {
        "action": "list"
    }
}
```

### Wishlist Response
```json
{
    "module": "COLL",
    "opcode": 34,
    "data": {
        "items": [
            {
                "type": "mount",
                "id": 32458,
                "name": "Ashes of Al'ar",
                "source": "{\"type\":\"drop\",\"location\":\"Tempest Keep\",\"boss\":\"Kael'thas\",\"dropRate\":1}",
                "priority": 3,
                "note": "Farm every week",
                "addedAt": 1703164800
            }
        ]
    }
}
```

---

## Answering: "Can We Tell Where to Get This?"

**YES!** The source tracking system provides:

| Information | How We Know It |
|-------------|----------------|
| **Location** | Stored in `source` JSON → `location` field |
| **Boss/NPC** | Stored in `source` JSON → `boss` or `npc` field |
| **Drop Rate** | Stored in `source` JSON → `dropRate` field |
| **Requirements** | Stored in `source` JSON → `requirements` object |
| **Tips** | Stored in `source` JSON → `tips` array |
| **Coordinates** | Stored in `source` JSON → `coordinates` object |

### Data Sources

1. **Wowhead/WoWDB** - Import drop rates, locations
2. **DBC Files** - Item/spell associations
3. **Manual Entry** - DC-exclusive items
4. **Community** - Player-submitted tips

---

## Related: Zone Awareness

The wishlist can show a "nearby" indicator:

```lua
-- Check if player is in zone where wishlist item drops
function DCCollections:GetNearbyWishlistItems()
    local zone = GetZoneText()
    local subzone = GetSubZoneText()
    local mapId = GetCurrentMapAreaID()
    
    local nearby = {}
    for _, item in ipairs(self.wishlist) do
        local source = self:ParseSource(item.source)
        if source and source.location then
            if source.location:find(zone) or source.location:find(subzone) then
                table.insert(nearby, item)
            end
        end
    end
    return nearby
end
```

---

## Summary

The Wishlist System provides:

✅ **Track desired items** - Up to 50 per account  
✅ **Know where to get them** - Full source JSON with location, boss, drop rate  
✅ **Priority management** - High/Medium/Low  
✅ **Personal notes** - Remember why you want it  
✅ **Zone notifications** - Alert when entering relevant zones  
✅ **Auto-complete** - Item removed when collected  

