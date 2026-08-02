-- ---------------------------------------------------------------------------
-- 212  Map 750 -- populate Ashenvale and Winterspring
-- ---------------------------------------------------------------------------
-- APPLY 211_ FIRST and deploy its two client DBCs. Without those 62 display
-- rows, ObjectMgr drops the creature_template_model rows for the new templates
-- and every spawn below is refused with "has no model defined".
--
-- WHY THESE TWO ZONES. Map 750 defines seven zones in AreaTable (ContinentID
-- 750): Hyjal Frontier 4923, Winterspring 4926, Felwood 4927, Moonglade 4928,
-- Darkshore 4929, Azshara 4930, Ashenvale 4931. Measuring creature spawns
-- against cata_world clipped to the identical footprint:
--
--     Mount Hyjal (Cata)  5173 / 5533   93%     Moonglade    292 /  410   71%
--     Darkshore           1795 / 1705  105%     Winterspring 1107 / 1861  60%
--     Felwood             1190 / 1479   80%     Azshara       161 /  358  45%
--     Mount Hyjal (van.)   317 /  239  133%     ASHENVALE      67 /  819   8%
--
-- Ashenvale and Winterspring are the two real gaps. AZSHARA IS DELIBERATELY NOT
-- TOUCHED: its 45% is not a defect -- that zone's terrain on map 750 is stock
-- WotLK, not Cata, so Cata Azshara spawns do not fit the ground there.
--
-- TERRAIN WAS VERIFIED BEFORE IMPORTING, not assumed -- that is exactly the
-- check Azshara failed. Sampling Cata spawn positions against map 750's own
-- heightmap: Ashenvale 45 of 52 land within 2y of the ground (median +0.11),
-- Winterspring 47 of 47 (median +0.08, worst +0.7). So z copies across
-- unchanged and needs no snapping.
--
-- HOW THE ZONES ARE DELIMITED. Not by bounding box -- a box around the
-- Ashenvale sliver also swallows half the Hyjal crater, which is how a first
-- attempt pulled in Sethria's Hatchling and Flame Ascendant. The ADT MCNK
-- header carries an areaid per 33.33y chunk; those chunks were resolved to
-- top-level zones and merged into the 126 rectangles in section A. Ashenvale
-- on this map is only the eastern sliver (x 3233-4267) -- a partial zone at the
-- map edge, not a whole one.
--
-- WHAT IS EXCLUDED, on purpose:
--   * game_event spawns (holiday content -- invisible outside the event anyway)
--   * anything already present at the same position under ANY offset band
--   * AIName is cleared. Cata's SmartAI rows are NOT imported here, and an
--     AIName of 'SmartAI' with no smart_scripts produces exactly the
--     "has SmartAI enabled but no SmartAI entries" errors that 205_/210_ spent
--     effort clearing. Empty AIName gives them default combat AI, which fights
--     correctly; the SmartAI layer is a separate job.
--   * VehicleId is cleared unless our vehicle_dbc actually has it -- a dangling
--     VehicleId freezes the creature on this core.
--   * ScriptName is cleared; cata's script names are not ours.
--
-- GUIDS are deterministic and traceable: guid = 16,100,000 + the cata source
-- guid. Cata's map-1 guids top out at 396,671 so the band 16,100,000-16,500,000
-- is enough, and it was verified empty on both tables.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) The zone mask -- 59 Ashenvale + 67 Winterspring chunk rectangles
-- ---------------------------------------------------------------------------
-- Chunk coordinates, 16 per ADT tile: cx = FLOOR((32 - x/533.3333)*16),
-- cy = FLOOR((32 - y/533.3333)*16). Kept as a table so the import predicate is
-- a plain join and the geometry stays auditable.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_zonemask`;

CREATE TABLE `dc_map750_zonemask` (
  `zone` VARCHAR(16) NOT NULL,
  `cx0` INT NOT NULL, `cx1` INT NOT NULL,
  `cy0` INT NOT NULL, `cy1` INT NOT NULL,
  KEY `k` (`cx0`,`cx1`,`cy0`,`cy1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_zonemask` (`zone`,`cx0`,`cx1`,`cy0`,`cy1`) VALUES
('ASH',384,415,416,468),('ASH',384,415,476,484),('ASH',384,415,514,518),('ASH',385,415,485,486),
('ASH',385,415,513,513),('ASH',386,415,487,487),('ASH',386,415,512,512),('ASH',387,394,506,507),
('ASH',387,395,505,505),('ASH',387,415,488,489),('ASH',387,415,511,511),('ASH',388,395,508,508),
('ASH',388,415,490,490),('ASH',388,415,504,504),('ASH',388,415,509,510),('ASH',389,393,491,491),
('ASH',390,393,492,492),('ASH',391,393,493,493),('ASH',391,415,469,475),('ASH',391,415,494,503),
('ASH',391,415,519,522),('ASH',392,415,523,523),('ASH',393,404,524,524),('ASH',394,403,525,525),
('ASH',396,415,624,629),('ASH',397,403,526,527),('ASH',397,415,491,493),('ASH',398,415,505,505),
('ASH',398,415,508,508),('ASH',399,415,506,507),('ASH',399,415,621,623),('ASH',400,415,528,529),
('ASH',401,415,617,620),('ASH',404,415,611,616),('ASH',405,415,530,531),('ASH',405,415,553,573),
('ASH',405,415,608,610),('ASH',405,415,630,630),('ASH',406,415,524,524),('ASH',406,415,532,533),
('ASH',406,415,552,552),('ASH',406,415,605,607),('ASH',407,412,551,551),('ASH',407,415,534,535),
('ASH',407,415,601,604),('ASH',408,412,536,536),('ASH',408,412,550,550),('ASH',408,415,598,600),
('ASH',408,415,631,631),('ASH',409,411,537,537),('ASH',409,415,527,527),('ASH',409,415,595,597),
('ASH',410,410,538,540),('ASH',410,415,525,526),('ASH',410,415,592,594),('ASH',410,415,632,632),
('ASH',411,415,590,591),('ASH',412,415,588,589),('ASH',413,415,633,633),
('WIN',272,281,644,645),('WIN',272,293,624,624),('WIN',272,324,647,650),('WIN',272,327,618,619),
('WIN',272,328,620,623),('WIN',272,329,625,625),('WIN',272,330,626,627),('WIN',272,333,628,628),
('WIN',272,334,629,629),('WIN',272,338,630,631),('WIN',272,340,632,632),('WIN',272,341,633,636),
('WIN',272,342,637,637),('WIN',272,343,638,638),('WIN',272,350,671,671),('WIN',272,353,670,670),
('WIN',272,356,669,669),('WIN',272,360,639,643),('WIN',272,360,646,646),('WIN',272,360,651,652),
('WIN',272,360,668,668),('WIN',272,361,653,655),('WIN',272,361,667,667),('WIN',272,365,656,662),
('WIN',272,371,666,666),('WIN',272,375,665,665),('WIN',272,376,664,664),('WIN',272,377,663,663),
('WIN',274,327,617,617),('WIN',276,326,616,616),('WIN',277,326,615,615),('WIN',279,325,614,614),
('WIN',284,360,644,645),('WIN',288,325,613,613),('WIN',289,325,612,612),('WIN',290,325,610,611),
('WIN',294,325,608,609),('WIN',295,325,605,607),('WIN',295,326,604,604),('WIN',296,326,603,603),
('WIN',296,329,624,624),('WIN',297,327,601,602),('WIN',298,327,600,600),('WIN',298,334,580,580),
('WIN',299,328,597,599),('WIN',299,334,579,579),('WIN',299,334,581,583),('WIN',300,318,586,589),
('WIN',300,328,596,596),('WIN',300,329,594,595),('WIN',300,330,593,593),('WIN',300,331,592,592),
('WIN',300,332,590,591),('WIN',300,333,585,585),('WIN',300,334,584,584),('WIN',301,334,578,578),
('WIN',323,332,589,589),('WIN',323,333,586,588),('WIN',328,360,647,650),('WIN',352,360,638,638),
('WIN',354,360,637,637),('WIN',359,360,636,636),('WIN',372,378,662,662),('WIN',372,379,661,661),
('WIN',372,380,660,660),('WIN',372,388,659,659),('WIN',372,389,656,658);

-- ---------------------------------------------------------------------------
-- B) The spawn set -- materialised once so every later section agrees
-- ---------------------------------------------------------------------------
-- Keeping this as a table rather than repeating the predicate matters: the
-- templates, the loot and the spawns must all be derived from the SAME set, or
-- a spawn can end up with no template.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_zoneport`;

