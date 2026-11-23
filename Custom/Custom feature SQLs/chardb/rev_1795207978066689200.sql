-- One-off: take race-fixed quests out of the logs of random bots that are on the wrong side for them.
--
-- pending_db_world/rev_1795179748362789600.sql (2026-11-20) limited 55 quests to one side (AllowableRaces
-- 908069965 Alliance / 1237320626 Horde), because their enders stand only on maps 750/751/861 and are hostile to
-- the other side. Bots that took them before that keep them forever: they can neither turn them in
-- (abandon reason cannot_turn_in) nor take them again correctly. On 11-20 evening: 636 rows (482 complete,
-- 154 incomplete) on RNDBOT characters whose race fails the quest's new AllowableRaces, 0 on other accounts.
--
-- Only characters on RNDBOT accounts are touched. The race test reads the live quest_template, so it removes
-- only what the current masks forbid.
-- Apply to the characters database (acore_chars) while the worldserver is STOPPED: a running server holds the
-- quest log in memory and saves the rows back. Reads acore_logon.account and acore_world.quest_template; change
-- the names if yours differ. Running it twice deletes nothing the second time.

DELETE qs FROM `character_queststatus` qs
    JOIN `characters` ch ON ch.`guid` = qs.`guid`
    JOIN `acore_logon`.`account` a ON a.`id` = ch.`account`
    JOIN `acore_world`.`quest_template` qt ON qt.`ID` = qs.`quest`
WHERE qs.`quest` IN (13583, 13585, 13589, 13599, 13867, 13893, 13895, 13896, 13953, 13964, 13965, 13976, 13981,
                     26079, 26444, 26453, 26467, 26468, 26469, 26470, 26472, 26476, 27158, 27159, 27165, 27197,
                     27725, 28674,
                     13801, 13873, 13901, 13923, 13936, 13958, 13974, 13977, 14462, 24463, 26429, 26430, 26921,
                     27083, 27095, 27117, 28115, 28168, 28484, 28487, 28508, 28587, 28600, 28620, 28636, 226926,
                     226979)
    AND qt.`AllowableRaces` <> 0
    AND (qt.`AllowableRaces` & (1 << (ch.`race` - 1))) = 0
    AND a.`username` LIKE 'RNDBOT%';
