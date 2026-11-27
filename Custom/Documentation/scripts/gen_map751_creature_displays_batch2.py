#!/usr/bin/env python3
"""Batch 2 of the map-751 creature-display downport: the 12 displays 89_ deferred.

89_missing_referenced_creatures.sql imports 44 of the 53 templates the band
references but never got. Nine were held back because their display is absent from
CreatureDisplayInfo.dbc and, unlike the credit bunnies, they are REAL NPCs a player
sees -- an invisible substitute would be a visible bug. This closes those nine.

    38980 Spirit of Devlin Agamand  31249      44915 Orc Crate            34180
    43007 Shadra                    33275      45270 Hillsbrad Worgen     34367-34370
    44369 Lord Godfrey              29675      47442 Johnny Awesome       35624
    44629 Garrosh Hellscream        32907      47443 Kingslayer Orkus     35625
                                               49231 Valdred Moray        36418

WHY THIS IS A SEPARATE SCRIPT AND NOT A RE-RUN OF BATCH 1
`gen_map751_creature_displays.py` takes its baseline from the
`.pre_map751_displays.bak` copies it wrote on its first pass, so re-running it with a
new plan would rewrite the CSVs as baseline+12 and **destroy the 303 rows 76_ already
appended**. Batch 2 is additive: its baseline is the CURRENT CSV, and it writes its
own backup suffix and its own SQL file.

THE WORGEN ROUTE IS DIFFERENT FROM BATCH 1 -- AND SIMPLER
76_ rebound its 34 worgen onto the DC WorgenNPC model copies (500961/500962) with the
bake in TextureVariation_1, because Cata's `DisplayRaceID = 22` has no ChrRaces row in
this client (verified again: ChrRaces holds 21 records, 22 is absent).
That rebinding is not needed. **WotLK's ChrRaces already has an NPC worgen race at
id 12**, and DC's own pre-existing worgen NPCs use it: displays 32722/36154 (male) and
33679/36161 (female) sit on stock models 3141/3142 with Extra rows declaring
`DisplayRaceID = 12`, and they render correctly today. So batch 2 keeps the stock
model and simply remaps the race **22 -> 12** on the Extra row, taking the native
BakeName path with no MONSTER-slot workaround and no white-render risk.

MODEL_INFO IS DERIVED BY SCALE, NOT BY FIRST-NON-ZERO SIBLING
Batch 1 inherited BoundingRadius/CombatReach from the first sibling display on the
same model that had non-zero values. That is wrong whenever the scales differ, and
here it matters: Shadra is scale 8.0 and her first sibling is scale 8.7. The data
shows the relationship is linear -- on the giant-spider model, BoundingRadius equals
the display scale exactly and CombatReach is scale x 2.3 (15928: 8.7/8.7/20.01,
16462: 1.4/1.4/3.22, 17180: 3.48/3.48/8.004). So batch 2 picks the sibling whose
scale is NEAREST and rescales both values by (our scale / donor scale). For the
scale-1.0 humanoids this is identical to batch 1's result; for Shadra (8.0), the
Hillsbrad Worgen (2.0) and the Orc Crate (0.5) it is not.

Emits (nothing is deployed):
  Custom/CSV DBC/CreatureDisplayInfo.csv        +12 rows
  Custom/CSV DBC/CreatureDisplayInfoExtra.csv   + 8 rows
  Custom/CSV DBC/CreatureModelData.csv          + 1 row  (Garrosh)
  Plaguelands/90_creature_displays_batch2.sql   overlay tables + creature_model_info
"""
import os, sys, json, csv, struct, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.environ.get("SCRATCH", "")
CSVDIR = os.path.normpath(os.path.join(HERE, "..", "..", "CSV DBC"))
OUTSQL = os.path.normpath(os.path.join(HERE, "..", "..", "Custom feature SQLs",
                                       "worlddb", "Plaguelands", "90_creature_displays_batch2.sql"))
BAK = ".pre_batch2.bak"

WORGEN_CATA_RACE, WORGEN_WOTLK_RACE = 22, 12
DEAD_SOUND, DEAD_NPCSOUND, DEAD_PARTICLE = {81}, {362, 381}, {588}

