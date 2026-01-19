#!/usr/bin/env python3
"""
Extend GT* DBC CSV files from level 100 to level 255
For DarkChaos-255 WoW private server

This script extends the following game tables:
- GtCombatRatings.csv (32 ratings × 100 levels -> 32 × 255)
- GtChanceToMeleeCrit.csv (11 classes × 100 levels -> 11 × 255)
- GtChanceToSpellCrit.csv (11 classes × 100 levels -> 11 × 255)
- GtOCTRegenHP.csv (11 classes × 100 levels -> 11 × 255)
- GtRegenHPPerSpt.csv (11 classes × 100 levels -> 11 × 255)
- GtRegenMPPerSpt.csv (11 classes × 100 levels -> 11 × 255)
- GtNPCManaCostScaler.csv (100 levels -> 255)

Barbershop costs are NOT extended (capped at level 100 as requested)
"""

import csv
import os
import math
from pathlib import Path

# Configuration
INPUT_DIR = Path(r"K:\Dark-Chaos\DarkChaos-255\Custom\CSV DBC")
OUTPUT_DIR = Path(r"K:\Dark-Chaos\DarkChaos-255\Custom\CSV DBC\Extended_255")

GT_MAX_LEVEL_OLD = 100
GT_MAX_LEVEL_NEW = 255
NUM_CLASSES = 11
NUM_COMBAT_RATINGS = 32


def parse_float(value_str):
    """Parse float from CSV - handles comma as decimal separator"""
    if not value_str or value_str == '':
        return 0.0
    # Replace comma with period for European format
    return float(value_str.replace(',', '.'))


def format_float(value):
    """Format float for CSV output - uses comma as decimal separator"""
    if value == 0:
        return "0"
    # Format with appropriate precision
    if abs(value) < 0.0001:
        return f"{value:.6E}".replace('.', ',')
    elif abs(value) < 1:
        return f"{value:.6f}".replace('.', ',').rstrip('0').rstrip(',')
    else:
        return f"{value:.6f}".replace('.', ',').rstrip('0').rstrip(',')


def read_csv(filepath):
    """Read CSV file and return list of (id, data) tuples"""
    data = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)  # Skip header
        for row in reader:
            if len(row) >= 2:
                data.append((int(row[0]), parse_float(row[1])))
    return data


def write_csv(filepath, data):
    """Write CSV file with (id, data) tuples"""
    with open(filepath, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, quoting=csv.QUOTE_ALL)
        writer.writerow(["ID", "Data"])
        for id_val, data_val in data:
            writer.writerow([str(id_val), format_float(data_val)])


def extrapolate_combat_ratings(data):
    """
    Extend GtCombatRatings from 100 to 255 levels per rating
    
    Combat ratings control how much rating is needed for 1% of a stat.
    Higher level = more rating needed (diminishing returns)
    
    Formula: exponential growth based on trend from level 60-80
    """
    new_data = []
    
    for rating_idx in range(NUM_COMBAT_RATINGS):
        # Get existing 100 levels for this rating
        start_idx = rating_idx * GT_MAX_LEVEL_OLD
        rating_data = [d[1] for d in data[start_idx:start_idx + GT_MAX_LEVEL_OLD]]
        
        # Add existing data
        for lvl in range(GT_MAX_LEVEL_OLD):
            new_id = rating_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, rating_data[lvl]))
        
        # Calculate growth rate from levels 70-80 (or use last value if flat)
        val_70 = rating_data[69] if len(rating_data) > 69 else rating_data[-1]
        val_80 = rating_data[79] if len(rating_data) > 79 else rating_data[-1]
        val_100 = rating_data[99] if len(rating_data) > 99 else rating_data[-1]
        
        # If values are 0 or near 0, just extend with 0
        if val_100 < 0.0001:
            for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
                new_id = rating_idx * GT_MAX_LEVEL_NEW + lvl + 1
                new_data.append((new_id, 0.0))
            continue
        
        # Calculate growth factor from level 80-100
        if val_80 > 0.0001:
            growth_per_level = (val_100 / val_80) ** (1.0 / 20.0)  # 20 levels
        else:
            growth_per_level = 1.05  # Default 5% per level
        
        # Extrapolate levels 101-255
        last_value = val_100
        for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
            # Continue exponential growth
            last_value = last_value * growth_per_level
            new_id = rating_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, last_value))
    
    return new_data


