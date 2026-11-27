"""Rewrites Hyjal Frontier quest and leveling SQL so that:

  1. 07_Leveling_Items.sql entries are renumbered to be strictly sorted by
     required level while keeping the vendor token block (400000-400010)
     in place.
  2. 06_Quest_Items.sql and 07_Leveling_Items.sql ItemLevel and stat
     budgets are rescaled upward so every freshly-created Hyjal piece is a
     clear buff over standard live-realm level-80 endgame gear.

Target ilvl ramp (was -> now):
    req 80  starter ring/pendant/cloak  264 -> 300
    req 82  Foothills slot expansion    264 -> 300
    req 88  Foothills rare loot         277 -> 316
    req 95  Scorched quest              284 -> 332
    req 97  Scorched slot expansion     284 -> 332
    req 103 Scorched rare loot          297 -> 352
    req 110 Summit quest / class chest  304 -> 372
    req 112 Summit slot expansion       304 -> 372
    req 125 Nordrassil loot / helms     317 -> 398
    req 127 Nordrassil slot expansion   317 -> 398

For each item the factor is new_ilvl / old_ilvl; SellPrice, stat values
1-5, and armor scale by that factor. Budget floor is 1 so 0-valued
columns (unused stats, plate cloth armor=0) stay zero.

The script is idempotent: it looks at each item's current ItemLevel and
maps it to the new target directly, so re-running it is a no-op once the
new ilvls are in place.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"k:\Dark-Chaos\DarkChaos-255-Master")
DIR = ROOT / "Custom" / "Level Areas" / "Hyjal 80 - 130"

QUEST_FILE = DIR / "06_Quest_Items.sql"
LEVELING_FILE = DIR / "07_Leveling_Items.sql"

# Required-level -> new ilvl
TARGET_ILVL = {
    80: 300,
    82: 300,
    88: 316,
    95: 332,
    97: 332,
    103: 352,
    110: 372,
    112: 372,
    125: 398,
    127: 398,
}

# Old ilvl -> new ilvl (fallback when we only know ItemLevel)
OLD_TO_NEW_ILVL = {
    264: 300,
    277: 316,
    284: 332,
    297: 352,
    304: 372,
    317: 398,
}

# Leveling-items entry renumbering (old -> new). Vendor block is
# unchanged; the endgame ranges (>=400200) are untouched.
LEVELING_ID_MAP: dict[int, int] = {}
def _add(old_start: int, old_end: int, new_start: int) -> None:
    for i, old in enumerate(range(old_start, old_end + 1)):
        LEVELING_ID_MAP[old] = new_start + i

# Foothills slot expansion (req 82) 400065-400079 -> 400041-400055
_add(400065, 400079, 400041)
# Scorched slot expansion (req 97) 400080-400094 -> 400056-400070
_add(400080, 400094, 400056)
# Summit class chests (req 110) 400041-400052 -> 400071-400082
_add(400041, 400052, 400071)
# Summit slot expansion (req 112) 400095-400109 -> 400083-400097
_add(400095, 400109, 400083)
# Nordrassil helms (req 125) 400053-400064 -> 400098-400109
_add(400053, 400064, 400098)
# Nordrassil slot expansion (req 127) 400110-400124 stays 400110-400124
for e in range(400110, 400125):
    LEVELING_ID_MAP[e] = e

# =====================================================================
# Tuple-aware rewriter
# =====================================================================

# Matches a multi-line VALUES tuple that starts with `(<6-digit-entry>,`.
# Greedy up to the matching closing `),` or `);`.
_TUPLE_RE = re.compile(r"\((4\d{5})\s*,.*?\)(?=\s*[,;])", re.DOTALL)


def _scale(value_str: str, factor: float) -> str:
    v = int(value_str.strip())
    if v == 0:
        return value_str
    return str(max(1, round(v * factor)))


def _rewrite_tuple(body: str, id_map: dict[int, int] | None) -> str:
    """Rewrite a single INSERT tuple body.

    body already includes the outer parentheses.
    """
    # Split payload off the surrounding parens.
    assert body.startswith("(") and body.endswith(")"), body[:40]
    inner = body[1:-1]

    # Split on top-level commas, respecting single-quoted strings that may
    # contain escaped apostrophes (\').
    parts: list[str] = []
    depth = 0
    in_str = False
    escape = False
    buf: list[str] = []
    for ch in inner:
        if in_str:
            buf.append(ch)
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == "'":
                in_str = False
            continue
        if ch == "'":
            in_str = True
            buf.append(ch)
        elif ch == "(":
            depth += 1
            buf.append(ch)
        elif ch == ")":
            depth -= 1
            buf.append(ch)
        elif ch == "," and depth == 0:
            parts.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    parts.append("".join(buf))

    # Preserve leading whitespace of each field for stable formatting.
    def repl(idx: int, new_val: str) -> None:
        raw = parts[idx]
        m = re.match(r"(\s*)(.*)$", raw, re.DOTALL)
        lead = m.group(1) if m else ""
        parts[idx] = f"{lead}{new_val}"

    # Only rewrite 34-column item_template rows. Other schemas (token row
    # with 22 cols, itemextendedcost_dbc, npc_vendor) are left untouched.
    if len(parts) != 34:
        return body

    entry = int(parts[0].strip())
    ilvl_raw = parts[15].strip()
    try:
        old_ilvl = int(ilvl_raw)
    except ValueError:
        return body

    new_ilvl = OLD_TO_NEW_ILVL.get(old_ilvl, old_ilvl)
    if new_ilvl == old_ilvl:
        # Not one of our tracked leveling ilvls - leave alone.
        return body
    factor = new_ilvl / old_ilvl

    repl(15, str(new_ilvl))            # ItemLevel
    repl(11, _scale(parts[11], factor))  # SellPrice
    for stat_idx in (21, 23, 25, 27, 29):
        repl(stat_idx, _scale(parts[stat_idx], factor))
    repl(30, _scale(parts[30], factor))  # armor

    if id_map is not None and entry in id_map:
        repl(0, str(id_map[entry]))

    return "(" + ",".join(parts) + ")"


def rewrite(path: Path, id_map: dict[int, int] | None) -> None:
    text = path.read_text(encoding="utf-8")

    def _sub(m: re.Match) -> str:
        return _rewrite_tuple(m.group(0), id_map)

    new_text = _TUPLE_RE.sub(_sub, text)

    # For the leveling file, also remap entry numbers in:
    #   - DELETE range header comments (leave ranges alone - written by hand below)
    #   - npc_vendor `item` column references
    if id_map is not None:
        # Update npc_vendor INSERT rows pointing at remapped entries. The
        # vendor block here only references 400001-400010 which are not in
        # the map, so this is a no-op in practice but future-proof.
        def _vendor_repl(mo: re.Match) -> str:
            eid = int(mo.group(2))
            new = id_map.get(eid, eid)
            return f"{mo.group(1)}{new}{mo.group(3)}"

        new_text = re.sub(
            r"(\(\s*830024\s*,\s*\d+\s*,\s*)(\d+)(\s*,)",
            _vendor_repl,
            new_text,
        )

    path.write_text(new_text, encoding="utf-8")


def main() -> None:
    rewrite(QUEST_FILE, id_map=None)
    rewrite(LEVELING_FILE, id_map=LEVELING_ID_MAP)
    print("Rewrote:")
    print(f"  {QUEST_FILE.name}")
    print(f"  {LEVELING_FILE.name}")


if __name__ == "__main__":
    main()
