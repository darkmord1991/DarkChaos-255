#!/usr/bin/env python3
"""Bake the DC-Collection mount previews for the STOCK (blizzlike) mounts and emit
Data/MountModelPathsStock.lua.

Why this exists
---------------
`generate_mount_model_paths.py` only ever emits the CUSTOM display band (>= 500000), so all
273 blizzlike mounts in the DC Collection catalog previewed BLANK: the preview widget is a
DressUpModel with no SetDisplayInfo on this client, the server's creature entries are not
shipped, and no MountModelPaths entry existed -- nothing left to render with.

Two things had to be solved:

1. WHICH MODEL.  `dc_mount_definitions.display_id` is wrong for every stock mount: it holds a
   RETAIL-era CreatureDisplayInfo id (Flying Broom = 56954, Brewfest Kodo = 29447, Great Elite
   Elekk = 39654), none of which are 3.3.5 rows, and many mounts share one (all five horse
   bridles = 13108). The real chain is
       Spell.dbc  EffectAura == 78 (SPELL_AURA_MOUNTED)  ->  EffectMiscValue = mount creature entry
       creature_template_model.CreatureDisplayID                              -> 3.3.5 display id
       CreatureDisplayInfo.ModelID -> CreatureModelData.ModelName             -> the stock .m2
   The middle hop needs the world DB, so it is cached in tools/data/stock_mount_entry_displays.json
   (regeneration query is in that file's own comment).

2. WHY IT WOULD BE WHITE.  A stock mount's body skin lives in MONSTER texture slots (type
   11/12/13) whose name is empty -- the client fills them from CreatureDisplayInfo.TextureVariation
   at runtime, and SetModel() has no display context to do that with. So one preview copy is baked
   PER DISPLAY with that display's TextureVariation written into those slots as plain type-0
   names. The .blp files already ship in the base archives, so nothing but the .m2/.skin is packed.
   numSkinProfiles is forced to 1: only skin00 is shipped, and a model whose nViews exceeds the
   skins actually present HARD-CRASHES the client (uncatchable by pcall).

Output
------
  <preview-out>/<folder>/<Stem>_<displayId>.m2 + <Stem>_<displayId>00.skin
  Custom/Client addons needed/DC-Collection/Data/MountModelPathsStock.lua

The Lua table is keyed by mount SPELL id (unique per mount, and exactly what the server sends as
the collection item's id) rather than by display id, because the stored display ids are the wrong,
colliding values described above. A second table keyed by the REAL display id is emitted too, so
the ordinary display-keyed lookup starts working as well once the DB is corrected.

Usage
-----
  python tools/generate_stock_mount_previews.py --data "K:/WoW_3.3.5a_ 255 Fun/Data" \
      --out K:/Dark-Chaos/retroport_tools/patch_g_staging/mountpreview
  # then deploy with retroport_tools/dc_mpq_deploy.py (routes mountpreview\ -> patch-A)
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import struct
import subprocess
import sys

BS = "\\"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSVDBC = os.path.join(REPO, "Custom", "CSV DBC")
ENTRY_DISPLAYS = os.path.join(REPO, "tools", "data", "stock_mount_entry_displays.json")
LUA_OUT = os.path.join(REPO, "Custom", "Client addons needed", "DC-Collection",
                       "Data", "MountModelPathsStock.lua")
EXTRACTOR = r"K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py"

# Client load order, lowest priority first. A later archive wins, so extracting in this order and
# letting each pass overwrite leaves exactly the file the client itself resolves.
ARCHIVE_ORDER = [
    "common.MPQ", "common-2.MPQ", "expansion.MPQ", "lichking.MPQ", "patch.MPQ",
    "patch-2.MPQ", "patch-3.MPQ", "patch-4.MPQ", "patch-5.MPQ", "patch-6.MPQ", "patch-7.MPQ",
    "patch-8.MPQ", "patch-9.MPQ", "patch-A.MPQ", "patch-B.MPQ", "patch-C.MPQ", "patch-D.MPQ",
    "patch-E.MPQ", "patch-F.MPQ", "patch-G.MPQ", "patch-H.MPQ",
]

MONSTER_SLOT = {11: 0, 12: 1, 13: 2}   # M2 texture type -> TextureVariation index

# Mounts whose spell carries no SPELL_AURA_MOUNTED of its own: 64749/64762 are TRIGGER_SPELL
# wrappers (the Argent Tournament loaner mounts) around 64681/64761, so follow EffectTriggerSpell.
# (Spell 55884 used to need an entry here too -- it is the generic Effect 36 "Learning" spell that
#  every mount item carries as spellid_1, and a scraper had turned it into a duplicate Horn of the
#  Timber Wolf catalog row. That row was deleted on 2026-08-18; see
#  Retroports/2026_08_18_01_dc_mount_catalog_fixes.sql.)
MANUAL_SPELL_DISPLAY = {64749: 17697, 64762: 17699}

CUSTOM_FLOOR = 500000


def load_csv(path):
    with open(path, newline="", encoding="utf-8") as fh:
        rd = csv.reader(fh)
        head = next(rd)
        return [r for r in rd if r], {n: i for i, n in enumerate(head)}


def normalise_model(name: str) -> str:
    """CreatureModelData stores .mdx/.mdl paths; the file on disk is always .m2."""
    p = name.replace("/", BS)
    return p[:-4] + ".m2" if p.lower().endswith((".mdx", ".mdl")) else p


def resolve_chain():
    """spell id -> (display id, model path, [tv1, tv2, tv3]) for every stock mount in the catalog."""
    src_rows, src_ix = load_csv(os.path.join(CSVDBC, "CDBC", "DCCollectionSource.csv"))
    spells = set()
    for row in src_rows:
        try:
            if row[src_ix["CollectionType"]] != "1":
                continue
            if int(row[src_ix["DisplayID"]]) < CUSTOM_FLOOR:
                spells.add(int(row[src_ix["SpellID"]]))
        except (ValueError, IndexError):
            continue

    spell_rows, spell_ix = load_csv(os.path.join(CSVDBC, "Spell.csv"))
    spell2entry = {}
    for row in spell_rows:
        try:
            sid = int(row[0])
        except (ValueError, IndexError):
            continue
        if sid not in spells:
            continue
        for k in (1, 2, 3):
            try:
                aura = int(row[spell_ix["EffectAura_%d" % k]])
            except (ValueError, IndexError):
                continue
            if aura == 78:                                  # SPELL_AURA_MOUNTED
                spell2entry[sid] = int(row[spell_ix["EffectMiscValue_%d" % k]])
                break

    entry2disp = {int(k): v for k, v in
                  json.load(open(ENTRY_DISPLAYS, encoding="utf-8"))["entryToDisplay"].items()}

    cdi_rows, cdi_ix = load_csv(os.path.join(CSVDBC, "CreatureDisplayInfo.csv"))
    cmd_rows, cmd_ix = load_csv(os.path.join(CSVDBC, "CreatureModelData.csv"))
    model_name = {r[cmd_ix["ID"]]: r[cmd_ix["ModelName"]] for r in cmd_rows}
    disp_info = {}
    for row in cdi_rows:
        try:
            disp_info[int(row[cdi_ix["ID"]])] = (
                model_name.get(row[cdi_ix["ModelID"]]),
                [row[cdi_ix["TextureVariation_%d" % k]] for k in (1, 2, 3)],
            )
        except (ValueError, IndexError):
            continue

    out, unresolved = {}, []
    for sid in sorted(spells):
        disp = MANUAL_SPELL_DISPLAY.get(sid)
        if disp is None:
            ent = spell2entry.get(sid)
            disp = entry2disp.get(ent) if ent else None
        info = disp_info.get(disp) if disp else None
        if not info or not info[0]:
            unresolved.append(sid)
            continue
        out[sid] = (disp, normalise_model(info[0]), info[1])
    return out, unresolved


def extract_models(models, data_dir, work_dir):
    """Pull each model's .m2 + skin00 out of the archive chain, honouring load order."""
    wanted = []
    for m in models:
        wanted.append(m)
        wanted.append(m[:-3] + "00.skin")
    os.makedirs(work_dir, exist_ok=True)
    listing = os.path.join(work_dir, "_wanted.txt")
    with open(listing, "w", encoding="utf-8") as fh:
        fh.write("\n".join(wanted) + "\n")
    for arc in ARCHIVE_ORDER:
        path = os.path.join(data_dir, arc)
        if not os.path.exists(path):
            continue
        subprocess.run([sys.executable, EXTRACTOR, "--mpq", path, "--out", work_dir,
                        "--preserve-paths", "--quiet", "--list-file", listing],
                       capture_output=True, text=True)
    missing = [w for w in wanted if not os.path.exists(os.path.join(work_dir, w.replace(BS, os.sep)))]
    return missing


