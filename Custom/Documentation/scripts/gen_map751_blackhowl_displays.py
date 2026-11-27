#!/usr/bin/env python3
"""gen_map751_blackhowl_displays.py - real Cata displays for the map-751 Blackhowl garrison.

113_gilneas_city_blackhowl_751.sql shipped with SUBSTITUTE displays because Cata's own
39812-39823 are ExtendedDisplayInfo CHARACTER-NPC displays and neither they nor their
CreatureDisplayInfoExtra rows exist here. This does the proper downport, following
[[character-npc-display-downport-recipe]]: the route is chosen by DisplayRaceID.

  race 1 (Human)  -> native CreatureDisplayInfoExtra + BakeName. ModelID 49 (male) / 50
                     (female) are the SAME ids in Cata, so the row copies verbatim. The
                     PLAYER character models are not touched.
  race 22 (Worgen)-> no stock ChrRaces row, so the Extra path is dead. Point at the DC
                     NPC-copy model 500962 (Character\\WorgenNPC\\Male\\WorgenMale.M2),
                     ExtendedDisplayInfoID 0, and bind the bake through MONSTER slots:
                     TV_1 = the bake, TV_2 = WorgenMaleSkin00_00_Extra, TV_3 =
                     cape_gilneas_a_01. TV_2/TV_3 are NOT optional -- leave them empty and
                     the body and cape render white. Values read off the working display
                     33950, never invented.

Layout note: Cata CreatureDisplayInfo is 17 fields, ours is 16 -- the first 16 align
position-for-position (verified on shared stock rows 895 and 1126), Cata just appends one.
CreatureDisplayInfoExtra is 21 fields / 84 bytes in BOTH, so those rows copy whole.

Ids are Cata's own (displays 39812-39823, extras 25973-25984) -- all verified free here, so
nothing is remapped and the provenance stays readable.

Outputs (nothing is deployed by this script):
  Custom/CSV DBC/CreatureDisplayInfo.csv        +9 rows   (appended)
  Custom/DBCs/CreatureDisplayInfo.dbc           +9 records
  Custom/CSV DBC/CreatureDisplayInfoExtra.csv   +7 rows
  Custom/DBCs/CreatureDisplayInfoExtra.dbc      +7 records
  <out>/Textures/BakedNpcTextures/*.blp         9 bakes
  <out>/Character/WorgenNPC/Male/*.blp          2 bakes AGAIN -- a MONSTER slot never
                                                reads BakedNpcTextures
  .../Plaguelands/114_blackhowl_real_displays_751.sql   creature_model_info + repoint
"""
import argparse
import io
import os
import struct
import sys

BS = chr(92)
REPO = "K:/Dark-Chaos/DarkChaos-255-Master/Custom"
CATA_DBC = "k:/tmp/catadbc"
CATA_ART = ["K:/UntouchedClients/Cata/Data/art.MPQ",
            "K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ",
            "K:/UntouchedClients/Cata/Data/base-Win.MPQ"]

WORGEN_MODEL = 500962          # Character\WorgenNPC\Male\WorgenMale.M2
WORGEN_TV2 = "WorgenMaleSkin00_00_Extra"
WORGEN_TV3 = "cape_gilneas_a_01"

# our creature entry -> [(display id, idx)] and the model_info reference per ModelID
ASSIGN = {
    4157805: [39812, 39813, 39814, 39815],   # Footsoldier: 2 human male + 2 human female
    4157810: [39818, 39819],                 # Sniper: 2 human female
    4157806: [39816, 39817],                 # Packmaster: 2 worgen
    4157802: [39823],                        # Lord Hiram Creed: human male, scale 1.75
}
WORGEN_DISPLAYS = {39816, 39817}
MODEL_INFO = {49: (0.306, 1.5, 0), 50: (0.208, 1.5, 1), WORGEN_MODEL: (0.306, 1.5, 0)}


def load_dbc(path):
    d = open(path, 'rb').read()
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    sb = 20 + rc * rs

    def s(o):
        if o <= 0 or sb + o >= len(d):
            return ""
        e = d.find(b'\0', sb + o)
        return d[sb + o:e].decode('utf-8', 'replace')

    rows = [[struct.unpack_from('<i', d, 20 + i * rs + k * 4)[0] for k in range(fc)]
            for i in range(rc)]
    return rows, s, (rc, fc, rs, ss)


def append_dbc(path, new_rows, str_cols, expect):
    """Append records to a WDBC in place. Existing records and string block are untouched;
    new strings are interned against what is already there."""
    d = open(path, 'rb').read()
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    assert (fc, rs) == expect, (fc, rs, expect)
    sb = 20 + rc * rs
    recs = bytearray(d[20:sb])
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

    for r in new_rows:
        rec = bytearray()
        for k, v in enumerate(r):
            rec += struct.pack('<I', addstr(v) if k in str_cols else (int(v) & 0xFFFFFFFF))
        assert len(rec) == rs, (len(rec), rs)
        recs += rec
    out = (b'WDBC' + struct.pack('<4I', rc + len(new_rows), fc, rs, len(strb))
           + bytes(recs) + bytes(strb))
    open(path, 'wb').write(out)
    print("  %s: %d -> %d records" % (os.path.basename(path), rc, rc + len(new_rows)))


