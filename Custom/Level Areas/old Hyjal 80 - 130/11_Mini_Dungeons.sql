-- Hyjal Frontier - mini-dungeon content pack (90-125)
--
-- This file adds five manual-spawn mini-dungeon sets:
--   1) Ashvein Warrens    (level 90)
--   2) Cindervault        (level 100)
--   3) Gravebloom Den     (level 110)
--   4) Rootshadow Hollow  (level 120)
--   5) The Gilded Depths  (level 125 gold mine)
--
-- Contents:
--   * 25 created signature items (400125-400149)
--   * 5 reference_loot_template pools (14120-14124)
--   * 25 creature templates for dungeon enemies and bosses (830110-830134)
--   * 5 standalone quests (81230-81234) wired through existing Hyjal commanders
--
-- No creature spawn rows are included here. Dungeon interiors and encounter
-- placements are expected to be handled manually.

-- -----------------------------------------------------------------------------
-- Cleanup
-- -----------------------------------------------------------------------------
DELETE FROM `creature_queststarter` WHERE `quest` BETWEEN 81230 AND 81234;
DELETE FROM `creature_questender`   WHERE `quest` BETWEEN 81230 AND 81234;
DELETE FROM `quest_request_items`   WHERE `ID`    BETWEEN 81230 AND 81234;
DELETE FROM `quest_offer_reward`    WHERE `ID`    BETWEEN 81230 AND 81234;
DELETE FROM `quest_template_addon`  WHERE `ID`    BETWEEN 81230 AND 81234;
DELETE FROM `quest_template`        WHERE `ID`    BETWEEN 81230 AND 81234;

DELETE FROM `creature_loot_template`
WHERE `Entry` IN (830114, 830119, 830124, 830129, 830134);

DELETE FROM `reference_loot_template`
WHERE `Entry` BETWEEN 14120 AND 14124;

DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 830110 AND 830134;
DELETE FROM `creature_template`       WHERE `entry`      BETWEEN 830110 AND 830134;

DELETE FROM `item_template`
WHERE `entry` BETWEEN 400125 AND 400149;

