#!/usr/bin/env python3
"""Phase 2 of the map-751 subzone retag: mint the AreaTable rows and retag the ADTs.

Map 751 shipped with 8 AreaTable rows -- the zones -- and NO subzones, so the whole
continent was 8 discoverable areas with no sub-area names anywhere. Map 750 has 204.
(WorldMapOverlay is a red herring: map 750 has zero overlay rows too.)

Source of truth is Cata's `World\\Maps\\Azeroth\\Azeroth_<x>_<y>.adt`, which is
coordinate-aligned with our `DCPlaguelands_<x>_<y>.adt` -- same tile coords, same
16x16 MCNK grid in the same order -- so chunk index i maps 1:1. Phase 1
(`scratchpad/subzone_plan.py`) produced subzone_plan.json from that.

Row construction, per subzone:
  * TECHNICAL fields (Flags, sound prefs, ambience, music, liquid, elevation,
    faction mask, light) are cloned from OUR AreaTable row for the same id when we
    already have one -- 161 of 215 are stock EK subzones, and their WotLK values are
    known-good. The other 54 are Cata-new and take their values from the Cata client.
  * The NAME always comes from CATA, even for the 161. Our terrain is the Cata-era
    Lordaeron, and 10 of these were renamed by the Shattering -- stock "Southshore"
    is Cata "Ruins of Southshore", stock "Hillsbrad Fields" is "The Sludge Fields".
    Using the stock name there would label the new terrain wrongly.
  * ParentAreaID is OUR zone id (the most common one across that subzone's chunks),
    not Cata's parent, so the result stays consistent with the zone split already
    shipped.

AreaBits come from the free pool below 4095 (`PLAYER_EXPLORED_ZONES_1` is 128
uint32 = 4096 bits; a bit at or above that can never be recorded). 215 needed,
1,047 free.

Writes: Custom/CSV DBC/AreaTable.csv (+215 rows) and repaired ADTs into
<scratch>/subzone_out plus a pack list. Deploy the ADTs and AreaTable.dbc together.
"""
import ctypes, os, sys, glob, struct, json, csv, shutil, collections
from ctypes import wintypes

sys.path.insert(0, r"K:/Dark-Chaos/wow.export-main/tools")
from mpq_stormlib_locate import load, open_archive

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.environ.get("SCRATCH", "")
CSVDIR = os.path.normpath(os.path.join(HERE, "..", "..", "CSV DBC"))
CATA = r"K:/UntouchedClients/Cata/Data"
DC = r"K:/WoW_3.3.5a_ 255 Fun/Data"
OUT = os.path.join(SP, "subzone_out")
NEW_ID_START = 16604
NAME_MASK = "16712190"


def mk(dll, pats, skip=()):
    H = []
    for p in pats:
        for a in sorted(glob.glob(p)):
            if any(s in os.path.basename(a).lower() for s in skip):
                continue
            h = open_archive(dll, a)
            if h:
                H.append((os.path.basename(a), h))

    def read(path):
        for _, h in reversed(H):
            fh = ctypes.c_void_p()
            ctypes.set_last_error(0)
            dll.SFileOpenFileEx(h, path.encode("utf-8"), 0, ctypes.byref(fh))
            if ctypes.get_last_error() != 0 or not fh:
                continue
            sz = dll.SFileGetFileSize(fh, None)
            raw = None
            if sz and sz != 0xFFFFFFFF:
                buf = ctypes.create_string_buffer(sz)
                got = wintypes.DWORD(0)
                dll.SFileReadFile(fh, buf, sz, ctypes.byref(got), None)
                raw = buf.raw[:got.value]
            dll.SFileCloseFile(fh)
            if raw is not None:
                return raw
        return None
    return read


def mcnk_offsets(data):
    """Byte offsets of each MCNK's area-id field, in file order."""
    out, pos = [], 0
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4][::-1].decode("ascii", "replace")
        size = struct.unpack_from("<I", data, pos + 4)[0]
        if tag == "MCNK":
            out.append(pos + 8 + 0x34)
        pos += 8 + size            # never break on size 0 -- that truncates the walk
    return out


