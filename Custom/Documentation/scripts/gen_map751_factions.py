#!/usr/bin/env python3
"""Downport the FactionTemplate/Faction rows the map-751 import needs.

18 imported creature templates reference 7 FactionTemplate ids that do not exist
here: 2166, 2207, 2261, 2293, 2294, 2322, 2357. A creature whose faction template
does not resolve falls back to a default, so hostility, PvP flags and "who attacks
whom" are all wrong for those NPCs -- the Bloodfang worgen pack, the Revantusk and
Wildhammer NPCs, High Warlord Cromush, Captain Crudbeard and the Blight Slime.

Sourced from the Cata 4.3.4 client (locale-enUS.MPQ). FactionTemplate.dbc is 14
fields in BOTH versions with the same order, so those rows copy verbatim.

Only ONE parent Faction is missing (1179 "Slime"); the other six templates point at
factions this client already has (14, 66, 76, 189, 469, 1134). Faction.dbc DOES
differ -- Cata packs 26 fields with single-string Name/Description where WotLK has
57 with a 16-locale block each -- so field 23 (Name) is written into
`Name_Lang_enUS` and the locale mask is copied from the rows already in the CSV.

1179 carries ReputationIndex = -1, i.e. it is not a reputation faction at all, so
no reputation bar or rank tuning is involved -- see the Gilneas case in
[[cata-faction-downport-neutral-trap]] where ReputationIndex -1 is what actually
decides behaviour, ahead of the group masks.

Outputs:
  Custom/CSV DBC/FactionTemplate.csv   +7 rows
  Custom/CSV DBC/Faction.csv           +1 row
  Plaguelands/78_factions.sql          overlay tables for the server
"""
import os, sys, csv, struct, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.environ.get("SCRATCH", "")
CSVDIR = os.path.normpath(os.path.join(HERE, "..", "..", "CSV DBC"))
OUTSQL = os.path.normpath(os.path.join(HERE, "..", "..", "Custom feature SQLs",
                                       "worlddb", "Plaguelands", "78_factions.sql"))

WANT_TEMPLATES = [2166, 2207, 2261, 2293, 2294, 2322, 2357]


def load(p):
    d = open(p, "rb").read()
    m, rc, fc, rs, ss = struct.unpack_from("<4sIIII", d, 0)
    assert m == b"WDBC", p
    rows = {}
    for i in range(rc):
        v = struct.unpack_from("<%dI" % fc, d, 20 + i * rs)
        rows[v[0]] = v
    return rows, d[20 + rc * rs:], fc


def i32(w):
    return struct.unpack("<i", struct.pack("<I", w))[0]


def f32(w):
    return struct.unpack("<f", struct.pack("<I", w))[0]


def fmt_f(v):
    s = "%.7g" % v
    return "0" if s in ("0", "-0") else s


def read_csv(name):
    with open(os.path.join(CSVDIR, name), encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh)), \
            [h.strip().strip('"') for h in open(os.path.join(CSVDIR, name), encoding="utf-8-sig").readline().split(",")]


def append_csv(name, cols, rows, label):
    path = os.path.join(CSVDIR, name)
    text = open(path, "rb").read().decode("utf-8-sig")
    hdr = [h.strip().strip('"') for h in text.split("\n", 1)[0].split(",")]
    if hdr != cols:
        raise SystemExit("ABORT: %s header mismatch\n file:%s\n want:%s" % (name, hdr, cols))
    existing = {ln.split(",", 1)[0].strip().strip('"') for ln in text.split("\n")[1:] if ln.strip()}
    dup = [r[0] for r in rows if str(r[0]) in existing]
    if dup:
        raise SystemExit("ABORT: %s already has ids %s" % (name, dup))
    shutil.copyfile(path, path + ".pre_map751_factions.bak")
    body = text if text.endswith("\n") else text + "\n"
    def cell(v):
        s = v if isinstance(v, str) else str(v)
        return '"%s"' % s.replace('"', '""') if ("," in s or '"' in s) else s
    out = body + "\n".join(",".join(cell(c) for c in r) for r in rows) + "\n"
    open(path, "wb").write(b"\xef\xbb\xbf" + out.encode("utf-8"))
    print("  %-24s %4d -> %4d (+%d %s)" % (name, len(existing), len(existing) + len(rows), len(rows), label))


