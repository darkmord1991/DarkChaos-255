#!/usr/bin/env python3
"""
New class spell ranks for levels 81-255, the WotLK way.

The owner's rule (2026-11-15): levels 1-80 stay as WotLK, and above 80 the game is
extended the way WotLK itself does it. For class spells that means more ranks. Each
spell family gets one new rank per band (learned at 81, 100, 130 and 160). A new rank
is a copy of the level-80 rank with:

  * SpellLevel = BaseLevel = the band level and MaxLevel = 0. MaxLevel 0 means no
    upper clamp on the per-level growth and no spell power level penalty, on the
    server and in the native client's tooltip alike;
  * amounts (base points, random spread, points per combo point) sized from the
    level-80 value by the balance reference so that the WHOLE hit -- base points
    plus coefficient x spell power or attack power in the reference gear -- grows
    like a white hit (damage) or like player health (heals, absorbs); see
    whole_hit_growth(). A strike's flat bonus grows like a white hit. Until
    2026-11-15 base points alone grew like weapon damage, which let low-coefficient
    spells (totems, Fire Nova, shocks) outgrow everything else;
  * points per level that carry the value from one band to the next, so there is no
    jump at a band boundary; the last rank keeps growing to level 255 where the
    reference does;
  * "Rank N" continuing the stock numbering (bots pick the highest rank by that
    text), and tooltip tokens such as $42845s1 remapped to the same band's ids.

Coefficients, costs, cast times, cooldowns and spell class masks are copied, so
talents, glyphs and procs keep working. Scripts and procs registered on the whole
rank chain (negative first-rank ids) cover the new ranks because they join
spell_ranks; rows registered under the level-80 rank's own id (spell_script_names,
spell_custom_attr, spell_threat, spell_linked_spell) are copied per new rank.

Families: the mage list below was picked by hand. The other classes come from
class_rank_discovery.json (every level-80 rank a class trainer teaches) through the
filters in families_from_discovery(): a family is kept if it carries a damage, heal,
absorb or flat buff amount and does not summon, create, enchant, teach or resurrect --
except totems (TOTEM_CREATURES: each band gets a copy of the totem creature) and weapon
imbues (IMBUE_ENCHANTS: each band gets a copy of the enchantment). Children a script
picks by rank number (Holy Shock, Penance, Fire Nova, Lightning Shield, the Threat of
Thassarian off-hands) get the same new ranks. Mind the id order rule in
families_from_discovery() before adding anything.

Outputs (into --out):
    new_spells.csv         232-column rows for wow.export-main/tools/spell-dbc-append.py
    sla_new.csv            new SkillLineAbility rows (spellbook entries)
    sla_changed.csv        the level-80 ranks' rows with SupercededBySpell pointing at the 81 rank
    new_enchants.csv       SpellItemEnchantment rows of the weapon imbues
    class_ranks.sql        world DB rows (see render_sql)
    families.txt           what was kept and skipped, and why
With --apply-csv the rows are also written into Custom/CSV DBC/Spell.csv and
SkillLineAbility.csv. Re-running replaces the same ids, so it is safe.

Usage:
    python tools/balance/gen_class_ranks.py --class mage --out <dir> [--apply-csv]
    python tools/balance/gen_class_ranks.py --class warrior,paladin,... --out <dir> [--apply-csv]
    python tools/balance/gen_class_ranks.py --class discovered --out <dir>      # every class in the json
"""

import argparse
import csv
import io
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_reference  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SPELL_CSV = ROOT / "Custom" / "CSV DBC" / "Spell.csv"
SLA_CSV = ROOT / "Custom" / "CSV DBC" / "SkillLineAbility.csv"
ENCHANT_CSV = ROOT / "Custom" / "CSV DBC" / "SpellItemEnchantment.csv"
DISCOVERY_JSON = Path(__file__).resolve().parent / "class_rank_discovery.json"
FAMILY_CSV = ROOT / "Custom" / "CSV DBC" / "CreatureFamily.csv"

# A new rank every 6 levels from 81, the pace of WotLK's last levels (owner, 2026-11-15; it was 81/100/130/160).
BANDS = [81, 87, 93, 99, 105, 111, 117, 123, 129, 135, 141, 147, 153, 159]
# Ids: band steps 1-9 sit at base + 10 * index + step; steps 10 and up (the bands added later) in the upper half of
# the same 1000-id block, base + 500 + 10 * index + (step - 9). Steps 1-4 kept the ids they had with four bands.
SECOND_BLOCK = 500
MAX_INDEX = 49
LAST_LEVEL = 255

# Spell effects and aura types whose base points are a damage, heal or absorb amount.
DAMAGE_EFFECTS = {2, 9}                 # SCHOOL_DAMAGE, HEALTH_LEECH
# The flat bonus on a weapon strike (WEAPON_DAMAGE_NOSCHOOL, WEAPON_DAMAGE, NORMALIZED_WEAPON_DMG). It adds to a
# white hit, so it grows like a whole white hit (reference melee_growth) and keeps its share of the hit. Spell
# damage grows like weapon damage instead: base points play the part of the whole weapon there, next to a spell
# power (or attack power) part that grows with gear.
STRIKE_EFFECTS = {17, 58, 121}
HEAL_EFFECTS = {10}                     # HEAL
AURA_EFFECTS = {6, 27, 35, 65, 119, 128, 129, 143}   # APPLY_AURA, PERSISTENT_AREA_AURA, area auras (party, raid,
                                                    # pet, friend, enemy, owner)
DAMAGE_AURAS = {3, 15, 43, 53}          # PERIODIC_DAMAGE, DAMAGE_SHIELD, PROC_TRIGGER_DAMAGE, PERIODIC_LEECH
HEAL_AURAS = {8, 69, 97}                # PERIODIC_HEAL, SCHOOL_ABSORB, MANA_SHIELD

# Flat buffs and debuffs: aura type -> how the amount grows. Negative amounts (Dampen Magic, Demoralizing Shout)
# grow in size as well. "armor" applies only to the armor school of MOD_RESISTANCE; other schools (resistance
# auras) stay flat, resistance being vestigial here.
BUFF_AURAS = {
    22: "armor",            # MOD_RESISTANCE, armor school: Ice Armor, Inner Fire, Devotion Aura, Demon Armor
    29: "stat",             # MOD_STAT (Dalaran Intellect; most stat buffs are percentages on this realm)
    13: "gear",             # MOD_DAMAGE_DONE (flat spell power)
    135: "gear",            # MOD_HEALING_DONE
    99: "gear",             # MOD_ATTACK_POWER
    124: "gear",            # MOD_RANGED_ATTACK_POWER
    127: "gear",            # RANGED_ATTACK_POWER_ATTACKER_BONUS (Hunter's Mark)
    85: "gear",             # MOD_POWER_REGEN (mana per 5 seconds)
    189: "gear",            # MOD_RATING
    34: "heal",             # MOD_INCREASE_HEALTH
    84: "heal",             # MOD_REGEN (health per 5 seconds)
    14: "heal",             # MOD_DAMAGE_TAKEN, flat spell damage taken (Amplify / Dampen Magic): creature spells
                            # grow like player health
    115: "heal",            # MOD_HEALING, flat healing taken (Amplify / Dampen Magic)
}
ARMOR_SCHOOL = 1               # also the physical school of MOD_DAMAGE_DONE: a flat bonus per weapon hit

# A family whose level-80 rank has one of these effects is not extended: resurrect, create item, summon,
# open lock, learn spell, summon pet / object / totem, enchant item, portals.
DENY_EFFECTS = {18, 24, 28, 33, 36, 41, 50, 53, 54, 56, 76, 87, 92, 104, 105, 106, 107, 112, 113, 114, 134}

# Families left out on purpose: the amount lives in a script, so scaled base points would do nothing or harm.
MANUAL_EXCLUDE = {
    48788: "Lay on Hands: the heal is set from maximum health by a script",
    27044: "Aspect of the Hawk: Aspect of the Dragonhawk replaces it",
}

# Scripted spells whose amount sits in an effect that is not an amount type (a dummy, or a trigger that passes
# a value on). Spell id -> {effect index: "damage" | "heal"}.
SCALE_OVERRIDES = {
    47471: {1: "damage"},   # Execute: base damage read by the script
    47475: {1: "strike"},   # Slam: weapon bonus read by the script
    60053: {1: "damage"},   # Explosive Shot: periodic dummy damage
    48156: {3: "damage"},   # Mind Flay: value passed to the damage spell it triggers
    48660: {3: "strike"},   # Hemorrhage: flat extra damage the target takes per hit
    49281: {1: "damage"},   # Lightning Shield: damage per charge
    49284: {1: "heal"},     # Earth Shield: heal per charge
    48451: {2: "heal"},     # Lifebloom: the bloom heal
    49938: {1: "damage"},   # Death and Decay: periodic damage
    57960: {1: "gear"},     # Water Shield: mana per orb, tooltip value (mana pools grow with intellect, i.e. gear)
    57961: {1: "gear"},     # Water Shield: the energize an orb casts, which is what restores the mana
    49895: {1: "damage"},   # Death Coil: damage read by the script (heals undead for 1.5 times it)
    57946: {1: "gear"},     # Life Tap: health turned into mana; sized against the mana pool
    58582: {1: "heal"},     # Stoneclaw Totem: the totem's health (a totem summon's base points set it)
    58591: {1: "heal"},     # Stoneclaw Totem: absorb the script puts on the shaman's totems
    58765: {1: "heal"},     # Healing Stream: tooltip value of the heal per tick
    58761: {1: "heal"},     # Healing Stream: the heal per tick, read by spell_sha_healing_stream_totem
    58792: {1: "damage"},   # Flametongue Weapon (Passive): fire damage basis read by spell_sha_flametongue_weapon
    # Third rollout
    47836: {2: "damage"},   # Seed of Corruption: damage taken before it detonates
    59092: {1: "gear"},     # Dark Pact: mana drained from the pet
    48113: {1: "heal"},     # Prayer of Mending: the heal, passed on with every jump
    51328: {1: "damage"},   # Corpse Explosion: damage passed to the explosion (effect 2 is its spell id)
    47984: {1: "strike"},   # Torment (Voidwalker): threat
    47990: {1: "strike"},   # Suffering (Voidwalker): threat
    47993: {1: "strike"},   # Anguish (Felguard): threat
    # Fourth rollout
    58804: {2: "gear"},     # Windfury Weapon: extra attack power (an effect without a type; spell_sha_windfury_weapon
                            # reads it from the rank whose enchantment is on the weapon)
}

