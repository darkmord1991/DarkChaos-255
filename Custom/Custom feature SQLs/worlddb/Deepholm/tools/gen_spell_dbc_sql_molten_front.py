import csv

CATA_REVIEW = "k:/tmp/deepholm_spells_review.csv"
OUT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/HyjalCata/76_molten_front_spell_dbc_additions.sql"

def transform_232_to_234(r):
    assert len(r) == 232, len(r)
    v = r[0:13] + ['0'] + [r[13]] + ['0'] + r[14:]
    assert len(v) == 234, len(v)
    return v

rows = []
ids = []
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
    f.write("-- Molten Front -- 76  Server-side spell_dbc additions\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- More-db-errors audit pass (2026-07-13): 10 more spell_dbc gaps surfaced\n")
    f.write("-- by SmartAI boot-log errors on Molten Front creatures (same systemic gap\n")
    f.write("-- as db-errors-vehicledbc-spelldbc-factiondbc-2026-07-10's 115 and round\n")
    f.write("-- 5's 2 -- this fork's spell_dbc is an incrementally-populated mirror, not\n")
    f.write("-- a full copy of any client's Spell.dbc). All 10 are Cata-only, downported\n")
    f.write("-- via Deepholm/tools/spell_downport.py from the same cached\n")
    f.write("-- k:/tmp/cata-dbc/Spell.dbc+SpellEffect.dbc (build 15601) used throughout\n")
    f.write("-- this session. Per established precedent, no matching client\n")
    f.write("-- Custom/CSV DBC/Spell.csv row added (server-side fix only).\n")
    f.write("-- NOTE: 2 more referenced spells (96565, 98102, both used by creature\n")
    f.write("-- 3652988) do NOT exist anywhere -- confirmed absent from both this fork's\n")
    f.write("-- stock Spell.dbc AND the full Cata 4.3.4 dump (dense id-neighbor check:\n")
    f.write("-- 96564/96566 and 98100/98103 exist, 96565/98102 are genuine gaps in\n")
    f.write("-- Blizzard's own spell numbering). Left unfixed -- no real data exists to\n")
    f.write("-- port; those 2 SmartAI actions will continue to be harmlessly skipped.\n")
    f.write("-- =====================================================================\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + idlist + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join("(" + ",".join("'" + x.replace("'", "''") + "'" for x in row) + ")" for row in rows) + ";\n")

print("spell_dbc rows:", len(rows), "(each 234 cols) ->", OUT)
print("ids:", idlist)
