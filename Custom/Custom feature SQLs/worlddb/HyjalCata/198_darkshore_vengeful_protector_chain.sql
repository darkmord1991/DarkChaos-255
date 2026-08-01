-- ---------------------------------------------------------------------------
-- 198  Darkshore -- close the Vengeful Protector chain (quest 13514)
-- ---------------------------------------------------------------------------
-- 196_ shipped the vehicle DATA but deliberately did NOT wire the script,
-- because nothing summoned the creature. That gap is now closed. The wowhead
-- quest text was the clue -- "take the company of one of the Vengeful
-- Protectors there" means they STAND IN THE WORLD and you click one, rather
-- than the vehicle being handed out by the quest.
--
-- THE FULL CHAIN, traced end to end:
--   1. 43742 Vengeful Protector -- the two that stand in Shatterspear Vale.
--      npcflag SPELLCLICK, spellclick spell 56685, AIName 'SmartAI'.
--   2. Its SmartAI has event 73 (ON_SPELLCLICK) -> action 80
--      (CALL_TIMED_ACTIONLIST) pointing at list 4374200 (= entry x 100).
--   3. That list makes the INVOKER (the player) cast 151235 "Dismount and
--      Cancel Shapeshifts", then 100 ms later 64602.
--   4. 64602 "Summon Possessed Vengeful Protector" summons 32851 -- the
--      RIDEABLE one, VehicleId 326, which 196_ imported.
--   5. The player clicks 32851 (spellclick 46598 "Ride Vehicle Hardcoded") and
--      rides it; npc_vengeful_protector_ancient_vehicle then runs.
--
-- Two of the three spells were already present (151235 and 46598 in spell_dbc,
-- 56685 in the binary Spell.dbc). Only 64602 had to be downported.
--
-- Apply against acore_world AFTER 196_, then REBUILD worldserver (the C++ port
-- lands with this). Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) Spell 64602 -- with the summon target REMAPPED
-- ---------------------------------------------------------------------------
-- Source: K:\UntouchedClients\Cata, Data\enUS\locale-enUS.MPQ -- Spell.dbc for
-- the header, SpellEffect.dbc for the effect (see the method notes in 194_).
--
-- THE ONE VALUE THAT IS NOT COPIED VERBATIM: EffectMiscValue_1 is the creature
-- to summon. Cata says 32851; on map 750 that must be 3732851, or the spell
-- would summon the raw Kalimdor entry, which does not exist here and the summon
-- would silently do nothing.
--
-- EffectMiscValueB 2976 is a SummonProperties id -- verified present in the
-- LIVE server's SummonProperties.dbc (204 rows), so no extra row is needed.
-- DieSides/BasePoints are both 0 here, so the +1 shift 194_ documents does not
-- apply to this spell.
-- ---------------------------------------------------------------------------
DELETE FROM `spell_dbc` WHERE `ID` = 64602;

INSERT INTO `spell_dbc`
    (`ID`,`Attributes`,`CastingTimeIndex`,`DurationIndex`,`RangeIndex`,`SpellIconID`,`SchoolMask`,
     `ProcChance`,`EquippedItemClass`,`Name_Lang_enUS`,
     `Effect_1`,`EffectBasePoints_1`,`EffectDieSides_1`,`EffectMiscValue_1`,`EffectMiscValueB_1`,
     `ImplicitTargetA_1`)
VALUES
(64602, 150995200, 1, 21, 1, 1, 1, 101, -1, 'Summon Possessed Vengeful Protector',
 28, 0, 0, 3732851, 2976, 18);

-- ---------------------------------------------------------------------------
-- B) The world-standing Protector (3743742) -- flags, AI and spellclick
-- ---------------------------------------------------------------------------
-- 184_ copied this template from cata_world, which reports npcflag 0 and no
-- AIName. nelt_world -- the DB the scripts were written against -- has
-- npcflag 16777216 (SPELLCLICK) and AIName 'SmartAI'. Without both, clicking
-- the Protector does nothing at all.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `npcflag` = `npcflag` | 16777216, `AIName` = 'SmartAI'
 WHERE `entry` = 3743742;

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 3743742;

