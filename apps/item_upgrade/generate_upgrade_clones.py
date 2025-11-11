#!/usr/bin/env python3
"""Generate cloned item templates for the DarkChaos item upgrade system.

This utility reads the base `item_template.sql`, tier source lists (T1/T2), and the
Item.csv DBC extract. It produces:
  * `dc_item_upgrade_clones_generated.sql` containing item_template inserts,
    clone mapping metadata, and dc_item_templates_upgrade rows for the clones.
  * Updates `Custom/CSV DBC/Item.csv` with new clone rows so the client can display
    the cloned items.

Clone rules:
    * Tier 1 items receive 6 upgrade levels (7 stages including the base item).
    * Tier 2 items receive 15 upgrade levels (16 stages including the base item).
    * Item level 213+ automatically maps to Tier 2 (otherwise Tier 1).
  * Each upgrade level scales numeric stats by +3% per level relative to the base item.
  * Description is annotated with the upgrade level and base item id.
  * Clone entry ranges:
        Tier 1 clones start at 2,000,000.
        Tier 2 clones start at 2,500,000.

Re-running the generator is safe; existing clone rows in the configured id ranges will
be replaced in both the SQL output and Item.csv.
"""

from __future__ import annotations

import argparse
import ast
import csv
import math
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
BASE_ITEM_TEMPLATE_SQL_PATH = REPO_ROOT / "data" / "sql" / "base" / "db_world" / "item_template.sql"
CUSTOM_ITEM_TEMPLATE_SQL_PATH = REPO_ROOT / "Custom" / "Custom feature SQLs" / "item_template.sql"
T1_LIST_PATH = REPO_ROOT / "Custom" / "Custom feature SQLs" / "worlddb" / "ItemUpgrades" / "T1.txt"
T2_LIST_PATH = REPO_ROOT / "Custom" / "Custom feature SQLs" / "worlddb" / "ItemUpgrades" / "T2.txt"
ITEM_CSV_PATH = REPO_ROOT / "Custom" / "CSV DBC" / "Item.csv"
SQL_OUTPUT_PATH = REPO_ROOT / "Custom" / "Custom feature SQLs" / "worlddb" / "ItemUpgrades" / "dc_item_upgrade_clones_generated.sql"

T1_START_ID = 2_000_000
T2_START_ID = 2_500_000
T1_LEVELS = 6
T2_LEVELS = 15
LEVEL_INCREMENT = 0.03
TIER2_ILVL_THRESHOLD = 213
CSV_ID_MIN = T1_START_ID
CSV_ID_MAX = 3_000_000  # upper bound to remove outdated clones on re-run
NON_EQUIPPABLE_INVENTORY_TYPES = {0, 18}


@dataclass
class CloneSpec:
    base_entry: int
    tier_id: int
    upgrade_level: int
    clone_entry: int
    multiplier: float


class ItemTemplateData:
    def __init__(self, columns: List[str], rows: Dict[int, List[object]]):
        self.columns = columns
        self.rows = rows
        self.index = {name: idx for idx, name in enumerate(columns)}

    def get(self, entry: int) -> List[object] | None:
        data = self.rows.get(entry)
        return list(data) if data is not None else None


def extract_column_order(schema_path: Path) -> List[str]:
    cols: List[str] = []
    pattern = re.compile(r"^  `([^`]+)` ")
    in_table = False
    create_pattern = re.compile(r"^CREATE TABLE(?: IF NOT EXISTS)? `item_template`")
    with schema_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if create_pattern.match(line.strip()):
                in_table = True
                continue
            if not in_table:
                continue
            if line.startswith(") ENGINE"):
                break
            match = pattern.match(line)
            if match:
                cols.append(match.group(1))
    if not cols:
        raise RuntimeError("Failed to parse item_template column order from schema")
    return cols


def parse_sql_tuple(tuple_str: str) -> List[object]:
    candidate = tuple_str.strip().strip(',')
    if not candidate.startswith('(') or not candidate.endswith(')'):
        raise ValueError(f"Unexpected tuple format: {tuple_str[:80]}...")
    candidate = candidate[1:-1]
    # Replace SQL NULL tokens with Python None for literal_eval
    candidate = re.sub(r"\bNULL\b", "None", candidate)
    try:
        parsed = ast.literal_eval(f"({candidate})")
    except (SyntaxError, ValueError) as exc:
        raise ValueError(f"Failed to parse tuple: {tuple_str[:120]}") from exc
    return list(parsed)


