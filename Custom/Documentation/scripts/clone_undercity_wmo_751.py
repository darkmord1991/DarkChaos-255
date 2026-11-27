#!/usr/bin/env python3
"""Clone the Undercity WMO for map 751 so it owns its areas outright.

WHY, IN ONE LINE: map 751 and map 0 were sharing one WMO, so they had to share its
WMOAreaTable rows too, and the only lever to separate them was the nameSet. Giving 751
its own copy of the building removes the sharing entirely.

WHAT CAME BEFORE THIS
    retag_undercity_area_751.py gave the shared WMO (wmoID 1150) a second nameSet -- rows
    for (1150, nameSet 2) pointing at new continent-751 areas 4940/4941, with the four
    map-751 ADT placements switched to nameSet 2. The SERVER honours that completely
    (.gps reports Zone 4940 / Area 4940, reachable only through
    GetWMOAreaTableEntryByTripple with adtId 2). The CLIENT never applied it and kept
    falling back to the terrain area 16606 "Ruins of Lordaeron".

    Every input the client reads was verified correct against the archives it actually
    reads -- ADT nameSet 2, wmoID 1150, the player's exact group (3D bbox test: gid
    6607/3221, both INTERIOR), (1150, 2, those groups) -> 4940, area 4940 on continent
    751, WorldMapArea 1275 -> 4940, dbc-verify clean, no MPQ duplicate entries, no
    phase redirect, no host cache. The data is not the problem; the client simply does
    not honour nameSet 2 on this WMO.

    Notably this WMO has nDoodadSets = 1 and stock only ever placed it with nameSet 0
    or 1 -- nameSet 2 is territory nothing in the 3.3.5 data set exercises for it.

THE FIX -- a private copy, used the ordinary way.

    world/wmo/dc/undercity751/undercity751.wmo   root wmoID 1150 -> 66901
    world/wmo/dc/undercity751/undercity751_000..215.wmo   byte-identical group copies

    and then map 751 uses **nameSet 1** -- the conventional configuration every stock
    WMO uses and the client demonstrably supports -- with its own WMOAreaTable rows keyed
    on the new root id. The nameSet-2 rows added for 1150 are removed, restoring wmoID
    1150 to its pristine stock state, so map 0's Undercity is untouched no matter what.

    Cloned from PATCH-9's copy, not stock common-2 and not our retail extract. patch-9
    ships a 216-group Cata downport that shadows common-2's 206-group stock file, and
    patch-9 is what the client actually loads today. Cloning it means map 751 keeps
    exactly the Undercity it already renders -- this change alters no visuals anywhere.

FOUR THINGS THAT WOULD EACH BREAK IT SILENTLY

  1. THE NEW PATH IS EXACTLY 42 CHARACTERS, the same as the old one. That is not
     cosmetic: MWMO is a fixed-size chunk of NUL-separated strings, and MWID holds byte
     offsets into it. A same-or-shorter path can be written in place with NUL padding,
     leaving the chunk size, MWID and every MHDR offset untouched. A longer path would
     mean rebuilding MWMO/MWID and re-patching all of MHDR.

  2. FOUR TILES CARRY THE PLACEMENT -- 30_28, 30_29, 31_28, 31_29 -- because a WMO is
     duplicated into every ADT its footprint overlaps. All four need the path and the
     nameSet, or the area changes as you walk across an invisible tile boundary.

  3. THE INTERIOR MINIMAP IS PATH-KEYED. md5translate.trs maps
     WMO\\Lorderon\\Undercity\\Undercity_NNN_XX_YY.blp to an md5 blp name, 457 entries.
     Rename the WMO and every one of those lookups misses, so the Undercity minimap goes
     black -- which currently works, so it would be a visible regression. A cloned dir
     block is appended pointing at the SAME md5 files, so the art is reused and the
     archive does not grow.

  4. THE VMAPS MUST BE RE-EXTRACTED AGAIN. The vmap stores the root WMO id, and it is
     changing from 1150 to 66901; the .vmo files are named after the WMO too. Until they
     are rebuilt the server will miss the triple and fall back to the terrain area --
     the mirror image of the client's current state.

Writes a staging tree plus the edited DBC/ADT/trs; deploys separately.
"""
import os, struct, shutil, glob

STAGE = r"K:/Dark-Chaos/retailextracts/_stage_undercity751"
SRC_ROOT = r"K:/tmp/_uwmo/p9/undercity.wmo"       # patch-9 root, extracted
SRC_GROUPS = r"K:/tmp/_ug"                         # patch-9 groups, extracted
WORK_ADT = r"K:/tmp/_uc_nameset_work"              # live tiles pulled from patch-4
TRS_IN = r"K:/tmp/_trs/md5translate.trs"
DBCD = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/DBCs"
CSVD = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC"

