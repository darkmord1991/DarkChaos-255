#!/usr/bin/env python3
"""Turn DC Portrait Capture screenshots into Encounter Journal boss art.

The addon (Capture.lua) renders each creature display id full-screen against
black and takes one screenshot per boss, in QUEUE order. This script pairs the
newest screenshots with that queue and writes the two BLPs the journal wants:

    UI-EJ-BOSS-<Name>.blp         128x64  the boss-list banner
    Portrait_model_<display>.blp   64x64  the small square icon

Both come out as uncompressed BLP2 BGRA (type=1, encoding=3, alphaDepth=8,
hasMips=0) -- the same shape as the 28 uncompressed BLPs already shipping in the
client patch, so no DXT encoder or external converter is needed. Lossless, and
the files are small enough (33 KB / 16 KB) that compression buys nothing.

The banner silhouette is lifted from the alpha channel of an existing banner, so
the result has the same torn-medallion shape as Blizzard's own art. Only the
mask is borrowed -- no pixels.

    python make-portraits.py --selftest        check the decoder + mask
    python make-portraits.py --dry-run         show the pairing, write nothing
    python make-portraits.py                   write the BLPs into the patch
"""

import argparse
import os
import struct
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required:  python -m pip install pillow")

# Must match CAPTURE_FRACTION in Capture.lua.
CAPTURE_FRACTION = 0.8

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
PATCH = os.path.join(REPO, 'Custom', 'Client patches needed', 'Interface')
EJ_DIR = os.path.join(PATCH, 'EncounterJournal')
PORTRAIT_DIR = os.path.join(PATCH, 'PORTRAITS')
DEFAULT_MASK = os.path.join(EJ_DIR, 'UI-EJ-BOSS-Ursoc.blp')
DEFAULT_SHOTS = r'K:\WoW_3.3.5a_ 255 Fun\Screenshots'

# ORDER MATTERS: this is the same list, in the same order, as QUEUE in
# Capture.lua. The Nth-oldest of the newest --count screenshots is entry N.
QUEUE = [
    # Timbermaw Hold (map 819)
    ("GatewardenMorthak",     503739, "Gatewarden Mor'thak"),
    ("TheSunderedChieftain",  503737, "The Sundered Chieftain"),
    ("DenMotherUrsara",       23773,  "Den Mother Ursara"),
    ("XanthirTheDefiler",     503743, "Xanthir the Defiler"),
    ("TheNightmareGivenRoot", 503770, "The Nightmare Given Root"),
    ("Ursol",                 503735, "Ursol"),
    # Crescent Grove (map 823)
    ("KeeperRanathos",        503751, "Keeper Ranathos"),
    ("GrovetenderEngryss",    503737, "Grovetender Engryss"),
    ("HighPriestessAlathea",  503753, "High Priestess A'lathea"),
    ("FenektisTheDeceiver",   503747, "Fenektis the Deceiver"),
    ("MasterRaxxieth",        503755, "Master Raxxieth"),
    # Emerald Sanctum (map 824)
    ("Erennius",              503765, "Erennius"),
]

BLP_HEADER = 148
BLP_PALETTE = 1024
BLP_DATA = BLP_HEADER + BLP_PALETTE   # 1172 -- the palette block is present for
                                      # every encoding, not just palettised ones


# --------------------------------------------------------------------------
#  BLP reading (DXT1/3/5 -> RGBA), enough to lift a mask from existing art
# --------------------------------------------------------------------------

