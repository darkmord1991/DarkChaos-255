-- ============================================================================
-- TEMPLE OF ATAL'HAKKAR — Giant Isles Clone
-- ============================================================================
-- An ancient copy of the Sunken Temple has risen in the Giant Isles.
-- Awakened Atal'ai cultists and their masters stir within its walls.
--
-- Map: Giant Isles (Map ID: 1405, Zone: Giant Isles)
--
-- This file is the quest / item / reward layer. The dungeon itself - the 1:1
-- copy of map 109 under the island temple, its creatures 400500-400523 (the quest
-- and achievement objectives) and 400530-400561, spawns, SmartAI, texts and all
-- of their creature loot - lives in
--   data/sql/updates/pending_db_world/rev_1791031658174280700.sql
-- plus src/server/scripts/DC/GiantIsles/dc_giant_isles_sunken_temple.cpp.
-- Do not add creature_template/SmartAI/loot rows for 400500-400523 here again:
-- re-running this file would overwrite the clones.
--
-- Entry ranges owned here:
--   creature_template : 400525-400527  (quest givers)
--   item_template     : 402000-402024  (quest item, rewards, boss drops)
--   quest_template    : 82000-82005, 82010-82015
--   reference_loot    : 14132          (temple boss loot pool)
--
-- Quest chain:
--   82000  "The Sunken Temple Awakens"  (intro kill quest)
--    └─ 82001  "The Four Bloodseekers"  (kill 4 sub-bosses → ring choice)
--        └─ 82002  "The Eternal Prophet"  (kill Jammal'an + collect idols → neck choice)
--            └─ 82003  "Hakkar Must Not Rise"  (kill Avatar → cloak choice)
--   82004  "Nightmare in the Deep"  (standalone: kill Shade → trinket choice)
--   82005  Daily: "Atal'ai Offerings"  (kill 12 trash → gold)
-- ============================================================================

-- ============================================================================
-- 1. CLEANUP
-- ============================================================================
DELETE FROM `creature_template`           WHERE `entry`  = 400525;
DELETE FROM `creature_template_model`     WHERE `CreatureID` = 400525;
DELETE FROM `item_template`               WHERE `entry`  BETWEEN 402000 AND 402022;
DELETE FROM `quest_template`              WHERE `ID`     BETWEEN 82000 AND 82005;
DELETE FROM `quest_template_addon`        WHERE `ID`     BETWEEN 82000 AND 82005;
DELETE FROM `quest_offer_reward`          WHERE `ID`     BETWEEN 82000 AND 82005;
DELETE FROM `quest_request_items`         WHERE `ID`     BETWEEN 82000 AND 82005;
DELETE FROM `creature_queststarter`       WHERE `quest`  BETWEEN 82000 AND 82005;
DELETE FROM `creature_questender`         WHERE `quest`  BETWEEN 82000 AND 82005;
DELETE FROM `reference_loot_template`     WHERE `Entry`  = 14132;

-- ============================================================================
-- 2-4. TEMPLE CREATURES (400500-400523): moved to the dungeon copy SQL (see header)
-- ============================================================================
-- 5. QUEST GIVER (400525)
-- Scholar Zal'ira — Zandalari Historian at the temple entrance
-- ============================================================================
INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,
     `KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,
     `minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
     `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,`rank`,`dmgschool`,`DamageModifier`,
     `BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,
     `unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,
     `lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
     `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,
     `RacialLeader`,`movementId`,`RegenHealth`,`CreatureImmunitiesId`,
     `flags_extra`,`ScriptName`,`VerifiedBuild`)
VALUES
(400525,0,0,0,0,0,'Scholar Zal\'ira','Zandalari Historian','Speak',0,
 80,80,2,35,3,
 1.0,1.14286,1.0,1.0,20.0,0,0,1.0,
 2000,2000,1,1,
 1,768,2048,0,0,7,0,
 0,0,0,0,0,
 0,0,'',0,1,
 10,1,1,1,
 0,0,1,0,
 2,'',12340);

-- ============================================================================
-- 6. QUEST GIVER MODEL
-- ============================================================================
DELETE FROM `creature_template_model` WHERE `CreatureID` = 400525;
-- Quest giver: use Elder Zul'jin model (already in Giant Isles)
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400525, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 12340 FROM `creature_template_model` WHERE `CreatureID` = 400200 LIMIT 1;

-- ============================================================================
-- 7-8. SMARTAI / CREATURE TEXTS: moved to the dungeon copy SQL (see header)
-- ============================================================================
-- 9. QUEST ITEM
-- ============================================================================
DELETE FROM `item_template` WHERE `entry` BETWEEN 402000 AND 402022;

-- 402000: Idol Fragment of Hakkar (quest collect item — drops from sub-bosses + main bosses)
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
(402000, 12, 0, -1, 'Idol Fragment of Hakkar',
    52576, 1, 0, 0, 1, 0,
    0, 0, -1, -1,
    1, 0, 0, 20, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 4, 'A shard of Hakkar\'s shattered idol. Required for ancient Zandalari rituals.', 0);

-- ============================================================================
-- 10. QUEST REWARD RINGS  (402001–402005)  — Quest 82001 choices, ilvl 285, req 80
-- Stat conventions match Hyjal Frontier (ilvl 300 = top of 80+ tier).
-- These sit ~5% below Hyjal Foothills entry rings.
-- Stat types: 45=SpellPower  38=AttackPower  7=Stam  5=Int  4=Str  3=Agi
--             6=Spirit  31=Hit  32=Crit  36=Haste  37=Expertise
--             12=Defense  13=Dodge  14=Parry
-- ============================================================================
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
-- Caster DPS ring
(402001, 4, 0, -1, 'Shard of Hakkar\'s Vision',
    64170, 3, 0, 0, 1, 0, 65000, 11, -1, -1, 285, 80, 0, 1, 0,
    45,104,  7,74,  5,74,  32,65,  36,56,  0, 1, '', 0),
-- Healer ring
(402002, 4, 0, -1, 'Shard of Hakkar\'s Mercy',
    33864, 3, 0, 0, 1, 0, 65000, 11, -1, -1, 285, 80, 0, 1, 0,
    45,104,  7,74,  5,74,   6,65,  32,56,  0, 1, '', 0),
-- Agility / physical DPS ring
(402003, 4, 0, -1, 'Shard of Hakkar\'s Fang',
    64225, 3, 0, 0, 1, 0, 65000, 11, -1, -1, 285, 80, 0, 1, 0,
    38,113,  3,97,  7,97,  32,65,  37,56,  0, 1, '', 0),
-- Strength / melee DPS ring
(402004, 4, 0, -1, 'Shard of Hakkar\'s Might',
    64176, 3, 0, 0, 1, 0, 65000, 11, -1, -1, 285, 80, 0, 1, 0,
    4,103,   7,111,  32,65,  36,56,  0,0,  0, 1, '', 0),
-- Tank ring
(402005, 4, 0, -1, 'Shard of Hakkar\'s Shield',
    64229, 3, 0, 0, 1, 0, 65000, 11, -1, -1, 285, 80, 0, 1, 0,
    4,97,  7,134,  12,46,  13,47,  14,52,  0, 1, '', 0);

-- ============================================================================
-- 11. QUEST REWARD NECKS  (402006–402010) — Quest 82002 choices, ilvl 285, req 80
-- ============================================================================
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
(402006, 4, 0, -1, 'Idol-Bound Sage\'s Pendant',
    9859, 3, 0, 0, 1, 0, 65000, 2, -1, -1, 285, 80, 0, 1, 0,
    45,104,  7,74,  5,74,  32,65,  36,56,  0, 1, '', 0),
(402007, 4, 0, -1, 'Idol-Bound Mender\'s Talisman',
    6494, 3, 0, 0, 1, 0, 65000, 2, -1, -1, 285, 80, 0, 1, 0,
    45,104,  7,74,  5,74,   6,65,  32,56,  0, 1, '', 0),
(402008, 4, 0, -1, 'Idol-Bound Hunter\'s Chain',
    9858, 3, 0, 0, 1, 0, 65000, 2, -1, -1, 285, 80, 0, 1, 0,
    38,113,  3,97,  7,97,  32,65,  37,56,  0, 1, '', 0),
(402009, 4, 0, -1, 'Idol-Bound Warrior\'s Gorget',
    19785, 3, 0, 0, 1, 0, 65000, 2, -1, -1, 285, 80, 0, 1, 0,
    4,103,   7,111,  32,65,  36,56,  0,0,  0, 1, '', 0),
(402010, 4, 0, -1, 'Idol-Bound Warden\'s Collar',
    18308, 3, 0, 0, 1, 0, 65000, 2, -1, -1, 285, 80, 0, 1, 0,
    4,97,  7,134,  12,46,  13,47,  14,52,  0, 1, '', 0);

-- ============================================================================
-- 12. QUEST REWARD CLOAKS  (402011–402015) — Quest 82003 choices, ilvl 295, req 80
-- ============================================================================
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
-- Caster DPS cloak
(402011, 4, 1, -1, 'Cloak of the Eternal Temple',
    28951, 3, 0, 0, 1, 0, 90000, 16, -1, -1, 295, 80, 0, 1, 0,
    45,108,  7,78,  5,78,  32,66,  36,58,  185, 1, '', 0),
-- Healer cloak
(402012, 4, 1, -1, 'Cloak of the Fallen Prophet',
    64300, 3, 0, 0, 1, 0, 90000, 16, -1, -1, 295, 80, 0, 1, 0,
    45,108,  7,78,  5,78,   6,66,  32,58,  185, 1, '', 0),
-- Agility cloak
(402013, 4, 1, -1, 'Cloak of Primal Shadows',
    64326, 3, 0, 0, 1, 0, 90000, 16, -1, -1, 295, 80, 0, 1, 0,
    38,116,  3,99,  7,99,  32,66,  37,58,  185, 1, '', 0),
-- Strength cloak
(402014, 4, 1, -1, 'Cloak of Atal\'ai Conquest',
    64307, 3, 0, 0, 1, 0, 90000, 16, -1, -1, 295, 80, 0, 1, 0,
    4,105,   7,115,  32,66,  36,58,  0,0,  185, 1, '', 0),
-- Tank cloak
(402015, 4, 1, -1, 'Bulwark of the Sunken Temple',
    54674, 3, 0, 0, 1, 0, 90000, 16, -1, -1, 295, 80, 0, 1, 0,
    4,99,  7,140,  12,48,  13,49,  14,54,  255, 1, '', 0);

-- ============================================================================
-- 13. QUEST REWARD TRINKETS  (402016–402020) — Quest 82004 choices, ilvl 290, req 80
-- ============================================================================
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
-- Caster DPS trinket
(402016, 4, 0, -1, 'Talisman of the Blood God',
    52576, 3, 0, 0, 1, 0, 80000, 12, -1, -1, 290, 80, 0, 1, 0,
    45,95,  7,75,  0,0,  0,0,  0,0,  0, 1, '', 0),
-- Healer trinket (spell power + spirit)
(402017, 4, 0, -1, 'Idol of the Fallen Prophet',
    52326, 3, 0, 0, 1, 0, 80000, 12, -1, -1, 290, 80, 0, 1, 0,
    45,80,  6,85,  7,65,  0,0,  0,0,  0, 1, '', 0),
-- Agility / physical DPS trinket
(402018, 4, 0, -1, 'Fang of the Ancient',
    51724, 3, 0, 0, 1, 0, 80000, 12, -1, -1, 290, 80, 0, 1, 0,
    38,110,  3,90,  7,70,  0,0,  0,0,  0, 1, '', 0),
-- Strength trinket
(402019, 4, 0, -1, 'Might of the Eternal',
    51706, 3, 0, 0, 1, 0, 80000, 12, -1, -1, 290, 80, 0, 1, 0,
    4,100,  7,90,  0,0,  0,0,  0,0,  0, 1, '', 0),
-- Tank trinket (stam + defense)
(402020, 4, 0, -1, 'Ward of Hakkar',
    53122, 3, 0, 0, 1, 0, 80000, 12, -1, -1, 290, 80, 0, 1, 0,
    7,155,  12,75,  0,0,  0,0,  0,0,  0, 1, '', 0);

-- ============================================================================
-- 14. EPIC BOSS-ONLY DROPS  (402021–402022) — Quality 4, ilvl 300, req 80
-- These are rare bonus drops, not tied to any quest reward choice.
-- ============================================================================
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
-- Avatar of Hakkar drop: epic ring (caster/all-rounder)
(402021, 4, 0, -1, 'Hakkar\'s Eternal Seal',
    64170, 4, 0, 0, 1, 0, 115000, 11, -1, -1, 300, 80, 0, 1, 0,
    45,115,  7,85,  5,85,  32,72,  36,62,  0, 1, 'Forged from the blood of a god.', 0),
-- Shade of Eranikus drop: epic neck (physical / agility)
(402022, 4, 0, -1, 'Dreamscale Amulet of Eranikus',
    9859, 4, 0, 0, 1, 0, 115000, 2, -1, -1, 300, 80, 0, 1, 0,
    38,125,  3,108,  7,108,  32,75,  37,65,  0, 1, 'Carved from the fading essence of a nightmare wyrm.', 0);

-- ============================================================================
-- 15. QUEST TEMPLATES (82000–82005)
-- ============================================================================
DELETE FROM `quest_template` WHERE `ID` BETWEEN 82000 AND 82005;
INSERT INTO `quest_template`
    (`ID`,`QuestType`,`QuestLevel`,`MinLevel`,`QuestSortID`,`QuestInfoID`,
     `SuggestedGroupNum`,`RewardXPDifficulty`,`RewardMoney`,`RewardMoneyDifficulty`,
     `RewardDisplaySpell`,`RewardSpell`,`Flags`,
     `RequiredNpcOrGo1`,`RequiredNpcOrGoCount1`,
     `RequiredNpcOrGo2`,`RequiredNpcOrGoCount2`,
     `RequiredNpcOrGo3`,`RequiredNpcOrGoCount3`,
     `RequiredNpcOrGo4`,`RequiredNpcOrGoCount4`,
     `RequiredItemId1`,`RequiredItemCount1`,
     `RewardChoiceItemID1`,`RewardChoiceItemQuantity1`,
     `RewardChoiceItemID2`,`RewardChoiceItemQuantity2`,
     `RewardChoiceItemID3`,`RewardChoiceItemQuantity3`,
     `RewardChoiceItemID4`,`RewardChoiceItemQuantity4`,
     `RewardChoiceItemID5`,`RewardChoiceItemQuantity5`,
     `LogTitle`,`LogDescription`,`QuestDescription`,`AreaDescription`,`QuestCompletionLog`,
     `VerifiedBuild`)
VALUES
-- 82000: "The Sunken Temple Awakens" — intro quest
(82000, 2, 80, 80, 5006, 81,
 5, 5, 150000, 0,
 0, 0, 8,
 400500, 8,
 400501, 4,
 0, 0,
 0, 0,
 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'The Sunken Temple Awakens',
 'The ancient temple in the Giant Isles has stirred. Atal\'ai cultists once sealed within have reawakened and are performing dark rituals to resurrect their blood god, Hakkar. Scholar Zal\'ira needs you to break their outer ranks and thin the cultist numbers.',
 'Scholar Zal\'ira says: "The seals have broken — Hakkar\'s servants walk again. Slay their warriors and witch doctors that surround the temple entrance. Prove you can handle what lies within."',
 'Giant Isles — Temple of Atal\'Hakkar',
 'You have disrupted the outer rituals. Report back to Scholar Zal\'ira.',
 12340),

-- 82001: "The Four Bloodseekers" — kill sub-bosses
(82001, 2, 80, 80, 5006, 81,
 5, 5, 200000, 0,
 0, 0, 8,
 400510, 1,
 400511, 1,
 400512, 1,
 400513, 1,
 0, 0,
 402001, 1, 402002, 1, 402003, 1, 402004, 1, 402005, 1,
 'The Four Bloodseekers',
 'Four elite Atal\'ai champions — the Bloodseekers — conduct the rite of summoning deep within the temple. Their deaths will break the ritual circle and prevent Jammal\'an from fully manifesting.',
 'Scholar Zal\'ira says: "Zul\'kar the Flayer, Seer Mazra, Bone Weaver Zolo, and Soul Raker Mijan hold the four corners of the ritual circle. End them."',
 'Giant Isles — Temple of Atal\'Hakkar (interior)',
 'All four Bloodseekers are slain. Return to Scholar Zal\'ira.',
 12340),

-- 82002: "The Eternal Prophet" — kill Jammal'an + collect 3 idol shards
(82002, 2, 80, 80, 5006, 81,
 5, 5, 250000, 0,
 0, 0, 8,
 400521, 1,
 0, 0,
 0, 0,
 0, 0,
 402000, 3,
 402006, 1, 402007, 1, 402008, 1, 402009, 1, 402010, 1,
 'The Eternal Prophet',
 'Jammal\'an the Eternal has manifested at the heart of the temple. He channels Hakkar\'s power through three idol shards still lodged in the temple walls. Destroy him and recover the shards to sever the connection.',
 'Scholar Zal\'ira says: "Jammal\'an draws power from the idol fragments scattered throughout the inner sanctum. Kill him and bring me three Idol Fragments of Hakkar so they can be sanctified and destroyed."',
 'Giant Isles — Temple of Atal\'Hakkar (inner sanctum)',
 'You have slain Jammal\'an the Eternal and recovered the idol fragments. Return to Scholar Zal\'ira.',
 12340),

-- 82003: "Hakkar Must Not Rise" — kill the Avatar
(82003, 2, 80, 80, 5006, 81,
 5, 5, 350000, 0,
 0, 0, 8,
 400522, 1,
 0, 0,
 0, 0,
 0, 0,
 0, 0,
 402011, 1, 402012, 1, 402013, 1, 402014, 1, 402015, 1,
 'Hakkar Must Not Rise',
 'The Reawakened Avatar of Hakkar writhes in the deepest sanctum. Fed by the idol fragments and the blood of the slain, the blood god has partially manifested. Destroy the avatar before it grows powerful enough to break free of the temple.',
 'Scholar Zal\'ira says: "What you carry allows you to enter the inner sanctum. The avatar is powerful beyond measure — rally who you can and strike it down before it consumes everything."',
 'Giant Isles — Temple of Atal\'Hakkar (sanctum of blood)',
 'The avatar is destroyed. Return to Scholar Zal\'ira.',
 12340),

-- 82004: "Nightmare in the Deep" — standalone optional quest (Shade of Eranikus)
(82004, 2, 80, 80, 5006, 81,
 5, 5, 200000, 0,
 0, 0, 8,
 400523, 1,
 0, 0,
 0, 0,
 0, 0,
 0, 0,
 402016, 1, 402017, 1, 402018, 1, 402019, 1, 402020, 1,
 'Nightmare in the Deep',
 'The Ancient Shade of Eranikus, a green dragon tormented for centuries in Hakkar\'s nightmare realm, has been drawn to the temple by the awakened rituals. Though a prisoner of nightmare himself, his power makes him deadly. Some say releasing him from his torment would be a mercy.',
 'Scholar Zal\'ira says: "I sense a dragon\'s essence deep within — the shade of Eranikus, lost in nightmare for ages. The ritual\'s reawakening has stirred him to madness. He must be put to rest."',
 'Giant Isles — Temple of Atal\'Hakkar (dragon\'s lair)',
 'The shade of Eranikus is at rest. Return to Scholar Zal\'ira.',
 12340),

-- 82005: Daily "Atal'ai Offerings" — daily kill quest
(82005, 2, 80, 80, 5006, 81,
 5, 5, 120000, 0,
 0, 0, 4104,
 400500, 6,
 400501, 6,
 0, 0,
 0, 0,
 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Atal\'ai Offerings',
 'The awakened Atal\'ai continue performing blood rites outside the temple each day. Their numbers must be kept in check to prevent a surge powerful enough to break the outer seals entirely.',
 'Scholar Zal\'ira says: "Every day they attempt new offerings to Hakkar. Slay their warriors and witch doctors — thin the numbers and disrupt the daily rite. I will reward you for your vigilance."',
 'Giant Isles — Temple of Atal\'Hakkar (exterior)',
 'The daily offerings are disrupted. Report back to Scholar Zal\'ira.',
 12340);

-- ============================================================================
-- 15b. QUEST OFFER REWARD / REQUEST ITEMS TEXT (82000–82005)
-- ============================================================================
INSERT INTO `quest_offer_reward` (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`RewardText`,`VerifiedBuild`) VALUES
(82000,0,0,0,0,0,0,0,0,'"You have thinned their outer ranks. But their leaders — the Four Bloodseekers — still conduct the ritual within. They must be stopped before Jammal\'an can be summoned."',12340),
(82001,0,0,0,0,0,0,0,0,'"Four champions fall. Yet the ritual fire still burns — Jammal\'an has already taken form. You must face the eternal prophet himself, and bring me proof of his final death: three shards of Hakkar\'s shattered idol."',12340),
(82002,0,0,0,0,0,0,0,0,'"The prophet is silenced — but the idol fragments you carry still pulse with Hakkar\'s hunger. The Avatar itself stirs in the deepest chamber. You must end this now."',12340),
(82003,0,0,0,0,0,0,0,0,'"You have done the impossible. The blood god\'s avatar is shattered. The temple\'s seals will hold for another age. Take this — you have earned it."',12340),
(82004,0,0,0,0,0,0,0,0,'"The nightmare wyrm is finally at peace. May Eranikus find rest beyond the dream. Take this trinket as a token of what he once was — powerful and noble."',12340),
(82005,0,0,0,0,0,0,0,0,'"Well done — the daily rite is broken. Return tomorrow and we shall do it again."',12340);

INSERT INTO `quest_request_items` (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`) VALUES
(82000,0,0,'"The cultists are still active. You must slay 8 Awakened Atal\'ai Warriors and 4 Awakened Atal\'ai Witch Doctors."',12340),
(82001,0,0,'"The four Bloodseekers still live. Slay them all before returning."',12340),
(82002,0,0,'"Jammal\'an still breathes and you are missing idol fragments. Do not return until both tasks are done."',12340),
(82003,0,0,'"The blood god still stirs in the depths. Kill the avatar and return when it is done."',12340),
(82004,0,0,'"The shade of Eranikus still haunts the deep passages. It must be ended."',12340),
(82005,0,0,'"The cultists still gather. Slay 6 warriors and 6 witch doctors before you return."',12340);

