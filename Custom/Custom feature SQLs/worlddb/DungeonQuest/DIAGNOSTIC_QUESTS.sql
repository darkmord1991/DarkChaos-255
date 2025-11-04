-- =====================================================================
-- DIAGNOSTIC: CHECK ACTUAL QUEST STARTERS IN DATABASE
-- =====================================================================

-- 1. Verify NPC 700001 quest starters exist
SELECT id, quest, COUNT(*) 
FROM creature_queststarter 
WHERE id = 700001 
GROUP BY id;

-- 2. List ALL quests for NPC 700001
SELECT id, quest 
FROM creature_queststarter 
WHERE id = 700001 
ORDER BY quest;

-- 3. Verify these quests exist in quest_template
SELECT qt.ID, qt.Title 
FROM creature_queststarter cqs
LEFT JOIN quest_template qt ON cqs.quest = qt.ID
WHERE cqs.id = 700001
ORDER BY cqs.quest;

-- 4. Check NPC 700001 in creature_template
SELECT entry, name, npcflag, gossip_menu_id, ScriptName
FROM creature_template
WHERE entry = 700001;

-- 5. Check for any gossip_menu entries that might block quests
SELECT * FROM gossip_menu WHERE menu_id IN (
  SELECT gossip_menu_id FROM creature_template WHERE entry = 700001
);

-- 6. Check creature_questender too
SELECT id, quest, COUNT(*)
FROM creature_questender
WHERE id = 700001
GROUP BY id;

-- =====================================================================
-- POTENTIAL FIX: Add gossip_menu entries for all quest NPCs
-- =====================================================================
-- If the above shows no gossip_menu entries, AzerothCore should auto-show quests
-- But if something is blocking it, we need to explicitly create gossip entries

-- First, find available gossip menu IDs
SELECT MAX(menu_id) FROM gossip_menu;

-- Then assign unique gossip_menu_ids to all quest NPCs (if needed)
-- This might be required for the quest list to display properly

-- =====================================================================
-- ALTERNATIVE FIX: Force gossip_menu_id to 0 (auto-generate)
-- =====================================================================
UPDATE creature_template
SET gossip_menu_id = 0
WHERE entry BETWEEN 700000 AND 700054
AND ScriptName = 'npc_dungeon_quest_master';

-- =====================================================================
-- CHECK: After importing, verify quest assignments loaded
-- =====================================================================
SELECT 
  cqs.id as NPC_Entry,
  COUNT(cqs.quest) as Quest_Count,
  MIN(cqs.quest) as First_Quest,
  MAX(cqs.quest) as Last_Quest
FROM creature_queststarter cqs
WHERE cqs.id BETWEEN 700000 AND 700054
GROUP BY cqs.id
ORDER BY cqs.id;

