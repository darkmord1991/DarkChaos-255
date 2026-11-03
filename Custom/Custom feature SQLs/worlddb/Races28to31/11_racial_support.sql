-- Races 28-31: everything the racial spells need besides their spell rows.
-- Needs the worldserver built with src/server/scripts/DC/Races/dc_races_28_31.cpp, because
-- spell_script_names is checked against the compiled scripts at startup.

DELETE FROM `spell_script_names` WHERE `spell_id` IN (256948, 257040, 255647, 256893, 256896, 274738);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(256948, 'spell_dc_spatial_rift'),
(257040, 'spell_dc_spatial_rift_teleport'),
(255647, 'spell_dc_lights_judgment'),
(256893, 'spell_dc_lights_judgment_strike'),
(256896, 'spell_dc_lights_reckoning_burst'),
(274738, 'spell_dc_ancestral_call');

-- Entropic Embrace: melee, ranged and spell hits, 5% chance, 45 seconds between procs. With the
-- 12 second buff that is close to retail's one proc a minute.
-- 82260 = 0x14154, SpellTypeMask 3 = damage + heal, SpellPhaseMask 2 = on hit.
DELETE FROM `spell_proc` WHERE `SpellId` = 255669;
INSERT INTO `spell_proc` (`SpellId`, `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `Chance`, `Cooldown`) VALUES
(255669, 82260, 3, 2, 5, 45000);

-- Sympathetic Vigor: 273217 is the owner's marker, 273218 the +10% health on the pet.
DELETE FROM `spell_pet_auras` WHERE `spell` = 273217;
INSERT INTO `spell_pet_auras` (`spell`, `effectId`, `pet`, `aura`) VALUES
(273217, 0, 0, 273218);

-- The strike and the eruption take their whole value from the script; a zero row stops the core
-- adding spell power on top of it.
DELETE FROM `spell_bonus_data` WHERE `entry` IN (256893, 256896);
INSERT INTO `spell_bonus_data` (`entry`, `direct_bonus`, `dot_bonus`, `ap_bonus`, `ap_dot_bonus`, `comments`) VALUES
(256893, 0, 0, 0, 0, 'Light''s Judgment - dc_races_28_31.cpp sets the damage'),
(256896, 0, 0, 0, 0, 'Light''s Reckoning - dc_races_28_31.cpp sets damage and healing');
