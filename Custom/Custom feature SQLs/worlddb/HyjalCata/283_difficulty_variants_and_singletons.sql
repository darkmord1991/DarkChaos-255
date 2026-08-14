-- ---------------------------------------------------------------------------
-- 283  Blackwing Descent difficulty variants + 5 singletons
-- ---------------------------------------------------------------------------
--     Creature (Entry: 42179) lists difficulty 2 mode entry 49048 with
--     `ScriptName` filled in. `ScriptName` of difficulty 0 mode creature is
--     always used instead.
--
-- 🔴 CORRECTION TO 271_. That file dismissed this class as "upstream AC data,
-- informational -- clearing the ScriptNames would change nothing and risks
-- breaking a heroic script". Both halves were wrong: these are **DC's own
-- BlackwingDescent downport**, not upstream, and clearing them is provably
-- behaviour-neutral. Verified rather than assumed:
--   * all 36 heroic variants have **0 spawns of their own** -- they exist only
--     as difficulty rows, so nothing can spawn them directly;
--   * every one carries the **same ScriptName as its difficulty-0 parent**
--     (36 of 36), so the script that runs is identical either way;
--   * `CheckCreatureTemplate` only ever uses difficulty-0's ScriptID anyway.
--
-- 🔴 AND YOU MUST FIX BOTH DIFFICULTY SLOTS, OR THE ROUND LOOKS LIKE A NO-OP.
-- The validation loop is
--     bool ok = true;
--     for (uint32 diff = 0; diff < MAX_DIFFICULTY - 1 && ok; ++diff)
--     {   if (!cInfo->DifficultyEntry[diff]) continue;
--         ok = false;                       // restored only at the very end
-- (ObjectMgr.cpp:969-974). `ok` goes false on entry and is restored only after
-- every check passes, and the loop condition tests it -- so the difficulty-2
-- `continue` at the ScriptName check **aborts the whole loop** and
-- `difficulty_entry_3` is never examined at all. The 18 slot-3 variants carry
-- the identical defect and are simply hidden behind the slot-2 one. Clear only
-- slot 2 and the next boot logs 18 brand-new slot-3 lines instead.
--
-- Same mechanism explains 41440 in section 3: 271_ cleared its
-- `difficulty_entry_2`, which let the loop reach slot 3 for the first time and
-- surfaced an error that had been hidden all along.

-- ---- 1. the 36 heroic ScriptNames (both slots) -----------------------------
-- Derived, not listed: any creature that is some other creature's difficulty
-- variant, has a ScriptName, and has no spawns of its own. The `NOT EXISTS`
-- spawn guard is what makes this safe to re-run and safe against a future
-- heroic template that IS spawned directly.
UPDATE acore_world.`creature_template` d
JOIN acore_world.`creature_template` n ON n.`difficulty_entry_2` = d.`entry`
SET d.`ScriptName` = ''
WHERE d.`ScriptName` <> ''
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature` c WHERE c.`id` = d.`entry`);

UPDATE acore_world.`creature_template` d
JOIN acore_world.`creature_template` n ON n.`difficulty_entry_3` = d.`entry`
SET d.`ScriptName` = ''
WHERE d.`ScriptName` <> ''
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature` c WHERE c.`id` = d.`entry`);

-- ---- 2. Chimaeron's family, on both heroic variants ------------------------
--     Creature (Entry: 43296, family 38) has different `family` in difficulty 2
--     mode (Entry: 47775, family 0).
--
-- 43296 Chimaeron is type 1 (Beast) family 38; its heroic copies were imported
-- with family 0. The difficulty-0 creature is authoritative, so the variants are
-- brought to match rather than the reverse. 47776 is the slot-3 twin and is
-- included for the reason above -- it would otherwise become the next boot's
-- new error the moment section 1 lets the loop advance.
-- Written as two equality joins rather than one `d.entry IN (n.d2, n.d3)`:
-- that form cannot use the index and did not finish when dry-run against the
-- live table.
UPDATE acore_world.`creature_template` d
JOIN acore_world.`creature_template` n ON n.`difficulty_entry_2` = d.`entry`
SET d.`family` = n.`family`
WHERE n.`family` <> d.`family`;

