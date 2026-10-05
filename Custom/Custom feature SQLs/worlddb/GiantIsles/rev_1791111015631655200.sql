-- Isles of Giants: the classic Temple of Atal'Hakkar quests on the island temple at level 80 (2026-10-04).
-- Given at the temple entrance by Sentinel Liriel (400526, Alliance) and Shadow Priest Mokra (400527, Horde); the quests
-- for both factions sit on both. Texts follow the stock quests, rewritten for the island (the stock ones send the
-- player to Fel'Zerul, Brohann, Marvon or Un'Goro); the level-50 reward items became gold like the DC temple quests.
--   82016 Jammal'an the Prophet (1446)       Head of Jammal'an from Jammal'an the Eternal
--   82017 The Essence of Eranikus (3373)    the Shade's essence into the Essence Font (148512) in his lair
--   82018 Into the Depths (3446)            the Atal'ai Stone Circle into the Altar of Hakkar (700028)
--   82019 Secret of the Circle (3447)       solve the statue circle; ends at the Idol of Hakkar (148838)
--   82020 The Temple of Atal'Hakkar (1445)  Horde: 20 Fetishes of Hakkar from the Atal'ai
--   82021 Into The Temple of Atal'Hakkar (1475)  Alliance: 10 Atal'ai Tablets from the island temple's tablets
--   82022/82023 Haze of Evil (4143 / 4146 Zapper Fuel)  5 Atal'ai Haze from the lurkers, worms and oozes
-- Not ported: The God Hakkar (the copy's ritual needs no egg, and 82011/82013 at the same NPCs already send players
-- after the Avatar), the level-52 class quests (they continue class chains that start elsewhere), the level-60
-- Eranikus, Tyrant of the Dream (Ahn'Qiraj prelude) and the unused placeholder 2868.
-- The 14 island tablets (700036, decoration) become the stock quest tablet 37099 (loot 3626 = Atal'ai Tablet, only
-- for players who need it). Five clones that shared a stock loot table get their own copy before the quest drop is
-- added, so the drops cannot leak to the Northrend creatures on those tables.

DELETE FROM `quest_template` WHERE `ID` BETWEEN 82016 AND 82023;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `StartItem`, `Flags`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`, `RequiredItemId1`, `RequiredItemCount1`, `VerifiedBuild`) VALUES
(82016, 2, 80, 80, 5006, 81, 5, 5, 250000, 0, 8, 0, 'Jammal''an the Prophet', 'Bring the Head of Jammal''an to the temple entrance on the Isles of Giants.', 'The Atal''ai have a prophet again, $c. Jammal''an has risen in the depths of this temple, preaching the same doom he preached in the Swamp of Sorrows: that Hakkar''s return will grant his tribe immortality.$b$bAn exile of his own people once warned us that the prophecy was nothing but manipulation. It cost the Atal''ai their temple then. Here it will cost this island everything.$b$bGo down into the temple and end Jammal''an. Bring me his head.', 'Return to the temple entrance on the Isles of Giants.', 6212, 1, 0),
(82017, 2, 80, 80, 5006, 81, 5, 5, 200000, 0, 8, 0, 'The Essence of Eranikus', 'Recover the Essence of Eranikus from the Ancient Shade of Eranikus and place it in the Essence Font in his lair.', 'Something old and green stirs in the deepest halls of the temple. Eranikus of the Green Dragonflight was charged with keeping the Atal''ai from ever bringing forth their god again. He failed, and the Nightmare took him.$b$bWhat lingers below is a shade, a tortured echo of the dragon he was. If he falls, $n, he will leave behind a gem holding part of his essence. Take it to the Essence Font in his lair. The green dragons built it to cleanse their own - perhaps it can still grant him rest.', 'Place the Essence of Eranikus in the Essence Font in Eranikus'' lair.', 10454, 1, 0),
(82018, 2, 80, 80, 5006, 81, 5, 5, 120000, 10466, 8, 0, 'Into the Depths', 'Bring the Atal''ai Stone Circle to the Altar of Hakkar deep in the Temple of Atal''Hakkar.', 'The scouts who went down before you found a circular room deep in the temple: six balconies, a serpent statue on the edge of each, and at the base of the room an altar to Hakkar.$b$bOne of them pushed a statue and nearly died for it - the statues are trapped. But the altar has a depression in its side, just the size of this stone circle.$b$bTake it down to the Altar of Hakkar, $n. Whatever the Atal''ai sealed in that room, this is the key.', 'Place the Atal''ai Stone Circle in the Altar of Hakkar.', 10466, 1, 0),
(82019, 2, 80, 80, 5006, 81, 5, 5, 200000, 0, 8, 0, 'Secret of the Circle', 'Discover the secret hidden in the circle of statues in the Temple of Atal''Hakkar.', 'The circle of statues in the temple is dangerous, but I believe it holds the secret to an even greater treasure.$B$BFrom the Altar of Hakkar, the scouts saw a series of lights move across the statues. If you can uncover what those lights mean, you may be able to unlock whatever the Atal''ai hid in that room.$B$BI warn you though, $N. Great evil lies in the temple. Anything of value down there will be fervently guarded.', 'Find the treasure hidden in the circle of statues.', 0, 0, 0),
(82020, 2, 80, 80, 5006, 81, 5, 5, 150000, 0, 8, 29361330, 'The Temple of Atal''Hakkar', 'Collect 20 Fetishes of Hakkar and bring them to Shadow Priest Mokra at the temple entrance.', 'Jammal''an''s prophecy has found new ears on this island. He swears that once Hakkar returns from the Nether, the Blood God will grant the Atal''ai immortality. Foolish trickery to bring about a premature doomsday, if you ask me.$b$bBut the Atal''ai carry enchanted fetishes, and those concern me greatly. If they are the key to the ritual that sank the first temple, the Horde must understand their power before the trolls use it again.$b$bGo into the temple and seize the fetishes!', 'Return to Shadow Priest Mokra at the temple entrance on the Isles of Giants.', 6181, 20, 0),
(82021, 2, 80, 80, 5006, 81, 5, 5, 150000, 0, 8, 102763597, 'Into The Temple of Atal''Hakkar', 'Gather 10 Atal''ai Tablets for Sentinel Liriel at the temple entrance.', 'According to legend, the Temple of Atal''Hakkar is a holy shrine to Hakkar the Soulflayer, kept by a vicious tribe of trolls named the Atal''ai. The first temple sank beneath the Pool of Tears - and now another has risen here, on the Isles of Giants.$b$bThe Explorers'' League will want to know how. The Atal''ai carved their rites into stone tablets, and some of them still lie intact around the temple grounds. Gather them for me, $n, before the trolls carry them below.', 'Return to Sentinel Liriel at the temple entrance on the Isles of Giants.', 6288, 10, 0),
(82022, 2, 80, 80, 5006, 81, 5, 5, 90000, 0, 8, 102763597, 'Haze of Evil', 'Collect 5 samples of Atal''ai Haze for Sentinel Liriel at the temple entrance.', 'There is a haze in the temple''s lower halls, $N. The deep lurkers, murk worms and oozes down there are soaked in it, and it is spreading - the island''s beasts that drink near the temple come back wrong.$B$BAtal''ai haze is horrid stuff and hard to collect, but the druids of Darnassus will want to know what the trolls are brewing down there. Bring me five samples.', 'Return to Sentinel Liriel at the temple entrance on the Isles of Giants.', 11318, 5, 0),
(82023, 2, 80, 80, 5006, 81, 5, 5, 90000, 0, 8, 29361330, 'Haze of Evil', 'Collect 5 samples of Atal''ai Haze for Shadow Priest Mokra at the temple entrance.', 'The Atal''ai brew a haze in the depths of their temple. The deep lurkers, murk worms and oozes down there are full of it. The trolls use it to bend lesser creatures to their will - and the apothecaries of the Undercity would pay dearly to learn how.$B$BBring me five samples of the haze, $N. Try not to breathe it in.', 'Return to Shadow Priest Mokra at the temple entrance on the Isles of Giants.', 11318, 5, 0);

DELETE FROM `quest_offer_reward` WHERE `ID` BETWEEN 82016 AND 82023;
INSERT INTO `quest_offer_reward` (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`, `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`, `RewardText`, `VerifiedBuild`) VALUES
(82016, 1, 0, 0, 0, 0, 0, 0, 0, 'So the prophet is silenced at last.$b$bHis reckless trust in false visions led his people to their doom once already, $n. You have spared this island the same fate.', 0),
(82017, 1, 0, 0, 0, 0, 0, 0, 0, 'You place the gem inside the essence font.$B$B"Thank you mortal, you have - no... this, this cannot be! No! The corruption of this accursed god even taints the sanctity of a Green Dragonflight essence font! No please, I feel my essence ripping from me! THE PAIN! I feel the grip of an eternal nightmare taking hold on me..."$B$B"Mortal, I implore you! Find one of the Green Dragonflight to stop this... help me... I am chained in darkness... forever in agony..."', 0),
(82018, 1, 0, 0, 0, 0, 0, 0, 0, 'You push the stone circle into the opening, and you hear it lock into place.$b$bNow that the stone is in place, you may continue... but what should you do next?$b$bPerhaps you should examine this altar further...', 0),
(82019, 1, 0, 0, 0, 0, 0, 0, 0, 'The eye of the idol glitters brightly even in the half-darkness of the temple. Its transparency reveals something shiny behind it. Sliding it to the side, you reach in and grasp what lies inside the statue.$B$BThe Atal''ai treasure is now yours.', 0),
(82020, 1, 0, 0, 0, 0, 0, 0, 0, 'Brave $c, you have proven yourself a great champion of the Horde.$b$bNow this collection of fetishes of Hakkar must be dealt with at once!', 0),
(82021, 1, 0, 0, 0, 0, 0, 0, 0, 'The Atal''ai Tablets! Thank you, $N!$B$BThe Explorers'' League will have these read before the week is out. Whatever the Atal''ai are planning here, we will know it before they do.', 0),
(82022, 1, 0, 0, 0, 0, 0, 0, 0, 'I admit, I''m a bit hesitant to touch that stuff, $N! But the druids will know what to make of it. Thank you.', 0),
(82023, 1, 0, 0, 0, 0, 0, 0, 0, 'Good. The apothecaries will be pleased.$B$BKeep your distance from the vials - I would hate to lose a useful ally to a sample.', 0);

DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 82016 AND 82023;
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(82016, 1, 1, 'Jammal''an still preaches? Every hour he lives, more of the Atal''ai answer his call.', 0),
(82017, 1, 1, 'As you near the essence font, the voice of Eranikus touches your mind.$B$B"Yes mortal, this essence font will redeem what untainted element of my psyche remains imbued in this gem. Place the gem inside the font, and let the magic of the Green Dragonflight cleanse the corruption and taint from my being. Only then will I find true release."', 0),
(82018, 1, 1, 'Upon examining the altar, you notice a depression in its side, just the size of the stone circle you carry...', 0),
(82020, 1, 1, 'If the Atal''ai fetishes hold the power to summon Hakkar and fulfill Jammal''an''s prophecy, they must be seized. Such powers must be understood by the Horde!', 0),
(82021, 1, 1, 'Have you found the tablets, $N? Every one we leave out there is one the Atal''ai can use.', 0),
(82022, 1, 1, 'Careful with that haze, $N. I would rather not touch it myself.', 0),
(82023, 1, 1, 'This haze could be a weapon in the right hands, $N. Ours.', 0);

DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 82016 AND 82023;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(400526, 82016),
(400527, 82016),
(400526, 82017),
(400527, 82017),
(400526, 82018),
(400527, 82018),
(400526, 82019),
(400527, 82019),
(400527, 82020),
(400526, 82021),
(400526, 82022),
(400527, 82023);