# Families admitted after the first rollout although an override above gives them an amount: they belong to the
# second pass of families_from_discovery, so the ids handed out in the first rollout stay where they are.
LATE_FAMILIES = {57960, 49895, 57946}

# Totems: the summon spell names a creature (EffectMiscValue_1) that casts the totem's spells. Each band gets its
# own copy of the creature, casting the band's copies of those spells (render_sql). Summon spell -> level-80
# creature. Strength of Earth, Windfury and Wrath of Air are percentages and need no ranks; resistance totems
# stay flat.
TOTEM_CREATURES = {
    57722: 30654,   # Totem of Wrath IV
    58582: 31122,   # Stoneclaw Totem X
    58656: 31133,   # Flametongue Totem VIII
    58704: 31165,   # Searing Totem X
    58734: 31167,   # Magma Totem VII
    58753: 31176,   # Stoneskin Totem X
    58757: 31185,   # Healing Stream Totem IX
    58774: 31190,   # Mana Spring Totem VIII
}

# Weapon imbues: the cast spell names a SpellItemEnchantment (EffectMiscValue_1) whose effect argument is the spell
# it applies or procs. Each band gets its own enchantment, numbered like the band's cast spell. Windfury Weapon is
# left out: its extra swings are weapon damage already, and the core reads its attack power bonus from rank 1.
IMBUE_ENCHANTS = {
    58790: 3781,    # Flametongue Weapon -> Flametongue 10
    58796: 3784,    # Frostbrand Weapon -> Frostbrand 9
    51994: 3350,    # Earthliving Weapon -> Earthliving 6
    58804: 3787,    # Windfury Weapon -> Windfury 8 (no child: every rank's enchantment applies the same aura, 33757)
}

# Third rollout (2026-11-15, "finish all classes"): families planned after everything of rollouts 1 and 2, the
# discovery filters do not apply to them (they summon, resurrect or were excluded before).
ROLLOUT3 = {
    47836, 59092,           # warlock: Seed of Corruption, Dark Pact
    48113, 48087,           # priest: Prayer of Mending, Lightwell
    49012, 49056, 49067,    # hunter: Wyvern Sting, Immolation Trap, Explosive Trap
    51328,                  # death knight: Corpse Explosion
    48171, 48950, 49277, 50763, 48477,      # Resurrection, Redemption, Ancestral Spirit, Revive, Rebirth
}

# Fourth rollout (2026-11-15): Windfury Weapon, once its script read the rank on the weapon. Planned after every
# rollout-3 entry of its class.
ROLLOUT4 = {58804}

# Traps: the cast spell summons a trap object (EffectMiscValue_1) whose Data3 is the spell it fires. Each band
# gets its own copy of the object, numbered like the band's spell (render_sql).
TRAP_OBJECTS = {
    49056: 189319,  # Immolation Trap VIII
    49067: 189322,  # Explosive Trap VI
}

# RESURRECT_NEW: base points are the health, the misc value the mana the target comes back with.
RESURRECT_EFFECT = 113

# Children of second-rollout families that discovery cannot see. "rank": the parent's script picks the child by
# its own rank number (GetSpellWithRank), so the child chain needs the same new ranks; past the end of a chain
# GetSpellWithRank returns the chain's top, i.e. the stock level-80 child.
# Top rank -> [(child top rank, link, parent top rank or None for the family's top)].
EXTRA_CHILDREN = {
    48825: [(48823, ("rank", 0), None), (48821, ("rank", 0), None)],               # Holy Shock damage, heal
    53007: [(53003, ("rank", 0), None), (53000, ("trigger", 2), 53003),            # Penance damage channel, bolt
            (52988, ("rank", 0), None), (52985, ("trigger", 2), 52988)],           # Penance heal channel, bolt
    61657: [(61654, ("rank", 0), None)],                                            # Fire Nova -> totem nova
    53201: [(53198, ("trigger", 1), None), (53195, ("points", 1), 53198),          # Starfall: star picker, star,
            (53190, ("trigger", 2), 53195)],                                        # splash
    57960: [(57961, ("trigger", 1), None)],                                         # Water Shield -> orb energize
    # Totems: ("creature", slot) is the totem creature's spell slot (creature_template_spell.Index).
    57722: [(57663, ("creature", 0), None)],                                        # Totem of Wrath: spell power
    58582: [(58591, ("creature", 1), None)],                                        # Stoneclaw: totem absorb
    58656: [(58655, ("creature", 0), None)],                                        # Flametongue Totem
    58704: [(58702, ("creature", 0), None)],                                        # Searing Totem: Attack
    58734: [(58736, ("creature", 0), None), (58735, ("trigger", 1), 58736)],       # Magma: pulse, damage
    58753: [(58754, ("creature", 0), None)],                                        # Stoneskin
    58757: [(58765, ("creature", 0), None), (58761, ("trigger", 1), 58765)],       # Healing Stream: pulse, heal
    58774: [(58777, ("creature", 0), None)],                                        # Mana Spring
    # Imbues: ("enchant", n) is the enchantment effect whose argument names the child.
    58790: [(58792, ("enchant", 1), None)],                                         # Flametongue passive
    58796: [(58799, ("enchant", 1), None)],                                         # Frostbrand Attack
    51994: [(52008, ("enchant", 1), None), (52000, ("trigger", 1), 52008)],        # Earthliving passive, heal
    # Third rollout. ("object", 3): the trap object's Data3 names the child.
    47836: [(47834, ("rank", 0), None)],    # Seed of Corruption -> detonation (spell_warl_seed_of_corruption_dummy)
    49012: [(49010, ("rank", 0), None)],    # Wyvern Sting -> its damage over time (spell_hun_wyvern_sting)
    48087: [(48085, ("rank", 0), None)],    # Lightwell -> Lightwell Renew (spell_pri_lightwell, by summon rank)
    49056: [(49054, ("object", 3), None)],  # Immolation Trap -> the trap's damage over time
    49067: [(49065, ("object", 3), None)],  # Explosive Trap -> the trap's explosion
}

# Rank-picked children of first-rollout families. They were missed in the first rollout, so the new ranks cast
# the stock level-80 child; they are planned after every family so the ids of the first rollout stay put.
LATE_CHILDREN = {
    49281: [(49279, ("rank", 0))],      # Lightning Shield -> its damage (spell_sha_lightning_shield, Static Shock)
    49921: [(66992, ("rank", 0))],      # Threat of Thassarian off-hand strikes (spell_dk_threat_of_thassarian)
    49924: [(66953, ("rank", 0))],
    49930: [(66979, ("rank", 0))],
    51425: [(66974, ("rank", 0))],
    55268: [(66962, ("rank", 0))],
}

# Stock rank chains a script walks from the wrong first rank. The Plague Strike off-hand chain (66988-66992) is
# rooted at 59133, an unrelated Plague Strike with a damage-over-time aura that nothing uses, while
# spell_dk_threat_of_thassarian asks for rank N of 66216, which is in no chain. So Threat of Thassarian always cast
# rank 1 (62 damage instead of 189 at level 80). Re-rooted at 66216 here because the new ranks need the chain.
# First rank the script uses -> (first rank the stock chain has, the chain's spells in rank order).
STOCK_CHAIN_FIXES = {
    66216: (59133, [66216, 66988, 66989, 66990, 66991, 66992]),
}

# Children a family casts through spell_linked_spell instead of a trigger field.
LINKED_CHILDREN = {
    48078: [48076],     # Holy Nova -> its heal
}

ATTR_PASSIVE = 0x40

