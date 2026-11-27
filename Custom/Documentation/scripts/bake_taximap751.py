#!/usr/bin/env python3
"""Build Interface\\TaxiFrame\\TaxiMap751.blp for the 8-zone Lordaeron map.

WHY THE FIRST TWO ATTEMPTS FAILED
1. `Interface\\WorldMap\\Plaguelands\\` is the ORIGINAL two-zone continent map --
   its art covers only Western + Eastern Plaguelands, matching WorldMapArea 1267's
   stale box (world X 533..3733, Y -5866..-533). Proven by back-projecting node
   coordinates onto it: Hearthglen, Light's Hope, Plaguewood and Eastwall all land
   on their printed labels within a few pixels. The extension never got new
   continent art, so 13 of 31 taxi nodes fell outside it and their pins scattered.
2. Compositing the eight per-zone maps registers correctly but looks like a
   patchwork -- the zone boxes overlap and leave gaps, and each carries its own
   parchment border.

THE SOURCE THAT WORKS
Map 751 preserves Eastern Kingdoms coordinates, so Lordaeron can be cropped
straight out of the stock `Interface\\WorldMap\\Azeroth\\` continent map
(WorldMapArea 14: Y 18171.97..-22569.21, X 11176.34..-15973.34). Seamless, correct
geography, and the same stylised look as TaxiMap750.

The crop is only ~246x183 of 1024x768, so the source's own zone labels do not
survive the upscale -- TaxiMap750 has readable names, so they are redrawn here at
each zone's WorldMapArea centre.

GEOMETRY. The taxi frame maps a node through WorldMapContinent's Taxi box onto a
square image, so the box is squared about the union of the eight zone boxes. World
X is the image's VERTICAL extent (top = higher X), world Y the horizontal (left =
higher Y). The box this emits MUST be written to WorldMapContinent id 10 or the
pins will not line up -- that mismatch is exactly what broke the first attempt.
"""
import os, sys, json, struct, subprocess, shutil
from PIL import Image, ImageDraw, ImageFont

SP = os.environ.get("SCRATCH", "")
DATA = r"K:/WoW_3.3.5a_ 255 Fun/Data"
TOOLS = r"K:/Dark-Chaos/wow.export-main/tools"
SIZE = 512

# stock Azeroth continent map (WorldMapArea 14)
AZ = dict(L=18171.97, R=-22569.21, T=11176.34, B=-15973.34)
AZW, AZH = 1024, 768

# the eight map-751 zones: L/R = world Y max/min, T/B = world X max/min
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


def load_azeroth():
    out = os.path.join(SP, "az_map")
    if not os.path.exists(os.path.join(out, "Azeroth12.blp")):
        os.makedirs(out, exist_ok=True)
        lst = os.path.join(SP, "_az_list.txt")
        with open(lst, "w") as fh:
            fh.write("\n".join("Interface\\WorldMap\\Azeroth\\Azeroth%d.blp" % (i + 1) for i in range(12)) + "\n")
        subprocess.run(["python", os.path.join(TOOLS, "mpq_stormlib_extract.py"),
                        "--mpq", DATA + "/enGB/locale-enGB.MPQ", "--out", out,
                        "--list-file", lst, "--quiet"], capture_output=True)
    raw = os.path.join(SP, "taxi", "azeroth_grid.bin")
    if not os.path.exists(raw):
        subprocess.run(["node", "-e", f"""
const fs=require('fs'),path=require('path'),blp=require('{TOOLS}/blp-codec.js');
const W=1024,H=768,TS=256,g=Buffer.alloc(W*H*4);
for(let i=0;i<12;i++){{const {{rgba}}=blp.blpMip0ToRGBA(fs.readFileSync(path.join('{out}','Azeroth'+(i+1)+'.blp')));
const cx=(i%4)*TS,cy=Math.floor(i/4)*TS;
for(let y=0;y<TS;y++) rgba.copy(g,((cy+y)*W+cx)*4,y*TS*4,(y*TS+TS)*4);}}
fs.writeFileSync('{raw}',g);"""], capture_output=True)
    return Image.frombytes("RGBA", (AZW, AZH), open(raw, "rb").read())


