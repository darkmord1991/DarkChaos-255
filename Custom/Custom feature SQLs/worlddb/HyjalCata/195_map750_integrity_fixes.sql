-- ---------------------------------------------------------------------------
-- 195  Map 750 -- integrity sweep after the Darkshore/Felwood layers
-- ---------------------------------------------------------------------------
-- Full-map re-audit after 188_-194_. Twelve checks were run; nine came back
-- clean (no orphan spawns, no modelless creatures, no out-of-bounds objects, no
-- dead spellclick cursors, no empty chests, no missing quest items). Three did
-- not, and two of those are fixed here.
--
-- ---------------------------------------------------------------------------
-- A) 76 display IDs used on map 750 have no `creature_model_info` row
-- ---------------------------------------------------------------------------
-- Distinct from the problem 188_ fixed. These display ids DO exist in the
-- client (they are stock 28xxx-30xxx / 38xxx ids, so the models render); what
-- is missing is the SERVER-side bounding data. Without it the core logs
--     "No model data exist for `CreatureDisplayID` = X listed by creature ..."
-- and falls back to a default bounding radius and combat reach -- i.e. wrong
-- hitboxes and melee reach on ~700 spawns, including dense ones:
--     Shatterspear Champion x95, Shatterspear Laborer x79, Vile Spray x73,
--     Irontree Shredder x24, Wildkin Spirit / Horde Enforcer x19 ...
-- All 76 resolve in cata_world.creature_model_info, so the real Blizzard
-- measurements are copied rather than guessed.
--
-- The set is computed rather than pinned because it is derived purely from
-- what is currently spawned; re-running after another import picks up any new
-- gap automatically, and the DELETE is scoped to exactly what the INSERT adds.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (
  SELECT * FROM (
    SELECT DISTINCT m.`CreatureDisplayID`
    FROM `creature` c
    JOIN `creature_template_model` m ON m.`CreatureID` = c.`id`
    WHERE c.`map` = 750
      AND EXISTS (SELECT 1 FROM `cata_world`.`creature_model_info` ci
                   WHERE ci.`DisplayID` = m.`CreatureDisplayID`)
  ) x);

INSERT INTO `creature_model_info`
    (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
SELECT ci.`DisplayID`, ci.`BoundingRadius`, ci.`CombatReach`, ci.`Gender`, ci.`DisplayID_Other_Gender`, 15595
FROM `cata_world`.`creature_model_info` ci
WHERE ci.`DisplayID` IN (
  SELECT * FROM (
    SELECT DISTINCT m.`CreatureDisplayID`
    FROM `creature` c
    JOIN `creature_template_model` m ON m.`CreatureID` = c.`id`
    WHERE c.`map` = 750
  ) y)
  AND NOT EXISTS (SELECT 1 FROM `creature_model_info` o WHERE o.`DisplayID` = ci.`DisplayID`);

-- ---------------------------------------------------------------------------
-- B) 3 Felwood quests are turned in at a gameobject we never imported
-- ---------------------------------------------------------------------------
-- 193_ only inserts a gameobject_questender row when the +3,700,000 template
-- exists -- that guard is what stops a quest being strandable. It did its job
-- and skipped these three, because the two objects are quest-only and have no
-- spawn of their own in cata_world, so the spawn-driven import in 184_ never
-- saw them:
--     206585 Totem of Ruumbo      -> quest 28100 "A Talking Totem"
--     207104 Master Control Pump  -> quests 28335 "Turn It Off! Turn It Off!"
--                                    and   28385 "Oil and Irony"
-- Importing the templates and then the relations closes all three.
--
-- The other five starter-without-ender quests found by the sweep (28129, 28131,
-- 28153, 28228, 28229) are NOT a defect here: cata_world has no ender of either
-- kind for them either, so they complete some other way. Left alone.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` IN (3906585, 3907104);

INSERT INTO `gameobject_template`
    (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
     `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,
     `Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,
     `Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT g.`entry` + 3700000, g.`type`, g.`displayId`, g.`name`, g.`IconName`, g.`castBarCaption`, g.`unk1`, g.`size`,
       g.`Data0`, g.`Data1`, g.`Data2`, g.`Data3`, g.`Data4`, g.`Data5`, g.`Data6`, g.`Data7`, g.`Data8`,
       g.`Data9`, g.`Data10`, g.`Data11`, g.`Data12`, g.`Data13`, g.`Data14`, g.`Data15`, g.`Data16`,
       g.`Data17`, g.`Data18`, g.`Data19`, g.`Data20`, g.`Data21`, g.`Data22`, g.`Data23`, '', '', g.`VerifiedBuild`
FROM `cata_world`.`gameobject_template` g
WHERE g.`entry` IN (206585, 207104);

DELETE FROM `gameobject_questender` WHERE `quest` IN (28100, 28335, 28385);

INSERT INTO `gameobject_questender` (`id`,`quest`)
SELECT r.`id` + 3700000, r.`quest`
FROM `cata_world`.`gameobject_questender` r
WHERE r.`quest` IN (28100, 28335, 28385)
  AND EXISTS (SELECT 1 FROM `gameobject_template` g WHERE g.`entry` = r.`id` + 3700000);

-- ---------------------------------------------------------------------------
-- NOT FIXED HERE, recorded so it is not re-discovered as new
-- ---------------------------------------------------------------------------
-- Quest 104906 "Further Corruption" (a +100,000 clone from an EARLIER pass, not
-- from 189_-194_) is HALF-OFFSET: RequiredNpcOrGo1 = 3707111 is correctly
-- offset but RequiredNpcOrGo2 = 7108 is still the raw Kalimdor id. Correcting
-- it to 3707108 would not make the quest completable either -- that template
-- exists but has ZERO spawns on map 750 -- so it needs a spawn decision, not a
-- one-line id fix. The other 17 raw-id objectives the sweep found all belong to
-- genuine vanilla map-0/1 quests and are correct as they are.
--
-- Apply against acore_world AFTER 193_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification after applying + restart (both expect 0):
--   SELECT COUNT(DISTINCT m.CreatureDisplayID) FROM creature c
--     JOIN creature_template_model m ON m.CreatureID = c.id
--    WHERE c.map = 750
--      AND NOT EXISTS (SELECT 1 FROM creature_model_info i WHERE i.DisplayID = m.CreatureDisplayID);
--
--   SELECT COUNT(DISTINCT s.quest) FROM creature_queststarter s
--     JOIN quest_template q ON q.ID = s.quest
--    WHERE q.QuestSortID IN (148,361) AND q.ID IN (28100,28335,28385)
--      AND NOT EXISTS (SELECT 1 FROM creature_questender e WHERE e.quest = s.quest)
--      AND NOT EXISTS (SELECT 1 FROM gameobject_questender g WHERE g.quest = s.quest);
-- ---------------------------------------------------------------------------
