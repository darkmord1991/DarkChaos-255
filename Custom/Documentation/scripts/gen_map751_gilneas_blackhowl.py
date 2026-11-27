#!/usr/bin/env python3
"""Generate 113_gilneas_city_blackhowl_751.sql from the harvested nelt phase-32768 spawn list."""
import os

SRC = "k:/tmp/blackhowl_spawns.txt"
OUT = ("K:/Dark-Chaos/DarkChaos-255-Master/Custom/Custom feature SQLs/worlddb/"
       "Plaguelands/113_gilneas_city_blackhowl_751.sql")
OFFSET = 4_100_000
GUID0 = 5_000_000
ZONE = 4939

# entry -> (name, subname, minlevel, maxlevel, faction, rank, unit_class, type, type_flags,
#           lootid, HealthModifier, ManaModifier, DamageModifier, displays[(id,scale)], equip)
T = {
    57802: dict(name="Lord Hiram Creed", subname="Warlord of the Blackhowl",
                lo=138, hi=138, faction=14, rank=1, uclass=2, ctype=7, tflags=8,
                hp=24.0, mana=2.0, dmg=1.0,
                models=[(35618, 1.75)], equip=(77193, 0, 0)),
    57805: dict(name="Blackhowl Footsoldier", subname="",
                lo=135, hi=136, faction=16, rank=1, uclass=1, ctype=7, tflags=0,
                hp=3.25, mana=1.0, dmg=1.0,
                models=[(34078, 1), (34079, 1), (34080, 1), (34081, 1)],
                equip=(31541, 57452, 0)),
    57806: dict(name="Blackhowl Packmaster", subname="",
                lo=136, hi=136, faction=16, rank=1, uclass=1, ctype=7, tflags=0,
                hp=4.25, mana=1.0, dmg=1.0,
                models=[(36072, 1), (36074, 1)], equip=None),
    57810: dict(name="Blackhowl Sniper", subname="",
                lo=135, hi=136, faction=16, rank=1, uclass=1, ctype=7, tflags=0,
                hp=3.25, mana=1.0, dmg=1.0,
                models=[(34321, 1), (34322, 1)], equip=(0, 0, 55325)),
    57861: dict(name="Blackhowl Bloodhound", subname="",
                lo=134, hi=135, faction=16, rank=0, uclass=1, ctype=1, tflags=0,
                hp=1.25, mana=1.0, dmg=1.0,
                models=[(30211, 1), (30213, 1)], equip=None),
}

