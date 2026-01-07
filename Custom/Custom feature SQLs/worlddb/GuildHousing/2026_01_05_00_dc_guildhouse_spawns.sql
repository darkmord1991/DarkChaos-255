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

-- Custom profession trainers (from Trainers/npc_trainer_new.sql)
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (90, 1, 95001, 16218.1, 16281.8, 13.1756, 6.1975, 'Alchemy Trainer (custom 95001)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (91, 1, 95005, 16218.3, 16284.3, 13.1756, 6.1975, 'Herbalism Trainer (custom 95005)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (92, 1, 95002, 16220.5, 16302.3, 13.1760, 6.14647, 'Blacksmithing Trainer (custom 95002)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (93, 1, 95009, 16220.2, 16299.6, 13.1780, 6.22894, 'Mining Trainer (custom 95009)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (94, 1, 95004, 16219.8, 16296.9, 13.1746, 6.24465, 'Engineering Trainer (custom 95004)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (95, 1, 95007, 16222.4, 16293.0, 13.1813, 1.51263, 'Jewelcrafting Trainer (custom 95007)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (96, 1, 95003, 16227.5, 16292.3, 13.1839, 1.49691, 'Enchanting Trainer (custom 95003)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (97, 1, 95006, 16231.6, 16301.0, 13.1757, 3.07372, 'Inscription Trainer (custom 95006)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (98, 1, 95008, 16231.2, 16295.0, 13.1761, 3.06574, 'Leatherworking Trainer (custom 95008)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (99, 1, 95010, 16228.9, 16304.7, 13.1819, 4.64831, 'Skinning Trainer (custom 95010)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (100, 1, 95011, 16220.4, 16278.7, 13.1756, 1.46157, 'Tailoring Trainer (custom 95011)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (101, 1, 95012, 16227.0, 16278.0, 13.1762, 1.48720, 'Cooking Trainer (custom 95012)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (102, 1, 95013, 16225.0, 16310.9, 29.2620, 6.22119, 'First Aid Trainer (custom 95013)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (103, 1, 95014, 16225.3, 16313.9, 29.2620, 6.28231, 'Fishing Trainer (custom 95014)');

-- Custom weapon & riding trainers
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (104, 1, 95025, 16224.0, 16286.0, 13.1760, 3.05000, 'Weapon Trainer (custom 95025)');
INSERT INTO `dc_guild_house_spawns` (`id`, `map`, `entry`, `posX`, `posY`, `posZ`, `orientation`, `comment`) VALUES (105, 1, 95026, 16226.0, 16286.0, 13.1760, 3.05000, 'Riding Trainer (custom 95026)');
