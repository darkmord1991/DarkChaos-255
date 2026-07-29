-- ---------------------------------------------------------------------------
-- 173  Hyjal round-40 -- the post-172 error log, worked through in batches
-- ---------------------------------------------------------------------------
--
-- ---------------------------------------------------------------------------
-- (1) Six DC displays rejected at boot: "No model data exist for
--     `CreatureDisplayID` = 38002/38051/30512/38152/38546/38547"
-- ---------------------------------------------------------------------------
-- NOT a DBC problem, although it reads like one.  All six displays and both
-- underlying models were verified present in the live server DBCs
-- (CreatureDisplayInfo 28,033 rows, CreatureModelData 2,911).  This message
-- comes from ObjectMgr::GetCreatureModelInfo, which reads the
-- `creature_model_info` SQL table -- the six DC-added displays never got rows
-- there.  Without one the core has no bounding radius / combat reach, so the
-- models were dropped from the clone templates at load.
--
-- Rows imported from cata_world.creature_model_info, which has all six.
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (38002, 38051, 30512, 38152, 38546, 38547);
INSERT INTO `creature_model_info` (`DisplayID`, `BoundingRadius`, `CombatReach`, `Gender`, `DisplayID_Other_Gender`, `VerifiedBuild`)
SELECT c.`DisplayID`, c.`BoundingRadius`, c.`CombatReach`, c.`Gender`, c.`DisplayID_Other_Gender`, 0
FROM cata_world.`creature_model_info` c
WHERE c.`DisplayID` IN (38002, 38051, 30512, 38152, 38546, 38547);

-- The mirror problem: six creature_model_info rows for displays that exist in
-- NO display store and are referenced by no creature_template_model row
-- (verified 0 uses each).  Dead weight from earlier imports.
DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (37729, 70574, 71536, 90230, 108129, 501315)
  AND NOT EXISTS (SELECT 1 FROM `creature_template_model` t
                  WHERE t.`CreatureDisplayID` = `creature_model_info`.`DisplayID`);

-- ---------------------------------------------------------------------------
-- (2) Five items "does not have a correct display id (...), must be 0"
-- ---------------------------------------------------------------------------
-- The message means item_template disagrees with the Item.dbc STORE, and the
-- core force-corrects to the store's value -- 0 -- so these five Cata trinkets/
-- rings lose their icon.  The served Item.dbc actually has the RIGHT displays
-- (verified: 64199/76516/79959/82367) -- but the `item_dbc` override table,
-- which wins over the file, carries DisplayInfoID = 0 for exactly these five.
-- A leftover of round 11's Item.csv column-shift bug: the override rows were
-- written before the shift was fixed and never regenerated.
UPDATE `item_dbc` SET `DisplayInfoID` = 64199 WHERE `ID` = 57299 AND `DisplayInfoID` = 0;
UPDATE `item_dbc` SET `DisplayInfoID` = 76516 WHERE `ID` = 57322 AND `DisplayInfoID` = 0;
UPDATE `item_dbc` SET `DisplayInfoID` = 79959 WHERE `ID` = 57335 AND `DisplayInfoID` = 0;
UPDATE `item_dbc` SET `DisplayInfoID` = 82367 WHERE `ID` IN (57374, 57377) AND `DisplayInfoID` = 0;

-- ---------------------------------------------------------------------------
-- (3) Four mount/key items with Cata's material convention
-- ---------------------------------------------------------------------------
--     Item (Entry: 62461) does not have a correct material (-1), must be 4.
-- Cata marks these class-15 items material -1; the 3.3.5 store says 4 and the
-- core corrects them every boot.  Making the DB say 4 ends the argument.
UPDATE `item_template` SET `Material` = 4
WHERE `entry` IN (62461, 62462, 73838, 73839) AND `Material` = -1;

-- ---------------------------------------------------------------------------
-- (4) 59 items carrying Mastery Rating -- a stat that does not exist in 3.3.5
-- ---------------------------------------------------------------------------
--     Item (Entry: 66880) has wrong (non-existing?) stat_type3 (49)   ... x59
--
-- Stat 49 is Cata's ITEM_MOD_MASTERY_RATING; on this core the slot is simply
-- ignored, so every one of these Molten Front / zone-gear items has been
-- missing a whole secondary stat's budget.  Standard WotLK-downport remap:
-- crit rating (32) where the item has no crit yet, haste rating (36) where it
-- already has crit.  Verified against the live data first: of the 59, 17
-- already carry crit and 18 haste, and ZERO carry both -- so the two-step
-- remap below cannot double a stat.  Order matters: the has-crit rows must
-- move to haste BEFORE the blanket crit remap runs.
UPDATE `item_template` SET `stat_type3` = 36 WHERE `stat_type3` = 49
  AND 32 IN (`stat_type1`, `stat_type2`, `stat_type4`, `stat_type5`, `stat_type6`,
             `stat_type7`, `stat_type8`, `stat_type9`, `stat_type10`);
UPDATE `item_template` SET `stat_type4` = 36 WHERE `stat_type4` = 49
  AND 32 IN (`stat_type1`, `stat_type2`, `stat_type3`, `stat_type5`, `stat_type6`,
             `stat_type7`, `stat_type8`, `stat_type9`, `stat_type10`);
UPDATE `item_template` SET `stat_type3` = 32 WHERE `stat_type3` = 49;
UPDATE `item_template` SET `stat_type4` = 32 WHERE `stat_type4` = 49;

