-- Blackwing Descent (map 669) — boss loot (NORMAL / 10-man)
-- Source: cata_world creature_loot_template + reference_loot_template (native Reference schema).
-- The 6 boss reference groups are remapped off the item-id namespace into a reserved band
-- (6690001..6690006) so nothing collides. Omnotron loot sits on Toxitron 42180 (as in cata / CataTC).
-- Item stats for the dropped items are populated in 10_items.sql.
--
-- Ref remap:  415700 Magmaw->6690001 · 421800 Omnotron(Toxitron)->6690002 · 413780 Maloriak->6690003
--             414420 Atramedes->6690004 · 432960 Chimaeron->6690005 · 413760 Nefarian->6690006
--
-- >>> TODO (difficulty coverage): cata loot is LootMode=1 (10N only). For 25N widen LootMode (1|2),
-- >>> and 10H/25H need the ilvl-372 HEROIC drop tables (heroic item ids 65005-65075 from the loot
-- >>> investigation) keyed to LootMode 4/8 — those heroic tables are NOT in cata_world/nelt_world and
-- >>> must be authored from the heroic drop lists. This file ships NORMAL loot only.

-- ---------------------------------------------------------------------------
-- reference_loot_template (the 6 boss loot groups, Entry remapped to 669000x)
-- ---------------------------------------------------------------------------
DELETE FROM `reference_loot_template` WHERE `Entry` BETWEEN 6690001 AND 6690006;
INSERT INTO `reference_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT
    CASE rlt.`Entry`
        WHEN 415700 THEN 6690001 WHEN 421800 THEN 6690002 WHEN 413780 THEN 6690003
        WHEN 414420 THEN 6690004 WHEN 432960 THEN 6690005 WHEN 413760 THEN 6690006
        ELSE rlt.`Entry` END,
    rlt.`Item`, rlt.`Reference`, rlt.`Chance`, rlt.`QuestRequired`, rlt.`LootMode`, rlt.`GroupId`, rlt.`MinCount`, rlt.`MaxCount`, rlt.`Comment`
FROM `cata_world`.`reference_loot_template` rlt
WHERE rlt.`Entry` IN (413760,413780,414420,415700,421800,432960);

-- ---------------------------------------------------------------------------
-- creature_loot_template (boss reference rows + Nefarian tier-token direct drops)
-- ---------------------------------------------------------------------------
DELETE FROM `creature_loot_template` WHERE `Entry` IN (41570,42180,41378,41442,43296,41376);
INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT
    clt.`Entry`,
    IF(clt.`Reference` > 0,
       CASE clt.`Reference`
           WHEN 415700 THEN 6690001 WHEN 421800 THEN 6690002 WHEN 413780 THEN 6690003
           WHEN 414420 THEN 6690004 WHEN 432960 THEN 6690005 WHEN 413760 THEN 6690006
           ELSE clt.`Reference` END,
       clt.`Item`),
    CASE clt.`Reference`
        WHEN 415700 THEN 6690001 WHEN 421800 THEN 6690002 WHEN 413780 THEN 6690003
        WHEN 414420 THEN 6690004 WHEN 432960 THEN 6690005 WHEN 413760 THEN 6690006
        ELSE clt.`Reference` END,
    clt.`Chance`, clt.`QuestRequired`, clt.`LootMode`, clt.`GroupId`, clt.`MinCount`, clt.`MaxCount`, clt.`Comment`
FROM `cata_world`.`creature_loot_template` clt
WHERE clt.`Entry` IN (41570,42180,41378,41442,43296,41376);
