-- apply_all.sql — ordered runner for the HyjalCata content port (target: acore_world). Run from INSIDE this folder:
--   cd "K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/HyjalCata" && mysql acore_world < apply_all.sql
-- Cross-DB INSERT...SELECT (reads cata_world). dc_entry = 3,600,000 + original. Idempotent (INSERT IGNORE).
SOURCE 01_creature_templates.sql;
SOURCE 02_gameobject_templates.sql;
SOURCE 04_spawns.sql;
SOURCE 40_items.sql;
SOURCE 41_spell_dbc.sql;
SOURCE 07_creature_text.sql;
SOURCE 08_loot.sql;
SOURCE 09_gossip.sql;
SOURCE 11_quests.sql;
SOURCE 12_smart_scripts.sql;
SOURCE 13_areas.sql;
SOURCE 14_graveyard.sql;
SOURCE 15_areatrigger.sql;
SOURCE 29_neltharion_templates.sql;
SOURCE 30_neltharion_spawn_layer.sql;
SOURCE 32_molten_front_phased.sql;
SOURCE 31_scriptnames.sql;
SOURCE 42_creature_model_info.sql;
SOURCE 43_movement_fix.sql;
SOURCE 44_missing_loot_items.sql;
SOURCE 45_reference_loot.sql;
SOURCE 46_neltharion_fixups.sql;
SOURCE 47_spell_dbc_custom.sql;
SOURCE 50_molten_front_quests.sql;
SOURCE 51_molten_front_spawns.sql;
SOURCE 52_smartai_error_fixes.sql;
SOURCE 53_spell_dbc_additions.sql;
SOURCE 54_spell_dbc_additions_custom.sql;
SOURCE 55_gameobject_missing.sql;
SOURCE 60_flightmaster_scripts.sql;
SOURCE 61_pickpocket_skinloot_fixups.sql;
SOURCE 62_spell_dbc_additions_quest_rewards.sql;
SOURCE 63_quest_sort_and_reward_fixes.sql;
SOURCE 64_item_templates.sql;
SOURCE 65_creature_addon_orphan_cleanup.sql;
SOURCE 66_vehicle_dbc_fix.sql;
SOURCE 67_creature_addon_spell_dbc_additions.sql;
SOURCE 68_faction_dbc_fix.sql;
SOURCE 69_gameobjectdisplayinfo_resync.sql;
SOURCE 70_killcredit_offset_fix.sql;
SOURCE 71_gameobjectdisplayinfo_10573.sql;
SOURCE 72_npc_vendor_backfill.sql;
SOURCE 73_npc_vendor_backfill_catchup.sql;
SOURCE 74_molten_front_missing_entities.sql;
SOURCE 75_molten_front_delegation_vow.sql;
SOURCE 76_molten_front_spell_dbc_additions.sql;
SOURCE 77_molten_front_creature_text.sql;
SOURCE 78_molten_front_graduation_spells.sql;
SOURCE 79_twilight_slavedriver_ainame_fix.sql;
SOURCE 80_spellclick_spell_dbc_additions.sql;
SOURCE 81_spellclick_backfill.sql;
SOURCE 82_vehicle_dbc_fix_round2.sql;
SOURCE 83_misc_fixes_round3.sql;
SOURCE 84_molten_front_quest_objectives.sql;
SOURCE 85_questsort_areatable_additions.sql;
SOURCE 86_quest_reward_spell_dbc_additions.sql;
SOURCE 87_vendor_extendedcost_crystallized_firestone.sql;
SOURCE 88_reference_loot_mobus_julak.sql;
SOURCE 89_ragnaros_emote_fix.sql;
SOURCE 90_creature_text_sound_silence.sql;
SOURCE 91_reward_spell_null_unresolvable.sql;
SOURCE 92_mobus_display_crash_fix.sql;
SOURCE 93_faction_template_2170.sql;
SOURCE 94_molten_lord_killcredit_offset.sql;
SOURCE 95_spellfocus_lock_dbc_additions.sql;
SOURCE 96_go_spellcaster_spell_dbc.sql;
SOURCE 97_flamewaker_shaman_lootid_offset.sql;
SOURCE 98_zone_consumables_vendor_stock_750.sql;
SOURCE 99_zone_gear_statfill.sql;
SOURCE 100_zone_token_economy.sql;
SOURCE 101_zone_level_bands.sql;

-- --- round 14 (2026-07-25): script/DB-error sweep + last missing downports ---
SOURCE 112_spell_dbc_round14.sql;
SOURCE 113_smartai_offset_fixes.sql;
SOURCE 114_ainame_cleanup.sql;
SOURCE 115_pool_dangling_cleanup.sql;
SOURCE 116_quest_credit_offset_fix.sql;
SOURCE 117_vehicle_dbc_hyjal_round14.sql;
SOURCE 118_missing_templates_and_scriptnames.sql;
SOURCE 119_flameward_helper_spawns.sql;
SOURCE 120_spell_effect_data_fixes.sql;
SOURCE 121_nordrassil_portals.sql;
SOURCE 102_delegation_vow_questgivers.sql;

-- --- round 15 (2026-07-25): post-MoltenFront-apply sweep ---------------------
SOURCE 122_smartai_actionlists.sql;
SOURCE 126_summon_transform_targets.sql;
SOURCE 123_spell_dbc_round15.sql;
SOURCE 124_loot_template_backfill.sql;
SOURCE 125_gossip_menus.sql;
SOURCE 127_misc_fixes_round15.sql;
SOURCE 128_creature_model_info.sql;
SOURCE 129_faction_and_movement_fixes.sql;

-- --- round 16 (2026-07-25): post-restart sweep -------------------------------
SOURCE 130_waypoint_paths.sql;
SOURCE 132_missing_entities_round16.sql;
SOURCE 131_spell_dbc_round16.sql;
SOURCE 133_offset_fixes_round16.sql;

-- --- round 17 (2026-07-25): waypoints-table correction + equipment ----------
SOURCE 134_waypoints_table_fix.sql;
SOURCE 135_spell_dbc_round17.sql;
SOURCE 136_creature_equip_backfill.sql;

-- --- round 18 (2026-07-25): crash/freeze risks + the MF quest items ---------
SOURCE 137_vehicle_dbc_round18.sql;
SOURCE 138_display_fixes_round18.sql;
SOURCE 139_misc_round18.sql;
SOURCE 140_mf_quest_items.sql;

-- --- round 19 (2026-07-25): teleport destinations --------------------------
SOURCE 141_spell_target_position.sql;

-- --- round 20 (2026-07-25): finish 3654343 + the last loot items ------------
SOURCE 142_creature_54343_completion.sql;
SOURCE 143_mf_loot_items.sql;

-- --- round 21 (2026-07-25): Thrall dialogue + boot-spam cleanup -----------
SOURCE 144_thrall_dialogue_and_boot_spam.sql;

-- --- round 19 spell (2026-07-25): Flame Cat Form ---------------------------
SOURCE 145_spell_dbc_round19.sql;

-- --- round 19b (2026-07-25): the 28 consumable spells ---------------------
SOURCE 146_food_spells_dbc.sql;

-- --- round 21 (2026-07-25): spells+spellclick for the grown clone block -----
SOURCE 144_spell_dbc_round21.sql;
SOURCE 145_spellclick_round21.sql;

-- --- round 20 (2026-07-25): spells the 13_ base-phase import surfaced ------
SOURCE 147_spell_dbc_round20.sql;

-- --- round 22 (2026-07-26): map-750 areatrigger targets + dead Firelands portal
SOURCE 148_areatrigger_target_map_fix.sql;

-- --- round 22 (2026-07-26): zone gear armor + weapon damage (Phase 2) --------
SOURCE 149_zone_gear_armor_dmg.sql;

