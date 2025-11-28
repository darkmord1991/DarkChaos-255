# Transmog Sets & Wardrobe System

**Priority:** S3 - Medium Priority  
**Effort:** Medium (2 weeks)  
**Impact:** Medium-High  
**Base:** mod-transmog (existing) + custom extensions

---

## Overview

An enhanced Transmogrification system that adds set saving, wardrobe collection tracking, outfit sharing, and cosmetic rewards. Building on the existing mod-transmog, this adds quality-of-life features players expect from modern WoW.

---

## Why It Fits DarkChaos-255

### Current Transmog Limitations
- No outfit saving
- No collection tracking
- No set bonuses for collecting
- Limited UI functionality

### Funserver Value
- Cosmetic progression is huge on private servers
- Fashion competitions/events
- Collection achievements
- Alt-friendly wardrobe

### Synergies
| System | Integration |
|--------|-------------|
| **Collection System** | Appearance collection tracking |
| **Seasonal** | Season-exclusive transmog sets |
| **Mythic+** | M+ themed transmog rewards |
| **Weekend Events** | Transmog unlock weekends |

---

## Feature Highlights

### Core Features

1. **Outfit Manager**
   - Save up to 20 outfits
   - Quick-swap hotkey
   - Per-spec outfits
   - Outfit sharing links

2. **Wardrobe Collection**
   - Track all unlocked appearances
   - Per-slot completion %
   - Set completion tracking
   - "Missing" list for hunting

3. **Set Bonuses**
   - Visual effects for full sets
   - Auras for matching gear
   - Transmog achievements

4. **Fashion System**
   - Player voting on outfits
   - Fashion shows (events)
   - "Fashionista" title

5. **Transmog Tokens**
   - Currency for rare appearances
   - Vendor with exclusive looks
   - Seasonal shop rotation

---

## Technical Implementation

### Database Schema

```sql
-- Saved outfits
CREATE TABLE dc_transmog_outfits (
    outfit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED,
    outfit_name VARCHAR(50),
    outfit_order INT DEFAULT 0,
    
    -- Slot appearances (display IDs or item entries)
    head_display INT UNSIGNED DEFAULT 0,
    shoulder_display INT UNSIGNED DEFAULT 0,
    chest_display INT UNSIGNED DEFAULT 0,
    waist_display INT UNSIGNED DEFAULT 0,
    legs_display INT UNSIGNED DEFAULT 0,
    feet_display INT UNSIGNED DEFAULT 0,
    wrist_display INT UNSIGNED DEFAULT 0,
    hands_display INT UNSIGNED DEFAULT 0,
    back_display INT UNSIGNED DEFAULT 0,
    mainhand_display INT UNSIGNED DEFAULT 0,
    offhand_display INT UNSIGNED DEFAULT 0,
    ranged_display INT UNSIGNED DEFAULT 0,
    tabard_display INT UNSIGNED DEFAULT 0,
    shirt_display INT UNSIGNED DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_player (player_guid)
);

-- Collected appearances (wardrobe)
CREATE TABLE dc_transmog_collection (
    player_guid INT UNSIGNED,
    item_entry INT UNSIGNED,  -- Item template entry
    display_id INT UNSIGNED,  -- Visual appearance
    slot_mask INT UNSIGNED,   -- Which slots this can apply to
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50),       -- 'drop', 'quest', 'vendor', 'craft'
    
    PRIMARY KEY (player_guid, item_entry),
    INDEX idx_player (player_guid),
    INDEX idx_display (display_id)
);

-- Transmog sets (for bonuses)
CREATE TABLE dc_transmog_sets (
    set_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    set_name VARCHAR(100),
    set_description TEXT,
    
    -- Required pieces (display IDs)
    required_pieces JSON,  -- [{"slot": "head", "display": 12345}, ...]
    piece_count INT,
    
    -- Bonus
    bonus_type ENUM('aura', 'title', 'effect', 'achievement'),
    bonus_data JSON,  -- {"aura_id": 12345} or {"title_id": 100}
    
    is_seasonal TINYINT DEFAULT 0,
    season_id INT UNSIGNED NULL
);

-- Fashion votes
CREATE TABLE dc_fashion_votes (
    vote_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    voter_guid INT UNSIGNED,
    target_guid INT UNSIGNED,
    vote_score TINYINT,  -- 1-5
    vote_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_vote (voter_guid, target_guid, DATE(vote_time)),
    INDEX idx_target (target_guid)
);

-- Fashion leaderboard (cached)
CREATE TABLE dc_fashion_leaderboard (
    player_guid INT UNSIGNED PRIMARY KEY,
    player_name VARCHAR(50),
    total_votes INT DEFAULT 0,
    average_score FLOAT DEFAULT 0,
    rank_position INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Transmog currency
CREATE TABLE dc_transmog_tokens (
    player_guid INT UNSIGNED PRIMARY KEY,
    tokens INT UNSIGNED DEFAULT 0
);

-- Sample transmog sets
INSERT INTO dc_transmog_sets (set_name, set_description, required_pieces, piece_count, bonus_type, bonus_data) VALUES
('Tier 10 Warrior', 'Complete Sanctified Ymirjar Lord set', 
 '[{"slot": "head", "display": 64673}, {"slot": "shoulder", "display": 64675}, {"slot": "chest", "display": 64671}, {"slot": "hands", "display": 64672}, {"slot": "legs", "display": 64674}]',
 5, 'aura', '{"aura_id": 70901}'),
('Dark Phoenix', 'Legendary phoenix-themed set',
 '[{"slot": "head", "display": 100001}, {"slot": "shoulder", "display": 100002}, {"slot": "chest", "display": 100003}]',
 3, 'effect', '{"particle_id": 500}'),
('Season 1 Champion', 'Season 1 exclusive gladiator set',
 '[{"slot": "head", "display": 110001}, {"slot": "shoulder", "display": 110002}]',
 2, 'title', '{"title_id": 200}');
```

