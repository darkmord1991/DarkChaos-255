-- Add metadata to guild house spawns for easier filtering/usage
ALTER TABLE `dc_guild_house_spawns`
    ADD COLUMN `spawn_type` ENUM('CREATURE','GAMEOBJECT') NOT NULL DEFAULT 'CREATURE' AFTER `entry`,
    ADD COLUMN `category` VARCHAR(64) NOT NULL DEFAULT 'misc' AFTER `spawn_type`,
    ADD COLUMN `label` VARCHAR(128) NOT NULL DEFAULT '' AFTER `category`,
    ADD COLUMN `enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `label`,
    ADD COLUMN `sort_order` INT NOT NULL DEFAULT 0 AFTER `enabled`,
    ADD COLUMN `preset` VARCHAR(64) NOT NULL DEFAULT 'default' AFTER `sort_order`;

-- Map 1 defaults (current entries)
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Paladin Trainer', `sort_order`=1 WHERE `id`=1;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Druid Trainer', `sort_order`=2 WHERE `id`=2;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Hunter Trainer', `sort_order`=3 WHERE `id`=3;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Mage Trainer', `sort_order`=4 WHERE `id`=4;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Priest Trainer', `sort_order`=5 WHERE `id`=5;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Rogue Trainer', `sort_order`=6 WHERE `id`=6;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Shaman Trainer', `sort_order`=7 WHERE `id`=7;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Warlock Trainer', `sort_order`=8 WHERE `id`=8;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Warrior Trainer', `sort_order`=9 WHERE `id`=9;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='Innkeeper', `sort_order`=10 WHERE `id`=10;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='Banker', `sort_order`=11 WHERE `id`=11;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Death Knight Trainer', `sort_order`=12 WHERE `id`=12;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='auctioneer', `label`='Alliance Auctioneer', `sort_order`=30 WHERE `id`=30;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='auctioneer', `label`='Horde Auctioneer', `sort_order`=31 WHERE `id`=31;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='GAMEOBJECT', `category`='object', `label`='Mailbox', `sort_order`=32 WHERE `id`=32;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='GAMEOBJECT', `category`='object', `label`='Forge', `sort_order`=33 WHERE `id`=33;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='GAMEOBJECT', `category`='object', `label`='Anvil', `sort_order`=34 WHERE `id`=34;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='GAMEOBJECT', `category`='object', `label`='Guild Vault', `sort_order`=45 WHERE `id`=45;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='vendor', `label`='Trade Supplies', `sort_order`=46 WHERE `id`=46;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='vendor', `label`='Tabard Vendor', `sort_order`=47 WHERE `id`=47;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='vendor', `label`='Food & Drink Vendor', `sort_order`=48 WHERE `id`=48;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='Spirit Healer', `sort_order`=49 WHERE `id`=49;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='GAMEOBJECT', `category`='object', `label`='Barber Chair', `sort_order`=50 WHERE `id`=50;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='vendor', `label`='Reagent Vendor', `sort_order`=51 WHERE `id`=51;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='vendor', `label`='Ammo & Repair Vendor', `sort_order`=52 WHERE `id`=52;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='Stable Master', `sort_order`=53 WHERE `id`=53;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='auctioneer', `label`='Neutral Auctioneer', `sort_order`=54 WHERE `id`=54;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='vendor', `label`='Poisons Vendor', `sort_order`=55 WHERE `id`=55;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='seasonal', `label`='Seasonal Trader', `sort_order`=79 WHERE `id`=79;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='seasonal', `label`='Holiday Ambassador', `sort_order`=80 WHERE `id`=80;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='seasonal', `label`='Omni-Crafter', `sort_order`=81 WHERE `id`=81;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='Guildhouse Manager', `sort_order`=82 WHERE `id`=82;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='GuildHouse Butler', `sort_order`=83 WHERE `id`=83;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='service', `label`='Services NPC', `sort_order`=84 WHERE `id`=84;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='mythic', `label`='Mythic NPC 190004', `sort_order`=85 WHERE `id`=85;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='mythic', `label`='Mythic NPC 100050', `sort_order`=86 WHERE `id`=86;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='mythic', `label`='Mythic NPC 100051', `sort_order`=87 WHERE `id`=87;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='mythic', `label`='Mythic NPC 100101', `sort_order`=88 WHERE `id`=88;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='mythic', `label`='Mythic NPC 100100', `sort_order`=89 WHERE `id`=89;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Alchemy Trainer', `sort_order`=90 WHERE `id`=90;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Herbalism Trainer', `sort_order`=91 WHERE `id`=91;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Blacksmithing Trainer', `sort_order`=92 WHERE `id`=92;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Mining Trainer', `sort_order`=93 WHERE `id`=93;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Engineering Trainer', `sort_order`=94 WHERE `id`=94;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Jewelcrafting Trainer', `sort_order`=95 WHERE `id`=95;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Enchanting Trainer', `sort_order`=96 WHERE `id`=96;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Inscription Trainer', `sort_order`=97 WHERE `id`=97;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Leatherworking Trainer', `sort_order`=98 WHERE `id`=98;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Skinning Trainer', `sort_order`=99 WHERE `id`=99;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Tailoring Trainer', `sort_order`=100 WHERE `id`=100;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Cooking Trainer', `sort_order`=101 WHERE `id`=101;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='First Aid Trainer', `sort_order`=102 WHERE `id`=102;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Fishing Trainer', `sort_order`=103 WHERE `id`=103;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Weapon Trainer', `sort_order`=104 WHERE `id`=104;
UPDATE `dc_guild_house_spawns` SET `spawn_type`='CREATURE', `category`='trainer', `label`='Riding Trainer', `sort_order`=105 WHERE `id`=105;
