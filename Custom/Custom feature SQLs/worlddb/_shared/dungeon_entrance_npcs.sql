-- =====================================================================================
-- Entrance AND exit NPCs for the new instances reached from map 750
--   Blackfathom Deeps (Ashenvale)  map 820
--   Timbermaw Hold                 map 819
--   Crescent Grove   (Ashenvale)   map 823
--   Emerald Sanctum  (Hyjal)       map 824
--
-- Two gossip NPCs each: one outside the instance to get in, one just inside to get out.
-- Each opens a real menu -- read what the place is first, then travel if you want to.
-- No DBC change, no client restart.
--
-- WHY NOT JUST AREATRIGGERS
--
--   1. An AreaTrigger has no model, no name and no tooltip, so it cannot be found. That is
--      literally why Timbermaw's "portal" was reported missing -- there was nothing to see.
--   2. It fires on APPROACH. The Timbermaw gatekeeper was first placed 7.6 yards from
--      trigger 607002's box (half-extents 4), so walking up to talk teleported the player
--      before they could click. The outside NPCs now stand 25-27 yards clear.
--   3. **Both exit triggers were centred exactly on their own arrival point** -- 607005 sat
--      at (-151.89, 106.96, -39.87) on map 820, which is precisely where 607004 drops you.
--      Arriving would have landed you inside the exit box and bounced you straight back
--      out, forever. Timbermaw had the identical bug at (-8165.96, -3459.75, 221.0); it
--      only came apart because the arrival Z was corrected to 222.4 afterwards.
--      Section 6 below removes the teleport action from both, killing the loop.
--
-- CORRECTION (2026-08-08): an earlier revision claimed custom AreaTriggers never fire on
-- this server and blamed the ID range (stock tops out at 5872, these are 607002+). WRONG --
-- in-game testing showed 607002 firing normally. High AreaTrigger IDs are fine. The
-- Blackfathom ENTRANCE trigger 607004 is still silent, which is a separate open question:
-- its coordinates come from map 1's VANILLA terrain, while map 750's Zoram Strand is CATA
-- terrain, so the cave mouth may simply not be in the same place there. The outside NPC
-- makes that moot.
--
-- THE SINGLE-OPTION AUTO-SELECT TRAP (found 2026-08-08)
--
-- A gossip menu with exactly ONE option, no quests, and an OptionIcon other than 0 is
-- SELECTED BY THE CLIENT AUTOMATICALLY -- the window never renders. From the stock 3.3.5
-- FrameXML, GossipFrame.lua:10-18:
--
--     if ( event == "GOSSIP_SHOW" ) then
--         -- if there is only a non-gossip option, then go to it directly
--         if ( GetNumGossipAvailableQuests() == 0 and GetNumGossipActiveQuests() == 0
--              and GetNumGossipOptions() == 1 ) then
--             local text, gossipType = GetGossipOptions();
--             if ( gossipType ~= "gossip" ) then SelectGossipOption(1); return; end
--
-- `gossipType` comes from the OPTION ICON, not OptionType -- icon 0 is "gossip", icon 2 is
-- "taxi". The first version used icon 2 with a single option, so clicking the Timbermaw
-- gatekeeper teleported instantly with no menu. Blackfathom looked fine only because it has
-- quests, which skips the branch entirely.
--
-- Two defences, both applied below: every menu carries at least TWO options, and any
-- lone-option menu would use icon 0. Menus also now lead with an informational option, so a
-- player can read what the place is before committing to go in.
--
-- Mechanism (verified against SmartScript.cpp:1707 before writing):
--   SMART_EVENT_GOSSIP_SELECT = 62   event_param1 = menu id, event_param2 = option index
--   SMART_ACTION_TELEPORT     = 62   action_param1 = MAP id; the destination comes from the
--                                    target_x/y/z/o COLUMNS, not from the action params
--   SMART_TARGET_ACTION_INVOKER = 7  so the teleported unit is the player who clicked
--   SMART_ACTION_CLOSE_GOSSIP = 72   closes the window first
--
-- Re-runnable.
-- =====================================================================================

