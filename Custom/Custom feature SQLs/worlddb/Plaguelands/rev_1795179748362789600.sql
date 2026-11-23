-- DarkChaos 2026-11-20: quest fixes from the 11-20 bot session.
--
-- 1. Quests on maps 750/751/861 that one faction can take but never hand in: every quest ender is hostile to it
--    (FactionTemplate EnemyGroup), while AllowableRaces is 0 or every race. 572 bots held one of these finished on
--    the wrong side and 96 gave up at the turn-in. The enders of all 55 spawn only on 750/751/861, so no stock
--    quest changes. Masks are this server's standard ones (908069965 Alliance, 1237320626 Horde).
UPDATE `quest_template` SET `AllowableRaces` = 908069965 WHERE `ID` IN
(13583, 13585, 13589, 13599, 13867, 13893, 13895, 13896, 13953, 13964, 13965, 13976, 13981, 26079, 26444, 26453,
 26467, 26468, 26469, 26470, 26472, 26476, 27158, 27159, 27165, 27197, 27725, 28674);
UPDATE `quest_template` SET `AllowableRaces` = 1237320626 WHERE `ID` IN
(13801, 13873, 13901, 13923, 13936, 13958, 13974, 13977, 14462, 24463, 26429, 26430, 26921, 27083, 27095, 27117,
 28115, 28168, 28484, 28487, 28508, 28587, 28600, 28620, 28636, 226926, 226979);

-- 2. Named quest targets with a single spawn on 750/751 respawned in 300-500 s, longer than a bot waits at its
--    target (5 min), with dozens of bots queued on each: 2,259 give-ups on one-mob objectives in 4 h. 120 s, as for
--    the other shared quest targets there.
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `map` IN (750, 751) AND `id` IN
(3611897, 3612250, 3634591, 3645450, 3703987, 3748344, 4102597, 4102599, 4104480) AND `guid` IN
(13074466, 13075249, 16462957, 13220655, 16367776, 15830197, 16713774, 16713773, 16714114);
