-- Blackwing Descent (map 669) — gameobject_template downport
-- Source: cata_world.gameobject_template (18 GOs spawned on map 669).
-- Cata has extra Data24..Data31 + RequiredLevel which this fork lacks; Data0..23 map directly.
-- ScriptNames (go_nefarians_end_orb_of_culmination, go_bwd_ancient_bell) come from the CataTC
-- boss/misc files being ported. Doors 205830/208291 + elevators 203716/207834 are wired via the
-- instance DoorData / GetGameObject links. nelt's custom portcullis 402368 is intentionally NOT imported.
--
-- NOTE: several displayIds are absent from the stock 3.3.5 GameObjectDisplayInfo (9683/9946/10138/
-- 10139/10363/10407/10463) — they are added in the DBC/CSV step; without them the door/elevator/gong
-- renders invisible.

DELETE FROM `gameobject_template` WHERE `entry` IN (180403,203254,203295,203306,203625,203716,204276,204928,204929,205830,206704,206705,207339,207340,207341,207342,207834,208291);

INSERT INTO `gameobject_template`
    (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`,
     `Data0`, `Data1`, `Data2`, `Data3`, `Data4`, `Data5`, `Data6`, `Data7`, `Data8`, `Data9`, `Data10`, `Data11`,
     `Data12`, `Data13`, `Data14`, `Data15`, `Data16`, `Data17`, `Data18`, `Data19`, `Data20`, `Data21`, `Data22`, `Data23`,
     `AIName`, `ScriptName`, `VerifiedBuild`)
SELECT
    gt.`entry`, gt.`type`, gt.`displayId`, gt.`name`, gt.`IconName`, gt.`castBarCaption`, gt.`unk1`, gt.`size`,
    gt.`Data0`, gt.`Data1`, gt.`Data2`, gt.`Data3`, gt.`Data4`, gt.`Data5`, gt.`Data6`, gt.`Data7`, gt.`Data8`, gt.`Data9`, gt.`Data10`, gt.`Data11`,
    gt.`Data12`, gt.`Data13`, gt.`Data14`, gt.`Data15`, gt.`Data16`, gt.`Data17`, gt.`Data18`, gt.`Data19`, gt.`Data20`, gt.`Data21`, gt.`Data22`, gt.`Data23`,
    gt.`AIName`, gt.`ScriptName`, 0
FROM `cata_world`.`gameobject_template` gt
WHERE gt.`entry` IN (180403,203254,203295,203306,203625,203716,204276,204928,204929,205830,206704,206705,207339,207340,207341,207342,207834,208291);
