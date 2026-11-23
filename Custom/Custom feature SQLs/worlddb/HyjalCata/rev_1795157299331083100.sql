-- ===========================================================================
-- HyjalCata r52 -- quest phasing for Darkshore 13518 (map 750).
--
-- !! Needs the worldserver build with DC/CrossSystem/QuestPhaseLayer.cpp. !!
-- Deploy that build FIRST (it runs fine without this table), then apply this
-- file and restart. Applied against an older build, the spawns below move to
-- phases nobody has: the survivors and the Lor'danel questgivers disappear
-- and 13518 / 13563 / 13564 / 13570 cannot be done.
-- Rules load at startup; there is no reload.
--
-- How it works: dc_quest_phase rules ADD phase bits to a player on a map
-- while a quest is in given states (spell_area style status mask). Phase 1
-- stays, so the rest of the continent is untouched. GMs see every phase.
--   bit 2  until 13518 is turned in: the 4 beach survivors + 5 rescuers
--   bit 4  once 13518 is turned in:  Volcor + Cerellean in Lor'danel
-- Bits 2 and 4 were unused on map 750 (checked 2026-11-20); Phased Duels
-- keeps clear of them automatically.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS `dc_quest_phase` (
    `map` SMALLINT UNSIGNED NOT NULL,
    `phase_mask` INT UNSIGNED NOT NULL COMMENT 'bits added on top of phase 1; never include 1',
    `quest` INT UNSIGNED NOT NULL,
    `quest_status_mask` INT UNSIGNED NOT NULL COMMENT '1 << QuestStatus: 1 none, 2 complete, 8 incomplete, 32 failed, 64 rewarded',
    `comment` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`map`, `phase_mask`, `quest`, `quest_status_mask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='DC quest phasing, see QuestPhaseLayer.h';

-- 43 = none | complete | incomplete | failed, i.e. everything but rewarded.
DELETE FROM `dc_quest_phase` WHERE `map` = 750 AND `quest` = 13518;
INSERT INTO `dc_quest_phase` (`map`,`phase_mask`,`quest`,`quest_status_mask`,`comment`) VALUES
(750, 2, 13518, 43, 'Darkshore: 13518 survivors on the beach and their rescuers, until the quest is turned in'),
(750, 4, 13518, 64, 'Darkshore: Volcor and Cerellean in Lor''danel, once 13518 is turned in');

-- Survivors (r49): Gershala, Cerellean, Volcor, Shaldyn.
UPDATE `creature` SET `phaseMask` = 2 WHERE `guid` BETWEEN 9025000 AND 9025003 AND `id` IN (3732911, 3733093, 3733094, 3733095);
-- Rescuers (r51): four Lor'danel Sentinels and Shaldyn's hippogryph rider.
UPDATE `creature` SET `phaseMask` = 2 WHERE `guid` BETWEEN 9025011 AND 9025015 AND `id` IN (3732969, 3733115);
-- Lor'danel questgivers (r50): Volcor, Cerellean.
UPDATE `creature` SET `phaseMask` = 4 WHERE `guid` IN (9025007, 9025008) AND `id` IN (3732959, 3732960);
