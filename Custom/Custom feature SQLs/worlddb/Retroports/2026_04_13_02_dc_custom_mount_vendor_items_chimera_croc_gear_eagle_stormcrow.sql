-- Additional mount item + vendor + collection integration
-- Requires Spell.csv rows 300727-300734 and displays 500181-500188.

DELETE FROM `item_template` WHERE `entry` BETWEEN 300397 AND 300404;

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
(300397,15,5,-1,'Reins of the Chimera Firemount Yellow',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300727,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300398,15,5,-1,'Reins of the Chimera Firemount Blue',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300728,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300399,15,5,-1,'Reins of the Chimera Firemount Green',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300729,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300400,15,5,-1,'Reins of the Chimera Firemount Red',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300730,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300401,15,5,-1,'Reins of the Crocsun Mount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300731,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300402,15,5,-1,'Reins of the Geargrinder Mount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300732,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300403,15,5,-1,'Reins of the Giant Eagle Hexmount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300733,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(300404,15,5,-1,'Reins of the Fel Stormcrow Mount',68743,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,300734,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0);

DELETE FROM `npc_vendor` WHERE `entry` = 3461020 AND `item` IN (300397,300398,300399,300400,300401,300402,300403,300404);
DELETE FROM `npc_vendor` WHERE `entry` = 3461020 AND `slot` IN (15,16,17,18,19,20,21,22);

INSERT INTO `npc_vendor`
(`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(3461020,15,300397,0,0,0,0),
(3461020,16,300398,0,0,0,0),
(3461020,17,300399,0,0,0,0),
(3461020,18,300400,0,0,0,0),
(3461020,19,300401,0,0,0,0),
(3461020,20,300402,0,0,0,0),
(3461020,21,300403,0,0,0,0),
(3461020,22,300404,0,0,0,0);

DELETE FROM `conditions`
WHERE `SourceTypeOrReferenceId` = 23
    AND `SourceGroup` = 3461020
    AND `SourceEntry` IN (300397,300398,300399,300400,300401,300402,300403,300404)
    AND `ConditionTypeOrReference` = 25;

INSERT INTO `dc_mount_definitions`
(`spell_id`,`name`,`mount_type`,`source`,`faction`,`rarity`,`speed`,`display_id`)
VALUES
(300727,'Chimera Firemount Yellow',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500181),
(300728,'Chimera Firemount Blue',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500182),
(300729,'Chimera Firemount Green',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500183),
(300730,'Chimera Firemount Red',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500184),
(300731,'Crocsun Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500185),
(300732,'Geargrinder Mount',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,100,500186),
(300733,'Giant Eagle Hexmount',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500187),
(300734,'Fel Stormcrow Mount',1,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,4,280,500188)
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
    AND `entry_id` IN (300727,300728,300729,300730,300731,300732,300733,300734);

INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(1,300727,1),
(1,300728,1),
(1,300729,1),
(1,300730,1),
(1,300731,1),
(1,300732,1),
(1,300733,1),
(1,300734,1);
