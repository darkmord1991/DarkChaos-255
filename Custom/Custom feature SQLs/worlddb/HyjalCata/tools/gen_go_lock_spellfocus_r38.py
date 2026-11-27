#!/usr/bin/env python3
"""Round-38: the 9 Lock.dbc + 13 SpellFocusObject.dbc rows map-750 gameobjects need.

Appends to Custom/CSV DBC/Lock.csv and SpellFocusObject.csv from the Cata 4.3.4
client.  Both live in enUS/locale-enUS.MPQ, NOT in the wow-update-base archives
where Spell.dbc came from -- same placement as Vehicle.dbc.

Lock is a straight copy: 33 fields / 132-byte records on BOTH sides, so field i
maps to field i with no transform.

SpellFocusObject is not: Cata collapsed the 16-locale name array to a single
string, so its table is 2 fields / 8 bytes against this client's 18 / 72.
Mapping is ID -> col 0, Name -> Name_Lang_enUS, and Name_Lang_Mask -> 16712190
(the value every existing row in the CSV carries).
"""
import struct, csv, shutil

LOC = "k:/tmp/cata-locale/"
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/"
NAME_MASK = "16712190"

LOCKS = [1821, 1822, 1826, 1835, 1843, 1874, 1923, 1939, 1963]
FOCUS = [1595, 1609, 1611, 1623, 1633, 1634, 1635, 1651, 1656, 1658, 1659,
         1661, 1662]


def load(p):
    with open(p, 'rb') as f:
        d = f.read()
    assert d[:4] == b'WDBC', p
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20 + rc * rs


def gi(t, r, i):
    d, rc, fc, rs, b, sb = t
    return struct.unpack('<i', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]


def cstr(t, r, i):
    d, rc, fc, rs, b, sb = t
    o = gi(t, r, i)
    return "" if o <= 0 else d[sb + o:d.index(b'\x00', sb + o)].decode('utf-8', 'replace')


def append(rel, rows, want, tag):
    path = REPO + rel
    with open(path, encoding='utf-8') as f:
        rr = csv.reader(f)
        hdr = [c.lstrip('\ufeff') for c in next(rr)]
        existing = {int(r[0]) for r in rr if r and r[0].strip()}
    dup = sorted(set(want) & existing)
    assert not dup, "%s already in CSV: %s" % (tag, dup)
    for r in rows:
        assert len(r) == len(hdr), (tag, len(r), len(hdr))
    shutil.copy2(path, path + ".pre_r38.bak")
    with open(path, 'a', encoding='utf-8', newline='') as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator='\n')
        for r in rows:
            w.writerow(r)
    ids = []
    with open(path, encoding='utf-8') as f:
        rr = csv.reader(f)
        next(rr)
        for r in rr:
            if r and r[0].strip():
                ids.append(int(r[0]))
    assert len(ids) == len(set(ids)), "%s DUPLICATE IDS" % tag
    print("%-22s %d -> %d (+%d), all unique" % (rel.split('/')[-1], len(ids) - len(rows), len(ids), len(rows)))


# --- Lock: 33 -> 33, direct ------------------------------------------------
L = load(LOC + "Lock.dbc")
assert L[2] == 33 and L[3] == 132, (L[2], L[3])
li = {gi(L, r, 0): r for r in range(L[1])}
lock_rows = []
LT = {1: 'ITEM', 2: 'SKILL', 3: 'SPELL'}
for i in LOCKS:
    r = li[i]
    row = [str(gi(L, r, k)) for k in range(33)]
    lock_rows.append(row)
    slots = ["slot%d %s=%d" % (s + 1, LT.get(gi(L, r, 1 + s), '?'), gi(L, r, 9 + s))
             for s in range(8) if gi(L, r, 1 + s)]
    print("  Lock %-5d %s" % (i, "; ".join(slots)))
append("Custom/CSV DBC/Lock.csv", lock_rows, LOCKS, "Lock")

# --- SpellFocusObject: 2 -> 18 ---------------------------------------------
S = load(LOC + "SpellFocusObject.dbc")
assert S[2] == 2, S[2]
si = {gi(S, r, 0): r for r in range(S[1])}
focus_rows = []
for i in FOCUS:
    r = si[i]
    name = cstr(S, r, 1)
    focus_rows.append([str(i), name] + [""] * 15 + [NAME_MASK])
    print("  SpellFocusObject %-5d %s" % (i, name))
append("Custom/CSV DBC/SpellFocusObject.csv", focus_rows, FOCUS, "SpellFocusObject")
