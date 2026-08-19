-- 89_missing_referenced_creatures.sql -- map 751 Lordaeron extension, DB step 28.
--
-- 44 creature templates the band references but that were NEVER IMPORTED IN ANY FORM
-- -- not at their own id, not at the +4,100,000 remap.
--
-- SAME ROOT CAUSE `46_missing_referenced_creatures.sql` DOCUMENTED FOR THE +3,600,000
-- BAND: the import discovers what to clone by joining `cata_world.creature` (static
-- spawns). NPCs that only ever appear dynamically -- kill-credit bunnies, quest
-- proxies, script-summoned actors -- have no spawn row, so the join never sees them.
-- 41 of these 44 have ZERO spawns in Cata.
--
-- What they were breaking:
--   * 49 quest objectives across ~45 quests -- "Quest 24967 has `RequiredNpcOrGo1` =
--     44175 but creature with entry 44175 does not exist, quest can't be done."
--     44175 "Spell Practice Credit" alone gates 6 quests.
--   * SmartAI summons and target lookups -- "Event SMART_EVENT_DISTANCE_CREATURE
--     using invalid creature entry 39038", action 12 SUMMON on 38980/39002.
--
-- IMPORTED AT THEIR PLAIN CATA IDS, NOT +4,100,000. This is deliberate and is the
-- opposite of what 86_ did for waypoints, so it is worth stating why:
--   * every reference to them already uses the plain id -- 6 quest rows point at
--     44175, zero point at 4144175
--   * the band's quest layer is ALREADY mixed: 75 quests use remapped creature ids
--     but 38 still use plain Cata ids. Plain is the more consistent choice here, and
--     it needs no reference rewriting at all
--   * all 44 ids were verified free in our creature_template
-- Remapping instead would mean rewriting 4 quest_template columns and several
-- smart_scripts fields for no gain.
--
-- SCHEMA DRIFT: our creature_template is 55 columns, Cata's is 84, so `SELECT *` is
-- impossible. 49 of our 55 exist in Cata; the other 6 take the value every one of the
-- band's 1,127 existing templates already uses (verified uniform):
--     exp=0  speed_swim=1  speed_flight=1  detection_range=20
--     dynamicflags=0  CreatureImmunitiesId=0
--
-- ===========================================================================
-- 1. creature_template -- 44 rows
--
--    FOUR GUARDS, each preventing an error class this import would otherwise
--    introduce. They are CASE expressions rather than post-hoc UPDATEs so the rows
--    are never briefly wrong.
--
--    * AIName is kept ONLY if the entry actually has smart_scripts rows to import.
--      This is exactly the trap 77_ hit: 74_ cloned templates with `SELECT *`, which
--      carried AIName='SmartAI' across without the scripts, and the creature booted
--      with SmartAI enabled and no script -- losing its whole behaviour and logging
--      "has SmartAI enabled but no SmartAI entries in the database".
--    * ScriptName is blanked. Cata's values name TrinityCore C++ scripts that do not
--      exist in this core, which boot-logs "ScriptName X for creature Y not found".
--      None of these 44 have a DC script.
--    * VehicleId is dropped unless the id exists in vehicle_dbc (75_ added 12).
--    * lootid / pickpocketloot / skinloot are dropped unless the loot template is
--      actually present, which is what 08_/44_/45_ populated.
-- ===========================================================================
DELETE FROM `creature_template` WHERE `entry` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

