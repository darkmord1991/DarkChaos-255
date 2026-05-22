#!/usr/bin/env python3
"""Generate DC collection custom CDBC assets from repo-local sources."""

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import struct
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]

COLLECTION_SQL_GLOBS = (
    "Custom/Custom feature SQLs/worlddb/CollectionSystem/*.sql",
    "Custom/Custom feature SQLs/worlddb/Retroports/*.sql",
    # Load extracted live tables last so they override repo fallback/sample rows.
    "Custom/Custom feature SQLs/collectionextracts/*.sql",
)

ITEM_TEMPLATE_SQL_CANDIDATES = (
    "Custom/Custom feature SQLs/worlddb/item_template.sql",
    "data/sql/base/db_world/item_template.sql",
)

CREATURE_TEMPLATE_MODEL_SQL_CANDIDATES = (
    "Custom/Custom feature SQLs/worlddb/creature_template_model.sql",
    "data/sql/base/db_world/creature_template_model.sql",
)

SPELL_EFFECT_SUMMON = 28
SPELL_EFFECT_LEARN_SPELL = 36
SPELL_EFFECT_SUMMON_PET = 56
SPELL_EFFECT_LEARN_PET_SPELL = 57
SPELL_EFFECT_TRIGGER_SPELL = 64

COLLECTION_DEFINITION_INDEX_TABLE = "dc_collection_definitions"

TABLE_KEY_COLUMNS = {
    "dc_mount_definitions": "spell_id",
    "dc_pet_definitions": "pet_entry",
    "dc_heirloom_definitions": "item_id",
    "dc_title_definitions": "title_id",
    "dc_collection_shop": "id",
}

COLLECTION_TYPE_LABELS = {
    0: "bonus",
    1: "mount",
    2: "pet",
    3: "toy",
    4: "heirloom",
    5: "title",
    6: "transmog",
    7: "itemset",
}

CATEGORY_IDS = {
    "bonus": 1,
    "mount": 2,
    "pet": 3,
    "heirloom": 4,
    "title": 5,
    "transmog": 6,
    "itemset": 7,
}

DISABLED_LOCAL_PET_ENTRY_IDS = {
    13342,
    13343,
    22200,
    28326,
    33817,
    34495,
    35227,
    37460,
    38234,
    38299,
    38612,
    40355,
    44820,
    44823,
    44824,
    44825,
    44826,
    44827,
    44828,
    44829,
    46890,
    46891,
    46894,
    49659,
    49660,
    49664,
    49911,
    50151,
}

# Curated preview metadata for real companion sources that the generic
# item-template spell walk cannot resolve from repo-local data alone.
CURATED_PET_PREVIEW_OVERRIDES: dict[int, tuple[int, int, int]] = {
    4055: (61855, 16189, 32841),
    7544: (15067, 6294, 9662),
    10673: (15048, 8909, 9656),
    15186: (26010, 15671, 15710),
    18963: (23428, 14661, 14633),
    18965: (23432, 14660, 14632),
    18966: (23431, 14658, 14630),
    18967: (23430, 14659, 14631),
    19462: (23811, 14938, 14878),
    33199: (43461, 28397, 32939),
    34364: (44369, 26452, 29726),
    34724: (71840, 31073, 38374),
    36871: (61472, 14273, 32643),
}

CATEGORY_ROWS = (
    {
        "ID": CATEGORY_IDS["bonus"],
        "CollectionType": 0,
        "ParentID": -1,
        "SortOrder": 10,
        "Flags": 0,
        "Key": "bonus",
        "Name": "Bonuses",
        "Icon": "Interface\\Icons\\INV_Misc_Coin_02",
    },
    {
        "ID": CATEGORY_IDS["mount"],
        "CollectionType": 1,
        "ParentID": -1,
        "SortOrder": 20,
        "Flags": 0,
        "Key": "mount",
        "Name": "Mounts",
        "Icon": "Interface\\Icons\\Ability_Mount_RidingHorse",
    },
    {
        "ID": CATEGORY_IDS["pet"],
        "CollectionType": 2,
        "ParentID": -1,
        "SortOrder": 30,
        "Flags": 0,
        "Key": "pet",
        "Name": "Pets",
        "Icon": "Interface\\Icons\\INV_Box_PetCarrier_01",
    },
    {
        "ID": CATEGORY_IDS["heirloom"],
        "CollectionType": 4,
        "ParentID": -1,
        "SortOrder": 40,
        "Flags": 0,
        "Key": "heirloom",
        "Name": "Heirlooms",
        "Icon": "Interface\\Icons\\INV_Chest_Chain_17",
    },
    {
        "ID": CATEGORY_IDS["title"],
        "CollectionType": 5,
        "ParentID": -1,
        "SortOrder": 50,
        "Flags": 0,
        "Key": "title",
        "Name": "Titles",
        "Icon": "Interface\\Icons\\INV_Scroll_11",
    },
    {
        "ID": CATEGORY_IDS["transmog"],
        "CollectionType": 6,
        "ParentID": -1,
        "SortOrder": 60,
        "Flags": 0,
        "Key": "transmog",
        "Name": "Appearances",
        "Icon": "Interface\\Icons\\INV_Chest_Cloth_17",
    },
    {
        "ID": CATEGORY_IDS["itemset"],
        "CollectionType": 7,
        "ParentID": -1,
        "SortOrder": 70,
        "Flags": 0,
        "Key": "itemset",
        "Name": "Item Sets",
        "Icon": "Interface\\Icons\\INV_Chest_Chain_17",
    },
)

CATEGORY_SCHEMA = (
    ("ID", "int"),
    ("CollectionType", "int"),
    ("ParentID", "int"),
    ("SortOrder", "int"),
    ("Flags", "int"),
    ("Key", "string"),
    ("Name", "string"),
    ("Icon", "string"),
)

SOURCE_SCHEMA = (
    ("ID", "int"),
    ("CollectionType", "int"),
    ("EntryID", "int"),
    ("CategoryID", "int"),
    ("SortOrder", "int"),
    ("Flags", "int"),
    ("Rarity", "int"),
    ("ItemID", "int"),
    ("SpellID", "int"),
    ("DisplayID", "int"),
    ("CreatureID", "int"),
    ("MountType", "int"),
    ("SourceObjectID", "int"),
    ("SourceValue", "float"),
    ("Name", "string"),
    ("Icon", "string"),
    ("SourceType", "string"),
    ("SourceName", "string"),
    ("SourceText", "string"),
)

SHOP_STATIC_SCHEMA = (
    ("ShopID", "int"),
    ("CollectionType", "int"),
    ("CollectionTypeName", "string"),
    ("EntryID", "int"),
    ("ItemID", "int"),
    ("SpellID", "int"),
    ("AppearanceID", "int"),
    ("DisplayID", "int"),
    ("CreatureID", "int"),
    ("MountType", "int"),
    ("Rarity", "int"),
    ("PriceTokens", "int"),
    ("PriceEmblems", "int"),
    ("DiscountPercent", "int"),
    ("Featured", "int"),
    ("Enabled", "int"),
    ("StockRemaining", "int"),
    ("AvailableFrom", "string"),
    ("AvailableUntil", "string"),
    ("Name", "string"),
    ("Icon", "string"),
    ("SourceType", "string"),
    ("SourceName", "string"),
    ("SourceText", "string"),
)

SHOP_SCHEMA = (
    ("ShopID", "int"),
    ("CollectionType", "int"),
    ("EntryID", "int"),
    ("ItemID", "int"),
    ("SpellID", "int"),
    ("AppearanceID", "int"),
    ("DisplayID", "int"),
    ("CreatureID", "int"),
    ("MountType", "int"),
    ("Rarity", "int"),
    ("PriceTokens", "int"),
    ("PriceEmblems", "int"),
    ("DiscountPercent", "int"),
    ("Featured", "int"),
    ("Enabled", "int"),
    ("StockRemaining", "int"),
    ("AvailableFrom", "string"),
    ("AvailableUntil", "string"),
    ("Name", "string"),
    ("Icon", "string"),
    ("SourceType", "string"),
    ("SourceName", "string"),
    ("SourceText", "string"),
)

SET_SCHEMA = (
    ("ID", "int"),
    ("CategoryID", "int"),
    ("SortOrder", "int"),
    ("Flags", "int"),
    ("Name", "string"),
    ("Icon", "string"),
    ("PieceCount", "int"),
    ("ItemID_1", "int"),
    ("ItemID_2", "int"),
    ("ItemID_3", "int"),
    ("ItemID_4", "int"),
    ("ItemID_5", "int"),
    ("ItemID_6", "int"),
    ("ItemID_7", "int"),
    ("ItemID_8", "int"),
    ("ItemID_9", "int"),
    ("ItemID_10", "int"),
    ("ItemID_11", "int"),
    ("ItemID_12", "int"),
    ("ItemID_13", "int"),
    ("ItemID_14", "int"),
    ("ItemID_15", "int"),
    ("ItemID_16", "int"),
    ("ItemID_17", "int"),
    ("ItemID_18", "int"),
    ("ItemID_19", "int"),
    ("ItemID_20", "int"),
)