OLD_WMOID, NEW_WMOID = 1150, 66901
OLD_NS, NEW_NS = 2, 1                              # 751 goes back to the ordinary nameSet
OLD_PATH = "world/wmo/lorderon/undercity/undercity.wmo"
NEW_PATH = "world/wmo/dc/undercity751/undercity751.wmo"
NEW_DIR = "world/wmo/dc/undercity751"
NEW_BASE = "undercity751"
TILES = ["DCPlaguelands_30_28", "DCPlaguelands_30_29",
         "DCPlaguelands_31_28", "DCPlaguelands_31_29"]
UID = 239598
NL = chr(10)
BS = chr(92)

W_ID, W_WMOID, W_NS, W_GROUP, W_AREA = 0, 1, 2, 3, 10


def clone_wmo():
    out = os.path.join(STAGE, "World", "wmo", "dc", "undercity751")
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)

    d = bytearray(open(SRC_ROOT, "rb").read())
    o, patched = 0, False
    while o + 8 <= len(d):
        tag = bytes(d[o:o + 4])[::-1].decode("ascii", "replace")
        sz = struct.unpack_from("<I", d, o + 4)[0]
        if tag == "MOHD":
            cur = struct.unpack_from("<I", d, o + 8 + 32)[0]
            assert cur == OLD_WMOID, "root wmoID is %d, expected %d" % (cur, OLD_WMOID)
            struct.pack_into("<I", d, o + 8 + 32, NEW_WMOID)
            patched = True
            break
        o += 8 + sz
    assert patched, "no MOHD in the root"
    open(os.path.join(out, NEW_BASE + ".wmo"), "wb").write(bytes(d))

    n = 0
    for f in sorted(glob.glob(os.path.join(SRC_GROUPS, "undercity_*.wmo"))):
        idx = os.path.basename(f).split("_")[-1].split(".")[0]
        shutil.copy2(f, os.path.join(out, "%s_%s.wmo" % (NEW_BASE, idx)))
        n += 1
    print("cloned WMO: root + %d groups -> %s" % (n, out))

    chk = open(os.path.join(out, NEW_BASE + ".wmo"), "rb").read()
    o = 0
    while o + 8 <= len(chk):
        tag = chk[o:o + 4][::-1].decode("ascii", "replace")
        sz = struct.unpack_from("<I", chk, o + 4)[0]
        if tag == "MOHD":
            print("   read-back wmoID=%d nGroups=%d"
                  % (struct.unpack_from("<I", chk, o + 8 + 32)[0],
                     struct.unpack_from("<I", chk, o + 8 + 4)[0]))
            break
        o += 8 + sz
    return n


