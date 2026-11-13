--
-- 67 imported Cataclysm quests carried QUEST_FLAGS_AUTOCOMPLETE (0x10000) while having real objectives.
-- In Cataclysm the flag means "turn in from the field once the objectives are done"; in this core
-- Quest::IsAutoComplete() is the flag alone, and CanRewardQuest / CMSG_QUESTGIVER_COMPLETE_QUEST
-- then skip the objective check: the starter offered the reward straight away (the Hyjal dailies
-- 29101/29125/29147/29161/29164 paid Emberwood Sap, the T4/T5 upgrade currency, with nothing done).
--
-- Fix: drop the flag, and list the quests in dc_quest_auto_complete so the QPOP "ready to turn in"
-- popup keeps the field turn-in. That path requires QUEST_STATUS_COMPLETE, i.e. the objectives.
-- Selection: (Flags & 65536) <> 0 AND any RequiredNpcOrGo1-4 / RequiredItemId1-6 set (2026-11-10).
--

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (13892, 14129, 14134, 14135, 14146, 14215, 14323, 25622);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(13892, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(14129, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(14134, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(14135, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(14146, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(14215, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(14323, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(25622, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (25729, 26256, 26261, 26426, 26875, 26937, 27010, 27040);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(25729, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(26256, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(26261, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(26426, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(26875, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(26937, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27010, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27040, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (27041, 27054, 27095, 27100, 27102, 27151, 27152, 27153);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(27041, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27054, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27095, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27100, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27102, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27151, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27152, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27153, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (27154, 27181, 27364, 27371, 27401, 27451, 27452, 27453);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(27154, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27181, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27364, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27371, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27401, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27451, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27452, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27453, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (27513, 27934, 28044, 28129, 28131, 28153, 28189, 28219);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(27513, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(27934, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28044, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28129, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28131, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28153, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28189, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28219, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (28220, 28221, 28222, 28224, 28229, 28261, 28329, 28355);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(28220, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28221, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28222, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28224, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28229, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28261, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28329, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28355, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (28538, 28566, 28603, 28640, 28641, 28643, 28644, 28645);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(28538, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28566, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28603, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28640, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28641, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28643, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28644, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28645, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (28646, 28719, 28735, 28745, 29101, 29125, 29147, 29161);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(28646, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28719, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28735, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(28745, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(29101, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(29125, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(29147, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(29161, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');

DELETE FROM `dc_quest_auto_complete` WHERE `quest_id` IN (29164, 29249, 29437);
INSERT INTO `dc_quest_auto_complete` (`quest_id`, `enabled`, `comment`) VALUES
(29164, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(29249, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10'),
(29437, 1, 'Cata import: AUTOCOMPLETE flag removed 2026-11-10');
UPDATE `quest_template` SET `Flags` = `Flags` & ~65536 WHERE `ID` IN (
    13892, 14129, 14134, 14135, 14146, 14215, 14323, 25622, 25729, 26256,
    26261, 26426, 26875, 26937, 27010, 27040, 27041, 27054, 27095, 27100,
    27102, 27151, 27152, 27153, 27154, 27181, 27364, 27371, 27401, 27451,
    27452, 27453, 27513, 27934, 28044, 28129, 28131, 28153, 28189, 28219,
    28220, 28221, 28222, 28224, 28229, 28261, 28329, 28355, 28538, 28566,
    28603, 28640, 28641, 28643, 28644, 28645, 28646, 28719, 28735, 28745,
    29101, 29125, 29147, 29161, 29164, 29249, 29437);
