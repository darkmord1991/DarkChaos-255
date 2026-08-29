-- ---------------------------------------------------------------------------
-- 219  Clear the pre-existing Errors.log backlog
-- ---------------------------------------------------------------------------
-- None of this was caused by the map-750 work; it is the long-standing noise
-- that has been sitting under it. Each item was checked for provenance before
-- being touched, because "pre-existing" is easy to assert and easy to get wrong.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) 130 orphaned pool_gameobject rows
-- ---------------------------------------------------------------------------
-- `pool_gameobject has a non existing gameobject spawn (GUID: N)`. Their guids
-- run 12,611,114-15,051,057, i.e. the nelt_world and PoolFix import bands.
--
-- VERIFIED NOT MINE before deleting, since 206_ removed 452 gameobjects and
-- this is exactly what that would look like if it had gone wrong: joining the
-- full dc_map750_dupe_backup_go against pool_gameobject returns 0 rows. 206_
-- also preferred a pooled member as the survivor precisely so this could not
-- happen.
--
-- SAFE TO DELETE: 99 of the affected pools still contain live spawns, and
-- removing every orphan leaves ZERO pools empty -- checked. An empty pool would
-- mean a spawn point that never populates, which is why that was worth testing
-- rather than assuming.
-- ---------------------------------------------------------------------------
DELETE p FROM `pool_gameobject` p
WHERE NOT EXISTS (SELECT 1 FROM `gameobject` g WHERE g.`guid` = p.`guid`);

-- ---------------------------------------------------------------------------
-- B) 20 orphaned creature_loot_template entries
-- ---------------------------------------------------------------------------
-- `Entry N isn't creature entry and not referenced from loot, and thus useless.`
-- No creature_template.lootid points at them and no reference_loot_template
-- pulls them in, so nothing can ever roll them.
-- ---------------------------------------------------------------------------
DELETE l FROM `creature_loot_template` l
WHERE NOT EXISTS (SELECT 1 FROM `creature_template` t WHERE t.`lootid` = l.`Entry`)
  AND NOT EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Reference` = l.`Entry`);

-- ---------------------------------------------------------------------------
-- C) 14 gameobject loot templates that were referenced but never imported
-- ---------------------------------------------------------------------------
-- `gameobject_loot_template Entry N does not exist but it is used by Gameobject M`
-- for 16 chests across the 3.7M/3.8M/3.9M bands. All 14 distinct loot ids exist
-- in cata_world, so these are importable rather than deletable -- the chests
-- currently open empty.
--
-- cata's gameobject_loot_template carries an extra `IsCurrency` column that we
-- do not have, hence the explicit list. Rows are filtered to items/references
-- that actually resolve here.
-- ---------------------------------------------------------------------------
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (
  26865, 27222, 27638, 27645, 27715, 27729, 36096,
  36131, 36132, 36133, 36134, 36135, 39336, 39381);

INSERT INTO `gameobject_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT l.`Entry`, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`gameobject_loot_template` l
WHERE l.`Entry` IN (26865, 27222, 27638, 27645, 27715, 27729, 36096,
                    36131, 36132, 36133, 36134, 36135, 39336, 39381)
  AND (   (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`))
       OR (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`)));

-- ---------------------------------------------------------------------------
-- D) 7 areatrigger rows pointing at ids that are not in AreaTrigger.dbc
-- ---------------------------------------------------------------------------
-- `Area trigger (ID:6194) does not exist in AreaTrigger.dbc`. Six are teleport
-- definitions and one is a script binding. A trigger the client never fires can
-- never run, so these rows are unreachable regardless.
--
-- Deleting rather than adding DBC rows on purpose: 607000/607001 are custom ids
-- in a range nothing else uses, and the other five are stock ids absent from a
-- 3.3.5 AreaTrigger.dbc. Inventing DBC entries to satisfy them would put live
-- teleports in the world with no idea where they were meant to lead.
--
-- Checked first: areatrigger_involvedrelation has no rows for any of the seven,
-- so no quest depends on them.
--
-- SUPERSEDED IN PART, 2026-08-29. The premise above -- "607000/607001 are not in
-- AreaTrigger.dbc" -- was true of those IDS but not of the triggers. The whole
-- custom band had been renumbered by `_shared/renumber_areatrigger_ids.sql`
-- (607000/607001 -> 6921/6922, 9861/9862 -> 6807/6808) because the 3.3.5 client
-- keeps trigger ids in a 16-bit table and anything over 65535 crashes it with
-- ERROR #132. Read back 2026-08-29: 6807/6808 and 6921/6922 ARE present in the
-- live server AreaTrigger.dbc and in the client's patch-4, so those four were
-- never really orphans -- only their retired ids were. Karazhan Crypts' rows have
-- been restored at 6921/6922 by KarazhanCrypts/03_areatrigger_teleport.sql, which
-- also adds the `areatrigger` definition rows this file's D) section never had.
-- The DELETEs below are now no-ops for the renumbered ids; do NOT extend them to
-- 6807/6808/6921/6922. 6194/6581/5876 remain genuinely absent from the DBC.
-- ---------------------------------------------------------------------------
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (6194, 6581, 9861, 9862, 607000, 607001, 5876);
DELETE FROM `areatrigger_scripts` WHERE `entry` IN (6194, 6581, 9861, 9862, 607000, 607001, 5876);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart (all expect 0):
--   SELECT COUNT(*) FROM pool_gameobject p
--    WHERE NOT EXISTS (SELECT 1 FROM gameobject g WHERE g.guid = p.guid);
--
--   SELECT COUNT(*) FROM (SELECT pool_entry FROM pool_gameobject GROUP BY pool_entry
--     HAVING SUM(EXISTS(SELECT 1 FROM gameobject g WHERE g.guid = pool_gameobject.guid)) = 0) z;
--
--   SELECT COUNT(DISTINCT gt.entry) FROM gameobject g
--     JOIN gameobject_template gt ON gt.entry = g.id
--    WHERE gt.type = 3 AND gt.Data1 > 0
--      AND NOT EXISTS (SELECT 1 FROM gameobject_loot_template l WHERE l.Entry = gt.Data1);
--
-- STILL OPEN, and deliberately not touched here:
--   * 5 unassigned ScriptNames (npc_group_finder, go_ancient_primal_altar,
--     spell_chimaeron_massacre, GOMove_spell_place,
--     spell_q13413_wyrmrest_skytalon_ride_periodic). These are compiled C++
--     scripts with no DB row pointing at them. Assigning one means deciding
--     WHICH creature or gameobject it belongs to, which is a content decision,
--     not cleanup -- and a wrong guess silently attaches behaviour to the wrong
--     NPC.
--   * 3636868 / 3637002 "has SmartAI enabled but no SmartAI entries". Checked:
--     both DO have smart_scripts rows, so clearing AIName would be the wrong
--     fix. The rows are being REJECTED at load for missing spells (74613,
--     81026, 80835) and a bad min/max on 3607885. Those spells need downporting
--     the way 216_ did, which is a job of its own.
--   * 4 Spell/script effect-mismatch warnings (326824, 329181, 329725, 343995)
--     -- C++ hooks bound to spell effects that differ here. Needs a code change.
--   * reference_loot_template 24161 group 1 at 110%, and skinning 7448 / 10807
--     at 138% / 134% -- pre-existing stock loot balance, see 215_.
-- ---------------------------------------------------------------------------