# creature_model_info donors, read from the live DB for every sibling the plan names.
# display -> (BoundingRadius, CombatReach, Gender). Zeros mean "no usable value" and
# are skipped, exactly as batch 1 did.
DONORS = {
    49: (0.306, 1.5, 0), 51: (0, 0, 0), 57: (0.383, 1.5, 0), 102: (0, 0, 0),
    211: (0.208, 1.5, 0), 214: (0, 0, 0), 907: (0, 0, 2), 1027: (0.383, 1.5, 0),
    1139: (0, 0, 0), 1275: (0.372, 1.5, 0), 1276: (0.306, 1.5, 0), 1278: (0.383, 1.5, 0),
    2208: (0.306, 1.5, 1), 2243: (0.389, 1.5, 0), 3141: (0.208, 1.5, 0),
    3142: (0.306, 1.5, 0), 3394: (0.347, 1.5, 0), 10375: (0, 0, 0),
    15476: (0.383, 1.5, 0), 15504: (0.383, 1.5, 0), 15928: (8.7, 20.01, 1),
    16462: (1.4, 3.22, 1), 17180: (3.48, 8.004, 1), 29422: (0.406, 1.5, 0),
    29423: (0.406, 1.5, 1), 32209: (0.54, 1.0, 2), 32722: (0.347222, 1.5, 0),
    33679: (0.347222, 1.5, 1), 36154: (0.347222, 1.5, 0), 36161: (0.347222, 1.5, 1),
}


class Dbc:
    def __init__(self, p):
        d = open(p, "rb").read()
        m, self.rc, self.fc, self.rs, self.ss = struct.unpack_from("<4sIIII", d, 0)
        assert m == b"WDBC", p
        self.rows = {}
        for i in range(self.rc):
            v = struct.unpack_from("<%dI" % self.fc, d, 20 + i * self.rs)
            self.rows[v[0]] = v
        self.sb = d[20 + self.rc * self.rs:]

    def s(self, o):
        # MUST return "" and never None for a null offset. The row builders feed
        # this straight into both the CSV and the SQL, and `str(None)` is the
        # literal text "None" -- which writes an empty TextureVariation as the
        # four-character string None, and makes the SQL read `..., None, ...` and
        # die with "1054 Unknown column 'None' in 'field list'". Stock rows and
        # 76_'s 303 rows all write an EMPTY field here.
        # The planner (plan_displays.py) returns None from its copy of this class
        # on purpose, for presence checks -- do not copy that one into a writer.
        if not o or o >= len(self.sb):
            return ""
        e = self.sb.find(b"\0", o)
        return self.sb[o:e if e >= 0 else None].decode("utf-8", "replace")


def i32(w):
    return struct.unpack("<i", struct.pack("<I", w))[0]


def f32(w):
    return struct.unpack("<f", struct.pack("<I", w))[0]


def fmt(v):
    # Backstop for the same class of bug as Dbc.s(): str(None) == "None", which is
    # a valid-looking but wrong CSV cell and an invalid SQL token.
    if v is None:
        return ""
    if isinstance(v, float):
        if v != v or v in (float("inf"), float("-inf")):
            return "0"
        s = "%.7g" % v
        return "0" if s in ("0", "-0") else s
    return str(v)


def csv_cell(v):
    s = fmt(v)
    return '"%s"' % s.replace('"', '""') if ("," in s or '"' in s) else s


def append_csv(name, cols, rows, label):
    path = os.path.join(CSVDIR, name)
    text = open(path, "rb").read().decode("utf-8-sig")
    hdr = [h.strip().strip('"') for h in text.split("\n", 1)[0].split(",")]
    if hdr != cols:
        raise SystemExit("ABORT: %s header mismatch\n  file: %s\n  want: %s" % (name, hdr, cols))
    existing = {ln.split(",", 1)[0].strip().strip('"') for ln in text.split("\n")[1:] if ln.strip()}
    dupes = [r[0] for r in rows if str(r[0]) in existing]
    if dupes:
        raise SystemExit("ABORT: %s already has ids %s -- refusing to duplicate" % (name, dupes[:8]))
    shutil.copyfile(path, path + BAK)
    body = text if text.endswith("\n") else text + "\n"
    out = body + "\n".join(",".join(csv_cell(c) for c in r) for r in rows) + "\n"
    open(path, "wb").write(b"\xef\xbb\xbf" + out.encode("utf-8"))
    print("  %-32s %5d -> %5d rows (+%d %s)" % (name, len(existing), len(existing) + len(rows), len(rows), label))


CDI_COLS = ["ID", "ModelID", "SoundID", "ExtendedDisplayInfoID", "CreatureModelScale",
            "CreatureModelAlpha", "TextureVariation_1", "TextureVariation_2",
            "TextureVariation_3", "PortraitTextureName", "BloodLevel", "BloodID",
            "NPCSoundID", "ParticleColorID", "CreatureGeosetData", "ObjectEffectPackageID"]
