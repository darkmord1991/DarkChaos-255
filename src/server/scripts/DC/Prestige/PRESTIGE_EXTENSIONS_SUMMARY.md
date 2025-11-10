# Prestige System Extensions - Implementation Summary

## Overview
Two major features added to the DarkChaos-255 Prestige system:
1. **Alt-Friendly XP Bonus** - Account-wide progression rewards
2. **Prestige Challenges** - Optional hard mode achievements

---

## 1. Alt-Friendly XP Bonus System

### Purpose
Encourages players to level multiple characters by granting XP bonuses based on max-level characters on their account.

### Mechanics
- **5% XP bonus per max-level (255) character** on the account
- **Maximum 25% bonus** (capped at 5 characters)
- Bonus **does not apply** to max-level characters
- Cache system for performance (clears when character reaches max level)

### Implementation Details

**File**: `dc_prestige_alt_bonus.cpp`

**Key Classes**:
- `PrestigeAltBonusSystem` - Singleton manager
  - `GetMaxLevelCharCount()` - Queries database, uses cache
  - `CalculateXPBonus()` - Returns bonus percentage for player
  - `InvalidateCacheForPlayer()` - Clears cache when needed

- `PrestigeAltBonusPlayerScript` - Player hooks
  - `OnGiveXP()` - Applies bonus to XP gains
  - `OnLogin()` - Shows welcome message with current bonus
  - `OnLevelChanged()` - Clears cache when reaching max level

**Database Queries**:
```sql
-- Count max-level characters on account
SELECT COUNT(*) FROM characters 
WHERE account = ? AND level >= 255
```

**Configuration** (`darkchaos-custom.conf.dist`):
```properties
Prestige.AltBonus.Enable = 1            # Master toggle
Prestige.AltBonus.MaxLevel = 255        # Level considered "max"
Prestige.AltBonus.PercentPerChar = 5    # 5% per character
Prestige.AltBonus.MaxCharacters = 5     # Max 5 characters counted
```

**Player Commands**:
- `.prestige altbonus info` - Display current bonus and max-level character count

**Example**:
```
Player has 3 characters at level 255 on their account:
- New character receives 15% bonus XP (3 × 5%)
- At level 255, they become the 4th max-level character
- Next new character receives 20% bonus XP (4 × 5%)
```

---

## 2. Prestige Challenges System

### Purpose
Optional hard mode challenges for skilled players seeking additional rewards and prestige.

### Challenge Types

#### Iron Prestige
- **Requirement**: Reach level 255 without dying
- **Tracking**: `OnPlayerKilledByCreature()`, `OnPVPKill()` hooks
- **Failure Condition**: Any death immediately fails the challenge
- **Rewards**: Title ID 188 ("Iron %s"), +2% permanent stat bonus

#### Speed Prestige
- **Requirement**: Reach level 255 in <100 hours played time
- **Tracking**: Compares total played time at start vs completion
- **Failure Condition**: Exceeding 100 hours before reaching 255
- **Rewards**: Title ID 189 ("Swift %s"), +2% permanent stat bonus

#### Solo Prestige
- **Requirement**: Reach level 255 without joining a group
- **Tracking**: `OnPlayerJoinedGroup()` hook
- **Failure Condition**: Joining any group/party/raid
- **Rewards**: Title ID 190 ("Lone Wolf %s"), +2% permanent stat bonus

### Implementation Details

**File**: `dc_prestige_challenges.cpp`

**Key Classes**:
- `PrestigeChallengeSystem` - Singleton manager
  - `StartChallenge()` - Opt player into challenge
  - `FailChallenge()` - Mark challenge as failed, remove from active
  - `CompleteChallenge()` - Grant rewards, update database
  - `CheckChallengeCompletion()` - Validate completion at level 255

