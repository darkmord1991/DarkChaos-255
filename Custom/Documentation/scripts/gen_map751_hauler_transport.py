#!/usr/bin/env python3
"""Make the map-751 Horde Haulers work as the rideable transports they are.

WHAT THEY ARE
-------------
`4144731` Horde Hauler is a free, self-driving passenger wagon running the
Silverpine road (Forsaken High Command -> The Sepulcher -> The Forsaken Front).
`4144764` Horde Coffin Hauler is its corpse-wagon counterpart running the other
way. Blizzard's own conductor dialogue is already in our `broadcast_text`
(44796 "ALL ABOARD! Next stop: The Sepulcher.", 44797 "Last stop: The Forsaken
Front!", 44788 "Final stop... EVERYBODY OUT!", 44790).

The player is a PASSENGER, not the driver: no seat on Vehicle 1048/1049 carries
`VEHICLE_SEAT_FLAG_CAN_CONTROL` (0x800).

WHY THEY ARE INERT TODAY
------------------------
`npcflag = 16777216` is **`UNIT_NPC_FLAG_SPELLCLICK`** (UnitDefines.h:346) -- NOT
PLAYER_VEHICLE, which is 0x02000000 (:347). ObjectMgr.cpp:8633-8636 strips
SPELLCLICK from any template that has the flag but no `npc_spellclick_spells` row,
and **the import brought across zero spellclick rows for the entire >=4,000,000
band** while cata_world has them. With the flag stripped there is no cursor, no
1015 opcode, and no way to board.

WHAT THIS GENERATES
-------------------
1. `npc_spellclick_spells` for both wagons. Cata uses spell **86807** "Ride Horde
   Hauler", which does not exist in this client, so we substitute **46598**
   "Ride Vehicle Hardcoded" (VehicleDefines.h:52) -- the standard 3.3.5 vehicle
   click. Safe here precisely because both entries have a real `VehicleId`:
   `HandleAuraControlVehicle` bails on `!target->IsVehicle()`
   (SpellAuraEffects.cpp), so 46598 would be a dead click on a non-vehicle.
2. `vehicle_template_accessory` -- the crew. TrinityCore's seat-2 row has
   `accessory_entry = 0` (the player's slot); ObjectMgr rejects a 0 accessory, and
   omitting it leaves seat 2 free, which is where TC seats the player anyway.
3. `vehicle_seat_addon` -- turns the shelf/bottom troopers to face outward.
4. `waypoint_data` path 447310 (63 nodes) + `creature_addon.path_id` +
   `MovementType = 2` on the one surviving spawn, so the wagon actually drives.
5. `creature_text` for the Horde Engineer so the stop announcements are audible.
6. `creature_model_info.CombatReach` 1.5 -> 4 for display 31290 (Cata's value; the
   wagon is large and 1.5 makes it awkward to click).

Everything is transposed from TrinityCore's own implementation:
  src/server/scripts/EasternKingdoms/zone_silverpine_forest.cpp  (npc_silverpine_horde_hauler)
  sql/old/9.x/world/22082_2022_11_20/2022_10_01_01_world.sql     (path + accessories)
The route needs NO coordinate transform: TC node 5 (1376.23, 828.832, 48.75095) is
byte-identical to our spawn guid 16719448, which is what proves these spawns are
sniffer captures of one moving wagon rather than five parked ones.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TC = os.environ.get(
    "TC_SQL",
    r"K:/Dark-Chaos/tc master/TrinityCore/sql/old/9.x/world/22082_2022_11_20/2022_10_01_01_world.sql")
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "Custom feature SQLs",
                                    "worlddb", "Plaguelands", "79_hauler_transport.sql"))

OFFSET = 4_100_000
HAULER, COFFIN = 4144731, 4144764
PATH_ID = 447310
KEEP_GUID = 16716000                     # route origin; the other four are captures
DROP_GUIDS = [16714741, 16715001, 16715487, 16719448]
CLICK_SPELL = 46598
ENGINEER = 4144734
# BroadcastTextIds already present in acore_world.broadcast_text
ENGINEER_TEXT = [
    (0, 44796, "ALL ABOARD! Next stop: The Sepulcher."),
    (1, 44797, "Last stop: The Forsaken Front!"),
    (2, 44788, "Final stop... EVERYBODY OUT!"),
    (3, 44790, "...you definitely don't want to be comin' back on the other wagon"),
]


def main():
    src = open(TC, encoding="utf-8", errors="replace").read()

    acc = re.findall(r"^\((44731,\s*\d+,\s*\d+,\s*\d+,.*?)\);?$", src, re.M)
    acc_rows = []
    for m in re.finditer(r"^\(44731,\s*(\d+),\s*(\d+),\s*(\d+),\s*'([^']*)',\s*(\d+),\s*(\d+)\)", src, re.M):
        a_entry, seat, minion, desc, stype, stimer = m.groups()
        if int(a_entry) == 0:
            continue                     # the player's seat -- must stay empty
        acc_rows.append((HAULER, int(a_entry) + OFFSET, int(seat), int(minion),
                         desc, int(stype), int(stimer)))
    if len(acc_rows) != 7:
        raise SystemExit("ABORT: parsed %d accessory rows, expected 7" % len(acc_rows))

    seat_addon = re.findall(r"^\((839[4-7]),\s*([\d.]+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)", src, re.M)
    if len(seat_addon) != 4:
        raise SystemExit("ABORT: parsed %d vehicle_seat_addon rows, expected 4" % len(seat_addon))

    wp = []
    for m in re.finditer(r"^\(447310,\s*(\d+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*(NULL|[-\d.]+),"
                         r"\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)", src, re.M):
        wp.append(m.groups())
    if len(wp) != 63:
        raise SystemExit("ABORT: parsed %d waypoint nodes, expected 63" % len(wp))

    w = []
    a = w.append
    a("-- 79_hauler_transport.sql -- map 751 Lordaeron extension, DB step 18.\n--")
    a("-- GENERATED by Custom/Documentation/scripts/gen_map751_hauler_transport.py --")
    a("-- do not hand-edit; re-run the generator instead.\n--")
    a("-- Makes the Horde Hauler (4144731) and Horde Coffin Hauler (4144764) work as the")
    a("-- rideable passenger wagons they are, rather than inert scenery.\n--")
    a("-- WHY THEY ARE INERT: npcflag 16777216 is UNIT_NPC_FLAG_SPELLCLICK")
    a("-- (UnitDefines.h:346), NOT PLAYER_VEHICLE (0x02000000, :347). ObjectMgr.cpp:8633-8636")
    a("-- strips SPELLCLICK from any template carrying the flag with no npc_spellclick_spells")
    a("-- row -- and the import brought across ZERO spellclick rows for the whole")
    a("-- >=4,000,000 band, while cata_world has them. Flag stripped => no cursor, no 1015")
    a("-- opcode, no boarding. That is the single blocker; everything else here is content.\n--")
    a("-- The player is a PASSENGER, not the driver: no seat of Vehicle 1048/1049 carries")
    a("-- VEHICLE_SEAT_FLAG_CAN_CONTROL (0x800).\n--")
    a("-- Transposed from TrinityCore's own implementation:")
    a("--   src/server/scripts/EasternKingdoms/zone_silverpine_forest.cpp")
    a("--   sql/old/9.x/world/22082_2022_11_20/2022_10_01_01_world.sql")
    a("-- No coordinate transform is needed: TC node 5 (1376.23, 828.832, 48.75095) is")
    a("-- byte-identical to our spawn guid 16719448.\n")

    a("-- ---------------------------------------------------------------------------")
    a("-- 1. BLOCKER: the spell-click rows, without which the flag is stripped at boot")
    a("--")
    a("-- Cata uses spell 86807 'Ride Horde Hauler', which does not exist in this client")
    a("-- (verified against the live Spell.dbc, 53,799 records). We substitute 46598")
    a("-- 'Ride Vehicle Hardcoded' (VehicleDefines.h:52). That substitution is only valid")
    a("-- because BOTH entries have a real VehicleId -- HandleAuraControlVehicle bails on")
    a("-- !target->IsVehicle(), so 46598 on a non-vehicle is a silently dead click.")
    a("-- ---------------------------------------------------------------------------")
    a("DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` IN (%d, %d);" % (HAULER, COFFIN))
    a("")
    a("INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES")
    a("(%d, %d, 1, 0),\n(%d, %d, 1, 0);\n" % (HAULER, CLICK_SPELL, COFFIN, CLICK_SPELL))

    a("-- ---------------------------------------------------------------------------")
    a("-- 2. The crew. TrinityCore's seat-2 row has accessory_entry = 0 (the player's")
    a("--    slot); ObjectMgr rejects a 0 accessory, and leaving seat 2 empty is exactly")
    a("--    where TC seats the player. Entries remapped +%d.\n" % OFFSET)
    a("--    NOTE: vehicle_template_accessory rows are only accepted for an entry that")
    a("--    already has a npc_spellclick_spells row, so section 1 must land first.")
    a("-- ---------------------------------------------------------------------------")
    a("DELETE FROM `vehicle_template_accessory` WHERE `entry` = %d;" % HAULER)
    a("")
    a("INSERT INTO `vehicle_template_accessory` (`entry`, `accessory_entry`, `seat_id`, `minion`, `description`, `summontype`, `summontimer`) VALUES")
    a(",\n".join("(%d, %d, %d, %d, '%s', %d, %d)" % r for r in acc_rows) + ";\n")

    a("-- ---------------------------------------------------------------------------")
    a("-- 3. Seat orientation for the shelf/bottom troopers (they face backwards otherwise)")
    a("-- ---------------------------------------------------------------------------")
    a("DELETE FROM `vehicle_seat_addon` WHERE `SeatEntry` IN (8394, 8395, 8396, 8397);")
    a("")
    a("INSERT INTO `vehicle_seat_addon` (`SeatEntry`, `SeatOrientation`, `ExitParamX`, `ExitParamY`, `ExitParamZ`, `ExitParamO`, `ExitParamValue`) VALUES")
    a(",\n".join("(%s, %s, %s, %s, %s, %s, %s)" % r for r in seat_addon) + ";\n")

    a("-- ---------------------------------------------------------------------------")
    a("-- 4. The route: 63 nodes, Forsaken High Command -> Sepulcher -> Forsaken Front.")
    a("--    Delays on nodes 11 / 35 / 60 are the three stops.")
    a("-- ---------------------------------------------------------------------------")
    a("DELETE FROM `waypoint_data` WHERE `id` = %d;" % PATH_ID)
    a("")
    a("INSERT INTO `waypoint_data` (`id`, `point`, `position_x`, `position_y`, `position_z`, `orientation`, `delay`, `move_type`, `action`, `action_chance`, `wpguid`) VALUES")
    a(",\n".join("(%d, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" % ((PATH_ID,) + n) for n in wp) + ";\n")

    a("-- ---------------------------------------------------------------------------")
    a("-- 5. Attach the route to the one real spawn.")
    a("--")
    a("--    MovementType 2 = WAYPOINT_MOTION_TYPE. Note the path is started by")
    a("--    Motion_Initialize (Creature.cpp:1114) BEFORE AI selection (:1116), so no AI")
    a("--    change is needed -- and do NOT set AIName='SmartAI' here, it would displace")
    a("--    VehicleAI (CreatureAISelector.cpp:63-65), which these already run.")
    a("-- ---------------------------------------------------------------------------")
    a("DELETE FROM `creature_addon` WHERE `guid` = %d;" % KEEP_GUID)
    a("")
    a("INSERT INTO `creature_addon` (`guid`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `visibilityDistanceType`, `auras`)")
    a("VALUES (%d, %d, 0, 0, 1, 0, 0, '');" % (KEEP_GUID, PATH_ID))
    a("")
    a("UPDATE `creature` SET `MovementType` = 2, `wander_distance` = 0 WHERE `guid` = %d;\n" % KEEP_GUID)

    a("-- ---------------------------------------------------------------------------")
    a("-- 6. The conductor's stop announcements. broadcast_text 44796/44797/44788/44790")
    a("--    are already present locally; creature_text is keyed by CreatureID so the")
    a("--    engineer needs his own rows.")
    a("-- ---------------------------------------------------------------------------")
    a("DELETE FROM `creature_text` WHERE `CreatureID` = %d;" % ENGINEER)
    a("")
    a("INSERT INTO `creature_text` (`CreatureID`, `GroupID`, `ID`, `Text`, `Type`, `Language`, `Probability`, `Emote`, `Duration`, `Sound`, `BroadcastTextId`, `TextRange`, `comment`) VALUES")
    a(",\n".join("(%d, %d, 0, '%s', 14, 0, 100, 0, 0, 0, %d, 0, 'Horde Engineer - hauler stop %d')"
                 % (ENGINEER, g, t.replace("'", "''"), b, g) for g, b, t in ENGINEER_TEXT) + ";\n")

    a("-- ---------------------------------------------------------------------------")
    a("-- 7. Interact radius. Cata gives display 31290 CombatReach 4; the import wrote the")
    a("--    generic 1.5, which is small for a wagon this size.")
    a("-- ---------------------------------------------------------------------------")
    a("UPDATE `creature_model_info` SET `CombatReach` = 4 WHERE `DisplayID` = 31290;\n")

    a("-- ---------------------------------------------------------------------------")
    a("-- 8. OPTIONAL / DESTRUCTIVE -- read before running.")
    a("--")
    a("-- Four of the five Horde Hauler 'spawns' are sniffer captures of the SAME moving")
    a("-- wagon, not spawn points. Proof: guid 16719448 (1376.23, 828.832, 48.7509) is")
    a("-- byte-identical to route node 5, and each of the four sits on the route facing")
    a("-- the direction of travel. Left in place you get five wagons where there should be")
    a("-- one, four of them parked and inert.")
    a("--")
    a("-- Skip this section if you would rather keep them as static scenery.")
    a("-- ---------------------------------------------------------------------------")
    a("-- DELETE FROM `creature` WHERE `guid` IN (%s);" % ", ".join(str(g) for g in DROP_GUIDS))
    a("")

    a("-- ---------------------------------------------------------------------------\n-- Verification\n-- ---------------------------------------------------------------------------")
    a("SELECT 'spellclick rows (want 2)' AS what, COUNT(*) AS n FROM `npc_spellclick_spells` WHERE `npc_entry` IN (%d, %d)" % (HAULER, COFFIN))
    a("UNION ALL SELECT 'accessory rows (want 7)', COUNT(*) FROM `vehicle_template_accessory` WHERE `entry` = %d" % HAULER)
    a("UNION ALL SELECT 'seat addon rows (want 4)', COUNT(*) FROM `vehicle_seat_addon` WHERE `SeatEntry` IN (8394,8395,8396,8397)")
    a("UNION ALL SELECT 'waypoint nodes (want 63)', COUNT(*) FROM `waypoint_data` WHERE `id` = %d" % PATH_ID)
    a("UNION ALL SELECT 'engineer texts (want 4)', COUNT(*) FROM `creature_text` WHERE `CreatureID` = %d" % ENGINEER)
    a("UNION ALL SELECT 'routed spawn (want 1)', COUNT(*) FROM `creature` c JOIN `creature_addon` a ON a.`guid` = c.`guid`")
    a("WHERE c.`guid` = %d AND c.`MovementType` = 2 AND a.`path_id` = %d;\n" % (KEEP_GUID, PATH_ID))
    a("-- must be empty: an accessory creature that does not exist")
    a("SELECT 'PROBLEM: missing accessory creature' AS problem, a.`accessory_entry`")
    a("FROM `vehicle_template_accessory` a")
    a("LEFT JOIN `creature_template` t ON t.`entry` = a.`accessory_entry`")
    a("WHERE a.`entry` = %d AND t.`entry` IS NULL;\n" % HAULER)
    a("-- must be empty: a template still carrying SPELLCLICK with no row (flag gets stripped)")
    a("SELECT 'PROBLEM: SPELLCLICK with no spellclick row' AS problem, t.`entry`, t.`name`, t.`VehicleId`")
    a("FROM `creature_template` t")
    a("WHERE t.`entry` IN (%d, %d) AND (t.`npcflag` & 16777216)" % (HAULER, COFFIN))
    a("  AND NOT EXISTS (SELECT 1 FROM `npc_spellclick_spells` s WHERE s.`npc_entry` = t.`entry`);")

    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(w) + "\n")
    print("wrote %s" % OUT)
    print("  spellclick 2, accessories %d, seat addons %d, waypoint nodes %d, texts %d"
          % (len(acc_rows), len(seat_addon), len(wp), len(ENGINEER_TEXT)))
    print("  route origin guid %d; %d capture spawns offered for deletion (commented out)"
          % (KEEP_GUID, len(DROP_GUIDS)))


main()
