# -*- coding: utf-8 -*-
"""
DC SQL safety ratchet.

The DC script tree builds most of its SQL with format strings rather than
PreparedStatement. Converting all ~600 call sites at once is not worth doing as
a project, so this check exists to stop the situation getting worse and to keep
the one genuinely dangerous pattern from coming back.

It enforces two rules over src/server/scripts/DC:

  DC-SQL-1  No hand-rolled SQL string escaper.
            Escaping must go through the driver (CharacterDatabase.EscapeString
            / DCAddon::Utils::EscapeSql, which delegates to it). A byte-level
            escaper written by hand is wrong under NO_BACKSLASH_ESCAPES and for
            multi-byte charsets, regardless of how careful the character list is.

  DC-SQL-2  No unescaped string interpolation into SQL.
            A '{}' placeholder inside a SQL statement must be fed by a value
            that has been escaped, or is a compile-time literal. Numeric {}
            placeholders are unaffected.

Deliberate exceptions carry a trailing "// sql-ok: <reason>" on the offending
line, which makes the exception reviewable in the diff instead of invisible.

Usage:  python apps/codestyle/codestyle-dc-sql.py
Exit:   0 clean, 1 violations found.
"""

import os
import re
import sys

DC_ROOT = os.path.join("src", "server", "scripts", "DC")

SOURCE_EXTENSIONS = (".cpp", ".h")

# Opt-out marker for a reviewed, deliberate exception.
ALLOW_MARKER = "sql-ok:"

# --- DC-SQL-1 -----------------------------------------------------------------
# A hand-rolled SQL escaper is a function body that maps a single quote onto an
# escaped replacement. Both forms below are SQL-specific; JSON and CSV escapers
# produce neither, which keeps this rule narrow.
_BACKSLASH = chr(92)
_QUOTE = chr(34)
_APOSTROPHE = chr(39)

# The C++ literal  "\\'"  -> backslash-escaped single quote
SQL_ESCAPED_QUOTE_TOKEN = _QUOTE + _BACKSLASH + _BACKSLASH + _APOSTROPHE + _QUOTE
# The C++ literal  "''"   -> SQL-standard single-quote doubling
SQL_DOUBLED_QUOTE_TOKEN = _QUOTE + _APOSTROPHE + _APOSTROPHE + _QUOTE

ESCAPER_NAME_RE = re.compile(
    r"\b(?:std::string|auto)\s+\w*(?:[Ee]scape|ESCAPE)\w*\s*\(", re.UNICODE)

# --- DC-SQL-2 -----------------------------------------------------------------
# Statement-ish string literal: contains SQL and a quoted placeholder.
SQL_KEYWORD_RE = re.compile(
    r"\b(SELECT|INSERT|UPDATE|DELETE|REPLACE)\b", re.IGNORECASE)

# A '{}' placeholder (quoted -> a string is going in there).
QUOTED_PLACEHOLDER_RE = re.compile(r"'\{\}'")

DB_CALL_RE = re.compile(
    r"\b(?:CharacterDatabase|WorldDatabase|LoginDatabase)\s*\.\s*"
    r"(?:Execute|Query|PExecute|PQuery|AsyncQuery)\s*\(")

# The dominant idiom in this tree escapes in place on its own line, before the
# statement is built:
#
#     std::string name = itemTemplate->Name1;
#     WorldDatabase.EscapeString(name);
#     WorldDatabase.Execute("... '{}' ...", name);
#
# so a name-by-name look at the call arguments alone reports these as unescaped.
# Collect every variable escaped anywhere in the file and treat it as safe.
ESCAPED_INPLACE_RE = re.compile(
    r"(?:CharacterDatabase|WorldDatabase|LoginDatabase)\s*\.\s*EscapeString\s*\(\s*"
    r"([A-Za-z_]\w*)\s*\)")

ESCAPED_ASSIGN_RE = re.compile(
    r"\b([A-Za-z_]\w*)\s*=\s*[^;]*(?:Escape|Sanitiz)[^;]*;")

# Values built entirely from string literals (enum -> text mappers) cannot carry
# a quote. Catch the common "const char* x = \"LITERAL\"" / switch-assignment form.
LITERAL_CHAR_PTR_RE = re.compile(
    r"\bchar\s+const\s*\*\s*([A-Za-z_]\w*)\s*=|"
    r"\bconst\s+char\s*\*\s*([A-Za-z_]\w*)\s*=")

