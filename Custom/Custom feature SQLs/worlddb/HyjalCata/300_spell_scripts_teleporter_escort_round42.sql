-- ---------------------------------------------------------------------------
-- 300  Round 42 -- the 6 spell-script mismatches, the SFK teleporter, one escort
-- ---------------------------------------------------------------------------
-- Clears the last two classes of line in the boot log. Every one turned out to
-- be a real broken mechanic rather than log noise -- a handler that "won't be
-- executed" is a boss ability that silently never fires.
--
-- THE SIX SCRIPT MISMATCHES SPLIT CLEANLY IN TWO, and which side is wrong was
-- settled against the source data every time, never by preference:
--   * 93572, 105552, 326824 -- our spell_dbc row is FAITHFUL, the script binds
--     the wrong effect. Fixed in C++ (see section 6; needs a rebuild).
--   * 329181, 329725 -- the script is right, our downported row cannot support
--     it. Fixed here in SQL.
--   * 343995 -- neither: retail agrees the spell is a self-cast, so the hook
--     could never have fired. Retired in C++ with the reasoning recorded.
--
-- Sources used: the Cata 4.3.4 client SpellEffect.dbc (k:/tmp/cata-dbc, 97,927
-- rows; effects live there, NOT in Spell.dbc, from 4.x on -- column 24 is the
-- SpellID and column 25 the effect index) and retailextracts/_spell_sl/
-- SpellEffect.csv for the Shadowlands ids.
--
-- ---------------------------------------------------------------------------
-- 1) spell_dbc -- 329725 Expunge, the aura that was not an aura
-- ---------------------------------------------------------------------------
--     Spell `329725` Effect `Index: EFFECT_0 AuraName: SPELL_AURA_ANY` of script
--     `aura_expunge` did not match dbc effect data
--
-- SPELL_AURA_ANY matching nothing looks impossible, and that is the tell.
-- SpellInfo.cpp:365 -- `IsAura()` returns `(IsUnitOwnedAuraEffect() || ...) &&
-- ApplyAuraName != 0`. Our row has Effect_1 = 6 (APPLY_AURA) but EffectAura_1 =
-- **0**, so it is an aura-applying effect that applies no aura, and even the
-- wildcard cannot bind to it.
--
-- Retail says the aura is **395**, and copying that verbatim would BRICK THE
-- SERVER: TOTAL_AURAS is 317 (SpellAuraDefines.h:380), AuraEffectHandler is a
-- flat array of that size, and SpellMgr.cpp:3041 asserts
-- `ApplyAuraName < TOTAL_AURAS` at load. Same class of trap as the effect-id
-- >= 165 boot crash. SL aura 395 (AREA_TRIGGER) has no 3.3.5 equivalent at all.
--
-- So EFFECT_0 gets SPELL_AURA_DUMMY (4). The script chose SPELL_AURA_ANY
-- precisely so the downport could pick any 3.3.5 type -- its own comment says so
-- -- and DUMMY does nothing on its own, which is right for an aura whose only
-- job is to spawn an Obliterating Rift on heroic when it expires. That mechanic
-- has never worked; this is what turns it on.
UPDATE acore_world.`spell_dbc` SET `EffectAura_1` = 4
 WHERE `ID` = 329725 AND `Effect_1` = 6 AND `EffectAura_1` = 0;

-- ---------------------------------------------------------------------------
-- 2) spell_dbc -- 329181 Wracking Pain, an area cleave with no area
-- ---------------------------------------------------------------------------
--     Spell `329181` Effect `Index: EFFECT_0 Target: 15` of script
--     `spell_wracking_pain` did not match dbc effect data
--
-- The downport kept Shadowlands' targets verbatim: ImplicitTargetA 25 with
-- TargetB 130 on EFFECT_0. 3.3.5 has no target 130, and 25 alone selects a
-- single unit, so `OnObjectAreaTargetSelect` had no target LIST to filter and
-- Denathrius' cleave has been hitting one target instead of the raid.
--
-- Retail expresses the area through TargetB 130 plus **radius index 48**, and
-- that index exists unchanged in our stock SpellRadius.dbc (58 records) as
-- **60 yards**. So the faithful 3.3.5 spelling of the same spell is TargetA 15
-- (TARGET_UNIT_SRC_AREA_ENEMY, SharedDefines.h:1427) with retail's own radius --
-- no invented numbers. The script then filters that list down to players, which
-- is exactly what its comment says it is for.
UPDATE acore_world.`spell_dbc`
   SET `ImplicitTargetA_1` = 15, `EffectRadiusIndex_1` = 48
 WHERE `ID` = 329181 AND `Effect_1` = 2 AND `ImplicitTargetA_1` = 25;

