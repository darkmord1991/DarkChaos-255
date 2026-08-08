-- ---------------------------------------------------------------------------
-- 275  The 2 lock key items 274_ left open
-- ---------------------------------------------------------------------------
-- 274_ imported 9 Cata locks; two of them name a key item this DB has never
-- had, so the lock loaded and the object still could not be opened:
--
--   Lock 1826 -> item 45465, on GO 3794482 "Horde Explosives"
--   Lock 1923 -> item 45040, on GO 3794101 / 3894101 "Shatterspear Cage"
--
-- Neither raises a boot line -- `LockKeyType` 1 (ITEM) is not validated at load
-- -- which is exactly why this class of gap survives rounds of log-driven work.
-- The other three keys of the set (44925 Corruptor's Master Key, 49533
-- Ironwrought Key, 54788 Twilight Pick) were already present.
--
-- 🔴 THE NAMES CONFIRM THE WHOLE CHAIN, and that is the point of sourcing them
-- rather than inventing placeholders: 45040 reads
-- **"Shatterspear Torturer's Cage Key"** against a GO called "Shatterspear
-- Cage". If a name had come back unrelated it would have meant the lock->item
-- mapping was wrong, not that the item was missing.
--
-- SOURCE + CALIBRATION.  Class/subclass/material/displayid come from the Cata
-- 4.3.4 `Item.db2`; name, flags, quality and counts from `Item-sparse.db2`.
-- Take Item-sparse from **enUS/locale-enUS.MPQ** -- the wow-update-enUS-*
-- copies are PTCH binary deltas (magic `PTCH`), not tables, and parsing one
-- yields garbage.
--
-- Neither table's field order was assumed.  Guessing which words are strings
-- produced convincing nonsense (44925 "read" as *Martin Fury*), so the Name
-- index was CALIBRATED: locate three names we already hold in `item_template`
-- inside the string block and find which word holds their offset -- all three
-- agree on word 99.  Flags/FlagsExtra were calibrated the same way against
-- 49533's live row (8390720 / 8192), which reproduced exactly, and maxcount
-- against 44925 (0) and 54788 (1).
--
-- NO CLIENT WORK.  Both display ids already ship: 37458 = `INV_Misc_Idol_01`,
-- 9154 = `INV_Misc_Key_07`.  And no `Item.dbc` row is added, deliberately --
-- 49533 and 54788 are absent from it too and work fine, because
-- `ObjectMgr::LoadItemTemplates` only `LOG_DEBUG`s a missing dbcitem
-- (ObjectMgr.cpp:3500-3502) and the client learns the item from
-- SMSG_ITEM_QUERY_SINGLE_RESPONSE.  Matching the existing convention also keeps
-- this out of Item.dbc, which is the file with the item-upgrade interactions.

DELETE FROM acore_world.`item_template` WHERE `entry` IN (45465,45040);
INSERT INTO acore_world.`item_template`
(`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`Material`,`sheath`,`bonding`,`startquest`,`VerifiedBuild`) VALUES
(45465,12,0,-1,'Warsong Shredder Blade',37458,1,0,8192,1,0,0,0,-1,-1,1,0,1,1,4,0,4,0,15595),
(45040,13,0,-1,'Shatterspear Torturer''s Cage Key',9154,1,8390720,8192,1,0,0,0,-1,-1,1,0,1,1,4,0,4,0,15595);

-- Verify after apply:
--   SELECT entry, name, class, displayid, Flags FROM item_template
--    WHERE entry IN (45465,45040);                                    -> 2 rows
--   and in game, "Horde Explosives" and both "Shatterspear Cage" objects can
--   finally be opened by the key their lock has always asked for.