CREATE TABLE `dc_map750_zoneport` (
  `src_guid` INT NOT NULL PRIMARY KEY,
  `src_id`   INT NOT NULL,
  `zone`     VARCHAR(16) NOT NULL,
  KEY `k_id` (`src_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_zoneport` (`src_guid`,`src_id`,`zone`)
SELECT s.`guid`, s.`id`, z.`zone`
FROM `cata_world`.`creature` s
JOIN `dc_map750_zonemask` z
  ON FLOOR((32 - s.`position_x`/533.3333333)*16) BETWEEN z.`cx0` AND z.`cx1`
 AND FLOOR((32 - s.`position_y`/533.3333333)*16) BETWEEN z.`cy0` AND z.`cy1`
WHERE s.`map` = 1
  AND NOT EXISTS (SELECT 1 FROM `game_event_creature` e WHERE e.`guid` = s.`guid`)
  AND NOT EXISTS (SELECT 1 FROM `creature` o
                  WHERE o.`map` = 750 AND o.`id` IN (s.`id`+3700000, s.`id`+3600000, s.`id`+3900000)
                    AND ROUND(o.`position_x`,1) = ROUND(s.`position_x`,1)
                    AND ROUND(o.`position_y`,1) = ROUND(s.`position_y`,1));

-- ---------------------------------------------------------------------------
-- C) creature_template
-- ---------------------------------------------------------------------------
-- Explicit column list, not SELECT * -- the two schemas differ substantially.
-- cata has modelid1-4, femaleName, trainer_*, resistance1-6, spell1-8,
-- StaticFlags1-5, mechanic_immune_mask which we do not; we have exp,
-- speed_swim, speed_flight, detection_range, dynamicflags, CreatureImmunitiesId
-- which cata does not. The five we must invent are set to the values the
-- existing 771 map-750 templates already use (exp 0 in 762 of them, swim 1,
-- flight 1, detection 18, immunities 0).
--
-- difficulty_entry_* and KillCredit* are creature entries and are offset with
-- everything else -- left raw they would point at stock creatures.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  SELECT * FROM (SELECT DISTINCT `src_id`+3700000 FROM `dc_map750_zoneport`) x);
DELETE FROM `creature_template` WHERE `entry` IN (
  SELECT * FROM (SELECT DISTINCT `src_id`+3700000 FROM `dc_map750_zoneport`
                 WHERE `src_id`+3700000 NOT IN (SELECT `entry` FROM `creature_template`)) y);

