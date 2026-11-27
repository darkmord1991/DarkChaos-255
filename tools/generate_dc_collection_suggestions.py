#!/usr/bin/env python3
"""Generate DC-Collection "also collected" suggestion data (Ascension-style co-pick graphs).

Inspired by Project Ascension's SpellToSpellSuggestionData co-pick model: for every
collection entry, precompute the entries most associated with it and ship the result as a
static client data file - zero server load, resolved to icons/names client-side by the
existing DC:GetDefinition / DC:ResolveDefinitionIcon machinery.

Scoring is a HYBRID because a young realm has too few accounts for pure co-occurrence:
  score = 3 * coOwnerCount                (accounts owning both, from the ownership snapshot)
        + 2 * same source                 (same vendor/drop/quest source key)
        + 1.5 * same mount_type           (mounts only: ground/flying)
        + 1 * same rarity
        + 1 * same slot                   (heirlooms only)
        + 0.5 * same expansion            (mounts only)
As the population grows, re-export the ownership snapshot and regenerate - co-occurrence
progressively dominates the content-based prior.

Inputs (no DB connection needed):
  - Custom/Custom feature SQLs/collectionextracts/extracts.sql   (definitions dump; regenerate
    from the world DB when definitions change)
  - Custom/Custom feature SQLs/collectionextracts/ownership_snapshot.csv  (optional; export with:
      SELECT CONCAT_WS(':', collection_type, entry_id, account_id)
      FROM acore_chars.dc_collection_items
      WHERE unlocked = 1 AND collection_type IN (1,2,4);
    one "type:entry:account" per line, header ignored)

Output:
  - Custom/Client addons needed/DC-Collection/Data/SuggestionData.lua
    DC.SUGGESTION_DATA = { [typeId] = { [entryId] = { {e=id, s=score}, ... } } }
    typeId: 1=mounts, 2=pets, 4=heirlooms (matches Cache.lua TYPE_NAME_TO_ID)

Usage:  python tools/generate_dc_collection_suggestions.py
"""
import json
import os
import re
import sys
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRACTS = os.path.join(REPO, "Custom", "Custom feature SQLs", "collectionextracts", "extracts.sql")
OWNERSHIP = os.path.join(REPO, "Custom", "Custom feature SQLs", "collectionextracts", "ownership_snapshot.csv")
OUT = os.path.join(REPO, "Custom", "Client addons needed", "DC-Collection", "Data", "SuggestionData.lua")

TOP_N = 6
MIN_SCORE = 1.0


def split_tuples(values_blob):
    """Split an INSERT VALUES blob into per-row tuple strings (handles quoted commas/parens)."""
    rows, depth, cur, in_str, esc = [], 0, "", False, False
    for ch in values_blob:
        if esc:
            cur += ch
            esc = False
            continue
        if ch == "\\" and in_str:
            cur += ch
            esc = True
            continue
        if ch == "'":
            in_str = not in_str
            cur += ch
            continue
        if not in_str:
            if ch == "(":
                depth += 1
                if depth == 1:
                    cur = ""
                    continue
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    rows.append(cur)
                    cur = ""
                    continue
            elif ch == ";" and depth == 0:
                break  # end of this INSERT statement (don't run into following DDL)
        if depth >= 1:
            cur += ch
    return rows


def split_fields(row):
    """Split one tuple string into raw field strings."""
    fields, cur, in_str, esc = [], "", False, False
    for ch in row:
        if esc:
            cur += ch
            esc = False
            continue
        if ch == "\\" and in_str:
            cur += ch
            esc = True
            continue
        if ch == "'":
            in_str = not in_str
            cur += ch
            continue
        if ch == "," and not in_str:
            fields.append(cur.strip())
            cur = ""
            continue
        cur += ch
    fields.append(cur.strip())
    return fields


def parse_insert(sql_text, table):
    # Slice the file by INSERT sections rather than regexing to the first ';' -
    # source fields contain JSON with semicolons that would truncate the match.
    start = sql_text.find("INSERT INTO `%s`" % table)
    if start < 0:
        return [], []
    nxt = sql_text.find("INSERT INTO `", start + 16)
    section = sql_text[start:nxt if nxt > 0 else len(sql_text)]
    m = re.search(r"\(([^)]*)\)\s*VALUES\s*(.*)", section, re.S)
    if not m:
        return [], []
    cols = [c.strip().strip("`") for c in m.group(1).split(",")]
    return cols, [split_fields(r) for r in split_tuples(m.group(2))]


def unquote(v):
    v = v.strip()
    if v.upper() == "NULL":
        return None
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1].replace("\\'", "'").replace('\\"', '"')
    return v