INSERT INTO `creature_template`
 (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
  `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
  `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,`rank`,`dmgschool`,
  `DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,
  `unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,
  `skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
  `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,
  `RegenHealth`,`CreatureImmunitiesId`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT c.`entry`, c.`difficulty_entry_1`, c.`difficulty_entry_2`, c.`difficulty_entry_3`,
       c.`KillCredit1`, c.`KillCredit2`, c.`name`, c.`subname`, c.`IconName`, c.`gossip_menu_id`,
       c.`minlevel`, c.`maxlevel`,
       0,                                                     -- exp: band default
       c.`faction`, c.`npcflag`, c.`speed_walk`, c.`speed_run`,
       1, 1, 20,                                              -- speed_swim / speed_flight / detection_range
       c.`rank`, c.`dmgschool`, c.`DamageModifier`, c.`BaseAttackTime`, c.`RangeAttackTime`,
       c.`BaseVariance`, c.`RangeVariance`, c.`unit_class`, c.`unit_flags`, c.`unit_flags2`,
       0,                                                     -- dynamicflags
       c.`family`, c.`type`, c.`type_flags`,
       CASE WHEN EXISTS (SELECT 1 FROM `creature_loot_template` l WHERE l.`Entry` = c.`lootid`)
            THEN c.`lootid` ELSE 0 END,
       CASE WHEN EXISTS (SELECT 1 FROM `pickpocketing_loot_template` l WHERE l.`Entry` = c.`pickpocketloot`)
            THEN c.`pickpocketloot` ELSE 0 END,
       CASE WHEN EXISTS (SELECT 1 FROM `skinning_loot_template` l WHERE l.`Entry` = c.`skinloot`)
            THEN c.`skinloot` ELSE 0 END,
       c.`PetSpellDataId`,
       CASE WHEN c.`VehicleId` > 0 AND EXISTS (SELECT 1 FROM `vehicle_dbc` v WHERE v.`ID` = c.`VehicleId`)
            THEN c.`VehicleId` ELSE 0 END,
       c.`mingold`, c.`maxgold`,
       CASE WHEN EXISTS (SELECT 1 FROM `cata_world`.`smart_scripts` s
                         WHERE s.`entryorguid` = c.`entry` AND s.`source_type` = 0)
            THEN c.`AIName` ELSE '' END,
       c.`MovementType`, c.`HoverHeight`, c.`HealthModifier`, c.`ManaModifier`, c.`ArmorModifier`,
       c.`ExperienceModifier`, c.`RacialLeader`, c.`movementId`, c.`RegenHealth`,
       0,                                                     -- CreatureImmunitiesId
       c.`flags_extra`,
       '',                                                    -- ScriptName: see guard note
       c.`VerifiedBuild`
FROM `cata_world`.`creature_template` c
WHERE c.`entry` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

-- ===========================================================================
-- 2. creature_template_model -- the layer that actually gates spawning
--
--    Our creature_template has NO modelid columns; models live here (and the display
--    must also exist in CreatureDisplayInfo.dbc, or LoadCreatureTemplateModels
--    silently DROPS the row and the template reports "has no model defined").
--
--    Of the 56 displays these creatures use, 5 are absent from our DBC:
--        32778, 34511, 34512, 34513, 36358
--    All five belong to pure credit/proxy bunnies that are never rendered:
--        44175 Spell Practice Credit          (32778)
--        45495 Worgen Combatant Proxy         (34511/34512/34513)
--        49189/49542/49553/49561/49626/49627  (36358)  "PvG ... Complete" credits
--    They are substituted with **11686**, this core's canonical invisible-trigger
--    display -- the one Invisible Stalker (15214) and World Invisible Trigger (12999)
--    use, already present with a creature_model_info row (BoundingRadius 0.5,
--    CombatReach 1). For an NPC that exists only to take a kill credit, invisible is
--    not a compromise, it is correct.
--
--    That substitution is exactly sufficient: the set of displays lacking a
--    creature_model_info row is precisely those five, so afterwards every display
--    these 44 use resolves through all three layers and NO new creature_model_info
--    rows are needed.
--
--    DisplayScale/Probability are 1/1 -- all 44 have scale 1 in Cata and all 1,466
--    existing band model rows are 1/1.
-- ===========================================================================
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT m.`CreatureID`, m.`Idx`,
       CASE WHEN m.`d` IN (32778, 34511, 34512, 34513, 36358) THEN 11686 ELSE m.`d` END,
       1, 1, 0
FROM (
    SELECT `entry` AS `CreatureID`, 0 AS `Idx`, `modelid1` AS `d` FROM `cata_world`.`creature_template` WHERE `modelid1` > 0
    UNION ALL SELECT `entry`, 1, `modelid2` FROM `cata_world`.`creature_template` WHERE `modelid2` > 0
    UNION ALL SELECT `entry`, 2, `modelid3` FROM `cata_world`.`creature_template` WHERE `modelid3` > 0
    UNION ALL SELECT `entry`, 3, `modelid4` FROM `cata_world`.`creature_template` WHERE `modelid4` > 0
) m
WHERE m.`CreatureID` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

-- ===========================================================================
-- 3. creature_template_addon -- 44 rows
--
--    Cata's table is 15 columns to our 8: it stores StandState / AnimTier / VisFlags
--    / SheathState / PvPFlags as separate fields where 3.3.5 packs them into
--    bytes1/bytes2. Verified against 1,000+ already-imported band rows:
--        bytes1 = StandState + (VisFlags << 16) + (AnimTier << 24)
--        bytes2 = SheathState + (PvPFlags << 8)      (cata SheathState 2 -> our 258)
--    Across these 44 the only non-zero packing field is SheathState (0 or 1) and
--    PvPFlags is 0 everywhere, so bytes1 = 0 and bytes2 = SheathState. The formula is
--    written out anyway so it stays correct if this file is ever re-run against
--    different rows.
--
--    `path_id` is 0: Cata's `waypointPathId` indexes ITS waypoint table, which is not
--    ours, and none of these 44 patrol.
-- ===========================================================================
DELETE FROM `creature_template_addon` WHERE `entry` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)
SELECT a.`entry`, 0, a.`mount`,
       a.`StandState` + (a.`VisFlags` << 16) + (a.`AnimTier` << 24),
       a.`SheathState` + (a.`PvPFlags` << 8),
       a.`emote`, a.`visibilityDistanceType`, a.`auras`
