-- =====================================================================================
-- Emerald Sanctum (map 824) -- creature templates
--
-- Entry band 4030001-4030199. The 4,000,000-4,499,999 range was verified empty before
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


DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4030001 AND 4030199;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `rank`,
     `unit_class`, `type`, `lootid`, `AIName`, `MovementType`, `HealthModifier`,
     `DamageModifier`, `ArmorModifier`, `BaseAttackTime`, `flags_extra`, `RegenHealth`) VALUES
    (4030001, 'Erennius', 'The Sanctum Warden', 130, 130, 16, 0, 3, 2, 7, 4030001, '', 0, 70, 35, 1, 2000, 524288, 1),
    (4030002, 'Ysondre the Wakener', 'The Emerald Nightmare', 130, 130, 16, 0, 3, 1, 2, 4030002, '', 0, 85, 40, 1, 2000, 524288, 1),
    (4030003, 'Lethon the Wakener', 'The Emerald Nightmare', 130, 130, 16, 0, 3, 1, 2, 4030003, '', 0, 85, 40, 1, 2000, 524288, 1),
    (4030004, 'Emeriss the Wakener', 'The Emerald Nightmare', 130, 130, 16, 0, 3, 1, 2, 4030004, '', 0, 85, 40, 1, 2000, 524288, 1),
    (4030005, 'Taerar the Wakener', 'The Emerald Nightmare', 130, 130, 16, 0, 3, 1, 2, 4030005, '', 0, 85, 40, 1, 2000, 524288, 1),
    (4030101, 'Nightmare Whelp', NULL, 130, 130, 16, 0, 0, 1, 2, 4030101, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4030102, 'Dreamscale Dryad', NULL, 130, 130, 16, 0, 0, 2, 7, 4030102, 'SmartAI', 1, 3, 2, 1, 2000, 0, 1),
    (4030103, 'Verdant Horror', NULL, 130, 130, 16, 0, 1, 1, 7, 4030103, 'SmartAI', 1, 6, 3, 1, 2000, 0, 1);

-- DisplayScale stays 1.0: the real per-variant factor is CreatureDisplayInfo
-- .CreatureModelScale, which was taken from the retail DB2. A hand-set DisplayScale
-- here is what produced microscopic creatures in the 2026-06 pet batch.
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (4030001, 0, 503765, 1, 1, 0),
    (4030002, 0, 503757, 1, 1, 0),
    (4030003, 0, 503759, 1, 1, 0),
    (4030004, 0, 503761, 1, 1, 0),
    (4030005, 0, 503763, 1, 1, 0),
    (4030101, 0, 503773, 1, 1, 0),
    (4030102, 0, 503765, 1, 1, 0),
    (4030103, 0, 503771, 1, 1, 0);

-- Server-side bounds. Derived from each model's retail GeoBox x its display scale;
-- a blanket 0.306/1.5 is wrong for about half of them.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (503757, 503759, 503761, 503763, 503765, 503771, 503773);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`) VALUES
    (503757, 3.0, 9.0, 2),
    (503759, 3.0, 9.0, 2),
    (503761, 3.0, 9.0, 2),
    (503763, 3.0, 9.0, 2),
    (503765, 0.621, 1.863, 2),
    (503771, 0.7, 2.5, 2),
    (503773, 0.55, 2.0, 2);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'templates (want 8)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199
UNION ALL SELECT 'template_model rows (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4030001 AND 4030199
UNION ALL SELECT 'lootid <> entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199 AND `lootid` <> `entry`
UNION ALL SELECT 'displays with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` BETWEEN 4030001 AND 4030199 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'bosses rank<>3 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199 AND `flags_extra` = 524288 AND `rank` <> 3;
