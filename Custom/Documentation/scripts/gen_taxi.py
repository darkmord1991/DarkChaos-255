#!/usr/bin/env python3
"""Build the DC Hyjal (750) + Plaguelands (751) taxi network from REAL Cata
4.3.4 flight-path data.

Both DC maps are coordinate-preserving copies of the retail continents (Hyjal =
continent 1, Plaguelands = continent 0), verified: every flight master matches a
Cata taxi node within ~2-7 yds. So we lift Blizzard's authored TaxiPathNode
waypoints verbatim (they follow the real terrain), only remapping ContinentID
(1->750, 0->751) and node/path ids into our ranges.

For node pairs Blizzard connected directly we use that path's waypoints. For
pairs without a direct path we concatenate the cheapest chain of direct Cata
segments through our own nodes (Dijkstra on Cata fare), so every pair still flies
a real Blizzard route without leaving the zone.

Source DBCs: extracted from K:/Cata/Data/enUS/locale-enUS.MPQ (build 15595),
placed in ./cata_dbc next to this script.

Map 751 also carries three Alliance-only CUSTOM nodes (400-402, 2026-11-12) with
no Cata flight point under them: see CUSTOM_NODES, ALLIANCE_ONLY, FORCED_PAIRS,
LEADIN and FORCED_VIA. Their rows and paths are appended AFTER every existing
one, so adding them changed no existing TaxiNodes / TaxiPath / TaxiPathNode row.
"""
import csv, io, json, hashlib, math, os, struct, heapq
from collections import defaultdict

REPO = "k:/Dark-Chaos/DarkChaos-255-Master"
# DC_TAXI_CSV_DIR points the run at a COPY of the three CSVs (dry run + diff)
# instead of rewriting Custom/CSV DBC in place.
BASE = os.environ.get("DC_TAXI_CSV_DIR") or REPO + "/Custom/CSV DBC"
CATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cata_dbc")

NODES_CSV = os.path.join(BASE, "TaxiNodes.csv")
PATH_CSV  = os.path.join(BASE, "TaxiPath.csv")
PNODE_CSV = os.path.join(BASE, "TaxiPathNode.csv")

NODE_IDS   = (set(range(421, 438)) | {338, 339, 343, 344, 345, 446, 447} | {346, 347, 349}
              | {350, 351} | {354, 355, 356, 360, 361, 362, 363, 364, 365, 366, 367}
              # --- map-751 Lordaeron extension (2026-08-19), 19 new points ------
              | {368, 369, 370, 371, 372, 373, 374, 378, 385, 386, 387,
                 388, 389, 390, 391, 396, 397, 398, 399}
              # --- map-751 Alliance route (2026-11-12): CUSTOM_NODES below ---
              | {400, 401, 402})
# 338 stays in NODE_IDS so regeneration PURGES its stale rows; it is no longer in NODEMAP.
PATH_BASE  = 9500
PNODE_BASE = 48000
MASK = "16712190"
HIPPO, GRYPHON, BAT = 3837, 541, 3574
# Map 750's own taxi mount: the Legion Val'sharah Hippogryph (display 502052),
# instead of HIPPO's plain vanilla Creature\Hippogryph\Hippogryph.mdx. The
# template is created by
#   Custom/Custom feature SQLs/worlddb/HyjalCata/194_hyjal_taxi_mount.sql
# and deliberately lives outside the Collection mount pipeline's ID range so
# that regenerating mounts cannot renumber the flight network's mount away.
HYJAL_HIPPO = 800200
CONT_REMAP = {1: 750, 0: 751}

# Maps that ship ADJACENCY instead of a full mesh.
#
# A full mesh gives every ordered pair its own TaxiPath, so the client always has
# a one-segment route and the flight map draws a single straight line to every
# destination -- no intermediate stops, which is what made map 750's flight map
# look unlike Blizzard's. Blizzard ships adjacency: 806 paths for 330 nodes (0.7%
# of a mesh, mean out-degree 3.2) and lets the CLIENT chain them, which is what
# produces the multi-leg route and the stations you pass through.
#
# Safe on the server: AzerothCore does not need a path per pair for this. The
# client sends the whole chain and PlayerTaxi::ActivateTaxiPathTo walks
# CONSECUTIVE pairs (PlayerTaxi.cpp ~173, `GetTaxiPath(dest[i-1], dest[i])`),
# summing each hop -- every consecutive pair IS a real edge, so it resolves.
#
# 751 joined this in Plaguelands/85_, which cleared `npc_dc_downport_flightmaster`
# from its 32 flight masters so they use the native taxi frame like 750's. While
# they were on the gossip flight master (dc_downport_taxi.cpp) 751 HAD to be a full
# mesh: that script asks for ONE direct path current->destination and silently drops
# every non-adjacent entry from its list. Map 750 made the same move in
# HyjalCata/221_.
#
# The note in synth_arc about "every ordered pair needs its own path" is about that
# gossip path, not about the native one -- do not read it as a reason to go back to
# a mesh.
ADJACENCY_ONLY_MAPS = {750, 751}

# Cata gives both Andorhal flight points the same name (they are the phased
# Alliance/Forsaken pair). Disambiguate for the shared gossip list.
NAME_OVERRIDE = {
    434: "Andorhal (Forsaken), Western Plaguelands",
    435: "Andorhal (Alliance), Western Plaguelands",
}

CATA, STOCK, CUSTOM = "cata", "stock", "custom"