FROM `cata_world`.`creature_template_addon` a
WHERE a.`entry` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

-- ===========================================================================
-- 4. creature_equip_template -- 8 rows. Schemas identical (see 87_).
-- ===========================================================================
DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT e.`CreatureID`, e.`ID`, e.`ItemID1`, e.`ItemID2`, e.`ItemID3`, e.`VerifiedBuild`
FROM `cata_world`.`creature_equip_template` e
WHERE e.`CreatureID` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

-- ===========================================================================
-- 5. creature_text -- 18 rows. Cata has 14 columns to our 13: it adds `SoundType`
--    between `Sound` and `BroadcastTextId` (same difference 82_ handled). Copied
--    server-side so the apostrophes in the text never go through an escaper.
-- ===========================================================================
DELETE FROM `creature_text` WHERE `CreatureID` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`,
                             `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`)
SELECT t.`CreatureID`, t.`GroupID`, t.`ID`, t.`Text`, t.`Type`, t.`Language`, t.`Probability`,
       t.`Emote`, t.`Duration`, t.`Sound`, t.`BroadcastTextId`, t.`TextRange`, t.`comment`
FROM `cata_world`.`creature_text` t
WHERE t.`CreatureID` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

-- ===========================================================================
-- 6. smart_scripts -- 24 rows. Ours is 31 columns to Cata's 29: it adds
--    `event_param6` (after event_param5) and `target_param4` (after target_param3),
--    both 0. Every column is listed on both sides so the two extra fields cannot
--    shift the rest by one -- the failure mode that would silently move a spell id
--    into a timer.
--
--    The spells these cast were checked: 73305 and 73309 were the only ones missing,
--    and 88_ now downports them. Apply 88_ BEFORE this file or those two rows will be
--    rejected at boot.
-- ===========================================================================
DELETE FROM `smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

