"""
Fix Custom Spell Attributes in Spell.csv

This script removes the SPELL_ATTR0_PASSIVE (0x40) flag from custom spells
so that buff icons will appear in the player's buff bar.

The PASSIVE flag tells the client this is a passive ability (like talents)
which should NOT show in the buff bar. Our custom buffs need to be visible.
"""

import csv
import os

# Configuration
CSV_PATH = 'CSV DBC/Spell.csv'
OUTPUT_PATH = 'CSV DBC/Spell_fixed.csv'

# Spell ranges to fix
FIXES = [
    # (spell_id_start, spell_id_end, new_attributes, new_aura1 or None to keep)
    (800001, 800001, 65552, None),     # Hotspot buff: remove PASSIVE
    (800002, 800019, 16, None),        # Prestige stat buffs: remove PASSIVE  
    (800040, 800044, 65536, 4),        # Prestige XP buffs: remove PASSIVE + set aura type
]

SPELL_ATTR0_PASSIVE = 0x40

def main():
    print("Reading Spell.csv...")
    
    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        rows = list(reader)
    
    header = rows[0]
    data_rows = rows[1:]
    
    # Find column indices
    id_col = header.index('ID')
    attr_col = header.index('Attributes')
    aura1_col = header.index('EffectAura_1')
    
    print(f"Found columns: ID={id_col}, Attributes={attr_col}, EffectAura_1={aura1_col}")
    
    fixes_applied = 0
    
    for i, row in enumerate(data_rows):
        try:
            spell_id = int(row[id_col])
            current_attr = int(row[attr_col])
            
            for start_id, end_id, new_attr, new_aura in FIXES:
                if start_id <= spell_id <= end_id:
                    old_attr = current_attr
                    old_aura = row[aura1_col]
                    
                    # Apply attribute fix
                    row[attr_col] = str(new_attr)
                    
                    # Apply aura fix if specified
                    if new_aura is not None:
                        row[aura1_col] = str(new_aura)
                    
                    print(f"  Spell {spell_id}: Attributes {old_attr} -> {new_attr}", end="")
                    if new_aura is not None:
                        print(f", EffectAura_1 {old_aura} -> {new_aura}", end="")
                    print()
                    
                    fixes_applied += 1
                    break
                    
        except (ValueError, IndexError):
            continue
    
    print(f"\nApplied {fixes_applied} fixes")
    
    # Write output
    print(f"Writing {OUTPUT_PATH}...")
    with open(OUTPUT_PATH, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(data_rows)
    
    print("Done!")
    print()
    print("NEXT STEPS:")
    print("1. Review the changes in Spell_fixed.csv")
    print("2. Rename Spell.csv to Spell_backup.csv")
    print("3. Rename Spell_fixed.csv to Spell.csv")  
    print("4. Regenerate Spell.dbc from the CSV")
    print("5. Copy new Spell.dbc to client Data folder")
    print("6. Restart server and client")

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir('Custom')
    main()