# The seven border-zone points come from the STOCK 3.3.5 tables, not Cata, and
# the distinction matters.  Map 750's eastern third is stock WotLK Kalimdor
# terrain (Everlook, Moonglade, Felwood, Azshara), so the stock routes are the
# ones that actually follow the ground under them.  Azshara proves the point:
# Cata node 44 is 'Bilgewater Harbor' at (3547, -6295) after the revamp, while
# the Valormok flight master standing on our terrain is at (3662, -4390) --
# lifting the Cata route would fly players 1,900 yards into open water.
#
# All seven matched a stock node within 8 yards of the live flight master.
#
# our_id, our_map, source, source_node_id, mount_horde, mount_alliance
NODEMAP = [
    (421, 750, CATA, 558, HYJAL_HIPPO, HYJAL_HIPPO),
    (422, 750, CATA, 781, HYJAL_HIPPO, HYJAL_HIPPO),
    (423, 750, CATA, 557, HYJAL_HIPPO, HYJAL_HIPPO),
    (424, 750, CATA, 559, HYJAL_HIPPO, HYJAL_HIPPO),
    (425, 750, CATA, 616, HYJAL_HIPPO, HYJAL_HIPPO),
    # --- border zones, added round 37 -------------------------------------
    # (338 Valormok RETIRED, round 43: Cata removed the flight point -- Bilgewater
    #  replaced it, off-map -- and 176_/177_ made the corner fully Cata content;
    #  Kroum despawned by 177_. Kept in NODE_IDS so a regen purges stale rows.)
    (339, 750, STOCK, 166, HYJAL_HIPPO, HYJAL_HIPPO),   # Emerald Sanctuary        (Gorrim)
    (343, 750, STOCK,  65, HYJAL_HIPPO, HYJAL_HIPPO),   # Talonbranch Glade    (Mishellena)
    (344, 750, STOCK,  52, HYJAL_HIPPO, HYJAL_HIPPO),   # Everlook             (Maethrya)
    (345, 750, STOCK,  53, HYJAL_HIPPO, HYJAL_HIPPO),   # Everlook               (Yugrek)
    (446, 750, STOCK,  49, HYJAL_HIPPO, HYJAL_HIPPO),   # Moonglade            (Sindrayl)
    (447, 750, STOCK,  69, HYJAL_HIPPO, HYJAL_HIPPO),   # Moonglade            (Faustron)
    # --- Cataclysm-only Felwood points, added with the Cata creature layer ---
    # These two have no STOCK counterpart: Cata replaced Bloodvenom Post (stock
    # node 48, "[DISABLED in 4.x]") with Whisperwind Grove and added Irontree
    # Clearing. So unlike the border zones above they must come from CATA.
    # That is safe here even though the eastern terrain is stock: Felwood's
    # heightmap barely moved between WotLK and Cata (unlike Azshara, which is
    # why 338 uses STOCK), and both nodes matched the live flight master --
    # 594 is 1.0 yd from Hanah, 597 is 4.9 yd from Dirzak.
    # Node ids must stay <= 448 (TaxiMaskSize = 14 uint32 = 448 bits, see
    # DBCStructure.h); 438-445 are stock nodes, so 346/347 were taken instead.
    (346, 750, CATA, 594, HYJAL_HIPPO, HYJAL_HIPPO),    # Whisperwind Grove (Hanah Southsong)
    (347, 750, CATA, 597, HYJAL_HIPPO, HYJAL_HIPPO),    # Irontree Clearing (Dirzak Pryocrank)
    (349, 750, CATA, 595, HYJAL_HIPPO, HYJAL_HIPPO),    # Wildheart Point  (Chyella Hushglade)
    # NOTE the full Cata Felwood network is these FIVE points -- 65 Talonbranch,
    # 166 Emerald Sanctuary, 594 Whisperwind Grove, 595 Wildheart Point and
    # 597 Irontree Clearing. Cata node 48 "Bloodvenom Post" is NOT one of them:
    # it is flagged "[DISABLED in 4.x]" in TaxiNodes.dbc, i.e. Blizzard retired
    # that flight point in the revamp. Do not re-add it -- a player standing at
    # Bloodvenom Post is meant to have no flight master; Wildheart Point (~700
    # yds away) is its replacement.
    # --- Darkshore, added with the Cata Darkshore layer (HyjalCata/184_) -----
    # CATA, not STOCK, and the measurement is unambiguous. Blizzard REUSED node
    # id 26 in the revamp: stock 26 is "Auberdine", cata 26 is "Lor'danel", and
    # they are 1,428 yards apart because Auberdine was destroyed. Our flight
    # masters were imported from cata_world at cata coordinates, so:
    #     Teldira Moonfeather -> cata 26  = 2.3 yd   (stock 26 = 1,427.7 yd)
    #     Delanea             -> cata 339 = 2.0 yd   (no stock node exists --
    #                                     Grove of the Ancients only got a
    #                                     flight point in Cataclysm)
    # Taking STOCK here would drop players in the ruins of Auberdine. This is
    # the mirror image of the Azshara call above, where STOCK was right.
    (350, 750, CATA,  26, HYJAL_HIPPO, HYJAL_HIPPO),    # Lor'danel        (Teldira Moonfeather)
    (351, 750, CATA, 339, HYJAL_HIPPO, HYJAL_HIPPO),    # Grove of the Ancients   (Delanea)
    # --- Ashenvale + Azshara, added round 45 with the 279-tile expansion -------
    # These zones only became whole with the terrain expansion; 178_ imported
    # their flight masters, and every one matched a CATA node within 6 yds.
    # CATA, not STOCK: both zones were revamped, and the stock nodes sit on
    # pre-Cata ground here (that is exactly why node 338 was retired).
    # Two traps resolved by measurement, not by taking the nearest hit:
    #   Vhulgra -> 61 "Splintertree Post" (5.8 yds).  The two NEARER hits are
    #     both dead: 344 "Quest - Splintertree Post -> Zoramgar" (2.8 yds) is a
    #     quest path node, and 343 "Splintertree" (4.6 yds) has out-degree 0 --
    #     no route touches it.  61 has 9 in / 9 out.  Pick by CONNECTIVITY, not
    #     by distance, or the router falls back to synthesised arcs.
    #   Friz Groundspin has two spawns; only 3637005 (2650,-6212) is the real
    #     rocketway (3.3 yds). Spawn 3650367 is 48 yds off and is a duplicate.
    #   Andruk -> 58 "Zoram'gar Outpost" (4.1 yds, 8 in / 8 out).  Nearer again
    #     are two dead ends: 349 "Andruk, Zoram'gar" (1.9 yds, in-degree 0) and
    #     345 "Quest - Zoramgar" (1.9 yds, out-degree 0).  Cata keeps per-NPC and
    #     per-quest TaxiNodes rows next to the real flight point -- ALWAYS check
    #     in/out degree in TaxiPath before binding one.
    (354, 750, CATA,  28, HYJAL_HIPPO, HYJAL_HIPPO),   # Astranaar          (Daelyshia)
    (355, 750, CATA, 351, HYJAL_HIPPO, HYJAL_HIPPO),   # Stardust Spire     (Myre Moonglide)
    (356, 750, CATA, 167, HYJAL_HIPPO, HYJAL_HIPPO),   # Forest Song        (Suralais Farwind)
    (360, 750, CATA, 350, HYJAL_HIPPO, HYJAL_HIPPO),   # Hellscream's Watch (Thraka)
    (361, 750, CATA,  61, HYJAL_HIPPO, HYJAL_HIPPO),   # Splintertree Post  (Vhulgra)
    (362, 750, CATA, 356, HYJAL_HIPPO, HYJAL_HIPPO),   # Silverwind Refuge  (Wind Tamer Shoshok)
    (363, 750, CATA, 614, HYJAL_HIPPO, HYJAL_HIPPO),   # Northern Rocketway (Blitz Blastospazz)
    (364, 750, CATA, 613, HYJAL_HIPPO, HYJAL_HIPPO),   # Southern Rocketway (Friz Groundspin)
    (365, 750, CATA,  44, HYJAL_HIPPO, HYJAL_HIPPO),   # Bilgewater Harbour (Kroum)
    (366, 750, CATA, 683, HYJAL_HIPPO, HYJAL_HIPPO),   # Valormok           (Kroum, inland)
    (367, 750, CATA,  58, HYJAL_HIPPO, HYJAL_HIPPO),   # Zoram'gar Outpost  (Andruk)
    (426, 751, CATA,  66, BAT, GRYPHON),
    (427, 751, CATA,  68, BAT, GRYPHON),
    (428, 751, CATA, 315, BAT, GRYPHON),
    (429, 751, CATA, 383, BAT, GRYPHON),
    (430, 751, CATA,  86, BAT, GRYPHON),
    (431, 751, CATA, 630, BAT, GRYPHON),
    (432, 751, CATA,  87, BAT, GRYPHON),
    (433, 751, CATA,  84, BAT, GRYPHON),
    (434, 751, CATA, 649, BAT, GRYPHON),
    (435, 751, CATA, 650, BAT, GRYPHON),
    (436, 751, CATA, 651, BAT, GRYPHON),
    (437, 751, CATA, 672, BAT, GRYPHON),
    # --- Lordaeron extension, added 2026-08-19 with the 7 new zones -----------
    # Every one of these matched its live flight master within 0.6-6.7 yd, which
    # re-confirms the coordinate-preserving premise for the whole eastern block.
    # Ids come from the free pool under the 448 TaxiMaskSize ceiling; 338 is
    # deliberately NOT reused (it stays in NODE_IDS only so a regen purges the
    # retired Valormok rows). 20 free ids remain after this.
    # BAT/GRYPHON in BOTH slots, as above — one mount in both slots would hide the
    # node from the other faction.
    (368, 751, CATA, 460, BAT, GRYPHON),   # Brill, Tirisfal                 (Anette Williams)
    (369, 751, CATA,  11, BAT, GRYPHON),   # Undercity                       (Michael Garrett)
    (370, 751, CATA, 384, BAT, GRYPHON),   # The Bulwark, Tirisfal        (Timothy Cunningham)
    (371, 751, CATA, 681, BAT, GRYPHON),   # Forsaken Rear Guard, Silverpine   (Franny Mertz)
    (372, 751, CATA,  10, BAT, GRYPHON),   # The Sepulcher, Silverpine          (Karos Razok)
    (373, 751, CATA, 654, BAT, GRYPHON),   # The Forsaken Front, Silverpine  (Steven Stutzka)
    (374, 751, CATA, 667, BAT, GRYPHON),   # Ruins of Southshore, Hillsbrad     (Darla Harris)
    (378, 751, CATA, 669, BAT, GRYPHON),   # Eastpoint Tower, Hillsbrad    (Darren Longfellow)
    (385, 751, CATA, 668, BAT, GRYPHON),   # Southpoint Gate, Hillsbrad      (Pamela Stutzka)
    (386, 751, CATA, 670, BAT, GRYPHON),   # Strahnbrad, Alterac            (Phillip Harding)
    (387, 751, CATA,  13, BAT, GRYPHON),   # Tarren Mill, Hillsbrad                   (Zarise)
    (388, 751, CATA, 618, BAT, GRYPHON),   # Stormfeather Outpost, Hinterlands (Brock Rockbeard)
    (389, 751, CATA,  76, BAT, GRYPHON),   # Revantusk Village, Hinterlands           (Gorkas)
    (390, 751, CATA,  43, BAT, GRYPHON),   # Aerie Peak, Hinterlands     (Guthrum Thunderfist)
    (391, 751, CATA, 617, BAT, GRYPHON),   # Hiri'watha, Hinterlands             (Kellen Kuhn)
    (396, 751, CATA,  16, BAT, GRYPHON),   # Refuge Pointe, Arathi               (Cedrik Prose)
    (397, 751, CATA, 601, BAT, GRYPHON),   # Galen's Fall, Arathi                (Rhoda Bowers)
    (398, 751, CATA,  17, BAT, GRYPHON),   # Hammerfall, Arathi                          (Urda)
    (399, 751, CATA, 646, BAT, GRYPHON),   # Forsaken Forward Command, Gilneas (Bat Handler Doomair)
    # --- map-751 Alliance route, phase 1 (2026-11-12) ----------------------------
    # Three Alliance flight masters where Cata has no flight point, so the row comes
    # from CUSTOM_NODES (explicit position + name) and the routes from ROUTE_ALT.
    # Horde mount 0, the stock convention for a one-faction node (Stormwind is
    # 0/541): ObjectMgr::GetNearestTaxiNode skips it for Horde players, and
    # playerbots' TravelNodePath::getCost refuses a flight that starts or ends on a
    # node without the bot's team mount, so Horde bots never plan through the camp.
    (400, 751, CUSTOM, 400, 0, GRYPHON),   # 7th Legion Base Camp, Silverpine  (Gryphon Master Tolvan)
    (401, 751, CUSTOM, 401, 0, GRYPHON),   # Ambermill, Silverpine             (Gryphon Master Dorrin)
    (402, 751, CUSTOM, 402, 0, GRYPHON),   # Stormpike Encampment, Hillsbrad   (Gryphon Master Hilda Stonepeak)
]

