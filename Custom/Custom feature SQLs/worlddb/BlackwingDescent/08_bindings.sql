-- Blackwing Descent (map 669) — script/condition/vehicle bindings
-- spell_script_names (161) + conditions (60) reference the BWD boss spell ids — those spells must be
-- added to Spell.dbc + spell_dbc (DBC step). The C++ SpellScripts + at_bwd_intro AreaTriggerScript are
-- provided by the ported CataTC boss/misc files. AreaTrigger 6583 also needs a client AreaTrigger.dbc row.

-- ---------------------------------------------------------------------------
-- spell_script_names  (161 boss ability SpellScript bindings)
-- ---------------------------------------------------------------------------
DELETE FROM `spell_script_names`
WHERE `ScriptName` LIKE 'spell_magmaw%' OR `ScriptName` LIKE 'spell_maloriak%' OR `ScriptName` LIKE 'spell_atramedes%'
   OR `ScriptName` LIKE 'spell_chimaeron%' OR `ScriptName` LIKE 'spell_omnotron%' OR `ScriptName` LIKE 'spell_nefarian%'
   OR `ScriptName` LIKE 'spell_bwd%';

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`)
SELECT `spell_id`, `ScriptName`
FROM `cata_world`.`spell_script_names`
WHERE `ScriptName` LIKE 'spell_magmaw%' OR `ScriptName` LIKE 'spell_maloriak%' OR `ScriptName` LIKE 'spell_atramedes%'
   OR `ScriptName` LIKE 'spell_chimaeron%' OR `ScriptName` LIKE 'spell_omnotron%' OR `ScriptName` LIKE 'spell_nefarian%'
   OR `ScriptName` LIKE 'spell_bwd%';

-- ---------------------------------------------------------------------------
-- conditions  (SPELL_IMPLICIT_TARGET type 13 on the BWD boss spells)
-- ---------------------------------------------------------------------------
DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 13
  AND `SourceEntry` IN (
      SELECT `spell_id` FROM `cata_world`.`spell_script_names`
      WHERE `ScriptName` LIKE 'spell_magmaw%' OR `ScriptName` LIKE 'spell_maloriak%' OR `ScriptName` LIKE 'spell_atramedes%'
         OR `ScriptName` LIKE 'spell_chimaeron%' OR `ScriptName` LIKE 'spell_omnotron%' OR `ScriptName` LIKE 'spell_nefarian%'
         OR `ScriptName` LIKE 'spell_bwd%');

INSERT INTO `conditions`
    (`SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`,
     `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`,
     `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`)
SELECT
    `SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`,
    `ConditionTarget`, `ConditionValue1`, `ConditionValue2`, `ConditionValue3`, `NegativeCondition`,
    `ErrorType`, `ErrorTextId`, `ScriptName`, `Comment`
FROM `cata_world`.`conditions`
WHERE `SourceTypeOrReferenceId` = 13
  AND `SourceEntry` IN (
      SELECT `spell_id` FROM `cata_world`.`spell_script_names`
      WHERE `ScriptName` LIKE 'spell_magmaw%' OR `ScriptName` LIKE 'spell_maloriak%' OR `ScriptName` LIKE 'spell_atramedes%'
         OR `ScriptName` LIKE 'spell_chimaeron%' OR `ScriptName` LIKE 'spell_omnotron%' OR `ScriptName` LIKE 'spell_nefarian%'
         OR `ScriptName` LIKE 'spell_bwd%');

-- ---------------------------------------------------------------------------
-- npc_spellclick_spells  (Magmaw 41570 head-ride 77901; Atramedes 41442 ride 46598)
-- ---------------------------------------------------------------------------
DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (41570,41442,42186,42166,42178,42179,42180,41378,43296,41376,41270);
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`)
SELECT `npc_entry`, `spell_id`, `cast_flags`, `user_type`
FROM `cata_world`.`npc_spellclick_spells`
WHERE `npc_entry` IN (41570,41442,42186,42166,42178,42179,42180,41378,43296,41376,41270);

-- ---------------------------------------------------------------------------
-- vehicle_template_accessory  (Atramedes 41442 -> Blind Dragon Tail 42356, seat 0)
-- ---------------------------------------------------------------------------
DELETE FROM `vehicle_template_accessory` WHERE `entry` IN (41570,41442,42186,42166,42178,42179,42180,41378,43296,41376,41270);
INSERT INTO `vehicle_template_accessory` (`entry`, `accessory_entry`, `seat_id`, `minion`, `description`, `summontype`, `summontimer`)
SELECT `entry`, `accessory_entry`, `seat_id`, `minion`, `description`, `summontype`, `summontimer`
FROM `cata_world`.`vehicle_template_accessory`
WHERE `entry` IN (41570,41442,42186,42166,42178,42179,42180,41378,43296,41376,41270);

-- ---------------------------------------------------------------------------
-- areatrigger_scripts  (Nefarian intro RP trigger; distinct from the entrance-teleport AT 6581)
-- ---------------------------------------------------------------------------
DELETE FROM `areatrigger_scripts` WHERE `entry` = 6583;
INSERT INTO `areatrigger_scripts` (`entry`, `ScriptName`) VALUES (6583, 'at_bwd_intro');

-- ---------------------------------------------------------------------------
-- game_tele  (GM convenience: .tele BlackwingDescentInside -> map 669 entrance)
-- ---------------------------------------------------------------------------
DELETE FROM `game_tele` WHERE `id` = 10614;
INSERT INTO `game_tele` (`id`, `position_x`, `position_y`, `position_z`, `orientation`, `map`, `name`)
VALUES (10614, -345.872, -224.344, 193.127, 0, 669, 'BlackwingDescentInside');
