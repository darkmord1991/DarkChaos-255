#!/usr/bin/env python3
"""
WDC5 decoder for Item.db2 - extract per-record ClassID + InventoryType,
including all sections, id lists and copy tables. Counts items per
(ClassID, InventoryType).
"""
import struct, sys, os
from collections import Counter, defaultdict

DBC_DIR = "K:/Dark-Chaos/WoW server data/11.1.7 TC/dbc/deDE/"

def read_bits(buf_bytes, bit_offset, bit_count):
    """Read bit_count bits starting at bit_offset (LSB-first within byte stream)."""
    val = 0
    for i in range(bit_count):
        byte_i = (bit_offset + i) >> 3
        bit_i = (bit_offset + i) & 7
        if byte_i < len(buf_bytes):
            bit = (buf_bytes[byte_i] >> bit_i) & 1
            val |= (bit << i)
    return val

class WDC5:
    def __init__(self, path):
        self.d = open(path, 'rb').read()
        self._parse()

    def _parse(self):
        d = self.d
        assert d[0:4] == b'WDC5'
        self.version = struct.unpack_from('<I', d, 4)[0]
        p = 8 + 128
        hdrfmt = '<IIIIiiiiIIIIIIIII'
        (self.record_count, self.field_count, self.record_size,
         self.string_table_size, self.table_hash, self.layout_hash,
         self.min_id, self.max_id, self.locale, self.flags,
         self.total_field_count, self.bitpacked_data_offset,
         self.lookup_column_count, self.field_storage_info_size,
         self.common_data_size, self.pallet_data_size,
         self.section_count) = struct.unpack_from(hdrfmt, d, p)
        p += struct.calcsize(hdrfmt)
        self.has_offset_map = bool(self.flags & 0x01)
        # section headers
        self.sections = []
        secfmt = '<QIIIIIIII'
        for s in range(self.section_count):
            (tact_key, file_offset, srec, sstr, offrecend, sidlist,
             srel, soffmapidcount, scopy) = struct.unpack_from(secfmt, d, p)
            p += struct.calcsize(secfmt)
            self.sections.append(dict(file_offset=file_offset, record_count=srec,
                string_size=sstr, offset_records_end=offrecend, id_list_size=sidlist,
                relationship_size=srel, offset_map_id_count=soffmapidcount,
                copy_table_count=scopy))
        # field structure
        self.fields = []
        for _ in range(self.field_count):
            sb = struct.unpack_from('<h', d, p)[0]; p += 2
            pos = struct.unpack_from('<H', d, p)[0]; p += 2
            self.fields.append((sb, pos))
        # storage info
        self.storage = []
        for _ in range(self.field_storage_info_size // 24):
            t = struct.unpack_from('<HHIIIII', d, p); p += 24
            self.storage.append(dict(offset_bits=t[0], size_bits=t[1],
                additional_data_size=t[2], storage_type=t[3],
                comp1=t[4], comp2=t[5], comp3=t[6]))
        self.pallet_start = p
        self.pallet = d[p:p + self.pallet_data_size]
        p += self.pallet_data_size
        self.common = d[p:p + self.common_data_size]
        p += self.common_data_size

    def pallet_value(self, field_idx, palette_index):
        # pallet entries are 4 bytes each, concatenated per-field in order of fields
        base = 0
        for fi in range(field_idx):
            base += self.storage[fi]['additional_data_size']
        off = base + palette_index * 4
        return struct.unpack_from('<I', self.pallet, off)[0]

    def decode(self, want_fields):
        """Return dict id -> {field_idx: value} for want_fields (must be pallet or bitpacked)."""
        d = self.d
        out = {}
        for sec in self.sections:
            p = sec['file_offset']
            # records: record_count * record_size bytes (non-sparse, has_offset_map False)
            rec_data_len = sec['record_count'] * self.record_size
            rec_start = p
            p += rec_data_len
            # string block
            p += sec['string_size']
            # id list: record_count uint32 (since flag 0x04 => separate ids)
            id_list = []
            if sec['id_list_size']:
                cnt = sec['id_list_size'] // 4
                for i in range(cnt):
                    id_list.append(struct.unpack_from('<I', d, p + i*4)[0])
                p += sec['id_list_size']
            # copy table: copy_table_count * (uint32 id_new, uint32 id_old)
            copies = []
            if sec['copy_table_count']:
                ncopy = sec['copy_table_count'] // 8  # field is byte size
                for i in range(ncopy):
                    nid, oid = struct.unpack_from('<II', d, p + i*8)
                    copies.append((nid, oid))
                p += sec['copy_table_count']
            # relationship map skipped
            p += sec['relationship_size']

            # decode each record
            rec_values = {}  # ridx -> {fid: val}
            for ridx in range(sec['record_count']):
                rbuf = d[rec_start + ridx*self.record_size : rec_start + (ridx+1)*self.record_size]
                vals = {}
                for fid in want_fields:
                    st = self.storage[fid]
                    raw = read_bits(rbuf, st['offset_bits'], st['size_bits'])
                    if st['storage_type'] in (3, 4):  # pallet
                        vals[fid] = self.pallet_value(fid, raw)
                    else:
                        vals[fid] = raw
                rec_values[ridx] = vals
                rid = id_list[ridx] if id_list else None
                if rid is not None:
                    out[rid] = vals
            # apply copy table (copied row id_new gets values of id_old)
            for nid, oid in copies:
                if oid in out:
                    out[nid] = dict(out[oid])
        return out


INVTYPE = {
 0:'NON_EQUIP',1:'HEAD',2:'NECK',3:'SHOULDER',4:'BODY(shirt)',5:'CHEST',
 6:'WAIST',7:'LEGS',8:'FEET',9:'WRIST',10:'HAND',11:'FINGER',12:'TRINKET',
 13:'WEAPON(1H)',14:'SHIELD',15:'RANGED',16:'CLOAK',17:'2HWEAPON',18:'BAG',
 19:'TABARD',20:'ROBE(chest)',21:'MAINHAND',22:'OFFHAND',23:'HOLDABLE',
 24:'AMMO',25:'THROWN',26:'RANGEDRIGHT',27:'QUIVER',28:'RELIC'}
CLASSNAME={0:'Consumable',1:'Container',2:'Weapon',3:'Gem',4:'Armor',5:'Reagent',
 6:'Projectile',7:'TradeGoods',8:'ItemEnhancement',9:'Recipe',10:'Money',
 11:'Quiver',12:'Quest',13:'Key',14:'Permanent',15:'Misc',16:'Glyph',
 17:'BattlePet',18:'WoWToken',19:'Profession'}

if __name__ == '__main__':
    w = WDC5(os.path.join(DBC_DIR, 'Item.db2'))
    # field 0 = ClassID, field 3 = InventoryType (hypothesis), field 1 = SubclassID
    data = w.decode([0, 1, 3, 4])
    print("total decoded ids:", len(data))
    # sanity: palette sizes
    print("ClassID palette entries:", w.storage[0]['additional_data_size']//4)
    print("InvType palette entries:", w.storage[3]['additional_data_size']//4)
    # count by class
    cls_counter = Counter(v[0] for v in data.values())
    print("\n== ClassID distribution ==")
    for c in sorted(cls_counter):
        print(f"  class {c:2d} {CLASSNAME.get(c,'?'):16s} = {cls_counter[c]}")
    # invtype distribution overall
    inv_counter = Counter(v[3] for v in data.values())
    print("\n== InventoryType distribution (all classes) ==")
    for it in sorted(inv_counter):
        print(f"  inv {it:2d} {INVTYPE.get(it,'?'):14s} = {inv_counter[it]}")
    # per class per invtype for class 2 & 4
    print("\n== Class 2 (Weapon) by InventoryType ==")
    c2 = Counter(v[3] for v in data.values() if v[0]==2)
    for it in sorted(c2): print(f"  inv {it:2d} {INVTYPE.get(it,'?'):14s} = {c2[it]}")
    print("\n== Class 4 (Armor) by InventoryType ==")
    c4 = Counter(v[3] for v in data.values() if v[0]==4)
    for it in sorted(c4): print(f"  inv {it:2d} {INVTYPE.get(it,'?'):14s} = {c4[it]}")
    # save id->class/sub/inv mapping for join
    import json
    with open(os.path.join(os.path.dirname(__file__),'_item_map.json'),'w') as f:
        json.dump({str(k):[v[0],v[1],v[3]] for k,v in data.items()}, f)
    print("\nwrote _item_map.json")