# Nodes no Cata/stock flight point stands on: (continent, x, y, z, name), with z the
# terrain height under the spot (client ADT heightmap), as Blizzard's rows carry it.
# Each sits 4-6 yd from its flight master (creature 830308 / 830318 / 830320), so
# ActivateTaxiPathTo's start-distance check passes from anywhere in talking range.
CUSTOM_NODES = {
    400: (0, -583.0, 1689.0, 14.3, "7th Legion Base Camp, Silverpine Forest"),
    401: (0, -36.0, 716.0, 65.19, "Ambermill, Silverpine Forest"),
    402: (0, -34.0, -317.0, 130.81, "Stormpike Encampment, Hillsbrad"),
}

# Alliance-only nodes. An Alliance player cannot discover a Horde flight master's
# node (the NPC is hostile), and WorldSession::HandleActivateTaxi(Express)Opcode
# refuses a route through any node the player has not discovered -- so the client's
# usual chaining through Horde nodes would fail for them. These nodes therefore get
# NO adjacency paths at all, only the direct FORCED_PAIRS below (both directions),
# and they are never an intermediate hop of any other route.
ALLIANCE_ONLY = {400, 401, 402}
# Each pair is routed like any other (combined_path over REAL Cata segments), then
# its custom ends get the LEADIN below; 400<->402 is FORCED_VIA. 426 Chillwind
# Camp, 396 Refuge Pointe and 390 Aerie Peak are the Alliance-held nodes the spine
# connects to.
FORCED_PAIRS = [(400, 401), (401, 402), (400, 402), (402, 426), (402, 396), (402, 390)]

