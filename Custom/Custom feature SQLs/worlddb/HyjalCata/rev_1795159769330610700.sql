-- ===========================================================================
-- Map 861 -- Molten Front: working stage unlocks.
--
-- !! Needs the worldserver build in which QuestPhaseLayer reads status bit 128
-- !! ("turned in at least once") and zone_molten_front's Forlorn Spire escort
-- !! uses the 12-point route. Deploy it FIRST, then apply this and restart.
-- An older build drops the unknown bit 128: "after Into the Fire" is then
-- skipped and "after The Forlorn Spire" shrinks to "complete", so those two
-- areas stay hidden for players who already turned the dailies in.
--
-- Cata's Molten Front grows with the player: each unlock quest opens an area
-- (nelt_world phase_definitions zone 5733). Here everything stood in phase 1
-- at once, the two event quests were disabled, and the "Stage 2" switch had
-- no trigger. The unlocks map to DC's own quests where DC replaced Cata's:
--   751332 Druids of the Talon (Cata 29181), 751331 Into the Depths (29203).
--
--   bit   Cata phase                          shown while
--   2     Druids of the Talon opened          751332 in the log or done
--   4     during Into the Fire (29206)        29206 in the log
--   8     after Into the Fire                 29206 turned in once
--   16    Stage 2 (forward camp, tree)        751332 or 29214 turned in
--   32    Shadow Wardens opened               29214 turned in
--   64    during The Forlorn Spire (29205)    29205 in the log
--   128   after The Forlorn Spire             29205 complete or turned in once
--   512   after Calling the Ancients          29283 turned in
--   16384 Into the Depths (Leyara)            751331 in the log
-- 29205 / 29206 are DAILIES in every Cata source, and a repeatable quest
-- reports NONE again after its turn-in -- hence status 128 for "after".
-- Deviations from Cata, so no turn-in NPC is ever out of sight:
--   * bit 2 already from 751332 in the log (it has no objective, so it is
--     done on accept): Skylord Omnuron, its turn-in, stands in that phase.
--   * Marin Bladewing, turn-in of 29205, also shows "during" (64): status
--     COMPLETE has no hook, and the camera ride ends without an area change.
--   * The Furnace Door only "during" (4): it would wall off the Furnace.
--   * The Forlorn Spire tower GO (3808532) stays in phase 1 (display picked by
--     hand earlier, and the escort climbs to its top).
--   * No intro phase (Cata 32768): its content was never imported.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A) Rules. Status masks: 2 complete, 8 incomplete, 64 rewarded, 128 turned
--    in at least once (also repeatable/daily quests). 10 = in the log.
-- ---------------------------------------------------------------------------
DELETE FROM `dc_quest_phase` WHERE `map` = 861;
INSERT INTO `dc_quest_phase` (`map`,`phase_mask`,`quest`,`quest_status_mask`,`comment`) VALUES
(861, 2, 751332, 74, 'Molten Front: Druids of the Talon opened (751332 in the log or done)'),
(861, 4, 29206, 10, 'Molten Front: during Into the Fire'),
(861, 8, 29206, 128, 'Molten Front: after Into the Fire (daily, turned in at least once)'),
(861, 16, 751332, 64, 'Molten Front: Stage 2 (Druids of the Talon unlocked)'),
(861, 16, 29214, 64, 'Molten Front: Stage 2 (Shadow Wardens unlocked)'),
(861, 32, 29214, 64, 'Molten Front: Shadow Wardens opened'),
(861, 64, 29205, 10, 'Molten Front: during The Forlorn Spire'),
(861, 128, 29205, 130, 'Molten Front: after The Forlorn Spire (daily: complete, or turned in at least once)'),
(861, 512, 29283, 64, 'Molten Front: after Calling the Ancients'),
(861, 16384, 751331, 10, 'Molten Front: during Into the Depths');

