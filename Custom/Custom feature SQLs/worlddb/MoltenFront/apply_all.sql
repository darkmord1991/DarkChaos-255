-- apply_all.sql -- ordered runner for the Molten Front content (target: acore_world).
-- Cross-DB INSERT...SELECT reads nelt_world (map 861). dc_entry = 3,600,000 + original.
-- Run AFTER ../HyjalCata/apply_all.sql. Remove the SOURCE lines for 32_/51_ from the
-- HyjalCata runner first (this folder supersedes them). See 00_README.md.
--   cd "K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/MoltenFront" && mysql acore_world < apply_all.sql
SOURCE 01_mf_templates.sql;
SOURCE 02_mf_spawns.sql;
SOURCE 03_mf_quests.sql;
SOURCE 04_mf_portal.sql;
-- 06_mf_scriptnames re-applies the HyjalCata ScriptName wiring so freshly-cloned
-- MF script-carriers (from 01) get their ScriptName too. Inlined directly here
-- (not via a wrapper file) because HeidiSQL does not reliably resolve a SOURCE
-- statement nested inside another SOURCE'd file.
SOURCE 07_mf_questgiver_gaps.sql;
SOURCE 08_mf_access.sql;
SOURCE 09_mf_polish.sql;
SOURCE 10_vehicle_dbc_1631.sql;
SOURCE 11_white_npc_stock_displays.sql;
SOURCE 12_mf_quartermaster_stock.sql;
SOURCE 13_mf_base_phase_backfill.sql;
SOURCE ../HyjalCata/31_scriptnames.sql;
SOURCE ../HyjalCata/46_neltharion_fixups.sql;
-- 05 (leveling/economy wiring) is covered by HyjalCata 99_/100_ (self-derive over map 750+861).
SOURCE 14_round20_followups.sql;
-- --- 2026-07-29 audit round -------------------------------------------------
-- 15: spawn-layer gaps (Ash Pile template + 33 base-phase GOs, 9 creature_addon
--     rows, 4 patrol paths, AIName fix, action list 5283400, Zen'Vorka pricing +
--     stat-fill, loot merge, 3 dropped quest relations).
-- 16: the "deep MF" NPC layer that was never cloned (19 creature templates + GO
--     3808535 + spawns + quest relations) -- unblocks 13 broken quests.
-- 19: spell_dbc rows the 16_ clones cast (MUST come before 16 -- SmartAIMgr
--     discards any row whose spell is unknown at load time).
-- 17: interaction layer -- kill-credit grants, quest-item sources.
-- 18: gossip text for the five menus that exist in no source DB.
SOURCE 15_mf_spawn_layer_fixes.sql;
SOURCE 19_mf_deep_layer_spells.sql;
SOURCE 16_mf_deep_layer.sql;
SOURCE 17_mf_interactions.sql;
SOURCE 18_mf_gossip.sql;

-- --- round 25 (2026-08-06 Errors.log sweep) ---------------------------------

-- 20: the 16 timed action lists 16_ left behind. Its own spell prerequisite is
-- inlined as section 1 of the same file, so ordering is self-contained here --
-- but HyjalCata/258_ is a sibling of this round and neither depends on it.
SOURCE 20_mf_actionlists_restore.sql;
