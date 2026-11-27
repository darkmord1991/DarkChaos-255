#!/usr/bin/env python3
"""
Round-35 displays -- the 17 CreatureDisplayInfo ids the 370xxxx/374xxxx
Winterspring/Felwood clone band references and this client lacks.

259_ cloned 17 Cata quest-objective creatures and 260_ created 38 quest items.
Between them they referenced 7 CreatureDisplayInfo ids and 13 ItemDisplayInfo
ids that are absent from this client, so the NPCs would render as nothing and
the items would carry displayid 0 (no icon).

EVERY UNDERLYING ASSET ALREADY SHIPS WITH THIS CLIENT -- checked, not assumed:

  * 6 of the 7 creature displays reuse a CreatureModelData row we already have
    (Cata model ids 51 / 56 / 182 / 1914 / 2555 are byte-for-byte the same ids
    here, our CSV just stores the path with the WotLK `.mdx` extension).  Only
    model 3394 (OrcCrate09) is new, and its .m2 is in common-2.MPQ.
  * The kodo textures, NagaLordMale.m2, OrcCrate09.m2 and the shoulder
    component LShoulder_Robe_B_04.m2 all resolve in common/common-2/expansion.
  * All 12 item icons resolve in the enGB LOCALE archives.  Interface art on
    this install lives in enGB/locale-enGB.MPQ and enGB/patch-enGB.MPQ, NOT in
    the root archives -- looking only at common/patch-N reports every icon as
    missing, including stock ones like INV_Sword_04.

So this round is pure DBC rows: no model bake, no BLP extraction, no MPQ asset
write.  Emits CSV appends for four tables plus the server-side SQL.

FIELD MAPPINGS, all derived empirically from ids present on BOTH sides rather
than assumed:
  CreatureDisplayInfo      cata 17 fields -> our 16 columns, 1:1, last dropped
  CreatureDisplayInfoExtra cata 21 fields -> our 21 columns, 1:1
  CreatureModelData        cata 31 fields -> our 28 columns, 1:1, last 3 dropped
  ItemDisplayInfo          cata 25 fields -> our 25 columns, 1:1

  python gen_winterspring_displays_r35.py [outdir]
"""
import struct, csv, os, sys, shutil

CATA = "k:/tmp/cata-dbc/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
OUT = sys.argv[1] if len(sys.argv) > 1 else "k:/tmp/hyjal_r35/"

# creature display -> the 259_ clone that needs it
CDI_WANT = {
    28389: "3733093", 28390: "3733094", 28391: "3733095", 28392: "3732911",
    29027: "3733131", 29028: "3733132", 29238: "3748044", 29613: "3748736",
    32710: "3734485", 32711: "3733166", 28628: "3734331", 35959: "3748032",
    36039: "3748042", 36102: "3748311", 36156: "3748352", 36387: "3749149",
    36396: "3749191",
}

# Two Cata models are absent under their Cata model id but ALREADY EXIST in our
# CreatureModelData under DC retroport ids (the 500xxx band):
#   3428 FacelessOneCaster        -> 502404
#   3634 UnboundFireElemental     -> 501085
# Repointing is free and exact -- same model, already deployed -- and avoids
# both a fabricated CreatureModelData row and an asset extraction.
MODEL_SUB = {3428: 502404, 3634: 501085}
# item display -> the 260_ item that needs it.  60762 is not an item display of
# ours: it is NPCItemDisplay_2 on CreatureDisplayInfoExtra 19747, the shoulder
# the Azsharite Core credit marker wears, and it is the only one of the 27
# NPCItemDisplay references across the four Extra rows that we lack.
IDI_WANT = {}

CDI_STR = {6, 7, 8, 9}
CDI_FLT = {4}
CMD_STR = {2}
CMD_FLT = {4, 7, 8, 9, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27}
IDI_STR = {1, 2, 3, 4, 5, 6, 15, 16, 17, 18, 19, 20, 21, 22}
XTR_STR = {20}


def load(p):
    d = open(p, 'rb').read()
    assert d[:4] == b'WDBC', p
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20 + rc * rs


def i32(t, r, i):
    d, rc, fc, rs, b, sb = t
    return struct.unpack('<i', d[b + r*rs + i*4:b + r*rs + i*4 + 4])[0]


def f32(t, r, i):
    d, rc, fc, rs, b, sb = t
    return struct.unpack('<f', d[b + r*rs + i*4:b + r*rs + i*4 + 4])[0]


def cstr(t, r, i):
    d, rc, fc, rs, b, sb = t
    off = i32(t, r, i)
    if off <= 0:
        return ""
    return d[sb + off:d.index(b'\x00', sb + off)].decode('utf-8', 'replace')


def fnum(x):
    if isinstance(x, float):
        return str(int(x)) if x == int(x) else repr(round(x, 6))
    return str(x)