# ---------------------------------------------------------------------------
# Hand-picked classes. Ids: spell = slot_id(spell_base, index, band number); spellbook rows the
# same from sla_base. A family is {"top": id} plus optional "children": [(child id, (link kind, effect index))].
# Link kinds: "trigger" (EffectTriggerSpell_n names the child), "points" (EffectBasePoints_n = child id - 1),
# "linked" (spell_linked_spell names the child).
# ---------------------------------------------------------------------------
CLASSES = {
    "mage": {
        "spell_base": 921000,
        "sla_base": 30000,
        "families": [
            {"top": 42833},                                                 # Fireball
            {"top": 42842},                                                 # Frostbolt
            {"top": 47610},                                                 # Frostfire Bolt
            {"top": 42897},                                                 # Arcane Blast
            {"top": 44781},                                                 # Arcane Barrage
            {"top": 42921},                                                 # Arcane Explosion
            {"top": 42846, "children": [(42845, ("trigger", 2))]},          # Arcane Missiles
            {"top": 42940, "children": [(42938, ("trigger", 2))]},          # Blizzard
            {"top": 55360, "children": [(55362, ("points", 2))]},           # Living Bomb
            {"top": 42891},                                                 # Pyroblast
            {"top": 42873},                                                 # Fire Blast
            {"top": 42859},                                                 # Scorch
            {"top": 42926},                                                 # Flamestrike
            {"top": 42945},                                                 # Blast Wave
            {"top": 42950},                                                 # Dragon's Breath
            {"top": 42931},                                                 # Cone of Cold
            {"top": 42917},                                                 # Frost Nova
            {"top": 42914},                                                 # Ice Lance
            {"top": 43039},                                                 # Ice Barrier
            {"top": 43020},                                                 # Mana Shield
            {"top": 43010},                                                 # Fire Ward
            {"top": 43012},                                                 # Frost Ward
            # Second rollout (2026-11-15): flat buffs.
            {"top": 43046, "children": [(43044, ("trigger", 1))]},          # Molten Armor (+ its fire damage)
            {"top": 43008},                                                 # Ice Armor
            {"top": 43017},                                                 # Amplify Magic
            {"top": 43015},                                                 # Dampen Magic
            {"top": 61024},                                                 # Dalaran Intellect
            {"top": 61316},                                                 # Dalaran Brilliance
        ],
    },
}

csv.field_size_limit(10 ** 9)


def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader)
        rows = [row for row in reader if row]
    return header, rows


def format_rows(rows):
    buffer = io.StringIO(newline="")
    csv.writer(buffer, quoting=csv.QUOTE_ALL, lineterminator="\n").writerows(rows)
    return buffer.getvalue()


def write_csv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(format_rows([header] + rows))


def parse_float(text):
    return float(text) if text not in ("", None) else 0.0


def parse_int(text):
    return int(text) if text not in ("", None) else 0


COEFFICIENTS_JSON = Path(__file__).resolve().parent / "spell_coefficients.json"

# Spell power of a level-80 character in the reference questing gear (gen_reference: item level 217). Measured on
# 2026-11-15 from the level 75-80 green and blue caster items in item_template (item level ~194): 699 from the
# armour, neck and rings plus ~370 from a one-hander and off-hand, scaled by the gear-stat curve to item level 217.
REFERENCE_SPELL_POWER_80 = 1200.0
# Spell.dbc EffectBonusMultiplier_1..3 (fields 229-231): the CSV names them by position.
BONUS_MULTIPLIER_COLUMNS = ("Field227", "Field228", "Field229")
# Auras whose coefficient is the dot one (per tick, like their base points).
PERIODIC_AURAS = {3, 8, 53}             # PERIODIC_DAMAGE, PERIODIC_HEAL, PERIODIC_LEECH

# Coefficients the core applies in C++ rather than through spell_bonus_data, or through the spell the amount is
# handed to. Spell id -> {effect index: (spell power, attack power)}; combo-point spells at five points.
SCRIPT_COEFFICIENTS = {
    43039: {1: (0.8068, 0.0)},      # Ice Barrier (spell_mage_ice_barrier)
    43010: {1: (0.8068, 0.0)},      # Fire Ward (spell_mage_fire_frost_ward)
    43012: {1: (0.8068, 0.0)},      # Frost Ward
    43020: {1: (0.8053, 0.0)},      # Mana Shield (spell_mage_mana_shield)
    48066: {1: (0.8068, 0.0)},      # Power Word: Shield (spell_pri_power_word_shield)
    47891: {1: (0.8068, 0.0)},      # Shadow Ward (spell_warl_shadow_ward)
    48113: {1: (0.8057, 0.0)},      # Prayer of Mending: the heal it hands on (33110)
    48451: {2: (0.655, 0.0)},       # Lifebloom: the bloom (33778)
    58765: {1: (0.0827, 0.0)},      # Healing Stream: the heal it triggers (52042)
    58761: {1: (0.0827, 0.0)},      # Healing Stream Totem
    47836: {2: (0.2129, 0.0)},      # Seed of Corruption: the detonation (27285)
    49895: {1: (0.0, 0.15)},        # Death Coil: the damage spell (47632)
    49938: {1: (0.0, 0.04805)},     # Death and Decay: the damage spell (52212), per tick
    60053: {1: (0.0, 0.16)},        # Explosive Shot: the damage spell (53352), per tick
    57993: {1: (0.0, 0.09)},        # Envenom: base points x doses plus 9% attack power per combo point
                                    # (Spell::EffectSchoolDMG), so per dose like the base points
    48577: {1: (0.0, 0.35)},        # Ferocious Bite: 7% attack power per combo point (Spell::EffectSchoolDMG)
    49800: {1: (0.0, 0.05)},        # Rip: 1% attack power per combo point per tick (spell_dru_rip)
    48672: {1: (0.0, 0.0375)},      # Rupture: 3.75% attack power per tick at five points (spell_rog_rupture)
}

# Damage or heal effects that keep the plain curve on their base points (the whole-hit rule cannot be sized).
KEEP_PLAIN_GROWTH = {
    61411: "Shield of Righteousness: the block value part is clamped to 29.5-34.5 x level by the core",
}

_coefficient_data = None


def coefficient_data():
    """spell_bonus_data and the rank chains, as dumped by dump_spell_coefficients.py."""
    global _coefficient_data
    if _coefficient_data is None:
        _coefficient_data = json.loads(COEFFICIENTS_JSON.read_text(encoding="utf-8"))
    return _coefficient_data


def spell_coefficients(source, ix, n):
    """(spell power, attack power) coefficient the core applies to effect n of the level-80 rank `source`.

    The core's rule (Unit::SpellDamageBonusDone / SpellHealingBonusDone): a spell_bonus_data row under the spell's
    own id, else under its first rank's, wins; without one a SPELL_DAMAGE_CLASS_NONE spell gets no bonus and any
    other takes Spell.dbc's EffectBonusMultiplier.
    """
    scripted = SCRIPT_COEFFICIENTS.get(parse_int(source[ix["ID"]]), {}).get(n)
    if scripted is not None:
        return scripted
    data = coefficient_data()
    spell_id = str(parse_int(source[ix["ID"]]))
    row = data["bonus"].get(spell_id)
    if row is None and spell_id in data["first_rank"]:
        row = data["bonus"].get(str(data["first_rank"][spell_id]))
    effect = parse_int(source[ix["Effect_%d" % n]])
    periodic = effect in AURA_EFFECTS and parse_int(source[ix["EffectAura_%d" % n]]) in PERIODIC_AURAS
    if row is not None:
        direct, dot, ap, ap_dot = row
        return (max(0.0, dot), max(0.0, ap_dot)) if periodic else (max(0.0, direct), max(0.0, ap))
    if parse_int(source[ix["DefenseType"]]) == 0:
        return 0.0, 0.0
    return max(0.0, parse_float(source[ix[BONUS_MULTIPLIER_COLUMNS[n - 1]]])), 0.0


def attack_power_growth(level):
    return gen_reference.reference_attack_power(level) / gen_reference.reference_attack_power(80)


def whole_hit_growth(target, base_80, spell_power_part, attack_power_part):
    """The factor on a level-80 rank's base points that makes its whole hit grow like `target`.

    A hit is base points plus coefficient x spell power (or attack power). In the reference gear the power part
    grows with gear (gear_growth, or the attack power curve), so the base points carry the rest:
        base(L) = target(L) * (base_80 + part_80) - part_80 * power_growth(L)
    Scaling the base points alone by one curve (as this generator did until 2026-11-15) made a rank grow faster the
    less of its hit was coefficient: totems, Fire Nova and shocks outgrew nukes, and nukes outgrew attack power
    abilities. Never below the level-80 value.
    """
    def growth(level):
        t = target(level)
        extra = ((t - gen_reference.gear_growth(level)) * spell_power_part
                 + (t - attack_power_growth(level)) * attack_power_part)
        return max(1.0, t + extra / base_80)
    return growth


GROWTH = {
    "damage": gen_reference.weapon_growth,
    "strike": gen_reference.melee_growth,
    "heal": gen_reference.health_growth,
    "gear": gen_reference.gear_growth,
    "armor": gen_reference.armor_growth,
    "stat": gen_reference.stat_growth,
}


def buff_growth(effect, aura, misc):
    """The curve of a flat buff or debuff amount, or None."""
    if effect not in AURA_EFFECTS or aura not in BUFF_AURAS:
        return None
    if BUFF_AURAS[aura] == "armor" and not (misc & ARMOR_SCHOOL):
        return None
    if aura == 13 and misc == ARMOR_SCHOOL:
        return GROWTH["strike"]     # Tiger's Fury: flat damage on each weapon hit
    return GROWTH[BUFF_AURAS[aura]]


def growth_function(effect, aura, spell_id=0, n=0):
    """The reference curve an effect's amount follows, or None when it is not an amount."""
    override = SCALE_OVERRIDES.get(spell_id, {}).get(n)
    if override:
        return GROWTH[override]
    if effect in STRIKE_EFFECTS:
        return gen_reference.melee_growth
    if effect in DAMAGE_EFFECTS or (effect in AURA_EFFECTS and aura in DAMAGE_AURAS):
        return gen_reference.weapon_growth
    if effect in HEAL_EFFECTS or (effect in AURA_EFFECTS and aura in HEAL_AURAS) or effect == RESURRECT_EFFECT:
        return gen_reference.health_growth
    return None


