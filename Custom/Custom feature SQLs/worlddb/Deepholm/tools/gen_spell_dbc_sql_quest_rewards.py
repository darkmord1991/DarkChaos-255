import csv

CATA_REVIEW = "k:/tmp/deepholm_spells_review.csv"
OUT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/HyjalCata/86_quest_reward_spell_dbc_additions.sql"

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
    f.write("-- Quest reward spell_dbc additions (from the Loading Quests boot log)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- More-db-errors audit pass (2026-07-13): 6 more RewardSpell gaps, same\n")
    f.write("-- systemic spell_dbc mirror gap as every other round this session. All 6\n")
    f.write("-- are backend quest-mechanic spells (faction-set, phase update, cancel-aura\n")
    f.write("-- triggers) -- server-side only, no client Spell.csv row needed. 4 more\n")
    f.write("-- referenced spells (84192, 84205, 94998, 100562) don't exist in ANY Cata\n")
    f.write("-- 4.3.4 build (dense id-neighbor check on both sides of each id) -- genuine\n")
    f.write("-- gaps in Blizzard's own spell numbering, same as round 5's/HyjalCata 76_'s\n")
    f.write("-- unresolvable ids. Left unfixed; RewardSpell failures are non-fatal (quest\n")
    f.write("-- just won't grant that spell reward).\n")
    f.write("-- =====================================================================\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + idlist + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join("(" + ",".join("'" + x.replace("'", "''") + "'" for x in row) + ")" for row in rows) + ";\n")

print("spell_dbc rows:", len(rows), "(each 234 cols) ->", OUT)
print("ids:", idlist)