def iter_item_template_rows(sql_path: Path) -> Iterable[List[object]]:
    buffer: List[str] = []
    in_insert = False
    with sql_path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not in_insert:
                if line.startswith("INSERT INTO `item_template`"):
                    in_insert = True
                continue
            if not line:
                continue
            buffer.append(line)
            if line.endswith(";"):
                joined = "".join(buffer)
                buffer.clear()
                in_insert = False
                for tuple_text in split_insert_values(joined[:-1]):
                    yield parse_sql_tuple(tuple_text)


def split_insert_values(payload: str) -> List[str]:
    """Split a payload like '(...),(...),(...)' into individual tuple strings."""
    result: List[str] = []
    depth = 0
    chunk_start = 0
    for idx, char in enumerate(payload):
        if char == '(':
            if depth == 0:
                chunk_start = idx
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                result.append(payload[chunk_start:idx + 1])
    return result


def load_item_template(schema_path: Path, sql_path: Path) -> ItemTemplateData:
    columns = extract_column_order(schema_path)
    rows: Dict[int, List[object]] = {}
    for row in iter_item_template_rows(sql_path):
        entry = coerce_int(row[0])
        if len(row) != len(columns):
            raise ValueError(f"Column mismatch for entry {entry}: expected {len(columns)}, got {len(row)}")
        rows[entry] = row
    return ItemTemplateData(columns, rows)


def load_tier_list(path: Path, id_column: str = "item_id") -> List[int]:
    entries: List[int] = []
    with path.open("r", encoding="utf-8") as handle:
        header = handle.readline().strip()
        if not header:
            return entries
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            parts = stripped.split(';')
            try:
                item_id = int(parts[0])
            except ValueError:
                continue
            entries.append(item_id)
    return entries


def load_item_csv(csv_path: Path) -> Tuple[List[str], List[List[str]]]:
    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        rows = list(reader)
    if not rows:
        raise RuntimeError(f"Item.csv at {csv_path} is empty")
    header = rows[0]
    data_rows = rows[1:]
    return header, data_rows


def write_item_csv(csv_path: Path, header: List[str], rows: Iterable[List[str]]) -> None:
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, quoting=csv.QUOTE_ALL)
        writer.writerow(header)
        writer.writerows(rows)


def escape_sql_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace("'", "\\'")
    return f"'{escaped}'"


def sql_literal(value: object) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return escape_sql_string(value)
    if isinstance(value, float):
        if abs(value) < 1e-9:
            value = 0.0
        text = f"{value:.6f}".rstrip('0').rstrip('.')
        if text == "-0":
            text = "0"
        return text
    return str(value)


def format_sql_row(row: List[object]) -> str:
    return "(" + ",".join(sql_literal(value) for value in row) + ")"


def chunked(sequence: List[List[object]], size: int) -> Iterable[List[List[object]]]:
    for idx in range(0, len(sequence), size):
        yield sequence[idx:idx + size]


def scale_int(value: object, scale: float) -> object:
    if value is None:
        return None
    if not isinstance(value, (int, float)):
        return value
    scaled = int(round(float(value) * scale))
    return scaled


def scale_float(value: object, scale: float) -> object:
    if value is None:
        return None
    if not isinstance(value, (int, float)):
        return value
    scaled = float(value) * scale
    return round(scaled, 6)


def coerce_int(value: object, default: int = 0) -> int:
    if value is None:
        return default
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return default
        try:
            return int(stripped)
        except ValueError:
            try:
                return int(float(stripped))
            except ValueError:
                return default
    return default


def build_description(base_desc: str, base_entry: int, upgrade_level: int) -> str:
    suffix = f" [Upgrade L{upgrade_level} • Base {base_entry}]"
    if not base_desc:
        return suffix.strip()
    max_len = 255
    if len(base_desc) + len(suffix) <= max_len:
        return base_desc + suffix
    # Trim base description to fit, keeping readable ending
    allowed = max_len - len(suffix) - 3  # 3 for ellipsis
    if allowed <= 0:
        return suffix.strip()
    return base_desc[:allowed] + "..." + suffix


def classify_armor_type(item_class: int, item_subclass: int) -> str:
    if item_class == 4:  # Armor
        mapping = {
            1: "cloth",
            2: "leather",
            3: "mail",
            4: "plate",
            6: "shield",
        }
        return mapping.get(item_subclass, "cosmetic")
    if item_class == 2:
        return "weapon"
    if item_class == 3:
        return "projectile"
    if item_class == 0:
        return "consumable"
    if item_class == 5:
        return "gems"
    if item_class == 11:
        return "quiver"
    if item_class == 15:
        return "mount"
    return "misc"


def default_upgrade_category(tier_id: int) -> str:
    return "common" if tier_id == 1 else "uncommon"


