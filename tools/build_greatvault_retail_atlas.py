"""Repack the retail Great Vault art into 3.3.5-safe atlases for DC-MythicPlus.

Source is the retail `Interface/WeeklyReward/EvergreenWeeklyRewardUI.blp`
(2048x2048, BLP2 raw BGRA). The 3.3.5 client only loads power-of-two UI
textures up to 1024px, so the members GreatVaultFrame.lua uses are cropped at
their retail AtlasInfo rects and placed onto two 1024x1024 sheets. The two
panel-sized members (frame back and frame border) are larger than a sheet and
are scaled down; the addon stretches them back over the panel.

Output matches the known-good RetailAtlas/ChallengeMode.blp header: BLP2,
DXT5 (encoding 2, alpha type 7), a single mip level.

    python tools/build_greatvault_retail_atlas.py [source.blp] [preview_dir]

A preview_dir, when given, receives a PNG of each sheet for eyeballing crops.

Prints the pixel rect table that GreatVaultFrame.lua's VAULT_ATLAS mirrors.
"""
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Custom" / "Client addons needed" / "DC-MythicPlus" / "Textures" / "RetailAtlas"
DEFAULT_SOURCE = Path(r"K:\Dark-Chaos\WoW 11.2.5 PTR interface extract\weeklyreward\evergreenweeklyrewardui.blp")

SOURCE_SIZE = 2048
SHEET = 1024

# Retail AtlasInfo.lua (Interface/WeeklyReward/EvergreenWeeklyRewardUI):
# name -> (width, height, left, right, top, bottom)
RETAIL = {
    "frame-back": (1134, 712, 0.000488281, 0.554199, 0.000488281, 0.348145),
    "frame": (1175, 662, 0.000488281, 0.574219, 0.349121, 0.672363),
    "frame-topdecor": (229, 103, 0.305176, 0.416992, 0.706543, 0.756836),
    "frame-selectbutton": (209, 31, 0.000488281, 0.102539, 0.963867, 0.979004),
    "header": (735, 15, 0.417969, 0.776855, 0.706543, 0.713867),
    "divider": (1057, 7, 0.417969, 0.934082, 0.714844, 0.718262),
    "category-raids": (405, 172, 0.000488281, 0.198242, 0.67334, 0.757324),
    "category-dungeons": (422, 177, 0.555176, 0.76123, 0.251953, 0.338379),
    "category-pvp": (421, 152, 0.575195, 0.780762, 0.59375, 0.667969),
    "reward-locked": (218, 125, 0.000488281, 0.106934, 0.839844, 0.900879),
    "reward-unlocked": (218, 125, 0.000488281, 0.106934, 0.901855, 0.962891),
    "reward-selected": (214, 121, 0.199219, 0.303711, 0.76709, 0.826172),
    "reward-unselected": (215, 122, 0.199219, 0.304199, 0.706543, 0.766113),
    "reward-itemframe": (156, 51, 0.819336, 0.895508, 0.646973, 0.671875),
    "reward-fx-backglow": (168, 115, 0.905762, 0.987793, 0.567383, 0.623535),
    "reward-selected-sideglow": (260, 163, 0.819336, 0.946289, 0.349121, 0.428711),
    "reward-selected-outerglow": (234, 141, 0.819336, 0.933594, 0.429688, 0.498535),
}

# sheet -> [(member, x, y, target width, target height)]
LAYOUT = {
    "GreatVaultFrame": [
        ("frame-back", 0, 0, 1024, 643),
        ("category-raids", 0, 646, 405, 172),
        ("category-dungeons", 408, 646, 422, 177),
        ("category-pvp", 0, 826, 421, 152),
        ("frame-topdecor", 424, 826, 229, 103),
        ("frame-selectbutton", 656, 826, 209, 31),
    ],
    "GreatVaultCards": [
        ("frame", 0, 0, 1024, 577),
        ("reward-locked", 0, 580, 218, 125),
        ("reward-unlocked", 221, 580, 218, 125),
        ("reward-selected", 442, 580, 214, 121),
        ("reward-unselected", 659, 580, 215, 122),
        ("reward-selected-sideglow", 0, 708, 260, 163),
        ("reward-selected-outerglow", 263, 708, 234, 141),
        ("reward-fx-backglow", 500, 708, 168, 115),
        ("reward-itemframe", 671, 708, 156, 51),
        ("header", 0, 874, 735, 15),
        ("divider", 0, 892, 1020, 7),
    ],
}


def load_retail_blp(path):
    data = path.read_bytes()
    if data[:4] != b"BLP2":
        raise SystemExit(f"not a BLP2 file: {path}")
    encoding = data[8]
    width, height = struct.unpack_from("<II", data, 12)
    offset = struct.unpack_from("<I", data, 20)[0]
    if encoding != 3 or (width, height) != (SOURCE_SIZE, SOURCE_SIZE):
        raise SystemExit(f"expected a {SOURCE_SIZE}px raw BGRA BLP, got encoding {encoding} {width}x{height}")
    return Image.frombytes("RGBA", (width, height), data[offset:offset + width * height * 4], "raw", "BGRA")


