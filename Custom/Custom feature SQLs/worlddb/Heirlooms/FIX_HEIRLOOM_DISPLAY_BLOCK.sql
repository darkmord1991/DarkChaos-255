-- ===========================================================================
-- DC heirloom set - the whole display block was mis-assigned
-- ===========================================================================
--
-- SYMPTOM: blue-and-white checkered box (ErrorCube) welded to the HEAD of any
-- character wearing "Heirloom Kingly Circlet" (300343) and its three siblings,
-- to the SHOULDERS of eight heirloom shoulder pieces, and to the HAND of the
-- Heirloom Polearm. Every other heirloom rendered with wrong or missing armour
-- textures, invisible cloaks/shields, and shield icons on necklaces and rings.
--
-- ROOT CAUSE: the DC heirloom set (300340-300381 and 303100-303139, 81 items)
-- was assigned ItemDisplayInfo ids 50001-50041 as a straight sequential block.
-- Those ids were never free. 50001-50025 are pre-existing STOCK display rows
-- built for unrelated slots - Sunwell PvP shoulders and helms, Northrend maces,
-- knives, wands and shields - and several are still referenced by live stock
-- items (Brutal Gladiator's Lamellar/Ornamented/Scaled Shoulders 35031/35063/
-- 35092/40965 all use 50003). So every heirloom inherited a display built for
-- some other slot.
--
-- WHY ONLY SOME OF THEM CUBED: a component model name is only valid for the
-- folder its InventoryType selects (same rule as the Haversack bug, see
-- FIX_HEIRLOOM_HAVERSACK_DISPLAY.sql). Measured across all 160,123 Item.dbc
-- rows, only head (99.8%), shoulder (99.5%), the weapon slots (~100%) and bags
-- actually resolve a model from ItemDisplayInfo; chest/legs/wrist/hands/waist/
-- feet are 0.2-4% and stock Blizzard rows in those slots routinely carry
-- leftover shoulder model names with no ill effect. So the ErrorCubes were:
--
--   display 50003 (head)     ModelName_1 = LShoulder_Plate_Sunwell_D_01.mdx
--                            -> Head\LShoulder_Plate_Sunwell_D_01_<race>.m2
--                            items 300343, 303108, 303124, 303132
--   display 50004 (shoulder) ModelName_1 = Mace_1H_Northrend_C_01.mdx
--                            items 300344
--   display 50005 (shoulder) ModelName_1 = Helm_Robe_Sunwell_D_01.mdx
--                            items 300345, 303101, 303117
--   display 50006 (shoulder) ModelName_1 = Mace_1H_Northrend_C_01.mdx
--                            items 300346, 303109, 303125, 303133
--   display 45009 (polearm)  ModelName_1 = Helm_Mail_RaidShaman_F_01.mdx
--                            item  300340
--
-- Displays 50001/50002 (head) have an EMPTY ModelName, so 300341, 300342,
-- 303100 and 303116 rendered no helm at all.
--
-- THE FIX: the display rows cannot be edited - 50003 is live stock data. Each
-- heirloom is repointed to a real, slot-correct stock display instead, sourced
-- from complete 8-piece classic tier sets so each heirloom set reads as one
-- coherent look:
--
--   Might   (mail)    -> Giantstalker's     Agility (leather) -> Nightslayer
--   Wisdom  (cloth)   -> Arcanist           Conquest (plate)  -> Wrath
--   Light   (plate)   -> Judgement          the Hunt (mail)   -> Dragonstalker
--   Elements (mail)   -> The Ten Storms     the Grove (leath) -> Stormrage
--
-- IMPORTANT - THIS SQL ALONE IS NOT ENOUGH. ObjectMgr::LoadItemTemplates ->
-- enforceDBCAttributes (ObjectMgr.cpp:3534) overwrites item_template.displayid
-- with Item.dbc's DisplayInfoID at load, so a DB-only change is a runtime
-- no-op - exactly what defeated the first Haversack fix. The matching
-- Item.dbc rows have been repointed in Custom/CSV DBC/Item.csv; that must be
-- compiled (dbc-compile.py --only Item) and deployed to the server's
-- data/dbc/ before or with this script. Keep the two in lockstep.
-- ===========================================================================

-- Giantstalker (mail)
UPDATE `item_template` SET `displayid` = 32028 WHERE `entry` = 300341; -- head      was 50001
UPDATE `item_template` SET `displayid` = 32030 WHERE `entry` = 300344; -- shoulder  was 50004
UPDATE `item_template` SET `displayid` = 32022 WHERE `entry` = 300347; -- chest     was 50007
UPDATE `item_template` SET `displayid` = 32021 WHERE `entry` = 300350; -- wrist     was 50010
UPDATE `item_template` SET `displayid` = 32024 WHERE `entry` = 300353; -- hands     was 50013
UPDATE `item_template` SET `displayid` = 32019 WHERE `entry` = 300356; -- waist     was 50016
UPDATE `item_template` SET `displayid` = 32029 WHERE `entry` = 300359; -- legs      was 50019
UPDATE `item_template` SET `displayid` = 32040 WHERE `entry` = 300362; -- feet      was 50022

