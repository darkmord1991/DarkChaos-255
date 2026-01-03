# Mentor/Apprentice System

**Priority:** A6 (High Priority)  
**Effort:** Medium (2 weeks)  
**Impact:** High  
**Base:** Custom System (inspired by mod-recruitafriend)

---

## Overview

High-level players (mentors) can assist lower-level players (apprentices) and receive rewards for helping them progress. This creates a social bond, helps new players, and gives veterans something to do.

---

## Why It Fits DarkChaos-255

### Integration Points
| System | Integration |
|--------|-------------|
| **Prestige System** | Prestige 5+ required to mentor |
| **Seasonal System** | Season-specific mentorship rewards |
| **Item Upgrades** | Bonus upgrade tokens for mentors |
| **Dungeon Quests** | Bonus completion rewards when grouped |

### Benefits
- Helps new player retention
- Gives veterans purpose
- Builds community bonds
- Reduces "lonely leveling" problem
- Scales veteran down for balance

---

## Features

### 1. **Mentor Registration**
- Level 200+ and Prestige 1+ required
- Register as mentor via NPC or command
- Set availability status
- Choose mentoring specialties (PvP, PvE, Dungeons)

### 2. **Apprentice System**
- Any player under level 100 can request mentor
- Matched by specialty or manually chosen
- Limited to 3 active apprentices per mentor
- Progress tracking dashboard

### 3. **Mentor Scaling**
- Mentor scaled down to apprentice's level + 5
- Stats adjusted for balance
- Can still use abilities but damage normalized
- XP is shared (mentor gets reduced XP, apprentice gets bonus)

### 4. **Reward Structure**
- Mentor tokens for milestone completions
- Bonus when apprentice reaches level caps
- Seasonal mentorship achievements
- Exclusive mentor titles and cosmetics

---

## Implementation

### Database Schema
```sql
CREATE TABLE dc_mentors (
    guid INT UNSIGNED PRIMARY KEY,
    mentor_level TINYINT UNSIGNED DEFAULT 1,
    total_apprentices INT UNSIGNED DEFAULT 0,
    active_apprentices TINYINT UNSIGNED DEFAULT 0,
    specialty ENUM('pve', 'pvp', 'dungeons', 'all') DEFAULT 'all',
    available BOOLEAN DEFAULT TRUE,
    total_levels_mentored INT UNSIGNED DEFAULT 0,
    mentor_rating FLOAT DEFAULT 5.0,
    registered_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE dc_apprentices (
    apprentice_guid INT UNSIGNED PRIMARY KEY,
    mentor_guid INT UNSIGNED NOT NULL,
    start_level TINYINT UNSIGNED NOT NULL,
    current_level TINYINT UNSIGNED NOT NULL,
    start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    graduated BOOLEAN DEFAULT FALSE,
    graduation_date TIMESTAMP NULL,
    rating_given TINYINT UNSIGNED DEFAULT 0,
    FOREIGN KEY (mentor_guid) REFERENCES dc_mentors(guid)
);

CREATE TABLE dc_mentor_rewards (
    milestone VARCHAR(50) PRIMARY KEY,
    reward_type ENUM('item', 'currency', 'title', 'mount'),
    reward_id INT UNSIGNED NOT NULL,
    reward_count INT UNSIGNED DEFAULT 1
);

-- Sample rewards
INSERT INTO dc_mentor_rewards VALUES
('first_apprentice', 'title', 500, 1),           -- Title: "Guide"
('apprentice_to_80', 'currency', 1, 50),         -- 50 Mentor Tokens
('apprentice_to_255', 'currency', 1, 200),       -- 200 Mentor Tokens
('10_graduates', 'mount', 50000, 1),             -- Exclusive Mount
('50_graduates', 'title', 501, 1);               -- Title: "Master Mentor"
```

