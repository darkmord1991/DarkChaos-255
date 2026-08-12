-- =====================================================================================
-- Timbermaw Hold (map 819) -- creature templates  [RECALIBRATED]
--
-- exp = 2 ON EVERY ROW. `creature_template.exp` selects BOTH the health and the damage column
-- in creature_classlevelstats: exp 0 -> basehp0 / damage_base, exp 2 -> basehp2 / damage_exp2.
-- At level 130 that is 13,791 vs 35,753 HP and a 4.6x damage difference. The first version of
-- this file omitted the column, so it defaulted to 0 and every creature came out roughly a
-- quarter of its intended size. Level-130 content on this server (Malfurion 3652135, the
-- Giant Isles world bosses) all use exp 2.
--
-- Modifiers calibrated against real references, not guessed:
--     Oondasta    lvl 82  exp 2  HM 2000  ->  26.9M HP, dmg 50
--     Malfurion   lvl 130 exp 2  HM  500  ->  17.9M HP, dmg 35
-- effective HP = basehp2(level, unit_class) x HealthModifier, so the numbers below are exact.
--
-- Ranks are load-bearing: MythicDifficultyScaling picks the level column by rank (3/2 ->
-- *_level_boss, 1 -> *_level_elite, else *_level_normal). Rare elites are rank 2 so they scale
-- like bosses rather than like trash.
--
-- `ScriptName` IS SET HERE, not only in 11_boss_scripts.sql. This file DELETEs and re-INSERTs
-- the whole entry band, so a re-run used to reset ScriptName to '' and leave the bosses with
-- NO AI AT ALL -- no error, they simply stand and melee. Emitting it here makes 05 and 11
-- order-independent; 11 is now just an idempotent re-assert.
--
-- Everything without a C++ script gets `AIName` = 'SmartAI' and its behaviour from
-- 14_trash_smartai.sql. The two columns are mutually exclusive: a row with both logs
-- "has ScriptName set but AIName is set to SmartAI" and the C++ AI loses.
--
-- Entry band 4010001-4010199. `lootid` == `entry` is a hard invariant on this server.
-- Re-runnable.
-- =====================================================================================


DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4010001 AND 4010199;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `rank`,
     `unit_class`, `type`, `lootid`, `AIName`, `ScriptName`, `MovementType`, `HealthModifier`,
     `DamageModifier`, `ArmorModifier`, `BaseAttackTime`, `flags_extra`, `RegenHealth`) VALUES
    (4010001, 'Gatewarden Mor''thak', 'Timbermaw Hold', 130, 130, 2, 16, 0, 3, 1, 7, 4010001, '', 'boss_gatewarden_morthak', 0, 500, 35, 1, 2000, 524288, 1),
    (4010002, 'The Sundered Chieftain', 'Timbermaw Hold', 130, 130, 2, 16, 0, 3, 2, 7, 4010002, '', 'boss_sundered_chieftain', 0, 500, 35, 1, 2000, 524288, 1),
    (4010003, 'Den Mother Ursara', 'Timbermaw Hold', 130, 130, 2, 16, 0, 3, 1, 1, 4010003, '', 'boss_den_mother_ursara', 0, 500, 35, 1, 2000, 524288, 1),
    (4010004, 'Xanthir the Defiler', 'Timbermaw Hold', 130, 130, 2, 16, 0, 3, 8, 3, 4010004, '', 'boss_xanthir_the_defiler', 0, 500, 35, 1, 2000, 524288, 1),
    (4010005, 'The Nightmare Given Root', 'Timbermaw Hold', 130, 130, 2, 16, 0, 3, 1, 7, 4010005, '', 'boss_nightmare_given_root', 0, 500, 35, 1, 2000, 524288, 1),
    (4010006, 'Ursol', 'The Sleeping Twin', 130, 130, 2, 16, 0, 3, 2, 1, 4010006, '', 'boss_ursol', 0, 600, 38, 1, 2000, 524288, 1),
    (4010007, 'Ursoc', 'The Raging Twin', 130, 130, 2, 16, 0, 3, 1, 1, 4010007, '', 'boss_ursoc', 0, 800, 45, 1, 2000, 524288, 1),
    (4010101, 'Timbermaw Denguard', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4010101, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4010102, 'Timbermaw Bonecrusher', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4010102, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4010103, 'Timbermaw Ritualist', NULL, 130, 130, 2, 16, 0, 0, 2, 7, 4010103, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010104, 'Timbermaw Dreamspeaker', NULL, 130, 130, 2, 16, 0, 0, 8, 7, 4010104, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010105, 'Timbermaw Totemcaller', NULL, 130, 130, 2, 16, 0, 0, 2, 7, 4010105, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010106, 'Nightmare-Touched Furbolg', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4010106, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4010107, 'Corrupted Denwatcher', NULL, 130, 130, 2, 16, 0, 1, 1, 1, 4010107, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4010108, 'Ravening Denbeast', NULL, 130, 130, 2, 16, 0, 0, 1, 1, 4010108, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010109, 'Nightmare Satyr', NULL, 130, 130, 2, 16, 0, 0, 8, 3, 4010109, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010110, 'Shadowhorn Trickster', NULL, 130, 130, 2, 16, 0, 0, 4, 3, 4010110, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010111, 'Rooted Horror', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4010111, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4010112, 'Nightmare Sapling', NULL, 130, 130, 2, 16, 0, 0, 1, 7, 4010112, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4010151, 'Elder Growl-of-Stone', 'Rare', 130, 130, 2, 16, 0, 2, 1, 1, 4010151, 'SmartAI', '', 1, 120, 12, 1, 2000, 0, 1),
    (4010152, 'Vor''thak the Hollow', 'Rare', 130, 130, 2, 16, 0, 2, 1, 7, 4010152, 'SmartAI', '', 1, 120, 12, 1, 2000, 0, 1),
    (4010153, 'The Sleepless Root', 'Rare', 130, 130, 2, 16, 0, 2, 1, 7, 4010153, 'SmartAI', '', 1, 120, 12, 1, 2000, 0, 1);

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
    (4010102, 0, 2003, 1, 1, 0),
    (4010103, 0, 6746, 1, 1, 0),
    (4010104, 0, 3028, 1, 1, 0),
    (4010105, 0, 2000, 1, 1, 0),
    (4010106, 0, 503739, 1, 1, 0),
    (4010107, 0, 6825, 1, 1, 0),
    (4010108, 0, 23999, 1, 1, 0),
    (4010109, 0, 503743, 1, 1, 0),
    (4010110, 0, 11345, 1, 1, 0),
    (4010111, 0, 503771, 1, 1, 0),
    (4010112, 0, 503772, 1, 1, 0),
    (4010151, 0, 23999, 1, 1, 0),
    (4010152, 0, 503739, 1, 1, 0),
    (4010153, 0, 503770, 1, 1, 0);