### Eluna Outfit System

```lua
-- Transmog Wardrobe Manager
local Wardrobe = {}
Wardrobe.PlayerOutfits = {}  -- Cache

-- Load outfits for a player
function Wardrobe.LoadOutfits(player)
    local guid = player:GetGUIDLow()
    Wardrobe.PlayerOutfits[guid] = {}
    
    local query = CharDBQuery([[
        SELECT outfit_id, outfit_name, head_display, shoulder_display, chest_display,
               waist_display, legs_display, feet_display, wrist_display, hands_display,
               back_display, mainhand_display, offhand_display, ranged_display
        FROM dc_transmog_outfits
        WHERE player_guid = ]] .. guid .. [[ ORDER BY outfit_order
    ]])
    
    if query then
        repeat
            table.insert(Wardrobe.PlayerOutfits[guid], {
                id = query:GetUInt32(0),
                name = query:GetString(1),
                slots = {
                    [1] = query:GetUInt32(2),   -- head
                    [3] = query:GetUInt32(3),   -- shoulder
                    [5] = query:GetUInt32(4),   -- chest
                    [6] = query:GetUInt32(5),   -- waist
                    [7] = query:GetUInt32(6),   -- legs
                    [8] = query:GetUInt32(7),   -- feet
                    [9] = query:GetUInt32(8),   -- wrist
                    [10] = query:GetUInt32(9),  -- hands
                    [15] = query:GetUInt32(10), -- back
                    [16] = query:GetUInt32(11), -- mainhand
                    [17] = query:GetUInt32(12), -- offhand
                    [18] = query:GetUInt32(13), -- ranged
                }
            })
        until not query:NextRow()
    end
end

-- Save current appearance as outfit
function Wardrobe.SaveOutfit(player, outfitName)
    local guid = player:GetGUIDLow()
    local outfits = Wardrobe.PlayerOutfits[guid] or {}
    
    if #outfits >= 20 then
        player:SendBroadcastMessage("|cffff0000You have reached the maximum outfit limit (20).|r")
        return false
    end
    
    -- Get current appearances
    local appearances = {}
    local slotIds = {1, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18}
    
    for _, slot in ipairs(slotIds) do
        local item = player:GetItemByPos(255, slot)
        if item then
            -- Get transmog appearance or actual appearance
            local display = item:GetTransmog() or item:GetDisplayId()
            appearances[slot] = display
        else
            appearances[slot] = 0
        end
    end
    
    -- Save to database
    CharDBExecute(string.format([[
        INSERT INTO dc_transmog_outfits 
        (player_guid, outfit_name, head_display, shoulder_display, chest_display,
         waist_display, legs_display, feet_display, wrist_display, hands_display,
         back_display, mainhand_display, offhand_display, ranged_display, outfit_order)
        VALUES (%d, '%s', %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d)
    ]], guid, outfitName, 
        appearances[1] or 0, appearances[3] or 0, appearances[5] or 0,
        appearances[6] or 0, appearances[7] or 0, appearances[8] or 0,
        appearances[9] or 0, appearances[10] or 0, appearances[15] or 0,
        appearances[16] or 0, appearances[17] or 0, appearances[18] or 0,
        #outfits + 1
    ))
    
    -- Reload
    Wardrobe.LoadOutfits(player)
    player:SendBroadcastMessage("|cff00ff00Outfit '" .. outfitName .. "' saved!|r")
    return true
end

-- Apply saved outfit
function Wardrobe.ApplyOutfit(player, outfitId)
    local guid = player:GetGUIDLow()
    local outfits = Wardrobe.PlayerOutfits[guid]
    
    if not outfits then
        Wardrobe.LoadOutfits(player)
        outfits = Wardrobe.PlayerOutfits[guid]
    end
    
    local outfit = nil
    for _, o in ipairs(outfits) do
        if o.id == outfitId then
            outfit = o
            break
        end
    end
    
    if not outfit then
        player:SendBroadcastMessage("|cffff0000Outfit not found.|r")
        return false
    end
    
    -- Apply each slot
    for slot, display in pairs(outfit.slots) do
        if display > 0 then
            local item = player:GetItemByPos(255, slot)
            if item then
                -- Check if player has unlocked this appearance
                if Wardrobe.HasAppearance(player, display) then
                    item:SetTransmog(display)
                else
                    player:SendBroadcastMessage("|cffff0000Missing appearance for slot " .. slot .. "|r")
                end
            end
        end
    end
    
    player:SendBroadcastMessage("|cff00ff00Outfit '" .. outfit.name .. "' applied!|r")
    return true
end

-- Check if player has collected an appearance
function Wardrobe.HasAppearance(player, displayId)
    local guid = player:GetGUIDLow()
    local query = CharDBQuery([[
        SELECT 1 FROM dc_transmog_collection 
        WHERE player_guid = ]] .. guid .. [[ AND display_id = ]] .. displayId)
    return query ~= nil
end

-- Collect appearance when item is obtained
function Wardrobe.CollectAppearance(player, item)
    local guid = player:GetGUIDLow()
    local entry = item:GetEntry()
    local display = item:GetDisplayId()
    
    -- Check if already collected
    local exists = CharDBQuery([[
        SELECT 1 FROM dc_transmog_collection 
        WHERE player_guid = ]] .. guid .. [[ AND item_entry = ]] .. entry)
    
    if not exists then
        CharDBExecute(string.format([[
            INSERT INTO dc_transmog_collection 
            (player_guid, item_entry, display_id, slot_mask, source)
            VALUES (%d, %d, %d, %d, 'obtained')
        ]], guid, entry, display, item:GetSlotMask()))
        
        player:SendBroadcastMessage("|cff00ff00New appearance collected!|r")
    end
end

-- Slash commands
local function HandleWardrobeCommand(player, command, args)
    if command ~= "wardrobe" and command ~= "outfit" then
        return true
    end
    
    local subCmd, param = args:match("(%S+)%s*(.*)")
    subCmd = subCmd or args
    
    if subCmd == "save" then
        local name = param ~= "" and param or "Outfit " .. os.date("%H:%M")
        Wardrobe.SaveOutfit(player, name)
        
    elseif subCmd == "load" then
        local outfitId = tonumber(param)
        if outfitId then
            Wardrobe.ApplyOutfit(player, outfitId)
        else
            player:SendBroadcastMessage("Usage: .outfit load <id>")
        end
        
    elseif subCmd == "list" then
        local outfits = Wardrobe.PlayerOutfits[player:GetGUIDLow()] or {}
        player:SendBroadcastMessage("|cff00ff00=== Your Outfits ===|r")
        for i, o in ipairs(outfits) do
            player:SendBroadcastMessage(string.format("  [%d] %s", o.id, o.name))
        end
        
    elseif subCmd == "delete" then
        local outfitId = tonumber(param)
        if outfitId then
            CharDBExecute("DELETE FROM dc_transmog_outfits WHERE outfit_id = " .. outfitId .. 
                " AND player_guid = " .. player:GetGUIDLow())
            Wardrobe.LoadOutfits(player)
            player:SendBroadcastMessage("|cffff0000Outfit deleted.|r")
        end
        
    elseif subCmd == "collection" then
        local count = Wardrobe.GetCollectionCount(player)
        player:SendBroadcastMessage("|cff00ff00Appearances collected: " .. count .. "|r")
        
    else
        player:SendBroadcastMessage("Usage: .wardrobe save|load|list|delete|collection")
    end
    
    return false
end
RegisterPlayerEvent(42, HandleWardrobeCommand)

-- Load outfits on login
local function OnLogin(event, player)
    Wardrobe.LoadOutfits(player)
end
RegisterPlayerEvent(3, OnLogin)

-- Collect appearances when looting
local function OnLootItem(event, player, item, count)
    Wardrobe.CollectAppearance(player, item)
end
RegisterPlayerEvent(29, OnLootItem)
```

