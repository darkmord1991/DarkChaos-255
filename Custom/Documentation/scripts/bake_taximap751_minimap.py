#!/usr/bin/env python3
"""Rebuild Interface\TaxiFrame\TaxiMap751.blp from map 751's own MINIMAP TILES.

WHY THE PREVIOUS TWO SOURCES BOTH FAILED
1. `bake_taximap751.js` composited the eight PER-ZONE world maps. Rendered and
   looked at: the zone BLPs are fully OPAQUE rectangles, so the result is a literal
   patchwork of overlapping tiles with hard edges. The `alpha < 8` cutout the script
   relies on does nothing because there is no alpha.
2. `bake_taximap751.py` cropped the stock Azeroth continent map. Geometrically this
   one is CORRECT -- rendering the crop box and the node positions onto the Azeroth
   image puts both squarely over Lordaeron -- but the region is only **246x276 px of
   a 1024x768 stylised overview**, upscaled ~2x to 512x512. Hence blurry and vague.

THE SOURCE THAT ACTUALLY WORKS
Map 751 already ships 195 baked minimap tiles (textures\Minimap\DCPlaguelands\
map<col>_<row>.blp, 256x256 each). They are ADT-aligned, so their world position is
exact arithmetic rather than a hand-placed box -- no registration guesswork at all --
and 195 x 256px is far more detail than the Azeroth crop can offer.

THE BOX -- terrain-tight E-W, PADDED N-S TO THE FRAME'S ASPECT
The taxi map is drawn into a fixed 316 x 352 region (TAXI_MAP_WIDTH/HEIGHT in
Blizzard's TaxiFrame.lua; the TaxiMap texture and TaxiRouteMap frame are both that
size in TaxiFrame.xml, so art and pins share one box). That region is PORTRAIT,
0.898 wide-to-tall.

A terrain-tight box is 9067 (E-W) x 6400 (N-S) -- LANDSCAPE, 1.417. Mapping a
landscape box onto a portrait frame squashes the continent horizontally to
(316/9067)/(352/6400) = **0.634 of its true width**. That is what "the flight map
does not fit" meant: not misplaced pins -- every node was verified to sit on a real
terrain tile -- but a continent drawn 37% too narrow. The pins are squashed by the
same factor, so they stay ON their landmarks; the whole picture is just wrong-shaped.

USE A SQUARE BOX -- and not only for proportions.
EVERY Blizzard box is square: Azeroth and Kalimdor 28800 on both axes, Outland and
Northrend square to within a rounding unit. That is not decoration. Because both
spans are equal, it is IMPOSSIBLE to tell from stock data which range the client
pairs with which screen axis -- taxiMinX/MaxX with the horizontal, or with world X
and therefore the vertical. A non-square box is the first thing that depends on the
answer, and a frame-aspect (0.898) box placed the pins visibly wrong in-game.

So: square, span = the larger terrain axis, centred on the terrain.

    N-S 6400 -> 9067 (centred), E-W left terrain-tight at 9067
    TaxiMinX -4000  TaxiMaxX 5067  TaxiMinY -6400  TaxiMaxY 2667

Terrain then fills 100% of the width and 71% of the height, with sea above and below,
taking only the frame's own 316:352 stretch -- exactly what every Blizzard continent
map takes. Filling the frame edge to edge was never the goal; drawing the land in
its real proportions is.

The empty slots in the tile grid are filled with a continuation of the terrain around
them (mapbake_inpaint) rather than left as flat blocks; everything outside the grid
stays sea.

WHY NOT THE PARCHMENT CROP, WHICH MATCHES MAP 750'S LOOK
Tried and rendered. It fills the frame fine with this box, but several nodes land in
painted OCEAN on the eastern side: the stock Azeroth art is WotLK Eastern Kingdoms
while map 751's terrain is CATA Lordaeron, and the coastlines differ. Accuracy wins;
a sepia grade below pulls the minimap composite toward the parchment palette.

THE BOX EMITTED HERE MUST BE WRITTEN TO WorldMapContinent id 10. Art and box are one
change -- that coupling is what broke the first attempt.
"""
import os, sys, json, subprocess, struct

SP = os.environ.get("SCRATCH", "")
TOOLS = r"K:/Dark-Chaos/wow.export-main/tools"
TILE = 1600.0 / 3.0
FRAME_ASPECT = 316.0 / 352.0   # Blizzard's TAXI_MAP_WIDTH / TAXI_MAP_HEIGHT
SIZE = 512                     # stored SQUARE. Geometrically neutral: the texture always
                               # fills the 316x352 region whatever its pixel dims, so the
                               # box -> frame mapping is unchanged. (blp-codec's
                               # makeBlpMips takes one dimension -- square only.)
BUILD_W, BUILD_H = 1024, 1024  # composite big, downscale once at the end
sys.path.insert(0, TOOLS)

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
from mapbake_inpaint import fill_holes, smooth_seam

