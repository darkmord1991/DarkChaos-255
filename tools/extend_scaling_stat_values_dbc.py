#!/usr/bin/env python3
"""Extend ScalingStatValues calculations and rebuild CSV + DBC.

Uses the CSV file as source of truth and extrapolates levels above the highest
existing row using a gentle progressive boost curve used by server-side
heirloom scaling fallback:
value(level) = value(base) * (1 + x + c * x^2), where x = (level-base)/base.
"""

from __future__ import annotations

import argparse
import csv
import struct
from pathlib import Path


HEADER_FMT = "<4s4I"
ROW_FMT = "<24i"
HEADER_SIZE = struct.calcsize(HEADER_FMT)
ROW_SIZE = struct.calcsize(ROW_FMT)
ROW_FIELD_COUNT = 24
DEFAULT_PROGRESSIVE_CURVE = 0.08


DEFAULT_CSV_HEADER = [
    "ID",
    "Charlevel",
    "ShoulderBudget",
    "TrinketBudget",
    "WeaponBudget1H",
    "RangedBudget",
    "ClothShoulderArmor",
    "LeatherShoulderArmor",
    "MailShoulderArmor",
    "PlateShoulderArmor",
    "WeaponDPS1H",
    "WeaponDPS2H",
    "SpellcasterDPS1H",
    "SpellcasterDPS2H",
    "RangedDPS",
    "WandDPS",
    "SpellPower",
    "PrimaryBudget",
    "TertiaryBudget",
    "ClothCloakArmor",
    "ClothChestArmor",
    "LeatherChestArmor",
    "MailChestArmor",
    "PlateChestArmor",
]


def parse_dbc(path: Path) -> tuple[list[list[int]], bytes]:
    raw = path.read_bytes()
    if len(raw) < HEADER_SIZE:
        raise ValueError(f"{path} is too small to be a valid DBC file")

    magic, record_count, field_count, record_size, string_size = struct.unpack_from(
        HEADER_FMT, raw, 0
    )

    if magic != b"WDBC":
        raise ValueError(f"{path} is not a WDBC file")
    if field_count != ROW_FIELD_COUNT:
        raise ValueError(f"Expected {ROW_FIELD_COUNT} fields, got {field_count}")
    if record_size != ROW_SIZE:
        raise ValueError(f"Expected row size {ROW_SIZE}, got {record_size}")

    data_offset = HEADER_SIZE
    data_size = record_count * record_size
    strings_offset = data_offset + data_size
    strings_end = strings_offset + string_size

    if strings_end > len(raw):
        raise ValueError("DBC file is truncated")

    rows: list[list[int]] = []
    for i in range(record_count):
        offset = data_offset + i * record_size
        rows.append(list(struct.unpack_from(ROW_FMT, raw, offset)))

    string_block = raw[strings_offset:strings_end] or b"\x00"
    return rows, string_block


