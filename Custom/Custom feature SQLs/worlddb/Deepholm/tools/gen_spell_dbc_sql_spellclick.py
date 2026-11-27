import csv

FORK_CSV = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/Spell.csv"
CATA_REVIEW = "k:/tmp/deepholm_spells_review.csv"
OUT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/HyjalCata/80_spellclick_spell_dbc_additions.sql"

STOCK_IDS = ["41020", "46598"]

def transform_232_to_234(r):
    assert len(r) == 232, len(r)
    v = r[0:13] + ['0'] + [r[13]] + ['0'] + r[14:]
    assert len(v) == 234, len(v)
    return v

rows = []
ids = []

with open(FORK_CSV, encoding='utf-8') as f:
    rr = list(csv.reader(f))
for r in rr:
    if r and r[0] in STOCK_IDS:
        rows.append(transform_232_to_234(r))
        ids.append(r[0])

with open(CATA_REVIEW, encoding='utf-8') as f:
    rr = list(csv.reader(f))
for r in rr[1:]:
    if len(r) != 232:
        print("WARN row len", len(r), r[0]); continue
    rows.append(transform_232_to_234(r))
    ids.append(r[0])

idlist = ",".join(ids)
with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    f.write("-- =====================================================================\n")
    f.write("-- spellclick spell_dbc additions (Magmaw's Pincer / Wyvern / Hyjal MF)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- More-db-errors audit pass (2026-07-13): boot-log 'has\n")
    f.write("-- UNIT_NPC_FLAG_SPELLCLICK but no data in spellclick table' warnings.\n")
    f.write("-- Same systemic spell_dbc gap as every other round this session. 41020\n")
    f.write("-- and 46598 are stock WotLK (raw-copied from this fork's own\n")
    f.write("-- Custom/CSV DBC/Spell.csv, no remap needed). The other 5\n")
    f.write("-- (90102/94656/96504/97885/98757) are Cata-only, downported via\n")
    f.write("-- Deepholm/tools/spell_downport.py. Server-side only (spellclick\n")
    f.write("-- interactions don't need a client-visible spell entry beyond what's\n")
    f.write("-- already compiled for the stock ones; the Cata ones are triggered by\n")
    f.write("-- right-click interact, not an action-bar button).\n")
    f.write("-- =====================================================================\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + idlist + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join("(" + ",".join("'" + x.replace("'", "''") + "'" for x in row) + ")" for row in rows) + ";\n")

print("spell_dbc rows:", len(rows), "(each 234 cols) ->", OUT)
print("ids:", idlist)
