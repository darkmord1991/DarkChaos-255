-- ---------------------------------------------------------------------------
-- 124  Hyjal round-15 -- loot tables the clone pipeline left behind
-- ---------------------------------------------------------------------------
-- Boot log:
--     Table 'creature_loot_template' Entry 52680 does not exist but it is used
--     by Creature 3652680.                                (+ 9 more, 3 tables)
--
-- Two different shapes, both from the Molten Front import:
--
-- (a) 10 creature_template rows keep a RAW Cata lootid / pickpocketloot /
--     skinloot whose table has no such Entry.  Note the raw value is NOT
--     automatically wrong: most of the clone block deliberately reuses the
--     stock WotLK loot tables (Skeletal Flayer 3601783 -> lootid 1783 is
--     correct and resolves).  Only these 10 point at a Cata-only id that was
--     never imported -- verified by checking every raw lootid in the block
--     against its own table, which leaves exactly this set:
--       creature_loot   52680 Cinderling, 52981 Cinderweb Spinner
--       pickpocketing   52871 Druid of the Flame, 53085 Flamewaker Sentinel,
--                       53143 Flamewaker Hunter
--       skinning        52107 Obsidium Punisher, 52648 Cinderweb Creeper,
--                       52981 Cinderweb Spinner, 53240 Emberspit Scorpion,
--                       53656 Cinderweb Clutchkeeper
--     All 10 exist in nelt_world, so the loot rows are imported AT THE RAW ID
--     (matching what creature_template already points at -- no remap needed,
--     and it keeps the "clone reuses the source loot table" convention).
--
-- (b) 7 Molten Front quest GameObjects reference a gameobject_loot_template
--     that was never cloned, so they open and give nothing -- the quests that
--     need them cannot be completed:
--       208431 Cinderweb Egg Sac      208540 Magmolia (2 GOs share it)
--       208588 Flame Druid Staff      208590 Flame Druid Spellbook
--       208592 Flame Druid Reagent Pouch  208593 Flame Druid Idol
--       208630 Fire Hawk Egg
--
-- nelt loot shape (old-TC): entry, item, ChanceOrQuestChance, lootmode,
-- groupid, mincountOrRef, maxcount -- negative chance = quest-required,
-- negative mincountOrRef = reference id.  Same conversion 29_ uses.
-- Idempotent (INSERT IGNORE).
-- ---------------------------------------------------------------------------

INSERT IGNORE INTO acore_world.creature_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.creature_loot_template lt
WHERE lt.entry IN (52680,52981);

INSERT IGNORE INTO acore_world.pickpocketing_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.pickpocketing_loot_template lt
WHERE lt.entry IN (52871,53085,53143);

INSERT IGNORE INTO acore_world.skinning_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.skinning_loot_template lt
WHERE lt.entry IN (52107,52648,52981,53240,53656);

INSERT IGNORE INTO acore_world.gameobject_loot_template (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT lt.entry, lt.item, IF(lt.mincountOrRef<0,-lt.mincountOrRef,0), ABS(lt.ChanceOrQuestChance), IF(lt.ChanceOrQuestChance<0,1,0), lt.lootmode, lt.groupid, IF(lt.mincountOrRef<0,1,lt.mincountOrRef), lt.maxcount
FROM nelt_world.gameobject_loot_template lt
WHERE lt.entry IN (208431,208540,208588,208590,208592,208593,208630);

-- Any item these tables drop that this DB does not have yet will show up as
-- "item entry not listed in `item_template` - skipped" on the next boot; that
-- overlaps the 19 Molten Front quest items still outstanding (see 00_README
-- round-15 "deferred").
