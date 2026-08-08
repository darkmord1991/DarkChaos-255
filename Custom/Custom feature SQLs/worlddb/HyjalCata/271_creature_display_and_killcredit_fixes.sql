-- ---------------------------------------------------------------------------
-- 271  17 crash-class creature displays + every broken KillCredit + 2 vehicles
-- ---------------------------------------------------------------------------
-- Four classes, and three of them are regressions I introduced in 258_ and 267_.
-- The pattern behind all three is the same and is now written down for good: a
-- cloned or raw-imported template drags its REFERENCE FIELDS with it, and every
-- one of them has to be swept -- lootid, AIName, creature_text, KillCredit1/2,
-- VehicleId, and every creature_template_model row.

-- ---- 1. the 17 missing creature displays -- CRASH CLASS --------------------
--     Creature (Entry: 3732911) lists non-existing CreatureDisplayID id (28392),
--     this can crash the client.
--     Creature (Entry: 3732911) does not have any existing display id in
--     creature_template_model.
--
-- The 370xxxx/374xxxx Winterspring/Felwood clone band, PRE-EXISTING (not from
-- this round) -- it is the gap 259_ recorded and deferred. 14 of the 17 reuse a
-- model we already have.
--
-- Two needed a substitution, and both were free: Cata models 3428
-- (FacelessOneCaster) and 3634 (UnboundFireElemental) are absent under their
-- Cata ids but ALREADY EXIST in our CreatureModelData under DC retroport ids --
-- 502404 and 501085 -- pointing at exactly the same .m2. Same model, already
-- deployed, no fabricated row and no asset extraction. Only 3739
-- (Hyjal_BoulderA01, whose .m2 is in patch-8) needed a genuinely new
-- CreatureModelData row.
--
-- 4 of the Extra rows (455, 589, 2672, 5683) are stock and already present, so
-- only 20033 and 23489 are added -- the append guard caught that rather than
-- silently duplicating them.
--
-- All of it is ALREADY COMPILED AND DEPLOYED (patch-4 + enGB/patch-enGB-3;
-- CreatureDisplayInfo 28,624 -> 28,641, Extra 16,544 -> 16,546, ModelData
-- 2,944 -> 2,945; 0 ids lost). This is the server half.

DELETE FROM acore_world.`creaturedisplayinfo_dbc` WHERE `ID` IN (28389,28390,28391,28392,28628,29027,29028,29238,29613,32710,32711,35959,36039,36102,36156,36387,36396);

INSERT INTO acore_world.`creaturedisplayinfo_dbc`
(`ID`,`ModelID`,`SoundID`,`ExtendedDisplayInfoID`,`CreatureModelScale`,`CreatureModelAlpha`,`TextureVariation_1`,`TextureVariation_2`,`TextureVariation_3`,`PortraitTextureName`,`BloodLevel`,`BloodID`,`NPCSoundID`,`ParticleColorID`,`CreatureGeosetData`,`ObjectEffectPackageID`) VALUES
(28389,55,0,455,1,255,'','','','',0,0,0,0,0,0),
(28390,55,0,589,1,255,'','','','',1,0,0,0,0,0),
(28391,56,0,2672,1,255,'','','','',0,0,0,0,0,0),
(28392,55,0,5683,1,255,'','','','',1,0,0,0,0,0),
(28628,3003,0,0,2,255,'FacelessOneSkinPurple','FacelessOneSkinGlow','','',2,0,0,0,0,0),
(29027,82,0,0,1.5,150,'TigerSkinBlackStriped','','','',1,0,0,0,0,0),
(29028,83,0,0,2,150,'BearSkinBrown','','','',-1,0,0,0,0,0),
(29238,67,0,0,1,255,'AncientProtectorGreen','','','',3,0,94,0,0,0),
(29613,49,3133,20033,1.1,255,'','','','',0,0,409,0,0,0),
(32710,502404,0,0,4,255,'FacelessOneCaster2Red','FacelessOneCaster1Red','','',0,0,0,0,0,0),
(32711,2739,0,0,0.5,255,'DragonSkin1Green','DragonSkin2Green','DragonSkin3Green','',3,0,0,0,0,0),
(35959,951,0,0,0.25,255,'LasherSkinBrown','','','',-1,0,0,0,0,0),
(36039,141,0,0,0.75,255,'EntSkinRed','','','',0,2,0,0,0,0),
(36102,3141,0,23489,1,255,'','','','',0,0,0,0,0,0),
(36156,501085,0,0,2,255,'UnboundFireElemental_Blue1','','','',-1,0,0,282,0,0),
(36387,3739,0,0,0.25,255,'','','','inv_stone_13',0,0,0,0,0,0),
(36396,2297,0,0,0.05,255,'AshenvaleLeaf','','','',-1,0,0,0,0,0);

