# Weekend Events System

**Priority:** S2 - High Priority  
**Effort:** Low (1 week)  
**Impact:** High  
**Base:** Custom Eluna with scheduled tasks

---

## Overview

A Weekend Events System provides rotating bonuses and special content on weekends (or other scheduled times). This includes XP bonuses, reputation bonuses, specific dungeon/raid bonuses, PvP events, and special activities. The system creates predictable excitement and gives players reasons to log in during specific times.

---

## Why It Fits DarkChaos-255

### Player Engagement Value
- Creates "appointment gaming" moments
- Drives population peaks on weekends
- Provides variety and excitement
- Helps catch-up mechanics (bonus XP/rep)

### Funserver Appeal
- Custom events unique to DarkChaos
- Enhances existing content without new development
- Easy to implement, high impact
- Flexible for seasonal tie-ins

### Synergies
| System | Integration |
|--------|-------------|
| **Seasonal** | Season-themed events |
| **Mythic+** | Mythic+ Bonus Weekend |
| **HLBG** | HLBG Bonus Weekend |
| **Item Upgrade** | Upgrade Material Bonus |

---

## Feature Highlights

### Event Types

1. **Bonus Weekends**
   - Timewalking-style bonuses
   - Reputation bonus
   - Profession bonus
   - Honor/Arena points bonus

2. **Dungeon Events**
   - Specific dungeon spotlight
   - Bonus loot/emblems
   - Achievement hunting weekends

3. **World Events**
   - World boss spawns
   - Invasion events
   - Treasure hunting

4. **PvP Events**
   - Arena Skirmish Bonus
   - Battleground Bonus
   - World PvP Event
   - HLBG Tournament

5. **Custom DarkChaos Events**
   - Mythic+ Push Week
   - Mount Collector's Weekend
   - Alt Leveling Weekend
   - Transmog Unlocking Event

### Sample Event Calendar

| Week | Event | Bonus |
|------|-------|-------|
| 1 | Mythic+ Push Week | +50% M+ currency, extra chest loot |
| 2 | Reputation Bonus | +100% rep gains all factions |
| 3 | HLBG Tournament | Double rating gains, special rewards |
| 4 | Timewalking: Classic | Classic dungeons, scaled rewards |
| 5 | World Boss Week | 3 world bosses spawn daily |
| 6 | Profession Bonus | +50% skill gains, extra mats |
| 7 | Battleground Bonus | +100% honor, bonus marks |
| 8 | Alt Leveling | +200% XP, heirloom vendor discount |

---

## Technical Implementation

### Database Schema

