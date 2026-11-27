-- Hyjal Frontier - zone consumables + vendor inventories
--
-- Four scaling tiers of branded food/drink/potions cover the full 80-130
-- leveling route.  Each tier uses a custom Spell.csv entry (added to
-- Spell.collection_additions.csv) so restore amounts actually scale with
-- the expanded Hyjal health/mana pools — no longer capped by WotLK-era
-- Runic spells.
--
-- Tier / req-level / custom spell IDs:
--   T1 Foothills  80  food 300550  drink 300551  heal 300552  mana 300553  rejuv 300554
--   T2 Scorched   95  food 300555  drink 300556  heal 300557  mana 300558  rejuv 300559
--   T3 Summit    110  food 300560  drink 300561  heal 300562  mana 300563  rejuv 300564
--   T4 Nordrassil125  food 300565  drink 300566  heal 300567  mana 300568  rejuv 300569
--
-- Restore values per tier (via custom spells):
--   Food health per tick (aura 84, period ~5s × 6 ticks = 30s):
--     T1 6,000  T2 12,000  T3 25,000  T4 50,000
--   Drink mana per period (aura 226, period 2,200ms × ~14 ticks = 30s):
--     T1 5,000  T2 10,000  T3 22,000  T4 45,000
--   Healing Potion (instant heal, range):
--     T1 30,000–40,000  T2 65,000–85,000  T3 140,000–180,000  T4 300,000–380,000
--   Mana Potion:
--     T1 25,000–30,000  T2 55,000–68,000  T3 120,000–150,000  T4 260,000–320,000
--   Rejuvenation Potion (health + mana):
--     T1 22,000–28,000  T2 48,000–60,000  T3 100,000–125,000  T4 220,000–275,000
--
-- Item.csv entries for 400800-400823 are also added (client display).
-- Vendor assignments:
--   Food & Drink  830139 (Alliance) / 830152 (Horde): all food, drink, stat food T1-T4
--   General Goods 830137 (Alliance) / 830150 (Horde): all potions T1-T4 + standard goods
--   Trade Supplies830138 (Alliance) / 830151 (Horde): crafting/tool items
--   Reagents      830140 (Alliance) / 830153 (Horde): bandages + quick-access mana/heal

-- =============================================================================
-- Branded consumable items (400800-400823)
-- =============================================================================
DELETE FROM `item_template` WHERE `entry` BETWEEN 400800 AND 400823;

INSERT INTO `item_template`
    (`entry`, `class`, `subclass`, `SoundOverrideSubclass`, `name`, `displayid`,
     `Quality`, `Flags`, `FlagsExtra`, `BuyCount`, `BuyPrice`, `SellPrice`,
     `InventoryType`, `AllowableClass`, `AllowableRace`, `maxcount`, `stackable`,
     `bonding`, `RequiredLevel`, `ItemLevel`, `spellid_1`, `spelltrigger_1`,
     `spellcharges_1`, `spellcooldown_1`, `spellcategory_1`,
     `spellcategorycooldown_1`, `FoodType`, `description`, `VerifiedBuild`)
VALUES
-- ===== T1 Foothills (req 80) =================================================
(400800, 0, 5, -1, 'Emberwood Trail Ration', 49687,
    1, 0, 0, 5, 9000, 450, 0, -1, -1, 0, 20, 0, 80, 75,
    300550, 0, -1, 0, 11, 1000, 6,
    'A hearty Foothills field meal. Restores health while eating.', 0),
(400801, 0, 5, -1, 'Emberwood Spring Tea', 50880,
    1, 0, 0, 5, 11000, 550, 0, -1, -1, 0, 20, 0, 80, 75,
    300551, 0, -1, 0, 59, 1000, 0,
    'Brewed from Hyjal spring water. Restores mana while drinking.', 0),
(400802, 0, 5, -1, 'Emberwood Hearty Stew', 50876,
    1, 0, 0, 5, 16000, 800, 0, -1, -1, 0, 20, 0, 80, 75,
    300550, 0, -1, 0, 11, 1000, 3,
    'A filling Foothills stew. Restores health while eating.', 0),
