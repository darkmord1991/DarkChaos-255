#!/usr/bin/env python3
"""
Add dungeon quest titles directly to CharTitles.dbc binary file
"""
import struct
import os
import shutil

def read_dbc(filename):
    """Read DBC file"""
    with open(filename, 'rb') as f:
        data = f.read(20)
        signature, num_records, num_fields, record_size, string_block_size = struct.unpack('<5I', data)
        
        if signature != 0x43424457:  # 'WDBC'
            raise ValueError(f"Invalid DBC signature: 0x{signature:08x}")
        
        print(f"Reading {filename}")
        print(f"  Records: {num_records}, Fields: {num_fields}, Record Size: {record_size}")
        
        records_data = f.read(num_records * record_size)
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
    """Add string to string block"""
    if not text:
        return 0, string_block
    text_bytes = text.encode('utf-8') + b'\x00'
    offset = len(string_block)
    return offset, string_block + text_bytes

def create_title_record(title_id, condition_id, name_text, name1_text, mask_id, string_block):
    """
    Create a title record for CharTitles.dbc
    Record size is 148 bytes, not 156
    37 fields * 4 bytes = 148 bytes
    Fields: ID(1) + Condition_ID(1) + Name_Lang(18) + Name1_Lang(18) = 38 fields... 
    Wait that's 152 bytes. Let me recalculate: 37 fields exactly
    So: 1 ID + 1 Condition + 17 Name + 17 Name1 + 1 Mask = 37 fields * 4 = 148 bytes
    """
    
    # Add strings to block
    name_offset, string_block = add_string(string_block, name_text)
    name1_offset, string_block = add_string(string_block, name1_text)
    
    record = bytearray(148)  # Correct size: 37 fields * 4 bytes
    offset = 0
    
    # Field 0: ID (int)
    struct.pack_into('<I', record, offset, title_id)
    offset += 4
    
    # Field 1: Condition_ID (int)
    struct.pack_into('<I', record, offset, condition_id)
    offset += 4
    
    # Fields 2-18: Name_Lang (17 ints, NOT 18!) 
    struct.pack_into('<I', record, offset, name_offset)
    offset += 4
    for _ in range(16):  # 16 more for 17 total
        struct.pack_into('<I', record, offset, 0)
        offset += 4
    
    # Fields 19-35: Name1_Lang (17 ints)
    struct.pack_into('<I', record, offset, name1_offset)
    offset += 4
    for _ in range(16):  # 16 more for 17 total
        struct.pack_into('<I', record, offset, 0)
        offset += 4
    
    # Field 36: Mask_ID (int)
    struct.pack_into('<I', record, offset, mask_id)
    offset += 4
    
    assert offset == 148, f"Title record offset {offset} != 148"
    
    return bytes(record), string_block

def write_dbc(filename, dbc_data):
    """Write DBC file"""
    with open(filename, 'wb') as f:
        f.write(struct.pack('<5I',
                dbc_data['signature'],
                dbc_data['num_records'],
                dbc_data['num_fields'],
                dbc_data['record_size'],
                dbc_data['string_block_size']))
        f.write(dbc_data['records_data'])
        f.write(dbc_data['string_block'])
    
    print(f"Wrote {filename}")

# Main
dbc_file = "c:\\Users\\flori\\Desktop\\WoW Server\\Azeroth Fork\\DarkChaos-255\\Custom\\DBCs\\CharTitles.dbc"
backup_file = dbc_file + ".backup"

if not os.path.exists(backup_file):
    shutil.copy(dbc_file, backup_file)
    print(f"Created backup: {backup_file}")

# Read DBC
dbc = read_dbc(dbc_file)