def extrapolate_class_based_crit(data, is_melee=True):
    """
    Extend GtChanceToMeleeCrit or GtChanceToSpellCrit from 100 to 255 levels per class
    
    These tables determine how much crit you get per point of Agility/Intellect.
    Higher level = LESS crit per stat point (values decrease)
    """
    new_data = []
    
    for class_idx in range(NUM_CLASSES):
        start_idx = class_idx * GT_MAX_LEVEL_OLD
        class_data = [d[1] for d in data[start_idx:start_idx + GT_MAX_LEVEL_OLD]]
        
        # Add existing data
        for lvl in range(GT_MAX_LEVEL_OLD):
            new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, class_data[lvl]))
        
        # Get level 80 and 100 values
        val_80 = class_data[79] if len(class_data) > 79 else class_data[-1]
        val_100 = class_data[99] if len(class_data) > 99 else class_data[-1]
        
        # If values are 0, extend with 0
        if val_100 < 1e-10:
            for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
                new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
                new_data.append((new_id, 0.0))
            continue
        
        # Calculate decay rate (values decrease with level)
        if val_80 > 1e-10:
            decay_per_level = (val_100 / val_80) ** (1.0 / 20.0)
        else:
            decay_per_level = 0.96  # Default ~4% decay per level
        
        # Ensure decay doesn't go below minimum
        min_value = val_100 * 0.01  # Floor at 1% of level 100 value
        
        # Extrapolate levels 101-255
        last_value = val_100
        for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
            last_value = max(last_value * decay_per_level, min_value)
            new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, last_value))
    
    return new_data


def extrapolate_regen_hp(data):
    """
    Extend GtOCTRegenHP from 100 to 255 levels per class
    
    This controls base HP regeneration from spirit.
    Values tend to plateau at higher levels.
    """
    new_data = []
    
    for class_idx in range(NUM_CLASSES):
        start_idx = class_idx * GT_MAX_LEVEL_OLD
        class_data = [d[1] for d in data[start_idx:start_idx + GT_MAX_LEVEL_OLD]]
        
        # Add existing data
        for lvl in range(GT_MAX_LEVEL_OLD):
            new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, class_data[lvl]))
        
        # Get level 100 value - keep it constant (plateau)
        val_100 = class_data[99] if len(class_data) > 99 else class_data[-1]
        
        # Extrapolate levels 101-255 - maintain level 100 value (plateau)
        for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
            new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, val_100))
    
    return new_data


def extrapolate_regen_per_spt(data, is_hp=True):
    """
    Extend GtRegenHPPerSpt or GtRegenMPPerSpt from 100 to 255 levels per class
    
    Controls spirit -> regen conversion.
    Higher level = less regen per spirit (diminishing)
    """
    new_data = []
    
    for class_idx in range(NUM_CLASSES):
        start_idx = class_idx * GT_MAX_LEVEL_OLD
        class_data = [d[1] for d in data[start_idx:start_idx + GT_MAX_LEVEL_OLD]]
        
        # Add existing data
        for lvl in range(GT_MAX_LEVEL_OLD):
            new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, class_data[lvl]))
        
        val_80 = class_data[79] if len(class_data) > 79 else class_data[-1]
        val_100 = class_data[99] if len(class_data) > 99 else class_data[-1]
        
        # If zero, extend with zero
        if val_100 < 1e-10:
            for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
                new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
                new_data.append((new_id, 0.0))
            continue
        
        # Calculate decay rate
        if val_80 > 1e-10:
            decay_per_level = (val_100 / val_80) ** (1.0 / 20.0)
        else:
            decay_per_level = 0.97
        
        # Floor value
        min_value = val_100 * 0.1  # Floor at 10% of level 100
        
        # Extrapolate
        last_value = val_100
        for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
            last_value = max(last_value * decay_per_level, min_value)
            new_id = class_idx * GT_MAX_LEVEL_NEW + lvl + 1
            new_data.append((new_id, last_value))
    
    return new_data


def extrapolate_npc_mana_cost(data):
    """
    Extend GtNPCManaCostScaler from 100 to 255 levels
    
    This scales NPC spell mana costs by level.
    Values increase with level.
    """
    new_data = list(data)  # Copy existing
    
    # Get trend from levels 80-100
    val_80 = data[79][1] if len(data) > 79 else data[-1][1]
    val_100 = data[99][1] if len(data) > 99 else data[-1][1]
    
    # Calculate linear growth per level
    growth_per_level = (val_100 - val_80) / 20.0
    
    # Extrapolate levels 101-255
    last_value = val_100
    for lvl in range(GT_MAX_LEVEL_OLD, GT_MAX_LEVEL_NEW):
        last_value = last_value + growth_per_level
        new_data.append((lvl + 1, last_value))
    
    return new_data