-- =====================================================================================
-- 1. The eight NPCs, as data.
--
-- POSITION CONFIDENCE -- these are not all equally trustworthy:
--   * Timbermaw arrival (-8153.15, -3456.87, 222.4) is MEASURED: in-game `.gps` gave
--     FloorZ 222.36, GroundZ 42.40. The old Z of 221.0, derived from the WMO group bbox,
--     was below the floor. GroundZ and FloorZ are ~180 yards apart there because the raid
--     is WMO interior suspended above the terrain, so terrain-derived Z is worthless.
--   * Blackfathom arrival (-151.89, 106.96, -39.87) is stock AreaTrigger 257's own target
--     for map 48 -- proven vanilla data, and map 820 shares that terrain.
--   * The two map-750 gatekeeper spots are anchored on nearby real spawns.
--   * The FIRST FOUR NPC standing spots below are the positions they were placed at IN GAME
--     and read back out of the live `creature` table, so re-running this file keeps them
--     where they were put rather than snapping them back to my estimates. The four added
--     for Crescent Grove and Emerald Sanctum have not been in game yet -- their Z is
--     computed from the deployed terrain with the core's own height maths (see the note on
--     those rows), which is a much better starting point than the estimates the first four
--     began with, but `.gps` them once and paste the read-back values here.
--     Note the asymmetry that made those estimates acceptable in the first place: a creature
--     spawned a yard off the floor is cosmetic, whereas a teleport DESTINATION a yard low
--     drops the player through it -- which is why only the destinations were ever measured.
--   * Every DESTINATION below is now either measured in game or taken from Blizzard's own
--     data. None is an estimate of mine any more. The three that were cost real debugging:
--     Timbermaw's arrival (Z was under the floor), and Blackfathom's way OUT, which I had
--     guessed from map 1's VANILLA Zoram Strand -- but map 750's Zoram Strand is CATA
--     terrain, so the ground is not where the old continent says it is. If you ever need to
--     add another, `.gps` it; do not interpolate from a neighbouring map.
-- =====================================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_gate;
CREATE TEMPORARY TABLE tmp_gate (
    entry      INT UNSIGNED PRIMARY KEY,
    guid       INT UNSIGNED,
    name       VARCHAR(100),
    subname    VARCHAR(100),
    display    INT UNSIGNED,
    menu       INT UNSIGNED,
    text_id    INT UNSIGNED,
    npcflag    INT UNSIGNED,
    option_txt VARCHAR(120),
    greeting   TEXT,
    home_map   INT UNSIGNED, home_x FLOAT, home_y FLOAT, home_z FLOAT, home_o FLOAT,
    dest_map   INT UNSIGNED, dest_x FLOAT, dest_y FLOAT, dest_z FLOAT, dest_o FLOAT
);