-- ---------------------------------------------------------------------------
-- 3) spell_dbc -- 95303 / 95305, the two missing teleports
-- ---------------------------------------------------------------------------
--     SmartAIMgr: Entry 5051400 SourceType 0 Event 1 Action 11 uses non-existent
--     Spell entry 95303, skipped.        (and Event 2 / 95305)
--
-- Both exist in the Cata client: SpellEffect.dbc gives each a single effect 5
-- (TELEPORT_UNITS) with ImplicitTargetA 25 and **TargetB 17 = TARGET_DEST_DB**,
-- i.e. the destination comes from spell_target_position (section 4).
--
-- Cloned from 95300 "Teleport to Great Hall", which is already downported with
-- the identical effect/target shape. Cloning the whole row rather than listing
-- 232 columns keeps every other field of the fork layout correct and survives
-- schema drift. Names follow 95300's pattern and match the gossip options.
DELETE FROM acore_world.`spell_dbc` WHERE `ID` IN (95303, 95305);
CREATE TEMPORARY TABLE acore_world.`_dc_tp_clone` LIKE acore_world.`spell_dbc`;
INSERT INTO acore_world.`_dc_tp_clone` SELECT * FROM acore_world.`spell_dbc` WHERE `ID` = 95300;
UPDATE acore_world.`_dc_tp_clone` SET `ID` = 95303,
       `Name_Lang_enUS` = 'Teleport to Chapel', `Name_Lang_enGB` = 'Teleport to Chapel';
INSERT INTO acore_world.`spell_dbc` SELECT * FROM acore_world.`_dc_tp_clone`;
UPDATE acore_world.`_dc_tp_clone` SET `ID` = 95305,
       `Name_Lang_enUS` = 'Teleport to Laboratory', `Name_Lang_enGB` = 'Teleport to Laboratory';
INSERT INTO acore_world.`spell_dbc` SELECT * FROM acore_world.`_dc_tp_clone`;
DROP TEMPORARY TABLE acore_world.`_dc_tp_clone`;

-- ---------------------------------------------------------------------------
-- 4) spell_target_position -- where the three teleports actually go
-- ---------------------------------------------------------------------------
-- Investigating the two log lines turned up a feature that is broken at THREE
-- layers, not one. The Haunted Stable Hand (5051400, map 825 = our Shadowfang
-- Keep clone) offers a three-way teleporter, and:
--   * two of its three spells did not exist            -> section 3
--   * NONE of the three had a destination row          -> here
--   * gossip menu 12669 had no options and no text     -> section 5
-- So even option 1, whose spell 95300 was downported long ago, silently did
-- nothing. Fixing only the log lines would have left the NPC just as useless.
--
-- Cata's coordinates transfer unchanged; only MapID moves 33 -> 825. Confirmed
-- by lining the destinations up against our own map-825 spawns -- each teleport
-- lands in its boss's room:
--     95300 Great Hall  (-274.60, 2297.12,  76.15)  ~ Baron Silverlaine  (-265.87, 2293.65,  76.24)
--     95305 Laboratory  (-160.64, 2178.70, 138.70)  ~ Lord Walden        (-145.84, 2164.47, 128.56)
--
-- 🔴 95303 (Chapel) IS DERIVED, NOT COPIED -- the one authored value in this
-- file. cata_world.spell_target_position simply has no row for it (TC's data is
-- incomplete here), so there is nothing to transfer. The gossip option names the
-- destination -- "Can you take me to the Chapel?" -- and the Chapel is Commander
-- Springvale's room, so his spawn point is used verbatim. Chosen because it is
-- the only coordinate on that map provably standable: a boss spawns there. The
-- cost is that it drops you on Springvale's marker rather than at the doorway
-- like the other two. **Worth walking in-game and nudging if it feels wrong** --
-- it is one row, and nothing else depends on it.
DELETE FROM acore_world.`spell_target_position` WHERE `ID` IN (95300, 95303, 95305);
INSERT INTO acore_world.`spell_target_position`
  (`ID`, `EffectIndex`, `MapID`, `PositionX`, `PositionY`, `PositionZ`, `Orientation`, `VerifiedBuild`)
VALUES
(95300, 0, 825, -274.603, 2297.12, 76.1534, 5.89326, 0),
(95303, 0, 825, -227.498, 2257.70, 102.837, 3.40339, 0),
(95305, 0, 825, -160.636, 2178.70, 138.698, 5.89487, 0);

