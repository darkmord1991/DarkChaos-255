-- ===========================================================================
-- DC custom heirlooms - add ARMOR scaling (follow-up to FIX_HEIRLOOM_SET_SCALING)
-- ===========================================================================
--
-- Run AFTER FIX_HEIRLOOM_SET_SCALING.sql. This only ORs armor bits into the
-- existing ScalingStatValue masks; the stat-curve bits are unchanged, so stats
-- keep scaling exactly as they do now.
--
-- ScalingStatValues.dbc carries two armor tiers per armor class:
--   armorMod[0..3]   (bits 0x20/0x40/0x80/0x100)        - shoulder tier
--   armorMod2[1..4]  (bits 0x100000..0x800000)          - chest tier
--   armorMod2[0]     (bit  0x80000)                     - cloak
-- They sit at exactly the 0.75 / 1.00 ratio WoW uses for those slots, so:
--   chest + legs                -> chest tier
--   head, shoulder, hands, feet -> shoulder tier
--   back                        -> cloak
--
-- WRIST (300350-300352) and WAIST (300356-300358) are deliberately NOT touched.
-- Their real slot budget is ~0.56 of chest and no DBC column provides it; the
-- shoulder tier would overshoot them by about a third. They keep their static
-- armor and the upgrade-system multiplier.
-- Shield, shirt, neck, ring, trinket and off-hand are also left alone - no
-- meaningful armor curve exists for them.
--
-- No item in this set is leather or plate; every piece is cloth (subclass 1) or
-- mail (subclass 3), so only those two bit sets appear below.
--
-- Once ScalingStatValue is non-zero the core replaces the static `armor` field
-- entirely (Player.cpp: `if (proto->ScalingStatValue > 0 ...) armor = ssvarmor`),
-- so the `armor` column below becomes cosmetic. It is left as-is.
--
-- Client needs its item WDB cache cleared to show the new values.
-- ===========================================================================

USE acore_world;

-- --- head               (shoulder-tier armor) ----------------
UPDATE `item_template` SET `ScalingStatValue` = 136 WHERE `entry` = 300341; -- Heirloom War Crown [mail, 100 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 136 WHERE `entry` = 300342; -- Heirloom Battle Helm [mail, 100 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 40 WHERE `entry` = 300343; -- Heirloom Kingly Circlet [cloth, 80 -> 210 armor @80, 750 @255]

-- --- shoulder           (shoulder-tier armor) ----------------
UPDATE `item_template` SET `ScalingStatValue` = 129 WHERE `entry` = 300344; -- Heirloom Mantle of Honor [mail, 90 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 129 WHERE `entry` = 300345; -- Heirloom Shoulders of Valor [mail, 90 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 33 WHERE `entry` = 300346; -- Heirloom Pauldrons of Wisdom [cloth, 75 -> 210 armor @80, 750 @255]

-- --- chest + legs        (chest-tier armor) ------------------
UPDATE `item_template` SET `ScalingStatValue` = 4194312 WHERE `entry` = 300347; -- Heirloom Chestplate of the Champion [mail, 150 -> 1171 armor @80, 4181 @255]
UPDATE `item_template` SET `ScalingStatValue` = 4194312 WHERE `entry` = 300348; -- Heirloom Battleplate [mail, 150 -> 1171 armor @80, 4181 @255]
UPDATE `item_template` SET `ScalingStatValue` = 1048584 WHERE `entry` = 300349; -- Heirloom Robes of Insight [cloth, 120 -> 280 armor @80, 1000 @255]

-- --- hands              (shoulder-tier armor) ----------------
UPDATE `item_template` SET `ScalingStatValue` = 129 WHERE `entry` = 300353; -- Heirloom Gauntlets of Strength [mail, 80 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 129 WHERE `entry` = 300354; -- Heirloom Grips of Precision [mail, 80 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 33 WHERE `entry` = 300355; -- Heirloom Gloves of Sorcery [cloth, 65 -> 210 armor @80, 750 @255]

-- --- chest + legs        (chest-tier armor) ------------------
UPDATE `item_template` SET `ScalingStatValue` = 4194312 WHERE `entry` = 300359; -- Heirloom Legplates of the Conqueror [mail, 120 -> 1171 armor @80, 4181 @255]
UPDATE `item_template` SET `ScalingStatValue` = 4194312 WHERE `entry` = 300360; -- Heirloom Leggings of Swiftness [mail, 120 -> 1171 armor @80, 4181 @255]
UPDATE `item_template` SET `ScalingStatValue` = 1048584 WHERE `entry` = 300361; -- Heirloom Trousers of Arcane Power [cloth, 100 -> 280 armor @80, 1000 @255]

-- --- feet               (shoulder-tier armor) ----------------
UPDATE `item_template` SET `ScalingStatValue` = 129 WHERE `entry` = 300362; -- Heirloom Sabatons of Fury [mail, 90 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 129 WHERE `entry` = 300363; -- Heirloom Boots of Haste [mail, 90 -> 878 armor @80, 3135 @255]
UPDATE `item_template` SET `ScalingStatValue` = 33 WHERE `entry` = 300364; -- Heirloom Sandals of Brilliance [cloth, 75 -> 210 armor @80, 750 @255]

-- --- back               (cloak armor) ------------------------
UPDATE `item_template` SET `ScalingStatValue` = 786432 WHERE `entry` = 300370; -- Heirloom Cape of Valor [cloth, 75 -> 140 armor @80, 500 @255]
UPDATE `item_template` SET `ScalingStatValue` = 786432 WHERE `entry` = 300371; -- Heirloom Drape of Swiftness [cloth, 75 -> 140 armor @80, 500 @255]
UPDATE `item_template` SET `ScalingStatValue` = 786432 WHERE `entry` = 300372; -- Heirloom Cloak of Insight [cloth, 75 -> 140 armor @80, 500 @255]

-- --- verification ---------------------------------------------------------
SELECT `entry`, `name`, `InventoryType`, `subclass`, `ScalingStatValue` AS SSV, `armor`
FROM `item_template`
WHERE `entry` IN (300341,300342,300343,300344,300345,300346,300347,300348,300349,300353,300354,300355,300359,300360,300361,300362,300363,300364,300370,300371,300372)
ORDER BY `entry`;
-- Expect 21 rows. Wrist 300350-300352 and waist 300356-300358 must NOT appear.
