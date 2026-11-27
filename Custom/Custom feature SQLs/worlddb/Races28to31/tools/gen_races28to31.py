#!/usr/bin/env python3
r"""
gen_races28to31.py - the rows that make Drakkari Troll, Void Elf, Lightforged and Mag'har playable.

Run gen_allied_classic_textures.py first: this reads its manifest. It replaces its own rows every time, so
it can run again after any change.

    CSV pipeline     CharSections, CharHairGeosets, CharacterFacialHairStyles, ChrRaces, CharStartOutfit,
                     CreatureDisplayInfo, CreatureModelData
    Binary           CharBaseInfo, SkillRaceClassInfo (Custom/DBCs, they have no CSV)
    SQL              ../20_races_server.sql

Each table is diffed after compiling: rows outside these races must come out unchanged. The one intended
change is Dark Iron's faces 10-19, which were flag 1. ComponentFlagsMatch gives a Death Knight only rows
with 0x4 or 0x10, so a Dark Iron Death Knight had no face at all.

    python gen_races28to31.py --manifest K:\tmp\races28to31_stage\manifest.json
"""
import argparse
import csv
import ctypes
import io
import json
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stage_filestring_assets as stage  # noqa: E402

REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
CSV_DIR = os.path.join(REPO, "Custom", "CSV DBC")
DBC_DIR = os.path.join(REPO, "Custom", "DBCs")
CSV2WDBC = r"K:\Dark-Chaos\wow.export-main\tools\csv2wdbc.py"
SQL_OUT = os.path.join(HERE, "..", "20_races_server.sql")
ASCENSION = r"K:\UntouchedClients\ascension_live\Data"
ASCENSION_RACE = 44

NEW_RACES = (28, 29, 30, 31)
# outfit is the race whose starting gear is cloned: Blood Elf gear is Horde-gated, so Void Elf wears Human's.
RACES = {
    28: dict(key="drakkari", name="Drakkari Troll", file="DrakkariTroll", parent=8, outfit=8, alliance=False,
             sections=952000, male=503950, female=503951),
    29: dict(key="voidelf", name="Void Elf", file="VoidElf", parent=10, outfit=1, alliance=True, faction=1,
             language=7, sections=953000),
    30: dict(key="lightforged", name="Lightforged Draenei", file="LightforgedDraenei", parent=11, outfit=11,
             alliance=True, sections=954000),
    31: dict(key="maghar", name="Mag'har Orc", file="MagharOrc", parent=2, outfit=2, alliance=False,
             sections=955000),
}
HAIR_GEOSET_BASE, FACIAL_STYLE_BASE, OUTFIT_BASE = 735, 1117, 363
DRAKKARI_MODELS = {0: (503950, "Character\\DrakkariTroll\\Male\\DrakkariTrollMale.mdx", 185),
                   1: (503951, "Character\\DrakkariTroll\\Female\\DrakkariTrollFemale.mdx", 186)}
# Racials the cloned action bars would otherwise carry, with no spell behind them.
PARENT_RACIALS = (59752, 20572, 33697, 33702, 26297, 28730, 25046, 50613, 28880, 59542, 59543, 59544, 59545,
                  59547, 59548)
MASK_ALLIANCE = (1 << 28) | (1 << 29)
MASK_HORDE = (1 << 27) | (1 << 30)
# Sweeps follow rows that already admit a vetted custom race of that faction plus a stock one, so a row that
# names one race (a racial) stays with that race.
MARK_ALLIANCE, STOCK_ALLIANCE = 1 << 26, 1101
MARK_HORDE, STOCK_HORDE = 1 << 24, 690
# Dark Iron was only part swept in the client's SkillRaceClassInfo (77 rows of 184), so that file follows
# Kul Tiran instead and fills Dark Iron in.
MARK_SKILL_ALLIANCE, DARK_IRON = 1 << 25, 1 << 26


