#!/usr/bin/env python3
"""Add the Timbermaw (tortoise port) rows to the DC DBC sources, idempotently.

  * Custom/CSV DBC/CreatureModelData.csv, CreatureDisplayInfo.csv, ItemDisplayInfo.csv -- new display rows
    from client_asset_plan.json (Turtle models re-hosted at 4010001+ / 4102000+)
  * Custom/CSV DBC/Item.csv -- one row per new item (the core DROPS any item_template row without one)
  * Custom/CSV DBC/Achievement.csv -- achievement 60049 now names Ursol (its criterion already points at 4010007)
  * Custom/DBCs/DungeonEncounter.dbc -- patched IN PLACE, because its CSV is the stale side (736 vs 1017 rows,
    see the dungeon-encounter memory); the CSV's map-819 rows are updated to match for readability.

Every CSV edit is byte-level: these files mix CRLF/LF and quoted/unquoted rows, and appended rows copy the
quoted CRLF style of the newest rows. Re-running is a no-op. Compiling is a separate step (00_README.md).
"""
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
CSV_DIR = os.path.join(REPO, "Custom", "CSV DBC")
DBC_DIR = os.path.join(REPO, "Custom", "DBCs")
sys.path.insert(0, HERE)
from gen_timbermaw_sql import ENCOUNTERS, ENCOUNTER_DBC_IDS  # noqa: E402


def read_ids(path):
    ids = set()
    with open(path, "rb") as fh:
        next(fh)
        for line in fh:
            first = line.split(b",", 1)[0].strip(b'"\xef\xbb\xbf\r\n')
            if first.isdigit():
                ids.add(int(first))
    return ids


def header(path):
    with open(path, "rb") as fh:
        h = fh.readline().decode("utf-8-sig").strip()
    return [c.strip('"') for c in h.split(",")]


def append_rows(name, rows):
    path = os.path.join(CSV_DIR, name)
    cols = header(path)
    have = read_ids(path)
    out = []
    for r in rows:
        if int(r["ID"]) in have:
            continue
        vals = [str(r.get(c, "0")) for c in cols]
        for v in vals:
            if '"' in v or "\n" in v:
                raise SystemExit("%s: value needs escaping, refusing: %r" % (name, v))
        out.append(",".join('"%s"' % v for v in vals).encode("utf-8") + b"\r\n")
    if out:
        with open(path, "rb") as fh:
            data = fh.read()
        if not data.endswith(b"\n"):
            data += b"\r\n"
        with open(path, "wb") as fh:
            fh.write(data + b"".join(out))
    print("%-24s +%d rows (%d already present)" % (name, len(out), len(rows) - len(out)))


def edit_line(name, key_prefix, old, new):
    path = os.path.join(CSV_DIR, name)
    data = open(path, "rb").read()
    lines = data.split(b"\n")
    changed = 0
    for i, line in enumerate(lines):
        if line.startswith(key_prefix) and old in line:
            lines[i] = line.replace(old, new)
            changed += 1
    if changed:
        open(path, "wb").write(b"\n".join(lines))
    print("%-24s %d line(s) edited" % (name, changed))


def patch_dungeon_encounter():
    """Rename map 819's rows to the new encounters and add bits 7/8, in the binary DBC."""
    path = os.path.join(DBC_DIR, "DungeonEncounter.dbc")
    data = open(path, "rb").read()
    magic, nrec, nfield, recsize, strsize = struct.unpack_from("<4s4I", data, 0)
    assert magic == b"WDBC" and nfield == 23 and recsize == 92, (magic, nfield, recsize)
    rows = [list(struct.unpack_from("<23I", data, 20 + i * 92)) for i in range(nrec)]
    strings = data[20 + nrec * 92:]

    def s(off):
        return strings[off:strings.index(b"\0", off)].decode("utf-8")

    text = [[s(r[k]) for k in range(5, 21)] for r in rows]
    by_id = {r[0]: i for i, r in enumerate(rows)}
    wanted = {}
    for diff, ids in ENCOUNTER_DBC_IDS.items():
        for bit, eid in enumerate(ids):
            wanted[eid] = (diff, bit, ENCOUNTERS[bit][1])
    template = rows[by_id[1100]]
    for eid, (diff, bit, name) in sorted(wanted.items()):
        if eid not in by_id:
            rows.append(list(template))
            text.append([""] * 16)
            by_id[eid] = len(rows) - 1
        i = by_id[eid]
        r = rows[i]
        r[0], r[1], r[2], r[3], r[4] = eid, 819, diff, bit, bit
        text[i][0] = name
    # rebuild the string block: '\0' first, every distinct string once
    block = bytearray(b"\0")
    offs = {"": 0}
    for i, r in enumerate(rows):
        for k in range(16):
            t = text[i][k]
            if t not in offs:
                offs[t] = len(block)
                block += t.encode("utf-8") + b"\0"
            r[5 + k] = offs[t]
    out = struct.pack("<4s4I", b"WDBC", len(rows), 23, 92, len(block))
    out += b"".join(struct.pack("<23I", *r) for r in rows) + bytes(block)
    if out == data:
        print("DungeonEncounter.dbc      unchanged")
        return
    if not os.path.exists(path + ".pre-tortoise-timbermaw.bak"):
        open(path + ".pre-tortoise-timbermaw.bak", "wb").write(data)
    open(path, "wb").write(out)
    print("DungeonEncounter.dbc      %d -> %d rows, map 819 now %d rows" % (
        nrec, len(rows), sum(1 for r in rows if r[1] == 819)))

    # the CSV is stale in general, but keep its map-819 block truthful
    cpath = os.path.join(CSV_DIR, "DungeonEncounter.csv")
    lines = [ln for ln in open(cpath, "rb").read().split(b"\n") if ln]
    body = [ln if ln.endswith(b"\r") else ln + b"\r" for ln in lines if ln.split(b",")[1:2] != [b"819"]]
    for eid, (diff, bit, name) in sorted(wanted.items()):
        body.append(("%d,819,%d,%d,%d,%s,,,,,,,,,,,,,,,,16712190,0\r" % (eid, diff, bit, bit, name)).encode("utf-8"))
    open(cpath, "wb").write(b"\n".join(body) + b"\n")
    print("DungeonEncounter.csv      map 819 block rewritten (%d rows)" % len(wanted))


def main():
    plan = json.load(open(os.path.join(HERE, "client_asset_plan.json"), encoding="utf-8"))
    items = json.load(open(os.path.join(HERE, "item_dbc_rows.json"), encoding="utf-8"))
    append_rows("CreatureModelData.csv", plan["cmd_new"])
    append_rows("CreatureDisplayInfo.csv", plan["cdi_new"])
    append_rows("ItemDisplayInfo.csv", plan["idi_new"])
    item_rows = [{"ID": r[0], "ClassID": r[1], "SubclassID": r[2], "Sound_Override_Subclassid": r[3],
                  "Material": r[4], "DisplayInfoID": r[5], "InventoryType": r[6], "SheatheType": r[7]} for r in items]
    append_rows("Item.csv", item_rows)
    edit_line("Achievement.csv", b'"60049",', b"Defeat Ursoc in Timbermaw Hold.", b"Defeat Ursol in Timbermaw Hold.")
    patch_dungeon_encounter()


if __name__ == "__main__":
    main()