HEADER = """\
-- 113_gilneas_city_blackhowl_751.sql -- populate Gilneas City (area 16789) on map 751.
--
-- THE SYMPTOM
--   Ruins of Gilneas reads as an empty zone. Measured against the ADT area map (MCNK
--   areaid at tag +0x34) rather than the DB -- `creature.areaId` is populated on map
--   751 but always equals the ZONE, never a subzone, so it cannot answer this:
--
--   Chunks below are LAND only. A chunk counts as water when MH2O gives it a liquid
--   layer AND its terrain is at or under sea level -- height alone is not enough, The
--   Blackwald's floor sits at a median of -22.9 with no liquid at all and is walkable
--   (our heightmap is byte-identical to Cata's Azeroth ADTs, so that depth is Blizzard's).
--
--     subzone                     land chunks   spawns   chunks occupied
--     Northern Headlands                  281      305             43%
--     Forsaken Forward Command             56       66             54%
--     Gilneas City                        225        9            0.9%   <-- the capital
--     The Blackwald                       181        0               0%
--     Stormglen / Hayward / Bite / Mine     70        0               0%
--     zone body (untagged)              1,513      110            1.2%
--
--   Zone-wide 192 of 2,539 land chunks hold a creature -- 7.6%, against 15.0-31.1% for
--   the other seven map-751 zones. Per-km2 density is 192, which is MID-PACK (Arathi
--   182, Hinterlands 227, EPL 336, Tirisfal 494): the defect is DISTRIBUTION, not
--   headcount. All 541 spawns sit in the northern third.
--
-- WHY -- NOT AN IMPORT BUG
--   The import matched its source exactly: cata_world's unphased map-0 Gilneas box has
--   748 creatures, we have 750. On retail almost everything in this zone lives in
--   QUEST PHASES driven from Silverpine, and cata_world carries none of them. The
--   unphased base layer really is just the Forsaken beachhead in the north.
--
-- WHAT THIS FILE DOES
--   nelt_world DOES have the phase layers. Its phase 32768 is the Blackhowl worgen
--   mercenary garrison, 283 spawns and effectively all of them inside Gilneas City.
--   That layer is flattened into phase 1 here. Our Gilneas is single-phase by design
--   (all 750 existing spawns are phaseMask 1) and Gilneas City is empty, so nothing
--   stacks: every position lands in the X -1867..-1367 / Y 1167..1767 box, which is
--   Gilneas City's own bounding box, and holds 9 spawns today.
--
--   Templates come from cata_world (57770-57861), NOT from nelt -- nelt's map-0 Gilneas
--   also carries LEAKED map-654 starting-zone spawns (Orc Raiders, Duskhaven Watchmen,
--   Queen Mia Greymane; present on both map 0 and 654 there, on 654 only in cata_world).
--   Only the five Blackhowl entries are taken, matched by entry id, and only their
--   phase-32768 rows.
--
-- DELIBERATE DEVIATIONS FROM SOURCE, each one a judgement call:
--   * Zazzo Twinklefingers (57770) is DROPPED. He is a lone npcflag=2 questgiver and we
--     have none of his quests -- a gossip cursor over an NPC with nothing to say.
--   * Levels 85 -> the Gilneas band. Source level 85 is far outside the zone's Blizzard
--     range (13-14), so a linear re-map is meaningless; they take the band's existing
--     elite tiers instead: 135-136 (rank 1), 136 (packmaster), 138 (Creed, the zone's
--     top elite tier), 134-135 for the beast.
--   * DISPLAYS ARE SUBSTITUTES. Cata points these at CreatureDisplayInfo 39799-39823,
--     which are ExtendedDisplayInfo character-NPC displays and are ABSENT from our
--     deployed CreatureDisplayInfo.dbc; this fork bakes such NPCs into 500xxx
--     MONSTER-slot models instead (see 33950 -> model 500962). Rather than block the
--     spawn work on an art downport, each entry reuses a worgen display already
--     deployed AND already backed by a creature_model_info row:
--       Footsoldier -> 34078/34079/34080/34081 (Worgen Renegade, 2 male + 2 female --
--                      matches Cata's own 2 male + 2 female split)
--       Sniper      -> 34321/34322 (Bloodfang Stalker)
--       Packmaster  -> 36072/36074 (Bloodfang Sentry)
--       Bloodhound  -> 30211/30213  <-- EXACT, these are Cata's own ids and we have them
--       Creed       -> 35618 at DisplayScale 1.75 (Cata scale preserved)
--     Repointing these at properly downported displays later is a one-table change.
--   * type_flags 0x80000008 -> 0x8 on Creed. The high bit is a Cata-only flag.
--   * creature_template.type on Creed: source says 2 (Dragonkin) for a worgen warlord,
--     which would make him Track Dragonkin bait. Set to 7 (Humanoid).
--   * MovementType 2 (waypoint) -> 1 with wander_distance 3 on the 46 rows that carry
--     it. We are not importing waypoint_data, and type 2 with no path logs an error and
--     leaves the mob standing. Same treatment as 102_wander_restore_751.
--   * spawntimesecs 300 -> 120, matching every other spawn in this zone.
--
-- STATS. HealthModifier/ManaModifier/DamageModifier are the cata source values, which
-- are pre-band numbers. `zoneId`/`areaId` are set to 4939 on every row on purpose, so
-- 106_band_rescale_751.sql picks these five entries up -- RE-RUN 106 AFTER THIS FILE or
-- they stay off the band curve.
--
-- LOOT. Source lootid is 0 on all five, so they drop nothing. An optional block at the
-- end wires them to existing Gilneas loot tables; it is commented out -- uncomment if
-- you want them to drop.
--
-- IDEMPOTENT. Every INSERT is preceded by its matching DELETE, keyed on an explicit
-- five-entry IN list and on the guid block -- never a BETWEEN over entry ids. guids 5000000-5000282 were verified free across creature,
-- creature_addon, creature_formations and game_event_creature (0 rows in 5000000-5000400).
-- Entries 4157802-4157861 sit above the map-751 import band (which ends at 4155808).
"""


