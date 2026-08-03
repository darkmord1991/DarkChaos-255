-- ---------------------------------------------------------------------------
-- 241  Map 750 -- clear areatable_dbc overrides for the seven band zones
-- ---------------------------------------------------------------------------
-- The band rename ships in Custom/CSV DBC/AreaTable.csv (4929 "Darkshore
-- (80-90)" ... 4923 "Hyjal Frontier (113-130)", ExplorationLevel = band
-- start). The SQL override table `areatable_dbc` WINS over the DBC file --
-- 171_ documented the trap where a stale row made 4926 report as "Blackrock
-- Caverns" with AreaBit 0, silently killing exploration credit.
--
-- This file guarantees no override shadows the recompiled DBC for any of the
-- seven zones. Re-check after ANY later file touches areatable_dbc.
-- (information_schema.TABLE_ROWS is an estimate -- always COUNT(*).)
-- ---------------------------------------------------------------------------

DELETE FROM `areatable_dbc` WHERE `ID` IN (4923, 4926, 4927, 4928, 4929, 4930, 4931);

-- ---------------------------------------------------------------------------
-- Trailer -- verification (expect 0)
-- ---------------------------------------------------------------------------
-- SELECT COUNT(*) FROM areatable_dbc
-- WHERE ID IN (4923, 4926, 4927, 4928, 4929, 4930, 4931);
