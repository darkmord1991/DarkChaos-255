#!/usr/bin/env python3
"""Generate the Vehicle.dbc / VehicleSeat.dbc rows the map-751 Lordaeron
extension needs, sourced from the real Cataclysm 4.3.4 client.

Emits `Custom/Custom feature SQLs/worlddb/Plaguelands/75_vehicle_dbc.sql`,
following the format established by `52_vehicle_dbc_fix.sql` for the first
Plaguelands import.

Why this exists
---------------
17 imported creature templates carry a `VehicleId`, and Vehicle.dbc contained
NONE of the 12 distinct ids they use. A creature whose VehicleId does not
resolve makes the client hang, so this is not cosmetic.

Neither cata_world nor nelt_world carries a Vehicle.dbc-equivalent table, so
the data comes straight out of the client:
  K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ -> DBFilesClient\\*.dbc
Base archive only -- no wow-update PTCH delta is needed; every id we want is
present pre-patch (asserted by the script, not assumed).

The 66 -> 58 field truncation
-----------------------------
VehicleSeat.dbc grew from 58 fields in 3.3.5 to 66 in 4.3.4. This script keeps
the first 58 and drops the rest, matching the project's WotLK-format
`vehicleseat_dbc` table. That is only safe if the 8 extra fields are TRAILING
rather than inserted -- so `verify_seat_layout()` proves it by diffing the
58-field prefix of every seat id present in BOTH clients. A field insertion
would desynchronise nearly all 782 shared rows from the insertion point on; the
observed handful of scattered per-field differences is ordinary Blizzard data
drift between patches. The script REFUSES to emit if that check fails.

Vehicle.dbc itself is 40 fields in both versions -- no truncation.
"""

import os
import struct

CATA_DBC = os.environ.get("CATA_DBC", r"K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ")
CATA_EXTRACT = os.environ.get("CATA_EXTRACT", "")  # dir with pre-extracted Vehicle*.dbc
LIVE_DBC = os.environ.get("LIVE_DBC", r"K:/Dark-Chaos/Server/data/dbc")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "..", "..", "Custom feature SQLs", "worlddb", "Plaguelands", "75_vehicle_dbc.sql")

# The 12 VehicleIds used by templates in the map-751 import band (4100000-4199999).
WANT_VEHICLES = [659, 665, 924, 1048, 1049, 1063, 1094, 1097, 1132, 1251, 1294, 1511]

# ---------------------------------------------------------------------------
# Column layouts. i = int32, f = float, s = string-block offset.
# ---------------------------------------------------------------------------
VEHICLE_COLS = [
    ("ID", "i"), ("Flags", "i"), ("TurnSpeed", "f"), ("PitchSpeed", "f"),
    ("PitchMin", "f"), ("PitchMax", "f"),
] + [("SeatID_%d" % (k + 1), "i") for k in range(8)] + [
    ("MouseLookOffsetPitch", "f"), ("CameraFadeDistScalarMin", "f"),
    ("CameraFadeDistScalarMax", "f"), ("CameraPitchOffset", "f"),
    ("FacingLimitRight", "f"), ("FacingLimitLeft", "f"),
    ("MsslTrgtTurnLingering", "f"), ("MsslTrgtPitchLingering", "f"),
    ("MsslTrgtMouseLingering", "f"), ("MsslTrgtEndOpacity", "f"),
    ("MsslTrgtArcSpeed", "f"), ("MsslTrgtArcRepeat", "f"),
    ("MsslTrgtArcWidth", "f"), ("MsslTrgtImpactRadius_1", "f"),
    ("MsslTrgtImpactRadius_2", "f"), ("MsslTrgtArcTexture", "s"),
    ("MsslTrgtImpactTexture", "s"), ("MsslTrgtImpactModel_1", "s"),
    ("MsslTrgtImpactModel_2", "s"), ("CameraYawOffset", "f"),
    ("UilocomotionType", "i"), ("MsslTrgtImpactTexRadius", "f"),
    ("VehicleUIIndicatorID", "i"), ("PowerDisplayID_1", "i"),
    ("PowerDisplayID_2", "i"), ("PowerDisplayID_3", "i"),
]