def main():
    ft, _, ftfc = load(os.path.join(SP, "cata_veh", "FactionTemplate.dbc"))
    fac, facsb, facfc = load(os.path.join(SP, "cata_veh", "Faction.dbc"))
    if ftfc != 14:
        raise SystemExit("ABORT: cata FactionTemplate has %d fields, expected 14" % ftfc)

    def s_(o):
        if not o or o >= len(facsb):
            return ""
        e = facsb.find(b"\0", o)
        return facsb[o:e if e >= 0 else None].decode("utf-8", "replace")

    FT_COLS = ["ID", "Faction", "Flags", "FactionGroup", "FriendGroup", "EnemyGroup",
               "Enemies_1", "Enemies_2", "Enemies_3", "Enemies_4",
               "Friend_1", "Friend_2", "Friend_3", "Friend_4"]
    fac_rows_csv, FAC_COLS = read_csv("Faction.csv")
    have_fac = {int(r["ID"]) for r in fac_rows_csv}
    have_ft = {int(r["ID"]) for r in read_csv("FactionTemplate.csv")[0]}

    missing = [w for w in WANT_TEMPLATES if w not in ft]
    if missing:
        raise SystemExit("ABORT: templates %s not in the Cata client" % missing)
    already = [w for w in WANT_TEMPLATES if w in have_ft]
    if already:
        raise SystemExit("ABORT: templates %s already exist here" % already)

    ft_rows = [[i32(ft[w][i]) for i in range(14)] for w in WANT_TEMPLATES]

    # any parent Faction we do not already have
    need_fac = sorted({ft[w][1] for w in WANT_TEMPLATES if ft[w][1] and ft[w][1] not in have_fac})
    # the locale mask convention already in use here
    mask_name = fac_rows_csv[0]["Name_Lang_Mask"]
    mask_desc = fac_rows_csv[0]["Description_Lang_Mask"]

    fac_rows = []
    for f in need_fac:
        r = fac.get(f)
        if not r:
            raise SystemExit("ABORT: parent faction %d not in the Cata client" % f)
        vals = [i32(r[0]), i32(r[1])] + [i32(r[i]) for i in range(2, 19)]
        vals += [fmt_f(f32(r[19])), fmt_f(f32(r[20])), i32(r[21]), i32(r[22])]
        name, desc = s_(r[23]), s_(r[24])
        vals += [name] + [""] * 15 + [mask_name]
        vals += [desc] + [""] * 15 + [mask_desc]
        if len(vals) != 57:
            raise SystemExit("ABORT: built %d Faction columns, expected 57" % len(vals))
        fac_rows.append(vals)

    print("generating:")
    if not os.environ.get("SQL_ONLY"):
        append_csv("FactionTemplate.csv", FT_COLS, ft_rows, "templates")
        if fac_rows:
            append_csv("Faction.csv", FAC_COLS, fac_rows, "factions")
    else:
        print("  SQL_ONLY set -- CSVs left untouched")

    def ins(table, cols, rows):
        out = ["DELETE FROM `%s` WHERE `ID` IN (%s);" % (table, ",".join(str(r[0]) for r in rows)), ""]
        out.append("INSERT INTO `%s` (%s) VALUES" % (table, ", ".join("`%s`" % c for c in cols)))
        body = []
        for r in rows:
            cells = []
            for v in r:
                if isinstance(v, str) and not v.replace(".", "").replace("-", "").isdigit():
                    cells.append("'%s'" % v.replace("\\", "\\\\").replace("'", "''"))
                else:
                    cells.append(str(v))
            body.append("(" + ", ".join(cells) + ")")
        out.append(",\n".join(body) + ";")
        return "\n".join(out)

    with open(OUTSQL, "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("-- 78_factions.sql -- map 751 Lordaeron extension, DB step 17.\n--\n")
        w("-- GENERATED by Custom/Documentation/scripts/gen_map751_factions.py --\n")
        w("-- do not hand-edit; re-run the generator instead.\n--\n")
        w("-- 18 imported creature templates reference %d FactionTemplate ids that do not\n" % len(WANT_TEMPLATES))
        w("-- exist here (%s).\n" % ", ".join(str(x) for x in WANT_TEMPLATES))
        w("-- A creature whose faction template does not resolve falls back to a default, so\n")
        w("-- hostility, PvP flags and who-attacks-whom are all wrong for the Bloodfang worgen\n")
        w("-- pack, the Revantusk and Wildhammer NPCs, High Warlord Cromush, Captain Crudbeard\n")
        w("-- and the Blight Slime.\n--\n")
        w("-- FactionTemplate.dbc is 14 fields in BOTH 3.3.5 and 4.3.4 with the same order, so\n")
        w("-- these rows are copied verbatim from the Cata client.\n--\n")
        if fac_rows:
            w("-- Only ONE parent Faction was missing (%s); the rest point at factions this\n"
              % ", ".join(str(r[0]) for r in fac_rows))
            w("-- client already has (14, 66, 76, 189, 469, 1134). Faction.dbc DOES differ --\n")
            w("-- Cata packs 26 fields with single-string Name/Description, WotLK has 57 with a\n")
            w("-- 16-locale block each -- so the name goes into Name_Lang_enUS and the locale\n")
            w("-- mask is copied from the rows already present.\n")
            w("-- Faction 1179 'Slime' has ReputationIndex = -1: it is not a reputation faction,\n")
            w("-- so there is no rep bar or rank tuning to get wrong.\n")
        w("--\n-- Both halves are needed: the overlay tables below for the server, and the\n")
        w("-- recompiled DBCs for the client (which resolves hostility colouring itself).\n\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("-- 1. FactionTemplate\n")
        w("-- ---------------------------------------------------------------------------\n")
        w(ins("factiontemplate_dbc", FT_COLS, ft_rows) + "\n\n")
        if fac_rows:
            w("-- ---------------------------------------------------------------------------\n")
            w("-- 2. Faction\n")
            w("-- ---------------------------------------------------------------------------\n")
            w(ins("faction_dbc", FAC_COLS, fac_rows) + "\n\n")
        w("-- ---------------------------------------------------------------------------\n-- Verification\n")
        w("-- ---------------------------------------------------------------------------\n")
        w("SELECT 'factiontemplate rows (want %d)' AS what, COUNT(*) AS n\n" % len(ft_rows))
        w("FROM `factiontemplate_dbc` WHERE `ID` IN (%s)\n" % ",".join(str(r[0]) for r in ft_rows))
        if fac_rows:
            w("UNION ALL SELECT 'faction rows (want %d)', COUNT(*)\n" % len(fac_rows))
            w("FROM `faction_dbc` WHERE `ID` IN (%s)\n" % ",".join(str(r[0]) for r in fac_rows))
        w(";\n\n")
        w("-- must be empty: an imported creature whose faction template is still unknown\n")
        w("SELECT 'PROBLEM: unresolved faction template' AS problem, t.`faction`, COUNT(*) AS templates\n")
        w("FROM `creature_template` t\n")
        w("WHERE t.`entry` BETWEEN 4100000 AND 4199999\n")
        w("  AND t.`faction` IN (%s)\n" % ",".join(str(r[0]) for r in ft_rows))
        w("  AND NOT EXISTS (SELECT 1 FROM `factiontemplate_dbc` f WHERE f.`ID` = t.`faction`)\n")
        w("GROUP BY t.`faction`;\n")

    print("\nwrote %s" % OUTSQL)
    print("  factiontemplate rows %d, faction rows %d" % (len(ft_rows), len(fac_rows)))


main()