def generate_clones(item_template: ItemTemplateData,
                    tier1_entries: List[int],
                    tier2_entries: List[int]) -> Tuple[List[List[object]], List[List[str]], List[CloneSpec], List[str], Dict[int, Dict[str, int]]]:
    idx = item_template.index
    clones_sql: List[List[object]] = []
    clones_csv: List[List[str]] = []
    mappings: List[CloneSpec] = []
    warnings: List[str] = []
    stat_value_cols = [name for name in item_template.columns if name.startswith("stat_value")]
    stat_value_idx = [idx[name] for name in stat_value_cols]
    float_cols = ["dmg_min1", "dmg_max1", "dmg_min2", "dmg_max2", "ArmorDamageModifier"]
    float_idx = [idx[name] for name in float_cols if name in idx]
    int_cols = [
        "ItemLevel", "BuyPrice", "SellPrice", "armor", "holy_res", "fire_res", "nature_res",
        "frost_res", "shadow_res", "arcane_res", "block", "MaxDurability", "ScalingStatValue",
        "minMoneyLoot", "maxMoneyLoot"
    ]
    int_idx = [idx[name] for name in int_cols if name in idx]

    description_idx = idx["description"]
    name_idx = idx["name"]
    comment_idx = idx.get("comment")
    item_level_idx = idx.get("ItemLevel")
    csv_fields = ["entry", "class", "subclass", "SoundOverrideSubclass", "Material", "displayid", "InventoryType", "sheath"]
    csv_idx = [idx[field] for field in csv_fields]

    tier_summary: Dict[int, Dict[str, int]] = {
        1: {"bases": 0, "clones": 0, "missing": 0, "skipped": 0},
        2: {"bases": 0, "clones": 0, "missing": 0, "skipped": 0},
    }

    combined_entries: List[int] = sorted({entry for entry in (tier1_entries + tier2_entries) if entry < T1_START_ID})
    next_clone_entry = {1: T1_START_ID, 2: T2_START_ID}

    tier2_lookup = {entry for entry in tier2_entries if entry < T1_START_ID}

    for base_entry in combined_entries:
        base_row = item_template.get(base_entry)
        if base_row is None:
            tier_id = 2 if base_entry in tier2_lookup else 1
            warnings.append(f"Base item {base_entry} not found in item_template (tier {tier_id})")
            tier_summary[tier_id]["missing"] += 1
            continue

        base_item_level = coerce_int(base_row[item_level_idx]) if item_level_idx is not None else 0
        tier_id = 2 if base_item_level >= TIER2_ILVL_THRESHOLD else 1
        if base_entry in tier2_lookup:
            tier_id = 2

        levels = T2_LEVELS if tier_id == 2 else T1_LEVELS
        clone_entry = next_clone_entry[tier_id]

        inventory_type = coerce_int(base_row[idx["InventoryType"]])
        item_class = coerce_int(base_row[idx["class"]])
        if inventory_type in NON_EQUIPPABLE_INVENTORY_TYPES or inventory_type <= 0:
            warnings.append(
                f"Skipping base item {base_entry} ({base_row[idx['name']]}) due to inventory type {inventory_type}"
            )
            tier_summary[tier_id]["skipped"] += 1
            continue
        if item_class == 1:
            warnings.append(
                f"Skipping base item {base_entry} ({base_row[idx['name']]}) because it is a bag class ({item_class})"
            )
            tier_summary[tier_id]["skipped"] += 1
            continue

        tier_summary[tier_id]["bases"] += 1
        base_description = str(base_row[description_idx]) if base_row[description_idx] else ""
        base_name = str(base_row[name_idx]) if base_row[name_idx] else ""
        base_comment = str(base_row[comment_idx]) if (comment_idx is not None and base_row[comment_idx]) else ""

        for level in range(1, levels + 1):
            multiplier = 1.0 + LEVEL_INCREMENT * level
            clone_row = list(base_row)
            clone_row[idx["entry"]] = clone_entry
            clone_row[idx["name"]] = base_name
            clone_row[idx["description"]] = build_description(base_description, base_entry, level)

            if comment_idx is not None:
                comment_suffix = f"Upgrade clone of {base_entry} (tier {tier_id} level {level})"
                clone_comment = comment_suffix if not base_comment else f"{base_comment} | {comment_suffix}"
                clone_row[comment_idx] = clone_comment

            for position in stat_value_idx:
                clone_row[position] = scale_int(base_row[position], multiplier)

            for position in int_idx:
                clone_row[position] = scale_int(base_row[position], multiplier)

            for position in float_idx:
                clone_row[position] = scale_float(base_row[position], multiplier)

            clones_sql.append(clone_row)
            csv_row = [str(clone_row[position]) for position in csv_idx]
            clones_csv.append(csv_row)

            mappings.append(CloneSpec(
                base_entry=base_entry,
                tier_id=tier_id,
                upgrade_level=level,
                clone_entry=clone_entry,
                multiplier=round(multiplier, 6),
            ))

            clone_entry += 1
            tier_summary[tier_id]["clones"] += 1

        next_clone_entry[tier_id] = clone_entry

    return clones_sql, clones_csv, mappings, warnings, tier_summary


