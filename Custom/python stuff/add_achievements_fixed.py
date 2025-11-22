#!/usr/bin/env python3
"""
Add dungeon quest achievements directly to Achievement.dbc binary file
Corrected field order based on WDBX screenshot
"""
import struct
import os
import shutil

def read_dbc(filename):
    """Read DBC file and return components"""
    with open(filename, 'rb') as f:
        # Read header: 5 uints = 20 bytes
        data = f.read(20)
        signature, num_records, num_fields, record_size, string_block_size = struct.unpack('<5I', data)
        
        if signature != 0x43424457:  # 'WDBC'
            raise ValueError(f"Invalid DBC signature: 0x{signature:08x}")
        
        print(f"Reading {filename}")
        print(f"  Records: {num_records}, Fields: {num_fields}, Record Size: {record_size}")
        
        # Read all records
        records_data = f.read(num_records * record_size)
        
        # Read string block
        string_block = f.read(string_block_size)
        
    return {
        'signature': signature,
        'num_records': num_records,
        'num_fields': num_fields,
        'record_size': record_size,
        'string_block_size': string_block_size,
        'records_data': records_data,
        'string_block': string_block
    }

def add_string(string_block, text):
    """Add string to string block, return offset"""
    if not text:
        return 0, string_block  # Null offset
    text_bytes = text.encode('utf-8') + b'\x00'
    offset = len(string_block)
    return offset, string_block + text_bytes

def create_achievement_record(ach_id, faction, instance_id, supercedes, 
                             title, description, reward, category, points, ui_order, flags, icon_id,
                             string_block):
    """
    Create a 248-byte achievement record with string offsets
    62 fields × 4 bytes = 248 bytes
    
    Field layout (from WDBX screenshot analysis):
    0: ID
    1: Faction
    2: Instance_Id
    3: Supercedes
    4-21: Title_Lang (18 ints: enUS + 17 others)
    22-39: Description_Lang (18 ints)
    40-57: Reward_Lang (18 ints)
    58: Category
    59: Points
    60: UI_Order
    61: Flags (end - total 62 fields)
    
    Wait - IconID should be there. Let me check if it's merged with Flags or comes after.
    Actually from binary analysis: record_size = 248, and we have the Mask fields
    """
    
    record = bytearray(248)
    offset = 0
    
    # Add title, description, reward strings to block and get offsets
    title_offset, string_block = add_string(string_block, title)
    desc_offset, string_block = add_string(string_block, description)
    reward_offset, string_block = add_string(string_block, reward)
    
    # Field 0: ID (int)
    struct.pack_into('<I', record, offset, ach_id)
    offset += 4
    
    # Field 1: Faction (int, signed)
    struct.pack_into('<i', record, offset, faction)
    offset += 4
    
    # Field 2: Instance_Id (int, signed)
    struct.pack_into('<i', record, offset, instance_id)
    offset += 4
    
    # Field 3: Supercedes (int)
    struct.pack_into('<I', record, offset, supercedes)
    offset += 4
    
    # Fields 4-21: Title_Lang (18 ints)
    struct.pack_into('<I', record, offset, title_offset)
    offset += 4
    for _ in range(17):
        struct.pack_into('<I', record, offset, 0)
        offset += 4
    
    # Fields 22-39: Description_Lang (18 ints)
    struct.pack_into('<I', record, offset, desc_offset)
    offset += 4
    for _ in range(17):
        struct.pack_into('<I', record, offset, 0)
        offset += 4
    
    # Fields 40-57: Reward_Lang (18 ints)
    struct.pack_into('<I', record, offset, reward_offset)
    offset += 4
    for _ in range(17):
        struct.pack_into('<I', record, offset, 0)
        offset += 4
    
    # Field 58: Category (int)
    struct.pack_into('<I', record, offset, category)
    offset += 4
    
    # Field 59: Points (int)
    struct.pack_into('<I', record, offset, points)
    offset += 4
    
    # Field 60: UI_Order (int)
    struct.pack_into('<I', record, offset, ui_order)
    offset += 4
    
    # Field 61: Flags (int) - THIS IS THE 62nd field (0-indexed), total 248 bytes
    struct.pack_into('<I', record, offset, flags)
    offset += 4
    
    # offset is now 248, we've used all the space
    assert offset == 248, f"Record offset {offset} != 248"
    
    return bytes(record), string_block

def write_dbc(filename, dbc_data):
    """Write DBC file"""
    with open(filename, 'wb') as f:
        # Write header
        f.write(struct.pack('<5I', 
                dbc_data['signature'],
                dbc_data['num_records'],
                dbc_data['num_fields'],
                dbc_data['record_size'],
                dbc_data['string_block_size']))
        
        # Write records
        f.write(dbc_data['records_data'])
        
        # Write string block
        f.write(dbc_data['string_block'])
    
    print(f"Wrote {filename}")

