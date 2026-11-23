-- DarkChaos: two bankers on the Mount Hyjal continent (map 750) were spawned without a zone.
-- The playerbots travel cache files a spawn on the DC continents under `creature`.`zoneId` and falls back to the
-- terrain when it is 0. Bots above level 80 visit a banker only when it stands in a zone of their own level, so the
-- zone has to be right. Both get the zone every neighbouring spawn carries.

-- Vanguard Banker (Horde), Azshara 80-90
UPDATE `creature` SET `zoneId` = 4930, `areaId` = 4930 WHERE `guid` = 16469123 AND `id` = 830148 AND `zoneId` = 0;

-- Encampment Banker (Alliance), Darkshore 80-90
UPDATE `creature` SET `zoneId` = 4929, `areaId` = 4929 WHERE `guid` = 16469127 AND `id` = 830135 AND `zoneId` = 0;
