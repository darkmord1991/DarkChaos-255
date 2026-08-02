-- ---------------------------------------------------------------------------
-- 209  Map 750 -- complete the loot layer
-- ---------------------------------------------------------------------------
-- Full audit of every loot pointer reachable from a map-750 spawn. Most of it
-- was already correct, and it is worth recording what was checked and passed so
-- nobody re-audits it:
--
--   creature_template.lootid       -> creature_loot_template        0 dangling
--   creature_template.pickpocketloot -> pickpocketing_loot_template 0 dangling
--   gameobject_template.Data1      -> gameobject_loot_template      0 dangling
--   loot rows -> item_template                                     0 missing
--   loot rows -> reference_loot_template                           0 missing
--   loot groups with chance sum > 100                              0
--
-- TWO REAL GAPS, both from the same cause: the creature imports copied the
-- `creature_template` columns but not the loot tables those columns point into.
--
-- 1) SKINNING -- 48 creature entries / 744 spawns carry a skinloot id with no
--    skinning_loot_template behind it, which is the
--       "Table 'skinning_loot_template' Entry 3707445 does not exist
--        but it is used by Creature 3707445"
--    block in Errors.log. Every one of the 47 distinct ids resolves: these are
--    stock WotLK Winterspring/Felwood beasts (Shardtooth, Frostsaber, Angerclaw,
--    Ice Thistle, Cobalt whelps, Ysondre) and OUR OWN skinning_loot_template
--    already holds the raw rows. skinloot is already set to entry + 3,700,000,
--    so nothing in creature_template needs touching -- only the 204 rows behind
--    it are missing. Sourced from our own table, not cata, so every item is
--    guaranteed to exist here.
--
-- 2) MOBS THAT DROP NOTHING -- 90 entries / 1355 spawns have lootid = 0 while
--    the source has loot. (259 map-750 entries have lootid = 0 in total; the
--    other 169 have no loot in any source either -- guards, questgivers,
--    trigger bunnies -- and are correctly left alone.)
--
--    The wiring rule is uniform and was verified against all 1355 spawns, not
--    assumed: lootid = entry - 3,700,000, without exception.
--
--    2a) 11 entries (Darkshore/Kalimdor mobs) whose loot template ALREADY
--        exists here at the raw id -- Encrusted Tide Crawler, Moonstalker Sire,
--        Grizzled Thistle Bear, the Greymist murlocs. Pure pointer fix, no new
--        loot rows.
--    2b) 79 entries (Cata content -- Shatterspear, Twilight, Darkscale,
--        Jadefire, Irontree) whose loot is not in our DB. 2,705 rows imported.
--
-- WHY cata_world AND NOT nelt_world. Both were checked. nelt_world covers
-- EXACTLY the same 79 entries and not one more -- verified, zero entries where
-- nelt has loot and cata does not -- so the gap set above is complete either
-- way. The difference is only in shape: nelt has pre-flattened the reference
-- pools inline, giving 12,158 rows to cata's 2,784 for the same content.
-- Compare Forsaken Looter (34046):
--     cata: Linen Cloth 64.6842, Reference 24102 @ 12.4545, Reference 24071 ...
--     nelt: Linen Cloth 64.802,  Rough Wooden Staff 0.627, Old Greatsword 0.47,
--           Feeble Shortbow 0.45, Commoner's Sword 0.45, ... (24102 expanded)
-- The direct chances agree to three decimals, so they are the same data.
-- cata's form is kept because it is 4.5x more compact and, more importantly,
-- it keeps these mobs drawing from OUR OWN reference pools (24071 and friends
-- already exist here and are WotLK-curated) instead of baking a Cataclysm
-- snapshot of those pools into 79 separate copies that can never be updated.
--
-- WHAT IS DROPPED, AND WHY THAT IS SAFE. 79 of those 2,784 rows (2.8%, 36
-- distinct items) point at Cataclysm items that do not exist on this client, so
-- they are filtered out rather than imported -- an unresolvable item id just
-- produces a load error and drops silently anyway. Checked explicitly: NOT ONE
-- of the 79 templates is left empty by that filter, so every one of these mobs
-- ends up with real loot. The 36 items are listed by the verification query at
-- the bottom if they are ever worth downporting.
--
-- 119 rows referenced 9 reference_loot_templates we lacked. Rather than drop
-- those too, section A imports them (plus 2 they nest into), and they pull in
-- no missing items at all -- so those 119 rows survive intact.
--
-- cata_world's loot tables carry an extra `IsCurrency` column that ours do not,
-- hence the explicit column lists throughout.
--
-- Apply against acore_world, then restart worldserver. Idempotent.
-- Section order matters: A before B, or B's reference rows fail validation.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) reference_loot_template -- the 9 referenced sets + 2 they nest into
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` IN (
  24102, 24103, 24104, 24107, 24150, 24731, 24737, 45001, 45004, 45008, 45009);

INSERT INTO `reference_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT r.`Entry`, r.`Item`, r.`Reference`, r.`Chance`, r.`QuestRequired`,
       r.`LootMode`, r.`GroupId`, r.`MinCount`, r.`MaxCount`, r.`Comment`
