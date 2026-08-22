-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 7: creature_text + small extras
--
-- REQUIRES 03_templates.sql (offset creature_template) and 04_spawns.sql (guid maps).
--
-- ---------------------------------------------------------------------------------
-- WHY creature_text MATTERS MORE THAN IT LOOKS
-- ---------------------------------------------------------------------------------
-- The five ported boss scripts call Talk(...) 23 times between them -- SAY_AGGRO,
-- SAY_ASPHYXIATE, SAY_ANNOUNCE_STAY_OF_EXECUTION, SAY_DEATH and so on. Talk(n) does
-- nothing but look up (CreatureID = me->GetEntry(), GroupID = n) in creature_text. With
-- no rows the bosses are completely silent AND every call logs
--     CreatureTextMgr: Could not find Text for Creature ... GroupID n
-- once per pull. 86 rows cover it.
--
-- The schema is a clean 1:1 -- all 13 AzerothCore columns exist in cata_world.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. creature_text -- keyed by CreatureID, so only that column shifts. GroupID must NOT
--    change: it is the `n` in Talk(n) and the C++ enums (SAY_AGGRO = 1, ...) are fixed.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` BETWEEN 5000000 AND 5099999;
INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`,
     `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT t.CreatureID + 5000000, t.GroupID, t.ID, t.Text, t.Type, t.Language, t.Probability,
       t.Emote, t.Duration, t.Sound, t.BroadcastTextId, t.TextRange, t.comment
FROM `cata_world`.`creature_text` t
WHERE t.CreatureID IN (SELECT entry FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- 2. npc_spellclick_spells -- 1 row.
--
-- A spellclick row without the matching UNIT_NPC_FLAG_SPELLCLICK on the creature gives a
-- dead cursor, and the flag without a row does the same in reverse. npcflag came across
-- verbatim in 03, so the pair stays consistent.
-- -------------------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` BETWEEN 5000000 AND 5099999;
INSERT INTO `npc_spellclick_spells`
    (`npc_entry`, `spell_id`, `cast_flags`, `user_type`)
SELECT s.npc_entry + 5000000, s.spell_id, s.cast_flags, s.user_type
FROM `cata_world`.`npc_spellclick_spells` s
WHERE s.npc_entry IN (SELECT entry FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- 3. creature_summon_groups -- 2 rows.
--
-- Both summonerId AND the summoned `entry` are offset: a clone boss summoning the STOCK
-- add would put a classic-SFK creature inside the Cata instance.
-- `Comment` is absent upstream and left to its AzerothCore default.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_summon_groups` WHERE `summonerId` BETWEEN 5000000 AND 5099999;
INSERT INTO `creature_summon_groups`
    (`summonerId`, `summonerType`, `groupId`, `entry`, `position_x`, `position_y`,
     `position_z`, `orientation`, `summonType`, `summonTime`)
SELECT g.summonerId + 5000000, g.summonerType, g.groupId,
       IF(g.entry IN (SELECT entry FROM `dc_sfk825_ct_set`), g.entry + 5000000, g.entry),
       g.position_x, g.position_y, g.position_z, g.orientation, g.summonType, g.summonTime
FROM `cata_world`.`creature_summon_groups` g
WHERE g.summonerId IN (SELECT entry FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'creature_text rows (want 86)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_text` WHERE `CreatureID` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'npc_spellclick_spells (want 1)', CAST(COUNT(*) AS CHAR)
    FROM `npc_spellclick_spells` WHERE `npc_entry` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'creature_summon_groups (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_summon_groups` WHERE `summonerId` BETWEEN 5000000 AND 5099999
-- Each of the five bosses must have text, or it will pull in silence.
UNION ALL SELECT CONCAT('text groups for boss ', b.e), CAST(COUNT(t.GroupID) AS CHAR)
    FROM (SELECT 46962 + 5000000 e UNION SELECT 3887 + 5000000 UNION SELECT 4278 + 5000000
          UNION SELECT 46963 + 5000000 UNION SELECT 46964 + 5000000) b
    LEFT JOIN `creature_text` t ON t.CreatureID = b.e
    GROUP BY b.e
UNION ALL SELECT 'summon groups pointing at a STOCK entry (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_summon_groups`
    WHERE `summonerId` BETWEEN 5000000 AND 5099999 AND `entry` < 5000000
UNION ALL SELECT 'STOCK creature_text on 3887/4278 (unchanged)', CAST(COUNT(*) AS CHAR)
    FROM `creature_text` WHERE `CreatureID` IN (3887, 4278);
