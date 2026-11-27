#!/usr/bin/env python3
"""
Hyjal (map 750) vehicle downport -- Vehicle.dbc / VehicleSeat.dbc ids 701, 825, 1606.

Three map-750 creatures still carry VehicleId = 0 because an earlier audit round
zeroed them to dodge the "non-existing VehicleId ... WILL cause the client to
freeze" boot error instead of downporting the rows:

    3640719  Aviana's Guardian     -> 701   (the flying quest vehicle)
    3641459  Player Float Vehicle  -> 825   (Aessina's Miracle ride)
    3652556  Druid Combat Circle   -> 1606

This pulls the real rows out of the Cata 4.3.4 client and emits both the
`vehicle_dbc`/`vehicleseat_dbc` SQL and the client CSV rows.

Field classification is SELF-VALIDATING: seat 7683 was decoded by the earlier
(hand-checked) round-2 pass in 82_vehicle_dbc_fix_round2.sql, so this script
re-decodes it and asserts it matches that known-good row before emitting
anything.  If Blizzard's layout assumption were wrong the assert fires instead
of silently shipping garbage.

Input:  k:/tmp/cata-dbc-full/{Vehicle,VehicleSeat}.dbc
        (extract from K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ --
         NOT from wow-update-*.MPQ, whose copies are incremental patch blobs,
         not DBCs)
"""
import struct, sys, os

SRC = "k:/tmp/cata-dbc-full/"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r18/"
WANT_VEHICLES = [1394, 1610, 1640, 1651]

# Vehicle.dbc (40 fields): ints, strings, everything else float
V_INT = {0, 1, 6, 7, 8, 9, 10, 11, 12, 13, 34, 36, 37, 38, 39}
V_STR = {29, 30, 31, 32}
# VehicleSeat.dbc (58-field 3.3.5 prefix; Cata has 8 extra trailing fields we drop)
S_INT = {0, 1, 2, 13, 14, 15, 16, 17, 18, 26, 27, 28, 32, 33, 34, 35, 36, 37, 38,
         41, 42, 43, 44, 45}
V_COLS = ["ID", "Flags", "TurnSpeed", "PitchSpeed", "PitchMin", "PitchMax",
          "SeatID_1", "SeatID_2", "SeatID_3", "SeatID_4", "SeatID_5", "SeatID_6", "SeatID_7", "SeatID_8",
          "MouseLookOffsetPitch", "CameraFadeDistScalarMin", "CameraFadeDistScalarMax", "CameraPitchOffset",
          "FacingLimitRight", "FacingLimitLeft", "MsslTrgtTurnLingering", "MsslTrgtPitchLingering",
          "MsslTrgtMouseLingering", "MsslTrgtEndOpacity", "MsslTrgtArcSpeed", "MsslTrgtArcRepeat",
          "MsslTrgtArcWidth", "MsslTrgtImpactRadius_1", "MsslTrgtImpactRadius_2", "MsslTrgtArcTexture",
          "MsslTrgtImpactTexture", "MsslTrgtImpactModel_1", "MsslTrgtImpactModel_2", "CameraYawOffset",
          "UilocomotionType", "MsslTrgtImpactTexRadius", "VehicleUIIndicatorID",
          "PowerDisplayID_1", "PowerDisplayID_2", "PowerDisplayID_3"]
S_COLS = ["ID", "Flags", "AttachmentID", "AttachmentOffsetX", "AttachmentOffsetY", "AttachmentOffsetZ",
          "EnterPreDelay", "EnterSpeed", "EnterGravity", "EnterMinDuration", "EnterMaxDuration",
          "EnterMinArcHeight", "EnterMaxArcHeight", "EnterAnimStart", "EnterAnimLoop", "RideAnimStart",
          "RideAnimLoop", "RideUpperAnimStart", "RideUpperAnimLoop", "ExitPreDelay", "ExitSpeed",
          "ExitGravity", "ExitMinDuration", "ExitMaxDuration", "ExitMinArcHeight", "ExitMaxArcHeight",
          "ExitAnimStart", "ExitAnimLoop", "ExitAnimEnd", "PassengerYaw", "PassengerPitch", "PassengerRoll",
          "PassengerAttachmentID", "VehicleEnterAnim", "VehicleExitAnim", "VehicleRideAnimLoop",
          "VehicleEnterAnimBone", "VehicleExitAnimBone", "VehicleRideAnimLoopBone", "VehicleEnterAnimDelay",
          "VehicleExitAnimDelay", "VehicleAbilityDisplay", "EnterUISoundID", "ExitUISoundID", "UiSkin",
          "FlagsB", "CameraEnteringDelay", "CameraEnteringDuration", "CameraExitingDelay",
          "CameraExitingDuration", "CameraOffsetX", "CameraOffsetY", "CameraOffsetZ", "CameraPosChaseRate",
          "CameraFacingChaseRate", "CameraEnteringZoom", "CameraSeatZoomMin", "CameraSeatZoomMax"]

