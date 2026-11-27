#!/usr/bin/env python3
"""
Fix white-rendering character-model NPCs, and add the map-861 displays that do
not exist at all.

TWO DISTINCT PROBLEMS, TWO DIFFERENT FIXES
------------------------------------------
1. RACES THAT EXIST IN 3.3.5 ChrRaces (human, orc, nightelf, tauren, troll,
   dwarf, gnome, scourge, bloodelf, draenei, goblin) can use the normal NPC
   path: CreatureDisplayInfo.ExtendedDisplayInfoID -> CreatureDisplayInfoExtra,
   and the client bakes the skin live from race/sex/skin/face/hair + equipment.
   Every one of map 861's 34 character NPCs already has a valid extended id, so
   they are fine -- what is missing there is four CreatureDisplayInfo rows that
   were never downported at all (their creatures therefore have no usable model).

2. WORGEN (race 22) and PANDAREN (24) DO NOT EXIST in 3.3.5 ChrRaces, so the
   extended/bake path is unusable no matter what the DBC says -- this is why
   Lycanthoth Vandal renders pure white even though Cata gives it extended ids
   20978/20979.  The only route that works is TextureVariation_*, which binds
   M2 texture types 11/12/13.  Verified for this model set:
     * Character/WorgenNPC/{Male,Female}/Worgen{Male,Female}.M2 in patch-9
       already declare slot0 = type 11 and slot1 = type 12, so TV1/TV2 bind.
     * All 8 skin variants + their _Extra companions ship in patch-9 for both
       sexes, next to the M2 (TextureVariation BLPs must sit in the M2's own
       folder).
     * The playable worgen race lives at Character/Worgen/... -- a different
       path -- so touching the WorgenNPC set cannot affect it.
   Same technique as the earlier Legion-Dalaran fix; see the
   worgen-pandaren-npc-texture-fix note.

Skin choice comes from the Cata CreatureDisplayInfoExtra row the display points
at, so each NPC keeps its intended fur colour rather than all becoming skin 0.

Writes back to Custom/CSV DBC/{CreatureDisplayInfo,CreatureDisplayInfoExtra}.csv
(a .bak_charfix copy is made first).  Recompile + deploy afterwards.

    python fix_char_npc_displays.py [--apply]
"""
import csv, os, struct, shutil, sys

CSV = "K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/"
CATA = "k:/tmp/cata-dbc/"
APPLY = "--apply" in sys.argv

# map-861 displays that have no CreatureDisplayInfo row at all.
# model ids are the DC-side equivalents (verified present in CreatureModelData).
MISSING_861 = [
    # display, DC model, extended, scale, comment
    (38002, 502776, 0,     2.0, "Lava Burster -- LAVAWORM_03, baked as DC model 502776"),
    (38051, 185,    25341, 1.0, "Zen'Vorka -- stock TrollMale"),
    (38546, 59,     25335, 1.0, "Hyjal Defender / Wounded Hyjal Defender -- stock TaurenMale"),
    (38547, 60,     25336, 1.0, "Hyjal Defender / Wounded Hyjal Defender -- stock TaurenFemale"),
]
NEED_EXTRA = [25335, 25336, 25341]

EXTRA_COLS = (["ID", "DisplayRaceID", "DisplaySexID", "SkinID", "FaceID", "HairStyleID",
               "HairColorID", "FacialHairID"]
              + ["NPCItemDisplay_%d" % i for i in range(1, 12)]
              + ["Flags", "BakeName"])

# race id -> (folder, MaleModelName, FemaleModelName) for the TextureVariation route
TV_RACES = {22: ("WorgenNPC", "WorgenMale", "WorgenFemale"),
            24: ("Pandaren", "PandarenMale", "PandarenFemale")}


def load_dbc(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'WDBC', path
    rc, fc, rs, ss = struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20 + rc * rs


def i32(d, b, rs, r, i):
    return struct.unpack('<i', d[b + r * rs + i * 4:b + r * rs + i * 4 + 4])[0]


def cstr(d, sb, off):
    if off <= 0:
        return ""
    e = d.index(b'\x00', sb + off)
    return d[sb + off:e].decode('utf-8', 'replace')


def read_csv(name):
    with open(CSV + name, encoding='utf-8', newline='') as f:
        rows = list(csv.reader(f))
    return rows[0], rows[1:]


def write_csv(name, hdr, rows, quoted):
    shutil.copy2(CSV + name, CSV + name + ".bak_charfix")
    with open(CSV + name, 'w', encoding='utf-8', newline='') as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL if quoted else csv.QUOTE_MINIMAL,
                       lineterminator='\n')
        w.writerow(hdr)
        for r in rows:
            w.writerow(r)