def bake(src_m2, src_skin, tvs, folder, out_m2, out_skin):
    """Write one display's preview copy: MONSTER slots named, numSkinProfiles forced to 1."""
    buf = bytearray(open(src_m2, "rb").read())
    if buf[:4] != b"MD20":
        return None
    n_tex, ofs_tex = struct.unpack_from("<II", buf, 0x50)

    # A slot with no TextureVariation to bind would draw solid white; fall back to the model's own
    # first hard-coded texture so the surface at least takes the model's colours.
    fallback = None
    for i in range(n_tex):
        t, _fl, nlen, noff = struct.unpack_from("<IIII", buf, ofs_tex + i * 16)
        if t == 0 and nlen > 1:
            fallback = buf[noff:noff + nlen].split(b"\0")[0].decode("latin1")
            break

    edits, whites = [], 0
    for i in range(n_tex):
        rec = ofs_tex + i * 16
        t, _fl, nlen, _noff = struct.unpack_from("<IIII", buf, rec)
        if nlen > 1:
            continue                                        # already named -- leave it alone
        var = tvs[MONSTER_SLOT[t]].strip() if t in MONSTER_SLOT else ""
        if var:
            edits.append((rec, BS.join(["Creature", folder, var + ".blp"])))
        elif fallback:
            edits.append((rec, fallback))
            whites += 1
    for rec, name in edits:
        raw = name.encode("latin1") + b"\x00"
        noff = len(buf)
        buf += raw
        struct.pack_into("<IIII", buf, rec, 0, 3, len(raw), noff)   # type 0, wrap both axes
    struct.pack_into("<I", buf, 0x44, 1)                    # numSkinProfiles = 1

    # Particle/ribbon emitters are not ticked in the preview widget, so an additive emitter quad
    # sits in its spawn-frame pose forever and reads as a frozen glowing "box" stuck to the model.
    # Zeroing the counts in the PREVIEW COPY is the same fix the custom mount previews carry; the
    # in-world models keep their full effects.
    struct.pack_into("<I", buf, 0x120, 0)                   # nRibbonEmitters
    struct.pack_into("<I", buf, 0x128, 0)                   # nParticleEmitters

    os.makedirs(os.path.dirname(out_m2), exist_ok=True)
    open(out_m2, "wb").write(buf)
    shutil.copy2(src_skin, out_skin)
    return whites


