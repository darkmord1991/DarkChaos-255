#!/usr/bin/env python3
"""
Generate Comprehensive Raid Quest Assignments for All Expansions (Vanilla, TBC, WotLK)

Map IDs Reference:
VANILLA RAIDS:
- Molten Core: 409
- Blackwing Lair: 469
- Temple of Ahn'Qiraj: 531
- Ruins of Ahn'Qiraj: 509
- World Bosses: Various (Azuregos: 0, etc.)

TBC RAIDS:
- Karazhan: 532
- Serpentshrine Cavern: 552
- The Eye (Tempest Keep): 554
- Mount Hyjal: 534
- Black Temple: 564
- Sunwell Plateau: 580

WOTLK RAIDS:
- Naxxramas: 533
- The Eye of Eternity: 616
- The Obsidian Sanctum: 615
- Ulduar: 603
- Trial of the Crusader: 649
- Icecrown Citadel: 631
- Ruby Sanctum: 724

NPC ALLOCATION:
700055-700074: Vanilla & TBC raids (20 NPCs)
700075-700085: WotLK raids (11 NPCs)
"""

# Comprehensive Raid List with Quest IDs (sample - you should verify actual IDs from Wowhead)
ALL_RAIDS = {
    # VANILLA RAIDS (Expansion 0)
    "Molten Core": {
        "map_id": 409,
        "npc_entry": 700055,
        "expansion": 0,
        "level_range": (60, 60),
        "quests": [
            24425,  # Lucifron's Curse
            24427,  # Suppression
            24424,  # Shazzrah Must Die!
            24426,  # Gehennas the Flame
            24428,  # Golemagg the Incinerator
            24429,  # Sulfuron Harbinger
            24430,  # Ragnaros Must Die!
        ]
    },
    "Blackwing Lair": {
        "map_id": 469,
        "npc_entry": 700056,
        "expansion": 0,
        "level_range": (60, 60),
        "quests": [
            24432,  # Razorgore Must Die!
            24433,  # Vaelastrasz the Corrupt
            24434,  # Brood Affliction: Rabid
            24435,  # Brood Affliction: Blue Dragon Whelps
            24436,  # Taerar's Favor
            24437,  # Taerar Must Die!
            24438,  # Nefarian Must Die!
        ]
    },
    "Temple of Ahn'Qiraj": {
        "map_id": 531,
        "npc_entry": 700057,
        "expansion": 0,
        "level_range": (60, 60),
        "quests": [
            24440,  # Viscidus Must Die!
            24441,  # Prophecy of the Dragon
            24442,  # C'Thun Must Die!
            24443,  # Teleportation: Temple of Ahn'Qiraj
        ]
    },
    "Ruins of Ahn'Qiraj": {
        "map_id": 509,
        "npc_entry": 700058,
        "expansion": 0,
        "level_range": (40, 50),
        "quests": [
            24444,  # Ossirian the Unscarred
        ]
    },

    # TBC RAIDS (Expansion 1)
    "Karazhan": {
        "map_id": 532,
        "npc_entry": 700059,
        "expansion": 1,
        "level_range": (70, 70),
        "quests": [
            24445,  # Medivh's Tower
            24446,  # Attumen the Huntsman
            24447,  # Moroes Must Die!
            24448,  # The Menagerie
            24449,  # Shade of Aran Must Die!
            24450,  # The Master's Gambit
            24451,  # Prince Malchezaar
        ]
    },
    "Serpentshrine Cavern": {
        "map_id": 552,
        "npc_entry": 700060,
        "expansion": 1,
        "level_range": (70, 70),
        "quests": [
            24452,  # Hydross the Unstable
            24453,  # The Lurker Below
            24454,  # Leotheras the Blind
            24455,  # Fathom-Lord Karathress
            24456,  # Morogrim Tidewalker
            24457,  # Lady Vashj
        ]
    },
    "The Eye": {
        "map_id": 554,
        "npc_entry": 700061,
        "expansion": 1,
        "level_range": (70, 70),
        "quests": [
            24458,  # Alar Must Die!
            24459,  # VanCleef's Revenge
            24460,  # Kael'thas Must Die!
        ]
    },
    "Mount Hyjal": {
        "map_id": 534,
        "npc_entry": 700062,
        "expansion": 1,
        "level_range": (70, 70),
        "quests": [
            24461,  # Rage Winterchill
            24462,  # Anetheron Must Die!
            24463,  # Kaz'rogal
            24464,  # Azgalor Must Die!
            24465,  # Archimonde Must Die!
        ]
    },
    "Black Temple": {
        "map_id": 564,
        "npc_entry": 700063,
        "expansion": 1,
        "level_range": (70, 70),
        "quests": [
            24466,  # High Warlord Naj'entus
            24467,  # Supremus Must Die!
            24468,  # Mother Shahraz
            24469,  # The Illidari Council
            24470,  # Illidan Stormrage
        ]
    },
    "Sunwell Plateau": {
        "map_id": 580,
        "npc_entry": 700064,
        "expansion": 1,
        "level_range": (70, 70),
        "quests": [
            24471,  # Kalecgos Must Die!
            24472,  # Brutallus
            24473,  # Felmyst Must Die!
            24474,  # Eredar Twins
            24475,  # M'uru
            24476,  # Kil'jaeden Must Die!
        ]
    },

    # WOTLK RAIDS (Expansion 2)
    "Naxxramas": {
        "map_id": 533,
        "npc_entry": 700065,
        "expansion": 2,
        "level_range": (80, 80),
        "quests": [
            13593,  # The Only Song I Know...
            13609,  # Echoes of War
            13610,  # Anub'Rekhan Must Die!
            13614,  # Patchwerk Must Die!
        ]
    },
    "The Eye of Eternity": {
        "map_id": 616,
        "npc_entry": 700066,
        "expansion": 2,
        "level_range": (80, 80),
        "quests": [
            13616,  # Malygos Must Die!
            13617,  # Judgment at the Eye of Eternity
            13618,  # Heroic Judgment at the Eye of Eternity
        ]
    },
    "The Obsidian Sanctum": {
        "map_id": 615,
        "npc_entry": 700067,
        "expansion": 2,
        "level_range": (80, 80),
        "quests": [
            13619,  # Sartharion Must Die!
        ]
    },
    "Ulduar": {
        "map_id": 603,
        "npc_entry": 700068,
        "expansion": 2,
        "level_range": (80, 80),
        "quests": [
            13620,  # Ancient History
            13621,  # The Celestial Planetarium
            13622,  # Algalon
            13623,  # Archivum Data Disc
            13624,  # Hodir's Sigil
            13625,  # Thorim's Sigil
            13626,  # Mimiron's Sigil
            13628,  # All Is Well That Ends Well
            13629,  # Heroic: All Is Well That Ends Well
        ]
    },
    "Trial of the Crusader": {
        "map_id": 649,
        "npc_entry": 700069,
        "expansion": 2,
        "level_range": (80, 80),
        "quests": [
            13632,  # Lord Jaraxxus Must Die!
        ]
    },
    "Icecrown Citadel": {
        "map_id": 631,
        "npc_entry": 700070,
        "expansion": 2,
        "level_range": (80, 80),
        "quests": [
            13633,  # Lord Marrowgar Must Die!
            13634,  # The Splintered Throne
            13635,  # Blood Infusion
            13636,  # Frost Infusion
            13637,  # Unholy Infusion
            13638,  # A Feast of Souls
            13639,  # Respite for a Tormented Soul
            13640,  # Securing the Ramparts
            13641,  # Residue Rendezvous
            13642,  # A Change of Heart
            13643,  # Choose Your Path
            13646,  # The Sacred and the Corrupt
            13649,  # The Lich King's Last Stand
            13662,  # Jaina's Locket
            13663,  # Murarin's Lament
            13664,  # The Lightbringer's Redemption
            13665,  # Sylvanas' Vengeance
            13666,  # Shadow's Edge
            13667,  # Shadowmourne...
            13668,  # Mograine's Reunion
            13671,  # Path of Might
            13672,  # Ashen Band of Endless Might
        ]
    },
    "Ruby Sanctum": {
        "map_id": 724,
        "npc_entry": 700071,
        "expansion": 2,
        "level_range": (82, 82),
        "quests": [
            13803,  # Assault on the Sanctum
            13804,  # Trouble at Wyrmrest
            13805,  # The Twilight Destroyer
        ]
    },
}

