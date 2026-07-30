-- =====================================================================
-- Molten Front -- 16  DEEP CAMPAIGN LAYER (the un-cloned phase set)
-- ---------------------------------------------------------------------
-- WHY: 01_/02_ cloned map 861 from source phaseMask IN (1,2047,8,16,128).
-- The Molten Front's campaign-UNLOCK layer lives in the *other* phases --
-- 512 (the "Lieutenant of Flame" rare camp), 16384 (the Leyara finale),
-- 14/160/77 (the daily questgivers) and 32 (the Hyjal-side Behemoth/rare
-- credit-granters, which are on map 1, not 861). None of it was ever
-- ported, which is why the MF audit found 13 quests with no questgiver
-- and no kill-credit source.
--
-- This file clones that layer: 24 creature templates + 1 gameobject,
-- dc_entry = source + 3,600,000 (GO 208535 -> 3808535), plus their
-- displays, equipment, addons, loot, spawns and quest relations.
-- Conventions inherited verbatim from 01_/02_/13_ (column map, RAW lootid,
-- phaseMask forced to 1, zone/area 4925 on map 861).
--
-- ENTITIES (source -> clone)
--   questgivers / campaign NPCs
--     53073 Captain Soren Moonfall  -> 3653073   starts 29128
--     52490 Skylord Omnuron         -> 3652490   ends  29182 + 29305
--     52495 Shalis Darkhunter       -> 3652495   starts 29243, ends 29244
--     53056 Shalis Darkhunter (var) -> 3653056   starts 29243 (2nd phase copy)
--     53196 Ricket                  -> 3653196   starts 29263 + 29278
--     54163 Ricket (var)            -> 3654163   starts 29297
--   "Lieutenant of Flame" rare camp (phase 512, all five share one spot)
--     53055 Ancient Charscale             -> 3653055
--     53759 Cinderweb Queen               -> 3653759
--     53771 Ancient Smoldering Behemoth   -> 3653771
--     53834 Devout Harbinger              -> 3653834
--     53864 Ancient Firelord              -> 3653864
--   Hyjal-side rares / credit granters (source map 1, phase 32)
--     52289 Fiery Behemoth  -> 3652289 (12 spawns)
--     53264 Searris         -> 3653264
--     53265 Kelbnar         -> 3653265
--     53267 Andrazor        -> 3653267
--     53271 Fah Jarakk      -> 3653271
--   credit proxies / objective targets (template only, no spawns)
--     53370 Foothold Kill Credit -> 3653370   objective of 29201
--     40660 Twilight Lancer      -> 3640660   objective of 29177
--   finale (the Leyara encounter, complete)
--     53366 Leyara                       -> 3653366  (spawn + text + full SmartAI)
--     53912 Malfurion Stormrage          -> 3653912  (summoned actor)
--     53913 Arch Druid Hamuul Runetotem  -> 3653913  (summoned actor)
--     54109 Arch Druid Hamuul (2nd copy) -> 3654109  (summoned by 53913's script)
--     54110 Malfurion Stormrage (2nd)    -> 3654110  (summoned by 53912's script)
--     75193 Wondi's Bunny - Into the Depths - Event Starter -> 3675193 (spawned)
--   gameobject
--     208535 "Dried Acorn" -> 3808535   starts 29245
--
-- DISPLAY SUBSTITUTIONS (rule from 11_: never emit a display absent from
-- the client CreatureDisplayInfo.csv, and never ship a Cata CHARACTER
-- display that depends on a CreatureDisplayInfoExtra bake -- those render
-- as untextured WHITE models here).
--     3653073  38141 -> 11774  Moonglade Warden (NE male officer).  38141 IS
--                              in the CSV but is a stock NE-male model whose
--                              ExtendedDisplayInfoID 25207 is a Cata CDIExtra
--                              row the client cannot bake -> white model.
--                              Same call, same replacement pool as 11_.
--     3653055  38140 -> 17343  Druid of the Talon.  38140 is ABSENT from the
--                              client CSV; no MF equivalent exists for a
--                              flame-humanoid melee.  APPROXIMATION, flagged.
--     3653759  38477 -> 38483  Cinderweb Matriarch (already shipped for the
--                              861 spider bosses).  38477 absent from CSV.
--     3653771  38852 -> 38851  Molten Behemoth (already shipped, scale 1.1).
--                              38852 absent from CSV.
--     3653834  38504 -> 17343  Druid of the Talon.  38504 absent from CSV.
--                              APPROXIMATION, flagged.
--     3653913  38564 -> 31605  stock Tauren-druid display.  38564 is absent from
--     3654109                  the client CSV; 31605 is what every live Hamuul
--                              clone already uses (3639858 / 3640805 / 3652838),
--                              so this matches the map's existing look.
-- 35095 (Malfurion, 3653912 + 3654110) kept -- present in the CSV and already
-- live on 3639857 / 3641632 / 3652135 / 3652845.
-- Kept as-is (verified present in Custom/CSV DBC/CreatureDisplayInfo.csv and
-- already in live use on other clones): 32245 (Omnuron, on 3640997),
-- 38088 (Shalis, on 3652494), 38062 (Leyara, on raw 53014), 26243 (Ricket,
-- stock), 31966 (Twilight Lancer, on live 40660), 16480+21342 (credit proxy),
-- 38673 (Fiery Behemoth), 38255/38258/38012/38674 (the four Lords),
-- 38591 (Ancient Firelord, on 3654252 Ragepyre).
--
-- SPELLS -- **19_mf_deep_layer_spells.sql IS A HARD PREREQUISITE** (apply_all
-- runs it first).  Its 33 spell_dbc rows cover EVERY spell this file
-- references: the 24 combat spells this layer casts, the 8 they trigger through
-- EffectTriggerSpell, and the benign addon aura 76651 --
--     75934 88734 93402 96633 96652 96889 97721 98314 98705 99994 99996 99998
--     100041 100154 100229 100267 100378 100658 100659 100660 100804 100854
--     101633 79870 | 80550 99995 100040 97246 100264 98002 100855 100262 | 76651
-- (the trigger graph's remaining leaves, 45334 and 50286, are stock ids that
-- already resolve client-side).  Every SmartAI row that was withheld in the
-- earlier cuts of this file is therefore shipped, and 76651 is restored on the
-- Fiery Behemoth's addon.
--
-- EXACTLY ONE id is deliberately kept OUT, and must stay out forever:
--   * 84886 -- Cata "Generic Quest Invisibility 9", same family as 87872 /
--     94223 / 80797.  Porting it would make Shalis Darkhunter (3653056)
--     invisible to every player.  It is stripped from her addon and filtered
--     out of creature_template_spell and the SmartAI port below.
-- No other quest-invisibility aura appears anywhere in this layer -- verified.
--
-- VEHICLES: every cloned template has VehicleId = 0.  Nothing to guard.
-- SPELLCLICK: no cloned template carries the SPELLCLICK npcflag and none has
-- npc_spellclick_spells rows in either source -- nothing to port.
--
-- GUID BANDS (all verified empty before writing)
--     creature   15,350,001+   map 861 deep-layer spawns (9, source coords)
--     creature   15,350,101+   map 861 DC-PLACED questgivers (2 Rickets)
--     creature   15,820,001+   map 750 Hyjal-side rares (17, source coords)
--     gameobject 15,220,001+   map 861 GO spawn (1)
--     pool       133,000,001   "Lieutenant of Flame" rare rotation
--
-- Idempotent (delete-then-insert on every block). Needs a worldserver restart.
-- Run AFTER 13_mf_base_phase_backfill.sql AND AFTER 19_mf_deep_layer_spells.sql.
-- =====================================================================
SET @OFF := 3600000;

-- =========================== CREATURE TEMPLATES ======================
-- Column map = 01_/HyjalCata-29 (faction_A->faction, dmg_multiplier->
-- DamageModifier, Health_mod/Mana_mod/Armor_mod->*Modifier, speed_fly->
-- speed_flight, LEAST(exp,2)).  AIName is copied verbatim from the source and
-- that is now CORRECT for every entry: with 19_ applied, all thirteen clones
-- that carry AIName='SmartAI' (52289, 53055, 53271, 53366, 53759, 53771,
-- 53834, 53864, 53912, 53913, 54109, 54110, 75193) get their full row set
-- below, and the other eleven carry AIName='' in the source.  A template that
-- claims SmartAI with zero rows logs "has SmartAI enabled but no SmartAI
-- entries" on every boot -- verified that no such mismatch remains.
DELETE FROM acore_world.`creature_template` WHERE `entry` IN (3640660,3652289,3652490,3652495,3653055,3653056,3653073,3653196,3653264,3653265,3653267,3653271,3653366,3653370,3653759,3653771,3653834,3653864,3653912,3653913,3654109,3654110,3654163,3675193);

INSERT INTO acore_world.`creature_template`
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT entry+@OFF, IF(KillCredit1>0,KillCredit1+@OFF,0), IF(KillCredit2>0,KillCredit2+@OFF,0), name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, lootid, pickpocketloot, skinloot, PetSpellDataId, VehicleId, mingold, maxgold,
       AIName,
       MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193);

-- ---- display models (one row per non-zero modelid slot) ----
DELETE FROM acore_world.`creature_template_model` WHERE `CreatureID` IN (3640660,3652289,3652490,3652495,3653055,3653056,3653073,3653196,3653264,3653265,3653267,3653271,3653366,3653370,3653759,3653771,3653834,3653864,3653912,3653913,3654109,3654110,3654163,3675193);

INSERT INTO acore_world.`creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT entry+@OFF, idx, mid, scale, 1, 0 FROM (
  SELECT entry, 0 idx, modelid1 mid, scale FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND modelid1>0
  UNION ALL SELECT entry, 1, modelid2, scale FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND modelid2>0
  UNION ALL SELECT entry, 2, modelid3, scale FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND modelid3>0
  UNION ALL SELECT entry, 3, modelid4, scale FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND modelid4>0
) m;

-- ---- display substitutions (see header). Scoped to this file's clones. ----
UPDATE acore_world.`creature_template_model` SET `CreatureDisplayID` = 11774 WHERE `CreatureID` = 3653073 AND `CreatureDisplayID` = 38141;
UPDATE acore_world.`creature_template_model` SET `CreatureDisplayID` = 17343 WHERE `CreatureID` = 3653055 AND `CreatureDisplayID` = 38140;
UPDATE acore_world.`creature_template_model` SET `CreatureDisplayID` = 38483 WHERE `CreatureID` = 3653759 AND `CreatureDisplayID` = 38477;
UPDATE acore_world.`creature_template_model` SET `CreatureDisplayID` = 38851 WHERE `CreatureID` = 3653771 AND `CreatureDisplayID` = 38852;
UPDATE acore_world.`creature_template_model` SET `CreatureDisplayID` = 17343 WHERE `CreatureID` = 3653834 AND `CreatureDisplayID` = 38504;
UPDATE acore_world.`creature_template_model` SET `CreatureDisplayID` = 31605 WHERE `CreatureID` IN (3653913,3654109) AND `CreatureDisplayID` = 38564;

-- ---- movement (flight capability from InhabitType, as 01_) ----
DELETE FROM acore_world.`creature_template_movement` WHERE `CreatureId` IN (3640660,3652289,3652490,3652495,3653055,3653056,3653073,3653196,3653264,3653265,3653267,3653271,3653366,3653370,3653759,3653771,3653834,3653864,3653912,3653913,3654109,3654110,3654163,3675193);

INSERT INTO acore_world.`creature_template_movement` (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`)
SELECT entry+@OFF, 1, (InhabitType&2)>0, 1, 0, 0, 0, 0
FROM nelt_world.creature_template
WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193)
  AND (InhabitType&4)>0;

