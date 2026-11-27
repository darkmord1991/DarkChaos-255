#!/usr/bin/env python3
# Port Deepholm quest-credit smart_scripts from Neltharion 4.3.4 (29-col) -> DC fork (31-col).
import re
F=r"K:/Dark-Chaos/cata stuff/Project-Neltharion-4.3.4-Cataclysm/world.sql"
OUT=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/21_quest_credit_scripts.sql"
CREDIT={42466,43805,44900,45083,46139,44281,44772,44133,44938,44051,53744,43388,44218,44229,
 43164,43165,43166,43167,43978,44290,43597,43649,43027,43028,43029,43038,43640,45091,44135,44228,42465,44025,44768}
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
# collect all smart_scripts tuples
allrows=[];collecting=False;buf=''
for line in open(F,encoding='utf-8',errors='replace'):
    if not collecting and 'INTO `smart_scripts`' in line: collecting=True;buf=line
    elif collecting: buf+=line
    if collecting and line.rstrip().endswith(';'):
        vi=buf.upper().find('VALUES')
        for fl in pt(buf[vi+6:]):
            if len(fl)>=29: allrows.append(fl[:29])
        collecting=False;buf=''

def eog(fl):
    try: return int(fl[0])
    except: return None
def st(fl):
    try: return int(fl[1])
    except: return -1
# pass1: source_type 0 rows for credit creatures
src0=[fl for fl in allrows if st(fl)==0 and eog(fl) in CREDIT]
# find referenced timed_actionlist ids (action_type 80 -> action_param1)
allist=set()
for fl in src0:
    if int(fl[12])==80:
        try: allist.add(int(fl[13]))
        except: pass
# pass2: source_type 9 (timed actionlist) rows whose entryorguid is a referenced list
src9=[fl for fl in allrows if st(fl)==9 and eog(fl) in allist]
rows=src0+src9

# collect spells referenced (SPELLHIT ep1; CAST/INVOKER_CAST/REMOVE_AURA/ADD_AURA ap1)
spells=set()
for fl in rows:
    et=int(fl[4]); at=int(fl[12])
    if et in (8,31): # SPELLHIT / SPELLHIT_TARGET -> event_param1 = spell
        try: spells.add(int(fl[8]))
        except: pass
    if at in (11,85,28,75,77): # CAST, INVOKER_CAST, REMOVE_AURA, ADD_AURA, ...
        try: spells.add(int(fl[13]))
        except: pass
spells.discard(0)

# remap 29 -> 31 (insert event_param5=0, event_param6=0 after index 11)
def to_dc(fl):
    return fl[0:12] + ['0','0'] + fl[12:29]
def sqlval(v):
    v=v.strip()
    if v.upper()=='NULL': return '0'
    if v.startswith("'"): return v  # quoted comment
    return v
with open(OUT,'w',encoding='utf-8',newline='\n') as f:
    f.write("-- =====================================================================\n")
    f.write("-- Deepholm Downport  --  21  Quest-credit SmartAI (ported from Neltharion 4.3.4)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- The flagged quest credits the TDB lacked, ported from the fully-scripted\n")
    f.write("-- Neltharion 4.3.4 repack (our exact entry ids). 29-col -> DC 31-col remap\n")
    f.write("-- (event_param5/6 inserted = 0). Includes the creatures' timed_actionlists.\n")
    f.write("-- Trigger/cast spells these reference are added by 22_credit_spells (extracted\n")
    f.write("-- from the Cata client). Supersedes the flagged placeholders in 18.\n")
    f.write("-- =====================================================================\n\n")
    cl=",".join(str(e) for e in sorted(CREDIT))
    f.write("UPDATE `creature_template` SET `AIName`='SmartAI' WHERE `entry` IN ("+cl+") AND (`AIName`='' OR `AIName` IS NULL);\n\n")
    f.write("DELETE FROM `smart_scripts` WHERE (`source_type`=0 AND `entryorguid` IN ("+cl+"))\n")
    f.write("  OR (`source_type`=9 AND `entryorguid` IN ("+",".join(str(x) for x in sorted(allist))+"));\n\n")
    f.write("INSERT INTO `smart_scripts` (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES\n")
    out=[]
    for fl in sorted(rows,key=lambda r:(st(r),eog(r),int(r[2]) if r[2].lstrip('-').isdigit() else 0)):
        dc=to_dc(fl)
        out.append("("+",".join(sqlval(v) for v in dc)+")")
    f.write(",\n".join(out)+";\n")
print("source_type0 rows:",len(src0)," timed_actionlists:",len(allist)," source_type9 rows:",len(src9)," total:",len(rows))
print("referenced spells (",len(spells),"):",sorted(spells))
open(r"k:/tmp/credit_spells.txt","w").write(",".join(str(s) for s in sorted(spells)))
print("OUT:",OUT)
