/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

CREATE TABLE IF NOT EXISTS `achievement_category_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Parent` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Ui_Order` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `achievement_criteria_data` (
  `criteria_id` int NOT NULL,
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `value1` int unsigned NOT NULL DEFAULT '0',
  `value2` int unsigned NOT NULL DEFAULT '0',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`criteria_id`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Achievment system';

CREATE TABLE IF NOT EXISTS `achievement_criteria_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Achievement_Id` int NOT NULL DEFAULT '0',
  `Type` int NOT NULL DEFAULT '0',
  `Asset_Id` int NOT NULL DEFAULT '0',
  `Quantity` int NOT NULL DEFAULT '0',
  `Start_Event` int NOT NULL DEFAULT '0',
  `Start_Asset` int NOT NULL DEFAULT '0',
  `Fail_Event` int NOT NULL DEFAULT '0',
  `Fail_Asset` int NOT NULL DEFAULT '0',
  `Description_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `Timer_Start_Event` int NOT NULL DEFAULT '0',
  `Timer_Asset_Id` int NOT NULL DEFAULT '0',
  `Timer_Time` int NOT NULL DEFAULT '0',
  `Ui_Order` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `achievement_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Faction` int NOT NULL DEFAULT '0',
  `Instance_Id` int NOT NULL DEFAULT '0',
  `Supercedes` int NOT NULL DEFAULT '0',
  `Title_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Description_Lang_enUS` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enGB` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_koKR` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_frFR` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_deDE` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enCN` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhCN` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enTW` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhTW` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esES` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esMX` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ruRU` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptPT` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptBR` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_itIT` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Category` int NOT NULL DEFAULT '0',
  `Points` int NOT NULL DEFAULT '0',
  `Ui_Order` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `IconID` int NOT NULL DEFAULT '0',
  `Reward_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Reward_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Minimum_Criteria` int NOT NULL DEFAULT '0',
  `Shares_Criteria` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `achievement_reward` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `TitleA` int unsigned NOT NULL DEFAULT '0',
  `TitleH` int unsigned NOT NULL DEFAULT '0',
  `ItemID` int unsigned NOT NULL DEFAULT '0',
  `Sender` int unsigned NOT NULL DEFAULT '0',
  `Subject` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MailTemplateID` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `achievement_reward_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `Locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Subject` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`ID`,`Locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `acore_string` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `content_default` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `locale_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `locale_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `antidos_opcode_policies` (
  `Opcode` smallint unsigned NOT NULL,
  `Policy` tinyint unsigned NOT NULL,
  `MaxAllowedCount` smallint unsigned NOT NULL,
  PRIMARY KEY (`Opcode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `areagroup_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `AreaID_1` int NOT NULL DEFAULT '0',
  `AreaID_2` int NOT NULL DEFAULT '0',
  `AreaID_3` int NOT NULL DEFAULT '0',
  `AreaID_4` int NOT NULL DEFAULT '0',
  `AreaID_5` int NOT NULL DEFAULT '0',
  `AreaID_6` int NOT NULL DEFAULT '0',
  `NextAreaID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `areapoi_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Importance` int NOT NULL DEFAULT '0',
  `Icon_1` int NOT NULL DEFAULT '0',
  `Icon_2` int NOT NULL DEFAULT '0',
  `Icon_3` int NOT NULL DEFAULT '0',
  `Icon_4` int NOT NULL DEFAULT '0',
  `Icon_5` int NOT NULL DEFAULT '0',
  `Icon_6` int NOT NULL DEFAULT '0',
  `Icon_7` int NOT NULL DEFAULT '0',
  `Icon_8` int NOT NULL DEFAULT '0',
  `Icon_9` int NOT NULL DEFAULT '0',
  `FactionID` int NOT NULL DEFAULT '0',
  `X` float NOT NULL DEFAULT '0',
  `Y` float NOT NULL DEFAULT '0',
  `Z` float NOT NULL DEFAULT '0',
  `ContinentID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `AreaID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Description_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `WorldStateID` int NOT NULL DEFAULT '0',
  `WorldMapLink` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `areatable_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ContinentID` int NOT NULL DEFAULT '0',
  `ParentAreaID` int NOT NULL DEFAULT '0',
  `AreaBit` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `SoundProviderPref` int NOT NULL DEFAULT '0',
  `SoundProviderPrefUnderwater` int NOT NULL DEFAULT '0',
  `AmbienceID` int NOT NULL DEFAULT '0',
  `ZoneMusic` int NOT NULL DEFAULT '0',
  `IntroSound` int NOT NULL DEFAULT '0',
  `ExplorationLevel` int NOT NULL DEFAULT '0',
  `AreaName_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `FactionGroupMask` int NOT NULL DEFAULT '0',
  `LiquidTypeID_1` int NOT NULL DEFAULT '0',
  `LiquidTypeID_2` int NOT NULL DEFAULT '0',
  `LiquidTypeID_3` int NOT NULL DEFAULT '0',
  `LiquidTypeID_4` int NOT NULL DEFAULT '0',
  `MinElevation` float NOT NULL DEFAULT '0',
  `Ambient_Multiplier` float NOT NULL DEFAULT '0',
  `Lightid` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `areatrigger` (
  `entry` int unsigned NOT NULL AUTO_INCREMENT,
  `map` int unsigned NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `radius` float NOT NULL DEFAULT '0' COMMENT 'Seems to be a box of size yards with center at x,y,z',
  `length` float NOT NULL DEFAULT '0' COMMENT 'Most commonly used when size is 0, but not always',
  `width` float NOT NULL DEFAULT '0' COMMENT 'Most commonly used when size is 0, but not always',
  `height` float NOT NULL DEFAULT '0' COMMENT 'Most commonly used when size is 0, but not always',
  `orientation` float NOT NULL DEFAULT '0' COMMENT 'Most commonly used when size is 0, but not always',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB AUTO_INCREMENT=6449 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `areatrigger_involvedrelation` (
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Trigger System';

CREATE TABLE IF NOT EXISTS `areatrigger_scripts` (
  `entry` int NOT NULL,
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `areatrigger_tavern` (
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Identifier',
  `name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `faction` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Trigger System';

CREATE TABLE IF NOT EXISTS `areatrigger_teleport` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `target_map` smallint unsigned NOT NULL DEFAULT '0',
  `target_position_x` float NOT NULL DEFAULT '0',
  `target_position_y` float NOT NULL DEFAULT '0',
  `target_position_z` float NOT NULL DEFAULT '0',
  `target_orientation` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`),
  FULLTEXT KEY `name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Trigger System';

CREATE TABLE IF NOT EXISTS `arena_season_reward` (
  `group_id` int NOT NULL COMMENT 'id from arena_season_reward_group table',
  `type` enum('achievement','item') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'achievement',
  `entry` int unsigned NOT NULL COMMENT 'For item type - item entry, for achievement - achevement id.',
  PRIMARY KEY (`group_id`,`type`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `arena_season_reward_group` (
  `id` int NOT NULL AUTO_INCREMENT,
  `arena_season` tinyint unsigned NOT NULL,
  `criteria_type` enum('pct','abs') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pct' COMMENT 'Determines how rankings are evaluated: "pct" - percentage-based (e.g., top 20% of the ladder), "abs" - absolute position-based (e.g., top 10 players).',
  `min_criteria` float NOT NULL,
  `max_criteria` float NOT NULL,
  `reward_mail_template_id` int unsigned DEFAULT NULL,
  `reward_mail_subject` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reward_mail_body` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `gold_reward` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=40 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `auctionhouse_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `FactionID` int NOT NULL DEFAULT '0',
  `DepositRate` int NOT NULL DEFAULT '0',
  `ConsignmentRate` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `auctionhousebot_professionItems` (
  `Entry` int NOT NULL AUTO_INCREMENT,
  `Item` int NOT NULL,
  PRIMARY KEY (`Entry`)
) ENGINE=InnoDB AUTO_INCREMENT=3661 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `bankbagslotprices_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Cost` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `barbershopstyle_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Type` int NOT NULL DEFAULT '0',
  `DisplayName_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Description_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Cost_Modifier` float NOT NULL DEFAULT '0',
  `Race` int NOT NULL DEFAULT '0',
  `Sex` int NOT NULL DEFAULT '0',
  `Data` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `battleground_template` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `MinPlayersPerTeam` smallint unsigned NOT NULL DEFAULT '0',
  `MaxPlayersPerTeam` smallint unsigned NOT NULL DEFAULT '0',
  `MinLvl` tinyint unsigned NOT NULL DEFAULT '0',
  `MaxLvl` tinyint unsigned NOT NULL DEFAULT '0',
  `AllianceStartLoc` int unsigned DEFAULT NULL,
  `AllianceStartO` float NOT NULL,
  `HordeStartLoc` int unsigned DEFAULT NULL,
  `HordeStartO` float NOT NULL,
  `StartMaxDist` float NOT NULL DEFAULT '0',
  `Weight` tinyint unsigned NOT NULL DEFAULT '1',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `Comment` char(38) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `battlemaster_entry` (
  `entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Entry of a creature',
  `bg_template` int unsigned NOT NULL DEFAULT '0' COMMENT 'Battleground template id',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `battlemasterlist_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MapID_1` int NOT NULL DEFAULT '0',
  `MapID_2` int NOT NULL DEFAULT '0',
  `MapID_3` int NOT NULL DEFAULT '0',
  `MapID_4` int NOT NULL DEFAULT '0',
  `MapID_5` int NOT NULL DEFAULT '0',
  `MapID_6` int NOT NULL DEFAULT '0',
  `MapID_7` int NOT NULL DEFAULT '0',
  `MapID_8` int NOT NULL DEFAULT '0',
  `InstanceType` int NOT NULL DEFAULT '0',
  `GroupsAllowed` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `MaxGroupSize` int NOT NULL DEFAULT '0',
  `HolidayWorldState` int NOT NULL DEFAULT '0',
  `Minlevel` int NOT NULL DEFAULT '0',
  `Maxlevel` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `beastmaster_tames` (
  `entry` int unsigned NOT NULL,
  `name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `family` int unsigned NOT NULL,
  `rarity` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `broadcast_text` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `LanguageID` int DEFAULT NULL,
  `MaleText` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `FemaleText` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `EmoteID1` int DEFAULT NULL,
  `EmoteID2` int DEFAULT NULL,
  `EmoteID3` int DEFAULT NULL,
  `EmoteDelay1` int DEFAULT NULL,
  `EmoteDelay2` int DEFAULT NULL,
  `EmoteDelay3` int DEFAULT NULL,
  `SoundEntriesId` int DEFAULT NULL,
  `EmotesID` int DEFAULT NULL,
  `Flags` int DEFAULT NULL,
  `VerifiedBuild` smallint DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `broadcast_text_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `MaleText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `FemaleText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` smallint DEFAULT '0',
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `charstartoutfit_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `RaceID` tinyint unsigned NOT NULL DEFAULT '0',
  `ClassID` tinyint unsigned NOT NULL DEFAULT '0',
  `SexID` tinyint unsigned NOT NULL DEFAULT '0',
  `OutfitID` tinyint unsigned NOT NULL DEFAULT '0',
  `ItemID_1` int NOT NULL DEFAULT '0',
  `ItemID_2` int NOT NULL DEFAULT '0',
  `ItemID_3` int NOT NULL DEFAULT '0',
  `ItemID_4` int NOT NULL DEFAULT '0',
  `ItemID_5` int NOT NULL DEFAULT '0',
  `ItemID_6` int NOT NULL DEFAULT '0',
  `ItemID_7` int NOT NULL DEFAULT '0',
  `ItemID_8` int NOT NULL DEFAULT '0',
  `ItemID_9` int NOT NULL DEFAULT '0',
  `ItemID_10` int NOT NULL DEFAULT '0',
  `ItemID_11` int NOT NULL DEFAULT '0',
  `ItemID_12` int NOT NULL DEFAULT '0',
  `ItemID_13` int NOT NULL DEFAULT '0',
  `ItemID_14` int NOT NULL DEFAULT '0',
  `ItemID_15` int NOT NULL DEFAULT '0',
  `ItemID_16` int NOT NULL DEFAULT '0',
  `ItemID_17` int NOT NULL DEFAULT '0',
  `ItemID_18` int NOT NULL DEFAULT '0',
  `ItemID_19` int NOT NULL DEFAULT '0',
  `ItemID_20` int NOT NULL DEFAULT '0',
  `ItemID_21` int NOT NULL DEFAULT '0',
  `ItemID_22` int NOT NULL DEFAULT '0',
  `ItemID_23` int NOT NULL DEFAULT '0',
  `ItemID_24` int NOT NULL DEFAULT '0',
  `DisplayItemID_1` int NOT NULL DEFAULT '0',
  `DisplayItemID_2` int NOT NULL DEFAULT '0',
  `DisplayItemID_3` int NOT NULL DEFAULT '0',
  `DisplayItemID_4` int NOT NULL DEFAULT '0',
  `DisplayItemID_5` int NOT NULL DEFAULT '0',
  `DisplayItemID_6` int NOT NULL DEFAULT '0',
  `DisplayItemID_7` int NOT NULL DEFAULT '0',
  `DisplayItemID_8` int NOT NULL DEFAULT '0',
  `DisplayItemID_9` int NOT NULL DEFAULT '0',
  `DisplayItemID_10` int NOT NULL DEFAULT '0',
  `DisplayItemID_11` int NOT NULL DEFAULT '0',
  `DisplayItemID_12` int NOT NULL DEFAULT '0',
  `DisplayItemID_13` int NOT NULL DEFAULT '0',
  `DisplayItemID_14` int NOT NULL DEFAULT '0',
  `DisplayItemID_15` int NOT NULL DEFAULT '0',
  `DisplayItemID_16` int NOT NULL DEFAULT '0',
  `DisplayItemID_17` int NOT NULL DEFAULT '0',
  `DisplayItemID_18` int NOT NULL DEFAULT '0',
  `DisplayItemID_19` int NOT NULL DEFAULT '0',
  `DisplayItemID_20` int NOT NULL DEFAULT '0',
  `DisplayItemID_21` int NOT NULL DEFAULT '0',
  `DisplayItemID_22` int NOT NULL DEFAULT '0',
  `DisplayItemID_23` int NOT NULL DEFAULT '0',
  `DisplayItemID_24` int NOT NULL DEFAULT '0',
  `InventoryType_1` int NOT NULL DEFAULT '0',
  `InventoryType_2` int NOT NULL DEFAULT '0',
  `InventoryType_3` int NOT NULL DEFAULT '0',
  `InventoryType_4` int NOT NULL DEFAULT '0',
  `InventoryType_5` int NOT NULL DEFAULT '0',
  `InventoryType_6` int NOT NULL DEFAULT '0',
  `InventoryType_7` int NOT NULL DEFAULT '0',
  `InventoryType_8` int NOT NULL DEFAULT '0',
  `InventoryType_9` int NOT NULL DEFAULT '0',
  `InventoryType_10` int NOT NULL DEFAULT '0',
  `InventoryType_11` int NOT NULL DEFAULT '0',
  `InventoryType_12` int NOT NULL DEFAULT '0',
  `InventoryType_13` int NOT NULL DEFAULT '0',
  `InventoryType_14` int NOT NULL DEFAULT '0',
  `InventoryType_15` int NOT NULL DEFAULT '0',
  `InventoryType_16` int NOT NULL DEFAULT '0',
  `InventoryType_17` int NOT NULL DEFAULT '0',
  `InventoryType_18` int NOT NULL DEFAULT '0',
  `InventoryType_19` int NOT NULL DEFAULT '0',
  `InventoryType_20` int NOT NULL DEFAULT '0',
  `InventoryType_21` int NOT NULL DEFAULT '0',
  `InventoryType_22` int NOT NULL DEFAULT '0',
  `InventoryType_23` int NOT NULL DEFAULT '0',
  `InventoryType_24` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chartitles_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Condition_ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Name1_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name1_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Mask_ID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chatchannels_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `FactionGroup` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Shortcut_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Shortcut_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chrclasses_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Field01` int NOT NULL DEFAULT '0',
  `DisplayPower` int NOT NULL DEFAULT '0',
  `PetNameToken` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Name_Female_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Name_Male_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Filename` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SpellClassSet` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `CinematicSequenceID` int NOT NULL DEFAULT '0',
  `Required_Expansion` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `chrraces_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `FactionID` int NOT NULL DEFAULT '0',
  `ExplorationSoundID` int NOT NULL DEFAULT '0',
  `MaleDisplayId` int NOT NULL DEFAULT '0',
  `FemaleDisplayId` int NOT NULL DEFAULT '0',
  `ClientPrefix` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `BaseLanguage` int NOT NULL DEFAULT '0',
  `CreatureType` int NOT NULL DEFAULT '0',
  `ResSicknessSpellID` int NOT NULL DEFAULT '0',
  `SplashSoundID` int NOT NULL DEFAULT '0',
  `ClientFilestring` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `CinematicSequenceID` int NOT NULL DEFAULT '0',
  `Alliance` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Name_Female_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Female_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Name_Male_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Male_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `FacialHairCustomization_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `FacialHairCustomization_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `HairCustomization` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Required_Expansion` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `cinematiccamera_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `model` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `soundEntry` int NOT NULL DEFAULT '0',
  `locationX` float NOT NULL DEFAULT '0',
  `locationY` float NOT NULL DEFAULT '0',
  `locationZ` float NOT NULL DEFAULT '0',
  `rotation` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cinematic camera DBC';

CREATE TABLE IF NOT EXISTS `cinematicsequences_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `SoundID` int NOT NULL DEFAULT '0',
  `Camera_1` int NOT NULL DEFAULT '0',
  `Camera_2` int NOT NULL DEFAULT '0',
  `Camera_3` int NOT NULL DEFAULT '0',
  `Camera_4` int NOT NULL DEFAULT '0',
  `Camera_5` int NOT NULL DEFAULT '0',
  `Camera_6` int NOT NULL DEFAULT '0',
  `Camera_7` int NOT NULL DEFAULT '0',
  `Camera_8` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `command` (
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `security` tinyint unsigned NOT NULL DEFAULT '0',
  `help` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Chat System';

CREATE TABLE IF NOT EXISTS `conditions` (
  `SourceTypeOrReferenceId` int NOT NULL DEFAULT '0',
  `SourceGroup` int unsigned NOT NULL DEFAULT '0',
  `SourceEntry` int NOT NULL DEFAULT '0',
  `SourceId` int NOT NULL DEFAULT '0',
  `ElseGroup` int unsigned NOT NULL DEFAULT '0',
  `ConditionTypeOrReference` int NOT NULL DEFAULT '0',
  `ConditionTarget` tinyint unsigned NOT NULL DEFAULT '0',
  `ConditionValue1` int unsigned NOT NULL DEFAULT '0',
  `ConditionValue2` int unsigned NOT NULL DEFAULT '0',
  `ConditionValue3` int unsigned NOT NULL DEFAULT '0',
  `NegativeCondition` tinyint unsigned NOT NULL DEFAULT '0',
  `ErrorType` int unsigned NOT NULL DEFAULT '0',
  `ErrorTextId` int unsigned NOT NULL DEFAULT '0',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`SourceTypeOrReferenceId`,`SourceGroup`,`SourceEntry`,`SourceId`,`ElseGroup`,`ConditionTypeOrReference`,`ConditionTarget`,`ConditionValue1`,`ConditionValue2`,`ConditionValue3`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Condition System';

CREATE TABLE IF NOT EXISTS `creature` (
  `guid` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Global Unique Identifier',
  `id1` int unsigned NOT NULL DEFAULT '0' COMMENT 'Creature Identifier',
  `id2` int unsigned NOT NULL DEFAULT '0' COMMENT 'Creature Identifier',
  `id3` int unsigned NOT NULL DEFAULT '0' COMMENT 'Creature Identifier',
  `map` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map Identifier',
  `zoneId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Zone Identifier',
  `areaId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Area Identifier',
  `spawnMask` tinyint unsigned NOT NULL DEFAULT '1',
  `phaseMask` int unsigned NOT NULL DEFAULT '1',
  `equipment_id` tinyint NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `spawntimesecs` int unsigned NOT NULL DEFAULT '120',
  `wander_distance` float NOT NULL DEFAULT '0',
  `currentwaypoint` int unsigned NOT NULL DEFAULT '0',
  `curhealth` int unsigned NOT NULL DEFAULT '1',
  `curmana` int unsigned NOT NULL DEFAULT '0',
  `MovementType` tinyint unsigned NOT NULL DEFAULT '0',
  `npcflag` int unsigned NOT NULL DEFAULT '0',
  `unit_flags` int unsigned NOT NULL DEFAULT '0',
  `dynamicflags` int unsigned NOT NULL DEFAULT '0',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '',
  `VerifiedBuild` int DEFAULT NULL,
  `CreateObject` tinyint unsigned NOT NULL DEFAULT '0',
  `Comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`guid`),
  KEY `idx_map` (`map`),
  KEY `idx_id` (`id1`)
) ENGINE=InnoDB AUTO_INCREMENT=9000794 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature System';

CREATE TABLE IF NOT EXISTS `creature_addon` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `path_id` int unsigned NOT NULL DEFAULT '0',
  `mount` int unsigned NOT NULL DEFAULT '0',
  `bytes1` int unsigned NOT NULL DEFAULT '0',
  `bytes2` int unsigned NOT NULL DEFAULT '0',
  `emote` int unsigned NOT NULL DEFAULT '0',
  `visibilityDistanceType` tinyint unsigned NOT NULL DEFAULT '0',
  `auras` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_classlevelstats` (
  `level` tinyint unsigned NOT NULL,
  `class` tinyint unsigned NOT NULL,
  `basehp0` int unsigned NOT NULL DEFAULT '1',
  `basehp1` int unsigned NOT NULL DEFAULT '1',
  `basehp2` int unsigned NOT NULL DEFAULT '1',
  `basemana` int unsigned NOT NULL DEFAULT '0',
  `basearmor` int unsigned NOT NULL DEFAULT '1',
  `attackpower` int unsigned NOT NULL DEFAULT '0',
  `rangedattackpower` int unsigned NOT NULL DEFAULT '0',
  `damage_base` float NOT NULL DEFAULT '0',
  `damage_exp1` float NOT NULL DEFAULT '0',
  `damage_exp2` float NOT NULL DEFAULT '0',
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`level`,`class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_default_trainer` (
  `CreatureId` int unsigned NOT NULL,
  `TrainerId` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`CreatureId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `creature_equip_template` (
  `CreatureID` int unsigned NOT NULL DEFAULT '0',
  `ID` tinyint unsigned NOT NULL DEFAULT '1',
  `ItemID1` int unsigned NOT NULL DEFAULT '0',
  `ItemID2` int unsigned NOT NULL DEFAULT '0',
  `ItemID3` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`CreatureID`,`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_formations` (
  `leaderGUID` int unsigned NOT NULL DEFAULT '0',
  `memberGUID` int unsigned NOT NULL DEFAULT '0',
  `dist` float NOT NULL DEFAULT '0',
  `angle` float NOT NULL DEFAULT '0',
  `groupAI` int unsigned NOT NULL DEFAULT '0',
  `point_1` smallint unsigned NOT NULL DEFAULT '0',
  `point_2` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`memberGUID`),
  CONSTRAINT `creature_formations_chk_1` CHECK (((`dist` >= 0) and (`angle` >= 0)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`,`Reference`,`GroupId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `creature_model_info` (
  `DisplayID` int unsigned NOT NULL DEFAULT '0',
  `BoundingRadius` float NOT NULL DEFAULT '0',
  `CombatReach` float NOT NULL DEFAULT '0',
  `Gender` tinyint unsigned NOT NULL DEFAULT '2',
  `DisplayID_Other_Gender` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` mediumint DEFAULT NULL,
  PRIMARY KEY (`DisplayID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature System (Model related info)';

CREATE TABLE IF NOT EXISTS `creature_movement_override` (
  `SpawnId` int unsigned NOT NULL DEFAULT '0',
  `Ground` tinyint unsigned DEFAULT NULL,
  `Swim` tinyint unsigned DEFAULT NULL,
  `Flight` tinyint unsigned DEFAULT NULL,
  `Rooted` tinyint unsigned DEFAULT NULL,
  `Chase` tinyint unsigned DEFAULT NULL,
  `Random` tinyint unsigned DEFAULT NULL,
  `InteractionPauseTimer` int unsigned DEFAULT NULL COMMENT 'Time (in milliseconds) during which creature will not move after interaction with player',
  PRIMARY KEY (`SpawnId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_onkill_reputation` (
  `creature_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Creature Identifier',
  `RewOnKillRepFaction1` smallint NOT NULL DEFAULT '0',
  `RewOnKillRepFaction2` smallint NOT NULL DEFAULT '0',
  `MaxStanding1` tinyint NOT NULL DEFAULT '0',
  `IsTeamAward1` tinyint NOT NULL DEFAULT '0',
  `RewOnKillRepValue1` float NOT NULL DEFAULT '0',
  `MaxStanding2` tinyint NOT NULL DEFAULT '0',
  `IsTeamAward2` tinyint NOT NULL DEFAULT '0',
  `RewOnKillRepValue2` float NOT NULL DEFAULT '0',
  `TeamDependent` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`creature_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature OnKill Reputation gain';

CREATE TABLE IF NOT EXISTS `creature_questender` (
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`id`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature System';

CREATE TABLE IF NOT EXISTS `creature_questitem` (
  `CreatureEntry` int unsigned NOT NULL DEFAULT '0',
  `Idx` int unsigned NOT NULL DEFAULT '0',
  `ItemId` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`CreatureEntry`,`Idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_queststarter` (
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Identifier',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`id`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature System';

CREATE TABLE IF NOT EXISTS `creature_sparring` (
  `GUID` int unsigned NOT NULL,
  `SparringPCT` float NOT NULL,
  PRIMARY KEY (`GUID`),
  CONSTRAINT `creature_sparring_ibfk_1` FOREIGN KEY (`GUID`) REFERENCES `creature` (`guid`),
  CONSTRAINT `creature_sparring_chk_1` CHECK ((`SparringPCT` between 0 and 100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_summon_groups` (
  `summonerId` int unsigned NOT NULL DEFAULT '0',
  `summonerType` tinyint unsigned NOT NULL DEFAULT '0',
  `groupId` tinyint unsigned NOT NULL DEFAULT '0',
  `entry` int unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `summonType` tinyint unsigned NOT NULL DEFAULT '0',
  `summonTime` int unsigned NOT NULL DEFAULT '0',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_template` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `difficulty_entry_1` int unsigned NOT NULL DEFAULT '0',
  `difficulty_entry_2` int unsigned NOT NULL DEFAULT '0',
  `difficulty_entry_3` int unsigned NOT NULL DEFAULT '0',
  `KillCredit1` int unsigned NOT NULL DEFAULT '0',
  `KillCredit2` int unsigned NOT NULL DEFAULT '0',
  `name` char(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '0',
  `subname` char(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `IconName` char(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `gossip_menu_id` int unsigned NOT NULL DEFAULT '0',
  `minlevel` tinyint unsigned NOT NULL DEFAULT '1',
  `maxlevel` tinyint unsigned NOT NULL DEFAULT '1',
  `exp` smallint NOT NULL DEFAULT '0',
  `faction` smallint unsigned NOT NULL DEFAULT '0',
  `npcflag` int unsigned NOT NULL DEFAULT '0',
  `speed_walk` float NOT NULL DEFAULT '1' COMMENT 'Result of 2.5/2.5, most common value',
  `speed_run` float NOT NULL DEFAULT '1.14286' COMMENT 'Result of 8.0/7.0, most common value',
  `speed_swim` float NOT NULL DEFAULT '1',
  `speed_flight` float NOT NULL DEFAULT '1',
  `detection_range` float NOT NULL DEFAULT '20',
  `scale` float NOT NULL DEFAULT '1',
  `rank` tinyint unsigned NOT NULL DEFAULT '0',
  `dmgschool` tinyint NOT NULL DEFAULT '0',
  `DamageModifier` float NOT NULL DEFAULT '1',
  `BaseAttackTime` int unsigned NOT NULL DEFAULT '0',
  `RangeAttackTime` int unsigned NOT NULL DEFAULT '0',
  `BaseVariance` float NOT NULL DEFAULT '1',
  `RangeVariance` float NOT NULL DEFAULT '1',
  `unit_class` tinyint unsigned NOT NULL DEFAULT '0',
  `unit_flags` int unsigned NOT NULL DEFAULT '0',
  `unit_flags2` int unsigned NOT NULL DEFAULT '0',
  `dynamicflags` int unsigned NOT NULL DEFAULT '0',
  `family` tinyint NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `type_flags` int unsigned NOT NULL DEFAULT '0',
  `lootid` int unsigned NOT NULL DEFAULT '0',
  `pickpocketloot` int unsigned NOT NULL DEFAULT '0',
  `skinloot` int unsigned NOT NULL DEFAULT '0',
  `PetSpellDataId` int unsigned NOT NULL DEFAULT '0',
  `VehicleId` int unsigned NOT NULL DEFAULT '0',
  `mingold` int unsigned NOT NULL DEFAULT '0',
  `maxgold` int unsigned NOT NULL DEFAULT '0',
  `AIName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `MovementType` tinyint unsigned NOT NULL DEFAULT '0',
  `HoverHeight` float NOT NULL DEFAULT '1',
  `HealthModifier` float NOT NULL DEFAULT '1',
  `ManaModifier` float NOT NULL DEFAULT '1',
  `ArmorModifier` float NOT NULL DEFAULT '1',
  `ExperienceModifier` float NOT NULL DEFAULT '1',
  `RacialLeader` tinyint unsigned NOT NULL DEFAULT '0',
  `movementId` int unsigned NOT NULL DEFAULT '0',
  `RegenHealth` tinyint unsigned NOT NULL DEFAULT '1',
  `mechanic_immune_mask` int unsigned NOT NULL DEFAULT '0',
  `spell_school_immune_mask` int unsigned NOT NULL DEFAULT '0',
  `flags_extra` int unsigned NOT NULL DEFAULT '0',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature System';

CREATE TABLE IF NOT EXISTS `creature_template_addon` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `path_id` int unsigned NOT NULL DEFAULT '0',
  `mount` int unsigned NOT NULL DEFAULT '0',
  `bytes1` int unsigned NOT NULL DEFAULT '0',
  `bytes2` int unsigned NOT NULL DEFAULT '0',
  `emote` int unsigned NOT NULL DEFAULT '0',
  `visibilityDistanceType` tinyint unsigned NOT NULL DEFAULT '0',
  `auras` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_template_locale` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Title` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_template_model` (
  `CreatureID` int unsigned NOT NULL,
  `Idx` smallint unsigned NOT NULL DEFAULT '0',
  `CreatureDisplayID` int unsigned NOT NULL,
  `DisplayScale` float NOT NULL DEFAULT '1',
  `Probability` float NOT NULL DEFAULT '0',
  `VerifiedBuild` smallint unsigned DEFAULT NULL,
  PRIMARY KEY (`CreatureID`,`Idx`),
  CONSTRAINT `creature_template_model_chk_1` CHECK ((`Idx` <= 3))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `creature_template_movement` (
  `CreatureId` int unsigned NOT NULL DEFAULT '0',
  `Ground` tinyint unsigned DEFAULT NULL,
  `Swim` tinyint unsigned DEFAULT NULL,
  `Flight` tinyint unsigned DEFAULT NULL,
  `Rooted` tinyint unsigned DEFAULT NULL,
  `Chase` tinyint unsigned DEFAULT NULL,
  `Random` tinyint unsigned DEFAULT NULL,
  `InteractionPauseTimer` int unsigned DEFAULT NULL COMMENT 'Time (in milliseconds) during which creature will not move after interaction with player',
  PRIMARY KEY (`CreatureId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_template_outfits` (
  `entry` int unsigned NOT NULL,
  `race` tinyint unsigned NOT NULL DEFAULT '1',
  `gender` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0 for male, 1 for female',
  `skin` tinyint unsigned NOT NULL DEFAULT '0',
  `face` tinyint unsigned NOT NULL DEFAULT '0',
  `hair` tinyint unsigned NOT NULL DEFAULT '0',
  `haircolor` tinyint unsigned NOT NULL DEFAULT '0',
  `facialhair` tinyint unsigned NOT NULL DEFAULT '0',
  `head` int unsigned NOT NULL DEFAULT '0',
  `shoulders` int unsigned NOT NULL DEFAULT '0',
  `body` int unsigned NOT NULL DEFAULT '0',
  `chest` int unsigned NOT NULL DEFAULT '0',
  `waist` int unsigned NOT NULL DEFAULT '0',
  `legs` int unsigned NOT NULL DEFAULT '0',
  `feet` int unsigned NOT NULL DEFAULT '0',
  `wrists` int unsigned NOT NULL DEFAULT '0',
  `hands` int unsigned NOT NULL DEFAULT '0',
  `back` int unsigned NOT NULL DEFAULT '0',
  `tabard` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `creature_template_resistance` (
  `CreatureID` int unsigned NOT NULL,
  `School` tinyint unsigned NOT NULL,
  `Resistance` smallint DEFAULT NULL,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`CreatureID`,`School`),
  CONSTRAINT `creature_template_resistance_chk_1` CHECK (((`School` >= 1) and (`School` <= 6)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_template_spell` (
  `CreatureID` int unsigned NOT NULL,
  `Index` tinyint unsigned NOT NULL DEFAULT '0',
  `Spell` int unsigned DEFAULT NULL,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`CreatureID`,`Index`),
  CONSTRAINT `creature_template_spell_chk_1` CHECK (((`Index` >= 0) and (`Index` <= 7)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_text` (
  `CreatureID` int unsigned NOT NULL DEFAULT '0',
  `GroupID` tinyint unsigned NOT NULL DEFAULT '0',
  `ID` tinyint unsigned NOT NULL DEFAULT '0',
  `Text` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Type` tinyint unsigned NOT NULL DEFAULT '0',
  `Language` tinyint NOT NULL DEFAULT '0',
  `Probability` float NOT NULL DEFAULT '0',
  `Emote` int unsigned NOT NULL DEFAULT '0',
  `Duration` int unsigned NOT NULL DEFAULT '0',
  `Sound` int unsigned NOT NULL DEFAULT '0',
  `BroadcastTextId` int NOT NULL DEFAULT '0',
  `TextRange` tinyint unsigned NOT NULL DEFAULT '0',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '',
  PRIMARY KEY (`CreatureID`,`GroupID`,`ID`),
  CONSTRAINT `creature_text_chk_1` CHECK ((`Probability` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creature_text_locale` (
  `CreatureID` int unsigned NOT NULL DEFAULT '0',
  `GroupID` tinyint unsigned NOT NULL DEFAULT '0',
  `ID` tinyint unsigned NOT NULL DEFAULT '0',
  `Locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Text` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`CreatureID`,`GroupID`,`ID`,`Locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creaturedisplayinfo_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ModelID` int NOT NULL DEFAULT '0',
  `SoundID` int NOT NULL DEFAULT '0',
  `ExtendedDisplayInfoID` int NOT NULL DEFAULT '0',
  `CreatureModelScale` float NOT NULL DEFAULT '0',
  `CreatureModelAlpha` int NOT NULL DEFAULT '0',
  `TextureVariation_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `TextureVariation_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `TextureVariation_3` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `PortraitTextureName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `BloodLevel` int NOT NULL DEFAULT '0',
  `BloodID` int NOT NULL DEFAULT '0',
  `NPCSoundID` int NOT NULL DEFAULT '0',
  `ParticleColorID` int NOT NULL DEFAULT '0',
  `CreatureGeosetData` int NOT NULL DEFAULT '0',
  `ObjectEffectPackageID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creaturedisplayinfoextra_dbc` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `DisplayRaceID` int unsigned NOT NULL DEFAULT '0',
  `DisplaySexID` int unsigned NOT NULL DEFAULT '0',
  `SkinID` int unsigned NOT NULL DEFAULT '0',
  `FaceID` int unsigned NOT NULL DEFAULT '0',
  `HairStyleID` int unsigned NOT NULL DEFAULT '0',
  `HairColorID` int unsigned NOT NULL DEFAULT '0',
  `FacialHairID` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay1` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay2` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay3` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay4` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay5` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay6` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay7` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay8` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay9` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay10` int unsigned NOT NULL DEFAULT '0',
  `NPCItemDisplay11` int unsigned NOT NULL DEFAULT '0',
  `Flags` int unsigned NOT NULL DEFAULT '0',
  `BakeName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creaturefamily_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MinScale` float NOT NULL DEFAULT '0',
  `MinScaleLevel` int NOT NULL DEFAULT '0',
  `MaxScale` float NOT NULL DEFAULT '0',
  `MaxScaleLevel` int NOT NULL DEFAULT '0',
  `SkillLine_1` int NOT NULL DEFAULT '0',
  `SkillLine_2` int NOT NULL DEFAULT '0',
  `PetFoodMask` int NOT NULL DEFAULT '0',
  `PetTalentType` int NOT NULL DEFAULT '0',
  `CategoryEnumID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `IconFile` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creaturemodeldata_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `ModelName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SizeClass` int NOT NULL DEFAULT '0',
  `ModelScale` float NOT NULL DEFAULT '0',
  `BloodID` int NOT NULL DEFAULT '0',
  `FootprintTextureID` int NOT NULL DEFAULT '0',
  `FootprintTextureLength` float NOT NULL DEFAULT '0',
  `FootprintTextureWidth` float NOT NULL DEFAULT '0',
  `FootprintParticleScale` float NOT NULL DEFAULT '0',
  `FoleyMaterialID` int NOT NULL DEFAULT '0',
  `FootstepShakeSize` int NOT NULL DEFAULT '0',
  `DeathThudShakeSize` int NOT NULL DEFAULT '0',
  `SoundID` int NOT NULL DEFAULT '0',
  `CollisionWidth` float NOT NULL DEFAULT '0',
  `CollisionHeight` float NOT NULL DEFAULT '0',
  `MountHeight` float NOT NULL DEFAULT '0',
  `GeoBoxMinX` float NOT NULL DEFAULT '0',
  `GeoBoxMinY` float NOT NULL DEFAULT '0',
  `GeoBoxMinZ` float NOT NULL DEFAULT '0',
  `GeoBoxMaxX` float NOT NULL DEFAULT '0',
  `GeoBoxMaxY` float NOT NULL DEFAULT '0',
  `GeoBoxMaxZ` float NOT NULL DEFAULT '0',
  `WorldEffectScale` float NOT NULL DEFAULT '0',
  `AttachedEffectScale` float NOT NULL DEFAULT '0',
  `MissileCollisionRadius` float NOT NULL DEFAULT '0',
  `MissileCollisionPush` float NOT NULL DEFAULT '0',
  `MissileCollisionRaise` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creaturespelldata_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Spells_1` int NOT NULL DEFAULT '0',
  `Spells_2` int NOT NULL DEFAULT '0',
  `Spells_3` int NOT NULL DEFAULT '0',
  `Spells_4` int NOT NULL DEFAULT '0',
  `Availability_1` int NOT NULL DEFAULT '0',
  `Availability_2` int NOT NULL DEFAULT '0',
  `Availability_3` int NOT NULL DEFAULT '0',
  `Availability_4` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `creaturetype_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `currencytypes_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ItemID` int NOT NULL DEFAULT '0',
  `CategoryID` int NOT NULL DEFAULT '0',
  `BitIndex` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_aoeloot_blacklist` (
  `item_id` int unsigned NOT NULL,
  `reason` varchar(100) NOT NULL DEFAULT 'Blacklisted',
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Item Blacklist';

CREATE TABLE IF NOT EXISTS `dc_aoeloot_config` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `config_key` varchar(64) NOT NULL,
  `config_value` varchar(255) NOT NULL,
  `description` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_key` (`config_key`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Global Configuration';

CREATE TABLE IF NOT EXISTS `dc_aoeloot_smart_categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `category_name` varchar(64) NOT NULL,
  `stat_primary` varchar(32) NOT NULL COMMENT 'e.g., INTELLECT, STRENGTH, AGILITY',
  `stat_secondary` varchar(64) DEFAULT NULL COMMENT 'Comma-separated secondary stats',
  `class_mask` int unsigned NOT NULL DEFAULT '0' COMMENT 'Class bitmask, 0 = all',
  `spec_id` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0 = any spec',
  PRIMARY KEY (`id`),
  KEY `idx_class` (`class_mask`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Smart Loot Categories';

CREATE TABLE IF NOT EXISTS `dc_aoeloot_zone_modifiers` (
  `zone_id` int unsigned NOT NULL,
  `zone_name` varchar(64) NOT NULL,
  `gold_multiplier` float NOT NULL DEFAULT '1',
  `item_quality_bonus` tinyint NOT NULL DEFAULT '0' COMMENT 'Added to quality roll',
  `mythic_bonus_multiplier` float NOT NULL DEFAULT '1',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos AoE Loot - Zone Modifiers';

CREATE TABLE IF NOT EXISTS `dc_chaos_artifact_items` (
  `item_id` int unsigned NOT NULL,
  `artifact_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `artifact_rarity` enum('common','uncommon','rare','epic','legendary') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'rare',
  `power_level` tinyint unsigned DEFAULT '1',
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`item_id`),
  KEY `idx_rarity` (`artifact_rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_collection_achievement_defs` (
  `achievement_id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` text,
  `collection_type` enum('mount','pet','toy','transmog','title','heirloom','total') NOT NULL,
  `required_count` int unsigned NOT NULL,
  `reward_type` enum('title','mount','pet','item','currency','spell') DEFAULT NULL,
  `reward_id` int unsigned DEFAULT NULL,
  `reward_tokens` int unsigned NOT NULL DEFAULT '0',
  `reward_emblems` int unsigned NOT NULL DEFAULT '0',
  `icon` varchar(255) DEFAULT NULL,
  `points` int unsigned NOT NULL DEFAULT '10',
  `sort_order` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`achievement_id`),
  KEY `idx_type` (`collection_type`),
  KEY `idx_count` (`required_count`)
) ENGINE=InnoDB AUTO_INCREMENT=56 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Collection achievement definitions';

CREATE TABLE IF NOT EXISTS `dc_collection_definitions` (
  `collection_type` tinyint unsigned NOT NULL COMMENT '1=mount,2=pet,3=toy,4=heirloom,5=title,6=transmog',
  `entry_id` int unsigned NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`collection_type`,`entry_id`),
  KEY `idx_enabled` (`collection_type`,`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Generic collection definition index';

CREATE TABLE IF NOT EXISTS `dc_collection_shop` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `collection_type` tinyint unsigned NOT NULL COMMENT '1..6 (see dc_collection_items.collection_type)',
  `entry_id` int unsigned NOT NULL,
  `price_tokens` int unsigned NOT NULL DEFAULT '0',
  `price_emblems` int unsigned NOT NULL DEFAULT '0',
  `discount_percent` tinyint unsigned NOT NULL DEFAULT '0',
  `available_from` datetime DEFAULT NULL,
  `available_until` datetime DEFAULT NULL,
  `stock_remaining` int DEFAULT NULL COMMENT 'NULL or <0 for unlimited',
  `featured` tinyint(1) NOT NULL DEFAULT '0',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `idx_enabled_time` (`enabled`,`available_from`,`available_until`),
  KEY `idx_type` (`collection_type`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Collection shop (generic)';

CREATE TABLE IF NOT EXISTS `dc_daily_quest_token_rewards` (
  `quest_id` int unsigned NOT NULL COMMENT 'Daily quest ID (700101-700104)',
  `token_item_id` int unsigned NOT NULL COMMENT 'Token item ID to award',
  `token_count` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Number of tokens awarded',
  `bonus_multiplier` float NOT NULL DEFAULT '1' COMMENT 'Multiplier for bonus tokens (difficulty-based)',
  `created_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`quest_id`),
  KEY `token_idx` (`token_item_id`),
  CONSTRAINT `dc_daily_quest_token_rewards_ibfk_1` FOREIGN KEY (`token_item_id`) REFERENCES `dc_quest_reward_tokens` (`token_item_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily dungeon quest token rewards - triggers on QUEST_REWARDED status';

CREATE TABLE IF NOT EXISTS `dc_difficulty_config` (
  `difficulty_id` int unsigned NOT NULL AUTO_INCREMENT,
  `difficulty_name` enum('Normal','Heroic','Mythic','Mythic+') NOT NULL,
  `display_name` varchar(50) NOT NULL COMMENT 'Display name for players',
  `min_level` tinyint unsigned NOT NULL DEFAULT '1',
  `token_multiplier` decimal(4,2) NOT NULL DEFAULT '1.00' COMMENT 'Token reward multiplier',
  `gold_multiplier` decimal(4,2) NOT NULL DEFAULT '1.00' COMMENT 'Gold reward multiplier',
  `xp_multiplier` decimal(4,2) NOT NULL DEFAULT '1.00' COMMENT 'XP reward multiplier',
  `min_group_size` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Minimum players required',
  `max_group_size` tinyint unsigned NOT NULL DEFAULT '5' COMMENT 'Maximum group size',
  `time_limit_minutes` smallint unsigned NOT NULL DEFAULT '0' COMMENT '0 = no limit',
  `deaths_allowed` tinyint unsigned NOT NULL DEFAULT '255' COMMENT '255 = unlimited',
  `enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT '1=active, 0=disabled',
  `sort_order` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`difficulty_id`),
  UNIQUE KEY `difficulty_name` (`difficulty_name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='v4.0 - Difficulty tier configuration';

CREATE TABLE IF NOT EXISTS `dc_duel_tournament_npcs` (
  `entry` int unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `subname` varchar(100) DEFAULT 'Tournament Master',
  `tournament_type` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=Standard, 1=1v1, 2=Class-only',
  `min_level` tinyint unsigned NOT NULL DEFAULT '80',
  `entry_fee` int unsigned NOT NULL DEFAULT '0' COMMENT 'In copper',
  `reward_item` int unsigned NOT NULL DEFAULT '0',
  `reward_count` int unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos Phased Dueling - Tournament NPCs';

CREATE TABLE IF NOT EXISTS `dc_duel_zones` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `zone_id` int unsigned NOT NULL,
  `area_id` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(64) NOT NULL,
  `description` text,
  `min_level` tinyint unsigned NOT NULL DEFAULT '1',
  `max_level` tinyint unsigned NOT NULL DEFAULT '255',
  `allowed_classes` int unsigned NOT NULL DEFAULT '0' COMMENT 'Bitmask, 0 = all classes',
  `phase_id_start` int unsigned NOT NULL DEFAULT '100000' COMMENT 'Starting phase ID for this zone',
  `phase_id_end` int unsigned NOT NULL DEFAULT '199999' COMMENT 'Ending phase ID for this zone',
  `rewards_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `honor_multiplier` float NOT NULL DEFAULT '1',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_zone_area` (`zone_id`,`area_id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos Phased Dueling - Zone Configuration';

CREATE TABLE IF NOT EXISTS `dc_dungeon_entrances` (
  `dungeon_map` smallint unsigned NOT NULL COMMENT 'Dungeon map ID (same as in dc_dungeon_mythic_profile)',
  `entrance_map` int unsigned NOT NULL COMMENT 'Map where the entrance is located',
  `entrance_x` float NOT NULL COMMENT 'X coordinate of entrance',
  `entrance_y` float NOT NULL COMMENT 'Y coordinate of entrance',
  `entrance_z` float NOT NULL COMMENT 'Z coordinate of entrance',
  `entrance_o` float NOT NULL COMMENT 'Orientation at entrance',
  PRIMARY KEY (`dungeon_map`),
  CONSTRAINT `dc_dungeon_entrances_ibfk_1` FOREIGN KEY (`dungeon_map`) REFERENCES `dc_dungeon_mythic_profile` (`map_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Dungeon entrance coordinates for portal teleportation';

CREATE TABLE IF NOT EXISTS `dc_dungeon_mythic_profile` (
  `map_id` smallint unsigned NOT NULL COMMENT 'Map ID from Map.dbc',
  `name` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Dungeon display name',
  `heroic_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Enable Heroic difficulty (difficulty 2)',
  `mythic_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Enable Mythic difficulty (difficulty 3)',
  `base_health_mult` float NOT NULL DEFAULT '1.25' COMMENT 'Mythic HP multiplier (1.25 = +25%)',
  `base_damage_mult` float NOT NULL DEFAULT '1.15' COMMENT 'Mythic damage multiplier (1.15 = +15%)',
  `heroic_level_normal` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Heroic normal mob level (0 = keep original)',
  `heroic_level_elite` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Heroic elite mob level (0 = keep original)',
  `heroic_level_boss` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Heroic boss level (0 = keep original)',
  `mythic_level_normal` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Mythic normal mob level (0 = keep original)',
  `mythic_level_elite` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Mythic elite mob level (0 = keep original)',
  `mythic_level_boss` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Mythic boss level (0 = keep original)',
  `death_budget` tinyint unsigned NOT NULL DEFAULT '10' COMMENT 'Max deaths allowed in Mythic',
  `wipe_budget` tinyint unsigned NOT NULL DEFAULT '3' COMMENT 'Max wipes allowed in Mythic',
  `loot_ilvl` int unsigned NOT NULL DEFAULT '219' COMMENT 'Base item level for Mythic loot',
  `token_reward` int unsigned NOT NULL DEFAULT '101000' COMMENT 'Mythic token item ID',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`map_id`),
  KEY `idx_enabled` (`mythic_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mythic difficulty profiles for dungeons';

CREATE TABLE IF NOT EXISTS `dc_dungeon_npc_mapping` (
  `map_id` int unsigned NOT NULL COMMENT 'Dungeon map ID from Map.dbc',
  `quest_master_entry` int unsigned NOT NULL COMMENT 'Quest master NPC creature entry (700000-700052)',
  `dungeon_name` varchar(100) NOT NULL COMMENT 'Human-readable dungeon name',
  `expansion` tinyint unsigned DEFAULT '0' COMMENT '0=Classic, 1=TBC, 2=WotLK, 3=Cata',
  `min_level` tinyint unsigned DEFAULT '1' COMMENT 'Recommended minimum level',
  `max_level` tinyint unsigned DEFAULT '80' COMMENT 'Recommended maximum level',
  `enabled` tinyint(1) DEFAULT '1' COMMENT 'Is this dungeon quest system enabled?',
  PRIMARY KEY (`map_id`,`quest_master_entry`),
  KEY `idx_quest_master` (`quest_master_entry`),
  KEY `idx_expansion` (`expansion`,`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='v4.0 - Maps dungeon map IDs to quest master NPCs';

CREATE TABLE IF NOT EXISTS `dc_dungeon_setup` (
  `map_id` smallint unsigned NOT NULL COMMENT 'Dungeon map ID',
  `dungeon_name` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Display name',
  `expansion` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Expansion identifier (0=Vanilla, 1=TBC, 2=WotLK, ...)',
  `is_unlocked` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Global unlock gate',
  `normal_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Allow Normal queue/teleport',
  `heroic_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Allow Heroic difficulty',
  `heroic_scaling_mode` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=Profile default, 1=Custom scaling, 2=No scaling overrides',
  `mythic_enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Allow Mythic (non keystone)',
  `mythic_plus_enabled` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Allow Mythic+ keystones',
  `season_lock` int unsigned DEFAULT NULL COMMENT 'Optional season requirement (NULL = always)',
  `notes` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional admin notes',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`map_id`),
  KEY `season_lock` (`season_lock`),
  CONSTRAINT `dc_dungeon_setup_ibfk_1` FOREIGN KEY (`map_id`) REFERENCES `dc_dungeon_mythic_profile` (`map_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Unified dungeon availability toggles for Normal/Heroic/Mythic/Mythic+';

CREATE TABLE IF NOT EXISTS `dc_guild_house_locations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `map` int unsigned NOT NULL,
  `posX` float NOT NULL,
  `posY` float NOT NULL,
  `posZ` float NOT NULL,
  `orientation` float NOT NULL,
  `cost` int unsigned NOT NULL DEFAULT '10000000',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `required_achievement` int unsigned DEFAULT '0',
  `comment` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_guild_house_spawns` (
  `id` int NOT NULL AUTO_INCREMENT,
  `map` int NOT NULL DEFAULT '1',
  `entry` int NOT NULL DEFAULT '0',
  `posX` float NOT NULL DEFAULT '0',
  `posY` float NOT NULL DEFAULT '0',
  `posZ` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `comment` varchar(500) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `map_entry` (`map`,`entry`)
) ENGINE=InnoDB AUTO_INCREMENT=106 DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `dc_heirloom_definitions` (
  `item_id` int unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `slot` tinyint unsigned NOT NULL COMMENT 'Equipment slot',
  `armor_type` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=misc, 1=cloth, 2=leather, 3=mail, 4=plate',
  `max_upgrade_level` tinyint unsigned NOT NULL DEFAULT '3',
  `scaling_type` tinyint unsigned NOT NULL DEFAULT '0',
  `icon` varchar(255) DEFAULT '',
  `source` text,
  PRIMARY KEY (`item_id`),
  KEY `idx_slot` (`slot`),
  KEY `idx_armor_type` (`armor_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Heirloom definitions';

CREATE TABLE IF NOT EXISTS `dc_heirloom_enchant_mapping` (
  `package_id` tinyint unsigned NOT NULL,
  `level` tinyint unsigned NOT NULL,
  `enchant_id` int unsigned NOT NULL COMMENT 'SpellItemEnchantment.dbc ID',
  `stat_1_value` int unsigned NOT NULL,
  `stat_2_value` int unsigned NOT NULL,
  `stat_3_value` int unsigned DEFAULT NULL,
  `display_text` varchar(128) NOT NULL COMMENT 'Tooltip text',
  PRIMARY KEY (`package_id`,`level`),
  KEY `idx_enchant` (`enchant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Mapping between packages and DBC enchant IDs';

CREATE TABLE IF NOT EXISTS `dc_heirloom_package_levels` (
  `level` tinyint unsigned NOT NULL,
  `base_stat_value` int unsigned NOT NULL COMMENT 'Base stat value at this level (before weight)',
  `essence_cost` int unsigned NOT NULL COMMENT 'Essence cost to upgrade TO this level',
  `total_essence` int unsigned NOT NULL COMMENT 'Total essence invested at this level',
  `stat_multiplier` float NOT NULL COMMENT 'Display multiplier for progression feel',
  `milestone_name` varchar(32) DEFAULT NULL COMMENT 'Special name for milestone levels',
  PRIMARY KEY (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Stat values and costs per upgrade level';

CREATE TABLE IF NOT EXISTS `dc_heirloom_stat_packages` (
  `package_id` tinyint unsigned NOT NULL,
  `package_name` varchar(32) NOT NULL,
  `package_icon` varchar(64) NOT NULL DEFAULT 'Interface\\Icons\\INV_Misc_QuestionMark' COMMENT 'Icon path for addon',
  `description` varchar(255) NOT NULL,
  `stat_type_1` tinyint unsigned NOT NULL COMMENT 'Primary stat type (ItemModType)',
  `stat_type_2` tinyint unsigned NOT NULL COMMENT 'Secondary stat type (ItemModType)',
  `stat_type_3` tinyint unsigned DEFAULT NULL COMMENT 'Tertiary stat type (optional)',
  `stat_weight_1` float NOT NULL DEFAULT '1' COMMENT 'Weight multiplier for stat 1',
  `stat_weight_2` float NOT NULL DEFAULT '1' COMMENT 'Weight multiplier for stat 2',
  `stat_weight_3` float NOT NULL DEFAULT '0.5' COMMENT 'Weight multiplier for stat 3 (if exists)',
  `color_r` tinyint unsigned DEFAULT '255' COMMENT 'Package color red component',
  `color_g` tinyint unsigned DEFAULT '255' COMMENT 'Package color green component',
  `color_b` tinyint unsigned DEFAULT '255' COMMENT 'Package color blue component',
  `recommended_classes` varchar(128) DEFAULT NULL COMMENT 'Recommended class names',
  `recommended_specs` varchar(128) DEFAULT NULL COMMENT 'Recommended spec names',
  `sort_order` tinyint unsigned DEFAULT '0' COMMENT 'Display order in addon',
  `is_enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`package_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Heirloom secondary stat package definitions';

CREATE TABLE IF NOT EXISTS `dc_heirloom_upgrade_costs` (
  `upgrade_level` tinyint unsigned NOT NULL COMMENT 'Target upgrade level (1-15)',
  `token_cost` int unsigned NOT NULL DEFAULT '0' COMMENT 'Upgrade Tokens required',
  `essence_cost` int unsigned NOT NULL DEFAULT '0' COMMENT 'Upgrade Essence required',
  `description` varchar(64) DEFAULT NULL COMMENT 'Level description',
  PRIMARY KEY (`upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Costs for heirloom stat package upgrades';

CREATE TABLE IF NOT EXISTS `dc_hlbg_seasons` (
  `season` smallint unsigned NOT NULL COMMENT 'Season number',
  `name` varchar(64) NOT NULL DEFAULT 'Season' COMMENT 'Display name',
  `start_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Season start',
  `end_date` datetime DEFAULT NULL COMMENT 'Season end (NULL = ongoing)',
  `is_active` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = current active season',
  `description` text COMMENT 'Season description',
  PRIMARY KEY (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='HLBG Season configuration';

CREATE TABLE IF NOT EXISTS `dc_hotspots_active` (
  `id` int unsigned NOT NULL COMMENT 'Unique hotspot ID',
  `map_id` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map ID where hotspot is located',
  `zone_id` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Zone ID where hotspot is located',
  `x` float NOT NULL DEFAULT '0' COMMENT 'X coordinate',
  `y` float NOT NULL DEFAULT '0' COMMENT 'Y coordinate',
  `z` float NOT NULL DEFAULT '0' COMMENT 'Z coordinate',
  `spawn_time` bigint NOT NULL DEFAULT '0' COMMENT 'Unix timestamp when hotspot was spawned',
  `expire_time` bigint NOT NULL DEFAULT '0' COMMENT 'Unix timestamp when hotspot expires',
  `gameobject_guid` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'GUID of visual marker GameObject (0 if none)',
  PRIMARY KEY (`id`),
  KEY `idx_expire_time` (`expire_time`),
  KEY `idx_map_zone` (`map_id`,`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos Hotspots - Active hotspots for crash persistence';

CREATE TABLE IF NOT EXISTS `dc_item_custom_data` (
  `item_id` int unsigned NOT NULL COMMENT 'Item entry ID',
  `custom_note` text COLLATE utf8mb4_unicode_ci COMMENT 'Custom text to show in tooltip',
  `custom_source` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Custom source text (e.g. "World Boss Drop")',
  `is_custom` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Flag for custom items',
  PRIMARY KEY (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Custom item metadata for QoS tooltips';

CREATE TABLE IF NOT EXISTS `dc_item_proc_spells` (
  `spell_id` int unsigned NOT NULL,
  `item_entry` int unsigned NOT NULL DEFAULT '0',
  `proc_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `proc_type` enum('damage','healing','buff','debuff') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'damage',
  `scales_with_upgrade` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`spell_id`),
  KEY `idx_proc_type` (`proc_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_item_templates_upgrade` (
  `item_id` int unsigned NOT NULL,
  `tier_id` tinyint unsigned DEFAULT '1',
  `armor_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'misc',
  `item_slot` tinyint unsigned DEFAULT '0',
  `rarity` tinyint unsigned DEFAULT '0',
  `source_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'import',
  `source_id` int unsigned DEFAULT '0',
  `base_stat_value` smallint unsigned DEFAULT '0',
  `cosmetic_variant` tinyint unsigned DEFAULT '0',
  `is_active` tinyint(1) DEFAULT '1',
  `upgrade_category` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'common',
  `season` tinyint unsigned DEFAULT '1',
  PRIMARY KEY (`item_id`),
  KEY `idx_tier_season` (`tier_id`,`season`),
  KEY `idx_armor_type` (`armor_type`),
  KEY `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item Upgrade Template Mappings v2.0';

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_clones` (
  `base_item_id` int unsigned NOT NULL,
  `tier_id` tinyint unsigned NOT NULL,
  `upgrade_level` tinyint unsigned NOT NULL,
  `clone_item_id` int unsigned NOT NULL,
  `stat_multiplier` float NOT NULL,
  PRIMARY KEY (`base_item_id`,`upgrade_level`),
  UNIQUE KEY `idx_clone_item` (`clone_item_id`),
  KEY `idx_tier_level` (`tier_id`,`upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Generated item clone mapping';

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_costs` (
  `tier_id` tinyint unsigned NOT NULL,
  `upgrade_level` tinyint unsigned NOT NULL,
  `token_cost` int unsigned NOT NULL,
  `essence_cost` int unsigned NOT NULL,
  `ilvl_increase` smallint unsigned DEFAULT '0',
  `stat_increase_percent` float DEFAULT '0',
  `season` int unsigned NOT NULL DEFAULT '1',
  `gold_cost` int unsigned DEFAULT '0',
  PRIMARY KEY (`tier_id`,`upgrade_level`,`season`),
  UNIQUE KEY `idx_tier_level` (`tier_id`,`upgrade_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_inputs` (
  `input_id` int unsigned NOT NULL AUTO_INCREMENT,
  `recipe_id` int unsigned NOT NULL,
  `item_id` int unsigned NOT NULL,
  `quantity` int unsigned NOT NULL DEFAULT '1',
  `required_tier` tinyint unsigned NOT NULL DEFAULT '0',
  `required_upgrade_level` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`input_id`),
  KEY `idx_recipe_id` (`recipe_id`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Required input items per synthesis recipe';

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_synthesis_recipes` (
  `recipe_id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `required_level` int unsigned DEFAULT '0',
  `input_essence` int unsigned DEFAULT '0',
  `input_tokens` int unsigned DEFAULT '0',
  `output_item_id` int unsigned NOT NULL,
  `output_quantity` int unsigned DEFAULT '1',
  `success_rate_base` decimal(5,2) DEFAULT '100.00' COMMENT 'Base success rate as percentage (0-100)',
  `cooldown_seconds` int unsigned DEFAULT '0',
  `required_tier` tinyint unsigned DEFAULT '0',
  `required_upgrade_level` tinyint unsigned DEFAULT '0',
  `catalyst_item_id` int unsigned DEFAULT '0',
  `catalyst_quantity` int unsigned DEFAULT '0',
  `active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`recipe_id`),
  KEY `idx_active` (`active`),
  KEY `idx_required_level` (`required_level`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Synthesis recipes for combining items/materials into new items';

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_tier_items` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tier_id` int unsigned NOT NULL,
  `item_entry` int unsigned NOT NULL,
  `slot_type` tinyint unsigned DEFAULT NULL COMMENT 'Equipment slot',
  `item_class` tinyint unsigned DEFAULT NULL,
  `item_subclass` tinyint unsigned DEFAULT NULL,
  `required_level` tinyint unsigned DEFAULT NULL,
  `base_ilvl` smallint unsigned DEFAULT NULL,
  `max_upgrade_level` tinyint unsigned NOT NULL DEFAULT '15',
  `upgrade_cost_multiplier` float NOT NULL DEFAULT '1',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `notes` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_tier_item` (`tier_id`,`item_entry`),
  KEY `idx_item_entry` (`item_entry`),
  KEY `idx_tier_id` (`tier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Items that can be upgraded per tier';

CREATE TABLE IF NOT EXISTS `dc_item_upgrade_tiers` (
  `tier_id` tinyint unsigned NOT NULL,
  `tier_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `min_ilvl` smallint unsigned DEFAULT '0',
  `max_ilvl` smallint unsigned DEFAULT '0',
  `max_upgrade_level` tinyint unsigned NOT NULL DEFAULT '15',
  `stat_multiplier_max` float NOT NULL DEFAULT '1.5',
  `upgrade_cost_per_level` int unsigned NOT NULL DEFAULT '100',
  `source_content` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_artifact` tinyint(1) NOT NULL DEFAULT '0',
  `season` tinyint unsigned NOT NULL DEFAULT '1',
  `is_active` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`tier_id`,`season`),
  KEY `idx_season` (`season`),
  KEY `idx_active_tiers` (`season`,`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tier definitions for item upgrade system';

CREATE TABLE IF NOT EXISTS `dc_mount_definitions` (
  `spell_id` int unsigned NOT NULL COMMENT 'Mount spell ID',
  `name` varchar(100) NOT NULL COMMENT 'Mount name',
  `mount_type` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=ground, 1=flying, 2=aquatic, 3=all',
  `source` text COMMENT 'JSON source info',
  `faction` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=both, 1=alliance, 2=horde',
  `class_mask` int unsigned NOT NULL DEFAULT '0' COMMENT '0=all, else class bitmask',
  `display_id` int unsigned NOT NULL DEFAULT '0',
  `icon` varchar(255) DEFAULT '' COMMENT 'Icon path override',
  `rarity` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0=common, 1=uncommon, 2=rare, 3=epic, 4=legendary',
  `speed` smallint unsigned NOT NULL DEFAULT '100' COMMENT 'Speed percentage',
  `expansion` tinyint unsigned NOT NULL DEFAULT '2' COMMENT '0=vanilla, 1=tbc, 2=wotlk',
  `is_tradeable` tinyint(1) NOT NULL DEFAULT '0',
  `profession_required` tinyint unsigned DEFAULT NULL,
  `skill_required` smallint unsigned DEFAULT NULL,
  `flags` int unsigned NOT NULL DEFAULT '0' COMMENT 'Custom flags',
  PRIMARY KEY (`spell_id`),
  KEY `idx_mount_type` (`mount_type`),
  KEY `idx_rarity` (`rarity`),
  KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Mount definitions';

CREATE TABLE IF NOT EXISTS `dc_mplus_affix_pairs` (
  `pair_id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique affix pair identifier',
  `name` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Pair display name (e.g., "Tyrannical + Bolstering")',
  `boss_affix_id` int unsigned NOT NULL COMMENT 'Boss-focused affix spell ID',
  `trash_affix_id` int unsigned NOT NULL COMMENT 'Trash-focused affix spell ID',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Player-facing description of combined effects',
  PRIMARY KEY (`pair_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Affix pair definitions for weekly rotation';

CREATE TABLE IF NOT EXISTS `dc_mplus_affix_schedule` (
  `season_id` int unsigned NOT NULL COMMENT 'Season from dc_mplus_seasons',
  `week_number` tinyint unsigned NOT NULL COMMENT 'Week of the season (0-51)',
  `affix1` tinyint unsigned NOT NULL COMMENT 'First affix ID (boss-focused)',
  `affix2` tinyint unsigned NOT NULL COMMENT 'Second affix ID (trash-focused)',
  PRIMARY KEY (`season_id`,`week_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly affix rotation schedule for Mythic+ seasons';

CREATE TABLE IF NOT EXISTS `dc_mplus_affixes` (
  `affix_id` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique affix identifier',
  `name` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Affix name (e.g., "Tyrannical-Lite")',
  `type` enum('boss','trash') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Target type: boss or trash',
  `spell_id` int unsigned NOT NULL COMMENT 'Spell ID to apply',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Player-facing description',
  `enabled` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Enable/disable affix',
  PRIMARY KEY (`affix_id`),
  KEY `idx_type` (`type`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Individual affix definitions';

CREATE TABLE IF NOT EXISTS `dc_mplus_dungeons` (
  `dungeon_id` int unsigned NOT NULL COMMENT 'Map ID',
  `dungeon_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `short_name` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Abbreviation like UK, AN, etc.',
  `min_level` tinyint unsigned NOT NULL DEFAULT '80',
  `base_timer` int unsigned NOT NULL DEFAULT '1800' COMMENT 'Base completion timer in seconds',
  `trash_count` int unsigned NOT NULL DEFAULT '0' COMMENT 'Required trash kills for completion',
  `boss_count` tinyint unsigned NOT NULL DEFAULT '0',
  `difficulty_rating` tinyint unsigned NOT NULL DEFAULT '5' COMMENT '1-10 difficulty scale',
  `season_enabled` tinyint(1) NOT NULL DEFAULT '1',
  `teleport_x` float DEFAULT NULL,
  `teleport_y` float DEFAULT NULL,
  `teleport_z` float DEFAULT NULL,
  `teleport_o` float DEFAULT NULL,
  `icon_path` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`dungeon_id`),
  KEY `idx_season_enabled` (`season_enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mythic+ dungeon definitions';

CREATE TABLE IF NOT EXISTS `dc_mplus_featured_dungeons` (
  `season_id` int unsigned NOT NULL COMMENT 'Season from dc_mplus_seasons',
  `map_id` smallint unsigned NOT NULL COMMENT 'Dungeon map ID',
  `sort_order` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Display order in UI',
  `dungeon_name` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Display name for UI/GM tools',
  `notes` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional comments (e.g., rotation theme)',
  PRIMARY KEY (`season_id`,`map_id`),
  KEY `map_id` (`map_id`),
  CONSTRAINT `dc_mplus_featured_dungeons_ibfk_1` FOREIGN KEY (`season_id`) REFERENCES `dc_mplus_seasons_archived_20251122` (`season_id`) ON DELETE CASCADE,
  CONSTRAINT `dc_mplus_featured_dungeons_ibfk_2` FOREIGN KEY (`map_id`) REFERENCES `dc_dungeon_mythic_profile` (`map_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Featured dungeons per season for Mythic+ rotation';

CREATE TABLE IF NOT EXISTS `dc_mplus_scale_multipliers` (
  `keystoneLevel` int unsigned NOT NULL COMMENT 'Keystone difficulty level (0-30+)',
  `hpMultiplier` float NOT NULL DEFAULT '1' COMMENT 'Health multiplier for creatures',
  `damageMultiplier` float NOT NULL DEFAULT '1' COMMENT 'Damage multiplier for creatures',
  `description` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Label for this difficulty (e.g. "M+2", "M+10")',
  PRIMARY KEY (`keystoneLevel`),
  KEY `idx_keystoneLevel` (`keystoneLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature scaling multipliers for each Mythic+ keystone level';

CREATE TABLE IF NOT EXISTS `dc_mplus_seasons` (
  `season` smallint unsigned NOT NULL COMMENT 'Season number',
  `name` varchar(64) NOT NULL DEFAULT 'Season' COMMENT 'Display name',
  `start_date` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Season start',
  `end_date` datetime DEFAULT NULL COMMENT 'Season end (NULL = ongoing)',
  `is_active` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '1 = current active season',
  `description` text COMMENT 'Season description',
  PRIMARY KEY (`season`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='M+ Season configuration';

CREATE TABLE IF NOT EXISTS `dc_mplus_spec_npcs` (
  `entry` int unsigned NOT NULL,
  `name` varchar(100) NOT NULL,
  `subname` varchar(100) DEFAULT 'M+ Spectator',
  `spawn_map` int unsigned NOT NULL DEFAULT '571' COMMENT 'Dalaran default',
  `spawn_x` float NOT NULL DEFAULT '5807',
  `spawn_y` float NOT NULL DEFAULT '588',
  `spawn_z` float NOT NULL DEFAULT '660',
  `spawn_o` float NOT NULL DEFAULT '3.14',
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - NPC Configuration';

CREATE TABLE IF NOT EXISTS `dc_mplus_spec_positions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `map_id` int unsigned NOT NULL,
  `position_name` varchar(64) NOT NULL COMMENT 'e.g., "First Boss", "Entrance", "Final Boss"',
  `position_x` float NOT NULL,
  `position_y` float NOT NULL,
  `position_z` float NOT NULL,
  `orientation` float NOT NULL DEFAULT '0',
  `is_default` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Default viewing position for spectators',
  PRIMARY KEY (`id`),
  KEY `idx_map` (`map_id`),
  KEY `idx_default` (`map_id`,`is_default`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Viewing Positions';

CREATE TABLE IF NOT EXISTS `dc_mplus_spec_strings` (
  `id` int unsigned NOT NULL,
  `locale` varchar(4) NOT NULL DEFAULT 'enUS',
  `text` varchar(255) NOT NULL,
  PRIMARY KEY (`id`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='DarkChaos M+ Spectator - Localized Strings';

CREATE TABLE IF NOT EXISTS `dc_mplus_teleporter_npcs` (
  `entry` int unsigned NOT NULL COMMENT 'NPC entry from creature_template',
  `name` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'NPC display name',
  `subname` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'NPC subtitle',
  `purpose` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'NPC function description',
  `gossip_menu_id` int unsigned DEFAULT NULL COMMENT 'Gossip menu ID',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mythic+ hub NPC definitions';

CREATE TABLE IF NOT EXISTS `dc_mplus_weekly_affixes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `week_number` tinyint unsigned NOT NULL COMMENT 'Week of rotation (1-12)',
  `affix1_id` int unsigned NOT NULL COMMENT 'Primary affix (always active 2+)',
  `affix2_id` int unsigned DEFAULT NULL COMMENT 'Secondary affix (active 4+)',
  `affix3_id` int unsigned DEFAULT NULL COMMENT 'Tertiary affix (active 7+)',
  `affix4_id` int unsigned DEFAULT NULL COMMENT 'Seasonal affix (active 10+)',
  `season_id` int unsigned NOT NULL DEFAULT '1',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `notes` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_week_season` (`week_number`,`season_id`),
  KEY `idx_season` (`season_id`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly affix rotation schedule';

CREATE TABLE IF NOT EXISTS `dc_npc_quest_link` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `npc_entry` int unsigned NOT NULL COMMENT 'NPC entry ID (700000-700052)',
  `quest_id` int unsigned NOT NULL COMMENT 'Quest ID (700101-700999)',
  `is_starter` tinyint(1) NOT NULL DEFAULT '1',
  `is_ender` tinyint(1) NOT NULL DEFAULT '1',
  `notes` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Admin notes',
  `created_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `npc_quest_link` (`npc_entry`,`quest_id`),
  KEY `quest_idx` (`quest_id`),
  KEY `npc_idx` (`npc_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Optional tracking - standard AC tables (creature_questrelation, creature_involvedrelation) are authoritative';

CREATE TABLE IF NOT EXISTS `dc_pet_definitions` (
  `pet_entry` int unsigned NOT NULL COMMENT 'Pet entry or spell ID',
  `name` varchar(100) NOT NULL,
  `pet_type` enum('companion','minipet') NOT NULL DEFAULT 'companion',
  `pet_spell_id` int unsigned DEFAULT NULL COMMENT 'Summon spell if different',
  `source` text COMMENT 'JSON source info',
  `faction` tinyint unsigned NOT NULL DEFAULT '0',
  `display_id` int unsigned NOT NULL DEFAULT '0',
  `icon` varchar(255) DEFAULT '',
  `rarity` tinyint unsigned NOT NULL DEFAULT '0',
  `expansion` tinyint unsigned NOT NULL DEFAULT '2',
  `flags` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`pet_entry`),
  KEY `idx_rarity` (`rarity`),
  KEY `idx_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Pet definitions';

CREATE TABLE IF NOT EXISTS `dc_quest_difficulty_mapping` (
  `quest_id` int unsigned NOT NULL,
  `base_difficulty` tinyint unsigned NOT NULL DEFAULT '1' COMMENT '1=Easy, 2=Normal, 3=Hard, 4=Heroic, 5=Mythic',
  `scaling_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `min_level` tinyint unsigned DEFAULT NULL,
  `max_level` tinyint unsigned DEFAULT NULL,
  `reward_multiplier` float NOT NULL DEFAULT '1',
  `token_bonus` int unsigned NOT NULL DEFAULT '0',
  `essence_bonus` int unsigned NOT NULL DEFAULT '0',
  `notes` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`quest_id`),
  KEY `idx_difficulty` (`base_difficulty`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Quest difficulty settings and reward modifiers';

CREATE TABLE IF NOT EXISTS `dc_quest_reward_tokens` (
  `token_item_id` int unsigned NOT NULL COMMENT 'Item ID for token (700001-700005)',
  `token_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Display name of token',
  `token_description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Token description for players',
  `token_type` enum('explorer','specialist','legendary','challenge','speedrunner') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Token category/type',
  `rarity` tinyint unsigned DEFAULT '1' COMMENT 'Item rarity (1=common, 2=uncommon, 3=rare, 4=epic)',
  `icon_id` int unsigned DEFAULT NULL COMMENT 'Item icon ID from client DBC',
  `created_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`token_item_id`),
  KEY `token_type` (`token_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Custom dungeon quest token definitions';

CREATE TABLE IF NOT EXISTS `dc_seasonal_chest_rewards` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `season_id` int unsigned NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `chest_tier` tinyint NOT NULL COMMENT 'Tier: 1=Bronze, 2=Silver, 3=Gold, 4=Legendary',
  `item_id` int unsigned NOT NULL COMMENT 'Item template ID',
  `min_drop_ilvl` smallint unsigned DEFAULT '0' COMMENT 'Minimum item level',
  `max_drop_ilvl` smallint unsigned DEFAULT '0' COMMENT 'Maximum item level',
  `drop_chance` float NOT NULL DEFAULT '1' COMMENT 'Probability 0.0-1.0',
  `weight` int unsigned DEFAULT '1' COMMENT 'Selection weight (higher=more likely)',
  `armor_class` tinyint unsigned DEFAULT NULL COMMENT 'Filter: 1=Cloth, 2=Leather, 3=Mail, 4=Plate',
  `slot` tinyint unsigned DEFAULT NULL COMMENT 'Equipment slot filter (optional)',
  `class_restrictions` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Comma-separated class IDs',
  `spec_restrictions` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Comma-separated spec names',
  `primary_stat` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Primary stat priority (INT, STR, AGI)',
  `enabled` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_tier` (`season_id`,`chest_tier`),
  KEY `idx_item_id` (`item_id`),
  KEY `idx_chest_tier` (`chest_tier`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Chest loot pool configuration';

CREATE TABLE IF NOT EXISTS `dc_seasonal_creature_rewards` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `season_id` int unsigned NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `creature_id` int unsigned NOT NULL COMMENT 'Creature template ID',
  `reward_type` tinyint NOT NULL COMMENT '1=Token, 2=Essence, 3=Both',
  `base_token_amount` int unsigned DEFAULT '0' COMMENT 'Base tokens per kill',
  `base_essence_amount` int unsigned DEFAULT '0' COMMENT 'Base essence per kill',
  `creature_rank` tinyint DEFAULT '0' COMMENT 'Rank: 0=Normal, 1=Rare, 2=Boss, 3=Raid Boss',
  `content_type` tinyint DEFAULT '1' COMMENT '1=Dungeon, 2=Raid, 3=World',
  `difficulty_level` tinyint DEFAULT '1' COMMENT 'Content difficulty (1-5)',
  `seasonal_multiplier` float DEFAULT '1' COMMENT 'Season-specific multiplier',
  `minimum_players` tinyint unsigned DEFAULT '1' COMMENT 'Minimum group size required',
  `group_split_tokens` tinyint(1) DEFAULT '1' COMMENT 'Split tokens among group',
  `enabled` tinyint(1) DEFAULT '1' COMMENT 'Enable/disable rewards',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_creature` (`season_id`,`creature_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_creature_id` (`creature_id`),
  KEY `idx_rank_type` (`creature_rank`,`content_type`)
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Boss/Rare/Creature kill reward configuration';

CREATE TABLE IF NOT EXISTS `dc_seasonal_quest_rewards` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `season_id` int unsigned NOT NULL COMMENT 'Foreign key to dc_seasons.season_id',
  `quest_id` int unsigned NOT NULL COMMENT 'Quest template ID',
  `reward_type` tinyint NOT NULL COMMENT '1=Token, 2=Essence, 3=Both',
  `base_token_amount` int unsigned DEFAULT '0' COMMENT 'Base tokens awarded',
  `base_essence_amount` int unsigned DEFAULT '0' COMMENT 'Base essence awarded',
  `min_level` tinyint unsigned DEFAULT '1' COMMENT 'Minimum player level to reward',
  `quest_difficulty` tinyint DEFAULT '2' COMMENT 'Difficulty tier (0-5, where 2=normal)',
  `seasonal_multiplier` float DEFAULT '1' COMMENT 'Season-specific multiplier',
  `is_daily` tinyint(1) DEFAULT '0' COMMENT 'Daily quest flag',
  `is_weekly` tinyint(1) DEFAULT '0' COMMENT 'Weekly quest flag',
  `is_repeatable` tinyint(1) DEFAULT '0' COMMENT 'Repeatable quest flag',
  `enabled` tinyint(1) DEFAULT '1' COMMENT 'Enable/disable rewards for this quest',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_season_quest` (`season_id`,`quest_id`),
  KEY `idx_season_id` (`season_id`),
  KEY `idx_quest_id` (`quest_id`),
  KEY `idx_enabled` (`enabled`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Quest reward configuration per season';

CREATE TABLE IF NOT EXISTS `dc_seasonal_reward_config` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `config_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Configuration key',
  `config_value` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Configuration value (can be JSON)',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Human-readable description',
  `modified_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_config_key` (`config_key`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Global configuration for seasonal reward system';

CREATE TABLE IF NOT EXISTS `dc_seasonal_reward_multipliers` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `season_id` int unsigned NOT NULL,
  `multiplier_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'quest, creature, pvp, achievement, dungeon, raid',
  `base_multiplier` float DEFAULT '1' COMMENT 'Applied to all rewards of this type',
  `day_of_week` tinyint DEFAULT '0' COMMENT '0=every day, 1=Monday, 7=Sunday',
  `hour_start` tinyint DEFAULT '0' COMMENT 'Starting hour (UTC)',
  `hour_end` tinyint DEFAULT '24' COMMENT 'Ending hour (UTC)',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Human-readable description',
  `enabled` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_season_type` (`season_id`,`multiplier_type`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Flexible multiplier overrides for balancing';

CREATE TABLE IF NOT EXISTS `dc_spell_custom_data` (
  `spell_id` int unsigned NOT NULL COMMENT 'Spell ID',
  `custom_note` text COLLATE utf8mb4_unicode_ci COMMENT 'Custom text to show in tooltip',
  `modified_values` text COLLATE utf8mb4_unicode_ci COMMENT 'JSON or comma-separated list of modified values',
  PRIMARY KEY (`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Custom spell metadata for QoS tooltips';

CREATE TABLE IF NOT EXISTS `dc_synthesis_recipes` (
  `recipe_id` int unsigned NOT NULL,
  `type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `required_level` int unsigned NOT NULL DEFAULT '1',
  `input_essence` int unsigned NOT NULL DEFAULT '0',
  `input_tokens` int unsigned NOT NULL DEFAULT '0',
  `output_item_id` int unsigned NOT NULL,
  `success_rate_base` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`recipe_id`),
  KEY `idx_type` (`type`),
  KEY `idx_required_level` (`required_level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Synthesis recipes for item transmutation';

CREATE TABLE IF NOT EXISTS `dc_teleporter` (
  `id` int NOT NULL AUTO_INCREMENT,
  `parent` int NOT NULL DEFAULT '0',
  `type` int NOT NULL DEFAULT '1',
  `faction` int NOT NULL DEFAULT '-1',
  `security_level` int DEFAULT '0',
  `comment` text,
  `icon` int NOT NULL DEFAULT '0',
  `name` char(255) NOT NULL DEFAULT '',
  `map` int DEFAULT NULL,
  `x` decimal(10,3) DEFAULT NULL,
  `y` decimal(10,3) DEFAULT NULL,
  `z` decimal(10,3) DEFAULT NULL,
  `o` decimal(10,3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1001 DEFAULT CHARSET=latin1;

CREATE TABLE IF NOT EXISTS `dc_token_vendor_items` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `class` tinyint unsigned NOT NULL COMMENT 'Class ID (1=Warrior, 2=Paladin, etc)',
  `slot` tinyint unsigned NOT NULL COMMENT 'Gear slot (1=Head, 2=Neck, 3=Shoulders, etc)',
  `item_id` int unsigned NOT NULL COMMENT 'Item template ID',
  `item_level` smallint unsigned NOT NULL COMMENT 'Item level (200, 213, 226, 239, 252, etc)',
  `spec` tinyint unsigned DEFAULT '0' COMMENT 'Talent spec (0=all specs, 1=primary, 2=secondary, 3=tertiary)',
  `token_cost` tinyint unsigned NOT NULL DEFAULT '11' COMMENT 'Token cost (overrides default)',
  `priority` tinyint unsigned DEFAULT '1' COMMENT 'Selection priority (higher = preferred)',
  PRIMARY KEY (`id`),
  KEY `idx_class_slot_ilvl` (`class`,`slot`,`item_level`),
  KEY `idx_item_id` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=797 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Token vendor item pool for Mythic+ rewards';

CREATE TABLE IF NOT EXISTS `dc_toy_definitions` (
  `item_id` int unsigned NOT NULL COMMENT 'Toy item ID',
  `name` varchar(100) NOT NULL,
  `category` varchar(50) DEFAULT 'General',
  `source` text COMMENT 'JSON source info',
  `cooldown` int unsigned NOT NULL DEFAULT '0' COMMENT 'Cooldown in seconds',
  `icon` varchar(255) DEFAULT '',
  `rarity` tinyint unsigned NOT NULL DEFAULT '0',
  `expansion` tinyint unsigned NOT NULL DEFAULT '2',
  `flags` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`item_id`),
  KEY `idx_category` (`category`),
  KEY `idx_rarity` (`rarity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Toy definitions';

CREATE TABLE IF NOT EXISTS `dc_upgrade_tracks` (
  `track_id` int NOT NULL AUTO_INCREMENT COMMENT 'Unique track identifier',
  `track_name` varchar(100) NOT NULL COMMENT 'Display name: Heroic Dungeon, Mythic Raid, etc.',
  `source_content` varchar(50) NOT NULL COMMENT 'Content type: dungeon, raid, hlbg, mythic_plus',
  `difficulty` varchar(50) NOT NULL COMMENT 'Difficulty: heroic, mythic, mythic+5, etc.',
  `base_ilvl` int NOT NULL COMMENT 'Starting item level from this content',
  `max_ilvl` int NOT NULL COMMENT 'Maximum item level after all upgrades',
  `upgrade_steps` tinyint NOT NULL DEFAULT '5' COMMENT 'Number of upgrade stages (0-5 usually)',
  `ilvl_per_step` tinyint NOT NULL DEFAULT '4' COMMENT 'Item level gain per step (+3 or +4)',
  `token_cost_per_upgrade` int NOT NULL DEFAULT '10' COMMENT 'Upgrade tokens needed per step',
  `flightstone_cost_base` int NOT NULL DEFAULT '50' COMMENT 'Base flightstone cost (scaled by slot)',
  `required_player_level` int NOT NULL DEFAULT '80' COMMENT 'Minimum player level to use this track',
  `required_item_level` int NOT NULL DEFAULT '200' COMMENT 'Minimum gear iLvl to access this track',
  `description` varchar(255) DEFAULT NULL COMMENT 'UI description for players',
  `active` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'Is this track currently available?',
  `season` int NOT NULL DEFAULT '0' COMMENT '0 = permanent, else season number',
  `created_date` int unsigned DEFAULT '0' COMMENT 'Unix timestamp when created',
  PRIMARY KEY (`track_id`),
  UNIQUE KEY `uk_track` (`source_content`,`difficulty`,`season`),
  KEY `k_active` (`active`),
  KEY `k_season` (`season`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='Upgrade track definitions';

CREATE TABLE IF NOT EXISTS `dc_vault_loot_table` (
  `item_id` int unsigned NOT NULL COMMENT 'Item entry ID from item_template',
  `item_level_min` smallint unsigned NOT NULL DEFAULT '190' COMMENT 'Minimum ilvl this item can appear at',
  `item_level_max` smallint unsigned NOT NULL DEFAULT '300' COMMENT 'Maximum ilvl this item can appear at',
  `class_mask` int unsigned NOT NULL DEFAULT '0' COMMENT 'Class mask: 1=Warrior, 2=Paladin, 4=Hunter, 8=Rogue, 16=Priest, 32=DK, 64=Shaman, 128=Druid, 256=Mage, 512=Warlock',
  `spec_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Specific spec name (Arms, Fury, Protection, etc.) or NULL for all specs',
  `armor_type` enum('Cloth','Leather','Mail','Plate','Misc') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Armor proficiency requirement',
  `slot_type` enum('Head','Neck','Shoulder','Back','Chest','Wrist','Hands','Waist','Legs','Feet','Finger','Trinket','Weapon','Shield','Offhand','Ranged') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Equipment slot',
  `role_mask` tinyint unsigned NOT NULL DEFAULT '7' COMMENT 'Role mask: 1=Tank, 2=Healer, 4=DPS, 7=All',
  `weight` smallint unsigned NOT NULL DEFAULT '100' COMMENT 'Selection weight for random picking (higher = more likely)',
  `source` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Item source description (ICC, RS, ToC, etc.)',
  PRIMARY KEY (`item_id`),
  KEY `idx_class_spec` (`class_mask`,`spec_name`),
  KEY `idx_armor_slot` (`armor_type`,`slot_type`),
  KEY `idx_role` (`role_mask`),
  KEY `idx_ilvl` (`item_level_min`,`item_level_max`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mythic+ Great Vault loot table for spec-based rewards';

CREATE TABLE IF NOT EXISTS `dc_weekly_quest_token_rewards` (
  `quest_id` int unsigned NOT NULL COMMENT 'Weekly quest ID (700201-700204)',
  `token_item_id` int unsigned NOT NULL COMMENT 'Token item ID to award',
  `token_count` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Number of tokens awarded',
  `bonus_multiplier` float NOT NULL DEFAULT '1' COMMENT 'Multiplier for bonus tokens (difficulty-based)',
  `created_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`quest_id`),
  KEY `token_idx` (`token_item_id`),
  CONSTRAINT `dc_weekly_quest_token_rewards_ibfk_1` FOREIGN KEY (`token_item_id`) REFERENCES `dc_quest_reward_tokens` (`token_item_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weekly dungeon quest token rewards - triggers on QUEST_REWARDED status';

CREATE TABLE IF NOT EXISTS `destructiblemodeldata_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `State0Wmo` int NOT NULL DEFAULT '0',
  `State0DestructionDoodadSet` int NOT NULL DEFAULT '0',
  `State0ImpactEffectDoodadSet` int NOT NULL DEFAULT '0',
  `State0AmbientDoodadSet` int NOT NULL DEFAULT '0',
  `State1Wmo` int NOT NULL DEFAULT '0',
  `State1DestructionDoodadSet` int NOT NULL DEFAULT '0',
  `State1ImpactEffectDoodadSet` int NOT NULL DEFAULT '0',
  `State1AmbientDoodadSet` int NOT NULL DEFAULT '0',
  `State2Wmo` int NOT NULL DEFAULT '0',
  `State2DestructionDoodadSet` int NOT NULL DEFAULT '0',
  `State2ImpactEffectDoodadSet` int NOT NULL DEFAULT '0',
  `State2AmbientDoodadSet` int NOT NULL DEFAULT '0',
  `State3Wmo` int NOT NULL DEFAULT '0',
  `State3DestructionDoodadSet` int NOT NULL DEFAULT '0',
  `State3ImpactEffectDoodadSet` int NOT NULL DEFAULT '0',
  `State3AmbientDoodadSet` int NOT NULL DEFAULT '0',
  `Field17` int NOT NULL DEFAULT '0',
  `Field18` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `disables` (
  `sourceType` int unsigned NOT NULL,
  `entry` int unsigned NOT NULL,
  `flags` tinyint unsigned NOT NULL DEFAULT '0',
  `params_0` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `params_1` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`sourceType`,`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `disenchant_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `dungeon_access_requirements` (
  `dungeon_access_id` tinyint unsigned NOT NULL COMMENT 'ID from dungeon_access_template',
  `requirement_type` tinyint unsigned NOT NULL COMMENT '0 = achiev, 1 = quest, 2 = item',
  `requirement_id` int unsigned NOT NULL COMMENT 'Achiev/quest/item ID',
  `requirement_note` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Optional msg shown ingame to player if he cannot enter. You can add extra info',
  `faction` tinyint unsigned NOT NULL DEFAULT '2' COMMENT '0 = Alliance, 1 = Horde, 2 = Both factions',
  `priority` tinyint unsigned DEFAULT NULL COMMENT 'Priority order for the requirement, sorted by type. 0 is the highest priority',
  `leader_only` tinyint NOT NULL DEFAULT '0' COMMENT '0 = check the requirement for the player trying to enter, 1 = check the requirement for the party leader',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`dungeon_access_id`,`requirement_type`,`requirement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Add (multiple) requirements before being able to enter a dungeon/raid';

CREATE TABLE IF NOT EXISTS `dungeon_access_template` (
  `id` tinyint unsigned NOT NULL AUTO_INCREMENT COMMENT 'The dungeon template ID',
  `map_id` int unsigned DEFAULT NULL COMMENT 'Map ID from instance_template',
  `difficulty` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '5 man: 0 = normal, 1 = heroic, 2 = epic (not implemented) | 10 man: 0 = normal, 2 = heroic | 25 man: 1 = normal, 3 = heroic',
  `min_level` tinyint unsigned DEFAULT NULL,
  `max_level` tinyint unsigned DEFAULT NULL,
  `min_avg_item_level` smallint unsigned DEFAULT NULL COMMENT 'Min average ilvl required to enter',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Dungeon Name 5/10/25/40 man - Normal/Heroic',
  PRIMARY KEY (`id`),
  KEY `FK_dungeon_access_template__instance_template` (`map_id`)
) ENGINE=InnoDB AUTO_INCREMENT=138 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Dungeon/raid access template and single requirements';

CREATE TABLE IF NOT EXISTS `dungeonencounter_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MapID` int NOT NULL DEFAULT '0',
  `Difficulty` int NOT NULL DEFAULT '0',
  `OrderIndex` int NOT NULL DEFAULT '0',
  `Bit` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `SpellIconID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `durabilitycosts_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_1` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_2` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_3` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_4` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_5` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_6` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_7` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_8` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_9` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_10` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_11` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_12` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_13` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_14` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_15` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_16` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_17` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_18` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_19` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_20` int NOT NULL DEFAULT '0',
  `WeaponSubClassCost_21` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_1` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_2` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_3` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_4` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_5` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_6` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_7` int NOT NULL DEFAULT '0',
  `ArmorSubClassCost_8` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `durabilityquality_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `emotes_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `EmoteSlashCommand` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AnimID` int NOT NULL DEFAULT '0',
  `EmoteFlags` int NOT NULL DEFAULT '0',
  `EmoteSpecProc` int NOT NULL DEFAULT '0',
  `EmoteSpecProcParam` int NOT NULL DEFAULT '0',
  `EventSoundID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `emotestext_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `EmoteID` int NOT NULL DEFAULT '0',
  `EmoteText_1` int NOT NULL DEFAULT '0',
  `EmoteText_2` int NOT NULL DEFAULT '0',
  `EmoteText_3` int NOT NULL DEFAULT '0',
  `EmoteText_4` int NOT NULL DEFAULT '0',
  `EmoteText_5` int NOT NULL DEFAULT '0',
  `EmoteText_6` int NOT NULL DEFAULT '0',
  `EmoteText_7` int NOT NULL DEFAULT '0',
  `EmoteText_8` int NOT NULL DEFAULT '0',
  `EmoteText_9` int NOT NULL DEFAULT '0',
  `EmoteText_10` int NOT NULL DEFAULT '0',
  `EmoteText_11` int NOT NULL DEFAULT '0',
  `EmoteText_12` int NOT NULL DEFAULT '0',
  `EmoteText_13` int NOT NULL DEFAULT '0',
  `EmoteText_14` int NOT NULL DEFAULT '0',
  `EmoteText_15` int NOT NULL DEFAULT '0',
  `EmoteText_16` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `event_scripts` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `delay` int unsigned NOT NULL DEFAULT '0',
  `command` int unsigned NOT NULL DEFAULT '0',
  `datalong` int unsigned NOT NULL DEFAULT '0',
  `datalong2` int unsigned NOT NULL DEFAULT '0',
  `dataint` int NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `o` float NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `exploration_basexp` (
  `level` tinyint unsigned NOT NULL DEFAULT '0',
  `basexp` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Exploration System';

CREATE TABLE IF NOT EXISTS `faction_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ReputationIndex` int NOT NULL DEFAULT '0',
  `ReputationRaceMask_1` int NOT NULL DEFAULT '0',
  `ReputationRaceMask_2` int NOT NULL DEFAULT '0',
  `ReputationRaceMask_3` int NOT NULL DEFAULT '0',
  `ReputationRaceMask_4` int NOT NULL DEFAULT '0',
  `ReputationClassMask_1` int NOT NULL DEFAULT '0',
  `ReputationClassMask_2` int NOT NULL DEFAULT '0',
  `ReputationClassMask_3` int NOT NULL DEFAULT '0',
  `ReputationClassMask_4` int NOT NULL DEFAULT '0',
  `ReputationBase_1` int NOT NULL DEFAULT '0',
  `ReputationBase_2` int NOT NULL DEFAULT '0',
  `ReputationBase_3` int NOT NULL DEFAULT '0',
  `ReputationBase_4` int NOT NULL DEFAULT '0',
  `ReputationFlags_1` int NOT NULL DEFAULT '0',
  `ReputationFlags_2` int NOT NULL DEFAULT '0',
  `ReputationFlags_3` int NOT NULL DEFAULT '0',
  `ReputationFlags_4` int NOT NULL DEFAULT '0',
  `ParentFactionID` int NOT NULL DEFAULT '0',
  `ParentFactionMod_1` float NOT NULL DEFAULT '0',
  `ParentFactionMod_2` float NOT NULL DEFAULT '0',
  `ParentFactionCap_1` int NOT NULL DEFAULT '0',
  `ParentFactionCap_2` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Description_Lang_enUS` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enGB` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_koKR` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_frFR` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_deDE` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enCN` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhCN` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enTW` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhTW` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esES` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esMX` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ruRU` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptPT` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptBR` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_itIT` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `factiontemplate_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Faction` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `FactionGroup` int NOT NULL DEFAULT '0',
  `FriendGroup` int NOT NULL DEFAULT '0',
  `EnemyGroup` int NOT NULL DEFAULT '0',
  `Enemies_1` int NOT NULL DEFAULT '0',
  `Enemies_2` int NOT NULL DEFAULT '0',
  `Enemies_3` int NOT NULL DEFAULT '0',
  `Enemies_4` int NOT NULL DEFAULT '0',
  `Friend_1` int NOT NULL DEFAULT '0',
  `Friend_2` int NOT NULL DEFAULT '0',
  `Friend_3` int NOT NULL DEFAULT '0',
  `Friend_4` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fishing_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `game_event` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `start_time` timestamp NULL DEFAULT '2000-01-01 13:00:00' COMMENT 'Absolute start date, the event will never start before',
  `end_time` timestamp NULL DEFAULT '2000-01-01 13:00:00' COMMENT 'Absolute end date, the event will never start after',
  `occurence` bigint unsigned NOT NULL DEFAULT '5184000' COMMENT 'Delay in minutes between occurences of the event',
  `length` bigint unsigned NOT NULL DEFAULT '2592000' COMMENT 'Length in minutes of the event',
  `holiday` int unsigned NOT NULL DEFAULT '0' COMMENT 'Client side holiday id',
  `holidayStage` tinyint unsigned NOT NULL DEFAULT '0',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Description of the event displayed in console',
  `world_event` tinyint unsigned NOT NULL DEFAULT '0' COMMENT '0 if normal event, 1 if world event',
  `announce` tinyint unsigned NOT NULL DEFAULT '2' COMMENT '0 dont announce, 1 announce, 2 value from config',
  PRIMARY KEY (`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_arena_seasons` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `season` tinyint unsigned NOT NULL COMMENT 'Arena season number',
  UNIQUE KEY `season` (`season`,`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_battleground_holiday` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `bgflag` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_condition` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `condition_id` int unsigned NOT NULL DEFAULT '0',
  `req_num` float DEFAULT '0',
  `max_world_state_field` smallint unsigned NOT NULL DEFAULT '0',
  `done_world_state_field` smallint unsigned NOT NULL DEFAULT '0',
  `description` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`eventEntry`,`condition_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_creature` (
  `eventEntry` smallint NOT NULL COMMENT 'Entry of the game event. Put negative entry to remove during event.',
  `guid` int unsigned NOT NULL,
  PRIMARY KEY (`guid`,`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_creature_quest` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event.',
  `id` int unsigned NOT NULL DEFAULT '0',
  `quest` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_gameobject` (
  `eventEntry` smallint NOT NULL COMMENT 'Entry of the game event. Put negative entry to remove during event.',
  `guid` int unsigned NOT NULL,
  PRIMARY KEY (`guid`,`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_gameobject_quest` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `id` int unsigned NOT NULL DEFAULT '0',
  `quest` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`,`quest`,`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_model_equip` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event.',
  `guid` int unsigned NOT NULL DEFAULT '0',
  `modelid` int unsigned NOT NULL DEFAULT '0',
  `equipment_id` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_npc_vendor` (
  `eventEntry` smallint NOT NULL COMMENT 'Entry of the game event.',
  `guid` int unsigned NOT NULL DEFAULT '0',
  `slot` smallint NOT NULL DEFAULT '0',
  `item` int unsigned NOT NULL DEFAULT '0',
  `maxcount` int unsigned NOT NULL DEFAULT '0',
  `incrtime` int unsigned NOT NULL DEFAULT '0',
  `ExtendedCost` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`eventEntry`,`guid`,`item`) USING BTREE,
  KEY `slot` (`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_npcflag` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `guid` int unsigned NOT NULL DEFAULT '0',
  `npcflag` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`eventEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_pool` (
  `eventEntry` smallint NOT NULL COMMENT 'Entry of the game event. Put negative entry to remove during event.',
  `pool_entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Id of the pool',
  PRIMARY KEY (`pool_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_prerequisite` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event',
  `prerequisite_event` int unsigned NOT NULL,
  PRIMARY KEY (`eventEntry`,`prerequisite_event`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_quest_condition` (
  `eventEntry` tinyint unsigned NOT NULL COMMENT 'Entry of the game event.',
  `quest` int unsigned NOT NULL DEFAULT '0',
  `condition_id` int unsigned NOT NULL DEFAULT '0',
  `num` float DEFAULT '0',
  PRIMARY KEY (`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_event_seasonal_questrelation` (
  `questId` int unsigned NOT NULL COMMENT 'Quest Identifier',
  `eventEntry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Entry of the game event',
  PRIMARY KEY (`questId`,`eventEntry`),
  KEY `idx_quest` (`questId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Player System';

CREATE TABLE IF NOT EXISTS `game_graveyard` (
  `ID` int NOT NULL DEFAULT '0',
  `Map` int NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `game_tele` (
  `id` int unsigned NOT NULL,
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `map` smallint unsigned NOT NULL DEFAULT '0',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tele Command';

CREATE TABLE IF NOT EXISTS `game_weather` (
  `zone` int unsigned NOT NULL DEFAULT '0',
  `spring_rain_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `spring_snow_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `spring_storm_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `summer_rain_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `summer_snow_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `summer_storm_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `fall_rain_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `fall_snow_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `fall_storm_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `winter_rain_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `winter_snow_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `winter_storm_chance` tinyint unsigned NOT NULL DEFAULT '25',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Weather System';

CREATE TABLE IF NOT EXISTS `gameobject` (
  `guid` int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Global Unique Identifier',
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Gameobject Identifier',
  `map` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Map Identifier',
  `zoneId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Zone Identifier',
  `areaId` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'Area Identifier',
  `spawnMask` tinyint unsigned NOT NULL DEFAULT '1',
  `phaseMask` int unsigned NOT NULL DEFAULT '1',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `rotation0` float NOT NULL DEFAULT '0',
  `rotation1` float NOT NULL DEFAULT '0',
  `rotation2` float NOT NULL DEFAULT '0',
  `rotation3` float NOT NULL DEFAULT '0',
  `spawntimesecs` int NOT NULL DEFAULT '0',
  `animprogress` tinyint unsigned NOT NULL DEFAULT '0',
  `state` tinyint unsigned NOT NULL DEFAULT '0',
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '',
  `VerifiedBuild` int DEFAULT NULL,
  `Comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB AUTO_INCREMENT=5714516 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Gameobject System';

CREATE TABLE IF NOT EXISTS `gameobject_addon` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `invisibilityType` tinyint unsigned NOT NULL DEFAULT '0',
  `invisibilityValue` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobject_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `gameobject_questender` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`id`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobject_questitem` (
  `GameObjectEntry` int unsigned NOT NULL DEFAULT '0',
  `Idx` int unsigned NOT NULL DEFAULT '0',
  `ItemId` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`GameObjectEntry`,`Idx`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobject_queststarter` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `quest` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest Identifier',
  PRIMARY KEY (`id`,`quest`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobject_template` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `displayId` int unsigned NOT NULL DEFAULT '0',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `IconName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `castBarCaption` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `unk1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `size` float NOT NULL DEFAULT '1',
  `Data0` int unsigned NOT NULL DEFAULT '0',
  `Data1` int NOT NULL DEFAULT '0',
  `Data2` int unsigned NOT NULL DEFAULT '0',
  `Data3` int unsigned NOT NULL DEFAULT '0',
  `Data4` int unsigned NOT NULL DEFAULT '0',
  `Data5` int unsigned NOT NULL DEFAULT '0',
  `Data6` int NOT NULL DEFAULT '0',
  `Data7` int unsigned NOT NULL DEFAULT '0',
  `Data8` int unsigned NOT NULL DEFAULT '0',
  `Data9` int unsigned NOT NULL DEFAULT '0',
  `Data10` int unsigned NOT NULL DEFAULT '0',
  `Data11` int unsigned NOT NULL DEFAULT '0',
  `Data12` int unsigned NOT NULL DEFAULT '0',
  `Data13` int unsigned NOT NULL DEFAULT '0',
  `Data14` int unsigned NOT NULL DEFAULT '0',
  `Data15` int unsigned NOT NULL DEFAULT '0',
  `Data16` int unsigned NOT NULL DEFAULT '0',
  `Data17` int unsigned NOT NULL DEFAULT '0',
  `Data18` int unsigned NOT NULL DEFAULT '0',
  `Data19` int unsigned NOT NULL DEFAULT '0',
  `Data20` int unsigned NOT NULL DEFAULT '0',
  `Data21` int unsigned NOT NULL DEFAULT '0',
  `Data22` int unsigned NOT NULL DEFAULT '0',
  `Data23` int unsigned NOT NULL DEFAULT '0',
  `AIName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `ScriptName` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Gameobject System';

CREATE TABLE IF NOT EXISTS `gameobject_template_addon` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `faction` smallint unsigned NOT NULL DEFAULT '0',
  `flags` int unsigned NOT NULL DEFAULT '0',
  `mingold` int unsigned NOT NULL DEFAULT '0',
  `maxgold` int unsigned NOT NULL DEFAULT '0',
  `artkit0` int NOT NULL DEFAULT '0',
  `artkit1` int NOT NULL DEFAULT '0',
  `artkit2` int NOT NULL DEFAULT '0',
  `artkit3` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobject_template_locale` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `castBarCaption` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobjectartkit_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Texture_1` int NOT NULL DEFAULT '0',
  `Texture_2` int NOT NULL DEFAULT '0',
  `Texture_3` int NOT NULL DEFAULT '0',
  `Attach_Model_1` int NOT NULL DEFAULT '0',
  `Attach_Model_2` int NOT NULL DEFAULT '0',
  `Attach_Model_3` int NOT NULL DEFAULT '0',
  `Attach_Model_4` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gameobjectdisplayinfo_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ModelName` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Sound_1` int NOT NULL DEFAULT '0',
  `Sound_2` int NOT NULL DEFAULT '0',
  `Sound_3` int NOT NULL DEFAULT '0',
  `Sound_4` int NOT NULL DEFAULT '0',
  `Sound_5` int NOT NULL DEFAULT '0',
  `Sound_6` int NOT NULL DEFAULT '0',
  `Sound_7` int NOT NULL DEFAULT '0',
  `Sound_8` int NOT NULL DEFAULT '0',
  `Sound_9` int NOT NULL DEFAULT '0',
  `Sound_10` int NOT NULL DEFAULT '0',
  `GeoBoxMinX` float NOT NULL DEFAULT '0',
  `GeoBoxMinY` float NOT NULL DEFAULT '0',
  `GeoBoxMinZ` float NOT NULL DEFAULT '0',
  `GeoBoxMaxX` float NOT NULL DEFAULT '0',
  `GeoBoxMaxY` float NOT NULL DEFAULT '0',
  `GeoBoxMaxZ` float NOT NULL DEFAULT '0',
  `ObjectEffectPackageID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gemproperties_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Enchant_Id` int NOT NULL DEFAULT '0',
  `Maxcount_Inv` int NOT NULL DEFAULT '0',
  `Maxcount_Item` int NOT NULL DEFAULT '0',
  `Type` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //
CREATE PROCEDURE `GenerateHeirloomEnchantMappings`()
BEGIN
    DECLARE pkg_id INT;
    DECLARE lvl INT;
    DECLARE base_val INT;
    DECLARE stat1_type INT;
    DECLARE stat2_type INT;
    DECLARE stat3_type INT;
    DECLARE weight1 FLOAT;
    DECLARE weight2 FLOAT;
    DECLARE weight3 FLOAT;
    DECLARE pkg_name VARCHAR(32);
    DECLARE stat1_val INT;
    DECLARE stat2_val INT;
    DECLARE stat3_val INT;
    DECLARE enc_id INT;
    DECLARE display_txt VARCHAR(128);
    
    -- Clear existing mappings
    TRUNCATE TABLE dc_heirloom_enchant_mapping;
    
    -- Loop through all packages
    SET pkg_id = 1;
    WHILE pkg_id <= 12 DO
        -- Get package definition
        SELECT package_name, stat_type_1, stat_type_2, stat_type_3, stat_weight_1, stat_weight_2, stat_weight_3
        INTO pkg_name, stat1_type, stat2_type, stat3_type, weight1, weight2, weight3
        FROM dc_heirloom_stat_packages
        WHERE package_id = pkg_id;
        
        -- Loop through all levels
        SET lvl = 1;
        WHILE lvl <= 15 DO
            -- Get base value for this level
            SELECT base_stat_value INTO base_val
            FROM dc_heirloom_package_levels
            WHERE level = lvl;
            
            -- Calculate stat values
            SET stat1_val = ROUND(base_val * weight1);
            SET stat2_val = ROUND(base_val * weight2);
            SET stat3_val = IF(stat3_type IS NOT NULL, ROUND(base_val * weight3), NULL);
            
            -- Calculate enchant ID: 900000 + (pkg_id * 100) + level
            SET enc_id = 900000 + (pkg_id * 100) + lvl;
            
            -- Build display text
            SET display_txt = CONCAT(pkg_name, ' ', lvl, '/15');
            
            -- Insert mapping
            INSERT INTO dc_heirloom_enchant_mapping 
                (package_id, level, enchant_id, stat_1_value, stat_2_value, stat_3_value, display_text)
            VALUES 
                (pkg_id, lvl, enc_id, stat1_val, stat2_val, stat3_val, display_txt);
            
            SET lvl = lvl + 1;
        END WHILE;
        
        SET pkg_id = pkg_id + 1;
    END WHILE;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS `glyphproperties_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `SpellID` int NOT NULL DEFAULT '0',
  `GlyphSlotFlags` int NOT NULL DEFAULT '0',
  `SpellIconID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `glyphslot_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Type` int NOT NULL DEFAULT '0',
  `Tooltip` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gossip_menu` (
  `MenuID` int unsigned NOT NULL DEFAULT '0',
  `TextID` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`MenuID`,`TextID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gossip_menu_option` (
  `MenuID` int unsigned NOT NULL DEFAULT '0',
  `OptionID` smallint unsigned NOT NULL DEFAULT '0',
  `OptionIcon` int unsigned NOT NULL DEFAULT '0',
  `OptionText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `OptionBroadcastTextID` int NOT NULL DEFAULT '0',
  `OptionType` tinyint unsigned NOT NULL DEFAULT '0',
  `OptionNpcFlag` int unsigned NOT NULL DEFAULT '0',
  `ActionMenuID` int unsigned NOT NULL DEFAULT '0',
  `ActionPoiID` int unsigned NOT NULL DEFAULT '0',
  `BoxCoded` tinyint unsigned NOT NULL DEFAULT '0',
  `BoxMoney` int unsigned NOT NULL DEFAULT '0',
  `BoxText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BoxBroadcastTextID` int NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`MenuID`,`OptionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gossip_menu_option_locale` (
  `MenuID` int unsigned NOT NULL DEFAULT '0',
  `OptionID` smallint unsigned NOT NULL DEFAULT '0',
  `Locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `OptionText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BoxText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`MenuID`,`OptionID`,`Locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `graveyard_zone` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `GhostZone` int unsigned NOT NULL DEFAULT '0',
  `Faction` smallint unsigned NOT NULL DEFAULT '0',
  `Comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`ID`,`GhostZone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Trigger System';

CREATE TABLE IF NOT EXISTS `gtbarbershopcostbase_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtchancetomeleecrit_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtchancetomeleecritbase_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtchancetospellcrit_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtchancetospellcritbase_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtcombatratings_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtnpcmanacostscaler_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtoctclasscombatratingscalar_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtoctregenhp_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtregenhpperspt_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `gtregenmpperspt_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `holidays_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Duration_1` int NOT NULL DEFAULT '0',
  `Duration_2` int NOT NULL DEFAULT '0',
  `Duration_3` int NOT NULL DEFAULT '0',
  `Duration_4` int NOT NULL DEFAULT '0',
  `Duration_5` int NOT NULL DEFAULT '0',
  `Duration_6` int NOT NULL DEFAULT '0',
  `Duration_7` int NOT NULL DEFAULT '0',
  `Duration_8` int NOT NULL DEFAULT '0',
  `Duration_9` int NOT NULL DEFAULT '0',
  `Duration_10` int NOT NULL DEFAULT '0',
  `Date_1` int NOT NULL DEFAULT '0',
  `Date_2` int NOT NULL DEFAULT '0',
  `Date_3` int NOT NULL DEFAULT '0',
  `Date_4` int NOT NULL DEFAULT '0',
  `Date_5` int NOT NULL DEFAULT '0',
  `Date_6` int NOT NULL DEFAULT '0',
  `Date_7` int NOT NULL DEFAULT '0',
  `Date_8` int NOT NULL DEFAULT '0',
  `Date_9` int NOT NULL DEFAULT '0',
  `Date_10` int NOT NULL DEFAULT '0',
  `Date_11` int NOT NULL DEFAULT '0',
  `Date_12` int NOT NULL DEFAULT '0',
  `Date_13` int NOT NULL DEFAULT '0',
  `Date_14` int NOT NULL DEFAULT '0',
  `Date_15` int NOT NULL DEFAULT '0',
  `Date_16` int NOT NULL DEFAULT '0',
  `Date_17` int NOT NULL DEFAULT '0',
  `Date_18` int NOT NULL DEFAULT '0',
  `Date_19` int NOT NULL DEFAULT '0',
  `Date_20` int NOT NULL DEFAULT '0',
  `Date_21` int NOT NULL DEFAULT '0',
  `Date_22` int NOT NULL DEFAULT '0',
  `Date_23` int NOT NULL DEFAULT '0',
  `Date_24` int NOT NULL DEFAULT '0',
  `Date_25` int NOT NULL DEFAULT '0',
  `Date_26` int NOT NULL DEFAULT '0',
  `Region` int NOT NULL DEFAULT '0',
  `Looping` int NOT NULL DEFAULT '0',
  `CalendarFlags_1` int NOT NULL DEFAULT '0',
  `CalendarFlags_2` int NOT NULL DEFAULT '0',
  `CalendarFlags_3` int NOT NULL DEFAULT '0',
  `CalendarFlags_4` int NOT NULL DEFAULT '0',
  `CalendarFlags_5` int NOT NULL DEFAULT '0',
  `CalendarFlags_6` int NOT NULL DEFAULT '0',
  `CalendarFlags_7` int NOT NULL DEFAULT '0',
  `CalendarFlags_8` int NOT NULL DEFAULT '0',
  `CalendarFlags_9` int NOT NULL DEFAULT '0',
  `CalendarFlags_10` int NOT NULL DEFAULT '0',
  `HolidayNameID` int NOT NULL DEFAULT '0',
  `HolidayDescriptionID` int NOT NULL DEFAULT '0',
  `TextureFilename` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Priority` int NOT NULL DEFAULT '0',
  `CalendarFilterType` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `instance_encounters` (
  `entry` int unsigned NOT NULL COMMENT 'Unique entry from DungeonEncounter.dbc',
  `creditType` tinyint unsigned NOT NULL DEFAULT '0',
  `creditEntry` int unsigned NOT NULL DEFAULT '0',
  `lastEncounterDungeon` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'If not 0, LfgDungeon.dbc entry for the instance it is last encounter in',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `instance_template` (
  `map` smallint unsigned NOT NULL,
  `parent` smallint unsigned NOT NULL,
  `script` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `allowMount` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`map`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `item_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ClassID` int NOT NULL DEFAULT '0',
  `SubclassID` int NOT NULL DEFAULT '0',
  `Sound_Override_Subclassid` int NOT NULL DEFAULT '0',
  `Material` int NOT NULL DEFAULT '0',
  `DisplayInfoID` int NOT NULL DEFAULT '0',
  `InventoryType` int NOT NULL DEFAULT '0',
  `SheatheType` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `item_enchantment_template` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `ench` int unsigned NOT NULL DEFAULT '0',
  `chance` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`,`ench`),
  CONSTRAINT `item_enchantment_template_chk_1` CHECK ((`chance` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item Random Enchantment System';

CREATE TABLE IF NOT EXISTS `item_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `item_set_names` (
  `entry` int unsigned NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `InventoryType` tinyint unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `item_set_names_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `item_template` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `subclass` tinyint unsigned NOT NULL DEFAULT '0',
  `SoundOverrideSubclass` tinyint NOT NULL DEFAULT '-1',
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `displayid` int unsigned NOT NULL DEFAULT '0',
  `Quality` tinyint unsigned NOT NULL DEFAULT '0',
  `Flags` int unsigned NOT NULL DEFAULT '0',
  `FlagsExtra` int unsigned NOT NULL DEFAULT '0',
  `BuyCount` tinyint unsigned NOT NULL DEFAULT '1',
  `BuyPrice` bigint NOT NULL DEFAULT '0',
  `SellPrice` int unsigned NOT NULL DEFAULT '0',
  `InventoryType` tinyint unsigned NOT NULL DEFAULT '0',
  `AllowableClass` int NOT NULL DEFAULT '-1',
  `AllowableRace` int NOT NULL DEFAULT '-1',
  `ItemLevel` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredLevel` tinyint unsigned NOT NULL DEFAULT '0',
  `RequiredSkill` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredSkillRank` smallint unsigned NOT NULL DEFAULT '0',
  `requiredspell` int unsigned NOT NULL DEFAULT '0',
  `requiredhonorrank` int unsigned NOT NULL DEFAULT '0',
  `RequiredCityRank` int unsigned NOT NULL DEFAULT '0',
  `RequiredReputationFaction` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredReputationRank` smallint unsigned NOT NULL DEFAULT '0',
  `maxcount` int NOT NULL DEFAULT '0',
  `stackable` int DEFAULT '1',
  `ContainerSlots` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_type1` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value1` int NOT NULL DEFAULT '0',
  `stat_type2` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value2` int NOT NULL DEFAULT '0',
  `stat_type3` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value3` int NOT NULL DEFAULT '0',
  `stat_type4` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value4` int NOT NULL DEFAULT '0',
  `stat_type5` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value5` int NOT NULL DEFAULT '0',
  `stat_type6` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value6` int NOT NULL DEFAULT '0',
  `stat_type7` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value7` int NOT NULL DEFAULT '0',
  `stat_type8` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value8` int NOT NULL DEFAULT '0',
  `stat_type9` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value9` int NOT NULL DEFAULT '0',
  `stat_type10` tinyint unsigned NOT NULL DEFAULT '0',
  `stat_value10` int NOT NULL DEFAULT '0',
  `ScalingStatDistribution` smallint NOT NULL DEFAULT '0',
  `ScalingStatValue` int unsigned NOT NULL DEFAULT '0',
  `dmg_min1` float NOT NULL DEFAULT '0',
  `dmg_max1` float NOT NULL DEFAULT '0',
  `dmg_type1` tinyint unsigned NOT NULL DEFAULT '0',
  `dmg_min2` float NOT NULL DEFAULT '0',
  `dmg_max2` float NOT NULL DEFAULT '0',
  `dmg_type2` tinyint unsigned NOT NULL DEFAULT '0',
  `armor` int unsigned NOT NULL DEFAULT '0',
  `holy_res` smallint DEFAULT NULL,
  `fire_res` smallint DEFAULT NULL,
  `nature_res` smallint DEFAULT NULL,
  `frost_res` smallint DEFAULT NULL,
  `shadow_res` smallint DEFAULT NULL,
  `arcane_res` smallint DEFAULT NULL,
  `delay` smallint unsigned NOT NULL DEFAULT '1000',
  `ammo_type` tinyint unsigned NOT NULL DEFAULT '0',
  `RangedModRange` float NOT NULL DEFAULT '0',
  `spellid_1` int NOT NULL DEFAULT '0',
  `spelltrigger_1` tinyint unsigned NOT NULL DEFAULT '0',
  `spellcharges_1` smallint NOT NULL DEFAULT '0',
  `spellppmRate_1` float NOT NULL DEFAULT '0',
  `spellcooldown_1` int NOT NULL DEFAULT '-1',
  `spellcategory_1` smallint unsigned NOT NULL DEFAULT '0',
  `spellcategorycooldown_1` int NOT NULL DEFAULT '-1',
  `spellid_2` int NOT NULL DEFAULT '0',
  `spelltrigger_2` tinyint unsigned NOT NULL DEFAULT '0',
  `spellcharges_2` smallint NOT NULL DEFAULT '0',
  `spellppmRate_2` float NOT NULL DEFAULT '0',
  `spellcooldown_2` int NOT NULL DEFAULT '-1',
  `spellcategory_2` smallint unsigned NOT NULL DEFAULT '0',
  `spellcategorycooldown_2` int NOT NULL DEFAULT '-1',
  `spellid_3` int NOT NULL DEFAULT '0',
  `spelltrigger_3` tinyint unsigned NOT NULL DEFAULT '0',
  `spellcharges_3` smallint NOT NULL DEFAULT '0',
  `spellppmRate_3` float NOT NULL DEFAULT '0',
  `spellcooldown_3` int NOT NULL DEFAULT '-1',
  `spellcategory_3` smallint unsigned NOT NULL DEFAULT '0',
  `spellcategorycooldown_3` int NOT NULL DEFAULT '-1',
  `spellid_4` int NOT NULL DEFAULT '0',
  `spelltrigger_4` tinyint unsigned NOT NULL DEFAULT '0',
  `spellcharges_4` smallint NOT NULL DEFAULT '0',
  `spellppmRate_4` float NOT NULL DEFAULT '0',
  `spellcooldown_4` int NOT NULL DEFAULT '-1',
  `spellcategory_4` smallint unsigned NOT NULL DEFAULT '0',
  `spellcategorycooldown_4` int NOT NULL DEFAULT '-1',
  `spellid_5` int NOT NULL DEFAULT '0',
  `spelltrigger_5` tinyint unsigned NOT NULL DEFAULT '0',
  `spellcharges_5` smallint NOT NULL DEFAULT '0',
  `spellppmRate_5` float NOT NULL DEFAULT '0',
  `spellcooldown_5` int NOT NULL DEFAULT '-1',
  `spellcategory_5` smallint unsigned NOT NULL DEFAULT '0',
  `spellcategorycooldown_5` int NOT NULL DEFAULT '-1',
  `bonding` tinyint unsigned NOT NULL DEFAULT '0',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `PageText` int unsigned NOT NULL DEFAULT '0',
  `LanguageID` tinyint unsigned NOT NULL DEFAULT '0',
  `PageMaterial` tinyint unsigned NOT NULL DEFAULT '0',
  `startquest` int unsigned NOT NULL DEFAULT '0',
  `lockid` int unsigned NOT NULL DEFAULT '0',
  `Material` tinyint NOT NULL DEFAULT '0',
  `sheath` tinyint unsigned NOT NULL DEFAULT '0',
  `RandomProperty` int NOT NULL DEFAULT '0',
  `RandomSuffix` int unsigned NOT NULL DEFAULT '0',
  `block` int unsigned NOT NULL DEFAULT '0',
  `itemset` int unsigned NOT NULL DEFAULT '0',
  `MaxDurability` smallint unsigned NOT NULL DEFAULT '0',
  `area` int unsigned NOT NULL DEFAULT '0',
  `Map` smallint NOT NULL DEFAULT '0',
  `BagFamily` int NOT NULL DEFAULT '0',
  `TotemCategory` int NOT NULL DEFAULT '0',
  `socketColor_1` tinyint NOT NULL DEFAULT '0',
  `socketContent_1` int NOT NULL DEFAULT '0',
  `socketColor_2` tinyint NOT NULL DEFAULT '0',
  `socketContent_2` int NOT NULL DEFAULT '0',
  `socketColor_3` tinyint NOT NULL DEFAULT '0',
  `socketContent_3` int NOT NULL DEFAULT '0',
  `socketBonus` int NOT NULL DEFAULT '0',
  `GemProperties` int NOT NULL DEFAULT '0',
  `RequiredDisenchantSkill` smallint NOT NULL DEFAULT '-1',
  `ArmorDamageModifier` float NOT NULL DEFAULT '0',
  `duration` int unsigned NOT NULL DEFAULT '0',
  `ItemLimitCategory` smallint NOT NULL DEFAULT '0',
  `HolidayId` int unsigned NOT NULL DEFAULT '0',
  `ScriptName` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `DisenchantID` int unsigned NOT NULL DEFAULT '0',
  `FoodType` tinyint unsigned NOT NULL DEFAULT '0',
  `minMoneyLoot` int unsigned NOT NULL DEFAULT '0',
  `maxMoneyLoot` int unsigned NOT NULL DEFAULT '0',
  `flagsCustom` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`),
  KEY `idx_name` (`name`(250)),
  KEY `items_index` (`class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item System';

CREATE TABLE IF NOT EXISTS `item_template_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itembagfamily_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itemdisplayinfo_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ModelName_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ModelName_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ModelTexture_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ModelTexture_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `InventoryIcon_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `InventoryIcon_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `GeosetGroup_1` int NOT NULL DEFAULT '0',
  `GeosetGroup_2` int NOT NULL DEFAULT '0',
  `GeosetGroup_3` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `SpellVisualID` int NOT NULL DEFAULT '0',
  `GroupSoundIndex` int NOT NULL DEFAULT '0',
  `HelmetGeosetVis_1` int NOT NULL DEFAULT '0',
  `HelmetGeosetVis_2` int NOT NULL DEFAULT '0',
  `Texture_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_3` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_4` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_5` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_6` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_7` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_8` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ItemVisual` int NOT NULL DEFAULT '0',
  `ParticleColorID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itemextendedcost_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `HonorPoints` int NOT NULL DEFAULT '0',
  `ArenaPoints` int NOT NULL DEFAULT '0',
  `ArenaBracket` int NOT NULL DEFAULT '0',
  `ItemID_1` int NOT NULL DEFAULT '0',
  `ItemID_2` int NOT NULL DEFAULT '0',
  `ItemID_3` int NOT NULL DEFAULT '0',
  `ItemID_4` int NOT NULL DEFAULT '0',
  `ItemID_5` int NOT NULL DEFAULT '0',
  `ItemCount_1` int NOT NULL DEFAULT '0',
  `ItemCount_2` int NOT NULL DEFAULT '0',
  `ItemCount_3` int NOT NULL DEFAULT '0',
  `ItemCount_4` int NOT NULL DEFAULT '0',
  `ItemCount_5` int NOT NULL DEFAULT '0',
  `RequiredArenaRating` int NOT NULL DEFAULT '0',
  `ItemPurchaseGroup` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itemlimitcategory_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Quantity` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itemrandomproperties_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Enchantment_1` int NOT NULL DEFAULT '0',
  `Enchantment_2` int NOT NULL DEFAULT '0',
  `Enchantment_3` int NOT NULL DEFAULT '0',
  `Enchantment_4` int NOT NULL DEFAULT '0',
  `Enchantment_5` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itemrandomsuffix_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `InternalName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Enchantment_1` int NOT NULL DEFAULT '0',
  `Enchantment_2` int NOT NULL DEFAULT '0',
  `Enchantment_3` int NOT NULL DEFAULT '0',
  `Enchantment_4` int NOT NULL DEFAULT '0',
  `Enchantment_5` int NOT NULL DEFAULT '0',
  `AllocationPct_1` int NOT NULL DEFAULT '0',
  `AllocationPct_2` int NOT NULL DEFAULT '0',
  `AllocationPct_3` int NOT NULL DEFAULT '0',
  `AllocationPct_4` int NOT NULL DEFAULT '0',
  `AllocationPct_5` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `itemset_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `ItemID_1` int NOT NULL DEFAULT '0',
  `ItemID_2` int NOT NULL DEFAULT '0',
  `ItemID_3` int NOT NULL DEFAULT '0',
  `ItemID_4` int NOT NULL DEFAULT '0',
  `ItemID_5` int NOT NULL DEFAULT '0',
  `ItemID_6` int NOT NULL DEFAULT '0',
  `ItemID_7` int NOT NULL DEFAULT '0',
  `ItemID_8` int NOT NULL DEFAULT '0',
  `ItemID_9` int NOT NULL DEFAULT '0',
  `ItemID_10` int NOT NULL DEFAULT '0',
  `ItemID_11` int NOT NULL DEFAULT '0',
  `ItemID_12` int NOT NULL DEFAULT '0',
  `ItemID_13` int NOT NULL DEFAULT '0',
  `ItemID_14` int NOT NULL DEFAULT '0',
  `ItemID_15` int NOT NULL DEFAULT '0',
  `ItemID_16` int NOT NULL DEFAULT '0',
  `ItemID_17` int NOT NULL DEFAULT '0',
  `SetSpellID_1` int NOT NULL DEFAULT '0',
  `SetSpellID_2` int NOT NULL DEFAULT '0',
  `SetSpellID_3` int NOT NULL DEFAULT '0',
  `SetSpellID_4` int NOT NULL DEFAULT '0',
  `SetSpellID_5` int NOT NULL DEFAULT '0',
  `SetSpellID_6` int NOT NULL DEFAULT '0',
  `SetSpellID_7` int NOT NULL DEFAULT '0',
  `SetSpellID_8` int NOT NULL DEFAULT '0',
  `SetThreshold_1` int NOT NULL DEFAULT '0',
  `SetThreshold_2` int NOT NULL DEFAULT '0',
  `SetThreshold_3` int NOT NULL DEFAULT '0',
  `SetThreshold_4` int NOT NULL DEFAULT '0',
  `SetThreshold_5` int NOT NULL DEFAULT '0',
  `SetThreshold_6` int NOT NULL DEFAULT '0',
  `SetThreshold_7` int NOT NULL DEFAULT '0',
  `SetThreshold_8` int NOT NULL DEFAULT '0',
  `RequiredSkill` int NOT NULL DEFAULT '0',
  `RequiredSkillRank` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lfg_dungeon_rewards` (
  `dungeonId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Dungeon entry from dbc',
  `maxLevel` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Max level at which this reward is rewarded',
  `firstQuestId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest id with rewards for first dungeon this day',
  `otherQuestId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Quest id with rewards for Nth dungeon this day',
  PRIMARY KEY (`dungeonId`,`maxLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lfg_dungeon_template` (
  `dungeonId` int unsigned NOT NULL DEFAULT '0' COMMENT 'Unique id from LFGDungeons.dbc',
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`dungeonId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lfgdungeons_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_Unk` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `MinLevel` int NOT NULL DEFAULT '0',
  `MaxLevel` int NOT NULL DEFAULT '0',
  `Target_Level` int NOT NULL DEFAULT '0',
  `Target_Level_Min` int NOT NULL DEFAULT '0',
  `Target_Level_Max` int NOT NULL DEFAULT '0',
  `MapID` int NOT NULL DEFAULT '0',
  `Difficulty` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `TypeID` int NOT NULL DEFAULT '0',
  `Faction` int NOT NULL DEFAULT '0',
  `TextureFilename` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `ExpansionLevel` int NOT NULL DEFAULT '0',
  `Order_Index` int NOT NULL DEFAULT '0',
  `Group_Id` int NOT NULL DEFAULT '0',
  `Description_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_Unk` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `light_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ContinentID` int NOT NULL DEFAULT '0',
  `X` float NOT NULL DEFAULT '0',
  `Y` float NOT NULL DEFAULT '0',
  `Z` float NOT NULL DEFAULT '0',
  `FalloffStart` float NOT NULL DEFAULT '0',
  `FalloffEnd` float NOT NULL DEFAULT '0',
  `LightParamsID_1` int NOT NULL DEFAULT '0',
  `LightParamsID_2` int NOT NULL DEFAULT '0',
  `LightParamsID_3` int NOT NULL DEFAULT '0',
  `LightParamsID_4` int NOT NULL DEFAULT '0',
  `LightParamsID_5` int NOT NULL DEFAULT '0',
  `LightParamsID_6` int NOT NULL DEFAULT '0',
  `LightParamsID_7` int NOT NULL DEFAULT '0',
  `LightParamsID_8` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `linked_respawn` (
  `guid` int unsigned NOT NULL COMMENT 'dependent creature',
  `linkedGuid` int unsigned NOT NULL COMMENT 'master creature',
  `linkType` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`,`linkType`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature Respawn Link System';

CREATE TABLE IF NOT EXISTS `liquidtype_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Flags` int NOT NULL DEFAULT '0',
  `Type` int NOT NULL DEFAULT '0',
  `SoundID` int NOT NULL DEFAULT '0',
  `SpellID` int NOT NULL DEFAULT '0',
  `MaxDarkenDepth` float NOT NULL DEFAULT '0',
  `FogDarkenintensity` float NOT NULL DEFAULT '0',
  `AmbDarkenintensity` float NOT NULL DEFAULT '0',
  `DirDarkenintensity` float NOT NULL DEFAULT '0',
  `LightID` int NOT NULL DEFAULT '0',
  `ParticleScale` float NOT NULL DEFAULT '0',
  `ParticleMovement` int NOT NULL DEFAULT '0',
  `ParticleTexSlots` int NOT NULL DEFAULT '0',
  `MaterialID` int NOT NULL DEFAULT '0',
  `Texture_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_3` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_4` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_5` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Texture_6` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Color_1` int NOT NULL DEFAULT '0',
  `Color_2` int NOT NULL DEFAULT '0',
  `Float_1` float NOT NULL DEFAULT '0',
  `Float_2` float NOT NULL DEFAULT '0',
  `Float_3` float NOT NULL DEFAULT '0',
  `Float_4` float NOT NULL DEFAULT '0',
  `Float_5` float NOT NULL DEFAULT '0',
  `Float_6` float NOT NULL DEFAULT '0',
  `Float_7` float NOT NULL DEFAULT '0',
  `Float_8` float NOT NULL DEFAULT '0',
  `Float_9` float NOT NULL DEFAULT '0',
  `Float_10` float NOT NULL DEFAULT '0',
  `Float_11` float NOT NULL DEFAULT '0',
  `Float_12` float NOT NULL DEFAULT '0',
  `Float_13` float NOT NULL DEFAULT '0',
  `Float_14` float NOT NULL DEFAULT '0',
  `Float_15` float NOT NULL DEFAULT '0',
  `Float_16` float NOT NULL DEFAULT '0',
  `Float_17` float NOT NULL DEFAULT '0',
  `Float_18` float NOT NULL DEFAULT '0',
  `Int_1` int NOT NULL DEFAULT '0',
  `Int_2` int NOT NULL DEFAULT '0',
  `Int_3` int NOT NULL DEFAULT '0',
  `Int_4` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `lock_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Type_1` int NOT NULL DEFAULT '0',
  `Type_2` int NOT NULL DEFAULT '0',
  `Type_3` int NOT NULL DEFAULT '0',
  `Type_4` int NOT NULL DEFAULT '0',
  `Type_5` int NOT NULL DEFAULT '0',
  `Type_6` int NOT NULL DEFAULT '0',
  `Type_7` int NOT NULL DEFAULT '0',
  `Type_8` int NOT NULL DEFAULT '0',
  `Index_1` int NOT NULL DEFAULT '0',
  `Index_2` int NOT NULL DEFAULT '0',
  `Index_3` int NOT NULL DEFAULT '0',
  `Index_4` int NOT NULL DEFAULT '0',
  `Index_5` int NOT NULL DEFAULT '0',
  `Index_6` int NOT NULL DEFAULT '0',
  `Index_7` int NOT NULL DEFAULT '0',
  `Index_8` int NOT NULL DEFAULT '0',
  `Skill_1` int NOT NULL DEFAULT '0',
  `Skill_2` int NOT NULL DEFAULT '0',
  `Skill_3` int NOT NULL DEFAULT '0',
  `Skill_4` int NOT NULL DEFAULT '0',
  `Skill_5` int NOT NULL DEFAULT '0',
  `Skill_6` int NOT NULL DEFAULT '0',
  `Skill_7` int NOT NULL DEFAULT '0',
  `Skill_8` int NOT NULL DEFAULT '0',
  `Action_1` int NOT NULL DEFAULT '0',
  `Action_2` int NOT NULL DEFAULT '0',
  `Action_3` int NOT NULL DEFAULT '0',
  `Action_4` int NOT NULL DEFAULT '0',
  `Action_5` int NOT NULL DEFAULT '0',
  `Action_6` int NOT NULL DEFAULT '0',
  `Action_7` int NOT NULL DEFAULT '0',
  `Action_8` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mail_level_reward` (
  `level` tinyint unsigned NOT NULL DEFAULT '0',
  `raceMask` int unsigned NOT NULL DEFAULT '0',
  `mailTemplateId` int unsigned NOT NULL DEFAULT '0',
  `senderEntry` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`level`,`raceMask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mail System';

CREATE TABLE IF NOT EXISTS `mail_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `mailtemplate_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Subject_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Subject_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Body_Lang_enUS` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_enGB` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_koKR` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_frFR` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_deDE` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_enCN` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_zhCN` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_enTW` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_zhTW` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_esES` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_esMX` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_ruRU` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_ptPT` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_ptBR` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_itIT` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Body_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `map_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Directory` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `InstanceType` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `PVP` int NOT NULL DEFAULT '0',
  `MapName_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `AreaTableID` int NOT NULL DEFAULT '0',
  `MapDescription0_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription0_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapDescription0_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `MapDescription1_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `MapDescription1_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MapDescription1_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `LoadingScreenID` int NOT NULL DEFAULT '0',
  `MinimapIconScale` float NOT NULL DEFAULT '0',
  `CorpseMapID` int NOT NULL DEFAULT '0',
  `CorpseX` float NOT NULL DEFAULT '0',
  `CorpseY` float NOT NULL DEFAULT '0',
  `TimeOfDayOverride` int NOT NULL DEFAULT '0',
  `ExpansionID` int NOT NULL DEFAULT '0',
  `RaidOffset` int NOT NULL DEFAULT '0',
  `MaxPlayers` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mapdifficulty_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MapID` int NOT NULL DEFAULT '0',
  `Difficulty` int NOT NULL DEFAULT '0',
  `Message_Lang_enUS` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_enGB` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_koKR` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_frFR` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_deDE` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_enCN` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_zhCN` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_enTW` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_zhTW` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_esES` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_esMX` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_ruRU` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_ptPT` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_ptBR` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_itIT` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Message_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `RaidDuration` int NOT NULL DEFAULT '0',
  `MaxPlayers` int NOT NULL DEFAULT '0',
  `Difficultystring` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `milling_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `mod_auctionhousebot` (
  `auctionhouse` int NOT NULL DEFAULT '0' COMMENT 'mapID of the auctionhouse.',
  `name` char(25) DEFAULT NULL COMMENT 'Text name of the auctionhouse.',
  `minitems` int DEFAULT '0' COMMENT 'This is the minimum number of items you want to keep in the auction house. a 0 here will make it the same as the maximum.',
  `maxitems` int DEFAULT '0' COMMENT 'This is the number of items you want to keep in the auction house.',
  `percentgreytradegoods` int DEFAULT '0' COMMENT 'Sets the percentage of the Grey Trade Goods auction items',
  `percentwhitetradegoods` int DEFAULT '27' COMMENT 'Sets the percentage of the White Trade Goods auction items',
  `percentgreentradegoods` int DEFAULT '12' COMMENT 'Sets the percentage of the Green Trade Goods auction items',
  `percentbluetradegoods` int DEFAULT '10' COMMENT 'Sets the percentage of the Blue Trade Goods auction items',
  `percentpurpletradegoods` int DEFAULT '1' COMMENT 'Sets the percentage of the Purple Trade Goods auction items',
  `percentorangetradegoods` int DEFAULT '0' COMMENT 'Sets the percentage of the Orange Trade Goods auction items',
  `percentyellowtradegoods` int DEFAULT '0' COMMENT 'Sets the percentage of the Yellow Trade Goods auction items',
  `percentgreyitems` int DEFAULT '0' COMMENT 'Sets the percentage of the non trade Grey auction items',
  `percentwhiteitems` int DEFAULT '10' COMMENT 'Sets the percentage of the non trade White auction items',
  `percentgreenitems` int DEFAULT '30' COMMENT 'Sets the percentage of the non trade Green auction items',
  `percentblueitems` int DEFAULT '8' COMMENT 'Sets the percentage of the non trade Blue auction items',
  `percentpurpleitems` int DEFAULT '2' COMMENT 'Sets the percentage of the non trade Purple auction items',
  `percentorangeitems` int DEFAULT '0' COMMENT 'Sets the percentage of the non trade Orange auction items',
  `percentyellowitems` int DEFAULT '0' COMMENT 'Sets the percentage of the non trade Yellow auction items',
  `minpricegrey` int DEFAULT '100' COMMENT 'Minimum price of Grey items (percentage).',
  `maxpricegrey` int DEFAULT '150' COMMENT 'Maximum price of Grey items (percentage).',
  `minpricewhite` int DEFAULT '150' COMMENT 'Minimum price of White items (percentage).',
  `maxpricewhite` int DEFAULT '250' COMMENT 'Maximum price of White items (percentage).',
  `minpricegreen` int DEFAULT '800' COMMENT 'Minimum price of Green items (percentage).',
  `maxpricegreen` int DEFAULT '1400' COMMENT 'Maximum price of Green items (percentage).',
  `minpriceblue` int DEFAULT '1250' COMMENT 'Minimum price of Blue items (percentage).',
  `maxpriceblue` int DEFAULT '1750' COMMENT 'Maximum price of Blue items (percentage).',
  `minpricepurple` int DEFAULT '2250' COMMENT 'Minimum price of Purple items (percentage).',
  `maxpricepurple` int DEFAULT '4550' COMMENT 'Maximum price of Purple items (percentage).',
  `minpriceorange` int DEFAULT '3250' COMMENT 'Minimum price of Orange items (percentage).',
  `maxpriceorange` int DEFAULT '5550' COMMENT 'Maximum price of Orange items (percentage).',
  `minpriceyellow` int DEFAULT '5250' COMMENT 'Minimum price of Yellow items (percentage).',
  `maxpriceyellow` int DEFAULT '6550' COMMENT 'Maximum price of Yellow items (percentage).',
  `minbidpricegrey` int DEFAULT '70' COMMENT 'Starting bid price of Grey items as a percentage of the randomly chosen buyout price. Default: 70',
  `maxbidpricegrey` int DEFAULT '100' COMMENT 'Starting bid price of Grey items as a percentage of the randomly chosen buyout price. Default: 100',
  `minbidpricewhite` int DEFAULT '70' COMMENT 'Starting bid price of White items as a percentage of the randomly chosen buyout price. Default: 70',
  `maxbidpricewhite` int DEFAULT '100' COMMENT 'Starting bid price of White items as a percentage of the randomly chosen buyout price. Default: 100',
  `minbidpricegreen` int DEFAULT '80' COMMENT 'Starting bid price of Green items as a percentage of the randomly chosen buyout price. Default: 80',
  `maxbidpricegreen` int DEFAULT '100' COMMENT 'Starting bid price of Green items as a percentage of the randomly chosen buyout price. Default: 100',
  `minbidpriceblue` int DEFAULT '75' COMMENT 'Starting bid price of Blue items as a percentage of the randomly chosen buyout price. Default: 75',
  `maxbidpriceblue` int DEFAULT '100' COMMENT 'Starting bid price of Blue items as a percentage of the randomly chosen buyout price. Default: 100',
  `minbidpricepurple` int DEFAULT '80' COMMENT 'Starting bid price of Purple items as a percentage of the randomly chosen buyout price. Default: 80',
  `maxbidpricepurple` int DEFAULT '100' COMMENT 'Starting bid price of Purple items as a percentage of the randomly chosen buyout price. Default: 100',
  `minbidpriceorange` int DEFAULT '80' COMMENT 'Starting bid price of Orange items as a percentage of the randomly chosen buyout price. Default: 80',
  `maxbidpriceorange` int DEFAULT '100' COMMENT 'Starting bid price of Orange items as a percentage of the randomly chosen buyout price. Default: 100',
  `minbidpriceyellow` int DEFAULT '80' COMMENT 'Starting bid price of Yellow items as a percentage of the randomly chosen buyout price. Default: 80',
  `maxbidpriceyellow` int DEFAULT '100' COMMENT 'Starting bid price of Yellow items as a percentage of the randomly chosen buyout price. Default: 100',
  `maxstackgrey` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `maxstackwhite` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `maxstackgreen` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `maxstackblue` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `maxstackpurple` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `maxstackorange` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `maxstackyellow` int DEFAULT '0' COMMENT 'Stack size limits for item qualities - a value of 0 will disable a maximum stack size for that quality, which will allow the bot to create items in stack as large as the item allows.',
  `buyerpricegrey` int DEFAULT '1' COMMENT 'Multiplier to vendorprice when buying grey items from auctionhouse',
  `buyerpricewhite` int DEFAULT '3' COMMENT 'Multiplier to vendorprice when buying white items from auctionhouse',
  `buyerpricegreen` int DEFAULT '5' COMMENT 'Multiplier to vendorprice when buying green items from auctionhouse',
  `buyerpriceblue` int DEFAULT '12' COMMENT 'Multiplier to vendorprice when buying blue items from auctionhouse',
  `buyerpricepurple` int DEFAULT '15' COMMENT 'Multiplier to vendorprice when buying purple items from auctionhouse',
  `buyerpriceorange` int DEFAULT '20' COMMENT 'Multiplier to vendorprice when buying orange items from auctionhouse',
  `buyerpriceyellow` int DEFAULT '22' COMMENT 'Multiplier to vendorprice when buying yellow items from auctionhouse',
  `buyerbiddinginterval` int DEFAULT '1' COMMENT 'Interval how frequently AHB bids on each AH. Time in minutes',
  `buyerbidsperinterval` int DEFAULT '1' COMMENT 'number of bids to put in per bidding interval',
  PRIMARY KEY (`auctionhouse`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `mod_auctionhousebot_disabled_items` (
  `item` mediumint unsigned NOT NULL,
  PRIMARY KEY (`item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `module_string` (
  `module` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'module dir name, eg mod-cfbg',
  `id` int unsigned NOT NULL,
  `string` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`module`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `module_string_locale` (
  `module` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Corresponds to an existing entry in module_string',
  `id` int unsigned NOT NULL COMMENT 'Corresponds to an existing entry in module_string',
  `locale` enum('koKR','frFR','deDE','zhCN','zhTW','esES','esMX','ruRU') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `string` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`module`,`id`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `movie_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Filename` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Volume` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `namesprofanity_dbc` (
  `ID` int unsigned NOT NULL,
  `Pattern` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `LanguagueID` tinyint NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `namesreserved_dbc` (
  `ID` int unsigned NOT NULL,
  `Pattern` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `LanguagueID` tinyint NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `npc_spellclick_spells` (
  `npc_entry` int unsigned NOT NULL COMMENT 'reference to creature_template',
  `spell_id` int unsigned NOT NULL COMMENT 'spell which should be casted ',
  `cast_flags` tinyint unsigned NOT NULL COMMENT 'first bit defines caster: 1=player, 0=creature; second bit defines target, same mapping as caster bit',
  `user_type` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'relation with summoner: 0-no 1-friendly 2-raid 3-party player can click',
  PRIMARY KEY (`npc_entry`,`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `npc_text` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `text0_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text0_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID0` int NOT NULL DEFAULT '0',
  `lang0` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability0` float NOT NULL DEFAULT '0',
  `em0_0` smallint unsigned NOT NULL DEFAULT '0',
  `em0_1` smallint unsigned NOT NULL DEFAULT '0',
  `em0_2` smallint unsigned NOT NULL DEFAULT '0',
  `em0_3` smallint unsigned NOT NULL DEFAULT '0',
  `em0_4` smallint unsigned NOT NULL DEFAULT '0',
  `em0_5` smallint unsigned NOT NULL DEFAULT '0',
  `text1_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text1_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID1` int NOT NULL DEFAULT '0',
  `lang1` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability1` float NOT NULL DEFAULT '0',
  `em1_0` smallint unsigned NOT NULL DEFAULT '0',
  `em1_1` smallint unsigned NOT NULL DEFAULT '0',
  `em1_2` smallint unsigned NOT NULL DEFAULT '0',
  `em1_3` smallint unsigned NOT NULL DEFAULT '0',
  `em1_4` smallint unsigned NOT NULL DEFAULT '0',
  `em1_5` smallint unsigned NOT NULL DEFAULT '0',
  `text2_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text2_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID2` int NOT NULL DEFAULT '0',
  `lang2` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability2` float NOT NULL DEFAULT '0',
  `em2_0` smallint unsigned NOT NULL DEFAULT '0',
  `em2_1` smallint unsigned NOT NULL DEFAULT '0',
  `em2_2` smallint unsigned NOT NULL DEFAULT '0',
  `em2_3` smallint unsigned NOT NULL DEFAULT '0',
  `em2_4` smallint unsigned NOT NULL DEFAULT '0',
  `em2_5` smallint unsigned NOT NULL DEFAULT '0',
  `text3_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text3_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID3` int NOT NULL DEFAULT '0',
  `lang3` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability3` float NOT NULL DEFAULT '0',
  `em3_0` smallint unsigned NOT NULL DEFAULT '0',
  `em3_1` smallint unsigned NOT NULL DEFAULT '0',
  `em3_2` smallint unsigned NOT NULL DEFAULT '0',
  `em3_3` smallint unsigned NOT NULL DEFAULT '0',
  `em3_4` smallint unsigned NOT NULL DEFAULT '0',
  `em3_5` smallint unsigned NOT NULL DEFAULT '0',
  `text4_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text4_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID4` int NOT NULL DEFAULT '0',
  `lang4` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability4` float NOT NULL DEFAULT '0',
  `em4_0` smallint unsigned NOT NULL DEFAULT '0',
  `em4_1` smallint unsigned NOT NULL DEFAULT '0',
  `em4_2` smallint unsigned NOT NULL DEFAULT '0',
  `em4_3` smallint unsigned NOT NULL DEFAULT '0',
  `em4_4` smallint unsigned NOT NULL DEFAULT '0',
  `em4_5` smallint unsigned NOT NULL DEFAULT '0',
  `text5_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text5_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID5` int NOT NULL DEFAULT '0',
  `lang5` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability5` float NOT NULL DEFAULT '0',
  `em5_0` smallint unsigned NOT NULL DEFAULT '0',
  `em5_1` smallint unsigned NOT NULL DEFAULT '0',
  `em5_2` smallint unsigned NOT NULL DEFAULT '0',
  `em5_3` smallint unsigned NOT NULL DEFAULT '0',
  `em5_4` smallint unsigned NOT NULL DEFAULT '0',
  `em5_5` smallint unsigned NOT NULL DEFAULT '0',
  `text6_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text6_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID6` int NOT NULL DEFAULT '0',
  `lang6` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability6` float NOT NULL DEFAULT '0',
  `em6_0` smallint unsigned NOT NULL DEFAULT '0',
  `em6_1` smallint unsigned NOT NULL DEFAULT '0',
  `em6_2` smallint unsigned NOT NULL DEFAULT '0',
  `em6_3` smallint unsigned NOT NULL DEFAULT '0',
  `em6_4` smallint unsigned NOT NULL DEFAULT '0',
  `em6_5` smallint unsigned NOT NULL DEFAULT '0',
  `text7_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `text7_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `BroadcastTextID7` int NOT NULL DEFAULT '0',
  `lang7` tinyint unsigned NOT NULL DEFAULT '0',
  `Probability7` float NOT NULL DEFAULT '0',
  `em7_0` smallint unsigned NOT NULL DEFAULT '0',
  `em7_1` smallint unsigned NOT NULL DEFAULT '0',
  `em7_2` smallint unsigned NOT NULL DEFAULT '0',
  `em7_3` smallint unsigned NOT NULL DEFAULT '0',
  `em7_4` smallint unsigned NOT NULL DEFAULT '0',
  `em7_5` smallint unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `npc_text_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `Locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Text0_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text0_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text1_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text1_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text2_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text2_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text3_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text3_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text4_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text4_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text5_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text5_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text6_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text6_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text7_0` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Text7_1` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`ID`,`Locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `npc_vendor` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `slot` smallint NOT NULL DEFAULT '0',
  `item` int NOT NULL DEFAULT '0',
  `maxcount` tinyint unsigned NOT NULL DEFAULT '0',
  `incrtime` int unsigned NOT NULL DEFAULT '0',
  `ExtendedCost` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`entry`,`item`,`ExtendedCost`),
  KEY `slot` (`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Npc System';

CREATE TABLE IF NOT EXISTS `outdoorpvp_template` (
  `TypeId` tinyint unsigned NOT NULL,
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`TypeId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OutdoorPvP Templates';

CREATE TABLE IF NOT EXISTS `overridespelldata_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Spells_1` int NOT NULL DEFAULT '0',
  `Spells_2` int NOT NULL DEFAULT '0',
  `Spells_3` int NOT NULL DEFAULT '0',
  `Spells_4` int NOT NULL DEFAULT '0',
  `Spells_5` int NOT NULL DEFAULT '0',
  `Spells_6` int NOT NULL DEFAULT '0',
  `Spells_7` int NOT NULL DEFAULT '0',
  `Spells_8` int NOT NULL DEFAULT '0',
  `Spells_9` int NOT NULL DEFAULT '0',
  `Spells_10` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `page_text` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `Text` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `NextPageID` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Item System';

CREATE TABLE IF NOT EXISTS `page_text_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Text` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pet_levelstats` (
  `creature_entry` int unsigned NOT NULL,
  `level` tinyint unsigned NOT NULL,
  `hp` int unsigned NOT NULL DEFAULT '0',
  `mana` int unsigned NOT NULL DEFAULT '0',
  `armor` int unsigned NOT NULL DEFAULT '0',
  `str` int unsigned NOT NULL DEFAULT '0',
  `agi` int unsigned NOT NULL DEFAULT '0',
  `sta` int unsigned NOT NULL DEFAULT '0',
  `inte` int unsigned NOT NULL DEFAULT '0',
  `spi` int unsigned NOT NULL DEFAULT '0',
  `min_dmg` int unsigned NOT NULL DEFAULT '0',
  `max_dmg` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`creature_entry`,`level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci PACK_KEYS=0 COMMENT='Stores pet levels stats.';

CREATE TABLE IF NOT EXISTS `pet_name_generation` (
  `id` int unsigned NOT NULL,
  `word` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `entry` int unsigned NOT NULL DEFAULT '0',
  `half` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pet_name_generation_locale` (
  `ID` int unsigned NOT NULL,
  `Locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Word` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Half` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`,`Locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pickpocketing_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `player_class_stats` (
  `Class` tinyint unsigned NOT NULL,
  `Level` tinyint unsigned NOT NULL,
  `BaseHP` int unsigned NOT NULL DEFAULT '1',
  `BaseMana` int unsigned NOT NULL DEFAULT '1',
  `Strength` int unsigned NOT NULL DEFAULT '0',
  `Agility` int unsigned NOT NULL DEFAULT '0',
  `Stamina` int unsigned NOT NULL DEFAULT '0',
  `Intellect` int unsigned NOT NULL DEFAULT '0',
  `Spirit` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`Class`,`Level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci PACK_KEYS=0 COMMENT='Stores levels stats.';

CREATE TABLE IF NOT EXISTS `player_factionchange_achievement` (
  `alliance_id` int unsigned NOT NULL,
  `alliance_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `horde_id` int unsigned NOT NULL,
  `horde_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`alliance_id`,`horde_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_factionchange_items` (
  `alliance_id` int unsigned NOT NULL,
  `alliance_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `horde_id` int unsigned NOT NULL,
  `horde_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`alliance_id`,`horde_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_factionchange_quests` (
  `alliance_id` int unsigned NOT NULL,
  `horde_id` int unsigned NOT NULL,
  PRIMARY KEY (`alliance_id`,`horde_id`),
  UNIQUE KEY `alliance_uniq` (`alliance_id`),
  UNIQUE KEY `horde_uniq` (`horde_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_factionchange_reputations` (
  `alliance_id` int unsigned NOT NULL,
  `alliance_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `horde_id` int unsigned NOT NULL,
  `horde_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`alliance_id`,`horde_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_factionchange_spells` (
  `alliance_id` int unsigned NOT NULL,
  `alliance_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `horde_id` int unsigned NOT NULL,
  `horde_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`alliance_id`,`horde_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_factionchange_titles` (
  `alliance_id` int NOT NULL,
  `alliance_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `horde_id` int NOT NULL,
  `horde_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`alliance_id`,`horde_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `player_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `player_race_stats` (
  `Race` tinyint unsigned NOT NULL,
  `Strength` int NOT NULL DEFAULT '0',
  `Agility` int NOT NULL DEFAULT '0',
  `Stamina` int NOT NULL DEFAULT '0',
  `Intellect` int NOT NULL DEFAULT '0',
  `Spirit` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Race`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci PACK_KEYS=0 COMMENT='Stores race stats.';

CREATE TABLE IF NOT EXISTS `player_shapeshift_model` (
  `ShapeshiftID` tinyint unsigned NOT NULL,
  `RaceID` tinyint unsigned NOT NULL,
  `CustomizationID` tinyint unsigned NOT NULL,
  `GenderID` tinyint unsigned NOT NULL,
  `ModelID` int unsigned NOT NULL,
  PRIMARY KEY (`ShapeshiftID`,`RaceID`,`CustomizationID`,`GenderID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci PACK_KEYS=0;

CREATE TABLE IF NOT EXISTS `player_totem_model` (
  `TotemID` tinyint unsigned NOT NULL,
  `RaceID` tinyint unsigned NOT NULL,
  `ModelID` int unsigned NOT NULL,
  PRIMARY KEY (`TotemID`,`RaceID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci PACK_KEYS=0;

CREATE TABLE IF NOT EXISTS `player_xp_for_level` (
  `Level` tinyint unsigned NOT NULL,
  `Experience` int unsigned NOT NULL,
  PRIMARY KEY (`Level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playercreateinfo` (
  `race` tinyint unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `map` smallint unsigned NOT NULL DEFAULT '0',
  `zone` int unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`race`,`class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playercreateinfo_action` (
  `race` tinyint unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `button` smallint unsigned NOT NULL DEFAULT '0',
  `action` int unsigned NOT NULL DEFAULT '0',
  `type` smallint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`race`,`class`,`button`),
  KEY `playercreateinfo_race_class_index` (`race`,`class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playercreateinfo_cast_spell` (
  `raceMask` int unsigned NOT NULL DEFAULT '0',
  `classMask` int unsigned NOT NULL DEFAULT '0',
  `spell` int unsigned NOT NULL DEFAULT '0',
  `note` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playercreateinfo_item` (
  `race` tinyint unsigned NOT NULL DEFAULT '0',
  `class` tinyint unsigned NOT NULL DEFAULT '0',
  `itemid` int unsigned NOT NULL DEFAULT '0',
  `amount` int NOT NULL DEFAULT '1',
  `Note` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`race`,`class`,`itemid`),
  KEY `playercreateinfo_race_class_index` (`race`,`class`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playercreateinfo_skills` (
  `raceMask` int unsigned NOT NULL,
  `classMask` int unsigned NOT NULL,
  `skill` smallint unsigned NOT NULL,
  `rank` smallint unsigned NOT NULL DEFAULT '0',
  `comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`raceMask`,`classMask`,`skill`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `playercreateinfo_spell_custom` (
  `racemask` int unsigned NOT NULL DEFAULT '0',
  `classmask` int unsigned NOT NULL DEFAULT '0',
  `Spell` int unsigned NOT NULL DEFAULT '0',
  `Note` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`racemask`,`classmask`,`Spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `points_of_interest` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `PositionX` float NOT NULL DEFAULT '0',
  `PositionY` float NOT NULL DEFAULT '0',
  `Icon` int unsigned NOT NULL DEFAULT '0',
  `Flags` int unsigned NOT NULL DEFAULT '0',
  `Importance` int unsigned NOT NULL DEFAULT '0',
  `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `points_of_interest_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pool_creature` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `pool_entry` int unsigned NOT NULL DEFAULT '0',
  `chance` float NOT NULL DEFAULT '0',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`guid`),
  KEY `idx_guid` (`guid`),
  CONSTRAINT `pool_creature_chk_1` CHECK ((`chance` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pool_gameobject` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `pool_entry` int unsigned NOT NULL DEFAULT '0',
  `chance` float NOT NULL DEFAULT '0',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`guid`),
  KEY `idx_guid` (`guid`),
  CONSTRAINT `pool_gameobject_chk_1` CHECK ((`chance` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pool_pool` (
  `pool_id` int unsigned NOT NULL DEFAULT '0',
  `mother_pool` int unsigned NOT NULL DEFAULT '0',
  `chance` float NOT NULL DEFAULT '0',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`pool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pool_quest` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `pool_entry` int unsigned NOT NULL DEFAULT '0',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`entry`),
  KEY `idx_guid` (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pool_template` (
  `entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Pool entry',
  `max_limit` int unsigned NOT NULL DEFAULT '0' COMMENT 'Max number of objects (0) is no limit',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //
CREATE PROCEDURE `PopulateHeirloomDefinitions`()
BEGIN
    INSERT IGNORE INTO dc_heirloom_definitions (item_id, name, slot, armor_type)
    SELECT 
        h.item_id,
        h.item_name,
        h.slot,
        h.armor_type
    FROM v_heirloom_items h
    WHERE h.item_id NOT IN (SELECT item_id FROM dc_heirloom_definitions);
    
    SELECT ROW_COUNT() AS heirlooms_added;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `PopulateMountDefinitions`()
BEGIN
    -- Insert mounts from item_template that aren't already defined
    INSERT IGNORE INTO dc_mount_definitions (spell_id, name, rarity, display_id, source)
    SELECT 
        m.spell_id,
        m.item_name,
        m.rarity,
        m.display_id,
        JSON_OBJECT('type', 'unknown', 'item_id', m.item_id)
    FROM v_mount_items m
    WHERE m.spell_id NOT IN (SELECT spell_id FROM dc_mount_definitions);
    
    SELECT ROW_COUNT() AS mounts_added;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `PopulateMountSourcesFromLoot`()
BEGIN
    -- Update mount sources from creature loot
    UPDATE dc_mount_definitions md
    JOIN (
        SELECT 
            mi.spell_id,
            JSON_OBJECT(
                'type', 'drop',
                -- Pick a representative boss for this spell_id.
                -- Aggregation avoids ONLY_FULL_GROUP_BY issues.
                'boss', MIN(ct.name),
                'dropRate', ROUND(MAX(clt.Chance), 1),
                'creature_entry', MIN(ct.entry)
            ) AS source_json
        FROM v_mount_items mi
        JOIN creature_loot_template clt ON clt.Item = mi.item_id
        JOIN creature_template ct ON ct.lootid = clt.Entry
        WHERE ct.rank >= 3 OR (ct.unit_flags & 32768) > 0  -- Boss flag
        GROUP BY mi.spell_id
    ) src ON md.spell_id = src.spell_id
    SET md.source = src.source_json
    WHERE md.source IS NULL OR JSON_EXTRACT(md.source, '$.type') = 'unknown';
    
    -- Update mount sources from vendors
    UPDATE dc_mount_definitions md
    JOIN (
        SELECT 
            mi.spell_id,
            JSON_OBJECT(
                'type', 'vendor',
                -- Pick a representative vendor for this spell_id.
                'npc', MIN(ct.name),
                'cost', MIN(i.BuyPrice)
            ) AS source_json
        FROM v_mount_items mi
        JOIN item_template i ON i.entry = mi.item_id
        JOIN npc_vendor nv ON nv.item = mi.item_id
        JOIN creature_template ct ON ct.entry = nv.entry
        GROUP BY mi.spell_id
    ) src ON md.spell_id = src.spell_id
    SET md.source = src.source_json
    WHERE md.source IS NULL OR JSON_EXTRACT(md.source, '$.type') = 'unknown';
    
    SELECT 'Mount sources updated' AS status;
END//
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `PopulatePetDefinitions`()
BEGIN
    INSERT IGNORE INTO dc_pet_definitions (pet_entry, name, pet_spell_id, rarity, display_id, source)
    SELECT 
        p.item_id,
        p.item_name,
        p.spell_id,
        p.rarity,
        p.display_id,
        JSON_OBJECT('type', 'unknown', 'item_id', p.item_id)
    FROM v_pet_items p
    WHERE p.item_id NOT IN (SELECT pet_entry FROM dc_pet_definitions);
    
    SELECT ROW_COUNT() AS pets_added;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS `powerdisplay_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ActualType` int NOT NULL DEFAULT '0',
  `GlobalstringBaseTag` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Red` tinyint unsigned NOT NULL DEFAULT '0',
  `Green` tinyint unsigned NOT NULL DEFAULT '0',
  `Blue` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `prospecting_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `pvpdifficulty_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MapID` int NOT NULL DEFAULT '0',
  `RangeIndex` int NOT NULL DEFAULT '0',
  `MinLevel` int NOT NULL DEFAULT '0',
  `MaxLevel` int NOT NULL DEFAULT '0',
  `Difficulty` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_details` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `Emote1` smallint unsigned NOT NULL DEFAULT '0',
  `Emote2` smallint unsigned NOT NULL DEFAULT '0',
  `Emote3` smallint unsigned NOT NULL DEFAULT '0',
  `Emote4` smallint unsigned NOT NULL DEFAULT '0',
  `EmoteDelay1` int unsigned NOT NULL DEFAULT '0',
  `EmoteDelay2` int unsigned NOT NULL DEFAULT '0',
  `EmoteDelay3` int unsigned NOT NULL DEFAULT '0',
  `EmoteDelay4` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_greeting` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `GreetEmoteType` smallint unsigned NOT NULL DEFAULT '0',
  `GreetEmoteDelay` int unsigned NOT NULL DEFAULT '0',
  `Greeting` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_greeting_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Greeting` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`type`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_mail_sender` (
  `QuestId` int unsigned NOT NULL DEFAULT '0',
  `RewardMailSenderEntry` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`QuestId`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_money_reward` (
  `Level` int NOT NULL DEFAULT '0',
  `Money0` int NOT NULL DEFAULT '0',
  `Money1` int NOT NULL DEFAULT '0',
  `Money2` int NOT NULL DEFAULT '0',
  `Money3` int NOT NULL DEFAULT '0',
  `Money4` int NOT NULL DEFAULT '0',
  `Money5` int NOT NULL DEFAULT '0',
  `Money6` int NOT NULL DEFAULT '0',
  `Money7` int NOT NULL DEFAULT '0',
  `Money8` int NOT NULL DEFAULT '0',
  `Money9` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`Level`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_offer_reward` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `Emote1` smallint unsigned NOT NULL DEFAULT '0',
  `Emote2` smallint unsigned NOT NULL DEFAULT '0',
  `Emote3` smallint unsigned NOT NULL DEFAULT '0',
  `Emote4` smallint unsigned NOT NULL DEFAULT '0',
  `EmoteDelay1` int unsigned NOT NULL DEFAULT '0',
  `EmoteDelay2` int unsigned NOT NULL DEFAULT '0',
  `EmoteDelay3` int unsigned NOT NULL DEFAULT '0',
  `EmoteDelay4` int unsigned NOT NULL DEFAULT '0',
  `RewardText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_offer_reward_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `RewardText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_poi` (
  `QuestID` int unsigned NOT NULL DEFAULT '0',
  `id` int unsigned NOT NULL DEFAULT '0',
  `ObjectiveIndex` int NOT NULL DEFAULT '0',
  `MapID` int unsigned NOT NULL DEFAULT '0',
  `WorldMapAreaId` int unsigned NOT NULL DEFAULT '0',
  `Floor` int unsigned NOT NULL DEFAULT '0',
  `Priority` int unsigned NOT NULL DEFAULT '0',
  `Flags` int unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`QuestID`,`id`),
  KEY `idx` (`QuestID`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_poi_points` (
  `QuestID` int unsigned NOT NULL DEFAULT '0',
  `Idx1` int unsigned NOT NULL DEFAULT '0',
  `Idx2` int unsigned NOT NULL DEFAULT '0',
  `X` int NOT NULL DEFAULT '0',
  `Y` int NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`QuestID`,`Idx1`,`Idx2`),
  KEY `questId_id` (`QuestID`,`Idx1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_request_items` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `EmoteOnComplete` smallint unsigned NOT NULL DEFAULT '0',
  `EmoteOnIncomplete` smallint unsigned NOT NULL DEFAULT '0',
  `CompletionText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_request_items_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `CompletionText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_template` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `QuestType` tinyint unsigned NOT NULL DEFAULT '2',
  `QuestLevel` smallint NOT NULL DEFAULT '1',
  `MinLevel` tinyint unsigned NOT NULL DEFAULT '0',
  `QuestSortID` smallint NOT NULL DEFAULT '0',
  `QuestInfoID` smallint unsigned NOT NULL DEFAULT '0',
  `SuggestedGroupNum` tinyint unsigned NOT NULL DEFAULT '0',
  `RequiredFactionId1` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredFactionId2` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredFactionValue1` int NOT NULL DEFAULT '0',
  `RequiredFactionValue2` int NOT NULL DEFAULT '0',
  `RewardNextQuest` int unsigned NOT NULL DEFAULT '0',
  `RewardXPDifficulty` tinyint unsigned NOT NULL DEFAULT '0',
  `RewardMoney` int NOT NULL DEFAULT '0',
  `RewardMoneyDifficulty` int unsigned NOT NULL DEFAULT '0',
  `RewardDisplaySpell` int unsigned NOT NULL DEFAULT '0',
  `RewardSpell` int NOT NULL DEFAULT '0',
  `RewardHonor` int NOT NULL DEFAULT '0',
  `RewardKillHonor` float NOT NULL DEFAULT '0',
  `StartItem` int unsigned NOT NULL DEFAULT '0',
  `Flags` int unsigned NOT NULL DEFAULT '0',
  `RequiredPlayerKills` tinyint unsigned NOT NULL DEFAULT '0',
  `RewardItem1` int unsigned NOT NULL DEFAULT '0',
  `RewardAmount1` smallint unsigned NOT NULL DEFAULT '0',
  `RewardItem2` int unsigned NOT NULL DEFAULT '0',
  `RewardAmount2` smallint unsigned NOT NULL DEFAULT '0',
  `RewardItem3` int unsigned NOT NULL DEFAULT '0',
  `RewardAmount3` smallint unsigned NOT NULL DEFAULT '0',
  `RewardItem4` int unsigned NOT NULL DEFAULT '0',
  `RewardAmount4` smallint unsigned NOT NULL DEFAULT '0',
  `ItemDrop1` int unsigned NOT NULL DEFAULT '0',
  `ItemDropQuantity1` smallint unsigned NOT NULL DEFAULT '0',
  `ItemDrop2` int unsigned NOT NULL DEFAULT '0',
  `ItemDropQuantity2` smallint unsigned NOT NULL DEFAULT '0',
  `ItemDrop3` int unsigned NOT NULL DEFAULT '0',
  `ItemDropQuantity3` smallint unsigned NOT NULL DEFAULT '0',
  `ItemDrop4` int unsigned NOT NULL DEFAULT '0',
  `ItemDropQuantity4` smallint unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemID1` int unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemQuantity1` smallint unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemID2` int unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemQuantity2` smallint unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemID3` int unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemQuantity3` smallint unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemID4` int unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemQuantity4` smallint unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemID5` int unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemQuantity5` smallint unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemID6` int unsigned NOT NULL DEFAULT '0',
  `RewardChoiceItemQuantity6` smallint unsigned NOT NULL DEFAULT '0',
  `POIContinent` smallint unsigned NOT NULL DEFAULT '0',
  `POIx` float NOT NULL DEFAULT '0',
  `POIy` float NOT NULL DEFAULT '0',
  `POIPriority` int unsigned NOT NULL DEFAULT '0',
  `RewardTitle` tinyint unsigned NOT NULL DEFAULT '0',
  `RewardTalents` tinyint unsigned NOT NULL DEFAULT '0',
  `RewardArenaPoints` smallint unsigned NOT NULL DEFAULT '0',
  `RewardFactionID1` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction id from Faction.dbc in this case',
  `RewardFactionValue1` int NOT NULL DEFAULT '0',
  `RewardFactionOverride1` int NOT NULL DEFAULT '0',
  `RewardFactionID2` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction id from Faction.dbc in this case',
  `RewardFactionValue2` int NOT NULL DEFAULT '0',
  `RewardFactionOverride2` int NOT NULL DEFAULT '0',
  `RewardFactionID3` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction id from Faction.dbc in this case',
  `RewardFactionValue3` int NOT NULL DEFAULT '0',
  `RewardFactionOverride3` int NOT NULL DEFAULT '0',
  `RewardFactionID4` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction id from Faction.dbc in this case',
  `RewardFactionValue4` int NOT NULL DEFAULT '0',
  `RewardFactionOverride4` int NOT NULL DEFAULT '0',
  `RewardFactionID5` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction id from Faction.dbc in this case',
  `RewardFactionValue5` int NOT NULL DEFAULT '0',
  `RewardFactionOverride5` int NOT NULL DEFAULT '0',
  `TimeAllowed` int unsigned NOT NULL DEFAULT '0',
  `AllowableRaces` int unsigned NOT NULL DEFAULT '0',
  `LogTitle` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `LogDescription` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `QuestDescription` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `AreaDescription` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `QuestCompletionLog` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `RequiredNpcOrGo1` int NOT NULL DEFAULT '0',
  `RequiredNpcOrGo2` int NOT NULL DEFAULT '0',
  `RequiredNpcOrGo3` int NOT NULL DEFAULT '0',
  `RequiredNpcOrGo4` int NOT NULL DEFAULT '0',
  `RequiredNpcOrGoCount1` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredNpcOrGoCount2` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredNpcOrGoCount3` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredNpcOrGoCount4` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredItemId1` int unsigned NOT NULL DEFAULT '0',
  `RequiredItemId2` int unsigned NOT NULL DEFAULT '0',
  `RequiredItemId3` int unsigned NOT NULL DEFAULT '0',
  `RequiredItemId4` int unsigned NOT NULL DEFAULT '0',
  `RequiredItemId5` int unsigned NOT NULL DEFAULT '0',
  `RequiredItemId6` int unsigned NOT NULL DEFAULT '0',
  `RequiredItemCount1` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredItemCount2` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredItemCount3` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredItemCount4` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredItemCount5` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredItemCount6` smallint unsigned NOT NULL DEFAULT '0',
  `Unknown0` tinyint unsigned NOT NULL DEFAULT '0',
  `ObjectiveText1` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText2` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText3` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText4` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Quest System';

CREATE TABLE IF NOT EXISTS `quest_template_addon` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `MaxLevel` tinyint unsigned NOT NULL DEFAULT '0',
  `AllowableClasses` int unsigned NOT NULL DEFAULT '0',
  `SourceSpellID` int unsigned NOT NULL DEFAULT '0',
  `PrevQuestID` int NOT NULL DEFAULT '0',
  `NextQuestID` int unsigned NOT NULL DEFAULT '0',
  `ExclusiveGroup` int NOT NULL DEFAULT '0',
  `RewardMailTemplateID` int unsigned NOT NULL DEFAULT '0',
  `RewardMailDelay` int unsigned NOT NULL DEFAULT '0',
  `RequiredSkillID` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredSkillPoints` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredMinRepFaction` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredMaxRepFaction` smallint unsigned NOT NULL DEFAULT '0',
  `RequiredMinRepValue` int NOT NULL DEFAULT '0',
  `RequiredMaxRepValue` int NOT NULL DEFAULT '0',
  `ProvidedItemCount` tinyint unsigned NOT NULL DEFAULT '0',
  `SpecialFlags` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `quest_template_locale` (
  `ID` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Title` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Details` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Objectives` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `EndText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `CompletedText` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText1` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText2` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText3` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ObjectiveText4` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `questfactionreward_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Difficulty_1` int NOT NULL DEFAULT '0',
  `Difficulty_2` int NOT NULL DEFAULT '0',
  `Difficulty_3` int NOT NULL DEFAULT '0',
  `Difficulty_4` int NOT NULL DEFAULT '0',
  `Difficulty_5` int NOT NULL DEFAULT '0',
  `Difficulty_6` int NOT NULL DEFAULT '0',
  `Difficulty_7` int NOT NULL DEFAULT '0',
  `Difficulty_8` int NOT NULL DEFAULT '0',
  `Difficulty_9` int NOT NULL DEFAULT '0',
  `Difficulty_10` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `questsort_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `SortName_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SortName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `questxp_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Difficulty_1` int NOT NULL DEFAULT '0',
  `Difficulty_2` int NOT NULL DEFAULT '0',
  `Difficulty_3` int NOT NULL DEFAULT '0',
  `Difficulty_4` int NOT NULL DEFAULT '0',
  `Difficulty_5` int NOT NULL DEFAULT '0',
  `Difficulty_6` int NOT NULL DEFAULT '0',
  `Difficulty_7` int NOT NULL DEFAULT '0',
  `Difficulty_8` int NOT NULL DEFAULT '0',
  `Difficulty_9` int NOT NULL DEFAULT '0',
  `Difficulty_10` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `randproppoints_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Epic_1` int NOT NULL DEFAULT '0',
  `Epic_2` int NOT NULL DEFAULT '0',
  `Epic_3` int NOT NULL DEFAULT '0',
  `Epic_4` int NOT NULL DEFAULT '0',
  `Epic_5` int NOT NULL DEFAULT '0',
  `Superior_1` int NOT NULL DEFAULT '0',
  `Superior_2` int NOT NULL DEFAULT '0',
  `Superior_3` int NOT NULL DEFAULT '0',
  `Superior_4` int NOT NULL DEFAULT '0',
  `Superior_5` int NOT NULL DEFAULT '0',
  `Good_1` int NOT NULL DEFAULT '0',
  `Good_2` int NOT NULL DEFAULT '0',
  `Good_3` int NOT NULL DEFAULT '0',
  `Good_4` int NOT NULL DEFAULT '0',
  `Good_5` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reference_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `reputation_reward_rate` (
  `faction` int unsigned NOT NULL DEFAULT '0',
  `quest_rate` float NOT NULL DEFAULT '1',
  `quest_daily_rate` float NOT NULL DEFAULT '1',
  `quest_weekly_rate` float NOT NULL DEFAULT '1',
  `quest_monthly_rate` float NOT NULL DEFAULT '1',
  `quest_repeatable_rate` float NOT NULL DEFAULT '1',
  `creature_rate` float NOT NULL DEFAULT '1',
  `spell_rate` float NOT NULL DEFAULT '1',
  PRIMARY KEY (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `reputation_spillover_template` (
  `faction` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction entry',
  `faction1` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'faction to give spillover for',
  `rate_1` float NOT NULL DEFAULT '0' COMMENT 'the given rep points * rate',
  `rank_1` tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'max rank,above this will not give any spillover',
  `faction2` smallint unsigned NOT NULL DEFAULT '0',
  `rate_2` float NOT NULL DEFAULT '0',
  `rank_2` tinyint unsigned NOT NULL DEFAULT '0',
  `faction3` smallint unsigned NOT NULL DEFAULT '0',
  `rate_3` float NOT NULL DEFAULT '0',
  `rank_3` tinyint unsigned NOT NULL DEFAULT '0',
  `faction4` smallint unsigned NOT NULL DEFAULT '0',
  `rate_4` float NOT NULL DEFAULT '0',
  `rank_4` tinyint unsigned NOT NULL DEFAULT '0',
  `faction5` smallint unsigned NOT NULL DEFAULT '0',
  `rate_5` float NOT NULL DEFAULT '0',
  `rank_5` tinyint unsigned NOT NULL DEFAULT '0',
  `faction6` smallint unsigned NOT NULL DEFAULT '0',
  `rate_6` float NOT NULL DEFAULT '0',
  `rank_6` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Reputation spillover reputation gain';

CREATE TABLE IF NOT EXISTS `scalingstatdistribution_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `StatID_1` int NOT NULL DEFAULT '0',
  `StatID_2` int NOT NULL DEFAULT '0',
  `StatID_3` int NOT NULL DEFAULT '0',
  `StatID_4` int NOT NULL DEFAULT '0',
  `StatID_5` int NOT NULL DEFAULT '0',
  `StatID_6` int NOT NULL DEFAULT '0',
  `StatID_7` int NOT NULL DEFAULT '0',
  `StatID_8` int NOT NULL DEFAULT '0',
  `StatID_9` int NOT NULL DEFAULT '0',
  `StatID_10` int NOT NULL DEFAULT '0',
  `Bonus_1` int NOT NULL DEFAULT '0',
  `Bonus_2` int NOT NULL DEFAULT '0',
  `Bonus_3` int NOT NULL DEFAULT '0',
  `Bonus_4` int NOT NULL DEFAULT '0',
  `Bonus_5` int NOT NULL DEFAULT '0',
  `Bonus_6` int NOT NULL DEFAULT '0',
  `Bonus_7` int NOT NULL DEFAULT '0',
  `Bonus_8` int NOT NULL DEFAULT '0',
  `Bonus_9` int NOT NULL DEFAULT '0',
  `Bonus_10` int NOT NULL DEFAULT '0',
  `Maxlevel` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `scalingstatvalues_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Charlevel` int NOT NULL DEFAULT '0',
  `ShoulderBudget` int NOT NULL DEFAULT '0',
  `TrinketBudget` int NOT NULL DEFAULT '0',
  `WeaponBudget1H` int NOT NULL DEFAULT '0',
  `RangedBudget` int NOT NULL DEFAULT '0',
  `ClothShoulderArmor` int NOT NULL DEFAULT '0',
  `LeatherShoulderArmor` int NOT NULL DEFAULT '0',
  `MailShoulderArmor` int NOT NULL DEFAULT '0',
  `PlateShoulderArmor` int NOT NULL DEFAULT '0',
  `WeaponDPS1H` int NOT NULL DEFAULT '0',
  `WeaponDPS2H` int NOT NULL DEFAULT '0',
  `SpellcasterDPS1H` int NOT NULL DEFAULT '0',
  `SpellcasterDPS2H` int NOT NULL DEFAULT '0',
  `RangedDPS` int NOT NULL DEFAULT '0',
  `WandDPS` int NOT NULL DEFAULT '0',
  `SpellPower` int NOT NULL DEFAULT '0',
  `PrimaryBudget` int NOT NULL DEFAULT '0',
  `TertiaryBudget` int NOT NULL DEFAULT '0',
  `ClothCloakArmor` int NOT NULL DEFAULT '0',
  `ClothChestArmor` int NOT NULL DEFAULT '0',
  `LeatherChestArmor` int NOT NULL DEFAULT '0',
  `MailChestArmor` int NOT NULL DEFAULT '0',
  `PlateChestArmor` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `script_waypoint` (
  `entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'creature_template entry',
  `pointid` int unsigned NOT NULL DEFAULT '0',
  `location_x` float NOT NULL DEFAULT '0',
  `location_y` float NOT NULL DEFAULT '0',
  `location_z` float NOT NULL DEFAULT '0',
  `waittime` int unsigned NOT NULL DEFAULT '0' COMMENT 'waittime in millisecs',
  `point_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`entry`,`pointid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Script Creature waypoints';

CREATE TABLE IF NOT EXISTS `skill_discovery_template` (
  `spellId` int unsigned NOT NULL DEFAULT '0' COMMENT 'SpellId of the discoverable spell',
  `reqSpell` int unsigned NOT NULL DEFAULT '0' COMMENT 'spell requirement',
  `reqSkillValue` smallint unsigned NOT NULL DEFAULT '0' COMMENT 'skill points requirement',
  `chance` float NOT NULL DEFAULT '0' COMMENT 'chance to discover',
  PRIMARY KEY (`spellId`,`reqSpell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Skill Discovery System';

CREATE TABLE IF NOT EXISTS `skill_extra_item_template` (
  `spellId` int unsigned NOT NULL DEFAULT '0' COMMENT 'SpellId of the item creation spell',
  `requiredSpecialization` int unsigned NOT NULL DEFAULT '0' COMMENT 'Specialization spell id',
  `additionalCreateChance` float NOT NULL DEFAULT '0' COMMENT 'chance to create add',
  `additionalMaxNum` tinyint NOT NULL DEFAULT '0',
  PRIMARY KEY (`spellId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Skill Specialization System';

CREATE TABLE IF NOT EXISTS `skill_fishing_base_level` (
  `entry` int unsigned NOT NULL DEFAULT '0' COMMENT 'Area identifier',
  `skill` smallint NOT NULL DEFAULT '0' COMMENT 'Base skill level requirement',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Fishing system';

CREATE TABLE IF NOT EXISTS `skill_perfect_item_template` (
  `spellId` int unsigned NOT NULL DEFAULT '0' COMMENT 'SpellId of the item creation spell',
  `requiredSpecialization` int unsigned NOT NULL DEFAULT '0' COMMENT 'Specialization spell id',
  `perfectCreateChance` float NOT NULL DEFAULT '0' COMMENT 'chance to create the perfect item instead',
  `perfectItemType` int unsigned NOT NULL DEFAULT '0' COMMENT 'perfect item type to create instead',
  PRIMARY KEY (`spellId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Crafting Perfection System';

CREATE TABLE IF NOT EXISTS `skillline_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `CategoryID` int NOT NULL DEFAULT '0',
  `SkillCostsID` int NOT NULL DEFAULT '0',
  `DisplayName_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `DisplayName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Description_Lang_enUS` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enGB` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_koKR` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_frFR` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_deDE` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enCN` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhCN` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_enTW` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_zhTW` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esES` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_esMX` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ruRU` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptPT` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_ptBR` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_itIT` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `SpellIconID` int NOT NULL DEFAULT '0',
  `AlternateVerb_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AlternateVerb_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `CanLink` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `skilllineability_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `SkillLine` int NOT NULL DEFAULT '0',
  `Spell` int NOT NULL DEFAULT '0',
  `RaceMask` int NOT NULL DEFAULT '0',
  `ClassMask` int NOT NULL DEFAULT '0',
  `ExcludeRace` int NOT NULL DEFAULT '0',
  `ExcludeClass` int NOT NULL DEFAULT '0',
  `MinSkillLineRank` int NOT NULL DEFAULT '0',
  `SupercededBySpell` int NOT NULL DEFAULT '0',
  `AcquireMethod` int NOT NULL DEFAULT '0',
  `TrivialSkillLineRankHigh` int NOT NULL DEFAULT '0',
  `TrivialSkillLineRankLow` int NOT NULL DEFAULT '0',
  `CharacterPoints_1` int NOT NULL DEFAULT '0',
  `CharacterPoints_2` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `skillraceclassinfo_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `SkillID` int NOT NULL DEFAULT '0',
  `RaceMask` int NOT NULL DEFAULT '0',
  `ClassMask` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `MinLevel` int NOT NULL DEFAULT '0',
  `SkillTierID` int NOT NULL DEFAULT '0',
  `SkillCostIndex` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `skilltiers_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Cost_1` int NOT NULL DEFAULT '0',
  `Cost_2` int NOT NULL DEFAULT '0',
  `Cost_3` int NOT NULL DEFAULT '0',
  `Cost_4` int NOT NULL DEFAULT '0',
  `Cost_5` int NOT NULL DEFAULT '0',
  `Cost_6` int NOT NULL DEFAULT '0',
  `Cost_7` int NOT NULL DEFAULT '0',
  `Cost_8` int NOT NULL DEFAULT '0',
  `Cost_9` int NOT NULL DEFAULT '0',
  `Cost_10` int NOT NULL DEFAULT '0',
  `Cost_11` int NOT NULL DEFAULT '0',
  `Cost_12` int NOT NULL DEFAULT '0',
  `Cost_13` int NOT NULL DEFAULT '0',
  `Cost_14` int NOT NULL DEFAULT '0',
  `Cost_15` int NOT NULL DEFAULT '0',
  `Cost_16` int NOT NULL DEFAULT '0',
  `Value_1` int NOT NULL DEFAULT '0',
  `Value_2` int NOT NULL DEFAULT '0',
  `Value_3` int NOT NULL DEFAULT '0',
  `Value_4` int NOT NULL DEFAULT '0',
  `Value_5` int NOT NULL DEFAULT '0',
  `Value_6` int NOT NULL DEFAULT '0',
  `Value_7` int NOT NULL DEFAULT '0',
  `Value_8` int NOT NULL DEFAULT '0',
  `Value_9` int NOT NULL DEFAULT '0',
  `Value_10` int NOT NULL DEFAULT '0',
  `Value_11` int NOT NULL DEFAULT '0',
  `Value_12` int NOT NULL DEFAULT '0',
  `Value_13` int NOT NULL DEFAULT '0',
  `Value_14` int NOT NULL DEFAULT '0',
  `Value_15` int NOT NULL DEFAULT '0',
  `Value_16` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `skinning_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `smart_scripts` (
  `entryorguid` int NOT NULL,
  `source_type` tinyint unsigned NOT NULL DEFAULT '0',
  `id` smallint unsigned NOT NULL DEFAULT '0',
  `link` smallint unsigned NOT NULL DEFAULT '0',
  `event_type` tinyint unsigned NOT NULL DEFAULT '0',
  `event_phase_mask` smallint unsigned NOT NULL DEFAULT '0',
  `event_chance` tinyint unsigned NOT NULL DEFAULT '100',
  `event_flags` smallint unsigned NOT NULL DEFAULT '0',
  `event_param1` int unsigned NOT NULL DEFAULT '0',
  `event_param2` int unsigned NOT NULL DEFAULT '0',
  `event_param3` int unsigned NOT NULL DEFAULT '0',
  `event_param4` int unsigned NOT NULL DEFAULT '0',
  `event_param5` int unsigned NOT NULL DEFAULT '0',
  `event_param6` int unsigned NOT NULL DEFAULT '0',
  `action_type` tinyint unsigned NOT NULL DEFAULT '0',
  `action_param1` int unsigned NOT NULL DEFAULT '0',
  `action_param2` int unsigned NOT NULL DEFAULT '0',
  `action_param3` int unsigned NOT NULL DEFAULT '0',
  `action_param4` int unsigned NOT NULL DEFAULT '0',
  `action_param5` int unsigned NOT NULL DEFAULT '0',
  `action_param6` int unsigned NOT NULL DEFAULT '0',
  `target_type` tinyint unsigned NOT NULL DEFAULT '0',
  `target_param1` int unsigned NOT NULL DEFAULT '0',
  `target_param2` int unsigned NOT NULL DEFAULT '0',
  `target_param3` int unsigned NOT NULL DEFAULT '0',
  `target_param4` int unsigned NOT NULL DEFAULT '0',
  `target_x` float NOT NULL DEFAULT '0',
  `target_y` float NOT NULL DEFAULT '0',
  `target_z` float NOT NULL DEFAULT '0',
  `target_o` float NOT NULL DEFAULT '0',
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Event Comment',
  PRIMARY KEY (`entryorguid`,`source_type`,`id`,`link`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `soundentries_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `SoundType` int NOT NULL DEFAULT '0',
  `Name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_3` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_4` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_5` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_6` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_7` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_8` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_9` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `File_10` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Freq_1` int NOT NULL DEFAULT '0',
  `Freq_2` int NOT NULL DEFAULT '0',
  `Freq_3` int NOT NULL DEFAULT '0',
  `Freq_4` int NOT NULL DEFAULT '0',
  `Freq_5` int NOT NULL DEFAULT '0',
  `Freq_6` int NOT NULL DEFAULT '0',
  `Freq_7` int NOT NULL DEFAULT '0',
  `Freq_8` int NOT NULL DEFAULT '0',
  `Freq_9` int NOT NULL DEFAULT '0',
  `Freq_10` int NOT NULL DEFAULT '0',
  `DirectoryBase` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Volumefloat` float NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `MinDistance` float NOT NULL DEFAULT '0',
  `DistanceCutoff` float NOT NULL DEFAULT '0',
  `EAXDef` int NOT NULL DEFAULT '0',
  `SoundEntriesAdvancedID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_area` (
  `spell` int unsigned NOT NULL DEFAULT '0',
  `area` int unsigned NOT NULL DEFAULT '0',
  `quest_start` int unsigned NOT NULL DEFAULT '0',
  `quest_end` int unsigned NOT NULL DEFAULT '0',
  `aura_spell` int NOT NULL DEFAULT '0',
  `racemask` int unsigned NOT NULL DEFAULT '0',
  `gender` tinyint unsigned NOT NULL DEFAULT '2',
  `autocast` tinyint unsigned NOT NULL DEFAULT '0',
  `quest_start_status` int NOT NULL DEFAULT '64',
  `quest_end_status` int NOT NULL DEFAULT '11',
  PRIMARY KEY (`spell`,`area`,`quest_start`,`aura_spell`,`racemask`,`gender`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_bonus_data` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `direct_bonus` float NOT NULL DEFAULT '0',
  `dot_bonus` float NOT NULL DEFAULT '0',
  `ap_bonus` float NOT NULL DEFAULT '0',
  `ap_dot_bonus` float NOT NULL DEFAULT '0',
  `comments` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_cooldown_overrides` (
  `Id` int unsigned NOT NULL,
  `RecoveryTime` int unsigned NOT NULL DEFAULT '0',
  `CategoryRecoveryTime` int unsigned NOT NULL DEFAULT '0',
  `StartRecoveryTime` int unsigned NOT NULL DEFAULT '0',
  `StartRecoveryCategory` int unsigned NOT NULL DEFAULT '0',
  `Comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_custom_attr` (
  `spell_id` int unsigned NOT NULL DEFAULT '0' COMMENT 'spell id',
  `attributes` int unsigned NOT NULL DEFAULT '0' COMMENT 'SpellCustomAttributes',
  PRIMARY KEY (`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SpellInfo custom attributes';

CREATE TABLE IF NOT EXISTS `spell_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Category` int unsigned NOT NULL DEFAULT '0',
  `DispelType` int unsigned NOT NULL DEFAULT '0',
  `Mechanic` int unsigned NOT NULL DEFAULT '0',
  `Attributes` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx2` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx3` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx4` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx5` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx6` int unsigned NOT NULL DEFAULT '0',
  `AttributesEx7` int unsigned NOT NULL DEFAULT '0',
  `ShapeshiftMask` bigint unsigned NOT NULL DEFAULT '0',
  `unk_320_2` int NOT NULL DEFAULT '0',
  `ShapeshiftExclude` bigint unsigned NOT NULL DEFAULT '0',
  `unk_320_3` int NOT NULL DEFAULT '0',
  `Targets` int unsigned NOT NULL DEFAULT '0',
  `TargetCreatureType` int unsigned NOT NULL DEFAULT '0',
  `RequiresSpellFocus` int unsigned NOT NULL DEFAULT '0',
  `FacingCasterFlags` int unsigned NOT NULL DEFAULT '0',
  `CasterAuraState` int unsigned NOT NULL DEFAULT '0',
  `TargetAuraState` int unsigned NOT NULL DEFAULT '0',
  `ExcludeCasterAuraState` int unsigned NOT NULL DEFAULT '0',
  `ExcludeTargetAuraState` int unsigned NOT NULL DEFAULT '0',
  `CasterAuraSpell` int unsigned NOT NULL DEFAULT '0',
  `TargetAuraSpell` int unsigned NOT NULL DEFAULT '0',
  `ExcludeCasterAuraSpell` int unsigned NOT NULL DEFAULT '0',
  `ExcludeTargetAuraSpell` int unsigned NOT NULL DEFAULT '0',
  `CastingTimeIndex` int unsigned NOT NULL DEFAULT '0',
  `RecoveryTime` int unsigned NOT NULL DEFAULT '0',
  `CategoryRecoveryTime` int unsigned NOT NULL DEFAULT '0',
  `InterruptFlags` int unsigned NOT NULL DEFAULT '0',
  `AuraInterruptFlags` int unsigned NOT NULL DEFAULT '0',
  `ChannelInterruptFlags` int unsigned NOT NULL DEFAULT '0',
  `ProcTypeMask` int unsigned NOT NULL DEFAULT '0',
  `ProcChance` int unsigned NOT NULL DEFAULT '0',
  `ProcCharges` int unsigned NOT NULL DEFAULT '0',
  `MaxLevel` int unsigned NOT NULL DEFAULT '0',
  `BaseLevel` int unsigned NOT NULL DEFAULT '0',
  `SpellLevel` int unsigned NOT NULL DEFAULT '0',
  `DurationIndex` int unsigned NOT NULL DEFAULT '0',
  `PowerType` int NOT NULL DEFAULT '0',
  `ManaCost` int unsigned NOT NULL DEFAULT '0',
  `ManaCostPerLevel` int unsigned NOT NULL DEFAULT '0',
  `ManaPerSecond` int unsigned NOT NULL DEFAULT '0',
  `ManaPerSecondPerLevel` int unsigned NOT NULL DEFAULT '0',
  `RangeIndex` int unsigned NOT NULL DEFAULT '0',
  `Speed` float NOT NULL DEFAULT '0',
  `ModalNextSpell` int unsigned NOT NULL DEFAULT '0',
  `CumulativeAura` int unsigned NOT NULL DEFAULT '0',
  `Totem_1` int unsigned NOT NULL DEFAULT '0',
  `Totem_2` int unsigned NOT NULL DEFAULT '0',
  `Reagent_1` int NOT NULL DEFAULT '0',
  `Reagent_2` int NOT NULL DEFAULT '0',
  `Reagent_3` int NOT NULL DEFAULT '0',
  `Reagent_4` int NOT NULL DEFAULT '0',
  `Reagent_5` int NOT NULL DEFAULT '0',
  `Reagent_6` int NOT NULL DEFAULT '0',
  `Reagent_7` int NOT NULL DEFAULT '0',
  `Reagent_8` int NOT NULL DEFAULT '0',
  `ReagentCount_1` int NOT NULL DEFAULT '0',
  `ReagentCount_2` int NOT NULL DEFAULT '0',
  `ReagentCount_3` int NOT NULL DEFAULT '0',
  `ReagentCount_4` int NOT NULL DEFAULT '0',
  `ReagentCount_5` int NOT NULL DEFAULT '0',
  `ReagentCount_6` int NOT NULL DEFAULT '0',
  `ReagentCount_7` int NOT NULL DEFAULT '0',
  `ReagentCount_8` int NOT NULL DEFAULT '0',
  `EquippedItemClass` int NOT NULL DEFAULT '0',
  `EquippedItemSubclass` int NOT NULL DEFAULT '0',
  `EquippedItemInvTypes` int NOT NULL DEFAULT '0',
  `Effect_1` int unsigned NOT NULL DEFAULT '0',
  `Effect_2` int unsigned NOT NULL DEFAULT '0',
  `Effect_3` int unsigned NOT NULL DEFAULT '0',
  `EffectDieSides_1` int NOT NULL DEFAULT '0',
  `EffectDieSides_2` int NOT NULL DEFAULT '0',
  `EffectDieSides_3` int NOT NULL DEFAULT '0',
  `EffectRealPointsPerLevel_1` float NOT NULL DEFAULT '0',
  `EffectRealPointsPerLevel_2` float NOT NULL DEFAULT '0',
  `EffectRealPointsPerLevel_3` float NOT NULL DEFAULT '0',
  `EffectBasePoints_1` int NOT NULL DEFAULT '0',
  `EffectBasePoints_2` int NOT NULL DEFAULT '0',
  `EffectBasePoints_3` int NOT NULL DEFAULT '0',
  `EffectMechanic_1` int unsigned NOT NULL DEFAULT '0',
  `EffectMechanic_2` int unsigned NOT NULL DEFAULT '0',
  `EffectMechanic_3` int unsigned NOT NULL DEFAULT '0',
  `ImplicitTargetA_1` int unsigned NOT NULL DEFAULT '0',
  `ImplicitTargetA_2` int unsigned NOT NULL DEFAULT '0',
  `ImplicitTargetA_3` int unsigned NOT NULL DEFAULT '0',
  `ImplicitTargetB_1` int unsigned NOT NULL DEFAULT '0',
  `ImplicitTargetB_2` int unsigned NOT NULL DEFAULT '0',
  `ImplicitTargetB_3` int unsigned NOT NULL DEFAULT '0',
  `EffectRadiusIndex_1` int unsigned NOT NULL DEFAULT '0',
  `EffectRadiusIndex_2` int unsigned NOT NULL DEFAULT '0',
  `EffectRadiusIndex_3` int unsigned NOT NULL DEFAULT '0',
  `EffectAura_1` int unsigned NOT NULL DEFAULT '0',
  `EffectAura_2` int unsigned NOT NULL DEFAULT '0',
  `EffectAura_3` int unsigned NOT NULL DEFAULT '0',
  `EffectAuraPeriod_1` int unsigned NOT NULL DEFAULT '0',
  `EffectAuraPeriod_2` int unsigned NOT NULL DEFAULT '0',
  `EffectAuraPeriod_3` int unsigned NOT NULL DEFAULT '0',
  `EffectMultipleValue_1` float NOT NULL DEFAULT '0',
  `EffectMultipleValue_2` float NOT NULL DEFAULT '0',
  `EffectMultipleValue_3` float NOT NULL DEFAULT '0',
  `EffectChainTargets_1` int unsigned NOT NULL DEFAULT '0',
  `EffectChainTargets_2` int unsigned NOT NULL DEFAULT '0',
  `EffectChainTargets_3` int unsigned NOT NULL DEFAULT '0',
  `EffectItemType_1` int unsigned NOT NULL DEFAULT '0',
  `EffectItemType_2` int unsigned NOT NULL DEFAULT '0',
  `EffectItemType_3` int unsigned NOT NULL DEFAULT '0',
  `EffectMiscValue_1` int NOT NULL DEFAULT '0',
  `EffectMiscValue_2` int NOT NULL DEFAULT '0',
  `EffectMiscValue_3` int NOT NULL DEFAULT '0',
  `EffectMiscValueB_1` int NOT NULL DEFAULT '0',
  `EffectMiscValueB_2` int NOT NULL DEFAULT '0',
  `EffectMiscValueB_3` int NOT NULL DEFAULT '0',
  `EffectTriggerSpell_1` int unsigned NOT NULL DEFAULT '0',
  `EffectTriggerSpell_2` int unsigned NOT NULL DEFAULT '0',
  `EffectTriggerSpell_3` int unsigned NOT NULL DEFAULT '0',
  `EffectPointsPerCombo_1` float NOT NULL DEFAULT '0',
  `EffectPointsPerCombo_2` float NOT NULL DEFAULT '0',
  `EffectPointsPerCombo_3` float NOT NULL DEFAULT '0',
  `EffectSpellClassMaskA_1` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskA_2` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskA_3` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskB_1` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskB_2` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskB_3` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskC_1` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskC_2` int unsigned NOT NULL DEFAULT '0',
  `EffectSpellClassMaskC_3` int unsigned NOT NULL DEFAULT '0',
  `SpellVisualID_1` int unsigned NOT NULL DEFAULT '0',
  `SpellVisualID_2` int unsigned NOT NULL DEFAULT '0',
  `SpellIconID` int unsigned NOT NULL DEFAULT '0',
  `ActiveIconID` int unsigned NOT NULL DEFAULT '0',
  `SpellPriority` int unsigned NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `NameSubtext_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `NameSubtext_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Description_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_Unk` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `Description_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `AuraDescription_Lang_enUS` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_enGB` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_koKR` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_frFR` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_deDE` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_enCN` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_zhCN` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_enTW` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_zhTW` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_esES` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_esMX` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_ruRU` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_ptPT` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_ptBR` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_itIT` varchar(550) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AuraDescription_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `ManaCostPct` int unsigned NOT NULL DEFAULT '0',
  `StartRecoveryCategory` int unsigned NOT NULL DEFAULT '0',
  `StartRecoveryTime` int unsigned NOT NULL DEFAULT '0',
  `MaxTargetLevel` int unsigned NOT NULL DEFAULT '0',
  `SpellClassSet` int unsigned NOT NULL DEFAULT '0',
  `SpellClassMask_1` int unsigned NOT NULL DEFAULT '0',
  `SpellClassMask_2` int unsigned NOT NULL DEFAULT '0',
  `SpellClassMask_3` int unsigned NOT NULL DEFAULT '0',
  `MaxTargets` int unsigned NOT NULL DEFAULT '0',
  `DefenseType` int unsigned NOT NULL DEFAULT '0',
  `PreventionType` int unsigned NOT NULL DEFAULT '0',
  `StanceBarOrder` int unsigned NOT NULL DEFAULT '0',
  `EffectChainAmplitude_1` float NOT NULL DEFAULT '0',
  `EffectChainAmplitude_2` float NOT NULL DEFAULT '0',
  `EffectChainAmplitude_3` float NOT NULL DEFAULT '0',
  `MinFactionID` int unsigned NOT NULL DEFAULT '0',
  `MinReputation` int unsigned NOT NULL DEFAULT '0',
  `RequiredAuraVision` int unsigned NOT NULL DEFAULT '0',
  `RequiredTotemCategoryID_1` int unsigned NOT NULL DEFAULT '0',
  `RequiredTotemCategoryID_2` int unsigned NOT NULL DEFAULT '0',
  `RequiredAreasID` int NOT NULL DEFAULT '0',
  `SchoolMask` int unsigned NOT NULL DEFAULT '0',
  `RuneCostID` int unsigned NOT NULL DEFAULT '0',
  `SpellMissileID` int unsigned NOT NULL DEFAULT '0',
  `PowerDisplayID` int NOT NULL DEFAULT '0',
  `EffectBonusMultiplier_1` float NOT NULL DEFAULT '0',
  `EffectBonusMultiplier_2` float NOT NULL DEFAULT '0',
  `EffectBonusMultiplier_3` float NOT NULL DEFAULT '0',
  `SpellDescriptionVariableID` int unsigned NOT NULL DEFAULT '0',
  `SpellDifficultyID` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_enchant_proc_data` (
  `entry` int unsigned NOT NULL,
  `customChance` int unsigned NOT NULL DEFAULT '0',
  `PPMChance` float NOT NULL DEFAULT '0',
  `procEx` int unsigned NOT NULL DEFAULT '0',
  `attributeMask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`),
  CONSTRAINT `spell_enchant_proc_data_chk_1` CHECK ((`PPMChance` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Spell enchant proc data';

CREATE TABLE IF NOT EXISTS `spell_group` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `spell_id` int NOT NULL,
  PRIMARY KEY (`id`,`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Spell System';

CREATE TABLE IF NOT EXISTS `spell_group_stack_rules` (
  `group_id` int unsigned NOT NULL DEFAULT '0',
  `stack_rule` tinyint NOT NULL DEFAULT '0',
  `description` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_linked_spell` (
  `spell_trigger` int NOT NULL,
  `spell_effect` int NOT NULL DEFAULT '0',
  `type` tinyint unsigned NOT NULL DEFAULT '0',
  `comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  UNIQUE KEY `trigger_effect_type` (`spell_trigger`,`spell_effect`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Spell System';

CREATE TABLE IF NOT EXISTS `spell_loot_template` (
  `Entry` int unsigned NOT NULL DEFAULT '0',
  `Item` int unsigned NOT NULL DEFAULT '0',
  `Reference` int NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '100',
  `QuestRequired` tinyint NOT NULL DEFAULT '0',
  `LootMode` smallint unsigned NOT NULL DEFAULT '1',
  `GroupId` tinyint unsigned NOT NULL DEFAULT '0',
  `MinCount` tinyint unsigned NOT NULL DEFAULT '1',
  `MaxCount` tinyint unsigned NOT NULL DEFAULT '1',
  `Comment` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`Entry`,`Item`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Loot System';

CREATE TABLE IF NOT EXISTS `spell_mixology` (
  `entry` int unsigned NOT NULL,
  `pctMod` float NOT NULL DEFAULT '30' COMMENT 'bonus multiplier',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_pet_auras` (
  `spell` int unsigned NOT NULL COMMENT 'dummy spell id',
  `effectId` tinyint unsigned NOT NULL DEFAULT '0',
  `pet` int unsigned NOT NULL DEFAULT '0' COMMENT 'pet id; 0 = all',
  `aura` int unsigned NOT NULL COMMENT 'pet aura id',
  PRIMARY KEY (`spell`,`effectId`,`pet`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_proc` (
  `SpellId` int NOT NULL DEFAULT '0',
  `SchoolMask` tinyint unsigned NOT NULL DEFAULT '0',
  `SpellFamilyName` smallint unsigned NOT NULL DEFAULT '0',
  `SpellFamilyMask0` int unsigned NOT NULL DEFAULT '0',
  `SpellFamilyMask1` int unsigned NOT NULL DEFAULT '0',
  `SpellFamilyMask2` int unsigned NOT NULL DEFAULT '0',
  `ProcFlags` int unsigned NOT NULL DEFAULT '0',
  `SpellTypeMask` int unsigned NOT NULL DEFAULT '0',
  `SpellPhaseMask` int unsigned NOT NULL DEFAULT '0',
  `HitMask` int unsigned NOT NULL DEFAULT '0',
  `AttributesMask` int unsigned NOT NULL DEFAULT '0',
  `ProcsPerMinute` float NOT NULL DEFAULT '0',
  `Chance` float NOT NULL DEFAULT '0',
  `Cooldown` int unsigned NOT NULL DEFAULT '0',
  `Charges` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`SpellId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_proc_event` (
  `entry` int NOT NULL DEFAULT '0',
  `SchoolMask` tinyint NOT NULL DEFAULT '0',
  `SpellFamilyName` smallint unsigned NOT NULL DEFAULT '0',
  `SpellFamilyMask0` int unsigned NOT NULL DEFAULT '0',
  `SpellFamilyMask1` int unsigned NOT NULL DEFAULT '0',
  `SpellFamilyMask2` int unsigned NOT NULL DEFAULT '0',
  `procFlags` int unsigned NOT NULL DEFAULT '0',
  `procEx` int unsigned NOT NULL DEFAULT '0',
  `procPhase` int unsigned NOT NULL DEFAULT '0',
  `ppmRate` float NOT NULL DEFAULT '0',
  `CustomChance` float NOT NULL DEFAULT '0',
  `Cooldown` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_ranks` (
  `first_spell_id` int unsigned NOT NULL DEFAULT '0',
  `spell_id` int unsigned NOT NULL DEFAULT '0',
  `rank` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`first_spell_id`,`rank`),
  UNIQUE KEY `spell_id` (`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Spell Rank Data';

CREATE TABLE IF NOT EXISTS `spell_required` (
  `spell_id` int NOT NULL DEFAULT '0',
  `req_spell` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`spell_id`,`req_spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Spell Additinal Data';

CREATE TABLE IF NOT EXISTS `spell_script_names` (
  `spell_id` int NOT NULL,
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  UNIQUE KEY `spell_id` (`spell_id`,`ScriptName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_scripts` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `effIndex` tinyint unsigned NOT NULL DEFAULT '0',
  `delay` int unsigned NOT NULL DEFAULT '0',
  `command` int unsigned NOT NULL DEFAULT '0',
  `datalong` int unsigned NOT NULL DEFAULT '0',
  `datalong2` int unsigned NOT NULL DEFAULT '0',
  `dataint` int NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `o` float NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spell_target_position` (
  `ID` int unsigned NOT NULL DEFAULT '0' COMMENT 'Identifier',
  `EffectIndex` tinyint unsigned NOT NULL DEFAULT '0',
  `MapID` smallint unsigned NOT NULL DEFAULT '0',
  `PositionX` float NOT NULL DEFAULT '0',
  `PositionY` float NOT NULL DEFAULT '0',
  `PositionZ` float NOT NULL DEFAULT '0',
  `Orientation` float NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT NULL,
  PRIMARY KEY (`ID`,`EffectIndex`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Spell System';

CREATE TABLE IF NOT EXISTS `spell_threat` (
  `entry` int unsigned NOT NULL,
  `flatMod` int DEFAULT NULL,
  `pctMod` float NOT NULL DEFAULT '1' COMMENT 'threat multiplier for damage/healing',
  `apPctMod` float NOT NULL DEFAULT '0' COMMENT 'additional threat bonus from attack power',
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellcasttimes_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Base` int NOT NULL DEFAULT '0',
  `PerLevel` int NOT NULL DEFAULT '0',
  `Minimum` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellcategory_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spelldifficulty_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `DifficultySpellID_1` int NOT NULL DEFAULT '0',
  `DifficultySpellID_2` int NOT NULL DEFAULT '0',
  `DifficultySpellID_3` int NOT NULL DEFAULT '0',
  `DifficultySpellID_4` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellduration_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Duration` int NOT NULL DEFAULT '0',
  `DurationPerLevel` int NOT NULL DEFAULT '0',
  `MaxDuration` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellfocusobject_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellitemenchantment_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Charges` int NOT NULL DEFAULT '0',
  `Effect_1` int NOT NULL DEFAULT '0',
  `Effect_2` int NOT NULL DEFAULT '0',
  `Effect_3` int NOT NULL DEFAULT '0',
  `EffectPointsMin_1` int NOT NULL DEFAULT '0',
  `EffectPointsMin_2` int NOT NULL DEFAULT '0',
  `EffectPointsMin_3` int NOT NULL DEFAULT '0',
  `EffectPointsMax_1` int NOT NULL DEFAULT '0',
  `EffectPointsMax_2` int NOT NULL DEFAULT '0',
  `EffectPointsMax_3` int NOT NULL DEFAULT '0',
  `EffectArg_1` int NOT NULL DEFAULT '0',
  `EffectArg_2` int NOT NULL DEFAULT '0',
  `EffectArg_3` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `ItemVisual` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `Src_ItemID` int NOT NULL DEFAULT '0',
  `Condition_Id` int NOT NULL DEFAULT '0',
  `RequiredSkillID` int NOT NULL DEFAULT '0',
  `RequiredSkillRank` int NOT NULL DEFAULT '0',
  `MinLevel` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellitemenchantmentcondition_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Lt_OperandType_1` tinyint unsigned NOT NULL DEFAULT '0',
  `Lt_OperandType_2` tinyint unsigned NOT NULL DEFAULT '0',
  `Lt_OperandType_3` tinyint unsigned NOT NULL DEFAULT '0',
  `Lt_OperandType_4` tinyint unsigned NOT NULL DEFAULT '0',
  `Lt_OperandType_5` tinyint unsigned NOT NULL DEFAULT '0',
  `Lt_Operand_1` int NOT NULL DEFAULT '0',
  `Lt_Operand_2` int NOT NULL DEFAULT '0',
  `Lt_Operand_3` int NOT NULL DEFAULT '0',
  `Lt_Operand_4` int NOT NULL DEFAULT '0',
  `Lt_Operand_5` int NOT NULL DEFAULT '0',
  `Operator_1` tinyint unsigned NOT NULL DEFAULT '0',
  `Operator_2` tinyint unsigned NOT NULL DEFAULT '0',
  `Operator_3` tinyint unsigned NOT NULL DEFAULT '0',
  `Operator_4` tinyint unsigned NOT NULL DEFAULT '0',
  `Operator_5` tinyint unsigned NOT NULL DEFAULT '0',
  `Rt_OperandType_1` tinyint unsigned NOT NULL DEFAULT '0',
  `Rt_OperandType_2` tinyint unsigned NOT NULL DEFAULT '0',
  `Rt_OperandType_3` tinyint unsigned NOT NULL DEFAULT '0',
  `Rt_OperandType_4` tinyint unsigned NOT NULL DEFAULT '0',
  `Rt_OperandType_5` tinyint unsigned NOT NULL DEFAULT '0',
  `Rt_Operand_1` int NOT NULL DEFAULT '0',
  `Rt_Operand_2` int NOT NULL DEFAULT '0',
  `Rt_Operand_3` int NOT NULL DEFAULT '0',
  `Rt_Operand_4` int NOT NULL DEFAULT '0',
  `Rt_Operand_5` int NOT NULL DEFAULT '0',
  `Logic_1` tinyint unsigned NOT NULL DEFAULT '0',
  `Logic_2` tinyint unsigned NOT NULL DEFAULT '0',
  `Logic_3` tinyint unsigned NOT NULL DEFAULT '0',
  `Logic_4` tinyint unsigned NOT NULL DEFAULT '0',
  `Logic_5` tinyint unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellradius_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Radius` float NOT NULL DEFAULT '0',
  `RadiusPerLevel` float NOT NULL DEFAULT '0',
  `RadiusMax` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellrange_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `RangeMin_1` float NOT NULL DEFAULT '0',
  `RangeMin_2` float NOT NULL DEFAULT '0',
  `RangeMax_1` float NOT NULL DEFAULT '0',
  `RangeMax_2` float NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `DisplayName_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_Unk` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `DisplayNameShort_Lang_enUS` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_enGB` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_koKR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_frFR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_deDE` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_enCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_zhCN` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_enTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_zhTW` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_esES` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_esMX` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_ruRU` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_ptPT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_ptBR` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_itIT` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_Unk` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `DisplayNameShort_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellrunecost_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Blood` int NOT NULL DEFAULT '0',
  `Unholy` int NOT NULL DEFAULT '0',
  `Frost` int NOT NULL DEFAULT '0',
  `RunicPower` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellshapeshiftform_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `BonusActionBar` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `CreatureType` int NOT NULL DEFAULT '0',
  `AttackIconID` int NOT NULL DEFAULT '0',
  `CombatRoundTime` int NOT NULL DEFAULT '0',
  `CreatureDisplayID_1` int NOT NULL DEFAULT '0',
  `CreatureDisplayID_2` int NOT NULL DEFAULT '0',
  `CreatureDisplayID_3` int NOT NULL DEFAULT '0',
  `CreatureDisplayID_4` int NOT NULL DEFAULT '0',
  `PresetSpellID_1` int NOT NULL DEFAULT '0',
  `PresetSpellID_2` int NOT NULL DEFAULT '0',
  `PresetSpellID_3` int NOT NULL DEFAULT '0',
  `PresetSpellID_4` int NOT NULL DEFAULT '0',
  `PresetSpellID_5` int NOT NULL DEFAULT '0',
  `PresetSpellID_6` int NOT NULL DEFAULT '0',
  `PresetSpellID_7` int NOT NULL DEFAULT '0',
  `PresetSpellID_8` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `spellvisual_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `PrecastKit` int NOT NULL DEFAULT '0',
  `CastKit` int NOT NULL DEFAULT '0',
  `ImpactKit` int NOT NULL DEFAULT '0',
  `StateKit` int NOT NULL DEFAULT '0',
  `StateDoneKit` int NOT NULL DEFAULT '0',
  `ChannelKit` int NOT NULL DEFAULT '0',
  `HasMissile` int NOT NULL DEFAULT '0',
  `MissileModel` int NOT NULL DEFAULT '0',
  `MissilePathType` int NOT NULL DEFAULT '0',
  `MissileDestinationAttachment` int NOT NULL DEFAULT '0',
  `MissileSound` int NOT NULL DEFAULT '0',
  `AnimEventSoundID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `CasterImpactKit` int NOT NULL DEFAULT '0',
  `TargetImpactKit` int NOT NULL DEFAULT '0',
  `MissileAttachment` int NOT NULL DEFAULT '0',
  `MissileFollowGroundHeight` int NOT NULL DEFAULT '0',
  `MissileFollowGroundDropSpeed` int NOT NULL DEFAULT '0',
  `MissileFollowGroundApproach` int NOT NULL DEFAULT '0',
  `MissileFollowGroundFlags` int NOT NULL DEFAULT '0',
  `MissileMotion` int NOT NULL DEFAULT '0',
  `MissileTargetingKit` int NOT NULL DEFAULT '0',
  `InstantAreaKit` int NOT NULL DEFAULT '0',
  `ImpactAreaKit` int NOT NULL DEFAULT '0',
  `PersistentAreaKit` int NOT NULL DEFAULT '0',
  `MissileCastOffsetX` float NOT NULL DEFAULT '0',
  `MissileCastOffsetY` float NOT NULL DEFAULT '0',
  `MissileCastOffsetZ` float NOT NULL DEFAULT '0',
  `MissileImpactOffsetX` float NOT NULL DEFAULT '0',
  `MissileImpactOffsetY` float NOT NULL DEFAULT '0',
  `MissileImpactOffsetZ` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `stableslotprices_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Cost` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `summonproperties_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Control` int NOT NULL DEFAULT '0',
  `Faction` int NOT NULL DEFAULT '0',
  `Title` int NOT NULL DEFAULT '0',
  `Slot` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `talent_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `TabID` int NOT NULL DEFAULT '0',
  `TierID` int NOT NULL DEFAULT '0',
  `ColumnIndex` int NOT NULL DEFAULT '0',
  `SpellRank_1` int NOT NULL DEFAULT '0',
  `SpellRank_2` int NOT NULL DEFAULT '0',
  `SpellRank_3` int NOT NULL DEFAULT '0',
  `SpellRank_4` int NOT NULL DEFAULT '0',
  `SpellRank_5` int NOT NULL DEFAULT '0',
  `SpellRank_6` int NOT NULL DEFAULT '0',
  `SpellRank_7` int NOT NULL DEFAULT '0',
  `SpellRank_8` int NOT NULL DEFAULT '0',
  `SpellRank_9` int NOT NULL DEFAULT '0',
  `PrereqTalent_1` int NOT NULL DEFAULT '0',
  `PrereqTalent_2` int NOT NULL DEFAULT '0',
  `PrereqTalent_3` int NOT NULL DEFAULT '0',
  `PrereqRank_1` int NOT NULL DEFAULT '0',
  `PrereqRank_2` int NOT NULL DEFAULT '0',
  `PrereqRank_3` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `RequiredSpellID` int NOT NULL DEFAULT '0',
  `CategoryMask_1` int NOT NULL DEFAULT '0',
  `CategoryMask_2` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `talenttab_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `SpellIconID` int NOT NULL DEFAULT '0',
  `RaceMask` int NOT NULL DEFAULT '0',
  `ClassMask` int NOT NULL DEFAULT '0',
  `PetTalentMask` int NOT NULL DEFAULT '0',
  `OrderIndex` int NOT NULL DEFAULT '0',
  `BackgroundFile` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `taxinodes_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `ContinentID` int NOT NULL DEFAULT '0',
  `X` float NOT NULL DEFAULT '0',
  `Y` float NOT NULL DEFAULT '0',
  `Z` float NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `MountCreatureID_1` int NOT NULL DEFAULT '0',
  `MountCreatureID_2` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `taxipath_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `FromTaxiNode` int NOT NULL DEFAULT '0',
  `ToTaxiNode` int NOT NULL DEFAULT '0',
  `Cost` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `taxipathnode_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `PathID` int NOT NULL DEFAULT '0',
  `NodeIndex` int NOT NULL DEFAULT '0',
  `ContinentID` int NOT NULL DEFAULT '0',
  `LocX` float NOT NULL DEFAULT '0',
  `LocY` float NOT NULL DEFAULT '0',
  `LocZ` float NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `Delay` int NOT NULL DEFAULT '0',
  `ArrivalEventID` int NOT NULL DEFAULT '0',
  `DepartureEventID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `teamcontributionpoints_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Data` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `totemcategory_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Name_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Name_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  `TotemCategoryType` int NOT NULL DEFAULT '0',
  `TotemCategoryMask` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `trainer` (
  `Id` int unsigned NOT NULL DEFAULT '0',
  `Type` tinyint unsigned NOT NULL DEFAULT '2',
  `Requirement` mediumint unsigned NOT NULL DEFAULT '0',
  `Greeting` mediumtext COLLATE utf8mb4_general_ci,
  `VerifiedBuild` int DEFAULT '0',
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `trainer_locale` (
  `Id` int unsigned NOT NULL DEFAULT '0',
  `locale` varchar(4) COLLATE utf8mb4_general_ci NOT NULL,
  `Greeting_lang` mediumtext COLLATE utf8mb4_general_ci,
  `VerifiedBuild` int DEFAULT '0',
  PRIMARY KEY (`Id`,`locale`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `trainer_spell` (
  `TrainerId` int unsigned NOT NULL DEFAULT '0',
  `SpellId` int unsigned NOT NULL DEFAULT '0',
  `MoneyCost` int unsigned NOT NULL DEFAULT '0',
  `ReqSkillLine` int unsigned NOT NULL DEFAULT '0',
  `ReqSkillRank` int unsigned NOT NULL DEFAULT '0',
  `ReqAbility1` int unsigned NOT NULL DEFAULT '0',
  `ReqAbility2` int unsigned NOT NULL DEFAULT '0',
  `ReqAbility3` int unsigned NOT NULL DEFAULT '0',
  `ReqLevel` tinyint unsigned NOT NULL DEFAULT '0',
  `VerifiedBuild` int DEFAULT '0',
  PRIMARY KEY (`TrainerId`,`SpellId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `transportanimation_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `TransportID` int NOT NULL DEFAULT '0',
  `TimeIndex` int NOT NULL DEFAULT '0',
  `PosX` float NOT NULL DEFAULT '0',
  `PosY` float NOT NULL DEFAULT '0',
  `PosZ` float NOT NULL DEFAULT '0',
  `SequenceID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `transportrotation_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `GameObjectsID` int NOT NULL DEFAULT '0',
  `TimeIndex` int NOT NULL DEFAULT '0',
  `RotX` float NOT NULL DEFAULT '0',
  `RotY` float NOT NULL DEFAULT '0',
  `RotZ` float NOT NULL DEFAULT '0',
  `RotW` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `transports` (
  `guid` int unsigned NOT NULL AUTO_INCREMENT,
  `entry` int unsigned NOT NULL DEFAULT '0',
  `name` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ScriptName` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  PRIMARY KEY (`guid`),
  UNIQUE KEY `idx_entry` (`entry`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Transports';

CREATE TABLE IF NOT EXISTS `updates` (
  `name` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'filename with extension of the update.',
  `hash` char(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '' COMMENT 'sha1 hash of the sql file.',
  `state` enum('RELEASED','CUSTOM','MODULE','ARCHIVED','PENDING') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'RELEASED' COMMENT 'defines if an update is released or archived.',
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'timestamp when the query was applied.',
  `speed` int unsigned NOT NULL DEFAULT '0' COMMENT 'time the query takes to apply in ms.',
  PRIMARY KEY (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='List of all applied updates in this database.';

CREATE TABLE IF NOT EXISTS `updates_include` (
  `path` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'directory to include. $ means relative to the source directory.',
  `state` enum('RELEASED','ARCHIVED','CUSTOM','PENDING') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'RELEASED' COMMENT 'defines if the directory contains released or archived updates.',
  PRIMARY KEY (`path`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='List of directories where we want to include sql updates.';

CREATE TABLE `v_heirloom_items` (
	`item_id` INT UNSIGNED NOT NULL,
	`item_name` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`rarity` TINYINT UNSIGNED NOT NULL,
	`slot` TINYINT UNSIGNED NOT NULL,
	`armor_type` TINYINT UNSIGNED NOT NULL,
	`display_id` INT UNSIGNED NOT NULL
);

CREATE TABLE `v_heirloom_packages_detailed` (
	`package_id` TINYINT UNSIGNED NOT NULL,
	`package_name` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_0900_ai_ci',
	`package_icon` VARCHAR(1) NOT NULL COMMENT 'Icon path for addon' COLLATE 'utf8mb4_0900_ai_ci',
	`description` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_0900_ai_ci',
	`stat_type_1` TINYINT UNSIGNED NOT NULL COMMENT 'Primary stat type (ItemModType)',
	`stat_type_2` TINYINT UNSIGNED NOT NULL COMMENT 'Secondary stat type (ItemModType)',
	`stat_type_3` TINYINT UNSIGNED NULL COMMENT 'Tertiary stat type (optional)',
	`stat_1_name` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_0900_ai_ci',
	`stat_2_name` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_0900_ai_ci',
	`stat_3_name` VARCHAR(1) NULL COLLATE 'utf8mb4_0900_ai_ci',
	`color_css` VARCHAR(1) NULL COLLATE 'utf8mb4_0900_ai_ci',
	`recommended_classes` VARCHAR(1) NULL COMMENT 'Recommended class names' COLLATE 'utf8mb4_0900_ai_ci',
	`recommended_specs` VARCHAR(1) NULL COMMENT 'Recommended spec names' COLLATE 'utf8mb4_0900_ai_ci',
	`sort_order` TINYINT UNSIGNED NULL COMMENT 'Display order in addon'
);

CREATE TABLE `v_mount_items` (
	`item_id` INT UNSIGNED NOT NULL,
	`item_name` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`spell_id` INT NOT NULL,
	`rarity` TINYINT UNSIGNED NOT NULL,
	`display_id` INT UNSIGNED NOT NULL
);

CREATE TABLE `v_pet_items` (
	`item_id` INT UNSIGNED NOT NULL,
	`item_name` VARCHAR(1) NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`spell_id` INT NOT NULL,
	`rarity` TINYINT UNSIGNED NOT NULL,
	`display_id` INT UNSIGNED NOT NULL
);

CREATE TABLE IF NOT EXISTS `vehicle_accessory` (
  `guid` int unsigned NOT NULL DEFAULT '0',
  `accessory_entry` int unsigned NOT NULL DEFAULT '0',
  `seat_id` tinyint NOT NULL DEFAULT '0',
  `minion` tinyint unsigned NOT NULL DEFAULT '0',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `summontype` tinyint unsigned NOT NULL DEFAULT '6' COMMENT 'see enum TempSummonType',
  `summontimer` int unsigned NOT NULL DEFAULT '30000' COMMENT 'timer, only relevant for certain summontypes',
  PRIMARY KEY (`guid`,`seat_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vehicle_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `TurnSpeed` float NOT NULL DEFAULT '0',
  `PitchSpeed` float NOT NULL DEFAULT '0',
  `PitchMin` float NOT NULL DEFAULT '0',
  `PitchMax` float NOT NULL DEFAULT '0',
  `SeatID_1` int NOT NULL DEFAULT '0',
  `SeatID_2` int NOT NULL DEFAULT '0',
  `SeatID_3` int NOT NULL DEFAULT '0',
  `SeatID_4` int NOT NULL DEFAULT '0',
  `SeatID_5` int NOT NULL DEFAULT '0',
  `SeatID_6` int NOT NULL DEFAULT '0',
  `SeatID_7` int NOT NULL DEFAULT '0',
  `SeatID_8` int NOT NULL DEFAULT '0',
  `MouseLookOffsetPitch` float NOT NULL DEFAULT '0',
  `CameraFadeDistScalarMin` float NOT NULL DEFAULT '0',
  `CameraFadeDistScalarMax` float NOT NULL DEFAULT '0',
  `CameraPitchOffset` float NOT NULL DEFAULT '0',
  `FacingLimitRight` float NOT NULL DEFAULT '0',
  `FacingLimitLeft` float NOT NULL DEFAULT '0',
  `MsslTrgtTurnLingering` float NOT NULL DEFAULT '0',
  `MsslTrgtPitchLingering` float NOT NULL DEFAULT '0',
  `MsslTrgtMouseLingering` float NOT NULL DEFAULT '0',
  `MsslTrgtEndOpacity` float NOT NULL DEFAULT '0',
  `MsslTrgtArcSpeed` float NOT NULL DEFAULT '0',
  `MsslTrgtArcRepeat` float NOT NULL DEFAULT '0',
  `MsslTrgtArcWidth` float NOT NULL DEFAULT '0',
  `MsslTrgtImpactRadius_1` float NOT NULL DEFAULT '0',
  `MsslTrgtImpactRadius_2` float NOT NULL DEFAULT '0',
  `MsslTrgtArcTexture` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MsslTrgtImpactTexture` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MsslTrgtImpactModel_1` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `MsslTrgtImpactModel_2` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `CameraYawOffset` float NOT NULL DEFAULT '0',
  `UilocomotionType` int NOT NULL DEFAULT '0',
  `MsslTrgtImpactTexRadius` float NOT NULL DEFAULT '0',
  `VehicleUIIndicatorID` int NOT NULL DEFAULT '0',
  `PowerDisplayID_1` int NOT NULL DEFAULT '0',
  `PowerDisplayID_2` int NOT NULL DEFAULT '0',
  `PowerDisplayID_3` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vehicle_seat_addon` (
  `SeatEntry` int unsigned NOT NULL COMMENT 'VehicleSeatEntry.dbc identifier',
  `SeatOrientation` float DEFAULT '0' COMMENT 'Seat Orientation override value',
  `ExitParamX` float DEFAULT '0',
  `ExitParamY` float DEFAULT '0',
  `ExitParamZ` float DEFAULT '0',
  `ExitParamO` float DEFAULT '0',
  `ExitParamValue` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`SeatEntry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `vehicle_template_accessory` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `accessory_entry` int unsigned NOT NULL DEFAULT '0',
  `seat_id` tinyint NOT NULL DEFAULT '0',
  `minion` tinyint unsigned NOT NULL DEFAULT '0',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `summontype` tinyint unsigned NOT NULL DEFAULT '6' COMMENT 'see enum TempSummonType',
  `summontimer` int unsigned NOT NULL DEFAULT '30000' COMMENT 'timer, only relevant for certain summontypes',
  PRIMARY KEY (`entry`,`seat_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vehicleseat_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `AttachmentID` int NOT NULL DEFAULT '0',
  `AttachmentOffsetX` float NOT NULL DEFAULT '0',
  `AttachmentOffsetY` float NOT NULL DEFAULT '0',
  `AttachmentOffsetZ` float NOT NULL DEFAULT '0',
  `EnterPreDelay` float NOT NULL DEFAULT '0',
  `EnterSpeed` float NOT NULL DEFAULT '0',
  `EnterGravity` float NOT NULL DEFAULT '0',
  `EnterMinDuration` float NOT NULL DEFAULT '0',
  `EnterMaxDuration` float NOT NULL DEFAULT '0',
  `EnterMinArcHeight` float NOT NULL DEFAULT '0',
  `EnterMaxArcHeight` float NOT NULL DEFAULT '0',
  `EnterAnimStart` int NOT NULL DEFAULT '0',
  `EnterAnimLoop` int NOT NULL DEFAULT '0',
  `RideAnimStart` int NOT NULL DEFAULT '0',
  `RideAnimLoop` int NOT NULL DEFAULT '0',
  `RideUpperAnimStart` int NOT NULL DEFAULT '0',
  `RideUpperAnimLoop` int NOT NULL DEFAULT '0',
  `ExitPreDelay` float NOT NULL DEFAULT '0',
  `ExitSpeed` float NOT NULL DEFAULT '0',
  `ExitGravity` float NOT NULL DEFAULT '0',
  `ExitMinDuration` float NOT NULL DEFAULT '0',
  `ExitMaxDuration` float NOT NULL DEFAULT '0',
  `ExitMinArcHeight` float NOT NULL DEFAULT '0',
  `ExitMaxArcHeight` float NOT NULL DEFAULT '0',
  `ExitAnimStart` int NOT NULL DEFAULT '0',
  `ExitAnimLoop` int NOT NULL DEFAULT '0',
  `ExitAnimEnd` int NOT NULL DEFAULT '0',
  `PassengerYaw` float NOT NULL DEFAULT '0',
  `PassengerPitch` float NOT NULL DEFAULT '0',
  `PassengerRoll` float NOT NULL DEFAULT '0',
  `PassengerAttachmentID` int NOT NULL DEFAULT '0',
  `VehicleEnterAnim` int NOT NULL DEFAULT '0',
  `VehicleExitAnim` int NOT NULL DEFAULT '0',
  `VehicleRideAnimLoop` int NOT NULL DEFAULT '0',
  `VehicleEnterAnimBone` int NOT NULL DEFAULT '0',
  `VehicleExitAnimBone` int NOT NULL DEFAULT '0',
  `VehicleRideAnimLoopBone` int NOT NULL DEFAULT '0',
  `VehicleEnterAnimDelay` float NOT NULL DEFAULT '0',
  `VehicleExitAnimDelay` float NOT NULL DEFAULT '0',
  `VehicleAbilityDisplay` int NOT NULL DEFAULT '0',
  `EnterUISoundID` int NOT NULL DEFAULT '0',
  `ExitUISoundID` int NOT NULL DEFAULT '0',
  `UiSkin` int NOT NULL DEFAULT '0',
  `FlagsB` int NOT NULL DEFAULT '0',
  `CameraEnteringDelay` float NOT NULL DEFAULT '0',
  `CameraEnteringDuration` float NOT NULL DEFAULT '0',
  `CameraExitingDelay` float NOT NULL DEFAULT '0',
  `CameraExitingDuration` float NOT NULL DEFAULT '0',
  `CameraOffsetX` float NOT NULL DEFAULT '0',
  `CameraOffsetY` float NOT NULL DEFAULT '0',
  `CameraOffsetZ` float NOT NULL DEFAULT '0',
  `CameraPosChaseRate` float NOT NULL DEFAULT '0',
  `CameraFacingChaseRate` float NOT NULL DEFAULT '0',
  `CameraEnteringZoom` float NOT NULL DEFAULT '0',
  `CameraSeatZoomMin` float NOT NULL DEFAULT '0',
  `CameraSeatZoomMax` float NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `version` (
  `core_version` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '' COMMENT 'Core revision dumped at startup.',
  `core_revision` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `db_version` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Version of world DB.',
  `cache_id` int DEFAULT '0',
  PRIMARY KEY (`core_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Version Notes';

CREATE TABLE IF NOT EXISTS `warden_checks` (
  `id` smallint unsigned NOT NULL AUTO_INCREMENT,
  `type` tinyint unsigned DEFAULT NULL,
  `data` varchar(48) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `str` varchar(170) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` int unsigned DEFAULT NULL,
  `length` tinyint unsigned DEFAULT NULL,
  `result` varchar(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `comment` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=812 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `waypoint_data` (
  `id` int unsigned NOT NULL DEFAULT '0' COMMENT 'Creature GUID',
  `point` int unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float DEFAULT NULL,
  `delay` int unsigned NOT NULL DEFAULT '0',
  `move_type` int NOT NULL DEFAULT '0',
  `action` int NOT NULL DEFAULT '0',
  `action_chance` smallint NOT NULL DEFAULT '100',
  `wpguid` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`,`point`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `waypoint_scripts` (
  `id` int unsigned NOT NULL DEFAULT '0',
  `delay` int unsigned NOT NULL DEFAULT '0',
  `command` int unsigned NOT NULL DEFAULT '0',
  `datalong` int unsigned NOT NULL DEFAULT '0',
  `datalong2` int unsigned NOT NULL DEFAULT '0',
  `dataint` int unsigned NOT NULL DEFAULT '0',
  `x` float NOT NULL DEFAULT '0',
  `y` float NOT NULL DEFAULT '0',
  `z` float NOT NULL DEFAULT '0',
  `o` float NOT NULL DEFAULT '0',
  `guid` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `waypoints` (
  `entry` int unsigned NOT NULL DEFAULT '0',
  `pointid` int unsigned NOT NULL DEFAULT '0',
  `position_x` float NOT NULL DEFAULT '0',
  `position_y` float NOT NULL DEFAULT '0',
  `position_z` float NOT NULL DEFAULT '0',
  `orientation` float DEFAULT NULL,
  `delay` int unsigned NOT NULL DEFAULT '0',
  `point_comment` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`entry`,`pointid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Creature waypoints';

CREATE TABLE IF NOT EXISTS `wmoareatable_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `WMOID` int NOT NULL DEFAULT '0',
  `NameSetID` int NOT NULL DEFAULT '0',
  `WMOGroupID` int NOT NULL DEFAULT '0',
  `SoundProviderPref` int NOT NULL DEFAULT '0',
  `SoundProviderPrefUnderwater` int NOT NULL DEFAULT '0',
  `AmbienceID` int NOT NULL DEFAULT '0',
  `ZoneMusic` int NOT NULL DEFAULT '0',
  `IntroSound` int NOT NULL DEFAULT '0',
  `Flags` int NOT NULL DEFAULT '0',
  `AreaTableID` int NOT NULL DEFAULT '0',
  `AreaName_Lang_enUS` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_enGB` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_koKR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_frFR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_deDE` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_enCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_zhCN` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_enTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_zhTW` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_esES` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_esMX` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_ruRU` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_ptPT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_ptBR` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_itIT` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_Unk` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `AreaName_Lang_Mask` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `worldmaparea_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MapID` int NOT NULL DEFAULT '0',
  `AreaID` int NOT NULL DEFAULT '0',
  `AreaName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `LocLeft` float NOT NULL DEFAULT '0',
  `LocRight` float NOT NULL DEFAULT '0',
  `LocTop` float NOT NULL DEFAULT '0',
  `LocBottom` float NOT NULL DEFAULT '0',
  `DisplayMapID` int NOT NULL DEFAULT '0',
  `DefaultDungeonFloor` int NOT NULL DEFAULT '0',
  `ParentWorldMapID` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `worldmapoverlay_dbc` (
  `ID` int NOT NULL DEFAULT '0',
  `MapAreaID` int NOT NULL DEFAULT '0',
  `AreaID_1` int NOT NULL DEFAULT '0',
  `AreaID_2` int NOT NULL DEFAULT '0',
  `AreaID_3` int NOT NULL DEFAULT '0',
  `AreaID_4` int NOT NULL DEFAULT '0',
  `MapPointX` int NOT NULL DEFAULT '0',
  `MapPointY` int NOT NULL DEFAULT '0',
  `TextureName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `TextureWidth` int NOT NULL DEFAULT '0',
  `TextureHeight` int NOT NULL DEFAULT '0',
  `OffsetX` int NOT NULL DEFAULT '0',
  `OffsetY` int NOT NULL DEFAULT '0',
  `HitRectTop` int NOT NULL DEFAULT '0',
  `HitRectLeft` int NOT NULL DEFAULT '0',
  `HitRectBottom` int NOT NULL DEFAULT '0',
  `HitRectRight` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS `v_heirloom_items`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_heirloom_items` AS select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`Quality` AS `rarity`,`i`.`InventoryType` AS `slot`,`i`.`subclass` AS `armor_type`,`i`.`displayid` AS `display_id` from `item_template` `i` where (`i`.`Quality` = 7)
;

DROP TABLE IF EXISTS `v_heirloom_packages_detailed`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_heirloom_packages_detailed` AS select `p`.`package_id` AS `package_id`,`p`.`package_name` AS `package_name`,`p`.`package_icon` AS `package_icon`,`p`.`description` AS `description`,`p`.`stat_type_1` AS `stat_type_1`,`p`.`stat_type_2` AS `stat_type_2`,`p`.`stat_type_3` AS `stat_type_3`,(case `p`.`stat_type_1` when 3 then 'Agility' when 4 then 'Strength' when 5 then 'Intellect' when 6 then 'Spirit' when 7 then 'Stamina' when 12 then 'Defense' when 13 then 'Dodge' when 14 then 'Parry' when 15 then 'Block' when 31 then 'Hit' when 32 then 'Crit' when 35 then 'Resilience' when 36 then 'Haste' when 37 then 'Expertise' when 44 then 'Armor Pen' when 45 then 'Spell Power' else concat('Stat ',`p`.`stat_type_1`) end) AS `stat_1_name`,(case `p`.`stat_type_2` when 3 then 'Agility' when 4 then 'Strength' when 5 then 'Intellect' when 6 then 'Spirit' when 7 then 'Stamina' when 12 then 'Defense' when 13 then 'Dodge' when 14 then 'Parry' when 15 then 'Block' when 31 then 'Hit' when 32 then 'Crit' when 35 then 'Resilience' when 36 then 'Haste' when 37 then 'Expertise' when 44 then 'Armor Pen' when 45 then 'Spell Power' else concat('Stat ',`p`.`stat_type_2`) end) AS `stat_2_name`,(case `p`.`stat_type_3` when 3 then 'Agility' when 4 then 'Strength' when 5 then 'Intellect' when 6 then 'Spirit' when 7 then 'Stamina' when 12 then 'Defense' when 13 then 'Dodge' when 14 then 'Parry' when 15 then 'Block' when 31 then 'Hit' when 32 then 'Crit' when 35 then 'Resilience' when 36 then 'Haste' when 37 then 'Expertise' when 44 then 'Armor Pen' when 45 then 'Spell Power' when NULL then NULL else concat('Stat ',`p`.`stat_type_3`) end) AS `stat_3_name`,concat('rgb(',`p`.`color_r`,',',`p`.`color_g`,',',`p`.`color_b`,')') AS `color_css`,`p`.`recommended_classes` AS `recommended_classes`,`p`.`recommended_specs` AS `recommended_specs`,`p`.`sort_order` AS `sort_order` from `dc_heirloom_stat_packages` `p` where (`p`.`is_enabled` = true) order by `p`.`sort_order`
;

DROP TABLE IF EXISTS `v_mount_items`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_mount_items` AS select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_1` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 5) and (`i`.`spellid_1` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_2` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 5) and (`i`.`spellid_2` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_3` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 5) and (`i`.`spellid_3` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_4` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 5) and (`i`.`spellid_4` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_5` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 5) and (`i`.`spellid_5` > 0))
;

DROP TABLE IF EXISTS `v_pet_items`;
CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v_pet_items` AS select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_1` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 2) and (`i`.`spellid_1` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_2` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 2) and (`i`.`spellid_2` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_3` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 2) and (`i`.`spellid_3` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_4` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 2) and (`i`.`spellid_4` > 0)) union all select `i`.`entry` AS `item_id`,`i`.`name` AS `item_name`,`i`.`spellid_5` AS `spell_id`,`i`.`Quality` AS `rarity`,`i`.`displayid` AS `display_id` from `item_template` `i` where ((`i`.`class` = 15) and (`i`.`subclass` = 2) and (`i`.`spellid_5` > 0))
;

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
