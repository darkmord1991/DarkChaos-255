-- DarkChaos: map 751 quest follow-up - Nathaniel Dumah made neutral, two same-name turn-ins, and the Tyr's Hand
-- quests (Eastern Plaguelands) plus Go Fletch! (Western Plaguelands) offered on their DC-only 751 NPCs
--
-- Apply after rev_1794430943616766700.sql (the map 751 quest cleanup). Same rules: rows are written only for
-- entries spawned on 751 and on no stock map (map < 725 AND map <> 37), every INSERT is preceded by a DELETE of
-- exactly the keys it writes, and re-running the file changes nothing more.
--
-- Revert: faction of 3611616 back to 123; delete the giver, turn-in and loot pairs listed below; QuestLevel and
-- MinLevel of the ten quests back to 42/39 (27166: 36/34); ExclusiveGroup of 27612, 27613, 27614, 27615, 27616
-- and 27619 back to 27612; Data1 of the five gameobjects of block d back to 0.
--
-- Apply to acore_world, then restart the worldserver.

-- a) Nathaniel Dumah 3611616 is the turn-in of 26935 (added by the cleanup file) but kept the classic Alliance
-- faction 123, so Horde players could accept 26935 from the neutral Field Agent Kaartish and never hand it in.
-- cata_world has him on 2070 (Argent Crusade, no friend or enemy group: neutral to both factions; 206 live
-- templates use it, and it is in the server DBC and the client FactionTemplate CSV). Nothing else on 751 sets his
-- faction: both spawns (Chillwind Camp and Northridge Lumber Mill) have no ScriptName, the template has no AI and
-- no ScriptName, and no smart_scripts row sets a faction on him. His other quests stay Alliance-only through their
-- AllowableRaces.
UPDATE `creature_template` SET `faction` = 2070
WHERE `entry` = 3611616 AND `faction` = 123
  AND `entry` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37);

-- b) Same-name turn-ins for two quests the cleanup file no longer unlinks. Their Cata turn-in entry was never
-- imported, but the same character stands on 751 under another DC-only entry and the quest has no objective that
-- 751 lacks:
--   27096 Orcs are in Order -> 4110181 Lady Sylvanas Windrunner. The quest only asks to deliver the letter its
--     giver hands out (60811). NOTE: this Sylvanas stands in the Undercity throne room (1290, 316), not at Forsaken
--     High Command as the quest text says (Admiral Hatchet, the giver, is at 1069, 1601). Her C++ script
--     npc_lady_sylvanas_windrunner only reacts to quest 9180 on reward, so the turn-in itself is unaffected.
--   27455 Boys Will Be Boys -> 3645730 Gidwin Goldbraids, whose second spawn stands at Light's Hope Chapel
--     (2302, -5261), where the quest sends the player. The other Gidwin, 3645428, stands at the western caravan
--     stop and is not used.
-- Not done: 27406 and 27423 could end at Belmont 4145312, but their objectives (Lord Godfrey's corpse 44369 and the
-- Worgen Combatant Proxy 45495) are spawned nowhere on 751 and no 751 creature gives that credit. 27181 stays
-- unlinked (its giver is the hostile kill target). The INSERT also requires the quest to still be offered on 751.
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((4110181, 27096), (3645730, 27455));
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (SELECT 4110181 AS `id`, 27096 AS `quest` UNION ALL SELECT 3645730, 27455) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `quest` FROM `creature_queststarter`
      WHERE `id` IN (SELECT `id` FROM `creature` WHERE `map` = 751));

