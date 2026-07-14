-- ---------------------------------------------------------------------------
-- creaturefamily_dbc -- full stock WotLK backfill (was 0 rows server-wide)
-- ---------------------------------------------------------------------------
-- Surfaced as "Creature (Entry: N) has invalid creature family (F) in
-- `family`" for a handful of custom entries, but investigation showed the
-- table was COMPLETELY EMPTY (0 rows) across the whole server, not just
-- missing a few ids -- already flagged informationally in an earlier round,
-- but re-checked here because several of the newly-flagged entries
-- (3644474 "Whitetail Fox", 3644476 "Bullmastiff", 3644551 "Rabid Fox",
-- 3645453 "Blighthound") have `type_flags & 1` (CREATURE_TYPE_FLAG_TAMEABLE)
-- set -- these are real hunter-tameable beasts, and 1140 creature_template
-- rows server-wide share that flag. With creaturefamily_dbc empty, EVERY
-- tameable beast on this server has undefined pet-family data (abilities,
-- diet, talent tree, skin category) -- a core hunter-class gap, not cosmetic
-- flavor, so worth fixing properly instead of deferring again.
--
-- CreatureFamily.dbc is small and 100% static reference data -- the 40 stock
-- WotLK rows were decoded directly from this project's own known-good
-- reference ("K:/Dark-Chaos/WoW server data/AC data v19/dbc/
-- CreatureFamily.dbc", no schema-drift risk, exact client build already
-- deployed). PetTalentType/CategoryEnumID = -1 for the 8 non-hunter-pet
-- families (warlock pets, Ghoul row 40's CategoryEnumID excepted, Remote
-- Control) -- matches the raw DBC's 0xFFFFFFFF sentinel. Only
-- Name_Lang_enUS populated, matching this project's minimal-i18n convention.
--
-- 3 MORE rows (50 "Fox", 52 "Dog", 55 "Shale Spider") added from the real
-- Cata 4.3.4 client -- these are the actual families referenced by
-- Whitetail Fox/Bullmastiff/Rabid Fox/Blighthound (Plaguelands, tameable)
-- and Crimson Shale Spider/Deep Spider/Amthea/Jadefang (Plaguelands, not
-- tameable). Cata's CreatureFamily.dbc dropped from 28 to 12 fields
-- (multi-locale name array collapsed to a single Name+IconFile pair) --
-- confirmed the field layout is still Name at index 10 / IconFile at index
-- 11 by cross-checking family 1 "Wolf" resolves to the same known-correct
-- Ability_Hunter_Pet_Wolf icon in both the WotLK and Cata dumps. Fox/Dog's
-- real Cata icons genuinely are generic placeholders (inv_misc_monstertail_07
-- / inv_jewelry_necklace_22, not a parsing bug) -- Cata never shipped
-- polished hunter-pet icons for them since pet-taming Fox/Dog wasn't added
-- until MoP; shipped as-is per this session's "use real retail data even
-- when it looks unusual" convention.
-- ---------------------------------------------------------------------------
DELETE FROM `creaturefamily_dbc` WHERE `ID` IN (1,2,3,4,5,6,7,8,9,11,12,15,16,17,19,20,21,23,24,25,26,27,28,29,30,31,32,33,34,35,37,38,39,40,41,42,43,44,45,46,50,52,55);

INSERT INTO `creaturefamily_dbc`
    (`ID`,`MinScale`,`MinScaleLevel`,`MaxScale`,`MaxScaleLevel`,`SkillLine_1`,`SkillLine_2`,`PetFoodMask`,`PetTalentType`,`CategoryEnumID`,`Name_Lang_enUS`,`IconFile`)
