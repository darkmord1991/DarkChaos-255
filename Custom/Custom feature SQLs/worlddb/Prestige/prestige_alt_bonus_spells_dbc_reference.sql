-- =====================================================================
-- DarkChaos-255 Alt Bonus Visual Buff Spells
-- =====================================================================
-- These spell IDs need to be added to Spell.dbc client-side
-- Reference for creating the visual buffs that show players their XP bonus
-- =====================================================================

-- Spell IDs Required in Spell.dbc:
-- 800020 - Alt Bonus 5% (1 max-level character)
-- 800021 - Alt Bonus 10% (2 max-level characters)
-- 800022 - Alt Bonus 15% (3 max-level characters)
-- 800023 - Alt Bonus 20% (4 max-level characters)
-- 800024 - Alt Bonus 25% (5+ max-level characters)

-- =====================================================================
-- DBC Entry Template (Add these to Spell.dbc using a DBC editor)
-- =====================================================================

/*
Spell Entry Template for 800020-800024:

Field: ID
Value: 800020 (increment for each tier)

Field: Name
Value: "Alt Bonus 5%" (increment percentage)

Field: Description
Value: "Grants 5% bonus experience from having 1 max-level character on your account."

Field: Aura
Value: SPELL_AURA_DUMMY (4)

Field: Duration
Value: -1 (permanent until removed)

Field: Effect[0]
Value: SPELL_EFFECT_APPLY_AURA (6)

Field: EffectBasePoints[0]
Value: 5 (the percentage - increment for each tier)

Field: EffectAura[0]
Value: SPELL_AURA_DUMMY (4)

Field: Icon
Value: Use a suitable icon (e.g., spell_holy_blessedrecovery or achievement_level_10)

Field: Attributes
Value: SPELL_ATTR0_PASSIVE | SPELL_ATTR0_HIDDEN_CLIENTSIDE (if you want it hidden)

Field: Schools
Value: SPELL_SCHOOL_MASK_NORMAL (1)

*/

-- =====================================================================
-- Alternative: Use SpellCustomAttributes (Server-side only visual)
-- =====================================================================
-- If you don't want to modify client DBCs, you can use existing spells
-- and just change the icons/names server-side (but players won't see
-- custom names without client modifications)

-- World database entries for spell visual customization
-- (These are optional and only affect tooltip text if supported)

DELETE FROM `spell_script_names` WHERE `spell_id` BETWEEN 800020 AND 800024;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800020, 'spell_alt_bonus_5'),
(800021, 'spell_alt_bonus_10'),
(800022, 'spell_alt_bonus_15'),
(800023, 'spell_alt_bonus_20'),
(800024, 'spell_alt_bonus_25');

-- =====================================================================
-- Usage Notes:
-- =====================================================================
-- 1. These spells are purely visual - they don't grant actual XP bonus
-- 2. The actual XP calculation is done in dc_prestige_alt_bonus.cpp
-- 3. System automatically applies/removes appropriate buff on login
-- 4. Buff updates when player reaches max level (removes buff)
-- 5. New alts on same account automatically get appropriate buff
--
-- Visual Buff Benefits:
-- - Players can easily see their current bonus at a glance
-- - Buff icon visible in buff bar
-- - Tooltip shows percentage and source
-- - Increases awareness of alt-friendly system
-- =====================================================================

-- =====================================================================
-- Quick Client DBC Guide:
-- =====================================================================
-- Tools Needed:
-- - WDBX Editor (https://github.com/WowDevTools/WDBXEditor)
-- - Spell.dbc from client Data/DBFilesClient/
--
-- Steps:
-- 1. Open Spell.dbc in WDBX Editor
-- 2. Find an existing passive buff spell as template (e.g., 48074)
-- 3. Copy the template row 5 times
-- 4. Modify ID to 800020-800024
-- 5. Change Name/Description for each tier
-- 6. Change EffectBasePoints[0] to 5, 10, 15, 20, 25
-- 7. Save Spell.dbc
-- 8. Rebuild client patch MPQ
-- 9. Distribute to players
--
-- Alternative (No Client Edit):
-- - Use existing spell IDs (e.g., 15007, 15008 from Resurrection Sickness)
-- - Players will see wrong names but buffs still work
-- =====================================================================
