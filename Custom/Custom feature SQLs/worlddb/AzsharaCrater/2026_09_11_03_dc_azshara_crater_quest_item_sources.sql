-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- give the collection quests an item that actually drops
-- ---------------------------------------------------------------------------
-- Completability audit 2026-09-11: the crater's collection quests asked for items
-- nothing on map 37 drops (or, for 300805, an item a player can hold only one of).
-- This file fixes every case where the quest's own text already names a creature
-- that IS spawned on the crater, so the fix is a loot row plus, where the old item
-- was a placeholder, pointing the quest at a fitting stock item.
--
--   quest   title                        needs                      drops from (map 37 spawns)
--   300107  Hides Against the Cold       8 Light Hide 783           Mangy Wolf 525 (15)
--   300207  Dust of the Fallen           10 Gold Dust 773           Dreadbone Skeleton 16303 (11)
--   300307  Beads of the Thistlefur      10 Gnoll War Beads 527     Thistlefur 3921/3922/3924/3925/3926 (30)
--   300507  Feathers of the Thunderhead  10 Undamaged Hippogryph    Thunderhead Hippogryph 6375 (5),
--                                           Feather 10450 (was 8393 Scorpok Pincer)   Thunderhead Skystormer 6378 (3)
--   300804  Relics of the Sanctum        10 Highborne Relic 5360    Skeletal Craftsman 32164 (10),
--                                           (was 3822 Runic Darkblade, a weapon)      Moonrest Highborne 26455 (2)
--   300805  Unbind the Phantoms          8 Ghostly Essence 24480    Moonrest Highborne 26455 (2)
--                                           (was 23180 Flame of Thunder Bluff, max 1 per player)
--
-- 300107 was already completable by buying hides from the crater Leather vendor;
-- the wolf drop makes it work the way its text reads.
--
-- Pre-flight, verified live:
--   * every item has an Item.dbc row (Custom/CSV DBC/Item.csv) and its display in
--     ItemDisplayInfo.csv -- an item_template row without Item.dbc is skipped at load;
--   * each creature's lootid is its own entry and no other template shares it;
--   * none of these items already sits in those loot tables (no key collisions);
--   * every drop is QuestRequired = 1, so it only drops while a player needs it.
--     Other quests that also use these items: 958 (Darkshore, lvl ~17) for 5360,
--     9825 (Ghostlands) for 24480, 3381 (no spawned giver) for 10450 -- none of
--     their players farm level 46-79 crater mobs, so nothing leaks;
--   * 527 is used by no other quest and no loot table. Its "Deprecated" name and
--     ITEM_FLAG_DEPRECATED (0x10, "cannot equip or use" -- irrelevant for a quest
--     item, but the name shows in the tooltip) are cleaned up here.
--
-- Every quest UPDATE is guarded on the old RequiredItemId1, so re-running the
-- file cannot double-apply the text REPLACE.
--
-- NOT handled here (needs a design call -- see the hand-off message):
--   300301 Ten Cursed Horns  -- Satyr Horns: no satyrs anywhere in zone 3.
--   300706 Orders in the Dark -- Cultist Orders: cultists exist, but no stackable
--                               stock "orders" item fits the Shadow Council.
--   300407 Rations from the Reef -- completable (vendor Big Bear Meat), but the text
--                               asks for Tender Crab Meat and no crab is spawned.
--
-- Apply, then restart: item_template (the 527 rename) has no .reload command.
-- `.reload creature_loot_template` + `.reload quest_template` cover everything else
-- if the rename can wait for the next restart.
-- ---------------------------------------------------------------------------

-- 300507 / 300804 / 300805: point the quests at the new items
UPDATE `quest_template`
SET `RequiredItemId1` = 10450,
    `LogDescription` = REPLACE(`LogDescription`, 'Hippogryph Feathers', 'Undamaged Hippogryph Feathers'),
    `QuestDescription` = REPLACE(`QuestDescription`, 'Hippogryph Feathers', 'Undamaged Hippogryph Feathers'),
    `QuestCompletionLog` = REPLACE(`QuestCompletionLog`, 'Hippogryph Feathers', 'Undamaged Hippogryph Feathers')
WHERE `ID` = 300507
  AND `RequiredItemId1` = 8393;

