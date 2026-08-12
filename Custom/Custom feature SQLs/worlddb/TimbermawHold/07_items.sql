-- =====================================================================================
-- Timbermaw Hold -- raid tier items (ilvl 450)
--
-- Theme: furbolg, bone and Nightmare -- physical, tank/melee bias
--
-- Each row is a FULL-ROW CLONE of an ilvl-412 tier-4 item of the same class / subclass /
-- InventoryType. Only entry, name, ItemLevel and the stat magnitudes change. That is
-- deliberate: displayid, icon, AllowableClass, sockets, bonding, sheath and material all come
-- from an item that already renders correctly, so this file cannot invent a broken icon or an
-- item no class can equip.
--
-- ilvl 450 sits above the 412-435 ladder/themed ceiling and lands inside upgrade tier 5
-- (412+) automatically -- `dc_item_upgrade_tiers` windows are pure ItemLevel, so no new tier
-- and no schema change is needed. An item whose ilvl falls in NO tier window is invisible to
-- the upgrade UI, which is why this must not drift above the tier-5 range.
--
-- BOTH raids share this one tier on purpose. They are parallel endgame options with different
-- themes, not a ladder, so neither obsoletes the other.
--
-- Coverage: 8 armour slots x 4 armour types covers all nine classes; plus neck, back, two
-- rings, two trinkets and a full weapon spread so every spec has something to want.
--
-- Entry band 410000-410053. 410000-499999 was verified completely empty before allocation.
-- Re-runnable.
-- =====================================================================================


SET @ILVL := 450;
SET @K := 1.092233;   -- 450 / 412, applied to stats, armour and weapon damage

DROP TEMPORARY TABLE IF EXISTS tmp_itmap;
CREATE TEMPORARY TABLE tmp_itmap (src INT UNSIGNED, new_entry INT UNSIGNED PRIMARY KEY, new_name VARCHAR(255));
INSERT INTO tmp_itmap VALUES
    (400265, 410000, 'Ursine Cowl'),
    (400262, 410001, 'Bonecarved Helm'),
    (400256, 410002, 'Denwarden''s Faceguard'),
    (400233, 410003, 'Nightmare-Bound Greathelm'),
    (400270, 410004, 'Ursine Mantle'),
    (400264, 410005, 'Bonecarved Spaulders'),
    (400258, 410006, 'Denwarden''s Shoulderguards'),
    (400238, 410007, 'Nightmare-Bound Pauldrons'),
    (400272, 410008, 'Ursine Robes'),
    (400260, 410009, 'Bonecarved Vest'),
    (400259, 410010, 'Denwarden''s Hauberk'),
    (400230, 410011, 'Nightmare-Bound Breastplate'),
    (400341, 410012, 'Ursine Cord'),
    (400414, 410013, 'Bonecarved Belt'),
    (400329, 410014, 'Denwarden''s Girdle'),
    (400330, 410015, 'Nightmare-Bound Waistguard'),
    (400269, 410016, 'Ursine Leggings'),
    (400263, 410017, 'Bonecarved Britches'),
    (400257, 410018, 'Denwarden''s Greaves'),
    (400236, 410019, 'Nightmare-Bound Legplates'),
    (400377, 410020, 'Ursine Slippers'),
    (400339, 410021, 'Bonecarved Boots'),
    (400408, 410022, 'Denwarden''s Sabatons'),
    (400327, 410023, 'Nightmare-Bound Warboots'),
    (400340, 410024, 'Ursine Cuffs'),
    (400426, 410025, 'Bonecarved Bracers'),
    (400350, 410026, 'Denwarden''s Wristguards'),
    (400366, 410027, 'Nightmare-Bound Vambraces'),
    (400266, 410028, 'Ursine Gloves'),
    (400261, 410029, 'Bonecarved Grips'),
    (400255, 410030, 'Denwarden''s Gauntlets'),
    (400232, 410031, 'Nightmare-Bound Handguards'),
    (400347, 410032, 'Denwarden''s Amulet'),
    (400349, 410033, 'Ursine Cloak'),
    (400342, 410034, 'Bonecarved Band'),
    (400342, 410035, 'Ursine Signet'),
    (400355, 410036, 'Ursine Idol'),
    (400355, 410037, 'Bonecarved Talisman'),
    (400337, 410038, 'Denwarden''s Axe'),
    (400338, 410039, 'Denwarden''s Mace'),
    (400336, 410040, 'Ursine Blade'),
    (400333, 410041, 'Denwarden''s Dagger'),
    (400325, 410042, 'Nightmare-Bound Claw'),
    (400393, 410043, 'Bonecarved Greataxe'),
    (400515, 410044, 'Nightmare-Bound Maul'),
    (400376, 410045, 'Ursine Halberd'),
    (400348, 410046, 'Ursine Greatsword'),
    (400326, 410047, 'Ursine Staff'),
    (400506, 410048, 'Ursine Bulwark'),
    (400401, 410049, 'Nightmare-Bound Tome'),
    (400388, 410050, 'Denwarden''s Longbow'),
    (400397, 410051, 'Ursine Rifle'),
    (400440, 410052, 'Denwarden''s Crossbow'),
    (400381, 410053, 'Ursine Wand');

