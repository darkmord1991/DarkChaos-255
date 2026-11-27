"""Downport Cataclysm 4.3.4 spells into this fork's 3.3.5 `spell_dbc` overlay.

Column layout for the 4.3.4 Spell.dbc / SpellEffect.dbc was calibrated empirically
in an earlier pass (see the cata-spell-downport memory); this script re-verifies it
against known spells before emitting anything.

Usage:
    python _cata_spell_downport.py --verify
    python _cata_spell_downport.py --ids 93505,93527,... --out 01_spells.sql
"""
import argparse
import struct
import sys

# ---------------------------------------------------------------------------
# DBC reading
# ---------------------------------------------------------------------------


class Dbc:
    def __init__(self, path):
        raw = open(path, 'rb').read()
        magic, self.records, self.fields, self.recsize, self.stringsize = \
            struct.unpack_from('<4sIIII', raw, 0)
        if magic != b'WDBC':
            raise SystemExit('%s is not a WDBC file' % path)
        self.data = raw[20:20 + self.records * self.recsize]
        self.strings = raw[20 + self.records * self.recsize:]

    def row(self, i):
        off = i * self.recsize
        return struct.unpack_from('<%dI' % self.fields, self.data, off)

    def row_f(self, i):
        off = i * self.recsize
        return struct.unpack_from('<%df' % self.fields, self.data, off)

    def text(self, offset):
        if offset == 0 or offset >= len(self.strings):
            return ''
        end = self.strings.find(b'\0', offset)
        return self.strings[offset:end].decode('utf-8', 'replace')

    def index_by_col(self, col):
        idx = {}
        for i in range(self.records):
            idx.setdefault(self.row(i)[col], []).append(i)
        return idx


# ---------------------------------------------------------------------------
# Calibrated 4.3.4 column positions
# ---------------------------------------------------------------------------

SPELL = {
    'Attributes': 1, 'AttributesEx': 2, 'AttributesEx2': 3, 'AttributesEx3': 4,
    'AttributesEx4': 5, 'AttributesEx5': 6, 'AttributesEx6': 7, 'AttributesEx7': 8,
    'CastingTimeIndex': 12, 'DurationIndex': 13, 'PowerType': 14,
    'RangeIndex': 15, 'Speed': 16, 'SpellVisualID_1': 17, 'SpellVisualID_2': 18,
    'SpellIconID': 19, 'ActiveIconID': 20, 'Name_Lang_enUS': 21,
    'Description_Lang_enUS': 23, 'SchoolMask': 25,
}
FLOAT_COLS = {'Speed'}

EFFECT = {
    'SpellID': 24, 'EffectIndex': 25,
    'Effect': 1, 'EffectAura': 3, 'EffectAuraPeriod': 4, 'EffectBasePoints': 5,
    'EffectMiscValue': 12, 'EffectMiscValueB': 13, 'EffectRadiusIndex': 15,
    'EffectTriggerSpell': 21, 'ImplicitTargetA': 22, 'ImplicitTargetB': 23,
}


def esc(s):
    return s.replace('\\', '\\\\').replace("'", "''")


def build(spell_path, effect_path):
    return Dbc(spell_path), Dbc(effect_path)


def verify(sp):
    """Round-trip check against spells that exist in BOTH 4.3.4 and 3.3.5.

    Expected values are the REAL 3.3.5 ones, read out of Custom/CSV DBC/Spell.csv --
    do not write them from memory. 46598 is the useful disambiguator: DurationIndex
    21 and RangeIndex 152 are distinctive, where CastingTimeIndex and SchoolMask are
    both 1 on every one of these and prove nothing on their own.
    """
    # SpellIconID anchors: 368 / 207 / 173 are distinctive and each matches ONLY
    # column 19 across all 48, which is what actually pins that column. Do not use
    # 46598 for the icon -- its icon genuinely changed between 3.3.5 (332) and
    # 4.3.4 (3766), and 332 appears in no Cata column at all. Values that are 1
    # (37752, 52225) match four columns and prove nothing on their own.
    expect = {
        7038:  {'SpellIconID': 368},
        7054:  {'SpellIconID': 207},
        23224: {'SpellIconID': 173},
        46598: {'DurationIndex': 21, 'RangeIndex': 152,
                'SchoolMask': 1, 'CastingTimeIndex': 1,
                'Name_Lang_enUS': 'Ride Vehicle Hardcoded'},
        52225: {'DurationIndex': 0, 'RangeIndex': 1, 'SpellIconID': 1,
                'SchoolMask': 1, 'Name_Lang_enUS': 'Cosmetic - Infected Wounds'},
        37752: {'DurationIndex': 0, 'RangeIndex': 1, 'SpellIconID': 1,
                'CastingTimeIndex': 1, 'Name_Lang_enUS': 'Stand'},
    }
    idx = sp.index_by_col(0)
    ok = True
    for sid, fields in expect.items():
        if sid not in idx:
            print('  %-7d NOT IN CATA CLIENT' % sid)
            ok = False
            continue
        r = sp.row(idx[sid][0])
        for k, want in fields.items():
            got = sp.text(r[SPELL[k]]) if k.endswith('_Lang_enUS') else r[SPELL[k]]
            flag = 'ok' if got == want else '*** MISMATCH ***'
            print('  %-7d %-22s got %-28s expect %-28s %s' % (sid, k, got, want, flag))
            ok &= (got == want)
    return ok


