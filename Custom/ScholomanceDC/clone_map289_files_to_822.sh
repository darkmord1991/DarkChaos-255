#!/usr/bin/env bash
# Clone map 289 (Scholomance) server terrain to map 822.
#
# This is a pure RENAME-COPY: the map id lives only in the FILENAME, never inside any of
# these files, so no extractor run and no client art are needed. The client still loads the
# same WMO because Map.dbc row 822 keeps Directory = "SchoolofNecromancy".
#
#   maps/{id:03}{gx:02}{gy:02}.map                          GridTerrainLoader.cpp:36
#   vmaps/{id:03}.vmtree + {id:03}_{ty:02}_{tx:02}.vmtile   MapTree.cpp:77-84
#   mmaps/{id:03}.mmap + {id:03}{gx:02}{gy:02}.mmtile       MMapMgr.h:48-49
#
# Without this the map registers and players teleport in, then fall through the world:
# there is no heightmap, no collision and no navmesh for map 822.
#
# Usage:
#   ./clone_map289_files_to_822.sh /path/to/server/data           # dry run
#   ./clone_map289_files_to_822.sh /path/to/server/data --apply
set -euo pipefail

DATA="${1:-}"
APPLY="${2:-}"
SRC=289
DST=822

if [[ -z "$DATA" ]]; then
    echo "usage: $0 /path/to/server/data [--apply]" >&2
    exit 2
fi
for d in maps vmaps mmaps; do
    [[ -d "$DATA/$d" ]] || { echo "ERROR: $DATA/$d not found" >&2; exit 1; }
done

copied=0
skipped=0
src_seen=0

do_copy() {
    local src="$1" dst="$2"
    src_seen=$((src_seen+1))
    if [[ -e "$dst" ]]; then
        skipped=$((skipped+1)); return
    fi
    if [[ "$APPLY" == "--apply" ]]; then
        cp -p "$src" "$dst"
    fi
    copied=$((copied+1))
}

# maps/  289GGGG.map -> 822GGGG.map
for f in "$DATA"/maps/${SRC}*.map; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    do_copy "$f" "$DATA/maps/${DST}${b#$SRC}"
done
n_map=$src_seen

# vmaps/ 289.vmtree -> 822.vmtree ; 289_TY_TX.vmtile -> 822_TY_TX.vmtile
for f in "$DATA"/vmaps/${SRC}.vmtree "$DATA"/vmaps/${SRC}_*.vmtile; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    do_copy "$f" "$DATA/vmaps/${DST}${b#$SRC}"
done
n_vmap=$((src_seen - n_map))

# mmaps/ 289.mmap -> 822.mmap ; 289GGGG.mmtile -> 822GGGG.mmtile
for f in "$DATA"/mmaps/${SRC}.mmap "$DATA"/mmaps/${SRC}*.mmtile; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    do_copy "$f" "$DATA/mmaps/${DST}${b#$SRC}"
done
n_mmap=$((src_seen - n_map - n_vmap))

echo "map ${SRC} -> ${DST}"
echo "  source files found : $src_seen  (maps $n_map, vmaps $n_vmap, mmaps $n_mmap)"
echo "  to copy            : $copied"
echo "  already present    : $skipped (left alone)"

# A source map with no .map files at all means the wrong data directory was given, or
# Scholomance was never extracted -- either way copying nothing would look like success.
if [[ "$n_map" -eq 0 ]]; then
    echo "ERROR: no ${SRC}*.map files found in $DATA/maps -- wrong data dir?" >&2
    exit 1
fi
if [[ "$n_mmap" -eq 0 ]]; then
    echo "WARNING: no mmaps for map ${SRC}. Creatures on 822 will not pathfind." >&2
fi

if [[ "$APPLY" != "--apply" ]]; then
    echo
    echo "DRY RUN -- nothing written. Re-run with --apply."
fi
