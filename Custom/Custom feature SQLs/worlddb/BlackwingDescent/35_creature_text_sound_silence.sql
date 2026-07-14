-- ---------------------------------------------------------------------------
-- creature_text -- silence Sound references with no matching Sound.dbc entry
-- ---------------------------------------------------------------------------
-- "CreatureTextMgr: Entry N, Group G in table `creature_texts` has Sound S
-- but sound does not exist." across 12 BWD boss/NPC entries (Nefarian,
-- Maloriak x2, Lord Victor Nefarius x5, Atramedes, Omnotron, Finkle
-- Einhorn). These are real Cata boss voice-line SoundEntries ids that were
-- never downported (would require extracting audio assets from the real
-- Cata client and repacking the client patch -- explicitly deferred, see
-- memory). Engine already falls back to no sound at load (temp.sound = 0),
-- text/emote still fire -- purely cosmetic. Nulled at the source per user
-- request (2026-07-14) to quiet the boot log instead of pursuing full VO.
-- ---------------------------------------------------------------------------
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 41376 AND `Sound` IN (20073,20155,20075,20077,20079,20074,20080,20081,20083,20078);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 41378 AND `Sound` IN (19847,19851,19853,19852,19856,19857,19859,19858,19854,19848,19849,19850);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 41379 AND `Sound` IN (20066,20070,20071);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 41442 AND `Sound` IN (20820,20826,20827,20822,20821,20823);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 42186 AND `Sound` IN (21865,21867,21866,23378,21871,21869,21872,21870,21873,21864);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 43404 AND `Sound` IN (19860,19861,19862,19863,19864,19865,19866,19867);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 44202 AND `Sound` IN (20835,20834,20833,20836,20838);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 48964 AND `Sound` IN (23362,23364,23365,23361,23379,20090,20085,20086,20088,20089,20087);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 49226 AND `Sound` IN (23377,23374,23378,23375,23376);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 49427 AND `Sound` IN (23367,23369,23368,23366);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 49580 AND `Sound` IN (23360,23359,23358);
UPDATE `creature_text` SET `Sound` = 0 WHERE `CreatureID` = 49799 AND `Sound` IN (23372,23370,23371);
