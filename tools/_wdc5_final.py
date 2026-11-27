#!/usr/bin/env python3
"""Final consolidated per-slot appearance breakdown.
   Primary = exact matched (Item.db2 join). Plus scaled-to-total estimate."""
import os, sys
from collections import Counter, defaultdict
sys.path.insert(0, os.path.dirname(__file__))
from _wdc5_ima import decode_all
from _wdc5_decode import WDC5, INVTYPE

DBC = "K:/Dark-Chaos/WoW server data/11.1.7 TC/dbc/deDE/"

w_item = WDC5(os.path.join(DBC, 'Item.db2'))
item_map = w_item.decode([0, 1, 3])
item_ci = {iid: (v[0], v[3]) for iid, v in item_map.items()}

_, ima_rows = decode_all('ItemModifiedAppearance.db2', [1, 3])
app_slots = defaultdict(Counter)
all_apps = set()
for rid, vals, relval in ima_rows:
    appid = vals.get(3)
    itemid = vals.get(1)
    if appid == 0:
        continue
    all_apps.add(appid)
    ci = item_ci.get(itemid)
    if ci:
        app_slots[appid][(ci[0], ci[1])] += 1

TRACK_A = {1, 3, 13, 14, 15, 17, 21, 22, 23, 25, 26, 28}
TRACK_B = {4, 5, 6, 7, 8, 9, 10, 16, 19, 20}

def track_of(inv):
    if inv in TRACK_A: return 'A'
    if inv in TRACK_B: return 'B'
    return 'N/A'

invtype_app = defaultdict(set)
for appid, ctr in app_slots.items():
    if not ctr:
        continue
    (cls, inv), _ = ctr.most_common(1)[0]
    invtype_app[inv].add(appid)

total_matched = sum(len(s) for s in invtype_app.values())
total_referenced = len(all_apps)
scale = total_referenced / total_matched

print(f"total referenced appearances (IMA) = {total_referenced}")
print(f"matched-to-slot via Item.db2       = {total_matched}")
print(f"scale factor (total/matched)       = {scale:.3f}")
print()
print(f"{'inv':>3} {'slot':14} {'trk':3} {'matched':>8} {'scaled_est':>10}")
tA_m = tB_m = tNA_m = 0
tA_s = tB_s = tNA_s = 0
for inv in sorted(invtype_app):
    m = len(invtype_app[inv])
    s = round(m * scale)
    t = track_of(inv)
    print(f"{inv:3d} {INVTYPE.get(inv,'?'):14} {t:3} {m:8d} {s:10d}")
    if t == 'A': tA_m += m; tA_s += s
    elif t == 'B': tB_m += m; tB_s += s
    else: tNA_m += m; tNA_s += s
print()
print(f"TRACK A matched={tA_m} scaled={tA_s}")
print(f"TRACK B matched={tB_m} scaled={tB_s}")
print(f"N/A    matched={tNA_m} scaled={tNA_s}")
print(f"A+B    matched={tA_m+tB_m} scaled={tA_s+tB_s}")
