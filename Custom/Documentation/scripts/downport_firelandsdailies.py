#!/usr/bin/env python3
"""
downport_firelandsdailies.py -- one-command terrain downport of the Cata "Molten
Front" map (FirelandsDailies, DC map 861) from the Cata 4.3.4 MPQ client to 3.3.5.

Mirrors wow.export/tools/downport-map.js's bake->MISS->extract->re-bake loop, but
sources from the **Cata MPQ client** (name-based) instead of retail CASC, because
FirelandsDailies is a real Cata map (verified: Map.dbc row 861, WDT + ADTs in
expansion3.MPQ). Footprint: 80 tiles, X 27-36 / Y 25-32 (parsed from the WDT).

Proven working: wxl-baker downports the Cata FirelandsDailies ADTs cleanly; this
just automates all 80 tiles + the referenced model/WMO/texture deps.

Usage:
  python downport_firelandsdailies.py \
      --cata "K:/UntouchedClients/Cata/Data" \
      --extract "K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py" \
      --baker  "K:/Dark-Chaos/dc-wotlkextensions/build/downport/Release/wxl-baker.exe" \
      --work   "K:/Dark-Chaos/retailextracts/dc_moltenfront_861" \
      [--max-passes 6]

Output: <work>/baked/world/maps/firelandsdailies/*  (the 3.3.5 ADT set) + any baked
models/textures. Then (offline, per HYJAL_MOLTENFRONT_HANDOFF.md):
  - pack into client patch-4 (World\\Maps\\FirelandsDailies + minimap),
  - run server mapextractor/vmap4/mmaps_generator for map 861,
  - Map.csv/AreaTable(4925)/MapDifficulty already registered (Custom/CSV DBC + DBCs).
"""
import argparse, os, re, subprocess, struct, sys

MAP = "FirelandsDailies"
# Cata split-ADT suffixes + the archives that hold FirelandsDailies content (priority order)
SUFFIXES = ["", "_obj0", "_obj1", "_tex0", "_tex1"]
ARCHIVES = ["expansion3.MPQ", "world.MPQ", "world2.MPQ", "art.MPQ", "base-Win.MPQ",
            "enUS/locale-enUS.MPQ", "enUS/expansion3-locale-enUS.MPQ"]

def sh(*args):
    return subprocess.run(args, capture_output=True, text=True)

def wdt_tiles(path):
    d = open(path, "rb").read(); i = 0; tiles = []
    while i + 8 <= len(d):
        magic = d[i:i+4][::-1]; size = struct.unpack("<I", d[i+4:i+8])[0]
        if magic == b"MAIN":
            body = d[i+8:i+8+size]
            for n in range(64*64):
                if struct.unpack("<I", body[n*8:n*8+4])[0] & 1:
                    tiles.append((n % 64, n // 64))
        i += 8 + size
    return tiles

def extract(extract_py, cata, name, out):
    # try each archive until the file lands (name-based, hash-resolved)
    for a in ARCHIVES:
        mpq = os.path.join(cata, a)
        if not os.path.exists(mpq): continue
        r = sh(sys.executable, extract_py, "--mpq", mpq, "--file", name.replace("/", "\\"),
               "--out", out, "--preserve-paths")
        if "1 written" in (r.stdout + r.stderr):
            return True
    return False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cata", required=True)
    ap.add_argument("--extract", required=True)
    ap.add_argument("--baker", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--max-passes", type=int, default=6)
    a = ap.parse_args()

    src = os.path.join(a.work, "src"); out = os.path.join(a.work, "baked")
    os.makedirs(src, exist_ok=True); os.makedirs(out, exist_ok=True)
    mapdir = f"World/Maps/{MAP}"

    # 1. WDT (+WDL) then every present tile's split ADTs
    for f in (f"{mapdir}/{MAP}.wdt", f"{mapdir}/{MAP}.wdl"):
        extract(a.extract, a.cata, f, src)
    wdt = os.path.join(src, mapdir, f"{MAP}.wdt")
    if not os.path.exists(wdt): sys.exit("WDT not extracted -- check --cata path")
    tiles = wdt_tiles(wdt)
    xs = [t[0] for t in tiles]; ys = [t[1] for t in tiles]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    print(f"{len(tiles)} tiles, bbox X{x0}-{x1} Y{y0}-{y1}")
    for (x, y) in tiles:
        for suf in SUFFIXES:
            extract(a.extract, a.cata, f"{mapdir}/{MAP}_{x}_{y}{suf}.adt", src)

    # 2. bake -> collect MISS -> extract deps -> re-bake, until stable
    for p in range(a.max_passes):
        r = sh(a.baker, "--in", src, "--out", out, "--tiles", MAP,
               str(x0), str(y0), str(x1), str(y1), "--deps", "--no-update")
        miss = re.findall(r"MISS\s+(\S+)", r.stdout + r.stderr)
        miss = [m for m in miss if not m.endswith(".wdl")]   # wdl optional
        print(f"pass {p+1}: {len(miss)} missing deps")
        if not miss: print("DONE -- 0 missing"); break
        got = 0
        for name in sorted(set(miss)):
            if extract(a.extract, a.cata, name, src): got += 1
        print(f"  extracted {got}/{len(set(miss))} deps")
        if got == 0:
            print("no further deps resolvable (rest are holes/absent) -- baked output usable"); break
    print(f"baked tree -> {out}/world/maps/firelandsdailies/")

if __name__ == "__main__":
    main()