### Fashion Voting

```lua
-- Fashion voting system
local Fashion = {}

function Fashion.Vote(voter, target, score)
    if score < 1 or score > 5 then
        voter:SendBroadcastMessage("Vote must be between 1 and 5.")
        return
    end
    
    if voter:GetGUIDLow() == target:GetGUIDLow() then
        voter:SendBroadcastMessage("You cannot vote for yourself.")
        return
    end
    
    CharDBExecute(string.format([[
        INSERT INTO dc_fashion_votes (voter_guid, target_guid, vote_score)
        VALUES (%d, %d, %d)
        ON DUPLICATE KEY UPDATE vote_score = %d, vote_time = NOW()
    ]], voter:GetGUIDLow(), target:GetGUIDLow(), score, score))
    
    voter:SendBroadcastMessage("|cff00ff00You rated " .. target:GetName() .. "'s outfit " .. score .. "/5|r")
    target:SendBroadcastMessage("|cff00ff00" .. voter:GetName() .. " rated your outfit " .. score .. "/5!|r")
    
    -- Update leaderboard cache
    Fashion.UpdateLeaderboard(target)
end

function Fashion.UpdateLeaderboard(player)
    local guid = player:GetGUIDLow()
    
    CharDBExecute(string.format([[
        INSERT INTO dc_fashion_leaderboard (player_guid, player_name, total_votes, average_score)
        SELECT %d, '%s', COUNT(*), AVG(vote_score)
        FROM dc_fashion_votes WHERE target_guid = %d
        ON DUPLICATE KEY UPDATE 
            total_votes = (SELECT COUNT(*) FROM dc_fashion_votes WHERE target_guid = %d),
            average_score = (SELECT AVG(vote_score) FROM dc_fashion_votes WHERE target_guid = %d)
    ]], guid, player:GetName(), guid, guid, guid))
end

-- Command: .fashion vote <player> <1-5>
local function HandleFashionCommand(player, command, args)
    if command ~= "fashion" then return true end
    
    local subCmd, param1, param2 = args:match("(%S+)%s*(%S*)%s*(%S*)")
    
    if subCmd == "vote" then
        local targetName = param1
        local score = tonumber(param2)
        
        if not targetName or not score then
            player:SendBroadcastMessage("Usage: .fashion vote <player> <1-5>")
            return false
        end
        
        local target = GetPlayerByName(targetName)
        if target then
            Fashion.Vote(player, target, score)
        else
            player:SendBroadcastMessage("Player not found.")
        end
        
    elseif subCmd == "top" then
        player:SendBroadcastMessage("|cff00ff00=== Fashion Leaderboard ===|r")
        local query = CharDBQuery([[
            SELECT player_name, average_score, total_votes 
            FROM dc_fashion_leaderboard 
            ORDER BY average_score DESC, total_votes DESC 
            LIMIT 10
        ]])
        if query then
            local rank = 1
            repeat
                player:SendBroadcastMessage(string.format("  %d. %s - %.1f/5 (%d votes)",
                    rank, query:GetString(0), query:GetFloat(1), query:GetUInt32(2)))
                rank = rank + 1
            until not query:NextRow()
        end
        
    elseif subCmd == "myscore" then
        local query = CharDBQuery([[
            SELECT average_score, total_votes FROM dc_fashion_leaderboard 
            WHERE player_guid = ]] .. player:GetGUIDLow())
        if query then
            player:SendBroadcastMessage(string.format(
                "|cff00ff00Your fashion score: %.1f/5 (%d votes)|r",
                query:GetFloat(0), query:GetUInt32(1)))
        else
            player:SendBroadcastMessage("No votes yet!")
        end
    end
    
    return false
end
RegisterPlayerEvent(42, HandleFashionCommand)
```

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `.outfit save <name>` | Save current appearance |
| `.outfit load <id>` | Apply saved outfit |
| `.outfit list` | List saved outfits |
| `.outfit delete <id>` | Delete outfit |
| `.wardrobe collection` | Show collection count |
| `.fashion vote <player> <1-5>` | Rate player's outfit |
| `.fashion top` | Show fashion leaderboard |
| `.fashion myscore` | Show your fashion rating |

---

## Implementation Phases

### Phase 1 (Week 1): Outfit System
- [ ] Database schema
- [ ] Save/load outfits
- [ ] Appearance collection
- [ ] Basic commands

### Phase 2 (Week 2): Fashion & Polish
- [ ] Fashion voting
- [ ] Leaderboard
- [ ] Set bonuses
- [ ] Client addon (optional)

---

## Success Metrics

- Outfits saved per player
- Collection completion rates
- Fashion votes per day
- Event participation

---

**Recommendation:** Start with outfit saving (most requested feature). Add collection tracking as part of the larger Collection System. Fashion voting can be a fun weekend event feature.
