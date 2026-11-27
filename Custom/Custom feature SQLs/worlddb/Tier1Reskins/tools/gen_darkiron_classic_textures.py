#!/usr/bin/env python3
r"""
gen_darkiron_classic_textures.py - bake CLASSIC-LAYOUT Dark Iron skins for race 27.

Why (2026-09-06): the first Dark Iron pass (gen_reskin_races.py) shipped the retail body skins
verbatim.  Those are 1024x512 textures in the WoD/retail body layout (body strips on the left,
whole head on the right).  Race 27 uses the classic v264 dwarf model, whose compositor expects the
classic 512x512 layout (stock HD skin in patch-7) and refuses the retail file outright - every
Dark Iron rendered with a flat GREEN body while the face (a 512x512 blit into the face region)
happened to survive.  Retail faces also cannot be remapped onto the classic face UVs, so the
whole skin/face/underwear set is re-authored here from the parent's own textures.

Method: take the stock HD dwarf colour-00 set (skin, 20 face variations upper+lower, underwear),
re-tone them to five Dark Iron skin tones sampled from the retail skins, and turn the saturated
blue/green eye pixels into the Dark Iron ember glow.  Output is PALETTISED BLP2 (colorEncoding 1,
full mip chain) - the only body-texture format the 3.3.5 compositor is known to accept here.

Inputs (extract from the client's patch-7 first; scratchpad script `extract7.py` did this):
    <src>/Character/Dwarf/<Sex>/Dwarf<Sex>Skin00_00.blp  (+ Dwarf<Sex>Skin00_00_Extra.blp, the HD head texture)
    <src>/Character/Dwarf/<Sex>/Dwarf<Sex>Face{Upper,Lower}VV_00.blp   VV = 00..19
    <src>/Character/Dwarf/<Sex>/Dwarf<Sex>Naked{Pelvis,Torso}Skin00_00.blp (male has no torso)

Usage:
    python gen_darkiron_classic_textures.py --src <dir> --out K:\tmp\t1_darkirondwarf_classic
        [--preview sheet.png] [--csv]      # --csv rewrites the race-27 CharSections.csv rows

Then:  csv2wdbc.py --csv "Custom/CSV DBC/CharSections.csv" --out Custom/DBCs/CharSections.dbc
       --table CharSections ; deploy textures via the emitted .set file to patch-7, the DBC to
       patch-4 + enGB\patch-enGB-3 + enGB\patch-enGB-4, sync-dbc-deploy.js, hand Custom/DBCs over.
"""
import argparse
import csv
import io
import os
import re
import struct
import sys

import numpy as np
from PIL import Image

REPO = r"K:\Dark-Chaos\DarkChaos-255-Master"
CSVDIR = os.path.join(REPO, "Custom", "CSV DBC")
HERE = os.path.dirname(os.path.abspath(__file__))

RACE = 27
DEPLOY_DIR = "DarkIronDwarf"
FILE_PREFIX = "darkirondwarf"
NEW_ID_BASE = 951000          # 950000-950566 is the first pass; hair rows there stay live
SECTION_FLAGS = {0: 17, 1: 1, 4: 17}
MAX_FACE_VARIATION = 19       # the parent's CharSections rows stop at 19; patch-7 ships a 20th file

# Five skin tones per sex, sampled from the retail Dark Iron skins (body average of colours 0-3;
# colour 4 in retail is near-black, lifted here so shading survives).  RGB.
TONES = {
    "Male":   [(66, 60, 68), (106, 100, 94), (118, 114, 118), (70, 72, 74), (42, 38, 44)],
    "Female": [(80, 72, 86), (124, 118, 115), (138, 132, 142), (88, 89, 97), (50, 46, 54)],
}
EMBER = np.array([255.0, 138.0, 42.0])   # Dark Iron eye glow

# Hair (section 3) rows from the first pass reference darkirondwarfhair00_00..06.  The retail hair
# texture is the WoD layout: it is TRANSPARENT where the stock 512x256 layout keeps the beard
# rings / bands / earrings, and the dwarf's beard geosets (2-16, 302-310; female 302-306) sample
# the hair texture with opaque render flags -> those pieces rendered WHITE.  Ship stock dwarf hair
# textures (classic layout) under the Dark Iron names instead; the map below picks the seven
# stock colours closest to retail's Dark Iron palette (black, ash, dark brown, dark red, ember
# red, silver, white).  Stock hair has no skin patch (colour-invariant pixels are all leather /
# metal), so no re-tone is needed.
HAIR_MAP = {0: 9, 1: 8, 2: 4, 3: 10, 4: 16, 5: 7, 6: 14}