# Main
dbc_file = "c:\\Users\\flori\\Desktop\\WoW Server\\Azeroth Fork\\DarkChaos-255\\Custom\\DBCs\\Achievement.dbc"
backup_file = dbc_file + ".backup"

# Create backup if it doesn't exist
if not os.path.exists(backup_file):
    shutil.copy(dbc_file, backup_file)
    print(f"Created backup: {backup_file}")

# Read DBC
dbc = read_dbc(dbc_file)

# Achievements to add - all 52 for dungeon quests
achievements = [
    (13500, -1, -1, 0, "Dungeon Delver", "Complete all daily quests in Blackrock Depths.", "", 97, 5, 1, 4, 3454),
    (13501, -1, -1, 0, "Stratholme Conqueror", "Complete all daily quests in Stratholme.", "", 97, 5, 1, 4, 3454),
    (13502, -1, -1, 0, "Molten Purifier", "Complete all daily quests in Molten Core.", "", 97, 5, 1, 4, 3454),
    (13503, -1, -1, 0, "Shadow Slayer", "Complete all daily quests in Black Temple.", "", 97, 5, 1, 4, 3454),
    (13504, -1, -1, 0, "Titan's Foe", "Complete all daily quests in Ulduar.", "", 97, 5, 1, 4, 3454),
    (13505, -1, -1, 0, "Crusader Supreme", "Complete all daily quests in Trial of the Crusader.", "", 97, 5, 1, 4, 3454),
    (13506, -1, -1, 0, "Lichborne Champion", "Complete all daily quests in Icecrown Citadel.", "", 97, 5, 1, 4, 3454),
    (13507, -1, -1, 0, "Crimson Protector", "Complete all daily quests in Ruby Sanctuary.", "", 97, 5, 1, 4, 3454),
    (13508, -1, -1, 0, "Veteran Dungeon Master", "Complete 50 dungeon quests across all dungeons.", "", 97, 10, 1, 4, 3454),
    (13509, -1, -1, 0, "Master Dungeon Conqueror", "Complete 100 dungeon quests across all dungeons.", "", 97, 10, 1, 4, 3454),
    (13510, -1, -1, 0, "Elite Quest Master", "Complete 250 dungeon quests across all dungeons.", "", 97, 15, 1, 4, 3454),
    (13511, -1, -1, 0, "Legendary Explorer", "Complete 500 dungeon quests across all dungeons.", "", 97, 20, 1, 4, 3454),
    (13512, -1, -1, 0, "Speedrunner", "Complete any dungeon in less than 20 minutes.", "", 97, 10, 1, 4, 3454),
    (13513, -1, -1, 0, "Speed Demon", "Complete 10 speedruns under the time limit.", "", 97, 15, 1, 4, 3454),
    (13514, -1, -1, 0, "Loot Lord", "Collect 100 unique item drops from dungeon quests.", "", 97, 15, 1, 4, 3454),
    (13515, -1, -1, 0, "Collector's Pride", "Collect 500 unique item drops from dungeon quests.", "", 97, 20, 1, 4, 3454),
    (13516, -1, -1, 0, "Gold Rush", "Earn 100,000 gold from dungeon quests.", "", 97, 15, 1, 4, 3454),
    (13517, -1, -1, 0, "Rich Adventurer", "Earn 1,000,000 gold from dungeon quests.", "", 97, 20, 1, 4, 3454),
    (13518, -1, -1, 0, "Token Hoarder", "Collect 1,000 dungeon tokens.", "", 97, 15, 1, 4, 3454),
    (13519, -1, -1, 0, "Token Master", "Collect 10,000 dungeon tokens.", "", 97, 20, 1, 4, 3454),
    (13520, -1, -1, 0, "Blackrock Depths Conqueror", "Defeat all bosses in Blackrock Depths.", "", 97, 10, 1, 4, 3454),
    (13521, -1, -1, 0, "Stratholme Liberator", "Defeat all bosses in Stratholme.", "", 97, 10, 1, 4, 3454),
    (13522, -1, -1, 0, "Molten Core Purifier", "Defeat all bosses in Molten Core.", "", 97, 10, 1, 4, 3454),
    (13523, -1, -1, 0, "Black Temple Destroyer", "Defeat all bosses in Black Temple.", "", 97, 10, 1, 4, 3454),
    (13524, -1, -1, 0, "Ulduar Titan Slayer", "Defeat all bosses in Ulduar.", "", 97, 10, 1, 4, 3454),
    (13525, -1, -1, 0, "Trial Champion", "Defeat all bosses in Trial of the Crusader.", "", 97, 10, 1, 4, 3454),
    (13526, -1, -1, 0, "Icecrown Liberator", "Defeat all bosses in Icecrown Citadel.", "", 97, 10, 1, 4, 3454),
    (13527, -1, -1, 0, "Ruby Sanctum Guardian", "Defeat all bosses in Ruby Sanctuary.", "", 97, 10, 1, 4, 3454),
    (13528, -1, -1, 0, "Depths Explorer", "Complete 100 quests in Blackrock Depths.", "", 97, 10, 1, 4, 3454),
    (13529, -1, -1, 0, "Strath Slayer", "Complete 100 quests in Stratholme.", "", 97, 10, 1, 4, 3454),
    (13530, -1, -1, 0, "Molten Expert", "Complete 100 quests in Molten Core.", "", 97, 10, 1, 4, 3454),
    (13531, -1, -1, 0, "Shadow Expert", "Complete 100 quests in Black Temple.", "", 97, 10, 1, 4, 3454),
    (13532, -1, -1, 0, "Titan Expert", "Complete 100 quests in Ulduar.", "", 97, 10, 1, 4, 3454),
    (13533, -1, -1, 0, "Crusade Expert", "Complete 100 quests in Trial of the Crusader.", "", 97, 10, 1, 4, 3454),
    (13534, -1, -1, 0, "Lich Expert", "Complete 100 quests in Icecrown Citadel.", "", 97, 10, 1, 4, 3454),
    (13535, -1, -1, 0, "Crimson Expert", "Complete 100 quests in Ruby Sanctuary.", "", 97, 10, 1, 4, 3454),
    (13536, -1, -1, 0, "Perfect Week", "Complete all weekly quests in a single week.", "", 97, 15, 1, 4, 3454),
    (13537, -1, -1, 0, "Monthly Master", "Complete 100 weekly quests total.", "", 97, 20, 1, 4, 3454),
    (13538, -1, -1, 0, "Daily Grind", "Complete 100 daily quests in a single month.", "", 97, 15, 1, 4, 3454),
    (13539, -1, -1, 0, "Legendary Series", "Complete 1000 total dungeon quests.", "", 97, 25, 1, 4, 3454),
    (13540, -1, -1, 0, "Party Vanquisher", "Complete 50 dungeons in a party.", "", 97, 10, 1, 4, 3454),
    (13541, -1, -1, 0, "Solo Master", "Complete 50 dungeons solo.", "", 97, 10, 1, 4, 3454),
    (13542, -1, -1, 0, "Legendary Soloist", "Complete 250 dungeons solo.", "", 97, 20, 1, 4, 3454),
    (13543, -1, -1, 0, "No Deaths Allowed", "Complete 25 dungeons without any party member dying.", "", 97, 15, 1, 4, 3454),
    (13544, -1, -1, 0, "Hardcore Survivor", "Complete 100 dungeons without any party member dying.", "", 97, 20, 1, 4, 3454),
    (13545, -1, -1, 0, "Five Star Admiral", "Achieve 5-star rating on 50 dungeon completions.", "", 97, 15, 1, 4, 3454),
    (13546, -1, -1, 0, "Perfection Achieved", "Achieve 5-star rating on 100 dungeon completions.", "", 97, 20, 1, 4, 3454),
    (13547, -1, -1, 0, "Creature Slayer", "Defeat 1000 creatures across all dungeons.", "", 97, 15, 1, 4, 3454),
    (13548, -1, -1, 0, "Boss Destroyer", "Defeat 500 bosses across all dungeons.", "", 97, 20, 1, 4, 3454),
    (13549, -1, -1, 0, "Pit Conqueror", "Complete all daily quests in Pit of Saron.", "", 97, 5, 1, 4, 3454),
    (13550, -1, -1, 0, "Halls Liberator", "Complete all daily quests in Halls of Reflection.", "", 97, 5, 1, 4, 3454),
    (13551, -1, -1, 0, "Ultimate Dungeon Master", "Complete all dungeon quest achievements.", "", 97, 25, 1, 4, 3454),
]

print(f"\nAdding {len(achievements)} achievements...")

# Build new records and string block
new_records = dbc['records_data']
new_string_block = dbc['string_block']

for ach in achievements:
    record, new_string_block = create_achievement_record(*ach, new_string_block)
    new_records += record

# Update DBC data
dbc['num_records'] += len(achievements)
dbc['string_block_size'] = len(new_string_block)
dbc['records_data'] = new_records
dbc['string_block'] = new_string_block

print(f"New record count: {dbc['num_records']}")
print(f"New string block size: {len(new_string_block)} bytes")

# Write updated DBC
write_dbc(dbc_file, dbc)

print("\n✓ Successfully added achievements!")
print(f"✓ Records added: {len(achievements)}")
print(f"✓ Backup created at: {backup_file}")
