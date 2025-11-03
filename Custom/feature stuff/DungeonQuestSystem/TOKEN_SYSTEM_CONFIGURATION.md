# TOKEN SYSTEM CONFIGURATION GUIDE
## DC-255 Dungeon Quest System

**Date**: November 2, 2025  
**Version**: 2.0

---

## TABLE OF CONTENTS

1. Token Configuration Options
2. Daily Quest Token Rewards
3. Weekly Quest Token Rewards
4. CSV Configuration Files
5. SQL Configuration Examples
6. Modifying Token Values
7. Adding New Tokens
8. Token Exchange/Vendors (Optional Future)

---

## 1. TOKEN CONFIGURATION OPTIONS

### Five Core Tokens

| Token ID | Token Name | Item ID | Purpose | Rarity |
|----------|-----------|---------|---------|--------|
| 1 | Dungeon Explorer Token | 700001 | Awarded for daily quests | Common (White) |
| 2 | Expansion Specialist Token | 700002 | Awarded for expansion quests | Uncommon (Green) |
| 3 | Legendary Quest Token | 700003 | High-value achievement reward | Rare (Blue) |
| 4 | Challenge Master Token | 700004 | Difficult quest completion | Uncommon (Green) |
| 5 | Speed Runner Token | 700005 | Time-based challenge reward | Common (White) |

### Token Properties (from dc_items_tokens.csv)

```csv
item_id,item_name,item_display_id,item_class,item_subclass,quality,sellprice,buyprice,description
700001,Dungeon Explorer Token,12345,15,0,1,500,0,Awarded for completing daily dungeon quests
700002,Expansion Specialist Token,12346,15,0,2,1000,0,Awarded for expansion mastery quests
700003,Legendary Quest Token,12347,15,0,4,2000,0,High-tier reward token for major achievements
700004,Challenge Master Token,12348,15,0,2,1500,0,Awarded for completing challenging dungeon quests
700005,Speed Runner Token,12349,15,0,1,750,0,Awarded for time-based challenge completion
```

**Key Columns**:
- `item_class` = 15 (Miscellaneous / Quest)
- `quality` = 1-4 (White/Green/Blue/Purple)
- `sellprice` = NPC vendor price (in copper)
- `description` = Tooltip text

---

## 2. DAILY QUEST TOKEN REWARDS

### Configuration Table: dc_daily_quest_token_rewards

```sql
CREATE TABLE dc_daily_quest_token_rewards (
  daily_quest_id INT PRIMARY KEY,
  token_id_1 INT NOT NULL,
  token_count_1 INT DEFAULT 1,
  token_id_2 INT,
  token_count_2 INT DEFAULT 0,
  gold_reward INT DEFAULT 0,
  xp_reward INT DEFAULT 0,
  FOREIGN KEY (token_id_1) REFERENCES dc_quest_reward_tokens(token_id),
  FOREIGN KEY (token_id_2) REFERENCES dc_quest_reward_tokens(token_id)
);
```

### Daily Quest Reward Structure

#### Quest 700101: Explorer's Challenge
```sql
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700101, 1, 1, NULL, 0, 1000, 10000);
```
**Rewards**: 1x Dungeon Explorer Token + 1000 gold + 10k XP

#### Quest 700102: Focused Exploration
```sql
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700102, 1, 2, 2, 1, 2000, 25000);
```
**Rewards**: 2x Explorer Token + 1x Specialist Token + 2000 gold + 25k XP

#### Quest 700103: Quick Runner
```sql
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700103, 1, 3, NULL, 0, 3000, 50000);
```
**Rewards**: 3x Explorer Token + 3000 gold + 50k XP

#### Quest 700104: Dungeon Master's Gauntlet
```sql
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700104, 1, 5, 4, 2, 5000, 100000);
```
**Rewards**: 5x Explorer Token + 2x Challenge Master Token + 5000 gold + 100k XP

---

## 3. WEEKLY QUEST TOKEN REWARDS

### Configuration Table: dc_weekly_quest_token_rewards

