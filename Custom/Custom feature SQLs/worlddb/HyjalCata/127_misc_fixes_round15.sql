-- ---------------------------------------------------------------------------
-- 127  Hyjal round-15 -- the small stuff
-- ---------------------------------------------------------------------------

-- --- (1) Harpy Signal Fire: linked trap never cloned ------------------------
-- Seen live while flying map 750, repeating every time the button fires:
--     Gameobject (GUID: 584 Entry: 203189) not created: non-existing entry in
--     `gameobject_template`. Map: 750 (X: 4884.87 Y: -3042.44 Z: 1190.51)
-- Those low, climbing GUIDs are the map's RUNTIME object counter, not spawn
-- ids -- nothing in `gameobject` has entry 203189.  The summoner is GO 3803187
-- "Harpy Signal Fire" (type 1 = BUTTON), whose `Data3` is button.linkedTrap
-- (GameObjectData.h:60): it still holds the raw Cata id 203189 and that trap
-- ("Harpy Signal Fire (Trap)") was never imported.  A sweep of every
-- linked-trap slot (Data1/3/9/12 by GO type) across the whole 3.8M block found
-- this as the only instance.
-- Clone the trap at the offset id, then repoint the button at it.
INSERT IGNORE INTO acore_world.gameobject_template
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
SELECT entry+3600000, type, displayId, name, IconName, castBarCaption, unk1, size, Data0, Data1, Data2, Data3, Data4, Data5, Data6, Data7, Data8, Data9, Data10, Data11, Data12, Data13, Data14, Data15, Data16, Data17, Data18, Data19, Data20, Data21, Data22, Data23, AIName, '', 0
FROM cata_world.gameobject_template WHERE entry = 203189;

-- (MySQL forbids naming the UPDATE target inside a subquery -- error 1093 --
--  so the "does the trap exist" guard is expressed as a JOIN instead.)
UPDATE `gameobject_template` gt
JOIN `gameobject_template` t ON t.`entry` = 3803189
SET gt.`Data3` = 3803189
WHERE gt.`entry` = 3803187 AND gt.`Data3` = 203189;

-- --- (2) spellclick flag with no spellclick rows -----------------------------
--     npc_spellclick_spells: Creature template 3653131 has
--     UNIT_NPC_FLAG_SPELLCLICK but no data in spellclick table! Removing flag
-- 3653131 "Lava Bubbles" and 3653243 "Injured Druid of the Talon" -- both are
-- click-to-interact Molten Front objectives, so dropping the flag (what the
-- core does) breaks them.  Both rows exist in nelt_world; import rather than
-- let the flag be stripped.
INSERT IGNORE INTO acore_world.npc_spellclick_spells (`npc_entry`,`spell_id`,`cast_flags`,`user_type`)
SELECT npc_entry+3600000, spell_id, cast_flags, user_type
FROM nelt_world.npc_spellclick_spells WHERE npc_entry IN (53131,53243);

-- --- (3) one more un-offset SmartAI kill credit ------------------------------
--     SmartAIMgr: Entry 3653249 SourceType 0 Event 1 Action 33 uses
--     non-existent Creature entry 53249, skipped.
-- Fire Hawk Matriarch crediting herself -- same shape as everything 113_ fixed,
-- just newly visible now that map 861 is loaded.
UPDATE `smart_scripts` s SET s.`action_param1` = s.`action_param1` + 3600000
WHERE s.`source_type` = 0 AND s.`entryorguid` = 3653249 AND s.`action_type` = 33
  AND s.`action_param1` = 53249
  AND EXISTS (SELECT 1 FROM `creature_template` c WHERE c.`entry` = 3653249);

-- --- (4) SmartAI declared with genuinely zero rows ---------------------------
-- 3653240 Emberspit Scorpion and 3675046 "Wondi's Bunny - Generic Nearby
-- Target 3" have AIName='SmartAI' and no smart_scripts rows in ANY source DB.
-- (The other ~15 entries in that boot warning DO have rows -- every row was
-- being skipped for a missing spell, and 123_ fixes those.)
UPDATE `creature_template` ct SET ct.`AIName` = ''
WHERE ct.`entry` IN (3653240,3675046)
  AND ct.`AIName` = 'SmartAI' AND ct.`ScriptName` = ''
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0);
