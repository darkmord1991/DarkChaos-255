# Seasonal Quest & Chest System - Quick Reference

**Last Updated:** November 15, 2025

---

## 🎯 One-Minute Overview

A comprehensive seasonal reward system that automatically awards tokens to players for:
- ✅ **Quests** - 1-50 tokens based on difficulty
- ✅ **Boss Kills** - 50-500 tokens based on content type
- ✅ **Seasonal Multipliers** - Flexible per-season tuning (e.g., Season 2 = +15% rewards)

Designed to work seamlessly with existing systems using token-based rewards (like WoW Ascension/Remix).

---

## 📊 Key Numbers

| Activity | Base Reward | Range | Notes |
|----------|------------|-------|-------|
| Normal Quest | 15 | 0-25 | Scales by player vs quest level |
| Hard Quest | 20 | 0-30 | +25% for challenging content |
| Daily Quest | 50 | 40-60 | Repeatable, weekly counted |
| Weekly Quest | 100 | 80-120 | Once per week |
| Dungeon Trash | 5 | 3-8 | Low-value mobs |
| Dungeon Boss | 50 | 40-60 | Highest dungeon reward |
| Raid Trash | 25 | 20-30 | Mid-tier |
| Raid Boss | 100 | 80-120 | Significant reward |
| World Boss | 500 | 400-600 | Rare, high-value |
| **Weekly Cap** | — | **500** | Resets Sunday 00:00 |

---

## 🗄️ Database Tables at a Glance

### World DB (Configuration)
```
dc_seasonal_quest_rewards
├─ quest_id → reward_type, token_amount, multiplier
├─ is_daily, is_weekly flags
└─ difficulty tier (0-5)

dc_seasonal_creature_rewards
├─ creature_id → token_amount, essence_amount
├─ rank (normal/rare/boss/raid)
├─ content_type (dungeon/raid/world)
└─ multiplier override

dc_seasonal_chest_rewards
├─ chest_tier (1-4: Bronze-Legendary)
├─ loot pool (item IDs, drop chances)
├─ armor class & spec filtering
└─ weighted selection

dc_seasonal_reward_config
└─ Global settings (caps, thresholds, multipliers)
```

### Character DB (Player Tracking)
```
dc_player_seasonal_stats
├─ player_guid, season_id
├─ total_tokens_earned, total_essence_earned
├─ weekly_tokens_earned (reset each week)
├─ quest/boss/chest counters
└─ last_activity timestamps

dc_reward_transactions (Audit Log)
├─ player_guid, season_id, transaction_type
├─ source (quest_id / creature_id)
├─ token_amount, essence_amount
├─ multipliers applied (difficulty, season)
└─ timestamp for analytics

dc_player_seasonal_achievements
└─ Milestones (100 tokens earned, 10 quests, etc)

dc_player_seasonal_chests
└─ Prevents duplicate chest claims
```

---

## 🔄 Player Flow (High Level)

### Quest Completion
```
Player completes quest
    ↓
OnPlayerCompleteQuest() hook
    ↓
Query: dc_seasonal_quest_rewards (season + quest_id)
    ↓
Calculate: token_amount × difficulty_mult × season_mult
    ↓
Check: weekly_cap not exceeded
    ↓
Award tokens + log transaction
    ↓
Update player stats
    ↓
Notify player: "+15 Tokens (Quest: [Name])"
```

### Boss Kill (Group)
```
Boss dies
    ↓
OnUnitDeath() hook
    ↓
Query: dc_seasonal_creature_rewards (season + creature_id)
    ↓
Calculate: base_tokens × rank_multiplier × season_multiplier
    ↓
Split among group members
    ↓
Award to each + log transactions
    ↓
Update boss_killed counter for each
```

---

## ⚙️ Configuration (SQL Snippets)

### Add Quest Rewards
```sql
INSERT INTO dc_seasonal_quest_rewards 
(season_id, quest_id, reward_type, base_token_amount, seasonal_multiplier)
VALUES (1, 12345, 1, 15, 1.0);  -- Season 1, Quest 12345, 15 tokens
```

### Add Creature Rewards
```sql
INSERT INTO dc_seasonal_creature_rewards
(season_id, creature_id, reward_type, base_token_amount, creature_rank, content_type, seasonal_multiplier)
VALUES (1, 1000, 1, 50, 2, 1, 1.0);  -- Dungeon boss
```

### Apply Season Multiplier
```sql
UPDATE dc_seasonal_quest_rewards 
SET seasonal_multiplier = 1.15 
WHERE season_id = 2;  -- Season 2 = +15% all quests
```

### Override Global Config
```sql
UPDATE dc_seasonal_reward_config 
SET config_value = '600' 
WHERE config_key = 'weekly_token_cap';  -- Increase cap to 600
```

---

## 🛠️ Admin Commands (Planned)

