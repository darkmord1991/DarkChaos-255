-- ---------------------------------------------------------------------------
-- 330  Indexes for the token-vendor item lookups
-- ---------------------------------------------------------------------------
-- Observed live, reported from the server log:
--
--     [MessageRouter] SLOW handler MPLUS|0x81 took 389 ms (player=Adaasd)
--     [UpdateProfiler] World.UpdateSessions took 389ms
--     [MessageRouter] SLOW handler MPLUS|0x81 took 152 ms
--
-- 0x81 is CMSG_TOKEN_VENDOR_CHOICES -- one click on a gear slot. 389 ms inside
-- a world update is not a slow query in the abstract: `World::UpdateSessions`
-- is SINGLE-THREADED, so every player on the realm was stalled for that tick.
-- One person browsing a vendor should never do that.
--
-- 🔴 THE CAUSE IS THE INDEX SET, not the query. `item_template` has 159,563
-- rows and exactly three indexes:
--
--     PRIMARY      (entry)
--     idx_name     (name(250))
--     items_index  (class)          <- cardinality 15
--
-- GetItemsForSlotAndClass filters on class + subclass + InventoryType +
-- ItemLevel and then does `ORDER BY ItemLevel DESC, name ASC LIMIT 60/80`. With
-- only `class` indexed, MySQL reads every armour row (~100k), applies the rest
-- as a post-filter, and filesorts the survivors. That is the 389 ms.
--
-- ---------------------------------------------------------------------------
-- THE TWO INDEXES, AND WHY BOTH
-- ---------------------------------------------------------------------------
-- The vendor issues three query shapes and they do NOT share a prefix:
--
--   armour   class = 4 AND subclass = ? AND InventoryType = ? AND ItemLevel ...
--   weapons  class = 2 AND subclass IN (...)          AND ItemLevel ...
--   accessory                          InventoryType = ? AND ItemLevel ...
--
-- 🔴 The accessory branch (neck / back / finger / trinket) constrains NO class
-- or subclass at all, so a (class, subclass, ...) index cannot serve it -- a
-- leftmost-prefix miss. That branch is the one with the widest scan and it is
-- the easy one to overlook, hence the second index.
--
--   idx_dc_vendor_slot   (class, subclass, InventoryType, ItemLevel)
--   idx_dc_vendor_inv    (InventoryType, ItemLevel)
--
-- ItemLevel is last in both so the range predicate sits at the tail, where it
-- can still be used, and the leading equality columns do the narrowing.
--
-- Not covering indexes -- `name` is not included on purpose. Adding a 250-byte
-- prefix column to make them covering would cost far more space than the row
-- lookups save at LIMIT 60.
--
-- COST: two secondary indexes over 159,563 rows, a few MB each. Writes to
-- `item_template` are rare (imports, not gameplay), so the maintenance overhead
-- is irrelevant next to a single-threaded 389 ms stall.
--
-- 🔴 Uses ALTER TABLE ... ADD INDEX, which on MySQL 8 with InnoDB is ONLINE for
-- secondary indexes -- no table lock, safe on a live realm. Still cheaper to
-- run during a quiet moment.
--
-- Apply against acore_world. Idempotent -- guarded on information_schema so a
-- re-run is a no-op rather than a duplicate-key error.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. Armour and weapon lookups
-- ---------------------------------------------------------------------------
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'item_template'
     AND INDEX_NAME = 'idx_dc_vendor_slot') > 0,
  'SELECT ''idx_dc_vendor_slot already present'' AS note',
  'ALTER TABLE `item_template` ADD INDEX `idx_dc_vendor_slot` (`class`, `subclass`, `InventoryType`, `ItemLevel`)');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

-- ---------------------------------------------------------------------------
-- 2. Accessory lookups (neck / back / finger / trinket -- no class predicate)
-- ---------------------------------------------------------------------------
SET @sql := IF(
  (SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'item_template'
     AND INDEX_NAME = 'idx_dc_vendor_inv') > 0,
  'SELECT ''idx_dc_vendor_inv already present'' AS note',
  'ALTER TABLE `item_template` ADD INDEX `idx_dc_vendor_inv` (`InventoryType`, `ItemLevel`)');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Both indexes present (expect 2 rows):
-- SELECT INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME FROM information_schema.STATISTICS
-- WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'item_template'
--   AND INDEX_NAME IN ('idx_dc_vendor_slot', 'idx_dc_vendor_inv')
-- ORDER BY INDEX_NAME, SEQ_IN_INDEX;
--
-- The armour lookup should now report key = idx_dc_vendor_slot and a rows
-- estimate in the hundreds, not ~100,000:
-- EXPLAIN SELECT entry, name, ItemLevel FROM item_template
-- WHERE class = 4 AND subclass = 3 AND InventoryType = 9
--   AND ItemLevel BETWEEN 448 AND 452
--   AND (AllowableClass = 0 OR (AllowableClass & 64) != 0) AND Quality >= 3
-- ORDER BY ItemLevel DESC, name ASC LIMIT 60;
--
-- The accessory lookup should report key = idx_dc_vendor_inv:
-- EXPLAIN SELECT entry, name, ItemLevel FROM item_template
-- WHERE InventoryType = 2 AND ItemLevel BETWEEN 410 AND 414
--   AND (AllowableClass = 0 OR (AllowableClass & 64) != 0) AND Quality >= 3
-- ORDER BY ItemLevel DESC, name ASC LIMIT 80;
--
-- In game: click through several slots on both vendors and confirm the log no
-- longer prints `SLOW handler MPLUS|0x81`.
-- ---------------------------------------------------------------------------
