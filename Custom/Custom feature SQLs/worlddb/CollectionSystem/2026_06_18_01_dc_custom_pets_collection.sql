-- DC-Collection: register 48 custom pets + schema update for color variant grouping
--
-- Adds variant_group / variant_color to dc_pet_definitions so the Collection
-- addon can display color-variant families as a single grouped card with
-- color swatches (see "Color Variant Design" section at bottom of file).
--
-- All item/spell/creature cross-references match 2026_06_18_02_dc_custom_pets.sql

-- ============================================================
-- 1. SCHEMA: add variant columns to dc_pet_definitions
--    Run once. IF NOT EXISTS is MariaDB-only; these are plain MySQL ALTER TABLEs.
--    On re-run they error with "Duplicate column name" — safe to ignore.
-- ============================================================

ALTER TABLE `dc_pet_definitions`
    ADD COLUMN `variant_group`
        VARCHAR(50) DEFAULT NULL
        COMMENT 'Groups color-variant pets under one family in the Collection UI'
        AFTER `flags`;

ALTER TABLE `dc_pet_definitions`
    ADD COLUMN `variant_color`
        VARCHAR(30) DEFAULT NULL
        COMMENT 'Human-readable color label for this variant (e.g. Gold, Blue)'
        AFTER `variant_group`;

-- ============================================================
-- 2. DC_PET_DEFINITIONS  (48 rows)
--
-- source JSON mirrors the vendor NPC pattern from brontosaur SQL.
-- display_id maps to CreatureDisplayInfo ID (for 3D preview).
-- variant_group/variant_color set only for multi-skin pets.
-- ============================================================

DELETE FROM `dc_pet_definitions` WHERE `pet_entry` IN (
    300412,300413,300414,300415,300416,300417,300418,300419,300420,300421,
    300422,300423,300424,300425,300426,300427,300428,300429,300430,300431,
    300432,300433,300434,300435,300436,300437,300438,300439,300440,300441,
    300442,300443,300444,300445,300446,300447,300448,300449,300450,300451,
    300452,300453,300454,300455,300456,300457,300458,300459
);

INSERT INTO `dc_pet_definitions`
    (`pet_entry`,`name`,`pet_type`,`pet_spell_id`,`source`,`faction`,`display_id`,
     `icon`,`rarity`,`expansion`,`flags`,`variant_group`,`variant_color`)
VALUES
-- # 1   Aether Serpent  Rare 3
(300412,'Aether Serpent','companion',300742,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300412,"creatureEntry":3461230}',
 0,500671,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 2   Azmeroth Murloc  Rare 3
(300413,'Azmeroth Murloc','companion',300743,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300413,"creatureEntry":3461231}',
 0,500672,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 3   Baby Demon  Epic 4
(300414,'Baby Demon','companion',300744,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300414,"creatureEntry":3461232}',
 0,500673,'INV_Box_PetCarrier_01',4,2,0,NULL,NULL),
-- # 4   Maldraxxus Bat  Uncommon 2
(300415,'Maldraxxus Bat','companion',300745,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300415,"creatureEntry":3461233}',
 0,500674,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 5   Revendreth Bat  Uncommon 2
(300416,'Revendreth Bat','companion',300746,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300416,"creatureEntry":3461234}',
 0,500675,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 6   Primal Beaver  Uncommon 2
(300417,'Primal Beaver','companion',300747,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300417,"creatureEntry":3461235}',
 0,500676,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 7   Blood Louse  Uncommon 2
(300418,'Blood Louse','companion',300748,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300418,"creatureEntry":3461236}',
 0,500677,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 8   Caterpillar Larva  Uncommon 2
(300419,'Caterpillar Larva','companion',300749,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300419,"creatureEntry":3461237}',
 0,500678,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 9   Corn Stalk  Uncommon 2
(300420,'Corn Stalk','companion',300750,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300420,"creatureEntry":3461238}',
 0,500679,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 10  Golden Dog  Rare 3
(300421,'Golden Dog','companion',300751,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300421,"creatureEntry":3461239}',
 0,500680,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 11  Eye of N'Zoth  Epic 4
(300422,'Eye of N\'Zoth','companion',300752,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300422,"creatureEntry":3461240}',
 0,500681,'INV_Box_PetCarrier_01',4,2,0,NULL,NULL),
-- # 12  Fox Wyvern  Rare 3
(300423,'Fox Wyvern','companion',300753,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300423,"creatureEntry":3461241}',
 0,500682,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 13  Future Bot  Rare 3
(300424,'Future Bot','companion',300754,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300424,"creatureEntry":3461242}',
 0,500683,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 14  Gnome Toy  Uncommon 2
(300425,'Gnome Toy','companion',300755,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300425,"creatureEntry":3461243}',
 0,500684,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 15  Harvest Golem  Uncommon 2
(300426,'Harvest Golem','companion',300756,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300426,"creatureEntry":3461244}',
 0,500685,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 16  Kodo Calf  Uncommon 2
