-- Startup warnings from Errors.log. None of these changes what a player sees except the two quests.

-- Rotations stored to 4 decimals, so a hair off unit length. All are about Z only: taken from the orientation again.
UPDATE `gameobject` SET `rotation2` = 0.957973, `rotation3` = 0.286859 WHERE `id` = 37099 AND `guid` = 9005451;
UPDATE `gameobject` SET `rotation2` = 0.411956, `rotation3` = 0.911204 WHERE `id` = 37099 AND `guid` = 9005452;
UPDATE `gameobject` SET `rotation2` = 0.539794, `rotation3` = -0.841797 WHERE `id` = 37099 AND `guid` = 9005453;
UPDATE `gameobject` SET `rotation2` = 0.750912, `rotation3` = -0.660402 WHERE `id` = 37099 AND `guid` = 9005454;
UPDATE `gameobject` SET `rotation2` = 0.578265, `rotation3` = 0.815849 WHERE `id` = 37099 AND `guid` = 9005455;
UPDATE `gameobject` SET `rotation2` = 0.379911, `rotation3` = 0.925023 WHERE `id` = 37099 AND `guid` = 9005456;
UPDATE `gameobject` SET `rotation2` = 0.914752, `rotation3` = -0.404017 WHERE `id` = 37099 AND `guid` = 9005457;
UPDATE `gameobject` SET `rotation2` = 0.912335, `rotation3` = 0.409446 WHERE `id` = 37099 AND `guid` = 9005458;
UPDATE `gameobject` SET `rotation2` = 0.563941, `rotation3` = 0.825815 WHERE `id` = 37099 AND `guid` = 9005459;
UPDATE `gameobject` SET `rotation2` = 0.827365, `rotation3` = 0.561665 WHERE `id` = 37099 AND `guid` = 9005460;
UPDATE `gameobject` SET `rotation2` = 0.762322, `rotation3` = -0.647198 WHERE `id` = 37099 AND `guid` = 9005461;
UPDATE `gameobject` SET `rotation2` = 0.330988, `rotation3` = 0.943635 WHERE `id` = 37099 AND `guid` = 9005462;
UPDATE `gameobject` SET `rotation2` = 0.542113, `rotation3` = 0.840305 WHERE `id` = 37099 AND `guid` = 9005463;
UPDATE `gameobject` SET `rotation2` = 0.311853, `rotation3` = -0.950130 WHERE `id` = 37099 AND `guid` = 9005464;
UPDATE `gameobject` SET `rotation2` = 0.519956, `rotation3` = 0.854193 WHERE `id` = 700035 AND `guid` = 9005465;
UPDATE `gameobject` SET `rotation2` = 0.519956, `rotation3` = 0.854193 WHERE `id` = 700035 AND `guid` = 9005466;
UPDATE `gameobject` SET `rotation2` = 0.344816, `rotation3` = -0.938670 WHERE `id` = 700035 AND `guid` = 9005467;
UPDATE `gameobject` SET `rotation2` = 0.127552, `rotation3` = 0.991832 WHERE `id` = 700035 AND `guid` = 9005468;
UPDATE `gameobject` SET `rotation2` = 0.779708, `rotation3` = 0.626143 WHERE `id` = 4010001 AND `guid` = 16530201;
UPDATE `gameobject` SET `rotation2` = 0.245992, `rotation3` = -0.969272 WHERE `id` = 4010002 AND `guid` = 16530202;
UPDATE `gameobject` SET `rotation2` = 0.760636, `rotation3` = -0.649178 WHERE `id` = 4010003 AND `guid` = 16530203;
UPDATE `gameobject` SET `rotation2` = 0.997244, `rotation3` = -0.074185 WHERE `id` = 4010004 AND `guid` = 16530204;
UPDATE `gameobject` SET `rotation2` = 0.915420, `rotation3` = 0.402500 WHERE `id` = 4010005 AND `guid` = 16530205;
UPDATE `gameobject` SET `rotation2` = 0.764716, `rotation3` = 0.644368 WHERE `id` = 4010010 AND `guid` = 16530206;
UPDATE `gameobject` SET `rotation2` = 0.905706, `rotation3` = -0.423906 WHERE `id` = 4010007 AND `guid` = 16530207;
UPDATE `gameobject` SET `rotation2` = 0.730258, `rotation3` = 0.683171 WHERE `id` = 4010006 AND `guid` = 16530208;
UPDATE `gameobject` SET `rotation2` = 0.991819, `rotation3` = -0.127654 WHERE `id` = 4010008 AND `guid` = 16530209;

-- A retail tool category; 3.3.5 has no 194, and these are plain weapons
UPDATE `item_template` SET `TotemCategory` = 0 WHERE `entry` IN (504297, 504406, 504637);

-- Atal'ai Offerings carries the daily flag but was not repeatable
UPDATE `quest_template_addon` SET `SpecialFlags` = `SpecialFlags` | 1 WHERE `ID` = 82005;

-- Quests that start from an item, which must also be handed out
UPDATE `quest_template_addon` SET `ProvidedItemCount` = 1 WHERE `ID` = 700775;
DELETE FROM `quest_template_addon` WHERE `ID` = 82018;
INSERT INTO `quest_template_addon` (`ID`, `ProvidedItemCount`) VALUES (82018, 1);

-- The group added up to 110%, so its last 10% could never drop
UPDATE `reference_loot_template` SET `Chance` = 40 WHERE `Entry` = 24161 AND `Item` = 24040 AND `GroupId` = 1;
