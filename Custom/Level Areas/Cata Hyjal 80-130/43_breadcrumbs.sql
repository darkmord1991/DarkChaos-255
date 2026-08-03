-- ---------------------------------------------------------------------------
-- 43  Breadcrumbs: Azshara Crater -> faction starts -> band-to-band chain
-- ---------------------------------------------------------------------------
-- Azshara Crater (1-80) has never handed off to the 80-130 continent, and the
-- new bands need signposts at each edge. Eight report-to quests from the
-- reserved 81300 block (kill-free, so no new creatures or objectives):
--
--   81300  Sails to Lor'danel            A    78   Thadeus (map 37) -> Kyteran
--   81301  The Bilgewater Expedition     H    78   Thadeus (map 37) -> Mixi
--   81310  Into Ashenvale                A    85   Kyteran -> Kimlya (Astranaar)
--   81311  Orders from Splintertree     H    85   Mixi -> Kaylisk (Splintertree)
--   81312  North to Felwood            both   93   Kimlya + Kaylisk -> Gorrim
--   81313  The Frozen Reaches          both  101   Gorrim -> Vizzie (Everlook)
--   81314  The Sacred Mountain         both  110   Vizzie -> Sebelia (Nordrassil)
--   81315  Moonglade Respite (flavor)  both   93   Gorrim -> Keeper Remulos
--
-- All QuestLevel = -1 (XP scales to the player -- QuestXP.dbc reaches 255) with
-- MinLevel = band start - 2, matching 234_'s convention. AllowableRaces uses
-- the live vocabulary: Alliance 2098253, Horde 946, both 0. No PrevQuestID --
-- players entering by teleporter (not from Azshara Crater) must not be locked
-- out. Reward: flat 10g + a mid RewardXPDifficulty tier.
--
-- The ender/starter NPCs are native innkeepers/FMs that lack the questgiver
-- bit -- section 3 ORs it on (npcflag | 2), idempotent.
--
-- Run AFTER HyjalCata 231_-234_ and 40_. Idempotent (DELETE + INSERT).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. the quests
-- ---------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` BETWEEN 81300 AND 81315;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`,
    `RewardXPDifficulty`, `RewardMoney`, `AllowableRaces`, `Flags`,
    `LogTitle`, `LogDescription`, `QuestDescription`, `QuestCompletionLog`) VALUES
(81300, 2, -1,  78, 4929, 4, 100000, 2098253, 8,
 'Sails to Lor''danel',
 'Report to Innkeeper Kyteran at Lor''danel in Darkshore.',
 'Your training in the crater is complete. The Guardians of Hyjal call every able hand to the northern front. Take the teleporter to Lor''danel on the Darkshore coast -- Innkeeper Kyteran will see you settled.',
 'Report to Innkeeper Kyteran at Lor''danel.'),
(81301, 2, -1,  78, 4930, 4, 100000, 946, 8,
 'The Bilgewater Expedition',
 'Report to Innkeeper Mixi at Bilgewater Harbor in Azshara.',
 'Your training in the crater is complete. The Bilgewater Cartel pays well for capable muscle in Azshara. Take the teleporter to Bilgewater Harbor -- Innkeeper Mixi keeps the ledger.',
 'Report to Innkeeper Mixi at Bilgewater Harbor.'),
(81310, 2, -1,  85, 4931, 4, 100000, 2098253, 8,
 'Into Ashenvale',
 'Report to Innkeeper Kimlya at Astranaar in Ashenvale.',
 'Darkshore is holding. The fight has moved south into Ashenvale, and Astranaar needs every blade. Travel south and report to Innkeeper Kimlya.',
 'Report to Innkeeper Kimlya at Astranaar.'),
(81311, 2, -1,  85, 4931, 4, 100000, 946, 8,
 'Orders from Splintertree',
 'Report to Innkeeper Kaylisk at Splintertree Post in Ashenvale.',
 'Azshara runs itself now. Splintertree Post is screaming for reinforcements against the Alliance push. Head west into Ashenvale and report to Innkeeper Kaylisk.',
 'Report to Innkeeper Kaylisk at Splintertree Post.'),
(81312, 2, -1,  93, 4927, 4, 100000, 0, 8,
 'North to Felwood',
 'Report to Gorrim at the Emerald Sanctuary in Felwood.',
 'The corruption in Felwood answers to neither banner. The Cenarion druids at the Emerald Sanctuary take all comers -- seek out Gorrim at the southern gateway.',
 'Report to Gorrim at the Emerald Sanctuary.'),
(81313, 2, -1, 101, 4926, 4, 100000, 0, 8,
 'The Frozen Reaches',
 'Report to Innkeeper Vizzie at Everlook in Winterspring.',
 'Winterspring''s passes are open. Everlook welcomes anyone whose coin is good -- and the Steamwheedle pay for strong arms besides. Report to Innkeeper Vizzie.',
 'Report to Innkeeper Vizzie at Everlook.'),
(81314, 2, -1, 110, 4923, 4, 100000, 0, 8,
 'The Sacred Mountain',
 'Report to Sebelia at Nordrassil on Hyjal.',
 'The summit of Hyjal burns. The Guardians muster at Nordrassil beneath the World Tree for the last ascent. Report to Sebelia -- and bring everything you have.',
 'Report to Sebelia at Nordrassil.'),
(81315, 2, -1,  93, 4928, 4, 100000, 0, 8,
 'Moonglade Respite',
 'Speak with Keeper Remulos at Nighthaven in Moonglade.',
 'Not every road through these lands is a battlefield. Moonglade remains a sanctuary; Keeper Remulos welcomes travelers who need rest, trade or the druids'' counsel.',
 'Speak with Keeper Remulos at Nighthaven.');

-- ---------------------------------------------------------------------------
-- 2. starter / ender wiring
-- ---------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 81300 AND 81315;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(300070,  81300),  -- Archmage Thadeus, Azshara Crater (map 37)
(300070,  81301),
(3743420, 81310),  -- Innkeeper Kyteran, Lor'danel
(3643771, 81311),  -- Innkeeper Mixi, Bilgewater Harbor
(3606738, 81312),  -- Innkeeper Kimlya, Astranaar
(3612196, 81312),  -- Innkeeper Kaylisk, Splintertree Post
(3722931, 81313),  -- Gorrim, Emerald Sanctuary
(3722931, 81315),
(3711118, 81314);  -- Innkeeper Vizzie, Everlook

DELETE FROM `creature_questender` WHERE `quest` BETWEEN 81300 AND 81315;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3743420, 81300),
(3643771, 81301),
(3606738, 81310),
(3612196, 81311),
(3722931, 81312),
(3711118, 81313),
(3640843, 81314),  -- Sebelia, Nordrassil
(3711832, 81315);  -- Keeper Remulos, Nighthaven

-- ---------------------------------------------------------------------------
-- 3. questgiver bit on the native hub NPCs that lack it
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2
WHERE `entry` IN (3743420, 3643771, 3606738, 3612196, 3722931, 3711118, 3640843, 3711832);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- SELECT ID, QuestLevel, MinLevel, AllowableRaces FROM quest_template
-- WHERE ID BETWEEN 81300 AND 81315;                                    -- 8 rows
-- SELECT id, quest FROM creature_queststarter WHERE quest BETWEEN 81300 AND 81315;
-- SELECT entry, npcflag & 2 FROM creature_template
-- WHERE entry IN (3743420, 3643771, 3606738, 3612196, 3722931, 3711118,
--                 3640843, 3711832);                                   -- all 2
-- In-game: fresh 80 on each faction, run the full chain to Nordrassil.