-- ============================================================================
-- 16. QUEST CHAIN LINKS (quest_template_addon)
-- ============================================================================
INSERT INTO `quest_template_addon`
    (`ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,
     `ExclusiveGroup`,`BreadcrumbForQuestId`,`RewardMailTemplateID`,`RewardMailDelay`,
     `RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,
     `RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`)
VALUES
(82000, 0, 0, 0, 0, 0,        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82001, 0, 0, 0, 82000, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82002, 0, 0, 0, 82001, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82003, 0, 0, 0, 82002, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82004, 0, 0, 0, 0, 0,         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82005, 0, 0, 0, 0, 0,         0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

-- Chain quest auto-offer: completing 82000 auto-offers 82001, etc.
UPDATE `quest_template` SET `RewardNextQuest` = 82001 WHERE `ID` = 82000;
UPDATE `quest_template` SET `RewardNextQuest` = 82002 WHERE `ID` = 82001;
UPDATE `quest_template` SET `RewardNextQuest` = 82003 WHERE `ID` = 82002;

-- ============================================================================
-- 17. QUEST STARTERS / ENDERS
-- Scholar Zal'ira (400525) gives and ends all quests.
-- ============================================================================
INSERT INTO `creature_queststarter` (`id`,`quest`) VALUES
(400525, 82000),
(400525, 82001),
(400525, 82002),
(400525, 82003),
(400525, 82004),
(400525, 82005);

INSERT INTO `creature_questender` (`id`,`quest`) VALUES
(400525, 82000),
(400525, 82001),
(400525, 82002),
(400525, 82003),
(400525, 82004),
(400525, 82005);

-- ============================================================================
-- 18. LOOT TABLES
-- ============================================================================

-- -- Boss reference loot pool (14132): general temple epic/rare drops
INSERT INTO `reference_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`) VALUES
(14132, 402021, 0,  8, 0, 1, 0, 1, 1, 'Hakkar\'s Eternal Seal (epic ring)'),
(14132, 402022, 0,  8, 0, 1, 0, 1, 1, 'Dreamscale Amulet of Eranikus (epic neck)'),
(14132, 402001, 0, 10, 0, 1, 0, 1, 1, 'Shard of Hakkar\'s Vision (ring)'),
(14132, 402003, 0, 10, 0, 1, 0, 1, 1, 'Shard of Hakkar\'s Fang (ring)'),
(14132, 402006, 0, 10, 0, 1, 0, 1, 1, 'Idol-Bound Sage\'s Pendant (neck)'),
(14132, 402008, 0, 10, 0, 1, 0, 1, 1, 'Idol-Bound Hunter\'s Chain (neck)');

