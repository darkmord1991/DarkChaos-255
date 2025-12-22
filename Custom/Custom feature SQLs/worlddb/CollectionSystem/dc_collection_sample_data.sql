-- ============================================================================
-- DC Collection System - Sample Definitions
-- ============================================================================
-- Version: 1.0.0
-- Author: DarkChaos-255
-- Description: Sample mount, pet, title, and heirloom definitions
-- Run AFTER: dc_collection_definitions.sql
-- ============================================================================

-- ============================================================================
-- SAMPLE MOUNT DEFINITIONS (WotLK popular mounts)
-- ============================================================================

INSERT INTO `dc_mount_definitions` (`spell_id`, `name`, `mount_type`, `source`, `faction`, `rarity`, `speed`, `display_id`) VALUES
-- Ground Mounts (type 0)
(23229, 'Swift Mistsaber', 0, '{"type":"vendor","npc":"Lelanai","zone":"Darnassus"}', 1, 3, 100, 6080),
(23228, 'Swift Palomino', 0, '{"type":"vendor","npc":"Katie Hunter","zone":"Elwynn Forest"}', 1, 3, 100, 2409),
(23225, 'Swift White Ram', 0, '{"type":"vendor","npc":"Veron Amberstill","zone":"Dun Morogh"}', 1, 3, 100, 2786),
(23227, 'Swift Blue Mechanostrider', 0, '{"type":"vendor","npc":"Milli Featherwhistle","zone":"Dun Morogh"}', 1, 3, 100, 10662),
(23509, 'Frostwolf Howler', 0, '{"type":"pvp","vendor":"Frostwolf Quartermaster","rep":"Frostwolf Clan"}', 2, 3, 100, 14774),
(23510, 'Stormpike Battle Charger', 0, '{"type":"pvp","vendor":"Stormpike Quartermaster","rep":"Stormpike Guard"}', 1, 3, 100, 14777),
(46628, 'Traveler\'s Tundra Mammoth', 0, '{"type":"vendor","npc":"Mei Francis","zone":"Dalaran","cost":20000}', 0, 4, 100, 25452),
(42776, 'Grand Black War Mammoth', 0, '{"type":"drop","boss":"Vault of Archavon Bosses","dropRate":0.1}', 0, 4, 100, 27241),

-- Flying Mounts (type 1)
(32235, 'Golden Gryphon', 1, '{"type":"vendor","npc":"Brunn Flamebeard","zone":"Shadowmoon Valley"}', 1, 2, 280, 17699),
(32239, 'Ebon Gryphon', 1, '{"type":"vendor","npc":"Brunn Flamebeard","zone":"Shadowmoon Valley"}', 1, 2, 280, 17696),
(32246, 'Swift Purple Gryphon', 1, '{"type":"vendor","npc":"Brunn Flamebeard","zone":"Shadowmoon Valley"}', 1, 3, 310, 17719),
(32295, 'Swift Red Wind Rider', 1, '{"type":"vendor","npc":"Dama Wildmane","zone":"Shadowmoon Valley"}', 2, 3, 310, 17719),
(48025, 'Headless Horseman\'s Mount', 1, '{"type":"drop","boss":"Headless Horseman","instance":"Scarlet Monastery","dropRate":0.5}', 0, 4, 310, 25159),
(51960, 'Ashes of Al\'ar', 1, '{"type":"drop","boss":"Kael\'thas Sunstrider","instance":"Tempest Keep","dropRate":1.0}', 0, 5, 310, 17890),
(44153, 'Azure Drake', 1, '{"type":"drop","boss":"Malygos","instance":"Eye of Eternity","dropRate":2.0}', 0, 4, 310, 25832),
(59650, 'Black Proto-Drake', 1, '{"type":"achievement","achievement":"Glory of the Raider"}', 0, 4, 310, 28040),
(59961, 'Red Proto-Drake', 1, '{"type":"achievement","achievement":"Glory of the Hero"}', 0, 4, 310, 28044),
(60114, 'Armored Brown Bear', 1, '{"type":"vendor","npc":"Mei Francis","zone":"Dalaran","cost":750}', 0, 3, 100, 29598),
(61451, 'Flying Carpet', 1, '{"type":"profession","profession":"Tailoring","skill":300}', 0, 2, 280, 28060),
(61294, 'Green Proto-Drake', 1, '{"type":"drop","source":"Mysterious Egg","dropRate":5.0}', 0, 4, 310, 28053),
(63796, 'Mimiron\'s Head', 1, '{"type":"drop","boss":"Yogg-Saron","instance":"Ulduar","mode":"Hard Mode","dropRate":1.0}', 0, 5, 310, 28890),
(72286, 'Invincible', 1, '{"type":"drop","boss":"The Lich King","instance":"Icecrown Citadel","mode":"Heroic","dropRate":1.0}', 0, 5, 310, 31007),
(54753, 'White Polar Bear', 1, '{"type":"drop","source":"Hyldnir Spoils","dropRate":2.0}', 0, 3, 100, 28428),
(66087, 'Silver Covenant Hippogryph', 1, '{"type":"vendor","npc":"Dame Evniki Kapsalis","rep":"Silver Covenant","repLevel":"Exalted"}', 1, 4, 310, 29143),
(66088, 'Sunreaver Dragonhawk', 1, '{"type":"vendor","npc":"Vasarin Redmorn","rep":"Sunreavers","repLevel":"Exalted"}', 2, 4, 310, 29696),

