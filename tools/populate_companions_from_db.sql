-- Quick validation: Check what companion items actually exist in your database
-- Run this to see the REAL item IDs your server has:

SELECT entry, name, Quality, spellid_1, spellid_2, spellid_3, spellid_4, spellid_5 
FROM item_template 
WHERE class = 15 AND subclass = 2 
ORDER BY entry;

-- If you want to use this data to populate dc_pet_definitions:
-- 1. Export the results to CSV
-- 2. Match against wowhead names to get icon/source data
-- 3. Import into dc_pet_definitions

-- Alternative: Populate with basic data from item_template
-- DO NOT rely on spellid_1 specifically; companion items may use spellid_2+.
-- Also in your DB many items have spellid_1 = 55884, so treating spellid_1 as "the companion spell" is incorrect.
-- Let the server auto-resolve the correct spell ID using FindCompanionSpellIdForItem()
INSERT INTO dc_pet_definitions (pet_entry, name, icon, rarity, source, pet_spell_id)
SELECT 
    entry,
    name,
    'INV_Misc_QuestionMark',  -- Placeholder icon, will be resolved by server
    Quality,
    '{"type":"unknown"}',  -- Basic source placeholder
    0  -- Set to 0 - server will auto-resolve the CORRECT spell ID
FROM item_template
WHERE class = 15 AND subclass = 2
AND entry NOT IN (SELECT pet_entry FROM dc_pet_definitions);  -- Don't duplicate existing entries