-- ---- template spells (inline spell1-8 -> creature_template_spell) ----
-- With 19_ applied every referenced spell exists, so the only filter left is
-- 84886 (quest invisibility -- must never ship).
DELETE FROM acore_world.`creature_template_spell` WHERE `CreatureID` IN (3640660,3652289,3652490,3652495,3653055,3653056,3653073,3653196,3653264,3653265,3653267,3653271,3653366,3653370,3653759,3653771,3653834,3653864,3653912,3653913,3654109,3654110,3654163,3675193);

INSERT INTO acore_world.`creature_template_spell` (`CreatureID`,`Index`,`Spell`,`VerifiedBuild`)
SELECT entry+@OFF, idx, sp, 0 FROM (
  SELECT entry, 0 idx, spell1 sp FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell1>0
  UNION ALL SELECT entry, 1, spell2 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell2>0
  UNION ALL SELECT entry, 2, spell3 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell3>0
  UNION ALL SELECT entry, 3, spell4 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell4>0
  UNION ALL SELECT entry, 4, spell5 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell5>0
  UNION ALL SELECT entry, 5, spell6 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell6>0
  UNION ALL SELECT entry, 6, spell7 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell7>0
  UNION ALL SELECT entry, 7, spell8 FROM nelt_world.creature_template WHERE entry IN (40660,52289,52490,52495,53055,53056,53073,53196,53264,53265,53267,53271,53366,53370,53759,53771,53834,53864,53912,53913,54109,54110,54163,75193) AND spell8>0
) s
WHERE sp NOT IN (84886);