(300427,'Kodo Calf','companion',300757,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300427,"creatureEntry":3461245}',
 0,500686,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 17  Lunar Rabbit  Rare 3
(300428,'Lunar Rabbit','companion',300758,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300428,"creatureEntry":3461246}',
 0,500687,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 18  Magical Fish  Rare 3
(300429,'Magical Fish','companion',300759,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300429,"creatureEntry":3461247}',
 0,500688,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 19  Mammoth Calf  Uncommon 2
(300430,'Mammoth Calf','companion',300760,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300430,"creatureEntry":3461248}',
 0,500689,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 20-22  Marmoset x3  Rare 3  variant_group='marmoset_pet'
(300431,'Marmoset (Grey)','companion',300761,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300431,"creatureEntry":3461249}',
 0,500690,'INV_Box_PetCarrier_01',3,2,0,'marmoset_pet','Grey'),
(300432,'Marmoset (Brown)','companion',300762,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300432,"creatureEntry":3461250}',
 0,500691,'INV_Box_PetCarrier_01',3,2,0,'marmoset_pet','Brown'),
(300433,'Marmoset (White)','companion',300763,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300433,"creatureEntry":3461251}',
 0,500692,'INV_Box_PetCarrier_01',3,2,0,'marmoset_pet','White'),
-- # 23  Maw Guard Pup  Rare 3
(300434,'Maw Guard Pup','companion',300764,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300434,"creatureEntry":3461252}',
 0,500693,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 24  Mechagon Construct  Rare 3
(300435,'Mechagon Construct','companion',300765,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300435,"creatureEntry":3461253}',
 0,500694,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 25  Mummy  Rare 3
(300436,'Mummy','companion',300766,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300436,"creatureEntry":3461254}',
 0,500695,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 26  Ogre Pup  Rare 3
(300437,'Ogre Pup','companion',300767,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300437,"creatureEntry":3461255}',
 0,500696,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 27  Owl  Uncommon 2
(300438,'Owl','companion',300768,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300438,"creatureEntry":3461256}',
 0,500697,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 28  Phoenix Hatchling  Epic 4
(300439,'Phoenix Hatchling','companion',300769,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300439,"creatureEntry":3461257}',
 0,500698,'INV_Box_PetCarrier_01',4,2,0,NULL,NULL),
-- # 29  Pit Lord Spawn  Epic 4
(300440,'Pit Lord Spawn','companion',300770,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300440,"creatureEntry":3461258}',
 0,500699,'INV_Box_PetCarrier_01',4,2,0,NULL,NULL),
-- # 30  Progenitor Bot  Rare 3
(300441,'Progenitor Bot','companion',300771,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300441,"creatureEntry":3461259}',
 0,500700,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 31  Progenitor Worm  Rare 3
(300442,'Progenitor Worm','companion',300772,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300442,"creatureEntry":3461260}',
 0,500701,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 32-35  Celestial Quilin x4  Legendary 5  variant_group='quilin_celestial'
(300443,'Celestial Quilin (Gold)','companion',300773,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300443,"creatureEntry":3461261}',
 0,500702,'INV_Box_PetCarrier_01',5,2,0,'quilin_celestial','Gold'),
(300444,'Celestial Quilin (Blue)','companion',300774,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300444,"creatureEntry":3461262}',
 0,500703,'INV_Box_PetCarrier_01',5,2,0,'quilin_celestial','Blue'),
(300445,'Celestial Quilin (Green)','companion',300775,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300445,"creatureEntry":3461263}',
 0,500704,'INV_Box_PetCarrier_01',5,2,0,'quilin_celestial','Green'),
(300446,'Celestial Quilin (Purple)','companion',300776,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300446,"creatureEntry":3461264}',
 0,500705,'INV_Box_PetCarrier_01',5,2,0,'quilin_celestial','Purple'),
-- # 36  Goblin Companion  Uncommon 2
(300447,'Goblin Companion','companion',300777,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300447,"creatureEntry":3461265}',
 0,500706,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 37-38  Sha x2  Legendary 5  variant_group='sha_pet'
(300448,'Sha Manifestation','companion',300778,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300448,"creatureEntry":3461266}',
 0,500707,'INV_Box_PetCarrier_01',5,2,0,'sha_pet','Dark'),
(300449,'Sha Manifestation (Light)','companion',300779,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300449,"creatureEntry":3461267}',
 0,500708,'INV_Box_PetCarrier_01',5,2,0,'sha_pet','Light'),
-- # 39  Sinstone Golem  Rare 3
(300450,'Sinstone Golem','companion',300780,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300450,"creatureEntry":3461268}',
 0,500709,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 40  Skeleton Hand  Rare 3
(300451,'Skeleton Hand','companion',300781,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300451,"creatureEntry":3461269}',
 0,500710,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 41  Skeleton Spine  Rare 3
(300452,'Skeleton Spine','companion',300782,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300452,"creatureEntry":3461270}',
 0,500711,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 42  Storm Gryphon  Rare 3