def font(size):
    for p in (r"C:\Windows\Fonts\georgiab.ttf", r"C:\Windows\Fonts\timesbd.ttf",
              r"C:\Windows\Fonts\arialbd.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def main():
    # square taxi box from the union of the zone boxes
    Xs = [v for z in ZONES for v in (z[3], z[4])]
    Ys = [v for z in ZONES for v in (z[1], z[2])]
    uXT, uXB, uYL, uYR = max(Xs), min(Xs), max(Ys), min(Ys)
    span = max(uXT - uXB, uYL - uYR)
    cX, cY = (uXT + uXB) / 2.0, (uYL + uYR) / 2.0
    box = dict(xMin=cX - span / 2, xMax=cX + span / 2, yMin=cY - span / 2, yMax=cY + span / 2)
    print("union  X %.0f..%.0f  Y %.0f..%.0f" % (uXB, uXT, uYR, uYL))
    print("square box X %.0f..%.0f  Y %.0f..%.0f (span %.0f)" % (box["xMin"], box["xMax"], box["yMin"], box["yMax"], span))

    az = load_azeroth()
    # crop the box region out of the Azeroth map
    def ax(y): return (AZ["L"] - y) / (AZ["L"] - AZ["R"]) * AZW
    def ay(x): return (AZ["T"] - x) / (AZ["T"] - AZ["B"]) * AZH
    x0, x1 = ax(box["yMax"]), ax(box["yMin"])
    y0, y1 = ay(box["xMax"]), ay(box["xMin"])
    print("crop on Azeroth map: x %.0f..%.0f  y %.0f..%.0f (%.0fx%.0f px)" % (x0, x1, y0, y1, x1 - x0, y1 - y0))
    crop = az.crop((int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))))
    im = crop.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")

    # The taxi box is SQUARE but Lordaeron is not: the union spans 6469 in world X
    # against 9769 in Y, so the top and bottom of the image fall outside the
    # continent. Left as-is they show unrelated Eastern Kingdoms coastline and, at
    # the very bottom, the source map's own "EASTERN KINGDOMS" title bleeding in.
    # Fade those bands out so the frame reads as deliberate rather than mis-cropped.
    def py_(x): return (box["xMax"] - x) / span * SIZE
    top_edge, bot_edge = py_(uXT), py_(uXB)
    ramp = 26
    px_im = im.load()
    for yy in range(SIZE):
        if yy < top_edge:
            t = min(1.0, (top_edge - yy) / ramp)
        elif yy > bot_edge:
            t = min(1.0, (yy - bot_edge) / ramp)
        else:
            continue
        for xx in range(SIZE):
            r_, g_, b_ = px_im[xx, yy]
            px_im[xx, yy] = (int(r_ * (1 - t) + 16 * t),
                             int(g_ * (1 - t) + 12 * t),
                             int(b_ * (1 - t) + 8 * t))
    print("faded outside the continent: rows <%.0f and >%.0f" % (top_edge, bot_edge))

    # redraw the zone names -- the source labels do not survive a ~2x upscale
    d = ImageDraw.Draw(im)
    f = font(13)
    def px(y): return (box["yMax"] - y) / span * SIZE
    def py(x): return (box["xMax"] - x) / span * SIZE
    for name, L, R, T, B in ZONES:
        cx_, cy_ = px((L + R) / 2.0), py((T + B) / 2.0)
        txt = name.upper()
        try:
            bb = d.textbbox((0, 0), txt, font=f)
            w_, h_ = bb[2] - bb[0], bb[3] - bb[1]
        except AttributeError:
            w_, h_ = d.textsize(txt, font=f)
        ox, oy = cx_ - w_ / 2, cy_ - h_ / 2
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    d.text((ox + dx, oy + dy), txt, font=f, fill=(30, 20, 10))
        d.text((ox, oy), txt, font=f, fill=(250, 238, 205))
        print("   label %-22s at (%3.0f,%3.0f)" % (name, cx_, cy_))

    os.makedirs(os.path.join(SP, "taxi"), exist_ok=True)
    im.save(os.path.join(SP, "taxi", "TaxiMap751_preview.png"))
    rgba = im.convert("RGBA").tobytes()
    open(os.path.join(SP, "taxi", "final.bin"), "wb").write(rgba)
    # Paths are normalised to forward slashes BEFORE going into the JS source --
    # a Windows path embedded raw turns every backslash into a JS escape.
    src_bin = os.path.join(SP, "taxi", "final.bin").replace(os.sep, "/")
    dst_blp = os.path.join(SP, "taxi", "TaxiMap751.blp").replace(os.sep, "/")
    js = (
        "const fs=require('fs'),blp=require('%s/blp-codec.js');\n"
        "let cur=fs.readFileSync('%s'),w=%d,mips=[];\n"
        "while(w>=1){mips.push(blp.encodeDXT1(cur,w,w)); if(w===1)break;"
        " cur=blp.resizeRGBA(cur,w,w,w>>1,w>>1); w>>=1;}\n"
        "fs.writeFileSync('%s', blp.makeBlpMips(mips,%d));\n"
        "console.log('blp mips', mips.length);" % (TOOLS, src_bin, SIZE, dst_blp, SIZE)
    )
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True)
    if r.returncode:
        raise SystemExit("ABORT: blp encode failed\n" + r.stderr[-800:])
    print("  " + r.stdout.strip())
    json.dump(box, open(os.path.join(SP, "taxi", "taximap751_box.json"), "w"), indent=1)
    sz = os.path.getsize(os.path.join(SP, "taxi", "TaxiMap751.blp"))
    print("\nwrote TaxiMap751.blp (%d bytes)" % sz)
    print("WRITE THESE INTO WorldMapContinent id 10 -- pins depend on it:")
    print("   TaxiMinX %.0f  TaxiMaxX %.0f  TaxiMinY %.0f  TaxiMaxY %.0f"
          % (box["xMin"], box["xMax"], box["yMin"], box["yMax"]))


main()
