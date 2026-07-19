-- Castle Nathria (map 2296) -- boss loot: creature_loot_template + gameobject_loot_template.
-- Transcoded from Shadowlands-era source dumps, filtered against the 72-item downported-gear
-- allowlist (the actual item_template stat rows for these 72 ids are populated in 03_loot_item_stats.sql).
-- Of Castle Nathria's 298-id retail loot pool, 226 are Shadowlands-only "borrowed power" items
-- (Soulbind Conduits / Runecarver Memories / Anima reagents) with NO 3.3.5 equivalent and were
-- deliberately never downported -- ONLY the 72 real gear ids may appear as an `Item` value below.
--
-- Sources checked:
--   1) SLDB_902_world_2021_03_12.sql (543MB base dump) -- creature_loot_template rows found for
--      Sludgefist, Artificer Xy'mox, Council of Blood (Baroness Frieda + Castellan Niklaus),
--      Stone Legion Generals (General Kaal), Sire Denathrius.
--   2) world09.sql ([9.2.7] Rem999 repack, independent dump) -- adds Shriekwing (missing from #1).
--   3) 2021_03_15_00_world_shriekwing.sql / 2021_03_16_08_world_altimor.sql /
--      2021_03_18_00_world_darkvein.sql (boss-specific shadowcore patches) -- none contain any
--      creature_loot_template / gameobject_loot_template rows (confirmed by direct grep).
--   4) 2021_03_18_02_world_cre_gob_data.sql -- no loot tables at all in this file (creature/GO
--      template + spawn data only; handled by the companion spawn-import pass).
--
-- Result: 4 of the 10 encounters have ZERO creature_loot_template rows in ANY of the 4 sources above:
-- Huntsman Altimor (165066), Hungering Destroyer (164261), Lady Inerva Darkvein (165521), and Sun
-- King's Salvation (165759). This is a genuine source-data gap, not an oversight on this pass -- no
-- gear rows are written for these 3 entries; their reward is whatever mingold/maxgold the companion
-- creature_template pass assigns them. Do not add fake Item ids here to compensate.
--
-- GroupId convention (mirrors BlackwingDescent's 09_loot.sql per-boss grouping): each boss's surviving
-- allowlisted items share one GroupId (=1) with Chance values summing to ~100, so a kill guarantees
-- exactly one of that boss's pieces rather than an independent (and, post-filtering, very sparse)
-- per-item roll. Council of Blood and Stone Legion Generals are multi-body encounters; source only
-- carried loot rows on a subset of the co-boss entries (Baroness Frieda + Castellan Niklaus for
-- Council of Blood; General Kaal only for Stone Legion Generals) -- Lord Stavros (166970) and General
-- Grashaal (168113) get no rows here, matching source and the single-creditEntry convention already
-- used in 11_instance_encounters.sql.
--
-- Apply against acore_world.

-- ---------------------------------------------------------------------------
-- Shriekwing (164406) -- source: world09.sql (missing from the SLDB_902 base dump)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 164406;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (164406, 182976, 0, 17, 0, 1, 1, 1, 1, 'Double-Chained Utility Belt'),
    (164406, 182979, 0, 17, 0, 1, 1, 1, 1, 'Slippers of the Forgotten Heretic'),
    (164406, 182993, 0, 17, 0, 1, 1, 1, 1, 'Chiropteran Leggings'),
    (164406, 183027, 0, 17, 0, 1, 1, 1, 1, 'Errant Crusader''s Greaves'),
    (164406, 183034, 0, 16, 0, 1, 1, 1, 1, 'Cowled Batwing Cloak'),
    (164406, 184016, 0, 16, 0, 1, 1, 1, 1, 'Skulker''s Wing');

-- ---------------------------------------------------------------------------
-- Huntsman Altimor (165066) -- NO creature_loot_template rows in any of the 4 sources checked
-- (base dump, world09 repack, or the dedicated 2021_03_16_08_world_altimor.sql patch). Gold-only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Hungering Destroyer (164261) -- NO creature_loot_template rows in any of the 4 sources checked.
-- Gold-only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Sun King's Salvation (165759) -- NO creature_loot_template rows in any of the 4 sources checked.
-- Gold-only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Artificer Xy'mox (166644) -- source: SLDB_902_world_2021_03_12.sql
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 166644;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (166644, 182987, 0, 17, 0, 1, 1, 1, 1, 'Breastplate of Cautious Calculation'),
    (166644, 183004, 0, 17, 0, 1, 1, 1, 1, 'Shadewarped Sash'),
    (166644, 183012, 0, 17, 0, 1, 1, 1, 1, 'Greaves of Enigmatic Energies'),
    (166644, 183019, 0, 17, 0, 1, 1, 1, 1, 'Precisely Calibrated Chronometer'),
    (166644, 183038, 0, 16, 0, 1, 1, 1, 1, 'Hyperlight Band'),
    (166644, 184021, 0, 16, 0, 1, 1, 1, 1, 'Glyph of Assimilation');

-- ---------------------------------------------------------------------------
-- Lady Inerva Darkvein (165521) -- NO creature_loot_template rows in any of the 4 sources checked
-- (base dump, world09 repack, or the dedicated 2021_03_18_00_world_darkvein.sql patch). Gold-only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Council of Blood -- Baroness Frieda (166969) -- source: SLDB_902_world_2021_03_12.sql
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 166969;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (166969, 182983, 0, 20, 0, 1, 1, 1, 1, 'Stoneguard Attendant''s Boots'),
    (166969, 182989, 0, 20, 0, 1, 1, 1, 1, 'Corset of the Deft Duelist'),
    (166969, 183023, 0, 20, 0, 1, 1, 1, 1, 'Sparkling Glass Slippers'),
    (166969, 183039, 0, 20, 0, 1, 1, 1, 1, 'Noble''s Birthstone Pendant'),
    (166969, 184024, 0, 20, 0, 1, 1, 1, 1, 'Macabre Sheet Music');

-- ---------------------------------------------------------------------------
-- Council of Blood -- Castellan Niklaus (166971) -- source: SLDB_902_world_2021_03_12.sql
-- (superset of Frieda's items + 3 more; both entries carried rows in source, so both are kept)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 166971;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (166971, 182983, 0, 13, 0, 1, 1, 1, 1, 'Stoneguard Attendant''s Boots'),
    (166971, 182989, 0, 13, 0, 1, 1, 1, 1, 'Corset of the Deft Duelist'),
    (166971, 183011, 0, 13, 0, 1, 1, 1, 1, 'Courtier''s Costume Trousers'),
    (166971, 183014, 0, 13, 0, 1, 1, 1, 1, 'Castellan''s Chainlink Grips'),
    (166971, 183023, 0, 12, 0, 1, 1, 1, 1, 'Sparkling Glass Slippers'),
    (166971, 183030, 0, 12, 0, 1, 1, 1, 1, 'Enchanted Toe-Tappers'),
    (166971, 183039, 0, 12, 0, 1, 1, 1, 1, 'Noble''s Birthstone Pendant'),
    (166971, 184024, 0, 12, 0, 1, 1, 1, 1, 'Macabre Sheet Music');

-- ---------------------------------------------------------------------------
-- Council of Blood -- Lord Stavros (166970) -- NO creature_loot_template rows in source
-- (only Frieda + Niklaus carried loot for this encounter). Gold-only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Sludgefist (164407) -- source: SLDB_902_world_2021_03_12.sql
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 164407;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (164407, 182981, 0, 15, 0, 1, 1, 1, 1, 'Leggings of Lethal Reverberations'),
    (164407, 182984, 0, 15, 0, 1, 1, 1, 1, 'Colossal Plate Gauntlets'),
    (164407, 182999, 0, 14, 0, 1, 1, 1, 1, 'Rampaging Giant''s Chestplate'),
    (164407, 183005, 0, 14, 0, 1, 1, 1, 1, 'Heedless Pugilist''s Harness'),
    (164407, 183006, 0, 14, 0, 1, 1, 1, 1, 'Stoneclas Stompers'),
    (164407, 183022, 0, 14, 0, 1, 1, 1, 1, 'Impossibly Oversized Mitts'),
    (164407, 184026, 0, 14, 0, 1, 1, 1, 1, 'Hateful Chain');

-- ---------------------------------------------------------------------------
-- Stone Legion Generals -- General Kaal (168112) -- source: SLDB_902_world_2021_03_12.sql
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 168112;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (168112, 182991, 0, 34, 0, 1, 1, 1, 1, 'Oathsworn Soldier''s Gauntlets'),
    (168112, 183032, 0, 33, 0, 1, 1, 1, 1, 'Crest of the Legionnaire General'),
    (168112, 184027, 0, 33, 0, 1, 1, 1, 1, 'Stone Legion Heraldry');

-- ---------------------------------------------------------------------------
-- Stone Legion Generals -- General Grashaal (168113) -- NO creature_loot_template rows in source
-- (only General Kaal carried loot for this encounter). Gold-only.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Sire Denathrius (167406) -- source: SLDB_902_world_2021_03_12.sql
-- (only 3 of the 72 allowlisted items map to this entry in source; the bulk of Denathrius's retail
-- pool is either "borrowed power" (excluded) or outside the 298-id pool researched for this pass)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` = 167406;
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
    (167406, 183036, 0, 34, 0, 1, 1, 1, 1, 'Most Regal Signet of Sire Denathrius'),
    (167406, 184030, 0, 33, 0, 1, 1, 1, 1, 'Dreadfire Vessel'),
    (167406, 184031, 0, 33, 0, 1, 1, 1, 1, 'Sanguine Vintage');

-- ---------------------------------------------------------------------------
-- gameobject_loot_template -- chest GOs 357751 ('...Trophies') / 357752 ('Sun King's Cache')
--
-- Both are confirmed GAMEOBJECT_TYPE_CHEST (type=3) in gameobject_template, and both reference the
-- SAME lootId via Data0 = 1634 in every source dump checked. However entry 1634 has ZERO rows in the
-- gameobject_loot_template table of either the SLDB_902 base dump or the world09 repack (verified by
-- locating each dump's exact gameobject_loot_template line range from its own table-boundary markers
-- and confirming no `(1634,` tuple falls inside it -- every other match for "1634" in the file belongs
-- to unrelated tables that happen to reuse the same numeric id, e.g. gameobject spawns/addons/locale
-- rows, a `game_tele` row, a `creature_template` row, etc.).
--
-- No gameobject_loot_template rows are written here -- inventing chest contents from nothing would
-- violate the "don't invent fake ids" constraint. If a real lootId=1634 table turns up in a fuller
-- source dump later, this is where it goes.
-- ---------------------------------------------------------------------------
