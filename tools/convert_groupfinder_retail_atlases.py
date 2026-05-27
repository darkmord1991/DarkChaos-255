from pathlib import Path
import struct

from PIL import Image
from PIL.BlpImagePlugin import BLPFormatError


ROOT = Path(__file__).resolve().parents[1]
ADDON_RETAIL_DIR = ROOT / "Custom" / "Client addons needed" / "DC-MythicPlus" / "Textures" / "Retail"

BLUE_MENU_MAIN = ROOT / "Custom" / "Interface" / "Common" / "bluemenu-main.blp"
BLUE_MENU_RING = ROOT / "Custom" / "Interface" / "Common" / "bluemenuring.blp"
GROUPFINDER_ATLAS = ROOT / "Custom" / "Interface" / "LFGFrame" / "groupfinder.blp"
LFG_PROMPTS_ATLAS = ROOT / "Custom" / "Interface" / "LFGFrame" / "UILFGPrompts.blp"

WHOLE_TEXTURES = {
    BLUE_MENU_RING: [ADDON_RETAIL_DIR / "bluemenuring_335.tga"],
}

SLICE_TEXTURES = {
    BLUE_MENU_MAIN: [
        (ADDON_RETAIL_DIR / "BlueMenu-Normal.tga", (0.00390625, 0.87890625, 0.75195313, 0.83007813)),
        (ADDON_RETAIL_DIR / "BlueMenu-Selected.tga", (0.00390625, 0.87890625, 0.59179688, 0.66992188)),
        (ADDON_RETAIL_DIR / "BlueMenu-Disabled.tga", (0.00390625, 0.87890625, 0.67187500, 0.75000000)),
    ],
    GROUPFINDER_ATLAS: [
        (ADDON_RETAIL_DIR / "GroupFinder-Background.tga", (0.000488281, 0.160645, 0.000976562, 0.329102)),
        (ADDON_RETAIL_DIR / "GroupFinder-Background-Dungeons.tga", (0.325195, 0.487793, 0.0966797, 0.19043)),
        (ADDON_RETAIL_DIR / "GroupFinder-Button-Cover.tga", (0.000488281, 0.146973, 0.331055, 0.375977)),
        (ADDON_RETAIL_DIR / "GroupFinder-Button-Highlight.tga", (0.000488281, 0.143066, 0.424805, 0.460938)),
        (ADDON_RETAIL_DIR / "GroupFinder-Button-Select.tga", (0.000488281, 0.143066, 0.462891, 0.499023)),
        (ADDON_RETAIL_DIR / "GroupFinder-Nav-Dungeons.tga", (0.000488281, 0.14209, 0.723633, 0.758789)),
        (ADDON_RETAIL_DIR / "GroupFinder-Nav-Raids.tga", (0.161621, 0.303223, 0.383789, 0.418945)),
        (ADDON_RETAIL_DIR / "GroupFinder-Nav-Premade.tga", (0.000488281, 0.14209, 0.612305, 0.647461)),
        (ADDON_RETAIL_DIR / "GroupFinder-Eye-Backglow.tga", (0.930176, 0.970215, 0.000976562, 0.0810547)),
        (ADDON_RETAIL_DIR / "GroupFinder-Eye-Frame.tga", (0.971191, 0.996582, 0.000976562, 0.0517578)),
        (ADDON_RETAIL_DIR / "GroupFinder-Eye-Single.tga", (0.692871, 0.714355, 0.260742, 0.303711)),
    ],
    LFG_PROMPTS_ATLAS: [
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Generic.tga", (0.000488281, 0.125488, 0.503418, 0.628418)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Generic-Disabled.tga", (0.000488281, 0.125488, 0.629395, 0.754395)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Tank.tga", (0.630371, 0.755371, 0.251465, 0.376465)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Tank-Disabled.tga", (0.756348, 0.881348, 0.251465, 0.376465)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Healer.tga", (0.000488281, 0.125488, 0.755371, 0.880371)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Healer-Disabled.tga", (0.126465, 0.251465, 0.251465, 0.376465)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-DPS.tga", (0.000488281, 0.125488, 0.251465, 0.376465)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-DPS-Disabled.tga", (0.000488281, 0.125488, 0.377441, 0.502441)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Leader.tga", (0.126465, 0.251465, 0.503418, 0.628418)),
        (ADDON_RETAIL_DIR / "GroupFinder-Role-Leader-Disabled.tga", (0.126465, 0.251465, 0.629395, 0.754395)),
    ],
}


def save_image(image: Image.Image, target: Path) -> None:
    if image.mode != "RGBA":
        image = image.convert("RGBA")

    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, format="TGA")
    print(f"{target.relative_to(ROOT)} {image.size}")


def crop_image(image: Image.Image, coords: tuple[float, float, float, float]) -> Image.Image:
    width, height = image.size
    left = int(round(coords[0] * width))
    right = int(round(coords[1] * width))
    top = int(round(coords[2] * height))
    bottom = int(round(coords[3] * height))
    return image.crop((left, top, right, bottom))


def open_blp(source: Path) -> Image.Image:
    try:
        image = Image.open(source)
        image.load()
        return image
    except BLPFormatError as exc:
        if "Unknown BLP encoding 3" not in str(exc):
            raise

    data = source.read_bytes()
    if data[:4] != b"BLP2":
        raise ValueError(f"unsupported BLP magic in {source}")

    color_encoding, alpha_depth, alpha_type, _mips = struct.unpack_from("<4B", data, 8)
    width, height = struct.unpack_from("<II", data, 12)
    mip_offset = struct.unpack_from("<I", data, 20)[0]
    mip_size = struct.unpack_from("<I", data, 84)[0]

    if color_encoding != 3:
        raise ValueError(f"unsupported raw fallback encoding {color_encoding} in {source}")

    expected_size = width * height * 4
    if mip_size < expected_size:
        raise ValueError(f"short mip level in {source}: {mip_size} < {expected_size}")

    pixel_data = data[mip_offset:mip_offset + expected_size]
    if len(pixel_data) != expected_size:
        raise ValueError(f"truncated pixel data in {source}")

    image = Image.frombytes("RGBA", (width, height), pixel_data, "raw", "BGRA")
    image.info["blp_alpha_depth"] = alpha_depth
    image.info["blp_alpha_type"] = alpha_type
    return image


def main() -> int:
    sources = set(WHOLE_TEXTURES) | set(SLICE_TEXTURES)
    missing = [path for path in sources if not path.exists()]
    if missing:
        for path in missing:
            print(f"missing source: {path.relative_to(ROOT)}")
        return 1

    loaded = {}
    for source in sources:
        loaded[source] = open_blp(source)

    for source, targets in WHOLE_TEXTURES.items():
        for target in targets:
            save_image(loaded[source], target)

    for source, targets in SLICE_TEXTURES.items():
        for target, coords in targets:
            save_image(crop_image(loaded[source], coords), target)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())