#!/usr/bin/env python3
"""Decode ItemModifiedAppearance + ItemAppearance, join to Item.db2 class/invtype,
   count distinct ItemAppearanceID per slot.  Robust field auto-detection."""
import struct, os, json, sys
from collections import Counter, defaultdict
sys.path.insert(0, os.path.dirname(__file__))
from _wdc5_decode import WDC5, INVTYPE, CLASSNAME, read_bits

DBC = "K:/Dark-Chaos/WoW server data/11.1.7 TC/dbc/deDE/"

def decode_all(name, want_fields, signed=()):
    """Generic decode: returns id->[vals], handling inline-id (flags&4==0 -> id is
    field0 inline OR relationship), id-list, copies, pallet & bitpacked & relationship."""
    w = WDC5(os.path.join(DBC, name))
    d = w.d
    out = {}
    rel_map = {}  # record-global-index -> relationship value (foreign id)
    rows = []     # list of (id, valsdict, rel_value)
    has_idlist_flag = (w.flags & 0x04) != 0
    for sec in w.sections:
        p = sec['file_offset']
        rec_start = p
        p += sec['record_count'] * w.record_size
        p += sec['string_size']
        id_list = []
        if sec['id_list_size']:
            for i in range(sec['id_list_size']//4):
                id_list.append(struct.unpack_from('<I', d, p+i*4)[0])
            p += sec['id_list_size']
        # copy table (byte size)
        copies = []
        if sec['copy_table_count']:
            for i in range(sec['copy_table_count']//8):
                nid, oid = struct.unpack_from('<II', d, p+i*8)
                copies.append((nid, oid));
            p += sec['copy_table_count']
        # relationship data: header uint32 count, uint32 min, uint32 max, then count*(uint32 val, uint32 recidx)
        rel = {}
        if sec['relationship_size']:
            rcount, rmin, rmax = struct.unpack_from('<III', d, p)
            q = p + 12
            for i in range(rcount):
                val, recidx = struct.unpack_from('<II', d, q + i*8)
                rel[recidx] = val
            p += sec['relationship_size']
        # decode records
        for ridx in range(sec['record_count']):
            rbuf = d[rec_start+ridx*w.record_size : rec_start+(ridx+1)*w.record_size]
            vals = {}
            for fid in want_fields:
                st = w.storage[fid]
                raw = read_bits(rbuf, st['offset_bits'], st['size_bits'])
                if st['storage_type'] in (3,4):
                    vals[fid] = w.pallet_value(fid, raw)
                else:
                    # sign-extend if signed_bitpacked (type 5) and want signed
                    if st['storage_type'] == 5 and fid in signed:
                        bits = st['size_bits']
                        if raw & (1 << (bits-1)):
                            raw -= (1 << bits)
                    vals[fid] = raw
            rid = id_list[ridx] if id_list else None
            relval = rel.get(ridx)
            rows.append((rid, vals, relval))
    return w, rows

# ---- ItemModifiedAppearance ----
w_ima, ima_rows = decode_all('ItemModifiedAppearance.db2', [0,1,2,3,4], signed=())
# Inspect ranges of each field to identify ItemID and ItemAppearanceID
print("== IMA field ranges (first 5 fields), record_size=%d, n=%d ==" % (w_ima.record_size, len(ima_rows)))
for fid in range(5):
    vs = [r[1][fid] for r in ima_rows if fid in r[1]]
    print(f"  field[{fid}] min={min(vs)} max={max(vs)} distinct={len(set(vs))}")
relvals = [r[2] for r in ima_rows if r[2] is not None]
if relvals:
    print(f"  relationship: min={min(relvals)} max={max(relvals)} distinct={len(set(relvals))} count={len(relvals)}")