# The Cata flight points the custom nodes route through stand 331-706 yd away, and
# the end snap alone flies that distance as one straight glide -- through the
# ridge at the Forward Command (-20 yd) and the hills around the Stormpike camp
# (-50 yd), measured on the client heightmap. LEADIN replaces those glides. Per
# forced path: (head, tail), each None (plain snap) or
#   (k, (x, y, z) of waypoint k, [lifted points])
# meaning "fly from our node over the lifted points onto waypoint k of the
# combined_path() polyline" (head; the tail mirrors it into our node). Waypoints
# before k (after k for a tail) are dropped, which is what cuts the long detours
# through Horde flight points (401->402 was 5,019 yd of Blizzard chain via the
# Sepulcher; it flies 1,199 yd).
# Computed offline (2026-11-12) from the map-751 ADT heightmap of the test client
# (MCVT, the client's own triangle interpolation): 35 yd over terrain in cruise,
# >= 10 yd inside the 80 yd take-off/landing zones, climb <= 0.9; the join point
# minimises the flown length with a lifted yard counted 1.3x a Blizzard yard.
# Buildings and trees are not in a heightmap. The waypoint-k coordinates are
# asserted, so a change to ROUTE_ALT, CUSTOM_NODES or the Cata data fails loudly
# here: recompute the entry, or delete it to fall back to the plain snap.
LEADIN = {
    (400, 401): (
        (11, (-472.4, 1556.3, 91.1),
         [(-551.4, 1651.1, 48.4), (-532.4, 1628.3, 44.3)]),
        (16, (-185.3, 1275.8, 75.1),
         [(-182.7, 1266.1, 83.8), (-171.1, 1222.7, 88.2), (-160.8, 1184.1, 99.6), (-153.1, 1155.1, 96.6),
          (-126.1, 1053.8, 102.3), (-99.0, 952.5, 103.8), (-82.3, 889.7, 100.4), (-65.6, 827.0, 95.8),
          (-48.9, 764.3, 98.4)])),
    (401, 400): (
        (2, (-181.2, 1309.5, 78.0),
         [(-47.8, 764.3, 98.3), (-63.1, 827.0, 96.0), (-78.5, 889.7, 100.4), (-93.8, 952.4, 103.9),
          (-112.7, 1029.6, 100.7), (-132.8, 1111.7, 97.9), (-151.7, 1188.9, 99.0), (-162.3, 1232.3, 87.2)]),
        (6, (-422.9, 1446.8, 80.4),
         [(-455.4, 1496.0, 52.1), (-479.9, 1533.0, 54.1), (-493.4, 1553.5, 46.4), (-539.6, 1623.3, 43.3),
          (-555.9, 1647.9, 48.2)])),
    (401, 402): (
        (23, (115.8, 600.0, 147.0),
         [(2.9, 686.3, 98.3), (38.0, 659.5, 106.0), (108.1, 605.9, 150.1)]),
        (25, (49.7, 23.0, 122.6),
         [(45.0, 3.9, 112.7), (35.6, -34.5, 130.6), (10.8, -135.0, 161.2), (3.7, -163.8, 175.7),
          (-3.3, -192.5, 179.0), (-10.4, -221.2, 193.8), (-13.9, -235.6, 189.3), (-18.7, -254.7, 197.4)])),
    (402, 401): (
        (10, (-88.0, 195.4, 123.9),
         [(-38.2, -277.6, 176.5), (-39.7, -262.8, 183.8), (-42.3, -238.2, 173.1), (-46.5, -198.8, 167.5),
          (-56.3, -105.2, 167.4), (-66.2, -11.5, 168.3), (-74.0, 62.4, 131.1), (-81.7, 136.3, 94.2)]),
        (11, (286.9, 386.0, 110.7),
         [(217.5, 457.0, 63.5), (158.4, 517.3, 105.7), (102.9, 574.1, 145.4), (89.0, 588.3, 135.5),
          (82.0, 595.4, 138.0), (43.9, 634.4, 110.7), (-1.3, 680.5, 99.7)])),
    (402, 426): (
        (4, (-628.2, -766.0, 33.5),
         [(-73.9, -347.1, 168.1), (-101.8, -368.2, 168.1), (-197.5, -440.5, 109.2), (-269.3, -494.8, 96.2),
          (-337.1, -546.0, 88.2), (-377.0, -576.1, 86.5), (-408.9, -600.2, 90.7), (-432.8, -618.3, 89.5),
          (-448.7, -630.4, 81.6), (-476.7, -651.5, 87.2), (-520.5, -684.6, 80.0), (-552.4, -708.7, 80.9),
          (-568.4, -720.8, 77.1), (-616.2, -756.9, 47.0)]),
        None),
    (426, 402): (
        None,
        (23, (-567.6, -827.0, 22.7),
         [(-524.3, -785.7, 76.6), (-509.9, -771.9, 84.5), (-434.2, -699.5, 85.4), (-354.9, -623.7, 88.0),
          (-279.2, -551.3, 94.2), (-207.0, -482.4, 103.3), (-156.6, -434.2, 114.0), (-73.7, -354.9, 167.3)])),
    (402, 396): (
        (3, (-727.6, -600.8, 44.2),
         [(-47.9, -322.7, 153.0), (-80.2, -335.9, 170.5), (-145.0, -362.4, 182.9), (-154.2, -366.2, 179.1),
          (-168.1, -371.9, 181.1), (-251.3, -405.9, 136.9), (-329.9, -438.1, 94.4), (-408.6, -470.2, 85.1),
          (-487.2, -502.4, 76.5), (-547.3, -527.0, 74.5), (-607.4, -551.6, 71.7), (-630.5, -561.0, 62.5),
          (-699.9, -589.4, 62.4)]),
        None),
    (396, 402): (
        None,
        (11, (-776.0, -528.0, 35.0),
         [(-737.7, -517.1, 56.7), (-709.0, -508.9, 58.0), (-689.8, -503.5, 65.4), (-608.4, -480.3, 68.3),
          (-503.1, -450.4, 76.9), (-397.8, -420.5, 87.1), (-297.3, -391.9, 138.8), (-196.8, -363.3, 189.5),
          (-91.4, -333.3, 175.4), (-48.4, -321.1, 154.2)])),
    (402, 390): (
        (3, (-728.3, -593.1, 34.2),
         [(-47.9, -322.5, 153.1), (-80.3, -335.4, 170.5), (-145.1, -361.2, 183.2), (-168.2, -370.4, 182.3),
          (-251.6, -403.5, 138.2), (-334.9, -436.6, 94.0), (-408.9, -466.1, 85.1), (-487.6, -497.4, 75.9),
          (-552.4, -523.1, 74.3), (-612.6, -547.0, 71.4), (-640.4, -558.1, 61.5), (-682.1, -574.7, 61.1)]),
        None),
    (390, 402): (
        None,
        (12, (-595.8, -607.7, 49.8),
         [(-547.1, -582.5, 74.9), (-449.8, -532.2, 85.5), (-343.6, -477.2, 89.4), (-286.1, -447.5, 99.2),
          (-215.4, -410.9, 138.4), (-144.6, -374.2, 175.5), (-118.0, -360.5, 177.4), (-78.2, -339.9, 169.2)])),
}

# Forced pairs flown as two other forced paths back to back, passing OVER the
# middle node at VIA_HEIGHT above its ground instead of landing there: the Cata
# chain for 400<->402 (via the Sepulcher) is 5,700 yd and touches down in a Horde
# camp. Lifted points within VIA_SKIP yd of the middle node (the legs' landing /
# take-off ramps) are dropped.
FORCED_VIA = {(400, 402): 401, (402, 400): 401}
VIA_HEIGHT = 35.0
VIA_SKIP = 60.0

