-- ---------------------------------------------------------------------------
-- 199  Hyjal -- restore the missing quest enders for Lycanthoth the Corruptor
-- ---------------------------------------------------------------------------
-- Found while auditing every hard-coded quest id in the map-750 C++ scripts.
-- Of the 27 ids checked, 25 were correct in every respect. These two were not:
--
--     25272 "Lycanthoth the Corruptor"  starter 3639432, ZERO enders
--     25273 "Lycanthoth the Corruptor"  starter 3639433, ZERO enders
--
-- Both are accepted from NPCs that DO spawn on map 750, so a player can take
-- them and then has no way to hand them in. cata_world has the enders; our
-- import never brought the relations across:
--     25272 -> 39622 Spirit of Lo'Gosh
--     25273 -> 39622 Spirit of Lo'Gosh  and  39627 Spirit of Goldrinn
--
-- Both creatures already have templates here at the +3,600,000 Hyjal band
-- (3639622 / 3639627), so only the relation rows are missing.
--
-- HONEST CAVEAT -- this makes the quests turn-in-able, it does not by itself
-- make them completable. Neither spirit has a SPAWN on map 750: they are event
-- creatures that appear during the Lycanthoth encounter. If they turn out never
-- to be summoned, that is a separate defect in the encounter, and this file is
-- still a prerequisite for fixing it -- without these rows the hand-in would
-- fail even with the spirit standing in front of you.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

DELETE FROM `creature_questender` WHERE `quest` IN (25272, 25273);

INSERT INTO `creature_questender` (`id`,`quest`)
SELECT e.`id` + 3600000, e.`quest`
FROM `cata_world`.`creature_questender` e
WHERE e.`quest` IN (25272, 25273)
  AND EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = e.`id` + 3600000);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT id, quest FROM creature_questender WHERE quest IN (25272,25273);
--     -- 3639622/25272, 3639622/25273, 3639627/25273
--
--   -- no map-750 quest referenced by a DC script has a starter but no ender
--   -- of either kind (expect 0):
--   SELECT COUNT(DISTINCT s.quest) FROM creature_queststarter s
--    WHERE s.id >= 3600000
--      AND NOT EXISTS (SELECT 1 FROM creature_questender e WHERE e.quest = s.quest)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_questender g WHERE g.quest = s.quest);
-- ---------------------------------------------------------------------------
