#!/usr/bin/env python3
"""
Generate correct dungeon quest INSERT statements with ENUM strings
"""

# Dungeon quest ranges: 700701-701037 (337 quests total)
# 18 quests per dungeon (4 difficulties × 4 quests + 2 extras)

dungeons = [
    (389, "Ragefire Chasm", 700701, 300, 450, 600, 900),
    (36, "Deadmines", 700719, 350, 500, 700, 1000),
    (48, "Blackfathom Deeps", 700737, 400, 550, 750, 1100),
    (34, "Stockade", 700755, 350, 500, 700, 1000),
    (43, "Wailing Caverns", 700773, 350, 500, 700, 1000),
    (47, "Razorfen Kraul", 700791, 450, 600, 850, 1200),
    (90, "Gnomeregan", 700809, 400, 550, 750, 1100),
    (189, "Scarlet Monastery", 700827, 500, 650, 900, 1300),
    (129, "Razorfen Downs", 700845, 550, 700, 950, 1400),
    (70, "Uldaman", 700863, 600, 750, 1000, 1500),
    (209, "Zul'Farrak", 700881, 650, 800, 1100, 1600),
    (349, "Maraudon", 700899, 700, 850, 1150, 1700),
    (109, "Sunken Temple", 700917, 750, 900, 1200, 1800),
    (229, "Blackrock Depths", 700935, 800, 1000, 1300, 1900),
    (230, "Blackrock Spire", 700953, 850, 1100, 1400, 2000),
    (329, "Stratholme", 700971, 900, 1150, 1450, 2100),
    (429, "Dire Maul", 700989, 950, 1200, 1500, 2200),
    (33, "Shadowfang Keep", 701007, 400, 550, 750, 1100),
]

# Additional quests to reach 337 total (701025-701037 = 13 quests)
extras = [
    (701025, 389, 'Mythic', 2, 600, 1, 1),
    (701026, 36, 'Mythic', 2, 700, 1, 1),
    (701027, 48, 'Mythic+', 3, 1100, 1, 1),
    (701028, 34, 'Mythic+', 3, 1000, 1, 1),
    (701029, 43, 'Mythic', 2, 700, 1, 1),
    (701030, 47, 'Mythic+', 3, 1200, 1, 1),
    (701031, 90, 'Mythic', 2, 750, 1, 1),
    (701032, 189, 'Mythic+', 3, 1300, 1, 1),
    (701033, 129, 'Mythic', 2, 950, 1, 1),
    (701034, 70, 'Mythic+', 3, 1500, 1, 1),
    (701035, 209, 'Mythic', 2, 1100, 1, 1),
    (701036, 349, 'Mythic+', 3, 1700, 1, 1),
    (701037, 109, 'Mythic', 2, 1200, 1, 1),
]

output = []
output.append("-- Dungeon Quest Mappings (337 quests across all dungeons and difficulties)")
output.append("-- Format: Quest ranges per dungeon, 4 difficulties each (Normal, Heroic, Mythic, Mythic+)")
output.append("")
output.append("INSERT INTO `dc_quest_difficulty_mapping`")
output.append("(`quest_id`, `dungeon_id`, `difficulty`, `base_token_reward`, `base_gold_reward`, `requires_group`, `is_active`)")
output.append("VALUES")

lines = []

for map_id, name, start_quest, normal_gold, heroic_gold, mythic_gold, mythicplus_gold in dungeons:
    output.append(f"-- {name} ({start_quest}-{start_quest+17}) - 18 quests")
    
    quest_id = start_quest
    
    # Normal (4 quests, solo, token=1)
    for i in range(4):
        lines.append(f"({quest_id}, {map_id}, 'Normal', 1, {normal_gold}, 0, 1)")
        quest_id += 1
    
    # Heroic (4 quests, solo, token=1)
    for i in range(4):
        lines.append(f"({quest_id}, {map_id}, 'Heroic', 1, {heroic_gold}, 0, 1)")
        quest_id += 1
    
    # Mythic (4 quests, group required, token=2)
    for i in range(4):
        lines.append(f"({quest_id}, {map_id}, 'Mythic', 2, {mythic_gold}, 1, 1)")
        quest_id += 1
    
    # Mythic+ (4 quests, group required, token=3)
    for i in range(4):
        lines.append(f"({quest_id}, {map_id}, 'Mythic+', 3, {mythicplus_gold}, 1, 1)")
        quest_id += 1
    
    # 2 extra quests (Normal and Heroic)
    lines.append(f"({quest_id}, {map_id}, 'Normal', 1, {normal_gold}, 0, 1)")
    quest_id += 1
    lines.append(f"({quest_id}, {map_id}, 'Heroic', 1, {heroic_gold}, 0, 1)")
    quest_id += 1
    
    output.append(", ".join(lines[-18:]) + ",")
    output.append("")

# Add extras
output.append("-- Additional 13 quests to reach 337 total (701025-701037)")
extra_lines = []
for quest_id, map_id, diff, token, gold, group, active in extras:
    extra_lines.append(f"({quest_id}, {map_id}, '{diff}', {token}, {gold}, {group}, {active})")

output.append(", ".join(extra_lines) + ";")

# Write to file
with open('dungeon_quests_fixed.sql', 'w', encoding='utf-8') as f:
    f.write('\n'.join(output))

print(f"✓ Generated {len(dungeons) * 18 + len(extras)} quest mappings")
print(f"✓ Saved to: dungeon_quests_fixed.sql")
print(f"✓ Total quests: {len(dungeons) * 18 + len(extras)}")
