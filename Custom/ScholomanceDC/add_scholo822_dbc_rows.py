"""Append the DarkChaos Scholomance clone (map 822) rows to the DBC CSVs.

APPEND-ONLY. Every stock row is copied through byte-for-byte and the new rows are added at
the end; nothing is re-serialised. A full CSV round-trip silently corrupts stock rows in
this repo (see the AreaTrigger incident, where a rebuild would have dropped 116 triggers),
so do not "clean up" by rewriting with csv.writer over the whole file.

Idempotent: re-running strips any row it previously added before appending again.

    python add_scholo822_dbc_rows.py            # dry run, prints what it would add
    python add_scholo822_dbc_rows.py --apply

WHAT THIS ADDS
    Map.csv             1 row  -- id 822, cloned from 289
    MapDifficulty.csv   3 rows -- ids 9358/9359/9360, cloned from 28/9128/9129

WHAT IT DELIBERATELY DOES NOT ADD
    AreaTrigger.csv     nothing. The clone's entrances and exit are trigger CREATURES
                        (07_portals.sql), because new areatriggers provably never fire on
                        this fork's custom maps -- the client sends no CMSG_AREATRIGGER even
                        when standing 2 yards from the centre of a correct, deployed row.

THE TWO FIELDS THAT CHANGE, AND WHY THE REST MUST NOT
    Directory  stays "SchoolofNecromancy". This is what makes the clone free on the client side:
               the map id lives only in server-side terrain FILENAMES, so the client loads
               the WMO it already has and no art, WDT or ADT work is needed at all.
    CorpseMapID  0 -> 751. Stock Scholomance sends corpses to map 0 (real Western
               Plaguelands). Left at 0 a player dying in the DC clone would run back as a
               ghost on the wrong continent entirely. CorpseX/CorpseY are unchanged because
               751 is a clone of that terrain and the gate is at the same coordinates.
"""
import argparse
import io
import os

CSV_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'CSV DBC')

SRC_MAP  = 289
NEW_MAP  = 822
NEW_NAME = 'Scholomance (DarkChaos)'

# Where corpses go. Stock says map 0; the clone belongs to the DC Lordaeron extension.
CORPSE_MAP = 751

# difficulty -> (new MapDifficulty id, source MapDifficulty id on map 329)
# Stock 329 already carries all three on this fork (9130/9131 were added by DC), and every
# one of the 468 cloned creature spawns uses spawnMask 7, so the clone needs all three or
# heroic and mythic come up as empty dungeons with no error anywhere.
MAPDIFF = {0: (9358, 28), 1: (9359, 9128), 2: (9360, 9129)}

# Field indices in Map.csv (66 fields).
MAP_ID, MAP_DIRECTORY, MAP_NAME_ENUS, MAP_CORPSE_MAPID = 0, 1, 5, 59
MAP_FIELDS = 66

# Field indices in MapDifficulty.csv (23 fields).
MD_ID, MD_MAPID, MD_DIFFICULTY, MD_MESSAGE_ENUS = 0, 1, 2, 3
MD_FIELDS = 23

# --- the dungeon map ---------------------------------------------------------------
# Scholomance has FOUR floors. floor -> (new DungeonMap id, source id on map 289).
DUNGEONMAP = {1: (769, 151), 2: (770, 152), 3: (771, 153), 4: (772, 154)}
DM_FIELDS = 8
DM_ID, DM_MAPID, DM_FLOOR, DM_PARENTWMA = 0, 1, 2, 7

# 26 chunk rows on map 289, spread over the four floors. Band 6818.. verified empty.
DMC_FIELDS = 5
DMC_ID, DMC_MAPID, DMC_DUNGEONMAPID = 0, 1, 3
DMC_ID_BASE = 6818

# WorldMapArea 763 is stock Scholomance's; 1277 is the next free id (max in use is 1276,
# which is the Stratholme clone's).
WMA_FIELDS = 11
WMA_ID, WMA_MAPID = 0, 1
WMA_NEW_ID, WMA_SRC_ID = 1278, 763


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


def find_row(lines, wanted_id, id_index=0):
    for line in lines:
        f = split_row(line)
        if f and f[id_index] == str(wanted_id):
            return f
    return None


def strip_ids(lines, ids, id_index=0):
    """Drop rows this script previously added, so re-running is idempotent."""
    ids = {str(i) for i in ids}
    kept, removed = [], 0
    for line in lines:
        f = split_row(line)
        if f and f[id_index] in ids:
            removed += 1
            continue
        kept.append(line)
    return kept, removed


def append_before_trailing_blank(lines, new_lines):
    """Insert before any trailing empty line so the file keeps its final newline."""
    tail = []
    while lines and lines[-1] == '':
        tail.append(lines.pop())
    return lines + new_lines + tail