DROP TEMPORARY TABLE IF EXISTS tmp_it;
CREATE TEMPORARY TABLE tmp_it LIKE `item_template`;
ALTER TABLE tmp_it DROP PRIMARY KEY,
    ADD COLUMN `new_entry` INT UNSIGNED, ADD COLUMN `new_name` VARCHAR(255);

INSERT INTO tmp_it
    SELECT i.*, m.new_entry, m.new_name
    FROM tmp_itmap m JOIN `item_template` i ON i.`entry` = m.src;

-- Retune. Damage is scaled too, or the weapons would be strictly worse than the
-- ladder items they are meant to replace despite the higher item level.
UPDATE tmp_it SET
    `entry` = `new_entry`, `name` = `new_name`,
    `ItemLevel` = @ILVL, `RequiredLevel` = 130, `quality` = 4, `VerifiedBuild` = 0,
    `armor`      = ROUND(`armor` * @K),
    `dmg_min1`   = ROUND(`dmg_min1` * @K), `dmg_max1` = ROUND(`dmg_max1` * @K),
    `dmg_min2`   = ROUND(`dmg_min2` * @K), `dmg_max2` = ROUND(`dmg_max2` * @K),
    `stat_value1` = ROUND(`stat_value1` * @K),
    `stat_value2` = ROUND(`stat_value2` * @K),
    `stat_value3` = ROUND(`stat_value3` * @K),
    `stat_value4` = ROUND(`stat_value4` * @K),
    `stat_value5` = ROUND(`stat_value5` * @K),
    `stat_value6` = ROUND(`stat_value6` * @K),
    `stat_value7` = ROUND(`stat_value7` * @K),
    `stat_value8` = ROUND(`stat_value8` * @K),
    `stat_value9` = ROUND(`stat_value9` * @K),
    `stat_value10` = ROUND(`stat_value10` * @K);

ALTER TABLE tmp_it DROP COLUMN `new_entry`, DROP COLUMN `new_name`;

DELETE FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053;
INSERT INTO `item_template` SELECT * FROM tmp_it;

DROP TEMPORARY TABLE IF EXISTS tmp_it;
DROP TEMPORARY TABLE IF EXISTS tmp_itmap;

-- -------------------------------------------------------------------------------------
-- Report -- literal id range, never the temp table: MySQL error 1137 forbids reopening
-- a TEMPORARY table more than once in a single statement, and this is a UNION of many.
-- -------------------------------------------------------------------------------------
SELECT 'items (want 54)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053
UNION ALL SELECT 'missing displayid (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053 AND `displayid` = 0
UNION ALL SELECT 'wrong ilvl (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053 AND `ItemLevel` <> @ILVL
UNION ALL SELECT 'outside upgrade tier 5 window (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053 AND `ItemLevel` < 412
UNION ALL SELECT 'equippable by no class (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053 AND `AllowableClass` = 0
UNION ALL SELECT 'distinct armour types (want 4)', CAST(COUNT(DISTINCT `subclass`) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053 AND `class` = 4 AND `subclass` BETWEEN 1 AND 4
UNION ALL SELECT 'distinct weapon subclasses (want >=10)', CAST(COUNT(DISTINCT `subclass`) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410000 AND 410053 AND `class` = 2;