INSERT INTO tmp_gate VALUES
    -- outside Blackfathom, on map 750 (Zoram Strand). npcflag 3 = GOSSIP | QUESTGIVER,
    -- because this one also hands out the 11 cloned quests from 08_quests.sql.
    (3999001, 16622000, 'Blackfathom Gatekeeper', 'Blackfathom Deeps', 4841, 62010, 62010, 3,
     'Take me into Blackfathom Deeps.',
     'The tide runs black below us. The Twilight''s Hammer has taken the Deeps, and Aku''mai stirs in the dark. Say the word and I will see you inside.',
     750, 4249.43, 730.525, -26.4006, 1.95034,
     -- Blizzard's own BFD entrance arrival, lifted from areatrigger_teleport 257 (target
     -- map 48). Map 820 is a byte-clone of 48, so this point is guaranteed to be on the
     -- floor -- it is not an estimate of mine, and it needs no re-measuring.
     820, -151.89, 106.96, -39.87, 4.53),

    -- outside Timbermaw, on map 750 (furbolg camp), ~27 yd clear of trigger 607002
    (3999002, 16622001, 'Timbermaw Gatekeeper', 'Timbermaw Hold', 2003, 62011, 62011, 1,
     'Take me into Timbermaw Hold.',
     'The Hold is not what it was. Something beneath the roots has turned our kin against us. If you mean to face it, I can open the way.',
     750, 6996.93, -2103.84, 587.22, 4.76962,
     819, -8153.15, -3456.87, 222.4, 0.306),

    -- inside Blackfathom, ~7 yd from where players land
    (3999003, 16622002, 'Blackfathom Warden', 'Passage Out', 4842, 62012, 62012, 1,
     'Take me back to Zoram Strand.',
     'Leaving already? The way out is dark and the tide is against you. Hold still and I will send you back to the shore.',
     820, -161.292, 99.621, -42.4134, 0.0449585,
     -- MEASURED IN GAME (game_tele 10644 `dcbfd`). My previous value here, 4254.0/749.0/-25.0,
     -- was a round-number estimate carried over from map 1's VANILLA Zoram Strand terrain --
     -- but map 750's Zoram Strand is CATA terrain, so the ground sits elsewhere and players
     -- fell through on the way out. Lands ~8 yd from the Blackfathom Gatekeeper.
     750, 4246.28, 738.322, -25.9246, 1.86366),

    -- inside Timbermaw, ~7 yd from where players land
    (3999004, 16622003, 'Timbermaw Warden', 'Passage Out', 2003, 62013, 62013, 1,
     'Take me back to the surface.',
     'The roots run deep and the paths twist. Stand close and I will walk you back to the open air.',
     819, -8123.93, -3453.69, 223.996, 2.81771,
     750, 7008.0, -2124.0, 588.3, 4.75),

    -- ---------------------------------------------------------------------------------
    -- Crescent Grove (map 823) and Emerald Sanctum (map 824), added 2026-08-09.
    --
    -- Every Z below is COMPUTED, not estimated: the MCVT -> V9/V8 -> getHeightFromFloat
    -- maths the worldserver itself uses, run against the deployed ADTs (sampler in
    -- Custom/TurtleDungeons/, calibrated to a median 0.00 error against live map-750
    -- spawn Z). The Emerald Sanctum arrival computes to 30.099 where the source pack's own
    -- AreaTrigger sits at 30.1 -- an independent check on both numbers.
    --
    -- Do NOT substitute Turtle's own map-750-side coordinates: theirs come from map 1's
    -- VANILLA Ashenvale and Hyjal, and map 750 is CATA terrain. The Grove entrance ground
    -- is 14 yd and the Sanctum entrance 32 yd above where the old continent puts it -- the
    -- same class of mistake that dropped players through the floor leaving Blackfathom.
    -- Both gatekeepers stand 25 yd clear of their AreaTrigger box (half-extents 4) so
    -- walking up to talk cannot teleport you before you can click, which is what made the
    -- Timbermaw gatekeeper unusable at 7.6 yd.
    -- ---------------------------------------------------------------------------------

    -- outside Crescent Grove, on map 750 (Ashenvale, the Mystral Lake hillside)
    (3999005, 16622004, 'Crescent Grove Gatekeeper', 'Crescent Grove', 11767, 62014, 62014, 1,
     'Take me into Crescent Grove.',
     'The grove was ours once. Now the vilethorn creeps through it, and what feeds on it no longer answers to Elune. Step close and I will take you in.',
     750, 1707.48, -1289.88, 173.694, 2.356,
     823, 585.6, 96.7, 276.92, 5.498),

    -- outside Emerald Sanctum, on map 750 (Hyjal, ~170 yd from Nordrassil)
    (3999007, 16622006, 'Emerald Sanctum Gatekeeper', 'Emerald Sanctum', 11769, 62016, 62016, 1,
     'Take me into the Emerald Sanctum.',
     'Behind this slope the Dream presses against the waking world, and something inside the Sanctum has stopped holding the two apart. Twenty of you, no fewer, if you mean to walk it.',
     750, 4833.10, -1731.70, 1196.215, 4.712,
     824, 2767.4, 2959.0, 30.10, 0.785),

    -- inside Crescent Grove, ~8 yd from where players land (dz -0.5, flat ground)
    (3999006, 16622005, 'Crescent Grove Warden', 'Passage Out', 1982, 62015, 62015, 1,
     'Take me back to Ashenvale.',
     'You have seen enough of the rot, then. Hold still and I will set you back on the ridge.',
     823, 579.94, 102.36, 276.414, 5.498,
     750, 1707.48, -1289.88, 173.694, 2.356),

    -- inside Emerald Sanctum, ~8 yd from where players land (dz -0.08, flat ground)
    (3999008, 16622007, 'Emerald Sanctum Warden', 'Passage Out', 17340, 62017, 62017, 1,
     'Take me back to Hyjal.',
     'The Dream does not let go gladly. Stand with me and I will draw you back to the mountain.',
     824, 2761.74, 2953.34, 30.019, 0.785,
     750, 4833.10, -1731.70, 1196.215, 4.712);

