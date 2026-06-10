-- Zandalari Battlesaur (retroport) + example creature + Oondasta display swap
--
-- Source model: Custom/creature/zandalaridevilsaur/zandalaribattlesaur.m2
--   Pack the folder Custom/creature/zandalaridevilsaur/ into a client patch MPQ
--   at path  Creature\zandalaridevilsaur\  (m2 + .skin + all .blp).
--
-- Client DBC requirements (regenerate .dbc from the CSV sources, then deploy to
-- BOTH the client patch and the worldserver data/dbc/ directory):
--   CreatureModelData.csv:    500233  (ModelName Creature\zandalaridevilsaur\zandalaribattlesaur.m2)
--   CreatureDisplayInfo.csv:  500234  (ModelID 500233; var1 zandalaridevilsaur_brown, var2 zandalaribattlesaurarmor_brass)
--
-- Texture variations confirmed from the M2 header: tex[0]=MONSTER_1 (body),
-- tex[2]=MONSTER_2 (armor). All other textures are hardcoded/embedded.

-- Server-side model bounds for the new display (matches King Mosh / display 5305
-- so Oondasta's hitbox is unchanged after the swap).
DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500234);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500234,3.00,6.00,2,0,0);

-- Example creature that uses the new display at scale 1.0 (for previewing the model).
DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461230);

DELETE FROM `creature_template`
WHERE `entry` IN (3461230);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461230,'Zandalari Battlesaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461230,0,500234,1.00,1,0);

-- Point Oondasta (entry 400100) at the new Zandalari Battlesaur display.
-- (Canonical row also updated in worlddb/GiantIsles/giant_isles_creatures.sql.)
DELETE FROM `creature_template_model`
WHERE `CreatureID` = 400100;

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(400100,0,500234,12.00,1,12340);
