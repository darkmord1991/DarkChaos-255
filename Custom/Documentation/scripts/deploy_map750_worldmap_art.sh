#!/usr/bin/env bash
# Deploy the Cata zone-map art for map 750 (Darkshore / Azshara / Ashenvale)
# plus the WorldMapArea.dbc rows that point at it.
#
# WHY: map 750's terrain and towns are Cataclysm (Lor'danel, Bilgewater
# Harbor), but WorldMapArea rows 1259/1260/1261 were byte-copies of the STOCK
# vanilla rows -- same texture folders (Darkshore / Aszhara / Ashenvale) AND
# the same vanilla Loc bounds. So the world map drew the pre-Cata art: no
# Lor'danel, no Bilgewater Harbor.
#
# The fix uses NEW texture folders so the stock Kalimdor (map 1) maps keep the
# vanilla art they need:
#     Interface\WorldMap\DarkshoreCata\DarkshoreCata1..12.blp
#     Interface\WorldMap\AszharaCata\AszharaCata1..12.blp
#     Interface\WorldMap\AshenvaleCata\AshenvaleCata1..12.blp
# and adopts Cata's own Loc bounds for Darkshore + Azshara (Ashenvale's bounds
# were already identical to Cata's). Bounds MUST travel with the art or the
# player arrow and every POI land in the wrong place.
#
# Art was extracted from K:/UntouchedClients/Cata/Data/enUS/locale-enUS.MPQ
# into Custom/WorldMapArt750/ (BLP2/DXT, mips present, 256x256 -- verified
# 3.3.5-compatible, no hasMips=2 green-texture cases).
#
# !! CLOSE THE WOW CLIENT FIRST -- MPQ writes fail with
# "FAILED to open ... read-write" while the client/WarcraftXLHost holds the
# archive. Do not kill the process; exit it normally.
#
# Re-runnable. Run from anywhere.
set -euo pipefail

TOOLS="K:/Dark-Chaos/wow.export-main/tools"
REPO="K:/Dark-Chaos/DarkChaos-255-Master"
ART="$REPO/Custom/WorldMapArt750"
PATCH="K:/WoW_3.3.5a_ 255 Fun/Data/patch-4.MPQ"
PATCH_LOCALE="K:/WoW_3.3.5a_ 255 Fun/Data/enGB/patch-enGB-3.MPQ"

cd "$TOOLS"

echo "== 1/3  zone map art -> patch-4.MPQ =="
ARGS=""
for z in AszharaCata DarkshoreCata AshenvaleCata; do
  for i in $(seq 1 12); do
    ARGS="$ARGS --set $ART/$z/$z$i.blp=Interface\\WorldMap\\$z\\$z$i.blp"
  done
done
python mpq_stormlib_patch.py --mpq "$PATCH" $ARGS

echo "== 2/3  WorldMapArea.dbc -> patch-4 + enGB-3 =="
# enGB patches outrank patch-N for files present in both, so the DBC goes to
# BOTH. The new BLP paths exist only in patch-4, which is fine -- nothing
# shadows them.
for m in "$PATCH" "$PATCH_LOCALE"; do
  python mpq_stormlib_patch.py --mpq "$m" \
    --set "$REPO/Custom/DBCs/WorldMapArea.dbc=DBFilesClient\\WorldMapArea.dbc"
done

echo "== 3/3  sync DBC to the WarcraftXLHost candidate dirs =="
node sync-dbc-deploy.js --files WorldMapArea.dbc

echo
echo "Done. Restart the client, then open the map on Azshara (80-90):"
echo "  * Bilgewater Harbor, the Rocketway and Gallywix's palace must be drawn"
echo "  * Darkshore must show Lor'danel instead of Auberdine"
echo "  * the player arrow and quest POIs must sit in the right places"
