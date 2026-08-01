-- ---------------------------------------------------------------------------
-- 196  Darkshore -- Vengeful Protector vehicle data (Vehicle 326 / Seat 2883)
-- ---------------------------------------------------------------------------
-- Unblocks the DATA half of npc_vengeful_protector_ancient_vehicle (quest 13514
-- "The Ancients' Ire"). Read the CAVEAT before wiring the C++.
--
-- WHERE THE WIRING ACTUALLY LIVES -- `nelt_world`, not `cata_world`. cata_world
-- reports VehicleId = 0 and npcflag = 0 for every NPC involved; nelt_world (the
-- Neltharion source DB the scripts were written against) has the real values:
--     32851 Vengeful Protector  VehicleId 326, npcflag SPELLCLICK, click 46598
--     43742 Vengeful Protector  VehicleId 0,   npcflag SPELLCLICK, click 56685
-- So 32851 is the real vehicle. It has ZERO spawns anywhere -- it is summoned.
--
-- THE BLOCKER THAT IS NOW SOLVED -- Vehicle.dbc 326 does not exist in 3.3.5
-- (live server has 449 rows and no 326; our Custom/DBCs copy reaches id 1651
-- and still lacks it). Both rows come from K:\UntouchedClients\Cata,
-- Data\enUS\locale-enUS.MPQ -- note the Vehicle DBCs are in the LOCALE archive,
-- and the wow-update-enUS-*.MPQ copies are PTCH deltas, not full tables.
--
--   * Vehicle.dbc      -- Cata layout is IDENTICAL to 3.3.5 (40 fields,
--                         recordSize 160), so row 326 copies verbatim.
--   * VehicleSeat.dbc  -- NOT identical: Cata has 66 fields / 264 bytes vs our
--                         58 / 232. The mapping used below was derived
--                         EMPIRICALLY, not guessed: 782 seat ids exist in both
--                         files, and comparing every column pair across all 782
--                         shows our columns 0-56 map 1:1 onto cata 0-56
--                         (98-100% agreement each -- the sub-100% cases are
--                         Blizzard retuning individual float values between
--                         expansions, not a structural shift), and our column
--                         57 (CameraSeatZoomMax) maps to cata column 63. Cata
--                         inserted six AnimKit fields at 57-62.
--
-- Rows go into the vehicle_dbc / vehicleseat_dbc SQL overlays, which mirror the
-- DBC layouts exactly (40 and 58 columns) -- the same mechanism used for the
-- earlier VehicleId freeze-fixes. No client DBC rebuild is needed for the
-- server to resolve them.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Vehicle 326 -- verbatim from the Cata client (identical layout)
-- ---------------------------------------------------------------------------
DELETE FROM `vehicle_dbc` WHERE `ID` = 326;

INSERT INTO `vehicle_dbc`
    (`ID`,`Flags`,`TurnSpeed`,`PitchSpeed`,`PitchMin`,`PitchMax`,`SeatID_1`,`SeatID_2`,`SeatID_3`,`SeatID_4`,`SeatID_5`,`SeatID_6`,`SeatID_7`,`SeatID_8`,`MouseLookOffsetPitch`,`CameraFadeDistScalarMin`,`CameraFadeDistScalarMax`,`CameraPitchOffset`,`FacingLimitRight`,`FacingLimitLeft`,`MsslTrgtTurnLingering`,`MsslTrgtPitchLingering`,`MsslTrgtMouseLingering`,`MsslTrgtEndOpacity`,`MsslTrgtArcSpeed`,`MsslTrgtArcRepeat`,`MsslTrgtArcWidth`,`MsslTrgtImpactRadius_1`,`MsslTrgtImpactRadius_2`,`MsslTrgtArcTexture`,`MsslTrgtImpactTexture`,`MsslTrgtImpactModel_1`,`MsslTrgtImpactModel_2`,`CameraYawOffset`,`UilocomotionType`,`MsslTrgtImpactTexRadius`,`VehicleUIIndicatorID`,`PowerDisplayID_1`,`PowerDisplayID_2`,`PowerDisplayID_3`)
VALUES
  (326, 1074307178, 1.571000, 1.047000, 0.000000, 0.000000, 2883, 0, 0, 0, 0, 0, 0, 0, 0.000000, 1.750000, 2.000000, 0.436332, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0, 0.000000, 0.000000, 0.000000, 0, 0, 0, 0, 0.000000, 0, 0.000000, 0, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- B) VehicleSeat 2883 -- the single seat Vehicle 326 references
-- ---------------------------------------------------------------------------
DELETE FROM `vehicleseat_dbc` WHERE `ID` = 2883;

