-- ---------------------------------------------------------------------------
-- 247  Molten Front (map 861) -- integrate as the 125-130 daily endgame
-- ---------------------------------------------------------------------------
-- With Hyjal Frontier topping out at 113-130, the Molten Front becomes the
-- natural max-level daily hub -- exactly its Cata role (unlocked from Hyjal,
-- token-driven daily progression). This file does the DATA side now so the
-- zone is endgame-ready the moment its terrain ships:
--
--   * creatures spawned on map 861 re-level to the 128-130 crown band
--     (authentic Cata 85s otherwise award zero XP to a 128+ player -- grey
--     level is player - 9);
--   * its quests (the MF daily chain, QuestSortID 0 at level 85) go
--     QuestLevel = -1 / MinLevel 125, same convention as 234_;
--   * 101_'s elite HP/damage modifiers already cover map 861 and stay.
--
-- STILL GATED: map 861 has no maps/vmaps/mmaps on the live host, so
-- dc_teleporter 413 stays at security_level 3 (see 30_entry_points.sql and
-- HYJAL_MOLTENFRONT_HANDOFF.md sections E0/E03). Flip it to 0 only after the
-- terrain deployment -- this file deliberately does NOT touch it. The
-- Hyjal -> Molten Front breadcrumb should be added together with that flip
-- (quest block 81316+ is free).
--
-- Run AFTER 233_ (levels must not be re-snapshotted afterwards -- the
-- dc_map750_snap baseline from 233_ already covers the whole 3.6M-3.8M
-- template range, MF templates included). Idempotent (absolute assignments).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) re-level the Molten Front population to the crown band
-- ---------------------------------------------------------------------------
-- trash: 128-129
UPDATE `creature_template` ct
SET ct.`minlevel` = 128, ct.`maxlevel` = 129
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 861)
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 0;

-- elites: 129-130
UPDATE `creature_template` ct
SET ct.`minlevel` = 129, ct.`maxlevel` = 130
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 861)
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` = 1;

-- rares / bosses: flat 130
UPDATE `creature_template` ct
SET ct.`minlevel` = 130, ct.`maxlevel` = 130
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 861)
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` = 0
  AND ct.`rank` >= 2;

-- service / flagged NPCs: flat 130
UPDATE `creature_template` ct
SET ct.`minlevel` = 130, ct.`maxlevel` = 130
WHERE ct.`entry` BETWEEN 3600000 AND 3799999
  AND ct.`entry` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 861)
  AND ct.`type` NOT IN (8, 10)
  AND ct.`npcflag` <> 0;

-- ---------------------------------------------------------------------------
-- B) scale the Molten Front quests
-- ---------------------------------------------------------------------------
-- Scope by starter entity spawned on map 861 (its daily chain lives on sort 0
-- -- never scope by QuestSortID). Starters shared with map 750 are fine
-- (both maps are in-project); quests also started by anything else are not
-- touched, same guard as 234_.
DROP TABLE IF EXISTS `dc_map861_quests`;

CREATE TABLE `dc_map861_quests` (
  `quest` INT NOT NULL PRIMARY KEY
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map861_quests` (`quest`)
SELECT qs.`quest`
FROM `creature_queststarter` qs
WHERE qs.`id` IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` = 861);

INSERT IGNORE INTO `dc_map861_quests` (`quest`)
SELECT qs.`quest`
FROM `gameobject_queststarter` qs
WHERE qs.`id` IN (SELECT DISTINCT g.`id` FROM `gameobject` g WHERE g.`map` = 861);

DELETE q FROM `dc_map861_quests` q
WHERE EXISTS (
    SELECT 1 FROM `creature_queststarter` qs
    WHERE qs.`quest` = q.`quest`
      AND qs.`id` NOT IN (SELECT DISTINCT c.`id` FROM `creature` c WHERE c.`map` IN (750, 861))
)
OR EXISTS (
    SELECT 1 FROM `gameobject_queststarter` qs
    WHERE qs.`quest` = q.`quest`
      AND qs.`id` NOT IN (SELECT DISTINCT g.`id` FROM `gameobject` g WHERE g.`map` IN (750, 861))
);

UPDATE `quest_template` qt
JOIN `dc_map861_quests` q ON q.`quest` = qt.`ID`
SET qt.`QuestLevel` = -1,
    qt.`MinLevel` = 125;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- level bands on 861 (expect 128/129/130 only, plus untouched critters):
-- SELECT ct.`rank`, ct.minlevel, ct.maxlevel, COUNT(*) FROM creature_template ct
-- WHERE ct.entry IN (SELECT DISTINCT id FROM creature WHERE map = 861)
--   AND ct.type NOT IN (8, 10) GROUP BY ct.`rank`, ct.minlevel, ct.maxlevel;
-- quest scaling:
-- SELECT COUNT(*), MIN(qt.MinLevel), MAX(qt.QuestLevel) FROM quest_template qt
-- JOIN dc_map861_quests q ON q.quest = qt.ID;
-- the gate is still closed (expect security_level 3 until terrain ships):
-- SELECT id, security_level FROM dc_teleporter WHERE id = 413;
