-- ============================================================================
-- DC-Collection: pet preview display-id corrections
-- ============================================================================
-- Fixes the only pet definitions that resolve NO creature model through the
-- normal chain (teaching item -> companion summon spell -> SPELL_EFFECT_SUMMON
-- creature -> creature_template_model.CreatureDisplayID), so their 3D preview
-- renders for not-yet-collected pets instead of falling back to the player
-- model.
--
-- These display ids are STOCK CreatureDisplayInfo ids already present in the
-- client DBC -- NO custom DBC / client patch is required. Only the server-side
-- dc_pet_definitions.display_id (the fallback the addon previews when live
-- spell resolution yields nothing) needs to be set.
--
-- Scope: the remaining visible+broken pets identified by replaying the resolve
-- chain against Custom/CSV DBC/Spell.csv. All other unresolved definitions are
-- either already hidden by the client SUPPRESSED_PET_ENTRY_IDS list (dummies /
-- "NPC Equip" / Pet Fish / Pet Stone / Silver Shafted Arrow ...) or summon a
-- creature that already has a valid display id (handled by the runtime backfill
-- DCCollection.Pets.BackfillDisplayIdsOnStartup).
-- ============================================================================

-- Sea Turtle egg colour variants. The companion item slots carry no summon
-- spell (only the sibling "Turtle Egg (Loggerhead)" 18964 is wired -> creature
-- 14629 "Loggerhead Snapjaw" -> display 14657). They are the same turtle, so
-- preview them with the same model. NOTE: these items have no summon spell, so
-- they are not actually summonable even when owned -- this fixes the preview
-- only. To make them functional pets, wire spell 23429 into item_template.
UPDATE `dc_pet_definitions` SET `display_id` = 14657
    WHERE `pet_entry` IN (18963, 18965, 18966, 18967);

-- Unhatched Jubling Egg (19462). Its item spell 23851 is SPELL_EFFECT_CREATE_ITEM
-- (the egg hatches into a separate item over time), not a companion summon, so
-- the chain resolves nothing. The actual Jubling companion is creature 14878
-- (display 14938) -- already collected via "A Jubling's Tiny Home" (19450). This
-- previews the egg as the Jubling it becomes. If 19462 should not be a separate
-- collectible from 19450, delete the row instead of setting a display id.
UPDATE `dc_pet_definitions` SET `display_id` = 14938
    WHERE `pet_entry` = 19462;

-- Baby Coralshell Turtle (39148). The companion item carries no summon spell, so
-- the chain resolves nothing. The matching creature is 24594 "Coral Shell Turtle"
-- -> display 7046. This is the same value the client previously hardcoded in
-- PET_PREVIEW_VISUAL_FALLBACKS[39148]; promoting it to authoritative server data
-- means that client-side fallback can be removed.
UPDATE `dc_pet_definitions` SET `display_id` = 7046
    WHERE `pet_entry` = 39148;
