-- Worgoblin: open race-gated content to goblins (256) and worgen (2048).
-- ARAC's all-races class-quest mask 1791 is pinned to 4095 FIRST because the
-- generic sweeps exclude sentinel masks (1791|256 would become the excluded 2047).
UPDATE `quest_template` SET `AllowableRaces` = 4095 WHERE `AllowableRaces` = 1791;
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|2048 WHERE `AllowableRaces` & 1 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|256 WHERE `AllowableRaces` & 2 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151);
-- DK 'A Special Surprise' race-specific pins (mod-worgoblin)
UPDATE `quest_template` SET `AllowableRaces` = 1 WHERE `ID` = 12742;
UPDATE `quest_template` SET `AllowableRaces` = 2 WHERE `ID` = 12748;

UPDATE `item_template` SET `AllowableRace` = 4095 WHERE `AllowableRace` = 1791;
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|2048 WHERE `AllowableRace` & 1 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|256 WHERE `AllowableRace` & 2 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 4095, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151);
