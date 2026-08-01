-- ---------------------------------------------------------------------------
-- 183  Felwood -- the rest of the Cata layer 181_ missed (west + north)
-- ---------------------------------------------------------------------------
-- CORRECTS 181_. That file selected the Cata creature layer with a hand-drawn
-- coordinate box (x 5500-7200, y -2600..-600). The box was too small: Felwood
-- is zone 361 in cata_world and actually spans x 3509-7373, y -2275..-221, so
-- everything west and north of the box was silently left out --
--     Cata-era spawns in Felwood (zone 361):  581
--     imported by 181_:                       400
--     MISSED:                                 181  (25 entries)
-- Reported in game as "Bloodvenom Post is missing a flight master": that whole
-- corner of the zone had ZERO spawns, because it sits at y ~ -320, outside the
-- box entirely.
--
-- LESSON, recorded because it nearly shipped twice: cata_world.creature carries
-- a real `zoneId`, so select by ZONE, not by an eyeballed bounding box.
-- (Felwood is 361 -- 4927 is this project's own custom AreaTable id and matches
-- nothing in cata_world.)
--
-- WHAT THIS ADDS -- another whole settlement plus the zone's fifth flight point:
--   * WILDHEART POINT (~4735/-880/343), entirely absent until now:
--     43079 Chyella Hushglade (Hippogryph Master -- Felwood's FIFTH flight
--     master), 48599 Innkeeper Teenycaugh, 47617 Farlus Wildheart.
--   * BLOODVENOM POST (~5100/-350) -- the reported spot: 47679 Winna Hazzard
--     and the Bloodvenom Slimeslave population that Cata put there.
--   * EMERALD SANCTUARY vendors 48607 Muurald, 48608 Kamar (the flight master
--     Gorrim was already present as DC entry 3722931).
--   * 47341 Arcanist Delaris + 47366 Impsy (Shatter Scar Vale), 47692 Altsoba
--     Ragetotem, 47696 Kelnir Leafsong, 51664 Andalar Shadevale, and the
--     remaining Cata mobs.
--
-- ABOUT THE REPORTED MISSING FLIGHT MASTER -- worth being precise, because the
-- answer is "correct as-is" rather than "fixed": there is deliberately NO
-- flight master at Bloodvenom Post. Cata node 48 "Bloodvenom Post, Felwood" is
-- flagged "[DISABLED in 4.x]" in TaxiNodes.dbc -- Blizzard retired that flight
-- point in the revamp. Its replacement is Wildheart Point ~700 yards away,
-- which this file finally brings in. So Felwood's complete Cata network is five
-- points: Talonbranch (343), Emerald Sanctuary (339), Whisperwind Grove (346),
-- Wildheart Point (349) and Irontree Clearing (347).
--
-- Guid block 15,840,001+ (verified empty) so 181_'s 15,830,00x block is
-- untouched. 4 of the 25 entries also have spawns inside 181_'s box and so
-- already have templates; they are deleted and re-inserted identically rather
-- than skipped, which keeps this file self-contained and re-runnable.
--
-- Apply against acore_world AFTER 181_, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creature_template -- the 25 remaining entries at +3,700,000
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` IN (
  SELECT * FROM (SELECT DISTINCT c.`id`+3700000 FROM `cata_world`.`creature` c
   WHERE c.`map`=1 AND c.`zoneId`=361 AND c.`id`>=40000
     AND NOT (c.`position_x` BETWEEN 5500 AND 7200 AND c.`position_y` BETWEEN -2600 AND -600)) x);

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
                    WHERE c.`map`=1 AND c.`zoneId`=361 AND c.`id`>=40000
                      AND NOT (c.`position_x` BETWEEN 5500 AND 7200 AND c.`position_y` BETWEEN -2600 AND -600));

-- ---------------------------------------------------------------------------
-- B) creature_template_model -- unroll cata's inline modelid1-4
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (
  SELECT * FROM (SELECT DISTINCT c.`id`+3700000 FROM `cata_world`.`creature` c
   WHERE c.`map`=1 AND c.`zoneId`=361 AND c.`id`>=40000
     AND NOT (c.`position_x` BETWEEN 5500 AND 7200 AND c.`position_y` BETWEEN -2600 AND -600)) x);

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT t.`entry`+3700000, i.idx, m.model, 1, 1, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN (SELECT 0 AS idx UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) i
JOIN LATERAL (SELECT CASE i.idx WHEN 0 THEN t.`modelid1` WHEN 1 THEN t.`modelid2`
                                WHEN 2 THEN t.`modelid3` ELSE t.`modelid4` END AS model) m
WHERE t.`entry` IN (SELECT DISTINCT c.`id` FROM `cata_world`.`creature` c
                    WHERE c.`map`=1 AND c.`zoneId`=361 AND c.`id`>=40000
                      AND NOT (c.`position_x` BETWEEN 5500 AND 7200 AND c.`position_y` BETWEEN -2600 AND -600))
  AND m.model > 0;

-- ---------------------------------------------------------------------------
-- C) creature -- the 181 missed spawns into guid block 15,840,001+
-- ---------------------------------------------------------------------------
-- npcflag / unit_flags COALESCE'd to 0 for the same reason as 181_: they are
-- the only two columns cata_world lets be NULL that this fork does not, and
-- ObjectMgr::ChooseCreatureFlags only overrides the template when the spawn
-- value is non-zero, so 0 == cata's NULL == "inherit from template".
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 15840000 AND 15849999;

INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15840000 + ROW_NUMBER() OVER (ORDER BY s.`guid`),
       s.`id`+3700000, 750, 0, 0, 1, 1, s.`equipment_id`,
       s.`position_x`, s.`position_y`, s.`position_z`, s.`orientation`,
       s.`spawntimesecs`, s.`wander_distance`, 0, 1, 0, s.`MovementType`,
       COALESCE(s.`npcflag`,0), COALESCE(s.`unit_flags`,0), '', s.`VerifiedBuild`, 'Felwood-Cata'
FROM `cata_world`.`creature` s
WHERE s.`map`=1 AND s.`zoneId`=361 AND s.`id`>=40000
  AND NOT (s.`position_x` BETWEEN 5500 AND 7200 AND s.`position_y` BETWEEN -2600 AND -600);

-- ---------------------------------------------------------------------------
-- D) Wire Chyella Hushglade up as a flight master
-- ---------------------------------------------------------------------------
-- Same gossip flight master as 182_. Node 349 "Wildheart Point, Felwood" was
-- added to gen_taxi.py (CATA node 595, 4.3 yds from her) and regenerated:
-- network 26 -> 27 nodes, 314 -> 342 paths, 0 synthesised arcs. The DBCs are
-- deployed and dc_downport_taxi.cpp kNodes[] has the entry -- BOTH A CLIENT
-- REDISTRIBUTION AND A WORLDSERVER REBUILD ARE REQUIRED.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_dc_downport_flightmaster'
WHERE `entry` = 3743079;

-- ---------------------------------------------------------------------------
-- Verification after applying + rebuild + client restart:
--   SELECT COUNT(*) FROM creature WHERE guid BETWEEN 15840000 AND 15849999;   -- 181
--   -- all five Felwood flight masters present and scripted:
--   SELECT entry, name, subname, ScriptName FROM creature_template
--    WHERE entry IN (3612578,3722931,3743073,3743079,3743085);
--   -- and Bloodvenom Post should now have a population but still NO flight
--   -- master -- that is correct Cataclysm behaviour.
-- ---------------------------------------------------------------------------
