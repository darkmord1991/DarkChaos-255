-- =====================================================================================
-- SERVER CRASH FIX -- gameobject_template.AIName = 'SmartAI' segfaults the worldserver
--
-- Nothing to do with Shadowfang Keep; found from the stack trace of a crash on map 751.
-- Apply this before anything else in this directory.
--
-- ---------------------------------------------------------------------------------
-- THE CRASH
-- ---------------------------------------------------------------------------------
--     Thread 14 "worldserver" received signal SIGSEGV
--     #0  FactorySelector::SelectGameObjectAI (go=...) at CreatureAISelector.cpp:108
--     #1  GameObject::AIM_Initialize                  at GameObject.cpp:106
--     #2  GameObject::Create (name_id=4701852, x=2889.17, y=-827.80, z=160.29)
--     #3  GameObject::LoadGameObjectFromDB
--     #5  GridObjectLoader::LoadGameObjects
--     #7  MapGridManager::LoadGrid (x=26, y=33)
--     #9  Map::PlayerRelocation
--
-- CreatureAISelector.cpp:104-108:
--     GameObjectAI* SelectGameObjectAI(GameObject* go)
--     {
--         if (GameObjectAI* scriptedAI = sScriptMgr->GetGameObjectAI(go))
--             return scriptedAI;
--         return SelectFactory<GameObjectAI>(go)->Create(go);   // <-- no null guard
--     }
--
-- `SelectFactory` looks the AIName up in the GameObjectAI registry. **'SmartAI' is the
-- CREATURE ai name; the GameObject one is 'SmartGameObjectAI'.** There is no GameObjectAI
-- factory registered under 'SmartAI', so the lookup returns nullptr and the unguarded
-- `->Create(go)` dereferences it. Note the movement-generator call three lines above does
-- use ASSERT_NOTNULL -- this path simply does not.
--
-- The crash therefore fires the instant ANY player walks into a grid containing one of
-- these objects. It is not a rare race: it is deterministic, and it takes the whole
-- worldserver down.
--
-- ---------------------------------------------------------------------------------
-- SCOPE
-- ---------------------------------------------------------------------------------
-- 8 templates, ALL of them spawned, ALL on map 751:
--     4600375  Tirisfal Pumpkin        10 spawns
--     4601557  Lillith's Dinner Table   1
--     4602688  Keystone                 1
--     4701852  Lever                    1   <- the one in the trace
--     4701853  Lever                    1
--     4713531  Cannon                   1
--     4780437  Wickerman Ashes          9
--     4780666  Draconic for Dummies     1
--
-- Every one already has smart_scripts rows with source_type = 1 (the GameObject kind), so
-- the intent was always SmartGameObjectAI -- only the name is wrong. That means the fix is
-- a rename, not a removal, and the scripted behaviour starts working rather than being
-- switched off.
--
-- For contrast, the 735 templates that already say 'SmartGameObjectAI' are fine.
-- =====================================================================================

UPDATE `gameobject_template`
SET `AIName` = 'SmartGameObjectAI'
WHERE `AIName` = 'SmartAI';

-- -------------------------------------------------------------------------------------
-- Report -- all branches numeric (see the collation note in 12).
-- -------------------------------------------------------------------------------------
SELECT 'GO templates still on the crashing AIName (want 0)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `gameobject_template` WHERE `AIName` = 'SmartAI'
UNION ALL SELECT 'GO templates on SmartGameObjectAI (want 743)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `AIName` = 'SmartGameObjectAI'
UNION ALL SELECT 'the 8 repaired, now correct (want 8)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template`
    WHERE `entry` IN (4600375, 4601557, 4602688, 4701852, 4701853, 4713531, 4780437, 4780666)
      AND `AIName` = 'SmartGameObjectAI'
-- Any GO AIName that is neither empty nor SmartGameObjectAI has no factory and will crash
-- the same way. This is the check to re-run after any future gameobject_template import.
UNION ALL SELECT 'GO templates with an unknown AIName - would crash (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `gameobject_template` WHERE `AIName` <> '' AND `AIName` <> 'SmartGameObjectAI'
-- Creature AINames are a separate registry and must NOT be touched by the UPDATE above.
UNION ALL SELECT 'creature_template still using SmartAI (unchanged, expect many)', CAST(COUNT(*) AS CHAR)
    FROM `creature_template` WHERE `AIName` = 'SmartAI';
