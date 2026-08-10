-- ===========================================================================
-- 277_map750_wander_restore.sql
-- Restore random wandering on map 750 that the cata_world import never carried.
--
-- WHY
-- ---
-- cata_world is a thin movement source: its spawn POSITIONS are good but its
-- `MovementType` is largely 0. map 750 took most of its spawns from it, so the
-- world stands still. Proof -- cata and nelt hold near-identical spawn COUNTS
-- for the same zones (independent dumps of the same content; only ~15-20% of
-- positions coincide, so neither is a copy of the other), yet:
--
--   zone            nelt wander        cata wander        map 750 today
--   Azshara 16      1837/3177 57.8%     145/3173  4.6%     145/3174  4.6%  <=
--   Ashenvale 331   2544/4205 60.5%     712/4200 17.0%     783/4320 18.1%
--   Mount Hyjal 616 1109/2945 37.7%     827/4928 16.8%    1185/4496 26.4%
--   Darkshore 148   1132/2255 50.2%     908/2432 37.3%    1084/2705 40.1%
--   whole map 1      35971/59074 60.9%  16270/54061 30.1%  (stock acore 71.2%)
--
-- Azshara's 145 is an exact inheritance of cata's 145. That is the smoking gun.
--
-- The import itself is NOT buggy. Position+entry matching our 750 spawns back
-- to their source resolves 17,591 of 19,089 and only 322 disagree on
-- MovementType -- every spawn faithfully copied what its source said. The
-- source was thin. Re-importing cannot fix this; only nelt can supply the
-- missing values.
--
-- HOW THE TARGET SET WAS DERIVED
-- ------------------------------
-- cata and nelt barely share positions, so a position join silently never
-- consults nelt for the ~12,000 spawns that matched cata only. The comparison
-- is therefore per ENTRY: map `id` down through the offset bands
-- (3.6M / 3.7M / 7.3M), then ask "does this creature type wander in nelt".
--
-- Guards applied when selecting entries (each one removed real rows):
--   * name equality between our creature_template and nelt's -- 4 mapped
--     entries resolve to a DIFFERENT creature and were dropped
--     (3634123 "Astranaar's Burning! Fire Bunny" <- 34123 "Descend Into
--     Madness"; 3603780 <- "Singed Shambler"; 3703734 <- "Orc Overseer").
--     3606827 "Crab" <- 6827 "Shore Crab" is a genuine Cata rename and is
--     re-added by hand below.
--   * flags_extra & 128  -- trigger/bunny NPCs stay put
--   * npcflag & 0x1000000 -- vehicles are driven, not wandered
--   * vehicle_template_accessory members -- they ride, they do not roam
--   * creature_formations members -- the leader moves the group
--   * unit_flags & 4 (DISABLE_MOVE), creature_template_movement.Rooted = 1
--   * nelt must have a non-zero spawndist to copy
--
-- Not the cause, verified clean on 750 and deliberately NOT touched here:
--   0 spawns at MovementType=2 without a waypoint_data path,
--   0 at MovementType=1 with wander_distance 0, 0 Rooted=1.
--
-- SCOPE
-- -----
--   Section A -- 213 entries / 4,542 spawns. Every spawn of the entry is
--                MovementType 0 here; nelt wanders the majority of its own.
--   Section B --  66 entries /   865 spawns. SOME of our spawns of the entry
--                already wander; nelt wanders 100% of its own. Confirmed the
--                same defect, not deliberate placement: of the 867 static rows
--                814 position-match a cata row, and the 968 that already
--                wander match cata rows too -- cata filled movement on some
--                rows of a creature type and not others.
--
--   Section A takes nelt's modal spawndist. Section B takes the distance our
--   OWN already-wandering spawns of that entry use, so a camp stays internally
--   consistent; two degenerate values (Deadwood Avenger 1, Manifest Nightmare
--   2) fall back to nelt's, since a 1-2 yard radius is still standing still.
--
--   Sections are independent -- apply A alone if you want the conservative cut.
--
-- Worth a spot-check in game (prop-sounding names nelt nonetheless wanders):
--   3648340 Drink Tray, 3734299 Earth Elemental Remains,
--   3748077 Irontree Woods Island, 3636126 Azsharite Core Cart Summon Bunny.
--
-- Re-runnable: every statement is keyed on MovementType=0 AND wander_distance=0,
-- so a second apply is a no-op. Needs a worldserver restart, not just an apply.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Section 0 -- full snapshot of map 750 movement so this is reversible.
-- Revert with:
--   UPDATE `creature` c JOIN `dc_map750_wander_backup` b ON b.`guid` = c.`guid`
--     SET c.`MovementType` = b.`MovementType`, c.`wander_distance` = b.`wander_distance`;
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS `dc_map750_wander_backup`;
CREATE TABLE `dc_map750_wander_backup` (
  `guid` INT UNSIGNED NOT NULL,
  `id` INT UNSIGNED NOT NULL,
  `MovementType` TINYINT UNSIGNED NOT NULL,
  `wander_distance` FLOAT NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `dc_map750_wander_backup` (`guid`, `id`, `MovementType`, `wander_distance`)
  SELECT `guid`, `id`, `MovementType`, `wander_distance` FROM `creature` WHERE `map` = 750;

-- ---------------------------------------------------------------------------
-- Section A -- 213 entries / 4,542 spawns, fully static here, wandering in nelt.
-- ---------------------------------------------------------------------------
UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 6 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3601412, -- Squirrel
  3603711, -- Wrathtail Myrmidon
  3603713, -- Wrathtail Wave Rider
  3603717, -- Wrathtail Sorceress
  3603750, -- Foulweald Totemic
  3603754, -- Xavian Betrayer
  3603755, -- Xavian Felsworn
  3603757, -- Xavian Hellcaller
  3603772, -- Lesser Felguard
  3603774, -- Felslayer
  3603781, -- Shadethicket Wood Shaper
  3603782, -- Shadethicket Stone Mover
  3603784, -- Shadethicket Bark Ripper
  3603799, -- Severed Druid
  3603803, -- Severed Keeper
  3603812, -- Clattering Crawler
  3603815, -- Blink Dragon
  3603819, -- Wildthorn Stalker
  3603820, -- Wildthorn Venomspitter
  3603821, -- Wildthorn Lurker
  3603823, -- Ghostpaw Runner
  3603825, -- Ghostpaw Alpha
  3603834, -- Crazed Ancient
  3603917, -- Befouled Water Elemental
  3603919, -- Withered Ancient
  3603925, -- Thistlefur Avenger
  3603926, -- Thistlefur Pathfinder
  3603928, -- Rotting Slime
  3603943, -- Ruuzel
  3603944, -- Wrathtail Priestess
  3604054, -- Laughing Sister
  3606115, -- Roaming Felguard
  3606190, -- Spitelash Warrior
  3606193, -- Spitelash Screamer
  3606195, -- Spitelash Siren
  3606200, -- Legashi Satyr
  3606201, -- Legashi Rogue
  3606202, -- Legashi Hellcaller
  3606827, -- Crab (nelt 6827 "Shore Crab" -- Cata rename, re-added by hand)
  3608761, -- Mosshoof Courser
  3608764, -- Mistwing Ravager
  3611697, -- Mannoroc Lasher
  3612474, -- Emeraldon Boughguard
  3612475, -- Emeraldon Tree Warder
  3612476, -- Emeraldon Oracle
  3612676, -- Sharptalon
  3617467, -- Skunk
  3633193, -- Ashenvale Skirmisher
  3634350, -- Dangerfish
  3635312, -- Talrendis Saboteur
  3635833, -- Spitelash Priestess
  3636304, -- Mistwing Cliffdweller
  3636385, -- Netgun Gnome
  3636592, -- Apprentice Investigator
  3636611, -- Talrendis Biologist
  3636815, -- Valormok Grunt
  3636816, -- Talrendis Defender
  3637002, -- Cliff Crasher
  3637740, -- Yellowfin Shark
  3702172, -- Strider Clutchmother
  3702206, -- Greymist Hunter
  3703713, -- Wrathtail Wave Rider
  3703717, -- Wrathtail Sorceress
  3703733, -- Forsaken Herbalist
  3703812, -- Clattering Crawler
  3703819, -- Wildthorn Stalker
  3703823, -- Ghostpaw Runner
  3703825, -- Ghostpaw Alpha
  3703919, -- Withered Ancient
  3706827, -- Shore Crab
  3710196, -- General Colbatann
  3710199, -- Grizzle Snowpaw
  3710200, -- Rak'shiri
  3710916, -- Winterfall Runner
  3712474, -- Emeraldon Boughguard
  3712475, -- Emeraldon Tree Warder
  3732997, -- Fleetfoot
  3733044, -- Corrupted Blackwood
  3733389, -- Thistlefur Wise One
  3733390, -- Thistlefur Warrior
  3733864, -- Vile Terror
  3734350, -- Dangerfish
  3748453, -- Irontree Chopper
  3749565, -- Snowfrolic Fox
  3750313  -- Displaced Warp Stalker
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 5 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3603743, -- Foulweald Warrior
  3603783, -- Shadethicket Raincaller
  3603810, -- Elder Ashenvale Bear
  3607446, -- Rabid Shardtooth
  3612037, -- Ursol'lok
  3631890, -- Mountain Skunk
  3635095, -- Talrendis Scout
  3635245, -- Greystone Basilisk
  3636061, -- Research Intern
  3639344, -- Fiery Instructor
  3646991, -- Unbound Fire Elemental
  3652557, -- Raging Invader
  3731890, -- Mountain Skunk
  3732985, -- Frenzied Cyclone
  3734318, -- Whitetail Stag
  3734417  -- Young Grizzled Thistle Bear
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 10 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3603752, -- Xavian Rogue
  3603762, -- Felmusk Felsworn
  3603763, -- Felmusk Shadowstalker
  3603773, -- Akkrilus
  3603942, -- Mavoris Cloudsbreak
  3604619, -- Geltharis
  3606072, -- Diathorus the Seeker
  3606073, -- Searing Infernal
  3606648, -- Antilos
  3606650, -- General Fangferror
  3607885, -- Spitelash Battlemaster
  3607886, -- Spitelash Enchantress
  3608408, -- Warlord Krellian
  3610641, -- Branch Snapper
  3610737, -- Shy-Rotam
  3612759, -- Tideress
  3613896, -- Scalebeard
  3620725, -- Bat
  3632261, -- Crystal Spider
  3633444, -- Harbinger Aphotic
  3634295, -- Lord Magmathar
  3634314, -- Lava Rager
  3634499, -- Oso Bramblescar
  3635096, -- Weakened Mosshoof Stag
  3635466, -- Restless Spirit
  3635831, -- Spitelash Stormfury
  3635832, -- Spitelash Seacaller
  3636126, -- Azsharite Core Cart Summon Bunny
  3636131, -- Vile Splash
  3636147, -- Static-Charged Hippogryph
  3636868, -- Enslaved Son of Arkkoroc
  3636989, -- Spitelash Invader
  3637741, -- Bilgewater Seal
  3639724, -- Horrorguard
  3639749, -- Twilight Enforcer
  3640573, -- Twilight Stormwaker
  3646910, -- Core Hound
  3646911, -- Lava Surger
  3648340, -- Drink Tray
  3648692, -- Twilight Spider
  3649773, -- Robo-Chick
  3649774, -- Rabid Nut Varmint 5000
  3650302, -- Imported Mottled Boar
  3702175, -- Shadowclaw
  3702192, -- Firecaller Radison
  3702321, -- Foreststrider Fledgling
  3703792, -- Terrowulf Packlord
  3707016, -- Lady Vespira
  3707104, -- Dessecus
  3707149, -- Withered Protector
  3710202, -- Azurous
  3710559, -- Lady Vespia
  3710644, -- Mist Howler
  3710806, -- Ursius
  3714340, -- Alshirr Banebreath
  3714342, -- Ragepaw
  3714345, -- The Ongar
  3722902, -- Phantasmal Lash
  3732261, -- Crystal Spider
  3732928, -- Vile Spray
  3732936, -- Tide Crawler Hatchling
  3733057, -- Twilight Zealot
  3733079, -- Darkscale Myrmidon
  3733083, -- Enraged Earth Elemental
  3733207, -- Lady Janira
  3733884, -- Corrupted Duskrat
  3734030, -- Dark Strand Victim
  3734299, -- Earth Elemental Remains
  3734315, -- Marauding Poacher
  3734339, -- Greymist Refugee
  3734413, -- Faceless One
  3734414, -- Darkscale Siren
  3734423, -- Warlord Wrathspine
  3747339, -- Impsy
  3747601, -- Jadefire Defender
  3748077, -- Irontree Woods Island
  3748740, -- Archmage Maenius
  3748763, -- Forlorn Highborne
  3748960, -- Frostshard Rumbler
  3749217, -- Wintervine Lasher
  3749235, -- Icewhomp
  3749728, -- Elfin Rabbit
  3749772, -- Rabbot
  3749773, -- Robo-Chick
  3749774, -- Rabid Nut Varmint 5000
  3750312, -- Mana-Compelled Shade
  3750317, -- Mana Thirster
  3750318, -- Xorothian Satyr
  3750319, -- Dimensional Ooze
  3750320, -- Lost Ravager
  3750321, -- Xorothian Imp
  3750322, -- Arcane Mana-Cluster
  3750325  -- Umbranse the Spiritspeaker
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 12 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3603816, -- Wild Buck
  3603817, -- Shadowhorn Stag
  3603818, -- Elder Shadowhorn Stag
  3606350, -- Makrinni Razorclaw
  3606352, -- Coralshell Lurker
  3606370, -- Makrinni Scrabbler
  3606375, -- Thunderhead Hippogryph
  3703816, -- Wild Buck
  3748454  -- Talonbranch Wisp
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 3 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3612123, -- Reef Shark
  3612921, -- Enraged Foulweald
  3651509, -- Bilgewater Bruiser
  3651867, -- Silverwind Vanquisher
  3652161, -- Foulweald Pathfinder
  3656894, -- Splintertree Guard
  3733039, -- Enraged Hippogryph
  3747398  -- Vorlus
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 13 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3636665, -- Warsong Assault Wind Rider
  3636852  -- Skychaser Hippogryph
);

-- ---------------------------------------------------------------------------
-- Section B -- 66 entries / 865 spawns. Some spawns of these entries already
-- wander here; distance follows what those live spawns already use.
-- ---------------------------------------------------------------------------
UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 15 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3600721, -- Rabbit
  3700721, -- Rabbit
  3703818, -- Elder Shadowhorn Stag
  3703834, -- Crazed Ancient
  3703925, -- Thistlefur Avenger
  3703926, -- Thistlefur Pathfinder
  3707428, -- Frostmaul Giant
  3707429, -- Frostmaul Preserver
  3707432, -- Frostsaber Stalker
  3707443, -- Shardtooth Mauler
  3707447, -- Fledgling Chillwind
  3707448, -- Chillwind Chimaera
  3707450, -- Ragged Owlbeast
  3707453, -- Moontouched Owlbeast
  3707454, -- Berserk Owlbeast
  3707455, -- Winterspring Owl
  3707457, -- Rogue Ice Thistle
  3707458, -- Ice Thistle Yeti
  3707459, -- Ice Thistle Matriarch
  3707460, -- Ice Thistle Patriarch
  3707523, -- Suffering Highborne
  3712476  -- Emeraldon Oracle
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 10 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3609699, -- Fire Beetle
  3638926, -- Twilight Flamecaller
  3639342, -- Twilight Supplicant
  3639998, -- Terrified Squirrel
  3640336, -- Charbringer
  3640403, -- Spinescale Matriarch
  3640564, -- Fiery Instructor
  3640713, -- Twilight Augur
  3640755, -- Emissary of Flame
  3642657, -- Hyjal Eagle
  3642658, -- Hyjal Roc
  3642659, -- Hyjal Screecher
  3649759, -- Death's Head Cockroach
  3649779, -- Alpine Chipmunk
  3649780, -- Fire-Proof Roach
  3649861, -- Twilight Beetle
  3650478, -- Ash Lizard
  3650481, -- Rock Viper
  3650485, -- Carrion Rat
  3652791, -- Charred Flamewaker
  3652794, -- Brimstone Destroyer
  3702071, -- Moonstalker Matriarch
  3702237, -- Moonstalker Sire
  3707154, -- Deadwood Gardener
  3707440, -- Winterfall Den Watcher
  3708958, -- Angerclaw Mauler
  3708960, -- Felpaw Scavenger
  3709878, -- Entropic Beast
  3710016, -- Tainted Rat
  3710017, -- Tainted Cockroach
  3722889, -- Manifest Nightmare (live value 2 is degenerate -- nelt's 10 used)
  3749779  -- Alpine Chipmunk
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 5 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3639437, -- Twilight Hunter
  3702207, -- Greymist Oracle
  3707113, -- Jaedenar Guardian
  3707115, -- Jaedenar Adept
  3707446  -- Rabid Shardtooth
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 6 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3638913, -- Twilight Vanquisher
  3707157  -- Deadwood Avenger (live value 1 is degenerate -- nelt's 6 used)
);

UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 3 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` IN (
  3641563, -- Shadowflame Master
  3641565, -- Molten Tormentor
  3707017, -- Lord Sinslayer
  3707439  -- Winterfall Shaman
);

-- Faerie Dragon
UPDATE `creature` SET `MovementType` = 1, `wander_distance` = 9 WHERE `map` = 750 AND `MovementType` = 0 AND `wander_distance` = 0 AND `id` = 3639921;

-- ---------------------------------------------------------------------------
-- Verification -- run after applying.
--
--   -- expect 5,407 rows and a map-750 wander rate of ~62% (was 33.8%)
--   SELECT COUNT(*) AS restored FROM `creature` c
--     JOIN `dc_map750_wander_backup` b ON b.`guid` = c.`guid`
--    WHERE b.`MovementType` = 0 AND c.`MovementType` = 1;
--
--   SELECT `zoneId`, COUNT(*) AS spawns, SUM(`MovementType` = 1) AS wander,
--          ROUND(100 * SUM(`MovementType` = 1) / COUNT(*), 1) AS pct
--     FROM `creature` WHERE `map` = 750 GROUP BY `zoneId` ORDER BY spawns DESC;
--
--   -- must stay 0: wandering with no radius
--   SELECT COUNT(*) FROM `creature`
--    WHERE `map` = 750 AND `MovementType` = 1 AND `wander_distance` <= 0;
-- ---------------------------------------------------------------------------
