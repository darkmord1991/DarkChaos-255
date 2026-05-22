from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
WORLD_SQL_ROOT = REPO_ROOT / "data" / "sql" / "base" / "db_world"
CUSTOM_CSV_ROOT = REPO_ROOT / "Custom" / "CSV DBC"
OUTPUT_FILE = (
    REPO_ROOT
    / "Custom"
    / "Client addons needed"
    / "DC-QOS"
    / "Modules"
    / "QuestMapData.lua"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate DC-QOS quest map data from AzerothCore world SQL and "
            "custom DBC CSV exports."
        )
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=REPO_ROOT,
        help="Repository root. Defaults to the parent of this script.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=OUTPUT_FILE,
        help="Output Lua file path.",
    )
    return parser.parse_args()


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader)


def parse_csv_int(value: str | None) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    return int(float(text.replace(",", ".")))


def parse_csv_float(value: str | None) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    return float(text.replace(",", "."))


def parse_table_columns(path: Path) -> list[str]:
    columns: list[str] = []
    in_create = False

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line.startswith("CREATE TABLE"):
                in_create = True
                continue
            if not in_create:
                continue
            if line.startswith(")"):
                break
            if not line.startswith("`"):
                continue

            end = line.find("`", 1)
            if end == -1:
                continue
            columns.append(line[1:end])

    if not columns:
        raise RuntimeError(f"Unable to parse column list from {path}")

    return columns


def split_sql_fields(row: str) -> list[str]:
    fields: list[str] = []
    current: list[str] = []
    in_quote = False
    escape = False

    for char in row:
        if in_quote:
            current.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == "'":
                in_quote = False
            continue

        if char == "'":
            in_quote = True
            current.append(char)
            continue

        if char == ",":
            fields.append("".join(current).strip())
            current = []
            continue

        current.append(char)

    if current:
        fields.append("".join(current).strip())

    return fields


def iter_insert_rows(path: Path) -> list[list[str]]:
    rows: list[list[str]] = []
    statement_parts: list[str] = []
    capturing = False

    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            stripped = raw_line.lstrip()
            if stripped.startswith("INSERT INTO"):
                capturing = True
                statement_parts = [raw_line]
                if raw_line.rstrip().endswith(";"):
                    rows.extend(parse_insert_statement("".join(statement_parts)))
                    capturing = False
                continue

            if not capturing:
                continue

            statement_parts.append(raw_line)
            if raw_line.rstrip().endswith(";"):
                rows.extend(parse_insert_statement("".join(statement_parts)))
                capturing = False

    return rows


def parse_insert_statement(statement: str) -> list[list[str]]:
    values_index = statement.find("VALUES")
    if values_index == -1:
        return []

    payload = statement[values_index + len("VALUES") :].strip()
    if payload.endswith(";"):
        payload = payload[:-1]

    rows: list[list[str]] = []
    current: list[str] = []
    depth = 0
    in_quote = False
    escape = False

    for char in payload:
        if in_quote:
            current.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == "'":
                in_quote = False
            continue

        if char == "'":
            in_quote = True
            current.append(char)
            continue

        if char == "(":
            if depth > 0:
                current.append(char)
            depth += 1
            continue

        if char == ")":
            depth -= 1
            if depth == 0:
                rows.append(split_sql_fields("".join(current)))
                current = []
            else:
                current.append(char)
            continue

        if depth > 0:
            current.append(char)

    return rows


def sql_to_python(value: str):
    text = value.strip()
    if text == "NULL":
        return None
    if text.startswith("'") and text.endswith("'"):
        inner = text[1:-1]
        inner = inner.replace("\\'", "'")
        inner = inner.replace('\\"', '"')
        inner = inner.replace("\\n", "\n")
        inner = inner.replace("\\r", "\r")
        inner = inner.replace("\\\\", "\\")
        return inner
    try:
        if "." in text:
            return float(text)
        return int(text)
    except ValueError:
        return text


def build_records(path: Path) -> list[dict[str, object]]:
    columns = parse_table_columns(path)
    rows = iter_insert_rows(path)
    return [dict(zip(columns, (sql_to_python(value) for value in row), strict=False)) for row in rows]


