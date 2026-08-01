-- ---------------------------------------------------------------------------
-- 181  Felwood (map 750) -- import the missing Cataclysm creature layer
-- ---------------------------------------------------------------------------
-- Companion to 180_. That file established WHY Felwood looks half-built: the
-- zone was populated from the PRE-Cataclysm Kalimdor creature set. Measured
-- over the Felwood footprint (x 5500-7200, y -2600..-600):
--     cata_world:  41 vanilla-era entries + 59 CATACLYSM-era entries
--     ours:        65 vanilla-band entries +  0 Cataclysm-era entries
-- Every Cataclysm addition to the zone was therefore missing. This file imports
-- all 59 of them (430 spawns), following the zone's existing +3,700,000 entry
-- convention.
--
-- WHY THIS IS SAFE ON OUR TERRAIN -- checked, not assumed. Map 750 is a Cata
-- downport, so its heightmap is the Cataclysm one, and two independent in-game
-- readings confirm the Cata coordinates land on real ground:
--     Whisperwind Grove  reported GroundZ 411.93  -- Cata NPCs there sit at 411.9-415.3
--     Talonbranch Glade  reported FloorZ  566.0097 -- Cata Mishellena sits at 566.08
--
-- WHAT THIS RESTORES (three settlements that are currently empty or thin):
--   * WHISPERWIND GROVE (~6080/-855/412) -- the reported empty town:
--     43073 Hanah Southsong (Hippogryph Master -- the missing 2nd flightmaster),
--     47842 Arch Druid Navarax, 47843 Huntress Selura, 48126 Isural Forestsworn,
--     48339 Elessa Starbreeze, 48349 Hurak Wildhorn, 48459 Tender Puregrove,
--     48215 Innkeeper Wylaria, 48216 Hurah (Stable Master), 48469 Fez Hobnob,
--     48491 James Hallow, vendors 48573/48574/48577/48580/48581/48587,
--     plus Whisperwind Protector / Lasher / Healer.
--   * TALONBRANCH GLADE (~6200/-1930/566) -- where Mishellena stands, currently
--     just her: 47931 Denmother Ulrica (Innkeeper), 48492 Lyros Swiftwind,
--     48551 Darren Clease, 48552 Elizabeth Nesworth, 48553 Jennette Doyle,
--     48555 James Trussel, 48258 Willard Harrington, plus Talonbranch
--     Defender / Guardian / Wisp.
--   * THE GOBLIN CAMP at Jadefire Run (~6890/-1610/503) -- entirely absent:
--     43085 Dirzak Pryocrank (Flight Master -- a THIRD flightmaster),
--     48332 Deputy Clunky, 48127 Darla Drilldozer, 48333 Foreman Pikwik,
--     48493 Alton Redding, vendors 48228/48235/48236/48238, and the oil-field
--     mobs 48310/48315/48317/48331.
--   * Plus 47556 Drizle / 48461 Ferli (Timbermaw cubs), 48344 Kroshius,
--     47923 Feronas Sindweller, and the Cata mob set (Jadefire Shifter,
--     Irontree Chopper/Shredder, Felrot Courser, Rabid Screecher, ...).
--
-- ADDITIVE ONLY -- the existing vanilla layer is NOT removed. That was the plan
-- until it was checked: 12 of those vanilla entries are live QUEST OBJECTIVES
-- and deleting them would break five working quests --
--     3707107 Jadefire Trickster / 3707111 Jadefire Hellcaller / 3710648 Xavaric
--         -> 104906 "Further Corruption"
--     3707156/3707157/3707158 Deadwood Den Watcher/Avenger/Shaman
--         -> 108461 "Deadwood of the North"
--     3707440 Winterfall Den Watcher / 3707442 Winterfall Pathfinder
--         -> 105082 "Threat of the Winterfall", 108464 "Winterfall Activity"
--     3709878 Entropic Beast / 3709879 Entropic Horror
--         -> 105156 "Verifying the Corruption"
--     3639437 Twilight Hunter -> 25255 "Harrying the Hunters"
-- CONSEQUENCE, be aware: Felwood ends up denser than either version alone (522
-- existing + 430 new spawns), with both generations of some mobs present
-- (vanilla Jadefire Trickster alongside Cata Jadefire Shifter, vanilla Felpaw
-- Scavenger alongside Cata Felrot Courser). Thinning the vanilla mobs is safe
-- ONLY for entries not in the list above; that is a balance pass, deliberately
-- not bundled into a content import.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) creature_template -- 59 entries at +3,700,000
-- ---------------------------------------------------------------------------
-- Copied on the 49 columns the two schemas share. Our fork-only columns (exp,
-- speed_swim, speed_flight, detection_range, dynamicflags, CreatureImmunitiesId)
-- take their defaults; cata-only columns (modelid1-4, scale, trainer_*,
-- resistance*, spell1-8, StaticFlags*, mechanic_immune_mask, ...) have no
-- equivalent here -- modelid1-4 is handled by creature_template_model in part B,
-- the rest are Cata-only mechanics this core cannot express.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template` WHERE `entry` BETWEEN 3743073 AND 3750003;

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
                    WHERE c.`map`=1 AND c.`id`>=40000
                      AND c.`position_x` BETWEEN 5500 AND 7200
                      AND c.`position_y` BETWEEN -2600 AND -600);

-- loot/pickpocket/skin ids are zeroed above on purpose: cata_world's loot table
-- ids do not exist in this DB, and pointing at them would only produce
-- "Table `creature_loot_template` Entry N does not exist" on every boot.

-- ---------------------------------------------------------------------------
-- B) creature_template_model -- from cata's inline modelid1-4
-- ---------------------------------------------------------------------------
-- This fork moved display ids out of creature_template into their own table;
-- cata_world still carries modelid1..4 inline, so they are unrolled here. Only
-- non-zero slots are inserted, and Idx is packed 0..n so the core picks
-- uniformly among the real models.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 3743073 AND 3750003;

INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT t.`entry`+3700000, i.idx, m.model, 1, 1, t.`VerifiedBuild`
FROM `cata_world`.`creature_template` t
JOIN (SELECT 0 AS idx UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) i
JOIN LATERAL (SELECT CASE i.idx WHEN 0 THEN t.`modelid1` WHEN 1 THEN t.`modelid2`
                                WHEN 2 THEN t.`modelid3` ELSE t.`modelid4` END AS model) m
WHERE t.`entry` IN (SELECT DISTINCT c.`id` FROM `cata_world`.`creature` c
                    WHERE c.`map`=1 AND c.`id`>=40000
                      AND c.`position_x` BETWEEN 5500 AND 7200
                      AND c.`position_y` BETWEEN -2600 AND -600)
  AND m.model > 0;

-- ---------------------------------------------------------------------------
-- C) creature -- 430 spawns into the free guid block 15,830,000+
-- ---------------------------------------------------------------------------
-- Block verified empty (0 rows in 15830000-15839999; highest guid in the whole
-- table is 15820020). Coordinates are carried across UNCHANGED -- see the
-- terrain note in the header for why that is correct here. map 1 -> 750;
-- zoneId/areaId written as 0, which is what every other map-750 spawn does (the
-- core resolves them at runtime).
--
-- npcflag / unit_flags are COALESCE'd to 0: they are the only two columns where
-- cata_world allows NULL and this fork does not (all 430 rows are NULL there),
-- and 0 is the correct substitute rather than a fudge -- ObjectMgr::
-- ChooseCreatureFlags only overrides the template when the spawn value is
-- non-zero (`if (data->npcflag)`), so 0 means exactly what cata's NULL means:
-- inherit from creature_template. The flightmaster/vendor/innkeeper flags
-- therefore survive.
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `guid` BETWEEN 15830000 AND 15839999;

INSERT INTO `creature`
    (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,
     `position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,
     `currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15830000 + ROW_NUMBER() OVER (ORDER BY s.`guid`),
       s.`id`+3700000, 750, 0, 0, 1, 1, s.`equipment_id`,
       s.`position_x`, s.`position_y`, s.`position_z`, s.`orientation`,
       s.`spawntimesecs`, s.`wander_distance`, 0, 1, 0, s.`MovementType`,
       COALESCE(s.`npcflag`,0), COALESCE(s.`unit_flags`,0), '', s.`VerifiedBuild`, 'Felwood-Cata'
FROM `cata_world`.`creature` s
WHERE s.`map`=1 AND s.`id`>=40000
  AND s.`position_x` BETWEEN 5500 AND 7200
  AND s.`position_y` BETWEEN -2600 AND -600;

-- ---------------------------------------------------------------------------
-- D) STILL TO DO -- the two new flightmasters need taxi data (DBC, not SQL)
-- ---------------------------------------------------------------------------
-- 43073 Hanah Southsong (Whisperwind Grove, ~6077.7/-844.5/412.4) and
-- 43085 Dirzak Pryocrank (Jadefire Run, ~6888/-1619/503) will stand there and
-- offer the flight menu, but with no TaxiNodes row and no TaxiPath rows the
-- menu is empty -- they are talkable but not yet flyable.
--
-- Adding them needs: a TaxiNodes entry each on ContinentID 750, a TaxiPath
-- pair to every other map-750 node, and TaxiPathNode waypoints for each --
-- then a TaxiNodes.dbc + TaxiPath.dbc + TaxiPathNode.dbc recompile and deploy
-- to patch-4 AND patch-enGB-3 (both confirmed shadowed), i.e. another client
-- redistribution. Node ids must stay <= 448 on this core (see the flight-path
-- downport notes); 421-425 and 446/447 are already used by map 750.
-- Deliberately left out of this file so the creature import can go live on its
-- own without waiting on a client push.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM creature_template WHERE entry BETWEEN 3743073 AND 3750003;      -- 59
--   SELECT COUNT(*) FROM creature WHERE guid BETWEEN 15830000 AND 15839999;              -- 430
--   SELECT COUNT(*) FROM creature_template_model WHERE CreatureID BETWEEN 3743073 AND 3750003;
--   -- any template that ended up with no model would render as an invisible NPC:
--   SELECT entry, name FROM creature_template t WHERE t.entry BETWEEN 3743073 AND 3750003
--     AND NOT EXISTS (SELECT 1 FROM creature_template_model m WHERE m.CreatureID=t.entry);
-- ---------------------------------------------------------------------------
