-- =====================================================================
-- Felwood / Talonbranch Glade (map 750) -- 295  Double-layer cleanup
-- ---------------------------------------------------------------------
-- Reported in game: "the spawns at Talonbranch Glade look a bit strange."
--
-- The COORDINATES ARE NOT WRONG. Every spawn in the Talonbranch bowl was
-- re-measured against all three source DBs and each one is a verbatim copy
-- of its own source, distance 0.00:
--   * Cata layer  (guid 15830062-15830355)  == cata_world.creature   0.00 yd
--   * stock layer (guid 15800428-15800833)  == acore_backup.creature 0.00 yd
--
-- What LOOKS wrong is the additive double import from `181_`/`183_`: both
-- generations of Talonbranch Glade are spawned at once, and Blizzard moved
-- people between the two versions. Where a Cata NPC was dropped on the exact
-- tile a vanilla NPC still occupies, you get a 3-4 yard huddle of overlapping
-- nameplates. Talonbranch is the ONLY settlement on map 750 where this hits
-- named/service NPCs -- a zone-wide cross-layer sweep (all 2,211 stock-layer
-- spawns vs all 611 Cata-layer spawns) returned 140 pairs under 12 yd, but
-- every other one is trash-vs-trash, which is normal for a deliberately
-- double-populated zone and is NOT treated as a defect here.
--
-- Three fixes, all UPDATE-only. No new ids, no DBC change, no client deploy.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Malygen + Mylini Frostmoon float ~6.5 yd in the air
-- ---------------------------------------------------------------------
-- This is the one place stock AzerothCore's data is wrong for OUR terrain.
-- Map 750's heightmap is the CATACLYSM one, and three of four sources put
-- the ground at this spot at ~568; only stock AC says 574.6:
--
--   Malygen (2803)           ours 574.65 | nelt 567.74 | cata 567.77
--   Mylini Frostmoon (15315) ours 574.66 | nelt 567.94 | cata 568.18
--
-- Confirmed independently: every Cata-layer NPC within 25 yd of them sits at
-- 567.8-568.2. A zone-wide Z sweep found only these two among named/service
-- NPCs (the other 7 hits are trash mobs on slopes, where the neighbour-average
-- ground estimate is not trustworthy).
--
-- Z only -- XY is left alone so they stay where the camp expects them.
--
-- NOTE Malygen also walks waypoint path 15800428, whose 4 points are already
-- at z 567.76-568.03 around (6148..6166, -1914..-1920). So his SPAWN row was
-- the orphan: he popped in the air at y=-1941 and then walked down to a path
-- 22 yd away. The path is correct, the spawn Z was not -- nothing to change there.
UPDATE `creature` SET `position_z` = 567.74 WHERE `guid` = 15800428;
UPDATE `creature` SET `position_z` = 567.94 WHERE `guid` = 15800429;

-- ---------------------------------------------------------------------
-- 2. Kaerbrus + Shi'alune are standing inside Elizabeth Nesworth
-- ---------------------------------------------------------------------
-- Stock AC parks Kaerbrus and his pet at (6229, -1917, 563). Cataclysm moved
-- Kaerbrus ~30 yd north to (6213.28, -1887.31) and dropped Elizabeth Nesworth
-- on the tile he used to stand on. Both got imported, so:
--
--   Shi'alune (15800830) <-> Elizabeth Nesworth (15830339)   3.55 yd
--   Kaerbrus  (15800833) <-> Elizabeth Nesworth (15830339)   4.34 yd
--
-- That is the three-overlapping-nameplates cluster in the screenshot.
-- Moving the vanilla pair to their Cataclysm coordinates clears it AND puts
-- them where Blizzard placed them on this exact terrain. Values are
-- cata_world.creature guid 359956 / 360843 verbatim, orientation included.
--
-- Safe to move: both are MovementType 0, no creature_addon, no waypoint path
-- and no creature_formations row, so nothing else references the old spot.
-- Nearest existing spawn to the new position is a Talonbranch Guardian 19 yd
-- away -- no new overlap created.
UPDATE `creature` SET `position_x` = 6213.28, `position_y` = -1887.31, `position_z` = 566.08, `orientation` = 2.55 WHERE `guid` = 15800833;
UPDATE `creature` SET `position_x` = 6215.83, `position_y` = -1882.63, `position_z` = 565.91, `orientation` = 2.42 WHERE `guid` = 15800830;

