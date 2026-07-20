-- ---------------------------------------------------------------------------
-- Flamewaker Shaman (3653093) lootid -- raw cata id, needs the +3,600,000 offset
-- ---------------------------------------------------------------------------
-- "Table 'creature_loot_template' Entry 53093 does not exist but it is used
-- by Creature 3653093." Self-inflicted from HyjalCata/84_'s cross-DB copy,
-- which carried `lootid` straight from cata_world without remapping it to
-- the +3,600,000 clone offset -- same bug class as the RequiredNpcOrGo/
-- KillCredit1 remap bugs fixed in earlier rounds. cata_world's own lootid
-- convention here is self-referencing (lootid = entry), so the fix is
-- simply pointing it at this creature's own (already-offset) entry.
--
-- creature_loot_template itself was ALSO never copied for this entry (0
-- rows at either the raw or offset id) -- cata_world has the real table:
-- 332 rows, a shared "Firelands trash gear" pool (many tiny-chance possible
-- drops + one common ~49% junk/gold-proxy item 53010) -- copied verbatim
-- via cross-DB INSERT...SELECT, same pattern as every other loot backfill
-- this session.
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `lootid` = 3653093 WHERE `entry` = 3653093 AND `lootid` = 53093;

DELETE FROM `creature_loot_template` WHERE `Entry` = 3653093;

INSERT INTO `creature_loot_template` (`Entry`,`Item`,`Reference`,`Chance`,`QuestRequired`,`LootMode`,`GroupId`,`MinCount`,`MaxCount`)
SELECT 3653093, `Item`, `Reference`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`
FROM `cata_world`.`creature_loot_template`
WHERE `Entry` = 53093;
