-- Hyjal Frontier - NPC equipment loadouts
--
-- creature_equip_template (CreatureID, ID=1, ItemID1=main, ItemID2=off, ItemID3=ranged)
-- After inserting rows, sets creature_template.equipment_id=1 for the affected entries.
--
-- Item IDs are existing item_template entries with known visible models:
--   40345  Broken Promise       - sword 1H (ilvl 213), disp 54878  → Alliance guards/commanders
--   40402  Last Laugh           - axe  1H (ilvl 226), disp 55906  → Horde guards/warriors
--   49976  Bulwark of Smouldering Steel - shield (ilvl 264), disp 65030  → tank slots
--   49992  Nibelung             - staff  (ilvl 264), disp 64342  → druid/caster NPCs
--   49982  Heartpierce          - dagger (ilvl 264), disp 64669  → scouts/rogues
--   50028  Trauma               - mace 1H (ilvl 264), disp 64514 → shaman/priest NPCs
--   50178  Bloodfall            - polearm (ilvl 264), disp 64379 → huntress/ranger NPCs
--   49919  Cryptmaker           - mace 2H (ilvl 264), disp 64393 → Horde commanders

-- Note: equip rows for quest-giver templates 830030-830039 are in 10_NPCs_Quests.sql
-- because those creature_template entries are created there (after this file runs).
DELETE FROM `creature_equip_template`
WHERE `CreatureID` IN (
    830020,830021,830022,830023,830024,
    830145,830146,830147
);

INSERT INTO `creature_equip_template`
    (`CreatureID`,`ID`,`ItemID1`,`ItemID2`,`ItemID3`,`VerifiedBuild`)
VALUES
-- Alliance service NPCs (templates exist from 05_Start_NPCs.sql)
(830020, 1,  40345, 49976,     0, 0),  -- Hyjal Flight Master:      sword+shield (ceremonial)
(830021, 1,  40345, 49976,     0, 0),  -- Encampment Guard:          sword+shield
(830022, 1,  40402,     0,     0, 0),  -- Vanguard Grunt:            axe 1H
(830023, 1,      0,     0,     0, 0),  -- Innkeeper Cerelina:        unarmed (civilian)
(830024, 1,      0,     0,     0, 0),  -- Emberwood Quartermaster:   unarmed (vendor)
-- Horde service NPCs (templates exist from 05b_Town_NPCs.sql)
(830145, 1,  40402, 49976,     0, 0),  -- Vanguard Flight Master:    axe+shield
(830146, 1,      0,     0,     0, 0),  -- Innkeeper Garruka:         unarmed
(830147, 1,      0,     0,     0, 0);  -- Emberwood Quartermaster:   unarmed

-- equipment_id lives on the creature SPAWN row, not creature_template.
-- The spawn INSERT rows in 05b and 10 already reference equipment_id directly.
-- Run this UPDATE after those files are applied to correct any existing rows
-- and to future-proof manual spawns added outside these SQL files.
-- Service NPCs only (quest giver equip update is handled in 10_NPCs_Quests.sql)
UPDATE `creature` SET `equipment_id`=1
WHERE `map`=1410
  AND `id1` IN (830020,830021,830022,830023,830024,830145,830146,830147);