INSERT INTO `npc_spellclick_spells` (`npc_entry`,`spell_id`,`cast_flags`,`user_type`) VALUES
(3743742, 56685, 1, 0);

-- ---------------------------------------------------------------------------
-- C) SmartAI -- the spellclick hook and its timed action list
-- ---------------------------------------------------------------------------
-- The action list id follows this core's convention of entry x 100, so
-- 3743742 -> 374374200. Both DELETEs are scoped to the exact entryorguid; note
-- source_type 9 must NEVER be range-deleted, because action lists from
-- unrelated creatures share the same numeric space.
--
-- Actions, in order: clear npcflag so the Protector cannot be clicked twice;
-- have the player cast 151235 (dismount) and then 64602 (summon); restore the
-- SPELLCLICK flag 2 seconds later so the next player can use it.
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3743742 AND `source_type` = 0;
DELETE FROM `smart_scripts` WHERE `entryorguid` = 374374200 AND `source_type` = 9;

INSERT INTO `smart_scripts`
    (`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
     `event_param1`,`event_param2`,`event_param3`,`event_param4`,
     `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,
     `target_type`,`target_param1`,`target_param2`,`target_param3`,
     `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
(3743742, 0, 0, 0, 73, 0, 100, 0, 0, 0, 0, 0,
 80, 374374200, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
 'Vengeful Protector - On Spellclick - Run action list'),
(374374200, 9, 0, 0, 0, 0, 100, 0, 0, 0, 0, 0,
 81, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
 'Vengeful Protector - Clear npcflag so it cannot be clicked twice'),
(374374200, 9, 1, 0, 0, 0, 100, 0, 0, 0, 0, 0,
 85, 151235, 2, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0,
 'Vengeful Protector - Invoker casts Dismount and Cancel Shapeshifts'),
(374374200, 9, 2, 0, 0, 0, 100, 0, 100, 100, 0, 0,
 85, 64602, 2, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0,
 'Vengeful Protector - Invoker casts Summon Possessed Vengeful Protector'),
(374374200, 9, 3, 0, 0, 0, 100, 0, 2000, 2000, 0, 0,
 81, 16777216, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
 'Vengeful Protector - Restore SPELLCLICK npcflag');

-- ---------------------------------------------------------------------------
-- D) Wire the vehicle AI
-- ---------------------------------------------------------------------------
-- Ported into DC/MountHyjal/zone_darkshore_cata.cpp. The original compared
-- me->GetAreaId() against AREA_SHATTERSPEAR_VALE = 4664 and despawned the
-- vehicle 10 seconds after that check failed -- on map 750 it would ALWAYS have
-- failed, because this project uses its own AreaTable ids. The port accepts the
-- retail area id OR our Darkshore id (4929), the same belt-and-braces the
-- existing Hyjal port uses with DC_HYJAL_AREAID.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `ScriptName` = 'npc_vengeful_protector_ancient_vehicle'
 WHERE `entry` = 3732851;

-- ---------------------------------------------------------------------------
-- Verification after applying + rebuild + restart:
--   SELECT ID, Name_Lang_enUS, Effect_1, EffectMiscValue_1 FROM spell_dbc WHERE ID = 64602;
--     -- Effect 28, EffectMiscValue_1 = 3732851 (NOT 32851)
--   SELECT entry, npcflag, AIName FROM creature_template WHERE entry = 3743742;  -- 16777216 / SmartAI
--   SELECT entry, VehicleId, ScriptName FROM creature_template WHERE entry = 3732851;
--   SELECT COUNT(*) FROM smart_scripts WHERE entryorguid = 374374200 AND source_type = 9;  -- 4
--
-- In game, at Shatterspear Vale on map 750: click one of the two Vengeful
-- Protectors while on quest 13514. You should be dismounted, a Possessed
-- Vengeful Protector should appear, and clicking THAT should seat you in it.
-- If the click does nothing, section B did not apply; if the mount appears but
-- vanishes ~10s later, the worldserver binary is stale (the area fix is in C++).
-- ---------------------------------------------------------------------------
