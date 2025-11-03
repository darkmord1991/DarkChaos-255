-- =====================================================================
-- DUNGEON QUEST NPC SYSTEM v2.0 - TOKEN REWARD DEFINITIONS
-- =====================================================================
-- Purpose: Define token rewards for daily, weekly, and dungeon quests
-- Status: Production Ready
-- Version: 2.0 (Standard AzerothCore)
-- =====================================================================

-- =====================================================================
-- TOKEN ITEM DEFINITIONS (dc_quest_reward_tokens)
-- =====================================================================

INSERT INTO `dc_quest_reward_tokens` 
(`token_item_id`, `token_name`, `token_description`, `token_type`, `rarity`, `icon_id`)
VALUES
-- Token ID 700001: Dungeon Explorer Token (Common)
(700001, 'Dungeon Explorer Token', 'Token of accomplishment for exploring dungeons', 'explorer', 1, 1000),

-- Token ID 700002: Expansion Specialist Token (Common)
(700002, 'Expansion Specialist Token', 'Token awarded for specializing in specific expansion dungeons', 'specialist', 1, 1001),

-- Token ID 700003: Legendary Dungeon Token (Rare)
(700003, 'Legendary Dungeon Token', 'Rare token for legendary dungeon achievements', 'legendary', 3, 1002),

-- Token ID 700004: Challenge Master Token (Rare)
(700004, 'Challenge Master Token', 'Token for conquering difficult challenges', 'challenge', 3, 1003),

-- Token ID 700005: Speed Runner Token (Common)
(700005, 'Speed Runner Token', 'Token for completing dungeons in record time', 'speedrunner', 1, 1004);

-- =====================================================================
-- DAILY QUEST TOKEN REWARDS (dc_daily_quest_token_rewards)
-- =====================================================================

-- Daily Quest 700101: Ragefire Chasm Challenge
-- Reward: 1x Dungeon Explorer Token (base) with 1.0x multiplier
INSERT INTO `dc_daily_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700101, 700001, 1, 1.0);

-- Daily Quest 700102: Blackfathom Deeps Challenge
-- Reward: 1x Dungeon Explorer Token (base) with 1.0x multiplier
INSERT INTO `dc_daily_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700102, 700001, 1, 1.0);

-- Daily Quest 700103: Gnomeregan Challenge
-- Reward: 1x Dungeon Explorer Token (base) with 1.0x multiplier
INSERT INTO `dc_daily_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700103, 700001, 1, 1.0);

-- Daily Quest 700104: Shadowfang Keep Challenge
-- Reward: 1x Dungeon Explorer Token (base) with 1.0x multiplier
INSERT INTO `dc_daily_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700104, 700001, 1, 1.0);

-- =====================================================================
-- WEEKLY QUEST TOKEN REWARDS (dc_weekly_quest_token_rewards)
-- =====================================================================

-- Weekly Quest 700201: Classic Dungeon Mastery
-- Reward: 3x Expansion Specialist Tokens (base) with 1.0x multiplier
INSERT INTO `dc_weekly_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700201, 700002, 3, 1.0);

-- Weekly Quest 700202: TBC Dungeon Mastery
-- Reward: 3x Expansion Specialist Tokens (base) with 1.0x multiplier
INSERT INTO `dc_weekly_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700202, 700002, 3, 1.0);

-- Weekly Quest 700203: WotLK Dungeon Mastery
-- Reward: 3x Expansion Specialist Tokens (base) with 1.0x multiplier
INSERT INTO `dc_weekly_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700203, 700002, 3, 1.0);

-- Weekly Quest 700204: Ultimate Dungeon Challenge
-- Reward: 5x Legendary Dungeon Tokens (base) with 1.0x multiplier
INSERT INTO `dc_weekly_quest_token_rewards`
(`quest_id`, `token_item_id`, `token_count`, `bonus_multiplier`)
VALUES
(700204, 700003, 5, 1.0);

-- =====================================================================
-- NOTES
-- =====================================================================

-- TOKEN REWARD TIERS:
-- Daily Quests (700101-700104):
--   - Base: 1x Dungeon Explorer Token per quest
--   - With multiplier: Up to 2x tokens on weekends (example)
--
-- Weekly Quests (700201-700203):
--   - Base: 3x Expansion Specialist Tokens per quest
--   - With multiplier: Up to 4.5x tokens (example 1.5x)
--
-- Weekly Quest (700204 - Ultimate Challenge):
--   - Base: 5x Legendary Dungeon Tokens (rare!)
--   - With multiplier: Up to 7.5x tokens
--
-- MULTIPLIER USES:
--   - 1.0x: Standard multiplier
--   - 1.5x: Weekend bonus
--   - 2.0x: Special event bonus
--   - 0.5x: Reduced (if needed for balance)
--
-- HOW IT WORKS:
--   1. Player completes quest
--   2. Script queries dc_daily_quest_token_rewards or dc_weekly_quest_token_rewards
--   3. Gets token_item_id, token_count, and multiplier
--   4. Calculates: final_count = token_count * multiplier
--   5. Awards tokens via AddItem(token_item_id, final_count)
--   6. Player sees notification

-- =====================================================================
-- QUERY EXAMPLES
-- =====================================================================

-- Get daily token rewards for quest 700101:
-- SELECT * FROM dc_daily_quest_token_rewards WHERE quest_id = 700101;
-- Result: token_item_id=700001, token_count=1, bonus_multiplier=1.0
--
-- Get weekly token rewards for quest 700204:
-- SELECT * FROM dc_weekly_quest_token_rewards WHERE quest_id = 700204;
-- Result: token_item_id=700003, token_count=5, bonus_multiplier=1.0
--
-- Get all token definitions:
-- SELECT * FROM dc_quest_reward_tokens;
-- Result: 5 token types with names and descriptions

-- =====================================================================
-- CUSTOMIZATION EXAMPLES
-- =====================================================================

-- To increase daily rewards by 50%:
-- UPDATE dc_daily_quest_token_rewards SET token_count = 2;
--
-- To apply event multiplier (2x):
-- UPDATE dc_daily_quest_token_rewards SET bonus_multiplier = 2.0;
--
-- To reset to normal:
-- UPDATE dc_daily_quest_token_rewards SET bonus_multiplier = 1.0;
--
-- To add new token type:
-- INSERT INTO dc_quest_reward_tokens VALUES (700006, 'New Token', 'Description', 'type', 2, 1005);
--
-- To link new token to quest:
-- INSERT INTO dc_daily_quest_token_rewards VALUES (700105, 700006, 1, 1.0);

SET FOREIGN_KEY_CHECKS=1;
