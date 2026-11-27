#!/usr/bin/env python3
"""Bake the DarkChaos HD / upgraded creature models and deploy them into the client patch layout.

Produces offline-converted (v264) model sets for the custom creatures/doodads that the DC
CreatureModelData rows in the 501600-501635 id range reference (Hyjal / Plaguelands and the
Cata-era retroports). Every model is emitted as a COMPLETE set (m2 + all skin profiles + external
anims + own textures) by the upgraded wxl-baker, so a single bake yields renderable models.

Pipeline (all offline; the client is only touched by the explicit --deploy step):
  1. Read the 501600-501635 ModelName paths from Custom/CSV DBC/CreatureModelData.csv.
  2. Bake each with wxl-baker (staged mode: keeps the 0x40000000 marker so the DC WarcraftXL
     runtime finalizes them; do NOT use --native-m2, which targets a runtime-less stock client).
  3. Route the staging tree into the client archives with dc_mpq_deploy.py, which sends each file
     to the archive dc_mpq_layout.dest_for() picks (these are creature\\ paths, so patch-G/patch-H).

This script used to pack the staging tree into a whole fresh patch-8.MPQ and copy that over the live
archive. That was destructive: the staging tree holds only these ~5k models, so the copy discarded
every other file the destination archive held. Deployment now adds/replaces exactly the baked files
and leaves the rest of the archive intact. See Custom/Client patches needed/CLIENT_PATCH_LAYOUT.md.

Expected MISS lines during bake are harmless: shared stock textures (item/objectcomponents,
spells/*, world/*) resolve from the base client MPQs, and a few alias/optional .anim sequences
have no external file in the extract.

Usage:
  python tools/build_hd_models.py [--bake] [--deploy] [--all] [--dry-run]
      [--src   K:/Dark-Chaos/retailextracts/creature_hyjal_plague]
      [--baker K:/Dark-Chaos/dc-wotlkextensions/build/downport/Release/wxl-baker.exe]
      [--data  "K:/WoW_3.3.5a_ 255 Fun/Data"]
"""
import argparse
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(REPO, "Custom", "CSV DBC", "CreatureModelData.csv")
CDI = os.path.join(REPO, "Custom", "CSV DBC", "CreatureDisplayInfo.csv")
STAGE = os.path.join(REPO, "Custom", "Client patches needed", "_hd_models")
DEPLOYER = r"K:/Dark-Chaos/retroport_tools/dc_mpq_deploy.py"
DATA_DIR = r"K:/WoW_3.3.5a_ 255 Fun/Data"

ID_LO, ID_HI = 501600, 501635


def model_targets():
    """The .m2 logical names the 501600-501635 CreatureModelData rows reference (deduped)."""
    import csv
    seen, out = set(), []
    with open(CSV, newline="", encoding="utf-8-sig") as f:
        r = csv.reader(f)
        hdr = next(r)
        mi, idi = hdr.index("ModelName"), hdr.index("ID")
        for row in r:
            try:
                rid = int(row[idi])
            except ValueError:
                continue
            if ID_LO <= rid <= ID_HI:
                p = row[mi].replace("\\", "/").strip()
                if p.lower().endswith(".m2") and p.lower() not in seen:
                    seen.add(p.lower())
                    out.append(p)
    return out


def _model_dir_by_id():
    """CreatureModelData.ID (501600-501635) -> the model's directory (e.g. 501630 -> creature/moltengiant)."""
    import csv
    out = {}
    with open(CSV, newline="", encoding="utf-8-sig") as f:
        r = csv.reader(f)
        hdr = next(r)
        mi, idi = hdr.index("ModelName"), hdr.index("ID")
        for row in r:
            try:
                rid = int(row[idi])
            except ValueError:
                continue
            if ID_LO <= rid <= ID_HI:
                p = row[mi].replace("\\", "/").strip()
                out[rid] = p.rsplit("/", 1)[0] if "/" in p else ""
    return out