def write_lua(spell2path, disp2path):
    lines = [
        "-- DC-Collection Data/MountModelPathsStock.lua",
        "-- ============================================",
        "--",
        "-- Preview .m2 paths for the STOCK (blizzlike) mounts -- the half of the catalog",
        "-- MountModelPaths.lua has never covered, since that file is generated from the CUSTOM",
        "-- 500000+ display band only. All 273 stock mounts previewed blank before this existed.",
        "--",
        "-- Keyed by MOUNT SPELL, not by display id, on purpose: dc_mount_definitions.display_id",
        "-- holds a retail-era CreatureDisplayInfo id for every stock mount (Flying Broom = 56954,",
        "-- Brewfest Kodo = 29447), which is not a 3.3.5 display at all, and several mounts share one",
        "-- such id (all five horse bridles = 13108) -- so a display-keyed lookup can neither resolve",
        "-- nor tell the colours apart. The spell id is unique per mount and is exactly what the",
        "-- server sends as the collection item's id.",
        "--",
        "-- AUTO-GENERATED by tools/generate_stock_mount_previews.py. Do not edit by hand.",
        "",
        "local DC = DCCollection",
        "",
        "-- [mountSpellId] -> client .m2 path",
        "DC.MountModelPathsBySpell = DC.MountModelPathsBySpell or {",
    ]
    for sid in sorted(spell2path):
        lines.append('    [%d] = "%s",' % (sid, spell2path[sid].replace(BS, BS * 2)))
    lines += [
        "}",
        "",
        "-- The same models keyed by their REAL 3.3.5 display id, so the ordinary display-keyed",
        "-- lookup works too once dc_mount_definitions.display_id is corrected.",
        "DC.MountModelPaths = DC.MountModelPaths or {}",
        "for displayId, path in pairs({",
    ]
    for did in sorted(disp2path):
        lines.append('    [%d] = "%s",' % (did, disp2path[did].replace(BS, BS * 2)))
    lines += [
        "}) do",
        "    if DC.MountModelPaths[displayId] == nil then DC.MountModelPaths[displayId] = path end",
        "end",
        "",
    ]
    with open(LUA_OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True, help="the live client Data directory")
    ap.add_argument("--out", required=True, help="mountpreview\\ staging root to bake into")
    ap.add_argument("--work", default=None, help="scratch dir for the extracted stock models")
    args = ap.parse_args()

    work = args.work or os.path.join(args.out, "_stocksrc")
    chain, unresolved = resolve_chain()
    print("stock mounts in catalog: %d   unresolved: %s" % (len(chain) + len(unresolved), unresolved))

    models = sorted({v[1] for v in chain.values()}, key=str.lower)
    print("distinct stock models: %d -- extracting" % len(models))
    missing = extract_models(models, args.data, work)
    if missing:
        print("MISSING from every archive (%d):" % len(missing))
        for m in missing[:20]:
            print("   ", m)
        return 1

    spell2path, disp2path, whites, baked = {}, {}, 0, 0
    for sid, (disp, model, tvs) in sorted(chain.items()):
        folder = model.split(BS)[-2]
        stem = os.path.basename(model)[:-3]
        rel = BS.join([folder.lower(), "%s_%d.m2" % (stem, disp)])
        if disp not in disp2path:
            src_m2 = os.path.join(work, model.replace(BS, os.sep))
            w = bake(src_m2, src_m2[:-3] + "00.skin", tvs, folder,
                     os.path.join(args.out, folder.lower(), "%s_%d.m2" % (stem, disp)),
                     os.path.join(args.out, folder.lower(), "%s_%d00.skin" % (stem, disp)))
            if w is None:
                print("   NOT MD20, skipped:", model)
                continue
            whites += w
            baked += 1
            disp2path[disp] = BS.join(["mountpreview", rel])
        spell2path[sid] = disp2path[disp]

    write_lua(spell2path, disp2path)
    print("baked %d preview models for %d displays / %d spells" % (baked, len(disp2path), len(spell2path)))
    print("MONSTER slots with no TextureVariation (fell back to the model's own texture): %d" % whites)
    print("wrote", LUA_OUT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
