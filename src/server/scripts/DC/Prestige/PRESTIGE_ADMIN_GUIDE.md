# Prestige System Extensions - Admin Guide

## Quick Start

### 1. Database Setup
Run the SQL schema:
```bash
mysql -u root -p acore_characters < data/sql/custom/db_characters/prestige_challenges_schema.sql
```

This creates two tables:
- `dc_prestige_challenges` - Tracks active/completed challenges
- `dc_prestige_challenge_rewards` - Stores permanent stat bonuses

### 2. Configuration
Edit `Custom/Config files/darkchaos-custom.conf.dist`:

#### Enable Alt Bonus (Default: ON)
```properties
Prestige.AltBonus.Enable = 1
Prestige.AltBonus.MaxLevel = 255
Prestige.AltBonus.PercentPerChar = 5      # 5% per character
Prestige.AltBonus.MaxCharacters = 5       # Max 25% bonus
```

#### Enable Prestige Challenges (Default: ON)
```properties
Prestige.Challenges.Enable = 1
Prestige.Challenges.Iron.Enable = 1
Prestige.Challenges.Speed.Enable = 1
Prestige.Challenges.Speed.TimeLimit = 360000  # 100 hours
Prestige.Challenges.Solo.Enable = 1
```

### 3. Compile & Restart
```bash
cd build
cmake --build . --config RelWithDebInfo
# Restart worldserver
```

---

## Configuration Reference

### Alt Bonus Tuning

**Conservative Settings** (Slow progression):
```properties
Prestige.AltBonus.PercentPerChar = 3      # 3% per char
Prestige.AltBonus.MaxCharacters = 3       # Max 9% bonus
```

**Aggressive Settings** (Fast alt leveling):
```properties
Prestige.AltBonus.PercentPerChar = 10     # 10% per char
Prestige.AltBonus.MaxCharacters = 5       # Max 50% bonus
```

**Retail-Like** (Moderate):
```properties
Prestige.AltBonus.PercentPerChar = 5      # 5% per char
Prestige.AltBonus.MaxCharacters = 5       # Max 25% bonus (DEFAULT)
```

### Challenge Difficulty Tuning

**Easy Mode**:
```properties
Prestige.Challenges.Speed.TimeLimit = 720000  # 200 hours
# Consider disabling Iron if too hard for your players
Prestige.Challenges.Iron.Enable = 0
```

**Hardcore Mode**:
```properties
Prestige.Challenges.Speed.TimeLimit = 180000  # 50 hours
# All challenges enabled with strict rules
```

**Challenge Rewards** (Hardcoded, requires C++ changes):
```cpp
// In dc_prestige_challenges.cpp
constexpr uint32 BONUS_STAT_PERCENT_IRON = 2;   // +2% per challenge
constexpr uint32 BONUS_STAT_PERCENT_SPEED = 2;
constexpr uint32 BONUS_STAT_PERCENT_SOLO = 2;
```

---

## Client DBC Requirements

### Required Title Entries

Add these to `CharTitles.dbc`:

| ID  | Name Format | Description |
|-----|-------------|-------------|
| 188 | Iron %s | No deaths challenge |
| 189 | Swift %s | Speed run challenge |
| 190 | Lone Wolf %s | Solo leveling challenge |

**Steps to Add**:
1. Open `CharTitles.dbc` in a DBC editor (e.g., WDBX Editor)
2. Add new rows with IDs 188-190
3. Set name format (e.g., "Iron %s" where %s = player name)
4. Save and rebuild client MPQ
5. Distribute to players

**Alternative**: Use existing title IDs if you prefer not to modify client files.

---

## GM Commands

### Alt Bonus Management
```sql
-- Check account's max-level character count
SELECT COUNT(*) FROM characters WHERE account = <ACCOUNT_ID> AND level >= 255;

-- Manually clear alt bonus cache (if needed)
-- System auto-clears on level-up to 255
```

