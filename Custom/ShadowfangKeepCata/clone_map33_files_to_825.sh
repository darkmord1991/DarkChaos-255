#!/usr/bin/env bash
# Clone map 33 (Shadowfang Keep) server terrain to map 825.
#
# This is a pure RENAME-COPY: the map id lives only in the FILENAME, never inside
# any of these files, so no extractor run and no client art are needed.
#   maps/{id:03}{gx:02}{gy:02}.map          GridTerrainLoader.cpp:36
#   vmaps/{id:03}.vmtree + {id:03}_{ty:02}_{tx:02}.vmtile   MapTree.cpp:77-84
#   mmaps/{id:03}.mmap + {id:03}{gx:02}{gy:02}.mmtile       MMapMgr.h:48-49
#
# Usage:
#   ./clone_map33_files_to_825.sh /path/to/server/data           # dry run
#   ./clone_map33_files_to_825.sh /path/to/server/data --apply
set -euo pipefail

DATA="${1:-}"
APPLY="${2:-}"
SRC=033
DST=825

if [[ -z "$DATA" ]]; then
    echo "usage: $0 /path/to/server/data [--apply]" >&2
    exit 2
fi
for d in maps vmaps mmaps; do
    [[ -d "$DATA/$d" ]] || { echo "ERROR: $DATA/$d not found" >&2; exit 1; }
done

copied=0
skipped=0

do_copy() {
    local src="$1" dst="$2"
    if [[ -e "$dst" ]]; then
        skipped=$((skipped+1)); return
    fi
    if [[ "$APPLY" == "--apply" ]]; then
        cp -p "$src" "$dst"
    fi
    copied=$((copied+1))
}

# maps/  033GGGG.map -> 825GGGG.map
for f in "$DATA"/maps/${SRC}*.map; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    do_copy "$f" "$DATA/maps/${DST}${b#$SRC}"
done

# vmaps/ 033.vmtree -> 825.vmtree ; 033_TY_TX.vmtile -> 825_TY_TX.vmtile
for f in "$DATA"/vmaps/${SRC}.vmtree "$DATA"/vmaps/${SRC}_*.vmtile; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    do_copy "$f" "$DATA/vmaps/${DST}${b#$SRC}"
done

# mmaps/ 033.mmap -> 825.mmap ; 033GGGG.mmtile -> 825GGGG.mmtile
for f in "$DATA"/mmaps/${SRC}.mmap "$DATA"/mmaps/${SRC}*.mmtile; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    do_copy "$f" "$DATA/mmaps/${DST}${b#$SRC}"
done

echo "map ${SRC} -> ${DST}"
echo "  to copy : $copied"
echo "  existing: $skipped (left alone)"
echo "  expected: 25 .map + 1 .vmtree + 12 .vmtile + 1 .mmap + 25 .mmtile = 64"
if [[ "$APPLY" != "--apply" ]]; then
    echo
    echo "DRY RUN -- nothing written. Re-run with --apply."
fi
