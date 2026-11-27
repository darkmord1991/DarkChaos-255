#!/usr/bin/env python3
"""Final join: count distinct ItemAppearanceID per (class, InventoryType) slot,
   split into Track A / Track B / N/A."""
import os, sys, json
from collections import Counter, defaultdict
sys.path.insert(0, os.path.dirname(__file__))
from _wdc5_ima import decode_all
from _wdc5_decode import WDC5, INVTYPE, CLASSNAME

DBC = "K:/Dark-Chaos/WoW server data/11.1.7 TC/dbc/deDE/"

# 1. Item.db2 map: itemid -> (class, subclass, invtype)
w_item = WDC5(os.path.join(DBC, 'Item.db2'))
item_map = w_item.decode([0,1,3])   # field0=class, 1=subclass, 3=invtype
item_ci = {iid: (v[0], v[1], v[3]) for iid, v in item_map.items()}
print("Item.db2 ids:", len(item_ci))

# 2. IMA: itemid(field1) -> appearanceid(field3)
_, ima_rows = decode_all('ItemModifiedAppearance.db2', [1,3])
# build appearance -> set of (class,invtype) via its items
app_slots = defaultdict(Counter)     # appid -> Counter[(class,invtype)]
app_to_items = defaultdict(set)
for rid, vals, relval in ima_rows:
    itemid = vals.get(1)
    appid = vals.get(3)
    if appid == 0:
        continue
    app_to_items[appid].add(itemid)
    ci = item_ci.get(itemid)
    if ci:
        app_slots[appid][(ci[0], ci[2])] += 1   # (class, invtype)

print("distinct appearance ids referenced:", len(app_to_items))
matched = sum(1 for a in app_slots if app_slots[a])
print("appearances with a resolvable Item.db2 slot:", matched)

# Assign each appearance to its dominant slot
TRACK_A = {1,3,13,14,15,17,21,22,23,25,26,28}   # model slots (incl head, shoulder)
TRACK_B = {4,5,6,7,8,9,10,16,19,20}             # texture slots (incl cloak)
# N/A appearance slots: 2 neck,11 finger,12 trinket,18 bag,24 ammo,27 quiver

slot_app = defaultdict(set)          # (class,invtype) -> set(appid)
invtype_app = defaultdict(set)       # invtype -> set(appid)  (class-agnostic)
for appid, ctr in app_slots.items():
    if not ctr:
        continue
    (cls, inv), _ = ctr.most_common(1)[0]
    slot_app[(cls, inv)].add(appid)
    invtype_app[inv].add(appid)

print("\n=== Distinct appearances by InventoryType (dominant-slot assignment) ===")
def track_of(inv):
    if inv in TRACK_A: return 'A'
    if inv in TRACK_B: return 'B'
    return 'N/A'
total_by_track = Counter()
for inv in sorted(invtype_app):
    n = len(invtype_app[inv])
    t = track_of(inv)
    total_by_track[t] += n
    print(f"  inv {inv:2d} {INVTYPE.get(inv,'?'):14s} track {t:3s} = {n}")
print("\nTrack totals (appearances):", dict(total_by_track))
print("sum equippable A+B:", total_by_track['A']+total_by_track['B'])

# Class 2 vs Class 4 split per invtype
print("\n=== Appearances by class+invtype ===")
c2 = {inv:len(app) for (c,inv),app in slot_app.items() if c==2}
c4 = {inv:len(app) for (c,inv),app in slot_app.items() if c==4}
print("WEAPON (class2) by inv:")
for inv in sorted(c2): print(f"   inv {inv:2d} {INVTYPE.get(inv,'?'):14s} = {c2[inv]}")
print("ARMOR (class4) by inv:")
for inv in sorted(c4): print(f"   inv {inv:2d} {INVTYPE.get(inv,'?'):14s} = {c4[inv]}")

# also: how many appearances had NO Item.db2 slot (only present in ItemSparse)
unmatched = [a for a in app_to_items if not app_slots.get(a)]
print("\nappearances referenced by IMA but item not in Item.db2 (likely ItemSparse-only):", len(unmatched))
