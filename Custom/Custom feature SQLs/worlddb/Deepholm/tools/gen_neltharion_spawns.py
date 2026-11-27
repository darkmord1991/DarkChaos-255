#!/usr/bin/env python3
# Migrate the Deepholm spawn layer from Project Neltharion 4.3.4 (replaces cata 04/20/23/26-B).
import re
F=r"K:/Dark-Chaos/cata stuff/Project-Neltharion-4.3.4-Cataclysm/world.sql"
OUT=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/30_neltharion_spawn_layer.sql"
CRE=9500000; GO=9600000; PATH=9000000; POOL=9000000
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
def scan(t):
    coll=False;buf=''
    for line in open(F,encoding='utf-8',errors='replace'):
        if not coll and 'INTO `%s`'%t in line: coll=True;buf=line
        elif coll: buf+=line
        if coll and line.rstrip().endswith(';'):
            vi=buf.upper().find('VALUES')
            for fl in pt(buf[vi+6:]): yield fl
            coll=False;buf=''
def num(v):
    v=v.strip()
    return '0' if v.upper()=='NULL' else v
def q(v):  # SQL string literal (Neltharion auras/desc already '' for quotes)
    v=v.strip()
    return v if v.startswith("'") else ("'%s'"%v if v.upper()!='NULL' else 'NULL')

# 1) visible creatures (phaseMask&1)
cre_rows=[]; cre_guids=set()
for fl in scan('creature'):
    try:
        if int(fl[2])!=646 or not(int(fl[6])&1): continue
    except: continue
    g=int(fl[0]); cre_guids.add(g)
    ch=fl[17] if fl[17].strip() not in ('0','NULL','') else '1'
    # equipment_id: Neltharion uses large ids (own scheme); our col is tinyint -> use -1
    # = "load the creature's default equip set" from our (cata-sourced) creature_equip_template.
    cre_rows.append("(%d,%s,646,0,0,%s,1,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'',0,0,'Deepholm-Nel')"%(
        g+CRE, fl[1], num(fl[5]), '-1', num(fl[9]),num(fl[10]),num(fl[11]),num(fl[12]),
        num(fl[13]), num(fl[15]), num(fl[16]), ch, num(fl[18]), num(fl[19]), num(fl[20]), num(fl[21]), num(fl[22])))
# 2) creature_addon for those guids ; collect path ids
addon_rows=[]; paths=set()
for fl in scan('creature_addon'):  # guid0 path1 mount2 bytes1=3 bytes2=4 emote5 distvis6 auras7
    try: g=int(fl[0])
    except: continue
    if g not in cre_guids: continue
    p=int(fl[1]) if fl[1].strip().isdigit() else 0
    if p>0: paths.add(p)
    addon_rows.append("(%d,%s,%s,%s,%s,%s,%s,%s)"%(g+CRE,(str(p+PATH) if p>0 else '0'),num(fl[2]),num(fl[3]),num(fl[4]),num(fl[5]),num(fl[6]),q(fl[7])))
# 3) waypoint_data for those paths
wp_rows=[]
for fl in scan('waypoint_data'):  # id0 point1 x2 y3 z4 o5 delay6 move_flag7 action8 chance9 wpguid10 inv11
    try: pid=int(fl[0])
    except: continue
    if pid not in paths: continue
    wp_rows.append("(%d,%s,%s,%s,%s,%s,0,%s,0,%s,%s,%s,0)"%(pid+PATH,num(fl[1]),num(fl[2]),num(fl[3]),num(fl[4]),num(fl[5]),num(fl[6]),num(fl[7]),num(fl[8]),num(fl[9])))
# 4) pool_creature for those guids ; collect pools
pc_rows=[]; pools=set(); poolmembers={}
for fl in scan('pool_creature'):  # guid0 pool_entry1 chance2 desc3
    try: g=int(fl[0])
    except: continue
    if g not in cre_guids: continue
    pe=int(fl[1]); pools.add(pe); poolmembers[pe]=poolmembers.get(pe,0)+1
    pc_rows.append("(%d,%d,%s,%s)"%(g+CRE,pe+POOL,num(fl[2]),q(fl[3]) if len(fl)>3 else "''"))
# 5) visible gameobjects
go_rows=[]; go_guids=set()
for fl in scan('gameobject'):  # guid0 id1 map2 zone3 area4 spawnMask5 phaseMask6 x7 y8 z9 o10 r0..r3=11-14 spawntime15 anim16 state17
    try:
        if int(fl[2])!=646 or not(int(fl[6])&1): continue
    except: continue
    g=int(fl[0]); go_guids.add(g)
    go_rows.append("(%d,%s,646,0,0,%s,1,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'',0,'Deepholm-Nel')"%(
        g+GO, fl[1], num(fl[5]), num(fl[7]),num(fl[8]),num(fl[9]),num(fl[10]),num(fl[11]),num(fl[12]),num(fl[13]),num(fl[14]),num(fl[15]),num(fl[16]),num(fl[17])))
