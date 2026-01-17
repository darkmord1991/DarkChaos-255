#!/usr/bin/env python3
"""
Add dungeon quest achievements directly to Achievement.dbc binary file
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
    """Create a 248-byte achievement record with string offsets"""
    
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
    
    # Fields 4-21: Title_Lang (18 ints - English text offset + 17 language offsets)
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
    
    # Field 61: Flags (int) - THIS IS THE LAST FIELD (62 fields total, 0-61)
    struct.pack_into('<I', record, offset, flags)
    offset += 4
    
    # Note: IconID and other fields must be before the last boundary
    # For now we're done - all 62 fields filled, 248 bytes used
    
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

# Create backup
if not os.path.exists(backup_file):
    shutil.copy(dbc_file, backup_file)
    print(f"Created backup: {backup_file}")

# Read DBC
dbc = read_dbc(dbc_file)

# Achievements to add
achievements = [
    (13500, -1, -1, 0, "Dungeon Delver", "Complete all daily quests in Blackrock Depths.", "", 97, 5, 1, 4, 3454),
    (13501, -1, -1, 0, "Stratholme Conqueror", "Complete all daily quests in Stratholme.", "", 97, 5, 1, 4, 3454),
    (13502, -1, -1, 0, "Molten Purifier", "Complete all daily quests in Molten Core.", "", 97, 5, 1, 4, 3454),
    (13503, -1, -1, 0, "Shadow Slayer", "Complete all daily quests in Black Temple.", "", 97, 5, 1, 4, 3454),
    (13504, -1, -1, 0, "Titan's Foe", "Complete all daily quests in Ulduar.", "", 97, 5, 1, 4, 3454),
    (13505, -1, -1, 0, "Crusader Supreme", "Complete all daily quests in Trial of the Crusader.", "", 97, 5, 1, 4, 3454),
    (13506, -1, -1, 0, "Lichborne Champion", "Complete all daily quests in Icecrown Citadel.", "", 97, 5, 1, 4, 3454),
    (13507, -1, -1, 0, "Crimson Protector", "Complete all daily quests in Ruby Sanctuary.", "", 97, 5, 1, 4, 3454),
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
