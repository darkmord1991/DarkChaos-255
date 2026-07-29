-- ---------------------------------------------------------------------------
-- 162  Hyjal round-28 -- first pass against the LIVE error log
-- ---------------------------------------------------------------------------
-- Every earlier round in this series was triaged against
-- K:\Dark-Chaos\Server\logs\Errors.log, which turns out to be a stale Feb-19
-- copy: the running worldserver logs to /home/wowcore/azeroth-server/logs on
-- the Linux host.  Reading the real file changes what is actually broken, and
-- several items below are regressions from THIS series of fixes.
--
-- ---------------------------------------------------------------------------
-- (1) MY OWN REGRESSION from 155_ -- idle movers with a wander distance
-- ---------------------------------------------------------------------------
--     Table `creature` have creature (SpawnId: 15501215 Entry: 3650057) with
--     `MovementType`=0 (idle) have `wander_distance`<>0, set to 0.
--     ... same for SpawnId 15501256 (Entry 3654320)
--
-- 155_ copies `wander_distance` from cata_world, and 159_ then forces
-- MovementType to 0 for waypoint movers that have no path.  Neither clears the
-- wander distance, so the pair ends up contradictory.  Blazewing and Ban'thalos
-- (both rare spawns) are the two that landed this way.
--
-- Fixed at the source too: 155_ and 161_ now zero wander_distance whenever they
-- force MovementType to 0, so a re-run cannot recreate this.
UPDATE `creature` SET `wander_distance` = 0
WHERE `guid` BETWEEN 15500000 AND 15799999
  AND `MovementType` = 0 AND `wander_distance` <> 0;

-- ---------------------------------------------------------------------------
-- (2) CLIENT-CRASH RISK -- two creatures with a display id that does not exist
-- ---------------------------------------------------------------------------
--     Creature (Entry: 3653107) lists non-existing CreatureDisplayID id
--     (30512), this can crash the client.
--     Creature (Entry: 3653112) lists non-existing CreatureDisplayID id (38152)
--
-- Both arrived with round 21's clone-block growth and neither display was ever
-- downported.  The models themselves ARE present, so the fix is two
-- CreatureDisplayInfo rows rather than an art job:
--     30512  Smothervine              -> model 3080   (stock WotLK
--                                        Creature\YoggSaron\YoggSaronTentacleThin)
--     38152  Subterranean Magma Worm  -> model 502776 (the DC-baked
--                                        Creature\LavaWorm\LavaWorm_03, the same
--                                        model display 38002 already uses)
-- Added to Custom/CSV DBC/CreatureDisplayInfo.csv (28,031 -> 28,033),
-- recompiled, copied to Server/data/dbc and packed into both client archives.
-- NO SQL is needed for these two -- noted here so the round is self-describing.

-- ---------------------------------------------------------------------------
-- (3) Seething Pyrelord's kill credit points at a clone that was never made
-- ---------------------------------------------------------------------------
--     Creature (Entry: 3652300) lists non-existing creature entry 3652816 in
--     `KillCredit1`.
--
-- Cata's 52300 credits 52816 "Charred Invader".  This DB has the RAW 52816 but
-- no 3652816 clone, so the +3,600,000 offset was applied to a reference whose
-- target was never cloned.  That is exactly the case 133_'s rule exists for --
-- rewrite only when the raw id resolves to nothing -- so the correct value is
-- the raw one.
-- Written as a JOIN, not EXISTS: MySQL rejects reading the UPDATE target inside
-- a subquery with "You can't specify target table 'creature_template' for update
-- in FROM clause" (error 1093).  The JOIN expresses the same guard -- it matches
-- nothing, and so updates nothing, unless entry 52816 exists.  Same mistake and
-- same fix as 127_.
UPDATE `creature_template` ct
JOIN `creature_template` credit ON credit.`entry` = 52816
SET ct.`KillCredit1` = 52816
WHERE ct.`entry` = 3652300 AND ct.`KillCredit1` = 3652816;

-- ---------------------------------------------------------------------------
-- (4) A spawn whose creature does not exist, and 8 orphaned addons
-- ---------------------------------------------------------------------------
--     Table `creature` has creature (SpawnId: 9010386) with non existing
--     creature entry 3461257 in `id` field, skipped.
--     Creature (GUID: 9010250/58/65/71/75/97/9010300/03) does not exist but has
--     a record in `creature_addon`
--
-- 9010386 sits on map 745 (not Hyjal) with entry 3461257, which exists nowhere
-- -- a mis-keyed row from an early import.  The core skips it, so deleting is
-- purely cleanup.  The 8 addon rows are the tail of an older spawn deletion in
-- the 9,010,xxx Hyjal block; their creatures are long gone and the paths they
-- carry (53004968-53004976) are unreachable.
DELETE FROM `creature` WHERE `guid` = 9010386 AND `id` = 3461257;

