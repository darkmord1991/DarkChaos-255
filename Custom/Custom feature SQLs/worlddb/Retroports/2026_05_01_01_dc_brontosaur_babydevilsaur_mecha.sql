-- Brontosaurus, Babydevilsaur, Mechadevilsaur, and Mechadevilsaur mount
--
-- Client DBC requirements:
--   CreatureModelData.csv: 500220-500223
--   CreatureDisplayInfo.csv: 500224-500232
--   Spell.csv: 300739

DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461217,3461218,3461219,3461220,3461221,3461222,3461223,3461224,3461225,3461228);

DELETE FROM `creature_template`
WHERE `entry` IN (3461217,3461218,3461219,3461220,3461221,3461222,3461223,3461224,3461225,3461228);

DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500224,500225,500226,500227,500228,500229,500230,500231,500232);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500224,1.60,3.20,2,0,0),
(500225,1.60,3.20,2,0,0),
(500226,1.60,3.20,2,0,0),
(500227,1.60,3.20,2,0,0),
(500228,1.60,3.20,2,0,0),
(500229,1.60,3.20,2,0,0),
(500230,0.50,1.00,2,0,0),
(500231,0.90,1.80,2,0,0),
(500232,1.15,2.30,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461217,'Brontosaurus Black','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461218,'Brontosaurus Blue','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461219,'Brontosaurus Brown','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461220,'Brontosaurus Green','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461221,'Brontosaurus White','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461222,'Brontosaurus','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461223,'Baby Devilsaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461224,'Mecha Devilsaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461225,'Mechadevilsaur Mount (NPC)','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461228,'Mechadevilsaur Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461217,0,500224,1.00,1,0),
(3461218,0,500225,1.00,1,0),
(3461219,0,500226,1.00,1,0),
(3461220,0,500227,1.00,1,0),
(3461221,0,500228,1.00,1,0),
(3461222,0,500229,1.00,1,0),
(3461223,0,500230,1.00,1,0),
(3461224,0,500231,1.00,1,0),
(3461225,0,500232,1.00,1,0),
(3461228,0,500232,1.00,1,0);

DELETE FROM `item_template`
WHERE `entry` IN (300409);

INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,
 `Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,
 `Material`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,
 `stackable`,`ContainerSlots`,`spellid_1`,`spelltrigger_1`,`spellcharges_1`,
 `spellppmRate_1`,`spellcooldown_1`,`spellcategory_1`,`spellcategorycooldown_1`,
 `spellid_2`,`spelltrigger_2`,`spellcharges_2`,`spellppmRate_2`,
 `spellcooldown_2`,`spellcategory_2`,`spellcategorycooldown_2`,
 `bonding`,`description`,`RequiredDisenchantSkill`,
 `duration`,`ScriptName`,`DisenchantID`,`FoodType`,`minMoneyLoot`,
 `maxMoneyLoot`,`flagsCustom`,`VerifiedBuild`)
VALUES
(300409,15,5,-1,'Reins of the Mechadevilsaur',68747,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300739,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0);

DELETE FROM `npc_vendor`
WHERE `entry` = 3461020
  AND `item` IN (300409);

DELETE FROM `npc_vendor`
WHERE `entry` = 3461020
  AND `slot` IN (27);

INSERT INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(3461020,27,300409,0,0,0,0);

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 23
  AND `SourceGroup` = 3461020
  AND `SourceEntry` IN (300409)
  AND `ConditionTypeOrReference` = 25;

INSERT INTO `dc_mount_definitions`
(`spell_id`,`name`,`mount_type`,`source`,`faction`,`rarity`,`speed`,`display_id`)
VALUES
(300739,'Mechadevilsaur Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500232)
ON DUPLICATE KEY UPDATE
`name` = VALUES(`name`),
`mount_type` = VALUES(`mount_type`),
`source` = VALUES(`source`),
`faction` = VALUES(`faction`),
`rarity` = VALUES(`rarity`),
`speed` = VALUES(`speed`),
`display_id` = VALUES(`display_id`);

DELETE FROM `dc_collection_definitions`
WHERE `collection_type` = 1
  AND `entry_id` IN (300739);

INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,300739,1);