-- -----------------------------------------------------------------------------
-- Created signature items
-- -----------------------------------------------------------------------------
INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`,
     `displayid`, `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`,
     `SellPrice`, `InventoryType`, `AllowableClass`, `AllowableRace`,
     `ItemLevel`, `RequiredLevel`, `maxcount`, `stackable`, `ContainerSlots`,
     `stat_type1`, `stat_value1`, `stat_type2`, `stat_value2`,
     `stat_type3`, `stat_value3`, `stat_type4`, `stat_value4`,
     `stat_type5`, `stat_value5`, `armor`, `bonding`, `description`,
     `VerifiedBuild`)
VALUES
-- Ashvein Warrens (level 90)
(400125, 4, 0, -1, 'Ashvein Spell Loop',
    64170, 4, 0, 0, 1, 0,
    110864, 11, -1, -1,
    324, 90, 0, 1, 0,
    45, 132, 7, 94,
    5, 94, 32, 82,
    36, 71,  0, 1,
    'Signature Ashvein Warrens reward for caster builds.', 0),
(400126, 4, 0, -1, 'Ashvein Renewal Loop',
    33864, 4, 0, 0, 1, 0,
    110864, 11, -1, -1,
    324, 90, 0, 1, 0,
    45, 132, 7, 94,
    5, 94, 6, 82,
    36, 71,  0, 1,
    'Signature Ashvein Warrens reward for healer builds.', 0),
(400127, 4, 0, -1, 'Ashvein Predator Loop',
    64225, 4, 0, 0, 1, 0,
    110864, 11, -1, -1,
    324, 90, 0, 1, 0,
    38, 151, 3, 121,
    7, 107, 32, 82,
    37, 71,  0, 1,
    'Signature Ashvein Warrens reward for agility builds.', 0),
(400128, 4, 0, -1, 'Ashvein War Loop',
    64176, 4, 0, 0, 1, 0,
    110864, 11, -1, -1,
    324, 90, 0, 1, 0,
    4, 129, 7, 139,
    32, 82, 36, 71,
    0,  0,  0, 1,
    'Signature Ashvein Warrens reward for strength builds.', 0),
(400129, 4, 0, -1, 'Ashvein Bastion Loop',
    64229, 4, 0, 0, 1, 0,
    110864, 11, -1, -1,
    324, 90, 0, 1, 0,
    4, 94, 7, 168,
    12, 71, 13, 71,
    14, 58,  0, 1,
    'Signature Ashvein Warrens reward for tank builds.', 0),

-- Cindervault (level 100)
(400130, 4, 1, -1, 'Cindervault Spelldrape',
    28951, 4, 0, 0, 1, 0,
    145000, 16, -1, -1,
    348, 100, 0, 1, 0,
    45, 154, 7, 110,
    5, 110, 32, 96,
    36, 84, 220, 1,
    'Signature Cindervault reward for caster builds.', 0),
(400131, 4, 1, -1, 'Cindervault Lifedrape',
    64300, 4, 0, 0, 1, 0,
    145000, 16, -1, -1,
    348, 100, 0, 1, 0,
    45, 154, 7, 110,
    5, 110, 6, 96,
    36, 84, 220, 1,
    'Signature Cindervault reward for healer builds.', 0),
(400132, 4, 1, -1, 'Cindervault Skulker Drape',
    64326, 4, 0, 0, 1, 0,
    145000, 16, -1, -1,
    348, 100, 0, 1, 0,
    38, 178, 3, 142,
    7, 142, 32, 96,
    44, 84, 220, 1,
    'Signature Cindervault reward for agility builds.', 0),
(400133, 4, 1, -1, 'Cindervault Warmantle',
    64307, 4, 0, 0, 1, 0,
    145000, 16, -1, -1,
    348, 100, 0, 1, 0,
    4, 149, 7, 161,
    32, 96, 36, 84,
    0,  0, 220, 1,
    'Signature Cindervault reward for strength builds.', 0),
(400134, 4, 1, -1, 'Cindervault Bulwark Drape',
    54674, 4, 0, 0, 1, 0,
    145000, 16, -1, -1,
    348, 100, 0, 1, 0,
    4, 110, 7, 194,
    12, 96, 13, 96,
    31, 61, 220, 1,
    'Signature Cindervault reward for tank builds.', 0),

-- Gravebloom Den (level 110)
(400135, 4, 0, -1, 'Gravebloom Spellchain',
    64219, 4, 0, 0, 1, 0,
    183553, 2, -1, -1,
    372, 110, 0, 1, 0,
    45, 184, 7, 131,
    5, 131, 31, 114,
    36, 99,  0, 1,
    'Signature Gravebloom Den reward for caster builds.', 0),
(400136, 4, 0, -1, 'Gravebloom Mercy Chain',
    64190, 4, 0, 0, 1, 0,
    183553, 2, -1, -1,
    372, 110, 0, 1, 0,
    45, 184, 7, 131,
    5, 131, 6, 114,
    36, 99,  0, 1,
    'Signature Gravebloom Den reward for healer builds.', 0),
(400137, 4, 0, -1, 'Gravebloom Talon Chain',
    6510, 4, 0, 0, 1, 0,
    183553, 2, -1, -1,
    372, 110, 0, 1, 0,
    38, 214, 3, 171,
    7, 150, 44, 114,
    32, 99,  0, 1,
    'Signature Gravebloom Den reward for agility builds.', 0),
(400138, 4, 0, -1, 'Gravebloom Warchain',
    64173, 4, 0, 0, 1, 0,
    183553, 2, -1, -1,
    372, 110, 0, 1, 0,
    4, 181, 7, 196,
    32, 114, 44, 99,
    0,  0,   0, 1,
    'Signature Gravebloom Den reward for strength builds.', 0),
(400139, 4, 0, -1, 'Gravebloom Aegis Chain',
    64211, 4, 0, 0, 1, 0,
    183553, 2, -1, -1,
    372, 110, 0, 1, 0,
    4, 131, 7, 236,
    12, 114, 13, 99,
    31, 87,   0, 1,
    'Signature Gravebloom Den reward for tank builds.', 0),

-- Rootshadow Hollow (level 120)
(400140, 4, 1, -1, 'Rootshadow Spellshroud',
    28951, 4, 0, 0, 1, 0,
    228000, 16, -1, -1,
    392, 120, 0, 1, 0,
    45, 195, 7, 139,
    5, 139, 32, 121,
    36, 105, 244, 1,
    'Signature Rootshadow Hollow reward for caster builds.', 0),
(400141, 4, 1, -1, 'Rootshadow Renewal Shroud',
    64300, 4, 0, 0, 1, 0,
    228000, 16, -1, -1,
    392, 120, 0, 1, 0,
    45, 195, 7, 139,
    5, 139, 6, 121,
    36, 105, 244, 1,
    'Signature Rootshadow Hollow reward for healer builds.', 0),
(400142, 4, 1, -1, 'Rootshadow Stalker Shroud',
    64326, 4, 0, 0, 1, 0,
    228000, 16, -1, -1,
    392, 120, 0, 1, 0,
    38, 228, 3, 182,
    7, 160, 32, 121,
    44, 105, 244, 1,
    'Signature Rootshadow Hollow reward for agility builds.', 0),
(400143, 4, 1, -1, 'Rootshadow Warshroud',
    64307, 4, 0, 0, 1, 0,
    228000, 16, -1, -1,
    392, 120, 0, 1, 0,
    4, 192, 7, 208,
    32, 121, 36, 105,
    0,  0,  244, 1,
    'Signature Rootshadow Hollow reward for strength builds.', 0),
(400144, 4, 1, -1, 'Rootshadow Ironbark Shroud',
    54674, 4, 0, 0, 1, 0,
    228000, 16, -1, -1,
    392, 120, 0, 1, 0,
    4, 139, 7, 248,
    12, 121, 13, 105,
    31, 92,  244, 1,
    'Signature Rootshadow Hollow reward for tank builds.', 0),

-- The Gilded Depths (level 125 gold mine)
(400145, 4, 0, -1, 'Gilded Depths Spell Torque',
    64219, 4, 0, 0, 1, 0,
    255000, 2, -1, -1,
    404, 125, 0, 1, 0,
    45, 205, 7, 146,
    5, 146, 31, 128,
    36, 111,  0, 1,
    'Signature Gilded Depths reward for caster builds.', 0),
(400146, 4, 0, -1, 'Gilded Depths Mercy Torque',
    64190, 4, 0, 0, 1, 0,
    255000, 2, -1, -1,
    404, 125, 0, 1, 0,
    45, 205, 7, 146,
    5, 146, 6, 128,
    36, 111,  0, 1,
    'Signature Gilded Depths reward for healer builds.', 0),
(400147, 4, 0, -1, 'Gilded Depths Talon Torque',
    6510, 4, 0, 0, 1, 0,
    255000, 2, -1, -1,
    404, 125, 0, 1, 0,
    38, 239, 3, 191,
    7, 168, 44, 128,
    32, 111,  0, 1,
    'Signature Gilded Depths reward for agility builds.', 0),
(400148, 4, 0, -1, 'Gilded Depths War Torque',
    64173, 4, 0, 0, 1, 0,
    255000, 2, -1, -1,
    404, 125, 0, 1, 0,
    4, 202, 7, 219,
    32, 128, 44, 111,
    0,  0,   0, 1,
    'Signature Gilded Depths reward for strength builds.', 0),
(400149, 4, 0, -1, 'Gilded Depths Vault Torque',
    64211, 4, 0, 0, 1, 0,
    255000, 2, -1, -1,
    404, 125, 0, 1, 0,
    4, 146, 7, 261,
    12, 128, 13, 111,
    31, 97,   0, 1,
    'Signature Gilded Depths reward for tank builds.', 0);

-- -----------------------------------------------------------------------------
-- Loot pools
-- -----------------------------------------------------------------------------
INSERT INTO `reference_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
     `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
(14120, 400125, 0, 0, 0, 1, 1, 1, 1, 'Ashvein pool - caster ring'),
(14120, 400126, 0, 0, 0, 1, 1, 1, 1, 'Ashvein pool - healer ring'),
(14120, 400127, 0, 0, 0, 1, 1, 1, 1, 'Ashvein pool - agility ring'),
(14120, 400128, 0, 0, 0, 1, 1, 1, 1, 'Ashvein pool - strength ring'),
(14120, 400129, 0, 0, 0, 1, 1, 1, 1, 'Ashvein pool - tank ring'),
(14121, 400130, 0, 0, 0, 1, 1, 1, 1, 'Cindervault pool - caster cloak'),
(14121, 400131, 0, 0, 0, 1, 1, 1, 1, 'Cindervault pool - healer cloak'),
(14121, 400132, 0, 0, 0, 1, 1, 1, 1, 'Cindervault pool - agility cloak'),
(14121, 400133, 0, 0, 0, 1, 1, 1, 1, 'Cindervault pool - strength cloak'),
(14121, 400134, 0, 0, 0, 1, 1, 1, 1, 'Cindervault pool - tank cloak'),
(14122, 400135, 0, 0, 0, 1, 1, 1, 1, 'Gravebloom pool - caster pendant'),
(14122, 400136, 0, 0, 0, 1, 1, 1, 1, 'Gravebloom pool - healer pendant'),
(14122, 400137, 0, 0, 0, 1, 1, 1, 1, 'Gravebloom pool - agility pendant'),
(14122, 400138, 0, 0, 0, 1, 1, 1, 1, 'Gravebloom pool - strength pendant'),
(14122, 400139, 0, 0, 0, 1, 1, 1, 1, 'Gravebloom pool - tank pendant'),
(14123, 400140, 0, 0, 0, 1, 1, 1, 1, 'Rootshadow pool - caster cloak'),
(14123, 400141, 0, 0, 0, 1, 1, 1, 1, 'Rootshadow pool - healer cloak'),
(14123, 400142, 0, 0, 0, 1, 1, 1, 1, 'Rootshadow pool - agility cloak'),
(14123, 400143, 0, 0, 0, 1, 1, 1, 1, 'Rootshadow pool - strength cloak'),
(14123, 400144, 0, 0, 0, 1, 1, 1, 1, 'Rootshadow pool - tank cloak'),
(14124, 400145, 0, 0, 0, 1, 1, 1, 1, 'Gilded Depths pool - caster pendant'),
(14124, 400146, 0, 0, 0, 1, 1, 1, 1, 'Gilded Depths pool - healer pendant'),
(14124, 400147, 0, 0, 0, 1, 1, 1, 1, 'Gilded Depths pool - agility pendant'),
(14124, 400148, 0, 0, 0, 1, 1, 1, 1, 'Gilded Depths pool - strength pendant'),
(14124, 400149, 0, 0, 0, 1, 1, 1, 1, 'Gilded Depths pool - tank pendant');

INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`,
     `GroupId`, `MinCount`, `MaxCount`, `Comment`)
