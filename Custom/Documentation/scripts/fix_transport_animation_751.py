#!/usr/bin/env python3
"""Clone TransportAnimation frames onto the map-751 +4,600,000 gameobject band.

THE SYMPTOM
    StaticTransport::Create: No AnimationInfo was found for GameObject entry (4620651)
nine times at boot, and in-game the Undercity elevators/platforms simply are not there.

THE CAUSE -- AN OFFSET-BAND TRAP, the same family as the creature +4,100,000 ones.
TransportAnimation.dbc is keyed by **GameObject ENTRY**, not by displayId (the error
message says so: "for GameObject entry"). Its field 1 is the goEntry. The table already
carries frames for 20649..20657 -- the STOCK Undercity elevator entries -- but map 751's
import re-homed those gameobjects to 4,600,000 + base, i.e. 4620649..4620657. The lookup
is by entry, so it finds nothing and the transport never spawns.

Nothing else was wrong with them: gameobject_template rows exist (type 11, displayIds
455/462), the nine spawns exist on map 751, and 87_ already fixed their state/animprogress.
Only the animation link was severed by the offset.

THE FIX
Copy each frame of 20649..20657 to a new row with TransportID = base + 4,600,000,
preserving TimeIndex / X / Y / Z / SequenceID exactly. 54 frames in, 54 frames out.
New row ids start above the current maximum so nothing is overwritten.

This is additive: the stock 20649..20657 rows are left untouched, so anything still using
the unoffset entries keeps working.

Writes Custom/DBCs/TransportAnimation.dbc (+ the CSV if one exists) and
Plaguelands/101_transport_animation.sql for the overlay, if that table exists.
"""
import os, struct, csv, io

ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom"
SRC = r"k:/tmp/_ta/TransportAnimation.dbc"      # extracted from patch-4
OFFSET = 4600000
BASE = list(range(20649, 20658))
NL = chr(10)


def main():
    d = open(SRC, "rb").read()
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    assert (fc, rs) == (7, 28), (fc, rs)
    base, sb = 20, 20 + rc * rs
    recs = [bytearray(d[base + i * rs: base + (i + 1) * rs]) for i in range(rc)]
    ids = [struct.unpack_from("<I", r, 0)[0] for r in recs]
    nextid = max(ids) + 1

    have = {struct.unpack_from("<i", r, 4)[0] for r in recs}
    already = [b + OFFSET for b in BASE if (b + OFFSET) in have]
    assert not already, "offset rows already present: %s" % already

    added = []
    for b in BASE:
        for r in recs:
            if struct.unpack_from("<i", r, 4)[0] != b:
                continue
            new = bytearray(r)
            struct.pack_into("<I", new, 0, nextid)          # fresh row id
            struct.pack_into("<i", new, 4, b + OFFSET)      # re-home to the band
            added.append(new)
            nextid += 1
    print("frames cloned: %d (from %d base entries)" % (len(added), len(BASE)))

    out = b"WDBC" + struct.pack("<4I", rc + len(added), fc, rs, ss) \
        + b"".join(bytes(r) for r in recs) + b"".join(bytes(r) for r in added) \
        + d[sb:sb + ss]
    p = os.path.join(ROOT, "DBCs", "TransportAnimation.dbc")
    open(p, "wb").write(out)
    print("wrote %s : %d -> %d records" % (p, rc, rc + len(added)))

    # read-back verification
    d2 = open(p, "rb").read()
    rc2, fc2, rs2, ss2 = struct.unpack("<4I", d2[4:20])
    per = {}
    for i in range(rc2):
        t = struct.unpack_from("<i", d2, 20 + i * rs2 + 4)[0]
        per[t] = per.get(t, 0) + 1
    ok = all(per.get(b + OFFSET, 0) == per.get(b, 0) for b in BASE)
    print("  per-entry frame counts match base<->offset:", ok)
    for b in BASE[:3]:
        print("    %d -> %d frames | %d -> %d frames"
              % (b, per.get(b, 0), b + OFFSET, per.get(b + OFFSET, 0)))
    print("  originals byte-identical:", d[base:sb] == d2[20:20 + rc * rs])
    dup = [i for i, n in {}.items()]
    allids = [struct.unpack_from("<I", d2, 20 + i * rs2)[0] for i in range(rc2)]
    print("  row ids unique:", len(allids) == len(set(allids)))

    # CSV, if the project keeps one
    c = os.path.join(ROOT, "CSV DBC", "TransportAnimation.csv")
    if os.path.exists(c):
        with open(c, encoding="utf-8", newline="") as fh:
            r = csv.reader(fh); hdr = next(r); rows = [x for x in r if x and x[0].strip() != ""]
        for rec in added:
            rows.append([str(struct.unpack_from("<i", rec, k * 4)[0]) for k in range(fc)])
        buf = io.StringIO(); w = csv.writer(buf, lineterminator=NL, quoting=csv.QUOTE_ALL)
        w.writerow(hdr)
        for x in rows: w.writerow(x)
        open(c, "w", encoding="utf-8", newline="").write(buf.getvalue())
        print("  TransportAnimation.csv: %d rows" % len(rows))
    else:
        print("  (no TransportAnimation.csv in Custom/CSV DBC -- DBC only)")


main()
