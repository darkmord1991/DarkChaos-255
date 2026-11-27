#!/usr/bin/env python3
"""Give map 751's Undercity (undercity751.wmo) an interior minimap that matches its groups.

WHY, IN ONE LINE: the clone's minimap entries were copied from STOCK Undercity, but the clone
is a 216-group retail bake whose groups are numbered in REVERSE (clone i ~ retail 213 - i), so
every group drew another group's tiles -- black floors with misplaced green fragments.

HOW THE CLIENT FINDS A TILE (see memory wmo-minimap-client-mode-rules)
    key = "<MWMO path minus 'World\\'>_<group:03>_<x:02>_<y:02>.blp" looked up in
    textures\\Minimap\\md5translate.trs; the tile grid is laid out from the GROUP'S BOUNDING BOX
    (128 units per 256 px, the last tile shrunk to a power of two). So a tile set only fits the
    group it was cut for, positioned by THAT group's bbox.

WHAT THIS DOES
  1. Maps every clone group to its retail twin by bounding box (one-to-one, nearest first).
  2. Sets each interior group's bbox -- root MOGI and the group file's MOGP header -- to retail's
     exact floats. The bake had rounded them outward by up to a unit, and on 17 groups that
     pushed a span across a power-of-two step, so the client would have stretched a 32 px tile
     over a 64 px cell. With retail's own numbers the client computes the grid retail's tiles
     were cut for. The geometry is retail's, so the exact bbox still bounds it.
  3. Points each interior group at retail's tiles. Where 12.0.7 pruned a group's tiles, it falls
     back to the stock 3.3.5 group with the same bbox (those files already ship in the client).
  4. Rebuilds the "dir: WMO\\dc\\undercity751" block of the LIVE trs (both separator styles, as
     before) and stages the new tile files under their md5 names.

751 only: map 0 keeps world/wmo/lorderon/undercity/undercity.wmo and its stock block.
Writes a staging tree; deploy with retroport_tools/dc_mpq_deploy.py, then re-extract the map-751
vmaps (group bounds are stored in the .vmo).
"""
import collections, glob, hashlib, os, re, shutil, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from upgrade_undercity751_forever import build, chunks, get, group_parts, put  # noqa: E402

WORK = r"K:/tmp/_uc751_minimap"
PREV_STAGE = r"K:/Dark-Chaos/retailextracts/_stage_undercity751_hd/World/wmo/dc/undercity751"
LIVE_GROUPS = r"K:/tmp/_uc751_forever/live751"
STAGE = r"K:/Dark-Chaos/retailextracts/_stage_undercity751_minimap"
OUT_WMO = os.path.join(STAGE, "World", "wmo", "dc", "undercity751")
OUT_MINI = os.path.join(STAGE, "textures", "Minimap")
BASE = "undercity751"
BS = chr(92)
CRLF = chr(13) + chr(10)
CLONE_DIR = "dir: WMO" + BS + "dc" + BS + "undercity751"
STOCK_DIR = "dir: WMO" + BS + "Lorderon" + BS + "Undercity"
GF_INTERIOR = 0x2000
MATCH_LIMIT = 20.0          # summed |bbox delta| over 6 floats; real twins are < 8
STOCK_LIMIT = 6.0


