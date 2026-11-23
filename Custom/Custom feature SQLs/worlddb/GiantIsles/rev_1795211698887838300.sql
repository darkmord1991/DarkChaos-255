-- DC: Giant Isles (map 1405) - loot for the island's surface mobs and Zandalari camps, and a graveyard per faction.
--
-- Every surface mob on the island had lootid 0 (gold only). The drops follow the MoP Isle of Giants loot of the same
-- creatures (bfa_world creature_loot_template for 69925 Zandalari Dinomancer and the dinosaurs 69983-70021,
-- skyfire_world has the spawns but no loot), each mapped to the level-80 item that plays the same part: Sharp Fangs
-- -> Serrated Fang, Saur Tusk -> Looped Tusk, Mote of Harmony -> Crystallized Life, Windwool -> Frostweave Cloth,
-- MoP level-90 food -> Salted Venison / Honeymint Tea, Ghost Iron -> Titanium Lockbox, the level-88 world greens ->
-- the DC World Loot Level 80 ladder (1200080 non-humanoid, 1200180 humanoid, as on the Northrend level-80 mobs).
-- The island pets that exist as DC Collection items keep their MoP rates: Direhorn Runt from the stegodons (the
-- island's direhorns), Anklerender / Footslasher / Kneebiter from the Dinomancers. Not carried over: Giant Dinosaur
-- Bone and Primal Egg (no such items on this server). The guards (Primal Warden, Beast Hunter, Tideguard Warden) get
-- nothing. With loot set, the playerbots grind cache also takes these mobs (it skips lootid 0).

-- Chaos Devilsaur
DELETE FROM `creature_loot_template` WHERE `Entry` = 400000;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400000, 39211, 0, 80, 0, 1, 0, 1, 3, 'Chaos Devilsaur - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400000, 39562, 0, 6, 0, 1, 0, 1, 1, 'Chaos Devilsaur - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400000, 37704, 0, 8, 0, 1, 0, 1, 1, 'Chaos Devilsaur - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400000, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Chaos Devilsaur - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400000, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Chaos Devilsaur - World Loot Level 80 (MoP level-88 world greens)');

-- Primal Stegodon
DELETE FROM `creature_loot_template` WHERE `Entry` = 400003;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400003, 39211, 0, 80, 0, 1, 0, 1, 3, 'Primal Stegodon - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400003, 39562, 0, 6, 0, 1, 0, 1, 1, 'Primal Stegodon - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400003, 37704, 0, 8, 0, 1, 0, 1, 1, 'Primal Stegodon - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400003, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Primal Stegodon - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400003, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Primal Stegodon - World Loot Level 80 (MoP level-88 world greens)'),
(400003, 301815, 0, 2, 0, 1, 0, 1, 1, 'Primal Stegodon - Cage of the Direhorn Runt (MoP Direhorn Runt 94573, 3%)');

-- Elder Stegodon
DELETE FROM `creature_loot_template` WHERE `Entry` = 400004;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400004, 39211, 0, 80, 0, 1, 0, 1, 3, 'Elder Stegodon - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400004, 39562, 0, 6, 0, 1, 0, 1, 1, 'Elder Stegodon - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400004, 37704, 0, 8, 0, 1, 0, 1, 1, 'Elder Stegodon - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400004, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Elder Stegodon - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400004, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Elder Stegodon - World Loot Level 80 (MoP level-88 world greens)'),
(400004, 301815, 0, 2, 0, 1, 0, 1, 1, 'Elder Stegodon - Cage of the Direhorn Runt (MoP Direhorn Runt 94573, 3%)');

-- Chaos Raptor
DELETE FROM `creature_loot_template` WHERE `Entry` = 400007;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400007, 39211, 0, 80, 0, 1, 0, 1, 3, 'Chaos Raptor - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400007, 39562, 0, 6, 0, 1, 0, 1, 1, 'Chaos Raptor - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400007, 37704, 0, 8, 0, 1, 0, 1, 1, 'Chaos Raptor - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400007, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Chaos Raptor - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400007, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Chaos Raptor - World Loot Level 80 (MoP level-88 world greens)');

-- Chaos Raptor Runner
DELETE FROM `creature_loot_template` WHERE `Entry` = 400008;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400008, 39211, 0, 80, 0, 1, 0, 1, 3, 'Chaos Raptor Runner - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400008, 39562, 0, 6, 0, 1, 0, 1, 1, 'Chaos Raptor Runner - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400008, 37704, 0, 8, 0, 1, 0, 1, 1, 'Chaos Raptor Runner - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400008, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Chaos Raptor Runner - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400008, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Chaos Raptor Runner - World Loot Level 80 (MoP level-88 world greens)');

