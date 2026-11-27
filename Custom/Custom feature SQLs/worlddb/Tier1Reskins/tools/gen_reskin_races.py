#!/usr/bin/env python3
r"""
gen_reskin_races.py - author the Tier-1 reskin races for this fork.

A RESKIN race is one that shares a stock race's MODEL and differs only in its textures, so unlike
the Pandaren / allied-race ports there is no model to downport at all:

  * The display ids point at the PARENT race's models, so the classic v264 model loads.
  * ChrRaces.ClientPrefix is the parent's (helms), but ClientFileString is the race's OWN: the
    create screen builds RACE_INFO_, ABILITY_INFO_, the icon key and the glue scene from it, and
    with the parent's value the race shows the parent's text, icon and scene (2026-11-01). The
    client also builds three asset paths from it, so ship them under the new name:
      World\Generic\PassiveDoodads\DeathSkeletons\<File><Sex>DeathSkeleton.m2 + 00.skin
      Interface\CharacterFrame\TemporaryPortrait-<Sex>-<File>.blp
      Interface\DressUpFrame\DressUpBackground-<File>1..4.blp
  * CharSections stores FULL texture paths, so the new appearance lives in its own folder
    (Character\<Race>\<Sex>\...) with no name collision against the parent.

That matters because these races' retail models are MD21 v274 and wxl-baker does NOT downport
character trees -- it copies them through. Raw MD21 character models T-pose. The reskin route
sidesteps the whole problem.

WHAT IT TOUCHES  (all with .pre-reskin.bak backups; refuses to run twice)
  CSV pipeline (Custom/CSV DBC/*.csv -> run again with --compile afterwards):
    CharSections, CharHairGeosets, CharacterFacialHairStyles
  Binary append (Custom/DBCs/*.dbc):
    ChrRaces, CharBaseInfo
  Writes an MPQ set-file for the harvested textures next to this script.

WARNING (2026-09-06): the retail SKIN / FACE / UNDERWEAR textures this script wires up are the
WoD+ body layout (1024x512, head on the right half).  The classic v264 model's compositor rejects
them -> flat GREEN body in-game.  Only the HAIR rows (section 3) and the parent-referencing facial
hair rows (section 2) from this pass are still live; sections 0/1/4 are regenerated in the classic
layout by gen_darkiron_classic_textures.py (ids 951000+).  Run that after this one.

Retail's texture set for these races, verified against the harvest:
  skin       1 variation x N colours          -> section 0
  faceupper  M variations x N colours         -> section 1, and there is NO facelower:
             retail merged it into the skin after BfA, so TextureName_1 stays empty and the
             base skin supplies the lower face.
  hair       1 variation x N colours          -> section 3, reused across every parent hair
             STYLE, since the geometry comes from CharHairGeosets and the texture is a ramp.
  pelvis/torso underwear                      -> section 4. Male rows are pelvis-only: every
             stock male race leaves the torso slot empty.
  facial hair: none shipped, so section 2 rows reference the PARENT's beard textures.

Flags are the stock create-screen values, read out of the parent's own rows:
  section 0/2/3/4 -> 17, section 1 -> 1.  (5 marks death-knight variants, 8 the extra set.)
"""
import csv
import io
import os
import re
import shutil
import struct
import subprocess
import sys

REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
CSVDIR = os.path.join(REPO, "Custom", "CSV DBC")
DBCDIR = os.path.join(REPO, "Custom", "DBCs")
CSV2WDBC = r"K:\Dark-Chaos\wow.export-main\tools\csv2wdbc.py"
HERE = os.path.dirname(os.path.abspath(__file__))
BAK = ".pre-reskin.bak"

# One row per race. Adding the rest of Tier-1 is a data edit: they all harvest to the same shape.
# prefix MUST be the PARENT's ClientPrefix: the client builds every helm model name as
#   Item\ObjectComponents\Head\<model>_<prefix><M|F>.m2
# and there are no <model>_Di*.m2 files anywhere, so a race-specific prefix puts an ErrorCube on
# every head slot (2026-09-06).
RACES = [
    dict(race=27, name="Dark Iron Dwarf", prefix="Dw", dirname="darkirondwarf",
         parent=3, parent_dir="Dwarf", filestring="DarkIronDwarf",
         faction=3, side=0, language=7, male_disp=53, female_disp=54,
         harvest=r"K:\tmp\t1_darkirondwarf", deploy_dir="DarkIronDwarf",
         cs_base=950000, chg_base=700, cfhs_base=1100),
]
CLONE_RACE = 3          # ChrRaces template: dwarf, a known-good playable Alliance row
SECTION_FLAGS = {0: 17, 1: 1, 2: 17, 3: 17, 4: 17}