-- Effective HP at these levels, for reference when retuning:
--   4010001  Gatewarden Mor'thak          boss     17,876,500 HP   dmg x35
--   4010002  The Sundered Chieftain       boss     17,876,500 HP   dmg x35
--   4010003  Den Mother Ursara            boss     17,876,500 HP   dmg x35
--   4010004  Xanthir the Defiler          boss     17,876,500 HP   dmg x35
--   4010005  The Nightmare Given Root     boss     17,876,500 HP   dmg x35
--   4010006  Ursol                        twin     21,451,800 HP   dmg x38
--   4010007  Ursoc                        final    28,602,400 HP   dmg x45
--   4010101  Timbermaw Denguard           elite     1,787,650 HP   dmg x6
--   4010102  Timbermaw Bonecrusher        elite     1,787,650 HP   dmg x6
--   4010103  Timbermaw Ritualist          trash       893,825 HP   dmg x4
--   4010104  Timbermaw Dreamspeaker       trash       893,825 HP   dmg x4
--   4010105  Timbermaw Totemcaller        trash       893,825 HP   dmg x4
--   4010106  Nightmare-Touched Furbolg    elite     1,787,650 HP   dmg x6
--   4010107  Corrupted Denwatcher         elite     1,787,650 HP   dmg x6
--   4010108  Ravening Denbeast            trash       893,825 HP   dmg x4
--   4010109  Nightmare Satyr              trash       893,825 HP   dmg x4
--   4010110  Shadowhorn Trickster         trash       893,825 HP   dmg x4
--   4010111  Rooted Horror                elite     1,787,650 HP   dmg x6
--   4010112  Nightmare Sapling            trash       893,825 HP   dmg x4
--   4010151  Elder Growl-of-Stone         rare      4,290,360 HP   dmg x12
--   4010152  Vor'thak the Hollow          rare      4,290,360 HP   dmg x12
--   4010153  The Sleepless Root           rare      4,290,360 HP   dmg x12

SELECT 'templates (want 22)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199
UNION ALL SELECT 'rows still on exp 0 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199 AND `exp` <> 2
UNION ALL SELECT 'lootid <> entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199 AND `lootid` <> `entry`
UNION ALL SELECT 'displays with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` BETWEEN 4010001 AND 4010199 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'rows with a C++ ScriptName (want 7)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199 AND `ScriptName` <> ''
UNION ALL SELECT 'rows with BOTH AIName and ScriptName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199
      AND `ScriptName` <> '' AND `AIName` <> ''
UNION ALL SELECT 'rows with NO AI at all (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4010001 AND 4010199
      AND `ScriptName` = '' AND `AIName` = ''
UNION ALL SELECT 'lowest boss HP (sanity, want > 10000000)', CAST(MIN(ROUND(c.basehp2 * t.`HealthModifier`)) AS CHAR)
    FROM `creature_template` t JOIN `creature_classlevelstats` c
      ON c.`level` = t.`minlevel` AND c.`class` = t.`unit_class`
    WHERE t.`entry` BETWEEN 4010001 AND 4010199 AND t.`flags_extra` = 524288;
