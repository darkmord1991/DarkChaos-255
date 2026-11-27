#!/usr/bin/env python3
"""
gen_allied_race_dbcs.py - build every client DBC row for the Tier-2 allied races.

Generalised from the one-off Pandaren generator; driven entirely by the RACES table
below, so adding a fourth race (Earthen is the obvious candidate) is a data edit.

  race 24  Vulpera         (Horde)     <- Ascension donor race 19
  race 25  Zandalari Troll (Horde)     <- Ascension donor race 12
  race 26  Kul Tiran       (Alliance)  <- Ascension donor race 16

Donor art + DBCs live in K:\\Dark-Chaos\\retailextracts\\allied_races\\ (harvested from
ascension_live patch-CHA.MPQ / patch-M.MPQ). See ../00_README.md for the port notes.

WHAT IT TOUCHES  (all with .pre-allied.bak backups; refuses to run twice)
  CSV pipeline (Custom/CSV DBC/*.csv -> compile with csv2wdbc afterwards):
    CharSections, CharHairGeosets, CharacterFacialHairStyles,
    CreatureModelData, CreatureDisplayInfo
  Binary append (Custom/DBCs/*.dbc):
    ChrRaces, CharBaseInfo, CharStartOutfit, SkillRaceClassInfo

TRAPS BAKED IN (each cost real time on the Pandaren port - do not "simplify" them away)
  * Dangling texture references are CLEARED, not copied. Ascension's Zandalari male
    section-4 rows name a male naked-TORSO texture that exists in no client; every stock
    male race has pelvis-only underwear, so clearing reproduces the correct stock shape.
    The same rule protects against any other phantom reference in a donor.
  * `CharacterFacialHairStyles` CSV carries a synthetic ID column the live 8-field DBC
    does not have. compile_csvs() strips it - never ship csv2wdbc's raw output.
  * Locale name slots are CLEARED except enUS. The Pandaren rows still carry mojibake
    worgen strings because the clone copied them verbatim.
  * A record is rsz//4 INTS, which is not always the field count (CharStartOutfit packs
    race/class/sex/outfit into ONE int).
  * Player-race display ids above 65535 need the PlayerInfo::displayId_m/f uint32 fix
    (Player.h) or the server truncates them and segfaults on login.
"""
import csv
import io
import os
import shutil
import struct
import subprocess
import sys

REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
CSVDIR = os.path.join(REPO, "Custom", "CSV DBC")
DBCDIR = os.path.join(REPO, "Custom", "DBCs")
STAGE = r"K:\Dark-Chaos\retailextracts\allied_races"
DONOR = os.path.join(STAGE, "donor_dbc")
FILES = os.path.join(STAGE, "files")
CSV2WDBC = r"K:\Dark-Chaos\wow.export-main\tools\csv2wdbc.py"
BAK = ".pre-allied.bak"

RACES = [
    # collision replaces the donor's model row, which is shifted by a column for these two races:
    # see Races28to31/tools/fix_model_effect_scales.py.
    dict(race=24, donor=19, name="Vulpera", prefix="Vu", filestring="Vulpera",
         dirname="vulpera", faction=2, side=1, language=1, collision=("0.5556", "1.389"),
         cs_base=930000, cmd=(503902, 503903), cdi=(503912, 503913)),
    dict(race=25, donor=12, name="Zandalari Troll", prefix="Za", filestring="ZandalariTroll",
         dirname="zandalaritroll", faction=2, side=1, language=1, collision=("0.611112", "2.03128"),
         cs_base=935000, cmd=(503904, 503905), cdi=(503914, 503915)),
    dict(race=26, donor=16, name="Kul Tiran", prefix="Kt", filestring="KulTiran",
         dirname="kultiran", faction=1, side=0, language=7,
         cs_base=940000, cmd=(503906, 503907), cdi=(503916, 503917)),
]
CHG_BASE = 637          # CharHairGeosets ids (pandaren ended at 636)
CFHS_BASE = 529         # CharacterFacialHairStyles CSV ids (pandaren ended at 528)
CLONE_RACE = 12         # ChrRaces row cloned as the template (worgen: known-good playable)


# ------------------------------------------------------------------ dbc helpers
def read_dbc(path):
    d = open(path, "rb").read()
    magic, rows, fields, rsz, ssz = struct.unpack("<4siiii", d[:20])
    assert magic == b"WDBC", path
    sb = d[20 + rows * rsz:]
    n = rsz // 4                      # ints per record != field count for packed tables
    recs = [struct.unpack("<%di" % n, d[20 + i * rsz:20 + (i + 1) * rsz]) for i in range(rows)]

    def s(o):
        if o <= 0:
            return ""
        return sb[o:sb.index(b"\0", o)].decode("latin-1")
    return recs, s, fields, rsz, sb


