-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER DATABASE: OFFLINE MIGRATION FROM CLONE ENTRIES TO DYNAMIC UPGRADES
-- ═══════════════════════════════════════════════════════════════════════════════
-- Purpose:
--   Convert live clone-backed player items into dynamic upgrade state rows in
--   `dc_item_upgrades`, then rewrite `item_instance.itemEntry` back to the base
--   item entry.
--
-- Scope:
--   * Scoped to the live schemas observed on 2026-05-23:
--       - character DB: `acore_chars`
--       - world DB:     `acore_world`
--   * Uses the deployed tables/columns currently present in those schemas.
--
-- Preconditions:
--   1. worldserver and authserver must be stopped.
--   2. Take full backups of `acore_chars` and `acore_world` first.
--   3. Run this before deploying a server build that removes live clone
--      compatibility paths. After that cutover, clone entries left in
--      `item_instance` are no longer normalized at login.
--   4. The required deployment hard gate after this script is:
--        SELECT COUNT(*) FROM `acore_chars`.`item_instance`
--        WHERE `itemEntry` >= 2000000;
--      The result must be 0 before the cutover build goes live.
--
-- Safety model:
--   * Builds a staging table first.
--   * Fails closed by setting `@gate_ok = 0` if validation finds mismatches.
--   * Creates backup tables for affected `item_instance` and existing
--     `dc_item_upgrades` rows before modifying anything.
--   * Leaves inventory/mail/auction/guild-bank link tables untouched because
--     they point at `item_instance.guid`, not `itemEntry`.
--
-- Notes:
--   * Historical `dc_item_upgrade_log` rows are not rewritten.
--   * Backup/staging tables created by this script are left in place on purpose.
-- ═══════════════════════════════════════════════════════════════════════════════

USE `acore_chars`;

-- ───────────────────────────────────────────────────────────────────────────────
-- 0) Runtime constants and baseline inspection
-- ───────────────────────────────────────────────────────────────────────────────
SET @migration_ts := UNIX_TIMESTAMP();
SET @clone_item_id_min := 2000000;

SELECT 'BASELINE: clone instances before migration' AS status;
SELECT
    COUNT(*) AS clone_instances,
    COUNT(DISTINCT owner_guid) AS owners_with_clone_items
FROM `acore_chars`.`item_instance`
WHERE `itemEntry` >= @clone_item_id_min;

SELECT 'BASELINE: clone storage buckets before migration' AS status;
SELECT bucket, clone_items
FROM (
    SELECT 'item_instance' AS bucket, COUNT(*) AS clone_items
    FROM `acore_chars`.`item_instance`
    WHERE `itemEntry` >= @clone_item_id_min

    UNION ALL

    SELECT 'inventory', COUNT(*)
    FROM `acore_chars`.`character_inventory` ci
    JOIN `acore_chars`.`item_instance` ii ON ii.guid = ci.item
    WHERE ii.itemEntry >= @clone_item_id_min

    UNION ALL

    SELECT 'mail', COUNT(*)
    FROM `acore_chars`.`mail_items` mi
    JOIN `acore_chars`.`item_instance` ii ON ii.guid = mi.item_guid
    WHERE ii.itemEntry >= @clone_item_id_min

    UNION ALL

    SELECT 'auctionhouse', COUNT(*)
    FROM `acore_chars`.`auctionhouse` ah
    JOIN `acore_chars`.`item_instance` ii ON ii.guid = ah.itemguid
    WHERE ii.itemEntry >= @clone_item_id_min

    UNION ALL

    SELECT 'guild_bank', COUNT(*)
    FROM `acore_chars`.`guild_bank_item` gbi
    JOIN `acore_chars`.`item_instance` ii ON ii.guid = gbi.item_guid
    WHERE ii.itemEntry >= @clone_item_id_min
) AS buckets;

-- ───────────────────────────────────────────────────────────────────────────────
-- 1) Precompute cumulative invested costs by tier/season/level
-- ───────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `dc_item_upgrade_cost_cumulative_stage`;
CREATE TABLE `dc_item_upgrade_cost_cumulative_stage` AS
SELECT
    c1.tier_id,
    c1.season,
    c1.upgrade_level,
    SUM(c2.token_cost) AS tokens_invested,
    SUM(c2.essence_cost) AS essence_invested
