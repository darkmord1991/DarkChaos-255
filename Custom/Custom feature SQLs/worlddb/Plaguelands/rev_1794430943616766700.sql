-- DarkChaos: map 751 quest cleanup - missing turn-ins, dead and below-band quest offers, four fixed-level Cata
-- quests, six SmartAI flags and quest-item drops (audit 2026-11-11, counts re-checked against the live DB)
--
-- Scope: the 569 quests GIVEN on map 751 (a starter spawned there). "DC-only" = no spawn on a stock map
-- (map < 725 AND map <> 37). Every starter DELETE names its exact (giver, quest) pairs AND re-checks at apply
-- time that the giver is spawned on 751 and DC-only, so no stock quest offer can be touched. Every INSERT is
-- preceded by a DELETE of exactly the keys it writes. Re-running the file changes nothing more.
--
-- Revert: everything is listed explicitly below - re-insert the starter pairs of blocks 1b, 2 and 3, set quest
-- 28189 back to QuestLevel 20 / MinLevel 19, set AIName back to '' for the six entries of block 4 and Data1 back
-- to 0 for the seven gameobjects of block 5, and delete the turn-in and loot pairs this file adds.
--
-- Apply to acore_world, then restart the worldserver.

-- 1a. Six quests given on 751 had no turn-in row at all. Their turn-in (skyfire_world and cata_world agree,
-- TC_Cata_world too where it has the row) exists on 751 as the DC copy (source entry + 3600000), spawned only
-- on 751:
--   26935 Northridge Lumber Mill        -> 3611616 Nathaniel Dumah  (source 11616)
--   27165 Victory, For Now              -> 3610838 Ashlam Valorfist (source 10838)
--   27206 Alas, Andorhal                -> 3610838 Ashlam Valorfist (source 10838)
--   27535 Just a Little Touched         -> 3612384 Augustus the Touched (source 12384)
--   27544 Cenarion Tenacity             -> 3616135 Rayne (source 16135)
--   27053 Gahrron's Withering Cauldron  -> GO 3776392 Scourge Cauldron (source 176392)
-- The INSERTs re-check that the entry is still spawned on 751 and DC-only.
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3611616, 26935), (3610838, 27165), (3610838, 27206));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3612384, 27535), (3616135, 27544));
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (
    SELECT 3611616 AS `id`, 26935 AS `quest` UNION ALL
    SELECT 3610838, 27165 UNION ALL
    SELECT 3610838, 27206 UNION ALL
    SELECT 3612384, 27535 UNION ALL
    SELECT 3616135, 27544
) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

