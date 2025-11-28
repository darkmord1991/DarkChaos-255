# Dynamic World Events System

**Priority:** A7 (High Priority)  
**Effort:** Low (1 week)  
**Impact:** High  
**Base:** mod-weekendbonus + Custom Extensions

---

## Overview

Rotating world events that provide bonuses and activities. Events can be scheduled (daily, weekly) or triggered randomly, creating "reasons to log in today."

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Hotspots** | Events can activate special hotspots |
| **Seasonal System** | Season-exclusive events |
| **Mythic+** | M+ bonus events |
| **HLBG** | PvP event weekends |
| **Dungeon Quests** | Bonus dungeon rewards |

### Benefits
- Creates daily engagement
- Server feels alive and dynamic
- Easy to add new events
- Builds on existing mod-weekendbonus
- Low development effort

---

## Event Types

### 1. **Bonus Events**
- Double XP Weekend
- Double Token Rates
- Increased Drop Rates
- Reduced Repair Costs
- Bonus Honor/Arena Points

### 2. **Activity Events**
- World Boss Spawn
- Rare NPC Hunt
- Zone Invasion
- Treasure Hunt
- Dungeon Rush

### 3. **Community Events**
- Server-wide Goal (kill X bosses)
- Faction Competition
- Guild Challenge
- PvP Tournament Week

### 4. **Seasonal Events**
- Holiday Specials
- Season Launch Celebration
- End-of-Season Finale

---

## Implementation

### Database Schema
```sql
CREATE TABLE dc_world_events (
    event_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    event_name VARCHAR(100) NOT NULL,
    event_type ENUM('bonus', 'activity', 'community', 'seasonal') NOT NULL,
    description TEXT,
    
    -- Timing
    start_time TIMESTAMP NULL,
    end_time TIMESTAMP NULL,
    duration_hours INT UNSIGNED DEFAULT 24,
    recurrence ENUM('none', 'daily', 'weekly', 'monthly') DEFAULT 'none',
    day_of_week TINYINT UNSIGNED DEFAULT 0,  -- 0=Sunday, 6=Saturday
    
    -- Effects
    xp_multiplier FLOAT DEFAULT 1.0,
    token_multiplier FLOAT DEFAULT 1.0,
    drop_multiplier FLOAT DEFAULT 1.0,
    honor_multiplier FLOAT DEFAULT 1.0,
    
    -- Conditions
    min_level TINYINT UNSIGNED DEFAULT 1,
    max_level TINYINT UNSIGNED DEFAULT 255,
    affected_zones TEXT,  -- JSON array of zone IDs
    
    -- Status
    active BOOLEAN DEFAULT FALSE,
    priority TINYINT UNSIGNED DEFAULT 0,
    
    -- Announcements
    announce_start TEXT,
    announce_end TEXT,
    announce_interval INT UNSIGNED DEFAULT 3600  -- seconds
);

CREATE TABLE dc_event_schedule (
    schedule_id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    event_id INT UNSIGNED NOT NULL,
    scheduled_start TIMESTAMP NOT NULL,
    scheduled_end TIMESTAMP NOT NULL,
    executed BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (event_id) REFERENCES dc_world_events(event_id)
);

-- Sample events
INSERT INTO dc_world_events (event_name, event_type, xp_multiplier, recurrence, day_of_week, announce_start) VALUES
('Double XP Weekend', 'bonus', 2.0, 'weekly', 5, 'Double XP Weekend has begun! Enjoy 2x experience until Monday!'),
('Mythic Monday', 'bonus', 1.0, 'weekly', 1, 'Mythic Monday! All M+ dungeons drop bonus loot today!'),
('World Boss Wednesday', 'activity', 1.0, 'weekly', 3, 'World Boss Wednesday! A powerful foe has appeared in Azeroth!'),
('Token Tuesday', 'bonus', 1.5, 'weekly', 2, 'Token Tuesday! 50% bonus tokens from all sources!');
```

