#!/usr/bin/env python3
"""Re-bake raw/modern models that already live in a client MPQ into proper v264, into a staging tree.

Some DC creatures/pets/mounts were shipped as RAW MD21 (never de-chunked). The archive holding them
also ships each model's COMPLETE modern source next to it (m2 + all skin profiles + LOD skins + .anim +
every .blp), and those creatures are NOT in the retailextracts trees -- so the archive itself is the bake
source of record.

Since the 2026-08-04 patch rebuild there is no longer a low-slot/high-slot override pair to exploit:
all creature\\ assets live in ONE role (patch-G/patch-H) and no path exists twice across the custom
layer. So point --mpq at whichever archive dc_mpq_layout.dest_for() assigns the target models to, and
deploy the re-baked result back over the same paths via dc_mpq_deploy.py. Overriding a raw copy by
shipping a second copy into a higher-numbered patch is no longer a valid technique - it would just
re-introduce the shadowed duplicates the rebuild removed.

Pipeline per run:
  1. From the MPQ (listfile), gather every file that shares a directory with a target .m2  (its whole
     model folder: skins, LOD skins, anims, textures).
  2. Extract that set to a temp source tree (mpq_stormlib_extract.py --preserve-paths).
  3. Bake the target .m2s with the upgraded wxl-baker (--deps): emits v264 m2 + skins + anims + own textures.
  4. Copy any companion .blp/.skin/.anim the baker did not emit (monster-skin body textures named by the
     DBC, LOD skins) from the temp source into the staging tree.
Caller then redeploys the models (python tools/build_hd_models.py --deploy).

Usage:
  python tools/rebake_from_mpq.py --mpq "K:/WoW_3.3.5a_ 255 Fun/Data/patch-G.MPQ" \
      --m2-list <file with one m2 logical name per line> [--limit N]
      [--out "Custom/Client patches needed/_hd_models"] [--tmp <dir>]
      [--baker K:/Dark-Chaos/dc-wotlkextensions/build/downport/Release/wxl-baker.exe]
"""
import argparse
import ctypes
import os
import shutil
import struct
import subprocess
import sys
from ctypes import wintypes

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DLL = r"K:\Dark-Chaos\Release2.3.01\x64\StormLib.dll"
EXTRACT = r"K:/Dark-Chaos/wow.export-main/tools/mpq_stormlib_extract.py"
MPQ_OPEN_READ_ONLY = 0x00000100


def read_listfile(mpq):
    d = ctypes.WinDLL(DLL, use_last_error=True)
    d.SFileOpenArchive.argtypes = [ctypes.c_wchar_p, wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p)]
    d.SFileOpenFileEx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, wintypes.DWORD, ctypes.POINTER(ctypes.c_void_p)]
    d.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    d.SFileGetFileSize.restype = wintypes.DWORD
    d.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    h = ctypes.c_void_p()
    d.SFileOpenArchive(mpq, 0, MPQ_OPEN_READ_ONLY, ctypes.byref(h))
    if not h.value:
        sys.exit("ERR open " + mpq)
    fh = ctypes.c_void_p()
    ctypes.set_last_error(0)
    d.SFileOpenFileEx(h, b"(listfile)", 0, ctypes.byref(fh))
    buf = ctypes.create_string_buffer(64 * 1024 * 1024)
    rd = wintypes.DWORD(0)
    d.SFileReadFile(fh, buf, 64 * 1024 * 1024, ctypes.byref(rd), None)
    d.SFileCloseArchive(h)
    return [l.strip() for l in buf.raw[:rd.value].decode("latin1").replace("\r", "\n").split("\n") if l.strip()]


def norm(p):
    return p.replace("\\", "/").lower()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mpq", required=True)
    ap.add_argument("--m2-list", required=True)
    ap.add_argument("--out", default=os.path.join(REPO, "Custom", "Client patches needed", "_hd_models"))
    ap.add_argument("--tmp", default=os.path.join(os.environ.get("TEMP", "/tmp"), "wxl_rebake_src"))
    ap.add_argument("--baker", default=r"K:/Dark-Chaos/dc-wotlkextensions/build/downport/Release/wxl-baker.exe")
    ap.add_argument("--limit", type=int, default=0)
    a = ap.parse_args()

    m2s = [l.strip() for l in open(a.m2_list, encoding="utf-8") if l.strip().lower().endswith(".m2")]
    if a.limit:
        m2s = m2s[:a.limit]
    print(f"[rebake] {len(m2s)} target .m2 from {os.path.basename(a.mpq)}")

    listfile = read_listfile(a.mpq)
    # directories that contain a target model
    dirs = set(norm(m).rsplit("/", 1)[0] for m in m2s)
    # every archive file living in one of those directories
    extract = [p for p in listfile if norm(p).rsplit("/", 1)[0] in dirs]
    print(f"[rebake] {len(dirs)} model dirs -> extracting {len(extract)} source files")

    os.makedirs(a.tmp, exist_ok=True)
    ext_list = os.path.join(a.tmp, "_extract_list.txt")
    with open(ext_list, "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(extract) + "\n")
    subprocess.run([sys.executable, EXTRACT, "--mpq", a.mpq, "--out", a.tmp,
                    "--preserve-paths", "--list-file", ext_list, "--quiet"], check=True)

    bake_list = os.path.join(a.tmp, "_bake_list.txt")
    with open(bake_list, "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(m2s) + "\n")
    subprocess.run([a.baker, "--in", a.tmp, "--out", a.out, "--deps", "--no-update",
                    "--list", bake_list], check=False)  # MISS on shared stock textures is expected

    # Copy companion assets the baker does not emit (monster-skin body textures from the DBC, LOD skins).
    copied = 0
    for root, _, files in os.walk(a.tmp):
        for fn in files:
            ext = fn.lower().rsplit(".", 1)[-1]
            if ext not in ("blp", "skin", "anim"):
                continue
            src = os.path.join(root, fn)
            rel = os.path.relpath(src, a.tmp).replace(os.sep, "/")
            dst = os.path.join(a.out, rel)
            if not os.path.isfile(dst):
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
                copied += 1
    print(f"[rebake] copied {copied} companion assets (textures/lod-skins) the baker did not emit")
    print(f"[rebake] done -> {a.out}  (repack with: python tools/build_hd_models.py --deploy)")


if __name__ == "__main__":
    main()