FROM `acore_world`.`dc_item_upgrade_costs` c1
JOIN `acore_world`.`dc_item_upgrade_costs` c2
  ON c2.tier_id = c1.tier_id
 AND c2.season = c1.season
 AND c2.upgrade_level <= c1.upgrade_level
GROUP BY c1.tier_id, c1.season, c1.upgrade_level;

ALTER TABLE `dc_item_upgrade_cost_cumulative_stage`
    ADD PRIMARY KEY (`tier_id`, `season`, `upgrade_level`);

-- ───────────────────────────────────────────────────────────────────────────────
-- 2) Build one staging row per live clone item instance
-- ───────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `dc_item_upgrade_clone_migration_stage`;
CREATE TABLE `dc_item_upgrade_clone_migration_stage` AS
SELECT
    ii.guid AS item_guid,
    ii.owner_guid,
    COALESCE(NULLIF(ii.owner_guid, 0), mi.receiver, ah.itemowner, 0) AS resolved_player_guid,
    CASE
        WHEN ci.item IS NOT NULL THEN 'inventory'
        WHEN mi.item_guid IS NOT NULL THEN 'mail'
        WHEN ah.itemguid IS NOT NULL THEN 'auctionhouse'
        WHEN gbi.item_guid IS NOT NULL THEN 'guild_bank'
        ELSE 'detached'
    END AS storage_bucket,
    ii.itemEntry AS clone_item_entry,
    clones.base_item_id AS base_item_entry,
    clones.tier_id AS clone_tier_id,
    base_map.tier_id AS mapped_tier_id,
    COALESCE(base_map.tier_id, clones.tier_id) AS resolved_tier_id,
    clones.upgrade_level,
    clones.stat_multiplier,
    COALESCE(base_map.season, 1) AS season,
    costs.upgrade_level AS cost_rollup_level,
    COALESCE(costs.tokens_invested, 0) AS tokens_invested,
    COALESCE(costs.essence_invested, 0) AS essence_invested,
    COALESCE(it.name, CONCAT('Item ', clones.base_item_id)) AS base_item_name,
    existing.upgrade_level AS existing_upgrade_level,
    existing.tier_id AS existing_tier_id
FROM `acore_chars`.`item_instance` ii
JOIN `acore_world`.`dc_item_upgrade_clones` clones
  ON clones.clone_item_id = ii.itemEntry
LEFT JOIN `acore_world`.`dc_item_templates_upgrade` base_map
  ON base_map.item_id = clones.base_item_id
 AND base_map.is_active = 1
LEFT JOIN `acore_world`.`item_template` it
  ON it.entry = clones.base_item_id
LEFT JOIN `acore_chars`.`character_inventory` ci
  ON ci.item = ii.guid
LEFT JOIN `acore_chars`.`mail_items` mi
  ON mi.item_guid = ii.guid
LEFT JOIN `acore_chars`.`auctionhouse` ah
  ON ah.itemguid = ii.guid
LEFT JOIN `acore_chars`.`guild_bank_item` gbi
  ON gbi.item_guid = ii.guid
LEFT JOIN `acore_chars`.`dc_item_upgrade_cost_cumulative_stage` costs
  ON costs.tier_id = COALESCE(base_map.tier_id, clones.tier_id)
 AND costs.season = COALESCE(base_map.season, 1)
 AND costs.upgrade_level = clones.upgrade_level
LEFT JOIN `acore_chars`.`dc_item_upgrades` existing
  ON existing.item_guid = ii.guid
WHERE ii.itemEntry >= @clone_item_id_min;

ALTER TABLE `dc_item_upgrade_clone_migration_stage`
    ADD PRIMARY KEY (`item_guid`),
    ADD KEY `idx_clone_entry` (`clone_item_entry`),
    ADD KEY `idx_base_entry` (`base_item_entry`),
    ADD KEY `idx_storage_bucket` (`storage_bucket`);

SELECT 'STAGE: rows prepared for migration' AS status;
SELECT
    COUNT(*) AS staged_clone_items,
    COUNT(DISTINCT resolved_player_guid) AS distinct_resolved_players,
    SUM(storage_bucket = 'inventory') AS inventory_rows,
    SUM(storage_bucket = 'mail') AS mail_rows,
    SUM(storage_bucket = 'auctionhouse') AS auctionhouse_rows,
    SUM(storage_bucket = 'guild_bank') AS guild_bank_rows,
    SUM(storage_bucket = 'detached') AS detached_rows
