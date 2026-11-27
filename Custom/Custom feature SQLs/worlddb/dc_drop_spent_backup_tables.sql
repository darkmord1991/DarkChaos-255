-- =====================================================================================
-- acore_world -- drop the spent rollback/backup tables
--
-- Every table below was created by ONE migration purely so that migration could be
-- reverted. Verified before writing this file:
--   * no C++ in src/ or modules/ queries any of them
--   * no other .sql reads them except the file that created them (and the commented-out
--     rollback recipes in that same file's header)
--   * no view and no foreign key depends on them
-- Dropping one therefore loses ONLY the ability to roll back its own migration.
--
-- NOT LISTED HERE, DELIBERATELY -- these look temporary but are load-bearing:
--   dc_scholo822_* / dc_sfk825_* / dc_strat821_*  id maps. Later files in each dungeon
--     suite join to them instead of doing id arithmetic, and they cross-check each other
--     for guid-band collisions. ScholomanceDC/02_id_maps.sql says so explicitly: "They
--     are permanent (not TEMPORARY) on purpose ... the audit trail for which clone id
--     came from which stock id."
--   dc_map751_spawn_guid   -- the guid allocation ledger, read by Plaguelands 63/66/67/70.
--   dc_map750_snap         -- read by HyjalCata 233/235/247/288/290/305/307/311/...
--   dc_map750_item_clone   -- read by HyjalCata 309/312/319/321/322/323 and
--                             tools/gen_item_dbc_append_r48.py
--   every other dc_map750_* / dc_map751_* working table (band, chunkzone, entryzone,
--     questzone, ref_clone, zoneport, src_*, stat_snap, ...) for the same reason.
--
-- Reclaims roughly 6 MB. Safe to re-run: every statement is IF EXISTS.
-- =====================================================================================

USE `acore_world`;

-- --- creature_loot_template snapshots (Hyjal / map750 loot rounds) --------------------
DROP TABLE IF EXISTS `clt_backup_r266`;            -- 266_loot_orphans_and_group_fixes.sql, 23,272 rows
DROP TABLE IF EXISTS `dc_orphan_loot_backup`;      -- 290_map750_gold_skinning_and_junk_loot.sql, 27 rows
DROP TABLE IF EXISTS `dc_orphan_loot_backup2`;     -- 291_boot_log_round35.sql, 3,975 rows
DROP TABLE IF EXISTS `dc_dualstore_loot_backup`;   -- 292_boot_log_round36.sql, 215 rows
DROP TABLE IF EXISTS `dc_map750_junkgear_backup`;  -- 290_map750_gold_skinning_and_junk_loot.sql, 4,118 rows

-- --- spawn / movement snapshots -------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_wander_backup`;    -- 277_map750_wander_restore.sql, 19,762 rows
DROP TABLE IF EXISTS `dc_map750_patrol_backup`;    -- 305_map750_patrol_restore_round47.sql, 22 rows
DROP TABLE IF EXISTS `dc_map750_dupe_backup_go`;   -- 206_map750_duplicate_gameobjects.sql, 452 rows
DROP TABLE IF EXISTS `dc_stray_go_backup_530`;     -- 285_outland_stray_herbs.sql, 5 rows
DROP TABLE IF EXISTS `dc_map751_zone_backup`;      -- Plaguelands/61_zone_split.sql, 8,169 rows

-- --- level / stat snapshots -----------------------------------------------------------
DROP TABLE IF EXISTS `dc_clstats_backup`;          -- 315_creature_stats_above_83.sql, 688 rows
DROP TABLE IF EXISTS `dc_map750_questlevel_backup`;-- 311_map750_questlevel_band_round48.sql, 101 rows

-- --- superseded legacy stub ------------------------------------------------------------
-- Replaced by dc_item_upgrade_item_overrides. ItemUpgradeManager.cpp names it only in a
-- comment; compat_item_templates_upgrade.sql itself says "safe to drop after the new
-- binary has been deployed". Currently 0 rows, and both table checkers
-- (dc_database_table_checker.sql, Eluna dc_table_checker.lua) already mark it as no
-- longer queried by the current binary.
DROP TABLE IF EXISTS `dc_item_templates_upgrade`;

-- =====================================================================================
-- HOLD BACK unless you are done evaluating the 2026-09-02 rounds in game.
-- These three are yesterday's snapshots and are still a live rollback path. Uncomment
-- once the rare-band promotion, the relevel and the exp rebalance are signed off.
-- =====================================================================================
-- DROP TABLE IF EXISTS `dc_map750_rare_loot_backup`;       -- 322_map750_rare_band_promotion.sql, 177 rows
-- DROP TABLE IF EXISTS `dc_map750_relevel_backup`;         -- 325_map750_relevel_stragglers.sql, 14 rows
-- DROP TABLE IF EXISTS `dc_creature_exp_rebalance_backup`; -- 318_creature_expansion_stat_column.sql, 1,992 rows

-- Verify afterwards -- expect only the three held-back tables to remain:
--   SELECT TABLE_NAME FROM information_schema.TABLES
--    WHERE TABLE_SCHEMA = 'acore_world' AND TABLE_NAME LIKE '%backup%';
