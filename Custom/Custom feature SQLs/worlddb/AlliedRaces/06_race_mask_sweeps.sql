-- NOTE (2026-08-28): the per-faction test below keys on the HUMAN bit for Alliance and the ORC
-- bit for Horde. That is too narrow -- anything allowed to e.g. Troll + Tauren but NOT Orc never
-- opened to the new races, which cost ~3,060 items and ~90 quests per race. 14_playability_fixes.sql
-- redoes both sweeps against ANY stock race of the faction (Alliance 3149, Horde 946) and is the
-- version to copy for the next race. Left as-is here because it is idempotent and 14_ supersedes it.

-- Allied races: open race-gated content to bits 23/24 (Horde) and 25 (Alliance).
-- All-race sentinels are pinned FIRST (Worgoblin's sweep-order lesson). The running
-- all-races mask grows each port: 4095 -> 6295551 (pandaren) -> 65015807 (these three).
UPDATE `quest_template` SET `AllowableRaces` = 65015807 WHERE `AllowableRaces` IN (1791, 4095, 6295551);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|33554432 WHERE `AllowableRaces` & 1 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);
UPDATE `quest_template` SET `AllowableRaces` = `AllowableRaces`|25165824 WHERE `AllowableRaces` & 2 AND `AllowableRaces` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);

UPDATE `item_template` SET `AllowableRace` = 65015807 WHERE `AllowableRace` IN (1791, 4095, 6295551);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|33554432 WHERE `AllowableRace` & 1 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);
UPDATE `item_template` SET `AllowableRace` = `AllowableRace`|25165824 WHERE `AllowableRace` & 2 AND `AllowableRace` NOT IN (-1, 2147483647, 2047, 8191, 16383, 32767, 65535, 131071, 262143, 524287, 1048575, 2097151, 6295551, 65015807);