-- --- round 23 (2026-07-26): the invisible-questgiver fix + vendor backfill ---
-- 150_ is the important one: it is the reason nine Hyjal NPCs (Hamuul, Jarod,
-- Tyrus, the three Ancient images, Thisalee, Aviana's Egg -- 16 spawns) were
-- invisible to every player.  151_ must precede 152_, which reads its items.
SOURCE 150_quest_invisibility_detection.sql;
SOURCE 151_zenvorka_items.sql;
SOURCE 152_npc_vendor_backfill.sql;

-- --- round 24 (2026-07-26): AIName/ScriptName double-ownership resolution ----
-- Clears the misleading AIName on the 19 templates where a DC C++ script
-- already wins over SmartAI. No runtime change; makes the DB honest.
SOURCE 153_ainame_scriptname_resolution.sql;

-- --- round 25 (2026-07-27): duplicate unique-NPC spawns + the 277 never ported
SOURCE 154_unique_npc_duplicate_spawns.sql;
SOURCE 155_missing_hyjal_spawns.sql;

-- --- round 25b (2026-07-27): stop questgivers/vendors brawling ---------------
SOURCE 156_questgiver_combat_immunity.sql;
-- 157_ (snow area / Winterspring overlap) is DELIBERATELY NOT sourced here --
-- it is an opt-in content decision; read its header.

-- --- round 25c (2026-07-27): corrective -- 155_ had undone 154_'s dedup ------
SOURCE 158_fix_155_reintroduced_duplicates.sql;

-- --- round 25d (2026-07-27): waypoint paths for 155_'s imported spawns -------
-- MUST follow 155_: it copies MovementType from cata_world but no addon rows,
-- so waypoint movers arrive pathless. 159_ imports the real Cata paths.
SOURCE 159_imported_spawn_waypoints.sql;

-- --- round 26 (2026-07-27): duplicate vendor clones 154_ missed + flag catch-up
-- Must run after 157_ if that opt-in file is used -- it re-runs 156_'s sweep.
SOURCE 160_duplicate_vendor_clones.sql;

-- --- round 27 (2026-07-27): populate the remaining border bands ---------------
-- Emptiness-guarded: only imports where map 750 has nothing within 100 yards.
SOURCE 161_border_bands_populate.sql;

-- --- round 28 (2026-07-28): first pass against the LIVE log ------------------
-- Earlier rounds triaged a stale Feb-19 Errors.log copy; the real one lives on
-- the Linux host. 162_ fixes what that revealed, incl. two of my own regressions.
SOURCE 162_live_log_round28.sql;

-- --- round 29 (2026-07-28): second live-log pass -----------------------------
SOURCE 163_live_log_round29.sql;

-- --- round 30 (2026-07-28): populate the TRUE map extent ---------------------
-- Supersedes 161_'s scope: that file searched a box derived from existing
-- spawns, so it could not see the empty eastern third of the map (Everlook,
-- Moonglade, Felwood). 2,694 creatures + 1,680 gameobjects.
SOURCE 164_true_extent_populate.sql;

-- --- round 31 (2026-07-28): quest POI map markers ---------------------------
-- 481 POI rows / ~227 quests. Requires the corrected WorldMapArea 1216 bounds
-- to line up (POI blobs project through exactly those Loc values).
SOURCE 165_quest_poi.sql;

-- --- round 37 (2026-07-29): flight points for the border zones --------------
-- BEFORE 166_ on purpose: the six spawns go in with RAW entry ids inside the
-- guid block 166_ derives its source set from, so they get cloned on the same
-- pass. Needs the regenerated TaxiNodes/TaxiPath/TaxiPathNode DBCs deployed.
SOURCE 170_border_flightmasters.sql;

-- --- round 34 (2026-07-28): clone the border-zone NPCs/GOs ------------------
-- Gives map 750 private copies (creature +3,700,000 / gameobject +3,900,000) of
-- the stock NPCs 157_/161_/164_ imported, so Winterspring/Moonglade/Felwood/
-- Darkshore/Azshara/Ashenvale can be edited without touching the real zones.
-- MUST run after 157_/161_/164_ -- it reads their spawn blocks to find the set,
-- and repoints those spawns as its LAST step.
SOURCE 166_border_zone_clone.sql;

-- --- round 35 (2026-07-28): clone the border-zone quests --------------------
-- 194 quests at raw + 100,000, with Prev/Next/ExclusiveGroup/Breadcrumb links
-- remapped only where the target is also cloned. MUST run after 166_ -- it
-- derives its source set from 166_'s cloned templates.
SOURCE 167_border_zone_quests.sql;

-- --- round 36 (2026-07-29): repair what 166_'s first revision broke ----------
-- Not a Hyjal fix: 166_ used to DELETE smart_scripts source_type 9 across
-- 3,700,000-3,799,999, which is where stock numbers Icecrown Citadel's action
-- lists (entry*100 for entries 37000-37999). It destroyed 148 rows / 10 lists
-- belonging to Darion Mograine, Blood-Queen Lana'thel, The Lich King and
-- Shadowmourne. 166_ no longer touches that band; this restores it.
SOURCE 168_restore_stock_action_lists.sql;

-- --- round 37 (2026-07-29): the rest of the clone fallout --------------------
-- Same class of mistake as 168_, found in the post-restart log: 166_'s
-- `DELETE ... WHERE entry >= 3900000` took DC's Legion Dalaran guild-housing
-- gameobjects (4,100,000-4,100,674) with it, orphaning 714 spawns, and 167_
-- mis-keyed quest_greeting. Both generators now delete by exact id.
SOURCE 169_clone_fallout_repair.sql;

-- --- round 38 (2026-07-29): areatable_dbc override + imported world events ---
-- 85_ had registered area 4926 as "Blackrock Caverns" in the ADDITIVE
-- areatable_dbc override, which outranks the DBC file and made the whole
-- Winterspring zone report the wrong name with AreaBit 0 (no exploration).
-- Also strips 660 GO + 348 creature spawns that 164_ imported without their
-- game_event gating -- a permanent Scourge Invasion necropolis, among others.
SOURCE 171_areatable_override_and_world_events.sql;

-- --- round 39 (2026-07-29): skinning block rescue + waypoint + dead vendor ---
-- 166_'s skinning clone kept being skipped at application time (0 rows after
-- two runs, though its SELECT yields 221) -- isolated here so it can be run
-- and verified alone. Plus the one pathless waypoint clone and item 2332.
SOURCE 172_skinning_waypoint_vendor.sql;

-- --- round 40 (2026-07-29): post-172 log batches -----------------------------
-- creature_model_info for 6 DC displays (the "No model data exist" block),
-- item_dbc display-0 leftovers of the r11 column shift, mastery(49)->crit/haste
-- remap on 59 items, 2 restored HLBG decor templates, 29 heroic ScriptName
-- clears, Giant Isles pickpocket/skin loot re-links.
SOURCE 173_db_errors_round40.sql;

-- --- round 41 (2026-07-29): graveyards for the border zones ------------------
-- 4926-4931 had zero graveyard_zone links; 10 stock graveyards inside the
-- terrain box cloned to map 750 (ids 15020-15029), all six zones blanket-
-- linked to every map-750 graveyard (nearest wins at runtime).
SOURCE 174_border_zone_graveyards.sql;

-- --- round 42 (2026-07-29): populate the new western terrain strip -----------
-- Terrain grew 81 -> 108 tiles (cols 30-41) from the same retail source as the
-- rest of the map; Felwood is now 100% of its real footprint. Imports the stock
-- map-1 spawns in x 3200..8000 / y -533..1067, EXCLUDING world-event-only
-- content up front (the omission that put a Scourge necropolis on the map and
-- needed 171_ to undo). MUST run before re-running 166_, which clones it.
SOURCE 175_west_strip_populate.sql;
-- --- round 42 (2026-07-29): Kalimdor-edge flight masters --------------------
-- The Winterspring/Felwood/Azshara/Moonglade flight points on map 750 had taxi
-- nodes and a full path mesh to Hyjal, but their flight masters could not use
-- it. Six of them are STOCK Kalimdor NPCs spawned on both map 1 and map 750, so
-- 60_'s template-level ScriptName bind would have rewired real Azeroth too --
-- they are cloned to +3.6M and only the map-750 spawns repointed.
-- Needs a worldserver REBUILD (dc_downport_taxi.cpp node table) + restart.
SOURCE 175_kalimdor_edge_flightmasters.sql;
SOURCE 176_soren_moonfall_waypoints.sql;
SOURCE 177_gossip_dead_ends.sql;
SOURCE 178_catatc_content_port.sql;
SOURCE 179_quest_audit_map750.sql;
SOURCE 180_felwood_position_audit.sql;
SOURCE 181_felwood_cata_layer_import.sql;
SOURCE 182_felwood_new_flightmasters.sql;
SOURCE 183_felwood_cata_layer_remainder.sql;
SOURCE 184_darkshore_cata_import.sql;
SOURCE 185_map750_out_of_bounds_objects.sql;
SOURCE 186_felwood_cata_scripts.sql;
SOURCE 187_darkshore_flightmasters.sql;
SOURCE 188_map750_missing_display_ids.sql;
SOURCE 189_darkshore_quest_items.sql;
SOURCE 190_darkshore_quest_layer.sql;
SOURCE 191_darkshore_escort_data.sql;
SOURCE 192_felwood_quest_items.sql;
SOURCE 193_felwood_quest_layer.sql;
SOURCE 194_hyjal_taxi_mount.sql;
SOURCE 194_map750_missing_spells.sql;
SOURCE 195_map750_integrity_fixes.sql;
SOURCE 196_darkshore_vehicle.sql;
SOURCE 197_darkshore_controller_data.sql;
SOURCE 198_darkshore_vengeful_protector_chain.sql;
SOURCE 199_lycanthoth_quest_enders.sql;
SOURCE 200_map750_missing_factions.sql;
SOURCE 201_map750_missing_creature_displays.sql;
SOURCE 202_map750_waypoint_paths.sql;
SOURCE 203_smartai_cast_spells.sql;
SOURCE 204_map750_smartai_scripts.sql;
SOURCE 205_map750_smartai_repairs.sql;
SOURCE 206_map750_duplicate_gameobjects.sql;
SOURCE 207_map750_node_ground_snap.sql;
SOURCE 208_map750_moonglade_gaps.sql;
SOURCE 209_map750_loot_completion.sql;
SOURCE 210_map750_post_restart_cleanup.sql;

-- --- round 43 (2026-08-02): Azshara corner -> Cataclysm content -------------
-- Terrain was ALREADY retail post-Cata (heightmap-proven); this swaps the
-- stock-WotLK spawn layer for cata_world zone-16 content inside the extent,
-- wiped chunk-precisely via a 4930 mask read from the shipped ADTs.
SOURCE 176_azshara_cata_content.sql;