TRANSMOG_SCHEMA = (
    ("ID", "int"),
    ("DisplayID", "int"),
    ("InventoryType", "int"),
    ("ItemClass", "int"),
    ("ItemSubClass", "int"),
    ("VisualSlot", "int"),
    ("CanonicalItemID", "int"),
    ("Rarity", "int"),
    ("ItemLevel", "int"),
    ("Name", "string"),
    ("Icon", "string"),
    ("ItemIDsTotal", "int"),
    ("ItemIDs", "string"),
)

MYTHICPLUS_AFFIX_SCHEMA = (
    ("ID", "int"),
    ("SpellID", "int"),
    ("Enabled", "int"),
    ("Type", "string"),
    ("Token", "string"),
    ("Name", "string"),
    ("Description", "string"),
    ("Icon", "string"),
)

MYTHICPLUS_DUNGEON_SCHEMA = (
    ("ID", "int"),
    ("SortOrder", "int"),
    ("TimeLimit", "int"),
    ("Difficulty", "int"),
    ("MinLevel", "int"),
    ("Enabled", "int"),
    ("Name", "string"),
    ("ShortName", "string"),
    ("ArtKey", "string"),
)

PASSTHROUGH_CDBC_OUTPUTS = (
    ("DCMythicPlusAffix", MYTHICPLUS_AFFIX_SCHEMA),
    ("DCMythicPlusDungeon", MYTHICPLUS_DUNGEON_SCHEMA),
)

TITLE_ICON = "Interface\\Icons\\INV_Scroll_11"
TRANSMOG_CANONICAL_ITEMID_THRESHOLD = 200000

INVENTORY_TYPE_TO_VISUAL_SLOT = {
    1: 283,
    3: 287,
    4: 289,
    5: 291,
    20: 291,
    6: 293,
    7: 295,
    8: 297,
    9: 299,
    10: 301,
    16: 311,
    13: 313,
    17: 313,
    21: 313,
    14: 315,
    22: 315,
    23: 315,
    15: 317,
    25: 317,
    28: 317,
    19: 319,
}

MANIFEST_TYPE_ORDER = (
    "mounts",
    "pets",
    "heirlooms",
    "titles",
    "transmog",
    "itemsets",
)

MANIFEST_SQL_TYPE_CONFIG = {
    "mounts": {
        "collection_type": 1,
        "table_name": "dc_mount_definitions",
        "server_type": "mount",
    },
    "pets": {
        "collection_type": 2,
        "table_name": "dc_pet_definitions",
        "server_type": "pet",
    },
    "heirlooms": {
        "collection_type": 4,
        "table_name": "dc_heirloom_definitions",
        "server_type": "heirloom",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate DCCollectionCategory/Source/Set CSV and CDBC assets "
            "from repo-local SQL and CSV sources."
        )
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=REPO_ROOT,
        help="Repository root. Defaults to the script's parent repo.",
    )
    parser.add_argument(
        "--csv-output-dir",
        type=Path,
        default=None,
        help="Custom/CSV DBC/CDBC output directory.",
    )
    parser.add_argument(
        "--cdbc-output-dir",
        type=Path,
        default=None,
        help="Custom/CDBCs output directory.",
    )
    parser.add_argument(
        "--patch-output-dir",
        type=Path,
        default=None,
        help="Patch bundle DBFilesClient output directory.",
    )
    parser.add_argument(
        "--skip-patch-copy",
        action="store_true",
        help="Do not mirror generated CDBCs into the patch bundle path.",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        help=(
            "Optional basenames to generate, for example "
            "DCCollectionCategory DCMythicPlusAffix. Defaults to all outputs."
        ),
    )
    return parser.parse_args()


def int_or_default(value: Any, default: int = 0) -> int:
    if value is None:
        return default
    if isinstance(value, int):
        return value
    text = str(value).strip()
    if not text:
        return default
    try:
        return int(float(text))
    except ValueError:
        return default


