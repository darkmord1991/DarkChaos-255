-- =====================================================
-- DarkChaos-255 Custom Achievements
-- =====================================================
-- Achievement IDs: 10001-20000 (reserved for DarkChaos)

-- =====================================================
-- 1. CUSTOM ZONE EXPLORATION (Category: 10001)
-- =====================================================

-- Azshara Crater Achievements
INSERT INTO `achievement_dbc` (`ID`, `Faction`, `Instance_Id`, `Category`, `Points`, `Ui_Order`, `Flags`, `IconID`, 
    `Title_Lang_enUS`, `Description_Lang_enUS`, `Reward_Lang_enUS`) VALUES

-- Explore Azshara Crater
(10001, -1, -1, 10001, 10, 1, 0, 4396, 
    'Explore Azshara Crater', 
    'Explore all areas of Azshara Crater', 
    'Title Reward: Crater Explorer'),

-- Azshara Crater Quests Complete
(10002, -1, -1, 10001, 25, 2, 0, 4396,
    'Azshara Crater Quests',
    'Complete all quests in Azshara Crater',
    NULL),

-- Hyjal Achievements
(10003, -1, -1, 10001, 10, 3, 0, 4396,
    'Explore Hyjal',
    'Explore all areas of Hyjal',
    'Title Reward: Protector of Nordrassil'),

(10004, -1, -1, 10001, 25, 4, 0, 4396,
    'Hyjal Quests',
    'Complete all quests in Hyjal',
    NULL),

-- =====================================================
-- 2. CUSTOM DUNGEONS (Category: 10002)
-- =====================================================

-- Example custom dungeon achievements
(10100, -1, -1, 10002, 10, 1, 0, 4352,
    'Custom Dungeon Explorer',
    'Complete 10 custom dungeons',
    NULL),

(10101, -1, -1, 10002, 25, 2, 0, 4352,
    'Custom Dungeon Master',
    'Complete all custom dungeons',
    'Title Reward: Dungeon Master'),

-- =====================================================
-- 3. HINTERLANDS BATTLEGROUND (Category: 10003)
-- =====================================================

(10200, -1, -1, 10003, 10, 1, 0, 1785,
    'Hinterlands Novice',
    'Participate in 10 Hinterlands BG matches',
    NULL),

(10201, -1, -1, 10003, 10, 2, 0, 1785,
    'Hinterlands Victor',
    'Win 10 Hinterlands BG matches',
    NULL),

(10202, -1, -1, 10003, 25, 3, 0, 1785,
    'Hinterlands Hero',
    'Win 100 Hinterlands BG matches',
    'Title Reward: Hinterlands Hero'),

(10203, -1, -1, 10003, 10, 4, 0, 1785,
    'Flag Runner',
    'Capture 25 flags in Hinterlands BG',
    NULL),

(10204, -1, -1, 10003, 25, 5, 0, 1785,
    'Flag Master',
    'Capture 100 flags in Hinterlands BG',
    'Title Reward: Flag Master'),

(10205, -1, -1, 10003, 10, 6, 0, 1785,
    'Hinterlands Defender',
    'Defend your base 50 times',
    NULL),

-- =====================================================
-- 4. PRESTIGE SYSTEM (Category: 10004)
-- =====================================================

(10300, -1, -1, 10004, 10, 1, 0, 2951,
    'Prestige Level I',
    'Reach Prestige Level 1',
    'Title Reward: Prestige I'),

(10301, -1, -1, 10004, 10, 2, 0, 2951,
    'Prestige Level II',
    'Reach Prestige Level 2',
    'Title Reward: Prestige II'),

(10302, -1, -1, 10004, 10, 3, 0, 2951,
    'Prestige Level III',
    'Reach Prestige Level 3',
    'Title Reward: Prestige III'),

(10303, -1, -1, 10004, 10, 4, 0, 2951,
    'Prestige Level IV',
    'Reach Prestige Level 4',
    'Title Reward: Prestige IV'),

(10304, -1, -1, 10004, 10, 5, 0, 2951,
    'Prestige Level V',
    'Reach Prestige Level 5',
    'Title Reward: Prestige V'),

(10305, -1, -1, 10004, 25, 6, 0, 2951,
    'Prestige Level VI',
    'Reach Prestige Level 6',
    'Title Reward: Prestige VI'),

(10306, -1, -1, 10004, 25, 7, 0, 2951,
    'Prestige Level VII',
    'Reach Prestige Level 7',
    'Title Reward: Prestige VII'),

(10307, -1, -1, 10004, 25, 8, 0, 2951,
    'Prestige Level VIII',
    'Reach Prestige Level 8',
    'Title Reward: Prestige VIII'),

(10308, -1, -1, 10004, 50, 9, 0, 2951,
    'Prestige Level IX',
    'Reach Prestige Level 9',
    'Title Reward: Prestige IX'),

(10309, -1, -1, 10004, 100, 10, 0, 2951,
    'Prestige Level X',
    'Reach Prestige Level 10',
    'Title Reward: Prestige X'),

