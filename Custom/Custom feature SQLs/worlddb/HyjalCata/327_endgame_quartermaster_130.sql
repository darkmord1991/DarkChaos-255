-- ---------------------------------------------------------------------------
-- 327  Frontier Endgame Quartermaster -- the level-130 gear vendor
-- ---------------------------------------------------------------------------
-- 🔴 THE PROBLEM, measured. There are 615 equippable items at RequiredLevel 130
-- and only 63 can be obtained. The purpose-built set -- 400230-400707, 428
-- pieces at ilvl 412, already organised into 34 tier sets (765-780, 883-901) --
-- has exactly TWO loot entries, both on "Hyjal Doomlord" (830072), a creature
-- with **zero spawns on any map**. So the entire designed endgame set is dead.
--
-- The gear itself needed nothing: it is already RequiredLevel 130, Quality 4,
-- correctly `AllowableClass`-masked per class, and covers every slot --
-- head 40, neck 16, shoulder 43, chest 24, waist 21, legs 44, feet 18,
-- wrist 17, hands 43, finger 15, trinket 5, cloak 11, 1H 19, 2H 28, MH 13,
-- OH 16, shield 3, ranged 13, relic 9. Weapons, necks, rings and trinkets were
-- never missing. Only a SOURCE was.
--
-- ---------------------------------------------------------------------------
-- WHY A VENDOR, AND WHY THIS ONE
-- ---------------------------------------------------------------------------
-- The Mythic+ token vendor (100051, `npc_mythic_token_vendor`) already does
-- exactly this job at level 80: it queries `item_template` LIVE by class,
-- armour subclass, InventoryType and ItemLevel +-2, filters on AllowableClass
-- and role, and sells for DC Upgrade Tokens. None of that is level-80 specific.
--
-- So this ships a SECOND NPC on the SAME script rather than a second script.
-- Everything that differs between the two -- the item-level rungs, the currency
-- and the prices -- is now resolved from the vendor's creature entry, so one
-- code path serves both and neither can be changed without the other being
-- considered. Verified the live queries return real pools at 412: warrior plate
-- head 9, necks 22, rings 28, trinkets 20, cloaks 16, two-handers 41.
--
-- 🔴 REQUIRES THE C++ BUILD. Three changes, all in
-- `dc_mythicplus_token_vendor.cpp`:
--   * GetVendorTiers(), GetVendorCurrencyItemId(), GetVendorCurrencyName() and
--     GetItemCost() are new; they drive the gossip menu, the addon payload AND
--     every purchase path, so the two vendors cannot drift apart
--   * GetSessionVendorEntry() resolves the vendor from the player's UI session,
--     because the addon handlers get no Creature*. It returns 0 for a stale
--     session, which falls back to TOKENS -- a stale session can never silently
--     charge the wrong currency
--   * 🔴 the gossip dispatch ranges were WIDENED -- they were hardcoded
--     `action >= 200 && action <= 300` for tier picks and `>= 200000 &&
--     < 300000` for slot picks. The endgame rungs (412/450/510) and their slot
--     actions (412001-510014) fell straight through both and hit the purchase
--     branch. Now 600 / 600000, still clear of 1000 (info), 2000 (exchange),
--     9000 (open UI), 9999 (back) and the 5000000 purchase band.
-- Without the build this NPC spawns and greets, but every tier click misfires.
--
-- ---------------------------------------------------------------------------
-- PRICING -- Emberwood Sap, and why it looks nothing like the Mythic+ ladder
-- ---------------------------------------------------------------------------
-- 🔴 THE TWO VENDORS CHARGE DIFFERENT CURRENCIES, and the ladders are NOT
-- convertible. Never "align" them by ratio -- each is priced against its own
-- income:
--
--     tokens  ~26,700 per continent run from quests alone  ->  11-15 a piece
--     sap       2,955 per run from quests (326_), plus
--               ~0.19 per kill from drops                  -> 120-450 a piece
--
--     ilvl 412  120 sap   the 428-piece tier set
--     ilvl 450  250 sap   108 pieces
--     ilvl 510  450 sap   58 weapons, the top rung
--
-- Sap is the Frontier currency and is ALSO what T4/T5 upgrades cost (320_), so
-- gear and upgrades now compete for one purse -- which is the point. Prices are
-- set so ACQUIRING is the cheap half and IMPROVING the expensive half: a piece
-- is 120 sap, a full T5 upgrade path on that same piece is 600.
--
-- A full 16-slot ilvl-412 set is 1,920 sap, about two thirds of one continent
-- run's quest income. Cheap on purpose: this rung is the FLOOR of endgame, the
-- thing that stops a fresh 130 having nothing. 450 and 510 are where it bites.
--
-- 🔴 If sap turns out too tight in play, raise the tap in 326_ (one CASE) or
-- lower these three numbers in GetItemCost(). Do NOT move the level-80 token
-- ladder to compensate -- they are separate economies.
--
-- ---------------------------------------------------------------------------
-- PLACEMENT
-- ---------------------------------------------------------------------------
-- Molten Front (map 861, zone 4925), beside the existing sap quartermasters
-- Zen'Vorka (981.3, 375.6), Damek Bloombeard (986.7, 375.0), Ayla Shadowstorm
-- and Varlan Highbough -- so the endgame vendors stand together.
--
-- 🔴 SPAWN GUID MUST BE <= 0xFFFFFF (16,777,215). `creature.guid` is not
-- AUTO_INCREMENT-safe here so it has to be explicit -- but "explicit" is not
-- enough: ObjectMgr::GenerateCreatureSpawnId() (ObjectMgr.cpp:7667) hard-fails
-- above 0xFFFFFF, and startup seeds that counter from MAX(guid) + 1
-- (ObjectMgr.cpp:7629). A single row above the cap therefore makes the FIRST
-- runtime creature spawn abort the whole server:
--
--     Creature spawn id overflow!! Can't continue, shutting down server.
--     Search on forum for TCE00007 for more info.
--
-- The first version of this file used 16800052 -- above the cap -- and did
-- exactly that. 16751100 sits above the previous live maximum (16,751,007) and
-- well under the ceiling.
--
-- 🔴 HEADROOM IS TIGHT: only ~26,000 spawn ids remain between the live maximum
-- and the 0xFFFFFF ceiling. Large imports need a compaction pass, not a higher
-- starting guid.
--
-- Apply against acore_world. Idempotent. Needs the worldserver build + restart.
-- ---------------------------------------------------------------------------