- `PrestigeChallengePlayerScript` - Player hooks
  - `OnLogin()` - Load active challenges
  - `OnPlayerKilledByCreature/OnPVPKill()` - Fail Iron challenge
  - `OnPlayerJoinedGroup()` - Fail Solo challenge
  - `OnLevelChanged()` - Check challenge completion

**Database Schema** (`prestige_challenges_schema.sql`):

```sql
-- Challenge progress tracking
CREATE TABLE dc_prestige_challenges (
  guid INT(10) UNSIGNED NOT NULL,
  prestige_level TINYINT(3) UNSIGNED NOT NULL,
  challenge_type TINYINT(3) UNSIGNED NOT NULL, -- 1=Iron, 2=Speed, 3=Solo
  active TINYINT(1) NOT NULL DEFAULT 1,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  start_time INT(10) UNSIGNED NOT NULL,
  start_playtime INT(10) UNSIGNED NOT NULL DEFAULT 0,
  completion_time INT(10) UNSIGNED DEFAULT NULL,
  death_count INT(10) UNSIGNED NOT NULL DEFAULT 0,
  group_count INT(10) UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (guid, prestige_level, challenge_type)
);

-- Challenge rewards (permanent bonuses)
CREATE TABLE dc_prestige_challenge_rewards (
  guid INT(10) UNSIGNED NOT NULL,
  challenge_type TINYINT(3) UNSIGNED NOT NULL,
  stat_bonus_percent TINYINT(3) UNSIGNED NOT NULL DEFAULT 2,
  granted_time INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (guid, challenge_type)
);
```

**Configuration** (`darkchaos-custom.conf.dist`):
```properties
Prestige.Challenges.Enable = 1              # Master toggle
Prestige.Challenges.Iron.Enable = 1         # Iron challenge
Prestige.Challenges.Speed.Enable = 1        # Speed challenge
Prestige.Challenges.Speed.TimeLimit = 360000 # 100 hours in seconds
Prestige.Challenges.Solo.Enable = 1         # Solo challenge
```

**Player Commands**:
- `.prestige challenge start <iron|speed|solo>` - Opt into a challenge
- `.prestige challenge status` - View active and completed challenges
- `.prestige challenge list` - List all available challenges

**Rewards Stacking**:
```
Base Prestige System:     +10% stats (Prestige level 10)
Iron Prestige Complete:   +2% stats (permanent)
Speed Prestige Complete:  +2% stats (permanent)
Solo Prestige Complete:   +2% stats (permanent)
---------------------------------------------------
Maximum Total:            +16% permanent stat bonus
```

---

## Integration Points

### Script Loader
**File**: `dc_script_loader.cpp`

Added function declarations:
```cpp
void AddSC_dc_prestige_alt_bonus();
void AddSC_dc_prestige_challenges();
```

Modified loader:
```cpp
// Prestige System
try {
    AddSC_dc_prestige_system();
    AddSC_dc_prestige_spells();
    AddSC_dc_prestige_alt_bonus();      // NEW
    AddSC_dc_prestige_challenges();     // NEW
    LOG_INFO(">>   ✓ Prestige mechanics, spells, alt bonus, and challenges loaded");
}
```

### CMakeLists
**File**: `src/server/scripts/DC/CMakeLists.txt`

Added to `SCRIPTS_DC_Prestige`:
```cmake
Prestige/dc_prestige_alt_bonus.cpp
Prestige/dc_prestige_challenges.cpp
```

---

## Database Installation

### Required SQL
1. Run `data/sql/custom/db_characters/prestige_challenges_schema.sql`

### DBC Requirements (Client-Side)

**CharTitles.dbc** additions required for challenges:
```
ID 188: Iron %s          (Iron Prestige title)
ID 189: Swift %s         (Speed Prestige title)
ID 190: Lone Wolf %s     (Solo Prestige title)
```

**Note**: These titles must be added to the client DBC and distributed to players.

---

## Testing Checklist

