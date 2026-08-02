-- ---------------------------------------------------------------------------
-- 195  Hyjal round-45 -- stop offering the quests that cannot be completed
-- ---------------------------------------------------------------------------
-- Map 750 offers 45 quests that a player can accept and then never finish,
-- because the pieces they need are on other maps.  They show a "!" over an NPC,
-- fill a log slot and dead-end.  This file stops them being OFFERED.
--
-- THE TWO CATEGORIES ARE NOT THE SAME THING, and were checked separately:
--
--  43 have NO QUEST ENDER ANYWHERE.  Structurally unfinishable -- verified
--     earlier by tracing every ender's position: they sit in Kalimdor proper,
--     Eastern Kingdoms, Deepholm and the Molten Front.  Nothing to fix.
--
--   2 DO have an ender here but still cannot be completed:
--     25729 "Gerenzo the Traitor"  -- needs to kill Gerenzo Wrenchwhistle
--            (4202).  Zero spawns on map 750 in ANY offset band (raw, +3.6M,
--            +3.7M).
--     29234 "Delegation"           -- needs item 69646 "Branch of Nordrassil",
--            which has NO source at all here: no creature drop, no gameobject
--            loot, no vendor, no quest reward anywhere, no SourceSpell and no
--            previous quest to grant it.
--
-- THREE QUESTS ARE DELIBERATELY KEPT even though they have no POI marker.
-- "No POI" only means no map pin -- it does NOT mean unfinishable, and deleting
-- them would have destroyed working content:
--     28395 "Feathers for Nafien" / 28396 "Feathers for Grazle" -- both need
--            item 21377 "Deadwood Headdress Feather", which drops from NINE
--            creature types spawned on this map.  Fully completable.
--     29199 "Calling for Reinforcements" -- has no kill or item objective at
--            all and its ender is spawned here.  Fully completable.
--
-- WHAT IS AND IS NOT REMOVED.  Only the QUESTGIVER LINKS go: the quest_template
-- rows stay. That is deliberate --
--   * a player who already has one of these in their log keeps a valid quest
--     object instead of hitting a dangling id,
--   * the templates are inert once nothing offers them,
--   * and other maps may legitimately reference the same ids.
-- 28 of the 43 are a PrevQuestID for some follow-up, but those follow-ups are
-- ALREADY unobtainable (their prerequisite could never be completed), so
-- removing the offer changes nothing for them.
--
-- Also clears the two ENDER links for 25729/29234 so those NPCs stop showing a
-- "?" for a quest nobody can hold.
--
-- ORDER: must run AFTER 180_ -- that file recreates queststarter links from the
-- Cata source, so running it later would put these back.
-- ---------------------------------------------------------------------------

-- --- creature questgivers --------------------------------------------------
DELETE qs FROM `creature_queststarter` qs
JOIN `creature` c ON c.`id` = qs.`id` AND c.`map` = 750
WHERE qs.`quest` IN (13619,13653,13798,13805,13841,13866,13879,13888,14267,14308,14389,14413,
                     14428,14442,14475,24448,25297,25300,25411,25613,25616,25640,25663,25729,
                     25945,26044,26058,26294,26335,26388,26416,27398,27399,28129,28131,28153,
                     28229,28479,28732,28745,29202,29234,29284,29326,29437);

-- --- gameobject questgivers (8 of them are also started by an object) ------
DELETE gs FROM `gameobject_queststarter` gs
JOIN `gameobject` g ON g.`id` = gs.`id` AND g.`map` = 750
WHERE gs.`quest` IN (13619,13653,13798,13805,13841,13866,13879,13888,14267,14308,14389,14413,
                     14428,14442,14475,24448,25297,25300,25411,25613,25616,25640,25663,25729,
                     25945,26044,26058,26294,26335,26388,26416,27398,27399,28129,28131,28153,
                     28229,28479,28732,28745,29202,29234,29284,29326,29437);

-- --- the two orphaned ender links -----------------------------------------
DELETE qe FROM `creature_questender` qe
JOIN `creature` c ON c.`id` = qe.`id` AND c.`map` = 750
WHERE qe.`quest` IN (25729, 29234);

DELETE ge FROM `gameobject_questender` ge
JOIN `gameobject` g ON g.`id` = ge.`id` AND g.`map` = 750
WHERE ge.`quest` IN (25729, 29234);

-- Verify -- expect 0 unfinishable quests still offered on map 750, and the
-- three keepers still present:
--   SELECT COUNT(DISTINCT qs.quest) FROM `creature_queststarter` qs
--     JOIN `creature` c ON c.id = qs.id
--    WHERE c.map = 750
--      AND qs.quest NOT IN (SELECT quest FROM `creature_questender`)
--      AND qs.quest NOT IN (SELECT quest FROM `gameobject_questender`);
--   SELECT DISTINCT qs.quest FROM `creature_queststarter` qs
--     JOIN `creature` c ON c.id = qs.id
--    WHERE c.map = 750 AND qs.quest IN (28395, 28396, 29199);   -- expect 3 rows
