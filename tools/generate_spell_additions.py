import csv
from pathlib import Path

spell_csv = Path('Custom/CSV DBC/Spell.csv')
out_csv = Path('Custom/CSV DBC/Spell.collection_additions.csv')

# IDs and base points for tiers
tiers = [ (300510, 1), (300511, 2), (300512, 3), (300513, 5) ]

with open(spell_csv, newline='', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    header_len = len(header)
    # find template row for Mount Speed (ID 13587)
    template = None
    for row in reader:
        if row[0] == '13587':
            template = row
            break

if template is None:
    raise SystemExit('Template spell 13587 not found in Spell.csv')

# find needed field indices
id_idx = header.index('ID')
eff_base_1 = header.index('EffectBasePoints_1')
eff_base_2 = header.index('EffectBasePoints_2')
aura_eff_1 = header.index('EffectAura_1')
name_idx = header.index('Name_Lang_enUS')
desc_idx = header.index('Description_Lang_enUS')
aura_desc_idx = header.index('AuraDescription_Lang_enUS')
spellIcon_idx = header.index('SpellIconID')

new_rows = []
for spell_id, base in tiers:
    row = template.copy()
    row[id_idx] = str(spell_id)
    # set both effect base points if present (some templates use two)
    row[eff_base_1] = str(base)
    row[eff_base_2] = str(base)
    # Ensure Aura (EffectAura_1) is 130 (mounted speed not stacking)
    row[aura_eff_1] = '130'
    # Set Icon
    row[spellIcon_idx] = '2035'
    # Set names and descriptions
    row[name_idx] = f"Collector's Speed {'I' if base==1 else 'II' if base==2 else 'III' if base==3 else 'IV'}"
    row[desc_idx] = f"Your mount collection grants +{base}% mount speed."
    row[aura_desc_idx] = f"Mount speed increased by {base}%."
    new_rows.append(row)

# write out
with open(out_csv, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f, quoting=csv.QUOTE_ALL)
    for r in new_rows:
        if len(r) != header_len:
            raise SystemExit(f'Generated row length mismatch: {len(r)} vs header {header_len}')
        writer.writerow(r)

print('Wrote', out_csv)