def main():
    plan = json.load(open(os.path.join(SP, "subzone_plan.json")))
    sub = {int(k): v for k, v in plan["subzones"].items()}

    rows = list(csv.DictReader(open(os.path.join(CSVDIR, "AreaTable.csv"), encoding="utf-8-sig")))
    hdr = list(rows[0].keys())
    ours = {int(r["ID"]): r for r in rows}
    used_bits = {int(r["AreaBit"]) for r in rows if r["AreaBit"] not in ("", "-1")}
    used_ids = {int(r["ID"]) for r in rows}
    free_bits = [b for b in range(1, 4096) if b not in used_bits]
    if len(free_bits) < len(sub):
        raise SystemExit("ABORT: need %d AreaBits, only %d free below 4095" % (len(sub), len(free_bits)))

    nid = NEW_ID_START
    while nid in used_ids:
        nid += 1

    newrows, idmap, cloned, fresh = [], {}, 0, 0
    for cata_id in sorted(sub):
        v = sub[cata_id]
        src = ours.get(cata_id)
        rec = {c: "0" for c in hdr}
        if src:
            rec.update({c: src[c] for c in hdr})
            cloned += 1
        else:
            rec["Flags"] = str(v["flags"])
            rec["AmbienceID"] = str(v["ambience"])
            rec["ZoneMusic"] = str(v["zonemusic"])
            rec["IntroSound"] = str(v["introsound"])
            rec["ExplorationLevel"] = str(v["explevel"])
            rec["SoundProviderPrefUnderwater"] = "11"
            rec["MinElevation"] = "-500"
            fresh += 1
        rec["ID"] = str(nid)
        rec["ContinentID"] = "751"
        rec["ParentAreaID"] = str(v["parent_zone"])
        rec["AreaBit"] = str(free_bits.pop(0))
        rec["AreaName_Lang_enUS"] = v["name"]          # Cata name wins -- see docstring
        for c in hdr:
            if c.startswith("AreaName_Lang_") and c not in ("AreaName_Lang_enUS", "AreaName_Lang_Mask"):
                rec[c] = ""
        rec["AreaName_Lang_Mask"] = NAME_MASK
        newrows.append([rec[c] for c in hdr])
        idmap[cata_id] = nid
        nid += 1
        while nid in used_ids:
            nid += 1

    print("subzone rows: %d (cloned from our stock row %d, built from cata %d)" % (len(newrows), cloned, fresh))
    print("AreaBits %s..%s ; ids %d..%d" % (newrows[0][hdr.index("AreaBit")], newrows[-1][hdr.index("AreaBit")],
                                            int(newrows[0][0]), int(newrows[-1][0])))

    # ---- append the CSV ---------------------------------------------------
    path = os.path.join(CSVDIR, "AreaTable.csv")
    text = open(path, "rb").read().decode("utf-8-sig")
    lines = [ln for ln in text.split("\n")[1:] if ln.strip()]
    quoted = bool(lines) and lines[0].split(",")[0].strip().startswith('"')
    def cell(s):
        s = "" if s is None else str(s)
        if quoted:
            return '"%s"' % s.replace('"', '""')
        return '"%s"' % s if ("," in s or '"' in s) else s
    shutil.copyfile(path, path + ".pre_map751_subzones.bak")
    body = text if text.endswith("\n") else text + "\n"
    open(path, "wb").write(b"\xef\xbb\xbf" +
                           (body + "\n".join(",".join(cell(c) for c in r) for r in newrows) + "\n").encode("utf-8"))
    print("AreaTable.csv %d -> %d rows (quoted=%s)" % (len(rows), len(rows) + len(newrows), quoted))

    # ---- retag the ADTs ---------------------------------------------------
    dll = load()
    dll.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                  ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    dll.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    dll.SFileGetFileSize.restype = wintypes.DWORD
    rd_cata = mk(dll, [CATA + "/*.MPQ", CATA + "/enUS/*.MPQ"], skip=("wow-update",))
    rd_dc = mk(dll, [DC + "/*.MPQ", DC + "/enGB/*.MPQ"])

    tiles = sorted({tuple(int(x) for x in k.split("|")) for k in []}) or None
    # tile list from the plan's own coverage: re-derive from the WDT
    wdt = open(os.path.join(SP, "lt", "DCPlaguelands.wdt"), "rb").read()
    pos, tset = 0, []
    while pos + 8 <= len(wdt):
        tag = wdt[pos:pos + 4][::-1].decode("ascii", "replace")
        size = struct.unpack_from("<I", wdt, pos + 4)[0]
        if tag == "MAIN":
            for i in range(64 * 64):
                if struct.unpack_from("<I", wdt, pos + 8 + i * 8)[0] & 1:
                    tset.append((i % 64, i // 64))
        pos += 8 + size
    tset.sort()

    os.makedirs(OUT, exist_ok=True)
    packlines, changed_tiles, changed_chunks, untouched = [], 0, 0, 0
    for tx, ty in tset:
        s = rd_cata("World\\Maps\\Azeroth\\Azeroth_%d_%d.adt" % (tx, ty))
        rel = "World\\Maps\\DCPlaguelands\\DCPlaguelands_%d_%d.adt" % (tx, ty)
        d = rd_dc(rel)
        if s is None or d is None or s[:4] != b"REVM" or d[:4] != b"REVM":
            raise SystemExit("ABORT: tile %d_%d unreadable (src=%s dst=%s)" % (tx, ty, s is None, d is None))
        so, do_ = mcnk_offsets(s), mcnk_offsets(d)
        if len(so) != 256 or len(do_) != 256:
            raise SystemExit("ABORT: tile %d_%d has %d/%d MCNKs" % (tx, ty, len(so), len(do_)))
        buf = bytearray(d)
        hit = 0
        for i in range(256):
            ca = struct.unpack_from("<I", s, so[i])[0]
            new = idmap.get(ca)
            if new is None:
                untouched += 1
                continue
            if struct.unpack_from("<I", buf, do_[i])[0] != new:
                struct.pack_into("<I", buf, do_[i], new)
                hit += 1
        if hit:
            p = os.path.join(OUT, rel.replace("\\", os.sep))
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "wb").write(bytes(buf))
            packlines.append("%s=%s" % (p.replace("\\", "/"), rel))
            changed_tiles += 1
            changed_chunks += hit

    lf = os.path.join(SP, "pack_subzones.txt")
    open(lf, "w", encoding="utf-8", newline="\n").write("\n".join(packlines) + "\n")
    print("\nretag: %d tiles rewritten, %d chunks retagged, %d chunks left on their zone id"
          % (changed_tiles, changed_chunks, untouched))
    print("pack list: %s" % lf)


main()