```sql
-- Event definitions
CREATE TABLE dc_weekend_events (
    event_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_name VARCHAR(100),
    event_description TEXT,
    event_type ENUM('bonus', 'dungeon', 'pvp', 'world', 'custom'),
    
    -- Bonus multipliers
    xp_multiplier FLOAT DEFAULT 1.0,
    rep_multiplier FLOAT DEFAULT 1.0,
    honor_multiplier FLOAT DEFAULT 1.0,
    drop_multiplier FLOAT DEFAULT 1.0,
    gold_multiplier FLOAT DEFAULT 1.0,
    profession_multiplier FLOAT DEFAULT 1.0,
    
    -- Special flags
    special_flags JSON,  -- Custom data for event scripts
    icon_id INT UNSIGNED DEFAULT 0,
    color_code VARCHAR(8) DEFAULT 'FFFFFF',
    
    -- Activation
    is_active TINYINT DEFAULT 1,
    priority INT DEFAULT 0  -- Higher = takes precedence
);

-- Event schedule
CREATE TABLE dc_weekend_event_schedule (
    schedule_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id INT UNSIGNED,
    
    -- Time-based (for regular weekends)
    day_of_week TINYINT,  -- 0=Sunday, 6=Saturday, NULL=date-based
    start_hour TINYINT DEFAULT 0,
    end_hour TINYINT DEFAULT 23,
    
    -- Date-based (for special events)
    start_date DATE NULL,
    end_date DATE NULL,
    
    -- Season integration
    season_id INT UNSIGNED NULL,  -- Only active during specific season
    
    FOREIGN KEY (event_id) REFERENCES dc_weekend_events(event_id)
);

-- Active events cache (for performance)
CREATE TABLE dc_active_events (
    event_id INT UNSIGNED PRIMARY KEY,
    event_name VARCHAR(100),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ends_at TIMESTAMP,
    INDEX idx_ends_at (ends_at)
);

-- Event history (for analytics)
CREATE TABLE dc_event_history (
    history_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id INT UNSIGNED,
    event_name VARCHAR(100),
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    player_participation INT DEFAULT 0,
    
    INDEX idx_event_id (event_id),
    INDEX idx_dates (started_at, ended_at)
);

-- Sample event data
INSERT INTO dc_weekend_events 
(event_name, event_description, event_type, xp_multiplier, rep_multiplier, honor_multiplier, special_flags) 
VALUES
('Mythic+ Push Week', 'Bonus rewards for Mythic+ dungeons!', 'dungeon', 1.0, 1.0, 1.0, 
 '{"mplus_currency_bonus": 1.5, "extra_chest_loot": true}'),
('Reputation Bonus Weekend', 'All reputation gains doubled!', 'bonus', 1.0, 2.0, 1.0, NULL),
('HLBG Tournament', 'Compete for glory in Hinterland!', 'pvp', 1.0, 1.0, 2.0,
 '{"hlbg_rating_bonus": 2.0, "special_title": "Weekend Warrior"}'),
('Timewalking: Classic', 'Revisit classic dungeons for scaled rewards.', 'dungeon', 1.0, 1.0, 1.0,
 '{"dungeons": [34, 36, 43, 47, 48], "scaled_loot": true}'),
('World Boss Week', 'Powerful world bosses spawn across Azeroth.', 'world', 1.0, 1.0, 1.0,
 '{"boss_spawns": [16, 17, 18, 19], "spawn_interval": 7200}'),
('Profession Bonus Weekend', 'Craft more efficiently!', 'bonus', 1.0, 1.0, 1.0,
 '{"skill_gain_bonus": 1.5, "extra_craft_chance": 0.25}'),
('Battleground Bonus Weekend', 'Earn extra honor in battlegrounds!', 'pvp', 1.0, 1.0, 2.0,
 '{"bonus_marks": true}'),
('Alt Leveling Weekend', 'Level up your alts faster!', 'bonus', 3.0, 1.5, 1.0,
 '{"heirloom_discount": 0.5}');

-- Schedule events (weekend = Saturday/Sunday)
INSERT INTO dc_weekend_event_schedule (event_id, day_of_week, start_hour, end_hour) VALUES
(1, 5, 18, 23), (1, 6, 0, 23), (1, 0, 0, 23),  -- M+ Push: Fri 6pm - Sun midnight
(2, 6, 0, 23), (2, 0, 0, 23),                   -- Rep bonus: Sat-Sun
(3, 6, 14, 22),                                  -- HLBG Tournament: Sat afternoon
(4, 6, 0, 23), (4, 0, 0, 23),                   -- Timewalking: Sat-Sun
(5, 5, 20, 23), (5, 6, 0, 23), (5, 0, 0, 20);  -- World Boss: Fri-Sun
```

### Eluna Event Manager