def emit(sp, ef, ids, out):
    sidx = sp.index_by_col(0)
    eidx = ef.index_by_col(EFFECT['SpellID'])
    rows, missing = [], []

    for sid in ids:
        if sid not in sidx:
            missing.append(sid)
            continue
        r = sp.row(sidx[sid][0])
        rf = sp.row_f(sidx[sid][0])

        col = {'ID': sid}
        for name, c in SPELL.items():
            if name.endswith('_Lang_enUS'):
                col[name] = sp.text(r[c])
            elif name in FLOAT_COLS:
                col[name] = round(rf[c], 6)
            else:
                col[name] = r[c]

        # effects
        for e in eidx.get(sid, []):
            er = ef.row(e)
            i = er[EFFECT['EffectIndex']]
            if i > 2:                     # 3.3.5 only has three effect slots
                continue
            n = i + 1
            col['Effect_%d' % n] = er[EFFECT['Effect']]
            col['EffectAura_%d' % n] = er[EFFECT['EffectAura']]
            col['EffectAuraPeriod_%d' % n] = er[EFFECT['EffectAuraPeriod']]
            # 3.3.5: value = BasePoints + rand(1..DieSides). Cata dropped DieSides,
            # so DieSides = 1 and BasePoints = cata - 1 reproduces the same amount.
            bp = struct.unpack('<i', struct.pack('<I', er[EFFECT['EffectBasePoints']]))[0]
            col['EffectBasePoints_%d' % n] = bp - 1
            col['EffectDieSides_%d' % n] = 1
            col['EffectMiscValue_%d' % n] = struct.unpack('<i', struct.pack('<I', er[EFFECT['EffectMiscValue']]))[0]
            col['EffectMiscValueB_%d' % n] = struct.unpack('<i', struct.pack('<I', er[EFFECT['EffectMiscValueB']]))[0]
            col['EffectRadiusIndex_%d' % n] = er[EFFECT['EffectRadiusIndex']]
            col['EffectTriggerSpell_%d' % n] = er[EFFECT['EffectTriggerSpell']]
            col['ImplicitTargetA_%d' % n] = er[EFFECT['ImplicitTargetA']]
            col['ImplicitTargetB_%d' % n] = er[EFFECT['ImplicitTargetB']]

        col['ProcChance'] = 101           # 3.3.5 default
        col['EquippedItemClass'] = -1     # 3.3.5 default
        rows.append(col)

    with open(out, 'w', encoding='utf-8', newline='') as fh:
        fh.write('-- Cataclysm 4.3.4 spells downported into the 3.3.5 `spell_dbc` overlay.\n')
        fh.write('-- Generated by _cata_spell_downport.py from K:/UntouchedClients/Cata\n')
        fh.write('--   Data/enUS/locale-enUS.MPQ : DBFilesClient/Spell.dbc + SpellEffect.dbc\n')
        fh.write('-- BasePoints carry the -1 / DieSides = 1 shift (Cata dropped DieSides).\n')
        fh.write('-- spell_dbc is SERVER-SIDE ONLY: the server resolves these at once, but the\n')
        fh.write('-- client shows no icon or tooltip until Spell.dbc itself is rebuilt with\n')
        fh.write('-- tools/spell-dbc-append.py and deployed.\n\n')
        fh.write('DELETE FROM `spell_dbc` WHERE `ID` IN (%s);\n\n'
                 % ','.join(str(r['ID']) for r in rows))
        for r in rows:
            cols = sorted(r)
            vals = []
            for c in cols:
                v = r[c]
                vals.append("'%s'" % esc(v) if isinstance(v, str) else str(v))
            fh.write('INSERT INTO `spell_dbc` (%s) VALUES (%s);\n'
                     % (', '.join('`%s`' % c for c in cols), ', '.join(vals)))
    return rows, missing


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--spell', required=True)
    ap.add_argument('--effect', required=True)
    ap.add_argument('--verify', action='store_true')
    ap.add_argument('--ids')
    ap.add_argument('--out')
    a = ap.parse_args()

    sp, ef = build(a.spell, a.effect)
    print('Spell.dbc   %d rows x %d fields' % (sp.records, sp.fields))
    print('SpellEffect %d rows x %d fields' % (ef.records, ef.fields))

    if a.verify:
        print('\nlayout verification:')
        sys.exit(0 if verify(sp) else 1)

    ids = [int(x) for x in a.ids.split(',') if x.strip()]
    rows, missing = emit(sp, ef, ids, a.out)
    print('\nemitted %d spells -> %s' % (len(rows), a.out))
    if missing:
        print('NOT FOUND in the Cata client: %s' % ','.join(map(str, missing)))
