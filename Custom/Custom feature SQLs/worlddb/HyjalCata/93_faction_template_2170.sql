-- ---------------------------------------------------------------------------
-- factiontemplate_dbc 2170 -- missing, referenced by Flamewaker Shaman (3653093)
-- ---------------------------------------------------------------------------
-- "Creature (Entry: 3653093) has non-existing faction template (2170)."
-- Self-inflicted gap from HyjalCata/84_'s cross-DB creature_template copy
-- (cata_world has no factiontemplate_dbc table -- same systemic pattern as
-- every other *_dbc gap this session). Extracted straight from the real
-- Cata 4.3.4 client's FactionTemplate.dbc (locale-enUS.MPQ, still .dbc
-- format for this table). Parent Faction 74 "Elemental" already exists in
-- this DB (stock WotLK), so only the FactionTemplate row is needed.
-- ---------------------------------------------------------------------------
DELETE FROM `factiontemplate_dbc` WHERE `ID` = 2170;

INSERT INTO `factiontemplate_dbc`
    (`ID`,`Faction`,`Flags`,`FactionGroup`,`FriendGroup`,`EnemyGroup`,`Enemies_1`,`Enemies_2`,`Enemies_3`,`Enemies_4`,`Friend_1`,`Friend_2`,`Friend_3`,`Friend_4`)
VALUES
(2170,74,33,8,0,1,31,0,0,0,74,0,0,0);
