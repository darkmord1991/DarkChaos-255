-- =====================================================================================
-- Server-side AreaTrigger DEFINITIONS for the custom instance portals.
--
-- >>> THIS IS THE FILE THAT MAKES THE PORTALS ACTUALLY FIRE. <<<
--
-- THE BUG THIS FIXES, because it is not obvious and it cost several rounds of chasing:
--
-- The worldserver does NOT read AreaTrigger.dbc. It never has. `ObjectMgr::LoadAreaTriggers()`
-- (ObjectMgr.cpp:7256) runs exactly this query:
--
--     SELECT entry, map, x, y, z, radius, length, width, height, orientation FROM areatrigger
--
-- and that is the only thing that fills `_areaTriggerStore`. So a custom trigger needs
-- **THREE** rows, not two, and missing the third fails completely silently:
--
--   1. AreaTrigger.dbc          -> teaches the CLIENT where the box is, so it sends
--                                  CMSG_AREATRIGGER when the player walks in.
--   2. `areatrigger`            -> teaches the SERVER the same box. THIS TABLE.
--   3. `areatrigger_teleport`   -> says where the trigger sends you.
--
-- With 1 and 3 present but 2 missing, the client dutifully sends the packet and
-- `WorldSession::HandleAreaTriggerOpcode` (MiscHandler.cpp:706) does:
--
--     AreaTrigger const* atEntry = sObjectMgr->GetAreaTrigger(triggerId);
--     if (!atEntry) { LOG_DEBUG(...); return; }
--
-- ...a LOG_DEBUG and a bare return. No error, no message to the player, nothing in the
-- default log level. You walk into the portal and absolutely nothing happens -- which is
-- exactly the symptom that was reported for Blackfathom.
--
-- Before this file, `areatrigger` held 1259 rows (stock, including 257 = real BFD on map 48)
-- and ZERO rows at entry >= 607000, while `areatrigger_teleport` had five rows with no
-- matching definition -- these five. So none of the custom portals could ever have fired.
--
-- That also retracts an earlier claim in the Timbermaw and Blackfathom READMEs that trigger
-- 607002 "was verified firing in game". It cannot have been: it has no definition row either.
-- Timbermaw enters and exits correctly through the gatekeeper/warden GOSSIP NPCs, which is a
-- completely separate code path, and that is what was actually being observed.
--
-- The values below are generated FIELD-FOR-FIELD from the deployed AreaTrigger.dbc, so the
-- client's idea of each box and the server's are identical by construction. The DBC column
-- order maps 1:1 onto this table:
--     ID -> entry, ContinentID -> map, X/Y/Z -> x/y/z, Radius -> radius,
--     Box_Length -> length, Box_Width -> width, Box_Height -> height, Box_Yaw -> orientation
-- If you ever move a box, change the CSV, recompile, redeploy, and regenerate this file from
-- the DBC -- do not hand-edit one side.
--
-- 607003 (Timbermaw exit) is deliberately absent: `dungeon_entrance_npcs.sql` section 6 drops
-- its `areatrigger_teleport` row because the box sits on the old below-the-floor arrival
-- estimate, so a definition here would do nothing.
--
-- Re-runnable.
-- =====================================================================================

DELETE FROM `areatrigger` WHERE `entry` IN (607002, 607004, 607005, 607006, 607007);
INSERT INTO `areatrigger`
    (`entry`, `map`, `x`, `y`, `z`, `radius`, `length`, `width`, `height`, `orientation`) VALUES
    -- Timbermaw Hold entrance, map 750 furbolg camp -> map 819
    (607002, 750, 7015, -2145, 587, 0, 8, 8, 10, 0),
    -- Blackfathom Deeps entrance, map 750 Zoram Strand cave mouth -> map 820. Position
    -- measured in game; the old one came off stock trigger 257, i.e. map 1's VANILLA terrain.
    (607004, 750, 4250.270508, 748.806213, -23.281, 0, 8, 8, 10, 0),
    -- Blackfathom Deeps exit, inside map 820 -> map 750. 61.5 yd from the arrival point, so
    -- arriving does not land you in the exit box and bounce you straight back out.
    (607005, 820, -176.863907, 51.559681, -49.635101, 0, 8, 8, 10, 0),
    -- Crescent Grove entrance, map 750 -> map 823
    (607006, 750, 1689.800049, -1272.199951, 175.550003, 0, 8, 8, 10, 0),
    -- Emerald Sanctum entrance, map 750 -> map 824
    (607007, 750, 4833.100098, -1756.699951, 1190.27002, 0, 8, 8, 10, 0);

-- -------------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------------
SELECT 'definitions added (want 5)' AS `check`, CAST(COUNT(*) AS CHAR) AS result
    FROM `areatrigger` WHERE `entry` IN (607002, 607004, 607005, 607006, 607007)
UNION ALL SELECT 'teleports with NO definition (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger_teleport` t LEFT JOIN `areatrigger` a ON a.`entry` = t.`ID`
    WHERE a.`entry` IS NULL
UNION ALL SELECT 'definitions on a map missing from instance_template/Map (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` a WHERE a.`entry` >= 607000 AND a.`map` NOT IN (750, 819, 820, 823, 824)
-- A box whose own map equals its teleport target map sends the player back onto the map
-- they are already standing on -- the shape a self-teleport loop takes. None of ours do.
UNION ALL SELECT 'same-map teleports (want 0)', CAST(COUNT(*) AS CHAR)
    FROM `areatrigger` a JOIN `areatrigger_teleport` t ON t.`ID` = a.`entry`
    WHERE a.`entry` >= 607000 AND a.`map` = t.`target_map`;