# NPC Names by Expansion
NPC_NAMES = {
    "Molten Core": "Firekeeper Adagio",
    "Blackwing Lair": "Blackwing Herald",
    "Temple of Ahn'Qiraj": "Qiraji Keeper",
    "Ruins of Ahn'Qiraj": "Scarab Warden",
    "Karazhan": "Tower Master Meredith",
    "Serpentshrine Cavern": "Coilfang Quartermaster",
    "The Eye": "Solarian's Oracle",
    "Mount Hyjal": "Hyjal Guardian",
    "Black Temple": "Illidari Quartermaster",
    "Sunwell Plateau": "Sunwell Keeper",
    "Naxxramas": "Lich King's Herald",
    "The Eye of Eternity": "Aspects' Oracle",
    "The Obsidian Sanctum": "Twilight Historian",
    "Ulduar": "Titan's Keeper",
    "Trial of the Crusader": "Crusader's Quartermaster",
    "Icecrown Citadel": "Frost Lich Keeper",
    "Ruby Sanctum": "Twilight Warden",
}

EXPANSIONS = {0: "Vanilla", 1: "TBC", 2: "WotLK"}

def generate_all_raids_sql():
    """Generate SQL for all raid quest assignments"""
    
    print("-- =====================================================================")
    print("-- COMPREHENSIVE RAID QUEST ASSIGNMENTS v5.0")
    print("-- ALL EXPANSIONS: Vanilla, TBC, WotLK")
    print("-- =====================================================================")
    print()
    
    total_quests = sum(len(raid["quests"]) for raid in ALL_RAIDS.values())
    total_raids = len(ALL_RAIDS)
    total_npcs = len(set(raid["npc_entry"] for raid in ALL_RAIDS.values()))
    
    print(f"-- Total Raids: {total_raids}")
    print(f"-- Total NPCs: {total_npcs}")
    print(f"-- Total Quests: {total_quests}")
    print()
    
    # Creature templates
    print("-- =====================================================================")
    print("-- DELETE OLD RAID NPCs (700055-700071)")
    print("-- =====================================================================")
    print("DELETE FROM `creature_template` WHERE `entry` IN (700055, 700056, 700057, 700058, 700059, 700060, 700061, 700062, 700063, 700064, 700065, 700066, 700067, 700068, 700069, 700070, 700071);")
    print()
    
    print("-- =====================================================================")
    print("-- RAID NPC TEMPLATES (All Expansions)")
    print("-- =====================================================================")
    print()
    
    # Sort by NPC entry
    sorted_raids = sorted(ALL_RAIDS.items(), key=lambda x: x[1]["npc_entry"])
    
    print("INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`)")
    print("VALUES")
    
    for i, (raid_name, raid_info) in enumerate(sorted_raids):
        npc_entry = raid_info["npc_entry"]
        min_level, max_level = raid_info["level_range"]
        npc_name = NPC_NAMES[raid_name]
        expansion = EXPANSIONS[raid_info["expansion"]]
        
        comma = "," if i < len(sorted_raids) - 1 else ";"
        
        print(f"({npc_entry}, 0, 0, 0, 0, 0, '{npc_name}', 'Raid Quest Master [{expansion}]', 'Speak', 0, {min_level}, {max_level}, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0){comma}")
    
    print()
    print()
    
    # Quest starters
    print("-- =====================================================================")
    print("-- RAID QUEST STARTERS (All Expansions)")
    print("-- =====================================================================")
    print()
    
    for raid_name, raid_info in sorted_raids:
        npc_entry = raid_info["npc_entry"]
        quests = raid_info["quests"]
        expansion = EXPANSIONS[raid_info["expansion"]]
        
        print(f"-- {raid_name} [{expansion}] - NPC {npc_entry}")
        print(f"DELETE FROM `creature_queststarter` WHERE `id` = {npc_entry};")
        print(f"INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES")
        
        for j, quest_id in enumerate(sorted(quests)):
            comma = "," if j < len(quests) - 1 else ";"
            print(f"({npc_entry}, {quest_id}){comma}")
        
        print()
    
    print()
    
    # Quest enders
    print("-- =====================================================================")
    print("-- RAID QUEST ENDERS (All Expansions - Same as Starters)")
    print("-- =====================================================================")
    print()
    
    for raid_name, raid_info in sorted_raids:
        npc_entry = raid_info["npc_entry"]
        quests = raid_info["quests"]
        
        print(f"-- {raid_name} - NPC {npc_entry}")
        print(f"DELETE FROM `creature_questender` WHERE `id` = {npc_entry};")
        print(f"INSERT INTO `creature_questender` (`id`, `quest`) VALUES")
        
        for j, quest_id in enumerate(sorted(quests)):
            comma = "," if j < len(quests) - 1 else ";"
            print(f"({npc_entry}, {quest_id}){comma}")
        
        print()
    
    print()
    
    # Mappings
    print("-- =====================================================================")
    print("-- RAID NPC MAPPINGS (Update dc_dungeon_npc_mapping)")
    print("-- =====================================================================")
    print()
    print("-- Remove old mapping for NPC 700002 from ICC")
    print("DELETE FROM `dc_dungeon_npc_mapping` WHERE `map_id` = 631 AND `quest_master_entry` = 700002;")
    print()
    print("-- Insert all raid mappings")
    print("INSERT INTO `dc_dungeon_npc_mapping` (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`) VALUES")
    
    for i, (raid_name, raid_info) in enumerate(sorted_raids):
        map_id = raid_info["map_id"]
        npc_entry = raid_info["npc_entry"]
        expansion = raid_info["expansion"]
        min_level, max_level = raid_info["level_range"]
        
        comma = "," if i < len(sorted_raids) - 1 else ";"
        
        print(f"({map_id}, {npc_entry}, '{raid_name}', {expansion}, {min_level}, {max_level}){comma}")
    
    print()
    print()
    print("-- =====================================================================")
    print("-- SUMMARY")
    print("-- =====================================================================")
    print(f"-- Total Raids Added: {total_raids}")
    print(f"-- Total NPCs Created: {total_npcs}")
    print(f"-- Total Quests Added: {total_quests}")
    print("--")
    print("-- NPC Ranges:")
    print("-- Vanilla Raids: 700055-700058 (4 NPCs)")
    print("-- TBC Raids:    700059-700064 (6 NPCs)")
    print("-- WotLK Raids:  700065-700071 (7 NPCs)")
    print("-- =====================================================================")

if __name__ == "__main__":
    generate_all_raids_sql()
