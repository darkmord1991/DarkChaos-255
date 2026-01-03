# Battle Pass System

**Priority:** S1 (Highest)  
**Effort:** Medium (4-6 weeks)  
**Impact:** Very High  
**Client Required:** AIO Addon UI only

---

## Overview

A modern engagement system inspired by retail games and successful private servers. Players progress through tiers by completing activities, earning rewards from free and optional premium tracks.

---

## Why This Feature?

### Player Psychology
- **Daily Engagement**: Gives players a reason to log in every day
- **Clear Progression**: Visual progress bar satisfies completionist urges
- **FOMO Prevention**: Limited-time rewards create urgency
- **Value Perception**: Even free track feels rewarding

### Competitor Examples
- **Torment WoW**: First WoW private server with battle pass (2024)
- **Fortnite/CoD**: Industry standard for player retention
- **Path of Exile**: Challenge leagues with MTX rewards

### DC Synergy
- Integrates with existing **Seasonal System**
- Rewards can include **M+ tokens**, **upgrade materials**
- Drives participation in **HLBG**, **dungeons**, **world content**

---

## Feature Specification

### Core Mechanics

```
BATTLE PASS STRUCTURE
├── Season Duration: 90 days (matches DC seasons)
├── Total Tiers: 100
├── XP per Tier: 1000 Battle Pass XP
├── Daily XP Cap: 3000 (prevents burnout, ~30 tiers/month)
└── Catch-up: +50% XP in final 30 days
```

### XP Sources

| Activity | XP Reward | Daily Limit |
|----------|-----------|-------------|
| Daily Login | 100 | 1/day |
| First Win (Dungeon) | 200 | 1/day |
| First Win (BG) | 200 | 1/day |
| M+ Completion | 100-500 | No limit |
| HLBG Participation | 150 | No limit |
| World Boss Kill | 300 | Per boss |
| Weekly Quest | 500 | Varies |
| Seasonal Challenge | 1000 | Unique |

### Reward Tracks

**Free Track (All Players):**
- Tier 1: 1000 Gold
- Tier 5: XP Boost Token (1 hour)
- Tier 10: Unique Title: "Pathfinder"
- Tier 20: M+ Entry Token x3
- Tier 30: Upgrade Token (Tier 1)
- Tier 40: Transmog Set (Recolor)
- Tier 50: Mount (Ground)
- Tier 60: Upgrade Token (Tier 2)
- Tier 70: Pet Companion
- Tier 80: Mount (Flying)
- Tier 90: Upgrade Token (Tier 3)
- Tier 100: Prestige Title + Unique Aura

**Premium Track (Optional - Vote/Donate Incentive):**
- Tier 1: +10% Season XP
- Tier 10: Exclusive Transmog
- Tier 25: Unique Tabard
- Tier 50: Exclusive Mount Skin
- Tier 75: Profile Frame
- Tier 100: Legendary Transmog + Title

---

## Technical Implementation

### Database Schema

```sql
-- Player battle pass progress
CREATE TABLE `dc_battlepass_progress` (
    `guid` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `current_tier` INT UNSIGNED DEFAULT 0,
    `current_xp` INT UNSIGNED DEFAULT 0,
    `total_xp` INT UNSIGNED DEFAULT 0,
    `is_premium` TINYINT(1) DEFAULT 0,
    `claimed_tiers` BLOB, -- Bitmask of claimed rewards
    `last_login_bonus` DATETIME,
    PRIMARY KEY (`guid`, `season_id`)
);

-- Battle pass tier rewards
CREATE TABLE `dc_battlepass_rewards` (
    `tier` INT UNSIGNED NOT NULL,
    `season_id` INT UNSIGNED NOT NULL,
    `track` ENUM('free', 'premium') NOT NULL,
    `reward_type` ENUM('item', 'title', 'mount', 'gold', 'token', 'spell'),
    `reward_id` INT UNSIGNED NOT NULL,
    `reward_count` INT UNSIGNED DEFAULT 1,
    PRIMARY KEY (`tier`, `season_id`, `track`)
);

-- Daily/weekly challenges
CREATE TABLE `dc_battlepass_challenges` (
    `challenge_id` INT UNSIGNED AUTO_INCREMENT,
    `season_id` INT UNSIGNED NOT NULL,
    `type` ENUM('daily', 'weekly', 'seasonal'),
    `description` VARCHAR(255),
    `objective_type` VARCHAR(50),
    `objective_count` INT UNSIGNED,
    `xp_reward` INT UNSIGNED,
    `is_active` TINYINT(1) DEFAULT 1,
    PRIMARY KEY (`challenge_id`)
);
```