def has_amount(row, ix, include_buffs=False):
    for n in (1, 2, 3):
        effect = parse_int(row[ix["Effect_%d" % n]])
        aura = parse_int(row[ix["EffectAura_%d" % n]])
        base = parse_int(row[ix["EffectBasePoints_%d" % n]])
        if growth_function(effect, aura, parse_int(row[ix["ID"]]), n) is not None:
            if base > 0 or parse_float(row[ix["EffectPointsPerCombo_%d" % n]]) > 0:
                return True
        elif include_buffs and buff_growth(effect, aura, parse_int(row[ix["EffectMiscValue_%d" % n]])):
            if abs(base + 1) > 1:
                return True
    return False


def value_at_80(row, ix, n):
    """Base points a level-80 caster gets from effect n, computed the way the server does."""
    base = parse_int(row[ix["EffectBasePoints_%d" % n]])
    per_level = parse_float(row[ix["EffectRealPointsPerLevel_%d" % n]])
    base_level = parse_int(row[ix["BaseLevel"]])
    spell_level = parse_int(row[ix["SpellLevel"]])
    max_level = parse_int(row[ix["MaxLevel"]])
    level = max(80, base_level)
    if max_level > 0:
        level = min(level, max_level)
    return base + per_level * (level - max(base_level, spell_level))


def format_float(value):
    return ("%.2f" % value).rstrip("0").rstrip(".") or "0"


def hit_growth(growth, source, ix, n, combo):
    """Damage and heal effects grow as a whole hit (whole_hit_growth); every other amount keeps its curve.

    Damage targets the white hit's growth (melee_growth), so spells keep the relation to weapon attacks they have
    at level 80; heals and absorbs target player health (health_growth).
    """
    if parse_int(source[ix["ID"]]) in KEEP_PLAIN_GROWTH:
        return growth
    if growth is gen_reference.weapon_growth:
        target = gen_reference.melee_growth
    elif growth is gen_reference.health_growth and parse_int(source[ix["Effect_%d" % n]]) != RESURRECT_EFFECT:
        target = gen_reference.health_growth
    else:
        return growth
    die = parse_int(source[ix["EffectDieSides_%d" % n]])
    # The average level-80 hit's base part: base points plus the average die roll, at five combo points.
    base_80 = value_at_80(source, ix, n) + (die + 1) / 2.0 + 5 * combo
    if base_80 <= 0:
        return target
    spell_power, attack_power = spell_coefficients(source, ix, n)
    return whole_hit_growth(target, base_80, spell_power * REFERENCE_SPELL_POWER_80,
                            attack_power * gen_reference.reference_attack_power(80))


def scale_effects(row, source, ix, band, next_band, whole_hit=True):
    """Rewrite the amount effects of `row` for one band, reading the level-80 values from `source`.

    `source` must be the untouched level-80 rank: `row` already carries the band's levels, and the
    level-80 value depends on the old ones. `whole_hit` False keeps the plain curves (pet abilities: their
    attack power is the pet's, which the player references do not describe).
    """
    for n in (1, 2, 3):
        effect = parse_int(source[ix["Effect_%d" % n]])
        aura = parse_int(source[ix["EffectAura_%d" % n]])
        base = parse_int(source[ix["EffectBasePoints_%d" % n]])
        growth = growth_function(effect, aura, parse_int(source[ix["ID"]]), n)
        if growth is None:
            # A flat buff grows in size whatever its sign; a value of 0 (base points -1, one die side) stays.
            growth = buff_growth(effect, aura, parse_int(source[ix["EffectMiscValue_%d" % n]]))
            if growth is None or abs(base + 1) <= 1:
                continue
        else:
            combo = parse_float(source[ix["EffectPointsPerCombo_%d" % n]])
            if whole_hit:
                growth = hit_growth(growth, source, ix, n, combo)
            if combo > 0:
                row[ix["EffectPointsPerCombo_%d" % n]] = format_float(combo * growth(band))
            if base <= 0:
                continue
        at80 = value_at_80(source, ix, n)
        die = parse_int(source[ix["EffectDieSides_%d" % n]])
        row[ix["EffectBasePoints_%d" % n]] = str(int(round(at80 * growth(band))))
        if die > 1:
            row[ix["EffectDieSides_%d" % n]] = str(max(1, int(round(die * growth(band)))))
        per_level = at80 * (growth(next_band) - growth(band)) / (next_band - band)
        row[ix["EffectRealPointsPerLevel_%d" % n]] = format_float(per_level)
        if effect == RESURRECT_EFFECT:
            # The mana a resurrection gives back has no per-level growth: it steps with the band.
            mana = parse_int(source[ix["EffectMiscValue_%d" % n]])
            row[ix["EffectMiscValue_%d" % n]] = str(int(round(mana * GROWTH["gear"](band))))


def remap_tokens(text, id_map):
    """$42845s1 -> $921071s1 for every id of the family; other text is left alone."""
    if not text:
        return text
    return re.sub(r"\$(\d+)(?=[a-zA-Z])", lambda m: "$" + str(id_map.get(int(m.group(1)), m.group(1))), text)


def rank_number(text):
    match = re.match(r"^Rank (\d+)$", text or "")
    return int(match.group(1)) if match else None


def families_from_discovery(entry, by_id, ix, report):
    """The discovered level-80 ranks of one class, filtered to the ones worth a new rank.

    Ids follow plan order, so they stay stable only if each rollout adds behind the previous one:
      1. first rollout (2026-11-15): families with a damage, heal or absorb amount, with their children;
      2. second rollout (2026-11-15): families only the later rules admit (flat buffs, EXTRA_CHILDREN,
         LATE_FAMILIES), then LATE_CHILDREN of first-rollout families;
      3. third rollout (2026-11-15): ROLLOUT3 families ("rollout": 3), which plan() puts after the late
         children. A fourth rollout must come after all of that.
    """
    first, second, third, skipped = [], [], [], []
    for top, _level, triggers in entry["families"]:
        source = by_id.get(str(top))
        name = source[ix["Name_Lang_enUS"]] if source else "?"
        reason = None
        rollout3 = top in ROLLOUT3 or top in ROLLOUT4
        if source is None:
            reason = "not in Spell.csv"
        elif top in MANUAL_EXCLUDE:
            reason = MANUAL_EXCLUDE[top]
        elif not rollout3 and parse_int(source[ix["Attributes"]]) & ATTR_PASSIVE:
            reason = "passive"
        elif not rollout3 and top not in TOTEM_CREATURES and top not in IMBUE_ENCHANTS and any(
                parse_int(source[ix["Effect_%d" % n]]) in DENY_EFFECTS for n in (1, 2, 3)):
            reason = "summons, creates, enchants, teaches or resurrects"
        elif rank_number(source[ix["NameSubtext_Lang_enUS"]]) is None:
            reason = "no 'Rank N' text"
        if reason:
            skipped.append("  skip %6d %-28s %s" % (top, name, reason))
            continue

        children = []
        links = [(child, ("trigger", n)) for n, child in (triggers or [])]
        links += [(child, ("linked", 0)) for child in LINKED_CHILDREN.get(top, [])]
        for child, link in links:
            child_row = by_id.get(str(child))
            if child_row is not None and has_amount(child_row, ix):
                children.append((child, link, None))
        late = top in LATE_FAMILIES or top in TOTEM_CREATURES or top in IMBUE_ENCHANTS
        if rollout3:
            third.append(({"top": top, "children": children + list(EXTRA_CHILDREN.get(top, [])),
                           "rollout": 4 if top in ROLLOUT4 else 3}, name))
        elif not late and (has_amount(source, ix) or children):
            first.append(({"top": top, "children": children, "late_children": LATE_CHILDREN.get(top, [])}, name))
        elif top in EXTRA_CHILDREN:
            second.append(({"top": top, "children": children + list(EXTRA_CHILDREN[top])}, name))
        elif has_amount(source, ix, include_buffs=True) or children:
            second.append(({"top": top, "children": children}, name))
        else:
            skipped.append("  skip %6d %-28s no damage, heal, absorb or buff amount" % (top, name))

    for family, name in first + second + third:
        report.append("  keep %6d %-28s %s" % (family["top"], name, ", ".join(
            ["+%d (%s)" % (child, link[0]) for child, link, _parent in family["children"]]
            + ["+%d (%s, late)" % (child, link[0]) for child, link in family.get("late_children", [])])))
    report.extend(skipped)
    return {"spell_base": entry["spell_base"], "sla_base": entry["sla_base"],
            "families": [family for family, _name in first + second + third]}


def plan(config):
    """Entries in id order, every child right after its parent."""
    entries = []
    late = []

    def add(family):
        parent_index = len(entries)
        late.extend((parent_index, child) for child in family.get("late_children", []))
        entries.append({"index": parent_index, "top": family["top"], "parent": None, "link": None})
        children = [tuple(child) + (None,) * (3 - len(child)) for child in family.get("children", [])]
        if family.get("child"):
            children.append((family["child"], family["link"], None))
        index_by_top = {family["top"]: parent_index}
        for child, link, parent_top in children:
            index_by_top[child] = len(entries)
            entries.append({"index": len(entries), "top": child, "link": link,
                            "parent": index_by_top[parent_top] if parent_top else parent_index})

    for family in config["families"]:
        if family.get("rollout", 1) < 3:
            add(family)
    for parent_index, (child, link) in late:
        entries.append({"index": len(entries), "top": child, "link": link, "parent": parent_index})
    for rollout in sorted({family.get("rollout", 1) for family in config["families"]} - {1, 2}):
        for family in config["families"]:
            if family.get("rollout", 1) == rollout:
                add(family)
    return entries