VALUES
(830114, 14120, 14120, 100, 0, 1, 1, 1, 1, 'Foreman Droth - signature pool'),
(830119, 14121, 14121, 100, 0, 1, 1, 1, 1, 'Forgemaster Salhar - signature pool'),
(830124, 14122, 14122, 100, 0, 1, 1, 1, 1, 'Matron Vhalra - signature pool'),
(830129, 14123, 14123, 100, 0, 1, 1, 1, 1, 'Hollow Warden Azhul - signature pool'),
(830134, 14124, 14124, 100, 0, 1, 1, 1, 1, 'High Excavator Auriclash - signature pool');

-- -----------------------------------------------------------------------------
-- Dungeon creature templates (manual spawn placement expected)
-- -----------------------------------------------------------------------------
INSERT INTO `creature_template`
    (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `exp`,
     `faction`, `npcflag`, `speed_walk`, `speed_run`, `rank`,
     `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`,
     `unit_flags`, `dynamicflags`, `family`, `type`, `type_flags`,
     `lootid`, `mingold`, `maxgold`,
     `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`,
     `RegenHealth`, `flags_extra`, `ScriptName`, `VerifiedBuild`)
VALUES
-- Ashvein Warrens
(830110, 'Ashvein Laborer',        'Ashvein Warrens', 90, 91, 1,
    14, 0, 1, 1.14286, 0, 6.2, 2000, 2000, 1,
    0, 0, 0, 6, 0,
    0, 450, 900,
    18, 1, 1, 1,
    1, 0, '', 0),
