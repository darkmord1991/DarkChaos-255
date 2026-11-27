"""Restore retail MCNK holes on chunks covered by a WMO footprint (map 861).

wxl-baker's --flatten-holes zeroes EVERY hole because 3.3.5 cannot hide a hole
behind a modern cliff/cave mesh -- the hole would show sky.  That is right for
terrain-only chunks, but wrong where a WMO sits on the chunk: the building
supplies its own floor/walls through the opening, so the hole is both safe and
REQUIRED.  Flattening those sealed the md_flamegate_e / md_flamegate_f
passages with solid ground and buried the base of firelands_druidtree_stage01.

Restores the source uint16 at MCNK+0x3C for covered chunks only.  Size
preserving (2-byte in-place edit), so every MHDR offset and all 256 MCIN
pointers stay valid.  0x3E and the 0x78/0x7C hi-res words are left as-is.
"""
import struct, os, sys, glob

SRCDIR = 'K:/Dark-Chaos/retailextracts/dc_moltenfront_861/src/World/Maps/FirelandsDailies/'
WORK   = 'K:/tmp/adtwork/'
TILE   = 533.33333
CH     = TILE / 16.0
DRY    = '--apply' not in sys.argv
VMARGIN = 25.0   # yards of slack on the WMO's vertical extent

def walk(d):
    o = 0
    while o + 8 <= len(d):
        tag = d[o:o+4][::-1]
        size = struct.unpack_from('<I', d, o+4)[0]
        yield tag, o+8, size
        o += 8 + size

def wmo_boxes(d):
    names, boxes = [], []
    for tag, off, size in walk(d):
        if tag == b'MWMO':
            names = [x.decode('ascii','replace') for x in d[off:off+size].split(b'\0') if x]
        elif tag == b'MODF':
            for i in range(size // 64):
                b = off + i*64
                minx, miny, minz, maxx, maxy, maxz = struct.unpack_from('<6f', d, b+32)
                boxes.append((minx, maxx, minz, maxz, miny, maxy))
    return names, boxes

def mcnk_index(d):
    out = {}
    for tag, off, size in walk(d):
        if tag == b'MCNK' and size >= 0x80:
            fl, ix, iy = struct.unpack_from('<3I', d, off)
            out[(ix, iy)] = off
    return out

def src_holes(tx, ty):
    p = SRCDIR + 'FirelandsDailies_%d_%d.adt' % (tx, ty)
    if not os.path.exists(p):
        return {}
    d = open(p, 'rb').read()
    g = {}
    for tag, off, size in walk(d):
        if tag == b'MCNK' and size >= 0x80:
            fl, ix, iy = struct.unpack_from('<3I', d, off)
            g[(ix, iy)] = struct.unpack_from('<H', d, off+0x3C)[0]
    return g

# every WMO footprint on the map, gathered first (a WMO overlaps several tiles)
all_boxes = []
for f in sorted(glob.glob(WORK + '*.adt')):
    all_boxes += wmo_boxes(open(f, 'rb').read())[1]
print('WMO placements (all tiles, with duplicates): %d' % len(all_boxes))

total_restored = 0
files_touched = 0
for f in sorted(glob.glob(WORK + '*.adt')):
    base = os.path.basename(f)
    tx, ty = [int(v) for v in base.replace('.adt','').split('_')[-2:]]
    d = bytearray(open(f, 'rb').read())
    idx = mcnk_index(d)
    if len(idx) != 256:
        print('  !! %s has %d MCNKs -- skipped' % (base, len(idx)))
        continue
    sh = src_holes(tx, ty)
    restored = 0
    for (ix, iy), off in idx.items():
        want = sh.get((ix, iy), 0)
        if not want:
            continue
        cx0 = tx*TILE + ix*CH; cz0 = ty*TILE + iy*CH
        ccx = cx0 + CH/2.0;    ccz = cz0 + CH/2.0
        # chunk base height (MCNK header position.z at +0x68 -> +0x70)
        ch_h = struct.unpack_from('<f', d, off+0x70)[0]
        # Vertical test as well as horizontal: a WMO whose vertical extent does
        # not reach this chunk's ground (a platform hanging far overhead, say)
        # is not the thing the hole was punched for, so leave that hole closed.
        covered = any(bx0 <= ccx <= bx1 and bz0 <= ccz <= bz1
                      and (by0 - VMARGIN) <= ch_h <= (by1 + VMARGIN)
                      for bx0, bx1, bz0, bz1, by0, by1 in all_boxes)
        if not covered:
            continue
        cur = struct.unpack_from('<H', d, off+0x3C)[0]
        if cur == want:
            continue
        struct.pack_into('<H', d, off+0x3C, want)
        restored += 1
    if restored:
        files_touched += 1
        total_restored += restored
        if not DRY:
            open(f, 'wb').write(bytes(d))
        print('  %s: restored %d chunk holes' % (base, restored))
print('%s %d chunks across %d tiles' % ('WOULD RESTORE' if DRY else 'RESTORED', total_restored, files_touched))
