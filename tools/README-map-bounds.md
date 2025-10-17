Map Bounds Extractor
====================

This small tool scans the client's `World/Maps/<map>/` folders and inspects WDT/ADT tiles to produce a conservative
tile-based map bounds CSV at `var/map_bounds.csv`.

When to use
-----------
- If your server does not have reliable `WorldMapArea.dbc` extents for custom maps, use this extractor where the
  client's map files exist (for example on your workstation with the game client installed).

How it works
------------
- The extractor uses the `WDTFile`/`ADTFile` helpers found in `src/tools/vmap4_extractor/` to detect which ADT tiles
  exist for each map and computes bounds by assuming each ADT tile is ~533.3333 world units wide.

Usage
-----
Build it as a standalone program (this repository may already have a tools build target):

1. Compile `tools/map_bounds_extractor.cpp` with a C++17 compiler and ensure the extractor headers (`wdtfile.h`/`adtfile.h`)
   are available in the include path.
2. Run:

   map_bounds_extractor "C:/Program Files (x86)/World of Warcraft/_classic_/" 

   (adjust path to your client data root). The program writes `var/map_bounds.csv`.

3. Inspect `var/map_bounds.csv` and optionally commit it to your server repo to provide stable bounds for the server
   at runtime.

Server integration
------------------
- The hotspots system will load `var/map_bounds.csv` on startup and will also attempt runtime parsing of client data if
  `Hotspots.ClientDataPath` is configured. The hybrid approach uses DBC first, then CSV, then ADT/WDT (runtime) fallbacks.