-- =====================================================================================
-- 2. Templates. Cloned from 3694 (Sentinel Selarin) so every stat column gets a sane 3.3.5
-- value, then the identity fields are overridden -- the same schema-agnostic trick used by
-- 05_cata_npc_layer.sql, so no 55-column INSERT list can drift out of sync.
-- faction 35 = friendly to everyone; unit_flags 0x2|0x100|0x200 = not attackable and immune
-- to PC and NPC, so a gatekeeper standing in open world content cannot be killed.
-- =====================================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_gate_ct;
CREATE TEMPORARY TABLE tmp_gate_ct LIKE `creature_template`;
ALTER TABLE tmp_gate_ct DROP PRIMARY KEY, ADD COLUMN `new_entry` INT UNSIGNED;
INSERT INTO tmp_gate_ct
    SELECT ct.*, g.entry FROM tmp_gate g JOIN `creature_template` ct ON ct.`entry` = 3694;
UPDATE tmp_gate_ct SET `entry` = `new_entry`;
ALTER TABLE tmp_gate_ct DROP COLUMN `new_entry`;

DELETE FROM `creature_template` WHERE `entry` IN (SELECT entry FROM tmp_gate);
INSERT INTO `creature_template` SELECT * FROM tmp_gate_ct;

UPDATE `creature_template` ct JOIN tmp_gate g ON g.entry = ct.`entry` SET
    ct.`name` = g.name, ct.`subname` = g.subname,
    ct.`minlevel` = 96, ct.`maxlevel` = 96,
    ct.`faction` = 35, ct.`rank` = 0, ct.`type` = 7, ct.`unit_class` = 1,
    ct.`npcflag` = g.npcflag,
    ct.`unit_flags` = 770,
    ct.`gossip_menu_id` = g.menu,
    ct.`lootid` = 0, ct.`pickpocketloot` = 0, ct.`skinloot` = 0,
    ct.`difficulty_entry_1` = 0, ct.`difficulty_entry_2` = 0, ct.`difficulty_entry_3` = 0,
    ct.`KillCredit1` = 0, ct.`KillCredit2` = 0,
    ct.`AIName` = 'SmartAI', ct.`ScriptName` = '', ct.`VerifiedBuild` = 0;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (SELECT entry FROM tmp_gate);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT entry, 0, display, 1, 1, 0 FROM tmp_gate;

