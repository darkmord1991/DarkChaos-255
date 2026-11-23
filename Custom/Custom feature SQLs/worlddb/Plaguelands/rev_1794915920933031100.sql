-- ===========================================================================
-- HyjalCata r50 -- Darkshore (map 750): ports from BFA-HavenCore #715-#722
-- (2026-11-11 .. 11-14) plus one gap of our own that they exposed.
--
-- HavenCore is TC 8.3.7 (BFA flags, quest_objectives, phase_area): only the
-- MECHANIC is taken from them; every id below is ours (+3,700,000 creatures,
-- spawn guids from our own map-750 rows, coordinates verified against our
-- spawns -- map 750 keeps Kalimdor's coordinate space).
--
-- Already correct on our side, so NOT ported:
--   #717 Reason to Worry: no queststarter hack on Morra, Overseer's Orders
--        drops at 49.7 % with QuestRequired 0, and the five dead laborers +
--        dead overseer at Morra's camp already carry aura 29266 (same six
--        spawns HavenCore flags, matched by position).
--   #722 Horoo the Flamekeeper already patrols (path 15861945, 25 points);
--        Twilight Rider (Humanoid) 3734293 has no spawns here.
--   A Lost Companion: Grimclaw's corpse is already spawned (15860967,
--        bytes1 7) at HavenCore's position.
--
-- Not ported: HavenCore's 120 s duration for spell 62624 (a hotfix row);
-- ours keeps the client's 20 s, which needs no Spell.dbc change.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A) 13509 "War Supplies" (HavenCore #715). Sentinel Torch 44999 casts 62624,
--    whose only target is TARGET_UNIT_NEARBY_ENTRY (38). That target needs a
--    conditions row to know WHICH entry, and the credit bunny had no AI, so
--    the torch failed with "invalid target" and the quest could not progress.
--    The aura condition stops one crate being burned twice while it burns.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` = 3733056 AND `AIName` = '';

DELETE FROM `smart_scripts` WHERE `entryorguid` = 3733056 AND `source_type` = 0;
INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(3733056, 0, 0, 0, 8, 0, 100, 0, 62624, 0, 0, 0, 0, 0, 33, 3733056, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
 'Shatterspear Supplies Credit Bunny - On Spellhit Torch Shatterspear Supplies - Quest Credit (13509)');

DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` = 62624;
INSERT INTO `conditions`
    (`SourceTypeOrReferenceId`,`SourceGroup`,`SourceEntry`,`SourceId`,`ElseGroup`,`ConditionTypeOrReference`,
     `ConditionTarget`,`ConditionValue1`,`ConditionValue2`,`ConditionValue3`,`NegativeCondition`,`ErrorType`,
     `ErrorTextId`,`ScriptName`,`Comment`)
VALUES
(13, 1, 62624, 0, 0, 31, 0, 3, 3733056, 0, 0, 0, 0, '', 'Torch Shatterspear Supplies - target Shatterspear Supplies Credit Bunny'),
(13, 1, 62624, 0, 0, 1, 0, 62624, 0, 0, 1, 0, 0, '', 'Torch Shatterspear Supplies - target is not already burning');

-- ---------------------------------------------------------------------------
-- B) 13564 "A Lost Companion" (HavenCore #721). The quest has no objective
--    except "Locate Grimclaw.", so without the exploration flag it completed
--    the moment it was accepted. Now the player has to reach the corpse.
--    Event-driven (out-of-combat line of sight, 30 yd) instead of HavenCore's
--    1 s timer; guid-scoped because a living Grimclaw may be spawned later.
-- ---------------------------------------------------------------------------
UPDATE `quest_template_addon` SET `SpecialFlags` = `SpecialFlags` | 2 WHERE `ID` = 13564;

UPDATE `creature_template` SET `AIName` = 'SmartAI' WHERE `entry` = 3733053 AND `AIName` = '';

DELETE FROM `smart_scripts` WHERE `entryorguid` = -15860967 AND `source_type` = 0;
INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(-15860967, 0, 0, 0, 10, 0, 100, 0, 2, 30, 0, 0, 1, 0, 15, 13564, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
 'Grimclaw - OOC LoS player within 30 yd - Area Explored Or Event Happens (13564)');

-- ---------------------------------------------------------------------------
-- C) Our own gap: the Lor'danel questgivers Volcor 32960 (starts 13564) and
--    Cerellean Whiteclaw 32959 (starts and ends 13563, 13570) were never
--    spawned. In nelt_world they are phaseMask 4 (Lor'danel after the rescue),
--    which neither 184_ nor r49 imported, so all three quests were
--    unreachable. Map 750 has no phasing, so they are spawned always visible
--    and gated by quest chain instead, with nelt's prerequisites: 13563 and
--    13564 after 13518 "The Last Wave of Survivors", 13570 after 13591.
--    Their wounded beach variants (3733093/3733094, r49) stay where they are.
--    Positions, stand state and Cerellean's weapon (3494) are nelt's.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_addon` WHERE `entry` IN (3732959, 3732960);
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(3732959, 0, 0, 65536, 1, 0, 0, NULL),
(3732960, 0, 0, 7, 1, 0, 0, NULL);

DELETE FROM `creature_equip_template` WHERE `CreatureID` = 3732959;
INSERT INTO `creature_equip_template` (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`) VALUES
(3732959, 1, 3494, 0, 0, 0);

