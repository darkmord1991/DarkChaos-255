-- =====================================================================
-- Deepholm Downport  --  36  Missing creature_text + SmartAI cleanup
-- ---------------------------------------------------------------------
-- Fixes two boot-time SmartAI warnings that reference creature_text
-- groups that were never imported or never existed.
--
-- A) Zoltrik Drakebane (44135)
--    SmartAI events id=2 (LINK→TALK group 1) and id=8 (SPELLHIT 82773
--    →TALK group 0) were imported from cata_world (file 12) but the
--    matching creature_text rows were not (file 07 filtered by creature
--    spawn map; this NPC is summoned, not stationed on map 646).
--    Source data confirmed correct in cata_world — import them.
--
-- B) Therazane (42465) — Elemental Bonds dialogue (groups 14 + 15)
--    SmartAI events id=6/7 use event_type=DATA_SET to play "Elemental
--    Bonds Talk" (4.2 Firelands patch content).  The text was NEVER
--    written in cata_world (0 rows).  These events can only fire via
--    C++ SetData(42465, 14/15), which we don't implement.  Deleting
--    the two dead SmartAI rows silences the load warning permanently
--    without losing any reachable functionality.
-- =====================================================================

-- A) Zoltrik Drakebane: import missing creature_text
DELETE FROM `creature_text` WHERE `CreatureID` = 44135 AND `GroupID` IN (0, 1);

INSERT INTO `creature_text`
  (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`,
   `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT
  `CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`,
  `Emote`, 0, 0, 0, 0, `Comment`
FROM `cata_world`.`creature_text`
WHERE `CreatureID` = 44135 AND `GroupID` IN (0, 1);

-- B) Therazane: remove dead Elemental Bonds SmartAI rows
DELETE FROM `smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` = 42465 AND `id` IN (6, 7);