class CsvTable:
    """A CSV edited in place: its BOM, quoting and line endings survive, only named rows change."""

    def __init__(self, name):
        self.name = name
        self.path = os.path.join(CSV_DIR, name + ".csv")
        raw = open(self.path, "rb").read()
        self.bom = raw[:3] == b"\xef\xbb\xbf"
        text = raw[3:].decode("utf-8") if self.bom else raw.decode("utf-8")
        self.eol = "\r\n" if "\r\n" in text[:4096] else "\n"
        self.lines = text.split(self.eol)
        if self.lines and self.lines[-1] == "":
            self.lines.pop()
        self.quoted = self.lines[0].startswith('"')
        self.header = next(csv.reader([self.lines[0]]))
        self.rows = []
        for row in csv.reader(io.StringIO("\n".join(self.lines[1:]), newline="")):
            self.rows.append(row)
        self.index = {name: i for i, name in enumerate(self.header)}

    def drop(self, keep):
        self.rows = [row for row in self.rows if keep(row)]

    def format(self, row):
        buffer = io.StringIO()
        writer = csv.writer(buffer, quoting=csv.QUOTE_ALL if self.quoted else csv.QUOTE_MINIMAL, lineterminator="")
        writer.writerow(row)
        return buffer.getvalue()

    def save(self):
        lines = [self.lines[0]] + [self.format(row) for row in self.rows]
        data = (self.eol.join(lines) + self.eol).encode("utf-8")
        with open(self.path, "wb") as f:
            f.write((b"\xef\xbb\xbf" if self.bom else b"") + data)
        print("  %-30s %d rows" % (self.name + ".csv", len(self.rows)))


def read_dbc(name):
    data = open(os.path.join(DBC_DIR, name + ".dbc"), "rb").read()
    magic, rows, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
    if magic != b"WDBC":
        raise SystemExit(name + ": not a WDBC file")
    return bytearray(data), rows, fields, size, strings


