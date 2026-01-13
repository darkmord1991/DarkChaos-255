import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CHECKER = REPO / "Custom" / "Eluna scripts" / "dc_table_checker.lua"
CHARS_SCHEMA = REPO / "Custom" / "Custom feature SQLs" / "acore_chars schema.sql"
WORLD_SCHEMA = REPO / "Custom" / "Custom feature SQLs" / "world schema.sql"

ENTRY_RE = re.compile(
    r"\{\s*\"(?P<schema>acore_chars|acore_world)\"\s*,\s*\"(?P<table>[^\"]+)\"\s*,\s*\"(?P<feature>[^\"]*)\"\s*,\s*(?P<critical>true|false)\s*\}",
    re.IGNORECASE,
)

CREATE_TABLE_RE = re.compile(
    r"(?i)CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+`(?P<table>dc_[^`]+)`"
)


def extract_dc_tables(schema_path: Path) -> list[str]:
    text = schema_path.read_text(encoding="utf-8", errors="ignore")
    tables = sorted({m.group("table") for m in CREATE_TABLE_RE.finditer(text)})
    return tables


def guess_feature(table: str) -> str:
    t = table.lower()
    if t.startswith("dc_aoeloot_"):
        return "AoE Loot"
    if t.startswith("dc_artifact_") or t.startswith("dc_player_artifact_") or t.startswith("dc_chaos_artifact_"):
        return "Artifacts"
    if (
        t.startswith("dc_collection_")
        or t.endswith("_collection")
        or t in {"dc_mount_collection", "dc_pet_collection", "dc_toy_collection", "dc_transmog_collection", "dc_title_collection", "dc_heirloom_collection"}
    ):
        return "Collection System"
    if t.startswith("dc_cross_system_"):
        return "Cross-System"
    if t.startswith("dc_duel_"):
        return "Duel System"
    if t.startswith("dc_group_finder_"):
        return "Group Finder"
    if t.startswith("dc_guild_house"):
        return "Guild Housing"
    if "leaderboard" in t or t.startswith("dc_leaderboard_") or t == "dc_guild_upgrade_stats":
        return "Leaderboards"
    if t.startswith("dc_heirloom_"):
        return "Heirloom"
    if t.startswith("dc_hlbg_"):
        return "HLBG System"
    if (
        t.startswith("dc_item_upgrade_")
        or t == "dc_item_upgrades"
        or t.startswith("dc_upgrade_")
        or t.startswith("dc_player_upgrade_")
        or t == "dc_player_item_upgrades"
    ):
        return "Item Upgrade"
    if t.startswith("dc_migration_"):
        return "Migration"
    if t.startswith("dc_mplus_") or t.startswith("dc_mythic_") or t.startswith("dc_spectator_"):
        return "Mythic+"
    if t.startswith("dc_character_") or t.startswith("dc_dungeon_") or t.startswith("dc_player_dungeon_"):
        return "Dungeon System"
    if t.startswith("dc_season") or t.startswith("dc_player_season"):
        return "Season System"
    if t.startswith("dc_token_"):
        return "Token System"
    if t.startswith("dc_vault_") or t.startswith("dc_weekly_"):
        return "Weekly Vault"
    if t.startswith("dc_welcome_") or t.startswith("dc_player_welcome") or t == "dc_player_seen_features":
        return "Welcome System"
    if t.startswith("dc_addon_protocol_"):
        return "Protocol Logging"
    if t.startswith("dc_prestige_") or t.startswith("dc_character_prestige"):
        return "Prestige"
    if t in {"dc_item_custom_data", "dc_spell_custom_data"}:
        return "Custom Data"
    if t.startswith("dc_teleporter") or t.startswith("dc_hotspots_"):
        return "Teleporters"
    if "quest" in t:
        return "Quest System"
    return "Misc"


def replace_required_tables_block(lua_text: str, new_block_lines: list[str]) -> str:
    lines = lua_text.splitlines(keepends=True)

    start_idx = None
    for i, line in enumerate(lines):
        if re.search(r"\bREQUIRED_TABLES\s*=\s*\{", line):
            start_idx = i
            break
    if start_idx is None:
        raise RuntimeError("Could not find REQUIRED_TABLES block")

    # Find matching closing brace for the REQUIRED_TABLES table.
    depth = 0
    end_idx = None
    for i in range(start_idx, len(lines)):
        line = lines[i]
        # Count braces on this line
        for ch in line:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end_idx = i
                    break
        if end_idx is not None:
            break

    if end_idx is None:
        raise RuntimeError("Could not find end of REQUIRED_TABLES block")

    # Preserve trailing comma after the closing brace if present.
    trailing = ""
    if lines[end_idx].rstrip().endswith("},"):
        trailing = ","

    # Build replacement block
    indent_match = re.match(r"^(\s*)", lines[start_idx])
    indent = indent_match.group(1) if indent_match else ""
    out = []
    out.append(f"{indent}REQUIRED_TABLES = {{\n")
    out.extend(new_block_lines)
    out.append(f"{indent}}}{trailing}\n")

    return "".join(lines[:start_idx] + out + lines[end_idx + 1 :])


def main() -> None:
    chars_tables = extract_dc_tables(CHARS_SCHEMA)
    world_tables = extract_dc_tables(WORLD_SCHEMA)

    chars_set = set(chars_tables)
    world_set = set(world_tables)

    existing_text = CHECKER.read_text(encoding="utf-8", errors="ignore")
    existing_entries = []
    for m in ENTRY_RE.finditer(existing_text):
        schema = m.group("schema")
        table = m.group("table")
        feature = m.group("feature")
        critical = m.group("critical").lower()
        existing_entries.append((schema, table, feature, critical))

    kept = []
    seen = set()
    for schema, table, feature, critical in existing_entries:
        if not table.startswith("dc_"):
            continue
        exists = (table in chars_set) if schema == "acore_chars" else (table in world_set)
        if not exists:
            continue
        key = (schema, table)
        if key in seen:
            continue
        seen.add(key)
        kept.append((schema, table, feature, critical))

    # Add any schema tables missing from the checker
    for table in chars_tables:
        key = ("acore_chars", table)
        if key in seen:
            continue
        seen.add(key)
        kept.append(("acore_chars", table, guess_feature(table), "false"))

    for table in world_tables:
        key = ("acore_world", table)
        if key in seen:
            continue
        seen.add(key)
        kept.append(("acore_world", table, guess_feature(table), "false"))

    kept.sort(key=lambda x: (x[0], x[1]))

    # Format new block lines
    new_lines = []
    for schema, table, feature, critical in kept:
        new_lines.append(f"        {{\"{schema}\", \"{table}\", \"{feature}\", {critical}}},\n")

    updated = replace_required_tables_block(existing_text, new_lines)

    # Also drop any now-stale VIEW checks section from REQUIRED_TABLES (already filtered by schema list)
    CHECKER.write_text(updated, encoding="utf-8")

    print(f"Updated {CHECKER} with {len(kept)} REQUIRED_TABLES entries (chars={len(chars_tables)}, world={len(world_tables)}).")


if __name__ == "__main__":
    main()
