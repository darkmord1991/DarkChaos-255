-- ---------------------------------------------------------------------------
-- 145  Hyjal round-21 -- one more spellclick row
-- ---------------------------------------------------------------------------
--     npc_spellclick_spells: Creature template 3653107 has
--     UNIT_NPC_FLAG_SPELLCLICK but no data in spellclick table! Removing flag
--
-- "Smothervine" came in with the clone block's latest growth, carrying the
-- spellclick npcflag but not its row -- same shape as 127_/139_ before it.
-- nelt_world has the row; import it rather than let the core strip the flag
-- (which would break the interaction the quest needs).
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO acore_world.npc_spellclick_spells (`npc_entry`,`spell_id`,`cast_flags`,`user_type`)
SELECT npc_entry + 3600000, spell_id, cast_flags, user_type
FROM nelt_world.npc_spellclick_spells WHERE npc_entry = 53107;

-- ---------------------------------------------------------------------------
-- The rest of this round's log is handled by files that are already
-- SELF-DERIVING over the whole 3,600,000 block, so simply re-running
-- apply_all.sql picks up the newly imported entries with no new SQL:
--
--   136_  creature_equip_template -- 135 spawns are back on equipment_id = -1
--         with no equip rows (the block grew from 1,059 to 1,100 templates).
--         136_ imports what cata_world/nelt_world have and zeroes the rest.
--   133_  the offset sweeps -- picks up the two new un-offset references
--         (3653112 action 33 -> 53112, 3675180 action 12 -> 53107; both clones
--         already exist).
--   128_  creature_model_info -- covers any display the new templates brought.
--
-- That is the point of writing them self-derivingly: content growth does not
-- need new files, only a re-run.
-- ---------------------------------------------------------------------------
