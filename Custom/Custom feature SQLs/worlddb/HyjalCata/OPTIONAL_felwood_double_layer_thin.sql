-- ---------------------------------------------------------------------------
-- OPTIONAL  Felwood double-layer thinning -- 103 trash spawns, 15 entries
-- ---------------------------------------------------------------------------
-- 🔴 NOT IN apply_all.sql ON PURPOSE. This is a balance decision, not a defect
-- fix, and it DELETES spawns. Read the numbers, then add the SOURCE line
-- yourself if you want it.
--
-- BACKGROUND. Felwood carries two creature layers by design (181_/183_ imported
-- the Cata population additively on top of the vanilla one, because 12 vanilla
-- entries are live quest objectives and deleting them would break those
-- quests). Over the zone footprint that is 937 vanilla-layer + 581 cata-layer
-- spawns. The only real DEFECT the double layer caused -- named and service
-- NPCs standing on top of each other at Talonbranch -- was already fixed by
-- 295_. What is left is density.
--
-- WHAT THIS REMOVES: vanilla-layer trash that the Cata layer already covers.
--
--   937  vanilla-layer spawns in the Felwood box (x 3509-7373, y -2275..-221)
--  -298  are a quest objective (RequiredNpcOrGo on some quest)   -- kept
--   -46  carry an npcflag (vendor/trainer/flightmaster/gossip)   -- kept
--   -15  rank > 0 (elite or rare)                                -- kept
--  =219  have a cata-layer spawn within 25 yd at all
--   -->  after the guards below: **103 spawns across 15 entries**
--
-- THE GUARDS, and why each one is there rather than "trash is trash":
--   * quest objective / queststarter / questender  -> deleting breaks a quest
--   * npcflag <> 0, rank > 0                       -> service and named mobs
--   * ScriptName set                               -> a C++ script owns it
--   * smart_scripts entryorguid = -guid            -> a SmartAI script is
--       attached TO THIS SPAWN by guid; deleting it strands the script
--   * pool_creature / game_event_creature          -> spawn-rotation member
--   * creature_formations leader or member         -> breaks the formation
--   * creature_addon.path_id > 0                   -> it walks an authored
--       patrol route (several of them were only just restored by 305_)
--   * the entry has >= 8 spawns on map 750         -> never thin a rare or
--       one-off. This is the guard that matters most: the first pass without it
--       proposed deleting the ONLY spawn of Shi'alune, Kroshius and Overlord
--       Ror, three named NPCs that merely happen to stand near a Cata spawn.
--   * at most 33% of any one entry's map-750 spawns -> a zone thinned to a
--       third of its mobs is a different defect
--
-- Deletion order within an entry is by guid ascending, so it is deterministic
-- and re-running removes nothing further (the survivors have no duplicates left
-- to pair with once their neighbours are gone... they do, so the cap is what
-- makes this idempotent-ish -- see the note at the bottom).
--
-- Apply against acore_world, then restart worldserver.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Backup first -- this is the only copy of what was removed
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_felwood_thin_backup` LIKE `creature`;

-- ---------------------------------------------------------------------------
-- B) Pick the victims once, into a temp table
-- ---------------------------------------------------------------------------
-- Computed ONCE and reused by the backup, the delete and the addon cleanup, so
-- the three cannot disagree -- the predicate is never evaluated twice.
-- ---------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `dc_felwood_thin`;
CREATE TEMPORARY TABLE `dc_felwood_thin` (
  `guid` INT UNSIGNED NOT NULL PRIMARY KEY,
  `entry` INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_felwood_thin` (`guid`, `entry`)