FROM `dc_item_upgrade_clone_migration_stage`;

-- ───────────────────────────────────────────────────────────────────────────────
-- 3) Stage gates: refuse to mutate if required base mappings or owners are bad
-- ───────────────────────────────────────────────────────────────────────────────
SET @stage_clone_count := (
    SELECT COUNT(*) FROM `dc_item_upgrade_clone_migration_stage`
);

SET @missing_base_mapping_count := (
    SELECT COUNT(*)
    FROM `dc_item_upgrade_clone_migration_stage`
    WHERE mapped_tier_id IS NULL
);

SET @tier_mismatch_count := (
    SELECT COUNT(*)
    FROM `dc_item_upgrade_clone_migration_stage`
    WHERE mapped_tier_id IS NOT NULL
      AND mapped_tier_id <> clone_tier_id
);

SET @missing_player_guid_count := (
    SELECT COUNT(*)
    FROM `dc_item_upgrade_clone_migration_stage`
    WHERE resolved_player_guid = 0
);

SET @missing_cost_rollup_count := (
    SELECT COUNT(*)
    FROM `dc_item_upgrade_clone_migration_stage`
    WHERE upgrade_level > 0
      AND cost_rollup_level IS NULL
);

SET @gate_ok := IF(
    @missing_base_mapping_count = 0
    AND @tier_mismatch_count = 0
    AND @missing_player_guid_count = 0
    AND @missing_cost_rollup_count = 0,
    1,
    0
);

SELECT 'STAGE GATE SUMMARY' AS status;
SELECT
    @stage_clone_count AS staged_clone_items,
    @missing_base_mapping_count AS missing_base_mapping_count,
    @tier_mismatch_count AS tier_mismatch_count,
    @missing_player_guid_count AS missing_player_guid_count,
    @missing_cost_rollup_count AS missing_cost_rollup_count,
    @gate_ok AS gate_ok;

SELECT
    CASE
        WHEN @gate_ok = 1 THEN 'OK: validation passed, writes are enabled.'
        ELSE 'STOP: validation failed, write statements below will no-op.'
    END AS gate_status;

SELECT 'VALIDATION DETAIL: base mapping mismatches (must be empty)' AS status;
SELECT
    item_guid,
    clone_item_entry,
    base_item_entry,
    clone_tier_id,
    mapped_tier_id,
    storage_bucket
FROM `dc_item_upgrade_clone_migration_stage`
WHERE mapped_tier_id IS NULL
   OR mapped_tier_id <> clone_tier_id;

SELECT 'VALIDATION DETAIL: rows with no resolved player owner (must be empty)' AS status;
SELECT
    item_guid,
    clone_item_entry,
    base_item_entry,
    storage_bucket,
    owner_guid,
    resolved_player_guid
FROM `dc_item_upgrade_clone_migration_stage`
WHERE resolved_player_guid = 0;

-- ───────────────────────────────────────────────────────────────────────────────
-- 4) Backup currently affected rows before any mutation
-- ───────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS `dc_item_upgrade_clone_migration_backup_item_instance`;
CREATE TABLE `dc_item_upgrade_clone_migration_backup_item_instance` AS
SELECT ii.*
FROM `acore_chars`.`item_instance` ii
JOIN `dc_item_upgrade_clone_migration_stage` stage
  ON stage.item_guid = ii.guid
WHERE @gate_ok = 1;

ALTER TABLE `dc_item_upgrade_clone_migration_backup_item_instance`
    ADD PRIMARY KEY (`guid`),
    ADD KEY `idx_itemEntry` (`itemEntry`),
    ADD KEY `idx_owner_guid` (`owner_guid`);

DROP TABLE IF EXISTS `dc_item_upgrade_clone_migration_backup_state`;
CREATE TABLE `dc_item_upgrade_clone_migration_backup_state` AS
SELECT state.*
FROM `acore_chars`.`dc_item_upgrades` state
JOIN `dc_item_upgrade_clone_migration_stage` stage
  ON stage.item_guid = state.item_guid
WHERE @gate_ok = 1;

