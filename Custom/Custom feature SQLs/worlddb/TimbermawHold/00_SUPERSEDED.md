# Superseded (2026-10-28)

The raid content in `05_templates.sql`–`17_achievement_criteria_data.sql` has been replaced by
Turtle WoW's own Timbermaw Hold, ported from tortoise-wow. See
`Custom/TimbermawHold/tortoise_port/00_README.md` and the pending files
`data/sql/updates/pending_db_world/rev_1793212190166823600.sql` (…601, …602).

**Do not re-apply 05–17.** `05_templates.sql` DELETEs and re-inserts the whole 4010001–4010199
creature band. `06_spawns.sql` sweeps map 819's spawns. Several others range-DELETE rows that the
new content now owns. That includes `09_instance.sql`, which writes the OLD bosses back into
`instance_encounters` 1100–1106, and `10_dc_difficulty.sql`, which restores the quest-master
follower that `15_` removed.

Only `01`–`04` (instance_template, game_tele, areatrigger_teleport, dungeon_access) are map-level
and safe.