DELETE FROM `gameobject_questender` WHERE `id` = 3776392 AND `quest` = 27053;
INSERT INTO `gameobject_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (SELECT 3776392 AS `id`, 27053 AS `quest`) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `gameobject` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

-- 1b. Stop offering 44 quests on 751 that cannot be turned in there. The turn-in of each one (looked up in
-- skyfire_world, cata_world and TC_Cata_world) is either not in the live DB or not spawned on 751:
--   - 24 class breadcrumbs ("Meet with ..." and the older class-trainer calls): 20 from the Undercity class
--     trainers (their spawns carry zone 4933) and 4 from the Silverpine paladin trainer 4120406, all ending at
--     trainers in Orgrimmar, Thunder Bluff, Silvermoon or Moonglade;
--   - 6 dungeon breadcrumbs ending inside Ragefire Chasm (26867), Scarlet Monastery (26982, 26986, 26987,
--     26988) or Stratholme (27422); no copy of those turn-ins exists on 751/821/822/825;
--   - 13 Cata quests whose turn-in was never imported or never spawned on 751: Sylvanas 44365/45525/45617,
--     Belmont 45474 (template only), Captain Rutsak 45389, Murd Doc 44556, Johnny Awesome 47869, Kingslayer
--     Orkus 48218, Eddie Flofizzle 46650, Lieutenant Sanders 13158 (map 0 only), and 28355, which has no
--     turn-in in any source DB. 27181 and 28355 are listed in dc_quest_auto_complete, but their giver is the
--     hostile kill target itself (Bloodfang Stalker faction 2166, Mudsnout Gnoll faction 95), so neither can
--     ever be accepted. 27406 and 27423 could end at the same-name Belmont 4145312 on 751, but their objectives
--     (Lord Godfrey's corpse 44369, Worgen Combatant Proxy 45495) are spawned nowhere on 751;
--   - 27096 Orcs are in Order and 27455 Boys Will Be Boys are NOT unlinked: the follow-up file
--     rev_1794431829690775000.sql gives them same-name turn-ins on 751 (Sylvanas 4110181, Gidwin 3645730);
--   - 205904 (clone of 5904) ends at the summoned Termite Barrel 177491, whose summoner, the Northridge Lumber
--     Mill Crate 177490, is spawned only on map 0.
-- Every giver here is a DC-only copy; none is shared with a stock map. Turn-in rows are left alone.
DELETE FROM `creature_queststarter`
WHERE (`id`, `quest`) IN (
    (4104563, 27282), (4104563, 28299), (4104566, 27277), (4104566, 28300), (4104584, 27279), (4104584, 28298),
    (4104593, 27281), (4104593, 28290), (4104606, 27331), (4104606, 27332), (4104606, 27334), (4104606, 27335),
    (4104606, 28164), (4104606, 28304), (4104606, 28307), (4104606, 28309), (4104606, 28323), (4139116, 27278),
    (4139116, 28297), (4152319, 27283), (4120406, 27298), (4120406, 27304), (4120406, 28302), (4120406, 28303),
    (4110837, 25010), (4110181, 26867), (4102789, 26943), (4102700, 26982), (4112920, 26986), (4114741, 26987),
    (4114739, 26988), (4145195, 27181), (4145315, 27350), (4145312, 27406), (3645482, 27422),
    (4145315, 27423), (4145312, 27438), (4101938, 27484), (4145752, 27513), (3648704, 27762),
    (4147781, 28206), (4148129, 28344), (4102372, 28355), (3611616, 205904)
)
  AND `id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- 2. Stop offering the 34 below-band PvP quests on 751: Alterac Valley (QuestSortID 2597, 22 quests, the
-- Stormpike/Frostwolf copies at the Stormpike camp in Hillsbrad) and Arathi Basin (QuestSortID 3358, 12 quests,
-- the Arathi Highlands copies). The stock givers on maps 0/30 keep them; the 751 turn-ins stay so a quest that is
-- already in a log can still be handed in.
DELETE FROM `creature_queststarter`
WHERE (`id`, `quest`) IN (
    (4113776, 7082), (4113776, 7101), (4113776, 7124), (4113777, 7081), (4113777, 7102), (4113777, 7122),
    (4113816, 7141), (4113816, 8271), (4113817, 7142), (4113817, 8272), (4113840, 7161), (4113840, 7163),
    (4113840, 7164), (4113840, 7165), (4113840, 7166), (4113840, 7167), (4113841, 7162), (4113841, 7168),
    (4113841, 7169), (4113841, 7170), (4113841, 7171), (4113841, 7172),
    (4114983, 8105), (4114983, 8114), (4114983, 8115), (4115021, 8120), (4115021, 8121), (4115021, 8122),
    (4115126, 8263), (4115126, 8264), (4115126, 8265), (4115127, 8260), (4115127, 8261), (4115127, 8262)
)
  AND `id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- 3. The four Cata quests at fixed low levels:
--   28189 Do the Right Thing (was QuestLevel 20 / MinLevel 19): SCALED. It is playable on 751 - GO giver Shovel
--     4806944 hands out item 63150, whose spell 89089 exists server- and client-side, the 15 Human Seedlings
--     4147872 are spawned in Hillsbrad (28 spawns), and the quest has no turn-in NPC by design: it is listed in
--     dc_quest_auto_complete (remote turn-in popup). MinLevel = Hillsbrad floor 138 - 2.
--   27045 Waiting to Exsanguinate (lvl 11): UNLINKED. Turn-in Belmont 44789 is not in the live DB, its
--     prerequisite 27039 is not offered on 751 and its eavesdrop credit 44882 is not spawned anywhere.
--   29157 The Zandalari Menace (lvl 85): UNLINKED. Breadcrumb to Bwemba 53081 in Orgrimmar, not in the live DB.
--   29388 Guardians of Hyjal: Firelands Invasion! (lvl 128): KEPT. Its turn-in Matoclaw 3652669 is spawned only on
--     map 750 (Hyjal), but 29387/29388 carry NextQuestID 29145, and 29387 has no giver anywhere: this board is the
--     only way into Matoclaw's "Opening the Door" (29145) on map 750. Unlinking it would close that chain.
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 136
WHERE `ID` = 28189 AND `ID` IN (SELECT `quest` FROM `gameobject_queststarter` WHERE `id` = 4806944);

DELETE FROM `gameobject_queststarter`
WHERE (`id`, `quest`) IN ((4805143, 27045), (4807324, 29157))
  AND `id` IN (SELECT `id` FROM `gameobject` WHERE `map` = 751)
  AND `id` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37);

-- 4. Six DC-only templates had smart_scripts rows but AIName '' (so the rows were never loaded), no ScriptName on
-- the template or on any spawn. Their scripts are valid and every spell exists server-side:
--   3611286 Magistrate Marduke     on respawn: cast 17622 Caer Darrow Ghosts on self (skyfire's 11286 script)
--   3644487/3644488/3644489        Thrashing Pumpkin / Pome Wraith / Corn Stalker - on reset: set faction 20
--                                  (nelt_world rows; 20 and template faction 21 are both hostile to players)
--   3645239 Lesser Val'kyr         in combat every 22-24 s: cast 85536 Spectre Blast (spell_dbc overlay)
--   3646096 Crusader Lord Valdelmar aggro: Devotion Aura; Hammer of Justice, Cleave on players within 5 yd,
--                                  Crusader Strike on timers (all 3.3.5 spells)
UPDATE `creature_template` SET `AIName` = 'SmartAI'
WHERE `entry` IN (3611286, 3644487, 3644488, 3644489, 3645239, 3646096)
  AND `AIName` = '' AND `ScriptName` = ''
  AND `entry` IN (SELECT `entryorguid` FROM `smart_scripts` WHERE `source_type` = 0)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- 5a. Quest items whose dropper exists on 751 but drops nothing: seven chest GOs whose import zeroed the loot id
-- (Data1 = 0). Source: the same GO in cata_world/skyfire_world (100 %, quest item). Data1 is set to the entry, only
-- where it is still 0, and the loot rows are keyed by that Data1.
--   27011 Redpine Thievery             60750 Northridge Lumber        GO 3805137 (48 spawns)
--   27017 Memories from a Lost Past    60770 Gahrron Prayer Book      GO 3805153
--                                      60771 Faded Finger Painting    GO 3805154
--   27488 Impatience                   61318 Gidwin's Prayer Book     GO 3805537
--   27531 Counter-Plague Research      61364 Rotberry (4-7)           GO 3805559 (28 spawns)
--                                      61365 Disembodied Arm          GO 3805560 (43 spawns)
--                                      61366 Flesh Giant Foot Scrapings GO 3805558
UPDATE `gameobject_template` SET `Data1` = `entry`
WHERE `entry` IN (3805137, 3805153, 3805154, 3805537, 3805558, 3805559, 3805560)
  AND `type` = 3 AND `Data1` = 0
  AND `entry` IN (SELECT `id` FROM `gameobject` WHERE `map` = 751)
  AND `entry` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37);

DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805137 AND `Item` = 60750;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805153 AND `Item` = 60770;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805154 AND `Item` = 60771;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805537 AND `Item` = 61318;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805558 AND `Item` = 61366;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805559 AND `Item` = 61364;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805560 AND `Item` = 61365;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
    `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `t`.`Data1`, `v`.`item`, 0, 100, 1, 1, 0, `v`.`mincount`, `v`.`maxcount`, 'DC 751 quest item (cata_world)'
