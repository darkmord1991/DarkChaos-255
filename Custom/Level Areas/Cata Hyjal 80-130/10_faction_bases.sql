-- ---------------------------------------------------------------------------
-- 10  Faction bases: Jaina's Encampment (Alliance) + Thrall's Vanguard (Horde)
-- ---------------------------------------------------------------------------
-- Map 750 has NO Alliance or Horde presence at all -- every NPC on it is neutral
-- (Guardians of Hyjal 2252 / 2233, or 35). There are zero faction-12 and zero
-- faction-29 creatures, so neither side has a base, an innkeeper to bind at, or
-- a quartermaster of its own.
--
-- The full rosters already exist as `creature_template` rows WITH their vendor
-- stock -- they were authored for the superseded map 1410 and have simply never
-- been placed on 750. This file re-homes them; nothing is re-authored.
--
-- SITES were chosen from live spawn geometry, not guessed. Both are existing
-- flat, friendly, ground-verified settlements. Service NPCs make good anchors
-- because they are always placed on real ground -- unlike, say, the Hyjal Bear
-- Cubs, whose z is tree-height and which would have put a town in mid-air:
--   Alliance (4433, -2071, 1208.3)  z stddev 3.5 over 43 service NPCs
--                                   -- Grove of Aessina shelf, 877 yd from Nordrassil
--   Horde    (5334, -2156, 1274.6)  z stddev 8.1 over 14 service NPCs
--                                   -- the Duran / Ragehowl camp, 614 yd from Nordrassil
--   separation between the two camps: 905 yd
--
-- !! The two camp FLIGHT MASTERS (830020, 830145) are deliberately NOT spawned.
-- A flight master needs its own TaxiNodes.dbc entry to be a departure point, and
-- adding nodes is a client-DBC task. Map 750's existing mesh already covers the
-- Alliance camp -- node 422 (Ranela Featherglen, 4394/-2107) is 51 yd away -- so
-- the gap is the Horde camp only. Tracked as a follow-up rather than shipping a
-- flight master whose gossip opens an empty taxi map.
--
-- Layout: 12 service NPCs on an 18 yd ring facing the camp centre, 6 guards on a
-- 32 yd ring facing outward. These coordinates are ground-valid but not art-aware
-- -- final placement wants an in-game `.gps` pass.
--
-- GUID block 9020000-9020499 (verified empty). Idempotent.
-- ---------------------------------------------------------------------------

-- 1. Retire the map-1410 placements (that map is superseded).
DELETE FROM `creature` WHERE `id` BETWEEN 830000 AND 830999 AND `map` = 1410;

-- 2. Place both camps on map 750.
DELETE FROM `creature` WHERE `guid` BETWEEN 9020000 AND 9020499;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
    `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
    `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`,
    `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