-- c) The Tyr's Hand quests of Eastern Plaguelands. Givers and turn-ins as in skyfire_world and cata_world, which
-- agree. TC_Cata_world has the givers but no turn-in rows at all for this hub (27460-27620), which is why it can
-- look as if 27461/27462 had no turn-in on 751. Commander Eligor Dawnbringer 3616115, Korfax 3616112 and Archmage
-- Angela Dosantos 3616116 stand together at about (1692, -5213); the Crusader's Flare GO 3805875 is in the same
-- zone. All are DC-only copies (source entry + 3600000), spawned only on 751, zone 4924.
--   27461 To Take the Abbey     GO 3805875 -> Eligor 3616115     no objective
--   27462 To Take the Barracks  GO 3805875 -> Korfax 3616112     no objective
--   27613 The Assassin          Eligor -> Eligor                 kill Rohan the Assassin 3646095
--   27615 The Wrathcaster       Korfax -> Korfax                 kill Mataus the Wrathcaster 3646093
--   27616 The Huntsman          Korfax -> Korfax                 kill Huntsman Leopold 3646094
--   27619 The Commander         Korfax -> Korfax                 kill Scarlet Commander Marjhan 3646092
--   27617 Befouled No More      Eligor -> Dosantos 3616116       no objective, needs one of the quests above
--   27618 Argent Upheaval       Korfax -> Dosantos 3616116       no objective; it also opens 27620 Like Rats,
--                                                                which rev_1794429413835942600.sql offers
-- The live objectives already point at the 751 copies (3646092-3646095, one spawn each), so nothing is remapped.
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3616115, 27613), (3616115, 27617));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3616112, 27615), (3616112, 27616));
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3616112, 27618), (3616112, 27619));
INSERT INTO `creature_queststarter` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (
    SELECT 3616115 AS `id`, 27613 AS `quest` UNION ALL
    SELECT 3616115, 27617 UNION ALL
    SELECT 3616112, 27615 UNION ALL
    SELECT 3616112, 27616 UNION ALL
    SELECT 3616112, 27618 UNION ALL
    SELECT 3616112, 27619
) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

DELETE FROM `gameobject_queststarter` WHERE `id` = 3805875 AND `quest` IN (27461, 27462);
INSERT INTO `gameobject_queststarter` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (SELECT 3805875 AS `id`, 27461 AS `quest` UNION ALL SELECT 3805875, 27462) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `gameobject` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3616115, 27461), (3616115, 27613), (3616112, 27462));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3616112, 27615), (3616112, 27616), (3616112, 27619));
DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3616116, 27617), (3616116, 27618));
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (
    SELECT 3616115 AS `id`, 27461 AS `quest` UNION ALL
    SELECT 3616115, 27613 UNION ALL
    SELECT 3616112, 27462 UNION ALL
    SELECT 3616112, 27615 UNION ALL
    SELECT 3616112, 27616 UNION ALL
    SELECT 3616112, 27619 UNION ALL
    SELECT 3616116, 27617 UNION ALL
    SELECT 3616116, 27618
) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