def source_key(raw):
    """Reduce a source field (often JSON like {"npc":..,"type":"vendor"}) to a grouping key."""
    if not raw:
        return ""
    s = unquote(raw) or ""
    try:
        obj = json.loads(s)
        if isinstance(obj, dict):
            return "%s|%s" % (obj.get("type", ""), obj.get("npc", obj.get("zone", obj.get("boss", ""))))
    except (ValueError, TypeError):
        pass
    return s.lower()[:24]


def main():
    sql_text = open(EXTRACTS, encoding="utf-8", errors="replace").read()

    entries = {}  # (typeId, entryId) -> feature dict

    cols, rows = parse_insert(sql_text, "dc_mount_definitions")
    idx = {c: i for i, c in enumerate(cols)}
    for r in rows:
        eid = int(r[idx["spell_id"]])
        entries[(1, eid)] = {
            "src": source_key(r[idx["source"]]),
            "mt": unquote(r[idx["mount_type"]]),
            "rarity": unquote(r[idx["rarity"]]),
            "exp": unquote(r[idx["expansion"]]),
        }

    cols, rows = parse_insert(sql_text, "dc_pet_definitions")
    idx = {c: i for i, c in enumerate(cols)}
    for r in rows:
        eid = int(r[idx["pet_entry"]])
        entries[(2, eid)] = {
            "src": source_key(r[idx["source"]]) if "source" in idx else "",
            "rarity": unquote(r[idx["rarity"]]) if "rarity" in idx else "",
        }

    cols, rows = parse_insert(sql_text, "dc_heirloom_definitions")
    idx = {c: i for i, c in enumerate(cols)}
    for r in rows:
        eid = int(r[idx["item_id"]])
        entries[(4, eid)] = {
            "slot": unquote(r[idx["slot"]]) if "slot" in idx else "",
        }

    # Ownership -> co-occurrence counts per (type) between entry pairs.
    co = defaultdict(int)  # (typeId, a, b) a<b -> co-owner count
    if os.path.isfile(OWNERSHIP):
        by_owner = defaultdict(set)  # (typeId, account) -> set(entry)
        for line in open(OWNERSHIP, encoding="utf-8"):
            parts = line.strip().split(":")
            if len(parts) != 3 or not parts[0].isdigit():
                continue
            t, e, a = int(parts[0]), int(parts[1]), int(parts[2])
            by_owner[(t, a)].add(e)
        for (t, _a), owned in by_owner.items():
            owned = sorted(owned)
            for i, x in enumerate(owned):
                for y in owned[i + 1:]:
                    co[(t, x, y)] += 1

    # Score suggestion candidates per entry (same type only).
    by_type = defaultdict(list)
    for (t, e) in entries:
        by_type[t].append(e)

    suggestions = defaultdict(dict)  # typeId -> entryId -> [(score, other)]
    for t, ids in by_type.items():
        for e in ids:
            fe = entries[(t, e)]
            scored = []
            for o in ids:
                if o == e:
                    continue
                fo = entries[(t, o)]
                a, b = (e, o) if e < o else (o, e)
                score = 3.0 * co.get((t, a, b), 0)
                if fe.get("src") and fe.get("src") == fo.get("src"):
                    score += 2.0
                if t == 1 and fe.get("mt") == fo.get("mt"):
                    score += 1.5
                if fe.get("rarity") and fe.get("rarity") == fo.get("rarity"):
                    score += 1.0
                if t == 4 and fe.get("slot") and fe.get("slot") == fo.get("slot"):
                    score += 1.0
                if t == 1 and fe.get("exp") == fo.get("exp"):
                    score += 0.5
                if score >= MIN_SCORE:
                    scored.append((score, o))
            scored.sort(key=lambda x: (-x[0], x[1]))
            if scored:
                suggestions[t][e] = scored[:TOP_N]

    lines = [
        "-- Auto-generated by tools/generate_dc_collection_suggestions.py. Do not edit.",
        "-- \"Players who collected X also collected Y\" (Ascension-style co-pick graph,",
        "-- hybrid co-occurrence + content similarity). Regenerate when definitions or the",
        "-- ownership snapshot change. Keys: [typeId][entryId] -> array of {e=entry, s=score}.",
        "local DC = DCCollection",
        "if not DC then return end",
        "",
        "DC.SUGGESTION_DATA = {",
    ]
    for t in sorted(suggestions):
        lines.append("    [%d] = {" % t)
        for e in sorted(suggestions[t]):
            row = ", ".join("{e=%d,s=%.1f}" % (o, s) for s, o in suggestions[t][e])
            lines.append("        [%d] = { %s }," % (e, row))
        lines.append("    },")
    lines.append("}")
    lines.append("")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    total = sum(len(v) for v in suggestions.values())
    print("Wrote suggestions for %d entries (%s) -> %s" % (
        total, ", ".join("type%d=%d" % (t, len(v)) for t, v in sorted(suggestions.items())), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
