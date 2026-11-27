"""Re-pad retail spell decal textures for DC-DangerZone and write BLP2 DXT5 with full mips.

Each source's visible content (alpha > 16) is cropped to its square bbox, scaled so it
exactly fills the inner (1 - 2*MARGIN) of a CANVAS canvas, and centred.  The addon maps
the world square [-R, R] onto texcoords [MARGIN, 1-MARGIN], so the outer edge of the
ring in the texture lands exactly on the world radius, and sampling a little outside
the square (strip slivers, texture spin) hits transparent margin instead of wrapping
into visible content.
"""
import struct, sys, os
from PIL import Image
import numpy as np

CANVAS = 512
MARGIN = 0.15

def crop_pad(src):
    im = Image.open(src); im.load(); im = im.convert("RGBA")
    a = np.array(im)[:, :, 3]
    ys, xs = np.where(a > 16)
    if len(ys) == 0:
        raise SystemExit("empty alpha: " + src)
    cy, cx = (ys.min() + ys.max()) / 2.0, (xs.min() + xs.max()) / 2.0
    half = max(ys.max() - ys.min(), xs.max() - xs.min()) / 2.0 + 1
    box = (int(round(cx - half)), int(round(cy - half)), int(round(cx + half)), int(round(cy + half)))
    # crop may run past the source edge; PIL pads with transparent black
    crop = im.crop(box)
    inner = int(round(CANVAS * (1 - 2 * MARGIN)))
    crop = crop.resize((inner, inner), Image.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    off = (CANVAS - inner) // 2
    out.paste(crop, (off, off))
    return out

def to565(r, g, b):
    return ((int(r) >> 3) << 11) | ((int(g) >> 2) << 5) | (int(b) >> 3)

def from565(c):
    return np.array([((c >> 11) & 31) * 255 / 31, ((c >> 5) & 63) * 255 / 63, (c & 31) * 255 / 31])

def encode_dxt5(rgba):
    h, w = rgba.shape[:2]
    bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
    pad = np.zeros((bh * 4, bw * 4, 4), dtype=np.float64)
    pad[:h, :w] = rgba
    out = bytearray()
    for by in range(bh):
        for bx in range(bw):
            blk = pad[by * 4:by * 4 + 4, bx * 4:bx * 4 + 4].reshape(16, 4)
            alpha = blk[:, 3]
            rgb = blk[:, :3].copy()
            opaque = alpha > 0
            if opaque.any() and not opaque.all():
                rgb[~opaque] = rgb[opaque].mean(axis=0)
            # --- alpha block (8-level, a0 > a1) ---
            a0, a1 = int(alpha.max()), int(alpha.min())
            if a0 == a1:
                idx = [0] * 16
            else:
                levels = [a0, a1] + [((7 - i) * a0 + i * a1) / 7.0 for i in range(1, 7)]
                idx = [int(np.argmin([abs(v - l) for l in levels])) for v in alpha]
            bits = 0
            for i, v in enumerate(idx):
                bits |= (v & 7) << (3 * i)
            out += struct.pack("<BB", a0, a1) + bits.to_bytes(6, "little")
            # --- color block (range fit, c0 > c1 -> 4 colours) ---
            cmax = rgb.max(axis=0); cmin = rgb.min(axis=0)
            c0, c1 = to565(*cmax), to565(*cmin)
            if c0 < c1:
                c0, c1 = c1, c0
            if c0 == c1:
                cidx = 0
            else:
                p0, p1 = from565(c0), from565(c1)
                pal = [p0, p1, (2 * p0 + p1) / 3, (p0 + 2 * p1) / 3]
                cidx = 0
                for i in range(16):
                    d = [np.sum((rgb[i] - p) ** 2) for p in pal]
                    cidx |= int(np.argmin(d)) << (2 * i)
            out += struct.pack("<HHI", c0, c1, cidx)
    return bytes(out)

def write_blp2_dxt5(im, dst):
    mips = []
    cur = im
    while True:
        mips.append(cur)
        if cur.size[0] <= 1 and cur.size[1] <= 1:
            break
        cur = cur.resize((max(1, cur.size[0] // 2), max(1, cur.size[1] // 2)), Image.LANCZOS)
    if len(mips) > 16:
        mips = mips[:16]
    datas = [encode_dxt5(np.array(m, dtype=np.float64)) for m in mips]
    header_size = 4 + 4 + 4 + 4 + 4 + 64 + 64 + 1024
    offsets, sizes, pos = [], [], header_size
    for d in datas:
        offsets.append(pos); sizes.append(len(d)); pos += len(d)
    offsets += [0] * (16 - len(offsets)); sizes += [0] * (16 - len(sizes))
    hdr = b"BLP2" + struct.pack("<I", 1) + struct.pack("<BBBB", 2, 8, 7, 1)
    hdr += struct.pack("<II", im.size[0], im.size[1])
    hdr += struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + bytes(1024)
    with open(dst, "wb") as f:
        f.write(hdr)
        for d in datas:
            f.write(d)
    return len(mips), pos

if __name__ == "__main__":
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    pairs = [a.split("=") for a in sys.argv[2:]]
    for name, src in pairs:
        im = crop_pad(src)
        n, size = write_blp2_dxt5(im, os.path.join(outdir, name + ".blp"))
        im.save(os.path.join(outdir, name + ".png"))
        print(f"{name}: {n} mips, {size} bytes  <- {os.path.basename(src)}")
