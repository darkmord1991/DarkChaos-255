-- DarkChaos map 751 (2026-11-14): Eastern Plaguelands mob levels as a gradient, plus two Horde Silverpine fixes.
-- Apply AFTER the three port files rev_1794662427930924200 (750), rev_1794662456589305400 (EPL) and
-- rev_1794662597564234900 (Horde Silverpine); part 2 uses NPCs and quests that the last one creates.
--
-- PART 1 - Eastern Plaguelands (zone 4924, band 152-160)
-- Why: 1,515 of the zone's 1,880 attackable spawns were flat level 158 (12 more at 160), so a 152-153 player
-- and every bot (they attack at most 4 levels above themselves) could not hunt there.
-- Order of the sub-areas: from where the zone's Cata quests on 751 actually are (POI centroid, else the giver)
-- and the Cata mob levels there. Cata level 40-41 = entry side (Thondroril, Terrorweb Tunnel, Death's Step,
-- Marris Stead, Undercroft, Darrowshire, Crown Guard, Fungal Vale, Lake Mereldar, Infectis Scar), 42-43 =
-- middle (Corin's Crossing, Light's Shield, Pestilent Scar, Browman Mill, Noxious Glade, Tyr's Hand, Light's
-- Hope, Eastwall, Ix'lar's Domain, Northdale, Zul'Mashar, Northpass, Blackwood Lake), 44-45 = far side
-- (Terrordale, Siege Vise, Quel'Lithien Lodge, Plaguewood, Stratholme approach). Mapping 40 -> 152, 45 -> 158
-- (1.2 per Cata level), the same scale that gives the pending EPL file's 153-154 and Tyr's Hand's 153-155.
-- A normal mob's level = mean of (its Cata template level) and (the sub-areas of its 751 spawns), spread 1, or
-- 2 when its spawns cover several tiers. Rares/elites keep their old +2 over the normals around them (median
-- of the rank-0 hostiles within 150 yd after this file) but never sit below the highest of those normals: then
-- they get that level + 1 (Foreman Marcrid 154-155, Death Knight Soulbearer 157-158, Hed'mush 157-158,
-- Garginox 156-157).
-- Scope: 56 templates (43 normal, 13 rare/elite), 1282 spawns. Every one is spawned only on map 751 in zone
-- 4924, except Putrid Gargoyle / Plaguehound Runt / Plaguebat, which also have 5 border spawns tagged Western
-- Plaguelands (4932, band 148-153) at the Death's Step edge: their new 152-154 suits that zone better than 158.
-- Hostile = factiontemplate EnemyGroup & 7; also the neutral faction-7 beasts (Carrion Grub / Devourer, Plagued
-- Swine: quest mobs of 27456 / 27533 / 205544). Not touched: the 16 templates rev_1794662456589305400
-- relevels, Tyr's Hand (153-155 since 11-13), service NPCs, friendly and reputation-faction NPCs, Nathanos'
-- Blighthounds (160, with him), the unselectable Corpsebeast vehicles (27530), and Omasum Blighthoof / Karthis
-- Darkrune (already 156; the rule would raise them). Only the Soulbearer is raised (156 -> 157-158).
-- Stats: 751's 332_ model at the new minlevel (normal 2.5x player HP / 4.5% swing, rare 5x / 6%, elite 8x /
-- 7.5%, rare elite 25x / 11%); the five hand-tuned rares above their model (Bloodbane, Hed'mush, Thresh'jin,
-- Zul'Brin, Darkscythe) and Garginox keep their ratio to it. creature_classlevelstats has every class/level used.
-- Loot: templates now below 156 move their ladder reference 752218 (RequiredLevel 156 band) to 752217 (152).
-- SmartAI: only spell casts; the summons (Skeletal Servant 8477, Carrion Scarab 10699) are stock templates
-- whose level does not follow the caster. No C++ script references these entries.
-- Backup: the first run stores the old levels, modifiers and ladder reference in `dc_backup_20261114_epl_relevel`.
-- Revert part 1:
--   UPDATE `creature_template` AS `t` JOIN `dc_backup_20261114_epl_relevel` AS `b` ON `b`.`entry` = `t`.`entry`
--     SET `t`.`minlevel` = `b`.`minlevel`, `t`.`maxlevel` = `b`.`maxlevel`,
--     `t`.`HealthModifier` = `b`.`HealthModifier`, `t`.`DamageModifier` = `b`.`DamageModifier`
--   UPDATE `creature_loot_template` AS `l` JOIN `dc_backup_20261114_epl_relevel` AS `b` ON `b`.`entry` = `l`.`Entry`
--     SET `l`.`Reference` = 752218 WHERE `l`.`Reference` = 752217 AND `b`.`ladder_ref` = 752218
--   (ladder_ref = 752218 if the template had the 156-band reference before this file, else 0)
--   UPDATE `quest_template` AS `t` JOIN `dc_backup_20261114_epl_quest_minlevel` AS `b` ON `b`.`ID` = `t`.`ID`
--     SET `t`.`MinLevel` = `b`.`MinLevel`
-- Quests: nine EPL quests at MinLevel 150 had their easiest kill target more than 4 levels up after this
-- relevel (bots attack at most +4): 27477, 27479, 27521, 27522, 27525, 27533, 206133, 206136 -> 152 (targets
-- 155-156), 27530 The Corpsebeasts -> 154 (its unselectable Corpsebeasts stay 158). Old values in
-- `dc_backup_20261114_epl_quest_minlevel`.
--
-- PART 2 - Horde Silverpine Forest (zone 4935)
-- a) Breadcrumb 751390 The Forsaken Front: Grand Executor Mortuus (Forsaken High Command, where the Tirisfal
--    hand-offs 26964 / 28568 end) -> Lady Sylvanas at the Forsaken Front (4145617). The Forsaken Front chain
--    (27472 / 27474 / 27542) has no prerequisite here, but the only quest that leads to it is 27438 The Great
--    Escape, which starts in Gilneas; the Sepulcher's 27290 is the Gilneas route. Breadcrumb for 27472, hidden
--    once 27290 or 27438 is taken, complete or rewarded (those players reach the Front through Gilneas).
--    Horde mask 1237320626 as on the chain it leads into (690 plus goblin and DC's Horde races).
-- b) MinLevel 132 -> 134 on the 14 older Horde Silverpine quests (QuestSortID 130), the same for Dalar
--    Dawnweaver's 27478 / 27483 (Silverpine, QuestSortID 36; 27478 sits between 27476 and 27484, both 134), and
--    26964 Warchief's Command: Silverpine Forest! (Executor Zygand, Brill) 128 -> 134: it is Tirisfal's hand-off to
--    Mortuus and would otherwise send a 128-133 player to a hub with nothing to take.
--    Revert: 27478, 27483 and the 14 back to 132, 26964 back to 128.
--
-- Re-runnable: the backups keep their first values, every row block is deleted and re-inserted, UPDATEs are
-- absolute or guarded on the old value. Apply to acore_world, then restart the worldserver.

-- 1. Eastern Plaguelands
CREATE TABLE IF NOT EXISTS `dc_backup_20261114_epl_relevel` (
    `entry` INT UNSIGNED NOT NULL,
    `minlevel` TINYINT UNSIGNED NOT NULL,
    `maxlevel` TINYINT UNSIGNED NOT NULL,
    `HealthModifier` FLOAT NOT NULL,
    `DamageModifier` FLOAT NOT NULL,
    `ladder_ref` INT UNSIGNED NOT NULL,
    `captured_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- First run only: INSERT IGNORE keeps the originals on a re-run (the DELETE removes nothing; codestyle)
DELETE FROM `dc_backup_20261114_epl_relevel` WHERE `entry` = 0;
INSERT IGNORE INTO `dc_backup_20261114_epl_relevel` (`entry`, `minlevel`, `maxlevel`, `HealthModifier`,
    `DamageModifier`, `ladder_ref`)
SELECT `t`.`entry`, `t`.`minlevel`, `t`.`maxlevel`, `t`.`HealthModifier`, `t`.`DamageModifier`,
    IF(EXISTS (SELECT 1 FROM `creature_loot_template` AS `l` WHERE `l`.`Entry` = `t`.`entry`
        AND `l`.`Reference` = 752218), 752218, 0)
FROM `creature_template` AS `t`
WHERE `t`.`entry` IN (3601843, 3601844, 3608521, 3608522, 3608523, 3608524, 3608527, 3608530, 3608534, 3608535,
    3608540, 3608544, 3608546, 3608547, 3608550, 3608553, 3608555, 3608556, 3608557, 3608558, 3608560, 3608561,
    3608562, 3608563, 3608564, 3608565, 3608596, 3608597, 3608598, 3608600, 3608601, 3608602, 3608603, 3608605,
    3608607, 3610818, 3610819, 3610821, 3610822, 3610823, 3610824, 3610825, 3610826, 3610827, 3610940, 3611290,
    3611291, 3611896, 3611897, 3612250, 3612261, 3612322, 3616117, 3616184, 3617878, 3645681);

-- new levels and the 332_ stats at the new minlevel (only where every spawn is on 751 in EPL)
-- Crypt Horror, Crypt Slayer, Ghost of the Past, Mossflayer Zombie, Unliving Mossflayer
UPDATE `creature_template` SET `minlevel` = 152, `maxlevel` = 153, `HealthModifier` = 0.9104, `DamageModifier` = 0.7919
WHERE `entry` IN (3608557, 3608558, 3610940, 3611290, 3611291)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Plaguehound Runt, Plaguebat
UPDATE `creature_template` SET `minlevel` = 152, `maxlevel` = 153, `HealthModifier` = 0.9104, `DamageModifier` = 0.7919
WHERE `entry` IN (3608596, 3608600)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` NOT IN (4924, 4932));
-- Putrid Gargoyle
UPDATE `creature_template` SET `minlevel` = 152, `maxlevel` = 154, `HealthModifier` = 0.9104, `DamageModifier` = 0.7919
WHERE `entry` IN (3608534)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` NOT IN (4924, 4932));
-- Crypt Stalker, Crypt Walker
UPDATE `creature_template` SET `minlevel` = 152, `maxlevel` = 154, `HealthModifier` = 0.9104, `DamageModifier` = 0.7919
WHERE `entry` IN (3608555, 3608556)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Dark Adept, Plaguehound, Carrion Grub, Zaeldarr the Outcast
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `HealthModifier` = 0.9106, `DamageModifier` = 0.793
WHERE `entry` IN (3608546, 3608597, 3608603, 3612250)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Shadowmage
UPDATE `creature_template` SET `minlevel` = 153, `maxlevel` = 154, `HealthModifier` = 1.1365, `DamageModifier` = 0.7811
WHERE `entry` IN (3608550)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Blighted Horror, Plague Monstrosity, Frenzied Plaguehound, Noxious Plaguebat, Rotting Sludge, Duskwing
UPDATE `creature_template` SET `minlevel` = 154, `maxlevel` = 155, `HealthModifier` = 0.9107, `DamageModifier` = 0.7941
WHERE `entry` IN (3608521, 3608522, 3608598, 3608601, 3608607, 3611897)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Foreman Marcrid
UPDATE `creature_template` SET `minlevel` = 154, `maxlevel` = 155, `HealthModifier` = 1.8215, `DamageModifier` = 1.0386
WHERE `entry` IN (3601844)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Mossflayer Cannibal
UPDATE `creature_template` SET `minlevel` = 155, `maxlevel` = 156, `HealthModifier` = 0.9109, `DamageModifier` = 0.7799
WHERE `entry` IN (3608562)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Scourge Guard, Torn Screamer, Gangled Golem, Mossflayer Scout, Mossflayer Shadowhunter, Borelgore, Infected
-- Mossflayer
UPDATE `creature_template` SET `minlevel` = 155, `maxlevel` = 156, `HealthModifier` = 0.9109, `DamageModifier` = 0.7951
WHERE `entry` IN (3608527, 3608540, 3608544, 3608560, 3608561, 3611896, 3612261)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Deathspeaker Selendre
UPDATE `creature_template` SET `minlevel` = 156, `maxlevel` = 156, `HealthModifier` = 2.274, `DamageModifier` = 1.0442
WHERE `entry` IN (3610827)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Foreman Jerris, Nerubian Overseer
UPDATE `creature_template` SET `minlevel` = 156, `maxlevel` = 156, `HealthModifier` = 9.1101, `DamageModifier` = 1.9462
WHERE `entry` IN (3601843, 3616184)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Quel'Lithien Protector
UPDATE `creature_template` SET `minlevel` = 156, `maxlevel` = 157, `HealthModifier` = 0.911, `DamageModifier` = 0.7809
WHERE `entry` IN (3612322)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Scourge Soldier, Cannibal Ghoul, Putrid Shrieker, Woodsman, Ranger, Pathstrider, Monstrous Plaguebat, Carrion
-- Devourer, Plagued Swine, Scourge Siege Engineer
UPDATE `creature_template` SET `minlevel` = 156, `maxlevel` = 157, `HealthModifier` = 0.911, `DamageModifier` = 0.7962
WHERE `entry` IN (3608523, 3608530, 3608535, 3608563, 3608564, 3608565, 3608602, 3608605, 3616117, 3617878)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Cursed Mage
UPDATE `creature_template` SET `minlevel` = 156, `maxlevel` = 157, `HealthModifier` = 1.137, `DamageModifier` = 0.7832
WHERE `entry` IN (3608524)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Garginox
UPDATE `creature_template` SET `minlevel` = 156, `maxlevel` = 157, `HealthModifier` = 14.9956, `DamageModifier` = 0.6635
WHERE `entry` IN (3645681)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Gish the Unmoving
UPDATE `creature_template` SET `minlevel` = 157, `maxlevel` = 157, `HealthModifier` = 1.8223, `DamageModifier` = 1.0629
WHERE `entry` IN (3610825)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Death Cultist
UPDATE `creature_template` SET `minlevel` = 157, `maxlevel` = 158, `HealthModifier` = 0.9111, `DamageModifier` = 0.7818
WHERE `entry` IN (3608547)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Necromancer
UPDATE `creature_template` SET `minlevel` = 157, `maxlevel` = 158, `HealthModifier` = 1.1372, `DamageModifier` = 0.7839
WHERE `entry` IN (3608553)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Death Knight Soulbearer
UPDATE `creature_template` SET `minlevel` = 157, `maxlevel` = 158, `HealthModifier` = 1.8223, `DamageModifier` = 1.0424
WHERE `entry` IN (3610818)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Hed'mush the Rotting
UPDATE `creature_template` SET `minlevel` = 157, `maxlevel` = 158, `HealthModifier` = 6.5708, `DamageModifier` = 0.4983
WHERE `entry` IN (3610821)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Warlord Thresh'jin
UPDATE `creature_template` SET `minlevel` = 158, `maxlevel` = 158, `HealthModifier` = 6.5718, `DamageModifier` = 0.4989
WHERE `entry` IN (3610822)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Zul'Brin Warpbranch
UPDATE `creature_template` SET `minlevel` = 158, `maxlevel` = 158, `HealthModifier` = 7.7768, `DamageModifier` = 0.4903
WHERE `entry` IN (3610823)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Ranger Lord Hawkspear
UPDATE `creature_template` SET `minlevel` = 159, `maxlevel` = 159, `HealthModifier` = 1.8228, `DamageModifier` = 1.0656
WHERE `entry` IN (3610824)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);
-- Baron Bloodbane, Lord Darkscythe
UPDATE `creature_template` SET `minlevel` = 159, `maxlevel` = 159, `HealthModifier` = 6.5727, `DamageModifier` = 0.4995
WHERE `entry` IN (3610819, 3610826)
  AND `entry` NOT IN (SELECT `id` FROM `creature` WHERE `map` <> 751 OR `zoneId` <> 4924);

-- gear drop: below 156 the 152 ladder band (752217) instead of the 156 band (752218), chance unchanged
UPDATE `creature_loot_template` SET `Reference` = 752217
WHERE `Entry` IN (3601844, 3608521, 3608522, 3608527, 3608534, 3608540, 3608544, 3608546, 3608550, 3608555, 3608556,
    3608557, 3608558, 3608560, 3608561, 3608562, 3608596, 3608597, 3608598, 3608600, 3608601, 3608603, 3608607,
    3610940, 3611290, 3611291, 3611896, 3611897, 3612250, 3612261)
  AND `Reference` = 752218;

-- quests whose easiest target would sit more than 4 levels above their MinLevel
CREATE TABLE IF NOT EXISTS `dc_backup_20261114_epl_quest_minlevel` (
    `ID` INT UNSIGNED NOT NULL,
    `MinLevel` INT NOT NULL,
    `captured_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELETE FROM `dc_backup_20261114_epl_quest_minlevel` WHERE `ID` = 0;
INSERT IGNORE INTO `dc_backup_20261114_epl_quest_minlevel` (`ID`, `MinLevel`)
SELECT `ID`, `MinLevel` FROM `quest_template` WHERE `ID` IN (27477, 27479, 27521, 27522, 27525, 27533, 206133, 206136,
    27530);
UPDATE `quest_template` SET `MinLevel` = 152 WHERE `ID` IN (27477, 27479, 27521, 27522, 27525, 27533, 206133, 206136)
  AND `MinLevel` = 150;
UPDATE `quest_template` SET `MinLevel` = 154 WHERE `ID` = 27530 AND `MinLevel` = 150;

-- 2a. Breadcrumb 751390 The Forsaken Front (Mortuus -> Sylvanas at the Forsaken Front)
-- quest_template rows are never deleted (codestyle), so REPLACE
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `RewardXPDifficulty`,
    `RewardMoney`, `Flags`, `POIContinent`, `POIx`, `POIy`, `RewardFactionID1`, `RewardFactionValue1`,
    `AllowableRaces`, `VerifiedBuild`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`)
SELECT 751390, 2, -1, 134, 4935, 2, 30825, 8, 751, -153.32, 1270.27, 68, 3, 1237320626, 0,
    'The Forsaken Front',
    'Report to Lady Sylvanas Windrunner at the Forsaken Front in southern Silverpine Forest.',
    CONCAT(
        'Not every soldier of the Forsaken is needed behind the Greymane Wall, $c. Some of us have work ',
        'closer to home.$B$BOur Dark Lady has taken the war south herself. The Forsaken Front stands in the ',
        'shadow of Shadowfang Keep, and the Alliance has dug in at Ambermill and along the road beyond. ',
        'Every blade we send there is one less grave we must dig for our own.$B$BTake the south road past ',
        'the Sepulcher. Lady Sylvanas is expecting you, and she does not like to wait.'),
    'Report to Lady Sylvanas Windrunner at the Forsaken Front in Silverpine Forest.';

DELETE FROM `quest_template_addon` WHERE `ID` = 751390;
INSERT INTO `quest_template_addon` (`ID`, `BreadcrumbForQuestId`) VALUES (751390, 27472);

DELETE FROM `quest_offer_reward` WHERE `ID` = 751390;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `RewardText`, `VerifiedBuild`)
SELECT 751390, 1,
    CONCAT(
        'Mortuus sends me another. Good.$B$BLet the others chase worgen through the ruins of Gilneas. The ',
        'battle that decides this forest is fought here, $N, and I intend to win it.'), 0;

DELETE FROM `creature_queststarter` WHERE `id` = 4144615 AND `quest` = 751390;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (4144615, 751390);
-- the Forsaken Front Sylvanas comes from rev_1794662597564234900: no row if that file is not applied yet
DELETE FROM `creature_questender` WHERE `id` = 4145617 AND `quest` = 751390;
INSERT INTO `creature_questender` (`id`, `quest`)
SELECT 4145617, 751390 FROM `creature_template` WHERE `entry` = 4145617;

-- not offered to players on the Gilneas route: 27290 or 27438 in the log, complete or rewarded (state mask 74)
DELETE FROM `conditions` WHERE `SourceTypeOrReferenceId` = 19 AND `SourceGroup` = 0 AND `SourceEntry` = 751390;
INSERT INTO `conditions` (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`,
    `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`,
    `NegativeCondition`, `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`) VALUES
