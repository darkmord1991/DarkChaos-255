-- ---------------------------------------------------------------------------
-- 323  Map 750 -- raise the Hyjal band's target ItemLevel (fixes an inversion)
-- ---------------------------------------------------------------------------
-- 309_ targets each band's clone gear at a base ItemLevel:
--
--     band  80 -> 285    band  88 -> 315    band  96 -> 355
--     band 104 -> 372    band 113 -> 385
--
-- plus a +-10 spread carried from the SOURCE item's own ItemLevel, plus +8 for
-- blue and +16 for epic.
--
-- 🔴 THE INVERSION. Hyjal (band 113-128, the LAST leveling band) ends up with
-- LOWER item levels than Winterspring (band 104-115) below it:
--
--     band 104 clones   green max 380   blue max 390   epic max 395
--     band 113 clones   green     375   blue     383   epic none
--
-- ---------------------------------------------------------------------------
-- WHY -- and it is not the base target
-- ---------------------------------------------------------------------------
-- 385 is already higher than 372, so the base is not the problem. The spread
-- term is:
--
--     ROUND((LEAST(GREATEST(src.ItemLevel, 5), 70) - 5) * 20 / 65) - 10
--
-- 🔴 EVERY SINGLE band-113 source item has `ItemLevel = 0`. Measured: 101 of
-- 101, min 0, max 0. They are Cata Firelands/Hyjal pieces (57260+ -- "Nemesis
-- Crushers", "Tortolla's Discarded Scales", "Leggings of the Vanquished
-- Usurper") that were downported with ItemLevel never set, and RequiredLevel 1.
--
-- With src.ItemLevel = 0 the term is GREATEST(0,5) = 5, so (5-5)*20/65 - 10 =
-- **-10 for every item**. The whole band collapses onto the bottom of its own
-- spread: exactly two values, 375 (80 greens) and 383 (21 blues). Winterspring,
-- whose sources have real item levels averaging 55, spreads properly and
-- overtakes it.
--
-- ---------------------------------------------------------------------------
-- THE FIX
-- ---------------------------------------------------------------------------
-- Assign band 113 its target directly rather than through a spread term that
-- has no signal to work with:
--
--     green @hyjal_base (388)    blue @hyjal_base + 8 (396)
--
-- 🔴 NO ARTIFICIAL SPREAD IS INVENTED. Deriving one from entry ids would be
-- fabricating variance the data does not contain. The band stays two values
-- until the real gap is closed -- which is to restore ItemLevel on the 57260+
-- source items, a downport repair that would let 309_'s spread term work by
-- itself. Noted as the proper fix; not attempted here because it needs real
-- Cata item levels, not guesses.
--
-- WHY 388, checked against everything it has to sit between:
--
--     band 104 green max      380   <- 388 clears it like-for-like (+8)
--     band 104 blue max       390   <- 396 clears it like-for-like (+6)
--     band 104 epic max       395   <- 396 clears the band outright
--     T4 ladder epic          398   <- stays ABOVE both, numerically AND in
--                                      power: at qmul 1.15 vs 1.00 it is 16%
--                                      stronger than a 396 blue, and 40%
--                                      stronger than a 388 green
--     T4 upgrade tier window  300-411  <- 388/396 stay inside it, so the gear
--                                      remains tier-4 upgradeable (Emberwood
--                                      Sap, per 320_) and does not fall into
--                                      T5 at 412+
--
-- Pushing to 400/408 instead would also work and fills the band better, but a
-- clone BLUE would then show a higher item level than the ladder EPIC players
-- buy with sap -- power ordering stays correct, but the number on the tooltip
-- would undercut the reward. Change @hyjal_base if that trade is wanted.
--
-- 🔴 THIS DOES NOT GIVE BAND 113 A RequiredLevel SPREAD, and cannot. By the
-- ladder curve 321_ fits, ilvl 388-396 is level 108-110 gear, which clamps up
-- to the band floor of 113 either way. Levels 116-128 have NO authored gear
-- tier anywhere on the continent -- that is a content gap, not a data defect,
-- and no ItemLevel assignment inside T4's window can close it.
--
-- ---------------------------------------------------------------------------
-- 🔴 RUN ORDER -- this file invalidates two others
-- ---------------------------------------------------------------------------
-- Stat budget is `0.00207 * ItemLevel^2.13 * slot * quality` and RequiredLevel
-- is a function of ItemLevel, so moving ItemLevel silently stales both:
--
--     1. 323_  (this file)
--     2. re-run 319_   -- recomputes stat budgets for the 101 moved items
--     3. re-run 321_   -- recomputes RequiredLevel from the new ItemLevel
--
-- Both are idempotent and derive from ItemLevel, so re-running them is safe and
-- affects only what actually moved. 322_ is independent of ItemLevel and may be
-- applied before or after.
--
-- Apply against acore_world. Idempotent -- absolute assignment, no arithmetic
-- on the current value. Needs `.reload item_template` or a worldserver restart,
-- plus a client cache bump.
-- ---------------------------------------------------------------------------

USE `acore_world`;

SET @hyjal_base := 388;

-- ---------------------------------------------------------------------------
-- 1. Move the pin first -- `dc_map750_item_clone` is what 309_ calls the pin,
--    and everything downstream joins it. Leaving tgt_ilvl stale would make a
--    fresh 309_ apply disagree with the live data.
-- ---------------------------------------------------------------------------
UPDATE `dc_map750_item_clone` m
JOIN `item_template` i ON i.`entry` = m.`clone_entry`
SET m.`tgt_ilvl` = @hyjal_base
                 + CASE i.`Quality` WHEN 3 THEN 8 WHEN 4 THEN 16 ELSE 0 END
WHERE m.`band_lo` = 113;

-- ---------------------------------------------------------------------------
-- 2. Then the items themselves, from the pin
-- ---------------------------------------------------------------------------
UPDATE `item_template` i
JOIN `dc_map750_item_clone` m ON m.`clone_entry` = i.`entry`
SET i.`ItemLevel` = m.`tgt_ilvl`
WHERE m.`band_lo` = 113;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- Band 113 now sits above band 104 like-for-like (expect 388 green / 396 blue
-- against 380 / 390):
-- SELECT m.band_lo, i.Quality, COUNT(*) n, MIN(i.ItemLevel) lo, MAX(i.ItemLevel) hi
-- FROM dc_map750_item_clone m JOIN item_template i ON i.entry = m.clone_entry
-- WHERE m.band_lo IN (104, 113) AND i.class IN (2, 4) AND i.InventoryType > 0
-- GROUP BY m.band_lo, i.Quality ORDER BY m.band_lo, i.Quality;
--
-- Nothing escaped the tier-4 upgrade window (expect 0):
-- SELECT COUNT(*) FROM dc_map750_item_clone m
-- JOIN item_template i ON i.entry = m.clone_entry
-- WHERE m.band_lo = 113 AND (i.ItemLevel < 300 OR i.ItemLevel > 411);
--
-- The ladder epic still outranks every band-113 clone (expect 0):
-- SELECT COUNT(*) FROM dc_map750_item_clone m
-- JOIN item_template i ON i.entry = m.clone_entry
-- WHERE m.band_lo = 113 AND i.ItemLevel >= 398;
--
-- Pin and items agree (expect 0):
-- SELECT COUNT(*) FROM dc_map750_item_clone m
-- JOIN item_template i ON i.entry = m.clone_entry
-- WHERE m.band_lo = 113 AND i.ItemLevel <> m.tgt_ilvl;
--
-- AFTER re-running 319_, band-113 budgets should have risen ~7%
-- ((396/383)^2.13 = 1.074):
-- SELECT ROUND(AVG(stat_value1 + stat_value2 + stat_value3 + stat_value4)) avg_budget
-- FROM dc_map750_item_clone m JOIN item_template i ON i.entry = m.clone_entry
-- WHERE m.band_lo = 113 AND i.class IN (2, 4) AND i.InventoryType > 0;
--
-- ROLLBACK (restores 309_'s original assignment for this band):
-- UPDATE dc_map750_item_clone m JOIN item_template i ON i.entry = m.clone_entry
-- SET m.tgt_ilvl = CASE i.Quality WHEN 3 THEN 383 WHEN 4 THEN 391 ELSE 375 END
-- WHERE m.band_lo = 113;
-- UPDATE item_template i JOIN dc_map750_item_clone m ON m.clone_entry = i.entry
-- SET i.ItemLevel = m.tgt_ilvl WHERE m.band_lo = 113;
-- -- then re-run 319_ and 321_.
-- ---------------------------------------------------------------------------