-- ---------------------------------------------------------------------------
-- B) Spawns into their Cata stage (nelt phase, ORed over stacked rows; spawns
--    nelt also shows in phase 1 stay in phase 1). Ranges pinned 2026-11-20 --
--    each is a run of consecutive guids that all share the mask.
-- ---------------------------------------------------------------------------
-- after Into the Fire: the Furnace, the Druid of the Talon dailies (592)
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` IN (15300004, 15300011);
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300034 AND 15300556;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300578 AND 15300583;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300589 AND 15300590;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300782 AND 15300802;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300905 AND 15300907;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300910 AND 15300920;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300945 AND 15300962;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300966 AND 15300967;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300973 AND 15300974;
UPDATE `creature` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15301117 AND 15301118;
-- Thisalee Crow (during or after Into the Fire), Skylord Omnuron (opened onward)
UPDATE `creature` SET `phaseMask` = 12 WHERE `map` = 861 AND `id` = 3652444 AND `guid` = 15310001;
UPDATE `creature` SET `phaseMask` = 14 WHERE `map` = 861 AND `id` = 3652490 AND `guid` = 15350007;
-- Stage 2: forward camp (14)
UPDATE `creature` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300006 AND 15300010;
UPDATE `creature` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` IN (15300591);
UPDATE `creature` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300657 AND 15300658;
UPDATE `creature` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300877 AND 15300878;
UPDATE `creature` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300908 AND 15300909;
UPDATE `creature` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15301096 AND 15301097;
-- after The Forlorn Spire: Shadow Warden area and dailies (107)
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300012 AND 15300033;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300586 AND 15300587;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300592 AND 15300596;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300627 AND 15300629;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300640 AND 15300656;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300672 AND 15300691;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300693 AND 15300700;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` IN (15300733, 15301101);
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300803 AND 15300814;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15300975 AND 15300988;
UPDATE `creature` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15301098 AND 15301099;
-- Marin Bladewing, turn-in of The Forlorn Spire: also during it
UPDATE `creature` SET `phaseMask` = 192 WHERE `map` = 861 AND `id` = 3652494 AND `guid` = 15300592;
-- Shalis Darkhunter (Wardens opened or after the Spire)
UPDATE `creature` SET `phaseMask` = 160 WHERE `map` = 861 AND `id` = 3652495 AND `guid` = 15350008;
-- the five Lieutenants (after Calling the Ancients)
UPDATE `creature` SET `phaseMask` = 512 WHERE `map` = 861 AND `id` BETWEEN 3600000 AND 3699999 AND `guid` BETWEEN 15350002 AND 15350006;
-- Leyara and her finale controller (during Into the Depths)
UPDATE `creature` SET `phaseMask` = 16384 WHERE `map` = 861 AND `id` IN (3653366, 3675193) AND `guid` IN (15350001, 15350009);

-- Gameobjects: Rappelling Rope (8); Sentinel Tree, tree doodad, camp crates and
-- racks, Pre Moonwell (16); Shadow Warden daily objects (128). Not the tower.
UPDATE `gameobject` SET `phaseMask` = 8 WHERE `map` = 861 AND `id` IN (3808570) AND `guid` IN (15200001);
UPDATE `gameobject` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` IN (3808536, 3808584, 3809102, 3809103, 3809104, 3809105, 3809278) AND `guid` IN (15200087, 15200146);
UPDATE `gameobject` SET `phaseMask` = 16 WHERE `map` = 861 AND `id` IN (3808536, 3808584, 3809102, 3809103, 3809104, 3809105, 3809278) AND `guid` BETWEEN 15200233 AND 15200241;
UPDATE `gameobject` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` IN (3808474, 3808537, 3808588, 3808590, 3808592, 3808593) AND `guid` IN (15200085, 15200088);
UPDATE `gameobject` SET `phaseMask` = 128 WHERE `map` = 861 AND `id` IN (3808474, 3808537, 3808588, 3808590, 3808592, 3808593) AND `guid` BETWEEN 15200147 AND 15200165;

-- ---------------------------------------------------------------------------
-- C) The two events. Controllers, Captain Saynna at the start, the camera's
--    channel bunny on the spire, and the Furnace Door -- all at nelt's spots
--    and in nelt's phases. Guid block 9027100+, checked empty 2026-11-20.
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 9027100 AND 9027104 AND `id` IN (3675181, 3675182, 3675186, 3644403, 3652854);
INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9027100, 3675181, 861, 0, 0, 1, 4, 0, 1063.28, 417.805, 41.074, 0.7085, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Molten Front - Into the Fire start controller (29206)'),
(9027101, 3675182, 861, 0, 0, 1, 4, 0, 1167.23, 532.116, 54.448, 4.3478, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Molten Front - Into the Fire end controller (29206)'),
(9027102, 3675186, 861, 0, 0, 1, 96, 0, 1149.22, 283.585, 16.76, 5.5979, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Molten Front - The Forlorn Spire controller (29205)'),
(9027103, 3644403, 861, 0, 0, 1, 64, 0, 1174.09, 134.778, 101.907, 0.6109, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Molten Front - Forlorn Spire camera channel target (29205)'),
(9027104, 3652854, 861, 0, 0, 1, 32, 0, 1142.4, 282.155, 16.759, 0.1983, 300, 0, 0, 1, 0, 0, 0, 0, '', 0, 'Molten Front - Captain Saynna Stormrunner, Forlorn Spire start (29205)');

DELETE FROM `gameobject` WHERE `guid` = 9027100 AND `id` = 3808427;
INSERT INTO `gameobject`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,
     `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
VALUES
(9027100, 3808427, 861, 0, 0, 1, 4, 1165.84, 533.719, 53.5342, 3.10665, 0, 0, 0, 1, 120, 255, 1, '', 0, 'Molten Front - Furnace Door (29206)');