### Alt Bonus System
- [ ] Create character, verify 0% bonus initially
- [ ] Level character to 255
- [ ] Create alt, verify 5% bonus message on login
- [ ] Kill mob, confirm XP increased by 5%
- [ ] Level 5 characters to 255, verify 25% bonus cap
- [ ] Test cache invalidation on level up

### Iron Prestige Challenge
- [ ] Start Iron challenge: `.prestige challenge start iron`
- [ ] Verify challenge appears in `.prestige challenge status`
- [ ] Die to mob - verify challenge failed message
- [ ] Restart challenge, reach 255 without dying
- [ ] Verify title granted and +2% bonus applied

### Speed Prestige Challenge
- [ ] Start Speed challenge: `.prestige challenge start speed`
- [ ] Check remaining time in `.prestige challenge status`
- [ ] Level to 255 within 100 hours
- [ ] Verify completion and rewards
- [ ] Test failure case (exceed 100 hours)

### Solo Prestige Challenge
- [ ] Start Solo challenge: `.prestige challenge start solo`
- [ ] Attempt to join group - verify immediate failure
- [ ] Restart challenge, level to 255 solo
- [ ] Verify completion and rewards

### Stacking Verification
- [ ] Complete all 3 challenges
- [ ] Check `.prestige challenge status` shows +6% total
- [ ] Verify stat sheet shows combined bonuses
- [ ] Test with prestige levels (16% total possible)

---

## Performance Considerations

### Alt Bonus Caching
- Account max-level count cached on first query
- Cache invalidated only when character reaches max level
- Minimal database queries (once per character creation)

### Challenge Tracking
- Active challenges loaded on login (1 query per player)
- Validation uses in-memory cache (no queries during gameplay)
- Database writes only on start/complete/fail (rare events)

---

## Known Limitations

1. **Speed Challenge**: Uses total played time (includes AFK)
   - Consider adding active time tracking in future

2. **Solo Challenge**: Requires group join hook
   - Does not track dungeon finder (if enabled)
   - Does not track raid invites accepted

3. **Challenge Titles**: Require client DBC modification
   - Alternative: Use existing game titles if client edits not possible

4. **Alt Bonus**: Does not account for deleted characters
   - Once a character reaches 255, they count permanently
   - Consider adding cleanup for deleted characters

---

## Future Enhancements

### Potential Additions
1. **Combo Challenges**
   - "Immortal Solo Speedrunner" - Complete all 3 challenges simultaneously
   - Reward: Special mount or legendary item

2. **Seasonal Challenges**
   - Reset challenges each season
   - Leaderboards for fastest completions

3. **Guild Challenges**
   - Guild-wide challenge bonuses
   - Prestige guild levels based on member completions

4. **Challenge Tiers**
   - Iron I/II/III with escalating difficulty
   - Higher tiers: 80-255 no deaths, 1-255 no deaths

5. **Alt Bonus Expansion**
   - Bonus applies to other systems (reputation, gold drops)
   - Account-wide achievement sharing

---

## Files Changed

### New Files
- `src/server/scripts/DC/Prestige/dc_prestige_alt_bonus.cpp`
- `src/server/scripts/DC/Prestige/dc_prestige_challenges.cpp`
- `data/sql/custom/db_characters/prestige_challenges_schema.sql`

### Modified Files
- `src/server/scripts/DC/CMakeLists.txt` (added 2 scripts)
- `src/server/scripts/DC/dc_script_loader.cpp` (added loaders)
- `Custom/Config files/darkchaos-custom.conf.dist` (added config section)

---

## Conclusion

Both systems successfully implemented with:
- ✅ Clean C++ code (no compiler errors)
- ✅ Comprehensive configuration options
- ✅ Player-friendly commands
- ✅ Database schema designed for performance
- ✅ Optional/toggleable features
- ✅ Integration with existing prestige system

The alt bonus system encourages account progression while challenges provide endgame goals for skilled players. Combined, they significantly enhance the prestige system's depth and replayability.
