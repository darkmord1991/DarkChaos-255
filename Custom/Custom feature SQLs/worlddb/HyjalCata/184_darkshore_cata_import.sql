-- ---------------------------------------------------------------------------
-- 184  Darkshore (map 750, zone 148) -- full Cataclysm import
-- ---------------------------------------------------------------------------
-- Reported: after the recent terrain expansion that replaced the half-baked
-- borders with open sea, Darkshore has NPCs only in the north and is otherwise
-- empty.
--
-- MEASURED: it is not "thin", it is essentially ABSENT.
--     cata_world zone 148:  2,432 creature spawns / 216 entries
--                             753 gameobject spawns / 114 entries
--     ours on map 750:      ZERO spawns anywhere with y > -534
-- Map-750 creatures currently span y -5331..-534 while Darkshore runs
-- y -1692..+1308, so everything from the Felwood border northward -- Lor'danel,
-- the whole coast, Ameth'Aran, Bashal'Aran, the Master's Glaive -- has never
-- been populated. The handful of NPCs visible "in the north" are the Felwood
-- border overlap, not Darkshore content.
--
-- Selected by `zoneId = 148`, NOT by a bounding box -- the mistake 181_ made
-- and 183_ had to correct. cata_world.creature/gameobject both carry a real
-- zoneId; Darkshore is 148 there.
--
-- This is the POST-Cataclysm Darkshore, per "stay with the cata stuff": rebuilt
-- Lor'danel rather than the destroyed Auberdine. Note cata_world's zone 148
-- deliberately mixes old and new entry ids (3841 Teldira and 4187 Harlon are
-- vanilla ids Blizzard kept; 43419-43439 are Cata additions) -- so unlike
-- 181_/183_ this imports the WHOLE zone, not just id>=40000. Nothing of
-- Darkshore exists here yet, so there is no vanilla layer to preserve.
--
-- Entry convention +3,700,000 (the band this half of map 750 already uses).
-- Guid blocks verified empty: creatures 15,860,001+, gameobjects 15,900,001+.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creature_template -- 216 entries
-- ---------------------------------------------------------------------------
-- 30 of these already exist at +3,700,000 (entries shared with Felwood etc.);
-- they are deleted and re-inserted identically so this file stays re-runnable.
-- loot/pickpocket/skin ids zeroed -- cata_world's creature loot ids do not
-- exist here and would only produce boot spam.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (
  SELECT * FROM (SELECT DISTINCT c.`id`+3700000 FROM `cata_world`.`creature` c
                 WHERE c.`map`=1 AND c.`zoneId`=148) x);

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,`KillCredit1`,`KillCredit2`,
     `name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,`speed_run`,
     `rank`,`dmgschool`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,
     `unit_flags2`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,
     `DamageModifier`,`ExperienceModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT s.`entry`+3700000,0,0,0,
       CASE WHEN s.`KillCredit1`>0 THEN s.`KillCredit1`+3700000 ELSE 0 END,
       CASE WHEN s.`KillCredit2`>0 THEN s.`KillCredit2`+3700000 ELSE 0 END,
       s.`name`,s.`subname`,s.`IconName`,s.`gossip_menu_id`,s.`minlevel`,s.`maxlevel`,s.`faction`,s.`npcflag`,
       s.`speed_walk`,s.`speed_run`,s.`rank`,s.`dmgschool`,s.`BaseAttackTime`,s.`RangeAttackTime`,
       s.`BaseVariance`,s.`RangeVariance`,s.`unit_class`,s.`unit_flags`,s.`unit_flags2`,s.`family`,s.`type`,
       s.`type_flags`,0,0,0,s.`PetSpellDataId`,s.`VehicleId`,s.`mingold`,s.`maxgold`,s.`AIName`,s.`MovementType`,
       s.`HoverHeight`,s.`HealthModifier`,s.`ManaModifier`,s.`ArmorModifier`,s.`DamageModifier`,
       s.`ExperienceModifier`,s.`RacialLeader`,s.`movementId`,s.`RegenHealth`,s.`flags_extra`,'',s.`VerifiedBuild`
