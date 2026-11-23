-- Map 751: fill Darrowmere Lake (area 16744, Western Plaguelands band 148-153)
--
-- Report: "in darrowmere lake on map 751 there are like no spawns".
--
-- Not a lost import: cata_world, TC_Cata_world, skyfire_world and stock WotLK map 0 have no creature in
-- the lake past its north shore either. Measured from the server heightmap + liquid layer (5 yd grid):
-- 17,254 water samples (median depth 29 yd, max 79) and 8,335 land samples, and only 5 creatures stand
-- inside the area at all (east edge, x 1644-1729). Nothing on 751 swims at this level, so two templates
-- are added.
--
-- TEMPLATES (owner's choice 2026-11-17: new lake mobs + shore)
--   830331 Darrowmere Surge   copy of 3608519 Blighted Surge (vanilla display 5497, Drowning Death 16555,
--                             Toxic Bolt 16554, frost immune -6), level 150-151. Cata's Flow of Gratitude
--                             85873 on aggro is left out. Stationary on the lake floor, as the EPL Surges are.
--   830332 Darrowmere Snapjaw copy of 4102505 Saltwater Snapjaw (display 5027, family 21), level 150-151.
--                             Its Crushing Bite 80604 is not in the server Spell.dbc, so Rend 13445 instead.
-- LOOT: copies of the source tables without quest drops (QuestRequired 1), drop-ladder reference moved
--   to 752216 (RequiredLevel 148). Snapjaw also gets the source skinning table.
--
-- SPAWNS 9026000-9026057 (58), positions from the server .map files (area, ground, liquid level):
--   26 Surges on the lake floor at 2.5-9 yd depth within 70 yd of a shore, at least 75 yd apart;
--   14 Snapjaws in the shallows or on flat ground within 12 yd of the water, at least 60 yd apart;
--   18 existing WPL 153 mobs on flat banks at lakeside height (z <= 77), at least 55 yd apart:
--      north bank Diseased Wolf 3601817 / Venom Mist Lurker 3601822, south bank Skeletal Flayer 3601783 / Lurker.
--   Every point keeps 35-40 yd from the 241 creatures already in the box and 40 yd from Caer Darrow.
--   z is heightmap ground; WMO objects are not in that layer, so check a few with .gps after applying.
--
-- REVERT: delete creature guid 9026000-9026057, then creature_template / _model / loot / skinning / smart_scripts
--   rows of 830331 and 830332.

-- 1. templates (REPLACE: template rows are never deleted)
REPLACE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(830331, 0, 0, 0, 0, 0, 'Darrowmere Surge', NULL, NULL, 0, 150, 151, 2, 91, 0, 1, 1.28968, 1, 1, 18, 0, 0, 0.50286, 2000, 2000, 1, 1, 1, 0, 2048, 0, 0, 4, 0, 830331, 0, 0, 0, 0, 0, 0, 'SmartAI', 0, 1, 0.637891, 1, 1, 1, 0, 0, 1, -6, 0, '', 12340),
(830332, 0, 0, 0, 0, 0, 'Darrowmere Snapjaw', NULL, NULL, 0, 150, 151, 2, 7, 0, 1, 1.14286, 1, 1, 20, 0, 0, 0.493768, 2000, 2000, 1, 1, 1, 0, 2048, 0, 21, 1, 1, 830332, 0, 830332, 0, 0, 0, 0, 'SmartAI', 1, 1, 0.692011, 1, 1, 1, 0, 0, 1, 0, 0, '', 15595);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (830331, 830332);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(830331, 0, 5497, 1, 1, 0),
(830332, 0, 5027, 1, 1, 0);

-- 2. combat AI
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (830331, 830332) AND `source_type` = 0;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
(830331, 0, 0, 0, 0, 0, 100, 0, 5000, 8000, 24000, 25000, 0, 0, 11, 16555, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 'Darrowmere Surge - In Combat - Cast Drowning Death'),
(830331, 0, 1, 0, 0, 0, 100, 0, 0, 0, 3400, 4700, 0, 0, 11, 16554, 64, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Darrowmere Surge - In Combat - Cast Toxic Bolt'),
(830332, 0, 0, 0, 0, 0, 100, 0, 3500, 4500, 12000, 16000, 0, 0, 11, 13445, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Darrowmere Snapjaw - In Combat - Cast Rend');

-- 3. loot: source tables minus quest drops, ladder reference moved to the band-148 table 752216
DELETE FROM `creature_loot_template` WHERE `Entry` = 830331;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 830331, `Item`, CASE WHEN `Reference` = 752218 THEN 752216 ELSE `Reference` END, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Darrowmere Surge, copy of 3608519'
FROM `creature_loot_template` WHERE `Entry` = 3608519 AND `QuestRequired` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 830332;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 830332, `Item`, CASE WHEN `Reference` = 752215 THEN 752216 ELSE `Reference` END, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Darrowmere Snapjaw, copy of 4102505'
FROM `creature_loot_template` WHERE `Entry` = 4102505 AND `QuestRequired` = 0;
DELETE FROM `skinning_loot_template` WHERE `Entry` = 830332;
INSERT INTO `skinning_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 830332, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, 'Darrowmere Snapjaw, copy of 4102505'
FROM `skinning_loot_template` WHERE `Entry` = 4102505;

-- 4. spawns
DELETE FROM `creature` WHERE `guid` BETWEEN 9026000 AND 9026057 AND `id` IN (830331, 830332, 3601783, 3601817, 3601822);
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9026000, 830331, 751, 4932, 16744, 1, 1, 0, 1510.00, -2840.00, 49.79, 4.539, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026001, 830331, 751, 4932, 16744, 1, 1, 0, 975.00, -2390.00, 49.55, 3.451, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026002, 830331, 751, 4932, 16744, 1, 1, 0, 1510.00, -2275.00, 50.07, 2.995, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026003, 830331, 751, 4932, 16744, 1, 1, 0, 1670.00, -2585.00, 49.73, 0.282, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026004, 830331, 751, 4932, 16744, 1, 1, 0, 1220.00, -3020.00, 46.57, 1.124, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026005, 830331, 751, 4932, 16744, 1, 1, 0, 1645.00, -2775.00, 44.89, 1.739, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026006, 830331, 751, 4932, 16744, 1, 1, 0, 1005.00, -2265.00, 48.06, 2.955, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026007, 830331, 751, 4932, 16744, 1, 1, 0, 1300.00, -2975.00, 46.90, 0.123, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026008, 830331, 751, 4932, 16744, 1, 1, 0, 1255.00, -1920.00, 45.56, 5.893, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026009, 830331, 751, 4932, 16744, 1, 1, 0, 1530.00, -2410.00, 49.77, 1.576, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026010, 830331, 751, 4932, 16744, 1, 1, 0, 1050.00, -2690.00, 47.10, 0.712, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026011, 830331, 751, 4932, 16744, 1, 1, 0, 980.00, -2635.00, 43.91, 4.034, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026012, 830331, 751, 4932, 16744, 1, 1, 0, 1090.00, -2990.00, 48.93, 0.521, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026013, 830331, 751, 4932, 16744, 1, 1, 0, 1560.00, -2525.00, 49.38, 0.061, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026014, 830331, 751, 4932, 16744, 1, 1, 0, 1055.00, -2090.00, 47.27, 4.608, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026015, 830331, 751, 4932, 16744, 1, 1, 0, 1570.00, -2210.00, 46.38, 1.974, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026016, 830331, 751, 4932, 16744, 1, 1, 0, 1375.00, -2020.00, 50.18, 3.532, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026017, 830331, 751, 4932, 16744, 1, 1, 0, 1440.00, -2995.00, 49.31, 3.214, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026018, 830331, 751, 4932, 16744, 1, 1, 0, 1005.00, -2820.00, 48.14, 2.259, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026019, 830331, 751, 4932, 16744, 1, 1, 0, 985.00, -2155.00, 46.87, 0.386, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026020, 830331, 751, 4932, 16744, 1, 1, 0, 1635.00, -2670.00, 43.96, 3.499, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026021, 830331, 751, 4932, 16744, 1, 1, 0, 1445.00, -2065.00, 46.22, 5.797, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026022, 830331, 751, 4932, 16744, 1, 1, 0, 945.00, -2480.00, 45.63, 1.372, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026023, 830331, 751, 4932, 16744, 1, 1, 0, 1485.00, -2150.00, 45.92, 4.899, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026024, 830331, 751, 4932, 16744, 1, 1, 0, 1155.00, -2015.00, 47.69, 0.075, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026025, 830331, 751, 4932, 16744, 1, 1, 0, 1580.00, -2870.00, 44.12, 0.776, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Surge on the lake floor'),
(9026026, 830332, 751, 4932, 16744, 1, 1, 0, 1035.00, -2945.00, 60.96, 6.104, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026027, 830332, 751, 4932, 16744, 1, 1, 0, 1010.00, -2755.00, 52.40, 4.484, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026028, 830332, 751, 4932, 16744, 1, 1, 0, 920.00, -2555.00, 56.13, 4.135, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026029, 830332, 751, 4932, 16744, 1, 1, 0, 1365.00, -3060.00, 59.01, 2.757, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026030, 830332, 751, 4932, 16744, 1, 1, 0, 980.00, -2330.00, 56.79, 5.154, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026031, 830332, 751, 4932, 16744, 1, 1, 0, 1310.00, -1955.00, 51.46, 0.784, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026032, 830332, 751, 4932, 16744, 1, 1, 0, 985.00, -2700.00, 56.80, 4.186, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026033, 830332, 751, 4932, 16744, 1, 1, 0, 1200.00, -1960.00, 55.74, 0.660, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026034, 830332, 751, 4932, 16744, 1, 1, 0, 1270.00, -2735.00, 64.00, 1.714, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026035, 830332, 751, 4932, 16744, 1, 1, 0, 1540.00, -2350.00, 58.12, 3.339, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026036, 830332, 751, 4932, 16744, 1, 1, 0, 1640.00, -2530.00, 60.54, 1.471, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026037, 830332, 751, 4932, 16744, 1, 1, 0, 1560.00, -2465.00, 58.95, 2.618, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026038, 830332, 751, 4932, 16744, 1, 1, 0, 1730.00, -2560.00, 63.28, 4.728, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026039, 830332, 751, 4932, 16744, 1, 1, 0, 1455.00, -2910.00, 50.85, 4.859, 300, 6, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Snapjaw at the waterline'),
(9026040, 3601817, 751, 4932, 16744, 1, 1, 0, 1140.00, -1955.00, 63.70, 1.664, 300, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Diseased Wolf on the bank'),
(9026041, 3601822, 751, 4932, 16744, 1, 1, 0, 1100.00, -2020.00, 61.84, 2.749, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026042, 3601783, 751, 4932, 16744, 1, 1, 0, 1145.00, -3085.00, 65.11, 1.475, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Skeletal Flayer on the bank'),
(9026043, 3601822, 751, 4932, 16744, 1, 1, 0, 1695.00, -2640.00, 69.55, 3.869, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026044, 3601817, 751, 4932, 16744, 1, 1, 0, 950.00, -2230.00, 70.74, 2.657, 300, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Diseased Wolf on the bank'),
(9026045, 3601783, 751, 4932, 16744, 1, 1, 0, 960.00, -2785.00, 64.94, 0.378, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Skeletal Flayer on the bank'),
(9026046, 3601822, 751, 4932, 16744, 1, 1, 0, 1565.00, -2285.00, 64.44, 2.947, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026047, 3601783, 751, 4932, 16744, 1, 1, 0, 990.00, -2905.00, 61.89, 0.918, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Skeletal Flayer on the bank'),
(9026048, 3601822, 751, 4932, 16744, 1, 1, 0, 1425.00, -3050.00, 63.54, 5.800, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026049, 3601822, 751, 4932, 16744, 1, 1, 0, 1365.00, -1960.00, 61.49, 1.701, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026050, 3601783, 751, 4932, 16744, 1, 1, 0, 1095.00, -3050.00, 61.43, 1.379, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Skeletal Flayer on the bank'),
(9026051, 3601822, 751, 4932, 16744, 1, 1, 0, 1285.00, -3040.00, 64.34, 3.665, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026052, 3601783, 751, 4932, 16744, 1, 1, 0, 915.00, -2415.00, 69.58, 3.854, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Skeletal Flayer on the bank'),
(9026053, 3601822, 751, 4932, 16744, 1, 1, 0, 1520.00, -2895.00, 61.95, 3.454, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026054, 3601817, 751, 4932, 16744, 1, 1, 0, 1205.00, -1885.00, 75.85, 4.165, 300, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Diseased Wolf on the bank'),
(9026055, 3601822, 751, 4932, 16744, 1, 1, 0, 1545.00, -2135.00, 74.41, 4.065, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank'),
(9026056, 3601783, 751, 4932, 16744, 1, 1, 0, 890.00, -2500.00, 74.34, 6.243, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Skeletal Flayer on the bank'),
(9026057, 3601822, 751, 4932, 16744, 1, 1, 0, 1245.00, -3080.00, 75.57, 3.511, 300, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'DC 751 Darrowmere Lake: Venom Mist Lurker on the bank');