-- Nightslayer (leather)
UPDATE `item_template` SET `displayid` = 31514 WHERE `entry` = 300342; -- head      was 50002
UPDATE `item_template` SET `displayid` = 31504 WHERE `entry` = 300345; -- shoulder  was 50005
UPDATE `item_template` SET `displayid` = 31105 WHERE `entry` = 300348; -- chest     was 50008
UPDATE `item_template` SET `displayid` = 31106 WHERE `entry` = 300351; -- wrist     was 50011
UPDATE `item_template` SET `displayid` = 31503 WHERE `entry` = 300354; -- hands     was 50014
UPDATE `item_template` SET `displayid` = 31339 WHERE `entry` = 300357; -- waist     was 50017
UPDATE `item_template` SET `displayid` = 31340 WHERE `entry` = 300360; -- legs      was 50020
UPDATE `item_template` SET `displayid` = 31109 WHERE `entry` = 300363; -- feet      was 50023

-- Arcanist (cloth)
UPDATE `item_template` SET `displayid` = 31517 WHERE `entry` = 300343; -- head      was 50003
UPDATE `item_template` SET `displayid` = 30586 WHERE `entry` = 300346; -- shoulder  was 50006
UPDATE `item_template` SET `displayid` = 30584 WHERE `entry` = 300352; -- wrist     was 50012
UPDATE `item_template` SET `displayid` = 30585 WHERE `entry` = 300355; -- hands     was 50015
UPDATE `item_template` SET `displayid` = 30583 WHERE `entry` = 300358; -- waist     was 50018
UPDATE `item_template` SET `displayid` = 30582 WHERE `entry` = 300361; -- legs      was 50021
UPDATE `item_template` SET `displayid` = 30587 WHERE `entry` = 300364; -- feet      was 50024

-- Glacial Vest (cloth)
UPDATE `item_template` SET `displayid` = 35302 WHERE `entry` = 300349; -- chest     was 50009

-- Wrath (plate)
UPDATE `item_template` SET `displayid` = 34215 WHERE `entry` = 303100; -- head      was 50002
UPDATE `item_template` SET `displayid` = 34253 WHERE `entry` = 303101; -- shoulder  was 50005
UPDATE `item_template` SET `displayid` = 33983 WHERE `entry` = 303102; -- chest     was 50008
UPDATE `item_template` SET `displayid` = 33982 WHERE `entry` = 303103; -- wrist     was 50011
UPDATE `item_template` SET `displayid` = 33984 WHERE `entry` = 303104; -- hands     was 50014
UPDATE `item_template` SET `displayid` = 33990 WHERE `entry` = 303105; -- waist     was 50017
UPDATE `item_template` SET `displayid` = 33986 WHERE `entry` = 303106; -- legs      was 50020
UPDATE `item_template` SET `displayid` = 33989 WHERE `entry` = 303107; -- feet      was 50023

-- Judgement (plate)
UPDATE `item_template` SET `displayid` = 45888 WHERE `entry` = 303108; -- head      was 50003
UPDATE `item_template` SET `displayid` = 34258 WHERE `entry` = 303109; -- shoulder  was 50006
UPDATE `item_template` SET `displayid` = 33635 WHERE `entry` = 303110; -- chest     was 50009
UPDATE `item_template` SET `displayid` = 33634 WHERE `entry` = 303111; -- wrist     was 50012
UPDATE `item_template` SET `displayid` = 33636 WHERE `entry` = 303112; -- hands     was 50015
UPDATE `item_template` SET `displayid` = 33633 WHERE `entry` = 303113; -- waist     was 50018
UPDATE `item_template` SET `displayid` = 33637 WHERE `entry` = 303114; -- legs      was 50021
UPDATE `item_template` SET `displayid` = 33639 WHERE `entry` = 303115; -- feet      was 50024

-- Dragonstalker (mail)
UPDATE `item_template` SET `displayid` = 34367 WHERE `entry` = 303116; -- head      was 50002
UPDATE `item_template` SET `displayid` = 34091 WHERE `entry` = 303117; -- shoulder  was 50005
UPDATE `item_template` SET `displayid` = 33667 WHERE `entry` = 303118; -- chest     was 50008
UPDATE `item_template` SET `displayid` = 33666 WHERE `entry` = 303119; -- wrist     was 50011
UPDATE `item_template` SET `displayid` = 33668 WHERE `entry` = 303120; -- hands     was 50014
UPDATE `item_template` SET `displayid` = 33665 WHERE `entry` = 303121; -- waist     was 50017
UPDATE `item_template` SET `displayid` = 33672 WHERE `entry` = 303122; -- legs      was 50020
UPDATE `item_template` SET `displayid` = 34269 WHERE `entry` = 303123; -- feet      was 50023