USE `acore_world`;

-- ---------------------------------------------------------------------------
-- 1. The NPC
-- ---------------------------------------------------------------------------
-- Modelled on 100051 verbatim except level, name and display: faction 35
-- (friendly to all), npcflag 4097 = GOSSIP (1) | 4096 (questgiver-ish flag the
-- Mythic+ vendor carries), unit_class 8, type 10 (not specified), RegenHealth 1.
DELETE FROM `creature_template` WHERE `entry` = 100052;
INSERT INTO `creature_template`
  (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `npcflag`,
   `rank`, `unit_class`, `unit_flags`, `type`, `type_flags`, `AIName`,
   `MovementType`, `ScriptName`, `RegenHealth`, `flags_extra`, `exp`)
VALUES
  (100052, 'Frontier Quartermaster', 'Endgame Gear - Emberwood Sap', 130, 130, 35, 4097,
   0, 8, 0, 10, 0, '', 0, 'npc_mythic_token_vendor', 1, 0, 0);

DELETE FROM `creature_template_model` WHERE `CreatureID` = 100052;
INSERT INTO `creature_template_model`
  (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
  (100052, 0, 30259, 1, 1, 0);

-- ---------------------------------------------------------------------------
-- 2. The spawn -- Molten Front hub, beside the sap quartermasters
-- ---------------------------------------------------------------------------
DELETE FROM `creature` WHERE `id` = 100052;
DELETE FROM `creature` WHERE `guid` = 16751100;
-- Repairs the over-cap guid the first version of this file inserted.
DELETE FROM `creature` WHERE `guid` = 16800052;
INSERT INTO `creature`
  (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
   `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`,
   `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`,
   `MovementType`)
VALUES
  (16751100, 100052, 861, 4925, 0, 1, 1, 0, 992.40, 379.20, 39.10, 2.408,
   300, 0, 0, 1, 0, 0);

-- ---------------------------------------------------------------------------
-- Trailer -- verification
-- ---------------------------------------------------------------------------
-- NPC exists, level 130, scripted (expect 1 row, ScriptName set):
-- SELECT entry, name, subname, minlevel, npcflag, ScriptName
-- FROM creature_template WHERE entry = 100052;
--
-- Spawned once on Molten Front (expect 1 row, guid 16751100):
-- SELECT guid, map, zoneId, position_x, position_y, position_z
-- FROM creature WHERE id = 100052;
--
-- 🔴 NOTHING above the spawn-id ceiling (expect 0 on both, or the worldserver
-- will refuse to start):
-- SELECT COUNT(*) FROM creature WHERE guid > 16777215;
-- SELECT COUNT(*) FROM gameobject WHERE guid > 16777215;
--
-- The pools the vendor will actually show a Warrior at each rung
-- (expect non-zero on every row):
-- SELECT 412 ilvl, COUNT(*) plate_head FROM item_template
--   WHERE class = 4 AND subclass = 4 AND InventoryType = 1
--     AND ItemLevel BETWEEN 410 AND 414
--     AND (AllowableClass = 0 OR (AllowableClass & 1) != 0) AND Quality >= 3
-- UNION ALL SELECT 450, COUNT(*) FROM item_template
--   WHERE class = 4 AND subclass = 4 AND InventoryType = 1
--     AND ItemLevel BETWEEN 448 AND 452
--     AND (AllowableClass = 0 OR (AllowableClass & 1) != 0) AND Quality >= 3
-- UNION ALL SELECT 510, COUNT(*) FROM item_template
--   WHERE class = 2 AND ItemLevel BETWEEN 508 AND 512 AND Quality >= 3;
--
-- In-game, after the build + restart:
--   * talk to the Frontier Quartermaster -- header should read
--     "Frontier Endgame Quartermaster", with rungs 412 (120) / 450 (250) /
--     510 (450) SAP rather than the 200-252 token ladder;
--   * the balance line should read "Your Emberwood Sap:", not "Your Tokens:";
--   * pick 412 -> a slot -> confirm a real item list, and that buying deducts
--     SAP while the Upgrade Token count is untouched;
--   * the Token <-> Essence exchange entry should be ABSENT here (a Mythic+
--     concept; sap has no essence conversion);
--   * 🔴 talk to the Mythic+ vendor (100051) and confirm it STILL shows
--     200/213/226/239/252 at 11-15 TOKENS and still offers the exchange --
--     that is the regression this shares a script with.
-- ---------------------------------------------------------------------------
