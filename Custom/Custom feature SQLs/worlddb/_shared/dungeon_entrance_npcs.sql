-- =====================================================================================
-- Visible entrance NPCs for the two new instances on map 750
--   Blackfathom Deeps (Ashenvale)  map 820
--   Timbermaw Hold                 map 819
--
-- WHY THIS EXISTS
--
-- Both dungeons were originally reachable only through an AreaTrigger -- an invisible
-- walk-in box defined in AreaTrigger.dbc. Two problems showed up in testing:
--
--   1. Timbermaw's "portal" could not be found, because there was nothing to find. An
--      AreaTrigger has no model, no name and no tooltip; the player is expected to already
--      know where to stand.
--   2. Blackfathom's trigger never fired. The server logs contain NO areatrigger entries at
--      all, which means the CLIENT never sent CMSG_AREATRIGGER -- the server never got the
--      chance to reject it. Everything the server needs was verified present:
--        * areatrigger_teleport rows 607002-607005          (checked in the live DB)
--        * AreaTrigger.dbc rows 607002-607005 on the SERVER (checked via its data/dbc)
--        * the same rows in the CLIENT's patch-4.MPQ, which is the archive that wins for
--          DBFilesClient\AreaTrigger.dbc (checked -- no shadowing)
--        * trigger Z -23.06 matches the terrain: a Spirit Healer sits at z -27.0 and a
--          gameobject at z -22.4, both within 28 yards
--      The one thing that stands out is the ID range: stock AreaTrigger.dbc tops out at
--      **5872**, and these are 607002+. That convention came from the Karazhan Crypts work
--      (607000/607001), whose own README records that its triggers were never verified
--      in game either -- so it is likely no custom AreaTrigger on this server has ever
--      fired, and the high IDs are the prime suspect.
--
-- A gossip NPC sidesteps the whole question: it is visible, named, clickable, needs no DBC
-- change and no client restart, and it teleports through SmartAI. The AreaTriggers are left
-- in place -- they cost nothing and will start working if the ID theory is ever fixed.
--
-- Mechanism (verified against SmartScript.cpp before writing):
--   SMART_EVENT_GOSSIP_SELECT = 62   event_param1 = menu id, event_param2 = option id
--   SMART_ACTION_TELEPORT     = 62   action_param1 = MAP id; the destination comes from the
--                                    target_x/y/z/o COLUMNS, not from the action params
--   SMART_TARGET_ACTION_INVOKER = 7  so the teleported unit is the player who clicked
--   SMART_ACTION_CLOSE_GOSSIP = 72   closes the window first
--
-- Re-runnable.
-- =====================================================================================

SET @NPC_BFD  := 3999001;
SET @NPC_TIMB := 3999002;
SET @MENU_BFD  := 62010;
SET @MENU_TIMB := 62011;
SET @TEXT_BFD  := 62010;
SET @TEXT_TIMB := 62011;
SET @GUID_BFD  := 16622000;
SET @GUID_TIMB := 16622001;

-- -------------------------------------------------------------------------------------
-- Templates. Cloned from 3694 (Sentinel Selarin) so every stat column gets a sane value,
-- then the identity fields are overridden -- same schema-agnostic trick as 05_cata_npc_layer.
-- faction 35 = friendly to everyone; unit_flags 0x2|0x100|0x200 = not attackable and immune
-- to both PC and NPC, so a gatekeeper standing in open world content cannot be killed.
-- -------------------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_gate_new;
CREATE TEMPORARY TABLE tmp_gate_new (
    new_entry INT UNSIGNED PRIMARY KEY,
    base_entry INT UNSIGNED,
    name VARCHAR(100),
    subname VARCHAR(100),
    lvl SMALLINT,
    display INT UNSIGNED,
    menu INT UNSIGNED,
    npcflag INT UNSIGNED
);
-- npcflag 1 = GOSSIP, 3 = GOSSIP | QUESTGIVER.
-- The Blackfathom gatekeeper also hands out the 11 cloned Blackfathom quests (08_quests.sql),
-- so it needs the questgiver bit or the client shows no quest marker and no quest list.
-- Timbermaw has no quest layer yet, so it stays gossip-only.
INSERT INTO tmp_gate_new VALUES
    (@NPC_BFD,  3694, 'Blackfathom Gatekeeper', 'Blackfathom Deeps', 96, 4841, @MENU_BFD,  3),
    (@NPC_TIMB, 3694, 'Timbermaw Gatekeeper',   'Timbermaw Hold',   96, 2003, @MENU_TIMB, 1);

