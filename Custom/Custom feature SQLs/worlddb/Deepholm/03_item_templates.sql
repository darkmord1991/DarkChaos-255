-- =====================================================================
-- Deepholm Downport  --  03  Item templates (missing quest + vendor items)
-- ---------------------------------------------------------------------
-- Generated from the retail wow.export extracts Item.csv + ItemSparse.csv
-- (Item.csv -> class/subclass/inventoryType; ItemSparse.csv -> name/quality/
-- levels/prices/stackable/bonding). Covers the 45 quest-referenced + 8 vendor
-- items that Deepholm content needs but acore_world.item_template lacks.
--
-- Notes / follow-ups:
--   * displayid = real DisplayInfoID from the Cata 4.3.4 client Item.db2 (field 5).
--     30 of these display ids already exist in Custom/CSV DBC/ItemDisplayInfo.csv;
--     the 23 that did not are added by 03b_itemdisplayinfo_additions.csv (icons).
--   * The 8 Inscriptions (class 0 / subclass 8) are purchasable but their
--     shoulder-enchant ON-USE spell lives in ItemEffect.db2 (not in these two
--     CSVs) -- add spellid_1/spelltrigger_1 once ItemEffect is extracted.
--   * Unspecified item_template columns fall back to table defaults.
-- =====================================================================

DELETE FROM `item_template` WHERE `entry` IN (58168,58169,58177,58254,58500,58501,58502,58845,58884,58885,58886,58944,58959,58965,59062,59123,59144,59323,60264,60266,60297,60382,60383,60487,60490,60501,60504,60574,60575,60745,60758,60767,60773,60791,60810,60814,60816,60831,60834,60835,60837,61399,61437,61440,62321,62333,62342,62343,62344,62345,62346,62347,64404);

INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`name`,`displayid`,`Quality`,`Flags`,`BuyCount`,`BuyPrice`,`SellPrice`,
 `InventoryType`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`bonding`,`startquest`,`Material`,`sheath`,`VerifiedBuild`)
