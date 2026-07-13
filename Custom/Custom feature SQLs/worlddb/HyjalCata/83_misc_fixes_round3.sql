-- ---------------------------------------------------------------------------
-- Molten Front -- 83  Misc boot-log fixes (round 3, 2026-07-13)
-- ---------------------------------------------------------------------------
-- 1) gossip npcflag fix: Condenna the Pitiless (3639442) has gossip_menu_id
--    11216 assigned but npcflag is missing UNIT_NPC_FLAG_GOSSIP (1).
-- 2) faction_dbc/factiontemplate_dbc: creature 3654176 (unspawned, summon-only
--    -- same class as the rest of this pass) references FactionTemplate 2327,
--    missing from our mirror. Extracted directly from the real Cata client
--    (K:/Cata, enUS/locale-enUS.MPQ) -- FactionTemplate 2327 -> parent
--    Faction 50 "Dragonflight, Red". Same single-locale convention as
--    68_faction_dbc_fix.sql (Name_Lang_enUS only, Name_Lang_Mask=16712190).
-- 3) creature_model_info: 3 DisplayIDs list a model but have no
--    creature_model_info row (server-side bounding-radius/combat-reach/gender
--    data, separate from the compiled CreatureDisplayInfo.dbc) --
--    "No model data exist for CreatureDisplayID = N" boot warnings.
--      32524 (Child of Tortolla, 74_) -> cloned from sibling display 32504
--        (same ModelID 501041 Turtle.m2).
--      38490 (Kalecgos quest-ender variant, 74_) -> cloned from sibling
--        display 23487 (same ModelID 2698 DragonKalecgos.m2).
--      29680 (Tony Bachk, 3656049, unspawned) -> real Cata data resolves to
--        ModelID 831 GoblinMale.mdx (same body already used by Sovik/Hobart);
--        cloned from sibling display 7136's creature_model_info row. This
--        display id ALSO needs adding to the client CreatureDisplayInfo.dbc
--        (was in this fork's own creature_model_info already but never
--        compiled into the client DBC) -- see the paired
--        Custom/CSV DBC/CreatureDisplayInfo.csv append + recompile/redeploy.
-- NOT fixed here: display 37338 (Mobus, 3650009) resolves to a genuinely new
-- Cata model (WhaleShark, ModelID 3369) not yet present in this project's
-- asset pipeline -- needs a real model/texture extraction+bake, out of scope
-- for a DBC-row-only fix. Left as a known gap.
-- ---------------------------------------------------------------------------

UPDATE `creature_template` SET `npcflag` = `npcflag` | 1
WHERE `entry` = 3639442 AND (`npcflag` & 1) = 0;

DELETE FROM `faction_dbc` WHERE `ID` = 50;
INSERT INTO `faction_dbc` VALUES
(50,-1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,5,5,'Dragonflight, Red',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,16712190,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0);

DELETE FROM `factiontemplate_dbc` WHERE `ID` = 2327;
INSERT INTO `factiontemplate_dbc` VALUES
(2327,50,1,0,1,0,0,0,0,0,50,0,0,0);

DELETE FROM `creature_model_info` WHERE `DisplayID` IN (32524,38490,29680);
INSERT INTO `creature_model_info` (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`) VALUES
(32524,1,1,2,0,NULL),
(38490,1,6,0,0,NULL),
(29680,0.306,1.5,0,0,NULL);
