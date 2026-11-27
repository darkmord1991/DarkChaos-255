#!/usr/bin/env python3
"""Repair the geometry of the downported Mount Hyjal area triggers.

`HyjalCata/15_areatrigger.sql` cloned 61 Cata triggers into the ID+600,000 block and wrote
matching client rows into `Custom/CSV DBC/AreaTrigger.csv`.  The copy was positional, but
the two DBC layouts are not the same width:

    WotLK 3.3.5 AreaTrigger.dbc : 10 fields, recsize 40
        0 ID  1 ContinentID  2 X  3 Y  4 Z  5 Radius
        6 Box_Length  7 Box_Width  8 Box_Height  9 Box_Yaw

    Cata  4.3.4 AreaTrigger.dbc : 13 fields, recsize 52
        0 ID  1 ContinentID  2 X  3 Y  4 Z  5 ?  6 ?  7 ?
        8 Radius  9 Box_Length  10 Box_Width  11 Box_Height  12 Box_Yaw

Cata inserts three extra fields at 5-7, so a positional copy shifts the whole geometry
block by three: the real `Radius` landed in `Box_Height`, `Box_Length` landed in `Box_Yaw`,
and `Radius`/`Box_Length`/`Box_Width` were filled with Cata's three unrelated zeros.

The result is a trigger with **no volume at all** - radius 0 and a 0x0 box - which can never
fire.  110 of the 112 rows in the block are in that state (stock WotLK has only 3 such rows
out of 1,256).  Positions were unaffected, which is why this went unnoticed.

Repair: re-read the Cata DBC and take fields 8-12 for each cloned trigger.

Excluded: 607000 / 607001 (Karazhan Crypts) are hand-authored, not part of the downport,
and are detected automatically because they do not match the positional-copy signature.

Usage:
    python fix_areatrigger_geometry.py [--csv PATH] [--cata-dbc PATH] [--check-only]
"""

import argparse
import csv
import io
import os
import struct
import sys

CLONE_OFFSET = 600000

# WotLK CSV column indices
W_ID, W_CONTINENT, W_X, W_Y, W_Z = 0, 1, 2, 3, 4
W_RADIUS, W_BOX_LEN, W_BOX_WID, W_BOX_HGT, W_BOX_YAW = 5, 6, 7, 8, 9

# Cata DBC field indices for the geometry block
C_RADIUS, C_BOX_LEN, C_BOX_WID, C_BOX_HGT, C_BOX_YAW = 8, 9, 10, 11, 12

TOLERANCE = 0.01


def read_cata_dbc(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    magic, record_count, field_count, record_size, _ = struct.unpack("<4siiii", blob[:20])
    if magic != b"WDBC":
        raise ValueError(f"{path}: not a WDBC file")
    if field_count < 13:
        raise ValueError(f"{path}: expected the 13-field Cata layout, got {field_count}")
    rows = {}
    for index in range(record_count):
        offset = 20 + index * record_size
        ints = struct.unpack(f"<{field_count}i", blob[offset:offset + 4 * field_count])
        floats = struct.unpack(f"<{field_count}f", blob[offset:offset + 4 * field_count])
        rows[ints[0]] = floats
    return rows


def looks_positionally_copied(row, source):
    """True when CSV fields 5-9 equal Cata fields 5-9 - the signature of the bad copy."""
    for offset in range(5, 10):
        try:
            got = float(row[offset])
        except ValueError:
            return False
        if abs(got - source[offset]) > TOLERANCE:
            return False
    return True


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", ".."))
    default_csv = os.path.join(repo, "CSV DBC", "AreaTrigger.csv")

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", default=default_csv)
    parser.add_argument("--cata-dbc", default="k:/tmp/cata-dbc/AreaTrigger.dbc")
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()

    cata = read_cata_dbc(args.cata_dbc)
    print(f"cata source: {args.cata_dbc} ({len(cata)} rows)")

    with io.open(args.csv, encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.reader(handle))
    header, body = rows[0], rows[1:]

    repaired = skipped = absent = 0
    spheres = boxes = degenerate = 0

    for row in body:
        trigger_id = int(row[W_ID])
        if trigger_id < CLONE_OFFSET:
            continue
        source_id = trigger_id - CLONE_OFFSET
        source = cata.get(source_id)
        if source is None:
            absent += 1
            continue
        if not looks_positionally_copied(row, source):
            # Hand-authored or already repaired - never overwrite.
            skipped += 1
            continue

        row[W_RADIUS] = f"{source[C_RADIUS]:.6g}"
        row[W_BOX_LEN] = f"{source[C_BOX_LEN]:.6g}"
        row[W_BOX_WID] = f"{source[C_BOX_WID]:.6g}"
        row[W_BOX_HGT] = f"{source[C_BOX_HGT]:.6g}"
        row[W_BOX_YAW] = f"{source[C_BOX_YAW]:.6g}"
        repaired += 1

        if source[C_RADIUS] > 0:
            spheres += 1
        elif source[C_BOX_LEN] > 0 and source[C_BOX_WID] > 0:
            boxes += 1
        else:
            degenerate += 1

    print(f"repaired : {repaired}  (sphere {spheres}, box {boxes}, still-degenerate {degenerate})")
    print(f"skipped  : {skipped}  (hand-authored / already correct)")
    print(f"no cata source: {absent}")

    if args.check_only:
        return 0

    # The file has no BOM and uses LF - write it back exactly that way.
    with io.open(args.csv, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, quoting=csv.QUOTE_ALL, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(body)
    print(f"\nwrote {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
