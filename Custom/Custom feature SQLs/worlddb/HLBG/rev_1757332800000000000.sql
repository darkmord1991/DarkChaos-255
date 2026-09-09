-- Hinterland BG: raise the player cap to 40 per side (80-player matches).
UPDATE `battleground_template` SET `MaxPlayersPerTeam` = 40 WHERE `ID` = 20;

-- Hinterland BG faction bosses (Thrall 810002, Varian 810003).
--
-- They shipped at raid-boss scale: HealthModifier 335 on a level-80 base of
-- 12600 is ~4.2 million HP, and DamageModifier 35 two-shots a level-80 player.
-- Nothing short of an organised raid could touch them, so the 200-resource
-- prize - by far the largest single swing in the battleground's economy - had
-- never once been claimed. Rescaled to something a 10-15 player group can kill
-- under pressure: ~756k HP and 10x damage. Still the hardest thing on the map,
-- but now an objective rather than a monument.
UPDATE `creature_template` SET `HealthModifier` = 60, `DamageModifier` = 10 WHERE `entry` IN (810002, 810003);
