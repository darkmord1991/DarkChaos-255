-- =====================================================================
-- DarkChaos-255 Custom Buff System - Complete Implementation
-- =====================================================================
-- This file creates all custom buff spells for DarkChaos-255:
-- 1. Hotspot XP Buff (800001)
-- 2. Prestige Bonus Auras (800010-800019)
-- 3. Challenge Mode Aura Spells (800020-800028)
-- 
-- IMPORTANT: Updated to match actual DarkChaos-255 spell_dbc table structure
-- Column names use underscores: Effect_1, EffectAura_1, ImplicitTargetA_1, etc.
-- Primary key is `ID` (not `Id`)
-- =====================================================================

-- =====================================================================
-- Step 1: Remove old spell entries
-- =====================================================================

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 800001 AND 800028;
DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 800040 AND 800044;

-- =====================================================================
-- Step 1.5: Clear Equipment Requirements for Custom Spells
-- =====================================================================
-- DarkChaos custom spells (800000-899999) should not require specific equipment
-- to apply. Clear any lingering EquippedItemClass requirements that might block
-- aura application to players without the required item equipped.
-- This applies to prestige, challenge modes, and hotspot buffs.
-- =====================================================================


-- =====================================================================
-- =====================================================================
-- Spell ID: 800001 (Hotspot XP Buff)
-- Purpose: Marker aura for XP bonus when player is in hotspot zone
-- Aura Type: 4 (SPELL_AURA_DUMMY - marker only)
-- Effect: 6 (SPELL_EFFECT_APPLY_AURA)
-- Duration: 21 (Permanent while in hotspot)
-- Attributes: 0x10 (treat as ability so the aura remains visible and cancellable)
-- =====================================================================

-- CRITICAL: SpellIconID must match client Spell.dbc for buff icon to display!
-- ImplicitTargetA_1: 1 = TARGET_UNIT_CASTER (self) - MUST match client
-- DurationIndex: 42 = matches client (not 21!)
INSERT INTO `spell_dbc` 
(`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
 `Effect_1`, `EffectBasePoints_1`, `EffectMechanic_1`, `ImplicitTargetA_1`, `EffectAura_1`,
 `SpellIconID`, `SchoolMask`, `Name_Lang_enUS`)
VALUES
(800001, 0x10010, 1, 42, 1, 6, 59, 0, 1, 4, 4124, 1, 'DC Hotspot - XP Buff 100%');

-- =====================================================================
-- Step 3: Create Prestige Bonus Aura Spells
-- =====================================================================
-- Purpose: Stat bonus auras for prestige system
-- Aura Type: 137 (SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE - applies % to all stats AND displays in buff bar)
-- Effect: 6 (SPELL_EFFECT_APPLY_AURA)
-- EffectBasePoints_1: 0-9 (Maps to 1-10% bonus per prestige level)
-- EffectMechanic_1: MUST BE 0 (not used for this aura type)
-- ImplicitTargetA_1: 21 (TARGET_SELF for passive/permanent auras)
-- Attributes: 0x10 (treat as ability so aura displays and can be cancelled)
-- DurationIndex: 21 (permanent)
-- CRITICAL: Aura type 137 is VISIBLE and applies stat bonuses server-side
-- =====================================================================

INSERT INTO `spell_dbc` 
(`ID`, `Attributes`, `AttributesEx`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
 `Effect_1`, `EffectBasePoints_1`, `EffectMechanic_1`, `ImplicitTargetA_1`, `EffectAura_1`,
 `SchoolMask`, `Name_Lang_enUS`)
VALUES
-- Prestige Level 1: 1% All Stats
(800010, 0x10, 0x0, 1, 21, 1, 6, 0, 0, 21, 137, 1, 'DC Prestige 1 - Enhanced Stats'),
-- Prestige Level 2: 2% All Stats  
(800011, 0x10, 0x0, 1, 21, 1, 6, 1, 0, 21, 137, 1, 'DC Prestige 2 - Enhanced Stats'),
-- Prestige Level 3: 3% All Stats
(800012, 0x10, 0x0, 1, 21, 1, 6, 2, 0, 21, 137, 1, 'DC Prestige 3 - Enhanced Stats'),
-- Prestige Level 4: 4% All Stats
(800013, 0x10, 0x0, 1, 21, 1, 6, 3, 0, 21, 137, 1, 'DC Prestige 4 - Enhanced Stats'),
-- Prestige Level 5: 5% All Stats
(800014, 0x10, 0x0, 1, 21, 1, 6, 4, 0, 21, 137, 1, 'DC Prestige 5 - Enhanced Stats'),
-- Prestige Level 6: 6% All Stats
(800015, 0x10, 0x0, 1, 21, 1, 6, 5, 0, 21, 137, 1, 'DC Prestige 6 - Enhanced Stats'),
-- Prestige Level 7: 7% All Stats
(800016, 0x10, 0x0, 1, 21, 1, 6, 6, 0, 21, 137, 1, 'DC Prestige 7 - Enhanced Stats'),
-- Prestige Level 8: 8% All Stats
(800017, 0x10, 0x0, 1, 21, 1, 6, 7, 0, 21, 137, 1, 'DC Prestige 8 - Enhanced Stats'),
-- Prestige Level 9: 9% All Stats
(800018, 0x10, 0x0, 1, 21, 1, 6, 8, 0, 21, 137, 1, 'DC Prestige 9 - Enhanced Stats'),
-- Prestige Level 10: 10% All Stats
(800019, 0x10, 0x0, 1, 21, 1, 6, 9, 0, 21, 137, 1, 'DC Prestige 10 - Enhanced Stats');

-- =====================================================================
-- Step 4: Create Challenge Mode Aura Spells
-- =====================================================================
-- Spell IDs: 800020-800028 (Challenge Modes)
-- Purpose: Marker auras for challenge mode visual identification
-- Aura Type: 4 (SPELL_AURA_DUMMY - marker only, visual buff for players)
-- Effect: 6 (SPELL_EFFECT_APPLY_AURA)
-- These auras don't apply mechanical effects, they just display in buff bar
-- to show which challenge mode(s) the player has active
-- Attributes: 0x10 (treat as ability so the visible aura can be cancelled)
-- =====================================================================

INSERT INTO `spell_dbc` 
(`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
 `Effect_1`, `EffectBasePoints_1`, `EffectMechanic_1`, `ImplicitTargetA_1`, `EffectAura_1`,
 `SchoolMask`, `Name_Lang_enUS`)
