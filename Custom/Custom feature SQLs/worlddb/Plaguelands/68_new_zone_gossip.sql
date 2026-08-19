-- 68_new_zone_gossip.sql — map 751 Lordaeron extension, DB step 7.
--
-- Gossip menus + options for the imported NPCs, and the gossip_menu_id that 62_
-- deliberately left at 0. REQUIRES 62_. Also clears the handful of dead AINames
-- 66_ could not satisfy.
--
-- 202 of our templates want a menu; 164 distinct menu ids are involved.
--
-- MENU IDS ARE A SHARED SPACE, so the same three-way split as the quest import:
--   * acore already has the EXACT (MenuID, TextID) pair  -> REUSE it untouched.
--     170 pairs match. Reusing means the stock menu and its stock options serve our
--     NPC too, which is right: it is the same dialogue.
--   * MenuID absent from acore entirely                  -> INSERT at the raw id.
--   * MenuID present but pointing at a DIFFERENT TextID  -> RELOCATE to
--     MenuID + 4,100,000. **8 menus hit this.** Reusing them would put unrelated
--     dialogue in our NPCs' mouths; overwriting them would change stock NPCs.
--     The 4,100,000-4,199,999 gossip band was verified empty.
--
-- npc_text is effectively a shared global string pool — 207 of the 208 referenced
-- ids already exist in acore, so texts are NOT copied. The one missing id is
-- reported at the bottom; its menu will show an empty body until backfilled.
--
-- `gossip_menu` is just (MenuID, TextID). `gossip_menu_option` shares all 14
-- columns with acore and has no nullability mismatches. `ActionMenuID` chains one
-- menu to another and is remapped whenever it points at a relocated menu.

SET @GMOFF := 4100000;

-- ---------------------------------------------------------------------------
-- Decide, per menu id, whether to reuse / insert / relocate
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map751_gossip_map`;
CREATE TABLE `dc_map751_gossip_map` (
  `src_menu` INT UNSIGNED NOT NULL,
  `new_menu` INT UNSIGNED NOT NULL,
  `mode`     ENUM('reuse','insert','relocate') NOT NULL,
  PRIMARY KEY (`src_menu`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map751_gossip_map` (`src_menu`,`new_menu`,`mode`)
SELECT d.`menu`,
       IF(d.`conflict` = 1, d.`menu` + @GMOFF, d.`menu`),
       CASE WHEN d.`conflict` = 1 THEN 'relocate'
            WHEN d.`in_acore`  = 1 THEN 'reuse'
            ELSE 'insert' END
FROM (
  SELECT DISTINCT t.`gossip_menu_id` AS `menu`,
         EXISTS(SELECT 1 FROM `gossip_menu` a WHERE a.`MenuID` = t.`gossip_menu_id`) AS `in_acore`,
         (    EXISTS(SELECT 1 FROM `gossip_menu` a2 WHERE a2.`MenuID` = t.`gossip_menu_id`)
          AND NOT EXISTS(
                SELECT 1 FROM `cata_world`.`gossip_menu` cg
                JOIN `gossip_menu` a3 ON a3.`MenuID` = cg.`MenuID` AND a3.`TextID` = cg.`TextID`
                WHERE cg.`MenuID` = t.`gossip_menu_id`)
         ) AS `conflict`
  FROM `cata_world`.`creature_template` t
  JOIN `dc_map751_src_creature` s ON s.`id` = t.`entry`
  WHERE t.`gossip_menu_id` > 0
) d;

-- ---------------------------------------------------------------------------
-- Menus we own (insert + relocate). Reused ids are never written to.
-- ---------------------------------------------------------------------------
DELETE FROM `gossip_menu`        WHERE `MenuID` BETWEEN 4100000 AND 4199999;
DELETE FROM `gossip_menu_option` WHERE `MenuID` BETWEEN 4100000 AND 4199999;
DELETE g FROM `gossip_menu` g
  JOIN `dc_map751_gossip_map` m ON m.`new_menu` = g.`MenuID` AND m.`mode` = 'insert';
DELETE o FROM `gossip_menu_option` o
  JOIN `dc_map751_gossip_map` m ON m.`new_menu` = o.`MenuID` AND m.`mode` = 'insert';

INSERT INTO `gossip_menu` (`MenuID`,`TextID`)
SELECT m.`new_menu`, cg.`TextID`
FROM `cata_world`.`gossip_menu` cg
JOIN `dc_map751_gossip_map` m ON m.`src_menu` = cg.`MenuID`
WHERE m.`mode` IN ('insert','relocate');

INSERT INTO `gossip_menu_option`
 (`MenuID`,`OptionID`,`OptionIcon`,`OptionText`,`OptionBroadcastTextID`,`OptionType`,
  `OptionNpcFlag`,`ActionMenuID`,`ActionPoiID`,`BoxCoded`,`BoxMoney`,`BoxText`,
  `BoxBroadcastTextID`,`VerifiedBuild`)
