-- Extract all companion teaching items from item_template
-- This will give us the REAL item IDs from your database

SELECT 
    entry AS item_id,
    name AS item_name,
    Quality AS rarity,
    spellid_1,
    spellid_2,
    spellid_3,
    spellid_4,
    spellid_5,
    description,
    -- Try to determine source from various flags
    CASE 
        WHEN BuyPrice > 0 AND SellPrice > 0 THEN 'Vendor'
        WHEN Flags & 0x00000010 THEN 'Quest Reward'
        WHEN Flags & 0x00000800 THEN 'Profession'
        ELSE 'Drop/Other'
    END AS likely_source
FROM item_template
WHERE class = 15 AND subclass = 2  -- Companion pets
ORDER BY entry ASC;

-- Also get counts
SELECT COUNT(*) AS total_companion_items
FROM item_template
WHERE class = 15 AND subclass = 2;

-- Check if we have spell data for these companions
SELECT 
    it.entry AS item_id,
    it.name AS item_name,
    it.spellid_1,
    it.spellid_2,
    it.spellid_3,
    it.spellid_4,
    it.spellid_5,
    -- Note: spell_dbc join here is illustrative; items may use spellid_2+.
    s.EffectMiscValue_1 AS summoned_creature_id_from_spellid_1
FROM item_template it
LEFT JOIN spell_dbc s ON s.Id = it.spellid_1
WHERE it.class = 15 AND it.subclass = 2
AND it.spellid_1 > 0
ORDER BY it.entry ASC
LIMIT 20;  -- Just show first 20 to verify structure
