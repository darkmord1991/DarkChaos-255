#!/usr/bin/env python3
"""
PROPERLY convert difficulty integers to ENUM strings
Only replace the 3rd field (difficulty column), not other columns!
"""

import re

print("Reading MASTER_WORLD_v4.0.sql...")

with open('MASTER_WORLD_v4.0.sql', 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern that matches the VALUES section for dungeon quest mappings
# (quest_id, dungeon_id, difficulty, token, gold, group, active)
# We only want to replace the difficulty field (3rd position)

def fix_dungeon_insert(match):
    """Fix a single INSERT value tuple"""
    text = match.group(0)
    # Pattern: (number, number, [0-3], number, number, [0-1], [0-1])
    # We need to replace only position 3 (after 2 commas)
    
    # Replace each difficulty value carefully
    parts = text.split(',')
    if len(parts) >= 7:  # Should have 7 parts
        # parts[2] is the difficulty (after quest_id and dungeon_id)
        difficulty_str = parts[2].strip()
        
        # Map integers to ENUMs
        difficulty_map = {
            '0': "'Normal'",
            '1': "'Heroic'",
            '2': "'Mythic'",
            '3': "'Mythic+'"
        }
        
        if difficulty_str in difficulty_map:
            parts[2] = ' ' + difficulty_map[difficulty_str]
            return ','.join(parts)
    
    return text

# Match pattern for dungeon quest section only (after "-- Ragefire Chasm" comment)
# Find the section starting from line "-- Ragefire Chasm (700701-700718)"
dungeon_section_start = content.find("-- Ragefire Chasm (700701-700718)")

if dungeon_section_start == -1:
    print("ERROR: Could not find dungeon quest section!")
    exit(1)

# Find the end (before verification queries)
dungeon_section_end = content.find("-- =====================================================================\n-- VERIFICATION QUERIES", dungeon_section_start)

if dungeon_section_end == -1:
    dungeon_section_end = len(content)

# Extract the dungeon section
before_dungeon = content[:dungeon_section_start]
dungeon_section = content[dungeon_section_start:dungeon_section_end]
after_dungeon = content[dungeon_section_end:]

print(f"Found dungeon section: {len(dungeon_section)} bytes")

# Pattern to match individual INSERT tuples
# (number, number, number, number, number, number, number)
pattern = r'\(\d+,\s*\d+,\s*[0-3],\s*\d+,\s*\d+,\s*[01],\s*[01]\)'

# Fix all matches in dungeon section
fixed_dungeon = re.sub(pattern, fix_dungeon_insert, dungeon_section)

# Count replacements
original_zeros = dungeon_section.count(', 0, ')
original_ones = dungeon_section.count(', 1, ')  
original_twos = dungeon_section.count(', 2, ')
original_threes = dungeon_section.count(', 3, ')

fixed_normals = fixed_dungeon.count("'Normal'")
fixed_heroics = fixed_dungeon.count("'Heroic'")
fixed_mythics = fixed_dungeon.count("'Mythic'")
fixed_mythicplus = fixed_dungeon.count("'Mythic+'")

print(f"\nConversions in dungeon section:")
print(f"  'Normal'  : {fixed_normals}")
print(f"  'Heroic'  : {fixed_heroics}")
print(f"  'Mythic'  : {fixed_mythics}")
print(f"  'Mythic+' : {fixed_mythicplus}")

# Rebuild file
new_content = before_dungeon + fixed_dungeon + after_dungeon

# Write back
with open('MASTER_WORLD_v4.0.sql', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("\n✓ File updated successfully!")
print("✓ Only the difficulty column (3rd position) was modified")
print("✓ base_token_reward, base_gold_reward, requires_group unchanged")
