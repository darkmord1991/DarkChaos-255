-- ---------------------------------------------------------------------------
-- vehicle_dbc / vehicleseat_dbc  (non-existing VehicleId -- "WILL cause the
-- client to freeze" per boot log). Neither cata_world nor nelt_world carry a
-- Vehicle.dbc-equivalent table, so this is sourced directly from the real
-- Cataclysm 4.3.4 client (K:/Cata, DBFilesClient\Vehicle.dbc /
-- VehicleSeat.dbc in enUS/locale-enUS.MPQ -- base data, no PTCH delta needed,
-- all referenced IDs present pre-patch). Scope: DC Plaguelands (map 751), incl. world boss Julak-Doom (3650089 -- VehicleId 1412).
-- VehicleSeat.dbc grew from 58 to 66 fields between 3.3.5 and 4.3.4; the 8
-- extra Cata-only trailing fields are dropped to match this project's
-- existing 58-field WotLK-format vehicleseat_dbc convention -- they don't
-- affect seat validity, only some newer client-side camera/animkit polish.
-- ---------------------------------------------------------------------------

DELETE FROM `vehicle_dbc` WHERE `ID` IN (1035,1104,1412);

INSERT INTO `vehicle_dbc` (`ID`, `Flags`, `TurnSpeed`, `PitchSpeed`, `PitchMin`, `PitchMax`, `SeatID_1`, `SeatID_2`, `SeatID_3`, `SeatID_4`, `SeatID_5`, `SeatID_6`, `SeatID_7`, `SeatID_8`, `MouseLookOffsetPitch`, `CameraFadeDistScalarMin`, `CameraFadeDistScalarMax`, `CameraPitchOffset`, `FacingLimitRight`, `FacingLimitLeft`, `MsslTrgtTurnLingering`, `MsslTrgtPitchLingering`, `MsslTrgtMouseLingering`, `MsslTrgtEndOpacity`, `MsslTrgtArcSpeed`, `MsslTrgtArcRepeat`, `MsslTrgtArcWidth`, `MsslTrgtImpactRadius_1`, `MsslTrgtImpactRadius_2`, `MsslTrgtArcTexture`, `MsslTrgtImpactTexture`, `MsslTrgtImpactModel_1`, `MsslTrgtImpactModel_2`, `CameraYawOffset`, `UilocomotionType`, `MsslTrgtImpactTexRadius`, `VehicleUIIndicatorID`, `PowerDisplayID_1`, `PowerDisplayID_2`, `PowerDisplayID_3`) VALUES
(1035, 1073877031, 3.142, 3.142, 0.0, 0.0, 8373, 0, 0, 0, 0, 0, 0, 0, 0.785398, 1.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, NULL, NULL, NULL, NULL, 0.0, 0, 0.0, 0, 0, 0, 0),
(1104, 1342312487, 3.142, 3.142, 0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0.785398, 1.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, NULL, NULL, NULL, NULL, 0.0, 5, 0.0, 0, 0, 0, 0),
(1412, 1073877031, 3.142, 3.142, 0.0, 0.0, 9337, 0, 0, 0, 0, 0, 0, 0, 0.785398, 1.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, NULL, NULL, NULL, NULL, 0.0, 0, 0.0, 0, 0, 0, 0);

DELETE FROM `vehicleseat_dbc` WHERE `ID` IN (8373,9337);

INSERT INTO `vehicleseat_dbc` (`ID`, `Flags`, `AttachmentID`, `AttachmentOffsetX`, `AttachmentOffsetY`, `AttachmentOffsetZ`, `EnterPreDelay`, `EnterSpeed`, `EnterGravity`, `EnterMinDuration`, `EnterMaxDuration`, `EnterMinArcHeight`, `EnterMaxArcHeight`, `EnterAnimStart`, `EnterAnimLoop`, `RideAnimStart`, `RideAnimLoop`, `RideUpperAnimStart`, `RideUpperAnimLoop`, `ExitPreDelay`, `ExitSpeed`, `ExitGravity`, `ExitMinDuration`, `ExitMaxDuration`, `ExitMinArcHeight`, `ExitMaxArcHeight`, `ExitAnimStart`, `ExitAnimLoop`, `ExitAnimEnd`, `PassengerYaw`, `PassengerPitch`, `PassengerRoll`, `PassengerAttachmentID`, `VehicleEnterAnim`, `VehicleExitAnim`, `VehicleRideAnimLoop`, `VehicleEnterAnimBone`, `VehicleExitAnimBone`, `VehicleRideAnimLoopBone`, `VehicleEnterAnimDelay`, `VehicleExitAnimDelay`, `VehicleAbilityDisplay`, `EnterUISoundID`, `ExitUISoundID`, `UiSkin`, `FlagsB`, `CameraEnteringDelay`, `CameraEnteringDuration`, `CameraExitingDelay`, `CameraExitingDuration`, `CameraOffsetX`, `CameraOffsetY`, `CameraOffsetZ`, `CameraPosChaseRate`, `CameraFacingChaseRate`, `CameraEnteringZoom`, `CameraSeatZoomMin`, `CameraSeatZoomMax`) VALUES
(8373, 34635784, 5, 0.15, 0.0, -0.2, 0.0, 7.0, 19.290001, 0.0, 0.0, 1.0, 4.0, 37, 38, -1, -1, -1, -1, 0.0, 7.0, 19.290001, 0.0, 0.0, 1.0, 4.0, 37, 38, 39, 0.0, 0.0, 0.0, 19, -1, -1, -1, -1, -1, -1, 0.0, 0.0, 1, 0, 0, 0, 33554432, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
(9337, 33587215, 5, -0.1, 0.0, 0.1, 0.0, 7.0, 19.290001, 0.0, 0.0, 1.0, 4.0, 37, 38, 227, 227, 227, 227, 0.0, 7.0, 19.290001, 0.0, 0.0, 1.0, 4.0, 37, 38, 39, 0.0, -1.22173, 0.0, -1, -1, -1, -1, -1, -1, -1, 0.0, 0.0, 1, 0, 0, 0, 33554432, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);

