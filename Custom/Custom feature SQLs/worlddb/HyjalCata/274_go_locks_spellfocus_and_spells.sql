-- ---------------------------------------------------------------------------
-- 274  gameobject_template data0/data1 -- locks, spell focus objects, spells
-- ---------------------------------------------------------------------------
-- From the "Loading Game Object Templates" block.  Every map-750 line in it is
-- closed by three client DBCs (already compiled and deployed, see below); this
-- file is the DB-side half plus the handful that no client file can fix.
--
-- 🔴 READ THIS BEFORE TRUSTING THE LOG'S NUMBERS.  `CheckGOLockId`
-- (ObjectMgr.cpp:7715) formats its message with `goInfo->door.lockId` -- ALWAYS
-- data[1] -- no matter which field it actually validated:
--     LOG_ERROR(... "have data{}={} but lock (Id: {}) not found.",
--               goInfo->entry, goInfo->type, N, goInfo->door.lockId, goInfo->door.lockId);
-- Only DOOR (0) and BUTTON (1) keep their lockId in data1.  QUESTGIVER, CHEST,
-- TRAP, GOOBER, AREADAMAGE, CAMERA, FLAGSTAND and FLAGDROP read data0, so for
-- all of those the printed value is the WRONG FIELD.  That is why the log is
-- full of "data0=0 but lock (Id: 0) not found" -- data0 is not 0, it is a real
-- lock id the message never shows, and data1 just happens to be 0.  Examples:
--     3794101 "Shatterspear Cage"     logged 0      -> actually lock 1923
--     3795002 "Lava Fissure"          logged 13880  -> actually lock 1835 (13880 is questId)
--     3802952 "Darkwhisper Lodestone" logged 25509  -> actually lock 1874
--     203254  "Orb of Culmination"    logged 0      -> actually lock 700900
-- The spell (type 22) and SpellFocus (type 8) messages print the right field.
--
-- MEASURED, not read off the log: across the whole gameobject_template there are
-- 14 lock ids, 17 SpellFocusObject ids and 26 spells that do not resolve --
-- against the REAL Lock.dbc / SpellFocusObject.dbc / Spell.dbc, never against
-- `lock_dbc` (9 rows, custom only) or `spell_dbc`.  Checking type-22 data0
-- against `spell_dbc` reported 135 "missing" spells; 109 of those are stock and
-- perfectly fine.  Same overlay trap as always.
--
-- CLIENT SIDE, ALREADY COMPILED AND DEPLOYED (patch-4 + enGB/patch-enGB-3 + the
-- three WarcraftXLHost checkouts; 0 ids lost, every pre-existing row verified
-- byte-identical, archive contents re-extracted and md5-matched):
--     Lock.dbc              396 -> 405   (+9)   1821 1822 1826 1835 1843 1874 1923 1939 1963
--     SpellFocusObject.dbc  382 -> 395   (+13)  1595 1609 1611 1623 1633 1634 1635 1651 1656 1658 1659 1661 1662
--     Spell.dbc          53,250 -> 53,257 (+7)  65213 65409 68666 69814 68083 88697 99926
-- Both source DBCs came from the Cata client's **enUS/locale-enUS.MPQ**, not the
-- wow-update-base archives Spell.dbc lives in -- same placement as Vehicle.dbc.
-- Lock is a straight copy (33 fields / 132-byte records on both sides).
-- SpellFocusObject is not: Cata collapsed the 16-locale name array to one
-- string, so its table is 2 fields against this client's 18.
--
-- ---- 1. the 7 spells -------------------------------------------------------
-- 4 are GO type 22 (SPELLCASTER) data0 on map 750.  The other 3 are
-- LOCK_KEY_SPELL entries (Type = 3, SharedDefines.h:2593) inside the 9 locks
-- above -- they raise no boot line of their own, but importing a lock without
-- its key would be half a fix.
--
-- These rows MIRROR the deployed Spell.dbc; they are not what makes the error
-- go away.  The worldserver resolves these ids straight out of Spell.dbc now.
-- `spell_dbc` is kept in step so the DB does not disagree with the client and so
-- the spells survive a DBC rebuild from a different source.
-- Same id-range trap as 272_: 65213, 65409, 68083, 68666 and 69814 all look like
-- WotLK ids and not one of them was in this client.

DELETE FROM acore_world.`spell_dbc` WHERE `ID` IN (65213,65409,68666,69814,68083,88697,99926);