-- --- round 43b (2026-08-02): Azshara quest layer + Kroum/Valormok retired ---
-- MUST follow 176_. Quest chains seeded from the corner questgivers; chains
-- crossing the map edge dead-end there by design. Kroum despawned; taxi node
-- 338 removed from the regenerated 28-node network (DBC deploy same round).
SOURCE 177_azshara_quests.sql;
SOURCE 211_map750_ashenvale_winterspring_displays.sql;
SOURCE 212_map750_ashenvale_winterspring.sql;
SOURCE 213_map750_restore_creature_models.sql;
SOURCE 214_map750_creature_model_info.sql;
SOURCE 215_map750_loot_and_ai_cleanup.sql;
SOURCE 216_map750_zone_smartai_spells.sql;
SOURCE 217_map750_zone_smartai.sql;
SOURCE 218_map750_zone_quests.sql;
SOURCE 219_map750_backlog_cleanup.sql;

-- --- round 44 (2026-08-02): populate the 108->279 tile expansion ----------
-- Ships WITH the client patch-4/patch-6 terrain of the same round. Requires the
-- server to have maps/vmaps/mmaps for all 279 tiles first, else these spawns
-- sit on ground the server cannot load.
SOURCE 178_new_terrain_spawns.sql;

-- --- round 44: Felwood gathering layer (827 nodes; zone was unfarmable) ----
SOURCE 179_felwood_gathering_layer.sql;

-- --- round 44 phase 2: quest layer for the expanded terrain ---------------
-- Strictly after 178_ (its +@OFF creature entries are what the starter/ender
-- rows point at). Chains leaving map 750 dead-end at the map edge by design.
SOURCE 180_new_terrain_quests.sql;

-- --- round 45: creature_model_info for the expanded-terrain displays -------
-- Pairs with the CreatureDisplayInfo/Extra DBC + baked-texture client deploy
-- of the same round. BOTH halves must go live together.
SOURCE 181_new_terrain_creature_model_info.sql;

-- --- round 45: flight-master duplicate cleanup (pairs with taxi expansion) -
SOURCE 182_flightmaster_dupes.sql;

-- --- round 45: quest POI + NPC service backfill ---------------------------
SOURCE 183_quest_poi.sql;
SOURCE 184_vendors_and_trainers.sql;

-- --- round 45: repair trainer links 184_ removed (Engineering / NULL subname)
SOURCE 185_trainer_link_repair.sql;

-- --- round 45: quest-ender repair (11 of 54; rest are off-map by design) ---
SOURCE 186_quest_ender_repair.sql;

-- --- round 45: unblock 11 displays whose model file already shipped --------
-- Pairs with the CreatureModelData/CreatureDisplayInfo DBC deploy of the same
-- round. 5 displays remain blocked pending a Cata model extract + bake.
SOURCE 187_blocked_model_displays.sql;

-- --- round 45: quest items + the last blocked models -----------------------
-- 188_ needs no client deploy beyond ItemDisplayInfo (icons all already ship).
-- 189_ pairs with the patch-6 model bake + CreatureModelData/DisplayInfo DBCs.
SOURCE 188_map750_quest_items.sql;
SOURCE 189_caravan_and_doodad_models.sql;

-- --- round 45 follow-up: ender-NPC displays + orphan POI blob --------------
SOURCE 190_ender_npc_displays_and_poi_cleanup.sql;

-- --- round 45 follow-up: equipment + chest loot the spawn imports missed ---
SOURCE 191_equipment_and_chest_loot.sql;

-- --- round 45 follow-up: the 43 SmartAI spells that genuinely do not exist --
-- (368 of the 411 the log flags are FALSE POSITIVES: they live in the client
--  Spell.dbc, which spell_dbc only overrides. Verified against the live dbc.)
SOURCE 192_map750_smartai_spells.sql;

-- --- round 45: the one reachable C++ gap, done as SmartAI ------------------
-- Full audit of the Cata zone sources: 62 real candidates, only 2 reachable,
-- one of which (Ruul Snowhoof) is already SmartAI-driven here.
SOURCE 193_naga_brazier_smartai.sql;

-- --- round 45: the remaining dead SmartAI entries --------------------------
-- 6 of 8 had a SPURIOUS AIName (source has none) -> cleared, not scripted.
-- 1 (Frostsaber Cub) deliberately skipped: source casts a non-existent spell.
SOURCE 194_dead_smartai_cleanup.sql;

-- --- round 45: retire the 45 quests that cannot be completed ---------------
-- MUST run after 180_ (that file recreates queststarter links from the source).
-- Keeps 28395/28396/29199: no POI marker, but verified completable.
SOURCE 195_retire_uncompletable_quests.sql;

-- --- round 45: SmartAI the source has that map 750 never imported ----------
-- 54 creature entries + 2 action lists + 1 gameobject. MUST run after 192_:
-- 43 of the spells these scripts cast are minted there.
SOURCE 196_smartai_coverage_import.sql;

-- --- round 45: flight-master defects found by the map-750 POI audit -------
-- LAST on purpose. It despawns a duplicate Kroum, clears a stray FLIGHTMASTER
-- flag and moves Mishellena onto her taxi node -- all corrections to spawn
-- data, so anything that re-imports spawns (176_/177_/178_/212_ ...) must run
-- BEFORE it or the fixes are silently undone, the way 155_ once undid 154_.
SOURCE 220_map750_flightmaster_cleanup.sql;

-- --- round 45: gossip + text layer -----------------------------------------
-- 51 NPCs had a gossip_menu_id with no menu row; 28 entries had no
-- creature_text while the source did. Run BEFORE 196_ so its new Talk
-- actions have lines from the first restart.
SOURCE 197_gossip_and_texts.sql;

-- --- HOTFIX: 2 spells with a Cata-only effect id crashed LoadSpellInfoStore -
-- Only needed if 192_ was applied in its pre-guard form. 192_ now skips them.
SOURCE 198_hotfix_spell_effect_out_of_range.sql;

-- --- round 45: rows SmartAIMgr rejects at load (13 rows + 1 dead trigger) ---
-- These are SKIPPED by the core, so the behaviour does not exist in game.
SOURCE 199_smartai_validation_repair.sql;

-- --- Plaguelands (map 751): finish the SmartAI import ----------------------
-- 200_ MUST precede 201_: it mints the 27 spells those scripts cast.
-- Stock maps (0/1/530/571) deliberately NOT touched -- see 201_ footer.
SOURCE 200_map751_smartai_spells.sql;
SOURCE 201_map751_smartai_coverage.sql;

-- --- round 45: one flight UI on map 750 -- the native taxi frame ----------
-- Retires the gossip fallback now that WorldMapContinent row 9 + the rebuilt
-- TaxiMap750.blp make the native map work. Map 751 KEEPS the script: it has no
-- WorldMapContinent row, so the native frame cannot render there.
-- After 220_, which is what puts every flight master on its node.
SOURCE 221_map750_native_flightmasters.sql;

-- --- round 46: the SmartAI defects the log only half-reported ---------------
-- 222_ is the big one and it is NOT cosmetic. This fork reads the distance for
-- range-based events from params 5/6 (minMaxRepeat.rangeMin/rangeMax), while
-- upstream AzerothCore reads params 1/2 -- and the Cata imports followed
-- upstream. 226 of 245 clone-band rows put the distance where the engine never
-- looks, so ranged abilities fire only at contact range. Only 17 of them logged
-- anything. Run this before judging any map-750 combat behaviour.
SOURCE 222_smartai_range_param_layout.sql;

-- 223_ mints the last 9 spells SmartAI casts that exist nowhere on this server.
-- Verified absent from BOTH the live Spell.dbc and spell_dbc, and all 9 cleared
-- the effect-range guard, so this batch cannot repeat the 198_ boot crash.
SOURCE 223_map750_751_smartai_spells.sql;

-- 224_ finishes the class 199_ started: 5 rows dropped at load for a stray
-- target_param1 on a NO_PARAMS target type.
SOURCE 224_smartai_unused_target_params.sql;

-- --- round 46: 40 missing creature displays + 3 faction templates ----------
-- Hundreds of "has no model defined in table `creature_template_model`" lines
-- per boot: 32 entries / 277 spawns whose ONLY display ids are absent from
-- CreatureDisplayInfo.dbc, so the core drops every model and refuses the spawn.
-- NOTE this SQL alone changes NOTHING at runtime -- the *_dbc tables are an
-- overlay the server does not read. The compiled DBCs must be copied to the
-- server's data/dbc; see the file header for the three filenames and counts.
SOURCE 225_map750_751_missing_displays_and_factions.sql;

-- --- round 46: vehicles ----------------------------------------------------
-- 39 of the 60 VehicleIds the clone band uses were absent from Vehicle.dbc, so
-- 44 templates / ~250 spawns (Warsong Shredder, Ashenvale Wrecker, Watch Wind
-- Rider x27, Tendril from Below x79 ...) spawned as un-rideable NPCs. Includes
-- the 73 VehicleSeat rows they reference, spellclick for 10 vehicles that had
-- none (3 of them flagged SPELLCLICK with no row = dead cursor), and the one
-- missing click spell. Like 225_, the overlay rows here do NOT fix it on their
-- own -- Vehicle.dbc/VehicleSeat.dbc must reach the server's data/dbc.
SOURCE 226_map750_751_vehicles.sql;

-- --- round 46: the 7 vehicle passengers 226_ had to skip -------------------
-- All 7 parent vehicles are spawned (83 spawns; Twilight Buzzard alone x47),
-- so they currently stand there riderless. Imports the 7 passenger templates
-- (offset follows the PARENT's band -- the Twilight Rider chain is +3.7M, not
-- +3.6M), their models, the 2 missing creature_model_info rows, display 36722,
-- and vehicle 734 + seat 7696 + spell 97400 for Treetop, which is itself a
-- vehicle. MUST RUN AFTER 226_.
SOURCE 227_map750_751_vehicle_passengers.sql;

