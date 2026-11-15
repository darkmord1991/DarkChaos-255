-- DarkChaos: repair the Darkshore naga chain on map 750, 13953 -> 13899 -> 13900 (2026-11-14)
--
-- The chain stopped after its first step for everyone: 77 characters hold 13899 complete and none has ever
-- turned it in.
-- * 13899 "The Darkscale Warlord" had no objective and ended at Warlord Wrathspine (3734423) himself, a level 90
--   naga on faction 74, hostile to every player. The core refuses quest dialogs with hostile NPCs. In Cata the
--   kill and the turn-in at his corpse were scripted; none of that was ported.
-- * 13900 "The Offering to Azshara" started at that hostile warlord, needed kill credit 3751314 "Azshara Event
--   Credit" (no spawn, nothing gives it) and ended at Malfurion 3734422 (not spawned anywhere).
--
-- Repair, data only:
-- * 13899: slay Warlord Wrathspine (1), then return to Balren of the Claw (3734402) at the Grove of the
--   Ancients, who also gives the quest. His reward text now says the horn was not on the warlord.
-- * 13900: Balren gives it and takes it back. The objective is 3 Darkscale Priestesses (3734415), the four
--   that stand on the ritual platform above Nazj'vel. npc_offering_to_azshara_controller still summons four
--   more when a player on the quest arrives and none are alive.
-- * Wrathspine loses his questgiver flag. He and the 4 priestesses respawn after 120 s instead of 300 s, like
--   other 750/751 quest targets (bots queue on single spawns).
-- * Both turn-in markers move to Balren. No objective markers on purpose: Nazj'vel is under water (the
--   warlord is at z -38) and playerbots aim at max(terrain, water level), which is the surface. Without a
--   marker they use the spawn positions at their real height.
-- Characters that hold 13899 complete keep that status (it is not re-checked at login), so they can turn it
-- in to Balren straight away and get 13900 offered.
--
-- Original values (cata_world has the same): 13899 objective none, ender 3734423, completion log empty, reward
-- text "The warlord doesn't seem to have the horn on him.  Perhaps he was telling the truth.". 13900 objective
-- 3751314 x1 "Offering to Azshara prevented", starter 3734423, ender 3734422, description "The warlord said the
-- horn of the ancients was being offered to Azshara above Nazj'vel.$B$BPerhaps it's not too late to save the
-- ancient relic from being destroyed.". npcflag of 3734423 was 2, spawntimesecs 300.
-- Re-running the file is a no-op. Apply to acore_world, then restart the worldserver.

-- 1. objectives and texts
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3734423, `RequiredNpcOrGoCount1` = 1,
    `QuestCompletionLog` = 'Return to Balren of the Claw at the Grove of the Ancients in Darkshore.'
    WHERE `ID` = 13899;
UPDATE `quest_template` SET `RequiredNpcOrGo1` = 3734415, `RequiredNpcOrGoCount1` = 3, `ObjectiveText1` = '',
    `QuestDescription` = 'Wrathspine is dead, but the horn of the ancients was not on him. If the naga have it, their priestesses will be offering it to Azshara on the platform above Nazj''vel.$B$BGo back and stop them, $n. Perhaps it''s not too late to save the ancient relic from being destroyed.',
    `QuestCompletionLog` = 'Return to Balren of the Claw at the Grove of the Ancients in Darkshore.'
    WHERE `ID` = 13900;
UPDATE `quest_offer_reward` SET `RewardText` = 'Wrathspine is dead? Good... but he did not have the horn of the ancients on him.$B$BIf the naga still have it, I fear they mean to give it to their queen.'
    WHERE `ID` = 13899;
DELETE FROM `quest_request_items` WHERE `ID` IN (13899, 13900);
INSERT INTO `quest_request_items` (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`, `VerifiedBuild`) VALUES
(13899, 1, 1, 'Have you found the warlord, $n?', 0),
(13900, 1, 1, 'Have you stopped the priestesses? The horn of the ancients must not reach Azshara.', 0);

-- 2. Balren gives and takes both quests
DELETE FROM `creature_queststarter` WHERE `quest` = 13900;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES (3734402, 13900);
DELETE FROM `creature_questender` WHERE `quest` IN (13899, 13900);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(3734402, 13899),
(3734402, 13900);
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~2 WHERE `entry` = 3734423;

-- 3. quest targets respawn like other 750/751 quest targets
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3734423 AND `guid` = 15862017;
UPDATE `creature` SET `spawntimesecs` = 120 WHERE `id` = 3734415 AND `guid` IN (15862005, 15862006, 15862007, 15862008);

-- 4. turn-in markers on Balren (4984, 88), Darkshore world map 1259
DELETE FROM `quest_poi_points` WHERE `QuestID` = 13899 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(13899, 0, 0, 4984, 88, 0);
DELETE FROM `quest_poi_points` WHERE `QuestID` = 13900 AND `Idx1` = 0;
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(13900, 0, 0, 4984, 88, 0);
