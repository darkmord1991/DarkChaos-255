#!/usr/bin/env python3
"""Rebake Interface\WorldMap\Plaguelands\Plaguelands{1..12}.blp -- the map-751
CONTINENT overview -- from the same minimap composite as the taxi map, and emit the
matching WorldMapArea 1267 rect.

WHY. The deployed tiles were a crop of stock EK continent art covering the OLD 2-zone
footprint, and WMA 1267 carried the matching 2-zone rect -- a consistent pair, but
wrong for the 8-zone continent: the overview showed only WPL+EPL (with EK's baked
"WESTERN PLAGUELANDS" label), and every engine projection (player dot, addon pins,
zone rect math) ran through the 2-zone rect.

THE ENGINE WINDOW (see continent-art-engine-convention). The client renders the 12
tiles 1:1 into the 1002x668 WorldMapDetailFrame -- the right 22px and bottom 100px of
the 1024x768 grid are CLIPPED -- and maps the WMA continent rect onto that window.
So the art here maps the rect onto the TOP-LEFT 1002x668, never the full grid.

THE RECT. Must contain all eight zone WMA rects (envelope Y 3450..-6319,
X 3838..-2631) and every terrain tile (Y 2667..-6400, X 3733..-2667), at the
window's exact 3:2 aspect so terrain is not stretched:

    L = 3500   R = -6400   T = 3866.667   B = -2733.333
    (Y span 9900, X span 6600, aspect 1.500 -- same exact ratio as stock
     Kalimdor's continent row: 36800 / 24533)

ART AND RECT ARE ONE CHANGE. This script patches WorldMapArea row 1267 (DBC + CSV)
itself so they cannot ship separately -- the same coupling lesson as the taxi box.

Deploy after running: the 12 tiles -> patch-5 (where the old ones live; root wins
art), WorldMapArea.dbc -> patch-4 + patch-enGB-3 + sync-dbc-deploy (WXL serves it
off disk) + the server's data/dbc.
"""
import os, sys, json, subprocess, struct, csv, io

SP = os.environ.get("SCRATCH", "")
TOOLS = r"K:/Dark-Chaos/wow.export-main/tools"
ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom"
TILE = 1600.0 / 3.0
sys.path.insert(0, TOOLS)

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
from mapbake_inpaint import fill_holes, smooth_seam

# the continent rect (WMA 1267): see header
L, R, T, B = 3500.0, -6400.0, 3866.0 + 2.0 / 3.0, -2733.0 - 1.0 / 3.0
SPAN_Y, SPAN_X = L - R, T - B      # 9900 x 6600

