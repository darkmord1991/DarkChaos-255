-- =====================================================================
-- Round 50 -- the four "Script named X is not assigned in the database"
--             lines left over from round 37  (boot log 2026-09-02)
-- ---------------------------------------------------------------------
--   Script named 'spell_gen_submerge_visual'             is not assigned...
--   Script named 'spell_challenge_iron_man_plus_800029'  is not assigned...
--   Script named 'npc_tesla_40'                          is not assigned...
--   Script named 'npc_omarion_gossip'                    is not assigned...
--
-- 296_ deferred all four with "each needs its intended target read out of the
-- C++ before a row can be written".  That has now been done; the four have
-- four different root causes and only two of them are pure data.
--
-- ---------------------------------------------------------------------
-- 1. spell_challenge_iron_man_plus_800029  -- a plain missing row
-- ---------------------------------------------------------------------
-- dc_challenge_modes.h:51 declares SPELL_AURA_IRON_MAN_PLUS = 800029 and
-- Spell.csv line 58037 carries the 800029 row, so the aura exists on both
-- sides.  spell_script_names holds 800020..800028 -- the whole challenge-mode
-- block -- and stops one short.  Nothing else is wrong with it.
--
-- ---------------------------------------------------------------------
-- 2. spell_gen_submerge_visual  -- a DC copy of an upstream script took its
--    rows
-- ---------------------------------------------------------------------
-- DC/Naxx40/custom_spells_40.cpp carried `spell_submerge_visual_aura`, which
-- is Scripts/Spells/spell_generic.cpp's `spell_gen_submerge_visual` with a
-- different class name (identical Register(), identical two SetStandState
-- handlers; upstream additionally guards on a creature owner in Load()).
-- 05_naxx40_spells.sql pointed BOTH 26234 and 28819 at the DC copy, which left
-- the upstream registration with no rows -- and upstream's own
-- 2026_07_03_03.sql row for 28819 was overwritten in the process.
--
-- The duplicate class has been DELETED from custom_spells_40.cpp and
-- 05_naxx40_spells.sql now writes the upstream name, so a fresh apply lands in
-- the right state.  This file only repairs the live DB.
--
-- ORDERING: apply this file together with the matching worldserver build.  On
-- the old binary the new name does not exist yet ("Table spell_script_names
-- references non-existing script"); on the new binary the old name does not.
--
-- ---------------------------------------------------------------------
-- 3. npc_tesla_40  -- needed its own creature entry, as 99_ predicted
-- ---------------------------------------------------------------------
-- 99_retarget_naxx40_to_map_2921.sql section 12 disabled
--   UPDATE creature_template SET ScriptName='npc_tesla_40' WHERE entry=16218;
-- because 16218 is STOCK and core's `npc_tesla` owns it, and closed with:
-- "Fix properly in the clone pass by giving the 40-man its own Tesla Coil
-- entry and repointing NPC_TESLA_COIL in boss_thaddius_40.cpp."  That is what
-- this section does -- 351098, a straight clone of 16218 in the naxx40 @CENTRY
-- band, and boss_thaddius_40.cpp's NPC_TESLA_COIL now names it.
--
-- Why it was not merely cosmetic: stock `npc_tesla` resolves its AI through
-- Northrend/Naxxramas/naxxramas.h's GetNaxxramasAI, which only accepts the
-- instance script "instance_naxxramas".  Map 2921 runs
-- "instance_naxxramas_40", so on the 40-man the factory returned nullptr and
-- the coils fell back to plain ScriptedAI.  16218 is IMMUNE_TO_PC |
-- NOT_SELECTABLE (unit_flags 33554688) so they were never killable, but the
-- default AI still evades, and an evading coil drops the Feugen/Stalagg
-- overload cast mid-fight.  DC/Naxx40/naxx40_instance.h's GetNaxxramasAI
-- accepts both instance names, so 351098 + npc_tesla_40 attaches on 2921.
--
-- No spawn rows are touched: 16218 has none anywhere in the DB, the coils are
-- summoned by boss_thaddius_40 itself.
--
-- ---------------------------------------------------------------------
-- 4. npc_omarion_gossip  -- its content file was disabled WHOLESALE by the
--    stock-533 guard
-- ---------------------------------------------------------------------
-- The gossip tree this script needs was written long ago, in
-- Naxx40/07_naxx40_omarion.sql.  The stock-533 guard pass commented out the
-- three lines in it that touch stock rows (16365's ScriptName/faction, and the
-- emote fields on npc_text 8507/8516 + broadcast_text 12247/12280) -- and then
-- ALSO renamed the whole file to `.SKIPPED-stock533`, which took the other
-- ~90% of it down with them.  So npc_text 24401-24403, gossip_menu
-- 24401-24403 and every gossip_menu_option row for menus 24400-24404 were
-- never applied, and the script had nothing to render.
--
-- Re-applied below, unchanged, minus the stock rows -- plus the naxx40-owned
-- Omarion clone (351099) the guard note asked for ("Re-add later as
-- naxx40-owned clones if needed"), and the map-2921 spawn repointed onto it.
-- Stock 16365 keeps its faction 794, its gossip_menu_id 7215 and its empty
-- ScriptName; the 40-man clone gets faction 1766 and gossip_menu_id 0, which
-- is what the original file asked for on 16365.
--
-- The two emote-only lines that were correctly guarded are NOT restored: they
-- would have added Omarion's laugh/talk emotes to the intro (npc_text 8507)
-- and handbook (8516) texts, which the 40-man shares with stock 533.  Cosmetic
-- and stock-touching -- left alone deliberately.
--
-- Checked before writing: broadcast_text 12251-12281 (all 22 ids the options
-- cite) exist; npc_text 8507 and 8516 exist and carry their Classic text in
-- text0_1; 16365 has no creature_queststarter/questender rows, so repointing
-- the spawn breaks no quest chain.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Iron Man+ challenge aura
-- ---------------------------------------------------------------------
DELETE FROM `spell_script_names` WHERE `spell_id` = 800029 AND `ScriptName` = 'spell_challenge_iron_man_plus_800029';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800029, 'spell_challenge_iron_man_plus_800029');

-- ---------------------------------------------------------------------
-- 2. Submerge Visual -> upstream script
-- ---------------------------------------------------------------------
DELETE FROM `spell_script_names` WHERE `spell_id` IN (26234, 28819) AND `ScriptName` IN ('spell_submerge_visual_aura', 'spell_gen_submerge_visual');
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(26234, 'spell_gen_submerge_visual'),
(28819, 'spell_gen_submerge_visual');

-- ---------------------------------------------------------------------
-- 3. Naxx40 Tesla Coil (351098) -- clone of stock 16218
-- ---------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 351098;
CREATE TEMPORARY TABLE `tmp_naxx40_tesla` AS SELECT * FROM `creature_template` WHERE `entry` = 16218;
UPDATE `tmp_naxx40_tesla` SET `entry` = 351098, `ScriptName` = 'npc_tesla_40', `difficulty_entry_1` = 0, `difficulty_entry_2` = 0, `difficulty_entry_3` = 0;
INSERT INTO `creature_template` SELECT * FROM `tmp_naxx40_tesla`;
DROP TEMPORARY TABLE `tmp_naxx40_tesla`;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 351098;
CREATE TEMPORARY TABLE `tmp_naxx40_tesla_model` AS SELECT * FROM `creature_template_model` WHERE `CreatureID` = 16218;
UPDATE `tmp_naxx40_tesla_model` SET `CreatureID` = 351098;
INSERT INTO `creature_template_model` SELECT * FROM `tmp_naxx40_tesla_model`;
DROP TEMPORARY TABLE `tmp_naxx40_tesla_model`;

DELETE FROM `creature_template_addon` WHERE `entry` = 351098;
CREATE TEMPORARY TABLE `tmp_naxx40_tesla_addon` AS SELECT * FROM `creature_template_addon` WHERE `entry` = 16218;
UPDATE `tmp_naxx40_tesla_addon` SET `entry` = 351098;
INSERT INTO `creature_template_addon` SELECT * FROM `tmp_naxx40_tesla_addon`;
DROP TEMPORARY TABLE `tmp_naxx40_tesla_addon`;

DELETE FROM `creature_template_movement` WHERE `CreatureId` = 351098;
CREATE TEMPORARY TABLE `tmp_naxx40_tesla_move` AS SELECT * FROM `creature_template_movement` WHERE `CreatureId` = 16218;
UPDATE `tmp_naxx40_tesla_move` SET `CreatureId` = 351098;
INSERT INTO `creature_template_movement` SELECT * FROM `tmp_naxx40_tesla_move`;
DROP TEMPORARY TABLE `tmp_naxx40_tesla_move`;

DELETE FROM `creature_template_locale` WHERE `entry` = 351098;
CREATE TEMPORARY TABLE `tmp_naxx40_tesla_loc` AS SELECT * FROM `creature_template_locale` WHERE `entry` = 16218;
UPDATE `tmp_naxx40_tesla_loc` SET `entry` = 351098;
INSERT INTO `creature_template_locale` SELECT * FROM `tmp_naxx40_tesla_loc`;
DROP TEMPORARY TABLE `tmp_naxx40_tesla_loc`;

-- ---------------------------------------------------------------------
-- 4a. Naxx40 Master Craftsman Omarion (351099) -- clone of stock 16365
-- ---------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` = 351099;
CREATE TEMPORARY TABLE `tmp_naxx40_omarion` AS SELECT * FROM `creature_template` WHERE `entry` = 16365;
UPDATE `tmp_naxx40_omarion` SET `entry` = 351099, `ScriptName` = 'npc_omarion_gossip', `gossip_menu_id` = 0, `faction` = 1766, `difficulty_entry_1` = 0, `difficulty_entry_2` = 0, `difficulty_entry_3` = 0;
INSERT INTO `creature_template` SELECT * FROM `tmp_naxx40_omarion`;
DROP TEMPORARY TABLE `tmp_naxx40_omarion`;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 351099;
CREATE TEMPORARY TABLE `tmp_naxx40_omarion_model` AS SELECT * FROM `creature_template_model` WHERE `CreatureID` = 16365;
UPDATE `tmp_naxx40_omarion_model` SET `CreatureID` = 351099;
INSERT INTO `creature_template_model` SELECT * FROM `tmp_naxx40_omarion_model`;
DROP TEMPORARY TABLE `tmp_naxx40_omarion_model`;

DELETE FROM `creature_template_addon` WHERE `entry` = 351099;
CREATE TEMPORARY TABLE `tmp_naxx40_omarion_addon` AS SELECT * FROM `creature_template_addon` WHERE `entry` = 16365;
UPDATE `tmp_naxx40_omarion_addon` SET `entry` = 351099;
INSERT INTO `creature_template_addon` SELECT * FROM `tmp_naxx40_omarion_addon`;
DROP TEMPORARY TABLE `tmp_naxx40_omarion_addon`;

DELETE FROM `creature_template_movement` WHERE `CreatureId` = 351099;
CREATE TEMPORARY TABLE `tmp_naxx40_omarion_move` AS SELECT * FROM `creature_template_movement` WHERE `CreatureId` = 16365;
UPDATE `tmp_naxx40_omarion_move` SET `CreatureId` = 351099;
INSERT INTO `creature_template_movement` SELECT * FROM `tmp_naxx40_omarion_move`;
DROP TEMPORARY TABLE `tmp_naxx40_omarion_move`;

DELETE FROM `creature_template_locale` WHERE `entry` = 351099;
CREATE TEMPORARY TABLE `tmp_naxx40_omarion_loc` AS SELECT * FROM `creature_template_locale` WHERE `entry` = 16365;
UPDATE `tmp_naxx40_omarion_loc` SET `entry` = 351099;
INSERT INTO `creature_template_locale` SELECT * FROM `tmp_naxx40_omarion_loc`;
DROP TEMPORARY TABLE `tmp_naxx40_omarion_loc`;

-- The single map-2921 Omarion (guid 361390) moves onto the clone.  Guarded on
-- both guid AND map so it can never touch a stock-533 spawn.
UPDATE `creature` SET `id` = 351099 WHERE `guid` = 361390 AND `map` = 2921 AND `id` = 16365;

-- ---------------------------------------------------------------------
-- 4b. Omarion gossip tree  (restored from 07_naxx40_omarion.sql)
--     24400 no-crafter / 24401 tailoring / 24402 blacksmithing /
--     24403 leatherworking / 24404 intro
--     Emote fields are baked into the INSERT here; 07_ set them with three
--     follow-up UPDATEs.  Laugh = 11, Talk = 1, Question = 6.
-- ---------------------------------------------------------------------
SET @ID := 24400;

DELETE FROM `npc_text` WHERE `ID` IN (@ID+1, @ID+2, @ID+3);
INSERT INTO `npc_text` (`ID`, `text0_0`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_1`, `em0_3`, `VerifiedBuild`) VALUES
(@ID+1, 'A tailor, eh? Very well. What would you like to learn about, tailor?', 12252, 0, 1, 6, 1, 0),
(@ID+2, 'I have what you need, $c.', 12265, 0, 1, 1, 0, 0),
(@ID+3, 'Perhaps I can teach you something...', 12258, 0, 1, 1, 0, 0);

