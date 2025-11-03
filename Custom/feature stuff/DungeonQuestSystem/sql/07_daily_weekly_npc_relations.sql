-- ============================================
-- Daily & Weekly Quest NPC Relations
-- Links quest herald (700003) to daily/weekly quests
-- ============================================

-- Delete existing relations for daily/weekly herald
DELETE FROM `creature_queststarter` WHERE `id` = 700003;
DELETE FROM `creature_questender` WHERE `id` = 700003;

-- ===== DAILY QUEST STARTERS =====
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
-- Sunday (Day 0)
(700003, 700101),  -- [Daily] Blackrock Depths
(700003, 700102),  -- [Daily] Hellfire Citadel: Ramparts (Heroic)
(700003, 700103),  -- [Daily] Drak'Tharon Keep
(700003, 700104),  -- [Daily] Gnomeregan
(700003, 700105),  -- [Daily] Stratholme

-- Monday (Day 1)
(700003, 700106),  -- [Daily] Dire Maul
(700003, 700107),  -- [Daily] Auchenai Crypts (Heroic)
(700003, 700108),  -- [Daily] Gundrak
(700003, 700109),  -- [Daily] Scarlet Monastery
(700003, 700110),  -- [Daily] Uldaman

-- Tuesday (Day 2)
(700003, 700111),  -- [Daily] Blackrock Spire
(700003, 700112),  -- [Daily] The Slave Pens (Heroic)
(700003, 700113),  -- [Daily] Utgarde Keep
(700003, 700114),  -- [Daily] The Deadmines
(700003, 700115),  -- [Daily] Scholomance

-- Wednesday (Day 3)
(700003, 700116),  -- [Daily] Maraudon
(700003, 700117),  -- [Daily] Shadow Labyrinth (Heroic)
(700003, 700118),  -- [Daily] Halls of Stone
(700003, 700119),  -- [Daily] Wailing Caverns
(700003, 700120),  -- [Daily] Zul'Farrak

-- Thursday (Day 4)
(700003, 700121),  -- [Daily] The Temple of Atal'Hakkar
(700003, 700122),  -- [Daily] The Steamvault (Heroic)
(700003, 700123),  -- [Daily] The Nexus
(700003, 700124),  -- [Daily] Blackfathom Deeps
(700003, 700125),  -- [Daily] Razorfen Downs

-- Friday (Day 5)
(700003, 700126),  -- [Daily] Shadowfang Keep
(700003, 700127),  -- [Daily] Mana-Tombs (Heroic)
(700003, 700128),  -- [Daily] Azjol-Nerub
(700003, 700129),  -- [Daily] Ragefire Chasm
(700003, 700130),  -- [Daily] Razorfen Kraul

-- Saturday (Day 6)
(700003, 700131),  -- [Daily] The Stockade
(700003, 700132),  -- [Daily] The Underbog (Heroic)
(700003, 700133),  -- [Daily] Halls of Lightning
(700003, 700134),  -- [Daily] Caverns of Time
(700003, 700135),  -- [Daily] Scarlet Monastery

-- ===== WEEKLY QUEST STARTERS =====
-- Week 1
(700003, 700201),  -- [Weekly] Blackrock Depths (Heroic)
(700003, 700202),  -- [Weekly] Hellfire Citadel: Ramparts (Mythic)
(700003, 700203),  -- [Weekly] Drak'Tharon Keep (Heroic)

-- Week 2
(700003, 700204),  -- [Weekly] Dire Maul (Heroic)
(700003, 700205),  -- [Weekly] Auchenai Crypts (Mythic)
(700003, 700206),  -- [Weekly] Utgarde Keep (Heroic)

-- Week 3
(700003, 700207),  -- [Weekly] Blackrock Spire (Heroic)
(700003, 700208),  -- [Weekly] The Slave Pens (Mythic)
(700003, 700209),  -- [Weekly] Gundrak (Heroic)

-- Week 4
(700003, 700210),  -- [Weekly] Maraudon (Heroic)
(700003, 700211),  -- [Weekly] Shadow Labyrinth (Mythic)
(700003, 700212);  -- [Weekly] Halls of Stone (Heroic)

-- ===== DAILY QUEST ENDERS =====
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
-- Sunday (Day 0)
(700003, 700101), (700003, 700102), (700003, 700103), (700003, 700104), (700003, 700105),

-- Monday (Day 1)
(700003, 700106), (700003, 700107), (700003, 700108), (700003, 700109), (700003, 700110),

-- Tuesday (Day 2)
(700003, 700111), (700003, 700112), (700003, 700113), (700003, 700114), (700003, 700115),

-- Wednesday (Day 3)
(700003, 700116), (700003, 700117), (700003, 700118), (700003, 700119), (700003, 700120),

-- Thursday (Day 4)
(700003, 700121), (700003, 700122), (700003, 700123), (700003, 700124), (700003, 700125),

-- Friday (Day 5)
(700003, 700126), (700003, 700127), (700003, 700128), (700003, 700129), (700003, 700130),

-- Saturday (Day 6)
(700003, 700131), (700003, 700132), (700003, 700133), (700003, 700134), (700003, 700135),

-- ===== WEEKLY QUEST ENDERS =====
-- Week 1-4
(700003, 700201), (700003, 700202), (700003, 700203),
(700003, 700204), (700003, 700205), (700003, 700206),
(700003, 700207), (700003, 700208), (700003, 700209),
(700003, 700210), (700003, 700211), (700003, 700212);

-- ============================================
-- SUMMARY
-- ============================================
-- NPC 700003 (Quest Herald) offers:
--   - 35 daily quests (5 per day, 7-day rotation)
--   - 12 weekly quests (3 per week, 4-week rotation)
--   - Total: 47 quests
--
-- Daily quests reset: 6:00 AM server time
-- Weekly quests reset: Wednesday 6:00 AM server time
--
-- Players can only see quests that are currently active
-- based on the rotation schedule
