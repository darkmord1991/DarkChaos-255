-- Allied races: open race-gated content to bits 23/24 (Horde) and 25 (Alliance).
-- All-race sentinels are pinned FIRST (Worgoblin's sweep-order lesson). The running
-- all-races mask grows each port: 4095 -> 6295551 (pandaren) -> 65015807 (these three).
UPDATE `quest_template` SET `AllowableRaces` = 65015807 WHERE `AllowableRaces` IN (1791, 4095, 6295551);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|33554432 WHERE `AllowableRaces` & 1 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|25165824 WHERE `AllowableRaces` & 2 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);

UPDATE `item_template` SET `AllowableRace` = 65015807 WHERE `AllowableRace` IN (1791, 4095, 6295551);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|33554432 WHERE `AllowableRace` & 1 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|25165824 WHERE `AllowableRace` & 2 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);