def copy_monster_textures(src, dry):
    """Copy the monster-skin body textures the DBC-agnostic baker cannot see.

    A creature's body texture is not named in the .m2 -- the model has empty type-11/12/13
    'monster' texture slots that the client fills at runtime from CreatureDisplayInfo.TextureVariation_1..3.
    So for every display whose ModelID is one of ours, copy "<model dir>/<TextureVariation>.blp" from the
    extract next to the model. Without this the monster slots bind nothing and the material env-maps the
    scene -> the model renders solid green.
    """
    import csv
    import shutil
    mdir = _model_dir_by_id()
    copied = missing = 0
    with open(CDI, newline="", encoding="utf-8-sig") as f:
        r = csv.reader(f)
        hdr = next(r)
        mid = hdr.index("ModelID")
        tvs = [hdr.index("TextureVariation_1"), hdr.index("TextureVariation_2"), hdr.index("TextureVariation_3")]
        for row in r:
            try:
                rmodel = int(row[mid])
            except ValueError:
                continue
            if not (ID_LO <= rmodel <= ID_HI):
                continue
            d = mdir.get(rmodel)
            if d is None:
                continue
            for ti in tvs:
                name = row[ti].strip()
                if not name:
                    continue
                rel = (d + "/" if d else "") + name + ".blp"
                s = os.path.join(src, rel)
                t = os.path.join(STAGE, rel)
                if os.path.isfile(s):
                    if not os.path.isfile(t):
                        if not dry:
                            os.makedirs(os.path.dirname(t), exist_ok=True)
                            shutil.copy2(s, t)
                        copied += 1
                else:
                    missing += 1
                    print("  [tex MISS]", rel)
    print(f"[hd] monster-skin textures: {copied} copied, {missing} missing")


def bake(src, baker, dry):
    targets = model_targets()
    print(f"[hd] {len(targets)} model targets from {os.path.basename(CSV)} [{ID_LO}-{ID_HI}]")
    list_path = os.path.join(STAGE, "_bake_list.txt")  # _bake_* is auto-skipped by the packer
    os.makedirs(STAGE, exist_ok=True)
    with open(list_path, "w", newline="\n") as f:
        f.write("\n".join(targets) + "\n")
    # Staged mode (no --native-m2); --deps also pulls referenced textures.
    cmd = [baker, "--in", src, "--out", STAGE, "--deps", "--no-update", "--list", list_path]
    print("[hd] bake:", " ".join(f'"{c}"' if " " in c else c for c in cmd))
    if dry:
        return
    # wxl-baker returns 1 when any file MISSes (expected for shared stock textures) -> not fatal.
    subprocess.run(cmd, check=False)
    # Monster-skin body textures live in the DBC, not the model -> copy them after baking.
    copy_monster_textures(src, dry)


def deploy(data, dry):
    """Route the baked tree into whichever archives the canonical layout assigns these paths to."""
    cmd = [sys.executable, DEPLOYER, "--stage", STAGE, "--data", data]
    if not dry:
        cmd.append("--apply")
    print("[hd] deploy:", " ".join(f'"{c}"' if " " in c else c for c in cmd))
    subprocess.run(cmd, check=True)


def main():
    ap = argparse.ArgumentParser(description="Bake and deploy the HD/upgraded creature models.")
    ap.add_argument("--bake", action="store_true")
    ap.add_argument("--textures", action="store_true", help="copy DBC monster-skin textures only (no re-bake)")
    ap.add_argument("--deploy", action="store_true", help="route the baked tree into the client archives")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--src", default=r"K:/Dark-Chaos/retailextracts/creature_hyjal_plague")
    ap.add_argument("--baker", default=r"K:/Dark-Chaos/dc-wotlkextensions/build/downport/Release/wxl-baker.exe")
    ap.add_argument("--data", default=DATA_DIR)
    a = ap.parse_args()
    if not (a.bake or a.textures or a.deploy or a.all):
        ap.print_help()
        return 0
    if a.bake or a.all:
        bake(a.src, a.baker, a.dry_run)
    elif a.textures:
        copy_monster_textures(a.src, a.dry_run)
    if a.deploy or a.all:
        deploy(a.data, a.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