def float_or_default(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return default
    try:
        return float(text)
    except ValueError:
        return default


def text_or_empty(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def first_text(mapping: dict[str, Any], *keys: str) -> str:
    for key in keys:
        text = text_or_empty(mapping.get(key))
        if text:
            return text
    return ""


def first_int(mapping: dict[str, Any], *keys: str) -> int:
    for key in keys:
        value = int_or_default(mapping.get(key), 0)
        if value > 0:
            return value
    return 0


def normalize_icon_path(value: Any) -> str:
    text = text_or_empty(value)
    if not text:
        return ""

    text = text.replace("/", "\\")
    if "\\" in text:
        return text
    if text.isdigit():
        return text
    return f"Interface\\Icons\\{text}"


def join_with_details(base: str, details: list[str]) -> str:
    clean_details = [detail for detail in details if detail]
    if not clean_details:
        return base
    if base:
        return f"{base} ({', '.join(clean_details)})"
    return ", ".join(clean_details)


def describe_source_as_text(source: dict[str, Any]) -> str:
    source_type = text_or_empty(source.get("type") or source.get("Type")).lower()

    if source_type == "promotion":
        event_name = first_text(source, "event")
        return join_with_details("Promotion", [event_name])

    if source_type == "event":
        event_name = first_text(source, "event")
        return join_with_details("Event", [event_name])

    if source_type == "tcg":
        card_name = first_text(source, "card")
        return join_with_details("TCG", [card_name])

    if source_type == "shop":
        store_name = first_text(source, "store")
        return join_with_details("Shop", [store_name])

    if source_type == "arena":
        rating = int_or_default(source.get("rating"), 0)
        if rating > 0:
            return f"Arena ({rating} rating)"
        return "Arena"

    if source_type == "pvp":
        rank = int_or_default(source.get("rank"), 0)
        vendor_name = first_text(source, "vendor")
        rep_name = first_text(source, "rep")
        details = []
        if rank > 0:
            details.append(f"Rank {rank}")
        if vendor_name:
            details.append(vendor_name)
        if rep_name:
            details.append(rep_name)
        return join_with_details("PvP", details)

    if source_type == "class":
        class_name = first_text(source, "class")
        return join_with_details("Class", [class_name])

    if source_type == "darkchaos":
        return "DarkChaos Exclusive"

    if source_type == "quest":
        quest_name = first_text(source, "quest", "questline")
        return join_with_details("Quest", [quest_name])

    return first_text(
        source,
        "sourceText",
        "source_text",
        "event",
        "store",
        "card",
        "quest",
        "questline",
        "source",
    )


def build_source_fields(raw_source: Any) -> dict[str, Any]:
    fields = {
        "source_type": "",
        "source_name": "",
        "source_text": "",
        "source_object_id": 0,
        "source_value": 0.0,
        "item_id": 0,
        "creature_id": 0,
    }

    raw_text = text_or_empty(raw_source)
    if not raw_text:
        return fields

    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError:
        fields["source_text"] = raw_text
        return fields

    if not isinstance(parsed, dict):
        fields["source_text"] = raw_text
        return fields

    fields["item_id"] = int_or_default(
        parsed.get("itemId", parsed.get("item_id")),
        0,
    )
    fields["creature_id"] = int_or_default(
        parsed.get("creatureEntry", parsed.get("creature_entry")),
        0,
    )

    source_type = text_or_empty(parsed.get("type") or parsed.get("Type")).lower()

    if source_type == "vendor":
        base_name = first_text(parsed, "npc", "vendor")
        cost_text = first_text(parsed, "cost")
        details = [
            first_text(parsed, "zone"),
            first_text(parsed, "rep"),
            first_text(parsed, "repLevel", "level"),
        ]
        if cost_text:
            details.append(f"Cost: {cost_text}")
        fields["source_type"] = "vendor"
        fields["source_name"] = join_with_details(base_name, details)
        fields["source_object_id"] = int_or_default(
            parsed.get("npcEntry", parsed.get("npc_entry")),
            0,
        )
        return fields

    if source_type == "drop":
        base_name = first_text(parsed, "boss", "mob", "source")
        details = [
            first_text(parsed, "instance"),
            first_text(parsed, "zone"),
            first_text(parsed, "mode"),
        ]
        fields["source_type"] = "drop"
        fields["source_name"] = join_with_details(base_name, details)
        fields["source_object_id"] = int_or_default(
            parsed.get("creatureEntry", parsed.get("creature_entry")),
            0,
        )
        fields["source_value"] = float_or_default(
            parsed.get("dropRate", parsed.get("drop_rate")),
            0.0,
        )
        return fields

    if source_type == "achievement":
        fields["source_type"] = "achievement"
        fields["source_name"] = first_text(parsed, "achievement")
        return fields

    if source_type == "profession":
        profession_name = first_text(parsed, "profession")
        skill = int_or_default(parsed.get("skill"), 0)
        details = [str(skill) if skill > 0 else ""]
        fields["source_type"] = "profession"
        fields["source_name"] = join_with_details(profession_name, details)
        fields["source_value"] = float(skill) if skill > 0 else 0.0
        return fields

    if source_type == "reputation":
        base_name = first_text(parsed, "faction", "rep")
        details = [first_text(parsed, "repLevel", "level")]
        fields["source_type"] = "reputation"
        fields["source_name"] = join_with_details(base_name, details)
        return fields

    if source_type == "unknown":
        fields["source_type"] = "unknown"
        fields["source_object_id"] = fields["item_id"]
        return fields

    quest_name = first_text(parsed, "quest", "questline")
    quest_id = int_or_default(parsed.get("questId", parsed.get("quest_id")), 0)
    if source_type == "quest" and not quest_name and quest_id > 0:
        fields["source_type"] = "quest"
        fields["source_object_id"] = quest_id
        return fields

    fields["source_text"] = describe_source_as_text(parsed) or raw_text
    return fields


def split_sql_statements(sql_text: str) -> list[str]:
    statements: list[str] = []
    current: list[str] = []
    in_string = False
    quote_char = ""
    index = 0

    while index < len(sql_text):
        char = sql_text[index]
        next_char = sql_text[index + 1] if index + 1 < len(sql_text) else ""

        if in_string:
            current.append(char)
            if char == "\\" and index + 1 < len(sql_text):
                current.append(sql_text[index + 1])
                index += 2
                continue
            if char == quote_char:
                in_string = False
            index += 1
            continue

        if char in ("'", '"'):
            in_string = True
            quote_char = char
            current.append(char)
            index += 1
            continue

        if char == "-" and next_char == "-":
            prev_char = sql_text[index - 1] if index > 0 else "\n"
            if prev_char.isspace():
                while index < len(sql_text) and sql_text[index] != "\n":
                    index += 1
                continue

        if char == "/" and next_char == "*":
            index += 2
            while index + 1 < len(sql_text):
                if sql_text[index] == "*" and sql_text[index + 1] == "/":
                    index += 2
                    break
                index += 1
            continue

        if char == ";":
            statement = "".join(current).strip()
            if statement:
                statements.append(statement)
            current = []
            index += 1
            continue

        current.append(char)
        index += 1

    trailing = "".join(current).strip()
    if trailing:
        statements.append(trailing)

    return statements


def parse_sql_columns(columns_sql: str) -> list[str]:
    return [part.strip().strip("`") for part in columns_sql.split(",") if part.strip()]


def convert_sql_token(token: str) -> Any:
    if token == "":
        return ""

    upper = token.upper()
    if upper == "NULL":
        return None

    if re.fullmatch(r"-?\d+", token):
        return int(token)

    if re.fullmatch(r"-?(?:\d+\.\d*|\d*\.\d+)", token):
        return float(token)

    return token


def parse_sql_value_rows(values_sql: str) -> list[list[Any]]:
    rows: list[list[Any]] = []
    index = 0

    while index < len(values_sql):
        while index < len(values_sql) and values_sql[index] in " \t\r\n,":
            index += 1
        if index >= len(values_sql):
            break
        if values_sql[index] != "(":
            break

        index += 1
        row: list[Any] = []
        token_chars: list[str] = []
        in_string = False

        while index < len(values_sql):
            char = values_sql[index]

            if in_string:
                if char == "\\" and index + 1 < len(values_sql):
                    token_chars.append(values_sql[index + 1])
                    index += 2
                    continue
                if char == "'":
                    in_string = False
                    index += 1
                    continue
                token_chars.append(char)
                index += 1
                continue

            if char == "'":
                in_string = True
                index += 1
                continue

            if char == ",":
                row.append(convert_sql_token("".join(token_chars).strip()))
                token_chars = []
                index += 1
                continue

            if char == ")":
                row.append(convert_sql_token("".join(token_chars).strip()))
                rows.append(row)
                index += 1
                break

            token_chars.append(char)
            index += 1

    return rows


def collect_sql_files(repo_root: Path) -> list[Path]:
    sql_files: list[Path] = []
    seen: set[Path] = set()
    for pattern in COLLECTION_SQL_GLOBS:
        for path in sorted(repo_root.glob(pattern)):
            resolved = path.resolve()
            if resolved not in seen:
                sql_files.append(resolved)
                seen.add(resolved)
    return sql_files


def load_collection_definition_tables(repo_root: Path) -> dict[str, dict[int, dict[str, Any]]]:
    tables = {
        table_name: {}
        for table_name in TABLE_KEY_COLUMNS
    }

    insert_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?(\w+)`?\s*\((.*?)\)\s*VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )
    delete_re = re.compile(
        r"^\s*DELETE\s+FROM\s+`?(\w+)`?\s+WHERE\s+(.+)$",
        re.IGNORECASE | re.DOTALL,
    )

    for sql_file in collect_sql_files(repo_root):
        sql_text = sql_file.read_text(encoding="utf-8")
        if not any(table_name in sql_text for table_name in TABLE_KEY_COLUMNS):
            continue

        for statement in split_sql_statements(sql_text):
            insert_match = insert_re.match(statement)
            if insert_match:
                table_name = insert_match.group(1).lower()
                if table_name not in tables:
                    continue

                columns = parse_sql_columns(insert_match.group(2))
                values_sql = re.split(
                    r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                    insert_match.group(3),
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]
                for raw_row in parse_sql_value_rows(values_sql):
                    row = {
                        columns[index]: raw_row[index]
                        for index in range(min(len(columns), len(raw_row)))
                    }
                    key_name = TABLE_KEY_COLUMNS[table_name]
                    key_value = int_or_default(row.get(key_name), 0)
                    if key_value > 0:
                        tables[table_name][key_value] = row
                continue

            delete_match = delete_re.match(statement)
            if not delete_match:
                continue

            table_name = delete_match.group(1).lower()
            if table_name not in tables:
                continue

            key_name = TABLE_KEY_COLUMNS[table_name]
            where_sql = delete_match.group(2)

            in_match = re.search(
                rf"`?{re.escape(key_name)}`?\s+IN\s*\(([^)]+)\)",
                where_sql,
                re.IGNORECASE | re.DOTALL,
            )
            if in_match:
                key_values = [
                    int(value)
                    for value in re.findall(r"-?\d+", in_match.group(1))
                ]
                for key_value in key_values:
                    tables[table_name].pop(key_value, None)
                continue

            eq_match = re.search(
                rf"`?{re.escape(key_name)}`?\s*=\s*(-?\d+)",
                where_sql,
                re.IGNORECASE,
            )
            if eq_match:
                tables[table_name].pop(int(eq_match.group(1)), None)

    return tables


def load_collection_definition_index(
    repo_root: Path,
) -> dict[int, dict[int, dict[str, Any]]]:
    index_rows: dict[int, dict[int, dict[str, Any]]] = {}

    insert_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?(\w+)`?\s*\((.*?)\)\s*VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )
    delete_re = re.compile(
        r"^\s*DELETE\s+FROM\s+`?(\w+)`?\s+WHERE\s+(.+)$",
        re.IGNORECASE | re.DOTALL,
    )

    for sql_file in collect_sql_files(repo_root):
        sql_text = sql_file.read_text(encoding="utf-8")
        if COLLECTION_DEFINITION_INDEX_TABLE not in sql_text.lower():
            continue

        for statement in split_sql_statements(sql_text):
            insert_match = insert_re.match(statement)
            if insert_match:
                table_name = insert_match.group(1).lower()
                if table_name != COLLECTION_DEFINITION_INDEX_TABLE:
                    continue

                columns = parse_sql_columns(insert_match.group(2))
                values_sql = re.split(
                    r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                    insert_match.group(3),
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]
                for raw_row in parse_sql_value_rows(values_sql):
                    row = {
                        columns[index]: raw_row[index]
                        for index in range(min(len(columns), len(raw_row)))
                    }
                    collection_type = int_or_default(
                        row.get("collection_type"),
                        0,
                    )
                    entry_id = int_or_default(row.get("entry_id"), 0)
                    if collection_type > 0 and entry_id > 0:
                        index_rows.setdefault(collection_type, {})[entry_id] = row
                continue

            delete_match = delete_re.match(statement)
            if not delete_match:
                continue

            table_name = delete_match.group(1).lower()
            if table_name != COLLECTION_DEFINITION_INDEX_TABLE:
                continue

            where_sql = delete_match.group(2)
            type_match = re.search(
                r"`?collection_type`?\s*=\s*(-?\d+)",
                where_sql,
                re.IGNORECASE,
            )
            if not type_match:
                continue

            collection_type = int(type_match.group(1))
            type_rows = index_rows.setdefault(collection_type, {})

            in_match = re.search(
                r"`?entry_id`?\s+IN\s*\(([^)]+)\)",
                where_sql,
                re.IGNORECASE | re.DOTALL,
            )
            if in_match:
                entry_ids = [
                    int(value)
                    for value in re.findall(r"-?\d+", in_match.group(1))
                ]
                for entry_id in entry_ids:
                    type_rows.pop(entry_id, None)
                continue

            entry_match = re.search(
                r"`?entry_id`?\s*=\s*(-?\d+)",
                where_sql,
                re.IGNORECASE,
            )
            if entry_match:
                type_rows.pop(int(entry_match.group(1)), None)

    return index_rows


def get_enabled_definition_ids(
    definition_index: dict[int, dict[int, dict[str, Any]]],
    collection_type: int,
) -> set[int] | None:
    rows = definition_index.get(collection_type)
    if rows is None:
        return None

    return {
        entry_id
        for entry_id, row in rows.items()
        if int_or_default(row.get("enabled", 1), 1) != 0
    }


def get_ordered_definition_ids(
    available_ids: set[int],
    expected_ids: set[int] | None,
) -> list[int]:
    if expected_ids is None:
        return sorted(available_ids)

    return [
        entry_id
        for entry_id in sorted(available_ids)
        if entry_id in expected_ids
    ]


def parse_create_table_column_names(create_table_sql: str) -> list[str]:
    columns: list[str] = []
    for raw_line in create_table_sql.splitlines():
        line = raw_line.strip()
        if not line.startswith("`"):
            continue
        end = line.find("`", 1)
        if end <= 1:
            continue
        columns.append(line[1:end])
    return columns


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def load_item_template_rows(repo_root: Path) -> dict[int, dict[str, Any]]:
    create_re = re.compile(
        r"^\s*CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+`?item_template`?\s*\(.*$",
        re.IGNORECASE | re.DOTALL,
    )
    insert_with_columns_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?item_template`?\s*\((.*?)\)\s*VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )
    insert_without_columns_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?item_template`?\s+VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )

    for candidate in ITEM_TEMPLATE_SQL_CANDIDATES:
        path = repo_root / candidate
        if not path.exists():
            continue

        sql_text = path.read_text(encoding="utf-8")
        if "item_template" not in sql_text.lower():
            continue

        rows: dict[int, dict[str, Any]] = {}
        column_names: list[str] = []

        for statement in split_sql_statements(sql_text):
            if not column_names and create_re.match(statement):
                column_names = parse_create_table_column_names(statement)
                continue

            insert_match = insert_with_columns_re.match(statement)
            if insert_match:
                columns = parse_sql_columns(insert_match.group(1))
                values_sql = re.split(
                    r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                    insert_match.group(2),
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]
            else:
                insert_match = insert_without_columns_re.match(statement)
                if not insert_match or not column_names:
                    continue
                columns = column_names
                values_sql = re.split(
                    r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                    insert_match.group(1),
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]

            for raw_row in parse_sql_value_rows(values_sql):
                row = {
                    columns[index]: raw_row[index]
                    for index in range(min(len(columns), len(raw_row)))
                }
                entry = int_or_default(row.get("entry"), 0)
                if entry > 0:
                    rows[entry] = row

        if rows:
            return rows

    return {}


