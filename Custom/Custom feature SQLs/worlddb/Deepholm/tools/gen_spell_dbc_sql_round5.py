import csv

# Round 5 (2026-07-11): 2 more spell_dbc gaps found on creature_template_spell
# (Deepholm map 646) - Blood Seeker (3868) -> 7140, Earthen Catapult (43952) -> 82294.
# 7140 is stock WotLK (already present in Custom/CSV DBC/Spell.csv, no remap needed,
# raw-copied straight from there). 82294 is Cata-only, downported via spell_downport.py
# (TARGET=[82294]) -> k:/tmp/deepholm_spells_review.csv, same as 39_/24_.
FORK_CSV = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/CSV DBC/Spell.csv"
CATA_REVIEW = "k:/tmp/deepholm_spells_review.csv"
OUT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/Deepholm/46_spell_dbc_additions_round5.sql"

STOCK_IDS = ["7140"]

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
    f.write("-- Deepholm Downport  --  46  Server-side spell_dbc additions (round 5)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- More-db-errors audit pass (2026-07-11): creature_template_spell rows for\n")
    f.write("-- Blood Seeker (3868) and Earthen Catapult (43952) referenced spells 7140 and\n")
    f.write("-- 82294, both missing from acore_world.spell_dbc (same systemic gap as 39_/24_:\n")
    f.write("-- this fork's spell_dbc is an incrementally-populated mirror, not a full copy\n")
    f.write("-- of any client's Spell.dbc). 7140 is stock WotLK (already present in this\n")
    f.write("-- fork's own Custom/CSV DBC/Spell.csv -- the CLIENT already has it compiled;\n")
    f.write("-- only the server-side SQL mirror was missing it, no DBC/MPQ redeploy needed).\n")
    f.write("-- 82294 'Fire Catapult' is Cata-only, downported via\n")
    f.write("-- Deepholm/tools/spell_downport.py from k:/tmp/cata-dbc/Spell.dbc+SpellEffect.dbc\n")
    f.write("-- (build 15601) -- same source/tool as 39_. Per that file's own precedent, no\n")
    f.write("-- matching client Custom/CSV DBC/Spell.csv row was added either (server-side\n")
    f.write("-- fix only; add a client row separately if client-visible tooltips/visuals for\n")
    f.write("-- Fire Catapult are wanted later).\n")
    f.write("-- =====================================================================\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + idlist + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join("(" + ",".join("'" + x.replace("'", "''") + "'" for x in row) + ")" for row in rows) + ";\n")

print("spell_dbc rows:", len(rows), "(each 234 cols) ->", OUT)
print("ids:", idlist)
