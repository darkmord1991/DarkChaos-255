-- =====================================================================================
-- Timbermaw Hold (map 819, 20-man) -- loot
--
-- creature_loot_template convention on this server: `lootid` == `entry`, so a boss's loot
-- rows are keyed on its own entry. Never point one of these at a foreign loot id.
--
-- MinCount / MaxCount are `tinyint unsigned`, so the hard ceiling is 255. Token amounts here
-- stay well inside that; scale the base DOWN rather than up if you retune.
--
-- Gear is dropped as an explicit GroupId so exactly one piece rolls per group, rather than
-- every listed item rolling independently and a boss showering the raid.
-- =====================================================================================


DELETE FROM `creature_loot_template` WHERE `Entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007, 4010101, 4010102, 4010103, 4010104, 4010105, 4010106, 4010107, 4010108, 4010109, 4010110, 4010111, 4010112, 4010151, 4010152, 4010153);

INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (4010001, 410024, 0, 25.0, 0, 1, 1, 1, 1, 'Gatewarden Mor''thak - tier gear'),
    (4010001, 410018, 0, 25.0, 0, 1, 1, 1, 1, 'Gatewarden Mor''thak - tier gear'),
    (4010001, 410043, 0, 25.0, 0, 1, 1, 1, 1, 'Gatewarden Mor''thak - tier gear'),
    (4010001, 410015, 0, 25.0, 0, 1, 1, 1, 1, 'Gatewarden Mor''thak - tier gear'),
    (4010001, 300311, 0, 100, 0, 1, 0, 40, 55, 'Gatewarden Mor''thak - upgrade tokens'),
    (4010002, 410004, 0, 25.0, 0, 1, 1, 1, 1, 'The Sundered Chieftain - tier gear'),
    (4010002, 410050, 0, 25.0, 0, 1, 1, 1, 1, 'The Sundered Chieftain - tier gear'),
    (4010002, 410049, 0, 25.0, 0, 1, 1, 1, 1, 'The Sundered Chieftain - tier gear'),
    (4010002, 410026, 0, 25.0, 0, 1, 1, 1, 1, 'The Sundered Chieftain - tier gear'),
    (4010002, 300311, 0, 100, 0, 1, 0, 40, 55, 'The Sundered Chieftain - upgrade tokens'),
    (4010003, 410031, 0, 25.0, 0, 1, 1, 1, 1, 'Den Mother Ursara - tier gear'),
    (4010003, 410053, 0, 25.0, 0, 1, 1, 1, 1, 'Den Mother Ursara - tier gear'),
    (4010003, 410034, 0, 25.0, 0, 1, 1, 1, 1, 'Den Mother Ursara - tier gear'),
    (4010003, 410048, 0, 25.0, 0, 1, 1, 1, 1, 'Den Mother Ursara - tier gear'),
    (4010003, 300311, 0, 100, 0, 1, 0, 40, 55, 'Den Mother Ursara - upgrade tokens'),
    (4010004, 410037, 0, 25.0, 0, 1, 1, 1, 1, 'Xanthir the Defiler - tier gear'),
    (4010004, 410012, 0, 25.0, 0, 1, 1, 1, 1, 'Xanthir the Defiler - tier gear'),
    (4010004, 410044, 0, 25.0, 0, 1, 1, 1, 1, 'Xanthir the Defiler - tier gear'),
    (4010004, 410009, 0, 25.0, 0, 1, 1, 1, 1, 'Xanthir the Defiler - tier gear'),
    (4010004, 300311, 0, 100, 0, 1, 0, 40, 55, 'Xanthir the Defiler - upgrade tokens'),
    (4010005, 410011, 0, 25.0, 0, 1, 1, 1, 1, 'The Nightmare Given Root - tier gear'),
    (4010005, 410045, 0, 25.0, 0, 1, 1, 1, 1, 'The Nightmare Given Root - tier gear'),
    (4010005, 410032, 0, 25.0, 0, 1, 1, 1, 1, 'The Nightmare Given Root - tier gear'),
    (4010005, 410025, 0, 25.0, 0, 1, 1, 1, 1, 'The Nightmare Given Root - tier gear'),
    (4010005, 300311, 0, 100, 0, 1, 0, 40, 55, 'The Nightmare Given Root - upgrade tokens'),
    (4010006, 410030, 0, 25.0, 0, 1, 1, 1, 1, 'Ursol - tier gear'),
    (4010006, 410029, 0, 25.0, 0, 1, 1, 1, 1, 'Ursol - tier gear'),
    (4010006, 410023, 0, 25.0, 0, 1, 1, 1, 1, 'Ursol - tier gear'),
    (4010006, 410051, 0, 25.0, 0, 1, 1, 1, 1, 'Ursol - tier gear'),
    (4010006, 300311, 0, 100, 0, 1, 0, 40, 55, 'Ursol - upgrade tokens'),
    (4010007, 410014, 0, 16.7, 0, 1, 1, 1, 1, 'Ursoc - tier gear'),
    (4010007, 410001, 0, 16.7, 0, 1, 1, 1, 1, 'Ursoc - tier gear'),
    (4010007, 410000, 0, 16.7, 0, 1, 1, 1, 1, 'Ursoc - tier gear'),
    (4010007, 410008, 0, 16.7, 0, 1, 1, 1, 1, 'Ursoc - tier gear'),
    (4010007, 410046, 0, 16.7, 0, 1, 1, 1, 1, 'Ursoc - tier gear'),
    (4010007, 410035, 0, 16.7, 0, 1, 1, 1, 1, 'Ursoc - tier gear'),
    (4010007, 300311, 0, 100, 0, 1, 0, 80, 100, 'Ursoc - upgrade tokens'),
    (4010101, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010102, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010103, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010104, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010105, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010106, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010107, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010108, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010109, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010110, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010111, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010112, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4010151, 410030, 0, 25, 0, 1, 1, 1, 1, 'rare elite - tier gear'),
    (4010151, 300311, 0, 100, 0, 1, 0, 20, 28, 'rare elite - upgrade tokens'),
    (4010152, 410037, 0, 25, 0, 1, 1, 1, 1, 'rare elite - tier gear'),
    (4010152, 300311, 0, 100, 0, 1, 0, 20, 28, 'rare elite - upgrade tokens'),
    (4010153, 410044, 0, 25, 0, 1, 1, 1, 1, 'rare elite - tier gear'),
    (4010153, 300311, 0, 100, 0, 1, 0, 20, 28, 'rare elite - upgrade tokens');

-- Boss token payouts. This is a data hook: `dc_seasonal_creature_rewards` maps a
-- creature to a token/essence payout with no code at all, and the CrossSystem reward
-- distributor applies the prestige/difficulty/seasonal multipliers on top.
DELETE FROM `dc_seasonal_creature_rewards` WHERE `creature_id` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007);
INSERT INTO `dc_seasonal_creature_rewards`
    (`season_id`, `creature_id`, `reward_type`, `base_token_amount`, `base_essence_amount`,
     `creature_rank`, `content_type`, `difficulty_level`, `seasonal_multiplier`,
     `minimum_players`, `group_split_tokens`, `enabled`) VALUES
    (1, 4010001, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4010002, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4010003, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4010004, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4010005, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4010006, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4010007, 1, 1000, 300, 3, 2, 1, 2.5, 20, 1, 1);

-- Great Vault. The raid track needs no new code -- GetRaidBossProgressForWeek()
-- popcounts instance.completedEncounters -- but the gear only becomes a vault CHOICE
-- if it is listed here. armor_type/slot_type/role_mask are read straight off the item.
DELETE FROM `dc_vault_loot_table` WHERE `source` = 'Timbermaw Hold';
INSERT INTO `dc_vault_loot_table`
    (`item_id`, `item_level_min`, `item_level_max`, `class_mask`, `spec_name`, `armor_type`,
     `slot_type`, `role_mask`, `weight`, `source`)
SELECT i.`entry`, 430, 470, 1023, NULL,
       CASE i.`subclass` WHEN 1 THEN 'Cloth' WHEN 2 THEN 'Leather'
                         WHEN 3 THEN 'Mail'  WHEN 4 THEN 'Plate' ELSE 'Misc' END,
       CASE i.`InventoryType`
            WHEN 1 THEN 'Head' WHEN 2 THEN 'Neck' WHEN 3 THEN 'Shoulder' WHEN 5 THEN 'Chest'
            WHEN 6 THEN 'Waist' WHEN 7 THEN 'Legs' WHEN 8 THEN 'Feet' WHEN 9 THEN 'Wrist'
            WHEN 10 THEN 'Hands' WHEN 11 THEN 'Finger' WHEN 12 THEN 'Trinket'
            WHEN 16 THEN 'Back' WHEN 20 THEN 'Chest' ELSE 'Weapon' END,
       7, 10, 'Timbermaw Hold'
FROM `item_template` i WHERE i.`entry` BETWEEN 410000 AND 410053;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'loot rows (want 55)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_loot_template` WHERE `Entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007, 4010101, 4010102, 4010103, 4010104, 4010105, 4010106, 4010107, 4010108, 4010109, 4010110, 4010111, 4010112, 4010151, 4010152, 4010153)
UNION ALL SELECT 'loot pointing at a missing item (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_loot_template` l LEFT JOIN `item_template` i ON i.`entry` = l.`Item`
    WHERE l.`Entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007, 4010101, 4010102, 4010103, 4010104, 4010105, 4010106, 4010107, 4010108, 4010109, 4010110, 4010111, 4010112, 4010151, 4010152, 4010153) AND l.`Reference` = 0 AND i.`entry` IS NULL
UNION ALL SELECT 'bosses with no seasonal reward (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT 4010001 AS e UNION ALL SELECT 4010002 UNION ALL SELECT 4010003 UNION ALL SELECT 4010004 UNION ALL SELECT 4010005 UNION ALL SELECT 4010006 UNION ALL SELECT 4010007) b
    LEFT JOIN `dc_seasonal_creature_rewards` r ON r.`creature_id` = b.e
    WHERE r.`creature_id` IS NULL
UNION ALL SELECT 'vault entries', CAST(COUNT(*) AS CHAR)
    FROM `dc_vault_loot_table` WHERE `source` = 'Timbermaw Hold'
UNION ALL SELECT 'lootid <> entry on these creatures (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (4010001, 4010002, 4010003, 4010004, 4010005, 4010006, 4010007, 4010101, 4010102, 4010103, 4010104, 4010105, 4010106, 4010107, 4010108, 4010109, 4010110, 4010111, 4010112, 4010151, 4010152, 4010153) AND `lootid` <> `entry`;
