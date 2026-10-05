-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- Arcane Sentinel 300095 out-of-combat script, 2026-10-04
-- ---------------------------------------------------------------------------
-- rev_1790887680706947900 cloned Library Guardian 29724 as 300095 and copied every SmartAI
-- row, although clones are meant to keep only their combat rows. The copy brought the
-- out-of-combat "Run Script" row that starts Library Guardian's action list 2972400. That
-- list turns the guardian to the nearest Databank 29746, says line 0 and casts Data Stream on
-- the Databank. Map 37 has no Databank and 300095 has no creature_text, so every 45-60 s each
-- sentinel logged "SMART_ACTION_TALK ... using non-existent Text id 0 for talker 300095"
-- (290 times in a 45 min run) and set itself active for 12 s for nothing.
-- The On Aggro row (Set Rooted Off) stays.

DELETE FROM `smart_scripts`
WHERE `source_type` = 0 AND `entryorguid` = 300095 AND `event_type` = 1
    AND `action_type` = 80 AND `action_param1` = 2972400;
