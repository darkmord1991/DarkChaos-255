-- DarkChaos map flight licenses for maps 750 / 751. Re-runnable.
-- Code: src/server/scripts/DC/Progression/dc_flight_license.cpp (config DC.FlightLicense.*).
-- Client rows: Custom/CSV DBC/Spell.csv (300610, 300611) and SkillLineAbility.csv (51827, 51828).
--
--   300610 Kalimdor Flight License  - map 750 (Mount Hyjal continent, 80-130), level 120, 1000g, quest 81330
--   300611 Lordaeron Flight License - map 751 (Plaguelands, 130-160),          level 150, 2000g, quest 81331
--
-- Each license allows flying on its map (like Cold Weather Flying in Northrend) and adds 50% to ground-mount,
-- flying-mount and flight-form speed there (auras 130 / 209 / 210; the AuraScript keeps them to that map).

-- 1) Server spell rows (spell_dbc overlay, same values as the Spell.csv rows): passive, three self auras of 50%.
DELETE FROM `spell_dbc` WHERE `ID` IN (300610, 300611);
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `ProcChance`, `DurationIndex`, `RangeIndex`,
    `EquippedItemClass`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectDieSides_1`, `EffectDieSides_2`,
    `EffectDieSides_3`, `EffectBasePoints_1`, `EffectBasePoints_2`, `EffectBasePoints_3`, `ImplicitTargetA_1`,
    `ImplicitTargetA_2`, `ImplicitTargetA_3`, `EffectAura_1`, `EffectAura_2`, `EffectAura_3`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_Mask`, `NameSubtext_Lang_enUS`, `NameSubtext_Lang_Mask`, `Description_Lang_enUS`,
    `Description_Lang_Mask`, `AuraDescription_Lang_Mask`, `EffectChainAmplitude_1`, `EffectChainAmplitude_2`,
    `EffectChainAmplitude_3`, `SchoolMask`) VALUES
(300610, 16777296, 1, 101, 21, 1, -1, 6, 6, 6, 1, 1, 1, 49, 49, 49, 1, 1, 1, 130, 209, 210, 2554,
    'Kalimdor Flight License', 16712190, 'Passive', 16712190,
    'Allows you to fly in northern Kalimdor (Darkshore, Azshara, Ashenvale, Felwood, Winterspring and Mount Hyjal) and increases your mounted and flight form speed there by 50%.',
    16712190, 16712188, 1, 1, 1, 1),
(300611, 16777296, 1, 101, 21, 1, -1, 6, 6, 6, 1, 1, 1, 49, 49, 49, 1, 1, 1, 130, 209, 210, 3894,
    'Lordaeron Flight License', 16712190, 'Passive', 16712190,
    'Allows you to fly in Lordaeron (Tirisfal Glades to the Eastern Plaguelands) and increases your mounted and flight form speed there by 50%.',
    16712190, 16712188, 1, 1, 1, 1);

-- 2) The AuraScript that limits the speed auras to the license's map.
DELETE FROM `spell_script_names` WHERE `spell_id` IN (300610, 300611);
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES
(300610, 'spell_dc_flight_license'),
(300611, 'spell_dc_flight_license');

-- 3) Every riding trainer teaches both licenses: any trainer that teaches a riding rank or Cold Weather Flying
--    (stock 35-46, Flying Instructor 95026, Velma Warnam 410046 on map 751 at the time of writing).
--    Expert Riding (225) required, like Cold Weather Flying.
DELETE FROM `trainer_spell` WHERE `SpellId` = 300610;
INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`,
    `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT DISTINCT `TrainerId`, 300610, 10000000, 762, 225, 0, 0, 0, 120, 0 FROM `trainer_spell`
    WHERE `SpellId` IN (33388, 33389, 33391, 33392, 34090, 34091, 34092, 34093, 54197);
DELETE FROM `trainer_spell` WHERE `SpellId` = 300611;
INSERT INTO `trainer_spell` (`TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1`,
    `ReqAbility2`, `ReqAbility3`, `ReqLevel`, `VerifiedBuild`)
SELECT DISTINCT `TrainerId`, 300611, 20000000, 762, 225, 0, 0, 0, 150, 0 FROM `trainer_spell`
    WHERE `SpellId` IN (33388, 33389, 33391, 33392, 34090, 34091, 34092, 34093, 54197);