-- Chaos Raptor Hunter
DELETE FROM `creature_loot_template` WHERE `Entry` = 400009;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400009, 39211, 0, 80, 0, 1, 0, 1, 3, 'Chaos Raptor Hunter - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400009, 39562, 0, 6, 0, 1, 0, 1, 1, 'Chaos Raptor Hunter - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400009, 37704, 0, 8, 0, 1, 0, 1, 1, 'Chaos Raptor Hunter - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400009, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Chaos Raptor Hunter - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400009, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Chaos Raptor Hunter - World Loot Level 80 (MoP level-88 world greens)');

-- Fledgling Chaos Pterrordax
DELETE FROM `creature_loot_template` WHERE `Entry` = 400011;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400011, 39211, 0, 80, 0, 1, 0, 1, 3, 'Fledgling Chaos Pterrordax - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400011, 39562, 0, 6, 0, 1, 0, 1, 1, 'Fledgling Chaos Pterrordax - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400011, 37704, 0, 8, 0, 1, 0, 1, 1, 'Fledgling Chaos Pterrordax - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400011, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Fledgling Chaos Pterrordax - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400011, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Fledgling Chaos Pterrordax - World Loot Level 80 (MoP level-88 world greens)');

-- Chaos Pterrordax
DELETE FROM `creature_loot_template` WHERE `Entry` = 400012;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400012, 39211, 0, 80, 0, 1, 0, 1, 3, 'Chaos Pterrordax - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400012, 39562, 0, 6, 0, 1, 0, 1, 1, 'Chaos Pterrordax - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400012, 37704, 0, 8, 0, 1, 0, 1, 1, 'Chaos Pterrordax - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400012, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Chaos Pterrordax - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400012, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Chaos Pterrordax - World Loot Level 80 (MoP level-88 world greens)');

-- Primal Crocodile
DELETE FROM `creature_loot_template` WHERE `Entry` = 400061;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400061, 39211, 0, 80, 0, 1, 0, 1, 3, 'Primal Crocodile - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400061, 39562, 0, 6, 0, 1, 0, 1, 1, 'Primal Crocodile - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400061, 37704, 0, 8, 0, 1, 0, 1, 1, 'Primal Crocodile - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400061, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Primal Crocodile - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400061, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Primal Crocodile - World Loot Level 80 (MoP level-88 world greens)');

-- Cavebone Ravasaur
DELETE FROM `creature_loot_template` WHERE `Entry` = 400273;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400273, 39211, 0, 80, 0, 1, 0, 1, 3, 'Cavebone Ravasaur - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400273, 39562, 0, 6, 0, 1, 0, 1, 1, 'Cavebone Ravasaur - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400273, 37704, 0, 8, 0, 1, 0, 1, 1, 'Cavebone Ravasaur - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400273, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Cavebone Ravasaur - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400273, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Cavebone Ravasaur - World Loot Level 80 (MoP level-88 world greens)');

