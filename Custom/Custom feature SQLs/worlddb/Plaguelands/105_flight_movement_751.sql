-- 105_flight_movement_751.sql -- map 751 flying creatures, DB step 44.
--
-- THE SYMPTOM
--   "flying npcs fall from the sky down again"
--   Silverpine's Val'kyr (Agatha, Arthura, Daschla), the Fallen Human bodies they
--   raise, and the bats/razorbeaks drop to the ground instead of hovering.
--
-- THE CAUSE -- ANOTHER OFFSET-BAND IMPORT GAP, and "again" is precise.
--   This fork has NO `creature_template.InhabitType` column; it was replaced by
--   `creature_template_movement` (Ground / Swim / Flight / Rooted / ...). The source
--   `nelt_world` still carries InhabitType, so an importer has to TRANSLATE it. The
--   earlier imports did. The map-751 extension import, on the +4,100,000 band, did not:
--
--     map 750       3.6M band   59 air creatures   0 missing a movement row
--     map 751       3.6M band   10 air creatures   0 missing
--     map 861       3.6M band   21 air creatures   0 missing
--     map 751       4.1M band   19 air creatures   19 MISSING  <-- all of them
--
--   With no row, Flight defaults to 0, gravity applies, and anything whose source says
--   "air" falls. Same family as the TransportAnimation gap (101_) and the gameobject
--   flags gap (103_/104_): the base table was cloned onto the band, the side table was
--   not.
--
-- THE MAPPING IS COPIED FROM THE BAND THAT WORKS, not invented. Every 3.6M row on this
-- map follows one rule, and these are the actual rows:
--     InhabitType 4 (air)          -> Ground 0, Swim 0, Flight 1   e.g. Invisible Stalker (Floating)
--     InhabitType 5 (ground|air)   -> Ground 1, Swim 0, Flight 1   e.g. Monstrous Plaguebat
--   so Ground and Swim are taken from InhabitType bits 0x1 and 0x2, and Flight is 1.
--   Rooted / Chase / Random / InteractionPauseTimer are 0 in every working row.
--
--   Flight = 1 is DisableGravity, which is what stops the fall and is what the working
--   band uses uniformly. Flight = 2 (CanFly) is deliberately NOT used -- no row on this
--   map uses it, and granting real flight would change pathing, not just posture.
--
--   One entry, 4144592 "Fallen Human", has InhabitType 7 (ground|water|air) and so gets
--   Swim = 1. No 3.6M row on this map has bit 0x2 set, so that single value follows the
--   bit definition rather than a local precedent -- called out here rather than hidden.
--
-- THE SOURCE IS VALIDATED BY NAME, not by arithmetic alone. Of the 1,121 entries in the
-- 4.1M band, 1,119 match their (id - 4,100,000) counterpart on name; the 2 that do not
-- are excluded, exactly as in 103_. Derived at apply time so the predicate is reviewable.
--
-- NOT CHANGED HERE: `creature_addon.bytes1` animTier. Only 2 of the 10 working 3.6M air
-- creatures set it, so it is not what keeps them up -- the movement row is. If a specific
-- Val'kyr still looks wrong-posed rather than falling, that is the follow-up.

DROP TABLE IF EXISTS `_dc_flight_751`;

CREATE TABLE `_dc_flight_751` (
  `CreatureId` INT UNSIGNED NOT NULL,
  `Ground` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `Swim` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `Flight` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `Rooted` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `Chase` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `Random` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `InteractionPauseTimer` INT UNSIGNED NOT NULL DEFAULT 0,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `src_inhabit` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`CreatureId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_dc_flight_751`
  (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`,
   `InteractionPauseTimer`, `name`, `src_inhabit`)
SELECT DISTINCT c.`id`,
       CASE WHEN s.`InhabitType` & 1 THEN 1 ELSE 0 END,
       CASE WHEN s.`InhabitType` & 2 THEN 1 ELSE 0 END,
       1, 0, 0, 0, 0,
       t.`name`, s.`InhabitType`
FROM `creature` c
JOIN `creature_template` t ON t.`entry` = c.`id`
JOIN `nelt_world`.`creature_template` s ON s.`entry` = c.`id` - 4100000
WHERE c.`map` = 751
  AND c.`id` >= 4100000
  AND s.`name` <=> t.`name`
  AND (s.`InhabitType` & 4);

DELETE FROM `creature_template_movement`
 WHERE `CreatureId` IN (SELECT `CreatureId` FROM `_dc_flight_751`);

INSERT INTO `creature_template_movement`
  (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`)
SELECT `CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`
FROM `_dc_flight_751`;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'entries staged (want 19)' AS what, COUNT(*) AS n FROM `_dc_flight_751`
UNION ALL SELECT '  ...all with Flight = 1 (want 19)', COUNT(*)
  FROM `_dc_flight_751` WHERE `Flight` = 1
UNION ALL SELECT '  ...Ground 1 i.e. also walks (want 1)', COUNT(*)
  FROM `_dc_flight_751` WHERE `Ground` = 1
UNION ALL SELECT '  ...Swim 1, the InhabitType 7 case (want 1)', COUNT(*)
  FROM `_dc_flight_751` WHERE `Swim` = 1
UNION ALL SELECT 'movement rows now present for them (want 19)', COUNT(*)
  FROM `creature_template_movement` m
  JOIN `_dc_flight_751` f ON f.`CreatureId` = m.`CreatureId`
UNION ALL SELECT 'map-751 air creatures STILL with no movement row (want 0)', COUNT(*)
  FROM (SELECT DISTINCT c.`id` FROM `creature` c
         JOIN `creature_template` t2 ON t2.`entry` = c.`id`
         JOIN `nelt_world`.`creature_template` s2 ON s2.`entry` = c.`id` - 4100000
        WHERE c.`map` = 751 AND c.`id` >= 4100000
          AND s2.`name` <=> t2.`name` AND (s2.`InhabitType` & 4)) q
  LEFT JOIN `creature_template_movement` m2 ON m2.`CreatureId` = q.`id`
  WHERE m2.`CreatureId` IS NULL
UNION ALL SELECT 'total spawns lifted back into the air', COUNT(*)
  FROM `creature` c JOIN `_dc_flight_751` f ON f.`CreatureId` = c.`id`
  WHERE c.`map` = 751;

SELECT `CreatureId`, `name`, `src_inhabit`, `Ground`, `Swim`, `Flight`
FROM `_dc_flight_751` ORDER BY `CreatureId`;

DROP TABLE `_dc_flight_751`;