-- =====================================================================================
-- 3. Gossip
--
-- Each NPC gets a two-level menu:
--   main menu   option 0 (icon 0) -> opens the info menu   option 1 (icon 2) -> travel
--   info menu   option 0 (icon 2) -> travel                option 1 (icon 0) -> close
-- Never fewer than two options anywhere -- see the auto-select note in the header.
-- =====================================================================================
DROP TEMPORARY TABLE IF EXISTS tmp_gate_menu;
CREATE TEMPORARY TABLE tmp_gate_menu (
    entry     INT UNSIGNED,
    menu      INT UNSIGNED,
    text_id   INT UNSIGNED,
    body      TEXT,
    PRIMARY KEY (menu)
);
INSERT INTO tmp_gate_menu VALUES
    (3999001, 62020, 62020,
     'Blackfathom Deeps lies beneath the Zoram Strand -- a drowned temple of Elune the naga took, and the Twilight''s Hammer took from them. Aku''mai, the beast the cult feeds, sleeps in the deepest chamber.

A five-person dungeon for the ninety-second to ninety-sixth season of a champion. Heroic and Mythic trials await those who have reached the cap.'),
    (3999002, 62021, 62021,
     'Timbermaw Hold runs beneath the mountains between Felwood and Winterspring. Something in the roots has turned the furbolg against their own, and the deep halls are no longer ours.

A raid for twenty. Come prepared, and come with friends -- what waits in Ursoc''s chamber does not fall to a handful.'),
    (3999003, 62022, 62022,
     'The passage back to the Zoram Strand is short but the tide is against you. Say the word and I will carry you up.'),
    (3999004, 62023, 62023,
     'The way to the surface twists through the roots. Say the word and I will walk you out.'),
    (3999005, 62024, 62024,
     'Crescent Grove sits above Mystral Lake in Ashenvale -- a moonwell grove the Shadowleaf satyr broke open, and the vilethorn has been spreading out of the wound ever since.

A five-person dungeon. Bring someone who can cleanse.'),
    (3999006, 62025, 62025,
     'The ridge above the grove is a short walk from here, if you would rather not take the long way through the thorns. Say the word.'),
    (3999007, 62026, 62026,
     'The Emerald Sanctum is a waystation of the green flight, grown where the Dream lies thinnest against Hyjal. Its keepers stopped answering, and what comes through now is not dreaming.

A raid for twenty. Do not bring fewer and expect to leave.'),
    (3999008, 62027, 62027,
     'The way back to the mountainside is open whenever you want it. Say the word and I will draw you through.');

-- npc_text: the greeting on the main menu, plus the body on each info menu
DELETE FROM `npc_text` WHERE `ID` IN (SELECT text_id FROM tmp_gate)
   OR `ID` IN (SELECT text_id FROM tmp_gate_menu);
INSERT INTO `npc_text` (`ID`, `text0_0`, `BroadcastTextID0`, `Probability0`)
SELECT text_id, greeting, 0, 1 FROM tmp_gate;
INSERT INTO `npc_text` (`ID`, `text0_0`, `BroadcastTextID0`, `Probability0`)
SELECT text_id, body, 0, 1 FROM tmp_gate_menu;

DELETE FROM `gossip_menu` WHERE `MenuID` IN (SELECT menu FROM tmp_gate)
   OR `MenuID` IN (SELECT menu FROM tmp_gate_menu);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) SELECT menu, text_id FROM tmp_gate;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) SELECT menu, text_id FROM tmp_gate_menu;

DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (SELECT menu FROM tmp_gate)
   OR `MenuID` IN (SELECT menu FROM tmp_gate_menu);

-- main menu, option 0: open the info menu (ActionMenuID does this in the core, no script)
INSERT INTO `gossip_menu_option`
    (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`)
SELECT g.menu, 0, 0,
       IF(g.dest_map = 750, 'Where does this passage lead?', 'Tell me about this place.'),
       0, 1, 1, m.menu
FROM tmp_gate g JOIN tmp_gate_menu m ON m.entry = g.entry;

-- main menu, option 1: travel
INSERT INTO `gossip_menu_option`
    (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`)
SELECT menu, 1, 2, option_txt, 0, 1, 1, 0 FROM tmp_gate;

-- info menu, option 0: travel  /  option 1: close
INSERT INTO `gossip_menu_option`
    (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`)
SELECT m.menu, 0, 2, g.option_txt, 0, 1, 1, 0
FROM tmp_gate_menu m JOIN tmp_gate g ON g.entry = m.entry;
INSERT INTO `gossip_menu_option`
    (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`)
SELECT menu, 1, 0, 'Not just now.', 0, 1, 1, 0 FROM tmp_gate_menu;

-- =====================================================================================
-- 4. SmartAI
--
-- Three gossip selections per NPC now that each has a two-level menu:
--   main menu option 1  -> travel
--   info menu option 0  -> travel
--   info menu option 1  -> just close
-- Main-menu option 0 needs no script: `ActionMenuID` makes the core open the info menu.
--
-- event_param1 = menu id, event_param2 = the option's index in the SENT list. Both come
-- straight from MiscHandler.cpp:199 `sGossipSelect(_player, menuId, gossipListId)`, and the
-- pairing matches how stock content does it (e.g. Barnil Stonepot 716 uses sender = his menu
-- id 5483 with action 0..3, one row per option).
-- Each travel row links to a second row that performs the teleport.
-- =====================================================================================
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (SELECT entry FROM tmp_gate);

DROP TEMPORARY TABLE IF EXISTS tmp_gate_sel;
CREATE TEMPORARY TABLE tmp_gate_sel (
    entry INT UNSIGNED, idx INT UNSIGNED, menu INT UNSIGNED, opt INT UNSIGNED,
    travels TINYINT, label VARCHAR(60)
);
-- Three separate INSERTs, not one UNION: MySQL cannot reference a TEMPORARY table twice in
-- the same statement (error 1137 "Can't reopen table"), and tmp_gate_menu is needed by two
-- of the three branches.
INSERT INTO tmp_gate_sel
SELECT g.entry, 0, g.menu, 1, 1, 'main menu - travel' FROM tmp_gate g;
INSERT INTO tmp_gate_sel
SELECT m.entry, 2, m.menu, 0, 1, 'info menu - travel' FROM tmp_gate_menu m;
INSERT INTO tmp_gate_sel
SELECT m.entry, 4, m.menu, 1, 0, 'info menu - decline' FROM tmp_gate_menu m;

-- the selection row: close the window, and link on to the teleport when it travels
INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
     `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT s.entry, 0, s.idx, IF(s.travels = 1, s.idx + 1, 0), 62, 0, 100, 0, s.menu, s.opt, 0, 0, 0, 0,
       72, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
       CONCAT(g.name, ' - ', s.label, ' - Close Gossip')
FROM tmp_gate_sel s JOIN tmp_gate g ON g.entry = s.entry;

-- the linked teleport row, only for the selections that travel
INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
     `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`)
SELECT s.entry, 0, s.idx + 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0,
       62, g.dest_map, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0,
       g.dest_x, g.dest_y, g.dest_z, g.dest_o,
       CONCAT(g.name, ' - ', s.label, ' - Teleport to map ', g.dest_map)
FROM tmp_gate_sel s JOIN tmp_gate g ON g.entry = s.entry
WHERE s.travels = 1;

-- =====================================================================================
-- 5. Spawns.
-- spawnMask: map 750 has one difficulty (1); the instance maps carry 7, which covers every
-- difficulty row they have now (819/823/824 have one each, 820 has three) and any added later.
-- =====================================================================================
DELETE FROM `creature` WHERE `guid` IN (SELECT guid FROM tmp_gate);
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`)
SELECT guid, entry, home_map, 0, 0, IF(home_map = 750, 1, 7), 1, 0,
       home_x, home_y, home_z, home_o, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0,
       CONCAT(name, ' - ', subname)
FROM tmp_gate;

-- =====================================================================================
-- 6. Kill the exit-trigger teleport loop.
--
-- 607003 and 607005 are the two "exit" AreaTriggers, and each box was originally placed on
-- top of its own instance's ARRIVAL point -- so the first thing a player did on arriving was
-- stand in the trigger that sends them back.
--
-- **607005 (Blackfathom) IS FIXED and is no longer deleted here.** Its box was re-measured
-- in game to the real walk-out point inside the dungeon (-176.86 / 51.56 / -49.64), which is
-- 61.5 yd from the arrival point -- far outside the 8x8x10 box -- so the loop is gone and the
-- portal works as a real exit. `06_registration.sql` owns that row; see the geometry note
-- there. Deleting it here would just fight that file.
--
-- 607003 (Timbermaw) is still dropped: its box sits on my old, below-the-floor arrival
-- estimate, and Timbermaw already enters and exits correctly through the gatekeeper and
-- warden gossip. `.gps` the real walk-out spot inside the Hold if you want it re-enabled.
--
-- The two ENTRANCE triggers (607002 Timbermaw, 607004 Blackfathom) are left working.
--
-- Crescent Grove (823) and Emerald Sanctum (824) have NO exit trigger at all -- the loop is
-- avoided by construction rather than repaired afterwards. Their entrance boxes are 607006
-- and 607007; the way out is the warden, same as Timbermaw.
-- =====================================================================================
DELETE FROM `areatrigger_teleport` WHERE `ID` = 607003;

-- =====================================================================================
-- Report
-- =====================================================================================
SELECT 'templates (want 8)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` BETWEEN 3999001 AND 3999008
UNION ALL SELECT 'displays (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` BETWEEN 3999001 AND 3999008
UNION ALL SELECT 'gossip menus (want 16)', CAST(COUNT(*) AS CHAR)
    FROM `gossip_menu` WHERE `MenuID` BETWEEN 62010 AND 62027
UNION ALL SELECT 'gossip options (want 32)', CAST(COUNT(*) AS CHAR)
    FROM `gossip_menu_option` WHERE `MenuID` BETWEEN 62010 AND 62027
UNION ALL SELECT 'npc_text (want 16)', CAST(COUNT(*) AS CHAR)
    FROM `npc_text` WHERE `ID` BETWEEN 62010 AND 62027
UNION ALL SELECT 'menus with only 1 option (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT `MenuID` FROM `gossip_menu_option` WHERE `MenuID` BETWEEN 62010 AND 62027
          GROUP BY `MenuID` HAVING COUNT(*) < 2) x
UNION ALL SELECT 'smart rows (want 40)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` BETWEEN 3999001 AND 3999008
UNION ALL SELECT 'spawns (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` BETWEEN 16622000 AND 16622007
UNION ALL SELECT 'exit-trigger loops remaining (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` WHERE `ID` = 607003
UNION ALL SELECT 'target maps registered (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` IN (819, 820, 823, 824);

DROP TEMPORARY TABLE IF EXISTS tmp_gate_ct;
DROP TEMPORARY TABLE IF EXISTS tmp_gate_sel;
DROP TEMPORARY TABLE IF EXISTS tmp_gate_menu;
DROP TEMPORARY TABLE IF EXISTS tmp_gate;