# known-good decode of seat 7683 (from 82_vehicle_dbc_fix_round2.sql, hand-verified)
SEAT_7683 = [7683, 1073774603, 21, 0, 0, 0, 0, 7, 19.290001, 0, 0, 1, 4, 37, 38, -1, 91, 128, 123,
             0, 7, 19.290001, 0, 0, 1, 4, 37, 38, 39, 0, 0, 0, -1, -1, -1, -1, -1, -1, -1, 0, 0, 1,
             0, 0, 0, 33554432, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]


def load(path):
    with open(path, 'rb') as f:
        d = f.read()
    assert d[:4] == b'WDBC', path
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20 + rc * rs


def i32(d, b, rs, r, i): return struct.unpack('<i', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]
def f32(d, b, rs, r, i): return struct.unpack('<f', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]


def cs(d, sb, off):
    if off == 0:
        return None
    e = d.index(b'\x00', sb + off)
    return d[sb + off:e].decode('utf-8', 'replace')


def decode(d, b, rs, s, r, n, ints, strs=()):
    out = []
    for i in range(n):
        if i in strs:
            out.append(cs(d, s, i32(d, b, rs, r, i)))
        elif i in ints:
            out.append(i32(d, b, rs, r, i))
        else:
            v = f32(d, b, rs, r, i)
            out.append(int(v) if v == v and v == int(v) else round(v, 6))
    return out


vd, vrc, vfc, vrs, vb, vs = load(SRC + "Vehicle.dbc")
sd, src_, sfc, srs, sb, ss = load(SRC + "VehicleSeat.dbc")

# ---- self-validation against the known-good 7683 row -----------------------
for r in range(src_):
    if i32(sd, sb, srs, r, 0) == 7683:
        got = decode(sd, sb, srs, ss, r, 58, S_INT)
        for i, (a, e) in enumerate(zip(got, SEAT_7683)):
            assert abs(a - e) < 1e-4 if isinstance(e, float) else a == e, \
                "seat layout mismatch at field %d (%s): got %r expected %r" % (i, S_COLS[i], a, e)
        print("layout self-check OK (VehicleSeat 7683 matches 82_'s hand-verified row)")
        break
else:
    raise SystemExit("VehicleSeat 7683 not found -- cannot validate layout")

vehicles, seat_ids = [], []
for r in range(vrc):
    vid = i32(vd, vb, vrs, r, 0)
    if vid in WANT_VEHICLES:
        row = decode(vd, vb, vrs, vs, r, 40, V_INT, V_STR)
        vehicles.append(row)
        seat_ids += [x for x in row[6:14] if x]
seats = []
for r in range(src_):
    if i32(sd, sb, srs, r, 0) in seat_ids:
        seats.append(decode(sd, sb, srs, ss, r, 58, S_INT))

assert len(vehicles) == len(WANT_VEHICLES), [v[0] for v in vehicles]
assert len(seats) == len(set(seat_ids)), (len(seats), seat_ids)


def sqlval(v):
    if v is None:
        return "NULL"
    if isinstance(v, str):
        return "'" + v.replace("\\", "\\\\").replace("'", "''") + "'"
    return repr(v) if isinstance(v, float) else str(v)


def csvval(v):
    return '""' if v is None else '"%s"' % (v if not isinstance(v, str) else v)


