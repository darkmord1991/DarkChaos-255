-- ---------------------------------------------------------------------------
-- Azshara Crater (map 37) -- looser quest level requirements, 2026-10-01
-- ---------------------------------------------------------------------------
-- No crater quest has a prerequisite quest: there is no quest_template_addon
-- chain, no `conditions` row, no `disables` row and no phasing. The only gate
-- is MinLevel, and it sat only 2-5 levels under each quest's level. A hub's
-- quests therefore opened one at a time, each as the XP from the earlier ones
-- came in, which played like a quest chain.
--
-- New rule, per quest: MinLevel = QuestLevel - 6. Two limits apply:
--   * never below the MinLevel of the quest that sends players to that hub,
--     so a hub's quests don't open before the hub does;
--   * never above the current value.
-- A wider window gains nothing: at 6 levels above the player a quest is already
-- deep red.
--
-- These 19 quests keep their level requirement:
--   * the quests turned in at another hub. They set the pace from hub to hub:
--     hand-offs 300106 300206 300306 300405 300505 300604 300704 and
--     breadcrumbs 300950-300955.
--   * the solo kills of a single elite or rare elite: 300506 Scalebeard,
--     300605 Solenor, 300609 Lethtendris, 300610 The Ravenian,
--     300703 Nexus-Prince Shaffar, 300803 Gondria.
-- The group-quest hubs (Idona to Arcanigos) follow the same rule. Most of their
-- quests were already below it.
--
-- Bots barely notice the change. They still take a quest only once it is at
-- most 3 levels above them (NewRpgBaseAction::IsQuestCapableDoing), and every
-- new MinLevel already allows that.
--
-- Idempotent: each UPDATE fires only while MinLevel still holds the old value.
-- That makes the file safe to apply twice, and it never overwrites a later
-- edit. Restart the worldserver afterwards. Do NOT use `.reload quest_template`:
-- it frees every Quest object, and playerbots keep Quest pointers in their RPG
-- state (NewRpgInfo).
-- ---------------------------------------------------------------------------

-- Zone 1 - Scout Thalindra / Warden Stonebrook (reachable from level 1)
UPDATE `quest_template` SET `MinLevel` = 1 WHERE `ID` = 300107 AND `MinLevel` = 2; -- L5 Hides Against the Cold
UPDATE `quest_template` SET `MinLevel` = 1 WHERE `ID` = 300102 AND `MinLevel` = 2; -- L6 Bears at the Larder
UPDATE `quest_template` SET `MinLevel` = 2 WHERE `ID` = 300103 AND `MinLevel` = 4; -- L8 Restless Timberlings
UPDATE `quest_template` SET `MinLevel` = 2 WHERE `ID` = 300108 AND `MinLevel` = 5; -- L8 Tide of Murlocs
UPDATE `quest_template` SET `MinLevel` = 3 WHERE `ID` = 300104 AND `MinLevel` = 5; -- L9 The Webwood Ridge
UPDATE `quest_template` SET `MinLevel` = 4 WHERE `ID` = 300105 AND `MinLevel` = 7; -- L10 What Stirs the Grove

-- Zone 2 - Arcanist Melia / Spirit of Kelvenar (reachable from level 8)
UPDATE `quest_template` SET `MinLevel` = 8 WHERE `ID` = 300200 AND `MinLevel` = 10; -- L12 The Restless Dead
UPDATE `quest_template` SET `MinLevel` = 8 WHERE `ID` = 300201 AND `MinLevel` = 11; -- L14 Rifts in the Ley
UPDATE `quest_template` SET `MinLevel` = 9 WHERE `ID` = 300205 AND `MinLevel` = 11; -- L15 Varo'then's Journal
UPDATE `quest_template` SET `MinLevel` = 9 WHERE `ID` = 300207 AND `MinLevel` = 12; -- L15 Dust of the Fallen
UPDATE `quest_template` SET `MinLevel` = 10 WHERE `ID` = 300202 AND `MinLevel` = 12; -- L16 Golems Run Wild
UPDATE `quest_template` SET `MinLevel` = 10 WHERE `ID` = 300203 AND `MinLevel` = 13; -- L16 A Voice Among the Ruins
UPDATE `quest_template` SET `MinLevel` = 12 WHERE `ID` = 300204 AND `MinLevel` = 14; -- L18 The Wailing Noble
UPDATE `quest_template` SET `MinLevel` = 12 WHERE `ID` = 300208 AND `MinLevel` = 14; -- L18 Poisoned Waters

