-- =====================================================================================
-- Emerald Sanctum -- raid tier items (ilvl 450)
--
-- Theme: dream, scale and verdant growth -- nature/spell bias
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
-- Entry band 410100-410153. 410000-499999 was verified completely empty before allocation.
-- Re-runnable.
-- =====================================================================================


SET @ILVL := 450;
SET @K := 1.092233;   -- 450 / 412, applied to stats, armour and weapon damage

DROP TEMPORARY TABLE IF EXISTS tmp_itmap;
CREATE TEMPORARY TABLE tmp_itmap (src INT UNSIGNED, new_entry INT UNSIGNED PRIMARY KEY, new_name VARCHAR(255));
INSERT INTO tmp_itmap VALUES
    (400265, 410100, 'Verdant Cowl'),
    (400262, 410101, 'Dreamscale Helm'),
    (400256, 410102, 'Wakener''s Faceguard'),
    (400233, 410103, 'Emerald Greathelm'),
    (400270, 410104, 'Verdant Mantle'),
    (400264, 410105, 'Dreamscale Spaulders'),
    (400258, 410106, 'Wakener''s Shoulderguards'),
    (400238, 410107, 'Emerald Pauldrons'),
    (400272, 410108, 'Verdant Robes'),
    (400260, 410109, 'Dreamscale Vest'),
    (400259, 410110, 'Wakener''s Hauberk'),
    (400230, 410111, 'Emerald Breastplate'),
    (400341, 410112, 'Verdant Cord'),
    (400414, 410113, 'Dreamscale Belt'),
    (400329, 410114, 'Wakener''s Girdle'),
    (400330, 410115, 'Emerald Waistguard'),
    (400269, 410116, 'Verdant Leggings'),
    (400263, 410117, 'Dreamscale Britches'),
    (400257, 410118, 'Wakener''s Greaves'),
    (400236, 410119, 'Emerald Legplates'),
    (400377, 410120, 'Verdant Slippers'),
    (400339, 410121, 'Dreamscale Boots'),
    (400408, 410122, 'Wakener''s Sabatons'),
    (400327, 410123, 'Emerald Warboots'),
    (400340, 410124, 'Verdant Cuffs'),
    (400426, 410125, 'Dreamscale Bracers'),
    (400350, 410126, 'Wakener''s Wristguards'),
    (400366, 410127, 'Emerald Vambraces'),
    (400266, 410128, 'Verdant Gloves'),
    (400261, 410129, 'Dreamscale Grips'),
    (400255, 410130, 'Wakener''s Gauntlets'),
    (400232, 410131, 'Emerald Handguards'),
    (400347, 410132, 'Wakener''s Amulet'),
    (400349, 410133, 'Verdant Cloak'),
    (400342, 410134, 'Dreamscale Band'),
    (400342, 410135, 'Verdant Signet'),
    (400355, 410136, 'Verdant Idol'),
    (400355, 410137, 'Dreamscale Talisman'),
    (400337, 410138, 'Wakener''s Axe'),
    (400338, 410139, 'Wakener''s Mace'),
    (400336, 410140, 'Verdant Blade'),
    (400333, 410141, 'Wakener''s Dagger'),
    (400325, 410142, 'Emerald Claw'),
    (400393, 410143, 'Dreamscale Greataxe'),
    (400515, 410144, 'Emerald Maul'),
    (400376, 410145, 'Verdant Halberd'),
    (400348, 410146, 'Verdant Greatsword'),
    (400326, 410147, 'Verdant Staff'),
    (400506, 410148, 'Verdant Bulwark'),
    (400401, 410149, 'Emerald Tome'),
    (400388, 410150, 'Wakener''s Longbow'),
    (400397, 410151, 'Verdant Rifle'),
    (400440, 410152, 'Wakener''s Crossbow'),
    (400381, 410153, 'Verdant Wand');

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

DELETE FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153;
INSERT INTO `item_template` SELECT * FROM tmp_it;

DROP TEMPORARY TABLE IF EXISTS tmp_it;
DROP TEMPORARY TABLE IF EXISTS tmp_itmap;

-- -------------------------------------------------------------------------------------
-- Report -- literal id range, never the temp table: MySQL error 1137 forbids reopening
-- a TEMPORARY table more than once in a single statement, and this is a UNION of many.
-- -------------------------------------------------------------------------------------
SELECT 'items (want 54)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153
UNION ALL SELECT 'missing displayid (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153 AND `displayid` = 0
UNION ALL SELECT 'wrong ilvl (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153 AND `ItemLevel` <> @ILVL
UNION ALL SELECT 'outside upgrade tier 5 window (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153 AND `ItemLevel` < 412
UNION ALL SELECT 'equippable by no class (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153 AND `AllowableClass` = 0
UNION ALL SELECT 'distinct armour types (want 4)', CAST(COUNT(DISTINCT `subclass`) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153 AND `class` = 4 AND `subclass` BETWEEN 1 AND 4
UNION ALL SELECT 'distinct weapon subclasses (want >=10)', CAST(COUNT(DISTINCT `subclass`) AS CHAR)
    FROM `item_template` WHERE `entry` BETWEEN 410100 AND 410153 AND `class` = 2;
