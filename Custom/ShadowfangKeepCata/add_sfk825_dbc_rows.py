"""Append the Cataclysm Shadowfang Keep clone (map 825) rows to the DBC CSVs.

APPEND-ONLY. Every stock row is copied through byte-for-byte and the new rows are
added at the end; nothing is re-serialised. A full CSV round-trip silently corrupts
stock rows in this repo (see the AreaTrigger incident), so do not "clean up" by
rewriting with csv.writer over the whole file.

Idempotent: re-running strips any row it previously added before appending again.

    python add_sfk825_dbc_rows.py            # dry run, prints what it would add
    python add_sfk825_dbc_rows.py --apply
"""
import argparse
import io
import os
import sys

CSV_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'CSV DBC')

SRC_MAP        = 33
NEW_MAP        = 825
NEW_MAPDIFF    = {0: 9352, 1: 9353, 2: 9354}   # difficulty -> new MapDifficulty id
SRC_MAPDIFF    = {0: 7,    1: 9100, 2: 9101}   # map 33's existing rows
NEW_MAP_NAME   = 'Shadowfang Keep (Cataclysm)'

# AreaTrigger: the entrance pair, cloned from stock Shadowfang Keep's own two triggers.
#
#   145  map 0,  radius 7  -- the door in Silverpine Forest -> into map 33
#   194  map 33, radius 5  -- just inside, by the arrival point -> back out to map 0
#
# The clone reuses their POSITIONS AND RADII verbatim and only changes ContinentID. That
# is deliberate: the entrance box and the arrival point sit 4.5 yd apart, well inside the
# exit trigger's 5 yd radius, which would normally be the "walk out and get teleported
# straight back in" trap. Stock demonstrably works with that geometry, so copying it
# exactly reproduces stock behaviour instead of inviting a guess about clearances.
#
# 751's Silverpine Forest (zone 4935) is a clone of stock zone 130, so the door is at the
# same coordinates -- verified: 53 creature and 16 gameobject spawns sit within 300 yd of
# it on map 751, and the nearest is 54 yd away.
#
# Ids 6960/6961: live MAX in AreaTrigger.csv is 6954. Client AreaTrigger ids must stay
# under 65535, so the 607xxx band some older DC docs mention is NOT usable here (and no
# 607xxx row exists in this CSV).
ENTRANCE_MAP = 751       # DC Plaguelands / Lordaeron extension, zone 4935 Silverpine

NEW_TRIGGERS = [
    # (new id, source id to copy geometry from, ContinentID for the copy, comment)
    (6960, 145, ENTRANCE_MAP, 'SFK Cata entrance, Silverpine on map 751'),
    (6961, 194, NEW_MAP,      'SFK Cata exit, inside map 825'),
]


def read_lines(name):
    with io.open(os.path.join(CSV_DIR, name), encoding='utf-8-sig', newline='') as fh:
        return fh.read().split('\n')


def write_lines(name, lines):
    with io.open(os.path.join(CSV_DIR, name), 'w', encoding='utf-8-sig', newline='') as fh:
        fh.write('\n'.join(lines))


def split_row(line):
    """Split a quoted CSV line. Every field in these files is quoted, no embedded quotes."""
    if not line.startswith('"'):
        return None
    return line[1:-1].split('","') if line.endswith('"') else None


def join_row(fields):
    return '"' + '","'.join(fields) + '"'


def find_row(lines, first_field):
    for i, l in enumerate(lines):
        f = split_row(l)
        if f and f[0] == str(first_field):
            return i, f
    return None, None


