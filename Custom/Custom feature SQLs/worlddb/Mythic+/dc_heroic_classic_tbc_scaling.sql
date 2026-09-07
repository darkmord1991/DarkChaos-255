-- =====================================================================
-- Classic / TBC dungeons: Heroic moves to WotLK heroic levels
-- =====================================================================
-- Apply against: acore_world. Safe to re-run.
--
-- Pairs with the runtime change in dc_mythicplus_core_scripts.cpp
-- (OnCreatureSelectLevel). Applying only one of the two leaves the
-- dungeons mis-tuned - see WHY below.
--
-- WHY
-- ---------------------------------------------------------------------
-- 1. Heroic was dead content. dc_dungeon_mythic_profile put Vanilla
--    heroic at level 60/61/62 and left TBC heroic at 0 (= keep the stock
--    ~70). Against a level-80 party those are grey mobs: no threat, no
--    xp, and the level delta alone makes them miss almost every swing.
--    Only Mythic (80/81/82) was reachable content.
--
-- 2. The multipliers were compensating for the wrong thing.
--    creature_classlevelstats has three stat columns and AzerothCore
--    picks one by creature_template.exp. Vanilla dungeon creatures are
--    exp=0, TBC exp=1, WotLK exp=2, and at level 81 those columns read:
--
--        HP      5492 (exp0)  9474 (exp1)  13033 (exp2)
--        damage  47.9 (exp0)  133.0 (exp1)  169.0 (exp2)
--
--    The old Vanilla/TBC Mythic multipliers of 3.0x HP / 2.0x damage
--    were chosen to close that gap. 3.0x roughly does close it for HP
--    (5492 * 3.0 = 16476 vs 13033 * 1.35 = 17595), but 2.0x does not
--    come close for damage (47.9 * 2.0 = 96 vs 169.0 * 1.2 = 203).
--    Classic and TBC bosses ended up as damage sponges that could not
--    kill anyone.
--
-- WHY THIS IS NOT "UPDATE creature_template SET exp = 2"
-- ---------------------------------------------------------------------
-- That was the obvious fix and it is wrong: creature_classlevelstats
-- .basehp2 is unpopulated (= 1) below level 55 AND again at levels
-- 60-63. Flipping exp on the templates would give Normal-mode Deadmines
-- mobs (level 17-20) exactly 1 HP. The expansion column is therefore
-- normalised at runtime, inside OnCreatureSelectLevel, where the level
-- has already been forced to 80-82 and basehp2 is valid. Normal mode
-- never enters that path and is untouched.
--
-- WHAT THE RUNTIME DOES WITH THESE NUMBERS
-- ---------------------------------------------------------------------
-- For Classic/TBC maps at Heroic or Mythic the creature is rebuilt as:
--
--     HP     = basehp2[level]     * HealthModifier * 1.55  * difficulty
--     damage = damage_exp2[level] * DamageModifier * 1.733 * difficulty
--
-- The 1.55 / 1.733 pair is not invented. It is Blizzard's own normal ->
-- heroic conversion, read straight out of the WotLK dungeon templates,
-- where it is strikingly consistent:
--
--     Ingvar        HealthModifier 12.5 -> 19   DamageModifier 7.5 -> 13
--     Trollgore                    20   -> 32                  7.5 -> 13
--     Tharon'ja                    25   -> 38                  7.5 -> 13
--     King Ymiron                  30   -> 42                  7.5 -> 13
--     Slad'ran                     15   -> 24                  7.5 -> 13
--
-- Classic/TBC dungeons have no heroic template to read those from - that
-- is the whole problem - so the factor is applied to the normal template
-- instead, which reproduces what the heroic template would have been.
--
-- 'difficulty' is then the same modest step the WotLK maps already use:
-- 1.15/1.10 at Heroic, and base_health_mult/base_damage_mult at Mythic,
-- which this file drops from 3.0/2.0 to 1.35/1.20 to match them.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Heroic now runs at WotLK heroic levels on Classic and TBC maps.
--    80 trash / 81 elite / 82 boss, matching Utgarde Keep through
--    Halls of Reflection.
-- ---------------------------------------------------------------------
UPDATE `dc_dungeon_mythic_profile` p
JOIN `dc_dungeon_setup` s ON s.`map_id` = p.`map_id`
SET p.`heroic_level_normal` = 80,
    p.`heroic_level_elite`  = 81,
    p.`heroic_level_boss`   = 82