SELECT x.`guid`, x.`entry` FROM (
  SELECT c.`guid`, c.`id` AS entry,
         ROW_NUMBER() OVER (PARTITION BY c.`id` ORDER BY c.`guid`) AS rn,
         (SELECT COUNT(*) FROM `creature` c3 WHERE c3.`map` = 750 AND c3.`id` = c.`id`) AS tot
  FROM `creature` c
  JOIN `creature_template` ct ON ct.`entry` = c.`id`
  LEFT JOIN (
      SELECT DISTINCT `RequiredNpcOrGo1` AS e FROM `quest_template` WHERE `RequiredNpcOrGo1` > 0
      UNION SELECT DISTINCT `RequiredNpcOrGo2` FROM `quest_template` WHERE `RequiredNpcOrGo2` > 0
      UNION SELECT DISTINCT `RequiredNpcOrGo3` FROM `quest_template` WHERE `RequiredNpcOrGo3` > 0
      UNION SELECT DISTINCT `RequiredNpcOrGo4` FROM `quest_template` WHERE `RequiredNpcOrGo4` > 0
  ) prot ON prot.`e` = c.`id`
  LEFT JOIN LATERAL (
      SELECT 1 AS n FROM `creature` c2
      WHERE c2.`map` = 750 AND c2.`guid` BETWEEN 15830001 AND 15850000
        AND SQRT(POW(c2.`position_x` - c.`position_x`, 2)
               + POW(c2.`position_y` - c.`position_y`, 2)) <= 25
      LIMIT 1
  ) near ON TRUE
  WHERE c.`map` = 750
    AND c.`guid` BETWEEN 15800001 AND 15820000
    AND c.`position_x` BETWEEN 3509 AND 7373
    AND c.`position_y` BETWEEN -2275 AND -221
    AND prot.`e` IS NULL
    AND ct.`npcflag` = 0
    AND ct.`rank` = 0
    AND near.`n` IS NOT NULL
    AND (ct.`ScriptName` IS NULL OR ct.`ScriptName` = '')
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` qs WHERE qs.`id` = c.`id`)
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` qe WHERE qe.`id` = c.`id`)
    AND NOT EXISTS (SELECT 1 FROM `smart_scripts` ss WHERE ss.`source_type` = 0 AND ss.`entryorguid` = -c.`guid`)
    AND NOT EXISTS (SELECT 1 FROM `pool_creature` pc WHERE pc.`guid` = c.`guid`)
    AND NOT EXISTS (SELECT 1 FROM `game_event_creature` ge WHERE ge.`guid` = c.`guid`)
    AND NOT EXISTS (SELECT 1 FROM `creature_formations` cf WHERE cf.`leaderGUID` = c.`guid` OR cf.`memberGUID` = c.`guid`)
    AND NOT EXISTS (SELECT 1 FROM `creature_addon` ca WHERE ca.`guid` = c.`guid` AND ca.`path_id` > 0)
) x
WHERE x.`tot` >= 8 AND x.`rn` <= FLOOR(x.`tot` * 0.33);

-- ---------------------------------------------------------------------------
-- C) Back up, then delete
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `dc_felwood_thin_backup`
SELECT c.* FROM `creature` c JOIN `dc_felwood_thin` t ON t.`guid` = c.`guid`;

DELETE ca FROM `creature_addon` ca JOIN `dc_felwood_thin` t ON t.`guid` = ca.`guid`;

DELETE c FROM `creature` c JOIN `dc_felwood_thin` t ON t.`guid` = c.`guid`;

DROP TEMPORARY TABLE IF EXISTS `dc_felwood_thin`;

-- ---------------------------------------------------------------------------
-- Expected: 103 spawns, 15 entries. Biggest contributors (measured 2026-08-30):
--   3710017 Tainted Cockroach     26 of 104     3708957 Angerclaw Grizzly 11 of 36
--   3708960 Felpaw Scavenger      11 of 46      3708959 Felpaw Wolf        9 of 41
--   3708956 Angerclaw Bear         8 of 42      3710016 Tainted Rat        7 of 34
--   3707099 Ironbeak Hunter        5 of 19      3708958 Angerclaw Mauler   4 of 39
-- Felwood keeps 834 vanilla + 581 cata spawns -- still denser than either
-- source on its own, which is the design.
--
-- ⚠ NOT fully idempotent: a second run re-evaluates "has a cata neighbour" and
-- "33% of what is left", so it would thin a further slice. Run it ONCE. The
-- backup table makes that recoverable either way.
--
-- REVERT:
--   INSERT INTO creature SELECT * FROM dc_felwood_thin_backup;
--   DROP TABLE dc_felwood_thin_backup;
--   (creature_addon rows are not restored -- none of the deleted spawns had a
--    path_id, that was a guard, so only auras/emotes from 273_ would be lost;
--    re-run 273_ if you revert.)
-- ---------------------------------------------------------------------------