### C++ Mentor Manager
```cpp
// MentorSystem.h
class MentorManager
{
public:
    static MentorManager* instance();
    
    // Mentor operations
    bool RegisterMentor(Player* player);
    bool UnregisterMentor(Player* player);
    bool SetMentorAvailability(Player* mentor, bool available);
    
    // Apprentice operations
    bool RequestMentor(Player* apprentice, ObjectGuid mentorGuid = ObjectGuid::Empty);
    bool AcceptApprentice(Player* mentor, Player* apprentice);
    bool GraduateApprentice(Player* apprentice);
    
    // Scaling
    void ApplyMentorScaling(Player* mentor, Player* apprentice);
    void RemoveMentorScaling(Player* mentor);
    
    // Rewards
    void CheckMilestones(Player* mentor, Player* apprentice, uint8 newLevel);
    void GrantMentorReward(Player* mentor, const std::string& milestone);
    
    // Queries
    bool IsMentor(ObjectGuid guid) const;
    bool HasMentor(ObjectGuid guid) const;
    ObjectGuid GetMentor(ObjectGuid apprenticeGuid) const;
    std::vector<ObjectGuid> GetApprentices(ObjectGuid mentorGuid) const;
    
private:
    std::unordered_map<ObjectGuid, MentorData> _mentors;
    std::unordered_map<ObjectGuid, ObjectGuid> _apprenticeToMentor;
};

#define sMentorMgr MentorManager::instance()
```

### Eluna Hooks
```lua
-- Mentor XP sharing
local function OnGainXP(event, player, amount, victim)
    local mentorGuid = GetMentor(player:GetGUIDLow())
    if mentorGuid then
        -- Apprentice gets 20% bonus XP when mentor nearby
        local mentor = GetPlayerByGUID(mentorGuid)
        if mentor and player:GetDistance(mentor) < 100 then
            return amount * 1.2  -- 20% bonus
        end
    end
    return amount
end

-- Mentor level check
local function OnLevelChange(event, player, oldLevel)
    local mentorGuid = GetMentor(player:GetGUIDLow())
    if mentorGuid then
        CheckMentorMilestone(mentorGuid, player:GetGUIDLow(), player:GetLevel())
    end
end
```

---

## Mentor Levels

| Level | Requirement | Perks |
|-------|-------------|-------|
| 1 | First registration | 1 apprentice slot |
| 2 | 5 graduates | 2 apprentice slots |
| 3 | 15 graduates | 3 apprentice slots, title |
| 4 | 30 graduates | 3 slots + bonus tokens |
| 5 | 50 graduates | 3 slots + mount + max rewards |

---

## Commands

### Mentor Commands
```
.mentor register         - Register as mentor
.mentor unregister       - Remove mentor status
.mentor status           - Show your mentor stats
.mentor available        - Toggle availability
.mentor apprentices      - List your apprentices
.mentor kick <name>      - Remove an apprentice
```

### Apprentice Commands
```
.apprentice find         - List available mentors
.apprentice request <n>  - Request specific mentor
.apprentice status       - Show your mentorship
.apprentice leave        - Leave mentorship
.apprentice rate <1-5>   - Rate your mentor on graduation
```

---

## UI Components (AIO Addon)

```lua
-- Mentor Dashboard
-- Shows: Active apprentices, progress bars, milestones
-- Apprentice Finder
-- Shows: Available mentors, specialties, ratings
-- Graduation Certificate
-- Celebratory popup when apprentice reaches 255
```

---

## Timeline

| Task | Duration |
|------|----------|
| Database schema | 2 hours |
| C++ MentorManager | 3 days |
| Scaling system | 2 days |
| Reward system | 1 day |
| Eluna hooks | 1 day |
| AIO addon UI | 2 days |
| Testing | 2 days |
| **Total** | **~2 weeks** |

---

## Future Enhancements

1. **Mentor Chat Channel** - Dedicated channel for mentors
2. **Mentor Quests** - Special quests for mentor-apprentice pairs
3. **Mentor Leaderboard** - Top mentors displayed
4. **Specialization Training** - Mentors teach class-specific tips
5. **Graduation Ceremony** - Server-wide announcement
