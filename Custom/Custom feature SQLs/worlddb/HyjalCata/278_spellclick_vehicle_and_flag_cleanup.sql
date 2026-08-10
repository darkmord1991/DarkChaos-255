-- ===========================================================================
-- 278_spellclick_vehicle_and_flag_cleanup.sql
-- Make 276_'s vehicle accessories actually load, and clear vestigial
-- UNIT_NPC_FLAG_SPELLCLICK the core strips at every boot.
--
-- Two different boot messages, two different severities. Only the first is a
-- functional defect.
--
-- SECTION 1 -- 276_ IS CURRENTLY A COMPLETE NO-OP
-- -----------------------------------------------
--   Table `vehicle_template_accessory`: creature template entry N has no data
--   in npc_spellclick_spells
--
-- `ObjectMgr::LoadVehicleTemplateAccessories` (ObjectMgr.cpp ~4103) does:
--     if (_spellClickInfoStore.find(uiEntry) == _spellClickInfoStore.end())
--     { LOG_ERROR(...); continue; }
-- -- `continue`, so the accessory row is DROPPED. All 5 vehicles 276_ added
-- are rejected, so not one of its riders spawns. The table looks correct in
-- the DB and does nothing in game: a riderless wind rider, a riderless
-- hippogryph, a kodo-less wagon.
--
-- The fix is NOT to set the SPELLCLICK npcflag. The core says so itself at
-- ObjectMgr.cpp ~8629:
--   "NOTE: It *CAN* be the other way around: no spellclick flag but with
--    spellclick data, in case of creature-only vehicle accessories"
-- These 5 are exactly that -- NPC-crewed ambient vehicles, no SPELLCLICK, no
-- PLAYER_VEHICLE, riders are minions. A player must never get a click cursor
-- on them; the row exists only to satisfy the loader so the crew spawns.
--
-- Spell 46598 "Ride Vehicle Hardcoded" is what nelt_world uses for 4 of the 5
-- and it is present in our spell_dbc. It is also the house convention here:
-- 45 vehicles in `vehicle_template_accessory` already carry a 46598 row while
-- having no SPELLCLICK flag. cast_flags/user_type are copied from nelt
-- verbatim (cast_flags bit 0x1 = NPC_CLICK_CAST_CASTER_CLICKER, i.e. the
-- clicker is the caster -- inert here, since nothing can click these).
-- Krom'gar Wagon is the exception: nelt uses 62309, which is not in our
-- spell_dbc, so it takes 46598 with the majority flags.
--
--   3634132 Astranaar Thrower          <- Astranaar Sentinel
--   3634160 Watch Wind Rider           <- Hellscream's Hellion
--   3636665 Warsong Assault Wind Rider <- Azshara Bombardier   (minion)
--   3636852 Skychaser Hippogryph       <- Talrendis Skychaser  (minion)
--   3641744 Krom'gar Wagon             <- War Kodo             (minion, seat 1)
--
-- SECTION 2 -- vestigial flags, cosmetic
-- --------------------------------------
--   npc_spellclick_spells: Creature template N has UNIT_NPC_FLAG_SPELLCLICK
--   but no data in spellclick table! Removing flag
--
-- `LoadNPCSpellClickSpells` (ObjectMgr.cpp ~8633) already clears the bit on the
-- in-memory template, so there is no dead cursor and nothing crashes -- the
-- core self-heals every boot. Clearing it in the DB only makes the stored data
-- honest and silences the log.
--
-- None of these can be fixed faithfully: every one wants a Cata-only spell
-- absent from our Spell.dbc -- 66778 (Runaway Shredder), 81432/56685 (Surface
-- Transport), 79936 (Smoot), 80017 (AWOL Grunt), 89908 (Goblin Cocktail),
-- 73991/56685 (Footbomb Uniform). Same wall as the Felwood lasher/squirrel
-- round; the resolution there was identical -- substitute a spell only where a
-- script makes the click mean something, otherwise clear the flag. Nothing
-- here qualifies: none is a quest starter or ender, and Runaway Shredder's
-- SmartAI has only aggro and death events, no spellclick event. So the flag is
-- pure leftover on all of them.
--
-- 173382 "Soul Pedestal" is deliberately NOT touched -- it is Castle Nathria
-- content (4 spawns on map 2296), not a Cata import, and neither source DB has
-- a row for it. That looks like unfinished work in another workstream rather
-- than import residue, so its owner should decide. Uncomment the last
-- statement to silence it too.
--
-- Re-runnable. Needs a worldserver restart, not just an apply.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Section 1 -- creature-only vehicle accessories: satisfy the loader.
-- Do NOT add UNIT_NPC_FLAG_SPELLCLICK to these templates.
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (3634132, 3634160, 3636665, 3636852, 3641744);

INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(3634132, 46598, 0, 0),
(3634160, 46598, 0, 0),
(3636665, 46598, 1, 0),
(3636852, 46598, 1, 0),
(3641744, 46598, 1, 0);

-- ---------------------------------------------------------------------------
-- Section 2 -- clear UNIT_NPC_FLAG_SPELLCLICK (16777216) where no row can
-- ever exist. The core already does this in memory; this makes the DB agree.
--
--   3635111 Runaway Shredder                    17 spawns, map 750
--   3636917 Surface to Other Surface Transport   1 spawn,  map 750
--   3642644 Smoot                                1 spawn,  map 750
--   3642646 AWOL Grunt                          15 spawns, map 750
--   3648341 Goblin Cocktail                      8 spawns, map 750
--   3648342 Goblin Cocktail                      4 spawns, map 750
--   3648343 Goblin Cocktail                      4 spawns, map 750
--     39592 Ultimate Footbomb Uniform            0 spawns (template-only)
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~16777216
 WHERE `entry` IN (39592, 3635111, 3636917, 3642644, 3642646, 3648341, 3648342, 3648343)
   AND (`npcflag` & 16777216) <> 0;

-- Castle Nathria "Soul Pedestal" -- see header. Uncomment if that workstream
-- confirms the click was never going to be wired.
-- UPDATE `creature_template` SET `npcflag` = `npcflag` & ~16777216
--  WHERE `entry` = 173382 AND (`npcflag` & 16777216) <> 0;

-- ---------------------------------------------------------------------------
-- Verification -- after applying, these boot lines must be gone:
--   "Table `vehicle_template_accessory`: creature template entry ... has no
--    data in npc_spellclick_spells"   (all 5)
--   "npc_spellclick_spells: Creature template ... Removing flag"
--    (all but 173382)
--
-- And "Loaded N Vehicle Template Accessories" must rise by 5.
--
--   -- must return 0 rows
--   SELECT v.entry FROM `vehicle_template_accessory` v
--    WHERE NOT EXISTS (SELECT 1 FROM `npc_spellclick_spells` s
--                       WHERE s.npc_entry = v.entry);
--
--   -- must return 0 rows (flag set, no row) apart from 173382
--   SELECT ct.entry, ct.name FROM `creature_template` ct
--    WHERE (ct.npcflag & 16777216) <> 0
--      AND NOT EXISTS (SELECT 1 FROM `npc_spellclick_spells` s
--                       WHERE s.npc_entry = ct.entry);
--
--   -- the 5 vehicles must NOT have gained a click cursor
--   SELECT entry, name, npcflag & 16777216 AS must_be_zero
--     FROM `creature_template`
--    WHERE entry IN (3634132, 3634160, 3636665, 3636852, 3641744);
-- ---------------------------------------------------------------------------
