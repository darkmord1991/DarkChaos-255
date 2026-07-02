-- =====================================================================
-- Mount Hyjal / Molten Front Downport  --  55  Missing GameObject templates
-- ---------------------------------------------------------------------
-- 3 GOs referenced by SMART_ACTION_SUMMON_GO (3675026/27/28) were never
-- imported: "The Manipulator's Portal Spell Effect" (Fire/Air/Earth).
-- Only Earth (displayId 9010, spells\creature_spellportal_yellow.mdx) is
-- already a stock 3.3.5 display id -- imported here.
-- Fire (203083, displayId 9081) and Air (203085, displayId 9503) are
-- Cata-new display ids NOT staged in Custom/CSV DBC/GameObjectDisplayInfo.csv
-- yet -- needs the retroport_tools pipeline first, not imported here.
-- =====================================================================

DELETE FROM `gameobject_template` WHERE `entry` = 203086;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`, `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`, `AIName`, `ScriptName`)
VALUES (203086, 5, 9010, 'The Manipulator''s Portal Spell Effect (Earth)', '', '', '', 1.2, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, '', '');
