-- ---------------------------------------------------------------------------
-- 264  Map 750 -- the regressions round 25 introduced
-- ---------------------------------------------------------------------------
-- Post-apply boot log, 2026-08-06. Round 25 cleared all 35 "non-existent Spell
-- entry" lines, all three original "SmartAI enabled but no SmartAI entries"
-- (3601824, 3604472, 3636976), the Aynasha boolean, the 22491 sound, all 17
-- "quest can't be done" and all 236 dead containers -- and introduced six new
-- lines of its own. All six are mine, and all six are one mistake wearing
-- different clothes: a clone was copied without something that backs it.

-- ---- 0. three secondary display variants -- CRASH CLASS --------------------
--     Creature (Entry: 3632856) lists non-existing CreatureDisplayID id (28479)
--     Creature (Entry: 3634603) lists non-existing CreatureDisplayID id (29295)
--     Creature (Entry: 3634603) lists non-existing CreatureDisplayID id (29296)
--     ... "this can crash the client."
--
-- 262_ audited the displays by reading each template's modelid1 and stopped
-- there. But creature_template_model carries up to FOUR rows per creature, and
-- 259_ imported all of them -- so the Idx 1..3 appearance variants went in
-- pointing at displays this client did not have. **Sweep every
-- creature_template_model row of an import, not just Idx 0.** Note the severity
-- difference: a missing Idx-0 display makes an NPC invisible, a missing
-- secondary one is flagged as client-crashing.
--
-- The fix was as cheap as 262_'s: 28479 is model 52 (OrcFemale) and 29295 /
-- 29296 are model 56 (NightElfFemale), both already in our CreatureModelData,
-- so it is three CreatureDisplayInfo rows plus their three
-- CreatureDisplayInfoExtra rows. Those six rows are ALREADY COMPILED AND
-- DEPLOYED (patch-4 + enGB/patch-enGB-3, 0 ids lost); this is the server half.
--
-- 29295 and 29296 are 0/0 in nelt_world like 29294 was, so they take the same
-- canonical NightElfFemale value 0.306 / 1.5.
DELETE FROM acore_world.`creature_model_info` WHERE `DisplayID` IN (28479,29295,29296);

