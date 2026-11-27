"""Build the small DC-Talents textures that stand in for retail art 3.3.5 cannot draw directly.

  Textures/Line-<state>.tga       talents-arrow-line-<state>, reshaped for the stock DrawRouteLine
                                  rotated-quad technique: the line strip fills a 32x32 texture with a
                                  transparent 1px border (the 32/30 factor in Core/Line.lua).
  Textures/ArrowHead-<state>.tga  talents-arrow-head-<state> on its own padded square, so 3.3.5's
                                  Texture:SetRotation (which rotates the whole file's texture
                                  coordinates) can turn it without pulling in neighbouring sprites.

Source: the retail 11.2.5 PTR talentframe BLPs (BLP2 colour encoding 3, raw BGRA) with 11.2.7 atlas
coordinates. TGAs are written by hand as uncompressed 32bpp, bottom-left origin (what 3.3.5 reads).
Usage: python make_dc_textures.py
"""
import os
import re
import struct

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, '..', '..', 'DC-Talents', 'Textures'))
SRC = r'K:/Dark-Chaos/WoW 11.2.5 PTR interface extract/talentframe'
ATLAS_SOURCE = r'K:/Dark-Chaos/WoW 11.2.7 FrameXML/Helix/AtlasInfo.lua'

STATES = ['yellow', 'gray', 'red', 'locked', 'ghost']


def load_blp_raw(path):
    data = open(path, 'rb').read()
    assert data[:4] == b'BLP2', path
    encoding = data[8]
    width, height = struct.unpack_from('<II', data, 12)
    offset = struct.unpack_from('<I', data, 20)[0]
    if encoding != 3:
        raise ValueError('%s: expected raw BGRA (encoding 3), got %d' % (path, encoding))
    raw = data[offset:offset + width * height * 4]
    image = Image.frombytes('RGBA', (width, height), raw, 'raw', 'BGRA')
    return image


def atlas_rects():
    rects = {}
    for line in open(ATLAS_SOURCE, encoding='utf-8', errors='replace'):
        m = re.match(r'\s*\["(talents-arrow-(?:line|head)-\w+)"\]=\{(\d+), (\d+), ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)', line)
        if m:
            name = m.group(1)
            w, h, l, r, t, b = (float(v) for v in m.groups()[1:])
            rects[name] = (w, h, l, r, t, b)
    return rects


def crop(image, rect):
    _, _, l, r, t, b = rect
    width, height = image.size
    return image.crop((round(l * width), round(t * height), round(r * width), round(b * height)))


def write_tga(path, image):
    image = image.convert('RGBA')
    width, height = image.size
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    rows = []
    pixels = image.tobytes('raw', 'BGRA')
    stride = width * 4
    for y in range(height - 1, -1, -1):
        rows.append(pixels[y * stride:(y + 1) * stride])
    with open(path, 'wb') as fh:
        fh.write(header)
        fh.write(b''.join(rows))


def padded(image, inner_width, inner_height, size=32):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    resized = image.resize((inner_width, inner_height), Image.LANCZOS)
    canvas.paste(resized, ((size - inner_width) // 2, (size - inner_height) // 2), resized)
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    rects = atlas_rects()
    lines = load_blp_raw(os.path.join(SRC, 'talentsarrowline.blp'))
    nodes = load_blp_raw(os.path.join(SRC, 'talents.blp'))

    for state in STATES:
        name = 'talents-arrow-line-' + state
        if name in rects:
            strip = crop(lines, rects[name])
            # The strip tiles horizontally; its full height becomes the line thickness.
            write_tga(os.path.join(OUT, 'Line-%s.tga' % state), padded(strip, 30, 30))
            print('Line-%s.tga from %s %dx%d' % (state, name, *strip.size))

        name = 'talents-arrow-head-' + state
        if name in rects:
            head = crop(nodes, rects[name])
            w, h = head.size
            scale = 30.0 / max(w, h)
            write_tga(os.path.join(OUT, 'ArrowHead-%s.tga' % state), padded(head, max(1, round(w * scale)), max(1, round(h * scale))))
            print('ArrowHead-%s.tga from %s %dx%d' % (state, name, w, h))

    # Plain white line for solid-colour lines (SetColorTexture on a Line).
    white = Image.new('RGBA', (30, 30), (255, 255, 255, 255))
    write_tga(os.path.join(OUT, 'Line.tga'), padded(white, 30, 30))
    print('Line.tga (white)')


if __name__ == '__main__':
    main()