# Titles to add (using available IDs 188-239, not 2000-2051)
# The existing CharTitles.dbc only goes up to ID 187, so we start from 188
titles = [
    (188, 0, "Dungeon Delver", "<Dungeon Delver>", 1),
    (189, 0, "Stratholme Conqueror", "<Stratholme Conqueror>", 1),
    (190, 0, "Molten Purifier", "<Molten Purifier>", 1),
    (191, 0, "Shadow Slayer", "<Shadow Slayer>", 1),
    (192, 0, "Titan's Foe", "<Titan's Foe>", 1),
    (193, 0, "Crusader Supreme", "<Crusader Supreme>", 1),
    (194, 0, "Lichborne Champion", "<Lichborne Champion>", 1),
    (195, 0, "Crimson Protector", "<Crimson Protector>", 1),
    (196, 0, "Veteran Dungeon Master", "<Veteran Dungeon Master>", 1),
    (197, 0, "Master Dungeon Conqueror", "<Master Dungeon Conqueror>", 1),
    (198, 0, "Elite Quest Master", "<Elite Quest Master>", 1),
    (199, 0, "Legendary Explorer", "<Legendary Explorer>", 1),
    (200, 0, "Speedrunner", "<Speedrunner>", 1),
    (201, 0, "Speed Demon", "<Speed Demon>", 1),
    (202, 0, "Loot Lord", "<Loot Lord>", 1),
    (203, 0, "Collector's Pride", "<Collector's Pride>", 1),
    (204, 0, "Gold Rush", "<Gold Rush>", 1),
    (205, 0, "Rich Adventurer", "<Rich Adventurer>", 1),
    (206, 0, "Token Hoarder", "<Token Hoarder>", 1),
    (207, 0, "Token Master", "<Token Master>", 1),
    (208, 0, "Blackrock Depths Conqueror", "<Blackrock Depths Conqueror>", 1),
    (209, 0, "Stratholme Liberator", "<Stratholme Liberator>", 1),
    (210, 0, "Molten Core Purifier", "<Molten Core Purifier>", 1),
    (211, 0, "Black Temple Destroyer", "<Black Temple Destroyer>", 1),
    (212, 0, "Ulduar Titan Slayer", "<Ulduar Titan Slayer>", 1),
    (213, 0, "Trial Champion", "<Trial Champion>", 1),
    (214, 0, "Icecrown Liberator", "<Icecrown Liberator>", 1),
    (215, 0, "Ruby Sanctum Guardian", "<Ruby Sanctum Guardian>", 1),
    (216, 0, "Depths Explorer", "<Depths Explorer>", 1),
    (217, 0, "Strath Slayer", "<Strath Slayer>", 1),
    (218, 0, "Molten Expert", "<Molten Expert>", 1),
    (219, 0, "Shadow Expert", "<Shadow Expert>", 1),
    (220, 0, "Titan Expert", "<Titan Expert>", 1),
    (221, 0, "Crusade Expert", "<Crusade Expert>", 1),
    (222, 0, "Lich Expert", "<Lich Expert>", 1),
    (223, 0, "Crimson Expert", "<Crimson Expert>", 1),
    (224, 0, "Perfect Week", "<Perfect Week>", 1),
    (225, 0, "Monthly Master", "<Monthly Master>", 1),
    (226, 0, "Daily Grind", "<Daily Grind>", 1),
    (227, 0, "Legendary Series", "<Legendary Series>", 1),
    (228, 0, "Party Vanquisher", "<Party Vanquisher>", 1),
    (229, 0, "Solo Master", "<Solo Master>", 1),
    (230, 0, "Legendary Soloist", "<Legendary Soloist>", 1),
    (231, 0, "No Deaths Allowed", "<No Deaths Allowed>", 1),
    (232, 0, "Hardcore Survivor", "<Hardcore Survivor>", 1),
    (233, 0, "Five Star Admiral", "<Five Star Admiral>", 1),
    (234, 0, "Perfection Achieved", "<Perfection Achieved>", 1),
    (235, 0, "Creature Slayer", "<Creature Slayer>", 1),
    (236, 0, "Boss Destroyer", "<Boss Destroyer>", 1),
    (237, 0, "Pit Conqueror", "<Pit Conqueror>", 1),
    (238, 0, "Halls Liberator", "<Halls Liberator>", 1),
    (239, 0, "Ultimate Dungeon Master", "<Ultimate Dungeon Master>", 1),
]

print(f"\nAdding {len(titles)} titles...")

# Build new records and string block
new_records = dbc['records_data']
new_string_block = dbc['string_block']

for title in titles:
    record, new_string_block = create_title_record(*title, new_string_block)
    new_records += record

# Update DBC data
dbc['num_records'] += len(titles)
dbc['string_block_size'] = len(new_string_block)
dbc['records_data'] = new_records
dbc['string_block'] = new_string_block

print(f"New record count: {dbc['num_records']}")
print(f"New string block size: {len(new_string_block)} bytes")

# Write updated DBC
write_dbc(dbc_file, dbc)

print("\n✓ Successfully added titles!")
print(f"✓ Titles added: {len(titles)}")
print(f"✓ Backup created at: {backup_file}")
