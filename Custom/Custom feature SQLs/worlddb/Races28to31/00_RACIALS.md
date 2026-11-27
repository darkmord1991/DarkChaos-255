# Racials of races 28-31

Drakkari Troll (28, Horde), Void Elf (29, Alliance), Lightforged Draenei (30, Alliance), Mag'har Orc
(31, Horde). The racial spells are below. The races are at the end of this file.

Retail ids and values come from the 9.2.7 client DB2s, skill lines 2421, 2423 and 2598. All ids were
free in `Spell.csv`. Scripts are in `src/server/scripts/DC/Races/dc_races_28_31.cpp`.

## Void Elf

| Spell | Id | On 3.3.5 | Difference from retail |
|---|---|---|---|
| Chill of Night | 255668 | Passive, 1% less Shadow and Arcane damage | None |
| Preternatural Calm | 255670 | Passive, `REDUCE_PUSHBACK` 100 | None, see Balance |
| Entropic Embrace | 255669 + 256374 | Proc: 5% chance, 45 s cooldown, +5% damage and healing for 12 s | Retail adds the bonus as extra Shadowfrost damage (aura 257, not on 3.3.5) |
| Spatial Rift | 256948 + 257040 | Rift object 30 yards ahead for 6 s, second spell steps through it, 3 min cooldown | Retail reuses one button (aura 332) and moves the rift with an area trigger (effect 179) |

## Lightforged Draenei

| Spell | Id | On 3.3.5 | Difference from retail |
|---|---|---|---|
| Holy Resistance | 255651 | Passive, 1% less Holy damage | None |
| Forge of Light | 255650 + 259930 | +10 Blacksmithing; summons a forge and an anvil for 2 min, 15 min cooldown | Stock objects, no Forge of Light model |
| Light's Judgment | 255647 + 256893 | Ground target, strikes after 3 s, 5 yards, 2.5 min cooldown | No ground marker during the delay |
| Light's Reckoning | 255652 + 256896 | Erupts on death, damages enemies and heals allies within 8 yards | None in behaviour |
| Demonbane | 255653 | +20% experience from demons | None |

## Mag'har Orc

| Spell | Id | On 3.3.5 | Difference from retail |
|---|---|---|---|
| Ancestral Call | 274738 + 274739-274742 | One random blessing, 15 s, 2 min cooldown | See below |
| Open Skies | 273216 | +10% mounted speed, ground and flying | None |
| Sympathetic Vigor | 273217 + 273218 | +10% pet health, through `spell_pet_auras` | Retail aura 382 is not on 3.3.5 |
| Savage Blood | 273220 | Poison, disease and curse effects 10% shorter | None; retail's fourth effect was an unused dummy |

Ancestral Call values are percentages because this server scales past level 80, where flat ratings
stop mattering:

| Blessing | Retail stat | Here |
|---|---|---|
| Rictus of the Laughing Skull | Critical strike | +3% critical strike chance |
| Zeal of the Burning Blade | Haste | +3% attack and casting speed |
| Ferocity of the Frostwolf | Mastery (no 3.3.5 stat) | +3% damage done |
| Might of the Blackrock | Versatility (no 3.3.5 stat) | +3% healing done, 3% less damage taken |

## Drakkari Troll

Not a retail race, so nothing here is official.

| Spell | Id | Effect |
|---|---|---|
| Blood of the Gods | 910200 | Berserking values: +20% attack and casting speed for 10 s, 3 min cooldown |
| Regeneration | 20555 | The stock troll racial |
| Frozen Empire | 910201 | 1% less Frost damage |
| Da Voodoo Shuffle | 58943 | The stock troll racial |

## Deliberately not shipped

| Racial | Why |
|---|---|
| Ethereal Connection (Void Elf) | Reduces the cost of Transmogrification, and transmog is free on this server. An invented replacement would not be a port. |

## Scaled values

`RacialPower` in the script is `level * 2 + max(attack power, spell power) * coefficient`, the shape of
Rocket Barrage. Light's Judgment uses 0.75, Light's Reckoning 0.5 for both damage and healing. Retail's
own formula is a tooltip variable that is not in the DB2s, so these are first guesses.

## Balance to check in game

- Preternatural Calm removes spell pushback entirely, as retail does. Pushback matters more on 3.3.5,
  so this may need lowering (effect value 100).
- Entropic Embrace's chance and cooldown are in `11_racial_support.sql`.

## Apply order

1. Build the worldserver with `dc_races_28_31.cpp`. It is a new file, so CMake has to run again.
2. `mysql acore_world < apply_all.sql` from this folder.
3. Restart. `.learn <spell id>` tests any racial before the races exist.

## The races

| Race | Model | Textures | Scene |
|---|---|---|---|
| Drakkari Troll | Ascension `DrakkariTroll`, displays 503950/503951 | Ascension, 9 tones, 6 faces | Retail `UI_Troll` |
| Void Elf | Blood Elf | Retail, 6 tones, 8 faces, 9 hair colours | Retail `UI_VoidElf` |
| Lightforged Draenei | Draenei | Retail, 3 tones, 10 faces, 6 hair colours | Retail `UI_LightforgedDraenei` |
| Mag'har Orc | Orc | Retail `orc*clan*`, 10 tones, 9 faces, Orc hair | Stock Orc, retail has none |

Faces appear twice, the second set with flag 5, because a Death Knight cannot select a flag 1 row. Void Elf wears
Human starting gear: Blood Elf gear is Horde-gated.

`tools/gen_allied_classic_textures.py` explains how retail skins reach the classic models. It prints a proof
score per model and stops below 0.80. To rebuild everything:

1. `gen_allied_classic_textures.py`, then `gen_races28to31.py` for the rows, DBCs and `20_races_server.sql`.
2. `gen_races28to31_icons.py` for the race icons.
3. `dc_mpq_deploy.py --stage` for the art. DBCs go to `patch-4`, `patch-enGB-3` and `patch-enGB-4`.
4. Regenerate `DCCharCustomizeData.lua` once the textures are in the client: its swatches sample the archives.

Not ported: the Lightforged tattoos and rune textures, which have no slot on a 3.3.5 model.

The races play with no rebuild. A rebuild only adds them to the ICC buff masks and the bot start table.