def do_map(apply_it):
    lines = read_lines('Map.csv')
    src = find_row(lines, SRC_MAP)
    if src is None:
        raise SystemExit('Map.csv has no row %d -- cannot clone' % SRC_MAP)
    if len(src) != MAP_FIELDS:
        raise SystemExit('Map.csv row %d has %d fields, expected %d -- layout changed, '
                         'refusing to guess' % (SRC_MAP, len(src), MAP_FIELDS))

    row = list(src)
    row[MAP_ID] = str(NEW_MAP)
    row[MAP_NAME_ENUS] = NEW_NAME
    row[MAP_CORPSE_MAPID] = str(CORPSE_MAP)
    # Directory is intentionally NOT touched -- see the module docstring.

    print('Map.csv')
    print('  + id %s  Directory=%r  Name=%r  CorpseMapID=%s (stock had %s)'
          % (row[MAP_ID], row[MAP_DIRECTORY], row[MAP_NAME_ENUS],
             row[MAP_CORPSE_MAPID], src[MAP_CORPSE_MAPID]))

    lines, removed = strip_ids(lines, [NEW_MAP])
    if removed:
        print('  (replaced %d existing row(s) for id %d)' % (removed, NEW_MAP))
    lines = append_before_trailing_blank(lines, [join_row(row)])
    if apply_it:
        write_lines('Map.csv', lines)


def do_mapdifficulty(apply_it):
    lines = read_lines('MapDifficulty.csv')
    new_rows = []

    print('MapDifficulty.csv')
    for difficulty in sorted(MAPDIFF):
        new_id, src_id = MAPDIFF[difficulty]
        src = find_row(lines, src_id)
        if src is None:
            raise SystemExit('MapDifficulty.csv has no row %d -- cannot clone difficulty %d'
                             % (src_id, difficulty))
        if len(src) != MD_FIELDS:
            raise SystemExit('MapDifficulty.csv row %d has %d fields, expected %d'
                             % (src_id, len(src), MD_FIELDS))
        row = list(src)
        row[MD_ID] = str(new_id)
        row[MD_MAPID] = str(NEW_MAP)
        if row[MD_MESSAGE_ENUS]:
            row[MD_MESSAGE_ENUS] = row[MD_MESSAGE_ENUS].replace('Scholomance', NEW_NAME)
        new_rows.append(join_row(row))
        print('  + id %-5s map %s difficulty %s  (from %s)'
              % (row[MD_ID], row[MD_MAPID], row[MD_DIFFICULTY], src_id))

    lines, removed = strip_ids(lines, [i for i, _ in MAPDIFF.values()])
    if removed:
        print('  (replaced %d existing row(s))' % removed)
    lines = append_before_trailing_blank(lines, new_rows)
    if apply_it:
        write_lines('MapDifficulty.csv', lines)


def do_dungeonmap(apply_it):
    """The in-instance map the client draws when you open the world map inside the dungeon.

    Without these rows the map frame comes up blank -- which is what "dungeon map is missing"
    looks like. Three tables have to agree, and all three are keyed on the CLONE's map id:

        DungeonMap        one row per floor, giving that floor's world-space bounds
        DungeonMapChunk   maps each WMO group to the floor it belongs to
        WorldMapArea      the map-art entry the client resolves for map 821

    ParentWorldMapID is NOT changed. It points at the WorldMapArea of the OUTDOOR zone the
    dungeon hangs off -- 22 = WesternPlaguelands, on map 0. That stays stock even though the
    clone's entrance is on 751: the Shadowfang and Stratholme clones kept their own stock
    parents the same way, and both dungeon maps draw correctly.
    """
    lines = read_lines('DungeonMap.csv')
    new_rows = []
    print('DungeonMap.csv')
    for floor in sorted(DUNGEONMAP):
        new_id, src_id = DUNGEONMAP[floor]
        src = find_row(lines, src_id)
        if src is None:
            raise SystemExit('DungeonMap.csv has no row %d -- cannot clone floor %d'
                             % (src_id, floor))
        if len(src) != DM_FIELDS:
            raise SystemExit('DungeonMap.csv row %d has %d fields, expected %d'
                             % (src_id, len(src), DM_FIELDS))
        row = list(src)
        row[DM_ID] = str(new_id)
        row[DM_MAPID] = str(NEW_MAP)
        new_rows.append(join_row(row))
        print('  + id %-5s map %s floor %s  bounds %s..%s / %s..%s  parentWMA %s  (from %s)'
              % (row[DM_ID], row[DM_MAPID], row[DM_FLOOR], row[3], row[4], row[5], row[6],
                 row[DM_PARENTWMA], src_id))

    lines, removed = strip_ids(lines, [i for i, _ in DUNGEONMAP.values()])
    if removed:
        print('  (replaced %d existing row(s))' % removed)
    lines = append_before_trailing_blank(lines, new_rows)
    if apply_it:
        write_lines('DungeonMap.csv', lines)