(9020000, 830023, 750, 4923, 4923, 1, 1, 0, 4451.000, -2071.000, 1208.300, 3.142, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Innkeeper Cerelina'),
(9020001, 830024, 750, 4923, 4923, 1, 1, 0, 4448.588, -2062.000, 1208.300, 3.665, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Emberwood Sap Quartermaster'),
(9020002, 830135, 750, 4923, 4923, 1, 1, 0, 4442.000, -2055.412, 1208.300, 4.189, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Banker'),
(9020003, 830136, 750, 4923, 4923, 1, 1, 0, 4433.000, -2053.000, 1208.300, 4.712, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Auctioneer'),
(9020004, 830137, 750, 4923, 4923, 1, 1, 0, 4424.000, -2055.412, 1208.300, 5.236, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Provisioner'),
(9020005, 830138, 750, 4923, 4923, 1, 1, 0, 4417.412, -2062.000, 1208.300, 5.760, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Trader'),
(9020006, 830139, 750, 4923, 4923, 1, 1, 0, 4415.000, -2071.000, 1208.300, 0.000, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Cook'),
(9020007, 830140, 750, 4923, 4923, 1, 1, 0, 4417.412, -2080.000, 1208.300, 0.524, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Alchemist'),
(9020008, 830141, 750, 4923, 4923, 1, 1, 0, 4424.000, -2086.588, 1208.300, 1.047, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Weaponsmith'),
(9020009, 830142, 750, 4923, 4923, 1, 1, 0, 4433.000, -2089.000, 1208.300, 1.571, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Armorer'),
(9020010, 830143, 750, 4923, 4923, 1, 1, 0, 4442.000, -2086.588, 1208.300, 2.094, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Stable Master'),
(9020011, 830144, 750, 4923, 4923, 1, 1, 0, 4448.588, -2080.000, 1208.300, 2.618, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Tabard Vendor'),
(9020012, 830021, 750, 4923, 4923, 1, 1, 0, 4460.713, -2055.000, 1208.300, 0.524, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Guard'),
(9020013, 830021, 750, 4923, 4923, 1, 1, 0, 4433.000, -2039.000, 1208.300, 1.571, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Guard'),
(9020014, 830021, 750, 4923, 4923, 1, 1, 0, 4405.287, -2055.000, 1208.300, 2.618, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Encampment Guard'),
(9020015, 830161, 750, 4923, 4923, 1, 1, 0, 4405.287, -2087.000, 1208.300, 3.665, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Hyjal Frontier Soldier'),
(9020016, 830161, 750, 4923, 4923, 1, 1, 0, 4433.000, -2103.000, 1208.300, 4.712, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Hyjal Frontier Soldier'),
(9020017, 830161, 750, 4923, 4923, 1, 1, 0, 4460.713, -2087.000, 1208.300, 5.760, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Jaina''s Encampment - Hyjal Frontier Soldier'),
(9020030, 830146, 750, 4923, 4923, 1, 1, 0, 5352.000, -2156.000, 1274.600, 3.142, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Innkeeper Garruka'),
(9020031, 830147, 750, 4923, 4923, 1, 1, 0, 5349.588, -2147.000, 1274.600, 3.665, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Emberwood Sap Quartermaster'),
(9020032, 830148, 750, 4923, 4923, 1, 1, 0, 5343.000, -2140.412, 1274.600, 4.189, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Banker'),
(9020033, 830149, 750, 4923, 4923, 1, 1, 0, 5334.000, -2138.000, 1274.600, 4.712, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Auctioneer'),
(9020034, 830150, 750, 4923, 4923, 1, 1, 0, 5325.000, -2140.412, 1274.600, 5.236, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Provisioner'),
(9020035, 830151, 750, 4923, 4923, 1, 1, 0, 5318.412, -2147.000, 1274.600, 5.760, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Trader'),
(9020036, 830152, 750, 4923, 4923, 1, 1, 0, 5316.000, -2156.000, 1274.600, 0.000, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Cook'),
(9020037, 830153, 750, 4923, 4923, 1, 1, 0, 5318.412, -2165.000, 1274.600, 0.524, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Shaman Supplier'),
(9020038, 830154, 750, 4923, 4923, 1, 1, 0, 5325.000, -2171.588, 1274.600, 1.047, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Weaponsmith'),
(9020039, 830155, 750, 4923, 4923, 1, 1, 0, 5334.000, -2174.000, 1274.600, 1.571, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Armorer'),
(9020040, 830156, 750, 4923, 4923, 1, 1, 0, 5343.000, -2171.588, 1274.600, 2.094, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Stable Master'),
(9020041, 830157, 750, 4923, 4923, 1, 1, 0, 5349.588, -2165.000, 1274.600, 2.618, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Tabard Vendor'),
(9020042, 830022, 750, 4923, 4923, 1, 1, 0, 5361.713, -2140.000, 1274.600, 0.524, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Grunt'),
(9020043, 830022, 750, 4923, 4923, 1, 1, 0, 5334.000, -2124.000, 1274.600, 1.571, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Grunt'),
(9020044, 830022, 750, 4923, 4923, 1, 1, 0, 5306.287, -2140.000, 1274.600, 2.618, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Vanguard Grunt'),
(9020045, 830162, 750, 4923, 4923, 1, 1, 0, 5306.287, -2172.000, 1274.600, 3.665, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Hyjal Vanguard Warrior'),
(9020046, 830162, 750, 4923, 4923, 1, 1, 0, 5334.000, -2188.000, 1274.600, 4.712, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Hyjal Vanguard Warrior'),
(9020047, 830162, 750, 4923, 4923, 1, 1, 0, 5361.713, -2172.000, 1274.600, 5.760, 300, 0, 0, 0, 0, 0, 0, 0, 0, '', NULL, 0, 'Thrall''s Vanguard - Hyjal Vanguard Warrior');
