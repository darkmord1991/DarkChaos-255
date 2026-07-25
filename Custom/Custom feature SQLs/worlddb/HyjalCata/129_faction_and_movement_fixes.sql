-- ---------------------------------------------------------------------------
-- 129  Hyjal round-15 -- faction template 2348 + waypoint-less patrollers
-- ---------------------------------------------------------------------------

-- --- (1) missing FactionTemplate 2348 ---------------------------------------
--     Creature (template id: 3652680) has invalid faction (faction template
--     id) #2348
-- (spammed once per spawn attempt).  3652680 "Cinderling" is a Molten Front
-- trash mob; FactionTemplate 2348 has no row in `factiontemplate_dbc`, so the
-- core falls back to faction 35 (friendly to everyone) -- the mob is
-- unattackable.  Downported from the real Cata 4.3.4 client
-- (k:/tmp/cata-dbc/FactionTemplate.dbc, 14-field record, same layout as 3.3.5):
--     ID 2348, Faction 1065, Flags 0, FactionGroup 8, FriendGroup 0,
--     EnemyGroup 1, Enemies 0/0/0/0, Friend 1065/0/0/0
-- Same downport path as 68_faction_dbc_fix.sql / 93_faction_template_2170.sql.
DELETE FROM `factiontemplate_dbc` WHERE `ID` = 2348;

INSERT INTO `factiontemplate_dbc`
(`ID`,`Faction`,`Flags`,`FactionGroup`,`FriendGroup`,`EnemyGroup`,`Enemies_1`,`Enemies_2`,`Enemies_3`,`Enemies_4`,`Friend_1`,`Friend_2`,`Friend_3`,`Friend_4`) VALUES
(2348, 1065, 0, 8, 0, 1, 0, 0, 0, 0, 1065, 0, 0, 0);

-- The client needs the same row to colour the nameplate correctly; append it to
-- Custom/CSV DBC/FactionTemplate.csv and recompile (see 00_README round-15).

-- --- (2) MovementType 2 with no waypoint path -------------------------------
--     WaypointMovementGenerator::DoInitialize: creature Druid of the Talon
--     (... Entry: 3652341 ...) doesn't have waypoint path id: 0
-- 4 map-861 spawns carry MovementType = 2 (WAYPOINT) but have no
-- `creature_addon.path_id` and no waypoint_data.  nelt_world keys its waypoint
-- paths by ITS OWN spawn guids, and MoltenFront/02_mf_spawns.sql re-guids into
-- the 15,300,000 block without preserving a nelt-guid -> DC-guid mapping, so
-- the paths could not come across with the spawns.
--
-- Rather than invent routes, drop these four to MovementType 0 (idle): they
-- stand still instead of re-initialising a null path on every grid load.  The
-- real patrol routes stay available in nelt_world if someone later reworks
-- 02_mf_spawns to carry the guid mapping.
--
-- Self-deriving over both maps so it also catches any future spawn with the
-- same defect.
UPDATE `creature` c
LEFT JOIN `creature_addon` a ON a.`guid` = c.`guid`
SET c.`MovementType` = 0
WHERE c.`map` IN (750,861)
  AND c.`MovementType` = 2
  AND COALESCE(a.`path_id`, 0) = 0;

-- Template-level equivalent: Mobus (3650009) and Magria (3654319) declare
-- MovementType 2 with no waypoint_data anywhere.  Neither has a spawn right
-- now, so this is pre-emptive.
UPDATE `creature_template` ct SET ct.`MovementType` = 0
WHERE ct.`entry` IN (3650009,3654319) AND ct.`MovementType` = 2
  AND NOT EXISTS (SELECT 1 FROM `waypoint_data` w WHERE w.`id` = ct.`entry`);
