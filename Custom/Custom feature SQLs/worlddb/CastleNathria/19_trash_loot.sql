-- Castle Nathria (map 2296) -- trash / mini-boss creature_loot_template rows.
--
-- Scope: the DB-content transcode pass (05-12) deliberately left trash unlooted (only the
-- 7-10 boss-tier encounters got real loot, see castle-nathria-item-loot-coverage memory).
-- This file fills in real source loot for the ~89 named trash/mini-boss entries used across
-- Castle Nathria's 148-entry creature_template roster that still had zero creature_loot_template
-- rows as of this pass (verified via a live `SELECT Entry, COUNT(*) ... GROUP BY Entry` against
-- this fork's own world DB before starting -- confirmed 0 rows for all 89 target entries).
--
-- Sources checked, in the order specified for this pass:
--   1) SLDB_902_world_2021_03_12.sql (543MB shadowcore base dump, same source 10_loot.sql used).
--      `creature_loot_template` is declared once (line ~841681) with a single `insert into`
--      statement (one row per physical line, table data spans lines 841697-2744705 -- verified
--      against the next `/*Table structure for table ...*/` marker, `creature_model_info` at
--      2744706, so this range is exact). Searched with an anchored `^\(ID,` regex restricted to
--      that line range only (NOT the whole 543MB file -- a first attempt without the range
--      restriction matched 1219 lines because these are generic 6-digit Shadowlands ids that also
--      appear as the leading column of the `creature` spawn table, `creature_addon`, etc.; the
--      range-restricted search correctly found exactly 254 real loot rows across 32 of the 89
--      target entries).
--   2) TDB_full_world_1200.26021_2026_02_06.sql (597MB TrinityCore/AzerothCore master TDB dump,
--      new source discovered this session) -- checked as a fallback for the 57 entries absent from
--      source #1. `creature_loot_template`'s data is a handful of giant one-line `INSERT` statements
--      (lines 1167-1177); extracted those lines and grepped for all 57 missing entry ids anchored on
--      `(ID,` -- zero matches. This is expected: TDB master is upstream AzerothCore content (Classic/
--      TBC/Wrath), it was never going to carry Shadowlands raid-trash loot; it was only ever useful
--      for name lookups on this project (see castle-nathria-db-content-transcode memory, mojibake-name
--      fix). Confirms these 57 are a genuine source-data gap, not a search miss.
--
-- Result: 32 of the 89 entries have real loot below (254 rows total). The other 57 have NO
-- creature_loot_template rows in either source -- gold-only, no fake ids invented to compensate:
--   165469 Nathrian Enforcer, 165471 Nathrian Duelist, 165474 Nathrian Assassin, 165481 Court
--   Assassin, 165483 Court Hierarch, 165763 Vile Occultist, 165764 Rockbound Vanquisher, 167566
--   Bleakwing Assassin, 168700 Pestering Fiend, 168973 High Torturer Darithos, 169196 Crimson
--   Cabalist, 169457 Bargast, 169458 Hecutis, 169601 Stone Legion Commando, 171145 Feasting
--   Venthyr, 171146 Belligerent Waiter, 171577 Ripped Soul, 172858 Stone Legion Goliath, 172899
--   Nathrian Enforcer, 172902 Nathrian Duelist, 172903 Nathrian Executor, 173015 Nathrian Heavy
--   Enforcer, 173142 Dread Feaster, 173178 Stone Legion Goliath, 173189 Nathrian Hawkeye, 173298
--   General Kaal, 173434 General Grashaal, 173609 Nathrian Conservator, 173641 Nathrian Gargon,
--   173949 Nathrian Soldier, 173973 Nathrian Tracker, 174069 Hulking Gargon, 174071 Vicious
--   Gargon, 174093 Nathrian Ranger, 174100 Nathrian Singuard, 174126 Baron Duskhollow, 174141
--   Dusty Widow, 174194 Court Executor, 174208 Court Executor, 174337 Nathrian Gargon, 174338
--   Stinky Feedhauler, 174878 Belligerent Waiter, 175527 Winged Ravager, 175894 Loyal Gargon,
--   176015 Stonewrought Guardian, 165067 Margore, 168156 Remornia, 168158 Remornia, 169267 Root
--   of Extinction, 172651 The Accuser, 172652 Prince Renathal, 172653 General Draven, 170404
--   General Draven, 173119 Prince Renathal, 173120 General Draven, 175232 General Kaal, 175233
--   General Grashaal.
--
-- Column order copied straight across (`Entry,Item,Reference,Chance,QuestRequired,LootMode,
-- GroupId,MinCount,MaxCount,Comment` -- identical order in source and this fork's schema, no
-- reordering needed). Unlike 10_loot.sql / 12_loot_journal_supplement.sql (which curate a 72-item
-- allowlist into a single GroupId=1 bucket summing to ~100% chance), this file preserves the
-- source's own GroupId/Chance/QuestRequired/LootMode values verbatim -- this is a straight
-- transcode of real trash loot tables, not a curated boss-loot pass.
--
-- Schema-range validation (per this fork's live `creature_loot_template` schema, fetched via
-- mcp__acmcp__get_table_schema before writing anything): Entry/Item = int unsigned, Reference =
-- int (signed), Chance = float, QuestRequired = tinyint (signed), LootMode = smallint unsigned,
-- GroupId/MinCount/MaxCount = tinyint unsigned (max 255 -- the specific field the task brief
-- flagged, since source MinCount/MaxCount are `int(10) unsigned` (wide) in the 2021 dump's own
-- CREATE TABLE). Every one of the 254 extracted rows was checked column-by-column against these
-- ranges: QuestRequired is 0 or 1 everywhere, GroupId is 0-2, MinCount/MaxCount are 1-3 everywhere
-- (real trash loot count values, nowhere near the tinyint ceiling) -- 0 violations, nothing
-- clamped.
--
-- Item cross-check against this fork's live `item_template` (queried via mcp__acmcp__query_database
-- in batches covering all ~89 unique Item ids referenced below): 71 of 89 exist (real downported
-- gear, mostly Revendreth/Castle Nathria trash greens+blues already covered by the broader item
-- downport pass). 18 did NOT exist in item_template at authoring time (comments below originally
-- read "NOT in item_template") -- 173202/173204 (the dominant 40-85% chance filler slot on nearly
-- every creature below), 178061/178113/178115/178128/178131/178132 (recurring secondary filler),
-- 173705/173715/173871/173875/176852/176860/176862/180310/180453/180834 (creature-specific one-off
-- drops, incl. 176852/176860/176862 on the two rat-themed trash entries 173798/173800).
--
-- **RESOLVED in `20_missing_trash_items.sql`**: all 18 turned out to be real Shadowlands trade-good/
-- junk/quest-token items -- this SL-era source dump simply has no `item_template` table to look them
-- up in (only `item_template_addon`). Recovered from the retail client's Item.db2/ItemSparse.db2
-- (decoded from the 9.2.7 DekkCore repack, since 12.0.7's copies are TACT-encrypted) and downported
-- with real names/stats + icon-only ItemDisplayInfo rows. Comments below now carry the real item
-- names instead of the stale "NOT in item_template" flag.
--
-- Apply against acore_world.

DELETE FROM `creature_loot_template` WHERE `Entry` IN
    (165470,165472,165479,168337,173145,173146,173190,173276,173280,173444,173445,173446,173448,
     173464,173466,173469,173568,173604,173613,173633,173798,173800,173802,174012,174070,174090,
     174092,174134,174162,174336,174842,174843);

-- ---------------------------------------------------------------------------
-- Nathrian Executor (165470)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (165470, 173202, 0, 75.6757, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (165470, 173204, 0, 12.1622, 0, 1, 0, 1, 2, 'Lightless Silk'),
    (165470, 177734, 0, 2.7027, 0, 1, 0, 1, 1, 'Crumbling Plate Shoulderguards'),
    (165470, 177735, 0, 1.35135, 0, 1, 0, 1, 1, 'Crumbling Plate Legguards'),
    (165470, 177737, 0, 1.35135, 0, 1, 0, 1, 1, 'Crumbling Plate Gloves'),
    (165470, 177741, 0, 1.35135, 0, 1, 0, 1, 1, 'Dredged Chain Spaulders'),
    (165470, 177753, 0, 1.35135, 0, 1, 0, 1, 1, 'Mire-Stained Leather Shoulderpads'),
    (165470, 177772, 0, 1.35135, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Cord'),
    (165470, 177790, 0, 2.7027, 0, 1, 0, 1, 1, 'Night Guardian Footguards'),
    (165470, 177800, 0, 1.35135, 0, 1, 0, 1, 1, 'Bubbling Concoction'),
    (165470, 177804, 0, 1.35135, 0, 1, 0, 1, 1, 'Ritualist Dagger'),
    (165470, 177811, 0, 1.35135, 0, 1, 0, 1, 1, 'Depraved Tutor''s Signet'),
    (165470, 179319, 0, 1.35135, 0, 1, 0, 1, 1, 'Caged Cudgel'),
    (165470, 182990, 0, 1.35135, 0, 1, 0, 1, 1, 'Legionnaire''s Bloodstained Sabatons'),
    (165470, 183035, 0, 2.7027, 0, 1, 0, 1, 1, 'Ardent Sunstar Signet');

-- ---------------------------------------------------------------------------
-- Nathrian Siphoner (165472)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (165472, 173202, 0, 77, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (165472, 173204, 0, 15, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (165472, 177743, 0, 0.558659, 0, 1, 0, 1, 1, 'Dredged Chain Breeches'),
    (165472, 177745, 0, 0.558659, 0, 1, 0, 1, 1, 'Dredged Chain Gauntlets'),
    (165472, 177746, 0, 0.558659, 0, 1, 0, 1, 1, 'Dredged Chain Helm'),
    (165472, 177747, 0, 0.558659, 0, 1, 0, 1, 1, 'Dredged Chain Clasp'),
    (165472, 177748, 0, 0.558659, 0, 1, 0, 1, 1, 'Mire-Stained Leather Cinch'),
    (165472, 177750, 0, 0.558659, 0, 1, 0, 1, 1, 'Mire-Stained Leather Handwraps'),
    (165472, 177751, 0, 0.558659, 0, 1, 0, 1, 1, 'Mire-Stained Leather Guise'),
    (165472, 177752, 0, 0.558659, 0, 1, 0, 1, 1, 'Mire-Stained Leather Leggings'),
    (165472, 177753, 0, 0.558659, 0, 1, 0, 1, 1, 'Mire-Stained Leather Shoulderpads'),
    (165472, 177756, 0, 1.11732, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Armbands'),
    (165472, 177758, 0, 1.11732, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Slippers'),
    (165472, 177759, 0, 0.558659, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Legwraps'),
    (165472, 177774, 0, 0.558659, 0, 1, 0, 1, 1, 'Depraved Darkblade''s Treads'),
    (165472, 177783, 0, 0.558659, 0, 1, 0, 1, 1, 'Savage Bonemauler Helm'),
    (165472, 177786, 0, 0.558659, 0, 1, 0, 1, 1, 'Savage Bonemauler Cinch'),
    (165472, 177799, 0, 1.11732, 0, 1, 0, 1, 1, 'Stoneborn Shield'),
    (165472, 177805, 0, 1.11732, 0, 1, 0, 1, 1, 'Redeemer''s Mace'),
    (165472, 177809, 0, 1.11732, 0, 1, 0, 1, 1, 'Lithe Rapier'),
    (165472, 177816, 0, 0.558659, 0, 1, 0, 1, 1, 'Dredhollow Cape'),
    (165472, 179311, 0, 0.558659, 0, 1, 0, 1, 1, 'Barkweave Wristwraps'),
    (165472, 179319, 0, 0.558659, 0, 1, 0, 1, 1, 'Caged Cudgel'),
    (165472, 179332, 0, 0.558659, 0, 1, 0, 1, 1, 'Stone Sentinel Poleaxe'),
    (165472, 183010, 0, 0.558659, 0, 1, 0, 1, 1, 'Stud-Scarred Footwear');

-- ---------------------------------------------------------------------------
-- Court Enforcer (165479)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (165479, 173202, 0, 81.5789, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (165479, 173204, 0, 12.2807, 0, 1, 0, 1, 2, 'Lightless Silk'),
    (165479, 177742, 0, 0.877193, 0, 1, 0, 1, 1, 'Dredged Chain Footguards'),
    (165479, 177743, 0, 0.877193, 0, 1, 0, 1, 1, 'Dredged Chain Breeches'),
    (165479, 177755, 0, 0.877193, 0, 1, 0, 1, 1, 'Mire-Stained Leather Bracers'),
    (165479, 177756, 0, 0.877193, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Armbands'),
    (165479, 177757, 0, 1.75439, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Tunic'),
    (165479, 177758, 0, 0.877193, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Slippers'),
    (165479, 177761, 0, 0.877193, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Hood'),
    (165479, 177779, 0, 0.877193, 0, 1, 0, 1, 1, 'Depraved Darkblade''s Bindings'),
    (165479, 177786, 0, 0.877193, 0, 1, 0, 1, 1, 'Savage Bonemauler Cinch'),
    (165479, 177802, 0, 0.877193, 0, 1, 0, 1, 1, 'Hopebreaker Carbine'),
    (165479, 178061, 0, 3.50877, 0, 1, 0, 1, 1, 'Malleable Flesh'),
    (165479, 179323, 0, 0.877193, 0, 1, 0, 1, 1, 'Dredhollow Cudgel'),
    (165479, 179332, 0, 0.877193, 0, 1, 0, 1, 1, 'Stone Sentinel Poleaxe'),
    (165479, 183971, 0, 0.877193, 0, 1, 0, 1, 1, 'Depraved Ritualist''s Kris'),
    (165479, 184778, 0, 1.75439, 0, 1, 0, 1, 1, 'Decadent Nathrian Shawl');

-- ---------------------------------------------------------------------------
-- Moldovaak (168337)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (168337, 173202, 0, 47, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (168337, 177768, 0, 5.88235, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Sandals'),
    (168337, 178113, 0, 11.7647, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (168337, 178115, 0, 11.7647, 0, 1, 0, 1, 1, 'Tapping Stone Claw'),
    (168337, 178131, 0, 29.4118, 0, 1, 0, 1, 1, 'Whetstone Talon File');

-- ---------------------------------------------------------------------------
-- Gorging Mite (173145)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173145, 173871, 0, 46.2463, 0, 1, 0, 1, 1, 'Harrowed Ichor'),
    (173145, 173875, 0, 5.1051, 0, 1, 0, 1, 1, 'Defiling Mire'),
    (173145, 176871, 0, 48.6487, 0, 1, 0, 1, 1, 'Item 176871 (NOT in item_template)'),
    (173145, 177768, 0, 0.3003, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Sandals'),
    (173145, 177780, 0, 0.600601, 0, 1, 0, 1, 1, 'Savage Bonemauler Chainmail'),
    (173145, 177794, 0, 0.600601, 0, 1, 0, 1, 1, 'Night Guardian Cincture'),
    (173145, 177796, 0, 0.3003, 0, 1, 0, 1, 1, 'Depraved Darkblade''s Tunic'),
    (173145, 177799, 0, 0.600601, 0, 1, 0, 1, 1, 'Stoneborn Shield'),
    (173145, 177800, 0, 0.3003, 0, 1, 0, 1, 1, 'Bubbling Concoction'),
    (173145, 177801, 0, 0.3003, 0, 1, 0, 1, 1, 'Sky Legion Halbard'),
    (173145, 177802, 0, 0.3003, 0, 1, 0, 1, 1, 'Hopebreaker Carbine'),
    (173145, 177804, 0, 0.3003, 0, 1, 0, 1, 1, 'Ritualist Dagger'),
    (173145, 177805, 0, 0.3003, 0, 1, 0, 1, 1, 'Redeemer''s Mace'),
    (173145, 179319, 0, 0.3003, 0, 1, 0, 1, 1, 'Caged Cudgel'),
    (173145, 183035, 0, 0.600601, 0, 1, 0, 1, 1, 'Ardent Sunstar Signet');

-- ---------------------------------------------------------------------------
-- Winged Ravager (173146)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173146, 173871, 0, 48.2993, 0, 1, 0, 1, 1, 'Harrowed Ichor'),
    (173146, 173875, 0, 4.76191, 0, 1, 0, 1, 1, 'Defiling Mire'),
    (173146, 176871, 0, 47, 0, 1, 0, 1, 1, 'Item 176871 (NOT in item_template)'),
    (173146, 177773, 0, 1.36054, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Wristwraps'),
    (173146, 177805, 0, 0.680272, 0, 1, 0, 1, 1, 'Redeemer''s Mace'),
    (173146, 179319, 0, 0.680272, 0, 1, 0, 1, 1, 'Caged Cudgel'),
    (173146, 179334, 0, 0.680272, 0, 1, 0, 1, 1, 'Wingblade Staff'),
    (173146, 182990, 0, 0.680272, 0, 1, 0, 1, 1, 'Legionnaire''s Bloodstained Sabatons'),
    (173146, 183013, 0, 0.680272, 0, 1, 0, 1, 1, 'Fallen Templar''s Gauntlets');

-- ---------------------------------------------------------------------------
-- Court Hawkeye (173190)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173190, 173202, 0, 81, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173190, 173204, 0, 8.10811, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173190, 177733, 0, 5.40541, 0, 1, 0, 1, 1, 'Crumbling Plate Warboots'),
    (173190, 177744, 0, 2.7027, 0, 1, 0, 1, 1, 'Dredged Chain Vest'),
    (173190, 177751, 0, 2.7027, 0, 1, 0, 1, 1, 'Mire-Stained Leather Guise'),
    (173190, 177758, 0, 2.7027, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Slippers'),
    (173190, 177763, 0, 2.7027, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Mantle'),
    (173190, 177780, 0, 2.7027, 0, 1, 0, 1, 1, 'Savage Bonemauler Chainmail'),
    (173190, 177794, 0, 2.7027, 0, 1, 0, 1, 1, 'Night Guardian Cincture'),
    (173190, 177801, 0, 2.7027, 0, 1, 0, 1, 1, 'Sky Legion Halbard'),
    (173190, 177806, 0, 2.7027, 0, 1, 0, 1, 1, 'Banewood Dirk'),
    (173190, 177810, 0, 5.40541, 0, 1, 0, 1, 1, 'Stonebreaker Mace'),
    (173190, 182982, 0, 2.7027, 0, 1, 0, 1, 1, 'Watchful Arbelist''s Bracers'),
    (173190, 183031, 0, 2.7027, 0, 1, 0, 1, 1, 'Soldier''s Stoneband Wristguards');

-- ---------------------------------------------------------------------------
-- Stone Legion Commando (173276)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173276, 173202, 0, 50, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (173276, 173204, 0, 25, 0, 1, 0, 2, 2, 'Lightless Silk'),
    (173276, 177735, 0, 25, 0, 1, 0, 1, 1, 'Crumbling Plate Legguards'),
    (173276, 178113, 0, 25, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (173276, 178131, 0, 25, 0, 1, 0, 1, 1, 'Whetstone Talon File');

-- ---------------------------------------------------------------------------
-- Stone Legion Skirmisher (173280)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173280, 173204, 0, 14.2857, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173280, 178113, 0, 57.1429, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (173280, 178115, 0, 14.2857, 0, 1, 0, 1, 1, 'Tapping Stone Claw'),
    (173280, 180453, 0, 28.5714, 1, 1, 0, 1, 1, 'She Had a Stone Heart');

-- ---------------------------------------------------------------------------
-- Caramain (173444)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173444, 173202, 0, 47, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173444, 173204, 0, 11.7647, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173444, 177733, 0, 5.88235, 0, 1, 0, 1, 1, 'Crumbling Plate Warboots'),
    (173444, 178061, 0, 5.88235, 0, 1, 0, 1, 1, 'Malleable Flesh'),
    (173444, 178113, 0, 35.2941, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (173444, 179311, 0, 5.88235, 0, 1, 0, 1, 1, 'Barkweave Wristwraps'),
    (173444, 179334, 0, 5.88235, 0, 1, 0, 1, 1, 'Wingblade Staff'),
    (173444, 180453, 0, 5.88235, 1, 1, 0, 1, 1, 'She Had a Stone Heart');

-- ---------------------------------------------------------------------------
-- Sindrel (173445)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173445, 173202, 0, 44.4444, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173445, 173204, 0, 11.1111, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173445, 178061, 0, 5.55555, 0, 1, 0, 2, 2, 'Malleable Flesh'),
    (173445, 178113, 0, 44.4444, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (173445, 178115, 0, 11.1111, 0, 1, 0, 1, 1, 'Tapping Stone Claw'),
    (173445, 178131, 0, 5.55555, 0, 1, 0, 1, 1, 'Whetstone Talon File'),
    (173445, 179334, 0, 11.1111, 0, 1, 0, 1, 1, 'Wingblade Staff');

-- ---------------------------------------------------------------------------
-- Hargitas (173446)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173446, 173202, 0, 39.1304, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (173446, 173204, 0, 13, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173446, 177739, 0, 4.34783, 0, 1, 0, 1, 1, 'Crumbling Plate Greatbelt'),
    (173446, 177806, 0, 4.34783, 0, 1, 0, 1, 1, 'Banewood Dirk'),
    (173446, 178061, 0, 13, 0, 1, 0, 1, 2, 'Malleable Flesh'),
    (173446, 178113, 0, 26, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (173446, 178115, 0, 8.69565, 0, 1, 0, 1, 1, 'Tapping Stone Claw'),
    (173446, 178131, 0, 8.69565, 0, 1, 0, 1, 1, 'Whetstone Talon File'),
    (173446, 179311, 0, 4.34783, 0, 1, 0, 1, 1, 'Barkweave Wristwraps');

-- ---------------------------------------------------------------------------
-- Dragost (173448)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173448, 173202, 0, 73.3333, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173448, 173204, 0, 13.3333, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173448, 173705, 0, 6.66667, 1, 1, 0, 1, 1, 'The Venthyr Diaries'),
    (173448, 177744, 0, 6.66667, 0, 1, 0, 1, 1, 'Dredged Chain Vest'),
    (173448, 177753, 0, 13.3333, 0, 1, 0, 1, 1, 'Mire-Stained Leather Shoulderpads'),
    (173448, 178061, 0, 20, 0, 1, 0, 1, 3, 'Malleable Flesh');

-- ---------------------------------------------------------------------------
-- Deplina (173464)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173464, 173202, 0, 76.4706, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173464, 173204, 0, 11.7647, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173464, 177735, 0, 5.88235, 0, 1, 0, 1, 1, 'Crumbling Plate Legguards'),
    (173464, 177799, 0, 5.88235, 0, 1, 0, 1, 1, 'Stoneborn Shield'),
    (173464, 177806, 0, 5.88235, 0, 1, 0, 1, 1, 'Banewood Dirk'),
    (173464, 182978, 0, 5.88235, 0, 1, 0, 1, 1, 'Barkweave Wristwraps'),
    (173464, 183008, 0, 5.88235, 0, 1, 0, 1, 1, 'Supple Supplicant''s Gloves');

-- ---------------------------------------------------------------------------
-- Fara (173466)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173466, 173202, 0, 80, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (173466, 173204, 0, 20, 0, 1, 0, 1, 1, 'Lightless Silk');

-- ---------------------------------------------------------------------------
-- Kullan (173469)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173469, 173202, 0, 80, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (173469, 173204, 0, 13.3333, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173469, 173705, 0, 6.66667, 1, 1, 0, 1, 1, 'The Venthyr Diaries'),
    (173469, 183035, 0, 6.66667, 0, 1, 0, 1, 1, 'Ardent Sunstar Signet');

-- ---------------------------------------------------------------------------
-- Anima Crazed Worker (173568)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173568, 173202, 0, 76, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173568, 173204, 0, 16, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173568, 177737, 0, 2, 0, 1, 0, 1, 1, 'Crumbling Plate Gloves'),
    (173568, 177738, 0, 1, 0, 1, 0, 1, 1, 'Crumbling Plate Chestpiece'),
    (173568, 177757, 0, 1, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Tunic'),
    (173568, 177759, 0, 3, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Legwraps'),
    (173568, 177793, 0, 1, 0, 1, 0, 1, 1, 'Night Guardian Pauldrons'),
    (173568, 177794, 0, 1, 0, 1, 0, 1, 1, 'Night Guardian Cincture'),
    (173568, 177799, 0, 1, 0, 1, 0, 1, 1, 'Stoneborn Shield'),
    (173568, 177801, 0, 1, 0, 1, 0, 1, 1, 'Sky Legion Halbard'),
    (173568, 178061, 0, 4, 0, 1, 0, 1, 3, 'Malleable Flesh'),
    (173568, 178128, 0, 6, 0, 1, 0, 1, 1, 'Pouch of Shinies'),
    (173568, 179311, 0, 2, 0, 1, 0, 1, 1, 'Barkweave Wristwraps'),
    (173568, 179319, 0, 1, 0, 1, 0, 1, 1, 'Caged Cudgel'),
    (173568, 179332, 0, 1, 0, 1, 0, 1, 1, 'Stone Sentinel Poleaxe');

-- ---------------------------------------------------------------------------
-- Sinister Antiquarian (173604)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173604, 173202, 0, 66.6667, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (173604, 173204, 0, 13.3333, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173604, 177761, 0, 3.33333, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Hood'),
    (173604, 177777, 0, 3.33333, 0, 1, 0, 1, 1, 'Depraved Darkblade''s Breeches'),
    (173604, 177789, 0, 3.33333, 0, 1, 0, 1, 1, 'Night Guardian Breastplate'),
    (173604, 178061, 0, 10, 0, 1, 0, 1, 3, 'Malleable Flesh'),
    (173604, 179319, 0, 3.33333, 0, 1, 0, 1, 1, 'Caged Cudgel'),
    (173604, 179333, 0, 6.66667, 0, 1, 0, 1, 1, 'Inquisitor Cudgel');

-- ---------------------------------------------------------------------------
-- Nathrian Registrar (173613)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173613, 173202, 0, 85.7143, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173613, 173204, 0, 14.2857, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (173613, 177801, 0, 14.2857, 0, 1, 0, 1, 1, 'Sky Legion Halbard'),
    (173613, 179329, 0, 14.2857, 0, 1, 0, 1, 1, 'Gargoyle Heartpiercer');

-- ---------------------------------------------------------------------------
-- Nathrian Archivist (173633)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173633, 173202, 0, 67.3913, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (173633, 173204, 0, 28.2609, 0, 1, 0, 1, 2, 'Lightless Silk'),
    (173633, 177746, 0, 4.34783, 0, 1, 0, 1, 1, 'Dredged Chain Helm'),
    (173633, 177753, 0, 2.17391, 0, 1, 0, 1, 1, 'Mire-Stained Leather Shoulderpads'),
    (173633, 177758, 0, 2.17391, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Slippers'),
    (173633, 177792, 0, 2.17391, 0, 1, 0, 1, 1, 'Night Guardian Legguards'),
    (173633, 177800, 0, 2.17391, 0, 1, 0, 1, 1, 'Bubbling Concoction'),
    (173633, 177805, 0, 2.17391, 0, 1, 0, 1, 1, 'Redeemer''s Mace'),
    (173633, 179332, 0, 2.17391, 0, 1, 0, 1, 1, 'Stone Sentinel Poleaxe');

-- ---------------------------------------------------------------------------
-- Rat of Unusual Size (173798)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173798, 176852, 0, 20.5882, 0, 1, 0, 1, 1, 'Hardened Tail Bone'),
    (173798, 176860, 0, 11.7647, 0, 1, 0, 1, 1, 'Keen Incisor'),
    (173798, 176862, 0, 67.6471, 0, 1, 0, 1, 1, 'Marred Skin'),
    (173798, 177795, 0, 3, 0, 1, 0, 1, 1, 'Night Guardian Armplates'),
    (173798, 179323, 0, 3, 0, 1, 0, 1, 1, 'Dredhollow Cudgel');

-- ---------------------------------------------------------------------------
-- Sewer Rat (173800)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173800, 176852, 0, 22.1854, 0, 1, 0, 1, 1, 'Hardened Tail Bone'),
    (173800, 176860, 0, 5.29801, 0, 1, 0, 1, 1, 'Keen Incisor'),
    (173800, 176862, 0, 72.5166, 0, 1, 0, 1, 1, 'Marred Skin'),
    (173800, 177805, 0, 0.331126, 0, 1, 0, 1, 1, 'Redeemer''s Mace'),
    (173800, 179329, 0, 0.331126, 0, 1, 0, 1, 1, 'Gargoyle Heartpiercer'),
    (173800, 183971, 0, 0.331126, 0, 1, 0, 1, 1, 'Depraved Ritualist''s Kris');

-- ---------------------------------------------------------------------------
-- Carved Assistant (173802)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (173802, 173202, 0, 9, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (173802, 173204, 0, 1, 0, 1, 0, 2, 2, 'Lightless Silk'),
    (173802, 177769, 0, 1, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Handwraps'),
    (173802, 177771, 0, 1, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Leggings'),
    (173802, 177799, 0, 1, 0, 1, 0, 1, 1, 'Stoneborn Shield'),
    (173802, 178113, 0, 74, 0, 1, 0, 1, 1, 'Twitching Stone'),
    (173802, 178132, 0, 21, 0, 1, 0, 1, 1, 'Richly Calligraphed Invitation'),
    (173802, 180310, 0, 4, 0, 1, 0, 1, 1, 'Fluttering Stone Wings');

-- ---------------------------------------------------------------------------
-- Executrix Ophelia (174012)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174012, 173202, 0, 45.4545, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (174012, 173204, 0, 9, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (174012, 177744, 0, 9, 0, 1, 0, 1, 1, 'Dredged Chain Vest'),
    (174012, 177758, 0, 9, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Slippers'),
    (174012, 177771, 0, 9, 0, 1, 0, 1, 1, 'Avowed Tormenter''s Leggings'),
    (174012, 177785, 0, 9, 0, 1, 0, 1, 1, 'Savage Bonemauler Shoulderguards'),
    (174012, 177799, 0, 18.1818, 0, 1, 0, 1, 1, 'Stoneborn Shield');

-- ---------------------------------------------------------------------------
-- Kennel Overseer (174070)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174070, 173202, 0, 76.1905, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (174070, 173204, 0, 4.76191, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (174070, 173705, 0, 4.76191, 1, 1, 0, 1, 1, 'The Venthyr Diaries'),
    (174070, 177745, 0, 4.76191, 0, 1, 0, 1, 1, 'Dredged Chain Gauntlets'),
    (174070, 177763, 0, 4.76191, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Mantle'),
    (174070, 178061, 0, 4.76191, 0, 1, 0, 1, 1, 'Malleable Flesh'),
    (174070, 179311, 0, 9.52381, 0, 1, 0, 1, 1, 'Barkweave Wristwraps');

-- ---------------------------------------------------------------------------
-- Nathrian Hierarch (174090)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174090, 173202, 0, 73.6842, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (174090, 173204, 0, 26.3158, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (174090, 177743, 0, 5.26316, 0, 1, 0, 1, 1, 'Dredged Chain Breeches');

-- ---------------------------------------------------------------------------
-- Nathrian Gargon Rider (174092)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174092, 173202, 0, 76.6234, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (174092, 173204, 0, 16.8831, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (174092, 177734, 0, 1.2987, 0, 1, 0, 1, 1, 'Crumbling Plate Shoulderguards'),
    (174092, 177757, 0, 1.2987, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Tunic'),
    (174092, 177758, 0, 1.2987, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Slippers'),
    (174092, 177761, 0, 1.2987, 0, 1, 0, 1, 1, 'Ember-Bleached Cloth Hood'),
    (174092, 177783, 0, 1.2987, 0, 1, 0, 1, 1, 'Savage Bonemauler Helm'),
    (174092, 177802, 0, 1.2987, 0, 1, 0, 1, 1, 'Hopebreaker Carbine'),
    (174092, 178061, 0, 2.5974, 0, 1, 0, 1, 1, 'Malleable Flesh'),
    (174092, 179311, 0, 1.2987, 0, 1, 0, 1, 1, 'Barkweave Wristwraps'),
    (174092, 179323, 0, 1.2987, 0, 1, 0, 1, 1, 'Dredhollow Cudgel'),
    (174092, 182978, 0, 1.2987, 0, 1, 0, 1, 1, 'Barkweave Wristwraps');

-- ---------------------------------------------------------------------------
-- Lord Evershade (174134)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174134, 173202, 0, 100, 0, 1, 0, 1, 2, 'Shrouded Cloth'),
    (174134, 184778, 0, 66.6667, 0, 1, 0, 1, 1, 'Decadent Nathrian Shawl');

-- ---------------------------------------------------------------------------
-- Countess Gloomveil (174162)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174162, 173202, 0, 75, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (174162, 173204, 0, 12.5, 0, 1, 0, 1, 1, 'Lightless Silk'),
    (174162, 183971, 0, 12.5, 0, 1, 0, 1, 1, 'Depraved Ritualist''s Kris');

-- ---------------------------------------------------------------------------
-- Kennel Overseer (174336 -- second, distinct entry from 174070)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174336, 173202, 0, 75, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (174336, 173204, 0, 17.8571, 0, 1, 0, 1, 2, 'Lightless Silk'),
    (174336, 177811, 0, 3.57143, 0, 1, 0, 1, 1, 'Depraved Tutor''s Signet'),
    (174336, 178061, 0, 3.57143, 0, 1, 0, 1, 1, 'Malleable Flesh');

-- ---------------------------------------------------------------------------
-- Belligerent Waiter (174842 -- one of three same-name entries; only this one had source loot)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174842, 173202, 0, 81, 0, 1, 0, 1, 3, 'Shrouded Cloth'),
    (174842, 173204, 0, 16.2162, 0, 1, 0, 1, 2, 'Lightless Silk'),
    (174842, 173715, 0, 1.35135, 1, 1, 0, 1, 1, 'Dredger''s Toolkit'),
    (174842, 177810, 0, 1.35135, 0, 1, 0, 1, 1, 'Stonebreaker Mace'),
    (174842, 178128, 0, 1.35135, 0, 1, 0, 1, 1, 'Pouch of Shinies'),
    (174842, 180834, 0, 1.35135, 0, 1, 0, 1, 1, 'Renathal''s Journal Pages'),
    (174842, 183010, 0, 1.35135, 0, 1, 0, 1, 1, 'Stud-Scarred Footwear');

-- ---------------------------------------------------------------------------
-- Stoneborn Maitre D' (174843)
-- ---------------------------------------------------------------------------
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (174843, 173202, 0, 25, 0, 1, 0, 2, 2, 'Shrouded Cloth'),
    (174843, 178113, 0, 75, 0, 1, 0, 1, 1, 'Twitching Stone');
