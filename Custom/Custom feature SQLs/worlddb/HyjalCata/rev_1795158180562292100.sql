-- ===========================================================================
-- HyjalCata r53 -- more quest phasing on map 750, after an audit of maps
-- 750 / 751 / 861 against nelt_world's Cata phases (2026-11-20).
--
-- !! Needs the worldserver build whose QuestPhaseLayer.cpp reads `quest2`. !!
-- That build reads the r52 layout too, so: deploy it, apply this, restart.
-- An older build ignores the new columns and treats the two-quest "before"
-- rule below as one-quest, which keeps those four NPCs visible a bit longer
-- than intended -- harmless, but deploy the build first anyway.
--
-- The trouble looked for: an NPC that Cata showed in one story state only
-- (a quest-driven phase) but that sits in phase 1 here, so players see it in
-- every state at once -- above all a questgiver standing in two places, like
-- Volcor in r50/r52. Fixed here:
--   bit 8   Darkshore: the three Great Spirits, only during The Ritual Bond
--           (13569) or while one of their own quests is in the log, so a spirit
--           quest taken there can always be handed back.
--   bit 16  Mount Hyjal, Shrine of Goldrinn: Takrik Ragehowl, Ian Duran, Rio
--           Duran and Royce Duskwhisper at the shrine until 25272 or 25273
--           (Lycanthoth, wolf or bird side) is turned in ...
--   bit 32  ... and at the camp above it afterwards. Both copies are the same
--           creature entry, so whichever one is visible offers every quest.
--           Cata also hid the camp copies once 25372 rewarded (the zone heals);
--           kept visible here so no questgiver can ever disappear for good.
--
-- Looked at and deliberately NOT phased:
--   * Darkshore 13514 The Ancients' Ire: nelt keeps only 11 of the champions
--     in the "during" phase but the quest needs 30 kills.
--   * Darkshore Battle for Darkshore (13899 / 13897): the "during" state was
--     never imported, and the Offering to Azshara controller lives in it.
--   * Hyjal Sanctuary of Malorne (29196-29198): Malfurion, Saynna, Elderlimb,
--     Mylune lack some of their phase copies here; phasing would hide the
--     29198 turn-in. Hamuul's Grove copy: the Aessina vehicle script finds him
--     with a phase-filtered search.
--   * Azshara: the phased naga / marksman / Grabbit spawns are one spawn each
--     that Cata showed in both states; Katrana is a 24467 kill target.
--   * Map 751: the Silverpine phases hang on quests that do not exist here
--     (27472 27594 27601) or have no giver (27045 27484); Quel'Danil's 27625
--     is broken on its own (objective is raw 43541, invaders never imported).
--   * Map 861: the Molten Front stage unlocks are disabled (29205, 29206) or
--     missing (29181, 29203, 29286), so phasing would hide most of the map.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- A) Second quest condition (ANDed with the first). Guarded: re-runnable.
-- ---------------------------------------------------------------------------
SELECT IF(EXISTS (SELECT 1 FROM `information_schema`.`COLUMNS` WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'dc_quest_phase' AND `COLUMN_NAME` = 'quest2'), 'DO 0', 'ALTER TABLE `dc_quest_phase` ADD COLUMN `quest2` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `quest_status_mask`, ADD COLUMN `quest2_status_mask` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `quest2`, DROP PRIMARY KEY, ADD PRIMARY KEY (`map`, `phase_mask`, `quest`, `quest_status_mask`, `quest2`, `quest2_status_mask`)') INTO @dc_qp_stmt;
PREPARE `dc_qp_alter` FROM @dc_qp_stmt;
EXECUTE `dc_qp_alter`;
DEALLOCATE PREPARE `dc_qp_alter`;

-- ---------------------------------------------------------------------------
-- B) Rules. Status masks: 2 complete + 8 incomplete = 10 (in the log),
--    43 = everything but rewarded, 64 = rewarded.
-- ---------------------------------------------------------------------------
DELETE FROM `dc_quest_phase` WHERE `map` = 750 AND `phase_mask` IN (8, 16, 32);
INSERT INTO `dc_quest_phase` (`map`,`phase_mask`,`quest`,`quest_status_mask`,`quest2`,`quest2_status_mask`,`comment`) VALUES
(750, 8, 13569, 10, 0, 0, 'Darkshore: Great Spirits while The Ritual Bond is in the log'),
(750, 8, 13567, 10, 0, 0, 'Darkshore: Great Stag Spirit while its quest is in the log'),
(750, 8, 13568, 10, 0, 0, 'Darkshore: Great Moonstalker Spirit while its quest is in the log'),
(750, 8, 13597, 10, 0, 0, 'Darkshore: Great Thistle Bear Spirit while its quest is in the log'),
(750, 16, 25272, 43, 25273, 43, 'Hyjal: Shrine of Goldrinn NPCs at the shrine until Lycanthoth (either side) is turned in'),
(750, 32, 25272, 64, 0, 0, 'Hyjal: Shrine of Goldrinn NPCs at the camp after Lycanthoth (Lo''Gosh side)'),
(750, 32, 25273, 64, 0, 0, 'Hyjal: Shrine of Goldrinn NPCs at the camp after Lycanthoth (Goldrinn side)');

-- ---------------------------------------------------------------------------
-- C) Spawns.
-- ---------------------------------------------------------------------------
-- Great Moonstalker / Thistle Bear / Stag Spirit (r49)
UPDATE `creature` SET `phaseMask` = 8 WHERE `guid` BETWEEN 9025004 AND 9025006 AND `id` IN (3733131, 3733132, 3733133);
-- Shrine copies (nelt phase 4): Ian Duran, Takrik Ragehowl, Rio Duran, Royce Duskwhisper
UPDATE `creature` SET `phaseMask` = 16 WHERE `guid` BETWEEN 9841077 AND 9841080 AND `id` IN (3639432, 3639433, 3639434, 3639435);
-- Camp copies (nelt phase 8): Royce Duskwhisper, Takrik Ragehowl, Ian Duran, Rio Duran
UPDATE `creature` SET `phaseMask` = 32 WHERE `guid` BETWEEN 9841165 AND 9841168 AND `id` IN (3639432, 3639433, 3639434, 3639435);
