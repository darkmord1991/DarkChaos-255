-- ═══════════════════════════════════════════════════════════════════════════════
-- DIAGNOSTIC: Delete All Player Item Upgrades
-- ═══════════════════════════════════════════════════════════════════════════════
-- 
-- PURPOSE: Clear all upgrade data to test if corrupted records are causing crash
-- 
-- ISSUE: Server crashes on login with upgraded items
-- HYPOTHESIS: Corrupted data in dc_player_item_upgrades table
-- TEST: Delete all data and try login - if no crash, data was corrupt
--
-- NOTE: This will permanently delete ALL player item upgrade progress!
--       Only run this for debugging purposes.
--
-- ═══════════════════════════════════════════════════════════════════════════════

-- STEP 1: Show current state (BEFORE cleanup)
SELECT 'BEFORE CLEANUP:' as status;
SELECT COUNT(*) as total_upgrades FROM dc_player_item_upgrades;

SELECT 
  player_guid, 
  COUNT(*) as upgrade_count,
  MIN(item_guid) as first_item,
  MAX(item_guid) as last_item
FROM dc_player_item_upgrades
GROUP BY player_guid
ORDER BY player_guid;

-- STEP 2: Backup data (optional - create backup table)
CREATE TABLE IF NOT EXISTS dc_player_item_upgrades_backup_nov8_2025 AS
SELECT * FROM dc_player_item_upgrades;

SELECT 'Backup created in dc_player_item_upgrades_backup_nov8_2025' as status;

-- STEP 3: DELETE ALL UPGRADES
DELETE FROM dc_player_item_upgrades;

SELECT 'All upgrade data deleted!' as status;

-- STEP 4: Show final state (AFTER cleanup)
SELECT 'AFTER CLEANUP:' as status;
SELECT COUNT(*) as total_upgrades FROM dc_player_item_upgrades;

-- ═══════════════════════════════════════════════════════════════════════════════
-- NEXT STEPS:
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- 1. Run this query on acore_characters database
--
-- 2. Restart server:
--    ./acore.sh run-worldserver
--
-- 3. Try logging in with previously upgraded character
--    - If login succeeds: Data was corrupt, need to investigate why
--    - If login still crashes: Different cause, not the upgrade data
--
-- 4. If this fixes it:
--    - Check backup table for issues:
--      SELECT * FROM dc_player_item_upgrades_backup_nov8_2025;
--    - Look for NULL values, invalid GUIDs, wrong timestamps, etc.
--
-- 5. To restore from backup (if needed):
--    INSERT INTO dc_player_item_upgrades 
--    SELECT * FROM dc_player_item_upgrades_backup_nov8_2025;
--
-- ═══════════════════════════════════════════════════════════════════════════════

-- VERIFICATION: Check table is now empty
SELECT 'VERIFICATION: Table should be empty now' as status;
DESCRIBE dc_player_item_upgrades;
