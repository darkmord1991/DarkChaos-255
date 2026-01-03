# Phased Dueling Arenas System

**Priority:** S4 - High Priority  
**Effort:** Low (1 week)  
**Impact:** Medium  
**Base:** Custom Eluna/C++ with existing phasing technology

---

## Overview

Phased Dueling Arenas create private, instanced duel zones where players can fight without interference. Players enter a "duel queue" or teleport to arena locations, then get phased into a private copy of the arena. This prevents griefing, spectating issues, and allows for rated 1v1 content.

---

## Why It Fits DarkChaos-255

### Funserver PvP Enhancement
- 255 funservers attract PvP-focused players
- Clean dueling experience without distractions
- Tournament potential (rated 1v1 ladder)
- Integrates with HLBG as another PvP mode

### Current Problems Solved
- Mall dueling chaos with dozens of players
- Buff stealing/griefing during duels
- No structured 1v1 ladder
- Spectators interfering with fights

### Synergies
| System | Integration |
|--------|-------------|
| **HLBG** | Alternative PvP mode, shared rating? |
| **Seasonal** | Seasonal 1v1 rankings, rewards |
| **Prestige** | Duel wins count toward prestige |
| **Hotspots** | "Active Arena" as hotspot type |

---

## Feature Highlights

### Core Features

1. **Private Phased Arenas**
   - Players phased into private copy
   - Multiple arena layouts (Gurubashi, Ring of Valor, custom)
   - Countdown timer before fight starts
   - Auto-teleport back after fight

2. **Duel Queue System**
   - Queue for random opponent (MMR based)
   - Challenge specific player
   - Class-specific queues optional

3. **Rated Dueling (1v1 Ladder)**
   - MMR/Elo system
   - Seasonal resets
   - Leaderboard
   - Rewards at thresholds

4. **Spectator Mode**
   - Watch ongoing duels
   - Spectator phasing (invisible)
   - Stream-friendly

5. **Tournament Mode**
   - Bracket tournaments
   - Single/double elimination
   - Admin-initiated or scheduled

### Arena Layouts
| Arena | Description | Size |
|-------|-------------|------|
| Gurubashi Pit | Classic circular arena | Small |
| Ring of Valor | Retail-style with pillars | Medium |
| Nagrand Arena | Open with minimal obstacles | Medium |
| Blade's Edge | Elevated platforms | Large |
| Custom Mall Arena | DarkChaos themed | Medium |

---

## Technical Implementation

### Database Schema

```sql
-- Arena definitions
CREATE TABLE dc_duel_arenas (
    arena_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    arena_name VARCHAR(50),
    map_id INT UNSIGNED,
    pos_x FLOAT, pos_y FLOAT, pos_z FLOAT, pos_o FLOAT,  -- Spawn point 1
    pos2_x FLOAT, pos2_y FLOAT, pos2_z FLOAT, pos2_o FLOAT,  -- Spawn point 2
    phase_base INT UNSIGNED DEFAULT 1000000,  -- Base phase for instances
    is_active TINYINT DEFAULT 1
);

-- Active duels (phased instances)
CREATE TABLE dc_active_duels (
    duel_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    arena_id INT UNSIGNED,
    phase_id INT UNSIGNED,  -- Unique phase for this duel
    player1_guid INT UNSIGNED,
    player2_guid INT UNSIGNED,
    player1_ready TINYINT DEFAULT 0,
    player2_ready TINYINT DEFAULT 0,
    status ENUM('pending', 'countdown', 'active', 'finished') DEFAULT 'pending',
    started_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    winner_guid INT UNSIGNED NULL
);

-- Rated duel statistics
CREATE TABLE dc_duel_ratings (
    player_guid INT UNSIGNED PRIMARY KEY,
    rating INT DEFAULT 1500,
    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    highest_rating INT DEFAULT 1500,
    current_streak INT DEFAULT 0,
    best_streak INT DEFAULT 0,
    season_id INT UNSIGNED DEFAULT 1,
    last_fight TIMESTAMP NULL
);

-- Duel history (for replays/stats)
CREATE TABLE dc_duel_history (
    duel_id INT UNSIGNED PRIMARY KEY,
    arena_id INT UNSIGNED,
    player1_guid INT UNSIGNED,
    player2_guid INT UNSIGNED,
    winner_guid INT UNSIGNED,
    p1_class TINYINT, p2_class TINYINT,
    p1_rating_before INT, p1_rating_after INT,
    p2_rating_before INT, p2_rating_after INT,
    duration_seconds INT,
    fight_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Queue for matchmaking
CREATE TABLE dc_duel_queue (
    player_guid INT UNSIGNED PRIMARY KEY,
    queue_type ENUM('random', 'rated') DEFAULT 'random',
    rating INT,  -- Cached for matchmaking
    class_id TINYINT,
    queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Arena definitions data
INSERT INTO dc_duel_arenas (arena_name, map_id, pos_x, pos_y, pos_z, pos_o, pos2_x, pos2_y, pos2_z, pos2_o) VALUES
('Gurubashi Arena', 0, -13261.3, 168.294, 35.0, 1.5, -13229.5, 168.294, 35.0, 4.7),
('Ring of Valor', 618, 763.632, -284.0, 28.276, 3.14, 763.632, -306.162, 28.276, 0),
('Nagrand Arena', 559, 4055.0, 2921.0, 13.0, 4.7, 4023.0, 2895.0, 13.0, 1.5);
```

