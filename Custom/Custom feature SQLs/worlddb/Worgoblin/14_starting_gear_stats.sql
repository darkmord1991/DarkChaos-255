-- Worgoblin (races 12/9): populate stats on the 49 starting-outfit items
-- ------------------------------------------------------------------------
-- These items (entries 49399-49579, 52532, 52550-52552, referenced by
-- CharStartOutfit.dbc for races 12/9) came in via the wraith item downport
-- as appearance-only shells: ItemLevel 0, armor 0, all stat_type/value 0.
--
-- Checked against the real Cata reference (nelt_world.db_item-sparse_15595,
-- build 4.3.4): every one of these 49 items is genuinely stat-less there too
-- (ItemLevel 1, all Stat_Type/Value 0) - Blizzard ships Worgen/Goblin
-- starting "civvies" without stats, same spirit as WotLK's own Human/Orc
-- starting shirts/pants. So this is NOT a case of copying real Cata armor
-- values (there aren't any) - it's backfilling DC's own ilvl-1 armor
-- convention so Worgen/Goblin gear isn't visibly weaker than every other
-- race's starting robe/pants at a glance.
--
-- Armor values = MAX(armor) already present in this item_template for
-- ItemLevel=1, Quality<=2 items of the same class/subclass/InventoryType
-- (i.e. "what does DC's own DB already consider correct for ilvl-1 gear of
-- this armor type and slot"). Plate belt/gloves have no ilvl-1 precedent in
-- the DB, so those two are extrapolated from the ilvl-40 plate slot ratios
-- (belt =~ 0.64x legs, gloves =~ 0.72x legs) applied to the real ilvl-1
-- plate legs value (34): belt=22, gloves=24.
UPDATE `item_template`
SET `armor` = CASE
        WHEN `subclass` = 1 AND `InventoryType` IN (7, 8) THEN 2
        WHEN `subclass` = 1 AND `InventoryType` = 20 THEN 3
        WHEN `subclass` = 2 AND `InventoryType` = 5 THEN 17
        WHEN `subclass` = 2 AND `InventoryType` = 7 THEN 14
        WHEN `subclass` = 2 AND `InventoryType` = 8 THEN 11
        WHEN `subclass` = 2 AND `InventoryType` = 10 THEN 10
        WHEN `subclass` = 3 AND `InventoryType` = 5 THEN 37
        WHEN `subclass` = 3 AND `InventoryType` = 6 THEN 20
        WHEN `subclass` = 3 AND `InventoryType` = 7 THEN 32
        WHEN `subclass` = 3 AND `InventoryType` = 8 THEN 25
        WHEN `subclass` = 3 AND `InventoryType` = 10 THEN 23
        WHEN `subclass` = 4 AND `InventoryType` = 5 THEN 39
        WHEN `subclass` = 4 AND `InventoryType` = 6 THEN 22
        WHEN `subclass` = 4 AND `InventoryType` = 7 THEN 34
        WHEN `subclass` = 4 AND `InventoryType` = 8 THEN 27
        WHEN `subclass` = 4 AND `InventoryType` = 10 THEN 24
        ELSE `armor`
    END,
    `ItemLevel` = 1
WHERE `entry` IN (
    49399, 49400, 49401, 49403, 49404, 49406, 49407, 49408, 49409,
    49502, 49503, 49504, 49505, 49506, 49508, 49510, 49512, 49514, 49515, 49516,
    49520, 49521, 49522, 49524, 49527, 49528, 49529, 49531, 49563, 49564, 49565,
    49566, 49567, 49568, 49569, 49570, 49571, 49572, 49573, 49574, 49575, 49576,
    49577, 49578, 49579, 52550, 52551, 52552
)
AND `class` = 4;

-- Starting weapon (Worn Wood Chopper): the appearance-only shell left it at
-- 0-0 damage, a genuinely non-functional weapon (unlike 0-armor civvies,
-- a 0-damage weapon can't do anything). Mirror stock 3.3.5 "Worn Battleaxe"
-- (12282) - identical class/subclass/InventoryType, same starting-weapon tier.
UPDATE `item_template`
SET `dmg_min1` = 3, `dmg_max1` = 5, `delay` = 2900, `ItemLevel` = 1
WHERE `entry` = 52532;
