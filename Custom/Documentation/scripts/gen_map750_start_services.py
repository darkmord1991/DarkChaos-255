#!/usr/bin/env python3
"""Generate `Custom/Level Areas/Cata Hyjal 80-130/41_start_services.sql`.

Service rings (class + profession trainers, stock entries) for the classic
faction start hubs on map 750, plus Emberwood Sap quartermaster singles at the
band hubs. Same ring math and placement rules as gen_hyjal_camps.py:

* Anchor on a coordinate whose `.gps` reports GroundZ == FloorZ; short of an
  in-game reading, ground-placed native SERVICE NPCS are the only trustworthy
  z reference (never arbitrary creatures).  Both centres below are anchored on
  such NPCs and are flagged PROVISIONAL in the SQL until verified in-game.
* Keep rings tight; re-run this script after editing CAMPS, never hand-edit
  the SQL.

Stock trainer entries carry their `creature_default_trainer` links, so a bare
spawn delivers the full training window -- no extra SQL.
"""

import io
import math
import os

# --------------------------------------------------------------------------------------
# Camp definitions.
# --------------------------------------------------------------------------------------
CAMPS = [
    dict(
        name="Lor'danel services",
        # Anchor: Teldira Moonfeather (flight master, ground-placed) 7462.24, -326.55, 8.21.
        # PROVISIONAL until an in-game .gps confirms GroundZ == FloorZ.
        cx=7462.24, cy=-326.55, cz=8.21,
        zone=4929,
        guid0=9020050,
        inner_radius=10.0,     # (unused -- class trainers dropped, see header)
        outer_radius=13.0,     # professions + secondaries
        inner=[],
        outer=[
            (5499,    "Lilyssia Nightbreeze, Alchemy Trainer"),
            (1317,    "Lucan Cordell, Enchanting Trainer"),
            (17222,   "Artificer Daelo, Engineering Trainer"),
            (5566,    "Tannysa, Herbalism Trainer"),
            (30713,   "Catarina Stanford, Inscription Trainer"),
            (3500574, "Timothy Jones, Jewelcrafting Trainer"),
            (5564,    "Simon Tanner, Leatherworking Trainer"),
            (1292,    "Maris Granger, Skinning Trainer"),
            (1346,    "Georgio Bolero, Tailoring Trainer"),
            (5482,    "Stephen Ryback, Cooking Trainer"),
            (2327,    "Shaina Fuller, First Aid Trainer"),
            (5493,    "Arnold Leland, Fishing Trainer"),
            (4732,    "Randal Hunter, Riding Trainer"),
        ],
    ),
    dict(
        name="Bilgewater Harbor services",
        # Anchor: Kroum (Wind Rider, ground-placed) 3548.18, -6291.23, 0.84 -- the dock
        # plaza. PROVISIONAL until an in-game .gps confirms GroundZ == FloorZ (Bilgewater
        # is a WMO island; the deck around the anchor is flat but MUST be verified).
        cx=3548.18, cy=-6291.23, cz=0.84,
        zone=4930,
        guid0=9020200,
        inner_radius=10.0,
        outer_radius=13.0,
        inner=[],
        outer=[
            (3347,    "Yelmak, Alchemy Trainer"),
            (3355,    "Saru Steelfury, Blacksmithing Trainer"),
            (11074,   "Hgarth, Enchanting Trainer"),
            (11017,   "Roxxik, Engineering Trainer"),
            (8146,    "Ruw, Herbalism Trainer"),
            (30709,   "Poshken Hardbinder, Inscription Trainer"),
            (3500574, "Timothy Jones, Jewelcrafting Trainer"),
            (3365,    "Karolek, Leatherworking Trainer"),
            (3357,    "Makaru, Mining Trainer"),
            (7088,    "Thuwd, Skinning Trainer"),
            (3363,    "Magar, Tailoring Trainer"),
            (3026,    "Aska Mistrunner, Cooking Trainer"),
            (5943,    "Rawrk, First Aid Trainer"),
            (3332,    "Lumak, Fishing Trainer"),
            (4752,    "Kildar, Riding Trainer"),
        ],
    ),
]

# Emberwood Sap quartermaster singles, one per band hub. 830024 is the original
# (faction 12, Alliance) -- fine at the Alliance start; the neutral clone 830163
# (faction 35, created by the SQL header below) serves everywhere else.
SINGLES = [
    # (guid, entry, zone, x, y, z, o, comment) -- anchored on the hub innkeeper.
    (9020074, 830024, 4929, 7426.50, -281.50,   7.74, 3.10, "Lor'danel - Emberwood Sap Quartermaster (next to Innkeeper Kyteran)"),
    (9020224, 830163, 4930, 3532.50, -6516.50, 43.59, 3.28, "Bilgewater Harbor - Emberwood Sap Quartermaster (next to Innkeeper Mixi)"),
    (9020240, 830163, 4926, 6698.50, -4676.50, 721.65, 0.54, "Everlook - Emberwood Sap Quartermaster (next to Innkeeper Vizzie)"),
    (9020241, 830163, 4923, 5516.50, -3611.00, 1570.13, 1.12, "Nordrassil - Emberwood Sap Quartermaster (next to Sebelia)"),
]

