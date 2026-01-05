/*
 * DarkChaos Database Table Checker
 * 
 * This script checks for all required DC (DarkChaos) custom tables
 * and reports which ones are missing. Run this before starting the server
 * to identify database schema issues.
 * 
 * Updated: 2025-11-29 (synced with C++ code and schema files)
 * Tables: ~95 in acore_chars, ~60 in acore_world = ~155 total
 */

-- Create a temporary table to store check results
DROP TEMPORARY TABLE IF EXISTS dc_table_check_results;
CREATE TEMPORARY TABLE dc_table_check_results (
    table_schema VARCHAR(64),
    table_name VARCHAR(64),
    exists_flag TINYINT(1) DEFAULT 0,
    required_for VARCHAR(100)
);

-- ============================================================
-- CHARACTER DATABASE (acore_chars)
-- ============================================================

-- Achievement System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_achievement_definitions', 0, 'Achievements');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_achievements', 0, 'Achievements');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_server_firsts', 0, 'Achievements');

-- AoE Loot System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_aoe_loot_settings', 0, 'AoE Loot');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_aoeloot_accumulated', 0, 'AoE Loot');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_aoeloot_detailed_stats', 0, 'AoE Loot');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_aoeloot_preferences', 0, 'AoE Loot');

-- Artifact System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_artifact_mastery_events', 0, 'Artifacts');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_artifact_discoveries', 0, 'Artifacts');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_artifact_mastery', 0, 'Artifacts');

-- Challenge/Dungeon Progress
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_challenge_modes', 0, 'Challenge Mode');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_challenge_mode_log', 0, 'Challenge Mode');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_challenge_mode_stats', 0, 'Challenge Mode');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_difficulty_completions', 0, 'Dungeon Progress');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_difficulty_streaks', 0, 'Dungeon Progress');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_dungeon_npc_respawn', 0, 'Dungeon Progress');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_dungeon_progress', 0, 'Dungeon Progress');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_dungeon_quests_completed', 0, 'Dungeon Progress');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_dungeon_statistics', 0, 'Dungeon Stats');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_dungeon_instance_resets', 0, 'Dungeon System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_dungeon_completion_stats', 0, 'Dungeon Stats');

-- Prestige System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_prestige', 0, 'Prestige');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_prestige_log', 0, 'Prestige');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_character_prestige_stats', 0, 'Prestige');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_prestige_challenge_rewards', 0, 'Prestige');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_prestige_challenges', 0, 'Prestige');

-- Duel System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_duel_class_matchups', 0, 'Duel System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_duel_history', 0, 'Duel System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_duel_statistics', 0, 'Duel System');

-- Guild/Leaderboard
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_guild_leaderboard', 0, 'Leaderboards');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_guild_upgrade_stats', 0, 'Leaderboards');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_leaderboard_cache', 0, 'Leaderboards');

-- Heirloom System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_heirloom_package_history', 0, 'Heirloom');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_heirloom_player_packages', 0, 'Heirloom');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_heirloom_upgrade_log', 0, 'Heirloom');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_heirloom_upgrades', 0, 'Heirloom');

-- HLBG (Hinterlands BG) System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_hlbg_player_history', 0, 'HLBG System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_hlbg_player_season_data', 0, 'HLBG System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_hlbg_season_config', 0, 'HLBG System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_hlbg_match_history', 0, 'HLBG System');

-- Item Upgrade System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_costs', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_currency_exchange_log', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_log', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_stat_scaling', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_state', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_synthesis_cooldowns', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_synthesis_log', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrade_transmutation_sessions', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_item_upgrades', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_item_upgrades', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_synthesis_cooldowns', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_tier_caps', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_tier_unlocks', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_transmutation_cooldowns', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_upgrade_summary', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_upgrade_tokens', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_recent_upgrades_feed', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_respec_history', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_respec_log', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_tier_conversion_log', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_top_upgraders', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_upgrade_history', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_upgrade_speed_stats', 0, 'Item Upgrade');

-- Mythic+ System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mplus_keystones', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mplus_runs', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mplus_scores', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythicplus_hud_cache', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythic_keystones', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_keystones', 0, 'Mythic+');

-- Mythic Spectator
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythic_spectator_invites', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythic_spectator_popularity', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythic_spectator_replays', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythic_spectator_sessions', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_mythic_spectator_settings', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_spectator_settings', 0, 'Mythic Spectator');

-- Season System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_claimed_chests', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_season_data', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_seasonal_achievements', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_seasonal_chests', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_seasonal_stats', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_seasonal_stats_history', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_season_history', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_seasons', 0, 'Season System');

-- Quest/Daily/Weekly System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_daily_quest_progress', 0, 'Quest System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_weekly_cap_snapshot', 0, 'Quest System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_weekly_quest_progress', 0, 'Quest System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_weekly_rewards', 0, 'Weekly Vault');

-- Token System
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_token_event_config', 0, 'Token System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_token_rewards_log', 0, 'Token System');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_token_transaction_log', 0, 'Token System');

-- Vault/Rewards
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_player_progression_summary', 0, 'Vault/Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_reward_transactions', 0, 'Vault/Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_vault_reward_pool', 0, 'Vault/Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_weekly_spending', 0, 'Vault/Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_chars', 'dc_weekly_vault', 0, 'Weekly Vault');

-- ============================================================
-- WORLD DATABASE (acore_world)
-- ============================================================

