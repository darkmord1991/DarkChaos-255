#!/usr/bin/env python3
"""Downport the creature displays the map-751 Lordaeron extension needs.

260 imported templates fail to load with "has no model defined in
creature_template_model". The table is NOT empty -- the core DISCARDS model rows
whose CreatureDisplayID is absent from CreatureDisplayInfo.dbc, and a template
left with no surviving model reports that message per spawn.

323 display ids >30000 are referenced by the band; 303 are missing. This script
downports all 303 from the Cata 4.3.4 client.

Why the Cata ids are reused verbatim
------------------------------------
None of the 303 collide with anything in DC's CreatureDisplayInfo, so they ship
under their ORIGINAL ids. That means `creature_template_model` needs no remap at
all -- the rows already point at these numbers. Only one CreatureDisplayInfoExtra
id collides (21831) and it alone is reallocated.

The three routes
----------------
* **plain (65)** -- ExtendedDisplayInfoID = 0. A CreatureDisplayInfo row, plus a
  CreatureModelData row where DC has none for that model path.
* **stock-race characters (204)** -- races 1-11/13/18/20 all have a ChrRaces row
  in this client, so these take the native CreatureDisplayInfoExtra + BakeName
  route. Cata's CreatureDisplayInfoExtra is already 21 fields, identical in
  layout to ours, so the rows copy across essentially unchanged.
* **worgen (34)** -- race 22 has NO ChrRaces row in this client (verified: both
  the server's and the client's ChrRaces stop at 21), so the Extra route is dead
  for them. They are rebound onto the DC WorgenNPC model copies (500961 female /
  500962 male) whose texture slots are MONSTER slots, with the bake bound through
  TextureVariation_1. TV_2/TV_3 carry the per-model skin/cape values, without
  which the NPC renders white. A MONSTER slot never reads BakedNpcTextures, so
  those bakes are also packed next to the model.

Layout verification (done, not assumed)
---------------------------------------
* CreatureDisplayInfo: Cata is 17 fields, ours 16, and the extra one is TRAILING
  -- 24,152 of 25,571 shared rows are identical across all 16 (94.5%); the rest
  is Blizzard data drift. CreatureModelAlpha is an INT, not a float.
* CreatureDisplayInfoExtra: both 21 fields, same order.
* CreatureModelData: Cata 31 vs our 28, extras trailing. Note our custom band
  writes ModelName with a `.m2` extension (1,616 of 1,622 rows) while stock rows
  use `.mdx`; new rows follow the custom-band convention.

Dangling references are zeroed rather than shipped: SoundID 81, NPCSoundID
362/381 and ParticleColorID 588 exist in Cata but not here.

Outputs (nothing is applied):
  Custom/CSV DBC/CreatureDisplayInfo.csv        +303 rows
  Custom/CSV DBC/CreatureDisplayInfoExtra.csv   +238 rows
  Custom/CSV DBC/CreatureModelData.csv          + 14 rows
  Plaguelands/76_creature_displays.sql          overlay tables + creature_model_info
"""
import os, sys, json, csv, struct, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.environ.get("SCRATCH", "")
CSVDIR = os.path.normpath(os.path.join(HERE, "..", "..", "CSV DBC"))
OUTSQL = os.path.normpath(os.path.join(HERE, "..", "..", "Custom feature SQLs",
                                       "worlddb", "Plaguelands", "76_creature_displays.sql"))

WORGEN_MODEL = {0: 500962, 1: 500961}
# Per-model slot values, read off the working city displays on the SAME model.
# The bake fills MONSTER1 only; leaving 2/3 empty renders white cloaks/robes.
WORGEN_SLOTS = {500962: ("WorgenMaleSkin00_00_Extra", "cape_gilneas_a_01"),
                500961: ("WorgenFemaleSkin00_00_Extra", "cape_gilneas_a_01")}
DEAD_SOUND, DEAD_NPCSOUND, DEAD_PARTICLE = {81}, {362, 381}, {588}
EXTRA_ID_REMAP = {}          # filled for colliding extra ids
NEW_EXTRA_BASE = 503725


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
        if not o or o >= len(self.sb):
            return ""
        e = self.sb.find(b"\0", o)
        return self.sb[o:e if e >= 0 else None].decode("utf-8", "replace")