INSERT INTO `vehicleseat_dbc`
    (`ID`,`Flags`,`AttachmentID`,`AttachmentOffsetX`,`AttachmentOffsetY`,`AttachmentOffsetZ`,`EnterPreDelay`,`EnterSpeed`,`EnterGravity`,`EnterMinDuration`,`EnterMaxDuration`,`EnterMinArcHeight`,`EnterMaxArcHeight`,`EnterAnimStart`,`EnterAnimLoop`,`RideAnimStart`,`RideAnimLoop`,`RideUpperAnimStart`,`RideUpperAnimLoop`,`ExitPreDelay`,`ExitSpeed`,`ExitGravity`,`ExitMinDuration`,`ExitMaxDuration`,`ExitMinArcHeight`,`ExitMaxArcHeight`,`ExitAnimStart`,`ExitAnimLoop`,`ExitAnimEnd`,
     `PassengerYaw`,`PassengerPitch`,`PassengerRoll`,`PassengerAttachmentID`,`VehicleEnterAnim`,`VehicleExitAnim`,`VehicleRideAnimLoop`,`VehicleEnterAnimBone`,`VehicleExitAnimBone`,`VehicleRideAnimLoopBone`,`VehicleEnterAnimDelay`,`VehicleExitAnimDelay`,`VehicleAbilityDisplay`,`EnterUISoundID`,`ExitUISoundID`,`UiSkin`,`FlagsB`,`CameraEnteringDelay`,`CameraEnteringDuration`,`CameraExitingDelay`,`CameraExitingDuration`,`CameraOffsetX`,`CameraOffsetY`,`CameraOffsetZ`,`CameraPosChaseRate`,`CameraFacingChaseRate`,`CameraEnteringZoom`,`CameraSeatZoomMin`,`CameraSeatZoomMax`)
VALUES
  (2883, 1779476655, 10, 0.200000, 0.000000, 0.600000, 0.000000, 20.000000, 19.290001, 0.000000, 0.000000, 1.000000, 4.000000, 37, 38, 96, 97, 96, 97, 0.000000, 20.000000, 19.290001, 0.000000, 0.000000, 1.000000, 4.000000, 37, 38, 39,
   0.000000, 0.000000, 0.000000, -1, 216, -1, -1, -1, -1, -1, 3.000000, 0.000000, 1, 13837, 13835, 0, 27648, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 25.000000, 15.000000, 0.000000);

-- ---------------------------------------------------------------------------
-- C) The vehicle creature itself + its spellclick
-- ---------------------------------------------------------------------------
-- 3732851 is imported with VehicleId forced to 326 and npcflag SPELLCLICK,
-- because cata_world -- the table the template is copied FROM -- has both as 0.
-- Spell 46598 "Ride Vehicle Hardcoded" already exists in the stock 3.3.5
-- Spell.dbc, so no overlay row is minted for it.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 3732851;

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
     `rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,
     `unit_flags2`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,
     `DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, 0, 0, 0, 0,
       s.`name`, s.`subname`, s.`IconName`, s.`gossip_menu_id`, s.`minlevel`, s.`maxlevel`, s.`faction`,
       16777216, s.`speed_walk`, s.`speed_run`, s.`rank`, s.`dmgschool`,
       s.`BaseAttackTime`, s.`RangeAttackTime`, s.`BaseVariance`, s.`RangeVariance`, s.`unit_class`,
       COALESCE(s.`unit_flags`, 0), s.`unit_flags2`, s.`family`, s.`type`, s.`type_flags`,
       0, 0, 0, s.`PetSpellDataId`, 326, s.`mingold`, s.`maxgold`, '', s.`MovementType`,
       s.`HoverHeight`, s.`HealthModifier`, s.`ManaModifier`, s.`ArmorModifier`, s.`DamageModifier`,
       s.`ExperienceModifier`, s.`RacialLeader`, s.`movementId`, s.`RegenHealth`, s.`flags_extra`, '', s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` = 32851;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 3732851;

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT s.`entry` + 3700000, 0, s.`modelid1`, 1, 1, s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` = 32851 AND s.`modelid1` > 0;

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 3732851;

INSERT INTO `npc_spellclick_spells` (`npc_entry`,`spell_id`,`cast_flags`,`user_type`) VALUES
(3732851, 46598, 1, 0);

-- ---------------------------------------------------------------------------
-- CAVEAT -- why the C++ script is NOT wired by this file
-- ---------------------------------------------------------------------------
-- Two links in the chain are still open, and wiring the ScriptName before they
-- are closed would produce a script that never fires:
--
--  1. NOTHING SUMMONS IT YET. 32851 is summoned by spell 64602 (found by
--     scanning the Cata SpellEffect.dbc for Effect 28 / SUMMON with
--     EffectMiscValue 32851). 64602 is absent from our Spell.dbc and spell_dbc,
--     and nothing in cata_world casts it -- no item, no gameobject, and quest
--     13514 has SourceSpellID 0. The caster is probably a SmartAI or another
--     script in the Neltharion tree and has not been identified.
--
--  2. THE SCRIPT'S AREA CHECK CANNOT MATCH. It compares me->GetAreaId()
--     against AREA_SHATTERSPEAR_VALE = 4664. Map 750 uses this project's own
--     AreaTable ids (Darkshore = 4929), so the comparison would always fail and
--     the AI would decide the player had left the area and despawn the vehicle
--     after 10 seconds. Any port must remap that constant.
--
-- Everything in sections A-C is still worth applying now: it is the part that
-- was genuinely blocked, it is verified, and it is inert until something
-- summons the creature.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT ID, Flags, SeatID_1 FROM vehicle_dbc WHERE ID = 326;        -- seat 2883
--   SELECT ID, Flags, AttachmentID FROM vehicleseat_dbc WHERE ID = 2883;
--   SELECT entry, name, VehicleId, npcflag FROM creature_template WHERE entry = 3732851;
--   -- and the boot log must NOT contain
--   --   "Creature (Entry: 3732851) has vehicle id 326 that does not exist"
-- ---------------------------------------------------------------------------
