# Raid Finder System

**Priority:** S2 - High Priority  
**Effort:** Medium (2 weeks)  
**Impact:** High  
**Base:** Custom queue system with AutoBalance integration

---

## Overview

A Raid Finder system helps players find groups for raid content without needing to rely on guild schedules or trade chat spam. Supports both pickup groups and scheduled raids, with optional difficulty scaling for smaller groups.

---

## Why It Fits DarkChaos-255

### Population Reality
- Low population = hard to fill raids
- Different time zones need flexibility
- New players need raid access
- Catch-up mechanic for alts

### Funserver Value
- More accessible endgame
- Raid achievements for everyone
- Gear progression path
- Community building

### Synergies
| System | Integration |
|--------|-------------|
| **AutoBalance** | Scale raids for smaller groups |
| **Seasonal** | Seasonal raid achievements |
| **Item Upgrade** | Raid drops as upgrade base |
| **Cross-Faction** | Cross-faction raid groups |

---

## Feature Highlights

### Core Features

1. **Queue System**
   - Role-based queue (tank, healer, DPS)
   - iLevel requirements
   - Raid-ready check
   - Solo or partial group queue

2. **Raid Scaling**
   - 10-man and 25-man options
   - Flex scaling (10-25 players)
   - Difficulty adjustment per group size
   - AutoBalance integration

3. **Scheduled Raids**
   - Set specific times
   - Signup system
   - Roster management
   - Raid calendar

4. **Raid Leader Tools**
   - Ready check
   - Role assignment
   - Loot rules (need/greed, master loot)
   - Boss strategy notes

5. **Incentives**
   - Bonus loot for using finder
   - Achievements
   - Weekly raid quest

---

## Technical Implementation

### Database Schema

```sql
-- Raid definitions
CREATE TABLE dc_raid_finder_raids (
    raid_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    raid_name VARCHAR(100),
    map_id INT UNSIGNED,
    difficulty ENUM('10n', '10h', '25n', '25h', 'flex'),
    
    -- Requirements
    min_item_level INT DEFAULT 0,
    min_level INT DEFAULT 80,
    attunement_quest INT UNSIGNED NULL,  -- Required quest completion
    
    -- Group composition
    min_tanks INT DEFAULT 2,
    min_healers INT DEFAULT 2,
    min_dps INT DEFAULT 4,
    min_players INT DEFAULT 10,
    max_players INT DEFAULT 25,
    
    -- Scaling
    use_autobalance TINYINT DEFAULT 1,
    flex_enabled TINYINT DEFAULT 1,
    
    -- Availability
    is_active TINYINT DEFAULT 1,
    seasonal_only TINYINT DEFAULT 0,
    
    INDEX idx_map (map_id)
);

-- Active raid queues
CREATE TABLE dc_raid_finder_queue (
    queue_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_guid INT UNSIGNED,
    raid_id INT UNSIGNED,
    role ENUM('tank', 'healer', 'dps'),
    item_level INT,
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_queue (player_guid),
    INDEX idx_raid (raid_id),
    INDEX idx_role (raid_id, role)
);

-- Group queue (partial groups)
CREATE TABLE dc_raid_finder_group_queue (
    group_queue_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    leader_guid INT UNSIGNED,
    raid_id INT UNSIGNED,
    tanks_have INT DEFAULT 0,
    healers_have INT DEFAULT 0,
    dps_have INT DEFAULT 0,
    total_players INT DEFAULT 0,
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Scheduled raids
CREATE TABLE dc_raid_finder_scheduled (
    schedule_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    raid_id INT UNSIGNED,
    leader_guid INT UNSIGNED,
    leader_name VARCHAR(50),
    
    -- Timing
    scheduled_time TIMESTAMP,
    duration_hours INT DEFAULT 3,
    
    -- Signup info
    title VARCHAR(100),
    description TEXT,
    
    -- Requirements
    min_item_level INT DEFAULT 0,
    voice_required TINYINT DEFAULT 0,
    
    -- Status
    status ENUM('open', 'full', 'in_progress', 'completed', 'cancelled') DEFAULT 'open',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_time (scheduled_time),
    INDEX idx_leader (leader_guid)
);

-- Scheduled raid signups
CREATE TABLE dc_raid_finder_signups (
    signup_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    schedule_id INT UNSIGNED,
    player_guid INT UNSIGNED,
    player_name VARCHAR(50),
    role ENUM('tank', 'healer', 'dps'),
    status ENUM('pending', 'accepted', 'declined', 'standby') DEFAULT 'pending',
    note TEXT,
    signed_up_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_signup (schedule_id, player_guid),
    FOREIGN KEY (schedule_id) REFERENCES dc_raid_finder_scheduled(schedule_id)
);

-- Raid completion history
CREATE TABLE dc_raid_finder_history (
    history_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    raid_id INT UNSIGNED,
    source ENUM('queue', 'scheduled', 'manual'),
    player_count INT,
    bosses_killed INT,
    total_bosses INT,
    completion_percent FLOAT,
    duration_minutes INT,
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample raid data
INSERT INTO dc_raid_finder_raids 
(raid_name, map_id, difficulty, min_item_level, min_tanks, min_healers, min_dps, min_players, max_players) VALUES
-- WotLK Raids
('Naxxramas', 533, '10n', 180, 2, 2, 6, 8, 10),
('Naxxramas', 533, '25n', 180, 2, 5, 15, 20, 25),
('Obsidian Sanctum', 615, '10n', 180, 1, 2, 5, 6, 10),
('Obsidian Sanctum', 615, '25n', 180, 2, 5, 15, 18, 25),
('Eye of Eternity', 616, '10n', 200, 2, 2, 6, 8, 10),
('Ulduar', 603, '10n', 210, 2, 3, 7, 10, 10),
('Ulduar', 603, '25n', 210, 3, 6, 16, 20, 25),
('Trial of the Crusader', 649, '10n', 225, 2, 2, 6, 8, 10),
('Trial of the Crusader', 649, '25n', 225, 2, 5, 15, 20, 25),
('Icecrown Citadel', 631, '10n', 245, 2, 3, 5, 8, 10),
('Icecrown Citadel', 631, '25n', 245, 3, 6, 16, 20, 25),
('Ruby Sanctum', 724, '10n', 255, 2, 2, 5, 8, 10);
```

