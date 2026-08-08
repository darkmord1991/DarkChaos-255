--
-- DarkChaos: move runtime-created schema into the SQL update flow.
--
-- These tables were previously created from C++ at runtime (CREATE TABLE IF NOT
-- EXISTS in EnsureTable()-style helpers). Runtime DDL keeps the schema out of
-- the update history and forces defensive information_schema probing on hot
-- request paths, so the definitions now live here and the C++ DDL is removed.
--
-- Definitions are transcribed from the C++ they replace. The wardrobe tables
-- previously attempted utf8mb4 and fell back to utf8 at runtime; they are
-- pinned to utf8mb4 here, which is what that code preferred.
--
-- CREATE TABLE IF NOT EXISTS is used throughout so this applies cleanly to
-- servers that already have these tables from the old runtime path. The live
-- schema was checked before writing this: all ten tables already exist and
-- dc_collection_community_outfits already carries author_account_id and
-- downvotes, so the old probe-then-ALTER migrations are not reproduced here.
--
-- Note: the `updated_at` definitions below wrap after "ON UPDATE" on purpose.
-- The SQL codestyle linter is line-based and reads "UPDATE CURRENT_TIMESTAMP"
-- as an unquoted identifier after an UPDATE clause; wrapping avoids the false
-- positive without changing the column semantics.
--

-- ---------------------------------------------------------------------------
-- Wardrobe: community outfits
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_collection_community_outfits` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(100),
  `author_name` VARCHAR(50),
  `author_account_id` INT UNSIGNED DEFAULT 0,
  `author_guid` INT UNSIGNED,
  `items_string` TEXT,
  `upvotes` INT UNSIGNED DEFAULT 0,
  `downvotes` INT UNSIGNED DEFAULT 0,
  `downloads` INT UNSIGNED DEFAULT 0,
  `views` INT UNSIGNED DEFAULT 0,
  `weekly_votes` INT UNSIGNED DEFAULT 0,
  `tags` VARCHAR(255) DEFAULT '',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Backfill account ownership from author_guid for rows written before
-- author_account_id existed. Idempotent.
UPDATE `dc_collection_community_outfits` JOIN `characters` ON `characters`.`guid` = `dc_collection_community_outfits`.`author_guid` SET `dc_collection_community_outfits`.`author_account_id` = `characters`.`account` WHERE `dc_collection_community_outfits`.`author_account_id` = 0 OR `dc_collection_community_outfits`.`author_account_id` IS NULL;

CREATE TABLE IF NOT EXISTS `dc_collection_community_favorites` (
  `account_id` INT UNSIGNED NOT NULL,
  `outfit_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`account_id`, `outfit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dc_collection_community_votes` (
  `account_id` INT UNSIGNED NOT NULL,
  `outfit_id` INT UNSIGNED NOT NULL,
  `vote` TINYINT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `outfit_id`),
  KEY `idx_outfit_id` (`outfit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Wardrobe: account outfits and applied transmog
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_account_outfits` (
  `account_id` INT UNSIGNED NOT NULL COMMENT 'Account ID',
  `outfit_id` TINYINT UNSIGNED NOT NULL COMMENT 'Outfit Slot (0-49)',
  `name` VARCHAR(50) NOT NULL DEFAULT 'New Outfit',
  `icon` VARCHAR(100) NOT NULL DEFAULT 'Interface/Icons/INV_Misc_QuestionMark',
  `items` TEXT COMMENT 'JSON {SlotKey: itemId}',
  `source_community_id` INT UNSIGNED DEFAULT NULL COMMENT 'If copied from community outfit',
  `source_author` VARCHAR(50) DEFAULT NULL COMMENT 'Original author name if copied from community',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `outfit_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Account-wide saved outfits';

CREATE TABLE IF NOT EXISTS `dc_character_transmog` (
  `guid` INT UNSIGNED NOT NULL COMMENT 'Character GUID (low)',
  `slot` TINYINT UNSIGNED NOT NULL COMMENT 'Equipment slot (0-18)',
  `fake_entry` INT UNSIGNED NOT NULL COMMENT 'Item entry used for appearance',
  `real_entry` INT UNSIGNED NOT NULL COMMENT 'Real equipped item entry',
  PRIMARY KEY (`guid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Applied transmog per character';

-- ---------------------------------------------------------------------------
-- Mythic+: HUD snapshot cache
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_mplus_hud_cache` (
  `instance_key` BIGINT UNSIGNED NOT NULL,
  `map_id` INT UNSIGNED NOT NULL,
  `instance_id` INT UNSIGNED NOT NULL,
  `owner_guid` INT UNSIGNED NOT NULL,
  `keystone_level` TINYINT UNSIGNED NOT NULL,
  `season_id` INT UNSIGNED NOT NULL,
  `payload` LONGTEXT NOT NULL,
  `updated_at` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`instance_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Account-wide progression pools
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_account_achievement_pools` (
  `account_id` INT UNSIGNED NOT NULL,
  `achievement_id` INT UNSIGNED NOT NULL,
  `completed_at` INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE
    CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `achievement_id`),
  KEY `idx_achievement_id` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos: Account-wide completed achievements';

CREATE TABLE IF NOT EXISTS `dc_account_social_friends` (
  `account_id` INT UNSIGNED NOT NULL,
  `friend_guid` INT UNSIGNED NOT NULL,
  `note` VARCHAR(48) NOT NULL DEFAULT '',
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE
    CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `friend_guid`),
  KEY `idx_friend_guid` (`friend_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos: Account-wide friendlist entries';

CREATE TABLE IF NOT EXISTS `dc_account_reputation_pools` (
  `account_id` INT UNSIGNED NOT NULL,
  `faction_id` INT UNSIGNED NOT NULL,
  `standing` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE
    CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`, `faction_id`),
  KEY `idx_faction` (`faction_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DarkChaos: Account-wide reputation pools';

-- ---------------------------------------------------------------------------
-- Seasons: weekly reset bookkeeping
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dc_weekly_reset_state` (
  `system` VARCHAR(64) NOT NULL PRIMARY KEY,
  `week_start` INT UNSIGNED NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE
    CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