INSERT INTO `smart_scripts`
 (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT s.`entryorguid`, s.`source_type`, s.`id`, s.`link`, s.`event_type`, s.`event_phase_mask`,
       s.`event_chance`, s.`event_flags`, s.`event_param1`, s.`event_param2`, s.`event_param3`,
       s.`event_param4`, s.`event_param5`, 0,
       s.`action_type`, s.`action_param1`, s.`action_param2`, s.`action_param3`, s.`action_param4`,
       s.`action_param5`, s.`action_param6`,
       s.`target_type`, s.`target_param1`, s.`target_param2`, s.`target_param3`, 0,
       s.`target_x`, s.`target_y`, s.`target_z`, s.`target_o`, s.`comment`
FROM `cata_world`.`smart_scripts` s
WHERE s.`source_type` = 0 AND s.`entryorguid` IN (
    38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,
    44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,
    47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,
    52072,52553,53592,53737,53827);

-- ===========================================================================
-- NOT IMPORTED -- 9 templates that need art first
--
-- Their display is absent from CreatureDisplayInfo.dbc and, unlike the eight credit
-- bunnies above, they are REAL NPCs a player would see, so an invisible substitute
-- would be a visible bug rather than a correct one. Each needs its display taken
-- through the retroport pipeline (K:\Dark-Chaos\retroport_tools) first -- the same
-- reason 46_ deferred "Mobus".
--
--     38980  Spirit of Devlin Agamand   display 31249
--     43007  Shadra                     display 33275
--     44369  Lord Godfrey               display 29675
--     44629  Garrosh Hellscream         display 32907
--     44915  Orc Crate                  display 34180
--     45270  Hillsbrad Worgen           displays 34367/34368/34369/34370
--     47442  Johnny Awesome             display 35624
--     47443  Kingslayer Orkus           display 35625
--     49231  Valdred Moray              display 36418
--
-- Once those displays are staged, add the entries to every id list in this file and
-- re-run it -- each section is DELETE-then-INSERT, so re-running is safe.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'templates imported (want 44)' AS what, COUNT(*) AS n
FROM `creature_template` WHERE `entry` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
UNION ALL SELECT 'model rows (want 62)', COUNT(*)
FROM `creature_template_model` WHERE `CreatureID` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
UNION ALL SELECT 'addon rows (want 44)', COUNT(*)
FROM `creature_template_addon` WHERE `entry` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
UNION ALL SELECT 'creature_text rows (want 18)', COUNT(*)
FROM `creature_text` WHERE `CreatureID` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
UNION ALL SELECT 'smart_scripts rows (want 24)', COUNT(*)
FROM `smart_scripts` WHERE `source_type`=0 AND `entryorguid` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
UNION ALL SELECT 'quest objectives now resolvable (was 49 broken)',
  (SELECT COUNT(*) FROM `quest_template` q WHERE q.`RequiredNpcOrGo1` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827));

-- must be empty: a template with SmartAI enabled but no script -- the 77_ trap
SELECT 'PROBLEM: SmartAI with no script rows' AS problem, t.`entry`, t.`name`
FROM `creature_template` t
WHERE t.`entry` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
  AND t.`AIName` = 'SmartAI'
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = t.`entry` AND s.`source_type` = 0);

-- must be empty: a template left with no usable model, which is what makes the core
-- log "has no model defined in creature_template_model" for every spawn
SELECT 'PROBLEM: template with no model row' AS problem, t.`entry`, t.`name`
FROM `creature_template` t
WHERE t.`entry` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
  AND NOT EXISTS (SELECT 1 FROM `creature_template_model` m WHERE m.`CreatureID` = t.`entry`);

-- must be empty: a model row whose display has no creature_model_info, which gates
-- spawning even when the DBC row exists
SELECT 'PROBLEM: display without creature_model_info' AS problem, m.`CreatureID`, m.`CreatureDisplayID`
FROM `creature_template_model` m
WHERE m.`CreatureID` IN (38887,38895,38923,38981,39002,39038,39098,42597,43236,43541,44175,44432,44433,44474,44476,44622,44623,44624,44625,44882,44942,45430,45495,45756,47444,47697,47752,48290,48684,48752,49189,49230,49337,49542,49553,49561,49626,49627,51833,52072,52553,53592,53737,53827)
  AND NOT EXISTS (SELECT 1 FROM `creature_model_info` i WHERE i.`DisplayID` = m.`CreatureDisplayID`);
