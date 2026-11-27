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
    parser.add_argument(
        "--mysql-host",
        help=(
            "Read from the LIVE world database instead of the base SQL dumps. "
            "The dumps only hold stock AzerothCore content, so custom zones "
            "(map 750 and friends) are missing from them entirely."
        ),
    )
    parser.add_argument("--mysql-port", type=int, default=3306)
    parser.add_argument("--mysql-user", default="acore")
    parser.add_argument("--mysql-password", default="acore")
    parser.add_argument("--mysql-db", default="acore_world")
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


class SqlFileSource:
    """Default source: the AzerothCore base SQL dumps checked into the repo."""

    def __init__(self, world_sql_root: Path):
        self.root = world_sql_root

    def records(self, table: str) -> list[dict[str, object]]:
        return build_records(self.root / f"{table}.sql")

    def close(self) -> None:
        pass


class MySqlSource:
    """Live world database.

    The base SQL dumps only contain STOCK AzerothCore content, so a realm with
    custom zones generates quest data that silently omits them -- map 750 has
    788 quests and produced exactly zero markers. The live `acore_world` is the
    superset (base content plus every applied custom SQL), so when this source is
    used it REPLACES the files rather than merging: there is nothing in the dumps
    that the database does not already have, and merging two sources of the same
    rows only invites disagreement about which wins.
    """

    def __init__(self, host: str, port: int, user: str, password: str, database: str):
        try:
            import pymysql
        except ImportError as exc:  # pragma: no cover - depends on environment
            raise SystemExit(
                "--mysql-host needs PyMySQL: pip install pymysql"
            ) from exc

        self._pymysql = pymysql
        try:
            self.conn = pymysql.connect(
                host=host,
                port=port,
                user=user,
                password=password,
                database=database,
                charset="utf8mb4",
                cursorclass=pymysql.cursors.DictCursor,
            )
        except pymysql.err.OperationalError as exc:
            code = exc.args[0] if exc.args else 0
            hint = ""
            if code == 1045:
                hint = (
                    "\n  Access denied. MySQL grants are per HOST, so credentials that work\n"
                    "  on the server itself are still refused from another machine. Either run\n"
                    "  this on the DB host, or grant your workstation:\n"
                    f"      GRANT SELECT ON {database}.* TO '{user}'@'<your-ip>' IDENTIFIED BY '<pw>';"
                )
            elif code == 2003:
                hint = "\n  Could not reach the server -- check the host/port and that MySQL listens externally."
            raise SystemExit(f"MySQL connection failed: {exc}{hint}") from exc

    def records(self, table: str) -> list[dict[str, object]]:
        with self.conn.cursor() as cur:
            cur.execute(f"SELECT * FROM `{table}`")
            return list(cur.fetchall())

    def close(self) -> None:
        try:
            self.conn.close()
        except Exception:
            pass


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


def choose_world_map_area_by_position(
    rows: list[dict[str, object]],
    raw_x: float,
    raw_y: float,
) -> dict[str, object] | None:
    """Resolve the WorldMapArea containing a world position on a given map: the
    smallest Loc rect that contains the point (most specific zone) wins. Needed
    because this fork's spawn tables carry zoneId/areaId = 0 almost everywhere,
    which starves the id-based resolution."""
    best_row = None
    best_span = None
    for row in rows:
        try:
            left = float(row["LocLeft"])
            right = float(row["LocRight"])
            top = float(row["LocTop"])
            bottom = float(row["LocBottom"])
        except (KeyError, TypeError, ValueError):
            continue
        if normalize_coord(raw_y, left, right) is None:
            continue
        if normalize_coord(raw_x, top, bottom) is None:
            continue
        span = abs(left - right) * abs(top - bottom)
        if span <= 0:
            continue
        if best_span is None or span < best_span:
            best_span = span
            best_row = row
    return best_row


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
    z_field: str | None = None,
    map_rect_rows: dict[int, list[dict[str, object]]] | None = None,
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
        if not world_map_area and map_rect_rows is not None and isinstance(map_id, int):
            world_map_area = choose_world_map_area_by_position(
                map_rect_rows.get(map_id) or [],
                float(raw_x),
                float(raw_y),
            )
        if not world_map_area:
            continue

        normalized = normalize_world_point(float(raw_x), float(raw_y), world_map_area)
        if not normalized:
            continue

        normalized_x, normalized_y = normalized
        point: dict[str, object] = {
            "m": int(world_map_area["ID"]),
            "x": normalized_x,
            "y": normalized_y,
        }
        # World Z (spawn height) rides along so the in-world supertracker pin can
        # sit on the real ground instead of guessing from the player's elevation.
        if z_field is not None:
            raw_z = record.get(z_field)
            if isinstance(raw_z, (int, float)):
                point["z"] = round(float(raw_z), 1)
        lookup[entity_id].append(point)

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


