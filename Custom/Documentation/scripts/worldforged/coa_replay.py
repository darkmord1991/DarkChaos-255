"""Replay Ascension CoA's worldforged SQL history into a scratch SQLite DB.

CoA's pickup layer is ~40 migrations that each patch the previous one, plus later pending
revisions, so no single file holds the final state. This replays them the way the
AzerothCore updater would and leaves the result in SQLite:

  base  = data/coa-world/coa-world-20260912.zip (gameobject, gameobject_template,
          gameobject_loot_template, reference_loot_template) - the package predates
          the module's first migration (2026-09-16)
  then  = modules/mod-worldforged-pickups/data/sql/db-world/*.sql and
          data/sql/updates/pending_db_world/*.sql in filename order, executing only the
          statements that target the gameobject tables

Usage: python coa_replay.py <out.sqlite> [<CoA checkout, or a git archive extract of its SQL folders>]
"""
import math
import re
import sqlite3
import sys
import zipfile
from pathlib import Path

COA = Path(r"K:/Dark-Chaos/Ascension COA/azerothcore-wotlk-coa")
ZIP = COA / "data/coa-world/coa-world-20260912.zip"

TABLES = {
    "gameobject": """CREATE TABLE gameobject (guid INTEGER PRIMARY KEY, id INT, map INT, zoneId INT, areaId INT,
        spawnMask INT, phaseMask INT, position_x REAL, position_y REAL, position_z REAL, orientation REAL,
        rotation0 REAL, rotation1 REAL, rotation2 REAL, rotation3 REAL, spawntimesecs INT, animprogress INT,
        state INT, ScriptName TEXT DEFAULT '', VerifiedBuild INT, Comment TEXT)""",
    "gameobject_template": """CREATE TABLE gameobject_template (entry INTEGER PRIMARY KEY, type INT, displayId INT,
        name TEXT, IconName TEXT, castBarCaption TEXT, unk1 TEXT, size REAL, """
        + ", ".join(f"Data{i} INT DEFAULT 0" for i in range(24))
        + ", AIName TEXT DEFAULT '', ScriptName TEXT DEFAULT '', VerifiedBuild INT)",
    "gameobject_loot_template": """CREATE TABLE gameobject_loot_template (Entry INT, Item INT, Reference INT DEFAULT 0,
        Chance REAL DEFAULT 100, QuestRequired INT DEFAULT 0, LootMode INT DEFAULT 1, GroupId INT DEFAULT 0,
        MinCount INT DEFAULT 1, MaxCount INT DEFAULT 1, Comment TEXT, PRIMARY KEY (Entry, Item))""",
    "reference_loot_template": """CREATE TABLE reference_loot_template (Entry INT, Item INT, Reference INT DEFAULT 0,
        Chance REAL DEFAULT 100, QuestRequired INT DEFAULT 0, LootMode INT DEFAULT 1, GroupId INT DEFAULT 0,
        MinCount INT DEFAULT 1, MaxCount INT DEFAULT 1, Comment TEXT, PRIMARY KEY (Entry, Item))""",
}

ESC = {"0": "\0", "'": "'", '"': '"', "b": "\b", "n": "\n", "r": "\r", "t": "\t", "Z": "\x1a", "\\": "\\"}

TARGET_RE = re.compile(
    r"^\s*(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO|UPDATE|DELETE\s+FROM|DELETE\s+`?\w+`?\s+FROM)\s+`?(\w+)`?",
    re.I)
DELETE_ALIAS_RE = re.compile(r"^\s*DELETE\s+`?(\w+)`?\s+FROM\s+`?(\w+)`?\s+`?(\w+)`?\s+(.*)$", re.I | re.S)
TEMP_RE = re.compile(r"^\s*(CREATE|DROP)\s+TEMPORARY\s+TABLE", re.I)
SET_RE = re.compile(r"^\s*SET\s+@(\w+)\s*:?=\s*(.+)$", re.I | re.S)


