-- ============================================================================
-- DC-Collection: remove non-pet rows from dc_pet_definitions
-- ============================================================================
-- These 28 rows are class 15 / subclass 2 (the companion subclass) but are NOT
-- collectible companions: they carry no summon spell, so they can never resolve
-- a creature model. The runtime backfill logs them as "unresolved" on every
-- startup and they inflate the pet denominator. The client already hides them
-- (explicit SUPPRESSED_PET_ENTRY_IDS + the "^NPC Equip " name filter in
-- PetModule.lua), so removing the definitions only tidies the table, silences
-- the startup WARN, and makes the collected/total count accurate. None are
-- summonable, so no player can own one, and nothing references them outside
-- dc_pet_definitions.
--
-- Run AFTER the resolvable pets are populated (the IsCompanionSpell gate fix in
-- dc_addon_collection.cpp + the 2026_06_18_03 full-display-backfill migration).
-- DELETEs only (idempotent); safe to re-run.
-- ============================================================================

-- Group A: definitively not pets -- 22 NPC display-equipment items (auto-named
-- "NPC Equip <id>", Quality 0), plus the Pet Fish / Pet Stone novelty dummies
-- and Silver Shafted Arrow (a SPELL_EFFECT_DUMMY, not a summon). 25 rows.
DELETE FROM `dc_pet_definitions` WHERE `pet_entry` IN (
    13342, 13343, 22200,
    28326, 33817, 34495, 38234, 38299, 38612, 40355,
    44823, 44824, 44825, 44826, 44827, 44828, 44829,
    46890, 46891, 46894, 49659, 49660, 49664, 49911, 50151);

-- Group B: pet-adjacent TOYS that summon nothing in the spell DBC -- the Goblin
-- Weather Machine (SCRIPT_EFFECT) and two pet leashes (APPLY_AURA pet toys).
-- Not companions either. If you intend to wire any of these up as a real pet
-- later (item summon spell -> creature -> display), comment this statement out
-- and add the spell + a display_id instead. 3 rows.
DELETE FROM `dc_pet_definitions` WHERE `pet_entry` IN (35227, 37460, 44820);
