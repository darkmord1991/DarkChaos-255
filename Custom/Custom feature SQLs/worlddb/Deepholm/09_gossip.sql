-- =====================================================================
-- Deepholm Downport  --  09  Gossip  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
--
-- 48 Deepholm gossip menus, of which 2 (83 = Spirit Healer, 9821) already exist
-- as stock and are EXCLUDED (never overwritten). 51 referenced npc_text ids, of
-- which 49 are stock greetings (kept via INSERT IGNORE) -- only the ~2 new rows
-- are added.
--
-- Mapping notes:
--   * gossip_menu_option: Cata 4.3.4 splits the row across 3 tables. This DENORMALIZES
--     gossip_menu_option + gossip_menu_option_action (ActionMenuId/ActionPoiId) +
--     gossip_menu_option_box (BoxCoded/BoxMoney/BoxText/BoxBroadcastTextId) back into
--     this fork's flat gossip_menu_option. Cata OptionIndex->OptionID, OptionNpcflag->OptionNpcFlag.
--   * npc_text: Cata has 3 EmoteDelay/Emote pairs per block; this fork has 6 emote slots
--     and no delays. em{i}_0..2 <- Emote{i}_0..2, em{i}_3..5 <- 0, delays dropped.
-- =====================================================================

-- ---------------------------------------------------------------------
-- gossip_menu  (exclude stock menus 83, 9821)
-- ---------------------------------------------------------------------
DELETE FROM `gossip_menu`
WHERE `MenuID` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `gossip_menu_id` > 0)
  AND `MenuID` NOT IN (83, 9821);

INSERT INTO `gossip_menu` (`MenuID`, `TextID`)
SELECT gm.`MenuID`, gm.`TextID`
FROM `cata_world`.`gossip_menu` gm
WHERE gm.`MenuID` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `gossip_menu_id` > 0)
  AND gm.`MenuID` NOT IN (83, 9821);

-- ---------------------------------------------------------------------
-- npc_text  (only new ids added; 49/51 are stock greetings -> INSERT IGNORE)
-- ---------------------------------------------------------------------
INSERT IGNORE INTO `npc_text`
(`ID`,
 `text0_0`,`text0_1`,`BroadcastTextID0`,`lang0`,`Probability0`,`em0_0`,`em0_1`,`em0_2`,`em0_3`,`em0_4`,`em0_5`,
 `text1_0`,`text1_1`,`BroadcastTextID1`,`lang1`,`Probability1`,`em1_0`,`em1_1`,`em1_2`,`em1_3`,`em1_4`,`em1_5`,
 `text2_0`,`text2_1`,`BroadcastTextID2`,`lang2`,`Probability2`,`em2_0`,`em2_1`,`em2_2`,`em2_3`,`em2_4`,`em2_5`,
 `text3_0`,`text3_1`,`BroadcastTextID3`,`lang3`,`Probability3`,`em3_0`,`em3_1`,`em3_2`,`em3_3`,`em3_4`,`em3_5`,
 `text4_0`,`text4_1`,`BroadcastTextID4`,`lang4`,`Probability4`,`em4_0`,`em4_1`,`em4_2`,`em4_3`,`em4_4`,`em4_5`,
 `text5_0`,`text5_1`,`BroadcastTextID5`,`lang5`,`Probability5`,`em5_0`,`em5_1`,`em5_2`,`em5_3`,`em5_4`,`em5_5`,
 `text6_0`,`text6_1`,`BroadcastTextID6`,`lang6`,`Probability6`,`em6_0`,`em6_1`,`em6_2`,`em6_3`,`em6_4`,`em6_5`,
 `text7_0`,`text7_1`,`BroadcastTextID7`,`lang7`,`Probability7`,`em7_0`,`em7_1`,`em7_2`,`em7_3`,`em7_4`,`em7_5`,
 `VerifiedBuild`)
SELECT n.`ID`,
 n.`text0_0`,n.`text0_1`,n.`BroadcastTextID0`,n.`lang0`,n.`Probability0`,n.`Emote0_0`,n.`Emote0_1`,n.`Emote0_2`,0,0,0,
 n.`text1_0`,n.`text1_1`,n.`BroadcastTextID1`,n.`lang1`,n.`Probability1`,n.`Emote1_0`,n.`Emote1_1`,n.`Emote1_2`,0,0,0,
 n.`text2_0`,n.`text2_1`,n.`BroadcastTextID2`,n.`lang2`,n.`Probability2`,n.`Emote2_0`,n.`Emote2_1`,n.`Emote2_2`,0,0,0,
 n.`text3_0`,n.`text3_1`,n.`BroadcastTextID3`,n.`lang3`,n.`Probability3`,n.`Emote3_0`,n.`Emote3_1`,n.`Emote3_2`,0,0,0,
 n.`text4_0`,n.`text4_1`,n.`BroadcastTextID4`,n.`lang4`,n.`Probability4`,n.`Emote4_0`,n.`Emote4_1`,n.`Emote4_2`,0,0,0,
 n.`text5_0`,n.`text5_1`,n.`BroadcastTextID5`,n.`lang5`,n.`Probability5`,n.`Emote5_0`,n.`Emote5_1`,n.`Emote5_2`,0,0,0,
 n.`text6_0`,n.`text6_1`,n.`BroadcastTextID6`,n.`lang6`,n.`Probability6`,n.`Emote6_0`,n.`Emote6_1`,n.`Emote6_2`,0,0,0,
 n.`text7_0`,n.`text7_1`,n.`BroadcastTextID7`,n.`lang7`,n.`Probability7`,n.`Emote7_0`,n.`Emote7_1`,n.`Emote7_2`,0,0,0,
 0
FROM `cata_world`.`npc_text` n
WHERE n.`ID` IN (
  SELECT DISTINCT gm.`TextID` FROM `cata_world`.`gossip_menu` gm
  WHERE gm.`MenuID` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `gossip_menu_id` > 0)
    AND gm.`TextID` > 0);

-- ---------------------------------------------------------------------
-- gossip_menu_option  (denormalize 3 Cata tables -> flat; exclude stock menus)
-- ---------------------------------------------------------------------
DELETE FROM `gossip_menu_option`
WHERE `MenuID` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `gossip_menu_id` > 0)
  AND `MenuID` NOT IN (83, 9821);

INSERT INTO `gossip_menu_option`
(`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`,
 `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`)
SELECT o.`MenuId`, o.`OptionIndex`, o.`OptionIcon`, o.`OptionText`, o.`OptionBroadcastTextId`, o.`OptionType`, o.`OptionNpcflag`,
 COALESCE(a.`ActionMenuId`, 0), COALESCE(a.`ActionPoiId`, 0),
 COALESCE(b.`BoxCoded`, 0), COALESCE(b.`BoxMoney`, 0), COALESCE(b.`BoxText`, ''), COALESCE(b.`BoxBroadcastTextId`, 0),
 o.`VerifiedBuild`
FROM `cata_world`.`gossip_menu_option` o
LEFT JOIN `cata_world`.`gossip_menu_option_action` a ON a.`MenuId` = o.`MenuId` AND a.`OptionIndex` = o.`OptionIndex`
LEFT JOIN `cata_world`.`gossip_menu_option_box` b ON b.`MenuId` = o.`MenuId` AND b.`OptionIndex` = o.`OptionIndex`
WHERE o.`MenuId` IN (SELECT DISTINCT `gossip_menu_id` FROM `cata_world`.`creature_template` WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`creature` WHERE `map` = 646) AND `gossip_menu_id` > 0)
  AND o.`MenuId` NOT IN (83, 9821);
