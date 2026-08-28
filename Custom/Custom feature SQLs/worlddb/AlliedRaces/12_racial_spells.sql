-- Allied races: grant the racial spells at character creation.
--
-- Racemasks: Vulpera (24) 1 << 23 = 8388608, Zandalari Troll (25) 1 << 24 = 16777216,
-- Kul Tiran (26) 1 << 25 = 33554432. Same mechanism as the Pandaren set in
-- ../Pandaren/04_playercreateinfo_spell_custom.sql.
--
-- 312925 (Nose for Trouble, triggered) is deliberately NOT granted: it is the damage the passive
-- 312924 procs, and granting it would put a second copy in the spellbook.
--
-- Design and the list of racials deliberately not shipped: 00_RACIALS.md.

DELETE FROM `playercreateinfo_spell_custom` WHERE `Spell` IN
    (312411, 312924, 265225, 291944, 281954, 291628, 287712, 280331, 287829);
INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`) VALUES
(8388608,  0, 312411, 'Vulpera - Bag of Tricks'),
(8388608,  0, 312924, 'Vulpera - Nose for Trouble'),
(8388608,  0, 265225, 'Vulpera - Fire Resistance'),
(16777216, 0, 291944, 'Zandalari Troll - Regeneratin'),
(16777216, 0, 281954, 'Zandalari Troll - Pterrordax Swoop'),
(16777216, 0, 291628, 'Zandalari Troll - City of Gold'),
(33554432, 0, 287712, 'Kul Tiran - Haymaker'),
(33554432, 0, 280331, 'Kul Tiran - Child of the Sea'),
(33554432, 0, 287829, 'Kul Tiran - Rime of the Ancient Mariner');
