-- Blackwing Descent (map 669) — creature_text (boss/add yells & emotes) + Finkle gossip
-- Source: cata_world.creature_text (104 lines / 20 entries). Cross-schema INSERT...SELECT copies
-- the Text verbatim (no manual escaping). Cata's extra SoundType column is dropped.
-- All BroadcastTextIds referenced already exist in acore_world.broadcast_text (no broadcast_text port).

-- ---------------------------------------------------------------------------
-- creature_text
-- ---------------------------------------------------------------------------
DELETE FROM `creature_text` WHERE `CreatureID` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506);

INSERT INTO `creature_text`
    (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT
    `CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`
FROM `cata_world`.`creature_text`
WHERE `CreatureID` IN (35592,41270,41376,41378,41379,41442,41445,41505,41546,41570,41576,41620,41767,41789,41806,41841,41843,41879,41948,41961,41962,42098,42166,42178,42179,42180,42186,42321,42347,42356,42362,42595,42649,42690,42733,42764,42767,42768,42800,42802,42803,42856,42897,42920,42934,42947,42949,42951,42954,42956,42958,42960,43119,43122,43125,43126,43127,43128,43129,43130,43206,43296,43404,43407,43656,44202,44418,46083,48270,48964,49226,49416,49427,49447,49580,49623,49679,49740,49799,49811,51089,51506);

-- ---------------------------------------------------------------------------
-- Finkle Einhorn (44202) gossip — creature_template.gossip_menu_id = 11812 (npc_text 16565 is stock).
-- The follow-up ActionMenuID (11834) chain is not ported (minor RP); the option just closes.
-- ---------------------------------------------------------------------------
DELETE FROM `gossip_menu` WHERE `MenuID` = 11812;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (11812, 16565);

DELETE FROM `gossip_menu_option` WHERE `MenuID` = 11812;
INSERT INTO `gossip_menu_option`
    (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`,
     `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`)
VALUES
    (11812, 0, 0, 'I suppose you''ll be needing a key for this cage? Wait, don''t tell me. The horrific gibbering monster behind me ate it, right?', 0, 1, 1, 0, 0, 0, 0, NULL, 0, 0);