# ------------------------------------------------------------------ BLP read
def blp_decode(path):
    b = open(path, "rb").read()
    enc, ad, at = b[8], b[9], b[10]
    w, h = struct.unpack("<II", b[12:20])
    offs = struct.unpack("<16I", b[20:84])
    sizes = struct.unpack("<16I", b[84:148])
    data = b[offs[0]:offs[0] + sizes[0]]
    if enc == 1:
        pal = np.frombuffer(b[148:148 + 1024], dtype=np.uint8).reshape(256, 4)[:, [2, 1, 0]]
        idx = np.frombuffer(data[:w * h], dtype=np.uint8)
        rgb = pal[idx].reshape(h, w, 3)
        return Image.fromarray(rgb, "RGB")
    if enc == 2:
        n = 1 if ad == 0 else {1: 2, 7: 3}.get(at, 1)
        return Image.frombytes("RGBA", (w, h), data, "bcn", n).convert("RGB")
    if enc == 3:
        return Image.frombytes("RGBA", (w, h), data, "raw", "BGRA").convert("RGB")
    raise SystemExit("unsupported BLP encoding %d in %s" % (enc, path))


# ------------------------------------------------------------------ BLP write (palettised)
def blp_write_palettised(im, path):
    """BLP2 colorEncoding 1, alphaDepth 0, alphaType 8, full mip chain - the stock skin format."""
    im = im.convert("RGB")
    w, h = im.size
    q0 = im.quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = q0.getpalette()[:768]
    pal += [0] * (768 - len(pal))
    palimg = Image.new("P", (1, 1))
    palimg.putpalette(pal)
    mips = []
    mw, mh = w, h
    cur = im
    while True:
        q = cur.quantize(palette=palimg, dither=Image.Dither.NONE)
        mips.append(q.tobytes())
        if mw == 1 and mh == 1:
            break
        mw, mh = max(1, mw // 2), max(1, mh // 2)
        cur = im.resize((mw, mh), Image.Resampling.LANCZOS)
    offs, sizes = [0] * 16, [0] * 16
    pos = 148 + 1024
    for i, m in enumerate(mips[:16]):
        offs[i], sizes[i] = pos, len(m)
        pos += len(m)
    hdr = b"BLP2" + struct.pack("<I", 1) + bytes((1, 0, 8, 1)) + struct.pack("<II", w, h)
    hdr += struct.pack("<16I", *offs) + struct.pack("<16I", *sizes)
    palbytes = bytearray()
    for i in range(256):
        r, g, b = pal[3 * i:3 * i + 3]
        palbytes += bytes((b, g, r, 0))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(hdr)
        f.write(palbytes)
        for m in mips[:16]:
            f.write(m)


# ------------------------------------------------------------------ recolour
def _hsv(rgb):
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn
    sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    hue[rm] = (60.0 * ((g[rm] - b[rm]) / d[rm])) % 360.0
    hue[gm] = 60.0 * ((b[gm] - r[gm]) / d[gm]) + 120.0
    hue[bm] = 60.0 * ((r[bm] - g[bm]) / d[bm]) + 240.0
    return hue, sat, mx / 255.0


def retone(im, tone, src_avg_lum, skin_mask_only=False, ember_eyes=False):
    """Map the source's shading onto `tone`.  Luminance ratio drives the multiplicative part,
    a small additive term keeps contrast alive in the darker tones."""
    rgb = np.asarray(im.convert("RGB"), dtype=np.float64)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    ratio = np.clip(lum / src_avg_lum, 0.0, 2.2)
    tone = np.array(tone, dtype=np.float64)
    out = tone * (ratio[..., None] ** 0.85) + ((lum - src_avg_lum) * 0.22)[..., None]
    out = np.clip(out, 0, 255)
    hue, sat, val = _hsv(rgb)
    if skin_mask_only:
        # underwear: only re-tone skin-coloured pixels, leave the cloth alone
        skin = (hue >= 5) & (hue <= 45) & (sat >= 0.22) & (sat <= 0.78) & (val > 0.22)
        out = np.where(skin[..., None], out, rgb)
    if ember_eyes:
        eye = (sat > 0.38) & (hue >= 70) & (hue <= 290) & (val > 0.18)
        glow = EMBER * np.clip(val, 0.55, 1.0)[..., None]
        out = np.where(eye[..., None], glow, out)
    return Image.fromarray(out.astype(np.uint8), "RGB")


def source_avg_lum(im):
    rgb = np.asarray(im.convert("RGB"), dtype=np.float64)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    return float(lum[lum > 20].mean())


# ------------------------------------------------------------------ main
def find(src, sex, pattern):
    d = os.path.join(src, "Character", "Dwarf", sex)
    rx = re.compile(pattern, re.I)
    out = {}
    for f in sorted(os.listdir(d)):
        m = rx.match(f)
        if m:
            out[int(m.group(1)) if m.groups() else 0] = os.path.join(d, f)
    return out


def dest(sex, filename):
    return "Character\\%s\\%s\\%s" % (DEPLOY_DIR, sex, filename)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="dir holding Character/Dwarf/<Sex>/*.blp (stock HD set)")
    ap.add_argument("--out", required=True, help="staging root; textures land under Character/DarkIronDwarf")
    ap.add_argument("--preview", help="write a contact sheet PNG of colour 0..4 skins + one face per sex")
    ap.add_argument("--csv", action="store_true", help="rewrite the race-27 skin/face/underwear CharSections.csv rows")
    ap.add_argument("--hair-only", action="store_true", help="only emit the hair textures + reskin_classic_hair.set")
    a = ap.parse_args()

    setfile = []
    csv_rows = []
    next_id = NEW_ID_BASE
    preview = []
    lo = FILE_PREFIX

    hair_set = []
    for c, stock in HAIR_MAP.items():
        srcp = os.path.join(a.src, "Character", "Dwarf", "Hair00_%02d.blp" % stock)
        name = "%shair00_%02d.blp" % (lo, c)
        p = os.path.join(a.out, "Character", DEPLOY_DIR, name)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(srcp, "rb") as fi, open(p, "wb") as fo:
            fo.write(fi.read())
        hair_set.append((p, "Character\\%s\\%s" % (DEPLOY_DIR, name)))
    hair_setpath = os.path.join(HERE, "reskin_classic_hair.set")
    with open(hair_setpath, "w", encoding="utf-8") as f:
        for local, arch in hair_set:
            f.write("%s=%s\n" % (local, arch))
    print("hair: %d stock textures copied under Dark Iron names, set-file %s" % (len(hair_set), hair_setpath))
    if a.hair_only:
        return

    for sex in ("Male", "Female"):
        sx = sex.lower()
        skin = find(src=a.src, sex=sex, pattern=r"^Dwarf%sSkin00_00\.blp$" % sex)[0]
        uppers = find(a.src, sex, r"^Dwarf%sFaceUpper(\d\d)_00\.blp$" % sex)
        lowers = find(a.src, sex, r"^Dwarf%sFaceLower(\d\d)_00\.blp$" % sex)
        pelvis = find(a.src, sex, r"^Dwarf%sNakedPelvisSkin00_00\.blp$" % sex).get(0)
        torso = find(a.src, sex, r"^Dwarf%sNakedTorsoSkin00_00\.blp$" % sex).get(0)
        extra = find(a.src, sex, r"^Dwarf%sSkin00_00_Extra\.blp$" % sex)[0]
        variations = sorted(v for v in set(uppers) & set(lowers) if v <= MAX_FACE_VARIATION)
        skin_im = blp_decode(skin)
        avg = source_avg_lum(skin_im)
        print("%s: skin %s avg lum %.1f, %d face variations, pelvis=%s torso=%s"
              % (sex, os.path.basename(skin), avg, len(variations), bool(pelvis), bool(torso)))

        for c, tone in enumerate(TONES[sex]):
            cc = "%02d" % c
            # section 0 - skin
            name = "%s%sskin00_%s.blp" % (lo, sx, cc)
            p = os.path.join(a.out, "Character", DEPLOY_DIR, sex, name)
            im = retone(skin_im, tone, avg)
            blp_write_palettised(im, p)
            setfile.append((p, dest(sex, name)))
            # TextureName_2 = the HD "skin extra" head texture (M2 texture type 8).  The HD dwarf models
            # in patch-7 draw the ears (geoset 702) and the beard rings / bands from it; a skin row
            # without it renders those pieces WHITE.  Re-toned from the parent's Extra like the faces.
            xname = "%s%sskin00_%s_Extra.blp" % (lo, sx, cc)
            xp = os.path.join(a.out, "Character", DEPLOY_DIR, sex, xname)
            xim = retone(blp_decode(extra), tone, avg, ember_eyes=True)
            blp_write_palettised(xim, xp)
            setfile.append((xp, dest(sex, xname)))
            csv_rows.append([next_id, RACE, 0 if sex == "Male" else 1, 0, dest(sex, name), dest(sex, xname), "", SECTION_FLAGS[0], 0, c])
            next_id += 1
            preview.append(("%s skin %d" % (sex, c), im))
            preview.append(("%s extra %d" % (sex, c), xim))

            # section 1 - faces (lower in TextureName_1, upper in TextureName_2, like the parent)
            for v in variations:
                vv = "%02d" % v
                pair = []
                for kind, srcmap in (("facelower", lowers), ("faceupper", uppers)):
                    name = "%s%s%s%s_%s.blp" % (lo, sx, kind, vv, cc)
                    p = os.path.join(a.out, "Character", DEPLOY_DIR, sex, name)
                    im = retone(blp_decode(srcmap[v]), tone, avg, ember_eyes=True)
                    blp_write_palettised(im, p)
                    setfile.append((p, dest(sex, name)))
                    pair.append(dest(sex, name))
                    if v == 0 and kind == "facelower":
                        preview.append(("%s face %d" % (sex, c), im))
                # Faces 10-19 are the Death Knight set: that class cannot select a flag 1 row.
                flags = SECTION_FLAGS[1] if v < 10 else 5
                csv_rows.append([next_id, RACE, 0 if sex == "Male" else 1, 1, pair[0], pair[1], "", flags, v, c])
                next_id += 1

            # section 4 - underwear (pelvis in _1, torso in _2 for the female; male is pelvis-only)
            tex = []
            for kind, srcp in (("nakedpelvisskin", pelvis), ("nakedtorsoskin", torso)):
                if not srcp:
                    tex.append("")
                    continue
                name = "%s%s%s00_%s.blp" % (lo, sx, kind, cc)
                p = os.path.join(a.out, "Character", DEPLOY_DIR, sex, name)
                im = retone(blp_decode(srcp), tone, avg, skin_mask_only=True)
                blp_write_palettised(im, p)
                setfile.append((p, dest(sex, name)))
                tex.append(dest(sex, name))
            csv_rows.append([next_id, RACE, 0 if sex == "Male" else 1, 4, tex[0], tex[1], "", SECTION_FLAGS[4], 0, c])
            next_id += 1

    setpath = os.path.join(HERE, "reskin_classic_textures.set")
    with open(setpath, "w", encoding="utf-8") as f:
        for local, arch in setfile:
            f.write("%s=%s\n" % (local, arch))
    print("wrote %d textures, set-file %s" % (len(setfile), setpath))

    if a.preview:
        cell = 256
        cols = 5
        rows = (len(preview) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * cell, rows * (cell + 16)), (40, 40, 40))
        from PIL import ImageDraw
        d = ImageDraw.Draw(sheet)
        for i, (label, im) in enumerate(preview):
            t = im.copy()
            t.thumbnail((cell, cell))
            x, y = (i % cols) * cell, (i // cols) * (cell + 16)
            sheet.paste(t, (x, y + 16))
            d.text((x + 3, y + 2), label, fill=(255, 255, 0))
        sheet.save(a.preview)
        print("preview", a.preview)

    if a.csv:
        p = os.path.join(CSVDIR, "CharSections.csv")
        bak = p + ".pre-darkiron-classic.bak"
        if not os.path.exists(bak):
            import shutil
            shutil.copy2(p, bak)
        with open(p, encoding="utf-8-sig", newline="") as f:
            rd = csv.reader(f)
            hdr = next(rd)
            rows = [r for r in rd]
        keep = [r for r in rows if not (int(r[1]) == RACE and int(r[3]) in (0, 1, 4))]
        dropped = len(rows) - len(keep)
        assert not any(int(r[0]) >= NEW_ID_BASE for r in keep), "id block %d+ already in use" % NEW_ID_BASE
        keep.extend([[str(x) for x in r] for r in csv_rows])
        buf = io.StringIO()
        w = csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator="\n")
        w.writerow(hdr)
        w.writerows(keep)
        with io.open(p, "w", encoding="utf-8", newline="") as f:
            f.write(buf.getvalue())
        print("CharSections.csv: dropped %d first-pass race-%d rows (sections 0/1/4), appended %d (ids %d-%d)"
              % (dropped, RACE, len(csv_rows), NEW_ID_BASE, next_id - 1))


if __name__ == "__main__":
    main()
