-- =====================================================================
-- Blackwing Descent Downport  --  23  npc_spellclick_spells (Magmaw shields)
-- ---------------------------------------------------------------------
-- 8 "Ancient Dwarven Shield" entries (41445 + 42947/42949/42951/42954/
-- 42956/42958/42960, map 669) kept UNIT_NPC_FLAG_SPELLCLICK from the
-- cata_world creature_template copy but never got their npc_spellclick_spells
-- row, so ObjectMgr strips the flag at boot:
--   npc_spellclick_spells: Creature template N has UNIT_NPC_FLAG_SPELLCLICK
--   but no data in spellclick table! Removing flag
-- i.e. the Magmaw shield-tanking mechanic (players click a shield to pick
-- it up) has no click-to-cast wired up on any of these props.
-- Same cross-schema copy pattern as the rest of the BWD roster.
--
-- NOT included: 41620/41789 ("Magmaw's Pincer") and 45004/45024 ("Wyvern"),
-- which also lost their spellclick data -- neither has any spawn on any of
-- the 5 custom maps found via `creature`, creature_summon_groups, or
-- smart_scripts SUMMON_CREATURE in this pass, so map 669 couldn't be
-- confirmed. Likely either orphaned cata_world copy residue or summoned by
-- a mechanism this pass didn't check; left alone pending confirmation.
-- =====================================================================

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (41445,42947,42949,42951,42954,42956,42958,42960);

INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`)
SELECT scs.`npc_entry`, scs.`spell_id`, scs.`cast_flags`, scs.`user_type`
FROM `cata_world`.`npc_spellclick_spells` scs
WHERE scs.`npc_entry` IN (41445,42947,42949,42951,42954,42956,42958,42960);