def build_mapping_rows(mappings: List[CloneSpec]) -> List[List[object]]:
    rows: List[List[object]] = []
    for spec in mappings:
        rows.append([
            spec.base_entry,
            spec.tier_id,
            spec.upgrade_level,
            spec.clone_entry,
            spec.multiplier,
        ])
    return rows


def build_templates_upgrade_rows(item_template: ItemTemplateData,
                                 mappings: List[CloneSpec]) -> List[List[object]]:
    idx = item_template.index
    rows: List[List[object]] = []
    for spec in mappings:
        base_row = item_template.rows.get(spec.base_entry)
        if base_row is None:
            continue
        item_class = coerce_int(base_row[idx["class"]])
        item_subclass = coerce_int(base_row[idx["subclass"]])
        armor_type = classify_armor_type(item_class, item_subclass)
        item_slot = coerce_int(base_row[idx["InventoryType"]])
        rarity = coerce_int(base_row[idx["Quality"]])
        base_ilvl = coerce_int(base_row[idx["ItemLevel"]])
        upgraded_ilvl = int(round(base_ilvl * spec.multiplier)) if base_ilvl > 0 else 0

        rows.append([
            spec.clone_entry,
            spec.tier_id,
            armor_type,
            item_slot,
            rarity,
            "clone",
            spec.base_entry,
            upgraded_ilvl,
            0,
            1,
            default_upgrade_category(spec.tier_id),
            1,
        ])
    return rows


