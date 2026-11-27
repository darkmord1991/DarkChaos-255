#!/usr/bin/env python3
"""Extend `QuestXP.dbc` from level 100 to level 255.

`Quest::XPValue` (src/server/game/Quests/QuestDef.cpp:199) looks the quest's level up in
`QuestXP.dbc` and **returns 0 outright when there is no row**:

    QuestXPEntry const* xpentry = sQuestXPStore.LookupEntry(quest_level);
    if (!xpentry)
        return 0;

The shipped DBC stops at level 100, so on a 255-level server every quest above level 100
awards no experience at all.  This script continues the existing curve to 255.

Shape of the table: 11 uint32 fields - `ID` (= level) then `Exp[10]`.  Columns 0 and 9 are
always 0 (a known trap: `RewardXPDifficulty = 9` therefore zeroes a quest's XP; 8 is the
real maximum).  Columns 1-8 advance by a fixed per-level slope, quantised to 50:

    col   1    2    3    4    5    6    7    8
    slope 25   60  120  180  240  300  360  480

measured over levels 80-100 of the stock table, and consistent across the whole tail.

Usage:
    python extend_questxp_255.py [--src PATH] [--out-dbc PATH] [--out-csv PATH] [--check-only]
"""

import argparse
import io
import os
import struct
import sys

MAX_LEVEL = 255
SOURCE_LAST_LEVEL = 100
SLOPE_FIT_FROM = 80
QUANTUM = 50
FIELD_COUNT = 11
RECORD_SIZE = 44


def read_dbc(path):
    with open(path, "rb") as handle:
        blob = handle.read()
    magic, record_count, field_count, record_size, string_size = struct.unpack("<4siiii", blob[:20])
    if magic != b"WDBC":
        raise ValueError(f"{path}: not a WDBC file")
    if field_count != FIELD_COUNT or record_size != RECORD_SIZE:
        raise ValueError(f"{path}: expected {FIELD_COUNT} fields / {RECORD_SIZE}b records, "
                         f"got {field_count} / {record_size}")
    rows = {}
    for index in range(record_count):
        offset = 20 + index * record_size
        values = struct.unpack("<11i", blob[offset:offset + record_size])
        rows[values[0]] = list(values)
    return rows, string_size


def write_dbc(path, rows, string_size):
    ordered = [rows[key] for key in sorted(rows)]
    payload = bytearray()
    payload += struct.pack("<4siiii", b"WDBC", len(ordered), FIELD_COUNT, RECORD_SIZE,
                           max(string_size, 1))
    for values in ordered:
        payload += struct.pack("<11i", *values)
    payload += b"\0" * max(string_size, 1)
    with open(path, "wb") as handle:
        handle.write(payload)
    return len(ordered)


def compute_slopes(rows):
    """Per-column per-level slope, measured across the clean upper range."""
    low = rows[SLOPE_FIT_FROM]
    high = rows[SOURCE_LAST_LEVEL]
    span = SOURCE_LAST_LEVEL - SLOPE_FIT_FROM
    return [(high[col] - low[col]) / span for col in range(FIELD_COUNT)]


def extend(rows, slopes):
    """Continue the curve past SOURCE_LAST_LEVEL, quantised to QUANTUM."""
    anchor = rows[SOURCE_LAST_LEVEL]
    added = 0
    for level in range(SOURCE_LAST_LEVEL + 1, MAX_LEVEL + 1):
        if level in rows:
            continue
        values = [level]
        for col in range(1, FIELD_COUNT):
            if anchor[col] == 0:
                values.append(0)          # cols 0 and 9 stay 0 by design
                continue
            raw = anchor[col] + slopes[col] * (level - SOURCE_LAST_LEVEL)
            values.append(int(round(raw / QUANTUM)) * QUANTUM)
        rows[level] = values
        added += 1
    return added


def write_csv(path, rows):
    header = ["Level"] + [f"Exp_{i}" for i in range(10)]
    with io.open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(",".join(header) + "\n")
        for key in sorted(rows):
            handle.write(",".join(str(v) for v in rows[key]) + "\n")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", ".."))
    default_src = os.path.join(repo, "DBCs", "QuestXP.dbc")
    default_csv = os.path.join(repo, "CSV DBC", "Extended_255", "QuestXP.csv")

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", default=default_src)
    parser.add_argument("--out-dbc", default=None, help="default: overwrite --src in place")
    parser.add_argument("--out-csv", default=default_csv)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()

    rows, string_size = read_dbc(args.src)
    print(f"source: {args.src}  ({len(rows)} rows, last level {max(rows)})")

    slopes = compute_slopes(rows)
    # Record layout is [ID, Exp_0 .. Exp_9], so Exp_k lives at index k + 1.
    print("per-level slopes (Exp_1..Exp_8): " + ", ".join(f"{s:g}" for s in slopes[2:10]))

    added = extend(rows, slopes)
    print(f"rows added: {added}  -> {len(rows)} total, last level {max(rows)}")

    for level in (80, 100, 130, 200, 255):
        if level in rows:
            row = rows[level]
            print(f"  L{level:>3}: Exp_8 (max difficulty) = {row[9]:>8,}   "
                  f"Exp_0 = {row[1]}, Exp_9 = {row[10]}")

    if args.check_only:
        return 0

    out_dbc = args.out_dbc or args.src
    count = write_dbc(out_dbc, rows, string_size)
    print(f"\nwrote {out_dbc} ({count} rows)")

    if args.out_csv:
        os.makedirs(os.path.dirname(args.out_csv), exist_ok=True)
        write_csv(args.out_csv, rows)
        print(f"wrote {args.out_csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
