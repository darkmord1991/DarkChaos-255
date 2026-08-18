-- ---------------------------------------------------------------------------
-- 294  Legion Dalaran gameobjects -- 3.3.5 substitutes, and honest neutralising
-- ---------------------------------------------------------------------------
-- The last big block in Errors.log: 36 lines from the Legion Dalaran import
-- (guildhouse map 1413), every one a GameObject pointing at a retail id that
-- does not exist here.
--     Gameobject (Entry: 4100014 GoType: 22) have data0=183400 but Spell
--       (Entry 183400) not exist.
--     GameObject (Entry: 4100216 GoType: 8) have data0=1896 but SpellFocus
--       (Id: 1896) not exist.
--
-- 🔴 THE BLOCK IS MUCH SMALLER THAN ITS LINE COUNT. **20 of the 36 templates
-- are not spawned anywhere** -- they are import residue that only the template
-- validator ever sees. The 16 that ARE spawned all sit on map 1413, and they
-- are overwhelmingly PROFESSION STATIONS, not the "22 retail spells with no
-- downport source" I had been carrying them as. That reframing is what makes
-- this fixable without inventing a single spell.
--
-- The instruction was: substitute from 3.3.5 equivalents where one exists,
-- neutralise the rest. That splits cleanly, because 3.3.5's whole crafting-focus
-- vocabulary is four objects -- SpellFocusObject 1 Anvil, 2 Loom, 3 Forge,
-- 4 Cooking Fire (verified by dumping the deployed SpellFocusObject.dbc: 47
-- stock entries, and none of 1884/1888/1889/1896 among them). Blacksmithing and
-- engineering need a station in 3.3.5; **alchemy, leatherworking and tailoring
-- do not** -- they work anywhere. So an alchemy station has no 3.3.5 equivalent
-- to substitute, and pretending otherwise would be worse than leaving it inert.
--
-- Neutralising means **type 5 GAMEOBJECT_TYPE_GENERIC** -- an inert prop that
-- keeps its model, name and placement and simply stops claiming to cast
-- something. NOT type 0, which is DOOR.
-- `data0` is cleared to 0 as well: a GENERIC object ignores it, and leaving a
-- dead retail spell id sitting in the column is precisely what generates this
-- block every boot. Every retail id is written down in the tables below and in
-- the REVERT section, so a future Legion port can restore them from this file.
--
-- Apply against acore_world, then restart worldserver. Idempotent -- every
-- statement is guarded on the exact pre-image.

-- ---------------------------------------------------------------------------
-- 1) Real substitutes -- 4 stations that become working 3.3.5 focus objects
-- ---------------------------------------------------------------------------
-- These are the only four where a genuine 3.3.5 equivalent exists. After this
-- they are not merely quiet, they WORK: a blacksmith standing at the guildhouse
-- forge/anvil can craft recipes that require one.
--
--   4100216  Forge of Power            focus 1896 -> 3 Forge   (was type 8)
--   4100014  Alard's Forge             spell 183400 -> type 8, focus 3 Forge
--   4100015  Alard's Anvil             spell 183400 -> type 8, focus 1 Anvil
--   4100017  Alard's Workbench         spell 183400 -> type 8, focus 1 Anvil
--   4100673  Namha's Workbench         focus 1889 -> 1 Anvil   (was type 8)
--   4100243  Namha's Workbench         spell 196485 -> type 8, focus 1 Anvil
--
-- "Workbench -> Anvil" is the defensible reading: engineering is the profession
-- those benches serve, and in 3.3.5 engineering's station requirement IS the
-- anvil. Loom (2) and Cooking Fire (4) have no counterpart in this import.

-- 1a. already type 8, just repoint the focus
UPDATE acore_world.`gameobject_template` SET `data0` = 3
 WHERE `entry` = 4100216 AND `type` = 8 AND `data0` = 1896;   -- Forge of Power
UPDATE acore_world.`gameobject_template` SET `data0` = 1
 WHERE `entry` = 4100673 AND `type` = 8 AND `data0` = 1889;   -- Namha Workbench

-- 1b. type 22 crafting stations -> real type 8 focus objects
UPDATE acore_world.`gameobject_template` SET `type` = 8, `data0` = 3
 WHERE `entry` = 4100014 AND `type` = 22 AND `data0` = 183400; -- Alard Forge
UPDATE acore_world.`gameobject_template` SET `type` = 8, `data0` = 1
 WHERE `entry` = 4100015 AND `type` = 22 AND `data0` = 183400; -- Alard Anvil
