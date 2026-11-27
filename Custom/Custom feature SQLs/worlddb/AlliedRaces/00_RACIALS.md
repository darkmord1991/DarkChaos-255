# Allied-race racials — Vulpera (24), Zandalari Troll (25), Kul Tiran (26)

Deferred when the races shipped, on the grounds that BfA racials need core work. Most of them
turned out not to: nine of the ten spells below are pure data, built from templates that already
exist in this fork's own `Spell.csv`. Only City of Gold needs a core hook.

Spell ids are the real BfA ids, all verified free against `Custom/CSV DBC/Spell.csv` (54,210 rows,
max id 910123). Effect and aura ids are verified against the core enums, not recalled — see
[[spell-effect-range-crash]]: an effect id >= 165 or an aura id >= 317 asserts and segfaults at
boot, so every value below is quoted with its enum name.

Granted through `playercreateinfo_spell_custom` by racemask, the same as the Pandaren set:
Vulpera `8388608`, Zandalari `16777216`, Kul Tiran `33554432`.

## Vulpera (24)

| Spell | ID | Effect / aura | Template |
|---|---|---|---|
| Bag of Tricks | 312411 | `SPELL_EFFECT_SCHOOL_DAMAGE` (2), Fire, 1.5 min CD | Gouge 1776 (active, melee/ranged shape) |
| Nose for Trouble | 312924 | `SPELL_AURA_PROC_TRIGGER_SPELL` (42) on being struck -> 312925 | Arcane Affinity 28877 (passive) |
| Nose for Trouble (triggered) | 312925 | `SPELL_EFFECT_SCHOOL_DAMAGE` (2), Physical, hidden | Gouge 1776 |
| Fire Resistance | 265225 | `SPELL_AURA_MOD_DAMAGE_PERCENT_TAKEN` (87), misc 4 = Fire, -1% | Frost Resistance 20596 |

Bag of Tricks in retail picks a random trick that damages an enemy *or* heals an ally. Shipped as
the damage trick only: a single spell cannot branch on target hostility, and a SpellScript to do it
is not worth the coupling for a cosmetic randomisation.

## Zandalari Troll (25)

| Spell | ID | Effect / aura | Template |
|---|---|---|---|
| Regeneratin' | 291944 | channelled `SPELL_AURA_PERIODIC_HEAL` (8), 6s, 2.5 min CD | Cannibalize 20577 (channel) |
| Pterrordax Swoop | 281954 | `SPELL_AURA_FEATHER_FALL` (105), 2 min CD | Slow Fall 130 |
| City of Gold | 291628 | passive dummy + **core hook**: +2% creature money | Arcane Affinity 28877 |

`SPELL_AURA_FEATHER_FALL` (105) is the slow-descent aura, **not** `SPELL_AURA_SAFE_FALL` (144),
which is the rogue no-fall-damage talent. Slow Fall 130 uses 105; Pandaren Bouncy uses the core
`DAMAGE_FALL` halving instead.

## Kul Tiran (26)

| Spell | ID | Effect / aura | Template |
|---|---|---|---|
| Haymaker | 287712 | damage (2) + `SPELL_EFFECT_KNOCK_BACK` (98) + `SPELL_AURA_MOD_STUN` (12), 2.5 min CD | War Stomp 20549 (stun) + Gouge 1776 |
| Child of the Sea | 280331 | `SPELL_AURA_WATER_BREATHING` (82) + `SPELL_AURA_MOD_INCREASE_SWIM_SPEED` (58) +20% | Unending Breath 5697 |
| Rime of the Ancient Mariner | 287829 | `SPELL_AURA_MOD_DAMAGE_PERCENT_TAKEN` (87) x2, misc 16 = Frost, 8 = Nature, -1% | Frost Resistance 20596 |

Haymaker is the one I expected to need core work and does not: `SPELL_EFFECT_KNOCK_BACK` is 98 in
3.3.5 and a spell has three effect slots, so damage + knockback + stun fits in one row.

## Deliberately not shipped

| Racial | Why |
|---|---|
| Make Camp / Return to Camp (Vulpera) | Needs a per-character persisted world position and a second teleport spell keyed to it. Real core work plus a characters-DB column; worth doing on its own, not folded into a spell batch. |
| Embrace of the Loa (Zandalari) | Six selectable loa blessings behind a shrine interaction. A feature, not a racial. |
| Jack of All Trades (Kul Tiran) | +5 to *every* profession. A spell has three effect slots and there are far more than three professions, so it needs either a spell chain or an on-login skill hook. |
| Brush It Off (Vulpera / Kul Tiran) | Grants Versatility, which has no WotLK analogue. Any mapping would be invention rather than a port. |
| Rummage Your Bag (Vulpera) | Depends on Bag of Tricks' charge system, which 3.3.5 spell data cannot express. |

## Core work

Only **City of Gold**. Creature money loot is multiplied by 1.02 when the looter is Zandalari; the
spell itself is an inert passive so the ability shows in the spellbook with its tooltip. Everything
else is data, so the racials land without a rebuild except for this one hook.