(400803, 0, 1, -1, 'Emberwood Healing Draught', 56990,
    1, 0, 0, 1, 24000, 6000, 0, -1, -1, 0, 20, 0, 80, 80,
    300552, 0, -1, 0, 4, 60000, 0,
    'A Foothills healing potion. Restores 30,000 to 40,000 health.', 0),
(400804, 0, 1, -1, 'Emberwood Mana Draught', 56989,
    1, 0, 0, 1, 24000, 6000, 0, -1, -1, 0, 20, 0, 80, 80,
    300553, 0, -1, 0, 4, 60000, 0,
    'A Foothills mana potion. Restores 25,000 to 30,000 mana.', 0),
(400805, 0, 1, -1, 'Emberwood Restoration Draught', 56990,
    1, 0, 0, 1, 30000, 7500, 0, -1, -1, 0, 20, 0, 80, 80,
    300554, 0, -1, 0, 4, 60000, 0,
    'A Foothills restoration potion. Restores health and mana.', 0),

-- ===== T2 Scorched Groves (req 95) ===========================================
(400806, 0, 5, -1, 'Skyfire Camp Bread', 49687,
    1, 0, 0, 5, 12000, 600, 0, -1, -1, 0, 20, 0, 95, 95,
    300555, 0, -1, 0, 11, 1000, 6,
    'Standard rations from the Scorched Groves front. Restores health while eating.', 0),
(400807, 0, 5, -1, 'Skyfire Infused Water', 50880,
    1, 0, 0, 5, 14000, 700, 0, -1, -1, 0, 20, 0, 95, 95,
    300556, 0, -1, 0, 59, 1000, 0,
    'Drawn from scorched grove springs. Restores mana while drinking.', 0),
(400808, 0, 5, -1, 'Skyfire Hearty Stew', 50876,
    1, 0, 0, 5, 20000, 1000, 0, -1, -1, 0, 20, 0, 95, 95,
    300555, 0, -1, 0, 11, 1000, 3,
    'A filling Scorched Groves stew. Restores health while eating.', 0),
(400809, 0, 1, -1, 'Skyfire Healing Tincture', 56990,
    1, 0, 0, 1, 32000, 8000, 0, -1, -1, 0, 20, 0, 95, 95,
    300557, 0, -1, 0, 4, 60000, 0,
    'A Scorched Groves healing potion. Restores 65,000 to 85,000 health.', 0),
(400810, 0, 1, -1, 'Skyfire Mana Tincture', 56989,
    1, 0, 0, 1, 32000, 8000, 0, -1, -1, 0, 20, 0, 95, 95,
    300558, 0, -1, 0, 4, 60000, 0,
    'A Scorched Groves mana potion. Restores 55,000 to 68,000 mana.', 0),
(400811, 0, 1, -1, 'Skyfire Restoration Tincture', 56990,
    1, 0, 0, 1, 40000, 10000, 0, -1, -1, 0, 20, 0, 95, 95,
    300559, 0, -1, 0, 4, 60000, 0,
    'A Scorched Groves restoration potion. Restores health and mana.', 0),

-- ===== T3 Summit (req 110) ===================================================
(400812, 0, 5, -1, 'Summit Ranger Ration', 49687,
    2, 0, 0, 5, 16000, 800, 0, -1, -1, 0, 20, 0, 110, 110,
    300560, 0, -1, 0, 11, 1000, 6,
    'Summit war-camp provisions. Restores health while eating.', 0),
(400813, 0, 5, -1, 'Summit Moonwell Water', 50880,
    2, 0, 0, 5, 18000, 900, 0, -1, -1, 0, 20, 0, 110, 110,
    300561, 0, -1, 0, 59, 1000, 0,
    'Collected from a Summit moonwell. Restores mana while drinking.', 0),
(400814, 0, 5, -1, 'Summit Feast', 50876,
    2, 0, 0, 5, 24000, 1200, 0, -1, -1, 0, 20, 0, 110, 110,
    300560, 0, -1, 0, 11, 1000, 3,
    'A rich Summit banquet. Restores health while eating.', 0),
