-- Worgoblin: starting class spells for the new races.
-- DC's playercreateinfo_spell_custom uses per-race masks (no 0-mask rows), so the
-- new races get their own sets: class spells = intersection of the orc(2) and
-- human(1) sets (racials/languages are race-unique and drop out), plus the
-- goblin/worgen racials appended explicitly.
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` IN (256, 2048);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 256, a.`classmask`, a.`Spell`, CONCAT('Goblin - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 2 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 1 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 2048, a.`classmask`, a.`Spell`, CONCAT('Worgen - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 1 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 2 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`) VALUES
(256, 0, 669, 'Goblin - Language Orcish'),
(256, 0, 69042, 'Goblin - Time is Money'),
(256, 0, 69044, 'Goblin - Best Deals Anywhere'),
(256, 0, 69045, 'Goblin - Better Living Through Chemistry'),
(256, 0, 69046, 'Goblin - Pack Hobgoblin'),
(256, 0, 69041, 'Goblin - Rocket Barrage'),
(256, 0, 69070, 'Goblin - Rocket Jump'),
(2048, 0, 668, 'Worgen - Language Common'),
(2048, 0, 68975, 'Worgen - Viciousness'),
(2048, 0, 68976, 'Worgen - Aberration'),
(2048, 0, 68978, 'Worgen - Flayer'),
(2048, 0, 68992, 'Worgen - Darkflight'),
(2048, 0, 68996, 'Worgen - Two Forms');
