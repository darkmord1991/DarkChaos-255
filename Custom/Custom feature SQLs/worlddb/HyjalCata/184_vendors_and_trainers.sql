-- ---------------------------------------------------------------------------
-- 184  Hyjal round-45 -- give map 750's vendors stock and its trainers spells
-- ---------------------------------------------------------------------------
-- 88 NPCs on map 750 carry the vendor flag with an EMPTY inventory and 29 carry
-- the trainer flag with nothing to teach: the imports cloned the templates and
-- the npcflags but never the service tables.  Clicking them opens a blank
-- window.
--
-- VENDORS: 67 of the 88 have rows in cata_world (872 of them).  831 survive the
-- item filter -- 41 sell items that do not exist in our item_template and are
-- dropped, because a vendor slot pointing at a missing item shows as a broken
-- entry.  All 29 distinct ExtendedCost ids used were verified present in the
-- live server's ItemExtendedCost.dbc, so the token/currency prices resolve.
-- The remaining 21 vendors have no cata source at all and stay empty.
--
-- TRAINERS: cata's trainer data is deliberately NOT imported.  Its 1,123 spells
-- looked fine against `spell_dbc` (2 hits) but that table is only the ADDITIVE
-- override -- the real store is the client's Spell.dbc, and testing there showed
-- the low ids all present while the Cata-era top of the range (87498..101600)
-- is entirely MISSING.  Importing would have produced trainers offering spells
-- no client can learn.  Cata's TrainerIds (1..427) would also have collided
-- head-on with ours (126 rows already sit in 1..500).
--
-- Instead each NPC is pointed at the EXISTING trainer that already serves its
-- profession, matched on subname.  Every target below was checked to carry real
-- spells (count in brackets), so these NPCs immediately train the full stock
-- list rather than a partial Cata one.
--
-- Two get their trainer flag REMOVED instead of a link:
--   Stephanie Krutsick, "Archaeology Trainer" -- Archaeology is a Cataclysm
--     secondary skill that does not exist in 3.3.5; there is nothing to teach.
--   KTC Train-a-Tron Deluxe, "Professions Trainer & Vendor" -- a goblin
--     multi-profession machine with no single 3.3.5 equivalent.  It keeps its
--     VENDOR flag and stays useful as a vendor.
-- ---------------------------------------------------------------------------

-- --- vendors ---------------------------------------------------------------
DELETE FROM `npc_vendor` WHERE `entry` IN (
  SELECT e FROM (SELECT DISTINCT t.`entry` AS e FROM `creature` c
    JOIN `creature_template` t ON t.`entry` = c.`id`
    WHERE c.`map` = 750 AND (t.`npcflag` & 128)) x);

INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT DISTINCT t.`entry`, cv.`slot`, cv.`item`, cv.`maxcount`, cv.`incrtime`, cv.`ExtendedCost`, 0
FROM cata_world.npc_vendor cv
JOIN acore_world.creature_template t
  ON cv.`entry` IN (CAST(t.`entry` AS SIGNED) - 3600000, CAST(t.`entry` AS SIGNED) - 3700000)
JOIN acore_world.creature c ON c.`id` = t.`entry` AND c.`map` = 750
WHERE (t.`npcflag` & 128)
  AND cv.`item` IN (SELECT `entry` FROM acore_world.item_template);

-- --- trainers: reuse the stock trainer that already serves each profession --
-- Scoped to the subnames the INSERT below re-creates.  The first revision
-- deleted EVERY map-750 trainer link and re-added only matching subnames, which
-- silently dropped Jenna Lemkenilli (Engineering, missing from the CASE) and
-- Meilosh (NULL subname) -- see 185_ for the repair and the general rule.
DELETE FROM `creature_default_trainer` WHERE `CreatureId` IN (
  SELECT e FROM (SELECT DISTINCT t.`entry` AS e FROM `creature` c
    JOIN `creature_template` t ON t.`entry` = c.`id`
    WHERE c.`map` = 750 AND (t.`npcflag` & 16)
      AND t.`subname` IN ('Alchemy Trainer','Blacksmithing Trainer','Druid Trainer','Engineering Trainer',
                          'First Aid Trainer','Fishing Trainer','Herbalism Trainer','Hunter Trainer',
                          'Leatherworking Trainer','Mage Trainer','Mining Trainer','Pet Trainer',
                          'Priest Trainer','Rogue Trainer','Shaman Trainer','Skinning Trainer',
                          'Tailoring Trainer','Warlock Trainer','Warrior Trainer')) x);

INSERT INTO `creature_default_trainer` (`CreatureId`, `TrainerId`)
SELECT DISTINCT t.`entry`,
  CASE t.`subname`
    WHEN 'Alchemy Trainer'        THEN 67    -- 46 spells
    WHEN 'Blacksmithing Trainer'  THEN 60    -- 86
    WHEN 'Druid Trainer'          THEN 33    -- 297
    WHEN 'Engineering Trainer'    THEN 92    -- (added: 184_ first shipped without it)
    WHEN 'First Aid Trainer'      THEN 83    -- 14
    WHEN 'Fishing Trainer'        THEN 98    -- 4
    WHEN 'Herbalism Trainer'      THEN 69    -- 4
    WHEN 'Hunter Trainer'         THEN 7     -- 172
    WHEN 'Leatherworking Trainer' THEN 61    -- 76
    WHEN 'Mage Trainer'           THEN 16    -- 256
    WHEN 'Mining Trainer'         THEN 80    -- 14
    WHEN 'Pet Trainer'            THEN 125   -- 1
    WHEN 'Priest Trainer'         THEN 11    -- 240
    WHEN 'Rogue Trainer'          THEN 9     -- 122
    WHEN 'Shaman Trainer'         THEN 14    -- 276
    WHEN 'Skinning Trainer'       THEN 100   -- 4
    WHEN 'Tailoring Trainer'      THEN 74    -- 103
    WHEN 'Warlock Trainer'        THEN 31    -- 235
    WHEN 'Warrior Trainer'        THEN 1     -- 133
  END
FROM `creature` c
JOIN `creature_template` t ON t.`entry` = c.`id`
WHERE c.`map` = 750 AND (t.`npcflag` & 16)
  AND t.`subname` IN ('Alchemy Trainer','Blacksmithing Trainer','Druid Trainer','First Aid Trainer',
                      'Engineering Trainer','Fishing Trainer','Herbalism Trainer','Hunter Trainer','Leatherworking Trainer',
                      'Mage Trainer','Mining Trainer','Pet Trainer','Priest Trainer','Rogue Trainer',
                      'Shaman Trainer','Skinning Trainer','Tailoring Trainer','Warlock Trainer',
                      'Warrior Trainer');

-- --- nothing to teach: drop the trainer flag, keep every other function -----
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~16
WHERE `entry` IN (3751997, 3649885) AND (`npcflag` & 16);

-- Verify -- expect 0 empty vendors with a cata source, and 2 remaining unlinked
-- trainers (both intentionally de-flagged above, so this should read 0 too):
--   SELECT COUNT(DISTINCT t.entry) FROM `creature` c JOIN `creature_template` t ON t.entry=c.id
--    WHERE c.map=750 AND (t.npcflag & 16)
--      AND NOT EXISTS (SELECT 1 FROM `creature_default_trainer` d WHERE d.CreatureId=t.entry);
--   SELECT COUNT(*) FROM `npc_vendor` v JOIN `creature` c ON c.id=v.entry WHERE c.map=750;
