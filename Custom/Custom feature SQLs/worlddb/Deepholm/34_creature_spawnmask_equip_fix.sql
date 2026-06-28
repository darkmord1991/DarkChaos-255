-- =====================================================================
-- Deepholm Downport  --  34  Creature spawn cleanup (spawnMask + equip)
-- ---------------------------------------------------------------------
-- Two related Neltharion-import warnings, both from hardcoded defaults
-- in gen_neltharion_spawns.py:
--
-- A) spawnMask=1 (3,269 creatures)
--    AC's LoadCreatures() warns on every boot but does NOT skip them;
--    creatures load fine. Switching to 0 ("always spawn") silences the
--    flood of "wrong spawn mask 1 including not supported difficulty
--    modes for map (Id: 646)" lines.
--
-- B) equipment_id=-1 without a creature_equip_template row (143 entries)
--    equipment_id=-1 means "load from creature_equip_template" but 143
--    Deepholm entries have no row there (most are ambient mobs, bunnies,
--    elementals — nothing that would show a weapon anyway).  AC says
--    "set to no equipment" and continues. Switching to 0 ("no equipment")
--    produces the same result with no warning.
--
-- gen_neltharion_spawns.py is also patched to emit 0/0 so a future
-- regeneration of 30 doesn't reintroduce either warning.
-- =====================================================================

-- A) spawnMask 1 -> 0 for all Neltharion Deepholm creatures
UPDATE `creature`
SET    `spawnMask` = 0
WHERE  `map`  = 646
  AND  `guid` >= 9500000
  AND  `spawnMask` != 0;

-- B) equipment_id -1 -> 0 for entries that have no creature_equip_template row
--    (leaves equipment_id=-1 intact for the few entries that DO have a template)
UPDATE `creature` c
SET    c.`equipment_id` = 0
WHERE  c.`map`  = 646
  AND  c.`guid` >= 9500000
  AND  c.`equipment_id` = -1
  AND  NOT EXISTS (
         SELECT 1 FROM `creature_equip_template` cet
         WHERE cet.`CreatureID` = c.`id` AND cet.`ID` = 1
       );

-- Verify: expect 0 rows for both after this runs.
-- SELECT COUNT(*) FROM `creature` WHERE `map`=646 AND `guid`>=9500000 AND `spawnMask`!=0;
-- SELECT COUNT(*) FROM `creature` c WHERE c.`map`=646 AND c.`guid`>=9500000
--   AND c.`equipment_id`=-1
--   AND NOT EXISTS (SELECT 1 FROM `creature_equip_template` cet WHERE cet.`CreatureID`=c.`id` AND cet.`ID`=1);
