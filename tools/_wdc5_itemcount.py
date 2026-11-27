#!/usr/bin/env python3
"""
Minimal WDC5 parser - decode Item.db2 fields (ClassID, InventoryType, SheatheType)
per record id, plus dump field storage info. Ground-truth per-slot enumeration for
the DarkChaos item downport sizing task.
"""
import struct
import sys
import os

DBC_DIR = "K:/Dark-Chaos/WoW server data/11.1.7 TC/dbc/deDE/"

def u32(d, o): return struct.unpack_from('<I', d, o)[0]
def i32(d, o): return struct.unpack_from('<i', d, o)[0]
def u16(d, o): return struct.unpack_from('<H', d, o)[0]

class WDC5:
    def __init__(self, path):
        self.d = open(path, 'rb').read()
        self.parse()

    def parse(self):
        d = self.d
        assert d[0:4] == b'WDC5', d[0:4]
        self.version = u32(d, 4)
        # schema string 128 bytes
        p = 8 + 128
        (self.record_count, self.field_count, self.record_size,
         self.string_table_size, self.table_hash, self.layout_hash,
         self.min_id, self.max_id, self.locale, self.flags,
         self.total_field_count, self.bitpacked_data_offset,
         self.lookup_column_count, self.field_storage_info_size,
         self.common_data_size, self.pallet_data_size,
         self.section_count) = struct.unpack_from('<IIIIiiiiIIIIIIIII', d, p)
        p += struct.calcsize('<IIIIiiiiIIIIIIIII')
        self.has_offset_map = bool(self.flags & 0x01)
        self.has_id_block = not (self.flags & 0x04) == 0  # flag 0x04 => separate id list
        # section headers
        self.sections = []
        for s in range(self.section_count):
            (tact_key, file_offset, srecord_count, sstring_size,
             offset_records_end, sid_list_size, srelationship_size,
             soffset_map_id_count, scopy_table_count) = struct.unpack_from('<QIIIIIIII', d, p)
            p += struct.calcsize('<QIIIIIIII')
            self.sections.append(dict(
                file_offset=file_offset, record_count=srecord_count,
                string_size=sstring_size, offset_records_end=offset_records_end,
                id_list_size=sid_list_size, relationship_size=srelationship_size,
                offset_map_id_count=soffset_map_id_count,
                copy_table_count=scopy_table_count))
        # field structure (field_count x {int16 size_bits, uint16 position})
        self.fields = []
        for fi in range(self.field_count):
            size_bits = struct.unpack_from('<h', d, p)[0]; p += 2
            position = struct.unpack_from('<H', d, p)[0]; p += 2
            self.fields.append((size_bits, position))
        # field storage info (total_field_count x 24 bytes)
        self.storage = []
        n_storage = self.field_storage_info_size // 24
        for fi in range(n_storage):
            (field_offset_bits, field_size_bits, additional_data_size,
             storage_type, comp1, comp2, comp3) = struct.unpack_from('<HHIIIII', d, p)
            p += 24
            self.storage.append(dict(
                offset_bits=field_offset_bits, size_bits=field_size_bits,
                additional_data_size=additional_data_size,
                storage_type=storage_type, comp1=comp1, comp2=comp2, comp3=comp3))
        self.pallet_start = p
        p += self.pallet_data_size
        self.common_start = p
        p += self.common_data_size
        self.after_common = p

    def dump(self):
        print(f"version={self.version} records={self.record_count} fields={self.field_count} "
              f"total_fields={self.total_field_count} record_size={self.record_size} "
              f"flags={self.flags} sections={self.section_count} layout_hash={self.layout_hash}")
        print(f"has_offset_map={self.has_offset_map} string_table_size={self.string_table_size}")
        for i, st in enumerate(self.storage):
            stype = {0:'none/inline', 1:'bitpacked', 2:'common', 3:'pallet', 4:'pallet_array', 5:'signed_bitpacked'}.get(st['storage_type'], st['storage_type'])
            print(f"  field[{i}] offbits={st['offset_bits']} sizebits={st['size_bits']} "
                  f"type={stype} c1={st['comp1']} c2={st['comp2']} c3={st['comp3']} add={st['additional_data_size']}")
        for i, s in enumerate(self.sections):
            print(f"  section[{i}] off={s['file_offset']} recs={s['record_count']} "
                  f"str={s['string_size']} idlist={s['id_list_size']} "
                  f"copy={s['copy_table_count']} reln={s['relationship_size']} "
                  f"offmapids={s['offset_map_id_count']} offrecend={s['offset_records_end']}")

if __name__ == '__main__':
    name = sys.argv[1] if len(sys.argv) > 1 else 'Item.db2'
    w = WDC5(os.path.join(DBC_DIR, name))
    w.dump()
