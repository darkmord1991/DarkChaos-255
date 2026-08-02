-- ---------------------------------------------------------------------------
-- 200  Map 750 -- the 14 Cataclysm faction templates the imports reference
-- ---------------------------------------------------------------------------
-- Live Errors.log after the restart is full of
--     "Creature (template id: 3734302) has invalid faction (faction template
--      id) #2154"
-- 40 imported creature entries across Darkshore and Felwood use 14 faction
-- template ids that Cataclysm added and 3.3.5 never had. Verified against the
-- LIVE server via read_server_dbc, not just the SQL overlay -- FactionTemplate
-- .dbc has 880 records and contains NONE of the 14. (Checking only
-- `factiontemplate_dbc`, which is an overlay, would have been the same mistake
-- as checking only `spell_dbc` for missing spells.)
--
-- Affected, by template:
--   2151 Darkshore Stag, Whitetail Stag          2163 Talonbranch NPCs (11 entries)
--   2152 Mottled Doe, Whitetail Doe              2164 Denmother Ulrica, Willard Harrington
--   2153 Moonstalker Matriarch / Sire            2165 Talonbranch Guardian
--   2154 Thistle Bear x3                         2159/2160/2162 Irontree goblins (12)
--   2157 Corrupted Thistle Bear x2               2171 Blackwood Furbolg
--   2158 Thistle Bear Cub, Young Grizzled        2319 Corrupted/Maddened Blackwood
--
-- SOURCE -- K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ.
--   * FactionTemplate.dbc -- Cata layout is IDENTICAL to 3.3.5 (14 fields,
--     recordSize 56), so all 14 rows copy VERBATIM.
--   * Faction.dbc -- NOT identical: Cata has 26 fields / 104 bytes, ours has
--     57 / 228, because 3.3.5 stores 16 localised name strings where Cata
--     stores one. The numeric prefix (fields 0-22: ID, ReputationIndex, the
--     race/class/base/flags quads, ParentFactionID, ParentFactionMod,
--     ParentFactionCap) is in the same order in both, which is the part that
--     matters; names are supplied by hand below.
--
-- The 14 templates reference 7 factions. 31 and 65 already exist; 1130-1134 do
-- not and are added in section A.
--
-- ---------------------------------------------------------------------------
-- ONE DELIBERATE CHANGE: ReputationIndex is forced to -1 on all five.
-- ---------------------------------------------------------------------------
-- 1130/1131/1132 (Stag, Thistle Bear, Moonstalker) are already -1 in Cata --
-- pure creature factions with no player reputation. 1133 and 1134 are NOT:
-- they are Bilgewater Cartel and Gilneas, with ReputationIndex 105 and 106.
-- Those indices address slots in the client's reputation pane that a 3.3.5
-- client does not have, and the creatures that use them here (the Irontree
-- goblins and the Talonbranch night elves) only need a valid faction so they
-- load and pick the right friends and enemies -- not a reputation bar. Both are
-- therefore imported as -1. The rest of their data (race masks, reputation
-- base values, parent faction) is kept intact, so if the reputations are ever
-- wanted the change is a one-line edit rather than a re-import.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) faction_dbc -- the 5 parent factions
-- ---------------------------------------------------------------------------
DELETE FROM `faction_dbc` WHERE `ID` IN (1130, 1131, 1132, 1133, 1134);

INSERT INTO `faction_dbc`
    (`ID`,`ReputationIndex`,
     `ReputationRaceMask_1`,`ReputationRaceMask_2`,`ReputationRaceMask_3`,`ReputationRaceMask_4`,
     `ReputationClassMask_1`,`ReputationClassMask_2`,`ReputationClassMask_3`,`ReputationClassMask_4`,
     `ReputationBase_1`,`ReputationBase_2`,`ReputationBase_3`,`ReputationBase_4`,
     `ReputationFlags_1`,`ReputationFlags_2`,`ReputationFlags_3`,`ReputationFlags_4`,
     `ParentFactionID`,`ParentFactionMod_1`,`ParentFactionMod_2`,`ParentFactionCap_1`,`ParentFactionCap_2`,
     `Name_Lang_enUS`,`Description_Lang_enUS`)
