-- --------------------------------------------------------
-- Host:                         192.168.178.45
-- Server-Version:               8.0.44-0ubuntu0.24.04.1 - (Ubuntu)
-- Server-Betriebssystem:        Linux
-- HeidiSQL Version:             12.13.0.7157
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- Exportiere Struktur von Tabelle acore_chars.account_data
CREATE TABLE IF NOT EXISTS `account_data` (
  `accountId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Account Identifier',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `time` int unsigned NOT NULL DEFAULT '0',
  `data` blob NOT NULL,
  PRIMARY KEY (`accountId`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.account_instance_times
CREATE TABLE IF NOT EXISTS `account_instance_times` (
  `accountId` int unsigned NOT NULL,
  `instanceId` int unsigned NOT NULL DEFAULT '0',
  `releaseTime` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`accountId`,`instanceId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.account_tutorial
CREATE TABLE IF NOT EXISTS `account_tutorial` (
  `accountId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Account Identifier',
  `tut0` int unsigned NOT NULL DEFAULT '0',
  `tut1` int unsigned NOT NULL DEFAULT '0',
  `tut2` int unsigned NOT NULL DEFAULT '0',
  `tut3` int unsigned NOT NULL DEFAULT '0',
  `tut4` int unsigned NOT NULL DEFAULT '0',
  `tut5` int unsigned NOT NULL DEFAULT '0',
  `tut6` int unsigned NOT NULL DEFAULT '0',
  `tut7` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`accountId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.active_arena_season
CREATE TABLE IF NOT EXISTS `active_arena_season` (
  `season_id` tinyint unsigned NOT NULL,
  `season_state` tinyint unsigned NOT NULL COMMENT 'Supported 2 states: 0 - disabled; 1 - in progress.'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.addons
CREATE TABLE IF NOT EXISTS `addons` (
  `name` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `crc` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Addons';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.arena_team
CREATE TABLE IF NOT EXISTS `arena_team` (
  `arenaTeamId` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `captainGuid` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `rating` smallint unsigned NOT NULL DEFAULT '0',
  `seasonGames` smallint unsigned NOT NULL DEFAULT '0',
  `seasonWins` smallint unsigned NOT NULL DEFAULT '0',
  `weekGames` smallint unsigned NOT NULL DEFAULT '0',
  `weekWins` smallint unsigned NOT NULL DEFAULT '0',
  `rank` int unsigned NOT NULL DEFAULT '0',
  `backgroundColor` int unsigned NOT NULL DEFAULT '0',
  `emblemStyle` tinyint unsigned NOT NULL DEFAULT '0',
  `emblemColor` int unsigned NOT NULL DEFAULT '0',
  `borderStyle` tinyint unsigned NOT NULL DEFAULT '0',
  `borderColor` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`arenaTeamId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.arena_team_member
CREATE TABLE IF NOT EXISTS `arena_team_member` (
  `arenaTeamId` int unsigned NOT NULL DEFAULT '0',
  `guid` int unsigned NOT NULL DEFAULT '0',
  `weekGames` smallint unsigned NOT NULL DEFAULT '0',
  `weekWins` smallint unsigned NOT NULL DEFAULT '0',
  `seasonGames` smallint unsigned NOT NULL DEFAULT '0',
  `seasonWins` smallint unsigned NOT NULL DEFAULT '0',
  `personalRating` smallint NOT NULL DEFAULT '0',
  PRIMARY KEY (`arenaTeamId`,`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.auctionhouse
CREATE TABLE IF NOT EXISTS `auctionhouse` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `houseid` tinyint unsigned NOT NULL DEFAULT '7',
  `itemguid` int unsigned NOT NULL DEFAULT '0',
  `itemowner` int unsigned NOT NULL DEFAULT '0',
  `buyoutprice` int unsigned NOT NULL DEFAULT '0',
  `time` int unsigned NOT NULL DEFAULT '0',
  `buyguid` int unsigned NOT NULL DEFAULT '0',
  `lastbid` int unsigned NOT NULL DEFAULT '0',
  `startbid` int unsigned NOT NULL DEFAULT '0',
  `deposit` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `item_guid` (`itemguid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.banned_addons
CREATE TABLE IF NOT EXISTS `banned_addons` (
  `Id` int unsigned NOT NULL AUTO_INCREMENT,
  `Name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Version` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `Timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`Id`),
  UNIQUE KEY `idx_name_ver` (`Name`,`Version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.battleground_deserters
CREATE TABLE IF NOT EXISTS `battleground_deserters` (
  `guid` int unsigned NOT NULL COMMENT 'characters.guid',
  `type` tinyint unsigned NOT NULL COMMENT 'type of the desertion',
  `datetime` datetime NOT NULL COMMENT 'datetime of the desertion'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.beastmaster_tamed_pets
CREATE TABLE IF NOT EXISTS `beastmaster_tamed_pets` (
  `owner_guid` int unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `name` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date_tamed` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`owner_guid`,`entry`),
  KEY `idx_beastmaster_tamed_pets_owner_guid` (`owner_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.bugreport
CREATE TABLE IF NOT EXISTS `bugreport` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Identifier',
  `type` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Debug System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.calendar_events
CREATE TABLE IF NOT EXISTS `calendar_events` (
  `id` bigint unsigned NOT NULL DEFAULT '0',
  `creator` int unsigned NOT NULL DEFAULT '0',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `type` tinyint unsigned NOT NULL DEFAULT '4',
  `dungeon` int NOT NULL DEFAULT '-1',
  `eventtime` int unsigned NOT NULL DEFAULT '0',
  `flags` int unsigned NOT NULL DEFAULT '0',
  `time2` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.calendar_invites
CREATE TABLE IF NOT EXISTS `calendar_invites` (
  `id` bigint unsigned NOT NULL DEFAULT '0',
  `event` bigint unsigned NOT NULL DEFAULT '0',
  `invitee` int unsigned NOT NULL DEFAULT '0',
  `sender` int unsigned NOT NULL DEFAULT '0',
  `status` tinyint unsigned NOT NULL DEFAULT '0',
  `statustime` int unsigned NOT NULL DEFAULT '0',
  `rank` tinyint unsigned NOT NULL DEFAULT '0',
  `text` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.channels
CREATE TABLE IF NOT EXISTS `channels` (
  `channelId` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `team` int unsigned NOT NULL,
  `announce` tinyint unsigned NOT NULL DEFAULT '1',
  `ownership` tinyint unsigned NOT NULL DEFAULT '1',
  `password` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lastUsed` int unsigned NOT NULL,
  PRIMARY KEY (`channelId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Channel System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.channels_bans
CREATE TABLE IF NOT EXISTS `channels_bans` (
  `channelId` int unsigned NOT NULL,
  `playerGUID` int unsigned NOT NULL,
  `banTime` int unsigned NOT NULL,
  PRIMARY KEY (`channelId`,`playerGUID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.channels_rights
CREATE TABLE IF NOT EXISTS `channels_rights` (
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `flags` int unsigned NOT NULL,
  `speakdelay` int unsigned NOT NULL,
  `joinmessage` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `delaymessage` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `moderators` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_account_data
CREATE TABLE IF NOT EXISTS `character_account_data` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `time` int unsigned NOT NULL DEFAULT '0',
  `data` blob NOT NULL,
  PRIMARY KEY (`guid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_achievement
CREATE TABLE IF NOT EXISTS `character_achievement` (
  `guid` int unsigned NOT NULL,
  `achievement` smallint unsigned NOT NULL,
  `date` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`achievement`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_achievement_offline_updates
CREATE TABLE IF NOT EXISTS `character_achievement_offline_updates` (
  `guid` int unsigned NOT NULL COMMENT 'Character''s GUID',
  `update_type` tinyint unsigned NOT NULL COMMENT 'Supported types: 1 - COMPLETE_ACHIEVEMENT; 2 - UPDATE_CRITERIA',
  `arg1` int unsigned NOT NULL COMMENT 'For type 1: achievement ID; for type 2: ACHIEVEMENT_CRITERIA_TYPE',
  `arg2` int unsigned DEFAULT NULL COMMENT 'For type 2: miscValue1 for updating achievement criteria',
  `arg3` int unsigned DEFAULT NULL COMMENT 'For type 2: miscValue2 for updating achievement criteria',
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Stores updates to character achievements when the character was offline';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_achievement_progress
CREATE TABLE IF NOT EXISTS `character_achievement_progress` (
  `guid` int unsigned NOT NULL,
  `criteria` smallint unsigned NOT NULL,
  `counter` int unsigned NOT NULL,
  `date` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`criteria`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_action
CREATE TABLE IF NOT EXISTS `character_action` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `spec` tinyint unsigned NOT NULL DEFAULT '0',
  `button` tinyint unsigned NOT NULL DEFAULT '0',
  `action` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`spec`,`button`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_arena_stats
CREATE TABLE IF NOT EXISTS `character_arena_stats` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `slot` tinyint unsigned NOT NULL DEFAULT '0',
  `matchMakerRating` smallint unsigned NOT NULL DEFAULT '0',
  `maxMMR` smallint NOT NULL,
  PRIMARY KEY (`guid`,`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_aura
CREATE TABLE IF NOT EXISTS `character_aura` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `casterGuid` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'Full Global Unique Identifier',
  `itemGuid` bigint unsigned NOT NULL DEFAULT '0',
  `spell` int unsigned NOT NULL DEFAULT '0',
  `effectMask` tinyint unsigned NOT NULL DEFAULT '0',
  `recalculateMask` tinyint unsigned NOT NULL DEFAULT '0',
  `stackCount` tinyint unsigned NOT NULL DEFAULT '1',
  `amount0` int NOT NULL DEFAULT '0',
  `amount1` int NOT NULL DEFAULT '0',
  `amount2` int NOT NULL DEFAULT '0',
  `base_amount0` int NOT NULL DEFAULT '0',
  `base_amount1` int NOT NULL DEFAULT '0',
  `base_amount2` int NOT NULL DEFAULT '0',
  `maxDuration` int NOT NULL DEFAULT '0',
  `remainTime` int NOT NULL DEFAULT '0',
  `remainCharges` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`casterGuid`,`itemGuid`,`spell`,`effectMask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_banned
CREATE TABLE IF NOT EXISTS `character_banned` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `bandate` int unsigned NOT NULL DEFAULT '0',
  `unbandate` int unsigned NOT NULL DEFAULT '0',
  `bannedby` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `banreason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `active` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`guid`,`bandate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Ban List';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_battleground_random
CREATE TABLE IF NOT EXISTS `character_battleground_random` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_brew_of_the_month
CREATE TABLE IF NOT EXISTS `character_brew_of_the_month` (
  `guid` int unsigned NOT NULL,
  `lastEventId` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_declinedname
CREATE TABLE IF NOT EXISTS `character_declinedname` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `genitive` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `dative` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `accusative` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `instrumental` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `prepositional` varchar(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_entry_point
CREATE TABLE IF NOT EXISTS `character_entry_point` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `joinX` float NOT NULL DEFAULT '0',
  `joinY` float NOT NULL DEFAULT '0',
  `joinZ` float NOT NULL DEFAULT '0',
  `joinO` float NOT NULL DEFAULT '0',
  `joinMapId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Map Identifier',
  `taxiPath0` int unsigned NOT NULL DEFAULT '0',
  `taxiPath1` int unsigned NOT NULL DEFAULT '0',
  `mountSpell` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_equipmentsets
CREATE TABLE IF NOT EXISTS `character_equipmentsets` (
  `guid` int NOT NULL DEFAULT '0',
  `setguid` bigint NOT NULL AUTO_INCREMENT,
  `setindex` tinyint unsigned NOT NULL DEFAULT '0',
  `name` varchar(31) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `iconname` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `ignore_mask` int unsigned NOT NULL DEFAULT '0',
  `item0` int unsigned NOT NULL DEFAULT '0',
  `item1` int unsigned NOT NULL DEFAULT '0',
  `item2` int unsigned NOT NULL DEFAULT '0',
  `item3` int unsigned NOT NULL DEFAULT '0',
  `item4` int unsigned NOT NULL DEFAULT '0',
  `item5` int unsigned NOT NULL DEFAULT '0',
  `item6` int unsigned NOT NULL DEFAULT '0',
  `item7` int unsigned NOT NULL DEFAULT '0',
  `item8` int unsigned NOT NULL DEFAULT '0',
  `item9` int unsigned NOT NULL DEFAULT '0',
  `item10` int unsigned NOT NULL DEFAULT '0',
  `item11` int unsigned NOT NULL DEFAULT '0',
  `item12` int unsigned NOT NULL DEFAULT '0',
  `item13` int unsigned NOT NULL DEFAULT '0',
  `item14` int unsigned NOT NULL DEFAULT '0',
  `item15` int unsigned NOT NULL DEFAULT '0',
  `item16` int unsigned NOT NULL DEFAULT '0',
  `item17` int unsigned NOT NULL DEFAULT '0',
  `item18` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`setguid`),
  UNIQUE KEY `idx_set` (`guid`,`setguid`,`setindex`),
  KEY `Idx_setindex` (`setindex`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_gifts
CREATE TABLE IF NOT EXISTS `character_gifts` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `item_guid` int unsigned NOT NULL DEFAULT '0',
  `entry` int unsigned NOT NULL DEFAULT '0',
  `flags` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`item_guid`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_glyphs
CREATE TABLE IF NOT EXISTS `character_glyphs` (
  `guid` int unsigned NOT NULL,
  `talentGroup` tinyint unsigned NOT NULL DEFAULT '0',
  `glyph1` smallint unsigned DEFAULT '0',
  `glyph2` smallint unsigned DEFAULT '0',
  `glyph3` smallint unsigned DEFAULT '0',
  `glyph4` smallint unsigned DEFAULT '0',
  `glyph5` smallint unsigned DEFAULT '0',
  `glyph6` smallint unsigned DEFAULT '0',
  PRIMARY KEY (`guid`,`talentGroup`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_homebind
CREATE TABLE IF NOT EXISTS `character_homebind` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `mapId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map Identifier',
  `zoneId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Zone Identifier',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_instance
CREATE TABLE IF NOT EXISTS `character_instance` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `instance` int unsigned NOT NULL DEFAULT '0',
  `permanent` tinyint unsigned NOT NULL DEFAULT '0',
  `extended` tinyint unsigned NOT NULL,
  PRIMARY KEY (`guid`,`instance`),
  KEY `instance` (`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_inventory
CREATE TABLE IF NOT EXISTS `character_inventory` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `bag` int unsigned NOT NULL DEFAULT '0',
  `slot` tinyint unsigned NOT NULL DEFAULT '0',
  `item` int unsigned NOT NULL DEFAULT '0' COMMENT 'Item Global Unique Identifier',
  PRIMARY KEY (`item`),
  UNIQUE KEY `guid` (`guid`,`bag`,`slot`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_pet
CREATE TABLE IF NOT EXISTS `character_pet` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `entry` int unsigned NOT NULL DEFAULT '0',
  `owner` int unsigned NOT NULL DEFAULT '0',
  `modelid` int unsigned DEFAULT '0',
  `CreatedBySpell` int unsigned DEFAULT '0',
  `PetType` tinyint unsigned NOT NULL DEFAULT '0',
  `level` smallint unsigned NOT NULL DEFAULT '1',
  `exp` int unsigned NOT NULL DEFAULT '0',
  `Reactstate` tinyint unsigned NOT NULL DEFAULT '0',
  `name` varchar(21) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'Pet',
  `renamed` tinyint unsigned NOT NULL DEFAULT '0',
  `slot` tinyint unsigned NOT NULL DEFAULT '0',
  `curhealth` int unsigned NOT NULL DEFAULT '1',
  `curmana` int unsigned NOT NULL DEFAULT '0',
  `curhappiness` int unsigned NOT NULL DEFAULT '0',
  `savetime` int unsigned NOT NULL DEFAULT '0',
  `abdata` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `owner` (`owner`),
  KEY `idx_slot` (`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pet System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_pet_declinedname
CREATE TABLE IF NOT EXISTS `character_pet_declinedname` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `owner` int unsigned NOT NULL DEFAULT '0',
  `genitive` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `dative` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `accusative` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `instrumental` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `prepositional` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `owner_key` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_prestige
CREATE TABLE IF NOT EXISTS `character_prestige` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `prestige_level` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Current prestige level (0-10)',
  `prestige_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date of last prestige',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prestige levels for level 255 characters';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_prestige_stats
CREATE TABLE IF NOT EXISTS `character_prestige_stats` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `total_prestiges` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total number of prestige resets',
  `highest_prestige` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Highest prestige level reached',
  `first_prestige_date` datetime DEFAULT NULL COMMENT 'Date of first prestige',
  `last_prestige_date` datetime DEFAULT NULL COMMENT 'Date of most recent prestige',
  `total_levels_gained` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total levels gained across all prestiges',
  PRIMARY KEY (`guid`),
  KEY `idx_highest_prestige` (`highest_prestige`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prestige statistics and leaderboards';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_queststatus
CREATE TABLE IF NOT EXISTS `character_queststatus` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  `status` tinyint unsigned NOT NULL DEFAULT '0',
  `explored` tinyint unsigned NOT NULL DEFAULT '0',
  `timer` int unsigned NOT NULL DEFAULT '0',
  `mobcount1` smallint unsigned NOT NULL DEFAULT '0',
  `mobcount2` smallint unsigned NOT NULL DEFAULT '0',
  `mobcount3` smallint unsigned NOT NULL DEFAULT '0',
  `mobcount4` smallint unsigned NOT NULL DEFAULT '0',
  `itemcount1` smallint unsigned NOT NULL DEFAULT '0',
  `itemcount2` smallint unsigned NOT NULL DEFAULT '0',
  `itemcount3` smallint unsigned NOT NULL DEFAULT '0',
  `itemcount4` smallint unsigned NOT NULL DEFAULT '0',
  `itemcount5` smallint unsigned NOT NULL DEFAULT '0',
  `itemcount6` smallint unsigned NOT NULL DEFAULT '0',
  `playercount` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_queststatus_daily
CREATE TABLE IF NOT EXISTS `character_queststatus_daily` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  `time` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`quest`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_queststatus_monthly
CREATE TABLE IF NOT EXISTS `character_queststatus_monthly` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`guid`,`quest`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_queststatus_rewarded
CREATE TABLE IF NOT EXISTS `character_queststatus_rewarded` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  `active` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`guid`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_queststatus_seasonal
CREATE TABLE IF NOT EXISTS `character_queststatus_seasonal` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  `event` int unsigned NOT NULL DEFAULT '0' COMMENT 'Event Identifier',
  PRIMARY KEY (`guid`,`quest`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_queststatus_weekly
CREATE TABLE IF NOT EXISTS `character_queststatus_weekly` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`guid`,`quest`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_reputation
CREATE TABLE IF NOT EXISTS `character_reputation` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `faction` smallint unsigned NOT NULL DEFAULT '0',
  `standing` int NOT NULL DEFAULT '0',
  `flags` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_settings
CREATE TABLE IF NOT EXISTS `character_settings` (
  `guid` int unsigned NOT NULL,
  `source` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`guid`,`source`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player Settings';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_skills
CREATE TABLE IF NOT EXISTS `character_skills` (
  `guid` int unsigned NOT NULL COMMENT 'Global Unique Identifier',
  `skill` smallint unsigned NOT NULL,
  `value` smallint unsigned NOT NULL,
  `max` smallint unsigned NOT NULL,
  PRIMARY KEY (`guid`,`skill`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_social
CREATE TABLE IF NOT EXISTS `character_social` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Character Global Unique Identifier',
  `friend` int unsigned NOT NULL DEFAULT '0' COMMENT 'Friend Global Unique Identifier',
  `flags` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Friend Flags',
  `note` varchar(48) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'Friend Note',
  PRIMARY KEY (`guid`,`friend`,`flags`),
  KEY `friend` (`friend`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_spell
CREATE TABLE IF NOT EXISTS `character_spell` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `spell` int unsigned NOT NULL DEFAULT '0' COMMENT 'Spell Identifier',
  `specMask` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`guid`,`spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_spell_cooldown
CREATE TABLE IF NOT EXISTS `character_spell_cooldown` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier, Low part',
  `spell` int unsigned NOT NULL DEFAULT '0' COMMENT 'Spell Identifier',
  `category` int unsigned DEFAULT '0',
  `item` int unsigned NOT NULL DEFAULT '0' COMMENT 'Item Identifier',
  `time` int unsigned NOT NULL DEFAULT '0',
  `needSend` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`guid`,`spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_stats
CREATE TABLE IF NOT EXISTS `character_stats` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier, Low part',
  `maxhealth` int unsigned NOT NULL DEFAULT '0',
  `maxpower1` int unsigned NOT NULL DEFAULT '0',
  `maxpower2` int unsigned NOT NULL DEFAULT '0',
  `maxpower3` int unsigned NOT NULL DEFAULT '0',
  `maxpower4` int unsigned NOT NULL DEFAULT '0',
  `maxpower5` int unsigned NOT NULL DEFAULT '0',
  `maxpower6` int unsigned NOT NULL DEFAULT '0',
  `maxpower7` int unsigned NOT NULL DEFAULT '0',
  `strength` int unsigned NOT NULL DEFAULT '0',
  `agility` int unsigned NOT NULL DEFAULT '0',
  `stamina` int unsigned NOT NULL DEFAULT '0',
  `intellect` int unsigned NOT NULL DEFAULT '0',
  `spirit` int unsigned NOT NULL DEFAULT '0',
  `armor` int unsigned NOT NULL DEFAULT '0',
  `resHoly` int unsigned NOT NULL DEFAULT '0',
  `resFire` int unsigned NOT NULL DEFAULT '0',
  `resNature` int unsigned NOT NULL DEFAULT '0',
  `resFrost` int unsigned NOT NULL DEFAULT '0',
  `resShadow` int unsigned NOT NULL DEFAULT '0',
  `resArcane` int unsigned NOT NULL DEFAULT '0',
  `blockPct` float NOT NULL DEFAULT '0',
  `dodgePct` float NOT NULL DEFAULT '0',
  `parryPct` float NOT NULL DEFAULT '0',
  `critPct` float NOT NULL DEFAULT '0',
  `rangedCritPct` float NOT NULL DEFAULT '0',
  `spellCritPct` float NOT NULL DEFAULT '0',
  `attackPower` int unsigned NOT NULL DEFAULT '0',
  `rangedAttackPower` int unsigned NOT NULL DEFAULT '0',
  `spellPower` int unsigned NOT NULL DEFAULT '0',
  `resilience` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`),
  CONSTRAINT `character_stats_chk_1` CHECK (((`blockPct` >= 0) and (`dodgePct` >= 0) and (`parryPct` >= 0) and (`critPct` >= 0) and (`rangedCritPct` >= 0) and (`spellCritPct` >= 0)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_talent
CREATE TABLE IF NOT EXISTS `character_talent` (
  `guid` int unsigned NOT NULL,
  `spell` int unsigned NOT NULL,
  `specMask` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.character_transmog
CREATE TABLE IF NOT EXISTS `character_transmog` (
  `player_guid` int unsigned DEFAULT NULL,
  `slot` varchar(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `item` int unsigned DEFAULT NULL,
  `real_item` int unsigned DEFAULT NULL,
  UNIQUE KEY `player_and_slot` (`player_guid`,`slot`) USING BTREE,
  KEY `player_and_slot_key` (`player_guid`,`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.characters
CREATE TABLE IF NOT EXISTS `characters` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `account` int unsigned NOT NULL DEFAULT '0' COMMENT 'Account Identifier',
  `name` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `race` tinyint unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `gender` tinyint unsigned NOT NULL DEFAULT '0',
  `level` tinyint unsigned NOT NULL DEFAULT '0',
  `xp` int unsigned NOT NULL DEFAULT '0',
  `money` int unsigned NOT NULL DEFAULT '0',
  `skin` tinyint unsigned NOT NULL DEFAULT '0',
  `face` tinyint unsigned NOT NULL DEFAULT '0',
  `hairStyle` tinyint unsigned NOT NULL DEFAULT '0',
  `hairColor` tinyint unsigned NOT NULL DEFAULT '0',
  `facialStyle` tinyint unsigned NOT NULL DEFAULT '0',
  `bankSlots` tinyint unsigned NOT NULL DEFAULT '0',
  `restState` tinyint unsigned NOT NULL DEFAULT '0',
  `playerFlags` int unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `map` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map Identifier',
  `instance_id` int unsigned NOT NULL DEFAULT '0',
  `instance_mode_mask` tinyint unsigned NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `taximask` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `online` tinyint unsigned NOT NULL DEFAULT '0',
  `cinematic` tinyint unsigned NOT NULL DEFAULT '0',
  `totaltime` int unsigned NOT NULL DEFAULT '0',
  `leveltime` int unsigned NOT NULL DEFAULT '0',
  `logout_time` int unsigned NOT NULL DEFAULT '0',
  `is_logout_resting` tinyint unsigned NOT NULL DEFAULT '0',
  `rest_bonus` float NOT NULL DEFAULT '0',
  `resettalents_cost` int unsigned NOT NULL DEFAULT '0',
  `resettalents_time` int unsigned NOT NULL DEFAULT '0',
  `trans_x` float NOT NULL DEFAULT '0',
  `trans_y` float NOT NULL DEFAULT '0',
  `trans_z` float NOT NULL DEFAULT '0',
  `trans_o` float NOT NULL DEFAULT '0',
  `transguid` int DEFAULT '0',
  `extra_flags` smallint unsigned NOT NULL DEFAULT '0',
  `stable_slots` tinyint unsigned NOT NULL DEFAULT '0',
  `at_login` smallint unsigned NOT NULL DEFAULT '0',
  `zone` smallint unsigned NOT NULL DEFAULT '0',
  `death_expire_time` int unsigned NOT NULL DEFAULT '0',
  `taxi_path` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `arenaPoints` int unsigned NOT NULL DEFAULT '0',
  `totalHonorPoints` int unsigned NOT NULL DEFAULT '0',
  `todayHonorPoints` int unsigned NOT NULL DEFAULT '0',
  `yesterdayHonorPoints` int unsigned NOT NULL DEFAULT '0',
  `totalKills` int unsigned NOT NULL DEFAULT '0',
  `todayKills` smallint unsigned NOT NULL DEFAULT '0',
  `yesterdayKills` smallint unsigned NOT NULL DEFAULT '0',
  `chosenTitle` int unsigned NOT NULL DEFAULT '0',
  `knownCurrencies` bigint unsigned NOT NULL DEFAULT '0',
  `watchedFaction` int unsigned NOT NULL DEFAULT '0',
  `drunk` tinyint unsigned NOT NULL DEFAULT '0',
  `health` int unsigned NOT NULL DEFAULT '0',
  `power1` int unsigned NOT NULL DEFAULT '0',
  `power2` int unsigned NOT NULL DEFAULT '0',
  `power3` int unsigned NOT NULL DEFAULT '0',
  `power4` int unsigned NOT NULL DEFAULT '0',
  `power5` int unsigned NOT NULL DEFAULT '0',
  `power6` int unsigned NOT NULL DEFAULT '0',
  `power7` int unsigned NOT NULL DEFAULT '0',
  `latency` int unsigned DEFAULT '0',
  `talentGroupsCount` tinyint unsigned NOT NULL DEFAULT '1',
  `activeTalentGroup` tinyint unsigned NOT NULL DEFAULT '0',
  `exploredZones` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `equipmentCache` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ammoId` int unsigned NOT NULL DEFAULT '0',
  `knownTitles` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `actionBars` tinyint unsigned NOT NULL DEFAULT '0',
  `grantableLevels` tinyint unsigned NOT NULL DEFAULT '0',
  `order` tinyint DEFAULT NULL,
  `creation_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleteInfos_Account` int unsigned DEFAULT NULL,
  `deleteInfos_Name` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deleteDate` int unsigned DEFAULT NULL,
  `innTriggerId` int unsigned NOT NULL,
  `extraBonusTalentCount` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`),
  KEY `idx_account` (`account`),
  KEY `idx_online` (`online`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.characters_npcbot
CREATE TABLE IF NOT EXISTS `characters_npcbot` (
  `entry` int unsigned NOT NULL COMMENT 'creature_template.entry',
  `owner` int unsigned NOT NULL DEFAULT '0' COMMENT 'characters.guid (lowguid)',
  `roles` int unsigned NOT NULL COMMENT 'bitmask: tank(1),dps(2),heal(4),ranged(8)',
  `spec` tinyint unsigned NOT NULL DEFAULT '1',
  `faction` int unsigned NOT NULL DEFAULT '35',
  `equipMhEx` int unsigned NOT NULL DEFAULT '0',
  `equipOhEx` int unsigned NOT NULL DEFAULT '0',
  `equipRhEx` int unsigned NOT NULL DEFAULT '0',
  `equipHead` int unsigned NOT NULL DEFAULT '0',
  `equipShoulders` int unsigned NOT NULL DEFAULT '0',
  `equipChest` int unsigned NOT NULL DEFAULT '0',
  `equipWaist` int unsigned NOT NULL DEFAULT '0',
  `equipLegs` int unsigned NOT NULL DEFAULT '0',
  `equipFeet` int unsigned NOT NULL DEFAULT '0',
  `equipWrist` int unsigned NOT NULL DEFAULT '0',
  `equipHands` int unsigned NOT NULL DEFAULT '0',
  `equipBack` int unsigned NOT NULL DEFAULT '0',
  `equipBody` int unsigned NOT NULL DEFAULT '0',
  `equipFinger1` int unsigned NOT NULL DEFAULT '0',
  `equipFinger2` int unsigned NOT NULL DEFAULT '0',
  `equipTrinket1` int unsigned NOT NULL DEFAULT '0',
  `equipTrinket2` int unsigned NOT NULL DEFAULT '0',
  `equipNeck` int unsigned NOT NULL DEFAULT '0',
  `spells_disabled` longtext,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.characters_npcbot_group_member
CREATE TABLE IF NOT EXISTS `characters_npcbot_group_member` (
  `guid` int unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `memberFlags` tinyint unsigned NOT NULL DEFAULT '0',
  `subgroup` tinyint unsigned NOT NULL DEFAULT '0',
  `roles` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.characters_npcbot_stats
CREATE TABLE IF NOT EXISTS `characters_npcbot_stats` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `maxhealth` int unsigned NOT NULL DEFAULT '0',
  `maxpower` int unsigned NOT NULL DEFAULT '0',
  `strength` int unsigned NOT NULL DEFAULT '0',
  `agility` int unsigned NOT NULL DEFAULT '0',
  `stamina` int unsigned NOT NULL DEFAULT '0',
  `intellect` int unsigned NOT NULL DEFAULT '0',
  `spirit` int unsigned NOT NULL DEFAULT '0',
  `armor` int unsigned NOT NULL DEFAULT '0',
  `defense` int unsigned NOT NULL DEFAULT '0',
  `resHoly` int unsigned NOT NULL DEFAULT '0',
  `resFire` int unsigned NOT NULL DEFAULT '0',
  `resNature` int unsigned NOT NULL DEFAULT '0',
  `resFrost` int unsigned NOT NULL DEFAULT '0',
  `resShadow` int unsigned NOT NULL DEFAULT '0',
  `resArcane` int unsigned NOT NULL DEFAULT '0',
  `blockPct` float unsigned NOT NULL DEFAULT '0',
  `dodgePct` float unsigned NOT NULL DEFAULT '0',
  `parryPct` float unsigned NOT NULL DEFAULT '0',
  `critPct` float unsigned NOT NULL DEFAULT '0',
  `attackPower` int unsigned NOT NULL DEFAULT '0',
  `spellPower` int unsigned NOT NULL DEFAULT '0',
  `spellPen` int unsigned NOT NULL DEFAULT '0',
  `hastePct` float unsigned NOT NULL DEFAULT '0',
  `hitBonusPct` float unsigned NOT NULL DEFAULT '0',
  `expertise` int unsigned NOT NULL DEFAULT '0',
  `armorPenPct` float unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.characters_npcbot_transmog
CREATE TABLE IF NOT EXISTS `characters_npcbot_transmog` (
  `entry` int unsigned NOT NULL,
  `slot` tinyint unsigned NOT NULL,
  `item_id` int unsigned NOT NULL DEFAULT '0',
  `fake_id` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`,`slot`),
  CONSTRAINT `bot_id` FOREIGN KEY (`entry`) REFERENCES `characters_npcbot` (`entry`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.corpse
CREATE TABLE IF NOT EXISTS `corpse` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Character Global Unique Identifier',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `mapId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map Identifier',
  `phaseMask` int unsigned NOT NULL DEFAULT '1',
  `displayId` int unsigned NOT NULL DEFAULT '0',
  `itemCache` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `bytes1` int unsigned NOT NULL DEFAULT '0',
  `bytes2` int unsigned NOT NULL DEFAULT '0',
  `guildId` int unsigned NOT NULL DEFAULT '0',
  `flags` tinyint unsigned NOT NULL DEFAULT '0',
  `dynFlags` tinyint unsigned NOT NULL DEFAULT '0',
  `time` int unsigned NOT NULL DEFAULT '0',
  `corpseType` tinyint unsigned NOT NULL DEFAULT '0',
  `instanceId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Instance Identifier',
  PRIMARY KEY (`guid`),
  KEY `idx_type` (`corpseType`),
  KEY `idx_instance` (`instanceId`),
  KEY `idx_time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Death System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.creature_respawn
CREATE TABLE IF NOT EXISTS `creature_respawn` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `respawnTime` int unsigned NOT NULL DEFAULT '0',
  `mapId` smallint unsigned NOT NULL DEFAULT '0',
  `instanceId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Instance Identifier',
  PRIMARY KEY (`guid`,`instanceId`),
  KEY `idx_instance` (`instanceId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Grid Loading System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.custom_solocraft_character_stats
CREATE TABLE IF NOT EXISTS `custom_solocraft_character_stats` (
  `GUID` bigint unsigned NOT NULL,
  `Difficulty` float NOT NULL,
  `GroupSize` int NOT NULL,
  `SpellPower` int unsigned NOT NULL DEFAULT '0',
  `Stats` float NOT NULL DEFAULT '100',
  PRIMARY KEY (`GUID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_bin;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.custom_transmogrification
CREATE TABLE IF NOT EXISTS `custom_transmogrification` (
  `GUID` int unsigned NOT NULL COMMENT 'Item guidLow',
  `FakeEntry` int unsigned NOT NULL COMMENT 'Item entry',
  `Owner` int unsigned NOT NULL COMMENT 'Player guidLow',
  PRIMARY KEY (`GUID`),
  KEY `Owner` (`Owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='6_2';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.custom_transmogrification_sets
CREATE TABLE IF NOT EXISTS `custom_transmogrification_sets` (
  `Owner` int unsigned NOT NULL COMMENT 'Player guidlow',
  `PresetID` tinyint unsigned NOT NULL COMMENT 'Preset identifier',
  `SetName` text COMMENT 'SetName',
  `SetData` text COMMENT 'Slot1 Entry1 Slot2 Entry2',
  PRIMARY KEY (`Owner`,`PresetID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COMMENT='6_1';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.custom_unlocked_appearances
CREATE TABLE IF NOT EXISTS `custom_unlocked_appearances` (
  `account_id` int unsigned NOT NULL,
  `item_template_id` mediumint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`account_id`,`item_template_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.daily_players_reports
CREATE TABLE IF NOT EXISTS `daily_players_reports` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `creation_time` int unsigned NOT NULL DEFAULT '0',
  `average` float NOT NULL DEFAULT '0',
  `total_reports` bigint unsigned NOT NULL DEFAULT '0',
  `speed_reports` bigint unsigned NOT NULL DEFAULT '0',
  `fly_reports` bigint unsigned NOT NULL DEFAULT '0',
  `jump_reports` bigint unsigned NOT NULL DEFAULT '0',
  `waterwalk_reports` bigint unsigned NOT NULL DEFAULT '0',
  `teleportplane_reports` bigint unsigned NOT NULL DEFAULT '0',
  `climb_reports` bigint unsigned NOT NULL DEFAULT '0',
  `teleport_reports` bigint unsigned NOT NULL DEFAULT '0',
  `ignorecontrol_reports` bigint unsigned NOT NULL DEFAULT '0',
  `zaxis_reports` bigint unsigned NOT NULL DEFAULT '0',
  `antiswim_reports` bigint unsigned NOT NULL DEFAULT '0',
  `gravity_reports` bigint unsigned NOT NULL DEFAULT '0',
  `antiknockback_reports` bigint unsigned NOT NULL DEFAULT '0',
  `no_fall_damage_reports` bigint unsigned NOT NULL DEFAULT '0',
  `op_ack_hack_reports` bigint unsigned NOT NULL DEFAULT '0',
  `counter_measures_reports` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_achievement_definitions
CREATE TABLE IF NOT EXISTS `dc_achievement_definitions` (
  `achievement_id` int unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) NOT NULL,
  `reward_mastery_points` int unsigned NOT NULL DEFAULT '0',
  `reward_tokens` int unsigned NOT NULL DEFAULT '0',
  `is_hidden` tinyint(1) NOT NULL DEFAULT '0',
  `unlock_requirement` int unsigned NOT NULL DEFAULT '0',
  `unlock_type` varchar(50) NOT NULL,
  PRIMARY KEY (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Achievement definitions';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_aoe_loot_settings
CREATE TABLE IF NOT EXISTS `dc_aoe_loot_settings` (
  `character_guid` int unsigned NOT NULL,
  `enabled` tinyint(1) DEFAULT '1',
  `show_messages` tinyint(1) DEFAULT '1',
  `min_quality` tinyint unsigned DEFAULT '0',
  `auto_skin` tinyint(1) DEFAULT '0',
  `smart_loot` tinyint(1) DEFAULT '1',
  `loot_range` float DEFAULT '30',
  PRIMARY KEY (`character_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='AOE Loot addon settings per character';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_aoeloot_accumulated
CREATE TABLE IF NOT EXISTS `dc_aoeloot_accumulated` (
  `player_guid` int unsigned NOT NULL,
  `accumulated_gold` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'Total gold looted via AoE',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Accumulated Gold';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_aoeloot_detailed_stats
CREATE TABLE IF NOT EXISTS `dc_aoeloot_detailed_stats` (
  `player_guid` int unsigned NOT NULL,
  `total_items` int unsigned NOT NULL DEFAULT '0',
  `total_gold` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'In copper',
  `poor_vendored` int unsigned NOT NULL DEFAULT '0',
  `vendor_gold` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'Gold from auto-vendoring',
  `skinned` int unsigned NOT NULL DEFAULT '0',
  `mined` int unsigned NOT NULL DEFAULT '0',
  `herbed` int unsigned NOT NULL DEFAULT '0',
  `upgrades` int unsigned NOT NULL DEFAULT '0' COMMENT 'Gear upgrades found',
  `mythic_bonus_items` int unsigned NOT NULL DEFAULT '0' COMMENT 'Bonus items from M+ runs',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Detailed Statistics';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_aoeloot_preferences
CREATE TABLE IF NOT EXISTS `dc_aoeloot_preferences` (
  `player_guid` int unsigned NOT NULL,
  `aoe_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `min_quality` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary',
  `auto_skin` tinyint(1) NOT NULL DEFAULT '1',
  `smart_loot` tinyint(1) NOT NULL DEFAULT '1',
  `auto_vendor_poor` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Auto-vendor poor quality items',
  `ignored_items` text COMMENT 'Comma-separated list of item IDs to ignore',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `show_messages` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Whether to show AoE loot info/debug messages (1=show, 0=hide)',
  PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Player Preferences';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_artifact_mastery_events
CREATE TABLE IF NOT EXISTS `dc_artifact_mastery_events` (
  `event_id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `artifact_id` int unsigned NOT NULL,
  `event_type` enum('unlock','level_up','ability_gained','milestone_reached','reset','rank_up') COLLATE utf8mb4_unicode_ci DEFAULT 'level_up',
  `event_data` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`event_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_artifact_id` (`artifact_id`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Historical log of artifact mastery events';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_challenge_modes
CREATE TABLE IF NOT EXISTS `dc_character_challenge_modes` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `active_modes` int unsigned NOT NULL DEFAULT '0' COMMENT 'Bitwise flags for active challenge modes (1=Hardcore, 2=Semi-Hardcore, 4=Self-Crafted, 8=Iron Man, 16=Solo, 32=Dungeon Only, 64=PvP Only, 128=Quest Only)',
  `activated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When challenge modes were last activated',
  `total_activations` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total number of times challenge modes have been activated',
  `total_deactivations` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total number of times challenge modes have been deactivated',
  `hardcore_deaths` int unsigned NOT NULL DEFAULT '0' COMMENT 'Number of hardcore deaths (if applicable)',
  `last_hardcore_death` timestamp NULL DEFAULT NULL COMMENT 'Timestamp of last hardcore death',
  `character_locked` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 if character is locked due to hardcore death, 0 otherwise',
  `locked_at` timestamp NULL DEFAULT NULL COMMENT 'When character was locked',
  `notes` varchar(255) DEFAULT NULL COMMENT 'Optional notes or comments',
  PRIMARY KEY (`guid`),
  KEY `idx_active_modes` (`active_modes`),
  KEY `idx_locked` (`character_locked`),
  KEY `idx_hardcore_deaths` (`hardcore_deaths`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Current challenge mode settings per character';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_difficulty_completions
CREATE TABLE IF NOT EXISTS `dc_character_difficulty_completions` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID from characters table',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon map ID from acore_world.dc_dungeon_npc_mapping',
  `difficulty` enum('Normal','Heroic','Mythic','Mythic+') COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_completions` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total times completed at this difficulty',
  `best_time_seconds` int unsigned NOT NULL DEFAULT '0' COMMENT '0 = no timed run yet',
  `fastest_completion_date` timestamp NULL DEFAULT NULL,
  `last_completion_date` timestamp NULL DEFAULT NULL,
  `total_deaths` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total deaths across all runs',
  `perfect_runs` int unsigned NOT NULL DEFAULT '0' COMMENT 'Runs with 0 deaths',
  PRIMARY KEY (`guid`,`dungeon_id`,`difficulty`),
  KEY `idx_guid` (`guid`),
  KEY `idx_dungeon_difficulty` (`dungeon_id`,`difficulty`),
  KEY `idx_best_time` (`best_time_seconds`),
  CONSTRAINT `fk_diff_comp_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='v4.0 - Track per-difficulty dungeon completions for each player';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_difficulty_streaks
CREATE TABLE IF NOT EXISTS `dc_character_difficulty_streaks` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID from characters table',
  `difficulty` enum('Normal','Heroic','Mythic','Mythic+') COLLATE utf8mb4_unicode_ci NOT NULL,
  `current_streak` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Current consecutive completions',
  `longest_streak` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Longest streak ever achieved',
  `last_completion_date` timestamp NULL DEFAULT NULL,
  `streak_start_date` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`guid`,`difficulty`),
  KEY `idx_current_streak` (`current_streak`),
  KEY `idx_longest_streak` (`longest_streak`),
  CONSTRAINT `fk_diff_streak_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='v4.0 - Track consecutive completion streaks per difficulty';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_dungeon_npc_respawn
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_npc_respawn` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `npc_entry` int unsigned NOT NULL COMMENT 'NPC entry ID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Which dungeon',
  `is_despawned` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=spawned, 1=despawned',
  `despawn_time` timestamp NULL DEFAULT NULL COMMENT 'When NPC disappeared',
  `last_respawn_attempt` timestamp NULL DEFAULT NULL COMMENT 'Last respawn command used',
  `respawn_cooldown_until` timestamp NULL DEFAULT NULL COMMENT 'Respawn available after this time',
  PRIMARY KEY (`guid`,`npc_entry`,`dungeon_id`),
  KEY `idx_is_despawned` (`is_despawned`),
  KEY `idx_respawn_cooldown` (`respawn_cooldown_until`),
  KEY `idx_respawn_despawn_status` (`is_despawned`,`respawn_cooldown_until`),
  CONSTRAINT `fk_respawn_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Track NPC despawn/respawn status for combat-based system';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_dungeon_progress
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_progress` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon ID from dc_dungeon_quest_mapping',
  `quest_id` int unsigned NOT NULL COMMENT 'Quest ID',
  `quest_type` enum('DAILY','WEEKLY','SPECIAL') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DAILY' COMMENT 'Quest type',
  `status` enum('AVAILABLE','IN_PROGRESS','COMPLETED','FAILED') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'AVAILABLE' COMMENT 'Current quest status',
  `completion_count` int unsigned NOT NULL DEFAULT '0' COMMENT 'Times completed in this cycle',
  `last_completed` timestamp NULL DEFAULT NULL COMMENT 'Last completion time',
  `rewards_claimed` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Reward items claimed (0=no, 1=yes)',
  `token_amount` int unsigned NOT NULL DEFAULT '0' COMMENT 'Tokens earned',
  `gold_earned` int unsigned NOT NULL DEFAULT '0' COMMENT 'Gold earned',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`,`dungeon_id`,`quest_id`),
  KEY `idx_dungeon` (`dungeon_id`),
  KEY `idx_quest` (`quest_id`),
  KEY `idx_status` (`status`),
  KEY `idx_progress_guid_dungeon` (`guid`,`dungeon_id`),
  KEY `idx_progress_status_completed` (`status`,`last_completed`),
  CONSTRAINT `fk_dungeon_progress_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Track dungeon quest progress per character';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_dungeon_quests_completed
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_quests_completed` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon ID',
  `quest_id` int unsigned NOT NULL COMMENT 'Quest ID',
  `completion_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `duration_seconds` int unsigned NOT NULL DEFAULT '0' COMMENT 'Time taken to complete',
  `party_size` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Party/group size',
  `difficulty` enum('NORMAL','HEROIC','MYTHIC') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NORMAL',
  `tokens_earned` int unsigned NOT NULL DEFAULT '0',
  `gold_earned` int unsigned NOT NULL DEFAULT '0',
  `item_drops` text COLLATE utf8mb4_unicode_ci COMMENT 'JSON array of item IDs dropped',
  `achievement_triggered` tinyint unsigned DEFAULT '0' COMMENT 'Any achievement unlocked this run',
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_dungeon` (`dungeon_id`),
  KEY `idx_completion_time` (`completion_time`),
  CONSTRAINT `fk_completed_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Historical dungeon quest completion log';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_dungeon_statistics
CREATE TABLE IF NOT EXISTS `dc_character_dungeon_statistics` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `stat_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'total_quests_completed',
  `stat_value` int unsigned NOT NULL DEFAULT '0',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `total_quests_completed` int unsigned NOT NULL DEFAULT '0',
  `total_tokens_earned` int unsigned NOT NULL DEFAULT '0',
  `total_gold_earned` int unsigned NOT NULL DEFAULT '0',
  `total_dungeons_completed` int unsigned NOT NULL DEFAULT '0',
  `speedrun_records` int unsigned NOT NULL DEFAULT '0' COMMENT 'Speedrun achievements',
  `rare_creatures_defeated` int unsigned NOT NULL DEFAULT '0',
  `achievement_count` int unsigned NOT NULL DEFAULT '0',
  `title_count` int unsigned NOT NULL DEFAULT '0',
  `last_quest_completed` timestamp NULL DEFAULT NULL,
  `current_streak_days` int unsigned NOT NULL DEFAULT '0',
  `longest_streak_days` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`),
  KEY `idx_total_quests` (`total_quests_completed`),
  KEY `idx_total_tokens` (`total_tokens_earned`),
  KEY `idx_stat_name` (`stat_name`),
  CONSTRAINT `fk_stat_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Overall statistics for dungeon quest achievements';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_prestige
CREATE TABLE IF NOT EXISTS `dc_character_prestige` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `prestige_level` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Current prestige level (0-10)',
  `total_prestiges` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total number of times prestiged',
  `last_prestige_time` int unsigned NOT NULL DEFAULT '0' COMMENT 'Unix timestamp of last prestige',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos: Tracks player prestige levels';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_prestige_log
CREATE TABLE IF NOT EXISTS `dc_character_prestige_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry ID',
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `prestige_level` tinyint unsigned NOT NULL COMMENT 'Prestige level achieved',
  `prestige_time` int unsigned NOT NULL COMMENT 'Unix timestamp when prestige occurred',
  `from_level` tinyint unsigned NOT NULL COMMENT 'Character level before prestige',
  `kept_gear` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 if kept gear, 0 if removed',
  PRIMARY KEY (`id`),
  KEY `idx_guid` (`guid`),
  KEY `idx_prestige_level` (`prestige_level`),
  KEY `idx_prestige_time` (`prestige_time`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prestige history log for all characters';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_character_prestige_stats
CREATE TABLE IF NOT EXISTS `dc_character_prestige_stats` (
  `prestige_level` tinyint unsigned NOT NULL,
  `total_players` int unsigned NOT NULL DEFAULT '0',
  `last_updated` int unsigned NOT NULL,
  PRIMARY KEY (`prestige_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos: Statistics for prestige levels';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_duel_class_matchups
CREATE TABLE IF NOT EXISTS `dc_duel_class_matchups` (
  `winner_class` tinyint unsigned NOT NULL,
  `loser_class` tinyint unsigned NOT NULL,
  `total_matches` int unsigned NOT NULL DEFAULT '0',
  `avg_duration_seconds` float NOT NULL DEFAULT '0',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`winner_class`,`loser_class`),
  KEY `idx_matchups` (`winner_class`,`loser_class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos Phased Dueling - Class Matchup Stats';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_duel_history
CREATE TABLE IF NOT EXISTS `dc_duel_history` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `winner_guid` int unsigned NOT NULL,
  `loser_guid` int unsigned NOT NULL,
  `winner_class` tinyint unsigned NOT NULL,
  `loser_class` tinyint unsigned NOT NULL,
  `winner_spec` tinyint unsigned NOT NULL DEFAULT '0',
  `loser_spec` tinyint unsigned NOT NULL DEFAULT '0',
  `duration_seconds` int unsigned NOT NULL DEFAULT '0',
  `winner_damage_dealt` int unsigned NOT NULL DEFAULT '0',
  `loser_damage_dealt` int unsigned NOT NULL DEFAULT '0',
  `duel_type` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=Normal, 1=Tournament, 2=Rated',
  `zone_id` int unsigned NOT NULL DEFAULT '0',
  `area_id` int unsigned NOT NULL DEFAULT '0',
  `duel_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_winner` (`winner_guid`,`duel_time` DESC),
  KEY `idx_loser` (`loser_guid`,`duel_time` DESC),
  KEY `idx_time` (`duel_time` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos Phased Dueling - Match History';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_duel_statistics
CREATE TABLE IF NOT EXISTS `dc_duel_statistics` (
  `player_guid` int unsigned NOT NULL,
  `wins` int unsigned NOT NULL DEFAULT '0',
  `losses` int unsigned NOT NULL DEFAULT '0',
  `draws` int unsigned NOT NULL DEFAULT '0',
  `total_damage_dealt` bigint unsigned NOT NULL DEFAULT '0',
  `total_damage_taken` bigint unsigned NOT NULL DEFAULT '0',
  `longest_duel_seconds` int unsigned NOT NULL DEFAULT '0',
  `shortest_win_seconds` int unsigned NOT NULL DEFAULT '4294967295',
  `last_duel_time` bigint unsigned NOT NULL DEFAULT '0',
  `last_opponent_guid` int unsigned NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`),
  KEY `idx_wins` (`wins` DESC),
  KEY `idx_last_duel` (`last_duel_time` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos Phased Dueling - Player Statistics';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_dungeon_instance_resets
CREATE TABLE IF NOT EXISTS `dc_dungeon_instance_resets` (
  `reset_id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `dungeon_id` int unsigned NOT NULL COMMENT 'Dungeon ID',
  `reset_type` enum('DAILY','WEEKLY') COLLATE utf8mb4_unicode_ci NOT NULL,
  `reset_date` date NOT NULL,
  `reset_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reset_id`),
  UNIQUE KEY `uk_guid_dungeon_date` (`guid`,`dungeon_id`,`reset_date`,`reset_type`),
  KEY `idx_dungeon_id` (`dungeon_id`),
  KEY `idx_reset_date` (`reset_date`),
  CONSTRAINT `fk_reset_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Track reset dates for daily/weekly quests';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von View acore_chars.dc_guild_leaderboard
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `dc_guild_leaderboard` 
);

-- Exportiere Struktur von Tabelle acore_chars.dc_heirloom_package_history
CREATE TABLE IF NOT EXISTS `dc_heirloom_package_history` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `item_guid` int unsigned NOT NULL COMMENT 'Item instance GUID',
  `player_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `old_package_id` tinyint unsigned NOT NULL COMMENT 'Previous package ID',
  `old_package_level` tinyint unsigned NOT NULL COMMENT 'Previous package level',
  `new_package_id` tinyint unsigned NOT NULL COMMENT 'New package ID',
  `new_package_level` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'New package level (usually 1)',
  `essence_refunded` int unsigned NOT NULL DEFAULT '0' COMMENT 'Essence refunded (50% of invested)',
  `respec_cost` int unsigned NOT NULL DEFAULT '0' COMMENT 'Gold cost for respec (if any)',
  `reason` varchar(64) DEFAULT NULL COMMENT 'Optional reason (manual, spec_change, etc.)',
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player` (`player_guid`),
  KEY `idx_item` (`item_guid`),
  KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='History of package changes for analytics';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_heirloom_player_packages
CREATE TABLE IF NOT EXISTS `dc_heirloom_player_packages` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `item_guid` int unsigned NOT NULL COMMENT 'Item instance GUID from item_instance',
  `player_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `item_entry` int unsigned NOT NULL COMMENT 'Item template entry (e.g., 300365)',
  `package_id` tinyint unsigned NOT NULL COMMENT 'Chosen package (1-12, FK to dc_heirloom_stat_packages)',
  `package_level` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Current upgrade level (1-15)',
  `essence_invested` int unsigned NOT NULL DEFAULT '50' COMMENT 'Total essence spent on this package',
  `times_respec` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Number of times player changed packages',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_item` (`item_guid`) COMMENT 'One package per item instance',
  KEY `idx_player` (`player_guid`),
  KEY `idx_package` (`package_id`),
  KEY `idx_entry` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Player heirloom stat package selections and progress';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_heirloom_upgrade_log
CREATE TABLE IF NOT EXISTS `dc_heirloom_upgrade_log` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `item_guid` int unsigned NOT NULL COMMENT 'Item instance GUID',
  `item_entry` int unsigned NOT NULL COMMENT 'Item template entry',
  `from_level` tinyint unsigned NOT NULL COMMENT 'Previous level',
  `to_level` tinyint unsigned NOT NULL COMMENT 'New level',
  `from_package` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Previous package ID',
  `to_package` tinyint unsigned NOT NULL COMMENT 'New package ID',
  `enchant_id` int unsigned NOT NULL COMMENT 'Applied enchantment ID',
  `token_cost` int unsigned NOT NULL DEFAULT '0' COMMENT 'Tokens spent for this upgrade',
  `essence_cost` int unsigned NOT NULL DEFAULT '0' COMMENT 'Essence spent for this upgrade',
  `timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player` (`player_guid`),
  KEY `idx_item` (`item_guid`),
  KEY `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Heirloom upgrade transaction log';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_heirloom_upgrades
CREATE TABLE IF NOT EXISTS `dc_heirloom_upgrades` (
  `item_guid` int unsigned NOT NULL COMMENT 'Item instance GUID from item_instance',
  `player_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `item_entry` int unsigned NOT NULL COMMENT 'Item template entry (e.g., 300365)',
  `upgrade_level` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Current upgrade level (1-15)',
  `package_id` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Chosen package (1-12)',
  `enchant_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Applied SpellItemEnchantment.dbc ID',
  `essence_invested` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total essence spent',
  `tokens_invested` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total tokens spent',
  `first_upgraded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When first upgraded',
  `last_upgraded_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'When last upgraded',
  PRIMARY KEY (`item_guid`),
  KEY `idx_player` (`player_guid`),
  KEY `idx_package` (`package_id`),
  KEY `idx_entry` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Heirloom stat package upgrade state';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_costs
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
  `tier_id` tinyint unsigned NOT NULL COMMENT 'Item tier (1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary)',
  `tier_name` varchar(50) COLLATE utf8mb4_general_ci NOT NULL COMMENT 'Human-readable tier name',
  `base_essence_cost` float NOT NULL COMMENT 'Base essence cost for level 0→1',
  `base_token_cost` float NOT NULL COMMENT 'Base token cost for level 0→1',
  `escalation_rate` float DEFAULT '1.1' COMMENT 'Cost multiplier per level (1.1 = 10% increase)',
  `cost_multiplier` float DEFAULT '1' COMMENT 'Overall cost adjustment for tier',
  `stat_multiplier` float DEFAULT '1' COMMENT 'Stat scaling multiplier for tier (0.9-1.25x)',
  `ilvl_multiplier` float DEFAULT '1' COMMENT 'Item level bonus multiplier (1.0-2.5x)',
  `max_upgrade_level` tinyint unsigned DEFAULT '15' COMMENT 'Maximum upgrade level for tier',
  `enabled` tinyint(1) DEFAULT '1' COMMENT 'Enable/disable tier upgrades',
  `last_modified` int unsigned DEFAULT NULL COMMENT 'Last modification timestamp',
  PRIMARY KEY (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Item upgrade cost configuration per tier';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_currency_exchange_log
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_currency_exchange_log` (
  `log_id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `exchange_type` enum('tokens_to_essence','essence_to_tokens') COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` int unsigned NOT NULL,
  `exchange_rate` decimal(5,2) NOT NULL,
  `exchange_time` int unsigned NOT NULL,
  PRIMARY KEY (`log_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_exchange_time` (`exchange_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_log
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_log` (
  `log_id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry ID',
  `player_guid` int unsigned NOT NULL COMMENT 'Player performing upgrade',
  `item_guid` int unsigned NOT NULL COMMENT 'Item being upgraded',
  `item_id` int unsigned NOT NULL COMMENT 'Item template ID',
  `upgrade_from` tinyint unsigned NOT NULL COMMENT 'Previous upgrade level',
  `upgrade_to` tinyint unsigned NOT NULL COMMENT 'New upgrade level',
  `essence_cost` int unsigned NOT NULL COMMENT 'Essence paid for this upgrade',
  `token_cost` int unsigned NOT NULL COMMENT 'Tokens paid for this upgrade',
  `base_ilvl` smallint unsigned NOT NULL COMMENT 'Base item level',
  `old_ilvl` smallint unsigned NOT NULL COMMENT 'Item level before upgrade',
  `new_ilvl` smallint unsigned NOT NULL COMMENT 'Item level after upgrade',
  `old_stat_multiplier` float DEFAULT NULL COMMENT 'Stat multiplier before upgrade',
  `new_stat_multiplier` float DEFAULT NULL COMMENT 'Stat multiplier after upgrade',
  `timestamp` int unsigned NOT NULL COMMENT 'When this upgrade occurred',
  `season_id` int unsigned DEFAULT '1' COMMENT 'Season ID',
  PRIMARY KEY (`log_id`),
  KEY `idx_player` (`player_guid`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_season` (`season_id`),
  KEY `idx_player_timestamp` (`player_guid`,`timestamp`),
  KEY `idx_dc_item_upgrade_log_player_timestamp` (`player_guid`,`timestamp`),
  CONSTRAINT `fk_dc_item_upgrade_log_player` FOREIGN KEY (`player_guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Complete log of all item upgrades';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_stat_scaling
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_stat_scaling` (
  `scaling_id` tinyint unsigned NOT NULL COMMENT 'Unique scaling configuration ID',
  `base_multiplier_per_level` float DEFAULT '0.025' COMMENT 'Base stat multiplier per level (2.5% = 0.025)',
  `min_upgrade_level` tinyint unsigned DEFAULT '0' COMMENT 'Minimum level for scaling',
  `max_upgrade_level` tinyint unsigned DEFAULT '15' COMMENT 'Maximum level for scaling',
  `enabled` tinyint(1) DEFAULT '1' COMMENT 'Enable/disable scaling',
  `last_modified` int unsigned DEFAULT NULL COMMENT 'Last modification timestamp',
  PRIMARY KEY (`scaling_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci COMMENT='DarkChaos: Item upgrade stat scaling configuration';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_state
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_state` (
  `item_guid` int unsigned NOT NULL COMMENT 'From item_instance.guid',
  `player_guid` int unsigned NOT NULL,
  `tier_id` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1=Leveling, 2=Heroic, 3=Raid, 4=Mythic, 5=Artifact',
  `upgrade_level` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0-15, 0=base, 15=max',
  `tokens_invested` int unsigned NOT NULL DEFAULT '0',
  `essence_invested` int unsigned NOT NULL DEFAULT '0',
  `base_item_level` smallint unsigned NOT NULL,
  `upgraded_item_level` smallint unsigned NOT NULL,
  `stat_multiplier` float NOT NULL DEFAULT '1' COMMENT '1.0=base, 1.5=+50% stats, etc',
  `first_upgraded_at` int unsigned NOT NULL COMMENT 'Unix timestamp',
  `last_upgraded_at` int unsigned NOT NULL COMMENT 'Unix timestamp',
  `season` int unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`item_guid`),
  KEY `idx_player` (`player_guid`),
  KEY `idx_tier_level` (`tier_id`,`upgrade_level`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Item upgrade states for each item';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_synthesis_cooldowns
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_cooldowns` (
  `player_guid` int unsigned NOT NULL,
  `recipe_id` int unsigned NOT NULL,
  `cooldown_end` int unsigned NOT NULL,
  PRIMARY KEY (`player_guid`,`recipe_id`),
  KEY `idx_cooldown_end` (`cooldown_end`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_synthesis_log
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_log` (
  `log_id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `recipe_id` int unsigned NOT NULL,
  `success` tinyint unsigned NOT NULL,
  `attempt_time` int unsigned NOT NULL,
  `consumed_items` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`log_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_recipe_id` (`recipe_id`),
  KEY `idx_attempt_time` (`attempt_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrade_transmutation_sessions
CREATE TABLE IF NOT EXISTS `dc_item_upgrade_transmutation_sessions` (
  `session_id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `item_guid` int unsigned NOT NULL,
  `transmutation_type` enum('standard','special','fusion','synthesis') COLLATE utf8mb4_unicode_ci DEFAULT 'standard',
  `status` enum('pending','in_progress','completed','failed','cancelled') COLLATE utf8mb4_unicode_ci DEFAULT 'pending',
  `target_tier` tinyint unsigned DEFAULT '1',
  `target_level` tinyint unsigned DEFAULT '1',
  `tokens_required` int unsigned DEFAULT '0',
  `essence_required` int unsigned DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `started_at` timestamp NULL DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`session_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_item_guid` (`item_guid`),
  KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Session tracking for transmutation processes';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_item_upgrades
CREATE TABLE IF NOT EXISTS `dc_item_upgrades` (
  `upgrade_id` int NOT NULL AUTO_INCREMENT COMMENT 'Unique upgrade record ID',
  `item_guid` int NOT NULL COMMENT 'Unique item GUID from player inventory',
  `player_guid` int NOT NULL COMMENT 'Character GUID (from characters table)',
  `base_item_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Base item name for display and reference',
  `tier_id` tinyint NOT NULL DEFAULT '1' COMMENT 'Upgrade tier (1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary)',
  `upgrade_level` tinyint NOT NULL DEFAULT '0' COMMENT 'Current upgrade level (0-15 per tier, 0=no upgrade)',
  `tokens_invested` int NOT NULL DEFAULT '0' COMMENT 'Total upgrade tokens spent on this item',
  `essence_invested` int NOT NULL DEFAULT '0' COMMENT 'Total essence spent on this item',
  `stat_multiplier` float NOT NULL DEFAULT '1' COMMENT 'Current stat multiplier (1.0 = base stats, 1.2 = +20%, etc)',
  `first_upgraded_at` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'Unix timestamp when item was first upgraded (64-bit)',
  `last_upgraded_at` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'Unix timestamp when item was last upgraded (64-bit)',
  `season` int NOT NULL DEFAULT '0' COMMENT 'Season ID for seasonal resets (0=permanent)',
  PRIMARY KEY (`upgrade_id`),
  UNIQUE KEY `item_guid` (`item_guid`),
  KEY `k_player` (`player_guid`),
  KEY `k_item_guid` (`item_guid`),
  KEY `k_tier` (`tier_id`),
  KEY `k_season` (`season`),
  KEY `k_last_upgraded` (`last_upgraded_at`)
) ENGINE=InnoDB AUTO_INCREMENT=39 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item upgrade state tracking - stores player item upgrade progress and history';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mplus_keystones
CREATE TABLE IF NOT EXISTS `dc_mplus_keystones` (
  `character_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `map_id` smallint unsigned NOT NULL COMMENT 'Dungeon map ID',
  `level` tinyint unsigned NOT NULL COMMENT 'Keystone level (1-8)',
  `season_id` int unsigned NOT NULL COMMENT 'Season ID from dc_mplus_seasons',
  `expires_on` bigint unsigned NOT NULL COMMENT 'Expiration timestamp (Unix)',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation timestamp',
  PRIMARY KEY (`character_guid`),
  KEY `idx_season` (`season_id`),
  KEY `idx_expiration` (`expires_on`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Active Mythic+ keystones (one per player)';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mplus_runs
CREATE TABLE IF NOT EXISTS `dc_mplus_runs` (
  `run_id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique run identifier',
  `character_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `season_id` int unsigned NOT NULL COMMENT 'Season ID',
  `map_id` smallint unsigned NOT NULL COMMENT 'Dungeon map ID',
  `keystone_level` tinyint unsigned NOT NULL COMMENT 'Keystone level',
  `score` int NOT NULL DEFAULT '0' COMMENT 'Run score (can be negative on failure)',
  `deaths` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Total deaths',
  `wipes` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Total wipes',
  `completion_time` int unsigned DEFAULT NULL COMMENT 'Completion time in seconds (NULL if failed)',
  `success` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'TRUE if run completed successfully',
  `affix_pair_id` int unsigned DEFAULT NULL COMMENT 'Active affix pair',
  `group_members` json DEFAULT NULL COMMENT 'Array of participant GUIDs',
  `completed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Run completion timestamp',
  PRIMARY KEY (`run_id`),
  KEY `idx_player_season` (`character_guid`,`season_id`,`completed_at` DESC),
  KEY `idx_vault_eligibility` (`character_guid`,`season_id`,`success`,`completed_at`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Complete Mythic+ run history for vault and statistics';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mplus_scores
CREATE TABLE IF NOT EXISTS `dc_mplus_scores` (
  `character_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `season_id` int unsigned NOT NULL COMMENT 'Season ID',
  `map_id` smallint unsigned NOT NULL COMMENT 'Dungeon map ID',
  `best_level` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Highest keystone level cleared',
  `best_score` int unsigned NOT NULL DEFAULT '0' COMMENT 'Best score achieved',
  `last_run_ts` bigint unsigned NOT NULL COMMENT 'Last run timestamp (Unix)',
  `total_runs` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total runs of this dungeon',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_guid`,`season_id`,`map_id`),
  KEY `idx_leaderboard` (`season_id`,`map_id`,`best_score` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Per-dungeon Mythic+ scores and best clears';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mythic_spectator_invites
CREATE TABLE IF NOT EXISTS `dc_mythic_spectator_invites` (
  `code` varchar(8) NOT NULL,
  `instance_id` int unsigned NOT NULL,
  `created_by` int unsigned NOT NULL,
  `created_at` bigint unsigned NOT NULL,
  `expires_at` bigint unsigned NOT NULL,
  `max_uses` int unsigned NOT NULL DEFAULT '10',
  `use_count` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`code`),
  KEY `idx_instance` (`instance_id`),
  KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Invite Links';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mythic_spectator_popularity
CREATE TABLE IF NOT EXISTS `dc_mythic_spectator_popularity` (
  `map_id` int unsigned NOT NULL,
  `keystone_level` tinyint unsigned NOT NULL,
  `total_spectators` int unsigned NOT NULL DEFAULT '0',
  `total_watch_time` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'In seconds',
  `last_spectated` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`map_id`,`keystone_level`),
  KEY `idx_popularity` (`total_spectators` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Popularity Stats';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mythic_spectator_replays
CREATE TABLE IF NOT EXISTS `dc_mythic_spectator_replays` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `map_id` int unsigned NOT NULL,
  `keystone_level` tinyint unsigned NOT NULL,
  `leader_name` varchar(12) NOT NULL,
  `start_time` bigint unsigned NOT NULL,
  `end_time` bigint unsigned NOT NULL DEFAULT '0',
  `completed` tinyint(1) NOT NULL DEFAULT '0',
  `replay_data` longtext NOT NULL COMMENT 'JSON serialized replay events',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_map_level` (`map_id`,`keystone_level`),
  KEY `idx_start_time` (`start_time` DESC),
  KEY `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Replay Storage';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mythic_spectator_sessions
CREATE TABLE IF NOT EXISTS `dc_mythic_spectator_sessions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `spectator_guid` int unsigned NOT NULL,
  `instance_id` int unsigned NOT NULL,
  `map_id` int unsigned NOT NULL,
  `keystone_level` tinyint unsigned NOT NULL,
  `join_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `leave_time` timestamp NULL DEFAULT NULL,
  `duration_seconds` int unsigned NOT NULL DEFAULT '0',
  `stream_mode` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=Normal, 1=Names Hidden, 2=Full Anonymous',
  PRIMARY KEY (`id`),
  KEY `idx_spectator` (`spectator_guid`,`join_time` DESC),
  KEY `idx_instance` (`instance_id`),
  KEY `idx_time` (`join_time` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Session Log';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mythic_spectator_settings
CREATE TABLE IF NOT EXISTS `dc_mythic_spectator_settings` (
  `player_guid` int unsigned NOT NULL,
  `allow_spectators` tinyint(1) NOT NULL DEFAULT '1',
  `allow_public_listing` tinyint(1) NOT NULL DEFAULT '1',
  `default_stream_mode` tinyint unsigned NOT NULL DEFAULT '0',
  `blocked_spectators` text COMMENT 'Comma-separated list of blocked player GUIDs',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Player Settings';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_mythicplus_hud_cache
CREATE TABLE IF NOT EXISTS `dc_mythicplus_hud_cache` (
  `instance_key` bigint unsigned NOT NULL,
  `map_id` int unsigned NOT NULL,
  `instance_id` int unsigned NOT NULL,
  `owner_guid` int unsigned NOT NULL,
  `keystone_level` tinyint unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `updated_at` bigint unsigned NOT NULL,
  PRIMARY KEY (`instance_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_artifact_discoveries
CREATE TABLE IF NOT EXISTS `dc_player_artifact_discoveries` (
  `player_guid` int unsigned NOT NULL,
  `artifact_id` int unsigned NOT NULL,
  `discovery_type` enum('quest','craft','purchase','event','admin') COLLATE utf8mb4_unicode_ci DEFAULT 'craft',
  `discovered_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `completion_percentage` tinyint unsigned DEFAULT '0',
  PRIMARY KEY (`player_guid`,`artifact_id`),
  KEY `idx_discovery_type` (`discovery_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks discovered artifacts per player';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_artifact_mastery
CREATE TABLE IF NOT EXISTS `dc_player_artifact_mastery` (
  `player_guid` int unsigned NOT NULL,
  `artifact_id` int unsigned NOT NULL,
  `mastery_level` tinyint unsigned DEFAULT '0',
  `mastery_points` int unsigned DEFAULT '0',
  `total_points_earned` int unsigned DEFAULT '0',
  `unlocked_abilities` text COLLATE utf8mb4_unicode_ci,
  `unlocked_at` timestamp NULL DEFAULT NULL,
  `last_updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`,`artifact_id`),
  KEY `idx_mastery_level` (`mastery_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Artifact mastery progression per player';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_claimed_chests
CREATE TABLE IF NOT EXISTS `dc_player_claimed_chests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `chest_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `chest_tier` tinyint NOT NULL,
  `items_received` json DEFAULT NULL,
  `claimed_at` bigint unsigned NOT NULL,
  `claimed_by_npc_guid` int unsigned DEFAULT NULL,
  `transaction_id` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`,`season_id`),
  KEY `idx_chest_id` (`chest_id`),
  KEY `idx_claimed_at` (`claimed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Prevents duplicate chest claims';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_daily_quest_progress
CREATE TABLE IF NOT EXISTS `dc_player_daily_quest_progress` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `daily_quest_entry` int unsigned NOT NULL COMMENT 'Daily quest entry id',
  `completed_today` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=no, 1=yes',
  `last_completed` timestamp NULL DEFAULT NULL COMMENT 'Last completion time',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`,`daily_quest_entry`),
  KEY `idx_guid` (`guid`),
  KEY `idx_daily_entry` (`daily_quest_entry`),
  CONSTRAINT `fk_dc_player_daily_progress_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Per-player tracking for daily dungeon quest progress';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_dungeon_completion_stats
CREATE TABLE IF NOT EXISTS `dc_player_dungeon_completion_stats` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `last_activity` timestamp NULL DEFAULT NULL COMMENT 'Last dungeon-related activity',
  `total_dungeons_completed` int unsigned NOT NULL DEFAULT '0',
  `total_quests_completed` int unsigned NOT NULL DEFAULT '0',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`),
  KEY `idx_last_activity` (`last_activity`),
  CONSTRAINT `fk_dc_player_dungeon_stats_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Per-player dungeon completion stats and timestamps';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_item_upgrades
CREATE TABLE IF NOT EXISTS `dc_player_item_upgrades` (
  `upgrade_id` int NOT NULL AUTO_INCREMENT COMMENT 'Unique upgrade record ID',
  `item_guid` int NOT NULL COMMENT 'Unique item GUID from player inventory',
  `player_guid` int NOT NULL COMMENT 'Character GUID (from characters table)',
  `base_item_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Base item name for display',
  `tier_id` tinyint NOT NULL DEFAULT '1' COMMENT 'Upgrade tier (1-5)',
  `upgrade_level` tinyint NOT NULL DEFAULT '0' COMMENT 'Current upgrade level (0-15 per tier)',
  `tokens_invested` int NOT NULL DEFAULT '0' COMMENT 'Total upgrade tokens spent',
  `essence_invested` int NOT NULL DEFAULT '0' COMMENT 'Total essence spent',
  `stat_multiplier` float NOT NULL DEFAULT '1' COMMENT 'Current stat multiplier (1.0 = base stats)',
  `first_upgraded_at` int unsigned DEFAULT '0' COMMENT 'Unix timestamp when first upgraded',
  `last_upgraded_at` int unsigned DEFAULT '0' COMMENT 'Unix timestamp when last upgraded',
  `season` int NOT NULL DEFAULT '0' COMMENT 'Season ID for seasonal resets',
  PRIMARY KEY (`upgrade_id`),
  UNIQUE KEY `item_guid` (`item_guid`),
  KEY `k_player` (`player_guid`),
  KEY `k_item_guid` (`item_guid`),
  KEY `k_season` (`season`),
  KEY `k_tier` (`tier_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player item upgrade state and history';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von View acore_chars.dc_player_progression_summary
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `dc_player_progression_summary` 
);

-- Exportiere Struktur von Tabelle acore_chars.dc_player_season_data
CREATE TABLE IF NOT EXISTS `dc_player_season_data` (
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `essence_earned` int unsigned NOT NULL DEFAULT '0',
  `tokens_earned` int unsigned NOT NULL DEFAULT '0',
  `essence_spent` int unsigned NOT NULL DEFAULT '0',
  `tokens_spent` int unsigned NOT NULL DEFAULT '0',
  `items_upgraded` int unsigned NOT NULL DEFAULT '0',
  `upgrades_applied` int unsigned NOT NULL DEFAULT '0',
  `mastery_earned` int unsigned NOT NULL DEFAULT '0',
  `rank_this_season` int unsigned NOT NULL DEFAULT '0',
  `first_upgrade_timestamp` bigint unsigned DEFAULT '0',
  `last_upgrade_timestamp` bigint unsigned DEFAULT '0',
  PRIMARY KEY (`player_guid`,`season_id`),
  KEY `idx_season` (`season_id`),
  KEY `idx_upgrades` (`upgrades_applied` DESC),
  KEY `idx_mastery` (`mastery_earned` DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Per-season player statistics';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_seasonal_achievements
CREATE TABLE IF NOT EXISTS `dc_player_seasonal_achievements` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `achievement_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `achievement_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `achievement_description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `progress_value` int unsigned DEFAULT NULL,
  `reward_tokens` int unsigned DEFAULT '0',
  `reward_essence` int unsigned DEFAULT '0',
  `achieved_at` bigint unsigned NOT NULL,
  `rewarded_at` bigint unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`,`season_id`),
  KEY `idx_achievement_type` (`achievement_type`),
  KEY `idx_achieved_at` (`achieved_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Seasonal achievements';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_seasonal_chests
CREATE TABLE IF NOT EXISTS `dc_player_seasonal_chests` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `week_timestamp` bigint unsigned NOT NULL,
  `slot1_tokens` int unsigned NOT NULL DEFAULT '0',
  `slot1_essence` int unsigned NOT NULL DEFAULT '0',
  `slot2_tokens` int unsigned NOT NULL DEFAULT '0',
  `slot2_essence` int unsigned NOT NULL DEFAULT '0',
  `slot3_tokens` int unsigned NOT NULL DEFAULT '0',
  `slot3_essence` int unsigned NOT NULL DEFAULT '0',
  `slots_unlocked` tinyint unsigned NOT NULL DEFAULT '1',
  `collected` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_season_week` (`player_guid`,`season_id`,`week_timestamp`),
  KEY `idx_season_week` (`season_id`,`week_timestamp`),
  KEY `idx_uncollected` (`collected`,`season_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly seasonal reward chest tracking';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_seasonal_stats
CREATE TABLE IF NOT EXISTS `dc_player_seasonal_stats` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `total_tokens_earned` bigint unsigned DEFAULT '0',
  `total_essence_earned` bigint unsigned DEFAULT '0',
  `quests_completed` int unsigned DEFAULT '0',
  `bosses_killed` int unsigned DEFAULT '0',
  `chests_claimed` int unsigned DEFAULT '0',
  `weekly_tokens_earned` int unsigned DEFAULT '0',
  `weekly_essence_earned` int unsigned DEFAULT '0',
  `weekly_reset_at` bigint unsigned DEFAULT NULL,
  `season_best_run` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_reward_at` bigint unsigned DEFAULT NULL,
  `last_activity_at` bigint unsigned DEFAULT NULL,
  `joined_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_player_season` (`player_guid`,`season_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_tokens_earned` (`total_tokens_earned`),
  KEY `idx_last_activity` (`last_activity_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player seasonal statistics';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_seasonal_stats_history
CREATE TABLE IF NOT EXISTS `dc_player_seasonal_stats_history` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `total_tokens_earned` bigint unsigned DEFAULT '0',
  `total_essence_earned` bigint unsigned DEFAULT '0',
  `quests_completed` int unsigned DEFAULT '0',
  `bosses_killed` int unsigned DEFAULT '0',
  `chests_claimed` int unsigned DEFAULT '0',
  `final_rank_tokens` int unsigned DEFAULT NULL,
  `final_rank_bosses` int unsigned DEFAULT NULL,
  `archived_at` bigint unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`,`season_id`),
  KEY `idx_archived_at` (`archived_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Archived player stats';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_synthesis_cooldowns
CREATE TABLE IF NOT EXISTS `dc_player_synthesis_cooldowns` (
  `player_guid` int unsigned NOT NULL,
  `last_synthesis` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player synthesis cooldown tracking';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_tier_caps
CREATE TABLE IF NOT EXISTS `dc_player_tier_caps` (
  `player_guid` int unsigned NOT NULL,
  `tier_id` tinyint unsigned NOT NULL,
  `max_level` tinyint unsigned DEFAULT '1',
  `progression_percentage` tinyint unsigned DEFAULT '0',
  `capped_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`,`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Maximum achievable level per tier per player';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_tier_unlocks
CREATE TABLE IF NOT EXISTS `dc_player_tier_unlocks` (
  `player_guid` int unsigned NOT NULL,
  `tier_id` tinyint unsigned NOT NULL,
  `is_unlocked` tinyint(1) DEFAULT '1',
  `unlocked_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `tier_reset_count` int unsigned DEFAULT '0',
  PRIMARY KEY (`player_guid`,`tier_id`),
  KEY `idx_tier_id` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks which upgrade tiers players have unlocked';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_transmutation_cooldowns
CREATE TABLE IF NOT EXISTS `dc_player_transmutation_cooldowns` (
  `player_guid` int unsigned NOT NULL,
  `transmutation_type` enum('standard','special','fusion','synthesis') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'standard',
  `cooldown_until` timestamp NULL DEFAULT NULL,
  `daily_uses` int unsigned DEFAULT '0',
  `last_reset` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`,`transmutation_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Transmutation cooldown tracking per player';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von View acore_chars.dc_player_upgrade_summary
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `dc_player_upgrade_summary` 
);

-- Exportiere Struktur von Tabelle acore_chars.dc_player_upgrade_tokens
CREATE TABLE IF NOT EXISTS `dc_player_upgrade_tokens` (
  `player_guid` int unsigned NOT NULL,
  `currency_type` enum('upgrade_token','artifact_essence','upgrade_key','ancient_crystal') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'upgrade_token',
  `amount` int unsigned DEFAULT '0',
  `weekly_earned` int unsigned DEFAULT '0',
  `season` int unsigned DEFAULT '1',
  `last_transaction_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`,`currency_type`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player currency storage for upgrades';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_weekly_cap_snapshot
CREATE TABLE IF NOT EXISTS `dc_player_weekly_cap_snapshot` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `week_ending` date NOT NULL,
  `tokens_earned` int unsigned DEFAULT '0',
  `essence_earned` int unsigned DEFAULT '0',
  `quests_completed` int unsigned DEFAULT '0',
  `bosses_killed` int unsigned DEFAULT '0',
  `chests_claimed` int unsigned DEFAULT '0',
  `snapshot_at` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_player_season_week` (`player_guid`,`season_id`,`week_ending`),
  KEY `idx_week_ending` (`week_ending`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Historical snapshots of weekly caps';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_weekly_quest_progress
CREATE TABLE IF NOT EXISTS `dc_player_weekly_quest_progress` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `weekly_quest_entry` int unsigned NOT NULL COMMENT 'Weekly quest entry id',
  `completed_this_week` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=no, 1=yes',
  `week_reset_date` timestamp NULL DEFAULT NULL COMMENT 'Last week reset timestamp',
  `last_completed` timestamp NULL DEFAULT NULL COMMENT 'Last completion time',
  `created_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`,`weekly_quest_entry`),
  KEY `idx_guid` (`guid`),
  KEY `idx_weekly_entry` (`weekly_quest_entry`),
  CONSTRAINT `fk_dc_player_weekly_progress_guid` FOREIGN KEY (`guid`) REFERENCES `characters` (`guid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Per-player tracking for weekly dungeon quest progress';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_player_weekly_rewards
CREATE TABLE IF NOT EXISTS `dc_player_weekly_rewards` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `character_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `season_id` int unsigned NOT NULL COMMENT 'Season ID',
  `week_start` bigint unsigned NOT NULL COMMENT 'Week start timestamp (Unix Tuesday reset)',
  `system_type` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'mythic_plus, seasonal_rewards, pvp, hlbg',
  `mplus_runs_completed` tinyint unsigned DEFAULT '0' COMMENT 'Mythic+ runs this week',
  `mplus_highest_level` tinyint unsigned DEFAULT '0' COMMENT 'Highest keystone cleared',
  `tokens_earned` int unsigned DEFAULT '0' COMMENT 'Total tokens earned this week',
  `essence_earned` int unsigned DEFAULT '0' COMMENT 'Total essence earned this week',
  `slot1_unlocked` tinyint(1) NOT NULL DEFAULT '0',
  `slot1_tokens` int unsigned DEFAULT '0',
  `slot1_essence` int unsigned DEFAULT '0',
  `slot1_item_ilvl` smallint unsigned DEFAULT '0' COMMENT 'M+ item reward ilvl',
  `slot2_unlocked` tinyint(1) NOT NULL DEFAULT '0',
  `slot2_tokens` int unsigned DEFAULT '0',
  `slot2_essence` int unsigned DEFAULT '0',
  `slot2_item_ilvl` smallint unsigned DEFAULT '0',
  `slot3_unlocked` tinyint(1) NOT NULL DEFAULT '0',
  `slot3_tokens` int unsigned DEFAULT '0',
  `slot3_essence` int unsigned DEFAULT '0',
  `slot3_item_ilvl` smallint unsigned DEFAULT '0',
  `reward_claimed` tinyint(1) NOT NULL DEFAULT '0',
  `claimed_slot` tinyint unsigned DEFAULT '0' COMMENT '1/2/3 - which slot was claimed',
  `claimed_item_id` int unsigned DEFAULT NULL COMMENT 'Item entry if item claimed',
  `claimed_tokens` int unsigned DEFAULT '0' COMMENT 'Tokens claimed',
  `claimed_essence` int unsigned DEFAULT '0' COMMENT 'Essence claimed',
  `claimed_at` bigint unsigned DEFAULT NULL COMMENT 'Claim timestamp',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_char_season_week_system` (`character_guid`,`season_id`,`week_start`,`system_type`),
  KEY `idx_season_week` (`season_id`,`week_start`),
  KEY `idx_system_type` (`system_type`),
  KEY `idx_pending_rewards` (`season_id`,`week_start`,`reward_claimed`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Unified weekly rewards tracking for all systems';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_prestige_challenge_rewards
CREATE TABLE IF NOT EXISTS `dc_prestige_challenge_rewards` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `challenge_type` tinyint unsigned NOT NULL COMMENT '1=Iron, 2=Speed, 3=Solo',
  `stat_bonus_percent` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Permanent stat bonus percentage',
  `granted_time` int unsigned NOT NULL COMMENT 'Unix timestamp when reward granted',
  PRIMARY KEY (`guid`,`challenge_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prestige challenge rewards';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_prestige_challenges
CREATE TABLE IF NOT EXISTS `dc_prestige_challenges` (
  `guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `prestige_level` tinyint unsigned NOT NULL COMMENT 'Prestige level when challenge started',
  `challenge_type` tinyint unsigned NOT NULL COMMENT '1=Iron, 2=Speed, 3=Solo',
  `active` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Is challenge currently active',
  `completed` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Was challenge completed successfully',
  `start_time` int unsigned NOT NULL COMMENT 'Unix timestamp when challenge started',
  `start_playtime` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total played time when challenge started (seconds)',
  `completion_time` int unsigned DEFAULT NULL COMMENT 'Unix timestamp when challenge completed',
  `death_count` int unsigned NOT NULL DEFAULT '0' COMMENT 'Deaths during challenge (for Iron)',
  `group_count` int unsigned NOT NULL DEFAULT '0' COMMENT 'Times grouped during challenge (for Solo)',
  PRIMARY KEY (`guid`,`prestige_level`,`challenge_type`),
  KEY `idx_active` (`guid`,`active`),
  KEY `idx_completed` (`completed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Prestige challenge progress';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von View acore_chars.dc_recent_upgrades_feed
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `dc_recent_upgrades_feed` 
);

-- Exportiere Struktur von Tabelle acore_chars.dc_reward_transactions
CREATE TABLE IF NOT EXISTS `dc_reward_transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `transaction_type` enum('quest','creature','creature_group','chest','manual','adjustment') COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_id` int unsigned DEFAULT NULL,
  `source_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reward_type` tinyint DEFAULT NULL,
  `token_amount` int unsigned DEFAULT '0',
  `essence_amount` int unsigned DEFAULT '0',
  `base_amount` int unsigned DEFAULT NULL,
  `difficulty_multiplier` float DEFAULT '1',
  `season_multiplier` float DEFAULT '1',
  `final_multiplier` float DEFAULT '1',
  `weekly_total_after` int unsigned DEFAULT NULL,
  `notes` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `transaction_at` bigint unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_season` (`player_guid`,`season_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_transaction_type` (`transaction_type`),
  KEY `idx_transaction_at` (`transaction_at`),
  KEY `idx_source_id` (`source_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail: all reward transactions';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_season_history
CREATE TABLE IF NOT EXISTS `dc_season_history` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `season_id` int unsigned NOT NULL,
  `event_type` enum('created','started','ended','archived') COLLATE utf8mb4_unicode_ci NOT NULL,
  `event_timestamp` bigint unsigned NOT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_event_type` (`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Season lifecycle history';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_seasons
CREATE TABLE IF NOT EXISTS `dc_seasons` (
  `season_id` int unsigned NOT NULL,
  `season_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `season_description` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Season description text',
  `season_type` tinyint unsigned DEFAULT '0' COMMENT '0=Normal, 1=Special, 2=Event',
  `season_state` tinyint unsigned DEFAULT '0' COMMENT '0=Inactive, 1=Active, 2=Transitioning, 3=Maintenance',
  `start_timestamp` bigint unsigned NOT NULL,
  `end_timestamp` bigint unsigned DEFAULT '0',
  `created_timestamp` bigint unsigned DEFAULT '0' COMMENT 'When season was created',
  `allow_carryover` tinyint(1) DEFAULT '0' COMMENT 'Allow stats to carry over to next season',
  `carryover_percentage` float DEFAULT '0' COMMENT 'Percentage of stats to carry over (0.0-1.0)',
  `reset_on_end` tinyint(1) DEFAULT '1' COMMENT 'Reset all stats when season ends',
  `theme_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Season theme identifier',
  `banner_path` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'Path to season banner image',
  `is_active` tinyint(1) NOT NULL DEFAULT '0',
  `max_upgrade_level` tinyint unsigned NOT NULL DEFAULT '15',
  `cost_multiplier` float NOT NULL DEFAULT '1',
  `reward_multiplier` float NOT NULL DEFAULT '1',
  `theme` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `milestone_essence_cap` int unsigned NOT NULL DEFAULT '50000',
  `milestone_token_cap` int unsigned NOT NULL DEFAULT '25000',
  PRIMARY KEY (`season_id`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Season configuration';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_server_firsts
CREATE TABLE IF NOT EXISTS `dc_server_firsts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `category` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `player_guid` int unsigned NOT NULL,
  `player_name` varchar(12) COLLATE utf8mb4_unicode_ci NOT NULL,
  `achievement_time` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_category` (`category`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_tier_conversion_log
CREATE TABLE IF NOT EXISTS `dc_tier_conversion_log` (
  `log_id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `from_tier` tinyint unsigned NOT NULL,
  `to_tier` tinyint unsigned NOT NULL,
  `conversion_type` enum('upgrade','downgrade','reset','skip') COLLATE utf8mb4_unicode_ci DEFAULT 'upgrade',
  `tokens_spent` int unsigned DEFAULT '0',
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit trail for tier conversion events';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_token_event_config
CREATE TABLE IF NOT EXISTS `dc_token_event_config` (
  `event_id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique event config ID',
  `event_type` enum('quest','creature','achievement','pvp','battleground','daily') COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Type of event',
  `event_source_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Source ID (quest_id, creature_id, achievement_id, etc.; 0 for general PvP)',
  `token_reward` int unsigned NOT NULL DEFAULT '0' COMMENT 'Base upgrade tokens awarded',
  `essence_reward` int unsigned NOT NULL DEFAULT '0' COMMENT 'Base artifact essence awarded',
  `scaling_factor` float DEFAULT '1' COMMENT 'Multiplier for difficulty/level scaling (1.0 = no scaling)',
  `cooldown_seconds` int unsigned DEFAULT '0' COMMENT 'Cooldown between awards (0 = no cooldown)',
  `is_active` tinyint unsigned DEFAULT '1' COMMENT 'Is this event currently active',
  `is_repeatable` tinyint unsigned DEFAULT '1' COMMENT 'Can award be earned multiple times (0 = one-time like achievements)',
  `season` int unsigned NOT NULL DEFAULT '1' COMMENT 'Season this config applies to',
  `notes` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Notes about this event config',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this config was created',
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'When last updated',
  PRIMARY KEY (`event_id`),
  UNIQUE KEY `uix_event_source` (`event_type`,`event_source_id`,`season`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_is_active` (`is_active`),
  KEY `idx_season` (`season`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Configuration for which events award tokens and how much';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_token_rewards_log
CREATE TABLE IF NOT EXISTS `dc_token_rewards_log` (
  `log_id` bigint unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique log entry',
  `character_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `map_id` smallint unsigned NOT NULL COMMENT 'Dungeon map ID',
  `difficulty` tinyint unsigned NOT NULL COMMENT 'Difficulty (0=Normal, 1=Heroic, 3=Mythic)',
  `keystone_level` tinyint unsigned DEFAULT NULL COMMENT 'Mythic+ level (NULL for base Mythic)',
  `player_level` tinyint unsigned NOT NULL COMMENT 'Player level at time of reward',
  `tokens_awarded` int unsigned NOT NULL COMMENT 'Token count awarded',
  `boss_entry` int unsigned NOT NULL COMMENT 'Final boss creature entry',
  `awarded_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Reward timestamp',
  PRIMARY KEY (`log_id`),
  KEY `idx_player_history` (`character_guid`,`awarded_at` DESC),
  KEY `idx_dungeon_stats` (`map_id`,`difficulty`,`awarded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Token reward history for final boss kills';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_token_transaction_log
CREATE TABLE IF NOT EXISTS `dc_token_transaction_log` (
  `transaction_id` int unsigned NOT NULL AUTO_INCREMENT,
  `player_guid` int unsigned NOT NULL,
  `currency_type` enum('upgrade_token','artifact_essence','upgrade_key','ancient_crystal') COLLATE utf8mb4_unicode_ci DEFAULT 'upgrade_token',
  `amount` int unsigned NOT NULL,
  `transaction_type` enum('earn','spend','admin_add','admin_remove','transfer','reward','penalty') COLLATE utf8mb4_unicode_ci DEFAULT 'earn',
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `balance_before` int unsigned DEFAULT '0',
  `balance_after` int unsigned DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`transaction_id`),
  KEY `idx_player_guid` (`player_guid`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_transaction_type` (`transaction_type`)
) ENGINE=InnoDB AUTO_INCREMENT=338 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Complete audit trail of token/currency transactions';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von View acore_chars.dc_top_upgraders
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `dc_top_upgraders` 
);

-- Exportiere Struktur von View acore_chars.dc_upgrade_speed_stats
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `dc_upgrade_speed_stats` (
	`player_guid` INT UNSIGNED NOT NULL COMMENT 'Player performing upgrade',
	`total_upgrades` BIGINT NOT NULL,
	`upgrades_per_day` DECIMAL(29,4) NULL,
	`first_upgrade` INT UNSIGNED NULL COMMENT 'When this upgrade occurred',
	`last_upgrade` INT UNSIGNED NULL COMMENT 'When this upgrade occurred',
	`average_cost_per_upgrade` DECIMAL(15,4) NULL
);

-- Exportiere Struktur von Tabelle acore_chars.dc_vault_reward_pool
CREATE TABLE IF NOT EXISTS `dc_vault_reward_pool` (
  `character_guid` int unsigned NOT NULL COMMENT 'Character GUID',
  `season_id` int unsigned NOT NULL COMMENT 'Season ID',
  `week_start` bigint unsigned NOT NULL COMMENT 'Week start timestamp',
  `item_id` int unsigned NOT NULL COMMENT 'Item/Token entry ID',
  `item_level` smallint unsigned NOT NULL COMMENT 'Item level for this reward',
  `slot_index` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Reward slot index (0-5)',
  `claimed` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Whether this reward was claimed',
  `claimed_at` bigint unsigned DEFAULT NULL COMMENT 'Timestamp when claimed',
  PRIMARY KEY (`character_guid`,`season_id`,`week_start`,`slot_index`),
  KEY `idx_claimed` (`character_guid`,`season_id`,`week_start`,`claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Generated vault reward options with claim tracking';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_weekly_spending
CREATE TABLE IF NOT EXISTS `dc_weekly_spending` (
  `player_guid` int unsigned NOT NULL,
  `week_start` date NOT NULL,
  `tokens_spent` int unsigned DEFAULT '0',
  `essence_spent` int unsigned DEFAULT '0',
  `upgrades_performed` int unsigned DEFAULT '0',
  `reset_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`player_guid`,`week_start`),
  KEY `idx_week_start` (`week_start`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly spending tracking for progression and limits';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.dc_weekly_vault
CREATE TABLE IF NOT EXISTS `dc_weekly_vault` (
  `character_guid` int unsigned NOT NULL,
  `season_id` int unsigned NOT NULL,
  `week_start` bigint unsigned NOT NULL,
  `runs_completed` tinyint unsigned NOT NULL DEFAULT '0',
  `highest_level` tinyint unsigned NOT NULL DEFAULT '0',
  `slot1_unlocked` tinyint(1) NOT NULL DEFAULT '0',
  `slot2_unlocked` tinyint(1) NOT NULL DEFAULT '0',
  `slot3_unlocked` tinyint(1) NOT NULL DEFAULT '0',
  `reward_claimed` tinyint(1) NOT NULL DEFAULT '0',
  `claimed_slot` tinyint unsigned DEFAULT NULL,
  `claimed_item_id` int unsigned DEFAULT NULL,
  `claimed_tokens` int unsigned DEFAULT NULL,
  `claimed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`character_guid`,`season_id`,`week_start`),
  KEY `idx_pending_rewards` (`season_id`,`week_start`,`reward_claimed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly Great Vault progress';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.game_event_condition_save
CREATE TABLE IF NOT EXISTS `game_event_condition_save` (
  `eventEntry` tinyint unsigned NOT NULL,
  `condition_id` int unsigned NOT NULL DEFAULT '0',
  `done` float DEFAULT '0',
  PRIMARY KEY (`eventEntry`,`condition_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.game_event_save
CREATE TABLE IF NOT EXISTS `game_event_save` (
  `eventEntry` tinyint unsigned NOT NULL,
  `state` tinyint unsigned NOT NULL DEFAULT '1',
  `next_start` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.gameobject_respawn
CREATE TABLE IF NOT EXISTS `gameobject_respawn` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `respawnTime` int unsigned NOT NULL DEFAULT '0',
  `mapId` smallint unsigned NOT NULL DEFAULT '0',
  `instanceId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Instance Identifier',
  PRIMARY KEY (`guid`,`instanceId`),
  KEY `idx_instance` (`instanceId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Grid Loading System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.gm_subsurvey
CREATE TABLE IF NOT EXISTS `gm_subsurvey` (
  `surveyId` int unsigned NOT NULL AUTO_INCREMENT,
  `questionId` int unsigned NOT NULL DEFAULT '0',
  `answer` int unsigned NOT NULL DEFAULT '0',
  `answerComment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`surveyId`,`questionId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.gm_survey
CREATE TABLE IF NOT EXISTS `gm_survey` (
  `surveyId` int unsigned NOT NULL AUTO_INCREMENT,
  `guid` int unsigned NOT NULL DEFAULT '0',
  `mainSurvey` int unsigned NOT NULL DEFAULT '0',
  `comment` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `createTime` int unsigned NOT NULL DEFAULT '0',
  `maxMMR` smallint NOT NULL,
  PRIMARY KEY (`surveyId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.gm_ticket
CREATE TABLE IF NOT EXISTS `gm_ticket` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `type` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0 open, 1 closed, 2 character deleted',
  `playerGuid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier of ticket creator',
  `name` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Name of ticket creator',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `createTime` int unsigned NOT NULL DEFAULT '0',
  `mapId` smallint unsigned NOT NULL DEFAULT '0',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  `lastModifiedTime` int unsigned NOT NULL DEFAULT '0',
  `closedBy` int NOT NULL DEFAULT '0' COMMENT '-1 Closed by Console, >0 GUID of GM',
  `assignedTo` int unsigned NOT NULL DEFAULT '0' COMMENT 'GUID of admin to whom ticket is assigned',
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `response` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `completed` tinyint unsigned NOT NULL DEFAULT '0',
  `escalated` tinyint unsigned NOT NULL DEFAULT '0',
  `viewed` tinyint unsigned NOT NULL DEFAULT '0',
  `needMoreHelp` tinyint unsigned NOT NULL DEFAULT '0',
  `resolvedBy` int NOT NULL DEFAULT '0' COMMENT '-1 Resolved by Console, >0 GUID of GM',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.group_member
CREATE TABLE IF NOT EXISTS `group_member` (
  `guid` int unsigned NOT NULL,
  `memberGuid` int unsigned NOT NULL,
  `memberFlags` tinyint unsigned NOT NULL DEFAULT '0',
  `subgroup` tinyint unsigned NOT NULL DEFAULT '0',
  `roles` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`memberGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Groups';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.groups
CREATE TABLE IF NOT EXISTS `groups` (
  `guid` int unsigned NOT NULL,
  `leaderGuid` int unsigned NOT NULL,
  `lootMethod` tinyint unsigned NOT NULL,
  `looterGuid` int unsigned NOT NULL,
  `lootThreshold` tinyint unsigned NOT NULL,
  `icon1` bigint unsigned NOT NULL,
  `icon2` bigint unsigned NOT NULL,
  `icon3` bigint unsigned NOT NULL,
  `icon4` bigint unsigned NOT NULL,
  `icon5` bigint unsigned NOT NULL,
  `icon6` bigint unsigned NOT NULL,
  `icon7` bigint unsigned NOT NULL,
  `icon8` bigint unsigned NOT NULL,
  `groupType` tinyint unsigned NOT NULL,
  `difficulty` tinyint unsigned NOT NULL DEFAULT '0',
  `raidDifficulty` tinyint unsigned NOT NULL DEFAULT '0',
  `masterLooterGuid` int unsigned NOT NULL,
  PRIMARY KEY (`guid`),
  KEY `leaderGuid` (`leaderGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Groups';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild
CREATE TABLE IF NOT EXISTS `guild` (
  `guildid` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `leaderguid` int unsigned NOT NULL DEFAULT '0',
  `EmblemStyle` tinyint unsigned NOT NULL DEFAULT '0',
  `EmblemColor` tinyint unsigned NOT NULL DEFAULT '0',
  `BorderStyle` tinyint unsigned NOT NULL DEFAULT '0',
  `BorderColor` tinyint unsigned NOT NULL DEFAULT '0',
  `BackgroundColor` tinyint unsigned NOT NULL DEFAULT '0',
  `info` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `motd` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `createdate` int unsigned NOT NULL DEFAULT '0',
  `BankMoney` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guildid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_bank_eventlog
CREATE TABLE IF NOT EXISTS `guild_bank_eventlog` (
  `guildid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Guild Identificator',
  `LogGuid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Log record identificator - auxiliary column',
  `TabId` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Guild bank TabId',
  `EventType` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Event type',
  `PlayerGuid` int unsigned NOT NULL DEFAULT '0',
  `ItemOrMoney` int unsigned NOT NULL DEFAULT '0',
  `ItemStackCount` smallint unsigned NOT NULL DEFAULT '0',
  `DestTabId` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Destination Tab Id',
  `TimeStamp` int unsigned NOT NULL DEFAULT '0' COMMENT 'Event UNIX time',
  PRIMARY KEY (`guildid`,`LogGuid`,`TabId`),
  KEY `guildid_key` (`guildid`),
  KEY `Idx_PlayerGuid` (`PlayerGuid`),
  KEY `Idx_LogGuid` (`LogGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_bank_item
CREATE TABLE IF NOT EXISTS `guild_bank_item` (
  `guildid` int unsigned NOT NULL DEFAULT '0',
  `TabId` tinyint unsigned NOT NULL DEFAULT '0',
  `SlotId` tinyint unsigned NOT NULL DEFAULT '0',
  `item_guid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guildid`,`TabId`,`SlotId`),
  KEY `guildid_key` (`guildid`),
  KEY `Idx_item_guid` (`item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_bank_right
CREATE TABLE IF NOT EXISTS `guild_bank_right` (
  `guildid` int unsigned NOT NULL DEFAULT '0',
  `TabId` tinyint unsigned NOT NULL DEFAULT '0',
  `rid` tinyint unsigned NOT NULL DEFAULT '0',
  `gbright` tinyint unsigned NOT NULL DEFAULT '0',
  `SlotPerDay` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guildid`,`TabId`,`rid`),
  KEY `guildid_key` (`guildid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_bank_tab
CREATE TABLE IF NOT EXISTS `guild_bank_tab` (
  `guildid` int unsigned NOT NULL DEFAULT '0',
  `TabId` tinyint unsigned NOT NULL DEFAULT '0',
  `TabName` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `TabIcon` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `TabText` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`guildid`,`TabId`),
  KEY `guildid_key` (`guildid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_eventlog
CREATE TABLE IF NOT EXISTS `guild_eventlog` (
  `guildid` int unsigned NOT NULL COMMENT 'Guild Identificator',
  `LogGuid` int unsigned NOT NULL COMMENT 'Log record identificator - auxiliary column',
  `EventType` tinyint unsigned NOT NULL COMMENT 'Event type',
  `PlayerGuid1` int unsigned NOT NULL COMMENT 'Player 1',
  `PlayerGuid2` int unsigned NOT NULL COMMENT 'Player 2',
  `NewRank` tinyint unsigned NOT NULL COMMENT 'New rank(in case promotion/demotion)',
  `TimeStamp` int unsigned NOT NULL COMMENT 'Event UNIX time',
  PRIMARY KEY (`guildid`,`LogGuid`),
  KEY `Idx_PlayerGuid1` (`PlayerGuid1`),
  KEY `Idx_PlayerGuid2` (`PlayerGuid2`),
  KEY `Idx_LogGuid` (`LogGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild Eventlog';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_member
CREATE TABLE IF NOT EXISTS `guild_member` (
  `guildid` int unsigned NOT NULL COMMENT 'Guild Identificator',
  `guid` int unsigned NOT NULL,
  `rank` tinyint unsigned NOT NULL,
  `pnote` varchar(31) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `offnote` varchar(31) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  UNIQUE KEY `guid_key` (`guid`),
  KEY `guildid_key` (`guildid`),
  KEY `guildid_rank_key` (`guildid`,`rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_member_withdraw
CREATE TABLE IF NOT EXISTS `guild_member_withdraw` (
  `guid` int unsigned NOT NULL,
  `tab0` int unsigned NOT NULL DEFAULT '0',
  `tab1` int unsigned NOT NULL DEFAULT '0',
  `tab2` int unsigned NOT NULL DEFAULT '0',
  `tab3` int unsigned NOT NULL DEFAULT '0',
  `tab4` int unsigned NOT NULL DEFAULT '0',
  `tab5` int unsigned NOT NULL DEFAULT '0',
  `money` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild Member Daily Withdraws';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.guild_rank
CREATE TABLE IF NOT EXISTS `guild_rank` (
  `guildid` int unsigned NOT NULL DEFAULT '0',
  `rid` tinyint unsigned NOT NULL,
  `rname` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `rights` int unsigned DEFAULT '0',
  `BankMoneyPerDay` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guildid`,`rid`),
  KEY `Idx_rid` (`rid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.hlbg_player_stats
CREATE TABLE IF NOT EXISTS `hlbg_player_stats` (
  `player_guid` int unsigned NOT NULL COMMENT 'Player GUID (unique identifier)',
  `player_name` varchar(12) NOT NULL COMMENT 'Player character name',
  `faction` varchar(16) NOT NULL DEFAULT 'Unknown' COMMENT 'Alliance or Horde',
  `battles_participated` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total battles joined',
  `battles_won` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total battles won',
  `last_participation` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Last battle timestamp',
  `total_kills` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total player kills',
  `total_deaths` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total deaths',
  `resources_captured` int unsigned NOT NULL DEFAULT '0' COMMENT 'Total resources captured',
  PRIMARY KEY (`player_guid`),
  KEY `idx_player_name` (`player_name`) COMMENT 'Search by name',
  KEY `idx_faction` (`faction`) COMMENT 'Faction-specific leaderboards',
  KEY `idx_battles_won` (`battles_won`) COMMENT 'Win count leaderboard',
  KEY `idx_total_kills` (`total_kills`) COMMENT 'Kill count leaderboard',
  KEY `idx_last_participation` (`last_participation`) COMMENT 'Recent activity queries'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='HLBG Player Statistics - Individual player performance tracking';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.hlbg_seasons
CREATE TABLE IF NOT EXISTS `hlbg_seasons` (
  `season` smallint unsigned NOT NULL COMMENT 'Season number (increments each season)',
  `name` varchar(64) NOT NULL DEFAULT '' COMMENT 'Season display name (e.g., "Season 1: Genesis")',
  `start_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Season start timestamp',
  `end_date` timestamp NULL DEFAULT NULL COMMENT 'Season end timestamp (NULL = current season)',
  `is_active` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1 = Active season, 0 = Past season',
  `description` text COMMENT 'Season description/changelog',
  PRIMARY KEY (`season`),
  KEY `idx_is_active` (`is_active`) COMMENT 'Find current season',
  KEY `idx_dates` (`start_date`,`end_date`) COMMENT 'Date range queries'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='HLBG Season Tracking - Season metadata and names';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.hlbg_winner_history
CREATE TABLE IF NOT EXISTS `hlbg_winner_history` (
  `id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique battle identifier',
  `season` smallint unsigned NOT NULL DEFAULT '1' COMMENT 'Season number (joins with hlbg_seasons)',
  `occurred_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Battle end timestamp',
  `duration_seconds` int unsigned NOT NULL DEFAULT '0' COMMENT 'Battle duration in seconds',
  `zone_id` smallint unsigned NOT NULL DEFAULT '26' COMMENT 'Zone ID (26 = Hinterlands)',
  `map_id` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map ID (0 = Eastern Kingdoms)',
  `winner_tid` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Winner: 0=Alliance, 1=Horde, 2=Draw',
  `win_reason` varchar(32) NOT NULL DEFAULT 'depletion' COMMENT 'Win reason: depletion, tiebreaker, manual',
  `score_alliance` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Final Alliance resource count',
  `score_horde` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Final Horde resource count',
  `affix` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Affix ID: 0=None, 1=Sunlight, 2=Clear, 3=Breeze, 4=Storm, 5=Rain, 6=Fog',
  `weather` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Weather type: 0=Fine, 1=Rain, 2=Snow, 3=Storm, 4=Thunder, 5=BlackRain',
  `weather_intensity` float NOT NULL DEFAULT '0' COMMENT 'Weather intensity (0.0-1.0)',
  PRIMARY KEY (`id`),
  KEY `idx_season` (`season`) COMMENT 'Season filtering queries',
  KEY `idx_occurred_at` (`occurred_at`) COMMENT 'Date range queries',
  KEY `idx_winner_tid` (`winner_tid`) COMMENT 'Win rate aggregations',
  KEY `idx_affix` (`affix`) COMMENT 'Affix statistics queries',
  KEY `idx_weather` (`weather`) COMMENT 'Weather statistics queries',
  KEY `idx_win_reason` (`win_reason`) COMMENT 'Win condition analysis',
  KEY `idx_season_occurred` (`season`,`occurred_at`) COMMENT 'Composite index for season history'
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='HLBG Battle History - Primary table for all battle results';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.instance
CREATE TABLE IF NOT EXISTS `instance` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `map` smallint unsigned NOT NULL DEFAULT '0',
  `resettime` int unsigned NOT NULL DEFAULT '0',
  `difficulty` tinyint unsigned NOT NULL DEFAULT '0',
  `completedEncounters` int unsigned NOT NULL DEFAULT '0',
  `data` text COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `map` (`map`),
  KEY `resettime` (`resettime`),
  KEY `difficulty` (`difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.instance_reset
CREATE TABLE IF NOT EXISTS `instance_reset` (
  `mapid` smallint unsigned NOT NULL DEFAULT '0',
  `difficulty` tinyint unsigned NOT NULL DEFAULT '0',
  `resettime` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`mapid`,`difficulty`),
  KEY `difficulty` (`difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.instance_saved_go_state_data
CREATE TABLE IF NOT EXISTS `instance_saved_go_state_data` (
  `id` int unsigned NOT NULL COMMENT 'instance.id',
  `guid` int unsigned NOT NULL COMMENT 'gameobject.guid',
  `state` tinyint unsigned DEFAULT '0' COMMENT 'gameobject.state',
  PRIMARY KEY (`id`,`guid`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.item_instance
CREATE TABLE IF NOT EXISTS `item_instance` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `itemEntry` int unsigned DEFAULT '0',
  `owner_guid` int unsigned NOT NULL DEFAULT '0',
  `creatorGuid` int unsigned NOT NULL DEFAULT '0',
  `giftCreatorGuid` int unsigned NOT NULL DEFAULT '0',
  `count` int unsigned NOT NULL DEFAULT '1',
  `duration` int NOT NULL DEFAULT '0',
  `charges` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `flags` int unsigned DEFAULT '0',
  `enchantments` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `randomPropertyId` smallint NOT NULL DEFAULT '0',
  `durability` smallint unsigned NOT NULL DEFAULT '0',
  `playedTime` int unsigned NOT NULL DEFAULT '0',
  `text` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`guid`),
  KEY `idx_owner_guid` (`owner_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.item_loot_storage
CREATE TABLE IF NOT EXISTS `item_loot_storage` (
  `containerGUID` int unsigned NOT NULL,
  `itemid` int unsigned NOT NULL,
  `count` int unsigned NOT NULL,
  `item_index` int unsigned NOT NULL DEFAULT '0',
  `randomPropertyId` int NOT NULL,
  `randomSuffix` int unsigned NOT NULL,
  `follow_loot_rules` tinyint unsigned NOT NULL,
  `freeforall` tinyint unsigned NOT NULL,
  `is_blocked` tinyint unsigned NOT NULL,
  `is_counted` tinyint unsigned NOT NULL,
  `is_underthreshold` tinyint unsigned NOT NULL,
  `needs_quest` tinyint unsigned NOT NULL,
  `conditionLootId` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.item_refund_instance
CREATE TABLE IF NOT EXISTS `item_refund_instance` (
  `item_guid` int unsigned NOT NULL COMMENT 'Item GUID',
  `player_guid` int unsigned NOT NULL COMMENT 'Player GUID',
  `paidMoney` int unsigned NOT NULL DEFAULT '0',
  `paidExtendedCost` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`item_guid`,`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item Refund System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.item_soulbound_trade_data
CREATE TABLE IF NOT EXISTS `item_soulbound_trade_data` (
  `itemGuid` int unsigned NOT NULL COMMENT 'Item GUID',
  `allowedPlayers` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Space separated GUID list of players who can receive this item in trade',
  PRIMARY KEY (`itemGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item Refund System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.lag_reports
CREATE TABLE IF NOT EXISTS `lag_reports` (
  `reportId` int unsigned NOT NULL AUTO_INCREMENT,
  `guid` int unsigned NOT NULL DEFAULT '0',
  `lagType` tinyint unsigned NOT NULL DEFAULT '0',
  `mapId` smallint unsigned NOT NULL DEFAULT '0',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  `latency` int unsigned NOT NULL DEFAULT '0',
  `createTime` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`reportId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.lfg_data
CREATE TABLE IF NOT EXISTS `lfg_data` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `dungeon` int unsigned NOT NULL DEFAULT '0',
  `state` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='LFG Data';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.log_arena_fights
CREATE TABLE IF NOT EXISTS `log_arena_fights` (
  `fight_id` int unsigned NOT NULL,
  `time` datetime NOT NULL,
  `type` tinyint unsigned NOT NULL,
  `duration` int unsigned NOT NULL,
  `winner` int unsigned NOT NULL,
  `loser` int unsigned NOT NULL,
  `winner_tr` smallint unsigned NOT NULL,
  `winner_mmr` smallint unsigned NOT NULL,
  `winner_tr_change` smallint NOT NULL,
  `loser_tr` smallint unsigned NOT NULL,
  `loser_mmr` smallint unsigned NOT NULL,
  `loser_tr_change` smallint NOT NULL,
  `currOnline` int unsigned NOT NULL,
  PRIMARY KEY (`fight_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.log_arena_memberstats
CREATE TABLE IF NOT EXISTS `log_arena_memberstats` (
  `fight_id` int unsigned NOT NULL,
  `member_id` tinyint unsigned NOT NULL,
  `name` char(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `guid` int unsigned NOT NULL,
  `team` int unsigned NOT NULL,
  `account` int unsigned NOT NULL,
  `ip` char(15) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `damage` int unsigned NOT NULL,
  `heal` int unsigned NOT NULL,
  `kblows` int unsigned NOT NULL,
  PRIMARY KEY (`fight_id`,`member_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.log_encounter
CREATE TABLE IF NOT EXISTS `log_encounter` (
  `time` datetime NOT NULL,
  `map` smallint unsigned NOT NULL,
  `difficulty` tinyint unsigned NOT NULL,
  `creditType` tinyint unsigned NOT NULL,
  `creditEntry` int unsigned NOT NULL,
  `playersInfo` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.log_money
CREATE TABLE IF NOT EXISTS `log_money` (
  `sender_acc` int unsigned NOT NULL,
  `sender_guid` int unsigned NOT NULL,
  `sender_name` char(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_ip` char(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `receiver_acc` int unsigned NOT NULL,
  `receiver_name` char(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `money` bigint unsigned NOT NULL,
  `topic` char(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `date` datetime NOT NULL,
  `type` tinyint NOT NULL COMMENT '1=COD,2=AH,3=GB DEPOSIT,4=GB WITHDRAW,5=MAIL,6=TRADE'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.mail
CREATE TABLE IF NOT EXISTS `mail` (
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Identifier',
  `messageType` tinyint unsigned NOT NULL DEFAULT '0',
  `stationery` tinyint NOT NULL DEFAULT '41',
  `mailTemplateId` smallint unsigned NOT NULL DEFAULT '0',
  `sender` int unsigned NOT NULL DEFAULT '0' COMMENT 'Character Global Unique Identifier',
  `receiver` int unsigned NOT NULL DEFAULT '0' COMMENT 'Character Global Unique Identifier',
  `subject` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `body` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `has_items` tinyint unsigned NOT NULL DEFAULT '0',
  `expire_time` int unsigned NOT NULL DEFAULT '0',
  `deliver_time` int unsigned NOT NULL DEFAULT '0',
  `money` int unsigned NOT NULL DEFAULT '0',
  `cod` int unsigned NOT NULL DEFAULT '0',
  `checked` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_receiver` (`receiver`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mail System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.mail_items
CREATE TABLE IF NOT EXISTS `mail_items` (
  `mail_id` int unsigned NOT NULL DEFAULT '0',
  `item_guid` int unsigned NOT NULL DEFAULT '0',
  `receiver` int unsigned NOT NULL DEFAULT '0' COMMENT 'Character Global Unique Identifier',
  PRIMARY KEY (`item_guid`),
  KEY `idx_receiver` (`receiver`),
  KEY `idx_mail_id` (`mail_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.mail_server_character
CREATE TABLE IF NOT EXISTS `mail_server_character` (
  `guid` int unsigned NOT NULL,
  `mailId` int unsigned NOT NULL,
  PRIMARY KEY (`guid`,`mailId`),
  KEY `fk_mail_server_character` (`mailId`),
  CONSTRAINT `fk_mail_server_character` FOREIGN KEY (`mailId`) REFERENCES `mail_server_template` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.mail_server_template
CREATE TABLE IF NOT EXISTS `mail_server_template` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `moneyA` int unsigned NOT NULL DEFAULT '0',
  `moneyH` int unsigned NOT NULL DEFAULT '0',
  `subject` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `body` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `active` tinyint unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.mail_server_template_conditions
CREATE TABLE IF NOT EXISTS `mail_server_template_conditions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `templateID` int unsigned NOT NULL,
  `conditionType` enum('Level','PlayTime','Quest','Achievement','Reputation','Faction','Race','Class','AccountFlags') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `conditionValue` int unsigned NOT NULL,
  `conditionState` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_mail_template_conditions` (`templateID`),
  CONSTRAINT `fk_mail_template_conditions` FOREIGN KEY (`templateID`) REFERENCES `mail_server_template` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.mail_server_template_items
CREATE TABLE IF NOT EXISTS `mail_server_template_items` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `templateID` int unsigned NOT NULL,
  `faction` enum('Alliance','Horde') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `item` int unsigned NOT NULL,
  `itemCount` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_mail_template` (`templateID`),
  CONSTRAINT `fk_mail_template` FOREIGN KEY (`templateID`) REFERENCES `mail_server_template` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.pet_aura
CREATE TABLE IF NOT EXISTS `pet_aura` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `casterGuid` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'Full Global Unique Identifier',
  `spell` int unsigned NOT NULL DEFAULT '0',
  `effectMask` tinyint unsigned NOT NULL DEFAULT '0',
  `recalculateMask` tinyint unsigned NOT NULL DEFAULT '0',
  `stackCount` tinyint unsigned NOT NULL DEFAULT '1',
  `amount0` int DEFAULT NULL,
  `amount1` int DEFAULT NULL,
  `amount2` int DEFAULT NULL,
  `base_amount0` int DEFAULT NULL,
  `base_amount1` int DEFAULT NULL,
  `base_amount2` int DEFAULT NULL,
  `maxDuration` int NOT NULL DEFAULT '0',
  `remainTime` int NOT NULL DEFAULT '0',
  `remainCharges` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`casterGuid`,`spell`,`effectMask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pet System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.pet_spell
CREATE TABLE IF NOT EXISTS `pet_spell` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier',
  `spell` int unsigned NOT NULL DEFAULT '0' COMMENT 'Spell Identifier',
  `active` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Pet System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.pet_spell_cooldown
CREATE TABLE IF NOT EXISTS `pet_spell_cooldown` (
  `guid` int unsigned NOT NULL DEFAULT '0' COMMENT 'Global Unique Identifier, Low part',
  `spell` int unsigned NOT NULL DEFAULT '0' COMMENT 'Spell Identifier',
  `category` int unsigned DEFAULT '0',
  `time` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.petition
CREATE TABLE IF NOT EXISTS `petition` (
  `ownerguid` int unsigned NOT NULL,
  `petitionguid` int unsigned DEFAULT '0',
  `petition_id` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ownerguid`,`type`),
  UNIQUE KEY `index_ownerguid_petitionguid` (`ownerguid`,`petitionguid`),
  KEY `idx_petition_id` (`petition_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.petition_sign
CREATE TABLE IF NOT EXISTS `petition_sign` (
  `ownerguid` int unsigned NOT NULL,
  `petitionguid` int unsigned NOT NULL DEFAULT '0',
  `petition_id` int unsigned NOT NULL DEFAULT '0',
  `playerguid` int unsigned NOT NULL DEFAULT '0',
  `player_account` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`petitionguid`,`playerguid`),
  KEY `Idx_playerguid` (`playerguid`),
  KEY `Idx_ownerguid` (`ownerguid`),
  KEY `idx_petition_id_player` (`petition_id`,`playerguid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Guild System';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.players_reports_status
CREATE TABLE IF NOT EXISTS `players_reports_status` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `creation_time` int unsigned NOT NULL DEFAULT '0',
  `average` float NOT NULL DEFAULT '0',
  `total_reports` bigint unsigned NOT NULL DEFAULT '0',
  `speed_reports` bigint unsigned NOT NULL DEFAULT '0',
  `fly_reports` bigint unsigned NOT NULL DEFAULT '0',
  `jump_reports` bigint unsigned NOT NULL DEFAULT '0',
  `waterwalk_reports` bigint unsigned NOT NULL DEFAULT '0',
  `teleportplane_reports` bigint unsigned NOT NULL DEFAULT '0',
  `climb_reports` bigint unsigned NOT NULL DEFAULT '0',
  `teleport_reports` bigint unsigned NOT NULL DEFAULT '0',
  `ignorecontrol_reports` bigint unsigned NOT NULL DEFAULT '0',
  `zaxis_reports` bigint unsigned NOT NULL DEFAULT '0',
  `antiswim_reports` bigint unsigned NOT NULL DEFAULT '0',
  `gravity_reports` bigint unsigned NOT NULL DEFAULT '0',
  `antiknockback_reports` bigint unsigned NOT NULL DEFAULT '0',
  `no_fall_damage_reports` bigint unsigned NOT NULL DEFAULT '0',
  `op_ack_hack_reports` bigint unsigned NOT NULL DEFAULT '0',
  `counter_measures_reports` bigint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.pool_quest_save
CREATE TABLE IF NOT EXISTS `pool_quest_save` (
  `pool_id` int unsigned NOT NULL DEFAULT '0',
  `quest_id` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`pool_id`,`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.profanity_name
CREATE TABLE IF NOT EXISTS `profanity_name` (
  `name` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.pvpstats_battlegrounds
CREATE TABLE IF NOT EXISTS `pvpstats_battlegrounds` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `winner_faction` tinyint NOT NULL,
  `bracket_id` tinyint unsigned NOT NULL,
  `type` tinyint unsigned NOT NULL,
  `date` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.pvpstats_players
CREATE TABLE IF NOT EXISTS `pvpstats_players` (
  `battleground_id` bigint unsigned NOT NULL,
  `character_guid` int unsigned NOT NULL,
  `winner` bit(1) NOT NULL,
  `score_killing_blows` int unsigned DEFAULT NULL,
  `score_deaths` int unsigned DEFAULT NULL,
  `score_honorable_kills` int unsigned DEFAULT NULL,
  `score_bonus_honor` int unsigned DEFAULT NULL,
  `score_damage_done` int unsigned DEFAULT NULL,
  `score_healing_done` int unsigned DEFAULT NULL,
  `attr_1` int unsigned DEFAULT '0',
  `attr_2` int unsigned DEFAULT '0',
  `attr_3` int unsigned DEFAULT '0',
  `attr_4` int unsigned DEFAULT '0',
  `attr_5` int unsigned DEFAULT '0',
  PRIMARY KEY (`battleground_id`,`character_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.quest_tracker
CREATE TABLE IF NOT EXISTS `quest_tracker` (
  `id` int unsigned DEFAULT '0',
  `character_guid` int unsigned NOT NULL DEFAULT '0',
  `quest_accept_time` datetime NOT NULL,
  `quest_complete_time` datetime DEFAULT NULL,
  `quest_abandon_time` datetime DEFAULT NULL,
  `completed_by_gm` tinyint NOT NULL DEFAULT '0',
  `core_hash` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0',
  `core_revision` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.recovery_item
CREATE TABLE IF NOT EXISTS `recovery_item` (
  `Id` int unsigned NOT NULL AUTO_INCREMENT,
  `Guid` int unsigned NOT NULL DEFAULT '0',
  `ItemEntry` int unsigned DEFAULT '0',
  `Count` int unsigned NOT NULL DEFAULT '0',
  `DeleteDate` int unsigned DEFAULT NULL,
  PRIMARY KEY (`Id`),
  KEY `idx_guid` (`Guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.reserved_name
CREATE TABLE IF NOT EXISTS `reserved_name` (
  `name` varchar(12) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player Reserved Names';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Prozedur acore_chars.SelectHeirloomPackage
DELIMITER //
CREATE PROCEDURE `SelectHeirloomPackage`(
    IN p_item_guid INT UNSIGNED,
    IN p_player_guid INT UNSIGNED,
    IN p_item_entry INT UNSIGNED,
    IN p_package_id TINYINT UNSIGNED,
    OUT p_result_code INT,
    OUT p_result_message VARCHAR(128)
)
BEGIN
    DECLARE v_existing_package TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_existing_level TINYINT UNSIGNED DEFAULT 1;
    DECLARE v_existing_essence INT UNSIGNED DEFAULT 0;
    DECLARE v_refund_essence INT UNSIGNED DEFAULT 0;
    
    -- Check if item already has a package
    SELECT package_id, package_level, essence_invested 
    INTO v_existing_package, v_existing_level, v_existing_essence
    FROM dc_heirloom_player_packages
    WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
    
    IF v_existing_package IS NULL THEN
        -- First time selecting a package
        INSERT INTO dc_heirloom_player_packages 
            (item_guid, player_guid, item_entry, package_id, package_level, essence_invested)
        VALUES 
            (p_item_guid, p_player_guid, p_item_entry, p_package_id, 1, 50);
        
        SET p_result_code = 1;
        SET p_result_message = CONCAT('Package selected! Starting at level 1.');
        
    ELSEIF v_existing_package = p_package_id THEN
        -- Same package, no change needed
        SET p_result_code = 0;
        SET p_result_message = 'You already have this package selected.';
        
    ELSE
        -- Changing to different package - calculate 50% refund
        SET v_refund_essence = FLOOR(v_existing_essence / 2);
        
        -- Log the package change
        INSERT INTO dc_heirloom_package_history
            (item_guid, player_guid, old_package_id, old_package_level, 
             new_package_id, new_package_level, essence_refunded, reason)
        VALUES
            (p_item_guid, p_player_guid, v_existing_package, v_existing_level,
             p_package_id, 1, v_refund_essence, 'manual_respec');
        
        -- Update to new package at level 1
        UPDATE dc_heirloom_player_packages
        SET package_id = p_package_id,
            package_level = 1,
            essence_invested = 50,
            times_respec = times_respec + 1
        WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
        
        SET p_result_code = 2;
        SET p_result_message = CONCAT('Package changed! Refunded ', v_refund_essence, ' essence (50%).');
    END IF;
END//
DELIMITER ;

-- Exportiere Struktur von Prozedur acore_chars.sp_LogChallengeModeEvent
DELIMITER //
CREATE PROCEDURE `sp_LogChallengeModeEvent`(
    IN p_guid INT UNSIGNED,
    IN p_event_type VARCHAR(20),
    IN p_modes_before INT UNSIGNED,
    IN p_modes_after INT UNSIGNED,
    IN p_event_details TEXT,
    IN p_character_level TINYINT UNSIGNED,
    IN p_map_id SMALLINT UNSIGNED,
    IN p_zone_id SMALLINT UNSIGNED,
    IN p_position_x FLOAT,
    IN p_position_y FLOAT,
    IN p_position_z FLOAT,
    IN p_killer_entry INT UNSIGNED,
    IN p_killer_name VARCHAR(100)
)
BEGIN
    INSERT INTO `dc_character_challenge_mode_log` (
        `guid`,
        `event_type`,
        `modes_before`,
        `modes_after`,
        `event_details`,
        `character_level`,
        `map_id`,
        `zone_id`,
        `position_x`,
        `position_y`,
        `position_z`,
        `killer_entry`,
        `killer_name`
    ) VALUES (
        p_guid,
        p_event_type,
        p_modes_before,
        p_modes_after,
        p_event_details,
        p_character_level,
        p_map_id,
        p_zone_id,
        p_position_x,
        p_position_y,
        p_position_z,
        p_killer_entry,
        p_killer_name
    );
END//
DELIMITER ;

-- Exportiere Struktur von Tabelle acore_chars.updates
CREATE TABLE IF NOT EXISTS `updates` (
  `name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'filename with extension of the update.',
  `hash` char(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'sha1 hash of the sql file.',
  `state` enum('RELEASED','CUSTOM','MODULE','ARCHIVED','PENDING') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'RELEASED' COMMENT 'defines if an update is released or archived.',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'timestamp when the query was applied.',
  `speed` int unsigned NOT NULL DEFAULT '0' COMMENT 'time the query takes to apply in ms.',
  PRIMARY KEY (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='List of all applied updates in this database.';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.updates_include
CREATE TABLE IF NOT EXISTS `updates_include` (
  `path` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'directory to include. $ means relative to the source directory.',
  `state` enum('RELEASED','ARCHIVED','CUSTOM','PENDING') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'RELEASED' COMMENT 'defines if the directory contains released or archived updates.',
  PRIMARY KEY (`path`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='List of directories where we want to include sql updates.';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Prozedur acore_chars.UpgradeHeirloomPackage
DELIMITER //
CREATE PROCEDURE `UpgradeHeirloomPackage`(
    IN p_item_guid INT UNSIGNED,
    IN p_player_guid INT UNSIGNED,
    OUT p_result_code INT,
    OUT p_new_level TINYINT UNSIGNED,
    OUT p_essence_cost INT UNSIGNED,
    OUT p_result_message VARCHAR(128)
)
BEGIN
    DECLARE v_package_id TINYINT UNSIGNED;
    DECLARE v_current_level TINYINT UNSIGNED;
    DECLARE v_current_essence INT UNSIGNED;
    DECLARE v_upgrade_cost INT UNSIGNED;
    
    -- Get current package info
    SELECT package_id, package_level, essence_invested
    INTO v_package_id, v_current_level, v_current_essence
    FROM dc_heirloom_player_packages
    WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
    
    IF v_package_id IS NULL THEN
        SET p_result_code = -1;
        SET p_new_level = 0;
        SET p_essence_cost = 0;
        SET p_result_message = 'No package selected for this item.';
        
    ELSEIF v_current_level >= 15 THEN
        SET p_result_code = -2;
        SET p_new_level = 15;
        SET p_essence_cost = 0;
        SET p_result_message = 'Package is already at maximum level (15).';
        
    ELSE
        -- Get upgrade cost for next level (query world database)
        -- Note: In production, this would query acore_world.dc_heirloom_package_levels
        -- For now, use the formula directly
        SET v_upgrade_cost = CASE v_current_level + 1
            WHEN 2 THEN 75 WHEN 3 THEN 100 WHEN 4 THEN 150 WHEN 5 THEN 200
            WHEN 6 THEN 275 WHEN 7 THEN 350 WHEN 8 THEN 450 WHEN 9 THEN 575
            WHEN 10 THEN 725 WHEN 11 THEN 900 WHEN 12 THEN 1100 WHEN 13 THEN 1350
            WHEN 14 THEN 1650 WHEN 15 THEN 2050 ELSE 0
        END;
        
        -- Log the upgrade
        INSERT INTO dc_heirloom_upgrade_log
            (item_guid, player_guid, package_id, from_level, to_level, essence_cost)
        VALUES
            (p_item_guid, p_player_guid, v_package_id, v_current_level, v_current_level + 1, v_upgrade_cost);
        
        -- Update package level
        UPDATE dc_heirloom_player_packages
        SET package_level = package_level + 1,
            essence_invested = essence_invested + v_upgrade_cost
        WHERE item_guid = p_item_guid AND player_guid = p_player_guid;
        
        SET p_result_code = 1;
        SET p_new_level = v_current_level + 1;
        SET p_essence_cost = v_upgrade_cost;
        SET p_result_message = CONCAT('Upgraded to level ', v_current_level + 1, '!');
    END IF;
END//
DELIMITER ;

-- Exportiere Struktur von View acore_chars.v_player_heirloom_upgrades
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `v_player_heirloom_upgrades` (
	`player_guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID',
	`item_guid` INT UNSIGNED NOT NULL COMMENT 'Item instance GUID from item_instance',
	`item_entry` INT UNSIGNED NOT NULL COMMENT 'Item template entry (e.g., 300365)',
	`upgrade_level` TINYINT UNSIGNED NOT NULL COMMENT 'Current upgrade level (1-15)',
	`package_id` TINYINT UNSIGNED NOT NULL COMMENT 'Chosen package (1-12)',
	`enchant_id` INT UNSIGNED NOT NULL COMMENT 'Applied SpellItemEnchantment.dbc ID',
	`essence_invested` INT UNSIGNED NOT NULL COMMENT 'Total essence spent',
	`tokens_invested` INT UNSIGNED NOT NULL COMMENT 'Total tokens spent',
	`first_upgraded_at` TIMESTAMP NULL COMMENT 'When first upgraded',
	`last_upgraded_at` TIMESTAMP NULL COMMENT 'When last upgraded'
);

-- Exportiere Struktur von View acore_chars.v_seasonal_leaderboard
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `v_seasonal_leaderboard` (
	`player_guid` INT UNSIGNED NOT NULL,
	`season_id` INT UNSIGNED NOT NULL,
	`total_tokens_earned` BIGINT UNSIGNED NULL,
	`total_essence_earned` BIGINT UNSIGNED NULL,
	`quests_completed` INT UNSIGNED NULL,
	`bosses_killed` INT UNSIGNED NULL,
	`chests_claimed` INT UNSIGNED NULL,
	`token_rank` BIGINT UNSIGNED NOT NULL,
	`boss_rank` BIGINT UNSIGNED NOT NULL
);

-- Exportiere Struktur von View acore_chars.v_transaction_summary
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `v_transaction_summary` (
	`transaction_type` ENUM('quest','creature','creature_group','chest','manual','adjustment') NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`total_transactions` BIGINT NOT NULL,
	`total_tokens` DECIMAL(32,0) NULL,
	`total_essence` DECIMAL(32,0) NULL,
	`avg_token_reward` DECIMAL(14,4) NULL,
	`first_transaction` BIGINT UNSIGNED NULL,
	`last_transaction` BIGINT UNSIGNED NULL
);

-- Exportiere Struktur von View acore_chars.v_weekly_top_performers
-- Erstelle temporäre Tabelle, um View-Abhängigkeiten zuvorzukommen
CREATE TABLE `v_weekly_top_performers` (
	`player_guid` INT UNSIGNED NOT NULL,
	`season_id` INT UNSIGNED NOT NULL,
	`weekly_tokens_earned` INT UNSIGNED NULL,
	`weekly_essence_earned` INT UNSIGNED NULL,
	`quests_completed` INT UNSIGNED NULL,
	`bosses_killed` INT UNSIGNED NULL,
	`weekly_rank` BIGINT UNSIGNED NOT NULL
);

-- Exportiere Struktur von Tabelle acore_chars.warden_action
CREATE TABLE IF NOT EXISTS `warden_action` (
  `wardenId` smallint unsigned NOT NULL,
  `action` tinyint unsigned DEFAULT NULL,
  PRIMARY KEY (`wardenId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.world_state
CREATE TABLE IF NOT EXISTS `world_state` (
  `Id` int unsigned NOT NULL COMMENT 'Internal save ID',
  `Data` longtext,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='WorldState save system';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.worldstates
CREATE TABLE IF NOT EXISTS `worldstates` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `value` int unsigned NOT NULL DEFAULT '0',
  `comment` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Variable Saves';

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.zone_difficulty_completion_logs
CREATE TABLE IF NOT EXISTS `zone_difficulty_completion_logs` (
  `guid` int unsigned NOT NULL,
  `type` tinyint NOT NULL,
  `mode` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.zone_difficulty_encounter_logs
CREATE TABLE IF NOT EXISTS `zone_difficulty_encounter_logs` (
  `InstanceId` int NOT NULL DEFAULT '0',
  `TimestampStart` int NOT NULL DEFAULT '0',
  `TimestampEnd` int NOT NULL DEFAULT '0',
  `Map` int NOT NULL DEFAULT '0',
  `BossId` int NOT NULL DEFAULT '0',
  `PlayerGuid` int NOT NULL DEFAULT '0',
  `Mode` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`InstanceId`,`TimestampStart`,`PlayerGuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.zone_difficulty_instance_saves
CREATE TABLE IF NOT EXISTS `zone_difficulty_instance_saves` (
  `InstanceID` int NOT NULL DEFAULT '0',
  `HardmodeOn` tinyint NOT NULL DEFAULT '0',
  `HardmodePossible` tinyint NOT NULL DEFAULT '1',
  PRIMARY KEY (`InstanceID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Exportiere Struktur von Tabelle acore_chars.zone_difficulty_mythicmode_score
CREATE TABLE IF NOT EXISTS `zone_difficulty_mythicmode_score` (
  `GUID` int NOT NULL DEFAULT '0',
  `Type` tinyint NOT NULL DEFAULT '0',
  `Score` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`GUID`,`Type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Daten-Export vom Benutzer nicht ausgewählt

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `dc_guild_leaderboard`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dc_guild_leaderboard` AS select `g`.`guildid` AS `guildid`,`g`.`name` AS `guild_name`,`gs`.`total_members` AS `total_members`,`gs`.`members_with_upgrades` AS `members_with_upgrades`,`gs`.`total_guild_upgrades` AS `total_guild_upgrades`,`gs`.`total_items_upgraded` AS `total_items_upgraded`,`gs`.`average_ilvl_increase` AS `average_ilvl_increase`,`gs`.`total_essence_invested` AS `total_essence_invested`,`gs`.`total_tokens_invested` AS `total_tokens_invested` from (`guild` `g` join `dc_guild_upgrade_stats` `gs` on((`gs`.`guild_id` = `g`.`guildid`))) order by `gs`.`total_guild_upgrades` desc
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `dc_player_progression_summary`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dc_player_progression_summary` AS select `p`.`player_guid` AS `player_guid`,`p`.`total_mastery_points` AS `total_mastery_points`,`p`.`mastery_rank` AS `mastery_rank`,`p`.`items_fully_upgraded` AS `items_fully_upgraded`,`p`.`total_upgrades_applied` AS `total_upgrades_applied`,`s`.`essence_earned` AS `essence_earned`,`s`.`tokens_earned` AS `tokens_earned`,`s`.`essence_spent` AS `essence_spent`,`s`.`tokens_spent` AS `tokens_spent`,`s`.`items_upgraded` AS `items_upgraded`,`s`.`season_id` AS `season_id` from (`dc_player_artifact_mastery` `p` left join `dc_player_season_data` `s` on((`s`.`player_guid` = `p`.`player_guid`))) where (`s`.`season_id` = (select `dc_seasons`.`season_id` from `dc_seasons` where (`dc_seasons`.`is_active` = 1) limit 1))
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `dc_player_upgrade_summary`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dc_player_upgrade_summary` AS select `iu`.`player_guid` AS `player_guid`,count(distinct `iu`.`item_guid`) AS `items_upgraded`,sum(`iu`.`essence_invested`) AS `total_essence_spent`,sum(`iu`.`tokens_invested`) AS `total_tokens_spent`,avg(`iu`.`current_stat_multiplier`) AS `average_stat_multiplier`,avg((`iu`.`upgraded_item_level` - `iu`.`base_item_level`)) AS `average_ilvl_gain`,max(`iu`.`last_upgraded_timestamp`) AS `last_upgraded`,sum((case when (`iu`.`upgrade_level` = 15) then 1 else 0 end)) AS `fully_upgraded_items` from `dc_item_upgrades` `iu` group by `iu`.`player_guid`
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `dc_recent_upgrades_feed`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dc_recent_upgrades_feed` AS select `h`.`history_id` AS `history_id`,`h`.`player_guid` AS `player_guid`,`c`.`name` AS `player_name`,`h`.`item_id` AS `item_id`,`h`.`upgrade_from` AS `upgrade_from`,`h`.`upgrade_to` AS `upgrade_to`,`h`.`essence_cost` AS `essence_cost`,`h`.`token_cost` AS `token_cost`,`h`.`timestamp` AS `timestamp`,`h`.`season_id` AS `season_id` from (`dc_upgrade_history` `h` left join `characters` `c` on((`c`.`guid` = `h`.`player_guid`))) order by `h`.`timestamp` desc limit 50
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `dc_top_upgraders`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dc_top_upgraders` AS select `s`.`player_guid` AS `player_guid`,`c`.`name` AS `player_name`,`s`.`upgrades_applied` AS `upgrades_applied`,`s`.`items_upgraded` AS `items_upgraded`,`s`.`essence_spent` AS `essence_spent`,`s`.`tokens_spent` AS `tokens_spent`,`p`.`mastery_rank` AS `mastery_rank`,`p`.`total_mastery_points` AS `total_mastery_points`,`s`.`season_id` AS `season_id` from ((`dc_player_season_data` `s` left join `characters` `c` on((`c`.`guid` = `s`.`player_guid`))) left join `dc_player_artifact_mastery` `p` on((`p`.`player_guid` = `s`.`player_guid`))) where (`s`.`season_id` = (select `dc_seasons`.`season_id` from `dc_seasons` where (`dc_seasons`.`is_active` = 1) limit 1)) order by `s`.`upgrades_applied` desc limit 100
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `dc_upgrade_speed_stats`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dc_upgrade_speed_stats` AS select `dc_item_upgrade_log`.`player_guid` AS `player_guid`,count(0) AS `total_upgrades`,((count(0) / ((unix_timestamp(max(`dc_item_upgrade_log`.`timestamp`)) - unix_timestamp(min(`dc_item_upgrade_log`.`timestamp`))) + 1)) * 86400) AS `upgrades_per_day`,min(`dc_item_upgrade_log`.`timestamp`) AS `first_upgrade`,max(`dc_item_upgrade_log`.`timestamp`) AS `last_upgrade`,avg((`dc_item_upgrade_log`.`essence_cost` + `dc_item_upgrade_log`.`token_cost`)) AS `average_cost_per_upgrade` from `dc_item_upgrade_log` group by `dc_item_upgrade_log`.`player_guid`
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `v_player_heirloom_upgrades`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_player_heirloom_upgrades` AS select `hu`.`player_guid` AS `player_guid`,`hu`.`item_guid` AS `item_guid`,`hu`.`item_entry` AS `item_entry`,`hu`.`upgrade_level` AS `upgrade_level`,`hu`.`package_id` AS `package_id`,`hu`.`enchant_id` AS `enchant_id`,`hu`.`essence_invested` AS `essence_invested`,`hu`.`tokens_invested` AS `tokens_invested`,`hu`.`first_upgraded_at` AS `first_upgraded_at`,`hu`.`last_upgraded_at` AS `last_upgraded_at` from `dc_heirloom_upgrades` `hu`
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `v_seasonal_leaderboard`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_seasonal_leaderboard` AS select `dc_player_seasonal_stats`.`player_guid` AS `player_guid`,`dc_player_seasonal_stats`.`season_id` AS `season_id`,`dc_player_seasonal_stats`.`total_tokens_earned` AS `total_tokens_earned`,`dc_player_seasonal_stats`.`total_essence_earned` AS `total_essence_earned`,`dc_player_seasonal_stats`.`quests_completed` AS `quests_completed`,`dc_player_seasonal_stats`.`bosses_killed` AS `bosses_killed`,`dc_player_seasonal_stats`.`chests_claimed` AS `chests_claimed`,row_number() OVER (PARTITION BY `dc_player_seasonal_stats`.`season_id` ORDER BY `dc_player_seasonal_stats`.`total_tokens_earned` desc )  AS `token_rank`,row_number() OVER (PARTITION BY `dc_player_seasonal_stats`.`season_id` ORDER BY `dc_player_seasonal_stats`.`bosses_killed` desc )  AS `boss_rank` from `dc_player_seasonal_stats` where (`dc_player_seasonal_stats`.`total_tokens_earned` > 0) order by `dc_player_seasonal_stats`.`season_id`,`dc_player_seasonal_stats`.`total_tokens_earned` desc
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `v_transaction_summary`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_transaction_summary` AS select `dc_reward_transactions`.`transaction_type` AS `transaction_type`,count(0) AS `total_transactions`,sum(`dc_reward_transactions`.`token_amount`) AS `total_tokens`,sum(`dc_reward_transactions`.`essence_amount`) AS `total_essence`,avg(`dc_reward_transactions`.`token_amount`) AS `avg_token_reward`,min(`dc_reward_transactions`.`transaction_at`) AS `first_transaction`,max(`dc_reward_transactions`.`transaction_at`) AS `last_transaction` from `dc_reward_transactions` group by `dc_reward_transactions`.`transaction_type`
;

-- Entferne temporäre Tabelle und erstelle die eigentliche View
DROP TABLE IF EXISTS `v_weekly_top_performers`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_weekly_top_performers` AS select `dc_player_seasonal_stats`.`player_guid` AS `player_guid`,`dc_player_seasonal_stats`.`season_id` AS `season_id`,`dc_player_seasonal_stats`.`weekly_tokens_earned` AS `weekly_tokens_earned`,`dc_player_seasonal_stats`.`weekly_essence_earned` AS `weekly_essence_earned`,`dc_player_seasonal_stats`.`quests_completed` AS `quests_completed`,`dc_player_seasonal_stats`.`bosses_killed` AS `bosses_killed`,row_number() OVER (PARTITION BY `dc_player_seasonal_stats`.`season_id` ORDER BY `dc_player_seasonal_stats`.`weekly_tokens_earned` desc )  AS `weekly_rank` from `dc_player_seasonal_stats` where (`dc_player_seasonal_stats`.`weekly_reset_at` = (select max(`dc_player_seasonal_stats`.`weekly_reset_at`) from `dc_player_seasonal_stats` limit 1)) order by `dc_player_seasonal_stats`.`weekly_tokens_earned` desc
;

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