# Obstacle lift for every forced path (2026-11-22). LEADIN above clears the HEIGHTMAP only,
# and the Alterac / Silverpine pines are 50-110 yd tall: the 12 forced paths flew through
# ~2.2 tree crowns per 1000 yd (Blizzard's own 751 routes: 0.3, the same as in Cata, whose
# ground and doodads 751 shares). taxi_forced_lift.py raises each FINISHED forced path --
# LEADIN and FORCED_VIA included -- over the trees, rocks and buildings of the client's
# map-751 ADTs, never lowering a point and never moving it sideways, and stores the result
# here keyed by pair, with a fingerprint of the polyline it was computed from. Any change
# that moves a forced polyline (LEADIN, ROUTE_ALT, CUSTOM_NODES, the Cata data, the end
# rule) makes the entry stale and fails loudly below: rerun the tool, it regenerates the
# polylines itself (python taxi_forced_lift.py, then this script).
FORCED_LIFT_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "taxi_forced_lift.json")
# Set by taxi_forced_lift.py: write the UN-lifted forced polylines there instead of applying
# the lift. Only allowed against a DC_TAXI_CSV_DIR copy, never the repo CSVs.
DUMP_FORCED = os.environ.get("DC_TAXI_DUMP_FORCED")
if DUMP_FORCED and not os.environ.get("DC_TAXI_CSV_DIR"):
    raise SystemExit("DC_TAXI_DUMP_FORCED needs DC_TAXI_CSV_DIR: a dump run writes UN-lifted CSVs")


def polyline_fingerprint(pts):
    return hashlib.sha1(";".join("%.1f,%.1f,%.1f" % (p[1], p[2], p[3]) for p in pts)
                        .encode()).hexdigest()[:16]


FORCED_LIFT = {}
if not DUMP_FORCED and os.path.exists(FORCED_LIFT_JSON):
    with open(FORCED_LIFT_JSON, encoding="utf-8") as _f:
        for _e in json.load(_f)["paths"]:
            FORCED_LIFT[(_e["from"], _e["to"])] = _e

# ---- read Cata DBCs ----------------------------------------------------------
def read_dbc(name):
    d = open(os.path.join(CATA_DIR, name + ".dbc"), "rb").read()
    _, rc, fc, rs, ss = struct.unpack("<4sIIII", d[:20])
    return d, rc, rs, 20, 20 + rc * rs

dN, rcN, rsN, baseN, strN = read_dbc("TaxiNodes")
def cstr(off):
    e = dN.index(b"\0", strN + off)
    return dN[strN + off:e].decode("utf-8", "replace")

cata_node = {}
for i in range(rcN):
    r = dN[baseN + i * rsN: baseN + i * rsN + rsN]
    nid, cont = struct.unpack("<II", r[:8])
    x, y, z = struct.unpack("<fff", r[8:20])
    noff = struct.unpack("<I", r[20:24])[0]
    cata_node[nid] = (cont, x, y, z, cstr(noff))

dP, rcP, rsP, baseP, _ = read_dbc("TaxiPath")
edge = {}  # (from,to) -> (pathid, cost)
for i in range(rcP):
    pid, frm, to, cost = struct.unpack("<IIII", dP[baseP + i * rsP: baseP + i * rsP + 16])
    edge[(frm, to)] = (pid, cost)

dT, rcT, rsT, baseT, _ = read_dbc("TaxiPathNode")
seg = defaultdict(list)  # pathid -> [(idx, cont, x, y, z, flags), ...]
for i in range(rcT):
    r = dT[baseT + i * rsT: baseT + i * rsT + rsT]
    tid, pid, idx, cont = struct.unpack("<IIII", r[:16])
    x, y, z = struct.unpack("<fff", r[16:28])
    flags = struct.unpack("<I", r[28:32])[0]
    seg[pid].append((idx, cont, x, y, z, flags))
for pid in seg:
    seg[pid].sort()

# ---- routing among our nodes -------------------------------------------------
# Per-source graphs.  The stock ones are filled from the CSVs further down, once
# the read helpers exist; everything here only reads them at call time.
NODE_INFO = {CATA: cata_node, STOCK: {},                CUSTOM: dict(CUSTOM_NODES)}
EDGE      = {CATA: edge,      STOCK: {},                CUSTOM: {}}
SEG       = {CATA: seg,       STOCK: defaultdict(list), CUSTOM: defaultdict(list)}

src_of  = {o: (s, c) for o, m, s, c, mh, ma in NODEMAP}
our_by_map = defaultdict(list)
for o, m, s, c, mh, ma in NODEMAP:
    our_by_map[m].append(o)

# Extra source bindings used for ROUTING ONLY -- the TaxiNodes row itself still
# comes from NODEMAP above (our coordinates keep matching the live flight
# masters).  This is what lets a flight cross between the Cata-only Hyjal
# cluster and the stock border cluster on REAL Blizzard waypoints instead of a
# synthesised arc: Winterspring, Felwood and Moonglade were not revamped in
# Cataclysm, so those nodes exist in BOTH sources at the same place (Everlook
# 52/53 and Moonglade 49/69 match to the decimal), and Blizzard authored proper
# Cata routes from all four of them to Nordrassil (559 = our 424) -- 28-35
# terrain-following waypoints each.  Binding them to stock alone made every
# Hyjal<->border pair look unroutable and fall through to synth_arc.
#
# Azshara is deliberately absent: Cata node 44 is post-revamp Bilgewater
# Harbour, 1,900 yds away in open water, so Valormok (338) stays stock-only.
# It still reaches Hyjal by chaining through Talonbranch / Moonglade /
# Everlook, which do exist in both sources.
ROUTE_ALT = {
    339: [(CATA, 166)],   # Emerald Sanctuary  (Cata node 11 yds from ours)
    343: [(CATA,  65)],   # Talonbranch Glade  (Cata node 76 yds from ours)
    344: [(CATA,  52)],   # Everlook           (exact match)
    345: [(CATA,  53)],   # Everlook           (exact match)
    446: [(CATA,  49)],   # Moonglade          (exact match)
    447: [(CATA,  69)],   # Moonglade          (exact match)
    # CUSTOM nodes route through the nearest Cata flight point that HAS the real
    # segments they need; combined_path snaps the two ends back onto our node and
    # LEADIN (below FORCED_PAIRS) lifts the resulting glides over the terrain.
    # 402 takes two: Tarren Mill (13) for the Silverpine side, and pre-revamp
    # Southshore (14) for Blizzard's Alliance routes to Chillwind (14->66),
    # Refuge Pointe (14->16) and Aerie Peak (14->43).
    400: [(CATA, 646)],   # 7th Legion Base Camp -> Forsaken Forward Command (331 yd)
    401: [(CATA, 654)],   # Ambermill            -> The Forsaken Front       (601 yd)
    402: [(CATA,  13), (CATA, 14)],   # Stormpike -> Tarren Mill (557 yd), Southshore (706 yd)
}

# our node -> every (source, source_node) it can be routed through
srcs_of = defaultdict(list)
for o, m, s, c, mh, ma in NODEMAP:
    srcs_of[o].append((s, c))
for o, alts in ROUTE_ALT.items():
    for a in alts:
        if a not in srcs_of[o]:
            srcs_of[o].append(a)

def hop_waypoints(src, ca, cb):
    pid = EDGE[src][(ca, cb)][0]
    return [(cont, x, y, z, fl) for (idx, cont, x, y, z, fl) in SEG[src][pid]]

def best_edge(u, v):
    """Cheapest real segment between two of OUR nodes, over every source that
    holds both endpoints.  Returns (source, src_from, src_to, cost) or None."""
    best = None
    for su, cu in srcs_of[u]:
        for sv, cv in srcs_of[v]:
            if su != sv:
                continue
            e = EDGE[su].get((cu, cv))
            if e and (best is None or e[1] < best[3]):
                best = (su, cu, cv, e[1])
    return best