-- Level 15 on the Darkshore band (source 10-31 -> 80-90), as 233_ would have
-- done had they been spawned when it ran.
UPDATE `creature_template` SET `minlevel` = 82, `maxlevel` = 82 WHERE `entry` IN (3732959, 3732960);

-- Own guid block 9025000+: 9025007-9025008 checked empty on 2026-11-17.
DELETE FROM `creature` WHERE `guid` IN (9025007, 9025008) AND `id` IN (3732959, 3732960);
INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9025007, 3732960, 750, 0, 0, 1, 1, 0, 7445.88, -276.52, 13.7653, 1.58825, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r50 - Volcor, Lor''danel (nelt phase 4)'),
(9025008, 3732959, 750, 0, 0, 1, 1, 1, 7451.88, -268.619, 12.6927, 5.9274, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Darkshore-Cata r50 - Cerellean Whiteclaw, Lor''danel (nelt phase 4)');

UPDATE `quest_template_addon` SET `PrevQuestID` = 13518 WHERE `ID` IN (13563, 13564);
UPDATE `quest_template_addon` SET `PrevQuestID` = 13591 WHERE `ID` = 13570;

-- Bring the three onto the zone's quest standard (all 87 other zone-4929
-- quests): scaled level, MinLevel 78, 76,500 copper at XP difficulty 5,
-- 2 x Emberwood Sap in the first free reward slot (13570 keeps Withers in 1).
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 78, `RewardMoney` = 76500 WHERE `ID` IN (13563, 13570);
UPDATE `quest_template` SET `RewardItem1` = 400000, `RewardAmount1` = 2 WHERE `ID` IN (13563, 13564) AND `RewardItem1` IN (0, 400000);
UPDATE `quest_template` SET `RewardItem2` = 400000, `RewardAmount2` = 2 WHERE `ID` = 13570 AND `RewardItem2` IN (0, 400000);

DELETE FROM `dc_map750_questzone` WHERE `quest` IN (13563, 13564, 13570);
INSERT INTO `dc_map750_questzone` (`quest`,`zone`) VALUES
(13563, 4929), (13564, 4929), (13570, 4929);

-- ---------------------------------------------------------------------------
-- D) Alanndarian Nightsong (HavenCore #716): she lies wounded in Cata and
--    nelt, but the template-addon layer was never imported for her, so she
--    stood. Stand state only; nelt's 51329 stun aura is not needed for it.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_addon` WHERE `entry` = 3733055;
INSERT INTO `creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(3733055, 0, 0, 7, 1, 0, 0, NULL);

-- ---------------------------------------------------------------------------
-- E) Earth Elemental Remains (HavenCore #722 / #491): corpses with random
--    movement. Stand still. All 8 map-750 spawns.
-- ---------------------------------------------------------------------------
UPDATE `creature` SET `MovementType` = 0, `wander_distance` = 0 WHERE `guid` BETWEEN 15861658 AND 15861665 AND `id` = 3734299;

-- ---------------------------------------------------------------------------
-- F) Shadowclaw (HavenCore #720): patrol the shore instead of wandering.
--    HavenCore's path, start moved onto point 1. Our single spawn sits on
--    the same line (9.74 between points 2 and 3), so the heights fit.
-- ---------------------------------------------------------------------------
UPDATE `creature` SET `position_x` = 6723.84, `position_y` = 373.12, `position_z` = 5.73, `MovementType` = 2, `wander_distance` = 0
WHERE `guid` = 15860415 AND `id` = 3702175;

DELETE FROM `creature_addon` WHERE `guid` = 15860415;
INSERT INTO `creature_addon` (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(15860415, 15860415, 0, 0, 1, 0, 0, NULL);

DELETE FROM `waypoint_data` WHERE `id` = 15860415;
INSERT INTO `waypoint_data` (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`) VALUES
(15860415, 1, 6723.84, 373.12, 5.73, NULL, 0, 0, 0, 100, 0),
(15860415, 2, 6698.46, 368.29, 7.06, NULL, 0, 0, 0, 100, 0),
(15860415, 3, 6656.98, 354.79, 9.50, NULL, 0, 0, 0, 100, 0),
(15860415, 4, 6625.24, 335.90, 13.04, NULL, 0, 0, 0, 100, 0),
(15860415, 5, 6577.52, 306.50, 13.29, NULL, 0, 0, 0, 100, 0),
(15860415, 6, 6625.24, 335.90, 13.04, NULL, 0, 0, 0, 100, 0),
(15860415, 7, 6656.98, 354.79, 9.50, NULL, 0, 0, 0, 100, 0),
(15860415, 8, 6698.46, 368.29, 7.06, NULL, 0, 0, 0, 100, 0),
(15860415, 9, 6723.84, 373.12, 5.73, NULL, 0, 0, 0, 100, 0);