-- 4) The Flying Instructor (95026, full riding trainer, until now only on map 37) next to the Skeletal Stablemaster
--    and Petkeeper in the Jade Forest hub (map 745), same row and facing. Quest giver flag for the turn-ins.
UPDATE `creature_template` SET `npcflag` = `npcflag` | 2 WHERE `entry` = 95026;

DELETE FROM `creature` WHERE `guid` = 9024000 AND `id` = 95026 AND `map` = 745;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`, `equipment_id`,
    `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`, `wander_distance`, `currentwaypoint`,
    `curhealth`, `curmana`, `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`,
    `CreateObject`, `Comment`) VALUES
(9024000, 95026, 745, 0, 0, 1, 1, 0, 864.74, -2701.6, 192.152, 5.52514, 300, 0, 0, 5342, 0, 0, 0, 0, 0, '', NULL, 0,
    'DC flight licenses: Flying Instructor at the Jade Forest mount vendors');

-- 5) Breadcrumb quests, put into the quest log by the script at level 120 / 150 (no quest starter).
--    No objectives: complete on accept, turned in at the Flying Instructor (both spawns).
--    REPLACE keeps the file re-runnable without a DELETE on quest_template (codestyle rule).
REPLACE INTO `quest_template` (`ID`, `QuestType`, `QuestLevel`, `MinLevel`, `QuestSortID`, `RewardXPDifficulty`,
    `RewardMoney`, `Flags`, `AllowableRaces`, `LogTitle`, `LogDescription`, `QuestDescription`,
    `QuestCompletionLog`) VALUES
(81330, 2, -1, 120, 5019, 2, 0, 0, 0, 'Wings over Kalimdor',
    'Speak with the Flying Instructor beside the mount vendors in the Jade Forest.',
    'Your deeds in northern Kalimdor have not gone unnoticed, $N. The skies over Darkshore, Azshara, Ashenvale, Felwood, Winterspring and Mount Hyjal are open only to riders who carry the Kalimdor Flight License.$B$BThe Flying Instructor beside the mount vendors in the Jade Forest teaches it, and so does every other riding trainer. With it you may take to the air over those lands, and every mount you ride there carries you half again as fast.',
    'Speak with the Flying Instructor in the Jade Forest.'),
(81331, 2, -1, 150, 5019, 2, 0, 0, 0, 'Wings over Lordaeron',
    'Speak with the Flying Instructor beside the mount vendors in the Jade Forest.',
    'Lordaeron has tested you, $N, and you have held your ground. The skies over Tirisfal Glades, Silverpine Forest, Gilneas, Hillsbrad, Arathi and the Plaguelands are open only to riders who carry the Lordaeron Flight License.$B$BThe Flying Instructor beside the mount vendors in the Jade Forest teaches it, and so does every other riding trainer. With it you may take to the air over those lands, and every mount you ride there carries you half again as fast.',
    'Speak with the Flying Instructor in the Jade Forest.');

DELETE FROM `quest_offer_reward` WHERE `ID` IN (81330, 81331);
INSERT INTO `quest_offer_reward` (`ID`, `RewardText`) VALUES
(81330, 'Ready to leave the ground behind over Kalimdor, $c? Train with me and the skies above Hyjal are yours.$B$BMind you, the license holds only over those lands. Once one of your characters has it, all characters of your account receive it when they first set foot there.'),
(81331, 'Lordaeron from above is a sight few survivors forget, $c. Train with me and its skies are yours.$B$BMind you, the license holds only over those lands. Once one of your characters has it, all characters of your account receive it when they first set foot there.');

DELETE FROM `creature_questender` WHERE `quest` IN (81330, 81331);
INSERT INTO `creature_questender` (`id`, `quest`) VALUES
(95026, 81330),
(95026, 81331);

-- Turn-in marker on the Jade Forest world map (WorldMapArea 1101).
DELETE FROM `quest_poi` WHERE `QuestID` IN (81330, 81331);
INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`,
    `VerifiedBuild`) VALUES
(81330, 0, -1, 745, 1101, 0, 0, 1, 0),
(81331, 0, -1, 745, 1101, 0, 0, 1, 0);

DELETE FROM `quest_poi_points` WHERE `QuestID` IN (81330, 81331);
INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES
(81330, 0, 0, 865, -2702, 0),
(81331, 0, 0, 865, -2702, 0);