DELETE FROM acore_world.`creaturedisplayinfoextra_dbc` WHERE `ID` IN (20033,23489);

INSERT INTO acore_world.`creaturedisplayinfoextra_dbc`
(`ID`,`DisplayRaceID`,`DisplaySexID`,`SkinID`,`FaceID`,`HairStyleID`,`HairColorID`,`FacialHairID`,`NPCItemDisplay1`,`NPCItemDisplay2`,`NPCItemDisplay3`,`NPCItemDisplay4`,`NPCItemDisplay5`,`NPCItemDisplay6`,`NPCItemDisplay7`,`NPCItemDisplay8`,`NPCItemDisplay9`,`NPCItemDisplay10`,`NPCItemDisplay11`,`Flags`,`BakeName`) VALUES
(20033,1,0,1,6,6,8,2,0,0,62438,62391,62464,62394,62395,0,0,0,36921,0,'CreatureDisplayExtra-20033.blp'),
(23489,22,0,0,0,0,0,0,72847,55424,72848,72849,72850,55420,72851,55666,55418,0,0,0,'CreatureDisplayExtra-23489.blp');

DELETE FROM acore_world.`creaturemodeldata_dbc` WHERE `ID` IN (3739);

INSERT INTO acore_world.`creaturemodeldata_dbc`
(`ID`,`Flags`,`ModelName`,`SizeClass`,`ModelScale`,`BloodID`,`FootprintTextureID`,`FootprintTextureLength`,`FootprintTextureWidth`,`FootprintParticleScale`,`FoleyMaterialID`,`FootstepShakeSize`,`DeathThudShakeSize`,`SoundID`,`CollisionWidth`,`CollisionHeight`,`MountHeight`,`GeoBoxMinX`,`GeoBoxMinY`,`GeoBoxMinZ`,`GeoBoxMaxX`,`GeoBoxMaxY`,`GeoBoxMaxZ`,`WorldEffectScale`,`AttachedEffectScale`,`MissileCollisionRadius`,`MissileCollisionPush`,`MissileCollisionRaise`) VALUES
(3739,12288,'WORLD\\KALIMDOR\\HYJAL\\BOULDERS\\HYJAL_BOULDERA01.mdx',0,1,3,4,18,12,1,0,0,0,0,11.865,8.9569,0,0,0,0,0,0,0,1,1,0,0,0);

DELETE FROM acore_world.`creature_model_info` WHERE `DisplayID` IN (28389,28390,28391,28392,28628,29027,29028,29238,29613,32710,32711,35959,36039,36102,36156,36387,36396);

INSERT INTO acore_world.`creature_model_info` (`DisplayID`,`BoundingRadius`,`CombatReach`,`Gender`,`DisplayID_Other_Gender`)
SELECT n.modelid, IF(n.bounding_radius > 0, n.bounding_radius, 0.306),
       IF(n.combat_reach > 0, n.combat_reach, 1.5), n.gender, 0
FROM nelt_world.creature_model_info n
WHERE n.modelid IN (28389,28390,28391,28392,28628,29027,29028,29238,29613,32710,32711,35959,36039,36102,36156,36387,36396);