WIN_W, WIN_H = 1002, 668           # engine window inside the 1024x768 grid
SS = 2                             # supersample labels/composite, downscale once

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
    W, H = WIN_W * SS, WIN_H * SS

    def px(y):
        return (L - y) / SPAN_Y * W

    def py(x):
        return (T - x) / SPAN_X * H

    tiles = [tuple(t) for t in json.load(open(os.path.join(SP, "dcp_tiles.json")))]
    canvas = Image.new("RGB", (W, H), (150, 132, 100))
    # coverage mask: which canvas pixels a real minimap tile actually painted. The
    # grid is not a rectangle, so ~10 slots are empty and would otherwise stay flat
    # background -- the beige blocks punched out of the continent.
    cover = Image.new("L", (W, H), 0)
    cdraw = ImageDraw.Draw(cover)
    placed = 0
    for c, r in tiles:
        raw = os.path.join(SP, "mmtiles", "map%d_%d.bin" % (c, r))
        if not os.path.exists(raw):
            blp = os.path.join(SP, "mmtiles", "map%d_%d.blp" % (c, r))
            if not os.path.exists(blp):
                continue
            subprocess.run(["node", "-e",
                            "const fs=require('fs'),b=require('%s/blp-codec.js');"
                            "const {rgba}=b.blpMip0ToRGBA(fs.readFileSync('%s'));"
                            "fs.writeFileSync('%s',rgba);"
                            % (TOOLS, blp.replace(os.sep, '/'), raw.replace(os.sep, '/'))],
                           capture_output=True)
            if not os.path.exists(raw):
                continue
        t = Image.frombytes("RGBA", (256, 256), open(raw, "rb").read()).convert("RGB")
        x0, x1 = px((32 - c) * TILE), px((31 - c) * TILE)
        y0, y1 = py((32 - r) * TILE), py((31 - r) * TILE)
        w_, h_ = max(1, int(round(x1 - x0))), max(1, int(round(y1 - y0)))
        canvas.paste(t.resize((w_, h_), Image.LANCZOS), (int(round(x0)), int(round(y0))))
        cdraw.rectangle([int(round(x0)), int(round(y0)),
                         int(round(x0)) + w_ - 1, int(round(y0)) + h_ - 1], fill=255)
        placed += 1
    print("tiles placed: %d / %d" % (placed, len(tiles)))

    # Extend the surrounding terrain into the empty slots instead of leaving beige.
    known = np.asarray(cover) > 0
    holes = int((~known).sum())
    arr = fill_holes(np.asarray(canvas), known)
    arr = smooth_seam(arr, known, radius=2)
    canvas = Image.fromarray(arr)
    print("hole pixels filled: %d (%.1f%% of canvas)" % (holes, 100.0 * holes / (W * H)))

    # parchment grade -- identical numbers to the taxi bake, vectorised:
    # out = 0.42*rgb + 0.58*(lum * [1.32, 1.09, 0.68])
    lum = canvas.convert("L")
    lr = lum.point([min(255, int(i * 1.32)) for i in range(256)])
    lg = lum.point([min(255, int(i * 1.09)) for i in range(256)])
    lb = lum.point([int(i * 0.68) for i in range(256)])
    sepia = Image.merge("RGB", (lr, lg, lb))
    canvas = Image.blend(canvas, sepia, 0.58)
    canvas = ImageEnhance.Contrast(canvas).enhance(1.12)

    d = ImageDraw.Draw(canvas)
    f = font(24 * SS)
    for name, zl, zr, zt, zb in ZONES:
        cx, cy = px((zl + zr) / 2.0), py((zt + zb) / 2.0)
        txt = name.upper()
        bb = d.textbbox((0, 0), txt, font=f)
        w_, h_ = bb[2] - bb[0], bb[3] - bb[1]
        ox = min(max(4, cx - w_ / 2), W - w_ - 4)
        oy = min(max(4, cy - h_ / 2), H - h_ - 4)
        o = 2 * SS
        for dx in range(-o, o + 1, SS):
            for dy in range(-o, o + 1, SS):
                if dx or dy:
                    d.text((ox + dx, oy + dy), txt, font=f, fill=(24, 16, 8))
        d.text((ox, oy), txt, font=f, fill=(252, 240, 208))

    win = canvas.resize((WIN_W, WIN_H), Image.LANCZOS)

    # the clipped margins take the graded background colour so nothing bleeds if a
    # client addon ever shows the raw grid
    bg = win.getpixel((WIN_W - 1, WIN_H - 1))
    grid = Image.new("RGB", (1024, 768), bg)
    grid.paste(win, (0, 0))

    out_dir = os.path.join(SP, "cont751")
    os.makedirs(out_dir, exist_ok=True)
    grid.save(os.path.join(out_dir, "continent_preview.png"))

    # split into the 12 tiles (4 x 3, row-major, 1-based -- Blizzard numbering)
    manifest = []
    for i in range(12):
        tx, ty = (i % 4) * 256, (i // 4) * 256
        tile_img = grid.crop((tx, ty, tx + 256, ty + 256))
        binp = os.path.join(out_dir, "t%d.bin" % (i + 1))
        open(binp, "wb").write(tile_img.convert("RGBA").tobytes())
        blpp = os.path.join(out_dir, "Plaguelands%d.blp" % (i + 1))
        js = ("const fs=require('fs'),blp=require('%s/blp-codec.js');\n"
              "let cur=fs.readFileSync('%s'),w=256,h=256,mips=[];\n"
              "while(w>=1||h>=1){mips.push(blp.encodeDXT1(cur,Math.max(1,w),Math.max(1,h)));"
              " if(w<=1&&h<=1)break;"
              " cur=blp.resizeRGBA(cur,Math.max(1,w),Math.max(1,h),Math.max(1,w>>1),Math.max(1,h>>1));"
              " w>>=1;h>>=1;}\n"
              "fs.writeFileSync('%s', blp.makeBlpMips(mips,256));\n"
              % (TOOLS, binp.replace(os.sep, '/'), blpp.replace(os.sep, '/')))
        r_ = subprocess.run(["node", "-e", js], capture_output=True, text=True)
        if r_.returncode or not os.path.exists(blpp):
            raise SystemExit("ABORT: blp encode failed for tile %d\n%s" % (i + 1, r_.stderr[-500:]))
        manifest.append("%s=Interface%sWorldMap%sPlaguelands%sPlaguelands%d.blp"
                        % (blpp.replace(os.sep, '/'), chr(92), chr(92), chr(92), i + 1))
    open(os.path.join(out_dir, "deploy_manifest.txt"), "w", encoding="utf-8",
         newline=chr(10)).write(chr(10).join(manifest) + chr(10))
    print("12 tiles encoded -> %s" % out_dir)

    # ---- WMA 1267: patch the rect in DBC + CSV so art and rect ship together ----
    p = os.path.join(ROOT, "DBCs", "WorldMapArea.dbc")
    d_ = bytearray(open(p, "rb").read())
    rc, fc, rs, ss = struct.unpack("<4I", d_[4:20])
    hit = False
    for i in range(rc):
        o = 20 + i * rs
        if struct.unpack_from("<I", d_, o)[0] == 1267:
            struct.pack_into("<4f", d_, o + 4 * 4, L, R, T, B)
            hit = True
    assert hit, "WMA 1267 not found"
    open(p, "wb").write(bytes(d_))
    print("WorldMapArea.dbc: 1267 rect -> L=%.0f R=%.0f T=%.3f B=%.3f" % (L, R, T, B))

    cp = os.path.join(ROOT, "CSV DBC", "WorldMapArea.csv")
    with open(cp, encoding="utf-8", newline="") as fh:
        rr = csv.reader(fh)
        hdr = next(rr)
        rows = [x for x in rr if x and x[0].strip() != ""]
    n = 0
    for x in rows:
        if x[0] == "1267":
            x[4], x[5], x[6], x[7] = repr(L), repr(R), repr(round(T, 6)), repr(round(B, 6))
            n += 1
    assert n == 1, n
    buf = io.StringIO()
    w = csv.writer(buf, lineterminator=chr(10), quoting=csv.QUOTE_ALL)
    w.writerow(hdr)
    for x in rows:
        w.writerow(x)
    open(cp, "w", encoding="utf-8", newline="").write(buf.getvalue())
    print("WorldMapArea.csv: 1267 updated")


main()