# Arguments that are safe as-is: escaped values, literals, numbers, enum-ish
# constants, and anything already sanitised.
#
# The "safe*" prefix and "*Esc"/"*Escaped" suffix are the established naming
# convention in this tree for a value that has already been through
# EscapeString; honour it rather than fighting it.
SAFE_ARG_RE = re.compile(
    r"(?:"
    r"[Ee]scape|[Ss]anitiz|"          # went through an escaper
    r"\bsafe[A-Z]\w*|"                 # safeNote, safePlayerName, ...
    r"\w+Esc\b|\w+Escaped\b|"          # victimNameEsc, ...
    r'^\s*"|'                          # string literal
    r"^\s*'|"                          # char literal
    r"^\s*\d|"                         # numeric literal
    r"^\s*[A-Z0-9_]+\s*$|"             # ALL_CAPS constant
    r"std::to_string|"                 # numeric conversion
    r"\bTABLE_|\bCOLUMN_|\bSTATS_|\bREQUEST_TYPE_"   # internal table/column names
    r")")

# Ternaries that yield numbers cannot carry a quote, however string-ish the
# condition variable is named ("versionCompatible ? 1 : 0").
NUMERIC_TERNARY_RE = re.compile(r"\?\s*\d+\s*:\s*\d+\s*$")


def strip_comments_and_strings(code):
    """Blank out comments; keep string contents (we need to read the SQL)."""
    out = []
    i, n = 0, len(code)
    while i < n:
        c = code[i]
        if c == "/" and i + 1 < n and code[i + 1] == "/":
            while i < n and code[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and code[i + 1] == "*":
            i += 2
            while i + 1 < n and not (code[i] == "*" and code[i + 1] == "/"):
                if code[i] == "\n":
                    out.append("\n")
                i += 1
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def iter_sources(root):
    for base, _dirs, files in os.walk(root):
        for name in files:
            if name.endswith(SOURCE_EXTENSIONS):
                yield os.path.join(base, name)


def call_argument_text(text, open_paren_index):
    """Return the argument list of a call whose '(' is at open_paren_index."""
    depth = 0
    i = open_paren_index
    n = len(text)
    while i < n:
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren_index + 1:i]
        i += 1
    return text[open_paren_index + 1:min(n, open_paren_index + 2000)]


def function_body(lines, start_index):
    """Brace-matched body of the function whose signature starts at start_index.

    Scoped precisely rather than by a fixed line window: a window bleeds into
    neighbouring functions, which both hides real hits (a sibling that mentions
    EscapeString looks like delegation) and invents false ones.
    """
    depth = 0
    started = False
    body = []
    for line in lines[start_index:start_index + 200]:
        body.append(line)
        depth += line.count("{") - line.count("}")
        if "{" in line:
            started = True
        if started and depth <= 0:
            break
    return "\n".join(body)


def check_handrolled_escaper(path, lines, failures):
    """DC-SQL-1: flag escaper-shaped functions that build escapes by hand."""
    for index, line in enumerate(lines):
        if ALLOW_MARKER in line:
            continue
        if not ESCAPER_NAME_RE.search(line):
            continue

        body = function_body(lines, index)

        if "EscapeString" in body or "Utils::EscapeSql" in body:
            continue  # delegates to the driver - this is the approved shape

        # An escaped single quote, or single-quote doubling, is specific to SQL
        # escaping. JSON and CSV escapers produce neither, so this does not fire
        # on the tree's JSON helpers.
        #
        # Built from character codes rather than written as a regex: the target
        # is a C++ string literal full of backslashes, and stacking Python
        # escaping on regex escaping on C++ escaping is how a check ends up
        # silently matching nothing.
        sql_escape_shaped = (
            SQL_ESCAPED_QUOTE_TOKEN in body
            or SQL_DOUBLED_QUOTE_TOKEN in body
        )

        if sql_escape_shaped:
            failures.append(
                (path, index + 1,
                 "DC-SQL-1", "hand-rolled SQL escaper; delegate to "
                 "CharacterDatabase.EscapeString (see DCAddon::Utils::EscapeSql)"))


# Tokens that suggest a value carries free text rather than a number.
STRING_TOKENS = {
    "name", "text", "message", "msg", "note", "title", "comment", "str",
    "string", "label", "reason", "json", "payload", "module", "transport",
    "fingerprint", "category", "desc", "description", "preview",
}

TOKEN_SPLIT_RE = re.compile(r"[^A-Za-z]+")
CAMEL_SPLIT_RE = re.compile(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])")


def looks_like_string_value(expression):
    """True if any identifier token in the expression suggests free text."""
    for chunk in TOKEN_SPLIT_RE.split(expression):
        for token in CAMEL_SPLIT_RE.findall(chunk):
            if token.lower() in STRING_TOKENS:
                return True
    return False


