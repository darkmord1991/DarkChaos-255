#!/usr/bin/env python3
"""Bring map 751's private Undercity (undercity751.wmo) up to the WoW Forever / retail look.

WHY, IN ONE LINE: 751 already renders the remodeled Undercity top that WoW Forever shows --
what it lacks is Forever's 1024x1024 textures (ours are 256x256) and 138 of its doodads.

WHAT WAS FOUND (2026-10-04)
    WoW Forever (CDN product wow_classic_beta, 1.60.1.70205) swaps undercity.wmo for FDID
    7675285 at the identical placement. That model is retail's current undercity.wmo (FDID
    114612) re-shipped: same 216 groups, 215/216 group bboxes equal, identical texture set,
    Forever's 2,244 doodads a subset of retail's 2,250.
    Map 751 already places world/wmo/dc/undercity751/undercity751.wmo (wmoID 66901), the
    2026-08-21 clone of patch-9's 216-group bake of that same retail model
    (clone_undercity_wmo_751.py). Geometry above AND below ground therefore already matches.
    The visible gaps are:
      * 80 of the 82 textures are 1024x1024 DXT in Forever vs 256x256 in our client.
      * 138 doodads in Forever are absent from our copy (101 above ground), every model of
        which already ships in the client.
      * 5 of our doodads name "...MEATWAGONHAULER.MDX\\MEATWAGONHAULER.MDX" and never load.

WHAT THIS CHANGES -- map 751 only
    * HD textures are written under world/wmo/dc/undercity751/hd/ and only the clone's MOTX
      gains those paths (appended; the old strings stay, so no other offset moves). The
      shared stock texture paths are untouched, so map 0's Undercity and every other WMO
      that shares a texture keep exactly what they render today.
    * Missing doodads are appended to MODN/MODD and the single doodad set grows to cover
      them. Each one is referenced from the group(s) Forever references it from (groups
      matched by bounding box, because the bake re-ordered them), falling back to the
      smallest group whose bbox contains it.
    * Broken doodad names are repointed: to the Forever model standing at the same spot
      when there is one, otherwise to the de-duplicated path.

FOUR THINGS THAT WOULD EACH BREAK IT SILENTLY
  1. A DOODAD THAT NO GROUP REFERENCES IS NEVER DRAWN. Appending to MODD is not enough --
     the group's MODR must list it, and the group must carry flag 0x800.
  2. GROUP SUBCHUNK ORDER IS FIXED. The 3.3.5 client walks optional subchunks in flag order
     (MOLR, MODR, MOBN/MOBR, ..., MOCV, MLIQ). A new MODR goes right after MOLR, or after
     MOBA when the group has no lights -- never appended at the end.
  3. AN ALPHA CHANNEL CAN DISAPPEAR. If our texture has alpha and Forever's does not, a
     cut-out material would turn opaque; such a texture is only upgraded when every material
     using it is opaque (blendMode 0).
  4. DOODAD COLOURS ARE NOT COPIED RAW. The bake that produced our copy stored each MODD
     colour as the retail colour PLUS the root ambient (MOHD ambColor, BGR 49/31/30): every
     doodad of the courtyard group follows it exactly (50/50). A raw copy would make the new
     doodads visibly darker than their neighbours, so the same offset is applied here.
     Retail's MODD flags are all 0x10; our bake writes 0 -- only the low nibble is kept.

INPUTS (K:/tmp/_uc751_forever, fetched with tools/forever_probe.js from the CDN and
mpq_stormlib_extract.py from the live client): forever/root_7675285.wmo, forever/groups/
fv_NNN.wmo (LOD0, GFID order), forever/tex/<fdid>.blp + tex_fdids.tsv, live751/ (the
deployed clone from patch-9), ours_tex/ (the 256 copies the client loads today).

Writes a staging tree only; deploy with retroport_tools/dc_mpq_deploy.py. The server's
map-751 vmaps must be re-extracted afterwards (the new doodads carry collision).
"""
import os, struct, shutil, collections

