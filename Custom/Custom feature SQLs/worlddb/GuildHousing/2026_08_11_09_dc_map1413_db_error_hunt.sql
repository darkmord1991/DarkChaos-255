-- =============================================================================
-- Map 1413 (Legion Dalaran guild house) -- DB error hunt, 2026-08-11
-- =============================================================================
-- Findings that are actually broken and fixable are below. A structural sweep of
-- the map came back CLEAN on: orphan creature/gameobject spawns, missing
-- creature_model_info, gossip_menu_id -> gossip_menu, gossip option -> menu/POI,
-- gossip_menu -> npc_text, npc_vendor -> item_template, lootid -> loot rows,
-- SmartAI-without-scripts, waypoint paths (all 30 MovementType-2 spawns resolve),
-- and chest lock ids (43/57/93/259/1691/1852 all exist in Lock.dbc).
-- =============================================================================

-- ---------- 1. SmartAI TEXT_OVER validates against the WRONG entry (13 rows, mine)
-- Boot log: "SmartAIMgr: Entry 3500045 ... using non-existent Text id 3, skipped."
-- x11, plus "Creature entry (3500112) has SmartAI enabled but no SmartAI entries".
--
-- The text groups DO exist. The catch is SMART_EVENT_TEXT_OVER (52): unlike every
-- other event, IsTextValid() resolves the text against `event_param2` (a creature
-- entry), NOT against entryorguid -- see SmartScriptMgr.cpp:2128-2131. My port
-- copied event_param2 verbatim, so it still held the RETAIL entry (90417 Khadgar,
-- 96644, 102534, 102700, 105602, 105689, 105691, 106337), which has no
-- creature_text here -> the whole row was dropped at load, and for 3500112 that
-- was its entire script.
--
-- Every one of those retail entries maps to the script owner itself, so the
-- correct value is simply entryorguid.
UPDATE `smart_scripts`
SET `event_param2` = `entryorguid`
WHERE `source_type` = 0 AND `event_type` = 52
  AND `entryorguid` BETWEEN 3500000 AND 3501999
  AND `event_param2` NOT BETWEEN 3500000 AND 3501999;

-- ---------- 2. Well teleporter carries an equipment_id it has no template for (mine)
-- The trigger NPC was cloned from a Dalaran vendor row, which brought
-- equipment_id = 1 along. It is an invisible trigger with no model, so it just
-- makes the core complain on load.
UPDATE `creature` SET `equipment_id` = 0 WHERE `guid` IN (16700001, 16700002);

-- ---------- 3. Duplicate spawns from the June city import (NOT mine) ----------
-- 28 creature spawns and 2 gameobject spawns are EXACT duplicates -- same entry,
-- same position to 0.000 yd. Among them the whole Council of Six (Khadgar,
-- Modera, Karlain, Ansirem, Kalec), Violet Hold Guards, Kirin Tor Summoners and
-- Illidari Enforcers, i.e. two copies of each standing inside one another.
-- This is the map-1220 / map-1502 overlap in the source: the same NPC is listed
-- on both maps under zone 7502, and the original import took both.
-- The lower guid of each pair is kept.
DELETE FROM `creature_addon` WHERE `guid` IN
 (9500559, 9500667, 9500668, 9500761, 9500840, 9500845, 9500846, 9500847, 9500848,
  9500882, 9500914, 9500932, 9500933, 9500934, 9500935, 9500946, 9500947, 9500955,
  9500956, 9500957, 9500958, 9500959, 9500960, 9500961, 9500965, 9500966, 9500967,
  9501068);
DELETE FROM `creature` WHERE `guid` IN
 (9500559, 9500667, 9500668, 9500761, 9500840, 9500845, 9500846, 9500847, 9500848,
  9500882, 9500914, 9500932, 9500933, 9500934, 9500935, 9500946, 9500947, 9500955,
  9500956, 9500957, 9500958, 9500959, 9500960, 9500961, 9500965, 9500966, 9500967,
  9501068);

DELETE FROM `gameobject_addon` WHERE `guid` IN (9600679, 9600710);
DELETE FROM `gameobject` WHERE `guid` IN (9600679, 9600710);
