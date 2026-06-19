-- Dark Chaos - Cataclysm+ retail mount downport batch (10 mounts)
-- Extracted from the 12.0.7 retail client via wow.export headless CLI and downported
-- to 3.3.5a. Pairs with CSV DBC rows (CreatureModelData 500720-500729,
-- CreatureDisplayInfo 500730-500739, Spell 300790-300799) and the regenerated
-- DC Collection CDBC. Acquisition: 'Reins of ...' item sold by the Skeletal
-- Stablemaster (NPC 3461020), teaches the mount spell, registered in the
-- DC Collection (dc_mount_definitions + dc_collection_definitions).
--
-- Mounts: Sandstone Drake, Grand Expedition Yak, Sky Golem, Swift Windsteed,
--   Warforged Nightmare, Grinning Reaver, Highmountain Thunderhoof, Wonderwing 2.0,
--   Heavenly Onyx Cloud Serpent, Llothien Prowler.
-- ID bands: creature 3461286-3461295 | item 300460-300469 | spell 300790-300799
--           display 500730-500739 | model 500720-500729 | vendor slots 28-37

-- 1) creature_model_info (server-side bounds; mounts are display-only, generic bounds)
DELETE FROM `creature_model_info` WHERE `DisplayID` BETWEEN 500730 AND 500739;
INSERT INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES
(500730,0.75,2.50,2,0,0),
(500731,0.75,2.50,2,0,0),
(500732,0.75,2.50,2,0,0),
(500733,0.75,2.50,2,0,0),
(500734,0.75,2.50,2,0,0),
(500735,0.75,2.50,2,0,0),
(500736,0.75,2.50,2,0,0),
(500737,0.75,2.50,2,0,0),
(500738,0.75,2.50,2,0,0),
(500739,0.75,2.50,2,0,0);

-- 2) creature_template (mount display creatures referenced by SPELL_AURA_MOUNTED)
DELETE FROM `creature_template` WHERE `entry` BETWEEN 3461286 AND 3461295;
INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`speed_walk`,`speed_run`,
 `unit_class`,`type`,`AIName`,`MovementType`,`RegenHealth`,`VerifiedBuild`)
VALUES
(3461286,'Sandstone Drake','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461287,'Grand Expedition Yak','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461288,'Sky Golem','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461289,'Swift Windsteed','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461290,'Warforged Nightmare','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461291,'Grinning Reaver','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461292,'Highmountain Thunderhoof','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461293,'Wonderwing 2.0','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461294,'Heavenly Onyx Cloud Serpent','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0),
(3461295,'Llothien Prowler','Custom Mount Model',80,80,35,1,1.14286,1,1,'',0,1,0);

-- 3) creature_template_model (link creature -> display; scale baked in DBC CreatureModelScale)
DELETE FROM `creature_template_model` WHERE `CreatureID` BETWEEN 3461286 AND 3461295;
INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461286,0,500730,1,1,0),
(3461287,0,500731,1,1,0),
(3461288,0,500732,1,1,0),
(3461289,0,500733,1,1,0),
(3461290,0,500734,1,1,0),
(3461291,0,500735,1,1,0),
(3461292,0,500736,1,1,0),
(3461293,0,500737,1,1,0),
(3461294,0,500738,1,1,0),
(3461295,0,500739,1,1,0);

-- 4) item_template ('Reins of ...' learn item; spellid_2 trigger 6 = learn mount spell)
DELETE FROM `item_template` WHERE `entry` BETWEEN 300460 AND 300469;
INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,
 `Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`Material`,
 `AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,
 `ContainerSlots`,`spellid_1`,`spelltrigger_1`,`spellcharges_1`,`spellppmRate_1`,
 `spellcooldown_1`,`spellcategory_1`,`spellcategorycooldown_1`,`spellid_2`,`spelltrigger_2`,
 `spellcharges_2`,`spellppmRate_2`,`spellcooldown_2`,`spellcategory_2`,`spellcategorycooldown_2`,
 `bonding`,`description`,`RequiredDisenchantSkill`,`duration`,`ScriptName`,`DisenchantID`,
 `FoodType`,`minMoneyLoot`,`maxMoneyLoot`,`flagsCustom`,`VerifiedBuild`)