def parse_csv(path: Path) -> tuple[list[str], list[list[int]]]:
    with path.open("r", newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        try:
            header = next(reader)
        except StopIteration as exc:
            raise ValueError(f"{path} is empty") from exc

        rows: list[list[int]] = []
        for line_no, row in enumerate(reader, start=2):
            if not row or all(not cell.strip() for cell in row):
                continue
            if len(row) < ROW_FIELD_COUNT:
                raise ValueError(
                    f"{path}:{line_no} expected {ROW_FIELD_COUNT} columns, got {len(row)}"
                )

            parsed: list[int] = []
            for i in range(ROW_FIELD_COUNT):
                cell = row[i].strip()
                if not cell:
                    parsed.append(0)
                    continue
                parsed.append(int(cell))
            rows.append(parsed)

    return header, rows


def level_map(rows: list[list[int]]) -> dict[int, list[int]]:
    by_level: dict[int, list[int]] = {}
    for row in rows:
        level = row[1]
        if level <= 0:
            continue
        if level not in by_level:
            by_level[level] = row
    return by_level


def scaled_value(base_value: int, level: int, base_level: int, progressive_curve: float) -> int:
    if base_value == 0:
        return 0

    normalized_delta = float(level - base_level) / float(base_level)
    factor = 1.0 + normalized_delta + progressive_curve * normalized_delta * normalized_delta
    value = int(round(base_value * factor))
    return max(value, 0)


def rebuild_rows_progressive(
    rows: list[list[int]], target_level: int, base_level: int, progressive_curve: float
) -> tuple[list[list[int]], int, int]:
    by_level = level_map(rows)
    if not by_level:
        raise ValueError("No valid level rows found")

    if target_level <= 0:
        raise ValueError("target_level must be greater than zero")

    available_base_levels = [lvl for lvl in by_level if lvl <= base_level]
    if not available_base_levels:
        raise ValueError(
            f"No base row found at or below configured base level ({base_level})"
        )

    effective_base_level = max(available_base_levels)
    base_row = by_level[effective_base_level]

    max_id = max(row[0] for row in rows)
    next_id = max_id + 1
    recalculated = 0
    rebuilt_rows: list[list[int]] = []

    for level in range(1, target_level + 1):
        existing_row = by_level.get(level)
        if level <= effective_base_level and existing_row:
            rebuilt_rows.append(existing_row[:])
            continue

        new_row = [0] * ROW_FIELD_COUNT
        if existing_row:
            new_row[0] = existing_row[0]
        else:
            new_row[0] = next_id
            next_id += 1
        new_row[1] = level

        for idx in range(2, ROW_FIELD_COUNT):
            new_row[idx] = scaled_value(
                base_row[idx], level, effective_base_level, progressive_curve
            )

        rebuilt_rows.append(new_row)
        recalculated += 1

    return rebuilt_rows, effective_base_level, recalculated


def write_dbc(path: Path, rows: list[list[int]], string_block: bytes) -> None:
    if not string_block:
        string_block = b"\x00"

    record_count = len(rows)
    header = struct.pack(
        HEADER_FMT,
        b"WDBC",
        record_count,
        ROW_FIELD_COUNT,
        ROW_SIZE,
        len(string_block),
    )
    payload = b"".join(struct.pack(ROW_FMT, *row) for row in rows)
    path.write_bytes(header + payload + string_block)


def write_csv(path: Path, rows: list[list[int]], header: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows_sorted = sorted(rows, key=lambda r: r[1])

    if len(header) < ROW_FIELD_COUNT:
        header = DEFAULT_CSV_HEADER

    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerow(header[:ROW_FIELD_COUNT])
        writer.writerows(rows_sorted)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extend ScalingStatValues to a higher level cap and rebuild DBC"
    )
    parser.add_argument(
        "--source-csv",
        default="Custom/CSV DBC/ScalingStatValues.csv",
        help="CSV source file to read and extend",
    )
    parser.add_argument(
        "--dbc-input",
        default="Custom/DBCs/ScalingStatValues.dbc",
        help="Existing DBC used only to preserve string block metadata",
    )
    parser.add_argument(
        "--dbc-output",
        default="Custom/DBCs/ScalingStatValues.dbc",
        help="Output DBC file",
    )
    parser.add_argument(
        "--csv-output",
        default="Custom/CSV DBC/ScalingStatValues.csv",
        help="Output CSV file",
    )
    parser.add_argument(
        "--target-level",
        type=int,
        default=255,
        help="Highest character level row to generate",
    )
    parser.add_argument(
        "--base-level",
        type=int,
        default=80,
        help="Reference level used as the extrapolation baseline",
    )
    parser.add_argument(
        "--progressive-curve",
        type=float,
        default=DEFAULT_PROGRESSIVE_CURVE,
        help="Quadratic curve coefficient (higher means more progressive growth)",
    )
    args = parser.parse_args()

    source_csv = Path(args.source_csv)
    dbc_input = Path(args.dbc_input)
    dbc_output = Path(args.dbc_output)
    csv_output = Path(args.csv_output)

    csv_header, rows = parse_csv(source_csv)
    original_count = len(rows)

    if dbc_input.exists():
        _, string_block = parse_dbc(dbc_input)
    else:
        string_block = b"\x00"

    rows, base_level, recalculated = rebuild_rows_progressive(
        rows,
        args.target_level,
        args.base_level,
        args.progressive_curve,
    )
    rows_sorted = sorted(rows, key=lambda r: r[1])

    write_csv(csv_output, rows_sorted, csv_header)
    write_dbc(dbc_output, rows_sorted, string_block)

    print(
        f"Extended {source_csv}: {original_count} rows -> {len(rows_sorted)} rows"
    )
    print(f"Base level used for extrapolation: {base_level}")
    print(f"Rows recalculated above base: {recalculated}")
    print(f"Progressive curve coefficient: {args.progressive_curve}")
    print(f"CSV written: {csv_output}")
    print(f"DBC written: {dbc_output}")
    if recalculated > 0:
        print("Last 3 rows (Charlevel, SpellPower, WeaponDPS2H):")
        for row in rows_sorted[-3:]:
            print(f"  L{row[1]} SP={row[16]} DPS2H={row[11]}")


if __name__ == "__main__":
    main()