SELECT
  m.`new_menu`, co.`OptionID`, co.`OptionIcon`, co.`OptionText`, co.`OptionBroadcastTextID`,
  co.`OptionType`, co.`OptionNpcFlag`,
  -- a chained menu that we relocated must be followed to its new id
  COALESCE((SELECT m2.`new_menu` FROM `dc_map751_gossip_map` m2
             WHERE m2.`src_menu` = co.`ActionMenuID` AND m2.`mode` = 'relocate'),
           co.`ActionMenuID`),
  co.`ActionPoiID`, co.`BoxCoded`, co.`BoxMoney`, co.`BoxText`,
  co.`BoxBroadcastTextID`, co.`VerifiedBuild`
FROM `cata_world`.`gossip_menu_option` co
JOIN `dc_map751_gossip_map` m ON m.`src_menu` = co.`MenuID`
WHERE m.`mode` IN ('insert','relocate');

-- ---------------------------------------------------------------------------
-- Point the imported templates at their menu (62_ left this at 0)
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
  JOIN `cata_world`.`creature_template` ct ON ct.`entry` = t.`entry` - 4100000
  JOIN `dc_map751_gossip_map` m ON m.`src_menu` = ct.`gossip_menu_id`
  SET t.`gossip_menu_id` = m.`new_menu`
  WHERE t.`entry` BETWEEN 4100000 AND 4199999;

-- ---------------------------------------------------------------------------
-- Tidy: 66_ left a few templates claiming SmartAI with no script rows. An AIName
-- with nothing behind it is a load-time complaint and no AI at all, so clear it.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` t
  SET t.`AIName` = ''
  WHERE t.`entry` BETWEEN 4100000 AND 4199999
    AND t.`AIName` = 'SmartAI'
    AND NOT EXISTS(SELECT 1 FROM `smart_scripts` s WHERE s.`source_type` = 0 AND s.`entryorguid` = t.`entry`);

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT `mode`, COUNT(*) AS menus FROM `dc_map751_gossip_map` GROUP BY `mode`;

SELECT 'templates now pointing at a menu' AS what, COUNT(*) AS n
FROM `creature_template` WHERE `entry` BETWEEN 4100000 AND 4199999 AND `gossip_menu_id` > 0
UNION ALL SELECT 'gossip_menu rows written', COUNT(*) FROM `gossip_menu` g
  JOIN `dc_map751_gossip_map` m ON m.`new_menu` = g.`MenuID` WHERE m.`mode` IN ('insert','relocate')
UNION ALL SELECT 'gossip_menu_option rows written', COUNT(*) FROM `gossip_menu_option` o
  JOIN `dc_map751_gossip_map` m ON m.`new_menu` = o.`MenuID` WHERE m.`mode` IN ('insert','relocate')
UNION ALL SELECT 'AINames cleared (no scripts behind them)', 0 + (
  SELECT COUNT(*) FROM `creature_template` WHERE `entry` BETWEEN 4100000 AND 4199999 AND `AIName` = '');

-- must be zero: a template pointing at a menu that has no gossip_menu row
SELECT 'PROBLEM: gossip_menu_id with no menu row' AS problem, COUNT(*) AS n
FROM `creature_template` t
WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND t.`gossip_menu_id` > 0
  AND NOT EXISTS(SELECT 1 FROM `gossip_menu` g WHERE g.`MenuID` = t.`gossip_menu_id`)
UNION ALL
-- must be zero: an option chaining to a menu that does not exist
SELECT 'PROBLEM: ActionMenuID points nowhere', COUNT(*)
FROM `gossip_menu_option` o
JOIN `dc_map751_gossip_map` m ON m.`new_menu` = o.`MenuID` AND m.`mode` IN ('insert','relocate')
WHERE o.`ActionMenuID` > 0
  AND NOT EXISTS(SELECT 1 FROM `gossip_menu` g WHERE g.`MenuID` = o.`ActionMenuID`)
UNION ALL
-- must be zero: still claiming SmartAI with nothing behind it
SELECT 'PROBLEM: AIName=SmartAI with no scripts', COUNT(*)
FROM `creature_template` t
WHERE t.`entry` BETWEEN 4100000 AND 4199999 AND t.`AIName` = 'SmartAI'
  AND NOT EXISTS(SELECT 1 FROM `smart_scripts` s WHERE s.`source_type` = 0 AND s.`entryorguid` = t.`entry`);

-- the relocated menus, listed so the decision stays visible
SELECT 'RELOCATED (acore had this id with different text)' AS note,
       m.`src_menu`, m.`new_menu` FROM `dc_map751_gossip_map` m WHERE m.`mode` = 'relocate';

-- npc_text ids our menus reference that acore does not have (empty dialogue body)
SELECT 'MISSING npc_text (menu will show no text)' AS note, cg.`TextID`, COUNT(*) AS menus
FROM `cata_world`.`gossip_menu` cg
JOIN `dc_map751_gossip_map` m ON m.`src_menu` = cg.`MenuID` AND m.`mode` IN ('insert','relocate')
LEFT JOIN `npc_text` n ON n.`ID` = cg.`TextID`
WHERE n.`ID` IS NULL
GROUP BY cg.`TextID`;
