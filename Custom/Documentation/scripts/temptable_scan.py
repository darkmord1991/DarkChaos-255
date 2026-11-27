#!/usr/bin/env python3
"""Find statements that reference the same TEMPORARY table more than once.

MySQL cannot reopen a temporary table inside a single statement (error 1137), so any
statement naming one twice fails at apply time even though the SQL is otherwise valid.
"""
import re, glob, os, collections

ROOT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs"
FILES = sorted(glob.glob(os.path.join(ROOT, "**", "*.sql"), recursive=True))

bad = 0
for path in FILES:
    src = open(path, encoding="utf-8", errors="replace").read()
    # temp tables created in this file
    temps = set(re.findall(r"CREATE TEMPORARY TABLE (?:IF NOT EXISTS )?(\w+)", src, re.I))
    if not temps:
        continue
    # strip comments, then split into statements on ';'
    nocomment = "\n".join(l for l in src.splitlines() if not l.strip().startswith("--"))
    for stmt in nocomment.split(";"):
        s = stmt.strip()
        if not s:
            continue
        # DROP/CREATE of the temp table itself is exempt
        if re.match(r"^(DROP|CREATE|ALTER)\s", s, re.I):
            continue
        for t in temps:
            n = len(re.findall(r"\b" + re.escape(t) + r"\b", s))
            if n > 1:
                head = " ".join(s.split())[:90]
                print(f"{os.path.relpath(path, ROOT)}\n    {t} x{n}  ->  {head}...")
                bad += 1

print(f"\n{len(FILES)} files scanned; {bad} offending statement(s)")
