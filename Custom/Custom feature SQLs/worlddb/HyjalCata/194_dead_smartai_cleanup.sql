-- ---------------------------------------------------------------------------
-- 194  Hyjal round-45 -- the remaining dead SmartAI entries on map 750
-- ---------------------------------------------------------------------------
-- Eight entries on map 750 declared SmartAI with ZERO script rows, so the core
-- logs "has SmartAI enabled but no SmartAI entries in the database" and the AI
-- does nothing.  The obvious move -- clone the rows from the source -- turns out
-- to be WRONG for six of them, and needs a correction for a seventh.  Checking
-- each against the source individually:
--
--   4x Azsharite Formation (3752620/21/22/31) -- cata's own AIName is EMPTY and
--     it has no smart_scripts rows.  These are mining nodes: type 3 (chest),
--     lockId 43, lootId 9819, identical to cata's.  They are driven by lock +
--     loot, not by AI.  Our SmartGameObjectAI was set by the import, not
--     copied from the source.  There is nothing to clone -- the AIName itself
--     is the bug.
--
--   Dark Strand Cultist (3703725) / Dark Strand Excavator (3703730) -- same
--     story: cata has no AIName and no rows for either.  (nelt gives the
--     Cultist 'EventAI', a MaNGOS-era system this core does not run, so there
--     is nothing to convert.)  Also spurious.
--
--   Frostsaber Cub (3707430) -- nelt DOES have a row, but it casts spell
--     93157, which is absent from BOTH the client Spell.dbc and spell_dbc.
--     Cloning it would manufacture exactly the "non-existent Spell entry"
--     error that 192_ just cleaned up.  Its comment says "juju fury" (16323,
--     which we do have), so the id in the source is wrong -- and a 15%-on-death
--     player debuff is a nelt customisation, not Blizzard behaviour for a cub.
--     DELIBERATELY NOT IMPORTED.
--
--   Tome of Mel'Thandris (3619027) -- the one genuine script, imported below.
--
-- NOTE on entry 7430: it is "Young Frostsaber" in Cata but "Frostsaber Cub" in
-- WotLK.  Same creature, renamed between expansions -- not a mis-clone.
-- ---------------------------------------------------------------------------

-- --- 1. drop the spurious AI declarations ----------------------------------
UPDATE `gameobject_template` SET `AIName` = ''
WHERE `entry` IN (3752620, 3752621, 3752622, 3752631) AND `AIName` = 'SmartGameObjectAI';

UPDATE `creature_template` SET `AIName` = ''
WHERE `entry` IN (3703725, 3703730, 3707430) AND `AIName` = 'SmartAI';

-- --- 2. Tome of Mel'Thandris: summon Velinde Starsong on use ---------------
-- Cloned from cata_world 19027 with ONE deliberate change.  The source targets
-- SMART_TARGET_POSITION (8) with hardcoded coordinates 3169.15/-1211.71/216.95
-- -- but our Tome stands at 3124/-1475/193, some 264 YARDS away, so a verbatim
-- clone would summon Velinde in the wrong place entirely.  (Hardcoded
-- coordinates surviving a port is a known trap on this map.)
--
-- Using SMART_TARGET_SELF (1) instead summons her at the Tome's own position,
-- which is correct wherever the object stands and survives any future respawn
-- move.  Everything else is verbatim: SMART_EVENT_GO_STATE_CHANGED (70),
-- SMART_ACTION_SUMMON_CREATURE (12), 40s despawn.
--
-- Velinde Starsong is summoned as RAW entry 3946: she exists in our
-- creature_template as the stock WotLK NPC and is NOT cloned into the +3.6M
-- band, so the raw id is the only one that resolves.
DELETE FROM `smart_scripts` WHERE `entryorguid` = 3619027 AND `source_type` = 1;
INSERT INTO `smart_scripts`
  (`entryorguid`, `source_type`, `id`, `link`, `event_type`, `event_phase_mask`, `event_chance`,
   `event_flags`, `event_param1`, `event_param2`, `event_param3`, `event_param4`,
   `action_type`, `action_param1`, `action_param2`, `action_param3`, `action_param4`,
   `action_param5`, `action_param6`, `target_type`, `target_param1`, `target_param2`,
   `target_param3`, `target_x`, `target_y`, `target_z`, `target_o`, `comment`) VALUES
  (3619027, 1, 0, 0, 70, 0, 100, 0, 2, 0, 0, 0,
   12, 3946, 2, 40000, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
   "Tome of Mel'Thandris - On GO State Changed - Summon Velinde Starsong");

-- Verify -- expect 0 rows (no entry left declaring SmartAI with no script):
--   SELECT t.entry, t.name FROM `gameobject` g JOIN `gameobject_template` t ON t.entry = g.id
--    WHERE g.map = 750 AND t.AIName = 'SmartGameObjectAI'
--      AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.entryorguid = t.entry AND s.source_type = 1)
--   UNION ALL
--   SELECT t.entry, t.name FROM `creature` c JOIN `creature_template` t ON t.entry = c.id
--    WHERE c.map = 750 AND t.AIName = 'SmartAI'
--      AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s WHERE s.entryorguid = t.entry AND s.source_type = 0);