INSERT INTO acore_world.`creature_model_info` (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`) VALUES
(28479,0.2478,1.575,1,0),  -- nelt
(29295,0.306,1.5,1,0),     -- nelt row is 0/0; canonical NightElfFemale, as 262_ did for 29294
(29296,0.306,1.5,1,0);     -- nelt row is 0/0; canonical NightElfFemale, as 262_ did for 29294

DELETE FROM acore_world.`creaturedisplayinfo_dbc` WHERE `ID` IN (28479,29295,29296);

INSERT INTO acore_world.`creaturedisplayinfo_dbc`
(`ID`,`ModelID`,`SoundID`,`ExtendedDisplayInfoID`,`CreatureModelScale`,`CreatureModelAlpha`,`TextureVariation_1`,`TextureVariation_2`,`TextureVariation_3`,`PortraitTextureName`,`BloodLevel`,`BloodID`,`NPCSoundID`,`ParticleColorID`,`CreatureGeosetData`,`ObjectEffectPackageID`) VALUES
(28479,52,0,18886,1.05,255,'','','','',1,0,0,0,0,0),
(29295,56,0,19372,1,255,'','','','',1,0,0,0,0,0),
(29296,56,0,19373,1,255,'','','','',1,0,0,0,0,0);

-- 🔴 NPCItemDisplay1..11 has NO underscore in this table, unlike the CSV header
-- it was generated from (NPCItemDisplay_1..11). Getting it wrong raises
-- "Unknown column 'NPCItemDisplay_1' in 'field list'" -- and because mysql
-- continues past errors, the DELETE lands, the INSERT does not, and every later
-- statement applies normally, so the whole file still looks like it worked.
-- 262_ shipped with exactly this bug and its 4 rows never landed; they are
-- re-inserted in section 0b below. Read information_schema.COLUMNS, not the CSV.
DELETE FROM acore_world.`creaturedisplayinfoextra_dbc` WHERE `ID` IN (18886,19372,19373);

INSERT INTO acore_world.`creaturedisplayinfoextra_dbc`
(`ID`,`DisplayRaceID`,`DisplaySexID`,`SkinID`,`FaceID`,`HairStyleID`,`HairColorID`,`FacialHairID`,`NPCItemDisplay1`,`NPCItemDisplay2`,`NPCItemDisplay3`,`NPCItemDisplay4`,`NPCItemDisplay5`,`NPCItemDisplay6`,`NPCItemDisplay7`,`NPCItemDisplay8`,`NPCItemDisplay9`,`NPCItemDisplay10`,`NPCItemDisplay11`,`Flags`,`BakeName`) VALUES
(18886,2,1,4,4,2,6,4,0,12525,10962,12920,22816,9195,9196,0,9197,0,0,0,'CreatureDisplayExtra-18886.blp'),
(19372,4,1,4,6,3,2,0,5677,32016,4596,12165,12053,6865,18153,3767,11241,0,0,0,'CreatureDisplayExtra-19372.blp'),
(19373,4,1,6,0,9,0,4,5677,32016,4596,12165,12053,6865,18153,3767,11241,0,0,0,'CreatureDisplayExtra-19373.blp');

-- ---- 0b. the four CreatureDisplayInfoExtra rows 262_ lost -----------------
-- 262_'s overlay block used the CSV column names and raised "Unknown column
-- 'NPCItemDisplay_1'", so its DELETE ran and its INSERT did not -- these four
-- rows are absent on the live DB even though the rest of 262_ applied cleanly
-- (verified: creaturedisplayinfo_dbc 7/7, creaturemodeldata_dbc 1/1,
-- itemdisplayinfo_dbc 13/13, creaturedisplayinfoextra_dbc 0/4). Re-inserted
-- here with the real column names so 264_ alone completes the round; 262_ has
-- also been corrected for any future re-apply. Nothing was LOST to the failed
-- DELETE -- none of these ids existed beforehand.
DELETE FROM acore_world.`creaturedisplayinfoextra_dbc` WHERE `ID` IN (18884,19371,19747,19950);

INSERT INTO acore_world.`creaturedisplayinfoextra_dbc`
(`ID`,`DisplayRaceID`,`DisplaySexID`,`SkinID`,`FaceID`,`HairStyleID`,`HairColorID`,`FacialHairID`,`NPCItemDisplay1`,`NPCItemDisplay2`,`NPCItemDisplay3`,`NPCItemDisplay4`,`NPCItemDisplay5`,`NPCItemDisplay6`,`NPCItemDisplay7`,`NPCItemDisplay8`,`NPCItemDisplay9`,`NPCItemDisplay10`,`NPCItemDisplay11`,`Flags`,`BakeName`) VALUES
(18884,2,0,6,6,4,0,6,0,12525,10962,12920,22816,9195,9196,0,9197,0,0,0,'CreatureDisplayExtra-18884.blp'),
(19371,4,1,5,7,2,6,1,5677,32016,4596,12165,12053,6865,18153,3767,11241,0,0,0,'CreatureDisplayExtra-19371.blp'),
(19747,4,1,9,0,5,6,7,0,60762,0,44557,4300,33385,15621,0,0,0,0,0,'CreatureDisplayExtra-19747.blp'),
(19950,7,0,2,5,4,1,5,0,0,57506,25131,0,28995,10295,7082,5860,0,0,0,'CreatureDisplayExtra-19950.blp');

-- ---- 1. Unbound Flame Spirit 3640080 -- AIName with no rows ----------------
--     Creature entry (3640080) has SmartAI enabled but no SmartAI entries.
--
-- 258_'s header asserted "none of the four summon targets carries AIName". That
-- was checked against cata_world, but the clone was built from nelt_world, and
-- nelt gives 40080 AIName='SmartAI' WITH 4 real rows. Verify AIName against the
-- database you are actually cloning FROM, not a sibling source.
--
-- The 4 rows import clean: no spells, no creature entries, no text, no waypoint
-- paths, and no event in the 9/67/74 param-shift family (they are 11 RESPAWN,
-- 61 LINK, 32 DAMAGED, 54 JUST_SUMMONED). Only entryorguid is offset.
DELETE FROM acore_world.`smart_scripts` WHERE `source_type` = 0 AND `entryorguid` = 3640080;

INSERT INTO acore_world.`smart_scripts`
(`entryorguid`,`source_type`,`id`,`link`,`event_type`,`event_phase_mask`,`event_chance`,`event_flags`,`event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param6`,`action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
(3640080,0,0,1,11,0,100,0,0,0,0,0,0,0,42,100,100,0,0,0,0, 1, 0,0,0,0,0,0,0,0,'Unbound Flame Spirit - On Respawn - Set invincibility hp 100'),
(3640080,0,1,0,61,0,100,0,0,0,0,0,0,0, 8,  2,  0,0,0,0,0, 1, 0,0,0,0,0,0,0,0,'Unbound Flame Spirit - Linked - Set react state passive'),
(3640080,0,2,0,32,0,100,1,1,120000,60000,60000,0,0,42,0,0,0,0,0,0, 1, 0,0,0,0,0,0,0,0,'Unbound Flame Spirit - On Damaged 1-120000 - Clear invincibility'),
(3640080,0,3,0,54,0,100,0,0,0,0,0,0,0,49,  0,  0,0,0,0,0,21,30,0,0,0,0,0,0,0,'Unbound Flame Spirit - On Just Summoned - Attack nearest player within 30 yd');

-- ---- 2. Fiery Minion 3641501 -- AIName with no rows IN SOURCE EITHER -------
--     Creature entry (3641501) has SmartAI enabled but no SmartAI entries.
--
-- Same log line, opposite fix. nelt gives 41501 AIName='SmartAI' and ZERO
-- smart_scripts rows, so there is nothing to import and the flag is simply
-- wrong. This is exactly the case MoltenFront/20_ handled for 53113 by forcing
-- AIName='' on insert -- 258_ should have done the same here and did not.
-- Guarded on the row count so it can never strip a template that has since
-- gained rows.
UPDATE acore_world.`creature_template`
SET `AIName` = ''
WHERE `entry` = 3641501 AND `AIName` = 'SmartAI'
  AND NOT EXISTS (SELECT 1 FROM acore_world.`smart_scripts` s
                  WHERE s.`entryorguid` = 3641501 AND s.`source_type` = 0);

-- ---- 3. Bingham Gadgetspring 3636407 -- TALK with no creature_text ---------
--
--     SmartAIMgr: Entry 3636407 SourceType 0 Event 1 Action 1 using
--     non-existent Text id 0, skipped.
--
-- 259_ imported Bingham Gadgetspring's two SmartAI rows -- correctly, they are
-- his -- but not the creature_text they speak. Row 1 is SMART_EVENT_AGGRO ->
-- SMART_ACTION_TALK group 0, and with no creature_text row the validator drops
-- it, so he aggroes silently.
--
-- The lesson for the next clone import: a template's smart_scripts rows and its
-- creature_text are two separate tables and copying only the first trades a
-- "no SmartAI entries" warning for a "non-existent Text id" one. Sweep
-- action_type 1 (TALK) and event_type 52 (TEXT_OVER) for text groups whenever
-- rows are ported. Of the three AIName='SmartAI' templates 259_ brought over,
-- only 36407 speaks -- 34603 and 36822 have no creature_text in source at all,
-- which is why this surfaced as a single line rather than three.
--
-- Text and all its fields copied verbatim from nelt_world.creature_text.
-- type 12 is CHAT_MSG_MONSTER_YELL; sound is 0 in source so nothing is invented.
DELETE FROM acore_world.`creature_text` WHERE `CreatureID` = 3636407;

INSERT INTO acore_world.`creature_text`
(`CreatureID`,`GroupID`,`ID`,`Text`,`Type`,`Language`,`Probability`,`Emote`,`Duration`,`Sound`,`BroadcastTextId`,`TextRange`,`comment`)
VALUES
(3636407,0,0,'My house!',12,0,100,0,0,0,0,0,'Bingham Gadgetspring - on Aggro (src 36407)');

-- Verify after apply -- all three lines gone, nothing new:
--   * SELECT COUNT(*) FROM creature_text WHERE CreatureID = 3636407;   -> 1
--   * SELECT COUNT(*) FROM smart_scripts
--       WHERE entryorguid = 3640080 AND source_type = 0;               -> 4
--   * SELECT AIName FROM creature_template WHERE entry = 3641501;      -> ''
--   * the general form, which should return 0 rows for the whole clone band:
--       SELECT ct.entry FROM creature_template ct
--        WHERE ct.entry BETWEEN 3600000 AND 3700000 AND ct.AIName = 'SmartAI'
--          AND NOT EXISTS (SELECT 1 FROM smart_scripts s
--            WHERE s.entryorguid = ct.entry AND s.source_type = 0);
--
-- STILL OPEN AND EXPECTED, so they are not regressions:
--   * WaypointPath 16256 / 17238 -- upstream gaps, present in no source.
--   * WaypointPath 5391200 for list 5391201 -- the dead-end 16_ and 20_ both
--     document; path 5391201 exists but belongs to the 54109/54110 escape run.
--   * MoltenFront/20_ has not been applied yet: 14 timed action lists are still
--     absent (3649413, 3652705, 3652990, 3653107 x2, 3653112, 3653163,
--     3653234 x5, 3653354, 3654025, 3654070). That class logs nothing at boot,
--     so a quiet Errors.log is not evidence it is done -- check with the
--     action_type 80 query in 20_'s header.
