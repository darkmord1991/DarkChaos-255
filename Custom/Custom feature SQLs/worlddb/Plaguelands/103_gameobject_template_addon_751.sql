-- 103_gameobject_template_addon_751.sql -- map 751 gameobject flags/faction, DB step 42.
--
-- THE SYMPTOM
--   "i fall through the platform like on blackwing descent"
--   The Undercity elevators on map 751 are now visible (86_/101_ restored their
--   TransportAnimation frames and StaticTransport::Create no longer fails), but a
--   player standing on one drops straight through.
--
-- THE CAUSE -- AN OFFSET-BAND TRAP, third of the same family.
--   AzerothCore does NOT keep a gameobject's flags and faction in
--   `gameobject_template`; it moved both into the side table
--   `gameobject_template_addon`. The map-751 import cloned the base table onto the
--   +4,600,000 band and never touched the side table, so every one of those
--   gameobjects came up with flags = 0.
--
--   Bit 0x08 is GO_FLAG_TRANSPORT ("Object can transport (elevator, boat, car)").
--   It is what tells the client an object carries passengers. Without it the
--   elevator renders but is not a ride, so you fall through it.
--
--     stock 20649..20654 (Undervator / upperLdoor / lowerLdoor)  flags = 40   = 0x08|0x20
--     stock 20655..20657 (the third shaft)                       flags = 2088 = 0x800|0x08|0x20
--     map-751 4620649..4620657                                   NO ROW AT ALL
--
--   Same root cause as the TransportAnimation gap, and it is not limited to the
--   elevators: 838 distinct map-751 gameobject templates in that band have no addon
--   row, against a stock counterpart that does. Beyond the 9 transports this also
--   restores locked/conditional chests, non-selectable doors, mailbox and meeting
--   stone factions, and the NODESPAWN bit on 12 fixtures.
--
-- SCOPE -- DELIBERATELY NOT THE WHOLE BAND. Two exclusions, both load-bearing:
--
--   1. THE +4,800,000 BAND IS EXCLUDED ENTIRELY. Of its 168 templates only 34 have
--      any entry at (id - 4,800,000) at all, and NOT ONE of those 34 matches on
--      name, displayId and type -- they are pure numeric coincidences:
--          4802563 "Mailbox"  vs  2563 "Altar of the Tides - Focused"
--          4802681 "Bench"    vs  2681 "Hammerfall"
--          4804120 "Cache of Shadra" vs 4120 "Mulgore"
--      Copying those would have written 34 wrong factions/flags. That band was not
--      minted by subtracting an offset from a stock id, so it has no stock source.
--
--   2. SEVEN ROWS IN THE +4,600,000 BAND ARE SKIPPED, the ones where the source
--      disagrees on name, displayId or type -- the import changed the object, so
--      the stock flags no longer describe it:
--          4601586 Crate of Candles      type 3 vs stock type 2
--          4601557 Lillith's Dinner Table type 10 vs stock type 2
--          4658626 "Archaeology"         vs stock "Cartography"
--          4658620 "Mining & Jewelcrafting" vs stock "Mining"
--          4663674 Shaman Shrine         displayId 299 vs stock 0
--          4780523 Apple Bob             type 10 vs stock type 3
--          4780437 "Wickerman Ashes"     vs stock "Wickerman Ember", type 10 vs 2
--      Five of the seven have stock flags = 0 and faction = 0, so nothing is lost.
--
--   That leaves 831 rows that match on all three fields. 138 of them carry a real
--   value; the other 693 are all-default and are inserted anyway so the band is
--   complete and future edits have a row to edit. No mingold/maxgold and no artkits
--   are involved -- every matched source row is zero in all six of those columns.
--
-- THE +3,600,000 BAND IS ALREADY CORRECT: all 378 of its templates have addon rows.
-- Only the +4,600,000 import dropped them.
--
-- Derived at apply time from the live tables rather than baked as literals, so the
-- validation predicate is visible and re-running is idempotent.

