-- ============================================================================
-- Dark Chaos - Mythic+ Table Naming Standardization Migration
-- ============================================================================
-- Date: 2024-12-05
-- Purpose: Standardize all Mythic+ related table names to use consistent prefixes
-- 
-- Naming Convention:
--   dc_mplus_           → Core Mythic+ system (dungeons, affixes, scores, runs)
--   dc_mplus_spec_      → Spectator subsystem
--   dc_mplus_scale_     → Scaling subsystem
--   dc_gf_              → Group Finder system
-- ============================================================================

-- ============================================================================
-- WORLD DATABASE RENAMES
-- ============================================================================
-- Run this section against acore_world database

-- Core M+ tables (already using dc_mplus_ - no change needed):
-- dc_mplus_affix_pairs       ✓ (keep)
-- dc_mplus_affix_schedule    ✓ (keep)
-- dc_mplus_affixes           ✓ (keep)
-- dc_mplus_featured_dungeons ✓ (keep)
-- dc_mplus_seasons           ✓ (keep)
-- dc_mplus_teleporter_npcs   ✓ (keep)

-- Rename inconsistent tables in WORLD database:
RENAME TABLE `dc_mythic_plus_dungeons` TO `dc_mplus_dungeons`;
RENAME TABLE `dc_mythic_plus_weekly_affixes` TO `dc_mplus_weekly_affixes`;
RENAME TABLE `dc_mythic_scaling_multipliers` TO `dc_mplus_scale_multipliers`;

-- Spectator tables in WORLD database:
RENAME TABLE `dc_mythic_spectator_npcs` TO `dc_mplus_spec_npcs`;
RENAME TABLE `dc_mythic_spectator_positions` TO `dc_mplus_spec_positions`;
RENAME TABLE `dc_mythic_spectator_strings` TO `dc_mplus_spec_strings`;

-- ============================================================================
-- CHARACTER DATABASE RENAMES
-- ============================================================================
-- Run this section against acore_characters database

-- Core M+ tables (already using dc_mplus_ - no change needed):
-- dc_mplus_keystones  ✓ (keep)
-- dc_mplus_runs       ✓ (keep - note: there may be duplicates)
-- dc_mplus_scores     ✓ (keep)

-- Rename inconsistent tables in CHARACTERS database:
RENAME TABLE `dc_mythic_player_rating` TO `dc_mplus_player_ratings`;
RENAME TABLE `dc_mythic_plus_runs` TO `dc_mplus_runs_legacy`;  -- May conflict with dc_mplus_runs, merge or drop
RENAME TABLE `dc_mythic_plus_best_runs` TO `dc_mplus_best_runs`;

-- Spectator tables in CHARACTERS database:
RENAME TABLE `dc_mythic_spectator_invites` TO `dc_mplus_spec_invites`;
RENAME TABLE `dc_mythic_spectator_popularity` TO `dc_mplus_spec_popularity`;
RENAME TABLE `dc_mythic_spectator_replays` TO `dc_mplus_spec_replays`;
RENAME TABLE `dc_mythic_spectator_sessions` TO `dc_mplus_spec_sessions`;
RENAME TABLE `dc_mythic_spectator_settings` TO `dc_mplus_spec_settings`;

-- HUD cache rename:
RENAME TABLE `dc_mythicplus_hud_cache` TO `dc_mplus_hud_cache`;

-- ============================================================================
-- HANDLE DUPLICATE RUNS TABLES
-- ============================================================================
-- If both dc_mplus_runs and dc_mythic_plus_runs exist, migrate data:

-- Option 1: Merge data from legacy to main (uncomment if needed)
-- INSERT IGNORE INTO `dc_mplus_runs` SELECT * FROM `dc_mplus_runs_legacy`;
-- DROP TABLE IF EXISTS `dc_mplus_runs_legacy`;

-- Option 2: Just drop legacy if empty or not needed
-- DROP TABLE IF EXISTS `dc_mplus_runs_legacy`;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- World DB verification (run after migration):
-- SHOW TABLES LIKE 'dc_mplus%';
-- Expected: dc_mplus_affix_pairs, dc_mplus_affix_schedule, dc_mplus_affixes,
--           dc_mplus_dungeons, dc_mplus_featured_dungeons, dc_mplus_scale_multipliers,
--           dc_mplus_seasons, dc_mplus_spec_npcs, dc_mplus_spec_positions,
--           dc_mplus_spec_strings, dc_mplus_teleporter_npcs, dc_mplus_weekly_affixes

-- Characters DB verification (run after migration):
-- SHOW TABLES LIKE 'dc_mplus%';
-- Expected: dc_mplus_hud_cache, dc_mplus_keystones, dc_mplus_player_ratings,
--           dc_mplus_runs, dc_mplus_scores, dc_mplus_spec_invites,
--           dc_mplus_spec_popularity, dc_mplus_spec_replays, dc_mplus_spec_sessions,
--           dc_mplus_spec_settings

-- Group Finder verification:
-- SHOW TABLES LIKE 'dc_gf%';
-- Expected: dc_gf_applications, dc_gf_event_signups, dc_gf_listings, dc_gf_scheduled_events

SELECT 'Migration script prepared. Review and run sections separately on each database.' AS Status;