-- All-Terrain (type 3)
(48778, 'Acherus Deathcharger', 3, '{"type":"quest","quest":"The Light of Dawn","class":"Death Knight"}', 0, 3, 100, 25280),
(75614, 'Celestial Steed', 3, '{"type":"shop","store":"Blizzard Store"}', 0, 4, 310, 31958)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ============================================================================
-- SAMPLE PET DEFINITIONS (WotLK popular pets)
-- ============================================================================

INSERT INTO `dc_pet_definitions` (`pet_entry`, `name`, `pet_type`, `pet_spell_id`, `source`, `rarity`, `display_id`) VALUES
(4055, 'Baby Blizzard Bear', 'companion', 61855, '{"type":"promotion","event":"WoW 4th Anniversary"}', 3, 28473),
(10398, 'Mechanical Squirrel', 'companion', 4055, '{"type":"profession","profession":"Engineering","skill":75}', 1, 1155),
(10673, 'Pet Bombling', 'companion', 15048, '{"type":"profession","profession":"Engineering","skill":205}', 2, 9656),
(7544, 'Sprite Darter Hatchling', 'companion', 15067, '{"type":"drop","zone":"Feralas","mob":"Sprite Darter"}', 3, 6286),
(8494, 'Tiny Crimson Whelpling', 'companion', 10697, '{"type":"drop","zone":"Wetlands","dropRate":0.1}', 3, 7961),
(15186, 'Tiny Snowman', 'companion', 26010, '{"type":"event","event":"Feast of Winter Veil"}', 2, 15709),
(23713, 'Hippogryph Hatchling', 'companion', 30156, '{"type":"tcg","card":"Thunderhead Hippogryph"}', 4, 21766),
(32617, 'Sleepy Willy', 'companion', 40613, '{"type":"vendor","npc":"Breanni","zone":"Dalaran","cost":50}', 2, 16068),
(33199, 'Little Fawn', 'companion', 43461, '{"type":"achievement","achievement":"Lil\' Game Hunter"}', 3, 24941),
(34364, 'Mr. Chilly', 'companion', 44369, '{"type":"promotion","event":"Merge Accounts"}', 2, 24389),
(34724, 'Toxic Wasteling', 'companion', 71840, '{"type":"event","event":"Love is in the Air","source":"Lovely Charm Box"}', 3, 31281),
(36871, 'Kirin Tor Familiar', 'companion', 61472, '{"type":"achievement","achievement":"Higher Learning"}', 3, 28470),
(39656, 'Core Hound Pup', 'companion', 69452, '{"type":"promotion","event":"Authenticator"}', 3, 19220),
(39709, 'Pebble', 'companion', 84492, '{"type":"quest","quest":"Rock Lover","zone":"Deepholm"}', 3, 35595),
(41936, 'Lil\' Ragnaros', 'companion', 68385, '{"type":"shop","store":"Blizzard Store"}', 4, 37541)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ============================================================================
-- SAMPLE TITLE DEFINITIONS (WotLK titles)
-- ============================================================================

