#!/usr/bin/env python3
"""Validate addon startup hazards that evade plain luac/luacheck scans.

Checks two failure classes:
1. XML handlers that execute before their global function is defined in TOC load order.
2. Forward-declared top-level locals that are later redeclared with `local function`
   or `local name = function`, which can shadow the original local.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


TOP_LEVEL_FORWARD_DECL_RE = re.compile(
    r"^local\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:--.*)?$"
)
TOP_LEVEL_LOCAL_FUNCTION_RE = re.compile(
    r"^local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("
)
TOP_LEVEL_LOCAL_ASSIGN_FUNCTION_RE = re.compile(
    r"^local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\("
)
TOP_LEVEL_GLOBAL_FUNCTION_RE = re.compile(
    r"^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("
)
TOP_LEVEL_GLOBAL_ASSIGN_FUNCTION_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\("
)
TOP_LEVEL_GLOBAL_TABLE_ASSIGN_FUNCTION_RE = re.compile(
    r"^_G\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\("
)

XML_SCRIPT_BLOCK_RE = re.compile(r"<(On[A-Za-z]+)\b([^>]*)>(.*?)</\1>", re.IGNORECASE | re.DOTALL)
XML_FUNCTION_ATTR_RE = re.compile(
    r"\bfunction\s*=\s*\"([A-Za-z_][A-Za-z0-9_]*)\"",
    re.IGNORECASE,
)
XML_HANDLER_CALL_RE = re.compile(
    r"(?<![:.])\b([A-Za-z_][A-Za-z0-9_]*)\s*\("
)


@dataclass(frozen=True)
class TocEntry:
    index: int
    path: Path
    kind: str


@dataclass(frozen=True)
class GlobalDefinition:
    name: str
    toc_index: int
    line: int
    path: Path


@dataclass(frozen=True)
class XmlHandlerReference:
    name: str
    event: str
    toc_index: int
    line: int
    path: Path


@dataclass(frozen=True)
class Issue:
    severity: str
    code: str
    addon: str
    path: Path
    line: int
    message: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def repo_relative(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def normalize_toc_path(raw_value: str) -> str:
    return raw_value.replace("\\", "/").strip()


def parse_toc_entries(toc_path: Path) -> list[TocEntry]:
    entries: list[TocEntry] = []
    for raw_line in read_text(toc_path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("##"):
            continue

        rel_path = normalize_toc_path(line.split("#", 1)[0])
        if not rel_path:
            continue

        suffix = Path(rel_path).suffix.lower()
        if suffix not in {".lua", ".xml"}:
            continue

        full_path = toc_path.parent / rel_path
        if not full_path.exists():
            continue

        entries.append(TocEntry(len(entries), full_path.resolve(), suffix[1:]))

    return entries


def strip_line_comment(line: str) -> str:
    return line.split("--", 1)[0].rstrip()


def scan_global_definitions(entry: TocEntry) -> list[GlobalDefinition]:
    definitions: list[GlobalDefinition] = []
    for line_number, raw_line in enumerate(read_text(entry.path).splitlines(), start=1):
        line = strip_line_comment(raw_line)
        if not line:
            continue

        for pattern in (
            TOP_LEVEL_GLOBAL_FUNCTION_RE,
            TOP_LEVEL_GLOBAL_ASSIGN_FUNCTION_RE,
            TOP_LEVEL_GLOBAL_TABLE_ASSIGN_FUNCTION_RE,
        ):
            match = pattern.match(line)
            if match:
                definitions.append(
                    GlobalDefinition(match.group(1), entry.index, line_number, entry.path)
                )
                break

    return definitions


def scan_forward_shadowing(addon_name: str, entry: TocEntry) -> list[Issue]:
    issues: list[Issue] = []
    forward_declarations: dict[str, int] = {}
    reported_names: set[str] = set()

    for line_number, raw_line in enumerate(read_text(entry.path).splitlines(), start=1):
        line = strip_line_comment(raw_line)
        if not line:
            continue

        match = TOP_LEVEL_FORWARD_DECL_RE.match(line)
        if match:
            forward_declarations.setdefault(match.group(1), line_number)
            continue

        for pattern, code in (
            (TOP_LEVEL_LOCAL_FUNCTION_RE, "forward-shadow-local-function"),
            (TOP_LEVEL_LOCAL_ASSIGN_FUNCTION_RE, "forward-shadow-local-assign"),
        ):
            match = pattern.match(line)
            if not match:
                continue

            name = match.group(1)
            first_line = forward_declarations.get(name)
            if first_line is None or name in reported_names:
                continue

            issues.append(
                Issue(
                    severity="error",
                    code=code,
                    addon=addon_name,
                    path=entry.path,
                    line=line_number,
                    message=(
                        f"top-level local '{name}' was forward-declared on line {first_line} "
                        f"and later redeclared here; assign to the existing local instead"
                    ),
                )
            )
            reported_names.add(name)
            break

    return issues


def scan_xml_handlers(entry: TocEntry) -> list[XmlHandlerReference]:
    references: list[XmlHandlerReference] = []
    text = read_text(entry.path)

    for block_match in XML_SCRIPT_BLOCK_RE.finditer(text):
        event_name = block_match.group(1)
        attributes = block_match.group(2) or ""
        body = block_match.group(3) or ""
        line_number = text.count("\n", 0, block_match.start()) + 1

        seen: set[str] = set()

        for handler_name in XML_FUNCTION_ATTR_RE.findall(attributes):
            if handler_name not in seen:
                references.append(
                    XmlHandlerReference(
                        name=handler_name,
                        event=event_name,
                        toc_index=entry.index,
                        line=line_number,
                        path=entry.path,
                    )
                )
                seen.add(handler_name)

        body_without_comments = re.sub(r"--.*", "", body)
        for handler_name in XML_HANDLER_CALL_RE.findall(body_without_comments):
            if handler_name not in seen:
                references.append(
                    XmlHandlerReference(
                        name=handler_name,
                        event=event_name,
                        toc_index=entry.index,
                        line=line_number,
                        path=entry.path,
                    )
                )
                seen.add(handler_name)

    return references


def looks_addon_local(handler_name: str, addon_name: str, known_definitions: set[str]) -> bool:
    normalized = addon_name.replace("-", "_")
    collapsed = normalized.replace("_", "")
    prefixes = {
        f"{normalized}_",
        f"{collapsed}_",
        f"{addon_name.replace('-', '')}_",
        "DarkChaos_",
        "DC_",
        "DCQOS_",
    }

    for defined_name in known_definitions:
        if "_" in defined_name:
            first = defined_name.split("_", 1)[0] + "_"
            prefixes.add(first)

        if defined_name.startswith("DC_"):
            pieces = defined_name.split("_")
            if len(pieces) >= 3:
                prefixes.add("_".join(pieces[:2]) + "_")

    return any(handler_name.startswith(prefix) for prefix in prefixes)


def analyze_addon(root: Path, addon_dir: Path, toc_path: Path) -> list[Issue]:
    addon_name = addon_dir.name
    entries = parse_toc_entries(toc_path)
    issues: list[Issue] = []

    global_definitions: list[GlobalDefinition] = []
    xml_references: list[XmlHandlerReference] = []

    for entry in entries:
        if entry.kind == "lua":
            global_definitions.extend(scan_global_definitions(entry))
            issues.extend(scan_forward_shadowing(addon_name, entry))
        elif entry.kind == "xml":
            xml_references.extend(scan_xml_handlers(entry))

    definitions_by_name: dict[str, list[GlobalDefinition]] = {}
    for definition in global_definitions:
        definitions_by_name.setdefault(definition.name, []).append(definition)

    defined_names = set(definitions_by_name)

    for reference in xml_references:
        definitions = definitions_by_name.get(reference.name, [])
        earlier = [definition for definition in definitions if definition.toc_index < reference.toc_index]
        if earlier:
            continue

        later = [definition for definition in definitions if definition.toc_index > reference.toc_index]
        if later:
            first_late = min(later, key=lambda item: (item.toc_index, item.line))
            issues.append(
                Issue(
                    severity="error",
                    code="xml-handler-load-order",
                    addon=addon_name,
                    path=reference.path,
                    line=reference.line,
                    message=(
                        f"{reference.event} handler '{reference.name}' loads before its first global "
                        f"definition at {repo_relative(first_late.path, root)}:{first_late.line}"
                    ),
                )
            )
            continue

        if looks_addon_local(reference.name, addon_name, defined_names):
            issues.append(
                Issue(
                    severity="error",
                    code="xml-handler-missing-global",
                    addon=addon_name,
                    path=reference.path,
                    line=reference.line,
                    message=(
                        f"{reference.event} handler '{reference.name}' does not have a matching "
                        "top-level global definition in this addon"
                    ),
                )
            )

    return issues


def discover_root_tocs(root: Path, selected_addons: set[str]) -> list[tuple[Path, Path]]:
    discovered: list[tuple[Path, Path]] = []
    for addon_dir in sorted(child for child in root.iterdir() if child.is_dir()):
        if selected_addons and addon_dir.name.lower() not in selected_addons:
            continue

        toc_files = sorted(path for path in addon_dir.glob("*.toc") if path.is_file())
        for toc_file in toc_files:
            discovered.append((addon_dir, toc_file))

    return discovered


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check addon startup hazards beyond luac/luacheck."
    )
    parser.add_argument(
        "--root",
        default="Custom/Client addons needed",
        help="Addon root to scan (default: %(default)s)",
    )
    parser.add_argument(
        "--addon",
        action="append",
        default=[],
        help="Restrict scanning to a specific top-level addon folder. Repeat as needed.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = Path.cwd().resolve()
    addon_root = (repo_root / args.root).resolve()

    if not addon_root.exists():
        print(f"ERROR: addon root not found: {addon_root}")
        return 2

    selected_addons = {name.lower() for name in args.addon}
    toc_targets = discover_root_tocs(addon_root, selected_addons)
    if not toc_targets:
        print("No top-level addon TOCs matched the requested scope.")
        return 0

    print("=== Addon Startup Hazard Check ===")
    print(f"Root: {repo_relative(addon_root, repo_root)}")
    if selected_addons:
        print("Addons: " + ", ".join(sorted(args.addon)))
    print(f"TOCs: {len(toc_targets)}")

    issues: list[Issue] = []
    for addon_dir, toc_path in toc_targets:
        addon_issues = analyze_addon(repo_root, addon_dir, toc_path)
        issues.extend(addon_issues)
        status = "OK" if not addon_issues else f"{len(addon_issues)} issue(s)"
        print(f"[{status}] {repo_relative(toc_path, repo_root)}")

    errors = [issue for issue in issues if issue.severity == "error"]
    warnings = [issue for issue in issues if issue.severity == "warning"]

    if issues:
        print("")
        for issue in sorted(issues, key=lambda item: (item.addon.lower(), str(item.path), item.line, item.code)):
            rel_path = repo_relative(issue.path, repo_root)
            print(
                f"{issue.severity.upper()} [{issue.code}] {issue.addon} "
                f"{rel_path}:{issue.line} {issue.message}"
            )

    print("")
    print(
        "Summary: "
        f"errors={len(errors)} warnings={len(warnings)} scanned_tocs={len(toc_targets)}"
    )

    if errors:
        print("Gate: FAIL")
        return 1

    print("Gate: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())