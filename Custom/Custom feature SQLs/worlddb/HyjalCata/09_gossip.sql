-- Mount Hyjal (DCMountHyjal, map 750)
-- dc_entry = 3,600,000 + original (isolated, tunable). Source cata_world(TDB434)->acore_world. Cross-DB INSERT...SELECT.
SET @OFF := 3600000;

INSERT IGNORE INTO acore_world.gossip_menu (`MenuID`, `TextID`)
SELECT gm.MenuID, gm.TextID FROM cata_world.gossip_menu gm
JOIN (SELECT DISTINCT ct.gossip_menu_id AS mid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.gossip_menu_id > 0 AND (c.map=1 AND c.zoneId=616) AND ac.entry IS NULL) M ON M.mid = gm.MenuID;
INSERT IGNORE INTO acore_world.npc_text (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`, `text1_0`, `text1_1`, `BroadcastTextID1`, `lang1`, `Probability1`, `text2_0`, `text2_1`, `BroadcastTextID2`, `lang2`, `Probability2`, `text3_0`, `text3_1`, `BroadcastTextID3`, `lang3`, `Probability3`, `text4_0`, `text4_1`, `BroadcastTextID4`, `lang4`, `Probability4`, `text5_0`, `text5_1`, `BroadcastTextID5`, `lang5`, `Probability5`, `text6_0`, `text6_1`, `BroadcastTextID6`, `lang6`, `Probability6`, `text7_0`, `text7_1`, `BroadcastTextID7`, `lang7`, `Probability7`, `VerifiedBuild`)
SELECT nt.`ID`, nt.`text0_0`, nt.`text0_1`, nt.`BroadcastTextID0`, nt.`lang0`, nt.`Probability0`, nt.`text1_0`, nt.`text1_1`, nt.`BroadcastTextID1`, nt.`lang1`, nt.`Probability1`, nt.`text2_0`, nt.`text2_1`, nt.`BroadcastTextID2`, nt.`lang2`, nt.`Probability2`, nt.`text3_0`, nt.`text3_1`, nt.`BroadcastTextID3`, nt.`lang3`, nt.`Probability3`, nt.`text4_0`, nt.`text4_1`, nt.`BroadcastTextID4`, nt.`lang4`, nt.`Probability4`, nt.`text5_0`, nt.`text5_1`, nt.`BroadcastTextID5`, nt.`lang5`, nt.`Probability5`, nt.`text6_0`, nt.`text6_1`, nt.`BroadcastTextID6`, nt.`lang6`, nt.`Probability6`, nt.`text7_0`, nt.`text7_1`, nt.`BroadcastTextID7`, nt.`lang7`, nt.`Probability7`, nt.`VerifiedBuild` FROM cata_world.npc_text nt
JOIN (SELECT DISTINCT gm.TextID AS tid FROM cata_world.gossip_menu gm JOIN (SELECT DISTINCT ct.gossip_menu_id AS mid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.gossip_menu_id > 0 AND (c.map=1 AND c.zoneId=616) AND ac.entry IS NULL) M ON M.mid = gm.MenuID WHERE gm.TextID>0) T ON T.tid = nt.ID;
INSERT IGNORE INTO acore_world.gossip_menu_option (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`)
SELECT gmo.`MenuID`, gmo.`OptionID`, gmo.`OptionIcon`, gmo.`OptionText`, gmo.`OptionBroadcastTextID`, gmo.`OptionType`, gmo.`OptionNpcFlag`, gmo.`ActionMenuID`, gmo.`ActionPoiID`, gmo.`BoxCoded`, gmo.`BoxMoney`, gmo.`BoxText`, gmo.`BoxBroadcastTextID`, gmo.`VerifiedBuild` FROM cata_world.gossip_menu_option gmo
JOIN (SELECT DISTINCT ct.gossip_menu_id AS mid
  FROM cata_world.creature_template ct
  JOIN cata_world.creature c ON c.id = ct.entry
  LEFT JOIN acore_world.creature_template ac ON ac.entry = ct.entry AND ac.entry < @OFF
  WHERE ct.gossip_menu_id > 0 AND (c.map=1 AND c.zoneId=616) AND ac.entry IS NULL) M ON M.mid = gmo.MenuID;
