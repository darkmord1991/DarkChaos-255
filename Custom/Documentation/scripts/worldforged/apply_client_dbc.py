#!/usr/bin/env python3
"""Add the generator's new rows to DC's client DBC sources and compiled DBCs (repo files only).

  Item.csv / ItemDisplayInfo.csv    rows appended (skipped when the id is already there), then compiled
                                    with wow.export-main/tools/dbc-compile.py and verified (0 field diffs)
  GameObjectDisplayInfo.dbc         records appended to the BINARY (never rebuilt from CSV: six rows hold
                                    GeoBox floats the CSV rounds), rows mirrored into the CSV for parity

Usage: python apply_client_dbc.py --work K:/tmp/worldforged_build [--apply]
Deploying the compiled files to the client archives and the server is a separate step (see README).
"""
import argparse
import csv
import json
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
CSV_DIR = REPO / "Custom" / "CSV DBC"
DBC_DIR = REPO / "Custom" / "DBCs"
COMPILER = Path(r"K:/Dark-Chaos/wow.export-main/tools/dbc-compile.py")


def csv_ids(path):
    with path.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.reader(fh)
        next(reader)
        return {int(row[0]) for row in reader if row and row[0].lstrip("-").isdigit()}


def append_rows(path, lines, label, apply):
    present = csv_ids(path)
    todo = [ln for ln in lines if int(ln.split(",", 1)[0].strip('"')) not in present]
    print(f"{label}: {len(lines)} rows, {len(lines) - len(todo)} already present, {len(todo)} to append")
    if apply and todo:
        data = path.read_bytes()
        if not data.endswith(b"\n"):
            raise SystemExit(f"{path} does not end with a newline")
        with path.open("ab") as fh:
            for ln in todo:
                fh.write(ln.encode("utf-8") + b"\n")
    return todo


def godi_append(rows, apply):
    path = DBC_DIR / "GameObjectDisplayInfo.dbc"
    d = path.read_bytes()
    magic, count, fields, size, strsize = struct.unpack_from("<4sIIII", d, 0)
    assert magic == b"WDBC" and fields == 19 and size == 76, (magic, fields, size)
    assert 20 + count * size + strsize == len(d), "trailing bytes"
    ids = {struct.unpack_from("<i", d, 20 + i * size)[0] for i in range(count)}
    todo = [r for r in rows if r[0] not in ids]
    print(f"GameObjectDisplayInfo.dbc: {count} records, {len(rows) - len(todo)} of ours present, "
          f"{len(todo)} to append")
    if not apply or not todo:
        return todo
    records = bytearray(d[20:20 + count * size])
    strings = bytearray(d[20 + count * size:])
    for r in todo:
        name_off = len(strings)
        strings += r[1].encode("utf-8") + b"\0"
        records += struct.pack("<2i", r[0], name_off) + struct.pack("<10i", *r[2:12]) \
            + struct.pack("<6f", *r[12:18]) + struct.pack("<i", r[18])
    out = struct.pack("<4sIIII", magic, count + len(todo), fields, size, len(strings)) + records + strings
    path.write_bytes(out)
    csv_path = CSV_DIR / "GameObjectDisplayInfo.csv"
    lines = []
    for r in todo:
        cells = [str(r[0]), r[1]] + [str(v) for v in r[2:12]] + [format(v, ".6g") for v in r[12:18]] + [str(r[18])]
        lines.append(",".join(f'"{c}"' for c in cells))
    append_rows(csv_path, lines, "GameObjectDisplayInfo.csv", True)
    return todo


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, required=True)
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    item_lines = (a.work / "Item.csv.rows").read_text(encoding="utf-8").splitlines()
    idi_lines = (a.work / "ItemDisplayInfo.csv.rows").read_text(encoding="utf-8").splitlines()
    godi_rows = json.loads((a.work / "GameObjectDisplayInfo.rows.json").read_text(encoding="utf-8"))

    new_items = append_rows(CSV_DIR / "Item.csv", item_lines, "Item.csv", a.apply)
    new_idi = append_rows(CSV_DIR / "ItemDisplayInfo.csv", idi_lines, "ItemDisplayInfo.csv", a.apply)
    if a.apply:
        for table, changed in (("Item", new_items), ("ItemDisplayInfo", new_idi)):
            if not changed:
                continue
            for args in (["--only", table], ["--verify", "--only", table]):
                res = subprocess.run([sys.executable, str(COMPILER)] + args, capture_output=True, text=True)
                print(res.stdout.strip())
                if res.returncode:
                    raise SystemExit(res.stderr)
    godi_append(godi_rows, a.apply)
    if not a.apply:
        print("dry run - pass --apply to write")


if __name__ == "__main__":
    main()
