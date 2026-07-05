-- Blackwing Descent (map 669) — item stats + new loot items (NORMAL / 10-man)
-- The 73 normal (ilvl 359) drops already exist in item_template as appearance shells (models/displayid
-- populated, stats zero). Populate their stat block from nelt_world.db_item-sparse_15595 (build 4.3.4).
--
-- >>> ARMOR + WEAPON DAMAGE GAP: db_item-sparse has NO armor and NO dmg_min/dmg_max (client-derived in
-- >>> 4.3.4 from ilvl+quality+slot). This UPDATE leaves it.armor / dmg_min1 / dmg_max1 untouched (0).
-- >>> TODO: compute them from the retail ilvl/quality/slot armor+dps tables, or copy from an equal
-- >>> ilvl/slot 3.3.5 reference item, per gear piece.
-- >>> HEROIC (ilvl 372) gear (ids 65005-65075, +65010 new) is deferred with the heroic loot tables (09).

-- ---------------------------------------------------------------------------
-- Populate the 73 normal loot shells (stat block from db_item-sparse; armor/dmg = TODO)
-- ---------------------------------------------------------------------------
UPDATE `item_template` it
JOIN `nelt_world`.`db_item-sparse_15595` s ON s.`ID` = it.`entry`
SET
    it.`ItemLevel`     = s.`Itemlevel`,
    it.`Quality`       = s.`Quality`,
    it.`RequiredLevel` = s.`Requiredlevel`,
    it.`InventoryType` = s.`Inventorytype`,
    -- item-sparse uses -1 as the "unused stat slot" sentinel; item_template.stat_type* is tinyint
    -- unsigned, so clamp negatives to 0 (GREATEST) on both type and value to avoid an out-of-range error.
    it.`stat_type1` = GREATEST(s.`Stat_Type1`, 0), it.`stat_value1` = GREATEST(s.`Stat_Value1`, 0),
    it.`stat_type2` = GREATEST(s.`Stat_Type2`, 0), it.`stat_value2` = GREATEST(s.`Stat_Value2`, 0),
    it.`stat_type3` = GREATEST(s.`Stat_Type3`, 0), it.`stat_value3` = GREATEST(s.`Stat_Value3`, 0),
    it.`stat_type4` = GREATEST(s.`Stat_Type4`, 0), it.`stat_value4` = GREATEST(s.`Stat_Value4`, 0),
    it.`stat_type5` = GREATEST(s.`Stat_Type5`, 0), it.`stat_value5` = GREATEST(s.`Stat_Value5`, 0),
    it.`stat_type6` = GREATEST(s.`Stat_Type6`, 0), it.`stat_value6` = GREATEST(s.`Stat_Value6`, 0),
    it.`stat_type7` = GREATEST(s.`Stat_Type7`, 0), it.`stat_value7` = GREATEST(s.`Stat_Value7`, 0),
    it.`stat_type8` = GREATEST(s.`Stat_Type8`, 0), it.`stat_value8` = GREATEST(s.`Stat_Value8`, 0),
    it.`stat_type9` = GREATEST(s.`Stat_Type9`, 0), it.`stat_value9` = GREATEST(s.`Stat_Value9`, 0),
    it.`stat_type10` = GREATEST(s.`Stat_Type10`, 0), it.`stat_value10` = GREATEST(s.`Stat_Value10`, 0),
    it.`delay`      = s.`Delay`,
    it.`dmg_type1`  = s.`Damagetype`
WHERE it.`entry` IN (
    SELECT `Item` FROM `cata_world`.`reference_loot_template`
    WHERE `Entry` IN (413760,413780,414420,415700,421800,432960) AND `Item` > 0
);

-- ---------------------------------------------------------------------------
-- 5 new NON-gear loot items (tier-11 head tokens, Chimaeron cage key, Magmaw misc drop)
-- (heroic gear 65010 is created with the heroic loot pass — see 09/this file header)
-- ---------------------------------------------------------------------------
DELETE FROM `item_template` WHERE `entry` IN (63682,63683,63684,64663,71716);
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`,
     `InventoryType`, `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `bonding`, `Material`, `sheath`)
VALUES
    (63682, 0, 0, 'Helm of the Forlorn Vanquisher', 63765, 4, 0, 1, 0, 0, 0, 85, 85, 0, 1, 1, 0, 0),
    (63683, 0, 0, 'Helm of the Forlorn Conqueror',  63765, 4, 0, 1, 0, 0, 0, 85, 85, 0, 1, 1, 0, 0),
    (63684, 0, 0, 'Helm of the Forlorn Protector',  63765, 4, 0, 1, 0, 0, 0, 85, 85, 0, 1, 1, 0, 0),
    (64663, 12, 0, 'Bile-Etched Brass Key',          134, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0),
    (71716, 15, 0, 'Soothsayer''s Runes',            134, 3, 0, 1, 0, 0, 0, 85, 85, 0, 1, 1, 0, 0);