SEAT_COLS = [
    ("ID", "i"), ("Flags", "i"), ("AttachmentID", "i"),
    ("AttachmentOffsetX", "f"), ("AttachmentOffsetY", "f"), ("AttachmentOffsetZ", "f"),
    ("EnterPreDelay", "f"), ("EnterSpeed", "f"), ("EnterGravity", "f"),
    ("EnterMinDuration", "f"), ("EnterMaxDuration", "f"),
    ("EnterMinArcHeight", "f"), ("EnterMaxArcHeight", "f"),
    ("EnterAnimStart", "i"), ("EnterAnimLoop", "i"),
    ("RideAnimStart", "i"), ("RideAnimLoop", "i"),
    ("RideUpperAnimStart", "i"), ("RideUpperAnimLoop", "i"),
    ("ExitPreDelay", "f"), ("ExitSpeed", "f"), ("ExitGravity", "f"),
    ("ExitMinDuration", "f"), ("ExitMaxDuration", "f"),
    ("ExitMinArcHeight", "f"), ("ExitMaxArcHeight", "f"),
    ("ExitAnimStart", "i"), ("ExitAnimLoop", "i"), ("ExitAnimEnd", "i"),
    ("PassengerYaw", "f"), ("PassengerPitch", "f"), ("PassengerRoll", "f"),
    ("PassengerAttachmentID", "i"),
    ("VehicleEnterAnim", "i"), ("VehicleExitAnim", "i"), ("VehicleRideAnimLoop", "i"),
    ("VehicleEnterAnimBone", "i"), ("VehicleExitAnimBone", "i"),
    ("VehicleRideAnimLoopBone", "i"),
    ("VehicleEnterAnimDelay", "f"), ("VehicleExitAnimDelay", "f"),
    ("VehicleAbilityDisplay", "i"), ("EnterUISoundID", "i"), ("ExitUISoundID", "i"),
    ("UiSkin", "i"), ("FlagsB", "i"),
    ("CameraEnteringDelay", "f"), ("CameraEnteringDuration", "f"),
    ("CameraExitingDelay", "f"), ("CameraExitingDuration", "f"),
    ("CameraOffsetX", "f"), ("CameraOffsetY", "f"), ("CameraOffsetZ", "f"),
    ("CameraPosChaseRate", "f"), ("CameraFacingChaseRate", "f"),
    ("CameraEnteringZoom", "f"), ("CameraSeatZoomMin", "f"), ("CameraSeatZoomMax", "f"),
]
assert len(VEHICLE_COLS) == 40 and len(SEAT_COLS) == 58


class Dbc:
    def __init__(self, blob):
        magic, self.rc, self.fc, self.rs, self.ss = struct.unpack_from("<4sIIII", blob, 0)
        if magic != b"WDBC":
            raise ValueError("not a WDBC file")
        self.rows, self.raws = {}, {}
        for i in range(self.rc):
            raw = blob[20 + i * self.rs: 20 + (i + 1) * self.rs]
            key = struct.unpack_from("<I", raw, 0)[0]
            self.rows[key] = struct.unpack_from("<%dI" % self.fc, raw, 0)
            self.raws[key] = raw
        self.strings = blob[20 + self.rc * self.rs:]

    def string_at(self, off):
        if not off or off >= len(self.strings):
            return None
        end = self.strings.find(b"\0", off)
        s = self.strings[off:end if end >= 0 else None].decode("utf-8", "replace")
        return s or None


def read_dbc(name):
    """Prefer a pre-extracted copy; otherwise pull it out of the client MPQ."""
    if CATA_EXTRACT:
        p = os.path.join(CATA_EXTRACT, name + ".dbc")
        if os.path.exists(p):
            return Dbc(open(p, "rb").read())
    import subprocess, tempfile
    tools = r"K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py"
    tmp = tempfile.mkdtemp()
    subprocess.run(["python", tools, "--mpq", CATA_DBC, "--out", tmp,
                    "--file", "DBFilesClient\\%s.dbc" % name, "--quiet"], check=True)
    return Dbc(open(os.path.join(tmp, name + ".dbc"), "rb").read())