def main():
    rows = []
    for ln in open(SRC):
        p = ln.split()
        if not p:
            continue
        rows.append((int(p[0]), float(p[1]), float(p[2]), float(p[3]), float(p[4]),
                     int(p[5]), float(p[6]), int(p[7])))
    assert len(rows) == 283, len(rows)

    out = [HEADER, ""]
    entries = sorted(T)
    lo_e, hi_e = OFFSET + entries[0], OFFSET + entries[-1]
    ent_list = ", ".join(str(OFFSET + e) for e in entries)

    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- 1. creature_template")
    out.append("-- ---------------------------------------------------------------------------")
    out.append("DELETE FROM `creature_template` WHERE `entry` IN (%s);" % ent_list)
    out.append("INSERT INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`,")
    out.append("  `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `detection_range`, `rank`,")
    out.append("  `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `unit_class`, `unit_flags2`,")
    out.append("  `type`, `type_flags`, `lootid`, `AIName`, `MovementType`, `HoverHeight`,")
    out.append("  `HealthModifier`, `ManaModifier`, `ArmorModifier`, `RegenHealth`, `VerifiedBuild`) VALUES")
    vals = []
    for e in entries:
        t = T[e]
        sub = t["subname"].replace("'", "''")
        vals.append("(%d, '%s', '%s', %d, %d, 0, %d, 0, 1, 1.14286, 20, %d, %s, 2000, 2000, %d, 2048, "
                    "%d, %d, 0, '', 0, 1, %s, %s, 1, 1, 15595)"
                    % (OFFSET + e, t["name"].replace("'", "''"), sub, t["lo"], t["hi"], t["faction"],
                       t["rank"], t["dmg"], t["uclass"], t["ctype"], t["tflags"], t["hp"], t["mana"]))
    out.append(",\n".join(vals) + ";")
    out.append("")

    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- 2. creature_template_model -- substitute displays, see header")
    out.append("-- ---------------------------------------------------------------------------")
    out.append("DELETE FROM `creature_template_model` WHERE `CreatureID` IN (%s);" % ent_list)
    out.append("INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`,")
    out.append("  `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES")
    vals = []
    for e in entries:
        for idx, (d, sc) in enumerate(T[e]["models"]):
            vals.append("(%d, %d, %d, %s, 1, 0)" % (OFFSET + e, idx, d, sc))
    out.append(",\n".join(vals) + ";")
    out.append("")

    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- 3. creature_equip_template -- all four item displays verified present in the")
    out.append("--    live ItemDisplayInfo.dbc (25640, 65711, 79915, 677469)")
    out.append("-- ---------------------------------------------------------------------------")
    out.append("DELETE FROM `creature_equip_template` WHERE `CreatureID` IN (%s);" % ent_list)
    out.append("INSERT INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`,")
    out.append("  `ItemID3`, `VerifiedBuild`) VALUES")
    vals = []
    for e in entries:
        eq = T[e]["equip"]
        if eq:
            vals.append("(%d, 1, %d, %d, %d, 15595)" % (OFFSET + e, eq[0], eq[1], eq[2]))
    out.append(",\n".join(vals) + ";")
    out.append("")

    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- 4. spawns -- 283 rows, guids %d-%d" % (GUID0, GUID0 + len(rows) - 1))
    out.append("-- ---------------------------------------------------------------------------")
    out.append("DELETE FROM `creature` WHERE `guid` BETWEEN %d AND %d;" % (GUID0, GUID0 + len(rows) - 1))
    out.append("DELETE FROM `creature` WHERE `id` IN (%s);" % ent_list)
    out.append("INSERT INTO `creature` (`guid`, `id`, `map`, `zoneId`, `areaId`, `spawnMask`,")
    out.append("  `phaseMask`, `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`,")
    out.append("  `spawntimesecs`, `wander_distance`, `curhealth`, `curmana`, `MovementType`,")
    out.append("  `VerifiedBuild`) VALUES")
    vals = []
    for i, (eid, x, y, z, o, _st, _wd, mt) in enumerate(rows):
        if mt == 2:
            mt, wd = 1, 3
        else:
            wd = 0
        vals.append("(%d, %d, 751, %d, %d, 1, 1, 0, %s, %s, %s, %s, 120, %d, 0, 0, %d, 15595)"
                    % (GUID0 + i, OFFSET + eid, ZONE, ZONE, x, y, z, o, wd, mt))
    out.append(",\n".join(vals) + ";")
    out.append("")

    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- 5. OPTIONAL -- give them loot. Source lootid is 0 on all five, so as shipped")
    out.append("--    283 elites drop nothing. These point at Gilneas tables that already exist.")
    out.append("--    Uncomment to enable.")
    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- UPDATE `creature_template` SET `lootid` = 4145375 WHERE `entry` IN (4157805, 4157806, 4157810);")
    out.append("-- UPDATE `creature_template` SET `lootid` = 4145367 WHERE `entry` = 4157861;")
    out.append("")
    out.append("-- ---------------------------------------------------------------------------")
    out.append("-- 6. AFTER APPLYING: re-run 106_band_rescale_751.sql so these five entries get")
    out.append("--    band-derived HP/mana/damage instead of their raw Cata modifiers.")
    out.append("-- ---------------------------------------------------------------------------")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("wrote %s (%d spawn rows, %d templates)" % (OUT, len(rows), len(entries)))


if __name__ == "__main__":
    main()
