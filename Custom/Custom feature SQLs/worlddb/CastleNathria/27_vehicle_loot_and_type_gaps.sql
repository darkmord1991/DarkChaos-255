-- ===========================================================================
-- Castle Nathria (map 2296) -- 27  Vehicle freeze risk + dead lootids + type/aura gaps
-- ---------------------------------------------------------------------------
-- Boot-log round from a fresh restart (2026-07-25). Four Nathria-scoped classes,
-- each verified against the live DB and the real source dumps before acting.
--
-- ###########################################################################
-- 1. NON-EXISTENT VehicleIds -- the core's own words: "This *WILL* cause the
--    client to freeze!"  (highest severity in the whole log)
-- ###########################################################################
-- 16 creature templates carry 9 distinct Shadowlands VehicleIds:
--     5050, 7189, 7190, 7253, 7335, 7336, 7385, 7387, 7410
-- Vehicle.dbc on BOTH sides tops out at ID 1651 (449 records, verified by parsing
-- Server/data/dbc/Vehicle.dbc and Custom/DBCs/Vehicle.dbc), so none of the nine
-- resolve. There is no modern Vehicle DBC extract anywhere in retailextracts to
-- downport them from.
--
-- Two options were considered:
--   (a) author Vehicle.dbc rows the way MoltenFront/10_ did for Vehicle 1631
--       (real flags + an existing known-good VehicleSeat), or
--   (b) clear the field.
-- (b) wins decisively, because the vehicle data is VESTIGIAL: grepping all of
-- src/server/scripts/DC/CastleNathria/*.cpp for Vehicle / GetVehicleKit /
-- EnterVehicle / SeatId returns ZERO hits -- not one Nathria script, including
-- boss_hungering_destroyer, boss_lady_inerva_darkvein and
-- boss_stone_legion_generals (the only three affected creatures that even have a
-- ScriptName), uses vehicle functionality at all. So (a) would mean shipping nine
-- fabricated DBC rows with guessed seats and a client redeploy, to support
-- mechanics nothing invokes. Clearing the field removes the freeze risk outright,
-- is server-side only, and breaks nothing.
--
-- Affected (VehicleId -> creatures): 7410 Dancing Fools/Waltzing Venthyr (57
-- spawns), 5050 Lady Inerva Darkvein + her 5 anima containers, 7253 General
-- Draven x2, 7335 Hungering Destroyer, 7336 Nathrian Heavy Enforcer, 7385 Stone
-- Legion Goliath, 7387 General Kaal, 7189/7190 March of the Penitent vehicles.
-- Restoring is one UPDATE away if the SL vehicle mechanics are ever ported.
--
-- ###########################################################################
-- 2. 64 lootids pointing at loot tables that exist in NO source
-- ###########################################################################
-- 64 map-2296 creatures (51 trash / 314 spawns, 10 elite / 20 spawns, 3 boss /
-- 3 spawns) have `lootid` set but no matching creature_loot_template, producing
-- 64 "Entry N does not exist but it is used by Creature N" errors every boot.
--
-- These are NOT lost loot. Searched the real Shadowlands source the earlier
-- passes used -- SLDB_902_world_2021_03_12.sql, creature_loot_template block
-- isolated to its exact line range 841677-2744705 and all 1,902,968 loot rows
-- scanned -- and **0 of the 64 have a single row there**. That matches what
-- 19_trash_loot.sql already recorded: 32 of its 89 targets had real source loot
-- and "the other 57 have NO" (a genuine source-data gap, not a search miss).
-- So the loot never existed; only the dangling pointer does.
--
-- Clearing `lootid` makes the data self-consistent with the decision 19_ already
-- took (no invented loot) and silences all 64. FULLY REVERSIBLE: every one of the
-- 64 has lootid = entry (verified 64/64), so if a future source turns up:
--     UPDATE creature_template SET lootid = entry WHERE entry IN (...);
-- Deliberately NOT done: inventing drops for the 3 lootless bosses (165759
-- Kael'thas Sunstrider, 166970 Lord Stavros, 168113 General Grashaal) out of the
-- existing downported ilvl-200 gear pool. That is a content decision, not an
-- error fix -- say the word and it is a small follow-up.
--
-- ###########################################################################
-- 3. Invalid creature type 15  (6 creatures)
-- ###########################################################################
-- Shadowlands type 15 (Aberration) has no equivalent on 3.3.5, whose CreatureType
-- enum ends well below it, so the core logs "has invalid creature type (15)".
-- Remapped to 10 = "Not specified", the neutral choice: unlike guessing Undead or
-- Demon it cannot wrongly expose them to Shackle/Banish/tracking behaviour.
-- Affects 164261 Hungering Destroyer, 171577 Ripped Soul, 173142 Dread Feaster,
-- 173145, 173146 and 175527 Winged Ravager.
--
-- ###########################################################################
-- 4. creature_template_addon.auras holding the literal string "0"  (25 rows)
-- ###########################################################################
-- "has wrong spell '0' defined in `auras`". The transcode wrote "0" where it meant
-- "no auras"; the core parses it as spell id 0. Emptying the field is exactly
-- equivalent and silences 25 warnings.
--
-- Every statement re-derives its own condition at apply time, so none of them can
-- act on a row that has meanwhile gained real data. Idempotent; needs a
-- worldserver restart.
-- ===========================================================================

-- ---- 1. clear the vestigial Shadowlands VehicleIds (client-freeze fix) ------
UPDATE `creature_template` ct
SET ct.`VehicleId` = 0
WHERE ct.`VehicleId` > 0
  AND NOT EXISTS (SELECT 1 FROM `vehicle_dbc` v WHERE v.`ID` = ct.`VehicleId`)
  AND ct.`VehicleId` IN (5050,7189,7190,7253,7335,7336,7385,7387,7410)
  AND ct.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 2296);

-- ---- 2. clear lootids whose table exists in no source -----------------------
UPDATE `creature_template` ct
SET ct.`lootid` = 0
WHERE ct.`lootid` > 0
  AND ct.`lootid` = ct.`entry`
  AND NOT EXISTS (SELECT 1 FROM `creature_loot_template` lt WHERE lt.`Entry` = ct.`lootid`)
  AND ct.`entry` IN (SELECT DISTINCT `id` FROM `creature` WHERE `map` = 2296);

-- ---- 3. remap the invalid Shadowlands creature type -------------------------
UPDATE `creature_template` SET `type` = 10 WHERE `type` = 15;

-- ---- 4. "0" means no auras ---------------------------------------------------
UPDATE `creature_template_addon` SET `auras` = '' WHERE `auras` = '0';

-- ---------------------------------------------------------------------------
-- NOT touched in this round, on purpose:
--
-- * 11,580 creature_loot_template rows reference items that do not exist in
--   item_template (the boot log only samples a handful, e.g. items 179311 /
--   176871 / 58264). That is a GLOBAL class, not a Nathria one, and the core
--   simply skips those rows at load. Mass-deleting 11.5k rows is a destructive
--   change that deserves its own audit -- e.g. how many are Shadowlands
--   borrowed-power items that were deliberately never downported (see the
--   castle-nathria-item-loot-coverage memory: 226 such) versus real gaps.
--
-- * Several Nathria loot/reference groups exceed 100% total chance
--   (creature_loot_template entry 164407 group 1 = 114%, reference_loot_template
--   24161 group 1 = 110%). Harmless (the roll just saturates) but worth a tidy
--   pass alongside the item audit above.
-- ---------------------------------------------------------------------------
