-- ============================================
-- DarkChaos-255 Prestige System
-- Spell Script Names
-- ============================================
-- This assigns the C++ spell scripts to the prestige spells
-- Run this on your acore_world database
-- ============================================

DELETE FROM `spell_script_names` WHERE `ScriptName` IN (
    'spell_prestige_bonus_1',
    'spell_prestige_bonus_2',
    'spell_prestige_bonus_3',
    'spell_prestige_bonus_4',
    'spell_prestige_bonus_5',
    'spell_prestige_bonus_6',
    'spell_prestige_bonus_7',
    'spell_prestige_bonus_8',
    'spell_prestige_bonus_9',
    'spell_prestige_bonus_10'
);

INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(800002, 'spell_prestige_bonus_1'),
(800003, 'spell_prestige_bonus_2'),
(800004, 'spell_prestige_bonus_3'),
(800005, 'spell_prestige_bonus_4'),
(800006, 'spell_prestige_bonus_5'),
(800007, 'spell_prestige_bonus_6'),
(800008, 'spell_prestige_bonus_7'),
(800009, 'spell_prestige_bonus_8'),
(800010, 'spell_prestige_bonus_9'),
(800011, 'spell_prestige_bonus_10');