def drop_ids(lines, ids):
    """Remove rows whose ID column is in `ids` (idempotency)."""
    ids = {str(i) for i in ids}
    keep, dropped = [], 0
    for l in lines:
        f = split_row(l)
        if f and f[0] in ids:
            dropped += 1
            continue
        keep.append(l)
    return keep, dropped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()

    plan = []

    # ---------------- Map.csv ----------------
    lines = read_lines('Map.csv')
    lines, d = drop_ids(lines, [NEW_MAP])
    i, src = find_row(lines, SRC_MAP)
    if src is None:
        sys.exit('Map.csv: source row %d not found' % SRC_MAP)
    row = list(src)
    row[0] = str(NEW_MAP)
    row[5] = NEW_MAP_NAME          # MapName_Lang_enUS
    # Directory stays "Shadowfang": the clone SHARES the source's client art, which is
    # what makes this cheap -- no new WDT/ADT and no extractor run.
    assert row[1] == 'Shadowfang', 'unexpected Directory %r' % row[1]
    map_row = join_row(row)
    plan.append(('Map.csv', d, 1, 'map %d "%s", Directory %s, InstanceType %s'
                 % (NEW_MAP, NEW_MAP_NAME, row[1], row[2])))
    map_lines = lines + [map_row] if lines[-1] != '' else lines[:-1] + [map_row, '']

    # ---------------- MapDifficulty.csv ----------------
    mdl = read_lines('MapDifficulty.csv')
    mdl, d = drop_ids(mdl, NEW_MAPDIFF.values())
    new_rows = []
    for diff, new_id in sorted(NEW_MAPDIFF.items()):
        _, src = find_row(mdl, SRC_MAPDIFF[diff])
        if src is None:
            sys.exit('MapDifficulty.csv: source row %d not found' % SRC_MAPDIFF[diff])
        r = list(src)
        r[0] = str(new_id)
        r[1] = str(NEW_MAP)
        if r[3]:                    # Message_Lang_enUS, only set on H/M
            r[3] = r[3].replace('Shadowfang Keep', NEW_MAP_NAME)
        new_rows.append(join_row(r))
    plan.append(('MapDifficulty.csv', d, len(new_rows),
                 'ids %s (normal/heroic/mythic), MaxPlayers 5'
                 % '/'.join(str(NEW_MAPDIFF[k]) for k in sorted(NEW_MAPDIFF))))
    md_lines = mdl + new_rows if mdl[-1] != '' else mdl[:-1] + new_rows + ['']

    # ---------------- AreaTrigger.csv ----------------
    atl = read_lines('AreaTrigger.csv')
    atl, d = drop_ids(atl, [t[0] for t in NEW_TRIGGERS])
    at_rows = []
    for new_id, src_id, continent, comment in NEW_TRIGGERS:
        _, src = find_row(atl, src_id)
        if src is None:
            sys.exit('AreaTrigger.csv: source row %d not found' % src_id)
        r = list(src)
        r[0] = str(new_id)          # ID
        r[1] = str(continent)       # ContinentID -- the ONLY geometry change
        at_rows.append(join_row(r))
    plan.append(('AreaTrigger.csv', d, len(at_rows),
                 'ids %s (entrance on %d, exit on %d), geometry copied from 145/194'
                 % ('/'.join(str(t[0]) for t in NEW_TRIGGERS), ENTRANCE_MAP, NEW_MAP)))
    at_lines = atl + at_rows if atl[-1] != '' else atl[:-1] + at_rows + ['']

    # ---------------- report ----------------
    for name, dropped, added, detail in plan:
        print('%-20s -%d stale  +%d   %s' % (name, dropped, added, detail))

    print()
    print('NOT touched, on purpose:')
    print('  AreaTable.csv -- no new area row. The clone shares map 33\'s terrain and WMO,')
    print('    so both area lookups (GridMap area bytes baked into the .map files, and')
    print('    WMOAreaTable for interiors -- which has no map column at all) keep returning')
    print('    stock area 209 "Shadowfang Keep". An AreaTable row keyed to ContinentID 825')
    print('    would simply never be produced by either lookup. 209 is also the name we want.')
    print('    To get a genuinely distinct zone name the WMO must be cloned under a new')
    print('    wmoID, the way Naxxramas 533 -> 2921 was done.')

    if not a.apply:
        print('\nDRY RUN -- nothing written. Re-run with --apply.')
        return

    write_lines('Map.csv', map_lines)
    write_lines('MapDifficulty.csv', md_lines)
    write_lines('AreaTrigger.csv', at_lines)
    print('\nWritten. Now recompile (from K:/Dark-Chaos/wow.export-main/tools):')
    print('  for T in Map MapDifficulty AreaTrigger:')
    print('    python csv2wdbc.py --csv "<repo>/Custom/CSV DBC/$T.csv" \\')
    print('        --out "<repo>/Custom/DBCs/$T.dbc" --table $T')
    print('  NOT Spell.dbc -- that is a 234-field fork layout; use spell-dbc-append.py.')
    print('Then deploy:')
    print('  python mpq_stormlib_patch.py --mpq "<client>/Data/patch-4.MPQ" --set ...')
    print('  node sync-dbc-deploy.js --files Map.dbc,MapDifficulty.dbc,AreaTrigger.dbc')
    print('  and copy Map.dbc + MapDifficulty.dbc to the server\'s data/dbc -- without the')
    print('  Map.dbc row the server asserts in MapMgr::CreateBaseMap on first entry.')


if __name__ == '__main__':
    main()