-- ---- creature_template_addon ----
-- 52289's aura 76651 is RESTORED (19_ ships it).  53056's aura 84886 stays
-- stripped forever: it is "Generic Quest Invisibility 9" and would hide Shalis
-- Darkhunter from every player.
DELETE FROM acore_world.`creature_template_addon` WHERE `entry` IN (3640660,3652289,3652490,3652495,3653056,3653073,3653196,3653264,3653265,3653267,3653271,3653366,3653864,3653912,3653913);

INSERT INTO acore_world.`creature_template_addon` (`entry`,`path_id`,`mount`,`bytes1`,`bytes2`,`emote`,`visibilityDistanceType`,`auras`) VALUES
(3640660, 0, 0,        0, 1,   0, 0, ''),
(3652289, 0, 0,        0, 1,   0, 0, '76651'),
(3653912, 0, 0,        0, 1,   0, 0, ''),
(3653913, 0, 0,        0, 1,   0, 0, ''),
(3652490, 0, 0,    65536, 1,   0, 0, ''),
(3652495, 0, 0,    65536, 1,   0, 0, ''),
(3653056, 0, 0,    65544, 1,   0, 0, ''),
(3653073, 0, 0,    65536, 1,   0, 0, ''),
(3653196, 0, 0,    65536, 1,   0, 0, ''),
(3653264, 0, 0,        0, 1,   0, 0, ''),
(3653265, 0, 0,        0, 1,   0, 0, ''),
(3653267, 0, 0, 50331648, 1,   0, 0, ''),
(3653271, 0, 0,        0, 1,   0, 0, ''),
(3653366, 0, 0,        0, 1, 333, 0, ''),
(3653864, 0, 0,        0, 1,   0, 0, '');

-- ---- creature_equip_template ----
-- Source keys equipment by a shared template id; this fork keys it per
-- creature (CreatureID + ID).  Every ItemID below was verified present in
-- acore_world.item_template.  Spawns use equipment_id = -1, which picks ID 1.
DELETE FROM acore_world.`creature_equip_template` WHERE `CreatureID` IN (3640660,3652490,3652495,3653055,3653056,3653073,3653366,3653913,3654109);

