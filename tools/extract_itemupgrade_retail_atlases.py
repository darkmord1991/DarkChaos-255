from pathlib import Path
import struct

from PIL import Image
from PIL.BlpImagePlugin import BLPFormatError


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT.parent / "WoW 11.2.5 PTR interface extract" / "reforging"
OUTPUT_DIR = ROOT / "Custom" / "Client addons needed" / "DC-ItemUpgrade" / "Textures" / "Retail"

# Atlas coordinates come from the retail AtlasInfo table for the
# Interface/Reforging/ItemUpgrade* source sheets.
SLICE_TEXTURES = {
    SOURCE_DIR / "itemupgrade.blp": [
        (OUTPUT_DIR / "ItemUpgrade_BottomPanel-Shadow.tga", (0.622559, 0.882324, 0.0419922, 0.392578)),
        (OUTPUT_DIR / "ItemUpgrade_BottomPanel.tga", (0.361816, 0.621582, 0.0419922, 0.392578)),
        (OUTPUT_DIR / "ItemUpgrade_SlotBorder.tga", (0.059082, 0.0932617, 0.75293, 0.823242)),
        (OUTPUT_DIR / "ItemUpgrade_TopPanel.tga", (0.0942383, 0.354004, 0.75293, 0.90332)),
        (OUTPUT_DIR / "ItemUpgrade_FX_FrameDecor_MicaFlecksSheen.tga", (0.000488281, 0.36084, 0.0419922, 0.750977)),
        (OUTPUT_DIR / "ItemUpgrade_FX_Tooltip_Goldflake.tga", (0.777832, 0.974609, 0.394531, 0.799805)),
        (OUTPUT_DIR / "ItemUpgrade_FX_Tooltip_Overlay.tga", (0.361816, 0.544434, 0.394531, 0.732422)),
        (OUTPUT_DIR / "ItemUpgrade_TotalCostBar.tga", (0.0883789, 0.195801, 0.000976562, 0.0205078)),
        (OUTPUT_DIR / "ItemUpgrade_FX_SlotInnerGlow.tga", (0.000488281, 0.0283203, 0.75293, 0.807617)),
        (OUTPUT_DIR / "ItemUpgrade_GreenPlusIcon.tga", (0.0292969, 0.0581055, 0.75293, 0.80957)),
        (OUTPUT_DIR / "ItemUpgrade_GreenPlusIcon_Pressed.tga", (0.0292969, 0.0581055, 0.811523, 0.868164)),
        (OUTPUT_DIR / "ItemUpgrade_HelpTipArrow.tga", (0.000488281, 0.0141602, 0.80957, 0.873047)),
        (OUTPUT_DIR / "ItemUpgrade_FX_ButtonGlow.tga", (0.000488281, 0.0874023, 0.000976562, 0.0400391)),
        (OUTPUT_DIR / "ItemUpgrade_FX_Tooltip_ConfirmSheen.tga", (0.54541, 0.776855, 0.394531, 0.811523)),
    ],
    SOURCE_DIR / "itemupgradeframedecor.blp": [
        (OUTPUT_DIR / "ItemUpgrade_FX_FrameDecor_Ring.tga", (0.000976562, 0.706055, 0.000976562, 0.706055)),
    ],
    SOURCE_DIR / "itemupgradefxdecorlinesglow.blp": [
        (OUTPUT_DIR / "ItemUpgrade_FX_FrameDecor_IdleGlow.tga", (0.000976562, 0.628906, 0.0, 1.0)),
    ],
    SOURCE_DIR / "itemupgradefxmaskdecorlines.blp": [
        (OUTPUT_DIR / "ItemUpgrade_FX_FrameDecor_LineMask.tga", (0.0, 1.0, 0.0, 1.0)),
    ],
    SOURCE_DIR / "itemupgradefxmaskdecormica.blp": [
        (OUTPUT_DIR / "ItemUpgrade_FX_FrameDecor_MicaFlecksMask.tga", (0.0, 1.0, 0.0, 1.0)),
    ],
    SOURCE_DIR / "itemupgradefxtooltipglow.blp": [
        (OUTPUT_DIR / "ItemUpgradeTooltip-NineSlice-Corner.tga", (0.015625, 0.515625, 0.539062, 0.789062)),
        (OUTPUT_DIR / "ItemUpgradeTooltip-NineSlice-EdgeBottom.tga", (0.0, 0.5, 0.0078125, 0.257812)),
        (OUTPUT_DIR / "ItemUpgradeTooltip-NineSlice-EdgeTop.tga", (0.0, 0.5, 0.273438, 0.523438)),
    ],
    SOURCE_DIR / "itemupgradefxtooltipglowvertical.blp": [
        (OUTPUT_DIR / "ItemUpgradeTooltip-NineSlice-EdgeLeft.tga", (0.0078125, 0.257812, 0.0, 1.0)),
        (OUTPUT_DIR / "ItemUpgradeTooltip-NineSlice-EdgeRight.tga", (0.273438, 0.523438, 0.0, 1.0)),
    ],
    SOURCE_DIR / "itemupgradetooltipfullmask.blp": [
        (OUTPUT_DIR / "item_upgrade_tooltip_fullmask.tga", (0.0, 1.0, 0.0, 1.0)),
    ],
    SOURCE_DIR / "itemupgradetooltipmask.blp": [
        (OUTPUT_DIR / "tooltip_innerglow_mask_corner.tga", (0.0, 1.0, 0.0, 1.0)),
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
    missing = [path for path in SLICE_TEXTURES if not path.exists()]
    if missing:
        for path in missing:
            print(f"missing source: {path}")
        return 1

    loaded = {}
    for source in SLICE_TEXTURES:
        loaded[source] = open_blp(source)

    for source, targets in SLICE_TEXTURES.items():
        for target, coords in targets:
            save_image(crop_image(loaded[source], coords), target)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())