### Eluna Implementation

```lua
-- Duel Arena Manager
local DuelArena = {}
DuelArena.ActiveDuels = {}  -- phase_id -> duel_info
DuelArena.QueuedPlayers = {}  -- guid -> queue_info
DuelArena.NextPhase = 1000000

-- Queue for a duel
function DuelArena.QueuePlayer(player, queueType)
    local guid = player:GetGUIDLow()
    
    if DuelArena.QueuedPlayers[guid] then
        player:SendBroadcastMessage("You are already in queue.")
        return
    end
    
    local rating = DuelArena.GetPlayerRating(player)
    
    DuelArena.QueuedPlayers[guid] = {
        player = player,
        queueType = queueType,
        rating = rating,
        class = player:GetClass(),
        queuedAt = os.time()
    }
    
    player:SendBroadcastMessage("You have joined the " .. queueType .. " duel queue.")
    
    -- Try to find match immediately
    DuelArena.TryMatchmaking()
end

-- Matchmaking logic
function DuelArena.TryMatchmaking()
    local ratedQueue = {}
    
    for guid, info in pairs(DuelArena.QueuedPlayers) do
        if info.queueType == "rated" then
            table.insert(ratedQueue, {guid = guid, info = info})
        end
    end
    
    -- Sort by rating
    table.sort(ratedQueue, function(a, b) return a.info.rating < b.info.rating end)
    
    -- Match adjacent ratings (within 200 rating)
    local i = 1
    while i < #ratedQueue do
        local p1 = ratedQueue[i]
        local p2 = ratedQueue[i + 1]
        
        local ratingDiff = math.abs(p1.info.rating - p2.info.rating)
        local waitTime = os.time() - math.min(p1.info.queuedAt, p2.info.queuedAt)
        
        -- Expand search range based on wait time (50 rating per minute)
        local allowedDiff = 100 + (waitTime / 60) * 50
        
        if ratingDiff <= allowedDiff then
            DuelArena.CreateMatch(p1.guid, p2.guid)
            i = i + 2
        else
            i = i + 1
        end
    end
end

-- Create a phased match
function DuelArena.CreateMatch(guid1, guid2)
    local player1 = GetPlayerByGUID(guid1)
    local player2 = GetPlayerByGUID(guid2)
    
    if not player1 or not player2 then
        DuelArena.QueuedPlayers[guid1] = nil
        DuelArena.QueuedPlayers[guid2] = nil
        return
    end
    
    -- Remove from queue
    DuelArena.QueuedPlayers[guid1] = nil
    DuelArena.QueuedPlayers[guid2] = nil
    
    -- Select random arena
    local arenas = CharDBQuery("SELECT * FROM dc_duel_arenas WHERE is_active = 1")
    local arenaCount = arenas:GetRowCount()
    local arenaIndex = math.random(1, arenaCount)
    for i = 1, arenaIndex - 1 do arenas:NextRow() end
    
    local arenaId = arenas:GetUInt32(0)
    local arenaName = arenas:GetString(1)
    local mapId = arenas:GetUInt32(2)
    
    -- Get unique phase
    local phaseId = DuelArena.NextPhase
    DuelArena.NextPhase = DuelArena.NextPhase + 1
    
    -- Store duel info
    local duel = {
        duelId = nil,  -- Set after DB insert
        arenaId = arenaId,
        phaseId = phaseId,
        player1 = player1,
        player2 = player2,
        p1Ready = false,
        p2Ready = false,
        status = "pending",
        startTime = nil
    }
    DuelArena.ActiveDuels[phaseId] = duel
    
    -- Teleport and phase players
    local x1, y1, z1, o1 = arenas:GetFloat(3), arenas:GetFloat(4), arenas:GetFloat(5), arenas:GetFloat(6)
    local x2, y2, z2, o2 = arenas:GetFloat(7), arenas:GetFloat(8), arenas:GetFloat(9), arenas:GetFloat(10)
    
    -- Save return positions
    duel.p1Return = {player1:GetMapId(), player1:GetX(), player1:GetY(), player1:GetZ()}
    duel.p2Return = {player2:GetMapId(), player2:GetX(), player2:GetY(), player2:GetZ()}
    
    -- Phase players
    player1:SetPhaseMask(phaseId, true)
    player2:SetPhaseMask(phaseId, true)
    
    -- Teleport
    player1:Teleport(mapId, x1, y1, z1, o1)
    player2:Teleport(mapId, x2, y2, z2, o2)
    
    -- Announce
    player1:SendBroadcastMessage("Match found! Arena: " .. arenaName)
    player2:SendBroadcastMessage("Match found! Arena: " .. arenaName)
    
    -- Full heal and reset cooldowns
    player1:SetFullHealth()
    player1:SetPower(player1:GetPowerType(), player1:GetMaxPower(player1:GetPowerType()))
    player2:SetFullHealth()
    player2:SetPower(player2:GetPowerType(), player2:GetMaxPower(player2:GetPowerType()))
    
    -- Start countdown after 3 seconds
    CreateLuaEvent(function()
        DuelArena.StartCountdown(phaseId)
    end, 3000, 1)
end

-- Countdown before fight
function DuelArena.StartCountdown(phaseId)
    local duel = DuelArena.ActiveDuels[phaseId]
    if not duel then return end
    
    duel.status = "countdown"
    local countdown = 5
    
    -- Root players during countdown
    duel.player1:CastSpell(duel.player1, 45334, true)  -- Wild Magic (root visual)
    duel.player2:CastSpell(duel.player2, 45334, true)
    
    local function DoCountdown()
        if countdown > 0 then
            duel.player1:SendBroadcastMessage("Fight begins in " .. countdown .. "...")
            duel.player2:SendBroadcastMessage("Fight begins in " .. countdown .. "...")
            countdown = countdown - 1
            CreateLuaEvent(DoCountdown, 1000, 1)
        else
            duel.player1:RemoveAura(45334)
            duel.player2:RemoveAura(45334)
            duel.player1:SendBroadcastMessage("|cff00ff00FIGHT!|r")
            duel.player2:SendBroadcastMessage("|cff00ff00FIGHT!|r")
            duel.status = "active"
            duel.startTime = os.time()
        end
    end
    
    DoCountdown()
end

-- Handle player death
local function OnPlayerKilled(event, killer, killed)
    -- Find if player was in a duel
    for phaseId, duel in pairs(DuelArena.ActiveDuels) do
        if duel.status == "active" then
            local killedGuid = killed:GetGUIDLow()
            if killedGuid == duel.player1:GetGUIDLow() or killedGuid == duel.player2:GetGUIDLow() then
                DuelArena.EndDuel(phaseId, killer:GetGUIDLow())
                return
            end
        end
    end
end
RegisterPlayerEvent(6, OnPlayerKilled)

-- End duel and process results
function DuelArena.EndDuel(phaseId, winnerGuid)
    local duel = DuelArena.ActiveDuels[phaseId]
    if not duel then return end
    
    duel.status = "finished"
    local winner, loser
    
    if winnerGuid == duel.player1:GetGUIDLow() then
        winner = duel.player1
        loser = duel.player2
    else
        winner = duel.player2
        loser = duel.player1
    end
    
    -- Calculate rating change
    local winnerRating = DuelArena.GetPlayerRating(winner)
    local loserRating = DuelArena.GetPlayerRating(loser)
    local ratingChange = DuelArena.CalculateElo(winnerRating, loserRating, true)
    
    -- Update ratings
    DuelArena.UpdateRating(winner, winnerRating + ratingChange)
    DuelArena.UpdateRating(loser, loserRating - ratingChange)
    
    -- Announce
    winner:SendBroadcastMessage("|cff00ff00Victory! Rating: " .. (winnerRating + ratingChange) .. " (+" .. ratingChange .. ")|r")
    loser:SendBroadcastMessage("|cffff0000Defeat. Rating: " .. (loserRating - ratingChange) .. " (-" .. ratingChange .. ")|r")
    
    -- Resurrect and full heal loser
    loser:ResurrectPlayer(100)
    winner:SetFullHealth()
    loser:SetFullHealth()
    
    -- Return to original positions after delay
    CreateLuaEvent(function()
        -- Reset phase
        duel.player1:SetPhaseMask(1, true)
        duel.player2:SetPhaseMask(1, true)
        
        -- Teleport back
        duel.player1:Teleport(duel.p1Return[1], duel.p1Return[2], duel.p1Return[3], duel.p1Return[4])
        duel.player2:Teleport(duel.p2Return[1], duel.p2Return[2], duel.p2Return[3], duel.p2Return[4])
        
        -- Cleanup
        DuelArena.ActiveDuels[phaseId] = nil
    end, 5000, 1)
end

-- Elo calculation
function DuelArena.CalculateElo(winnerRating, loserRating, isWinner)
    local K = 32  -- Rating adjustment factor
    local expected = 1 / (1 + 10^((loserRating - winnerRating) / 400))
    local change = math.floor(K * (1 - expected) + 0.5)
    return math.max(change, 1)  -- Minimum 1 rating change
end

-- Slash commands
local function HandleDuelCommand(player, command, args)
    if command == "duel" then
        if args == "queue" or args == "q" then
            DuelArena.QueuePlayer(player, "casual")
            return false
        elseif args == "rated" or args == "r" then
            DuelArena.QueuePlayer(player, "rated")
            return false
        elseif args == "leave" or args == "l" then
            DuelArena.LeaveQueue(player)
            return false
        elseif args == "rating" then
            local rating = DuelArena.GetPlayerRating(player)
            player:SendBroadcastMessage("Your duel rating: " .. rating)
            return false
        end
    end
    return true
end
RegisterPlayerEvent(42, HandleDuelCommand)
```

