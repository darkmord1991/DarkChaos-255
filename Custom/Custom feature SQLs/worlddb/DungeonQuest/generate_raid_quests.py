#!/usr/bin/env python3
"""
Generate Raid Quest Assignments for Dungeon Quest System v5.0

This script creates quest assignments for WotLK raid quests
using new NPC entries (700055+) for each raid.

Map IDs for WotLK Raids:
- Naxxramas: 533
- The Eye of Eternity: 616  
- Obsidian Sanctum: 615
- Ulduar: 603
- Trial of the Crusader: 649
- Icecrown Citadel: 631
- Ruby Sanctum: 724
- Karazhan (TBC): 532
- Serpentshrine Cavern (TBC): 552
- Tempest Keep (TBC): 554
- Hyjal Summit (TBC): 534
- Black Temple (TBC): 564
- Sunwell Plateau (TBC): 580
- And older raids...
"""

# WotLK Raid Quests (from Wowhead)
# Format: (quest_id, raid_name, map_id)
RAID_QUESTS = [
    # Naxxramas (533) - NPC 700055
    (13593, "Naxxramas", 533),  # The Only Song I Know...
    (13609, "Naxxramas", 533),  # Echoes of War
    (13610, "Naxxramas", 533),  # Anub'Rekhan Must Die!
    (13614, "Naxxramas", 533),  # Patchwerk Must Die!
    
    # Eye of Eternity (616) - NPC 700056
    (13616, "The Eye of Eternity", 616),  # Malygos Must Die!
    (13617, "The Eye of Eternity", 616),  # Judgment at the Eye of Eternity
    (13618, "The Eye of Eternity", 616),  # Heroic Judgment at the Eye of Eternity
    
    # Obsidian Sanctum (615) - NPC 700057
    (13619, "The Obsidian Sanctum", 615),  # Sartharion Must Die!
    
    # Ulduar (603) - NPC 700058
    (13620, "Ulduar", 603),  # Ancient History
    (13621, "Ulduar", 603),  # The Celestial Planetarium
    (13622, "Ulduar", 603),  # Algalon
    (13623, "Ulduar", 603),  # Archivum Data Disc
    (13624, "Ulduar", 603),  # Hodir's Sigil
    (13625, "Ulduar", 603),  # Thorim's Sigil
    (13626, "Ulduar", 603),  # Mimiron's Sigil
    (13628, "Ulduar", 603),  # All Is Well That Ends Well
    (13629, "Ulduar", 603),  # Heroic: All Is Well That Ends Well
    
    # Trial of the Crusader (649) - NPC 700059
    (13632, "Trial of the Crusader", 649),  # Lord Jaraxxus Must Die!
    
    # Icecrown Citadel (631) - NPC 700060 (SEPARATE from dungeons!)
    (13633, "Icecrown Citadel", 631),  # Lord Marrowgar Must Die!
    (13634, "Icecrown Citadel", 631),  # The Splintered Throne
    (13635, "Icecrown Citadel", 631),  # Blood Infusion
    (13636, "Icecrown Citadel", 631),  # Frost Infusion
    (13637, "Icecrown Citadel", 631),  # Unholy Infusion
    (13638, "Icecrown Citadel", 631),  # A Feast of Souls
    (13639, "Icecrown Citadel", 631),  # Respite for a Tormented Soul
    (13640, "Icecrown Citadel", 631),  # Securing the Ramparts
    (13641, "Icecrown Citadel", 631),  # Residue Rendezvous
    (13642, "Icecrown Citadel", 631),  # A Change of Heart
    (13643, "Icecrown Citadel", 631),  # Choose Your Path
    (13646, "Icecrown Citadel", 631),  # The Sacred and the Corrupt
    (13649, "Icecrown Citadel", 631),  # The Lich King's Last Stand
    (13662, "Icecrown Citadel", 631),  # Jaina's Locket
    (13663, "Icecrown Citadel", 631),  # Murarin's Lament
    (13664, "Icecrown Citadel", 631),  # The Lightbringer's Redemption
    (13665, "Icecrown Citadel", 631),  # Sylvanas' Vengeance
    (13666, "Icecrown Citadel", 631),  # Shadow's Edge
    (13667, "Icecrown Citadel", 631),  # Shadowmourne...
    (13668, "Icecrown Citadel", 631),  # Mograine's Reunion
    (13671, "Icecrown Citadel", 631),  # Path of Might
    (13672, "Icecrown Citadel", 631),  # Ashen Band of Endless Might (or similar)
    
    # Ruby Sanctum (724) - NPC 700061
    (13803, "The Ruby Sanctum", 724),  # Assault on the Sanctum
    (13804, "The Ruby Sanctum", 724),  # Trouble at Wyrmrest
    (13805, "The Ruby Sanctum", 724),  # The Twilight Destroyer
]

# Map NPC assignments
RAID_NPCS = {
    "Naxxramas": (700055, "Lich King's Herald", 80),
    "The Eye of Eternity": (700056, "Aspects' Oracle", 80),
    "The Obsidian Sanctum": (700057, "Twilight Historian", 80),
    "Ulduar": (700058, "Titan's Keeper", 80),
    "Trial of the Crusader": (700059, "Crusader's Quartermaster", 80),
    "Icecrown Citadel": (700060, "Frost Lich Keeper", 80),  # SEPARATE!
    "The Ruby Sanctum": (700061, "Twilight Warden", 82),
}

