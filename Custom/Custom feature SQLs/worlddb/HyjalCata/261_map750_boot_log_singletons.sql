-- ---------------------------------------------------------------------------
-- 261  Map 750 -- the four one-off defects left in the boot log
-- ---------------------------------------------------------------------------
-- Everything here is small, independently verified against source, and
-- unrelated to the other files in this round except that 258_ must be applied
-- first (section 2 casts two spells it downports).

-- ---- 1. six clones that lost UNIT_NPC_FLAG_QUESTGIVER ----------------------
--     Table `creature_queststarter` has creature entry (3707139) for quest
--     28221, but npcflag does not include UNIT_NPC_FLAG_QUESTGIVER
--
-- The relation rows are correct -- all six carry npcflag = 2 in cata_world, so
-- these really are questgivers and it is our clones that lost the flag, not the
-- relations that were invented. Five are Winterspring/Felwood rare mobs that
-- offer a quest on sight (Cata does this a lot); Grabbit is a plain NPC.
--
--   3707139 Irontree Stomper .......... starts 28221
--   3707149 Withered Protector ........ starts 28224
--   3707434 Frostsaber Pride Watcher .. starts 28641
--   3707443 Shardtooth Mauler ......... starts 28719
--   3710806 Ursius .................... starts 28639
--   3635086 Labor Captain Grabbit ..... ends 14155 (and starts five more in
--                                       source, which we do not carry)
--
-- npcflag is OR'd rather than assigned so nothing already on the template is
-- dropped -- Grabbit in particular must keep whatever else it has.
UPDATE acore_world.`creature_template`
SET `npcflag` = `npcflag` | 2
WHERE `entry` IN (3707139,3707149,3707434,3707443,3710806,3635086)
  AND (`npcflag` & 2) = 0;

-- ---- 2. Arch Druid of Hyjal 3640150 -- SmartAI with zero rows --------------
--     Creature entry (3640150) has SmartAI enabled but no SmartAI entries in
--     the database.
--
-- Unlike the three templates 258_ fixes, this one is not a case of every row
-- being discarded: it genuinely has none. nelt_world has all six for source
-- 40150 and they were simply never imported. Three spawns on map 750 have been
-- standing inert.
--
-- Two rewrites, both required:
--
--   * row 1 targets the CLOSEST creature 40147 (Baron Geddon) at 30 yards --
--     raw. Our clone is 3640147 and is live, so without the offset the Arch
--     Druid never finds anything to attack. Params are never touched by the
--     +3,600,000 scheme; every import has to sweep them.
--   * row 3 is SMART_EVENT_FRIENDLY_HEALTH_PCT (74), which in this fork is
--     (min, max, repeatMin, repeatMax, hpPct, range) -- the health threshold
--     and radius live in event_param5/param6, while upstream and therefore
--     nelt put them in param1/param2, and nelt's table has no param5/param6 at
--     all. Copied verbatim it would read hpPct = 0 and range = 0 and never heal
--     anyone. Source values are 20% within 50 yards, repeating every 2-5s.
--     Same fork divergence handled in 259_ for SMART_EVENT_RANGE.
--
-- Rows 2 and 3 cast 77209 Wrath and 97426 Regrowth, both downported in 258_.
-- SmartAIMgr discards any row whose spell is unknown, so 258_ MUST be applied
-- before this file or two of the six rows vanish at load.
DELETE FROM acore_world.`smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3640150;

INSERT INTO acore_world.`smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
(3640150,0,0,0, 4,0,100,0,    0,    0,   0,   0, 0, 0, 21,     0,0,0,0,0,0,  1,      0, 0,0,0, 0,0,0,0, 'Arch Druid of Hyjal - On Aggro - Allow combat movement'),
(3640150,0,1,0, 1,0,100,0,    0,    0,2000,2000, 0, 0, 49,     0,0,0,0,0,0, 19,3640147,30,0,0, 0,0,0,0, 'Arch Druid of Hyjal - OOC every 2s - Attack nearest Baron Geddon 3640147 (src 40147)'),
(3640150,0,2,0, 0,0,100,0,    0, 2000,3000,5000, 0, 0, 11, 77209,0,0,0,0,0,  2,      0, 0,0,0, 0,0,0,0, 'Arch Druid of Hyjal - IC every 3-5s - Cast Wrath 77209 on victim'),
(3640150,0,3,0,74,0,100,0, 2000, 5000,2000,5000,20,50, 11, 97426,2,0,0,0,0,  7,      0, 0,0,0, 0,0,0,0, 'Arch Druid of Hyjal - Friendly below 20 pct within 50 yd - Cast Regrowth 97426 (hpPct/range in params 5/6, fork layout)'),
(3640150,0,4,0,11,0,100,0,    0,    0,   0,   0, 0, 0, 42,   100,100,0,0,0,0, 1,      0, 0,0,0, 0,0,0,0, 'Arch Druid of Hyjal - On Respawn - Set invincibility hp 100'),
(3640150,0,5,0,32,0,100,1,    1,120000,60000,60000,0,0, 42,   0,0,0,0,0,0,   1,      0, 0,0,0, 0,0,0,0, 'Arch Druid of Hyjal - On Damaged 1-120000 - Clear invincibility');

