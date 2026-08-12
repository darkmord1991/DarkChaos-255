-- =====================================================================================
-- Crescent Grove (map 823) -- creature templates  [RECALIBRATED]
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
-- Entry band 4020001-4020199. `lootid` == `entry` is a hard invariant on this server.
-- Re-runnable.
-- =====================================================================================


DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 4020001 AND 4020199;
DELETE FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199;

INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `rank`,
     `unit_class`, `type`, `lootid`, `AIName`, `ScriptName`, `MovementType`, `HealthModifier`,
     `DamageModifier`, `ArmorModifier`, `BaseAttackTime`, `flags_extra`, `RegenHealth`) VALUES
    (4020001, 'Keeper Ranathos', 'Crescent Grove', 96, 96, 2, 16, 0, 3, 2, 7, 4020001, '', 'boss_keeper_ranathos', 0, 150, 12, 1, 2000, 524288, 1),
    (4020002, 'Grovetender Engryss', 'Crescent Grove', 96, 96, 2, 16, 0, 3, 1, 7, 4020002, '', 'boss_grovetender_engryss', 0, 150, 12, 1, 2000, 524288, 1),
    (4020005, 'High Priestess A''lathea', 'Crescent Grove', 96, 96, 2, 16, 0, 3, 2, 7, 4020005, '', 'boss_high_priestess_alathea', 0, 150, 12, 1, 2000, 524288, 1),
    (4020006, 'Fenektis the Deceiver', 'Crescent Grove', 96, 96, 2, 16, 0, 3, 4, 3, 4020006, '', 'boss_fenektis_the_deceiver', 0, 150, 12, 1, 2000, 524288, 1),
    (4020007, 'Master Raxxieth', 'Crescent Grove', 96, 96, 2, 16, 0, 3, 1, 3, 4020007, '', 'boss_master_raxxieth', 0, 200, 15, 1, 2000, 524288, 1),
    (4020003, 'Elder ''One Eye''', NULL, 96, 96, 2, 16, 0, 2, 1, 7, 4020003, '', 'npc_crescent_grove_elder', 0, 75, 8, 1, 2000, 0, 1),
    (4020004, 'Elder Blackmaw', NULL, 96, 96, 2, 16, 0, 2, 2, 7, 4020004, '', 'npc_crescent_grove_elder', 0, 75, 8, 1, 2000, 0, 1),
    (4020101, 'Shadowleaf Satyr', NULL, 95, 95, 2, 16, 0, 1, 1, 3, 4020101, 'SmartAI', '', 1, 30, 5, 1, 2000, 0, 1),
    (4020102, 'Shadowleaf Trickster', NULL, 95, 95, 2, 16, 0, 0, 4, 3, 4020102, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020103, 'Shadowleaf Soothsayer', NULL, 95, 95, 2, 16, 0, 0, 8, 3, 4020103, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020104, 'Shadowleaf Bloodpriest', NULL, 95, 95, 2, 16, 0, 0, 2, 3, 4020104, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020105, 'Vilethorn Lasher', NULL, 95, 95, 2, 16, 0, 0, 1, 7, 4020105, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020106, 'Vilethorn Ancient', NULL, 96, 96, 2, 16, 0, 1, 1, 7, 4020106, 'SmartAI', '', 1, 30, 5, 1, 2000, 0, 1),
    (4020107, 'Grove Dryad', NULL, 95, 95, 2, 16, 0, 0, 2, 7, 4020107, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020108, 'Wildkin of the Crescent', NULL, 95, 95, 2, 16, 0, 0, 1, 7, 4020108, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020109, 'Crescent Furbolg', NULL, 95, 95, 2, 16, 0, 1, 1, 7, 4020109, 'SmartAI', '', 1, 30, 5, 1, 2000, 0, 1),
    (4020110, 'Moonwell Guardian', NULL, 95, 95, 2, 16, 0, 0, 2, 7, 4020110, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020111, 'Felbound Houndmaster', NULL, 95, 95, 2, 16, 0, 0, 1, 3, 4020111, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020112, 'Corrupted Treant', NULL, 95, 95, 2, 16, 0, 0, 1, 7, 4020112, 'SmartAI', '', 1, 15, 3, 1, 2000, 0, 1),
    (4020151, 'Thornmaw', 'Rare', 96, 96, 2, 16, 0, 2, 1, 7, 4020151, 'SmartAI', '', 1, 45, 7, 1, 2000, 0, 1),
    (4020152, 'Sister Nightbloom', 'Rare', 96, 96, 2, 16, 0, 2, 2, 7, 4020152, 'SmartAI', '', 1, 45, 7, 1, 2000, 0, 1),
    (4020153, 'Xar''thek the Whisperer', 'Rare', 96, 96, 2, 16, 0, 2, 8, 3, 4020153, 'SmartAI', '', 1, 45, 7, 1, 2000, 0, 1);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
    (4020001, 0, 503751, 1, 1, 0),
    (4020002, 0, 503737, 1, 1, 0),
    (4020005, 0, 503753, 1, 1, 0),
    (4020006, 0, 503747, 1, 1, 0),
    (4020007, 0, 503755, 1, 1, 0),
    (4020003, 0, 503737, 1, 1, 0),
    (4020004, 0, 2003, 1, 1, 0),
    (4020101, 0, 503745, 1, 1, 0),
    (4020102, 0, 27358, 1, 1, 0),
    (4020103, 0, 2878, 1, 1, 0),
    (4020104, 0, 11331, 1, 1, 0),
    (4020105, 0, 503772, 1, 1, 0),
    (4020106, 0, 503771, 1, 1, 0),
    (4020107, 0, 503753, 1, 1, 0),
    (4020108, 0, 27572, 1, 1, 0),
    (4020109, 0, 503737, 1, 1, 0),
    (4020110, 0, 2723, 1, 1, 0),
    (4020111, 0, 2019, 1, 1, 0),
    (4020112, 0, 2012, 1, 1, 0),
    (4020151, 0, 503771, 1, 1, 0),
    (4020152, 0, 503753, 1, 1, 0),
    (4020153, 0, 503747, 1, 1, 0);

