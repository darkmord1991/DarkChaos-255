-- DarkChaos Azshara Crater (map 37): the skeleton camp of "The Wailing Noble" (300204, quest level 18) down to the
-- level 16-17 range. In meter run 15 (11-23) bots of level 14-15 died in 31-37% of their fights there; the mages
-- (level 18-19 copies of Duskwood's 203) did most of it. Re-runnable.

-- 1) The six mages become Deathcage Sorcerer (16308), a stock skeleton mage from Ghostlands, level 16-18: Frostbolt
--    20792 like the Skeletal Mage, plus Frost Nova. It has no equipment row, so the spawns drop equipment_id 1.
--    The copy 300098 keeps its template rows but no spawns.
UPDATE `creature` SET `id` = 16308, `equipment_id` = 0
    WHERE `id` = 300098 AND `guid` IN (9000632, 9000633, 9000634, 9000635, 9000636, 9000637);

-- 2) No stock skeleton warrior is level 16-17 (Duskwood's Skeletal Warrior 48 is 21-22, Ghostlands' Dreadbone
--    Sentinel 16305 17-18), so the copy 300097, the quest's kill target, is set to 16-17.
UPDATE `creature_template` SET `minlevel` = 16, `maxlevel` = 17 WHERE `entry` = 300097;