### Eluna Queue System

```lua
-- Raid Finder Manager
local RaidFinder = {}
RaidFinder.ActiveQueues = {}  -- raid_id -> {tanks={}, healers={}, dps={}}
RaidFinder.QUEUE_CHECK_INTERVAL = 30000  -- 30 seconds

-- Initialize queues
function RaidFinder.Initialize()
    local query = CharDBQuery("SELECT raid_id FROM dc_raid_finder_raids WHERE is_active = 1")
    if query then
        repeat
            local raidId = query:GetUInt32(0)
            RaidFinder.ActiveQueues[raidId] = {
                tanks = {},
                healers = {},
                dps = {}
            }
        until not query:NextRow()
    end
end

-- Queue player for raid
function RaidFinder.QueuePlayer(player, raidId, role)
    local guid = player:GetGUIDLow()
    
    -- Check if already queued
    local existing = CharDBQuery(
        "SELECT 1 FROM dc_raid_finder_queue WHERE player_guid = " .. guid)
    if existing then
        player:SendBroadcastMessage("|cffff0000You are already in a raid queue.|r")
        return false
    end
    
    -- Get raid info
    local raid = RaidFinder.GetRaid(raidId)
    if not raid then
        player:SendBroadcastMessage("|cffff0000Invalid raid.|r")
        return false
    end
    
    -- Check item level
    local ilvl = RaidFinder.GetPlayerItemLevel(player)
    if ilvl < raid.minItemLevel then
        player:SendBroadcastMessage(string.format(
            "|cffff0000Item level too low. Required: %d, You have: %d|r",
            raid.minItemLevel, ilvl))
        return false
    end
    
    -- Validate role
    if not RaidFinder.ValidateRole(player, role) then
        player:SendBroadcastMessage("|cffff0000You cannot queue as that role with your current spec.|r")
        return false
    end
    
    -- Add to database
    CharDBExecute(string.format([[
        INSERT INTO dc_raid_finder_queue (player_guid, raid_id, role, item_level)
        VALUES (%d, %d, '%s', %d)
    ]], guid, raidId, role, ilvl))
    
    -- Add to memory queue
    table.insert(RaidFinder.ActiveQueues[raidId][role .. "s"], {
        guid = guid,
        player = player,
        ilvl = ilvl,
        queuedAt = os.time()
    })
    
    player:SendBroadcastMessage(string.format(
        "|cff00ff00Queued for %s as %s. Estimated wait: %s|r",
        raid.name, role, RaidFinder.EstimateWait(raidId, role)))
    
    return true
end

-- Leave queue
function RaidFinder.LeaveQueue(player)
    local guid = player:GetGUIDLow()
    
    CharDBExecute("DELETE FROM dc_raid_finder_queue WHERE player_guid = " .. guid)
    
    -- Remove from memory queues
    for raidId, queues in pairs(RaidFinder.ActiveQueues) do
        for role, players in pairs(queues) do
            for i, p in ipairs(players) do
                if p.guid == guid then
                    table.remove(players, i)
                    break
                end
            end
        end
    end
    
    player:SendBroadcastMessage("|cff00ff00Left raid queue.|r")
end

-- Check queues and form groups
function RaidFinder.ProcessQueues()
    for raidId, queues in pairs(RaidFinder.ActiveQueues) do
        local raid = RaidFinder.GetRaid(raidId)
        if not raid then goto continue end
        
        local tanks = queues.tanks
        local healers = queues.healers
        local dps = queues.dps
        
        -- Check if we have minimum requirements
        if #tanks >= raid.minTanks and 
           #healers >= raid.minHealers and 
           #dps >= raid.minDps then
            
            local totalPlayers = #tanks + #healers + #dps
            if totalPlayers >= raid.minPlayers then
                -- Form the group!
                RaidFinder.FormGroup(raidId, tanks, healers, dps, raid)
            end
        end
        
        ::continue::
    end
end

-- Form a raid group
function RaidFinder.FormGroup(raidId, tanks, healers, dps, raid)
    local members = {}
    
    -- Take required tanks
    for i = 1, raid.minTanks do
        if tanks[1] then
            table.insert(members, table.remove(tanks, 1))
        end
    end
    
    -- Take required healers
    for i = 1, raid.minHealers do
        if healers[1] then
            table.insert(members, table.remove(healers, 1))
        end
    end
    
    -- Fill with DPS up to max
    local remaining = raid.maxPlayers - #members
    for i = 1, math.min(remaining, #dps) do
        table.insert(members, table.remove(dps, 1))
    end
    
    -- Create raid group
    if #members >= raid.minPlayers then
        RaidFinder.StartRaid(members, raid)
    end
end

-- Start the raid instance
function RaidFinder.StartRaid(members, raid)
    -- Get first member as leader
    local leader = members[1].player
    if not leader then
        -- Find online player
        for _, m in ipairs(members) do
            if m.player and m.player:IsInWorld() then
                leader = m.player
                break
            end
        end
    end
    
    if not leader then return end
    
    -- Create raid group
    local group = leader:GetGroup()
    if not group then
        group = CreateRaid(leader)
    end
    
    -- Add members
    for i = 2, #members do
        local player = members[i].player
        if player and player:IsInWorld() then
            group:AddMember(player)
        end
    end
    
    -- Remove from queue
    for _, m in ipairs(members) do
        CharDBExecute("DELETE FROM dc_raid_finder_queue WHERE player_guid = " .. m.guid)
    end
    
    -- Notify and ready check
    for _, m in ipairs(members) do
        if m.player then
            m.player:SendBroadcastMessage("|cff00ff00[Raid Finder]|r Your group is ready for " .. raid.name .. "!")
            m.player:SendBroadcastMessage("The raid leader will perform a ready check.")
        end
    end
    
    -- Set raid difficulty
    leader:SetRaidDifficulty(raid.difficulty == "25n" and 1 or 0)
    
    -- Log formation
    CharDBExecute(string.format([[
        INSERT INTO dc_raid_finder_history (raid_id, source, player_count, bosses_killed, total_bosses)
        VALUES (%d, 'queue', %d, 0, 0)
    ]], raid.id, #members))
end

-- Scheduled raids
function RaidFinder.CreateScheduledRaid(leader, raidId, scheduledTime, title, description)
    local guid = leader:GetGUIDLow()
    
    CharDBExecute(string.format([[
        INSERT INTO dc_raid_finder_scheduled 
        (raid_id, leader_guid, leader_name, scheduled_time, title, description)
        VALUES (%d, %d, '%s', '%s', '%s', '%s')
    ]], raidId, guid, leader:GetName(), scheduledTime, title, description or ""))
    
    leader:SendBroadcastMessage("|cff00ff00Raid scheduled! Players can now sign up.|r")
    
    -- Announce
    SendWorldMessage(string.format(
        "|cff00ff00[Raid Finder]|r %s scheduled: %s - %s. Type .raid signup <id> to join!",
        leader:GetName(), title, scheduledTime))
end

-- Sign up for scheduled raid
function RaidFinder.SignupForRaid(player, scheduleId, role)
    local guid = player:GetGUIDLow()
    
    -- Check if raid exists and is open
    local raid = CharDBQuery(
        "SELECT status FROM dc_raid_finder_scheduled WHERE schedule_id = " .. scheduleId)
    if not raid or raid:GetString(0) ~= "open" then
        player:SendBroadcastMessage("|cffff0000Raid not found or not accepting signups.|r")
        return
    end
    
    -- Check if already signed up
    local existing = CharDBQuery(string.format(
        "SELECT 1 FROM dc_raid_finder_signups WHERE schedule_id = %d AND player_guid = %d",
        scheduleId, guid))
    if existing then
        player:SendBroadcastMessage("|cffff0000You are already signed up for this raid.|r")
        return
    end
    
    CharDBExecute(string.format([[
        INSERT INTO dc_raid_finder_signups (schedule_id, player_guid, player_name, role)
        VALUES (%d, %d, '%s', '%s')
    ]], scheduleId, guid, player:GetName(), role))
    
    player:SendBroadcastMessage("|cff00ff00Signed up for raid as " .. role .. "!|r")
end

-- Commands
local function HandleRaidCommand(player, command, args)
    if command ~= "raid" and command ~= "rf" then
        return true
    end
    
    local subCmd, param1, param2, param3 = args:match("(%S+)%s*(%S*)%s*(%S*)%s*(.*)")
    subCmd = subCmd or args
    
    if subCmd == "queue" or subCmd == "q" then
        local raidId = tonumber(param1)
        local role = param2 or "dps"
        if raidId then
            RaidFinder.QueuePlayer(player, raidId, role)
        else
            player:SendBroadcastMessage("Usage: .raid queue <raid_id> <tank|healer|dps>")
        end
        
    elseif subCmd == "leave" then
        RaidFinder.LeaveQueue(player)
        
    elseif subCmd == "list" then
        player:SendBroadcastMessage("|cff00ff00=== Available Raids ===|r")
        local raids = CharDBQuery("SELECT raid_id, raid_name, difficulty, min_item_level FROM dc_raid_finder_raids WHERE is_active = 1")
        if raids then
            repeat
                player:SendBroadcastMessage(string.format("  [%d] %s (%s) - iLvl %d+",
                    raids:GetUInt32(0), raids:GetString(1), raids:GetString(2), raids:GetUInt32(3)))
            until not raids:NextRow()
        end
        
    elseif subCmd == "schedule" then
        -- .raid schedule <raid_id> <time> <title>
        local raidId = tonumber(param1)
        local time = param2
        local title = param3
        if raidId and time and title then
            RaidFinder.CreateScheduledRaid(player, raidId, time, title, "")
        else
            player:SendBroadcastMessage("Usage: .raid schedule <raid_id> <YYYY-MM-DD HH:MM> <title>")
        end
        
    elseif subCmd == "signup" then
        local scheduleId = tonumber(param1)
        local role = param2 or "dps"
        if scheduleId then
            RaidFinder.SignupForRaid(player, scheduleId, role)
        else
            player:SendBroadcastMessage("Usage: .raid signup <schedule_id> <tank|healer|dps>")
        end
        
    elseif subCmd == "scheduled" then
        player:SendBroadcastMessage("|cff00ff00=== Scheduled Raids ===|r")
        local scheduled = CharDBQuery([[
            SELECT s.schedule_id, r.raid_name, s.scheduled_time, s.title, s.leader_name
            FROM dc_raid_finder_scheduled s
            JOIN dc_raid_finder_raids r ON s.raid_id = r.raid_id
            WHERE s.status = 'open' AND s.scheduled_time > NOW()
            ORDER BY s.scheduled_time LIMIT 10
        ]])
        if scheduled then
            repeat
                player:SendBroadcastMessage(string.format("  [%d] %s - %s by %s",
                    scheduled:GetUInt32(0), scheduled:GetString(1), 
                    scheduled:GetString(2), scheduled:GetString(4)))
            until not scheduled:NextRow()
        else
            player:SendBroadcastMessage("  No scheduled raids.")
        end
        
    else
        player:SendBroadcastMessage("Usage: .raid queue|leave|list|schedule|signup|scheduled")
    end
    
    return false
end
RegisterPlayerEvent(42, HandleRaidCommand)

-- Process queues every 30 seconds
CreateLuaEvent(function()
    RaidFinder.ProcessQueues()
end, RaidFinder.QUEUE_CHECK_INTERVAL, 0)

-- Initialize on server start
RaidFinder.Initialize()
```

---

## Commands Reference

| Command | Description |
|---------|-------------|
| `.raid list` | Show available raids |
| `.raid queue <id> <role>` | Queue for raid |
| `.raid leave` | Leave queue |
| `.raid schedule <id> <time> <title>` | Create scheduled raid |
| `.raid signup <id> <role>` | Sign up for scheduled raid |
| `.raid scheduled` | Show upcoming scheduled raids |

---

## Implementation Phases

### Phase 1 (Week 1): Core Queue
- [ ] Database schema
- [ ] Queue system
- [ ] Group formation
- [ ] Basic commands

### Phase 2 (Week 2): Features
- [ ] Scheduled raids
- [ ] Signup system
- [ ] AutoBalance integration
- [ ] Notifications

---

## Success Metrics

- Queue times
- Raid completion rates
- Player engagement
- Scheduled raid attendance

---

**Recommendation:** High priority for server health. Start with simple queue system, add scheduled raids after. Critical for retaining casual players who want raid content.
