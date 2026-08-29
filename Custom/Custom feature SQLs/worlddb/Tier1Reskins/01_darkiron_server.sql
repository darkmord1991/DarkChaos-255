-- Dark Iron Dwarf (race 27): the SERVER half.
--
-- The client half (ChrRaces/CharSections/CharHairGeosets/CharacterFacialHairStyles/CharBaseInfo
-- + textures + glue) is already deployed, which is why the race shows up in the create screen.
-- Player::Create validates the race/class pair against playercreateinfo, which had no rows for
-- 27 -- hence "invalid race/class pair (27/11) - refusing to do so".
--
-- Dark Iron is a RESKIN of the Dwarf: same model, same everything server-side. So every table
-- below is cloned from race 3 rather than hand-authored, which keeps it correct by construction
-- and makes the other Tier-1 races a one-line change.
--
-- No worldserver rebuild: the core has no MAX_RACES constant and reads races from ChrRaces at
-- runtime. Adding RACE_DARK_IRON_DWARF = 27 to SharedDefines.h is only needed for typed C++ use
-- (racials), exactly as the Pandaren comment there notes.
--
-- Race 27 bit = 1 << 26 = 67108864 (Alliance).

-- --------------------------------------------------------------------------------------------
-- 1. chrraces_dbc: the server-side ChrRaces row.
--    ClientFileString stays 'Dwarf' so the classic v264 model loads; only the identity differs.
--    Locale name slots are left empty except enUS -- see Pandaren/14_chrraces_locale_name_fix.sql
--    for what copying a donor's locale strings costs.
DELETE FROM `chrraces_dbc` WHERE `ID` = 27;
INSERT INTO `chrraces_dbc` (`ID`, `Flags`, `FactionID`, `ExplorationSoundID`, `MaleDisplayId`,
    `FemaleDisplayId`, `ClientPrefix`, `BaseLanguage`, `CreatureType`, `ResSicknessSpellID`,
    `SplashSoundID`, `ClientFilestring`, `CinematicSequenceID`, `Alliance`, `Name_Lang_enUS`,
    `Name_Lang_Mask`, `Name_Female_Lang_Mask`, `Name_Male_Lang_Mask`,
    `FacialHairCustomization_1`, `FacialHairCustomization_2`, `HairCustomization`,
    `Required_Expansion`)
SELECT 27, `Flags`, `FactionID`, `ExplorationSoundID`, `MaleDisplayId`, `FemaleDisplayId`,
    'Di', `BaseLanguage`, `CreatureType`, `ResSicknessSpellID`, `SplashSoundID`, 'Dwarf', 0,
    `Alliance`, 'Dark Iron Dwarf', `Name_Lang_Mask`, `Name_Female_Lang_Mask`, `Name_Male_Lang_Mask`,
    `FacialHairCustomization_1`, `FacialHairCustomization_2`, `HairCustomization`, `Required_Expansion`
FROM (SELECT * FROM `chrraces_dbc` WHERE `ID` = 3) AS dwarf;

-- --------------------------------------------------------------------------------------------
-- 2. Start position, action bars and base stats -- cloned from the dwarf for all ten classes.
DELETE FROM `playercreateinfo` WHERE `race` = 27;
INSERT INTO `playercreateinfo` (`race`, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`)
SELECT 27, `class`, `map`, `zone`, `position_x`, `position_y`, `position_z`, `orientation`
FROM (SELECT * FROM `playercreateinfo` WHERE `race` = 3) AS d;

DELETE FROM `playercreateinfo_action` WHERE `race` = 27;
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`)
SELECT 27, `class`, `button`, `action`, `type`
FROM (SELECT * FROM `playercreateinfo_action` WHERE `race` = 3) AS d;