FROM `cata_world`.`reference_loot_template` r
WHERE r.`Entry` IN (24102, 24103, 24104, 24107, 24150, 24731, 24737, 45001, 45004, 45008, 45009)
  AND (   (r.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = r.`Item`))
       OR (r.`Reference` > 0 AND r.`Reference` IN (24102, 24103, 24104, 24107, 24150, 24731,
                                                   24737, 45001, 45004, 45008, 45009)));

-- ---------------------------------------------------------------------------
-- B) creature_loot_template -- the 79 Cata loot sets
-- ---------------------------------------------------------------------------
-- Imported at the RAW cata lootid, which is free here: verified that none of
-- these 79 ids already exists in our creature_loot_template and that no other
-- creature_template row points at any of them.
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (
  32859, 32860, 32861, 32863, 32888, 32890, 32899, 32928, 32932, 32935, 32970, 32985, 32988,
  32989, 32990, 32996, 32997, 32999, 33009, 33020, 33021, 33022, 33043, 33044, 33057, 33058,
  33079, 33083, 33127, 33179, 33180, 33181, 33206, 33207, 33311, 33345, 33359, 33903, 33905,
  33978, 33980, 33981, 34033, 34046, 34103, 34248, 34302, 34304, 34318, 34326, 34339, 34350,
  34351, 34385, 34392, 34405, 34413, 34414, 34415, 34417, 34427, 47369, 47398, 47439, 47675,
  47679, 47687, 48038, 48154, 48259, 48315, 48331, 48344, 48452, 48453, 48455, 48456, 48763, 48764);

