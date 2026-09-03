-- DB update 2026_01_14_01 -> 2026_09_03_01
-- Jade Forest Training Grounds: extend the boss-display pools with the downported content.
--
-- Why:
-- - The pools were built on 2026-01-14 from `creature_template` rank 2/3 rows with exp 0/1/2,
--   which is everything that existed at the time. Every downport since then (Blackwing Descent,
--   Firelands / Molten Front, Deepholm, Gilneas, Castle Nathria, Timbermaw Hold, Crescent Grove,
--   the Emerald Sanctum, the beastmaster tames) landed outside that filter and is invisible to
--   the training dummies.
-- - `rank` is unreliable on imported content: Magmaw, Maloriak, Atramedes, Deathwing, Ysera and
--   Cenarius all came across as rank 1, so a rank-only rebuild would still miss them. The new
--   pools are therefore explicit id lists, not a SELECT.
--
-- Every display id below was verified twice before being listed:
--   1. `creature_model_info` has a row for it (server-side model data),
--   2. its CreatureModelData path resolves to an .m2/.mdx that is actually present in the
--      deployed MPQ chain (common/expansion/lichking/patch-2..patch-H) - a display whose model
--      is missing renders as the blue ErrorCube, not as a boss.
-- Excluded on purpose: 36178 (invisiblestalker - renders nothing) and 32308 (plain HumanFemale).
--
-- The script reads:
--   dc_training_boss_display_pool(pool_id, display_id, weight)
-- pool_id is now:
--   0 = Classic, 1 = Burning Crusade, 2 = Wrath of the Lich King  (unchanged by this file)
--   3 = Cataclysm
--   4 = Pandaria / Draenor
--   5 = Legion / Battle for Azeroth / Shadowlands
--   6 = Dark Chaos originals
--
-- Oversized models (Deathwing renders at 10x, Magmaw at 7.5x) are kept in the pool: the script
-- counter-scales the dummy object so nothing renders above MAX_BOSS_VISUAL_SCALE.