-- ---- 3. Sentinel Aynasha 3732964 -- boolean param out of range -------------
--     SmartAIMgr: Entry 3732964 SourceType 0 Event 6 Action 80 uses param value
--     of type Boolean with value 2, valid values are 0 or 1, skipped.
--
-- SMART_ACTION_CALL_TIMED_ACTIONLIST is (id, timerType, allowOverride) and
-- allowOverride is an SAIBool, so a 2 in action_param3 fails IsSAIBoolValid and
-- the row is dropped -- taking Aynasha's whole farewell action list 373296400
-- with it at the end of the quest-13510 escort. The 2 is a timerType value
-- (2 = always) written into the wrong column; moved to param2 where it belongs.
UPDATE acore_world.`smart_scripts`
SET `action_param2` = 2, `action_param3` = 0
WHERE `entryorguid` = 3732964 AND `source_type` = 0 AND `id` = 6
  AND `action_type` = 80 AND `action_param3` = 2;

-- ---- 4. Loudspeaker 3647206 -- sound 22491 does not exist ------------------
--     CreatureTextMgr: Entry 3647206, Group 0 in table `creature_texts` has
--     Sound 22491 but sound does not exist.
--
-- 22491 is a Cata-era SoundEntries id and is absent from the deployed
-- SoundEntries.dbc (13,415 records). cata_world carries the same 22491 on both
-- rows, so this is a downport gap and not a typo we introduced -- there is no
-- correct 3.3.5 id to substitute, and picking an unrelated zeppelin sound would
-- be inventing content. Cleared to 0: the two announcements still display, they
-- just play silently until the SoundEntries row is downported.
UPDATE acore_world.`creature_text`
SET `Sound` = 0
WHERE `CreatureID` = 3647206 AND `Sound` = 22491;

-- Verify after apply -- all four must return 0 rows:
--   SELECT entry FROM creature_template
--    WHERE entry IN (3707139,3707149,3707434,3707443,3710806,3635086)
--      AND (npcflag & 2) = 0;
--   SELECT 1 FROM creature_template ct WHERE ct.entry = 3640150
--     AND ct.AIName = 'SmartAI' AND NOT EXISTS (SELECT 1 FROM smart_scripts s
--       WHERE s.entryorguid = 3640150 AND s.source_type = 0);
--   SELECT 1 FROM smart_scripts WHERE entryorguid = 3732964 AND source_type = 0
--     AND action_type = 80 AND action_param3 > 1;
--   SELECT 1 FROM creature_text WHERE CreatureID = 3647206 AND Sound = 22491;
