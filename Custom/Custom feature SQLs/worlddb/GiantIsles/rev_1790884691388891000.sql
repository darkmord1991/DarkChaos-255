-- Giant Isles (map 1405): War Quartermaster spawn 9000301 sat 2.6 yd under the terrain
-- (z 12.4, ground 15.03 - unchanged by the MoP terrain swap; found by the spawn audit)
UPDATE `creature` SET `position_z` = 15.03 WHERE `guid` = 9000301 AND `id` = 400365 AND `map` = 1405;
