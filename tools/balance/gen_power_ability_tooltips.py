"""Tooltips for the attacks that take DC.Balance.PowerAbilities.

The core multiplies the damage of a short list of attack-power abilities above level 80
(DarkChaos::BalanceReference::PowerAbilityGrowth: a white hit's growth divided by the reference
attack power's growth). The client works a tooltip out from the formula in the spell's description,
so the same growth has to stand in that formula. The description parser has player level ($PL),
$max and $min but no table lookup, so the curve is written as straight segments between the levels
where the gear ladder bends. The result stays within 2% of the server's factor up to level 160 and
holds its level-160 value above that (the server's falls slowly, to 7% less at 255).

Run from the repository root:
    python tools/balance/gen_power_ability_tooltips.py            show the formula and what would change
    python tools/balance/gen_power_ability_tooltips.py --apply    rewrite Custom/CSV DBC/Spell.csv
    python tools/balance/gen_power_ability_tooltips.py --dbc IN OUT  the same change in a compiled Spell.dbc

The fork's Spell.dbc has 234 fields and no table definition, so it is never compiled from the CSV as
a whole; --dbc rewrites the description string of the listed records in the binary and leaves every
other record and string byte-identical.

Only the description text of the listed records changes; every other byte of the CSV stays as it
is. A second run finds the new formulas in place and changes nothing. After a change to
gen_reference.py that moves the curve, restore the stock formulas first (git) and run again.
"""
import io
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_reference  # noqa: E402

CSV_PATH = os.path.join(HERE, "..", "..", "Custom", "CSV DBC", "Spell.csv")

# Description_Lang_enUS: CSV column 168, and two fields further on in the 234-field DBC
# (dbc = csv[0:13] + [0] + csv[13] + [0] + csv[14:]).
DBC_FIELDS = 234
DBC_DESCRIPTION_FIELD = 170

# Share of a level-80 white hit that is weapon damage (same constant as the core's).
WEAPON_SHARE = gen_reference.WEAPON_SHARE_OF_HIT_80
# Levels where the curve is pinned; straight lines between them.
PINS = (80, 90, 119, 141, 160)


def growth(level):
    """The core's PowerAbilityGrowth."""
    if level <= 80:
        return 1.0
    melee = gen_reference.melee_growth(level)
    attack_power = (melee - WEAPON_SHARE * gen_reference.weapon_growth(level)) / (1.0 - WEAPON_SHARE)
    return max(1.0, melee / attack_power)


def segments():
    """(start level, width in levels, slope per level) for each straight piece."""
    out = []
    for low, high in zip(PINS, PINS[1:]):
        slope = round((growth(high) - growth(low)) / (high - low), 4)
        out.append((low, high - low, slope))
    return out


def tooltip_growth(level):
    return 1.0 + sum(slope * max(0, min(width, level - low)) for low, width, slope in segments())


def factor_text():
    terms = "".join("+%.4f*$max(0,$min(%d,$PL-%d))" % (slope, width, low) for low, width, slope in segments())
    return "(1" + terms + ")"


def plan(fx):
    """spell id -> list of (stock formula, new formula)."""
    share = ("${$AP*$m1/100}", "${$AP*$m1/100*%s}" % fx)
    wave = ("${$m3/100*$AP}", "${$m3/100*$AP*%s}" % fx)
    disease = [
        ("${$m1*1.15+$AP*0.055*1.15}", "${($m1*1.15+$AP*0.055*1.15)*%s}" % fx),
        ("${$m1*1.15}", "${$m1*1.15*%s}" % fx),
        ("${$AP*0.055*1.15}", "${$AP*0.055*1.15*%s}" % fx),
    ]
    righteousness = [("${1+0.2*$AP+0.32*$SPH}", "${(1+0.2*$AP+0.32*$SPH)*%s}" % fx)]
    vengeance = [("${1+0.22*$SPH+0.14*$AP}", "${(1+0.22*$SPH+0.14*$AP)*%s}" % fx)]
    light = [("${1+0.25*$SPH+0.16*$AP}", "${(1+0.25*$SPH+0.16*$AP)*%s}" % fx)]
    return {
        23881: [share],                 # Bloodthirst
        34428: [share],                 # Victory Rush
        57755: [("${$m1+$AP*.50}", "${($m1+$AP*.50)*%s}" % fx)],   # Heroic Throw
        20252: [("${$AP*0.12}", "${$AP*0.12*%s}" % fx)],            # Intercept
        46968: [wave],                  # Shockwave
        12809: [wave],                  # Concussion Blow
        59921: disease,                 # Frost Fever (the passive that carries the numbers)
        59879: disease,                 # Blood Plague
        21084: righteousness,           # Seal of Righteousness, its judgement line
        20187: righteousness,           # Judgement of Righteousness
        31801: vengeance,               # Seal of Vengeance
        31804: vengeance,               # Judgement of Vengeance
        53736: vengeance,               # Seal of Corruption
        53733: vengeance,               # Judgement of Corruption
        20164: light,                   # Seal of Justice
        20165: light,                   # Seal of Light
        20166: light,                   # Seal of Wisdom
    }