WHERE s.`expansion` IN (0, 1)
  AND p.`map_id` < 800;

-- ---------------------------------------------------------------------
-- 2) Mythic multipliers drop to the WotLK values. The runtime now puts
--    Classic/TBC creatures on the exp2 curve before these apply, so the
--    old 3.0/2.0 compensation would stack on top and overshoot badly.
-- ---------------------------------------------------------------------
UPDATE `dc_dungeon_mythic_profile` p
JOIN `dc_dungeon_setup` s ON s.`map_id` = p.`map_id`
SET p.`base_health_mult` = 1.35,
    p.`base_damage_mult` = 1.20
WHERE s.`expansion` IN (0, 1)
  AND p.`map_id` < 800;

-- ---------------------------------------------------------------------
-- 3) The custom DC dungeons on the 8xx maps are deliberately excluded
--    above (map_id < 800). Timbermaw Hold, BFD-Ashenvale, Crescent Grove
--    and Emerald Sanctum are level-130 content on their own curve, and
--    pulling them onto the level-82 WotLK curve would flatten them.
--    Listed here so the omission is visible rather than accidental:
--      819 Timbermaw Hold, 820 Blackfathom Deeps (Ashenvale),
--      823 Crescent Grove, 824 Emerald Sanctum, 2921 Naxxramas (40).
-- ---------------------------------------------------------------------


-- =====================================================================
-- Verification
-- =====================================================================
-- Heroic and Mythic levels for Classic/TBC should now read 80/81/82 and
-- 80/81/82, with multipliers 1.35 / 1.20:
--
--   SELECT p.map_id, p.name, p.heroic_level_normal, p.heroic_level_elite,
--          p.heroic_level_boss, p.base_health_mult, p.base_damage_mult
--   FROM dc_dungeon_mythic_profile p
--   JOIN dc_dungeon_setup s ON s.map_id = p.map_id
--   WHERE s.expansion IN (0,1) AND p.map_id < 800
--   ORDER BY s.expansion, p.map_id;
--
-- No Classic/TBC dungeon may still sit on the old compensation values
-- (expect 0 rows):
--
--   SELECT p.map_id, p.name FROM dc_dungeon_mythic_profile p
--   JOIN dc_dungeon_setup s ON s.map_id = p.map_id
--   WHERE s.expansion IN (0,1) AND p.map_id < 800
--     AND (p.base_health_mult > 2 OR p.base_damage_mult > 1.5
--          OR p.heroic_level_boss <> 82);
--
-- The 8xx custom dungeons must be untouched (expect their old values):
--
--   SELECT map_id, name, heroic_level_boss, base_health_mult
--   FROM dc_dungeon_mythic_profile WHERE map_id >= 800;
--
-- Sanity check the resulting boss budget against a real WotLK heroic
-- boss. At level 82 with the 1.55/1.733 conversion and the 1.15/1.10
-- heroic step, a Classic boss should land in the same order of magnitude
-- as heroic Ingvar (~294k HP, ~2470 swing):
--
--   SELECT ct.entry, ct.name, ct.HealthModifier, ct.DamageModifier,
--          ROUND(l.basehp2 * ct.HealthModifier * 1.55 * 1.15) AS hp_heroic,
--          ROUND(l.damage_exp2 * ct.DamageModifier * 1.733 * 1.10, 1) AS dmg_heroic
--   FROM creature_template ct
--   JOIN creature_classlevelstats l
--     ON l.class = ct.unit_class AND l.level = 82
--   WHERE ct.entry IN (4275, 1853, 10813, 645, 11501);
-- =====================================================================