(830111, 'Ashvein Bonepicker',     'Ashvein Warrens', 90, 92, 1,
    14, 0, 1, 1.14286, 0, 6.7, 2000, 2000, 1,
    0, 0, 0, 6, 0,
    0, 500, 950,
    19, 1, 1, 1,
    1, 0, '', 0),
(830112, 'Cinderslag Hexcaller',   'Ashvein Warrens', 91, 92, 1,
    14, 0, 1, 1.14286, 0, 7.1, 2000, 2000, 2,
    0, 0, 0, 6, 0,
    0, 550, 1000,
    20, 8, 1, 1,
    1, 0, '', 0),
(830113, 'Quarry Stitcher',        'Ashvein Warrens', 92, 93, 1,
    14, 0, 1, 1.14286, 1, 8.2, 2000, 2000, 1,
    0, 0, 0, 6, 0,
    0, 1200, 1800,
    24, 1, 2, 1,
    1, 0, '', 0),
(830114, 'Foreman Droth',          'Master of the Warrens', 93, 93, 1,
    14, 0, 1, 1.14286, 2, 10.4, 2000, 2000, 1,
    0, 0, 0, 6, 0,
    830114, 4000, 6500,
    32, 1, 2, 1,
    1, 0, '', 0),

-- Cindervault
(830115, 'Cindervault Impaler',    'Cindervault', 100, 101, 1,
    14, 0, 1, 1.14286, 0, 8.1, 2000, 2000, 1,
    0, 0, 0, 3, 0,
    0, 700, 1200,
    24, 1, 1, 1,
    1, 0, '', 0),
