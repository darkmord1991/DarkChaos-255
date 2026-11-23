-- One-off: take the three onboarding quests out of random bots' quest logs.
--
-- dc_firststart.cpp hands out 820062 "A Wider World" (turned in only on map 745), 81300 "The Call of
-- Kalimdor" and 81301 "The Bilgewater Expedition". Until the 2026-11-20 14:06 build it handed them to
-- bots as well, and bots never turn them in, so each one blocks a quest-log slot for good. On 11-20
-- after shutdown: 2,500 rows on RNDBOT characters (820062 1,644, 81301 481, 81300 375).
--
-- Only characters on RNDBOT accounts are touched; the 22 rows of other accounts stay.
-- Apply to the characters database (acore_chars) while the worldserver is STOPPED: a running server
-- holds the quest log in memory and saves the rows back. Reads acore_logon.account, the auth database
-- of this realm; change the name if yours differs. Running it twice deletes nothing the second time.

DELETE qs FROM `character_queststatus` qs
    JOIN `characters` ch ON ch.`guid` = qs.`guid`
    JOIN `acore_logon`.`account` a ON a.`id` = ch.`account`
WHERE qs.`quest` IN (820062, 81300, 81301)
    AND a.`username` LIKE 'RNDBOT%';
