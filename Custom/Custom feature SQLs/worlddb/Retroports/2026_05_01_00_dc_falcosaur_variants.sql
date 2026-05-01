-- Falcosaur custom creature + mount integration
-- Client model paths:
--   creature\falcosauros\falcosauros.m2
--   creature\falcosauros\falcosaurospet.m2
--   creature\falcosauros\falcosaurosmount.m2
--
-- Client DBC requirements:
--   CreatureModelData.csv: 500205-500207
--   CreatureDisplayInfo.csv: 500208-500219
--   Spell.csv: 300735-300738

-- -----------------------------------------------------------------------------
-- ID map
-- -----------------------------------------------------------------------------
-- ModelData IDs: 500205-500207
-- Display IDs:   500208-500219
-- Creature IDs:  3461205-3461216
-- Mount item IDs: 300405-300408
-- Mount spell IDs: 300735-300738

DELETE FROM `creature_template_model`
WHERE `CreatureID` IN (3461205,3461206,3461207,3461208,3461209,3461210,3461211,3461212,3461213,3461214,3461215,3461216);

DELETE FROM `creature_template`
WHERE `entry` IN (3461205,3461206,3461207,3461208,3461209,3461210,3461211,3461212,3461213,3461214,3461215,3461216);

DELETE FROM `creature_model_info`
WHERE `DisplayID` IN (500208,500209,500210,500211,500212,500213,500214,500215,500216,500217,500218,500219);

INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500208,0.90,1.80,2,0,0),
(500209,0.90,1.80,2,0,0),
(500210,0.90,1.80,2,0,0),
(500211,0.90,1.80,2,0,0),
(500212,0.55,1.10,2,0,0),
(500213,0.55,1.10,2,0,0),
(500214,0.55,1.10,2,0,0),
(500215,0.55,1.10,2,0,0),
(500216,1.15,2.30,2,0,0),
(500217,1.15,2.30,2,0,0),
(500218,1.15,2.30,2,0,0),
(500219,1.15,2.30,2,0,0);

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461205,'Black Falcosaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461206,'Green Falcosaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461207,'Red Falcosaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461208,'White Falcosaur','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461209,'Black Falcosaur Companion','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461210,'Green Falcosaur Companion','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461211,'Red Falcosaur Companion','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461212,'White Falcosaur Companion','Custom Creature Model',83,83,35,1,1.14286,1,1,'',0,1,0),
(3461213,'Black Falcosaur Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461214,'Green Falcosaur Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461215,'Red Falcosaur Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461216,'White Falcosaur Mount','Custom Creature Model',80,80,35,1,1.14286,1,1,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461205,0,500208,1.00,1,0),
(3461206,0,500209,1.00,1,0),
(3461207,0,500210,1.00,1,0),
(3461208,0,500211,1.00,1,0),
(3461209,0,500212,0.75,1,0),
(3461210,0,500213,0.75,1,0),
(3461211,0,500214,0.75,1,0),
(3461212,0,500215,0.75,1,0),
(3461213,0,500216,1.00,1,0),
(3461214,0,500217,1.00,1,0),
(3461215,0,500218,1.00,1,0),
(3461216,0,500219,1.00,1,0);

DELETE FROM `item_template`
WHERE `entry` IN (300405,300406,300407,300408);

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
(300405,15,5,-1,'Reins of the Black Falcosaur',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300735,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300406,15,5,-1,'Reins of the Green Falcosaur',68744,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300736,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300407,15,5,-1,'Reins of the Red Falcosaur',68745,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300737,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300408,15,5,-1,'Reins of the White Falcosaur',68746,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300738,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0);

DELETE FROM `npc_vendor`
WHERE `entry` = 3461020
  AND `item` IN (300405,300406,300407,300408);

DELETE FROM `npc_vendor`
WHERE `entry` = 3461020
  AND `slot` IN (23,24,25,26);

INSERT INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(3461020,23,300405,0,0,0,0),
(3461020,24,300406,0,0,0,0),
(3461020,25,300407,0,0,0,0),
(3461020,26,300408,0,0,0,0);

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 23
  AND `SourceGroup` = 3461020
  AND `SourceEntry` IN (300405,300406,300407,300408)
  AND `ConditionTypeOrReference` = 25;

INSERT INTO `dc_mount_definitions`
(`spell_id`,`name`,`mount_type`,`source`,`faction`,`rarity`,`speed`,`display_id`)
VALUES
(300735,'Black Falcosaur Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500216),
(300736,'Green Falcosaur Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500217),
(300737,'Red Falcosaur Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500218),
(300738,'White Falcosaur Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500219)
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
  AND `entry_id` IN (300735,300736,300737,300738);

INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,300735,1),
(1,300736,1),
(1,300737,1),
(1,300738,1);