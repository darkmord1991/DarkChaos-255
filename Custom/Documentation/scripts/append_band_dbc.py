#!/usr/bin/env python3
"""Append rows to LightIntBand / LightFloatBand .dbc directly from their CSVs.

`csv2wdbc.py` cannot build these two: neither table exists in the WDBX definition
file (`WotLK 3.3.5 (12340).xml`), which is why the map-750 lighting work edited the
DBCs in place instead. That in-place habit is also what caused the documented drift
where the CSVs fell four params behind the DBCs -- so this tool goes the other way
and treats the CSV as the source of truth, appending only the rows the DBC lacks.

Both tables are trivially appendable: 34 uint32 columns, fixed-width records, and a
1-byte (empty) string block. A DBC is header(20) + records + stringblock, so new
records are spliced in before the string block and recordCount is bumped.

Usage: append_band_dbc.py <Table> [<Table> ...]
"""
import struct, os, sys, csv, shutil

CSVDIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "CSV DBC"))
DBCDIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "DBCs"))


def run(table):
    cpath = os.path.join(CSVDIR, table + ".csv")
    bpath = os.path.join(DBCDIR, table + ".dbc")
    raw = open(bpath, "rb").read()
    magic, rc, fc, rs, ss = struct.unpack_from("<4sIIII", raw, 0)
    if magic != b"WDBC":
        raise SystemExit("ABORT: %s is not WDBC" % bpath)
    if rs != fc * 4:
        raise SystemExit("ABORT: %s has variable-width records (rs=%d fc=%d)" % (table, rs, fc))
    if ss > 1:
        raise SystemExit("ABORT: %s has a non-empty string block (%d bytes); this tool "
                         "only handles pure-numeric tables" % (table, ss))

    recs = raw[20:20 + rc * rs]
    strblk = raw[20 + rc * rs:]
    have = {struct.unpack_from("<I", recs, i * rs)[0] for i in range(rc)}

    rows = list(csv.reader(open(cpath, encoding="utf-8-sig")))
    hdr = [h.strip().strip('"') for h in rows[0]]
    if len(hdr) != fc:
        raise SystemExit("ABORT: %s csv has %d columns, dbc has %d" % (table, len(hdr), fc))

    add = []
    for r in rows[1:]:
        if not r or not r[0].strip():
            continue
        vals = [int(float(c.strip().strip('"') or 0)) for c in r]
        if vals[0] in have:
            continue
        add.append(struct.pack("<%di" % fc, *vals))

    if not add:
        print("  %-16s nothing to append (dbc already has every csv id)" % table)
        return

    if not os.path.exists(bpath + ".pre_band_append.bak"):
        shutil.copyfile(bpath, bpath + ".pre_band_append.bak")
    out = bytearray(raw[:20])
    struct.pack_into("<I", out, 4, rc + len(add))
    out += recs + b"".join(add) + strblk
    open(bpath, "wb").write(bytes(out))

    # verify from what we just wrote
    v = open(bpath, "rb").read()
    m2, rc2, fc2, rs2, ss2 = struct.unpack_from("<4sIIII", v, 0)
    ids = {struct.unpack_from("<I", v, 20 + i * rs2)[0] for i in range(rc2)}
    lost = have - ids
    if rc2 != rc + len(add) or fc2 != fc or rs2 != rs or ss2 != ss or lost:
        raise SystemExit("ABORT: %s verify failed (rc=%d fc=%d lost=%d)" % (table, rc2, fc2, len(lost)))
    print("  %-16s %6d -> %6d rows (+%d), fields %d, 0 lost" % (table, rc, rc2, len(add), fc2))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    for t in sys.argv[1:]:
        run(t)