-- creature_loot_template for 400500-400523 (idol fragments, boss pools): moved to the dungeon copy SQL

-- ============================================================================
-- 19. FACTION QUEST GIVERS (entries 400526–400527)
-- Alliance: Sentinel Liriel (400526, faction 12) — Night Elf Warden
-- Horde: Shadow Priest Mokra (400527, faction 29) — Troll Shadow Agent
-- Place with .npc add <entry> in-game; no spawn rows here per design.
-- ============================================================================
DELETE FROM `creature_template` WHERE `entry` IN (400526, 400527);

INSERT INTO `creature_template`
    (`entry`,`difficulty_entry_1`,`difficulty_entry_2`,`difficulty_entry_3`,
     `KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,
     `minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,
     `speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`detection_range`,`rank`,`dmgschool`,`DamageModifier`,
     `BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,
     `unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,
     `lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,
     `mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,
     `HealthModifier`,`ManaModifier`,`ArmorModifier`,`ExperienceModifier`,
     `RacialLeader`,`movementId`,`RegenHealth`,`CreatureImmunitiesId`,
     `flags_extra`,`ScriptName`,`VerifiedBuild`)
VALUES
(400526,0,0,0,0,0,'Sentinel Liriel','Alliance Warden','Speak',0,
 80,80,2,12,3,
 1.0,1.14286,1.0,1.0,20.0,0,0,1.0,
 2000,2000,1,1,
 1,768,2048,0,0,7,0,
 0,0,0,0,0,
 0,0,'',0,1,
 10,1,1,1,
 0,0,1,0,
 2,'',12340),
(400527,0,0,0,0,0,'Shadow Priest Mokra','Horde Shadow Agent','Speak',0,
 80,80,2,29,3,
 1.0,1.14286,1.0,1.0,20.0,0,0,1.0,
 2000,2000,1,1,
 1,768,2048,0,0,7,0,
 0,0,0,0,0,
 0,0,'',0,1,
 10,1,1,1,
 0,0,1,0,
 2,'',12340);

DELETE FROM `creature_template_model` WHERE `CreatureID` IN (400526, 400527);
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400526, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 12340 FROM `creature_template_model` WHERE `CreatureID` = 2155 LIMIT 1; -- Sentinel Shayla Nightbreeze
INSERT INTO `creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`)
SELECT 400527, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, 12340 FROM `creature_template_model` WHERE `CreatureID` = 660 LIMIT 1; -- Bloodscalp Witch Doctor (Troll)

-- ============================================================================
-- 20. FACTION WRIST REWARDS (402023–402024) — ilvl 285, req 80
-- Alliance: Sentinel's Atal'ai Bracers (caster/versatile)
-- Horde:    Blooded Hunter's Vambraces  (physical DPS)
-- ============================================================================
DELETE FROM `item_template` WHERE `entry` IN (402023, 402024);
INSERT INTO `item_template`
    (`entry`,`class`,`subclass`,`SoundOverrideSubclass`,`name`,
     `displayid`,`Quality`,`Flags`,`FlagsExtra`,`BuyCount`,`BuyPrice`,
     `SellPrice`,`InventoryType`,`AllowableClass`,`AllowableRace`,
     `ItemLevel`,`RequiredLevel`,`maxcount`,`stackable`,`ContainerSlots`,
     `stat_type1`,`stat_value1`,`stat_type2`,`stat_value2`,
     `stat_type3`,`stat_value3`,`stat_type4`,`stat_value4`,
     `stat_type5`,`stat_value5`,`armor`,`bonding`,`description`,`VerifiedBuild`)
VALUES
(402023, 4, 0, -1, 'Sentinel\'s Atal\'ai Bracers',
    52232, 3, 0, 0, 1, 0, 60000, 9, -1, -1, 285, 80, 0, 1, 0,
    45,73,  7,52,  5,52,  32,46,  36,39,  0, 1, 'Blessed by a Night Elf warden before entering the sunken temple.', 0),
(402024, 4, 0, -1, 'Blooded Hunter\'s Vambraces',
    53002, 3, 0, 0, 1, 0, 60000, 9, -1, -1, 285, 80, 0, 1, 0,
    38,80,  3,68,  7,68,  32,46,  37,39,  0, 1, 'Stained with the blood of troll cultists.', 0);

-- ============================================================================
-- 21. FACTION QUEST CHAINS (82010–82015)
-- Alliance chain: 82010 (intro) → 82011 (kill Avatar), AllowableRaces 102763597
-- Horde chain:    82012 (intro) → 82013 (kill Avatar), AllowableRaces 29361330
-- Daily quests:   82014 (Alliance), 82015 (Horde)
-- AllowableRaces bitmask: Alliance=102763597 (1101 + Worgen 12 + races 22/26/27),
-- Horde=29361330 (690 + Goblin 9 + races 23/24/25)
-- ============================================================================
DELETE FROM `quest_template` WHERE `ID` BETWEEN 82010 AND 82015;
INSERT INTO `quest_template`
    (`ID`,`QuestType`,`QuestLevel`,`MinLevel`,`QuestSortID`,`QuestInfoID`,
     `SuggestedGroupNum`,`RewardXPDifficulty`,`RewardMoney`,`RewardMoneyDifficulty`,
     `RewardDisplaySpell`,`RewardSpell`,`Flags`,
     `RequiredNpcOrGo1`,`RequiredNpcOrGoCount1`,
     `RequiredNpcOrGo2`,`RequiredNpcOrGoCount2`,
     `RequiredNpcOrGo3`,`RequiredNpcOrGoCount3`,
     `RequiredNpcOrGo4`,`RequiredNpcOrGoCount4`,
     `RequiredItemId1`,`RequiredItemCount1`,
     `RewardChoiceItemID1`,`RewardChoiceItemQuantity1`,
     `RewardChoiceItemID2`,`RewardChoiceItemQuantity2`,
     `RewardChoiceItemID3`,`RewardChoiceItemQuantity3`,
     `RewardChoiceItemID4`,`RewardChoiceItemQuantity4`,
     `RewardChoiceItemID5`,`RewardChoiceItemQuantity5`,
     `LogTitle`,`LogDescription`,`QuestDescription`,`AreaDescription`,`QuestCompletionLog`,
     `VerifiedBuild`)
VALUES
-- 82010: Alliance intro — kill 8 warriors + 4 witch doctors
(82010, 2, 80, 80, 5006, 81,
 5, 5, 150000, 0,
 0, 0, 8,
 400500, 8,
 400501, 4,
 0, 0,
 0, 0,
 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Zeal of the Alliance',
 'The Alliance has dispatched Sentinel Liriel to investigate the reawakened Temple of Atal\'Hakkar on the Giant Isles. Before entering, you must prove your worth by thinning the outer cultist forces.',
 'Sentinel Liriel says: "I have tracked the cult\'s resurgence here for weeks. Slay their outer wardens and casters — show me you are prepared for what lies within."',
 'Giant Isles — Temple of Atal\'Hakkar',
 'You have proven your mettle. Report back to Sentinel Liriel.',
 12340),
-- 82011: Alliance final — kill Avatar, reward bracers 402023
(82011, 2, 80, 80, 5006, 81,
 5, 5, 350000, 0,
 0, 0, 8,
 400522, 1,
 0, 0,
 0, 0,
 0, 0,
 0, 0,
 402023, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Blood God\'s Downfall',
 'The Reawakened Avatar of Hakkar lurks in the deepest sanctum, fed by the rites of the Atal\'ai cult. The Alliance cannot allow this blood-god corruption to fester on the Giant Isles. End the avatar\'s existence.',
 'Sentinel Liriel says: "The avatar must not be allowed to fully manifest. Rally your companions and descend into the sanctum. Destroy the Reawakened Avatar of Hakkar — for the Alliance, and for this island\'s future."',
 'Giant Isles — Temple of Atal\'Hakkar (sanctum of blood)',
 'The blood god\'s avatar is destroyed. Return to Sentinel Liriel.',
 12340),
-- 82012: Horde intro — kill 8 warriors + 4 witch doctors
(82012, 2, 80, 80, 5006, 81,
 5, 5, 150000, 0,
 0, 0, 8,
 400500, 8,
 400501, 4,
 0, 0,
 0, 0,
 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Strength of the Horde',
 'Shadow Priest Mokra has infiltrated the Giant Isles on behalf of the Horde to study — and if possible, contain — the reawakened Atal\'ai cult. Before entering the temple, demonstrate the Horde\'s power against the outer cultists.',
 'Shadow Priest Mokra says: "The Atal\'ai were once powerful shadow channelers. Now they are tools of a dead god. Crush their outer ranks and show them the Horde\'s shadow is darker than Hakkar\'s blood."',
 'Giant Isles — Temple of Atal\'Hakkar',
 'You have crushed the outer cultists. Report back to Shadow Priest Mokra.',
 12340),
-- 82013: Horde final — kill Avatar, reward bracers 402024
(82013, 2, 80, 80, 5006, 81,
 5, 5, 350000, 0,
 0, 0, 8,
 400522, 1,
 0, 0,
 0, 0,
 0, 0,
 0, 0,
 402024, 1, 0, 0, 0, 0, 0, 0, 0, 0,
 'Claim the God\'s Trophy',
 'The Reawakened Avatar of Hakkar is a prize worthy of the Horde\'s strongest warriors. Descend into the temple\'s deepest sanctum, destroy the avatar, and claim your trophy.',
 'Shadow Priest Mokra says: "The blood god thinks itself mighty. Let us prove otherwise. Kill the avatar — not for the Light, not for some ancient pact — but because the Horde suffers no gods on its lands."',
 'Giant Isles — Temple of Atal\'Hakkar (sanctum of blood)',
 'The avatar of Hakkar is destroyed. Return to Shadow Priest Mokra.',
 12340),
-- 82014: Alliance daily — kill 6 warriors + 6 witch doctors
(82014, 2, 80, 80, 5006, 81,
 5, 5, 90000, 0,
 0, 0, 4104,
 400500, 6,
 400501, 6,
 0, 0,
 0, 0,
 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Sentinel\'s Vigil',
 'Each day the Atal\'ai cult performs new blood rites at the temple entrance, reinforcing their hold on the ruins. Sentinel Liriel needs the daily rituals disrupted to keep them from reconsecrating the outer temple.',
 'Sentinel Liriel says: "They renew their blood rituals at dawn. Return each day and cut down their outer guard — it keeps them weakened and denies Hakkar\'s presence from spreading beyond the temple walls."',
 'Giant Isles — Temple of Atal\'Hakkar (exterior)',
 'The daily ritual is broken. Report back to Sentinel Liriel.',
 12340),
-- 82015: Horde daily — kill 6 warriors + 6 witch doctors
(82015, 2, 80, 80, 5006, 81,
 5, 5, 90000, 0,
 0, 0, 4104,
 400500, 6,
 400501, 6,
 0, 0,
 0, 0,
 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 'Horde Blood Tribute',
 'Each morning the Atal\'ai cultists perform new blood tributes to Hakkar. Shadow Priest Mokra wants them disrupted daily — partly to weaken the cult, and partly to deny their shadow magic from building toward another summoning.',
 'Shadow Priest Mokra says: "I want their daily tribute interrupted. Go bleed their outer guards every morning — don\'t let them rebuild momentum. The shadow priests of the Horde are watching this temple closely."',
 'Giant Isles — Temple of Atal\'Hakkar (exterior)',
 'The blood tribute is disrupted. Report back to Shadow Priest Mokra.',
 12340);

-- Race locks applied via UPDATE (AllowableRaces default=0 = unrestricted)
UPDATE `quest_template` SET `AllowableRaces` = 102763597 WHERE `ID` IN (82010, 82011, 82014);
UPDATE `quest_template` SET `AllowableRaces` = 29361330 WHERE `ID` IN (82012, 82013, 82015);

-- ============================================================================
-- 21b. FACTION QUEST OFFER REWARD / REQUEST ITEMS TEXT (82010–82015)
-- ============================================================================
DELETE FROM `quest_offer_reward`  WHERE `ID` BETWEEN 82010 AND 82015;
DELETE FROM `quest_request_items` WHERE `ID` BETWEEN 82010 AND 82015;

INSERT INTO `quest_offer_reward` (`ID`,`Emote1`,`Emote2`,`Emote3`,`Emote4`,`EmoteDelay1`,`EmoteDelay2`,`EmoteDelay3`,`EmoteDelay4`,`RewardText`,`VerifiedBuild`) VALUES
(82010,0,0,0,0,0,0,0,0,'"Well fought, soldier. The inner temple holds far greater threats. We cannot let Hakkar\'s essence grow any stronger — follow me."',12340),
(82011,0,0,0,0,0,0,0,0,'"You have done the Light\'s work this day. The cult\'s hold on this temple is broken. Accept these bracers — crafted by our wardens and blessed for this very campaign."',12340),
(82012,0,0,0,0,0,0,0,0,'"Ha! They broke like dry bones. But the real power is deeper inside — the blood god\'s avatar calls to the shadow. We must silence it before it grows beyond our control."',12340),
(82013,0,0,0,0,0,0,0,0,'"That\'s what I like to see — a real kill. These vambraces are yours — taken from the cult\'s finest before we found this island. Wear them with pride."',12340),
(82014,0,0,0,0,0,0,0,0,'"Well done. Return tomorrow — the cult will have replaced them by then. Vigilance never ends."',12340),
(82015,0,0,0,0,0,0,0,0,'"Good. Now get out of here and come back tomorrow. The cult replenishes like a wound — it needs constant pressure."',12340);

INSERT INTO `quest_request_items` (`ID`,`EmoteOnComplete`,`EmoteOnIncomplete`,`CompletionText`,`VerifiedBuild`) VALUES
(82010,0,0,'"You must slay 8 Awakened Atal\'ai Warriors and 4 Awakened Atal\'ai Witch Doctors before returning."',12340),
(82011,0,0,'"The avatar still stirs in the depths. Do not return until Hakkar\'s form is truly destroyed."',12340),
(82012,0,0,'"The outer guards must fall first. Slay 8 warriors and 4 witch doctors, then return."',12340),
(82013,0,0,'"The avatar still lives. The Horde doesn\'t celebrate half-victories. Come back when it\'s dead."',12340),
(82014,0,0,'"The daily ritual still continues. Slay 6 warriors and 6 witch doctors before reporting back."',12340),
(82015,0,0,'"Their daily tribute must be stopped. Slay 6 warriors and 6 witch doctors first."',12340);

-- ============================================================================
-- 22. FACTION QUEST CHAIN LINKS (quest_template_addon)
-- ============================================================================
DELETE FROM `quest_template_addon` WHERE `ID` BETWEEN 82010 AND 82015;
INSERT INTO `quest_template_addon`
    (`ID`,`MaxLevel`,`AllowableClasses`,`SourceSpellID`,`PrevQuestID`,`NextQuestID`,
     `ExclusiveGroup`,`BreadcrumbForQuestId`,`RewardMailTemplateID`,`RewardMailDelay`,
     `RequiredSkillID`,`RequiredSkillPoints`,`RequiredMinRepFaction`,`RequiredMaxRepFaction`,
     `RequiredMinRepValue`,`RequiredMaxRepValue`,`ProvidedItemCount`,`SpecialFlags`)
VALUES
(82010, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82011, 0, 0, 0, 82010, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82012, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82013, 0, 0, 0, 82012, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
(82014, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1),
(82015, 0, 0, 0, 0, 0,     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);

-- Auto-offer completing intro quests → final quests
UPDATE `quest_template` SET `RewardNextQuest` = 82011 WHERE `ID` = 82010;
UPDATE `quest_template` SET `RewardNextQuest` = 82013 WHERE `ID` = 82012;

-- ============================================================================
-- 23. FACTION QUEST STARTERS / ENDERS
-- Sentinel Liriel (400526): quests 82010, 82011, 82014
-- Shadow Priest Mokra (400527): quests 82012, 82013, 82015
-- ============================================================================
DELETE FROM `creature_queststarter` WHERE `id` IN (400526, 400527);
DELETE FROM `creature_questender`   WHERE `id` IN (400526, 400527);

INSERT INTO `creature_queststarter` (`id`,`quest`) VALUES
(400526, 82010), (400526, 82011), (400526, 82014),
(400527, 82012), (400527, 82013), (400527, 82015);

INSERT INTO `creature_questender` (`id`,`quest`) VALUES
(400526, 82010), (400526, 82011), (400526, 82014),
(400527, 82012), (400527, 82013), (400527, 82015);

-- ============================================================================
-- 24. ACHIEVEMENT CRITERIA DATA
-- ACHIEVEMENT_CRITERIA_TYPE_KILL_CREATURE (DBC type 0) requires at least one
-- row in achievement_criteria_data or the server logs an error on startup.
-- type=0 here means no extra condition — the kill itself satisfies the criteria.
-- Achievement DBC rows live in Custom/CSV DBC/Achievement.csv (IDs 60043–60047).
-- ============================================================================
DELETE FROM `achievement_criteria_data` WHERE `criteria_id` IN (
    13496, 13497, 13498, 13499,   -- Blood Seeker (60043)
    13500,                         -- The Prophet Falls (60044)
    13501,                         -- No Blood God Today (60045)
    13502,                         -- Laid to Rest (60046)
    13503, 13504, 13505            -- Temple Cleared (60047)
);

INSERT INTO `achievement_criteria_data` (`criteria_id`, `type`, `value1`, `value2`, `ScriptName`) VALUES
-- Blood Seeker (60043): slay all 4 Bloodseekers
(13496, 0, 0, 0, ''),  -- Zul'kar the Flayer     (400510)
(13497, 0, 0, 0, ''),  -- Seer Mazra              (400511)
(13498, 0, 0, 0, ''),  -- Bone Weaver Zolo        (400512)
(13499, 0, 0, 0, ''),  -- Soul Raker Mijan        (400513)
-- The Prophet Falls (60044): kill Jammal'an the Eternal
(13500, 0, 0, 0, ''),  -- Jammal'an the Eternal   (400521)
-- No Blood God Today (60045): kill Reawakened Avatar of Hakkar
(13501, 0, 0, 0, ''),  -- Avatar of Hakkar        (400522)
-- Laid to Rest (60046): kill Ancient Shade of Eranikus
(13502, 0, 0, 0, ''),  -- Ancient Shade of Eranikus (400523)
-- Temple Cleared (60047): kill all 3 bosses
(13503, 0, 0, 0, ''),  -- Atal'alarion the Eternal (400520)
(13504, 0, 0, 0, ''),  -- Jammal'an the Eternal   (400521)
(13505, 0, 0, 0, '');  -- Reawakened Avatar of Hakkar (400522)
