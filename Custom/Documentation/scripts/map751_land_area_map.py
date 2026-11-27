#!/usr/bin/env python3
"""land_area_map.py - per-chunk (areaid, is_land) map for map 751 from the deployed ADTs.

LAND TEST: a chunk counts as water only when MH2O gives it a liquid layer AND its highest
vertex is at or below sea level 0. Height alone is not enough -- see the note in build().

The earlier density pass counted OCEAN as zone area: "The Forbidding Sea" alone is 3,095
chunks in Hinterlands and 2,402 in Arathi, and the Gilneas zone body is a peninsula
surrounded by unnamed water tagged with the zone id. Dividing spawns by total chunks
therefore understates density by whatever fraction of the zone is sea.

Land test: terrain height = MCNK header position.z (+0x70) + max MCVT delta. MCVT lives at
ofsHeight (+0x14), both offsets relative to the MCNK TAG (adt-mcnk-parsing-traps). A chunk
whose highest vertex is below sea level 0 is ocean floor.
"""
import ctypes
import json
import re
import struct
import sys
from ctypes import wintypes

DLL = r"K:\Dark-Chaos\Release2.3.01\x64\StormLib.dll"
PATCH4 = "K:/WoW_3.3.5a_ 255 Fun/Data/patch-4.MPQ"
BS = chr(92)
TILE = 533.33333
CHUNK = TILE / 16.0

_dll = ctypes.WinDLL(DLL, use_last_error=True)
_dll.SFileOpenArchive.argtypes = [ctypes.c_wchar_p, wintypes.DWORD, wintypes.DWORD,
                                  ctypes.POINTER(ctypes.c_void_p)]
_dll.SFileOpenFileEx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, wintypes.DWORD,
                                 ctypes.POINTER(ctypes.c_void_p)]
_dll.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
_dll.SFileGetFileSize.restype = wintypes.DWORD
_dll.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                               ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]


def _open():
    h = ctypes.c_void_p()
    _dll.SFileOpenArchive(PATCH4, 0, 0x100, ctypes.byref(h))
    return h


def grab(h, name):
    fh = ctypes.c_void_p()
    ctypes.set_last_error(0)
    _dll.SFileOpenFileEx(h, name.encode(), 0, ctypes.byref(fh))
    if ctypes.get_last_error() != 0 or not fh:
        return None
    sz = _dll.SFileGetFileSize(fh, None)
    buf = ctypes.create_string_buffer(sz)
    rd = wintypes.DWORD()
    _dll.SFileReadFile(fh, buf, sz, ctypes.byref(rd), None)
    _dll.SFileCloseFile(fh)
    return buf.raw[:rd.value]


def mh2o_layers(data):
    """-> list of 256 layer_counts from MH2O, or None if the tile has no MH2O.

    Header is 256 x {uint32 ofsInstances, uint32 layerCount, uint32 ofsAttributes} and sits at
    the start of the MH2O DATA (offsets inside it are relative to that same point)."""
    off, n = 0, len(data)
    while off + 8 <= n:
        tag = data[off:off + 4][::-1]
        size = struct.unpack_from('<I', data, off + 4)[0]
        if tag == b'MH2O':
            base = off + 8
            return [struct.unpack_from('<I', data, base + i * 12 + 4)[0] for i in range(256)]
        off += 8 + size
    return None


def adt_chunks(data):
    """-> list of 256 (areaid, top_height) in file order (i = cx*16 + cy)."""
    out = []
    off, n = 0, len(data)
    while off + 8 <= n:
        tag = data[off:off + 4][::-1]
        size = struct.unpack_from('<I', data, off + 4)[0]
        if tag == b'MCNK':
            hdr = off + 8
            areaid = struct.unpack_from('<I', data, hdr + 0x34)[0]
            ofs_h = struct.unpack_from('<I', data, hdr + 0x14)[0]
            posz = struct.unpack_from('<f', data, hdr + 0x70)[0]
            top = posz
            if ofs_h:
                mcvt = off + ofs_h
                if data[mcvt:mcvt + 4][::-1] == b'MCVT':
                    hs = struct.unpack_from('<145f', data, mcvt + 8)
                    top = posz + max(hs)
            out.append((areaid, top))
        off += 8 + size
    return out


def build(cols, rows, dirname="dcplaguelands"):
    h = _open()
    assert h, "archive open failed"
    area_land, area_all = {}, {}
    ck_area, ck_land = {}, {}
    tiles = 0
    for col in cols:
        for row in rows:
            name = ("World" + BS + "Maps" + BS + dirname + BS +
                    "%s_%d_%d.adt" % (dirname, col, row))
            d = grab(h, name)
            if d is None:
                continue
            tiles += 1
            cs = adt_chunks(d)
            liq = mh2o_layers(d) or [0] * 256
            if len(cs) != 256:
                print("  WARN %s: %d MCNKs" % (name, len(cs)), file=sys.stderr)
            for i, (a, top) in enumerate(cs):
                cx, cy = divmod(i, 16)
                ck = (row * 16 + cx) * 1000 + (col * 16 + cy)
                # OCEAN only where liquid actually covers a chunk whose terrain is under it.
                # A bare "top <= 0" test is wrong inland: The Blackwald's floor sits at a median
                # of -22.9 with no liquid at all, and it is walkable ground (our heightmap is
                # byte-identical to Cata's own Azeroth ADTs, so the depth is Blizzard's).
                land = top > 0.0 or liq[i] == 0
                ck_area[ck] = a
                ck_land[ck] = land
                area_all[a] = area_all.get(a, 0) + 1
                if land:
                    area_land[a] = area_land.get(a, 0) + 1
    _dll.SFileCloseArchive(h)
    print("parsed %d ADTs" % tiles, file=sys.stderr)
    return area_all, area_land, ck_area, ck_land


if __name__ == "__main__":
    aa, al, cka, ckl = build(range(24, 44), range(23, 38))
    json.dump({"all": {str(k): v for k, v in aa.items()},
               "land": {str(k): v for k, v in al.items()},
               "ck_area": {str(k): v for k, v in cka.items()},
               "ck_land": {str(k): int(v) for k, v in ckl.items()}},
              open("k:/tmp/map751_land.json", "w"))
    print("areas=%d  chunks=%d  land=%d (%.1f%%)"
          % (len(aa), sum(aa.values()), sum(al.values()),
             100.0 * sum(al.values()) / sum(aa.values())))
