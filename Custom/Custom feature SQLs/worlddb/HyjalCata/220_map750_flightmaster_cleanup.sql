-- ---------------------------------------------------------------------------
-- 195  Map 750 -- three flight-master defects the POI audit surfaced
-- ---------------------------------------------------------------------------
-- Found by matching every map-750 flight master against TaxiNodes.dbc: 26 of 29
-- sit within 8 yards of the node they serve, and these three do not. Each one
-- is also visible in game as a wrong or duplicated flight-master marker,
-- because the MPOI layer (dc_addon_mappois.cpp) reports whatever the spawn
-- tables say -- and each one makes the server log
--     MapPOI (MPOI): N of 29 flight markers matched no TaxiNodes.dbc entry
-- at startup.
--
-- Deliberately NOT a template cleanup: 7308610 and 3650367 keep their
-- creature_template rows. Only spawns/flags change, which is reversible.
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- 1. Kroum 7308610 -- duplicate spawn on the RETIRED Valormok flight point
-- ---------------------------------------------------------------------------
-- gen_taxi.py retired node 338 in round 43 ("Cata removed the flight point --
-- Bilgewater replaced it") and its header records "Kroum despawned by 177_".
-- That despawn caught entry 3608610 but not its +3,700,000 clone: guid
-- 15810001 is still standing at (3664, -4390), which is exactly where node 338
-- used to be. Node 338 is gone from TaxiNodes.dbc, so this is a flight master
-- at a flight point that no longer exists.
--
-- 7308610 is a pure clone of 3608610 -- same name, subname, faction, npcflag,
-- ScriptName, AIName, and byte-identical smart_scripts (3 rows, "On Aggro -
-- Summon Creature 'Enraged Wyvern'"). Both are spawned; the Kroum players
-- should use are 3608610 at Bilgewater (node 365, 3.8 yds) and 3636728 at the
-- new Valormok (node 366, 3.2 yds). This third one is the leftover.
--
-- Verified to have NO dependants: no creature_addon, game_event_creature,
-- pool_creature, linked_respawn, creature_formations, waypoint_data,
-- queststarter/questender, gossip_menu, vendor, trainer, conditions or loot.
-- The smart_scripts rows are entry-scoped and simply stop firing with nothing
-- spawned; they are left in place so the template stays whole.
DELETE FROM `creature` WHERE `guid` = 15810001 AND `id` = 7308610;


-- ---------------------------------------------------------------------------
-- 2. Friz Groundspin 3650367 -- NOT despawned; it ends a quest
-- ---------------------------------------------------------------------------
-- gen_taxi.py notes that "only 3637005 (2650,-6212) is the real one", and the
-- measurement agrees: 3637005 is 3.3 yds from node 364 (Southern Rocketway)
-- while 3650367 at (2664, -6169) is 45 yds from it and matches no node at all.
-- Both carry the FLIGHTMASTER npcflag, so map 750 shows two Friz Groundspin
-- flight pins 45 yds apart -- too far for MPOI's 25-yard duplicate collapse.
--
-- BUT 3650367 must NOT be despawned: it is the ONLY questender for
--     28849  "Twilight Skies"  (level 84, RewardNextQuest 26388)
-- started by Captain Krazz (3642640). Removing the spawn would strand that
-- quest and the chain behind it.
--
-- So drop only the FLIGHTMASTER bit and keep the NPC. npcflag 8194 becomes 2
-- (QUESTGIVER): the quest still works, and the NPC stops claiming to be a
-- flight master it has no node for. Written as a bitmask clear so re-running
-- is a no-op and any other flags stay untouched.
UPDATE `creature_template` SET `npcflag` = `npcflag` & ~8192 WHERE `entry` = 3650367;


-- ---------------------------------------------------------------------------
-- 3. Mishellena 7312578 -- 79 yards adrift of her own flight point
-- ---------------------------------------------------------------------------
-- Node 343 "Talonbranch Glade, Felwood" sits at (6205.88, -1949.63, 571.29)
-- and was the ONLY map-750 taxi node with no flight master. Mishellena is at
-- (6215.3, -1871.17, 566.08) -- 79.2 yds away, just outside the 60-yard window
-- dc_addon_mappois.cpp uses to bind a flight master to its node, so she gets
-- no discovery gating and the node reads as abandoned.
--
-- Her predecessor spawn (entry 3612578, now unspawned) stood at approximately
-- (6204, -1951, 572), i.e. right on the node -- so the +3,700,000 re-clone is
-- what displaced her. Her current spot is also off on its own: the nearest
-- other NPC is a Talonbranch Guardian 25 yds away and everything else is 42+
-- yds, whereas the node is in the middle of the settlement (Willard Harrington
-- 13 yds, Nalesette Wildbringer 16 yds, Denmother Ulrica the innkeeper 50 yds).
--
-- Moved onto the node itself. Orientation faces the settlement centre rather
-- than keeping the old 4.24 rad, which pointed away into open ground after the
-- move; it is cosmetic, so adjust to taste.
UPDATE `creature`
SET `position_x` = 6205.88,
    `position_y` = -1949.63,
    `position_z` = 571.29,
    `orientation` = 1.85254
WHERE `guid` = 15810002 AND `id` = 7312578;
