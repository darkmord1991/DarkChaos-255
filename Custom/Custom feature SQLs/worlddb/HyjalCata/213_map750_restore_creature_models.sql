-- ---------------------------------------------------------------------------
-- 213  Map 750 -- restore the creature models 212_ stripped
-- ---------------------------------------------------------------------------
-- URGENT REPAIR. Apply this before anything else.
--
-- WHAT HAPPENED -- my mistake in 212_, and a nasty one because it fails quietly.
-- Section C deleted `creature_template_model` for every entry in the port set
-- and then re-inserted from cata with:
--
--     SELECT m.CreatureID+3700000, m.Idx, m.CreatureDisplayID,
--            m.DisplayScale, m.Probability, 0
--     FROM cata_world.creature_template_model m
--
-- `cata_world`.`creature_template_model` HAS NO `DisplayScale` COLUMN. It is
-- (CreatureID, Idx, CreatureDisplayID, Probability, VerifiedBuild) -- five
-- columns against our six. So that statement is an "Unknown column
-- 'm.DisplayScale'" error.
--
-- `mysql source` does not stop on error, so the DELETE committed and the INSERT
-- did not. Result: 190 creature entries / 3,862 spawns on map 750 lost their
-- models and every one of them now refuses to load with
--     "Creature (Entry: 3704075) has no model defined in table
--      `creature_template_model`, can't load."
-- That includes creatures that were working fine before 212_ -- Rat, Timbermaw
-- Warder, Timbermaw Mystic, Winterfall Runner -- because they were in the port
-- set (some of their spawns were missing) and so were caught by the DELETE.
--
-- I verified the schemas of `creature_template` and `gameobject_template`
-- before writing those sections and assumed this third table matched. It does
-- not. 212_ has been corrected in place, so a future run is safe; this file
-- repairs the database as it stands now.
--
-- NOTHING IS LOST -- checked before writing: all 190 entries are recoverable.
--   106 entries (143 rows) still have their stock rows here at the RAW id, and
--       those carry a real DisplayScale. These are the pre-existing map-750
--       creatures, so they get restored exactly as they were.
--    84 entries (125 rows) are the genuinely new Cata creatures 212_ added and
--       exist only in cata, where DisplayScale is written as 1.
--     0 entries have no model in either source.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- Requires `dc_map750_zoneport`, which 212_ left behind.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Restore from our own rows first -- they carry the real DisplayScale
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `creature_template_model`
    (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.`CreatureID` + 3700000, m.`Idx`, m.`CreatureDisplayID`,
       m.`DisplayScale`, m.`Probability`, 0
FROM `creature_template_model` m
WHERE m.`CreatureID` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)
  AND m.`CreatureDisplayID` > 0;

-- ---------------------------------------------------------------------------
-- B) Fill the rest from cata -- no DisplayScale column there, so 1
-- ---------------------------------------------------------------------------
-- INSERT IGNORE means this only supplies (CreatureID, Idx) pairs section A did
-- not already provide, so a creature that exists in both keeps OUR scale.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `creature_template_model`
    (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.`CreatureID` + 3700000, m.`Idx`, m.`CreatureDisplayID`,
       1, m.`Probability`, 0
FROM `cata_world`.`creature_template_model` m
WHERE m.`CreatureID` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)
  AND m.`CreatureDisplayID` > 0;

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   -- every map-750 spawn resolves to a model again (expect 0):
--   SELECT COUNT(*) FROM creature c
--    WHERE c.map = 750
--      AND NOT EXISTS (SELECT 1 FROM creature_template_model m WHERE m.CreatureID = c.id);
--
--   -- the 190 entries are covered (expect 190):
--   SELECT COUNT(DISTINCT m.CreatureID) FROM creature_template_model m
--    WHERE m.CreatureID IN (SELECT DISTINCT src_id + 3700000 FROM dc_map750_zoneport);
--
--   -- spot-check the four named in the report (expect 3, 1, 1, 1 rows):
--   SELECT CreatureID, COUNT(*) FROM creature_template_model
--    WHERE CreatureID IN (3704075, 3711516, 3711552, 3710916) GROUP BY CreatureID;
--
-- Errors.log should gain no further "has no model defined" lines. The Timbermaw
-- camp, the Winterfall furbolgs and the Ashenvale/Winterspring imports should
-- all be visible again.
-- ---------------------------------------------------------------------------
