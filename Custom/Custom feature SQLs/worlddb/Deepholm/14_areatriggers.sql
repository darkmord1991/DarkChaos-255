-- =====================================================================
-- Deepholm Downport  --  14  AreaTriggers  (Cata map 646)
-- ---------------------------------------------------------------------
-- Source: cata_world (TrinityCore 4.3.4).  Target: acore_world.
-- REQUIRES cata_world present on the same server at import time (read-only).
-- Run AFTER 11 (quests) -- areatrigger_involvedrelation references quests.
--
-- Deepholm referenced AreaTrigger ids: 6194 (teleport INTO Deepholm), 6126 +
-- 6221 (quest "reach location" objectives). Small.
--
-- *** HARD DEPENDENCY ***: these rows reference AreaTrigger.dbc entries that do
-- NOT exist in stock 3.3.5 (ids 6194/6126/6221 are Cata-new). They will not fire
-- until those AreaTrigger.dbc rows (ContinentID 646 + coords) are added to the
-- client AND server DBC -- that is the extraction/DBC track (acore_dbc.areatrigger
-- has ContinentID; author the rows there + client patch). The feasibility report
-- recommends a portal-GO + SmartAI teleport for ENTRY instead of relying on the
-- AreaTrigger.dbc 6194 row.
--
-- Mapping: areatrigger_teleport drops Cata `VerifiedBuild`. areatrigger_scripts
-- ScriptNames are C++ (ported in the script phase) -- harmless load warnings until then.
-- =====================================================================

-- ---------------------------------------------------------------------
-- areatrigger_teleport   (the teleport INTO Deepholm)
-- ---------------------------------------------------------------------
DELETE FROM `areatrigger_teleport` WHERE `ID` IN (6194);

INSERT INTO `areatrigger_teleport`
(`ID`,`Name`,`target_map`,`target_position_x`,`target_position_y`,`target_position_z`,`target_orientation`)
SELECT `ID`,`Name`,`target_map`,`target_position_x`,`target_position_y`,`target_position_z`,`target_orientation`
FROM `cata_world`.`areatrigger_teleport`
WHERE `target_map` = 646;

-- ---------------------------------------------------------------------
-- areatrigger_involvedrelation   (quest "reach areatrigger" objectives)
-- ---------------------------------------------------------------------
DELETE FROM `areatrigger_involvedrelation`
WHERE `quest` IN (SELECT `quest` FROM `cata_world`.`creature_questender` qe JOIN `cata_world`.`creature` c ON c.`id` = qe.`id` WHERE c.`map` = 646
                  UNION SELECT `quest` FROM `cata_world`.`creature_queststarter` qs JOIN `cata_world`.`creature` c2 ON c2.`id` = qs.`id` WHERE c2.`map` = 646
                  UNION SELECT `quest` FROM `cata_world`.`gameobject_questender` ge JOIN `cata_world`.`gameobject` g ON g.`id` = ge.`id` WHERE g.`map` = 646
                  UNION SELECT `quest` FROM `cata_world`.`gameobject_queststarter` gs JOIN `cata_world`.`gameobject` g2 ON g2.`id` = gs.`id` WHERE g2.`map` = 646);

INSERT INTO `areatrigger_involvedrelation` (`id`,`quest`)
SELECT ar.`id`, ar.`quest`
FROM `cata_world`.`areatrigger_involvedrelation` ar
WHERE ar.`quest` IN (SELECT `quest` FROM `cata_world`.`creature_questender` qe JOIN `cata_world`.`creature` c ON c.`id` = qe.`id` WHERE c.`map` = 646
                     UNION SELECT `quest` FROM `cata_world`.`creature_queststarter` qs JOIN `cata_world`.`creature` c2 ON c2.`id` = qs.`id` WHERE c2.`map` = 646
                     UNION SELECT `quest` FROM `cata_world`.`gameobject_questender` ge JOIN `cata_world`.`gameobject` g ON g.`id` = ge.`id` WHERE g.`map` = 646
                     UNION SELECT `quest` FROM `cata_world`.`gameobject_queststarter` gs JOIN `cata_world`.`gameobject` g2 ON g2.`id` = gs.`id` WHERE g2.`map` = 646);

-- ---------------------------------------------------------------------
-- areatrigger_scripts   (for the referenced AreaTrigger ids)
-- ---------------------------------------------------------------------
DELETE FROM `areatrigger_scripts` WHERE `entry` IN (6194, 6126, 6221);

INSERT INTO `areatrigger_scripts` (`entry`,`ScriptName`)
SELECT `entry`,`ScriptName` FROM `cata_world`.`areatrigger_scripts` WHERE `entry` IN (6194, 6126, 6221);