def load_relation_map(source, table: str) -> dict[int, list[int]]:
    relation_rows = source.records(table)
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

    if args.mysql_host:
        source = MySqlSource(
            args.mysql_host,
            args.mysql_port,
            args.mysql_user,
            args.mysql_password,
            args.mysql_db,
        )
        print(f"source: live database {args.mysql_user}@{args.mysql_host}:{args.mysql_port}/{args.mysql_db}")
    else:
        source = SqlFileSource(world_sql_root)
        print(f"source: base SQL dumps at {world_sql_root}")
        print(
            "  NOTE: the dumps are STOCK content only -- custom zones such as map 750\n"
            "        will be absent. Pass --mysql-host to read the live world DB."
        )

    quest_template_rows = source.records("quest_template")
    quests: dict[int, dict[str, object]] = {}
    for row in quest_template_rows:
        quest_id = row.get("ID")
        title = row.get("LogTitle") or row.get("QuestDescription") or row.get("QuestCompletionLog")
        level = row.get("QuestLevel")
        if isinstance(quest_id, int) and isinstance(title, str):
            quests[quest_id] = {"t": title, "l": int(level) if isinstance(level, int) else 0}

    creature_starters = load_relation_map(source, "creature_queststarter")
    gameobject_starters = load_relation_map(source, "gameobject_queststarter")
    creature_enders = load_relation_map(source, "creature_questender")
    gameobject_enders = load_relation_map(source, "gameobject_questender")

    # Objective entities (RequiredNpcOrGo1..4: positive = creature entry, negative
    # = gameobject entry). Their spawn heights supply the world Z for objective
    # POI markers, which quest_poi_points lacks entirely.
    quest_objective_entities: dict[int, list[tuple[str, int]]] = defaultdict(list)
    for row in quest_template_rows:
        quest_id = row.get("ID")
        if not isinstance(quest_id, int):
            continue
        for index in range(1, 5):
            entity = row.get(f"RequiredNpcOrGo{index}")
            if isinstance(entity, int) and entity > 0:
                quest_objective_entities[quest_id].append(("npc", entity))
            elif isinstance(entity, int) and entity < 0:
                quest_objective_entities[quest_id].append(("object", -entity))

    objective_creature_ids = {
        entity_id
        for entities in quest_objective_entities.values()
        for kind, entity_id in entities
        if kind == "npc"
    }
    objective_gameobject_ids = {
        entity_id
        for entities in quest_objective_entities.values()
        for kind, entity_id in entities
        if kind == "object"
    }

    creature_ids = set(creature_starters) | set(creature_enders) | objective_creature_ids
    gameobject_ids = set(gameobject_starters) | set(gameobject_enders) | objective_gameobject_ids

    # WorldMapArea rows grouped by terrain MapID for geometric (rect-contains)
    # zone resolution -- this fork's spawn rows have zoneId/areaId = 0.
    map_rect_rows: dict[int, list[dict[str, object]]] = defaultdict(list)
    for row in world_map_by_id.values():
        try:
            terrain_map_id = int(float(row["MapID"]))
        except (KeyError, TypeError, ValueError):
            continue
        map_rect_rows[terrain_map_id].append(row)

    creature_rows = source.records("creature")
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
        z_field="position_z",
        map_rect_rows=map_rect_rows,
    )

    gameobject_rows = source.records("gameobject")
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
        z_field="position_z",
        map_rect_rows=map_rect_rows,
    )

    def resolve_objective_z(quest_id: int, world_map_area_id: int, centroid_x: float, centroid_y: float) -> float | None:
        """World Z for an objective POI: average the quest's objective-entity spawn
        heights near the POI centroid (same WorldMapArea). Falls back to the single
        nearest spawn when none are close; None when the quest has no locatable
        objective entities there."""
        best: list[float] = []
        nearest_z: float | None = None
        nearest_dist_sq: float | None = None
        for kind, entity_id in quest_objective_entities.get(quest_id, []):
            spawns = creature_spawns if kind == "npc" else gameobject_spawns
            for point in spawns.get(entity_id, []):
                if point.get("m") != world_map_area_id or point.get("z") is None:
                    continue
                dx = float(point["x"]) - centroid_x
                dy = float(point["y"]) - centroid_y
                dist_sq = (dx * dx) + (dy * dy)
                if dist_sq <= 0.12 * 0.12:
                    best.append(float(point["z"]))
                if nearest_dist_sq is None or dist_sq < nearest_dist_sq:
                    nearest_dist_sq = dist_sq
                    nearest_z = float(point["z"])
        if best:
            return round(sum(best) / len(best), 1)
        if nearest_z is not None and nearest_dist_sq is not None and nearest_dist_sq <= 0.25 * 0.25:
            return round(nearest_z, 1)
        return None

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

    poi_rows = source.records("quest_poi")
    poi_points_rows = source.records("quest_poi_points")
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
        objective_z = resolve_objective_z(quest_id, world_map_area_id, centroid[0], centroid[1])
        if objective_z is not None:
            marker["z"] = objective_z
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
                if marker.get("z") is not None:
                    marker_fields.append(f"z={format_lua_value(marker.get('z'))}")
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
        f"data.generatedAt = {format_lua_value('2026-07-12')}",
        "",
    ])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(output_lines), encoding="utf-8", newline="\n")
    source.close()
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()