DROP TEMPORARY TABLE IF EXISTS tmp_gate_ct;
CREATE TEMPORARY TABLE tmp_gate_ct LIKE `creature_template`;
ALTER TABLE tmp_gate_ct DROP PRIMARY KEY, ADD COLUMN `new_entry` INT UNSIGNED;
INSERT INTO tmp_gate_ct
    SELECT ct.*, n.new_entry FROM tmp_gate_new n
    JOIN `creature_template` ct ON ct.`entry` = n.base_entry;
UPDATE tmp_gate_ct SET `entry` = `new_entry`;
ALTER TABLE tmp_gate_ct DROP COLUMN `new_entry`;

DELETE FROM `creature_template` WHERE `entry` IN (SELECT new_entry FROM tmp_gate_new);
INSERT INTO `creature_template` SELECT * FROM tmp_gate_ct;

UPDATE `creature_template` ct JOIN tmp_gate_new n ON n.new_entry = ct.`entry` SET
    ct.`name` = n.name, ct.`subname` = n.subname,
    ct.`minlevel` = n.lvl, ct.`maxlevel` = n.lvl,
    ct.`faction` = 35, ct.`rank` = 0, ct.`type` = 7, ct.`unit_class` = 1,
    ct.`npcflag` = n.npcflag,
    ct.`unit_flags` = 770,            -- NOT_ATTACKABLE | IMMUNE_TO_PC | IMMUNE_TO_NPC
    ct.`gossip_menu_id` = n.menu,
    ct.`lootid` = 0, ct.`pickpocketloot` = 0, ct.`skinloot` = 0,
    ct.`difficulty_entry_1` = 0, ct.`difficulty_entry_2` = 0, ct.`difficulty_entry_3` = 0,
    ct.`KillCredit1` = 0, ct.`KillCredit2` = 0,
    ct.`AIName` = 'SmartAI', ct.`ScriptName` = '', ct.`VerifiedBuild` = 0;

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (SELECT new_entry FROM tmp_gate_new);
INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT new_entry, 0, display, 1, 1, 0 FROM tmp_gate_new;

-- -------------------------------------------------------------------------------------
-- Gossip
-- -------------------------------------------------------------------------------------
DELETE FROM `npc_text` WHERE `ID` IN (@TEXT_BFD, @TEXT_TIMB);
INSERT INTO `npc_text` (`ID`, `text0_0`, `BroadcastTextID0`, `Probability0`) VALUES
    (@TEXT_BFD, 'The tide runs black below us. The Twilight''s Hammer has taken the Deeps, and Aku''mai stirs in the dark. Say the word and I will see you inside.', 0, 1),
    (@TEXT_TIMB, 'The Hold is not what it was. Something beneath the roots has turned our kin against us. If you mean to face it, I can open the way.', 0, 1);

DELETE FROM `gossip_menu` WHERE `MenuID` IN (@MENU_BFD, @MENU_TIMB);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
    (@MENU_BFD, @TEXT_BFD),
    (@MENU_TIMB, @TEXT_TIMB);

DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (@MENU_BFD, @MENU_TIMB);
INSERT INTO `gossip_menu_option`
    (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`) VALUES
    (@MENU_BFD,  0, 2, 'Take me into Blackfathom Deeps.', 0, 1, 1),
    (@MENU_TIMB, 0, 2, 'Take me into Timbermaw Hold.', 0, 1, 1);

-- -------------------------------------------------------------------------------------
-- SmartAI: on gossip option 0, close the window and teleport the clicker.
-- The destination lives in target_x/y/z/o -- action_param1 carries only the map id.
-- -------------------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (@NPC_BFD, @NPC_TIMB);
INSERT INTO `smart_scripts`
    (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
     `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`, `event_param5`, `event_param6`,
     `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`, `action_param5`, `action_param6`,
     `target_type`, `target_param1`, `target_param2`, `target_param3`, `target_param4`,
     `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
    (@NPC_BFD, 0, 0, 1, 62, 0, 100, 0, @MENU_BFD, 0, 0, 0, 0, 0,
     72, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
     'Blackfathom Gatekeeper - On Gossip Option 0 - Close Gossip'),
    (@NPC_BFD, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0,
     62, 820, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, -151.89, 106.96, -39.87, 1.15,
     'Blackfathom Gatekeeper - Linked - Teleport to map 820'),
    (@NPC_TIMB, 0, 0, 1, 62, 0, 100, 0, @MENU_TIMB, 0, 0, 0, 0, 0,
     72, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0,
     'Timbermaw Gatekeeper - On Gossip Option 0 - Close Gossip'),
    (@NPC_TIMB, 0, 1, 0, 61, 0, 100, 0, 0, 0, 0, 0, 0, 0,
     62, 819, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, -8165.96, -3459.75, 221.0, 0,
     'Timbermaw Gatekeeper - Linked - Teleport to map 819');

-- -------------------------------------------------------------------------------------
-- Spawns on map 750.
--
-- Positions are anchored to entities already standing on that ground, because terrain height
-- cannot be measured from outside the game:
--   Blackfathom  the cave mouth on Zoram Strand -- a Spirit Healer sits at (4265.0, 732.6,
--                -27.0) and a gameobject at (4234.4, 746.7, -22.4), so the shelf runs about
--                z -22..-27 across 90 yards. Placed between them.
--   Timbermaw    inside the furbolg camp, among Kernda (7000.2, -2123.9, 588.6) and
--                Meilosh (7025.6, -2135.7, 586.5).
-- STILL VERIFY WITH `.gps` -- adjust Z if GroundZ != FloorZ, then re-run this file.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` IN (@GUID_BFD, @GUID_TIMB);
INSERT INTO `creature`
    (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
     `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
     `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`,
     `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
    (@GUID_BFD,  @NPC_BFD,  750, 0, 0, 1, 1, 0, 4250.0, 745.0, -25.0, 2.30, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Blackfathom Deeps entrance - Zoram Strand'),
    (@GUID_TIMB, @NPC_TIMB, 750, 0, 0, 1, 1, 0, 7012.0, -2138.0, 587.0, 1.60, 300, 0, 0, 1, 0, 0, 0, 0, 0, '', 0, 0, 'Timbermaw Hold entrance - furbolg camp');

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'templates (want 2)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_template` WHERE `entry` IN (@NPC_BFD, @NPC_TIMB)
UNION ALL SELECT 'displays (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template_model` WHERE `CreatureID` IN (@NPC_BFD, @NPC_TIMB)
UNION ALL SELECT 'gossip menus (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gossip_menu` WHERE `MenuID` IN (@MENU_BFD, @MENU_TIMB)
UNION ALL SELECT 'gossip options (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `gossip_menu_option` WHERE `MenuID` IN (@MENU_BFD, @MENU_TIMB)
UNION ALL SELECT 'smart rows (want 4)', CAST(COUNT(*) AS CHAR)
    FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (@NPC_BFD, @NPC_TIMB)
UNION ALL SELECT 'spawns (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `creature` WHERE `guid` IN (@GUID_BFD, @GUID_TIMB)
UNION ALL SELECT 'target maps exist (want 2)', CAST(COUNT(*) AS CHAR)
    FROM `instance_template` WHERE `map` IN (819, 820);

DROP TEMPORARY TABLE IF EXISTS tmp_gate_ct;
DROP TEMPORARY TABLE IF EXISTS tmp_gate_new;