DELETE FROM `player_race_stats` WHERE `Race` = 27;
INSERT INTO `player_race_stats` (`Race`, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`)
SELECT 27, `Strength`, `Agility`, `Stamina`, `Intellect`, `Spirit`
FROM (SELECT * FROM `player_race_stats` WHERE `Race` = 3) AS d;

-- --------------------------------------------------------------------------------------------
-- 3. Class spells, cloned from the dwarf's rows.
--
-- Cloned per-class from an actual dwarf rather than intersected across two races: that
-- intersection is what silently dropped Mail from hunters and shamans and every one-handed
-- weapon from warriors and druids on all five earlier custom races (AlliedRaces/14_).
-- Dwarf racials are excluded -- Dark Iron gets its own later.
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` = 67108864;
INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 67108864, `classmask`, `Spell`, CONCAT('Dark Iron - ', IFNULL(`Note`, CAST(`Spell` AS CHAR)))
FROM (SELECT * FROM `playercreateinfo_spell_custom` WHERE `racemask` = 4) AS d
-- The dwarf-only spells, derived by diffing race 4 against race 1 rather than recalled:
--   672 Language Dwarven, 2481 Find Treasure, 20594 Stoneform, 20595 Gun Specialization,
--   20596 Frost Resistance. 197 (Two-Handed Axes) and 5149 also differ but are class
--   proficiencies, not racials, so they are kept.
WHERE `Spell` NOT IN (672, 2481, 20594, 20595, 20596);

-- Language Common, granted to every class (classmask 0), matching how the other races do it.
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` = 67108864 AND `Spell` = 668;
INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`) VALUES
(67108864, 0, 668, 'Dark Iron - Language Common');

-- --------------------------------------------------------------------------------------------
-- 4. Race-gated content: open everything an Alliance stock race may already use.
--
-- Same faction-wide rule as AlliedRaces/14_ and /15_: test for ANY stock Alliance race (3149),
-- never just the Human bit -- that narrower test cost ~3,000 items per race last time. The
-- SkillLineAbility pass keeps the >=3-races guard so Dark Iron does not inherit other races'
-- racials.
-- playercreateinfo_skills GRANTS skills at creation, so a blunt faction sweep here is wrong:
-- the table also holds each race's own language and racial, keyed by a single race bit. The
-- first version of this file handed Dark Iron the Human, Night Elf, Gnome, Draenei and Worgen
-- racials plus Darnassian, Gnomish and Draenei. Same >=3-races test as the SkillLineAbility
-- pass: a racial names one race, a faction-wide skill names the whole faction.
--
-- (The skillraceclassinfo_dbc sweep below stays blunt on purpose -- that table only VALIDATES
-- which skills a race/class may keep, so being permissive there grants nothing.)
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` & ~67108864
    WHERE (`raceMask` & 67108864) <> 0 AND BIT_COUNT(`raceMask` & 3149) < 3;
UPDATE `playercreateinfo_skills` SET `raceMask` = `raceMask` | 67108864
    WHERE `raceMask` <> 0 AND BIT_COUNT(`raceMask` & 3149) >= 3;

UPDATE `skillraceclassinfo_dbc` SET `RaceMask` = `RaceMask` | 67108864
    WHERE `RaceMask` <> -1 AND (`RaceMask` & 3149) <> 0;

-- ORDER MATTERS: skilllineability_dbc is empty on a stock install, so this UPDATE only
-- reaches rows AlliedRaces/15_skilllineability_faction_spells.sql has already inserted.
-- Run that file first, or Dark Iron loses the mage portals / paladin seals / Bloodlust set.
UPDATE `skilllineability_dbc` SET `RaceMask` = `RaceMask` | 67108864
    WHERE `RaceMask` <> 0 AND (`RaceMask` & 3149) <> 0;

UPDATE `item_template` SET `AllowableRace` = `AllowableRace` | 67108864
    WHERE `AllowableRace` NOT IN (-1, 0) AND (`AllowableRace` & 3149) <> 0;

UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces` | 67108864
    WHERE `AllowableRaces` NOT IN (0, 2147483647, 4294967295) AND (`AllowableRaces` & 3149) <> 0;
