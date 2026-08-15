--
-- Legion Dalaran guild house (map 1413): make the bank-hall Guild Vaults functional.
--
-- 4100154 and 4100155 were imported as type 5 (GAMEOBJECT_TYPE_GENERIC) -- pure
-- decoration, no interaction at all. They already carry displayId 8113, the same
-- model stock guild vaults 191319/193086-193089 use, so only the type is wrong.
--
-- type 34 = GAMEOBJECT_TYPE_GUILD_BANK. No Data fields and no ScriptName are
-- needed: every stock type-34 vault has Data0..Data2 = 0. The client itself sends
-- CMSG_GUILD_BANKER_ACTIVATE on right-click once it knows the object is type 34
-- (WorldSession::HandleGuildBankerActivate, GuildHandler.cpp:280).
--
-- NOT converted here: 4100050 and 4100051. Those sit at the exact x/y of the
-- already-working stock vaults 187293 (guids 9000326 / 9000380) and would give two
-- overlapping clickable vaults. They should be deleted rather than converted --
-- say the word and that is a separate one-liner.
--
-- The cache_id bump is REQUIRED, not optional. The 3.3.5 client caches
-- GAMEOBJECT_QUERY_RESPONSE in Cache\WDB\<locale>\gameobjectcache.wdb and never
-- re-queries an entry it has already seen, so without it any client that has
-- looked at these objects keeps treating them as type 5 and will never send the
-- activate opcode.
--

UPDATE `gameobject_template` SET `type`=34 WHERE `entry` IN (4100154,4100155);

UPDATE `version` SET `cache_id`=`cache_id`+1;
