CREATE TABLE IF NOT EXISTS `dc_guild_house` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `guild` int(11) NOT NULL DEFAULT '0',
  `phase` int(11) NOT NULL,
  `map` int(11) NOT NULL DEFAULT '0',
  `positionX` float NOT NULL DEFAULT '0',
  `positionY` float NOT NULL DEFAULT '0',
  `positionZ` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `guildhouse_level` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `guild` (`guild`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
