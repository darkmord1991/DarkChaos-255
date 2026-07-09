-- =====================================================================
-- Blackwing Descent Downport  --  22  Trash creature_loot_template rows
-- ---------------------------------------------------------------------
-- 09_loot.sql only ever covered the 6 boss reference rows (41570/42180/
-- 41378/41442/43296/41376) -- 17 trash entries (self-referencing lootid =
-- their own entry, per 01_creature_templates.sql) never got a matching
-- creature_loot_template row at all, logging at boot:
--   Table 'creature_loot_template' Entry N does not exist but it is used
--   by Creature N
-- i.e. Drakonid Drudge/Chainwielder/Slayer, Pyrecraw, Ivoroc, Maimgor,
-- Golem Sentry, Drakeadon Mongrel (x2 entries), and the 8 "Spirit of
-- <Blackrock boss>" adds -- none of them drop anything when killed.
-- Same cross-schema INSERT...SELECT pattern as 09_loot.sql, minus the
-- Reference-remap CASE logic (that was specific to the 6 bosses' shared
-- tier-token reference chain; these trash rows are assumed to use direct
-- Item drops in cata_world -- if any turn out to reference a
-- reference_loot_template id outside our copied range, a follow-up will
-- surface it the same way this batch was found).
-- =====================================================================

DELETE FROM `creature_loot_template` WHERE `Entry` IN (42362,42649,42767,42768,42764,42800,42802,42803,43119,43122,43125,43126,43127,43128,43129,43130,46083);

INSERT INTO `creature_loot_template`
    (`Entry`, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT
    clt.`Entry`, clt.`Item`, clt.`Reference`, clt.`Chance`, clt.`QuestRequired`, clt.`LootMode`, clt.`GroupId`, clt.`MinCount`, clt.`MaxCount`, clt.`Comment`
FROM `cata_world`.`creature_loot_template` clt
WHERE clt.`Entry` IN (42362,42649,42767,42768,42764,42800,42802,42803,43119,43122,43125,43126,43127,43128,43129,43130,46083);
