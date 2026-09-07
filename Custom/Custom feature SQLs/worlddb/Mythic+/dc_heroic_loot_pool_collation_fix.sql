-- =====================================================================
-- dc_heroic_loot_pool - collation fixup
-- =====================================================================
-- Apply against: acore_world. Safe to re-run. Takes about a second.
--
-- Only needed if dc_heroic_loot_pool.sql was applied BEFORE 2026-09-06.
-- The corrected CREATE TABLE in that file now sets the collation
-- explicitly, so a fresh apply does not need this.
--
-- WHY
-- ---------------------------------------------------------------------
-- The original CREATE TABLE ended with a bare "DEFAULT CHARSET=utf8mb4"
-- and no COLLATE. On MySQL 8 that resolves to the server default,
-- utf8mb4_0900_ai_ci, while every other table in this schema is
-- utf8mb4_unicode_ci:
--
--     dc_heroic_loot_pool   utf8mb4_0900_ai_ci
--     dc_vault_loot_table   utf8mb4_unicode_ci
--     item_template         utf8mb4_unicode_ci
--
-- Any statement that combines the text columns across the two - the
-- UNION that MythicPlusRunManager::LoadLootTable used to run - fails
-- with errno 1271, "illegal mix of collations for operation UNION".
-- The whole statement returns nothing, so the server logged
--
--     >> Mythic+ loot table preloaded: 0 entries across 26 item-level buckets
--
-- and Mythic+ rewards stopped working too, not just heroic ones.
--
-- LoadLootTable no longer unions the two tables, so this mismatch can no
-- longer take the vault half down with it. Fix it anyway: a mismatched
-- collation will keep biting any future join between these tables.
--
-- Verify afterwards with the query at the bottom - expect both tables to
-- read utf8mb4_unicode_ci.
-- =====================================================================

ALTER TABLE `dc_heroic_loot_pool`
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `dc_heroic_loot_pool`
  DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;


-- =====================================================================
-- Verification
-- =====================================================================
-- Both tables must report utf8mb4_unicode_ci (expect 2 rows, matching):
--
--   SELECT TABLE_NAME, TABLE_COLLATION FROM information_schema.TABLES
--   WHERE TABLE_SCHEMA = DATABASE()
--     AND TABLE_NAME IN ('dc_heroic_loot_pool','dc_vault_loot_table');
--
-- No text column may still carry the 0900 collation (expect 0 rows):
--
--   SELECT TABLE_NAME, COLUMN_NAME, COLLATION_NAME
--   FROM information_schema.COLUMNS
--   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dc_heroic_loot_pool'
--     AND COLLATION_NAME IS NOT NULL
--     AND COLLATION_NAME <> 'utf8mb4_unicode_ci';
--
-- The union that used to fail must now run (expect one number, ~5406):
--
--   SELECT COUNT(*) FROM (
--     SELECT spec_name, armor_type FROM dc_vault_loot_table
--     UNION ALL
--     SELECT spec_name, armor_type FROM dc_heroic_loot_pool) u;
--
-- Row count must be unchanged by the conversion (expect 2857):
--
--   SELECT COUNT(*) FROM dc_heroic_loot_pool;
-- =====================================================================
