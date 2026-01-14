-- DB update 2026_01_13_05 -> 2026_01_14_01
-- Jadeforest Training Grounds: boss display pools (vanilla / tbc / wotlk)
--
-- Why:
-- - `creature_template_model` is capped to 4 models per creature template (Idx 0..3).
-- - A separate pool table lets us keep ONLY 3 dummy entries while having a large, weighted model pool.
--
-- The script reads this table:
--   dc_training_boss_display_pool(pool_id, display_id, weight)
-- where pool_id is:
--   0 = Vanilla, 1 = TBC, 2 = WotLK

CREATE TABLE IF NOT EXISTS `dc_training_boss_display_pool` (
  `pool_id` tinyint unsigned NOT NULL,
  `display_id` int unsigned NOT NULL,
  `weight` float NOT NULL DEFAULT 1,
  PRIMARY KEY (`pool_id`, `display_id`),
  KEY `idx_pool_id` (`pool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Rebuild pools
DELETE FROM `dc_training_boss_display_pool`;

-- Vanilla pool (ct.exp = 0)
INSERT IGNORE INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`)
SELECT 0 AS `pool_id`, t.`CreatureDisplayID` AS `display_id`, 1 AS `weight`
FROM (
  SELECT DISTINCT ctm.`CreatureDisplayID`
  FROM `creature_template` ct
  JOIN `creature_template_model` ctm ON ctm.`CreatureID` = ct.`entry`
  WHERE ct.`rank` IN (2, 3)
    AND ct.`entry` < 800000
    AND ct.`exp` = 0
    AND ctm.`CreatureDisplayID` <> 0
  ORDER BY ctm.`CreatureDisplayID`
  LIMIT 800
) t;

-- TBC pool (ct.exp = 1)
INSERT IGNORE INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`)
SELECT 1 AS `pool_id`, t.`CreatureDisplayID` AS `display_id`, 1 AS `weight`
FROM (
  SELECT DISTINCT ctm.`CreatureDisplayID`
  FROM `creature_template` ct
  JOIN `creature_template_model` ctm ON ctm.`CreatureID` = ct.`entry`
  WHERE ct.`rank` IN (2, 3)
    AND ct.`entry` < 800000
    AND ct.`exp` = 1
    AND ctm.`CreatureDisplayID` <> 0
  ORDER BY ctm.`CreatureDisplayID`
  LIMIT 800
) t;

-- WotLK pool (ct.exp = 2)
INSERT IGNORE INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`)
SELECT 2 AS `pool_id`, t.`CreatureDisplayID` AS `display_id`, 1 AS `weight`
FROM (
  SELECT DISTINCT ctm.`CreatureDisplayID`
  FROM `creature_template` ct
  JOIN `creature_template_model` ctm ON ctm.`CreatureID` = ct.`entry`
  WHERE ct.`rank` IN (2, 3)
    AND ct.`entry` < 800000
    AND ct.`exp` = 2
    AND ctm.`CreatureDisplayID` <> 0
  ORDER BY ctm.`CreatureDisplayID`
  LIMIT 800
) t;

-- Optional weighting example (uncomment to make some models rarer):
-- UPDATE `dc_training_boss_display_pool` SET `weight` = 0.2
-- WHERE `pool_id` = 2 AND `display_id` IN (12345, 67890);