DELETE FROM `creature_questender` WHERE `quest` BETWEEN 82016 AND 82023;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(400526, 82016),
(400527, 82016),
(400527, 82020),
(400526, 82021),
(400526, 82022),
(400527, 82023);

DELETE FROM `gameobject_questender` WHERE `quest` BETWEEN 82016 AND 82023;
INSERT INTO `gameobject_questender` (`id`, `quest`) VALUES
(148512, 82017),
(700028, 82018),
(148838, 82019);

-- own loot tables for the clones that used a shared stock one (copied as they are)
DELETE FROM `creature_loot_template` WHERE `Entry` = 400532;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 400532, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `creature_loot_template` WHERE `Entry` = 26672;
DELETE FROM `creature_loot_template` WHERE `Entry` = 400533;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 400533, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `creature_loot_template` WHERE `Entry` = 28583;
DELETE FROM `creature_loot_template` WHERE `Entry` = 400534;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 400534, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `creature_loot_template` WHERE `Entry` = 28368;
DELETE FROM `creature_loot_template` WHERE `Entry` = 400535;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 400535, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `creature_loot_template` WHERE `Entry` = 28368;
DELETE FROM `creature_loot_template` WHERE `Entry` = 400549;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT 400549, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`
FROM `creature_loot_template` WHERE `Entry` = 28583;
UPDATE `creature_template` SET `lootid` = `entry` WHERE `entry` IN (400532, 400533, 400534, 400535, 400549);

-- the quest drops (only for players who need the item)
DELETE FROM `creature_loot_template` WHERE `Entry` IN (400500, 400501, 400502, 400503, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521, 400523, 400530, 400531, 400541, 400562, 400563, 400564, 400568, 400569, 400570, 400571) AND `Item` IN (6181, 6212, 10454, 11318);
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400500, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400501, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400502, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400503, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400504, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400505, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400510, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400511, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400512, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400513, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400520, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400521, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400521, 6212, 0, 100, 1, 1, 0, 1, 1, 'Head of Jammal''an (quest 82016)'),
(400523, 10454, 0, 100, 1, 1, 0, 1, 1, 'Essence of Eranikus (quest 82017)'),
(400530, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400531, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400532, 11318, 0, 100, 1, 1, 0, 1, 1, 'Atal''ai Haze (quests 82022/82023)'),
(400533, 11318, 0, 100, 1, 1, 0, 1, 1, 'Atal''ai Haze (quests 82022/82023)'),
(400534, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400535, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400541, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400549, 11318, 0, 100, 1, 1, 0, 1, 1, 'Atal''ai Haze (quests 82022/82023)'),
(400562, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400563, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400564, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400568, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400569, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400570, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)'),
(400571, 6181, 0, 80, 1, 1, 0, 1, 1, 'Fetish of Hakkar (quest 82020)');

-- the island temple's Atal'ai Tablets become the stock quest tablet
UPDATE `gameobject` SET `id` = 37099 WHERE `id` = 700036 AND `guid` BETWEEN 9005451 AND 9005464;