def slot_id(base, index, step):
    """The id of band `step` (1-based) of entry `index` in the block starting at `base`."""
    assert 0 <= index <= MAX_INDEX, "index %d does not fit the id block" % index
    assert 1 <= step <= 18
    if step <= 9:
        return base + 10 * index + step
    return base + SECOND_BLOCK + 10 * index + (step - 9)


def new_id(config, index, step):
    return slot_id(config["spell_base"], index, step)


def build_spells(config, header, by_id):
    ix = {name: position for position, name in enumerate(header)}
    entries = plan(config)
    string_columns = [position for name, position in ix.items() if "_Lang_" in name and not name.endswith("_Mask")]
    out = []
    for step, band in enumerate(BANDS, start=1):
        next_band = BANDS[step] if step < len(BANDS) else LAST_LEVEL
        # Every level-80 id of the planned families maps to its id in this band.
        id_map = {entry["top"]: new_id(config, entry["index"], step) for entry in entries}
        for entry in entries:
            source = by_id[str(entry["top"])]
            assert len(source) == len(header), "spell %d has %d cells" % (entry["top"], len(source))
            row = list(source)
            row[ix["ID"]] = str(id_map[entry["top"]])
            row[ix["SpellLevel"]] = str(band)
            row[ix["BaseLevel"]] = str(band)
            row[ix["MaxLevel"]] = "0"
            rank = rank_number(source[ix["NameSubtext_Lang_enUS"]])
            assert rank is not None or entry["parent"] is not None, "spell %d has no rank text" % entry["top"]
            if rank is not None:
                row[ix["NameSubtext_Lang_enUS"]] = "Rank %d" % (rank + step)
            scale_effects(row, source, ix, band, next_band, whole_hit=not config.get("pet"))
            for links, what in ((TOTEM_CREATURES, "creature"), (IMBUE_ENCHANTS, "enchantment"),
                                (TRAP_OBJECTS, "object")):
                if entry["top"] in links:
                    # The band's creature / enchantment is numbered like the band's spell.
                    assert parse_int(source[ix["EffectMiscValue_1"]]) == links[entry["top"]], \
                        "spell %d does not name %s %d" % (entry["top"], what, links[entry["top"]])
                    row[ix["EffectMiscValue_1"]] = str(id_map[entry["top"]])
            for child in entries:
                if child["parent"] != entry["index"]:
                    continue
                kind, effect_index = child["link"]
                child_id = id_map[child["top"]]
                if kind == "trigger":
                    assert parse_int(source[ix["EffectTriggerSpell_%d" % effect_index]]) == child["top"]
                    row[ix["EffectTriggerSpell_%d" % effect_index]] = str(child_id)
                elif kind == "rank":
                    # The parent's script asks for the child of its own rank number.
                    assert rank_number(by_id[str(child["top"])][ix["NameSubtext_Lang_enUS"]]) == \
                        rank_number(source[ix["NameSubtext_Lang_enUS"]]), "rank mismatch %d" % child["top"]
                elif kind == "points":
                    # Base points name the spell as id - 1 (EffectDieSides 1 adds the 1 back).
                    assert parse_int(source[ix["EffectBasePoints_%d" % effect_index]]) + 1 == child["top"]
                    row[ix["EffectBasePoints_%d" % effect_index]] = str(child_id - 1)
                # "linked": spell_linked_spell names the child; render_sql remaps it.
                # "creature": the totem creature's spell slot; render_sql copies the creature.
                # "enchant": the enchantment's argument; build_enchants copies the enchantment.
                # "object": the trap object's Data3; render_sql copies the object.
            for position in string_columns:
                row[position] = remap_tokens(row[position], id_map)
            out.append(row)
    return out


def build_sla(config, header, rows, report):
    assert header[:3] == ["ID", "SkillLine", "Spell"] and "SupercededBySpell" in header
    ix = {name: position for position, name in enumerate(header)}
    by_spell = {}
    for row in rows:
        by_spell.setdefault(row[ix["Spell"]], []).append(row)
    new_rows, changed = [], []
    next_pet_id = config["sla_base"]
    for entry in plan(config):
        sources = by_spell.get(str(entry["top"]), [])
        if config.get("pet"):
            # A pet ability has a row on every pet family's skill line that learns it (Bite: 18). The pet learns
            # the new rank at its spell level through those rows (SpellMgr::LoadPetLevelupSpellMap).
            sources = [row for row in sources if parse_int(row[ix["AcquireMethod"]]) == PET_ACQUIRE_METHOD]
            for source in sources:
                top_row = list(source)
                top_row[ix["SupercededBySpell"]] = str(new_id(config, entry["index"], 1))
                changed.append(top_row)
            for step in range(1, len(BANDS) + 1):
                for source in sources:
                    next_pet_id += 1
                    row = list(source)
                    row[ix["ID"]] = str(next_pet_id)
                    row[ix["Spell"]] = str(new_id(config, entry["index"], step))
                    row[ix["SupercededBySpell"]] = (str(new_id(config, entry["index"], step + 1))
                                                    if step < len(BANDS) else "0")
                    new_rows.append(row)
            continue
        if not sources:
            if entry["parent"] is None:
                report.append("  note %6d has no SkillLineAbility row: its new ranks show in the General tab"
                              % entry["top"])
            continue
        # Stock has a few spells with two rows (Inner Fire: one with the class mask, one without). Every row of
        # the level-80 rank points at the 81 rank; the new ranks copy the row that names the class.
        assert len(sources) <= 2, "spell %d has %d SkillLineAbility rows" % (entry["top"], len(sources))
        for source in sources:
            top_row = list(source)
            top_row[ix["SupercededBySpell"]] = str(new_id(config, entry["index"], 1))
            changed.append(top_row)
        source = max(sources, key=lambda row: parse_int(row[ix["ClassMask"]]) != 0)
        for step in range(1, len(BANDS) + 1):
            row = list(source)
            row[ix["ID"]] = str(slot_id(config["sla_base"], entry["index"], step))
            row[ix["Spell"]] = str(new_id(config, entry["index"], step))
            row[ix["SupercededBySpell"]] = str(new_id(config, entry["index"], step + 1)) if step < len(BANDS) else "0"
            new_rows.append(row)
    return new_rows, changed