def i32(w):
    return struct.unpack("<i", struct.pack("<I", w))[0]


def f32(w):
    return struct.unpack("<f", struct.pack("<I", w))[0]


def fmt(v):
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
    shutil.copyfile(path, path + ".pre_map751_displays.bak")
    body = text if text.endswith("\n") else text + "\n"
    out = body + "\n".join(",".join(csv_cell(c) for c in r) for r in rows) + "\n"
    open(path, "wb").write(b"\xef\xbb\xbf" + out.encode("utf-8"))
    print("  %-32s %5d -> %5d rows (+%d %s)" % (name, len(existing), len(existing) + len(rows), len(rows), label))


def main():
    plan = json.load(open(os.path.join(SP, "plan_displays.json")))
    donors = json.load(open(os.path.join(SP, "model_info_donors.json")))
    cdi = Dbc(os.path.join(SP, "cata_veh", "CreatureDisplayInfo.dbc"))
    cde = Dbc(os.path.join(SP, "cata_veh", "CreatureDisplayInfoExtra.dbc"))
    cmd = Dbc(os.path.join(SP, "cata_veh", "CreatureModelData.dbc"))

    # Read the PRE-APPEND state. Once the CSVs carry our rows, reading them back
    # would make every Cata extra id collide with itself and reallocate all 204 --
    # and would also let the new displays act as their own creature_model_info
    # donors. Re-running for the SQL alone must reproduce the ids already shipped,
    # so prefer the backup this script wrote on its first pass.
    def rd_orig(name):
        p = os.path.join(CSVDIR, name)
        bak = p + ".pre_map751_displays.bak"
        src = bak if os.path.exists(bak) else p
        return list(csv.DictReader(open(src, encoding="utf-8-sig"))), os.path.basename(src)

    dc_cdi, s1 = rd_orig("CreatureDisplayInfo.csv")
    cmd_list, s2 = rd_orig("CreatureModelData.csv")
    cde_list, s3 = rd_orig("CreatureDisplayInfoExtra.csv")
    print("  baseline: %s / %s / %s" % (s1, s2, s3))
    dc_cmd = {int(r["ID"]): r for r in cmd_list}
    have_extra = {int(r["ID"]) for r in cde_list}
    model_of_display = {int(r["ID"]): int(r["ModelID"]) for r in dc_cdi}
    siblings = {}
    for d, m in model_of_display.items():
        siblings.setdefault(m, []).append(d)

    extras_by_cata = {v["cata_id"]: v for v in plan["new_extras"].values()}
    nxt = NEW_EXTRA_BASE
    for cid in sorted(extras_by_cata):
        if cid in have_extra:
            while nxt in have_extra:
                nxt += 1
            EXTRA_ID_REMAP[cid] = nxt
            nxt += 1

    CDI_COLS = ["ID", "ModelID", "SoundID", "ExtendedDisplayInfoID", "CreatureModelScale",
                "CreatureModelAlpha", "TextureVariation_1", "TextureVariation_2",
                "TextureVariation_3", "PortraitTextureName", "BloodLevel", "BloodID",
                "NPCSoundID", "ParticleColorID", "CreatureGeosetData", "ObjectEffectPackageID"]
    CDE_COLS = ["ID", "DisplayRaceID", "DisplaySexID", "SkinID", "FaceID", "HairStyleID",
                "HairColorID", "FacialHairID"] + ["NPCItemDisplay_%d" % (i + 1) for i in range(11)] + \
               ["Flags", "BakeName"]
    # The overlay TABLE spells the item-display columns without the underscore that
    # the CSV header uses. Everything else matches. Verified against
    # INFORMATION_SCHEMA for all three tables -- do not assume the CSV header and the
    # table share names (this cost a 1054 at apply time once already).
    CDE_SQL_COLS = CDE_COLS[:8] + ["NPCItemDisplay%d" % (i + 1) for i in range(11)] + ["Flags", "BakeName"]

    CMD_COLS = ["ID", "Flags", "ModelName", "SizeClass", "ModelScale", "BloodID",
                "FootprintTextureID", "FootprintTextureLength", "FootprintTextureWidth",
                "FootprintParticleScale", "FoleyMaterialID", "FootstepShakeSize",
                "DeathThudShakeSize", "SoundID", "CollisionWidth", "CollisionHeight",
                "MountHeight", "GeoBoxMinX", "GeoBoxMinY", "GeoBoxMinZ", "GeoBoxMaxX",
                "GeoBoxMaxY", "GeoBoxMaxZ", "WorldEffectScale", "AttachedEffectScale",
                "MissileCollisionRadius", "MissileCollisionPush", "MissileCollisionRaise"]

    # ---- CreatureModelData rows -------------------------------------------
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

    # ---- CreatureDisplayInfo + Extra + creature_model_info -----------------
    cdi_rows, cde_rows, mi_rows = [], [], []
    seen_extra = set()
    worgen_n = 0
    for p in sorted(plan["plan"], key=lambda x: x["cata_display"]):
        d = p["cata_display"]
        src = cdi.rows[d]
        model = p["dc_model"]
        extra_cata = p["cata_extra"]
        ext_row = extras_by_cata.get(extra_cata) if extra_cata else None
        is_worgen = bool(ext_row and ext_row["race"] == 22)

        tv = [cdi.s(src[6]), cdi.s(src[7]), cdi.s(src[8])]
        if is_worgen:
            model = WORGEN_MODEL[ext_row["sex"]]
            bake = ext_row["bake"]
            base = bake[:-4] if bake.lower().endswith(".blp") else bake
            tv = [base, WORGEN_SLOTS[model][0], WORGEN_SLOTS[model][1]]
            ext_id = 0
            worgen_n += 1
        elif ext_row:
            ext_id = EXTRA_ID_REMAP.get(extra_cata, extra_cata)
            if extra_cata not in seen_extra:
                seen_extra.add(extra_cata)
                er = cde.rows[extra_cata]
                cde_rows.append([ext_id] + [i32(er[j]) for j in range(1, 20)] + [cde.s(er[20])])
        else:
            ext_id = 0

        snd = i32(src[2]);  snd = 0 if snd in DEAD_SOUND else snd
        npcs = i32(src[12]); npcs = 0 if npcs in DEAD_NPCSOUND else npcs
        part = i32(src[13]); part = 0 if part in DEAD_PARTICLE else part

        cdi_rows.append([d, model, snd, ext_id, f32(src[4]), i32(src[5]),
                         tv[0], tv[1], tv[2], cdi.s(src[9]), i32(src[10]), i32(src[11]),
                         npcs, part, i32(src[14]), i32(src[15])])

        # creature_model_info -- the 4th layer. Inherit from an existing display on
        # the SAME model; a blanket 0.306/1.5 is wrong for half of them.
        br = cr = None
        for s in siblings.get(model, []):
            v = donors.get(str(s))
            if v and v[0]:
                br, cr = v[0], v[1]
                break
        if br is None:
            # no sibling: fall back to the model's own collision width, which is
            # what the shipped rows track closely (0.6112 -> 0.611 bounding).
            row = dc_cmd.get(model)
            if row:
                br = float(row["CollisionWidth"] or 0) or 0.306
                cr = 1.5
            else:
                mr = [r for r in cmd_rows if r[0] == model]
                br = (mr[0][14] if mr else 0.306) or 0.306
                cr = 1.5
        gender = ext_row["sex"] if ext_row and ext_row["sex"] in (0, 1) else 2
        mi_rows.append((d, round(br, 6), round(cr, 6), gender))

    print("generating:")
    if os.environ.get("SQL_ONLY"):
        print("  SQL_ONLY set -- CSVs left untouched (they are already appended)")
    else:
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

    with open(OUTSQL, "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("-- 76_creature_displays.sql -- map 751 Lordaeron extension, DB step 15.\n--\n")
        w("-- GENERATED by Custom/Documentation/scripts/gen_map751_creature_displays.py --\n")
        w("-- do not hand-edit; re-run the generator instead.\n--\n")
        w("-- Closes the \"has no model defined in creature_template_model\" errors for the\n")
        w("-- %d templates that had no loadable display. The table was never empty -- the\n" % 260)
        w("-- core discards model rows whose CreatureDisplayID is missing from\n")
        w("-- CreatureDisplayInfo.dbc, which is the real gap.\n--\n")
        w("-- %d displays are downported from the Cata 4.3.4 client UNDER THEIR ORIGINAL\n" % len(cdi_rows))
        w("-- IDS (none collided), so `creature_template_model` needs NO remap.\n--\n")
        w("-- Two halves, and BOTH are needed:\n")
        w("--   1. the *_dbc overlay tables below (server: LOAD_DBC merges them at boot)\n")
        w("--   2. the recompiled DBCs in Custom/DBCs, deployed to the client patches AND\n")
        w("--      to the server's data/dbc (the client renders from its own copy)\n--\n")
        w("-- creature_model_info is the FOURTH layer and is NOT optional: without a row\n")
        w("-- the creature still refuses to load, with the SAME misleading message -- the\n")
        w("-- failing call is GetCreatureModelRandomGender. Values are inherited from an\n")
        w("-- existing display on the same ModelID rather than defaulted, because bounding\n")
        w("-- radius varies a lot per skeleton (0.208 human female .. 0.8725 tauren).\n\n")

        w("-- ---------------------------------------------------------------------------\n")
        w("-- 1. CreatureModelData overlay (%d new models)\n" % len(cmd_rows))
        w("-- ---------------------------------------------------------------------------\n")
        w(ins("creaturemodeldata_dbc", CMD_COLS, cmd_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 2. CreatureDisplayInfoExtra overlay (%d character bakes)\n" % len(cde_rows))
        w("-- ---------------------------------------------------------------------------\n")
        w(ins("creaturedisplayinfoextra_dbc", CDE_SQL_COLS, cde_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 3. CreatureDisplayInfo overlay (%d displays)\n" % len(cdi_rows))
        w("-- ---------------------------------------------------------------------------\n")
        w(ins("creaturedisplayinfo_dbc", CDI_COLS, cdi_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 4. creature_model_info -- the layer that actually gates spawning\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("DELETE FROM `creature_model_info` WHERE `DisplayID` IN (%s);\n\n"
          % ",".join(str(r[0]) for r in mi_rows))
        w("INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`) VALUES\n")
        w(",\n".join("(%d, %s, %s, %d, 0)" % (d, fmt(b), fmt(c), g) for d, b, c, g in mi_rows) + ";\n\n")

        w("-- ---------------------------------------------------------------------------\n-- Verification\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("SELECT 'display rows (want %d)' AS what, COUNT(*) AS n FROM `creaturedisplayinfo_dbc`\n" % len(cdi_rows))
        w("WHERE `ID` BETWEEN 30001 AND 39426\n")
        w("UNION ALL SELECT 'extra rows (want %d)', COUNT(*) FROM `creaturedisplayinfoextra_dbc`\n" % len(cde_rows))
        w("WHERE `ID` IN (%s)\n" % ",".join(str(r[0]) for r in cde_rows))
        w("UNION ALL SELECT 'model rows (want %d)', COUNT(*) FROM `creaturemodeldata_dbc`\n" % len(cmd_rows))
        w("WHERE `ID` IN (%s)\n" % ",".join(str(r[0]) for r in cmd_rows))
        w("UNION ALL SELECT 'model_info rows (want %d)', COUNT(*) FROM `creature_model_info`\n" % len(mi_rows))
        w("WHERE `DisplayID` IN (%s);\n\n" % ",".join(str(r[0]) for r in mi_rows))
        w("-- must be zero: an imported template whose every display is still unknown\n")
        w("SELECT 'PROBLEM: template with no resolvable display' AS problem, t.`entry`, t.`name`\n")
        w("FROM `creature_template` t\n")
        w("WHERE t.`entry` BETWEEN 4100000 AND 4199999\n")
        w("  AND NOT EXISTS (SELECT 1 FROM `creature_template_model` m\n")
        w("                  JOIN `creature_model_info` i ON i.`DisplayID` = m.`CreatureDisplayID`\n")
        w("                  WHERE m.`CreatureID` = t.`entry`);\n")

    print("\nwrote %s" % OUTSQL)
    print("  displays %d (worgen %d, stock-race characters %d, plain %d)"
          % (len(cdi_rows), worgen_n, len(cde_rows), len(cdi_rows) - worgen_n - len(cde_rows)))
    print("  extras %d  models %d  model_info %d" % (len(cde_rows), len(cmd_rows), len(mi_rows)))
    if EXTRA_ID_REMAP:
        print("  extra ids reallocated (collision): %s" % EXTRA_ID_REMAP)


main()
