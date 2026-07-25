-- ---------------------------------------------------------------------------
-- 144  Hyjal round-21 -- Thrall/Aggra wedding scene + 52 inert SmartAI warnings
-- ---------------------------------------------------------------------------
-- FIX 1 -- the quest 29331 "Elemental Bonds" wedding scene never plays.
--
-- Boot log (fresh restart, 2026-07-25):
--   SmartAIMgr: Entry 3654168 SourceType 0 Event 1 Action 1 using non-existent
--   Text id 0, skipped.            (and the same for events 2,3,4,5)
--
-- 102_ spawned Thrall (3654168) + Aggra (3654171) at Nordrassil, which unlocked
-- 29234/29331. Their SmartAI came across from nelt_world with the whole clone
-- block, but SMART_EVENT_TEXT_OVER's `event_param2` -- the entry of the creature
-- whose line just finished -- was left UN-OFFSET (raw 54168 / 54171). This is not
-- merely a cosmetic warning; the raw ids break the scene twice over:
--
--   * load time  -- SmartAIMgr::IsTextValid (SmartScriptMgr.cpp:2101) takes
--     `entry = e.event.textOver.creatureEntry` for TEXT_OVER events, so it looks
--     the text up on a creature id that does not exist here -> the row is
--     SKIPPED and never loaded at all.
--   * run time   -- SmartScript.cpp:4627 compares
--     `e.event.textOver.creatureEntry != var1`, where var1 is the entry of the
--     creature that actually spoke (the +3,600,000 clone). A raw id can never
--     match, so even a loaded row would never fire.
--
-- Result: only Thrall's opening line played (event 20, no TEXT_OVER involved) and
-- the six-step exchange died there -- Aggra never answered, Thrall never spoke his
-- vow, and he never despawned (his cleanup is chained off his last line).
-- Offsetting event_param2 fixes both failure modes.
--
-- The authored six-step scene, for reference:
--   T0 "In the face of this cataclysm..."  -> A0 "What are you saying, Go'el?"
--   -> T1 "Aggra... though I was not born on Draenor..." -> A1 "I stand before
--   you - Aggralan..." -> T2 "I stand before you - Go'el, Son of Durotan..."
--   -> T3 "For so long as I live..." -> Thrall despawns.
--
-- FIX 1b -- one unavoidable validator quirk. IsTextValid checks the text being
-- SAID against the creature named in event_param2 (the PREVIOUS speaker). That
-- works for self-talk chains but not for an alternating two-actor dialogue: the
-- step where Thrall says his group 2 is triggered by Aggra finishing her group 1,
-- so the validator demands that AGGRA own a group 2. She owns only 0 and 1 -- in
-- this DB and in nelt_world alike -- so that one row would still be skipped after
-- the offset, stalling the scene on Thrall's vow (the emotional payload) and
-- leaving him standing at Nordrassil forever.
--   Every alternative was worse: event_param2=0 also fails validation (`!entry`);
-- re-pointing the trigger at Thrall's own text collides with the row that makes
-- Aggra speak; and converting it to SMART_EVENT_LINK would fire instantly,
-- overlapping Thrall's vow with Aggra's line and losing the authored 17.5s pacing.
--   So a group-2 row is added for Aggra purely to satisfy the load-time check. It
-- is never spoken: nothing targets Aggra with text group 2 (she has no SmartAI of
-- her own, and Thrall's script only ever makes her say 0 and 1). Its text mirrors
-- her group-1 line so that it could not look broken if some future script did use
-- it, and its comment says exactly what it is.
--
-- FIX 2 -- 52 "has SmartAI enabled but no SmartAI entries" boot warnings.
-- Every one is a template carrying AIName='SmartAI' with ZERO smart_scripts rows
-- AND ZERO spawns, i.e. provably inert -- clearing AIName cannot change any
-- behaviour because there is nothing to run and nothing in the world to run it on:
--   * 48 x 990010-990075 -- the Beastmaster tameable-pet catalog (Horridon,
--     Fenryr, Deth'tilac, Elegon, ...). Tame targets driven by the pet system;
--     they never wanted SmartAI.
--   * 43396 Lord Victor Nefarius, 43404 Maloriak, 43407 Atramedes -- Blackwing
--     Descent boss placeholders (BWD is explicitly out of scope; when it is
--     scripted these get a ScriptName, which outranks AIName anyway).
--   * 49501 Golem Sentry -- the long-standing warning noted in the plan.
-- The WHERE re-derives that "provably inert" test at apply time, so it can never
-- strip AIName from a template that has gained SmartAI rows or spawns meanwhile.
--
-- Idempotent. Needs a worldserver restart.
-- ---------------------------------------------------------------------------

-- ---- FIX 1: offset the TEXT_OVER speaker ids onto the clones ----------------
UPDATE `smart_scripts` s
SET s.`event_param2` = s.`event_param2` + 3600000
WHERE s.`source_type` = 0
  AND s.`entryorguid` = 3654168
  AND s.`event_type` = 52
  AND s.`event_param2` IN (54168, 54171)
  AND EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`entry` = s.`event_param2` + 3600000);

-- ---- FIX 1b: load-validation placeholder so Thrall's vow is not skipped -----
DELETE FROM `creature_text` WHERE `CreatureID` = 3654171 AND `GroupID` = 2;
INSERT INTO `creature_text`
(`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
SELECT 3654171, 2, 0, t.`Text`, t.`Type`, t.`Language`, 100, t.`Emote`, t.`Duration`, 0, 0, t.`TextRange`,
       'Aggra - group 2 exists ONLY so SmartAIMgr::IsTextValid accepts Thrall 3654168 event 4 (TEXT_OVER validates the said text against the PREVIOUS speaker). Never played - see HyjalCata/144_.'
FROM `creature_text` t
WHERE t.`CreatureID` = 3654171 AND t.`GroupID` = 1 AND t.`ID` = 0;

-- ---- FIX 2: drop AIName from provably-inert templates -----------------------
UPDATE `creature_template` ct
SET ct.`AIName` = ''
WHERE ct.`AIName` = 'SmartAI'
  AND NOT EXISTS (SELECT 1 FROM `smart_scripts` s
                  WHERE s.`entryorguid` = ct.`entry` AND s.`source_type` = 0)
  AND NOT EXISTS (SELECT 1 FROM `creature` c WHERE c.`id` = ct.`entry`);

-- ---------------------------------------------------------------------------
-- STILL OPEN after this file (recorded so none of it is silently dropped):
--
-- * Spell 97678 -- Druid of the Flame (3654343) SmartAI event 0 casts it and it
--   exists in NEITHER the built client Spell.dbc NOR acore_world.spell_dbc, so
--   that ability is skipped. (Its other two casts, 17273 and 13878, are stock
--   3.3.5 spells and resolve from the DBC file -- only the Cata-era one is
--   missing, which is why the log names just 97678.) There is a proven path:
--   HyjalCata/tools/gen_hyjal_spell_downport.py (+ its r15/r16/r17 iterations),
--   which needs Spell.dbc + SpellEffect.dbc staged into k:/tmp/cata-dbc/ and the
--   index tables into k:/tmp/cata-locale/ from the Cata 4.3.4 client, then emits
--   both the spell_dbc SQL and the Custom/CSV DBC/Spell.csv rows for a Spell.dbc
--   recompile. Worth an r19 pass together with the pending food spells 300550-569.
--
-- * WaypointPath 16256 / 17238 -- referenced by SMART_ACTION_WP_START on clones
--   3616256 / 3617238. The paths exist in NO source (checked acore_world,
--   nelt_world and cata_world), and the un-cloned base creatures 16256/17238
--   log the identical warning, so this is an upstream gap rather than a downport
--   defect. Those two just stand still; hand-authoring the routes is the only fix.
--
-- * creature spawn guid 9010386 (map 745) points at entry 3461257, which exists
--   in no table and is not a +3,600,000 clone of anything (3461257-3600000 is
--   negative). The row is inert -- the core skips it -- but it is left in place
--   rather than deleted because map 745 is outside this zone's scope and the
--   intended creature cannot be inferred. Decide and delete/repoint it.
--
-- * AreaTrigger.dbc 9861/9862 still missing SERVER-side ("Area trigger (ID:9861)
--   does not exist in `AreaTrigger.dbc`"), so the Molten Front portal cannot fire
--   yet. This is the pending Linux DBC copy in HYJAL_MOLTENFRONT_HANDOFF §E0, not
--   a data bug.
-- ---------------------------------------------------------------------------