def do_dungeonmapchunk(apply_it):
    """One row per WMO group, saying which floor of the dungeon map it belongs to.

    DungeonMapID is remapped through DUNGEONMAP: left pointing at the stock floor ids the
    clone's chunks would attach to stock Scholomance's floors instead of its own.
    """
    lines = read_lines('DungeonMapChunk.csv')
    floor_map = {str(src): str(new) for new, src in DUNGEONMAP.values()}

    src_rows = []
    for line in lines:
        f = split_row(line)
        if f and len(f) == DMC_FIELDS and f[DMC_MAPID] == str(SRC_MAP):
            src_rows.append(f)
    if not src_rows:
        raise SystemExit('DungeonMapChunk.csv has no rows for map %d' % SRC_MAP)

    new_rows, new_ids = [], []
    for i, src in enumerate(src_rows):
        row = list(src)
        row[DMC_ID] = str(DMC_ID_BASE + i)
        row[DMC_MAPID] = str(NEW_MAP)
        if row[DMC_DUNGEONMAPID] not in floor_map:
            raise SystemExit('DungeonMapChunk row %s points at DungeonMap %s, which is not '
                             'one of the floors being cloned %s'
                             % (src[DMC_ID], row[DMC_DUNGEONMAPID], sorted(floor_map)))
        row[DMC_DUNGEONMAPID] = floor_map[row[DMC_DUNGEONMAPID]]
        new_rows.append(join_row(row))
        new_ids.append(int(row[DMC_ID]))

    per_floor = {}
    for r in new_rows:
        per_floor.setdefault(split_row(r)[DMC_DUNGEONMAPID], 0)
        per_floor[split_row(r)[DMC_DUNGEONMAPID]] += 1
    print('DungeonMapChunk.csv')
    print('  + %d rows, ids %d..%d' % (len(new_rows), new_ids[0], new_ids[-1]))
    for dm in sorted(per_floor):
        print('      DungeonMapID %s : %d chunks' % (dm, per_floor[dm]))

    lines, removed = strip_ids(lines, new_ids)
    if removed:
        print('  (replaced %d existing row(s))' % removed)
    lines = append_before_trailing_blank(lines, new_rows)
    if apply_it:
        write_lines('DungeonMapChunk.csv', lines)


def do_worldmaparea(apply_it):
    """The map-art entry the client resolves for map 821.

    AreaName is kept as the stock "Scholomance". That string is what points the client at the
    map tiles, the overlay art and the click mask, so reusing it means the clone shows the
    real Scholomance map with no new art -- the same trick as sharing Map.dbc's Directory.
    """
    lines = read_lines('WorldMapArea.csv')
    src = find_row(lines, WMA_SRC_ID)
    if src is None:
        raise SystemExit('WorldMapArea.csv has no row %d' % WMA_SRC_ID)
    if len(src) != WMA_FIELDS:
        raise SystemExit('WorldMapArea.csv row %d has %d fields, expected %d'
                         % (WMA_SRC_ID, len(src), WMA_FIELDS))
    row = list(src)
    row[WMA_ID] = str(WMA_NEW_ID)
    row[WMA_MAPID] = str(NEW_MAP)

    print('WorldMapArea.csv')
    print('  + id %s  map %s  areaId %s  areaName %r  (from %s)'
          % (row[WMA_ID], row[WMA_MAPID], row[2], row[3], WMA_SRC_ID))

    lines, removed = strip_ids(lines, [WMA_NEW_ID])
    if removed:
        print('  (replaced %d existing row(s))' % removed)
    lines = append_before_trailing_blank(lines, [join_row(row)])
    if apply_it:
        write_lines('WorldMapArea.csv', lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--apply', action='store_true', help='write the CSVs (default: dry run)')
    args = ap.parse_args()

    do_map(args.apply)
    print()
    do_mapdifficulty(args.apply)
    print()
    do_dungeonmap(args.apply)
    print()
    do_dungeonmapchunk(args.apply)
    print()
    do_worldmaparea(args.apply)
    print()
    if args.apply:
        print('CSVs written. Now compile and deploy:')
        print('  csv2wdbc.py Map.csv MapDifficulty.csv')
        print('  deploy to patch-4.MPQ AND enGB/patch-enGB-3.MPQ  (enGB shadows patch-4 '
              'for DBCs on this client)')
        print('  sync-dbc-deploy.js  (all three WarcraftXLHost candidate dirs)')
        print('  copy Map.dbc/MapDifficulty.dbc to the SERVER dbc dir as well -- the')
        print('  worldserver reads its own copy and will reject map 821 without it')
    else:
        print('DRY RUN -- nothing written. Re-run with --apply.')


if __name__ == '__main__':
    main()