INSERT IGNORE INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
     `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,`rank`,`dmgschool`,
     `DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,
     `unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,
     `skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
     `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,
     `RegenHealth`,`CreatureImmunitiesId`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT c.`entry`+3700000,
       IF(c.`difficulty_entry_1`>0, c.`difficulty_entry_1`+3700000, 0),
       IF(c.`difficulty_entry_2`>0, c.`difficulty_entry_2`+3700000, 0),
       IF(c.`difficulty_entry_3`>0, c.`difficulty_entry_3`+3700000, 0),
       IF(c.`KillCredit1`>0, c.`KillCredit1`+3700000, 0),
       IF(c.`KillCredit2`>0, c.`KillCredit2`+3700000, 0),
       c.`name`, c.`subname`, c.`IconName`, c.`gossip_menu_id`, c.`minlevel`, c.`maxlevel`, 0,
       c.`faction`, c.`npcflag`, c.`speed_walk`, c.`speed_run`, 1, 1, 18, c.`rank`, c.`dmgschool`,
       c.`DamageModifier`, c.`BaseAttackTime`, c.`RangeAttackTime`, c.`BaseVariance`, c.`RangeVariance`,
       c.`unit_class`, c.`unit_flags`, c.`unit_flags2`, 0, c.`family`, c.`type`, c.`type_flags`,
       c.`lootid`, c.`pickpocketloot`, c.`skinloot`, c.`PetSpellDataId`,
       IF(EXISTS(SELECT 1 FROM `vehicle_dbc` v WHERE v.`ID` = c.`VehicleId`), c.`VehicleId`, 0),
       c.`mingold`, c.`maxgold`, '', c.`MovementType`, c.`HoverHeight`,
       c.`HealthModifier`, c.`ManaModifier`, c.`ArmorModifier`, c.`ExperienceModifier`,
       c.`RacialLeader`, c.`movementId`, c.`RegenHealth`, 0, c.`flags_extra`, '', 0
FROM `cata_world`.`creature_template` c
WHERE c.`entry` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`);

