-- DarkChaos: map 750 / 751 quests that stay grey inside their zone's level band
--
-- 234_ (map 750) and 71_ (map 751) set QuestLevel -1 + a band MinLevel on every quest whose
-- givers were their own clone entries. These 46 slipped through both: their giver or turn-in is
-- a gameobject, an entry outside the snapshot tables, or a quest added after those files ran.
-- They keep a fixed Cata/classic QuestLevel, so players see them grey and bots never take them.
--
-- SCOPE - nothing here can reach map 0 or 1. A quest is listed only if ALL of these hold:
--   * every creature and gameobject that starts or ends it is spawned on map 750/751 only,
--   * no item starts it,
--   * stock AzerothCore (acore_backup) has no spawned giver or turn-in for it,
--   * it can be finished on its map: the turn-in and every kill/object target spawn there,
--   * its prerequisite (PrevQuestID) is available on the same map and is not itself skipped,
--   * it is not a dungeon/raid/PvP or seasonal quest, and not a breadcrumb off the continent.
-- The UPDATE re-checks the first two rules at apply time, so a later edit that shares one of
-- these quests with another map makes the row a no-op instead of a leak.
--
-- 345 more grey quests on these maps are shared with map 0/1 (stock quest ids also handed out
-- in Kalimdor or Eastern Kingdoms). They are NOT touched here. Making them band-level needs
-- private clones, as HyjalCata/167_ did for the border zones.
--
-- Effect: QuestLevel -1 (XP and reward scale with the player, see 234_), MinLevel raised to the
-- band floor - 2 (the floor 234_/71_ already use). MinLevel is never lowered. Idempotent.
-- Apply against acore_world. Old values are listed below for a manual revert.
--
-- 100965 and 108419 live in HyjalCata/167_'s clone window (100000-199999). Re-running 167_
-- recreates that window from the stock quests, so re-apply this file after any 167_ re-run.
--
-- map 750 Hyjal (zone 4923, band 113-128, MinLevel floor 110): 12
--    25279  was QuestLevel 116 MinLevel  80  The Shrine Reclaimed
--    25280  was QuestLevel 116 MinLevel  80  The Shrine Reclaimed
--    25297  was QuestLevel 116 MinLevel  80  From the Mouth of Madness
--    25300  was QuestLevel 116 MinLevel  80  The Eye of Twilight
--    25301  was QuestLevel  81 MinLevel  80  Mastering Puppets
--    25316  was QuestLevel 116 MinLevel  80  As Hyjal Burns
--    25601  was QuestLevel 116 MinLevel  80  Head of the Class
--    25617  was QuestLevel 116 MinLevel  80  Into the Maw!
--    25618  was QuestLevel 116 MinLevel  80  Into the Maw!
--    25644  was QuestLevel 119 MinLevel  78  The Twilight Egg
--    25763  was QuestLevel 116 MinLevel  80  The Codex of Shadows
--    29066  was QuestLevel 116 MinLevel  80  Good News... and Bad News
-- map 750 Winterspring (zone 4926, band 104-115, MinLevel floor 101): 2
--    28640  was QuestLevel 109 MinLevel  51  Fresh Frostsabers
--    28742  was QuestLevel 109 MinLevel  51  Shy-Rotam
-- map 750 Felwood (zone 4927, band 96-106, MinLevel floor 93): 4
--    28536  was QuestLevel 101 MinLevel  49  The Curse of Zin-Malor
--    28542  was QuestLevel  96 MinLevel  44  Warchief's Command: Felwood!
--    28543  was QuestLevel  96 MinLevel  44  Hero's Call: Felwood!
--   108419  was QuestLevel 101 MinLevel  50  An Imp's Request
-- map 750 Darkshore (zone 4929, band 80-90, MinLevel floor 78): 6
--    13564  was QuestLevel  80 MinLevel   8  A Lost Companion
--    13940  was QuestLevel  83 MinLevel  13  Leaving the Dream
--    26383  was QuestLevel  80 MinLevel   8  Breaking Waves of Change
--    26385  was QuestLevel  80 MinLevel   8  Breaking Waves of Change
--    28490  was QuestLevel  80 MinLevel   9  Hero's Call: Darkshore!
--   100965  was QuestLevel  84 MinLevel  13  The Tower of Althalaxx
-- map 750 Azshara (zone 4930, band 80-90, MinLevel floor 78): 12
--    14267  was QuestLevel  82 MinLevel  11  Investigating the Sea Shrine
--    14270  was QuestLevel  13 MinLevel  11  The Keystone Shard
--    14271  was QuestLevel  82 MinLevel  11  Report to Twocrush
--    14299  was QuestLevel  85 MinLevel  15  Xylem's Asylum
--    14308  was QuestLevel  82 MinLevel  11  When Science Attacks
--    14424  was QuestLevel  82 MinLevel  11  Need More Science
--    14428  was QuestLevel  85 MinLevel  16  Amberwind's Journal
--    14429  was QuestLevel  18 MinLevel  16  Arcane De-Construction
--    14430  was QuestLevel  85 MinLevel  16  Hacking the Construct
--    14478  was QuestLevel  84 MinLevel  12  Operation Fishgut
--    24449  was QuestLevel  85 MinLevel  12  Shore Leave
--    26335  was QuestLevel  84 MinLevel  84  Ready the Navy
-- map 750 Ashenvale (zone 4931, band 88-98, MinLevel floor 85): 6
--    13623  was QuestLevel  91 MinLevel  19  Delivery for Orendil
--    13628  was QuestLevel  91 MinLevel  19  Got Wood?
--    13848  was QuestLevel  91 MinLevel  19  Bad News Bear-er
--    13928  was QuestLevel  92 MinLevel  21  Recover the Fallen
--    26446  was QuestLevel  21 MinLevel  19  Reclaiming Felfire Hill
--    26464  was QuestLevel  91 MinLevel  19  The Lost Gem
-- map 751 Silverpine Forest (zone 4935, band 134-140, MinLevel floor 132): 1
--    27039  was QuestLevel  11 MinLevel   9  Dangerous Intentions
-- map 751 Arathi Highlands (zone 4938, band 142-147, MinLevel floor 140): 3
--    26039  was QuestLevel  29 MinLevel  27  The Princess Trapped
--    26041  was QuestLevel  29 MinLevel  27  Stones of Binding
--    26042  was QuestLevel  29 MinLevel  27  Breaking the Keystone