FROM `cata_world`.`creature_template` s
WHERE s.`entry` IN (SELECT DISTINCT c.`id` FROM `cata_world`.`creature` c
                    WHERE c.`map`=1 AND c.`zoneId`=148);

-- ---------------------------------------------------------------------------
-- B) creature_template_model
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  SELECT * FROM (SELECT DISTINCT c.`id`+3700000 FROM `cata_world`.`creature` c
                 WHERE c.`map`=1 AND c.`zoneId`=148) x);

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT t.`entry`+3700000, i.idx, m.model, 1, 1, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN (SELECT 0 AS idx UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) i
JOIN LATERAL (SELECT CASE i.idx WHEN 0 THEN t.`modelid1` WHEN 1 THEN t.`modelid2`
                                WHEN 2 THEN t.`modelid3` ELSE t.`modelid4` END AS model) m
WHERE t.`entry` IN (SELECT DISTINCT c.`id` FROM `cata_world`.`creature` c
                    WHERE c.`map`=1 AND c.`zoneId`=148)
  AND m.model > 0;

-- ---------------------------------------------------------------------------
-- C) creature -- 2,432 spawns
-- ---------------------------------------------------------------------------
-- npcflag/unit_flags COALESCE'd to 0: the only two columns cata_world lets be
-- NULL that this fork does not. ObjectMgr::ChooseCreatureFlags only overrides
-- the template when the spawn value is non-zero, so 0 == cata's NULL ==
-- "inherit from template", and the vendor/flightmaster flags survive.
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 15860000 AND 15869999;

INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15860000 + ROW_NUMBER() OVER (ORDER BY s.`guid`),
       s.`id`+3700000, 750, 0, 0, 1, 1, s.`equipment_id`,
       s.`position_x`, s.`position_y`, s.`position_z`, s.`orientation`,
       s.`spawntimesecs`, s.`wander_distance`, 0, 1, 0, s.`MovementType`,
       COALESCE(s.`npcflag`,0), COALESCE(s.`unit_flags`,0), '', s.`VerifiedBuild`, 'Darkshore-Cata'
FROM `cata_world`.`creature` s
WHERE s.`map`=1 AND s.`zoneId`=148;

-- ---------------------------------------------------------------------------
-- D) gameobject_template -- 114 entries
-- ---------------------------------------------------------------------------
-- Data0-Data23 are carried across UNCHANGED, including Data1 (the chest lootid
-- for type 3). That is deliberate: 206 of the 528 node spawns use STOCK loot
-- ids this DB already has (Copper Vein 1502, Mageroyal 1417, Briarthorn 1418,
-- Tin Vein 1503, Stranglekelp, Silverleaf, Peacebloom, Earthroot, ...), so they
-- work immediately; part F below supplies the Cata-only ones.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_template` WHERE `entry` IN (
  SELECT * FROM (SELECT DISTINCT g.`id`+3700000 FROM `cata_world`.`gameobject` g
                 WHERE g.`map`=1 AND g.`zoneId`=148) x);

INSERT INTO `gameobject_template`
    (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
     `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,
     `Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,
     `AIName`,`ScriptName`,`VerifiedBuild`)
SELECT s.`entry`+3700000,s.`type`,s.`displayId`,s.`name`,s.`IconName`,s.`castBarCaption`,s.`unk1`,s.`size`,
       s.`Data0`,s.`Data1`,s.`Data2`,s.`Data3`,s.`Data4`,s.`Data5`,s.`Data6`,s.`Data7`,s.`Data8`,s.`Data9`,
       s.`Data10`,s.`Data11`,s.`Data12`,s.`Data13`,s.`Data14`,s.`Data15`,s.`Data16`,s.`Data17`,s.`Data18`,
       s.`Data19`,s.`Data20`,s.`Data21`,s.`Data22`,s.`Data23`,s.`AIName`,'',s.`VerifiedBuild`
FROM `cata_world`.`gameobject_template` s
WHERE s.`entry` IN (SELECT DISTINCT g.`id` FROM `cata_world`.`gameobject` g
                    WHERE g.`map`=1 AND g.`zoneId`=148);

-- ---------------------------------------------------------------------------
-- E) gameobject -- 753 spawns
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject` WHERE `guid` BETWEEN 15900000 AND 15909999;