-- =====================================================
-- 5. COLLECTIONS (Category: 10005)
-- =====================================================

(10400, -1, -1, 10005, 10, 1, 0, 1024,
    'Mount Collector',
    'Obtain 50 mounts',
    NULL),

(10401, -1, -1, 10005, 25, 2, 0, 1024,
    'Mount Master',
    'Obtain 100 mounts',
    'Title Reward: Mount Master'),

(10402, -1, -1, 10005, 10, 3, 0, 413,
    'Pet Collector',
    'Obtain 50 companion pets',
    NULL),

(10403, -1, -1, 10005, 25, 4, 0, 413,
    'Pet Master',
    'Obtain 100 companion pets',
    'Title Reward: Pet Master'),

(10404, -1, -1, 10005, 10, 5, 0, 625,
    'Title Collector',
    'Earn 25 titles',
    NULL),

(10405, -1, -1, 10005, 25, 6, 0, 625,
    'The Titled',
    'Earn 50 titles',
    'Title Reward: the Titled'),

-- =====================================================
-- 6. SERVER FIRSTS (Category: 10006)
-- =====================================================

(10500, -1, -1, 10006, 100, 1, 0, 2442,
    'First to Level 255',
    'Be the first player to reach level 255',
    'Title Reward: Realm First! Level 255'),

(10501, -1, -1, 10006, 50, 2, 0, 2442,
    'First to Prestige',
    'Be the first player to reach Prestige Level 1',
    'Title Reward: Realm First! Prestige'),

(10502, -1, -1, 10006, 100, 3, 0, 2442,
    'First to Complete Custom Dungeons',
    'Be the first to complete all custom dungeons',
    'Title Reward: Realm First! Dungeon Conqueror'),

(10503, -1, -1, 10006, 100, 4, 0, 2442,
    'First Hinterlands BG Win',
    'Win the first Hinterlands BG match on the server',
    'Title Reward: Realm First! Hinterlands Victor'),

-- =====================================================
-- 7. CHALLENGE MODES (Category: 10007)
-- =====================================================

(10600, -1, -1, 10007, 25, 1, 0, 3778,
    'Hardcore Survivor',
    'Reach level 60 in Hardcore mode',
    'Title Reward: the Hardcore'),

(10601, -1, -1, 10007, 50, 2, 0, 3778,
    'Hardcore Legend',
    'Reach level 255 in Hardcore mode',
    'Title Reward: Hardcore Legend'),

(10602, -1, -1, 10007, 25, 3, 0, 3778,
    'Iron Man',
    'Reach level 60 in Iron Man mode',
    'Title Reward: Iron Man'),

(10603, -1, -1, 10007, 50, 4, 0, 3778,
    'Iron Legend',
    'Reach level 255 in Iron Man mode',
    'Title Reward: Iron Legend'),

(10604, -1, -1, 10007, 10, 5, 0, 3778,
    'Self-Sufficient',
    'Reach level 60 in Self-Crafted mode',
    'Title Reward: the Self-Sufficient'),

-- =====================================================
-- 8. LEVEL 255 ACHIEVEMENTS (Category: 10008)
-- =====================================================

(10700, -1, -1, 10008, 50, 1, 0, 3187,
    'Level 100',
    'Reach level 100',
    NULL),

(10701, -1, -1, 10008, 50, 2, 0, 3187,
    'Level 150',
    'Reach level 150',
    'Title Reward: the Powerful'),

(10702, -1, -1, 10008, 50, 3, 0, 3187,
    'Level 200',
    'Reach level 200',
    'Title Reward: the Unstoppable'),

(10703, -1, -1, 10008, 100, 4, 0, 3187,
    'Level 255',
    'Reach the maximum level of 255',
    'Title Reward: the Ascended'),

-- =====================================================
-- 9. CUSTOM QUESTS (Category: 10009)
-- =====================================================

(10800, -1, -1, 10009, 10, 1, 0, 1134,
    'Custom Quest Novice',
    'Complete 25 custom quests',
    NULL),

(10801, -1, -1, 10009, 25, 2, 0, 1134,
    'Custom Quest Hero',
    'Complete 100 custom quests',
    'Title Reward: Quest Hero'),

(10802, -1, -1, 10009, 50, 3, 0, 1134,
    'Custom Quest Master',
    'Complete all custom quests',
    'Title Reward: Custom Loremaster'),

-- =====================================================
-- 10. FEATS OF STRENGTH (Category: 10010)
-- =====================================================

(10900, -1, -1, 10010, 0, 1, 1, 2359,
    'Server Veteran',
    'Played on DarkChaos-255 for 1 year',
    'Title Reward: Server Veteran'),

(10901, -1, -1, 10010, 0, 2, 1, 2359,
    'Beta Tester',
    'Participated in the server beta',
    'Title Reward: Beta Tester'),

(10902, -1, -1, 10010, 0, 3, 1, 2359,
    'Early Adopter',
    'Joined the server in the first month',
    'Title Reward: Early Adopter');
