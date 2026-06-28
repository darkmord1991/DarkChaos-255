-- =====================================================================
-- Deepholm Downport  --  26  Movement fixes (flyers falling + static world)
-- ---------------------------------------------------------------------
-- The TDB shipped Deepholm movement-incomplete: aerial NPCs had no
-- creature_template_movement row (=> gravity => "falling from the sky once a
-- player reaches them"), and ~100 ambient mob entries were MovementType=0 with
-- no wander (=> "lots of stuff is very static", Twilight Throne airspace empty).
-- Flight flag + wander intent recovered from Project Neltharion 4.3.4
-- (InhabitType air-list + per-spawn MovementType profile). Flight enum:
-- 0=None, 1=DisableGravity (stays aloft), 2=CanFly.
-- =====================================================================

-- ---------------------------------------------------------------------
-- A) Flyers: give airborne NPCs Flight=1 (DisableGravity) so they don't fall.
--    (Aeosera/Xariona/Stone Drake already had Flight=1; this fills the gaps:
--     Twilight Pyremaw 42824, Crystalwing 48520, Stonescale Drake 43971, etc.)
-- ---------------------------------------------------------------------
INSERT INTO `creature_template_movement` (`CreatureId`,`Ground`,`Swim`,`Flight`,`Rooted`,`Chase`,`Random`,`InteractionPauseTimer`) VALUES
(29876,0,0,1,0,0,0,0),
(41200,0,0,1,0,0,0,0),
(41957,0,0,1,0,0,0,0),
(42824,0,0,1,0,0,0,0),
(43971,0,0,1,0,0,0,0),
(44835,0,0,1,0,0,0,0),
(44888,0,0,1,0,0,0,0),
(44889,0,0,1,0,0,0,0),
(44890,0,0,1,0,0,0,0),
(45191,0,0,1,0,0,0,0),
(48520,0,0,1,0,0,0,0),
(48642,0,0,1,0,0,0,0),
(50061,0,0,1,0,0,0,0)
ON DUPLICATE KEY UPDATE `Flight`=1;

-- ---------------------------------------------------------------------
-- B) Un-static the ambient mobs: idle (MovementType=0) spawns of entries that
--    Neltharion moves (random/patrol) -> random wander. Excludes bosses
--    (scripted) and invisible triggers/credits/bunnies/platforms by name.
--    (True patrol routes are a later refinement; random wander >> frozen.)
-- ---------------------------------------------------------------------
UPDATE `creature` c
JOIN `creature_template` ct ON ct.`entry`=c.`id`
SET c.`MovementType`=1, c.`wander_distance`=GREATEST(c.`wander_distance`,5)
WHERE c.`map`=646 AND c.`MovementType`=0
  AND (c.`ScriptName`='' OR c.`ScriptName` IS NULL)
  AND ct.`name` NOT REGEXP 'Bunny|Trigger|Credit|Beam|Controller| Ward|Platform|Generic|Stalker Beam|Totem|Camera|Visual'
  AND c.`id` IN (41945,41946,41956,41957,41960,42475,42479,42521,42524,42525,42527,42606,42607,42779,42809,42861,43026,43123,43134,43158,43181,43234,43254,43258,43339,43358,43367,43374,43456,43545,43616,43752,43753,43755,43763,43765,43780,43785,43966,43967,43981,44035,44079,44218,44220,44221,44350,44351,44372,44425,44839,44936,44967,44988,45364,45988,47071,49758,49770,49771,49815,49816,50041,50060,53739,53894);