# 6) pool_gameobject for those GO guids ; collect pools
pg_rows=[]
for fl in scan('pool_gameobject'):
    try: g=int(fl[0])
    except: continue
    if g not in go_guids: continue
    pe=int(fl[1]); pools.add(pe); poolmembers[pe]=poolmembers.get(pe,0)+1
    pg_rows.append("(%d,%d,%s,%s)"%(g+GO,pe+POOL,num(fl[2]),q(fl[3]) if len(fl)>3 else "''"))
# 7) pool_template: SYNTHESIZE (Neltharion's are nested/incomplete for the leaf
#    pools). Treat each referenced pool as a flat pool; gate to ~1/4 of members
#    (node behaviour) so we don't flood the zone, with min 1 active.
pt_rows=["(%d,%d,'Deepholm-Nel pool %d (%d members)')"%(p+POOL, max(1, m//4), p, m)
         for p,m in sorted(poolmembers.items())]

def block(table,cols,rows):
    if not rows: return ""
    return "INSERT INTO `%s` (%s) VALUES\n"%(table,cols)+",\n".join(rows)+";\n\n"
with open(OUT,'w',encoding='utf-8',newline='\n') as f:
    f.write("""-- =====================================================================
-- Deepholm Downport  --  30  Neltharion spawn-layer migration
-- ---------------------------------------------------------------------
-- Replaces the cata-sourced spawn layer (04) + supplements (20 Terborus spawn,
-- 23 GO densify, 26-B wander) with Project Neltharion 4.3.4's spawns, which carry
-- pool-gating (no stacked duplicates), real waypoint routes (%d paths), and
-- per-spawn MovementType (patrol/random). Entry-keyed content (templates, quests,
-- loot, gossip, conditions, credit smart_scripts, items, spells) is UNCHANGED.
-- Only base-visible spawns imported (phaseMask&1 -> phaseMask 1); storyline-phased
-- (deferred) skipped. Guid blocks: creature +%d, gameobject +%d, waypoint +%d, pool +%d.
-- 26-A (Flight=1 flyer fix) STILL applies (template-level, complements this).
-- =====================================================================

-- Cleanup: drop the old cata/supplement spawn layer (all map-646 spawns).
DELETE FROM `creature` WHERE `map`=646;
DELETE FROM `creature_addon` WHERE `guid` BETWEEN 9400000 AND 9461100;
DELETE FROM `gameobject` WHERE `map`=646;
DELETE FROM `gameobject_addon` WHERE `guid` BETWEEN 9300000 AND 9360050;
DELETE FROM `pool_creature` WHERE `pool_entry` BETWEEN %d AND %d;
DELETE FROM `pool_gameobject` WHERE `pool_entry` BETWEEN %d AND %d;
DELETE FROM `pool_template` WHERE `entry` BETWEEN %d AND %d;
DELETE FROM `waypoint_data` WHERE `id` BETWEEN %d AND %d;

"""%(len(paths),CRE,GO,PATH,POOL, POOL,POOL+999999, POOL,POOL+999999, POOL,POOL+999999, PATH,PATH+999999))
    f.write(block("creature","`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`",cre_rows))
    f.write(block("creature_addon","`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`",addon_rows))
    f.write(block("waypoint_data","`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,`smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`",wp_rows))
    f.write(block("pool_template","`entry`,`max_limit`,`description`",pt_rows))
    f.write(block("pool_creature","`guid`,`pool_entry`,`chance`,`description`",pc_rows))
    f.write(block("gameobject","`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`",go_rows))
    f.write(block("pool_gameobject","`guid`,`pool_entry`,`chance`,`description`",pg_rows))
    f.write("""-- Orphan cleanup: drop any spawn whose entry we lack a template for (Neltharion-only
-- quirks/customs), plus their now-dangling addon/pool rows.
DELETE c FROM `creature` c LEFT JOIN `creature_template` ct ON ct.`entry`=c.`id` WHERE c.`map`=646 AND ct.`entry` IS NULL;
DELETE g FROM `gameobject` g LEFT JOIN `gameobject_template` gt ON gt.`entry`=g.`id` WHERE g.`map`=646 AND gt.`entry` IS NULL;
DELETE a FROM `creature_addon` a LEFT JOIN `creature` c ON c.`guid`=a.`guid` WHERE a.`guid`>=%d AND c.`guid` IS NULL;
DELETE p FROM `pool_creature` p LEFT JOIN `creature` c ON c.`guid`=p.`guid` WHERE p.`pool_entry`>=%d AND c.`guid` IS NULL;
DELETE p FROM `pool_gameobject` p LEFT JOIN `gameobject` g ON g.`guid`=p.`guid` WHERE p.`pool_entry`>=%d AND g.`guid` IS NULL;
"""%(CRE,POOL,POOL))
print("creatures=%d addons=%d waypoints(pts)=%d paths=%d pool_tmpl=%d pool_cre=%d gameobjects=%d pool_go=%d"%(
    len(cre_rows),len(addon_rows),len(wp_rows),len(paths),len(pt_rows),len(pc_rows),len(go_rows),len(pg_rows)))
print("OUT:",OUT)
