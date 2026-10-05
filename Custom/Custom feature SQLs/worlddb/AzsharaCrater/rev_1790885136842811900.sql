-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- the 11 broken main-hub quests, 2026-10-01
-- ---------------------------------------------------------------------------
-- These quests could be accepted but never finished: their kill target had no spawn on
-- map 37. Each now has one, at a level that fits the quest:
--   300102 Bears at the Larder      Young Black Bear (5-6), was Young Forest Bear (8-9)
--   300103 Restless Timberlings     Timberling (5-6), unchanged target
--   300105 What Stirs the Grove     Timberling Trampler (8-9), in their own grove
--   300201 Rifts in the Ley         Void Anomaly (15-16), was Lesser Voidwalker (20)
--   300400 Break the Spitelash      300090 Spitelash Warrior (38-39), new clone of 6190 (46-47)
--   300401 Shells for the Wall      Saltwater Snapjaw (44-45), was Wavethrasher (52-53)
--   300402 The Arcane Gluttons      Spell Eater (54-56), was Tsu'zee (59 rare elite); QL 51 -> 54
--   300403 Scales of the Blue       Cobalt Broodling (55-56), was Draconic Magelord (53-54 elite)
--   300700 The Unquiet Coast        2nd objective Ethereal Wraith (65), was Ethereal Scavenger
--   300701 Unbound and Burning      300091 Mana Surge (64-65), new clone of 6550 (40)
--   300802 Masters of the Risen     Malefic Necromancer (80), was Overseer Syra (79)
-- The two clones keep the July texts true: Kol'gar's whole storyline names the Spitelash
-- (300404, 300405), and Seryth's 300700 speaks of "the surges". They copy only their source's
-- combat SmartAI row (Disarm / Shock), not the stock Azshara quest rows (polymorph, summon).
-- The Spitelash clone takes its loot and coin from Daggerspine Raider 2595 (38-39), the Mana
-- Surge clone from Mana Wraith 18864. Quest texts change only where they name the target.
-- 300402 also gets MinLevel 48 (QuestLevel - 6). The MinLevel pass (rev_1790882908747101700)
-- set it to 45 for the old level 51; its guard (MinLevel = 47) never matches 48, so the two
-- files can be applied in either order.
--
-- Spawns: guids 9002300-9002399 (block checked empty in creature, creature_addon,
-- game_event_creature, pool_creature, creature_formations, linked_respawn). Each point was
-- taken from the server's own .map terrain (K:/Dark-Chaos/Server/data/maps, the same height
-- the server computes) and checked for: ground under it, no water over it, walkable slope,
-- a walkable path to existing spawns, the camp's own height band (by the river for the shore
-- camps); 18 yd from other camps, 30 yd from NPCs, 60 yd from Azshara Bruisers (GuardAI,
-- hostile to monsters, level 255: they would kill anything inside their 43 yd aggro range),
-- 45 yd from any spawn standing on a structure or in a cave, and outside the aggro range of
-- every mob 5+ levels above the camp. 180s respawn, short wander so the camps stay where the
-- map markers say.
-- Map markers: objective rectangles around each camp. 300400-300403 had markers on Kalimdor
-- (map 1) coordinates from the January generator; those are replaced.
--
-- Corrected 2026-10-01 (same day): 19 of these points stood where the server navmesh has no
-- walkable ground (rocks, trees, the water's edge: the ADT height map cannot see them). They
-- were moved onto navmesh ground in their camps; the live DB gets the same move from the
-- side-hub file's part 1, so re-running this file and that one agree.
--
-- Idempotent: every quest UPDATE is guarded by the old target, the spawn block and the
-- clones are deleted before insert. Restart the worldserver afterwards; do NOT use
-- `.reload quest_template` (playerbots hold Quest pointers). The bot crater questline
-- rebuilds its playable-quest list at startup and picks these quests up on its own.
-- ---------------------------------------------------------------------------

-- 1. Clone templates
DELETE FROM `creature_template` WHERE `entry` = 300090;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300090, 0, 0, 0, 0, 0, `s`.`name`, `s`.`subname`, `s`.`IconName`, `s`.`gossip_menu_id`, 38, 39, 0,
    `s`.`faction`, `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`, `s`.`speed_flight`,
    `s`.`detection_range`, `s`.`rank`, `s`.`dmgschool`, `s`.`DamageModifier`, `s`.`BaseAttackTime`,
    `s`.`RangeAttackTime`, `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`, `s`.`unit_flags`,
    `s`.`unit_flags2`, `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`, `d`.`lootid`,
    `d`.`pickpocketloot`, `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`, `d`.`maxgold`,
    `s`.`AIName`, `s`.`MovementType`, `s`.`HoverHeight`, `s`.`HealthModifier`, `s`.`ManaModifier`,
    `s`.`ArmorModifier`, `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`, `s`.`RegenHealth`,
    `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 2595 WHERE `s`.`entry` = 6190;
DELETE FROM `creature_template` WHERE `entry` = 300091;
INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT 300091, 0, 0, 0, 0, 0, `s`.`name`, `s`.`subname`, `s`.`IconName`, `s`.`gossip_menu_id`, 64, 65, 1,
    `s`.`faction`, `s`.`npcflag`, `s`.`speed_walk`, `s`.`speed_run`, `s`.`speed_swim`, `s`.`speed_flight`,
    `s`.`detection_range`, `s`.`rank`, `s`.`dmgschool`, `s`.`DamageModifier`, `s`.`BaseAttackTime`,
    `s`.`RangeAttackTime`, `s`.`BaseVariance`, `s`.`RangeVariance`, `s`.`unit_class`, `s`.`unit_flags`,
    `s`.`unit_flags2`, `s`.`dynamicflags`, `s`.`family`, `s`.`type`, `s`.`type_flags`, `d`.`lootid`,
    `d`.`pickpocketloot`, `d`.`skinloot`, `s`.`PetSpellDataId`, `s`.`VehicleId`, `d`.`mingold`, `d`.`maxgold`,
    `s`.`AIName`, `s`.`MovementType`, `s`.`HoverHeight`, `s`.`HealthModifier`, `s`.`ManaModifier`,
    `s`.`ArmorModifier`, `s`.`ExperienceModifier`, `s`.`RacialLeader`, `s`.`movementId`, `s`.`RegenHealth`,
    `s`.`CreatureImmunitiesId`, `s`.`flags_extra`, '', 0
FROM `creature_template` AS `s` JOIN `creature_template` AS `d` ON `d`.`entry` = 18864 WHERE `s`.`entry` = 6550;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (300090, 300091);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(300090, 0, 6747, 1, 1, 0),
(300091, 0, 14252, 1, 1, 0);

DELETE FROM `creature_equip_template` WHERE `CreatureID` = 300090;
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(300090, 1, 2023, 0, 5870, 0);

DELETE FROM `creature_template_spell` WHERE `CreatureID` IN (300090, 300091);
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`) VALUES
(300090, 0, 6713, 0),
(300091, 0, 9532, 0),
(300091, 1, 11824, 0);