ZONES = [
    ("Tirisfal Glades",      3033, -1485, 3838,   825),
    ("Silverpine Forest",    3450,  -750, 1667, -1133),
    ("Ruins of Gilneas",     3440,   294,  -533, -2631),
    ("Hillsbrad Foothills",  1067, -2133,  400, -1733),
    ("Western Plaguelands",   417, -3883, 3367,   500),
    ("Eastern Plaguelands", -2288, -6319, 3704,  1017),
    ("The Hinterlands",     -1575, -5425, 1467, -1100),
    ("Arathi Highlands",     -867, -4467,  -133, -2533),
]


def font(sz):
    for p in (r"C:\Windows\Fonts\georgiab.ttf", r"C:\Windows\Fonts\timesbd.ttf",
              r"C:\Windows\Fonts\arialbd.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def main():
    tiles = [tuple(t) for t in json.load(open(os.path.join(SP, "dcp_tiles.json")))]
    cols = [c for c, r in tiles]
    rows = [r for c, r in tiles]
    yMax, yMin = (32 - min(cols)) * TILE, (31 - max(cols)) * TILE
    xMax, xMin = (32 - min(rows)) * TILE, (31 - max(rows)) * TILE
    # SQUARE box -- see header. span = the larger terrain axis.
    spanY = yMax - yMin
    need = max(spanY, xMax - xMin)
    cx = (xMax + xMin) / 2.0
    xMin, xMax = cx - need / 2.0, cx + need / 2.0
    box = dict(TaxiMinX=xMin, TaxiMaxX=xMax, TaxiMinY=yMin, TaxiMaxY=yMax)
    spanX = xMax - xMin
    print("SQUARE box         X %.0f..%.0f (%.0f)   Y %.0f..%.0f (%.0f)   aspect %.3f"
          % (xMin, xMax, spanX, yMin, yMax, spanY, spanY / spanX))

    def px(y): return (box["TaxiMaxY"] - y) / spanY * BUILD_W
    def py(x): return (box["TaxiMaxX"] - x) / spanX * BUILD_H

    SEA = (28, 42, 54)
    canvas = Image.new("RGB", (BUILD_W, BUILD_H), SEA)   # sea, for the N/S bands
    cover = Image.new("L", (BUILD_W, BUILD_H), 0)
    cdraw = ImageDraw.Draw(cover)
    placed = 0
    for c, r in tiles:
        p = os.path.join(SP, "mmtiles", "map%d_%d.blp" % (c, r))
        if not os.path.exists(p):
            continue
        raw = os.path.join(SP, "mmtiles", "map%d_%d.bin" % (c, r))
        if not os.path.exists(raw):
            subprocess.run(["node", "-e",
                            "const fs=require('fs'),b=require('%s/blp-codec.js');"
                            "const {rgba}=b.blpMip0ToRGBA(fs.readFileSync('%s'));"
                            "fs.writeFileSync('%s',rgba);"
                            % (TOOLS, p.replace(os.sep, '/'), raw.replace(os.sep, '/'))],
                           capture_output=True)
        if not os.path.exists(raw):
            continue
        t = Image.frombytes("RGBA", (256, 256), open(raw, "rb").read()).convert("RGB")
        x0, x1 = px((32 - c) * TILE), px((31 - c) * TILE)
        y0, y1 = py((32 - r) * TILE), py((31 - r) * TILE)
        w, h = max(1, int(round(x1 - x0))), max(1, int(round(y1 - y0)))
        canvas.paste(t.resize((w, h), Image.LANCZOS), (int(round(x0)), int(round(y0))))
        cdraw.rectangle([int(round(x0)), int(round(y0)),
                         int(round(x0)) + w - 1, int(round(y0)) + h - 1], fill=255)
        placed += 1
    print("tiles placed: %d / %d" % (placed, len(tiles)))

    # Fill the empty slots INSIDE the tile grid with a continuation of the terrain
    # around them; everything outside the grid stays sea. Without this the gaps show
    # as flat blocks punched out of the continent.
    known = np.asarray(cover) > 0
    gx0, gx1 = int(round(px((32 - min(cols)) * TILE))), int(round(px((31 - max(cols)) * TILE)))
    gy0, gy1 = int(round(py((32 - min(rows)) * TILE))), int(round(py((31 - max(rows)) * TILE)))
    inside = np.zeros_like(known)
    inside[max(0, gy0):gy1, max(0, gx0):gx1] = True
    arr = fill_holes(np.asarray(canvas), known)
    arr = smooth_seam(arr, known, radius=2)
    out_of_grid = (~known) & (~inside)
    arr[out_of_grid] = SEA                       # keep the N/S bands honest sea
    canvas = Image.fromarray(arr)
    print("grid holes filled: %d px" % int(((~known) & inside).sum()))

    # Parchment grade -- blend toward sepia so the satellite-looking minimap art sits
    # closer to TaxiMap750's stock parchment palette without losing its accuracy.
    acc = canvas.load()
    for yy in range(BUILD_H):
        for xx in range(BUILD_W):
            r_, g_, b_ = acc[xx, yy]
            l = (r_ * 299 + g_ * 587 + b_ * 114) // 1000
            acc[xx, yy] = (int(r_ * .42 + min(255, int(l * 1.32)) * .58),
                           int(g_ * .42 + min(255, int(l * 1.09)) * .58),
                           int(b_ * .42 + int(l * 0.68) * .58))
    canvas = ImageEnhance.Contrast(canvas).enhance(1.12)

    d = ImageDraw.Draw(canvas)
    f = font(24)
    for name, L, R, T, B in ZONES:
        cx, cy = px((L + R) / 2.0), py((T + B) / 2.0)
        txt = name.upper()
        bb = d.textbbox((0, 0), txt, font=f)
        w_, h_ = bb[2] - bb[0], bb[3] - bb[1]
        ox = min(max(4, cx - w_ / 2), BUILD_W - w_ - 4)   # clamp so edge zones are not clipped
        oy = cy - h_ / 2
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                if dx or dy:
                    d.text((ox + dx, oy + dy), txt, font=f, fill=(24, 16, 8))
        d.text((ox, oy), txt, font=f, fill=(252, 240, 208))

    out = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.join(SP, "taxi3"), exist_ok=True)
    out.save(os.path.join(SP, "taxi3", "TaxiMap751_preview.png"))
    open(os.path.join(SP, "taxi3", "final.bin"), "wb").write(out.convert("RGBA").tobytes())
    src = os.path.join(SP, "taxi3", "final.bin").replace(os.sep, "/")
    dst = os.path.join(SP, "taxi3", "TaxiMap751.blp").replace(os.sep, "/")
    js = ("const fs=require('fs'),blp=require('%s/blp-codec.js');\n"
          "let cur=fs.readFileSync('%s'),w=%d,mips=[];\n"
          "while(w>=1){mips.push(blp.encodeDXT1(cur,w,w)); if(w===1)break;"
          " cur=blp.resizeRGBA(cur,w,w,w>>1,w>>1); w>>=1;}\n"
          "fs.writeFileSync('%s', blp.makeBlpMips(mips,%d));\n"
          "console.log('blp mips',mips.length);" % (TOOLS, src, SIZE, dst, SIZE))
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("ABORT: blp encode failed\n" + r.stderr[-800:])
    print(" ", r.stdout.strip())
    json.dump(box, open(os.path.join(SP, "taxi3", "taximap751_box.json"), "w"), indent=1)

    # Write the box into WorldMapContinent id 10 HERE, in the run that produced the
    # art. Printing it for a human to copy is how the first attempt shipped art and
    # box out of step.
    import csv as _csv, io as _io
    ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom"
    dbc = os.path.join(ROOT, "DBCs", "WorldMapContinent.dbc")
    raw = bytearray(open(dbc, "rb").read())
    rc_, fc_, rs_, ss_ = struct.unpack("<4I", raw[4:20])
    hit = 0
    for i in range(rc_):
        o = 20 + i * rs_
        if struct.unpack_from("<I", raw, o + 4)[0] == 751:      # field 1 = MapID
            # fields 9..12 = TaxiMinX, TaxiMinY, TaxiMaxX, TaxiMaxY
            struct.pack_into("<4f", raw, o + 9 * 4,
                             box["TaxiMinX"], box["TaxiMinY"], box["TaxiMaxX"], box["TaxiMaxY"])
            hit += 1
    assert hit == 1, "expected one WorldMapContinent row for map 751, got %d" % hit
    open(dbc, "wb").write(bytes(raw))

    cpath = os.path.join(ROOT, "CSV DBC", "WorldMapContinent.csv")
    with open(cpath, encoding="utf-8-sig", newline="") as fh:
        rr = _csv.reader(fh)
        hdr = next(rr)
        rows = [x for x in rr if x and x[0].strip() != ""]
    ci = {n: k for k, n in enumerate(hdr)}
    n = 0
    for x in rows:
        if x[ci["MapID"]] == "751":
            for key in ("TaxiMinX", "TaxiMinY", "TaxiMaxX", "TaxiMaxY"):
                x[ci[key]] = repr(round(box[key], 6))
            n += 1
    assert n == 1, n
    buf = _io.StringIO()
    w = _csv.writer(buf, lineterminator=chr(10), quoting=_csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    open(cpath, "w", encoding="utf-8-sig", newline="").write(buf.getvalue())

    print("\nWorldMapContinent id 10 updated in DBC + CSV (art and box ship together):")
    for k in ("TaxiMinX", "TaxiMaxX", "TaxiMinY", "TaxiMaxY"):
        print("   %-9s %.0f" % (k, box[k]))


main()
