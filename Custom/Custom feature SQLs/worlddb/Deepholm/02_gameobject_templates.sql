-- =====================================================================
-- Deepholm Downport  --  02  GameObject definition layer  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Imports the 99 Deepholm-new GO templates (101 spawned on map 646 minus
-- 2 shared/stock entries already present server-wide: 191707, 204968).
--
-- Mapping notes:
--   * Data0-23 copied 1:1; Data24-31 dropped (verified: no Deepholm GO uses them).
--   * RequiredLevel dropped (no column in this fork; 6 GOs lose a level gate -- minor).
--   * GO types present: 0,1,2,3,5,6,8,10,19,22,23,25,31 -- all valid 3.3.5 types.
--   * No Deepholm GO carries a C++ ScriptName -- copied verbatim.
--   * gameobject_template_addon: artkit4 dropped (no column in this fork).
--   * Display ids kept retail; ~44 are Cata-new and need a GameObjectDisplayInfo
--     bake (see 05_assets_manifest.md) before they render.
-- =====================================================================

-- ---------------------------------------------------------------------
-- gameobject_template
-- ---------------------------------------------------------------------
DELETE FROM `gameobject_template`
WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646)
  AND `entry` NOT IN (191707, 204968);

INSERT INTO `gameobject_template`
(`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
 `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`,
 `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`,
 `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT
 gt.`entry`, gt.`type`, gt.`displayId`, gt.`name`, gt.`IconName`, gt.`castBarCaption`, gt.`unk1`, gt.`size`,
 gt.`Data0`, gt.`Data1`, gt.`Data2`, gt.`Data3`, gt.`Data4`, gt.`Data5`, gt.`Data6`, gt.`Data7`, gt.`Data8`, gt.`Data9`,
 gt.`Data10`, gt.`Data11`, gt.`Data12`, gt.`Data13`, gt.`Data14`, gt.`Data15`, gt.`Data16`, gt.`Data17`, gt.`Data18`, gt.`Data19`,
 gt.`Data20`, gt.`Data21`, gt.`Data22`, gt.`Data23`, gt.`AIName`, gt.`ScriptName`, gt.`VerifiedBuild`
FROM `cata_world`.`gameobject_template` gt
WHERE gt.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646)
  AND gt.`entry` NOT IN (191707, 204968);

-- ---------------------------------------------------------------------
-- gameobject_template_addon   (drop artkit4)
-- ---------------------------------------------------------------------
DELETE FROM `gameobject_template_addon`
WHERE `entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646)
  AND `entry` NOT IN (191707, 204968);

INSERT INTO `gameobject_template_addon`
(`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT a.`entry`, a.`faction`, a.`flags`, a.`mingold`, a.`maxgold`, a.`artkit0`, a.`artkit1`, a.`artkit2`, a.`artkit3`
FROM `cata_world`.`gameobject_template_addon` a
WHERE a.`entry` IN (SELECT DISTINCT `id` FROM `cata_world`.`gameobject` WHERE `map` = 646)
  AND a.`entry` NOT IN (191707, 204968);
