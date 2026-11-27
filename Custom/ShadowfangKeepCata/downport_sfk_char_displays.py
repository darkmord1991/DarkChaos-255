"""Downport the 32 CHARACTER-BASED Shadowfang Keep displays (the bosses and named adds).

These are the ones `downport_sfk_displays.py` deliberately skipped: a Human / Scourge /
Worgen body plus gear, driven by a CreatureDisplayInfoExtra row and a baked composite
body texture.

WHAT MAKES THEM WORK
The body texture is the `BakeName` .blp -- a pre-composited skin+armour sheet. All 31 were
extracted from the Cataclysm client's art.MPQ and deployed to patch-7.MPQ (the archive
dc_mpq_layout routes Textures\\BakedNpcTextures to). With the bake present the NPC renders
correctly even if the individual gear pieces do not resolve, which is the whole point of
baking and is why this is tractable at all.

WHAT WILL STILL BE MISSING
`NPCItemDisplay_1..11` point at ItemDisplayInfo ids, and many are Cataclysm-only. Those
slots are 3D attachments -- weapons, shoulders, helms, capes. A missing id there costs the
attachment, not the NPC: the body is already in the bake. Slots that do not resolve are
reported by this script and ZEROED rather than left dangling, so the client is never asked
for an id that is not there.

LAYOUT
Cata CreatureDisplayInfoExtra is 21 fields and so is this fork's CSV -- a straight 1:1, no
field to drop (unlike CreatureDisplayInfo, which needed 17 -> 16). Verified at runtime
against rows present in both clients before anything is written.

Usage:
    python downport_sfk_char_displays.py            # dry run + verification
    python downport_sfk_char_displays.py --apply
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

CATA_CDI   = r'K:\tmp\cata-dbc\CreatureDisplayInfo.dbc'
CATA_EXTRA = r'K:\tmp\cata-dbc\CreatureDisplayInfoExtra.dbc'
CDI_CSV    = os.path.join(REPO, 'Custom', 'CSV DBC', 'CreatureDisplayInfo.csv')
EXTRA_CSV  = os.path.join(REPO, 'Custom', 'CSV DBC', 'CreatureDisplayInfoExtra.csv')
IDI_CSV    = os.path.join(REPO, 'Custom', 'CSV DBC', 'ItemDisplayInfo.csv')

CHAR_DISPLAYS = [30054, 30056, 30057, 33986, 33987, 33988, 33989, 34162, 34610, 34611,
                 34612, 34713, 34714, 34728, 35574, 35868, 36374, 37287, 37288, 37289,
                 37290, 37291, 37292, 37294, 37296, 37297, 37298, 37299, 37300, 37358,
                 37373, 37374]

CDI_DROP_FIELD = 10          # Cata's PortraitCreatureDisplayInfoID; see the other script
CDI_STRINGS = {6, 7, 8, 9}
EXTRA_STRINGS_LAST = True    # BakeName is the final field


def load_csv(path):
    with io.open(path, encoding='utf-8-sig', newline='') as fh:
        r = csv.reader(fh)
        header = next(r)
        rows = [row for row in r if row and row[0].strip()]
    return header, rows


def write_csv(path, header, rows):
    tmp = path + '.tmp'
    with io.open(tmp, 'w', encoding='utf-8-sig', newline='') as fh:
        w = csv.writer(fh, lineterminator='\n')
        w.writerow(header)
        w.writerows(rows)
    os.replace(tmp, path)


def cdi_row(dbc, idx):
    r, rf = dbc.row(idx), dbc.row_f(idx)
    out = []
    for i in range(dbc.fields):
        if i == CDI_DROP_FIELD:
            continue
        if i in CDI_STRINGS:
            out.append(dbc.text(r[i]))
        elif i == 4:
            out.append('%g' % round(rf[i], 6))
        else:
            out.append(str(r[i]))
    return out


def extra_row(dbc, idx):
    r = dbc.row(idx)
    out = [str(r[i]) for i in range(dbc.fields - 1)]
    out.append(dbc.text(r[dbc.fields - 1]))          # BakeName
    return out


def verify_extra_layout(dbc, our_rows):
    """Prove the Extra layout against rows in both clients (race/sex/skin/face)."""
    ours = {int(r[0]): r for r in our_rows}
    idx = {dbc.row(i)[0]: i for i in range(dbc.records)}
    shared = [i for i in sorted(ours) if i in idx][:400]
    if len(shared) < 50:
        sys.exit('only %d shared Extra rows - cannot verify layout' % len(shared))
    agree = disagree = 0
    for e in shared:
        got, want = extra_row(dbc, idx[e]), ours[e]
        if got[1:8] == want[1:8]:                    # race..facialhair
            agree += 1
        else:
            disagree += 1
    pct = 100.0 * agree / (agree + disagree)
    print('Extra layout check over %d shared rows: %d agree, %d disagree (%.1f%%)'
          % (agree + disagree, agree, disagree, pct))
    if pct < 90.0:
        sys.exit('Extra layout agreement too low - refusing to write')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true')
    a = ap.parse_args()

    cdi, ex = Dbc(CATA_CDI), Dbc(CATA_EXTRA)
    cdi_hdr, cdi_rows = load_csv(CDI_CSV)
    ex_hdr, ex_rows = load_csv(EXTRA_CSV)
    print('Cata CDI %d x %d | Extra %d x %d' % (cdi.records, cdi.fields, ex.records, ex.fields))
    print('our CDI %d x %d | Extra %d x %d' % (len(cdi_rows), len(cdi_hdr),
                                               len(ex_rows), len(ex_hdr)))
    if len(ex_hdr) != ex.fields:
        sys.exit('Extra column count mismatch: ours %d, cata %d' % (len(ex_hdr), ex.fields))
    print()
    verify_extra_layout(ex, ex_rows)

    # Which ItemDisplayInfo ids does this client actually have?
    have_idi = set()
    with io.open(IDI_CSV, encoding='utf-8-sig', newline='') as fh:
        r = csv.reader(fh); next(r)
        for row in r:
            if row and row[0].strip():
                have_idi.add(int(row[0]))
    print('our ItemDisplayInfo ids: %d' % len(have_idi))

    di = {cdi.row(i)[0]: i for i in range(cdi.records)}
    xi = {ex.row(i)[0]: i for i in range(ex.records)}
    have_extra = {int(r[0]) for r in ex_rows}

    new_cdi, new_extra = [], []
    dropped_slots = kept_slots = 0
    for d in CHAR_DISPLAYS:
        row = cdi_row(cdi, di[d])
        e = int(row[cdi_hdr.index('ExtendedDisplayInfoID')])
        new_cdi.append(row)
        if e in have_extra or any(int(x[0]) == e for x in new_extra):
            continue
        er = extra_row(ex, xi[e])
        # zero unresolvable gear slots (columns 8..18 = NPCItemDisplay_1..11)
        for c in range(8, 19):
            v = int(er[c])
            if v and v not in have_idi:
                er[c] = '0'
                dropped_slots += 1
            elif v:
                kept_slots += 1
        new_extra.append(er)

    print()
    print('CreatureDisplayInfo rows to add: %d' % len(new_cdi))
    print('CreatureDisplayInfoExtra rows to add: %d' % len(new_extra))
    print('gear slots: %d resolve, %d zeroed (Cata-only item displays)'
          % (kept_slots, dropped_slots))
    print('  -> the body comes from the bake, so a zeroed slot costs an attachment,')
    print('     not the NPC. All 31 bakes are already deployed to patch-7.MPQ.')

    if not a.apply:
        print('\nDRY RUN -- nothing written. Re-run with --apply.')
        return

    add_ids = {int(r[0]) for r in new_cdi}
    write_csv(CDI_CSV, cdi_hdr,
              [r for r in cdi_rows if int(r[0]) not in add_ids] + new_cdi)
    ex_ids = {int(r[0]) for r in new_extra}
    write_csv(EXTRA_CSV, ex_hdr,
              [r for r in ex_rows if int(r[0]) not in ex_ids] + new_extra)
    print('\nwritten. Recompile CreatureDisplayInfo.dbc + CreatureDisplayInfoExtra.dbc,')
    print('push to patch-4.MPQ and run sync-dbc-deploy.js.')


if __name__ == '__main__':
    main()