-- MODELS COME FROM TWO SOURCES, AND cata's TABLE IS NARROWER THAN OURS.
-- `cata_world`.`creature_template_model` has NO `DisplayScale` column -- it is
-- (CreatureID, Idx, CreatureDisplayID, Probability, VerifiedBuild) against our
-- six. Selecting m.`DisplayScale` from it is an "Unknown column" error, and
-- because `mysql source` keeps going after an error, the DELETE above lands
-- while the INSERT does not -- which silently strips the models off every
-- creature in the port set, including ones that were working before.
--
-- Our own rows are preferred where they exist: 106 of the 190 entries are
-- pre-existing map-750 creatures whose stock rows are still here at the raw id,
-- and those carry a real DisplayScale. The remaining 84 are genuinely new Cata
-- creatures and can only come from cata, where DisplayScale is written as 1.
-- INSERT IGNORE makes the second pass fill only what the first did not.
INSERT IGNORE INTO `creature_template_model`
    (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.`CreatureID`+3700000, m.`Idx`, m.`CreatureDisplayID`, m.`DisplayScale`, m.`Probability`, 0
FROM `creature_template_model` m
WHERE m.`CreatureID` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)
  AND m.`CreatureDisplayID` > 0;

INSERT IGNORE INTO `creature_template_model`
    (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT m.`CreatureID`+3700000, m.`Idx`, m.`CreatureDisplayID`, 1, m.`Probability`, 0
FROM `cata_world`.`creature_template_model` m
WHERE m.`CreatureID` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)
  AND m.`CreatureDisplayID` > 0;

-- ---------------------------------------------------------------------------
-- D) Loot for the new creatures
-- ---------------------------------------------------------------------------
-- Imported at the RAW cata loot id, matching what 209_ established as the
-- convention for cata-sourced content, and filtered to rows whose item or
-- reference actually resolves here -- an unresolvable item id only produces a
-- load error and drops silently anyway.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (
  SELECT * FROM (SELECT DISTINCT c.`lootid` FROM `cata_world`.`creature_template` c
                 WHERE c.`lootid` > 0
                   AND c.`entry` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)) x);

INSERT INTO `creature_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT l.`Entry`, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`creature_loot_template` l
WHERE l.`Entry` IN (SELECT DISTINCT c.`lootid` FROM `cata_world`.`creature_template` c
                    WHERE c.`lootid` > 0
                      AND c.`entry` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`))
  AND (   (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`))
       OR (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`)));

