-- ---------------------------------------------------------------------------
-- 179  Hyjal round-44 -- restore Felwood's gathering layer
-- ---------------------------------------------------------------------------
-- The round-44 coverage pass measured Felwood at 28% gameobject coverage, and
-- 77% of that gap is the gathering layer: 827 of the 1,068 missing spawns are
-- herb nodes and ore veins.  Map-wide counts before this file:
--     Golden Sansam 0, Gromsblood 0, Crying Violet 0, Emerald Shimmercap 0,
--     Dreamfoil 1, Purple Lotus 5
-- ...against 174 each of Mithril/Gold/Truesilver that Cata places in Felwood
-- alone.  The zone is unfarmable in practice.
--
-- SCOPE: cata_world zone 361 gameobjects whose template type is 3 (chest --
-- herb nodes and veins are chests).  ALL of Cata's Felwood falls inside map
-- 750's ORIGINAL 108-tile footprint (cols 32-36 x rows 18-25), so the zone id
-- alone is an exact scope here and no terrain mask is needed.  That also means
-- this file is independent of the 279-tile expansion and can be applied on its
-- own.
--
-- NOT POOLED, deliberately: cata_world has no pool_gameobject table, and 2,705
-- of map 750's existing 3,026 type-3 nodes are already unpooled, so raw spawns
-- match both the source and this map's established practice.  If node density
-- turns out too high in play, pooling is a follow-up -- it is NOT a silent
-- change to make here.
--
-- Offset @OFF = 3,600,000 (the port series' band).  Map 750 already carries
-- gathering nodes in BOTH the +3.6M and +3.9M bands from earlier passes; the
-- delete below is keyed to exactly the ids this file inserts, so re-running is
-- idempotent and cannot touch the +3.9M ones.
-- ---------------------------------------------------------------------------

SET @OFF := 3600000;

-- idempotency: remove only the spawns THIS file creates (auto-guid would dupe)
DELETE FROM acore_world.gameobject
WHERE `map` = 750 AND `id` IN (
  SELECT DISTINCT g.`id` + @OFF FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=361 AND g.id IN (SELECT `entry` FROM cata_world.gameobject_template WHERE `type`=3)));


-- --- gameobject templates (INSERT IGNORE -- reuses any already cloned)  (adapted from 02_gameobject_templates.sql) ---
INSERT IGNORE INTO acore_world.gameobject_template (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild` FROM cata_world.gameobject_template WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=361 AND g.id IN (SELECT `entry` FROM cata_world.gameobject_template WHERE `type`=3))) AND entry NOT IN (SELECT entry FROM acore_world.gameobject_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.gameobject_template (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT `entry`+@OFF, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild` FROM acore_world.gameobject_template WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=361 AND g.id IN (SELECT `entry` FROM cata_world.gameobject_template WHERE `type`=3))) AND entry < @OFF;
INSERT IGNORE INTO acore_world.gameobject_template_addon (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry`+@OFF, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3` FROM cata_world.gameobject_template_addon WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=361 AND g.id IN (SELECT `entry` FROM cata_world.gameobject_template WHERE `type`=3))) AND entry NOT IN (SELECT entry FROM acore_world.gameobject_template WHERE entry < @OFF);
INSERT IGNORE INTO acore_world.gameobject_template_addon (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry`+@OFF, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3` FROM acore_world.gameobject_template_addon WHERE entry IN (SELECT DISTINCT g.id FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=361 AND g.id IN (SELECT `entry` FROM cata_world.gameobject_template WHERE `type`=3))) AND entry IN (SELECT entry FROM acore_world.gameobject_template WHERE entry < @OFF) AND entry < @OFF;


-- --- loot templates for the nodes  (adapted from 08_loot.sql) ---
;


-- --- the node spawns themselves  (adapted from 04_spawns.sql) ---
INSERT INTO acore_world.gameobject (`id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `position_x`, `position_y`, `position_z`, `orientation`, `rotation0`, `rotation1`, `rotation2`, `rotation3`, `spawntimesecs`, `animprogress`, `state`)
SELECT g.`id`+@OFF, 750, 4927, 4927, g.`spawnMask`, g.`phaseMask`, g.`position_x`, g.`position_y`, g.`position_z`, g.`orientation`, g.`rotation0`, g.`rotation1`, g.`rotation2`, g.`rotation3`, g.`spawntimesecs`, g.`animprogress`, g.`state`
FROM cata_world.gameobject g WHERE (g.map=1 AND g.zoneId=361 AND g.id IN (SELECT `entry` FROM cata_world.gameobject_template WHERE `type`=3));


-- --- loot for the two CATA-ONLY nodes ---------------------------------------
-- The seven vanilla nodes (Gold Vein, Mithril, Truesilver, Purple Lotus,
-- Gromsblood, Golden Sansam, Dreamfoil) already have gameobject_loot_template
-- rows in acore_world -- verified 4/6/4/2/1/1/1 rows against their lootIds, so
-- they are lootable the moment they spawn and need nothing here.
--
-- Crying Violet (lootId 35620) and Emerald Shimmercap (lootId 35716) are Cata
-- additions and had ZERO loot rows on our side -- they would have spawned as
-- empty props.  Their drops, items 63032 and 63078, DO already exist in our
-- item_template with real displayids (13489 / 19566), so the herbs are usable.
--
-- Written out literally rather than cross-DB SELECTed: cata_world's
-- gameobject_loot_template has an extra `IsCurrency` column (11 cols vs our 10),
-- so a column-less INSERT...SELECT fails on column count.
DELETE FROM `gameobject_loot_template` WHERE `Entry` IN (35620, 35716);
INSERT INTO `gameobject_loot_template`
  (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`) VALUES
  (35620, 63032, 0, 100, 1, 1, 0, 1, 1, 'Crying Violet (Cata herb, Felwood)'),
  (35716, 63078, 0, 100, 1, 1, 0, 1, 1, 'Emerald Shimmercap (Cata herb, Felwood)');

-- Verify -- expect +827 gathering-node spawns in Felwood:
--   SELECT t.name, COUNT(*) FROM `gameobject` g
--     JOIN `gameobject_template` t ON t.entry = g.id
--    WHERE g.map = 750 AND g.zoneId = 4927 AND t.type = 3
--    GROUP BY t.name ORDER BY 2 DESC;
