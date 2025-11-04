#!/usr/bin/env python3
"""
Final generator: reads CSV and creates creature_queststarter/questender INSERTs
with proper NPC assignments based on dungeon expansion.
"""

import csv

# Map ID to NPC mapping (expansion-based)
# NPC 700000 = Classic (expansion 0)
# NPC 700001 = TBC (expansion 1)  
# NPC 700002 = WotLK (expansion 2)

MAP_TO_NPC = {
    # Classic (NPC 700000)
    389: 700000,   # Ragefire Chasm
    36: 700000,    # Deadmines
    48: 700000,    # Blackfathom Deeps
    34: 700000,    # Stockade
    43: 700000,    # Wailing Caverns
    47: 700000,    # Razorfen Kraul
    90: 700000,    # Gnomeregan
    189: 700000,   # Scarlet Monastery
    129: 700000,   # Razorfen Downs
    70: 700000,    # Uldaman
    209: 700000,   # Zul'Farrak
    349: 700000,   # Maraudon
    109: 700000,   # Sunken Temple
    229: 700000,   # Blackrock Depths
    230: 700000,   # Blackrock Spire
    329: 700000,   # Stratholme
    429: 700000,   # Dire Maul
    33: 700000,    # Shadowfang Keep
    289: 700000,   # Scholomance
    
    # TBC (NPC 700001)
    543: 700001,   # Hellfire Citadel
    547: 700001,   # Coilfang Reservoir (Slave Pens)
    546: 700001,   # Coilfang Reservoir (Underbog)
    545: 700001,   # Coilfang Reservoir (Steamvault)
    554: 700001,   # Tempest Keep
    557: 700001,   # Auchindoun (Mana-Tombs)
    558: 700001,   # Auchindoun (Auchenai Crypts)
    556: 700001,   # Auchindoun (Sethekk Halls)
    555: 700001,   # Auchindoun (Shadow Labyrinth)
    269: 700001,   # Caverns of Time
    585: 700001,   # Magisters' Terrace
    
    # WotLK (NPC 700002)
    574: 700002,   # Utgarde Keep
    575: 700002,   # Utgarde Pinnacle
    576: 700002,   # The Nexus
    578: 700002,   # The Oculus
    599: 700002,   # Halls of Stone
    602: 700002,   # Halls of Lightning
    601: 700002,   # Azjol-Nerub
    619: 700002,   # Ahn'kahet
    604: 700002,   # Gundrak
    608: 700002,   # The Violet Hold
    600: 700002,   # Drak'Tharon Keep
    632: 700002,   # The Forge of Souls
    658: 700002,   # Pit of Saron
    595: 700002,   # The Culling of Stratholme
    668: 700002,   # Halls of Reflection
    631: 700002,   # Icecrown Citadel (this will need spawns in the future, but add for now)
}

# Read CSV and collect quests
quest_data = {}  # map_id -> [quest_ids]
all_quests = set()

csv_path = r"c:\Users\flori\Desktop\WoW Server\Azeroth Fork\DarkChaos-255\Custom\feature stuff\DungeonQuestSystem\data\dungeon_quest_map_correlation.csv"

try:
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            quest_id = int(row['quest_id'])
            map_id = int(row['map_id'])
            
            if map_id not in quest_data:
                quest_data[map_id] = []
            
            if quest_id not in quest_data[map_id]:
                quest_data[map_id].append(quest_id)
            
            all_quests.add(quest_id)
except Exception as e:
    print(f"Error reading CSV: {e}")
    exit(1)

# Generate creature_queststarter INSERTs grouped by NPC
print("-- =====================================================================")
print("-- CREATURE_QUESTSTARTER: Quest givers (Blizzard quest IDs)")
print("-- =====================================================================")
print()

npc_quests = {700000: [], 700001: [], 700002: []}

# Organize quests by NPC
for map_id, quest_list in quest_data.items():
    if map_id in MAP_TO_NPC:
        npc = MAP_TO_NPC[map_id]
        npc_quests[npc].extend(quest_list)

# Generate INSERTs for each NPC
for npc in [700000, 700001, 700002]:
    if npc_quests[npc]:
        print(f"DELETE FROM `creature_queststarter` WHERE `id` = {npc};")
        print(f"INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES")
        
        quest_list = sorted(set(npc_quests[npc]))
        for i, quest in enumerate(quest_list):
            comma = "," if i < len(quest_list) - 1 else ";"
            print(f"({npc}, {quest}){comma}")
        print()

# Generate creature_questender INSERTs
print()
print("-- =====================================================================")
print("-- CREATURE_QUESTENDER: Quest completers (same quests)")
print("-- =====================================================================")
print()

for npc in [700000, 700001, 700002]:
    if npc_quests[npc]:
        print(f"DELETE FROM `creature_questender` WHERE `id` = {npc};")
        print(f"INSERT INTO `creature_questender` (`id`, `quest`) VALUES")
        
        quest_list = sorted(set(npc_quests[npc]))
        for i, quest in enumerate(quest_list):
            comma = "," if i < len(quest_list) - 1 else ";"
            print(f"({npc}, {quest}){comma}")
        print()

# Summary
print("-- =====================================================================")
print(f"-- SUMMARY: {len(all_quests)} total Blizzard quests assigned")
print(f"-- NPC 700000 (Classic): {len(set(npc_quests[700000]))} quests")
print(f"-- NPC 700001 (TBC): {len(set(npc_quests[700001]))} quests")
print(f"-- NPC 700002 (WotLK): {len(set(npc_quests[700002]))} quests")
print("-- =====================================================================")

# Print missing maps
print()
print("-- Maps in CSV:")
for map_id in sorted(quest_data.keys()):
    npc = MAP_TO_NPC.get(map_id, "UNKNOWN")
    print(f"-- Map {map_id}: {len(quest_data[map_id])} quests -> NPC {npc}")
