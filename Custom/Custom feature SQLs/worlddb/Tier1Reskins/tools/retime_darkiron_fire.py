#!/usr/bin/env python3
"""Slow the fire in the Dark Iron glue scene by stretching its time base.

Retail draws these flames with three scrolling textures. 3.3.5 draws the first one only, so each
particle is one static wisp that is gone in half a second, which reads as fire burning too fast.

Everything is stretched by the same factor, like playing the fire in slow motion:
- life and its variation go up, speed, spin and drag come down, so a particle travels the same path;
- rate comes down, so the number of particles alive stays the same and the fire keeps its density
  (the client sizes its pool from (life variation + life) * rate);
- the backdrop's firelight sequences stretch along with it.

Speed variation is left alone: the client treats it as a fraction of speed, not as a speed.
Emitter 12 stays too. Its pulse is keyed to the 3333 ms sequence, which the camera also runs on.

Running it again with the same TARGET_FLAME_LIFE changes nothing. To retune, change that constant
and run it on the staged model.

Usage: retime_darkiron_fire.py --input <ui_darkirondwarf.m2> --output <ui_darkirondwarf.m2>
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

# Retail is 0.5 s.
TARGET_FLAME_LIFE = 0.83
FLAME_EMITTER = 1
FIRE_EMITTERS = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13)
# darkironbackground_glow and darkironbackground_glowspots.
FIRELIGHT_SEQUENCES = (4, 5)

EMITTER_SIZE = 476
SPEED, LIFE, RATE = 0x34, 0x98, 0xB0
LIFE_VARIATION = 0xAC
# Drag and spin are per-second rates.
RATE_FIELDS = (0x174, 0x180, 0x184)
# These would need their own scaling, so the tool stops if the scene ever gains one.
MUST_BE_ZERO = {"gravity": 0x84, "tumble": 0x188, "wind": 0x1A0}
TUMBLE_FLOATS, WIND_FLOATS = 6, 3

# (name, header offset of the array, record size, track offsets inside a record)
TRACK_TABLES = (
    ("bone", 0x2C, 88, (16, 36, 56)),
    ("color", 0x48, 40, (0, 20)),
    ("transparency", 0x58, 20, (0,)),
    ("uv", 0x60, 60, (0, 20, 40)),
    ("attachment", 0xF0, 40, (20,)),
    ("light", 0x108, 156, (16, 36, 56, 76, 96, 116, 136)),
    ("camera", 0x110, 100, (16, 48, 80)),
    ("emitter", 0x128, EMITTER_SIZE, (0x34, 0x48, 0x5C, 0x70, 0x84, 0x98, 0xB0, 0xC8, 0xDC, 0xF0, 0x1C8)),
)


def array(data: bytearray, offset: int) -> tuple[int, int]:
    return struct.unpack_from("<II", data, offset)


def sub_arrays(data: bytearray, offset: int):
    count, start = array(data, offset)
    for i in range(count):
        yield array(data, start + i * 8)


def scale_floats(data: bytearray, offset: int, count: int, factor: float) -> None:
    values = struct.unpack_from(f"<{count}f", data, offset)
    struct.pack_into(f"<{count}f", data, offset, *(value * factor for value in values))


def scale_track_values(data: bytearray, track: int, factor: float) -> None:
    for count, start in sub_arrays(data, track + 12):
        scale_floats(data, start, count, factor)


def track_value(data: bytearray, track: int) -> float:
    count, start = next(sub_arrays(data, track + 12))
    if count != 1:
        raise SystemExit(f"expected one key in the track at {track:#x}, found {count}")
    return struct.unpack_from("<f", data, start)[0]


def check_static(data: bytearray, emitter: int, index: int) -> None:
    fields = {
        "gravity": track_value(data, emitter + MUST_BE_ZERO["gravity"]),
        "tumble": max(map(abs, struct.unpack_from(f"<{TUMBLE_FLOATS}f", data, emitter + MUST_BE_ZERO["tumble"]))),
        "wind": max(map(abs, struct.unpack_from(f"<{WIND_FLOATS}f", data, emitter + MUST_BE_ZERO["wind"]))),
    }
    for name, value in fields.items():
        if value != 0.0:
            raise SystemExit(f"emitter {index}: {name} is {value}, this tool does not scale it")


def firelight_tracks(data: bytearray) -> list[int]:
    """Every track on a firelight sequence. Stops unless all of them are transparency tracks."""
    found = []
    for name, header, size, offsets in TRACK_TABLES:
        count, start = array(data, header)
        for i in range(count):
            for offset in offsets:
                track = start + i * size + offset
                sequence = struct.unpack_from("<h", data, track + 2)[0]
                if sequence not in FIRELIGHT_SEQUENCES:
                    continue
                if name != "transparency":
                    raise SystemExit(f"{name} {i} also runs on global sequence {sequence}")
                found.append(track)
    return found


def retime(data: bytearray) -> float:
    emitter_count, emitters = array(data, 0x128)
    if emitter_count != 14:
        raise SystemExit(f"expected the 14 emitter scene, found {emitter_count}")

    current = track_value(data, emitters + FLAME_EMITTER * EMITTER_SIZE + LIFE)
    factor = TARGET_FLAME_LIFE / current
    if abs(factor - 1.0) < 1e-5:
        return 1.0

    for index in FIRE_EMITTERS:
        emitter = emitters + index * EMITTER_SIZE
        check_static(data, emitter, index)
        scale_track_values(data, emitter + LIFE, factor)
        scale_track_values(data, emitter + SPEED, 1.0 / factor)
        scale_track_values(data, emitter + RATE, 1.0 / factor)
        scale_floats(data, emitter + LIFE_VARIATION, 1, factor)
        for field in RATE_FIELDS:
            scale_floats(data, emitter + field, 1, 1.0 / factor)

    sequence_count, sequences = array(data, 0x14)
    tracks = firelight_tracks(data)
    if sequence_count <= max(FIRELIGHT_SEQUENCES) or len(tracks) != len(FIRELIGHT_SEQUENCES):
        raise SystemExit(f"expected one transparency track per firelight sequence, found {len(tracks)}")
    for sequence in FIRELIGHT_SEQUENCES:
        length = struct.unpack_from("<I", data, sequences + sequence * 4)[0]
        struct.pack_into("<I", data, sequences + sequence * 4, round(length * factor))
    for track in tracks:
        for count, start in sub_arrays(data, track + 4):
            times = struct.unpack_from(f"<{count}I", data, start)
            struct.pack_into(f"<{count}I", data, start, *(round(time * factor) for time in times))
    return factor


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    data = bytearray(args.input.read_bytes())
    if data[:4] != b"MD20":
        raise SystemExit(f"{args.input} is not an M2")
    factor = retime(data)
    args.output.write_bytes(data)
    print(f"stretched by {factor:.4f}, the fire now plays at {100.0 / factor:.0f}% speed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
