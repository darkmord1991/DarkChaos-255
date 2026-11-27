#!/usr/bin/env python3
import re
F=r"K:/Dark-Chaos/cata stuff/Project-Neltharion-4.3.4-Cataclysm/world.sql"
OUT=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/23_gameobject_densify.sql"
GUID0=9330001
EXCLUDE={301074,301075,181355}  # Neltharion-custom + seasonal Midsummer Brazier
OUR_GO=set(int(x) for x in "191707,202736,202738,202739,202741,202747,202750,202778,203748,203749,203750,204045,204253,204274,204296,204297,204343,204348,204374,204375,204376,204377,204378,204390,204391,204392,204407,204410,204420,204575,204576,204577,204837,204946,204947,204948,204959,204967,204968,205081,205097,205098,205102,205110,205111,205112,205113,205115,205116,205119,205120,205121,205122,205125,205126,205127,205128,205129,205130,205131,205133,205134,205145,205146,205147,205151,205152,205161,205193,205195,205196,205197,205205,205206,205207,205208,205272,205273,205359,205361,205386,205565,206562,206980,206981,206982,206983,206984,207390,207494,207518,207593,207597,207897,207900,208256,208257,208258,208259,208260,208261".split(','))
def pt(data):
    i=0;n=len(data)
    while i<n:
        if data[i]=='(':
            i+=1;f=[];cur='';d=0;q=False
            while i<n:
                c=data[i]
                if q:
                    if c=="'":
                        if i+1<n and data[i+1]=="'":cur+="''";i+=2;continue
                        q=False;cur+=c;i+=1;continue
                    cur+=c;i+=1;continue
                if c=="'":q=True;cur+=c;i+=1;continue
                if c=='(':d+=1;cur+=c;i+=1;continue
                if c==')':
                    if d==0:f.append(cur);i+=1;break
                    d-=1;cur+=c;i+=1;continue
                if c==',' and d==0:f.append(cur);cur='';i+=1;continue
                cur+=c;i+=1
            yield [x.strip() for x in f]
        else:i+=1
def scan(table):
    out=[];collecting=False;buf=''
    for line in open(F,encoding='utf-8',errors='replace'):
        if not collecting and ('INTO `%s`'%table) in line: collecting=True;buf=line
        elif collecting: buf+=line
        if collecting and line.rstrip().endswith(';'):
            vi=buf.upper().find('VALUES')
            for fl in pt(buf[vi+6:]): out.append(fl)
            collecting=False;buf=''
    return out
# templates: id -> fields
tmpl={}
for fl in scan('gameobject_template'):
    try: tmpl[int(fl[0])]=fl
    except: pass
# Neltharion template index: 0 entry,1 type,2 displayId,3 name,4 IconName,5 castBarCaption,6 unk1,7 faction,8 flags,9 size,10-15 questItem,16-39 data0-23,...,49 AIName,50 ScriptName
def gtype(i):
    fl=tmpl.get(i); return int(fl[1]) if fl and fl[1].lstrip('-').isdigit() else -1
# placements (map 646)
placements=[]
for fl in scan('gameobject'):
    try:
        if len(fl)>=18 and int(fl[2])==646: placements.append(fl)
    except: pass
inc=[]; need_tmpl=set()
for fl in placements:
    gid=int(fl[1])
    if gid in EXCLUDE: continue
    t=gtype(gid)
    if gid in OUR_GO:
        if t==5: inc.append(fl)            # decoration density of a type we already have
    elif gid in tmpl:
        inc.append(fl); need_tmpl.add(gid) # genuinely missing GO type (template available)
    # else: spawn-only quirk with no template in Neltharion -> skip
print("included placements:",len(inc)," (missing-type templates to add:",len(need_tmpl),")")
from collections import Counter
print("by category: deco-shared(type5)=",sum(1 for fl in inc if int(fl[1]) in OUR_GO)," missing-type=",sum(1 for fl in inc if int(fl[1]) not in OUR_GO))

def q(v):
    v=v.strip()
    return v if v.startswith("'") else (v if v.upper()!='NULL' else '0')
with open(OUT,'w',encoding='utf-8',newline='\n') as f:
    f.write("-- =====================================================================\n")
    f.write("-- Deepholm Downport  --  23  Gameobject densify (from Neltharion 4.3.4)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- Supplements the world with Neltharion's richer GO placement: decoration\n")
    f.write("-- GOs (type 5) of types we already have + genuinely-missing GO types.\n")
    f.write("-- EXCLUDES Neltharion-custom (301xxx), seasonal (Midsummer Brazier), and\n")
    f.write("-- shared FUNCTIONAL types (doors/chests/quest objects we already imported)\n")
    f.write("-- to avoid duplicating interactive objects. New guid block 9,330,001+.\n")
    f.write("-- phaseMask=1 (always visible). Missing-type displayIds may need a bake.\n")
    f.write("-- =====================================================================\n\n")
    # templates for missing types (Neltharion -> our 35-col schema)
    if need_tmpl:
        idl=",".join(str(i) for i in sorted(need_tmpl))
        f.write("DELETE FROM `gameobject_template` WHERE `entry` IN ("+idl+");\n")
        f.write("INSERT INTO `gameobject_template` (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`) VALUES\n")
        trows=[]
        for i in sorted(need_tmpl):
            fl=tmpl[i]
            vals=[fl[0],fl[1],fl[2],q(fl[3]),q(fl[4]),q(fl[5]),fl[6],fl[9]]+[fl[16+k] for k in range(24)]+["''","''","0"]
            trows.append("("+",".join(q(str(v)) for v in vals)+")")
        f.write(",\n".join(trows)+";\n\n")
    # placements
    f.write("DELETE FROM `gameobject` WHERE `guid` BETWEEN %d AND %d;\n"%(GUID0,GUID0+len(inc)+10))
    f.write("INSERT INTO `gameobject` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`) VALUES\n")
    prows=[];g=GUID0
    for fl in inc:
        # Neltharion: guid0 id1 map2 zone3 area4 spawnMask5 phaseMask6 x7 y8 z9 o10 r0=11 r1=12 r2=13 r3=14 spawntime15 anim16 state17
        prows.append("(%d,%s,646,0,0,1,1,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'',0,'Deepholm densify')"%(
            g,fl[1],fl[7],fl[8],fl[9],fl[10],fl[11],fl[12],fl[13],fl[14],fl[15],fl[16],fl[17]))
        g+=1
    f.write(",\n".join(prows)+";\n")
print("OUT:",OUT," guids %d..%d"%(GUID0,g-1))