(19, 0, 751390, 0, 0, 47, 0, 27290, 74, 0, 1, 0, 0, '', 'The Forsaken Front: not on the Gilneas route (27290)'),
(19, 0, 751390, 0, 0, 47, 0, 27438, 74, 0, 1, 0, 0, '', 'The Forsaken Front: not on the Gilneas route (27438)');

-- turn-in marker on the Forsaken Front Sylvanas (world map area 1270, as the chain's POIs)
DELETE FROM `quest_poi` WHERE `QuestID` = 751390;
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(751390, 0, -1, 751, 1270, 0, 0, 1, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 751390;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(751390, 0, 0, -153, 1270, 0);

-- 2b. Silverpine opens at 134 for Horde, together with the pending Forsaken quests
UPDATE `quest_template` SET `MinLevel` = 134 WHERE `ID` IN (26965, 26989, 27069, 27073, 27082, 27088, 27093, 27094,
    27095, 27096, 27226, 27231, 27232, 28568)
  AND `MinLevel` = 132;
UPDATE `quest_template` SET `MinLevel` = 134 WHERE `ID` IN (27478, 27483) AND `MinLevel` = 132;
UPDATE `quest_template` SET `MinLevel` = 134 WHERE `ID` = 26964 AND `MinLevel` = 128;

-- Verify after apply (expected values in brackets):
--   SELECT COUNT(*) FROM `dc_backup_20261114_epl_relevel`;                                                [56]
--   SELECT COUNT(*) FROM `quest_template` WHERE `ID` IN (27477, 27479, 27521, 27522, 27525, 27533, 206133,
--     206136) AND `MinLevel` = 152;                                                                     [8]
--   SELECT COUNT(*) FROM `dc_backup_20261114_epl_relevel` AS `b`
--     JOIN `creature_template` AS `t` ON `t`.`entry` = `b`.`entry` WHERE `t`.`minlevel` = `b`.`minlevel`; [0]
--   SELECT COUNT(*) FROM `creature` AS `c` JOIN `creature_template` AS `t` ON `t`.`entry` = `c`.`id`
--     WHERE `c`.`map` = 751 AND `c`.`zoneId` = 4924 AND `t`.`rank` = 0 AND `t`.`minlevel` = 158
--     AND `t`.`faction` IN (14, 16, 21, 37, 91, 1576);                                                  [0]
--   SELECT COUNT(*) FROM `creature_queststarter` WHERE `quest` = 751390;                                   [1]
--   SELECT COUNT(*) FROM `creature_questender` WHERE `quest` = 751390;                                     [1]
--   SELECT COUNT(*) FROM `quest_template` WHERE `MinLevel` = 132 AND `QuestSortID` IN (130, 36);         [1]
--     (27480 Ley Energies: no giver on 751, left alone)