def mogi(root):
    d = get(root, "MOGI")
    return [(struct.unpack_from("<I", d, i * 32)[0], struct.unpack_from("<6f", d, i * 32 + 4))
            for i in range(len(d) // 32)]


def dist(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def one_to_one(src, dst, limit):
    pairs = sorted((dist(a[1], b[1]), i, j) for i, a in enumerate(src) for j, b in enumerate(dst))
    out, used = {}, set()
    for d, i, j in pairs:
        if d <= limit and i not in out and j not in used:
            out[i] = j
            used.add(j)
    return out


def trs_lines():
    raw = open(os.path.join(WORK, "live_trs", "md5translate.trs"), "rb").read()
    assert raw.count(b"\r\r") == 0, "live trs carries CR CR LF"
    return raw.decode("latin1").replace(CRLF, "\n").split("\n")


def block(lines, header):
    s = lines.index(header)
    e = s + 1
    while e < len(lines) and lines[e] and not lines[e].startswith("dir: "):
        e += 1
    return s, e


def main():
    for d in (OUT_WMO, OUT_MINI):
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)

    root = chunks(open(os.path.join(PREV_STAGE, BASE + ".wmo"), "rb").read())
    retail = chunks(open(os.path.join(WORK, "retail_root.wmo"), "rb").read())
    stock = chunks(open(os.path.join(WORK, "stock_root.wmo"), "rb").read())
    cg, rg, sg = mogi(root), mogi(retail), mogi(stock)
    to_retail = one_to_one(cg, rg, MATCH_LIMIT)
    retail_to_stock = one_to_one(rg, sg, STOCK_LIMIT)

    # retail tiles on disk (present in 12.0.7) and the ones the listfile says should exist
    present = collections.defaultdict(dict)
    for p in glob.glob(os.path.join(WORK, "retail", "**", "*.blp"), recursive=True):
        m = re.search(r"undercity_(\d+)_(\d+)_(\d+)\.blp$", p.lower())
        present[int(m.group(1))][(int(m.group(2)), int(m.group(3)))] = p
    listed = collections.defaultdict(set)
    for line in open(os.path.join(WORK, "retail_tile_names.txt")):
        m = re.search(r"undercity_(\d+)_(\d+)_(\d+)", line.lower())
        listed[int(m.group(1))].add((int(m.group(2)), int(m.group(3))))

    lines = trs_lines()
    ss, se = block(lines, STOCK_DIR)
    stock_tiles = collections.defaultdict(dict)
    for l in lines[ss + 1:se]:
        name, target = l.split(chr(9), 1)
        m = re.search(r"Undercity_(\d+)_(\d+)_(\d+)\.blp$", name)
        stock_tiles[int(m.group(1))][(int(m.group(2)), int(m.group(3)))] = target

    # 1-3: choose tiles per interior clone group, fix its bbox
    entries = {}                                       # (group, x, y) -> right side
    new_files = {}                                     # md5 name -> source path
    patched = {}                                       # clone group -> exact retail bbox
    report = collections.Counter()
    uncovered = []
    for i, (flags, _) in enumerate(cg):
        if not flags & GF_INTERIOR:
            continue
        j = to_retail.get(i)
        if j is None:
            uncovered.append((i, "no retail twin"))
            continue
        complete = j in present and listed[j] <= set(present[j])
        k = retail_to_stock.get(j)
        if complete:
            for (x, y), p in present[j].items():
                md5 = hashlib.md5(open(p, "rb").read()).hexdigest() + ".blp"
                new_files[md5] = p
                entries[(i, x, y)] = md5
            report["retail"] += 1
        elif k is not None and k in stock_tiles:
            entries.update({(i, x, y): t for (x, y), t in stock_tiles[k].items()})
            report["stock fallback"] += 1
        elif j in present:
            for (x, y), p in present[j].items():
                md5 = hashlib.md5(open(p, "rb").read()).hexdigest() + ".blp"
                new_files[md5] = p
                entries[(i, x, y)] = md5
            report["retail partial"] += 1
        else:
            uncovered.append((i, "retail %d has no tiles" % j))
            continue
        if dist(cg[i][1], rg[j][1]) > 1e-4:
            patched[i] = rg[j][1]

    # root MOGI bbox
    mg = bytearray(get(root, "MOGI"))
    for i, bb in patched.items():
        struct.pack_into("<6f", mg, i * 32 + 4, *bb)
    put(root, "MOGI", bytes(mg))
    open(os.path.join(OUT_WMO, BASE + ".wmo"), "wb").write(build(root))

    # group MOGP header bbox (offset 12 into the MOGP payload)
    for i, bb in sorted(patched.items()):
        src = os.path.join(PREV_STAGE, "%s_%03d.wmo" % (BASE, i))
        if not os.path.exists(src):
            src = os.path.join(LIVE_GROUPS, "%s_%03d.wmo" % (BASE, i))
        ver, hdr, subs = group_parts(open(src, "rb").read())
        struct.pack_into("<6f", hdr, 12, *bb)
        open(os.path.join(OUT_WMO, "%s_%03d.wmo" % (BASE, i)), "wb").write(
            build([["MVER", ver], ["MOGP", bytes(hdr) + build(subs)]]))

    # 4: rebuild the clone's trs block from the live file
    cs, ce = block(lines, CLONE_DIR)
    styles = (BS.join(["WMO", "dc", "undercity751", "Undercity751"]), "/".join(["WMO", "dc", "undercity751", "Undercity751"]))
    body = []
    for pfx in styles:
        for (g, x, y) in sorted(entries):
            right = entries[(g, x, y)]
            assert len(right) <= 39, "trs right side over 39 chars: %s" % right
            body.append("%s_%03d_%02d_%02d.blp%s%s" % (pfx, g, x, y, chr(9), right))
    out = lines[:cs + 1] + body + lines[ce:]
    open(os.path.join(OUT_MINI, "md5translate.trs"), "wb").write(CRLF.join(out).encode("latin1"))
    for md5, p in new_files.items():
        shutil.copyfile(p, os.path.join(OUT_MINI, md5))

    print("interior groups: %s; uncovered %d %s" % (dict(report), len(uncovered), uncovered))
    print("bbox set to retail's on %d groups (root MOGI + group files)" % len(patched))
    print("trs block %s: %d -> %d lines; %d new tile files staged"
          % (CLONE_DIR, ce - cs - 1, len(body), len(new_files)))
    print("staged -> %s" % STAGE)


if __name__ == "__main__":
    main()
