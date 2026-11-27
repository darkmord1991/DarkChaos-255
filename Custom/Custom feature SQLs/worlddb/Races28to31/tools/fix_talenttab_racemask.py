#!/usr/bin/env python3
r"""
fix_talenttab_racemask.py - give every playable race its talent trees.

Each class tab in TalentTab.dbc has RaceMask 0xFFF, which is races 1-12. The client skips a tab whose mask is
set and leaves out the player's race (TalentInfo.cpp), so races 22 and up had no talent tabs at all. The server
only checks the class, so bots have talents and nothing on the server side showed it. DC-Talents then found no
tree, fell back to a class-wide spec id and failed building the window.

The class mask keeps choosing the tabs. Pet tabs have mask 0 and stay that way. Safe to run again. There is no
CSV for this table, so it patches Custom/DBCs/TalentTab.dbc directly. The client and server use the same file.

    python fix_talenttab_racemask.py
"""
import os
import struct
import sys

DBC = r"K:\Dark-Chaos\DarkChaos-255-Master\Custom\DBCs\TalentTab.dbc"
RACE_MASK_FIELD = 19
CLASS_MASK_FIELD = 20
OLD_MASK = 0xFFF
ALL_RACES = 0xFFFFFFFF
PLAYABLE_RACES = list(range(1, 13)) + list(range(22, 32))
CLASSES = (1, 2, 3, 4, 5, 6, 7, 8, 9, 11)


def records(data):
    magic, rows, fields, size, strings = struct.unpack_from("<4s4I", data, 0)
    if magic != b"WDBC" or fields != 24:
        raise SystemExit("unexpected TalentTab layout")
    return [(20 + i * size) for i in range(rows)]


def tabs_for(data, race, klass):
    """TalentInfo.cpp's filter for a player's own tabs."""
    count = 0
    for at in records(data):
        race_mask = struct.unpack_from("<I", data, at + RACE_MASK_FIELD * 4)[0]
        class_mask = struct.unpack_from("<I", data, at + CLASS_MASK_FIELD * 4)[0]
        if race_mask:
            if race_mask & (1 << (race - 1)) and (not class_mask or class_mask & (1 << (klass - 1))):
                count += 1
        elif class_mask & (1 << (klass - 1)):
            count += 1
    return count


def main():
    data = bytearray(open(DBC, "rb").read())
    changed = 0
    for at in records(data):
        if struct.unpack_from("<I", data, at + RACE_MASK_FIELD * 4)[0] == OLD_MASK:
            struct.pack_into("<I", data, at + RACE_MASK_FIELD * 4, ALL_RACES)
            changed += 1
    bad = [(race, klass) for race in PLAYABLE_RACES for klass in CLASSES if tabs_for(data, race, klass) != 3]
    print("tabs changed %d, race and class pairs without 3 tabs: %d %s" % (changed, len(bad), bad[:6]))
    if bad:
        raise SystemExit("the filter still leaves a playable race short")
    if changed:
        backup = DBC + ".pre-racemask.bak"
        if not os.path.exists(backup):
            with open(backup, "wb") as f:
                f.write(open(DBC, "rb").read())
        with open(DBC, "wb") as f:
            f.write(data)
    return 0


if __name__ == "__main__":
    sys.exit(main())
