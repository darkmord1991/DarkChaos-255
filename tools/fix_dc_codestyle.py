from __future__ import annotations

import pathlib
import re

DC_ROOT = pathlib.Path("src/server/scripts/DC")
EXTS = {".cpp", ".h"}

# Convert only single-reference cases; avoid touching rvalue refs (&&).
CONST_AUTO_REF_RE = re.compile(r"\bconst\s+auto\s*&(?!=&)")

# Fix common 'if(' / 'else if(' spacing, and avoid 'if ( condition' with a space right after '('.
IF_PAREN_RE = re.compile(r"\bif\s*\(")
ELSE_IF_PAREN_RE = re.compile(r"\belse\s+if\s*\(")
IF_AFTER_LPAREN_SPACES_RE = re.compile(r"\bif\s*\(\s+")
ELSE_IF_AFTER_LPAREN_SPACES_RE = re.compile(r"\belse\s+if\s*\(\s+")


def _split_line_ending(line: str) -> tuple[str, str]:
    if line.endswith("\r\n"):
        return line[:-2], "\r\n"
    if line.endswith("\n"):
        return line[:-1], "\n"
    if line.endswith("\r"):
        return line[:-1], "\r"
    return line, ""


def _detect_default_eol(text: str) -> str:
    # Preserve the first newline sequence observed; fallback to '\n'.
    idx = text.find("\n")
    if idx == -1:
        return "\n"
    if idx > 0 and text[idx - 1] == "\r":
        return "\r\n"
    return "\n"


def fix_file(path: pathlib.Path) -> bool:
    original = path.read_text(encoding="utf-8", newline="")
    default_eol = _detect_default_eol(original)

    lines = original.splitlines(keepends=True)
    fixed_lines: list[str] = []

    for line in lines:
        body, eol = _split_line_ending(line)

        # Replace leading tabs with 4 spaces (codestyle only flags leading tabs).
        if body.startswith("\t"):
            tab_prefix_len = len(body) - len(body.lstrip("\t"))
            body = ("    " * tab_prefix_len) + body[tab_prefix_len:]

        # Trim trailing spaces/tabs.
        body = body.rstrip(" \t")

        # Enforce 'auto const&' instead of 'const auto&'.
        body = CONST_AUTO_REF_RE.sub("auto const&", body)

        # Normalize basic if/else-if parenthesis spacing.
        body = ELSE_IF_PAREN_RE.sub("else if (", body)
        body = IF_PAREN_RE.sub("if (", body)
        body = ELSE_IF_AFTER_LPAREN_SPACES_RE.sub("else if (", body)
        body = IF_AFTER_LPAREN_SPACES_RE.sub("if (", body)

        fixed_lines.append(body + eol)

    # Collapse consecutive blank lines (codestyle forbids more than 1 in a row).
    collapsed: list[str] = []
    prev_blank = False
    for line in fixed_lines:
        body, _eol = _split_line_ending(line)
        is_blank = body.strip() == ""
        if is_blank and prev_blank:
            continue
        collapsed.append(line)
        prev_blank = is_blank

    fixed_lines = collapsed

    # Remove blank lines at EOF (codestyle treats even a single final blank line as failure).
    while fixed_lines:
        last_body, _last_eol = _split_line_ending(fixed_lines[-1])
        if last_body.strip() == "":
            fixed_lines.pop()
            continue
        break

    # Ensure file ends with exactly one newline.
    if fixed_lines:
        last_body, last_eol = _split_line_ending(fixed_lines[-1])
        if last_eol == "":
            fixed_lines[-1] = last_body + default_eol
        else:
            # Normalize to one newline (avoid files ending with '\r' only).
            fixed_lines[-1] = last_body + default_eol

    fixed = "".join(fixed_lines)

    if fixed != original:
        path.write_text(fixed, encoding="utf-8", newline="")
        return True

    return False


def main() -> int:
    if not DC_ROOT.exists():
        raise SystemExit(f"DC root not found: {DC_ROOT}")

    changed = 0
    scanned = 0

    for path in DC_ROOT.rglob("*"):
        if path.is_file() and path.suffix in EXTS:
            scanned += 1
            if fix_file(path):
                changed += 1

    print(f"Scanned {scanned} files under {DC_ROOT}")
    print(f"Updated {changed} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