INSERT INTO `creature_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT l.`Entry`, l.`Item`, l.`Reference`, l.`Chance`, l.`QuestRequired`,
       l.`LootMode`, l.`GroupId`, l.`MinCount`, l.`MaxCount`, l.`Comment`
FROM `cata_world`.`creature_loot_template` l
WHERE l.`Entry` IN (
  32859, 32860, 32861, 32863, 32888, 32890, 32899, 32928, 32932, 32935, 32970, 32985, 32988,
  32989, 32990, 32996, 32997, 32999, 33009, 33020, 33021, 33022, 33043, 33044, 33057, 33058,
  33079, 33083, 33127, 33179, 33180, 33181, 33206, 33207, 33311, 33345, 33359, 33903, 33905,
  33978, 33980, 33981, 34033, 34046, 34103, 34248, 34302, 34304, 34318, 34326, 34339, 34350,
  34351, 34385, 34392, 34405, 34413, 34414, 34415, 34417, 34427, 47369, 47398, 47439, 47675,
  47679, 47687, 48038, 48154, 48259, 48315, 48331, 48344, 48452, 48453, 48455, 48456, 48763, 48764)
  AND (   (l.`Reference` = 0 AND EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = l.`Item`))
       OR (l.`Reference` > 0 AND EXISTS (SELECT 1 FROM `reference_loot_template` r WHERE r.`Entry` = l.`Reference`)));

-- ---------------------------------------------------------------------------
-- C) creature_template.lootid -- point the 90 mobs at their loot
-- ---------------------------------------------------------------------------
-- `lootid = entry - 3,700,000` is not a guess: it was checked against all 1355
-- affected spawns and holds for every one. The entry list is pinned rather than
-- re-derived so the set cannot widen between now and when this is applied, and
-- `lootid = 0` in the WHERE clause means a re-run can never overwrite a lootid
-- that has since been set deliberately.
-- ---------------------------------------------------------------------------
UPDATE `creature_template`
   SET `lootid` = CAST(`entry` AS SIGNED) - 3700000
 WHERE `lootid` = 0
   AND `entry` IN (
  3702071, 3702165, 3702206, 3702207, 3702233, 3702237, 3702321, 3703717, 3703812, 3703814,
  3703816,
  3732859, 3732860, 3732861, 3732863, 3732888, 3732890, 3732899, 3732928, 3732932, 3732935,
  3732970, 3732985, 3732988, 3732989, 3732990, 3732996, 3732997, 3732999, 3733009, 3733020,
  3733021, 3733022, 3733043, 3733044, 3733057, 3733058, 3733079, 3733083, 3733127, 3733179,
  3733180, 3733181, 3733206, 3733207, 3733311, 3733345, 3733359, 3733903, 3733905, 3733978,
  3733980, 3733981, 3734033, 3734046, 3734103, 3734248, 3734302, 3734304, 3734318, 3734326,
  3734339, 3734350, 3734351, 3734385, 3734392, 3734405, 3734413, 3734414, 3734415, 3734417,
  3734427, 3747369, 3747398, 3747439, 3747675, 3747679, 3747687, 3748038, 3748154, 3748259,
  3748315, 3748331, 3748344, 3748452, 3748453, 3748455, 3748456, 3748763, 3748764);

-- ---------------------------------------------------------------------------
-- D) skinning_loot_template -- 204 rows for the 47 skinnable beasts
-- ---------------------------------------------------------------------------
-- Cloned from our own table into the +3,700,000 band, which is what the
-- existing `skinloot` values already point at. The 3,700,000-3,799,999 band was
-- verified empty, so the DELETE cannot touch anything else.
-- ---------------------------------------------------------------------------
DELETE FROM `skinning_loot_template` WHERE `Entry` BETWEEN 3700000 AND 3799999;

INSERT INTO `skinning_loot_template`
    (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT s.`Entry` + 3700000, s.`Item`, s.`Reference`, s.`Chance`, s.`QuestRequired`,
       s.`LootMode`, s.`GroupId`, s.`MinCount`, s.`MaxCount`, s.`Comment`
FROM `skinning_loot_template` s
WHERE s.`Entry` IN (
  6375, 6377, 7125, 7126, 7430, 7431, 7432, 7433, 7434, 7435, 7436, 7437, 7443, 7444, 7445,
  7446, 7447, 7448, 7449, 7457, 7458, 7459, 7460, 8759, 8956, 8957, 8958, 8959, 8960, 8961,
  10147, 10196, 10197, 10200, 10202, 10659, 10660, 10661, 10662, 10663, 10664, 10806,
  12474, 12475, 12476, 12498, 14887);

-- ---------------------------------------------------------------------------
-- Verification after applying + restart:
--   SELECT COUNT(*) FROM reference_loot_template WHERE Entry IN
--     (24102,24103,24104,24107,24150,24731,24737,45001,45004,45008,45009);      -- 63
--   SELECT COUNT(DISTINCT Entry) FROM creature_loot_template
--    WHERE Entry BETWEEN 32859 AND 48764 AND Entry IN (32859,34046,48764);      -- 3
--   SELECT COUNT(*) FROM skinning_loot_template
--    WHERE Entry BETWEEN 3700000 AND 3799999;                                   -- 204
--
--   -- no map-750 spawn points at loot that does not exist (all expect 0):
--   SELECT COUNT(*) FROM creature c JOIN creature_template ct ON ct.entry=c.id
--    WHERE c.map=750 AND ct.skinloot>0
--      AND NOT EXISTS (SELECT 1 FROM skinning_loot_template l WHERE l.Entry=ct.skinloot);
--   SELECT COUNT(*) FROM creature c JOIN creature_template ct ON ct.entry=c.id
--    WHERE c.map=750 AND ct.lootid>0
--      AND NOT EXISTS (SELECT 1 FROM creature_loot_template l WHERE l.Entry=ct.lootid);
--
--   -- the 36 Cata items that were filtered out, if they are ever downported:
--   SELECT DISTINCT l.Item FROM cata_world.creature_loot_template l
--    WHERE l.Reference=0 AND NOT EXISTS (SELECT 1 FROM item_template i WHERE i.entry=l.Item)
--      AND l.Entry IN (32859,32860,32861,32863,32888,32928,32935,33009,33021,34046)
--    ORDER BY l.Item;
--
-- Errors.log should lose the whole `skinning_loot_template ... does not exist`
-- block. In game: the Winterspring and Felwood beasts become skinnable, and the
-- Shatterspear/Twilight/Darkscale/Jadefire mobs stop dropping nothing.
-- ---------------------------------------------------------------------------
