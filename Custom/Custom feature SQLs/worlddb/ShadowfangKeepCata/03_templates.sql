-- =====================================================================================
-- Cataclysm Shadowfang Keep -- map 825 clone, step 3: templates
--
-- Copies the Cataclysm creature/gameobject templates out of `cata_world` into
-- `acore_world` under a DC id band. Cross-database INSERT ... SELECT: both schemas
-- live on the same MySQL server, so the 1,100+ rows are never transcribed by hand.
--
-- WHY THE ENTRIES ARE OFFSET AT ALL
-- Cata SFK reuses two STOCK entries -- 3887 Baron Silverlaine and 4278 Commander
-- Springvale -- which classic Shadowfang Keep on map 33 also spawns and drives with
-- SmartAI. Writing a Cata ScriptName onto those rows would change classic SFK.
-- Offsetting every entry is what keeps the two dungeons genuinely independent.
--
-- ID BANDS (verified empty before allocation)
--   creature_template     +5,000,000   (2110..38208 -> 5002110..5038208)
--   gameobject_template   +5,100,000
-- Band 5,000,000-5,100,000 held 0 rows in creature_template, gameobject_template,
-- creature_loot_template and gameobject_loot_template at the time of writing.
--
-- COLUMN LISTS ARE EXPLICIT AND SHARED-ONLY. cata_world and acore_world disagree on both
-- the column SET and the column ORDER (creature.phaseMask is ordinal 7 in acore and 8 in
-- cata; creature.equipment_id is 8 vs 13), so SELECT * or any positional insert would
-- silently scramble every row. Columns absent from cata_world keep their AzerothCore
-- defaults: creature_template.exp, speed_swim, speed_flight, detection_range,
-- dynamicflags, CreatureImmunitiesId.
--
-- STOCK IS NOT TOUCHED. Every statement is scoped to the 5,0xx,xxx / 5,1xx,xxx bands.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- The import set, materialised once so every later step agrees on it. Three sources:
--
--   * the 47 entries actually spawned on cata_world map 33
--
--   * the SUMMONED encounter adds. These are NOT spawned -- the bosses create them at
--     runtime -- so they appear nowhere in `creature` and cannot be derived from spawn
--     data. The list therefore comes from the `SKCreatures` enum in
--     src/server/scripts/DC/ShadowfangKeepCata/sfk_cata.h and must stay in step with it.
--     Leaving them out is silent and total: the encounter runs, the boss calls
--     SummonCreature, the entry does not exist in the offset band, and nothing appears --
--     no worgen spirits for Silverlaine, no ghouls for Godfrey, no toxin for Walden.
--     It is also what makes 06's npc_sfk_worgen_spirit / npc_wailing_guardsman /
--     npc_tormented_officer updates match 0 rows.
--
--   * the entries reached through difficulty_entry_1/2/3 (the heroic variants) and
--     through creature_summon_groups. Never spawned directly, but AC resolves them at
--     runtime, so leaving them out would dangle every reference.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_sfk825_ct_set`;
CREATE TABLE `dc_sfk825_ct_set` (`entry` INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;

INSERT INTO `dc_sfk825_ct_set` (`entry`)
SELECT DISTINCT c.id FROM `cata_world`.`creature` c WHERE c.map = 33;

-- Summoned adds, from sfk_cata.h `enum SKCreatures`. INSERT IGNORE because a few of these
-- (Cromush, Ivar, the Berserkers, the Blightspreaders, the DEBUG Announcer) ARE spawned
-- and so are already present.
INSERT IGNORE INTO `dc_sfk825_ct_set` (`entry`)
SELECT e FROM (
    SELECT 51047 e UNION SELECT 50851 UNION SELECT 50934 UNION SELECT 50857   -- Silverlaine: spirits + ghosts
    UNION SELECT 51080 UNION SELECT 50869 UNION SELECT 51085 UNION SELECT 50834
    UNION SELECT 50615 UNION SELECT 50613 UNION SELECT 50547 UNION SELECT 50503 -- Springvale
    UNION SELECT 50522                                                          -- Walden: Mystery Toxin
    UNION SELECT 50561 UNION SELECT 52065                                       -- Godfrey: ghouls + barrage dummy
    UNION SELECT 47294 UNION SELECT 47006 UNION SELECT 43679                    -- generic
    UNION SELECT 47027 UNION SELECT 47031
) a
WHERE a.e IN (SELECT entry FROM `cata_world`.`creature_template`);

-- Anything creature_summon_groups points at (the Hummel event's apothecaries).
INSERT IGNORE INTO `dc_sfk825_ct_set` (`entry`)
SELECT g.entry FROM `cata_world`.`creature_summon_groups` g
WHERE g.summonerId IN (SELECT entry FROM `dc_sfk825_ct_set`)
  AND g.entry IN (SELECT entry FROM `cata_world`.`creature_template`);

INSERT IGNORE INTO `dc_sfk825_ct_set` (`entry`)
SELECT d.e FROM (
    SELECT difficulty_entry_1 e FROM `cata_world`.`creature_template`
        WHERE entry IN (SELECT entry FROM `dc_sfk825_ct_set`) AND difficulty_entry_1 <> 0
    UNION SELECT difficulty_entry_2 FROM `cata_world`.`creature_template`
        WHERE entry IN (SELECT entry FROM `dc_sfk825_ct_set`) AND difficulty_entry_2 <> 0
    UNION SELECT difficulty_entry_3 FROM `cata_world`.`creature_template`
        WHERE entry IN (SELECT entry FROM `dc_sfk825_ct_set`) AND difficulty_entry_3 <> 0
) d
WHERE d.e IN (SELECT entry FROM `cata_world`.`creature_template`);

-- -------------------------------------------------------------------------------------
-- creature_template
--
-- Transforms applied on the way through:
--   entry, difficulty_entry_*   +5,000,000 (0 stays 0)
--   lootid / pickpocketloot / skinloot -> 0. Loot is DELIBERATELY NOT imported: everything
--     except quest items can be skipped and scaled up later. Zeroing beats offsetting to a
--     loot template that does not exist, which would log a warning per kill. Revisit when
--     you tune the loot pass.
--   movementId -> 0. It points at creature_template_movement, and the cata_world copy is
--     missing 5 of AC's 8 columns (Ground, Swim, Flight, Rooted, Chase), so that table is
--     not safe to copy blind. 10 entries are affected; they fall back to default movement.
--   ScriptName -> '' here. The real bindings are applied in 06, so this file stays purely
--     mechanical and 06 is the single place that lists them.
--   AIName carried through as-is: every non-empty value in this set is 'SmartAI'
--     (verified), and the matching smart_scripts rows come across in 05.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` BETWEEN 5000000 AND 5099999;
INSERT INTO `creature_template`
    (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
     `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`,
     `minlevel`, `maxlevel`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`,
     `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `family`, `type`,
     `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
     `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`,
     `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
SELECT
     t.entry + 5000000,
     IF(t.difficulty_entry_1 = 0, 0, t.difficulty_entry_1 + 5000000),
     IF(t.difficulty_entry_2 = 0, 0, t.difficulty_entry_2 + 5000000),
     IF(t.difficulty_entry_3 = 0, 0, t.difficulty_entry_3 + 5000000),
     t.KillCredit1, t.KillCredit2, t.name, t.subname, t.IconName, t.gossip_menu_id,
     t.minlevel, t.maxlevel, t.faction, t.npcflag, t.speed_walk, t.speed_run, t.rank,
     t.dmgschool, t.DamageModifier, t.BaseAttackTime, t.RangeAttackTime, t.BaseVariance,
     t.RangeVariance, t.unit_class, t.unit_flags, t.unit_flags2, t.family, t.type,
     t.type_flags, 0, 0, 0, t.PetSpellDataId, t.VehicleId,
     t.mingold, t.maxgold, t.AIName, t.MovementType, t.HoverHeight, t.HealthModifier,
     t.ManaModifier, t.ArmorModifier, t.ExperienceModifier, t.RacialLeader, 0,
     t.RegenHealth, t.flags_extra, '', t.VerifiedBuild
FROM `cata_world`.`creature_template` t
WHERE t.entry IN (SELECT entry FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- gameobject_template -- schema is a clean 1:1 (all 35 AC columns exist in cata_world).
--
-- ENTRIES ARE REMAPPED DENSELY, NOT OFFSET.
-- The 43 GO entries on cata map 33 span 18,895..208,524. A flat `+5,100,000` would
-- scatter them from 5,118,895 to 5,308,524 -- across three 100k bands, and only the
-- first of those was ever verified empty. It collided immediately with DC's own
-- 5,301,906 "Rocket Delivery System" (25 live rows sit in 5.2M-5.4M), and because the
-- companion DELETE was scoped to 5.1M-5.2M it could not even clean up after itself.
--
-- Dense remap into 5,400,000+ instead: 43 entries, 43 consecutive ids, and the width of
-- the SOURCE range stops mattering. Band verified empty in both gameobject_template and
-- gameobject_loot_template. The mapping is kept so 04 can join it.
--
-- (creature_template keeps its flat +5,000,000: that import set tops out at entry 53,488,
-- so the whole thing lands inside the single 5.0M-5.1M band that was verified.)
--
--   Data* carried VERBATIM, and they are the thing to re-check by hand: for doors and
--   chests several Data slots hold lock ids, loot ids and linked-trap entries. Any that
--   point at a loot template are inert here because loot was not imported. Verified that
--   none of them points at another map-33 GO entry, so nothing needs remapping through
--   the table below.
--   ScriptName -> '' (see above); 5 rows carry a non-empty AIName/ScriptName upstream.
-- -------------------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_sfk825_gomap`;
CREATE TABLE `dc_sfk825_gomap` (
    `src_entry` INT UNSIGNED NOT NULL PRIMARY KEY,
    `new_entry` INT UNSIGNED NOT NULL,
    UNIQUE KEY `uk_new` (`new_entry`)
) ENGINE=InnoDB;

INSERT INTO `dc_sfk825_gomap` (`src_entry`, `new_entry`)
SELECT s.id, 5400000 + (ROW_NUMBER() OVER (ORDER BY s.id)) - 1
FROM (SELECT DISTINCT g.id FROM `cata_world`.`gameobject` g WHERE g.map = 33) s;

DELETE FROM `gameobject_template` WHERE `entry` BETWEEN 5400000 AND 5409999;
INSERT INTO `gameobject_template`
    (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
     `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`,
     `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`,
     `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`,
     `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT
     m.new_entry, t.type, t.displayId, t.name, t.IconName, t.castBarCaption, t.unk1, t.size,
     t.Data0, t.Data1, t.Data2, t.Data3, t.Data4, t.Data5, t.Data6, t.Data7, t.Data8,
     t.Data9, t.Data10, t.Data11, t.Data12, t.Data13, t.Data14, t.Data15, t.Data16,
     t.Data17, t.Data18, t.Data19, t.Data20, t.Data21, t.Data22, t.Data23,
     t.AIName, '', t.VerifiedBuild
FROM `cata_world`.`gameobject_template` t
JOIN `dc_sfk825_gomap` m ON m.src_entry = t.entry;

-- -------------------------------------------------------------------------------------
-- creature_equip_template -- clean 1:1. Keyed (CreatureID, ID); creature.equipment_id
-- holds the ID half, so only CreatureID shifts.
-- -------------------------------------------------------------------------------------
DELETE FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 5000000 AND 5099999;
INSERT INTO `creature_equip_template`
    (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`)
SELECT e.CreatureID + 5000000, e.ID, e.ItemID1, e.ItemID2, e.ItemID3, e.VerifiedBuild
FROM `cata_world`.`creature_equip_template` e
WHERE e.CreatureID IN (SELECT entry FROM `dc_sfk825_ct_set`);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
-- NOTE: every branch returns CAST(<number> AS CHAR). Do not return a value read out of a
-- text column here -- creature_template.ScriptName is utf8mb4_unicode_ci while a string
-- literal takes the connection collation, and mixing the two in one UNION fails with
-- SQL error 1271 "Illegal mix of collations". The stock-safety checks below therefore
-- report 1/0 rather than the text itself.
SELECT 'import set (want 97)' AS `check`, CAST(COUNT(*) AS CHAR) AS result FROM `dc_sfk825_ct_set`
UNION ALL SELECT 'creature_template (want 97)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'summoned adds present (want 15)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `entry` IN (
        51047+5000000, 50851+5000000, 50934+5000000, 50857+5000000, 51080+5000000,
        50869+5000000, 51085+5000000, 50834+5000000, 50615+5000000, 50613+5000000,
        50547+5000000, 50503+5000000, 50522+5000000, 50561+5000000, 52065+5000000)
UNION ALL SELECT 'GO entry map (want 43)', CAST(COUNT(*) AS CHAR) FROM `dc_sfk825_gomap`
UNION ALL SELECT 'gameobject_template (want 43)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `entry` BETWEEN 5400000 AND 5409999
UNION ALL SELECT 'GO templates outside the band (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` g JOIN `dc_sfk825_gomap` m ON m.new_entry = g.entry
    WHERE g.entry NOT BETWEEN 5400000 AND 5409999
UNION ALL SELECT 'creature_equip_template (want 15)', CAST(COUNT(*) AS CHAR)
    FROM `creature_equip_template` WHERE `CreatureID` BETWEEN 5000000 AND 5099999
UNION ALL SELECT 'dangling difficulty refs (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` a WHERE a.entry BETWEEN 5000000 AND 5099999
      AND a.difficulty_entry_1 <> 0
      AND a.difficulty_entry_1 NOT IN (SELECT b.entry FROM `creature_template` b)
UNION ALL SELECT 'STOCK 3887 Silverlaine ScriptName still empty (want 1)',
    CAST((SELECT `ScriptName` = '' FROM `creature_template` WHERE `entry` = 3887) AS CHAR)
UNION ALL SELECT 'STOCK 4278 Springvale ScriptName still empty (want 1)',
    CAST((SELECT `ScriptName` = '' FROM `creature_template` WHERE `entry` = 4278) AS CHAR);