-- Seeping Cave Pterrordax
DELETE FROM `creature_loot_template` WHERE `Entry` = 400274;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400274, 39211, 0, 80, 0, 1, 0, 1, 3, 'Seeping Cave Pterrordax - Serrated Fang (MoP Sharp Fangs 81194, 83%)'),
(400274, 39562, 0, 6, 0, 1, 0, 1, 1, 'Seeping Cave Pterrordax - Looped Tusk (MoP Saur Tusk 94243, 6%)'),
(400274, 37704, 0, 8, 0, 1, 0, 1, 1, 'Seeping Cave Pterrordax - Crystallized Life (MoP Mote of Harmony 89112, 8%)'),
(400274, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Seeping Cave Pterrordax - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.6%)'),
(400274, 1, 1200080, 0, 0, 1, 5, 1, 1, 'Seeping Cave Pterrordax - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Dinomancer
DELETE FROM `creature_loot_template` WHERE `Entry` = 400580;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400580, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Dinomancer - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400580, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400580, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400580, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400580, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400580, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Dinomancer - World Loot Level 80 (MoP level-88 world greens)'),
(400580, 301454, 0, 1.76, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Cage of the Zandalari Anklerender (MoP 95422, 1.76%)'),
(400580, 301455, 0, 1.29, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Cage of the Zandalari Footslasher (MoP 95423, 1.29%)'),
(400580, 301456, 0, 1.17, 0, 1, 0, 1, 1, 'Zandalari Dinomancer - Cage of the Zandalari Kneebiter (MoP 94126, 1.17%)');

-- Zandalari Invader
DELETE FROM `creature_loot_template` WHERE `Entry` = 400326;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400326, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Invader - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400326, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Invader - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400326, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Invader - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400326, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Invader - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400326, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Invader - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400326, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Invader - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Spearman
DELETE FROM `creature_loot_template` WHERE `Entry` = 400328;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400328, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Spearman - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400328, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Spearman - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400328, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Spearman - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400328, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Spearman - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400328, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Spearman - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400328, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Spearman - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Warrior
DELETE FROM `creature_loot_template` WHERE `Entry` = 400329;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400329, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Warrior - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400329, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Warrior - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400329, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Warrior - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400329, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Warrior - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400329, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Warrior - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400329, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Warrior - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Shadow Hunter
DELETE FROM `creature_loot_template` WHERE `Entry` = 400331;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400331, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Shadow Hunter - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400331, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Shadow Hunter - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400331, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Shadow Hunter - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400331, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Shadow Hunter - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400331, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Shadow Hunter - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400331, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Shadow Hunter - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Engine Crewman
DELETE FROM `creature_loot_template` WHERE `Entry` = 400583;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400583, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Engine Crewman - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400583, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Engine Crewman - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400583, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Engine Crewman - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400583, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Engine Crewman - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400583, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Engine Crewman - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400583, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Engine Crewman - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Cave Stalker
DELETE FROM `creature_loot_template` WHERE `Entry` = 400270;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400270, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Cave Stalker - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400270, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Cave Stalker - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400270, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Cave Stalker - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400270, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Cave Stalker - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400270, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Cave Stalker - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400270, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Cave Stalker - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Cave Hexxer
DELETE FROM `creature_loot_template` WHERE `Entry` = 400271;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400271, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Cave Hexxer - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400271, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Cave Hexxer - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400271, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Cave Hexxer - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400271, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Cave Hexxer - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400271, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Cave Hexxer - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400271, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Cave Hexxer - World Loot Level 80 (MoP level-88 world greens)');

-- Zandalari Boneguard
DELETE FROM `creature_loot_template` WHERE `Entry` = 400272;
INSERT INTO `creature_loot_template` (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
(400272, 33470, 0, 16, 0, 1, 0, 1, 3, 'Zandalari Boneguard - Frostweave Cloth (MoP Windwool Cloth 72988, 16%)'),
(400272, 33454, 0, 9.5, 0, 1, 0, 1, 1, 'Zandalari Boneguard - Salted Venison (MoP Skewered Peanut Chicken 81413, 9.6%)'),
(400272, 33445, 0, 5.5, 0, 1, 0, 1, 1, 'Zandalari Boneguard - Honeymint Tea (MoP Pearl Milk Tea 81414, 5.5%)'),
(400272, 37704, 0, 8, 0, 1, 0, 1, 1, 'Zandalari Boneguard - Crystallized Life (MoP Mote of Harmony 89112, 8.8%)'),
(400272, 43624, 0, 0.5, 0, 1, 0, 1, 1, 'Zandalari Boneguard - Titanium Lockbox (MoP Ghost Iron Lockbox 88567, 0.5%)'),
(400272, 1, 1200180, 0, 0, 1, 5, 1, 1, 'Zandalari Boneguard - World Loot Level 80 (MoP level-88 world greens)');

UPDATE `creature_template` SET `lootid` = `entry` WHERE `entry` IN (400000, 400003, 400004, 400007, 400008, 400009, 400011, 400012, 400061, 400273, 400274, 400580, 400326, 400328, 400329, 400331, 400583, 400270, 400271, 400272);

-- Graveyards: map 1405 had none, so a ghost stayed at its corpse and every death logged "graveyard_zone incomplete:
-- Zone 5006". One per faction, at its inn (MoP had a single Spirit Healer between the camps at 5950.8, 1154.8).
DELETE FROM `game_graveyard` WHERE `ID` IN (15143, 15144);
INSERT INTO `game_graveyard` (`ID`, `Map`, `x`, `y`, `z`, `Comment`) VALUES
(15143, 1405, 6037.81, 714.081, 51.4558, 'Giant Isles, Alliance camp (Innkeeper Molly) GY (1405)'),
(15144, 1405, 5880.33, 1542.16, 48.052, 'Giant Isles, Horde camp (Innkeeper Grok) GY (1405)');

DELETE FROM `graveyard_zone` WHERE `ID` IN (15143, 15144) AND `GhostZone` = 5006;
INSERT INTO `graveyard_zone` (`ID`, `GhostZone`, `Faction`, `Comment`) VALUES
(15143, 5006, 469, 'Giant Isles Alliance camp - Isles of Giants (1405), Alliance'),
(15144, 5006, 67, 'Giant Isles Horde camp - Isles of Giants (1405), Horde');