def rework_wmoareatable():
    p = os.path.join(DBCD, "WMOAreaTable.dbc")
    d = open(p, "rb").read()
    rc, fc, rs, ss = struct.unpack("<4I", d[4:20])
    sb = d[20 + rc * rs: 20 + rc * rs + ss]
    recs = [bytearray(d[20 + i * rs: 20 + (i + 1) * rs]) for i in range(rc)]

    def g(r, i):
        return struct.unpack_from("<i", r, i * 4)[0]

    ns2 = [r for r in recs if g(r, W_WMOID) == OLD_WMOID and g(r, W_NS) == 2]
    assert ns2, "no nameSet-2 rows for wmoID 1150 -- nothing to convert"
    keep = [r for r in recs if not (g(r, W_WMOID) == OLD_WMOID and g(r, W_NS) == 2)]
    print("WMOAreaTable: removing %d nameSet-2 rows for wmoID %d (restores it to stock)"
          % (len(ns2), OLD_WMOID))

    for r in keep:
        assert g(r, W_WMOID) != NEW_WMOID, "wmoID %d already in use" % NEW_WMOID

    nextid = max(struct.unpack_from("<I", r, 0)[0] for r in keep) + 1
    added = []
    for r in ns2:
        n = bytearray(r)
        struct.pack_into("<I", n, 0, nextid); nextid += 1
        struct.pack_into("<i", n, W_WMOID * 4, NEW_WMOID)
        struct.pack_into("<i", n, W_NS * 4, NEW_NS)
        added.append(n)
    out = keep + added
    open(p, "wb").write(b"WDBC" + struct.pack("<4I", len(out), fc, rs, len(sb))
                        + b"".join(bytes(r) for r in out) + sb)
    print("WMOAreaTable.dbc: %d -> %d records (+%d rows on wmoID %d nameSet %d)"
          % (rc, len(out), len(added), NEW_WMOID, NEW_NS))

    import csv, io
    c = os.path.join(CSVD, "WMOAreaTable.csv")
    with open(c, encoding="utf-8", newline="") as fh:
        r = csv.reader(fh); hdr = next(r)
        rows = [x for x in r if x and x[0].strip() != ""]
    ci = {n: i for i, n in enumerate(hdr)}
    cid, cw, cns = ci["ID"], ci["WMOID"], ci["NameSetID"]
    conv = [x for x in rows if int(x[cw]) == OLD_WMOID and int(x[cns]) == 2]
    rows = [x for x in rows if not (int(x[cw]) == OLD_WMOID and int(x[cns]) == 2)]
    nid = max(int(x[cid]) for x in rows) + 1
    for x in conv:
        y = list(x); y[cid] = str(nid); nid += 1
        y[cw] = str(NEW_WMOID); y[cns] = str(NEW_NS)
        rows.append(y)
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=NL, quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    open(c, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("WMOAreaTable.csv: %d rows" % len(rows))
    return len(added)


def repoint_adts():
    oldb, newb = OLD_PATH.encode("ascii"), NEW_PATH.encode("ascii")
    assert len(newb) <= len(oldb), "new path is longer -- MWMO cannot be patched in place"
    for t in TILES:
        p = os.path.join(WORK_ADT, t + ".adt")
        d = bytearray(open(p, "rb").read())
        o, ch = 0, {}
        while o + 8 <= len(d):
            tag = bytes(d[o:o + 4])[::-1].decode("ascii", "replace")
            sz = struct.unpack_from("<I", d, o + 4)[0]
            ch.setdefault(tag, (o + 8, sz))
            if tag == "MCNK":
                break
            o += 8 + sz
        mo, msz = ch["MWMO"]
        blob = bytes(d[mo:mo + msz])
        i = blob.lower().find(oldb)
        assert i >= 0, "old WMO path not found in %s" % t
        # overwrite in place, NUL-terminate, NUL-pad the rest of the old string's span
        d[mo + i: mo + i + len(oldb)] = newb + b"\0" * (len(oldb) - len(newb))
        # nameSet back to the ordinary 1
        fo, fsz = ch["MODF"]
        names = [x.decode("utf-8", "replace") for x in blob.split(b"\0") if x]
        hit = 0
        for k in range(fsz // 64):
            b = fo + k * 64
            nid, uid = struct.unpack_from("<II", d, b)
            if uid != UID:
                continue
            struct.pack_into("<H", d, b + 0x3C, NEW_NS)
            hit += 1
        assert hit == 1, "%s: expected 1 placement, got %d" % (t, hit)
        bak = p + ".pre-clone.bak"
        if not os.path.exists(bak):
            shutil.copy2(p, bak)
        open(p, "wb").write(bytes(d))
        print("   %-24s MWMO -> %s, nameSet -> %d" % (t, NEW_PATH, NEW_NS))


def clone_trs():
    txt = open(TRS_IN, encoding="utf-8", errors="replace").read()
    crlf = txt.count(chr(13) + NL) > txt.count(NL) / 2
    eol = (chr(13) + NL) if crlf else NL
    lines = txt.replace(chr(13) + NL, NL).split(NL)
    marker = "dir: WMO" + BS + "Lorderon" + BS + "Undercity"
    try:
        s = lines.index(marker)
    except ValueError:
        raise SystemExit("Undercity dir block not found in the trs")
    e = s + 1
    while e < len(lines) and not lines[e].startswith("dir: ") and lines[e].strip():
        e += 1
    block = lines[s + 1:e]
    newdir = "dir: WMO" + BS + "dc" + BS + "undercity751"
    if newdir in lines:
        print("   trs already has the clone block, skipping")
        return 0
    out = [newdir]
    # The block MIXES separators: 228 entries use backslashes and 228 use forward
    # slashes, both pointing at the same md5 files. Rewrite each entry in its OWN
    # style so the clone reproduces the duplication exactly rather than collapsing it.
    n = 0
    for l in block:
        if chr(9) not in l:
            continue
        name, md5 = l.split(chr(9), 1)
        for sep in (BS, "/"):
            oldpfx = sep.join(["WMO", "Lorderon", "Undercity", "Undercity"])
            if name.startswith(oldpfx):
                newpfx = sep.join(["WMO", "dc", "undercity751", "Undercity751"])
                out.append(newpfx + name[len(oldpfx):] + chr(9) + md5)
                n += 1
                break
        else:
            raise SystemExit("unexpected trs entry %r" % name)
    body = lines[:] + out
    open(os.path.join(STAGE, "md5translate.trs"), "w", encoding="utf-8",
         newline="").write(eol.join(body) + eol)
    print("md5translate.trs: cloned %d minimap entries into %r (same md5 targets)" % (n, newdir))
    return n


if __name__ == "__main__":
    ng = clone_wmo()
    rework_wmoareatable()
    repoint_adts()
    clone_trs()
    print()
    print("staged in %s" % STAGE)
    print("REMINDER: map 751 vmaps must be re-extracted -- the root WMO id changed to %d"
          % NEW_WMOID)
