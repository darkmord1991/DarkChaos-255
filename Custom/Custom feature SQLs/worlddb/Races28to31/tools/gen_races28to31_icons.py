#!/usr/bin/env python3
r"""
gen_races28to31_icons.py - races 28-31 in UI-CharacterCreate-Races.blp, next to Dark Iron.

Portraits go into the stock bevel frame at the placement gen_darkiron_race_icons.py fits against Kul Tiran.
Only the 4x4 blocks that touch a new cell are re-encoded at each mip level; every other block keeps its
bytes, because re-encoding the atlas drifts the stock icons.

    Column 9   rows 1/3   Mag'har (Horde)
    Column 10  rows 0/2   Void Elf (Alliance)      rows 1/3   Drakkari (Horde)
    Column 11  rows 0/2   Lightforged (Alliance)

Retail has no Drakkari portrait. --drakkari takes a folder with portrait-male-drakkari.png and
portrait-female-drakkari.png, 64x64 with a round alpha.

    python gen_races28to31_icons.py --atlas <in.blp> --out <out.blp> --portraits <dir> --drakkari <dir>
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, r"K:\Dark-Chaos\retroport_tools\_darkiron_icon")
import dxt3  # noqa: E402
import gen_darkiron_race_icons as icons  # noqa: E402

CELL = icons.CELL
# Bevel frames to lay a portrait into, by row: Kul Tiran for Alliance, Vulpera for Horde.
FRAME_COLUMN = 7
# The fit gen_darkiron_race_icons.py found against the Kul Tiran cells.
PLACEMENT = (54, 5, 5)
CELLS = (
    (9, 1, "temporaryportrait-male-magharorc.blp"), (9, 3, "temporaryportrait-female-magharorc.blp"),
    (10, 0, "temporaryportrait-male-voidelf.blp"), (10, 2, "temporaryportrait-female-voidelf.blp"),
    (10, 1, "drakkari:portrait-male-drakkari.png"), (10, 3, "drakkari:portrait-female-drakkari.png"),
    (11, 0, "temporaryportrait-male-lightforgeddraenei.blp"), (11, 2, "temporaryportrait-female-lightforgeddraenei.blp"),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--atlas", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--portraits", required=True)
    parser.add_argument("--drakkari", required=True)
    parser.add_argument("--sheet")
    args = parser.parse_args()

    blp, width, height, levels = icons.load_blp(args.atlas)
    atlas = Image.open(args.atlas).convert("RGBA")
    new = atlas.copy()
    for column, row, source in CELLS:
        frame = atlas.crop((FRAME_COLUMN * CELL, row * CELL, (FRAME_COLUMN + 1) * CELL, (row + 1) * CELL))
        path = os.path.join(args.drakkari, source[9:]) if source.startswith("drakkari:") \
            else os.path.join(args.portraits, source)
        portrait = Image.open(path).convert("RGBA")
        new.paste(icons.composite(frame, portrait, *PLACEMENT), (column * CELL, row * CELL))

    changed = 0
    image = new
    for level, (offset, size) in enumerate(levels):
        level_w, level_h = max(1, width >> level), max(1, height >> level)
        if level:
            image = image.resize((level_w, level_h), Image.BOX)
        blocks_w, blocks_h = max(1, (level_w + 3) // 4), max(1, (level_h + 3) // 4)
        pad = Image.new("RGBA", (blocks_w * 4, blocks_h * 4), (0, 0, 0, 0))
        pad.paste(image, (0, 0))
        pixels = np.asarray(pad, dtype=np.float64)
        for column, row, _ in CELLS:
            x0, x1 = (column * CELL) >> level, ((column + 1) * CELL) >> level
            y0, y1 = (row * CELL) >> level, ((row + 1) * CELL) >> level
            for block_y in range(y0 // 4, max(y0 // 4 + 1, (y1 + 3) // 4)):
                for block_x in range(x0 // 4, max(x0 // 4 + 1, (x1 + 3) // 4)):
                    if block_x >= blocks_w or block_y >= blocks_h:
                        continue
                    at = offset + (block_y * blocks_w + block_x) * 16
                    source_block = pixels[block_y * 4:block_y * 4 + 4, block_x * 4:block_x * 4 + 4]
                    blp[at:at + 16] = dxt3.encode_block(source_block)
                    changed += 1
    with open(args.out, "wb") as f:
        f.write(blp)
    print("patched %d blocks across %d mip levels" % (changed, len(levels)))
    if args.sheet:
        Image.open(args.out).convert("RGBA").crop((7 * CELL, 0, 12 * CELL, 4 * CELL)).resize(
            (5 * CELL * 3, 4 * CELL * 3), Image.Resampling.NEAREST).save(args.sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
