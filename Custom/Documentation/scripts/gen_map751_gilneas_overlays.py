#!/usr/bin/env python3
"""gen_map751_gilneas_overlays.py - give map-751 "Ruins of Gilneas" (WMA 1274) its exploration paint.

Ruins of Gilneas was the one map-751 zone left out of the 2026-08-20 WorldMapOverlay clone pass
(build_overlays2.py covered only the 7 zones whose art folders exist in stock WotLK). The
assumption at the time was that its custom art needed no overlays; it was wrong. Our
Interface\\WorldMap\\RuinsofGilneas\\ folder holds ONLY the 12 base tiles - and the base tiles are
the *unexplored* skeleton. Every detail (towns, roads, forests, labels) lives in the overlay art,
which was never downported, so the zone map renders blank parchment forever no matter what the
server has flagged as explored.

Cata does not paint this zone piece-by-piece like a vanilla zone: WMA 684's overlays are five rows
that all point at one full-window 1002x668 texture set, GilneasPuzzle1..12.blp, plus three
texture-less hit-rect rows. Our WMA 1274 rect is identical to Cata's WMA 684 rect and our base
tiles are byte-identical to Cata's, so the geometry transfers 1:1 - areas are the only remap.

Inputs: Cata AreaTable.dbc + WorldMapOverlay.dbc extracted to <catadbc> (see --catadbc), and the
Cata locale MPQ for the art.

What this writes:
  - Custom/CSV DBC/WorldMapOverlay.csv  (+N rows from FIRST_ID)
  - Custom/DBCs/WorldMapOverlay.dbc     (appended in place; existing records untouched)
  - <out>/Interface/WorldMap/RuinsofGilneas/GilneasPuzzle{1..12}.blp  staging tree for the art

Deploy afterwards: the BLPs via dc_mpq_deploy.py (dest_for -> patch-5), the DBC to patch-4 +
enGB/patch-enGB-3 + the WXL candidate dir K:/Dark-Chaos/Custom/DBCs.
"""
import argparse
import csv
import io
import os
import struct
import sys

BS = chr(92)
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/Custom"
CATA_LOCALE = "K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ"

OUR_WMA = 1274        # map 751 "RuinsofGilneas"
CATA_WMA = 684        # map 0 "RuinsofGilneas"
OUR_ZONE = 4939       # our Ruins of Gilneas zone area id
CATA_ZONE = 4706      # cata Ruins of Gilneas zone area id
FIRST_ID = 4400       # 4100-4172 = map 750, 4200-4308 = map 751's other 7 zones


def load_dbc(path):
    d = open(path, 'rb').read()
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    sb = 20 + rc * rs

    def s(o):
        if o <= 0 or sb + o >= len(d):
            return ""
        e = d.find(b'\0', sb + o)
        return d[sb + o:e].decode('utf-8', 'replace')

    rows = [[struct.unpack_from('<i', d, 20 + i * rs + k * 4)[0] for k in range(fc)] for i in range(rc)]
    return rows, s


def mpq_grab(archive, name):
    """Read one file out of an MPQ. Archive-open success is judged by the OUT HANDLE, file-open by
    get_last_error() - SFileOpen*'s BOOL return is unreliable through ctypes (see
    mpq_stormlib_locate.py)."""
    import ctypes
    from ctypes import wintypes
    dll = ctypes.WinDLL(r"K:\Dark-Chaos\Release2.3.01\x64\StormLib.dll", use_last_error=True)
    dll.SFileOpenArchive.argtypes = [ctypes.c_wchar_p, wintypes.DWORD, wintypes.DWORD,
                                     ctypes.POINTER(ctypes.c_void_p)]
    dll.SFileOpenFileEx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, wintypes.DWORD,
                                    ctypes.POINTER(ctypes.c_void_p)]
    dll.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    dll.SFileGetFileSize.restype = wintypes.DWORD
    dll.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                  ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    h = ctypes.c_void_p()
    dll.SFileOpenArchive(archive, 0, 0x100, ctypes.byref(h))
    if not h:
        return None
    fh = ctypes.c_void_p()
    ctypes.set_last_error(0)
    dll.SFileOpenFileEx(h, name.encode(), 0, ctypes.byref(fh))
    data = None
    if ctypes.get_last_error() == 0 and fh:
        sz = dll.SFileGetFileSize(fh, None)
        buf = ctypes.create_string_buffer(sz)
        rd = wintypes.DWORD()
        dll.SFileReadFile(fh, buf, sz, ctypes.byref(rd), None)
        dll.SFileCloseFile(fh)
        data = buf.raw[:rd.value]
    dll.SFileCloseArchive(h)
    return data


