#!/usr/bin/env python3
# Downport Cata 4.3.4 spells -> 3.3.5 monolithic Spell.csv rows (fork CSV-DBC format).
import struct, csv, io

CATA = "k:/tmp/cata-dbc/"      # Spell.dbc, SpellEffect.dbc (from 15601, full)
LOC  = "k:/tmp/cata-locale/"   # Cata index tables (SpellRange/Duration/CastTimes/Radius)
LIVE = "K:/Dark-Chaos/Server/data/dbc/"  # 3.3.5 index tables
FORK_HEADER = "K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/Spell.csv"
OUT = "k:/tmp/deepholm_spells_review.csv"

TARGET = [81778,82238,85807,88334,98782,100807]
TOTAL_SPELL_EFFECTS = 165   # 3.3.5 fork limit: effects >= this crash LoadSpellInfoStore
TOTAL_AURAS = 317           # 3.3.5 fork limit: auras >= this crash
NAME_MASK = 16712190

def load(path):
    with open(path,'rb') as f: d=f.read()
    assert d[:4]==b'WDBC', path
    rc,fc,rs,ss=struct.unpack('<4I', d[4:20])
    return d, rc, fc, rs, 20, 20+rc*rs

def i32(d,base,rs,rec,idx): return struct.unpack('<i', d[base+rec*rs+idx*4:base+rec*rs+idx*4+4])[0]
def f32(d,base,rs,rec,idx): return struct.unpack('<f', d[base+rec*rs+idx*4:base+rec*rs+idx*4+4])[0]
def u32(d,base,rs,rec,idx): return struct.unpack('<I', d[base+rec*rs+idx*4:base+rec*rs+idx*4+4])[0]  # flag/unsigned fields
def cstr(d,strbase,off):
    e=d.index(b'\x00', strbase+off); return d[strbase+off:e].decode('utf-8','replace')

# ---- index remap (Cata idx -> 3.3.5 idx, matched by value) ----
def idx_values(path, valfield, asfloat=False):
    d,rc,fc,rs,base,_=load(path); m={}
    for r in range(rc):
        rid=i32(d,base,rs,r,0)
        m[rid]=(f32(d,base,rs,r,valfield) if asfloat else i32(d,base,rs,r,valfield))
    return m
def make_remap(cata_path, live_path, vf_cata, vf_live, asfloat):
    cv=idx_values(cata_path,vf_cata,asfloat); lv=idx_values(live_path,vf_live,asfloat)
    val2idx={}
    for i,v in sorted(lv.items()):
        key=round(v,2)
        if key not in val2idx: val2idx[key]=i
    def remap(ci):
        if ci==0: return 0
        cvval=cv.get(ci)
        if ci in lv and cvval is not None and abs(lv[ci]-cvval)<0.05: return ci   # same idx, same value
        if cvval is None: return ci if ci in lv else 0
        key=round(cvval,2)
        if key in val2idx: return val2idx[key]
        best=min(lv.items(), key=lambda kv: abs(kv[1]-cvval)); return best[0]
    return remap, cv, lv
remap_cast,_,_   = make_remap(LOC+"SpellCastTimes.dbc", LIVE+"SpellCastTimes.dbc", 1,1, False)
remap_dur,_,_    = make_remap(LOC+"SpellDuration.dbc",  LIVE+"SpellDuration.dbc",  1,1, False)
remap_range,_,_  = make_remap(LOC+"SpellRange.dbc",     LIVE+"SpellRange.dbc",     3,3, True)
remap_radius,_,_ = make_remap(LOC+"SpellRadius.dbc",    LIVE+"SpellRadius.dbc",    1,1, True)

# ---- parse Cata Spell.dbc + SpellEffect.dbc ----
sd,src,sfc,srs,sbase,sstr=load(CATA+"Spell.dbc")
spell={}
for r in range(src):
    rid=i32(sd,sbase,srs,r,0)
    if rid in TARGET: spell[rid]=r
ed,erc,efc,ers,ebase,estr=load(CATA+"SpellEffect.dbc")
effs={}
for r in range(erc):
    sid=i32(ed,ebase,ers,r,24)
    if sid in TARGET: effs.setdefault(sid,{})[i32(ed,ebase,ers,r,25)]=r

