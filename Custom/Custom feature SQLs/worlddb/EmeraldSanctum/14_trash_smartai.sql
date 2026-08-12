-- =====================================================================================
-- Emerald Sanctum (map 824) -- SmartAI for trash and rare elites
--
-- 05_templates.sql sets `AIName` = 'SmartAI' on every non-boss row in this band. Without the
-- rows below that is a NO-OP THAT LOGS NOTHING: the creature loads an empty script and does
-- nothing but auto-attack. So until this file is applied, the "Ritualist", "Dreamspeaker" and
-- "Totemcaller" fight exactly like each other and like a boar.
--
-- 12 creatures, 8 distinct kits. Roles are deliberately readable from the name:
--   tanky/striker/brute  melee, differing in burst vs sustain vs self-buff
--   caster/firecaster/mooncaster  ranged damage on different schools
--   healer      casts Healing Touch on a wounded friendly -- THE interrupt check in trash
--   control     Fear / Curse of Tongues, punishes bad pack positioning
--   nightmare   Creature of Nightmare, the Emerald Dream signature
--   plant/ancient  rooted hazards and Thorns
--   drake       Noxious Breath + Tail Sweep, dragonkin only
--   summoner    action 12, calls adds that already exist as trash templates
--
-- Rare elites additionally enrage at 30%.
--
-- PARAM LAYOUTS WERE READ OFF LIVE ROWS, NOT ASSUMED. This fork moved some event params:
-- event 74 FRIENDLY_HEALTH_PCT carries hpPct/range in params 5/6 here, not 1/2. That event is
-- avoided entirely; event 14 FRIENDLY_HEALTH is standard and does the same job, handing the
-- wounded friendly in as the ACTION INVOKER (target_type 7).
--
-- Every spell id was confirmed present in the LIVE server Spell.dbc.
--
-- source_type 0 = creature, entryorguid = creature entry (positive), so this is per-template
-- and applies to every spawn. No action lists are used, so the entry*100 id convention and the
-- "never range-DELETE source_type 9" rule do not come into play here.
-- Re-runnable.
-- =====================================================================================

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4030101 AND 4030199;

INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
     `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
     `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`,
     `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`,
     `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`,
     `target_o`, `comment`) VALUES

    (4030101, 0, 0, 0, 0, 0, 100, 0, 5000, 9000, 13000, 18000, 0, 0, 11, 24818, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Whelp - In Combat - Cast 24818'),
    (4030101, 0, 1, 0, 0, 0, 100, 0, 9000, 13000, 15000, 21000, 0, 0, 11, 15847, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Whelp - In Combat - Cast 15847'),
    (4030102, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 6000, 9000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamscale Dryad - In Combat - Cast 21669'),
    (4030102, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 16000, 22000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamscale Dryad - In Combat - Cast 33844'),
    (4030103, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 17000, 23000, 0, 0, 11, 46026, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Verdant Horror - In Combat - Cast 46026'),
    (4030103, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Verdant Horror - In Combat - Cast 25777'),
    (4030104, 0, 0, 0, 0, 0, 100, 0, 5000, 8000, 9000, 13000, 0, 0, 11, 15496, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamwarden - In Combat - Cast 15496'),
    (4030104, 0, 1, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 22120, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Dreamwarden - Charge on aggro'),
    (4030105, 0, 0, 0, 14, 0, 100, 0, 180000, 40, 4000, 12000, 0, 0, 11, 25297, 32, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Fogcaller of the Dream - Heal a wounded friendly'),
    (4030105, 0, 1, 0, 0, 0, 100, 0, 6000, 9000, 9000, 13000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Fogcaller of the Dream - In Combat - Cast 21669'),
    (4030106, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 11000, 16000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Bloom - In Combat - Cast 33844'),
    (4030106, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Nightmare Bloom - In Combat - Cast 25777'),
    (4030107, 0, 0, 0, 0, 0, 100, 0, 5000, 9000, 13000, 18000, 0, 0, 11, 24818, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Slumbering Drakeling - In Combat - Cast 24818'),
    (4030107, 0, 1, 0, 0, 0, 100, 0, 9000, 13000, 15000, 21000, 0, 0, 11, 15847, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Slumbering Drakeling - In Combat - Cast 15847'),
    (4030108, 0, 0, 0, 0, 0, 100, 0, 7000, 11000, 24000, 32000, 0, 0, 11, 25806, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Dream Corrupter - In Combat - Cast 25806'),
    (4030108, 0, 1, 0, 0, 0, 100, 0, 3000, 6000, 10000, 14000, 0, 0, 11, 27383, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Dream Corrupter - In Combat - Cast 27383'),
    (4030109, 0, 0, 0, 0, 0, 100, 0, 6000, 9000, 20000, 26000, 0, 0, 12, 4030106, 4, 60000, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Rotbark Ancient - Summon reinforcements'),
    (4030109, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Rotbark Ancient - In Combat - Cast 25777'),
    (4030110, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 6000, 9000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Emerald Wisp - In Combat - Cast 21669'),
    (4030110, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 16000, 22000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Emerald Wisp - In Combat - Cast 33844'),
    (4030151, 0, 0, 0, 0, 0, 100, 0, 5000, 9000, 13000, 18000, 0, 0, 11, 24818, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Vethiss the Unwaking - In Combat - Cast 24818'),
    (4030151, 0, 1, 0, 0, 0, 100, 0, 9000, 13000, 15000, 21000, 0, 0, 11, 15847, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vethiss the Unwaking - In Combat - Cast 15847'),
    (4030151, 0, 2, 0, 2, 0, 100, 0, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vethiss the Unwaking - Enrage below 30%'),
    (4030151, 0, 3, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vethiss the Unwaking - Announce itself on aggro'),
    (4030152, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 17000, 23000, 0, 0, 11, 46026, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Mother Rootwither - In Combat - Cast 46026'),
    (4030152, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Mother Rootwither - In Combat - Cast 25777'),
    (4030152, 0, 2, 0, 2, 0, 100, 0, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Mother Rootwither - Enrage below 30%'),
    (4030152, 0, 3, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Mother Rootwither - Announce itself on aggro');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'smart_scripts rows (want 28)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4030101 AND 4030199
UNION ALL SELECT 'creatures given a kit (want 12)', CAST(COUNT(DISTINCT `entryorguid`) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4030101 AND 4030199
UNION ALL SELECT 'SmartAI templates with NO script (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` t
    LEFT JOIN (SELECT DISTINCT `entryorguid` AS e FROM `smart_scripts` WHERE `source_type` = 0) s
      ON s.e = t.`entry`
    WHERE t.`entry` BETWEEN 4030001 AND 4030199 AND t.`AIName` = 'SmartAI' AND s.e IS NULL
UNION ALL SELECT 'scripts on a template that is not SmartAI (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s JOIN `creature_template` t ON t.`entry` = s.`entryorguid`
    WHERE s.`source_type` = 0 AND s.`entryorguid` BETWEEN 4030101 AND 4030199
      AND t.`AIName` <> 'SmartAI'
UNION ALL SELECT 'summoned entries that do not exist (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s LEFT JOIN `creature_template` t ON t.`entry` = s.`action_param1`
    WHERE s.`source_type` = 0 AND s.`entryorguid` BETWEEN 4030101 AND 4030199
      AND s.`action_type` = 12 AND t.`entry` IS NULL;
