#!/usr/bin/env python3
# Build the missing ItemDisplayInfo rows for the 53 Deepholm items, from Cata ItemDisplayInfo.dbc.
import struct, csv

QUEST=[58168,58169,58177,58254,58500,58501,58502,58845,58884,58885,58886,58944,58959,58965,
 59062,59123,59144,59323,60264,60266,60297,60382,60383,60487,60490,60501,60504,60574,60575,
 60745,60758,60767,60773,60791,60810,60814,60816,60831,60834,60835,60837,61399,61437,61440,64404]
VENDOR=[62321,62333,62342,62343,62344,62345,62346,62347]
TARGET=QUEST+VENDOR
FORK="K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/ItemDisplayInfo.csv"
OUT="k:/tmp/itemdisplayinfo_review.csv"

# item -> displayid (Cata Item.db2 WDB2)
d=open('k:/tmp/cata-dbc/Item.db2','rb').read(); rc,fc,rs,ss=struct.unpack('<4I',d[4:20]); B=48
disp_of={ struct.unpack('<i',d[B+r*rs:B+r*rs+4])[0]: struct.unpack('<i',d[B+r*rs+20:B+r*rs+24])[0] for r in range(rc) }

# fork existing display ids + header
with open(FORK,encoding='utf-8') as f:
    rdr=csv.reader(f); header=next(rdr); fork_ids={int(r[0]) for r in rdr if r and r[0].strip().isdigit()}

want=sorted({disp_of[i] for i in TARGET if disp_of.get(i,0)>0} - fork_ids)
print("missing unique display ids:", want)

# Cata ItemDisplayInfo.dbc (WDBC, 25 fields). string fields (0-based): 1,2,3,4,5,6,15..22
dd=open('k:/tmp/cata-dbc/ItemDisplayInfo.dbc','rb').read()
RC,FC,RS,SS=struct.unpack('<4I',dd[4:20]); BASE=20; STR=20+RC*RS
STRFIELDS={1,2,3,4,5,6,15,16,17,18,19,20,21,22}
def cstr(off):
    if off==0: return ""
    e=dd.index(b'\x00',STR+off); return dd[STR+off:e].decode('utf-8','replace')
def fld(rec,idx): return struct.unpack('<i',dd[BASE+rec*RS+idx*4:BASE+rec*RS+idx*4+4])[0]

byid={ fld(r,0):r for r in range(RC) }
rows=[]
for did in want:
    if did not in byid: print("  !! display",did,"not in Cata ItemDisplayInfo"); continue
    r=byid[did]
    out=[]
    for c in range(25):
        out.append(cstr(fld(r,c)) if c in STRFIELDS else str(fld(r,c)))
    rows.append(out)

with open(OUT,'w',encoding='utf-8',newline='') as f:
    w=csv.writer(f,quoting=csv.QUOTE_ALL); w.writerow(header)
    for r in rows: w.writerow(r)
print(f"\ngenerated {len(rows)} ItemDisplayInfo rows -> {OUT}")
for r in rows: print(f"  {r[0]:>7}  icon={r[5]!r}  model={r[1]!r}")
