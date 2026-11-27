-- DarkChaos: Winterspring (map 750) quests unlock 3 levels below their highest kill target, the margin the
-- playerbots quest guard uses (NewRpgHelpers::HasKillTargetAboveBot). The clone remap left them 8-16 levels early,
-- so players and bots met level 110-113 Winterfall furbolgs and Shardtooth bears at level 93-102.
--   108464 Winterfall Activity         93 -> 109 (Winterfall Ursa 3707438, minlevel 112)
--   28637  A Taste for Bear           102 -> 106 (Shardtooth Bear 3707444, minlevel 109)
--   28719  A Little Gamy              101 -> 107 (Shardtooth Mauler 3707443, minlevel 110)
--   105082 Threat of the Winterfall   101 -> 107 (Winterfall Den Watcher 3707440, minlevel 110)
--   106603 Trouble in Winterspring!   101 -> 107 (breadcrumb for 105082)
-- 105082's third objective still named stock Winterfall Totemic 7441, which has no spawns anywhere, so the quest
-- could not be finished; it now names the map-750 copy 3707441 (minlevel 105, 12 spawns).
-- Each UPDATE checks the old value, so a second run changes nothing.
UPDATE `quest_template` SET `MinLevel` = 109 WHERE `ID` = 108464 AND `MinLevel` = 93;
UPDATE `quest_template` SET `MinLevel` = 106 WHERE `ID` = 28637 AND `MinLevel` = 102;
UPDATE `quest_template` SET `MinLevel` = 107 WHERE `ID` = 28719 AND `MinLevel` = 101;
UPDATE `quest_template` SET `MinLevel` = 107 WHERE `ID` = 105082 AND `MinLevel` = 101;
UPDATE `quest_template` SET `MinLevel` = 107 WHERE `ID` = 106603 AND `MinLevel` = 101;
UPDATE `quest_template` SET `RequiredNpcOrGo3` = 3707441 WHERE `ID` = 105082 AND `RequiredNpcOrGo3` = 7441;