VALUES
(1,0.7,1,1.0,60,208,270,1,0,23,'Wolf','Interface\\Icons\\Ability_Hunter_Pet_Wolf'),
(2,0.7,1,1.1,60,209,270,3,0,5,'Cat','Interface\\Icons\\Ability_Hunter_Pet_Cat'),
(3,0.4,1,0.6,60,203,270,1,2,17,'Spider','Interface\\Icons\\Ability_Hunter_Pet_Spider'),
(4,0.6,1,1.0,60,210,270,63,1,1,'Bear','Interface\\Icons\\Ability_Hunter_Pet_Bear'),
(5,0.6,1,1.0,60,211,270,63,1,3,'Boar','Interface\\Icons\\Ability_Hunter_Pet_Boar'),
(6,0.4,1,0.6,60,212,270,3,1,7,'Crocolisk','Interface\\Icons\\Ability_Hunter_Pet_Crocolisk'),
(7,0.5,1,0.9,60,213,270,3,0,4,'Carrion Bird','Interface\\Icons\\Ability_Hunter_Pet_Vulture'),
(8,0.7,1,1.4,60,214,270,58,1,6,'Crab','Interface\\Icons\\Ability_Hunter_Pet_Crab'),
(9,0.7,1,1.0,60,215,270,56,1,9,'Gorilla','Interface\\Icons\\Ability_Hunter_Pet_Gorilla'),
(11,0.5,1,0.8,60,217,270,1,0,13,'Raptor','Interface\\Icons\\Ability_Hunter_Pet_Raptor'),
(12,0.5,1,0.8,60,218,270,60,0,19,'Tallstrider','Interface\\Icons\\Ability_Hunter_Pet_TallStrider'),
(15,0.7,1,0.7,60,189,0,0,-1,-1,'Felhunter',''),
(16,0.8,1,0.8,60,204,0,0,-1,-1,'Voidwalker',''),
(17,1.0,1,1.0,60,205,0,0,-1,-1,'Succubus',''),
(19,1.0,1,1.0,60,207,0,0,-1,-1,'Doomguard',''),
(20,0.7,1,1.0,60,236,270,1,1,15,'Scorpid','Interface\\Icons\\Ability_Hunter_Pet_Scorpid'),
(21,0.5,1,0.72,60,251,270,58,1,21,'Turtle','Interface\\Icons\\Ability_Hunter_Pet_Turtle'),
(23,0.5,1,0.5,60,188,0,0,-1,-1,'Imp',''),
(24,0.4,1,0.63,60,653,270,49,2,0,'Bat','Interface\\Icons\\Ability_Hunter_Pet_Bat'),
(25,0.7,1,0.9,60,654,270,1,0,10,'Hyena','Interface\\Icons\\Ability_Hunter_Pet_Hyena'),
(26,0.5,1,0.8,60,655,270,3,2,2,'Bird of Prey','Interface\\Icons\\Ability_Hunter_Pet_Owl'),
(27,0.5,1,0.7,60,656,270,14,2,22,'Wind Serpent','Interface\\Icons\\Ability_Hunter_Pet_WindSerpent'),
(28,0.0,0,0.0,0,758,0,0,-1,-1,'Remote Control',''),
(29,0.9,1,0.9,60,761,0,0,-1,-1,'Felguard',''),
(30,0.35,1,0.65,60,763,270,35,2,8,'Dragonhawk','Interface\\Icons\\Ability_Hunter_Pet_DragonHawk'),
(31,0.65,1,0.9,60,767,270,1,2,14,'Ravager','Interface\\Icons\\Ability_Hunter_Pet_Ravager'),
(32,0.45,1,0.6,60,766,270,34,1,21,'Warp Stalker','Interface\\Icons\\Ability_Hunter_Pet_WarpStalker'),
(33,0.6,1,0.9,60,765,270,60,2,18,'Sporebat','Interface\\Icons\\Ability_Hunter_Pet_Sporebat'),
(34,0.35,1,0.55,60,764,270,17,2,12,'Nether Ray','Interface\\Icons\\Ability_Hunter_Pet_NetherRay'),
(35,0.6,1,0.8,60,768,270,1,2,16,'Serpent','Interface\\Icons\\Spell_Nature_GuardianWard'),
(37,0.35,1,0.65,60,775,270,60,0,11,'Moth','Interface\\Icons\\Ability_Hunter_Pet_Moth'),
(38,0.5,1,0.63,60,780,270,1,2,24,'Chimaera','Interface\\Icons\\Ability_Hunter_Pet_Chimera'),
(39,0.3,1,0.5,60,781,270,1,0,25,'Devilsaur','Interface\\Icons\\Ability_Hunter_Pet_Devilsaur'),
(40,1.0,1,1.0,80,782,0,0,-1,26,'Ghoul','Interface\\Icons\\Ability_Creature_Cursed_05'),
(41,0.7,1,1.0,60,783,270,17,2,63,'Silithid','Interface\\Icons\\Ability_Hunter_Pet_Silithid'),
(42,0.7,1,1.0,60,784,270,28,1,62,'Worm','Interface\\Icons\\Ability_Hunter_Pet_Worm'),
(43,0.35,1,0.56,60,786,270,60,1,61,'Rhino','Interface\\Icons\\Ability_Hunter_Pet_Rhino'),
(44,0.4,1,0.6,60,785,270,60,0,60,'Wasp','Interface\\Icons\\Ability_Hunter_Pet_Wasp'),
(45,0.3,1,0.5,60,787,270,1,0,59,'Core Hound','Interface\\Icons\\Ability_Hunter_Pet_CoreHound'),
(46,0.7,1,1.1,60,788,270,3,0,58,'Spirit Beast','Interface\\Icons\\Ability_Druid_PrimalPrecision'),
(50,0.6,1,0.9,60,808,270,35,0,27,'Fox','Interface\\Icons\\inv_misc_monstertail_07'),
(52,0.6,1,0.8,60,811,270,63,0,29,'Dog','Interface\\Icons\\inv_jewelry_necklace_22'),
(55,1.0,1,1.45,60,817,270,195,1,57,'Shale Spider','Interface\\Icons\\ability_hunter_pet_spider');