-- Zone 3 - Pathfinder Gor'nash (reachable from level 16)
UPDATE `quest_template` SET `MinLevel` = 17 WHERE `ID` = 300307 AND `MinLevel` = 20; -- L23 Beads of the Thistlefur
UPDATE `quest_template` SET `MinLevel` = 19 WHERE `ID` = 300302 AND `MinLevel` = 21; -- L25 Silence the Totems
UPDATE `quest_template` SET `MinLevel` = 19 WHERE `ID` = 300308 AND `MinLevel` = 21; -- L25 Teeth in the Shallows
UPDATE `quest_template` SET `MinLevel` = 20 WHERE `ID` = 300300 AND `MinLevel` = 22; -- L26 A Test of Steel
UPDATE `quest_template` SET `MinLevel` = 20 WHERE `ID` = 300301 AND `MinLevel` = 22; -- L26 Ten Cursed Horns
UPDATE `quest_template` SET `MinLevel` = 20 WHERE `ID` = 300303 AND `MinLevel` = 23; -- L26 The Captive Elder
UPDATE `quest_template` SET `MinLevel` = 22 WHERE `ID` = 300304 AND `MinLevel` = 24; -- L28 Rot at the Root
UPDATE `quest_template` SET `MinLevel` = 24 WHERE `ID` = 300305 AND `MinLevel` = 25; -- L30 Drive Them from the Wood

-- Zone 4 - Wavemaster Kol'gar (reachable from level 25)
UPDATE `quest_template` SET `MinLevel` = 28 WHERE `ID` = 300407 AND `MinLevel` = 30; -- L34 Rations for the Tide-Guard
UPDATE `quest_template` SET `MinLevel` = 31 WHERE `ID` = 300408 AND `MinLevel` = 33; -- L37 Thieves Among the Ruins
UPDATE `quest_template` SET `MinLevel` = 33 WHERE `ID` = 300400 AND `MinLevel` = 35; -- L39 Break the Spitelash
UPDATE `quest_template` SET `MinLevel` = 33 WHERE `ID` = 300409 AND `MinLevel` = 35; -- L39 Bounty: Molok the Crusher
UPDATE `quest_template` SET `MinLevel` = 34 WHERE `ID` = 300404 AND `MinLevel` = 36; -- L40 Bounty: Prince Nazjak
UPDATE `quest_template` SET `MinLevel` = 39 WHERE `ID` = 300401 AND `MinLevel` = 41; -- L45 Shells for the Wall
UPDATE `quest_template` SET `MinLevel` = 45 WHERE `ID` = 300402 AND `MinLevel` = 47; -- L51 The Arcane Gluttons
UPDATE `quest_template` SET `MinLevel` = 47 WHERE `ID` = 300403 AND `MinLevel` = 49; -- L53 Scales of the Blue

-- Zone 5 - Demonologist Vex'ara (reachable from level 36)
UPDATE `quest_template` SET `MinLevel` = 40 WHERE `ID` = 300501 AND `MinLevel` = 42; -- L46 Echoes of Zin-Azshari
UPDATE `quest_template` SET `MinLevel` = 41 WHERE `ID` = 300500 AND `MinLevel` = 43; -- L47 The Turned Timbermaw
UPDATE `quest_template` SET `MinLevel` = 42 WHERE `ID` = 300502 AND `MinLevel` = 44; -- L48 The Drowned Shrine
UPDATE `quest_template` SET `MinLevel` = 42 WHERE `ID` = 300507 AND `MinLevel` = 44; -- L48 Feathers of the Thunderhead
UPDATE `quest_template` SET `MinLevel` = 45 WHERE `ID` = 300503 AND `MinLevel` = 47; -- L51 Bounty: Ragepaw
UPDATE `quest_template` SET `MinLevel` = 46 WHERE `ID` = 300504 AND `MinLevel` = 48; -- L52 Bounty: Varo'then

-- Zone 6 - Felsworn Kael'thos (reachable from level 46)
UPDATE `quest_template` SET `MinLevel` = 46 WHERE `ID` = 300600 AND `MinLevel` = 48; -- L52 The Legashi Blight
UPDATE `quest_template` SET `MinLevel` = 47 WHERE `ID` = 300601 AND `MinLevel` = 49; -- L53 Jadefire Grown Bold
UPDATE `quest_template` SET `MinLevel` = 49 WHERE `ID` = 300602 AND `MinLevel` = 51; -- L55 Breaking the Watch
UPDATE `quest_template` SET `MinLevel` = 49 WHERE `ID` = 300607 AND `MinLevel` = 51; -- L55 Killers in the Dark
UPDATE `quest_template` SET `MinLevel` = 49 WHERE `ID` = 300608 AND `MinLevel` = 51; -- L55 Fires That Walk
UPDATE `quest_template` SET `MinLevel` = 54 WHERE `ID` = 300606 AND `MinLevel` = 55; -- L60 To the Dragon Coast

