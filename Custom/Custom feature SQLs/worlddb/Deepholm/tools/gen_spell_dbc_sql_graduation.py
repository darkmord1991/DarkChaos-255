import csv

CATA_REVIEW = "k:/tmp/deepholm_spells_review.csv"
OUT = r"K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/HyjalCata/78_molten_front_graduation_spells.sql"

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
    f.write("-- Molten Front -- 78  Graduation Speech override spells (resolves a\n")
    f.write("-- documented-blocked TODO from 47_spell_dbc_custom.sql)\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- 47_'s header flagged this as blocked: spell_inspiration_graduation /\n")
    f.write("-- spell_divisiveness_graduation / spell_crazy_graduation /\n")
    f.write("-- spell_step_down_graduation (zone_mount_hyjal.cpp) hook the 4 spells\n")
    f.write("-- OverrideSpellData.dbc row 270 grants via aura 293 on spell 74948\n")
    f.write("-- 'Twilight Speech' (MiscValue 270) -- and that row 'exists in no\n")
    f.write("-- available DB ... must be read from a Cata 4.3.4 client\n")
    f.write("-- OverrideSpellData.dbc'. Unblocked 2026-07-13: extracted\n")
    f.write("-- DBFilesClient\\OverrideSpellData.dbc straight from the real Cata client\n")
    f.write("-- (K:/Cata/Data/enUS/locale-enUS.MPQ) -- row 270 = Spells 74934/74935/\n")
    f.write("-- 74937/74947 (Flags=1), matching the C++ file's own inline comments\n")
    f.write("-- exactly (// inspiration, // incite, // pander, // step down):\n")
    f.write("--   74934 'Inspire!'   -> spell_inspiration_graduation\n")
    f.write("--   74935 'Incite!'    -> spell_divisiveness_graduation\n")
    f.write("--   74937 'Pander!'    -> spell_crazy_graduation\n")
    f.write("--   74947 'Step Down'  -> spell_step_down_graduation\n")
    f.write("-- All 4 downported for REAL from k:/tmp/cata-dbc/Spell.dbc+SpellEffect.dbc\n")
    f.write("-- (build 15601) via spell_downport.py -- not hand-authored placeholders.\n")
    f.write("-- Unlike the NPC-cast Molten Front spells in 76_, these ARE player-\n")
    f.write("-- visible (override action-bar buttons), so a matching client\n")
    f.write("-- Custom/CSV DBC/Spell.csv row was also added (see 00_README client-side\n")
    f.write("-- notes) -- Spell.dbc recompiled/patched/synced separately.\n")
    f.write("-- =====================================================================\n\n")
    f.write("DELETE FROM `spell_dbc` WHERE `ID` IN (" + idlist + ");\n\n")
    f.write("INSERT INTO `spell_dbc` VALUES\n")
    f.write(",\n".join("(" + ",".join("'" + x.replace("'", "''") + "'" for x in row) + ")" for row in rows) + ";\n\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("-- overridespelldata_dbc row 270 (0 rows server-wide before this --\n")
    f.write("-- incrementally-populated mirror, same pattern as vehicle_dbc/spell_dbc/\n")
    f.write("-- faction_dbc; server-side only, no client DBC needed for this table --\n")
    f.write("-- the client learns the override spells via normal spell-learn packets\n")
    f.write("-- once AuraEffect::HandleAuraOverrideSpells resolves this row).\n")
    f.write("-- ---------------------------------------------------------------------\n")
    f.write("DELETE FROM `overridespelldata_dbc` WHERE `ID` = 270;\n")
    f.write("INSERT INTO `overridespelldata_dbc` (`ID`,`Spells_1`,`Spells_2`,`Spells_3`,`Spells_4`,`Spells_5`,`Spells_6`,`Spells_7`,`Spells_8`,`Spells_9`,`Spells_10`,`Flags`) VALUES\n")
    f.write("(270,74934,74935,74937,0,74947,0,0,0,0,0,1);\n\n")
    f.write("-- spell_script_names wiring\n")
    f.write("DELETE FROM `spell_script_names` WHERE `ScriptName` IN ('spell_inspiration_graduation','spell_divisiveness_graduation','spell_crazy_graduation','spell_step_down_graduation');\n")
    f.write("INSERT INTO `spell_script_names` (`spell_id`,`ScriptName`) VALUES\n")
    f.write("(74934,'spell_inspiration_graduation'),\n")
    f.write("(74935,'spell_divisiveness_graduation'),\n")
    f.write("(74937,'spell_crazy_graduation'),\n")
    f.write("(74947,'spell_step_down_graduation');\n")

print("spell_dbc rows:", len(rows), "(each 234 cols) ->", OUT)
print("ids:", idlist)
