#!/usr/bin/env python3
"""
Generate SpellItemEnchantment.csv entries for Heirloom Stat Packages.

Formula: Enchant ID = 900000 + (package_id * 100) + level
Total: 12 packages * 15 levels = 180 enchantments
"""

import csv

# Stat type IDs for WoW 3.3.5a
STAT_TYPES = {
    "Critical Strike": 32,
    "Haste": 36,
    "Hit": 31,
    "Expertise": 37,
    "Armor Penetration": 44,
    "Spell Power": 45,
    "Dodge": 13,
    "Parry": 14,
    "Block": 15,
    "Defense": 12,
    "Stamina": 7,
    "Resilience": 35,
}

# Package definitions: (name, stat1, stat2, stat3, weight1, weight2, weight3)
# Weights: 0.5 = two stats, 0.333 = three stats
PACKAGES = {
    1: ("Fury", "Critical Strike", "Haste", None, 0.5, 0.5, 0),
    2: ("Precision", "Hit", "Expertise", None, 0.5, 0.5, 0),
    3: ("Devastation", "Critical Strike", "Armor Penetration", None, 0.5, 0.5, 0),
    4: ("Swiftblade", "Haste", "Armor Penetration", None, 0.5, 0.5, 0),
    5: ("Spellfire", "Critical Strike", "Haste", "Spell Power", 0.333, 0.333, 0.333),
    6: ("Arcane", "Hit", "Haste", "Spell Power", 0.333, 0.333, 0.333),
    7: ("Bulwark", "Dodge", "Parry", "Block", 0.333, 0.333, 0.333),
    8: ("Fortress", "Defense", "Block", "Stamina", 0.333, 0.333, 0.333),
    9: ("Survivor", "Dodge", "Stamina", None, 0.5, 0.5, 0),
    10: ("Gladiator", "Resilience", "Critical Strike", None, 0.5, 0.5, 0),
    11: ("Warlord", "Resilience", "Stamina", None, 0.5, 0.5, 0),
    12: ("Balanced", "Critical Strike", "Hit", "Haste", 0.333, 0.333, 0.333),
}

# Base stat values per level (total budget per level)
# Level 1 = 6, scales up to Level 15 = 168
LEVEL_VALUES = {
    1: 6, 2: 14, 3: 22, 4: 32, 5: 43,
    6: 55, 7: 67, 8: 80, 9: 95, 10: 110,
    11: 126, 12: 142, 13: 157, 14: 168, 15: 168,
}

ENCHANT_BASE_ID = 900000


def generate_enchantment_row(pkg_id, level):
    """Generate a single enchantment row."""
    pkg_name, stat1_name, stat2_name, stat3_name, w1, w2, w3 = PACKAGES[pkg_id]
    base_value = LEVEL_VALUES[level]
    
    # Calculate stat values
    stat1_value = round(base_value * w1)
    stat2_value = round(base_value * w2)
    stat3_value = round(base_value * w3) if stat3_name else 0
    
    # Get stat type IDs
    stat1_type = STAT_TYPES.get(stat1_name, 0)
    stat2_type = STAT_TYPES.get(stat2_name, 0)
    stat3_type = STAT_TYPES.get(stat3_name, 0) if stat3_name else 0
    
    # Calculate enchant ID
    enchant_id = ENCHANT_BASE_ID + (pkg_id * 100) + level
    
    # Build display name
    display_name = f"{pkg_name} {level}/15"
    
    # Effect type 5 = ITEM_ENCHANTMENT_TYPE_STAT (stat bonus)
    effect1 = 5 if stat1_type else 0
    effect2 = 5 if stat2_type else 0
    effect3 = 5 if stat3_type else 0
    
    # Build CSV row
    # Columns: ID, Charges, Effect_1, Effect_2, Effect_3, EffectPointsMin_1-3, EffectPointsMax_1-3,
    #          EffectArg_1-3, Name columns (16 lang columns), Name_Lang_Mask,
    #          ItemVisual, Flags, Src_ItemID, Condition_Id, RequiredSkillID, RequiredSkillRank, MinLevel
    
    row = [
        enchant_id,  # ID
        0,  # Charges
        effect1,  # Effect_1
        effect2,  # Effect_2
        effect3,  # Effect_3
        stat1_value,  # EffectPointsMin_1
        stat2_value,  # EffectPointsMin_2
        stat3_value,  # EffectPointsMin_3
        stat1_value,  # EffectPointsMax_1
        stat2_value,  # EffectPointsMax_2
        stat3_value,  # EffectPointsMax_3
        stat1_type,  # EffectArg_1 (stat type)
        stat2_type,  # EffectArg_2 (stat type)
        stat3_type,  # EffectArg_3 (stat type)
        display_name,  # Name_Lang_enUS
    ]
    
    # Add empty strings for other language columns (15 more)
    for _ in range(15):
        row.append("")
    
    # Add remaining columns
    row.extend([
        16712190,  # Name_Lang_Mask
        0,  # ItemVisual
        0,  # Flags
        0,  # Src_ItemID
        0,  # Condition_Id
        0,  # RequiredSkillID
        0,  # RequiredSkillRank
        0,  # MinLevel
    ])
    
    return row


def main():
    output_file = "heirloom_enchants_to_add.csv"
    
    rows = []
    for pkg_id in range(1, 13):  # 12 packages
        for level in range(1, 16):  # 15 levels
            row = generate_enchantment_row(pkg_id, level)
            rows.append(row)
    
    # Write CSV
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        
        # Write header
        header = [
            "ID", "Charges", "Effect_1", "Effect_2", "Effect_3",
            "EffectPointsMin_1", "EffectPointsMin_2", "EffectPointsMin_3",
            "EffectPointsMax_1", "EffectPointsMax_2", "EffectPointsMax_3",
            "EffectArg_1", "EffectArg_2", "EffectArg_3",
            "Name_Lang_enUS", "Name_Lang_enGB", "Name_Lang_koKR", "Name_Lang_frFR",
            "Name_Lang_deDE", "Name_Lang_enCN", "Name_Lang_zhCN", "Name_Lang_enTW",
            "Name_Lang_zhTW", "Name_Lang_esES", "Name_Lang_esMX", "Name_Lang_ruRU",
            "Name_Lang_ptPT", "Name_Lang_ptBR", "Name_Lang_itIT", "Name_Lang_Unk",
            "Name_Lang_Mask", "ItemVisual", "Flags", "Src_ItemID",
            "Condition_Id", "RequiredSkillID", "RequiredSkillRank", "MinLevel"
        ]
        writer.writerow(header)
        
        # Write data rows
        for row in rows:
            writer.writerow(row)
    
    print(f"Generated {len(rows)} enchantment entries in {output_file}")
    print("\nSample entries:")
    for pkg_id in [1, 2, 5]:  # Show samples from Fury, Precision, Spellfire
        for level in [1, 11, 15]:
            row = generate_enchantment_row(pkg_id, level)
            print(f"  ID {row[0]}: {row[14]} - Stats: {row[5]}/{row[6]}/{row[7]}")


if __name__ == "__main__":
    main()
