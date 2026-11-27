"""Insert one GameObjectDisplayInfo record into the binary DBC without
rebuilding it from CSV.

Rebuilding from Custom/CSV DBC/GameObjectDisplayInfo.csv is *almost* lossless --
46,928 ids in, 46,928 out -- but six rows (9140, 9141, 9146, 9375, 9376, 10014)
carry GeoBox floats with more precision than the CSV's ~6 significant digits, so
they drift by ~4e-6 on every round trip. Harmless, but pointless: appending to
the binary leaves every existing byte exactly where it was.

Same discipline as spell-dbc-append.py.
"""
import struct
import shutil
import os
import sys

SRC = "K:/Dark-Chaos/DarkChaos-255-Master/Custom/DBCs/GameObjectDisplayInfo.dbc"
BAK = "k:/tmp/r41_items/GODI.pre-r41.bak"

NEW_ID = 9901
NEW_MODEL = r"world\generic\human\passive doodads\books\book_dwarf_darkiron_02.mdx"
# sounds[10], geobox min xyz / max xyz, ObjectEffectPackageID -- all zero,
# matching every other Book_<race>_NN display in stock 3.3.5.
NEW_TAIL = [0] * 10 + [0.0] * 6 + [0]

DO = "--apply" in sys.argv

d = open(SRC, "rb").read()
magic, rc, fc, rs, sb = struct.unpack("<4sIIII", d[:20])
assert magic == b"WDBC" and fc == 19 and rs == 76, (magic, fc, rs)
recs_off = 20
str_off = 20 + rc * rs
assert str_off + sb == len(d), "trailing bytes"

ids = [struct.unpack("<i", d[recs_off + i * rs: recs_off + i * rs + 4])[0] for i in range(rc)]
sorted_by_id = all(ids[i] <= ids[i + 1] for i in range(len(ids) - 1))
print("records=%d fields=%d rowsize=%d stringblock=%d sorted_by_id=%s"
      % (rc, fc, rs, sb, sorted_by_id))
assert NEW_ID not in ids, "id already present"

# new string goes at the end of the existing string block
new_str = NEW_MODEL.encode("utf-8") + b"\0"
name_off = sb
strings = d[str_off:] + new_str

rec = struct.pack("<2i", NEW_ID, name_off) \
    + struct.pack("<10i", *NEW_TAIL[:10]) \
    + struct.pack("<6f", *NEW_TAIL[10:16]) \
    + struct.pack("<i", NEW_TAIL[16])
assert len(rec) == rs

records = d[recs_off:str_off]
if sorted_by_id:
    pos = sum(1 for i in ids if i < NEW_ID)          # keep the file ordered
    records = records[:pos * rs] + rec + records[pos * rs:]
    print("inserted at record index %d (keeps id order)" % pos)
else:
    records = records + rec
    print("appended at the end (file was not id-ordered)")

out = struct.pack("<4sIIII", magic, rc + 1, fc, rs, len(strings)) + records + strings

if not DO:
    print("\n(dry run -- pass --apply to write; would be %d bytes, was %d)"
          % (len(out), len(d)))
    raise SystemExit(0)

if not os.path.exists(BAK):
    shutil.copy2(SRC, BAK)
    print("backup ->", BAK)
open(SRC, "wb").write(out)
print("wrote %s: %d -> %d records, %d -> %d bytes" % (SRC, rc, rc + 1, len(d), len(out)))