(830116, 'Smoldercoil Binder',     'Cindervault', 100, 102, 1,
    14, 0, 1, 1.14286, 0, 8.8, 2000, 2000, 2,
    0, 0, 0, 3, 0,
    0, 750, 1250,
    26, 8, 1, 1,
    1, 0, '', 0),
(830117, 'Furnaceguard Annihilator', 'Cindervault', 101, 102, 1,
    14, 0, 1, 1.14286, 1, 9.5, 2000, 2000, 1,
    0, 0, 0, 3, 0,
    0, 900, 1400,
    28, 1, 2, 1,
    1, 0, '', 0),
(830118, 'Magma Lash Captain',     'Cindervault Overseer', 102, 103, 1,
    14, 0, 1, 1.14286, 1, 10.6, 2000, 2000, 1,
    0, 0, 0, 3, 0,
    0, 1800, 2500,
    32, 1, 2, 1,
    1, 0, '', 0),
(830119, 'Forgemaster Salhar',     'Cindervault Master', 103, 103, 1,
    14, 0, 1, 1.14286, 2, 12.2, 2000, 2000, 1,
    0, 0, 0, 3, 0,
    830119, 6000, 9000,
    40, 2, 2, 1,
    1, 0, '', 0),

-- Gravebloom Den
(830120, 'Gravebloom Reaver',      'Gravebloom Den', 110, 111, 1,
    14, 0, 1, 1.14286, 0, 9.6, 2000, 2000, 1,
    0, 0, 0, 6, 0,
    0, 1000, 1600,
    32, 1, 1, 1,
    1, 0, '', 0),
(830121, 'Rimeweb Widow',          'Gravebloom Den', 110, 112, 1,
    14, 0, 1, 1.14286, 0, 10.1, 2000, 2000, 8,
    0, 0, 0, 6, 0,
    0, 1050, 1650,
    33, 1, 1, 1,
    1, 0, '', 0),
(830122, 'Frostscript Boneweaver', 'Gravebloom Den', 111, 112, 1,
    14, 0, 1, 1.14286, 0, 10.8, 2000, 2000, 2,
    0, 0, 0, 6, 0,
    0, 1150, 1750,
    35, 8, 1, 1,
    1, 0, '', 0),
(830123, 'Ossuary Patriarch',      'Gravebloom Den', 112, 113, 1,
    14, 0, 1, 1.14286, 1, 11.9, 2000, 2000, 1,
    0, 0, 0, 6, 0,
    0, 2500, 3500,
    40, 1, 2, 1,
    1, 0, '', 0),
