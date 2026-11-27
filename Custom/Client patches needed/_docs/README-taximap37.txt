TaxiMap37.blp -- flight-map background for map 37 (Azshara Crater)
=================================================================
Deployed 2026-08-29. Third custom taxi map after 750 and 751; see
README-taximap750.txt for the original write-up of how the pieces fit together.

WHAT SHIPS, AND WHERE
  Interface\TaxiFrame\TaxiMap37.blp     -> Data\patch-5.MPQ
      512x512 BLP2 / DXT1 / 10 mips, 175,948 bytes.
      Cropped from Interface\WorldMap\AzsharaCrater\AzsharaCrater1..12.blp
      (the zone's own world map, already in patch-5).
      NOT present anywhere in the Data\enGB chain, so patch-5 alone is enough --
      unlike TaxiMap750.blp, which exists in both and has to be kept in sync.

  DBFilesClient\WorldMapContinent.dbc   -> Data\patch-4.MPQ  AND
                                           Data\enGB\patch-enGB-3.MPQ
      Both archives held byte-identical 10-row copies, so both were rewritten
      with the new 11-row build. 11 rows x 56 B + 20 B header + 1 B strings = 637 B.
      Client-side only -- the worldserver never loads this table, so there is
      nothing to scp to the server's data/dbc.

  New row: id 11, MapID 37
      boundaries 27 / 36 / 28 / 35   offsets 0 / 0   scale 0.7   WorldMapID 1
      box: TaxiMinX -700  TaxiMaxX 1700   TaxiMinY -750  TaxiMaxY 1650
           (square, 2400x2400)

THE TWO MUST SHIP TOGETHER. The DBC's Taxi box is the world rectangle the image
covers; one without the other puts every flight point in the wrong place.

WHY THIS BOX
The art is registered against the world by WorldMapArea 613
(LocLeft 2427 / LocRight -1884 / LocTop 1756 / LocBottom -1116), whose 4311x2872
aspect matches the art's own 1002x668 to within a pixel -- so reusing that
projection makes a taxi pin and a world-map pin for the same node land on the
same piece of parchment.

Squaring the WHOLE zone box would letterboard a third of the frame into blank
parchment, because the zone is 1.5:1 and the taxi frame is 1:1. The five camps
sit inside a 1102x955 patch of it, so the box is a 2400x2400 square centred on
them instead: >600 yd of margin around the outermost node, still fully inside the
art on all four sides (no fade band needed, unlike 751), and it crops 558x558
source pixels for a 512x512 output -- a slight DOWNscale, so nothing blurs and
the source's own labels and banner survive.

Node landing spots on the 512x512 image, as a registration check:
      441 Startcamp (153,347)   442 Level 30+ (240,369)   443 Level 50+ (325,230)
      444 Level 65+ (357,134)   445 Level 70+ (345,369)

REGENERATE
  python Custom/Documentation/scripts/bake_taximap37.py
It re-extracts the tiles, re-crops, re-encodes, writes both the .blp and the
_preview.png into Custom/Client patches needed/Interface/TaxiFrame/, and prints
the box to copy into WorldMapContinent.

SERVER SIDE (not part of this patch, but the map is dead without it)
  src/server/scripts/DC/AC/ac_flightmasters.cpp now opens this frame DIRECTLY from
  OnGossipHello -- right-click a crater flight master and the map is what you get.
  The fixed-route gossip list it used to show ("Camp to Level 30+" etc.) is gone;
  every destination it offered is a click on the map instead. Recoverable from git
  if the map ever disappoints.

  The script cannot just be unbound the way 750/751's was, because it is the only
  place the five nodes get granted: the taxi frame draws only DISCOVERED nodes and
  the crater's camps are reachable only by flying, so a new player would open a map
  with one dot on it. Same reason the NPCs keep npcflag 8193 rather than dropping
  the GOSSIP bit to let the client open the frame by itself.

  Needs a worldserver rebuild.