def main():
    # --- Cata sources -------------------------------------------------------
    cd, crc, cfc, crs, cb, cst = load_dbc(CATA + "CreatureDisplayInfo.dbc")
    cata_ext_of = {i32(cd, cb, crs, r, 0): i32(cd, cb, crs, r, 3) for r in range(crc)}

    ed, erc, efc, ers, eb, est = load_dbc(CATA + "CreatureDisplayInfoExtra.dbc")
    cata_extra = {}
    for r in range(erc):
        vals = [i32(ed, eb, ers, r, i) for i in range(efc)]
        vals[-1] = cstr(ed, est, vals[-1])
        cata_extra[vals[0]] = vals

    # --- fork CSVs ----------------------------------------------------------
    md_hdr, md_rows = read_csv("CreatureModelData.csv")
    models = {}
    for row in md_rows:
        try:
            models[int(row[0])] = row[2]
        except (ValueError, IndexError):
            pass

    ex_hdr, ex_rows = read_csv("CreatureDisplayInfoExtra.csv")
    have_extra = set()
    for row in ex_rows:
        try:
            have_extra.add(int(row[0]))
        except (ValueError, IndexError):
            pass

    cdi_hdr, cdi_rows = read_csv("CreatureDisplayInfo.csv")
    have_cdi = set()
    for row in cdi_rows:
        try:
            have_cdi.add(int(row[0]))
        except (ValueError, IndexError):
            pass

    idi_have = set()
    with open(CSV + "ItemDisplayInfo.csv", encoding='utf-8', newline='') as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            try:
                idi_have.add(int(row[0]))
            except (ValueError, IndexError):
                pass

    report = []

    # === 1. missing CreatureDisplayInfoExtra rows for the map-861 displays ===
    new_extra = []
    for eid in NEED_EXTRA:
        if eid in have_extra:
            report.append("  extra %d already present" % eid)
            continue
        src = cata_extra.get(eid)
        if not src:
            report.append("  !! extra %d not in Cata CreatureDisplayInfoExtra" % eid)
            continue
        out = list(src)
        dropped = []
        for i in range(8, 19):                      # NPCItemDisplay_1..11
            if out[i] and out[i] not in idi_have:
                dropped.append(out[i])
                out[i] = 0                          # unknown equipment -> render nothing
        new_extra.append([str(v) for v in out])
        report.append("  extra %d race=%d sex=%d skin=%d%s"
                      % (eid, src[1], src[2], src[3],
                         ("  (dropped unknown item displays %s)" % dropped) if dropped else ""))

    # === 2. missing CreatureDisplayInfo rows (map 861) =======================
    new_cdi = []
    for did, mid, ext, scale, note in MISSING_861:
        if did in have_cdi:
            report.append("  display %d already present" % did)
            continue
        if mid not in models:
            report.append("  !! display %d wants model %d which is not in CreatureModelData" % (did, mid))
            continue
        row = [str(did), str(mid), "0", str(ext), repr(scale) if scale != int(scale) else str(int(scale)),
               "255", "", "", "", "", "-1", "0", "0", "0", "0", "0"]
        new_cdi.append(row)
        report.append("  display %d -> model %d (%s) ext=%d  [%s]" % (did, mid, models[mid], ext, note))

    # === 3. TextureVariation route for worgen / pandaren =====================
    tv_fixed = []
    for row in cdi_rows:
        try:
            did = int(row[0])
            mid = int(row[1])
        except (ValueError, IndexError):
            continue
        fn = (models.get(mid) or "").lower().replace("/", "\\")
        if not fn.startswith("character\\"):
            continue
        if row[6].strip():                          # already has TextureVariation_1
            continue
        folder = None
        for race, (fold, male, female) in TV_RACES.items():
            if "\\%s\\" % fold.lower() in fn:
                folder = (race, fold, male, female)
                break
        if not folder:
            continue
        race, fold, male, female = folder
        src = cata_extra.get(cata_ext_of.get(did, 0), None)
        skin = src[3] if src else 0
        sex = src[2] if src else (1 if "female" in fn else 0)
        base = female if (sex == 1 or "female" in fn) else male
        row[6] = "%sSkin00_%02d" % (base, skin)
        row[7] = "%sSkin00_%02d_Extra" % (base, skin)
        tv_fixed.append((did, mid, row[6]))

    print("=== CreatureDisplayInfoExtra additions ===")
    print("\n".join(l for l in report if "extra" in l) or "  (none)")
    print("=== CreatureDisplayInfo additions (map 861) ===")
    print("\n".join(l for l in report if "display" in l) or "  (none)")
    print("=== TextureVariation fixes (worgen / pandaren, %d displays) ===" % len(tv_fixed))
    for t in tv_fixed:
        print("  display %-7d model %-7d -> %s" % t)

    if not APPLY:
        print("\n(dry run -- pass --apply to write the CSVs)")
        return

    if new_extra:
        write_csv("CreatureDisplayInfoExtra.csv", ex_hdr, ex_rows + new_extra, quoted=True)
    if new_cdi or tv_fixed:
        write_csv("CreatureDisplayInfo.csv", cdi_hdr, cdi_rows + new_cdi, quoted=False)
    print("\nwritten. Recompile CreatureDisplayInfo + CreatureDisplayInfoExtra and deploy.")


if __name__ == "__main__":
    main()
