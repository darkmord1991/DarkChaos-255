-- Two race-masked tables that every custom-race port missed.
--
-- Worgoblin, Pandaren, AlliedRaces and Tier1Reskins each swept `item_template.AllowableRace`,
-- `quest_template.AllowableRaces`, `playercreateinfo_skills`, `skillraceclassinfo_dbc` and
-- `skilllineability_dbc`. None of them touched `spell_area` or `conditions`, so races
-- 9, 12 and 22-27 are still excluded from every faction-wide row in both.
--
-- What that costs in game:
--   spell_area 70056 / 70057 area 4904 -- Hellscream's Warsong / Strength of Wrynn. A custom
--     race gets NO Icecrown Citadel raid buff at all.
--   spell_area 49416 / 58354 / 59062 / 60815 / 60943 / ... -- the Wrathgate and Argent
--     Tournament phase auras. Without them those zones render in the wrong phase.
--   conditions type 16 (CONDITION_RACE) 1101 / 690 -- "show the gossip if the player is from
--     the alliance/horde" and the Injured Rainspeaker SAI gate.
--   conditions type 16, masks 767..1790 -- the "Show gossip text if player is not a <race>"
--     set. A Pandaren genuinely is not a Dwarf, so these must include the custom bits.
--
-- The guard is the same one 01_darkiron_server.sql uses: a row that names at least THREE of a
-- faction's stock races is faction-wide and is opened up; a row naming one or two races is a
-- racial and is left alone. Stock masks: Alliance 1101, Horde 690.
--
--   Alliance customs: Worgen 2048 | Pandaren A 2097152 | Kul Tiran 33554432
--                     | Dark Iron 67108864  = 102762496
--   Horde customs:    Goblin 256 | Pandaren H 4194304 | Vulpera 8388608
--                     | Zandalari 16777216  = 29360384
--
-- Both statements are idempotent (bitwise OR of bits that may already be set).

UPDATE `spell_area` SET `racemask` = `racemask` | 102762496
    WHERE `racemask` <> 0 AND BIT_COUNT(`racemask` & 1101) >= 3;
UPDATE `spell_area` SET `racemask` = `racemask` | 29360384
    WHERE `racemask` <> 0 AND BIT_COUNT(`racemask` & 690) >= 3;

UPDATE `conditions` SET `ConditionValue1` = `ConditionValue1` | 102762496
    WHERE `ConditionTypeOrReference` = 16 AND BIT_COUNT(`ConditionValue1` & 1101) >= 3;
UPDATE `conditions` SET `ConditionValue1` = `ConditionValue1` | 29360384
    WHERE `ConditionTypeOrReference` = 16 AND BIT_COUNT(`ConditionValue1` & 690) >= 3;