def dijkstra(mp, oa, ob):
    """Cheapest chain of real segments between two of OUR nodes.

    The graph is keyed on OUR node ids rather than one source's, so a route may
    change source at any node that exists in both -- which is exactly how the
    border cluster reaches Hyjal.  Returns [(u, v, source, src_from, src_to)].

    ALLIANCE_ONLY nodes are never an intermediate hop: they share their Cata
    bindings with Horde nodes (400 ~ 399's 646), and 402 holds two Cata nodes
    574/739 yd apart, so routing THROUGH one could jump between them mid-route --
    and leaving them out keeps every pre-existing route exactly as it was.
    """
    ours = [o for o in our_by_map[mp] if o not in ALLIANCE_ONLY or o in (oa, ob)]
    adj = defaultdict(list)
    for u in ours:
        for v in ours:
            if u == v:
                continue
            be = best_edge(u, v)
            if be:
                adj[u].append((v, be[3], be[0], be[1], be[2]))
    dist = {oa: 0}
    prev = {}
    pq = [(0, oa)]
    while pq:
        du, u = heapq.heappop(pq)
        if u == ob:
            break
        if du > dist.get(u, 1e18):
            continue
        for v, w, s, cu, cv in adj[u]:
            nd = du + max(w, 1)
            if nd < dist.get(v, 1e18):
                dist[v] = nd
                prev[v] = (u, s, cu, cv)
                heapq.heappush(pq, (nd, v))
    if ob not in dist and oa != ob:
        return None
    hops = []
    cur = ob
    while cur != oa:
        pu, ps, pcu, pcv = prev[cur]
        hops.append((pu, cur, ps, pcu, pcv))
        cur = pu
    hops.reverse()
    return hops

CRUISE_CLEARANCE = 250.0   # yards above the higher endpoint
# NOTE (round 43): synth_arc is now a LAST RESORT that nothing currently hits --
# the generator reports "synthesised: 0".  Routing was taught to change source
# mid-chain (see ROUTE_ALT), so every one of the 264 pairs flies real Blizzard
# waypoints.  Keep this fallback for future nodes, but if it ever fires again,
# treat it as a bug to fix in ROUTE_ALT rather than a result to ship: the flat
# cruise below is what produced the user-visible "rockets to a silly altitude
# and clips the ground on take-off" flights.
#
# Long arcs cross the Hyjal rim / Winterspring peaks (~1,900), and a cruise
# keyed only to the ENDPOINTS flies straight through them -- Everlook (z 711)
# to Valormok (z 113) cruised at 951 and spent most of the route inside the
# mountain ("falling through the ground", user-reported).  There is no terrain
# sampling offline, so any arc long enough to leave its valley gets a flat
# floor above the highest ridge on the map.  Short hops (Everlook's two masters
# are ~130 yd apart) keep the endpoint-relative cruise -- rocketing to 2,200
# between two nodes in the same town would look ridiculous.
CRUISE_FLOOR = 2200.0
CRUISE_FLOOR_DIST = 800.0  # arcs shorter than this stay endpoint-relative

def synth_arc(oa, ob):
    """Straight hop for a pair Blizzard never authored.

    The five Hyjal points only exist in Cata (the zone was closed in 3.3.5) and
    the seven border points only in stock, so no source contains a route between
    the two clusters -- and AzerothCore has no TaxiPathGraph, it looks up
    sTaxiPathSetBySource[from][to] and nothing else, so every ordered pair needs
    its own path or the flight master simply will not offer the destination.

    Climb, cruise, descend.  Cruise sits CRUISE_CLEARANCE above the higher of the
    two ends, which clears Hyjal's rim on the worst pair (Nordrassil at z 1570
    down to Valormok at z 113).  Taxi splines do not collide with terrain, so the
    only thing altitude buys is not flying through a mountain in plain view.
    """
    _, mp_a, xa, ya, za, _ = node_row(oa)
    _, mp_b, xb, yb, zb, _ = node_row(ob)
    dist = ((xb - xa) ** 2 + (yb - ya) ** 2) ** 0.5
    cruise = max(za, zb) + CRUISE_CLEARANCE
    if dist > CRUISE_FLOOR_DIST:
        cruise = max(cruise, CRUISE_FLOOR)
    pts = [(mp_a, xa, ya, za + 10.0, 0)]
    for t in (0.15, 0.4, 0.6, 0.85):
        pts.append((mp_a, xa + (xb - xa) * t, ya + (yb - ya) * t, cruise, 0))
    pts.append((mp_b, xb, yb, zb + 10.0, 0))
    return pts, int(min(2000, max(200, dist * 0.6)))

# Path ends (2026-11-22). AzerothCore's FlightPathMovementGenerator::DoFinalize dismounts
# the player wherever the spline ends -- it does not put them on the ground -- so the last
# waypoint IS the landing spot. Blizzard's own paths end ~2 yd above the node (Cata median
# 2.0, stock 1.8, measured over 487 + 184 continent-0 paths). The old snap put both ends
# at node z + 10, which dropped the player 10 yd at every landing on 750/751. So:
#   * a hop flown from the node's OWN binding (src_of) keeps Blizzard's end waypoint when
#     it lies within ENDPOINT_KEEP yd -- for CATA/STOCK nodes our TaxiNodes row is that
#     source node's position, so this is exactly Blizzard's landing;
#   * any other end (ROUTE_ALT bindings such as Emerald Sanctuary, whose Cata ends sit
#     8-12 yd off and 3.5 yd low on our stock Felwood ground, and the CUSTOM nodes) is
#     snapped onto our node at Blizzard's height, ENDPOINT_LIFT.
# The take-off needs no snap: DoReset prepends the player's own position to the spline.
ENDPOINT_KEEP = 15.0
ENDPOINT_LIFT = 2.0


def combined_path(mp, oa, ob, hops=None):
    """Waypoints for oa->ob over `hops` (default: the cheapest chain, dijkstra)."""
    if hops is None:
        hops = dijkstra(mp, oa, ob)
    if hops is None:
        return synth_arc(oa, ob)
    pts, cost = [], 0
    for hi, (u, v, src, cu, cv) in enumerate(hops):
        wp = hop_waypoints(src, cu, cv)
        cost += EDGE[src][(cu, cv)][1]
        if hi > 0:
            wp = wp[1:]  # drop point coinciding with previous segment's end
        pts.extend(wp)
    # Snap an end onto OUR node only where the source does not already land on it
    # (see ENDPOINT_KEEP above). A source node can sit well off ours -- Talonbranch
    # is 76 yds, the custom nodes 331-706 yds -- and a chain may change source.
    if pts:
        ends = ((0, oa, (hops[0][2], hops[0][3])), (-1, ob, (hops[-1][2], hops[-1][4])))
        for i, oid, flown in ends:
            _, _, xo, yo, zo, _ = node_row(oid)
            p = pts[i]
            if flown != src_of[oid] or math.hypot(p[1] - xo, p[2] - yo) > ENDPOINT_KEEP:
                pts[i] = (p[0], xo, yo, zo + ENDPOINT_LIFT, p[4])
    return pts, cost

