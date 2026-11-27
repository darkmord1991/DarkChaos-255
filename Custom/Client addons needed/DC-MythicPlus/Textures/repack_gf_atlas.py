"""Repack the used retail Group Finder atlas members into one <=1024 sheet.

The 3.3.5 client crashes decoding UI textures larger than 1024px, so the
2048px atlas rips (groupfinder_335 / UILFGPrompts_335) cannot ship as-is.
Crops the members the addon uses and shelf-packs them into a single
1024x1024 TGA, then prints the Lua rect table.
"""
import os
import struct
from PIL import Image

ROOT = r"k:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\DC-MythicPlus\Textures\Retail"
OUT_NAME = "dc_groupfinder_atlas_335.tga"

GF = "groupfinder_335.tga"        # 2048x1024
PROMPTS = "UILFGPrompts_335.tga"  # 2048x2048

# key -> (source file, left, right, top, bottom) pixel rect
MEMBERS = {
    "background":           (GF, 1, 329, 1, 337),
    "button-cover":         (GF, 1, 301, 339, 385),
    "button-cover-down":    (GF, 1, 301, 387, 433),
    "button-highlight":     (GF, 1, 293, 435, 472),
    "button-select":        (GF, 1, 293, 474, 511),
    "highlightbar-blue":    (GF, 1499, 1803, 393, 425),
    "eye-highlight":        (GF, 331, 417, 465, 551),
    "button-dungeons":      (GF, 1, 291, 741, 777),
    "button-questing":      (GF, 1, 291, 817, 853),
    "button-battlegrounds": (GF, 1, 291, 589, 625),
    "button-scenarios":     (GF, 623, 913, 393, 429),
    "button-custom-pve":    (GF, 1, 291, 627, 663),
    "button-custom-pvp":    (GF, 1, 291, 665, 701),
    "button-raids":         (GF, 1, 291, 931, 967),
    "button-arenas":        (GF, 1, 291, 513, 549),
    "role-tank":            (PROMPTS, 1291, 1547, 515, 771),
    "role-healer":          (PROMPTS, 1, 257, 1547, 1803),
    "role-dps":             (PROMPTS, 1, 257, 515, 771),
    "readymark":            (PROMPTS, 1745, 1945, 259, 459),
    "pendingmark":          (PROMPTS, 1543, 1743, 259, 459),
    "divider":              (PROMPTS, 517, 885, 773, 777),
    "tank-micro":           (PROMPTS, 190, 251, 1805, 1866),
    "healer-micro":         (PROMPTS, 1, 62, 1931, 1992),
    "dps-micro":            (PROMPTS, 1, 62, 1805, 1866),
}

SHEET = 1024
PAD = 2

sources = {
    GF: Image.open(os.path.join(ROOT, GF)).convert("RGBA"),
    PROMPTS: Image.open(os.path.join(ROOT, PROMPTS)).convert("RGBA"),
}

crops = {}
for key, (src, l, r, t, b) in MEMBERS.items():
    crops[key] = sources[src].crop((l, t, r, b))

# Shelf pack, tallest first for stable rows.
order = sorted(crops.keys(), key=lambda k: (-crops[k].height, -crops[k].width, k))
sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
placed = {}
x, y, row_h = PAD, PAD, 0
for key in order:
    im = crops[key]
    w, h = im.size
    if x + w + PAD > SHEET:
        x = PAD
        y += row_h + PAD
        row_h = 0
    if y + h + PAD > SHEET:
        raise SystemExit(f"overflow at {key}")
    sheet.paste(im, (x, y))
    placed[key] = (x, x + w, y, y + h)
    x += w + PAD
    row_h = max(row_h, h)

used_h = y + row_h + PAD
print(f"-- packed {len(placed)} members, used height {used_h}/{SHEET}")

out_path = os.path.join(ROOT, OUT_NAME)
sheet.save(out_path)

# Force the same TGA header flavour as the known-good role buttons:
# type 2 (uncompressed truecolor), 32bpp, descriptor 0x08 (bottom-left origin,
# 8 alpha bits). PIL may write top-left; rewrite deterministically.
raw = sheet.transpose(Image.FLIP_TOP_BOTTOM).tobytes("raw", "BGRA")
header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SHEET, SHEET, 32, 0x08)
footer = b"\x00" * 8 + b"TRUEVISION-XFILE.\x00"
with open(out_path, "wb") as fh:
    fh.write(header + raw + footer)
print(f"-- wrote {out_path} ({os.path.getsize(out_path)} bytes)")

print("local GF_ATLAS_RECTS = {")
for key in sorted(placed):
    l, r, t, b = placed[key]
    print(f'    ["{key}"] = {{ {l}, {r}, {t}, {b} }},')
print("}")