-- Level band like the rest of 751: QuestLevel -1, MinLevel = Eastern Plaguelands floor 152 - 2 (all of these
-- NPCs and the GO are in zone 4924). Only quests that no stock-map giver offers are touched.
-- Rewards are NOT rescaled here: the choices of 27613 (62966-62968) and 27619 (62969-62971) are still the Cata
-- placeholders with item level 0/23 and RequiredLevel 0/1.
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 150
WHERE `ID` IN (27461, 27462, 27613, 27615, 27616, 27617, 27618, 27619)
  AND `ID` NOT IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` IN
      (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37))
  AND `ID` NOT IN (SELECT `quest` FROM `gameobject_queststarter` WHERE `id` IN
      (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37));

-- ExclusiveGroup. cata_world and TC_Cata_world put the six Tyr's Hand tasks (27612, 27613, 27614, 27615, 27616,
-- 27619) in the positive exclusive group 27612. In AzerothCore a positive group means "only one of them, ever":
-- after the first is taken the other five disappear. That is clearly wrong for six tasks with different targets,
-- their own reward choices and their own follow-ups (Eligor's lead to 27617, Korfax's to 27618). skyfire_world
-- has ExclusiveGroup 0 with the same NextQuestID links, which in AzerothCore means "all can be done, any one of
-- them unlocks 27617"; that is used here. The pair 27617/27618 keeps the source group 27617: two parallel
-- "report to Dosantos" breadcrumbs where doing one is enough for 27620.
UPDATE `quest_template_addon` SET `ExclusiveGroup` = 0
WHERE `ID` IN (27612, 27613, 27614, 27615, 27616, 27619) AND `ExclusiveGroup` = 27612;

-- d) Two quests that only lacked their item source. The reference DBs give real loot for every chest:
-- cata_world and TC_Cata_world agree (100 %, quest item, 1 per chest); skyfire_world agrees for the quill and has
-- no loot id on the four Battered Chests. On 751 these GOs were imported with Data1 = 0, so they dropped nothing.
-- Data1 is set to the entry where it is still 0, and the loot rows are keyed by that Data1.
--   27166 Go Fletch!       9x 60850 Brownfeather Quill  GO 3805246 (34 spawns, Western Plaguelands)
--   27614 Scarlet Salvage  61959 Crimson Boar           GO 3805878
--                          61960 Lihanna's Strand       GO 3805879
--                          61961 Shroud of Uther        GO 3805880
--                          61962 Gavinrad's Sigil       GO 3805881 (one spawn each, Eastern Plaguelands)
UPDATE `gameobject_template` SET `Data1` = `entry`
WHERE `entry` IN (3805246, 3805878, 3805879, 3805880, 3805881)
  AND `type` = 3 AND `Data1` = 0
  AND `entry` IN (SELECT `id` FROM `gameobject` WHERE `map` = 751)
  AND `entry` NOT IN (SELECT `id` FROM `gameobject` WHERE `map` < 725 AND `map` <> 37);

DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805246 AND `Item` = 60850;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805878 AND `Item` = 61959;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805879 AND `Item` = 61960;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805880 AND `Item` = 61961;
DELETE FROM `gameobject_loot_template` WHERE `Entry` = 3805881 AND `Item` = 61962;
INSERT INTO `gameobject_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
    `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT `t`.`Data1`, `v`.`item`, 0, 100, 1, 1, 0, 1, 1, 'DC 751 quest item (cata_world/TC)'
FROM (
    SELECT 3805246 AS `entry`, 60850 AS `item` UNION ALL
    SELECT 3805878, 61959 UNION ALL
    SELECT 3805879, 61960 UNION ALL
    SELECT 3805880, 61961 UNION ALL
    SELECT 3805881, 61962
) AS `v`
JOIN `gameobject_template` AS `t` ON `t`.`entry` = `v`.`entry` AND `t`.`Data1` = `v`.`entry`;

-- Their givers and turn-ins (skyfire_world and cata_world agree): 27614 Korfax 3616112 -> Korfax (part of the
-- Tyr's Hand group above), 27166 Commander Ashlam Valorfist 3610838 -> Valorfist. 27166 follows 27165 Victory,
-- For Now, whose turn-in the cleanup file adds; Valorfist has the Alliance faction 123, so 27166 is Alliance-only,
-- like 27165. Levels: 27614 Eastern Plaguelands 150, 27166 Western Plaguelands 148 - 2 = 146.
DELETE FROM `creature_queststarter` WHERE (`id`, `quest`) IN ((3616112, 27614), (3610838, 27166));
INSERT INTO `creature_queststarter` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (SELECT 3616112 AS `id`, 27614 AS `quest` UNION ALL SELECT 3610838, 27166) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

DELETE FROM `creature_questender` WHERE (`id`, `quest`) IN ((3616112, 27614), (3610838, 27166));
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT `v`.`id`, `v`.`quest` FROM (SELECT 3616112 AS `id`, 27614 AS `quest` UNION ALL SELECT 3610838, 27166) AS `v`
WHERE `v`.`id` IN (SELECT `id` FROM `creature` WHERE `map` = 751)
  AND `v`.`id` NOT IN (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37)
  AND `v`.`quest` IN (SELECT `ID` FROM `quest_template`);

UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 150
WHERE `ID` = 27614
  AND `ID` NOT IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` IN
      (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37));
UPDATE `quest_template` SET `QuestLevel` = -1, `MinLevel` = 146
WHERE `ID` = 27166
  AND `ID` NOT IN (SELECT `quest` FROM `creature_queststarter` WHERE `id` IN
      (SELECT `id` FROM `creature` WHERE `map` < 725 AND `map` <> 37));

-- Verify after apply (expected values in brackets):
--   SELECT `faction` FROM `creature_template` WHERE `entry` = 3611616;                                  [2070]
--   SELECT COUNT(*) FROM `creature_questender` WHERE (`id`, `quest`) IN ((4110181, 27096), (3645730, 27455)); [2]
--   SELECT COUNT(*) FROM `creature_queststarter` WHERE `quest` IN (27613, 27614, 27615, 27616, 27617, 27618,
--     27619, 27166);                                                                                     [8]
--   SELECT COUNT(*) FROM `gameobject_queststarter` WHERE `id` = 3805875 AND `quest` IN (27461, 27462);   [2]
--   SELECT COUNT(*) FROM `creature_questender` WHERE `quest` IN (27461, 27462, 27613, 27614, 27615, 27616,
--     27617, 27618, 27619, 27166);                                                                       [10]
--   SELECT COUNT(*) FROM `quest_template` WHERE `ID` IN (27461, 27462, 27613, 27614, 27615, 27616, 27617, 27618,
--     27619, 27166) AND `QuestLevel` = -1;                                                               [10]
--   SELECT COUNT(*) FROM `gameobject_loot_template` WHERE `Comment` = 'DC 751 quest item (cata_world/TC)'; [5]
