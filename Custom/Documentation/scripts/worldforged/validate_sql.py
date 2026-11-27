"""Structural checks for the generated worldforged SQL: arity, token well-formedness, id blocks, references.
A --delta file is checked against the shipped state it applies to, and the state it leaves is checked whole.

Usage: python validate_sql.py <rev_..._worldforged_*.sql> <work dir>
"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from gen_worldforged_750_751 import BLOCKS, dbc_path, shipped_state  # noqa: E402
from wdbc import DBC  # noqa: E402

DELETE_BLOCK = {"item_dbc": "item", "itemdisplayinfo_dbc": "idi", "gameobjectdisplayinfo_dbc": "godi",
                "gameobject_loot_template": "gotpl", "gameobject": "spawn"}

TOKEN = re.compile(r"^(NULL|-?\d+(\.\d+)?([eE][-+]?\d+)?|'(?:[^'\\]|''|\\.)*')$")


def split_fields(tup):
    fields, cur, in_str, i = [], [], False, 0
    while i < len(tup):
        c = tup[i]
        if in_str:
            cur.append(c)
            if c == "\\":
                cur.append(tup[i + 1])
                i += 2
                continue
            if c == "'":
                if tup[i + 1:i + 2] == "'":
                    cur.append("'")
                    i += 2
                    continue
                in_str = False
        elif c == "'":
            in_str = True
            cur.append(c)
        elif c == ",":
            fields.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    fields.append("".join(cur).strip())
    return fields


def tuples(body):
    depth, start, in_str, i = 0, None, False, 0
    while i < len(body):
        c = body[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == "'":
                if body[i + 1:i + 2] == "'":
                    i += 2
                    continue
                in_str = False
        elif c == "'":
            in_str = True
        elif c == "(":
            if depth == 0:
                start = i + 1
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                yield body[start:i]
        i += 1


def unquote(tok):
    return tok[1:-1].replace("''", "'").replace("\\\\", "\\") if tok.startswith("'") else tok


def main():
    sql = Path(sys.argv[1]).read_text(encoding="utf-8")
    work = Path(sys.argv[2])
    problems = []
    rows = defaultdict(list)
    for m in re.finditer(r"(?:INSERT|REPLACE) INTO `(\w+)` \(([^)]*)\) VALUES\n(.*?);\n", sql, re.S):
        table, cols = m.group(1), [c.strip(" `") for c in m.group(2).split(",")]
        for tup in tuples(m.group(3)):
            fields = split_fields(tup)
            if len(fields) != len(cols):
                problems.append(f"{table}: arity {len(fields)} != {len(cols)}: {tup[:120]}")
                continue
            bad = [f for f in fields if not TOKEN.match(f)]
            if bad:
                problems.append(f"{table}: malformed token(s) {bad[:3]}")
            rows[table].append(dict(zip(cols, (unquote(f) for f in fields))))
    for stmt in re.findall(r"^(DELETE FROM `\w+`[^;]*;)", sql, re.M):
        listed = re.match(r"DELETE FROM `(\w+)` WHERE `\w+` IN \(([\d, ]+)\);$", stmt)
        if listed and listed.group(1) in DELETE_BLOCK:
            lo, hi = BLOCKS[DELETE_BLOCK[listed.group(1)]]
            if all(lo <= int(v) <= hi for v in listed.group(2).split(",")):
                continue
        if "BETWEEN" not in stmt:
            problems.append("unscoped DELETE: " + stmt)
    print({t: len(r) for t, r in rows.items()})
    delta = re.search(r"_worldforged_(\w+)\.sql$", sys.argv[1])
    delta = delta.group(1) if delta and "--delta" in sql[:20000] else None
    shipped_tpls, shipped_items = set(), set()
    if delta:
        db, items_before, _overlays = shipped_state(work, delta)
        shipped_tpls = {e for (e,) in db.execute("SELECT entry FROM gameobject_template")}
        shipped_items = set(items_before)

    def ids(table, col):
        return [int(r[col]) for r in rows[table]]

    for table, col, blocks in (("item_template", "entry", ["item"]), ("item_dbc", "ID", ["item"]),
                               ("gameobject_template", "entry", ["gotpl", "prop_tpl"]),
                               ("gameobject_loot_template", "Entry", ["gotpl"]),
                               ("gameobject", "guid", ["spawn", "prop_spawn"]), ("itemdisplayinfo_dbc", "ID", ["idi"]),
                               ("gameobjectdisplayinfo_dbc", "ID", ["godi"])):
        vals = ids(table, col)
        if any(not any(BLOCKS[b][0] <= v <= BLOCKS[b][1] for b in blocks) for v in vals):
            problems.append(f"{table}.{col} outside its id block(s) {blocks}")
        if table != "gameobject_loot_template" and len(vals) != len(set(vals)):
            problems.append(f"{table}.{col} has duplicates")
    if max(ids("gameobject", "guid"), default=0) > 0xFFFFFF:
        problems.append("spawn guid above the 24-bit core cap")

    items = {int(r["entry"]): r for r in rows["item_template"]}
    item_dbc = {int(r["ID"]): r for r in rows["item_dbc"]}
    for e, r in items.items():
        d = item_dbc.get(e)
        if not d:
            problems.append(f"item {e} has no item_dbc row")
            continue
        for a, b in (("class", "ClassID"), ("subclass", "SubclassID"), ("displayid", "DisplayInfoID"),
                     ("InventoryType", "InventoryType"), ("sheath", "SheatheType"), ("Material", "Material")):
            if r[a] != d[b]:
                problems.append(f"item {e}: {a}={r[a]} but item_dbc {b}={d[b]}")
    dc_idi = set(DBC(dbc_path("ItemDisplayInfo.dbc")).ids()) | set(ids("itemdisplayinfo_dbc", "ID"))
    dc_godi = set(DBC(dbc_path("GameObjectDisplayInfo.dbc")).ids()) | set(ids("gameobjectdisplayinfo_dbc", "ID"))
    missing_idi = [e for e, r in items.items() if int(r["displayid"]) not in dc_idi]
    if missing_idi:
        problems.append(f"{len(missing_idi)} items point at unknown ItemDisplayInfo ids, e.g. {missing_idi[:5]}")
    tpls = {int(r["entry"]): r for r in rows["gameobject_template"]}
    missing_godi = [e for e, r in tpls.items() if int(r["displayId"]) not in dc_godi]
    if missing_godi:
        problems.append(f"{len(missing_godi)} templates point at unknown GameObjectDisplayInfo ids")
    chests = {e: r for e, r in tpls.items() if r["type"] == "3"}
    prop_lo, prop_hi = BLOCKS["prop_tpl"]
    if any(not (r["type"] == "5" and prop_lo <= e <= prop_hi and r["ScriptName"] == "")
           for e, r in tpls.items() if e not in chests):
        problems.append("a non-chest template is not a plain type-5 prop in the prop block")
    loot = Counter(int(r["Entry"]) for r in rows["gameobject_loot_template"])
    if not set(loot) <= set(chests) or set(chests) - shipped_tpls - set(loot) or any(n != 1 for n in loot.values()):
        problems.append("loot rows do not map one item to each template")
    if any(int(r["Item"]) not in items and int(r["Item"]) not in shipped_items
           for r in rows["gameobject_loot_template"]):
        problems.append("loot references an item outside this file")
    if any(int(r["Data1"]) != int(r["entry"]) or int(r["Data0"]) != 1689 or int(r["Data3"]) != 0
           for r in chests.values()):
        problems.append("template lock/lootId/consumable wrong")
    if any(int(r["id"]) not in tpls and int(r["id"]) not in shipped_tpls for r in rows["gameobject"]):
        problems.append("spawn references a template outside this file")
    if delta:
        db, items_after, _overlays = shipped_state(work)
        lo, hi = BLOCKS["spawn"]
        orphans = db.execute(f"""SELECT COUNT(*) FROM gameobject g LEFT JOIN gameobject_template t ON t.entry = g.id
                                 LEFT JOIN gameobject_loot_template l ON l.Entry = t.Data1
                                 WHERE g.guid BETWEEN {lo} AND {hi} AND (t.entry IS NULL OR l.Item IS NULL)""").fetchone()[0]
        no_item = [i for (i,) in db.execute("SELECT DISTINCT Item FROM gameobject_loot_template") if i not in items_after]
        spawns = db.execute(f"SELECT COUNT(*) FROM gameobject WHERE guid BETWEEN {lo} AND {hi}").fetchone()[0]
        plo, phi = BLOCKS["prop_spawn"]
        props, prop_orphans = db.execute(f"""SELECT COUNT(*), SUM(t.entry IS NULL) FROM gameobject g
                                             LEFT JOIN gameobject_template t ON t.entry = g.id
                                             WHERE g.guid BETWEEN {plo} AND {phi}""").fetchone()
        print(f"after this delta: {spawns} spawns, {orphans} without template or loot, "
              f"{len(no_item)} loot items without an item_template row; {props} props, {prop_orphans or 0} without "
              "template")
        if orphans or no_item or prop_orphans:
            problems.append("the state after this delta has spawns or loot pointing at nothing")
    if any(int(r["map"]) not in (750, 751) for r in rows["gameobject"]):
        problems.append("spawn off maps 750/751")
    neg = sum(1 for r in items.values() for k in range(1, 11) if int(r[f"stat_value{k}"]) < 0)
    if neg:
        problems.append(f"{neg} negative stats left")
    noarm = [e for e, r in items.items() if r["class"] == "4" and r["subclass"] in ("1", "2", "3", "4", "6")
             and r["InventoryType"] not in ("2", "11", "12", "23", "28") and int(r["armor"]) == 0]
    nodmg = [e for e, r in items.items() if r["class"] == "2" and float(r["dmg_max1"]) == 0]
    print(f"armor pieces with 0 armor: {len(noarm)}; weapons with 0 damage: {len(nodmg)}")
    unused_idi = set(ids("itemdisplayinfo_dbc", "ID")) - {int(r["displayid"]) for r in items.values()}
    unused_godi = set(ids("gameobjectdisplayinfo_dbc", "ID")) - {int(r["displayId"]) for r in tpls.values()}
    if unused_idi or unused_godi:
        problems.append(f"unused new display rows: idi {sorted(unused_idi)[:5]} godi {sorted(unused_godi)[:5]}")
    print("PROBLEMS:" if problems else "OK - no problems", *problems, sep="\n  ")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