def _c565(v):
    return (((v >> 11) & 31) * 255 // 31,
            ((v >> 5) & 63) * 255 // 63,
            (v & 31) * 255 // 31)


def _decode_dxt(src, w, h, alpha_enc):
    """alpha_enc: 0 = DXT1, 1 = DXT3, 7 = DXT5."""
    block = 8 if alpha_enc == 0 else 16
    out = bytearray(w * h * 4)
    pos = 0
    for by in range(0, h, 4):
        for bx in range(0, w, 4):
            alpha = [255] * 16
            if alpha_enc == 7:
                a0, a1 = src[pos], src[pos + 1]
                bits = int.from_bytes(src[pos + 2:pos + 8], 'little')
                table = [a0, a1]
                # 8-value mode interpolates a2..a7 as (6-i)*a0 + (i+1)*a1 over 7;
                # 6-value mode uses /5 and reserves the last two slots for 0/255.
                if a0 > a1:
                    table += [((6 - i) * a0 + (i + 1) * a1) // 7 for i in range(6)]
                else:
                    table += [((4 - i) * a0 + (i + 1) * a1) // 5 for i in range(4)] + [0, 255]
                alpha = [table[(bits >> (3 * i)) & 7] for i in range(16)]
                cpos = pos + 8
            elif alpha_enc == 1:
                raw = int.from_bytes(src[pos:pos + 8], 'little')
                alpha = [((raw >> (4 * i)) & 15) * 17 for i in range(16)]
                cpos = pos + 8
            else:
                cpos = pos

            c0, c1 = struct.unpack_from('<HH', src, cpos)
            idx = int.from_bytes(src[cpos + 4:cpos + 8], 'little')
            r0, g0, b0 = _c565(c0)
            r1, g1, b1 = _c565(c1)
            if alpha_enc != 0 or c0 > c1:
                colours = [(r0, g0, b0), (r1, g1, b1),
                           ((2 * r0 + r1) // 3, (2 * g0 + g1) // 3, (2 * b0 + b1) // 3),
                           ((r0 + 2 * r1) // 3, (g0 + 2 * g1) // 3, (b0 + 2 * b1) // 3)]
                punch = None
            else:
                colours = [(r0, g0, b0), (r1, g1, b1),
                           ((r0 + r1) // 2, (g0 + g1) // 2, (b0 + b1) // 2),
                           (0, 0, 0)]
                punch = 3

            for i in range(16):
                px, py = bx + (i % 4), by + (i // 4)
                if px >= w or py >= h:
                    continue
                sel = (idx >> (2 * i)) & 3
                r, g, b = colours[sel]
                a = 0 if (punch is not None and sel == punch) else alpha[i]
                o = (py * w + px) * 4
                out[o:o + 4] = bytes((r, g, b, a))
            pos += block
    return bytes(out)


def read_blp(path):
    """Decode mip 0 of a BLP2 file to a Pillow RGBA image."""
    with open(path, 'rb') as f:
        d = f.read()
    if d[:4] != b'BLP2':
        raise ValueError('%s is not BLP2' % path)

    enc, alpha_depth, alpha_enc, _has_mips = struct.unpack_from('<BBBB', d, 8)
    w, h = struct.unpack_from('<II', d, 12)
    off = struct.unpack_from('<16I', d, 20)[0]
    size = struct.unpack_from('<16I', d, 84)[0]
    raw = d[off:off + size]

    if enc == 2:
        rgba = _decode_dxt(raw, w, h, alpha_enc)
    elif enc == 3:
        rgba = bytearray(raw)
        rgba[0::4], rgba[2::4] = raw[2::4], raw[0::4]     # BGRA -> RGBA
        rgba = bytes(rgba)
    elif enc == 1:
        pal = d[BLP_HEADER:BLP_HEADER + BLP_PALETTE]
        out = bytearray(w * h * 4)
        n = w * h
        for i in range(n):
            p = raw[i] * 4
            a = 255
            if alpha_depth == 8:
                a = raw[n + i]
            out[i * 4:i * 4 + 4] = bytes((pal[p + 2], pal[p + 1], pal[p], a))
        rgba = bytes(out)
    else:
        raise ValueError('unsupported BLP encoding %d in %s' % (enc, path))

    return Image.frombytes('RGBA', (w, h), rgba)


# --------------------------------------------------------------------------
#  BLP writing (uncompressed BGRA, single mip)
# --------------------------------------------------------------------------

def write_blp(img, path):
    img = img.convert('RGBA')
    w, h = img.size
    raw = img.tobytes()
    bgra = bytearray(raw)
    bgra[0::4], bgra[2::4] = raw[2::4], raw[0::4]

    offsets = [0] * 16
    sizes = [0] * 16
    offsets[0] = BLP_DATA
    sizes[0] = w * h * 4

    head = bytearray()
    head += b'BLP2'
    head += struct.pack('<I', 1)                 # type: direct
    head += struct.pack('<BBBB', 3, 8, 8, 0)     # enc=BGRA, alpha 8, alphaEnc 8, no mips
    head += struct.pack('<II', w, h)
    head += struct.pack('<16I', *offsets)
    head += struct.pack('<16I', *sizes)
    assert len(head) == BLP_HEADER, len(head)
    head += b'\0' * BLP_PALETTE

    with open(path, 'wb') as f:
        f.write(bytes(head))
        f.write(bytes(bgra))


# --------------------------------------------------------------------------
#  compositing
# --------------------------------------------------------------------------

def crop_render(shot_path):
    """Pull the square render back out of a full-screen screenshot."""
    img = Image.open(shot_path).convert('RGBA')
    w, h = img.size
    side = int(round(h * CAPTURE_FRACTION))
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def cover_resize(img, box_w, box_h):
    """Scale to cover box_w x box_h, then centre-crop -- no distortion."""
    scale = max(box_w / img.width, box_h / img.height)
    img = img.resize((max(1, int(round(img.width * scale))),
                      max(1, int(round(img.height * scale)))), Image.LANCZOS)
    left = (img.width - box_w) // 2
    top = (img.height - box_h) // 2
    return img.crop((left, top, left + box_w, top + box_h))


def build_banner(render, mask):
    """Paste the render into the mask's torn-medallion silhouette."""
    bbox = mask.getchannel('A').getbbox()
    if not bbox:
        raise ValueError('mask has no opaque pixels')
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]

    banner = Image.new('RGBA', mask.size, (0, 0, 0, 0))
    banner.paste(cover_resize(render, bw, bh), (bbox[0], bbox[1]))
    banner.putalpha(mask.getchannel('A'))
    return banner


def newest_screenshots(folder, count):
    if not os.path.isdir(folder):
        sys.exit('screenshot folder not found: %s' % folder)
    shots = [os.path.join(folder, f) for f in os.listdir(folder)
             if f.lower().endswith(('.tga', '.jpg', '.jpeg', '.png'))]
    if len(shots) < count:
        sys.exit('found %d screenshots in %s, need %d' % (len(shots), folder, count))
    shots.sort(key=os.path.getmtime)
    return shots[-count:]          # newest `count`, oldest of those first


# --------------------------------------------------------------------------

def selftest(mask_path):
    print('decoding mask: %s' % mask_path)
    mask = read_blp(mask_path)
    a = mask.getchannel('A')
    opaque = mask.width * mask.height - a.histogram()[0]
    print('  size        : %dx%d' % mask.size)
    print('  alpha bbox  : %s' % (a.getbbox(),))
    print('  opaque px   : %d / %d (%.0f%%)' % (opaque, mask.width * mask.height,
                                                100.0 * opaque / (mask.width * mask.height)))
    if mask.size != (128, 64):
        print('  WARNING: expected a 128x64 banner')
    if not (0.2 < opaque / (mask.width * mask.height) < 0.95):
        print('  WARNING: silhouette looks wrong -- is this really a boss banner?')

    print('round-tripping the BLP writer')
    import io, tempfile
    with tempfile.TemporaryDirectory() as td:
        p = os.path.join(td, 't.blp')
        src = Image.new('RGBA', (128, 64), (10, 200, 30, 128))
        src.putpixel((0, 0), (255, 0, 0, 255))
        write_blp(src, p)
        back = read_blp(p)
        ok = back.size == src.size and back.getpixel((0, 0)) == (255, 0, 0, 255) \
            and back.getpixel((5, 5)) == (10, 200, 30, 128)
        print('  writer/reader agree: %s' % ok)
        if not ok:
            return 1
    print('selftest OK')
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--shots', default=DEFAULT_SHOTS, help='WoW Screenshots folder')
    ap.add_argument('--count', type=int, default=len(QUEUE), help='how many newest shots to take')
    ap.add_argument('--mask', default=DEFAULT_MASK, help='existing banner to lift the silhouette from')
    ap.add_argument('--ej-dir', default=EJ_DIR)
    ap.add_argument('--portrait-dir', default=PORTRAIT_DIR)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--force', action='store_true', help='overwrite existing art')
    args = ap.parse_args()

    if args.selftest:
        return selftest(args.mask)

    if args.count != len(QUEUE):
        print('note: --count %d but QUEUE has %d entries; pairing the first %d'
              % (args.count, len(QUEUE), min(args.count, len(QUEUE))))

    shots = newest_screenshots(args.shots, args.count)
    pairs = list(zip(QUEUE, shots))

    print('pairing %d screenshots (oldest first) against the capture queue:' % len(pairs))
    for (name, display, boss), shot in pairs:
        print('  %-26s <- %s' % (boss, os.path.basename(shot)))
    if args.dry_run:
        print('\n--dry-run: nothing written')
        return 0

    mask = read_blp(args.mask)
    written = 0
    for (name, display, boss), shot in pairs:
        render = crop_render(shot)

        banner_path = os.path.join(args.ej_dir, 'UI-EJ-BOSS-%s.blp' % name)
        portrait_path = os.path.join(args.portrait_dir, 'Portrait_model_%d.blp' % display)

        if os.path.exists(banner_path) and not args.force:
            print('  SKIP (exists): %s' % os.path.basename(banner_path))
        else:
            write_blp(build_banner(render, mask), banner_path)
            print('  wrote %s' % os.path.basename(banner_path))
            written += 1

        if os.path.exists(portrait_path) and not args.force:
            print('  SKIP (exists): %s' % os.path.basename(portrait_path))
        else:
            write_blp(cover_resize(render, 64, 64), portrait_path)
            print('  wrote %s' % os.path.basename(portrait_path))
            written += 1

    print('\n%d files written. Rebuild + deploy the MPQ patch to see them.' % written)
    return 0


if __name__ == '__main__':
    sys.exit(main())
