-- Pandaren: starting class spells for races 22 (Alliance) / 23 (Horde).
-- Same rule as Worgoblin: class spells = intersection of the human(1) and orc(2)
-- sets (racials/languages are race-unique and drop out), plus the pandaren racials
-- appended explicitly. Racial spell rows are generated in Spell.dbc/spell_dbc by
-- tools/gen_pandaren_spells.py (MoP ids, verified against SkyFire_548).
DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` IN (2097152, 4194304, 6291456);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 2097152, a.`classmask`, a.`Spell`, CONCAT('Pandaren A - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 1 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 2 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`)
SELECT 4194304, a.`classmask`, a.`Spell`, CONCAT('Pandaren H - ', a.`Note`)
FROM `playercreateinfo_spell_custom` a
WHERE a.`racemask` = 2 AND EXISTS (
    SELECT 1 FROM `playercreateinfo_spell_custom` b
    WHERE b.`racemask` = 1 AND b.`Spell` = a.`Spell` AND b.`classmask` = a.`classmask`);

INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`) VALUES
(2097152, 0, 668,    'Pandaren A - Language Common'),
(4194304, 0, 669,    'Pandaren H - Language Orcish'),
(6291456, 0, 107072, 'Pandaren - Epicurean'),
(6291456, 0, 107073, 'Pandaren - Gourmand'),
(6291456, 0, 107074, 'Pandaren - Inner Peace'),
(6291456, 0, 107076, 'Pandaren - Bouncy'),
(6291456, 0, 107079, 'Pandaren - Quaking Palm');