INSERT INTO acore_world.`creature_equip_template` (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`) VALUES
(3640660, 1, 52716,    0,    0, 0),
(3652490, 1, 13339,    0,    0, 0),
(3652495, 1, 14887,    0,    0, 0),
(3653055, 1, 49353,    0, 5870, 0),
(3653056, 1, 14887,    0,    0, 0),
(3653073, 1, 34883,    0,    0, 0),
(3653366, 1, 69756,    0,    0, 0),
(3653913, 1, 63052,    0,    0, 0),
(3654109, 1, 63052,    0,    0, 0);

-- ---- creature_text (the Leyara encounter's dialogue: 21 lines) ----
-- 53366 Leyara 11 | 53912 Malfurion 3 | 53913 Hamuul 4 | 54109 Hamuul-2 2 |
-- 54110 Malfurion-2 1.  TEXT_OVER is not used by any of these scripts and every
-- TALK action either targets SELF or a target type (19) that SmartAIMgr skips
-- text validation for, so no dummy group is needed here (unlike HyjalCata/144_).
DELETE FROM acore_world.`creature_text` WHERE `CreatureID` IN (3653366,3653912,3653913,3654109,3654110);

INSERT INTO acore_world.`creature_text` (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT entry+@OFF, groupid, id, text, type, language, probability, emote, duration, sound, BroadcastTextID, text_range, 'MoltenFront-DeepLayer'
FROM nelt_world.creature_text WHERE entry IN (53366,53912,53913,54109,54110);

-- =========================== SMARTAI ==================================
-- Full port of every entry script in this layer plus their timed action lists,
-- with the +3,600,000 param sweep applied.  With 19_ applied the whole set
-- ships: 139 rows over 30 script sets.  The only guard left at the bottom of
-- the statement keeps the quest-invisibility aura 84886 out.
--
-- PARAM SWEEP (what is rewritten and what is deliberately NOT)
--   entryorguid   source_type 0 -> +@OFF.  source_type 9 list ids stay RAW:
--                 this map numbers its lists SOURCE-entry x 100 (live 861 uses
--                 5253100 / 5296500 / 5308300-style), and 17_ kept 5280400/01
--                 the same way.  action 80 param1 (the list reference) is
--                 therefore NOT offset either.
--   action 12/50 param1 (summon creature)     -> +@OFF  (53911/53912/53913/
--                                                        54109/54110)
--   action 33    param1 (kill credit)         -> +@OFF  (53366).  EXCEPTION,
--                 per 17_: KillCredit 52816 "Charred Invader" MUST STAY RAW --
--                 four live dailies (29123/29127/29149/29163) name the raw id
--                 and 3652816 does not exist.  Guarded below even though no row
--                 in this set currently uses it.
--   action 86    param4 (cross-cast target)   -> +@OFF only when param3 is a
--                 creature target type (9/10/11/19)  (53912)
--   target_param1 for target_type 9/11/19     -> +@OFF  (53366/53911/53912/
--                                                        53913/75193)
--                 target_type 10 (CREATURE_GUID) is left alone -- verified zero
--                 such rows in this set, and a guid would need a spawn map.
--   action 53    param2 (waypoint path id)    -> NOT offset; the paths are
--                 ported below under their RAW ids (verified free live).
--   action 11/86 param1 (spell)               -> never offset.
DELETE FROM acore_world.`smart_scripts` WHERE `source_type` = 0 AND `entryorguid` IN (3652289,3653055,3653271,3653366,3653759,3653771,3653834,3653864,3653912,3653913,3654109,3654110,3675193);
DELETE FROM acore_world.`smart_scripts` WHERE `source_type` = 9 AND `entryorguid` IN (5336600,5336601,5336602,5336603,5336604,5336605,5336606,5336607,5336608,5391200,5391201,5391202,5391300,5391301,5391302,5410900,5411000,5411001);

INSERT INTO acore_world.`smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`)
SELECT
  IF(s.source_type = 0, s.entryorguid + @OFF, s.entryorguid),
  s.source_type, s.id, s.link, s.event_type, s.event_phase_mask, s.event_chance, s.event_flags,
  s.event_param1, s.event_param2, s.event_param3, s.event_param4,
  s.action_type,
  CASE WHEN s.action_type IN (12,50) AND s.action_param1 BETWEEN 1 AND 200000 THEN s.action_param1 + @OFF
       WHEN s.action_type = 33 AND s.action_param1 = 52816 THEN 52816
       WHEN s.action_type = 33 AND s.action_param1 BETWEEN 1 AND 200000 THEN s.action_param1 + @OFF
       ELSE s.action_param1 END,
  s.action_param2, s.action_param3,
  CASE WHEN s.action_type = 86 AND s.action_param3 IN (9,10,11,19) AND s.action_param4 BETWEEN 1 AND 200000 THEN s.action_param4 + @OFF
       ELSE s.action_param4 END,
  s.action_param5, s.action_param6,
  s.target_type,
  CASE WHEN s.target_type IN (9,11,19) AND s.target_param1 BETWEEN 1 AND 200000 THEN s.target_param1 + @OFF
       ELSE s.target_param1 END,
  s.target_param2, s.target_x, s.target_y, s.target_z, s.target_o,
  CONCAT('MF deep layer - ', COALESCE(NULLIF(s.comment,''), CONCAT('src ', s.entryorguid, '.', s.id)))
FROM nelt_world.smart_scripts s
WHERE ((s.source_type = 0 AND s.entryorguid IN (52289,53055,53271,53366,53759,53771,53834,53864,53912,53913,54109,54110,75193))
       OR (s.source_type = 9 AND s.entryorguid IN (5336600,5336601,5336602,5336603,5336604,5336605,5336606,5336607,5336608,5391200,5391201,5391202,5391300,5391301,5391302,5410900,5411000,5411001)))
  AND NOT (s.action_type IN (11,28,75,86) AND s.action_param1 IN (84886))
  AND NOT (s.event_type IN (8,9,23,31,52) AND s.event_param1 IN (84886));

-- The quest-critical part of the above: the five rare Lieutenants each carry a
-- JUST_DIED -> action 33 KilledMonsterCredit row whose raw 54230 "Lieutenant of
-- Flame" is swept to 3654230 -- the RequiredNpcOrGo1 of quests 29243 and 29305
-- ("Strike at the Heart"), which had no credit source at all before this file.

-- ---- waypoint paths used by action 53 (kept under their RAW ids) ----
-- nelt paths 53912 (1 point), 53913 (2), 54109 (1), 54110 (1), 5391201 (11),
-- 5391300 (1).  Verified: none of those six ids exists in acore_world.waypoints,
-- so there is no collision and the action 53 params can stay untouched.  nelt's
-- waypoints table has no orientation/delay columns -> 0 / 0.
-- KNOWN, SOURCE-SIDE: list 5391201 starts path 5391200, which has no rows in
-- nelt_world.waypoints either -- the path is dangling in the source too.  That
-- is a runtime "invalid path" warning on one movement step, not a load error,
-- and inventing points for it would be fabrication.
DELETE FROM acore_world.`waypoints` WHERE `entry` IN (53912,53913,54109,54110,5391201,5391300);

INSERT INTO acore_world.`waypoints` (`entry`,`pointid`,`position_x`,`position_y`,`position_z`,`orientation`,`delay`,`point_comment`)
SELECT w.entry, w.pointid, w.position_x, w.position_y, w.position_z, 0, 0, 'MF deep layer - Leyara encounter'
FROM nelt_world.waypoints w WHERE w.entry IN (53912,53913,54109,54110,5391201,5391300);

-- =========================== LOOT =====================================
-- lootid stays RAW (un-offset) -- the dominant live convention for map 861.
-- Only items that exist in acore_world.item_template are carried over;
-- reference rows (mincountOrRef<0) always pass, exactly as 01_ does.
DELETE FROM acore_world.`creature_loot_template` WHERE `Entry` IN (52289,53264,53265,53267,53271);

INSERT INTO acore_world.`creature_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.creature_loot_template lt
WHERE lt.entry IN (52289,53264,53265,53267,53271)
  AND (lt.mincountOrRef<0 OR lt.item IN (SELECT entry FROM acore_world.`item_template`));

DELETE FROM acore_world.`skinning_loot_template` WHERE `Entry` IN (52289,53271);

INSERT INTO acore_world.`skinning_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT st.entry, st.item, IF(st.mincountOrRef<0,-st.mincountOrRef,0), ABS(st.ChanceOrQuestChance), IF(st.ChanceOrQuestChance<0,1,0), st.lootmode, st.groupid, IF(st.mincountOrRef<0,1,st.mincountOrRef), st.maxcount
FROM nelt_world.skinning_loot_template st
WHERE st.entry IN (52289,53271)
  AND (st.mincountOrRef<0 OR st.item IN (SELECT entry FROM acore_world.`item_template`));

-- ---- quest item 69860 "Living Obsidium Chip" (quest 29295) ----
-- Its ONLY source in either Cata DB is loot table 52107 (Obsidium Punisher,
-- live as 3652107 with the RAW 52107 loot key already in place) -- but the
-- row itself never came across, so 29295 has no drop source at all.  Added
-- here as a quest-required 100% drop, exactly as the source has it.
DELETE FROM acore_world.`creature_loot_template` WHERE `Entry` = 52107 AND `Item` = 69860;
INSERT INTO acore_world.`creature_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`) VALUES
(52107, 69860, 0, 100, 1, 1, 0, 1, 1);

-- =========================== GAMEOBJECT ===============================
-- 208535 "Dried Acorn" is a type-2 QUESTGIVER, not a chest -- it has no
-- gameobject_loot_template anywhere, and quest 29245's StartItem 69675 is a
-- srcItemId (auto-granted on accept), so no loot source is needed once the
-- questgiver relation exists.  Item 69675 verified present live.
-- Data1 (gossip menu 16401) is zeroed: that menu does not exist in this DB and
-- a questgiver GO takes its quest list from gameobject_queststarter.
DELETE FROM acore_world.`gameobject_template` WHERE `entry` = 3808535;

INSERT INTO acore_world.`gameobject_template`
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT entry+3600000, `type`, displayId, name, IconName, castBarCaption, unk1, size, data0, 0, data2, data3, data4, data5, data6, data7, data8, data9, data10, data11, data12, data13, data14, data15, data16, data17, data18, data19, data20, data21, data22, data23, '', '', 0
FROM nelt_world.gameobject_template WHERE entry = 208535;

DELETE FROM acore_world.`gameobject_template_addon` WHERE `entry` = 3808535;

INSERT INTO acore_world.`gameobject_template_addon` (`entry`,`faction`,`flags`,`mingold`,`maxgold`,`artkit0`,`artkit1`,`artkit2`,`artkit3`)
SELECT entry+3600000, faction, flags, 0, 0, 0, 0, 0, 0
FROM nelt_world.gameobject_template WHERE entry = 208535;

-- ---- GO spawn (source map 861 phase 77, z 66.31 -> inside the 861 frame) ----
DELETE FROM acore_world.`gameobject` WHERE `guid` BETWEEN 15220001 AND 15229999;

INSERT INTO acore_world.`gameobject`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`VerifiedBuild`,`Comment`)
SELECT 15220000 + ROW_NUMBER() OVER (ORDER BY g.guid), g.id+3600000, 861, 4925, 4925, 1, 1,
       g.position_x, g.position_y, g.position_z, g.orientation, g.rotation0, g.rotation1, g.rotation2, g.rotation3,
       GREATEST(g.spawntimesecs,120), g.animprogress, g.state, '', 0, 'MoltenFront-DeepLayer'
FROM nelt_world.gameobject g
WHERE g.id = 208535 AND g.map = 861 AND g.position_z BETWEEN -200 AND 400;

-- =========================== SPAWNS: MAP 861 ==========================
-- Every map-861 spawn the source has for these entries, across ALL phases,
-- flattened to phaseMask 1 / zone+area 4925.  Each entry has exactly one
-- source spawn (no positional dedupe needed) and none of the clones has any
-- existing live placement (they were created above).  z guard: 861 frame.
--   53055/53759/53771/53834/53864 all sit on the SAME point (1546.90, 334.33,
--   62.12) -- they are the five phase-512 variants of one rare camp, so they
--   are pooled below and only one is up at a time.
--   52490 Skylord Omnuron  (1062.34, 421.43, 41.51)
--   52495 Shalis Darkhunter(1054.11, 318.14, 45.56)
--   53366 Leyara           (1229.46, 164.74, 10.71)
--   75193 Into-the-Depths event starter (1236.51, 163.90, 10.75) -- the invisible
--         bunny that drives Leyara's intro; it stands next to her by design.
-- 53912/53913/54109/54110 are summoned by the encounter, never statically
-- placed, so they get templates and scripts but no spawn rows (source agrees).
DELETE FROM acore_world.`pool_creature` WHERE `pool_entry` = 133000001;
DELETE FROM acore_world.`pool_template` WHERE `entry` = 133000001;
DELETE FROM acore_world.`creature` WHERE `guid` BETWEEN 15350001 AND 15350099;

INSERT INTO acore_world.`creature`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 15350000 + ROW_NUMBER() OVER (ORDER BY c.guid), c.id+@OFF, 861, 4925, 4925, 1, 1, -1,
       c.position_x, c.position_y, c.position_z, c.orientation, GREATEST(c.spawntimesecs,120), c.spawndist, c.currentwaypoint,
       c.curhealth, c.curmana, c.MovementType, ct.npcflag, ct.unit_flags, 0, '', 0, 0, 'MoltenFront-DeepLayer'
FROM nelt_world.creature c
JOIN nelt_world.creature_template ct ON ct.entry = c.id
WHERE c.map = 861
  AND c.id IN (52490,52495,53055,53366,53759,53771,53834,53864,75193)
  AND c.position_z BETWEEN -200 AND 400;

-- ---- rare rotation: only ONE Lieutenant of Flame up at a time ----
INSERT INTO acore_world.`pool_template` (`entry`,`max_limit`,`description`) VALUES
(133000001, 1, 'Molten Front - Lieutenant of Flame rare rotation');

INSERT INTO acore_world.`pool_creature` (`guid`,`pool_entry`,`chance`,`description`)
SELECT guid, 133000001, 0, 'MF Lieutenant of Flame rare'
FROM acore_world.`creature`
WHERE `guid` BETWEEN 15350001 AND 15350099 AND `id` IN (3653055,3653759,3653771,3653834,3653864);

-- =========================== SPAWNS: MAP 861 (DC-PLACED) ==============
-- Ricket has ZERO static spawns in nelt_world AND cata_world (verified on every
-- map, every phase) -- the source only ever phases her in through a script that
-- was never ported.  Both variants start live quests (29263/29278 and 29297),
-- so without a placement those three quests stay ungiveable.  They are placed
-- here BY HAND next to Damek Bloombeard (3653214 @ 986.74, 375.04, 38.53), the
-- questgiver who ENDS all three, i.e. inside the established MF hub camp.
-- These two coordinates are a DC choice, not a retail position.
DELETE FROM acore_world.`creature` WHERE `guid` BETWEEN 15350101 AND 15350199;

INSERT INTO acore_world.`creature`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`) VALUES
(15350101, 3653196, 861, 4925, 4925, 1, 1, -1, 989.74, 373.04, 38.45, 3.40, 300, 0, 0, 1, 0, 0, 3, 33536, 0, '', 0, 0, 'MoltenFront-DeepLayer DC-placed'),
(15350102, 3654163, 861, 4925, 4925, 1, 1, -1, 991.74, 370.04, 38.40, 3.40, 300, 0, 0, 1, 0, 0, 3, 33536, 0, '', 0, 0, 'MoltenFront-DeepLayer DC-placed');