def generate_raid_quest_sql():
    """Generate SQL for raid quest assignments"""
    
    raids_by_npc = {}
    for quest_id, raid_name, map_id in RAID_QUESTS:
        npc_entry, npc_name, level = RAID_NPCS[raid_name]
        if npc_entry not in raids_by_npc:
            raids_by_npc[npc_entry] = []
        raids_by_npc[npc_entry].append(quest_id)
    
    print("-- =====================================================================")
    print("-- RAID QUEST ASSIGNMENTS v5.0")
    print("-- =====================================================================")
    print("-- WotLK Raid Quests for NPC 700055-700061")
    print("-- Total Quests: {}".format(sum(len(q) for q in raids_by_npc.values())))
    print("-- =====================================================================\n")
    
    # creature_queststarter
    print("-- RAID QUEST STARTERS")
    for npc, quest_ids in sorted(raids_by_npc.items()):
        print(f"\n-- NPC {npc}")
        print(f"DELETE FROM `creature_queststarter` WHERE `id` = {npc};")
        print(f"INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES")
        for i, quest_id in enumerate(sorted(quest_ids)):
            comma = "," if i < len(quest_ids) - 1 else ";"
            print(f"({npc}, {quest_id}){comma}")
    
    # creature_questender
    print("\n-- RAID QUEST ENDERS (same as starters)")
    for npc, quest_ids in sorted(raids_by_npc.items()):
        print(f"\n-- NPC {npc}")
        print(f"DELETE FROM `creature_questender` WHERE `id` = {npc};")
        print(f"INSERT INTO `creature_questender` (`id`, `quest`) VALUES")
        for i, quest_id in enumerate(sorted(quest_ids)):
            comma = "," if i < len(quest_ids) - 1 else ";"
            print(f"({npc}, {quest_id}){comma}")

def generate_npc_templates():
    """Generate creature_template entries for raid NPCs"""
    print("\n\n-- =====================================================================")
    print("-- RAID NPC TEMPLATES")
    print("-- =====================================================================\n")
    
    print("INSERT INTO `creature_template` ")
    print("(`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, ")
    print("`name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, ")
    print("`speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `scale`, `rank`, ")
    print("`dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, ")
    print("`unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, ")
    print("`trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, ")
    print("`PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, ")
    print("`HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, ")
    print("`RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`)")
    print("VALUES")
    
    raid_npcs_sorted = sorted(RAID_NPCS.items(), key=lambda x: x[1][0])
    for i, (raid_name, (npc_id, npc_name, level)) in enumerate(raid_npcs_sorted):
        comma = "," if i < len(raid_npcs_sorted) - 1 else ";"
        # NPC entry, 0, 0, 0, 0, 0, name, subname, Speak, 0, level, level, 2, faction, npcflag, walk, run, swim, fly, range, scale, rank, dmgschool, dmgmod, attacktime, rangeattack, variance, variance, class, unitflags, unitflags2, dynamicflags, family, trainer, spell, class, race, type, typeflags, loot, pickpocket, skin, petspell, vehicle, mingold, maxgold, AIName, movement, height, health, mana, armor, exp, raciallead, movement, regenhealth, mechimmune, spellimmune, flagsextra, scriptname, build
        print(f"({npc_id}, 0, 0, 0, 0, 0, '{npc_name}', 'Raid Quest Master', 'Speak', 0, {level}, {level}, 2, 35, 3, 1, 1.14286, 1, 1, 50, 1.2, 1, 0, 1, 2000, 2000, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 1000, '', 0, 1, 3, 1, 1, 1, 0, 0, 1, 0, 0, 2, 'npc_dungeon_quest_master', 0){comma}")

def generate_mapping():
    """Generate dc_dungeon_npc_mapping entries for raids"""
    print("\n\n-- =====================================================================")
    print("-- RAID NPC MAPPINGS")
    print("-- =====================================================================\n")
    
    print("-- Insert into dc_dungeon_npc_mapping for raid quests")
    print("INSERT INTO `dc_dungeon_npc_mapping` (`map_id`, `quest_master_entry`, `dungeon_name`, `expansion`, `min_level`, `max_level`) VALUES")
    
    # Create map_id to npc mapping
    map_npc = {}
    for quest_id, raid_name, map_id in RAID_QUESTS:
        npc_entry, npc_name, level = RAID_NPCS[raid_name]
        if map_id not in map_npc:
            map_npc[map_id] = (npc_entry, raid_name, 2)  # expansion 2 for WotLK raids
    
    for i, (map_id, (npc_entry, raid_name, expansion)) in enumerate(sorted(map_npc.items())):
        comma = "," if i < len(map_npc) - 1 else ";"
        print(f"({map_id}, {npc_entry}, '{raid_name}', {expansion}, 80, 80){comma}")

if __name__ == "__main__":
    generate_raid_quest_sql()
    generate_npc_templates()
    generate_mapping()