-- --- round 46: linked traps inside gameobject_template --------------------
-- "Gameobject (GUID: 674 Entry: 194465) not created" -- the guid is a RUNTIME
-- guid, not a spawn: a GOOBER spawns its own linked trap, and the trap id
-- embedded in data12 was never remapped by the clone import. 2 templates,
-- 60 spawns (Lava Fissure x37, Ritual Gem x23) whose traps never appear.
SOURCE 228_map750_linked_trap_remap.sql;

-- --- round 46: summon spells pointing at raw Cata entries ------------------
-- Same class as 228_, found by applying its lesson to the spells the earlier
-- rounds minted: EffectMiscValue on a summon effect is the creature entry, and
-- it was copied from Cataclysm verbatim. 4 spells, all with live casters
-- (Spitelash Seacaller x14, Skullmage x7). Imports the 3 summon targets that
-- were never brought across; the 4th already existed as a clone.
-- 223_ was also corrected at source, so the UPDATEs here are value-guarded
-- no-ops if 223_ is applied after that fix. Needs no DBC deploy.
SOURCE 229_map750_751_summon_targets.sql;

-- --- round 46: patrol paths the later spawn imports skipped ----------------
-- 202_ restored waypoints for the spawns that existed in Aug 2026; the terrain
-- expansion that followed added thousands more and did not repeat it, leaving
-- 41 patrollers standing still (Brumeran 96 points, Nemesis 60, Lava Surger 48,
-- Everlook Bruiser 33 ...). Path id = spawn guid, same convention as 202_.
-- The addon rows are derived FROM the waypoint rows this file just inserted, so
-- a source path with no points can never produce a dangling link.
SOURCE 230_map750_751_missing_waypoints.sql;

-- --- round 47: the classic 80-130 leveling-band project (231-241) ----------
-- Zone bands: Darkshore/Azshara 80-90 (faction starts) -> Ashenvale 88-98 ->
-- Felwood 96-106 -> Winterspring 104-115 -> Hyjal 113-130; Moonglade stays a
-- sanctuary. 231/232 are HARD PREREQUISITES of everything after them, and 233
-- must be the first thing that ever changes levels in the clone band (it
-- snapshots the baseline). Companion content layer: Level Areas/Cata Hyjal
-- 80-130/ files 40-43 (run AFTER this runner). DBC side: AreaTable.csv band
-- renames + Spell.csv 300602/300603 (recompile + deploy), HotspotMgr.cpp
-- zone boxes + Hotspots.EnabledZones conf (rebuild + restart).

-- zoneId/areaId backfill (8,952 untagged spawns) + the dc_map750_entryzone
-- join tables every later file uses.
SOURCE 231_map750_zone_backfill.sql;

-- fork the 389 pre-offset lootids (133 shared with stock mobs) so loot edits
-- cannot leak outside map 750: lootid == entry becomes an invariant.
SOURCE 232_map750_loot_fork.sql;

-- the hard re-level: linear per-zone remap onto the bands, rank rules, flat
-- band-top service NPCs. Supersedes 101_'s rank-4 level lift (runs after it).
SOURCE 233_map750_relevel_bands.sql;

-- QuestLevel = -1 (player-scaled XP) + per-band MinLevel for quests whose
-- starters are exclusively map-750 entities.
SOURCE 234_map750_quest_levels.sql;

-- coin drops for the ~80% of killable coin-type mobs that had none.
SOURCE 235_map750_gold_backfill.sql;

-- spread the ~625 Cata drop-gear shells' RequiredLevel across the bands.
SOURCE 236_map750_gear_reband.sql;

-- 400xxx ladder as uncommon zone drops (reference loot 750080-750113) +
-- Emberwood Sap token on every killable with a loot table.
SOURCE 237_map750_refloot_ladder.sql;

-- re-tune ladder tiers to 82/92/102/115 -- closes the 101-120 gear hole with
-- no new item ids (hence no client patch).
SOURCE 238_map750_ladder_retune.sql;

-- skinning backfill from cata_world (Hyjal had 2 skinnable beasts).
SOURCE 239_map750_skinning_backfill.sql;

-- second vendor backfill: 38 vendor-flagged templates with empty windows.
SOURCE 240_map750_vendor_backfill2.sql;

-- clear areatable_dbc overrides so the recompiled AreaTable.csv wins.
SOURCE 241_map750_areatable_overrides.sql;

-- --- round 48: zone-themed loot + upgrade-token integration ----------------

-- loot density: copy the Cata loot tables for the killables that had none
-- (lootid = entry invariant, plain resolvable rows only).
SOURCE 242_map750_loot_backfill.sql;

-- five zone-themed 15-piece leveling sets (400708-400782), stat-clones of the
-- ladder with Cata+ displays from the downport corpus. Generated file -- edit
-- Documentation/scripts/data/zone_themed_sets.csv + re-run the generator.
SOURCE 243_map750_zone_themed_sets.sql;

-- item-upgrade integration: close the dead ilvl 227-299 tier window (T2->299)
-- and drop Upgrade Tokens (300311) from rares/bosses. `.upgrade prog reload`
-- after apply.
SOURCE 244_map750_upgrade_tokens.sql;

-- re-derive the passes that depend on the new loot tables and themed items:
-- 236_ re-bands gear now dropped by the 242_-backfilled mobs, 237_ fills the
-- per-zone themed references (empty on the first pass, before 243_ existed)
-- and extends ladder/token hooks to every new loot table. Both idempotent.
SOURCE 236_map750_gear_reband.sql;
SOURCE 237_map750_refloot_ladder.sql;

-- band-aware consumable rollout: the 400800-400823 food/drink/potion line on
-- every innkeeper and goods vendor map-wide (supersedes 98_'s nine-vendor
-- stocking; spells 300550+ verified present in spell_dbc).
SOURCE 245_map750_consumables_rollout.sql;

-- open-water fishing for all seven zones (classic pools re-keyed + Cata-fish
-- bonus layer) and the rod/lure kit on the three fisher vendors.
SOURCE 246_map750_fishing.sql;

-- Molten Front (map 861) data-side endgame integration: 128-130 re-level +
-- daily-quest scaling. Teleporter 413 stays GM-gated until the 861 terrain
-- deployment (HYJAL_MOLTENFRONT_HANDOFF.md E0/E03).
SOURCE 247_map861_molten_front_endgame.sql;

-- SmartAI/ScriptName repairs round 2 (2026-08-04 full-zone audit): restore
-- AIName on 52 templates whose imported scripts were dead, +1 GO; stable
-- master ScriptNames; drop one cata-guid-targeted row. Restart required.
SOURCE 248_map750_smartai_repairs2.sql;

-- --- round 53: dropped-cast backfill + Azshara choreography ----------------

