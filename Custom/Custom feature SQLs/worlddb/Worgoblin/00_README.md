# Worgoblin world-DB SQL — Playable Goblin (9) & Worgen (12)

Apply with `mysql acore_world < apply_all.sql` from this folder (files are
idempotent). Full feature documentation: `Custom/Worgoblin/README.md`;
deployment order incl. DBCs/client: `Custom/Worgoblin/DEPLOY.md`.

| File | Purpose |
|---|---|
| 01_playercreateinfo.sql | 20 start rows (2 races × 10 classes), all at DC's universal start (Azshara Crater, map 37 zone 268) |
| 02_player_race_stats.sql | Racial base stats (mod-worgoblin values) |
| 03_playercreateinfo_skills.sql | Racial skill lines 789/790 + axe/mace weapon-skill fixes |
| 04_playercreateinfo_spell_custom.sql | Class spells = orc(2)∩human(1) set intersection per race mask (256/2048) + explicit racials/languages |
| 05_playercreateinfo_action.sql | mod-worgoblin action bars + ARAC clones for goblin pal/druid, worgen pal/shaman |
| 06_race_mask_sweeps.sql | quest/item AllowableRace(s) opened for bits 8+11; pins ARAC's 1791→4095 first (worgoblin's sweep-order bug: 1791\|256=2047 is excluded by the generic sweep) |
| 07_mount_items.sql | Trike/horse mount items (must win over wraith appearance copies — they wire the new mount spells) |
| 08_creatures.sql | Display metadata + Gobber/trike/horse creatures (DC creature_template schema: no scale/trainer_*/immune masks) |
| 09_spell_script_names.sql | 69041 → spell_rocket_barrage |
| 10_spell_dbc.sql | 16 server-side spell rows (racials + mounts), generated 1:1 from the client Spell.dbc |
| 11_mount_vendor.sql | OPTIONAL: trike dealer/trainer NPC definitions (no spawns; `.npc add 48510` / `.npc add 48513`) |
| 14_starting_gear_stats.sql | Populates armor/weapon-damage on the 49 starting-outfit items (wraith downport left them stat-less; real Cata data is stat-less too, so armor is backfilled from DC's own ilvl-1 conventions instead) |

Deliberately NOT ported from mod-worgoblin:
- `optional-class-trainers.sql` / `optional-class-quests.sql` / `dk-quests.sql`
  — they spawn trainers/quests in retail start zones; DC starts everyone at
  Azshara Crater with its own infrastructure.
- `achievement_criteria_data` rows — the matching client Achievement_Criteria
  additions were skipped to keep DC's custom achievement DBCs untouched.
- Starting-gear `item_template` rows — all 49 exist already via the wraith
  item downport (DC's versions win; they reference DC displays). They came in
  as stat-less appearance shells; `14_starting_gear_stats.sql` backfills
  armor/weapon-damage (see that file's header for sourcing).
