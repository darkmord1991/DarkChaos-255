#!/usr/bin/env python3
"""Stage the client assets the new worldforged display rows need.

Reads the generator's output (ItemDisplayInfo.rows.json + .usage.json, GameObjectDisplayInfo.rows.json),
works out every file each display makes the 3.3.5 client open, checks DC's live client for it and takes
whatever is missing from the Ascension client (whose models are already MD20 v264 / BLP2). Every M2 taken
from Ascension is followed to its own dependencies - skins, external .anim files, hardcoded textures -
until nothing new turns up.

Output: <work>/assets_stage/<in-archive path> (ready for retroport_tools/dc_mpq_deploy.py --stage) and
<work>/assets_report.json. Nothing is written to any client.

Usage: python stage_assets.py --work K:/tmp/worldforged_build [--write]
"""
import argparse
import json
import struct
from collections import Counter
from pathlib import Path

from mpqset import MpqSet, client_archives

DC_DATA = Path(r"K:/WoW_3.3.5a_ 255 Fun/Data")
ASC_DATA = Path(r"K:/UntouchedClients/ascension_live/Data")

REGIONS = ["ArmUpperTexture", "ArmLowerTexture", "HandTexture", "TorsoUpperTexture", "TorsoLowerTexture",
           "LegUpperTexture", "LegLowerTexture", "FootTexture"]
# 3.3.5 helm models are one file per race and gender; take every variant the source has.
HELM_SUFFIXES = [r + g for r in ("Hu", "Or", "Dw", "Ni", "Sc", "Ta", "Gn", "Tr", "Be", "Dr", "Go", "Wo", "Pa",
                                 "Br", "Fo", "Na", "Vu", "Kt", "Za", "Ea", "Ma", "Di")
                 for g in ("M", "F")]
WEAPON_SLOTS = {13, 15, 17, 21, 22, 23, 25, 26}


def stem(model):
    return model.rsplit(".", 1)[0] if "." in model.rsplit("\\", 1)[-1] else model


def display_requirements(row, inv_types):
    """[(label, [alternative names])] - a slot is met when any alternative exists; every existing
    alternative is shipped (all helm races, both body-texture genders)."""
    _id, m1, m2, t1, t2, icon1 = row[0], row[1], row[2], row[3], row[4], row[5]
    req = []
    if icon1:
        req.append(("icon", [f"Interface\\Icons\\{icon1}.blp"]))
    inv = set(inv_types)
    if inv & {1}:
        if m1:
            req.append(("helm model", [f"Item\\ObjectComponents\\Head\\{stem(m1)}_{s}.m2" for s in HELM_SUFFIXES]))
        if t1:
            req.append(("helm texture", [f"Item\\ObjectComponents\\Head\\{t1}.blp"]))
    if inv & {3}:
        for model, tex in ((m1, t1), (m2, t2)):
            if model:
                req.append(("shoulder model", [f"Item\\ObjectComponents\\Shoulder\\{stem(model)}.m2"]))
            if tex:
                req.append(("shoulder texture", [f"Item\\ObjectComponents\\Shoulder\\{tex}.blp"]))
    if inv & {16} and t1:
        req.append(("cape texture", [f"Item\\ObjectComponents\\Cape\\{t1}.blp"]))
    for folder, slots in (("Shield", {14}), ("Weapon", WEAPON_SLOTS)):
        if inv & slots:
            for model, tex in ((m1, t1), (m2, t2)):
                if model:
                    req.append((f"{folder.lower()} model", [f"Item\\ObjectComponents\\{folder}\\{stem(model)}.m2"]))
                if tex:
                    req.append((f"{folder.lower()} texture", [f"Item\\ObjectComponents\\{folder}\\{tex}.blp"]))
    for region, tex in zip(REGIONS, row[15:23]):
        if tex:
            base = f"Item\\TextureComponents\\{region}\\{tex}"
            req.append(("body texture", [f"{base}_U.blp", f"{base}_M.blp", f"{base}_F.blp"]))
    return req


def m2_dependencies(name, data):
    """(problems, [dependency names]) for an MD20 model: skins, external animations, hardcoded textures."""
    if data[:4] != b"MD20":
        return [f"{name}: not MD20 ({data[:4]!r}) - needs a wxl-baker pass"], []
    version, = struct.unpack_from("<I", data, 4)
    if version != 264:
        return [f"{name}: M2 version {version}, the 3.3.5 client reads 264"], []
    problems = []
    flags, = struct.unpack_from("<I", data, 0x10)
    if flags & 0x8:
        problems.append(f"{name}: globalFlags 0x8 (texture combiner combos) - WXL's sanitizer covers overflow")
    base = name[:-3]
    deps = []
    n_views, = struct.unpack_from("<I", data, 0x44)
    deps += [f"{base}{i:02d}.skin" for i in range(n_views)]
    n_anim, ofs_anim = struct.unpack_from("<II", data, 0x1C)
    for i in range(n_anim):
        anim_id, sub_id = struct.unpack_from("<HH", data, ofs_anim + i * 64)
        aflags, = struct.unpack_from("<I", data, ofs_anim + i * 64 + 12)
        if not aflags & 0x20 and not aflags & 0x40:
            deps.append(f"{base}{anim_id:04d}-{sub_id:02d}.anim")
    n_tex, ofs_tex = struct.unpack_from("<II", data, 0x50)
    for i in range(n_tex):
        ttype, _tflags, nlen, nofs = struct.unpack_from("<4I", data, ofs_tex + i * 16)
        if ttype == 0 and nlen > 1:
            tex = data[nofs:nofs + nlen].split(b"\0")[0].decode("ascii", "replace")
            if tex:
                deps.append(tex)
    return problems, deps