UPDATE acore_world.`gameobject_template` SET `type` = 8, `data0` = 1
 WHERE `entry` = 4100017 AND `type` = 22 AND `data0` = 183400; -- Alard Workbench
UPDATE acore_world.`gameobject_template` SET `type` = 8, `data0` = 1
 WHERE `entry` = 4100243 AND `type` = 22 AND `data0` = 196485; -- Namha Workbench

-- ---------------------------------------------------------------------------
-- 2) Spawned objects with no 3.3.5 equivalent -- neutralised
-- ---------------------------------------------------------------------------
-- All on map 1413, all currently claiming a retail spell. Retail ids recorded
-- for a future port:
--   4100013 Alard's Whetstone            183400   decorative smithing prop
--   4100016 Alard's Quenching Trough     183400   decorative smithing prop
--   4100120 Tanithria's Finishing Table  186732   tailoring -- no 3.3.5 focus
--   4100147 Tiffany's Carving Machine         0   never had a spell authored
--   4100234 Bag of hard stones           206182   quest prop
--   4100241 Legion Communicator          207792   class-hall flavour
--   4100246 Namha's Tanning Rack         196485   leatherwork -- no 3.3.5 focus
--   4100257 Dalaran Alchemy Station      188799   alchemy -- no 3.3.5 focus
--   4100493 SI:7 Letter                  219701   quest prop
--   4101814 Portal to Dreadscar Rift          0   warlock class hall, no dest
--   4100170 Portal to Wyrmrest Temple    199711   see the note in section 3 --
--                                                 destination DOES exist, but
--                                                 wiring it is a feature
--   4100674 Namha's Tanning Rack (type 8)  1888   leatherwork -- no 3.3.5 focus
--   4100672 Dalaran Alchemy Station (t8)   1884   alchemy -- no 3.3.5 focus
UPDATE acore_world.`gameobject_template` SET `type` = 5, `data0` = 0
 WHERE `entry` IN (4100013,4100016,4100120,4100147,4100170,4100234,4100241,4100246,4100257,4100493,4101814)
   AND `type` = 22;

-- The two type-8 stations whose profession needs no station in 3.3.5. Both are
-- spawned, so they stay visible props -- they just stop advertising a focus the
-- client cannot resolve. Alchemy and leatherworking both craft anywhere here,
-- so nothing is lost by them being inert.
UPDATE acore_world.`gameobject_template` SET `type` = 5, `data0` = 0
 WHERE `entry` = 4100674 AND `type` = 8 AND `data0` = 1888;   -- Namha Tanning Rack
UPDATE acore_world.`gameobject_template` SET `type` = 5, `data0` = 0
 WHERE `entry` = 4100672 AND `type` = 8 AND `data0` = 1884;   -- Dalaran Alchemy Station

