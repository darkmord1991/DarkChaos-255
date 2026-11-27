#!/usr/bin/env python3
"""deploy_endgame_gear_dbc.py - land 329_'s generated endgame gear in Item.dbc.

329_ writes 288 rows into `item_template` (411000-411143 at ilvl 412,
411500-411643 at ilvl 450). Those rows are DEAD until Item.dbc knows the ids:
ObjectMgr::LoadItemTemplates discards any item_template row with no Item.dbc
entry, and only at LOG_DEBUG, so nothing appears in Errors.log. The symptom is
"the SQL applied but .additem fails".

This script does the whole chain and refuses to continue if any step looks wrong:

    export rows -> sanity-check -> back up -> append (CRLF) -> compile
                -> deploy to patch MPQs -> sync candidate dirs -> verify

USAGE
    # A) let it read the rows from the DB (needs pymysql + credentials)
    python deploy_endgame_gear_dbc.py --host H --user U --password P [--db acore_world]

    # B) or hand it the rows exported from your own SQL client
    #    (run the SELECT in 329_'s trailer, save the output, pass it here)
    python deploy_endgame_gear_dbc.py --rows exported_rows.txt

    # dry run - does everything except writing
    python deploy_endgame_gear_dbc.py ... --dry-run

WHY THE ROWS COME FROM item_template AND ARE NEVER HAND-WRITTEN
    enforceDBCAttributes FORCES class/subclass/Material/displayid/InventoryType/
    sheath onto the item from the DBC. If the CSV disagrees with item_template
    the DBC silently wins and the item is subtly wrong -- wrong model, wrong
    slot, wrong armour type. Deriving the CSV from the inserted rows is the only
    way the two cannot drift.
"""
import sys
import argparse
import hashlib
# Windows consoles default to cp1252 and blow up on non-ASCII in the final
# banner -- which once made a fully successful deploy look like a crash.
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass
import os
import shutil
import subprocess

MASTER = r'K:\Dark-Chaos\DarkChaos-255-Master'
TOOLS = r'K:\Dark-Chaos\wow.export-main\tools'
CSV_PATH = os.path.join(MASTER, r'Custom\CSV DBC\Item.csv')
DBC_OUT = os.path.join(MASTER, r'Custom\DBCs\Item.dbc')
CLIENT_MPQS = [
    r'K:\WoW_3.3.5a_ 255 Fun\Data\patch-4.MPQ',
    r'K:\WoW_3.3.5a_ 255 Fun\Data\enGB\patch-enGB-3.MPQ',
]

# Default: 329_'s two entry blocks. Overridable with --blocks/--expected so this
# verified pipeline serves later batches (337_'s 420000-420429) instead of being
# copy-pasted into a second script that then drifts from this one.
BLOCKS = [(411000, 411143), (411500, 411643)]
EXPECTED = 288

EXPORT_SQL = """
SELECT entry, class, subclass, Material, displayid, InventoryType, sheath
FROM item_template
WHERE (entry BETWEEN 411000 AND 411199) OR (entry BETWEEN 411500 AND 411699)
ORDER BY entry
"""


def die(msg):
    print('FATAL: ' + msg, file=sys.stderr)
    sys.exit(1)


def rows_from_db(host, user, password, db, port):
    try:
        import pymysql
    except ImportError:
        die('pymysql not installed - use --rows instead')
    conn = pymysql.connect(host=host, user=user, password=password, database=db, port=port)
    try:
        with conn.cursor() as cur:
            cur.execute(EXPORT_SQL)
            return [tuple(int(v) for v in r) for r in cur.fetchall()]
    finally:
        conn.close()


def rows_from_file(path):
    """Accept either the 7 bare columns or the pre-quoted CSV line."""
    out = []
    for raw in open(path, encoding='utf-8'):
        line = raw.strip().strip(',')
        if not line or line.lower().startswith('entry'):
            continue
        parts = [p.strip().strip('"').strip("'") for p in line.split(',')]
        parts = [p for p in parts if p != '']
        if len(parts) == 8:          # already CSV form, drop the -1 sentinel
            parts = parts[:3] + parts[4:]
        if len(parts) != 7:
            die('cannot parse row (want 7 columns, got %d): %s' % (len(parts), raw.rstrip()))
        try:
            out.append(tuple(int(p) for p in parts))
        except ValueError:
            die('non-numeric value in row: %s' % raw.rstrip())
    return out


def check(rows):
    if not rows:
        die('no rows - was 329_ applied? Item.dbc cannot be built from nothing.')
    ids = [r[0] for r in rows]
    if len(ids) != len(set(ids)):
        die('duplicate entry ids in the export')
    for i in ids:
        if not any(lo <= i <= hi for lo, hi in BLOCKS):
            die('entry %d is outside 329_\'s blocks - refusing to touch Item.csv' % i)
    if len(rows) != EXPECTED:
        print('WARNING: got %d rows, expected %d. Continuing, but check 329_ applied cleanly.'
              % (len(rows), EXPECTED))
    for r in rows:
        if r[4] == 0:
            die('entry %d has displayid 0 - it would be invisible; fix 329_ first' % r[0])
    print('  rows look sane: %d, ids %d..%d, no duplicates, every displayid set'
          % (len(rows), min(ids), max(ids)))
    return ids