VALUES
(300460,15,5,-1,'Reins of the Sandstone Drake',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300790,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300461,15,5,-1,'Reins of the Grand Expedition Yak',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300791,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300462,15,5,-1,'Reins of the Sky Golem',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300792,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300463,15,5,-1,'Reins of the Swift Windsteed',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300793,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300464,15,5,-1,'Reins of the Warforged Nightmare',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300794,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300465,15,5,-1,'Reins of the Grinning Reaver',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300795,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300466,15,5,-1,'Reins of the Highmountain Thunderhoof',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300796,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300467,15,5,-1,'Reins of the Wonderwing 2.0',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300797,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300468,15,5,-1,'Reins of the Heavenly Onyx Cloud Serpent',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300798,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300469,15,5,-1,'Reins of the Llothien Prowler',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300799,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0);

-- 5) npc_vendor (Skeletal Stablemaster 3461020, slots 28-37)
DELETE FROM `npc_vendor` WHERE `entry`=3461020 AND `item` BETWEEN 300460 AND 300469;
DELETE FROM `npc_vendor` WHERE `entry`=3461020 AND `slot` BETWEEN 28 AND 37;
INSERT INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(3461020,28,300460,0,0,0,0),
(3461020,29,300461,0,0,0,0),
(3461020,30,300462,0,0,0,0),
(3461020,31,300463,0,0,0,0),
(3461020,32,300464,0,0,0,0),
(3461020,33,300465,0,0,0,0),
(3461020,34,300466,0,0,0,0),
(3461020,35,300467,0,0,0,0),
(3461020,36,300468,0,0,0,0),
(3461020,37,300469,0,0,0,0);

-- 6) conditions cleanup (remove any stale vendor-item condition on these items)
DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId`=23 AND `SourceGroup`=3461020
    AND `SourceEntry` BETWEEN 300460 AND 300469 AND `ConditionTypeOrReference`=25;

-- 7) dc_mount_definitions (DC Collection catalog; fly=type3/speed310, ground=type0/speed100)
DELETE FROM `dc_mount_definitions` WHERE `spell_id` BETWEEN 300790 AND 300799;
INSERT INTO `dc_mount_definitions`
(`spell_id`,`name`,`mount_type`,`source`,`faction`,`rarity`,`speed`,`display_id`)
VALUES
(300790,'Sandstone Drake',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500730),
(300791,'Grand Expedition Yak',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500731),
(300792,'Sky Golem',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500732),
(300793,'Swift Windsteed',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500733),
(300794,'Warforged Nightmare',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500734),
(300795,'Grinning Reaver',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500735),
(300796,'Highmountain Thunderhoof',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500736),
(300797,'Wonderwing 2.0',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500737),
(300798,'Heavenly Onyx Cloud Serpent',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,310,500738),
(300799,'Llothien Prowler',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500739)
ON DUPLICATE KEY UPDATE
`name`=VALUES(`name`),`mount_type`=VALUES(`mount_type`),`source`=VALUES(`source`),
`faction`=VALUES(`faction`),`rarity`=VALUES(`rarity`),`speed`=VALUES(`speed`),
`display_id`=VALUES(`display_id`);

-- 8) dc_collection_definitions (enable in DC Collection; collection_type 1 = MOUNT)
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=1 AND `entry_id` BETWEEN 300790 AND 300799;
INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,300790,1),
(1,300791,1),
(1,300792,1),
(1,300793,1),
(1,300794,1),
(1,300795,1),
(1,300796,1),
(1,300797,1),
(1,300798,1),
(1,300799,1);
