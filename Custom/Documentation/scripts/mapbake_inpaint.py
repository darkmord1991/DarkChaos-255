#!/usr/bin/env python3
"""Push-pull hole filling for map bakes.

Map 751's minimap tile grid is not a rectangle -- ~10 of the 17x12 slots have no
tile -- so a composite has flat background blocks at the corners and along a couple
of edges. On the world map those read as beige holes punched out of the continent.

fill_holes() replaces them with a smooth continuation of whatever terrain surrounds
them, using the classic push-pull (pyramid) method:

  PUSH  repeatedly halve the image, carrying a coverage weight, so each coarser
        level averages only the pixels that actually exist
  PULL  walk back up, and wherever a pixel is unknown take the (bilinearly
        upsampled) value from the level above

The result is a soft, plausible extension of the neighbouring coastline/terrain
rather than a hard block. It invents nothing recognisable -- at the resolution the
holes sit at it just continues the local colour field, which is exactly what
"show the surrounding areas" asks for.

Holes fully enclosed by terrain fill convincingly. Holes at the outer edge get a
smear of the nearest land, which still beats a beige rectangle.
"""
import numpy as np


def _down(img, w):
    """Halve img (H,W,3 float) and w (H,W float), averaging only covered pixels."""
    h, wd = w.shape
    h2, w2 = (h + 1) // 2, (wd + 1) // 2
    ph, pw = h2 * 2 - h, w2 * 2 - wd
    if ph or pw:
        img = np.pad(img, ((0, ph), (0, pw), (0, 0)), mode="edge")
        w = np.pad(w, ((0, ph), (0, pw)), mode="constant")
    acc = (img * w[..., None]).reshape(h2, 2, w2, 2, 3).sum(axis=(1, 3))
    wsum = w.reshape(h2, 2, w2, 2).sum(axis=(1, 3))
    out = np.zeros_like(acc)
    nz = wsum > 0
    out[nz] = acc[nz] / wsum[nz][..., None]
    return out, np.minimum(wsum, 1.0)


def _up(img, shape):
    """Nearest-neighbour double, cropped to shape. Smoothed by the blend below."""
    h, wd = shape
    big = np.repeat(np.repeat(img, 2, axis=0), 2, axis=1)
    return big[:h, :wd]


def fill_holes(rgb, known, levels=9):
    """rgb: (H,W,3) uint8. known: (H,W) bool. Returns a new (H,W,3) uint8."""
    img = rgb.astype(np.float64)
    w = known.astype(np.float64)
    pyr = [(img, w)]
    for _ in range(levels):
        if pyr[-1][1].shape[0] <= 2 or pyr[-1][1].shape[1] <= 2:
            break
        pyr.append(_down(*pyr[-1]))
    cur = pyr[-1][0]
    for lvl in range(len(pyr) - 2, -1, -1):
        img_l, w_l = pyr[lvl]
        up = _up(cur, w_l.shape)
        a = w_l[..., None]
        cur = img_l * a + up * (1.0 - a)
    out = rgb.copy()
    hole = ~known
    out[hole] = np.clip(cur[hole], 0, 255).astype(np.uint8)
    return out


def smooth_seam(rgb, known, radius=2):
    """Light box blur applied ONLY just inside the filled side of each hole edge,
    so the join does not show a hard tile line. Known pixels are never touched."""
    from PIL import Image, ImageFilter
    im = Image.fromarray(rgb)
    blur = np.asarray(im.filter(ImageFilter.GaussianBlur(radius)))
    k = known.astype(np.uint8)
    # dilate the known mask; the ring between known and dilated-known is the seam
    kk = k.copy()
    for _ in range(radius + 1):
        kk[1:, :] |= k[:-1, :]
        kk[:-1, :] |= k[1:, :]
        kk[:, 1:] |= k[:, :-1]
        kk[:, :-1] |= k[:, 1:]
        k = kk.copy()
    ring = (kk.astype(bool)) & (~known)
    out = rgb.copy()
    out[ring] = blur[ring]
    return out
