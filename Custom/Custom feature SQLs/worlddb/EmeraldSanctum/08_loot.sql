-- =====================================================================================
-- Emerald Sanctum (map 824, 20-man) -- loot
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


DELETE FROM `creature_loot_template` WHERE `Entry` IN (4030001, 4030002, 4030003, 4030004, 4030005, 4030101, 4030102, 4030103);

INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (4030001, 410126, 0, 20.0, 0, 1, 1, 1, 1, 'Erennius - tier gear'),
    (4030001, 410120, 0, 20.0, 0, 1, 1, 1, 1, 'Erennius - tier gear'),
    (4030001, 410153, 0, 20.0, 0, 1, 1, 1, 1, 'Erennius - tier gear'),
    (4030001, 410119, 0, 20.0, 0, 1, 1, 1, 1, 'Erennius - tier gear'),
    (4030001, 410132, 0, 20.0, 0, 1, 1, 1, 1, 'Erennius - tier gear'),
    (4030001, 300311, 0, 100, 0, 1, 0, 40, 55, 'Erennius - upgrade tokens'),
    (4030002, 410144, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 410143, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 410121, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 410152, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 410139, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 410150, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 410124, 0, 14.3, 0, 1, 1, 1, 1, 'Ysondre the Wakener - tier gear'),
    (4030002, 300311, 0, 100, 0, 1, 0, 80, 100, 'Ysondre the Wakener - upgrade tokens'),
    (4030003, 410135, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 410140, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 410112, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 410138, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 410147, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 410110, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 410116, 0, 14.3, 0, 1, 1, 1, 1, 'Lethon the Wakener - tier gear'),
    (4030003, 300311, 0, 100, 0, 1, 0, 80, 100, 'Lethon the Wakener - upgrade tokens'),
    (4030004, 410106, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 410129, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 410118, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 410128, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 410101, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 410122, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 410130, 0, 14.3, 0, 1, 1, 1, 1, 'Emeriss the Wakener - tier gear'),
    (4030004, 300311, 0, 100, 0, 1, 0, 80, 100, 'Emeriss the Wakener - upgrade tokens'),
    (4030005, 410109, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 410114, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 410105, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 410125, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 410102, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 410117, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 410133, 0, 14.3, 0, 1, 1, 1, 1, 'Taerar the Wakener - tier gear'),
    (4030005, 300311, 0, 100, 0, 1, 0, 80, 100, 'Taerar the Wakener - upgrade tokens'),
    (4030101, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4030102, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens'),
    (4030103, 300311, 0, 35, 0, 1, 0, 2, 4, 'trash - upgrade tokens');

-- Boss token payouts. This is a data hook: `dc_seasonal_creature_rewards` maps a
-- creature to a token/essence payout with no code at all, and the CrossSystem reward
-- distributor applies the prestige/difficulty/seasonal multipliers on top.
DELETE FROM `dc_seasonal_creature_rewards` WHERE `creature_id` IN (4030001, 4030002, 4030003, 4030004, 4030005);
INSERT INTO `dc_seasonal_creature_rewards`
    (`season_id`, `creature_id`, `reward_type`, `base_token_amount`, `base_essence_amount`,
     `creature_rank`, `content_type`, `difficulty_level`, `seasonal_multiplier`,
     `minimum_players`, `group_split_tokens`, `enabled`) VALUES
    (1, 4030001, 1, 500, 150, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4030002, 1, 1000, 300, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4030003, 1, 1000, 300, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4030004, 1, 1000, 300, 3, 2, 1, 2.5, 20, 1, 1),
    (1, 4030005, 1, 1000, 300, 3, 2, 1, 2.5, 20, 1, 1);

-- Great Vault. The raid track needs no new code -- GetRaidBossProgressForWeek()
-- popcounts instance.completedEncounters -- but the gear only becomes a vault CHOICE
-- if it is listed here. armor_type/slot_type/role_mask are read straight off the item.
DELETE FROM `dc_vault_loot_table` WHERE `source` = 'Emerald Sanctum';
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
       7, 10, 'Emerald Sanctum'
FROM `item_template` i WHERE i.`entry` BETWEEN 410100 AND 410153;

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'loot rows (want 41)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_loot_template` WHERE `Entry` IN (4030001, 4030002, 4030003, 4030004, 4030005, 4030101, 4030102, 4030103)
UNION ALL SELECT 'loot pointing at a missing item (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_loot_template` l LEFT JOIN `item_template` i ON i.`entry` = l.`Item`
    WHERE l.`Entry` IN (4030001, 4030002, 4030003, 4030004, 4030005, 4030101, 4030102, 4030103) AND l.`Reference` = 0 AND i.`entry` IS NULL
UNION ALL SELECT 'bosses with no seasonal reward (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT 4030001 AS e UNION ALL SELECT 4030002 UNION ALL SELECT 4030003 UNION ALL SELECT 4030004 UNION ALL SELECT 4030005) b
    LEFT JOIN `dc_seasonal_creature_rewards` r ON r.`creature_id` = b.e
    WHERE r.`creature_id` IS NULL
UNION ALL SELECT 'vault entries', CAST(COUNT(*) AS CHAR)
    FROM `dc_vault_loot_table` WHERE `source` = 'Emerald Sanctum'
UNION ALL SELECT 'lootid <> entry on these creatures (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (4030001, 4030002, 4030003, 4030004, 4030005, 4030101, 4030102, 4030103) AND `lootid` <> `entry`;
