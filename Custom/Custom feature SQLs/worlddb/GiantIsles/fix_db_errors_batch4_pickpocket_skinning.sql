-- ---------------------------------------------------------------------------
-- pickpocketing_loot_template / skinning_loot_template gaps -- Atal'Hakkar
-- Temple clone (Zul'Gurub reskin, see temple_atal_hakkar_clone.sql)
-- ---------------------------------------------------------------------------
-- More-db-errors audit pass (2026-07-13, ultracode workflow investigation):
-- "Table `pickpocketing_loot_template` loot for creature (400500) not found"
-- (and 10 more), "Table `skinning_loot_template` loot for creature (400523)
-- not found". creature_template.pickpocketloot/skinloot already point to
-- these entries (self-referential, matching this project's own-entry-as-
-- lootid convention), but the actual loot rows were never authored.
--
-- NOTE: an existing file (fix_creature_template_errors_2.sql sections 5-6)
-- "fixed" these same warnings by NULLING pickpocketloot/skinloot to 0 --
-- that only silences the boot-log line by disabling the feature outright.
-- This file supersedes that workaround with real loot: each of these
-- creatures is a reskinned/renamed clone of a real Zul'Gurub Atal'ai troll
-- or boss (confirmed by name -- several are exact/near-exact matches, e.g.
-- 400513 "Soul Raker Mijan" / 5717 "Mijan", 400520 "Atal'alarion the
-- Eternal" / 8580 "Atal'alarion", 400521 "Jammal'an the Eternal" / 5710
-- "Jammal'an the Prophet", 400523 "Ancient Shade of Eranikus" / 5709 "Shade
-- of Eranikus"), so their loot is copied straight from the real ZG source
-- entry's already-live loot rows in this same DB.
-- ---------------------------------------------------------------------------
DELETE FROM `pickpocketing_loot_template` WHERE `Entry` IN (400500,400501,400502,400504,400505,400510,400511,400512,400513,400520,400521);

INSERT INTO `pickpocketing_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT 400500, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5256   -- Awakened Atal'ai Warrior <- Atal'ai Warrior
UNION ALL SELECT 400501, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5259   -- Awakened Atal'ai Witch Doctor <- Atal'ai Witch Doctor
UNION ALL SELECT 400502, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5273   -- Risen Atal'ai Priest <- Atal'ai High Priest
UNION ALL SELECT 400504, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5270   -- Atal'ai Soulflayer <- Atal'ai Corpse Eater
UNION ALL SELECT 400505, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5263   -- Hakkar's Devotee <- Mummified Atal'ai
UNION ALL SELECT 400510, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5713   -- Zul'kar the Flayer <- Gasher
UNION ALL SELECT 400511, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5715   -- Seer Mazra <- Hukku
UNION ALL SELECT 400512, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5716   -- Bone Weaver Zolo <- Zul'Lor
UNION ALL SELECT 400513, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5717   -- Soul Raker Mijan <- Mijan
UNION ALL SELECT 400520, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 8580   -- Atal'alarion the Eternal <- Atal'alarion
UNION ALL SELECT 400521, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `pickpocketing_loot_template` WHERE `Entry` = 5710;  -- Jammal'an the Eternal <- Jammal'an the Prophet

DELETE FROM `skinning_loot_template` WHERE `Entry` = 400523;

INSERT INTO `skinning_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT 400523, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment` FROM `skinning_loot_template` WHERE `Entry` = 5709;  -- Ancient Shade of Eranikus <- Shade of Eranikus