(300453,'Storm Gryphon','companion',300783,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300453,"creatureEntry":3461271}',
 0,500712,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 43  Survey Bot  Uncommon 2
(300454,'Survey Bot','companion',300784,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300454,"creatureEntry":3461272}',
 0,500713,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 44  Swamp Crawler  Uncommon 2
(300455,'Swamp Crawler','companion',300785,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300455,"creatureEntry":3461273}',
 0,500714,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 45  Tree Sprite  Uncommon 2
(300456,'Tree Sprite','companion',300786,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300456,"creatureEntry":3461274}',
 0,500715,'INV_Box_PetCarrier_01',2,2,0,NULL,NULL),
-- # 46  Wicker Beast  Rare 3
(300457,'Wicker Beast','companion',300787,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300457,"creatureEntry":3461275}',
 0,500716,'INV_Box_PetCarrier_01',3,2,0,NULL,NULL),
-- # 47  Winged Lion  Epic 4
(300458,'Winged Lion','companion',300788,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300458,"creatureEntry":3461276}',
 0,500717,'INV_Box_PetCarrier_01',4,2,0,NULL,NULL),
-- # 48  Wood Dragon  Epic 4
(300459,'Wood Dragon','companion',300789,
 '{"type":"vendor","npc":"Skeletal Petkeeper","npcEntry":3461229,"itemId":300459,"creatureEntry":3461277}',
 0,500718,'INV_Box_PetCarrier_01',4,2,0,NULL,NULL);

-- ============================================================
-- 3. DC_COLLECTION_DEFINITIONS  (collection_type=2 = Pets)
-- ============================================================

DELETE FROM `dc_collection_definitions`
WHERE `collection_type` = 2
  AND `entry_id` IN (
    300412,300413,300414,300415,300416,300417,300418,300419,300420,300421,
    300422,300423,300424,300425,300426,300427,300428,300429,300430,300431,
    300432,300433,300434,300435,300436,300437,300438,300439,300440,300441,
    300442,300443,300444,300445,300446,300447,300448,300449,300450,300451,
    300452,300453,300454,300455,300456,300457,300458,300459
);

INSERT INTO `dc_collection_definitions` (`collection_type`,`entry_id`,`enabled`)
VALUES
(2,300412,1),(2,300413,1),(2,300414,1),(2,300415,1),(2,300416,1),(2,300417,1),
(2,300418,1),(2,300419,1),(2,300420,1),(2,300421,1),(2,300422,1),(2,300423,1),
(2,300424,1),(2,300425,1),(2,300426,1),(2,300427,1),(2,300428,1),(2,300429,1),
(2,300430,1),(2,300431,1),(2,300432,1),(2,300433,1),(2,300434,1),(2,300435,1),
(2,300436,1),(2,300437,1),(2,300438,1),(2,300439,1),(2,300440,1),(2,300441,1),
(2,300442,1),(2,300443,1),(2,300444,1),(2,300445,1),(2,300446,1),(2,300447,1),
(2,300448,1),(2,300449,1),(2,300450,1),(2,300451,1),(2,300452,1),(2,300453,1),
(2,300454,1),(2,300455,1),(2,300456,1),(2,300457,1),(2,300458,1),(2,300459,1);

-- ============================================================
-- Color Variant Design Notes (for DC-Collection addon)
-- ============================================================
--
-- Server side (no changes beyond this file):
--   - variant_group groups pets into families: marmoset_pet (3), quilin_celestial (4), sha_pet (2)
--   - variant_color names each member: Grey/Brown/White, Gold/Blue/Green/Purple, Dark/Light
--   - Each variant is a fully independent collectible (own item, spell, creature, unlock)
--
-- Client side changes needed in DC-Collection:
--
--   PetJournalFrame.lua / DCPets.BuildPetList():
--     After loading all pet definitions, group entries that share variant_group.
--     Store as: DC_Pets.variantFamilies[group] = { entries, ... }
--
--   Rendering a variant family card:
--     - Show the highest-rarity collected variant as the card thumbnail
--     - Show color swatches along the bottom of the card (one per variant)
--     - Collected swatches: full color circle; uncollected: grey circle
--     - Clicking a collected swatch summons that variant
--     - Hovering a swatch: SetCreature(creatureEntry) in the 3D preview
--     - Card title: base name without color suffix, e.g. "Marmoset"
--
--   Server protocol (COLL handler) — no changes needed:
--     - Definitions response already includes variant_group/variant_color
--       because the server serialises all dc_pet_definitions columns.
--       Add them to the Lua deserialisation in DCCollection.Protocol.lua
--       if the fields aren't already forwarded.
--
--   Visual differentiation (requires WotLK-Extensions DLL work, separate task):
--     Currently all variants of the same model look identical because the
--     3.3.5a engine loads model00.skin unconditionally. To show skin01/02/03
--     the DLL needs a hook on the creature display render path that reads a
--     per-displayId skin-index override table and calls the correct skin.
--     Until that DLL hook lands, variants are distinct collectibles but
--     render identically — the swatch UI still works as a summon selector.