def build_rows(catadbc, verbose=True):
    """Clone Cata's WMA-684 overlay rows onto our WMA 1274, remapping areas by NAME.

    Cata WorldMapOverlay is 15 fields; ours is 17 - Cata dropped MapPointX/MapPointY (0 in every
    3.3.5 row anyway), so the insert point is right before TextureName."""
    cat, cs = load_dbc(os.path.join(catadbc, "AreaTable.dbc"))
    cov, covs = load_dbc(os.path.join(catadbc, "WorldMapOverlay.dbc"))
    ours, os_s = load_dbc(REPO + "/DBCs/AreaTable.dbc")

    cata_name = {r[0]: cs(r[11]) for r in cat}
    ours_by_name = {}
    for r in ours:
        if r[1] == 751 and (r[0] == OUR_ZONE or r[2] == OUR_ZONE):
            ours_by_name.setdefault(os_s(r[11]), r[0])

    def remap(cata_area):
        if cata_area == 0:
            return 0
        if cata_area == CATA_ZONE:
            return OUR_ZONE
        return ours_by_name.get(cata_name.get(cata_area, ""), None)

    out, skipped = [], []
    next_id = FIRST_ID
    for r in cov:
        if r[1] != CATA_WMA:
            continue
        areas = [remap(a) for a in r[2:6]]
        if any(a is None for a in areas):
            skipped.append((r[0], [cata_name.get(a, a) for a in r[2:6] if remap(a) is None]))
            continue
        if not any(areas):
            continue
        # [ID, MapAreaID, A1..A4, MapPointX, MapPointY, TextureName, W, H, OffX, OffY, T, L, B, R]
        out.append([next_id, OUR_WMA] + areas + [0, 0, covs(r[6])] + r[7:])
        next_id += 1
    if verbose:
        print("cloned %d overlay rows (ids %d-%d)" % (len(out), FIRST_ID, next_id - 1))
        for oid, names in skipped:
            print("  SKIPPED cata overlay %d - no map-751 area named %r" % (oid, names))
    return out


def append_csv(rows):
    p = REPO + "/CSV DBC/WorldMapOverlay.csv"
    with open(p, encoding="utf-8", newline="") as fh:
        rr = csv.reader(fh)
        hdr = next(rr)
        have = [x for x in rr if x and x[0].strip() != ""]
    existing = {x[0].strip('"') for x in have}
    for r in rows:
        if str(r[0]) in existing:
            sys.exit("id %s already in WorldMapOverlay.csv - pick a different FIRST_ID" % r[0])
        have.append([str(v) for v in r])
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=chr(10), quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in have:
        w.writerow(x)
    open(p, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("WorldMapOverlay.csv: %d rows" % len(have))


def append_dbc(rows):
    p = REPO + "/DBCs/WorldMapOverlay.dbc"
    d = open(p, 'rb').read()
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    assert (fc, rs) == (17, 68), (fc, rs)
    base, sb = 20, 20 + rc * rs
    recs = bytearray(d[base:sb])
    strb = bytearray(d[sb:sb + ss])
    seen, off = {}, 0
    while off < len(strb):
        e = strb.find(b'\0', off)
        if e < 0:
            break
        seen.setdefault(strb[off:e].decode('utf-8', 'replace'), off)
        off = e + 1
    seen[""] = 0

    def addstr(t):
        if t in seen:
            return seen[t]
        o = len(strb)
        strb.extend(t.encode('utf-8') + b'\0')
        seen[t] = o
        return o

    for r in rows:
        rec = bytearray()
        for k, v in enumerate(r):
            rec += struct.pack('<I', addstr(v) if k == 8 else (int(v) & 0xFFFFFFFF))
        assert len(rec) == rs
        recs += rec
    out = b'WDBC' + struct.pack('<4I', rc + len(rows), fc, rs, len(strb)) + bytes(recs) + bytes(strb)
    open(p, 'wb').write(out)
    print("WorldMapOverlay.dbc: %d -> %d records" % (rc, rc + len(rows)))


def stage_art(outdir):
    """Pull GilneasPuzzle1..12.blp out of the Cata client into an in-archive-shaped staging tree."""
    dest = os.path.join(outdir, "Interface", "WorldMap", "RuinsofGilneas")
    os.makedirs(dest, exist_ok=True)
    n = 0
    for i in range(1, 13):
        name = "GilneasPuzzle%d.blp" % i
        d = mpq_grab(CATA_LOCALE, "Interface" + BS + "WorldMap" + BS + "RuinsOfGilneas" + BS + name)
        if d is None:
            sys.exit("missing %s in %s" % (name, CATA_LOCALE))
        if d[:4] != b'BLP2':
            sys.exit("%s is not BLP2 (%r)" % (name, d[:4]))
        open(os.path.join(dest, name), 'wb').write(d)
        n += 1
    print("staged %d BLPs -> %s" % (n, dest))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--catadbc", default="k:/tmp/catadbc",
                    help="dir holding AreaTable.dbc + WorldMapOverlay.dbc extracted from the Cata client")
    ap.add_argument("--out", default="k:/tmp/gilneas_overlay_stage", help="staging tree for the art")
    ap.add_argument("--dry-run", action="store_true", help="print the rows, write nothing")
    a = ap.parse_args()
    rows = build_rows(a.catadbc)
    for r in rows:
        print("  ", r)
    if a.dry_run:
        return
    append_csv(rows)
    append_dbc(rows)
    stage_art(a.out)


if __name__ == "__main__":
    main()
