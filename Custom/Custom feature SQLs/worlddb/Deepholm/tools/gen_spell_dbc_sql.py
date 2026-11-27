import csv
SRC=["k:/tmp/deepholm_spells_review.csv","k:/tmp/credit_spells_review.csv"]
OUT=r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/24_spell_dbc_server.sql"
rows=[]; ids=[]
for f in SRC:
    rr=list(csv.reader(open(f,encoding='utf-8')))
    for r in rr[1:]:
        if len(r)!=232:
            print("WARN row len",len(r),r[0]); continue
        # spell_dbc(234) = csv[0:13] + unk_320_2(0) + ShapeshiftExclude + unk_320_3(0) + csv[14:]
        v = r[0:13] + ['0'] + [r[13]] + ['0'] + r[14:]
        assert len(v)==234, len(v)
        ids.append(r[0])
        rows.append("("+",".join("'"+x.replace("'","''")+"'" for x in v)+")")
idlist=",".join(ids)
with open(OUT,'w',encoding='utf-8',newline='\n') as f:
    f.write("-- =====================================================================\n")
    f.write("-- Deepholm Downport  --  24  Server-side spell_dbc (REQUIRED)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- This fork's worldserver loads spells from acore_world.spell_dbc (a 234-col\n")
    f.write("-- runtime table), NOT just the client Spell.dbc. The Spell.csv additions (19/22)\n")
    f.write("-- only give the CLIENT tooltips/visuals -- without these rows the server cannot\n")
    f.write("-- cast/resolve the Deepholm spells (Xariona kit, Twilight Buffet, credit triggers).\n")
    f.write("-- Same 3.3.5 layout as Spell.csv + the 2 unk_320 stance-mask high-words (=0).\n")
    f.write("-- 35 spells = the 12 in 19_spell_dbc_additions + the 23 in 22_credit_spell_dbc_additions.\n")
    f.write("-- =====================================================================\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN ("+idlist+");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join(rows)+";\n")
print("spell_dbc rows:",len(rows)," (each 234 cols) -> ",OUT)
print("ids:",idlist)
