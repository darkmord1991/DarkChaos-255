#!/usr/bin/env python3
"""
Class consumables for levels 81-255: rogue poisons, warlock stones, mage conjures and rituals.

Companion to gen_class_ranks.py, for the class spells whose effect lives on an item.

Rogue poisons (Instant, Deadly, Wound, Anesthetic) get one new rank per band (81, 100, 130,
160), the way gen_class_ranks.py extends a spell: a new poison item, the spell the item casts
(which coats the weapon with a new SpellItemEnchantment) and the poison the enchantment procs,
whose damage grows like weapon damage (tools/balance/gen_reference.py). Every vendor that sells
the level-80 poison sells the new ones. Crippling and Mind-numbing Poison are percentages and
stay as they are.

The healthstone and the soulstone become percentages instead, so one new rank at 81 covers
every level after it:

  * Create Healthstone rank 9 makes a Dread Healthstone that restores 20% of maximum health
    (22% / 24% with Improved Healthstone, the talent's stock +10% / +20%). A level-80 Fel
    Healthstone restores about that share of a level-80 character's health. The item the spell
    makes is picked by spell_warl_create_healthstone, which needs the rank-9 row this file's
    items fill (src/server/scripts/Spells/spell_warlock.cpp).
  * Create Soulstone rank 8 makes a Dread Soulstone whose resurrection restores 20% of maximum
    health and mana (SELF_RESURRECT with a positive amount is a percentage). The core maps the
    soulstone aura to its resurrection spell in Player::GetResurrectionSpellId.

Third rollout (same day):

  * Firestone and Spellstone get one rank per band like the poisons: Create Firestone / Spellstone
    ranks 8-11 / 7-10 make a new stone whose weapon enchantment grants the level-80 stone's rating
    grown with gear (ratings per percent grow with gear too, gtCombatRatings).
  * Conjure Refreshment rank 3 and Ritual of Refreshment rank 3 make Conjured Mana Tortes, which
    restore the same 4% of maximum health and mana per second as the level-81 vendor food and drink.
  * Conjure Mana Gem rank 7 makes a Mana Diamond that restores 15% of maximum mana (a level-80
    Mana Sapphire restores about that share), 3 charges.
  * Ritual of Souls rank 3 makes a Soulwell that hands out Dread Healthstones (go_soulwell picks the
    stone by the well's object entry: src/server/scripts/World/go_scripts.cpp).
  Rituals need copies of their game objects (the portal, then the table or well) and, for the
  Soulwell, of the server-only spell the portal casts (spell_dbc 58888).

Outputs (into --out): new_spells.csv, new_items.csv (Item.dbc rows), new_enchants.csv,
sla_new.csv, sla_changed.csv, class_items.sql. With --apply-csv the rows also go into
Custom/CSV DBC (Spell, Item, SpellItemEnchantment, SkillLineAbility). Re-running replaces the
same ids, so it is safe.

Usage:
    python tools/balance/gen_class_items.py --out <dir> [--apply-csv]
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_reference  # noqa: E402
from gen_class_ranks import (BANDS, ENCHANT_CSV, LAST_LEVEL, SLA_CSV, SPELL_CSV, append_rows,  # noqa: E402
                             parse_int, rank_number, read_csv, remap_tokens, replace_lines, roman,
                             scale_effects, write_csv)

ROOT = Path(__file__).resolve().parents[2]
ITEM_CSV = ROOT / "Custom" / "CSV DBC" / "Item.csv"

# Poisons: (item, the spell the item casts, its enchantment, the poison it procs, name, stock numeral).
POISONS = [
    (43231, 57968, 3769, 57965, "Instant Poison", 9),
    (43233, 57973, 3771, 57970, "Deadly Poison", 9),
    (43235, 57978, 3773, 57975, "Wound Poison", 7),
    (43237, 57982, 3774, 57981, "Anesthetic Poison", 2),
]
# Ids for poison p (0-3) and band step s (1-4).
POISON_ITEM_BASE = 423100       # items 423101-423134
POISON_APPLY_BASE = 920100      # the spell the item casts, 920101-920134
POISON_PROC_BASE = 920200       # the poison, 920201-920234
POISON_ENCHANT_BASE = 922100    # enchantments 922101-922134

HEALTHSTONE_LEVEL = 81
HEALTHSTONE_ITEM_LEVEL = 90
# Dread Healthstone: (item, stock item, heal spell, stock heal spell, percent of maximum health)
HEALTHSTONES = [
    (423005, 36892, 920006, 47875, 20),
    (423006, 36893, 920007, 47876, 22),     # Improved Healthstone rank 1
    (423007, 36894, 920008, 47877, 24),     # Improved Healthstone rank 2
]
HEALTHSTONE_NAME = "Dread Healthstone"
CREATE_HEALTHSTONE = (920009, 47878)        # rank 9, from rank 8
SOULSTONE_ITEM = (423008, 36895)
SOULSTONE_NAME = "Dread Soulstone"
CREATE_SOULSTONE = (920010, 47884)          # rank 8, from rank 7
SOULSTONE_AURA = (920011, 47883)            # Soulstone Resurrection; Player::GetResurrectionSpellId maps it
SOULSTONE_RESURRECT = (920012, 47882)       # Use Soulstone
SOULSTONE_PERCENT = 20
# Spellbook rows of the two create spells (warlock block; gen_class_ranks.py uses 48000-48264).
SLA_IDS = {920009: 48901, 920010: 48911}

CONJURED_NOTE = "\n\nConjured items disappear if logged out for more than 15 minutes."

# ---------------------------------------------------------------------------
# Third rollout
# ---------------------------------------------------------------------------
# Stones: (create spell top, item, the spell the item casts, its enchantment, the equip spell the enchantment
# applies, base name (band 1; later bands add a numeral), equip spell name pattern). Ids: stone_id().
STONES = [
    (60220, 41174, 55158, 3614, 55151,
     "Dread Firestone",
     "Firestone - %d Spell Crit"),
    (47888, 41196, 55194, 3620, 55195,
     "Dread Spellstone",
     "Spellstone - %d Haste"),
]
STONE_CREATE_BASE = 920300      # Create Firestone 920301-920304, Create Spellstone 920311-920314
STONE_USE_BASE = 920320         # the spell the stone casts
STONE_EQUIP_BASE = 920340       # the rating aura the enchantment applies
STONE_ENCHANT_BASE = 922200     # enchantments 922201-922214
STONE_ITEM_BASE = 423200        # items 423201-423214
STONE_SLA_BASE = 48920          # spellbook rows 48921-48934
STONE_RATING_EFFECT = 3         # the rating effect of the equip spell (named in its title)

FOOD_NAME = "Conjured Mana Torte"
FOOD_ITEM = (423009, 43523)                 # copy of Conjured Mana Strudel
FOOD_USE = (920014, 58648)                  # Refreshment: triggers the level-81 percent food and drink
FOOD_TRIGGERS = (920004, 920005)            # gen_consumables.py: 4% health / 4% mana per second
CONJURE_REFRESHMENT = (920013, 42956)       # rank 3, from rank 2
RITUAL_REFRESHMENT = (920015, 58659)        # rank 3, from rank 2; summons portal object 920015
REFRESHMENT_TABLE_SPELL = (920016, 58661)   # the portal's spell; summons table object 920016
REFRESHMENT_TABLE_CREATE = (920017, 58660)  # the table's spell: 20 Mana Tortes
MANA_GEM_NAME = "Mana Diamond"
MANA_GEM_ITEM = (423010, 33312)             # copy of Mana Sapphire
MANA_GEM_USE = (920019, 42987)              # Replenish Mana rank 7: percent of maximum mana
MANA_GEM_PERCENT = 15
CONJURE_MANA_GEM = (920018, 42985)          # rank 7, from rank 6
RITUAL_SOULS = (920020, 58887)              # rank 3, from rank 2; summons portal object 920020
SOULS_PORTAL_SPELL = (920021, 58888)        # server-only (spell_dbc): triggers Create Soulwell
CREATE_SOULWELL = (920022, 58889)           # summons Soulwell object 920022
SOULWELL_STONES = [(920023, 58890, 423005), (920024, 58896, 423006), (920025, 58898, 423007)]
# Game objects: (new entry, stock entry, Data field, new value). The entry is the id of the spell that summons it.
OBJECTS = [
    (920015, 193062, "Data1", 920016),      # Refreshment Portal -> table spell
    (920016, 193061, "Data0", 920017),      # Refreshment Table -> create Mana Tortes
    (920020, 193168, "Data1", 920021),      # Soul Portal -> trigger Create Soulwell
    (920022, 193169, "Data0", 920023),      # Soulwell -> create Dread Healthstone (go_soulwell picks the variant)
]
# Spellbook rows of the new create and ritual ranks (mage block 30001-30314, warlock 48001-48294 are taken).
THIRD_SLA_IDS = {920013: 30901, 920015: 30911, 920018: 30921, 920020: 48951}


def band_id(base, k, step, second_base=None):
    """Id of band `step` of item family k: base + 10 * k + step for steps 1-9 (the ids of the first four bands
    stay where they were), steps 10 and up at second_base + 10 * k + (step - 9). The default second base,
    base + 50, works for up to 5 families (k 0-4)."""
    assert 1 <= step <= 18 and 0 <= k
    if step <= 9:
        return base + 10 * k + step
    return (second_base if second_base is not None else base + 50) + 10 * k + (step - 9)


def poison_ids(p, step):
    assert p <= 4
    return (band_id(POISON_ITEM_BASE, p, step), band_id(POISON_APPLY_BASE, p, step),
            band_id(POISON_PROC_BASE, p, step), band_id(POISON_ENCHANT_BASE, p, step))


# Stones: the base blocks of create / use / equip sit 20 apart, so their steps 10+ need their own second blocks.
STONE_SECOND = {
    STONE_CREATE_BASE: 920600, STONE_USE_BASE: 920620, STONE_EQUIP_BASE: 920640,
    STONE_ENCHANT_BASE: 922250, STONE_ITEM_BASE: 423250, STONE_SLA_BASE: 48960,
}


def stone_id(base, k, step):
    return band_id(base, k, step, STONE_SECOND[base])


def set_levels(row, ix, level):
    row[ix["SpellLevel"]] = str(level)
    row[ix["BaseLevel"]] = str(level)
    row[ix["MaxLevel"]] = "0"


def build(spell_header, by_spell, enchant_header, by_enchant, item_header, by_item):
    ix = {name: position for position, name in enumerate(spell_header)}
    ex = {name: position for position, name in enumerate(enchant_header)}
    strings = [position for name, position in ix.items() if "_Lang_" in name and not name.endswith("_Mask")]
    spells, enchants, items, item_sql = [], [], [], []
    chain = []      # (new spell, stock spell, step): new ranks that join the stock spell's rank chain
    enchant_pairs = []

    def copy_item(new_entry, old_entry):
        assert item_header[0] == "ID" and len(item_header) == 8, "unexpected Item.csv header"
        items.append([str(new_entry)] + list(by_item[str(old_entry)][1:]))

    for p, (item, apply, enchant, proc, name, numeral) in enumerate(POISONS):
        for step, band in enumerate(BANDS, start=1):
            next_band = BANDS[step] if step < len(BANDS) else LAST_LEVEL
            new_item, new_apply, new_proc, new_enchant = poison_ids(p, step)
            title = "%s %s" % (name, roman(numeral + step))
            id_map = {apply: new_apply, proc: new_proc}
            for new, old in ((new_apply, apply), (new_proc, proc)):
                source = by_spell[str(old)]
                row = list(source)
                row[ix["ID"]] = str(new)
                set_levels(row, ix, band)
                row[ix["Name_Lang_enUS"]] = title
                rank = rank_number(source[ix["NameSubtext_Lang_enUS"]])
                assert rank == numeral, "spell %d is not rank %d" % (old, numeral)
                row[ix["NameSubtext_Lang_enUS"]] = "Rank %d" % (rank + step)
                if old == apply:
                    assert parse_int(source[ix["Effect_1"]]) == 54 and \
                        parse_int(source[ix["EffectMiscValue_1"]]) == enchant, "spell %d does not apply %d" % (old, enchant)
                    row[ix["EffectMiscValue_1"]] = str(new_enchant)
                else:
                    scale_effects(row, source, ix, band, next_band)
                for position in strings:
                    row[position] = remap_tokens(row[position], id_map)
                spells.append(row)
                chain.append((new, old, step))
            source = by_enchant[str(enchant)]
            assert parse_int(source[ex["EffectArg_1"]]) == proc, "enchantment %d does not proc %d" % (enchant, proc)
            row = list(source)
            row[ex["ID"]] = str(new_enchant)
            row[ex["EffectArg_1"]] = str(new_proc)
            row[ex["Name_Lang_enUS"]] = title
            enchants.append(row)
            enchant_pairs.append((new_enchant, enchant))
            copy_item(new_item, item)
            growth = gen_reference.gear_growth(band)
            item_sql.append((new_item, item, title, band, band, "spellid_1", new_apply,
                             "`BuyPrice` * %.4f" % growth, "`SellPrice` * %.4f" % growth))

    # Healthstone: three heal spells and items, one create rank.
    for new_item, old_item, new_spell, old_spell, percent in HEALTHSTONES:
        row = list(by_spell[str(old_spell)])
        row[ix["ID"]] = str(new_spell)
        set_levels(row, ix, HEALTHSTONE_LEVEL)
        row[ix["Name_Lang_enUS"]] = HEALTHSTONE_NAME
        row[ix["Effect_1"]] = "136"                     # HEAL_PCT
        row[ix["EffectBasePoints_1"]] = str(percent - 1)
        row[ix["EffectDieSides_1"]] = "1"
        row[ix["EffectRealPointsPerLevel_1"]] = "0"
        row[ix["Description_Lang_enUS"]] = "Instantly restores $s1% of your maximum health."
        spells.append(row)
        copy_item(new_item, old_item)
        item_sql.append((new_item, old_item, HEALTHSTONE_NAME, HEALTHSTONE_LEVEL, HEALTHSTONE_ITEM_LEVEL,
                         "spellid_2", new_spell, "0", "0"))
    new_create, old_create = CREATE_HEALTHSTONE
    source = by_spell[str(old_create)]
    row = list(source)
    row[ix["ID"]] = str(new_create)
    set_levels(row, ix, HEALTHSTONE_LEVEL)
    row[ix["NameSubtext_Lang_enUS"]] = "Rank %d" % (rank_number(source[ix["NameSubtext_Lang_enUS"]]) + 1)
    row[ix["Description_Lang_enUS"]] = ("Creates a %s that can be used to instantly restore $%ds1%% of your maximum "
                                        "health.%s" % (HEALTHSTONE_NAME, HEALTHSTONES[0][2], CONJURED_NOTE))
    spells.append(row)
    chain.append((new_create, old_create, 1))

    # Soulstone: item, aura, resurrection, create rank.
    new_item, old_item = SOULSTONE_ITEM
    new_aura, old_aura = SOULSTONE_AURA
    new_res, old_res = SOULSTONE_RESURRECT
    text = ("If the target dies while his soul is stored, he will be able to resurrect with $%ds1%% of his maximum "
            "health and mana." % new_res)
    row = list(by_spell[str(old_res)])
    row[ix["ID"]] = str(new_res)
    row[ix["EffectBasePoints_1"]] = str(SOULSTONE_PERCENT - 1)     # positive: a percentage (EffectSelfResurrect)
    row[ix["EffectDieSides_1"]] = "1"
    row[ix["EffectMiscValue_1"]] = "0"
    spells.append(row)
    row = list(by_spell[str(old_aura)])
    row[ix["ID"]] = str(new_aura)
    set_levels(row, ix, HEALTHSTONE_LEVEL)
    row[ix["Description_Lang_enUS"]] = "Stores the friendly target's soul.  " + text
    spells.append(row)
    copy_item(new_item, old_item)
    item_sql.append((new_item, old_item, SOULSTONE_NAME, 0, HEALTHSTONE_ITEM_LEVEL, "spellid_1", new_aura,
                     "0", "0"))
    new_create, old_create = CREATE_SOULSTONE
    source = by_spell[str(old_create)]
    assert parse_int(source[ix["EffectItemType_1"]]) == old_item
    row = list(source)
    row[ix["ID"]] = str(new_create)
    set_levels(row, ix, HEALTHSTONE_LEVEL)
    row[ix["NameSubtext_Lang_enUS"]] = "Rank %d" % (rank_number(source[ix["NameSubtext_Lang_enUS"]]) + 1)
    row[ix["EffectItemType_1"]] = str(new_item)
    row[ix["Description_Lang_enUS"]] = ("Creates a %s.  The Soulstone can be used to store one target's soul.  %s%s"
                                        % (SOULSTONE_NAME, text, CONJURED_NOTE))
    spells.append(row)
    chain.append((new_create, old_create, 1))

    def copy_spell(new, old, level=None, **changes):
        row = list(by_spell[str(old)])
        row[ix["ID"]] = str(new)
        if level is not None:
            set_levels(row, ix, level)
        for column, value in changes.items():
            row[ix[column]] = str(value)
        spells.append(row)
        return row

    # Stones: four bands.
    for k, (create, item, use, enchant, equip, base_name, equip_name) in enumerate(STONES):
        source_create = by_spell[str(create)]
        rank = rank_number(source_create[ix["NameSubtext_Lang_enUS"]])
        for step, band in enumerate(BANDS, start=1):
            next_band = BANDS[step] if step < len(BANDS) else LAST_LEVEL
            name = base_name if step == 1 else "%s %s" % (base_name, roman(step))
            new_create = stone_id(STONE_CREATE_BASE, k, step)
            new_use = stone_id(STONE_USE_BASE, k, step)
            new_equip = stone_id(STONE_EQUIP_BASE, k, step)
            new_enchant = stone_id(STONE_ENCHANT_BASE, k, step)
            new_item = stone_id(STONE_ITEM_BASE, k, step)
            id_map = {equip: new_equip, use: new_use, create: new_create}
            assert parse_int(source_create[ix["EffectItemType_1"]]) == item
            row = copy_spell(new_create, create, band, EffectItemType_1=new_item,
                             NameSubtext_Lang_enUS="Rank %d" % (rank + step))
            source_use = by_spell[str(use)]
            assert parse_int(source_use[ix["EffectMiscValue_1"]]) == enchant
            copy_spell(new_use, use, None, EffectMiscValue_1=new_enchant, Name_Lang_enUS=name)
            source_equip = by_spell[str(equip)]
            row = copy_spell(new_equip, equip, band)
            scale_effects(row, source_equip, ix, band, next_band)
            rating = parse_int(row[ix["EffectBasePoints_%d" % STONE_RATING_EFFECT]]) + 1
            row[ix["Name_Lang_enUS"]] = equip_name % rating
            for spell_row in spells[-3:]:
                for position in strings:
                    spell_row[position] = remap_tokens(spell_row[position], id_map)
            source = by_enchant[str(enchant)]
            assert parse_int(source[ex["EffectArg_1"]]) == equip
            enchant_row = list(source)
            enchant_row[ex["ID"]] = str(new_enchant)
            enchant_row[ex["EffectArg_1"]] = str(new_equip)
            enchant_row[ex["Name_Lang_enUS"]] = name
            enchants.append(enchant_row)
            copy_item(new_item, item)
            item_sql.append((new_item, item, name, 0, band, "spellid_1", new_use, "0", "0"))
            chain.append((new_create, create, step))

    # Conjured food and its two create spells.
    copy_item(*FOOD_ITEM)
    item_sql.append((FOOD_ITEM[0], FOOD_ITEM[1], FOOD_NAME, HEALTHSTONE_LEVEL, HEALTHSTONE_ITEM_LEVEL,
                     "spellid_1", FOOD_USE[0], "0", "0"))
    copy_spell(*FOOD_USE, HEALTHSTONE_LEVEL, EffectTriggerSpell_1=FOOD_TRIGGERS[0],
               EffectTriggerSpell_2=FOOD_TRIGGERS[1],
               Description_Lang_enUS="Restores $%ds1%% of your maximum health and $%ds1%% of your maximum mana every "
               "second for $%dd.  Must remain seated while eating." % (FOOD_TRIGGERS[0], FOOD_TRIGGERS[1],
                                                                       FOOD_TRIGGERS[0]))
    row = copy_spell(*CONJURE_REFRESHMENT, HEALTHSTONE_LEVEL, EffectItemType_1=FOOD_ITEM[0],
                     NameSubtext_Lang_enUS="Rank 3")
    row[ix["Description_Lang_enUS"]] = row[ix["Description_Lang_enUS"]].replace("Mana Strudels", "Mana Tortes")
    assert "Mana Tortes" in row[ix["Description_Lang_enUS"]]
    chain.append((CONJURE_REFRESHMENT[0], CONJURE_REFRESHMENT[1], 1))
    row = copy_spell(*RITUAL_REFRESHMENT, HEALTHSTONE_LEVEL, EffectMiscValue_1=RITUAL_REFRESHMENT[0],
                     NameSubtext_Lang_enUS="Rank 3")
    row[ix["Description_Lang_enUS"]] = remap_tokens(
        row[ix["Description_Lang_enUS"]].replace("Mana Strudels", "Mana Tortes"),
        {REFRESHMENT_TABLE_SPELL[1]: REFRESHMENT_TABLE_SPELL[0]})
    assert "Mana Tortes" in row[ix["Description_Lang_enUS"]]
    chain.append((RITUAL_REFRESHMENT[0], RITUAL_REFRESHMENT[1], 1))
    copy_spell(*REFRESHMENT_TABLE_SPELL, None, EffectMiscValue_1=REFRESHMENT_TABLE_SPELL[0])
    copy_spell(*REFRESHMENT_TABLE_CREATE, None, EffectItemType_1=FOOD_ITEM[0])

    # Mana gem.
    copy_item(*MANA_GEM_ITEM)
    item_sql.append((MANA_GEM_ITEM[0], MANA_GEM_ITEM[1], MANA_GEM_NAME, HEALTHSTONE_LEVEL, HEALTHSTONE_ITEM_LEVEL,
                     "spellid_2", MANA_GEM_USE[0], "0", "0"))
    copy_spell(*MANA_GEM_USE, HEALTHSTONE_LEVEL, Effect_1=137, EffectBasePoints_1=MANA_GEM_PERCENT - 1,  # ENERGIZE_PCT
               EffectDieSides_1=1, EffectRealPointsPerLevel_1=0, EffectMiscValue_1=0, NameSubtext_Lang_enUS="Rank 7",
               Description_Lang_enUS="Restores $s1% of your maximum mana.")
    # Not chained: 42987 is not the top of its chain (stock rank 7 is 42988), and an item's energize needs no
    # rank chain (no aura to stack, no script). Chaining it as rank 7 failed with a duplicate key (11-15).
    copy_spell(*CONJURE_MANA_GEM, HEALTHSTONE_LEVEL, EffectItemType_1=MANA_GEM_ITEM[0], NameSubtext_Lang_enUS="Rank 7",
               Description_Lang_enUS="Conjures a mana diamond that can be used to instantly restore $%ds1%% of your "
               "maximum mana.  3 charges." % MANA_GEM_USE[0])
    chain.append((CONJURE_MANA_GEM[0], CONJURE_MANA_GEM[1], 1))

    # Ritual of Souls.
    row = copy_spell(*RITUAL_SOULS, HEALTHSTONE_LEVEL, EffectMiscValue_1=RITUAL_SOULS[0],
                     NameSubtext_Lang_enUS="Rank 3")
    row[ix["Description_Lang_enUS"]] = remap_tokens(
        row[ix["Description_Lang_enUS"]].replace("Fel Healthstone", HEALTHSTONE_NAME),
        {CREATE_SOULWELL[1]: CREATE_SOULWELL[0]})
    assert HEALTHSTONE_NAME in row[ix["Description_Lang_enUS"]]
    chain.append((RITUAL_SOULS[0], RITUAL_SOULS[1], 1))
    copy_spell(*CREATE_SOULWELL, None, EffectMiscValue_1=CREATE_SOULWELL[0])
    for new, old, item_id in SOULWELL_STONES:
        copy_spell(new, old, None, EffectItemType_1=item_id, Name_Lang_enUS="Create " + HEALTHSTONE_NAME)

    for row in spells:
        assert len(row) == len(spell_header)
    return spells, enchants, items, item_sql, chain, enchant_pairs


def build_sla(sla_header, sla_rows):
    sx = {name: position for position, name in enumerate(sla_header)}
    by_spell = {}
    for row in sla_rows:
        by_spell.setdefault(row[sx["Spell"]], []).append(row)
    new_rows, changed = [], []
    # (new spell, stock top rank, spellbook id, the next band's spell or 0)
    ranks = [(new, old, SLA_IDS[new], 0) for new, old in (CREATE_HEALTHSTONE, CREATE_SOULSTONE)]
    ranks += [(new, old, THIRD_SLA_IDS[new], 0)
              for new, old in (CONJURE_REFRESHMENT, RITUAL_REFRESHMENT, CONJURE_MANA_GEM, RITUAL_SOULS)]
    for k, stone in enumerate(STONES):
        for step in range(1, len(BANDS) + 1):
            ranks.append((stone_id(STONE_CREATE_BASE, k, step), stone[0], stone_id(STONE_SLA_BASE, k, step),
                          stone_id(STONE_CREATE_BASE, k, step + 1) if step < len(BANDS) else 0))
    for new_spell, old_spell, sla_id, next_spell in ranks:
        sources = by_spell[str(old_spell)]
        assert len(sources) == 1, "spell %d has %d spellbook rows" % (old_spell, len(sources))
        if new_spell not in (stone_id(STONE_CREATE_BASE, k, step) for k in range(len(STONES))
                             for step in range(2, len(BANDS) + 1)):
            top = list(sources[0])
            top[sx["SupercededBySpell"]] = str(new_spell)
            changed.append(top)
        row = list(sources[0])
        row[sx["ID"]] = str(sla_id)
        row[sx["Spell"]] = str(new_spell)
        row[sx["SupercededBySpell"]] = str(next_spell)
        new_rows.append(row)
    return new_rows, changed


def sql_list(values):
    return ", ".join(str(value) for value in values)


def render_sql(spells, item_sql, chain, enchant_pairs):
    spell_ids = sorted(int(row[0]) for row in spells)
    poison_items = [entry for entry, _old, *_rest in item_sql if entry >= POISON_ITEM_BASE]
    out = []
    out.append("-- DarkChaos: rogue poisons, healthstone and soulstone for levels 81-255"
               " (generated by tools/balance/gen_class_items.py)")
    out.append("--")
    out.append("-- Poisons: Instant, Deadly, Wound and Anesthetic Poison get one rank per band, usable from levels")
    out.append("-- %s." % ", ".join(str(b) for b in BANDS))
    out.append("-- Each is a new item (%d+) coating the weapon with a new enchantment (%d+) whose poison (%d+)"
               % (POISON_ITEM_BASE, POISON_ENCHANT_BASE, POISON_PROC_BASE))
    out.append("-- hits like the level-80 one grown with weapon damage. Every vendor of the level-80 poison")
    out.append("-- sells them. Crippling and Mind-numbing Poison are percentages and keep their stock ranks.")
    out.append("-- Create Healthstone rank 9 (level %d) makes a Dread Healthstone: 20%% of maximum health, 22%% / 24%% with"
               % HEALTHSTONE_LEVEL)
    out.append("-- Improved Healthstone. Create Soulstone rank 8 makes a Dread Soulstone: resurrection with %d%% of"
               % SOULSTONE_PERCENT)
    out.append("-- maximum health and mana. Both need the worldserver build that knows them (spell_warlock.cpp, Player.cpp).")
    out.append("-- Third rollout: Firestone and Spellstone ranks per band (items %d+ and %d+, enchantments %d+ and"
               % (STONE_ITEM_BASE, STONE_SECOND[STONE_ITEM_BASE], STONE_ENCHANT_BASE))
    out.append("-- %d+), Conjure" % STONE_SECOND[STONE_ENCHANT_BASE])
    out.append("-- Refreshment and Ritual of Refreshment rank 3 (Conjured Mana Torte, 4%% health and mana per second),")
    out.append("-- Conjure Mana Gem rank 7 (Mana Diamond, %d%% of maximum mana) and Ritual of Souls rank 3 (a Soulwell"
               % MANA_GEM_PERCENT)
    out.append("-- with Dread Healthstones; needs the build that knows its object in go_soulwell).")
    out.append("--")
    out.append("-- The spells, items and enchantments are rows of Spell.dbc, Item.dbc and SpellItemEnchantment.dbc,")
    out.append("-- which ship with this file. Re-running gives the same result. Apply to acore_world, then restart.")
    out.append("")
    for entry, old, name, required, item_level, column, spell, buy, sell in item_sql:
        assert "'" not in name
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_class_item`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_class_item` SELECT * FROM `item_template` WHERE `entry` = %d;" % old)
        out.append("UPDATE `dc_tmp_class_item` SET `entry` = %d, `name` = '%s', `RequiredLevel` = %d, `ItemLevel` = %d, "
                   "`%s` = %d, `BuyPrice` = %s, `SellPrice` = %s, `VerifiedBuild` = 0;"
                   % (entry, name, required, item_level, column, spell, buy, sell))
        out.append("REPLACE INTO `item_template` SELECT * FROM `dc_tmp_class_item`;")
    out.append("DROP TEMPORARY TABLE `dc_tmp_class_item`;")
    out.append("")
    out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_class_item_map`;")
    out.append("CREATE TEMPORARY TABLE `dc_tmp_class_item_map` (`new_id` INT NOT NULL PRIMARY KEY, `old_id` INT NOT NULL, "
               "`step` TINYINT UNSIGNED NOT NULL) ENGINE=InnoDB;")
    out.append("DELETE FROM `dc_tmp_class_item_map`;")
    out.append("INSERT INTO `dc_tmp_class_item_map` (`new_id`, `old_id`, `step`) VALUES %s;"
               % ", ".join("(%d, %d, %d)" % link for link in chain))
    out.append("")
    out.append("-- Rank chains (Deadly Poison's script, spell_rog_deadly_poison, is registered on its chain)")
    out.append("DELETE FROM `spell_ranks` WHERE `spell_id` IN (%s);" % sql_list(spell_ids))
    out.append("INSERT INTO `spell_ranks` (`first_spell_id`, `spell_id`, `rank`) SELECT `r`.`first_spell_id`, "
               "`m`.`new_id`, `r`.`rank` + `m`.`step` FROM `dc_tmp_class_item_map` AS `m` JOIN `spell_ranks` AS `r` "
               "ON `r`.`spell_id` = `m`.`old_id`;")
    out.append("")
    out.append("-- Attack power coefficients of the poisons: by the spell's own id, else by its first rank's")
    out.append("DELETE FROM `spell_bonus_data` WHERE `entry` IN (%s);" % sql_list(spell_ids))
    out.append("INSERT INTO `spell_bonus_data` (`entry`, `direct_bonus`, `dot_bonus`, `ap_bonus`, `ap_dot_bonus`, "
               "`comments`) SELECT `m`.`new_id`, `b`.`direct_bonus`, `b`.`dot_bonus`, `b`.`ap_bonus`, `b`.`ap_dot_bonus`, "
               "`b`.`comments` FROM `dc_tmp_class_item_map` AS `m` JOIN `spell_ranks` AS `r` ON `r`.`spell_id` = "
               "`m`.`old_id` JOIN `spell_bonus_data` AS `b` ON `b`.`entry` = CASE WHEN EXISTS (SELECT 1 FROM "
               "`spell_bonus_data` AS `o` WHERE `o`.`entry` = `m`.`old_id`) THEN `m`.`old_id` ELSE `r`.`first_spell_id` "
               "END;")
    out.append("")
    out.append("-- Trainer offers of the create and ritual ranks: every trainer of the stock rank, previous rank required")
    offers = [(new, old, old, HEALTHSTONE_LEVEL) for new, old in (
        CREATE_HEALTHSTONE, CREATE_SOULSTONE, CONJURE_REFRESHMENT, RITUAL_REFRESHMENT, CONJURE_MANA_GEM, RITUAL_SOULS)]
    for k, stone in enumerate(STONES):
        for step, band in enumerate(BANDS, start=1):
            new = stone_id(STONE_CREATE_BASE, k, step)
            offers.append((new, stone[0], stone[0] if step == 1 else stone_id(STONE_CREATE_BASE, k, step - 1), band))
    out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_class_item_offer`;")
    out.append("CREATE TEMPORARY TABLE `dc_tmp_class_item_offer` (`new_id` INT NOT NULL PRIMARY KEY, `old_id` INT "
               "NOT NULL, `prev_id` INT NOT NULL, `level` TINYINT UNSIGNED NOT NULL) ENGINE=InnoDB;")
    out.append("DELETE FROM `dc_tmp_class_item_offer`;")
    out.append("INSERT INTO `dc_tmp_class_item_offer` (`new_id`, `old_id`, `prev_id`, `level`) VALUES %s;"
               % ", ".join("(%d, %d, %d, %d)" % offer for offer in offers))
    out.append("DELETE FROM `trainer_spell` WHERE `SpellId` IN (%s);" % sql_list(offer[0] for offer in offers))
    out.append("INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, "
               "`ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`) SELECT `t`.`TrainerId`, "
               "`o`.`new_id`, `t`.`MoneyCost`, `t`.`ReqSkillLine`, `t`.`ReqSkillRank`, `o`.`prev_id`, `t`.`ReqAbility2`, "
               "`t`.`ReqAbility3`, `o`.`level`, 0 FROM `dc_tmp_class_item_offer` AS `o` JOIN `trainer_spell` AS `t` "
               "ON `t`.`SpellId` = `o`.`old_id`;")
    out.append("DROP TEMPORARY TABLE `dc_tmp_class_item_offer`;")
    out.append("")
    out.append("-- Ritual objects: copies of the stock portal, table and well, numbered like the spell that summons them")
    out.append("-- and pointing at this file's spells. REPLACE: the codestyle rules never delete gameobject_template rows.")
    for new, old, column, value in OBJECTS:
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_class_object`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_class_object` SELECT * FROM `gameobject_template` WHERE `entry` = %d;"
                   % old)
        out.append("UPDATE `dc_tmp_class_object` SET `entry` = %d, `%s` = %d, `VerifiedBuild` = 0;" % (new, column, value))
        out.append("REPLACE INTO `gameobject_template` SELECT * FROM `dc_tmp_class_object`;")
        out.append("DROP TEMPORARY TABLE `dc_tmp_class_object`;")
        out.append("DELETE FROM `gameobject_template_addon` WHERE `entry` = %d;" % new)
        out.append("INSERT INTO `gameobject_template_addon` (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, "
                   "`artkit1`, `artkit2`, `artkit3`) SELECT %d, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, "
                   "`artkit1`, `artkit2`, `artkit3` FROM `gameobject_template_addon` WHERE `entry` = %d;" % (new, old))
    out.append("")
    out.append("-- The Soul Portal's spell is server-only (spell_dbc), like the stock one it copies")
    new, old = SOULS_PORTAL_SPELL
    out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_class_spell`;")
    out.append("CREATE TEMPORARY TABLE `dc_tmp_class_spell` SELECT * FROM `spell_dbc` WHERE `ID` = %d;" % old)
    out.append("UPDATE `dc_tmp_class_spell` SET `ID` = %d, `EffectTriggerSpell_1` = %d, `Name_Lang_enUS` = "
               "'Ritual of Souls Rank 3 - Trigger Create Soulwell (%d)';" % (new, CREATE_SOULWELL[0], CREATE_SOULWELL[0]))
    out.append("DELETE FROM `spell_dbc` WHERE `ID` = %d;" % new)
    out.append("INSERT INTO `spell_dbc` SELECT * FROM `dc_tmp_class_spell`;")
    out.append("DROP TEMPORARY TABLE `dc_tmp_class_spell`;")
    out.append("")
    out.append("-- Poison enchantments: the proc rate of the level-80 enchantment, if it has one")
    out.append("DELETE FROM `spell_enchant_proc_data` WHERE `entry` IN (%s);" % sql_list(new for new, _ in enchant_pairs))
    out.append("INSERT INTO `spell_enchant_proc_data` (`entry`, `customChance`, `PPMChance`, `procEx`, `attributeMask`) "
               "SELECT `e`.`new_id`, `p`.`customChance`, `p`.`PPMChance`, `p`.`procEx`, `p`.`attributeMask` FROM (%s) "
               "AS `e` JOIN `spell_enchant_proc_data` AS `p` ON `p`.`entry` = `e`.`old_id`;" % " UNION ALL ".join(
                   ("SELECT %d AS `new_id`, %d AS `old_id`" if position == 0 else "SELECT %d, %d") % pair
                   for position, pair in enumerate(enchant_pairs)))
    out.append("")
    out.append("-- Poison vendors: every vendor of a level-80 poison sells its new ranks")
    out.append("DELETE FROM `npc_vendor` WHERE `item` IN (%s);" % sql_list(poison_items))
    out.append("INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`) "
               "SELECT `v`.`entry`, `v`.`slot`, `n`.`new_id`, 0, 0, 0, 0 FROM `npc_vendor` AS `v` JOIN (%s) AS `n` "
               "ON `n`.`old_id` = `v`.`item` WHERE `v`.`ExtendedCost` = 0;" % " UNION ALL ".join(
                   ("SELECT %d AS `new_id`, %d AS `old_id`" if position == 0 else "SELECT %d, %d") % (entry, old)
                   for position, (entry, old, *_rest) in enumerate(row for row in item_sql if row[0] in poison_items)))
    out.append("")
    out.append("DROP TEMPORARY TABLE `dc_tmp_class_item_map`;")
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--apply-csv", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    spell_header, spell_rows = read_csv(SPELL_CSV)
    enchant_header, enchant_rows = read_csv(ENCHANT_CSV)
    item_header, item_rows = read_csv(ITEM_CSV)
    sla_header, sla_rows = read_csv(SLA_CSV)
    spells, enchants, items, item_sql, chain, enchant_pairs = build(
        spell_header, {row[0]: row for row in spell_rows}, enchant_header, {row[0]: row for row in enchant_rows},
        item_header, {row[0]: row for row in item_rows})
    sla_new, sla_changed = build_sla(sla_header, sla_rows)

    for label, rows, existing in (("spell", spells, spell_rows), ("enchantment", enchants, enchant_rows),
                                  ("item", items, item_rows), ("spellbook", sla_new, sla_rows)):
        taken = {row[0] for row in rows} & {row[0] for row in existing}
        if taken:
            print("%s ids already in the CSV (an earlier run, or a clash): %d" % (label, len(taken)))

    write_csv(args.out / "new_spells.csv", spell_header, spells)
    write_csv(args.out / "new_enchants.csv", enchant_header, enchants)
    write_csv(args.out / "new_items.csv", item_header, items)
    write_csv(args.out / "sla_new.csv", sla_header, sla_new)
    write_csv(args.out / "sla_changed.csv", sla_header, sla_changed)
    with open(args.out / "class_items.sql", "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render_sql(spells, item_sql, chain, enchant_pairs))
    print("%d spells, %d enchantments, %d items, %d spellbook rows" % (len(spells), len(enchants), len(items),
                                                                       len(sla_new)))

    if args.apply_csv:
        print("Spell.csv: removed %d earlier rows, appended %d" % (append_rows(SPELL_CSV, spells), len(spells)))
        print("SpellItemEnchantment.csv: removed %d earlier rows, appended %d"
              % (append_rows(ENCHANT_CSV, enchants), len(enchants)))
        print("Item.csv: removed %d earlier rows, appended %d" % (append_rows(ITEM_CSV, items), len(items)))
        print("SkillLineAbility.csv: removed %d earlier rows, appended %d"
              % (append_rows(SLA_CSV, sla_new), len(sla_new)))
        print("SkillLineAbility.csv: %d rows now point at the new rank" % replace_lines(SLA_CSV, sla_changed))


if __name__ == "__main__":
    main()