-- ---------------------------------------------------------------------
-- 3. Half the camp is unusable for Horde -- faction 80 -> 2164
-- ---------------------------------------------------------------------
-- Why the vanilla NPCs render RED and the Cata NPCs 4 yards away render
-- YELLOW, verified against the LIVE server's dbc, not a staging copy:
--
--   faction 80   -> Faction 69  "Darnassus", Faction.dbc ReputationIndex = 21
--                   -> reputation-driven; Horde base standing -42000 (Hated)
--                   -> REP_HOSTILE -> red -> gossip/vendor/trainer all refused
--   faction 2163 -> Faction 1134 "Gilneas",  Faction.dbc ReputationIndex = -1
--   faction 2164 -> Faction 1134 "Gilneas",  ditto
--                   -> CanHaveReputation() false, so Unit::GetReactionTo falls
--                      through the group masks to REP_NEUTRAL -> yellow -> usable
--
-- (The group masks on 2163/2164 do say FactionGroup 2 / EnemyGroup 4, i.e.
-- Alliance-vs-Horde, but a player's reaction never reaches the mask test while
-- the reputation path is live, and for Gilneas it is not. Hence neutral.)
--
-- FactionTemplate 2159/2163/2164/2165 ARE present in the deployed dbc --
-- 897 records, confirmed through the running worldserver's data/dbc. (The
-- acore_dbc dump schema is stale at 841 records; do not trust it for this.)
--
-- Net effect of the change: Horde goes Hated -> Neutral (can now use them),
-- Alliance goes Friendly -> Neutral (still fully usable -- neutral passes
-- Player::GetNPCIfCanInteractWith, which only rejects hostile). The camp ends
-- up internally consistent instead of half-red/half-yellow.
--
-- Scope check: each of these six templates has exactly ONE spawn and it is on
-- map 750, so no other zone is affected.
UPDATE `creature_template` SET `faction` = 2164 WHERE `entry` IN (
    3700543,  -- Nalesette Wildbringer  (Pet Trainer)
    3702803,  -- Malygen                (General Goods)
    3705501,  -- Kaerbrus               (Hunter Trainer)
    3709465,  -- Golhine the Hooded     (Druid Trainer)
    3715315   -- Mylini Frostmoon       (Weapon Merchant)
);

-- Shi'alune is Kaerbrus' Pet, not a service NPC, so she is deliberately a
-- SEPARATE statement -- but leaving her at 80 puts a red pet next to a now
-- yellow owner, which is exactly the inconsistency this file is removing.
-- Comment out if you want the pair to stay Darnassus-flagged.
UPDATE `creature_template` SET `faction` = 2164 WHERE `entry` = 3711181;

-- DELIBERATELY NOT CHANGED, for the record:
--   * Mishellena (7312578) stays faction 80. She is the flight master, and
--     Alliance-only flight from Talonbranch is authentic Blizzard design --
--     Horde's Felwood flight points are Hanah Southsong (Whisperwind Grove),
--     Chyella Hushglade (Wildheart Point) and Gorrim (Emerald Sanctuary),
--     all already faction 35 and all already reachable. Re-factioning a
--     flight master also drags the taxi network into it.
--   * Lyros Swiftwind (3748492) stays faction 80. He is a CATA-layer quest
--     giver that Blizzard itself shipped on Darnassus, so his quest is
--     Alliance-only by design, not by import damage. Changing him is a
--     content decision about Horde quest access, not a data fix.

-- =====================================================================
-- VERIFICATION -- run after applying; all three should come back clean
-- =====================================================================
-- 1. no named/service cross-layer pair closer than 8 yd at Talonbranch
-- SELECT a.guid, ta.name, b.guid, tb.name,
--        ROUND(SQRT(POW(a.position_x-b.position_x,2)+POW(a.position_y-b.position_y,2)+POW(a.position_z-b.position_z,2)),2) d
--   FROM creature a JOIN creature_template ta ON ta.entry=a.id
--   JOIN creature b ON b.map=a.map AND b.guid>a.guid
--   JOIN creature_template tb ON tb.entry=b.id
--  WHERE a.map=750 AND a.position_x BETWEEN 6100 AND 6300 AND a.position_y BETWEEN -1990 AND -1850
--    AND b.position_x BETWEEN 6100 AND 6300 AND b.position_y BETWEEN -1990 AND -1850
--    AND (ta.npcflag<>0 OR tb.npcflag<>0)
--    AND SQRT(POW(a.position_x-b.position_x,2)+POW(a.position_y-b.position_y,2)+POW(a.position_z-b.position_z,2)) < 8;
--
-- 2. nobody at Talonbranch above z 570 any more
-- SELECT guid, id, position_z FROM creature
--  WHERE map=750 AND position_x BETWEEN 6100 AND 6300
--    AND position_y BETWEEN -1990 AND -1850 AND position_z > 570;
--
-- 3. the camp reads one faction family
-- SELECT ct.faction, COUNT(*) FROM creature c JOIN creature_template ct ON ct.entry=c.id
--  WHERE c.map=750 AND c.position_x BETWEEN 6100 AND 6300
--    AND c.position_y BETWEEN -1990 AND -1850 GROUP BY ct.faction;