def sql_val(kind, word, dbc):
    if kind == "f":
        f = struct.unpack("<f", struct.pack("<I", word))[0]
        if f != f or f in (float("inf"), float("-inf")):
            return "0.0"
        return repr(round(f, 6))
    if kind == "s":
        s = dbc.string_at(word)
        return "NULL" if s is None else "'%s'" % s.replace("\\", "\\\\").replace("'", "''")
    return str(struct.unpack("<i", struct.pack("<I", word))[0])


def verify_seat_layout(cata, live):
    """Prove the 8 extra Cata fields are trailing, not inserted."""
    common = sorted(set(cata.rows) & set(live.rows))
    if len(common) < 100:
        raise SystemExit("ABORT: only %d shared seat ids -- too few to validate layout" % len(common))
    per_field = {}
    for sid in common:
        cv, lv = cata.rows[sid], live.rows[sid]
        for j in range(live.fc):
            if cv[j] != lv[j]:
                per_field[j] = per_field.get(j, 0) + 1
    # An INSERTED field desynchronises nearly every row from that index onward.
    bad = [j for j, n in per_field.items() if n > len(common) * 0.5]
    if bad:
        raise SystemExit("ABORT: fields %s differ in >50%% of %d shared rows -- "
                         "the layout is NOT a clean 58-field prefix." % (bad, len(common)))
    return len(common), sum(per_field.values())