```sql
CREATE TABLE dc_weekly_quest_token_rewards (
  weekly_quest_id INT PRIMARY KEY,
  token_id_1 INT NOT NULL,
  token_count_1 INT DEFAULT 1,
  token_id_2 INT,
  token_count_2 INT DEFAULT 0,
  gold_reward INT DEFAULT 0,
  xp_reward INT DEFAULT 0,
  title_reward_id INT,
  FOREIGN KEY (token_id_1) REFERENCES dc_quest_reward_tokens(token_id),
  FOREIGN KEY (token_id_2) REFERENCES dc_quest_reward_tokens(token_id)
);
```

### Weekly Quest Reward Structure

#### Quest 700201: Expansion Specialist
```sql
INSERT INTO dc_weekly_quest_token_rewards (weekly_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward, title_reward_id) VALUES
(700201, 2, 10, 3, 5, 5000, 100000, 1001);
```
**Rewards**: 10x Specialist Token + 5x Legendary Token + 5000 gold + 100k XP + Title "Master of [Expansion]"

#### Quest 700202: Speed Runner's Trial
```sql
INSERT INTO dc_weekly_quest_token_rewards (weekly_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700202, 5, 8, 4, 3, 4000, 75000);
```
**Rewards**: 8x Speed Runner Token + 3x Challenge Master Token + 4000 gold + 75k XP

#### Quest 700203: Devoted Runner
```sql
INSERT INTO dc_weekly_quest_token_rewards (weekly_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700203, 2, 6, NULL, 0, 3000, 50000);
```
**Rewards**: 6x Specialist Token + 3000 gold + 50k XP

#### Quest 700204: The Collector's Obsession
```sql
INSERT INTO dc_weekly_quest_token_rewards (weekly_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward, title_reward_id) VALUES
(700204, 3, 15, 4, 10, 10000, 150000, 1004);
```
**Rewards**: 15x Legendary Token + 10x Challenge Master Token + 10k gold + 150k XP + Title "The Collector"

---

## 4. CSV CONFIGURATION FILES

### File: `Custom\CSV DBC\dc_items_tokens.csv`

Purpose: Defines token item templates for AzerothCore item_template

```csv
item_id,item_name,item_display_id,item_class,item_subclass,quality,sellprice,buyprice,flags,description
700001,Dungeon Explorer Token,12345,15,0,1,500,0,0,Awarded for completing daily dungeon quests
700002,Expansion Specialist Token,12346,15,0,2,1000,0,0,Awarded for completing expansion mastery quests
700003,Legendary Quest Token,12347,15,0,4,2000,0,0,High-tier reward token for major achievements
700004,Challenge Master Token,12348,15,0,2,1500,0,0,Awarded for completing challenging dungeon quests
700005,Speed Runner Token,12349,15,0,1,750,0,0,Awarded for time-based challenge completion
```

**How to Load into item_template**:
```sql
-- Insert into AzerothCore item_template
INSERT INTO item_template (entry, class, subclass, name, displayid, quality, sellprice, flags, description) 
SELECT item_id, item_class, item_subclass, item_name, item_display_id, quality, sellprice, flags, description
FROM dc_items_tokens;
```

---

### File: `Custom\CSV DBC\dc_achievements.csv`

Purpose: Defines achievements that reward tokens

```csv
achievement_id,achievement_name,description,category,points,reward_item_id,reward_mount_id,reward_title_id
700001,Dungeon Explorer,Complete your first dungeon quest,General,5,0,0,0
700050,The Completionist,Complete all quests from 5 different dungeons,General,50,0,0,0
700100,Expansion Master - Classic,Complete all Classic expansion dungeon quests,Expansion,100,700051,0,1001
700101,Expansion Master - TBC,Complete all TBC expansion dungeon quests,Expansion,100,700052,0,1002
700102,Expansion Master - WOTLK,Complete all WOTLK expansion dungeon quests,Expansion,100,700053,0,1003
700200,Legendary Quester,Complete 500 dungeon quests,Challenge,200,700054,0,1005
700300,Speed Demon,Complete 25 quests in one week,Challenge,75,0,0,0
700400,The Collector,Complete 50 quests in one week,Challenge,100,700055,700086,1004
```

---

### File: `Custom\CSV DBC\dc_titles.csv`

Purpose: Defines titles awarded with achievements

