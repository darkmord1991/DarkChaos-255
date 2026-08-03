-- ---------------------------------------------------------------------------
-- 227  Map 750/751 -- the 7 vehicle passengers 226_ had to leave out
-- ---------------------------------------------------------------------------
-- 226_ could only insert 3 of the 10 vehicle_template_accessory rows because
-- the other 7 name a passenger creature that was never imported, and a row
-- pointing at a non-existent creature just logs an error and seats nobody.
-- This imports those 7 and adds the accessory rows.
--
-- ALL SEVEN PARENT VEHICLES ARE SPAWNED, so all seven mounts currently stand
-- there riderless:
--   3639833 Twilight Buzzard            47 spawns  -> Twilight Knight Rider
--   3640190 Climbing Tree               15         -> Treetop
--   3640573 Twilight Stormwaker          9         -> Twilight Stormwaker
--   3734282 Twilight Rider               7         -> Twilight Rider (Humanoid)
--   3639839 Twilight Stormwaker          2         -> Twilight Stormwaker
--   3650089 Julak-Doom                   2         -> Julak-Doom
--   3639789 Kristoff's Chain Vehicle     1         -> Kristoff Manheim
-- (I previously called Twilight Rider "the visible one" -- Twilight Buzzard at
-- 47 spawns is the bigger one.)
--
-- OFFSET FOLLOWS THE PARENT, not a fixed rule: six use +3,600,000, but the
-- Twilight Rider chain is a +3,700,000 border-zone clone, so 34293 -> 3734293.
-- Getting this wrong would create an orphan that looks fine in the table.
--
-- SCHEMA DRIFT IS LARGE and the import is column-scoped because of it: our
-- creature_template has 55 columns, cata's 84. Only the 49 shared ones are
-- copied; every non-shared column of ours has a DEFAULT (verified via
-- information_schema), so the rest fill themselves in. Notably cata still has
-- modelid1..4 and `scale`, which this fork moved into creature_template_model
-- -- hence the separate model block below.
--
-- gossip_menu_id IS DELIBERATELY ZEROED. Kristoff Manheim carries menu 11289,
-- which does not exist here; importing it verbatim would give him a gossip
-- flag opening an empty window -- the dead-option class already cleaned up in
-- 197_. He is a vehicle passenger, so the menu is not needed for the ride.
--
-- DEPENDENCIES THESE DRAG IN, all resolved rather than assumed:
--   * displays 28356/28357/31520/31966/28991/32815 already exist in the DBC
--     (the live file now reads 28,550 records, so 225_'s deploy landed).
--   * 36722 (Julak-Doom) did NOT. Resolved the same way as the 40 in 225_:
--     cata model 3363 = CREATURE\\MERCILESSONE\\MERCILESSONE.M2, which we
--     already have as model 502455, and its texture MercilessOneYellow.blp
--     was probed and found in patch-F.MPQ. Cata's scale of 10.0 is kept: both
--     CreatureModelData rows have ModelScale 1.0, so the geometry is the same
--     size in both games and 10.0 is faithful. (An existing display on that
--     model uses 0.5 -- that is a different, small creature, not evidence that
--     10.0 is wrong.)
--   * creature_model_info was missing for 32815 and 36722 -- without it the
--     spawn is refused even with a valid DBC row.
--   * 40250 "Treetop" is ITSELF a vehicle (VehicleId 734) with npcflag
--     SPELLCLICK, so it needs Vehicle 734, seat 7696, and click spell 97400 --
--     none of which existed. 97400 cleared the effect-id >= 165 guard.
--
-- THREE DBC ROWS ARE ADDED and the files recompiled: CreatureDisplayInfo
-- 28550 -> 28551, Vehicle 488 -> 489, VehicleSeat 857 -> 858. As always the
-- overlay rows below do not fix anything by themselves -- the binaries have to
-- reach the server's data/dbc.
-- ---------------------------------------------------------------------------

-- --- the 7 passenger creature templates ----------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (3639640, 3639835, 3639838, 3640250, 3640575, 3650091, 3734293);
INSERT INTO `creature_template`
 (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT m.dst, ct.`difficulty_entry_1`, ct.`difficulty_entry_2`, ct.`difficulty_entry_3`, ct.`KillCredit1`, ct.`KillCredit2`, ct.`name`, ct.`subname`, ct.`IconName`, 0, ct.`minlevel`, ct.`maxlevel`, ct.`faction`, ct.`npcflag`, ct.`speed_walk`, ct.`speed_run`, ct.`rank`, ct.`dmgschool`, ct.`DamageModifier`, ct.`BaseAttackTime`, ct.`RangeAttackTime`, ct.`BaseVariance`, ct.`RangeVariance`, ct.`unit_class`, ct.`unit_flags`, ct.`unit_flags2`, ct.`family`, ct.`type`, ct.`type_flags`, ct.`lootid`, ct.`pickpocketloot`, ct.`skinloot`, ct.`PetSpellDataId`, ct.`VehicleId`, ct.`mingold`, ct.`maxgold`, ct.`AIName`, ct.`MovementType`, ct.`HoverHeight`, ct.`HealthModifier`, ct.`ManaModifier`, ct.`ArmorModifier`, ct.`ExperienceModifier`, ct.`RacialLeader`, ct.`movementId`, ct.`RegenHealth`, ct.`flags_extra`, ct.`ScriptName`, ct.`VerifiedBuild`
FROM cata_world.`creature_template` ct
JOIN (SELECT 39640 src, 3639640 dst UNION ALL SELECT 39835 src, 3639835 dst UNION ALL SELECT 39838 src, 3639838 dst UNION ALL SELECT 40250 src, 3640250 dst UNION ALL SELECT 40575 src, 3640575 dst UNION ALL SELECT 50091 src, 3650091 dst UNION ALL SELECT 34293 src, 3734293 dst) m ON m.src = ct.`entry`;

-- --- their models ---------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (3639640, 3639835, 3639838, 3640250, 3640575, 3650091, 3734293);
INSERT INTO `creature_template_model`
 (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`) VALUES
(3734293, 0, 28356, 1, 1),
(3734293, 1, 28357, 1, 1),
(3639640, 0, 31520, 1, 1),
(3639835, 0, 31966, 1, 1),
(3639838, 0, 28356, 1, 1),
(3639838, 1, 28357, 1, 1),
(3640250, 0, 28991, 1, 1),
(3640250, 1, 32815, 1, 1),
(3640575, 0, 28356, 1, 1),
(3640575, 1, 28357, 1, 1),
(3650091, 0, 36722, 1, 1);

-- --- server-side model info for the 2 displays we lacked ------------------
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (32815, 36722);
INSERT INTO `creature_model_info`
 (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`)
SELECT `DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`
FROM cata_world.`creature_model_info` WHERE `DisplayID` IN (32815, 36722);

-- --- display 36722 (Julak-Doom) -------------------------------------------
DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` = 36722;
INSERT INTO `creaturedisplayinfo_dbc`
 (`ID`, `ModelID`, `SoundID`, `ExtendedDisplayInfoID`, `CreatureModelScale`, `CreatureModelAlpha`,
  `TextureVariation_1`, `TextureVariation_2`, `TextureVariation_3`, `PortraitTextureName`,
  `BloodLevel`, `BloodID`, `NPCSoundID`, `ParticleColorID`, `CreatureGeosetData`,
  `ObjectEffectPackageID`) VALUES
(36722, 502455, 0, 0, 10, 255, 'MercilessOneYellow', '', '', '', 1, 1, 0, 0, 0, 0);

-- --- Treetop is itself a vehicle ------------------------------------------
DELETE FROM `vehicle_dbc` WHERE `ID` = 734;
INSERT INTO `vehicle_dbc`
 (`ID`, `Flags`, `TurnSpeed`, `PitchSpeed`, `PitchMin`, `PitchMax`, `SeatID_1`, `SeatID_2`, `SeatID_3`, `SeatID_4`, `SeatID_5`, `SeatID_6`, `SeatID_7`, `SeatID_8`, `MouseLookOffsetPitch`, `CameraFadeDistScalarMin`, `CameraFadeDistScalarMax`, `CameraPitchOffset`, `FacingLimitRight`, `FacingLimitLeft`, `MsslTrgtTurnLingering`, `MsslTrgtPitchLingering`, `MsslTrgtMouseLingering`, `MsslTrgtEndOpacity`, `MsslTrgtArcSpeed`, `MsslTrgtArcRepeat`, `MsslTrgtArcWidth`, `MsslTrgtImpactRadius_1`, `MsslTrgtImpactRadius_2`, `MsslTrgtArcTexture`, `MsslTrgtImpactTexture`, `MsslTrgtImpactModel_1`, `MsslTrgtImpactModel_2`, `CameraYawOffset`, `UilocomotionType`, `MsslTrgtImpactTexRadius`, `VehicleUIIndicatorID`, `PowerDisplayID_1`, `PowerDisplayID_2`, `PowerDisplayID_3`) VALUES
(734, 260506171, 3.14159274, 3.14159274, 0, 0, 7696, 0, 0, 0, 0, 0, 0, 0, 0.785398185, 1, 1.5, -0.17453292, 0, 0, 1.5, 1.5, 1, 1, 0.5, 0.5, 1.60000002, 1, 1, 'Interface\\Vehicles\\Arrow.blp', '', 'Interface\\Vehicles\\Vehicle_Target_01.mdx', 'Interface\\Vehicles\\Vehicle_Target_02.mdx', -0.34906584, 0, 1, 0, 0, 0, 0);

DELETE FROM `vehicleseat_dbc` WHERE `ID` = 7696;
INSERT INTO `vehicleseat_dbc`
 (`ID`, `Flags`, `AttachmentID`, `AttachmentOffsetX`, `AttachmentOffsetY`, `AttachmentOffsetZ`, `EnterPreDelay`, `EnterSpeed`, `EnterGravity`, `EnterMinDuration`, `EnterMaxDuration`, `EnterMinArcHeight`, `EnterMaxArcHeight`, `EnterAnimStart`, `EnterAnimLoop`, `RideAnimStart`, `RideAnimLoop`, `RideUpperAnimStart`, `RideUpperAnimLoop`, `ExitPreDelay`, `ExitSpeed`, `ExitGravity`, `ExitMinDuration`, `ExitMaxDuration`, `ExitMinArcHeight`, `ExitMaxArcHeight`, `ExitAnimStart`, `ExitAnimLoop`, `ExitAnimEnd`, `PassengerYaw`, `PassengerPitch`, `PassengerRoll`, `PassengerAttachmentID`, `VehicleEnterAnim`, `VehicleExitAnim`, `VehicleRideAnimLoop`, `VehicleEnterAnimBone`, `VehicleExitAnimBone`, `VehicleRideAnimLoopBone`, `VehicleEnterAnimDelay`, `VehicleExitAnimDelay`, `VehicleAbilityDisplay`, `EnterUISoundID`, `ExitUISoundID`, `UiSkin`, `FlagsB`, `CameraEnteringDelay`, `CameraEnteringDuration`, `CameraExitingDelay`, `CameraExitingDuration`, `CameraOffsetX`, `CameraOffsetY`, `CameraOffsetZ`, `CameraPosChaseRate`, `CameraFacingChaseRate`, `CameraEnteringZoom`, `CameraSeatZoomMin`, `CameraSeatZoomMax`) VALUES
(7696, 1611696143, 2, 0, 0, -10, 0, 7, 19.2900009, 0, 0, 0, 0, 37, 38, 37, 120, 112, 111, 0, 7, 19.2900009, 0, 0, 0.0500000007, 0.100000001, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 17465, 0, 0, 33631744, 0, 0, 0, 0, 0, 0, 3, 0, 0, 14, 0, 0);

-- --- the spell Treetop's spellclick needs ---------------------------------
DELETE FROM `spell_dbc` WHERE `ID` IN (97400);
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`, `AttributesEx4`, `AttributesEx5`, `AttributesEx6`, `AttributesEx7`, `CastingTimeIndex`, `DurationIndex`, `PowerType`, `RangeIndex`, `Speed`, `SpellVisualID_1`, `SpellVisualID_2`, `SpellIconID`, `ActiveIconID`, `SchoolMask`, `ProcChance`, `EquippedItemClass`, `Name_Lang_enUS`, `Description_Lang_enUS`, `Effect_1`, `EffectAura_1`, `EffectAuraPeriod_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValue_1`, `EffectMiscValueB_1`, `EffectRadiusIndex_1`, `EffectTriggerSpell_1`, `ImplicitTargetA_1`, `ImplicitTargetB_1`, `Effect_2`, `EffectAura_2`, `EffectAuraPeriod_2`, `EffectBasePoints_2`, `EffectDieSides_2`, `EffectMiscValue_2`, `EffectMiscValueB_2`, `EffectRadiusIndex_2`, `EffectTriggerSpell_2`, `ImplicitTargetA_2`, `ImplicitTargetB_2`, `Effect_3`, `EffectAura_3`, `EffectAuraPeriod_3`, `EffectBasePoints_3`, `EffectDieSides_3`, `EffectMiscValue_3`, `EffectMiscValueB_3`, `EffectRadiusIndex_3`, `EffectTriggerSpell_3`, `ImplicitTargetA_3`, `ImplicitTargetB_3`) VALUES
(97400, 256, 0, 0, 268435456, 1, 0, 0, 0, 1, 0, 0, 1, 0.0, 0, 0, 1, 0, 1, 101, -1, 'Treetop Spell Bar Update', '', 3, 0, 0, -1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 3640250;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(3640250, 97400, 1, 0);

-- --- and finally the 7 accessory rows 226_ had to leave out ---------------
DELETE FROM `vehicle_template_accessory` WHERE `entry` IN (3639789, 3639833, 3639839, 3640190, 3640573, 3650089, 3734282);
INSERT INTO `vehicle_template_accessory`
 (`entry`, `accessory_entry`, `seat_id`, `minion`, `description`, `summontype`, `summontimer`) VALUES
(3639789, 3639640, 0, 1, 'Kristoff\'s Chain Vehicle - Kristoff Manheim', 8, 0),
(3639833, 3639835, 0, 1, 'Twilight Buzzard - Twilight Knight Rider', 8, 0),
(3639839, 3639838, 0, 1, 'Twilight Stormwaker - Twilight Stormwaker', 8, 0),
(3640190, 3640250, 4, 1, 'Climbing Tree - Treetop', 8, 0),
(3640573, 3640575, 1, 1, 'Twilight Stormwaker - Twilight Stormwaker', 8, 0),
(3650089, 3650091, 0, 1, 'Julak-Doom - Julak-Doom', 8, 0),
(3734282, 3734293, 0, 1, 'Twilight Rider - Twilight Rider (Humanoid)', 8, 0);

-- Verify -- expect 7, 11, 7 and no dangling accessory:
--   SELECT COUNT(*) FROM `creature_template` WHERE entry IN (3639640,3639835,3639838,3640250,3640575,3650091,3734293);
--   SELECT COUNT(*) FROM `creature_template_model` WHERE CreatureID IN (3639640,3639835,3639838,3640250,3640575,3650091,3734293);
--   SELECT COUNT(*) FROM `vehicle_template_accessory` a
--     WHERE a.entry BETWEEN 3600000 AND 3999999
--       AND NOT EXISTS (SELECT 1 FROM `creature_template` c WHERE c.entry = a.accessory_entry);  -- must be 0