### Commands

| Command | Description |
|---------|-------------|
| `.duel queue` | Queue for casual duel |
| `.duel rated` | Queue for rated duel |
| `.duel leave` | Leave queue |
| `.duel rating` | Check your rating |
| `.duel challenge <name>` | Challenge specific player |
| `.duel top` | Show top 10 players |

---

## Client Addon (Optional)

```lua
-- DC-DuelArena addon
local DuelArenaUI = CreateFrame("Frame", "DCDuelArena", UIParent)
DuelArenaUI:SetSize(300, 200)
DuelArenaUI:SetPoint("CENTER")
DuelArenaUI:Hide()

-- Queue status display
-- Rating display
-- Leaderboard button
-- Spectate button (if implemented)

-- AIO message handlers
AIO.AddAddonMessage("DuelArena", function(player, action, data)
    if action == "UPDATE_QUEUE" then
        -- Update queue time display
    elseif action == "MATCH_FOUND" then
        -- Play sound, show arena name
    elseif action == "LEADERBOARD" then
        -- Display top players
    end
end)
```

---

## Implementation Phases

### Phase 1 (Days 1-3): Core System
- [ ] Database schema
- [ ] Eluna queue system
- [ ] Phasing and teleport logic
- [ ] Basic duel start/end handling

### Phase 2 (Days 4-5): Rating System
- [ ] Elo calculations
- [ ] Win/loss tracking
- [ ] Leaderboard queries
- [ ] Slash commands

### Phase 3 (Days 6-7): Polish
- [ ] Multiple arena support
- [ ] Countdown visuals
- [ ] Client addon (optional)
- [ ] Spectator mode (stretch goal)

---

## Rewards Integration

| Rating | Reward |
|--------|--------|
| 1600 | Title: "Duelist" |
| 1800 | Exclusive Transmog |
| 2000 | Mount: "Arena Champion" |
| 2200 | Title: "Gladiator" |
| 2400 | Unique Weapon Transmog |

### Seasonal Integration
- Rating resets with seasons
- End-of-season rewards based on peak rating
- Seasonal titles (Season X Gladiator)

---

## Success Metrics

- Queue times (target: <2 minutes)
- Daily duel count
- Rating distribution health
- Player retention in system

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Win trading | Detect pattern, limit same-opponent matches |
| Gear imbalance | Optional gear normalization mode |
| Low population | Expand rating range over time |
| Phase leaking | Thorough phase cleanup on disconnect |

---

**Recommendation:** Start with casual (unrated) duels to test phasing system. Add rated ladder once stable. Consider tournament mode as Phase 2 feature.
