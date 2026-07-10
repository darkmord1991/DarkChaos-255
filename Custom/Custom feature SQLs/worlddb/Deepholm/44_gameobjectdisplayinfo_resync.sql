-- ---------------------------------------------------------------------------
-- gameobjectdisplayinfo_dbc resync  (Deepholm, map 646)
-- ---------------------------------------------------------------------------
-- The SQL DBC mirror is stale relative to Custom/CSV DBC/GameObjectDisplayInfo.csv
-- (same class of gap fixed for BWD's cauldron/bell/forge earlier -- here it's
-- 71 gameobject_template rows on this map whose displayId was never synced
-- into gameobjectdisplayinfo_dbc at all, mostly plain stock WotLK props
-- (chairs, lamps, doors, mailboxes) plus this project's own housing-decor
-- 101000+ display range). Missing displayId = "not loaded" -- the
-- gameobject is skipped entirely at boot, not just cosmetically broken.
-- All 71 rows already exist in the CSV; this just re-syncs the SQL mirror.
-- One id (10573, Hyjal) is missing from the CSV too and needs separate
-- real-client extraction -- excluded here, tracked as a follow-up.
-- IDs shared with other maps are duplicated here on purpose so each map's
-- apply run stays self-contained (matches this project's existing pattern).
-- ---------------------------------------------------------------------------

DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` IN (31,41,181,233,273,285,359,1127,1847,1868,1869,2530,3151,4395,4396,5492,6038,6406,6432,6482,6765,6792,6802,6870,6891,6895,6908,7181,7487,7608,7748,8171,8197,8363,8517,8757,8994,9145,9371,9432,9510,9652,9678,9681,9694,9715,9716,9721,9722,9814,9815,9840,9842,9846,9847,9849,9855,9856,9857,9858,9859,9860,9861,9885,10157,10158,10159,10160,10256,10266,10283);

INSERT INTO `gameobjectdisplayinfo_dbc`
    (`ID`, `ModelName`, `Sound_1`, `Sound_2`, `Sound_3`, `Sound_4`, `Sound_5`, `Sound_6`, `Sound_7`, `Sound_8`, `Sound_9`, `Sound_10`,
     `GeoBoxMinX`, `GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`, `ObjectEffectPackageID`)
VALUES
(31,'World\\Generic\\Human\\Passive Doodads\\Crates\\StormwindCrate01.mdx',0,0,0,0,0,0,0,0,0,0,-0.615704,-0.661954,0,0.615704,0.661954,1.24297,0),
(41,'World\\Generic\\ActiveDoodads\\Chest03\\Chest03.mdx',0,1277,0,0,0,0,0,0,0,0,-0.394601,-0.590637,0.005024,0.3936,0.589135,0.623557,0),
(181,'World\\Generic\\Human\\Passive Doodads\\BallandChain\\BallAndChain01.mdx',0,0,0,0,0,0,0,0,0,0,-0.259523,-0.257961,-0.143469,0.490956,0.994253,0.472676,0),
(233,'World\\SkillActivated\\TradeskillEnablers\\Tradeskill_Forge_01.mdx',0,0,0,0,0,0,0,0,0,0,-0.16244,-1.181084,0,2.171254,2.338611,4.772967,0),
(273,'World\\SkillActivated\\TradeskillEnablers\\Tradeskill_Anvil_01.mdx',0,0,0,0,0,0,0,0,0,0,-1.233692,-0.556316,-0.090814,0.652857,0.559759,1.354219,0),
(285,'World\\Generic\\Human\\Passive Doodads\\Crates\\ReplaceCrate01.mdx',0,0,0,0,0,0,0,0,0,0,-0.400577,-0.595919,0,0.399647,0.594496,0.634888,0),
(359,'World\\SkillActivated\\TradeskillNodes\\Bush_Mushroom03.mdx',0,0,0,0,0,0,0,0,0,0,-1.636405,-1.445099,-0.577679,1.397093,1.471955,1.775703,0),
(1127,'World\\Generic\\Human\\Passive Doodads\\Books\\BookMediumOpen04.mdx',0,0,0,0,0,0,0,0,0,0,-0.321742,-0.448497,0.000336,0.320725,0.454044,0.129496,0),
(1847,'World\\Lordaeron\\Plagueland\\PassiveDoodads\\Trees\\PlaguelandMushroom04.mdx',0,0,0,0,0,0,0,0,0,0,-1.6364,-1.44509,-0.109649,1.39709,1.47195,2.24373,0),
(1868,'World\\Generic\\DarkIronDwarf\\Passive Doodads\\Crates\\DarkIronCrate01.mdx',0,0,0,0,0,0,0,0,0,0,-0.999296,-1.166229,0,1.448172,1.138598,2.164719,0),
(1869,'World\\Generic\\DarkIronDwarf\\Passive Doodads\\Crates\\DarkIronCrate02.mdx',0,0,0,0,0,0,0,0,0,0,-1.289209,-1.237291,0,1.158259,1.067536,2.164719,0),
(2530,'World\\Goober\\G_BookOpenMediumBlack.mdx',0,12116,0,12118,0,0,0,0,0,0,-0.301394,-0.176314,-0.033139,0.341079,0.194156,0.22705,0),
(3151,'World\\Generic\\Human\\Passive Doodads\\Mugs\\Mug01.mdx',0,0,0,0,0,0,0,0,0,0,-0.168461,-0.186739,-0.010501,0.077006,0.138785,0.272041,0),
(4395,'World\\Generic\\ActiveDoodads\\SpellPortals\\MagePortal_Ogrimmar.mdx',0,0,9869,0,0,0,0,0,0,0,0,-1.561411,0.175986,0,1.561411,3.648433,0),
(4396,'World\\Generic\\ActiveDoodads\\SpellPortals\\MagePortal_Stormwind.mdx',0,0,9869,0,0,0,0,0,0,0,0,-1.561411,0.175986,0,1.561411,3.648433,0),
(5492,'World\\Generic\\ActiveDoodads\\MeetingStones\\Meetingstone01.mdx',0,0,0,0,0,0,0,0,0,0,-2.030113,-3.055414,-0.239334,2.592509,3.023229,9.040523,0),
(6038,'World\\Generic\\Human\\Passive Doodads\\Lanterns\\GeneralLantern01.mdx',0,0,0,0,0,0,0,0,0,0,-0.34628,-0.354768,-0.003824,0.369521,0.361033,1.371846,0),
(6406,'World\\Generic\\Orc\\Passive Doodads\\VoodooStuff\\SkullCandle01.mdx',0,0,0,0,0,0,0,0,0,0,-0.192941,-0.116625,-0.009064,0.172836,0.117983,0.564088,0),
(6432,'World\\Goober\\G_SporeMushroom.mdx',8480,0,0,0,0,0,8478,8479,0,0,-1.346679,-1.291444,-0.120614,1.357348,1.342433,2.679322,0),
(6482,'World\\SkillActivated\\TradeskillEnablers\\Tradeskill_FishSchool_02.mdx',0,0,0,0,0,0,0,0,0,0,-3.9393,-3.199767,-1.897449,3.118981,3.220656,-0.106936,0),
(6765,'World\\Generic\\PassiveDoodads\\SummerFestival\\SummerFest_Brazier_01.mdx',0,0,0,0,0,0,0,0,0,0,-0.642474,-0.642131,-0.010661,0.650019,0.650361,1.823681,0),
(6792,'World\\Generic\\BloodElf\\Passive Doodads\\BL_sq_Crate_001.mdx',0,0,0,0,0,0,0,0,0,0,-0.416667,-0.416667,0,0.416667,0.416667,0.833333,0),
(6802,'World\\Expansion01\\Doodads\\Generic\\BloodElf\\Bottles\\BE_Bottle01.mdx',0,0,0,0,0,0,0,0,0,0,-0.209478,-0.238858,-0.012893,0.200126,0.234112,1.009887,0),
(6870,'World\\Generic\\PassiveDoodads\\PostBoxes\\PostBoxBloodElf.mdx',0,0,0,0,0,0,0,0,0,0,-0.517974,-0.527504,0.004483,0.517769,0.524019,2.417233,0),
(6891,'World\\Goober\\G_BookOpenMedium06.mdx',0,12116,0,12118,0,0,0,0,0,0,-0.301394,-0.176314,-0.033139,0.341079,0.194156,0.22705,0),
(6895,'World\\Generic\\PassiveDoodads\\TugofWar\\TugofWar_RedDustBag01.mdx',0,0,0,0,0,0,0,0,0,0,-0.54398,-0.502727,-0.036349,0.658614,0.502468,0.992269,0),
(6908,'World\\Goober\\G_Book01_Green.mdx',0,0,0,12117,12117,0,0,0,0,0,-0.302832,-0.224365,-0.000393,0.301016,0.22332,0.128939,0),
(7181,'World\\Expansion01\\Doodads\\Terokkar\\Crystal\\TerokkarCrystal03.mdx',8973,8973,8973,8973,8973,8973,8973,8973,8973,8973,-0.689127,-1.392459,-1.112698,0.675506,1.143137,3.908931,0),
(7487,'World\\Generic\\BloodElf\\Passive Doodads\\BL_sq_Crate_002.mdx',0,0,0,0,0,0,0,0,0,0,-0.416667,-0.416667,0,0.416667,0.416667,0.833333,0),
(7608,'World\\Generic\\PassiveDoodads\\GuildBank\\GuildVault_Dwarf_01.mdx',0,0,0,0,0,0,0,0,0,0,-0.71174,-3.319601,0.323285,1.165754,2.657752,5.636937,0),
(7748,'World\\Expansion02\\Doodads\\Generic\\Bonfire\\BonfireNorthrend_01.mdx',0,0,0,0,0,0,0,0,0,0,-2.139699,-4.261206,-1.663296,2.097595,3.784491,5.581555,0),
(8171,'World\\Goober\\G_GnomeMailBox.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8197,'SPELLS\\INSTANCENEWPORTAL_PURPLE_SKULL.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8363,'World\\Expansion01\\Doodads\\Generic\\BloodElf\\Cups\\BE_Cup01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8517,'World\\Expansion01\\Doodads\\Generic\\BloodElf\\Bottles\\BE_Bottle04.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8757,'world\\generic\\dwarf\\passive doodads\\excavationbannerstands\\excavationbannerstand02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(8994,'world\\generic\\passivedoodads\\oktoberfest\\beerfest_crate.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9145,'creature\\invisiblestalker\\invisiblestalker.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9371,'world\\generic\\goblin\\passivedoodads\\kezan\\items\\goblin_forge_01.MDX',0,0,0,0,0,0,0,0,0,0,-2.210741,-2.212729,-0.064012,2.218538,2.345337,5.222637,0),
(9432,'world\\expansion03\\doodads\\twilighthammer\\brazier\\twilightshammer_brazier_01.MDX',0,0,0,0,0,0,0,0,0,0,-1.010818,-1.13252,-0.044028,1.019437,1.151566,1.471741,0),
(9510,'spells\\invisible.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9652,'WORLD\\GENERIC\\GOBLIN\\PASSIVEDOODADS\\KEZAN\\ITEMS\\GOBLIN_KEZAN_ANVIL_01.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9678,'world\\expansion03\\doodads\\lostisles\\trees\\lostisles_treefire_02.mdx',0,0,0,0,0,0,0,0,0,0,-2.729066,-3.205865,-1.36446,2.674848,2.907541,8.028709,0),
(9681,'WORLD\\EXPANSION01\\DOODADS\\GENERIC\\BLOODELF\\LANTERN\\BE_LANTERN01.MDX',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9694,'world\\expansion03\\doodads\\deepholm\\minerals\\deepholm_mineralcrystal01_green.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9715,'world\\expansion03\\doodads\\deepholm\\crystals\\deepholm_crystalblock01_chalk.mdx',0,0,0,0,0,0,0,0,0,0,-9.113967,-7.606616,-1.284348,7.74481,8.673062,16.36803,0),
(9716,'world\\expansion03\\doodads\\deepholm\\crystals\\deepholm_crystalblock02_chalk.mdx',0,0,0,0,0,0,0,0,0,0,-9.756601,-11.68612,-1.861683,10.58417,9.378209,42.30661,0),
(9721,'world\\expansion03\\doodads\\earthen\\banners\\earthen_rock_banner_01.mdx',0,0,0,0,0,0,0,0,0,0,-0.63146,-0.943833,0.235085,0.63146,0.943833,4.275407,0),
(9722,'world\\expansion03\\doodads\\earthen\\earthen_projectile_01.mdx',0,0,0,0,0,0,0,0,0,0,-0.565112,-0.414023,-0.543957,0.479975,0.562798,0.509156,0),
(9814,'WORLD\\EXPANSION03\\DOODADS\\EARTHEN\\EARTHEN_LIGHT_01.MDX',0,0,0,0,0,0,0,0,0,0,-0.3598,-0.632488,-0.032713,0.275679,0.403457,1.744381,0),
(9815,'world\\expansion03\\doodads\\deepholm\\deepholm_cluster.mdx',0,0,0,0,0,0,0,0,0,0,-2.988356,-5.242034,-1.723203,3.106069,5.326995,13.24898,0),
(9840,'world\\generic\\bloodelf\\passive doodads\\bl_sq_crate_003.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9842,'world\\expansion03\\doodads\\twilighthammer\\magicaldevices\\twilightshammer_magicaldevice_02earth.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9846,'world\\expansion01\\doodads\\zangar\\mushroom\\zangarmushroom03.mdx',0,0,0,0,0,0,0,0,0,0,-0.700005,-0.732508,-0.037212,0.758002,0.74388,1.987611,0),
(9847,'world\\expansion03\\doodads\\deepholm\\mushrooms\\deepholm_mossymushroom01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9849,'world\\expansion03\\doodads\\twilighthammer\\magicaldevices\\twilightshammer_magicaldevice_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9855,'world\\expansion03\\doodads\\trogg\\crates\\trog_crate_01.mdx',0,0,0,0,0,0,0,0,0,0,-1.022823,-0.968911,-0.124408,0.853767,0.97907,1.296261,0),
(9856,'world\\expansion03\\doodads\\earthen\\earthen_onager_wheel_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9857,'world\\expansion03\\doodads\\earthen\\earthen_onager_trunk_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9858,'world\\expansion03\\doodads\\earthen\\earthen_onager_trunk_02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9859,'world\\expansion03\\doodads\\earthen\\earthen_onager_beam_01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9860,'world\\expansion03\\doodads\\earthen\\earthen_onager_beam_02.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9861,'world\\expansion03\\doodads\\earthen\\earthen_onager_arm.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(9885,'world\\expansion03\\doodads\\twilighthammer\\barrel\\twilightshammer_barrel01.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10157,'world\\skillactivated\\tradeskillnodes\\elementium_miningnode_normal.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10158,'world\\skillactivated\\tradeskillnodes\\elementium_miningnode_rich.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10159,'world\\skillactivated\\tradeskillnodes\\obsidian_miningnode_normal.mdx',0,0,0,0,0,0,0,0,0,0,-1.366852,-1.249382,-1.007947,1.719012,1.160127,2.065927,0),
(10160,'world\\skillactivated\\tradeskillnodes\\obsidian_miningnode_rich.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10256,'world\\skillactivated\\tradeskillnodes\\bush_cinderbloom.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
(10266,'world\\skillactivated\\tradeskillnodes\\bush_heartblossom.mdx',0,0,0,0,0,0,0,0,0,0,-0.233063,-0.208685,-0.043568,0.281155,0.20476,0.302756,0),
(10283,'world\\expansion03\\doodads\\deepholm\\minerals\\deepholm_mineralcrystal02_orange.mdx',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

