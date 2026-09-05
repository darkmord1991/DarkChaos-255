-- ---------------------------------------------------------------------------------------------
-- Fix: no random bots ever log in.
--
-- `playerbots_account_type` still holds 300 rows from the February install (account ids 5-304
-- typed RNDbot, 35-84 typed AddClass). Those accounts no longer exist. Every account that does
-- exist today (ids 305-1504, holding all 12,001 bot characters) is still type 0 = unassigned.
--
-- RandomPlayerbotMgr sizes the RNDbot pool as ceil(MaxRandomBots / charsPerAccount) = 150, then
-- only assigns accounts when the existing count falls short. It counts the 250 stale rows, sees
-- 250 >= 150, and assigns nothing -- so rndBotTypeAccounts is 250 empty accounts, the character
-- query returns nothing, and no "add" event is ever written. Hence 0 bots online while the log
-- repeats "Can't log-in all the requested bots".
--
-- Dropping the orphaned rows lets the next startup assign 150 RNDbot + 50 AddClass accounts out
-- of the 1,200 real ones. No characters or bot state are touched.
-- ---------------------------------------------------------------------------------------------

USE `acore_playerbots`;

-- Expect 300 rows (250 type 1 + 50 type 2), all with no matching account.
SELECT COUNT(*) AS stale_rows_to_delete
FROM `playerbots_account_type` t
LEFT JOIN `acore_logon`.`account` a ON a.`id` = t.`account_id`
WHERE a.`id` IS NULL;

DELETE t
FROM `playerbots_account_type` t
LEFT JOIN `acore_logon`.`account` a ON a.`id` = t.`account_id`
WHERE a.`id` IS NULL;

-- Should now be a single row: type 0, 1200 accounts. The server assigns types on next start.
SELECT `account_type`, COUNT(*) AS accounts
FROM `playerbots_account_type`
GROUP BY `account_type`
ORDER BY `account_type`;
