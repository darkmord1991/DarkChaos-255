-- =====================================================================
-- Universal Quest Master (700100) -- dungeon-fitting display IDs
-- =====================================================================
-- Replaces the three blanket per-expansion placeholders that were sitting in
-- dc_dungeon_npc_mapping.display_id with one themed model per dungeon.
--
-- What was wrong:
--   1825  = Wisp / Forest Spirit -- a floating ball of light, on 20 classic dungeons
--   18500 = Mag'har Hunter       -- one generic orc for all 22 TBC dungeons
--   25870 = Mekgineer's Chopper  -- a MOTORCYCLE, on all 27 WotLK dungeons
--   16466 = Phantom Guest        -- the C++ fallback, left on the two custom maps
--
-- Every display below comes from an NPC that actually stands in that dungeon
-- (a named/friendly NPC where one exists, otherwise the dungeon's signature
-- faction mob), so the model is guaranteed to be present client-side.
-- All 76 ids were verified against CreatureDisplayInfo.dbc before writing.
--
-- After applying: `.reload dc_dungeon_quests` (that command also flushes the
-- follower's display cache as of this build). Players already inside an
-- instance keep their old follower until they re-enter.
-- =====================================================================

-- ---------------------------------------------------------------- Classic
UPDATE dc_dungeon_npc_mapping SET display_id = 2005  WHERE map_id = 33;  -- Shadowfang Keep       : Sorcerer Ashcrombe
UPDATE dc_dungeon_npc_mapping SET display_id = 2149  WHERE map_id = 34;  -- The Stockade          : Dextren Ward
UPDATE dc_dungeon_npc_mapping SET display_id = 2347  WHERE map_id = 36;  -- Deadmines             : Defias Pirate
UPDATE dc_dungeon_npc_mapping SET display_id = 4216  WHERE map_id = 43;  -- Wailing Caverns       : Naralex
UPDATE dc_dungeon_npc_mapping SET display_id = 6103  WHERE map_id = 47;  -- Razorfen Kraul        : Razorfen Defender (quilboar)
UPDATE dc_dungeon_npc_mapping SET display_id = 4946  WHERE map_id = 48;  -- Blackfathom Deeps     : Argent Guard Thaelrid
UPDATE dc_dungeon_npc_mapping SET display_id = 5710  WHERE map_id = 70;  -- Uldaman               : Baelog (dwarf explorer)
UPDATE dc_dungeon_npc_mapping SET display_id = 7132  WHERE map_id = 90;  -- Gnomeregan            : Kernobee (gnome)
UPDATE dc_dungeon_npc_mapping SET display_id = 6670  WHERE map_id = 109; -- Sunken Temple         : Atal'ai Witch Doctor
UPDATE dc_dungeon_npc_mapping SET display_id = 7851  WHERE map_id = 129; -- Razorfen Downs        : Belnistrasz
UPDATE dc_dungeon_npc_mapping SET display_id = 2499  WHERE map_id = 189; -- Scarlet Monastery     : Scarlet Centurion
UPDATE dc_dungeon_npc_mapping SET display_id = 6425  WHERE map_id = 209; -- Zul'Farrak            : Sandfury Shadowhunter
UPDATE dc_dungeon_npc_mapping SET display_id = 9629  WHERE map_id = 229; -- Blackrock Spire       : Scarshield Legionnaire
UPDATE dc_dungeon_npc_mapping SET display_id = 8707  WHERE map_id = 230; -- Blackrock Depths      : Marshal Windsor
UPDATE dc_dungeon_npc_mapping SET display_id = 8711  WHERE map_id = 249; -- Onyxia's Lair         : Onyxian Warder (model scale 2.0)
UPDATE dc_dungeon_npc_mapping SET display_id = 10008 WHERE map_id = 269; -- Caverns of Time       : Chromie
UPDATE dc_dungeon_npc_mapping SET display_id = 11163 WHERE map_id = 289; -- Scholomance           : Scholomance Necromancer
UPDATE dc_dungeon_npc_mapping SET display_id = 11758 WHERE map_id = 309; -- Zul'Gurub             : Hakkari Priest
UPDATE dc_dungeon_npc_mapping SET display_id = 10539 WHERE map_id = 329; -- Stratholme            : Thuzadin Necromancer
UPDATE dc_dungeon_npc_mapping SET display_id = 12337 WHERE map_id = 349; -- Maraudon              : Sister of Celebras
UPDATE dc_dungeon_npc_mapping SET display_id = 11434 WHERE map_id = 389; -- Ragefire Chasm        : Searing Blade Cultist
UPDATE dc_dungeon_npc_mapping SET display_id = 12030 WHERE map_id = 409; -- Molten Core           : Flamewaker (model scale 2.0)
UPDATE dc_dungeon_npc_mapping SET display_id = 14408 WHERE map_id = 429; -- Dire Maul             : Shen'dralar Zealot
UPDATE dc_dungeon_npc_mapping SET display_id = 13991 WHERE map_id = 469; -- Blackwing Lair        : Blackwing Technician
UPDATE dc_dungeon_npc_mapping SET display_id = 15437 WHERE map_id = 509; -- Ruins of Ahn'Qiraj    : Qiraji Warrior (model scale 1.5)
UPDATE dc_dungeon_npc_mapping SET display_id = 15481 WHERE map_id = 531; -- Temple of Ahn'Qiraj   : Kandrostrasz

-- ------------------------------------------------------------------- TBC
UPDATE dc_dungeon_npc_mapping SET display_id = 16464 WHERE map_id = 532; -- Karazhan              : Phantom Guest
UPDATE dc_dungeon_npc_mapping SET display_id = 17341 WHERE map_id = 534; -- Mount Hyjal           : Night Elf Huntress
UPDATE dc_dungeon_npc_mapping SET display_id = 17183 WHERE map_id = 540; -- Shattered Halls       : Shattered Hand Gladiator
UPDATE dc_dungeon_npc_mapping SET display_id = 17137 WHERE map_id = 542; -- Blood Furnace         : Shadowmoon Warlock
UPDATE dc_dungeon_npc_mapping SET display_id = 17043 WHERE map_id = 543; -- Hellfire Ramparts     : Bonechewer Destroyer
UPDATE dc_dungeon_npc_mapping SET display_id = 11440 WHERE map_id = 544; -- Magtheridon's Lair    : Hellfire Warder
UPDATE dc_dungeon_npc_mapping SET display_id = 18389 WHERE map_id = 545; -- The Steamvault        : Coilfang Myrmidon (naga)
UPDATE dc_dungeon_npc_mapping SET display_id = 17756 WHERE map_id = 546; -- The Underbog          : Murkblood Tribesman
UPDATE dc_dungeon_npc_mapping SET display_id = 18397 WHERE map_id = 547; -- The Slave Pens        : Coilfang Technician
UPDATE dc_dungeon_npc_mapping SET display_id = 20470 WHERE map_id = 548; -- Serpentshrine Cavern  : Coilfang Serpentguard
UPDATE dc_dungeon_npc_mapping SET display_id = 19472 WHERE map_id = 550; -- Tempest Keep          : Novice Astromancer
UPDATE dc_dungeon_npc_mapping SET display_id = 19942 WHERE map_id = 552; -- The Arcatraz          : Millhouse Manastorm
UPDATE dc_dungeon_npc_mapping SET display_id = 17819 WHERE map_id = 553; -- The Botanica          : Sunseeker Botanist
UPDATE dc_dungeon_npc_mapping SET display_id = 19966 WHERE map_id = 554; -- The Mechanar          : Sunseeker Engineer
UPDATE dc_dungeon_npc_mapping SET display_id = 18191 WHERE map_id = 555; -- Shadow Labyrinth      : Cabal Ritualist
UPDATE dc_dungeon_npc_mapping SET display_id = 18628 WHERE map_id = 556; -- Sethekk Halls         : Sethekk Guard (arakkoa)
UPDATE dc_dungeon_npc_mapping SET display_id = 21004 WHERE map_id = 557; -- Mana-Tombs            : Ethereal Sorcerer
UPDATE dc_dungeon_npc_mapping SET display_id = 17924 WHERE map_id = 558; -- Auchenai Crypts       : Auchenai Soulpriest
UPDATE dc_dungeon_npc_mapping SET display_id = 19083 WHERE map_id = 560; -- Old Hillsbrad         : Thrall
UPDATE dc_dungeon_npc_mapping SET display_id = 21115 WHERE map_id = 564; -- Black Temple          : Ashtongue Battlelord
UPDATE dc_dungeon_npc_mapping SET display_id = 18356 WHERE map_id = 565; -- Gruul's Lair          : Lair Brute (ogre)
UPDATE dc_dungeon_npc_mapping SET display_id = 22309 WHERE map_id = 568; -- Zul'Aman              : Amani'shi Guardian
UPDATE dc_dungeon_npc_mapping SET display_id = 23156 WHERE map_id = 580; -- Sunwell Plateau       : Sunblade Vindicator
UPDATE dc_dungeon_npc_mapping SET display_id = 22584 WHERE map_id = 585; -- Magister's Terrace    : Sunblade Magister

-- ----------------------------------------------------------------- WotLK
UPDATE dc_dungeon_npc_mapping SET display_id = 16598 WHERE map_id = 533; -- Naxxramas             : Naxxramas Acolyte
UPDATE dc_dungeon_npc_mapping SET display_id = 22285 WHERE map_id = 574; -- Utgarde Keep          : Dragonflayer Metalworker (vrykul)
UPDATE dc_dungeon_npc_mapping SET display_id = 22293 WHERE map_id = 575; -- Utgarde Pinnacle      : Dragonflayer Spectator
UPDATE dc_dungeon_npc_mapping SET display_id = 24312 WHERE map_id = 576; -- The Nexus             : Mage Hunter Ascendant
UPDATE dc_dungeon_npc_mapping SET display_id = 25011 WHERE map_id = 578; -- The Oculus            : Image of Belgaristrasz
UPDATE dc_dungeon_npc_mapping SET display_id = 24877 WHERE map_id = 595; -- Culling of Stratholme : Chromie (human form)
UPDATE dc_dungeon_npc_mapping SET display_id = 26353 WHERE map_id = 599; -- Halls of Stone        : Brann Bronzebeard
UPDATE dc_dungeon_npc_mapping SET display_id = 27077 WHERE map_id = 600; -- Drak'Tharon Keep      : Drakkari Guardian
UPDATE dc_dungeon_npc_mapping SET display_id = 25258 WHERE map_id = 601; -- Azjol-Nerub           : Anub'ar Shadowcaster
UPDATE dc_dungeon_npc_mapping SET display_id = 25756 WHERE map_id = 602; -- Halls of Lightning    : Stormforged Runeshaper
UPDATE dc_dungeon_npc_mapping SET display_id = 27938 WHERE map_id = 603; -- Ulduar                : Hired Engineer
UPDATE dc_dungeon_npc_mapping SET display_id = 27050 WHERE map_id = 604; -- Gundrak               : Drakkari Lancer
UPDATE dc_dungeon_npc_mapping SET display_id = 27214 WHERE map_id = 608; -- Violet Hold           : Lieutenant Sinclari
UPDATE dc_dungeon_npc_mapping SET display_id = 27226 WHERE map_id = 615; -- Obsidian Sanctum      : Onyx Brood General
UPDATE dc_dungeon_npc_mapping SET display_id = 27904 WHERE map_id = 616; -- Eye of Eternity       : Alexstrasza the Life-Binder
UPDATE dc_dungeon_npc_mapping SET display_id = 27369 WHERE map_id = 619; -- Ahn'kahet             : Twilight Apostle
UPDATE dc_dungeon_npc_mapping SET display_id = 26693 WHERE map_id = 624; -- Vault of Archavon     : Archavon Warder (model scale 2.0)
UPDATE dc_dungeon_npc_mapping SET display_id = 30859 WHERE map_id = 631; -- Icecrown Citadel      : Ebon Blade Commander
UPDATE dc_dungeon_npc_mapping SET display_id = 30168 WHERE map_id = 632; -- The Forge of Souls    : Soulguard Animator
UPDATE dc_dungeon_npc_mapping SET display_id = 22209 WHERE map_id = 649; -- Trial of the Crusader : Highlord Tirion Fordring
UPDATE dc_dungeon_npc_mapping SET display_id = 28836 WHERE map_id = 650; -- Trial of the Champion : Eadric the Pure
UPDATE dc_dungeon_npc_mapping SET display_id = 30364 WHERE map_id = 658; -- Pit of Saron          : Wrathbone Laborer
UPDATE dc_dungeon_npc_mapping SET display_id = 30977 WHERE map_id = 668; -- Halls of Reflection   : Phantom Mage
UPDATE dc_dungeon_npc_mapping SET display_id = 32105 WHERE map_id = 724; -- The Ruby Sanctum      : Ruby Drakonid

-- ---------------------------------------------------------- Custom maps
UPDATE dc_dungeon_npc_mapping SET display_id = 503753 WHERE map_id = 823; -- Crescent Grove       : High Priestess A'lathea
UPDATE dc_dungeon_npc_mapping SET display_id = 17340  WHERE map_id = 824; -- Emerald Sanctum      : Emerald Sanctum Warden

-- =====================================================================
-- Bonus fix: map 269 is the Caverns of Time instance (Old Hillsbrad /
-- Black Morass / Hyjal attunement chain -- see the 40 quests mapped to it in
-- dc_dungeon_quest_mapping), not Blackwing Lair. BWL is map 469 and has its
-- own row. dungeon_name/expansion/min_level/max_level are documentation only
-- (no C++ reads them), but the duplicated label made the table unauditable.
-- =====================================================================
UPDATE dc_dungeon_npc_mapping SET dungeon_name = 'Caverns of Time', expansion = 1, min_level = 66, max_level = 70 WHERE map_id = 269;

-- Verify: any row still carrying a blanket placeholder is a miss.
SELECT map_id, dungeon_name, display_id FROM dc_dungeon_npc_mapping
WHERE display_id IN (1825, 18500, 25870, 16466) OR display_id IS NULL OR display_id = 0;
