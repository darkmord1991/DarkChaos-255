-- =====================================================================
-- Molten Front -- 10  vehicle_dbc 1631 (missing on BOTH client and server)
-- ---------------------------------------------------------------------
-- Found by bisecting a hard client crash (ERROR #132 / 0xC0000005 at
-- exe+0xF3C5B) that fired reproducibly on map 861 right after
-- "object: update stream active" -- i.e. while the client processed the
-- creature object-update stream, NOT during terrain load. The faulting
-- instruction read [ECX+0x1C] with ECX holding a small integer that varied
-- per run (0x188, 0x873, 0x5CB1, ...) = an ID being dereferenced as a pointer,
-- the classic signature of a DBC row lookup that returned nothing.
--
-- Audit of every client-side DBC the object-update path touches for the
-- map-861 creature set found exactly two gaps:
--   * FactionTemplate 2170  -- fixed client-side (server already had it via
--                              HyjalCata/93_faction_template_2170.sql)
--   * Vehicle 1631          -- missing on the CLIENT **and** here on the server
-- All other refs resolve: 94 creature displays, 24 GO displays, 91 factions,
-- creature families 3/20/42/45, and the other 11 VehicleIds (705,709,710,729,
-- 750,759,769,1035,1270,1412,1606) are all present.
--
-- Same systemic pattern as every other *_dbc gap in this downport: the
-- cross-DB creature_template copy brought a VehicleId whose DBC row lives only
-- in the Cata client. Values below are the real Cata 4.3.4 Vehicle.dbc row 1631
-- (locale-enUS.MPQ, 40 fields / recordSize 160 -- byte-identical schema to 3.3.5):
--   flags = -1073610744, turnSpeed = pitchSpeed = PI, mouseLookOffsetPitch = 0.7854,
--   cameraFadeDistScalarMin/Max = 1.0 / 1.5
-- SeatID_1 is set to **8976** -- an existing, known-good VehicleSeat already in
-- this client (the seat Vehicle 1270 uses) -- rather than importing Cata's seat
-- 9914, because Cata's VehicleSeat schema has extra columns vs 3.3.5 and a
-- half-mapped seat row is exactly the kind of thing that crashes the client.
-- Adjust later if the seat placement needs to be exact.
--
-- Idempotent.
-- =====================================================================

DELETE FROM `vehicle_dbc` WHERE `ID` = 1631;

INSERT INTO `vehicle_dbc`
    (`ID`,`Flags`,`TurnSpeed`,`PitchSpeed`,`PitchMin`,`PitchMax`,
     `SeatID_1`,`SeatID_2`,`SeatID_3`,`SeatID_4`,`SeatID_5`,`SeatID_6`,`SeatID_7`,`SeatID_8`,
     `MouseLookOffsetPitch`,`CameraFadeDistScalarMin`,`CameraFadeDistScalarMax`,`CameraPitchOffset`)
VALUES
    (1631, -1073610744, 3.14159274, 3.14159274, 0, 0,
     8976, 0, 0, 0, 0, 0, 0, 0,
     0.785398, 1, 1.5, 0);