-- Effective HP at these levels, for reference when retuning:
--   4020001  Keeper Ranathos              boss      2,996,550 HP   dmg x12
--   4020002  Grovetender Engryss          boss      2,996,550 HP   dmg x12
--   4020005  High Priestess A'lathea      boss      2,996,550 HP   dmg x12
--   4020006  Fenektis the Deceiver        boss      2,996,550 HP   dmg x12
--   4020007  Master Raxxieth              final     3,995,400 HP   dmg x15
--   4020003  Elder 'One Eye'              elder     1,498,275 HP   dmg x8
--   4020004  Elder Blackmaw               elder     1,498,275 HP   dmg x8
--   4020101  Shadowleaf Satyr             elite       585,390 HP   dmg x5
--   4020102  Shadowleaf Trickster         trash       292,695 HP   dmg x3
--   4020103  Shadowleaf Soothsayer        trash       292,695 HP   dmg x3
--   4020104  Shadowleaf Bloodpriest       trash       292,695 HP   dmg x3
--   4020105  Vilethorn Lasher             trash       292,695 HP   dmg x3
--   4020106  Vilethorn Ancient            elite       599,310 HP   dmg x5
--   4020107  Grove Dryad                  trash       292,695 HP   dmg x3
--   4020108  Wildkin of the Crescent      trash       292,695 HP   dmg x3
--   4020109  Crescent Furbolg             elite       585,390 HP   dmg x5
--   4020110  Moonwell Guardian            trash       292,695 HP   dmg x3
--   4020111  Felbound Houndmaster         trash       292,695 HP   dmg x3
--   4020112  Corrupted Treant             trash       292,695 HP   dmg x3
--   4020151  Thornmaw                     rare        898,965 HP   dmg x7
--   4020152  Sister Nightbloom            rare        898,965 HP   dmg x7
--   4020153  Xar'thek the Whisperer       rare        898,965 HP   dmg x7

SELECT 'templates (want 22)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199
UNION ALL SELECT 'rows still on exp 0 (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199 AND `exp` <> 2
UNION ALL SELECT 'lootid <> entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199 AND `lootid` <> `entry`
UNION ALL SELECT 'displays with no creature_model_info (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` m LEFT JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`
    WHERE m.`CreatureID` BETWEEN 4020001 AND 4020199 AND i.`DisplayID` IS NULL
UNION ALL SELECT 'rows with a C++ ScriptName (want 7)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199 AND `ScriptName` <> ''
UNION ALL SELECT 'rows with BOTH AIName and ScriptName (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199
      AND `ScriptName` <> '' AND `AIName` <> ''
UNION ALL SELECT 'rows with NO AI at all (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 4020001 AND 4020199
      AND `ScriptName` = '' AND `AIName` = ''
UNION ALL SELECT 'lowest boss HP (sanity, want > 10000000)', CAST(MIN(ROUND(c.basehp2 * t.`HealthModifier`)) AS CHAR)
    FROM `creature_template` t JOIN `creature_classlevelstats` c
      ON c.`level` = t.`minlevel` AND c.`class` = t.`unit_class`
    WHERE t.`entry` BETWEEN 4020001 AND 4020199 AND t.`flags_extra` = 524288;