ALTER TABLE `dc_item_upgrade_clone_migration_backup_state`
    ADD PRIMARY KEY (`upgrade_id`),
    ADD UNIQUE KEY `uidx_item_guid` (`item_guid`),
    ADD KEY `idx_player_guid` (`player_guid`);

SELECT 'BACKUP COUNTS' AS status;
SELECT
    (SELECT COUNT(*) FROM `dc_item_upgrade_clone_migration_backup_item_instance`) AS backed_up_item_instances,
    (SELECT COUNT(*) FROM `dc_item_upgrade_clone_migration_backup_state`) AS backed_up_upgrade_rows;

-- ───────────────────────────────────────────────────────────────────────────────
-- 5) Upsert dynamic upgrade state for every staged clone item
-- ───────────────────────────────────────────────────────────────────────────────
INSERT INTO `acore_chars`.`dc_item_upgrades`
(
    `item_guid`,
    `player_guid`,
    `base_item_name`,
    `tier_id`,
    `upgrade_level`,
    `tokens_invested`,
    `essence_invested`,
    `stat_multiplier`,
    `first_upgraded_at`,
    `last_upgraded_at`,
    `season`
)
SELECT
    stage.item_guid,
    stage.resolved_player_guid,
    stage.base_item_name,
    stage.resolved_tier_id,
    stage.upgrade_level,
    stage.tokens_invested,
    stage.essence_invested,
    stage.stat_multiplier,
    @migration_ts,
    @migration_ts,
    stage.season
FROM `dc_item_upgrade_clone_migration_stage` stage
WHERE @gate_ok = 1
ON DUPLICATE KEY UPDATE
    `player_guid` = VALUES(`player_guid`),
    `base_item_name` = VALUES(`base_item_name`),
    `tier_id` = VALUES(`tier_id`),
    `upgrade_level` = VALUES(`upgrade_level`),
    `tokens_invested` = VALUES(`tokens_invested`),
    `essence_invested` = VALUES(`essence_invested`),
    `stat_multiplier` = VALUES(`stat_multiplier`),
    `season` = VALUES(`season`);

SELECT 'WRITE CHECK: dynamic state rows after upsert' AS status;
SELECT
    COUNT(*) AS migrated_upgrade_rows,
    COUNT(DISTINCT player_guid) AS distinct_players,
    MIN(upgrade_level) AS min_upgrade_level,
    MAX(upgrade_level) AS max_upgrade_level
FROM `acore_chars`.`dc_item_upgrades`
WHERE item_guid IN (
    SELECT item_guid FROM `dc_item_upgrade_clone_migration_stage`
);

-- ───────────────────────────────────────────────────────────────────────────────
-- 6) Rewrite live item instances from clone entry -> base entry
-- ───────────────────────────────────────────────────────────────────────────────
UPDATE `acore_chars`.`item_instance` ii
JOIN `dc_item_upgrade_clone_migration_stage` stage
  ON stage.item_guid = ii.guid
SET ii.itemEntry = stage.base_item_entry
WHERE @gate_ok = 1;

SELECT 'POST-MIGRATION CHECK: remaining clone item instances' AS status;
SELECT
    COUNT(*) AS remaining_clone_instances,
    COUNT(DISTINCT owner_guid) AS remaining_clone_owners
FROM `acore_chars`.`item_instance`
WHERE `itemEntry` >= @clone_item_id_min;

SELECT 'POST-MIGRATION CHECK: converted rows' AS status;
SELECT
    COUNT(*) AS converted_to_base_entries,
    MIN(itemEntry) AS min_base_entry,
    MAX(itemEntry) AS max_base_entry
FROM `acore_chars`.`item_instance`
WHERE `guid` IN (
    SELECT item_guid FROM `dc_item_upgrade_clone_migration_stage`
)
  AND `itemEntry` < @clone_item_id_min;

-- ───────────────────────────────────────────────────────────────────────────────
-- 7) Operator close-out notes
-- ───────────────────────────────────────────────────────────────────────────────
SELECT 'NEXT STEPS' AS status;
SELECT
    'If gate_ok=1 and remaining_clone_instances=0, the character DB portion is complete. Keep the backup/stage tables until the dynamic cutover build is validated, and block deployment unless SELECT COUNT(*) FROM acore_chars.item_instance WHERE itemEntry >= 2000000 returns 0.'
    AS note;