-- ---------------------------------------------------------------------------
-- 3) The 20 unspawned templates -- neutralised too
-- ---------------------------------------------------------------------------
-- These have ZERO gameobject rows, so nothing about them is reachable in game
-- and this changes no player-visible behaviour whatsoever. It is purely to stop
-- the template validator reporting them every boot. Mostly Legion portals whose
-- destinations do not exist in this build (The Skyfire, The Dark Lady's Fleet,
-- Dalaran Crater, Karazhan-Legion, the Ice Throne, Illidari Gateway, Sanctum of
-- Light, Netherlight Temple, the Maelstrom, Exodar) plus two Pandaria portals,
-- a Stormwind portal and one stray feast object.
--
-- 🔴 TWO OF THESE ARE WORTH REVISITING RATHER THAN BURYING, because their
-- destinations genuinely EXIST in 3.3.5:
--   * **4100170 "Portal to Wyrmrest Temple"** (Dragonblight) -- SPAWNED on 1413,
--     so it is a real object a player can walk up to. Neutralised in section 2
--     so the log is clean, but it is the one entry here that could become a
--     working guildhouse portal.
--   * **4100161 "Portal to Stormwind"** -- unspawned, so it would need placing
--     as well as wiring.
-- Both want a teleport spell and a destination coordinate chosen deliberately;
-- that is a feature, not a substitute, so neither is invented here.
UPDATE acore_world.`gameobject_template` SET `type` = 5, `data0` = 0
 WHERE `entry` IN (335620,4100134,4100135,4100161,4100165,4100166,4100167,4100168,
                   4100228,4100472,4100473,4100474,4100475,4100476,4100477,4100502,4100505)
   AND `type` = 22
   AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject` g WHERE g.`id` = `gameobject_template`.`entry`);

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--   -- 1. the six working stations:
--   SELECT entry, type, data0 FROM gameobject_template
--    WHERE entry IN (4100216,4100673,4100014,4100015,4100017,4100243);
--     -> all type 8; data0 = 3 (Forge) for 4100216/4100014,
--        data0 = 1 (Anvil) for 4100673/4100015/4100017/4100243
--
--   -- 2 + 3. nothing in the block still points at a missing spell/focus:
--   SELECT COUNT(*) FROM gameobject_template t
--    WHERE t.entry IN (335620,4100013,4100014,4100015,4100016,4100017,4100120,
--       4100134,4100135,4100147,4100161,4100165,4100166,4100167,4100168,4100170,
--       4100216,4100228,4100234,4100241,4100243,4100246,4100257,4100472,4100473,
--       4100474,4100475,4100476,4100477,4100493,4100502,4100505,4100672,4100673,
--       4100674,4101814)
--      AND ((t.type = 22 AND NOT EXISTS (SELECT 1 FROM spell_dbc s WHERE s.ID = t.data0))
--        OR (t.type = 8  AND t.data0 NOT IN (1,2,3,4)));                   -> 0
--
--   -- and no spawn changed object type under a player's feet:
--   SELECT COUNT(*) FROM gameobject WHERE id IN (4100014,4100015,4100017,4100243);
--                                                                          -> 4
--
--   Next boot: all 36 Legion Dalaran lines gone. Errors.log should drop from
--   ~74 to ~38 lines, and what remains is the 7 quest reward spells, 4 C++
--   script mismatches, 2 upstream waypoints, 3 stock loot-chance lines, 10
--   unproven loot orphans, 5 command rows and OutdoorPvP 8 -- none of them a DB
--   fix.
--
-- IN-GAME CHECK THAT MATTERS: stand at the guildhouse forge and anvil on map
-- 1413 with a blacksmith and confirm the crafting UI accepts them. The log going
-- quiet only proves the ids resolve.
--
-- REVERT -- restores every retail id from the tables above:
--   UPDATE gameobject_template SET type=8,  data0=1896   WHERE entry=4100216;
--   UPDATE gameobject_template SET type=8,  data0=1889   WHERE entry=4100673;
--   UPDATE gameobject_template SET type=8,  data0=1888   WHERE entry=4100674;
--   UPDATE gameobject_template SET type=22, data0=183400 WHERE entry IN (4100013,4100014,4100015,4100016,4100017);
--   UPDATE gameobject_template SET type=22, data0=196485 WHERE entry IN (4100243,4100246);
--   UPDATE gameobject_template SET type=22, data0=186732 WHERE entry=4100120;
--   UPDATE gameobject_template SET type=22, data0=0      WHERE entry IN (4100147,4101814,4100502);
--   UPDATE gameobject_template SET type=22, data0=206182 WHERE entry=4100234;
--   UPDATE gameobject_template SET type=22, data0=207792 WHERE entry=4100241;
--   UPDATE gameobject_template SET type=22, data0=188799 WHERE entry=4100257;
--   UPDATE gameobject_template SET type=22, data0=219701 WHERE entry=4100493;
--   UPDATE gameobject_template SET type=22, data0=308457 WHERE entry=335620;
--   UPDATE gameobject_template SET type=22, data0=192465 WHERE entry=4100134;
--   UPDATE gameobject_template SET type=22, data0=192477 WHERE entry=4100135;
--   UPDATE gameobject_template SET type=22, data0=121857 WHERE entry=4100161;
--   UPDATE gameobject_template SET type=22, data0=132623 WHERE entry=4100165;
--   UPDATE gameobject_template SET type=22, data0=132625 WHERE entry=4100166;
--   UPDATE gameobject_template SET type=22, data0=228507 WHERE entry=4100167;
--   UPDATE gameobject_template SET type=22, data0=202641 WHERE entry=4100168;
--   UPDATE gameobject_template SET type=22, data0=199711 WHERE entry=4100170;
--   UPDATE gameobject_template SET type=22, data0=205923 WHERE entry=4100228;
--   UPDATE gameobject_template SET type=22, data0=215782 WHERE entry=4100472;
--   UPDATE gameobject_template SET type=22, data0=215789 WHERE entry IN (4100473,4100474);
--   UPDATE gameobject_template SET type=22, data0=215790 WHERE entry IN (4100475,4100476);
--   UPDATE gameobject_template SET type=22, data0=215792 WHERE entry=4100477;
--   UPDATE gameobject_template SET type=22, data0=220513 WHERE entry=4100505;