(400815, 0, 1, -1, 'Summit Healing Elixir', 56990,
    2, 0, 0, 1, 42000, 10500, 0, -1, -1, 0, 20, 0, 110, 110,
    300562, 0, -1, 0, 4, 60000, 0,
    'A Summit healing elixir. Restores 140,000 to 180,000 health.', 0),
(400816, 0, 1, -1, 'Summit Mana Elixir', 56989,
    2, 0, 0, 1, 42000, 10500, 0, -1, -1, 0, 20, 0, 110, 110,
    300563, 0, -1, 0, 4, 60000, 0,
    'A Summit mana elixir. Restores 120,000 to 150,000 mana.', 0),
(400817, 0, 1, -1, 'Summit Restoration Elixir', 56990,
    2, 0, 0, 1, 52000, 13000, 0, -1, -1, 0, 20, 0, 110, 110,
    300564, 0, -1, 0, 4, 60000, 0,
    'A Summit restoration elixir. Restores health and mana.', 0),

-- ===== T4 Nordrassil (req 125) ===============================================
(400818, 0, 5, -1, 'Nordrassil Ancient Bread', 49687,
    2, 0, 0, 5, 20000, 1000, 0, -1, -1, 0, 20, 0, 125, 125,
    300565, 0, -1, 0, 11, 1000, 6,
    'Baked under Nordrassil. Restores health while eating.', 0),
(400819, 0, 5, -1, 'Nordrassil Moonwater', 50880,
    2, 0, 0, 5, 22000, 1100, 0, -1, -1, 0, 20, 0, 125, 125,
    300566, 0, -1, 0, 59, 1000, 0,
    'Blessed under the World Tree. Restores mana while drinking.', 0),
(400820, 0, 5, -1, 'Nordrassil World Tree Feast', 50876,
    3, 0, 0, 5, 30000, 1500, 0, -1, -1, 0, 20, 0, 125, 125,
    300565, 0, -1, 0, 11, 1000, 3,
    'A feast blessed by Nordrassil. Restores health while eating.', 0),
(400821, 0, 1, -1, 'Nordrassil Healing Infusion', 56990,
    2, 0, 0, 1, 55000, 13750, 0, -1, -1, 0, 20, 0, 125, 125,
    300567, 0, -1, 0, 4, 60000, 0,
    'A Nordrassil healing infusion. Restores 300,000 to 380,000 health.', 0),
(400822, 0, 1, -1, 'Nordrassil Mana Infusion', 56989,
    2, 0, 0, 1, 55000, 13750, 0, -1, -1, 0, 20, 0, 125, 125,
    300568, 0, -1, 0, 4, 60000, 0,
    'A Nordrassil mana infusion. Restores 260,000 to 320,000 mana.', 0),
(400823, 0, 1, -1, 'Nordrassil Restoration Infusion', 56990,
    3, 0, 0, 1, 68000, 17000, 0, -1, -1, 0, 20, 0, 125, 125,
    300569, 0, -1, 0, 4, 60000, 0,
    'A Nordrassil restoration infusion. Restores health and mana.', 0);

-- =============================================================================
-- Vendor inventories
--   Food & Drink vendors  : 830139 (A) / 830152 (H)
--   General Goods vendors : 830137 (A) / 830150 (H)
--   Trade Supplies vendors: 830138 (A) / 830151 (H)
--   Reagents vendors      : 830140 (A) / 830153 (H)
-- =============================================================================
DELETE FROM `npc_vendor`
WHERE `entry` IN (830137, 830138, 830139, 830140, 830150, 830151, 830152, 830153);

