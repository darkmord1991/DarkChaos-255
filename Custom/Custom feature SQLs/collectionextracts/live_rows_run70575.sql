-- Live-DB snapshot of the 13 collection rows of retail downport run 70575 (2026-10-28),
-- taken read-only from acore_world on 2026-11-08.
-- Their Retroports/2026_10_28_00..04_*.sql files disappeared from disk on 2026-10-28 and were
-- never committed, so no repo SQL named these rows and tools/generate_dc_collection_cdbc.py
-- refused to regenerate. This file restores them as an input; the rows ARE live already, so
-- applying it changes nothing. Supersede it with a full re-extract of extracts.sql.
--
-- The item_template and creature_template_model rows are what the generator reads a mount's
-- ItemID (spellid_2 -> teaching item) and CreatureID (display -> creature) from; without them
-- the 10 mounts regenerate with ItemID 0 / CreatureID 0. INSERT IGNORE without a DELETE, so
-- applying this can never overwrite a live item or creature row.

DELETE FROM `dc_mount_definitions` WHERE `spell_id` BETWEEN 303078 AND 303087;
INSERT INTO `dc_mount_definitions` (`spell_id`,`name`,`mount_type`,`source`,`faction`,`class_mask`,`display_id`,`icon`,`rarity`,`speed`,`expansion`,`is_tradeable`,`profession_required`,`skill_required`,`flags`) VALUES
(303078,'Hot Motocross Bunmover 4000',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505182,'',4,100,2,0,NULL,NULL,0),
(303079,'Hot Motocross Bunmover 4200',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505183,'',4,100,2,0,NULL,NULL,0),
(303080,'Hot Motocross Bunmover 4400',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505184,'',4,100,2,0,NULL,NULL,0),
(303081,'Hot Motocross Bunmover 4600',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505185,'',4,100,2,0,NULL,NULL,0),
(303082,'Living Heartsbane Cauldron',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505186,'',4,310,2,0,NULL,NULL,0),
(303083,'Ashen Dreadglider',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505187,'',4,310,2,0,NULL,NULL,0),
(303084,'Sporebearer Fungal Strider',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505188,'',4,100,2,0,NULL,NULL,0),
(303085,'Loa-Blessed Wayfarer',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505189,'',4,310,2,0,NULL,NULL,0),
(303086,'Corrupted Swarmer',3,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505190,'',4,310,2,0,NULL,NULL,0),
(303087,'Giant Grrloc',0,'{"type":"vendor","npc":"Skeletal Stablemaster","npcEntry":3461020}',0,0,505191,'',4,100,2,0,NULL,NULL,0);

DELETE FROM `dc_pet_definitions` WHERE `pet_entry` BETWEEN 303088 AND 303090;
INSERT INTO `dc_pet_definitions` (`pet_entry`,`name`,`pet_type`,`pet_spell_id`,`source`,`faction`,`display_id`,`icon`,`rarity`,`expansion`,`flags`,`variant_group`,`variant_color`) VALUES
(303088,'Aqir Razorwing','companion',303088,'{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229}',0,505192,'inv_icon_wingbroken03b',3,4,0,'aqirflying','Aqir Razorwing'),
(303089,'Aqir Wingreaver','companion',303089,'{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229}',0,505193,'inv_icon_wing03c',2,4,0,'aqirflying','Aqir Wingreaver'),
(303090,'Aqir Scuttler','companion',303090,'{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229}',0,505194,'inv_misc_monsterscales_13',2,4,0,'aqirscarab','Aqir Scuttler');

DELETE FROM `dc_collection_definitions` WHERE `entry_id` BETWEEN 303078 AND 303090 AND `collection_type` IN (1,2);
INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`) VALUES
(1,303078,1),(1,303079,1),(1,303080,1),(1,303081,1),(1,303082,1),(1,303083,1),(1,303084,1),(1,303085,1),(1,303086,1),(1,303087,1),
(2,303088,1),(2,303089,1),(2,303090,1);

INSERT IGNORE INTO `item_template` (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,`displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,`SellPrice`,`InventoryType`,`Material`,`AllowableClass`,`AllowableRace`,`ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,`spellid_1`,`spelltrigger_1`,`spellcharges_1`,`spellppmRate_1`,`spellcooldown_1`,`spellcategory_1`,`spellcategorycooldown_1`,`spellid_2`,`spelltrigger_2`,`spellcharges_2`,`spellppmRate_2`,`spellcooldown_2`,`spellcategory_2`,`spellcategorycooldown_2`,`bonding`,`description`,`RequiredDisenchantSkill`,`duration`,`ScriptName`,`DisenchantID`,`FoodType`,`minMoneyLoot`,`maxMoneyLoot`,`flagsCustom`,`VerifiedBuild`) VALUES
(303078,15,5,-1,'Reins of the Hot Motocross Bunmover 4000',16270412,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303078,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303079,15,5,-1,'Reins of the Hot Motocross Bunmover 4200',16270411,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303079,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303080,15,5,-1,'Reins of the Hot Motocross Bunmover 4400',16270410,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303080,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303081,15,5,-1,'Reins of the Hot Motocross Bunmover 4600',16270409,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303081,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303082,15,5,-1,'Reins of the Living Heartsbane Cauldron',15940961,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303082,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303083,15,5,-1,'Reins of the Ashen Dreadglider',15958551,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303083,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303084,15,5,-1,'Reins of the Sporebearer Fungal Strider',16262534,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303084,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303085,15,5,-1,'Reins of the Loa-Blessed Wayfarer',16269989,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303085,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303086,15,5,-1,'Reins of the Corrupted Swarmer',16014728,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303086,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303087,15,5,-1,'Reins of the Giant Grrloc',15933423,4,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303087,6,0,0,-1,0,-1,0,'Teaches you how to summon this mount.',-1,0,'',0,0,0,0,0,0),
(303088,15,2,-1,'Cage of the Aqir Razorwing',10103895,3,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303088,6,0,0,-1,0,-1,0,'Teaches you how to summon this companion.',-1,0,'',0,0,0,0,0,0),
(303089,15,2,-1,'Cage of the Aqir Wingreaver',10103856,2,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303089,6,0,0,-1,0,-1,0,'Teaches you how to summon this companion.',-1,0,'',0,0,0,0,0,0),
(303090,15,2,-1,'Cage of the Aqir Scuttler',22642,2,0,0,1,0,0,0,4,-1,-1,40,1,1,1,0,55884,0,-1,0,-1,330,3000,303090,6,0,0,-1,0,-1,0,'Teaches you how to summon this companion.',-1,0,'',0,0,0,0,0,0);

INSERT IGNORE INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`) VALUES
(3463626,0,505182,1,1,0),(3463627,0,505183,1,1,0),(3463628,0,505184,1,1,0),(3463629,0,505185,1,1,0),(3463630,0,505186,1,1,0),
(3463631,0,505187,1,1,0),(3463632,0,505188,1,1,0),(3463633,0,505189,1,1,0),(3463634,0,505190,1,1,0),(3463635,0,505191,1,1,0),
(3463636,0,505192,1,1,0),(3463637,0,505193,1,1,0),(3463638,0,505194,1,1,0);
