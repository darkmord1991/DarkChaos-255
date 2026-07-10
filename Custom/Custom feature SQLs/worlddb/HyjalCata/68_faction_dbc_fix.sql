-- ---------------------------------------------------------------------------
-- faction_dbc / factiontemplate_dbc additions  (Mount Hyjal, map 750)
-- ---------------------------------------------------------------------------
-- creature_template.faction pointed at FactionTemplate ids not present in
-- this fork's factiontemplate_dbc mirror ("has non-existing faction
-- template" boot warning -- non-fatal, but the null FactionTemplateEntry*
-- breaks hostility/reputation-color/tap logic for every creature using it).
-- Those FactionTemplate rows in turn reference parent Faction ids also
-- missing from faction_dbc. Both extracted directly from the real
-- Cataclysm 4.3.4 client (K:/Cata, DBFilesClient\FactionTemplate.dbc /
-- Faction.dbc, enUS/locale-enUS.MPQ base data). Faction.dbc's 16-locale
-- name/description block was already collapsed to a single string field in
-- this client build -- mapped to Name_Lang_enUS / Description_Lang_enUS
-- only, matching this project's established single-locale convention.
-- ---------------------------------------------------------------------------

DELETE FROM `faction_dbc` WHERE `ID` IN (973,1158,74,1128,977,1204);

INSERT INTO `faction_dbc` VALUES
(973,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,5,'Monster, Predator',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(1158,113,2099199,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,1162,0,0,0,0,'Guardians of Hyjal',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,'Faced with the impending devastation of Mount Hyjal, the most powerful members of the Cenarion Circle have joined forces with their Emerald Dragonflight allies to fend off Ragnaros'' elemental hordes and the Twilight''s Hammer.',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190),
(74,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,5,'Elemental',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(1128,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,5,'Twilight''s Hammer',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(977,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,5,'Hyjal Invaders',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(1204,127,2099199,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,1162,0,0,0,0,'Avengers of Hyjal',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,'Infuriated by the destruction wrought by the Lord of Flame, the Cenarion Circle seize the initiative, fighting back against Ragnaros and driving deep into the very heart of the Firelands.',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190);

DELETE FROM `factiontemplate_dbc` WHERE `ID` IN (2200,2233,2234,2252,2253,2254,2309,2369,2371,2379);

INSERT INTO `factiontemplate_dbc` VALUES
(2200,973,65,0,0,0,974,28,0,0,973,0,0,0),
(2233,1158,33,1,0,8,1128,74,977,0,1158,0,0,0),
(2234,74,32,8,0,1,1158,0,0,0,74,1128,0,0),
(2252,1158,0,1,0,8,977,0,0,0,1158,0,0,0),
(2253,1128,32,8,0,1,1158,0,0,0,74,1128,0,0),
(2254,1128,33,8,0,1,1158,0,0,0,74,1128,0,0),
(2309,1158,4129,1,0,8,977,0,0,0,1158,0,0,0),
(2369,1158,32,1,0,8,1128,74,0,0,1158,0,0,0),
(2371,977,32,8,0,1,1158,0,0,0,1128,977,74,0),
(2379,1204,0,1,0,8,0,0,0,0,1204,1158,0,0);

