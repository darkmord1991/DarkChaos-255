"""Read AzerothCore v9 server .map tiles exactly as GridTerrainData does (area, height, holes, liquid)."""
import struct
from functools import lru_cache
from pathlib import Path

import numpy as np

SIZE_OF_GRIDS = 533.3333
MAP_RESOLUTION = 128
INVALID_HEIGHT = -200000.0
HOLETAB_H = (0x1111, 0x2222, 0x4444, 0x8888)
HOLETAB_V = (0x000F, 0x00F0, 0x0F00, 0xF000)
MAPS_DIR = Path(r"K:/Dark-Chaos/Server/data/maps")


class Tile:
    def __init__(self, path):
        data = path.read_bytes()
        (magic, version, _build, area_off, _area_sz, h_off, _h_sz, l_off, _l_sz, holes_off,
         holes_sz) = struct.unpack_from("<4sII8I", data, 0)
        if magic != b"MAPS" or version != 9:
            raise ValueError(f"{path}: bad magic {magic} v{version}")
        self.grid_area = 0
        self.area_map = None
        if area_off:
            fourcc, flags, grid_area = struct.unpack_from("<4sHH", data, area_off)
            self.grid_area = grid_area
            if not flags & 0x1:
                self.area_map = np.frombuffer(data, "<u2", 256, area_off + 8)
        self.kind = "none"
        self.grid_height = INVALID_HEIGHT
        if h_off:
            fourcc, flags, gh, gmax = struct.unpack_from("<4sIff", data, h_off)
            self.grid_height = gh
            p = h_off + 16
            if flags & 0x1:
                self.kind = "flat"
            elif flags & 0x2:
                self.kind = "u16"
                self.v9 = np.frombuffer(data, "<u2", 129 * 129, p).astype(np.int64)
                self.v8 = np.frombuffer(data, "<u2", 128 * 128, p + 129 * 129 * 2).astype(np.int64)
                self.mult = (gmax - gh) / 65535
            elif flags & 0x4:
                self.kind = "u8"
                self.v9 = np.frombuffer(data, "u1", 129 * 129, p).astype(np.int64)
                self.v8 = np.frombuffer(data, "u1", 128 * 128, p + 129 * 129).astype(np.int64)
                self.mult = (gmax - gh) / 255
            else:
                self.kind = "float"
                self.v9 = np.frombuffer(data, "<f4", 129 * 129, p).astype(np.float64)
                self.v8 = np.frombuffer(data, "<f4", 128 * 128, p + 129 * 129 * 4).astype(np.float64)
        self.holes = np.frombuffer(data, "<u2", 256, holes_off) if holes_sz else None
        self.liquid = None
        if l_off:
            fourcc, lflags, lglob_flags, ltype, offx, offy, w, h, level = struct.unpack_from("<4sBBHBBBBf", data, l_off)
            p = l_off + 16
            entry = flag = None
            if not lflags & 0x1:
                entry = np.frombuffer(data, "<u2", 256, p)
                flag = np.frombuffer(data, "u1", 256, p + 512)
                p += 512 + 256
            lmap = None
            if not lflags & 0x2:
                lmap = np.frombuffer(data, "<f4", w * h, p)
            self.liquid = (lglob_flags, ltype, offx, offy, w, h, level, entry, flag, lmap)

    def area(self, x, y):
        if self.area_map is None:
            return self.grid_area
        lx = int(16 * (32 - x / SIZE_OF_GRIDS)) & 15
        ly = int(16 * (32 - y / SIZE_OF_GRIDS)) & 15
        return int(self.area_map[lx * 16 + ly])

    def is_hole(self, row, col):
        if self.holes is None:
            return False
        cell_row, cell_col = row // 8, col // 8
        hole_row = row % 8 // 2
        hole_col = (col - cell_col * 8) // 2
        return (int(self.holes[cell_row * 16 + cell_col]) & HOLETAB_H[hole_col] & HOLETAB_V[hole_row]) != 0

    def height(self, x, y):
        if self.kind == "none":
            return INVALID_HEIGHT
        if self.kind == "flat":
            return self.grid_height
        fx = MAP_RESOLUTION * (32 - x / SIZE_OF_GRIDS)
        fy = MAP_RESOLUTION * (32 - y / SIZE_OF_GRIDS)
        xi, yi = int(fx), int(fy)
        fx -= xi
        fy -= yi
        xi &= MAP_RESOLUTION - 1
        yi &= MAP_RESOLUTION - 1
        if self.is_hole(xi, yi):
            return INVALID_HEIGHT
        v9, v8 = self.v9, self.v8
        h1 = v9[xi * 129 + yi]
        h2 = v9[(xi + 1) * 129 + yi]
        h3 = v9[xi * 129 + yi + 1]
        h4 = v9[(xi + 1) * 129 + yi + 1]
        h5 = 2 * v8[xi * 128 + yi]
        if fx + fy < 1:
            if fx > fy:
                a, b, c = h2 - h1, h5 - h1 - h2, h1
            else:
                a, b, c = h5 - h1 - h3, h3 - h1, h1
        else:
            if fx > fy:
                a, b, c = h2 + h4 - h5, h4 - h2, h5 - h4
            else:
                a, b, c = h4 - h3, h3 + h4 - h5, h5 - h4
        z = a * fx + b * fy + c
        if self.kind == "float":
            return float(z)
        return float(z) * self.mult + self.grid_height

    def liquid_level(self, x, y):
        if self.liquid is None:
            return None
        gflags, ltype, offx, offy, w, h, level, entry, flag, lmap = self.liquid
        cx = MAP_RESOLUTION * (32 - x / SIZE_OF_GRIDS)
        cy = MAP_RESOLUTION * (32 - y / SIZE_OF_GRIDS)
        x_int = int(cx) & (MAP_RESOLUTION - 1)
        y_int = int(cy) & (MAP_RESOLUTION - 1)
        idx = (x_int >> 3) * 16 + (y_int >> 3)
        if flag is not None and not flag[idx]:
            return None
        if flag is None and not gflags:
            return None
        lx, ly = x_int - offy, y_int - offx
        if lx < 0 or lx >= h or ly < 0 or ly >= w:
            return None
        if lmap is None:
            return float(level)
        return float(lmap[lx * w + ly])


@lru_cache(maxsize=4096)
def tile(map_id, gx, gy):
    p = MAPS_DIR / f"{map_id:03d}{gx:02d}{gy:02d}.map"
    if not p.exists():
        return None
    return Tile(p)


def grid_of(x, y):
    return max(0, int(32 - x / SIZE_OF_GRIDS)), max(0, int(32 - y / SIZE_OF_GRIDS))


def probe(map_id, x, y):
    """(tile_exists, area_id, terrain_z or None, liquid_z or None)."""
    t = tile(map_id, *grid_of(x, y))
    if t is None:
        return False, 0, None, None
    z = t.height(x, y)
    return True, t.area(x, y), (None if z <= INVALID_HEIGHT + 1 else z), t.liquid_level(x, y)
