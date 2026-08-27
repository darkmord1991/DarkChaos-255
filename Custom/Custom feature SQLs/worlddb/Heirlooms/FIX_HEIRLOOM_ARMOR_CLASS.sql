-- ===========================================================================
-- DC custom heirlooms - close the armor-class gap (mail -> leather)
-- ===========================================================================
--
-- Problem: every physical piece in the set is MAIL (subclass 3). Armor
-- proficiency is a ceiling, not a slot, so mail excludes exactly the classes
-- that cannot train past leather:
--
--   rogue, druid      -> cloth + leather only   => COULD NOT EQUIP ANY OF IT
--   hunter, shaman    -> up to mail             => fine
--   warrior, pal, DK  -> up to plate            => fine
--   mage, priest, warlock -> cloth only         => use the cloth INT line
--
-- The heirloom "morph" rule in PlayerStorage.cpp only waives an UNLEARNED
-- proficiency for Paladin/Warrior (plate) and Hunter/Shaman (mail). It does not
-- let a rogue wear mail - that check is real and permanent.
--
-- Fix: move both physical lines (STA and STR+AGI) from mail to LEATHER, which
-- all seven physical classes can wear. The cloth INT line is untouched (every
-- class can wear cloth), so after this every class has two complete lines.
--
-- TRADE-OFF, stated plainly: plate and mail wearers now get leather armor
-- values from the scaling curve. Leather chest at 255 is 1882 vs mail 4181 vs
-- plate 7473. That is the price of one shared set; the alternative is adding
-- separate leather and plate item lines (16 new entries, new display IDs, new
-- cache loot rows and addon registration). Stats are unaffected - only the
-- armor column of the curve changes.
--
-- Three things must move together or the set desyncs:
--   1. item_template.subclass                 3 -> 2
--   2. dc_heirloom_definitions.armor_type     3 -> 2  (mirrors subclass; the
--      addon reads this table, and extracts.sql re-inserts it)
--   3. item_template.ScalingStatValue         mail armor bit -> leather bit
--      0x80 -> 0x40 (shoulder tier), 0x400000 -> 0x200000 (chest tier)
--
-- Wrist and waist carry no armor bit (deliberately skipped earlier - no DBC
-- column matches their ~0.56 budget), so only their subclass changes.
--
-- Resulting masks 65 and 2097160 are byte-identical to what Blizzard uses on
-- its own leather heirlooms (42952 Stained Shadowcraft Spaulders, 48689
-- Stained Shadowcraft Tunic).
--
-- No DBC or client work. Clear the item WDB cache to see it.
-- ===========================================================================

USE acore_world;

-- --- 1. armor class: mail -> leather --------------------------------------
UPDATE `item_template` SET `subclass` = 2 WHERE `entry` IN (
    300341, 300342, 300344, 300345, 300347, 300348, 300350, 300351,
    300353, 300354, 300356, 300357, 300359, 300360, 300362, 300363
) AND `subclass` = 3;

-- --- 2. keep the addon-facing definition table in step ---------------------
UPDATE `dc_heirloom_definitions` SET `armor_type` = 2 WHERE `item_id` IN (
    300341, 300342, 300344, 300345, 300347, 300348, 300350, 300351,
    300353, 300354, 300356, 300357, 300359, 300360, 300362, 300363
) AND `armor_type` = 3;

-- --- 3. armor curve: mail tier -> leather tier -----------------------------
-- head
UPDATE `item_template` SET `ScalingStatValue` = 72 WHERE `entry` = 300341; -- Heirloom War Crown [STA, armor bit mail->leather, 3135 -> 1410 @255]
UPDATE `item_template` SET `ScalingStatValue` = 72 WHERE `entry` = 300342; -- Heirloom Battle Helm [STR+AGI, armor bit mail->leather, 3135 -> 1410 @255]
-- shoulder
UPDATE `item_template` SET `ScalingStatValue` = 65 WHERE `entry` = 300344; -- Heirloom Mantle of Honor [STA, armor bit mail->leather, 3135 -> 1410 @255]
UPDATE `item_template` SET `ScalingStatValue` = 65 WHERE `entry` = 300345; -- Heirloom Shoulders of Valor [STR+AGI, armor bit mail->leather, 3135 -> 1410 @255]
-- chest
UPDATE `item_template` SET `ScalingStatValue` = 2097160 WHERE `entry` = 300347; -- Heirloom Chestplate of the Champion [STA, armor bit mail->leather, 4181 -> 1882 @255]
UPDATE `item_template` SET `ScalingStatValue` = 2097160 WHERE `entry` = 300348; -- Heirloom Battleplate [STR+AGI, armor bit mail->leather, 4181 -> 1882 @255]
-- hands
UPDATE `item_template` SET `ScalingStatValue` = 65 WHERE `entry` = 300353; -- Heirloom Gauntlets of Strength [STA, armor bit mail->leather, 3135 -> 1410 @255]
UPDATE `item_template` SET `ScalingStatValue` = 65 WHERE `entry` = 300354; -- Heirloom Grips of Precision [STR+AGI, armor bit mail->leather, 3135 -> 1410 @255]
-- legs
UPDATE `item_template` SET `ScalingStatValue` = 2097160 WHERE `entry` = 300359; -- Heirloom Legplates of the Conqueror [STA, armor bit mail->leather, 4181 -> 1882 @255]
UPDATE `item_template` SET `ScalingStatValue` = 2097160 WHERE `entry` = 300360; -- Heirloom Leggings of Swiftness [STR+AGI, armor bit mail->leather, 4181 -> 1882 @255]
-- feet
UPDATE `item_template` SET `ScalingStatValue` = 65 WHERE `entry` = 300362; -- Heirloom Sabatons of Fury [STA, armor bit mail->leather, 3135 -> 1410 @255]
UPDATE `item_template` SET `ScalingStatValue` = 65 WHERE `entry` = 300363; -- Heirloom Boots of Haste [STR+AGI, armor bit mail->leather, 3135 -> 1410 @255]

-- wrist (300350, 300351) and waist (300356, 300357) carry no armor bit, so
-- their ScalingStatValue is intentionally left alone.

-- --- verification ---------------------------------------------------------
SELECT i.`entry`, i.`name`, i.`subclass` AS item_subclass, d.`armor_type`,
       i.`ScalingStatValue` AS SSV, i.`InventoryType`
FROM `item_template` i
JOIN `dc_heirloom_definitions` d ON d.`item_id` = i.`entry`
WHERE i.`entry` IN (300341, 300342, 300344, 300345, 300347, 300348, 300350, 300351, 300353, 300354, 300356, 300357, 300359, 300360, 300362, 300363)
ORDER BY i.`InventoryType`, i.`entry`;
-- Expect 16 rows, every item_subclass = 2 and every armor_type = 2.
-- Any row where the two disagree means one of the first two statements missed.