# ------------------------------------------------------------------ dbc / csv helpers
def read_dbc(path):
    b = open(path, "rb").read()
    magic, rows, fields, rsz, ssz = struct.unpack_from("<4s4I", b, 0)
    assert magic == b"WDBC", path
    recs = [struct.unpack_from("<%di" % (rsz // 4), b, 20 + r * rsz) for r in range(rows)]
    return recs, b[20 + rows * rsz:], fields, rsz, ssz


def write_dbc(path, fields, rsz, recs, sb):
    with open(path, "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(recs), fields, rsz, len(sb)))
        for r in recs:
            f.write(struct.pack("<%di" % (rsz // 4), *r))
        f.write(sb)


def backup(path):
    if not os.path.exists(path + BAK):
        shutil.copy2(path, path + BAK)


def csv_read(name):
    with open(os.path.join(CSVDIR, name), encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f)
        return next(rd), [r for r in rd]


def csv_append(name, rows):
    p = os.path.join(CSVDIR, name)
    backup(p)
    buf = io.StringIO()
    csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(rows)
    with io.open(p, "a", encoding="utf-8", newline="") as f:
        f.write(buf.getvalue())
    print("  %-34s +%d rows" % (name, len(rows)))


# ------------------------------------------------------------------ texture scan
def scan_textures(spec, sex_name):
    """Group the harvested BLPs by CharSections section, variation and colour."""
    d = os.path.join(spec["harvest"], "character", spec["dirname"], sex_name)
    dn = spec["dirname"]
    pats = {
        0: re.compile(r"^%s%sskin(\d\d)_(\d\d)\.blp$" % (dn, sex_name)),
        1: re.compile(r"^%s%sfaceupper(\d\d)_(\d\d)\.blp$" % (dn, sex_name)),
        'pelvis': re.compile(r"^%s%snakedpelvisskin(\d\d)_(\d\d)\.blp$" % (dn, sex_name)),
        'torso': re.compile(r"^%s%snakedtorsoskin(\d\d)_(\d\d)\.blp$" % (dn, sex_name)),
    }
    got = {k: {} for k in pats}
    for f in sorted(os.listdir(d)):
        low = f.lower()
        for k, rx in pats.items():
            m = rx.match(low)
            if m:
                got[k][(int(m.group(1)), int(m.group(2)))] = f
                break
    return got


def scan_hair(spec):
    """Hair textures are RACE-level, like stock's Character\\Dwarf\\Hair00_00.blp.

    Retail ships them under the male folder only and names them without a sex, so scanning
    per-sex leaves the female with no hair at all. Both sexes reference the one race-level set.
    """
    rx = re.compile(r"^%shair(\d\d)_(\d\d)\.blp$" % spec["dirname"])
    got = {}
    for sex_name in ("male", "female"):
        d = os.path.join(spec["harvest"], "character", spec["dirname"], sex_name)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            m = rx.match(f.lower())
            if m:
                got.setdefault((int(m.group(1)), int(m.group(2))), os.path.join(d, f))
    return got


def tex_path(spec, sex_name, filename):
    return "Character\\%s\\%s\\%s" % (spec["deploy_dir"], sex_name.capitalize(), filename)


def hair_path(spec, filename):
    return "Character\\%s\\%s" % (spec["deploy_dir"], filename)


# ------------------------------------------------------------------ main
def main():
    cs_hdr, cs_rows = csv_read("CharSections.csv")
    chg_hdr, chg_rows = csv_read("CharHairGeosets.csv")
    cfh_hdr, cfh_rows = csv_read("CharacterFacialHairStyles.csv")
    ix = {n: i for i, n in enumerate(cs_hdr)}

    existing = {int(r[0]) for r in read_dbc(os.path.join(DBCDIR, "ChrRaces.dbc"))[0]}
    for spec in RACES:
        if spec["race"] in existing:
            raise SystemExit("REFUSING: ChrRaces already has race %d" % spec["race"])

    cs_out, chg_out, cfh_out, setlines = [], [], [], []

    for spec in RACES:
        cs_id, chg_id, cfh_id = spec["cs_base"], spec["chg_base"], spec["cfhs_base"]
        parent = str(spec["parent"])
        hair = scan_hair(spec)
        for (var, col), src in sorted(hair.items()):
            setlines.append("%s=%s" % (src, hair_path(spec, os.path.basename(src))))

        for sex, sex_name in ((0, "male"), (1, "female")):
            tex = scan_textures(spec, sex_name)

            def row(section, var, col, t1, t2="", t3=""):
                nonlocal cs_id
                r = [""] * len(cs_hdr)
                r[ix["ID"]] = cs_id
                r[ix["RaceID"]] = spec["race"]
                r[ix["SexID"]] = sex
                r[ix["BaseSection"]] = section
                r[ix["TextureName_1"]] = t1
                r[ix["TextureName_2"]] = t2
                r[ix["TextureName_3"]] = t3
                r[ix["Flags"]] = SECTION_FLAGS[section]
                r[ix["VariationIndex"]] = var
                r[ix["ColorIndex"]] = col
                cs_id += 1
                cs_out.append(r)

            # -- section 0: skin
            for (var, col), f in sorted(tex[0].items()):
                row(0, var, col, tex_path(spec, sex_name, f))
            skin_colors = sorted({c for _, c in tex[0]})

            # -- section 1: face. No facelower exists, so slot 1 stays empty.
            for (var, col), f in sorted(tex[1].items()):
                row(1, var, col, "", tex_path(spec, sex_name, f))

            # -- section 2: facial hair, borrowed from the parent (none is shipped)
            for r in cs_rows:
                if r[ix["RaceID"]] == parent and int(r[ix["SexID"]]) == sex \
                        and int(r[ix["BaseSection"]]) == 2 and r[ix["Flags"]] == "17":
                    row(2, int(r[ix["VariationIndex"]]), int(r[ix["ColorIndex"]]),
                        r[ix["TextureName_1"]], r[ix["TextureName_2"]], r[ix["TextureName_3"]])

            # -- section 3: hair. One race-level texture set reused across every parent hair
            #    STYLE; the geometry comes from CharHairGeosets, so the texture only carries
            #    the colour.
            hair_colors = sorted({c for _, c in hair})
            parent_hair_vars = sorted({int(r[ix["VariationIndex"]]) for r in cs_rows
                                       if r[ix["RaceID"]] == parent and int(r[ix["SexID"]]) == sex
                                       and int(r[ix["BaseSection"]]) == 3})
            for var in parent_hair_vars:
                for col in hair_colors:
                    row(3, var, col, hair_path(spec, os.path.basename(hair[(0, col)])))

            # -- section 4: underwear. Male is pelvis-only, matching every stock male race.
            for (var, col), f in sorted(tex['pelvis'].items()):
                torso = tex['torso'].get((var, col))
                row(4, var, col, tex_path(spec, sex_name, f),
                    tex_path(spec, sex_name, torso) if (torso and sex == 1) else "")

            # -- stage every harvested BLP for the MPQ
            hair_names = {os.path.basename(v).lower() for v in hair.values()}
            src = os.path.join(spec["harvest"], "character", spec["dirname"], sex_name)
            for f in sorted(os.listdir(src)):
                if f.lower().endswith(".blp") and f.lower() not in hair_names:
                    setlines.append("%s=%s" % (os.path.join(src, f),
                                               tex_path(spec, sex_name, f)))

            print("  %s %-7s skin=%d face=%d hair=%d(styles %d) underwear=%d"
                  % (spec["name"], sex_name, len(tex[0]), len(tex[1]),
                     len(hair_colors), len(parent_hair_vars), len(tex['pelvis'])))

        # -- CharHairGeosets / CharacterFacialHairStyles cloned from the parent
        chg_ix = {n: i for i, n in enumerate(chg_hdr)}
        for r in chg_rows:
            if r[chg_ix["RaceID"]] == parent:
                n = list(r)
                n[0] = chg_id
                n[chg_ix["RaceID"]] = spec["race"]
                chg_id += 1
                chg_out.append(n)
        cfh_ix = {n: i for i, n in enumerate(cfh_hdr)}
        for r in cfh_rows:
            if r[cfh_ix["RaceID"]] == parent:
                n = list(r)
                n[0] = cfh_id
                n[cfh_ix["RaceID"]] = spec["race"]
                cfh_id += 1
                cfh_out.append(n)

    csv_append("CharSections.csv", cs_out)
    csv_append("CharHairGeosets.csv", chg_out)
    csv_append("CharacterFacialHairStyles.csv", cfh_out)

    # ---- ChrRaces: clone the parent row, then override identity ----
    p = os.path.join(DBCDIR, "ChrRaces.dbc")
    backup(p)
    recs, sb, fields, rsz, ssz = read_dbc(p)
    sb = bytearray(sb)

    def addstr(t):
        if not t:
            return 0
        off = len(sb)
        sb.extend(t.encode("utf-8") + b"\0")
        return off

    tmpl = next(r for r in recs if r[0] == CLONE_RACE)
    for spec in RACES:
        n = list(tmpl)
        n[0] = spec["race"]
        n[2] = spec["faction"]
        n[4] = spec["male_disp"]
        n[5] = spec["female_disp"]
        n[6] = addstr(spec["prefix"])
        n[7] = spec["language"]
        n[11] = addstr(spec["filestring"])
        n[12] = 0                       # no intro cinematic of its own
        n[13] = spec["side"]
        for slot in range(14, 65):      # every locale name slot; enUS only, rest cleared
            n[slot] = 0
        n[14] = addstr(spec["name"])
        recs.append(n)
    recs.sort(key=lambda r: r[0])
    write_dbc(p, fields, rsz, recs, bytes(sb))
    print("  %-34s +%d rows -> %d" % ("ChrRaces.dbc", len(RACES), len(recs)))

    # ---- CharBaseInfo: race/class pairs, cloned from the parent ----
    p = os.path.join(DBCDIR, "CharBaseInfo.dbc")
    backup(p)
    b = open(p, "rb").read()
    magic, rows, fields, rsz, ssz = struct.unpack_from("<4s4I", b, 0)
    pairs = [(b[20 + i * rsz], b[20 + i * rsz + 1]) for i in range(rows)]
    added = 0
    for spec in RACES:
        for race, klass in [x for x in pairs if x[0] == spec["parent"]]:
            pairs.append((spec["race"], klass))
            added += 1
    with open(p, "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(pairs), fields, rsz, 1))
        for race, klass in pairs:
            f.write(bytes((race, klass)))
        f.write(b"\0")
    print("  %-34s +%d rows -> %d" % ("CharBaseInfo.dbc", added, len(pairs)))

    setfile = os.path.join(HERE, "reskin_textures.set")
    io.open(setfile, "w", encoding="utf-8", newline="\n").write("\n".join(setlines) + "\n")
    print("  %-34s %d files" % ("reskin_textures.set", len(setlines)))
    print("\nNext: rerun with --compile, then pack reskin_textures.set into a patch archive.")


def compile_csvs():
    """Compile the three CSV-owned tables, with the CharacterFacialHairStyles fixup."""
    for t in ("CharSections", "CharHairGeosets", "CharacterFacialHairStyles"):
        out = os.path.join(DBCDIR, t + ".dbc")
        if t != "CharacterFacialHairStyles":
            backup(out)
        subprocess.check_call([sys.executable, CSV2WDBC, "--csv", os.path.join(CSVDIR, t + ".csv"),
                               "--out", out, "--table", t])
    # The defs give CharacterFacialHairStyles a synthetic ID column the live DBC lacks.
    hdr, rows = csv_read("CharacterFacialHairStyles.csv")
    assert hdr[0] == "ID" and len(hdr) == 9, hdr
    p = os.path.join(DBCDIR, "CharacterFacialHairStyles.dbc")
    with open(p, "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(rows), 8, 32, 1))
        for r in rows:
            f.write(struct.pack("<8i", *[int(x) for x in r[1:]]))
        f.write(b"\0")
    print("CharacterFacialHairStyles.dbc rebuilt as 8-field: %d rows" % len(rows))


if __name__ == "__main__":
    if "--compile" in sys.argv:
        compile_csvs()
    else:
        main()