-- ── Food & Drink ─────────────────────────────────────────────────────────────
-- Zones vendors handle: all food/drink/stat food across all 4 tiers
--  Slots 1-3 T1 | 4-6 T2 | 7-9 T3 | 10-12 T4 | 13-15 standard WotLK items
INSERT INTO `npc_vendor`
    (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
VALUES
(830139,  1, 400800, 0, 0, 0, 0),  -- T1 food
(830139,  2, 400801, 0, 0, 0, 0),  -- T1 drink
(830139,  3, 400802, 0, 0, 0, 0),  -- T1 hearty stew
(830139,  4, 400806, 0, 0, 0, 0),  -- T2 food
(830139,  5, 400807, 0, 0, 0, 0),  -- T2 drink
(830139,  6, 400808, 0, 0, 0, 0),  -- T2 hearty stew
(830139,  7, 400812, 0, 0, 0, 0),  -- T3 food
(830139,  8, 400813, 0, 0, 0, 0),  -- T3 drink
(830139,  9, 400814, 0, 0, 0, 0),  -- T3 feast
(830139, 10, 400818, 0, 0, 0, 0),  -- T4 food
(830139, 11, 400819, 0, 0, 0, 0),  -- T4 drink
(830139, 12, 400820, 0, 0, 0, 0),  -- T4 feast
(830139, 13,  35952, 0, 0, 0, 0),  -- Briny Hardcheese (standard)
(830139, 14,  33445, 0, 0, 0, 0),  -- Honeymint Tea (standard)
(830139, 15,    159, 0, 0, 0, 0),  -- Refreshing Spring Water
(830139, 16,   4540, 0, 0, 0, 0),  -- Tough Hunk of Bread
-- Horde mirror
(830152,  1, 400800, 0, 0, 0, 0),
(830152,  2, 400801, 0, 0, 0, 0),
(830152,  3, 400802, 0, 0, 0, 0),
(830152,  4, 400806, 0, 0, 0, 0),
(830152,  5, 400807, 0, 0, 0, 0),
(830152,  6, 400808, 0, 0, 0, 0),
(830152,  7, 400812, 0, 0, 0, 0),
(830152,  8, 400813, 0, 0, 0, 0),
(830152,  9, 400814, 0, 0, 0, 0),
(830152, 10, 400818, 0, 0, 0, 0),
(830152, 11, 400819, 0, 0, 0, 0),
(830152, 12, 400820, 0, 0, 0, 0),
(830152, 13,  35952, 0, 0, 0, 0),
(830152, 14,  33445, 0, 0, 0, 0),
(830152, 15,    159, 0, 0, 0, 0),
(830152, 16,   4540, 0, 0, 0, 0),

-- ── General Goods ─────────────────────────────────────────────────────────────
-- Slots 1-12: potions by tier (heal/mana/rejuv × 4 tiers)
-- Slots 13+: standard WotLK potions, injectors, bandages
(830137,  1, 400803, 0, 0, 0, 0),  -- T1 heal pot
(830137,  2, 400804, 0, 0, 0, 0),  -- T1 mana pot
(830137,  3, 400805, 0, 0, 0, 0),  -- T1 rejuv
(830137,  4, 400809, 0, 0, 0, 0),  -- T2 heal pot
(830137,  5, 400810, 0, 0, 0, 0),  -- T2 mana pot
(830137,  6, 400811, 0, 0, 0, 0),  -- T2 rejuv
(830137,  7, 400815, 0, 0, 0, 0),  -- T3 heal pot
(830137,  8, 400816, 0, 0, 0, 0),  -- T3 mana pot
(830137,  9, 400817, 0, 0, 0, 0),  -- T3 rejuv
(830137, 10, 400821, 0, 0, 0, 0),  -- T4 heal pot
(830137, 11, 400822, 0, 0, 0, 0),  -- T4 mana pot
(830137, 12, 400823, 0, 0, 0, 0),  -- T4 rejuv
(830137, 13,  33447, 0, 0, 0, 0),  -- Runic Healing Potion
(830137, 14,  33448, 0, 0, 0, 0),  -- Runic Mana Potion
(830137, 15,  41166, 0, 0, 0, 0),  -- Runic Healing Injector
(830137, 16,  42545, 0, 0, 0, 0),  -- Runic Mana Injector
(830137, 17,  34721, 0, 0, 0, 0),  -- Frostweave Bandage
(830137, 18,  34722, 0, 0, 0, 0),  -- Heavy Frostweave Bandage
(830137, 19,    159, 0, 0, 0, 0),  -- Water
(830137, 20,   4540, 0, 0, 0, 0),  -- Bread
-- Horde mirror
(830150,  1, 400803, 0, 0, 0, 0),
(830150,  2, 400804, 0, 0, 0, 0),
(830150,  3, 400805, 0, 0, 0, 0),
(830150,  4, 400809, 0, 0, 0, 0),
(830150,  5, 400810, 0, 0, 0, 0),
(830150,  6, 400811, 0, 0, 0, 0),
(830150,  7, 400815, 0, 0, 0, 0),
(830150,  8, 400816, 0, 0, 0, 0),
(830150,  9, 400817, 0, 0, 0, 0),
(830150, 10, 400821, 0, 0, 0, 0),
(830150, 11, 400822, 0, 0, 0, 0),
(830150, 12, 400823, 0, 0, 0, 0),
(830150, 13,  33447, 0, 0, 0, 0),
(830150, 14,  33448, 0, 0, 0, 0),
(830150, 15,  41166, 0, 0, 0, 0),
(830150, 16,  42545, 0, 0, 0, 0),
(830150, 17,  34721, 0, 0, 0, 0),
(830150, 18,  34722, 0, 0, 0, 0),
(830150, 19,    159, 0, 0, 0, 0),
(830150, 20,   4540, 0, 0, 0, 0),

-- ── Trade Supplies ────────────────────────────────────────────────────────────
(830138, 1,   2320, 0, 0, 0, 0),  -- Coarse Thread
(830138, 2,   2321, 0, 0, 0, 0),  -- Fine Thread
(830138, 3,   4291, 0, 0, 0, 0),  -- Silken Thread
(830138, 4,   8343, 0, 0, 0, 0),  -- Heavy Silken Thread
(830138, 5,  38426, 0, 0, 0, 0),  -- Eternium Thread
(830138, 6,   2901, 0, 0, 0, 0),  -- Mining Pick
(830138, 7,   6219, 0, 0, 0, 0),  -- Arclight Spanner
(830138, 8,   6256, 0, 0, 0, 0),  -- Fishing Pole
-- Horde mirror
(830151, 1,   2320, 0, 0, 0, 0),
(830151, 2,   2321, 0, 0, 0, 0),
(830151, 3,   4291, 0, 0, 0, 0),
(830151, 4,   8343, 0, 0, 0, 0),
(830151, 5,  38426, 0, 0, 0, 0),
(830151, 6,   2901, 0, 0, 0, 0),
(830151, 7,   6219, 0, 0, 0, 0),
(830151, 8,   6256, 0, 0, 0, 0),

-- ── Reagents ─────────────────────────────────────────────────────────────────
(830140, 1,  34721, 0, 0, 0, 0),  -- Frostweave Bandage
(830140, 2,  34722, 0, 0, 0, 0),  -- Heavy Frostweave Bandage
(830140, 3,  400804, 0, 0, 0, 0), -- T1 mana pot (quick access)
(830140, 4,  400810, 0, 0, 0, 0), -- T2 mana pot
(830140, 5,  400803, 0, 0, 0, 0), -- T1 heal pot
(830140, 6,   33444, 0, 0, 0, 0), -- Pungent Seal Whey (level 70 drink)
-- Horde mirror
(830153, 1,  34721, 0, 0, 0, 0),
(830153, 2,  34722, 0, 0, 0, 0),
(830153, 3,  400804, 0, 0, 0, 0),
(830153, 4,  400810, 0, 0, 0, 0),
(830153, 5,  400803, 0, 0, 0, 0),
(830153, 6,   33444, 0, 0, 0, 0);

-- =============================================================================
-- Material field correction (AzerothCore validates item_template.Material
-- against Item.dbc at startup; INSERT above defaults to 0 which fails).
-- Food/drink items use Material=-1 (no equip sound), potions use Material=3.
-- =============================================================================
UPDATE `item_template` SET `Material`=-1
WHERE `entry` IN (400800,400801,400802,400806,400807,400808,400812,400813,400814,400818,400819,400820);
UPDATE `item_template` SET `Material`=3
WHERE `entry` IN (400803,400804,400805,400809,400810,400811,400815,400816,400817,400821,400822,400823);