def write_dbc(path, fields, rsz, recs, sb):
    with open(path, "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(recs), fields, rsz, len(sb)))
        for r in recs:
            f.write(r)
        f.write(sb)


def backup(path):
    if os.path.exists(path + BAK):
        raise SystemExit("REFUSING: %s exists - already ran? Restore the .bak files first." % (path + BAK))
    shutil.copy2(path, path + BAK)


def csv_read(name):
    with open(os.path.join(CSVDIR, name), encoding="utf-8-sig", newline="") as f:
        rd = csv.reader(f)
        hdr = next(rd)
        return hdr, list(rd)


def csv_append(name, rows):
    path = os.path.join(CSVDIR, name)
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    crlf = b"\r\n" in raw[:4096]
    quoted = raw[3 if bom else 0:4 if bom else 1] == b'"'
    backup(path)
    nl = "\r\n" if crlf else "\n"
    buf = io.StringIO()
    csv.writer(buf, quoting=csv.QUOTE_ALL if quoted else csv.QUOTE_MINIMAL,
               lineterminator=nl).writerows(rows)
    with open(path, "ab") as f:
        if not raw.endswith(b"\n"):
            f.write(nl.encode())
        f.write(buf.getvalue().encode("utf-8"))
    print("  %-32s +%d rows" % (name, len(rows)))


def have_file(rel):
    return os.path.exists(os.path.join(FILES, rel.replace("/", os.sep).replace("\\", os.sep)))


def main():
    dcs, dcs_s, _, _, _ = read_dbc(os.path.join(DONOR, "CharSections.dbc"))
    dchg, _, _, _, _ = read_dbc(os.path.join(DONOR, "CharHairGeosets.dbc"))
    dcfh, _, _, _, _ = read_dbc(os.path.join(DONOR, "CharacterFacialHairStyles.dbc"))
    dcdi, dcdi_s, _, _, _ = read_dbc(os.path.join(DONOR, "CreatureDisplayInfo.dbc"))
    dcmd, dcmd_s, _, _, _ = read_dbc(os.path.join(DONOR, "CreatureModelData.dbc"))
    dchr, dchr_s, _, _, _ = read_dbc(os.path.join(DONOR, "ChrRaces.dbc"))
    donor_chr = {r[0]: r for r in dchr}

    # ---- ceilings -----------------------------------------------------
    def cmax(name):
        _, rows = csv_read(name)
        return max(int(r[0]) for r in rows)
    assert cmax("CharSections.csv") < min(r["cs_base"] for r in RACES)
    assert cmax("CharHairGeosets.csv") < CHG_BASE
    assert cmax("CharacterFacialHairStyles.csv") < CFHS_BASE
    assert cmax("CreatureModelData.csv") < min(r["cmd"][0] for r in RACES)
    assert cmax("CreatureDisplayInfo.csv") < min(r["cdi"][0] for r in RACES)
    existing = {r[0] for r in read_dbc(os.path.join(DBCDIR, "ChrRaces.dbc"))[0]}
    for r in RACES:
        assert r["race"] not in existing, "race %d already present" % r["race"]
    print("ceilings ok")

    # ---- 1. CharSections ----------------------------------------------
    out, cleared, cleared_names = [], 0, set()
    for spec in RACES:
        rows = sorted([r for r in dcs if r[1] == spec["donor"]], key=lambda r: r[0])
        for i, r in enumerate(rows):
            tex = []
            for ci in (4, 5, 6):
                t = dcs_s(r[ci])
                if t and not have_file(t):
                    cleared += 1
                    cleared_names.add(t.lower())
                    t = ""            # phantom reference -> clear (see module docstring)
                tex.append(t)
            out.append([spec["cs_base"] + i, spec["race"], r[2], r[3],
                        tex[0], tex[1], tex[2], r[7], r[8], r[9]])
    csv_append("CharSections.csv", out)
    print("       dangling refs cleared: %d references over %d distinct textures"
          % (cleared, len(cleared_names)))
    for t in sorted(cleared_names)[:8]:
        print("         %s" % t.split(chr(92))[-1])

    # ---- 2. CharHairGeosets --------------------------------------------
    out, nid = [], CHG_BASE
    for spec in RACES:
        for r in sorted([r for r in dchg if r[1] == spec["donor"]], key=lambda r: r[0]):
            out.append([nid, spec["race"], r[2], r[3], r[4], r[5]])
            nid += 1
    csv_append("CharHairGeosets.csv", out)

    # ---- 3. CharacterFacialHairStyles ----------------------------------
    out, nid = [], CFHS_BASE
    for spec in RACES:
        for r in sorted([r for r in dcfh if r[0] == spec["donor"]], key=lambda r: (r[1], r[2])):
            out.append([nid, spec["race"], r[1], r[2], r[3], r[4], r[5], r[6], r[7]])
            nid += 1
    csv_append("CharacterFacialHairStyles.csv", out)

    # ---- 4/5. CreatureModelData + CreatureDisplayInfo -------------------
    cmd_hdr, _ = csv_read("CreatureModelData.csv")
    cdi_hdr, _ = csv_read("CreatureDisplayInfo.csv")
    CMD_FLOATS = {"ModelScale", "FootprintTextureLength", "FootprintTextureWidth",
                  "FootprintParticleScale", "CollisionWidth", "CollisionHeight", "MountHeight",
                  "GeoBoxMinX", "GeoBoxMinY", "GeoBoxMinZ", "GeoBoxMaxX", "GeoBoxMaxY",
                  "GeoBoxMaxZ", "WorldEffectScale", "AttachedEffectScale",
                  "MissileCollisionRadius", "MissileCollisionPush", "MissileCollisionRaise"}
    dcdi_by = {r[0]: r for r in dcdi}
    dcmd_by = {r[0]: r for r in dcmd}
    cmd_out, cdi_out = [], []
    for spec in RACES:
        dr = donor_chr[spec["donor"]]
        for sex, (donor_disp, new_cmd, new_cdi) in enumerate(
                ((dr[4], spec["cmd"][0], spec["cdi"][0]),
                 (dr[5], spec["cmd"][1], spec["cdi"][1]))):
            disp = dcdi_by[donor_disp]
            model = dcmd_by[disp[1]]
            sexdir = "Male" if sex == 0 else "Female"
            row = []
            for ci, col in enumerate(cmd_hdr):
                if col == "ID":
                    row.append(new_cmd)
                elif col == "ModelName":
                    row.append("Character\\%s\\%s\\%s%s.mdx"
                               % (spec["filestring"], sexdir, spec["filestring"], sexdir))
                elif col in CMD_FLOATS:
                    row.append(_f(model[ci]))
                else:
                    row.append(model[ci])
            if "collision" in spec:
                row[cmd_hdr.index("CollisionWidth")], row[cmd_hdr.index("CollisionHeight")] = spec["collision"]
                row[cmd_hdr.index("AttachedEffectScale")] = "1"
                row[cmd_hdr.index("MissileCollisionRadius")] = "0"
            cmd_out.append(row)
            row = []
            for ci, col in enumerate(cdi_hdr):
                if col == "ID":
                    row.append(new_cdi)
                elif col == "ModelID":
                    row.append(new_cmd)
                elif col == "CreatureModelScale":
                    row.append(_f(disp[ci]))
                elif col.startswith("TextureVariation") or col == "PortraitTextureName":
                    row.append(dcdi_s(disp[ci]))
                else:
                    row.append(disp[ci])
            cdi_out.append(row)
    csv_append("CreatureModelData.csv", cmd_out)
    csv_append("CreatureDisplayInfo.csv", cdi_out)

    # ---- 6. ChrRaces ----------------------------------------------------
    p = os.path.join(DBCDIR, "ChrRaces.dbc")
    recs, s, fields, rsz, sb = read_dbc(p)
    backup(p)
    base = next(r for r in recs if r[0] == CLONE_RACE)
    sb = bytearray(sb)

    def addstr(t):
        off = len(sb)
        sb.extend(t.encode("latin-1") + b"\0")
        return off
    newrecs = [struct.pack("<%di" % (rsz // 4), *r) for r in recs]
    for spec in RACES:
        v = list(base)
        v[0] = spec["race"]
        v[1] = 4                                  # playable
        v[2] = spec["faction"]
        v[4], v[5] = spec["cdi"]
        v[6] = addstr(spec["prefix"])
        v[7] = spec["language"]
        v[11] = addstr(spec["filestring"])
        v[12] = 0                                 # no intro cinematic
        v[13] = spec["side"]
        for i in range(14, 65):                   # clear every locale name slot...
            v[i] = 0
        v[14] = addstr(spec["name"])              # ...then set enUS only
        v[30] = 16712190                          # keep the stock locale masks
        v[47] = 16712172
        v[64] = 16712172
        dr = donor_chr[spec["donor"]]
        v[65], v[66], v[67] = addstr(dchr_s(dr[65])), addstr(dchr_s(dr[66])), addstr(dchr_s(dr[67]))
        v[68] = 0                                 # no expansion gate
        newrecs.append(struct.pack("<%di" % (rsz // 4), *v))
    write_dbc(p, fields, rsz, newrecs, bytes(sb))
    print("  %-32s +%d rows -> %d" % ("ChrRaces.dbc", len(RACES), len(newrecs)))

    # ---- 7. CharBaseInfo -------------------------------------------------
    p = os.path.join(DBCDIR, "CharBaseInfo.dbc")
    backup(p)
    # NOTE: do NOT use read_dbc here - CharBaseInfo's record is 2 BYTES (race, class), so
    # rsz//4 == 0 and the int unpack fails. Parse the header directly instead.
    raw = open(p + BAK, "rb").read()
    _, rowsn, fields, rsz, _ssz = struct.unpack("<4siiii", raw[:20])
    body = [raw[20 + i * rsz:20 + (i + 1) * rsz] for i in range(rowsn)]
    classes = sorted({b[1] for b in body if b[0] == 1})
    for spec in RACES:
        for c in classes:
            body.append(bytes([spec["race"], c]))
    write_dbc(p, fields, rsz, body, raw[20 + rowsn * rsz:])
    print("  %-32s +%d rows (classes %s)" % ("CharBaseInfo.dbc", len(RACES) * len(classes), classes))

    # ---- 8. CharStartOutfit ----------------------------------------------
    p = os.path.join(DBCDIR, "CharStartOutfit.dbc")
    raw = open(p, "rb").read()
    _, rowsn, fields, rsz, ssz = struct.unpack("<4siiii", raw[:20])
    backup(p)
    body = [raw[20 + i * rsz:20 + (i + 1) * rsz] for i in range(rowsn)]
    nid = max(struct.unpack("<i", b[:4])[0] for b in body) + 1
    added = 0
    for spec in RACES:
        src = 1 if spec["side"] == 0 else 2      # clone human for Alliance, orc for Horde
        for b in list(body):
            if b[4] == src:
                nb = bytearray(b)
                nb[0:4] = struct.pack("<i", nid)
                nb[4] = spec["race"]
                body.append(bytes(nb))
                nid += 1
                added += 1
    write_dbc(p, fields, rsz, body, raw[20 + rowsn * rsz:])
    print("  %-32s +%d rows" % ("CharStartOutfit.dbc", added))

    # ---- 9. SkillRaceClassInfo racemask sweep -----------------------------
    p = os.path.join(DBCDIR, "SkillRaceClassInfo.dbc")
    raw = bytearray(open(p, "rb").read())
    _, rowsn, fields, rsz, ssz = struct.unpack("<4siiii", bytes(raw[:20]))
    backup(p)
    A = sum(1 << (s["race"] - 1) for s in RACES if s["side"] == 0)
    H = sum(1 << (s["race"] - 1) for s in RACES if s["side"] == 1)
    changed = 0
    for i in range(rowsn):
        off = 20 + i * rsz + 8                    # field 2 = RaceMask
        mask, = struct.unpack("<i", bytes(raw[off:off + 4]))
        if mask <= 0:
            continue
        new = mask | (A if mask & 1 else 0) | (H if mask & 2 else 0)
        if new != mask:
            raw[off:off + 4] = struct.pack("<i", new)
            changed += 1
    open(p, "wb").write(bytes(raw))
    print("  %-32s %d rows re-masked" % ("SkillRaceClassInfo.dbc", changed))
    print("\nNow run: python %s --compile" % os.path.basename(__file__))


def _f(bits):
    return _fmt(struct.unpack("<f", struct.pack("<i", bits))[0])


def _fmt(x):
    if x == int(x):
        return str(int(x))
    return repr(round(x, 6)).rstrip("0").rstrip(".")


def compile_csvs():
    """Compile the five CSV-owned tables, with the CharacterFacialHairStyles fixup."""
    for t in ("CharSections", "CharHairGeosets", "CharacterFacialHairStyles",
              "CreatureModelData", "CreatureDisplayInfo"):
        out = os.path.join(DBCDIR, t + ".dbc")
        if t != "CharacterFacialHairStyles" and not os.path.exists(out + BAK):
            shutil.copy2(out, out + BAK)
        subprocess.check_call([sys.executable, CSV2WDBC, "--csv", os.path.join(CSVDIR, t + ".csv"),
                               "--out", out, "--table", t])
    # CharacterFacialHairStyles: the defs give a synthetic ID column the live DBC lacks.
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
