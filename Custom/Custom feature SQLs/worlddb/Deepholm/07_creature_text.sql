-- =====================================================================
-- Deepholm Downport  --  07  creature_text  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- 149 rows across 67 NPCs (boss/quest yells). Cata `SoundType` column dropped
-- (no column in this fork); everything else copies 1:1.
-- Scoped to Deepholm creature entries, excluding the 6 shared/stock infra ids.
-- =====================================================================

DELETE FROM `creature_text`
WHERE `CreatureID` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND `CreatureID` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);

INSERT INTO `creature_text`
(`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`,
 `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT t.`CreatureID`, t.`GroupID`, t.`ID`, t.`Text`, t.`Type`, t.`Language`, t.`Probability`,
 t.`Emote`, t.`Duration`, t.`Sound`, t.`BroadcastTextId`, t.`TextRange`, t.`comment`
FROM `cata_world`.`creature_text` t
WHERE t.`CreatureID` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646)
  AND t.`CreatureID` NOT IN (6491, 23837, 24110, 24288, 25670, 28332);
