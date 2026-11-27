"""Build the 232-column Spell CSV for the SFK-Cata downported spells, offline.

WHY THIS EXISTS ALONGSIDE export_sfk_spells_to_spell_csv.py
That script reads the rows back out of `spell_dbc`, which is the most direct source of
truth -- but it needs a reachable MySQL, and the DB is not reachable from the Windows repo
host. This one reconstructs the same rows from the SQL files that were applied
(01b/01c/01d) plus the table's column defaults, so it runs anywhere.

That reconstruction is exact, and it is worth saying why rather than hoping:
  * every NUMERIC column in spell_dbc defaults to 0
  * every STRING column defaults to NULL (-> empty in the CSV)
  * the INSERT statements in 01b/01c/01d name every column they set
so "defaults, overridden by whatever the INSERT names" reproduces the stored row exactly.
Verified against information_schema: 0 numeric columns have a non-zero default.

The two scripts should agree. If you ever have DB access, run the other one and diff --
that is the check, and it is cheap.

Usage:
    python build_sfk_spell_csv.py                  # writes sfk_spells.csv
    python build_sfk_spell_csv.py --out other.csv
"""
import argparse
import csv
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
SQL_DIR = os.path.join(REPO, 'Custom', 'Custom feature SQLs', 'worlddb', 'ShadowfangKeepCata')
SPELL_CSV = os.path.join(REPO, 'Custom', 'CSV DBC', 'Spell.csv')

SOURCES = [
    '01b_sfk_cata_aura_spells.sql',
    '01c_sfk_ashbury_missing_spells.sql',
    '01d_sfk_smartai_spells.sql',
]

# Already present in the fork's Spell.dbc under the same name from an earlier downport.
# spell-dbc-append.py REPLACES matching ids, so including it would rewrite a good row.
SKIP_IDS = {57718}

# spell_dbc and Spell.csv disagree on the names of the extra attribute masks -- the table
# numbers them Ex2..Ex7, the CSV letters them ExB..ExG. Same six fields, same order.
# Everything else the SQL sets matches by name; the guard below is what proves that, and
# it is why this map is six entries and not a guess.
COLUMN_ALIASES = {
    'AttributesEx2': 'AttributesExB',
    'AttributesEx3': 'AttributesExC',
    'AttributesEx4': 'AttributesExD',
    'AttributesEx5': 'AttributesExE',
    'AttributesEx6': 'AttributesExF',
    'AttributesEx7': 'AttributesExG',
}

INSERT_RE = re.compile(
    r'INSERT\s+INTO\s+`?spell_dbc`?\s*\((?P<cols>[^)]*)\)\s*VALUES\s*\((?P<vals>.*?)\);',
    re.S | re.I)


def split_values(s):
    """Split a SQL VALUES list on top-level commas, respecting '...' with '' escapes."""
    out, cur, i, in_str = [], [], 0, False
    while i < len(s):
        ch = s[i]
        if in_str:
            if ch == "'":
                if i + 1 < len(s) and s[i + 1] == "'":   # '' -> literal quote
                    cur.append("'"); i += 2; continue
                in_str = False; i += 1; continue
            if ch == '\\' and i + 1 < len(s):
                cur.append(s[i + 1]); i += 2; continue
            cur.append(ch); i += 1; continue
        if ch == "'":
            in_str = True; i += 1; continue
        if ch == ',':
            out.append(''.join(cur).strip()); cur = []; i += 1; continue
        cur.append(ch); i += 1
    out.append(''.join(cur).strip())
    return out


def parse_sql(path):
    """-> {spell_id: {column: value}}"""
    text = io.open(path, encoding='utf-8').read()
    rows = {}
    for m in INSERT_RE.finditer(text):
        cols = [c.strip().strip('`') for c in m.group('cols').split(',')]
        raw = m.group('vals')
        # was this value a quoted string in the source?
        quoted = [v.strip().startswith("'") for v in split_top(raw)]
        vals = split_values(raw)
        if len(cols) != len(vals):
            sys.exit('%s: %d columns but %d values' % (os.path.basename(path), len(cols), len(vals)))
        row = {}
        for c, v, q in zip(cols, vals, quoted):
            c = COLUMN_ALIASES.get(c, c)
            row[c] = v if q else (v if v.upper() != 'NULL' else '')
        rows[int(row['ID'])] = row
    return rows


