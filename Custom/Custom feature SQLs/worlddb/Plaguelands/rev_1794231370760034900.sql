-- Map 751 Silverpine port, Forsaken High Command slice: data for
-- src/server/scripts/DC/Plaguelands/Silverpine/silverpine_dc_high_command.cpp (AddSC_dc_silverpine_high_command).
--
-- 1. The Warchief Cometh (26965). Grand Executor Mortuus (4144615) gives and takes the quest and now hosts
--    npc_warchief_cometh_controller (the source's bunny 74954 was Neltharion-custom and never imported). The
--    static Agatha (4144608) and the 11 static Fallen Humans (4144592 male, 4144593 female) act the raise,
--    so the corpses get npc_fallen_human_silverpine. The source summons Sylvanas (44365) and Cromush (44640)
--    by id; neither template exists, so both are added here at their plain Cata ids (values from cata_world;
--    npcflag 0 as their SmartAI set it on summon, unit_flags 768 so the cutscene cast cannot be attacked;
--    displays 28213 / 34009 are in CreatureDisplayInfo.dbc). Garrosh (44629) already exists (89_).
--    creature_text is nelt_world's for 44365 / 44629 / 44640, BroadcastTextIds checked present. Sound is 0:
--    the voice kits 20459-20469 / 20496-20504 are not in the server SoundEntries.dbc and would be dropped
--    with a load error; the broadcast texts still name them should they be added later.
-- 2. 83149 "Forsaken Trooper Master Script" -> spell_forsaken_tropper_rand_transform (nelt binding).
-- 3. Steel Thunder (27069): the Sea Dog Crate (4805165) casts 83837, which force-casts 83838; 83838 and the
--    Orc Sea Pup do not exist here, so spell_pick_up_orc_crate is bound to 83837 and credits 44915 itself.
-- 4. Lost in the Darkness (27093): the cocoons (4144941) get npc_webbed_victim_silverpine, the rescued
--    Orc Sea Dog (44942, plain: the summon id and the quest objective) npc_orc_sea_dog_rescued. Its text is
--    nelt_world's minus one machine-translated line.
-- None of the bound entries has smart_scripts rows (checked), so no AIName/SAI cleanup is needed beyond
-- clearing AIName.
REPLACE INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `dmgschool`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `type_flags`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `RegenHealth`, `flags_extra`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(44365, 'Lady Sylvanas Windrunner', 'Banshee Queen', 88, 88, 0, 118, 0, 0.888888, 1.38571, 3, 0, 2000, 2000, 2, 768, 2048, 7, 2124, 0, 1, 400, 20, 1, 0, '', '', 15595),
(44640, 'High Warlord Cromush', '', 85, 85, 0, 29, 0, 1, 1.14286, 1, 0, 2000, 2000, 1, 768, 2048, 7, 0, 0, 1, 5, 15, 1, 0, '', '', 15595);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (44365, 44640);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(44365, 0, 28213, 1, 1, 15595),
(44640, 0, 34009, 1, 1, 15595);

DELETE FROM `creature_text` WHERE `CreatureID` IN (44365, 44629, 44640, 44942);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(44365, 0, 0, 'Where is that ogre-headed buffoon?', 12, 1, 100, 6, 0, 0, 44695, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 1, 0, 'Ah, speak of the devil...', 12, 1, 100, 1, 0, 0, 44696, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 2, 0, 'Warchief, so glad you could make it.', 12, 1, 100, 1, 0, 0, 44701, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 3, 0, 'With the death of the Lich King, many of the more intelligent Scourge became... unemployed. Those ''fiends,'' as you so delicately put it, are called val''kyr. They are under my command now...', 12, 1, 100, 0, 0, 0, 44702, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 4, 0, '...and they are part of the reason that I asked to see you.', 12, 1, 100, 1, 0, 0, 44703, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 5, 0, 'Very well, Warchief. I have solved the plight of the Forsaken!', 12, 1, 100, 5, 0, 0, 44705, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 6, 0, 'As a race, we Forsaken are unable to procreate', 12, 1, 100, 274, 0, 0, 44706, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 7, 0, 'With the aid of the val''kyr, we are now able to take the corpses of the fallen and create new Forsaken.', 12, 1, 100, 0, 0, 0, 44707, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 8, 0, 'Agatha, show the Warchief!', 12, 1, 100, 22, 0, 0, 44709, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 9, 0, 'Warchief, without these new Forsaken my people would die out... Our hold upon Gilneas and northern Lordaeron would crumble.', 12, 1, 100, 0, 0, 0, 44715, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44365, 10, 0, 'Isn''t it obvious, Warchief? I serve the Horde.', 12, 1, 100, 66, 0, 0, 44718, 0, 'Lady Sylvanas Windrunner - The Warchief Cometh'),
(44629, 0, 0, 'This better be important, Sylvanas. You know how I detest this place and its foul stench. Why have you called for me?', 12, 1, 100, 0, 0, 0, 44699, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 1, 0, 'And more importantly, what are those Scourge fiends doing here?', 12, 1, 100, 25, 0, 0, 44700, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 2, 0, 'Get on with it, Sylvanas.', 12, 1, 100, 1, 0, 0, 44704, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 3, 0, 'What you have done here, Sylvanas... it goes against the laws of nature. Disgusting is the only word I have to describe it.', 12, 1, 100, 0, 0, 0, 44714, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 4, 0, 'Have you given any thought to what this means, Sylvanas?', 12, 1, 100, 6, 0, 0, 44716, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 5, 0, 'What difference is there between you and the Lich King now?', 12, 1, 100, 6, 0, 0, 44717, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 6, 0, 'Watch your clever mouth, bitch.', 12, 1, 100, 397, 0, 0, 44719, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 7, 0, 'Cromush, you stay behind and make sure the Banshee Queen is well "guarded." I will be expecting a full report when next we meet.', 12, 1, 100, 0, 0, 0, 44720, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44629, 8, 0, 'Remember, Sylvanas, eventually we all have to stand before our maker and face judgment. Your day may come sooner than others...', 12, 1, 100, 0, 0, 0, 44721, 0, 'Garrosh Hellscream - The Warchief Cometh'),
(44640, 0, 0, 'ABBERATION!', 12, 1, 100, 5, 0, 0, 44713, 0, 'High Warlord Cromush - The Warchief Cometh'),
(44640, 1, 0, 'As you command, Warchief!', 12, 1, 100, 66, 0, 0, 44738, 0, 'High Warlord Cromush - The Warchief Cometh'),
(44942, 0, 0, 'We will find the commander of the operation and finish!', 12, 0, 100, 5, 0, 0, 0, 0, 'Orc Sea Dog - rescued'),
(44942, 0, 1, 'I need a drink!', 12, 0, 100, 5, 0, 0, 0, 0, 'Orc Sea Dog - rescued'),
(44942, 0, 2, 'Thanks!', 12, 0, 100, 5, 0, 0, 0, 0, 'Orc Sea Dog - rescued');

UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_warchief_cometh_controller' WHERE `entry` = 4144615;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_fallen_human_silverpine' WHERE `entry` IN (4144592, 4144593);
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_webbed_victim_silverpine' WHERE `entry` = 4144941;
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_orc_sea_dog_rescued' WHERE `entry` = 44942;

DELETE FROM `spell_script_names` WHERE `spell_id` IN (83149, 83837) AND `ScriptName` IN ('spell_forsaken_tropper_rand_transform', 'spell_pick_up_orc_crate');
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(83149, 'spell_forsaken_tropper_rand_transform'),
(83837, 'spell_pick_up_orc_crate');