# ---- CSV helpers (dot decimal, fully quoted, LF, no BOM) ---------------------
def num(v):
    # Dot decimal separator: the CSV-DBC convention in this repo (matches
    # CreatureModelData.csv etc. and what WDBX Editor parses). A comma is read as
    # a thousands separator by WDBX and silently drops the fraction.
    if isinstance(v, int) or float(v).is_integer():
        return str(int(v))
    return ("%.4f" % v).rstrip("0").rstrip(".")

def read_rows(path):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        return list(csv.reader(f))

def write_rows(path, header, rows):
    out = io.StringIO()
    w = csv.writer(out, quoting=csv.QUOTE_ALL, lineterminator="\n")
    w.writerow(header)
    for r in rows:
        w.writerow(r)
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(out.getvalue())

# ---- stock 3.3.5 graph, read back out of the CSVs ----------------------------
# The CSVs are this script's own output, so anything in our id ranges is skipped
# -- otherwise a second run would treat the generated map-750 paths as stock
# source data and feed them back into the router.
_srows = read_rows(NODES_CSV)[1:]
for r in _srows:
    if r and r[0].isdigit() and int(r[0]) not in NODE_IDS:
        NODE_INFO[STOCK][int(r[0])] = (int(r[1]), float(r[2]), float(r[3]), float(r[4]), r[5])
for r in read_rows(PATH_CSV)[1:]:
    if r and r[0].isdigit() and int(r[0]) < PATH_BASE:
        EDGE[STOCK][(int(r[1]), int(r[2]))] = (int(r[0]), int(r[3]))
for r in read_rows(PNODE_CSV)[1:]:
    if r and r[0].isdigit() and int(r[1]) < PATH_BASE:
        SEG[STOCK][int(r[1])].append((int(r[2]), int(r[3]), float(r[4]),
                                      float(r[5]), float(r[6]), int(r[7])))
for _pid in SEG[STOCK]:
    SEG[STOCK][_pid].sort()

def node_row(oid):
    """(source, our_map, x, y, z, name) for one of our nodes."""
    src, cid = src_of[oid]
    mp = next(m for o, m, s, c, mh, ma in NODEMAP if o == oid)
    cont, x, y, z, name = NODE_INFO[src][cid]
    return src, mp, x, y, z, NAME_OVERRIDE.get(oid, name)

# ---- TaxiNodes (snap coords + name to the matched source node) ---------------
rows = read_rows(NODES_CSV)
hdr = rows[0]
body = [r for r in rows[1:] if not (r and r[0].isdigit() and int(r[0]) in NODE_IDS)]
node_meta = {}  # our_id -> (map, x, y, z, name)
append_last = []
for oid, mp, srcn, cid, mh, ma in NODEMAP:
    _, _, x, y, z, name = node_row(oid)
    node_meta[oid] = (mp, x, y, z, name)
    row = [str(oid), str(mp), num(x), num(y), num(z), name] + [""] * 15 + [MASK, str(mh), str(ma)]
    assert len(row) == len(hdr), (len(row), len(hdr))
    (append_last if srcn == CUSTOM else body).append(row)
body.sort(key=lambda r: int(r[0]))
# CUSTOM rows go AFTER the sorted body, not into id order. The DBC compiler lays
# the string block out in record order, so a row inserted mid-file would shift
# the name offset of every record after it; appended, every earlier record stays
# byte-identical and only new bytes are added. The client and the server look
# TaxiNodes up by id, never by position.
append_last.sort(key=lambda r: int(r[0]))
write_rows(NODES_CSV, hdr, body + append_last)

# ---- TaxiPath + TaxiPathNode (full mesh, real Cata waypoints) ----------------
prows = read_rows(PATH_CSV)
phdr = prows[0]
pbody = [r for r in prows[1:] if not (r and r[0].isdigit() and int(r[0]) >= PATH_BASE)]

pnrows = read_rows(PNODE_CSV)
pnhdr = pnrows[0]
pnbody = [r for r in pnrows[1:] if not (r and r[0].isdigit() and int(r[0]) >= PNODE_BASE)]

pid = PATH_BASE
pnid = PNODE_BASE
npaths = 0
multi = 0
synth = 0
maxpts = 0
skipped_nonadjacent = 0
for mp, ids in our_by_map.items():
    for a in ids:
        for b in ids:
            if a == b:
                continue
            # Alliance-only nodes fly FORCED_PAIRS only (emitted after this loop,
            # so every id this loop hands out stays what it was before them).
            if a in ALLIANCE_ONLY or b in ALLIANCE_ONLY:
                continue
            # Adjacency maps emit ONLY pairs Blizzard actually connected; the
            # client chains the rest. Everything stays reachable because the
            # real-edge graph is connected (asserted after this loop).
            if mp in ADJACENCY_ONLY_MAPS and not best_edge(a, b):
                skipped_nonadjacent += 1
                continue
            # An adjacency pair IS a real Blizzard edge, so it flies that edge. Letting
            # dijkstra pick a cheaper chain here (it did until 2026-11-22) stitched
            # 9 of 751's and 2 of 750's paths through intermediate flight points with
            # their landings kept: Tarren Mill -> The Bulwark dived through the
            # Undercity tunnel and landed at Brill on the way (133 waypoints; the
            # direct path has 21). Multi-leg routes are the CLIENT's job here.
            if mp in ADJACENCY_ONLY_MAPS:
                be = best_edge(a, b)
                hops = [(a, b, be[0], be[1], be[2])]
            else:
                hops = dijkstra(mp, a, b)
            pts, cost = combined_path(mp, a, b, hops)
            if not pts:
                raise SystemExit(f"no route {a}->{b} on map {mp}")
            if hops is None:
                synth += 1
            elif len(hops) > 1:
                multi += 1
            elif len({h[2] for h in hops}) > 1:
                multi += 1
            cost = int(min(2000, max(50, cost)))
            pbody.append([str(pid), str(a), str(b), str(cost)])
            maxpts = max(maxpts, len(pts))
            for idx, (cont, x, y, z, fl) in enumerate(pts):
                mapid = CONT_REMAP.get(cont, mp)
                pnbody.append([str(pnid), str(pid), str(idx), str(mapid),
                               num(x), num(y), num(z), str(fl), "0", "0", "0"])
                pnid += 1
            pid += 1
            npaths += 1

# ---- Alliance-only spine: FORCED_PAIRS, both directions ------------------------
# After the main loop on purpose: these take the next free ids, so no existing
# TaxiPath / TaxiPathNode row changes id or content.
def apply_leadin(a, b, pts):
    """Replace the snap glide(s) of a forced path by its LEADIN entry."""
    head, tail = LEADIN.get((a, b), (None, None))
    kh, hpts, kt, tpts = 1, [], len(pts) - 2, []
    for part, is_head in ((head, True), (tail, False)):
        if part is None:
            continue
        k, at, lifted = part
        if not 0 < k < len(pts) - 1 or any(abs(pts[k][1 + i] - at[i]) > 0.11 for i in range(3)):
            raise SystemExit(f"LEADIN {a}->{b} is stale (waypoint {k} moved) -- recompute or delete the entry")
        if is_head:
            kh, hpts = k, lifted
        else:
            kt, tpts = k, lifted
    if kt < kh:
        raise SystemExit(f"LEADIN {a}->{b}: leave point {kt} before join point {kh}")
    cont = pts[0][0]
    lift = [(cont, x, y, z, 0) for x, y, z in hpts], [(cont, x, y, z, 0) for x, y, z in tpts]
    return [pts[0]] + lift[0] + pts[kh:kt + 1] + lift[1] + [pts[-1]]


