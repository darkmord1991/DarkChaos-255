-- ---------------------------------------------------------------------------
-- 137  Hyjal round-18 -- 4 more vehicles (CLIENT FREEZE RISK)
-- ---------------------------------------------------------------------------
--     Creature (Entry: 3649413) has a non-existing VehicleId (1394). This
--     *WILL* cause the client to freeze!      (+ 3652597/1610, 3653163/1640,
--                                                3653354/1651)
--
-- SELF-INFLICTED by rounds 14/15: 118_ and 126_ imported creature templates
-- straight from nelt_world *including their VehicleId*, without checking that
-- the matching Vehicle.dbc row existed.  Round 14's 117_ only downported the
-- vehicles for creatures that ALREADY existed with VehicleId zeroed (701, 825,
-- 1606), so anything the new imports brought in was never covered -- note 1606
-- (Druid Combat Circle, which 117_ did do) vs 1610 (Wings of Aviana, which it
-- did not): adjacent ids, different creatures, easy to conflate.
--
--   1394  Cenarius Event Camera    (3649413, imported by 126_)
--   1610  Wings of Aviana          (3652597, imported by 118_)
--   1640  Rope                     (3653163, imported by 126_)
--   1651  Escape Winds             (3653354, imported by 126_)
--
-- Same generator and the same self-validating field decode as 117_ (it
-- re-decodes seat 7683 and asserts it matches 82_'s hand-verified row before
-- emitting anything).  Seats 9280, 9854, 9935, 9954, 10135.
--
-- The matching CLIENT rows are appended to Custom/CSV DBC/Vehicle.csv +
-- VehicleSeat.csv and need a DBC recompile.
-- ---------------------------------------------------------------------------

DELETE FROM `vehicleseat_dbc` WHERE `ID` IN (9280,9854,9935,9954,10135);

INSERT INTO `vehicleseat_dbc` (`ID`, `Flags`, `AttachmentID`, `AttachmentOffsetX`, `AttachmentOffsetY`, `AttachmentOffsetZ`, `EnterPreDelay`, `EnterSpeed`, `EnterGravity`, `EnterMinDuration`, `EnterMaxDuration`, `EnterMinArcHeight`, `EnterMaxArcHeight`, `EnterAnimStart`, `EnterAnimLoop`, `RideAnimStart`, `RideAnimLoop`, `RideUpperAnimStart`, `RideUpperAnimLoop`, `ExitPreDelay`, `ExitSpeed`, `ExitGravity`, `ExitMinDuration`, `ExitMaxDuration`, `ExitMinArcHeight`, `ExitMaxArcHeight`, `ExitAnimStart`, `ExitAnimLoop`, `ExitAnimEnd`, `PassengerYaw`, `PassengerPitch`, `PassengerRoll`, `PassengerAttachmentID`, `VehicleEnterAnim`, `VehicleExitAnim`, `VehicleRideAnimLoop`, `VehicleEnterAnimBone`, `VehicleExitAnimBone`, `VehicleRideAnimLoopBone`, `VehicleEnterAnimDelay`, `VehicleExitAnimDelay`, `VehicleAbilityDisplay`, `EnterUISoundID`, `ExitUISoundID`, `UiSkin`, `FlagsB`, `CameraEnteringDelay`, `CameraEnteringDuration`, `CameraExitingDelay`, `CameraExitingDuration`, `CameraOffsetX`, `CameraOffsetY`, `CameraOffsetZ`, `CameraPosChaseRate`, `CameraFacingChaseRate`, `CameraEnteringZoom`, `CameraSeatZoomMin`, `CameraSeatZoomMax`) VALUES
(9280, 1108380174, 13, 0, 0, 0, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, -1, 102, 128, 123, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, -2113918976, 0, 0, 0, 0, 0, 0, 0, 0, 0, 50, 0, 0),
(9854, 1645283863, 9, 0, 0, 0, 0, 0.2, 0, 4.6, 4.6, 0, 0, 193, 193, -1, 102, 128, 123, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 2.2, 0, 0, 0, 0, 0),
(9935, 1073775631, 14, 0, 0, 0, 0, 15, 0, 0, 0, 1, 4, 37, 125, -1, 103, -1, 125, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0.349066, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, -2113929216, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(9954, 1073775657, 14, 0, 0, 0, 0, 15, 0, 0, 0, 1, 4, 37, 38, -1, -1, -1, -1, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0.349066, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, -2113929216, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(10135, 1073775657, 14, 0, 0, 0, 0, 15, 0, 0, 0, 1, 4, 37, 38, -1, -1, -1, -1, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0.349066, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, -2113929216, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

DELETE FROM `vehicle_dbc` WHERE `ID` IN (1394,1610,1640,1651);

INSERT INTO `vehicle_dbc` (`ID`, `Flags`, `TurnSpeed`, `PitchSpeed`, `PitchMin`, `PitchMax`, `SeatID_1`, `SeatID_2`, `SeatID_3`, `SeatID_4`, `SeatID_5`, `SeatID_6`, `SeatID_7`, `SeatID_8`, `MouseLookOffsetPitch`, `CameraFadeDistScalarMin`, `CameraFadeDistScalarMax`, `CameraPitchOffset`, `FacingLimitRight`, `FacingLimitLeft`, `MsslTrgtTurnLingering`, `MsslTrgtPitchLingering`, `MsslTrgtMouseLingering`, `MsslTrgtEndOpacity`, `MsslTrgtArcSpeed`, `MsslTrgtArcRepeat`, `MsslTrgtArcWidth`, `MsslTrgtImpactRadius_1`, `MsslTrgtImpactRadius_2`, `MsslTrgtArcTexture`, `MsslTrgtImpactTexture`, `MsslTrgtImpactModel_1`, `MsslTrgtImpactModel_2`, `CameraYawOffset`, `UilocomotionType`, `MsslTrgtImpactTexRadius`, `VehicleUIIndicatorID`, `PowerDisplayID_1`, `PowerDisplayID_2`, `PowerDisplayID_3`) VALUES
(1394, 1073877031, 3.142, 3.142, 0, 0, 9280, 0, 0, 0, 0, 0, 0, 0, 0.785398, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0),
(1610, 1073930248, 3.141593, 3.141593, 0, 0, 9854, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0),
(1640, 1610743808, 3.141593, 3.141593, 0, 0, 9935, 0, 0, 0, 0, 0, 0, 0, 0.785398, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0),
(1651, 1610743808, 3.141593, 3.141593, 0, 0, 9954, 10135, 0, 0, 0, 0, 0, 0, 0.785398, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0);

-- No creature_template.VehicleId changes here: unlike 117_, these four
-- creatures already carry the right VehicleId (their imports copied it from
-- nelt_world) -- it was only the Vehicle.dbc side that was missing.
