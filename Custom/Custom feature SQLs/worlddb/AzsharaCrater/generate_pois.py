#!/usr/bin/env python3
"""
Azshara Crater Quest POI Generator
Generates SQL INSERT statements for all quest POIs without using stored procedures
"""

# Quest data: (quest_id, creature_entry, questgiver_entry, is_travel_quest)
QUESTS = [
    # Zone 1 Kill Quests
    (300101, 1984, 300002, False),   # Wildlife Survey (Boar)
    (300102, 822, 300002, False),    # Bear Bounty
    (300103, 2022, 300001, False),   # Strange Energies
    (300104, 1998, 300002, False),   # Web of Danger
    (300105, 2022, 300002, False),   # Ancient's Lair
    (300108, 46, 300001, False),     # Murloc Menace
    
    # Zone 1 Travel Quest
    (300106, 300010, 300010, True),  # Report to North (to Arcanist Melia)
    
    # Zone 2 Kill Quests
    (300200, 16303, 300010, False),  # Haunted Grounds
    (300201, 418, 300010, False),    # Spectral Samples
    (300202, 36, 300010, False),     # Ancient Relics
    (300204, 48, 300011, False),     # Wailing Noble
    (300205, 16303, 300011, False),  # Varo'then's Journal
    (300208, 5897, 300010, False),   # Elemental Imbalance
    
    # Zone 2 Travel Quests
    (300203, 300011, 300011, True),  # Commune with Spirit
    (300206, 300020, 300020, True),  # Into the Slopes
    
    # Zone 3 Kill Quests
    (300300, 2044, 300020, False),   # Proving Strength
    (300302, 3922, 300020, False),   # Smash the Totems
    (300303, 3924, 300020, False),   # Elder's Request
    (300304, 3925, 300020, False),   # Source of Corruption
    (300305, 3926, 300020, False),   # Cleansing Ritual
    (300308, 2089, 300020, False),   # Crocolisk Crisis
    
    # Zone 3 Travel Quest
    (300306, 300001, 300001, True),  # The River Awaits
    
    # Zone 4 Kill Quests
    (300400, 6190, 300030, False),   # Naga Threat
    (300401, 6348, 300030, False),   # Shellhide Shells
    (300402, 11467, 300030, False),  # Arcane Devourers
    (300403, 6129, 300030, False),   # Drake Scales
    (300404, 2779, 300030, False),   # Bounty: Prince Nazjak
    
    # Zone 4 Travel Quest
    (300405, 300040, 300040, True),  # The Western Cliffs
    
    # Zone 5 Kill Quests
    (300500, 11791, 300040, False),  # Satyr Horns
    (300501, 5865, 300040, False),   # Felhound Fangs
    (300502, 11464, 300040, False),  # Fel Steed Subjugation
    (300503, 11452, 300040, False),  # Shadowstalker Hunt
    (300504, 6144, 300040, False),   # Bounty: Monnos the Elder
    
    # Zone 5 Travel Quest
    (300505, 300050, 300050, True),  # Into Haldarr Territory
    
    # Zone 6 Kill Quests
    (300600, 6200, 300050, False),   # Legashi Cull
    (300602, 7671, 300050, False),   # Doomguard Commander
    (300603, 10831, 300050, False),  # Bounty: Gatekeeper Karlindos
    (300605, 8716, 300050, False),   # Portal Sabotage
    
    # Zone 6 Travel Quest
    (300604, 300060, 300060, True),  # Dragon Coast
    
    # Zone 7 Kill Quests
    (300700, 6130, 300060, False),   # Whelpling Menace
    (300701, 15527, 300060, False),  # Mana Surge
    (300702, 23456, 300060, False),  # Netherwing Presence
    (300703, 10196, 300060, False),  # Bounty: General Colbatann
    
    # Zone 7 Travel Quest
    (300704, 300070, 300070, True),  # The Temple Approach
    
    # Zone 8 Kill Quests
    (300800, 32164, 300070, False),  # Skeletal Army
    (300801, 31691, 300070, False),  # Faceless Horror
    (300802, 27220, 300070, False),  # Forgotten Captains
    (300803, 6910, 300070, False),   # Bounty: Antilos
    
    # Dungeon 1 Quests
    (300900, 4831, 300081, False),   # Lady Sarevess
    (300901, 1716, 300081, False),   # Targorr the Dread
    (300950, 300081, 300081, True),  # The Ruins of Zin-Azshari
    
    # Dungeon 2 Quests
    (300910, 4424, 300082, False),   # Death Speaker Jargba
    (300911, 4428, 300082, False),   # Aggem Thorncurse
    (300912, 1012, 300082, False),   # The Mosshide Menace
    (300951, 300082, 300082, True),  # Timbermaw Deep
    
    # Dungeon 3 Quests
    (300920, 9024, 300083, False),   # The Pyromancer
    (300921, 8637, 300083, False),   # The Iron Legion
    (300922, 8279, 300083, False),   # Faulty Engineering
    (300923, 9156, 300083, False),   # Ambassador of Flame
    (300952, 300083, 300083, True),  # The Dark Iron Invasion
    
    # Dungeon 4 Quests
    (300930, 11486, 300084, False),  # The Fel Pit
    (300931, 12143, 300084, False),  # Lady Hederine
    (300932, 19261, 300084, False),  # Infernal Warbringer
    (300933, 18044, 300084, False),  # Doomguard Punisher
    (300934, 6135, 300084, False),   # Demon Legion
    (300953, 300084, 300084, True),  # The Fel Pit Beckons
    
    # Dungeon 5 Quests
    (300940, 24560, 300085, False),  # Temple of Elune
    (300941, 4832, 300085, False),   # The Twilight Threat
    (300942, 16485, 300085, False),  # Arcane Corruption
    (300943, 14515, 300085, False),  # High Priestess Arlokk
    (300944, 10683, 300085, False),  # Highborne Corruption
    (300945, 15467, 300085, False),  # Moonkin Madness
    (300946, 13019, 300085, False),  # Eldreth Incursion
    (300955, 300085, 300085, True),  # The Temple of Elune
    
    # Dungeon 6 Quests
    (300960, 29317, 300086, False),  # Sanctum of the Highborne
    (300961, 11487, 300086, False),  # Magister Kalendris
    (300962, 27959, 300086, False),  # The Forgotten Ones
    (300963, 15689, 300086, False),  # Arcane Sentinels
    (300964, 37881, 300086, False),  # Wretched Infestation
    (300965, 6116, 300086, False),   # Highborne Spirits
    (300966, 27099, 300086, False),  # Faceless Horror
    (300954, 300086, 300086, True),  # The Sanctum Guardian
]

