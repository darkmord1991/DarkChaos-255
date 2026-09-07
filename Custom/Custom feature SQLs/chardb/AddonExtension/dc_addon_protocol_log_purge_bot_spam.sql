-- ============================================================================
-- dc_addon_protocol_log / _stats -- one-off purge of playerbot spam
-- Database: acore_chars   (run manually; not a schema migration)
-- ============================================================================
--
-- WHY
-- ---
-- Playerbot sessions have no client and no addon, but the DC addon protocol
-- was pushing S2C frames at them anyway -- and logging every one. Measured on
-- this realm before the fix:
--
--   dc_addon_protocol_log   1,991,498 rows   477 MB data + 321 MB index
--                           95.6% of it addressed to RNDBOT* accounts
--   dc_addon_protocol_stats    16,911 rows   89% bot
--
--   Daily row counts, before bots / after bots:
--     2026-08-27 .. 09-04     ~2,000 - 5,000 rows/day   (normal)
--     2026-09-05                 892,077 rows/day
--     2026-09-06                 996,121 rows/day
--
-- The top producers were CORE|21 (CrossSystem CreatureKill -- one 277-byte
-- JSON frame per mob a bot kills, 942k rows) and QOS|21 (graphics-profile
-- cache invalidation on every zone/map change, 404k rows).
--
-- The source of the spam is fixed in code: the send paths now drop addon
-- traffic aimed at a session flagged IsBot(), so nothing is built, sent or
-- logged for a bot any more, and DC.AddonProtocol.Logging.RetentionDays keeps
-- the table bounded from here on. This script only clears the backlog that
-- already accumulated -- the built-in prune will not touch it while it is
-- still inside the retention window.
--
-- SAFETY
-- ------
-- Both tables are debugging aids. Nothing in the core, the addons or the
-- MCP tooling reads historical rows -- .dccaps and dc_observe_protocol_log
-- only ever look at recent activity. Deleting is safe at any time; the server
-- does not need to be down.
--
-- Deletes run in 50k batches so InnoDB does not hold a multi-minute row-lock
-- on a live realm. Re-run each statement until it reports 0 rows affected.
-- (Single-table DELETE ... IN (subquery) rather than a JOIN: MySQL rejects
-- LIMIT on the multi-table DELETE form, and unbatched these would each be a
-- million-row transaction.)
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Protocol log: drop every row belonging to a playerbot account.
--    Repeat until "0 rows affected".
-- ----------------------------------------------------------------------------
DELETE FROM dc_addon_protocol_log
WHERE account_id IN (
    SELECT id FROM acore_logon.account WHERE username LIKE 'RNDBOT%'
)
LIMIT 50000;


-- ----------------------------------------------------------------------------
-- 2. Protocol stats: same, keyed through characters.account since the stats
--    table only carries a guid.
--    Repeat until "0 rows affected".
-- ----------------------------------------------------------------------------
DELETE FROM dc_addon_protocol_stats
WHERE guid IN (
    SELECT c.guid
    FROM characters c
    JOIN acore_logon.account a ON a.id = c.account
    WHERE a.username LIKE 'RNDBOT%'
)
LIMIT 50000;


-- ----------------------------------------------------------------------------
-- 3. Stats rows for characters that no longer exist (bot characters churn).
--    Repeat until "0 rows affected".
-- ----------------------------------------------------------------------------
DELETE FROM dc_addon_protocol_stats
WHERE guid NOT IN (SELECT guid FROM characters)
LIMIT 50000;


-- ----------------------------------------------------------------------------
-- 4. Reclaim the disk. InnoDB does not return freed pages to the filesystem on
--    DELETE alone; without this the .ibd stays at its ~800 MB high-water mark.
--    Locks the table for the duration -- run it during a quiet period.
-- ----------------------------------------------------------------------------
OPTIMIZE TABLE dc_addon_protocol_log;
OPTIMIZE TABLE dc_addon_protocol_stats;


-- ============================================================================
-- ALTERNATIVE: if you do not care about the ~90k human rows either (this is a
-- debug log, and the useful window is the last few days), the whole backlog
-- goes in one statement, instantly, with the disk reclaimed and the
-- AUTO_INCREMENT reset:
--
--   TRUNCATE TABLE dc_addon_protocol_log;
--   TRUNCATE TABLE dc_addon_protocol_stats;
--   TRUNCATE TABLE dc_addon_protocol_errors;
-- ============================================================================
