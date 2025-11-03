#!/usr/bin/env python3
"""
Analyze DBC file structure to understand the exact format
"""
import struct
import sys

def read_dbc_header(filename):
    """Read DBC file header"""
    with open(filename, 'rb') as f:
        # DBC header is: signature(4) + records(4) + fields(4) + record_size(4) + string_block_size(4)
        data = f.read(20)
        signature, records, fields, record_size, string_block_size = struct.unpack('<5I', data)
        
        print(f"File: {filename}")
        print(f"Signature: {signature} (0x{signature:08x}) - should be 0x43424457 for 'WDBC'")
        print(f"Records: {records}")
        print(f"Fields: {fields}")
        print(f"Record Size: {record_size} bytes")
        print(f"String Block Size: {string_block_size} bytes")
        print(f"Expected file size: {20 + (records * record_size) + string_block_size}")
        print(f"Actual file size: {len(open(filename, 'rb').read())}")
        
        # Read first record to see data
        f.seek(20)
        first_record = f.read(record_size)
        print(f"\nFirst record (hex): {first_record.hex()}")
        print(f"First record size: {len(first_record)} bytes")
        
        # Try to parse as integers
        print("\nFirst record as 32-bit integers:")
        num_ints = record_size // 4
        for i in range(min(10, num_ints)):
            val = struct.unpack_from('<I', first_record, i*4)[0]
            print(f"  Field {i}: {val} (0x{val:08x})")

if __name__ == "__main__":
    filename = "c:\\Users\\flori\\Desktop\\WoW Server\\Azeroth Fork\\DarkChaos-255\\Custom\\DBCs\\Achievement.dbc"
    read_dbc_header(filename)