(830124, 'Matron Vhalra',          'Mistress of Gravebloom', 113, 113, 1,
    14, 0, 1, 1.14286, 2, 13.4, 2000, 2000, 2,
    0, 0, 0, 6, 0,
    830124, 8500, 12000,
    48, 8, 2, 1,
    1, 0, '', 0),

-- Rootshadow Hollow
(830125, 'Rootshadow Dryad',       'Rootshadow Hollow', 120, 121, 1,
    14, 0, 1, 1.14286, 0, 11.0, 2000, 2000, 2,
    0, 0, 0, 7, 0,
    0, 1400, 2200,
    42, 8, 1, 1,
    1, 0, '', 0),
(830126, 'Thornscar Ancient',      'Rootshadow Hollow', 120, 122, 1,
    14, 0, 1, 1.14286, 1, 11.7, 2000, 2000, 1,
    0, 0, 0, 5, 0,
    0, 1500, 2300,
    45, 1, 2, 1,
    1, 0, '', 0),
(830127, 'Dreamblight Channeler',  'Rootshadow Hollow', 121, 122, 1,
    14, 0, 1, 1.14286, 0, 12.0, 2000, 2000, 2,
    0, 0, 0, 7, 0,
    0, 1600, 2400,
    44, 8, 1, 1,
    1, 0, '', 0),
(830128, 'Barkbreaker Colossus',   'Rootshadow Hollow', 122, 123, 1,
    14, 0, 1, 1.14286, 1, 12.8, 2000, 2000, 1,
    0, 0, 0, 5, 0,
    0, 3500, 5000,
    52, 1, 2, 1,
    1, 0, '', 0),
(830129, 'Hollow Warden Azhul',    'Keeper of the Rot', 123, 123, 1,
    14, 0, 1, 1.14286, 2, 14.2, 2000, 2000, 2,
    0, 0, 0, 7, 0,
    830129, 11000, 15000,
    58, 8, 2, 1,
    1, 0, '', 0),

-- The Gilded Depths
(830130, 'Gilded Excavator',       'The Gilded Depths', 125, 126, 1,
    14, 0, 1, 1.14286, 0, 12.4, 2000, 2000, 1,
    0, 0, 0, 7, 0,
    0, 1800, 2600,
    46, 1, 1, 1,
    1, 0, '', 0),
(830131, 'Cartel Blastminer',      'The Gilded Depths', 125, 126, 1,
    14, 0, 1, 1.14286, 0, 12.9, 2000, 2000, 2,
    0, 0, 0, 7, 0,
    0, 1900, 2700,
    47, 8, 1, 1,
    1, 0, '', 0),
(830132, 'Auric Veinshaper',       'The Gilded Depths', 126, 127, 1,
    14, 0, 1, 1.14286, 0, 13.2, 2000, 2000, 2,
    0, 0, 0, 7, 0,
    0, 2000, 2800,
    49, 8, 1, 1,
    1, 0, '', 0),
(830133, 'Veinbreaker Sentinel',   'The Gilded Depths', 127, 128, 1,
    14, 0, 1, 1.14286, 1, 13.8, 2000, 2000, 1,
    0, 0, 0, 5, 0,
    0, 4500, 6500,
    58, 1, 2, 1,
    1, 0, '', 0),
(830134, 'High Excavator Auriclash', 'Lord of the Lode', 128, 128, 1,
    14, 0, 1, 1.14286, 2, 15.1, 2000, 2000, 1,
    0, 0, 0, 5, 0,
    830134, 14000, 20000,
    66, 1, 2, 1,
    1, 0, '', 0);

