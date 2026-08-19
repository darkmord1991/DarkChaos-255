-- =====================================================================
-- dc_vault_loot_table repair
-- =====================================================================
-- Found while tracing "Great Vault claimed successfully but I got no item".
-- The claim path itself was fine; the loot table it draws from is not.
--
-- Apply against: acore_world
-- Safe to re-run (every statement is idempotent).
--
-- Verification queries are at the bottom of this file.
-- =====================================================================
--
-- READ THIS FIRST
-- ---------------------------------------------------------------------
-- This file fixes the tagging (class_mask, spec_name) and removes rows
-- that cannot be delivered. It does NOT fix the item_id column, and the
-- item_id column is wrong for most of the WotLK rows:
--
--   tier   rows   item_id matches the source note
--   239      79   33 ok / 46 wrong
--   252      90    2 ok / 88 wrong
--   264      86   30 ok / 56 wrong
--   430     108   generated cleanly, no defects found
--
-- The three WotLK tiers were hand-authored by walking a contiguous item
-- id range alongside a list of tier token names; the two lists drifted
-- apart. 190 of 255 rows now point at an item that is not the one the
-- source note names - "Naxx 25 - Scourgeborne Gauntlets" carries id
-- 40553, which is Electrified Blade. Some source notes ("Deathwhisper
-- Pants") match no item in the database at all, so the ids cannot be
-- recovered from the notes either.
--
-- So: applying this file makes the table internally consistent and stops
-- the token fallback, and every reward will at least be usable by the
-- class that receives it. It does not make the table hand out the gear
-- it claims to. The 255 WotLK rows want regenerating from item_template
-- the way the clean 430 block was, which is a separate job.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Remove rows that can never be delivered.
-- ---------------------------------------------------------------------
-- 6 entries have no row in item_template at all. Before the server-side
-- guard was added these produced a silent success: CanStoreNewItem
-- failed, the code read that as "bags full", mailed it via a path that
-- drops unknown items, and reported the claim as successful.
--
-- 4 more exist but are not gear: a quest item, a companion pet, another
-- quest item and a placeholder token. None are a valid vault reward.

DELETE FROM `dc_vault_loot_table` WHERE `item_id` IN (
    47912,  -- no item_template row
    48103,  -- no item_template row
    48125,  -- no item_template row
    48127,  -- no item_template row
    48477,  -- no item_template row
    48479,  -- no item_template row
    40582,  -- [TDB PH] - unsused Scourgestone (placeholder, class 15)
    48104,  -- The Refleshifier (quest item, class 12)
    48126,  -- Razzashi Hatchling (companion pet, class 15)
    48128   -- Mountainfoot Iron (quest item, class 12)
);


-- ---------------------------------------------------------------------
-- 2. Correct class_mask to the real WoW class bits.
-- ---------------------------------------------------------------------
-- The table was authored with a sequential scheme that has no gap where
-- the unused bit 512 sits, so everything after Shaman is shifted one bit
-- down relative to the client's actual class mask:
--
--     table 128 -> real 1024 (Druid)   34 rows
--     table 256 -> real  128 (Mage)    14 rows
--     table 512 -> real  256 (Warlock) 10 rows
--
-- GetPlayerClassMask() in CrossSystemVaultUtils.h uses the real bits, so
-- Druids matched none of their own tier gear (1024 & 128 = 0) and fell
-- through to the generic class_mask = 1023 rows only. Mages matched the
-- Druid rows by mask but were then blocked by the armour filter, leaving
-- them with generic rows as well.
--
-- A further 14 rows are plain data-entry slips (warrior gear tagged
-- shaman, priest gear tagged druid, and so on).
--
-- item_template.AllowableClass is authoritative for both cases, so take
-- the value from there. Rows tagged 1023 ("any class") and items with
-- AllowableClass = -1 ("no restriction") are deliberately left alone.

UPDATE `dc_vault_loot_table` `t`
JOIN `item_template` `i` ON `i`.`entry` = `t`.`item_id`
SET `t`.`class_mask` = `i`.`AllowableClass`
WHERE `t`.`class_mask` <> 1023
  AND `i`.`AllowableClass` <> -1
  AND (`i`.`AllowableClass` & `t`.`class_mask`) = 0;


-- ---------------------------------------------------------------------
-- 3. Align the druid feral spec name with the server.
-- ---------------------------------------------------------------------
-- GetPlayerSpec() returns "Feral Combat" for talent tree 1, matching the
-- WotLK tree name. The table says "Feral", so the equality test in
-- fetchCandidates never hit and feral druids only ever saw the
-- spec_name IS NULL rows.

UPDATE `dc_vault_loot_table`
SET `spec_name` = 'Feral Combat'
WHERE `spec_name` = 'Feral';


-- ---------------------------------------------------------------------
-- 4. Let Discipline priests see the priest healer sets.
-- ---------------------------------------------------------------------
-- The priest healer rows are tagged spec_name = 'Holy', so a Discipline
-- priest matched none of them and got zero candidates in every tier.
-- class_mask = 16 plus role_mask = 2 already pins these rows to priest
-- healers, so the spec name adds nothing but the exclusion. NULL is the
-- table's existing convention for "any spec that fits this class+role".

UPDATE `dc_vault_loot_table`
SET `spec_name` = NULL
WHERE `spec_name` = 'Holy' AND `class_mask` = 16 AND `role_mask` = 2;


-- =====================================================================
-- Verification
-- =====================================================================
-- All three should return 0 rows after applying this file.
--
-- Entries with no item_template, or that are not weapons/armour:
--   SELECT t.item_id, i.name, i.class
--   FROM dc_vault_loot_table t
--   LEFT JOIN item_template i ON i.entry = t.item_id
--   WHERE i.entry IS NULL OR i.class NOT IN (2, 4);
--
-- class_mask still contradicting the item's own AllowableClass:
--   SELECT t.item_id, t.class_mask, i.AllowableClass
--   FROM dc_vault_loot_table t
--   JOIN item_template i ON i.entry = t.item_id
--   WHERE t.class_mask <> 1023 AND i.AllowableClass <> -1
--     AND (i.AllowableClass & t.class_mask) = 0;
--
-- Spec names the server never produces:
--   SELECT DISTINCT spec_name FROM dc_vault_loot_table
--   WHERE spec_name = 'Feral';
--
-- =====================================================================
-- Deliberately NOT changed here
-- =====================================================================
-- item_level_min behaves as a tier label rather than a real item level:
--
--   band 239-310  ->  items are actually ilvl 213 (76 of 79 rows)
--   band 252-310  ->  items are actually ilvl 232-258
--   band 264-310  ->  items are actually ilvl 264-277
--   band 430-470  ->  items are actually ilvl 450
--
-- The bands are left as they are because they drive candidate selection
-- (a +8 key looks up targetIlvl 264 and must land in the 264 band). The
-- display half is now handled server-side instead: GenerateVaultRewardPool
-- stores the item's own ItemLevel in dc_vault_reward_pool rather than the
-- tier target, so the panel shows what the reward really is. Whether a +2
-- key should hand out ilvl 213 or real 239 gear stays a tuning decision.

-- =====================================================================
-- Still missing after this file - needs content, not a data fix
-- =====================================================================
-- The 239 tier (the tier-7.5 Valorous sets, 80 rows) contains no
-- role_mask = 1 rows at all, so every tank spec - Protection Warrior,
-- Protection Paladin and Blood Death Knight - still finds no candidate
-- there and falls back to an upgrade token on a +2 to +4 key:
--
--   SELECT role_mask, COUNT(*) FROM dc_vault_loot_table
--   WHERE item_level_min = 239 GROUP BY role_mask;
--   -> 2 (healer): 20,  4 (dps): 55,  5 (feral): 5,  1 (tank): 0
--
-- Tank rows exist in the 252 and 264 tiers, so this is specific to the
-- lowest band. Add the tier-7.5 tank sets there to close it.