-- AoE Loot Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_aoeloot_blacklist', 0, 'AoE Loot Config');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_aoeloot_config', 0, 'AoE Loot Config');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_aoeloot_smart_categories', 0, 'AoE Loot Config');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_aoeloot_zone_modifiers', 0, 'AoE Loot Config');

-- Artifact Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_chaos_artifact_items', 0, 'Artifacts');

-- Quest Token Rewards
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_daily_quest_token_rewards', 0, 'Quest Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_weekly_quest_token_rewards', 0, 'Quest Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_quest_reward_tokens', 0, 'Quest Rewards');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_quest_difficulty_mapping', 0, 'Quest System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_npc_quest_link', 0, 'Quest System');

-- Difficulty System
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_difficulty_config', 0, 'Difficulty System');

-- Duel System
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_duel_tournament_npcs', 0, 'Duel System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_duel_zones', 0, 'Duel System');

-- Dungeon System
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_dungeon_entrances', 0, 'Dungeon System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_dungeon_mythic_profile', 0, 'Dungeon System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_dungeon_npc_mapping', 0, 'Dungeon System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_dungeon_setup', 0, 'Dungeon System');

-- Heirloom Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_heirloom_enchant_mapping', 0, 'Heirloom');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_heirloom_package_levels', 0, 'Heirloom');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_heirloom_stat_packages', 0, 'Heirloom');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_heirloom_upgrade_costs', 0, 'Heirloom');

-- Hotspots
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_hotspots_active', 0, 'Hotspot System');

-- Item Upgrade Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_proc_spells', 0, 'Item Procs');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_templates_upgrade', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_clones', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_costs', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_stage', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_state', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_synthesis_inputs', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_synthesis_recipes', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_tier_items', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_item_upgrade_tiers', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_synthesis_recipes', 0, 'Item Upgrade');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_upgrade_tracks', 0, 'Item Upgrade');

-- Mythic+ Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mplus_affix_pairs', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mplus_affix_schedule', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mplus_affixes', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mplus_featured_dungeons', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mplus_seasons', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mplus_teleporter_npcs', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mythic_plus_dungeons', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mythic_plus_weekly_affixes', 0, 'Mythic+');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mythic_scaling_multipliers', 0, 'Mythic+');

-- Mythic Spectator Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mythic_spectator_npcs', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mythic_spectator_positions', 0, 'Mythic Spectator');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_mythic_spectator_strings', 0, 'Mythic Spectator');

-- Season Rewards Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_seasonal_chest_rewards', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_seasonal_creature_rewards', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_seasonal_quest_rewards', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_seasonal_reward_config', 0, 'Season System');
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_seasonal_reward_multipliers', 0, 'Season System');

-- Token/Vendor Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_token_vendor_items', 0, 'Token System');

-- Vault Config
INSERT INTO dc_table_check_results VALUES ('acore_world', 'dc_vault_loot_table', 0, 'Weekly Vault');

-- ============================================================
-- Now check which tables exist
-- ============================================================

-- Check acore_chars tables
UPDATE dc_table_check_results r
SET exists_flag = 1
WHERE table_schema = 'acore_chars'
AND EXISTS (
    SELECT 1 FROM information_schema.TABLES t
    WHERE t.TABLE_SCHEMA = 'acore_chars'
    AND t.TABLE_NAME = r.table_name
);

-- Check acore_world tables
UPDATE dc_table_check_results r
SET exists_flag = 1
WHERE table_schema = 'acore_world'
AND EXISTS (
    SELECT 1 FROM information_schema.TABLES t
    WHERE t.TABLE_SCHEMA = 'acore_world'
    AND t.TABLE_NAME = r.table_name
);

-- ============================================================
-- Output Results
-- ============================================================

SELECT '========================================' AS '';
SELECT 'DarkChaos Database Table Check Results' AS '';
SELECT '========================================' AS '';
SELECT '' AS '';

-- Show missing tables
SELECT 'MISSING TABLES:' AS '';
SELECT CONCAT('  [', table_schema, '] ', table_name, ' (', required_for, ')') AS 'Missing Table'
FROM dc_table_check_results
WHERE exists_flag = 0
ORDER BY table_schema, required_for, table_name;

SELECT '' AS '';

-- Summary by feature
SELECT 'SUMMARY BY FEATURE:' AS '';
SELECT 
    required_for AS 'Feature',
    SUM(CASE WHEN exists_flag = 1 THEN 1 ELSE 0 END) AS 'Present',
    SUM(CASE WHEN exists_flag = 0 THEN 1 ELSE 0 END) AS 'Missing',
    COUNT(*) AS 'Total'
FROM dc_table_check_results
GROUP BY required_for
HAVING SUM(CASE WHEN exists_flag = 0 THEN 1 ELSE 0 END) > 0
ORDER BY required_for;

SELECT '' AS '';

-- Overall summary (using variables to avoid temp table reopen issue)
SELECT 'OVERALL SUMMARY:' AS '';
SELECT 
    @total := COUNT(*) AS 'Total Tables Checked',
    @present := SUM(CASE WHEN exists_flag = 1 THEN 1 ELSE 0 END) AS 'Tables Present',
    @missing := SUM(CASE WHEN exists_flag = 0 THEN 1 ELSE 0 END) AS 'Tables Missing'
FROM dc_table_check_results;

-- Final warning
SELECT '' AS '';
SELECT CASE 
    WHEN @missing > 0
    THEN CONCAT('⚠️  WARNING: ', @missing, ' tables are missing! Server may crash or malfunction.')
    ELSE '✅ All required DC tables are present.'
END AS 'Status';

-- Cleanup
DROP TEMPORARY TABLE IF EXISTS dc_table_check_results;
