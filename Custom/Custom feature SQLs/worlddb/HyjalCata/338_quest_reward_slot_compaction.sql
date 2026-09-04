-- ---------------------------------------------------------------------------
-- 338  Repair the reward-slot holes 334_ punched in 545 quests
-- ---------------------------------------------------------------------------
-- 🔴 THIS FIXES A BUG 334_ INTRODUCED. Apply it immediately after 334_.
--
-- Symptom, from the worldserver's "Loading Quests..." pass:
--
--   Quest 108798 has no `RewardItemId1` but has `RewardItem2`. Reward item will
--   not be loaded.
--   ... 545 of these
--
-- ---------------------------------------------------------------------------
-- WHAT WENT WRONG
-- ---------------------------------------------------------------------------
-- 334_ removed the leftover Upgrade Token reward by zeroing whichever slot it
-- occupied:
--
--     UPDATE quest_template SET RewardItem2 = 0, RewardAmount2 = 0
--     WHERE RewardItem2 = 300311 ...
--
-- 🔴 THE REWARD SLOTS MUST BE CONTIGUOUS. `ObjectMgr::LoadQuests` walks
-- RewardItem1..4 and stops at the first empty slot; a quest with slot 1 empty and
-- slot 2 filled has its reward silently DROPPED, not shifted up. Zeroing a middle
-- slot therefore does not remove one reward, it removes every reward from that
-- slot onward.
--
-- So the sap reward 326_ added -- the whole point of 334_ -- was being discarded
-- at load on 545 quests. The DB looked right and the server ignored it.
--
-- Measured before writing this: 545 quests have a hole, **all 545 are in
-- `dc_map750_token_swap_backup`**, i.e. every one was touched by 334_ and there
-- were zero pre-existing holes. The blast radius is exactly 334_'s own set.
--
-- ---------------------------------------------------------------------------
-- THE REPAIR
-- ---------------------------------------------------------------------------
-- Compact each quest's rewards down into slots 1..n with no gaps, preserving
-- their relative order, and zero the tail.
--
-- 🔴 NOT done with a chain of `SET RewardItem1 = IF(RewardItem1 = 0, RewardItem2,
-- RewardItem1), RewardAmount1 = IF(RewardItem1 = 0, ...)`. MySQL evaluates UPDATE
-- assignments LEFT TO RIGHT USING ALREADY-UPDATED VALUES, so the amount test
-- would read the item column this same statement had just overwritten and pair
-- the wrong amount with the wrong item. Instead the compacted values are computed
-- in a staging table first and then assigned in one shot, where no assignment can
-- observe another.
--
-- Idempotent: compacting an already-compact quest is a no-op, so this is safe to
-- re-run and safe to apply to quests that never had a hole.
--
-- 🔴 No `USE` statement -- select acore_world in your client.
--
-- Apply against acore_world AFTER 334_. Needs a worldserver restart.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Compute the compacted reward list per quest
-- ---------------------------------------------------------------------------
-- 🔴 SCOPED TO QUESTS THAT ACTUALLY HAVE A HOLE, not to
-- `dc_map750_token_swap_backup`. That backup is OVER-BROAD: 334_'s snapshot step
-- was not restricted to map 750, so it captured all 724 quests in the DB that
-- paid an Upgrade Token -- including the level-80 Mythic+ quests that correctly
-- still pay one (171 of them). Using it as the scope here would rewrite the
-- reward slots of quests 334_ never modified. Compaction happens to be a no-op on
-- them, but "happens to be harmless" is not a scope.
--
-- The hole condition is the precise blast radius: 545 quests, every one of them
-- one 334_ touched, and zero pre-existing holes anywhere in the DB.
DROP TABLE IF EXISTS `dc_quest_reward_holes`;
CREATE TABLE `dc_quest_reward_holes` (
  `quest_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_quest_reward_holes` (`quest_id`)
SELECT q.`ID` FROM `quest_template` q
WHERE (q.`RewardItem1` = 0 AND q.`RewardItem2` <> 0)
   OR (q.`RewardItem2` = 0 AND q.`RewardItem3` <> 0)
   OR (q.`RewardItem3` = 0 AND q.`RewardItem4` <> 0);

DROP TABLE IF EXISTS `dc_quest_reward_compact`;
CREATE TABLE `dc_quest_reward_compact` (
  `quest_id` INT UNSIGNED NOT NULL,
  `i1` INT NOT NULL DEFAULT 0, `a1` INT NOT NULL DEFAULT 0,
  `i2` INT NOT NULL DEFAULT 0, `a2` INT NOT NULL DEFAULT 0,
  `i3` INT NOT NULL DEFAULT 0, `a3` INT NOT NULL DEFAULT 0,
  `i4` INT NOT NULL DEFAULT 0, `a4` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`quest_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_quest_reward_compact` (`quest_id`, `i1`,`a1`, `i2`,`a2`, `i3`,`a3`, `i4`,`a4`)
SELECT r.`id`,
  COALESCE(MAX(CASE WHEN r.`rn` = 1 THEN r.`item` END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 1 THEN r.`amt`  END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 2 THEN r.`item` END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 2 THEN r.`amt`  END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 3 THEN r.`item` END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 3 THEN r.`amt`  END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 4 THEN r.`item` END), 0),
  COALESCE(MAX(CASE WHEN r.`rn` = 4 THEN r.`amt`  END), 0)
FROM (
  SELECT u.`id`, u.`item`, u.`amt`,
         ROW_NUMBER() OVER (PARTITION BY u.`id` ORDER BY u.`slot`) AS `rn`
  FROM (
    -- Unpivot the four slots, keeping only the filled ones. Ordering by the
    -- original slot number is what preserves the reward order.
              SELECT q.`ID` AS `id`, 1 AS `slot`, q.`RewardItem1` AS `item`, q.`RewardAmount1` AS `amt`
              FROM `quest_template` q
              WHERE q.`RewardItem1` <> 0
                AND q.`ID` IN (SELECT `quest_id` FROM `dc_quest_reward_holes`)
    UNION ALL SELECT q.`ID`, 2, q.`RewardItem2`, q.`RewardAmount2`
              FROM `quest_template` q
              WHERE q.`RewardItem2` <> 0
                AND q.`ID` IN (SELECT `quest_id` FROM `dc_quest_reward_holes`)
    UNION ALL SELECT q.`ID`, 3, q.`RewardItem3`, q.`RewardAmount3`
              FROM `quest_template` q
              WHERE q.`RewardItem3` <> 0
                AND q.`ID` IN (SELECT `quest_id` FROM `dc_quest_reward_holes`)
    UNION ALL SELECT q.`ID`, 4, q.`RewardItem4`, q.`RewardAmount4`
              FROM `quest_template` q
              WHERE q.`RewardItem4` <> 0
                AND q.`ID` IN (SELECT `quest_id` FROM `dc_quest_reward_holes`)
  ) u
) r
GROUP BY r.`id`;

-- ---------------------------------------------------------------------------
-- 2. Write the compacted rewards back
-- ---------------------------------------------------------------------------
UPDATE `quest_template` q
JOIN `dc_quest_reward_compact` c ON c.`quest_id` = q.`ID`
SET q.`RewardItem1` = c.`i1`, q.`RewardAmount1` = c.`a1`,
    q.`RewardItem2` = c.`i2`, q.`RewardAmount2` = c.`a2`,
    q.`RewardItem3` = c.`i3`, q.`RewardAmount3` = c.`a3`,
    q.`RewardItem4` = c.`i4`, q.`RewardAmount4` = c.`a4`;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- 🔴 THE ONE THAT MATTERS -- no quest anywhere may have a hole (expect 0). This
-- is deliberately NOT scoped to map 750: a hole is a bug wherever it is, and this
-- is the query whose non-zero result produced the wall of warnings.
-- SELECT COUNT(*) FROM quest_template
-- WHERE (RewardItem1 = 0 AND RewardItem2 <> 0)
--    OR (RewardItem2 = 0 AND RewardItem3 <> 0)
--    OR (RewardItem3 = 0 AND RewardItem4 <> 0);
--
-- Nothing was LOST in the compaction -- the number of filled reward slots per
-- quest must be identical before and after. `dc_map750_token_swap_backup` holds
-- the pre-334_ state, so expect every row to show removed = 1 (the token) and
-- nothing else (expect 0 rows where more than the token went missing):
-- SELECT q.ID,
--        (SELECT COUNT(*) FROM dc_map750_token_swap_backup b
--         WHERE b.kind='quest' AND b.id=q.ID) AS tokens_removed,
--        (q.RewardItem1<>0)+(q.RewardItem2<>0)+(q.RewardItem3<>0)+(q.RewardItem4<>0) AS filled_now
-- FROM quest_template q
-- WHERE q.ID IN (SELECT id FROM dc_map750_token_swap_backup WHERE kind='quest')
--   AND (q.RewardItem1<>0)+(q.RewardItem2<>0)+(q.RewardItem3<>0)+(q.RewardItem4<>0) = 0;
--
-- Every quest 334_ touched still pays sap, and now in a slot the core will
-- actually read (expect 0 rows):
-- SELECT q.ID FROM quest_template q
-- WHERE q.ID IN (SELECT id FROM dc_map750_token_swap_backup WHERE kind='quest')
--   AND 400000 NOT IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4);
--
-- And no token survived anywhere on map 750 (expect 0):
-- SELECT COUNT(*) FROM quest_template
-- WHERE 300311 IN (RewardItem1, RewardItem2, RewardItem3, RewardItem4)
--   AND ID IN (SELECT quest FROM creature_queststarter WHERE id BETWEEN 3600000 AND 3799999
--              UNION SELECT quest FROM creature_questender WHERE id BETWEEN 3600000 AND 3799999);
--
-- 🔴 Restart the worldserver and confirm the "has no `RewardItemId1` but has
-- `RewardItem2`" block is GONE from the Loading Quests pass. That log line, not
-- the DB, is the real pass/fail here -- the DB looked fine the whole time the
-- server was discarding the rewards.
--
-- Cleanup once satisfied:
--   DROP TABLE `dc_quest_reward_compact`;
--   DROP TABLE `dc_quest_reward_holes`;
-- ---------------------------------------------------------------------------