def via_path(first, second, mid):
    """Two built forced paths back to back, passing over node `mid` at VIA_HEIGHT."""
    _, mx, my, mz, _ = CUSTOM_NODES[mid]
    near = lambda p: ((p[1] - mx) ** 2 + (p[2] - my) ** 2) ** 0.5 < VIA_SKIP
    head = first[:-1]
    while len(head) > 1 and near(head[-1]):
        head.pop()
    tail = second[1:]
    while len(tail) > 1 and near(tail[0]):
        tail.pop(0)
    return head + [(first[-1][0], mx, my, mz + VIA_HEIGHT, 0)] + tail


forced = []
forced_dump = []
built = {}   # (a, b) -> (un-lifted waypoints, cost), for FORCED_VIA
for a0, b0 in FORCED_PAIRS:
    for a, b in ((a0, b0), (b0, a0)):
        mp = node_meta[a][0]
        if node_meta[b][0] != mp:
            raise SystemExit(f"forced pair {a}->{b} crosses maps")
        if (a, b) in FORCED_VIA:
            mid = FORCED_VIA[(a, b)]
            if (a, mid) not in built or (mid, b) not in built:
                raise SystemExit(f"FORCED_VIA {a}->{b}: legs via {mid} must come earlier in FORCED_PAIRS")
            pts = via_path(built[(a, mid)][0], built[(mid, b)][0], mid)
            cost = built[(a, mid)][1] + built[(mid, b)][1]
            hops = [(a, mid, "via", a, mid), (mid, b, "via", mid, b)]
        else:
            hops = dijkstra(mp, a, b)
            if hops is None:
                raise SystemExit(f"forced pair {a}->{b}: no real route -- fix ROUTE_ALT, never ship a synth_arc")
            pts, cost = combined_path(mp, a, b)
            pts = apply_leadin(a, b, pts)
        if len(hops) > 1 or len({h[2] for h in hops}) > 1:
            multi += 1
        cost = int(min(2000, max(50, cost)))
        built[(a, b)] = (pts, cost)   # UN-lifted: FORCED_VIA and the fingerprint use these
        fp = polyline_fingerprint(pts)
        if DUMP_FORCED:
            forced_dump.append({"from": a, "to": b, "map": mp, "fingerprint": fp,
                                "points": [[p[1], p[2], p[3]] for p in pts]})
        else:
            lift = FORCED_LIFT.get((a, b))
            if lift is None:
                raise SystemExit(f"forced path {a}->{b} has no entry in taxi_forced_lift.json -- "
                                 "run taxi_forced_lift.py")
            if lift["fingerprint"] != fp:
                raise SystemExit(f"taxi_forced_lift.json entry {a}->{b} is stale (its polyline moved) -- "
                                 "rerun taxi_forced_lift.py")
            pts = [(pts[0][0], x, y, z, 0) for x, y, z in lift["points"]]
        pbody.append([str(pid), str(a), str(b), str(cost)])
        maxpts = max(maxpts, len(pts))
        for idx, (cont, x, y, z, fl) in enumerate(pts):
            mapid = CONT_REMAP.get(cont, mp)
            pnbody.append([str(pnid), str(pid), str(idx), str(mapid),
                           num(x), num(y), num(z), str(fl), "0", "0", "0"])
            pnid += 1
        forced.append((pid, a, b, cost, len(pts), [(h[3], h[4]) for h in hops]))
        pid += 1
        npaths += 1

# Every Alliance-only node must reach a shared node over forced paths alone --
# it has no adjacency path, so this is its only way into the rest of the map.
_fadj = defaultdict(set)
for _p, a, b, *_ in forced:
    _fadj[a].add(b)
for u in sorted(ALLIANCE_ONLY):
    seen, stack = {u}, [u]
    while stack:
        for v in _fadj[stack.pop()]:
            if v not in seen:
                seen.add(v)
                stack.append(v)
    if not seen - ALLIANCE_ONLY:
        raise SystemExit(f"Alliance-only node {u} reaches no shared node over FORCED_PAIRS")

# An adjacency network is only usable if the real-edge graph is CONNECTED --
# a mesh hides an isolated node, adjacency strands it with no way to fly out.
# Checked here rather than trusted, because the node list keeps growing.
# (Alliance-only nodes have no adjacency paths; they were checked just above.)
for mp in ADJACENCY_ONLY_MAPS:
    ids = [o for o in our_by_map.get(mp, []) if o not in ALLIANCE_ONLY]
    if not ids:
        continue
    adj = defaultdict(set)
    for u in ids:
        for v in ids:
            if u != v and best_edge(u, v):
                adj[u].add(v)
    start = next(iter(ids))
    seen, stack = {start}, [start]
    while stack:
        for v in adj[stack.pop()]:
            if v not in seen:
                seen.add(v)
                stack.append(v)
    stranded = sorted(set(ids) - seen)
    if stranded:
        raise SystemExit(f"map {mp}: adjacency graph is disconnected, stranded nodes {stranded}")
    lonely = sorted(u for u in ids if not adj[u])
    if lonely:
        raise SystemExit(f"map {mp}: nodes with no real edge at all {lonely}")
    print(f"map {mp}: adjacency connected, {len(ids)} nodes, "
          f"{sum(len(v) for v in adj.values())} real edges, "
          f"mean out-degree {sum(len(v) for v in adj.values())/len(ids):.1f} "
          f"(Blizzard's stock average is 3.2); {skipped_nonadjacent} mesh pairs dropped")

pbody.sort(key=lambda r: int(r[0]))
pnbody.sort(key=lambda r: int(r[0]))
write_rows(PATH_CSV, phdr, pbody)
write_rows(PNODE_CSV, pnhdr, pnbody)
if DUMP_FORCED:
    with open(DUMP_FORCED, "w", encoding="utf-8") as f:
        json.dump({"paths": forced_dump}, f)
    print("forced polylines dumped (UN-lifted) to", DUMP_FORCED)

print("nodes:", len(NODEMAP))
print("paths:", npaths, "ids", PATH_BASE, "..", pid - 1,
      "| multi-hop:", multi, "| synthesised:", synth)
print("pathnodes:", pnid - PNODE_BASE, "ids", PNODE_BASE, "..", pnid - 1, "| max pts/path:", maxpts)
print("forced (Alliance-only) paths:", len(forced))
for fpid, a, b, cost, npts, chain in forced:
    via = f"via {FORCED_VIA[(a, b)]} (over it)" if (a, b) in FORCED_VIA else \
        "via Cata " + " ".join(f"{s}->{t}" for s, t in chain)
    print(f"  {fpid}: {a} -> {b}  cost {cost}  {npts} pts  {via}")
print("names:")
for oid, mp, srcn, cid, mh, ma in NODEMAP:
    print(f"  {oid} (map {mp}) <- {srcn} {cid}: {node_meta[oid][4]}")
