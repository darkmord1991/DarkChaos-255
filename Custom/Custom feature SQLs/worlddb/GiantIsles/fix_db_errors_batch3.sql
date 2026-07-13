-- =============================================================================
-- DB Error Fixes — Batch 3
-- Addresses remaining startup warnings after batches 1 & 2.
-- =============================================================================

-- 1. creature_template / model / equip for fishing NPCs 401119–401123
--    These entries were in fix_missing_creature_templates.sql (batch 1) but
--    were never applied to the live DB.
DELETE FROM `creature_template` WHERE `entry` IN (401119, 401120, 401121, 401122, 401123);
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`, `unit_class`,
     `unit_flags`, `RegenHealth`, `ScriptName`, `VerifiedBuild`)
VALUES
(401119, 'Grak\'zar',           'Ancient Cook',        400119, 80, 80, 35,   1, 1.0, 1.14286, 0, 1, 0, 1, 'npc_giant_isles_primal_cook', 12340),
(401120, 'Angler Tideborn',     'Fishing Trainer',     400130, 80, 80, 35,  17, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340),
(401121, 'Tide-Watcher Mazu',   'Fishing Daily Quests',400131, 80, 80, 35,   3, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340),
(401122, 'Bait Keeper Ruk\'lo', 'Fishing Supplies',    400132, 80, 80, 35, 129, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340),
(401123, 'Primal Fisher',       NULL,                       0, 80, 80, 35,   0, 1.0, 1.14286, 0, 1, 0, 1, '',                            12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (401119, 401120, 401121, 401122, 401123);
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(401119, 0, 4259, 1.0, 1.0, 12340),
(401120, 0, 2095, 1.0, 1.0, 12340),
(401121, 0, 5444, 1.0, 1.0, 12340),
(401122, 0, 4259, 1.0, 1.0, 12340),
(401123, 0, 2095, 1.0, 1.0, 12340);

DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (401120, 401121, 401122, 401123);
INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(401120, 1,  6256, 0, 0, 12340),
(401121, 1, 12584, 0, 0, 12340),
(401122, 1,     0, 0, 0, 12340),
(401123, 1,  6256, 0, 0, 12340);

-- 2. creature_loot_template: add missing entries for 400502–400505
--    Their creature_template rows exist (lootid = own entry) but loot rows
--    were omitted from temple_atal_hakkar_clone.sql.
DELETE FROM `creature_loot_template` WHERE `Entry` IN (400502, 400503, 400504, 400505);
INSERT INTO `creature_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`) VALUES
(400502, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400503, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400504, 402000, 0, 25, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)'),
(400505, 402000, 0, 15, 1, 1, 0, 1, 1, 'Idol Fragment of Hakkar (quest)');

-- 3. Fix broken reference_loot_template references in creature_loot_template
--    Boss rows used item=14132, Reference=1. Entry 1 doesn't exist.
--    Correct form: item=0, Reference=14132 (reference_loot_template entry 14132 exists).
UPDATE `creature_loot_template`
SET `Item` = 0, `Reference` = 14132
WHERE `Entry` IN (400520, 400521, 400522, 400523) AND `Reference` = 1;

-- 4. Zero lootid for entries pointing to loot table 7 (no rows exist)
UPDATE `creature_template` SET `lootid` = 0 WHERE `entry` IN (100050, 100051, 100100);

-- 5. Remove orphan gossip_menu row (TextID 50000 doesn't exist in npc_text;
--    no creature uses gossip_menu_id=700000)
DELETE FROM `gossip_menu` WHERE `MenuID` = 700000;

-- 6. Remove item 2332 from npc_vendor (item doesn't exist in item_template)
DELETE FROM `npc_vendor` WHERE `entry` IN (401101, 401106) AND `item` = 2332;

-- 7. Remove dead areatrigger_teleport rows for IDs 15000 and 15001 (Hyjal Frontier
--    portals — no matching AreaTrigger.dbc entry; client never fires these triggers)
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (15000, 15001);

-- 8. Remove orphan creature_formations entry (leaderGUID 92903 doesn't exist
--    in the creature spawn table)
DELETE FROM `creature_formations` WHERE `leaderGUID` = 92903;

-- 9. creature_text: add GroupID=2 rows required by SmartAI TALK(2) actions
-- 400510 (Zul'kar the Flayer): no text entries exist; add aggro + two combat taunts
DELETE FROM `creature_text` WHERE `CreatureID` = 400510;
INSERT INTO `creature_text` (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`) VALUES
(400510, 0, 0, 'The Atal\'ai shall not fall while blood flows through our veins!', 1, 0, 100, 0, 0, 0, 0, 0, 'Zul\'kar aggro'),
(400510, 1, 0, 'Your bones will adorn the walls of this temple!',                  1, 0, 100, 0, 0, 0, 0, 0, 'Zul\'kar taunt'),
(400510, 2, 0, 'Hakkar\'s power flows through me! You cannot win!',                1, 0, 100, 0, 0, 0, 0, 0, 'Zul\'kar taunt 2');

-- 400520 (Atal'alarion the Eternal): GroupID=0 and 1 exist; add GroupID=2 (kill yell)
DELETE FROM `creature_text` WHERE `CreatureID` = 400520 AND `GroupID` = 2;
INSERT INTO `creature_text` (`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`) VALUES
(400520, 2, 0, 'Another soul claimed for Hakkar. The blood god grows stronger!', 1, 0, 100, 0, 0, 0, 0, 0, 'Atal\'alarion kill yell');

-- 10. Elder Greymane (300021): has AIName=SmartAI with no smart_scripts rows, and
--     ScriptName='npc_elder_greymane_escort' with no matching C++ class.
UPDATE `creature_template`
SET `AIName` = '', `ScriptName` = ''
WHERE `entry` = 300021;

-- 11. Clear ScriptName for entries whose C++ class doesn't exist
UPDATE `creature_template`
SET `ScriptName` = ''
WHERE `entry` IN (190010, 190011, 199999, 200006, 830016);

-- 12. Remove invalid spell_area row (area 3317 not in AreaTable.dbc)
DELETE FROM `spell_area` WHERE `spell` = 74411 AND `area` = 3317;

-- 13. Remove invalid fishing_loot_template entry (area 3317 not valid)
DELETE FROM `fishing_loot_template` WHERE `entry` = 3317;

-- 14. Fix item_template display IDs
--     300011/300012: displayid 64584 is invalid → use 70000 (generic token icon)
UPDATE `item_template` SET `displayid` = 70000 WHERE `entry` IN (300011, 300012);
--     300313–300331: displayid 68750 is invalid → use 32837
UPDATE `item_template` SET `displayid` = 32837 WHERE `entry` BETWEEN 300313 AND 300331;

-- 15. Fix item_template class for 300311/300312: class=10 (Money) is obsolete
--     → class=15 (Miscellaneous), subclass=0 (Junk)
UPDATE `item_template` SET `class` = 15, `subclass` = 0 WHERE `entry` IN (300311, 300312);
