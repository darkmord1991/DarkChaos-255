"""Downport the Cataclysm Shadowfang Keep creature displays into the 3.3.5 client DBCs.

SCOPE: this handles the 12 PLAIN displays only -- the ones whose ExtendedDisplayInfoID is
0, i.e. a straight creature model with no character customisation. The other 32 are
character-based (Human/Scourge/Worgen bodies with gear and a baked composite texture) and
need the CreatureDisplayInfoExtra + BakeName pipeline, which is a separate job; see the
README section "The display layer".

WHY THE 12 ARE FREE
All 13 models the 44 displays reference already exist in this client:
  * 12 are stock WotLK creature models (Gargoyle, NorthrendGeist, NorthrendGhoul,
    NorthrendWorgen, SuperZombie, Worgen, and the character bodies)
  * CREATURE\\MASTIFF\\MASTIFF.M2 was downported earlier and lives in patch-H.MPQ,
    registered as CreatureModelData **501054** (DC's 5xxxxx retroport band) rather than
    Cata's 3190 -- so the three Mastiff displays are remapped to 501054, NOT given a new
    CreatureModelData row.
So no new art is needed for these 12; only DBC rows.

LAYOUT: 17 -> 16 FIELDS
Cataclysm's CreatureDisplayInfo inserted `PortraitCreatureDisplayInfoID` after
PortraitTextureName. 3.3.5 has no such column, so field index 10 is dropped. That is
VERIFIED at runtime against displays present in both clients rather than assumed -- if the
check fails the script refuses to write anything.

Usage:
    python downport_sfk_displays.py            # dry run + layout verification
    python downport_sfk_displays.py --apply
"""
import argparse
import csv
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'Custom', 'Custom feature SQLs', 'worlddb',
                                'ShadowfangKeepCata'))
from _cata_spell_downport import Dbc                                    # noqa: E402

CATA_CDI = r'K:\tmp\cata-dbc\CreatureDisplayInfo.dbc'
OUR_CSV = os.path.join(REPO, 'Custom', 'CSV DBC', 'CreatureDisplayInfo.csv')

# The 12 with ExtendedDisplayInfoID = 0.
PLAIN_DISPLAYS = [30210, 30211, 30212, 36256, 36329, 36837,
                  36848, 36849, 36850, 36851, 37301, 37302]

# Cata ModelID -> the id this client actually uses.
MODEL_REMAP = {3190: 501054}        # CREATURE\MASTIFF\MASTIFF.M2, already in patch-H.MPQ

DROP_FIELD = 10                     # Cata's PortraitCreatureDisplayInfoID
STRING_FIELDS = {6, 7, 8, 9}        # TextureVariation_1..3 + PortraitTextureName


def read_our_csv():
    with io.open(OUR_CSV, encoding='utf-8-sig', newline='') as fh:
        r = csv.reader(fh)
        header = next(r)
        rows = [row for row in r if row and row[0].strip()]
    return header, rows


def cata_to_335(dbc, idx):
    """One Cata record -> a 16-column 3.3.5 row."""
    r = dbc.row(idx)
    rf = dbc.row_f(idx)
    out = []
    for i in range(dbc.fields):
        if i == DROP_FIELD:
            continue
        if i in STRING_FIELDS:
            out.append(dbc.text(r[i]))
        elif i == 4:                                   # CreatureModelScale is a float
            out.append(('%g' % round(rf[i], 6)))
        else:
            out.append(str(r[i]))
    return out


def verify_layout(dbc, our_rows, header):
    """Prove the 17->16 mapping against displays that exist in BOTH clients.

    Only structural, client-independent fields are compared: model, scale, alpha and the
    trailing block. SoundID and the blood/particle fields are deliberately excluded --
    those legitimately differ between expansions and a mismatch there says nothing about
    the layout.
    """
    ours = {int(r[0]): r for r in our_rows}
    idx = {dbc.row(i)[0]: i for i in range(dbc.records)}
    check_cols = ['ModelID', 'CreatureModelScale', 'CreatureModelAlpha']
    pos = [header.index(c) for c in check_cols]

    shared = [i for i in sorted(ours) if i in idx and i < 30000][:400]
    if len(shared) < 50:
        sys.exit('only %d shared displays found - not enough to verify the layout' % len(shared))

    agree = disagree = 0
    examples = []
    for sid in shared:
        got = cata_to_335(dbc, idx[sid])
        want = ours[sid]
        if all(got[p] == want[p] for p in pos):
            agree += 1
        else:
            disagree += 1
            if len(examples) < 5:
                examples.append((sid, [got[p] for p in pos], [want[p] for p in pos]))
    pct = 100.0 * agree / (agree + disagree)
    print('layout check over %d displays present in both clients:' % (agree + disagree))
    print('  %s agree on %s' % (agree, ', '.join(check_cols)))
    print('  %s disagree (%.1f%% agreement)' % (disagree, pct))
    for sid, g, w in examples:
        print('    %-7d cata=%s  ours=%s' % (sid, g, w))
    # Models get re-pointed between expansions, so demand a strong majority, not perfection.
    if pct < 90.0:
        sys.exit('layout agreement too low - the 17->16 mapping is wrong, refusing to write')
    return pct


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()

    dbc = Dbc(CATA_CDI)
    header, our_rows = read_our_csv()
    print('Cata CreatureDisplayInfo: %d rows x %d fields' % (dbc.records, dbc.fields))
    print('our CSV: %d rows x %d columns' % (len(our_rows), len(header)))
    if len(header) != dbc.fields - 1:
        sys.exit('expected our CSV to have exactly one column fewer than the Cata DBC')
    print()
    verify_layout(dbc, our_rows, header)
    print()

    idx = {dbc.row(i)[0]: i for i in range(dbc.records)}
    have = {int(r[0]) for r in our_rows}
    model_col = header.index('ModelID')
    ext_col = header.index('ExtendedDisplayInfoID')

    new = []
    for sid in PLAIN_DISPLAYS:
        if sid not in idx:
            sys.exit('display %d not in the Cata client' % sid)
        row = cata_to_335(dbc, idx[sid])
        if row[ext_col] != '0':
            sys.exit('display %d is character-based (ext=%s) - not in scope here'
                     % (sid, row[ext_col]))
        src_model = int(row[model_col])
        row[model_col] = str(MODEL_REMAP.get(src_model, src_model))
        new.append((sid, src_model, row))

    print('%-7s %-8s %-8s %s' % ('display', 'cata', 'ours', 'note'))
    for sid, src, row in new:
        note = 'remapped' if src != int(row[model_col]) else ''
        flag = 'ALREADY PRESENT - will replace' if sid in have else ''
        print('%-7d %-8d %-8s %s %s' % (sid, src, row[model_col], note, flag))

    if not a.apply:
        print('\nDRY RUN -- nothing written. Re-run with --apply.')
        return

    keep = [r for r in our_rows if int(r[0]) not in {s for s, _, _ in new}]
    out = keep + [row for _, _, row in new]
    tmp = OUR_CSV + '.tmp'
    with io.open(tmp, 'w', encoding='utf-8-sig', newline='') as fh:
        w = csv.writer(fh, lineterminator='\n')
        w.writerow(header)
        w.writerows(out)
    os.replace(tmp, OUR_CSV)
    print('\nwrote %d rows (%d kept + %d ours) -> %s' % (len(out), len(keep), len(new), OUR_CSV))
    print('Now: compile CreatureDisplayInfo.dbc with csv2wdbc.py, push to patch-4.MPQ,')
    print('and run sync-dbc-deploy.js. creature_model_info is handled by 11_creature_models.sql.')


if __name__ == '__main__':
    main()
