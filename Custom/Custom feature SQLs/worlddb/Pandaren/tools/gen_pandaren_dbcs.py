#!/usr/bin/env python3
"""
gen_pandaren_dbcs.py - generate all client/server DBC rows for playable Pandaren (races 22/23).

Donor: Ascension race 20 (K:\ascension_live patch-M.MPQ DBCs, staged permanently at
retailextracts/pandaren_playable/donor_dbc/). Two ChrRaces rows are emitted per the
faction decision: 22 = Pandaren (Alliance), 23 = Pandaren (Horde). Art/models are shared;
only the race-keyed customization rows duplicate.

What it edits (all with .pre-pandaren.bak backups, idempotent - refuses to run twice):
  CSV pipeline (Custom/CSV DBC/*.csv, then compile with csv2wdbc):
    CharSections.csv               +2728 rows  (ids 920000+ / 925000+)
    CharHairGeosets.csv            +74 rows    (ids 563..636)
    CharacterFacialHairStyles.csv  +222 rows   (ids 307..528)
    CreatureModelData.csv          +2 rows     (503900 M / 503901 F)
    CreatureDisplayInfo.csv        +2 rows     (503910 M / 503911 F)
  Binary append (Custom/DBCs/*.dbc):
    ChrRaces.dbc                   +2 rows     (22 Alliance / 23 Horde)
    CharBaseInfo.dbc               +20 rows    (2 races x 10 classes, cloned from race 1)
    CharStartOutfit.dbc            +40 rows    (race 1 rows -> 22, race 2 rows -> 23)
  Server variant (retailextracts/pandaren_playable/dbc_server/):
    same 8 tables appended onto Server/data/dbc current copies (server CharSections is an
    older 10,988-row file; it gets ONLY the pandaren rows, not the client's HD rows).

ID allocation is asserted against current ceilings before any write.
"""
import csv
import io
import os
import shutil
import struct
import sys

REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
CSVDIR = os.path.join(REPO, "Custom", "CSV DBC")
DBCDIR = os.path.join(REPO, "Custom", "DBCs")
SRVDBC = r"K:\Dark-Chaos\Server\data\dbc"
STAGE = r"K:\Dark-Chaos\retailextracts\pandaren_playable"
DONOR = os.path.join(STAGE, "donor_dbc")
SRVOUT = os.path.join(STAGE, "dbc_server")

DONOR_RACE = 20
RACE_A, RACE_H = 22, 23
# CharSections id bases (client max 911363)
CS_BASE = {RACE_A: 920000, RACE_H: 925000}
CHG_BASE = 563          # CharHairGeosets ids (current max 562), 37 per race
CFHS_BASE = 307         # CharacterFacialHairStyles ids (csv max 306), 111 per race
CMD_M, CMD_F = 503900, 503901
CDI_M, CDI_F = 503910, 503911
CMD_FLOATS = {"ModelScale", "FootprintTextureLength", "FootprintTextureWidth",
              "FootprintParticleScale", "CollisionWidth", "CollisionHeight", "MountHeight",
              "GeoBoxMinX", "GeoBoxMinY", "GeoBoxMinZ", "GeoBoxMaxX", "GeoBoxMaxY",
              "GeoBoxMaxZ", "WorldEffectScale", "AttachedEffectScale",
              "MissileCollisionRadius", "MissileCollisionPush", "MissileCollisionRaise"}
CDI_FLOATS = {"CreatureModelScale"}


def read_dbc(path):
    d = open(path, "rb").read()
    magic, rows, fields, rsz, ssz = struct.unpack("<4siiii", d[:20])
    assert magic == b"WDBC", path
    recs = [d[20 + i * rsz:20 + (i + 1) * rsz] for i in range(rows)]
    sblock = d[20 + rows * rsz:]
    return rows, fields, rsz, recs, sblock


def dbc_string(sblock, off):
    if off <= 0:
        return ""
    return sblock[off:sblock.index(b"\0", off)].decode("latin-1")


