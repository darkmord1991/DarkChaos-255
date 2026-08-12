-- =====================================================================================
-- Crescent Grove (map 823) -- SmartAI for trash and rare elites
--
-- 05_templates.sql sets `AIName` = 'SmartAI' on every non-boss row in this band. Without the
-- rows below that is a NO-OP THAT LOGS NOTHING: the creature loads an empty script and does
-- nothing but auto-attack. So until this file is applied, the "Ritualist", "Dreamspeaker" and
-- "Totemcaller" fight exactly like each other and like a boar.
--
-- 15 creatures, 11 distinct kits. Roles are deliberately readable from the name:
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

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4020101 AND 4020199;

INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
     `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`,
     `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`,
     `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`,
     `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`,
     `target_o`, `comment`) VALUES

    (4020101, 0, 0, 0, 0, 0, 100, 0, 5000, 8000, 9000, 13000, 0, 0, 11, 15496, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Satyr - In Combat - Cast 15496'),
    (4020101, 0, 1, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 22120, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Satyr - Charge on aggro'),
    (4020102, 0, 0, 0, 0, 0, 100, 0, 10000, 14000, 22000, 30000, 0, 0, 11, 26070, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Trickster - In Combat - Cast 26070'),
    (4020102, 0, 1, 0, 0, 0, 100, 0, 4000, 7000, 15000, 20000, 0, 0, 11, 12889, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Trickster - In Combat - Cast 12889'),
    (4020103, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 12000, 17000, 0, 0, 11, 34435, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Soothsayer - In Combat - Cast 34435'),
    (4020103, 0, 1, 0, 0, 0, 100, 0, 8000, 11000, 14000, 19000, 0, 0, 11, 27383, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Soothsayer - In Combat - Cast 27383'),
    (4020104, 0, 0, 0, 14, 0, 100, 0, 60000, 40, 4000, 12000, 0, 0, 11, 25297, 32, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Bloodpriest - Heal a wounded friendly'),
    (4020104, 0, 1, 0, 0, 0, 100, 0, 6000, 9000, 9000, 13000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Shadowleaf Bloodpriest - In Combat - Cast 21669'),
    (4020105, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 11000, 16000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Vilethorn Lasher - In Combat - Cast 33844'),
    (4020105, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vilethorn Lasher - In Combat - Cast 25777'),
    (4020106, 0, 0, 0, 0, 0, 100, 0, 6000, 9000, 20000, 26000, 0, 0, 12, 4020105, 4, 60000, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vilethorn Ancient - Summon reinforcements'),
    (4020106, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vilethorn Ancient - In Combat - Cast 25777'),
    (4020107, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 6000, 9000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Grove Dryad - In Combat - Cast 21669'),
    (4020107, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 16000, 22000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Grove Dryad - In Combat - Cast 33844'),
    (4020108, 0, 0, 0, 0, 0, 100, 0, 4000, 7000, 10000, 15000, 0, 0, 11, 32736, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildkin of the Crescent - In Combat - Cast 32736'),
    (4020108, 0, 1, 0, 0, 0, 100, 0, 12000, 16000, 18000, 24000, 0, 0, 11, 33238, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Wildkin of the Crescent - In Combat - Cast 33238'),
    (4020109, 0, 0, 0, 0, 0, 100, 0, 3000, 6000, 8000, 12000, 0, 0, 11, 26996, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Crescent Furbolg - In Combat - Cast 26996'),
    (4020109, 0, 1, 0, 2, 0, 100, 0, 0, 25, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Crescent Furbolg - Enrage below 25%'),
    (4020110, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 6000, 9000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Moonwell Guardian - In Combat - Cast 21669'),
    (4020110, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 16000, 22000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Moonwell Guardian - In Combat - Cast 33844'),
    (4020111, 0, 0, 0, 0, 0, 100, 0, 10000, 14000, 22000, 30000, 0, 0, 11, 26070, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Felbound Houndmaster - In Combat - Cast 26070'),
    (4020111, 0, 1, 0, 0, 0, 100, 0, 4000, 7000, 15000, 20000, 0, 0, 11, 12889, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Felbound Houndmaster - In Combat - Cast 12889'),
    (4020112, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 17000, 23000, 0, 0, 11, 46026, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Corrupted Treant - In Combat - Cast 46026'),
    (4020112, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Corrupted Treant - In Combat - Cast 25777'),
    (4020151, 0, 0, 0, 0, 0, 100, 0, 8000, 12000, 17000, 23000, 0, 0, 11, 46026, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Thornmaw - In Combat - Cast 46026'),
    (4020151, 0, 1, 0, 0, 0, 100, 0, 1000, 2000, 60000, 60000, 0, 0, 11, 25777, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Thornmaw - In Combat - Cast 25777'),
    (4020151, 0, 2, 0, 2, 0, 100, 0, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Thornmaw - Enrage below 30%'),
    (4020151, 0, 3, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Thornmaw - Announce itself on aggro'),
    (4020152, 0, 0, 0, 0, 0, 100, 0, 2000, 4000, 6000, 9000, 0, 0, 11, 21669, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Sister Nightbloom - In Combat - Cast 21669'),
    (4020152, 0, 1, 0, 0, 0, 100, 0, 8000, 12000, 16000, 22000, 0, 0, 11, 33844, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Sister Nightbloom - In Combat - Cast 33844'),
    (4020152, 0, 2, 0, 2, 0, 100, 0, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sister Nightbloom - Enrage below 30%'),
    (4020152, 0, 3, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Sister Nightbloom - Announce itself on aggro'),
    (4020153, 0, 0, 0, 0, 0, 100, 0, 7000, 11000, 24000, 32000, 0, 0, 11, 25806, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Xar''thek the Whisperer - In Combat - Cast 25806'),
    (4020153, 0, 1, 0, 0, 0, 100, 0, 3000, 6000, 10000, 14000, 0, 0, 11, 27383, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Xar''thek the Whisperer - In Combat - Cast 27383'),
    (4020153, 0, 2, 0, 2, 0, 100, 0, 0, 30, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Xar''thek the Whisperer - Enrage below 30%'),
    (4020153, 0, 3, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Xar''thek the Whisperer - Announce itself on aggro');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'smart_scripts rows (want 36)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4020101 AND 4020199
UNION ALL SELECT 'creatures given a kit (want 15)', CAST(COUNT(DISTINCT `entryorguid`) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 4020101 AND 4020199
UNION ALL SELECT 'SmartAI templates with NO script (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` t
    LEFT JOIN (SELECT DISTINCT `entryorguid` AS e FROM `smart_scripts` WHERE `source_type` = 0) s
      ON s.e = t.`entry`
    WHERE t.`entry` BETWEEN 4020001 AND 4020199 AND t.`AIName` = 'SmartAI' AND s.e IS NULL
UNION ALL SELECT 'scripts on a template that is not SmartAI (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s JOIN `creature_template` t ON t.`entry` = s.`entryorguid`
    WHERE s.`source_type` = 0 AND s.`entryorguid` BETWEEN 4020101 AND 4020199
      AND t.`AIName` <> 'SmartAI'
UNION ALL SELECT 'summoned entries that do not exist (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` s LEFT JOIN `creature_template` t ON t.`entry` = s.`action_param1`
    WHERE s.`source_type` = 0 AND s.`entryorguid` BETWEEN 4020101 AND 4020199
      AND s.`action_type` = 12 AND t.`entry` IS NULL;
