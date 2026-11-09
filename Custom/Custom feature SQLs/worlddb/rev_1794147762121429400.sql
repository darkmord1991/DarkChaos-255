-- Startup error-log cleanup from the 2026-11-08 server log pass. Only deletes; safe to run twice.
-- Every delete re-checks that nothing uses the row, so a row that gained a user before this is applied stays.
--
-- 1. pool 300040 "Emerald Sanctum - rare elite": spawn 16520010 no longer exists. Its pool member goes; the pool
--    keeps 16520011 alone, so that rare spawns every time until the pool is redone.
-- 2. creature_template 4010151-4010153: the old Timbermaw Hold rares the Turtle port left in place
--    (rev_1793212190166823600). No spawns, models, loot, text or SmartAI rows; nothing references them.
--    Deleting from creature_template is intended (custom ids only); codestyle-sql flags it.
-- 3. Loot tables nothing points at:
--    pickpocketing 400500-400521, skinning 400523: the level-50 Atal'ai tables (GiantIsles/fix_db_errors_batch4).
--      The level-80 Sunken Temple copy re-pointed those creatures to 27533 / 70212 (GiantIsles/rev_1791031658174280700).
--    skinning 3825: stock Ghostpaw Alpha table; the template uses the identical copy 100010.
--    pickpocketing 52871, 53085, 53143, 3709460 and skinning 52107, 52648, 52981, 53240, 53656: no creature has
--      that entry and no template points at them (Cata import leftovers).
--    reference 24152, 24737: not stock and no loot row references them.

DELETE FROM `pool_creature` WHERE `pool_entry` = 300040 AND `guid` = 16520010
    AND NOT EXISTS (SELECT 1 FROM `creature` WHERE `guid` = 16520010);

DELETE FROM `creature_template` WHERE `entry` IN (4010151, 4010152, 4010153)
    AND NOT EXISTS (SELECT 1 FROM `creature` WHERE `creature`.`id` = `creature_template`.`entry`);

DELETE FROM `pickpocketing_loot_template`
    WHERE `Entry` IN (400500, 400501, 400502, 400504, 400505, 400510, 400511, 400512, 400513, 400520, 400521,
                      52871, 53085, 53143, 3709460)
    AND NOT EXISTS (SELECT 1 FROM `creature_template` WHERE `creature_template`.`pickpocketloot` = `pickpocketing_loot_template`.`Entry`);

DELETE FROM `skinning_loot_template`
    WHERE `Entry` IN (400523, 3825, 52107, 52648, 52981, 53240, 53656)
    AND NOT EXISTS (SELECT 1 FROM `creature_template` WHERE `creature_template`.`skinloot` = `skinning_loot_template`.`Entry`);

-- A reference can be used from any loot table. Nested use inside reference_loot_template is not checked: a DELETE
-- cannot read its own table (error 1093), and on 2026-11-08 no reference row pointed at either entry.
DELETE FROM `reference_loot_template`
    WHERE `Entry` IN (24152, 24737)
    AND `Entry` NOT IN (
        SELECT `Reference` FROM `creature_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `gameobject_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `item_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `disenchant_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `fishing_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `mail_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `milling_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `pickpocketing_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `prospecting_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `skinning_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `spell_loot_template` WHERE `Reference` IN (24152, 24737)
        UNION SELECT `Reference` FROM `player_loot_template` WHERE `Reference` IN (24152, 24737)
    );
