-- =====================================================================================
-- Emerald Sanctum (map 824) -- creature templates  [RECALIBRATED]
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
-- Entry band 4030001-4030199. `lootid` == `entry` is a hard invariant on this server.
-- Re-runnable.
-- =====================================================================================


DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4030001 AND 4030199;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `rank`,
     `unit_class`, `type`, `lootid`, `AIName`, `ScriptName`, `MovementType`, `HealthModifier`,
     `DamageModifier`, `ArmorModifier`, `BaseAttackTime`, `flags_extra`, `RegenHealth`) VALUES
    (4030001, 'Erennius', 'The Sanctum Warden', 130, 130, 2, 16, 0, 3, 2, 7, 4030001, '', 'boss_erennius', 0, 350, 30, 1, 2000, 524288, 1),
    (4030002, 'Ysondre the Wakener', 'The Emerald Nightmare', 130, 130, 2, 16, 0, 3, 1, 2, 4030002, '', 'boss_wakener_ysondre', 0, 700, 40, 1, 2000, 524288, 1),
    (4030003, 'Lethon the Wakener', 'The Emerald Nightmare', 130, 130, 2, 16, 0, 3, 1, 2, 4030003, '', 'boss_wakener_lethon', 0, 700, 40, 1, 2000, 524288, 1),
    (4030004, 'Emeriss the Wakener', 'The Emerald Nightmare', 130, 130, 2, 16, 0, 3, 1, 2, 4030004, '', 'boss_wakener_emeriss', 0, 700, 40, 1, 2000, 524288, 1),
    (4030005, 'Taerar the Wakener', 'The Emerald Nightmare', 130, 130, 2, 16, 0, 3, 1, 2, 4030005, '', 'boss_wakener_taerar', 0, 700, 40, 1, 2000, 524288, 1),
    (4030101, 'Nightmare Whelp', NULL, 130, 130, 2, 16, 0, 0, 1, 2, 4030101, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4030102, 'Dreamscale Dryad', NULL, 130, 130, 2, 16, 0, 0, 2, 7, 4030102, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4030103, 'Verdant Horror', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4030103, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4030104, 'Dreamwarden', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4030104, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4030105, 'Fogcaller of the Dream', NULL, 130, 130, 2, 16, 0, 0, 8, 7, 4030105, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4030106, 'Nightmare Bloom', NULL, 130, 130, 2, 16, 0, 0, 1, 7, 4030106, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4030107, 'Slumbering Drakeling', NULL, 130, 130, 2, 16, 0, 1, 1, 2, 4030107, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4030108, 'Dream Corrupter', NULL, 130, 130, 2, 16, 0, 0, 8, 3, 4030108, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4030109, 'Rotbark Ancient', NULL, 130, 130, 2, 16, 0, 1, 1, 7, 4030109, 'SmartAI', '', 1, 50, 6, 1, 2000, 0, 1),
    (4030110, 'Emerald Wisp', NULL, 130, 130, 2, 16, 0, 0, 8, 4, 4030110, 'SmartAI', '', 1, 25, 4, 1, 2000, 0, 1),
    (4030151, 'Vethiss the Unwaking', 'Rare', 130, 130, 2, 16, 0, 2, 1, 2, 4030151, 'SmartAI', '', 1, 120, 12, 1, 2000, 0, 1),
    (4030152, 'Mother Rootwither', 'Rare', 130, 130, 2, 16, 0, 2, 2, 7, 4030152, 'SmartAI', '', 1, 120, 12, 1, 2000, 0, 1);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (4030001, 0, 503765, 1, 1, 0),
    (4030002, 0, 503757, 1, 1, 0),
    (4030003, 0, 503759, 1, 1, 0),
    (4030004, 0, 503761, 1, 1, 0),
    (4030005, 0, 503763, 1, 1, 0),
    (4030101, 0, 503773, 1, 1, 0),
    (4030102, 0, 503765, 1, 1, 0),
    (4030103, 0, 503771, 1, 1, 0),
    (4030104, 0, 27572, 1, 1, 0),
    (4030105, 0, 2723, 1, 1, 0),
    (4030106, 0, 503772, 1, 1, 0),
    (4030107, 0, 503773, 1, 1, 0),
    (4030108, 0, 503743, 1, 1, 0),
    (4030109, 0, 503770, 1, 1, 0),
    (4030110, 0, 32477, 1, 1, 0),
    (4030151, 0, 503763, 1, 1, 0),
    (4030152, 0, 503765, 1, 1, 0);

-- Effective HP at these levels, for reference when retuning:
--   4030001  Erennius                     mini     12,513,550 HP   dmg x30
--   4030002  Ysondre the Wakener          wakener  25,027,100 HP   dmg x40
--   4030003  Lethon the Wakener           wakener  25,027,100 HP   dmg x40
--   4030004  Emeriss the Wakener          wakener  25,027,100 HP   dmg x40
--   4030005  Taerar the Wakener           wakener  25,027,100 HP   dmg x40
--   4030101  Nightmare Whelp              trash       893,825 HP   dmg x4
--   4030102  Dreamscale Dryad             trash       893,825 HP   dmg x4
--   4030103  Verdant Horror               elite     1,787,650 HP   dmg x6
--   4030104  Dreamwarden                  elite     1,787,650 HP   dmg x6
--   4030105  Fogcaller of the Dream       trash       893,825 HP   dmg x4
--   4030106  Nightmare Bloom              trash       893,825 HP   dmg x4
--   4030107  Slumbering Drakeling         elite     1,787,650 HP   dmg x6
--   4030108  Dream Corrupter              trash       893,825 HP   dmg x4
--   4030109  Rotbark Ancient              elite     1,787,650 HP   dmg x6
--   4030110  Emerald Wisp                 trash       893,825 HP   dmg x4
--   4030151  Vethiss the Unwaking         rare      4,290,360 HP   dmg x12
--   4030152  Mother Rootwither            rare      4,290,360 HP   dmg x12

SELECT 'templates (want 17)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199
UNION ALL SELECT 'rows still on exp 0 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199 AND `exp` <> 2
UNION ALL SELECT 'lootid <> entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199 AND `lootid` <> `entry`
UNION ALL SELECT 'displays with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` BETWEEN 4030001 AND 4030199 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'rows with a C++ ScriptName (want 5)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199 AND `ScriptName` <> ''
UNION ALL SELECT 'rows with BOTH AIName and ScriptName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199
      AND `ScriptName` <> '' AND `AIName` <> ''
UNION ALL SELECT 'rows with NO AI at all (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4030001 AND 4030199
      AND `ScriptName` = '' AND `AIName` = ''
UNION ALL SELECT 'lowest boss HP (sanity, want > 10000000)', CAST(MIN(ROUND(c.basehp2 * t.`HealthModifier`)) AS CHAR)
    FROM `creature_template` t JOIN `creature_classlevelstats` c
      ON c.`level` = t.`minlevel` AND c.`class` = t.`unit_class`
    WHERE t.`entry` BETWEEN 4030001 AND 4030199 AND t.`flags_extra` = 524288;