DELETE FROM `skinning_loot_template` WHERE `Entry` IN (
  SELECT * FROM (SELECT DISTINCT c.`skinloot` FROM `cata_world`.`creature_template` c
                 WHERE c.`skinloot` > 0
                   AND c.`entry` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`)
                   AND c.`skinloot` NOT IN (SELECT `Entry` FROM `skinning_loot_template`)) x);

INSERT IGNORE INTO `skinning_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT l.`Entry`, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`skinning_loot_template` l
WHERE l.`Entry` IN (SELECT DISTINCT c.`skinloot` FROM `cata_world`.`creature_template` c
                    WHERE c.`skinloot` > 0
                      AND c.`entry` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport`))
  AND l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`);

-- ---------------------------------------------------------------------------
-- E) The creature spawns
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 16100000 AND 16500000;

INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,
     `dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 16100000 + s.`guid`, s.`id`+3700000, 750, 0, 0, 1, 1, s.`equipment_id`,
       s.`position_x`, s.`position_y`, s.`position_z`, s.`orientation`,
       s.`spawntimesecs`, s.`wander_distance`, 0, s.`curhealth`, s.`curmana`,
       s.`MovementType`, 0, 0, 0, '', 0, 0, CONCAT('map750-', p.`zone`, '-212')
FROM `cata_world`.`creature` s
JOIN `dc_map750_zoneport` p ON p.`src_guid` = s.`guid`
WHERE EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`entry` = s.`id`+3700000);

-- ---------------------------------------------------------------------------
-- F) Gameobjects
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_zoneport_go`;

CREATE TABLE `dc_map750_zoneport_go` (
  `src_guid` INT NOT NULL PRIMARY KEY,
  `src_id`   INT NOT NULL,
  `zone`     VARCHAR(16) NOT NULL,
  KEY `k_id` (`src_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `dc_map750_zoneport_go` (`src_guid`,`src_id`,`zone`)
SELECT s.`guid`, s.`id`, z.`zone`
FROM `cata_world`.`gameobject` s
JOIN `dc_map750_zonemask` z
  ON FLOOR((32 - s.`position_x`/533.3333333)*16) BETWEEN z.`cx0` AND z.`cx1`
 AND FLOOR((32 - s.`position_y`/533.3333333)*16) BETWEEN z.`cy0` AND z.`cy1`
WHERE s.`map` = 1
  AND NOT EXISTS (SELECT 1 FROM `game_event_gameobject` e WHERE e.`guid` = s.`guid`)
  AND NOT EXISTS (SELECT 1 FROM `gameobject` o
                  WHERE o.`map` = 750 AND o.`id` IN (s.`id`+3700000, s.`id`+3900000)
                    AND ROUND(o.`position_x`,1) = ROUND(s.`position_x`,1)
                    AND ROUND(o.`position_y`,1) = ROUND(s.`position_y`,1));

DELETE FROM `gameobject_template` WHERE `entry` IN (
  SELECT * FROM (SELECT DISTINCT `src_id`+3700000 FROM `dc_map750_zoneport_go`
                 WHERE `src_id`+3700000 NOT IN (SELECT `entry` FROM `gameobject_template`)) y);

INSERT IGNORE INTO `gameobject_template`
    (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
     `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,
     `Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,
     `Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT g.`entry`+3700000, g.`type`, g.`displayId`, g.`name`, g.`IconName`, g.`castBarCaption`,
       g.`unk1`, g.`size`, g.`Data0`, g.`Data1`, g.`Data2`, g.`Data3`, g.`Data4`, g.`Data5`,
       g.`Data6`, g.`Data7`, g.`Data8`, g.`Data9`, g.`Data10`, g.`Data11`, g.`Data12`, g.`Data13`,
       g.`Data14`, g.`Data15`, g.`Data16`, g.`Data17`, g.`Data18`, g.`Data19`, g.`Data20`,
       g.`Data21`, g.`Data22`, g.`Data23`, '', '', 0
FROM `cata_world`.`gameobject_template` g
WHERE g.`entry` IN (SELECT DISTINCT `src_id` FROM `dc_map750_zoneport_go`);

DELETE FROM `gameobject` WHERE `guid` BETWEEN 16100000 AND 16500000;

INSERT INTO `gameobject`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
     `position_x`,`position_y`,`position_z`,`orientation`,
     `rotation0`,`rotation1`,`rotation2`,`rotation3`,
     `spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 16100000 + s.`guid`, s.`id`+3700000, 750, 0, 0, 1, 1,
       s.`position_x`, s.`position_y`, s.`position_z`, s.`orientation`,
       s.`rotation0`, s.`rotation1`, s.`rotation2`, s.`rotation3`,
       s.`spawntimesecs`, s.`animprogress`, s.`state`, '', 0,
       CONCAT('map750-', p.`zone`, '-212')
FROM `cata_world`.`gameobject` s
JOIN `dc_map750_zoneport_go` p ON p.`src_guid` = s.`guid`
WHERE EXISTS (SELECT 1 FROM `gameobject_template` t WHERE t.`entry` = s.`id`+3700000);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT zone, COUNT(*) FROM dc_map750_zoneport GROUP BY zone;   -- ASH ~1032, WIN ~1593
--   SELECT COUNT(*) FROM creature   WHERE guid BETWEEN 16100000 AND 16500000;
--   SELECT COUNT(*) FROM gameobject WHERE guid BETWEEN 16100000 AND 16500000;
--
--   -- every new spawn has a template and every template has a model (expect 0):
--   SELECT COUNT(*) FROM creature c WHERE c.guid BETWEEN 16100000 AND 16500000
--     AND NOT EXISTS (SELECT 1 FROM creature_template t WHERE t.entry=c.id);
--   SELECT COUNT(*) FROM creature c WHERE c.guid BETWEEN 16100000 AND 16500000
--     AND NOT EXISTS (SELECT 1 FROM creature_template_model m WHERE m.CreatureID=c.id);
--
--   -- re-measure coverage; Ashenvale should go from 8% to near parity:
--   SELECT COUNT(*) FROM creature WHERE map=750;
--
-- Errors.log should gain NO "has no model defined" lines for the 3.7M band. If
-- it does, 211_ was not applied first.
--
-- FOLLOW-UPS this file deliberately leaves open:
--   * SmartAI for the new creatures (AIName cleared -- default AI meanwhile).
--   * The quest layer for both zones (questgivers exist, relations do not).
--   * Azshara, which needs Cata terrain before its spawns can be imported.
-- ---------------------------------------------------------------------------
