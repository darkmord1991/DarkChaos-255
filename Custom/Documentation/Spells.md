# Custom Spells Summary (DC)

This document summarizes custom spell IDs currently referenced by DC systems in this repository.

## Mythic+ Affix Spells

Defined in [src/server/scripts/DC/MythicPlus/dc_mythicplus_affixes.h](src/server/scripts/DC/MythicPlus/dc_mythicplus_affixes.h) and used in affix handlers:

- 900010 — Affix: Bolstering (stacking buff visual/aura)
- 900020 — Affix: Necrotic (stacking wound aura)
- 900030 — Affix: Grievous (stacking wound aura)

## Hinterland BG (HLBG) Affix Spells

Defined in [src/server/scripts/DC/HinterlandBG/HinterlandBGConstants.h](src/server/scripts/DC/HinterlandBG/HinterlandBGConstants.h) and mapped in [src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Affixes.cpp](src/server/scripts/DC/HinterlandBG/OutdoorPvPHL_Affixes.cpp):

- 910010 — HLBG Affix: Sunlight (player haste)
- 910011 — HLBG Affix: Clear Skies (player damage)
- 910012 — HLBG Affix: Gentle Breeze (player healing received)
- 910020 — HLBG Affix: Storm (NPC damage)
- 910021 — HLBG Affix: Heavy Rain (NPC armor)
- 910022 — HLBG Affix: Fog (NPC evasion)

## Hotspot Spells

Referenced in [src/server/scripts/DC/Hotspot/HotspotCore.h](src/server/scripts/DC/Hotspot/HotspotCore.h), [src/server/scripts/DC/Hotspot/HotspotDefines.h](src/server/scripts/DC/Hotspot/HotspotDefines.h), and spell script [src/server/scripts/DC/Hotspot/spell_hotspot_buff_800001.cpp](src/server/scripts/DC/Hotspot/spell_hotspot_buff_800001.cpp):

- 800001 — Hotspot XP buff spell (spell script handles XP multiplier)
- 800002 — Hotspot aura spell (visual/configurable; default in HotspotCore)

## Prestige Spells

Referenced in [src/server/scripts/DC/Progression/Prestige/dc_prestige_spells.cpp](src/server/scripts/DC/Progression/Prestige/dc_prestige_spells.cpp) and [src/server/scripts/DC/Progression/Prestige/dc_prestige_system.cpp](src/server/scripts/DC/Progression/Prestige/dc_prestige_system.cpp):

- 800010–800019 — Prestige level stat bonus auras

Alt-bonus visuals used by [src/server/scripts/DC/Progression/Prestige/dc_prestige_alt_bonus.cpp](src/server/scripts/DC/Progression/Prestige/dc_prestige_alt_bonus.cpp) and [src/server/scripts/DC/Progression/Prestige/spell_prestige_alt_bonus_aura.cpp](src/server/scripts/DC/Progression/Prestige/spell_prestige_alt_bonus_aura.cpp):

- 800040–800044 — Alt-friendly XP bonus visuals (5%–25%)

## Challenge Mode Spells

Referenced in [src/server/scripts/DC/Progression/ChallengeMode/dc_challenge_modes.h](src/server/scripts/DC/Progression/ChallengeMode/dc_challenge_modes.h) and [src/server/scripts/DC/Progression/ChallengeMode/spell_challenge_mode_auras.cpp](src/server/scripts/DC/Progression/ChallengeMode/spell_challenge_mode_auras.cpp):

- 800020 — Hardcore
- 800021 — Semi-Hardcore
- 800022 — Self-Crafted Only
- 800023 — Item Quality Level Restriction
- 800024 — Slow XP Gain
- 800025 — Very Slow XP Gain
- 800026 — Quest XP Only
- 800027 — Iron Man
- 800028 — Multiple Challenges Combination
- 800029 — Iron Man+ Mode

## Collection System (Mount Speed) Spells

Referenced in [src/server/scripts/DC/CollectionSystem/CollectionCore.h](src/server/scripts/DC/CollectionSystem/CollectionCore.h) and addon integration [src/server/scripts/DC/AddonExtension/dc_addon_collection.cpp](src/server/scripts/DC/AddonExtension/dc_addon_collection.cpp):

- 300510 — Mount speed tier 1
- 300511 — Mount speed tier 2
- 300512 — Mount speed tier 3
- 300513 — Mount speed tier 4

## IDs Listed But Not Referenced As Spells

The following IDs appear in content as NPC or other non-spell references, not as spell IDs in scripts:

- 800003–800009 — NPC entries (for example, [src/server/scripts/DC/AC/ac_quest_npc_800009.cpp](src/server/scripts/DC/AC/ac_quest_npc_800009.cpp))

## Current Spell.csv Status

The current [Custom/CSV DBC/Spell.csv](Custom/CSV%20DBC/Spell.csv) contains only the 9 custom spell rows above (plus header). If you need a full Spell.csv dump, restore it and reapply these entries before importing into WDBX.
