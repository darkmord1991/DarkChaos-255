-- Camel mount item + vendor integration for custom mount vendor
-- Requires Spell.csv row ID 300726 and custom mount display 500176.

-- Keep Neptulon at 20% size in case the earlier template migration was already applied.
UPDATE `creature_template_model`
SET `DisplayScale` = 0.2
WHERE `CreatureID` = 3461177 AND `Idx` = 0;

DELETE FROM `item_template` WHERE `entry` = 300396;

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
(300396,15,5,-1,'Reins of the Camel Mount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300726,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0);

DELETE FROM `npc_vendor` WHERE `entry` = 3461020 AND `item` = 300396;
DELETE FROM `npc_vendor` WHERE `entry` = 3461020 AND `slot` = 14;

INSERT INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(3461020,14,300396,0,0,0,0);

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 23
    AND `SourceGroup` = 3461020
    AND `SourceEntry` = 300396
    AND `ConditionTypeOrReference` = 25;

INSERT INTO `dc_mount_definitions`
(`spell_id`,`name`,`mount_type`,`source`,`faction`,`rarity`,`speed`,`display_id`)
VALUES
(300726,'Camel Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500176)
ON DUPLICATE KEY UPDATE
`name` = VALUES(`name`),
`mount_type` = VALUES(`mount_type`),
`source` = VALUES(`source`),
`faction` = VALUES(`faction`),
`rarity` = VALUES(`rarity`),
`speed` = VALUES(`speed`),
`display_id` = VALUES(`display_id`);

DELETE FROM `dc_collection_definitions`
WHERE `collection_type` = 1 AND `entry_id` = 300726;

INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,300726,1);
