-- ---------------------------------------------------------------------------
-- 296  New content sweep -- map 751 Plaguelands + map 825 Shadowfang Keep
-- ---------------------------------------------------------------------------
-- Errors.log jumped 87 -> 361 lines. Not a regression: new content landed. The
-- new entry bands (4.8M, 5.0M, 5.2M-5.4M) are the **map 751 Plaguelands** and
-- **map 825 Shadowfang Keep** imports, and they arrived with the same classes
-- every offset-band import has arrived with.
--
--   1  273 gameobject_loot_template rows at LootMode 0 -- items that never drop
--   2  23 Plaguelands chests/herbs whose loot table was never created
--   3  3 Cauldron Lords with a dangling lootid
--   4  Deathstalker Commander Belmont -- dangling lootid, and the source agrees
--      it has no loot
--   5  npc_text 17706 -- Brazie the Botanist has a gossip menu and no greeting
--   6  2 unspawned Levers claiming SmartGameObjectAI with no rows
--
-- Apply against acore_world, then restart worldserver. Idempotent throughout.
--
-- 🔴 TWO CROSS-DB SCHEMA TRAPS IN THIS FILE, both checked rather than assumed:
--   * `cata_world.gameobject_loot_template` and `creature_loot_template` have
--     **11 columns to our 10** -- the extra one is `IsCurrency`. A `SELECT *`
--     copy would shift every column by one from that point on.
--   * `npc_text` uses **different column NAMES** in the two databases for the
--     emote fields (our six flat `em{i}_0..5` vs cata's `EmoteDelay{i}_{j}` /
--     `Emote{i}_{j}` pairs) -- section 5 records the mapping, though it no
--     longer needs it: that row turned out to be a placeholder in BOTH sources
--     and is authored here instead.
--   Every cross-DB INSERT below names its columns on both sides.

-- ---------------------------------------------------------------------------
-- 1) LootMode 0 -- 273 rows that can never drop
-- ---------------------------------------------------------------------------
--     Table 'gameobject_loot_template' Entry 4807485 Item 9770: LootMode is
--     equal to 0, item will never drop - setting mode 1
--
-- Same class as 281_. LootMode is a bitmask of difficulty modes; 0 matches no
-- mode, so the row is dead. The core patches it to 1 in memory at load ("setting
-- mode 1"), which is why this is 273 log lines rather than 273 broken chests --
-- but the DB should say what the server actually runs.
--
-- Exactly 2 tables carry it: 4794341 and 4807485 (Sturdy Treasure Chest on 751).
-- Measured: creature_loot_template, reference_loot_template and
-- skinning_loot_template have **0** LootMode-0 rows, so this is the whole class.
UPDATE acore_world.`gameobject_loot_template` SET `LootMode` = 1
 WHERE `LootMode` = 0 AND `Entry` IN (4794341, 4807485);

-- ---------------------------------------------------------------------------
-- 2) 23 Plaguelands objects whose loot table was never created
-- ---------------------------------------------------------------------------
--     Table 'gameobject_loot_template' Entry 4808876 does not exist but it is
--     used by Gameobject 4808876
--
-- The import set each clone's `data1` (lootid) to its own entry -- correct, and
-- consistent with 232_'s lootid == entry invariant -- but never created the
-- table at that id. The source loot lives in cata_world under a different id
-- (e.g. our 4802421 "Xavren's Thorn" -> cata 202421 -> loot table 28234).
--
-- The map-751 GO band is **+4,600,000**; verified by name for all 25 affected
-- templates (25/25 resolve at entry - 4,600,000 with an identical name). The
-- name check is what stops a wrong band silently pairing two different objects.
--
-- 24 of the 26 source rows import; **2 are blocked on missing items** and those
-- two GOs are left dangling on purpose rather than given an empty table (an
-- empty loot table is the same failure with a quieter log -- the 239_ lesson):
--     4805099 Ferocious Doomweed        -> item 60741  absent here and in nelt
--     4805363 Forsaken Communication Device -> item 60953  ditto
-- Both are Cata 60xxx quest items; see the follow-up note at the bottom.
INSERT INTO acore_world.`gameobject_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT t.`entry`, cl.`Item`, cl.`Reference`, cl.`Chance`, cl.`QuestRequired`,
       IF(cl.`LootMode` = 0, 1, cl.`LootMode`), cl.`GroupId`, cl.`MinCount`, cl.`MaxCount`,
       CONCAT('DC751 loot from cata ', s.`entry`, ' table ', s.`data1`, ' (296)')
FROM acore_world.`gameobject_template` t
JOIN `cata_world`.`gameobject_template` s
  ON s.`entry` = CAST(t.`entry` AS SIGNED) - 4600000 AND s.`name` = t.`name`
JOIN `cata_world`.`gameobject_loot_template` cl ON cl.`Entry` = s.`data1`
WHERE t.`type` = 3
  AND t.`data1` <> 0
  AND t.`entry` BETWEEN 4800000 AND 4899999
  AND NOT EXISTS (SELECT 1 FROM acore_world.`gameobject_loot_template` l WHERE l.`Entry` = t.`data1`)
  -- never import a row whose item does not exist here
  AND EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.`entry` = cl.`Item`)
  -- and do not carry a dead LootMode across (see section 1)
  AND cl.`Reference` >= 0;

-- ---------------------------------------------------------------------------
-- 3) The three Cauldron Lords
-- ---------------------------------------------------------------------------
-- 3611075 Bilemaw, 3611076 Razarch, 3611077 Malvinious -- Plaguelands cauldron
-- bosses at the +3,600,000 offset, each with lootid = entry and no table.
-- cata_world has 5 / 4 / 4 rows and **0 are blocked on a missing item**, so all
-- 13 import cleanly.
--
-- None of the three is spawned yet, so this is log-only today -- but the loot is
-- what makes them worth spawning, and importing it now means the spawn round
-- does not have to remember.
INSERT INTO acore_world.`creature_loot_template`
  (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`,`Comment`)