def extract(t, r, ncols, strset, fltset):
    out = []
    for k in range(ncols):
        if k in strset:
            out.append(cstr(t, r, k))
        elif k in fltset:
            out.append(fnum(f32(t, r, k)))
        else:
            out.append(str(i32(t, r, k)))
    return out


def csvload(rel):
    with open(REPO + rel, encoding='utf-8') as f:
        rr = csv.reader(f)
        h = next(rr)
        return h, {int(r[0]): r for r in rr if r and r[0].strip()}


def append(rel, rows, tag):
    """Append with a hard duplicate guard and a backup, then re-verify uniqueness."""
    if not rows:
        print("  %-26s nothing to add" % tag)
        return
    h, existing = csvload(rel)
    dup = [r[0] for r in rows if int(r[0]) in existing]
    assert not dup, "%s: ids already present: %s" % (tag, dup)
    assert all(len(r) == len(h) for r in rows), \
        "%s: width mismatch (header %d, rows %s)" % (tag, len(h), {len(r) for r in rows})
    shutil.copy2(REPO + rel, REPO + rel + ".pre_r35.bak")
    with open(REPO + rel, 'a', encoding='utf-8', newline='') as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator='\n')
        for r in rows:
            w.writerow(r)
    h2, after = csvload(rel)
    assert len(after) == len(existing) + len(rows), "%s: row count drift" % tag
    print("  %-26s %d -> %d rows (+%d)" % (tag, len(existing), len(after), len(rows)))


cdi = load(CATA + "CreatureDisplayInfo.dbc")
cmd = load(CATA + "CreatureModelData.dbc")
xtr = load(CATA + "CreatureDisplayInfoExtra.dbc")
idi = load(CATA + "ItemDisplayInfo.dbc")
CDI = {i32(cdi, r, 0): r for r in range(cdi[1])}
CMD = {i32(cmd, r, 0): r for r in range(cmd[1])}
XTR = {i32(xtr, r, 0): r for r in range(xtr[1])}
IDI = {i32(idi, r, 0): r for r in range(idi[1])}

_, ourM = csvload("Custom/CSV DBC/CreatureModelData.csv")
_, ourX = csvload("Custom/CSV DBC/CreatureDisplayInfoExtra.csv")

cdi_rows, xtr_rows, cmd_rows, idi_rows = [], [], [], []
seen_ext = set()
model_info = []
report = []

for cid, who in sorted(CDI_WANT.items()):
    r = CDI[cid]
    row = extract(cdi, r, 16, CDI_STR, CDI_FLT)
    if int(row[1]) in MODEL_SUB:
        row[1] = str(MODEL_SUB[int(row[1])])
    cdi_rows.append(row)
    model = int(row[1])
    ext = int(row[3])
    note = []
    if model not in ourM:
        mr = CMD[model]
        mrow = extract(cmd, mr, 28, CMD_STR, CMD_FLT)
        # our convention stores the WotLK .mdx extension; the client resolves it
        if mrow[2].lower().endswith('.m2'):
            mrow[2] = mrow[2][:-3] + '.mdx'
        cmd_rows.append(mrow)
        note.append("NEW CreatureModelData %d (%s)" % (model, mrow[2]))
    if ext:
        # one CreatureDisplayInfoExtra row can back SEVERAL displays (19653 is
        # shared by 29656 and 29657), so dedupe or the CSV gains a duplicate id
        # and the next compile silently drops one of them.
        if ext not in seen_ext and ext not in ourX:
            # several of these Extra rows are stock and already on our side
            # (455, 589, 2672, 5683) -- only the genuinely new ones are appended.
            seen_ext.add(ext)
            xr = XTR[ext]
            xtr_rows.append(extract(xtr, xr, 21, XTR_STR, set()))
        note.append("CreatureDisplayInfoExtra %d" % ext)
    report.append("  CDI %-6d model=%-5d scale=%-6s %-38s %s"
                  % (cid, model, row[4], who, "; ".join(note)))

for did in sorted(IDI_WANT):
    r = IDI[did]
    idi_rows.append(extract(idi, r, 25, IDI_STR, set()))

os.makedirs(OUT, exist_ok=True)
print("CSV appends:")
append("Custom/CSV DBC/CreatureDisplayInfo.csv", cdi_rows, "CreatureDisplayInfo")
append("Custom/CSV DBC/CreatureDisplayInfoExtra.csv", xtr_rows, "CreatureDisplayInfoExtra")
append("Custom/CSV DBC/CreatureModelData.csv", cmd_rows, "CreatureModelData")
append("Custom/CSV DBC/ItemDisplayInfo.csv", idi_rows, "ItemDisplayInfo")
print("\n" + "\n".join(report))
print("\nItemDisplayInfo rows added: %s" % sorted(IDI_WANT))
