#!/usr/bin/env python3
"""Generate DC item-upgrade tier custom CDBC assets from repo-local SQL."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

from generate_dc_collection_cdbc import (
    build_csv_content,
    build_wdbc_bytes,
    escape_lua_string,
    float_or_default,
    int_or_default,
    load_item_template_rows,
    parse_sql_columns,
    parse_sql_value_rows,
    split_sql_statements,
    text_or_empty,
    write_if_changed,
    write_text_if_changed,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
ITEM_UPGRADE_SQL_DIR = (
    REPO_ROOT
    / "Custom"
    / "Custom feature SQLs"
    / "worlddb"
    / "ItemUpgrades"
)

DEFAULT_SOURCE_FILES = (
    ITEM_UPGRADE_SQL_DIR / "ItemUpgrade_Schema_WORLD.sql",
    ITEM_UPGRADE_SQL_DIR / "populate_upgrade_tier_definitions.sql",
    ITEM_UPGRADE_SQL_DIR / "POPULATE_tier_definitions.sql",
)

DEFAULT_TIER_ITEM_SOURCE_FILES = tuple(sorted(ITEM_UPGRADE_SQL_DIR.glob("*.sql")))

CSV_OUTPUT = (
    REPO_ROOT / "Custom" / "CSV DBC" / "CDBC" / "DCItemUpgradeTier.csv"
)
CDBC_OUTPUT = REPO_ROOT / "Custom" / "CDBCs" / "DCItemUpgradeTier.cdbc"
PATCH_OUTPUT = (
    REPO_ROOT
    / "Custom"
    / "Client patches needed"
    / "patch-4"
    / "DBFilesClient"
    / "DCItemUpgradeTier.cdbc"
)
LUA_OUTPUT = (
    REPO_ROOT
    / "Custom"
    / "Client addons needed"
    / "DC-ItemUpgrade"
    / "Data"
    / "TierStatic.lua"
)

TIER_ITEM_CSV_OUTPUT = (
    REPO_ROOT / "Custom" / "CSV DBC" / "CDBC" / "DCItemUpgradeTierItem.csv"
)
TIER_ITEM_CDBC_OUTPUT = (
    REPO_ROOT / "Custom" / "CDBCs" / "DCItemUpgradeTierItem.cdbc"
)
TIER_ITEM_PATCH_OUTPUT = (
    REPO_ROOT
    / "Custom"
    / "Client patches needed"
    / "patch-4"
    / "DBFilesClient"
    / "DCItemUpgradeTierItem.cdbc"
)
TIER_ITEM_LUA_OUTPUT = (
    REPO_ROOT
    / "Custom"
    / "Client addons needed"
    / "DC-ItemUpgrade"
    / "Data"
    / "TierItemStatic.lua"
)

TIER_SCHEMA = (
    ("ID", "int"),
    ("TierID", "int"),
    ("Season", "int"),
    ("SortOrder", "int"),
    ("Flags", "int"),
    ("MinItemLevel", "int"),
    ("MaxItemLevel", "int"),
    ("MaxUpgradeLevel", "int"),
    ("StatMultiplierMax", "float"),
    ("UpgradeCostPerLevel", "int"),
    ("IsArtifact", "int"),
    ("Enabled", "int"),
    ("ColorARGB", "int"),
    ("Name", "string"),
    ("Description", "string"),
    ("SourceContent", "string"),
    ("Icon", "string"),
)

TIER_ITEM_SCHEMA = (
    ("ID", "int"),
    ("TierID", "int"),
    ("ItemID", "int"),
    ("SortOrder", "int"),
    ("Flags", "int"),
    ("Quality", "int"),
    ("InventoryType", "int"),
    ("ItemLevel", "int"),
)

DEFAULT_TIER_METADATA: dict[int, dict[str, Any]] = {
    1: {
        "SortOrder": 10,
        "Icon": "Interface\\Icons\\INV_Misc_Coin_01",
        "ColorARGB": 0xFF999999,
        "MaxUpgradeLevel": 6,
        "StatMultiplierMax": 2.0,
        "UpgradeCostPerLevel": 50,
    },
    2: {
        "SortOrder": 20,
        "Icon": "Interface\\Icons\\INV_Misc_Coin_02",
        "ColorARGB": 0xFF33CC33,
        "MaxUpgradeLevel": 15,
        "StatMultiplierMax": 1.5,
        "UpgradeCostPerLevel": 100,
    },
    3: {
        "SortOrder": 30,
        "Icon": "Interface\\Icons\\INV_Misc_Coin_03",
        "ColorARGB": 0xFF3366FF,
        "MaxUpgradeLevel": 80,
        "StatMultiplierMax": 2.5,
        "UpgradeCostPerLevel": 200,
    },
    4: {
        "SortOrder": 40,
        "Icon": "Interface\\Icons\\INV_Misc_Coin_04",
        "ColorARGB": 0xFFCC33CC,
        "MaxUpgradeLevel": 8,
        "StatMultiplierMax": 1.75,
        "UpgradeCostPerLevel": 250,
    },
    5: {
        "SortOrder": 50,
        "Icon": "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
        "ColorARGB": 0xFFFF8000,
        "MaxUpgradeLevel": 12,
        "StatMultiplierMax": 2.0,
        "UpgradeCostPerLevel": 300,
    },
}


def to_signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    if value >= 0x80000000:
        value -= 0x100000000
    return value


def first_text(row: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        text = text_or_empty(value).strip()
        if text:
            return text
    return ""


def first_int(row: dict[str, Any], *keys: str, default: int = 0) -> int:
    for key in keys:
        if key in row and row[key] not in (None, ""):
            return int_or_default(row.get(key), default)
    return default


def first_float(
    row: dict[str, Any], *keys: str, default: float = 0.0
) -> float:
    for key in keys:
        if key in row and row[key] not in (None, ""):
            return float_or_default(row.get(key), default)
    return default


def normalize_insert_row(raw_row: dict[str, Any]) -> dict[str, Any] | None:
    tier_id = first_int(raw_row, "tier_id", "TierID", "ID")
    if tier_id <= 0:
        return None

    season = first_int(raw_row, "season", "Season", default=1)
    if season <= 0:
        season = 1

    defaults = DEFAULT_TIER_METADATA.get(tier_id, {})
    is_artifact = first_int(raw_row, "is_artifact", "IsArtifact", default=0)

    normalized = {
        "TierID": tier_id,
        "Season": season,
        "SortOrder": first_int(
            raw_row,
            "sort_order",
            "SortOrder",
            default=int_or_default(defaults.get("SortOrder"), tier_id * 10),
        ),
        "Flags": first_int(raw_row, "flags", "Flags", default=0),
        "MinItemLevel": first_int(
            raw_row,
            "min_ilvl",
            "min_item_level",
            "MinItemLevel",
            default=0,
        ),
        "MaxItemLevel": first_int(
            raw_row,
            "max_ilvl",
            "max_item_level",
            "MaxItemLevel",
            default=0,
        ),
        "MaxUpgradeLevel": first_int(
            raw_row,
            "max_upgrade_level",
            "max_level",
            "MaxUpgradeLevel",
            default=int_or_default(defaults.get("MaxUpgradeLevel"), 15),
        ),
        "StatMultiplierMax": first_float(
            raw_row,
            "stat_multiplier_max",
            "StatMultiplierMax",
            default=float_or_default(defaults.get("StatMultiplierMax"), 1.5),
        ),
        "UpgradeCostPerLevel": first_int(
            raw_row,
            "upgrade_cost_per_level",
            "UpgradeCostPerLevel",
            default=int_or_default(defaults.get("UpgradeCostPerLevel"), 0),
        ),
        "IsArtifact": 1 if is_artifact else 0,
        "Enabled": first_int(
            raw_row,
            "is_active",
            "enabled",
            "Enabled",
            default=1,
        ),
        "ColorARGB": first_int(
            raw_row,
            "color_argb",
            "ColorARGB",
            default=to_signed32(
                int_or_default(defaults.get("ColorARGB"), 0xFFFFFFFF)
            ),
        ),
        "Name": first_text(raw_row, "tier_name", "name", "Name"),
        "Description": first_text(raw_row, "description", "Description"),
        "SourceContent": first_text(
            raw_row,
            "source_content",
            "SourceContent",
        ),
        "Icon": first_text(
            raw_row,
            "icon",
            "Icon",
        )
        or text_or_empty(defaults.get("Icon")),
    }

    if normalized["Flags"] == 0 and normalized["IsArtifact"] == 1:
        normalized["Flags"] = 1

    normalized["ColorARGB"] = to_signed32(
        int_or_default(normalized.get("ColorARGB"), 0xFFFFFFFF)
    )

    return normalized


def merge_rows(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in override.items():
        if value is None:
            continue
        if isinstance(value, str):
            if value == "":
                continue
        merged[key] = value
    return merged


def load_tier_rows(source_files: list[Path]) -> list[dict[str, Any]]:
    insert_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?dc_item_upgrade_tiers`?\s*\((.*?)\)\s*VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )

    rows_by_key: dict[tuple[int, int], dict[str, Any]] = {}

    for path in source_files:
        if not path.exists():
            continue

        sql_text = path.read_text(encoding="utf-8")
        if "dc_item_upgrade_tiers" not in sql_text.lower():
            continue

        for statement in split_sql_statements(sql_text):
            match = insert_re.match(statement)
            if not match:
                continue

            columns = parse_sql_columns(match.group(1))
            values_sql = re.split(
                r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                match.group(2),
                maxsplit=1,
                flags=re.IGNORECASE,
            )[0]
            for raw_values in parse_sql_value_rows(values_sql):
                raw_row = {
                    columns[index]: raw_values[index]
                    for index in range(min(len(columns), len(raw_values)))
                }
                normalized = normalize_insert_row(raw_row)
                if normalized is None:
                    continue

                key = (normalized["Season"], normalized["TierID"])
                current = rows_by_key.get(key, {})
                rows_by_key[key] = merge_rows(current, normalized)

    rows: list[dict[str, Any]] = []
    for season, tier_id in sorted(rows_by_key):
        row = dict(rows_by_key[(season, tier_id)])
        row["ID"] = (season * 1000) + tier_id
        rows.append(row)

    return rows


def normalize_tier_item_row(
    raw_row: dict[str, Any], item_template_rows: dict[int, dict[str, Any]]
) -> dict[str, Any] | None:
    item_id = first_int(raw_row, "item_id", "ItemID")
    tier_id = first_int(raw_row, "tier_id", "TierID")

    if item_id <= 0 or tier_id <= 0:
        return None
    if 2_000_000 <= item_id <= 2_999_999:
        return None

    enabled = first_int(raw_row, "is_active", "Enabled", default=1)
    if enabled <= 0:
        return None

    season = first_int(raw_row, "season", "Season", default=1)
    if season <= 0:
        season = 1

    item_row = item_template_rows.get(item_id, {})

    return {
        "Season": season,
        "TierID": tier_id,
        "ItemID": item_id,
        "SortOrder": first_int(raw_row, "sort_order", "SortOrder", default=0),
        "Flags": first_int(raw_row, "flags", "Flags", default=0),
        "Quality": first_int(
            raw_row,
            "quality",
            "Quality",
            default=int_or_default(item_row.get("Quality"), 0),
        ),
        "InventoryType": first_int(
            raw_row,
            "inventory_type",
            "InventoryType",
            default=int_or_default(item_row.get("InventoryType"), 0),
        ),
        "ItemLevel": first_int(
            raw_row,
            "item_level",
            "ItemLevel",
            "base_stat_value",
            default=int_or_default(item_row.get("ItemLevel"), 0),
        ),
    }


def load_tier_item_rows(
    source_files: list[Path], item_template_rows: dict[int, dict[str, Any]]
) -> list[dict[str, Any]]:
    insert_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?dc_item_templates_upgrade`?\s*\((.*?)\)\s*VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )

    rows_by_key: dict[tuple[int, int, int], dict[str, Any]] = {}
    tier_positions: dict[tuple[int, int], int] = {}

    for path in source_files:
        if not path.exists():
            continue

        sql_text = path.read_text(encoding="utf-8")
        if "dc_item_templates_upgrade" not in sql_text.lower():
            continue

        for statement in split_sql_statements(sql_text):
            match = insert_re.match(statement)
            if not match:
                continue

            columns = parse_sql_columns(match.group(1))
            values_sql = re.split(
                r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                match.group(2),
                maxsplit=1,
                flags=re.IGNORECASE,
            )[0]

            for raw_values in parse_sql_value_rows(values_sql):
                raw_row = {
                    columns[index]: raw_values[index]
                    for index in range(min(len(columns), len(raw_values)))
                }
                normalized = normalize_tier_item_row(raw_row, item_template_rows)
                if normalized is None:
                    continue

                key = (
                    normalized["Season"],
                    normalized["TierID"],
                    normalized["ItemID"],
                )
                tier_key = (normalized["Season"], normalized["TierID"])
                if key in rows_by_key:
                    normalized["__order"] = rows_by_key[key].get("__order", 0)
                    rows_by_key[key] = merge_rows(rows_by_key[key], normalized)
                    continue

                tier_positions[tier_key] = tier_positions.get(tier_key, 0) + 1
                normalized["__order"] = tier_positions[tier_key]
                rows_by_key[key] = normalized

    rows: list[dict[str, Any]] = []
    for season, tier_id, item_id in sorted(rows_by_key):
        row = dict(rows_by_key[(season, tier_id, item_id)])
        if int_or_default(row.get("SortOrder"), 0) <= 0:
            row["SortOrder"] = int_or_default(row.get("__order"), 0) * 10
        row["ID"] = (season * 100_000_000) + (tier_id * 10_000_000) + item_id
        row.pop("Season", None)
        row.pop("__order", None)
        rows.append(row)

    rows.sort(
        key=lambda row: (
            int_or_default(row.get("TierID"), 0),
            int_or_default(row.get("SortOrder"), 0),
            int_or_default(row.get("ItemID"), 0),
        )
    )

    return rows


def build_tier_lua_content(rows: list[dict[str, Any]]) -> str:
    field_map = (
        ("id", "ID", "int"),
        ("tierId", "TierID", "int"),
        ("season", "Season", "int"),
        ("sortOrder", "SortOrder", "int"),
        ("flags", "Flags", "int"),
        ("minItemLevel", "MinItemLevel", "int"),
        ("maxItemLevel", "MaxItemLevel", "int"),
        ("maxUpgradeLevel", "MaxUpgradeLevel", "int"),
        ("statMultiplierMax", "StatMultiplierMax", "float"),
        ("upgradeCostPerLevel", "UpgradeCostPerLevel", "int"),
        ("isArtifact", "IsArtifact", "int"),
        ("enabled", "Enabled", "int"),
        ("colorARGB", "ColorARGB", "int"),
        ("name", "Name", "string"),
        ("description", "Description", "string"),
        ("sourceContent", "SourceContent", "string"),
        ("icon", "Icon", "string"),
    )

    lines = [
        "-- Auto-generated by tools/generate_dc_item_upgrade_cdbc.py. Do not edit.",
        "local DC = DarkChaos_ItemUpgrade",
        "DC.TIER_STATIC_DATA = {",
    ]

    for row in rows:
        lines.append("    {")
        for lua_key, row_key, field_type in field_map:
            raw_value = row.get(row_key)
            if field_type == "int":
                int_value = int_or_default(raw_value, 0)
                if lua_key == "colorARGB" and int_value < 0:
                    int_value += 1 << 32
                value = str(int_value)
            elif field_type == "float":
                value = (
                    f"{float_or_default(raw_value, 0.0):.6f}".rstrip("0").rstrip(".")
                    or "0"
                )
            else:
                value = escape_lua_string(raw_value)
            lines.append(f"        {lua_key} = {value},")
        lines.append("    },")

    lines.extend(
        [
            "}",
            f"DC.TIER_STATIC_DATA_COUNT = {len(rows)}",
            "DC.TIER_STATIC_DATA_VERSION = 1",
            'if type(DC.BootstrapTierDefinitions) == "function" then',
            "    DC.BootstrapTierDefinitions()",
            "end",
            "",
        ]
    )
    return "\n".join(lines)


def build_tier_item_lua_content(rows: list[dict[str, Any]]) -> str:
    field_map = (
        ("id", "ID", "int"),
        ("tierId", "TierID", "int"),
        ("itemId", "ItemID", "int"),
        ("sortOrder", "SortOrder", "int"),
        ("flags", "Flags", "int"),
        ("quality", "Quality", "int"),
        ("inventoryType", "InventoryType", "int"),
        ("itemLevel", "ItemLevel", "int"),
    )

    lines = [
        "-- Auto-generated by tools/generate_dc_item_upgrade_cdbc.py. Do not edit.",
        "local DC = DarkChaos_ItemUpgrade",
        "DC.TIER_ITEM_STATIC_DATA = {",
    ]

    for row in rows:
        lines.append("    {")
        for lua_key, row_key, _field_type in field_map:
            value = str(int_or_default(row.get(row_key), 0))
            lines.append(f"        {lua_key} = {value},")
        lines.append("    },")

    lines.extend(
        [
            "}",
            f"DC.TIER_ITEM_STATIC_DATA_COUNT = {len(rows)}",
            "DC.TIER_ITEM_STATIC_DATA_VERSION = 1",
            'if type(DC.BootstrapTierItemData) == "function" then',
            "    DC.BootstrapTierItemData()",
            "end",
            "",
        ]
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate DC item-upgrade tier CDBC assets from repo SQL.",
    )
    parser.add_argument(
        "--source",
        action="append",
        type=Path,
        help="Optional SQL source file. May be provided multiple times.",
    )
    parser.add_argument(
        "--tier-item-source",
        dest="tier_item_source",
        action="append",
        type=Path,
        help=(
            "Optional SQL source file for tier-item browse rows. "
            "May be provided multiple times."
        ),
    )
    parser.add_argument(
        "--skip-patch-copy",
        action="store_true",
        help="Do not mirror the generated CDBC into the client patch folder.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    tier_source_files = args.source or list(DEFAULT_SOURCE_FILES)
    tier_item_source_files = (
        args.tier_item_source or list(DEFAULT_TIER_ITEM_SOURCE_FILES)
    )

    tier_rows = load_tier_rows(tier_source_files)
    if not tier_rows:
        raise SystemExit(
            "No item-upgrade tier rows found in source SQL. Check the configured source files."
        )

    item_template_rows = load_item_template_rows(REPO_ROOT)
    tier_item_rows = load_tier_item_rows(
        tier_item_source_files, item_template_rows
    )
    if not tier_item_rows:
        raise SystemExit(
            "No item-upgrade tier-item rows found in source SQL. Check the configured source files."
        )

    csv_content = build_csv_content(tier_rows, TIER_SCHEMA)
    cdbc_bytes = build_wdbc_bytes(tier_rows, TIER_SCHEMA)
    lua_content = build_tier_lua_content(tier_rows)

    tier_item_csv_content = build_csv_content(tier_item_rows, TIER_ITEM_SCHEMA)
    tier_item_cdbc_bytes = build_wdbc_bytes(tier_item_rows, TIER_ITEM_SCHEMA)
    tier_item_lua_content = build_tier_item_lua_content(tier_item_rows)

    updated_paths: list[Path] = []

    if write_text_if_changed(CSV_OUTPUT, csv_content):
        updated_paths.append(CSV_OUTPUT)
    if write_if_changed(CDBC_OUTPUT, cdbc_bytes):
        updated_paths.append(CDBC_OUTPUT)
    if not args.skip_patch_copy and write_if_changed(PATCH_OUTPUT, cdbc_bytes):
        updated_paths.append(PATCH_OUTPUT)
    if write_text_if_changed(LUA_OUTPUT, lua_content):
        updated_paths.append(LUA_OUTPUT)

    if write_text_if_changed(TIER_ITEM_CSV_OUTPUT, tier_item_csv_content):
        updated_paths.append(TIER_ITEM_CSV_OUTPUT)
    if write_if_changed(TIER_ITEM_CDBC_OUTPUT, tier_item_cdbc_bytes):
        updated_paths.append(TIER_ITEM_CDBC_OUTPUT)
    if not args.skip_patch_copy and write_if_changed(
        TIER_ITEM_PATCH_OUTPUT, tier_item_cdbc_bytes
    ):
        updated_paths.append(TIER_ITEM_PATCH_OUTPUT)
    if write_text_if_changed(TIER_ITEM_LUA_OUTPUT, tier_item_lua_content):
        updated_paths.append(TIER_ITEM_LUA_OUTPUT)

    print(f"Generated {len(tier_rows)} DC item-upgrade tier rows.")
    print(f"Generated {len(tier_item_rows)} DC item-upgrade tier-item rows.")
    if updated_paths:
        print("Updated outputs:")
        for path in updated_paths:
            print(f"- {path}")
    else:
        print("Outputs already up to date.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())