def ascension_rows():
    """Drakkari's rows from Ascension's own tables."""
    handle = ctypes.c_void_p()
    if not stage.S.SFileOpenArchive(os.path.join(ASCENSION, "patch-M.MPQ"), 0, 0x100, ctypes.byref(handle)):
        raise SystemExit("cannot open patch-M.MPQ")

    def table(name):
        data = stage.read([handle], "DBFilesClient\\%s.dbc" % name)
        magic, rows, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
        records = [struct.unpack_from("<%di" % (size // 4), data, 20 + i * size) for i in range(rows)]
        return records, data[20 + rows * size:]

    def text(blob, offset):
        return blob[offset:blob.index(b"\0", offset)].decode("utf-8")

    records, blob = table("CharSections")
    sections = [(r[2], r[3], text(blob, r[4]), text(blob, r[5]), text(blob, r[6]), r[7], r[8], r[9])
                for r in records if r[1] == ASCENSION_RACE]
    geosets = [r[2:] for r in table("CharHairGeosets")[0] if r[1] == ASCENSION_RACE]
    facial = [r[1:] for r in table("CharacterFacialHairStyles")[0] if r[0] == ASCENSION_RACE]
    return sections, geosets, facial


def section_rows(table, spec, entry):
    """The CharSections rows of a reskin race."""
    race = spec["race"]
    parent = str(spec["parent"])
    ix = table.index
    number = spec["sections"]
    out = []

    def add(sex, section, variation, colour, flags, first, second="", third=""):
        nonlocal number
        row = [""] * len(table.header)
        row[ix["ID"]] = str(number)
        row[ix["RaceID"]] = str(race)
        row[ix["SexID"]] = str(sex)
        row[ix["BaseSection"]] = str(section)
        row[ix["TextureName_1"]], row[ix["TextureName_2"]], row[ix["TextureName_3"]] = first, second, third
        row[ix["Flags"]] = str(flags)
        row[ix["VariationIndex"]] = str(variation)
        row[ix["ColorIndex"]] = str(colour)
        number += 1
        out.append(row)

    tones, faces = entry["tones"], entry["faces"]
    prefix, deploy = entry["prefix"], entry["deploy"]
    hair_map = {int(k): v for k, v in entry["hair_map"].items()}
    for sex, sex_name in ((0, "male"), (1, "female")):
        title = sex_name.capitalize()

        def path(name):
            return "Character\\%s\\%s\\%s%s%s" % (deploy, title, prefix, sex_name, name)

        for tone in range(tones):
            add(sex, 0, 0, tone, 17, path("skin00_%02d.blp" % tone), path("skin00_%02d_Extra.blp" % tone))
            torso = path("nakedtorsoskin00_%02d.blp" % tone) if entry["torso_" + sex_name] else ""
            add(sex, 4, 0, tone, 17, path("nakedpelvisskin00_%02d.blp" % tone), torso)
            for face in range(faces):
                lower, upper = path("facelower%02d_%02d.blp" % (face, tone)), path("faceupper%02d_%02d.blp" % (face, tone))
                add(sex, 1, face, tone, 1, lower, upper)
                # The same faces again for Death Knights, who cannot select a flag 1 row.
                add(sex, 1, faces + face, tone, 5, lower, upper)

        rows = [r for r in table.rows if r[ix["RaceID"]] == parent and r[ix["SexID"]] == str(sex)]

        def by_style(section):
            found = {}
            for row in rows:
                if row[ix["BaseSection"]] == section:
                    found.setdefault(int(row[ix["VariationIndex"]]), {})[int(row[ix["ColorIndex"]])] = row
            return found

        for section in ("2", "3"):
            for variation, colours in sorted(by_style(section).items()):
                if not hair_map:
                    for colour, row in sorted(colours.items()):
                        add(sex, section, variation, colour, row[ix["Flags"]], row[ix["TextureName_1"]],
                            row[ix["TextureName_2"]], row[ix["TextureName_3"]])
                    continue
                player = {c: r for c, r in colours.items() if r[ix["Flags"]] in ("17", "18")}
                if not player:
                    continue
                for colour, source in sorted(hair_map.items()):
                    row = player.get(source) or player[min(player)]
                    first = row[ix["TextureName_1"]]
                    if section == "3" and first:
                        first = "Character\\%s\\%shair00_%02d.blp" % (deploy, prefix, colour)
                    add(sex, section, variation, colour, row[ix["Flags"]], first, row[ix["TextureName_2"]],
                        row[ix["TextureName_3"]])
    return out


def drakkari_rows(table, spec, sections):
    ix = table.index
    out = []
    for number, (sex, section, first, second, third, flags, variation, colour) in enumerate(sections):
        row = [""] * len(table.header)
        row[ix["ID"]] = str(spec["sections"] + number)
        row[ix["RaceID"]] = str(spec["race"])
        row[ix["SexID"]] = str(sex)
        row[ix["BaseSection"]] = str(section)
        row[ix["TextureName_1"]], row[ix["TextureName_2"]], row[ix["TextureName_3"]] = first, second, third
        row[ix["Flags"]] = str(flags)
        row[ix["VariationIndex"]] = str(variation)
        row[ix["ColorIndex"]] = str(colour)
        out.append(row)
    return out


def char_sections(manifest, drakkari):
    table = CsvTable("CharSections")
    ix = table.index
    table.drop(lambda row: int(row[ix["RaceID"]]) not in NEW_RACES)
    fixed = 0
    for row in table.rows:
        if row[ix["RaceID"]] == "27" and row[ix["BaseSection"]] == "1" and int(row[ix["VariationIndex"]]) >= 10 \
                and row[ix["Flags"]] != "5":
            row[ix["Flags"]] = "5"
            fixed += 1
    print("  Dark Iron Death Knight faces set to flag 5: %d" % fixed)
    for race, spec in RACES.items():
        spec["race"] = race
        added = drakkari_rows(table, spec, drakkari) if race == 28 else section_rows(table, spec, manifest[spec["key"]])
        table.rows.extend(added)
        print("  %-22s %d CharSections rows" % (spec["name"], len(added)))
    table.save()


def hair_tables(drakkari_geosets, drakkari_facial):
    table = CsvTable("CharHairGeosets")
    ix = table.index
    table.drop(lambda row: int(row[ix["RaceID"]]) not in NEW_RACES)
    number = HAIR_GEOSET_BASE
    sources = list(table.rows)
    for race, spec in RACES.items():
        if race == 28:
            clones = [[str(sex), str(variation), str(geoset), str(scalp)]
                      for sex, variation, geoset, scalp in drakkari_geosets]
        else:
            clones = [row[ix["SexID"]:] for row in sources if row[ix["RaceID"]] == str(spec["parent"])]
        for clone in clones:
            table.rows.append([str(number), str(race)] + clone)
            number += 1
    table.save()

    table = CsvTable("CharacterFacialHairStyles")
    ix = table.index
    table.drop(lambda row: int(row[ix["RaceID"]]) not in NEW_RACES)
    number = FACIAL_STYLE_BASE
    sources = list(table.rows)
    for race, spec in RACES.items():
        if race == 28:
            clones = [[str(x) for x in row] for row in drakkari_facial]
        else:
            clones = [row[ix["SexID"]:] for row in sources if row[ix["RaceID"]] == str(spec["parent"])]
        for clone in clones:
            table.rows.append([str(number), str(race)] + clone)
            number += 1
    table.save()


def chr_races():
    table = CsvTable("ChrRaces")
    ix = table.index
    table.drop(lambda row: int(row[0]) not in NEW_RACES)
    template = next(row for row in table.rows if row[0] == "27")
    for race, spec in RACES.items():
        parent = next(row for row in table.rows if row[0] == str(spec["parent"]))
        row = list(template)
        for field in ("Flags", "FactionID", "ExplorationSoundID", "MaleDisplayId", "FemaleDisplayId", "ClientPrefix",
                      "BaseLanguage", "CreatureType", "ResSicknessSpellID", "SplashSoundID",
                      "FacialHairCustomization_1", "FacialHairCustomization_2", "HairCustomization",
                      "Required_Expansion"):
            if field in ix:
                row[ix[field]] = parent[ix[field]]
        row[0] = str(race)
        row[ix["ClientFilestring"]] = spec["file"]
        row[ix["Name_Lang_enUS"]] = spec["name"]
        row[ix["CinematicSequenceID"]] = "0"
        row[ix["Alliance"]] = "0" if spec["alliance"] else "1"
        if "faction" in spec:
            row[ix["FactionID"]] = str(spec["faction"])
            row[ix["BaseLanguage"]] = str(spec["language"])
        if "male" in spec:
            row[ix["MaleDisplayId"]], row[ix["FemaleDisplayId"]] = str(spec["male"]), str(spec["female"])
        table.rows.append(row)
    table.rows.sort(key=lambda row: int(row[0]))
    table.save()
    return table


def start_outfits():
    table = CsvTable("CharStartOutfit")
    ix = table.index
    table.drop(lambda row: int(row[ix["RaceID"]]) not in NEW_RACES)
    number = OUTFIT_BASE
    added = []
    for race, spec in RACES.items():
        # sCharStartOutfitMap keeps the last id it sees, so the highest id per class and sex is the live one.
        live = {}
        for row in table.rows:
            if row[ix["RaceID"]] == str(spec["outfit"]):
                live[(int(row[ix["ClassID"]]), int(row[ix["SexID"]]))] = row
        for key in sorted(live):
            row = list(live[key])
            row[0] = str(number)
            row[ix["RaceID"]] = str(race)
            number += 1
            added.append(row)
    table.rows.extend(added)
    table.save()
    return table.header, added


def displays():
    models = CsvTable("CreatureModelData")
    ix = models.index
    ids = {str(v[0]) for v in DRAKKARI_MODELS.values()}
    models.drop(lambda row: row[0] not in ids)
    model_rows = []
    for number, name, source in DRAKKARI_MODELS.values():
        row = list(next(r for r in models.rows if r[0] == str(source)))
        row[0] = str(number)
        row[ix["ModelName"]] = name
        model_rows.append(row)
    models.rows.extend(model_rows)
    models.save()

    info = CsvTable("CreatureDisplayInfo")
    info.drop(lambda row: row[0] not in ids)
    template = next(r for r in info.rows if r[0] == "503911")
    display_rows = []
    for number, _, _ in DRAKKARI_MODELS.values():
        row = list(template)
        row[0] = str(number)
        row[1] = str(number)
        display_rows.append(row)
    info.rows.extend(display_rows)
    info.save()
    return models.header, model_rows, info.header, display_rows


def snapshot(table):
    """id -> row with strings resolved, from the compiled DBC."""
    data = open(os.path.join(DBC_DIR, table + ".dbc"), "rb").read()
    magic, rows, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
    out = {}
    for i in range(rows):
        out[i] = data[20 + i * size:20 + (i + 1) * size]
    return out, data[20 + rows * size:], size


def semantic(table):
    records, blob, size = snapshot(table)
    resolved = {}
    for record in records.values():
        words = struct.unpack("<%di" % (size // 4), record)
        cells = []
        for word in words:
            if 0 < word < len(blob) and blob[word - 1] == 0:
                end = blob.index(b"\0", word)
                cells.append(blob[word:end])
            else:
                cells.append(word)
        resolved[words[0]] = cells
    return resolved


def compile_tables():
    before = {}
    tables = ("CharSections", "CharHairGeosets", "ChrRaces", "CharStartOutfit", "CreatureDisplayInfo", "CreatureModelData")
    for table in tables:
        before[table] = semantic(table)
    for table in tables + ("CharacterFacialHairStyles",):
        subprocess.check_call([sys.executable, CSV2WDBC, "--csv", os.path.join(CSV_DIR, table + ".csv"),
                               "--out", os.path.join(DBC_DIR, table + ".dbc"), "--table", table],
                              stdout=subprocess.DEVNULL)
    # The defs give this table a synthetic id column the client's file does not have.
    styles = CsvTable("CharacterFacialHairStyles")
    with open(os.path.join(DBC_DIR, "CharacterFacialHairStyles.dbc"), "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(styles.rows), 8, 32, 1))
        for row in styles.rows:
            f.write(struct.pack("<8i", *[int(x) for x in row[1:]]))
        f.write(b"\0")
    for table in tables:
        after = semantic(table)
        lost = [key for key in before[table] if key not in after]
        changed = [key for key, cells in before[table].items() if key in after and after[key] != cells]
        print("  %-22s %6d -> %6d rows, lost %d, changed %d" % (table, len(before[table]), len(after), len(lost), len(changed)))
        expected = 100 if table == "CharSections" else 0
        if lost or len(changed) > expected:
            raise SystemExit("%s: unexpected changes %s" % (table, (lost + changed)[:10]))


def char_base_info():
    data, rows, fields, size, strings = read_dbc("CharBaseInfo")
    pairs = [(data[20 + i * size], data[20 + i * size + 1]) for i in range(rows)]
    pairs = [p for p in pairs if p[0] not in NEW_RACES]
    for race, spec in RACES.items():
        pairs.extend((race, klass) for parent, klass in list(pairs) if parent == spec["parent"])
    with open(os.path.join(DBC_DIR, "CharBaseInfo.dbc"), "wb") as f:
        f.write(struct.pack("<4siiii", b"WDBC", len(pairs), fields, size, 1))
        for race, klass in pairs:
            f.write(bytes((race, klass)))
        f.write(b"\0")
    print("  CharBaseInfo.dbc               %d -> %d pairs" % (rows, len(pairs)))


def skill_race_class_info():
    data, rows, fields, size, strings = read_dbc("SkillRaceClassInfo")
    alliance = horde = 0
    for i in range(rows):
        at = 20 + i * size + 8
        mask = struct.unpack_from("<i", data, at)[0]
        if mask == -1:
            continue
        unsigned = mask & 0xFFFFFFFF
        if unsigned & MARK_SKILL_ALLIANCE and unsigned & STOCK_ALLIANCE:
            unsigned |= MASK_ALLIANCE | DARK_IRON
            alliance += 1
        if unsigned & MARK_HORDE and unsigned & STOCK_HORDE:
            unsigned |= MASK_HORDE
            horde += 1
        struct.pack_into("<I", data, at, unsigned)
    with open(os.path.join(DBC_DIR, "SkillRaceClassInfo.dbc"), "wb") as f:
        f.write(data)
    print("  SkillRaceClassInfo.dbc         %d rows, swept %d Alliance, %d Horde" % (rows, alliance, horde))


def sql_values(row):
    cells = []
    for cell in row:
        if cell == "":
            cells.append("''")
        elif cell.lstrip("-").replace(".", "", 1).isdigit():
            cells.append(cell)
        else:
            cells.append("'" + cell.replace("\\", "\\\\").replace("'", "''") + "'")
    return "(" + ", ".join(cells) + ")"


def quoted_columns(header):
    return ", ".join("`%s`" % name for name in header)


def sweep(lines, table, column, extra=""):
    lines.append("UPDATE `%s` SET `%s` = `%s` | %d WHERE (`%s` & %d) <> 0 AND (`%s` & %d) <> 0%s;"
                 % (table, column, column, MASK_ALLIANCE, column, MARK_ALLIANCE, column, STOCK_ALLIANCE, extra))
    lines.append("UPDATE `%s` SET `%s` = `%s` | %d WHERE (`%s` & %d) <> 0 AND (`%s` & %d) <> 0%s;"
                 % (table, column, column, MASK_HORDE, column, MARK_HORDE, column, STOCK_HORDE, extra))


def write_sql(races, outfit_header, outfits, model_header, model_rows, display_header, display_rows):
    ids = ", ".join(str(race) for race in NEW_RACES)
    lines = [
        "-- Drakkari Troll (28), Void Elf (29), Lightforged Draenei (30), Mag'har Orc (31): the server half.",
        "-- GENERATED by tools/gen_races28to31.py. Apply after 10_, 11_ and 12_. Safe to run again.",
        "--",
        "-- Bits: 28 = 134217728, 29 = 268435456, 30 = 536870912, 31 = 1073741824.",
        "-- Each sweep follows rows that admit Dark Iron (Alliance) or Zandalari (Horde) together with a stock",
        "-- race of that faction, so a row naming one race, such as a racial, stays with that race.",
        "",
        "-- 1. ChrRaces, as the other custom races have it. The DBC carries the same rows.",
        "DELETE FROM `chrraces_dbc` WHERE `ID` IN (%s);" % ids,
    ]
    ix = races.index
    columns = ("ID", "Flags", "FactionID", "ExplorationSoundID", "MaleDisplayId", "FemaleDisplayId", "ClientPrefix",
               "BaseLanguage", "CreatureType", "ResSicknessSpellID", "SplashSoundID", "ClientFilestring",
               "CinematicSequenceID", "Alliance", "Name_Lang_enUS", "Name_Lang_Mask", "Name_Female_Lang_Mask",
               "Name_Male_Lang_Mask", "FacialHairCustomization_1", "FacialHairCustomization_2", "HairCustomization",
               "Required_Expansion")
    lines.append("INSERT INTO `chrraces_dbc` (%s) VALUES" % quoted_columns(columns))
    rows = [next(r for r in races.rows if r[0] == str(race)) for race in NEW_RACES]
    lines.append(",\n".join(sql_values([row[ix[c]] for c in columns]) for row in rows) + ";")
    lines.append("")

    lines.append("-- 2. Start position, action bars and base stats, from each parent. The bars drop the parent's racial.")
    lines.append("DELETE FROM `playercreateinfo` WHERE `race` IN (%s);" % ids)
    lines.append("DELETE FROM `playercreateinfo_action` WHERE `race` IN (%s);" % ids)
    lines.append("DELETE FROM `player_race_stats` WHERE `Race` IN (%s);" % ids)
    racials = ", ".join(str(spell) for spell in PARENT_RACIALS)
    for race, spec in RACES.items():
        parent = spec["parent"]
        lines.append("INSERT INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, "
                     "`position_z`, `orientation`)")
        lines.append("SELECT %d, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation` "
                     "FROM (SELECT * FROM `playercreateinfo` WHERE `race` = %d) AS `donor`;" % (race, parent))
        lines.append("INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)")
        lines.append("SELECT %d, `class`, `button`, `action`, `type` FROM (SELECT * FROM `playercreateinfo_action` "
                     "WHERE `race` = %d AND NOT (`type` = 0 AND `action` IN (%s))) AS `donor`;" % (race, parent, racials))
        lines.append("INSERT INTO `player_race_stats` (`Race`, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`)")
        lines.append("SELECT %d, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit` "
                     "FROM (SELECT * FROM `player_race_stats` WHERE `Race` = %d) AS `donor`;" % (race, parent))
    lines.append("")

    lines.append("-- 3. Starting gear. A server-side overlay of the DBC rows.")
    lines.append("DELETE FROM `charstartoutfit_dbc` WHERE `RaceID` IN (%s);" % ids)
    lines.append("INSERT INTO `charstartoutfit_dbc` (%s) VALUES" % quoted_columns(outfit_header))
    lines.append(",\n".join(sql_values(row) for row in outfits) + ";")
    lines.append("")

    lines.append("-- 4. Drakkari's own model. The other three wear their parent's.")
    lines.append("DELETE FROM `creaturemodeldata_dbc` WHERE `ID` IN (503950, 503951);")
    lines.append("INSERT INTO `creaturemodeldata_dbc` (%s) VALUES" % quoted_columns(model_header))
    lines.append(",\n".join(sql_values(row) for row in model_rows) + ";")
    lines.append("DELETE FROM `creaturedisplayinfo_dbc` WHERE `ID` IN (503950, 503951);")
    lines.append("INSERT INTO `creaturedisplayinfo_dbc` (%s) VALUES" % quoted_columns(display_header))
    lines.append(",\n".join(sql_values(row) for row in display_rows) + ";")
    lines.append("")

    lines.append("-- 5. Race-gated content.")
    sweep(lines, "playercreateinfo_skills", "raceMask")
    sweep(lines, "skillraceclassinfo_dbc", "RaceMask", " AND `RaceMask` <> -1")
    sweep(lines, "skilllineability_dbc", "RaceMask")
    sweep(lines, "item_template", "AllowableRace", " AND `AllowableRace` NOT IN (-1, 0)")
    sweep(lines, "quest_template", "AllowableRaces", " AND `AllowableRaces` NOT IN (0, 2147483647, 4294967295)")
    sweep(lines, "spell_area", "racemask")
    sweep(lines, "conditions", "ConditionValue1", " AND `ConditionTypeOrReference` = 16")
    lines.append("")
    with open(SQL_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("  %s" % os.path.normpath(SQL_OUT))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()
    manifest = json.load(open(args.manifest))
    sections, geosets, facial = ascension_rows()

    char_sections(manifest, sections)
    hair_tables(geosets, facial)
    races = chr_races()
    outfit_header, outfits = start_outfits()
    model_header, model_rows, display_header, display_rows = displays()
    compile_tables()
    char_base_info()
    skill_race_class_info()
    write_sql(races, outfit_header, outfits, model_header, model_rows, display_header, display_rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