def load_item_display_ids(repo_root: Path) -> dict[int, int]:
    item_csv = repo_root / "Custom" / "CSV DBC" / "Item.csv"
    display_ids: dict[int, int] = {}
    for row in read_csv_rows(item_csv):
        item_id = int_or_default(row.get("ID"), 0)
        display_id = int_or_default(row.get("DisplayInfoID"), 0)
        if item_id > 0 and display_id > 0:
            display_ids[item_id] = display_id
    return display_ids


def load_item_display_icons(repo_root: Path) -> dict[int, str]:
    item_display_csv = repo_root / "Custom" / "CSV DBC" / "ItemDisplayInfo.csv"
    icons: dict[int, str] = {}
    for row in read_csv_rows(item_display_csv):
        display_id = int_or_default(row.get("ID"), 0)
        if display_id <= 0:
            continue

        icon = normalize_icon_path(
            first_text(row, "InventoryIcon_1", "InventoryIcon_2")
        )
        if icon:
            icons[display_id] = icon
    return icons


def load_spell_rows(repo_root: Path) -> dict[int, dict[str, str]]:
    spell_csv = repo_root / "Custom" / "CSV DBC" / "Spell.csv"
    if not spell_csv.exists():
        return {}

    rows: dict[int, dict[str, str]] = {}
    for row in read_csv_rows(spell_csv):
        spell_id = int_or_default(row.get("ID"), 0)
        if spell_id > 0:
            rows[spell_id] = row
    return rows


