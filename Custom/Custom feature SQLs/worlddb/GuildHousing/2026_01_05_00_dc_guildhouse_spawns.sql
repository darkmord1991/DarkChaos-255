CREATE TABLE IF NOT EXISTS `dc_guild_house_spawns` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `map` int(11) NOT NULL DEFAULT '1',
  `entry` int(11) NOT NULL DEFAULT '0',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `comment` varchar(500) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `map_entry` (`map`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (1, 1, 26327, 16216.5, 16279.4, 20.9306, 0.552869, 'Paladin Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (2, 1, 26324, 16221.3, 16275.7, 20.9285, 1.37363, 'Druid Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (3, 1, 26325, 16218.6, 16277, 20.9872, 0.967188, 'Hunter Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (4, 1, 26326, 16224.9, 16274.9, 20.9319, 1.58765, 'Mage Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (5, 1, 26328, 16227.9, 16275.9, 20.9254, 1.9941, 'Priest Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (6, 1, 26329, 16231.4, 16278.1, 20.9222, 2.20026, 'Rogue Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (7, 1, 26330, 16235.5, 16280.8, 20.9257, 2.18652, 'Shaman Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (8, 1, 26331, 16240.8, 16283.3, 20.9299, 1.86843, 'Warlock Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (9, 1, 26332, 16246.6, 16284.5, 20.9301, 1.68975, 'Warrior Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (10, 1, 800001, 16221.9, 16288.5, 13.17, 4.65, 'Innkeeper');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (11, 1, 30605, 16228, 16280.5, 13.1761, 2.98877, 'Banker');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (12, 1, 29195, 16252.3, 16284.9, 20.9324, 1.79537, 'Death Knight Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (13, 1, 2836, 16220.5, 16302.3, 13.176, 6.14647, 'Blacksmithing Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (14, 1, 8128, 16220.2, 16299.6, 13.178, 6.22894, 'Mining Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (15, 1, 8736, 16219.8, 16296.9, 13.1746, 6.24465, 'Engineering Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (16, 1, 18774, 16222.4, 16293, 13.1813, 1.51263, 'Jewelcrafting Trainer (Alliance)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (17, 1, 18751, 16222.4, 16293, 13.1813, 1.51263, 'Jewelcrafting Trainer (Horde)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (18, 1, 18773, 16227.5, 16292.3, 13.1839, 1.49691, 'Enchanting Trainer (Alliance)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (19, 1, 18753, 16227.5, 16292.3, 13.1839, 1.49691, 'Enchanting Trainer (Horde)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (20, 1, 30721, 16231.6, 16301, 13.1757, 3.07372, 'Inscription Trainer (Alliance)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (21, 1, 30722, 16231.6, 16301, 13.1757, 3.07372, 'Inscription Trainer (Horde)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (22, 1, 19187, 16231.2, 16295, 13.1761, 3.06574, 'Leatherworking Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (23, 1, 19180, 16228.9, 16304.7, 13.1819, 4.64831, 'Skinning Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (24, 1, 19052, 16218.1, 16281.8, 13.1756, 6.1975, 'Alchemy Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (25, 1, 908, 16218.3, 16284.3, 13.1756, 6.1975, 'Herbalism Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (26, 1, 2627, 16220.4, 16278.7, 13.1756, 1.46157, 'Tailoring Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (27, 1, 19184, 16225, 16310.9, 29.262, 6.22119, 'First Aid Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (28, 1, 2834, 16225.3, 16313.9, 29.262, 6.28231, 'Fishing Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (29, 1, 19185, 16227, 16278, 13.1762, 1.4872, 'Cooking Trainer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (30, 1, 8719, 16242, 16291.6, 22.9311, 1.52061, 'Alliance Auctioneer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (31, 1, 9856, 16242, 16291.6, 22.9311, 1.52061, 'Horde Auctioneer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (32, 1, 184137, 16220.3, 16272, 12.9736, 4.45592, 'Mailbox (Object)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (33, 1, 1685, 16253.8, 16294.3, 13.1758, 6.11938, 'Forge (Object)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (34, 1, 4087, 16254.4, 16298.7, 13.1758, 3.36027, 'Anvil (Object)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (45, 1, 187293, 16230.5, 16283.5, 13.9061, 3, 'Guild Vault (Object)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (46, 1, 28692, 16236.2, 16315.7, 20.8454, 4.64365, 'Trade Supplies');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (47, 1, 28776, 16223.7, 16297.9, 20.8454, 6.17044, 'Tabard Vendor');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (48, 1, 19572, 16230.2, 16316.1, 20.8455, 4.64365, 'Food & Drink Vendor');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (49, 1, 6491, 16319.9, 16242.4, 24.4747, 2.20683, 'Spirit Healer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (50, 1, 191028, 16255.5, 16304.9, 20.9785, 2.97516, 'Barber Chair (Object)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (51, 1, 29636, 16233.2, 16315.9, 20.8454, 4.64365, 'Reagent Vendor');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (52, 1, 29493, 16229.1, 16286.4, 13.176, 3.03831, 'Ammo & Repair Vendor');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (53, 1, 28690, 16227, 16267.9, 13.15, 4.6533, 'Stable Master');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (54, 1, 9858, 16238.2, 16291.8, 22.9306, 1.55386, 'Neutral Auctioneer');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (55, 1, 2622, 16242.8, 16302.1, 13.176, 4.5557, 'Poisons Vendor');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (79, 1, 95100, 16216, 16260, 21, 1.5, 'Seasonal Trader');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (80, 1, 95101, 16218, 16260, 21, 1.5, 'Holiday Ambassador');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (81, 1, 95102, 16220, 16260, 21, 1.5, 'Omni-Crafter');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (82, 1, 95103, 16222, 16260, 21, 1.5, 'Guildhouse Manager');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (83, 1, 95104, 16229.422, 16283.675, 13.175704, 3.036652, 'GuildHouse Butler');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (84, 1, 55002, 16222, 16260, 21, 1.5, 'Services NPC');

INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (85, 1, 190004, 16240.0000, 16290.0000, 13.175704, 3.036652, 'Mythic NPC 190004');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (86, 1, 100050, 16241.0000, 16291.0000, 13.175704, 3.036652, 'Mythic NPC 100050');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (87, 1, 100051, 16242.0000, 16292.0000, 13.175704, 3.036652, 'Mythic NPC 100051');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (88, 1, 100101, 16243.0000, 16293.0000, 13.175704, 3.036652, 'Mythic NPC 100101');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (89, 1, 100100, 16244.0000, 16294.0000, 13.175704, 3.036652, 'Mythic NPC 100100');
