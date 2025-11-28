-- ====================================================================================
-- HEIRLOOM ITEMS 300332-300364 - ADD SECONDARY STATS FOR AUTO-SCALING
-- ====================================================================================
-- Date: November 26, 2025
-- Database: acore_world
--
-- PURPOSE:
--   Add secondary stats (Crit, Haste, Hit, Expertise, etc.) to heirloom items so they
--   scale automatically with player level via the heirloom_scaling_255.cpp system.
--
-- STAT TYPES (WoTLK):
--   32 = Crit Rating
--   36 = Haste Rating
--   31 = Hit Rating
--   37 = Expertise Rating
--   45 = Spell Power
--   38 = Attack Power
--   44 = Armor Penetration
--   12 = Defense Rating
--   13 = Dodge Rating
--   14 = Parry Rating
--
-- DESIGN:
--   - Weapons: Add Crit + Haste (DPS) or Hit + Expertise (Physical)
--   - Armor (STR): Add Crit + Hit (melee DPS)
--   - Armor (AGI): Add Crit + Haste (agility DPS)
--   - Armor (INT): Add Haste + Crit (caster)
--   - Values are base values that will scale with level
-- ====================================================================================

-- ====================================================================================
-- WEAPONS (300332-300340)
-- ====================================================================================

-- 300332: Heirloom Flamefury Blade (Sword, STR) - Crit + Haste
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 15,   -- Crit Rating
    `stat_type3` = 36, `stat_value3` = 12    -- Haste Rating
WHERE `entry` = 300332;

-- 300333: Heirloom Stormfury (Sword, STR) - Hit + Expertise
UPDATE `item_template` SET 
    `stat_type2` = 31, `stat_value2` = 14,   -- Hit Rating
    `stat_type3` = 37, `stat_value3` = 14    -- Expertise Rating
WHERE `entry` = 300333;

-- 300334: Heirloom Frostbite Axe (Axe, STR) - Crit + Armor Penetration
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 18,   -- Crit Rating
    `stat_type3` = 44, `stat_value3` = 12    -- Armor Penetration
WHERE `entry` = 300334;

-- 300335: Heirloom Shadow Dagger (Dagger, AGI) - Crit + Haste
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 12,   -- Crit Rating
    `stat_type3` = 36, `stat_value3` = 10    -- Haste Rating
WHERE `entry` = 300335;