SELECT t.`entry`, cl.`Item`, cl.`Reference`, cl.`Chance`, cl.`QuestRequired`,
       IF(cl.`LootMode` = 0, 1, cl.`LootMode`), cl.`GroupId`, cl.`MinCount`, cl.`MaxCount`,
       CONCAT('DC751 loot from cata ', cs.`entry`, ' table ', cs.`lootid`, ' (296)')
FROM acore_world.`creature_template` t
JOIN `cata_world`.`creature_template` cs ON cs.`entry` = CAST(t.`entry` AS SIGNED) - 3600000
JOIN `cata_world`.`creature_loot_template` cl ON cl.`Entry` = cs.`lootid`
WHERE t.`entry` IN (3611075, 3611076, 3611077)
  AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` l WHERE l.`Entry` = t.`entry`)
  AND EXISTS (SELECT 1 FROM acore_world.`item_template` i WHERE i.`entry` = cl.`Item`);

-- ---------------------------------------------------------------------------
-- 4) Deathstalker Commander Belmont -- the source says he has no loot
-- ---------------------------------------------------------------------------
-- 4145312, spawned once on 751, lootid = 4145312 with no table. Unlike the
-- Cauldron Lords, **cata_world has 0 loot rows for his source**, so there is
-- nothing to import and the lootid is simply wrong. Clearing it is what the
-- core already does at runtime; this makes the DB agree.
UPDATE acore_world.`creature_template` SET `lootid` = 0
 WHERE `entry` = 4145312 AND `lootid` = 4145312
   AND NOT EXISTS (SELECT 1 FROM acore_world.`creature_loot_template` l WHERE l.`Entry` = 4145312);

-- ---------------------------------------------------------------------------
-- 5) npc_text 17706 -- Brazie the Botanist has nothing to say
-- ---------------------------------------------------------------------------
--     Table gossip_menu entry 12590 are using non-existing TextID 17706
--
-- gossip_menu 12590 belongs to creature 4149687 "Brazie the Botanist" (npcflag 3
-- = GOSSIP|QUESTGIVER, 1 spawn on map 751). The menu row exists, the text does
-- not, so opening him produces an empty gossip window above his quest list.
--
-- 🔴 THIS IS AUTHORED, NOT IMPORTED, AND THE FIRST VERSION OF THIS SECTION WAS
-- WRONG TWICE. Worth recording both, because each was a different mistake:
--
--   1. I wrote a 90-column cross-DB INSERT and it failed at apply with
--      `SQL 1054: Unknown column 'c.em0_0'`. I had compared the two schemas'
--      column NAME LISTS, seen them differ, and concluded the ORDER differed --
--      when in fact the NAMES differ: we store six flat `em{i}_0..5`, cata
--      stores three explicit `EmoteDelay{i}_{j}` / `Emote{i}_{j}` pairs.
--      (For the record, since it may be needed elsewhere: ObjectMgr.cpp:6713 and
--      its loader loop read the six as (delay, emote) x3 in order, so
--      em{i}_0..5 <- EmoteDelay{i}_0, Emote{i}_0, EmoteDelay{i}_1, Emote{i}_1,
--      EmoteDelay{i}_2, Emote{i}_2 -- positionally the tables DO line up.)
--
--   2. Having fixed the column names, I read the row before shipping it -- and
--      **cata_world's text0_0 is literally "Missing npc_text"**. nelt_world's is
--      "Need TXT YTDB". Both sources are placeholders; neither sniff project
--      ever captured Blizzard's real dialogue for this NPC (86 rows in cata
--      carry that same placeholder). Importing either would have replaced an
--      empty gossip window with a debug string shown to players -- strictly
--      worse, and the log would have gone quiet either way.
--
-- So the text below is DC-authored: short, neutral, and in keeping with the NPC
-- (Brazie is the gardener whose seedlings hold off the Scourge). It is not
-- Blizzard's line and does not pretend to be. If you would rather he simply had
-- no menu, the alternative is to delete gossip_menu 12590 and clear
-- creature_template.gossip_menu_id -- his quest list still opens on npcflag 2.
--
-- Written straight into our own schema, so there is no cross-DB column mapping
-- left to get wrong. Unlisted columns take their defaults (0 / '').
DELETE FROM acore_world.`npc_text` WHERE `ID` = 17706;
INSERT INTO acore_world.`npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`) VALUES
(17706,
 'The dead have no patience for a garden, but my garden has plenty for them. Mind where you step -- some of these sprouts bite back.',
 'The dead have no patience for a garden, but my garden has plenty for them. Mind where you step -- some of these sprouts bite back.',
 1);

-- ---------------------------------------------------------------------------
-- 6) Two Levers claiming SmartGameObjectAI with no script
-- ---------------------------------------------------------------------------
--     Gameobject entry (5201812) has SmartGameobjectAI enabled but no SmartAI
--     entries in the database.
--
-- 5201811 and 5201812, both named "Lever", both **unspawned**, both with zero
-- source_type-1 smart_scripts rows. Clearing AIName is the honest state: an
-- AIName with no rows advertises behaviour that does not exist.
--
-- 🔴 184850 "Sunhawk Portal Controller" reports the SAME error and is NOT
-- touched: it is stock AzerothCore content with **4 live spawns**. Clearing its
-- AIName would be editing upstream data to quiet a log, and if its rows are
-- meant to arrive from an upstream update, this would mask that.
UPDATE acore_world.`gameobject_template` SET `AIName` = ''
 WHERE `entry` IN (5201811, 5201812) AND `AIName` = 'SmartGameObjectAI';

-- ---------------------------------------------------------------------------
-- Verify after apply
-- ---------------------------------------------------------------------------
--  1  SELECT COUNT(*) FROM gameobject_loot_template WHERE LootMode=0;        -> 0
--  2  SELECT COUNT(*) FROM gameobject_loot_template
--      WHERE Comment LIKE 'DC751 loot from cata%';                          -> 24
--     SELECT COUNT(*) FROM gameobject_template t WHERE t.type=3 AND t.data1<>0
--       AND NOT EXISTS(SELECT 1 FROM gameobject_loot_template l WHERE l.Entry=t.data1);
--       -> 8   (2 blocked on missing items + the 6 map-825 ones, see below)
--  3  SELECT Entry, COUNT(*) FROM creature_loot_template
--      WHERE Entry IN (3611075,3611076,3611077) GROUP BY Entry;      -> 5 / 4 / 4
--  4  SELECT lootid FROM creature_template WHERE entry=4145312;             -> 0
--  5  SELECT COUNT(*) FROM npc_text WHERE ID=17706;                         -> 1
--     SELECT LEFT(text0_0,40) FROM npc_text WHERE ID=17706;
--       -> 'The dead have no patience for a garden'
--       -- and specifically NOT 'Missing npc_text' or 'Need TXT YTDB', which is
--       -- what the two source databases hold.
--  6  SELECT entry, AIName FROM gameobject_template WHERE entry IN (5201811,5201812);
--       -> both empty; 184850 must STILL read 'SmartGameObjectAI'
--
--  Next boot: ~300 of the 361 lines gone.
--
-- ---------------------------------------------------------------------------
-- Blocked, and what unblocks it -- ONE item downport
-- ---------------------------------------------------------------------------
-- Five Cataclysm quest items are absent from acore_world AND nelt_world, and
-- they are the only thing standing between this file and a clean loot layer on
-- both maps:
--     60741  -> GO 4805099 Ferocious Doomweed          (18 spawns, map 751)
--     60953  -> GO 4805363 Forsaken Communication Dev  (1 spawn,  map 751)
--     60871  -> lootid 34678, GO 5400040 Moontouched Wood  (43 spawns, map 825)
--     60872  -> lootid 34677, GO 5400039 Moonsteel Ingots  (30 spawns, map 825)
--     60873  -> lootid 34671, GO 5400038 Book of Lost Souls (1 spawn, map 825)
-- Plus item 69988 for `spell_loot_template` 99500 "Open Mulgore Pine Cone".
--
-- Note the map-825 objects point at **RAW** lootids (34671/34677/34678) rather
-- than the entry-matching convention, and 6 templates share those three ids. Do
-- not create tables at those raw ids without deciding that first -- raw ids in
-- the stock range are exactly what 232_'s lootid == entry invariant exists to
-- avoid.
--
-- These want the established item downport pipeline (Item-sparse.db2 is already
-- extracted at k:/tmp/cata-locale/), which is an Item.dbc + ItemDisplayInfo
-- rebuild and a client deploy -- a round of its own, not a section here.
--
-- ALSO DEFERRED, deliberately:
-- * Spells **95303 / 95305** ("Teleport to Chapel" / "Teleport to Laboratory"),
--   used by Haunted Stable Hand 5051400 on map 825. Both exist in the Cata 4.3.4
--   client and both screen CLEAN (effect 5 TELEPORT_UNITS, no stealth/
--   invisibility/phase aura), so the downport itself is routine -- but effect 0
--   has targetB = 17 TARGET_DEST_DB, which means each needs a
--   `spell_target_position` row or the teleport silently goes nowhere (the exact
--   defect 287_ found on spell 74948). cata_world has a destination for **95305
--   only**, and it is on map 33, so it needs remapping to 825; 95303 has no
--   destination anywhere. Downporting the spells without destinations would just
--   trade two log lines for two dead teleports.
-- * The 4 unassigned scripts new in this log (naxx_northrend_entrance,
--   npc_omarion_gossip, npc_tesla_40, spell_gen_submerge_visual) and 2 new
--   spell-script effect mismatches (93572, 105552) -- same shape as the six
--   already triaged in 292_: each needs its intended target read out of the C++
--   before a row can be written.