def main():
    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    print("=" * 60)
    print("Extending GT* DBC files from level 100 to level 255")
    print("=" * 60)
    
    # Process GtCombatRatings.csv
    print("\n[1/7] Processing GtCombatRatings.csv...")
    data = read_csv(INPUT_DIR / "GtCombatRatings.csv")
    print(f"  Read {len(data)} entries (32 ratings × 100 levels)")
    new_data = extrapolate_combat_ratings(data)
    write_csv(OUTPUT_DIR / "GtCombatRatings.csv", new_data)
    print(f"  Written {len(new_data)} entries (32 ratings × 255 levels)")
    
    # Process GtChanceToMeleeCrit.csv
    print("\n[2/7] Processing GtChanceToMeleeCrit.csv...")
    data = read_csv(INPUT_DIR / "GtChanceToMeleeCrit.csv")
    print(f"  Read {len(data)} entries (11 classes × 100 levels)")
    new_data = extrapolate_class_based_crit(data, is_melee=True)
    write_csv(OUTPUT_DIR / "GtChanceToMeleeCrit.csv", new_data)
    print(f"  Written {len(new_data)} entries (11 classes × 255 levels)")
    
    # Process GtChanceToSpellCrit.csv
    print("\n[3/7] Processing GtChanceToSpellCrit.csv...")
    data = read_csv(INPUT_DIR / "GtChanceToSpellCrit.csv")
    print(f"  Read {len(data)} entries (11 classes × 100 levels)")
    new_data = extrapolate_class_based_crit(data, is_melee=False)
    write_csv(OUTPUT_DIR / "GtChanceToSpellCrit.csv", new_data)
    print(f"  Written {len(new_data)} entries (11 classes × 255 levels)")
    
    # Process GtOCTRegenHP.csv
    print("\n[4/7] Processing GtOCTRegenHP.csv...")
    data = read_csv(INPUT_DIR / "GtOCTRegenHP.csv")
    print(f"  Read {len(data)} entries (11 classes × 100 levels)")
    new_data = extrapolate_regen_hp(data)
    write_csv(OUTPUT_DIR / "GtOCTRegenHP.csv", new_data)
    print(f"  Written {len(new_data)} entries (11 classes × 255 levels)")
    
    # Process GtRegenHPPerSpt.csv
    print("\n[5/7] Processing GtRegenHPPerSpt.csv...")
    data = read_csv(INPUT_DIR / "GtRegenHPPerSpt.csv")
    print(f"  Read {len(data)} entries (11 classes × 100 levels)")
    new_data = extrapolate_regen_per_spt(data, is_hp=True)
    write_csv(OUTPUT_DIR / "GtRegenHPPerSpt.csv", new_data)
    print(f"  Written {len(new_data)} entries (11 classes × 255 levels)")
    
    # Process GtRegenMPPerSpt.csv
    print("\n[6/7] Processing GtRegenMPPerSpt.csv...")
    data = read_csv(INPUT_DIR / "GtRegenMPPerSpt.csv")
    print(f"  Read {len(data)} entries (11 classes × 100 levels)")
    new_data = extrapolate_regen_per_spt(data, is_hp=False)
    write_csv(OUTPUT_DIR / "GtRegenMPPerSpt.csv", new_data)
    print(f"  Written {len(new_data)} entries (11 classes × 255 levels)")
    
    # Process GtNPCManaCostScaler.csv
    print("\n[7/7] Processing GtNPCManaCostScaler.csv...")
    data = read_csv(INPUT_DIR / "GtNPCManaCostScaler.csv")
    print(f"  Read {len(data)} entries (100 levels)")
    new_data = extrapolate_npc_mana_cost(data)
    write_csv(OUTPUT_DIR / "GtNPCManaCostScaler.csv", new_data)
    print(f"  Written {len(new_data)} entries (255 levels)")
    
    print("\n" + "=" * 60)
    print("DONE! Extended CSV files written to:")
    print(f"  {OUTPUT_DIR}")
    print("\nNOT MODIFIED (as requested):")
    print("  - GtBarberShopCostBase.csv (stays at level 100)")
    print("\n" + "=" * 60)
    print("\nNEXT STEPS:")
    print("1. Convert the extended CSV files back to DBC format")
    print("2. Update GT_MAX_LEVEL in DBCStructure.h from 100 to 255")
    print("3. Rebuild the server")
    print("4. Add DBCs to client patch (server-only use - client doesn't need them)")
    print("=" * 60)


if __name__ == "__main__":
    main()