INSERT INTO `creature_template_model`
    (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`,
     `VerifiedBuild`)
VALUES
(830110, 0, 571,   1.00, 1, 0),
(830111, 0, 8783,  1.00, 1, 0),
(830112, 0, 17537, 1.00, 1, 0),
(830113, 0, 12818, 1.00, 1, 0),
(830114, 0, 17308, 1.10, 1, 0),
(830115, 0, 17321, 1.00, 1, 0),
(830116, 0, 20930, 1.00, 1, 0),
(830117, 0, 15880, 1.00, 1, 0),
(830118, 0, 20930, 1.08, 1, 0),
(830119, 0, 1912,  1.10, 1, 0),
(830120, 0, 17311, 1.00, 1, 0),
(830121, 0, 17308, 1.00, 1, 0),
(830122, 0, 17537, 1.00, 1, 0),
(830123, 0, 12818, 1.05, 1, 0),
(830124, 0, 16919, 1.10, 1, 0),
(830125, 0, 17340, 1.00, 1, 0),
(830126, 0, 1460,  1.00, 1, 0),
(830127, 0, 17342, 1.00, 1, 0),
(830128, 0, 1461,  1.08, 1, 0),
(830129, 0, 15399, 1.05, 1, 0),
(830130, 0, 17339, 1.00, 1, 0),
(830131, 0, 17336, 1.00, 1, 0),
(830132, 0, 17337, 1.00, 1, 0),
(830133, 0, 1461,  1.05, 1, 0),
(830134, 0, 1460,  1.15, 1, 0);

-- -----------------------------------------------------------------------------
-- Quest templates
-- -----------------------------------------------------------------------------
INSERT INTO `quest_template`
    (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`,
     `QuestInfoID`, `RewardXPDifficulty`, `RewardMoney`, `AllowableRaces`,
     `LogTitle`, `LogDescription`, `QuestDescription`, `AreaDescription`,
     `QuestCompletionLog`, `RequiredNpcOrGo1`, `RequiredNpcOrGoCount1`,
     `RequiredNpcOrGo2`, `RequiredNpcOrGoCount2`,
     `RewardChoiceItemID1`, `RewardChoiceItemQuantity1`,
     `RewardChoiceItemID2`, `RewardChoiceItemQuantity2`,
     `RewardChoiceItemID3`, `RewardChoiceItemQuantity3`,
     `RewardChoiceItemID4`, `RewardChoiceItemQuantity4`,
     `RewardChoiceItemID5`, `RewardChoiceItemQuantity5`,
     `ObjectiveText1`, `ObjectiveText2`, `VerifiedBuild`)
VALUES
(81230, 2, 90, 90, 6101, 0, 5, 180000, 0,
 'Optional: Clear the Ashvein Warrens',
 'Purge Ashvein Laborers and slay Foreman Droth.',
 'Collapsed foothill tunnels beneath the ash line have become a hidden staging
route for corpse-haulers. Sweep out the Ashvein labor crews and put Foreman
Droth down before the warrens become a second front.',
 'Ashvein Warrens beneath the Foothills.',
 'The Ashvein Warrens are no longer feeding the front.',
 830110, 10, 830114, 1,
 400125, 1,
 400126, 1,
 400127, 1,
 400128, 1,
 400129, 1,
 'Ashvein Laborers slain', 'Foreman Droth slain', 0),

(81231, 2, 100, 100, 6102, 0, 6, 300000, 0,
 'Optional: Crack the Cindervault',
 'Break the Cindervault line and kill Forgemaster Salhar.',
 'An old furnace vault in the scorched groves is now being used to plate fresh
demons for the outer assault. Tear through the impaler crews and end
Forgemaster Salhar before another wave reaches the grove wards.',
 'Cindervault furnace chambers.',
 'The furnace line has gone cold.',
 830115, 12, 830119, 1,
 400130, 1,
 400131, 1,
 400132, 1,
 400133, 1,
 400134, 1,
 'Cindervault Impalers slain', 'Forgemaster Salhar slain', 0),

(81232, 2, 110, 110, 6103, 0, 7, 450000, 0,
 'Optional: Break the Gravebloom Den',
 'Cull Gravebloom Reavers and kill Matron Vhalra.',
 'The summit dead have hollowed a crypt-den beneath the ridge and are dragging
fresh corpses into the frost. Cut down the reavers and bring Matron Vhalra out
of the shadows before the den spills into the war camp.',
 'Gravebloom Den on the summit ridge.',
 'The den has collapsed into silence.',
 830120, 14, 830124, 1,
 400135, 1,
 400136, 1,
 400137, 1,
 400138, 1,
 400139, 1,
 'Gravebloom Reavers slain', 'Matron Vhalra slain', 0),

