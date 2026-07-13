-- =====================================================================
-- npc_spellclick_spells backfill (Hyjal Molten Front / Legion Dalaran)
-- ---------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): 24 creature_template entries had
-- UNIT_NPC_FLAG_SPELLCLICK set (npcflag bit 0x1000000 in this fork) but no
-- matching npc_spellclick_spells row -- the flag was silently cleared at
-- boot every time ("Removing flag"). This file covers the 20 Hyjal Molten
-- Front + 17 Legion Dalaran entries; the other 4 (Magmaw's Pincer/Wyvern,
-- BWD-adjacent) are in BlackwingDescent/29_spellclick_pincer_wyvern.sql.
-- Hyjal source data: mixed (10 from cata_world, 10 more only present in
-- nelt_world -- same "check the other DB" note as HyjalCata/77_'s Thrall
-- creature_text). All referenced spells now exist in spell_dbc (see 80_).
-- =====================================================================
SET @OFF := 3600000;

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (3639619,3639622,3639627,3639867,3640190,3645416,3652177,3652531,3652884,3652885,3652886,3652887,3652888,3652889,3652890,3652988,3653017,3653297,3653300,3653887,3675024);

-- Hyjal (map 750) -- source rows found split across cata_world and
-- nelt_world; both cross-DB SELECTs are guarded so only the DB that
-- actually has each entry contributes a row.
INSERT INTO `npc_spellclick_spells` (`npc_entry`,`spell_id`,`cast_flags`,`user_type`)
SELECT `npc_entry`+@OFF, `spell_id`, `cast_flags`, `user_type`
FROM `cata_world`.`npc_spellclick_spells`
WHERE `npc_entry` IN (39619,39867,40190,52884,52885,52886,52887,52888,52889,52890,53887);

INSERT INTO `npc_spellclick_spells` (`npc_entry`,`spell_id`,`cast_flags`,`user_type`)
SELECT `npc_entry`+@OFF, `spell_id`, `cast_flags`, `user_type`
FROM `nelt_world`.`npc_spellclick_spells`
WHERE `npc_entry` IN (39622,39627,45416,52177,52531,52988,53017,53297,53300,75024);

-- ---------------------------------------------------------------------
-- Legion Dalaran (map 1413) -- 17 entries genuinely have ZERO spellclick
-- rows in the real LegionCore source (verified via the full-file
-- line-bounded grep methodology from the Legion Dalaran vendor correction,
-- see db-errors-vendor-item-backfill-2026-07-10.md) -- checked cata_world,
-- nelt_world, AND the raw LegionCore_world_2020_04_25.sql dump directly, all
-- empty. Unlike Magmaw's Pincer/Wyvern/Hyjal MF, there's no real data to
-- port here -- the flag itself is the bug (set with nothing behind it,
-- likely a templating artifact from however these rows were generated;
-- targets include actual mount NPCs like hippogryphs AND unrelated "mail"
-- gag entries like NO ADDRESS/NOT ENOUGH STAMPS/BAD HANDWRITING, so it's
-- not a coherent "these all need a ride spell" pattern either). Clearing
-- the flag matches exactly what the server already does automatically at
-- boot, just without the repeated warning.
-- ---------------------------------------------------------------------
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~0x1000000
WHERE `entry` IN (3500091,3500282,3500285,3500299,3500325,3500361,3500369,3500425,3500535,3500536,3500537,3500538,3500544,3500545,3500546,3500562,3500587)
  AND (`npcflag` & 0x1000000) > 0;
