-- Silverpine Forest (map 751), C++ port slice "cities_in_dust":
-- src/server/scripts/DC/Plaguelands/Silverpine/silverpine_dc_cities_in_dust.cpp
--
-- 1. Quest 27088 "It's Only Poisonous if You Ingest It".
--    - The chicken 44935 exists at its PLAIN id (item 60808's spell 83902 summons that id) and
--      had no script: bind npc_mutant_bush_chicken. It has no smart_scripts rows.
--    - 83902 names SummonProperties 3027, which is in neither the server SummonProperties.dbc
--      (ids end at 2976) nor summonproperties_dbc, so it summoned nothing ("EffectSummonType:
--      Unhandled summon type 3027"). Row taken from the retail extract
--      (retroport_tools/_wago_68887/SummonProperties.csv: 3027,1,0,0,6,132352), Flags cut to
--      the low 16 bits (0x500) because 0x20000 does not exist in 3.3.5. Server-side only.
--      3027 is used by no other spell.
--    - The explosion 83903 hits an area of "entry" targets; 4.3.4 restricted effects 0 and 2
--      (damage, -62% damage done) to the ettin 44367. Ours is 4144367 (the spawned ettin and
--      27088's RequiredNpcOrGo1).
--
-- 2. Quest 27601 "Cities in Dust": the scene's twelve creatures did not exist on this server
--    (cata_world has the templates, the 751 import never took them). They are summoned, never
--    spawned, so they stay at their PLAIN Cata ids, as 100_missing_summon_creatures.sql does.
--    Values: names, classes, factions, flags (unit_flags 768 = immune to PC and NPC, as in
--    4.3.4) and type_flags from the 4.3.4 data; levels on the 751 Silverpine band
--    (71_level_reband: 10-20 -> 134-140, elite ceiling +2): Godfrey 140, Walden 139,
--    Ashbury 138, val'kyr 137, everyone else 140 (Cromush is level 1 in the Cata data, a
--    placeholder). Health: Godfrey and his two lords 8.5 (2.5 x basehp2 / basehp0 at 140, the
--    "rare: a real solo fight" factor of 106_); the rest cannot die (the script clamps damage)
--    and get 5. Godfrey's VehicleId 1170 is dropped: Vehicle.dbc does not have it.
--    Displays: Darius Crowley 34161 and Lorna Crowley 34520 are NOT in the server
--    CreatureDisplayInfo.dbc, and a template without a valid model cannot be summoned. They
--    use Worgen Rebel displays as placeholders: 34386 (male) and 34389 (female). Replace
--    both once the real displays are downported.
--    Also from nelt_world: Sylvanas's mount (the script dismounts her when she is shot), the
--    weapons of Sylvanas, Godfrey (his gun for the shot), Cromush and Crowley, 44 of the 45
--    creature_text lines (Sylvanas's group 24, an "another player already triggered the
--    scene" whisper, is left out: the scene is private now), and the condition restricting
--    the val'kyr's Raise Forsaken (85950) to Sylvanas.
--
-- NOT in this file, because it is not part of this slice: quest 27601 itself, its questgiver
-- Lady Sylvanas Windrunner 45617 (Forsaken High Command), its ender 46124 (Battlefront) and
-- the chain before it (27542-27594). None of them exist here. Whoever imports 27601 must keep
-- RequiredNpcOrGo1 = 46019 (plain id, the script credits it with KilledMonsterCredit) and must
-- NOT port 45617's quest-accept SmartAI: the C++ PlayerScript summons the scene on accept.

-- ---------------------------------------------------------------------------
-- Quest 27088: the chicken
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = '', `ScriptName` = 'npc_mutant_bush_chicken' WHERE `entry` = 44935;

-- SummonProperties 3027 is added by rev_1794231896144905400.sql with the other Cata summon rows.

-- ---------------------------------------------------------------------------
-- Spell target conditions (13 = implicit target, SourceGroup = effect mask, 31 = object entry)
-- ---------------------------------------------------------------------------
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 13 AND `SourceEntry` IN (83903, 85950);
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(13, 5, 83903, 0, 0, 31, 0, 3, 4144367, 0, 0, 0, 0, '', 'Bush Chicken Explosion! - only hits Forest Ettin (751)'),
(13, 1, 85950, 0, 0, 31, 0, 3, 46026, 0, 0, 0, 0, '', 'Raise Forsaken - only hits Lady Sylvanas Windrunner (Cities in Dust)');

-- ---------------------------------------------------------------------------
-- Quest 27601: the scene's creatures
-- ---------------------------------------------------------------------------
REPLACE INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `type_flags`, `VehicleId`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
(46019, 'Cities in Dust Quest Credit', '', 140, 140, 0, 68, 0, 1, 1.14286, 1, 1, 2000, 2000, 2, 0, 2048, 7, 262148, 0, '', 0, 1, 1, 1, 1, 1, 1, 0, '', 0),
(46026, 'Lady Sylvanas Windrunner', 'Banshee Queen', 140, 140, 0, 35, 0, 1, 1.14286, 1, 2, 2000, 2000, 2, 768, 2048, 7, 2124, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_sylvanas_cities_in_dust', 0),
(46027, 'Commander Lorna Crowley', '', 140, 140, 0, 11, 0, 1, 1.14286, 1, 2, 2000, 2000, 1, 768, 2048, 7, 0, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0),
(46028, 'Lord Godfrey', '', 140, 140, 0, 68, 0, 1, 1.14286, 1, 1.5, 2000, 2000, 2, 768, 2048, 7, 262148, 0, '', 0, 1, 8.5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_enemies', 0),
(46029, 'Lord Walden', '', 139, 139, 0, 68, 0, 1, 1.14286, 1, 1.5, 2000, 2000, 2, 768, 2048, 7, 262144, 0, '', 0, 1, 8.5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_enemies', 0),
(46030, 'Baron Ashbury', '', 138, 138, 0, 68, 0, 1, 1.14286, 1, 1.5, 2000, 2000, 2, 768, 2048, 7, 262144, 0, '', 0, 1, 8.5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_enemies', 0),
(46031, 'High Warlord Cromush', '', 140, 140, 0, 35, 0, 1, 1.14286, 1, 2, 2000, 2000, 1, 768, 2048, 7, 0, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0),
(46032, 'Arthura', '', 137, 137, 0, 35, 0, 1, 1.14286, 1, 2, 2000, 2000, 2, 768, 2048, 7, 0, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0),
(46033, 'Daschla', '', 137, 137, 0, 35, 0, 1, 1.14286, 1, 2, 2000, 2000, 2, 768, 2048, 7, 0, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0),
(46034, 'Agatha', '', 137, 137, 0, 35, 0, 1, 1.14286, 1, 2, 2000, 2000, 2, 768, 2048, 7, 0, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0),
(46035, 'Packleader Ivar Bloodfang', '', 140, 140, 0, 2173, 0, 1, 1.14286, 1, 2, 2000, 2000, 1, 768, 2048, 7, 262148, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0),
(46036, 'Lord Darius Crowley', 'Leader of the Gilneas Liberation Front', 140, 140, 0, 7, 0, 1, 1.14286, 1, 2, 2000, 2000, 1, 768, 2048, 7, 262148, 0, '', 0, 1, 5, 1, 1, 1, 1, 0, 'npc_cities_in_dust_actors', 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (46019, 46026, 46027, 46028, 46029, 46030, 46031, 46032, 46033, 46034, 46035, 46036);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(46019, 0, 34611, 1, 1, 0),
(46026, 0, 28213, 1, 1, 0),
(46027, 0, 34389, 1, 1, 0),
(46028, 0, 34611, 1, 1, 0),
(46029, 0, 34612, 1, 1, 0),
(46030, 0, 34610, 1, 1, 0),
(46031, 0, 34009, 1, 1, 0),
(46032, 0, 33997, 1, 1, 0),
(46033, 0, 33997, 1, 1, 0),
(46034, 0, 33996, 1, 1, 0),
(46035, 0, 34162, 1, 1, 0),
(46036, 0, 34386, 1, 1, 0);

DELETE FROM `creature_template_addon` WHERE `entry` = 46026;
INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`) VALUES
(46026, 0, 29257, 0, 1, 0, 0, NULL);

DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (46026, 46028, 46031, 46036);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(46026, 1, 2179, 0, 42775, 0),
(46028, 1, 0, 0, 52052, 0),
(46031, 1, 47031, 0, 0, 0),
(46036, 1, 54877, 54878, 0, 0);

DELETE FROM `creature_text` WHERE `CreatureID` IN (46026, 46028, 46031, 46032, 46033, 46034, 46035, 46036);
INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES
(46026, 0, 0, 'Onward, $n! We will beat back the Alliance dogs and secure Lordaeron for the Forsaken! For the Horde!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 1, 0, 'Accompany Lady Sylvanas Windrunner across the Battlefront.', 42, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 2, 0, 'Lay down your arms and surrender!', 14, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 3, 0, 'I will leave your cities in dust and your lives in ruin!', 14, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 4, 0, 'Look at them, $n. They scurry like rats, veering headlong to their doom. Surely Crowley and Bloodfang can see the futility in this!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 5, 0, 'To the Greymane Wall! We will force their hand.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 6, 0, 'Crowley, your forces have fallen before my mighty army. You have lost!', 14, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 7, 0, 'You frivolously throw away the lives of your people while your own king sits atop his throne of lies, nary lifting a finger to help.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 8, 0, 'Is Gilneas worth the lives that have been lost? The lives that will be lost? You cannot win.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 9, 0, 'And your daughter? You could have saved her... You could have offered her your blood, yet you did not. Why?', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 10, 0, 'Nothing, yet...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 11, 0, 'I now present you with a choice - a choice that I was never given.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 12, 0, 'I offer you the life of Lorna for your unconditional surrender.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 13, 0, 'Choose your next words wisely, Crowley. Deny me and she will serve me in undeath - forever.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 14, 0, 'Bring her, Godfrey!', 14, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 15, 0, 'Release her, Godfrey.', 12, 0, 100, 1, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 16, 0, 'Now leave here, Crowley, and never return.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 17, 0, 'Lordaeron belongs to the Forsaken.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 18, 0, 'SOLDIERS OF THE HORDE! WE ARE VICTORIOUS! LORDAERON IS W...', 14, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 19, 0, 'Lady Sylvanas Windrunner dies.', 41, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 20, 0, 'I saw... only darkness.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 21, 0, 'And as I drifted towards nothingness, a brilliant light appeared, then another, and another... My dear val''kyr.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 22, 0, 'I know now - beyond a shadow of a doubt - that the val''kyr are our future.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46026, 23, 0, 'We will never stop fighting for Lordaeron. Never...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lady Sylvanas Windrunner - Cities in Dust'),
(46028, 0, 0, 'Hello, old friend!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46028, 1, 0, 'Of course, mistress.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46028, 2, 0, 'Something that should have been done a long time ago, you filthy animal.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46028, 3, 0, 'Gilneas belongs to me, and so soon will the rest of Lordaeron!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46028, 4, 0, 'NOW JOIN YOUR MISTRESS IN DEATH!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46028, 5, 0, 'FALL BACK, BROTHERS! TO SHADOWFANG!', 14, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46028, 6, 0, 'This land will quiver and shake in the wake of our destruction!', 14, 0, 100, 0, 0, 0, 0, 0, 'Lord Godfrey - Cities in Dust'),
(46031, 0, 0, 'WHAT HAVE YOU DONE, GODFREY!', 12, 0, 100, 15, 0, 0, 0, 0, 'High Warlord Cromush - Cities in Dust'),
(46031, 1, 0, 'Fix her... FIX HER!', 12, 0, 100, 0, 0, 0, 0, 0, 'High Warlord Cromush - Cities in Dust'),
(46032, 0, 0, 'It will destroy us, sister...', 12, 0, 100, 1, 0, 0, 0, 0, 'Arthura - Cities in Dust'),
(46032, 1, 0, 'Then let it be done.', 12, 0, 100, 0, 0, 0, 0, 0, 'Arthura - Cities in Dust'),
(46033, 0, 0, 'It is our sacred duty. The pact was sealed, the bargain made...', 12, 0, 100, 1, 0, 0, 0, 0, 'Daschla - Cities in Dust'),
(46034, 0, 0, 'We are bound to her, sisters...', 12, 0, 100, 1, 0, 0, 0, 0, 'Agatha - Cities in Dust'),
(46035, 0, 0, 'You can''t be serious, Crowley. You miserable bastard!', 12, 0, 100, 5, 0, 0, 0, 0, 'Packleader Ivar Bloodfang - Cities in Dust'),
(46036, 0, 0, 'It''s not over, Sylvanas. Not yet.', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - Cities in Dust'),
(46036, 1, 0, 'We will die trying!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - Cities in Dust'),
(46036, 2, 0, 'LORNA? What... Where is she!? What have you done to her!?', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - Cities in Dust'),
(46036, 3, 0, 'GODFREY! You deceitful maggot!', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - Cities in Dust'),
(46036, 4, 0, 'Lorna... I... Release her. I will sound the retreat.', 12, 0, 100, 6, 0, 0, 0, 0, 'Lord Darius Crowley - Cities in Dust'),
(46036, 5, 0, 'Forgive me, daughter...', 12, 0, 100, 0, 0, 0, 0, 0, 'Lord Darius Crowley - Cities in Dust');
