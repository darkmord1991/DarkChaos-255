-- DC Naxx40 (map 2921): bind Sapphiron's Frost Explosion (28524) to the Naxx40 spell script.
-- AC 2026_11_24_02 removed the stock spell_sapphiron_frost_explosion and its row. Naxx40 had registered its own class
-- under that stock name and relied on the row to spare players hiding behind an Ice Block; the class is now
-- spell_sapphiron_frost_explosion_40 and needs its own row. On stock map 533 the script leaves the targets alone.
DELETE FROM `spell_script_names` WHERE `spell_id` = 28524 AND `ScriptName` = 'spell_sapphiron_frost_explosion_40';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(28524, 'spell_sapphiron_frost_explosion_40');