-- Ten Storms (mail)
UPDATE `item_template` SET `displayid` = 34217 WHERE `entry` = 303124; -- head      was 50003
UPDATE `item_template` SET `displayid` = 34255 WHERE `entry` = 303125; -- shoulder  was 50006
UPDATE `item_template` SET `displayid` = 34081 WHERE `entry` = 303126; -- chest     was 50009
UPDATE `item_template` SET `displayid` = 34079 WHERE `entry` = 303127; -- wrist     was 50012
UPDATE `item_template` SET `displayid` = 34082 WHERE `entry` = 303128; -- hands     was 50015
UPDATE `item_template` SET `displayid` = 34078 WHERE `entry` = 303129; -- waist     was 50018
UPDATE `item_template` SET `displayid` = 34084 WHERE `entry` = 303130; -- legs      was 50021
UPDATE `item_template` SET `displayid` = 34083 WHERE `entry` = 303131; -- feet      was 50024

-- Stormrage (leather)
UPDATE `item_template` SET `displayid` = 33655 WHERE `entry` = 303132; -- head      was 50003
UPDATE `item_template` SET `displayid` = 30546 WHERE `entry` = 303133; -- shoulder  was 50006
UPDATE `item_template` SET `displayid` = 30536 WHERE `entry` = 303134; -- chest     was 50009
UPDATE `item_template` SET `displayid` = 30548 WHERE `entry` = 303135; -- wrist     was 50012
UPDATE `item_template` SET `displayid` = 34016 WHERE `entry` = 303136; -- hands     was 50015
UPDATE `item_template` SET `displayid` = 30541 WHERE `entry` = 303137; -- waist     was 50018
UPDATE `item_template` SET `displayid` = 30540 WHERE `entry` = 303138; -- legs      was 50021
UPDATE `item_template` SET `displayid` = 30542 WHERE `entry` = 303139; -- feet      was 50024

-- Accessories and weapon
UPDATE `item_template` SET `displayid` = 29176 WHERE `entry` = 300340; -- polearm   Shadowstrike, was 45009
UPDATE `item_template` SET `displayid` = 10840 WHERE `entry` = 300365; -- shirt     Red Linen Shirt, was 50025
UPDATE `item_template` SET `displayid` = 9860 WHERE `entry` = 300367; -- neck      Onyxia Tooth Pendant, was 50027
UPDATE `item_template` SET `displayid` = 23717 WHERE `entry` = 300368; -- neck      Star of Mystaria, was 50028
UPDATE `item_template` SET `displayid` = 9858 WHERE `entry` = 300369; -- neck      Choker of Enlightenment, was 50029
UPDATE `item_template` SET `displayid` = 24013 WHERE `entry` = 300370; -- back      Cape of the Black Baron (heirloom), was 50030
UPDATE `item_template` SET `displayid` = 24108 WHERE `entry` = 300371; -- back      Stoneskin Gargoyle Cape (heirloom), was 50031
UPDATE `item_template` SET `displayid` = 23553 WHERE `entry` = 300372; -- back      Ancient Bloodmoon Cloak (heirloom), was 50032
UPDATE `item_template` SET `displayid` = 9837 WHERE `entry` = 300373; -- finger    Eye of Orgrimmar, was 50033
UPDATE `item_template` SET `displayid` = 23629 WHERE `entry` = 300374; -- finger    Blackstone Ring, was 50034
UPDATE `item_template` SET `displayid` = 9823 WHERE `entry` = 300375; -- finger    Tarnished Elven Ring, was 50035
UPDATE `item_template` SET `displayid` = 6337 WHERE `entry` = 300376; -- trinket   Swift Hand of Justice (heirloom), was 50036
UPDATE `item_template` SET `displayid` = 24784 WHERE `entry` = 300377; -- trinket   Discerning Eye of the Beast (heirloom), was 50037
UPDATE `item_template` SET `displayid` = 29712 WHERE `entry` = 300378; -- trinket   Royal Seal of Eldre'Thalas, was 50038
UPDATE `item_template` SET `displayid` = 23419 WHERE `entry` = 300379; -- shield    Draconian Deflector, was 50039
UPDATE `item_template` SET `displayid` = 34110 WHERE `entry` = 300380; -- shield    Drillborer Disk, was 50040
UPDATE `item_template` SET `displayid` = 40786 WHERE `entry` = 300381; -- holdable  Everburning Tome, was 50041

-- 300366 Heirloom Adventurer's Haversack and its II-VI clones already sit on
-- display 8270 from FIX_HEIRLOOM_HAVERSACK_DISPLAY.sql and are left alone.
