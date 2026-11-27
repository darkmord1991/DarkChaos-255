#!/usr/bin/env python3
"""Retag map 751's Undercity WMO placement from nameSet 1 to nameSet 2.

Companion to retag_undercity_area_751.py, which added the nameSet-2 WMOAreaTable
rows and the continent-751 AreaTable rows they point at. This is the other half:
the placement in the terrain has to actually ASK for nameSet 2, or the client and
server keep looking up nameSet 1 and keep resolving map 0's area 1497.

The edit is two bytes per placement -- MODF field NameSet at offset 0x3C of the
64-byte entry -- but it has to hit FOUR tiles, not one. A WMO is duplicated into
every ADT its footprint overlaps, and Undercity spans:

    DCPlaguelands_30_28   DCPlaguelands_30_29
    DCPlaguelands_31_28   DCPlaguelands_31_29

all carrying the same placement, uid 239598. Missing one would leave part of the
building resolving to the old area, which is worse than not doing it at all
because the boundary would be invisible and position-dependent.

The placement is matched on uid AND on the MWMO name containing "undercity", not
on index, so a tile with several WMOs cannot be mis-hit. Tiles are only written
if every expected placement was found and changed; a partial pass aborts.

THE MPQ IS AUTHORITATIVE HERE, NOT THE STAGING TREE. They are the same byte SIZE,
which makes them look interchangeable, but they are not: the deployed tiles have had
a subzone retag pass applied that staging never received.

    DCPlaguelands_31_29   staging  areas {4933: 110, 4935: 103, 4936: 43}
                          in-MPQ   areas {16606: 110, 16705: 42, 16641: 43, ...}

Re-packing staging into patch-4 would silently revert every subzone on four tiles.
So this extracts the live tiles from patch-4, edits those, and writes them back. The
staging copies get the same two-byte edit applied in place so a future rebake from
staging still asks for nameSet 2 -- but staging is never pushed to the archive.

Incidentally, that stale-staging difference is also what confirmed the diagnosis:
the deployed terrain under Undercity is tagged 16606 "Ruins of Lordaeron", which is
exactly the name that was showing instead of Undercity.

AFTER THIS, RE-EXTRACT MAP 751'S VMAPS. vmap4_extractor writes MODF.NameSet into
the vmap dir file (wmo.cpp:584) and the server resolves areas through
GetWMOAreaTableEntryByTripple(rootId, adtId, groupId) with adtId being that
nameSet. Until the vmaps are rebuilt the server misses the lookup and falls back
to the terrain area, so it will disagree with the client about where the player is.
"""
import os, struct, shutil, subprocess, sys

STAGE = r"K:/Dark-Chaos/retailextracts/_stage_dcplaguelands_ext/World/Maps/DCPlaguelands"
MPQ = r"K:/WoW_3.3.5a_ 255 Fun/Data/patch-4.MPQ"
TOOLS = r"K:/Dark-Chaos/wow.export-main/tools"
WORK = r"K:/tmp/_uc_nameset_work"
BS = chr(92)

TILES = ["DCPlaguelands_30_28", "DCPlaguelands_30_29",
         "DCPlaguelands_31_28", "DCPlaguelands_31_29"]
UID = 239598
OLD_NS, NEW_NS = 1, 2
MODF_NAMESET_OFS = 0x3C


def chunks(d):
    out = {}
    o = 0
    while o + 8 <= len(d):
        tag = d[o:o + 4][::-1].decode("ascii", "replace")
        sz = struct.unpack_from("<I", d, o + 4)[0]
        out.setdefault(tag, (o + 8, sz))
        if tag == "MCNK":
            break
        o += 8 + sz
    return out


def patch(path, dry):
    d = bytearray(open(path, "rb").read())
    ch = chunks(d)
    mo, msz = ch["MWMO"]
    names = [x.decode("utf-8", "replace") for x in bytes(d[mo:mo + msz]).split(b"\0") if x]
    fo, fsz = ch["MODF"]
    n = fsz // 64
    changed = 0
    for i in range(n):
        b = fo + i * 64
        nameId, uid = struct.unpack_from("<II", d, b)
        ns = struct.unpack_from("<H", d, b + MODF_NAMESET_OFS)[0]
        if uid != UID:
            continue
        if "undercity" not in names[nameId].lower():
            continue
        if ns == NEW_NS:
            print("      already nameSet %d, skipping" % NEW_NS)
            continue
        assert ns == OLD_NS, "unexpected nameSet %d in %s" % (ns, path)
        if not dry:
            struct.pack_into("<H", d, b + MODF_NAMESET_OFS, NEW_NS)
        changed += 1
    if changed and not dry:
        bak = path + ".pre-uc-nameset.bak"
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        open(path, "wb").write(bytes(d))
    return changed


def extract_live():
    """Pull the authoritative tiles out of patch-4 into a scratch dir."""
    if os.path.isdir(WORK):
        shutil.rmtree(WORK)
    os.makedirs(WORK)
    args = []
    for t in TILES:
        args += ["--file", "World%sMaps%sDCPlaguelands%s%s.adt" % (BS, BS, BS, t)]
    r = subprocess.run([sys.executable, os.path.join(TOOLS, "mpq_stormlib_extract.py"),
                        "--mpq", MPQ, "--out", WORK] + args,
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-800:], r.stderr[-800:])
        raise SystemExit("extract failed")
    for t in TILES:
        assert os.path.exists(os.path.join(WORK, t + ".adt")), "not extracted: " + t


def main():
    dry = "--dry-run" in sys.argv
    extract_live()

    total = 0
    for t in TILES:
        c = patch(os.path.join(WORK, t + ".adt"), dry)
        print("   %-24s (live)    placements changed: %d" % (t, c))
        total += c
    print("total placements retagged in the live tiles: %d (expected 4)" % total)
    assert total == 4 or dry, "expected exactly 4 placements, got %d" % total

    # the same edit into staging, so a rebake from there keeps it -- never pushed
    for t in TILES:
        p = os.path.join(STAGE, t + ".adt")
        if os.path.exists(p):
            c = patch(p, dry)
            print("   %-24s (staging) placements changed: %d" % (t, c))

    # read-back against the live tiles
    for t in TILES:
        d = open(os.path.join(WORK, t + ".adt"), "rb").read()
        ch = chunks(d)
        mo, msz = ch["MWMO"]
        names = [x.decode("utf-8", "replace") for x in d[mo:mo + msz].split(b"\0") if x]
        fo, fsz = ch["MODF"]
        for i in range(fsz // 64):
            b = fo + i * 64
            nameId, uid = struct.unpack_from("<II", d, b)
            if uid == UID and "undercity" in names[nameId].lower():
                ns = struct.unpack_from("<H", d, b + MODF_NAMESET_OFS)[0]
                print("   verify %-24s uid=%d nameSet=%d" % (t, uid, ns))
                assert dry or ns == NEW_NS

    if dry:
        print("dry run, nothing written")
        return

    sets = []
    for t in TILES:
        sets += ["--set", "%s=World%sMaps%sDCPlaguelands%s%s.adt"
                 % (os.path.join(WORK, t + ".adt"), BS, BS, BS, t)]
    cmd = [sys.executable, os.path.join(TOOLS, "mpq_stormlib_patch.py"),
           "--mpq", MPQ, "--no-backup"] + sets
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout[-1200:])
    if r.returncode != 0:
        print(r.stderr[-1200:])
        raise SystemExit("MPQ patch failed")


main()