-- ---- 2. the three KillCredit targets that do not exist ---------------------
-- 34353 -> 41087, 42016/42017 -> 41866 and 3707441 -> 3748586 all name a credit
-- proxy that was never imported. All three exist in nelt_world, all are 0-spawn
-- script-granted markers, so they are created as templates only -- the same
-- shape as the credit markers 259_ and 267_ already carry.
--
-- Band follows the referrer, not a blanket rule: 34353/42016/42017 are RAW
-- imports (267_) so their proxies go in raw, while 3707441 is a +3,700,000
-- Kalimdor clone and names 3748586, so 48586 is cloned at that offset.
--
-- 🔴 41087 and 41866 get display 1126 (Invisible Stalker) instead of their own
-- models. Their real displays 32293/32294/32295 are absent from the deployed
-- CreatureDisplayInfo.dbc, and importing them as-is would have added THREE more
-- "this can crash the client" lines -- swapping one error class for a worse one,
-- which is exactly the mistake 259_ made. They are invisible unit proxies that
-- are never rendered, so 1126 is not a compromise. 48586's own displays (328,
-- 11686) both exist and are kept.
SET @OFF37 := 3700000;

DELETE FROM acore_world.`creature_template` WHERE `entry` IN (41087,41866,3748586);

INSERT INTO acore_world.`creature_template`
(`entry`,`KillCredit1`,`KillCredit2`,`name`,`subname`,`IconName`,`gossip_menu_id`,`minlevel`,`maxlevel`,`exp`,`faction`,`npcflag`,`speed_walk`,`speed_run`,`speed_swim`,`speed_flight`,`rank`,`dmgschool`,`DamageModifier`,`BaseAttackTime`,`RangeAttackTime`,`BaseVariance`,`RangeVariance`,`unit_class`,`unit_flags`,`unit_flags2`,`dynamicflags`,`family`,`type`,`type_flags`,`lootid`,`pickpocketloot`,`skinloot`,`PetSpellDataId`,`VehicleId`,`mingold`,`maxgold`,`AIName`,`MovementType`,`HoverHeight`,`HealthModifier`,`ManaModifier`,`ArmorModifier`,`RacialLeader`,`movementId`,`RegenHealth`,`flags_extra`,`ScriptName`,`VerifiedBuild`)
SELECT IF(entry = 48586, entry + @OFF37, entry), 0, 0, name, subname, IconName, gossip_menu_id, minlevel, maxlevel, LEAST(exp,2), faction_A, npcflag, speed_walk, speed_run, speed_swim, speed_fly, `rank`, dmgschool, dmg_multiplier, baseattacktime, rangeattacktime, 1, 1, unit_class, unit_flags, unit_flags2, dynamicflags, family, type, type_flags, 0, 0, 0, PetSpellDataId, 0, mingold, maxgold,
       '',
       MovementType, HoverHeight, Health_mod, Mana_mod, Armor_mod, RacialLeader, movementId, RegenHealth, flags_extra, '', 0
FROM nelt_world.creature_template
WHERE entry IN (41087,41866,48586);

DELETE FROM acore_world.`creature_template_model` WHERE `CreatureID` IN (41087,41866,3748586);

INSERT INTO acore_world.`creature_template_model` (`CreatureID`,`Idx`,`CreatureDisplayID`,`DisplayScale`,`Probability`,`VerifiedBuild`) VALUES
(41087,0,1126,1,1,0),
(41866,0,1126,1,1,0),
(3748586,0,328,1,1,0),
(3748586,1,11686,1,1,0);

-- ---- 3. KillCredit that was WRONGLY offset ---------------------------------
-- Two separate cases of the +3,600,000 sweep being applied where it should not
-- have been. In both the RAW id exists and the offset one never did.
--
-- (a) 3640080 -> 3640065. My own 258_ wrote `KillCredit1 + @OFF` unconditionally
--     when cloning the summon targets. 40065 "Unbound Flame Spirit" exists RAW
--     and 3640065 does not, so the credit pointed at nothing.
--
-- (b) 3652816 on ten Molten Front templates. This one is documented: **52816
--     "Charred Invader" must stay RAW** -- four live dailies (29123/29127/29149/
--     29163) name raw 52816 and 3652816 has never existed. The rule was written
--     down after round 20 and these ten rows still violate it.
UPDATE acore_world.`creature_template` SET `KillCredit1` = 40065
WHERE `entry` = 3640080 AND `KillCredit1` = 3640065;