def crop_member(atlas, name):
    width, height, left, right, top, bottom = RETAIL[name]
    x = int(round(left * SOURCE_SIZE))
    y = int(round(top * SOURCE_SIZE))
    return atlas.crop((x, y, x + width, y + height))


def resize(image, size):
    if image.size == size:
        return image
    # Premultiply so transparent texels do not bleed dark fringes into edges.
    return image.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def to565(rgb):
    rgb = np.clip(np.rint(rgb), 0, 255).astype(np.uint32)
    return (rgb[..., 0] >> 3 << 11) | (rgb[..., 1] >> 2 << 5) | (rgb[..., 2] >> 3)


def from565(value):
    r = ((value >> 11) & 31) * 255.0 / 31
    g = ((value >> 5) & 63) * 255.0 / 63
    b = (value & 31) * 255.0 / 31
    return np.stack([r, g, b], axis=-1)


def encode_dxt5(image):
    pixels = np.asarray(image, dtype=np.float64)
    height, width = pixels.shape[:2]
    blocks = pixels.reshape(height // 4, 4, width // 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(-1, 16, 4)

    alpha = blocks[:, :, 3]
    a0 = alpha.max(axis=1)
    a1 = alpha.min(axis=1)
    steps = np.arange(1, 7, dtype=np.float64)
    levels = np.concatenate([
        a0[:, None], a1[:, None],
        ((7 - steps)[None, :] * a0[:, None] + steps[None, :] * a1[:, None]) / 7.0,
    ], axis=1)
    alpha_idx = np.abs(alpha[:, :, None] - levels[:, None, :]).argmin(axis=2).astype(np.uint64)
    alpha_idx[a0 == a1] = 0
    alpha_bits = np.zeros(len(blocks), dtype=np.uint64)
    for i in range(16):
        alpha_bits |= alpha_idx[:, i] << np.uint64(3 * i)

    rgb = blocks[:, :, :3].copy()
    opaque = alpha > 0
    counts = opaque.sum(axis=1, keepdims=True)
    mean = (rgb * opaque[:, :, None]).sum(axis=1) / np.maximum(counts, 1)
    rgb = np.where(opaque[:, :, None], rgb, mean[:, None, :])

    cmax = rgb.max(axis=1)
    cmin = rgb.min(axis=1)
    inset = (cmax - cmin) / 16.0
    c0 = to565(cmax - inset)
    c1 = to565(cmin + inset)
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)
    p0 = from565(c0)
    p1 = from565(c1)
    palette = np.stack([p0, p1, (2 * p0 + p1) / 3.0, (p0 + 2 * p1) / 3.0], axis=1)
    dist = ((rgb[:, :, None, :] - palette[:, None, :, :]) ** 2).sum(axis=3)
    color_idx = dist.argmin(axis=2).astype(np.uint32)
    color_idx[c0 == c1] = 0
    color_bits = np.zeros(len(blocks), dtype=np.uint32)
    for i in range(16):
        color_bits |= color_idx[:, i] << np.uint32(2 * i)

    out = np.zeros((len(blocks), 16), dtype=np.uint8)
    out[:, 0] = a0.astype(np.uint8)
    out[:, 1] = a1.astype(np.uint8)
    for i in range(6):
        out[:, 2 + i] = ((alpha_bits >> np.uint64(8 * i)) & np.uint64(0xFF)).astype(np.uint8)
    out[:, 8] = c0 & 0xFF
    out[:, 9] = c0 >> 8
    out[:, 10] = c1 & 0xFF
    out[:, 11] = c1 >> 8
    for i in range(4):
        out[:, 12 + i] = (color_bits >> np.uint32(8 * i)) & 0xFF
    return out.tobytes()


def write_blp(image, path):
    payload = encode_dxt5(image)
    header_size = 4 + 4 + 4 + 8 + 64 + 64 + 1024
    offsets = [header_size] + [0] * 15
    sizes = [len(payload)] + [0] * 15
    header = b"BLP2" + struct.pack("<I", 1) + struct.pack("<BBBB", 2, 8, 7, 0)
    header += struct.pack("<II", image.size[0], image.size[1])
    header += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + bytes(1024)
    path.write_bytes(header + payload)


def main():
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    preview_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    atlas = load_retail_blp(source)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("local VAULT_ATLAS = {")
    for sheet_name, members in LAYOUT.items():
        sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
        for name, x, y, width, height in members:
            if x + width > SHEET or y + height > SHEET:
                raise SystemExit(f"{sheet_name}: {name} overflows the sheet")
            sheet.alpha_composite(resize(crop_member(atlas, name), (width, height)), (x, y))
            print(f'    ["{name}"] = {{ "{sheet_name}", {x}, {y}, {width}, {height} }},')
        write_blp(sheet, OUT_DIR / f"{sheet_name}.blp")
        if preview_dir:
            preview_dir.mkdir(parents=True, exist_ok=True)
            backdrop = Image.new("RGBA", sheet.size, (255, 0, 255, 255))
            backdrop.alpha_composite(sheet)
            backdrop.convert("RGB").save(preview_dir / f"{sheet_name}.png")
    print("}")


if __name__ == "__main__":
    main()