-- =========================== SPAWNS: MAP 750 (HYJAL SIDE) =============
-- 52289/53264/53265/53267/53271/53073 are NOT on map 861 in the source: they
-- stand on map 1 in the Hyjal phase-32 layer, whose coordinate frame is the one
-- this server ships as map 750 zone/area 4923 (live 750/4923 spans x 3399-5770,
-- y -4979..-1280, z 569-1929; these rows land at x 3406-4453, y -2485..-2096,
-- z 966-1207).  The BETWEEN guard enforces the Hyjal z frame per row so nothing
-- from a foreign frame can slip in.
--   17 spawns: 12x Fiery Behemoth, 1x each Searris / Kelbnar / Andrazor /
--   Fah Jarakk, 1x Captain Soren Moonfall (questgiver for 29128).
DELETE FROM acore_world.`creature` WHERE `guid` BETWEEN 15820001 AND 15829999;

INSERT INTO acore_world.`creature`
(`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnMask`,`phaseMask`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curhealth`,`curmana`,`MovementType`,`npcflag`,`unit_flags`,`dynamicflags`,`ScriptName`,`VerifiedBuild`,`CreateObject`,`Comment`)
SELECT 15820000 + ROW_NUMBER() OVER (ORDER BY c.guid), c.id+@OFF, 750, 4923, 4923, 1, 1, -1,
       c.position_x, c.position_y, c.position_z, c.orientation, GREATEST(c.spawntimesecs,120), c.spawndist, c.currentwaypoint,
       c.curhealth, c.curmana, c.MovementType, ct.npcflag, ct.unit_flags, 0, '', 0, 0, 'MoltenFront-DeepLayer-Hyjal'
FROM nelt_world.creature c
JOIN nelt_world.creature_template ct ON ct.entry = c.id
WHERE c.map = 1
  AND c.id IN (52289,53073,53264,53265,53267,53271)
  AND c.position_z BETWEEN 880 AND 1929;

-- =========================== QUEST RELATIONS ==========================
-- Re-derived from cata_world (UNION nelt_world for anything cata lacks) for the
-- cloned source entries, offset by +3,600,000.  Guarded on the quest existing
-- live AND on the clone existing, so out-of-scope source quests self-skip and
-- the file cannot point a relation at a missing entry.
-- Expected additions: 29128 starter 3653073 | 29182 + 29305 ender 3652490 |
-- 29305 starter 3652490 | 29243 starter 3652495 + 3653056 | 29244 ender 3652495 |
-- 29263 + 29278 starter 3653196 | 29297 starter 3654163 | 29245 GO starter 3808535
-- (plus 29282/29287/29288/29290 if those quests are present).
--
-- 🔴 SCHEMA GOTCHA -- the two source DBs name these tables DIFFERENTLY:
--     cata_world  (TC-era):     creature_queststarter / creature_questender
--                               gameobject_queststarter / gameobject_questender
--     nelt_world  (MaNGOS-era): creature_questrelation / creature_involvedrelation
--                               gameobject_questrelation / gameobject_involvedrelation
--   Both carry the same (id, quest) columns.  Using the cata_world names against
--   nelt_world raises SQL error 1146 "Table doesn't exist" and -- because these are
--   separate statements -- SILENTLY SKIPS the whole relation import while the rest of
--   the file applies, leaving the deep-layer quests still unstartable.  Verified
--   2026-07-29 after exactly that happened on the first apply.
DELETE FROM acore_world.`creature_queststarter` WHERE `id` IN (3652490,3652495,3653056,3653073,3653196,3654163,3653366,3640660);
DELETE FROM acore_world.`creature_questender`   WHERE `id` IN (3652490,3652495,3653056,3653073,3653196,3654163,3653366,3640660);

INSERT IGNORE INTO acore_world.`creature_queststarter` (`id`,`quest`)
SELECT DISTINCT s.id+3600000, s.quest FROM (
  SELECT id, quest FROM cata_world.creature_queststarter WHERE id IN (52490,52495,53056,53073,53196,54163,53366,40660)
  UNION SELECT id, quest FROM nelt_world.creature_questrelation WHERE id IN (52490,52495,53056,53073,53196,54163,53366,40660)
) s
WHERE EXISTS (SELECT 1 FROM acore_world.`quest_template` q WHERE q.ID = s.quest)
  AND EXISTS (SELECT 1 FROM acore_world.`creature_template` ct WHERE ct.entry = s.id+3600000);

INSERT IGNORE INTO acore_world.`creature_questender` (`id`,`quest`)
SELECT DISTINCT e.id+3600000, e.quest FROM (
  SELECT id, quest FROM cata_world.creature_questender WHERE id IN (52490,52495,53056,53073,53196,54163,53366,40660)
  UNION SELECT id, quest FROM nelt_world.creature_involvedrelation WHERE id IN (52490,52495,53056,53073,53196,54163,53366,40660)
) e
WHERE EXISTS (SELECT 1 FROM acore_world.`quest_template` q WHERE q.ID = e.quest)
  AND EXISTS (SELECT 1 FROM acore_world.`creature_template` ct WHERE ct.entry = e.id+3600000);

DELETE FROM acore_world.`gameobject_queststarter` WHERE `id` = 3808535;

INSERT IGNORE INTO acore_world.`gameobject_queststarter` (`id`,`quest`)
SELECT DISTINCT g.id+3600000, g.quest FROM (
  SELECT id, quest FROM cata_world.gameobject_queststarter WHERE id = 208535
  UNION SELECT id, quest FROM nelt_world.gameobject_questrelation WHERE id = 208535
) g
WHERE EXISTS (SELECT 1 FROM acore_world.`quest_template` q WHERE q.ID = g.quest);

-- ---- raw objective fixes (same defect class as 13_/HyjalCata-116) ----
-- Both quests still name the RAW Cata entry while every live MF credit-giver is
-- the +3,600,000 clone.  Value-guarded and existence-guarded, so re-running is
-- a no-op.  29201's grant mechanism (Foothold Kill Credit) is handled by 17_;
-- this only makes the objective resolve to the clone 17_ will grant.
UPDATE acore_world.`quest_template` SET `RequiredNpcOrGo1` = 3640660
WHERE `ID` = 29177 AND `RequiredNpcOrGo1` = 40660
  AND EXISTS (SELECT 1 FROM acore_world.`creature_template` ct WHERE ct.entry = 3640660);

UPDATE acore_world.`quest_template` SET `RequiredNpcOrGo1` = 3653370
WHERE `ID` = 29201 AND `RequiredNpcOrGo1` = 53370
  AND EXISTS (SELECT 1 FROM acore_world.`creature_template` ct WHERE ct.entry = 3653370);

-- ---------------------------------------------------------------------
-- AFTER-APPLY EXPECTATIONS
--
-- * 29128 The Protectors of Hyjal   -- starter 3653073 now stands on map 750
--   (Hyjal, 4452.5/-2096.3/1204.0, his real source position).
-- * 29182 / 29305                   -- ender 3652490 Skylord Omnuron placed on 861.
-- * 29243 / 29244                   -- starter+ender 3652495 Shalis placed on 861.
--   3653056 is the second phase copy of the SAME NPC: cloned and wired as a
--   starter for 29243 (source says so) but deliberately NOT spawned, so the
--   camp does not end up with two Shalis models standing on each other.
-- * 29263 / 29278 / 29297           -- Ricket variants placed by hand (see above).
--   Their StartItem ids 69759 "The Bitter Pill" and 69832 "Burd Sticker" are
--   srcItemId semantics: the quest hands the item over on ACCEPT, so no loot or
--   vendor source is needed.  Both item_template rows verified present live.
-- * 29245 The Mysterious Seed       -- GO starter 3808535 placed on 861; StartItem
--   69675 "Dried Acorn" is likewise auto-granted on accept (item verified live).
-- * 29243 / 29305 Strike at the Heart -- these were ALREADY pointing at 3654230
--   "Lieutenant of Flame" but nothing granted that credit.  The five rare
--   Lieutenants cloned here each carry the ported JUST_DIED -> KilledMonsterCredit
--   3654230 row, so the objective now ticks.  This is the audit's
--   "kill-credit proxy" gap for 54230, resolved incidentally by the SmartAI port.
-- * 29295 The Bigger They Are       -- 69860 now drops from Obsidium Punisher.
-- * The Leyara finale is complete: 3653366 fights with her 30-row script and 9
--   timed action lists, summons 3653911 Shadow Wardens, 3653912 Malfurion and
--   3653913 Hamuul (who in turn summon their 3654110 / 3654109 second copies and
--   walk their ported waypoint paths), driven by the 3675193 event starter that
--   stands beside her.  Every cast in the encounter resolves (19_ ships all 33).
-- * 29177 Vigilance on Wings        -- objective now names 3640660, but see TODO 1.
--
-- ---------------------------------------------------------------------
-- TODO / KNOWN GAPS (nothing below is written by this file)
--
-- 1. TWILIGHT LANCER (3640660) HAS NO SPAWN ANYWHERE.
--    Verified: zero rows in nelt_world.creature AND cata_world.creature for
--    40660 on every map/phase, and zero SmartAI summon or target references:
--      SELECT * FROM nelt_world.creature WHERE id=40660;                -- 0
--      SELECT * FROM cata_world.creature WHERE id=40660;                -- 0
--      SELECT * FROM nelt_world.smart_scripts
--        WHERE (action_type IN (12,50) AND action_param1=40660)
--           OR (target_type IN (9,10,11,19) AND target_param1=40660);   -- 0
--    In retail the Lancers are spawned by the aerial (vehicle) event of quest
--    29177, whose script was never downported.  The objective now resolves to
--    a real template, but the quest still cannot be completed until the Lancers
--    are either placed by hand over the Hyjal 750/4923 airspace or summoned by
--    the event script.  Guid band 15,830,001+ is free and reserved for that.
--
-- 2. (RESOLVED) No spell this file references is missing any more.  19_ ships
--    all 33 rows -- including 79870 "Feral Charge", which unblocked the last
--    withheld row (timed action list 5391300 id 7, Hamuul charging Leyara).
--    Its trigger closure pulls in 45334, stock and already present client-side.
--    DELIBERATELY EXCLUDED FOREVER, do not "fix" this: 84886 "Generic Quest
--    Invisibility 9" -- porting it would hide Shalis Darkhunter (3653056) from
--    every player.  Same rule for 87872 / 94223 / 80797 and anything else in
--    that family.  It is filtered in three places here: her addon auras,
--    creature_template_spell, and the SmartAI port guards.
--
-- 3. (resolved by 19_) Every SmartAI row this layer needs is live and AIName
--    now matches row presence on all 24 clones.
--
-- 4. QUEST 29278 "Living Obsidium" (RequiredItemId1 = 69807) has NO loot source
--    in either Cata DB:
--      SELECT * FROM nelt_world.creature_loot_template WHERE item=69807;  -- 0
--      SELECT * FROM cata_world.creature_loot_template WHERE Item=69807;  -- 0
--    Its starter (3653196 Ricket) and ender (3653214) are both wired now, but
--    the item drop still has to be sourced -- most likely the same Obsidium
--    Punisher table 52107 that 69860 comes from.
--
-- 5. WAYPOINT PATH 5391200 IS EMPTY IN THE SOURCE.  Timed action list 5391201
--    starts it (action 53), but nelt_world.waypoints has no rows for it:
--      SELECT * FROM nelt_world.waypoints WHERE entry=5391200;            -- 0
--    The other six paths this encounter uses (53912, 53913, 54109, 54110,
--    5391201, 5391300) are ported.  This one costs a runtime "invalid path"
--    warning on a single movement step of the Leyara intro; points for it would
--    have to be invented, so they are not.
-- ---------------------------------------------------------------------