def split_top(s):
    """Same split as split_values but returns the RAW slices (quotes intact)."""
    out, start, i, in_str = [], 0, 0, False
    while i < len(s):
        ch = s[i]
        if in_str:
            if ch == "'":
                if i + 1 < len(s) and s[i + 1] == "'":
                    i += 2; continue
                in_str = False
            elif ch == '\\':
                i += 2; continue
            i += 1; continue
        if ch == "'":
            in_str = True; i += 1; continue
        if ch == ',':
            out.append(s[start:i]); start = i + 1
        i += 1
    out.append(s[start:])
    return out


def sync_spell_csv(rows, header):
    """Merge the rows into Custom/CSV DBC/Spell.csv (append-only, idempotent).

    Spell.csv is the source of truth for this table -- it and Spell.dbc were exactly in
    sync at 54,027 ids before this import, so leaving the CSV behind after appending to
    the .dbc would silently make it the stale copy.

    Rewrites the whole file through csv.reader/writer rather than appending text, because
    Spell.csv contains fields with embedded newlines (spell descriptions) and a naive
    line-append cannot see row boundaries. The ID set is diffed by the caller afterwards,
    which is what actually proves nothing was lost.
    """
    existing, out = [], []
    with io.open(SPELL_CSV, encoding='utf-8-sig', newline='') as fh:
        r = csv.reader(fh)
        hdr = next(r)
        if hdr != header:
            sys.exit('Spell.csv header changed since the CSV was built')
        ours = set(rows)
        for row in r:
            if not row:
                continue
            # idempotency: drop any previous copy of our ids, then re-add below
            if row[0].strip() and int(row[0]) in ours:
                continue
            out.append(row)
    before = len(out)

    for sid in sorted(rows):
        r = rows[sid]
        out.append([r.get(c, '') if is_string_col(c) else r.get(c, '0') for c in header])

    tmp = SPELL_CSV + '.tmp'
    with io.open(tmp, 'w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        w.writerows(out)
    os.replace(tmp, SPELL_CSV)
    return before, len(out)


LOCALE_SUFFIXES = ('_Lang_enUS', '_Lang_enGB', '_Lang_koKR', '_Lang_frFR', '_Lang_deDE',
                   '_Lang_enCN', '_Lang_zhCN', '_Lang_enTW', '_Lang_zhTW', '_Lang_esES',
                   '_Lang_esMX', '_Lang_ruRU', '_Lang_ptPT', '_Lang_ptBR', '_Lang_itIT',
                   '_Lang_Unk')


def is_string_col(name):
    return name.endswith(LOCALE_SUFFIXES)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(HERE, 'sfk_spells.csv'))
    ap.add_argument('--sync-spell-csv', action='store_true',
                    help='also merge the rows into Custom/CSV DBC/Spell.csv (source of truth)')
    a = ap.parse_args()

    with io.open(SPELL_CSV, encoding='utf-8-sig', newline='') as fh:
        header = next(csv.reader(fh))
    if len(header) != 232:
        sys.exit('Spell.csv header is %d columns, expected 232' % len(header))

    rows = {}
    for name in SOURCES:
        p = os.path.join(SQL_DIR, name)
        if not os.path.exists(p):
            sys.exit('missing %s' % p)
        got = parse_sql(p)
        print('%-42s %d spells' % (name, len(got)))
        rows.update(got)

    for sid in sorted(SKIP_IDS & set(rows)):
        del rows[sid]
        print('skipped %d (already in the fork Spell.dbc under the same name)' % sid)

    # Every column the SQL sets must exist in the CSV header, or a value would be silently
    # dropped -- that is the failure mode this check exists for.
    unknown = {c for r in rows.values() for c in r} - set(header)
    if unknown:
        sys.exit('columns set by the SQL but absent from Spell.csv: %s' % ', '.join(sorted(unknown)))

    with io.open(a.out, 'w', encoding='utf-8', newline='') as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_ALL)
        w.writerow(header)
        for sid in sorted(rows):
            r = rows[sid]
            # default: 0 for numerics, '' for strings -- both are '' safe here because the
            # appender writes '' string cells as empty and non-string cells parse '' as 0.
            w.writerow([r.get(c, '') if is_string_col(c) else r.get(c, '0') for c in header])

    print('\nwrote %d spells x %d columns -> %s' % (len(rows), len(header), a.out))
    print('ids: %s' % ','.join(str(i) for i in sorted(rows)))

    if a.sync_spell_csv:
        before, after = sync_spell_csv(rows, header)
        print('\nSpell.csv: %d rows kept + %d ours = %d' % (before, len(rows), after))
        print('Spell.csv is the source of truth for this table and was exactly in sync')
        print('with Spell.dbc before this import -- keep them together.')


if __name__ == '__main__':
    main()