### Challenge Management
```sql
-- View player's active challenges
SELECT * FROM dc_prestige_challenges WHERE guid = <CHARACTER_GUID> AND active = 1;

-- View completed challenges
SELECT * FROM dc_prestige_challenges WHERE guid = <CHARACTER_GUID> AND completed = 1;

-- Force complete a challenge (admin override)
UPDATE dc_prestige_challenges 
SET active = 0, completed = 1, completion_time = UNIX_TIMESTAMP() 
WHERE guid = <CHARACTER_GUID> AND challenge_type = <TYPE>;

-- Grant challenge reward manually
INSERT INTO dc_prestige_challenge_rewards (guid, challenge_type, stat_bonus_percent, granted_time)
VALUES (<CHARACTER_GUID>, <TYPE>, 2, UNIX_TIMESTAMP());

-- Remove failed/bugged challenge
DELETE FROM dc_prestige_challenges WHERE guid = <CHARACTER_GUID> AND challenge_type = <TYPE>;
```

### Challenge Types
- `1` = Iron Prestige (no deaths)
- `2` = Speed Prestige (<100 hours)
- `3` = Solo Prestige (no grouping)

---

## Monitoring & Analytics

### Popular Queries

**Alt Bonus Distribution**:
```sql
-- How many accounts have X max-level characters?
SELECT 
  COUNT(*) as char_count,
  COUNT(DISTINCT account) as accounts
FROM characters 
WHERE level >= 255
GROUP BY account
ORDER BY char_count DESC;
```

**Challenge Completion Rates**:
```sql
-- Success rate per challenge type
SELECT 
  challenge_type,
  COUNT(*) as total_attempts,
  SUM(completed) as completions,
  ROUND(SUM(completed) / COUNT(*) * 100, 2) as success_rate
FROM dc_prestige_challenges
GROUP BY challenge_type;
```

**Speed Prestige Leaderboard**:
```sql
-- Fastest Speed Prestige completions
SELECT 
  c.name,
  pc.completion_time - pc.start_time as seconds_taken
FROM dc_prestige_challenges pc
JOIN characters c ON c.guid = pc.guid
WHERE pc.challenge_type = 2 AND pc.completed = 1
ORDER BY seconds_taken ASC
LIMIT 10;
```

**Challenge Rewards Summary**:
```sql
-- Total stat bonuses granted per player
SELECT 
  c.name,
  SUM(r.stat_bonus_percent) as total_bonus
FROM dc_prestige_challenge_rewards r
JOIN characters c ON c.guid = r.guid
GROUP BY c.guid
ORDER BY total_bonus DESC;
```

---

## Troubleshooting

### Issue: Alt bonus not applying
**Symptoms**: Players report no XP bonus despite having max-level alts

**Diagnosis**:
```sql
-- Check if characters are actually at max level
SELECT account, name, level FROM characters WHERE account = <ACCOUNT_ID>;
```