# fork header -> column count
with open(FORK_HEADER,encoding='utf-8') as f: header=next(csv.reader(f))
NCOL=len(header)

def fnum(x):
    if isinstance(x,float):
        return str(int(x)) if x==int(x) else repr(round(x,6))
    return str(x)

rows=[]; report=[]
for sid in TARGET:
    if sid not in spell: report.append(f"  [{sid}] MISSING in Spell.dbc -- skipped"); continue
    r=spell[sid]
    col=["0"]*NCOL
    def S(c,v): col[c-1]=fnum(v)        # 1-indexed column setter
    S(1,sid)
    # attributes: Cata fields 1..8 -> cols 5..12  (UNSIGNED: flag fields can have bit 31 set)
    for k in range(8): S(5+k, u32(sd,sbase,srs,r,1+k))
    S(27, remap_cast(i32(sd,sbase,srs,r,12)))
    S(39, remap_dur (i32(sd,sbase,srs,r,13)))
    S(40, i32(sd,sbase,srs,r,14))                 # PowerType
    S(45, remap_range(i32(sd,sbase,srs,r,15)))
    S(46, f32(sd,sbase,srs,r,16))                 # Speed
    S(67,-1)                                       # EquippedItemClass = none
    school=u32(sd,sbase,srs,r,25); S(224, school)
    has_dmg=False
    for e in range(3):
        if e in effs.get(sid,{}):
            er=effs[sid][e]
            eff=i32(ed,ebase,ers,er,1)
            if eff>=TOTAL_SPELL_EFFECTS: eff=0            # clamp Cata-only effect ids (else server assert/crash)
            if eff==2: has_dmg=True
            S(70+e, eff)                                  # Effect
            S(73+e, i32(ed,ebase,ers,er,9))               # DieSides
            S(76+e, f32(ed,ebase,ers,er,17))              # RealPointsPerLevel
            S(79+e, i32(ed,ebase,ers,er,5))               # BasePoints
            S(82+e, i32(ed,ebase,ers,er,11))              # Mechanic
            S(85+e, i32(ed,ebase,ers,er,22))              # ImplicitTargetA
            S(88+e, i32(ed,ebase,ers,er,23))              # ImplicitTargetB
            S(91+e, remap_radius(i32(ed,ebase,ers,er,15)))# RadiusIndex
            _au=i32(ed,ebase,ers,er,3)
            S(94+e, _au if _au<TOTAL_AURAS else 0)         # Aura (clamp Cata-only aura ids)
            S(97+e, i32(ed,ebase,ers,er,4))               # AuraPeriod
            S(103+e, i32(ed,ebase,ers,er,8))              # ChainTargets
            S(106+e, i32(ed,ebase,ers,er,10))             # ItemType
            S(109+e, i32(ed,ebase,ers,er,12))             # MiscValue
            S(112+e, i32(ed,ebase,ers,er,13))             # MiscValueB
            S(115+e, i32(ed,ebase,ers,er,21))             # TriggerSpell
            S(121+e, u32(ed,ebase,ers,er,18))             # ClassMaskA (flags)
            S(124+e, u32(ed,ebase,ers,er,19))             # ClassMaskB (flags)
            S(127+e, u32(ed,ebase,ers,er,20))             # ClassMaskC (flags)
            S(215+e, f32(ed,ebase,ers,er,7))              # ChainAmplitude
    name=cstr(sd,sstr, i32(sd,sbase,srs,r,21))
    S(135, name); S(151, NAME_MASK)
    if has_dmg: S(212, 2 if school==1 else 1)             # DefenseType (melee/magic)
    rows.append(col)
    neff=len(effs.get(sid,{}))
    report.append(f"  [{sid}] {name!r:50s} school={school} effects={neff} cols={len(col)}")

with open(OUT,'w',encoding='utf-8',newline='') as f:
    w=csv.writer(f, quoting=csv.QUOTE_ALL)
    w.writerow(header)
    for row in rows: w.writerow(row)

print(f"generated {len(rows)} spell rows ({NCOL} cols each) -> {OUT}\n")
print("\n".join(report))
