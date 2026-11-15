-- High General Abbendis (3610828, the map 751 Tyr's Hand copy of 10828): the On Aggro row links to event 1, which
-- the copy never had, so every pull logs "Link Event 1 not found" (16 times in the 2026-11-14 12:45-18:08 run).
-- The stock 10828 row has link 0.
UPDATE `smart_scripts` SET `link` = 0
WHERE `entryorguid` = 3610828 AND `source_type` = 0 AND `id` = 0 AND `link` = 1;
