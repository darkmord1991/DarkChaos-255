-- Playability fixes for every custom race: Pandaren (22/23), Vulpera (24), Zandalari (25),
-- Kul Tiran (26).
--
-- Found 2026-08-28 from a report that a Zandalari druid "cannot wear anything". The druid was a
-- red herring: three separate defects, all of which hit EVERY custom race and EVERY class, and
-- two of which the Pandaren port has carried since it shipped.
--
-- Race bits:  Pandaren-A 2097152  Pandaren-H 4194304  Vulpera 8388608
--             Zandalari 16777216  Kul Tiran 33554432
-- Stock race bits by faction:
--   Alliance  Human 1, Dwarf 4, NightElf 8, Gnome 64, Draenei 1024, Worgen 2048  = 3149
--   Horde     Orc 2, Undead 16, Tauren 32, Troll 128, Goblin 256, BloodElf 512   =  946
-- Custom bits by faction:
--   Alliance  2097152 | 33554432                                       = 35651584
--   Horde     4194304 | 8388608 | 16777216                             = 29360128


-- ---------------------------------------------------------------------------------------------
-- 1. THE "cannot wear anything" BUG -- SkillRaceClassInfo racemasks.
--
-- The armour skill lines (293 Plate, 413 Mail, 414 Leather, 415 Cloth) all carried RaceMask
-- 6295551, which is the PANDAREN-ERA all-races mask (4095 | 2097152 | 4194304). The three allied
-- races are not in it, so although their proficiency spells (9077 Leather, 9078 Cloth, 8737 Mail)
-- were granted correctly, the skill each one confers was refused for the race and no armour could
-- be equipped at all. 114 of the 187 rows in this table were affected.
--
-- The faction test is "does this row already admit ANY stock race of that faction", not "does it
-- admit Human/Orc" -- see defect 2 for what the narrower test costs.
UPDATE `skillraceclassinfo_dbc` SET `RaceMask` = `RaceMask` | 35651584
    WHERE `RaceMask` <> -1 AND (`RaceMask` & 3149) <> 0;
UPDATE `skillraceclassinfo_dbc` SET `RaceMask` = `RaceMask` | 29360128
    WHERE `RaceMask` <> -1 AND (`RaceMask` & 946) <> 0;


-- ---------------------------------------------------------------------------------------------
-- 2. item_template / quest_template race gating.
--
-- 06_race_mask_sweeps.sql keyed on the HUMAN bit for Alliance and the ORC bit for Horde, so
-- anything allowed to (say) Troll + Tauren + Undead but not Orc never opened to the new races.
-- Measured before this fix: 3,063 items and 88 quests blocked for Zandalari that a stock Troll
-- could use; 3,061 items and 50 quests for Kul Tiran against a stock Human.
--
-- item_template.AllowableRace is signed int, -1 = every race. quest_template.AllowableRaces is
-- int unsigned, 0 = every race -- different sentinels, hence the different guards.
UPDATE `item_template` SET `AllowableRace` = `AllowableRace` | 35651584
    WHERE `AllowableRace` NOT IN (-1, 0) AND (`AllowableRace` & 3149) <> 0;
UPDATE `item_template` SET `AllowableRace` = `AllowableRace` | 29360128
    WHERE `AllowableRace` NOT IN (-1, 0) AND (`AllowableRace` & 946) <> 0;

UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces` | 35651584
    WHERE `AllowableRaces` NOT IN (0, 2147483647, 4294967295) AND (`AllowableRaces` & 3149) <> 0;
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces` | 29360128
    WHERE `AllowableRaces` NOT IN (0, 2147483647, 4294967295) AND (`AllowableRaces` & 946) <> 0;


-- ---------------------------------------------------------------------------------------------
-- 3. Class spells the derivation dropped.
--
-- The custom races' class spells were built as the INTERSECTION of two stock races (human and
-- orc for the allied set). Anything one of those two lacks was silently lost, which is why every
-- custom race is missing exactly the same 13 rows -- Pandaren included, since it shipped.
--
-- The damage: hunters and shamans had no MAIL proficiency, hunters no Guns/Dual Wield/Parry,
-- warriors and druids no one-handed weapon at all.
DELETE FROM `playercreateinfo_spell_custom`
    WHERE `racemask` IN (2097152, 4194304, 8388608, 16777216, 33554432)
      AND ((`classmask` = 1    AND `Spell` IN (198, 1180))
        OR (`classmask` = 4    AND `Spell` IN (266, 674, 3127, 5149, 8737))
        OR (`classmask` = 64   AND `Spell` IN (8737, 20608, 25442))
        OR (`classmask` = 1024 AND `Spell` IN (198, 1180, 20719)));

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT r.racemask, s.classmask, s.Spell, s.Note FROM
(SELECT 2097152 AS racemask UNION ALL SELECT 4194304 UNION ALL SELECT 8388608
 UNION ALL SELECT 16777216 UNION ALL SELECT 33554432) r
CROSS JOIN
(SELECT    1 AS classmask,   198 AS Spell, 'Warrior - One-Handed Maces' AS Note
 UNION ALL SELECT    1,  1180, 'Warrior - Daggers'
 UNION ALL SELECT    4,   266, 'Hunter - Guns'
 UNION ALL SELECT    4,   674, 'Hunter - Dual Wield'
 UNION ALL SELECT    4,  3127, 'Hunter - Parry'
 UNION ALL SELECT    4,  5149, 'Hunter - Beast Training'
 UNION ALL SELECT    4,  8737, 'Hunter - Mail'
 UNION ALL SELECT   64,  8737, 'Shaman - Mail'
 UNION ALL SELECT   64, 20608, 'Shaman - Reincarnation'
 UNION ALL SELECT   64, 25442, 'Shaman - class spell mirrored from stock races'
 UNION ALL SELECT 1024,   198, 'Druid - One-Handed Maces'
 UNION ALL SELECT 1024,  1180, 'Druid - Daggers'
 UNION ALL SELECT 1024, 20719, 'Druid - Feline Grace') s;