def generate_poi_sql(quest_id, creature_entry, questgiver_entry, is_travel):
    """Generate POI SQL for a single quest"""
    sql = []
    sql.append(f"-- Quest {quest_id}")
    
    if is_travel:
        # Travel quest: target NPC is both objective and completion
        sql.append(f"INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 0, 0, 37, 268, 0, 0, 3, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {creature_entry} LIMIT 1;")
        sql.append("")
        sql.append(f"INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 0, 0, c.position_x, c.position_y, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {creature_entry} LIMIT 1;")
        sql.append("")
        sql.append(f"INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 1, -1, 37, 268, 0, 0, 1, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {creature_entry} LIMIT 1;")
        sql.append("")
        sql.append(f"INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 1, 0, c.position_x, c.position_y, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {creature_entry} LIMIT 1;")
    else:
        # Kill quest: creature spawn + quest giver
        sql.append(f"INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 0, 0, 37, 268, 0, 0, 3, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {creature_entry} LIMIT 1;")
        sql.append("")
        sql.append(f"INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 0, 0, ROUND(AVG(c.position_x)), ROUND(AVG(c.position_y)), 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {creature_entry}")
        sql.append(f"HAVING AVG(c.position_x) IS NOT NULL;")
        sql.append("")
        sql.append(f"INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 1, -1, 37, 268, 0, 0, 1, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {questgiver_entry} LIMIT 1;")
        sql.append("")
        sql.append(f"INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`)")
        sql.append(f"SELECT {quest_id}, 1, 0, c.position_x, c.position_y, 0")
        sql.append(f"FROM creature c WHERE c.map = 37 AND c.id1 = {questgiver_entry} LIMIT 1;")
    
    sql.append("")
    return "\n".join(sql)

def main():
    """Generate the complete SQL file"""
    output = []
    
    # Header
    output.append("-- " + "=" * 76)
    output.append("-- Azshara Crater Quest POI Generator - COMPLETE")
    output.append("-- " + "=" * 76)
    output.append("-- Generated automatically for all Azshara Crater quests")
    output.append("-- Map: 37 | Zone: 268")
    output.append("-- " + "=" * 76)
    output.append("")
    
    # Cleanup
    output.append("DELETE FROM `quest_poi` WHERE `QuestID` BETWEEN 300100 AND 300966;")
    output.append("DELETE FROM `quest_poi_points` WHERE `QuestID` BETWEEN 300100 AND 300966;")
    output.append("")
    output.append("-- " + "=" * 76)
    output.append("-- POI Generation")
    output.append("-- " + "=" * 76)
    output.append("")
    
    # Generate POIs for all quests
    for quest_id, creature_entry, questgiver_entry, is_travel in QUESTS:
        output.append(generate_poi_sql(quest_id, creature_entry, questgiver_entry, is_travel))
    
    # Verification queries
    output.append("-- " + "=" * 76)
    output.append("-- Verification Queries")
    output.append("-- " + "=" * 76)
    output.append("")
    output.append("SELECT ")
    output.append("    qp.QuestID,")
    output.append("    qt.LogTitle as QuestName,")
    output.append("    qp.id as POI_ID,")
    output.append("    qp.ObjectiveIndex,")
    output.append("    qpp.X,")
    output.append("    qpp.Y")
    output.append("FROM quest_poi qp")
    output.append("JOIN quest_template qt ON qp.QuestID = qt.ID")
    output.append("LEFT JOIN quest_poi_points qpp ON qp.QuestID = qpp.QuestID AND qp.id = qpp.Idx1")
    output.append("WHERE qp.QuestID BETWEEN 300100 AND 300966")
    output.append("ORDER BY qp.QuestID, qp.id;")
    output.append("")
    output.append("-- " + "=" * 76)
    output.append("-- END OF SCRIPT")
    output.append("-- " + "=" * 76)
    
    # Write to file
    with open("2026_01_11_02_azshara_crater_quest_pois_generated.sql", "w", encoding="utf-8") as f:
        f.write("\n".join(output))
    
    print(f"Generated SQL file with {len(QUESTS)} quests!")
    print("File: 2026_01_11_02_azshara_crater_quest_pois_generated.sql")

if __name__ == "__main__":
    main()