VALUES
-- Hardcore Mode (800020)
(800020, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Hardcore Mode - One Death and You Die'),
-- Semi-Hardcore Mode (800021)  
(800021, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Semi-Hardcore - Multiple Lives Allowed'),
-- Self-Crafted Only Mode (800022)
(800022, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Self-Crafted - You Must Craft Your Own Gear'),
-- Item Quality Level Restriction (800023)
(800023, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Item Quality Restriction - Limited to Green or Better'),
-- Slow XP Gain (800024)
(800024, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Slow XP Mode - Reduced Experience Gain'),
-- Very Slow XP Gain (800025)
(800025, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Very Slow XP - Minimal Experience Gain'),
-- Quest XP Only (800026)
(800026, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Quest XP Only - No Mob Experience'),
-- Iron Man Mode (800027)
(800027, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Iron Man Mode - Hardcore + Self-Crafted + Item Restrictions'),
-- Challenge Combinations (800028)
(800028, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Challenge Mode Active - Multiple Challenges Enabled');

-- =====================================================================
-- Step 5: Create Alt XP Bonus Aura Spells
-- =====================================================================
-- Spell IDs: 800040-800044 (Alt XP Bonus - 5% to 25%)
-- Purpose: Visual auras showing XP bonus from having max-level alts
-- Aura Type: 4 (SPELL_AURA_DUMMY - marker only, visual buff for players)
-- Effect: 6 (SPELL_EFFECT_APPLY_AURA)
-- DurationIndex: 21 (permanent)
-- =====================================================================

INSERT INTO `spell_dbc` 
(`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
 `Effect_1`, `EffectBasePoints_1`, `EffectMechanic_1`, `ImplicitTargetA_1`, `EffectAura_1`,
 `SchoolMask`, `Name_Lang_enUS`)
VALUES
-- 5% Alt XP Bonus (1 max-level alt)
(800040, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Alt Bonus - 5% XP (1 Max-Level Alt)'),
-- 10% Alt XP Bonus (2 max-level alts)
(800041, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Alt Bonus - 10% XP (2 Max-Level Alts)'),
-- 15% Alt XP Bonus (3 max-level alts)
(800042, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Alt Bonus - 15% XP (3 Max-Level Alts)'),
-- 20% Alt XP Bonus (4 max-level alts)
(800043, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Alt Bonus - 20% XP (4 Max-Level Alts)'),
-- 25% Alt XP Bonus (5+ max-level alts)
(800044, 0x10, 1, 21, 1, 6, 0, 0, 21, 4, 1, 'DC Alt Bonus - 25% XP (5+ Max-Level Alts)');

-- =====================================================================
-- Integration Instructions
-- =====================================================================
-- 1. Run this SQL script on your world database
-- 2. Rebuild the DarkChaos server (./acore.sh compiler build)
-- 3. Restart the world server
-- 4. For Prestige: Re-login with a prestige character
--    - Buff should appear automatically in buff bar
-- 5. For Hotspot: Enter a hotspot zone while leveling
--    - Buff will apply automatically when you enter
-- 6. For Challenge Mode: Enable challenge mode on character
--    - Appropriate challenge mode buff(s) will display
-- 
-- Chat notifications will show:
-- - "Prestige buff aura applied! (Spell ID: 800010-800019)"
-- - "Hotspot XP buff applied!" (Spell ID: 800001)
-- - "Challenge Mode active - [Mode Name]" (Spell ID: 800020-800028)

-- =====================================================================
-- Spell Summary Table
-- =====================================================================
-- 
-- ID Range | Type          | Quantity | Purpose
-- ---------|---------------|----------|------------------------------------------
-- 800001   | Hotspot Buff  | 1        | XP bonus marker for hotspot zones
-- 800010   | Prestige 1    | 1        | +1% All Stats
-- 800011   | Prestige 2    | 1        | +2% All Stats
-- 800012   | Prestige 3    | 1        | +3% All Stats
-- 800013   | Prestige 4    | 1        | +4% All Stats
-- 800014   | Prestige 5    | 1        | +5% All Stats
-- 800015   | Prestige 6    | 1        | +6% All Stats
-- 800016   | Prestige 7    | 1        | +7% All Stats
-- 800017   | Prestige 8    | 1        | +8% All Stats
-- 800018   | Prestige 9    | 1        | +9% All Stats
-- 800019   | Prestige 10   | 1        | +10% All Stats
-- 800020   | Challenge     | 1        | Hardcore Mode marker
-- 800021   | Challenge     | 1        | Semi-Hardcore Mode marker
-- 800022   | Challenge     | 1        | Self-Crafted Mode marker
-- 800023   | Challenge     | 1        | Item Quality Restriction marker
-- 800024   | Challenge     | 1        | Slow XP Mode marker
-- 800025   | Challenge     | 1        | Very Slow XP Mode marker
-- 800026   | Challenge     | 1        | Quest XP Only Mode marker
-- 800027   | Challenge     | 1        | Iron Man Mode marker
-- 800028   | Challenge     | 1        | Multiple Challenge Modes marker
-- 
-- Total: 19 Custom Spells

-- =====================================================================
-- Column Reference (DarkChaos spell_dbc actual structure)
-- =====================================================================
-- ID: Spell ID (Primary Key) - NOT `Id`
-- Attributes: Spell attributes (0x100 = passive/permanent)
-- CastingTimeIndex: Casting time index (1 = instant)
-- DurationIndex: Duration type (0 = permanent)
-- RangeIndex: Spell range (1 = self/caster)
-- Effect_1: Effect type for slot 1 (6 = SPELL_EFFECT_APPLY_AURA) - WITH underscore
-- EffectBasePoints_1: Base points (varies by spell type) - WITH underscore
-- EffectMechanic_1: Effect mechanic (0 = none) - WITH underscore
-- ImplicitTargetA_1: Target type (1 = TARGET_UNIT_CASTER - self) - WITH underscore
-- EffectAura_1: Aura type (see below) - WITH underscore
-- SchoolMask: Magic school (1 = Physical)
-- Name_Lang_enUS: English spell name
--
-- Note: All effect columns use underscores (Effect_1, Effect_2, Effect_3, etc.)
-- NOT Effect1, Effect2, Effect3 as used in generic AzerothCore documentation!
--
-- =====================================================================
-- Aura Types Used in This File
-- =====================================================================
-- Aura Type 4: SPELL_AURA_DUMMY
--    Used for: Hotspot buff (800001), Challenge modes (800020-800028)
--    Purpose: Marker auras with no mechanical effect
--    These show in buff bar for player visibility/identification
--
-- Aura Type 137: SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE
--    Used for: Prestige bonuses (800010-800019)
--    Purpose: Apply percentage bonuses to ALL stats
--    This is critical - must match C++ code in dc_prestige_spells.cpp
--    Hooks registered for aura type 137 only!
--
-- =====================================================================
-- Prestige Spell Details
-- =====================================================================
-- EffectBasePoints_1 Mapping:
--   0 = +1% stats (prestige level 1)
--   1 = +2% stats (prestige level 2)
--   2 = +3% stats (prestige level 3)
--   ... continues to ...
--   9 = +10% stats (prestige level 10)
--
-- CRITICAL: Aura type 137 matches the C++ code in dc_prestige_spells.cpp
-- which expects SPELL_AURA_MOD_TOTAL_STAT_PERCENTAGE (enum value 137)
-- If this doesn't match, C++ hooks won't fire and stats won't apply!
--
-- =====================================================================
-- Hotspot Spell Details
-- =====================================================================
-- Spell 800001 (DC Hotspot - XP Buff 100%)
-- Purpose: Marker aura showing XP bonus is active
-- Applied when: Player enters a hotspot zone
-- Effect: Dummy aura (no mechanical effect, purely visual)
-- The actual XP calculation happens in C++ (Player::GainXP)
-- This aura just shows players they're in a bonus zone
--
-- =====================================================================
-- Challenge Mode Spell Details
-- =====================================================================
-- Spells 800020-800028 represent each challenge mode
-- Each can be active independently or in combination
-- Purpose: Visual identification in buff bar
-- Effect: Dummy auras (no mechanical effect on stats/XP)
-- Actual challenge mode effects applied in C++ (dc_challenge_modes.cpp)
-- These spells just display which modes are active
--
-- Applied by: dc_challenge_modes system when player enables that mode
-- Removed by: dc_challenge_modes system when player disables that mode
-- Multiple can stack: If player has Hardcore + Self-Crafted, both display

-- =====================================================================
-- Verification Queries
-- =====================================================================

UPDATE `spell_dbc`
SET EquippedItemClass = -1,
    EquippedItemSubclass = 0,
    EquippedItemInvTypes = 0
WHERE ID >= 800000 AND ID < 900000;

-- Also clear for Sayge's buff (hotspot detection spell)
UPDATE `spell_dbc`
SET EquippedItemClass = -1,
    EquippedItemSubclass = 0,
    EquippedItemInvTypes = 0
WHERE ID = 23768;

-- Verify all spells were created:
SELECT COUNT(*) as total_spells FROM `spell_dbc` WHERE `ID` BETWEEN 800001 AND 800028;

-- List all created spells:
SELECT `ID`, `Name_Lang_enUS`, `EffectAura_1` FROM `spell_dbc` WHERE `ID` BETWEEN 800001 AND 800028 ORDER BY `ID`;

-- Verify prestige spells have correct aura type (should all be 137):
SELECT `ID`, `Name_Lang_enUS`, `EffectAura_1` FROM `spell_dbc` WHERE `ID` BETWEEN 800010 AND 800019;

-- Verify hotspot spell exists (should have aura type 4):
SELECT `ID`, `Name_Lang_enUS`, `EffectAura_1` FROM `spell_dbc` WHERE `ID` = 800001;

-- Verify challenge mode spells (should all have aura type 4):
SELECT `ID`, `Name_Lang_enUS`, `EffectAura_1` FROM `spell_dbc` WHERE `ID` BETWEEN 800020 AND 800028;

-- =====================================================================
-- Step 5: Register Spell Script Names
-- =====================================================================
-- CRITICAL: Without these entries, the C++ scripts will NOT be called!
-- The spell_script_names table links spell IDs to their C++ script handlers.
-- =====================================================================

-- Clear existing entries
DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN 800001 AND 800044;

-- Hotspot XP Buff Script
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800001, 'spell_hotspot_buff_800001_aura');

-- Prestige Bonus Scripts (800010-800019)
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800010, 'spell_prestige_bonus_1'),
(800011, 'spell_prestige_bonus_2'),
(800012, 'spell_prestige_bonus_3'),
(800013, 'spell_prestige_bonus_4'),
(800014, 'spell_prestige_bonus_5'),
(800015, 'spell_prestige_bonus_6'),
(800016, 'spell_prestige_bonus_7'),
(800017, 'spell_prestige_bonus_8'),
(800018, 'spell_prestige_bonus_9'),
(800019, 'spell_prestige_bonus_10');

-- Challenge Mode Scripts (800020-800028)
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800020, 'spell_challenge_hardcore_800020'),
(800021, 'spell_challenge_semi_hardcore_800021'),
(800022, 'spell_challenge_self_crafted_800022'),
(800023, 'spell_challenge_item_quality_800023'),
(800024, 'spell_challenge_slow_xp_800024'),
(800025, 'spell_challenge_very_slow_xp_800025'),
(800026, 'spell_challenge_quest_xp_only_800026'),
(800027, 'spell_challenge_iron_man_800027'),
(800028, 'spell_challenge_combination_800028');

-- Alt Bonus Scripts (using 800040-800044 for 5%, 10%, 15%, 20%, 25%)
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800040, 'spell_alt_bonus_5'),
(800041, 'spell_alt_bonus_10'),
(800042, 'spell_alt_bonus_15'),
(800043, 'spell_alt_bonus_20'),
(800044, 'spell_alt_bonus_25');

-- Verify spell_script_names registration:
SELECT spell_id, ScriptName FROM `spell_script_names` WHERE spell_id BETWEEN 800001 AND 800050 ORDER BY spell_id;
