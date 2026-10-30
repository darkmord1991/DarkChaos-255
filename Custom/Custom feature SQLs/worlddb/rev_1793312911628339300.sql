-- DarkChaos phasing cleanup
-- 1) Cata phase auras 74095, 74096 and 74097 (Phase - Quest Zone-Specific 18/19/20, phase bits 24-26) in
--    creature_template_addon move these creatures out of phase 1, so no player ever sees them. Nothing on
--    maps 750 and 751 gives players those phases (no spell_area, SmartAI, script or condition does).
UPDATE `creature_template_addon` SET `auras` = '' WHERE `entry` IN (3639432, 3639433, 3639434, 3639435, 3643547) AND `auras` = '74097 74095';
UPDATE `creature_template_addon` SET `auras` = '73426 74676' WHERE `entry` = 3640169 AND `auras` = '74096 73426 74676';
UPDATE `creature_template_addon` SET `auras` = '83305 75602' WHERE `entry` = 3642389 AND `auras` = '74096 83305 75602';
UPDATE `creature_template_addon` SET `auras` = '' WHERE `entry` IN (4100721, 4101412) AND `auras` = '74096';

-- 2) Gameobjects on maps 750 and 751 imported in phases 16, 64 and 256. No spell_area, SmartAI, script or
--    condition sets those bits on these maps, so they were invisible to everyone. Cinderbloom x8 and the
--    Alliance Breadcrumb on 750, the Runeforge, Alchemy Labs and Orgrimmar/Stormwind portals on 751.
UPDATE `gameobject` SET `phaseMask` = 1 WHERE `guid` IN (15051093, 15051094, 15051095, 15051096, 15051097, 15051098, 15051099, 15051100) AND `id` = 3802747 AND `phaseMask` = 16;
UPDATE `gameobject` SET `phaseMask` = 1 WHERE `guid` = 16329076 AND `id` = 3794990 AND `phaseMask` = 256;
UPDATE `gameobject` SET `phaseMask` = 1 WHERE `guid` IN (12627441, 12627442, 12627443) AND `id` IN (3791540, 3791541, 3790557) AND `phaseMask` = 64;
UPDATE `gameobject` SET `phaseMask` = 1 WHERE `guid` IN (12627439, 12627440) AND `id` IN (3793052, 3793053) AND `phaseMask` = 256;

-- 3) Guild-house spawns left behind by the retired phase-per-guild model (map 1, phase 16). Nothing
--    references them: no addon, formation, linked respawn, pool, event, SmartAI, condition or respawn row.
DELETE FROM `creature` WHERE `guid` IN (9000525, 9000526, 9001435, 9001436) AND `id` IN (800002, 95104);
