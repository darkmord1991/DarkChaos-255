-- DarkChaos custom mount vendor and item registration
-- This migration adds:
--   - 14 custom mount items (300382-300395)
--   - vendor NPC template/spawn (3461020)
--   - vendor inventory entries for those mounts

DELETE FROM `item_template` WHERE `entry` BETWEEN 300382 AND 300395;

INSERT INTO `item_template`
(`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,
 `Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,
 `Material`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,
 `stackable`,`ContainerSlots`,`spellid_1`,`spelltrigger_1`,`spellcharges_1`,
 `spellppmRate_1`,`spellcooldown_1`,`spellcategory_1`,
 `spellcategorycooldown_1`,`bonding`,`description`,`RequiredDisenchantSkill`,
 `duration`,`ScriptName`,`DisenchantID`,`FoodType`,`minMoneyLoot`,
 `maxMoneyLoot`,`flagsCustom`,`VerifiedBuild`)
VALUES
(300389,15,5,-1,'Reins of the Dreamowl Firemount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300700,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Dreamowl Firemount.',-1,0,'',0,0,0,0,0,0),
(300390,15,5,-1,'Reins of the Felblaze Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300701,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Felblaze Infernal.',-1,0,'',0,0,0,0,0,0),
(300391,15,5,-1,'Reins of the Netherwing Mount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300702,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Netherwing Mount.',-1,0,'',0,0,0,0,0,0),
(300392,15,5,-1,'Reins of the Coldflame Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300703,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Coldflame Infernal.',-1,0,'',0,0,0,0,0,0),
(300393,15,5,-1,'Reins of the Flarecore Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300704,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Flarecore Infernal.',-1,0,'',0,0,0,0,0,0),
(300394,15,5,-1,'Reins of the Frostshard Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300705,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Frostshard Infernal.',-1,0,'',0,0,0,0,0,0),
(300395,15,5,-1,'Reins of the Hellfire Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300706,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Hellfire Infernal.',-1,0,'',0,0,0,0,0,0),
(300382,15,5,-1,'Reins of the Black Skeletal Warhorse II',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300707,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Black Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0),
(300383,15,5,-1,'Reins of the Brown Skeletal Warhorse II',68744,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300720,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Brown Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0),
(300384,15,5,-1,'Reins of the Green Skeletal Warhorse II',68745,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300721,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Green Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0),
(300385,15,5,-1,'Reins of the Midnight Skeletal Warhorse II',68746,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300722,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Midnight Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0),
(300386,15,5,-1,'Reins of the Purple Skeletal Warhorse II',68747,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300723,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Purple Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0),
(300387,15,5,-1,'Reins of the Red Skeletal Warhorse II',68748,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300724,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable Red Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0),
(300388,15,5,-1,'Reins of the White Skeletal Warhorse II',68749,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,300725,0,-1,0,-1,0,-1,0,'Summons and dismisses a rideable White Skeletal Warhorse II.',-1,0,'',0,0,0,0,0,0);

-- DELETE FROM `creature` WHERE `id1` = 3461020;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 3461020;
DELETE FROM `creature_template` WHERE `entry` = 3461020;

INSERT INTO `creature_template`
(`entry`,`name`,`subname`,`minlevel`,`maxlevel`,`faction`,`npcflag`,`speed_walk`,
 `speed_run`,`unit_class`,`type`,`AIName`,`MovementType`,
 `RegenHealth`,`VerifiedBuild`)
VALUES
(3461020,'Skeletal Stablemaster','DarkChaos Mount Vendor',80,80,35,128,1,
 1.14286,1,7,'',0,1,0);

INSERT INTO `creature_template_model`
(`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
VALUES
(3461020,0,1907,1,1,0);

DELETE FROM `npc_vendor` WHERE `entry` = 3461020;

INSERT INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(3461020,0,300389,0,0,0,0),
(3461020,1,300390,0,0,0,0),
(3461020,2,300391,0,0,0,0),
(3461020,3,300392,0,0,0,0),
(3461020,4,300393,0,0,0,0),
(3461020,5,300394,0,0,0,0),
(3461020,6,300395,0,0,0,0),
(3461020,7,300382,0,0,0,0),
(3461020,8,300383,0,0,0,0),
(3461020,9,300384,0,0,0,0),
(3461020,10,300385,0,0,0,0),
(3461020,11,300386,0,0,0,0),
(3461020,12,300387,0,0,0,0),
(3461020,13,300388,0,0,0,0);

-- -----------------------------------------------------------------------------
-- DC-Collection mount definitions (required for Mount Journal definitions list)
-- -----------------------------------------------------------------------------

DELETE FROM `dc_mount_definitions`
WHERE `spell_id` IN (300700,300701,300702,300703,300704,300705,300706,300707,300720,300721,300722,300723,300724,300725);

INSERT INTO `dc_mount_definitions`
(`spell_id`,`name`,`mount_type`,`source`,`faction`,`rarity`,`speed`,`display_id`)
VALUES
(300700,'Dreamowl Firemount',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500001),
(300701,'Felblaze Infernal',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500004),
(300702,'Netherwing Mount',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500005),
(300703,'Coldflame Infernal',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500009),
(300704,'Flarecore Infernal',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500010),
(300705,'Frostshard Infernal',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500011),
(300706,'Hellfire Infernal',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500012),
(300707,'Black Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500007),
(300720,'Brown Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500013),
(300721,'Green Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500014),
(300722,'Midnight Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500015),
(300723,'Purple Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500016),
(300724,'Red Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500017),
(300725,'White Skeletal Warhorse II',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500018)
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
	AND `entry_id` IN (300700,300701,300702,300703,300704,300705,300706,300707,300720,300721,300722,300723,300724,300725);

INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,300700,1),
(1,300701,1),
(1,300702,1),
(1,300703,1),
(1,300704,1),
(1,300705,1),
(1,300706,1),
(1,300707,1),
(1,300720,1),
(1,300721,1),
(1,300722,1),
(1,300723,1),
(1,300724,1),
(1,300725,1);
