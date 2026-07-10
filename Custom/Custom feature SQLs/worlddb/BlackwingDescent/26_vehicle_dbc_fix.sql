-- ---------------------------------------------------------------------------
-- vehicle_dbc / vehicleseat_dbc  (SQL DBC mirror was stale -- rows exist in
-- Custom/CSV DBC/Vehicle.csv + VehicleSeat.csv but were never synced into the
-- world DB mirror tables, so Creature::CreateVehicleKit's GetVehicleInfo(id)
-- lookup fails and the boot log flags a non-existing VehicleId -- "WILL cause
-- the client to freeze" if a player mounts/enters it. Affects Magmaw (41570),
-- Maimgor (42768), Room Stalker (47196), all map 669.
-- ---------------------------------------------------------------------------
DELETE FROM `vehicle_dbc` WHERE `ID` IN (834,931,1548);

INSERT INTO `vehicle_dbc` (`ID`, `Flags`, `TurnSpeed`, `PitchSpeed`, `PitchMin`, `PitchMax`, `SeatID_1`, `SeatID_2`, `SeatID_3`, `SeatID_4`, `SeatID_5`, `SeatID_6`, `SeatID_7`, `SeatID_8`, `MouseLookOffsetPitch`, `CameraFadeDistScalarMin`, `CameraFadeDistScalarMax`, `CameraPitchOffset`, `FacingLimitRight`, `FacingLimitLeft`, `MsslTrgtTurnLingering`, `MsslTrgtPitchLingering`, `MsslTrgtMouseLingering`, `MsslTrgtEndOpacity`, `MsslTrgtArcSpeed`, `MsslTrgtArcRepeat`, `MsslTrgtArcWidth`, `MsslTrgtImpactRadius_1`, `MsslTrgtImpactRadius_2`, `MsslTrgtArcTexture`, `MsslTrgtImpactTexture`, `MsslTrgtImpactModel_1`, `MsslTrgtImpactModel_2`, `CameraYawOffset`, `UilocomotionType`, `MsslTrgtImpactTexRadius`, `VehicleUIIndicatorID`, `PowerDisplayID_1`, `PowerDisplayID_2`, `PowerDisplayID_3`) VALUES
(834, 1073872899, 3.14159, 3.14159, 0, 0, 7910, 7911, 7936, 8051, 9073, 9609, 0, 0, 0, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0),
(931, 1073877031, 3.14159, 3.14159, 0, 0, 8143, 0, 0, 0, 0, 0, 0, 0, 0.785398, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0),
(1548, 1073741827, 3.14159, 3.14159, 0, 0, 9677, 9678, 9679, 9680, 9681, 9682, 9683, 9684, 0.785398, 1, 1.5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0);

DELETE FROM `vehicleseat_dbc` WHERE `ID` IN (7910,7911,7936,8051,8143,9073,9609,9677,9678,9679,9680,9681,9682,9683,9684);

INSERT INTO `vehicleseat_dbc` (`ID`, `Flags`, `AttachmentID`, `AttachmentOffsetX`, `AttachmentOffsetY`, `AttachmentOffsetZ`, `EnterPreDelay`, `EnterSpeed`, `EnterGravity`, `EnterMinDuration`, `EnterMaxDuration`, `EnterMinArcHeight`, `EnterMaxArcHeight`, `EnterAnimStart`, `EnterAnimLoop`, `RideAnimStart`, `RideAnimLoop`, `RideUpperAnimStart`, `RideUpperAnimLoop`, `ExitPreDelay`, `ExitSpeed`, `ExitGravity`, `ExitMinDuration`, `ExitMaxDuration`, `ExitMinArcHeight`, `ExitMaxArcHeight`, `ExitAnimStart`, `ExitAnimLoop`, `ExitAnimEnd`, `PassengerYaw`, `PassengerPitch`, `PassengerRoll`, `PassengerAttachmentID`, `VehicleEnterAnim`, `VehicleExitAnim`, `VehicleRideAnimLoop`, `VehicleEnterAnimBone`, `VehicleExitAnimBone`, `VehicleRideAnimLoopBone`, `VehicleEnterAnimDelay`, `VehicleExitAnimDelay`, `VehicleAbilityDisplay`, `EnterUISoundID`, `ExitUISoundID`, `UiSkin`, `FlagsB`, `CameraEnteringDelay`, `CameraEnteringDuration`, `CameraExitingDelay`, `CameraExitingDuration`, `CameraOffsetX`, `CameraOffsetY`, `CameraOffsetZ`, `CameraPosChaseRate`, `CameraFacingChaseRate`, `CameraEnteringZoom`, `CameraSeatZoomMin`, `CameraSeatZoomMax`) VALUES
(7910, 1213259786, 6, 0, 0, 0, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, -1, 474, 128, 123, 0, 7, 19.29, 1.2, 1.2, 6, 6, 40, 40, 39, 0, 0, 0, 34, 112, 1, 111, -1, -1, -1, 1, 0, 1, 0, 0, 0, 48890177, 3, 1, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0),
(7911, 1213259786, 7, 0, 0, 0, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, -1, 474, 128, 123, 0, 7, 19.29, 1.2, 1.2, 6, 6, 40, 40, 39, 0, 0, 0, 34, 112, 1, 111, -1, -1, -1, 1, 0, 1, 0, 0, 0, 48890177, 3, 1, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0),
(7936, 138502167, 5, 0, 0, 0.1, 0, 8, 19.29, 0, 0, 1, 4, 37, 132, -1, 102, 128, 123, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, 121, 0, 1.570796, 0, -1, 16, -1, -1, -1, -1, -1, 1.5, 0, 1, 0, 0, 0, 35783010, 0.75, 0, 0, 0, 0, 0, 0, 15, 0, 0, 0, 0),
(8051, 0, 14, 0, 0, 0, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, -1, 102, 128, 123, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, 35717120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(8143, 8198, 5, 1, 0, 0.5, 1, 7, 19.29, 0, 0, 1, 4, 37, 38, 474, 474, 474, 474, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, 39, 0, -1.047198, 3.141593, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, 34078977, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0),
(9073, 0, 14, 0, 0, 0, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, -1, 102, 128, 123, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, 35717120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(9609, 0, 14, 0, 0, 0, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, -1, 102, 128, 123, 0, 7, 19.29, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1, 0, 0, 0, 35717120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(9677, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 3, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9061633, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9678, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9679, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9680, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9681, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9682, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9683, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0),
(9684, 134242307, 2, 0, 0, 0, 0, 10, 19.29, 0.5, 2, 10, 15, 40, 40, -1, 0, 126, 126, 0, 7, 19.29, 1.2, 1.2, 10, 10, 40, 40, 39, 0, 0, 0, 19, -1, 1, 126, -1, -1, 26, 1, 0, 1, 0, 0, 0, 9062145, 0.15, 1, 0, 0, 0, 0, 0, 100, 20, 0, 25, 0);