def normalize_coord(value: float, min_value: float, max_value: float) -> float | None:
    span = max_value - min_value
    if span == 0:
        return None
    normalized = (value - min_value) / span
    if -0.02 <= normalized <= 1.02:
        return max(0.0, min(1.0, normalized))
    return None


def dedupe_points(points: list[dict[str, object]]) -> list[dict[str, object]]:
    seen: set[tuple[object, ...]] = set()
    unique: list[dict[str, object]] = []
    for point in points:
        key = (
            point.get("m"),
            round(float(point.get("x", 0.0)), 4),
            round(float(point.get("y", 0.0)), 4),
            point.get("k"),
            point.get("i"),
        )
        if key in seen:
            continue
        seen.add(key)
        unique.append(point)
    return unique


def format_lua_value(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return f"{value:.4f}".rstrip("0").rstrip(".")
    text = str(value)
    text = (
        text.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )
    return f'"{text}"'


def choose_world_map_area(
    area_id: int | None,
    map_id: int | None,
    area_parent: dict[int, int | None],
    area_to_rows: dict[int, list[dict[str, object]]],
) -> dict[str, object] | None:
    current = area_id
    visited: set[int] = set()

    while current and current not in visited:
        visited.add(current)
        candidates = area_to_rows.get(current) or []
        if candidates:
            if map_id is not None:
                for candidate in candidates:
                    if int(candidate["MapID"]) == map_id:
                        return candidate
            return candidates[0]
        current = area_parent.get(current)

    return None


def build_world_map_lookup(repo_root: Path):
    world_map_rows = read_csv_rows(repo_root / "Custom" / "CSV DBC" / "WorldMapArea.csv")
    area_rows_by_area: dict[int, list[dict[str, object]]] = defaultdict(list)
    world_map_by_id: dict[int, dict[str, object]] = {}

    for row in world_map_rows:
        map_id = parse_csv_int(row["MapID"])
        area_id = parse_csv_int(row["AreaID"])
        row_id = parse_csv_int(row["ID"])
        left = parse_csv_float(row["LocLeft"])
        right = parse_csv_float(row["LocRight"])
        top = parse_csv_float(row["LocTop"])
        bottom = parse_csv_float(row["LocBottom"])
        if None in (map_id, area_id, row_id, left, right, top, bottom):
            continue

        parsed = {
            "ID": row_id,
            "MapID": map_id,
            "AreaID": area_id,
            "LocLeft": left,
            "LocRight": right,
            "LocTop": top,
            "LocBottom": bottom,
            "AreaName": row.get("AreaName") or "",
        }
        world_map_by_id[row_id] = parsed
        area_rows_by_area[area_id].append(parsed)

    area_parent: dict[int, int | None] = {}
    for row in read_csv_rows(repo_root / "Custom" / "CSV DBC" / "AreaTable.csv"):
        area_id = parse_csv_int(row["ID"])
        parent_area = parse_csv_int(row["ParentAreaID"])
        if area_id is not None:
            area_parent[area_id] = parent_area

    return world_map_by_id, area_rows_by_area, area_parent


def normalize_world_point(raw_x: float, raw_y: float, world_map_area: dict[str, object]):
    left = float(world_map_area["LocLeft"])
    right = float(world_map_area["LocRight"])
    top = float(world_map_area["LocTop"])
    bottom = float(world_map_area["LocBottom"])
    normalized_x = normalize_coord(raw_y, left, right)
    normalized_y = normalize_coord(raw_x, top, bottom)
    if normalized_x is None or normalized_y is None:
        return None
    return normalized_x, normalized_y


def build_spawn_lookup(
    records: list[dict[str, object]],
    entity_id_field: str,
    map_field: str,
    zone_field: str,
    area_field: str,
    x_field: str,
    y_field: str,
    needed_entity_ids: set[int],
    area_parent: dict[int, int | None],
    area_to_rows: dict[int, list[dict[str, object]]],
) -> dict[int, list[dict[str, object]]]:
    lookup: dict[int, list[dict[str, object]]] = defaultdict(list)

    for record in records:
        entity_id = record.get(entity_id_field)
        if not isinstance(entity_id, int) or entity_id not in needed_entity_ids:
            continue

        map_id = record.get(map_field)
        zone_id = record.get(zone_field)
        area_id = record.get(area_field)
        raw_x = record.get(x_field)
        raw_y = record.get(y_field)
        if not isinstance(raw_x, (int, float)) or not isinstance(raw_y, (int, float)):
            continue

        world_map_area = choose_world_map_area(
            zone_id if isinstance(zone_id, int) and zone_id > 0 else area_id,
            map_id if isinstance(map_id, int) else None,
            area_parent,
            area_to_rows,
        )
        if not world_map_area:
            continue

        normalized = normalize_world_point(float(raw_x), float(raw_y), world_map_area)
        if not normalized:
            continue

        normalized_x, normalized_y = normalized
        lookup[entity_id].append(
            {
                "m": int(world_map_area["ID"]),
                "x": normalized_x,
                "y": normalized_y,
            }
        )

    for entity_id, points in list(lookup.items()):
        lookup[entity_id] = dedupe_points(points)

    return lookup


def compute_centroid(points: list[tuple[float, float]]) -> tuple[float, float] | None:
    if not points:
        return None
    x_total = 0.0
    y_total = 0.0
    for point_x, point_y in points:
        x_total += point_x
        y_total += point_y
    count = float(len(points))
    return x_total / count, y_total / count


def append_marker(store: dict[int, dict[str, object]], quest_id: int, key: str, marker: dict[str, object]):
    quest = store.setdefault(quest_id, {})
    bucket = quest.setdefault(key, [])
    bucket.append(marker)


def load_relation_map(path: Path) -> dict[int, list[int]]:
    relation_rows = build_records(path)
    relation_map: dict[int, list[int]] = defaultdict(list)
    for row in relation_rows:
        entity_id = row.get("id")
        quest_id = row.get("quest")
        if isinstance(entity_id, int) and isinstance(quest_id, int):
            relation_map[entity_id].append(quest_id)
    return relation_map


def main() -> None:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    output_path = args.output.resolve()

    world_sql_root = repo_root / "data" / "sql" / "base" / "db_world"
    world_map_by_id, area_to_rows, area_parent = build_world_map_lookup(repo_root)

    quest_template_rows = build_records(world_sql_root / "quest_template.sql")
    quests: dict[int, dict[str, object]] = {}
    for row in quest_template_rows:
        quest_id = row.get("ID")
        title = row.get("LogTitle") or row.get("QuestDescription") or row.get("QuestCompletionLog")
        level = row.get("QuestLevel")
        if isinstance(quest_id, int) and isinstance(title, str):
            quests[quest_id] = {"t": title, "l": int(level) if isinstance(level, int) else 0}

    creature_starters = load_relation_map(world_sql_root / "creature_queststarter.sql")
    gameobject_starters = load_relation_map(world_sql_root / "gameobject_queststarter.sql")
    creature_enders = load_relation_map(world_sql_root / "creature_questender.sql")
    gameobject_enders = load_relation_map(world_sql_root / "gameobject_questender.sql")

    creature_ids = set(creature_starters) | set(creature_enders)
    gameobject_ids = set(gameobject_starters) | set(gameobject_enders)

    creature_rows = build_records(world_sql_root / "creature.sql")
    creature_spawns = build_spawn_lookup(
        creature_rows,
        entity_id_field="id1",
        map_field="map",
        zone_field="zoneId",
        area_field="areaId",
        x_field="position_x",
        y_field="position_y",
        needed_entity_ids=creature_ids,
        area_parent=area_parent,
        area_to_rows=area_to_rows,
    )

    gameobject_rows = build_records(world_sql_root / "gameobject.sql")
    gameobject_spawns = build_spawn_lookup(
        gameobject_rows,
        entity_id_field="id",
        map_field="map",
        zone_field="zoneId",
        area_field="areaId",
        x_field="position_x",
        y_field="position_y",
        needed_entity_ids=gameobject_ids,
        area_parent=area_parent,
        area_to_rows=area_to_rows,
    )

    for entity_id, quest_ids in creature_starters.items():
        for quest_id in quest_ids:
            for point in creature_spawns.get(entity_id, []):
                append_marker(quests, quest_id, "s", {**point, "k": "npc"})

    for entity_id, quest_ids in gameobject_starters.items():
        for quest_id in quest_ids:
            for point in gameobject_spawns.get(entity_id, []):
                append_marker(quests, quest_id, "s", {**point, "k": "object"})

    for entity_id, quest_ids in creature_enders.items():
        for quest_id in quest_ids:
            for point in creature_spawns.get(entity_id, []):
                append_marker(quests, quest_id, "r", {**point, "k": "npc"})

    for entity_id, quest_ids in gameobject_enders.items():
        for quest_id in quest_ids:
            for point in gameobject_spawns.get(entity_id, []):
                append_marker(quests, quest_id, "r", {**point, "k": "object"})

    poi_rows = build_records(world_sql_root / "quest_poi.sql")
    poi_points_rows = build_records(world_sql_root / "quest_poi_points.sql")
    poi_points_by_key: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)

    for row in poi_points_rows:
        quest_id = row.get("QuestID")
        poi_id = row.get("Idx1")
        raw_x = row.get("X")
        raw_y = row.get("Y")
        if isinstance(quest_id, int) and isinstance(poi_id, int) and isinstance(raw_x, int) and isinstance(raw_y, int):
            poi_points_by_key[(quest_id, poi_id)].append((raw_x, raw_y))

    for row in poi_rows:
        quest_id = row.get("QuestID")
        poi_id = row.get("id")
        objective_index = row.get("ObjectiveIndex")
        world_map_area_id = row.get("WorldMapAreaId")
        if not all(isinstance(value, int) for value in (quest_id, poi_id, objective_index, world_map_area_id)):
            continue

        world_map_area = world_map_by_id.get(world_map_area_id)
        if not world_map_area:
            continue

        points = poi_points_by_key.get((quest_id, poi_id)) or []
        normalized_points: list[tuple[float, float]] = []
        for raw_x, raw_y in points:
            normalized = normalize_world_point(float(raw_x), float(raw_y), world_map_area)
            if normalized:
                normalized_points.append(normalized)

        centroid = compute_centroid(normalized_points)
        if not centroid:
            continue

        marker = {
            "m": world_map_area_id,
            "x": centroid[0],
            "y": centroid[1],
        }
        if objective_index >= 0:
            marker["i"] = objective_index
            append_marker(quests, quest_id, "o", marker)
        else:
            marker["k"] = "poi"
            append_marker(quests, quest_id, "r", marker)

    for quest in quests.values():
        for key in ("s", "r", "o"):
            if key in quest:
                quest[key] = sorted(
                    dedupe_points(quest[key]),
                    key=lambda point: (
                        int(point.get("m", 0)),
                        float(point.get("y", 0.0)),
                        float(point.get("x", 0.0)),
                        str(point.get("k", "")),
                        int(point.get("i", -1)),
                    ),
                )

    output_lines = [
        "-- Auto-generated by tools/generate_dcqos_quest_map_data.py.",
        "-- Do not edit by hand; regenerate from the repo quest/world SQL and DBC CSV exports.",
        "",
        "local addon = DCQOS",
        "if not addon then",
        "    return",
        "end",
        "",
        "local data = addon.QuestMapData or {}",
        "addon.QuestMapData = data",
        "",
        "data.quests = {",
    ]

    for quest_id in sorted(quests):
        quest = quests[quest_id]
        title = quest.get("t")
        if not title:
            continue

        fields = [f"t={format_lua_value(title)}", f"l={format_lua_value(quest.get('l', 0))}"]
        for key in ("s", "r", "o"):
            markers = quest.get(key)
            if not markers:
                continue
            marker_values = []
            for marker in markers:
                marker_fields = [
                    f"m={format_lua_value(marker.get('m'))}",
                    f"x={format_lua_value(marker.get('x'))}",
                    f"y={format_lua_value(marker.get('y'))}",
                ]
                if marker.get("k") is not None:
                    marker_fields.append(f"k={format_lua_value(marker.get('k'))}")
                if marker.get("i") is not None:
                    marker_fields.append(f"i={format_lua_value(marker.get('i'))}")
                marker_values.append("{" + ",".join(marker_fields) + "}")
            fields.append(f"{key}={{" + ",".join(marker_values) + "}")

        output_lines.append(f"    [{quest_id}]={{" + ",".join(fields) + "},")

    output_lines.extend([
        "}",
        "",
        f"data.generatedAt = {format_lua_value('2026-05-10')}",
        "",
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(output_lines), encoding="utf-8", newline="\n")
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()