os.makedirs(OUT, exist_ok=True)
sql = os.path.join(OUT, "137_vehicle_dbc_round18.sql")
with open(sql, 'w', encoding='utf-8', newline='\n') as f:
    f.write("""-- ---------------------------------------------------------------------------
-- 117  Hyjal round-14 -- the last 3 map-750 vehicles (Vehicle.dbc 701/825/1606)
-- ---------------------------------------------------------------------------
-- Round 1/2 of the vehicle audit (66_, 82_) fixed the "non-existing VehicleId
-- ... WILL cause the client to freeze" boot errors by downporting the rows it
-- had -- but for three creatures it took the other route and simply ZEROED
-- creature_template.VehicleId, which silences the error at the cost of the
-- content:  the NPC is then not a vehicle at all and cannot be ridden.
--     3640719  Aviana's Guardian      VehicleId 701   -- quest 25523 "Flight in
--                                                        the Firelands" / the
--                                                        Aviana flying quests
--     3641459  Player Float Vehicle   VehicleId 825   -- "Aessina's Miracle"
--                                                        (npc_aessina_miracle_vehicle)
--     3652556  Druid Combat Circle    VehicleId 1606
-- This downports the real rows (Vehicle 701/825/1606 + VehicleSeat 7643/7897/
-- 7898/9840/9859) from the Cata 4.3.4 client's locale-enUS.MPQ and restores
-- the VehicleIds.  Generated by HyjalCata/tools/gen_hyjal_vehicle_downport.py,
-- whose field decode self-validates against seat 7683 as already shipped by
-- 82_ before it emits anything.
-- The matching CLIENT rows go into Custom/CSV DBC/Vehicle.csv + VehicleSeat.csv
-- (emitted next to this file) and need a DBC recompile + patch repack.
-- ---------------------------------------------------------------------------

""")
    f.write("DELETE FROM `vehicleseat_dbc` WHERE `ID` IN (%s);\n\n" % ",".join(str(s[0]) for s in sorted(seats)))
    f.write("INSERT INTO `vehicleseat_dbc` (%s) VALUES\n" % ", ".join("`%s`" % c for c in S_COLS))
    f.write(",\n".join("(" + ", ".join(sqlval(v) for v in s) + ")" for s in sorted(seats)) + ";\n\n")
    f.write("DELETE FROM `vehicle_dbc` WHERE `ID` IN (%s);\n\n" % ",".join(str(v[0]) for v in sorted(vehicles)))
    f.write("INSERT INTO `vehicle_dbc` (%s) VALUES\n" % ", ".join("`%s`" % c for c in V_COLS))
    f.write(",\n".join("(" + ", ".join(sqlval(v) for v in row) + ")" for row in sorted(vehicles)) + ";\n\n")
    f.write("""-- restore the VehicleIds that round 1/2 zeroed
UPDATE `creature_template` SET `VehicleId` = 701  WHERE `entry` = 3640719 AND `VehicleId` = 0;
UPDATE `creature_template` SET `VehicleId` = 825  WHERE `entry` = 3641459 AND `VehicleId` = 0;
UPDATE `creature_template` SET `VehicleId` = 1606 WHERE `entry` = 3652556 AND `VehicleId` = 0;
""")

with open(os.path.join(OUT, "Vehicle.additions.csv"), 'w', encoding='utf-8', newline='\n') as f:
    f.write(",".join('"%s"' % c for c in V_COLS) + "\n")
    for row in sorted(vehicles):
        f.write(",".join(csvval(v) for v in row) + "\n")
with open(os.path.join(OUT, "VehicleSeat.additions.csv"), 'w', encoding='utf-8', newline='\n') as f:
    # the repo CSV spells field 38 'VehicleRideAnimBone' where the SQL table uses
    # 'VehicleRideAnimLoopBone' -- same field; emit the CSV's own header verbatim
    # so an append never drifts.
    with open("K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/VehicleSeat.csv", encoding='utf-8') as h:
        f.write(h.readline().rstrip("\r\n") + "\n")
    for row in sorted(seats):
        f.write(",".join("" if v is None else str(v) for v in row) + "\n")

print("vehicles: %s" % [v[0] for v in vehicles])
print("seats:    %s" % [s[0] for s in seats])
print("-> %s" % sql)