def main():
    cveh, cseat = read_dbc("Vehicle"), read_dbc("VehicleSeat")
    lveh = Dbc(open(os.path.join(LIVE_DBC, "Vehicle.dbc"), "rb").read())
    lseat = Dbc(open(os.path.join(LIVE_DBC, "VehicleSeat.dbc"), "rb").read())

    shared, drift = verify_seat_layout(cseat, lseat)

    absent = [v for v in WANT_VEHICLES if v not in cveh.rows]
    if absent:
        raise SystemExit("ABORT: vehicles %s are not in the Cata base archive "
                         "(a wow-update PTCH delta would be needed)" % absent)

    seats, seat_of = set(), {}
    for v in WANT_VEHICLES:
        s = [cveh.rows[v][6 + k] for k in range(8) if cveh.rows[v][6 + k]]
        seat_of[v] = s
        seats.update(s)
    missing_seats = sorted(s for s in seats if s not in cseat.rows)
    if missing_seats:
        raise SystemExit("ABORT: seats %s referenced but absent from the Cata client" % missing_seats)

    add_seats = sorted(s for s in seats if s not in lseat.rows)
    keep_seats = sorted(s for s in seats if s in lseat.rows)

    def rows_sql(table, cols, dbc, ids, fc_limit):
        names = ", ".join("`%s`" % c for c, _ in cols)
        out = ["DELETE FROM `%s` WHERE `ID` IN (%s);" % (table, ",".join(str(i) for i in ids)), ""]
        out.append("INSERT INTO `%s` (%s) VALUES" % (table, names))
        body = []
        for i in ids:
            r = dbc.rows[i]
            body.append("(" + ", ".join(sql_val(k, r[j], dbc) for j, (_, k) in enumerate(cols)) + ")")
        out.append(",\n".join(body) + ";")
        return "\n".join(out)

    with open(os.path.abspath(OUT), "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("-- 75_vehicle_dbc.sql -- map 751 Lordaeron extension, DB step 14.\n")
        w("--\n")
        w("-- GENERATED by Custom/Documentation/scripts/gen_map751_vehicle_dbc.py -- do not\n")
        w("-- hand-edit; re-run the generator instead.\n")
        w("--\n")
        w("-- 17 imported creature templates carry a VehicleId, and Vehicle.dbc had NONE of\n")
        w("-- the %d distinct ids they use. An unresolved VehicleId hangs the client, so this\n" % len(WANT_VEHICLES))
        w("-- is a hard blocker, not polish. Same gap 52_vehicle_dbc_fix.sql closed for the\n")
        w("-- first Plaguelands import.\n")
        w("--\n")
        w("-- Source: the real Cataclysm 4.3.4 client,\n")
        w("--   %s -> DBFilesClient\\Vehicle.dbc / VehicleSeat.dbc\n" % CATA_DBC)
        w("-- Base archive only; all %d ids are present pre-patch, so no wow-update PTCH\n" % len(WANT_VEHICLES))
        w("-- delta is involved. (cata_world / nelt_world carry no Vehicle.dbc equivalent.)\n")
        w("--\n")
        w("-- VehicleSeat.dbc is 66 fields in 4.3.4 versus 58 in 3.3.5; the 8 Cata-only\n")
        w("-- trailing fields are dropped to match this project's WotLK-format\n")
        w("-- `vehicleseat_dbc` table. That truncation was PROVEN safe, not assumed: the\n")
        w("-- 58-field prefix was diffed across all %d seat ids present in both clients and\n" % shared)
        w("-- only %d individual field values differ in total (ordinary Blizzard data drift).\n" % drift)
        w("-- An inserted -- rather than appended -- field would have desynchronised nearly\n")
        w("-- every row from the insertion point onward. Vehicle.dbc is 40 fields in both.\n")
        w("--\n")
        w("-- Seats: %d referenced, %d already live, %d added here.\n" % (len(seats), len(keep_seats), len(add_seats)))
        w("--\n")
        for v in WANT_VEHICLES:
            w("--   vehicle %-5d -> seat(s) %s\n" % (v, ", ".join(str(x) for x in seat_of[v])))
        w("\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 1. Vehicle rows\n")
        w("-- ---------------------------------------------------------------------------\n")
        w(rows_sql("vehicle_dbc", VEHICLE_COLS, cveh, WANT_VEHICLES, 40) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 2. VehicleSeat rows (first 58 of the client's 66 fields)\n")
        w("-- ---------------------------------------------------------------------------\n")
        w(rows_sql("vehicleseat_dbc", SEAT_COLS, cseat, add_seats, 58) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- Verification\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("SELECT 'vehicle rows present (want %d)' AS what, COUNT(*) AS n\n" % len(WANT_VEHICLES))
        w("FROM `vehicle_dbc` WHERE `ID` IN (%s)\n" % ",".join(str(i) for i in WANT_VEHICLES))
        w("UNION ALL SELECT 'seat rows present (want %d)', COUNT(*)\n" % len(seats))
        w("FROM `vehicleseat_dbc` WHERE `ID` IN (%s);\n\n" % ",".join(str(i) for i in sorted(seats)))
        w("-- must be zero: an imported template whose VehicleId still has no row\n")
        w("SELECT 'PROBLEM: template with an unresolved VehicleId' AS problem,\n")
        w("       t.`entry`, t.`name`, t.`VehicleId`\n")
        w("FROM `creature_template` t\n")
        w("LEFT JOIN `vehicle_dbc` v ON v.`ID` = t.`VehicleId`\n")
        w("WHERE t.`entry` BETWEEN 4100000 AND 4199999\n")
        w("  AND t.`VehicleId` > 0 AND v.`ID` IS NULL;\n\n")
        w("-- must be zero: a vehicle pointing at a seat that does not exist\n")
        idlist = ",".join(str(i) for i in WANT_VEHICLES)
        w("SELECT 'PROBLEM: vehicle references a missing seat' AS problem, s.`ID`, s.`seat`\n")
        w("FROM (\n")
        # The column alias goes on the FIRST branch of a UNION ALL -- naming it on a
        # later branch is a 1054 at apply time.
        for k in range(8):
            w("  %sSELECT `ID`, `SeatID_%d`%s FROM `vehicle_dbc` WHERE `ID` IN (%s)\n"
              % ("" if k == 0 else "UNION ALL ", k + 1, " AS `seat`" if k == 0 else "", idlist))
        w(") s\n")
        w("WHERE s.`seat` > 0 AND s.`seat` NOT IN (SELECT `ID` FROM `vehicleseat_dbc`);\n")

    print("wrote %s" % os.path.normpath(os.path.abspath(OUT)))
    print("  vehicles %d, seats added %d (of %d referenced), layout verified over %d shared rows"
          % (len(WANT_VEHICLES), len(add_seats), len(seats), shared))


if __name__ == "__main__":
    main()