CREATE TABLE IF NOT EXISTS `dc_title_definitions` (
    `title_id` INT UNSIGNED NOT NULL PRIMARY KEY COMMENT 'CharTitles.dbc ID',
    `name` VARCHAR(100) NOT NULL,
    `title_format` VARCHAR(100) NOT NULL COMMENT 'Title format string (%s = name)',
    `source` TEXT DEFAULT NULL COMMENT 'JSON source info',
    `faction` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=both, 1=alliance, 2=horde',
    `rarity` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    KEY `idx_faction` (`faction`),
    KEY `idx_rarity` (`rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Title definitions';

INSERT INTO `dc_title_definitions` (`title_id`, `name`, `title_format`, `source`, `faction`, `rarity`) VALUES
-- PvP Titles
(1, 'Private', 'Private %s', '{"type":"pvp","rank":1}', 1, 1),
(2, 'Corporal', 'Corporal %s', '{"type":"pvp","rank":2}', 1, 1),
(15, 'Scout', 'Scout %s', '{"type":"pvp","rank":1}', 2, 1),
(16, 'Grunt', 'Grunt %s', '{"type":"pvp","rank":2}', 2, 1),
(42, 'Gladiator', 'Gladiator %s', '{"type":"arena","rating":2200}', 0, 4),
(43, 'Duelist', 'Duelist %s', '{"type":"arena","rating":2000}', 0, 3),
(44, 'Rival', 'Rival %s', '{"type":"arena","rating":1800}', 0, 2),
(45, 'Challenger', 'Challenger %s', '{"type":"arena","rating":1550}', 0, 1),

-- Achievement Titles
(53, 'Champion of the Frozen Wastes', '%s, Champion of the Frozen Wastes', '{"type":"achievement","achievement":"Glory of the Raider (25)"}', 0, 4),
(72, 'the Undying', '%s the Undying', '{"type":"achievement","achievement":"The Undying"}', 0, 4),
(74, 'the Immortal', '%s the Immortal', '{"type":"achievement","achievement":"The Immortal"}', 0, 5),
(81, 'the Explorer', '%s the Explorer', '{"type":"achievement","achievement":"World Explorer"}', 0, 3),
(82, 'the Diplomat', '%s the Diplomat', '{"type":"achievement","achievement":"The Diplomat"}', 0, 3),
(113, 'the Kingslayer', '%s the Kingslayer', '{"type":"achievement","achievement":"Fall of the Lich King"}', 0, 5),
(122, 'Bane of the Fallen King', '%s, Bane of the Fallen King', '{"type":"achievement","achievement":"Fall of the Lich King (Heroic)"}', 0, 5),
(127, 'the Light of Dawn', '%s, the Light of Dawn', '{"type":"achievement","achievement":"The Light of Dawn (25 Heroic)"}', 0, 5),

-- Reputation Titles
(46, 'of the Shattered Sun', '%s of the Shattered Sun', '{"type":"reputation","faction":"Shattered Sun Offensive","level":"Exalted"}', 0, 3),
(48, 'Hand of A\'dal', '%s, Hand of A\'dal', '{"type":"quest","questline":"Attunement to Black Temple"}', 0, 4),
(49, 'Champion of the Naaru', '%s, Champion of the Naaru', '{"type":"quest","questline":"Tempest Keep Attunement"}', 0, 4),
(64, 'the Exalted', '%s the Exalted', '{"type":"achievement","achievement":"40 Exalted Reputations"}', 0, 4),
(126, 'the Astral Walker', '%s the Astral Walker', '{"type":"achievement","achievement":"Observed (Ulduar)"}', 0, 4),

-- Event Titles
(74, 'Elder', 'Elder %s', '{"type":"event","event":"Lunar Festival"}', 0, 2),
(76, 'Flame Keeper', 'Flame Keeper %s', '{"type":"event","event":"Midsummer Fire Festival"}', 1, 2),
(77, 'Flame Warden', 'Flame Warden %s', '{"type":"event","event":"Midsummer Fire Festival"}', 2, 2),
(83, 'Brewmaster', 'Brewmaster %s', '{"type":"event","event":"Brewfest"}', 0, 2),
(84, 'the Hallowed', '%s the Hallowed', '{"type":"event","event":"Hallow\'s End"}', 0, 2),
(87, 'Merrymaker', 'Merrymaker %s', '{"type":"event","event":"Feast of Winter Veil"}', 0, 2),
(124, 'the Noble', '%s the Noble', '{"type":"event","event":"Noblegarden"}', 0, 2)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ============================================================================
-- SAMPLE HEIRLOOM DEFINITIONS
-- ============================================================================

INSERT INTO `dc_heirloom_definitions` (`item_id`, `name`, `slot`, `armor_type`, `max_upgrade_level`, `source`) VALUES
-- Shoulders
(42949, 'Polished Spaulders of Valor', 3, 4, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42950, 'Champion Herod\'s Shoulder', 3, 4, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42951, 'Mystical Pauldrons of Elements', 3, 3, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42952, 'Stained Shadowcraft Spaulders', 3, 2, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42984, 'Preened Ironfeather Shoulders', 3, 2, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42985, 'Tattered Dreadmist Mantle', 3, 1, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),

-- Chest
(48685, 'Polished Breastplate of Valor', 5, 4, 3, '{"type":"vendor","npc":"Argent Tournament","cost":"Champion\'s Seals"}'),
(48687, 'Mystical Vest of Elements', 5, 3, 3, '{"type":"vendor","npc":"Argent Tournament","cost":"Champion\'s Seals"}'),
(48689, 'Stained Shadowcraft Tunic', 5, 2, 3, '{"type":"vendor","npc":"Argent Tournament","cost":"Champion\'s Seals"}'),
(48691, 'Preened Ironfeather Breastplate', 5, 2, 3, '{"type":"vendor","npc":"Argent Tournament","cost":"Champion\'s Seals"}'),

-- Weapons
(42943, 'Bloodied Arcanite Reaper', 17, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42944, 'Sharpened Scarlet Kris', 13, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42945, 'Balanced Heartseeker', 13, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42946, 'Charmed Ancient Bone Bow', 15, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42947, 'Dignified Headmaster\'s Charge', 17, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42948, 'Devout Aurastone Hammer', 21, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),

-- Trinkets
(42991, 'Swift Hand of Justice', 12, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}'),
(42992, 'Discerning Eye of the Beast', 12, 0, 3, '{"type":"vendor","npc":"Wintergrasp Quartermaster","cost":"Stone Keeper\'s Shards"}')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ============================================================================
-- UPDATE dc_collection_definitions INDEX
-- ============================================================================

-- Populate index from specific tables
INSERT IGNORE INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`)
SELECT 1, spell_id, 1 FROM dc_mount_definitions;

INSERT IGNORE INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`)
SELECT 2, pet_entry, 1 FROM dc_pet_definitions;

INSERT IGNORE INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`)
SELECT 4, item_id, 1 FROM dc_heirloom_definitions;

INSERT IGNORE INTO `dc_collection_definitions` (`collection_type`, `entry_id`, `enabled`)
SELECT 5, title_id, 1 FROM dc_title_definitions;

-- ============================================================================
-- SAMPLE SHOP ITEMS
-- ============================================================================

INSERT INTO `dc_collection_shop` (`collection_type`, `entry_id`, `price_tokens`, `price_emblems`, `featured`, `enabled`) VALUES
-- Featured Mounts
(1, 75614, 5000, 100, 1, 1),  -- Celestial Steed
(1, 72286, 10000, 500, 1, 1),  -- Invincible (very expensive)
(1, 63796, 8000, 300, 1, 1),  -- Mimiron's Head

-- Featured Pets
(2, 41936, 2500, 50, 1, 1),  -- Lil' Ragnaros

-- Regular Mounts
(1, 54753, 1000, 20, 0, 1),  -- White Polar Bear
(1, 48025, 2000, 50, 0, 1),  -- Headless Horseman's Mount

-- Regular Pets
(2, 33199, 500, 10, 0, 1),  -- Little Fawn
(2, 36871, 800, 15, 0, 1)  -- Kirin Tor Familiar
ON DUPLICATE KEY UPDATE price_tokens = VALUES(price_tokens);
