-- ====================================================================================
-- ONBOARDING: "A Harder Road" (quest 820059) - go look at the Challenge Mode Manager
-- ====================================================================================
-- Database: acore_world
--
-- Third follow-up to "Welcome to Azshara Crater" (820056). Hervikus the Chaotic
-- (800009) both offers and receives it, so the player never leaves the spawn camp;
-- it sits beside the existing 820057 (Warden Stonebrook) and 820058 (The Watchful
-- Eye) branches rather than being spliced into that chain.
--
-- HOW THE OBJECTIVE COMPLETES
-- The Challenge Mode Manager is gameobject_template 700010 (type 10, GOOBER,
-- ScriptName gobject_challenge_modes), spawned on map 37 at (144.72, 970.02, 295.37),
-- a few paces from Hervikus. The objective is the normal "use this gameobject" kind
-- (RequiredNpcOrGo1 = -700010), which the client shows as complete the moment the
-- manager's UI opens.
--
-- REQUIRES A WORLDSERVER REBUILD. gobject_challenge_modes::OnGossipHello returns
-- true, and GameObject::Use() bails out at that return - so the GOOBER branch that
-- normally hands out the gameobject quest credit never runs. The matching core change
-- adds an explicit Player::KillCreditGO() at the top of that hook
-- (src/server/scripts/DC/Progression/ChallengeMode/dc_challenge_modes_customized.cpp).
-- Without it the quest can be picked up but never completes.
--
-- DO NOT set Data1 (goober.questId) on 700010. An earlier revision of this file did,
-- believing it was only read for players holding 820059; it is not. Any goober with
-- questId > 0 gets GameObjectTemplate::IsForQuests (ObjectMgr::LoadGameObjectForQuests),
-- which makes GameObject::ActivateToQuest() the gate for GO_DYNFLAG_LO_ACTIVATE in
-- GameObject::BuildValuesUpdate - and without that dynamic flag the client refuses to
-- let a quest-flagged goober be clicked at all. The manager went dead for everyone who
-- was not holding 820059 (GMs excepted, they get ACTIVATE unconditionally).
--
-- The sparkle needs no template change: ActivateToQuest() tests HasQuestForGO(700010)
-- FIRST, before the IsForQuests gate, and RequiredNpcOrGo1 = -700010 above already
-- satisfies that while the quest is in the log.
-- ====================================================================================

-- --------------------------------------------------------------------------------
-- Quest
-- --------------------------------------------------------------------------------
DELETE FROM `quest_template` WHERE `ID` = 820059;
INSERT INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `QuestInfoID`, `SuggestedGroupNum`, `RewardXPDifficulty`, `RewardMoney`, `RewardItem1`, `RewardAmount1`, `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`, `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`, `ObjectiveText1`) VALUES
(820059, 2, 1, 1, 0, 0, 0, 1, 0, 300311, 1,
 'A Harder Road',
 'Examine the Challenge Mode Manager near the camp, then return to Hervikus the Chaotic.',
 'Sooner or later everyone who wanders into this crater stands before the Challenge Mode Manager, $N.$B$BIt is not decoration. Speak to it and it will offer you a harder road - hardcore, self-crafted, slow and steady, and stranger trials besides. Take one up and the world will test you the way it tested the first of us. Take none, and nobody here will think the less of you for it.$B$BGo and look upon it. Read what it offers. Then come back and tell me what you make of it.',
 'Azshara Crater',
 'Return to Hervikus the Chaotic.',
 -700010, 1,
 'Challenge Mode Manager examined');

DELETE FROM `quest_template_addon` WHERE `ID` = 820059;
INSERT INTO `quest_template_addon` (`ID`, `PrevQuestID`) VALUES
(820059, 820056);

DELETE FROM `quest_offer_reward` WHERE `ID` = 820059;
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`, `VerifiedBuild`) VALUES
(820059, 'Ha! I knew that stone would catch your eye. Most walk straight past it and wonder later why the crater never bit back hard enough.$B$BTake the token, $N. Whatever road you choose, you will want it.', 0);

-- --------------------------------------------------------------------------------
-- Quest giver / receiver: Hervikus the Chaotic (800009)
-- --------------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `id` = 800009 AND `quest` = 820059;
INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(800009, 820059);

DELETE FROM `creature_questender` WHERE `id` = 800009 AND `quest` = 820059;
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(800009, 820059);

-- --------------------------------------------------------------------------------
-- The Challenge Mode Manager must NOT be quest-gated - see the header. Forced back to
-- 0 here so re-running this file cannot resurrect the unclickable-manager bug.
-- --------------------------------------------------------------------------------
UPDATE `gameobject_template` SET `Data1` = 0 WHERE `entry` = 700010;

-- --------------------------------------------------------------------------------
-- Quest POI - objective box around the manager, turn-in box around Hervikus.
-- Map 37, WorldMapAreaId 613, same shape the generated Azshara Crater POIs use.
-- --------------------------------------------------------------------------------
DELETE FROM `quest_poi` WHERE `QuestID` = 820059;
DELETE FROM `quest_poi_points` WHERE `QuestID` = 820059;

INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES
(820059, 0,  0, 37, 613, 0, 0, 3, 0),
(820059, 1, -1, 37, 613, 0, 0, 1, 0);

INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(820059, 0, 0, 125, 950, 0),
(820059, 0, 1, 125, 990, 0),
(820059, 0, 2, 165, 990, 0),
(820059, 0, 3, 165, 950, 0),
(820059, 1, 0, 110, 980, 0),
(820059, 1, 1, 110, 1020, 0),
(820059, 1, 2, 150, 1020, 0),
(820059, 1, 3, 150, 980, 0);
