-- ============================================================
-- Item Upgrade: Proc Spell Mapping Table
-- ============================================================
-- This table maps spell IDs to item entries for proc scaling
-- When an item is upgraded, its proc effects will be scaled
-- ============================================================

DROP TABLE IF EXISTS `dc_item_proc_spells`;

CREATE TABLE `dc_item_proc_spells` (
    `spell_id` INT UNSIGNED NOT NULL COMMENT 'Spell ID of the proc effect',
    `item_entry` INT UNSIGNED NOT NULL COMMENT 'Item entry that has this proc',
    `proc_name` VARCHAR(255) DEFAULT NULL COMMENT 'Human-readable name of the proc',
    `proc_type` ENUM('damage', 'healing', 'buff', 'debuff', 'other') DEFAULT 'damage' COMMENT 'Type of proc effect',
    `scales_with_upgrade` TINYINT(1) DEFAULT 1 COMMENT '1 = scales with upgrade, 0 = no scaling',
    PRIMARY KEY (`spell_id`, `item_entry`),
    KEY `idx_item` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Maps item proc spells to items for upgrade scaling';

-- ============================================================
-- Common WotLK Trinket Procs
-- ============================================================

-- Darkmoon Card: Greatness (all variants)
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60229, 42989, 'Greatness (Agility)', 'buff'),
(60233, 42990, 'Greatness (Strength)', 'buff'),
(60234, 42991, 'Greatness (Intellect)', 'buff'),
(60235, 42992, 'Greatness (Spirit)', 'buff');

-- Darkmoon Card: Death
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(71485, 42990, 'Death Proc', 'damage'),
(71492, 42990, 'Death Proc (Heroic)', 'damage');

-- Mjolnir Runestone
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(45522, 33831, 'Lightning Bolt', 'damage');

-- Illustration of the Dragon Soul
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60486, 40432, 'Dragon Soul Buff', 'buff');

-- Dying Curse
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60494, 40255, 'Dying Curse Proc', 'buff');

-- Forge Ember
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60479, 37660, 'Forge Ember Proc', 'buff');

-- Extract of Necromantic Power
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60488, 40373, 'Necromantic Power', 'buff');

-- Grim Toll
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60437, 40256, 'Grim Toll Proc', 'buff');

-- Mirror of Truth
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60065, 40684, 'Mirror of Truth Proc', 'buff');

-- Pyrite Infuser
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(65014, 45286, 'Pyrite Infusion', 'buff');

-- Comet's Trail
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(64772, 45609, 'Comet Trail Proc', 'damage');

-- Flare of the Heavens
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(64713, 45518, 'Heavens Flare', 'damage');

-- Elemental Focus Stone
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(65004, 45866, 'Elemental Focus', 'buff');

-- Eye of the Broodmother
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(65006, 45308, 'Broodmother Focus', 'buff');

-- Shard of the Crystal Heart
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(60065, 48722, 'Crystal Heart Proc', 'buff');

-- Wrathstone
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(64800, 45535, 'Wrathstone Proc', 'damage');

-- ============================================================
-- Weapon Procs
-- ============================================================

-- Thunderfury, Blessed Blade of the Windseeker
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(21992, 19019, 'Thunderfury Proc', 'damage');

-- Val'anyr, Hammer of Ancient Kings
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(64413, 46017, 'Blessing of Ancient Kings', 'buff');

-- Shadowmourne
INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
(71903, 49623, 'Shadowmourne Chaos Bane', 'damage'),
(71904, 49623, 'Shadowmourne Soul Fragment', 'buff');

-- ============================================================
-- HOW TO ADD MORE PROC MAPPINGS:
-- ============================================================
-- 1. Find the spell ID of the proc in your database (spell_template or DBC)
-- 2. Find the item entry in item_template
-- 3. Insert a row with the mapping
-- 4. Server will automatically load on next restart
-- 
-- Example:
-- INSERT INTO `dc_item_proc_spells` (`spell_id`, `item_entry`, `proc_name`, `proc_type`) VALUES
-- (12345, 67890, 'My Cool Proc', 'damage');
-- ============================================================