```csv
title_id,title_name,male_name,female_name,category,icon
1000,Dungeon Master,Dungeon Master,Dungeon Master,Achievement,0
1001,Master of Classic,Master of Classic,Master of Classic,Expansion,1
1002,Master of Outlands,Master of Outlands,Master of Outlands,Expansion,2
1003,Master of Northrend,Master of Northrend,Master of Northrend,Expansion,3
1004,The Collector,the Collector,the Collector,Achievement,4
1005,Legendary,Legendary,Legendary,Achievement,5
```

---

## 5. SQL CONFIGURATION EXAMPLES

### Basic Token Configuration

```sql
-- Define available tokens
INSERT INTO dc_quest_reward_tokens (token_id, token_name, description, item_id, is_active) VALUES
(1, 'Dungeon Explorer Token', 'Earned from daily dungeon quests', 700001, 1),
(2, 'Expansion Specialist Token', 'Earned from weekly expansion quests', 700002, 1),
(3, 'Legendary Quest Token', 'High-tier reward token', 700003, 1),
(4, 'Challenge Master Token', 'Earned from difficult quests', 700004, 1),
(5, 'Speed Runner Token', 'Earned from time-based challenges', 700005, 1);

-- Daily quest rewards
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700101, 1, 1, NULL, 0, 1000, 10000),      -- Explorer's Challenge
(700102, 1, 2, 2, 1, 2000, 25000),         -- Focused Exploration
(700103, 1, 3, NULL, 0, 3000, 50000),      -- Quick Runner
(700104, 1, 5, 4, 2, 5000, 100000);        -- Dungeon Master's Gauntlet

-- Weekly quest rewards
INSERT INTO dc_weekly_quest_token_rewards (weekly_quest_id, token_id_1, token_count_1, token_id_2, token_count_2, gold_reward, xp_reward) VALUES
(700201, 2, 10, 3, 5, 5000, 100000),       -- Expansion Specialist
(700202, 5, 8, 4, 3, 4000, 75000),         -- Speed Runner's Trial
(700203, 2, 6, NULL, 0, 3000, 50000),      -- Devoted Runner
(700204, 3, 15, 4, 10, 10000, 150000);     -- The Collector's Obsession
```

---

## 6. MODIFYING TOKEN VALUES

### To Change Daily Quest Rewards

```sql
-- Example: Increase Explorer's Challenge reward from 1 to 2 tokens
UPDATE dc_daily_quest_token_rewards 
SET token_count_1 = 2 
WHERE daily_quest_id = 700101;

-- Example: Add a second token reward to Quick Runner
UPDATE dc_daily_quest_token_rewards 
SET token_id_2 = 2, token_count_2 = 1 
WHERE daily_quest_id = 700103;

-- Example: Increase gold reward for Dungeon Master's Gauntlet
UPDATE dc_daily_quest_token_rewards 
SET gold_reward = 7500 
WHERE daily_quest_id = 700104;
```

### To Change Weekly Quest Rewards

```sql
-- Example: Reduce Expansion Specialist tokens from 10 to 8
UPDATE dc_weekly_quest_token_rewards 
SET token_count_1 = 8 
WHERE weekly_quest_id = 700201;

-- Example: Double XP reward for Speed Runner's Trial
UPDATE dc_weekly_quest_token_rewards 
SET xp_reward = 150000 
WHERE weekly_quest_id = 700202;
```

### To Deactivate a Token

```sql
-- Example: Disable Challenge Master Token
UPDATE dc_quest_reward_tokens 
SET is_active = 0 
WHERE token_id = 4;
```

---

## 7. ADDING NEW TOKENS

### Step 1: Add to dc_items_tokens.csv

```csv
item_id,item_name,item_display_id,item_class,item_subclass,quality,sellprice,buyprice,description
700006,Guild Quest Token,12350,15,0,3,1200,0,Earned from guild-based dungeon quests
```

### Step 2: Insert into dc_quest_reward_tokens

```sql
INSERT INTO dc_quest_reward_tokens (token_id, token_name, description, item_id, is_active) VALUES
(6, 'Guild Quest Token', 'Earned from guild-based dungeon quests', 700006, 1);
```

### Step 3: Use in Quest Rewards

```sql
-- Use new token in a quest reward
INSERT INTO dc_daily_quest_token_rewards (daily_quest_id, token_id_1, token_count_1) VALUES
(700105, 6, 2);  -- New quest awards 2x Guild Quest Token
```

