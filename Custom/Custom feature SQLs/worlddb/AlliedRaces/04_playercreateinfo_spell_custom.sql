-- Allied races: starting class spells.
-- Class spells = intersection of the human(1) and orc(2) sets, exactly as Worgoblin and
-- Pandaren do it, plus each race's faction language. Racials are NOT granted here yet -
-- see 00_README.md "Racials" for why they are deferred.
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` IN (8388608, 16777216, 33554432);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 8388608, a.`classmask`, a.`Spell`, CONCAT('Vulpera - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 2 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 1 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 16777216, a.`classmask`, a.`Spell`, CONCAT('Zandalari - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 2 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 1 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 33554432, a.`classmask`, a.`Spell`, CONCAT('Kul Tiran - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 1 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 2 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`) VALUES
(8388608, 0, 669, 'Vulpera - Language Orcish'),
(16777216, 0, 669, 'Zandalari - Language Orcish'),
(33554432, 0, 668, 'Kul Tiran - Language Common');