INSERT INTO acore_world.`spell_dbc` VALUES
('65213','0','0','0','256','268435456','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','574','0','0','0','0','0','13','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','6','0','0','0','0','0','0','0','0','0','0','0','0','0','0','25','0','0','0','0','0','0','0','0','4','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Throw Oil Aura','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0'),
('65409','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','21','0','0','0','0','0','3','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','6','6','0','0','0','0','0','0','0','1','0','0','0','0','0','25','25','0','0','0','0','0','0','0','261','260','0','0','0','0','0','0','0','0','0','0','0','0','0','2','282','0','170','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Into the Nightmare','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','1','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0'),
('68666','0','0','0','256','0','132','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','3','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','140','0','0','0','0','0','0','0','0','0','0','0','0','0','0','25','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','68613','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Forcecast Energized','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0'),
('69814','0','0','0','256','0','132','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','3','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','140','0','0','0','0','0','0','0','0','0','0','0','0','0','0','25','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','68744','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Forcecast Fall to Death Port','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0'),
('68083','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','4','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','33','0','0','0','0','0','0','0','0','0','0','0','0','0','0','23','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','5','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Fire Mortar!','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0'),
('88697','0','0','0','384','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','5','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','3','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','86','61','0','0','0','0','0','0','0','0','0','0','0','0','0','40','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','8','27019','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Slash of Tichondrius','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','1','0','0','0','0','0','0','0','36','0','0','0','0','0','0','0','0'),
('99926','0','0','0','65792','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','5','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','12','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','-1','0','0','33','3','0','0','0','0','0','0','0','0','0','0','0','0','0','23','46','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','Bobbing for Apples','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','16712190','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','1','1','0','0','0','0','0','0','0','1','0','0','0','0','0','0','0','0');

-- ---- 2. the 5 locks that exist in no client, any expansion -----------------
-- Cleared rather than invented.  None is in the Cata 4.3.4 Lock.dbc (469 rows)
-- and none can be derived, so the choice is "no lock" or a fabricated one with
-- guessed key/skill requirements.  A GO whose lock cannot be defined is worse
-- than a GO with no lock: with data0 pointing at nothing the core logs on every
-- boot and the object still behaves as unlocked, so clearing changes no
-- behaviour and removes the line.  Every one is reversible -- the original
-- values are in the WHERE clause.
--
--   700900  "Orb of Culmination" (203254, QUESTGIVER, 1 spawn on map 669).
--           A DC-INVENTED id in the 700xxx custom band that was never authored
--           anywhere -- `lock_dbc` holds 9 rows and none is >= 700000.  Someone
--           planned a custom lock and only the reference landed.
--   2000    "Challenge Mode Manager" (700010, GOOBER, 4 spawns, maps 1/37/530).
--           MoP-era lock on a DC-authored GO, carried in from a MoP dump.
--   2155    "Desmonds Lockbox" (4100248, CHEST, 1 spawn, Legion Dalaran).
--   2173    "Knocker" x4 (4100262/63/78/79, GOOBER, 0 spawns).
--   3212    the four anima containers (352737-352740, GOOBER, 0 spawns) --
--           Shadowlands.
UPDATE acore_world.`gameobject_template` SET `data0` = 0
WHERE `type` IN (2,3,6,10,12,13,24,26) AND `data0` IN (700900,2000,2155,2173,3212);

-- Verify after apply -- and note the real verification is the boot log, since
-- the DBC half is what clears most of these:
--   SELECT COUNT(*) FROM gameobject_template
--    WHERE type IN (2,3,6,10,12,13,24,26) AND data0 IN (700900,2000,2155,2173,3212);   -> 0
--   SELECT COUNT(*) FROM spell_dbc WHERE ID IN (65213,65409,68666,69814,68083,88697,99926);  -> 7
-- and the block loses all 9 lock lines, all 13 SpellFocus lines and all 5
-- map-750 spell lines, plus the 6 undefinable-lock lines above.
--
-- ---- NOT fixed here, and why ----------------------------------------------
-- **2 lock key ITEMS are still missing**: Lock 1826 ("Horde Explosives",
-- 3794482) wants item 45465 and Lock 1923 ("Shatterspear Cage", 3794101 /
-- 3894101) wants 45040.  Neither is in `item_template` here nor in nelt_world.
-- They raise no boot line -- the lock loads fine, it just cannot be opened by
-- its intended key -- so this is a follow-up item downport, not a regression.
-- The other three keys (44925 Corruptor's Master Key, 49533 Ironwrought Key,
-- 54788 Twilight Pick) all exist.
--
-- **The Legion Dalaran block (map 1413, entries 4100xxx) is untouched.**
-- 22 retail spells, 4 SpellFocusObject ids and its share of the locks resolve in
-- no client older than Legion, so nothing can be downported for them -- they
-- need substitution or removal, which is a design decision about that build
-- rather than a data gap.  Left logging deliberately.
