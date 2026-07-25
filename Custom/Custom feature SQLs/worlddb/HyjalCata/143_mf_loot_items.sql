-- ---------------------------------------------------------------------------
-- 143  Hyjal round-20 -- 11 more items the Hyjal / Molten Front loot references
-- ---------------------------------------------------------------------------
--     Table 'gameobject_loot_template' Entry 208593 Item 69813: item entry not
--     listed in `item_template` - skipped
--     Table 'pickpocketing_loot_template' Entry 52871 Item 58261 / 63271-63275
--     / 68196: item entry not listed in `item_template` - skipped
--
-- 140_ built the 20 items the QUEST loader complained about; these are the ones
-- the LOOT loader wants, which only surfaced once 124_'s loot tables were in and
-- actually being parsed.  Note the knock-on: every item in gameobject_loot
-- 208593 (Flame Druid Idol) was skipped, which then made the whole table entry
-- "not exist" -- so the object gave nothing.
--
-- Found with a full sweep rather than from the log: every Item referenced by a
-- creature/pickpocket/skinning/gameobject loot table that a 3,600,000-block
-- entry points at, diffed against item_template.  (Loot rows with Reference > 0
-- use the Item column as a reference id, not an item -- 10,788 of those exist,
-- and they have to be excluded or the sweep reports ids 1-9 as "missing items".)
--
-- Same generator and sources as 140_ (Cata Item.db2 + retail ItemSparse):
--   HyjalCata/tools/gen_mf_loot_items.py
-- 4 of the 11 have Cata display ids the fork's ItemDisplayInfo does not carry,
-- so those get 0 (no icon) rather than an id the core would reject.
--
-- CAVEAT: 58261 "Buttery Wheat Roll" and 63275 "Gilnean Fortified Brandy" are
-- class 0 subclass 5 (Food & Drink).  They are created as valid items but with
-- no `spellid_1`, so they are inert -- eating them does nothing.  Both are
-- pickpocket flavour loot off Druid of the Flame, so that is cosmetic; wire the
-- food spells if they are ever wanted as real consumables.
-- ---------------------------------------------------------------------------

DELETE FROM `item_template` WHERE `entry` IN (56234,58261,63271,63272,63273,63274,63275,68196,69813,71375,71376);

INSERT INTO `item_template` (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyCount`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`, `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `ContainerSlots`, `bonding`, `description`, `startquest`, `Material`, `sheath`, `BagFamily`, `ScriptName`, `VerifiedBuild`) VALUES
(56234, 15, 0, 'Smooth Scale', 37656, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, '', 0, 4, 0, 0, '', 0),
(58261, 0, 5, 'Buttery Wheat Roll', 26736, 1, 0, 1, 0, 0, 0, -1, -1, 32, 32, 0, 20, 0, 0, 'Sweet, warm, buttery goodness.', 0, 4, 0, 65536, '', 0),
(63271, 15, 0, 'A Steamy Romance Novel: Big Brass Bombs', 67003, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, '', 0, 4, 1, 0, '', 0),
(63272, 15, 0, 'Overwhelming Cologne', 34536, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, '', 0, 4, 1, 0, '', 0),
(63273, 15, 0, 'Checked Handkerchief', 7067, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, '', 0, 4, 1, 0, '', 0),
(63274, 15, 0, 'Rabbit''s Other Foot', 6682, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, 'Maybe this one is luckier!', 0, 4, 0, 0, '', 0),
(63275, 0, 5, 'Gilnean Fortified Brandy', 0, 1, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, '', 0, 3, 0, 65536, '', 0),
(68196, 15, 0, 'Corroded Bronze Rivet', 0, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, '', 0, 4, 0, 0, '', 0),
(69813, 12, 0, 'Flame Druid Idol', 43580, 1, 0, 1, 0, 0, 0, -1, -1, 1, 1, 0, 1, 0, 1, 'Signifies a flame druid''s tie to the element of fire.', 0, 4, 0, 0, '', 0),
(71375, 15, 0, 'Red Ash', 0, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, 'Ingredient in certain types of plant food.', 0, 7, 0, 0, '', 0),
(71376, 15, 0, 'Lava Ruby', 6006, 0, 0, 1, 0, 0, 0, -1, -1, 1, 0, 0, 20, 0, 0, 'Useless, but beautiful.', 0, 3, 0, 0, '', 0);
