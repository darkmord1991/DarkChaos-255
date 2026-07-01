-- =====================================================================
-- Mount Hyjal (map 750) + Molten Front -- 46  Script-dependency fixups
-- ---------------------------------------------------------------------
-- Completes the wiring for the templates cloned by the EXTENDED
-- 29_neltharion_templates.sql (apply 29 first). Cross-DB INSERT...SELECT,
-- run on the world-DB host. Idempotent.
--   1. ScriptName wiring for the newly cloned entries (extends 31).
--   2. waypoint_data 39436 (Twilight Proveditor caravan path, 17 pts).
--   3. script_waypoint for the escort AIs (from nelt_world.waypoints).
--   4. creature_text for already-live talkers the cata TDB lacked.
--   5. EffectMiscValue remaps in the ALREADY-APPLIED 41_spell_dbc rows
--      (summon spells still pointed at raw Neltharion entries).
--   6. Graduation controller spawn at the Initiation Podium + GO dedup.
-- =====================================================================
SET @OFF := 3600000;

-- ---------------------------------------------------------------------
-- 1. ScriptName wiring (targets now exist; see 31_scriptnames.sql header)
-- ---------------------------------------------------------------------
-- End of the Supply Line caravan event
UPDATE acore_world.creature_template SET ScriptName='npc_twilight_proveditor'  WHERE entry=3639436;
UPDATE acore_world.creature_template SET ScriptName='npc_twilight_slavedriver' WHERE entry=3639438;
UPDATE acore_world.creature_template SET ScriptName='npc_twilight_slave'       WHERE entry=3639431;
-- Mental Training (orb) / Agility Training (trainer, summoned by 75397)
UPDATE acore_world.creature_template SET ScriptName='npc_orb_of_ascension'                 WHERE entry=3639601;
UPDATE acore_world.creature_template SET ScriptName='npc_blazing_trainer_agility_training' WHERE entry=3640434;
-- Lycanthoth spirit vehicles (summoned by 74077/74078)
UPDATE acore_world.creature_template SET ScriptName='npc_spirit_of_logosh_goldrinn_vehicle' WHERE entry IN (3639622, 3639627);
-- Flames from Above drake
UPDATE acore_world.creature_template SET ScriptName='npc_emerald_flameweaver_infiltrators' WHERE entry=3640856;
-- As Hyjal Burns: 151010 summons the FLIGHT-VEHICLE Aronus 3675024 (nelt wired
-- npc_aronus_vehicle there). 3640816 is the static questgiver Aronus and must
-- NOT carry the vehicle escort script (31 wired it there before the clone landed).
UPDATE acore_world.creature_template SET ScriptName=''                  WHERE entry=3640816 AND ScriptName='npc_aronus_vehicle';
UPDATE acore_world.creature_template SET ScriptName='npc_aronus_vehicle' WHERE entry=3675024;
-- Punting Season (93604 drop summons the child 52177; punter vehicle 52988)
UPDATE acore_world.creature_template SET ScriptName='npc_punt_child_of_tortolla' WHERE entry=3652177;
UPDATE acore_world.creature_template SET ScriptName='npc_turtle_punter'          WHERE entry=3652988;
-- Molten Front
UPDATE acore_world.creature_template SET ScriptName='npc_molten_front_behemoth'      WHERE entry=3652552;
UPDATE acore_world.creature_template SET ScriptName='npc_molten_splash_origin_bunny' WHERE entry=3652893;
UPDATE acore_world.creature_template SET ScriptName='npc_hyjal_wisp_away'            WHERE entry=3653083;
UPDATE acore_world.creature_template SET ScriptName='npc_into_the_fire_windcaller_nordrala' WHERE entry IN (3653355, 3653217);
UPDATE acore_world.creature_template SET ScriptName='npc_into_the_fire_controller'     WHERE entry=3675181;
UPDATE acore_world.creature_template SET ScriptName='npc_into_the_fire_end_controller' WHERE entry=3675182;
UPDATE acore_world.creature_template SET ScriptName='npc_the_forlorn_spire_controller' WHERE entry=3675186;
UPDATE acore_world.creature_template SET ScriptName='npc_the_forlorn_spire_anydruid'   WHERE entry IN (3652964, 3652965, 3652953);
UPDATE acore_world.creature_template SET ScriptName='npc_the_forlorn_spire_warden'     WHERE entry IN (3652954, 3652955);
UPDATE acore_world.creature_template SET ScriptName='npc_the_forlorn_spire_camera'     WHERE entry=3653017;
UPDATE acore_world.creature_template SET ScriptName='npc_trained_fire_hawk_vehicle'    WHERE entry=3653300;
UPDATE acore_world.creature_template SET ScriptName='npc_flame_protection_rune'        WHERE entry IN (3652884,3652885,3652886,3652887,3652888,3652889,3652890,3653887);
-- TODO: npc_aessina_miracle_vehicle -- the ridden vehicle entry could not be
-- identified in nelt_world (Aessina 41406 is the summoned passenger, not the
-- vehicle). Resolve the summon spell of quest 25807 before wiring.