WORK = r"K:/tmp/_uc751_forever"
LISTFILE = r"K:/Dark-Chaos/wow.export-main/tools/.casc-cache/community-listfile.csv"
STAGE = r"K:/Dark-Chaos/retailextracts/_stage_undercity751_hd"
OUT_DIR = os.path.join(STAGE, "World", "wmo", "dc", "undercity751")
BASE = "undercity751"
HD_PREFIX = "WORLD\\WMO\\DC\\UNDERCITY751\\HD\\"
NGROUPS = 216
BS = chr(92)

GF_HAS_LIGHTS, GF_HAS_DOODADS = 0x200, 0x800
OPTIONAL_ORDER = ["MOLR", "MODR", "MOBN", "MOBR", "MPBV", "MPBP", "MPBI", "MPBG", "MOCV",
                  "MLIQ", "MORI", "MORB", "MOTV", "MOCV"]


def chunks(b):
    out, o = [], 0
    while o + 8 <= len(b):
        tag = b[o:o + 4][::-1].decode("ascii")
        sz = struct.unpack_from("<I", b, o + 4)[0]
        out.append([tag, bytes(b[o + 8:o + 8 + sz])])
        o += 8 + sz
    assert o == len(b), "trailing bytes after chunk walk (%d != %d)" % (o, len(b))
    return out


def build(lst):
    return b"".join(t.encode("ascii")[::-1] + struct.pack("<I", len(d)) + d for t, d in lst)


def get(lst, tag):
    hit = [d for t, d in lst if t == tag]
    assert len(hit) == 1, "expected one %s, found %d" % (tag, len(hit))
    return hit[0]


def put(lst, tag, data):
    for c in lst:
        if c[0] == tag:
            c[1] = data
            return
    raise KeyError(tag)


def cstr(blob, o):
    return blob[o:blob.index(b"\0", o)].decode("latin1")


def norm(name):
    n = name.lower().replace(BS, "/")
    return n[:-4] + ".m2" if n.endswith(".mdx") else n


def to_modn(path):
    """Listfile path -> the clone's MODN convention (upper case, backslashes, .MDX)."""
    p = path.replace("/", BS).upper()
    return p[:-3] + ".MDX" if p.endswith(".M2") else p


def blp_header(path):
    b = open(path, "rb").read(20)
    assert b[:4] == b"BLP2", path
    return dict(enc=b[8], alpha=b[9], alpha_enc=b[10], mips=b[11], w=struct.unpack_from("<I", b, 12)[0],
                h=struct.unpack_from("<I", b, 16)[0])


def load_listfile():
    names = {}
    for line in open(LISTFILE, encoding="utf-8", errors="replace"):
        i = line.find(";")
        if i > 0:
            try:
                names[int(line[:i])] = line[i + 1:].strip()
            except ValueError:
                pass
    return names


