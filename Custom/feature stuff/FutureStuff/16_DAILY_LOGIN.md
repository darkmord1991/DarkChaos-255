# Daily Login Rewards System

**Priority:** S1 (Critical - Quick Win)  
**Effort:** Very Low (2-3 days)  
**Impact:** High  
**Base:** Custom Eluna Script

---

## Overview

A daily login reward system that encourages players to log in every day. Players receive escalating rewards for consecutive logins, with bonus rewards for weekly and monthly streaks.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Seasonal System** | Season-specific bonus rewards |
| **Item Upgrades** | Upgrade tokens as rewards |
| **Mythic+** | M+ keystones or tokens |
| **Prestige** | Prestige bonus multiplier |

### Benefits
- Increases daily active users
- Simple retention mechanic
- Low development effort
- Encourages habit formation
- Can tie into existing token system

---

## Features

### 1. **Daily Reward Tiers**
```
Day 1:  Bronze Token x5
Day 2:  Silver Token x2
Day 3:  Gold Token x1
Day 4:  Bronze Token x10
Day 5:  Upgrade Token x1
Day 6:  Random Mount Chance (1%)
Day 7:  Weekly Chest (Epic Quality)
```

### 2. **Streak Bonuses**
- 7-day streak: +10% XP buff (1 hour)
- 14-day streak: Choice of mount or pet
- 28-day streak: Exclusive title
- 30-day streak: Mythic+ Keystone

### 3. **Seasonal Integration**
- Season-specific rewards during active seasons
- Bonus seasonal currency
- Exclusive seasonal cosmetics at milestones

---

## Implementation

### Database Schema
```sql
CREATE TABLE dc_daily_login (
    guid INT UNSIGNED PRIMARY KEY,
    last_login DATE NOT NULL,
    current_streak INT UNSIGNED DEFAULT 0,
    longest_streak INT UNSIGNED DEFAULT 0,
    total_logins INT UNSIGNED DEFAULT 0,
    last_claimed_day TINYINT UNSIGNED DEFAULT 0,
    monthly_progress INT UNSIGNED DEFAULT 0,
    season_id INT UNSIGNED DEFAULT 0
);

CREATE TABLE dc_daily_rewards (
    day_number TINYINT UNSIGNED PRIMARY KEY,
    reward_type ENUM('item', 'currency', 'buff', 'title', 'mount'),
    reward_id INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1,
    bonus_chance FLOAT DEFAULT 0,
    bonus_reward_id INT UNSIGNED DEFAULT 0
);
```

### Eluna Script Structure
```lua
-- Daily Login Handler
local DailyLogin = {}

function DailyLogin.OnLogin(event, player)
    local guid = player:GetGUIDLow()
    local today = os.date("%Y-%m-%d")
    
    -- Check if already claimed today
    local query = CharDBQuery("SELECT last_login, current_streak FROM dc_daily_login WHERE guid = " .. guid)
    
    if query then
        local lastLogin = query:GetString(0)
        local streak = query:GetUInt32(1)
        
        if lastLogin == today then
            -- Already claimed
            return
        elseif IsConsecutiveDay(lastLogin, today) then
            -- Streak continues
            streak = streak + 1
        else
            -- Streak broken
            streak = 1
        end
        
        GiveReward(player, streak)
        UpdateDatabase(guid, today, streak)
    else
        -- First login ever
        CreateNewEntry(guid, today)
        GiveReward(player, 1)
    end
end

RegisterPlayerEvent(3, DailyLogin.OnLogin) -- PLAYER_EVENT_ON_LOGIN
```

### AIO Addon UI
```lua
-- Client-side reward display
local DailyLoginFrame = CreateFrame("Frame", "DCDailyLogin", UIParent)
DailyLoginFrame:SetSize(400, 300)
DailyLoginFrame:SetPoint("CENTER")

-- Show calendar-style reward grid
-- Highlight current day
-- Show streak progress
-- Animate reward claim
```

---

## Reward Configuration

### Week 1 Rewards
| Day | Reward | Amount |
|-----|--------|--------|
| 1 | Bronze Token | 5 |
| 2 | Silver Token | 2 |
| 3 | 30-min XP Buff | 1 |
| 4 | Bronze Token | 10 |
| 5 | Upgrade Token | 1 |
| 6 | Random Pet | 5% chance |
| 7 | Weekly Chest | 1 |

### Milestone Rewards
| Streak | Reward |
|--------|--------|
| 7 days | Title: "Dedicated" |
| 14 days | Choice: Mount OR 50 Gold Tokens |
| 21 days | Exclusive Transmog Set Piece |
| 28 days | Title: "Devoted" + M+ Keystone |
| 30 days | Monthly Chest (Legendary chance) |

---

## Commands

```
.daily info          - Show current streak and rewards
.daily claim         - Claim today's reward (if not auto)
.daily calendar      - Open reward calendar UI
.daily leaderboard   - Show top streaks on server
```

---

## GM Commands

```
.daily reset <player>           - Reset player's streak
.daily grant <player> <days>    - Add days to streak
.daily reload                   - Reload reward config
```

---

## Configuration

```lua
-- worldserver.conf additions
DailyLogin.Enable = 1
DailyLogin.AutoClaim = 1           -- Auto-claim on login
DailyLogin.StreakGracePeriod = 0   -- Hours past midnight before streak breaks
DailyLogin.ShowUI = 1              -- Show UI popup on login
DailyLogin.AnnounceStreak = 1      -- Announce milestone streaks
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 1 hour |
| Core Eluna script | 4 hours |
| Reward configuration | 2 hours |
| AIO addon UI | 4 hours |
| Testing | 4 hours |
| **Total** | **~2 days** |

---

## Future Enhancements

1. **Catch-up Mechanic** - Buy missed days with tokens
2. **VIP Bonus** - Donors get bonus rewards
3. **Referral Bonus** - Bonus for logging in with referred friends
4. **Guild Streak** - Guild-wide streak bonuses
5. **Event Multipliers** - 2x rewards during events