### Event Manager (C++)
```cpp
class WorldEventManager
{
public:
    static WorldEventManager* instance();
    
    // Event control
    void LoadEvents();
    void StartEvent(uint32 eventId);
    void EndEvent(uint32 eventId);
    void CheckScheduledEvents();
    
    // Active events
    std::vector<WorldEvent*> GetActiveEvents() const;
    bool IsEventActive(uint32 eventId) const;
    
    // Multipliers
    float GetXPMultiplier(Player* player) const;
    float GetTokenMultiplier(Player* player) const;
    float GetDropMultiplier(Player* player) const;
    
    // Announcements
    void AnnounceEvent(uint32 eventId, bool isStart);
    void ScheduleReminder(uint32 eventId, uint32 intervalSeconds);
    
private:
    std::unordered_map<uint32, WorldEvent> _events;
    std::set<uint32> _activeEvents;
    
    void ApplyEventEffects(uint32 eventId);
    void RemoveEventEffects(uint32 eventId);
};
```

### Eluna Integration
```lua
-- Event-aware XP hook
local function OnGainXP(event, player, amount, victim)
    local multiplier = GetActiveXPMultiplier()
    if multiplier > 1.0 then
        player:SendBroadcastMessage("|cFF00FF00[Event Bonus]|r +" .. ((multiplier - 1) * 100) .. "% XP!")
    end
    return math.floor(amount * multiplier)
end

-- Event-aware loot hook  
local function OnLootItem(event, player, item, count)
    local tokenMultiplier = GetActiveTokenMultiplier()
    if IsTokenItem(item:GetEntry()) and tokenMultiplier > 1.0 then
        local bonusTokens = math.floor(count * (tokenMultiplier - 1))
        if bonusTokens > 0 then
            player:AddItem(item:GetEntry(), bonusTokens)
            player:SendBroadcastMessage("|cFF00FF00[Event Bonus]|r +" .. bonusTokens .. " bonus tokens!")
        end
    end
end
```

---

## Weekly Schedule Example

| Day | Event | Bonus |
|-----|-------|-------|
| Monday | Mythic Monday | M+ bonus loot |
| Tuesday | Token Tuesday | +50% tokens |
| Wednesday | World Boss Wednesday | World boss spawns |
| Thursday | Dungeon Day | +25% dungeon XP |
| Friday | PvP Friday | +50% honor |
| Saturday | Double XP Weekend | 2x XP |
| Sunday | Double XP Weekend | 2x XP |

---

## Commands

### Player Commands
```
.event list           - Show all active events
.event info <id>      - Details about specific event
.event schedule       - Show upcoming events
```

### GM Commands
```
.event start <id>     - Manually start event
.event stop <id>      - Manually stop event
.event create         - Create new event (opens wizard)
.event modify <id>    - Modify event settings
.event delete <id>    - Delete event
.event reload         - Reload event database
```

---

## UI Component (AIO Addon)

```lua
-- Event Calendar
-- Shows weekly schedule with icons
-- Highlights active events
-- Countdown to next event
-- Event history log
```

---

## Configuration

```conf
# worldserver.conf
WorldEvents.Enable = 1
WorldEvents.AnnounceInterval = 3600    # Seconds between reminders
WorldEvents.MaxConcurrentEvents = 3    # Max active at once
WorldEvents.DefaultDuration = 24       # Hours
WorldEvents.ServerTimeZone = "UTC"     # For scheduling
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| EventManager C++ | 2 days |
| Multiplier hooks | 1 day |
| Eluna integration | 1 day |
| Sample events | 4 hours |
| AIO calendar addon | 1 day |
| Testing | 1 day |
| **Total** | **~1 week** |

---

## Future Enhancements

1. **Random Events** - Surprise events with no schedule
2. **Player-Triggered Events** - Guild events via tokens
3. **Cascading Events** - Events trigger other events
4. **Event Achievements** - Participate in X events
5. **Event Leaderboards** - Top performers during events