-- 300336: Heirloom Arcane Staff (Staff, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 15,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 12    -- Crit Rating
WHERE `entry` = 300336;

-- 300337: Heirloom Zephyr Bow (Bow, AGI) - Crit + Haste
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 14,   -- Crit Rating
    `stat_type3` = 36, `stat_value3` = 10    -- Haste Rating
WHERE `entry` = 300337;

-- 300338: Heirloom Arcane Wand (Wand, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 10,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 8     -- Crit Rating
WHERE `entry` = 300338;

-- 300339: Heirloom Earthshaker Mace (Mace, STR) - Hit + Crit
UPDATE `item_template` SET 
    `stat_type2` = 31, `stat_value2` = 14,   -- Hit Rating
    `stat_type3` = 32, `stat_value3` = 14    -- Crit Rating
WHERE `entry` = 300339;

-- 300340: Heirloom Polearm (Polearm, STR) - Crit + Armor Penetration
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 16,   -- Crit Rating
    `stat_type3` = 44, `stat_value3` = 10    -- Armor Penetration
WHERE `entry` = 300340;

-- ====================================================================================
-- ARMOR - HEAD (300341-300343)
-- ====================================================================================

-- 300341: Heirloom War Crown (Plate, STR) - Crit + Hit
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 16,   -- Crit Rating
    `stat_type3` = 31, `stat_value3` = 12    -- Hit Rating
WHERE `entry` = 300341;

-- 300342: Heirloom Battle Helm (Plate, STA) - Defense + Dodge
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 20,   -- Defense Rating
    `stat_type3` = 13, `stat_value3` = 14    -- Dodge Rating
WHERE `entry` = 300342;

-- 300343: Heirloom Kingly Circlet (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 16,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 12    -- Crit Rating
WHERE `entry` = 300343;

-- ====================================================================================
-- ARMOR - SHOULDERS (300344-300346)
-- ====================================================================================

-- 300344: Heirloom Mantle of Honor (Plate, STR) - Crit + Expertise
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 12,   -- Crit Rating
    `stat_type3` = 37, `stat_value3` = 10    -- Expertise Rating
WHERE `entry` = 300344;

-- 300345: Heirloom Shoulders of Valor (Plate, STA) - Defense + Parry
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 16,   -- Defense Rating
    `stat_type3` = 14, `stat_value3` = 10    -- Parry Rating
WHERE `entry` = 300345;

-- 300346: Heirloom Pauldrons of Wisdom (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 12,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 10    -- Crit Rating
WHERE `entry` = 300346;

-- ====================================================================================
-- ARMOR - CHEST (300347-300349)
-- ====================================================================================

-- 300347: Heirloom Chestplate of the Champion (Plate, STR) - Crit + Hit
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 20,   -- Crit Rating
    `stat_type3` = 31, `stat_value3` = 16    -- Hit Rating
WHERE `entry` = 300347;

-- 300348: Heirloom Battleplate (Plate, STA) - Defense + Dodge
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 24,   -- Defense Rating
    `stat_type3` = 13, `stat_value3` = 18    -- Dodge Rating
WHERE `entry` = 300348;

-- 300349: Heirloom Robes of Insight (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 20,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 16    -- Crit Rating
WHERE `entry` = 300349;

-- ====================================================================================
-- ARMOR - WRISTS (300350-300352)
-- ====================================================================================

-- 300350: Heirloom Vambraces of Might (Plate, STR) - Crit + Expertise
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 10,   -- Crit Rating
    `stat_type3` = 37, `stat_value3` = 8     -- Expertise Rating
WHERE `entry` = 300350;

-- 300351: Heirloom Bracers of Battle (Plate, STA) - Defense + Dodge
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 12,   -- Defense Rating
    `stat_type3` = 13, `stat_value3` = 8     -- Dodge Rating
WHERE `entry` = 300351;

-- 300352: Heirloom Cuffs of the Magi (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 10,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 8     -- Crit Rating
WHERE `entry` = 300352;

-- ====================================================================================
-- ARMOR - HANDS (300353-300355)
-- ====================================================================================

-- 300353: Heirloom Gauntlets of Strength (Plate, STR) - Crit + Hit
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 14,   -- Crit Rating
    `stat_type3` = 31, `stat_value3` = 10    -- Hit Rating
WHERE `entry` = 300353;

-- 300354: Heirloom Grips of Precision (Plate, STA) - Defense + Parry
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 16,   -- Defense Rating
    `stat_type3` = 14, `stat_value3` = 10    -- Parry Rating
WHERE `entry` = 300354;

-- 300355: Heirloom Gloves of Sorcery (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 14,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 10    -- Crit Rating
WHERE `entry` = 300355;

-- ====================================================================================
-- ARMOR - WAIST (300356-300358)
-- ====================================================================================

-- 300356: Heirloom Girdle of Power (Plate, STR) - Crit + Expertise
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 12,   -- Crit Rating
    `stat_type3` = 37, `stat_value3` = 10    -- Expertise Rating
WHERE `entry` = 300356;

-- 300357: Heirloom Belt of Agility (Plate, STA) - Defense + Dodge
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 14,   -- Defense Rating
    `stat_type3` = 13, `stat_value3` = 10    -- Dodge Rating
WHERE `entry` = 300357;

-- 300358: Heirloom Cord of Intellect (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 12,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 10    -- Crit Rating
WHERE `entry` = 300358;

-- ====================================================================================
-- ARMOR - LEGS (300359-300361)
-- ====================================================================================

-- 300359: Heirloom Legplates of the Conqueror (Plate, STR) - Crit + Hit
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 18,   -- Crit Rating
    `stat_type3` = 31, `stat_value3` = 14    -- Hit Rating
WHERE `entry` = 300359;

-- 300360: Heirloom Leggings of Swiftness (Plate, STA) - Defense + Parry
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 20,   -- Defense Rating
    `stat_type3` = 14, `stat_value3` = 14    -- Parry Rating
WHERE `entry` = 300360;

-- 300361: Heirloom Trousers of Arcane Power (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 18,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 14    -- Crit Rating
WHERE `entry` = 300361;

-- ====================================================================================
-- ARMOR - FEET (300362-300364)
-- ====================================================================================

-- 300362: Heirloom Sabatons of Fury (Plate, STR) - Crit + Expertise
UPDATE `item_template` SET 
    `stat_type2` = 32, `stat_value2` = 14,   -- Crit Rating
    `stat_type3` = 37, `stat_value3` = 10    -- Expertise Rating
WHERE `entry` = 300362;

-- 300363: Heirloom Boots of Haste (Plate, STA) - Defense + Dodge
UPDATE `item_template` SET 
    `stat_type2` = 12, `stat_value2` = 16,   -- Defense Rating
    `stat_type3` = 13, `stat_value3` = 10    -- Dodge Rating
WHERE `entry` = 300363;

-- 300364: Heirloom Sandals of Brilliance (Cloth, INT) - Haste + Crit
UPDATE `item_template` SET 
    `stat_type2` = 36, `stat_value2` = 14,   -- Haste Rating
    `stat_type3` = 32, `stat_value3` = 10    -- Crit Rating
WHERE `entry` = 300364;

-- ====================================================================================
-- UPDATE ITEM DESCRIPTIONS
-- ====================================================================================

UPDATE `item_template` SET 
    `description` = 'Stats scale with your level. A true adventurer\'s companion.'
WHERE `entry` BETWEEN 300332 AND 300364;

-- ====================================================================================
-- END OF FILE
-- ====================================================================================
-- Summary:
--   - Added stat_type2 and stat_value2 (primary secondary stat) to all 33 items
--   - Added stat_type3 and stat_value3 (additional secondary stat) to all 33 items
--   - Secondary stats chosen based on item's primary stat type:
--     * STR items: Crit + Hit/Expertise/ArP
--     * STA items: Defense + Dodge/Parry (tank stats)
--     * INT items: Haste + Crit (caster stats)
--     * AGI items: Crit + Haste
--   - Updated descriptions to remove upgrade references
-- ====================================================================================
