-- ========================================================================
-- DROP: Retire dead HLBG state table (acore_chars)
-- ========================================================================
-- Purpose:
--   Remove dc_hlbg_state after the HLBG runtime migration off OutdoorPvPHL.
--
-- Execution notes:
--   - This table is no longer referenced by live HLBG code.
--   - If PRECHECK reports table_exists = 0, the migration is already satisfied.
--   - If POSTCHECK reports table_exists = 1, stop and inspect permissions/errors.
-- ========================================================================

USE acore_chars;

SELECT 'PRECHECK' AS stage_gate,
       COUNT(*) AS table_exists
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name = 'dc_hlbg_state';

DROP TABLE IF EXISTS `dc_hlbg_state`;

SELECT 'POSTCHECK' AS stage_gate,
       COUNT(*) AS table_exists
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name = 'dc_hlbg_state';