-- Escort routes. Into the Fire: Voramus walks Nordrala's route (nelt has it
-- only for her; the script is shared). The Forlorn Spire: one 12-point route
-- for Turak, Taldros and Deldren -- nelt's 4 points for Taldros, then known
-- ground: a creeper spawn, the igniter ledge (6), a Cinderling spawn, the
-- sentinel spot, the spire plateau (10), the post-assault druids on top (12).
DELETE FROM `script_waypoint` WHERE `entry` = 3653217;
INSERT INTO `script_waypoint` (`entry`,`pointid`,`location_x`,`location_y`,`location_z`,`waittime`,`point_comment`)
SELECT 3653217, `pointid`, `location_x`, `location_y`, `location_z`, `waittime`, 'Windcaller Voramus - Into the Fire (route of Nordrala)'
FROM `script_waypoint` WHERE `entry` = 3653355;

DELETE FROM `script_waypoint` WHERE `entry` IN (3652953, 3652964, 3652965);
INSERT INTO `script_waypoint` (`entry`,`pointid`,`location_x`,`location_y`,`location_z`,`waittime`,`point_comment`) VALUES
(3652953, 1, 1158.9, 273.65, 17.93, 0, 'Forlorn Spire'), (3652953, 2, 1170.97, 252.92, 30.92, 0, 'Forlorn Spire'),
(3652953, 3, 1184.78, 240.22, 41.9, 0, 'Forlorn Spire'), (3652953, 4, 1192.92, 226.85, 50.97, 0, 'Forlorn Spire'),
(3652953, 5, 1192.9, 221.4, 52.21, 0, 'Forlorn Spire'), (3652953, 6, 1200, 211, 54.6, 0, 'Forlorn Spire - igniters'),
(3652953, 7, 1213.9, 189, 54.77, 0, 'Forlorn Spire'), (3652953, 8, 1213.32, 172, 59.8, 0, 'Forlorn Spire'),
(3652953, 9, 1205, 158, 60.2, 0, 'Forlorn Spire'), (3652953, 10, 1193.2, 152, 60.02, 0, 'Forlorn Spire - second line'),
(3652953, 11, 1180.9, 137.2, 63.56, 0, 'Forlorn Spire'), (3652953, 12, 1188.8, 131.7, 63.56, 0, 'Forlorn Spire - channel'),
(3652964, 1, 1158.9, 273.65, 17.93, 0, 'Forlorn Spire'), (3652964, 2, 1170.97, 252.92, 30.92, 0, 'Forlorn Spire'),
(3652964, 3, 1184.78, 240.22, 41.9, 0, 'Forlorn Spire'), (3652964, 4, 1192.92, 226.85, 50.97, 0, 'Forlorn Spire'),
(3652964, 5, 1192.9, 221.4, 52.21, 0, 'Forlorn Spire'), (3652964, 6, 1200, 211, 54.6, 0, 'Forlorn Spire - igniters'),
(3652964, 7, 1213.9, 189, 54.77, 0, 'Forlorn Spire'), (3652964, 8, 1213.32, 172, 59.8, 0, 'Forlorn Spire'),
(3652964, 9, 1205, 158, 60.2, 0, 'Forlorn Spire'), (3652964, 10, 1193.2, 152, 60.02, 0, 'Forlorn Spire - second line'),
(3652964, 11, 1180.9, 137.2, 63.56, 0, 'Forlorn Spire'), (3652964, 12, 1188.8, 131.7, 63.56, 0, 'Forlorn Spire - channel'),
(3652965, 1, 1158.9, 273.65, 17.93, 0, 'Forlorn Spire'), (3652965, 2, 1170.97, 252.92, 30.92, 0, 'Forlorn Spire'),
(3652965, 3, 1184.78, 240.22, 41.9, 0, 'Forlorn Spire'), (3652965, 4, 1192.92, 226.85, 50.97, 0, 'Forlorn Spire'),
(3652965, 5, 1192.9, 221.4, 52.21, 0, 'Forlorn Spire'), (3652965, 6, 1200, 211, 54.6, 0, 'Forlorn Spire - igniters'),
(3652965, 7, 1213.9, 189, 54.77, 0, 'Forlorn Spire'), (3652965, 8, 1213.32, 172, 59.8, 0, 'Forlorn Spire'),
(3652965, 9, 1205, 158, 60.2, 0, 'Forlorn Spire'), (3652965, 10, 1193.2, 152, 60.02, 0, 'Forlorn Spire - second line'),
(3652965, 11, 1180.9, 137.2, 63.56, 0, 'Forlorn Spire'), (3652965, 12, 1188.8, 131.7, 63.56, 0, 'Forlorn Spire - channel');

-- ---------------------------------------------------------------------------
-- D) Quests: the two events are live again, and Flight of the Storm Crows
--    follows Druids of the Talon as in Cata (its turn-in only shows from then).
-- ---------------------------------------------------------------------------
DELETE FROM `disables` WHERE `sourceType` = 1 AND `entry` IN (29205, 29206);
UPDATE `quest_template_addon` SET `PrevQuestID` = 751332 WHERE `ID` = 29182 AND `PrevQuestID` = 0;