(81233, 2, 120, 120, 6104, 0, 8, 650000, 0,
 'Optional: Silence Rootshadow Hollow',
 'Defeat Rootshadow Dryads and kill Hollow Warden Azhul.',
 'A blighted hollow beneath Nordrassil''s lower roots is turning wardens and
dryads alike. Burn out the Rootshadow sentries and strike down Hollow Warden
Azhul before the rot reaches the upper root-lines.',
 'Rootshadow Hollow beneath the lower roots.',
 'The hollow is quiet and the roots are breathing again.',
 830125, 16, 830129, 1,
 400140, 1,
 400141, 1,
 400142, 1,
 400143, 1,
 400144, 1,
 'Rootshadow Dryads slain', 'Hollow Warden Azhul slain', 0),

(81234, 2, 125, 125, 6104, 0, 9, 900000, 0,
 'Optional: Strip the Gilded Depths',
 'Break the gold mine crews and kill High Excavator Auriclash.',
 'The largest surviving extraction site in Hyjal is a gold mine carved straight
through living roots and guarded by hired crews, spellcutters and auric
constructs. Collapse the operation by smashing the excavation teams and ending
High Excavator Auriclash at the heart of the lode.',
 'The Gilded Depths beneath Nordrassil.',
 'The gold mine lies broken and silent.',
 830130, 18, 830134, 1,
 400145, 1,
 400146, 1,
 400147, 1,
 400148, 1,
 400149, 1,
 'Gilded Excavators slain', 'High Excavator Auriclash slain', 0);

INSERT INTO `quest_template_addon`
    (`ID`, `PrevQuestID`, `NextQuestID`, `SpecialFlags`)
VALUES
(81230, 0, 0, 0),
(81231, 0, 0, 0),
(81232, 0, 0, 0),
(81233, 0, 0, 0),
(81234, 0, 0, 0);

INSERT INTO `quest_request_items`
    (`ID`, `EmoteOnComplete`, `EmoteOnIncomplete`, `CompletionText`,
     `VerifiedBuild`)
VALUES
(81230, 6, 0, 'Those tunnels were too close to the Foothills line.', 0),
(81231, 6, 0, 'If Salhar is still standing, the furnace is still feeding them.', 0),
(81232, 6, 0, 'The den keeps spitting bodies back onto the ridge. End it.', 0),
(81233, 6, 0, 'The hollow is poisoning every patrol path around it.', 0),
(81234, 6, 0, 'That mine is too rich and too dangerous to leave intact.', 0);

INSERT INTO `quest_offer_reward`
    (`ID`, `Emote1`, `Emote2`, `Emote3`, `Emote4`,
     `EmoteDelay1`, `EmoteDelay2`, `EmoteDelay3`, `EmoteDelay4`,
     `RewardText`, `VerifiedBuild`)
VALUES
(81230, 0, 0, 0, 0, 0, 0, 0, 0,
 'Good. The warrens can no longer reinforce the foothills.', 0),
(81231, 0, 0, 0, 0, 0, 0, 0, 0,
 'That furnace was powering more of their push than we realized.', 0),
(81232, 0, 0, 0, 0, 0, 0, 0, 0,
 'The summit can hold while Gravebloom lies broken.', 0),
(81233, 0, 0, 0, 0, 0, 0, 0, 0,
 'Well struck. Rootshadow Hollow will not spread any farther today.', 0),
(81234, 0, 0, 0, 0, 0, 0, 0, 0,
 'Excellent. Without that mine, Auriclash loses the whole operation.', 0);

INSERT INTO `creature_queststarter` (`id`, `quest`) VALUES
(830031, 81230),
(830036, 81230),
(830032, 81231),
(830037, 81231),
(830033, 81232),
(830038, 81232),
(830033, 81233),
(830038, 81233),
(830034, 81234),
(830039, 81234);

INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(830031, 81230),
(830036, 81230),
(830032, 81231),
(830037, 81231),
(830033, 81232),
(830038, 81232),
(830033, 81233),
(830038, 81233),
(830034, 81234),
(830039, 81234);