def write_sql_output(output_path: Path,
                     columns: List[str],
                     clones_sql: List[List[object]],
                     mapping_rows: List[List[object]],
                     template_rows: List[List[object]]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        handle.write("-- Auto-generated by generate_upgrade_clones.py\n")
        handle.write("-- Timestamp: generated via script\n\n")
        handle.write("START TRANSACTION;\n\n")

        handle.write(f"DELETE FROM `item_template` WHERE `entry` BETWEEN {T1_START_ID} AND {CSV_ID_MAX};\n")
        handle.write(f"DELETE FROM `dc_item_upgrade_clones` WHERE `clone_item_id` BETWEEN {T1_START_ID} AND {CSV_ID_MAX};\n")
        handle.write(f"DELETE FROM `dc_item_templates_upgrade` WHERE `item_id` BETWEEN {T1_START_ID} AND {CSV_ID_MAX};\n\n")

        handle.write("CREATE TABLE IF NOT EXISTS `dc_item_upgrade_clones` (\n"
                     "  `base_item_id` INT UNSIGNED NOT NULL,\n"
                     "  `tier_id` TINYINT UNSIGNED NOT NULL,\n"
                     "  `upgrade_level` TINYINT UNSIGNED NOT NULL,\n"
                     "  `clone_item_id` INT UNSIGNED NOT NULL,\n"
                     "  `stat_multiplier` FLOAT NOT NULL,\n"
                     "  PRIMARY KEY (`base_item_id`, `upgrade_level`),\n"
                     "  UNIQUE KEY `idx_clone_item` (`clone_item_id`),\n"
                     "  KEY `idx_tier_level` (`tier_id`, `upgrade_level`)\n"
                     ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci\n"
                     "  COMMENT='Generated item clone mapping';\n\n")

        insert_header = "INSERT INTO `item_template` (" + ",".join(f"`{col}`" for col in columns) + ") VALUES\n"
        for chunk in chunked(clones_sql, 100):
            handle.write(insert_header)
            handle.write(",\n".join(format_sql_row(row) for row in chunk))
            handle.write(";\n\n")

        mapping_header = "INSERT INTO `dc_item_upgrade_clones` (`base_item_id`,`tier_id`,`upgrade_level`,`clone_item_id`,`stat_multiplier`) VALUES\n"
        for chunk in chunked(mapping_rows, 200):
            handle.write(mapping_header)
            handle.write(",\n".join(format_sql_row(row) for row in chunk))
            handle.write(";\n\n")

        templates_header = ("INSERT INTO `dc_item_templates_upgrade` "
                            "(`item_id`,`tier_id`,`armor_type`,`item_slot`,`rarity`,`source_type`,`source_id`,"
                            "`base_stat_value`,`cosmetic_variant`,`is_active`,`upgrade_category`,`season`) VALUES\n")
        for chunk in chunked(template_rows, 200):
            handle.write(templates_header)
            handle.write(",\n".join(format_sql_row(row) for row in chunk))
            handle.write(";\n\n")

        handle.write("COMMIT;\n")


def update_item_csv(csv_header: List[str],
                    csv_rows: List[List[str]],
                    clones_csv: List[List[str]]) -> List[List[str]]:
    filtered_rows: List[List[str]] = []
    for row in csv_rows:
        if not row:
            continue
        try:
            item_id = int(row[0])
        except ValueError:
            filtered_rows.append(row)
            continue
        if CSV_ID_MIN <= item_id <= CSV_ID_MAX:
            continue
        filtered_rows.append(row)

    filtered_rows.extend(clones_csv)
    return filtered_rows


def prune_columns_for_output(columns: List[str],
                             rows: List[List[object]],
                             drop_columns: Iterable[str]) -> Tuple[List[str], List[List[object]]]:
    drop_set = {col for col in drop_columns if col in columns}
    if not drop_set:
        return columns, rows

    keep_indices = [idx for idx, col in enumerate(columns) if col not in drop_set]
    pruned_columns = [columns[idx] for idx in keep_indices]

    pruned_rows: List[List[object]] = []
    for row in rows:
        pruned_rows.append([row[idx] for idx in keep_indices])

    return pruned_columns, pruned_rows


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate item upgrade clone data")
    parser.add_argument(
        "--item-template-sql",
        dest="item_template_sql",
        default=None,
        help="Path to item_template SQL export to use as the clone source",
    )
    parser.add_argument(
        "--schema-sql",
        dest="schema_sql",
        default=None,
        help="Optional path whose CREATE TABLE statement determines column order (defaults to item-template-sql)",
    )
    parser.add_argument(
        "--drop-column",
        dest="drop_columns",
        action="append",
        default=[],
        help="Item_template column to omit from generated SQL output (may be supplied multiple times)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.item_template_sql:
        item_template_sql_path = Path(args.item_template_sql).expanduser().resolve()
    elif CUSTOM_ITEM_TEMPLATE_SQL_PATH.exists():
        item_template_sql_path = CUSTOM_ITEM_TEMPLATE_SQL_PATH
    else:
        item_template_sql_path = BASE_ITEM_TEMPLATE_SQL_PATH

    if not item_template_sql_path.exists():
        raise FileNotFoundError(f"item_template SQL source not found: {item_template_sql_path}")

    if args.schema_sql:
        schema_path = Path(args.schema_sql).expanduser().resolve()
    else:
        schema_path = item_template_sql_path if item_template_sql_path.exists() else BASE_ITEM_TEMPLATE_SQL_PATH

    if not schema_path.exists():
        raise FileNotFoundError(f"Schema SQL file not found: {schema_path}")

    item_template = load_item_template(schema_path, item_template_sql_path)
    tier1_entries = load_tier_list(T1_LIST_PATH)
    tier2_entries = load_tier_list(T2_LIST_PATH)

    clones_sql, clones_csv, mappings, warnings, tier_summary = generate_clones(item_template, tier1_entries, tier2_entries)
    mapping_rows = build_mapping_rows(mappings)
    template_rows = build_templates_upgrade_rows(item_template, mappings)

    emit_columns, emit_clone_rows = prune_columns_for_output(item_template.columns, clones_sql, args.drop_columns)
    write_sql_output(SQL_OUTPUT_PATH, emit_columns, emit_clone_rows, mapping_rows, template_rows)

    header, rows = load_item_csv(ITEM_CSV_PATH)
    updated_rows = update_item_csv(header, rows, clones_csv)
    write_item_csv(ITEM_CSV_PATH, header, updated_rows)

    print(f"Generated {len(clones_sql)} cloned item_template rows")
    print(f"Generated {len(mapping_rows)} clone mappings")
    print(f"Updated Item.csv with {len(updated_rows)} rows total")
    if args.drop_columns:
        print(f"Omitted columns in SQL output: {', '.join(sorted(set(args.drop_columns)))}")
    for tier_id in sorted(tier_summary):
        summary = tier_summary[tier_id]
        print(
            f"Tier {tier_id}: {summary['bases']} base items, {summary['clones']} clones, "
            f"{summary['missing']} missing bases, {summary['skipped']} skipped"
        )
    if warnings:
        print("Warnings:")
        for message in warnings:
            print(f"  - {message}")


if __name__ == "__main__":
    main()
