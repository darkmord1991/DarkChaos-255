-- ---------------------------------------------------------------------------
-- creature_template_model  (Blackwing Descent, map 669)  --  Massive Crash
-- ---------------------------------------------------------------------------
-- Entry 47330 "Massive Crash" (2 live spawns, guid 9555011/9555012) is the
-- ONLY genuinely-missing creature display id on this map out of 36 checked
-- (all others were a false alarm from querying the empty, unused
-- `creaturedisplayinfo_dbc` SQL mirror -- this fork's server actually reads
-- CreatureDisplayInfo straight from the compiled Server/data/dbc file, not
-- SQL, so that table being 0 rows is normal and not itself a bug).
--
-- displayId 35543 (cata_world's own modelid1 for this entry) was never
-- retroported. Real fix (supersedes the earlier 20726-placeholder UPDATE):
-- the real Cata client's own CreatureDisplayInfo/CreatureModelData rows for
-- 35543 show ModelID 1731 = Creature\InvisibleStalker\InvisibleStalker.mdx
-- -- confirms this is a purely invisible effect/trigger prop (matches its
-- NOT_SELECTABLE unit_flag, no AIName/ScriptName), not a real visible mob.
-- InvisibleStalker (model id 1731) already ships in the base 3.3.5 client
-- and is already referenced by 119 other CreatureDisplayInfo rows -- so no
-- asset extraction was needed, just a new CreatureDisplayInfo.dbc row (added
-- to Custom/CSV DBC/CreatureDisplayInfo.csv, recompiled, deployed to
-- patch-4.MPQ + patch-enGB-3.MPQ + server data/dbc/ + all 3 WarcraftXLHost
-- dirs) mirroring template row 11686 (Scale 1.0, Alpha 255, BloodLevel 1).
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `creature_model_info`
(`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`,`VerifiedBuild`)
VALUES (35543,0.5,1,2,0,0);

UPDATE `creature_template_model` SET `CreatureDisplayID` = 35543 WHERE `CreatureID` = 47330 AND `CreatureDisplayID` = 20726;
