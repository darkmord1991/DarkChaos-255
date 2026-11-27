#!/usr/bin/env python3
# Downport the Deepholm LOOT + extra quest items that cause "references non-existent item" DB errors.
# class/subclass/invtype/material/sheath/displayid from Cata Item.db2 (authoritative, all present);
# name/quality/levels/prices/bonding from retail ItemSparse.csv. None are gear (no stats needed).
import struct, csv

SPARSE_CSV=r"C:/Users/flori/wow.export/ItemSparse.csv"
FORK_IDI=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/ItemDisplayInfo.csv"
DEST=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm"
OUT_SQL=DEST+"/03c_loot_extra_items.sql"
OUT_IDI=DEST+"/03d_itemdisplayinfo_loot_additions.csv"

LOOT=[52185,52197,52325,52326,52327,52328,52329,52363,52364,52365,52366,52367,52368,52369,52370,52371,52372,52373,52374,52375,52376,52377,52378,52379,52382,52383,52385,52386,52388,52494,52495,52496,52506,52983,52986,53010,53038,53062,53065,53068,58256,58258,58260,58268,58269,58962,60388,60389,60398,60399,60486,60739,60768,60809,62276,62277,62413,62414,62421,62435,62518,62519,62520,62521,62522,62523,62524,62527,62778,62782,62783,63122,63291,63310,63316,63317,63318,63348,64494,65504,65650,65894,65895,65896,65897,67282,67495,67539,68197,68198,68729,68781,68782,68783,68787,68788,68789,69772,69820]
QUEST_EXTRA=[58783]
IDS=sorted(set(LOOT)|set(QUEST_EXTRA))

# Cata Item.db2 (WDB2): ID(0) Class(1) Sub(2) Material(4) DisplayInfoID(5) InvType(6) Sheathe(7)
d=open('k:/tmp/cata-dbc/Item.db2','rb').read(); rc,fc,rs,ss=struct.unpack('<4I',d[4:20]); B=48
def gi(o): return struct.unpack('<i',d[o:o+4])[0]
cata={}
for r in range(rc):
    o=B+r*rs; cata[gi(o)]={'cls':gi(o+4),'sub':gi(o+8),'mat':gi(o+16),'disp':gi(o+20),'inv':gi(o+24),'sheath':gi(o+28)}

# retail ItemSparse -> name/quality/levels/prices/bonding/startquest
sp={}
want=set(IDS)
with open(SPARSE_CSV,encoding='utf-8',newline='') as f:
    for row in csv.DictReader(f,delimiter=';'):
        try: i=int(row['ID'])
        except: continue
        if i in want: sp[i]=row
def iget(d_,k,dft=0):
    v=(d_ or {}).get(k,'')
    if v in (None,''): return dft
    try: return int(float(v))
    except: return dft
def esc(s): return (s or '').replace('\\','\\\\').replace("'","''")

rows=[]; no_sparse=[]; no_cata=[]
for i in IDS:
    c=cata.get(i)
    if not c: no_cata.append(i); continue
    s=sp.get(i)
    if not s: no_sparse.append(i)
    name=esc((s or {}).get('Display_lang','') ) or ('Item '+str(i))
    q=iget(s,'OverallQualityID',1); il=iget(s,'ItemLevel'); rl=iget(s,'RequiredLevel')
    st=iget(s,'Stackable') or 1; mc=iget(s,'MaxCount'); bp=iget(s,'BuyPrice'); spr=iget(s,'SellPrice')
    bd=iget(s,'Bonding'); stq=iget(s,'StartQuestID')
    rows.append("({e},{cls},{sub},'{nm}',{disp},{q},0,1,{bp},{sp},{inv},{il},{rl},{mc},{st},{bd},{stq},{mat},{sh},0)".format(
        e=i,cls=c['cls'],sub=c['sub'],nm=name,disp=c['disp'],q=q,bp=bp,sp=spr,inv=c['inv'],
        il=il,rl=rl,mc=mc,st=st,bd=bd,stq=stq,mat=c['mat'],sh=c['sheath']))

idlist=",".join(str(i) for i in IDS)
with open(OUT_SQL,'w',encoding='utf-8',newline='\n') as f:
    f.write("""-- =====================================================================
-- Deepholm Downport  --  03c  Loot + extra quest items (DB-error fix)
-- ---------------------------------------------------------------------
-- Fixes acore_world load errors: Deepholm creature/reference/skinning/GO loot
-- tables + a few quest columns reference these items, which were absent from
-- item_template ("references non-existent item X" -> dropped from loot).
-- class/subclass/invType/material/sheath/displayid from the Cata 4.3.4 Item.db2;
-- name/quality/levels/prices/bonding from retail ItemSparse. All are non-gear
-- (TradeGoods/Recipe/Misc/Consumable/Quest/Key) -> no stats needed.
-- NOTE: Recipe-class items exist (error fixed) but won't teach a craft until a
-- recipe spell + RequiredSkill is linked (separate profession track).
-- =====================================================================

DELETE FROM `item_template` WHERE `entry` IN ("""+idlist+""");

INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,
 `InventoryType`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`startquest`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
""")
    f.write(",\n".join(rows)+";\n")

# ItemDisplayInfo additions for displayids not already in fork
with open(FORK_IDI,encoding='utf-8') as f:
    rd=csv.reader(f); idi_header=next(rd); fork_idi={int(r[0]) for r in rd if r and r[0].strip().isdigit()}
need=sorted({cata[i]['disp'] for i in IDS if cata.get(i,{}).get('disp',0)>0} - fork_idi)
dd=open('k:/tmp/cata-dbc/ItemDisplayInfo.dbc','rb').read()
RC,FC,RS,SS=struct.unpack('<4I',dd[4:20]); BASE=20; STR=20+RC*RS
STRF={1,2,3,4,5,6,15,16,17,18,19,20,21,22}
def ds(off):
    if off==0: return ""
    e=dd.index(b'\x00',STR+off); return dd[STR+off:e].decode('utf-8','replace')
def df(rec,idx): return struct.unpack('<i',dd[BASE+rec*RS+idx*4:BASE+rec*RS+idx*4+4])[0]
byid={df(r,0):r for r in range(RC)}
idi_rows=[]
for did in need:
    if did not in byid: continue
    r=byid[did]; idi_rows.append([ds(df(r,c)) if c in STRF else str(df(r,c)) for c in range(25)])
with open(OUT_IDI,'w',encoding='utf-8',newline='') as f:
    w=csv.writer(f,quoting=csv.QUOTE_ALL); w.writerow(idi_header)
    for r in idi_rows: w.writerow(r)

print(f"item rows: {len(rows)}  | not in Cata Item.db2: {no_cata}  | not in retail ItemSparse (name fallback used): {no_sparse}")
print(f"ItemDisplayInfo: {len(need)} displayids missing from fork -> {len(idi_rows)} rows generated")
print("OUT:", OUT_SQL, "/", OUT_IDI)