**Solutions**:
1. Verify `Prestige.AltBonus.Enable = 1` in config
2. Check `Prestige.AltBonus.MaxLevel` matches your server max level
3. Restart worldserver to reload config
4. Verify player is not at max level (bonus doesn't apply to max-level chars)

### Issue: Challenge failed unexpectedly
**Symptoms**: Player claims they didn't die/group but challenge failed

**Diagnosis**:
```sql
-- Check challenge failure reason
SELECT * FROM dc_prestige_challenges WHERE guid = <CHARACTER_GUID> AND active = 0;
```

**Solutions**:
1. Iron: Check death logs in server logs
2. Speed: Verify played time calculation
3. Solo: Check if player was invited to group (counts as failure)
4. If legitimate bug, manually restore challenge:
```sql
UPDATE dc_prestige_challenges 
SET active = 1, death_count = 0, group_count = 0
WHERE guid = <CHARACTER_GUID> AND challenge_type = <TYPE>;
```

### Issue: Challenge rewards not granted
**Symptoms**: Challenge shows completed but no title/stats

**Diagnosis**:
```sql
-- Check if reward entry exists
SELECT * FROM dc_prestige_challenge_rewards WHERE guid = <CHARACTER_GUID>;

-- Check title in CharTitles.dbc (client-side)
```

**Solutions**:
1. Manually grant reward:
```sql
INSERT INTO dc_prestige_challenge_rewards (guid, challenge_type, stat_bonus_percent, granted_time)
VALUES (<CHARACTER_GUID>, <TYPE>, 2, UNIX_TIMESTAMP());
```
2. If title missing, verify CharTitles.dbc includes IDs 188-190
3. Player must relog to see stat changes

### Issue: Performance problems
**Symptoms**: Server lag when players level up

**Diagnosis**:
- Check server logs for slow queries
- Monitor cache hit rates

**Solutions**:
1. Alt bonus cache should prevent excessive queries
2. Challenge validation uses in-memory cache
3. If issues persist, add database indexes:
```sql
CREATE INDEX idx_characters_account_level ON characters(account, level);
CREATE INDEX idx_challenges_active ON dc_prestige_challenges(guid, active);
```

---

## Balancing Considerations

### Alt Bonus Impact

**XP Curve Analysis**:
```
No bonus:     0h baseline
5% bonus:     ~0.5h saved
10% bonus:    ~1h saved
15% bonus:    ~1.5h saved
20% bonus:    ~2h saved
25% bonus:    ~2.5h saved per 1-255 run
```

**Recommendation**: Start conservative (5% per char) and increase based on player feedback.

### Challenge Difficulty

**Iron Prestige**:
- Most difficult challenge
- ~10-20% completion rate expected
- Consider for hardcore players only

**Speed Prestige**:
- Moderately difficult
- ~30-40% completion rate expected
- 100 hours is achievable but requires focus

**Solo Prestige**:
- Easiest challenge
- ~50-60% completion rate expected
- Good for casual players

**Reward Balance**:
- +2% per challenge = +6% total
- Comparable to 6 prestige levels
- Not overpowered but meaningful

---

## Advanced Configuration

### Custom Challenge Types (Future)

To add new challenges, modify `dc_prestige_challenges.cpp`:

1. Add new enum:
```cpp
enum PrestigeChallenge : uint8
{
    CHALLENGE_IRON  = 1,
    CHALLENGE_SPEED = 2,
    CHALLENGE_SOLO  = 3,
    CHALLENGE_CUSTOM = 4,  // NEW
};
```

2. Add title constant:
```cpp
constexpr uint32 TITLE_CUSTOM_PRESTIGE = 191;
```

3. Implement validation hooks
4. Add to command handler
5. Update configuration

### Seasonal Resets

To reset challenges seasonally:
```sql
-- Archive completed challenges
CREATE TABLE dc_prestige_challenges_archive AS 
SELECT *, NOW() as archived_date FROM dc_prestige_challenges WHERE completed = 1;

-- Clear for new season
TRUNCATE TABLE dc_prestige_challenges;
TRUNCATE TABLE dc_prestige_challenge_rewards;

-- Optional: Keep permanent rewards across seasons
-- (Don't truncate dc_prestige_challenge_rewards)
```

---

## Support & Updates

### Logging
All systems log to server console:
```
[SCRIPTS] Prestige Alt Bonus: Loaded (5% per char, max 5 chars = 25% max bonus)
[SCRIPTS] Prestige Challenges: Loaded (Iron: ON, Speed: 100h, Solo: ON)
[SCRIPTS] Prestige Challenges: Player <name> started challenge <type>
[SCRIPTS] Prestige Challenges: Player <name> completed challenge <type>
[SCRIPTS] Prestige Challenges: Player <name> failed challenge <type> - <reason>
```

### Common Admin Actions

**Disable all challenges temporarily**:
```properties
Prestige.Challenges.Enable = 0
```

**Disable specific challenge**:
```properties
Prestige.Challenges.Iron.Enable = 0
```

**Adjust Speed challenge time**:
```properties
# 50 hours = 180000 seconds
# 100 hours = 360000 seconds
# 150 hours = 540000 seconds
Prestige.Challenges.Speed.TimeLimit = 360000
```

**Boost alt bonus for events**:
```properties
Prestige.AltBonus.PercentPerChar = 10  # Double XP weekend!
```

---

## Maintenance

### Regular Tasks

**Weekly**:
- Review challenge completion rates
- Check for stuck/bugged challenges
- Monitor alt bonus cache performance

**Monthly**:
- Analyze leaderboards
- Adjust difficulty based on completion rates
- Archive old challenge data

**Seasonal**:
- Consider challenge resets
- Update rewards
- Refresh leaderboards

### Backup Queries
```sql
-- Backup challenge data
SELECT * FROM dc_prestige_challenges 
INTO OUTFILE '/tmp/prestige_challenges_backup.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';

-- Backup rewards data
SELECT * FROM dc_prestige_challenge_rewards
INTO OUTFILE '/tmp/prestige_rewards_backup.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';
```

---

## Contact

For bugs, feature requests, or questions:
- GitHub Issues: [repository link]
- Discord: [server invite]
- Documentation: `PRESTIGE_EXTENSIONS_SUMMARY.md`
- Player Guide: `PRESTIGE_PLAYER_GUIDE.md`