DROP TABLE IF EXISTS `_dc_go_addon_751`;

CREATE TABLE `_dc_go_addon_751` (
  `entry` INT UNSIGNED NOT NULL,
  `faction` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `flags` INT UNSIGNED NOT NULL DEFAULT 0,
  `mingold` INT UNSIGNED NOT NULL DEFAULT 0,
  `maxgold` INT UNSIGNED NOT NULL DEFAULT 0,
  `artkit0` INT NOT NULL DEFAULT 0,
  `artkit1` INT NOT NULL DEFAULT 0,
  `artkit2` INT NOT NULL DEFAULT 0,
  `artkit3` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `_dc_go_addon_751`
  (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT t.`entry`, sa.`faction`, sa.`flags`, sa.`mingold`, sa.`maxgold`,
       sa.`artkit0`, sa.`artkit1`, sa.`artkit2`, sa.`artkit3`
FROM (SELECT DISTINCT `id` FROM `gameobject` WHERE `map` = 751 AND `id` BETWEEN 4600000 AND 4799999) g
JOIN `gameobject_template` t ON t.`entry` = g.`id`
JOIN `gameobject_template` s ON s.`entry` = g.`id` - 4600000
JOIN `gameobject_template_addon` sa ON sa.`entry` = s.`entry`
WHERE s.`name` <=> t.`name`
  AND s.`displayId` <=> t.`displayId`
  AND s.`type` <=> t.`type`;

DELETE FROM `gameobject_template_addon`
 WHERE `entry` IN (SELECT `entry` FROM `_dc_go_addon_751`);

INSERT INTO `gameobject_template_addon`
  (`entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`)
SELECT `entry`, `faction`, `flags`, `mingold`, `maxgold`, `artkit0`, `artkit1`, `artkit2`, `artkit3`
FROM `_dc_go_addon_751`;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'rows staged (want 831)' AS what, COUNT(*) AS n FROM `_dc_go_addon_751`
UNION ALL SELECT '  ...of those, carrying a non-default value (want 138)', COUNT(*)
  FROM `_dc_go_addon_751`
  WHERE `faction` <> 0 OR `flags` <> 0 OR `mingold` <> 0 OR `maxgold` <> 0
     OR `artkit0` <> 0 OR `artkit1` <> 0 OR `artkit2` <> 0 OR `artkit3` <> 0
UNION ALL SELECT '  ...with GO_FLAG_TRANSPORT 0x08 (want 9)', COUNT(*)
  FROM `_dc_go_addon_751` WHERE `flags` & 8
UNION ALL SELECT 'the 9 Undercity transports now have an addon row (want 9)', COUNT(*)
  FROM `gameobject_template_addon` WHERE `entry` BETWEEN 4620649 AND 4620657
UNION ALL SELECT '  ...of those, rideable i.e. flags & 0x08 (want 9)', COUNT(*)
  FROM `gameobject_template_addon`
  WHERE `entry` BETWEEN 4620649 AND 4620657 AND `flags` & 8
UNION ALL SELECT 'map-751 +4.6M templates still with no addon row (want 7)', COUNT(*)
  FROM (SELECT DISTINCT `id` FROM `gameobject`
         WHERE `map` = 751 AND `id` BETWEEN 4600000 AND 4799999) q
  LEFT JOIN `gameobject_template_addon` a ON a.`entry` = q.`id`
  WHERE a.`entry` IS NULL
UNION ALL SELECT 'flags match stock exactly for the transports (want 9)', COUNT(*)
  FROM `gameobject_template_addon` n
  JOIN `gameobject_template_addon` o ON o.`entry` = n.`entry` - 4600000
  WHERE n.`entry` BETWEEN 4620649 AND 4620657 AND n.`flags` = o.`flags`;

DROP TABLE `_dc_go_addon_751`;