-- ---------------------------------------------------------------------
-- 2. Proveditor caravan path (MovePath(39436) in npc_twilight_proveditor).
--    nelt waypoint_data(id,point,x,y,z,orientation int,delay,move_flag,...)
--    -> this fork adds velocity/smoothTransition and renames move_flag.
-- ---------------------------------------------------------------------
DELETE FROM acore_world.waypoint_data WHERE id=39436;
INSERT INTO acore_world.waypoint_data (`id`,`point`,`position_x`,`position_y`,`position_z`,`orientation`,`velocity`,`delay`,`smoothTransition`,`move_type`,`action`,`action_chance`,`wpguid`)
SELECT id, point, position_x, position_y, position_z, NULLIF(orientation,0), 0, delay, 0, move_flag, action, action_chance, 0
FROM nelt_world.waypoint_data WHERE id=39436;

-- ---------------------------------------------------------------------
-- 3. Escort waypoints: AC's npc_escortAI loads script_waypoint by ENTRY.
--    nelt kept escort paths in `waypoints` (only Nordrala 53355 (14 pts) and
--    Keeper Taldros 52965 (4 pts) exist there). Anren 52904, Voramus 53217,
--    Turak 52964 and Deldren 52953 have NO path in any source DB -- their
--    escorts stay paused until paths are authored (tracked in 00_README).
-- ---------------------------------------------------------------------
DELETE FROM acore_world.script_waypoint WHERE entry IN (3653355, 3652965);
INSERT INTO acore_world.script_waypoint (`entry`,`pointid`,`location_x`,`location_y`,`location_z`,`waittime`,`point_comment`)
SELECT entry+@OFF, pointid, position_x, position_y, position_z, 0, point_comment
FROM nelt_world.waypoints WHERE entry IN (53355, 52965);

-- ---------------------------------------------------------------------
-- 4. creature_text for talkers that were already live before the 29
--    extension (their texts are Neltharion custom content; the cata TDB
--    clone in 07_creature_text.sql could not provide them).
-- ---------------------------------------------------------------------
INSERT IGNORE INTO acore_world.creature_text (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, comment
FROM nelt_world.creature_text
WHERE entry IN (40816, 40185, 40460, 41557, 52904, 40140, 40427, 40780, 40934, 39858, 40409, 40412);

-- ---------------------------------------------------------------------
-- 5. Already-applied 41_spell_dbc rows: summon effects still point at RAW
--    Neltharion entries (same bug class as the proveditor Creature::Create
--    spam). Remap to the +3,600,000 clones. Idempotent (guarded by old value).
-- ---------------------------------------------------------------------
UPDATE acore_world.spell_dbc SET EffectMiscValue_1=3802652 WHERE ID=73959 AND EffectMiscValue_1=202652; -- Summon Twilight Supplies (GO)
UPDATE acore_world.spell_dbc SET EffectMiscValue_2=3639601 WHERE ID=73984 AND EffectMiscValue_2=39601;  -- Mental Training -> Orb of Ascension
UPDATE acore_world.spell_dbc SET EffectMiscValue_1=3639622 WHERE ID=74077 AND EffectMiscValue_1=39622;  -- Summon Spirit of Lo'Gosh
UPDATE acore_world.spell_dbc SET EffectMiscValue_1=3639627 WHERE ID=74078 AND EffectMiscValue_1=39627;  -- Summon Spirit of Goldrinn
UPDATE acore_world.spell_dbc SET EffectMiscValue_1=3640434 WHERE ID=75397 AND EffectMiscValue_1=40434;  -- Agility Training -> Blazing Trainer
UPDATE acore_world.spell_dbc SET EffectMiscValue_1=3653083 WHERE ID=98151 AND EffectMiscValue_1=53083;  -- Summon Wisp
UPDATE acore_world.spell_dbc SET EffectMiscValue_1=3653092 WHERE ID=98183 AND EffectMiscValue_1=53092;  -- Summon Firekin

-- ---------------------------------------------------------------------
-- 6. Graduation Speech: spawn the hand-authored controller (3675196) at the
--    Initiation Podium (GO 3802996 @ 4742.51,-4971.33,907.419) and remove the
--    duplicated cata-layer podium GO (the nelt layer re-placed it; guid
--    9735668 is the stale cata copy, 12612851 is the nelt one).
-- ---------------------------------------------------------------------
DELETE FROM acore_world.creature WHERE guid=12960001;
INSERT INTO acore_world.creature (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`) VALUES
(12960001,3675196,750,4923,4923,1,1,-1,4742.51,-4971.33,907.419,4.71239,300,0,0,5342,0,0,0,0,0,'',0,0,'Hyjal-DC graduation controller');
DELETE FROM acore_world.gameobject WHERE guid=9735668 AND id=3802996;