UPDATE acore_world.`creature_template` d
JOIN acore_world.`creature_template` n ON n.`difficulty_entry_3` = d.`entry`
SET d.`family` = n.`family`
WHERE n.`family` <> d.`family`;

-- ---- 3. 41440's remaining difficulty slot ----------------------------------
--     Creature (Entry: 41440) has `difficulty_entry_3`=49983 but creature entry
--     49983 does not exist.
--
-- My own loose end: 271_ cleared this creature's `difficulty_entry_2` (49977)
-- and stopped there. 49983 exists in cata_world but not here, and the same
-- reasoning applies -- 41440 "Aberration" has **0 spawns**, so importing a whole
-- heroic template to satisfy a pointer nothing reaches is not worth it.
-- `difficulty_entry_1` (49971) exists and is left alone.
UPDATE acore_world.`creature_template` SET `difficulty_entry_3` = 0
WHERE `entry` = 41440 AND `difficulty_entry_3` = 49983;

-- ---- 4. three gossip menus with no GOSSIP npcflag --------------------------
--     Creature (Entry: 810002) has assigned gossip menu 3664, but npcflag does
--     not include UNIT_NPC_FLAG_GOSSIP (1).
--
-- All three have a real `gossip_menu` row and live spawns, so the menu simply
-- cannot open: 810002 "Thrall Warchief" (DC custom, 2 spawns, npcflag 0),
-- 3500320 "The Great Akazamzarak" and 3500503 "Light's Heart" (Legion Dalaran,
-- 1 spawn each, npcflag 2 = QUESTGIVER). OR'd so the existing flags survive --
-- same fix 271_ applied to 3725924.
UPDATE acore_world.`creature_template` SET `npcflag` = `npcflag` | 1
WHERE `entry` IN (810002,3500320,3500503) AND `gossip_menu_id` > 0 AND (`npcflag` & 1) = 0;

-- ---- 5. the one invalid creature type in the database ----------------------
--     Creature (Entry: 3501012) has invalid creature type (14) in `type`.
--
-- 🔴 NOT COSMETIC. `CheckCreatureTemplate` (ObjectMgr.cpp:1151-1155) does not
-- just warn -- it rewrites the value to **CREATURE_TYPE_HUMANOID** at load. So
-- "Young Mutant Warturtle" (3 spawns, map 1413) is a humanoid at runtime, which
-- changes spell type-masks, Track Beasts, and tameability.
--
-- Type 1 (Beast) is derived, not guessed: every other turtle in the database is
-- type 1 -- Coral Shell, Dragon, Sea, Sand, Riding, Tamable, Tamed. 14 is
-- outside the 3.3.5 enum entirely (CREATURE_TYPE_GAS_CLOUD = 13 is the max),
-- and this is the ONLY creature in the DB with type > 13.
UPDATE acore_world.`creature_template` SET `type` = 1
WHERE `entry` = 3501012 AND `type` = 14;

-- Verify after apply -- all must return 0:
--   SELECT COUNT(*) FROM creature_template n JOIN creature_template d
--     ON d.entry IN (n.difficulty_entry_2, n.difficulty_entry_3)
--    WHERE d.ScriptName <> '' OR n.family <> d.family;
--   SELECT COUNT(*) FROM creature_template WHERE type > 13;
--   SELECT COUNT(*) FROM creature_template WHERE entry=41440 AND difficulty_entry_3<>0;
--   SELECT COUNT(*) FROM creature_template
--    WHERE gossip_menu_id > 0 AND (npcflag & 1) = 0
--      AND entry IN (810002,3500320,3500503);
-- Expect the boot log to lose 20 lines and gain none -- the point of doing both
-- difficulty slots in one pass.