VALUES
(58168,12,0,'Irestone Core',69417,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(58169,12,0,'Elementium Grapple Line',48725,1,0,1,0,0,0,1,0,0,1,4,0,4,0,0),
(58177,12,0,'Earthen Ring Proclamation',55297,1,0,1,0,0,0,1,0,0,1,4,0,4,0,0),
(58254,12,0,'Delicate Chain Smasher',4717,1,0,1,0,0,0,1,0,0,1,4,0,4,0,0),
(58500,12,0,'Jade Crystal Cluster',6673,1,0,1,0,0,0,1,0,0,8,4,0,4,0,0),
(58501,12,0,'Quartzite Resin',70125,1,0,1,0,0,0,1,0,0,20,4,0,1,0,0),
(58502,12,0,'Explosive Bonding Compound',37853,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(58845,12,0,'Chalky Crystal Formation',13496,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(58884,12,0,'Stonefather''s Banner',38759,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(58885,12,0,'Rockslide Reagent',38617,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(58886,12,0,'Thunder Stone',19239,1,0,1,0,0,0,1,0,0,20,4,0,1,0,0),
(58944,12,0,'Catapult Part',36687,1,0,1,0,0,0,1,0,0,20,4,0,1,0,0),
(58959,12,0,'Petrified Stone Bat',69991,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(58965,12,0,'Deepvein''s Patch Kit',66122,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(59062,12,0,'Blood of Neltharion',15770,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(59123,12,0,'Verlok Miracle-Grow',2593,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(59144,12,0,'The Earthinator''s Cudgel',70216,1,0,1,0,0,0,1,0,1,1,4,0,8,0,0),
(59323,12,0,'Stonework Mallet',70249,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(60264,12,0,'Twilight Orders',3020,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(60266,12,0,'Stonework Mallet',70249,1,0,1,0,0,0,1,0,0,1,4,0,4,0,0),
(60297,12,0,'Side of Basilisk Meat',25467,1,0,1,0,0,0,1,0,10,10,4,0,4,0,0),
(60382,12,0,'Mylra''s Knife',70627,1,0,1,0,0,0,1,1,0,1,4,0,4,0,0),
(60383,12,0,'Twilight Snare',70628,1,0,1,0,0,0,1,1,0,1,4,0,4,0,0),
(60487,12,0,'Elemental Ore',20658,1,0,1,0,0,0,1,0,0,20,4,0,1,0,0),
(60490,12,0,'The Axe of Earthly Sundering',70757,1,0,1,0,0,0,1,0,1,1,4,0,1,0,0),
(60501,12,0,'Stormstone',8560,1,0,1,0,0,0,1,1,1,1,4,0,4,0,0),
(60504,12,0,'Painite Chunk',44729,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(60574,0,8,'The Upper World Pillar Fragment',70772,1,0,1,0,0,0,1,1,0,1,4,0,4,0,0),
(60575,12,0,'The Middle Fragment of the World Pillar',70772,1,0,1,0,0,0,1,0,1,1,4,0,8,0,0),
(60745,12,0,'Masters'' Gate Plans',60716,1,0,1,0,0,0,1,0,1,1,4,0,1,0,0),
(60758,12,0,'Encrypted Plans',60716,1,0,1,0,0,0,1,0,1,1,4,0,1,0,0),
(60767,12,0,'Bag of Verlok Miracle-Grow',2593,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(60773,12,0,'Trapped Basilisk Meat',25467,1,0,1,0,0,0,1,0,1,1,4,0,4,0,0),
(60791,12,0,'Painite Mote',54469,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0),
(60810,12,0,'Earthen Ring Banner',19562,1,0,1,0,0,0,1,1,1,1,4,0,4,0,0),
(60814,0,8,'Twilight Research Notes',7629,1,0,1,0,0,0,1,1,0,8,4,0,4,0,0),
(60816,0,8,'Maziel''s Research',7629,1,0,1,0,0,0,31,30,1,1,1,27100,4,0,0),
(60831,12,0,'Catapult Parts',36687,1,0,1,0,0,0,1,0,1,1,4,0,1,0,0),
(60834,12,0,'Goldmine''s Fire Totem',71182,1,0,1,0,0,0,1,0,1,1,4,0,2,0,0),
(60835,12,0,'Depleted Totem',105413,1,0,1,0,0,0,1,1,1,1,4,0,4,0,0),
(60837,12,0,'The Burning Heart',71172,1,0,1,0,0,0,1,0,1,1,4,0,8,0,0),
(61399,15,0,'Emerald Heart',56640,0,0,1,275924,55184,0,36,0,0,1,1,0,2,0,0),
(61437,15,0,'Relic of the Waywalker',34795,0,0,1,285079,57015,0,36,0,0,1,1,0,2,0,0),
(61440,15,0,'Relic of the Waywalker',56640,0,0,1,288230,57646,0,36,0,0,1,1,0,2,0,0),
(62321,0,8,'Lesser Inscription of Unbreakable Quartz',72301,3,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62333,0,8,'Greater Inscription of Unbreakable Quartz',72301,4,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62342,0,8,'Lesser Inscription of Charged Lodestone',72304,3,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62343,0,8,'Greater Inscription of Charged Lodestone',72304,4,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62344,0,8,'Lesser Inscription of Jagged Stone',72305,3,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62345,0,8,'Greater Inscription of Jagged Stone',72305,4,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62346,0,8,'Greater Inscription of Shattered Crystal',72306,4,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(62347,0,8,'Lesser Inscription of Shattered Crystal',72306,3,0,1,750000,187500,0,32,32,0,1,1,0,4,0,0),
(64404,12,0,'Ruby Crystal Cluster',37250,1,0,1,0,0,0,1,0,0,20,4,0,4,0,0);