def mogi_boxes(root):
    mogi = get(root, "MOGI")
    return [struct.unpack_from("<6f", mogi, i * 32 + 4) for i in range(len(mogi) // 32)]


def modd_entries(modd):
    out = []
    for i in range(len(modd) // 40):
        raw = struct.unpack_from("<I", modd, i * 40)[0]
        out.append(dict(name_idx=raw & 0xFFFFFF, flags=raw >> 24,
                        pos=struct.unpack_from("<3f", modd, i * 40 + 4),
                        rest=modd[i * 40 + 16:i * 40 + 40]))   # rotation(4f) + scale + color
    return out


def group_parts(gbytes):
    top = chunks(gbytes)
    assert [t for t, _ in top] == ["MVER", "MOGP"], [t for t, _ in top]
    mogp = top[1][1]
    return top[0][1], bytearray(mogp[:0x44]), chunks(mogp[0x44:])


def group_modr(gbytes):
    _, _, subs = group_parts(gbytes)
    for t, d in subs:
        if t == "MODR":
            return list(struct.unpack("<%dH" % (len(d) // 2), d))
    return []


def add_modr(gbytes, idx):
    ver, hdr, subs = group_parts(gbytes)
    flags = struct.unpack_from("<I", hdr, 8)[0]
    tags = [t for t, _ in subs]
    if "MODR" in tags:
        assert flags & GF_HAS_DOODADS
        k = tags.index("MODR")
        cur = list(struct.unpack("<%dH" % (len(subs[k][1]) // 2), subs[k][1]))
        cur += [i for i in idx if i not in cur]
        subs[k][1] = struct.pack("<%dH" % len(cur), *cur)
    else:
        assert not flags & GF_HAS_DOODADS
        anchor = "MOLR" if "MOLR" in tags else "MOBA"
        assert anchor != "MOLR" or flags & GF_HAS_LIGHTS
        subs.insert(tags.index(anchor) + 1, ["MODR", struct.pack("<%dH" % len(idx), *idx)])
        struct.pack_into("<I", hdr, 8, flags | GF_HAS_DOODADS)
    tags = [t for t, _ in subs]
    assert tags.index("MODR") < tags.index("MOBN") if "MOBN" in tags else True, tags
    return build([["MVER", ver], ["MOGP", bytes(hdr) + build(subs)]])


def upgrade_textures(root):
    motx = get(root, "MOTX")
    momt = bytearray(get(root, "MOMT"))
    starts = {0} | {i + 1 for i in range(len(motx) - 1) if motx[i] == 0 and motx[i + 1] != 0}
    fv = {}
    for line in open(os.path.join(WORK, "forever", "tex_fdids.tsv")):
        fid, name = line.rstrip("\n").split("\t")
        fv[name.lower()] = os.path.join(WORK, "forever", "tex", fid + ".blp")

    users = collections.defaultdict(list)                  # MOTX offset -> [(material, blendMode)]
    for m in range(len(momt) // 64):
        blend = struct.unpack_from("<I", momt, m * 64 + 8)[0]
        for f in (12, 24):
            v = struct.unpack_from("<I", momt, m * 64 + f)[0]
            if v in starts and motx[v] != 0:
                users[v].append((m, blend))

    newmotx = bytearray(motx)
    remap, copied, skipped = {}, [], []
    for off in sorted(users):
        name = cstr(motx, off)
        src = fv.get(norm(name))
        if not src:
            continue
        mine = os.path.join(WORK, "ours_tex", os.path.basename(norm(name)))
        a, b = blp_header(src), blp_header(mine)
        assert a["enc"] == 2 and a["mips"] in (0, 1), "Forever BLP not 3.3.5-safe: %s %s" % (name, a)
        if a["w"] * a["h"] <= b["w"] * b["h"]:
            continue
        if b["alpha"] and not a["alpha"] and any(bl != 0 for _, bl in users[off]):
            skipped.append(name)
            continue
        base = os.path.basename(norm(name))
        remap[off] = len(newmotx)
        newmotx += (HD_PREFIX + base.upper()).encode("ascii") + b"\0"
        dst = os.path.join(OUT_DIR, "hd", base)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        copied.append((name, "%dx%d -> %dx%d" % (b["w"], b["h"], a["w"], a["h"])))

    for m in range(len(momt) // 64):
        for f in (12, 24):
            v = struct.unpack_from("<I", momt, m * 64 + f)[0]
            if v in remap:
                struct.pack_into("<I", momt, m * 64 + f, remap[v])
    put(root, "MOTX", bytes(newmotx))
    put(root, "MOMT", bytes(momt))
    print("textures: %d upgraded to HD, %d kept (alpha would be lost on a blended material)"
          % (len(copied), len(skipped)))
    for n in skipped:
        print("   kept 256:", n)
    return copied


def add_doodads(root, fv_root, live_groups, fv_groups, listfile):
    modn = bytearray(get(root, "MODN"))
    modd = get(root, "MODD")
    ours = modd_entries(modd)
    name_at = {}
    o = 0
    while o < len(modn):
        if modn[o]:
            s = cstr(modn, o)
            name_at[o] = s
            o += len(s) + 1
        else:
            o += 1
    by_norm = {norm(s): off for off, s in name_at.items() if ".mdx" + BS not in s.lower()}
    appended = []

    def name_offset(path):
        key = norm(path)
        if key not in by_norm:
            while len(modn) % 4:
                modn.append(0)
            by_norm[key] = len(modn)
            appended.append(key)
            modn.extend(to_modn(path).encode("latin1") + b"\0")
        return by_norm[key]

    def near(a, b):
        return all(abs(x - y) <= 1.0 for x, y in zip(a, b))

    modi = get(fv_root, "MODI")
    fv_ids = struct.unpack("<%dI" % (len(modi) // 4), modi)
    fv = modd_entries(get(fv_root, "MODD"))
    for e in fv:
        e["name"] = norm(listfile[fv_ids[e["name_idx"]]])

    have = collections.defaultdict(list)
    for e in ours:
        have[norm(name_at[e["name_idx"]])].append(e["pos"])

    def present(e):
        return any(near(e["pos"], p) for p in have.get(e["name"], ()))

    missing = collections.OrderedDict()                     # dedupe Blizzard's stacked copies
    for i, e in enumerate(fv):
        if not present(e):
            key = (e["name"], tuple(round(v, 1) for v in e["pos"]))
            missing.setdefault(key, []).append(i)

    # 1) broken names: take the Forever model standing at the same spot, else de-duplicate
    newmodd = bytearray(modd)
    fixed = []
    for k, e in enumerate(ours):
        s = name_at[e["name_idx"]]
        if ".mdx" + BS not in s.lower():
            continue
        swap = next((key for key in missing if near(fv[missing[key][0]]["pos"], e["pos"])), None)
        if swap:
            target = listfile[fv_ids[fv[missing.pop(swap)[0]]["name_idx"]]]
        else:
            target = s[:s.lower().index(".mdx") + 4]
        struct.pack_into("<I", newmodd, k * 40, name_offset(target) | (e["flags"] << 24))
        fixed.append((k, norm(target)))

    # 2) Forever group -> our group, by bounding box (the bake re-ordered the groups)
    ob, fb = mogi_boxes(root), mogi_boxes(fv_root)
    gmap = {}
    for j, f in enumerate(fb):
        best = min(range(len(ob)), key=lambda i: sum(abs(x - y) for x, y in zip(ob[i], f)))
        if all(abs(x - y) <= 2.0 for x, y in zip(ob[best], f)):
            gmap[j] = best
    fv_refs = collections.defaultdict(set)
    for j, g in enumerate(fv_groups):
        for d in group_modr(g):
            fv_refs[d].add(j)

    def containing(pos):
        hits = [i for i, b in enumerate(ob) if all(b[a] - 0.5 <= pos[a] <= b[a + 3] + 0.5 for a in range(3))]
        assert hits, "no group contains doodad at %s" % (pos,)
        return min(hits, key=lambda i: (ob[i][3] - ob[i][0]) * (ob[i][4] - ob[i][1]) * (ob[i][5] - ob[i][2]))

    amb = get(root, "MOHD")[28:31]                          # B, G, R of the root ambient
    first_new = len(newmodd) // 40
    refs = collections.defaultdict(list)
    via_forever = via_bbox = 0
    for key, idxs in missing.items():
        e = fv[idxs[0]]
        mine = len(newmodd) // 40
        color = bytes(min(255, e["rest"][20 + c] + amb[c]) for c in range(3)) + e["rest"][23:24]
        newmodd += struct.pack("<I", name_offset(listfile[fv_ids[e["name_idx"]]]) | ((e["flags"] & 0x0F) << 24))
        newmodd += struct.pack("<3f", *e["pos"]) + e["rest"][:20] + color
        groups = {gmap[j] for i in idxs for j in fv_refs.get(i, ()) if j in gmap}
        if groups:
            via_forever += 1
        else:
            groups = {containing(e["pos"])}
            via_bbox += 1
        for g in groups:
            refs[g].append(mine)

    while len(modn) % 4:
        modn.append(0)
    put(root, "MODN", bytes(modn))
    put(root, "MODD", bytes(newmodd))
    mods = bytearray(get(root, "MODS"))
    assert len(mods) == 32 and struct.unpack_from("<II", mods, 20) == (0, len(ours)), "unexpected doodad sets"
    struct.pack_into("<I", mods, 24, len(newmodd) // 40)
    put(root, "MODS", bytes(mods))
    mohd = bytearray(get(root, "MOHD"))
    struct.pack_into("<I", mohd, 16, struct.unpack_from("<I", mohd, 16)[0] + len(appended))
    struct.pack_into("<I", mohd, 20, len(newmodd) // 40)
    put(root, "MOHD", bytes(mohd))

    print("doodads: %d added (%d placed per Forever's own group refs, %d by bbox), %d broken names fixed"
          % (len(newmodd) // 40 - first_new, via_forever, via_bbox, len(fixed)))
    for k, n in fixed:
        print("   MODD %d -> %s" % (k, n))
    print("group map: %d of %d Forever groups matched by bbox" % (len(gmap), len(fb)))

    changed = {}
    for g, idx in refs.items():
        changed[g] = add_modr(live_groups[g], idx)
    return changed, first_new, len(newmodd) // 40


def verify(root_bytes, groups, first_new, total):
    root = chunks(root_bytes)
    mohd = get(root, "MOHD")
    assert struct.unpack_from("<I", mohd, 4)[0] == NGROUPS
    assert struct.unpack_from("<I", mohd, 20)[0] == total == len(get(root, "MODD")) // 40
    motx, modn = get(root, "MOTX"), get(root, "MODN")
    for m in range(len(get(root, "MOMT")) // 64):
        for f in (12, 24):
            v = struct.unpack_from("<I", get(root, "MOMT"), m * 64 + f)[0]
            assert v == 0 or motx[v - 1] == 0, "material %d texture offset %d is mid-string" % (m, v)
    for e in modd_entries(get(root, "MODD")):
        assert e["name_idx"] == 0 or modn[e["name_idx"] - 1] == 0, "doodad name offset mid-string"
        assert cstr(modn, e["name_idx"]).upper().endswith((".MDX", ".M2"))
    seen = set()
    for i in range(NGROUPS):
        ver, hdr, subs = group_parts(groups[i])
        tags = [t for t, _ in subs]
        flags = struct.unpack_from("<I", hdr, 8)[0]
        assert ("MODR" in tags) == bool(flags & GF_HAS_DOODADS), "group %d flag/MODR mismatch" % i
        opt = [t for t in tags[6:]]
        assert opt == sorted(opt, key=lambda t: OPTIONAL_ORDER.index(t)), "group %d order %s" % (i, tags)
        for d in group_modr(groups[i]):
            assert d < total, "group %d references doodad %d of %d" % (i, d, total)
            seen.add(d)
    lost = [d for d in range(first_new, total) if d not in seen]
    assert not lost, "%d new doodads referenced by no group" % len(lost)
    print("verify: root + %d groups OK, all %d new doodads referenced" % (NGROUPS, total - first_new))


def main():
    if os.path.isdir(STAGE):
        shutil.rmtree(STAGE)
    os.makedirs(OUT_DIR)
    listfile = load_listfile()
    root = chunks(open(os.path.join(WORK, "live751", BASE + ".wmo"), "rb").read())
    assert struct.unpack_from("<I", get(root, "MOHD"), 32)[0] == 66901, "not the 751 clone"
    fv_root = chunks(open(os.path.join(WORK, "forever", "root_7675285.wmo"), "rb").read())
    live_groups = [open(os.path.join(WORK, "live751", "%s_%03d.wmo" % (BASE, i)), "rb").read() for i in range(NGROUPS)]
    fv_groups = [open(os.path.join(WORK, "forever", "groups", "fv_%03d.wmo" % i), "rb").read() for i in range(NGROUPS)]

    upgrade_textures(root)
    changed, first_new, total = add_doodads(root, fv_root, live_groups, fv_groups, listfile)
    root_bytes = build(root)
    groups = [changed.get(i, g) for i, g in enumerate(live_groups)]
    verify(root_bytes, groups, first_new, total)

    open(os.path.join(OUT_DIR, BASE + ".wmo"), "wb").write(root_bytes)
    for i in sorted(changed):
        open(os.path.join(OUT_DIR, "%s_%03d.wmo" % (BASE, i)), "wb").write(changed[i])
    print("staged: root + %d changed groups + HD textures -> %s" % (len(changed), STAGE))


if __name__ == "__main__":
    main()