def fix_blp_mip_flag(data):
    """BLP2 byte 11 must be 0 or 1. Later tools store other values there, which the 3.3.5 renderer rejects
    (solid green); the mip offset/size tables are already right, so the flag is rewritten from the size
    table at header+84."""
    if data[:4] != b"BLP2" or data[11] in (0, 1):
        return data
    sizes = struct.unpack_from("<16I", data, 84)
    out = bytearray(data)
    out[11] = 1 if sum(1 for s in sizes if s) > 1 else 0
    return bytes(out)


def blp_problems(name, data):
    if data[:4] != b"BLP2":
        return [f"{name}: not BLP2 ({data[:4]!r})"]
    encoding, _alpha_depth, _alpha_enc, has_mips = data[8], data[9], data[10], data[11]
    out = []
    if has_mips not in (0, 1):
        out.append(f"{name}: hasMips={has_mips} (the 3.3.5 renderer shows it green)")
    if encoding not in (1, 2, 3):
        out.append(f"{name}: unknown colour encoding {encoding}")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, required=True)
    ap.add_argument("--write", action="store_true", help="write the staged files")
    a = ap.parse_args()
    idi_rows = json.loads((a.work / "ItemDisplayInfo.rows.json").read_text(encoding="utf-8"))
    usage = {int(k): v for k, v in json.loads((a.work / "ItemDisplayInfo.usage.json").read_text()).items()}
    godi_rows = json.loads((a.work / "GameObjectDisplayInfo.rows.json").read_text(encoding="utf-8"))

    dc = MpqSet(client_archives(DC_DATA, "enGB"))
    asc = MpqSet(client_archives(ASC_DATA, "enUS"))
    in_dc, in_asc = {}, {}

    def have_dc(name):
        if name not in in_dc:
            in_dc[name] = bool(dc.where(name))
        return in_dc[name]

    def have_asc(name):
        if name not in in_asc:
            in_asc[name] = bool(asc.where(name))
        return in_asc[name]

    take, unresolved, problems = set(), [], []
    slots = Counter()
    for row in idi_rows:
        for label, alts in display_requirements(row, usage.get(row[0], [])):
            found_dc = [n for n in alts if have_dc(n)]
            found_asc = [n for n in alts if n not in found_dc and have_asc(n)]
            if not found_dc and not found_asc:
                unresolved.append((f"ItemDisplayInfo {row[0]}", label, alts[0]))
                continue
            slots[f"{label}: {'DC' if found_dc and not found_asc else 'Ascension'}"] += 1
            take.update(found_asc)
    for row in godi_rows:
        model = stem(row[1]) + ".m2"
        if have_dc(model):
            slots["GO model: DC"] += 1
        elif have_asc(model):
            slots["GO model: Ascension"] += 1
            take.add(model)
        else:
            unresolved.append((f"GameObjectDisplayInfo {row[0]}", "GO model", model))

    staged, shadowed = {}, []
    queue = sorted(take)
    while queue:
        name = queue.pop()
        if name.lower() in staged:
            continue
        src, data = asc.read(name)
        if data is None:
            unresolved.append(("dependency", "file", name))
            continue
        staged[name.lower()] = (name, src, data)
        low = name.lower()
        if low.endswith(".m2"):
            p, deps = m2_dependencies(name, data)
            problems += p
            for dep in deps:
                if dep.lower() in staged:
                    continue
                # A model's skins and animations must come from the same source as the model: an Ascension
                # .m2 paired with a same-named DC .skin is the texture-combiner overflow crash class.
                paired = dep.lower().endswith((".skin", ".anim"))
                if not paired and have_dc(dep):
                    continue
                if have_asc(dep):
                    queue.append(dep)
                    if paired and have_dc(dep):
                        shadowed.append(dep)
                elif not dep.lower().endswith(".anim"):
                    unresolved.append((name, "dependency", dep))
        elif low.endswith(".blp"):
            fixed = fix_blp_mip_flag(data)
            if fixed is not data:
                problems.append(f"{name}: hasMips={data[11]} normalised to {fixed[11]}")
                staged[low] = (name, src, fixed)
            problems += blp_problems(name, fixed)
        elif low.endswith(".skin") and data[:4] != b"SKIN":
            problems.append(f"{name}: not a SKIN file")

    kinds = Counter(n.rsplit(".", 1)[-1] for n in staged)
    total = sum(len(d) for _n, _s, d in staged.values())
    print("slots:", dict(sorted(slots.items())))
    print(f"files to take from Ascension: {len(staged)} ({total / 1048576:.1f} MB) {dict(kinds)}")
    print(f"skins/anims that replace a same-named DC file (to stay paired with their model): {len(shadowed)}")
    for s in shadowed[:20]:
        print("  ", s, "DC copy in:", [p.name for p in dc.where(s)])
    print(f"unresolved: {len(unresolved)}")
    for u in unresolved[:40]:
        print("  ", u)
    print(f"problems: {len(problems)}")
    for p in problems[:40]:
        print("  ", p)
    report = {"slots": slots, "staged": sorted(n for n, _s, _d in staged.values()), "unresolved": unresolved,
              "problems": problems, "shadowed": shadowed,
              "source_archives": Counter(s.name for _n, s, _d in staged.values())}
    (a.work / "assets_report.json").write_text(json.dumps(report, indent=1, default=str), encoding="utf-8")
    if a.write:
        root = a.work / "assets_stage"
        for name, _src, data in staged.values():
            dst = root / Path(*name.split("\\"))
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
        print("staged under", root)
    dc.close()
    asc.close()


if __name__ == "__main__":
    main()