DELETE FROM `creature_template_resistance` WHERE `CreatureID` = 300091;
INSERT INTO `creature_template_resistance` (`CreatureID`, `School`, `Resistance`, `VerifiedBuild`) VALUES
(300091, 2, 40, 0),
(300091, 3, 40, 0),
(300091, 4, 40, 0),
(300091, 5, 40, 0),
(300091, 6, 40, 0);

DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 300090;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 300090, `source_type`, 0, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
    `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
    `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
    `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 6190 AND `id` = 4;
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 300091;
INSERT INTO `smart_scripts` (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`, `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT 300091, `source_type`, 0, `link`, `event_type`, `event_phase_mask`, `event_chance`, `event_flags`,
    `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
    `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`,
    `action_param6`, `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
    `target_x`, `target_y`, `target_z`, `target_o`, `comment`
FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 6550 AND `id` = 2;

-- 2. Spawns
DELETE FROM `creature` WHERE `guid` BETWEEN 9002300 AND 9002400 AND `id` IN (1128, 2022, 2027, 2505, 10660, 10661, 17550, 18394, 31155, 300090, 300091) AND `map` = 37;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9002300, 1128, 37, 0, 0, 1, 1, 0, 213.00, 930.00, 260.79, 1.8468, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002301, 1128, 37, 0, 0, 1, 1, 0, 177.00, 906.00, 265.91, 4.2468, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002302, 1128, 37, 0, 0, 1, 1, 0, 225.00, 938.00, 262.87, 0.3636, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002303, 1128, 37, 0, 0, 1, 1, 0, 236.08, 934.94, 262.58, 2.7635, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002304, 1128, 37, 0, 0, 1, 1, 0, 165.00, 898.00, 266.26, 5.1635, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002305, 1128, 37, 0, 0, 1, 1, 0, 233.00, 950.00, 262.61, 1.2803, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002306, 1128, 37, 0, 0, 1, 1, 0, 161.00, 882.00, 267.68, 3.6802, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002307, 1128, 37, 0, 0, 1, 1, 0, 207.73, 940.18, 263.12, 6.0802, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002308, 1128, 37, 0, 0, 1, 1, 0, 175.89, 921.28, 266.49, 2.1970, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002309, 1128, 37, 0, 0, 1, 1, 0, 186.51, 938.40, 266.58, 4.5969, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300102 Bears at the Larder'),
(9002310, 2027, 37, 0, 0, 1, 1, 0, 10.00, 776.00, 276.62, 0.7137, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002311, 2027, 37, 0, 0, 1, 1, 0, -2.00, 768.00, 278.99, 3.1137, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002312, 2027, 37, 0, 0, 1, 1, 0, 26.00, 784.00, 275.44, 5.5136, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002313, 2027, 37, 0, 0, 1, 1, 0, 22.00, 768.00, 274.57, 1.6304, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002314, 2027, 37, 0, 0, 1, 1, 0, 10.00, 760.00, 274.04, 4.0304, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002315, 2027, 37, 0, 0, 1, 1, 0, 3.55, 785.86, 282.85, 0.1472, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002316, 2027, 37, 0, 0, 1, 1, 0, 38.00, 776.00, 271.63, 2.5471, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002317, 2027, 37, 0, 0, 1, 1, 0, 42.00, 792.00, 276.80, 4.9471, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002318, 2027, 37, 0, 0, 1, 1, 0, -30.00, 760.00, 281.12, 1.0639, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002319, 2027, 37, 0, 0, 1, 1, 0, 54.00, 784.00, 268.65, 3.4638, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002320, 2027, 37, 0, 0, 1, 1, 0, -46.00, 764.00, 279.75, 5.8638, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002321, 2027, 37, 0, 0, 1, 1, 0, -38.00, 748.00, 275.42, 1.9806, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300105 What Stirs the Grove'),
(9002322, 2022, 37, 0, 0, 1, 1, 0, 130.00, 806.00, 270.28, 4.3805, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002323, 2022, 37, 0, 0, 1, 1, 0, 106.00, 826.00, 272.50, 0.4973, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002324, 2022, 37, 0, 0, 1, 1, 0, 95.64, 830.71, 273.78, 2.8973, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002325, 2022, 37, 0, 0, 1, 1, 0, 114.00, 838.00, 272.21, 5.2972, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002326, 2022, 37, 0, 0, 1, 1, 0, 138.00, 838.00, 272.13, 1.4140, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002327, 2022, 37, 0, 0, 1, 1, 0, 150.00, 770.00, 258.44, 3.8140, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002328, 2022, 37, 0, 0, 1, 1, 0, 126.00, 846.00, 272.21, 6.2139, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002329, 2022, 37, 0, 0, 1, 1, 0, 138.00, 854.00, 270.93, 2.3307, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002330, 2022, 37, 0, 0, 1, 1, 0, 182.00, 802.00, 259.29, 4.7307, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300103 Restless Timberlings'),
(9002331, 17550, 37, 0, 0, 1, 1, 0, 42.00, 622.00, 267.12, 0.8475, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002332, 17550, 37, 0, 0, 1, 1, 0, 30.00, 614.00, 269.88, 3.2474, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002333, 17550, 37, 0, 0, 1, 1, 0, 30.00, 630.00, 269.85, 5.6474, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002334, 17550, 37, 0, 0, 1, 1, 0, 50.00, 610.00, 265.38, 1.7642, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002335, 17550, 37, 0, 0, 1, 1, 0, 50.00, 634.00, 267.48, 4.1641, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002336, 17550, 37, 0, 0, 1, 1, 0, 58.00, 622.00, 264.58, 0.2809, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002337, 17550, 37, 0, 0, 1, 1, 0, 38.00, 602.00, 268.63, 2.6809, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002338, 17550, 37, 0, 0, 1, 1, 0, 38.00, 642.00, 269.80, 5.0808, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002339, 17550, 37, 0, 0, 1, 1, 0, 18.00, 622.00, 268.80, 1.1976, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002340, 17550, 37, 0, 0, 1, 1, 0, 66.00, 610.00, 267.44, 3.5976, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300201 Rifts in the Ley'),
(9002341, 300090, 37, 0, 0, 1, 1, 1, 430.62, 265.96, 249.79, 5.9975, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002342, 300090, 37, 0, 0, 1, 1, 1, 439.29, 265.51, 243.03, 2.1143, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002343, 300090, 37, 0, 0, 1, 1, 1, 401.00, 265.00, 268.84, 4.5143, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002344, 300090, 37, 0, 0, 1, 1, 1, 428.80, 261.24, 240.28, 0.6310, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002345, 300090, 37, 0, 0, 1, 1, 1, 385.00, 269.00, 269.48, 3.0310, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002346, 300090, 37, 0, 0, 1, 1, 1, 418.31, 255.38, 240.72, 5.4310, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002347, 300090, 37, 0, 0, 1, 1, 1, 377.00, 257.00, 264.56, 1.5477, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002348, 300090, 37, 0, 0, 1, 1, 1, 444.44, 254.93, 241.52, 3.9477, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002349, 300090, 37, 0, 0, 1, 1, 1, 369.00, 269.00, 268.47, 0.0645, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002350, 300090, 37, 0, 0, 1, 1, 1, 438.93, 245.60, 239.83, 2.4645, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002351, 300090, 37, 0, 0, 1, 1, 1, 397.00, 221.00, 239.62, 4.8644, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002352, 300090, 37, 0, 0, 1, 1, 1, 433.00, 209.00, 269.41, 0.9812, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300400 Break the Spitelash'),
(9002353, 2505, 37, 0, 0, 1, 1, 0, 254.00, 114.00, 234.98, 3.3812, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002354, 2505, 37, 0, 0, 1, 1, 0, 262.00, 126.00, 231.34, 5.7811, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002355, 2505, 37, 0, 0, 1, 1, 0, 246.00, 126.00, 230.54, 1.8979, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002356, 2505, 37, 0, 0, 1, 1, 0, 266.00, 106.00, 237.95, 4.2979, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002357, 2505, 37, 0, 0, 1, 1, 0, 242.00, 106.00, 236.91, 0.4146, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002358, 2505, 37, 0, 0, 1, 1, 0, 254.00, 98.00, 239.54, 2.8146, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002359, 2505, 37, 0, 0, 1, 1, 0, 274.00, 118.00, 236.57, 5.2146, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002360, 2505, 37, 0, 0, 1, 1, 0, 234.00, 118.00, 233.06, 1.3313, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002361, 2505, 37, 0, 0, 1, 1, 0, 268.79, 93.86, 240.46, 3.7313, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002362, 2505, 37, 0, 0, 1, 1, 0, 233.24, 99.09, 236.90, 6.1313, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300401 Shells for the Wall'),
(9002363, 10661, 37, 0, 0, 1, 1, 0, 1147.00, 121.00, 268.96, 2.2480, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002364, 10661, 37, 0, 0, 1, 1, 0, 1107.17, 108.62, 268.57, 4.6480, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002365, 10661, 37, 0, 0, 1, 1, 0, 1119.00, 149.00, 271.55, 0.7648, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002366, 10661, 37, 0, 0, 1, 1, 0, 1107.00, 137.00, 268.67, 3.1647, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002367, 10661, 37, 0, 0, 1, 1, 0, 1097.07, 87.02, 269.01, 5.5647, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002368, 10661, 37, 0, 0, 1, 1, 0, 1091.00, 105.00, 269.10, 1.6815, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002369, 10661, 37, 0, 0, 1, 1, 0, 1110.96, 156.53, 274.26, 4.0814, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002370, 10661, 37, 0, 0, 1, 1, 0, 1087.00, 93.00, 269.91, 0.1982, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300402 The Arcane Gluttons'),
(9002371, 10660, 37, 0, 0, 1, 1, 0, 1123.00, 89.00, 268.25, 2.5982, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002372, 10660, 37, 0, 0, 1, 1, 0, 1114.13, 100.80, 269.46, 4.9982, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002373, 10660, 37, 0, 0, 1, 1, 0, 1103.00, 101.00, 268.87, 1.1149, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002374, 10660, 37, 0, 0, 1, 1, 0, 1099.00, 113.00, 268.62, 3.5149, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002375, 10660, 37, 0, 0, 1, 1, 0, 1107.00, 149.00, 270.96, 5.9149, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002376, 10660, 37, 0, 0, 1, 1, 0, 1090.02, 117.67, 268.66, 2.0316, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002377, 10660, 37, 0, 0, 1, 1, 0, 1091.00, 81.00, 269.07, 4.4316, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002378, 10660, 37, 0, 0, 1, 1, 0, 1095.00, 149.00, 270.35, 0.5484, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300403 Scales of the Blue'),
(9002379, 18394, 37, 0, 0, 1, 1, 0, 930.00, 245.00, 304.04, 2.9483, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300700 The Unquiet Coast'),
(9002380, 18394, 37, 0, 0, 1, 1, 0, 918.00, 237.00, 301.76, 5.3483, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300700 The Unquiet Coast'),
(9002381, 18394, 37, 0, 0, 1, 1, 0, 918.00, 253.00, 303.53, 1.4651, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300700 The Unquiet Coast'),
(9002382, 18394, 37, 0, 0, 1, 1, 0, 938.00, 257.00, 307.47, 3.8650, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300700 The Unquiet Coast'),
(9002383, 18394, 37, 0, 0, 1, 1, 0, 930.00, 229.00, 300.73, 6.2650, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300700 The Unquiet Coast'),
(9002384, 18394, 37, 0, 0, 1, 1, 0, 946.00, 245.00, 307.57, 2.3818, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300700 The Unquiet Coast'),
(9002385, 300091, 37, 0, 0, 1, 1, 0, 986.00, 176.00, 270.33, 4.7817, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002386, 300091, 37, 0, 0, 1, 1, 0, 974.00, 168.00, 269.33, 0.8985, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002387, 300091, 37, 0, 0, 1, 1, 0, 974.00, 184.00, 272.26, 3.2985, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002388, 300091, 37, 0, 0, 1, 1, 0, 994.00, 164.00, 268.34, 5.6984, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002389, 300091, 37, 0, 0, 1, 1, 0, 994.00, 188.00, 271.13, 1.8152, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002390, 300091, 37, 0, 0, 1, 1, 0, 1002.00, 176.00, 270.27, 4.2152, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002391, 300091, 37, 0, 0, 1, 1, 0, 982.00, 196.00, 272.60, 0.3320, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002392, 300091, 37, 0, 0, 1, 1, 0, 1010.00, 164.00, 268.51, 2.7319, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002393, 300091, 37, 0, 0, 1, 1, 0, 962.00, 192.00, 281.41, 5.1319, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002394, 300091, 37, 0, 0, 1, 1, 0, 986.00, 144.00, 268.09, 1.2487, 180, 10, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300701 Unbound and Burning'),
(9002395, 31155, 37, 0, 0, 1, 1, 0, -372.00, -162.00, 296.26, 3.6486, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300802 Masters of the Risen'),
(9002396, 31155, 37, 0, 0, 1, 1, 0, -352.00, -150.00, 296.16, 6.0486, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300802 Masters of the Risen'),
(9002397, 31155, 37, 0, 0, 1, 1, 0, -372.00, -138.00, 297.38, 2.1654, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300802 Masters of the Risen'),
(9002398, 31155, 37, 0, 0, 1, 1, 0, -352.00, -174.00, 295.83, 4.5653, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300802 Masters of the Risen'),
(9002399, 31155, 37, 0, 0, 1, 1, 0, -392.00, -150.00, 298.68, 0.6821, 180, 8, 0, 1, 0, 1, 0, 0, 0, '', 0, 0, 'Azshara Crater 300802 Masters of the Risen');

-- 3. Quest targets and the texts that name them (guarded: only while the old target is set)
-- 300102 Bears at the Larder
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 1128,
    `LogDescription` = 'Slay 8 Young Black Bears.',
    `QuestDescription` = 'Bears, $N. Great shaggy thieves, the lot of ''em. They''ve caught the scent of our stores, and now they''ll not leave off till the larder''s bare.$B$BPut down eight o'' the young black bears prowlin'' near the outpost. Do it clean, and there''s silver waitin'' for ye.',
    `QuestCompletionLog` = 'The black bears have been driven off.'
WHERE `ID` = 300102 AND `RequiredNpcOrGo1` = 822;
-- 300105 What Stirs the Grove
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 2027,
    `LogDescription` = 'Defeat 12 Timberling Tramplers.',
    `QuestDescription` = 'The Timberlings do not simply wander, $N. They gather, they turn, as though some old will bends them to a single purpose. I would know what wakes beneath this grove.$B$BStrike down twelve of the hulking Tramplers that herd them. Cut deep enough into their number, and whatever commands them may show itself. Be ready if it does.'
WHERE `ID` = 300105 AND `RequiredNpcOrGo1` = 2022;
-- 300201 Rifts in the Ley
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 17550,
    `LogDescription` = 'Destroy 8 Void Anomalies.',
    `QuestDescription` = 'There is a wrongness threading these ruins, $N. Not the wild arcane the crater leaks, but something colder. Void. It seeps in wherever the ley lines have frayed, and things crawl through the seams.$B$BVoid anomalies are gathering at the broken lines. Destroy eight of them before the rift they widen becomes a wound we cannot close.',
    `QuestCompletionLog` = 'The Void Anomalies have been destroyed.'
WHERE `ID` = 300201 AND `RequiredNpcOrGo1` = 418;
-- 300400 Break the Spitelash
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300090
WHERE `ID` = 300400 AND `RequiredNpcOrGo1` = 6190;
-- 300401 Shells for the Wall
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 2505,
    `LogDescription` = 'Kill 10 Saltwater Snapjaws.',
    `QuestDescription` = 'Snapjaws crowd the shallows where the river bends toward the drowned shrine, and their shells are plate no blade of ours cracks easily.$B$BWaste, I call it. Those shells would armor our bunkers against the naga tide better than any timber we could haul in.$B$BGo to the water''s edge and slay ten Saltwater Snapjaws, $N. We will strip the shells from what you leave behind.',
    `QuestCompletionLog` = 'Ten Saltwater Snapjaws slain.'
WHERE `ID` = 300401 AND `RequiredNpcOrGo1` = 6348;
-- 300402 The Arcane Gluttons
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 10661,
    `QuestLevel` = 54,
    `MinLevel` = 48,
    `LogDescription` = 'Kill 8 Spell Eaters.',
    `QuestDescription` = 'There is a hunger loose on the eastern river, $N. Spell Eaters, blue dragonkin drawn by the raw power bleeding out of this crater. They drink magic the way a whirlpool drinks a boat, and my mages cannot hold a spell within sight of them.$B$BEight of them prowl the riverbank. Destroy them before they swallow every last spell we have left to fight the naga with.',
    `QuestCompletionLog` = 'Eight Spell Eaters destroyed.'
WHERE `ID` = 300402 AND `RequiredNpcOrGo1` = 11467;
-- 300403 Scales of the Blue
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 10660,
    `LogDescription` = 'Kill 6 Cobalt Broodlings.',
    `QuestDescription` = 'Look to the eastern river and you will see them, $N. Cobalt Broodlings, young of the blue flight, drawn like moths to the arcane fire burning in this crater.$B$BI''ll not pretend it is only duty. A blue dragon''s scales fetch a fortune from the right buyer, and a Wavemaster''s war chest runs dry same as any other.$B$BBring down six of them and strip their scales. Storm and coin both favor the bold.',
    `QuestCompletionLog` = 'Six Cobalt Broodlings slain.'
WHERE `ID` = 300403 AND `RequiredNpcOrGo1` = 6129;
-- 300700 The Unquiet Coast
UPDATE `quest_template` SET
    `RequiredNpcOrGo2` = 18394,
    `LogDescription` = 'Kill 10 Kirin''Var Ghosts and 8 Ethereal Wraiths.',
    `QuestDescription` = 'I keep watch over the drakes and the surges, $N, but the dead along this coast are my burden too. The arcane bleeding out of the crater will not let them lie still. Kirin''Var Ghosts drift where their bodies fell, and Ethereal Wraiths pick at what magic clings to their bones.$B$BThey feel no peace, and while they linger they draw yet more corruption to them. Go to the shore and give them the only mercy left. Ten of the ghosts, and eight of the wraiths that torment them.'
WHERE `ID` = 300700 AND `RequiredNpcOrGo2` = 18309;
-- 300701 Unbound and Burning
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 300091
WHERE `ID` = 300701 AND `RequiredNpcOrGo1` = 15527;
-- 300802 Masters of the Risen
UPDATE `quest_template` SET
    `RequiredNpcOrGo1` = 31155,
    `LogDescription` = 'Slay 4 Malefic Necromancers.',
    `QuestDescription` = 'Kill the risen and they simply rise again, $N. The strength of this incursion is not in its corpses but in the hands that command them. Four Malefic Necromancers move among the sanctum''s ruins, and every soldier we destroy they raise anew.$B$BFind those four and end them. Break the will behind the horde, and the horde itself falls apart. I have seen it work on a hundred battlefields.'
WHERE `ID` = 300802 AND `RequiredNpcOrGo1` = 29518;

UPDATE `quest_offer_reward` SET `RewardText` = 'The spell eaters are undone, and there is magic in the air again.$B$BMy spellcasters can breathe. That hunger would have left us blind and weaponless. Well done, $N.' WHERE `ID` = 300402;
UPDATE `quest_request_items` SET `CompletionText` = 'The anomalies still bleed through the ley lines. We need them gone.' WHERE `ID` = 300201;

-- 4. Map markers (WorldMapAreaId 613 = Azshara Crater; rectangle = camp +/- 20 yd)
DELETE FROM `quest_poi` WHERE `QuestID` = 300102 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300102, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300102 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300102, 0, 0, 141, 862, 0),
(300102, 0, 1, 141, 970, 0),
(300102, 0, 2, 257, 970, 0),
(300102, 0, 3, 257, 862, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300105 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300105, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300105 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300105, 0, 0, -66, 728, 0),
(300105, 0, 1, -66, 812, 0),
(300105, 0, 2, 74, 812, 0),
(300105, 0, 3, 74, 728, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300103 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300103, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300103 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300103, 0, 0, 75, 750, 0),
(300103, 0, 1, 75, 874, 0),
(300103, 0, 2, 202, 874, 0),
(300103, 0, 3, 202, 750, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300201 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300201, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300201 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300201, 0, 0, -2, 582, 0),
(300201, 0, 1, -2, 662, 0),
(300201, 0, 2, 86, 662, 0),
(300201, 0, 3, 86, 582, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300400 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300400, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300400 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300400, 0, 0, 349, 189, 0),
(300400, 0, 1, 349, 289, 0),
(300400, 0, 2, 465, 289, 0),
(300400, 0, 3, 465, 189, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300401 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300401, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300401 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300401, 0, 0, 213, 73, 0),
(300401, 0, 1, 213, 146, 0),
(300401, 0, 2, 294, 146, 0),
(300401, 0, 3, 294, 73, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300402 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300402, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300402 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300402, 0, 0, 1067, 67, 0),
(300402, 0, 1, 1067, 177, 0),
(300402, 0, 2, 1167, 177, 0),
(300402, 0, 3, 1167, 67, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300403 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300403, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300403 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300403, 0, 0, 1070, 61, 0),
(300403, 0, 1, 1070, 169, 0),
(300403, 0, 2, 1143, 169, 0),
(300403, 0, 3, 1143, 61, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300700 AND `id` = 1;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300700, 1, 1, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300700 AND `Idx1` = 1;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300700, 1, 0, 898, 209, 0),
(300700, 1, 1, 898, 277, 0),
(300700, 1, 2, 966, 277, 0),
(300700, 1, 3, 966, 209, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300701 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300701, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300701 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300701, 0, 0, 942, 124, 0),
(300701, 0, 1, 942, 216, 0),
(300701, 0, 2, 1030, 216, 0),
(300701, 0, 3, 1030, 124, 0);
DELETE FROM `quest_poi` WHERE `QuestID` = 300802 AND `id` = 0;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(300802, 0, 0, 37, 613, 0, 0, 3, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 300802 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(300802, 0, 0, -412, -194, 0),
(300802, 0, 1, -412, -118, 0),
(300802, 0, 2, -332, -118, 0),
(300802, 0, 3, -332, -194, 0);
