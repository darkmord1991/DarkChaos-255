-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- the three collection quests that needed a design call
-- ---------------------------------------------------------------------------
-- Decisions taken 2026-09-11:
--
-- 300301 Ten Cursed Horns / 300300 A Test of Steel  (Pathfinder Gor'nash, zone 3)
--   Zone 3 had no satyrs at all: 300301 wanted "NPC Equip 21974" (a placeholder
--   nothing drops) and 300300 targeted Forlorn Spirit 2044 (no spawn). Both now use
--   the stock Ashenvale Felmusk satyrs, which are spawned BY HAND in-game (see the
--   spawn list in the hand-off). Felmusk Satyr 3758 / Rogue 3759 / Felsworn 3762
--   already carry Satyr Horns 5481 at 80%, QuestRequired, so no loot rows are needed.
--   Felmusk are level 25-27, the lowest stock satyrs that drop horns, so both quests
--   move from level 22/24 to 26 (MinLevel 22). Both stay inside the 21-30 reward tier,
--   so their reward items do not change.
--   UNTIL THE SATYRS ARE SPAWNED both quests remain uncompletable, exactly as today.
--
-- 300706 Orders in the Dark  (Dragonbinder Seryth, zone 7)
--   New item 303144 "Cultist Orders" (clone of 29797, a plain stackable quest
--   letter, icon INV_Letter_13), dropped by Kil'sorrow Cultist 17147 (7 spawns) at
--   50%. Replaces Fertile Spores 24449, which nothing on the crater drops.
--   REQUIRES Item.dbc row 303144 -- already appended to Custom/CSV DBC/Item.csv and
--   compiled into Custom/DBCs/Item.dbc (160124 rows; +1, 0 lost, 0 changed).
--   The SERVER Item.dbc must be deployed before the worldserver restarts: without the
--   DBC row ObjectMgr::LoadItemTemplates silently discards item 303144, and the quest
--   loads pointing at an item that does not exist.
--   Shadow Council Zealot 21754 (6 spawns) is not a source: its lootid is 0, and
--   giving it one would change the stock template everywhere it spawns.
--
-- 300407 Rations from the Reef  (Wavemaster Kol'gar, zone 4)
--   Completable already (Big Bear Meat 3730 from the Cooking vendors at Thalindra's
--   camp), but the text asked for Tender Crab Meat and no crab is spawned. The text
--   now matches the item. Retitled "Rations for the Tide-Guard".
--
-- Map markers for these quests: 2026_09_11_05_dc_azshara_crater_item_quest_pois.sql.
-- Apply this file, deploy Item.dbc (server + client), restart, then spawn the satyrs
-- and run the POI file.
-- ---------------------------------------------------------------------------

-- 300300: Forlorn Spirit -> Felmusk Satyr x6 + Felmusk Rogue x4
UPDATE `quest_template`
SET `RequiredNpcOrGo1` = 3758, `RequiredNpcOrGoCount1` = 6,
    `RequiredNpcOrGo2` = 3759, `RequiredNpcOrGoCount2` = 4,
    `QuestLevel` = 26, `MinLevel` = 22,
    `LogDescription` = 'Slay 6 Felmusk Satyrs and 4 Felmusk Rogues in the woods east of the outpost.',
    `QuestDescription` = REPLACE(`QuestDescription`, 'The Haldarr satyrs den', 'The Felmusk satyrs den')
WHERE `ID` = 300300
  AND `RequiredNpcOrGo1` = 2044;

UPDATE `quest_offer_reward`
SET `RewardText` = REPLACE(`RewardText`, 'The Haldarr will feel that loss.', 'The Felmusk will feel that loss.')
WHERE `ID` = 300300;

-- 300301: placeholder item -> stock Satyr Horns (dropped by the Felmusk satyrs)
UPDATE `quest_template`
SET `RequiredItemId1` = 5481,
    `QuestLevel` = 26, `MinLevel` = 22
WHERE `ID` = 300301
  AND `RequiredItemId1` = 21974;

-- 300706: new item 303144 "Cultist Orders", cloned from 29797 through a real staging
-- table (item_template's column order matches no dump, so no hand-written column list)
DROP TABLE IF EXISTS `dc_cultist_orders_stage`;
CREATE TABLE `dc_cultist_orders_stage` LIKE `item_template`;

INSERT INTO `dc_cultist_orders_stage` SELECT * FROM `item_template` WHERE `entry` = 29797;

UPDATE `dc_cultist_orders_stage`
SET `entry` = 303144,
    `name` = 'Cultist Orders',
    `stackable` = 20,
    `description` = 'Standing orders passed down the cultist ranks.',
    `VerifiedBuild` = 0;

DELETE FROM `item_template` WHERE `entry` = 303144;
INSERT INTO `item_template` SELECT * FROM `dc_cultist_orders_stage`;

DROP TABLE `dc_cultist_orders_stage`;

UPDATE `quest_template`
SET `RequiredItemId1` = 303144
WHERE `ID` = 300706
  AND `RequiredItemId1` = 24449;

DELETE FROM `creature_loot_template` WHERE `Entry` = 17147 AND `Item` = 303144;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(17147, 303144, 0, 50, 1, 1, 0, 1, 1, 'Kil''sorrow Cultist - Cultist Orders (Azshara Crater quest 300706)');

-- 300407: text follows the item it actually asks for
UPDATE `quest_template`
SET `LogTitle` = 'Rations for the Tide-Guard',
    `LogDescription` = 'Bring 10 Big Bear Meat to Wavemaster Kol''gar.',
    `QuestDescription` = 'An army marches on its belly, $N, and mine is sick to death of salt-fish and hard bread. The crabs that once crowded these shallows are long gone, and the river gives us nothing worth the cooking.$B$BThe cooking suppliers at Scout Thalindra''s camp keep a stock of Big Bear Meat hauled in from beyond the rim. Buy me ten cuts and carry them here. Cook fires tonight, and my tide-guard eats like it earned it.',
    `QuestCompletionLog` = 'Ten cuts of Big Bear Meat gathered.'
WHERE `ID` = 300407
  AND `RequiredItemId1` = 3730;

UPDATE `quest_offer_reward`
SET `RewardText` = 'Proper red meat, and plenty of it.$B$BMy soldiers will bless your name over the cook fire tonight. Good work, $N.'
WHERE `ID` = 300407;