def load_creature_template_model_display_ids(repo_root: Path) -> dict[int, int]:
    create_re = re.compile(
        r"^\s*CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?\s+`?creature_template_model`?\s*\(.*$",
        re.IGNORECASE | re.DOTALL,
    )
    insert_with_columns_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?creature_template_model`?\s*\((.*?)\)\s*VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )
    insert_without_columns_re = re.compile(
        r"^\s*INSERT(?:\s+IGNORE)?\s+INTO\s+`?creature_template_model`?\s+VALUES\s*(.*)$",
        re.IGNORECASE | re.DOTALL,
    )

    for candidate in CREATURE_TEMPLATE_MODEL_SQL_CANDIDATES:
        path = repo_root / candidate
        if not path.exists():
            continue

        sql_text = path.read_text(encoding="utf-8")
        if "creature_template_model" not in sql_text.lower():
            continue

        display_ids: dict[int, tuple[int, int]] = {}
        column_names: list[str] = []

        for statement in split_sql_statements(sql_text):
            if not column_names and create_re.match(statement):
                column_names = parse_create_table_column_names(statement)
                continue

            insert_match = insert_with_columns_re.match(statement)
            if insert_match:
                columns = parse_sql_columns(insert_match.group(1))
                values_sql = re.split(
                    r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                    insert_match.group(2),
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]
            else:
                insert_match = insert_without_columns_re.match(statement)
                if not insert_match or not column_names:
                    continue
                columns = column_names
                values_sql = re.split(
                    r"\bON\s+DUPLICATE\s+KEY\s+UPDATE\b",
                    insert_match.group(1),
                    maxsplit=1,
                    flags=re.IGNORECASE,
                )[0]

            for raw_row in parse_sql_value_rows(values_sql):
                row = {
                    columns[index]: raw_row[index]
                    for index in range(min(len(columns), len(raw_row)))
                }
                creature_id = first_int(
                    row,
                    "CreatureID",
                    "creature_id",
                    "creatureid",
                )
                display_id = first_int(
                    row,
                    "CreatureDisplayID",
                    "creature_display_id",
                    "creaturedisplayid",
                )
                if creature_id <= 0 or display_id <= 0:
                    continue

                idx = int_or_default(row.get("Idx", row.get("idx")), 99)
                current = display_ids.get(creature_id)
                if current is None or idx < current[0]:
                    display_ids[creature_id] = (idx, display_id)

        if display_ids:
            return {
                creature_id: display_id
                for creature_id, (_, display_id) in display_ids.items()
            }

    return {}


def is_companion_spell_row(spell_row: dict[str, Any] | None) -> bool:
    if not spell_row:
        return False

    for effect_index in range(1, 4):
        effect_id = int_or_default(spell_row.get(f"Effect_{effect_index}"), 0)
        if effect_id in {SPELL_EFFECT_SUMMON, SPELL_EFFECT_SUMMON_PET}:
            return True

    return False


def resolve_companion_summon_spell_from_spell(
    spell_rows: dict[int, dict[str, Any]],
    spell_id: int,
) -> int:
    if spell_id <= 0:
        return 0

    to_visit = [spell_id]
    visited: set[int] = set()

    while to_visit:
        spell_id_to_check = to_visit.pop()
        if spell_id_to_check <= 0 or spell_id_to_check in visited:
            continue

        visited.add(spell_id_to_check)
        spell_row = spell_rows.get(spell_id_to_check)
        if not spell_row:
            continue

        if is_companion_spell_row(spell_row):
            return spell_id_to_check

        for effect_index in range(1, 4):
            effect_id = int_or_default(
                spell_row.get(f"Effect_{effect_index}"),
                0,
            )
            if effect_id not in {
                SPELL_EFFECT_LEARN_SPELL,
                SPELL_EFFECT_LEARN_PET_SPELL,
                SPELL_EFFECT_TRIGGER_SPELL,
            }:
                continue

            next_spell_id = first_int(
                spell_row,
                f"EffectTriggerSpell_{effect_index}",
                f"EffectMiscValue_{effect_index}",
            )
            if next_spell_id > 0 and next_spell_id not in visited:
                to_visit.append(next_spell_id)

    return 0


def resolve_companion_preview_from_item_entry(
    entry_id: int,
    item_template_rows: dict[int, dict[str, Any]],
    spell_rows: dict[int, dict[str, Any]],
    creature_model_display_ids: dict[int, int],
) -> tuple[int, int, int]:
    item_row = item_template_rows.get(entry_id)
    if not item_row:
        return 0, 0, 0

    seen_spell_ids: set[int] = set()
    for spell_slot in range(1, 6):
        spell_id = first_int(
            item_row,
            f"spellid_{spell_slot}",
            f"spellid{spell_slot}",
            f"SpellID_{spell_slot}",
            f"SpellID{spell_slot}",
        )
        if spell_id <= 0 or spell_id in seen_spell_ids:
            continue

        seen_spell_ids.add(spell_id)
        summon_spell_id = resolve_companion_summon_spell_from_spell(
            spell_rows,
            spell_id,
        )
        if summon_spell_id <= 0:
            continue

        summon_spell = spell_rows.get(summon_spell_id)
        creature_id = 0
        display_id = 0
        if summon_spell:
            for effect_index in range(1, 4):
                effect_id = int_or_default(
                    summon_spell.get(f"Effect_{effect_index}"),
                    0,
                )
                if effect_id not in {SPELL_EFFECT_SUMMON, SPELL_EFFECT_SUMMON_PET}:
                    continue

                creature_id = first_int(
                    summon_spell,
                    f"EffectMiscValue_{effect_index}",
                )
                if creature_id > 0:
                    display_id = creature_model_display_ids.get(creature_id, 0)
                    break

        return summon_spell_id, display_id, creature_id

    return 0, 0, 0


def is_better_transmog_representative(
    new_entry: int,
    new_quality: int,
    new_item_level: int,
    old_entry: int,
    old_quality: int,
    old_item_level: int,
) -> bool:
    new_is_non_custom = new_entry < TRANSMOG_CANONICAL_ITEMID_THRESHOLD
    old_is_non_custom = old_entry < TRANSMOG_CANONICAL_ITEMID_THRESHOLD

    if new_is_non_custom != old_is_non_custom:
        return new_is_non_custom

    if new_quality != old_quality:
        return new_quality > old_quality

    if new_item_level != old_item_level:
        return new_item_level > old_item_level

    return new_entry < old_entry


def build_transmog_rows(
    item_template_rows: dict[int, dict[str, Any]],
    item_display_icons: dict[int, str],
) -> list[dict[str, Any]]:
    variants: dict[tuple[int, int, int, int], dict[str, Any]] = {}

    for entry_id, item in item_template_rows.items():
        display_id = int_or_default(item.get("displayid"), 0)
        inventory_type = int_or_default(item.get("InventoryType"), 0)
        item_class = int_or_default(item.get("class"), 0)
        item_subclass = int_or_default(item.get("subclass"), 0)

        if display_id <= 0 or inventory_type <= 0 or item_class not in (2, 4):
            continue

        quality = int_or_default(item.get("Quality"), 0)
        item_level = int_or_default(item.get("ItemLevel"), 0)
        key = (display_id, inventory_type, item_class, item_subclass)

        bucket = variants.get(key)
        if bucket is None:
            variants[key] = {
                "canonical_item_id": entry_id,
                "rarity": quality,
                "item_level": item_level,
                "name": text_or_empty(item.get("name")),
                "item_ids": [entry_id],
            }
            continue

        bucket["item_ids"].append(entry_id)
        if is_better_transmog_representative(
            entry_id,
            quality,
            item_level,
            int(bucket["canonical_item_id"]),
            int(bucket["rarity"]),
            int(bucket["item_level"]),
        ):
            bucket["canonical_item_id"] = entry_id
            bucket["rarity"] = quality
            bucket["item_level"] = item_level
            bucket["name"] = text_or_empty(item.get("name"))

    rows: list[dict[str, Any]] = []
    for row_id, key in enumerate(sorted(variants), start=1):
        bucket = variants[key]
        item_ids = sorted({int_or_default(item_id, 0) for item_id in bucket["item_ids"]})
        item_ids = [item_id for item_id in item_ids if item_id > 0]
        display_id, inventory_type, item_class, item_subclass = key

        rows.append(
            {
                "ID": row_id,
                "DisplayID": display_id,
                "InventoryType": inventory_type,
                "ItemClass": item_class,
                "ItemSubClass": item_subclass,
                "VisualSlot": INVENTORY_TYPE_TO_VISUAL_SLOT.get(
                    inventory_type,
                    0,
                ),
                "CanonicalItemID": int(bucket["canonical_item_id"]),
                "Rarity": int(bucket["rarity"]),
                "ItemLevel": int(bucket["item_level"]),
                "Name": text_or_empty(bucket["name"]),
                "Icon": item_display_icons.get(display_id, ""),
                "ItemIDsTotal": len(item_ids),
                "ItemIDs": ",".join(str(item_id) for item_id in item_ids),
            }
        )

    return rows


def build_title_source_rows(
    repo_root: Path,
    curated_titles: dict[int, dict[str, Any]],
) -> list[dict[str, Any]]:
    title_csv = repo_root / "Custom" / "CSV DBC" / "CharTitles.csv"
    rows: list[dict[str, Any]] = []

    for sort_order, row in enumerate(read_csv_rows(title_csv), start=1):
        title_id = int_or_default(row.get("ID"), 0)
        if title_id <= 0:
            continue

        title_name = text_or_empty(row.get("Name_Lang_enUS"))
        if not title_name:
            title_name = text_or_empty(row.get("Name1_Lang_enUS"))
        if not title_name:
            continue

        curated = curated_titles.get(title_id, {})
        source_fields = build_source_fields(curated.get("source"))

        rows.append(
            {
                "ID": len(rows) + 1,
                "CollectionType": 5,
                "EntryID": title_id,
                "CategoryID": CATEGORY_IDS["title"],
                "SortOrder": sort_order,
                "Flags": 0,
                "Rarity": int_or_default(curated.get("rarity"), 1),
                "ItemID": 0,
                "SpellID": 0,
                "DisplayID": 0,
                "CreatureID": 0,
                "MountType": -1,
                "SourceObjectID": int_or_default(
                    source_fields["source_object_id"],
                    0,
                ),
                "SourceValue": float_or_default(source_fields["source_value"], 0.0),
                "Name": title_name,
                "Icon": TITLE_ICON,
                "SourceType": source_fields["source_type"],
                "SourceName": source_fields["source_name"],
                "SourceText": source_fields["source_text"],
            }
        )

    return rows


def build_source_rows(
    repo_root: Path,
    tables: dict[str, dict[int, dict[str, Any]]],
    item_display_ids: dict[int, int],
    item_template_rows: dict[int, dict[str, Any]],
    spell_rows: dict[int, dict[str, Any]],
    creature_model_display_ids: dict[int, int],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []

    mounts = tables["dc_mount_definitions"]
    for sort_order, entry_id in enumerate(sorted(mounts), start=1):
        mount = mounts[entry_id]
        source_fields = build_source_fields(mount.get("source"))
        preview_display_id = int_or_default(mount.get("display_id"), 0)
        preview_creature_id = 0
        rows.append(
            {
                "ID": len(rows) + 1,
                "CollectionType": 1,
                "EntryID": entry_id,
                "CategoryID": CATEGORY_IDS["mount"],
                "SortOrder": sort_order,
                "Flags": 0,
                "Rarity": int_or_default(mount.get("rarity"), 0),
                "ItemID": int_or_default(source_fields["item_id"], 0),
                "SpellID": entry_id,
                "DisplayID": preview_display_id,
                "CreatureID": preview_creature_id,
                "MountType": int_or_default(mount.get("mount_type"), -1),
                "SourceObjectID": int_or_default(
                    source_fields["source_object_id"],
                    0,
                ),
                "SourceValue": float_or_default(source_fields["source_value"], 0.0),
                "Name": text_or_empty(mount.get("name")),
                "Icon": normalize_icon_path(mount.get("icon")),
                "SourceType": source_fields["source_type"],
                "SourceName": source_fields["source_name"],
                "SourceText": source_fields["source_text"],
            }
        )

    pets = tables["dc_pet_definitions"]
    for sort_order, entry_id in enumerate(sorted(pets), start=1):
        pet = pets[entry_id]
        pet_name = text_or_empty(pet.get("name"))
        if entry_id in DISABLED_LOCAL_PET_ENTRY_IDS or pet_name.startswith(
            "NPC Equip "
        ):
            continue

        source_fields = build_source_fields(pet.get("source"))
        item_id = int_or_default(source_fields["item_id"], 0)
        if item_id == 0 and entry_id in item_display_ids:
            item_id = entry_id

        spell_id = int_or_default(
            pet.get("pet_spell_id", pet.get("spell_id")),
            0,
        )
        display_id = int_or_default(pet.get("display_id"), 0)
        creature_id = int_or_default(source_fields["creature_id"], 0)

        if creature_id > 0 and display_id <= 0:
            display_id = creature_model_display_ids.get(creature_id, 0)

        preview_entry_id = item_id if item_id > 0 else entry_id
        if spell_id <= 0 or display_id <= 0 or creature_id <= 0:
            (
                resolved_spell_id,
                resolved_display_id,
                resolved_creature_id,
            ) = resolve_companion_preview_from_item_entry(
                preview_entry_id,
                item_template_rows,
                spell_rows,
                creature_model_display_ids,
            )
            if spell_id <= 0:
                spell_id = resolved_spell_id
            if display_id <= 0:
                display_id = resolved_display_id
            if creature_id <= 0:
                creature_id = resolved_creature_id

        curated_preview = CURATED_PET_PREVIEW_OVERRIDES.get(preview_entry_id)
        if curated_preview is None:
            curated_preview = CURATED_PET_PREVIEW_OVERRIDES.get(entry_id)
        if curated_preview is not None:
            curated_spell_id, curated_display_id, curated_creature_id = (
                curated_preview
            )
            if spell_id <= 0:
                spell_id = curated_spell_id
            if display_id <= 0:
                display_id = curated_display_id
            if creature_id <= 0:
                creature_id = curated_creature_id

        preview_display_id = display_id
        preview_creature_id = creature_id

        rows.append(
            {
                "ID": len(rows) + 1,
                "CollectionType": 2,
                "EntryID": entry_id,
                "CategoryID": CATEGORY_IDS["pet"],
                "SortOrder": sort_order,
                "Flags": 0,
                "Rarity": int_or_default(pet.get("rarity"), 0),
                "ItemID": item_id,
                "SpellID": spell_id,
                "DisplayID": preview_display_id,
                "CreatureID": preview_creature_id,
                "MountType": -1,
                "SourceObjectID": int_or_default(
                    source_fields["source_object_id"],
                    0,
                ),
                "SourceValue": float_or_default(source_fields["source_value"], 0.0),
                "Name": text_or_empty(pet.get("name")),
                "Icon": normalize_icon_path(pet.get("icon")),
                "SourceType": source_fields["source_type"],
                "SourceName": source_fields["source_name"],
                "SourceText": source_fields["source_text"],
            }
        )

    heirlooms = tables["dc_heirloom_definitions"]
    for sort_order, entry_id in enumerate(sorted(heirlooms), start=1):
        heirloom = heirlooms[entry_id]
        source_fields = build_source_fields(heirloom.get("source"))
        rows.append(
            {
                "ID": len(rows) + 1,
                "CollectionType": 4,
                "EntryID": entry_id,
                "CategoryID": CATEGORY_IDS["heirloom"],
                "SortOrder": sort_order,
                "Flags": 0,
                "Rarity": int_or_default(heirloom.get("rarity"), 0),
                "ItemID": entry_id,
                "SpellID": 0,
                "DisplayID": item_display_ids.get(entry_id, 0),
                "CreatureID": 0,
                "MountType": -1,
                "SourceObjectID": int_or_default(
                    source_fields["source_object_id"],
                    0,
                ),
                "SourceValue": float_or_default(source_fields["source_value"], 0.0),
                "Name": text_or_empty(heirloom.get("name")),
                "Icon": normalize_icon_path(heirloom.get("icon")),
                "SourceType": source_fields["source_type"],
                "SourceName": source_fields["source_name"],
                "SourceText": source_fields["source_text"],
            }
        )

    rows.extend(build_title_source_rows(repo_root, tables["dc_title_definitions"]))
    return rows


def build_collection_completeness_manifest(
    tables: dict[str, dict[int, dict[str, Any]]],
    source_rows: list[dict[str, Any]],
    transmog_rows: list[dict[str, Any]],
    shop_static_rows: list[dict[str, Any]],
    definition_index: dict[int, dict[int, dict[str, Any]]],
) -> dict[str, Any]:
    source_ids_by_type: dict[int, set[int]] = {}
    preview_incomplete_ids_by_type: dict[int, list[int]] = {}
    for row in source_rows:
        collection_type = int_or_default(row.get("CollectionType"), 0)
        entry_id = int_or_default(row.get("EntryID"), 0)
        if collection_type > 0 and entry_id > 0:
            source_ids_by_type.setdefault(collection_type, set()).add(entry_id)
            if (
                collection_type == 2
                and int_or_default(row.get("DisplayID"), 0) <= 0
                and int_or_default(row.get("CreatureID"), 0) <= 0
            ):
                preview_incomplete_ids_by_type.setdefault(
                    collection_type,
                    [],
                ).append(entry_id)

    type_manifest: dict[str, dict[str, Any]] = {}
    for type_name in MANIFEST_TYPE_ORDER:
        if type_name in MANIFEST_SQL_TYPE_CONFIG:
            config = MANIFEST_SQL_TYPE_CONFIG[type_name]
            collection_type = config["collection_type"]
            server_type = config["server_type"]
            present_ids = source_ids_by_type.get(collection_type, set())
            expected_ids = get_enabled_definition_ids(
                definition_index,
                collection_type,
            )
            missing_ids = []
            if type_name == "mounts" and expected_ids is not None:
                missing_ids = sorted(expected_ids - present_ids)
            elif type_name == "pets":
                missing_ids = sorted(preview_incomplete_ids_by_type.get(2, []))

            authoritative = len(present_ids) > 0
            if type_name == "mounts" and expected_ids is not None:
                authoritative = authoritative and not missing_ids
            elif type_name == "pets":
                authoritative = authoritative and not missing_ids

            server_source = "table"
            if type_name == "mounts":
                server_source = "table+index" if expected_ids is not None else "table"
            type_manifest[type_name] = {
                "collectionType": collection_type,
                "serverType": server_type,
                "serverSource": server_source,
                "definitionCount": len(present_ids),
                "expectedCount": (
                    len(expected_ids)
                    if expected_ids is not None
                    else len(present_ids)
                ),
                "indexAvailable": expected_ids is not None,
                "authoritative": authoritative,
                "requestSkip": authoritative,
                "missingCount": len(missing_ids),
                "missingIds": missing_ids[:32],
            }
            continue

        if type_name == "titles":
            present_ids = source_ids_by_type.get(5, set())
            authoritative = len(present_ids) > 0
            type_manifest[type_name] = {
                "collectionType": 5,
                "serverType": "title",
                "serverSource": "dbc",
                "definitionCount": len(present_ids),
                "expectedCount": len(present_ids),
                "indexAvailable": False,
                "authoritative": authoritative,
                "requestSkip": authoritative,
                "missingCount": 0,
                "missingIds": [],
            }
            continue

        if type_name == "transmog":
            authoritative = len(transmog_rows) > 0
            type_manifest[type_name] = {
                "collectionType": 6,
                "serverType": "transmog",
                "serverSource": "item_template",
                "definitionCount": len(transmog_rows),
                "expectedCount": len(transmog_rows),
                "indexAvailable": False,
                "authoritative": authoritative,
                "requestSkip": authoritative,
                "missingCount": 0,
                "missingIds": [],
            }
            continue

        collection_type = 6 if type_name == "transmog" else 7
        server_type = "transmog" if type_name == "transmog" else "itemset"
        present_ids = source_ids_by_type.get(collection_type, set())
        type_manifest[type_name] = {
            "collectionType": collection_type,
            "serverType": server_type,
            "serverSource": "runtime",
            "definitionCount": len(present_ids),
            "expectedCount": len(present_ids),
            "indexAvailable": False,
            "authoritative": False,
            "requestSkip": False,
            "missingCount": 0,
            "missingIds": [],
        }

    enabled_shop_rows = [
        row for row in shop_static_rows
        if int_or_default(row.get("Enabled", 1), 1) != 0
    ]
    unresolved_shop_rows = [
        row for row in enabled_shop_rows
        if not text_or_empty(row.get("Name"))
    ]

    shop_manifest = {
        "rowCount": len(shop_static_rows),
        "enabledRowCount": len(enabled_shop_rows),
        "resolvedRowCount": len(enabled_shop_rows) - len(unresolved_shop_rows),
        "authoritative": (
            len(enabled_shop_rows) > 0 and
            not unresolved_shop_rows
        ),
        "missingPreview": [
            {
                "shopId": int_or_default(row.get("ShopID"), 0),
                "collectionType": int_or_default(row.get("CollectionType"), 0),
                "entryId": int_or_default(row.get("EntryID"), 0),
            }
            for row in unresolved_shop_rows[:16]
        ],
    }

    return {
        "version": 1,
        "types": type_manifest,
        "shop": shop_manifest,
    }


def build_collection_completeness_json_content(
    manifest: dict[str, Any],
) -> str:
    return json.dumps(manifest, indent=2) + "\n"


def build_collection_completeness_lua_content(
    manifest: dict[str, Any],
) -> str:
    def lua_bool(value: bool) -> str:
        return "true" if value else "false"

    lines = [
        "-- Auto-generated by tools/generate_dc_collection_cdbc.py. Do not edit.",
        "local DC = DCCollection",
        "DC.COLLECTION_STATIC_MANIFEST = {",
        f"    version = {int_or_default(manifest.get('version'), 0)},",
        "    types = {",
    ]

    types = manifest.get("types", {})
    for type_name in MANIFEST_TYPE_ORDER:
        entry = types.get(type_name, {})
        lines.extend(
            [
                f"        {type_name} = {{",
                "            collectionType = "
                f"{int_or_default(entry.get('collectionType'), 0)},",
                f"            serverType = {escape_lua_string(entry.get('serverType'))},",
                f"            serverSource = {escape_lua_string(entry.get('serverSource'))},",
                "            definitionCount = "
                f"{int_or_default(entry.get('definitionCount'), 0)},",
                "            expectedCount = "
                f"{int_or_default(entry.get('expectedCount'), 0)},",
                "            indexAvailable = "
                f"{lua_bool(bool(entry.get('indexAvailable')))},",
                "            authoritative = "
                f"{lua_bool(bool(entry.get('authoritative')))},",
                "            requestSkip = "
                f"{lua_bool(bool(entry.get('requestSkip')))},",
                "            missingCount = "
                f"{int_or_default(entry.get('missingCount'), 0)},",
                "            missingIds = {",
            ]
        )
        for missing_id in entry.get("missingIds", []):
            lines.append(f"                {int_or_default(missing_id, 0)},")
        lines.extend(
            [
                "            },",
                "        },",
            ]
        )

    shop = manifest.get("shop", {})
    lines.extend(
        [
            "    },",
            "    shop = {",
            f"        rowCount = {int_or_default(shop.get('rowCount'), 0)},",
            "        enabledRowCount = "
            f"{int_or_default(shop.get('enabledRowCount'), 0)},",
            "        resolvedRowCount = "
            f"{int_or_default(shop.get('resolvedRowCount'), 0)},",
            "        authoritative = "
            f"{lua_bool(bool(shop.get('authoritative')))},",
            "        missingPreview = {",
        ]
    )
    for preview in shop.get("missingPreview", []):
        lines.extend(
            [
                "            {",
                "                shopId = "
                f"{int_or_default(preview.get('shopId'), 0)},",
                "                collectionType = "
                f"{int_or_default(preview.get('collectionType'), 0)},",
                "                entryId = "
                f"{int_or_default(preview.get('entryId'), 0)},",
                "            },",
            ]
        )
    lines.extend(
        [
            "        },",
            "    },",
            "}",
            "DC.COLLECTION_STATIC_MANIFEST_VERSION = "
            f"{int_or_default(manifest.get('version'), 0)}",
            "",
        ]
    )
    return "\n".join(lines)


def build_shop_static_rows(
    tables: dict[str, dict[int, dict[str, Any]]],
    source_rows: list[dict[str, Any]],
    item_display_ids: dict[int, int],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    definitions_by_key = {
        (
            int_or_default(row.get("CollectionType"), 0),
            int_or_default(row.get("EntryID"), 0),
        ): row
        for row in source_rows
    }

    shops = tables["dc_collection_shop"]
    for shop_id in sorted(shops):
        shop = shops[shop_id]
        collection_type = int_or_default(shop.get("collection_type"), 0)
        entry_id = int_or_default(
            shop.get("entry_id", shop.get("entry")),
            0,
        )
        definition = definitions_by_key.get((collection_type, entry_id))

        item_id = 0
        spell_id = 0
        appearance_id = 0
        display_id = 0
        creature_id = 0
        mount_type = -1
        rarity = 0
        name = ""
        icon = ""
        source_type = ""
        source_name = ""
        source_text = ""

        if definition is not None:
            item_id = int_or_default(definition.get("ItemID"), 0)
            spell_id = int_or_default(definition.get("SpellID"), 0)
            display_id = int_or_default(definition.get("DisplayID"), 0)
            creature_id = int_or_default(definition.get("CreatureID"), 0)
            mount_type = int_or_default(definition.get("MountType"), -1)
            rarity = int_or_default(definition.get("Rarity"), 0)
            name = text_or_empty(definition.get("Name"))
            icon = normalize_icon_path(definition.get("Icon"))
            source_type = text_or_empty(definition.get("SourceType"))
            source_name = text_or_empty(definition.get("SourceName"))
            source_text = text_or_empty(definition.get("SourceText"))

        if collection_type == 1 and spell_id == 0:
            spell_id = entry_id
        elif collection_type in {2, 4} and item_id == 0 and entry_id in item_display_ids:
            item_id = entry_id
            display_id = item_display_ids.get(entry_id, display_id)
        elif collection_type == 6:
            if entry_id in item_display_ids:
                item_id = entry_id
                display_id = item_display_ids[entry_id]
            appearance_id = display_id if display_id > 0 else entry_id

        rows.append(
            {
                "ShopID": shop_id,
                "CollectionType": collection_type,
                "CollectionTypeName": COLLECTION_TYPE_LABELS.get(
                    collection_type,
                    "unknown",
                ),
                "EntryID": entry_id,
                "ItemID": item_id,
                "SpellID": spell_id,
                "AppearanceID": appearance_id,
                "DisplayID": display_id,
                "CreatureID": creature_id,
                "MountType": mount_type,
                "Rarity": rarity,
                "PriceTokens": int_or_default(shop.get("price_tokens"), 0),
                "PriceEmblems": int_or_default(shop.get("price_emblems"), 0),
                "DiscountPercent": int_or_default(
                    shop.get("discount_percent"),
                    0,
                ),
                "Featured": int_or_default(shop.get("featured"), 0),
                "Enabled": int_or_default(shop.get("enabled", 1), 1),
                "StockRemaining": int_or_default(shop.get("stock_remaining"), -1),
                "AvailableFrom": text_or_empty(shop.get("available_from")),
                "AvailableUntil": text_or_empty(shop.get("available_until")),
                "Name": name,
                "Icon": icon,
                "SourceType": source_type,
                "SourceName": source_name,
                "SourceText": source_text,
            }
        )

    return rows


def build_set_rows(repo_root: Path) -> list[dict[str, Any]]:
    item_set_csv = repo_root / "Custom" / "CSV DBC" / "ItemSet.csv"
    rows: list[dict[str, Any]] = []

    for row in read_csv_rows(item_set_csv):
        set_id = int_or_default(row.get("ID"), 0)
        if set_id <= 0:
            continue

        name = text_or_empty(row.get("Name_Lang_enUS"))
        if not name:
            continue

        items: list[int] = []
        for index in range(1, 21):
            item_id = int_or_default(row.get(f"ItemID_{index}"), 0)
            if item_id > 0:
                items.append(item_id)

        if not items:
            continue

        set_row: dict[str, Any] = {
            "ID": set_id,
            "CategoryID": CATEGORY_IDS["itemset"],
            "SortOrder": set_id,
            "Flags": 0,
            "Name": name,
            "Icon": "",
            "PieceCount": len(items),
        }
        for index in range(1, 21):
            set_row[f"ItemID_{index}"] = items[index - 1] if index <= len(items) else 0
        rows.append(set_row)

    return rows


def format_csv_value(value: Any, value_type: str) -> str:
    if value_type == "float":
        number = float_or_default(value, 0.0)
        return f"{number:.6f}".rstrip("0").rstrip(".") or "0"
    if value_type == "int":
        return str(int_or_default(value, 0))
    return text_or_empty(value)


def build_csv_content(rows: list[dict[str, Any]], schema: tuple[tuple[str, str], ...]) -> str:
    header = [name for name, _ in schema]
    lines = [",".join(f'"{name}"' for name in header)]

    for row in rows:
        values = []
        for field_name, field_type in schema:
            raw = format_csv_value(row.get(field_name), field_type)
            escaped = raw.replace('"', '""')
            values.append(f'"{escaped}"')
        lines.append(",".join(values))

    return "\n".join(lines) + "\n"


def escape_lua_string(value: Any) -> str:
    text = text_or_empty(value)
    text = text.replace("\\", "\\\\")
    text = text.replace("\r", "\\r")
    text = text.replace("\n", "\\n")
    text = text.replace('"', '\\"')
    return f'"{text}"'


def build_shop_static_lua_content(rows: list[dict[str, Any]]) -> str:
    field_map = (
        ("shopId", "ShopID", "int"),
        ("collectionType", "CollectionType", "int"),
        ("collectionTypeName", "CollectionTypeName", "string"),
        ("entryId", "EntryID", "int"),
        ("itemId", "ItemID", "int"),
        ("spellId", "SpellID", "int"),
        ("appearanceId", "AppearanceID", "int"),
        ("displayId", "DisplayID", "int"),
        ("creatureId", "CreatureID", "int"),
        ("mountType", "MountType", "int"),
        ("rarity", "Rarity", "int"),
        ("priceTokens", "PriceTokens", "int"),
        ("priceEmblems", "PriceEmblems", "int"),
        ("discount", "DiscountPercent", "int"),
        ("featured", "Featured", "int"),
        ("enabled", "Enabled", "int"),
        ("stock", "StockRemaining", "int"),
        ("availableFrom", "AvailableFrom", "string"),
        ("availableUntil", "AvailableUntil", "string"),
        ("name", "Name", "string"),
        ("icon", "Icon", "string"),
        ("sourceType", "SourceType", "string"),
        ("sourceName", "SourceName", "string"),
        ("sourceText", "SourceText", "string"),
    )

    lines = [
        "-- Auto-generated by tools/generate_dc_collection_cdbc.py. Do not edit.",
        "local DC = DCCollection",
        "DC.SHOP_STATIC_DATA = {",
    ]

    for row in rows:
        lines.append("    {")
        for lua_key, row_key, field_type in field_map:
            raw_value = row.get(row_key)
            if field_type == "int":
                value = str(int_or_default(raw_value, 0))
            else:
                value = escape_lua_string(raw_value)
            lines.append(f"        {lua_key} = {value},")
        lines.append("    },")

    lines.extend(
        [
            "}",
            f"DC.SHOP_STATIC_DATA_COUNT = {len(rows)}",
            "",
        ]
    )
    return "\n".join(lines)


def add_string(string_offsets: dict[str, int], string_block: bytearray, value: str) -> int:
    if not value:
        return 0
    if value in string_offsets:
        return string_offsets[value]
    offset = len(string_block)
    string_block.extend(value.encode("utf-8"))
    string_block.append(0)
    string_offsets[value] = offset
    return offset


def build_wdbc_bytes(rows: list[dict[str, Any]], schema: tuple[tuple[str, str], ...]) -> bytes:
    string_offsets: dict[str, int] = {}
    string_block = bytearray(b"\x00")
    records = bytearray()

    for row in rows:
        for field_name, field_type in schema:
            value = row.get(field_name)
            if field_type == "string":
                offset = add_string(string_offsets, string_block, text_or_empty(value))
                records.extend(struct.pack("<I", offset))
            elif field_type == "float":
                records.extend(struct.pack("<f", float_or_default(value, 0.0)))
            else:
                records.extend(struct.pack("<i", int_or_default(value, 0)))

    header = struct.pack(
        "<4s4I",
        b"WDBC",
        len(rows),
        len(schema),
        len(schema) * 4,
        len(string_block),
    )
    return header + records + string_block


def write_if_changed(path: Path, content: bytes) -> bool:
    existing = path.read_bytes() if path.exists() else None
    if existing == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return True


def write_text_if_changed(path: Path, content: str) -> bool:
    existing = path.read_text(encoding="utf-8") if path.exists() else None
    if existing == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="")
    return True


def read_schema_csv_rows(path: Path, schema: tuple[tuple[str, str], ...]) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise ValueError(f"CSV file has no header: {path}")

        expected_fields = [field_name for field_name, _ in schema]
        missing_fields = [
            field_name
            for field_name in expected_fields
            if field_name not in reader.fieldnames
        ]
        if missing_fields:
            raise ValueError(
                f"CSV file {path} is missing required columns: "
                + ", ".join(missing_fields)
            )

        rows: list[dict[str, Any]] = []
        for row in reader:
            normalized_row = {
                field_name: row.get(field_name, "")
                for field_name in expected_fields
            }
            rows.append(normalized_row)

    return rows


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    selected_outputs = (
        {name.strip().lower() for name in args.only if name.strip()}
        if args.only
        else None
    )

    csv_output_dir = (
        args.csv_output_dir.resolve()
        if args.csv_output_dir is not None
        else repo_root / "Custom" / "CSV DBC" / "CDBC"
    )
    cdbc_output_dir = (
        args.cdbc_output_dir.resolve()
        if args.cdbc_output_dir is not None
        else repo_root / "Custom" / "CDBCs"
    )
    patch_output_dir = (
        args.patch_output_dir.resolve()
        if args.patch_output_dir is not None
        else repo_root / "Custom" / "Client patches needed" / "patch-4" / "DBFilesClient"
    )
    addon_data_dir = (
        repo_root / "Custom" / "Client addons needed" / "DC-Collection" / "Data"
    )

    tables = load_collection_definition_tables(repo_root)
    definition_index = load_collection_definition_index(repo_root)
    item_display_ids = load_item_display_ids(repo_root)
    item_display_icons = load_item_display_icons(repo_root)
    item_template_rows = load_item_template_rows(repo_root)
    spell_rows = load_spell_rows(repo_root)
    creature_model_display_ids = load_creature_template_model_display_ids(repo_root)

    category_rows = list(CATEGORY_ROWS)
    source_rows = build_source_rows(
        repo_root,
        tables,
        item_display_ids,
        item_template_rows,
        spell_rows,
        creature_model_display_ids,
    )
    transmog_rows = build_transmog_rows(item_template_rows, item_display_icons)
    shop_static_rows = build_shop_static_rows(tables, source_rows, item_display_ids)
    set_rows = build_set_rows(repo_root)
    completeness_manifest = build_collection_completeness_manifest(
        tables,
        source_rows,
        transmog_rows,
        shop_static_rows,
        definition_index,
    )

    outputs = (
        (
            "DCCollectionCategory",
            category_rows,
            CATEGORY_SCHEMA,
        ),
        (
            "DCCollectionSource",
            source_rows,
            SOURCE_SCHEMA,
        ),
        (
            "DCCollectionSet",
            set_rows,
            SET_SCHEMA,
        ),
        (
            "DCCollectionShop",
            shop_static_rows,
            SHOP_SCHEMA,
        ),
        (
            "DCCollectionTransmog",
            transmog_rows,
            TRANSMOG_SCHEMA,
        ),
    )

    passthrough_outputs = tuple(
        (
            basename,
            read_schema_csv_rows(csv_output_dir / f"{basename}.csv", schema),
            schema,
        )
        for basename, schema in PASSTHROUGH_CDBC_OUTPUTS
    )

    changed_paths: list[Path] = []
    for basename, rows, schema in outputs + passthrough_outputs:
        if selected_outputs is not None and basename.lower() not in selected_outputs:
            continue

        csv_path = csv_output_dir / f"{basename}.csv"
        cdbc_path = cdbc_output_dir / f"{basename}.cdbc"

        if basename.lower().startswith("dccollection"):
            if write_text_if_changed(csv_path, build_csv_content(rows, schema)):
                changed_paths.append(csv_path)

        cdbc_bytes = build_wdbc_bytes(rows, schema)
        if write_if_changed(cdbc_path, cdbc_bytes):
            changed_paths.append(cdbc_path)

        if not args.skip_patch_copy:
            patch_path = patch_output_dir / f"{basename}.cdbc"
            patch_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(cdbc_path, patch_path)
            changed_paths.append(patch_path)

    shop_csv_path = csv_output_dir / "DCCollectionShopStatic.csv"
    if write_text_if_changed(
        shop_csv_path,
        build_csv_content(shop_static_rows, SHOP_STATIC_SCHEMA),
    ):
        changed_paths.append(shop_csv_path)

    shop_lua_path = addon_data_dir / "ShopStatic.lua"
    if write_text_if_changed(
        shop_lua_path,
        build_shop_static_lua_content(shop_static_rows),
    ):
        changed_paths.append(shop_lua_path)

    manifest_json_path = csv_output_dir / "DCCollectionCompletenessManifest.json"
    if write_text_if_changed(
        manifest_json_path,
        build_collection_completeness_json_content(completeness_manifest),
    ):
        changed_paths.append(manifest_json_path)

    manifest_lua_path = addon_data_dir / "CollectionCompletenessManifest.lua"
    if write_text_if_changed(
        manifest_lua_path,
        build_collection_completeness_lua_content(completeness_manifest),
    ):
        changed_paths.append(manifest_lua_path)

    authoritative_types = [
        type_name
        for type_name in MANIFEST_TYPE_ORDER
        if completeness_manifest["types"].get(type_name, {}).get("requestSkip")
    ]

    print(
        "Generated DC collection assets: "
        f"{len(category_rows)} categories, "
        f"{len(source_rows)} sources, "
        f"{len(transmog_rows)} transmog variants, "
        f"{len(shop_static_rows)} shop rows, "
        f"{len(set_rows)} sets"
    )
    print(f"CSV output: {csv_output_dir}")
    print(f"CDBC output: {cdbc_output_dir}")
    if not args.skip_patch_copy:
        print(f"Patch output: {patch_output_dir}")
    print(
        "Authoritative local definition request-skip: "
        + (", ".join(authoritative_types) if authoritative_types else "none")
    )
    print(
        "Authoritative local shop static: "
        f"{completeness_manifest['shop']['authoritative']} "
        f"({completeness_manifest['shop']['resolvedRowCount']}/"
        f"{completeness_manifest['shop']['enabledRowCount']} resolved)"
    )
    print(f"Files updated: {len(changed_paths)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())