-- ---------------------------------------------------------------------------
-- 5) gossip_menu / gossip_menu_option -- making the teleporter reachable
-- ---------------------------------------------------------------------------
-- creature_template 5051400 already points at gossip_menu_id 12669 and carries
-- npcflag 1 (GOSSIP), but `gossip_menu` had no row for 12669 and
-- `gossip_menu_option` had none either -- so the three SmartAI "on gossip option
-- selected" events could never fire, because there were no options to select.
--
-- npc_text 17815 is ALREADY in our DB with the correct line ("Go away! You
-- shouldn't be here!"), imported earlier and never linked -- checked rather than
-- assumed, after 296_ where a cata npc_text turned out to be the placeholder
-- string "Missing npc_text". Only the menu -> text link is missing.
--
-- Cata's option 3 is deliberately DROPPED: it is a duplicate "Can you take me to
-- the Laboratory?" with OptionType 0 and no npcflag, a data artefact with no
-- SmartAI event behind it. Importing it would show players a dead fourth entry.
DELETE FROM acore_world.`gossip_menu` WHERE `MenuID` = 12669;
INSERT INTO acore_world.`gossip_menu` (`MenuID`, `TextID`) VALUES (12669, 17815);

DELETE FROM acore_world.`gossip_menu_option` WHERE `MenuID` = 12669;
INSERT INTO acore_world.`gossip_menu_option`
  (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`)
VALUES
(12669, 0, 0, 'Can you take me to the Great Hall?', 0, 1, 1),
(12669, 1, 0, 'Can you take me to the Chapel?', 0, 1, 1),
(12669, 2, 0, 'Can you take me to the Laboratory?', 0, 1, 1);

-- ---------------------------------------------------------------------------
-- 6) waypoint_data -- Anchorite Truuen's escort
-- ---------------------------------------------------------------------------
--     SmartAIMgr: Creature 17238 Event 1 Action 53 uses non-existent
--     WaypointPath id 17238, skipped.
--
-- This is a broken quest, not a stray log line: the WP_START carries quest 9446
-- "Tomb of the Lightbringer", which exists, so the escort has simply never been
-- walkable.
--
-- Neither cata_world nor our own tables have the path, but
-- **nelt_world.script_waypoint does** -- 26 points, MaNGOS-side. Confirmed as
-- the right path before converting: point 1 (953.06, -1432.52, 63.23) sits 9.5
-- yards from our spawn of 17238 (944.46, -1428.37, 64.61) on the same map, and
-- the route runs south-west to Uther's Tomb, which is where quest 9446 goes.
--
-- Points 23-26 repeat one coordinate with waittime 5000 -- the MaNGOS idiom for
-- a 20-second hold at the destination. Kept as four points rather than collapsed
-- into one 20,000 ms delay, so the path stays a faithful copy.
-- move_type is left 0: SmartAI action 53 param1 = 1 already makes him run, which
-- is the AzerothCore convention. orientation NULL = face the direction of travel.
DELETE FROM acore_world.`waypoint_data` WHERE `id` = 17238;
INSERT INTO acore_world.`waypoint_data`
  (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `velocity`,
   `delay`, `smoothTransition`, `move_type`, `action`, `action_chance`, `wpguid`)
VALUES
(17238, 1, 953.061, -1432.52, 63.225, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 2, 969.607, -1438.15, 65.367, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 3, 980.073, -1441.5, 65.4, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 4, 995.001, -1450.47, 61.323, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 5, 1032.7, -1473.49, 63.77, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 6, 1039.69, -1491.42, 65.28, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 7, 1038.8, -1523.32, 64.466, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 8, 1035.43, -1572.97, 61.541, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 9, 1034.45, -1612.83, 61.619, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 10, 1040.12, -1663.41, 60.923, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 11, 1059.75, -1703.75, 60.577, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 12, 1091.83, -1735.24, 60.806, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 13, 1131.75, -1755.32, 61.007, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 14, 1159.77, -1762.64, 60.57, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 15, 1153.79, -1772.0, 60.647, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 16, 1115.4, -1787.21, 61.076, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 17, 1091.88, -1799.06, 61.605, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 18, 1056.22, -1805.65, 71.811, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 19, 1024.03, -1807.93, 77.025, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 20, 1012.74, -1811.67, 77.564, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 21, 1006.74, -1813.59, 80.487, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 22, 983.15, -1823.05, 80.487, NULL, 0, 0, 0, 0, 0, 100, 0),
(17238, 23, 974.954, -1825.33, 81.348, NULL, 0, 5000, 0, 0, 0, 100, 0),
(17238, 24, 974.954, -1825.33, 81.348, NULL, 0, 5000, 0, 0, 0, 100, 0),
(17238, 25, 974.954, -1825.33, 81.348, NULL, 0, 5000, 0, 0, 0, 100, 0),
(17238, 26, 974.954, -1825.33, 81.348, NULL, 0, 5000, 0, 0, 0, 100, 0);

-- ---------------------------------------------------------------------------
-- 7) The C++ half -- THREE ONE-LINE FIXES AND ONE RETIREMENT (NEEDS A REBUILD)
-- ---------------------------------------------------------------------------
-- No SQL for these; recorded here so the round is reviewable in one place. Each
-- was decided by reading the source data, not the script.
--
-- 93572 Toxic Coagulant -- DC/ShadowfangKeepCata/boss_lord_walden.cpp
--   Cata: idx0 = APPLY_AURA / PERIODIC_TRIGGER_SPELL (period 3000, trigger
--   93617), idx1 = effect 64 with NO aura. Our row copies that exactly. The
--   script bound EFFECT_1 + PERIODIC_DAMAGE, which cannot exist on this spell.
--     EFFECT_1, SPELL_AURA_PERIODIC_DAMAGE -> EFFECT_0, SPELL_AURA_PERIODIC_TRIGGER_SPELL
--   The handler only reads the stack count, so the effect is just an attach
--   point -- but until now Walden's stacking DoT never converted to Fully
--   Coagulated.
--
-- 105552 DK T13 blood 2-piece -- DC/ItemSets/dc_cata_itemset_bonuses.cpp
--   Cata: idx0 = APPLY_AURA / PROC_TRIGGER_SPELL (42), triggering 105582. Our
--   row is faithful. The script bound SPELL_AURA_DUMMY, so the Kiss of Death
--   proc has never fired for anyone wearing the set.
--     SPELL_AURA_DUMMY -> SPELL_AURA_PROC_TRIGGER_SPELL
--
-- 326824 Painful Memories -- DC/CastleNathria/boss_sire_denathrius.cpp
--   Retail: one effect, APPLY_AURA / DUMMY on EFFECT_0, carrying
--   EffectTriggerSpell 326833 rather than a periodic aura. Our row is faithful.
--     SPELL_AURA_PERIODIC_TRIGGER_SPELL -> SPELL_AURA_DUMMY
--   DUMMY also describes what the handler does: one cast on apply, not a tick.
--
-- 343995 Blood Shroud -- DC/CastleNathria/boss_shriekwing.cpp  (RETIRED)
--   The odd one out: BOTH sides were right and the binding was still impossible.
--   Shriekwing self-casts it (`CastSpell(me, ...)`) and retail agrees -- both
--   effects are APPLY_AURA on ImplicitTarget 1 (caster), radius index 0. There
--   is no area target list for OnObjectAreaTargetSelect to filter, so the hook
--   was dead on arrival. The LOS/pillar mechanic it belongs to is driven by an
--   AreaTrigger in the source, which 3.3.5 has no equivalent for (the file
--   already TODOs that port). The registration is removed and FilterTargets kept
--   as the ready-made predicate for whoever ports it. An empty Register() is
--   silent -- SpellScript::_Validate only walks hooks that were registered.
--   Deliberately NOT "fixed" by giving the boss's self-buff a 60y area target:
--   that would invent a mechanic rather than downport one.
--
-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT EffectAura_1 FROM spell_dbc WHERE ID = 329725;                 -> 4
--  2  SELECT ImplicitTargetA_1, EffectRadiusIndex_1 FROM spell_dbc
--      WHERE ID = 329181;                                              -> 15, 48
--  3  SELECT COUNT(*) FROM spell_dbc WHERE ID IN (95303, 95305);            -> 2
--     SELECT ID, Name_Lang_enUS FROM spell_dbc WHERE ID IN (95300,95303,95305);
--        -> Great Hall / Chapel / Laboratory
--  4  SELECT COUNT(*) FROM spell_target_position
--      WHERE ID IN (95300,95303,95305) AND MapID = 825;                     -> 3
--  5  SELECT COUNT(*) FROM gossip_menu_option WHERE MenuID = 12669;         -> 3
--  6  SELECT COUNT(*) FROM waypoint_data WHERE id = 17238;                 -> 26
--  7  The four boot lines for 329181 / 329725 and the two SmartAI spells go on
--     the next restart. The other four (93572, 105552, 326824, 343995) need the
--     worldserver REBUILT -- they are C++ only.
--
--  In game: the Haunted Stable Hand should greet you and offer three working
--  teleports, and Anchorite Truuen should walk quest 9446 to Uther's Tomb.
--
-- ---------------------------------------------------------------------------
-- Still open
-- ---------------------------------------------------------------------------
-- * Creature 16256 "Jessica Chambers" WaypointPath 16256 -- the one line here
--   with NO source anywhere: absent from cata_world, from nelt_world's
--   script_waypoint / waypoint_data / waypoints, and from our own tables. Her
--   WP_START is not quest-gated (action_param4 = 0), so unlike Truuen nothing
--   measurable is broken by leaving it. Writing a path would be inventing one.
-- * 95303's Chapel coordinate is derived (see section 4) -- worth an in-game
--   sanity walk.
-- * 343995's LOS mechanic waits on the AreaTrigger port.
-- * The stock loot-chance overflows, the pickpocket/skinning/reference orphans,
--   the 8 unassigned scripts and OutdoorPvP type 8 remain triaged as
--   not-DB-fixes.
