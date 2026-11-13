--
-- DarkChaos: map 751 (Lordaeron, levels 130-160) needs a fifth of the XP per level.
-- At 130-159 a level took 4.17M-5.62M XP (147M for the band) against about 68k per quest at Rate.XP.Quest 2, so
-- all of 751's quests covered 12% (Alliance) to 19% (Horde) of the band. A fifth leaves about 12-17 quests per level.
-- The values come from the level, as the stock curve does (1,670,800 + 50,000 per level above 80, divided by 5),
-- so running this again changes nothing. Level 160 and up keep the full curve.
UPDATE `player_xp_for_level` SET `Experience` = 334160 + (`Level` - 80) * 10000 WHERE `Level` BETWEEN 130 AND 159;
