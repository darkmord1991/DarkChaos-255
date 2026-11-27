#!/usr/bin/env python3
"""
Snapshot the spell power coefficients the core uses, for gen_class_ranks.py.

The core takes a spell's coefficient from `spell_bonus_data` (looked up by the spell's own id, then by its first
rank's) and falls back to Spell.dbc's EffectBonusMultiplier. gen_class_ranks.py needs those numbers offline to size
new ranks so that a rank's whole hit -- base points plus the spell power or attack power part -- grows by one
factor. This writes the stock rows (ids below 900000; the generated ranks carry copies) and the stock rank chains to
spell_coefficients.json next to this script. Read-only: SELECT statements only.

Credentials come from WorldDatabaseInfo in the worldserver.conf given (default: the Windows server's).

Usage:
    python tools/balance/dump_spell_coefficients.py [--conf K:/Dark-Chaos/Server/configs/worldserver.conf]
"""

import argparse
import json
import re
from pathlib import Path

import pymysql

OUT = Path(__file__).resolve().parent / "spell_coefficients.json"
STOCK_LIMIT = 900000


def world_credentials(conf_path):
    text = Path(conf_path).read_text(encoding="utf-8", errors="replace")
    match = re.search(r'^\s*WorldDatabaseInfo\s*=\s*"([^"]*)"', text, re.MULTILINE)
    if not match:
        raise SystemExit("WorldDatabaseInfo not found in %s" % conf_path)
    host, port, user, password, database = match.group(1).split(";")
    return dict(host=host, port=int(port), user=user, password=password, database=database)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--conf", default="K:/Dark-Chaos/Server/configs/worldserver.conf")
    args = parser.parse_args()

    connection = pymysql.connect(**world_credentials(args.conf), connect_timeout=10, read_timeout=60)
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT `entry`, `direct_bonus`, `dot_bonus`, `ap_bonus`, `ap_dot_bonus` "
                           "FROM `spell_bonus_data` WHERE `entry` < %s ORDER BY `entry`", (STOCK_LIMIT,))
            bonus = {str(entry): [float(direct), float(dot), float(ap), float(ap_dot)]
                     for entry, direct, dot, ap, ap_dot in cursor.fetchall()}
            cursor.execute("SELECT `spell_id`, `first_spell_id` FROM `spell_ranks` WHERE `spell_id` < %s "
                           "ORDER BY `spell_id`", (STOCK_LIMIT,))
            first_rank = {str(spell): int(first) for spell, first in cursor.fetchall()}
    finally:
        connection.close()

    data = {
        "source": "acore_world spell_bonus_data and spell_ranks, ids below %d" % STOCK_LIMIT,
        "bonus_columns": ["direct_bonus", "dot_bonus", "ap_bonus", "ap_dot_bonus"],
        "bonus": bonus,
        "first_rank": first_rank,
    }
    OUT.write_text(json.dumps(data, indent=0, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print("%d coefficient rows, %d rank links -> %s" % (len(bonus), len(first_rank), OUT))


if __name__ == "__main__":
    main()