def split_records(raw):
    """Byte offsets (start, end) of each CSV record; a record ends at a line feed outside quotes."""
    out = []
    start = 0
    quotes = 0
    pos = 0
    while True:
        end = raw.find(b"\n", pos)
        if end < 0:
            if start < len(raw):
                out.append((start, len(raw)))
            return out
        quotes += raw.count(b'"', pos, end)
        if quotes % 2 == 0:
            out.append((start, end + 1))
            start = end + 1
            quotes = 0
        pos = end + 1


def patch_dbc(source, target, todo):
    data = io.open(source, "rb").read()
    magic, count, fields, size, string_size = struct.unpack_from("<4s4I", data)
    if magic != b"WDBC" or fields != DBC_FIELDS or size != 4 * DBC_FIELDS:
        sys.exit("%s is not a %d-field Spell.dbc" % (source, DBC_FIELDS))
    body = bytearray(data[20:20 + count * size])
    strings = bytearray(data[20 + count * size:20 + count * size + string_size])
    index = {struct.unpack_from("<I", body, i * size)[0]: i for i in range(count)}
    changed = []
    already = []
    for spell in sorted(todo):
        if spell not in index:
            sys.exit("spell %d is not in %s" % (spell, source))
        at = index[spell] * size + 4 * DBC_DESCRIPTION_FIELD
        offset = struct.unpack_from("<I", body, at)[0]
        text = bytes(strings[offset:strings.index(b"\0", offset)])
        new = text
        for stock, wanted in todo[spell]:
            stock_b, wanted_b = stock.encode(), wanted.encode()
            if wanted_b in new:
                continue
            if new.count(stock_b) != 1:
                sys.exit("spell %d: expected the formula %s once in the DBC text, found it %d times"
                         % (spell, stock, new.count(stock_b)))
            new = new.replace(stock_b, wanted_b)
        if new == text:
            already.append(spell)
            continue
        struct.pack_into("<I", body, at, len(strings))
        strings += new + b"\0"
        changed.append(spell)
    out = struct.pack("<4s4I", b"WDBC", count, fields, size, len(strings)) + bytes(body) + bytes(strings)
    io.open(target, "wb").write(out)
    print("dbc: %d records, changed %d %s, already done %d, strings %d -> %d bytes, written %s"
          % (count, len(changed), changed, len(already), string_size, len(strings), target))


def main():
    apply = "--apply" in sys.argv
    ids_path = sys.argv[sys.argv.index("--ids") + 1] if "--ids" in sys.argv else None
    fx = factor_text()
    worst = max(abs(tooltip_growth(level) / growth(level) - 1.0) for level in range(81, 161))
    print("factor in the tooltips:", fx)
    print("levels 81-160: at most %.2f%% from the server's factor; at 150 tooltip %.3f, server %.3f"
          % (100 * worst, tooltip_growth(150), growth(150)))

    todo = plan(fx)
    if "--dbc" in sys.argv:
        at = sys.argv.index("--dbc")
        patch_dbc(sys.argv[at + 1], sys.argv[at + 2], todo)
        return

    raw = io.open(CSV_PATH, "rb").read()
    pieces = []
    last = 0
    changed = []
    already = []
    seen = set()
    for start, end in split_records(raw):
        record = raw[start:end]
        if not record.startswith(b'"'):
            continue
        try:
            spell = int(record[1:record.index(b'"', 1)])
        except ValueError:
            continue
        if spell not in todo:
            continue
        seen.add(spell)
        new = record
        for stock, target in todo[spell]:
            stock_b, target_b = stock.encode(), target.encode()
            if target_b in new:
                continue
            if new.count(stock_b) != 1:
                sys.exit("spell %d: expected the formula %s once, found it %d times" % (spell, stock, new.count(stock_b)))
            new = new.replace(stock_b, target_b)
        if new == record:
            already.append(spell)
            continue
        if new.count(b'"') != record.count(b'"'):
            sys.exit("spell %d: quote count changed" % spell)
        pieces.append(raw[last:start])
        pieces.append(new)
        last = end
        changed.append(spell)
    missing = sorted(set(todo) - seen)
    if missing:
        sys.exit("spells not found in the CSV: %s" % missing)
    pieces.append(raw[last:])
    result = b"".join(pieces)
    print("records to change: %d %s | already done: %d" % (len(changed), sorted(changed), len(already)))
    if apply and changed:
        io.open(CSV_PATH, "wb").write(result)
        print("written:", os.path.normpath(CSV_PATH), "| %d -> %d bytes" % (len(raw), len(result)))
    if ids_path:
        io.open(ids_path, "w", encoding="ascii", newline="\n").write("\n".join(str(s) for s in sorted(todo)) + "\n")
        print("ids written:", ids_path)


if __name__ == "__main__":
    main()