-- 10 Cata spells the dropped SmartAI casts need (server-side spell_dbc,
-- 194_'s method). MUST run before 250_.
SOURCE 249_map750_dropped_cast_spells.sql;

-- re-import of the SmartAI rows the imports dropped: 32 entries / 63 rows
-- (pinned; 40 entries excluded for id-drift and listed in the header for
-- manual review). Fork range-param layout + actionlist 360384801 included.
SOURCE 250_map750_smartai_row_backfill.sql;

-- Wings of Steel + Slinky Sharpshiv (C++: zone_azshara_cata.cpp, REBUILD
-- REQUIRED) and the Sentinel Aynasha escort (SmartAI + waypoints).
SOURCE 251_map750_azshara_choreography.sql;

-- closes 250_'s two open items: retunes the event-67 row whose cata cooldowns
-- were shifted into the range params, and records why the 40 "id-drift"
-- entries must NOT be imported (they already carry the correct stock scripts).
SOURCE 252_map750_smartai_finalise.sql;

-- --- round 54: token rewards made visible + tokens become real currency ----

-- band-scaled Upgrade Token rewards in the quest turn-in box (603 quests).
-- PAIRS WITH the C++ change that stops the token hook double-paying these.
SOURCE 253_map750_quest_token_rewards.sql;

-- route both DC tokens into the Currency tab instead of bag space (the
-- CurrencyTypes.dbc rows already existed; only BagFamily was missing).
SOURCE 254_dc_upgrade_tokens_as_currency.sql;

-- re-price the rare/boss token drops against the quest economy (244_ gave a
-- named rare 1-3 tokens; a quest now pays 20-75). Supersedes 244_ section 2.
SOURCE 255_map750_rare_token_rescale.sql;

-- --- round 55: the movement audit 202_/230_ could not finish ---------------

-- 13 spawns whose patrol path was imported and bound but whose MovementType
-- was never flipped, so the route sits unread and logs nothing (Thartuk 175
-- points, Terrorpene 73, Garr 30). Plus 2 wander restores. No new rows.
SOURCE 256_map750_movement_flags.sql;

-- the routes position-matching structurally could not reach: Felwood on 750
-- carries Cata entries on the PRE-Cata spawn layout, so the Cata patrol layer
-- had nothing to bind to. 18 routes matched by distance-to-route instead.
SOURCE 257_map750_felwood_moonglade_waypoints.sql;

-- --- round 25: the 2026-08-06 Errors.log sweep of maps 750 / 751 / 861 ------

-- 258 MUST come first: 261_ section 2 and every discarded SmartAI cast row on
-- both maps depend on the 32 spells it downports (SmartAIMgr drops any row
-- whose spell is unknown at load, so applying the consumers first would import
-- them and immediately throw the rows away -- the same ordering constraint
-- MoltenFront/19_ has against 16_).
SOURCE 258_map750_smartai_missing_spells.sql;

-- 259: 17 quest objectives still naming raw Cata ids whose clone was never
-- created, so 17 quests log "quest can't be done". Carries its own two-spell
-- prerequisite inline.
SOURCE 259_map750_quest_objective_clones.sql;

-- 260: 38 items and the 16 loot tables behind 236 empty Cata quest containers.
SOURCE 260_map750_container_items_and_loot.sql;

-- 261: the four one-off boot-log defects left over. Depends on 258_.
SOURCE 261_map750_boot_log_singletons.sql;

-- 262: the 7 creature + 13 item displays 259_/260_ referenced but this client
-- did not have. Must follow both (its section 3 updates 260_'s items). The
-- client DBCs are already compiled and deployed; this is the server half.
SOURCE 262_map750_missing_displays.sql;

-- 263: 56 of the 70 spawns 259_'s objective clones need. Requires 259_ (the
-- templates) and 262_ (creature_model_info gates whether a spawn loads at all).
-- 14 are deliberately left unplaced -- see the file header for the terrain
-- evidence.
SOURCE 263_map750_objective_spawns.sql;

-- 264: the three regressions round 25 introduced, found in the post-apply boot
-- log. Two AIName-with-no-rows and one TALK-with-no-creature_text.
SOURCE 264_map750_r25_followup_fixes.sql;

-- 265: the 32 items creature_loot_template references but item_template lacks,
-- unblocking 145 loot rows. Global, not map-750-scoped -- filed here because
-- this is where the round's tooling lives.
SOURCE 265_loot_missing_items.sql;

-- 266: the loot orphans. Section 1 (16 clones missing the Emberwood Sap token)
-- MUST run before section 2 -- it is what makes those raw tables redundant and
-- therefore safe to drop. Plus the 164407 group-chance overflow and 175102.
SOURCE 266_loot_orphans_and_group_fixes.sql;

-- 267: backfills every item/creature/object quest_template references. Silences
-- the whole "Loading Quests..." block. NOTE: all 62 affected quests are
-- unreachable (no spawned questgivers), so this is structural completeness, not
-- a gameplay fix -- see the file header.
SOURCE 267_quest_reference_backfill.sql;

-- 268: restores the questgiver relation layer for the orphaned Cata quests --
-- ~111 quests become genuinely playable on 106 already-spawned NPCs. Enders are
-- inserted BEFORE starters on purpose: the starter gate requires a turn-in path,
-- so 29 quests that would otherwise be acceptable-but-uncompletable are skipped.
SOURCE 268_quest_relation_layer.sql;

-- 269: binds at_mh_hyjal_barrow_dens to areatrigger 5876 (quest 25325's only
-- completion path). Does NOT bind npc_darkshore_wisp_circling -- ScriptName
-- outranks AIName, so that would kill the wisps' sparkle; the drift is added as
-- a SmartAI row instead. See the file header.
SOURCE 269_unassigned_script_names.sql;

-- 270: 36 GameObjectDisplayInfo rows so 269 map-750 gameobjects LOAD at all --
-- including the 59 Thorned Bloodcups 260_ gave loot to. Plus 13 non-unit
-- rotations and 7 elevators with an invalid state.
SOURCE 270_gameobject_display_and_spawn_fixes.sql;

-- 271: 17 crash-class creature displays (the Winterspring/Felwood clone band)
-- plus every remaining broken KillCredit -- 15 of them, three classes of which
-- are my own offset/reference-sweep mistakes from 258_ and 267_ -- and the two
-- VehicleIds that freeze the client. Must run after 267_ (its raw imports are
-- what 41087/41866 are credited to).
SOURCE 271_creature_display_and_killcredit_fixes.sql;

-- 272: 51 Cata aura spells. HARD PREREQUISITE of 273_ -- LoadCreatureAddons
-- drops any aura whose spell is unknown, so applying 273_ first silently loses
-- them. 16 of the 51 sit in the WotLK 62000-70000 id band and are Cata content
-- anyway; do not infer presence from the range.
SOURCE 272_spell_dbc_creature_addon_auras.sql;

-- 273: the creature_addon layer maps 750/751/861 never got -- 5,443 spawns get
-- their stand/anim tier, sheath, emote, mount and visibility distance. Insert
-- only, no DELETE (see the file header -- the table is shared with the waypoint
-- path_id rows and with Plaguelands' own import). Invisibility/stealth/phase
-- auras are stripped so nothing can be hidden or phased out of phaseMask 1.
SOURCE 273_creature_addon_layer_import.sql;

-- 274: gameobject_template data0/data1. The map-750 half is closed by three
-- client DBCs (Lock +9, SpellFocusObject +13, Spell +7, all deployed); this is
-- the spell_dbc mirror plus the 5 lock ids that exist in no client and are
-- cleared. Read the header before believing the log's lock values -- the core
-- prints data1 while validating data0 for every type except DOOR/BUTTON.
SOURCE 274_go_locks_spellfocus_and_spells.sql;

-- 275: the 2 key items 274_'s locks ask for. Must follow 274_ -- the locks it
-- adds are what reference them. No boot line for this class (LOCK_KEY_ITEM is
-- not validated at load), so it is only findable by sweeping the lock rows.
SOURCE 275_lock_key_items.sql;

-- 276: vehicle_template_accessory -- 5 vehicles / 52 spawns get their riders
-- back (Krom'gar Wagon's kodo team, the Ashenvale + Azshara wind riders, the
-- Skychaser hippogryph). Another side table the importers skipped: 10 rows in
-- the clone band vs the source's 371. Needs a restart, not just an apply.
SOURCE 276_vehicle_accessories.sql;

-- 277: random wandering the cata_world import never carried. cata's spawn
-- POSITIONS are good but its MovementType is largely 0 (30.1% wander on
-- Kalimdor vs nelt's 60.9%), so map 750 inherited a static world -- Azshara's
-- 145 wanderers are an exact copy of cata's 145. The import is not at fault:
-- 17,591 of 19,089 spawns position-match a source and only 322 disagree. Fixed
-- per ENTRY against nelt (cata and nelt share <20% of positions, so a position
-- join never consults nelt). 279 entries / 5,407 spawns. Backs up all map-750
-- movement to dc_map750_wander_backup first. Needs a restart, not just an apply.
SOURCE 277_map750_wander_restore.sql;

-- 278: makes 276_ actually take effect. LoadVehicleTemplateAccessories does
-- `continue` when the vehicle has no npc_spellclick_spells row, so all 5 of
-- 276_'s accessory rows were being DROPPED at load and not one rider spawned --
-- the table looked right and did nothing. Adds the 46598 "Ride Vehicle
-- Hardcoded" rows WITHOUT setting the SPELLCLICK npcflag (the core blesses
-- exactly this for creature-only vehicle accessories, ObjectMgr.cpp ~8629).
-- Also clears 8 vestigial SPELLCLICK flags the core strips every boot anyway --
-- all want Cata-only spells we do not have. Must follow 276_.
SOURCE 278_spellclick_vehicle_and_flag_cleanup.sql;

-- 279: cosmetic. 2 Druid of the Talon spawns list `77042 40121 40122` in
-- creature_addon.auras, but 77042 is a MOD_SHAPESHIFT into FORM_FLIGHT_EPIC and
-- HandleAuraModShapeshift already casts 40122/40121 for that form, so the last
-- two are redundant and log "duplicate aura" at every spawn. Nothing is broken;
-- the core skips them. Recurs on any creature_addon import that carries a
-- shapeshift spell -- the sweep query is in the file's verification block.
SOURCE 279_druid_of_the_talon_shapeshift_auras.sql;

-- 280: boot-log round 30, map-750 half. 6 reference loot templates feeding 34
-- map-750 loot tables (those creatures have been dropping short); Lurah
-- Wrathvine's last 5 ExtendedCosts + the 5 trade-in trinkets they demand;
-- Su'ura Swiftarrow's battlemaster row; the Spitelash Siren's dropped Renew
-- (event 74's radius is param6 in this fork, not param2); and the Orgrimmar
-- gossip text + 6 direction POIs -- which also un-breaks the 82 map-1 grunts.
-- The log's pickpocket/skinning/Legion-Dalaran blocks are NOT map 750/861 and
-- are deliberately out of scope; see the file header.
SOURCE 280_boot_log_round30.sql;

-- 281: one UPDATE, 272 rows. gameobject_loot_template 39335 (4 map-750 treasure
-- chests) has LootMode 0 on every row; the core rewrites it to 1 in memory each
-- boot, so nothing is broken -- but it was 36% of the whole Errors.log. Writing
-- the value the core already computes changes no behaviour and clears the noise.
SOURCE 281_treasure_chest_lootmode.sql;

-- 282: the blocks earlier rounds ruled out as "not map 750/861". Blackfathom
-- Deeps clone (map 820): 18 pickpocket tables never cloned (64 rows, 155
-- spawns) and 5 creatures whose skinloot had the +3,900,000 offset applied to a
-- SHARED stock table (100007/100012 -> 4000007/4000012). Plus Deepholm's Albino
-- Cavefish School (24 spawns, no loot table) and 3 sourceless strays cleared.
SOURCE 282_bfd820_loot_and_strays.sql;

-- 283: Blackwing Descent difficulty variants. Clears the ScriptName on all 36
-- heroic templates (BOTH difficulty slots -- the validation loop aborts on the
-- slot-2 failure, so fixing only slot 2 just surfaces 18 new slot-3 lines),
-- matches Chimaeron's family on its two variants, clears 41440's remaining
-- difficulty_entry_3, adds the GOSSIP flag to 3 NPCs whose menus cannot open,
-- and fixes the one creature in the DB with an out-of-range `type` (the core
-- was silently rewriting a turtle to HUMANOID). Corrects 271_'s claim that this
-- class was upstream and cosmetic.
SOURCE 283_difficulty_variants_and_singletons.sql;

-- 284: pool_gameobject, 111 skipped rows on the Hyjal/Plaguelands herb pools.
-- 59 point at gameobjects that do not exist; 45 more are minority-map members
-- of pools the importers copied straight from a CROSS-MAP nelt herb rotation
-- (the description column still records map=0/1/530). Deleting the 45 makes
-- every pool single-map, which clears all 52 of those lines regardless of which
-- member the loader happens to see first. 0 pools are emptied.
SOURCE 284_pool_gameobject_cleanup.sql;

-- 285: deletes the 5 DC herb nodes spawned in Outland (backed up to
-- dc_stray_go_backup_530 first, DELETE joins the backup so removed == saved),
-- and REPAIRS 284_: its majority tie-break broke 3-way map splits on the lowest
-- map id, which kept the Outland junk in pools 131011137 / 131013413 and
-- dropped their real map-751 members. Those two are restored. Must follow 284_.
SOURCE 285_outland_stray_herbs.sql;

-- 286: the achievement_criteria_data row for criterion 13512 -- FATAL, not
-- cosmetic: a missing row is treated as FAILED, so achievement 60050 "Crescent
-- Grove" was unearnable. Its six siblings were fixed earlier; this one was
-- missed. Plus 21 quest reward spells downported from the Cata client -- 28
-- quests were handing out nothing on turn-in, 17 of them reachable.
SOURCE 286_quest_reward_spells_and_achievement.sql;

-- 287: boot log round 31, ten classes and almost all of them behaviour rather
-- than noise -- 175 inert Azshara land mines (a Cataclysm faction template that
-- does not exist in 3.3.5), 20 ore nodes that stopped spawning as collateral
-- from 284_, 26 NPCs with no equipment layer, a dead Twilight Speech teleport
-- (the destination was filed under the wrong effIndex), two Firelands necks
-- silently handing out three stats instead of four, and quest 700709 -- undoable
-- since it was written, fixed twice on paper and never actually applied.
-- Also restores quest 13250, the ONLY stock AzerothCore quest missing from this
-- database (proven by diffing the whole 0-14,500 stock id range).
-- NOTE: read boot logs through ACMCP. K:/Dark-Chaos/Server/logs/Errors.log is a
-- stale Feb-2026 map_bots Win64 build and its 17k lines describe a different DB.
SOURCE 287_boot_log_round31.sql;

-- 288: two things the boot log cannot see. (1) SIX mobs on the levelling
-- continent are still at vanilla levels 18-40 -- 233_ re-levels by joining
-- dc_map750_entryzone and silently skips anything with no row there, so a
-- level-95 player in Astranaar meets level-22 Sentinels. Zones were derived from
-- the modal zone of spawned neighbours within 250 yd, not from the names.
-- (2) 193 mobs across 2,859 spawns drop literally nothing (65 not even copper),
-- including Flamewaker Centurion's 153 spawns. NOT an import miss -- both source
-- DBs agree they are loot-less -- so this is AUTHORED content: each gets its own
-- zone's gear-ladder reference at the same chance its neighbours already use.
-- The vanilla trash reference 45009 was deliberately NOT added; it is
-- un-rescaled classic loot and would spread the ilvl problem into Hyjal/861.
-- Must run AFTER nothing in particular, but its own section 1 before section 2.
SOURCE 288_map750_loot_and_level_stragglers.sql;

-- 289: the 19 `creature_template_addon` "wrong spell in auras" lines. 20 ids,
-- all present in the Cata 4.3.4 client -- but only SIXTEEN are downported.
-- Screening for MOD_STEALTH/MOD_INVISIBILITY/PHASE (273_'s check) caught four
-- INVISIBILITY auras carried by 6 templates / 102 spawns in Ashenvale, all
-- visible today only because the spell is missing and the aura silently fails.
-- Adding them would hide 102 spawns -- r23's bug re-created -- so they are
-- stripped from creature_template_addon instead, which clears their lines too.
-- Spell.dbc for the 16 is ALREADY compiled and deployed (53,298 -> 53,314;
-- 0 ids lost) to Custom/CSV DBC + Custom/DBCs + patch-4 + patch-enGB-3 + the
-- three WXL checkouts + Server/data/dbc. Only the live server copy is pending.
SOURCE 289_creature_addon_auras_round40.sql;

-- 290: the three things 288_ deferred, and two of them turned out to be bugs in
-- EARLIER files rather than tuning. (1) GOLD -- 235_'s curve is fine, but its
-- "only where snapshot gold was 0" guard preserved vanilla values authored for
-- level 16-51 while 233_ pushed those creatures to 92-130, so Akkrilus is a
-- level-100 rare worth 34 copper; applied as a FLOOR over 271 templates, which
-- also covers map 861 -- 235_ joins dc_map750_entryzone and Molten Front has no
-- rows there, so it was never touched at all. (2) SKINNING -- 239_ joined
-- cata_world for BOTH clone bands; the +3.7M band's source is nelt_world, which
-- has skin tables for 23 beasts cata reports as unskinnable. (3) JUNK LOOT --
-- 4,118 ilvl-<60 gear rows on level-87 mobs removed (backed up; 0 tables
-- emptied, cloth/mats/consumables untouched), 22 tables given a ladder ref.
-- (4) closes the long-standing "useless loot table" class: 107 orphans PROVEN
-- to be strict duplicates of live +3.7M tables, 4,002 rows, backed up.
SOURCE 290_map750_gold_skinning_and_junk_loot.sql;

-- 291: finishes a job 290_ could not finish itself, plus four small ones.
-- 🔴 290_ has an ORDERING BUG: its section 3 strips ilvl-<60 gear from the live
-- forked tables, which broke section 4's "orphan must be a strict subset of the
-- live clone" test -- so section 4 correctly DECLINED 104 of 107 orphans and
-- deleted only 3. Nothing was lost; the guard did its job where a blind DELETE
-- would have taken all 107 (the 266_ mistake). Section 1 here re-runs it with a
-- corrected test (in the live clone OR is gear 290_ deliberately removed):
-- 104/104 redundant, 0 unproven, 3,975 rows.
-- Also: 4 creatures whose skinloot points at an empty table (the other half of
-- 239_'s wrong-source bug); areatrigger 5876 -- and 287_'s claim that it would
-- clear on restart was WRONG, the check reads the `areatrigger` TABLE despite
-- saying "AreaTrigger.dbc", so at_mh_hyjal_barrow_dens has never fired;
-- quest 13569 SpecialFlags; quests 25251/25265 sorted into non-existent Gilneas;
-- and a SmartAI WP_START pointing one id below its own authored path.
-- Map-750 elevators fixed outside SQL: TransportAnimation.dbc 5,289 -> 5,503.
SOURCE 291_boot_log_round35.sql;

-- 292: the LAST 11 "useless creature_loot_template" lines, and they are a
-- different shape from the 211 already removed -- which is also why my own
-- post-291_ check wrongly reported zero. A `Reference` value resolves against
-- the REFERENCE store, never the creature store, so an id can be referenced 11
-- times and still have a dead creature-store table of the same number. All 11
-- have a populated reference-store entry (which keeps working, untouched) and
-- zero users as a lootid, so the creature-store copy is unreachable: 215 rows.
-- Plus 2 live scripts wired up -- spell 82848 Massacre (the only unassigned one
-- of Chimaeron's ten) and spell 61244, an UPSTREAM row from update
-- 2026_06_30_01 that something deleted after the updater marked it applied.
-- The other 4 unassigned scripts are each explained in the file and must NOT be
-- assigned blind -- one of them (npc_darkshore_wisp_circling) would override
-- SmartAI on 29 spawns and kill the very sparkle its header says it preserves.
SOURCE 292_boot_log_round36.sql;

-- 293: Winterspring finally gets its own gear tier -- ilvl 385 / ReqLvl 108,
-- between Felwood's 372/102 and Hyjal's 398/115. It had been dropping a set
-- identical in tier to Felwood's, so levels 104-115 gave no step-up.
-- NOT the project I estimated: Winterspring already HAS its own 15 items
-- (400768-400782, the Frostsaber Stalker's set) -- 243_ just generated them at
-- Felwood's ilvl -- and Item.dbc carries no ItemLevel/RequiredLevel, so this is
-- ONE UPDATE over 15 rows with no new ids, no DBC rebuild and no client deploy.
-- Scale factor 1.069 is measured off the 372->398 gap (1.1380 across 26 ilvl,
-- halved), so the new tier interpolates and cannot overtake Hyjal's.
-- Verified: those items are referenced by reference_loot_template ONLY, and
-- both 372 and 385 resolve to upgrade tier 10, so nothing else moves.
SOURCE 293_winterspring_gear_tier.sql;

-- 294: the Legion Dalaran block -- the last big class in Errors.log, 36 lines.
-- Reframed rather than downported: **20 of the 36 templates are not spawned at
-- all**, and the 16 that are (map 1413) are overwhelmingly PROFESSION STATIONS,
-- not portals. 3.3.5's entire crafting-focus vocabulary is Anvil/Loom/Forge/
-- Cooking Fire, so six stations get a REAL substitute and start working
-- (Alard's forge+anvil+workbench, Namha's workbench, Forge of Power); the rest
-- are neutralised to type 5 GENERIC -- alchemy, leatherworking and tailoring
-- need no station in 3.3.5, so there is nothing to substitute and pretending
-- otherwise would be worse. Every retail id is recorded in the file's REVERT
-- block for a future Legion port. Not invented here: portals to Wyrmrest Temple
-- and Stormwind, whose destinations DO exist -- those are features, not fixes.
SOURCE 294_legion_dalaran_go_substitutes.sql;

-- 295: answers "were all gameobject_template_addon rows ported for map 750?"
-- No. 706 of the map's GO templates resolve to a cata_world source, ALL 706 have
-- an addon row there, and we held 532 -- 174 dropped on import (the recurring
-- offset-band gap: the template comes across, its addon does not).
-- 112 of the 174 are provably harmless: their source rows are all-default across
-- all nine columns, and GameObject.cpp:324-328 only applies the addon block if a
-- row EXISTS -- so inserting 0/0 over an already-0/0 default is a no-op. Those
-- are deliberately left out so the next audit stays readable.
-- The real gap is 62 templates / 732 spawns: 32 losing a faction (mailboxes, ore
-- veins, area markers) and 37 losing flags -- mostly GO_FLAG_INTERACT_COND 0x04
-- on ~40 quest objects that are currently clickable with no condition gate.
-- Checked first, because 287_ was bitten by it: every faction here EXISTS in
-- factiontemplate_dbc (no Cata-only 2206 case), and 0 of the 174 carry
-- GO_FLAG_TRANSPORT 0x08, so the elevator defect is not in this set.
SOURCE 295_map750_go_template_addon_backfill.sql;

-- 296: Errors.log jumped 87 -> 361 lines, and it is NOT a regression -- the new
-- 4.8M/5.0M/5.2M-5.4M bands are the map 751 Plaguelands and map 825 Shadowfang
-- Keep imports arriving with the usual offset-band classes.
-- 273 gameobject_loot rows at LootMode 0 (dead rows the core patches in memory);
-- 23 Plaguelands chests/herbs whose loot table was never created (band is
-- +4,600,000, verified by name 25/25); the 3 Cauldron Lords' loot; Belmont's
-- lootid cleared because cata agrees he has none; npc_text 17706 so Brazie the
-- Botanist has a greeting; 2 unspawned Levers' phantom SmartGameObjectAI.
-- TWO CROSS-DB SCHEMA TRAPS handled: cata's loot tables have 11 columns to our
-- 10 (extra IsCurrency), and npc_text is 90 columns in both but in a DIFFERENT
-- ORDER -- so every INSERT names its columns on both sides.
-- Blocked on one item downport: 5 Cata quest items (60741, 60953, 60871-3) and
-- 69988. Deferred: spells 95303/95305 need spell_target_position rows or the
-- teleports go nowhere, and cata has a destination for only one of them.
SOURCE 296_plaguelands_shadowfang_loot_round37.sql;

-- 297: the one CRASH-CLASS line in the log -- Baron Ashbury (5046962, live on
-- map 825) and his difficulty twin carry VehicleId 1422, which Vehicle.dbc does
-- not have: "This *WILL* cause the client to freeze!".
-- Downported rather than zeroed (66_/82_ zeroed three map-750 vehicles to dodge
-- this same error and it had to be undone later). Vehicle 1422 copies verbatim
-- -- both clients are 40 fields/160 bytes -- but VehicleSeat 9362 does NOT:
-- Cata is 66 fields/264 bytes to our 58/232, so the generator re-maps it and
-- self-validates against seat 7683 before emitting.
-- NOTE the obvious audit query lies here: `vehicle_dbc` is an OVERLAY of 90
-- custom rows, so "459 rows with a missing VehicleId" is meaningless -- the real
-- check is read_server_dbc against Vehicle.dbc, where exactly ONE id is absent.
-- Client half already deployed + re-verified in patch-4 and patch-enGB-3.
SOURCE 297_shadowfang_vehicle_1422.sql;

-- 298: four small classes from the 751/825 imports, 13 log lines.
-- 2 GO spellcaster spells (83837/84936, both screen clean, no TARGET_DEST_DB so
-- no spell_target_position needed); 7 difficulty variants whose ScriptName is
-- IDENTICAL to their parent (provable no-op, guarded on that equality); 2 spawns
-- with wander_distance but MovementType 0.
-- LOCKS 1856/1945 are DBC-side and already deployed -- and note the lock error
-- NAMES THE WRONG FIELD: it says "data0" while printing Data1 (a questId and a
-- lootid, both correct). Settled against Lock.dbc, where Data0's 1856/1945 are
-- the ids genuinely absent.
-- 🔴 Rebuilding Spell.dbc from CSV would have DELETED 13 spells (CSV 54,109 vs
-- deployed 54,120) -- used spell-dbc-append.py, 0 ids lost. Never csv2wdbc the
-- 234-field fork Spell.dbc.
SOURCE 298_plaguelands_locks_spells_round40.sql;

-- 295: Talonbranch Glade (Felwood) reported as "looking strange". Not a
-- coordinate bug -- every spawn there is a 0.00 yd verbatim copy of its own
-- source. It is the additive double layer from 181_/183_: Cata moved Kaerbrus
-- 30 yd and put Elizabeth Nesworth on his old tile, so the vanilla pair now
-- stands INSIDE her (3.5/4.3 yd). Moves Kaerbrus + Shi'alune to their Cata
-- coordinates, drops Malygen/Mylini out of the air (stock AC Z 574.6 vs ~568
-- real ground on this Cata heightmap), and re-factions the five vanilla
-- service NPCs 80 -> 2164 so Horde stops seeing half the camp as Hated.
-- Zone-wide cross-layer sweep confirms Talonbranch is the only settlement
-- where the double layer collides on named NPCs.
SOURCE 295_talonbranch_layer_overlap.sql;

-- 299  Round 41 -- the 6 Cata quest items (60741, 60871-3, 60953, 69988) and the
-- 9 dangling loot ids they free: gameobject_loot_template 4805099 / 4805363 /
-- 34671 / 34677 / 34678 and spell_loot_template 99500. Client half already
-- deployed (Item.csv + Item.dbc 154,936 -> 154,942, 0 ids lost); the refreshed
-- Item.dbc MUST reach the live data/dbc before the restart, or the core logs six
-- new "does not exist in Item.dbc" lines instead. Also records the DBC-only fix
-- for gameobject display 9901 (Book of Lost Souls, map 825) -- Cata's 21-field
-- GameObjectDisplayInfo is our 19 plus two trailing floats, so the row copies
-- straight across; appended to the binary, 0 existing rows changed.
SOURCE 299_plaguelands_quest_items_and_loot_round41.sql;

-- 300  Round 42 -- the 6 spell-script effect mismatches, the Shadowfang Keep
-- teleporter and Anchorite Truuen's escort. SQL half: spell_dbc fixes for 329725
-- (aura 0 -> 4; retail's 395 would trip the TOTAL_AURAS assert at boot) and
-- 329181 (single-target -> area + retail's own 60y radius), the two missing
-- teleport spells 95303/95305, all three spell_target_position rows, gossip menu
-- 12669 + its 3 options, and Truuen's 26-point path from nelt_world. The other
-- four log lines (93572, 105552, 326824, 343995) are C++ only and need a rebuild.
SOURCE 300_spell_scripts_teleporter_escort_round42.sql;

-- 301  Round 43 -- the 11 trainer gossip menus with no `gossip_menu_option`
-- rows (4608, 11877, 12049, 12053, 12531-12533, 12535, 12536, 8006100, 400130).
-- All 12 NPCs behind them are imported/custom (Legion Dalaran, map 750, one DC
-- custom); all 503 stock-range trainer menus already have theirs. The sources
-- only hold options for 11877, so the other ten use our own stock per-class
-- modal text + the same OptionType/Icon/NpcFlag triple. SQL only, no rebuild.
SOURCE 301_trainer_gossip_options_round43.sql;

-- 302  Round 44 -- the last 4 difficulty-variant ScriptNames (SFK worgen ghosts
-- 5050835 / 5050852 / 5051086 / 5051034). 298_'s guard was right; these came back
-- because ShadowfangKeepCata/06_scriptnames.sql and 21_fix_worgen_spirit_scriptname
-- .sql re-set them after it. BOTH SOURCE FILES ARE CORRECTED in this change (they
-- now clear variants instead of filling them), so apply order no longer matters.
-- Also records why the 58 deprecated flags_extra warnings are deliberately NOT
-- migrated to creature_immunities. SQL only, no rebuild.
SOURCE 302_sfk_difficulty_scriptnames_round44.sql;

-- 303  Round 45 -- page_text backfill from the map 751 text audit. 751's text
-- layers are complete except ONE dangling page_text (3743, the Tombstone
-- epitaph); the same DB-wide check found the map 750 goblin-journal chain
-- (3616-3619) missing too. Both taken from nelt_world, which is the only source
-- that has them. Pages 5121/5260 (Legion Dalaran) have no source and stay open.
-- SQL only, no rebuild, and no boot-log change -- page_text is not load-validated.
SOURCE 303_page_text_backfill_round45.sql;

-- 304  Round 46 -- the 16 heirloom armour Subclass mismatches (300341-300363).
-- Resolved as a SPLIT, not by making the DB agree with the DBC: the Strength
-- tier becomes Mail here (server side), while the Agility tier was fixed to
-- Leather in Item.dbc (client, already deployed) because Mail made 8 agility
-- heirlooms unequippable by rogues and druids forever. Intellect tier already
-- Cloth. The refreshed Item.dbc MUST reach the live data/dbc before the restart.
SOURCE 304_heirloom_armour_subclass_round46.sql;

-- 305  Round 47 -- the last missing map-750 patrol routes. 22 spawns matched to
-- their source route by DISTANCE TO THE ROUTE (not to the source spawn) with
-- mutual-nearest and a 25 yd cutoff. The raw match found 76 pairs; 52 of the 54
-- cata ones are routes 202_/230_ ALREADY imported onto a neighbouring spawn of
-- the same entry, and re-importing those would put two creatures in lockstep on
-- one line -- so only the 22 unclaimed routes are here (1 cata, 21 nelt).
-- Includes the Lor'danel Sentinels, Moonglade Wardens, Whisperwind Protector,
-- Nightsaber Rider and Horoo the Flamekeeper from the handoff's patrol list.
-- SQL only, no rebuild. dc_map750_patrol_backup makes it revertable.
SOURCE 305_map750_patrol_restore_round47.sql;

-- 306  Round 47 -- the 5 "authored menu, zero options" gossip dead-ends. Three
-- of them (12895/12899/12970) have no options in cata_world, nelt_world,
-- skyfire_world OR bfa_world either -- greeting-only NPCs, not a defect. The
-- other two (Malfurion 12799, Thisalee Crow 12833) were missing only the LINK
-- rows: every npc_text and broadcast_text they need is already in our DB. Two
-- of Malfurion's four source options are deliberately skipped (identical text,
-- no phase conditions authored anywhere). SQL only, no rebuild.
SOURCE 306_molten_front_gossip_options_round47.sql;

-- 307  Round 47 -- 5 Hyjal elites (Fiery Behemoth, Searris, Kelbnar, Andrazor,
-- Fah Jarakk) that 233_'s `entry BETWEEN 3600000 AND 3799999` guard skipped:
-- they are in the 7,3xx,xxx band, so they still conned level 85-86 in a 113-128
-- zone and never got a loot-ladder reference either. Re-levelled with 233_'s
-- own rank-1 formula (-> 129) and hooked to reference 750113. Must run AFTER
-- 233_ and the 24x_ ladder files. SQL only, no rebuild.
SOURCE 307_map750_73xx_band_relevel_and_ladder_round47.sql;

-- 308  Round 47 -- "Twilight Fanatic yells: Masters, I pledge this $r to you!"
-- reported in game. $r/$n/$c are substituted CLIENT-side from the chat packet's
-- target, and SMART_ACTION_TALK with target_type 0/1 supplies none unless the
-- script set an invoker -- the Fanatic's four rows are all invoker-less events,
-- so it never had one. Fixed the way stock AC does the same yell on Twilight
-- Disciple/Thug: target_type 2 (VICTIM), plus useTalkTarget so the Fanatic and
-- not its victim speaks. Also repairs the "Masters, I pledge this Pin to you!"
-- text we inherited verbatim from cata_world. SQL only, no rebuild.
SOURCE 308_twilight_fanatic_yell_token_round47.sql;

-- 309  Round 48 -- clone + rescale map 750's gear to its own level bands.
-- 2,131 loot items and 413 quest-reward items (Quality 2-4 only; greys/whites
-- stay vendor trash) cloned into 500000+ and rescaled onto the stat curve
-- measured from DC's OWN ladder (budget ~ ilvl^2.13, fitted across all five
-- tiers to ~1%). The 154 shared classic references are CLONED to 751000+, never
-- edited -- they feed maps 0/1 too -- and only map-750 loot is re-pointed, with
-- a guard that every owner of a lootid is a map-750 mob. Quest rewards keep
-- their names and get their zone's budget.
--
-- 🔴 THIS IS PHASE 1 OF 3. The clones are unusable until BOTH follow-ups run:
--   2) tools/gen_item_dbc_append_r48.py -> Item.csv -> dbc-compile --only Item
--      -> deploy to patch-4 + patch-enGB-3 + the server's data/dbc.
--      Without an Item.dbc row ObjectMgr SILENTLY DROPS each item_template row.
--   3) gen_zone_gear_armor_dmg.py (--dbc-dir K:/tmp/cata-itemcurves) -> 310_,
--      which fills the armor and weapon damage this file deliberately left 0.
-- Restart the worldserver only after both.
SOURCE 309_map750_gear_clone_rescale_round48.sql;

-- 311  Round 48 -- QuestLevel. The 539 quests already at -1 self-scale (AC reads
-- the PLAYER's level for XP) and stay untouched; the 101 that kept a fixed
-- vanilla level are remapped onto their zone band with 233_'s own linear
-- formula. MinLevel was already correct and is not touched.
-- 🔴 57 further fixed-level quests are deliberately EXCLUDED: they are also
-- given or turned in by an NPC spawned off map 750, and a quest id is global --
-- re-levelling them would re-tune the quest for a level-20 player in the real
-- world. Only map-750-exclusive quests are changed.
-- Run AFTER 310_ (the armor/damage generator output). SQL only, no rebuild.
-- 310  Round 48 phase 3 -- armor and weapon damage for the 2,536 clones, which
-- 309_ zeroed on purpose because both are DERIVED in Cata. Generated from the
-- real 4.3.4 curve DBCs (K:/tmp/cata-itemcurves) by gen_zone_gear_armor_dmg.py:
-- 313 weapons, 2,007 armor, 216 correctly skipped (neck/ring/trinket have no
-- armor value). Armor comes out correctly ordered by armor class at every slot
-- (cloth < leather < mail < plate; shields 7-12k, as Cata has them).
-- Must run AFTER 309_. See 314_ for a tier inconsistency this exposed.
SOURCE 310_map750_clone_armor_dmg_round48.sql;

SOURCE 311_map750_questlevel_band_round48.sql;

-- 312  Post-apply fix to 309_'s stat maths, found by verifying the live numbers.
-- (1) Negative stats collapsed the budget denominator -- Lapidis Tankard is
-- Agility -15 / Spirit +16, so total_src was 1 and the factor 84, giving the
-- clone -1,261 Agility. 4 clones affected; 309_ is corrected at source too.
-- (2) Single-stat items swallowed the whole slot budget: Cow King's Hide became
-- 761 Stamina where the ladder's BEST piece has 231 in its top stat. 93 clones
-- were over 400, 358 over 250. Caps any one stat at 40% of the item's budget.
-- Recomputes the budget from each clone's own ItemLevel, so it is idempotent and
-- does not depend on the broken values. SQL only, no rebuild.
SOURCE 312_map750_clone_stat_outliers_fix.sql;

-- 313  Repair for a double-apply of 309_. Section D re-points map-750 loot AT
-- the 751xxx clones, so a second run of section C saw those as fresh sources and
-- cloned the clones (gen2 751192+) -- and because C's DELETE wipes gen1's rows
-- before its INSERT reads them, gen2 came out EMPTY while all 1,635 live loot
-- rows had already been moved onto it. Net effect: map-750 mobs dropped nothing
-- and Errors.log grew to 194 KB of "isn't reference id" spam. gen1 was intact
-- (5,218 rows), so this re-points the loot back at gen1 and deletes gen2.
-- 309_ is hardened at source (C and D now ignore refs in 751000-751999), so a
-- third apply is a no-op. SQL only, no rebuild.
SOURCE 313_map750_ref_clone_generation_repair.sql;

-- 315  ⚠ GLOBAL, not map-750: creature_classlevelstats is keyed only by
-- (level, class), so this retunes every creature at level 84+ on every map
-- (~32,000 spawns; 751/750/646/861 carry most of them). Levels 80-83 are left
-- exactly as they are so Naxx/Ulduar/ICC/BWD tuning is untouched.
-- Two problems stacked: map-750 creatures are all exp=0 (the CLASSIC stat
-- column -- 42% of the HP and 29% of the damage of a WotLK mob at the same
-- level), and the 84-255 extension of the table is linear, so it never catches
-- up: a level-130 mob had 13,791 HP and hit for 80.6, i.e. 0.24% of a player's
-- health per swing where WotLK trash was 0.82%.
-- Geometric ramp from level 83 reaching x3 HP / x5 damage at 130, then flat to
-- 255. Guards the `basehp <= 1` placeholder, which ObjectMgr uses as a
-- "borrow from another column" marker -- scaling it would give those creatures
-- 3 HP. Backed up to dc_clstats_backup and idempotent. SQL only, no rebuild.
SOURCE 315_creature_stats_above_83.sql;

-- 316: item_template on-use/on-equip spells from the 2026-09-01 boot log.
-- 22 Cata quest source items (quest_template.StartItem) whose spellid_1/2 point
-- at 4.3.4 spells that were never downported, so ObjectMgr zeroed them and the
-- quests could not be finished. Downports the 23 logged ids plus the 5-spell
-- EffectTriggerSpell closure, imports the 3 missing summon targets at
-- +3,600,000 (with 36130's loot table, which is what quest 14324 needs), and
-- clears the two cosmetic lines in the same block: the Cata cooking-bag
-- BagFamily bit on 5 food items, and item 49533's non-existent Map 256.
-- Client Spell.dbc must be recompiled + packed for tooltips; server side is
-- immediate via spell_dbc.
SOURCE 316_item_use_spells_round49.sql;
