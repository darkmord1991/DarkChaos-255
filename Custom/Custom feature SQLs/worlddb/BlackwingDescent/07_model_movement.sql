-- Blackwing Descent (map 669) — creature_model_info + creature_template_movement (flight)
--
-- creature_model_info: 38 of the 49 BWD boss/add display ids are missing in acore (bounding_radius/
--   combat_reach/gender). Imported from cata_world for the MISSING ones only (NOT EXISTS guard — the
--   DC pattern for shared reference data; existing stock rows are left untouched). These display ids
--   are the Cata placeholders that 01_creature_templates.sql put in creature_template_model; after the
--   model retroport bake, remap BOTH tables to the 500xxx CreatureDisplayInfo ids together.
--
-- creature_template_movement: FLIGHT PRESERVATION (Hyjal/Plaguelands hazard). cata_world has no
--   InhabitType/Flight; synthesize from nelt_world.creature_template.InhabitType IN (4,5,6,7) with the
--   proven Bucket-B formula (mirrors ReviewFixes/review_flying_npcs.sql). Lifts Omnotron-controller
--   42186, Pyrecraw 42764, Ivoroc 42767 (IT=4) and Nefarian 41376 (IT=7).
--   NOT handled here (see 01 flags_extra 0x200 + the boss scripts): Atramedes 41442 (scripted air phase),
--   Magmaw 41570 (stationary vehicle), Onyxia 41270 (transport passenger — must NOT get Flight).

-- ---------------------------------------------------------------------------
-- creature_model_info  (import only the missing BWD display ids)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT cmi.`DisplayID`, cmi.`BoundingRadius`, cmi.`CombatReach`, cmi.`Gender`, cmi.`DisplayID_Other_Gender`, 0
FROM `cata_world`.`creature_model_info` cmi
WHERE cmi.`DisplayID` IN (
    SELECT `modelid1` FROM `cata_world`.`creature_template` WHERE `modelid1` > 0 AND `entry` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506)
    UNION SELECT `modelid2` FROM `cata_world`.`creature_template` WHERE `modelid2` > 0 AND `entry` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506)
    UNION SELECT `modelid3` FROM `cata_world`.`creature_template` WHERE `modelid3` > 0 AND `entry` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506)
    UNION SELECT `modelid4` FROM `cata_world`.`creature_template` WHERE `modelid4` > 0 AND `entry` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506)
)
AND NOT EXISTS (SELECT 1 FROM `creature_model_info` a WHERE a.`DisplayID` = cmi.`DisplayID`);

-- ---------------------------------------------------------------------------
-- creature_template_movement  (Bucket-B flight synthesis from nelt_world.InhabitType)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506);

INSERT INTO `creature_template_movement`
    (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT
    n.`entry`, (n.`InhabitType` & 1), ((n.`InhabitType` >> 3) & 1), 1, 0, 0, 0, 0
FROM `nelt_world`.`creature_template` n
WHERE n.`entry` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506)
  AND n.`InhabitType` IN (4,5,6,7);