UPDATE `quest_template` AS `q`
JOIN (
    SELECT 25279 AS `ID`, 110 AS `BandMin` UNION ALL
    SELECT 25280, 110 UNION ALL
    SELECT 25297, 110 UNION ALL
    SELECT 25300, 110 UNION ALL
    SELECT 25301, 110 UNION ALL
    SELECT 25316, 110 UNION ALL
    SELECT 25601, 110 UNION ALL
    SELECT 25617, 110 UNION ALL
    SELECT 25618, 110 UNION ALL
    SELECT 25644, 110 UNION ALL
    SELECT 25763, 110 UNION ALL
    SELECT 29066, 110 UNION ALL
    SELECT 28640, 101 UNION ALL
    SELECT 28742, 101 UNION ALL
    SELECT 28536, 93 UNION ALL
    SELECT 28542, 93 UNION ALL
    SELECT 28543, 93 UNION ALL
    SELECT 108419, 93 UNION ALL
    SELECT 13564, 78 UNION ALL
    SELECT 13940, 78 UNION ALL
    SELECT 26383, 78 UNION ALL
    SELECT 26385, 78 UNION ALL
    SELECT 28490, 78 UNION ALL
    SELECT 100965, 78 UNION ALL
    SELECT 14267, 78 UNION ALL
    SELECT 14270, 78 UNION ALL
    SELECT 14271, 78 UNION ALL
    SELECT 14299, 78 UNION ALL
    SELECT 14308, 78 UNION ALL
    SELECT 14424, 78 UNION ALL
    SELECT 14428, 78 UNION ALL
    SELECT 14429, 78 UNION ALL
    SELECT 14430, 78 UNION ALL
    SELECT 14478, 78 UNION ALL
    SELECT 24449, 78 UNION ALL
    SELECT 26335, 78 UNION ALL
    SELECT 13623, 85 UNION ALL
    SELECT 13628, 85 UNION ALL
    SELECT 13848, 85 UNION ALL
    SELECT 13928, 85 UNION ALL
    SELECT 26446, 85 UNION ALL
    SELECT 26464, 85 UNION ALL
    SELECT 27039, 132 UNION ALL
    SELECT 26039, 140 UNION ALL
    SELECT 26041, 140 UNION ALL
    SELECT 26042, 140
) AS `t` ON `t`.`ID` = `q`.`ID`
    AND NOT EXISTS (SELECT 1 FROM `creature_queststarter` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` NOT IN (750, 751))
    AND NOT EXISTS (SELECT 1 FROM `creature_questender` AS `s` JOIN `creature` AS `c` ON `c`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `c`.`map` NOT IN (750, 751))
    AND NOT EXISTS (SELECT 1 FROM `gameobject_queststarter` AS `s` JOIN `gameobject` AS `g` ON `g`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` NOT IN (750, 751))
    AND NOT EXISTS (SELECT 1 FROM `gameobject_questender` AS `s` JOIN `gameobject` AS `g` ON `g`.`id` = `s`.`id`
        WHERE `s`.`quest` = `q`.`ID` AND `g`.`map` NOT IN (750, 751))
    AND NOT EXISTS (SELECT 1 FROM `item_template` AS `i` WHERE `i`.`startquest` = `q`.`ID`)
