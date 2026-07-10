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
-- areatrigger  (server-side geometry for AT 6583 -- ObjectMgr::LoadAreaTriggers()
-- reads this table, NOT the binary DBC; HandleAreaTriggerOpcode rejects any
-- triggerId missing here before at_bwd_intro ever gets a chance to run. This row
-- was absent entirely, so the Lord Victor Nefarius entrance RP could never fire.
-- Geometry extracted from the real Cata 4.3.4 client (locale-enUS.MPQ) AreaTrigger.dbc,
-- same box the client-side AreaTrigger.dbc row below uses. Live-reloadable via
-- `.reload areatrigger` -- no worldserver restart required.
-- ---------------------------------------------------------------------------
DELETE FROM `areatrigger` WHERE `entry` = 6583;
INSERT INTO `areatrigger` (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`)
VALUES (6583, 669, -346.411, -224.767, 200.0, 0.0, 10.0, 20.0, 20.0, 0.0);

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

-- ---------------------------------------------------------------------------
-- gossip_menu + npc_text  (Orb of Culmination 203254 shipped with gossipID=0 in
-- both cata_world and acore_world -- retail never authored gossip text for this
-- trigger object, so interacting with it showed the client's blank "Greetings,
-- <name>." fallback with no body. go_nefarians_end_orb_of_culmination only
-- overrides GossipSelect, so the core's default type-2 gossip prep reads
-- gameobject_template.Data0 to resolve the menu -- same pattern as Finkle's Cage.)
-- ---------------------------------------------------------------------------
DELETE FROM `broadcast_text` WHERE `ID` = 700900;
INSERT INTO `broadcast_text`
    (`ID`, `LanguageID`, `MaleText`, `FemaleText`, `EmoteID1`, `EmoteID2`, `EmoteID3`,
     `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `SoundEntriesId`, `EmotesID`, `Flags`, `VerifiedBuild`)
VALUES
    (700900, 0, 'A pulsing orb of crystallized shadow magic hums with barely-contained power. You can feel Nefarian''s will converging upon this place.', '', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

DELETE FROM `npc_text` WHERE `ID` = 700900;
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `BroadcastTextID0`, `lang0`, `Probability0`)
VALUES (700900, 'A pulsing orb of crystallized shadow magic hums with barely-contained power. You can feel Nefarian''s will converging upon this place.', '', 700900, 0, 1);

DELETE FROM `gossip_menu` WHERE `MenuID` = 700900;
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (700900, 700900);

UPDATE `gameobject_template` SET `Data0` = 700900 WHERE `entry` = 203254;
