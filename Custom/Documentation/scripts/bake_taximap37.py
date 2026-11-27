#!/usr/bin/env python3
"""Build Interface\\TaxiFrame\\TaxiMap37.blp for Azshara Crater (map 37).

Same recipe as bake_taximap750/751: the taxi frame projects a node through
WorldMapContinent's Taxi box onto a SQUARE image, so the box has to be square and
the art has to be cropped to exactly that box.

WHERE THE SOURCE ART COMES FROM
Unlike 750/751, map 37 already HAS its own zone map -- `Interface\\WorldMap\\
AzsharaCrater\\AzsharaCrater1..12.blp`, 12 tiles of 256x256 laid out 4x3, shipped
in patch-5.MPQ. WorldMapArea 613 registers it against the world as

    LocLeft 2427  LocRight -1884   (world Y, left = higher Y)
    LocTop  1756  LocBottom -1116  (world X, top  = higher X)

whose 4311x2872 aspect (1.5010) matches the art's own 1002x668 (1.5000) to within
a pixel, i.e. the box is genuinely calibrated to this image rather than guessed.
Reusing it means a taxi pin and a world-map pin for the same node land on the same
piece of parchment -- which is the property that actually matters here, whether or
not the drawing is a faithful render of the crater's terrain (it is the Azshara
zone map with a re-lettered banner).

THE BOX
A square 2400x2400 centred on the five nodes:

    X -700..1700   Y -750..1650

It is deliberately NOT the whole zone squared. The zone box is 4311 wide against
2872 tall, so squaring it would letterbox a third of the frame into blank
parchment; the crater's five camps sit inside a 1102x955 patch of it. 2400 keeps
>600 yd of margin around the outermost node, still fits inside the art on all four
sides (no fade band needed, unlike 751), and crops 558x558 source pixels for a
512x512 output -- a slight DOWNscale, so nothing is blurred and the source's own
labels survive.

WRITE THE BOX INTO WorldMapContinent id 11 OR THE PINS WILL NOT LINE UP.
"""
import os
import subprocess

from PIL import Image

SP = os.environ.get(
    "SCRATCH",
    r"C:/Users/flori/AppData/Local/Temp/claude/k--Dark-Chaos-DarkChaos-255-Master/scratchpad",
)
DATA = r"K:/WoW_3.3.5a_ 255 Fun/Data"
TOOLS = r"K:/Dark-Chaos/wow.export-main/tools"
REPO = r"K:/Dark-Chaos/DarkChaos-255-Master"
STAGE = os.path.join(REPO, "Custom", "Client patches needed", "Interface", "TaxiFrame")
SIZE = 512

# WorldMapArea 613 -- the registration of the AzsharaCrater art against the world
WMA = dict(L=2427.0, R=-1884.0, T=1756.0, B=-1116.0)
ARTW, ARTH = 1002.0, 668.0          # drawn area inside the 1024x768 tile grid
GRIDW, GRIDH = 1024, 768

# square taxi box, centred on the five map-37 taxi nodes
BOX = dict(xMin=-700.0, xMax=1700.0, yMin=-750.0, yMax=1650.0)

NODES = [
    (441, 74.28629, 931.967, "Startcamp"),
    (442, -28.66916, 525.9561, "Level 30+"),
    (443, 620.978, 126.018, "Level 50+"),
    (444, 1070.14, -23.4705, "Level 65+"),
    (445, -31.81839, 31.17768, "Level 70+"),
]


def load_zone_map():
    """Stitch the 12 AzsharaCrater tiles into one 1024x768 RGBA image."""
    out = os.path.join(SP, "acmap")
    first = os.path.join(out, "AzsharaCrater1.blp")
    if not os.path.exists(first):
        os.makedirs(out, exist_ok=True)
        lst = os.path.join(SP, "_ac_list.txt")
        with open(lst, "w") as fh:
            fh.write("\n".join("Interface\\WorldMap\\AzsharaCrater\\AzsharaCrater%d.blp" % (i + 1)
                               for i in range(12)) + "\n")
        r = subprocess.run(["python", os.path.join(TOOLS, "mpq_stormlib_extract.py"),
                            "--mpq", DATA + "/patch-5.MPQ", "--out", out,
                            "--list-file", lst], capture_output=True, text=True)
        if not os.path.exists(first):
            raise SystemExit("ABORT: tile extraction failed\n" + r.stdout[-800:] + r.stderr[-800:])
    im = Image.new("RGBA", (GRIDW, GRIDH))
    for i in range(12):
        t = Image.open(os.path.join(out, "AzsharaCrater%d.blp" % (i + 1))).convert("RGBA")
        im.paste(t, ((i % 4) * 256, (i // 4) * 256))
    return im


def main():
    span = BOX["xMax"] - BOX["xMin"]
    assert abs((BOX["yMax"] - BOX["yMin"]) - span) < 0.01, "taxi box must be square"

    art = load_zone_map()

    # world -> pixel on the zone map (WorldMapArea projection)
    def ax(y):
        return (WMA["L"] - y) / (WMA["L"] - WMA["R"]) * ARTW

    def ay(x):
        return (WMA["T"] - x) / (WMA["T"] - WMA["B"]) * ARTH

    x0, x1 = ax(BOX["yMax"]), ax(BOX["yMin"])
    y0, y1 = ay(BOX["xMax"]), ay(BOX["xMin"])
    print("box   X %.0f..%.0f  Y %.0f..%.0f (span %.0f)"
          % (BOX["xMin"], BOX["xMax"], BOX["yMin"], BOX["yMax"], span))
    print("crop  x %.1f..%.1f  y %.1f..%.1f  (%.1fx%.1f px of %dx%d)"
          % (x0, x1, y0, y1, x1 - x0, y1 - y0, ARTW, ARTH))
    for edge, v in (("left", x0), ("right", x1), ("top", y0), ("bottom", y1)):
        if v < 0 or (edge in ("left", "right") and v > ARTW) or (edge in ("top", "bottom") and v > ARTH):
            raise SystemExit("ABORT: crop runs off the %s edge of the art (%.1f)" % (edge, v))

    crop = art.crop((int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))))
    im = crop.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")

    # report where each node lands, as a registration check
    def px(y):
        return (BOX["yMax"] - y) / span * SIZE

    def py(x):
        return (BOX["xMax"] - x) / span * SIZE

    for nid, nx, ny, label in NODES:
        print("   node %d %-10s -> (%3.0f,%3.0f) px" % (nid, label, px(ny), py(nx)))

    os.makedirs(SP, exist_ok=True)
    os.makedirs(STAGE, exist_ok=True)
    preview = os.path.join(STAGE, "TaxiMap37_preview.png")
    im.save(preview)

    raw = os.path.join(SP, "taximap37.bin")
    open(raw, "wb").write(im.convert("RGBA").tobytes())

    # Paths are normalised to forward slashes BEFORE going into the JS source --
    # a Windows path embedded raw turns every backslash into a JS escape.
    src_bin = raw.replace(os.sep, "/")
    dst_blp = os.path.join(STAGE, "TaxiMap37.blp").replace(os.sep, "/")
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
    print("\nwrote %s (%d bytes)" % (dst_blp, os.path.getsize(dst_blp)))
    print("WRITE THESE INTO WorldMapContinent id 11 -- pins depend on it:")
    print("   TaxiMinX %.0f  TaxiMaxX %.0f  TaxiMinY %.0f  TaxiMaxY %.0f"
          % (BOX["xMin"], BOX["xMax"], BOX["yMin"], BOX["yMax"]))


main()