SET `q`.`QuestLevel` = -1, `q`.`MinLevel` = IF(`q`.`MinLevel` > `t`.`BandMin`, `q`.`MinLevel`, `t`.`BandMin`);

-- Skipped on purpose (safe to edit, but scaling would not help): fix the reason first.
--   750 4923  25298  Free Your Mind, the Rest Follows
--       kill target 39719 not on map
--   750 4923  25303  Elementary!
--       kill target 39741 not on map. kill target 39739 not on map. kill target 39727 not on map. kill targe
--       t 39740 not on map
--   750 4923  25312  Return to Duskwhisper
--       prerequisite 25303 is itself excluded
--   750 4923  25332  Get Me Outta Here!
--       kill target 39808 not on map
--   750 4923  25411  A New Master
--       no ender on map. kill target 40099 not on map
--   750 4923  25412  The Name Never Spoken
--       prerequisite 25411 is itself excluded
--   750 4923  25663  An Offering for Aviana
--       no ender on map. kill target 41079 not on map
--   750 4923  25665  A Plea From Beyond
--       prerequisite 25663 is itself excluded
--   750 4923  27398  The Battle Is Won, The War Goes On
--       leads to 27203 which is not on map 750. no ender on map
--   750 4923  27399  The Battle Is Won, The War Goes On
--       no ender on map
--   750 4926 100980  The New Springs
--       prerequisite 974 not available on map 750
--   750 4926 103512  In Eranikus' Own Words
--       prerequisite 3374 not available on map 750
--   750 4926 103908  It's a Secret to Everybody
--       prerequisite 3845 not available on map 750
--   750 4926 104808  Felnok Steelspring
--       prerequisite 4726 not available on map 750
--   750 4927  27995  Dance for Ruumbo!
--       prerequisite 27989 not available on map 750. kill target 3747555 not on map
--   750 4927  28221  These Roots Were Made For Stompin'
--       no ender on map
--   750 4927  28224  The Last Protector
--       no ender on map
--   750 4927  28368  Fire in the Hole!
--       kill target 3748352 not on map
--   750 4927 108257  Blood of Morphaz
--       instance quest (QuestInfoID 81). prerequisite 8256 not available on map 750
--   750 4928 101123  Rabine Saturna
--       leads to 101124 which is not on map 750
--   750 4928 106762  Rabine Saturna
--       prerequisite 6761 not available on map 750. leads to 101124 which is not on map 750
--   750 4928 106844  Umber, Archivist
--       prerequisite 1126 not available on map 750
--   750 4928 107066  Seed of Life
--       instance quest (QuestInfoID 81)
--   750 4928 108446  Shrouded in Nightmare
--       QuestSortID -1 (raid-item chain)
--   750 4928 108734  Tyrande and Remulos
--       prerequisite 8733 not available on map 750
--   750 4928 113073  The Keeper's Favor
--       prerequisite 13072 not available on map 750
--   750 4929  13897  The Battle for Darkshore
--       kill target 3734485 not on map
--   750 4930  14190  The Perfect Prism
--       prerequisite 14165 not available on map 750
--   750 4930  14192  Prismbreak
--       prerequisite 14190 is itself excluded
--   750 4930  14310  Segmentation Fault: Core Dumped
--       kill target 3636096 not on map
--   750 4930  26293  Machines of War
--       prerequisite 28717 not available on map 750
--   750 4930  26294  Weapons of Mass Dysfunction
--       no ender on map. kill target 42674 not on map. kill target 42675 not on map
--   750 4930  26324  Where Is My Warfleet?
--       prerequisite 26294 is itself excluded
--   750 4930  26337  Beating the Market
--       kill target 3642798 not on map
--   750 4930  26388  Twilight Skies
--       no ender on map. kill target 42977 not on map
--   750 4931  13792  The Shadewalker
--       prerequisite 13766 not available on map 750
--   750 4931  13803  Blood of the Weak
--       prerequisite 13712 not available on map 750
--   750 4931  13872  Worgen Wisdom
--       prerequisite 13868 not available on map 750
--   750 4931  13921  He Who Would Be Forgiven
--       prerequisite 13919 not available on map 750
--   751 4924  27460  Soft Landing
--       prerequisite 27459 not available on map 751
--   751 4932  27170  The Abandoned Crypt
--       prerequisite 27169 not available on map 751
--   751 4933  27718  Warchief's Command: Vashj'ir!
--       no ender on map
--   751 4933  27721  Warchief's Command: Mount Hyjal!
--       leads to 25316 which is not on map 751. no ender on map
--   751 4933  27722  Warchief's Command: Deepholm!
--       leads to 27203 which is not on map 751. no ender on map
--   751 4933  28557  Warchief's Command: Uldum!
--       no ender on map
--   751 4933  28581  Warchief's Command: Searing Gorge!
--       no ender on map
--   751 4933  28667  Warchief's Command: Burning Steppes!
--       no ender on map
--   751 4933  28671  Warchief's Command: Blasted Lands!
--       no ender on map
--   751 4933  28677  Warchief's Command: Swamp of Sorrows!
--       no ender on map
--   751 4933  28688  Warchief's Command: Northern Stranglethorn Vale!
--       prerequisite 26416 not available on map 751. leads to 26278 which is not on map 751. no ender on map
--   751 4933  28704  Warchief's Command: The Cape of Stranglethorn!
--       no ender on map
--   751 4933  28705  Warchief's Command: Outland!
--       leads to 10120 which is not on map 751. no ender on map
--   751 4933  28711  Warchief's Command: Northrend!
--       no ender on map
--   751 4933  28717  Warchief's Command: Twilight Highlands!
--       no ender on map
--   751 4933  29157  The Zandalari Menace
--       no ender on map
--   751 4933  29388  Guardians of Hyjal: Firelands Invasion!
--       leads to 29145 which is not on map 751. no ender on map
--   751 4935  27045  Waiting to Exsanguinate
--       no ender on map. kill target 44882 not on map
--   751 4936  28189  Do the Right Thing
--       no ender on map
--
-- Check after applying (expect 46 rows, all QuestLevel -1):
-- SELECT `ID`, `QuestLevel`, `MinLevel` FROM `quest_template` WHERE `ID` IN (
--     25279, 25280, 25297, 25300, 25301, 25316, 25601, 25617, 25618, 25644, 25763, 29066,
--     28640, 28742, 28536, 28542, 28543, 108419, 13564, 13940, 26383, 26385, 28490, 100965,
--     14267, 14270, 14271, 14299, 14308, 14424, 14428, 14429, 14430, 14478, 24449, 26335,
--     13623, 13628, 13848, 13928, 26446, 26464, 27039, 26039, 26041, 26042) ORDER BY `ID`