CREATE TABLE IF NOT EXISTS `dc_training_boss_display_pool` (
  `pool_id` tinyint unsigned NOT NULL,
  `display_id` int unsigned NOT NULL,
  `weight` float NOT NULL DEFAULT 1,
  PRIMARY KEY (`pool_id`, `display_id`),
  KEY `idx_pool_id` (`pool_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Rebuild only the new pools; 0/1/2 keep whatever the 2026_01_14_01 rebuild produced.
DELETE FROM `dc_training_boss_display_pool` WHERE `pool_id` >= 3;

-- ---------------------------------------------------------------------------
-- Pool 3 - Cataclysm
-- Blackwing Descent, Firelands / Molten Front, Deepholm, Mount Hyjal, Gilneas,
-- Vashj'ir and the Cata world rares.
-- ---------------------------------------------------------------------------
INSERT INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`) VALUES
(3, 32229, 1),   -- Xariona / Desperiona (twilight dragon)
(3, 32440, 1),   -- Lord Victor Nefarius
(3, 32547, 1),   -- Lo'Grosh (ogre mage)
(3, 32569, 2),   -- Onyxia (Nefarian's chamber)
(3, 32679, 2),   -- Magmaw
(3, 32684, 1),   -- Toxitron
(3, 32685, 1),   -- Magmatron
(3, 32687, 1),   -- Arcanotron
(3, 32688, 1),   -- Electron
(3, 32711, 1),   -- Thessera
(3, 32716, 2),   -- Nefarian
(3, 32913, 2),   -- Therazane
(3, 33097, 1),   -- Maimgor
(3, 33147, 1),   -- Rom'ogg Bonecrusher
(3, 33186, 2),   -- Maloriak
(3, 33212, 1),   -- Kor the Immovable
(3, 33275, 1),   -- Shadra
(3, 33308, 2),   -- Chimaeron
(3, 33422, 1),   -- Terrath the Steady
(3, 33433, 1),   -- Ivoroc
(3, 33443, 1),   -- Aeosera
(3, 33482, 1),   -- Boden the Imposing
(3, 33483, 1),   -- Ma'haat the Indomitable
(3, 33591, 1),   -- Fungal Terror
(3, 33697, 1),   -- Stonefather Oremantle
(3, 33760, 1),   -- Colossal Gyreworm
(3, 34201, 1),   -- Elderlimb
(3, 34264, 1),   -- Emerald Colossus
(3, 34275, 1),   -- Feldspar the Eternal
(3, 34276, 1),   -- Ro'Bark
(3, 34371, 1),   -- Tortolla
(3, 34547, 2),   -- Atramedes
(3, 34610, 1),   -- Baron Ashbury
(3, 34611, 1),   -- Lord Godfrey
(3, 34612, 1),   -- Lord Walden
(3, 34803, 2),   -- Cenarius
(3, 35095, 2),   -- Malfurion Stormrage
(3, 35221, 1),   -- Aronus
(3, 35253, 2),   -- Ysera
(3, 35268, 2),   -- Deathwing
(3, 35321, 1),   -- Nemesis
(3, 35373, 1),   -- Berard the Moon-Crazed
(3, 35381, 1),   -- Bolgaff
(3, 35383, 1),   -- Aquarius the Unbound
(3, 35496, 2),   -- Exposed Head of Magmaw
(3, 36325, 1),   -- Maggarrak the Mountain Lord
(3, 36475, 1),   -- Ozruk
(3, 36636, 1),   -- Jadefang
(3, 36700, 1),   -- Thartuk the Exile
(3, 36701, 1),   -- Blazewing
(3, 36703, 1),   -- Terborus
(3, 36722, 1),   -- Julak-Doom
(3, 37282, 1),   -- Terrorpene
(3, 37296, 1),   -- Deathsworn Captain
(3, 37307, 1),   -- Garr
(3, 37360, 1),   -- Madexx
(3, 37364, 1),   -- Golgarok the Crimson Shatterer
(3, 37555, 1),   -- Shadowclaw
(3, 37569, 1),   -- The Evalcharr
(3, 37598, 1),   -- Foreman Jerris
(3, 37735, 1),   -- Araga
(3, 37737, 1),   -- Big Samras
(3, 37738, 1),   -- Creepthess
(3, 37740, 1),   -- Tamra Stormpike
(3, 37770, 1),   -- Ironback
(3, 37771, 1),   -- Razortalon
(3, 37772, 1),   -- The Reak
(3, 37773, 1),   -- Bayne
(3, 38424, 2),   -- Deth'tilac
(3, 38446, 2),   -- Alysrazor
(3, 38634, 2),   -- Ban'thalos
(3, 38748, 1),   -- Ankha
(3, 38749, 1);   -- Magria

-- ---------------------------------------------------------------------------
-- Pool 4 - Pandaria / Draenor
-- Raid-boss models pulled across for the beastmaster tames.
-- ---------------------------------------------------------------------------
INSERT INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`) VALUES
(4, 41399, 2),   -- Elegon (celestial serpent)
(4, 45427, 1),   -- Portent (quilen)
(4, 47325, 2),   -- Horridon (zandalari triceratops)
(4, 64466, 1),   -- Fenryr (wolf boss)
(4, 70231, 2),   -- Grey Juggernaut (Iron Juggernaut)
(4, 74736, 1),   -- Lightning Paw (mistfox)
(4, 78855, 1),   -- Cragmaw the Infested (blood troll beast)
(4, 86224, 1);   -- Sabertron (mechanical tiger)

-- ---------------------------------------------------------------------------
-- Pool 5 - Legion / Battle for Azeroth / Shadowlands
-- Castle Nathria's boss roster plus the Mechagon construct.
-- ---------------------------------------------------------------------------
INSERT INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`) VALUES
(5, 90775, 1),   -- K.U.-J.0. (mechanowolf)
(5, 94482, 2),   -- Kael'thas Sunstrider (corrupted)
(5, 95375, 2),   -- Artificer Xy'mox
(5, 95623, 2),   -- Sludgefist
(5, 95643, 1),   -- Huntsman Altimor
(5, 96806, 1),   -- Lady Inerva Darkvein
(5, 96835, 1),   -- Castellan Niklaus
(5, 96836, 1),   -- Baroness Frieda
(5, 96837, 1),   -- Lord Stavros
(5, 96942, 3),   -- Sire Denathrius
(5, 97268, 2),   -- Shriekwing
(5, 98155, 1),   -- General Kaal
(5, 98156, 1),   -- General Grashaal
(5, 98776, 2);   -- Hungering Destroyer

-- ---------------------------------------------------------------------------
-- Pool 6 - Dark Chaos originals
-- Timbermaw Hold, Crescent Grove, the Emerald Sanctum and the DC world bosses.
-- ---------------------------------------------------------------------------
INSERT INTO `dc_training_boss_display_pool` (`pool_id`, `display_id`, `weight`) VALUES
(6, 500008, 1),  -- Vorath the Drowned (thunder hydra)
(6, 500234, 2),  -- Oondasta (zandalari battlesaur)
(6, 501317, 1),  -- Highlord Alexandros Mograine
(6, 503735, 2),  -- Ursol (dream bear)
(6, 503737, 1),  -- The Sundered Chieftain (furbolg)
(6, 503739, 1),  -- Gatewarden Mor'thak (primal furbolg)
(6, 503743, 1),  -- Xanthir the Defiler (nightmare satyr)
(6, 503747, 1),  -- Fenektis the Deceiver (nightmare satyr)
(6, 503751, 2),  -- Keeper Ranathos (keeper of the grove)
(6, 503753, 1),  -- High Priestess A'lathea (dryad)
(6, 503755, 2),  -- Master Raxxieth (doomguard)
(6, 503757, 2),  -- Ysondre the Wakener
(6, 503759, 2),  -- Lethon the Wakener
(6, 503761, 2),  -- Emeriss the Wakener
(6, 503763, 2),  -- Taerar the Wakener
(6, 503765, 1),  -- Mother Rootwither (nightmare dryad)
(6, 503770, 2),  -- Erennius (nightmare ent)
(6, 503771, 1);  -- Thornmaw (nightmare ent)