def write_dbc(path, fields, rsz, recs, sblock):
    with open(path, "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(recs), fields, rsz, len(sblock)))
        for r in recs:
            f.write(r)
        f.write(sblock)


def backup(path):
    bak = path + ".pre-pandaren.bak"
    if os.path.exists(bak):
        raise SystemExit("REFUSING: %s exists - already ran? Restore or delete .baks first." % bak)
    shutil.copy2(path, bak)


def f2s(x):
    """float -> shortest csv literal, matching existing style (no trailing .0)"""
    if x == int(x):
        return str(int(x))
    return repr(round(x, 6)).rstrip("0").rstrip(".")


def sniff(path):
    """detect newline + quoting + BOM of an existing csv"""
    raw = open(path, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    crlf = b"\r\n" in raw[:4096]
    quoted = raw[3 if bom else 0:4 if bom else 1] == b'"'
    ends_nl = raw.endswith(b"\n")
    return bom, crlf, quoted, ends_nl


def append_csv(path, rows_out):
    bom, crlf, quoted, ends_nl = sniff(path)
    backup(path)
    nl = "\r\n" if crlf else "\n"
    q = csv.QUOTE_ALL if quoted else csv.QUOTE_MINIMAL
    buf = io.StringIO()
    w = csv.writer(buf, quoting=q, lineterminator=nl)
    for r in rows_out:
        w.writerow(r)
    with open(path, "ab") as f:
        if not ends_nl:
            f.write(nl.encode())
        f.write(buf.getvalue().encode("utf-8"))
    print("  %-55s +%d rows" % (os.path.relpath(path, REPO), len(rows_out)))


# ---------------------------------------------------------------- donor loads
def donor_recs(name, unpack_fields=True):
    rows, fields, rsz, recs, sb = read_dbc(os.path.join(DONOR, name + ".dbc"))
    out = []
    for rec in recs:
        vals = struct.unpack("<%di" % fields, rec)
        out.append((vals, rec))
    return fields, rsz, out, sb


def main():
    os.makedirs(SRVOUT, exist_ok=True)

    # ---- ceilings check ------------------------------------------------
    def csv_max(path):
        with open(path, encoding="utf-8-sig") as f:
            rd = csv.reader(f)
            next(rd)
            return max(int(r[0]) for r in rd)

    cs_max = csv_max(os.path.join(CSVDIR, "CharSections.csv"))
    chg_max = csv_max(os.path.join(CSVDIR, "CharHairGeosets.csv"))
    cfhs_max = csv_max(os.path.join(CSVDIR, "CharacterFacialHairStyles.csv"))
    cmd_max = csv_max(os.path.join(CSVDIR, "CreatureModelData.csv"))
    cdi_max = csv_max(os.path.join(CSVDIR, "CreatureDisplayInfo.csv"))
    assert cs_max < CS_BASE[RACE_A], cs_max
    assert chg_max < CHG_BASE, chg_max
    assert cfhs_max < CFHS_BASE, cfhs_max
    assert cmd_max < CMD_M, cmd_max
    assert cdi_max < CDI_M, cdi_max
    _, _, cr_recs_chk, _ = donor_recs("ChrRaces")
    rows, fields, rsz, our_cr, _ = read_dbc(os.path.join(DBCDIR, "ChrRaces.dbc"))
    have = {struct.unpack("<i", r[:4])[0] for r in our_cr}
    assert RACE_A not in have and RACE_H not in have, "races 22/23 already present"
    print("ceilings ok: CS<%d CHG<%d CFHS<%d CMD<%d CDI<%d" %
          (CS_BASE[RACE_A], CHG_BASE, CFHS_BASE, CMD_M, CDI_M))

    # ---- 1. CharSections.csv ------------------------------------------
    fields_cs, _, drecs, dsb = donor_recs("CharSections")
    donor_cs = [(v, rec) for v, rec in drecs if v[1] == DONOR_RACE]
    donor_cs.sort(key=lambda t: t[0][0])   # stable donor order
    out = []
    new_cs = []                            # (newid, race, sex, sec, tex1..3, flags, var, col)
    for race in (RACE_A, RACE_H):
        for i, (v, rec) in enumerate(donor_cs):
            nid = CS_BASE[race] + i
            t1, t2, t3 = (dbc_string(dsb, v[4]), dbc_string(dsb, v[5]), dbc_string(dsb, v[6]))
            out.append([nid, race, v[2], v[3], t1, t2, t3, v[7], v[8], v[9]])
            new_cs.append((nid, race, v[2], v[3], t1, t2, t3, v[7], v[8], v[9]))
    append_csv(os.path.join(CSVDIR, "CharSections.csv"), out)

    # ---- 2. CharHairGeosets.csv ---------------------------------------
    _, _, drecs, _ = donor_recs("CharHairGeosets")
    donor_chg = sorted([v for v, _ in drecs if v[1] == DONOR_RACE], key=lambda v: v[0])
    out = []
    nid = CHG_BASE
    new_chg = []
    for race in (RACE_A, RACE_H):
        for v in donor_chg:
            out.append([nid, race, v[2], v[3], v[4], v[5]])
            new_chg.append((nid, race, v[2], v[3], v[4], v[5]))
            nid += 1
    append_csv(os.path.join(CSVDIR, "CharHairGeosets.csv"), out)

    # ---- 3. CharacterFacialHairStyles.csv -----------------------------
    _, _, drecs, _ = donor_recs("CharacterFacialHairStyles")
    donor_fh = sorted([v for v, _ in drecs if v[0] == DONOR_RACE], key=lambda v: (v[1], v[2]))
    out = []
    nid = CFHS_BASE
    new_fh = []
    for race in (RACE_A, RACE_H):
        for v in donor_fh:
            out.append([nid, race, v[1], v[2], v[3], v[4], v[5], v[6], v[7]])
            new_fh.append((race, v[1], v[2], v[3], v[4], v[5], v[6], v[7]))
            nid += 1
    append_csv(os.path.join(CSVDIR, "CharacterFacialHairStyles.csv"), out)

    # ---- 4. CreatureModelData.csv -------------------------------------
    with open(os.path.join(CSVDIR, "CreatureModelData.csv"), encoding="utf-8-sig") as f:
        cmd_hdr = next(csv.reader(f))
    fields_cmd, _, drecs, dsb = donor_recs("CreatureModelData")
    assert fields_cmd == len(cmd_hdr) == 28
    dmap = {v[0]: (v, rec) for v, rec in drecs}
    out = []
    for did, nid, sex in ((112929, CMD_M, "Male"), (112930, CMD_F, "Female")):
        v, rec = dmap[did]
        row = []
        for ci, col in enumerate(cmd_hdr):
            if col == "ID":
                row.append(nid)
            elif col == "ModelName":
                row.append("Character\\Pandaren\\%s\\Pandaren%s.mdx" % (sex, sex))
            elif col in CMD_FLOATS:
                row.append(f2s(struct.unpack("<f", rec[ci * 4:ci * 4 + 4])[0]))
            else:
                row.append(v[ci])
        out.append(row)
    append_csv(os.path.join(CSVDIR, "CreatureModelData.csv"), out)

    # ---- 5. CreatureDisplayInfo.csv -----------------------------------
    with open(os.path.join(CSVDIR, "CreatureDisplayInfo.csv"), encoding="utf-8-sig") as f:
        cdi_hdr = next(csv.reader(f))
    fields_cdi, _, drecs, dsb = donor_recs("CreatureDisplayInfo")
    assert fields_cdi == len(cdi_hdr) == 16
    dmap = {v[0]: (v, rec) for v, rec in drecs}
    out = []
    for did, nid, mid in ((141687, CDI_M, CMD_M), (141688, CDI_F, CMD_F)):
        v, rec = dmap[did]
        row = []
        for ci, col in enumerate(cdi_hdr):
            if col == "ID":
                row.append(nid)
            elif col == "ModelID":
                row.append(mid)
            elif col in CDI_FLOATS:
                row.append(f2s(struct.unpack("<f", rec[ci * 4:ci * 4 + 4])[0]))
            elif col.startswith("TextureVariation") or col == "PortraitTextureName":
                row.append(dbc_string(dsb, v[ci]))
            else:
                row.append(v[ci])
        out.append(row)
    append_csv(os.path.join(CSVDIR, "CreatureDisplayInfo.csv"), out)

    # ---- 6. ChrRaces.dbc (binary, clone our worgen row) ---------------
    def build_chrraces(path, outpath):
        rows, fields, rsz, recs, sb = read_dbc(path)
        assert fields == 69 and rsz == 276
        base = None
        for r in recs:
            if struct.unpack("<i", r[:4])[0] == 12:
                base = bytearray(r)
        assert base is not None
        sb = bytearray(sb)

        def addstr(s):
            off = len(sb)
            sb.extend(s.encode("latin-1") + b"\0")
            return off

        s_pa = addstr("Pa")
        s_file = addstr("Pandaren")
        s_norm = addstr("NORMAL")
        s_ear = addstr("EARRINGS")
        newrecs = list(recs)
        for rid, faction, lang, side in ((RACE_A, 1, 7, 0), (RACE_H, 2, 1, 1)):
            r = bytearray(base)

            def put(idx, val):
                r[idx * 4:idx * 4 + 4] = struct.pack("<i", val)
            put(0, rid)
            put(1, 4)            # flags: playable, same as nightelf/goblin
            put(2, faction)      # FactionID: 1 = player-human template, 2 = player-orc
            put(4, CDI_M)
            put(5, CDI_F)
            put(6, s_pa)         # client prefix
            put(7, lang)         # base language: 7 common / 1 orcish
            put(11, s_file)      # ClientFileString -> Character\Pandaren\
            put(12, 0)           # no cinematic
            put(13, side)        # 0 alliance / 1 horde
            put(14, s_file)      # name enUS = "Pandaren" (locale mask kept from worgen row)
            put(31, 0)           # nameFemale unset (worgen row also unset)
            put(48, 0)           # nameMale unset
            put(65, s_norm)      # facialHairCustomization1 = NORMAL (donor)
            put(66, s_ear)       # facialHairCustomization2 = EARRINGS (donor)
            put(67, s_norm)      # hairCustomization = NORMAL
            put(68, 0)           # requiredExpansion 0 - client is 3.3.5, no gate
            newrecs.append(bytes(r))
        write_dbc(outpath, fields, rsz, newrecs, bytes(sb))
        print("  %-55s +2 rows -> %d" % (os.path.relpath(outpath, REPO), len(newrecs)))

    p = os.path.join(DBCDIR, "ChrRaces.dbc")
    backup(p)
    build_chrraces(p + ".pre-pandaren.bak", p)
    build_chrraces(os.path.join(SRVDBC, "ChrRaces.dbc"), os.path.join(SRVOUT, "ChrRaces.dbc"))

    # ---- 7. CharBaseInfo.dbc ------------------------------------------
    def build_cbi(path, outpath):
        rows, fields, rsz, recs, sb = read_dbc(path)
        assert rsz == 2
        classes = sorted({r[1] for r in recs if r[0] == 1})
        newrecs = list(recs)
        for race in (RACE_A, RACE_H):
            for c in classes:
                newrecs.append(bytes([race, c]))
        write_dbc(outpath, fields, rsz, newrecs, sb)
        print("  %-55s +%d rows (classes %s)" %
              (os.path.relpath(outpath, REPO), 2 * len(classes), classes))

    p = os.path.join(DBCDIR, "CharBaseInfo.dbc")
    backup(p)
    build_cbi(p + ".pre-pandaren.bak", p)
    build_cbi(os.path.join(SRVDBC, "CharBaseInfo.dbc"), os.path.join(SRVOUT, "CharBaseInfo.dbc"))

    # ---- 8. CharStartOutfit.dbc ---------------------------------------
    def build_cso(path, outpath):
        rows, fields, rsz, recs, sb = read_dbc(path)
        assert rsz == 296
        nid = max(struct.unpack("<i", r[:4])[0] for r in recs) + 1
        newrecs = list(recs)
        added = 0
        for src_race, race in ((1, RACE_A), (2, RACE_H)):
            for rec in recs:
                packed = rec[4:8]
                if packed[0] == src_race:
                    r = bytearray(rec)
                    r[0:4] = struct.pack("<i", nid)
                    r[4] = race
                    newrecs.append(bytes(r))
                    nid += 1
                    added += 1
        write_dbc(outpath, fields, rsz, newrecs, sb)
        print("  %-55s +%d rows" % (os.path.relpath(outpath, REPO), added))

    p = os.path.join(DBCDIR, "CharStartOutfit.dbc")
    backup(p)
    build_cso(p + ".pre-pandaren.bak", p)
    build_cso(os.path.join(SRVDBC, "CharStartOutfit.dbc"), os.path.join(SRVOUT, "CharStartOutfit.dbc"))

    # ---- 9. server variants of the CSV-owned tables --------------------
    # server copies are appended binary-wise (server CharSections is older than the
    # client's; it must NOT inherit the HD rows, only the pandaren rows).
    def srv_append(name, build_rows):
        src = os.path.join(SRVDBC, name + ".dbc")
        rows, fields, rsz, recs, sb = read_dbc(src)
        sb = bytearray(sb)

        def addstr(s):
            if not s:
                return 0
            off = len(sb)
            sb.extend(s.encode("latin-1") + b"\0")
            return off
        newrecs = list(recs) + build_rows(fields, addstr)
        write_dbc(os.path.join(SRVOUT, name + ".dbc"), fields, rsz, newrecs, bytes(sb))
        print("  %-55s +%d rows (server)" % ("dbc_server/" + name + ".dbc", len(newrecs) - rows))

    srv_append("CharSections", lambda fields, addstr: [
        struct.pack("<10i", nid, race, sex, sec, addstr(t1), addstr(t2), addstr(t3), fl, var, col)
        for nid, race, sex, sec, t1, t2, t3, fl, var, col in new_cs])
    srv_append("CharHairGeosets", lambda fields, addstr: [
        struct.pack("<6i", *v) for v in new_chg])
    srv_append("CharacterFacialHairStyles", lambda fields, addstr: [
        struct.pack("<8i", *v) for v in new_fh])
    print("\nDONE. Next: compile the 5 CSVs with csv2wdbc into Custom/DBCs, verify, "
          "then deploy (patch-I + patch-4 + enGB-3 mirror + Server/data/dbc).")


if __name__ == "__main__":
    main()
