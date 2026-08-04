-- ---------------------------------------------------------------------------
-- 248  Map 750 -- SmartAI/ScriptName repairs, round 2 (post-211/212/176 audit)
-- ---------------------------------------------------------------------------
-- Full re-audit 2026-08-04 of SmartAI + C++ coverage for every map-750 zone
-- against cata_world and the cata source cores, prompted by the suspicion that
-- Azshara/Ashenvale scripts were never ported.
--
-- VERDICT: the imports did NOT skip smart_scripts -- 0 of 1,618 spawned
-- templates have cata SmartAI rows we lack, and gameobject coverage is 100%.
-- The real defects are smaller and inverted:
--
--   A) 52 creature templates HAVE their smart_scripts rows but AIName = ''
--      (stomped by a later import pass), so SmartAI is never instantiated --
--      elites like Garr, Cindermaul, King Moltron, Nemesis, the Winterspring
--      rares and the Ashenvale town guards just melee with no abilities.
--      Every requirement of those rows was verified present (61 CAST spells
--      all resolve, 4 TALK texts imported, action lists + waypoint paths all
--      exist), so restoring AIName is safe standalone. +1 gameobject (Bonfire).
--   B) 3 stable masters lost their ScriptName in the clone (the script is
--      stock core code) -- includes Jaelysia at the Lor'danel start hub.
--   C) 1 untranslatable row: Arch Druid of Hyjal's on-reset cast targets a
--      CATA SPAWN GUID (target_type 10, guid 384466) that cannot exist here.
--
-- NOT defects (checked, left alone): 5 entries whose dormant rows are covered
-- by registered C++ (grudge match, Whisperwind Lasher, Moonglade flight
-- masters, Rabid Thistle Bear); Scourgelord Tyrannus set-dressing
-- (NullCreatureAI); Ashenvale/Winterspring vanilla scripts (Muglash,
-- Ranshalla, Clintar...) whose clones carry the stock ScriptNames correctly.
--
-- Known remaining (documented, deliberately NOT in this file):
--   * 72 entries imported with fewer rows than source (115 rows, mostly extra
--     combat casts/talks) -- 10 of the dropped casts need spell_dbc downports
--     (80009, 80012, 80066, 80068, 80546, 81020, 87420, 89399, 91997, 91998)
--     and cata action list 384801; a partial-import round can follow.
--   * Azshara flight/escort choreography C++ (Wings of Steel vehicle chain,
--     Sentinel Aynasha escort): quests 14464/13510/14430 are objective-less in
--     BOTH DBs (faithful import, they complete as report-to quests) -- the C++
--     adds the show, not completability. Port as its own round if wanted.
--
-- Idempotent (absolute UPDATEs + guarded DELETE). Restart worldserver after
-- apply (AIName/ScriptName are template-load-time).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- A) restore AIName on the 52 pinned creature templates
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `AIName` = 'SmartAI'
WHERE `ScriptName` = '' AND `AIName` = '' AND `entry` IN (
    -- Hyjal 4923 (26)
    3638896, 3638913, 3639445, 3639642, 3640139, 3640150, 3640229, 3640464,
    3640536, 3640573, 3640709, 3640713, 3640767, 3640814, 3640844, 3640998,
    3641029, 3641030, 3641031, 3641502, 3641565, 3641614, 3650055, 3650056,
    3650057, 3650058,
    -- Winterspring 4926 (3)
    3607458, 3710197, 3710200,
    -- Felwood 4927 (5)
    3702803, 3707126, 3714339, 3714344, 3715315,
    -- Moonglade 4928 (5)
    3611822, 3711822, 3722835, 3722889, 3722902,
    -- Darkshore 4929 (1)
    3711711,
    -- Azshara 4930 (4)
    3606350, 3606352, 3606372, 3606649,
    -- Ashenvale 4931 (8)
    3603812, 3603916, 3603932, 3606087, 3608015, 3612123, 3612903, 3617406);

UPDATE `gameobject_template` SET `AIName` = 'SmartGameObjectAI'
WHERE `entry` = 3961927 AND `AIName` = '';

-- ---------------------------------------------------------------------------
-- B) stable masters: restore the stock ScriptName the clone dropped
-- ---------------------------------------------------------------------------
UPDATE `creature_template` SET `ScriptName` = 'npc_stable_master'
WHERE `entry` IN (3748216, 3710085, 3743617) AND `ScriptName` = '';

-- ---------------------------------------------------------------------------
-- C) drop the cross-DB-untranslatable row (cast at a cata spawn guid)
-- ---------------------------------------------------------------------------
DELETE FROM `smart_scripts`
WHERE `entryorguid` = 3640150 AND `source_type` = 0 AND `target_type` = 10;

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- all 52 now instantiate (expect 52):
-- SELECT COUNT(*) FROM creature_template WHERE AIName = 'SmartAI' AND entry IN
--   (3638896, 3650056, 3641614, 3710197, 3714344, 3711711, 3606649, 3617406);
--   -- (spot list; full set above)
-- no SmartAI-with-zero-rows anomalies introduced (expect 0):
-- SELECT ct.entry FROM creature_template ct
-- WHERE ct.AIName = 'SmartAI' AND ct.entry BETWEEN 3600000 AND 3799999
--   AND NOT EXISTS (SELECT 1 FROM smart_scripts s
--                   WHERE s.entryorguid = ct.entry AND s.source_type = 0);
-- stable masters (expect 3):
-- SELECT entry, ScriptName FROM creature_template
-- WHERE entry IN (3748216, 3710085, 3743617);
-- the tt10 row is gone (expect 0):
-- SELECT COUNT(*) FROM smart_scripts
-- WHERE entryorguid = 3640150 AND source_type = 0 AND target_type = 10;
-- In-game after restart: pull Garr (3650056) or Cindermaul (3640844) --
-- abilities must fire; open the stable at Jaelysia in Lor'danel.