```bash
# View season rewards configuration
.season rewards info 1

# Show player's seasonal stats
.season rewards player Thrall

# View top 10 players
.season rewards leaderboard 1

# Simulate quest reward (testing)
.season rewards test quest 12345

# Simulate boss kill (testing)
.season rewards test creature 1000

# Adjust configuration
.season rewards config weekly_token_cap 600
```

---

## 🎮 Integration Points

| System | Integration | Link |
|--------|-------------|------|
| **SeasonalSystem** | Register callbacks | SEASON_EVENT_START/END/RESET |
| **ItemUpgradeManager** | Award tokens | AddCurrency() call |
| **PlayerScript** | Quest hook | OnPlayerCompleteQuest() |
| **UnitScript** | Boss hook | OnUnitDeath() |
| **Database** | Logging | dc_reward_transactions table |
| **Existing Token System** | Backward compat | ItemUpgradeTokenHooks still works |

---

## 📁 Files Checklist

### ✅ COMPLETED
- [x] `SEASONAL_QUEST_CHEST_ARCHITECTURE.md` - Full architecture
- [x] `IMPLEMENTATION_SUMMARY.md` - Roadmap and next steps
- [x] `dc_seasonal_rewards.sql` - World DB schema
- [x] `dc_seasonal_player_stats.sql` - Character DB schema

### 🔄 IN PROGRESS / TODO
- [ ] `SeasonalRewardManager.h/cpp` - Core manager
- [ ] `SeasonalQuestRewards.cpp` - Quest hook
- [ ] `SeasonalBossRewards.cpp` - Boss hook
- [ ] `SeasonalRewardCommands.cpp` - Admin commands
- [ ] `SeasonalRewardLoader.cpp` - Script registration
- [ ] Update CMakeLists.txt

---

## 🚀 Quick Start (When Ready)

1. **Execute SQL schemas** on both databases
2. **Create test season** (Season 999):
   ```sql
   INSERT INTO dc_seasons VALUES (999, 'Dev Test', ...);
   ```
3. **Add test quest reward**:
   ```sql
   INSERT INTO dc_seasonal_quest_rewards VALUES (NULL, 999, 12345, 1, 50, 0, 2, 1.0, 0, 0, 0, 1, NOW());
   ```
4. **Compile server** with new scripts
5. **Test in-game**:
   - Complete quest ID 12345
   - Should see: "+15 Tokens (Quest: [Name])"
   - Check `dc_reward_transactions` for audit trail

---

## 💡 Key Features

✅ **Seasonal Multipliers** - Adjust all quest/boss rewards via 1 config value  
✅ **Difficulty Scaling** - Harder content worth more tokens  
✅ **Weekly Caps** - Prevent farming exploits (500 tokens/week default)  
✅ **Group Splitting** - Boss rewards distributed equally  
✅ **Transaction Logging** - Complete audit trail for debugging  
✅ **Leaderboards** - Built-in SQL views for rankings  
✅ **Easy Config** - All values in database (no code recompile)  
✅ **Backward Compatible** - Existing token system continues to work  

---

## ⚠️ Important Notes

- **Weekly Cap Reset**: Sunday 00:00 server time (configurable)
- **Trivial Quests**: Player >> quest level = 0 tokens (avoid farming low content)
- **Group Splitting**: Boss tokens split equally; essence not split
- **Chest Drops**: Separate system (future phase) - currently just tokens
- **Transaction Logging**: Keeps complete audit trail (important for fraud detection)
- **Multipliers**: Multiplicative, not additive (difficulty × season × daily bonus)

---

## 🎓 Examples

### Example 1: Quest Reward Calculation
```
Base quest reward: 15 tokens
Player vs quest difficulty: Normal (1.0x)
Season 2 multiplier: 1.15x
Weekly cap check: 150/500 (OK)

Final: 15 × 1.0 × 1.15 = 17 tokens
Weekly total: 150 + 17 = 167 tokens
```

### Example 2: Boss Reward (Group)
```
Dungeon Boss base: 50 tokens, 10 essence
Group size: 4 players
Season multiplier: 1.0x
Daily bonus: None

Per player: 50 ÷ 4 = 12 tokens each
Essence: 10 (not split, each player gets full 10)
```

### Example 3: Season Configuration
```
Season 1 (Default): 1.0x multiplier
Season 2 (Launch Week): 1.15x multiplier
Season 2 (Weekend Bonus): Additional 1.1x Friday-Sunday

Player completes quest Saturday:
15 × 1.15 × 1.1 = 18.5 → 18 tokens (rounded down)
```

---

## 📞 Support

For questions about:
- **Architecture**: See `SEASONAL_QUEST_CHEST_ARCHITECTURE.md`
- **Implementation**: See `IMPLEMENTATION_SUMMARY.md`
- **Database**: Check SQL files in `Custom/Custom feature SQLs/`
- **Existing Systems**: Review `SeasonalSystem.h`, `ItemUpgradeTokenHooks.cpp`

---

**Version:** 1.0  
**Status:** Design Complete - Ready for Implementation  
**Next Phase:** Phase 1 Code Development