def append_csv(path, new_rows):
    """Append quoted rows, preserving the file's BOM, quoting mix and LF endings."""
    with open(path, "ab") as fh:
        for r in new_rows:
            line = ",".join('"%s"' % str(v).replace('"', '""') for v in r)
            fh.write(line.encode("utf-8") + b"\n")
    print("  %s: +%d rows" % (os.path.basename(path), len(new_rows)))


def mpq_grab(archive, name):
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


def emit_sql(new_cdi, displays, cdi_by):
    sql = [
        "-- 114_blackhowl_real_displays_751.sql -- swap the Blackhowl garrison off its",
        "-- substitute displays and onto the real Cata ones.",
        "--",
        "-- 113_gilneas_city_blackhowl_751.sql shipped with stand-in worgen displays because",
        "-- Cata's 39812-39823 are ExtendedDisplayInfo CHARACTER-NPC displays that did not exist",
        "-- here. gen_map751_blackhowl_displays.py downports them properly:",
        "--   * 7 human displays (ModelID 49/50, the SAME ids Cata uses) via native",
        "--     CreatureDisplayInfoExtra rows 25973-25978/25984 + BakeName. Player models untouched.",
        "--   * 2 worgen displays (39816/39817) via DC NPC-copy model 500962 with the bake bound",
        "--     through MONSTER slots -- worgen has no stock ChrRaces row so the Extra path is dead.",
        "--",
        "-- ORDERING GATE -- DEPLOY THE SERVER DBC FIRST, THEN APPLY THIS FILE.",
        "--   ObjectMgr.cpp:742 skips any creature_template_model row whose CreatureDisplayID is",
        "--   absent from the server's CreatureDisplayInfo.dbc:",
        "--     \"Creature (Entry: X) lists non-existing CreatureDisplayID id (Y), this can crash",
        "--      the client.\"",
        "--   Apply this before /home/wowcore/azeroth-server/data/dbc has the new rows and all four",
        "--   Blackhowl entries lose their models and stop spawning entirely. The client side is",
        "--   already deployed (patch-4, enGB/patch-enGB-3, the WXL mirror, 9 bakes in patch-7);",
        "--   the SERVER copy is the one step this workstation cannot do.",
        "--",
        "-- creature_model_info is the layer that is easy to miss: without it the creature refuses to",
        "-- load with a message naming creature_template_model, which is the WRONG table.",
        "",
        "-- ---------------------------------------------------------------------------",
        "-- 1. creature_model_info -- BoundingRadius/CombatReach read off existing displays",
        "--    on the SAME ModelID (49 human male 0.306, 50 human female 0.208, 500962 0.306);",
        "--    a blanket 0.306 is wrong for the female skeleton.",
        "-- ---------------------------------------------------------------------------",
        "DELETE FROM `creature_model_info` WHERE `DisplayID` IN (%s);"
        % ", ".join(str(d) for d in displays),
        "INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `gender`) VALUES",
    ]
    vals = []
    for (row, model), did in zip(new_cdi, displays):
        br, cr, g = MODEL_INFO[model]
        vals.append("(%d, %s, %s, %d)" % (did, br, cr, g))
    sql.append(",\n".join(vals) + ";")
    sql += [
        "",
        "-- ---------------------------------------------------------------------------",
        "-- 2. repoint creature_template_model off the substitutes. DisplayScale stays 1 --",
        "--    it MULTIPLIES with CreatureDisplayInfo.CreatureModelScale, and 39823 already",
        "--    carries Creed's 1.75 in the DBC (113's stand-in 35618 was scale 1.0, which is",
        "--    why 113 could put 1.75 in this column).",
        "-- ---------------------------------------------------------------------------",
        "DELETE FROM `creature_template_model` WHERE `CreatureID` IN (%s);"
        % ", ".join(str(e) for e in sorted(ASSIGN)),
        "INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`,",
        "  `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES",
    ]
    vals = []
    for ent in sorted(ASSIGN):
        for idx, did in enumerate(ASSIGN[ent]):
            # DisplayScale is 1 on every row ON PURPOSE. Creature.cpp:533 SetDisplayId ->
            # SetObjectScale(model.DisplayScale), and the client then renders at
            # CreatureDisplayInfo.CreatureModelScale * that object scale -- the two MULTIPLY.
            # Lord Hiram Creed's real display 39823 already carries 1.75 in the DBC, so
            # repeating it here would make him 3.06x. 113 could safely use 1.75 because its
            # stand-in display 35618 has a DBC scale of 1.0.
            vals.append("(%d, %d, %d, 1, 1, 15595)" % (ent, idx, did))
    sql.append(",\n".join(vals) + ";")
    sql += [
        "",
        "-- Blackhowl Bloodhound (4157861) is NOT touched: its Cata displays 30211/30213 are",
        "-- already in our DBC and 113 wired them exactly.",
    ]
    out_sql = (REPO + "/Custom feature SQLs/worlddb/Plaguelands/"
               "114_blackhowl_real_displays_751.sql")
    open(out_sql, "w", encoding="utf-8", newline="\n").write("\n".join(sql) + "\n")
    print("sql: %s" % os.path.basename(out_sql))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="k:/tmp/blackhowl_display_stage")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--sql-only", action="store_true",
                    help="re-emit the SQL against DBCs this script already appended to")
    a = ap.parse_args()

    cdi, cs, ch = load_dbc(CATA_DBC + "/CreatureDisplayInfo.dbc")
    cex, xs, xh = load_dbc(CATA_DBC + "/CreatureDisplayInfoExtra.dbc")
    cdi_by = {r[0]: r for r in cdi}
    cex_by = {r[0]: r for r in cex}
    ours_cdi, _, oh = load_dbc(REPO + "/DBCs/CreatureDisplayInfo.dbc")
    ours_cex, _, oxh = load_dbc(REPO + "/DBCs/CreatureDisplayInfoExtra.dbc")
    taken_d = {r[0] for r in ours_cdi}
    taken_x = {r[0] for r in ours_cex}

    displays = sorted({d for v in ASSIGN.values() for d in v})
    clash = [d for d in displays if d in taken_d]
    if clash and not a.sql_only:
        sys.exit("display ids already present here: %s" % clash)

    new_cdi, new_cex, bakes, extras_used = [], [], [], []
    for did in displays:
        src = cdi_by[did]
        row = list(src[:16])                       # drop Cata's 17th field
        extra_id = src[3]
        model = src[1]
        if did in WORGEN_DISPLAYS:
            row[1] = WORGEN_MODEL
            row[3] = 0
            row[6] = "CreatureDisplayExtra-%05d" % extra_id
            row[7] = WORGEN_TV2
            row[8] = WORGEN_TV3
            model = WORGEN_MODEL
        else:
            row[6] = cs(src[6])
            row[7] = cs(src[7])
            row[8] = cs(src[8])
            if extra_id not in taken_x:
                ex = cex_by[extra_id]
                new_cex.append([ex[0]] + list(ex[1:20]) + [xs(ex[20])])
                extras_used.append(extra_id)
        row[9] = cs(src[9])
        new_cdi.append((row, model))
        bakes.append(extra_id)
        scale = struct.unpack('<f', struct.pack('<i', src[4]))[0]
        print("  display %-6d model %-7d extra %-6d scale %-5s %s"
              % (did, model, row[3], scale,
                 "WORGEN via MONSTER slots" if did in WORGEN_DISPLAYS else "human Extra+BakeName"))

    if a.dry_run:
        print("dry run: %d displays, %d extras, %d bakes" % (len(new_cdi), len(new_cex), len(bakes)))
        return

    if a.sql_only:
        emit_sql(new_cdi, displays, cdi_by)
        return

    print("DBC/CSV:")
    append_csv(REPO + "/CSV DBC/CreatureDisplayInfo.csv", [r for r, _ in new_cdi])
    append_dbc(REPO + "/DBCs/CreatureDisplayInfo.dbc", [r for r, _ in new_cdi],
               str_cols={6, 7, 8, 9}, expect=(16, 64))
    if new_cex:
        append_csv(REPO + "/CSV DBC/CreatureDisplayInfoExtra.csv", new_cex)
        append_dbc(REPO + "/DBCs/CreatureDisplayInfoExtra.dbc", new_cex,
                   str_cols={20}, expect=(21, 84))

    # ---- art ----
    baked = os.path.join(a.out, "Textures", "BakedNpcTextures")
    wdir = os.path.join(a.out, "Character", "WorgenNPC", "Male")
    os.makedirs(baked, exist_ok=True)
    os.makedirs(wdir, exist_ok=True)
    worgen_extras = {cdi_by[d][3] for d in WORGEN_DISPLAYS}
    print("art:")
    for ex in sorted(set(bakes)):
        fn = "CreatureDisplayExtra-%05d.blp" % ex
        blob = None
        for arc in CATA_ART:
            blob = mpq_grab(arc, "Textures" + BS + "BakedNpcTextures" + BS + fn)
            if blob:
                break
        if not blob or blob[:4] != b'BLP2':
            sys.exit("bake %s not found or not BLP2" % fn)
        if blob[11] == 2:
            sys.exit("%s has hasMips=2 -- would render green, needs the one-byte fix" % fn)
        open(os.path.join(baked, fn), 'wb').write(blob)
        if ex in worgen_extras:
            open(os.path.join(wdir, fn), 'wb').write(blob)
    print("  %d bakes -> %s (+%d copied next to the worgen model)"
          % (len(set(bakes)), baked, len(worgen_extras)))

    emit_sql(new_cdi, displays, cdi_by)


if __name__ == "__main__":
    main()
