#!/usr/bin/env python3
# Parse Cata 4.3.4 Spell.dbc + SpellEffect.dbc and dump the Deepholm spells.
import struct
DBC="k:/tmp/cata-dbc/"
LOC="k:/tmp/cata-locale/"
TARGET=[93544,93545,93546,93553,93554,93556,95385,93425,100168,100562,84069,84153,83483]

def load(path):
    with open(path,'rb') as f: d=f.read()
    assert d[:4]==b'WDBC', path
    rc,fc,rs,ss=struct.unpack('<4I', d[4:20])
    base=20; strbase=base+rc*rs
    return d, rc, fc, rs, base, strbase

def s(d, strbase, off):  # read C-string at string-block offset
    e=d.index(b'\x00', strbase+off)
    return d[strbase+off:e].decode('utf-8','replace')

# Spell.dbc 48 fields
SP_NAME=21; SP_SCHOOL=25; SP_CAST=12; SP_DUR=13; SP_PWR=14; SP_RANGE=15
def field(d, base, rs, rec, idx, fmt='<i'):
    return struct.unpack(fmt, d[base+rec*rs+idx*4: base+rec*rs+idx*4+4])[0]

sd, src, sfc, srs, sbase, sstr = load(DBC+"Spell.dbc")
spell_row={}
for r in range(src):
    rid=field(sd, sbase, srs, r, 0)
    if rid in TARGET: spell_row[rid]=r

# SpellEffect grouped by SpellID(24), index(25)
ed, erc, efc, ers, ebase, estr = load(DBC+"SpellEffect.dbc")
eff_by_spell={}
for r in range(erc):
    sid=field(ed, ebase, ers, r, 24)
    if sid in TARGET:
        eff_by_spell.setdefault(sid,[]).append(r)

# SpellDuration resolve
def load_idx(path, valfield):
    try: d,rc,fc,rs,base,strb=load(path)
    except Exception: return {}
    m={}
    for r in range(rc):
        rid=struct.unpack('<i', d[base+r*rs:base+r*rs+4])[0]
        m[rid]=struct.unpack('<i', d[base+r*rs+valfield*4:base+r*rs+valfield*4+4])[0]
    return m
dur=load_idx(LOC+"SpellDuration.dbc",1)
cast=load_idx(LOC+"SpellCastTimes.dbc",1)

EFF={0:'NONE',1:'INSTAKILL',2:'SCHOOL_DAMAGE',3:'DUMMY',6:'APPLY_AURA',8:'POWER_DRAIN',10:'HEAL',24:'CREATE_ITEM',27:'PERSISTENT_AREA_AURA',28:'SUMMON',30:'ENERGIZE',35:'APPLY_AREA_AURA_PARTY',36:'LEARN_SPELL',38:'DISPEL',64:'TRIGGER_SPELL',77:'SCRIPT_EFFECT',79:'???',86:'ACTIVATE_OBJECT',119:'APPLY_AREA_AURA_RAID'}
AUR={0:'',3:'PERIODIC_DAMAGE',4:'DUMMY',8:'PERIODIC_HEAL',23:'PERIODIC_TRIGGER_SPELL',26:'MOD_STUN',33:'MOD_DECREASE_SPEED',79:'MOD_DAMAGE_PERCENT_DONE',201:'ENABLE_FLIGHT',226:'PERIODIC_DUMMY'}
for sid in TARGET:
    if sid not in spell_row: print(f"[{sid}] MISSING in Spell.dbc"); continue
    r=spell_row[sid]
    name=s(sd, sstr, field(sd,sbase,srs,r,SP_NAME))
    school=field(sd,sbase,srs,r,SP_SCHOOL)
    ci=field(sd,sbase,srs,r,SP_CAST); di=field(sd,sbase,srs,r,SP_DUR); ri=field(sd,sbase,srs,r,SP_RANGE)
    pwr=field(sd,sbase,srs,r,SP_PWR); spd=field(sd,sbase,srs,r,16,'<f')
    print(f"\n=== [{sid}] {name!r}  school={school} cast={cast.get(ci,'?')}ms dur={dur.get(di,'?')}ms rangeIdx={ri} pwr={pwr} speed={spd:g}")
    for er in sorted(eff_by_spell.get(sid,[]), key=lambda x: field(ed,ebase,ers,x,25)):
        ei=field(ed,ebase,ers,er,25)
        eff=field(ed,ebase,ers,er,1); aura=field(ed,ebase,ers,er,3)
        bp=field(ed,ebase,ers,er,5); ap=field(ed,ebase,ers,er,4)
        mv0=field(ed,ebase,ers,er,12); mv1=field(ed,ebase,ers,er,13)
        rad0=field(ed,ebase,ers,er,15); trig=field(ed,ebase,ers,er,21)
        ta=field(ed,ebase,ers,er,22); tb=field(ed,ebase,ers,er,23)
        ct=field(ed,ebase,ers,er,8); die=field(ed,ebase,ers,er,9)
        print(f"   eff{ei}: {EFF.get(eff,eff)}({eff}) aura={AUR.get(aura,aura)}({aura}) bp={bp} die={die} ampPeriod={ap} misc={mv0}/{mv1} radIdx={rad0} chainTgt={ct} trig={trig} tgtA={ta} tgtB={tb}")
