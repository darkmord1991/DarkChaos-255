-- Dark Chaos - repair the five companion pets that had a dc_pet_definitions row
-- but no way to obtain, summon or see them (found 2026-09-01 while verifying the
-- roster pet batch: 5 of 1327 pet definitions had no dc_collection_definitions row).
--
-- NOT a DarkChaos regression. acore_backup (stock-shaped reference) carries the
-- identical state: of the five Turtle Egg variants only (Loggerhead) 18964 was ever
-- given a teaching spell, so the other four are unused Blizzard item templates.
-- Everything needed to finish them already exists on the realm:
--
--   item    name                       spell  creature  display  creature name
--   18963   Turtle Egg (Albino)        23428     14633    14661  Albino Snapjaw
--   18964   Turtle Egg (Loggerhead)    23429     14629    14657  Loggerhead Snapjaw  (already worked)
--   18965   Turtle Egg (Hawksbill)     23432     14632    14660  Hawksbill Snapjaw
--   18966   Turtle Egg (Leatherback)   23431     14630    14658  Leatherback Snapjaw
--   18967   Turtle Egg (Olive)         23430     14631    14659  Olive Snapjaw
--
-- All four spells are stock Spell.dbc rows with Effect_1 = 28 (SUMMON), all five
-- creatures exist in creature_template with a creature_template_model row, and all
-- five displays have a creature_model_info row. Verified against the live DB.
--
-- Item 39148 "Baby Coralshell Turtle" is handled separately at the bottom: NO spell
-- anywhere in Spell.dbc summons its creature (24594), so unlike the turtles it cannot
-- be finished without inventing content, and its definition row is removed instead.

-- 1) item_template: teach the pet, mirroring the working 18964 exactly
--    (spellid_1 = 55884 'Learning' placeholder at trigger 0, real summon at trigger 6)
UPDATE `item_template` SET `spellid_1`=55884, `spelltrigger_1`=0, `spellid_2`=23428, `spelltrigger_2`=6 WHERE `entry`=18963;
UPDATE `item_template` SET `spellid_1`=55884, `spelltrigger_1`=0, `spellid_2`=23432, `spelltrigger_2`=6 WHERE `entry`=18965;
UPDATE `item_template` SET `spellid_1`=55884, `spelltrigger_1`=0, `spellid_2`=23431, `spelltrigger_2`=6 WHERE `entry`=18966;
UPDATE `item_template` SET `spellid_1`=55884, `spelltrigger_1`=0, `spellid_2`=23430, `spelltrigger_2`=6 WHERE `entry`=18967;

-- 2) dc_pet_definitions: give each its summon spell AND its own display.
--    All five rows carried display_id 14657 (the Loggerhead model), so even the four
--    that are being enabled here would otherwise have rendered as the wrong turtle.
UPDATE `dc_pet_definitions` SET `pet_spell_id`=23428, `display_id`=14661 WHERE `pet_entry`=18963;
UPDATE `dc_pet_definitions` SET `pet_spell_id`=23432, `display_id`=14660 WHERE `pet_entry`=18965;
UPDATE `dc_pet_definitions` SET `pet_spell_id`=23431, `display_id`=14658 WHERE `pet_entry`=18966;
UPDATE `dc_pet_definitions` SET `pet_spell_id`=23430, `display_id`=14659 WHERE `pet_entry`=18967;

-- 3) dc_collection_definitions: the missing rows, which is why these never appeared
--    in the collection UI at all
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=2 AND `entry_id` IN (18963,18965,18966,18967);
INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(2,18963,1),
(2,18965,1),
(2,18966,1),
(2,18967,1);

-- 4) npc_vendor: sell them wherever 18964 is already sold (the two 'Pets' vendors
--    500069 and 601569, slot 0 = append). Without this the items stay unobtainable
--    and the collection entry is decorative.
DELETE FROM `npc_vendor` WHERE `entry` IN (500069,601569) AND `item` IN (18963,18965,18966,18967);
INSERT INTO `npc_vendor` (`entry`,`slot`,`item`,`maxcount`,`incrtime`,`ExtendedCost`,`VerifiedBuild`)
VALUES
(500069,0,18963,0,0,0,0),
(500069,0,18965,0,0,0,0),
(500069,0,18966,0,0,0,0),
(500069,0,18967,0,0,0,0),
(601569,0,18963,0,0,0,0),
(601569,0,18965,0,0,0,0),
(601569,0,18966,0,0,0,0),
(601569,0,18967,0,0,0,0);

-- 5) Baby Coralshell Turtle (39148) -- drop the phantom definition.
--    The item is a stock template (VerifiedBuild 15595) with every spell slot 0, and
--    a scan of all 54,354 Spell.csv rows finds NO spell whose Effect 28/56 summons its
--    creature 24594. It therefore cannot be taught, summoned or collected, and its
--    definition row only inflates the collection's expected-pet count. Restore with
--    the INSERT below if it is ever given a summon spell.
-- INSERT INTO `dc_pet_definitions` (`pet_entry`,`name`,`pet_type`,`pet_spell_id`,`source`,`faction`,`display_id`,`icon`,`rarity`,`expansion`,`flags`,`variant_group`,`variant_color`)
-- VALUES (39148,'Baby Coralshell Turtle','companion',0,'{"type":"item","name":"Baby Coralshell Turtle"}',0,7046,'',1,2,0,NULL,NULL);
DELETE FROM `dc_pet_definitions` WHERE `pet_entry`=39148;
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=2 AND `entry_id`=39148;

-- 6) Finish the 2026-06-18 non-pet purge on the OTHER table.
--    CollectionSystem/2026_06_18_02_dc_pet_definitions_remove_nonpet_rows.sql deleted
--    these four from `dc_pet_definitions` (22200 Silver Shafted Arrow as a
--    SPELL_EFFECT_DUMMY in its group A; 35227 Goblin Weather Machine and the 37460 /
--    44820 pet leashes as toys in its group B) but never touched
--    `dc_collection_definitions`, leaving four collection entries pointing at pet
--    definitions that no longer exist. They are the exact mirror of the problem this
--    file opens with, and the only four of their kind on the realm.
DELETE FROM `dc_collection_definitions` WHERE `collection_type`=2 AND `entry_id` IN (22200,35227,37460,44820);