INSERT INTO `gameobject`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,
     `position_x`,`position_y`,`position_z`,`orientation`,
     `rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15900000 + ROW_NUMBER() OVER (ORDER BY s.`guid`),
       s.`id`+3700000, 750, 0, 0, 1, 1,
       s.`position_x`, s.`position_y`, s.`position_z`, s.`orientation`,
       s.`rotation0`, s.`rotation1`, s.`rotation2`, s.`rotation3`,
       s.`spawntimesecs`, s.`animprogress`, s.`state`, '', s.`VerifiedBuild`, 'Darkshore-Cata'
FROM `cata_world`.`gameobject` s
WHERE s.`map`=1 AND s.`zoneId`=148;

-- ---------------------------------------------------------------------------
-- F) gameobject_loot_template -- the Cata-only node/quest-object loot
-- ---------------------------------------------------------------------------
-- The 11 lootids behind Encrusted Clam (139 spawns), Highborne Relic (46),
-- Bear's Paw (27), Slain Wildkin Feather (25), Glittering Shell (19), Twilight
-- Plans (18), Fuming Toadstool (17), Greymist Debris (26), the two treasure
-- chests, Charred Book and the Ancient Disc -- 282 rows, none of which exist
-- here. Without these those ~322 objects would be clickable but drop nothing.
-- Loot ids are kept UNCHANGED (verified free in this DB) so gameobject_template
-- Data1 needs no rewriting.
--
-- 10 of the 282 rows reference Cata-only items absent from item_template and
-- are FILTERED OUT rather than imported -- an unknown item id in a loot table
-- is a boot error ("has non-existed item"), unlike the creature-loot case where
-- rows were kept and flagged.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN
    (26821,26825,26827,26866,26867,27011,27217,27237,27249,27250,39335);

INSERT INTO `gameobject_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT l.`Entry`,l.`Item`,l.`Reference`,l.`Chance`,l.`QuestRequired`,l.`LootMode`,l.`GroupId`,l.`MinCount`,l.`MaxCount`,l.`Comment`
FROM `cata_world`.`gameobject_loot_template` l
WHERE l.`Entry` IN (26821,26825,26827,26866,26867,27011,27217,27237,27249,27250,39335)
  AND EXISTS (SELECT 1 FROM `item_template` it WHERE it.`entry` = l.`Item`);

-- ---------------------------------------------------------------------------
-- G) STILL TO DO -- Darkshore's two flight masters need taxi data
-- ---------------------------------------------------------------------------
-- Teldira Moonfeather (3841 -> 3703841, Lor'danel ~7462/-327) and Delanea
-- (33253 -> 3733253, ~4970/+146) come in with the FLIGHTMASTER npcflag but,
-- like Hanah and Dirzak before them, need the full four-part treatment before
-- their menus work: a gen_taxi.py NODEMAP entry + re-run, the DBC deploy, a
-- kNodes[] entry in dc_downport_taxi.cpp, and ScriptName
-- 'npc_dc_downport_flightmaster'. Node ids must stay <= 448.
-- Deliberately separated so this import can go live without waiting on a
-- client redistribution.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM creature   WHERE guid BETWEEN 15860000 AND 15869999;  -- 2432
--   SELECT COUNT(*) FROM gameobject WHERE guid BETWEEN 15900000 AND 15909999;  -- 753
--   -- no template should end up model-less (renders as an invisible NPC):
--   SELECT t.entry, t.name FROM creature_template t
--    WHERE t.entry IN (SELECT DISTINCT id+3700000 FROM cata_world.creature WHERE map=1 AND zoneId=148)
--      AND NOT EXISTS (SELECT 1 FROM creature_template_model m WHERE m.CreatureID=t.entry);
-- ---------------------------------------------------------------------------