DELETE FROM `gossip_menu` WHERE `MenuID` IN (@ID+1, @ID+2, @ID+3);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(@ID+1, @ID+1),
(@ID+2, @ID+2),
(@ID+3, @ID+3);

DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (@ID, @ID+1, @ID+2, @ID+3, @ID+4);
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(@ID,   1, 0, 'Thank you, Omarion. You have taken a fatal blow for the team on this day.', 12281, 1, 1, 0,     0, 0, 0, '', 0, 0),
(@ID+1, 1, 3, 'Glacial Cloak.',                                                            12254, 1, 1, @ID+1, 0, 0, 0, '', 0, 0),
(@ID+1, 2, 3, 'Glacial Gloves.',                                                           12255, 1, 1, @ID+1, 0, 0, 0, '', 0, 0),
(@ID+1, 3, 3, 'Glacial Wrists.',                                                           12256, 1, 1, @ID+1, 0, 0, 0, '', 0, 0),
(@ID+1, 4, 3, 'Glacial Vest.',                                                             12253, 1, 1, @ID+1, 0, 0, 0, '', 0, 0),
(@ID+1, 5, 0, 'I need to go. Evil stirs. Die well, Omarion.',                              12270, 1, 1, 0,     0, 0, 0, '', 0, 0),
(@ID+2, 1, 3, 'Icebane Bracers.',                                                          12268, 1, 1, @ID+2, 0, 0, 0, '', 0, 0),
(@ID+2, 2, 3, 'Icebane Gauntlets.',                                                        12267, 1, 1, @ID+2, 0, 0, 0, '', 0, 0),
(@ID+2, 3, 3, 'Icebane Breastplate.',                                                      12266, 1, 1, @ID+2, 0, 0, 0, '', 0, 0),
(@ID+2, 4, 0, 'I need to go. Evil stirs. Die well, Omarion.',                              12270, 1, 1, 0,     0, 0, 0, '', 0, 0),
(@ID+3, 1, 3, 'Polar Bracers.',                                                            12264, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+3, 2, 3, 'Polar Gloves.',                                                             12263, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+3, 3, 3, 'Polar Tunic.',                                                              12262, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+3, 4, 3, 'Icy Scale Bracers.',                                                        12261, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+3, 5, 3, 'Icy Scale Gauntlets.',                                                      12260, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+3, 6, 3, 'Icy Scale Breastplate.',                                                    12259, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+3, 7, 0, 'I need to go. Evil stirs. Die well, Omarion.',                              12270, 1, 1, 0,     0, 0, 0, '', 0, 0),
(@ID+4, 1, 0, 'I am a master leatherworker, Omarion.',                                     12257, 1, 1, @ID+3, 0, 0, 0, '', 0, 0),
(@ID+4, 2, 0, 'I am a master blacksmith, Omarion.',                                        12269, 1, 1, @ID+2, 0, 0, 0, '', 0, 0),
(@ID+4, 3, 0, 'I am a master tailor, Omarion.',                                            12251, 1, 1, @ID+1, 0, 0, 0, '', 0, 0),
(@ID+4, 4, 0, 'Omarion, I am not a craftsman. Can you still help me?',                     12279, 1, 1, @ID,   0, 0, 0, '', 0, 0);

-- ---------------------------------------------------------------------
-- 5. Verification
-- ---------------------------------------------------------------------
-- SELECT spell_id, ScriptName FROM spell_script_names WHERE spell_id IN (26234, 28819, 800029);
-- SELECT entry, name, faction, gossip_menu_id, ScriptName FROM creature_template WHERE entry IN (351098, 351099);
-- SELECT guid, id, map FROM creature WHERE guid = 361390;
-- SELECT MenuID, COUNT(*) FROM gossip_menu_option WHERE MenuID BETWEEN 24400 AND 24404 GROUP BY MenuID;
-- =====================================================================