CDE_COLS = ["ID", "DisplayRaceID", "DisplaySexID", "SkinID", "FaceID", "HairStyleID",
            "HairColorID", "FacialHairID"] + ["NPCItemDisplay_%d" % (i + 1) for i in range(11)] + \
           ["Flags", "BakeName"]
# The overlay TABLE spells these without the underscore the CSV header uses.
# Verified against INFORMATION_SCHEMA -- this cost a 1054 at apply time once already.
CDE_SQL_COLS = CDE_COLS[:8] + ["NPCItemDisplay%d" % (i + 1) for i in range(11)] + ["Flags", "BakeName"]
CMD_COLS = ["ID", "Flags", "ModelName", "SizeClass", "ModelScale", "BloodID",
            "FootprintTextureID", "FootprintTextureLength", "FootprintTextureWidth",
            "FootprintParticleScale", "FoleyMaterialID", "FootstepShakeSize",
            "DeathThudShakeSize", "SoundID", "CollisionWidth", "CollisionHeight",
            "MountHeight", "GeoBoxMinX", "GeoBoxMinY", "GeoBoxMinZ", "GeoBoxMaxX",
            "GeoBoxMaxY", "GeoBoxMaxZ", "WorldEffectScale", "AttachedEffectScale",
            "MissileCollisionRadius", "MissileCollisionPush", "MissileCollisionRaise"]

NAMES = {29675: "Lord Godfrey", 31249: "Spirit of Devlin Agamand", 32907: "Garrosh Hellscream",
         33275: "Shadra", 34180: "Orc Crate", 34367: "Hillsbrad Worgen",
         34368: "Hillsbrad Worgen", 34369: "Hillsbrad Worgen", 34370: "Hillsbrad Worgen",
         35624: "Johnny Awesome", 35625: "Kingslayer Orkus", 36418: "Valdred Moray"}