-- Zone 7 - Dragonbinder Seryth (reachable from level 50)
UPDATE `quest_template` SET `MinLevel` = 56 WHERE `ID` = 300702 AND `MinLevel` = 58; -- L62 The Corrupted Brood
UPDATE `quest_template` SET `MinLevel` = 57 WHERE `ID` = 300710 AND `MinLevel` = 60; -- L63 Bounty: Marticar
UPDATE `quest_template` SET `MinLevel` = 58 WHERE `ID` = 300709 AND `MinLevel` = 60; -- L64 Bounty: Doomsayer Jurim
UPDATE `quest_template` SET `MinLevel` = 59 WHERE `ID` = 300700 AND `MinLevel` = 61; -- L65 The Unquiet Coast
UPDATE `quest_template` SET `MinLevel` = 59 WHERE `ID` = 300701 AND `MinLevel` = 60; -- L65 Unbound and Burning
UPDATE `quest_template` SET `MinLevel` = 61 WHERE `ID` = 300706 AND `MinLevel` = 65; -- L67 Orders in the Dark
UPDATE `quest_template` SET `MinLevel` = 62 WHERE `ID` = 300707 AND `MinLevel` = 65; -- L68 The Starving Threshold
UPDATE `quest_template` SET `MinLevel` = 62 WHERE `ID` = 300708 AND `MinLevel` = 65; -- L68 Bounty: Voidhunter Yar
UPDATE `quest_template` SET `MinLevel` = 62 WHERE `ID` = 300711 AND `MinLevel` = 65; -- L68 Collidus the Warp-Watcher
UPDATE `quest_template` SET `MinLevel` = 62 WHERE `ID` = 300712 AND `MinLevel` = 65; -- L68 Two Who Will Not Fade

-- Zone 8 - Archmage Thadeus / Nexus-Prince Haramad (reachable from level 68)
UPDATE `quest_template` SET `MinLevel` = 68 WHERE `ID` = 300800 AND `MinLevel` = 70; -- L72 Ranks of the Blighted
UPDATE `quest_template` SET `MinLevel` = 68 WHERE `ID` = 300804 AND `MinLevel` = 70; -- L73 Relics of the Sanctum
UPDATE `quest_template` SET `MinLevel` = 69 WHERE `ID` = 300801 AND `MinLevel` = 72; -- L75 Rest for the Moonrest
UPDATE `quest_template` SET `MinLevel` = 70 WHERE `ID` = 300805 AND `MinLevel` = 73; -- L76 Unbind the Phantoms
UPDATE `quest_template` SET `MinLevel` = 72 WHERE `ID` = 300802 AND `MinLevel` = 75; -- L78 Masters of the Risen
UPDATE `quest_template` SET `MinLevel` = 72 WHERE `ID` = 300820 AND `MinLevel` = 75; -- L78 Weapons of the Dead
UPDATE `quest_template` SET `MinLevel` = 73 WHERE `ID` = 300821 AND `MinLevel` = 76; -- L79 The Shard Watchers
UPDATE `quest_template` SET `MinLevel` = 73 WHERE `ID` = 300822 AND `MinLevel` = 76; -- L79 Raiders out of the Mist

-- Prospector Khazgorm, group quests (reachable from level 40)
UPDATE `quest_template` SET `MinLevel` = 42 WHERE `ID` = 300921 AND `MinLevel` = 44; -- L48 Break the Iron Ranks
UPDATE `quest_template` SET `MinLevel` = 43 WHERE `ID` = 300922 AND `MinLevel` = 45; -- L49 Faulty Engineering
UPDATE `quest_template` SET `MinLevel` = 44 WHERE `ID` = 300920 AND `MinLevel` = 45; -- L50 Loregrain's Last Ember
UPDATE `quest_template` SET `MinLevel` = 45 WHERE `ID` = 300923 AND `MinLevel` = 46; -- L51 Ambassador of Flame

-- Priestess Lunara, group quests (reachable from level 63)
UPDATE `quest_template` SET `MinLevel` = 63 WHERE `ID` = 300513 AND `MinLevel` = 65; -- L67 The Defiled Sanctum
UPDATE `quest_template` SET `MinLevel` = 63 WHERE `ID` = 300510 AND `MinLevel` = 65; -- L69 The Wailing Baroness

-- Image of Arcanigos, group quests (reachable from level 74)
UPDATE `quest_template` SET `MinLevel` = 74 WHERE `ID` = 300966 AND `MinLevel` = 75; -- L78 Lady Nightswood
