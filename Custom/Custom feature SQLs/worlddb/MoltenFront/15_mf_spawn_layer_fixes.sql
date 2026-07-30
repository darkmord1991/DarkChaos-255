-- =====================================================================
-- Molten Front (map 861) -- 15  Spawn-layer fixes (audit round: GO base phase,
--                               addons, patrols, SmartAI + vendor/loot/quest gaps)
-- ---------------------------------------------------------------------
-- Follow-up to 13_'s base-phase backfill: that pass restored the phase-1
-- CREATURE population but left several spawn-layer siblings behind. This file
-- closes them all. Source of truth = nelt_world (Cata), clone offset = +3,600,000
-- for creature/GO entries; loot keys, quest ids and waypoint-path ids stay RAW
-- per the live map-861 convention (01_/13_).
--
-- SECTIONS
--   1. Ash Pile GO template 3808545 (clone of 208545, type-10 goober) + addon row,
--      and the 33 missing phase-1 GO spawns: 19x Cinderweb Egg Sac 3808431 +
--      14x Ash Pile 3808545. GO guid band 15,210,001+ (15,210,000-15,219,999
--      verified empty; 02_ creatures 15,300,000+, 08_ GOs 15,330,000+, 13_
--      creatures 15,340,000+). Ash Pile Data1 = 29139 (quest "Aggressive
--      Growth") kept RAW -- quests keep their retail ids live, verified present.
--      Gooober type has no loot table; Egg Sac (type-3 chest) loot key 208431
--      already live. Position-dup guard: no source phase-1 spawn sits within
--      0.5yd of a live same-entry spawn (closest pairs: 1.3yd / 1.5yd), so all
--      33 are placed; the NOT EXISTS guard still ships in case the live set moves.
--   2. creature_addon restore -- 9 rows. nelt has 14 addon rows on map 861; the
--      other 5 belong to phases 32769/12 that were never ported (no live spawn).
--      Source guid -> live guid resolved by entry(+3.6M) + exact position match.
--      !! DROPPED AURAS -- DELIBERATE, DO NOT "FIX" !!
--        * aura 87872 (on Zen'Vorka 15340109, Malfurion 15340025, Capt. Irontree
--          15340024) and aura 94223 (on Druid of the Talon 15300586, Mounted
--          Guardian 15300587) are, per the Cata 4.3.4 Spell.dbc, "Generic Quest
--          Invisibility 22" / "Generic Quest Invisibility 25" -- retail campaign-
--          stage gating that hides the NPC from every player who lacks the paired
--          invisibility-detection grant (spell_area). On DC's fully-unlocked
--          snapshot there is no such grant: porting these auras would make the
--          NPCs INVISIBLE TO EVERYONE (same defect class as the 2026-07-26 Hyjal
--          questgiver-invisibility incident). They are REMOVED from the rows
--          below (auras='') on purpose -- do not backfill them into spell_dbc.
--          (80797, the twin on the un-ported phase-32769 rows, is a third
--          Generic Quest Invisibility; irrelevant while those phases stay out.)
--      Mount 14332 on 15300587 verified present in CreatureDisplayInfo.csv.
--      nelt's distance_visibility (default 2) has no live equivalent semantic;
--      visibilityDistanceType left 0 (Normal).
--   3. Patrol restore -- 4 waypoint paths, 57 points, ported to path id =
--      live_guid*10 (AC convention; ids verified free):
--        2346490 (11 pts) -> 153000110  guid 15300011  3652341 Anren Shadowseeker
--        2359460 ( 7 pts) -> 153005530  guid 15300553  3652341
--        2507010 (32 pts) -> 153005770  guid 15300577  3652134 (incl. 60-80s stops)
--        2518610 ( 7 pts) -> 153005930  guid 15300593  3652501
--      creature.MovementType 0->2 + creature_addon.path_id for those 4 guids
--      (their addon rows are created in section 2 -- one row per guid).
--   4. AIName='SmartAI' for 3653308, 3653310, 3653479, 3653093 -- each has 3
--      smart_scripts rows that never loaded because AIName was ''.
--   5. Timed action list 5283400 (7 rows) for Wounded Hyjal Defender 3652834 --
--      its live spell-hit handler already calls list 5283400 (raw id, free).
--      Param sweep applied: killcredit (33) param1 52834 -> 3652834. No spell
--      casts in the list. WP_START (53) references SmartAI `waypoints` path
--      52834 (raw) which was missing live -- ported here (1 point).
--      Talk group 0 for 3652834 verified live (6 texts, ported by 13_).
--   6. Zen'Vorka's shop (3652822): the 4 npc_vendor lines get ExtendedCost
--      14103 (50 Emberwood Sap -- 12_'s premium tier, verified) and items
--      70105-70108 are stat-filled from Cata ItemSparse (same shape + -1
--      sentinel guards as 12_), incl. SellPrice/BuyPrice.
--   7. Flamewaker Shaman 3653093 loot merge: 8 items present only in the raw
--      Cata table 53093 merged into the kept offset table 3653093 (332 rows).
--      NOTE: no live creature_template has lootid=53093 anymore -- the raw
--      53093 table (53 rows) is now redundant but deliberately retained.
--   8. Quest relation one-liners: questender (3652825,29209), (3652135,29201);
--      queststarter (3652135,29214). Quests + spawned clones verified live.
--
-- CAVEAT: sections 2/3 pin guids from 02_ (15300xxx) and 13_ (15340xxx). 13_
-- re-derives its band deterministically (ROW_NUMBER over source guid), so
-- re-applying 13_ keeps these guids stable -- but if 13_'s selection logic is
-- ever edited, re-verify 15340024/25/109 before re-running this file.
--
-- Idempotent (DELETE-before-INSERT everywhere, value-guarded UPDATEs).
-- Needs a worldserver restart. Run on acore_world AFTER 13_.
-- =====================================================================
SET @OFF := 3600000;

-- ======================================================================
-- 1. ASH PILE TEMPLATE + PHASE-1 GO SPAWNS
-- ======================================================================
-- Template 3808545 "Ash Pile" (type 10 goober; Data0=43 lock, Data1=29139 quest,
-- Data3=3000 autoclose, Data5=1 consumable, Data6=5 cooldown, Data23=1).
-- Data fields kept RAW per 01_'s GO convention.
DELETE FROM acore_world.gameobject_template WHERE `entry` = 3808545;

INSERT INTO acore_world.gameobject_template
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, `type`, displayId, name, IconName, castBarCaption, unk1, size, data0, data1, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, '', '', 0
FROM nelt_world.gameobject_template
WHERE entry = 208545;

-- nelt keeps faction/flags inline on the template -> live gameobject_template_addon
-- (same split 01_ performed for every other MF GO clone).
DELETE FROM acore_world.gameobject_template_addon WHERE `entry` = 3808545;

INSERT INTO acore_world.gameobject_template_addon (`entry`,`faction`,`flags`,`mingold`,`maxgold`,`artkit0`,`artkit1`,`artkit2`,`artkit3`)
SELECT entry+@OFF, faction, flags, 0, 0, 0, 0, 0, 0
FROM nelt_world.gameobject_template
WHERE entry = 208545;

-- 33 phase-1 spawns (19x 208431 -> 3808431, 14x 208545 -> 3808545), rotations
-- verbatim, spawntimesecs floored at 120, forced zone/area 4925 / phase 1.
-- The NOT EXISTS skips any source spawn within 0.5yd of a live same-entry spawn
-- outside our own band (none matched at authoring time -- all 33 insert).
DELETE FROM acore_world.gameobject WHERE `guid` BETWEEN 15210000 AND 15219999;

INSERT INTO acore_world.gameobject
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15210000 + ROW_NUMBER() OVER (ORDER BY g.id, g.guid), g.id+@OFF, 861, 4925, 4925, 1, 1,
       g.position_x, g.position_y, g.position_z, g.orientation,
       g.rotation0, g.rotation1, g.rotation2, g.rotation3,
       GREATEST(g.spawntimesecs,120), g.animprogress, g.state, '', 0, 'MoltenFront-15-BasePhaseGO'
FROM nelt_world.gameobject g
WHERE g.map = 861 AND g.phaseMask = 1 AND g.id IN (208431,208545)
  AND NOT EXISTS (SELECT 1 FROM acore_world.gameobject a
                  WHERE a.map = 861 AND a.id = g.id + @OFF
                    AND a.guid NOT BETWEEN 15210000 AND 15219999
                    AND ABS(a.position_x - g.position_x) < 0.5
                    AND ABS(a.position_y - g.position_y) < 0.5
                    AND ABS(a.position_z - g.position_z) < 0.5);

-- ======================================================================
-- 2. CREATURE_ADDON RESTORE (9 rows; auras 87872/94223 dropped -- see header)
-- ======================================================================
-- Source guid -> live guid (entry+3.6M, exact position match):
--   234649 -> 15300011 | 235946 -> 15300553 | 250701 -> 15300577
--   251861 -> 15300593 | 252526 -> 15340109 | 250702 -> 15340025
--   246545 -> 15340024 | 251822 -> 15300586 | 251823 -> 15300587
DELETE FROM acore_world.creature_addon WHERE `guid` IN
(15300011,15300553,15300577,15300593,15340109,15340025,15340024,15300586,15300587);

-- Joined against creature so a row is only written while the guid still holds
-- the expected clone (protects against a future re-band of 02_/13_).
INSERT INTO acore_world.creature_addon (`guid`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`)
SELECT v.guid, v.path_id, v.mount, v.bytes1, v.bytes2, v.emote, 0, v.auras
FROM (
  SELECT 15300011 AS guid, 3652341 AS id, 153000110 AS path_id, 0 AS mount,     0 AS bytes1, 0 AS bytes2, 0 AS emote, '' AS auras UNION ALL  -- patrol (src 234649)
  SELECT 15300553, 3652341, 153005530, 0,     0,     0, 0, '' UNION ALL  -- patrol (src 235946)
  SELECT 15300577, 3652134, 153005770, 0,     0,     0, 0, '' UNION ALL  -- patrol (src 250701)
  SELECT 15300593, 3652501, 153005930, 0,     0,     0, 0, '' UNION ALL  -- patrol (src 251861)
  SELECT 15340109, 3652822, 0,         0,     8,     0, 0, '' UNION ALL  -- Zen'Vorka kneel; aura 87872 DROPPED (src 252526)
  SELECT 15340025, 3652135, 0,         0,     0,     1, 0, '' UNION ALL  -- Malfurion; aura 87872 DROPPED (src 250702)
  SELECT 15340024, 3653080, 0,         0,     0,     1, 0, '' UNION ALL  -- Capt. Irontree; aura 87872 DROPPED (src 246545)
  SELECT 15300586, 3652477, 0,         0,     0,     0, 0, '' UNION ALL  -- Druid of the Talon; aura 94223 DROPPED (src 251822)
  SELECT 15300587, 3652478, 0,     14332, 65536,     1, 0, ''            -- mounted guardian; aura 94223 DROPPED (src 251823)
) v
JOIN acore_world.creature c ON c.guid = v.guid AND c.id = v.id;

-- ======================================================================
-- 3. PATROL PATHS (57 waypoint_data rows) + MovementType
-- ======================================================================
DELETE FROM acore_world.waypoint_data WHERE `id` IN (153000110,153005530,153005770,153005930);

-- Point order, positions and delays verbatim from nelt (source orientation is 0
-- for every point -> NULL live); move_flag maps onto move_type.
INSERT INTO acore_world.waypoint_data (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT CASE w.id
         WHEN 2346490 THEN 153000110
         WHEN 2359460 THEN 153005530
         WHEN 2507010 THEN 153005770
         WHEN 2518610 THEN 153005930
       END,
       w.point, w.position_x, w.position_y, w.position_z, NULL,
       w.delay, w.move_flag, w.action, w.action_chance, 0
FROM nelt_world.waypoint_data w
WHERE w.id IN (2346490,2359460,2507010,2518610);

-- Waypoint movement back on (source had MovementType=2; import flattened it to 0).
UPDATE acore_world.creature
SET `MovementType` = 2
WHERE `guid` IN (15300011,15300553,15300577,15300593)
  AND `id` IN (3652341,3652134,3652501)
  AND `map` = 861;

-- ======================================================================
-- 4. AINAME FIX -- 4 combat NPCs whose SmartAI never loaded
-- ======================================================================
UPDATE acore_world.creature_template ct
SET ct.`AIName` = 'SmartAI'
WHERE ct.`entry` IN (3653308,3653310,3653479,3653093)
  AND ct.`AIName` = ''
  AND EXISTS (SELECT 1 FROM acore_world.smart_scripts ss
              WHERE ss.entryorguid = ct.entry AND ss.source_type = 0);

-- ======================================================================
-- 5. TIMED ACTION LIST 5283400 -- Wounded Hyjal Defender rescue
-- ======================================================================
-- Live caller already exists: 3652834 spell-hit -> CALL_TIMED_ACTIONLIST 5283400
-- (raw list id, verified free -- no stock/DC collision). Param sweep: killcredit
-- param1 52834 -> 3652834 (clone live). No cast actions to verify. Talk group 0
-- exists for 3652834. WP_START path stays RAW 52834 -> ported just below.
DELETE FROM acore_world.smart_scripts WHERE `entryorguid` = 5283400 AND `source_type` = 9;

INSERT INTO acore_world.smart_scripts
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
(5283400,9,0,0,0,0,100,0,0,0,0,0,28,0,0,0,0,0,0,1,0,0,0,0,0,0,'Wounded Hyjal Defender - list - remove all auras'),
(5283400,9,1,0,0,0,100,0,0,0,0,0,91,7,0,0,0,0,0,1,0,0,0,0,0,0,'Wounded Hyjal Defender - list - clear bytes1 (stand up)'),
(5283400,9,2,0,0,0,100,0,0,0,0,0,33,3652834,0,0,0,0,0,7,0,0,0,0,0,0,'Wounded Hyjal Defender - list - kill credit 3652834 to invoker (was raw 52834)'),
(5283400,9,3,0,0,0,100,0,1000,1000,0,0,66,0,0,0,0,0,0,7,0,0,0,0,0,0,'Wounded Hyjal Defender - list - face invoker'),
(5283400,9,4,0,0,0,100,0,1000,1000,0,0,1,0,0,0,0,0,0,7,0,0,0,0,0,0,'Wounded Hyjal Defender - list - say text 0'),
(5283400,9,5,0,0,0,100,0,4000,5000,0,0,53,1,52834,0,0,0,0,1,0,0,0,0,0,0,'Wounded Hyjal Defender - list - WP start path 52834 (raw waypoints id)'),
(5283400,9,6,0,0,0,100,0,0,0,0,0,41,4000,0,0,0,0,0,1,0,0,0,0,0,0,'Wounded Hyjal Defender - list - despawn in 4s');

-- The SmartAI walk-off path referenced by action 53 above (missing live).
DELETE FROM acore_world.waypoints WHERE `entry` = 52834;

INSERT INTO acore_world.waypoints (`entry`,`pointid`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`point_comment`)
SELECT entry, pointid, position_x, position_y, position_z, NULL, 0, 'Wounded Hyjal Defender - rescued walk-off (MF 15_)'
FROM nelt_world.waypoints
WHERE entry = 52834;

-- ======================================================================
-- 6. ZEN'VORKA'S SHOP (3652822) -- pricing + stat-fill 70105-70108
-- ======================================================================
-- (a) The 4 lines were free (ExtendedCost=0) with slot 0: re-list at 14103
--     (50 Emberwood Sap -- the same premium tier 12_ uses for its best pieces),
--     guarded exactly like 12_ on item/vendor/cost existing.
DELETE FROM acore_world.npc_vendor WHERE `entry` = 3652822 AND `item` IN (70105,70106,70107,70108);

INSERT INTO acore_world.npc_vendor (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
SELECT v.entry, v.slot, v.item, 0, 0, v.cost, 0
FROM (
  SELECT 3652822 AS entry, 1 AS slot, 70105 AS item, 14103 AS cost UNION ALL  -- Matoclaw's Band
  SELECT 3652822, 2, 70106, 14103 UNION ALL  -- Nightweaver's Amulet
  SELECT 3652822, 3, 70107, 14103 UNION ALL  -- Fireheart Necklace
  SELECT 3652822, 4, 70108, 14103            -- Pyrelord Greaves
) v
WHERE EXISTS (SELECT 1 FROM acore_world.item_template        i WHERE i.entry = v.item)
  AND EXISTS (SELECT 1 FROM acore_world.creature_template    c WHERE c.entry = v.entry)
  AND EXISTS (SELECT 1 FROM acore_world.itemextendedcost_dbc e WHERE e.ID    = v.cost);

-- (b) Stat-fill from Cata ItemSparse -- same UPDATE shape and -1 sentinel guards
--     as 12_ section 1, plus SellPrice/BuyPrice (source: 253627/1014508 for the
--     jewellery, 450499/1801998 for the greaves). Guarded to still-empty shells.
--     `armor`/`dmg_min1` stay 0 as in 12_/99_ (Phase-2 offline generator scope).
UPDATE acore_world.item_template it
JOIN nelt_world.`db_item-sparse_15595` s ON s.ID = it.entry
SET
  it.stat_type1=IF(s.Stat_Type1<0,0,s.Stat_Type1),    it.stat_value1=IF(s.Stat_Type1<0,0,s.Stat_Value1),
  it.stat_type2=IF(s.Stat_Type2<0,0,s.Stat_Type2),    it.stat_value2=IF(s.Stat_Type2<0,0,s.Stat_Value2),
  it.stat_type3=IF(s.Stat_Type3<0,0,s.Stat_Type3),    it.stat_value3=IF(s.Stat_Type3<0,0,s.Stat_Value3),
  it.stat_type4=IF(s.Stat_Type4<0,0,s.Stat_Type4),    it.stat_value4=IF(s.Stat_Type4<0,0,s.Stat_Value4),
  it.stat_type5=IF(s.Stat_Type5<0,0,s.Stat_Type5),    it.stat_value5=IF(s.Stat_Type5<0,0,s.Stat_Value5),
  it.stat_type6=IF(s.Stat_Type6<0,0,s.Stat_Type6),    it.stat_value6=IF(s.Stat_Type6<0,0,s.Stat_Value6),
  it.stat_type7=IF(s.Stat_Type7<0,0,s.Stat_Type7),    it.stat_value7=IF(s.Stat_Type7<0,0,s.Stat_Value7),
  it.stat_type8=IF(s.Stat_Type8<0,0,s.Stat_Type8),    it.stat_value8=IF(s.Stat_Type8<0,0,s.Stat_Value8),
  it.stat_type9=IF(s.Stat_Type9<0,0,s.Stat_Type9),    it.stat_value9=IF(s.Stat_Type9<0,0,s.Stat_Value9),
  it.stat_type10=IF(s.Stat_Type10<0,0,s.Stat_Type10), it.stat_value10=IF(s.Stat_Type10<0,0,s.Stat_Value10),
  it.ItemLevel=s.Itemlevel,
  it.Quality=s.Quality,
  it.RequiredLevel=s.Requiredlevel,
  it.delay=s.Delay,
  it.SellPrice=s.SellPrice,
  it.BuyPrice=s.BuyPrice
WHERE it.entry IN (70105,70106,70107,70108)
  AND it.stat_value1=0 AND it.stat_value2=0 AND it.stat_value3=0
  AND it.armor=0 AND it.dmg_min1=0;

-- ======================================================================
-- 7. FLAMEWAKER SHAMAN 3653093 -- loot merge (offset table kept)
-- ======================================================================
-- 3653093 keeps lootid=3653093 (332-row table). The raw Cata table 53093 holds
-- 8 items the offset table lacks (all verified in item_template):
--   58269, 63292, 63300, 63311, 63323, 63341, 63349, 67059
-- Merged below with their source chances/groups. The raw 53093 table (53 rows)
-- has NO remaining live creature_template.lootid user -- redundant but retained
-- on purpose (raw-key convention elsewhere on this map).
DELETE FROM acore_world.creature_loot_template
WHERE `Entry` = 3653093 AND `Item` IN (58269,63292,63300,63311,63323,63341,63349,67059);

INSERT INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 3653093, lt.Item, lt.Reference, lt.Chance, lt.QuestRequired, lt.LootMode, lt.GroupId, lt.MinCount, lt.MaxCount
FROM acore_world.creature_loot_template lt
WHERE lt.Entry = 53093
  AND lt.Item IN (58269,63292,63300,63311,63323,63341,63349,67059);

-- ======================================================================
-- 8. QUEST RELATION ONE-LINERS (clones exist and are spawned)
-- ======================================================================
DELETE FROM acore_world.creature_questender WHERE (`id` = 3652825 AND `quest` = 29209) OR (`id` = 3652135 AND `quest` = 29201);

INSERT INTO acore_world.creature_questender (`id`,`quest`) VALUES
(3652825,29209),
(3652135,29201);

DELETE FROM acore_world.creature_queststarter WHERE `id` = 3652135 AND `quest` = 29214;

INSERT INTO acore_world.creature_queststarter (`id`,`quest`) VALUES
(3652135,29214);
