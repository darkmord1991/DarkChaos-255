#!/usr/bin/env python3
r"""
stage_filestring_assets.py - the assets a race needs because of its ChrRaces.ClientFileString.

The client builds these paths from that field, so a race with its own file string (which it needs
for its own text, icon and glue scene) has to ship them under that name:

    World\Generic\PassiveDoodads\DeathSkeletons\<File><Sex>DeathSkeleton.m2 + 00.skin
    Interface\DressUpFrame\DressUpBackground-<File>1..4.blp
    Interface\CharacterFrame\TemporaryPortrait-<Sex>-<File>.blp

Skeletons and dressing-room art are byte copies of the parent race's, read from the client's
winning archive. Portraits come from --portraits (the retail BLPs, named
temporaryportrait-<sex>-<file>.blp in lower case) and fall back to the parent's.

    python stage_filestring_assets.py --file DarkIronDwarf --parent Dwarf
        --client K:\WoWDecompDark\Data --stage <dir> [--portraits <dir>]
"""
import argparse
import ctypes
import os
import re
import sys

STORM = r"K:\Dark-Chaos\Release2.3.01\x64\StormLib.dll"
SKELETONS = "World\\Generic\\PassiveDoodads\\DeathSkeletons\\"
DRESSUP = "Interface\\DressUpFrame\\DressUpBackground-"
PORTRAIT = "Interface\\CharacterFrame\\TemporaryPortrait-"

S = ctypes.WinDLL(STORM)
S.SFileOpenArchive.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)]
S.SFileOpenArchive.restype = ctypes.c_ubyte
S.SFileOpenFileEx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_uint32, ctypes.POINTER(ctypes.c_void_p)]
S.SFileOpenFileEx.restype = ctypes.c_ubyte
S.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
S.SFileGetFileSize.restype = ctypes.c_uint32
S.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32, ctypes.POINTER(ctypes.c_uint32), ctypes.c_void_p]
S.SFileReadFile.restype = ctypes.c_ubyte
S.SFileCloseFile.argtypes = [ctypes.c_void_p]


def rank(name):
    """Archive priority: numbered and lettered patches first, highest last character first."""
    m = re.fullmatch(r"patch-([0-9a-z]+)\.mpq", name.lower())
    if m:
        return (0, -ord(m.group(1)[-1]))
    return (1, 0) if name.lower() == "patch.mpq" else (2, 0)


def open_archives(data):
    out = []
    for d in (data, os.path.join(data, "enGB")):
        names = sorted((n for n in os.listdir(d) if n.lower().endswith(".mpq")), key=rank)
        for n in names:
            h = ctypes.c_void_p()
            if S.SFileOpenArchive(os.path.join(d, n), 0, 0x100, ctypes.byref(h)):
                out.append(h)
    return out


def read(archives, path):
    for h in archives:
        f = ctypes.c_void_p()
        if S.SFileOpenFileEx(h, path.encode("ascii"), 0, ctypes.byref(f)):
            size = S.SFileGetFileSize(f, None)
            buf = ctypes.create_string_buffer(size)
            got = ctypes.c_uint32()
            S.SFileReadFile(f, buf, size, ctypes.byref(got), None)
            S.SFileCloseFile(f)
            return buf.raw[:got.value]
    raise SystemExit("not in the client: %s" % path)


def write(stage, path, data):
    out = os.path.join(stage, *path.split("\\"))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, "wb").write(data)
    print("%8d %s" % (len(data), path))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", required=True, help="the race's ClientFileString")
    ap.add_argument("--parent", required=True, help="the parent race's ClientFileString")
    ap.add_argument("--client", required=True, help="client Data folder")
    ap.add_argument("--stage", required=True, help="folder that mirrors in-archive paths")
    ap.add_argument("--portraits", help="folder with the retail portrait BLPs")
    a = ap.parse_args()

    archives = open_archives(a.client)
    retail = {}
    if a.portraits:
        for d, _, files in os.walk(a.portraits):
            for f in files:
                retail[f.lower()] = os.path.join(d, f)

    for sex in ("Male", "Female"):
        for suffix in ("DeathSkeleton.m2", "DeathSkeleton00.skin"):
            write(a.stage, "%s%s%s%s" % (SKELETONS, a.file, sex, suffix),
                  read(archives, "%s%s%s%s" % (SKELETONS, a.parent, sex, suffix)))
        name = "temporaryportrait-%s-%s.blp" % (sex.lower(), a.file.lower())
        portrait = open(retail[name], "rb").read() if name in retail \
            else read(archives, "%s%s-%s.blp" % (PORTRAIT, sex, a.parent))
        write(a.stage, "%s%s-%s.blp" % (PORTRAIT, sex, a.file), portrait)
    for i in range(1, 5):
        write(a.stage, "%s%s%d.blp" % (DRESSUP, a.file, i), read(archives, "%s%s%d.blp" % (DRESSUP, a.parent, i)))


if __name__ == "__main__":
    sys.exit(main())