VALUES
  (1130, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0000, 1.0000, 5, 5, 'Stag', ''),
  (1131, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0000, 1.0000, 5, 5, 'Thistle Bear', ''),
  (1132, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0000, 1.0000, 5, 5, 'Moonstalker', ''),
  (1133, -1, 946, 2098253, 0, 0, 0, 0, 0, 0, 3100, -42000, 0, 0, 273, 6, 0, 0, 67, 1.0000, 0.2500, 4, 7, 'Bilgewater Cartel', ''),
  (1134, -1, 2098253, 946, 2097152, 0, 0, 0, 0, 0, 0, -42000, 3000, 0, 273, 6, 17, 0, 469, 1.0000, 0.2500, 4, 7, 'Gilneas', '');

-- ---------------------------------------------------------------------------
-- B) factiontemplate_dbc -- the 14 templates, verbatim from the Cata client
-- ---------------------------------------------------------------------------
DELETE FROM `factiontemplate_dbc` WHERE `ID` IN
    (2151, 2152, 2153, 2154, 2157, 2158, 2159, 2160, 2162, 2163, 2164, 2165, 2171, 2319);

INSERT INTO `factiontemplate_dbc`
    (`ID`,`Faction`,`Flags`,`FactionGroup`,`FriendGroup`,`EnemyGroup`,
     `Enemies_1`,`Enemies_2`,`Enemies_3`,`Enemies_4`,`Friend_1`,`Friend_2`,`Friend_3`,`Friend_4`)
VALUES
  (2151, 1130, 1, 8, 0, 1, 0, 0, 0, 0, 1130, 0, 0, 0),
  (2152, 1130, 1024, 0, 0, 0, 0, 0, 0, 0, 1130, 0, 0, 0),
  (2153, 1132, 1, 8, 0, 1, 0, 0, 0, 0, 1132, 0, 0, 0),
  (2154, 1131, 1, 8, 0, 1, 0, 0, 0, 0, 1131, 0, 0, 0),
  (2157, 1131, 65, 8, 0, 1, 28, 0, 0, 0, 1131, 0, 0, 0),
  (2158, 1131, 1024, 8, 0, 0, 28, 0, 0, 0, 1131, 0, 0, 0),
  (2159, 1133, 0, 4, 4, 2, 0, 0, 0, 0, 1133, 0, 0, 0),
  (2160, 1133, 0, 4, 4, 2, 0, 0, 0, 0, 1133, 0, 0, 0),
  (2162, 1133, 32, 4, 4, 2, 0, 0, 0, 0, 1133, 0, 0, 0),
  (2163, 1134, 0, 2, 2, 4, 0, 0, 0, 0, 1134, 0, 0, 0),
  (2164, 1134, 1, 2, 2, 4, 0, 0, 0, 0, 1134, 0, 0, 0),
  (2165, 1134, 2113, 3, 2, 12, 0, 0, 0, 0, 1134, 0, 0, 0),
  (2171, 31, 65, 0, 1, 0, 74, 0, 0, 0, 31, 0, 0, 0),
  (2319, 65, 0, 8, 0, 1, 0, 0, 0, 0, 65, 0, 0, 0);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM factiontemplate_dbc WHERE ID IN
--     (2151,2152,2153,2154,2157,2158,2159,2160,2162,2163,2164,2165,2171,2319);  -- 14
--   SELECT COUNT(*) FROM faction_dbc WHERE ID BETWEEN 1130 AND 1134;            -- 5
--
--   -- no map-750 creature references a faction template we lack (expect 0):
--   SELECT COUNT(DISTINCT t.faction) FROM creature_template t
--    WHERE t.entry BETWEEN 3600000 AND 3799999
--      AND NOT EXISTS (SELECT 1 FROM factiontemplate_dbc f WHERE f.ID = t.faction);
--   -- (this only proves the overlay side; confirm the live DBC with
--   --  read_server_dbc, or simply check Errors.log for "invalid faction")
--
-- Errors.log should gain no further "has invalid faction (faction template id)"
-- lines for the 3.6M/3.7M entry range.
-- ---------------------------------------------------------------------------