-- No NOT EXISTS guard on these: MySQL rejects a subquery on the table being
-- UPDATEd (error 1093). The precondition is verified instead -- 52816 present,
-- 3652816 absent, 8 KillCredit1 + 2 KillCredit2 references -- and both UPDATEs
-- are idempotent, so a re-apply is a no-op.
UPDATE acore_world.`creature_template` SET `KillCredit1` = 52816
WHERE `KillCredit1` = 3652816;

UPDATE acore_world.`creature_template` SET `KillCredit2` = 52816
WHERE `KillCredit2` = 3652816;

-- ---- 4. two VehicleIds that freeze the client ------------------------------
--     Creature (Entry: 34353) has a non-existing VehicleId (408). This *WILL*
--     cause the client to freeze!
--
-- Both are mine, from 267_: I zeroed lootid on those raw imports but carried
-- VehicleId across unchanged. 408 and 853 are Cata vehicles and neither is in
-- the deployed Vehicle.dbc (496 records) -- confirmed with read_server_dbc, not
-- with `vehicle_dbc`, which holds only CUSTOM rows and reports hundreds of
-- perfectly good stock vehicles as missing.
--
-- Cleared rather than fabricated, exactly as CastleNathria/27_ did for its nine:
-- both creatures are 0-spawn objective markers for unreachable quests, nothing
-- in DC/ references them as vehicles, and inventing seat layouts would be worse
-- than no vehicle. Reversible -- the source values are 408 and 853.
UPDATE acore_world.`creature_template` SET `VehicleId` = 0
WHERE `entry` IN (34353,42016) AND `VehicleId` IN (408,853);

-- ---- 5. two singletons -----------------------------------------------------
-- 3725924 Twilight Speaker Viktor (1 spawn) has gossip_menu_id 9278 but no
-- GOSSIP npcflag, so the menu can never open. Same defect 261_ fixed for the
-- Winterspring questgivers. OR'd so nothing else on the template is lost.
UPDATE acore_world.`creature_template` SET `npcflag` = `npcflag` | 1
WHERE `entry` = 3725924 AND `gossip_menu_id` > 0 AND (`npcflag` & 1) = 0;

-- 41440 "Aberration" names difficulty_entry_2 = 49977, which does not exist
-- here. 49977 "Aberration (2)" IS in nelt/cata, but it is a heroic-mode variant
-- of a creature with 0 spawns, so importing a whole heroic template to satisfy a
-- pointer nothing reaches is not worth it. Cleared; re-point it if the normal
-- mode is ever spawned.
UPDATE acore_world.`creature_template` SET `difficulty_entry_2` = 0
WHERE `entry` = 41440 AND `difficulty_entry_2` = 49977;

-- Verify after apply -- all must return 0 rows:
--   SELECT ct.entry FROM creature_template ct
--    WHERE (ct.KillCredit1 > 0 AND NOT EXISTS (SELECT 1 FROM creature_template t
--             WHERE t.entry = ct.KillCredit1))
--       OR (ct.KillCredit2 > 0 AND NOT EXISTS (SELECT 1 FROM creature_template t
--             WHERE t.entry = ct.KillCredit2));
--   SELECT entry FROM creature_template WHERE entry IN (34353,42016) AND VehicleId <> 0;
--   SELECT entry FROM creature_template WHERE entry = 3725924 AND (npcflag & 1) = 0;
-- and the log loses all 17 "non-existing CreatureDisplayID" + 17 "does not have
-- any existing display id" + 15 KillCredit + 2 vehicle + 2 singleton lines.
--
-- NOT TOUCHED: the ~20 "lists difficulty 2 mode entry N with `ScriptName` filled
-- in" warnings. Those are upstream AC data (heroic variants carrying a
-- ScriptName that the core correctly ignores in favour of difficulty 0) and are
-- informational -- clearing the ScriptNames would change nothing and risks
-- breaking a heroic script that IS reached on another map.