def split_statements(text):
    """Yield top-level statements of a MySQL script with string literals already in SQLite form."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in ("'", '"'):
            quote = c
            i += 1
            buf = []
            while i < n:
                ch = text[i]
                if ch == "\\" and i + 1 < n:
                    nxt = text[i + 1]
                    buf.append(ESC.get(nxt, "\\" + nxt if nxt in "%_" else nxt))
                    i += 2
                    continue
                if ch == quote:
                    if i + 1 < n and text[i + 1] == quote:
                        buf.append(quote)
                        i += 2
                        continue
                    i += 1
                    break
                buf.append(ch)
                i += 1
            out.append("'" + "".join(buf).replace("'", "''") + "'")
            continue
        if c == "`":
            j = text.index("`", i + 1)
            out.append(text[i:j + 1])
            i = j + 1
            continue
        if c == "-" and text.startswith("--", i) and (i + 2 >= n or text[i + 2] in " \t\r\n"):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
            out.append(" ")
            continue
        if c == "#":
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
            out.append(" ")
            continue
        if c == "/" and text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            out.append(" ")
            continue
        if c == ";":
            stmt = "".join(out).strip()
            if stmt:
                yield stmt
            out = []
            i += 1
            continue
        out.append(c)
        i += 1
    stmt = "".join(out).strip()
    if stmt:
        yield stmt


class Replayer:
    def __init__(self, path):
        self.path = Path(path)
        if self.path.exists():
            self.path.unlink()
        self.db = sqlite3.connect(self.path)
        self.db.create_function("IF", 3, lambda c, a, b: a if c else b)
        self.db.create_function("GREATEST", -1, lambda *a: max(a))
        self.db.create_function("LEAST", -1, lambda *a: min(a))
        self.db.create_function("CONCAT", -1, lambda *a: "".join("" if x is None else str(x) for x in a))
        for name, fn in (("SIN", math.sin), ("COS", math.cos), ("SQRT", math.sqrt), ("ATAN", math.atan)):
            self.db.create_function(name, 1, fn)
        self.db.create_function("ATAN2", 2, math.atan2)
        self.db.create_function("POW", 2, math.pow)
        self.db.create_function("POWER", 2, math.pow)
        self.db.create_function("FIND_IN_SET", 2, lambda needle, haystack: (
            str(haystack or "").split(",").index(str(needle)) + 1 if str(needle) in str(haystack or "").split(",")
            else 0))
        # CoA gates some revisions on its own schema name (`AND DATABASE() = 'coa_world'`)
        self.db.create_function("DATABASE", 0, lambda: "coa_world")
        for ddl in TABLES.values():
            self.db.execute(ddl)
        self.vars = {}
        self.temp_tables = set()
        self.failures = []

    def substitute_vars(self, stmt):
        if not self.vars:
            return stmt
        return re.sub(r"@(\w+)", lambda m: str(self.vars.get(m.group(1), m.group(0))), stmt)

    def translate(self, stmt):
        s = self.substitute_vars(stmt)
        s = re.sub(r"^\s*INSERT\s+IGNORE\s+INTO", "INSERT OR IGNORE INTO", s, flags=re.I)
        odku = re.search(r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b(.*)$", s, re.I | re.S)
        if odku:
            sets = re.sub(r"\bVALUES\s*\(\s*(`?\w+`?)\s*\)", r"excluded.\1", odku.group(1), flags=re.I)
            s = s[:odku.start()] + " ON CONFLICT DO UPDATE SET " + sets
        m = DELETE_ALIAS_RE.match(s)
        if m:
            alias, table, alias2, rest = m.groups()
            if alias == alias2:
                s = f"DELETE FROM `{table}` WHERE rowid IN (SELECT `{alias}`.rowid FROM `{table}` `{alias}` {rest})"
        s = re.sub(r"CREATE\s+TEMPORARY\s+TABLE\s+(`?\w+`?)\s+LIKE\s+(`?\w+`?)\s*$",
                   r"CREATE TEMP TABLE \1 AS SELECT * FROM \2 WHERE 0", s, flags=re.I)
        s = re.sub(r"CREATE\s+TEMPORARY\s+TABLE\s+(`?\w+`?)\s+SELECT\b", r"CREATE TEMP TABLE \1 AS SELECT", s,
                   flags=re.I)                  # MySQL allows CREATE ... SELECT without AS
        s = re.sub(r"CREATE\s+TEMPORARY\s+TABLE", "CREATE TEMP TABLE", s, flags=re.I)
        s = re.sub(r"DROP\s+TEMPORARY\s+TABLE", "DROP TABLE", s, flags=re.I)
        if re.search(r"\(\s*VALUES\s+ROW\s*\(", s, re.I):   # MySQL 8 table value constructor
            s = re.sub(r"\bROW\s*\(", "(", s, flags=re.I)
        # MySQL multi-table UPDATE t AS a JOIN (derived) AS v ON ... SET a.x = v.x -> SQLite UPDATE ... FROM
        m = re.match(r"^\s*UPDATE\s+(`?\w+`?)\s+(?:AS\s+)?(`?\w+`?)\s+JOIN\s+(\(.*\))\s+(?:AS\s+)?(`?\w+`?)\s+ON\s+(.*?)"
                     r"\s+SET\s+(.*?)(?:\s+WHERE\s+(.*))?$", s, re.I | re.S)
        if m:
            table, alias, derived, valias, on, sets, where = m.groups()
            a = alias.strip("`")
            sets = re.sub(rf"(^|,)\s*`?{re.escape(a)}`?\s*\.\s*(`?\w+`?)\s*=", r"\1 \2 =", sets)
            s = (f"UPDATE {table} AS {alias} SET {sets} FROM {derived} AS {valias} WHERE {on}"
                 + (f" AND ({where})" if where else ""))
        return s

    def run(self, text, label):
        done = 0
        for stmt in split_statements(text):
            sm = SET_RE.match(stmt)
            if sm:
                value = sm.group(2).strip()
                if re.fullmatch(r"'(?:[^']|'')*'", value):   # a string list, e.g. for FIND_IN_SET
                    self.vars[sm.group(1)] = value
                    continue
                try:
                    self.vars[sm.group(1)] = int(eval(self.substitute_vars(value), {}, {}))
                except Exception:  # noqa: BLE001 - other session variables do not touch these tables
                    pass
                continue
            m = TARGET_RE.match(stmt)
            is_temp = TEMP_RE.match(stmt)
            target = m.group(1).lower() if m else None
            if is_temp:
                tm = re.search(r"TABLE\s+(?:IF\s+(?:NOT\s+)?EXISTS\s+)?`?(\w+)`?", stmt, re.I)
                if tm:
                    self.temp_tables.add(tm.group(1).lower())
                if stmt.upper().startswith("CREATE") and not re.search(r"`?gameobject\w*`?|reference_loot_template",
                                                                       stmt, re.I):
                    continue
            elif target not in TABLES and target not in self.temp_tables:
                continue
            try:
                self.db.execute(self.translate(stmt))
                done += 1
            except sqlite3.Error as e:
                self.failures.append((label, str(e), stmt[:300]))
        return done


def build(out_path, sql_root=COA):
    """sql_root: the CoA checkout, or a `git archive <commit>` extract of its two SQL folders to replay
    another commit without touching the checkout (the base zip is always read from COA)."""
    rp = Replayer(out_path)
    with zipfile.ZipFile(ZIP) as z:
        for table in TABLES:
            name = next(n for n in z.namelist() if Path(n).stem == table)
            rp.run(z.read(name).decode("utf-8"), f"zip:{table}")
    files = sorted(
        list((sql_root / "modules/mod-worldforged-pickups/data/sql/db-world").glob("*.sql"))
        + list((sql_root / "data/sql/updates/pending_db_world").glob("*.sql")),
        key=lambda p: p.name)
    for f in files:
        rp.vars.clear()
        rp.run(f.read_text(encoding="utf-8", errors="replace"), f.name)
    rp.db.commit()
    # Nothing downstream reads reference_loot_template, and CoA fills parts of it from tables this replay
    # does not model (its dungeon spoils, from coa_dungeon_loot_variant), so those cannot fail the build.
    go_failures = [f for f in rp.failures if re.search(r"gameobject", f[2], re.I)
                   or (re.search(r"reference_loot", f[2], re.I) and not f[1].startswith("no such table"))]
    if go_failures:
        for label, err, stmt in go_failures[:20]:
            print(f"  replay failure [{label}] {err}: {stmt[:160]}")
        raise SystemExit(f"{len(go_failures)} statements on the gameobject tables failed to replay")
    return rp.db


if __name__ == "__main__":
    db = build(sys.argv[1], Path(sys.argv[2]) if len(sys.argv) > 2 else COA)
    n = db.execute("SELECT COUNT(*) FROM gameobject WHERE ScriptName = 'worldforged_pickup'").fetchone()[0]
    print(f"replayed: {n} worldforged pickup spawns")
