-- =====================================================================================
-- Crescent Grove (map 823, 5-man) -- loot
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


DELETE FROM `creature_loot_template` WHERE `Entry` IN (4020001, 4020002, 4020005, 4020006, 4020007, 4020003, 4020004, 4020101, 4020102, 4020103, 4020104, 4020105, 4020106, 4020107, 4020108, 4020109, 4020110, 4020111, 4020112, 4020151, 4020152, 4020153);

INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (4020001, 750088, 750088, 25.0, 0, 1, 0, 1, 1, 'Keeper Ranathos - Ashenvale themed set'),
    (4020001, 300311, 0, 100, 0, 1, 0, 20, 35, 'Keeper Ranathos - upgrade tokens'),
    (4020002, 750088, 750088, 25.0, 0, 1, 0, 1, 1, 'Grovetender Engryss - Ashenvale themed set'),
    (4020002, 300311, 0, 100, 0, 1, 0, 20, 35, 'Grovetender Engryss - upgrade tokens'),
    (4020005, 750088, 750088, 25.0, 0, 1, 0, 1, 1, 'High Priestess A''lathea - Ashenvale themed set'),
    (4020005, 300311, 0, 100, 0, 1, 0, 20, 35, 'High Priestess A''lathea - upgrade tokens'),
    (4020006, 750088, 750088, 25.0, 0, 1, 0, 1, 1, 'Fenektis the Deceiver - Ashenvale themed set'),
    (4020006, 300311, 0, 100, 0, 1, 0, 20, 35, 'Fenektis the Deceiver - upgrade tokens'),
    (4020007, 750088, 750088, 40.0, 0, 1, 0, 1, 1, 'Master Raxxieth - Ashenvale themed set'),
    (4020007, 300311, 0, 100, 0, 1, 0, 40, 60, 'Master Raxxieth - upgrade tokens'),
    (4020003, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020004, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020101, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020102, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020103, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020104, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020105, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020106, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020107, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020108, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020109, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020110, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020111, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020112, 300311, 0, 35, 0, 1, 0, 1, 3, 'trash - upgrade tokens'),
    (4020151, 750088, 750088, 20, 0, 1, 0, 1, 1, 'rare elite - Ashenvale themed set'),
    (4020151, 300311, 0, 100, 0, 1, 0, 10, 18, 'rare elite - upgrade tokens'),
    (4020152, 750088, 750088, 20, 0, 1, 0, 1, 1, 'rare elite - Ashenvale themed set'),
    (4020152, 300311, 0, 100, 0, 1, 0, 10, 18, 'rare elite - upgrade tokens'),
    (4020153, 750088, 750088, 20, 0, 1, 0, 1, 1, 'rare elite - Ashenvale themed set'),
    (4020153, 300311, 0, 100, 0, 1, 0, 10, 18, 'rare elite - upgrade tokens');

-- Boss token payouts. This is a data hook: `dc_seasonal_creature_rewards` maps a
-- creature to a token/essence payout with no code at all, and the CrossSystem reward
-- distributor applies the prestige/difficulty/seasonal multipliers on top.
DELETE FROM `dc_seasonal_creature_rewards` WHERE `creature_id` IN (4020001, 4020002, 4020005, 4020006, 4020007);
INSERT INTO `dc_seasonal_creature_rewards`
    (`season_id`, `creature_id`, `reward_type`, `base_token_amount`, `base_essence_amount`,
     `creature_rank`, `content_type`, `difficulty_level`, `seasonal_multiplier`,
     `minimum_players`, `group_split_tokens`, `enabled`) VALUES
    (1, 4020001, 1, 60, 15, 3, 1, 1, 1.0, 3, 1, 1),
    (1, 4020002, 1, 60, 15, 3, 1, 1, 1.0, 3, 1, 1),
    (1, 4020005, 1, 60, 15, 3, 1, 1, 1.0, 3, 1, 1),
    (1, 4020006, 1, 60, 15, 3, 1, 1, 1.0, 3, 1, 1),
    (1, 4020007, 1, 120, 30, 3, 1, 1, 1.0, 3, 1, 1);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'loot rows (want 30)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `creature_loot_template` WHERE `Entry` IN (4020001, 4020002, 4020005, 4020006, 4020007, 4020003, 4020004, 4020101, 4020102, 4020103, 4020104, 4020105, 4020106, 4020107, 4020108, 4020109, 4020110, 4020111, 4020112, 4020151, 4020152, 4020153)
UNION ALL SELECT 'loot pointing at a missing item (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_loot_template` l LEFT JOIN `item_template` i ON i.`entry` = l.`Item`
    WHERE l.`Entry` IN (4020001, 4020002, 4020005, 4020006, 4020007, 4020003, 4020004, 4020101, 4020102, 4020103, 4020104, 4020105, 4020106, 4020107, 4020108, 4020109, 4020110, 4020111, 4020112, 4020151, 4020152, 4020153) AND l.`Reference` = 0 AND i.`entry` IS NULL
UNION ALL SELECT 'bosses with no seasonal reward (want 0)', CAST(COUNT(*) AS CHAR)
    FROM (SELECT 4020001 AS e UNION ALL SELECT 4020002 UNION ALL SELECT 4020005 UNION ALL SELECT 4020006 UNION ALL SELECT 4020007) b
    LEFT JOIN `dc_seasonal_creature_rewards` r ON r.`creature_id` = b.e
    WHERE r.`creature_id` IS NULL
UNION ALL SELECT 'vault entries', CAST(COUNT(*) AS CHAR)
    FROM `dc_vault_loot_table` WHERE `source` = 'Crescent Grove'
UNION ALL SELECT 'lootid <> entry on these creatures (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (4020001, 4020002, 4020005, 4020006, 4020007, 4020003, 4020004, 4020101, 4020102, 4020103, 4020104, 4020105, 4020106, 4020107, 4020108, 4020109, 4020110, 4020111, 4020112, 4020151, 4020152, 4020153) AND `lootid` <> `entry`;