def existing_ids(path):
    seen = set()
    with open(path, 'r', encoding='utf-8', newline='') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('"ID"'):
                continue
            try:
                seen.add(int(line.split(',')[0].strip('"')))
            except (ValueError, IndexError):
                continue
    return seen


def run(cmd, cwd=None):
    print('  $ ' + ' '.join(cmd))
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if res.stdout.strip():
        print('    ' + res.stdout.strip().replace('\n', '\n    '))
    if res.returncode != 0:
        print('    ' + (res.stderr or '').strip().replace('\n', '\n    '), file=sys.stderr)
        die('command failed with exit %d' % res.returncode)
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--rows')
    ap.add_argument('--host'); ap.add_argument('--user'); ap.add_argument('--password')
    ap.add_argument('--db', default='acore_world'); ap.add_argument('--port', type=int, default=3306)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--blocks', help='entry ranges, e.g. "420000-420429" or "a-b,c-d"')
    ap.add_argument('--expected', type=int, help='expected row count')
    a = ap.parse_args()

    global BLOCKS, EXPECTED
    if a.blocks:
        BLOCKS = [tuple(int(v) for v in part.split('-')) for part in a.blocks.split(',')]
        print('  blocks overridden: %s' % (BLOCKS,))
    if a.expected:
        EXPECTED = a.expected

    print('1. collecting rows')
    if a.rows:
        rows = rows_from_file(a.rows)
    elif a.host and a.user:
        rows = rows_from_db(a.host, a.user, a.password or '', a.db, a.port)
    else:
        die('need --rows FILE or --host/--user/--password')
    ids = check(rows)

    print('2. checking Item.csv')
    have = existing_ids(CSV_PATH)
    dupes = sorted(set(ids) & have)
    if dupes:
        # Re-running is fine, but appending twice would corrupt the record count.
        die('%d of these ids are ALREADY in Item.csv (e.g. %s).\n'
            '       Remove them first, or the DBC record count drifts.'
            % (len(dupes), dupes[:5]))
    print('  none of the %d ids are present yet' % len(ids))

    if a.dry_run:
        print('\nDRY RUN - stopping before any write.')
        print('Would append %d rows, compile Item.dbc, and deploy to:' % len(rows))
        for m in CLIENT_MPQS:
            print('   ' + m)
        return

    print('3. backing up')
    for p in (CSV_PATH, DBC_OUT):
        bak = p + ('.pre-%d.bak' % BLOCKS[0][0])
        if not os.path.exists(bak):
            shutil.copy2(p, bak)
            print('  ' + bak)
        else:
            print('  (backup already exists, kept) ' + bak)

    print('4. appending to Item.csv')
    # 🔴 CRLF. Item.csv is CRLF throughout; appending LF makes the compiler's
    # row count drift silently (documented trap, cost a debugging round before).
    with open(CSV_PATH, 'a', encoding='utf-8', newline='') as fh:
        for (eid, cls, sub, mat, disp, inv, sheath) in rows:
            fh.write('"%d","%d","%d","-1","%d","%d","%d","%d"\r\n'
                     % (eid, cls, sub, mat, disp, inv, sheath))
    print('  appended %d rows' % len(rows))

    print('5. compiling Item.dbc')
    run([sys.executable, 'dbc-compile.py', '--only', 'Item'], cwd=TOOLS)

    print('6. deploying to the client archives')
    for mpq in CLIENT_MPQS:
        if not os.path.exists(mpq):
            print('  SKIP (missing): ' + mpq)
            continue
        run([sys.executable, 'mpq_stormlib_patch.py', '--mpq', mpq,
             '--set', DBC_OUT + r'=DBFilesClient\Item.dbc'], cwd=TOOLS)

    print('7. syncing the candidate DBC dirs')
    # WarcraftXLHost reads some DBCs straight off disk from one of three sibling
    # checkouts, and which one is ambiguous. Skipping this is how a change can be
    # fully compiled and deployed and still never appear in game.
    run(['node', 'sync-dbc-deploy.js', '--files', 'Item.dbc'], cwd=TOOLS)

    print('8. verifying')
    run([sys.executable, 'dbc-compile.py', '--verify', '--only', 'Item'], cwd=TOOLS)
    print('  Item.dbc md5: ' + hashlib.md5(open(DBC_OUT, 'rb').read()).hexdigest())

    print("""
DONE on the client side.

*** THE SERVER STILL NEEDS IT. *** The worldserver runs on a Linux box you deploy to
   manually -- `K:\\Dark-Chaos\\Server\\data\\dbc` is NOT the server's dbc dir.
   Copy the freshly built file to the server's dbc directory:

       Custom/DBCs/Item.dbc   ->  <server>/data/dbc/Item.dbc

   then restart the worldserver. Until that lands, all %d items stay invisible
   to the server no matter what the client has.

   Verify in game:  .additem {first}
   🔴 Do NOT verify with the `item_dbc` table -- it is NOT a mirror of Item.dbc
   (13,603 rows, max ID 284,846, and it does not contain these ranges). An
   in-game .additem is the only real check.

   Then bump the client cache id, or players keep the stale tooltip.
""".format(first=BLOCKS[0][0]) % len(rows))


if __name__ == '__main__':
    main()