### Server Components

```cpp
// BattlePassMgr.h
class BattlePassMgr
{
public:
    static BattlePassMgr* Instance();
    
    void LoadFromDB();
    void AddXP(Player* player, uint32 amount, std::string source);
    void ClaimReward(Player* player, uint32 tier, bool premium);
    void CheckDailyLogin(Player* player);
    void ProcessChallenge(Player* player, ChallengeType type, uint32 param);
    
    uint32 GetCurrentTier(Player* player);
    uint32 GetXPForTier(uint32 tier);
    bool HasClaimedReward(Player* player, uint32 tier, bool premium);

private:
    std::unordered_map<ObjectGuid, BattlePassData> _playerProgress;
    std::vector<BattlePassReward> _rewards;
    std::vector<BattlePassChallenge> _challenges;
};
```

### AIO Addon UI

```lua
-- Battle Pass UI Elements
-- Main progress bar
-- Tier carousel with rewards
-- Current/next tier display
-- Challenge list panel
-- Claim buttons per tier
```

---

## Integration Points

| System | Integration |
|--------|-------------|
| **Seasonal System** | BP resets with seasons, season theme affects rewards |
| **Mythic+ System** | M+ completion grants BP XP based on key level |
| **HLBG** | Participation/wins grant BP XP |
| **Dungeon Quests** | Quest completion grants BP XP |
| **World Bosses** | Kill grants significant BP XP |
| **Prestige** | Prestige levels grant BP tier skips |

---

## UI Mockup Concept

```
┌─────────────────────────────────────────────────────────────┐
│  SEASON 5 BATTLE PASS                    Tier 42 / 100     │
├─────────────────────────────────────────────────────────────┤
│  [████████████████████░░░░░░░░░░░] 735 / 1000 XP           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    ◄ [40]   [41]   [42]   [43]   [44]   [45] ►             │
│       ✓      ✓     ◉      ○      ○      ○                  │
│      Gold   Token  ???   Mount  Title   Gem                │
│                                                             │
│  ─────── FREE TRACK ───────                                │
│  Tier 42: [Seasonal Transmog Helm]        [CLAIM]          │
│                                                             │
│  ─────── PREMIUM TRACK ───────                             │
│  Tier 42: [Exclusive Shoulder Effect]     [🔒 LOCKED]      │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  TODAY'S CHALLENGES                                         │
│  [✓] Complete 1 Dungeon              +200 XP               │
│  [ ] Win 2 Battlegrounds             +300 XP               │
│  [ ] Kill 50 Enemies in HLBG         +150 XP               │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Core (Week 1-2)
- Database schema
- XP tracking system
- Basic tier progression
- Login bonus integration

### Phase 2: Rewards (Week 3-4)
- Reward distribution system
- Item/title/mount granting
- Claim verification

### Phase 3: UI (Week 5-6)
- AIO addon UI panel
- Progress visualization
- Challenge display
- Notification system

### Phase 4: Integration (Week 7+)
- Hook all XP sources
- Daily/weekly challenges
- Premium track support
- Season rollover logic

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Players feel forced | Daily cap prevents burnout |
| Too grindy | Catch-up mechanics in final month |
| Pay-to-win concerns | Premium = cosmetics only |
| Reward inflation | Carefully curated tier rewards |

---

## Success Metrics

- **Daily Active Users**: +30% expected
- **Session Length**: +20% expected  
- **Seasonal Retention**: +40% expected
- **Content Participation**: More M+, BG, world content engagement

---

*Detailed specs for Dark Chaos Battle Pass System - January 2026*
