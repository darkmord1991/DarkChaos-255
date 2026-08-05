-- =============================================================================
-- DC Rare Spawn Timers - map 750 (Cata Kalimdor downport) and map 37 (Azshara Crater)
-- =============================================================================
-- Problem: the clone/downport imports wrote spawntimesecs = 300 as their default,
-- so 30 of 54 rare spawn points on map 750 and 41 of 42 on map 37 respawn in five
-- minutes. A rare that is back in five minutes is not rare, and it makes the
-- respawn announcer (RareSpawn.Announce.*) unusable - it would fire ~500 times an
-- hour on map 37 alone.
--
-- Policy applied here, per NPC (not per spawn point):
--   target = MAX(highest authored timer for that NPC, rank floor)
--   floors: map 750  rank 2 (rare elite) 21600s / 6h   rank 4 (rare) 14400s / 4h
--           map  37  rank 2 (rare elite)  7200s / 2h   rank 4 (rare)  3600s / 1h
--
-- Rank values are the core's CreatureEliteType (src/server/shared/SharedDefines.h):
-- 2 = CREATURE_ELITE_RAREELITE, 4 = CREATURE_ELITE_RARE. Rare elite gets the
-- longer floor because it is the tougher, higher-reward tier.
--
-- Authored Cata timers (43200 / 72000 / 86400 / 136800 / 19900) are preserved -
-- they came from the source data and are above every floor. Only the import
-- defaults and the sub-floor values move.
--
-- Every spawn point of a multi-point rare gets the SAME timer, because
-- 2026_08_05_01_dc_rare_spawn_pools.sql puts those points into a max_limit = 1
-- pool and the pool re-roll is driven by the despawning member's spawntimesecs.
-- Mixed timers inside one pool would make the rotation cadence random.
--
-- NOT touched: creature 800009 "Hervikus the Chaotic" (guid 3112386, map 37,
-- spawntimesecs = 10). Custom DC NPC, its 10s timer looks deliberate. It is
-- excluded from the announcer by the MinRespawnSecs gate anyway.
--
-- No spawn point is deleted. Duplicate spawn points of the same rare are handled
-- by pooling, not by removal.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Map 750 - rank 2 (rare elite), floor 21600 / 6h
-- -----------------------------------------------------------------------------

-- Scalebeard (3613896, Azshara) - import default, no authored timer to preserve.
UPDATE `creature` SET `spawntimesecs` = 21600 WHERE `guid` = 16465236;

-- Garr (3650056, Hyjal Frontier) - second spawn point matched to the authored 24h.
UPDATE `creature` SET `spawntimesecs` = 86400 WHERE `guid` = 15501214;

-- General Colbatann (3710196, Winterspring) - second spawn point matched to 12h.
UPDATE `creature` SET `spawntimesecs` = 43200 WHERE `guid` = 16376689;

-- Unchanged (already at or above the floor): 12202216 Garr 86400,
-- 15802286 Dessecus 43200, 15800802 Immolatus 43200, 15802279 Colbatann 43200,
-- 15600046 Kashoch the Reaver 43200, 15802278 Azurous 43200.

-- -----------------------------------------------------------------------------
-- Map 750 - rank 4 (rare), floor 14400 / 4h
-- -----------------------------------------------------------------------------

-- Thartuk the Exile (3650053) and Terrorpene (3650058): second spawn point
-- matched to the authored 20h.
UPDATE `creature` SET `spawntimesecs` = 72000 WHERE `guid` IN (15501205, 15501216);

