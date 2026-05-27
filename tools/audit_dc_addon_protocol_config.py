from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE_ROOT = REPO_ROOT / "src" / "server" / "scripts" / "DC"
DEFAULT_CONFIG_PATH = (
    REPO_ROOT / "Custom" / "Config files" / "darkchaos-custom.conf.dist"
)
SOURCE_SUFFIXES = {".cpp", ".h"}
KEY_LITERAL_RE = re.compile(r'"(DC\.AddonProtocol\.[A-Za-z0-9_.]+)"')
CONFIG_KEY_RE = re.compile(r"^\s*(DC\.AddonProtocol\.[A-Za-z0-9_.]+)\s*=")


def repo_relative(path: Path) -> str:
    try:
        return path.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Audit DC.AddonProtocol.* config coverage against the live C++ "
            "sources under src/server/scripts/DC."
        )
    )
    parser.add_argument(
        "--source-root",
        type=Path,
        default=DEFAULT_SOURCE_ROOT,
        help="Root directory to scan for DC.AddonProtocol.* string literals.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG_PATH,
        help="Config file to compare against.",
    )
    parser.add_argument(
        "--show-sources",
        action="store_true",
        help="Include per-key source file mappings in the JSON report.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with code 1 when missing or unknown keys are found.",
    )
    return parser.parse_args()


def iter_source_files(source_root: Path) -> list[Path]:
    if source_root.is_file():
        return [source_root]

    if not source_root.is_dir():
        raise FileNotFoundError(f"Source root not found: {source_root}")

    return sorted(
        path
        for path in source_root.rglob("*")
        if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES
    )


def extract_expected_keys(source_files: list[Path]) -> dict[str, list[str]]:
    key_sources: dict[str, list[str]] = defaultdict(list)

    for source_file in source_files:
        text = source_file.read_text(encoding="utf-8", errors="ignore")
        matches = sorted(set(KEY_LITERAL_RE.findall(text)))
        if not matches:
            continue

        relative_path = repo_relative(source_file)
        for key in matches:
            key_sources[key].append(relative_path)

    return dict(sorted(key_sources.items()))


def extract_config_keys(config_path: Path) -> dict[str, int]:
    if not config_path.is_file():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    config_keys: dict[str, int] = {}
    for line_number, line in enumerate(
        config_path.read_text(encoding="utf-8", errors="ignore").splitlines(),
        start=1,
    ):
        match = CONFIG_KEY_RE.match(line)
        if match:
            config_keys[match.group(1)] = line_number

    return dict(sorted(config_keys.items()))


def build_findings(missing_keys: list[str], unknown_keys: list[str]) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []

    if missing_keys:
        findings.append(
            {
                "severity": "error",
                "code": "missing_config_keys",
                "message": (
                    f"{len(missing_keys)} expected DC.AddonProtocol.* keys are "
                    "missing from the config file."
                ),
            }
        )

    if unknown_keys:
        findings.append(
            {
                "severity": "warning",
                "code": "unknown_config_keys",
                "message": (
                    f"{len(unknown_keys)} unknown DC.AddonProtocol.* keys were "
                    "found in the config file."
                ),
            }
        )

    return findings


def main() -> int:
    args = parse_args()
    source_root = args.source_root.resolve()
    config_path = args.config.resolve()

    source_files = iter_source_files(source_root)
    expected_key_sources = extract_expected_keys(source_files)
    config_keys = extract_config_keys(config_path)

    expected_keys = sorted(expected_key_sources)
    config_key_names = sorted(config_keys)
    missing_keys = sorted(set(expected_keys) - set(config_key_names))
    unknown_keys = sorted(set(config_key_names) - set(expected_keys))
    findings = build_findings(missing_keys, unknown_keys)

    report: dict[str, object] = {
        "sourceRootPath": repo_relative(source_root),
        "configFilePath": repo_relative(config_path),
        "sourceFileCount": len(source_files),
        "sourceFilesWithKeys": sorted(
            {
                source_path
                for source_paths in expected_key_sources.values()
                for source_path in source_paths
            }
        ),
        "expectedKeyCount": len(expected_keys),
        "configKeyCount": len(config_key_names),
        "missingKeys": missing_keys,
        "unknownKeys": unknown_keys,
        "findings": findings,
    }

    if args.show_sources:
        report["expectedKeySources"] = expected_key_sources
        report["configKeyLines"] = config_keys

    json.dump(report, sys.stdout, indent=2, sort_keys=False)
    sys.stdout.write("\n")

    if args.strict and findings:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())