DELETE FROM `creature_addon`
WHERE `guid` IN (9010250,9010258,9010265,9010271,9010275,9010297,9010300,9010303)
  AND NOT EXISTS (SELECT 1 FROM `creature` c WHERE c.`guid` = `creature_addon`.`guid`);

-- ---------------------------------------------------------------------------
-- (5) equipment_id = -1 on eight templates (~150 log lines)
-- ---------------------------------------------------------------------------
--     Table `creature` have creature (Entry: 3652500/03/04/3652633/3652822/
--     3652834/3653327/3675180) with equipment_id -1 not found in table
--     `creature_equip_template`, set to no equipment.
--
-- 136_ backfills equipment self-derivingly and zeroes whatever it cannot
-- resolve, but these entries joined the clone block afterwards.  -1 means
-- "look me up", 0 means "no equipment"; since none of them has a
-- creature_equip_template row in cata_world or nelt_world either, 0 is the
-- honest value and silences the loudest single block in the log.
UPDATE `creature` c
JOIN `creature_template` ct ON ct.`entry` = c.`id`
SET c.`equipment_id` = 0
WHERE c.`equipment_id` = -1
  AND c.`map` IN (750, 861)
  AND NOT EXISTS (SELECT 1 FROM `creature_equip_template` e WHERE e.`CreatureID` = c.`id`);

-- ---------------------------------------------------------------------------
-- (6) spell_inferno_tick is compiled but never bound
-- ---------------------------------------------------------------------------
--     Script named 'spell_inferno_tick' is not assigned in the database.
--
-- The script was restored in zone_mount_hyjal.cpp during round 14 but its
-- `spell_script_names` row was never added, so it has been dead ever since.
--
-- The spell is **74813 "Inferno"**, read from the script itself
-- (SPELL_INFERNO_TICK_AURA); it is the aura the AuraScript hooks, and it casts
-- SPELL_INFERNO_AOE 74817 per tick.  An earlier draft of this file guessed
-- 100289, which does not exist in Spell.dbc at all -- binding it would have
-- added a second dead row rather than fixing anything.
--
-- Verified against the built Custom/DBCs/Spell.dbc: 74813 is effects [0, 6, 6]
-- with auras [0, 23, 26], so SPELL_AURA_PERIODIC_TRIGGER_SPELL (23) is on
-- EFFECT_1.  The script was registering the handler on EFFECT_0, which the core
-- silently drops as "did not match dbc effect data" -- fixed in
-- zone_mount_hyjal.cpp alongside this row, so BOTH are needed and the C++ change
-- requires a worldserver rebuild.
--
-- No self-referencing subquery here either: an INSERT ... SELECT that reads its
-- own target table trips the same 1093 as (3) above.  The DELETE already makes
-- the INSERT idempotent.
DELETE FROM `spell_script_names` WHERE `ScriptName` = 'spell_inferno_tick';
INSERT INTO `spell_script_names` (`spell_id`,`ScriptName`) VALUES (74813, 'spell_inferno_tick');

-- ---------------------------------------------------------------------------
-- (7) 54343's loot references an item that exists nowhere
-- ---------------------------------------------------------------------------
--     Table 'creature_loot_template' Entry 54343 Item 58264: item entry not
--     listed in `item_template` - skipped
--
-- From 142_, which imported Druid of the Flame's loot from nelt_world.  Item
-- 58264 is absent from item_template here, from nelt_world AND from cata_world,
-- so there is nothing to downport -- it is a Neltharion-local id.  Dropping the
-- row is the only correct action; the loot table keeps its other entry.
DELETE FROM `creature_loot_template` WHERE `Entry` = 54343 AND `Item` = 58264;

-- ---------------------------------------------------------------------------
-- STILL OPEN after this round (needs something other than SQL)
-- ---------------------------------------------------------------------------
--   * THE LIVE HOST'S DBC DIRECTORY IS STALE.  The running server reports
--     "No model data exist for CreatureDisplayID = 38002 / 38051 / 38546 /
--     38547" and "Area trigger (ID: 9861 / 9862 / 607000 / 607001) does not
--     exist in AreaTrigger.dbc" -- but the local staging copies under
--     Server/data/dbc contain every one of those rows (CreatureDisplayInfo
--     28,031 rows, AreaTrigger 1,368).  Nothing in the DB can fix that: the
--     dbc directory has to be pushed to /home/wowcore/azeroth-server/data/dbc
--     and the server restarted.  That single deploy clears 8 log lines and is
--     why the round-23 map-861 display work never took effect in game.
--   * AreaTrigger 6194 (Deepholm - Stonecore Exit) and 6581 (Blackwing Descent
--     - Entrance) are genuinely absent from AreaTrigger.dbc in every copy --
--     Deepholm/BWD work, not Hyjal.
-- ---------------------------------------------------------------------------