FROM (
    SELECT 3805137 AS `entry`, 60750 AS `item`, 1 AS `mincount`, 1 AS `maxcount` UNION ALL
    SELECT 3805153, 60770, 1, 1 UNION ALL
    SELECT 3805154, 60771, 1, 1 UNION ALL
    SELECT 3805537, 61318, 1, 1 UNION ALL
    SELECT 3805558, 61366, 1, 1 UNION ALL
    SELECT 3805559, 61364, 4, 7 UNION ALL
    SELECT 3805560, 61365, 1, 1
) AS `v`
JOIN `gameobject_template` AS `t` ON `t`.`entry` = `v`.`entry` AND `t`.`Data1` = `v`.`entry`;

-- 5b. Quest items whose dropper is spawned on 751 but has no row for them. Chance = the cata_world chance
-- (skyfire_world agrees where it has the row), QuestRequired = 1. Rows are keyed by Entry = the creature's lootid,
-- which is its own entry for all 14: none of them is among the 222 templates that the pending
-- rev_1794428606734586200.sql gives lootid = entry, so these rows do not depend on that file. Droppers below 1 %
-- in cata_world (world-drop noise on 4138967, 4144547, 4144549, 4144793) are not copied.
--   26283/26490 Prime Slime            58082 Direglob Sample          4142592 The Direglob           100
--   26366/26518 Heads Up               58236 Umboda's Head            4142724 Umboda Three-Heads     100
--   26368 Venomous Secrets             58239 Shadra-Spawn Venom Sample 4142879 Spawn of Shadra       90
--   26418/26530 The Shell of Shadra    58779 Shell of Shadra          4142919 Qiaga the Keeper       100
--   26485 Snapjaws, Lad!               58867 Snapjaw Gizzard          4102505 Saltwater Snapjaw      75
--   24981 A Thorn in our Side          52077 Urgent Scarlet Memorandum 4101536/4101537 75, 4101662 100
--   25056 Grisly Grizzlies             52270 Plagued Bruin Hide       4139049 Plagued Bruin          39.072
--   28199 For Science!                 63254 Flesh Sample             4147859, 4147861 (Risen farmers) 100
--   28484 The Heart of the Matter      64380 Beating Yeti Heart       4148628 Ferocious Yeti         100
--   28485 Yetimus the Yeti Lord        64386 Yetimus' Twisted Horn    4147484 Yetimus                100
--   28489 Stagwiches                   64410 Juicy Stag Meat          4148184 Hill Stag              100
DELETE FROM `creature_loot_template` WHERE `Entry` = 4142592 AND `Item` = 58082 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4142724 AND `Item` = 58236 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4142879 AND `Item` = 58239 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4142919 AND `Item` = 58779 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4102505 AND `Item` = 58867 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4101536 AND `Item` = 52077 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4101537 AND `Item` = 52077 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4101662 AND `Item` = 52077 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4139049 AND `Item` = 52270 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4147859 AND `Item` = 63254 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4147861 AND `Item` = 63254 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4148628 AND `Item` = 64380 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4147484 AND `Item` = 64386 AND `Reference` = 0;
DELETE FROM `creature_loot_template` WHERE `Entry` = 4148184 AND `Item` = 64410 AND `Reference` = 0;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
    `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `t`.`lootid`, `v`.`item`, 0, `v`.`chance`, 1, 1, 0, 1, 1, 'DC 751 quest item (cata_world)'
FROM (
    SELECT 4142592 AS `entry`, 58082 AS `item`, 100 AS `chance` UNION ALL
    SELECT 4142724, 58236, 100 UNION ALL
    SELECT 4142879, 58239, 90 UNION ALL
    SELECT 4142919, 58779, 100 UNION ALL
    SELECT 4102505, 58867, 75 UNION ALL
    SELECT 4101536, 52077, 75 UNION ALL
    SELECT 4101537, 52077, 75 UNION ALL
    SELECT 4101662, 52077, 100 UNION ALL
    SELECT 4139049, 52270, 39.072 UNION ALL
    SELECT 4147859, 63254, 100 UNION ALL
    SELECT 4147861, 63254, 100 UNION ALL
    SELECT 4148628, 64380, 100 UNION ALL
    SELECT 4147484, 64386, 100 UNION ALL
    SELECT 4148184, 64410, 100
) AS `v`
JOIN `creature_template` AS `t` ON `t`.`entry` = `v`.`entry` AND `t`.`lootid` = `v`.`entry`
WHERE `v`.`entry` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- Verify after apply (expected values in brackets):
--   SELECT COUNT(*) FROM `creature_questender` WHERE (`id`, `quest`) IN ((3611616, 26935), (3610838, 27165),
--     (3610838, 27206), (3612384, 27535), (3616135, 27544));                                         [5]
--   SELECT COUNT(*) FROM `gameobject_questender` WHERE `id` = 3776392 AND `quest` = 27053;            [1]
--   SELECT `QuestLevel`, `MinLevel` FROM `quest_template` WHERE `ID` = 28189;                          [-1, 136]
--   SELECT COUNT(*) FROM `creature_template` WHERE `entry` IN (3611286, 3644487, 3644488, 3644489, 3645239,
--     3646096) AND `AIName` = 'SmartAI';                                                              [6]
--   SELECT COUNT(*) FROM `gameobject_loot_template` WHERE `Comment` = 'DC 751 quest item (cata_world)';  [7]
--   SELECT COUNT(*) FROM `creature_loot_template` WHERE `Comment` = 'DC 751 quest item (cata_world)';    [14]
