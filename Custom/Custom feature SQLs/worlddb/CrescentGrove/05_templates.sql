-- =====================================================================================
-- Crescent Grove (map 823) -- creature templates
--
-- Entry band 4020001-4020199. The 4,000,000-4,499,999 range was verified empty before
-- allocation. `lootid` == `entry` on every row: that is a hard invariant on this server
-- (see the map-750 loot fork), so never point a template at a foreign loot id.
--
-- DISPLAY IDS COME FROM THREE PLACES AND ALL THREE ARE DELIBERATE:
--   * 5037xx  -- models downported from retail 12.0.7 for these dungeons, already baked,
--                deployed to patch-G/H and compiled into CreatureDisplayInfo.
--   * 21631 / 23773 / 27358 / 34201 -- STOCK displays. The 3.3.5 client already ships
--                beargod, DireFurbolg, CrystalSatyr and AncientOfLore; downporting them
--                again shadowed the stock models and tripped the ERROR #132 gate, so the
--                stock ids are used instead. 21631 IS Ursoc, at scale 3.
--   * 50377x -- new combat-scale displays over models that had only been downported at
--                pet scale (0.3 / 0.5), which would otherwise give pet-sized bosses.
--
-- Creature display needs THREE layers and missing the third produces the misleading error
-- "has no model N defined in table `creature_template_model`":
--   1. CreatureDisplayInfo.dbc      (done, deployed)
--   2. creature_template_model      (below)
--   3. creature_model_info          (below -- server-side bounds)
--
-- Ranks are load-bearing: MythicDifficultyScaling picks the level column by rank
-- (3/2 -> *_level_boss, 1 -> *_level_elite, else *_level_normal), so every encounter boss
-- is rank 3 whether or not it is a "world boss" in the usual sense.
--
-- Re-runnable.
-- =====================================================================================


DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4020001 AND 4020199;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`,
     `unit_class`, `type`, `lootid`, `AIName`, `MovementType`, `HealthModifier`,
     `DamageModifier`, `ArmorModifier`, `BaseAttackTime`, `flags_extra`, `RegenHealth`) VALUES
    (4020001, 'Keeper Ranathos', 'Crescent Grove', 96, 96, 16, 0, 3, 2, 7, 4020001, '', 0, 25, 10, 1, 2000, 524288, 1),
    (4020002, 'Grovetender Engryss', 'Crescent Grove', 96, 96, 16, 0, 3, 1, 7, 4020002, '', 0, 25, 10, 1, 2000, 524288, 1),
    (4020005, 'High Priestess A''lathea', 'Crescent Grove', 96, 96, 16, 0, 3, 2, 7, 4020005, '', 0, 25, 10, 1, 2000, 524288, 1),
    (4020006, 'Fenektis the Deceiver', 'Crescent Grove', 96, 96, 16, 0, 3, 4, 3, 4020006, '', 0, 25, 10, 1, 2000, 524288, 1),
    (4020007, 'Master Raxxieth', 'Crescent Grove', 96, 96, 16, 0, 3, 1, 3, 4020007, '', 0, 30, 12, 1, 2000, 524288, 1),
    (4020003, 'Elder ''One Eye''', NULL, 96, 96, 16, 0, 2, 1, 7, 4020003, 'SmartAI', 1, 12, 6, 1, 2000, 0, 1),
    (4020004, 'Elder Blackmaw', NULL, 96, 96, 16, 0, 2, 2, 7, 4020004, 'SmartAI', 1, 12, 6, 1, 2000, 0, 1),
    (4020101, 'Shadowleaf Satyr', NULL, 95, 95, 16, 0, 0, 1, 3, 4020101, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4020102, 'Shadowleaf Trickster', NULL, 95, 95, 16, 0, 0, 8, 3, 4020102, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4020103, 'Vilethorn Lasher', NULL, 95, 95, 16, 0, 0, 1, 7, 4020103, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4020104, 'Grove Dryad', NULL, 95, 95, 16, 0, 0, 2, 7, 4020104, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4020105, 'Crescent Furbolg', NULL, 95, 95, 16, 0, 1, 1, 7, 4020105, 'SmartAI', 1, 5, 3, 1, 2000, 0, 1),
    (4020106, 'Vilethorn Ancient', NULL, 96, 96, 16, 0, 1, 1, 7, 4020106, 'SmartAI', 1, 6, 3, 1, 2000, 0, 1);

-- DisplayScale stays 1.0: the real per-variant factor is CreatureDisplayInfo
-- .CreatureModelScale, which was taken from the retail DB2. A hand-set DisplayScale
-- here is what produced microscopic creatures in the 2026-06 pet batch.
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (4020001, 0, 503751, 1, 1, 0),
    (4020002, 0, 503737, 1, 1, 0),
    (4020005, 0, 503753, 1, 1, 0),
    (4020006, 0, 503747, 1, 1, 0),
    (4020007, 0, 503755, 1, 1, 0),
    (4020003, 0, 503737, 1, 1, 0),
    (4020004, 0, 503737, 1, 1, 0),
    (4020101, 0, 503745, 1, 1, 0),
    (4020102, 0, 27358, 1, 1, 0),
    (4020103, 0, 503772, 1, 1, 0),
    (4020104, 0, 503753, 1, 1, 0),
    (4020105, 0, 503737, 1, 1, 0),
    (4020106, 0, 503771, 1, 1, 0);

-- Server-side bounds. Derived from each model's retail GeoBox x its display scale;
-- a blanket 0.306/1.5 is wrong for about half of them.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (503737, 503745, 503747, 503751, 503753, 503755, 503771, 503772);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`) VALUES
    (503737, 1.012, 3.036, 2),
    (503745, 0.932, 2.796, 2),
    (503747, 1.454, 4.362, 2),
    (503751, 1.204, 3.612, 2),
    (503753, 0.611, 1.833, 2),
    (503755, 2.828, 8.484, 2),
    (503771, 0.7, 2.5, 2),
    (503772, 0.55, 2.0, 2);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'templates (want 13)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199
UNION ALL SELECT 'template_model rows (want 13)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4020001 AND 4020199
UNION ALL SELECT 'lootid <> entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199 AND `lootid` <> `entry`
UNION ALL SELECT 'displays with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` BETWEEN 4020001 AND 4020199 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'bosses rank<>3 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199 AND `flags_extra` = 524288 AND `rank` <> 3;
