"""Export the SFK-Cata downported spells from `spell_dbc` into a 232-column Spell CSV,
ready for wow.export-main/tools/spell-dbc-append.py.

WHY THE VALUES COME FROM THE DATABASE, NOT FROM THE CATA CLIENT AGAIN
`_cata_spell_downport.py` sets only the ~25 fields it understands and lets MySQL supply
defaults for the rest. If this script re-derived the rows from the Cata DBC it would have
to reproduce those defaults by hand, and any drift would mean the SERVER (spell_dbc) and
the CLIENT (Spell.dbc) disagree about the same spell id -- which shows up as a spell that
works but has the wrong tooltip, or vice versa. Reading spell_dbc back guarantees they are
the same numbers.

THE 234 -> 232 MAPPING
spell_dbc has 234 columns; Spell.csv has 232. The difference is exactly the two padding
fields `unk_320_2` (ordinal 14) and `unk_320_3` (ordinal 16), which the CSV omits and
spell-dbc-append.py re-inserts as zeros. This script drops them BY NAME rather than by
position, so a future column reorder cannot silently shift every field by one.

Usage:
    python export_sfk_spells_to_spell_csv.py                     # writes sfk_spells.csv
    python export_sfk_spells_to_spell_csv.py --out other.csv
    python export_sfk_spells_to_spell_csv.py --host ... --user ... --password ... --db ...

With no connection arguments it reads ACMCP's .env (K:/Dark-Chaos/ACMCP/.env), which is
where the DB credentials for this project already live.
"""
import argparse
import csv
import io
import os
import re
import sys

# 21 spells the imported SmartAI trash casts + 4 of Ashbury's (declared as DUNGEON_MODE
# macros, so the original id sweep missed them) + Disease Cloud, the addon-layer visual.
#
# 57718 "Harpoon Loot Sparkles" is deliberately NOT here: it is already present in the
# fork's Spell.dbc under the same name from an earlier downport, and spell-dbc-append.py
# REPLACES matching ids in place -- re-adding it would rewrite a good row for no reason.
SPELL_IDS = [
    # SmartAI casts (01d)
    91064, 91077, 91088, 91099, 91213, 91220, 91291, 91324, 91325, 91348, 91419,
    91522, 91554, 91563, 91622, 91623, 91624, 91629, 91668, 91678, 95300,
    # Baron Ashbury signature abilities (01c)
    93468, 93705, 93581, 93712,
    # creature_addon visual (01b)
    88198,
]

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SPELL_CSV_HEADER = os.path.join(REPO, 'Custom', 'CSV DBC', 'Spell.csv')
ACMCP_ENV = r'K:/Dark-Chaos/ACMCP/.env'

# Present in spell_dbc, absent from Spell.csv. spell-dbc-append.py re-inserts them as 0.
PADDING_COLUMNS = ('unk_320_2', 'unk_320_3')


def load_env(path):
    """Parse KEY=VALUE lines out of an .env without importing anything."""
    out = {}
    if not os.path.exists(path):
        return out
    with io.open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def connect(a):
    import pymysql
    if a.host:
        host, user, pw, db, port = a.host, a.user, a.password, a.db, a.port
    else:
        env = load_env(ACMCP_ENV)
        if not env:
            sys.exit('could not read %s -- pass --host/--user/--password/--db instead' % ACMCP_ENV)

        def pick(*names, **kw):
            for n in names:
                for key in env:
                    if key.upper() == n:
                        return env[key]
            return kw.get('default')

        host = pick('MYSQL_HOST', 'DB_HOST', 'ACORE_DB_HOST', default='127.0.0.1')
        port = int(pick('MYSQL_PORT', 'DB_PORT', 'ACORE_DB_PORT', default='3306'))
        user = pick('MYSQL_USER', 'DB_USER', 'ACORE_DB_USER', default='root')
        pw = pick('MYSQL_PASSWORD', 'MYSQL_PASS', 'DB_PASSWORD', 'ACORE_DB_PASSWORD', default='')
        db = pick('MYSQL_WORLD_DB', 'WORLD_DB', 'ACORE_WORLD_DB', default='acore_world')
    print('connecting to %s@%s:%s/%s' % (user, host, port, db))
    return pymysql.connect(host=host, port=port, user=user, password=pw,
                           database=db, charset='utf8mb4')


def read_header():
    with io.open(SPELL_CSV_HEADER, encoding='utf-8-sig', newline='') as fh:
        return next(csv.reader(fh))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                  'sfk_spells.csv'))
    ap.add_argument('--host'); ap.add_argument('--user'); ap.add_argument('--password')
    ap.add_argument('--db', default='acore_world'); ap.add_argument('--port', type=int, default=3306)
    a = ap.parse_args()

    header = read_header()
    if len(header) != 232:
        sys.exit('Spell.csv header is %d columns, expected 232' % len(header))

    conn = connect(a)
    cur = conn.cursor()

    cur.execute("SELECT COLUMN_NAME FROM information_schema.COLUMNS "
                "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'spell_dbc' "
                "ORDER BY ORDINAL_POSITION")
    db_cols = [r[0] for r in cur.fetchall()]

    # Sanity: the CSV header must be exactly spell_dbc minus the two padding columns.
    expected = [c for c in db_cols if c not in PADDING_COLUMNS]
    if expected != header:
        for i, (e, h) in enumerate(zip(expected, header)):
            if e != h:
                sys.exit('column %d disagrees: spell_dbc says %r, Spell.csv says %r\n'
                         'The 234->232 mapping has changed; do not write a CSV from this.'
                         % (i, e, h))
        sys.exit('spell_dbc (minus padding) has %d columns, Spell.csv has %d'
                 % (len(expected), len(header)))

    sel = ', '.join('`%s`' % c for c in header)
    ids = ', '.join(str(i) for i in SPELL_IDS)
    cur.execute('SELECT %s FROM `spell_dbc` WHERE `ID` IN (%s) ORDER BY `ID`' % (sel, ids))
    rows = cur.fetchall()

    found = {r[0] for r in rows}
    missing = [i for i in SPELL_IDS if i not in found]
    if missing:
        sys.exit('these ids are not in spell_dbc -- run 01b/01c/01d first: %s'
                 % ','.join(map(str, missing)))

    with io.open(a.out, 'w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        for r in rows:
            w.writerow(['' if v is None else v for v in r])

    print('wrote %d spells x %d columns -> %s' % (len(rows), len(header), a.out))
    print()
    print('Next (from K:/Dark-Chaos/wow.export-main/tools):')
    print('  python spell-dbc-append.py \\')
    print('    --dbc "%s/Custom/DBCs/Spell.dbc" \\' % REPO.replace('\\', '/'))
    print('    --csv "%s" \\' % a.out.replace('\\', '/'))
    print('    --out "%s/Custom/DBCs/Spell.dbc"' % REPO.replace('\\', '/'))
    print('  python mpq_stormlib_patch.py --mpq "K:/WoW_3.3.5a_ 255 Fun/Data/patch-4.MPQ" \\')
    print('    --set "%s/Custom/DBCs/Spell.dbc=DBFilesClient\\Spell.dbc"' % REPO.replace('\\', '/'))
    print('  node sync-dbc-deploy.js --files Spell.dbc')
    print()
    print('Spell.dbc is the 234-field fork layout -- NEVER run csv2wdbc.py on it.')


if __name__ == '__main__':
    main()
