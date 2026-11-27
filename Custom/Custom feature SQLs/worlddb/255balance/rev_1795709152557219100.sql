-- DarkChaos: hunter pets gain strength above level 80 like warlock pets do.
-- pet_levelstats was extended to 255 with hunter pets (creature_entry 1) at +3 strength per level above 80 (192 at 80,
-- 432 at 160), warlock pets at +29 (314 -> 2,634). Pet attack power is 2 x strength - 20 plus 22% of the hunter's
-- ranged attack power, so hunter pets fell far behind the creatures they fight: Beast Mastery pets gave only 23-27% of
-- BM damage (WotLK BM ~35-40%) and BM ended ~40% below the median damage spec above 80. Hunter pets now gain +29 per
-- level above 80 too (2,512 at 160, 5,267 at 255); levels 1-80 are untouched. The WHERE clause only matches the old
-- +3 curve, so a second run changes nothing. Pets take the new values when they are next summoned or level up.
UPDATE `pet_levelstats` SET `str` = 192 + 29 * (`level` - 80)
    WHERE `creature_entry` = 1 AND `level` > 80 AND `str` = 192 + 3 * (`level` - 80);