def roman(number):
    out = ""
    for value, letters in ((10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")):
        while number >= value:
            out += letters
            number -= value
    return out


def build_totems(config, header, by_id):
    """(new creature, level-80 creature, band step, name) for every totem of the plan."""
    ix = {name: position for position, name in enumerate(header)}
    out = []
    for entry in plan(config):
        if entry["parent"] is not None or entry["top"] not in TOTEM_CREATURES:
            continue
        source = by_id[str(entry["top"])]
        rank = rank_number(source[ix["NameSubtext_Lang_enUS"]])
        for step in range(1, len(BANDS) + 1):
            name = "%s %s" % (source[ix["Name_Lang_enUS"]], roman(rank + step))
            assert "'" not in name and "\\" not in name
            out.append((new_id(config, entry["index"], step), TOTEM_CREATURES[entry["top"]], step, name))
    return out


def build_traps(config, header, by_id):
    """(new object, level-80 object, band step, name) for every trap of the plan."""
    ix = {name: position for position, name in enumerate(header)}
    out = []
    for entry in plan(config):
        if entry["parent"] is not None or entry["top"] not in TRAP_OBJECTS:
            continue
        source = by_id[str(entry["top"])]
        rank = rank_number(source[ix["NameSubtext_Lang_enUS"]])
        for step in range(1, len(BANDS) + 1):
            name = "%s %s" % (source[ix["Name_Lang_enUS"]], roman(rank + step))
            assert "'" not in name and "\\" not in name
            out.append((new_id(config, entry["index"], step), TRAP_OBJECTS[entry["top"]], step, name))
    return out


# Pet abilities: the pets of a class learn their ranks from SkillLineAbility rows on the pet family's skill lines
# (AcquireMethod 2), at the rank's spell level. Pseudo-classes for --class: warlock_pet, hunter_pet.
PET_ACQUIRE_METHOD = 2
WARLOCK_PET_FAMILIES = {15, 16, 17, 23, 29}     # Felhunter, Voidwalker, Succubus, Imp, Felguard
PET_CLASSES = {
    "warlock_pet": {"spell_base": 931000, "sla_base": 50000},
    "hunter_pet": {"spell_base": 932000, "sla_base": 51000},
}
PET_MIN_TOP_LEVEL = 60          # level-80 ranks; a pet ability whose last rank comes earlier is left alone


def pet_configs(names, by_id, ix, sla_header, sla_rows, report):
    """Family lists for the pet pseudo-classes, read from CreatureFamily.csv and SkillLineAbility.csv."""
    family_header, family_rows = read_csv(FAMILY_CSV)
    fx = {name: position for position, name in enumerate(family_header)}
    sx = {name: position for position, name in enumerate(sla_header)}
    owner_of_skill = {}
    for row in family_rows:
        owner = "warlock_pet" if parse_int(row[0]) in WARLOCK_PET_FAMILIES else (
            "hunter_pet" if parse_int(row[fx["PetTalentType"]]) >= 0 else None)
        for column in ("SkillLine_1", "SkillLine_2"):
            if owner and parse_int(row[fx[column]]):
                owner_of_skill[row[fx[column]]] = owner
    by_name = {}
    for row in sla_rows:
        owner = owner_of_skill.get(row[sx["SkillLine"]])
        if owner and parse_int(row[sx["AcquireMethod"]]) == PET_ACQUIRE_METHOD and row[sx["Spell"]] in by_id:
            spell = by_id[row[sx["Spell"]]]
            if 1 <= parse_int(row[sx["Spell"]]) < 900000:
                by_name.setdefault((owner, spell[ix["Name_Lang_enUS"]]), set()).add(parse_int(row[sx["Spell"]]))
    configs = {}
    for name in names:
        report.append(name)
        families = []
        for (owner, spell_name), ids in sorted(by_name.items(), key=lambda item: max(item[1])):
            if owner != name:
                continue
            top = max(ids, key=lambda spell_id: (parse_int(by_id[str(spell_id)][ix["SpellLevel"]]), spell_id))
            source = by_id[str(top)]
            level = parse_int(source[ix["SpellLevel"]])
            if level < PET_MIN_TOP_LEVEL or rank_number(source[ix["NameSubtext_Lang_enUS"]]) is None:
                continue
            if parse_int(source[ix["Attributes"]]) & ATTR_PASSIVE:
                continue
            children = []
            for n in (1, 2, 3):
                child = parse_int(source[ix["EffectTriggerSpell_%d" % n]])
                child_row = by_id.get(str(child))
                if child and child_row is not None and has_amount(child_row, ix, include_buffs=True):
                    children.append((child, ("trigger", n), None))
            if not has_amount(source, ix, include_buffs=True) and not children:
                report.append("  skip %6d %-28s no amount" % (top, spell_name))
                continue
            families.append({"top": top, "children": children})
            report.append("  keep %6d %-28s %s" % (top, spell_name, ", ".join(
                "+%d (%s)" % (child, link[0]) for child, link, _parent in children)))
        configs[name] = dict(PET_CLASSES[name], pet=True, families=families)
    return configs


def build_enchants(config, enchant_header, enchant_by_id):
    """New SpellItemEnchantment rows: the level-80 imbue's enchantment, pointing at the band's spell."""
    ex = {name: position for position, name in enumerate(enchant_header)}
    entries = plan(config)
    out, pairs = [], []
    for entry in entries:
        if entry["parent"] is not None or entry["top"] not in IMBUE_ENCHANTS:
            continue
        old = IMBUE_ENCHANTS[entry["top"]]
        source = enchant_by_id[str(old)]
        children = [child for child in entries if child["parent"] == entry["index"] and child["link"][0] == "enchant"]
        assert len(children) <= 1, "imbue %d has more than one enchant child" % entry["top"]
        child = children[0] if children else None
        if child is not None:
            arg = "EffectArg_%d" % child["link"][1]
            assert parse_int(source[ex[arg]]) == child["top"], "enchantment %d does not name %d" % (old, child["top"])
        match = re.match(r"^(.*\D)(\d+)$", source[ex["Name_Lang_enUS"]])
        assert match, "enchantment %d has no rank number in its name" % old
        for step in range(1, len(BANDS) + 1):
            row = list(source)
            row[ex["ID"]] = str(new_id(config, entry["index"], step))
            if child is not None:
                row[ex[arg]] = str(new_id(config, child["index"], step))
            row[ex["Name_Lang_enUS"]] = "%s%d" % (match.group(1), int(match.group(2)) + step)
            out.append(row)
            pairs.append((new_id(config, entry["index"], step), old))
    return out, pairs


def render_sql(title, configs, totems=(), enchant_pairs=(), traps=()):
    values = []
    families = 0
    for config in configs:
        entries = plan(config)
        families += sum(1 for entry in entries if entry["parent"] is None)
        for entry in entries:
            for step, band in enumerate(BANDS, start=1):
                prev = entry["top"] if step == 1 else new_id(config, entry["index"], step - 1)
                values.append("(%d, %d, %d, %d, %d, %d, %.4f)" % (
                    new_id(config, entry["index"], step), entry["top"], step, band, prev,
                    1 if entry["parent"] is None else 0, gen_reference.melee_growth(band)))
    lo = min(config["spell_base"] for config in configs)
    hi = max(config["spell_base"] for config in configs) + 999
    m = "`dc_tmp_rank_map`"
    out = []
    out.append("-- DarkChaos: class spell ranks for levels 81-255 (generated by tools/balance/gen_class_ranks.py)")
    out.append("-- Classes: %s." % title)
    out.append("--")
    out.append("-- %d spell families get one new rank per band, learned at levels" % families)
    out.append("-- %s." % ", ".join(str(b) for b in BANDS))
    out.append("-- Spell ids %d-%d; their Spell.dbc and SkillLineAbility.dbc rows ship with this file (the server needs"
               % (lo, hi))
    out.append("-- both DBC files before it).")
    out.append("-- A whole damage hit (base points plus the coefficient part) grows like a white hit, a heal or")
    out.append("-- absorb like player health (tools/balance/gen_reference.py);")
    out.append("-- flat buffs grow with gear (spell power, attack power, mana per 5), stats, health or the armor formula;")
    out.append("-- coefficients, costs and spell class masks are the level-80 rank's. The level-80 ranks are not changed.")
    out.append("-- Totems get a copy of their creature per band, traps a copy of their object, weapon imbues a copy")
    out.append("-- of their enchantment (SpellItemEnchantment.dbc rows ship with this file too). Pet abilities")
    out.append("-- (warlock_pet, hunter_pet) are learned by the pets at the band level, without a trainer.")
    out.append("--")
    out.append("-- For every new rank this file adds: the rank chain (spell_ranks); the trainer offer (every trainer that")
    out.append("-- teaches the level-80 rank, at the band level, previous rank required, same price); the spell power")
    out.append("-- coefficient (spell_bonus_data, copied from the row the core uses for the level-80 rank); and copies")
    out.append("-- of the rows the level-80 rank has under its own id: spell_script_names, spell_custom_attr,")
    out.append("-- spell_threat (flat threat grown like a white hit) and spell_linked_spell (a linked child moves to the")
    out.append("-- same band's copy).")
    out.append("-- Re-running gives the same result. Apply to acore_world, then restart the worldserver.")
    out.append("")
    out.append("DROP TEMPORARY TABLE IF EXISTS %s;" % m)
    out.append("CREATE TEMPORARY TABLE %s (`new_id` INT NOT NULL PRIMARY KEY, `top_id` INT NOT NULL, "
               "`step` TINYINT UNSIGNED NOT NULL, `band` TINYINT UNSIGNED NOT NULL, `prev_id` INT NOT NULL, "
               "`is_parent` TINYINT UNSIGNED NOT NULL, `growth` FLOAT NOT NULL, "
               "`bonus_src` INT NOT NULL DEFAULT 0) ENGINE=InnoDB;" % m)
    out.append("DELETE FROM %s;" % m)
    out.append("INSERT INTO %s (`new_id`, `top_id`, `step`, `band`, `prev_id`, `is_parent`, `growth`) VALUES" % m)
    for position, value in enumerate(values):
        out.append(value + (";" if position == len(values) - 1 else ","))
    out.append("-- A second copy: a temporary table can be named only once per statement.")
    out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_rank_map2`;")
    out.append("CREATE TEMPORARY TABLE `dc_tmp_rank_map2` ENGINE=InnoDB SELECT `new_id`, `top_id`, `step` FROM %s;" % m)
    out.append("")
    planned = {entry["top"] for config in configs for entry in plan(config)}
    for first, (stock_first, chain) in STOCK_CHAIN_FIXES.items():
        if chain[-1] not in planned:
            continue
        out.append("-- Stock chain fix: a script walks the ranks of %d, but stock roots that chain at %d." % (first,
                                                                                                        stock_first))
        out.append("-- Re-rooted at %d (the rank chain below adds the new ranks to it again)." % first)
        out.append("DELETE FROM `spell_ranks` WHERE `first_spell_id` IN (%d, %d);" % (stock_first, first))
        out.append("INSERT INTO `spell_ranks` (`first_spell_id`, `spell_id`, `rank`) VALUES %s;" % ", ".join(
            "(%d, %d, %d)" % (first, spell, rank) for rank, spell in enumerate(chain, start=1)))
        out.append("")
    out.append("-- Rank chain")
    out.append("DELETE FROM `spell_ranks` WHERE `spell_id` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `spell_ranks` (`first_spell_id`, `spell_id`, `rank`) SELECT `r`.`first_spell_id`, "
               "`m`.`new_id`, `r`.`rank` + `m`.`step` FROM %s AS `m` "
               "JOIN `spell_ranks` AS `r` ON `r`.`spell_id` = `m`.`top_id`;" % m)
    out.append("")
    out.append("-- Trainer offers")
    out.append("DELETE FROM `trainer_spell` WHERE `SpellId` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, "
               "`ReqAbility1`, `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`) SELECT `t`.`TrainerId`, "
               "`m`.`new_id`, `t`.`MoneyCost`, `t`.`ReqSkillLine`, `t`.`ReqSkillRank`, `m`.`prev_id`, "
               "`t`.`ReqAbility2`, `t`.`ReqAbility3`, `m`.`band`, 0 FROM %s AS `m` "
               "JOIN `trainer_spell` AS `t` ON `t`.`SpellId` = `m`.`top_id` WHERE `m`.`is_parent` = 1;" % m)
    out.append("")
    out.append("-- Spell power coefficients: the core looks a spell up by its own id, then by its first rank's.")
    out.append("UPDATE %s SET `bonus_src` = `top_id` WHERE `top_id` IN (SELECT `entry` FROM `spell_bonus_data`);" % m)
    out.append("UPDATE %s AS `m` JOIN `spell_ranks` AS `r` ON `r`.`spell_id` = `m`.`top_id` "
               "SET `m`.`bonus_src` = `r`.`first_spell_id` WHERE `m`.`bonus_src` = 0 "
               "AND `r`.`first_spell_id` IN (SELECT `entry` FROM `spell_bonus_data`);" % m)
    out.append("DELETE FROM `spell_bonus_data` WHERE `entry` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `spell_bonus_data` (`entry`, `direct_bonus`, `dot_bonus`, `ap_bonus`, `ap_dot_bonus`, "
               "`comments`) SELECT `m`.`new_id`, `b`.`direct_bonus`, `b`.`dot_bonus`, `b`.`ap_bonus`, "
               "`b`.`ap_dot_bonus`, `b`.`comments` FROM %s AS `m` "
               "JOIN `spell_bonus_data` AS `b` ON `b`.`entry` = `m`.`bonus_src`;" % m)
    out.append("")
    out.append("-- Rows registered under the level-80 rank's own id")
    out.append("DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) SELECT `m`.`new_id`, `s`.`ScriptName` "
               "FROM %s AS `m` JOIN `spell_script_names` AS `s` ON `s`.`spell_id` = `m`.`top_id`;" % m)
    out.append("DELETE FROM `spell_custom_attr` WHERE `spell_id` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `spell_custom_attr` (`spell_id`, `attributes`) SELECT `m`.`new_id`, `a`.`attributes` "
               "FROM %s AS `m` JOIN `spell_custom_attr` AS `a` ON `a`.`spell_id` = `m`.`top_id`;" % m)
    out.append("DELETE FROM `spell_threat` WHERE `entry` BETWEEN %d AND %d;" % (lo, hi))
    out.append("INSERT INTO `spell_threat` (`entry`, `flatMod`, `pctMod`, `apPctMod`) SELECT `m`.`new_id`, "
               "`t`.`flatMod` * `m`.`growth`, `t`.`pctMod`, `t`.`apPctMod` FROM %s AS `m` "
               "JOIN `spell_threat` AS `t` ON `t`.`entry` = `m`.`top_id`;" % m)
    out.append("DELETE FROM `spell_linked_spell` WHERE `spell_trigger` BETWEEN %d AND %d "
               "OR `spell_trigger` BETWEEN -%d AND -%d;" % (lo, hi, hi, lo))
    out.append("INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) SELECT "
               "CASE WHEN `l`.`spell_trigger` < 0 THEN -`m`.`new_id` ELSE `m`.`new_id` END, "
               "CASE WHEN `c`.`new_id` IS NULL THEN `l`.`spell_effect` ELSE `c`.`new_id` END, `l`.`type`, "
               "`l`.`comment` FROM %s AS `m` JOIN `spell_linked_spell` AS `l` "
               "ON `l`.`spell_trigger` IN (`m`.`top_id`, -`m`.`top_id`) LEFT JOIN `dc_tmp_rank_map2` AS `c` "
               "ON `c`.`top_id` = `l`.`spell_effect` AND `c`.`step` = `m`.`step`;" % m)
    if enchant_pairs:
        out.append("")
        out.append("-- Weapon imbue enchantments: the proc rate of the level-80 enchantment, if it has one")
        # By id: the poison enchantments of gen_class_items.py (922101-922134) sit inside this file's id range.
        out.append("DELETE FROM `spell_enchant_proc_data` WHERE `entry` IN (%s);"
                   % ", ".join(str(new) for new, _old in enchant_pairs))
        out.append("INSERT INTO `spell_enchant_proc_data` (`entry`, `customChance`, `PPMChance`, `procEx`, "
                   "`attributeMask`) SELECT `e`.`new_id`, `p`.`customChance`, `p`.`PPMChance`, `p`.`procEx`, "
                   "`p`.`attributeMask` FROM (%s) AS `e` JOIN `spell_enchant_proc_data` AS `p` "
                   "ON `p`.`entry` = `e`.`old_id`;" % " UNION ALL ".join(
                       ("SELECT %d AS `new_id`, %d AS `old_id`" if position == 0 else "SELECT %d, %d")
                       % pair for position, pair in enumerate(enchant_pairs)))
    if totems:
        t = "`dc_tmp_totem_map`"
        out.append("")
        out.append("-- Totem creatures: one copy of the level-80 totem per band, numbered like the band's summon spell")
        out.append("-- and casting the band's copies of its spells. The creatures' ids share the spell id range.")
        out.append("DROP TEMPORARY TABLE IF EXISTS %s;" % t)
        out.append("CREATE TEMPORARY TABLE %s (`new_entry` INT UNSIGNED NOT NULL PRIMARY KEY, `old_entry` INT "
                   "UNSIGNED NOT NULL, `step` TINYINT UNSIGNED NOT NULL, `name` VARCHAR(100) NOT NULL) "
                   "ENGINE=InnoDB;" % t)
        out.append("DELETE FROM %s;" % t)
        out.append("INSERT INTO %s (`new_entry`, `old_entry`, `step`, `name`) VALUES" % t)
        for position, (new_entry, old_entry, step, name) in enumerate(totems):
            out.append("(%d, %d, %d, '%s')%s" % (new_entry, old_entry, step, name,
                                                 ";" if position == len(totems) - 1 else ","))
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_totem_template`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_totem_template` ENGINE=InnoDB SELECT `t`.`new_entry` AS "
                   "`dc_new_entry`, `t`.`name` AS `dc_new_name`, `ct`.* FROM %s AS `t` JOIN `creature_template` "
                   "AS `ct` ON `ct`.`entry` = `t`.`old_entry`;" % t)
        out.append("UPDATE `dc_tmp_totem_template` SET `entry` = `dc_new_entry`, `name` = `dc_new_name`;")
        out.append("ALTER TABLE `dc_tmp_totem_template` DROP COLUMN `dc_new_entry`, DROP COLUMN `dc_new_name`;")
        out.append("-- REPLACE, not DELETE + INSERT: the codestyle rules never delete creature_template rows, and these")
        out.append("-- ids belong to this file alone.")
        out.append("REPLACE INTO `creature_template` SELECT * FROM `dc_tmp_totem_template`;")
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_totem_addon`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_totem_addon` ENGINE=InnoDB SELECT `t`.`new_entry` AS "
                   "`dc_new_entry`, `a`.* FROM %s AS `t` JOIN `creature_template_addon` AS `a` "
                   "ON `a`.`entry` = `t`.`old_entry`;" % t)
        out.append("UPDATE `dc_tmp_totem_addon` SET `entry` = `dc_new_entry`;")
        out.append("ALTER TABLE `dc_tmp_totem_addon` DROP COLUMN `dc_new_entry`;")
        out.append("DELETE FROM `creature_template_addon` WHERE `entry` BETWEEN %d AND %d;" % (lo, hi))
        out.append("INSERT INTO `creature_template_addon` SELECT * FROM `dc_tmp_totem_addon`;")
        out.append("DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN %d AND %d;" % (lo, hi))
        out.append("INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, "
                   "`Probability`, `VerifiedBuild`) SELECT `t`.`new_entry`, `m`.`Idx`, `m`.`CreatureDisplayID`, "
                   "`m`.`DisplayScale`, `m`.`Probability`, 0 FROM %s AS `t` JOIN `creature_template_model` AS `m` "
                   "ON `m`.`CreatureID` = `t`.`old_entry`;" % t)
        out.append("DELETE FROM `creature_template_spell` WHERE `CreatureID` BETWEEN %d AND %d;" % (lo, hi))
        out.append("INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`, `VerifiedBuild`) SELECT "
                   "`t`.`new_entry`, `s`.`Index`, CASE WHEN `r`.`new_id` IS NULL THEN `s`.`Spell` ELSE `r`.`new_id` "
                   "END, 0 FROM %s AS `t` JOIN `creature_template_spell` AS `s` ON `s`.`CreatureID` = `t`.`old_entry` "
                   "LEFT JOIN `dc_tmp_rank_map2` AS `r` ON `r`.`top_id` = `s`.`Spell` AND `r`.`step` = `t`.`step`;" % t)
        out.append("DROP TEMPORARY TABLE `dc_tmp_totem_addon`;")
        out.append("DROP TEMPORARY TABLE `dc_tmp_totem_template`;")
        out.append("DROP TEMPORARY TABLE %s;" % t)
    if traps:
        t = "`dc_tmp_trap_map`"
        out.append("")
        out.append("-- Trap objects: one copy of the level-80 trap per band, numbered like the band's trap spell and")
        out.append("-- firing the band's copy of the trap's spell (Data3).")
        out.append("DROP TEMPORARY TABLE IF EXISTS %s;" % t)
        out.append("CREATE TEMPORARY TABLE %s (`new_entry` INT UNSIGNED NOT NULL PRIMARY KEY, `old_entry` INT "
                   "UNSIGNED NOT NULL, `step` TINYINT UNSIGNED NOT NULL, `name` VARCHAR(100) NOT NULL) "
                   "ENGINE=InnoDB;" % t)
        out.append("DELETE FROM %s;" % t)
        out.append("INSERT INTO %s (`new_entry`, `old_entry`, `step`, `name`) VALUES %s;" % (t, ", ".join(
            "(%d, %d, %d, '%s')" % row for row in traps)))
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_trap_template`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_trap_template` ENGINE=InnoDB SELECT `t`.`new_entry` AS "
                   "`dc_new_entry`, `t`.`name` AS `dc_new_name`, `t`.`step` AS `dc_step`, `g`.* FROM %s AS `t` "
                   "JOIN `gameobject_template` AS `g` ON `g`.`entry` = `t`.`old_entry`;" % t)
        out.append("UPDATE `dc_tmp_trap_template` AS `g` JOIN `dc_tmp_rank_map2` AS `r` ON `r`.`top_id` = `g`.`Data3` "
                   "AND `r`.`step` = `g`.`dc_step` SET `g`.`entry` = `g`.`dc_new_entry`, `g`.`name` = `g`.`dc_new_name`, "
                   "`g`.`Data3` = `r`.`new_id`;")
        out.append("ALTER TABLE `dc_tmp_trap_template` DROP COLUMN `dc_new_entry`, DROP COLUMN `dc_new_name`, "
                   "DROP COLUMN `dc_step`;")
        out.append("-- REPLACE, not DELETE + INSERT: the codestyle rules never delete gameobject_template rows.")
        out.append("REPLACE INTO `gameobject_template` SELECT * FROM `dc_tmp_trap_template`;")
        out.append("DROP TEMPORARY TABLE IF EXISTS `dc_tmp_trap_addon`;")
        out.append("CREATE TEMPORARY TABLE `dc_tmp_trap_addon` ENGINE=InnoDB SELECT `t`.`new_entry` AS "
                   "`dc_new_entry`, `a`.* FROM %s AS `t` JOIN `gameobject_template_addon` AS `a` "
                   "ON `a`.`entry` = `t`.`old_entry`;" % t)
        out.append("UPDATE `dc_tmp_trap_addon` SET `entry` = `dc_new_entry`;")
        out.append("ALTER TABLE `dc_tmp_trap_addon` DROP COLUMN `dc_new_entry`;")
        out.append("DELETE FROM `gameobject_template_addon` WHERE `entry` IN (%s);"
                   % ", ".join(str(row[0]) for row in traps))
        out.append("INSERT INTO `gameobject_template_addon` SELECT * FROM `dc_tmp_trap_addon`;")
        out.append("DROP TEMPORARY TABLE `dc_tmp_trap_addon`;")
        out.append("DROP TEMPORARY TABLE `dc_tmp_trap_template`;")
        out.append("DROP TEMPORARY TABLE %s;" % t)
    out.append("")
    out.append("DROP TEMPORARY TABLE `dc_tmp_rank_map2`;")
    out.append("DROP TEMPORARY TABLE %s;" % m)
    return "\n".join(out) + "\n"


