-- DC-Collection: remove 3 phantom mount definitions that can never render a preview
-- (reported by the addon Mount Preview diagnostic: "3/1490 mount definitions have
--  no model data. Example spell IDs: 483, 60975, 60969").
--
-- Why these rows are wrong (all three are bad retail-import artifacts from
-- collectionextracts/extracts.sql, which has been fixed in the same commit):
--
--  * 483  "Black Qiraji Resonating Crystal": spell 483 is the generic "Learning"
--         spell, not a mount. The real WotLK Black Qiraji mount is already in the
--         table as spell 26656 (AQ battle tank), so this row is a broken duplicate.
--  * 60969 "Swift Flying Carpet" and 60975 "Swift Ebonweave Carpet": these are the
--         TAILORING CRAFT spells (Effect1 = 24 CREATE_ITEM) that create items
--         39303/44557, not mount spells. Neither spell chain contains a
--         SPELL_AURA_MOUNTED effect, so no display can ever be resolved; the
--         mounts themselves were never shipped on 3.3.5 (the items' use-spell
--         points back at the craft spell).
--
-- Their stored display_ids (33967 / 51685 / 42161) exist in NO CreatureDisplayInfo
-- (neither server dbc nor client patch set) and were already being dropped by the
-- orphan-display guard in dc_addon_collection.cpp.
--
-- No character-side cleanup needed: acore_characters.dc_mount_collection and
-- dc_collection_items contain zero rows for these ids (verified 2026-07-29).

DELETE FROM `dc_mount_definitions` WHERE `spell_id` IN (483, 60969, 60975);

DELETE FROM `dc_collection_definitions` WHERE `collection_type` = 1 AND `entry_id` IN (483, 60969, 60975);