```lua
-- Weekend Event Manager
local EventManager = {}
EventManager.ActiveEvents = {}
EventManager.EventBonuses = {}

-- Check and activate events (run every minute)
function EventManager.UpdateActiveEvents()
    local now = os.time()
    local currentDay = tonumber(os.date("%w", now))  -- 0-6, Sunday=0
    local currentHour = tonumber(os.date("%H", now))
    
    -- Query scheduled events for today
    local query = CharDBQuery([[
        SELECT e.event_id, e.event_name, e.event_type,
               e.xp_multiplier, e.rep_multiplier, e.honor_multiplier,
               e.drop_multiplier, e.gold_multiplier, e.profession_multiplier,
               e.special_flags
        FROM dc_weekend_events e
        JOIN dc_weekend_event_schedule s ON e.event_id = s.event_id
        WHERE e.is_active = 1
          AND (s.day_of_week = ]] .. currentDay .. [[ OR s.day_of_week IS NULL)
          AND (s.start_hour IS NULL OR s.start_hour <= ]] .. currentHour .. [[)
          AND (s.end_hour IS NULL OR s.end_hour >= ]] .. currentHour .. [[)
          AND (s.start_date IS NULL OR s.start_date <= CURDATE())
          AND (s.end_date IS NULL OR s.end_date >= CURDATE())
    ]])
    
    local newActive = {}
    if query then
        repeat
            local eventId = query:GetUInt32(0)
            local eventName = query:GetString(1)
            
            newActive[eventId] = {
                id = eventId,
                name = eventName,
                type = query:GetString(2),
                xpMult = query:GetFloat(3),
                repMult = query:GetFloat(4),
                honorMult = query:GetFloat(5),
                dropMult = query:GetFloat(6),
                goldMult = query:GetFloat(7),
                profMult = query:GetFloat(8),
                specialFlags = query:GetString(9)
            }
            
            -- Announce new events
            if not EventManager.ActiveEvents[eventId] then
                EventManager.AnnounceEventStart(eventName)
            end
        until not query:NextRow()
    end
    
    -- Check for ended events
    for eventId, event in pairs(EventManager.ActiveEvents) do
        if not newActive[eventId] then
            EventManager.AnnounceEventEnd(event.name)
        end
    end
    
    EventManager.ActiveEvents = newActive
    EventManager.RecalculateBonuses()
end

-- Calculate combined bonuses from all active events
function EventManager.RecalculateBonuses()
    local bonuses = {
        xp = 1.0,
        rep = 1.0,
        honor = 1.0,
        drop = 1.0,
        gold = 1.0,
        profession = 1.0
    }
    
    for _, event in pairs(EventManager.ActiveEvents) do
        bonuses.xp = bonuses.xp * event.xpMult
        bonuses.rep = bonuses.rep * event.repMult
        bonuses.honor = bonuses.honor * event.honorMult
        bonuses.drop = bonuses.drop * event.dropMult
        bonuses.gold = bonuses.gold * event.goldMult
        bonuses.profession = bonuses.profession * event.profMult
    end
    
    EventManager.EventBonuses = bonuses
end

-- Get current bonus for a type
function EventManager.GetBonus(bonusType)
    return EventManager.EventBonuses[bonusType] or 1.0
end

-- Check if specific event type is active
function EventManager.IsEventTypeActive(eventType)
    for _, event in pairs(EventManager.ActiveEvents) do
        if event.type == eventType then
            return true, event
        end
    end
    return false, nil
end

-- Announcements
function EventManager.AnnounceEventStart(eventName)
    SendWorldMessage("|cff00ff00[Weekend Event]|r " .. eventName .. " has begun!")
end

function EventManager.AnnounceEventEnd(eventName)
    SendWorldMessage("|cffff0000[Weekend Event]|r " .. eventName .. " has ended.")
end

-- Slash command for event info
local function EventInfoCommand(player, command, args)
    if command ~= "events" and command ~= "event" then
        return true
    end
    
    if next(EventManager.ActiveEvents) == nil then
        player:SendBroadcastMessage("|cff888888No events are currently active.|r")
    else
        player:SendBroadcastMessage("|cff00ff00=== Active Events ===|r")
        for _, event in pairs(EventManager.ActiveEvents) do
            player:SendBroadcastMessage("  • " .. event.name)
        end
        
        -- Show bonuses
        local b = EventManager.EventBonuses
        if b.xp > 1 then player:SendBroadcastMessage("  XP Bonus: +" .. ((b.xp - 1) * 100) .. "%") end
        if b.rep > 1 then player:SendBroadcastMessage("  Rep Bonus: +" .. ((b.rep - 1) * 100) .. "%") end
        if b.honor > 1 then player:SendBroadcastMessage("  Honor Bonus: +" .. ((b.honor - 1) * 100) .. "%") end
    end
    
    return false
end
RegisterPlayerEvent(42, EventInfoCommand)

-- Hook: XP gains
local function OnGiveXP(event, player, amount, victim)
    local mult = EventManager.GetBonus("xp")
    if mult > 1 then
        local bonus = math.floor(amount * (mult - 1))
        return amount + bonus
    end
    return amount
end
RegisterPlayerEvent(12, OnGiveXP)

-- Hook: Reputation gains
local function OnRepChange(event, player, factionId, standing, incremental)
    if incremental and incremental > 0 then
        local mult = EventManager.GetBonus("rep")
        if mult > 1 then
            local bonus = math.floor(incremental * (mult - 1))
            player:SetReputation(factionId, standing + bonus)
        end
    end
end
RegisterPlayerEvent(31, OnRepChange)

-- Hook: Honor gains (PvP kill)
local function OnPvPKill(event, killer, killed)
    local mult = EventManager.GetBonus("honor")
    if mult > 1 then
        -- Award bonus honor
        local baseHonor = 20  -- Approximate base honor
        local bonus = math.floor(baseHonor * (mult - 1))
        killer:ModifyHonorPoints(bonus)
        killer:SendBroadcastMessage("|cff00ff00+" .. bonus .. " bonus honor (Weekend Event)|r")
    end
end
RegisterPlayerEvent(6, OnPvPKill)

-- Update loop (every 60 seconds)
CreateLuaEvent(function()
    EventManager.UpdateActiveEvents()
end, 60000, 0)

-- Initial update on server start
EventManager.UpdateActiveEvents()
```

