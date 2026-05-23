-- ========================================================================
-- DROP: Retire HLBG seasonal/archive tables (acore_chars)
-- ========================================================================
-- Purpose:
--   Remove tables owned by the retired HLBGSeasonalParticipant path after
--   seasonal leaderboard reads have been moved to unified HLBG tables/views.
--
-- Tables removed:
--   - dc_hlbg_season_config
--   - dc_hlbg_player_season_data
--   - dc_hlbg_player_history
--   - dc_hlbg_match_history
--   - dc_hlbg_season_<n>_matches (if any legacy season tables still exist)
--
-- Execution notes:
--   - Review PRECHECK output before running in production.
--   - If POSTCHECK still lists rows, stop and inspect permissions/errors.
-- ========================================================================

USE acore_chars;

SELECT 'PRECHECK' AS stage_gate,
       table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND (
    table_name IN (
      'dc_hlbg_season_config',
      'dc_hlbg_player_season_data',
      'dc_hlbg_player_history',
      'dc_hlbg_match_history'
    )
    OR table_name LIKE 'dc_hlbg_season\_%\_matches' ESCAPE '\\'
  )
ORDER BY table_name;

DROP PROCEDURE IF EXISTS `dc_drop_hlbg_seasonal_tables_20260523`;
DELIMITER //
CREATE PROCEDURE `dc_drop_hlbg_seasonal_tables_20260523`()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE table_name_to_drop VARCHAR(128);
  DECLARE drop_cursor CURSOR FOR
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
      AND (
        table_name IN (
          'dc_hlbg_season_config',
          'dc_hlbg_player_season_data',
          'dc_hlbg_player_history',
          'dc_hlbg_match_history'
        )
        OR table_name LIKE 'dc_hlbg_season\_%\_matches' ESCAPE '\\'
      )
    ORDER BY table_name;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN drop_cursor;

  drop_loop: LOOP
    FETCH drop_cursor INTO table_name_to_drop;
    IF done = 1 THEN
      LEAVE drop_loop;
    END IF;

    SET @dc_sql = CONCAT('DROP TABLE IF EXISTS `', REPLACE(table_name_to_drop, '`', '``'), '`');
    PREPARE dc_stmt FROM @dc_sql;
    EXECUTE dc_stmt;
    DEALLOCATE PREPARE dc_stmt;
  END LOOP;

  CLOSE drop_cursor;
END//
DELIMITER ;

CALL `dc_drop_hlbg_seasonal_tables_20260523`();

DROP PROCEDURE IF EXISTS `dc_drop_hlbg_seasonal_tables_20260523`;

SELECT 'POSTCHECK' AS stage_gate,
       table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND (
    table_name IN (
      'dc_hlbg_season_config',
      'dc_hlbg_player_season_data',
      'dc_hlbg_player_history',
      'dc_hlbg_match_history'
    )
    OR table_name LIKE 'dc_hlbg_season\_%\_matches' ESCAPE '\\'
  )
ORDER BY table_name;