def collect_known_safe_names(text):
    """Variables the file demonstrably escapes, or builds from literals only."""
    safe = set()
    for match in ESCAPED_INPLACE_RE.finditer(text):
        safe.add(match.group(1))
    for match in ESCAPED_ASSIGN_RE.finditer(text):
        safe.add(match.group(1))
    for match in LITERAL_CHAR_PTR_RE.finditer(text):
        safe.add(match.group(1) or match.group(2))
    return safe


def check_unescaped_interpolation(path, text, failures, known_safe, raw_lines):
    """DC-SQL-2: flag '{}' fed by a value that was never escaped."""
    for match in DB_CALL_RE.finditer(text):
        open_paren = match.end() - 1
        args = call_argument_text(text, open_paren)

        if not SQL_KEYWORD_RE.search(args):
            continue

        placeholders = len(QUOTED_PLACEHOLDER_RE.findall(args))
        if placeholders == 0:
            continue

        line_no = text.count("\n", 0, match.start()) + 1

        # The opt-out marker lives in a // comment, which the analysis text has
        # had stripped - look for it in the original source, anywhere in the
        # lines this call spans.
        end_line = line_no + args.count("\n")
        span = raw_lines[line_no - 1:end_line + 1]
        if any(ALLOW_MARKER in line for line in span):
            continue

        # Split the argument list at the top level; the first argument is the
        # SQL, the rest are the values.
        depth = 0
        parts, current = [], []
        in_string = False
        escape_next = False
        for ch in args:
            if escape_next:
                current.append(ch)
                escape_next = False
                continue
            if ch == "\\":
                current.append(ch)
                escape_next = True
                continue
            if ch == '"':
                in_string = not in_string
            if not in_string:
                if ch in "([{":
                    depth += 1
                elif ch in ")]}":
                    depth -= 1
                elif ch == "," and depth == 0:
                    parts.append("".join(current))
                    current = []
                    continue
            current.append(ch)
        parts.append("".join(current))

        values = [p.strip() for p in parts[1:] if p.strip()]

        # Conservative: only complain when there are at least as many value
        # arguments as quoted placeholders and some value looks unescaped.
        suspicious = [v for v in values if not SAFE_ARG_RE.search(v)]

        # A value is only interesting if it could be a string. Filter out
        # obvious numeric expressions.
        suspicious = [
            v for v in suspicious
            if not re.match(r"^[\w:\.\->\(\)\s\*\+\-/%]*(?:Id|Count|Level|Size|"
                            r"Time|Ms|Num|Index|Guid|Entry)\s*(?:\(\))?$", v)
        ]

        suspicious = [v for v in suspicious if not NUMERIC_TERNARY_RE.search(v)]

        # Drop values the file escapes elsewhere, or builds from literals.
        suspicious = [
            v for v in suspicious
            if not any(re.search(r"\b" + re.escape(nm) + r"\b", v)
                       for nm in known_safe)
        ]

        if suspicious and placeholders > 0:
            # Only report when a suspicious value is plausibly a string source.
            # Tokenise rather than substring-match: "context.guid" contains
            # "text" and would otherwise be reported as a string.
            string_ish = [v for v in suspicious if looks_like_string_value(v)]
            if string_ish:
                failures.append(
                    (path, line_no, "DC-SQL-2",
                     "unescaped value interpolated into a quoted SQL placeholder: "
                     + ", ".join(string_ish[:3])))


def main():
    if not os.path.isdir(DC_ROOT):
        print("DC SQL check: {} not found; run from the repository root."
              .format(DC_ROOT))
        return 0

    failures = []

    for path in iter_sources(DC_ROOT):
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as handle:
                raw = handle.read()
        except OSError:
            continue

        text = strip_comments_and_strings(raw)
        lines = text.split("\n")
        raw_lines = raw.split("\n")

        known_safe = collect_known_safe_names(text)

        check_handrolled_escaper(path, lines, failures)
        check_unescaped_interpolation(path, text, failures, known_safe, raw_lines)

    if failures:
        for path, line_no, rule, message in sorted(failures):
            print("{}: {} at line {}: {}".format(rule, path, line_no, message))
        print("")
        print("DC SQL safety check : Failed ({} violation(s))".format(len(failures)))
        print("")
        print("Fix by using PreparedStatement, or by escaping the value with")
        print("CharacterDatabase.EscapeString / DCAddon::Utils::EscapeSql.")
        print("If the value is provably safe, append  // {} <reason>"
              .format(ALLOW_MARKER))
        return 1

    print("DC SQL safety check : Passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
