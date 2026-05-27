#!/usr/bin/env python3
"""Clean clone-era item upgrade CSV assets and rebuild transmog CDBC.

This tool removes clone item rows from Item.csv using an explicit exported
clone->base mapping, rewrites DCCollectionTransmog.csv to replace clone item
IDs with their base item IDs, and rebuilds DCCollectionTransmog.cdbc.

Expected clone-map input is a delimited text file with header columns similar
to:

    clone_item_id,base_item_id

The tool intentionally does not delete rows based on a raw ID threshold.
Only clone IDs present in the supplied mapping are touched.
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
from pathlib import Path
from typing import Any

from generate_dc_collection_cdbc import (
    TRANSMOG_SCHEMA,
    build_csv_content,
    build_wdbc_bytes,
    int_or_default,
    is_better_transmog_representative,
    load_item_display_icons,
    load_item_template_rows,
    text_or_empty,
    write_if_changed,
    write_text_if_changed,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ITEM_CSV = REPO_ROOT / "Custom" / "CSV DBC" / "Item.csv"
DEFAULT_TRANSMOG_CSV = (
    REPO_ROOT / "Custom" / "CSV DBC" / "CDBC" / "DCCollectionTransmog.csv"
)
DEFAULT_TRANSMOG_CDBC = REPO_ROOT / "Custom" / "CDBCs" / "DCCollectionTransmog.cdbc"
DEFAULT_PATCH_CDBC = (
    REPO_ROOT
    / "Custom"
    / "Client patches needed"
    / "patch-4"
    / "DBFilesClient"
    / "DCCollectionTransmog.cdbc"
)

CLONE_HEADER_ALIASES = (
    "clone_item_id",
    "clone_item_entry",
    "cloneitemid",
    "cloneitementry",
    "cloneid",
)
BASE_HEADER_ALIASES = (
    "base_item_id",
    "base_item_entry",
    "baseitemid",
    "baseitementry",
    "baseid",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Remove item-upgrade clone rows from Item.csv, rewrite "
            "DCCollectionTransmog.csv, and rebuild DCCollectionTransmog.cdbc."
        )
    )
    parser.add_argument(
        "--clone-map",
        type=Path,
        required=True,
        help=(
            "Delimited export containing clone/base item mappings. Required "
            "columns: clone_item_id + base_item_id (or close aliases)."
        ),
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=REPO_ROOT,
        help="Repository root. Defaults to the script's parent repo.",
    )
    parser.add_argument(
        "--item-csv",
        type=Path,
        default=DEFAULT_ITEM_CSV,
        help="Path to Item.csv.",
    )
    parser.add_argument(
        "--transmog-csv",
        type=Path,
        default=DEFAULT_TRANSMOG_CSV,
        help="Path to DCCollectionTransmog.csv.",
    )
    parser.add_argument(
        "--transmog-cdbc",
        type=Path,
        default=DEFAULT_TRANSMOG_CDBC,
        help="Path to DCCollectionTransmog.cdbc.",
    )
    parser.add_argument(
        "--patch-cdbc",
        type=Path,
        default=DEFAULT_PATCH_CDBC,
        help="Optional patch-copy destination for DCCollectionTransmog.cdbc.",
    )
    parser.add_argument(
        "--skip-item-csv",
        action="store_true",
        help="Do not rewrite Item.csv.",
    )
    parser.add_argument(
        "--skip-transmog-csv",
        action="store_true",
        help="Do not rewrite DCCollectionTransmog.csv.",
    )
    parser.add_argument(
        "--skip-cdbc",
        action="store_true",
        help="Do not rebuild DCCollectionTransmog.cdbc.",
    )
    parser.add_argument(
        "--skip-patch-copy",
        action="store_true",
        help="Do not mirror the rebuilt CDBC into the patch bundle path.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Compute and print changes without writing files.",
    )
    return parser.parse_args()


def normalize_header(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.strip().lower())


def sniff_dialect(sample: str) -> csv.Dialect:
    try:
        return csv.Sniffer().sniff(sample, delimiters=",\t;|")
    except csv.Error:
        return csv.excel


def read_delimited_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        sample = handle.read(8192)
        handle.seek(0)
        dialect = sniff_dialect(sample)
        reader = csv.DictReader(handle, dialect=dialect)
        if not reader.fieldnames:
            raise ValueError(f"Delimited file has no header: {path}")
        rows = [{key: value or "" for key, value in row.items()} for row in reader]
        return list(reader.fieldnames), rows


def build_generic_csv_content(
    fieldnames: list[str],
    rows: list[dict[str, Any]],
) -> str:
    header = ",".join(f'"{name}"' for name in fieldnames)
    lines = [header]
    for row in rows:
        values = []
        for fieldname in fieldnames:
            raw = text_or_empty(row.get(fieldname, ""))
            values.append(f'"{raw.replace(chr(34), chr(34) * 2)}"')
        lines.append(",".join(values))
    return "\n".join(lines) + "\n"


def resolve_column(fieldnames: list[str], aliases: tuple[str, ...]) -> str:
    by_normalized = {normalize_header(fieldname): fieldname for fieldname in fieldnames}
    for alias in aliases:
        fieldname = by_normalized.get(normalize_header(alias))
        if fieldname:
            return fieldname
    raise ValueError(
        "Missing required column. Expected one of: " + ", ".join(aliases)
    )


def load_clone_map(path: Path) -> dict[int, int]:
    fieldnames, rows = read_delimited_rows(path)
    clone_field = resolve_column(fieldnames, CLONE_HEADER_ALIASES)
    base_field = resolve_column(fieldnames, BASE_HEADER_ALIASES)

    clone_map: dict[int, int] = {}
    for row_number, row in enumerate(rows, start=2):
        clone_item_id = int_or_default(row.get(clone_field), 0)
        base_item_id = int_or_default(row.get(base_field), 0)

        if clone_item_id <= 0 and base_item_id <= 0:
            continue
        if clone_item_id <= 0 or base_item_id <= 0:
            raise ValueError(
                f"Invalid clone map row {row_number}: both clone and base IDs must be positive"
            )

        existing_base = clone_map.get(clone_item_id)
        if existing_base is not None and existing_base != base_item_id:
            raise ValueError(
                f"Conflicting mapping for clone item {clone_item_id}: "
                f"{existing_base} vs {base_item_id}"
            )

        clone_map[clone_item_id] = base_item_id

    if not clone_map:
        raise ValueError(f"No clone mappings were loaded from {path}")
    return clone_map


def parse_item_ids(value: str) -> list[int]:
    item_ids: list[int] = []
    for token in text_or_empty(value).split(","):
        item_id = int_or_default(token, 0)
        if item_id > 0:
            item_ids.append(item_id)
    return item_ids


def get_item_template_meta(
    item_id: int,
    item_template_rows: dict[int, dict[str, Any]],
) -> tuple[int, int, str, int]:
    item_row = item_template_rows.get(item_id)
    if not item_row:
        return 0, 0, "", 0

    return (
        int_or_default(item_row.get("Quality"), 0),
        int_or_default(item_row.get("ItemLevel"), 0),
        text_or_empty(item_row.get("name")),
        int_or_default(item_row.get("displayid"), 0),
    )


def choose_canonical_item(
    item_ids: list[int],
    row: dict[str, Any],
    item_template_rows: dict[int, dict[str, Any]],
) -> int:
    current_canonical = int_or_default(row.get("CanonicalItemID"), 0)
    current_quality = int_or_default(row.get("Rarity"), 0)
    current_item_level = int_or_default(row.get("ItemLevel"), 0)

    best_item_id = 0
    best_quality = 0
    best_item_level = 0

    for item_id in item_ids:
        quality, item_level, _, _ = get_item_template_meta(item_id, item_template_rows)
        if item_id == current_canonical and (quality <= 0 and item_level <= 0):
            quality = current_quality
            item_level = current_item_level

        if best_item_id <= 0:
            best_item_id = item_id
            best_quality = quality
            best_item_level = item_level
            continue

        if is_better_transmog_representative(
            item_id,
            quality,
            item_level,
            best_item_id,
            best_quality,
            best_item_level,
        ):
            best_item_id = item_id
            best_quality = quality
            best_item_level = item_level

    return best_item_id if best_item_id > 0 else item_ids[0]


def rewrite_item_csv(
    item_csv_path: Path,
    clone_map: dict[int, int],
) -> tuple[str, dict[str, int]]:
    fieldnames, rows = read_delimited_rows(item_csv_path)
    id_field = resolve_column(fieldnames, ("ID",))

    kept_rows: list[dict[str, str]] = []
    removed_rows = 0
    removed_item_ids: set[int] = set()

    for row in rows:
        item_id = int_or_default(row.get(id_field), 0)
        if item_id > 0 and item_id in clone_map:
            removed_rows += 1
            removed_item_ids.add(item_id)
            continue
        kept_rows.append(row)

    content = build_generic_csv_content(fieldnames, kept_rows)
    stats = {
        "rows_before": len(rows),
        "rows_after": len(kept_rows),
        "removed_rows": removed_rows,
        "removed_item_ids": len(removed_item_ids),
    }
    return content, stats


def rewrite_transmog_rows(
    rows: list[dict[str, str]],
    clone_map: dict[int, int],
    item_template_rows: dict[int, dict[str, Any]],
    item_display_icons: dict[int, str],
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    rewritten_rows: list[dict[str, Any]] = []
    rows_touched = 0
    rows_dropped = 0
    clone_refs_rewritten = 0
    canonical_changes = 0

    for row in rows:
        original_item_ids = parse_item_ids(row.get("ItemIDs", ""))
        cleaned_item_ids = sorted(
            {
                clone_map.get(item_id, item_id)
                for item_id in original_item_ids
                if clone_map.get(item_id, item_id) > 0
            }
        )

        clone_refs_rewritten += sum(1 for item_id in original_item_ids if item_id in clone_map)

        if not cleaned_item_ids:
            rows_dropped += 1
            continue

        current_canonical = int_or_default(row.get("CanonicalItemID"), 0)
        normalized_current_canonical = clone_map.get(current_canonical, current_canonical)
        canonical_item_id = choose_canonical_item(
            cleaned_item_ids,
            {
                **row,
                "CanonicalItemID": str(normalized_current_canonical),
            },
            item_template_rows,
        )

        quality, item_level, name, display_id = get_item_template_meta(
            canonical_item_id,
            item_template_rows,
        )

        if normalized_current_canonical != canonical_item_id:
            canonical_changes += 1

        cleaned_item_id_text = ",".join(str(item_id) for item_id in cleaned_item_ids)
        original_item_id_text = text_or_empty(row.get("ItemIDs"))
        if (
            cleaned_item_id_text != original_item_id_text
            or normalized_current_canonical != current_canonical
            or len(cleaned_item_ids) != int_or_default(row.get("ItemIDsTotal"), 0)
            or normalized_current_canonical != canonical_item_id
        ):
            rows_touched += 1

        resolved_display_id = display_id or int_or_default(row.get("DisplayID"), 0)
        resolved_icon = (
            item_display_icons.get(resolved_display_id)
            or text_or_empty(row.get("Icon"))
        )

        rewritten_rows.append(
            {
                "ID": int_or_default(row.get("ID"), 0),
                "DisplayID": int_or_default(row.get("DisplayID"), 0),
                "InventoryType": int_or_default(row.get("InventoryType"), 0),
                "ItemClass": int_or_default(row.get("ItemClass"), 0),
                "ItemSubClass": int_or_default(row.get("ItemSubClass"), 0),
                "VisualSlot": int_or_default(row.get("VisualSlot"), 0),
                "CanonicalItemID": canonical_item_id,
                "Rarity": quality or int_or_default(row.get("Rarity"), 0),
                "ItemLevel": item_level or int_or_default(row.get("ItemLevel"), 0),
                "Name": name or text_or_empty(row.get("Name")),
                "Icon": resolved_icon,
                "ItemIDsTotal": len(cleaned_item_ids),
                "ItemIDs": cleaned_item_id_text,
            }
        )

    stats = {
        "rows_before": len(rows),
        "rows_after": len(rewritten_rows),
        "rows_touched": rows_touched,
        "rows_dropped": rows_dropped,
        "clone_refs_rewritten": clone_refs_rewritten,
        "canonical_changes": canonical_changes,
    }
    return rewritten_rows, stats


def write_outputs(
    *,
    dry_run: bool,
    skip_item_csv: bool,
    skip_transmog_csv: bool,
    skip_cdbc: bool,
    skip_patch_copy: bool,
    item_csv_path: Path,
    transmog_csv_path: Path,
    transmog_cdbc_path: Path,
    patch_cdbc_path: Path,
    item_csv_content: str,
    transmog_rows: list[dict[str, Any]],
) -> list[Path]:
    changed_paths: list[Path] = []

    if not skip_item_csv and not dry_run:
        if write_text_if_changed(item_csv_path, item_csv_content):
            changed_paths.append(item_csv_path)

    if not skip_transmog_csv and not dry_run:
        transmog_csv_content = build_csv_content(transmog_rows, TRANSMOG_SCHEMA)
        if write_text_if_changed(transmog_csv_path, transmog_csv_content):
            changed_paths.append(transmog_csv_path)

    if not skip_cdbc and not dry_run:
        transmog_cdbc_bytes = build_wdbc_bytes(transmog_rows, TRANSMOG_SCHEMA)
        if write_if_changed(transmog_cdbc_path, transmog_cdbc_bytes):
            changed_paths.append(transmog_cdbc_path)

        if not skip_patch_copy:
            patch_cdbc_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(transmog_cdbc_path, patch_cdbc_path)
            changed_paths.append(patch_cdbc_path)

    return changed_paths


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    clone_map_path = args.clone_map.resolve()
    item_csv_path = args.item_csv.resolve()
    transmog_csv_path = args.transmog_csv.resolve()
    transmog_cdbc_path = args.transmog_cdbc.resolve()
    patch_cdbc_path = args.patch_cdbc.resolve()

    clone_map = load_clone_map(clone_map_path)
    item_template_rows = load_item_template_rows(repo_root)
    item_display_icons = load_item_display_icons(repo_root)

    item_csv_content, item_stats = rewrite_item_csv(item_csv_path, clone_map)
    _, transmog_csv_rows = read_delimited_rows(transmog_csv_path)
    transmog_rows, transmog_stats = rewrite_transmog_rows(
        transmog_csv_rows,
        clone_map,
        item_template_rows,
        item_display_icons,
    )

    changed_paths = write_outputs(
        dry_run=args.dry_run,
        skip_item_csv=args.skip_item_csv,
        skip_transmog_csv=args.skip_transmog_csv,
        skip_cdbc=args.skip_cdbc,
        skip_patch_copy=args.skip_patch_copy,
        item_csv_path=item_csv_path,
        transmog_csv_path=transmog_csv_path,
        transmog_cdbc_path=transmog_cdbc_path,
        patch_cdbc_path=patch_cdbc_path,
        item_csv_content=item_csv_content,
        transmog_rows=transmog_rows,
    )

    print(f"Loaded {len(clone_map)} clone mappings from {clone_map_path}")
    print(
        "Item.csv: "
        f"removed {item_stats['removed_rows']} clone rows "
        f"({item_stats['rows_before']} -> {item_stats['rows_after']})"
    )
    print(
        "DCCollectionTransmog.csv: "
        f"rewrote {transmog_stats['clone_refs_rewritten']} clone references across "
        f"{transmog_stats['rows_touched']} rows; "
        f"dropped {transmog_stats['rows_dropped']} empty rows; "
        f"canonical changed on {transmog_stats['canonical_changes']} rows"
    )

    if args.dry_run:
        print("Dry run only; no files were written.")
    elif changed_paths:
        print("Updated files:")
        for path in changed_paths:
            print(f"  {path}")
    else:
        print("No file content changed.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())