def line_ending(data):
    """The file's record terminator.

    Custom/CSV DBC holds both LF and CRLF files, and Spell.csv is LF with carriage returns inside some
    quoted descriptions, so the terminator is whichever ending most lines use.
    """
    return b"\r\n" if data.count(b"\r\n") * 2 > data.count(b"\n") else b"\n"


def split_records(data, eol):
    """Split CSV bytes into records, keeping line breaks inside quoted fields (multi-line tooltips).

    Every field is quoted and a literal quote is doubled, so a record ends at the first line break after
    which the record's quote count is even. Splitting on line breaks alone tore multi-line records apart
    (2026-11-15: replacing rows left 140 orphaned tooltip lines in Spell.csv).
    """
    records, current, quotes = [], [], 0
    for line in data.split(eol):
        current.append(line)
        quotes += line.count(b'"')
        if quotes % 2 == 0:
            records.append(eol.join(current))
            current, quotes = [], 0
    assert not current, "unbalanced quotes at the end of the file"
    return records


def append_rows(path, new_rows):
    """Append rows at the end of a CSV, dropping earlier copies of the same ids. Other bytes stay as they are."""
    data = Path(path).read_bytes()
    eol = line_ending(data)
    ids = {('"%s",' % row[0]).encode("ascii") for row in new_rows}
    records = split_records(data, eol)
    kept = [record for record in records if not any(record.startswith(prefix) for prefix in ids)]
    removed = len(records) - len(kept)
    data = eol.join(kept)
    if not data.endswith(eol):
        data += eol
    text = format_rows(new_rows).replace("\n", eol.decode("ascii"))
    Path(path).write_bytes(data + text.encode("utf-8"))
    return removed