---

## 8. TOKEN EXCHANGE/VENDORS (Optional Future Feature)

### If You Want Players to Exchange Tokens for Items

**NPC Vendor Script Template**:

```cpp
class npc_token_vendor : public CreatureScript {
public:
    npc_token_vendor() : CreatureScript("npc_token_vendor") { }
    
    bool OnGossipHello(Player* player, Creature* creature) override {
        // Show vendor menu with token exchange options
        // Explorer Token: 10 tokens = 1000 gold
        // Specialist Token: 5 tokens = 5000 gold
        // Etc.
    }
};
```

**Example Exchange Rates** (For Future Implementation):

| From | Count | To | Count |
|------|-------|----|----|
| Dungeon Explorer Token | 10 | Gold | 1000 |
| Dungeon Explorer Token | 50 | Specialist Token | 5 |
| Specialist Token | 10 | Legendary Token | 2 |
| Legendary Token | 1 | Epic Item | 1 |
| Challenge Master Token | 5 | Specialist Token | 2 |

---

## 9. TOKEN TRACKING IN-GAME

### Player Token Inventory

Tokens are stored as quest items in the player's inventory:

```sql
-- Example: Check player's Explorer Token count
SELECT COUNT(*) as token_count 
FROM character_inventory 
WHERE bag = 255 
AND item = 700001 
AND guid = player_guid;
```

### Player Achievement Tracking

Achievements are tracked by:

```sql
-- Example: Check if player earned "Dungeon Explorer" achievement
SELECT * 
FROM character_achievement 
WHERE guid = player_guid 
AND achievement = 700001;
```

### Token Usage Logging

```sql
-- Optional: Create a table to track token usage
CREATE TABLE token_transaction_log (
  transaction_id INT AUTO_INCREMENT PRIMARY KEY,
  player_guid INT,
  token_id INT,
  quantity INT,
  transaction_type ENUM('Earned', 'Used', 'Exchanged'),
  transaction_date TIMESTAMP,
  FOREIGN KEY (player_guid) REFERENCES characters(guid),
  FOREIGN KEY (token_id) REFERENCES dc_quest_reward_tokens(token_id)
);
```

---

## 10. CONFIGURATION BEST PRACTICES

### Do's ✅

- ✅ Use CSV files for easy modifications
- ✅ Keep token values proportional to quest difficulty
- ✅ Test token rewards in-game before going live
- ✅ Document any custom changes made
- ✅ Back up token configuration before modifications
- ✅ Use meaningful token names
- ✅ Scale rewards with server economy

### Don'ts ❌

- ❌ Don't hardcode token values in C++ code
- ❌ Don't change token IDs after distribution (confuses players)
- ❌ Don't mix old prestige system with new token system
- ❌ Don't forget to test token loading on server restart
- ❌ Don't overvalue tokens (breaks economy)
- ❌ Don't forget to reload CSV after editing

---

## TOKEN BALANCE RECOMMENDATIONS

### For Level 1-50 Players

- Daily Quest: 1 Explorer Token
- Weekly Quest: 5 Specialist Tokens
- Milestone (5 dungeons): 1 Legendary Token

### For Level 50-200 Players

- Daily Quest: 2 Explorer Tokens
- Weekly Quest: 8 Specialist Tokens
- Milestone (20 dungeons): 3 Legendary Tokens

### For Level 200-255 Players

- Daily Quest: 5 Explorer Tokens
- Weekly Quest: 15 Specialist Tokens
- Milestone (50 dungeons): 10 Legendary Tokens

---

## QUICK REFERENCE

**Token Summary**:
- 5 token types defined
- 4 daily quests (700101-700104)
- 4 weekly quests (700201-700204)
- All configurable via CSV/SQL
- No prestige integration
- Fully extensible for future tokens

**Configuration Files**:
- `dc_items_tokens.csv` → Item definitions
- `dc_achievements.csv` → Achievement definitions
- `dc_titles.csv` → Title definitions
- `DC_DUNGEON_QUEST_CONFIG.sql` → Token mapping
- `DC_DUNGEON_QUEST_DAILY_WEEKLY.sql` → Quest rewards

**To Update Token Rewards**: Edit SQL files and reload server (or hotfix via SQL UPDATE commands)

