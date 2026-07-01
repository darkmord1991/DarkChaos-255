-- =====================================================================
-- Mount Hyjal (map 750) + Molten Front -- 31  ScriptName wiring
-- ---------------------------------------------------------------------
-- Attaches the ported CreatureScripts / GameObjectScripts / SpellScripts
-- (src/server/scripts/DC/MountHyjal/zone_dc_mount_hyjal_ported.cpp +
--  zone_dc_molten_front.cpp) to their dc-clone entries.
--
-- A CreatureScript("name") / GameObjectScript("name") only fires if the
-- matching creature_template.ScriptName / gameobject_template.ScriptName
-- is set. nelt_world set ScriptName on only 2 rows, and the Neltharion
-- world.sql dump carries none of the rest, so the target entry for each
-- script was derived from the C++ semantics (self NPC_/GO_ enum, summon
-- site, quest, level/role) cross-checked against what the dc downport
-- actually created in acore_world (clone = original + 3,600,000).
--
-- ONLY entries that existed in acore_world at the time were wired here.
-- 2026-07 UPDATE: 29_neltharion_templates.sql now clones the remaining
-- script targets (proveditor set, orb, controllers, Molten Front cast,
-- summon-spell targets) and 46_neltharion_fixups.sql wires their
-- ScriptNames -- including MOVING npc_aronus_vehicle from the static
-- questgiver 3640816 (wired in the live DB by an earlier revision) to the
-- flight vehicle 3675024 that summon spell 151010 actually creates.
-- Apply 29 -> 46 after this file.
-- Idempotent.
-- =====================================================================

-- ---------------------------------------------------------------------
-- CreatureScript -> creature_template.ScriptName
-- ---------------------------------------------------------------------
-- 3640140  Arch Druid Fandral Staghelm  (lvl83 dream/combat variant; orig 40140)
UPDATE acore_world.creature_template SET ScriptName='npc_archdruid_fandral_staghelm_dream' WHERE entry=3640140;

-- 3640427  Spawn of Smolderos  (grudge-match combatant at the Butcher 4745,-4231; orig 40427)
UPDATE acore_world.creature_template SET ScriptName='npc_spawn_of_smolderos_grudge_match' WHERE entry=3640427;

-- 3640460  Activated Flameward  (NPC_FLAMEWARD const, summoned by go_flameward_inferno; orig 40460)
UPDATE acore_world.creature_template SET ScriptName='npc_activated_flameward' WHERE entry=3640460;

-- 3640780 / 3640934  Emerald Drake  (Slash and Burn quest 25608 bombing vehicle, both faction variants; orig 40780/40934)
UPDATE acore_world.creature_template SET ScriptName='npc_emerald_drake_slash_burn' WHERE entry=3640780;
UPDATE acore_world.creature_template SET ScriptName='npc_emerald_drake_slash_burn' WHERE entry=3640934;

-- 3641557  Child of Tortolla  (lvl80 Hyjal Strength-of-Tortolla child; orig 41557)
UPDATE acore_world.creature_template SET ScriptName='npc_strength_of_tortolla' WHERE entry=3641557;

-- 3652904  Anren Shadowseeker  (Molten Front prisoner, Get Me Out of Here quest 29272 escort; orig 52904)
UPDATE acore_world.creature_template SET ScriptName='npc_anren_shadowseeker_escort' WHERE entry=3652904;

-- ---------------------------------------------------------------------
-- GameObjectScript -> gameobject_template.ScriptName
-- ---------------------------------------------------------------------
-- 3802902 / 3802927..30  Flameward  (Prepping the Soil 25502 inferno braziers; orig 202902/202927-30)
UPDATE acore_world.gameobject_template SET ScriptName='go_flameward_inferno' WHERE entry IN (3802902,3802927,3802928,3802929,3802930);

-- ---------------------------------------------------------------------
-- SpellScript -> spell_script_names  (only the spells whose ID is fixed
-- by the script's own enum; the graduation/turtle SpellScripts are cast
-- by player abilities whose Cata spell IDs are resolved in the spell
-- downport, so they are listed in the report, not wired here.)
-- These require the spell to exist in the client spell_dbc (Cata IDs).
-- ---------------------------------------------------------------------
DELETE FROM acore_world.spell_script_names WHERE spell_id IN (73982,74010,74011,73983,74012,74013,97243,97247)
  AND ScriptName IN ('spell_answer_yes_master','spell_answer_yes_correct','spell_answer_yes_incorrect',
                     'spell_answer_no_master','spell_answer_no_correct','spell_answer_no_incorrect',
                     'spell_molten_behemoth_stomp','spell_molten_behemoth_fiery_boulder');
INSERT INTO acore_world.spell_script_names (spell_id, ScriptName) VALUES
 (73982, 'spell_answer_yes_master'),        -- SPELL_YES
 (74010, 'spell_answer_yes_correct'),        -- SPELL_ANSWER_YES_CORRECT
 (74011, 'spell_answer_yes_incorrect'),      -- SPELL_ANSWER_YES_INCORRECT
 (73983, 'spell_answer_no_master'),          -- SPELL_NO
 (74012, 'spell_answer_no_correct'),         -- SPELL_ANSWER_NO_CORRECT
 (74013, 'spell_answer_no_incorrect'),       -- SPELL_ANSWER_NO_INCORRECT
 (97243, 'spell_molten_behemoth_stomp'),     -- SPELL_MOLTEN_STOMP
 (97247, 'spell_molten_behemoth_fiery_boulder'); -- SPELL_FIERY_BOULDER