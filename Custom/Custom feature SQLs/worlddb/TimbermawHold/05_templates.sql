-- =====================================================================================
-- Timbermaw Hold (map 819) -- creature templates
--
-- Entry band 4010001-4010199. The 4,000,000-4,499,999 range was verified empty before
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


DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4010001 AND 4010199;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`,
     `unit_class`, `type`, `lootid`, `AIName`, `MovementType`, `HealthModifier`,
     `DamageModifier`, `ArmorModifier`, `BaseAttackTime`, `flags_extra`, `RegenHealth`) VALUES
    (4010001, 'Gatewarden Mor''thak', 'Timbermaw Hold', 130, 130, 16, 0, 3, 1, 7, 4010001, '', 0, 70, 35, 1, 2000, 524288, 1),
    (4010002, 'The Sundered Chieftain', 'Timbermaw Hold', 130, 130, 16, 0, 3, 2, 7, 4010002, '', 0, 70, 35, 1, 2000, 524288, 1),
    (4010003, 'Den Mother Ursara', 'Timbermaw Hold', 130, 130, 16, 0, 3, 1, 1, 4010003, '', 0, 70, 35, 1, 2000, 524288, 1),
    (4010004, 'Xanthir the Defiler', 'Timbermaw Hold', 130, 130, 16, 0, 3, 8, 3, 4010004, '', 0, 70, 35, 1, 2000, 524288, 1),
    (4010005, 'The Nightmare Given Root', 'Timbermaw Hold', 130, 130, 16, 0, 3, 1, 7, 4010005, '', 0, 75, 35, 1, 2000, 524288, 1),
    (4010006, 'Ursol', 'The Sleeping Twin', 130, 130, 16, 0, 3, 2, 1, 4010006, '', 0, 80, 35, 1, 2000, 524288, 1),
    (4010007, 'Ursoc', 'The Raging Twin', 130, 130, 16, 0, 3, 1, 1, 4010007, '', 0, 90, 45, 1, 2000, 524288, 1),
    (4010101, 'Timbermaw Denguard', NULL, 130, 130, 16, 0, 1, 1, 7, 4010101, 'SmartAI', 1, 6, 3, 1, 2000, 0, 1),
    (4010102, 'Timbermaw Ritualist', NULL, 130, 130, 16, 0, 0, 2, 7, 4010102, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4010103, 'Nightmare-Touched Furbolg', NULL, 130, 130, 16, 0, 1, 1, 7, 4010103, 'SmartAI', 1, 6, 3, 1, 2000, 0, 1),
    (4010104, 'Corrupted Denwatcher', NULL, 130, 130, 16, 0, 1, 1, 1, 4010104, 'SmartAI', 1, 6, 3, 1, 2000, 0, 1),
    (4010105, 'Nightmare Satyr', NULL, 130, 130, 16, 0, 0, 8, 3, 4010105, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4010106, 'Rooted Horror', NULL, 130, 130, 16, 0, 1, 1, 7, 4010106, 'SmartAI', 1, 6, 3, 1, 2000, 0, 1);

-- DisplayScale stays 1.0: the real per-variant factor is CreatureDisplayInfo
-- .CreatureModelScale, which was taken from the retail DB2. A hand-set DisplayScale
-- here is what produced microscopic creatures in the 2026-06 pet batch.
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (4010001, 0, 503739, 1, 1, 0),
    (4010002, 0, 503737, 1, 1, 0),
    (4010003, 0, 23773, 1, 1, 0),
    (4010004, 0, 503743, 1, 1, 0),
    (4010005, 0, 503770, 1, 1, 0),
    (4010006, 0, 503735, 1, 1, 0),
    (4010007, 0, 21631, 1, 1, 0),
    (4010101, 0, 503737, 1, 1, 0),
    (4010102, 0, 503737, 1, 1, 0),
    (4010103, 0, 503739, 1, 1, 0),
    (4010104, 0, 23773, 1, 1, 0),
    (4010105, 0, 503743, 1, 1, 0),
    (4010106, 0, 503771, 1, 1, 0);

-- Server-side bounds. Derived from each model's retail GeoBox x its display scale;
-- a blanket 0.306/1.5 is wrong for about half of them.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (503735, 503737, 503739, 503743, 503770, 503771);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`) VALUES
    (503735, 2.354, 7.062, 2),
    (503737, 1.012, 3.036, 2),
    (503739, 1.464, 4.392, 2),
    (503743, 1.565, 4.695, 2),
    (503770, 1.2, 4.0, 2),
    (503771, 0.7, 2.5, 2);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'templates (want 13)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199
UNION ALL SELECT 'template_model rows (want 13)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4010001 AND 4010199
UNION ALL SELECT 'lootid <> entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199 AND `lootid` <> `entry`
UNION ALL SELECT 'displays with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` BETWEEN 4010001 AND 4010199 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'bosses rank<>3 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199 AND `flags_extra` = 524288 AND `rank` <> 3;
