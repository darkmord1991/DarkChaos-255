-- =====================================================================
-- Molten Front -- 85  questsort_dbc / areatable_dbc additions
-- ---------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13): "Quest N has ZoneOrSort = -379/
-- -381 (sort case) but quest sort with this id does not exist" (10 Molten
-- Front quests) and "Quest N has ZoneOrSort = 4926 (zone case) but zone
-- with this id does not exist" (2 more Hyjal-questgiver quests, 28732/
-- 28735 -- confirmed Hyjal via questgiver 3649444, not an unrelated stock
-- gap, despite the area's real name referencing a different instance).
-- `sAreaTableStore`/`sQuestSortStore` are loaded via the same LOAD_DBC(...,
-- "X.dbc", "x_dbc") macro as vehicle_dbc/spell_dbc/faction_dbc (DBCStores.cpp)
-- -- i.e. real SQL-mirror tables the server actually reads, not an inert
-- mirror like creaturedisplayinfo_dbc. Both confirmed 0 rows server-wide
-- before this (same incrementally-populated-mirror pattern as every other
-- *_dbc table hit this session).
--
-- QuestSort 379/381 extracted directly from the real Cata client
-- (K:/Cata, enUS/locale-enUS.MPQ): 379 "Firelands Invasion", 381
-- "Elemental Bonds" (matches quest 29331 "Elemental Bonds: The Vow"
-- exactly). Single-locale convention (Name_Lang_enUS only, Mask=16712190).
--
-- AreaTable 4926 real name is "Blackrock Caverns" (Cata's own zone-tag
-- reuse for this quest, not a sign we need that instance built) --
-- registered with conservative-safe values only (ContinentID/ParentAreaID/
-- AreaBit/Flags/etc = 0) rather than porting Cata's real ContinentID (645)
-- verbatim, since we have no map 645 and don't want an unmapped continent
-- id leaking into any code that iterates AreaTable by ContinentID. This
-- purely satisfies the quest-log zone-label existence check.
-- =====================================================================

DELETE FROM `questsort_dbc` WHERE `ID` IN (379,381);
INSERT INTO `questsort_dbc` (`ID`,`SortName_Lang_enUS`,`SortName_Lang_enGB`,`SortName_Lang_koKR`,`SortName_Lang_frFR`,`SortName_Lang_deDE`,`SortName_Lang_enCN`,`SortName_Lang_zhCN`,`SortName_Lang_enTW`,`SortName_Lang_zhTW`,`SortName_Lang_esES`,`SortName_Lang_esMX`,`SortName_Lang_ruRU`,`SortName_Lang_ptPT`,`SortName_Lang_ptBR`,`SortName_Lang_itIT`,`SortName_Lang_Unk`,`SortName_Lang_Mask`) VALUES
(379,'Firelands Invasion',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190),
(381,'Elemental Bonds',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190);

DELETE FROM `areatable_dbc` WHERE `ID` = 4926;
INSERT INTO `areatable_dbc` (`ID`,`ContinentID`,`ParentAreaID`,`AreaBit`,`Flags`,`SoundProviderPref`,`SoundProviderPrefUnderwater`,`AmbienceID`,`ZoneMusic`,`IntroSound`,`ExplorationLevel`,`AreaName_Lang_enUS`,`AreaName_Lang_enGB`,`AreaName_Lang_koKR`,`AreaName_Lang_frFR`,`AreaName_Lang_deDE`,`AreaName_Lang_enCN`,`AreaName_Lang_zhCN`,`AreaName_Lang_enTW`,`AreaName_Lang_zhTW`,`AreaName_Lang_esES`,`AreaName_Lang_esMX`,`AreaName_Lang_ruRU`,`AreaName_Lang_ptPT`,`AreaName_Lang_ptBR`,`AreaName_Lang_itIT`,`AreaName_Lang_Unk`,`AreaName_Lang_Mask`,`FactionGroupMask`,`LiquidTypeID_1`,`LiquidTypeID_2`,`LiquidTypeID_3`,`LiquidTypeID_4`,`MinElevation`,`Ambient_Multiplier`,`Lightid`) VALUES
(4926,0,0,0,0,0,0,0,0,0,-1,'Blackrock Caverns',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,0,0,0,0,0,0,0,0);