def main():
    plan = json.load(open(os.path.join(SP, "plan_displays2.json")))
    cdi = Dbc(os.path.join(SP, "cata_veh", "CreatureDisplayInfo.dbc"))
    cde = Dbc(os.path.join(SP, "cata_veh", "CreatureDisplayInfoExtra.dbc"))
    cmd = Dbc(os.path.join(SP, "cata_veh", "CreatureModelData.dbc"))

    def rd(name):
        return list(csv.DictReader(open(os.path.join(CSVDIR, name), encoding="utf-8-sig")))

    dc_cdi = rd("CreatureDisplayInfo.csv")
    dc_cmd = {int(r["ID"]): r for r in rd("CreatureModelData.csv")}
    have_extra = {int(r["ID"]) for r in rd("CreatureDisplayInfoExtra.csv")}
    scale_of = {int(r["ID"]): float(r["CreatureModelScale"] or 1) for r in dc_cdi}

    extras_by_cata = {v["cata_id"]: v for v in plan["new_extras"].values()}
    collide = [c for c in extras_by_cata if c in have_extra]
    if collide:
        raise SystemExit("ABORT: extra ids already present: %s -- needs a remap band" % collide)

    # ---- CreatureModelData (only Garrosh) ----------------------------------
    cmd_rows = []
    for key, nm in sorted(plan["new_models"].items(), key=lambda kv: kv[1]["id"]):
        src = cmd.rows[nm["cata_model"]]
        vals = [nm["id"], i32(src[1]), nm["path"]]
        for ci in range(3, 28):
            name = CMD_COLS[ci]
            vals.append(i32(src[ci]) if name in ("SizeClass", "BloodID", "FootprintTextureID",
                                                 "FoleyMaterialID", "FootstepShakeSize",
                                                 "DeathThudShakeSize", "SoundID")
                        else f32(src[ci]))
        cmd_rows.append(vals)

    # ---- displays + extras + model_info ------------------------------------
    cdi_rows, cde_rows, mi_rows, notes = [], [], [], []
    worgen_n = 0
    for p in sorted(plan["plan"], key=lambda x: x["cata_display"]):
        d = p["cata_display"]
        src = cdi.rows[d]
        model = p["dc_model"]
        my_scale = f32(src[4]) or 1.0
        ext_cata = p["cata_extra"]
        ext_row = extras_by_cata.get(ext_cata) if ext_cata else None
        is_worgen = bool(ext_row and ext_row["race"] == WORGEN_CATA_RACE)

        if ext_row:
            ext_id = ext_cata
            er = cde.rows[ext_cata]
            race = i32(er[1])
            if race == WORGEN_CATA_RACE:
                race = WORGEN_WOTLK_RACE
                worgen_n += 1
                notes.append("  %-5d %-26s race 22 -> 12 (WotLK NPC worgen), model %d kept"
                             % (d, NAMES.get(d, "?"), model))
            cde_rows.append([ext_id, race] + [i32(er[j]) for j in range(2, 20)] + [cde.s(er[20])])
        else:
            ext_id = 0

        snd = i32(src[2]);  snd = 0 if snd in DEAD_SOUND else snd
        npcs = i32(src[12]); npcs = 0 if npcs in DEAD_NPCSOUND else npcs
        part = i32(src[13]); part = 0 if part in DEAD_PARTICLE else part

        cdi_rows.append([d, model, snd, ext_id, my_scale, i32(src[5]),
                         cdi.s(src[6]), cdi.s(src[7]), cdi.s(src[8]), cdi.s(src[9]),
                         i32(src[10]), i32(src[11]), npcs, part, i32(src[14]), i32(src[15])])

        # ---- creature_model_info: nearest-scale sibling, rescaled ----------
        best = None
        for s in p["sibling_displays"]:
            v = DONORS.get(s)
            if not v or not v[0]:
                continue
            ds = scale_of.get(s, 1.0) or 1.0
            gap = abs(ds - my_scale)
            if best is None or gap < best[0]:
                best = (gap, s, v, ds)
        if best:
            _, sib, (br, cr, _), dscale = best
            k = my_scale / dscale if dscale else 1.0
            br, cr = br * k, cr * k
            if abs(k - 1.0) > 1e-6:
                notes.append("  %-5d %-26s model_info from %d, rescaled x%.3f -> %.4f/%.4f"
                             % (d, NAMES.get(d, "?"), sib, k, br, cr))
        else:
            row = dc_cmd.get(model)
            if row:
                br = (float(row["CollisionWidth"] or 0) or 0.306) * my_scale
            else:
                mr = [r for r in cmd_rows if r[0] == model]
                br = ((mr[0][14] if mr else 0.306) or 0.306) * my_scale
            cr = 1.5 * my_scale
            notes.append("  %-5d %-26s NO sibling -- from model CollisionWidth x scale -> %.4f/%.4f"
                         % (d, NAMES.get(d, "?"), br, cr))
        gender = ext_row["sex"] if ext_row and ext_row["sex"] in (0, 1) else 2
        mi_rows.append((d, round(br, 6), round(cr, 6), gender))

    print("generating:")
    if os.environ.get("SQL_ONLY"):
        print("  SQL_ONLY set -- CSVs left untouched")
    else:
        if cmd_rows:
            append_csv("CreatureModelData.csv", CMD_COLS, cmd_rows, "models")
        append_csv("CreatureDisplayInfoExtra.csv", CDE_COLS, cde_rows, "extras")
        append_csv("CreatureDisplayInfo.csv", CDI_COLS, cdi_rows, "displays")

    # ---- SQL ---------------------------------------------------------------
    def ins(table, cols, rows):
        out = ["DELETE FROM `%s` WHERE `ID` IN (%s);" % (table, ",".join(str(r[0]) for r in rows)), ""]
        out.append("INSERT INTO `%s` (%s) VALUES" % (table, ", ".join("`%s`" % c for c in cols)))
        body = []
        for r in rows:
            cells = []
            for v in r:
                if isinstance(v, str):
                    cells.append("'%s'" % v.replace("\\", "\\\\").replace("'", "''") if v else "''")
                else:
                    cells.append(fmt(v))
            body.append("(" + ", ".join(cells) + ")")
        out.append(",\n".join(body) + ";")
        return "\n".join(out)

    disp_ids = ",".join(str(r[0]) for r in cdi_rows)
    with open(OUTSQL, "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("-- 90_creature_displays_batch2.sql -- map 751 Lordaeron extension, DB step 29.\n--\n")
        w("-- GENERATED by Custom/Documentation/scripts/gen_map751_creature_displays_batch2.py\n")
        w("-- -- do not hand-edit; re-run the generator instead.\n--\n")
        w("-- The %d displays 89_ deferred, so the 9 real NPCs it held back can ship.\n" % len(cdi_rows))
        w("-- Apply this BEFORE re-running 89_ with those 9 added to its id lists.\n--\n")
        w("-- Two halves, and BOTH are needed:\n")
        w("--   1. the *_dbc overlay tables below (server: LOAD_DBC merges them at boot)\n")
        w("--   2. the recompiled DBCs deployed to the client patches AND to the server's\n")
        w("--      data/dbc -- the client renders from its own copy\n--\n")
        w("-- WORGEN: Cata's DisplayRaceID 22 has no ChrRaces row in this client (21\n")
        w("-- records, 22 absent), but WotLK has an NPC worgen race at **12**, which DC's\n")
        w("-- own working worgen NPCs already use (displays 32722/36154/33679/36161 on\n")
        w("-- stock models 3141/3142). So the race is remapped 22 -> 12 and the stock model\n")
        w("-- is kept -- no rebinding onto the WorgenNPC copies, which is what 76_ had to\n")
        w("-- do before this was understood.\n--\n")
        w("-- creature_model_info is the FOURTH layer and is NOT optional: without a row the\n")
        w("-- creature refuses to load with the SAME misleading \"no model defined\" message\n")
        w("-- (the failing call is GetCreatureModelRandomGender). Values are inherited from\n")
        w("-- the sibling display whose SCALE is nearest, then rescaled by the scale ratio --\n")
        w("-- the relationship is linear, verified on the giant-spider family where\n")
        w("-- BoundingRadius == scale exactly (8.7/8.7, 1.4/1.4, 3.48/3.48).\n\n")
        if cmd_rows:
            w("-- ---------------------------------------------------------------------------\n")
            w("-- 1. CreatureModelData overlay (%d new model)\n" % len(cmd_rows))
            w("--    Garrosh is the only model of the 12 whose art is NOT already in the DC\n")
            w("--    client -- CREATURE\\GARROSH\\GARROSH.M2 must be downported and packed, or\n")
            w("--    display 32907 resolves to a model file that does not exist.\n")
            w("-- ---------------------------------------------------------------------------\n")
            w(ins("creaturemodeldata_dbc", CMD_COLS, cmd_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 2. CreatureDisplayInfoExtra overlay (%d character bakes, %d of them worgen)\n"
          % (len(cde_rows), worgen_n))
        w("-- ---------------------------------------------------------------------------\n")
        w(ins("creaturedisplayinfoextra_dbc", CDE_SQL_COLS, cde_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 3. CreatureDisplayInfo overlay (%d displays)\n" % len(cdi_rows))
        w("-- ---------------------------------------------------------------------------\n")
        w(ins("creaturedisplayinfo_dbc", CDI_COLS, cdi_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 4. creature_model_info -- the layer that actually gates spawning\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("DELETE FROM `creature_model_info` WHERE `DisplayID` IN (%s);\n\n" % disp_ids)
        w("INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`) VALUES\n")
        w(",\n".join("(%d, %s, %s, %d, 0)" % (d, fmt(b), fmt(c), g) for d, b, c, g in mi_rows) + ";\n\n")
        w("-- ---------------------------------------------------------------------------\n-- Verification\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("SELECT 'display rows (want %d)' AS what, COUNT(*) AS n FROM `creaturedisplayinfo_dbc` WHERE `ID` IN (%s)\n"
          % (len(cdi_rows), disp_ids))
        w("UNION ALL SELECT 'extra rows (want %d)', COUNT(*) FROM `creaturedisplayinfoextra_dbc` WHERE `ID` IN (%s)\n"
          % (len(cde_rows), ",".join(str(r[0]) for r in cde_rows)))
        if cmd_rows:
            w("UNION ALL SELECT 'model rows (want %d)', COUNT(*) FROM `creaturemodeldata_dbc` WHERE `ID` IN (%s)\n"
              % (len(cmd_rows), ",".join(str(r[0]) for r in cmd_rows)))
        w("UNION ALL SELECT 'model_info rows (want %d)', COUNT(*) FROM `creature_model_info` WHERE `DisplayID` IN (%s);\n\n"
          % (len(mi_rows), disp_ids))
        w("-- must be empty: a worgen extra still declaring race 22, which has no ChrRaces\n")
        w("-- row and renders as an untextured default model\n")
        w("SELECT 'PROBLEM: extra still on race 22' AS problem, `ID`, `DisplayRaceID`\n")
        w("FROM `creaturedisplayinfoextra_dbc` WHERE `ID` IN (%s) AND `DisplayRaceID` = 22;\n"
          % ",".join(str(r[0]) for r in cde_rows))

    print("\nwrote %s" % OUTSQL)
    print("  displays %d  (extras %d, worgen remapped %d, new models %d)"
          % (len(cdi_rows), len(cde_rows), worgen_n, len(cmd_rows)))
    if notes:
        print("\nper-display notes:")
        for n in notes:
            print(n)
    print("\nmodel_info:")
    for d, b, c, g in mi_rows:
        print("  %-5d %-26s bounding=%-9s reach=%-9s gender=%d" % (d, NAMES.get(d, "?"), fmt(b), fmt(c), g))


main()
