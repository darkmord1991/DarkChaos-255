-- Pandaren: open race-gated content to races 22 (bit 0x200000) / 23 (bit 0x400000).
-- All-race sentinel masks are pinned FIRST (same ordering lesson as Worgoblin: a
-- sentinel caught by the generic sweep would land on an excluded value).
-- 1791 = pre-worgoblin ARAC sentinel (in case rows were added since), 4095 = the
-- post-worgoblin all-races mask. New all-races mask = 4095 | 6291456 = 6295551.
UPDATE `quest_template` SET `AllowableRaces` = 6295551 WHERE `AllowableRaces` IN (1791, 4095);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|2097152 WHERE `AllowableRaces` & 1 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|4194304 WHERE `AllowableRaces` & 2 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551);

UPDATE `item_template` SET `AllowableRace` = 6295551 WHERE `AllowableRace` IN (1791, 4095);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|2097152 WHERE `AllowableRace` & 1 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|4194304 WHERE `AllowableRace` & 2 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551);