HEADER = """-- ---------------------------------------------------------------------------
-- 41  Start-hub services: profession trainers at Lor'danel + Bilgewater
--     Harbor, token quartermasters at all band hubs
-- ---------------------------------------------------------------------------
-- CLASS trainers are deliberately ABSENT: the server's learn-spells scripts
-- auto-teach class abilities, so only PROFESSION/secondary trainers (whose
-- recipes and skill ranks are not auto-learned) are placed. Stock capital
-- trainer NPCs carry their creature_default_trainer links, so a bare spawn
-- delivers the full training window. Alliance roster at Lor'danel, Horde at
-- Bilgewater Harbor; Timothy Jones (faction 35) covers Jewelcrafting on both.
--
-- Emberwood Sap quartermasters: the original 830024 is faction 12, hostile to
-- Horde -- so a NEUTRAL clone 830163 (faction 35, same vendor stock) serves
-- Bilgewater, Everlook and Nordrassil.
--
-- OPTIONAL FILE -- this is Option A of PLACEMENT_GUIDE.md section 5. If you
-- place the trainers by hand instead, SKIP this file (or delete guids
-- 9020050-9020241) or you get duplicates. Blacksmithing and Mining are absent
-- from the Lor'danel ring on purpose: Taryel Firestrike and Periale already
-- train them natively there.
--
-- Generated by Custom/Documentation/scripts/gen_map750_start_services.py --
-- edit the CAMPS/SINGLES tables there and re-run rather than hand-editing.
-- Centres are PROVISIONAL service-NPC anchors: verify GroundZ == FloorZ
-- in-game, correct the script, re-run, re-apply.
--
-- GUIDs 9020050-9020241 inside the reserved 9020000-9020499 block; template
-- 830163 (was free, highest used 830162). Run AFTER 10_faction_bases.sql
-- (whose DELETE is scoped to 9020000-9020047). Idempotent.
-- ---------------------------------------------------------------------------

-- 1. Neutral Emberwood Sap quartermaster template (clone of 830024, faction 35).
DELETE FROM `creature_template` WHERE `entry` = 830163;
DROP TEMPORARY TABLE IF EXISTS `tmp_dc750_qm`;
CREATE TEMPORARY TABLE `tmp_dc750_qm` AS
SELECT * FROM `creature_template` WHERE `entry` = 830024;
UPDATE `tmp_dc750_qm` SET `entry` = 830163, `faction` = 35;
INSERT INTO `creature_template` SELECT * FROM `tmp_dc750_qm`;
DROP TEMPORARY TABLE `tmp_dc750_qm`;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 830163;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT 830163, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model` WHERE `CreatureID` = 830024;

DELETE FROM `npc_vendor` WHERE `entry` = 830163;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`)
SELECT 830163, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`
FROM `npc_vendor` WHERE `entry` = 830024;

-- 2. The spawns.
DELETE FROM `creature` WHERE `guid` BETWEEN 9020050 AND 9020241;
INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
    `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`, `spawntimesecs`,
    `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`, `MovementType`, `npcflag`,
    `unit_flags`, `dynamicflags`, `ScriptName`, `VerifiedBuild`, `CreateObject`, `Comment`) VALUES
"""


def build_rows():
    rows = []
    for camp in CAMPS:
        guid = camp["guid0"]
        for radius, npcs in ((camp["inner_radius"], camp["inner"]),
                             (camp["outer_radius"], camp["outer"])):
            count = len(npcs)
            for index, (entry, label) in enumerate(npcs):
                angle = 2 * math.pi * index / count
                rows.append((
                    guid, entry, camp["zone"],
                    camp["cx"] + radius * math.cos(angle),
                    camp["cy"] + radius * math.sin(angle),
                    camp["cz"],
                    (angle + math.pi) % (2 * math.pi),      # face the centre
                    f"{camp['name']} - {label}",
                ))
                guid += 1
    for guid, entry, zone, x, y, z, o, comment in SINGLES:
        rows.append((guid, entry, zone, x, y, z, o, comment))
    return rows


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", ".."))
    out = os.path.join(repo, "Level Areas", "Cata Hyjal 80-130", "41_start_services.sql")

    rows = build_rows()
    values = ",\n".join(
        "({}, {}, 750, {}, {}, 1, 1, 0, {:.3f}, {:.3f}, {:.3f}, {:.3f}, 300, 0, 0, 0, 0, 0, "
        "0, 0, 0, '', NULL, 0, '{}')".format(g, e, z, z, x, y, cz, o, c.replace("'", "''"))
        for g, e, z, x, y, cz, o, c in rows
    )

    trailer = (
        "\n-- ---------------------------------------------------------------------------\n"
        "-- Trailer -- verification\n"
        "-- ---------------------------------------------------------------------------\n"
        "-- SELECT COUNT(*) FROM creature WHERE guid BETWEEN 9020050 AND 9020241;  -- "
        + str(len(rows)) + "\n"
        "-- SELECT entry, faction FROM creature_template WHERE entry = 830163;    -- 35\n"
        "-- SELECT COUNT(*) FROM npc_vendor WHERE entry = 830163;  -- same as 830024\n"
        "-- In-game: open every trainer window at both hubs, buy from all 4 QMs.\n"
    )

    body = HEADER + values + ";\n" + trailer
    io.open(out, "w", encoding="utf-8", newline="\n").write(body)
    print(f"wrote {out} ({len(rows)} spawns)")


if __name__ == "__main__":
    main()
