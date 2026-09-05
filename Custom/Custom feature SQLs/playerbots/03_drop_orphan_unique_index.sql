-- ---------------------------------------------------------------------------------------------
-- Drop `uniq_owner_bot_event` from playerbots_random_bots.
--
-- Added by 2026_02_12_01 in the OLD customised mod-playerbots checkout, whose stated reason was
-- "to support UPSERT writes and reduce deadlocks caused by DELETE + INSERT churn". That UPSERT
-- code went away with the fork swap -- nothing in the core or the current module issues an
-- ON DUPLICATE KEY against this table any more. Upstream deletes then inserts inside one
-- transaction, which keeps (owner, bot, event) unique on its own.
--
-- Left in place, the UNIQUE index actively causes deadlocks: two events for the same bot
-- ('randomize' and 'teleport') both sort before the existing 'update' row, so both land in the
-- same index gap, both take an X gap lock, and both then wait for insert intention on it.
--
-- idx_owner_bot_event covers the same (owner, bot, event) columns and is kept, so lookups are
-- unaffected. Upstream ran for years without the unique constraint.
-- ---------------------------------------------------------------------------------------------

USE `acore_playerbots`;

-- Sanity check: must return 0, otherwise the DELETE+INSERT invariant is not holding and the
-- unique index should stay until that is understood.
SELECT COUNT(*) AS duplicate_owner_bot_event_groups FROM (
    SELECT 1
    FROM `playerbots_random_bots`
    GROUP BY `owner`, `bot`, `event`
    HAVING COUNT(*) > 1
) d;

ALTER TABLE `playerbots_random_bots` DROP INDEX `uniq_owner_bot_event`;

-- idx_owner_bot_event should still be listed here.
SHOW INDEX FROM `playerbots_random_bots`;
