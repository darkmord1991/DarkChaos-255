-- =====================================================================
-- Boss overview on Heroic: the missing DungeonEncounter difficulty rows
-- =====================================================================
-- Apply against: acore_world. Safe to re-run.
--
-- WHY
-- ---------------------------------------------------------------------
-- The DENC boss tracker (the retail-style "Dungeon / Gnomeregan / 1/5
-- defeated" block) is keyed throughout by DungeonEncounter.dbc entry id,
-- and dc_addon_encounters.cpp builds its list with the same map+difficulty
-- lookup Map::UpdateEncounterState uses. DungeonEncounter rows are per
-- difficulty, and the Vanilla dungeons only have two of the three:
--
--     map  90 Gnomeregan   {difficulty 0: 5 rows, difficulty 2: 5 rows}
--     map  33 Shadowfang   {0: 8, 2: 8}
--     map 230 Blackrock D. {0: 19, 2: 19}
--                                    ^ no difficulty 1 anywhere
--
-- Somebody already added the difficulty-2 (Mythic) rows - their ids sit
-- well above the stock range - but Heroic was skipped. So on Heroic the
-- lookup returns an empty list and the tracker draws nothing, which is
-- exactly the "no boss overview in Gnomeregan" report.
--
-- It is not only cosmetic. Map::UpdateEncounterState uses the same rows
-- to set the completedEncounters bits, so on Heroic no Vanilla boss kill
-- was ever credited to the instance's persisted progress either.
--
-- All 16 TBC dungeons already carry difficulty-1 rows (they had real
-- heroic modes in stock), so they are untouched and were verified as
-- such. Difficulty 2 is complete on every Vanilla map, so Mythic was
-- never affected.
--
-- WHY THIS IS A DB OVERLAY AND NOT A DBC EDIT
-- ---------------------------------------------------------------------
-- DBCStores.cpp loads this store as
--
--     LOAD_DBC(sDungeonEncounterStore, "DungeonEncounter.dbc", "dungeonencounter_dbc")
--
-- and LoadDBC calls storage.Load(file) FIRST, then storage.LoadFromDB().
-- DBCDatabaseLoader::Load keeps the file-loaded index table
-- (memcpy of the existing rows), overrides only ids that collide, and
-- appends the rest - so this is an additive merge, not a replacement.
-- Adding rows here needs no DungeonEncounter.dbc rebuild and no client
-- patch: DENC pushes the list to the addon from the server, so the client
-- never reads these ids itself.
--
-- IDS
-- ---------------------------------------------------------------------
-- The highest id in the shipped DungeonEncounter.dbc is 1578. These rows
-- start at 20000 to leave the whole 1579-19999 range free for future
-- Blizzard-shaped or hand-authored entries. OrderIndex and Bit are copied
-- verbatim from each dungeon's difficulty-0 row - Bit is the position in
-- the completedEncounters mask, so it MUST match difficulty 0 or saved
-- progress would decode differently per difficulty.
--
-- NOT COVERED
-- ---------------------------------------------------------------------
-- Maps 821 and 822 (the DarkChaos Stratholme/Scholomance clones) have no
-- DungeonEncounter rows at ANY difficulty, so there is nothing to clone
-- and they get no boss overview on any difficulty. Giving them one means
-- authoring encounters from scratch and matching them to whatever bits
-- instance_stratholme_dc / instance_scholomance_dc actually set - a
-- separate job, not a copy.
-- =====================================================================

DELETE FROM `dungeonencounter_dbc` WHERE `ID` BETWEEN 20000 AND 20166;

INSERT INTO `dungeonencounter_dbc`
  (`ID`, `MapID`, `Difficulty`, `OrderIndex`, `Bit`, `Name_Lang_enUS`, `Name_Lang_Mask`, `SpellIconID`)
VALUES
  (20000, 33, 1, 0, 0, 'Rethilgore', 16712190, 0),
  (20001, 33, 1, 1000, 1, 'Razorclaw the Butcher', 16712190, 0),
  (20002, 33, 1, 2000, 2, 'Baron Silverlaine', 16712190, 0),
  (20003, 33, 1, 3000, 3, 'Commander Springvale', 16712190, 0),
  (20004, 33, 1, 4000, 4, 'Odo the Blindwatcher', 16712190, 0),
  (20005, 33, 1, 5000, 5, 'Fenrus the Devourer', 16712190, 0),
  (20006, 33, 1, 6000, 6, 'Wolf Master Nandos', 16712190, 0),
  (20007, 33, 1, 7000, 7, 'Archmage Arugal', 16712190, 0),
  (20008, 34, 1, 0, 0, 'Targorr the Dread', 16712190, 0),
  (20009, 34, 1, 1000, 1, 'Kam Deepfury', 16712190, 0),
  (20010, 34, 1, 2000, 2, 'Hamhock', 16712190, 0),
  (20011, 34, 1, 4000, 4, 'Dextren Ward', 16712190, 0),
  (20012, 34, 1, 5000, 3, 'Bazil Thredd', 16712190, 0),
  (20013, 36, 1, 0, 0, 'Rhahk''zor', 16712190, 0),
  (20014, 36, 1, 500, 1, 'Sneed', 16712190, 0),
  (20015, 36, 1, 750, 2, 'Gilnid', 16712190, 0),
  (20016, 36, 1, 875, 3, 'Mr. Smite', 16712190, 0),
  (20017, 36, 1, 937, 4, 'Cookie', 16712190, 0),
  (20018, 36, 1, 968, 5, 'Captain Greenskin', 16712190, 0),
  (20019, 36, 1, 1000, 6, 'Edwin VanCleef', 16712190, 0),
  (20020, 43, 1, 0, 0, 'Lady Anacondra', 16712190, 0),
  (20021, 43, 1, 1000, 1, 'Lord Cobrahn', 16712190, 0),
  (20022, 43, 1, 2000, 2, 'Kresh', 16712190, 0),
  (20023, 43, 1, 3000, 3, 'Lord Pythas', 16712190, 0),
  (20024, 43, 1, 4000, 4, 'Skum', 16712190, 0),
  (20025, 43, 1, 5000, 5, 'Lord Serpentis', 16712190, 0),
  (20026, 43, 1, 6000, 6, 'Verdan the Everliving', 16712190, 0),
  (20027, 43, 1, 7000, 7, 'Mutanus the Devourer', 16712190, 0),
  (20028, 47, 1, -1000, 2, 'Death Speaker Jargba', 16712190, 0),
  (20029, 47, 1, 0, 0, 'Roogug', 16712190, 0),
  (20030, 47, 1, 1000, 1, 'Aggem Thorncurse', 16712190, 0),
  (20031, 47, 1, 3000, 3, 'Overlord Ramtusk', 16712190, 0),
  (20032, 47, 1, 3500, 5, 'Agathelos the Raging', 16712190, 0),
  (20033, 47, 1, 4000, 4, 'Charlga Razorflank', 16712190, 0),
  (20034, 48, 1, 0, 0, 'Ghamoo-ra', 16712190, 0),
  (20035, 48, 1, 1000, 1, 'Lady Sarevess', 16712190, 0),
  (20036, 48, 1, 2000, 2, 'Gelihast', 16712190, 0),
  (20037, 48, 1, 3000, 3, 'Lorgus Jett', 16712190, 0),
  (20038, 48, 1, 5000, 5, 'Old Serra''kis', 16712190, 0),
  (20039, 48, 1, 6000, 6, 'Twilight Lord Kelris', 16712190, 0),
  (20040, 48, 1, 7000, 7, 'Aku''mai', 16712190, 0),
  (20041, 70, 1, 0, 0, 'Revelosh', 16712190, 0),
  (20042, 70, 1, 1000, 1, 'The Lost Dwarves', 16712190, 0),
  (20043, 70, 1, 2000, 2, 'Ironaya', 16712190, 0),
  (20044, 70, 1, 4000, 4, 'Ancient Stone Keeper', 16712190, 0),
  (20045, 70, 1, 5000, 5, 'Galgann Firehammer', 16712190, 0),
  (20046, 70, 1, 6000, 6, 'Grimlok', 16712190, 0),
  (20047, 70, 1, 7000, 7, 'Archaedas', 16712190, 0),
  (20048, 90, 1, 2000, 2, 'Grubbis', 16712190, 0),
  (20049, 90, 1, 2500, 1, 'Viscous Fallout', 16712190, 0),
  (20050, 90, 1, 3000, 3, 'Electrocutioner 6000', 16712190, 0),
  (20051, 90, 1, 4000, 4, 'Crowd Pummeler 9-60', 16712190, 0),
  (20052, 90, 1, 5000, 5, 'Mekgineer Thermaplugg', 16712190, 0),
  (20053, 109, 1, 0, 0, 'Atal''alarion', 16712190, 0),
  (20054, 109, 1, 500, 3, 'Jammal''an the Prophet', 16712190, 0),
  (20055, 109, 1, 1000, 1, 'Dreamscythe', 16712190, 0),
  (20056, 109, 1, 2000, 2, 'Weaver', 16712190, 0),
  (20057, 109, 1, 5000, 5, 'Morphaz', 16712190, 0),
  (20058, 109, 1, 6000, 6, 'Hazzas', 16712190, 0),
  (20059, 109, 1, 7000, 7, 'Avatar of Hakkar', 16712190, 0),
  (20060, 109, 1, 8000, 8, 'Shade of Eranikus', 16712190, 0),
  (20061, 129, 1, 0, 0, 'Tuten''kash', 16712190, 0),
  (20062, 129, 1, 1000, 1, 'Mordresh Fire Eye', 16712190, 0),
  (20063, 129, 1, 2000, 2, 'Glutton', 16712190, 0),
  (20064, 129, 1, 3000, 3, 'Amnennar the Coldbringer', 16712190, 0),
  (20065, 189, 1, 0, 0, 'Interrogator Vishas', 16712190, 0),
  (20066, 189, 1, 1000, 1, 'Bloodmage Thalnos', 16712190, 0),
  (20067, 189, 1, 2000, 2, 'Houndmaster Loksey', 16712190, 0),
  (20068, 189, 1, 3000, 3, 'Arcanist Doan', 16712190, 0),
  (20069, 189, 1, 4000, 4, 'Herod', 16712190, 0),
  (20070, 189, 1, 5000, 5, 'High Inquisitor Fairbanks', 16712190, 0),
  (20071, 189, 1, 6000, 6, 'High Inquisitor Whitemane', 16712190, 0),
  (20072, 209, 1, 0, 0, 'Hydromancer Velratha', 16712190, 0),
  (20073, 209, 1, 1000, 1, 'Ghaz''rilla', 16712190, 0),
  (20074, 209, 1, 2000, 2, 'Antu''sul', 16712190, 0),
  (20075, 209, 1, 3000, 3, 'Theka the Martyr', 16712190, 0),
  (20076, 209, 1, 4000, 4, 'Witch Doctor Zum''rah', 16712190, 0),
  (20077, 209, 1, 5000, 5, 'Nekrum Gutchewer', 16712190, 0),
  (20078, 209, 1, 6000, 6, 'Shadowpriest Sezz''ziz', 16712190, 0),
  (20079, 209, 1, 7000, 7, 'Chief Ukorz Sandscalp', 16712190, 0),
  (20080, 229, 1, 0, 0, 'Highlord Omokk', 16712190, 0),
  (20081, 229, 1, 1000, 1, 'Shadow Hunter Vosh''gajin', 16712190, 0),
  (20082, 229, 1, 2000, 2, 'War Master Voone', 16712190, 0),
  (20083, 229, 1, 3000, 3, 'Mother Smolderweb', 16712190, 0),
  (20084, 229, 1, 4000, 4, 'Urok Doomhowl', 16712190, 0),
  (20085, 229, 1, 5000, 5, 'Quartermaster Zigris', 16712190, 0),
  (20086, 229, 1, 5500, 7, 'Halycon', 16712190, 0),
  (20087, 229, 1, 6000, 6, 'Gizrul the Slavener', 16712190, 0),
  (20088, 229, 1, 8000, 8, 'Overlord Wyrmthalak', 16712190, 0),
  (20089, 229, 1, 9000, 9, 'Pyroguard Emberseer', 16712190, 0),
  (20090, 229, 1, 10000, 10, 'Solakar Flamewreath', 16712190, 0),
  (20091, 229, 1, 11000, 11, 'Warchief Rend Blackhand', 16712190, 0),
  (20092, 229, 1, 12000, 12, 'The Beast', 16712190, 0),
  (20093, 229, 1, 13000, 13, 'General Drakkisath', 16712190, 0),
  (20094, 230, 1, 0, 0, 'High Interrogator Gerstahn', 16712190, 0),
  (20095, 230, 1, 1000, 1, 'Lord Roccor', 16712190, 0),
  (20096, 230, 1, 2000, 2, 'Houndmaster Grebmar', 16712190, 0),
  (20097, 230, 1, 3000, 3, 'Ring of Law', 16712190, 0),
  (20098, 230, 1, 4000, 4, 'Pyromancer Loregrain', 16712190, 0),
  (20099, 230, 1, 5000, 5, 'Lord Incendius', 16712190, 0),
  (20100, 230, 1, 6000, 6, 'Warder Stilgiss', 16712190, 0),
  (20101, 230, 1, 7000, 7, 'Fineous Darkvire', 16712190, 0),
  (20102, 230, 1, 8000, 8, 'Bael''Gar', 16712190, 0),
  (20103, 230, 1, 9000, 9, 'General Angerforge', 16712190, 0),
  (20104, 230, 1, 10000, 10, 'Golem Lord Argelmach', 16712190, 0),
  (20105, 230, 1, 11000, 11, 'Hurley Blackbreath', 16712190, 0),
  (20106, 230, 1, 12000, 12, 'Phalanx', 16712190, 0),
  (20107, 230, 1, 13000, 13, 'Ribbly Screwspigot', 16712190, 0),
  (20108, 230, 1, 14000, 14, 'Plugger Spazzring', 16712190, 0),
  (20109, 230, 1, 15000, 15, 'Ambassador Flamelash', 16712190, 0),
  (20110, 230, 1, 16000, 16, 'The Seven', 16712190, 0),
  (20111, 230, 1, 17000, 17, 'Magmus', 16712190, 0),
  (20112, 230, 1, 18000, 18, 'Emperor Dagran Thaurissan', 16712190, 0),
  (20113, 289, 1, 0, 0, 'Kirtonos the Herald', 16712190, 0),
  (20114, 289, 1, 1000, 1, 'Jandice Barov', 16712190, 0),
  (20115, 289, 1, 2000, 2, 'Rattlegore', 16712190, 0),
  (20116, 289, 1, 3000, 3, 'Marduk Blackpool', 16712190, 0),
  (20117, 289, 1, 4000, 4, 'Vectus', 16712190, 0),
  (20118, 289, 1, 5000, 5, 'Ras Frostwhisper', 16712190, 0),
  (20119, 289, 1, 6000, 6, 'Instructor Malicia', 16712190, 0),
  (20120, 289, 1, 7000, 7, 'Doctor Theolen Krastinov', 16712190, 0),
  (20121, 289, 1, 8000, 8, 'Lorekeeper Polkelt', 16712190, 0),
  (20122, 289, 1, 9000, 9, 'The Ravenian', 16712190, 0),
  (20123, 289, 1, 10000, 10, 'Lord Alexei Barov', 16712190, 0),
  (20124, 289, 1, 11000, 11, 'Lady Illucia Barov', 16712190, 0),
  (20125, 289, 1, 12000, 12, 'Darkmaster Gandling', 16712190, 0),
  (20126, 329, 1, 1000, 1, 'Hearthsinger Forresten', 16712190, 0),
  (20127, 329, 1, 2000, 2, 'Timmy the Cruel', 16712190, 0),
  (20128, 329, 1, 3000, 3, 'Cannon Master Willey', 16712190, 0),
  (20129, 329, 1, 4000, 4, 'Malor the Zealous', 16712190, 0),
  (20130, 329, 1, 5000, 5, 'Archivist Galford', 16712190, 0),
  (20131, 329, 1, 6000, 6, 'Balnazzar', 16712190, 0),
  (20132, 329, 1, 6500, 0, 'The Unforgiven', 16712190, 0),
  (20133, 329, 1, 7000, 7, 'Baroness Anastari', 16712190, 0),
  (20134, 329, 1, 8000, 8, 'Nerub''enkan', 16712190, 0),
  (20135, 329, 1, 9000, 9, 'Maleki the Pallid', 16712190, 0),
  (20136, 329, 1, 10000, 10, 'Magistrate Barthilas', 16712190, 0),
  (20137, 329, 1, 11000, 11, 'Ramnstein the Gorger', 16712190, 0),
  (20138, 329, 1, 12000, 12, 'Baron Rivendare', 16712190, 0),
  (20139, 349, 1, 0, 0, 'Noxxion', 16712190, 0),
  (20140, 349, 1, 1000, 1, 'Razorlash', 16712190, 0),
  (20141, 349, 1, 2000, 2, 'Lord Vyletongue', 16712190, 0),
  (20142, 349, 1, 3000, 3, 'Celebras the Cursed', 16712190, 0),
  (20143, 349, 1, 4000, 4, 'Landslide', 16712190, 0),
  (20144, 349, 1, 5000, 5, 'Tinkerer Gizlock', 16712190, 0),
  (20145, 349, 1, 6000, 6, 'Rotgrip', 16712190, 0),
  (20146, 349, 1, 7000, 7, 'Princess Theradras', 16712190, 0),
  (20147, 389, 1, 0, 0, 'Oggleflint', 16712190, 0),
  (20148, 389, 1, 2000, 2, 'Jergosh the Invoker', 16712190, 0),
  (20149, 389, 1, 3000, 3, 'Bazzalan', 16712190, 0),
  (20150, 389, 1, 4000, 1, 'Taragaman the Hungerer', 16712190, 0),
  (20151, 429, 1, 0, 0, 'Zevrim Thornhoof', 16712190, 0),
  (20152, 429, 1, 1000, 1, 'Hydrospawn', 16712190, 0),
  (20153, 429, 1, 2000, 2, 'Lethtendris', 16712190, 0),
  (20154, 429, 1, 3000, 3, 'Alzzin the Wildshaper', 16712190, 0),
  (20155, 429, 1, 3500, 7, 'Tendris Warpwood', 16712190, 0),
  (20156, 429, 1, 4000, 4, 'Illyanna Ravenoak', 16712190, 0),
  (20157, 429, 1, 5000, 5, 'Magister Kalendris', 16712190, 0),
  (20158, 429, 1, 6000, 6, 'Immol''thar', 16712190, 0),
  (20159, 429, 1, 7000, 8, 'Prince Tortheldrin', 16712190, 0),
  (20160, 429, 1, 8000, 9, 'Guard Mol''dar', 16712190, 0),
  (20161, 429, 1, 9000, 10, 'Stomper Kreeg', 16712190, 0),
  (20162, 429, 1, 10000, 11, 'Guard Fengus', 16712190, 0),
  (20163, 429, 1, 11000, 12, 'Guard Slip''kik', 16712190, 0),
  (20164, 429, 1, 12000, 13, 'Captain Kromcrush', 16712190, 0),
  (20165, 429, 1, 13000, 14, 'Cho''Rush the Observer', 16712190, 0),
  (20166, 429, 1, 14000, 15, 'King Gordok', 16712190, 0);

-- =====================================================================
-- Verification
-- =====================================================================
-- Every Vanilla dungeon must now report all three difficulties. Expect
-- 19 maps, each with a non-zero heroic count matching its normal count:
--
--   SELECT MapID, Difficulty, COUNT(*) FROM dungeonencounter_dbc
--   WHERE Difficulty = 1 GROUP BY MapID, Difficulty ORDER BY MapID;
--
-- Row count (expect 167):
--
--   SELECT COUNT(*) FROM dungeonencounter_dbc WHERE ID BETWEEN 20000 AND 20166;
--
-- No id may collide with the shipped DBC, whose maximum is 1578
-- (expect 0):
--
--   SELECT COUNT(*) FROM dungeonencounter_dbc WHERE ID <= 1578;
--
-- After a worldserver restart the merged store should show the heroic
-- rows. The server log line to watch is the DBC load block; then in game,
-- enter a Vanilla dungeon on Heroic and the DENC block should list the
-- bosses. Gnomeregan should show 5: Grubbis, Viscous Fallout,
-- Electrocutioner 6000, Crowd Pummeler 9-60, Mekgineer Thermaplugg.
--
-- Bits must line up with difficulty 0 or a saved lockout decodes wrong.
-- This CANNOT be checked in SQL: the difficulty-0 rows live in
-- DungeonEncounter.dbc, not in this table, which holds only the overlay.
-- A self-join here matches nothing and reports every row as a mismatch -
-- do not read that as a fault. Check against the file instead:
--
--   python - <<'PY'
--   import struct
--   d=open('data/dbc/DungeonEncounter.dbc','rb').read()
--   _,rc,fc,rs,_=struct.unpack('<4siiii',d[:20])
--   rows=[struct.unpack('<%di'%fc,d[20+i*rs:20+(i+1)*rs]) for i in range(rc)]
--   for m in (33,90,230):
--       print(m,sorted((r[4],r[3]) for r in rows if r[1]==m and r[2]==0))
--   PY
--
-- then compare with:
--
--   SELECT MapID, Bit, OrderIndex FROM dungeonencounter_dbc
--   WHERE Difficulty = 1 AND ID >= 20000 AND MapID IN (33,90,230)
--   ORDER BY MapID, Bit;
--
-- Verified 2026-09-06 for map 90: Grubbis bit 2/order 2000, Viscous
-- Fallout bit 1/2500, Electrocutioner 6000 bit 3/3000, Crowd Pummeler
-- 9-60 bit 4/4000, Mekgineer Thermaplugg bit 5/5000 - identical to the
-- difficulty-0 rows in the DBC.
-- =====================================================================