-- ---------------------------------------------------------------------------
-- (5) Five orphaned decoration spawns -- Troll Hut and Gunrack
-- ---------------------------------------------------------------------------
--     Table `gameobject` has gameobject (GUID: 5531333) with non existing
--     gameobject entry 4000258, skipped.   (x3, plus 4000122 x2)
--
-- Hinterland-BG map-slice decorations whose templates live only in the
-- unapplied dump Custom/gameobject_template_acore.sql.  Both display ids
-- (99741, 99877) verified present in the served GameObjectDisplayInfo.dbc, so
-- restoring the two templates is safe and beats deleting five placed spawns.
--
-- The dump targets an OLDER schema: its rows carry 34 values against this
-- fork's 35 columns (one Data field short), so it cannot be pasted verbatim --
-- an earlier revision of this file did exactly that and died with error 1136.
-- acore_backup predates these rows too (verified 0), so the dump's values are
-- kept and the Data block right-padded with the missing zero.  For decor
-- types the Data fields are inert; only entry/type/displayId/name/size act.
DELETE FROM `gameobject_template` WHERE `entry` IN (4000122, 4000258);
INSERT INTO `gameobject_template`
  (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
   `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`,
   `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`,
   `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`) VALUES
(4000122, 14, 99877, 'Troll Hut [PATCH INTERIOR]', '', '', '', 1, 0, -1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0),
(4000258, 5, 99741, 'Gunrack [PATCH]', '', '', '', 1, 0, -1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '', '', 0);

-- ---------------------------------------------------------------------------
-- (6) 29 heroic difficulty entries with a redundant ScriptName
-- ---------------------------------------------------------------------------
--     Creature (Entry: 41270) lists difficulty 1 mode entry 51116 with
--     `ScriptName` filled in. `ScriptName` of difficulty 0 mode creature is
--     always used instead.   ... x29
--
-- BWD heroic templates.  The core states outright that these ScriptNames are
-- never read -- the normal-mode entry's script always drives both modes -- so
-- clearing them changes nothing at runtime and silences 29 boot lines.
UPDATE `creature_template` SET `ScriptName` = ''
WHERE `entry` IN (51116, 51104, 49974, 49971, 49583, 51101, 49973, 51456, 49975,
                  49056, 49053, 49047, 49050, 51459, 49490, 49121, 49504, 49505,
                  49507, 49508, 49509, 49510, 49511, 49512, 47774, 49976, 49482,
                  49798, 51119)
  AND `ScriptName` <> '';

-- ---------------------------------------------------------------------------
-- (7) Giant Isles Atal'ai loot tables built but never linked
-- ---------------------------------------------------------------------------
--     Table 'pickpocketing_loot_template' Entry 400500 isn't creature
--     pickpocket lootid and not referenced from loot ...  (x11, + skinning 400523)
--
-- GiantIsles' fix_db_errors_batch4 created these tables by copying the stock
-- Atal'ai loot, intending Entry = creature entry -- but the creature templates
-- carry pickpocketloot/skinloot 0 (verified all 14), so the tables float
-- unreferenced.  Linking them finishes what that fix started; the loot content
-- itself was already curated there.  400522 (Reawakened Avatar of Hakkar) and
-- 400503 (Atal'ai Boneguard) never got tables and are left alone.
UPDATE `creature_template` SET `pickpocketloot` = `entry`
WHERE `entry` IN (400500, 400501, 400502, 400504, 400505, 400510, 400511,
                  400512, 400513, 400520, 400521)
  AND `pickpocketloot` = 0;
UPDATE `creature_template` SET `skinloot` = 400523
WHERE `entry` = 400523 AND `skinloot` = 0;

-- ---------------------------------------------------------------------------
-- (8) OutdoorPvP type 8 -- noted, needs a decision rather than a blind row
-- ---------------------------------------------------------------------------
--     Could not initialize OutdoorPvP object for type ID 8; no entry in database.
--
-- Type 8 is OUTDOOR_PVP_HL (Hinterland BG) in this fork's enum and
-- `outdoorpvp_template` holds types 1-7.  NOT fixed here: adding the row makes
-- the core instantiate the HL OutdoorPvP script at startup, which is a feature
-- switch, not an error fix -- HLBG has its own battleground flow and whether
-- the OutdoorPvP wrapper should ALSO run is a design question.
--
-- Also left alone, pre-existing and non-Hyjal: the 4,100,xxx guild-housing
-- props whose data0 reference Legion spell ids (a Legion Dalaran downport
-- backlog item), stock areatriggers 6194/6581/9861/9862, DC areatriggers
-- 607000/607001 (need AreaTrigger.dbc client rows), ICC waypoint refs
-- 16256/17238, the `command` table 'chat*' rows, and the four Castle Nathria
-- spell scripts awaiting the C++ rebuild.
-- ---------------------------------------------------------------------------

-- Verify -- expect 6 / 0 / 0 / 0 / 2 / 0:
--   SELECT COUNT(*) FROM `creature_model_info` WHERE `DisplayID` IN (38002,38051,30512,38152,38546,38547);
--   SELECT COUNT(*) FROM `item_dbc` WHERE `ID` IN (57299,57322,57335,57374,57377) AND `DisplayInfoID` = 0;
--   SELECT COUNT(*) FROM `item_template` WHERE `stat_type3` = 49 OR `stat_type4` = 49;
--   SELECT COUNT(*) FROM `item_template` WHERE `entry` IN (62461,62462,73838,73839) AND `Material` = -1;
--   SELECT COUNT(*) FROM `gameobject_template` WHERE `entry` IN (4000122, 4000258);
--   SELECT COUNT(*) FROM `pickpocketing_loot_template` p WHERE p.`Entry` BETWEEN 400500 AND 400521
--     AND NOT EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`pickpocketloot` = p.`Entry`);
