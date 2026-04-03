-- DarkChaos custom mount vendor and item registration
-- This migration adds:
--   - 14 custom mount items (300382-300395)
--   - vendor NPC template/spawn (3461020)
--   - vendor inventory entries for those mounts

-- Mount spell definitions are sourced from Custom/CSV DBC/Spell.csv.

DELETE FROM `item_template` WHERE `entry` BETWEEN 300382 AND 300395;

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
(300389,15,5,-1,'Reins of the Dreamowl Firemount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300700,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300390,15,5,-1,'Reins of the Felblaze Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300701,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300391,15,5,-1,'Reins of the Netherwing Mount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300702,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300392,15,5,-1,'Reins of the Coldflame Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300703,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300393,15,5,-1,'Reins of the Flarecore Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300704,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300394,15,5,-1,'Reins of the Frostshard Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300705,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300395,15,5,-1,'Reins of the Hellfire Infernal',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300706,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300382,15,5,-1,'Reins of the Black Skeletal Warhorse II',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300707,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300383,15,5,-1,'Reins of the Brown Skeletal Warhorse II',68744,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300720,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300384,15,5,-1,'Reins of the Green Skeletal Warhorse II',68745,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300721,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300385,15,5,-1,'Reins of the Midnight Skeletal Warhorse II',68746,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300722,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300386,15,5,-1,'Reins of the Purple Skeletal Warhorse II',68747,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300723,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300387,15,5,-1,'Reins of the Red Skeletal Warhorse II',68748,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300724,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300388,15,5,-1,'Reins of the White Skeletal Warhorse II',68749,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300725,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0);

-- Backfill/update existing rows to Blizzard-style mount reins behavior:
-- slot 1 = generic on-use helper spell, slot 2 = learned mount spell.
UPDATE `item_template`
SET
	`spellid_1` = 55884,
	`spelltrigger_1` = 0,
	`spellcharges_1` = -1,
	`spellppmRate_1` = 0,
	`spellcooldown_1` = -1,
	`spellcategory_1` = 330,
	`spellcategorycooldown_1` = 3000,
	`spellid_2` = CASE `entry`
		WHEN 300389 THEN 300700
		WHEN 300390 THEN 300701
		WHEN 300391 THEN 300702
		WHEN 300392 THEN 300703
		WHEN 300393 THEN 300704
		WHEN 300394 THEN 300705
		WHEN 300395 THEN 300706
		WHEN 300382 THEN 300707
		WHEN 300383 THEN 300720
		WHEN 300384 THEN 300721
		WHEN 300385 THEN 300722
		WHEN 300386 THEN 300723
		WHEN 300387 THEN 300724
		WHEN 300388 THEN 300725
	END,
	`spelltrigger_2` = 6,
	`spellcharges_2` = 0,
	`spellppmRate_2` = 0,
	`spellcooldown_2` = -1,
	`spellcategory_2` = 0,
	`spellcategorycooldown_2` = -1
WHERE `entry` IN (300382,300383,300384,300385,300386,300387,300388,300389,300390,300391,300392,300393,300394,300395);

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
-- One-time purchase rules (hide mounts already learned by the player)
-- -----------------------------------------------------------------------------

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 23
	AND `SourceGroup` = 3461020
	AND `SourceEntry` IN (300382,300383,300384,300385,300386,300387,300388,300389,300390,300391,300392,300393,300394,300395)
	AND `ConditionTypeOrReference` = 25;

INSERT INTO `conditions`
(`SourceTypeOrReferenceId`,`SourceGroup`,`SourceEntry`,`SourceId`,`ElseGroup`,`ConditionTypeOrReference`,`ConditionTarget`,`ConditionValue1`,`ConditionValue2`,`ConditionValue3`,`NegativeCondition`,`ErrorType`,`ErrorTextId`,`ScriptName`,`Comment`)
VALUES
(23,3461020,300389,0,0,25,0,300700,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Dreamowl Firemount if spell 300700 is not known.'),
(23,3461020,300390,0,0,25,0,300701,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Felblaze Infernal if spell 300701 is not known.'),
(23,3461020,300391,0,0,25,0,300702,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Netherwing Mount if spell 300702 is not known.'),
(23,3461020,300392,0,0,25,0,300703,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Coldflame Infernal if spell 300703 is not known.'),
(23,3461020,300393,0,0,25,0,300704,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Flarecore Infernal if spell 300704 is not known.'),
(23,3461020,300394,0,0,25,0,300705,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Frostshard Infernal if spell 300705 is not known.'),
(23,3461020,300395,0,0,25,0,300706,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Hellfire Infernal if spell 300706 is not known.'),
(23,3461020,300382,0,0,25,0,300707,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Black Skeletal Warhorse II if spell 300707 is not known.'),
(23,3461020,300383,0,0,25,0,300720,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Brown Skeletal Warhorse II if spell 300720 is not known.'),
(23,3461020,300384,0,0,25,0,300721,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Green Skeletal Warhorse II if spell 300721 is not known.'),
(23,3461020,300385,0,0,25,0,300722,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Midnight Skeletal Warhorse II if spell 300722 is not known.'),
(23,3461020,300386,0,0,25,0,300723,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Purple Skeletal Warhorse II if spell 300723 is not known.'),
(23,3461020,300387,0,0,25,0,300724,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the Red Skeletal Warhorse II if spell 300724 is not known.'),
(23,3461020,300388,0,0,25,0,300725,0,0,1,0,0,'','Skeletal Stablemaster - only sell Reins of the White Skeletal Warhorse II if spell 300725 is not known.');

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