def replace_lines(path, changed_rows):
    """Replace the record of each changed row (matched by id) in place."""
    data = Path(path).read_bytes()
    eol = line_ending(data)
    records = split_records(data, eol)
    by_prefix = {('"%s",' % row[0]).encode("ascii"): format_rows([row]).rstrip("\n").encode("utf-8")
                 for row in changed_rows}
    hits = 0
    for position, record in enumerate(records):
        for prefix, text in by_prefix.items():
            if record.startswith(prefix):
                records[position] = text
                hits += 1
    assert hits == len(changed_rows), "replaced %d of %d records" % (hits, len(changed_rows))
    Path(path).write_bytes(eol.join(records))
    return hits


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--class", dest="class_names", required=True,
                        help="comma-separated class names, or 'discovered' for every class in the discovery json")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--apply-csv", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    spell_header, spell_rows = read_csv(SPELL_CSV)
    assert len(spell_header) == 232
    ix = {name: position for position, name in enumerate(spell_header)}
    by_id = {row[0]: row for row in spell_rows}
    sla_header, sla_rows = read_csv(SLA_CSV)
    enchant_header, enchant_rows = read_csv(ENCHANT_CSV)
    enchant_by_id = {row[0]: row for row in enchant_rows}

    discovery = {name: entry for name, entry in json.loads(DISCOVERY_JSON.read_text(encoding="utf-8")).items()
                 if not name.startswith("_")}
    names = sorted(discovery) if args.class_names == "discovered" else args.class_names.split(",")
    pets = pet_configs([name for name in names if name in PET_CLASSES], by_id, ix, sla_header, sla_rows, [])

    report, configs, spells, sla_new, sla_changed = [], [], [], [], []
    enchants, enchant_pairs, totems, traps = [], [], [], []
    for name in names:
        report.append(name)
        if name in CLASSES:
            config = CLASSES[name]
        elif name in pets:
            report.pop()
            config = pet_configs([name], by_id, ix, sla_header, sla_rows, report)[name]
        else:
            assert name in discovery, "unknown class %s" % name
            config = families_from_discovery(discovery[name], by_id, ix, report)
        configs.append(config)
        spells += build_spells(config, spell_header, by_id)
        rows, pairs = build_enchants(config, enchant_header, enchant_by_id)
        enchants += rows
        enchant_pairs += pairs
        totems += build_totems(config, spell_header, by_id)
        traps += build_traps(config, spell_header, by_id)
        rows_new, rows_changed = build_sla(config, sla_header, sla_rows, report)
        sla_new += rows_new
        sla_changed += rows_changed

    new_ids = {row[0] for row in spells}
    taken = {row[0] for row in spell_rows if row[0] in new_ids}
    sla_ids = {row[0] for row in sla_new}
    sla_taken = {row[0] for row in sla_rows if row[0] in sla_ids}
    if taken or sla_taken:
        print("ids already in the CSVs (left from an earlier run of this script, or a clash): %d spell, %d sla"
              % (len(taken), len(sla_taken)))

    write_csv(args.out / "new_spells.csv", spell_header, spells)
    write_csv(args.out / "sla_new.csv", sla_header, sla_new)
    write_csv(args.out / "sla_changed.csv", sla_header, sla_changed)
    write_csv(args.out / "new_enchants.csv", enchant_header, enchants)
    enchant_taken = {row[0] for row in enchants} & set(enchant_by_id)
    if enchant_taken:
        print("enchantment ids already in the CSV (an earlier run, or a clash): %d" % len(enchant_taken))
    with open(args.out / "class_ranks.sql", "w", encoding="utf-8", newline="\n") as handle:
        handle.write(render_sql(", ".join(names), configs, totems, enchant_pairs, traps))
    (args.out / "families.txt").write_text("\n".join(report) + "\n", encoding="utf-8")
    print("\n".join(line for line in report if not line.startswith("  keep")))
    print("%d families kept, %d spells, %d new spellbook rows, %d changed spellbook rows"
          % (sum(1 for line in report if line.startswith("  keep")) + sum(
              len(CLASSES[n]["families"]) for n in names if n in CLASSES), len(spells), len(sla_new), len(sla_changed)))

    if args.apply_csv:
        print("Spell.csv: removed %d earlier rows, appended %d" % (append_rows(SPELL_CSV, spells), len(spells)))
        print("SkillLineAbility.csv: removed %d earlier rows, appended %d" % (append_rows(SLA_CSV, sla_new), len(sla_new)))
        print("SkillLineAbility.csv: %d level-80 rows now point at the 81 rank" % replace_lines(SLA_CSV, sla_changed))
        if enchants:
            print("SpellItemEnchantment.csv: removed %d earlier rows, appended %d"
                  % (append_rows(ENCHANT_CSV, enchants), len(enchants)))


if __name__ == "__main__":
    main()