-- Everything else at the 4h floor. Includes the sub-floor authored values
-- (Blazewing 3600, Ban'thalos 7200, Lord Sinslayer 7200, Lady Vespira 9900,
-- Rak'shiri 9900, Alshirr Banebreath 9900, Ragepaw 9900, The Ongar 9900), which
-- are raised, and the 300s import defaults.
UPDATE `creature` SET `spawntimesecs` = 14400 WHERE `guid` IN (
    -- Azshara (4930)
    16466490,  -- Varo'then's Ghost   (3606118)
    16466100,  -- Antilos             (3606648)
    16465164,  -- Lady Sesspira       (3606649)
    16466318,  -- General Fangferror  (3606650)
    16000131,  -- Gatekeeper Rageroar (3606651)
    16000198,  -- The Evalcharr       (3608660)
    -- Ashenvale (4931)
    16462618,  -- Akkrilus            (3603773)
    16464302,  -- Branch Snapper      (3610641)
    16464170,  -- Ursol'lok           (3612037)
    16368953,  -- Terrowulf Packlord  (3703792)
    16371242,  -- Lady Vespia         (3710559)
    16371241,  -- Rorgish Jowl        (3710639)
    16371239,  -- Mist Howler         (3710644)
    -- Hyjal Frontier (4923)
    12250898,  -- Blazewing           (3650057)  was 3600
    15501215,  -- Blazewing           (3650057)  was  300
    12250976,  -- Ankha               (3654318)  was  300
    15501255,  -- Ankha               (3654318)  was  300
    12194904,  -- Ban'thalos          (3654320)  was 7200
    15501256,  -- Ban'thalos          (3654320)  was  300
    -- Darkshore (4929)
    15860416,  -- Strider Clutchmother    (3702172)
    15860415,  -- Shadowclaw              (3702175)
    15860414,  -- Lady Moongazer          (3702184)
    15860413,  -- Carnivous the Breaker   (3702186)
    15860412,  -- Firecaller Radison      (3702192)
    15862299,  -- Flagglemurk the Cruel   (3707015)
    15802287,  -- Lady Vespira            (3707016)  was 9900
    15862300,  -- Lady Vespira            (3707016)  was  300
    15800275,  -- Lord Sinslayer          (3707017)  was 7200
    15862301,  -- Lord Sinslayer          (3707017)  was  300
    -- Winterspring (4926)
    15802280,  -- Rak'shiri           (3710200)  was 9900
    -- Felwood (4927)
    15802282,  -- Alshirr Banebreath  (3714340)  was 9900
    15802281,  -- Ragepaw             (3714342)  was 9900
    15802284   -- The Ongar           (3714345)  was 9900
);

-- Unchanged (already at or above the floor): 12193475 Thartuk 72000,
-- 12193834 Terrorpene 72000, 15802019 Mezzir the Howler 19900,
-- 15802020 Grizzle Snowpaw 19900, 15700092 + 15801066 Death Howl 86400,
-- 15802285 + 15802685 + 15802686 Olm the Wise 86400, 15802283 Mongress 136800.

-- -----------------------------------------------------------------------------
-- Map 37 (Azshara Crater) - rank 2 (rare elite), 7200 / 2h
-- -----------------------------------------------------------------------------

UPDATE `creature` SET `spawntimesecs` = 7200 WHERE `guid` IN (
    3112044,  -- Scarlet Interrogator   (1838)
    3112071,  -- Scarlet High Clerist   (1839)
    9001204,  -- Monnos the Elder       (6646)
    9000764,  -- Pyromancer Loregrain   (9024)
    9000877,  -- Spirestone Lord Magus  (9217)
    9000879,  -- Spirestone Butcher     (9219)
    9000858,  -- Bannok Grimaxe         (9596)
    9000870,  -- Ghok Bashguud          (9718)
    9001110,  -- Volchan                (10119)
    9001011,  -- Scalebeard             (13896)
    3112046,  -- Setis                  (14471)
    3112070,  -- Lord Hel'nurath        (14506)
    9001041,  -- Lord Hel'nurath        (14506)  second spawn point
    9001316,  -- Nuramoc                (20932)
    9001296,  -- Old Crystalbark        (32357)
    9001345,  -- Aotona                 (32481)
    9001318,  -- King Krush             (32485)
    9001313,  -- Loque'nahak            (32517)
    9001354,  -- Gondria                (33776)
    9001331,  -- Skoll                  (35189)
    9001336   -- Arcturis               (38453)
);

-- -----------------------------------------------------------------------------
-- Map 37 (Azshara Crater) - rank 4 (rare), 3600 / 1h
-- -----------------------------------------------------------------------------

UPDATE `creature` SET `spawntimesecs` = 3600 WHERE `guid` IN (
    9000580,  -- Mother Fang               (471)
    9000928,  -- Fenros                    (507)
    9000555,  -- Timber                    (1132)
    9000627,  -- Great Father Arctikus     (1260)
    9000947,  -- Molok the Crusher         (2604)
    9000932,  -- Prince Nazjak             (2779)
    9000588,  -- Mazzranache               (3068)
    9000638,  -- Snort the Heckler         (5829)
    9000994,  -- Varo'then's Ghost         (6118)
    9000963,  -- Gatekeeper Rageroar       (6651)
    9000933,  -- Razortalon                (8210)
    9000763,  -- Faulty War Golem          (8279)
    9001013,  -- The Evalcharr             (8660)
    9000669,  -- Mist Howler               (10644)
    9000975,  -- Ragepaw                   (14342)
    9001284,  -- Marticar                  (18680)
    9001228,  -- Voidhunter Yar            (18683)
    9001252,  -- Doomsayer Jurim           (18686)
    9001253,  -- Speaker Mar'grom          (18693)
    9001230   -- Collidus the Warp-Watcher (18694)
);

-- =============================================================================
-- Verification
-- =============================================================================
-- Expected after apply: no rare/rare-elite spawn point on either map below its
-- floor, except Hervikus the Chaotic.
--
-- SELECT c.map, ct.rank, MIN(c.spawntimesecs), MAX(c.spawntimesecs), COUNT(*)
-- FROM creature c JOIN creature_template ct ON ct.entry = c.id
-- WHERE c.map IN (750, 37) AND ct.rank IN (2, 4) AND c.id <> 800009
-- GROUP BY c.map, ct.rank;
--
-- map 750 rank 2 -> min 21600  max  86400  (9 rows)
-- map 750 rank 4 -> min 14400  max 136800  (45 rows)
-- map  37 rank 2 -> min  7200  max   7200  (21 rows)
-- map  37 rank 4 -> min  3600  max   3600  (20 rows)
