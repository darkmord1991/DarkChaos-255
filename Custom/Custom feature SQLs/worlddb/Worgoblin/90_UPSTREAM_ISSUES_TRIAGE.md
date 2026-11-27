# Upstream mod-worgoblin issue triage (heyitsbench/mod-worgoblin, 2026-07-11)

Review of all 19 open upstream issues against the DC port. "Covered" = the DC
port's own implementation already avoids the bug by construction.

| # | Issue | DC status |
|---|---|---|
| 54 | Rocket Barrage/Jump separate cooldowns | **FIXED** — shared category 69041, 2-min CategoryRecoveryTime (`12_racial_shared_cooldown.sql` + client Spell.dbc in patch-4/enGB-3) |
| 48 | Missing 1h sword/mace/axe skills | **Covered** — DC `playercreateinfo_skills` uses raceMask=0 rows for all class weapon skills (apply to any race) + SkillRaceClassInfo racemask sweep |
| 3 | Racials "non-existed in SpellStore" | **Covered** — racial/mount spells shipped server-side via `spell_dbc` (10_spell_dbc.sql) |
| 28 | Hackfixed creation spells/skills | **Covered** — proper per-race `playercreateinfo_spell_custom` sets (orc∩human intersection + racials), not their hackfix |
| 25/24 | Languages / Factions TODO | **Covered** — Common/Orcish via SRCI+SLA racemasks + spell_custom 668/669; Faction.dbc BaseRepRaceMask updates on 89 factions |
| 29 | Conditions racemasks | **Covered** — quest/item mask sweeps (06) incl. the 1791→4095 ARAC pin; vendor conditions ported |
| 46 | Worgen druid forms/quests missing | **Likely covered** — DC's FirstStart learnspells teaches class spells race-agnostically; class quests opened by the mask sweep. Verify a worgen druid in-game gets bear form at the trainer/level |
| 59 | Trainer gossip error (Revi Ramrod 25000) | **Likely fixed** — root cause was their legacy `npc_trainer` wiring; DC uses `creature_default_trainer`→template 38. Verify once the optional vendor NPCs are spawned |
| 38 | DK starting-zone quests | **N/A** — DC starts all characters at Azshara Crater |
| 7 | Add Gilneas/Kezan | **Deferred by design** — separate DC downport track (nelt_world/cata_world + wxl-baker plan) |
| 33 | Gilnean (human-form) DisplayIDs + voice | Skipped — cosmetic, tied to Two Forms which is a known upstream limitation |
| 22 | Barbershop style names vs Cata | Skipped — cosmetic naming only |
| 36 | Workflow SQL for their CI | N/A — their repo infrastructure |
| 35/21 | HD-patch update / undead jaws | N/A — DC uses its own patch stack, not their HD patch |
| 31 | Localizations | N/A — DC client is enGB which reads the enUS locale slot |
| 6 | Goblin on unmodified client | N/A — DC ships a modified client by design |
| 58 | Repo status question | N/A |

Additional DC-only fixes not in their tracker (documented in memory):
- Stock 3.3.5 has ZERO CharacterFacialHairStyles rows for race 9 → authored 86
  rows, byte-validated against both Cata (9/22) and Ascension production (9/13);
  +411 geoset-only CharSections facial rows. This fixes the black/blue nose that
  upstream users likely also see.
- Worgen facial-hair textures referenced by their DBC never existed in any
  client; style-00 sourced from Ascension patch-CHA, phantom refs blanked.