UPDATE `quest_template`
SET `RequiredItemId1` = 5360,
    `LogDescription` = 'Recover 10 Highborne Relics.',
    `QuestDescription` = 'Before the Scourge grinds this place to rubble, there is knowledge here worth saving. The Highborne scattered relics through this temple, pieces of an arcane mastery even the Kirin Tor has not fully recovered, and the risen who shamble its halls have been picking them over.$B$BCut down the dead and recover ten Highborne Relics for me, $N. Better they rest in my study than shatter beneath the boots of the Scourge. Some of these secrets we cannot afford to lose twice.',
    `QuestCompletionLog` = 'Ten Highborne Relics saved from the Scourge.'
WHERE `ID` = 300804
  AND `RequiredItemId1` = 3822;

UPDATE `quest_template`
SET `RequiredItemId1` = 24480,
    `LogDescription` = 'Collect 8 Ghostly Essences.',
    `QuestDescription` = 'The Highborne spirits drifting through the sanctum are not free, $N. Each is chained to this world by a knot of Ghostly Essence, a residue the necromancers use as a leash. So long as the essence holds, the dead cannot rest and we cannot advance.$B$BRelease the Moonrest Highborne from their chains and gather eight measures of that essence. In my hands the bindings unravel. In theirs, the dead march. It is that simple.',
    `QuestCompletionLog` = 'Eight essences gathered for unbinding.'
WHERE `ID` = 300805
  AND `RequiredItemId1` = 23180;

-- 300307: drop the "Deprecated" from the bead item the quest already uses
UPDATE `item_template`
SET `name` = 'Gnoll War Beads',
    `Flags` = `Flags` & ~16
WHERE `entry` = 527;

UPDATE `item_template_locale`
SET `Name` = 'Gnollkriegsperlen'
WHERE `ID` = 527
  AND `locale` = 'deDE';

-- Loot: all quest-required, group 0
DELETE FROM `creature_loot_template` WHERE `Entry` = 525 AND `Item` = 783;
DELETE FROM `creature_loot_template` WHERE `Entry` = 16303 AND `Item` = 773;
DELETE FROM `creature_loot_template` WHERE `Entry` IN (3921, 3922, 3924, 3925, 3926) AND `Item` = 527;
DELETE FROM `creature_loot_template` WHERE `Entry` IN (6375, 6378) AND `Item` = 10450;
DELETE FROM `creature_loot_template` WHERE `Entry` IN (32164, 26455) AND `Item` = 5360;
DELETE FROM `creature_loot_template` WHERE `Entry` = 26455 AND `Item` = 24480;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(525, 783, 0, 50, 1, 1, 0, 1, 1, 'Mangy Wolf - Light Hide (Azshara Crater quest 300107)'),
(16303, 773, 0, 60, 1, 1, 0, 1, 1, 'Dreadbone Skeleton - Gold Dust (Azshara Crater quest 300207)'),
(3921, 527, 0, 40, 1, 1, 0, 1, 1, 'Thistlefur Ursa - Gnoll War Beads (Azshara Crater quest 300307)'),
(3922, 527, 0, 40, 1, 1, 0, 1, 1, 'Thistlefur Totemic - Gnoll War Beads (Azshara Crater quest 300307)'),
(3924, 527, 0, 40, 1, 1, 0, 1, 1, 'Thistlefur Shaman - Gnoll War Beads (Azshara Crater quest 300307)'),
(3925, 527, 0, 40, 1, 1, 0, 1, 1, 'Thistlefur Avenger - Gnoll War Beads (Azshara Crater quest 300307)'),
(3926, 527, 0, 40, 1, 1, 0, 1, 1, 'Thistlefur Pathfinder - Gnoll War Beads (Azshara Crater quest 300307)'),
(6375, 10450, 0, 70, 1, 1, 0, 1, 1, 'Thunderhead Hippogryph - Undamaged Hippogryph Feather (Azshara Crater quest 300507)'),
(6378, 10450, 0, 70, 1, 1, 0, 1, 1, 'Thunderhead Skystormer - Undamaged Hippogryph Feather (Azshara Crater quest 300507)'),
(32164, 5360, 0, 40, 1, 1, 0, 1, 1, 'Skeletal Craftsman - Highborne Relic (Azshara Crater quest 300804)'),
(26455, 5360, 0, 60, 1, 1, 0, 1, 1, 'Moonrest Highborne - Highborne Relic (Azshara Crater quest 300804)'),
(26455, 24480, 0, 100, 1, 1, 0, 1, 1, 'Moonrest Highborne - Ghostly Essence (Azshara Crater quest 300805)');
