-- ---------------------------------------------------------------------------
-- faction_dbc / factiontemplate_dbc additions  (DC Plaguelands, map 751)
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

DELETE FROM `faction_dbc` WHERE `ID` IN (72,68,1106);

INSERT INTO `faction_dbc` VALUES
(72,19,2098252,946,1,0,0,0,0,0,3100,-42000,4000,0,273,6,17,0,469,1,0.25,4,7,'Stormwind',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,'One of the last bastions of human power, this Alliance capital is ruled by the prodigal king, Varian Wrynn.',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190),
(68,17,418,2098253,16,512,0,0,0,0,500,-42000,4000,3100,273,6,17,17,67,1,0.25,4,7,'Undercity',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,'Led by Sylvanas Windrunner, the Forsaken have joined a tenuous alliance with the Horde and established this capital in the vast depths under the Ruins of Lordaeron.',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190),
(1106,94,2129919,0,0,0,0,0,0,0,0,0,0,0,16,0,0,0,1097,0,0,5,5,'Argent Crusade',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,'Led by Tirion Fordring, the Argent Crusade combines the reformed Order of the Silver Hand with the Argent Dawn in one final push against the forces of the Lich King.',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190);

DELETE FROM `factiontemplate_dbc` WHERE `ID` IN (2202,2213,2363);

INSERT INTO `factiontemplate_dbc` VALUES
(2202,72,32,2,2,4,0,0,0,0,0,0,0,0),
(2213,68,32,4,4,2,0,0,0,0,0,0,0,0),
(2363,1106,4097,0,0,0,0,0,0,0,1106,0,0,0);