### Login Notification

```lua
-- Notify players of active events on login
local function OnLogin(event, player)
    if next(EventManager.ActiveEvents) ~= nil then
        -- Delay to not spam with other login messages
        player:RegisterEvent(function()
            player:SendBroadcastMessage("|cff00ff00[Weekend Event]|r Active events:")
            for _, evt in pairs(EventManager.ActiveEvents) do
                player:SendBroadcastMessage("  • " .. evt.name)
            end
            player:SendBroadcastMessage("Type |cff00ff00.events|r for details.")
        end, 3000, 1)
    end
end
RegisterPlayerEvent(3, OnLogin)
```

### Client Addon (Optional)

```lua
-- DC-Events addon
local EventFrame = CreateFrame("Frame", "DCEvents", UIParent)
EventFrame:SetSize(250, 150)
EventFrame:SetPoint("TOP", UIParent, "TOP", 0, -20)

-- Create event display
local header = EventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOP", 0, -10)
header:SetText("|cff00ff00Weekend Events|r")

local eventText = EventFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
eventText:SetPoint("TOP", header, "BOTTOM", 0, -5)
eventText:SetJustifyH("CENTER")

-- Handle AIO updates
AIO.AddAddonMessage("DC-Events", function(player, action, data)
    if action == "UPDATE" then
        local events = {}
        for _, e in ipairs(data.events or {}) do
            table.insert(events, "• " .. e.name)
        end
        eventText:SetText(table.concat(events, "\n"))
        
        -- Show bonuses
        -- ...
    end
end)

-- Toggle visibility
SLASH_DCEVENT1 = "/events"
SlashCmdList["DCEVENT"] = function()
    if EventFrame:IsShown() then
        EventFrame:Hide()
    else
        EventFrame:Show()
    end
end
```

---

## Event Ideas

### Rotation 1: Standard Events

| Week | Event | Details |
|------|-------|---------|
| 1 | Mythic+ Push | Extra M+ currency, leaderboard prizes |
| 2 | Reputation | Double rep, featured faction |
| 3 | PvP Weekend | Double honor, HLBG focus |
| 4 | Timewalking | Classic dungeons spotlight |

### Rotation 2: Special Events

| Event | Timing | Details |
|-------|--------|---------|
| World Boss Invasion | Monthly | World bosses with unique drops |
| Treasure Hunt | Bi-weekly | Hidden treasures spawn |
| Transmog Runway | Monthly | Fashion competition |
| Racing Weekend | Monthly | Vehicle races |

### Seasonal Integration

```sql
-- Season-specific event (only active during Season 1)
INSERT INTO dc_weekend_event_schedule 
(event_id, day_of_week, season_id) VALUES
(10, 6, 1),  -- Special Season 1 Saturday event
(10, 0, 1);  -- And Sunday
```

---

## Implementation Phases

### Phase 1 (Days 1-2): Core System
- [ ] Database schema
- [ ] Event manager Eluna script
- [ ] Basic bonus hooks (XP, Rep, Honor)
- [ ] Slash command

### Phase 2 (Days 3-4): Event Types
- [ ] Dungeon spotlight events
- [ ] World boss spawning
- [ ] PvP event integration
- [ ] Login notifications

### Phase 3 (Days 5-7): Polish & Calendar
- [ ] Schedule initial rotation
- [ ] Client addon (optional)
- [ ] Admin commands
- [ ] Analytics tracking

---

## Admin Commands

| Command | Description |
|---------|-------------|
| `.event start <id>` | Force-start an event |
| `.event stop <id>` | Force-stop an event |
| `.event list` | List all events |
| `.event active` | List active events |
| `.event schedule` | View upcoming schedule |

---

## Success Metrics

- Weekend login increase
- Event participation rates
- Content engagement during events
- Player feedback scores

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Event fatigue | Rotate events, keep fresh |
| Economy impact | Careful with drop/gold bonuses |
| Server load | World boss spawn limits |
| Missed events | Add catch-up events |

---

**Recommendation:** Start with simple bonus weekends (XP, Rep, Honor). Add dungeon spotlights and world bosses after initial system is stable. Track which events drive most engagement and adjust rotation accordingly.
