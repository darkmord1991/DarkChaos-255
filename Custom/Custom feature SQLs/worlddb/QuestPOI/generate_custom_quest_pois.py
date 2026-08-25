# ---------------------------------------------------------------------------
# generate_custom_quest_pois.py -- quest_poi backfill for custom quests
# ---------------------------------------------------------------------------
# 183 custom quests (ID >= 80000) had no quest_poi rows, so the stock combined
# world map (QuestMapUpdateAllQuests is POI-driven, C-side) could never list
# them: empty quest panel + empty detail book even with the quest in the log.
#
# This generator emits dc_custom_quest_poi_backfill.sql from data snapshotted
# out of the live acore_world DB (2026-08-17):
#   * turn-in POI (ObjectiveIndex -1, Flags 1) at the quest ender's spawn
#   * objective POIs (ObjectiveIndex 0..3, Flags 3) at the centroid of each
#     RequiredNpcOrGo creature's spawns, grouped per WorldMapArea
#   * points on instance maps are re-anchored to the dungeon ENTRANCE on the
#     outdoor map (retail behaviour); instance maps without a WorldMapArea or
#     a stock entrance trigger (669 BWD, 819/820/823/824 custom) are dropped
#   * Hyjal Frontier (map 1410) NPCs have no live spawns (script/pending SQL),
#     so their coordinates come from the planned layout in
#     "Custom/Level Areas/old Hyjal 80 - 130/*.sql" -- regenerate when that
#     zone goes live if positions moved
#
# WorldMapAreaId is resolved from the live server WorldMapArea.dbc: exact
# zone-id match when the spawn has one, else smallest enclosing rect on the
# spawn's map (micro-dungeon WMAs, name ~ "...12_", are excluded).
#
# Re-run:  python generate_custom_quest_pois.py   (writes the .sql next to it)
# ---------------------------------------------------------------------------

import os
import re
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dc_custom_quest_poi_backfill.sql")
WMA_DBC = r"K:\Dark-Chaos\Server\data\dbc\WorldMapArea.dbc"
OLD_HYJAL_DIR = os.path.join(HERE, "..", "..", "..", "Level Areas", "old Hyjal 80 - 130")

# quest -> RequiredNpcOrGo1..4 (0 = unused). Snapshot of the 183 POI-less quests.
QUESTS = {
    80100: [400324, 0, 0, 0],
    81200: [830031, 0, 0, 0], 81201: [830040, 830041, 0, 0], 81202: [830032, 0, 0, 0],
    81203: [830050, 830051, 0, 0], 81204: [830070, 830072, 0, 0], 81205: [830042, 0, 0, 0],
    81206: [830052, 0, 0, 0], 81207: [830062, 0, 0, 0], 81208: [830073, 0, 0, 0],
    81209: [830062, 830073, 0, 0], 81210: [830036, 0, 0, 0], 81211: [830040, 830041, 0, 0],
    81212: [830037, 0, 0, 0], 81213: [830060, 830061, 0, 0], 81214: [830071, 830072, 0, 0],
    81215: [830091, 0, 0, 0], 81216: [830092, 0, 0, 0], 81217: [830093, 0, 0, 0],
    81218: [830094, 0, 0, 0], 81219: [830095, 0, 0, 0], 81220: [830096, 0, 0, 0],
    81221: [830097, 0, 0, 0], 81222: [830098, 0, 0, 0], 81223: [830097, 830098, 0, 0],
    81230: [830110, 830114, 0, 0], 81231: [830115, 830119, 0, 0], 81232: [830120, 830124, 0, 0],
    81233: [830125, 830129, 0, 0], 81234: [830130, 830134, 0, 0],
    81235: [830040, 0, 0, 0], 81236: [830042, 0, 0, 0], 81237: [830032, 0, 0, 0],
    81238: [830050, 0, 0, 0], 81239: [830051, 0, 0, 0], 81240: [830033, 0, 0, 0],
    81241: [830060, 830061, 0, 0], 81242: [830034, 0, 0, 0],
    81250: [830040, 830041, 0, 0], 81251: [830042, 0, 0, 0], 81252: [830037, 0, 0, 0],
    81253: [830050, 0, 0, 0], 81254: [830052, 0, 0, 0], 81255: [830038, 0, 0, 0],
    81256: [830060, 830061, 0, 0], 81257: [830097, 0, 0, 0],
    81260: [830097, 0, 0, 0], 81261: [830034, 0, 0, 0], 81262: [0, 0, 0, 0],
    81270: [830097, 0, 0, 0], 81271: [830039, 0, 0, 0], 81272: [0, 0, 0, 0],
    81300: [0, 0, 0, 0], 81301: [0, 0, 0, 0],
    81310: [0, 0, 0, 0], 81311: [0, 0, 0, 0], 81312: [0, 0, 0, 0],
    81313: [0, 0, 0, 0], 81314: [0, 0, 0, 0], 81315: [0, 0, 0, 0],
    82000: [400500, 400501, 0, 0], 82001: [400510, 400511, 400512, 400513],
    82002: [400521, 0, 0, 0], 82003: [400522, 0, 0, 0], 82004: [400523, 0, 0, 0],
    82005: [400500, 400501, 0, 0], 82010: [400500, 400501, 0, 0], 82011: [400522, 0, 0, 0],
    82012: [400500, 400501, 0, 0], 82013: [400522, 0, 0, 0], 82014: [400500, 400501, 0, 0],
    82015: [400500, 400501, 0, 0],
    83100: [0, 0, 0, 0], 83101: [0, 0, 0, 0], 83102: [0, 0, 0, 0],
    90001: [0, 0, 0, 0], 90002: [0, 0, 0, 0], 90003: [0, 0, 0, 0], 90004: [0, 0, 0, 0],
    90005: [0, 0, 0, 0], 90006: [0, 0, 0, 0], 90007: [0, 0, 0, 0], 90008: [0, 0, 0, 0],
    90009: [0, 0, 0, 0], 90010: [3912902, 0, 0, 0], 90011: [0, 0, 0, 0],
    300400: [6190, 0, 0, 0], 300401: [6348, 0, 0, 0], 300402: [11467, 0, 0, 0],
    300403: [6129, 0, 0, 0], 300407: [0, 0, 0, 0], 300505: [0, 0, 0, 0],
    300507: [0, 0, 0, 0], 300606: [0, 0, 0, 0],
    300820: [29837, 0, 0, 0], 300821: [18432, 0, 0, 0], 300822: [16408, 0, 0, 0],
    300954: [0, 0, 0, 0], 300962: [27959, 0, 0, 0], 300963: [15689, 0, 0, 0],
    300964: [29517, 29518, 0, 0], 300966: [29770, 0, 0, 0],
    400340: [400339, 0, 0, 0], 400341: [400339, 0, 0, 0],
    400342: [400360, 0, 0, 0], 400343: [400360, 0, 0, 0],
    700101: [0, 0, 0, 0], 700102: [0, 0, 0, 0], 700103: [0, 0, 0, 0], 700104: [0, 0, 0, 0],
    700201: [0, 0, 0, 0], 700202: [0, 0, 0, 0], 700203: [0, 0, 0, 0], 700204: [0, 0, 0, 0],
    700701: [41570, 0, 0, 0], 700702: [42180, 0, 0, 0], 700703: [41378, 0, 0, 0],
    700704: [41442, 0, 0, 0], 700705: [43296, 0, 0, 0], 700706: [41376, 0, 0, 0],
    700707: [43125, 43128, 43127, 43126], 700708: [42362, 42649, 42800, 0],
    700709: [44202, 0, 0, 0], 700710: [0, 0, 0, 0],
    700720: [0, 0, 0, 0], 700721: [4020001, 0, 0, 0], 700722: [4020002, 0, 0, 0],
    700723: [4020005, 0, 0, 0], 700724: [4020006, 0, 0, 0], 700725: [4020007, 0, 0, 0],
    700726: [0, 0, 0, 0],
    700760: [0, 0, 0, 0], 700761: [4010001, 0, 0, 0], 700762: [4010002, 0, 0, 0],
    700763: [4010003, 0, 0, 0], 700764: [4010004, 0, 0, 0], 700765: [4010005, 0, 0, 0],
    700766: [4010006, 0, 0, 0], 700767: [4010007, 0, 0, 0], 700768: [0, 0, 0, 0],
    700800: [0, 0, 0, 0], 700801: [0, 0, 0, 0], 700802: [0, 0, 0, 0],
    700803: [4030001, 0, 0, 0], 700804: [4030002, 0, 0, 0], 700805: [0, 0, 0, 0],
    820000: [0, 0, 0, 0], 820001: [0, 0, 0, 0], 820002: [26105, 0, 0, 0],
    820003: [0, 0, 0, 0], 820004: [26723, 0, 0, 0], 820005: [0, 0, 0, 0],
    820006: [26723, 0, 0, 0],
    820010: [29306, 0, 0, 0], 820011: [0, 0, 0, 0], 820012: [0, 0, 0, 0],
    820013: [29306, 0, 0, 0],
    820020: [18373, 0, 0, 0], 820021: [18373, 0, 0, 0], 820022: [19480, 0, 0, 0],
    820023: [18373, 0, 0, 0],
    820030: [27641, 27447, 0, 0], 820031: [27656, 0, 0, 0], 820032: [27655, 0, 0, 0],
    820033: [0, 0, 0, 0], 820034: [0, 0, 0, 0], 820035: [27641, 0, 0, 0],
    820036: [27656, 0, 0, 0],
    820040: [0, 0, 0, 0], 820041: [0, 0, 0, 0], 820042: [0, 0, 0, 0],
    820043: [18311, 18314, 18313, 18312], 820044: [0, 0, 0, 0],
    820050: [18472, 18956, 0, 0], 820051: [0, 0, 0, 0], 820052: [0, 0, 0, 0],
    820053: [0, 0, 0, 0], 820054: [18708, 0, 0, 0], 820055: [0, 0, 0, 0],
    820057: [0, 0, 0, 0], 820058: [0, 0, 0, 0],
    920100: [920102, 0, 0, 0], 920101: [920103, 0, 0, 0],
}

# quest -> ender creature entries (creature_questender snapshot; no GO enders).
ENDERS = {
    80100: [400320],
    81200: [830031], 81201: [830031], 81202: [830032], 81203: [830032],
    81204: [830034], 81205: [830031, 830036], 81206: [830032, 830037],
    81207: [830033, 830038], 81208: [830034, 830039], 81209: [830034, 830039],
    81210: [830036], 81211: [830036], 81212: [830037], 81213: [830037],
    81214: [830039], 81215: [830031, 830036], 81216: [830031, 830036],
    81217: [830032, 830037], 81218: [830032, 830037], 81219: [830033, 830038],
    81220: [830033, 830038], 81221: [830034, 830039], 81222: [830034, 830039],
    81223: [830034, 830039], 81230: [830031, 830036], 81231: [830032, 830037],
    81232: [830033, 830038], 81233: [830033, 830038], 81234: [830034, 830039],
    81235: [830031], 81236: [830031], 81237: [830032], 81238: [830032],
    81239: [830033], 81240: [830033], 81241: [830034], 81242: [830034],
    81250: [830036], 81251: [830037], 81252: [830037], 81253: [830037],
    81254: [830038], 81255: [830038], 81256: [830039], 81257: [830039],
    81260: [830033], 81261: [830034], 81262: [830034],
    81270: [830038], 81271: [830039], 81272: [830039],
    81300: [3743420], 81301: [3643771], 81310: [3606738], 81311: [3612196],
    81312: [3722931], 81313: [3711118], 81314: [3640843], 81315: [3711832],
    82000: [400525], 82001: [400525], 82002: [400525], 82003: [400525],
    82004: [400525], 82005: [400525], 82010: [400526], 82011: [400526],
    82012: [400527], 82013: [400527], 82014: [400526], 82015: [400527],
    83100: [401121], 83101: [401121], 83102: [401121],
    90001: [3999001], 90002: [3904787], 90003: [3999001], 90004: [3999001],
    90005: [3999001], 90006: [3999001], 90007: [3912736], 90008: [3912736],
    90009: [3912736], 90010: [3912736], 90011: [3912736],
    300400: [300030], 300401: [300030], 300402: [300030], 300403: [300030],
    300407: [300030], 300505: [300050], 300507: [300040], 300606: [300050],
    300820: [300071], 300821: [300071], 300822: [300071],
    300954: [300086], 300962: [300086], 300963: [300086], 300964: [300086],
    300966: [300086],
    400340: [400200], 400341: [400200], 400342: [400525], 400343: [400525],
    700101: [700100], 700102: [700100], 700103: [700100], 700104: [700100],
    700201: [700100], 700202: [700100], 700203: [700100], 700204: [700100],
    700701: [700110], 700702: [700110], 700703: [700110], 700704: [700110],
    700705: [700110], 700706: [700110], 700707: [700110], 700708: [700110],
    700709: [700110], 700710: [700110],
    700720: [3999005], 700721: [3999005], 700722: [3999005], 700723: [3999005],
    700724: [3999005], 700725: [3999005], 700726: [3999005],
    700760: [3999002], 700761: [3999002], 700762: [3999002], 700763: [3999002],
    700764: [3999002], 700765: [3999002], 700766: [3999002], 700767: [3999002],
    700768: [3999002],
    700800: [3999007], 700801: [3999007], 700802: [3999007], 700803: [3999007],
    700804: [3999007], 700805: [3999007],
    820000: [820000], 820001: [820000], 820002: [820000], 820003: [820000],
    820005: [820000],
    820010: [820001], 820011: [820001], 820012: [820001], 820013: [820001],
    820020: [820002], 820021: [820002], 820022: [820002], 820023: [820002],
    820031: [820003], 820032: [820003], 820033: [820003], 820034: [820003],
    820035: [820003], 820036: [820003],
    820040: [820004], 820041: [820004], 820042: [820004], 820043: [820004],
    820044: [820004],
    820050: [820005], 820051: [820005],
    820052: [820006], 820053: [820006], 820054: [820006], 820055: [820006],
    820057: [300002], 820058: [300001],
    920100: [900001], 920101: [900001],
}

# entry -> [(map, zoneId, x, y, spawnCount)] -- live creature-table centroids.
# Entries absent here have no static spawns (script-spawned) and resolve via
# HYJAL_1410 below or are dropped.
SPAWNS = {
    6129: [(1, 0, 2622.4, -5404.9, 5)],
    6190: [(1, 0, 3477.1, -4841.2, 28)],
    6348: [(1, 0, 4239.5, -7506.1, 18)],
    11467: [(429, 0, 128.6, 561.8, 1)],
    15689: [(532, 0, -11134.0, -1582.8, 1)],
    16408: [(532, 0, -10940.2, -1975.4, 4)],
    18311: [(557, 0, -109.5, -72.9, 14)],
    18312: [(557, 0, -326.8, -40.1, 13)],
    18313: [(557, 0, -131.7, -173.3, 19)],
    18314: [(557, 0, -373.8, -137.8, 7)],
    18373: [(558, 0, 68.1, -387.8, 1)],
    18472: [(556, 3791, -144.8, 173.6, 1)],
    18708: [(555, 3789, -157.9, -497.3, 1)],
    18956: [(556, 3791, -160.8, 157.0, 1)],
    26723: [(576, 0, 301.5, -5.5, 1)],
    27447: [(578, 0, 1285.6, 1070.4, 1)],
    27641: [(578, 0, 1056.6, 1047.6, 10)],
    27655: [(578, 0, 1177.5, 937.7, 1)],
    27656: [(578, 0, 1077.0, 1086.2, 1)],
    29306: [(604, 0, 1914.8, 743.7, 1)],
    29517: [(571, 0, 7403.2, 4208.0, 2)],
    29518: [(571, 0, 6832.9, -1372.3, 1)],
    29770: [(571, 0, 8402.5, 2824.4, 1)],
    41376: [(669, 5094, -104.7, 20.6, 1)],
    41378: [(669, 5094, -105.8, -462.6, 1)],
    41442: [(669, 5094, 0.0, 0.0, 0)],
    41570: [(669, 5094, -302.5, -31.7, 1)],
    42180: [(669, 5094, 0.0, 0.0, 0)],
    42362: [(669, 5094, -303.4, -50.0, 2)],
    42649: [(669, 5094, -328.4, -88.0, 1)],
    42800: [(669, 5094, -325.1, -347.4, 2)],
    43125: [(669, 5094, 128.3, -180.8, 1)],
    43126: [(669, 5094, 154.1, -258.3, 1)],
    43127: [(669, 5094, 140.3, -266.6, 1)],
    43128: [(669, 5094, 141.7, -183.5, 1)],
    43296: [(669, 5094, -104.7, 20.6, 1)],
    44202: [(669, 5094, -114.4, 43.2, 1)],
    300001: [(37, 0, 90.9, 1017.6, 1)],
    300002: [(37, 0, 150.3, 1000.1, 1)],
    400200: [(1405, 0, 5750.0, 1288.7, 1)],
    400320: [(1405, 0, 5824.2, 1544.6, 1)],
    400525: [(1405, 0, 6368.8, 1076.1, 1)],
    400526: [(1405, 0, 6217.6, 1049.2, 1)],
    400527: [(1405, 0, 6226.1, 1112.0, 1)],
    401121: [(1405, 0, 6430.5, 1367.8, 1)],
    700110: [(669, 0, -350.0, -224.3, 1)],
    820002: [(530, 0, -3381.6, 5161.7, 1)],
    820003: [(571, 0, 3874.1, 6988.5, 1)],
    820005: [(530, 0, -3337.9, 4703.5, 1)],
    820006: [(530, 0, -3597.0, 4920.5, 1)],
    900001: [(745, 0, 901.5, -2560.0, 1)],
    3606738: [(750, 4931, 2781.2, -433.0, 1)],
    3612196: [(750, 4931, 2341.9, -2567.0, 1)],
    3640843: [(750, 4923, 5513.6, -3608.0, 1)],
    3643771: [(750, 4930, 3527.2, -6519.0, 1)],
    3711118: [(750, 4926, 6695.1, -4673.0, 1)],
    3711832: [(750, 4928, 7848.3, -2216.4, 1)],
    3722931: [(750, 4927, 3981.7, -1321.5, 1)],
    3743420: [(750, 4929, 7423.1, -277.9, 1)],
    3904787: [(820, 0, -531.6, 319.0, 1)],
    3912736: [(820, 0, -157.1, 74.1, 1)],
    3912902: [(820, 0, -622.4, -10.4, 1)],
    3999001: [(750, 0, 4249.4, 730.5, 1)],
    3999002: [(750, 0, 6996.9, -2103.8, 1)],
    3999005: [(750, 0, 1707.5, -1289.9, 1)],
    3999007: [(750, 0, 4833.1, -1731.7, 1)],
    4010001: [(819, 0, -7791.2, -3286.5, 1)],
    4010002: [(819, 0, -7580.0, -3457.3, 1)],
    4010003: [(819, 0, -7306.9, -3325.4, 1)],
    4010004: [(819, 0, -7770.6, -3653.0, 1)],
    4010005: [(819, 0, -7927.2, -3810.9, 1)],
    4010006: [(819, 0, -7882.5, -3861.6, 1)],
    4010007: [(819, 0, -7541.0, -3691.2, 1)],
    4020001: [(823, 0, 155.3, 69.0, 1)],
    4020002: [(823, 0, 300.0, -120.0, 1)],
    4020005: [(823, 0, -308.4, -310.3, 1)],
    4020006: [(823, 0, -540.0, -72.0, 1)],
    4020007: [(823, 0, -716.3, -202.4, 1)],
    4030001: [(824, 0, 2728.5, 2986.1, 1)],
    4030002: [(824, 0, 2950.6, 3103.1, 1)],
}

# Instance map -> outdoor entrance points (AreaTrigger.dbc source positions of
# areatrigger_teleport rows targeting that map). Every point that lands on one
# of these maps is re-anchored to the (averaged) entrance.
ENTRANCES = {
    429: [(1, -3730.5, 934.0), (1, -3981.6, 771.2), (1, -4028.2, 124.0),
          (1, -3837.8, 1250.2), (1, -3742.0, 1249.2), (1, -3520.6, 1068.7)],
    532: [(0, -11101.9, -1998.1), (0, -11041.9, -1995.0)],
    555: [(530, -3656.1, 4943.1)],
    556: [(530, -3362.4, 4650.3)],
    557: [(530, -3068.1, 4942.8)],
    558: [(530, -3361.6, 5236.9)],
    576: [(571, 3902.8, 6985.7)],
    578: [(571, 3869.8, 6984.2)],
    604: [(571, 6700.5, -4666.0), (571, 6976.5, -4396.3)],
}

MICRO_WMA = re.compile(r"\d+_$")

# WMAs never valid as rect-match targets: 606 is stock Hyjal on map 1, a zone
# closed in 3.3.5 whose rect overlaps Azshara/Winterspring spawns.
EXCLUDED_WMA = {606}


def load_wma():
    with open(WMA_DBC, "rb") as f:
        data = f.read()
    magic, records, _fields, recsize, _strsize = struct.unpack_from("<4sIIII", data, 0)
    assert magic == b"WDBC"
    rec_off = 20
    str_off = rec_off + records * recsize
    rows = []
    for i in range(records):
        o = rec_off + i * recsize
        wid, mapid, areaid, name_off = struct.unpack_from("<3iI", data, o)
        left, right, top, bottom = struct.unpack_from("<4f", data, o + 16)
        end = data.index(b"\0", str_off + name_off)
        name = data[str_off + name_off:end].decode("utf-8", "replace")
        rows.append((wid, mapid, areaid, name, left, right, top, bottom))
    return rows


def load_hyjal_1410(needed):
    """Parse the planned map-1410 layout SQL for spawns of `needed` entries."""
    row_re = re.compile(
        r"^\((\d+),\s*(\d+),\s*\d+,\s*\d+,\s*1410,\s*\d+,\s*\d+,\s*[^,]+,\s*[^,]+,"
        r"\s*[^,]+,\s*(-?[\d.]+),\s*(-?[\d.]+),"
    )
    acc = {}
    for fname in ("10_NPCs_Quests.sql", "11_Mini_Dungeons.sql", "12_Extended_Quests.sql"):
        path = os.path.join(OLD_HYJAL_DIR, fname)
        if not os.path.isfile(path):
            continue
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                m = row_re.match(line.strip())
                if not m:
                    continue
                entry = int(m.group(2))
                if entry in needed:
                    acc.setdefault(entry, []).append((float(m.group(3)), float(m.group(4))))
    out = {}
    for entry, pts in acc.items():
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        out[entry] = [(1410, 6100, round(cx, 1), round(cy, 1), len(pts))]
    return out


def resolve_wma(wma_rows, mapid, x, y, zone):
    if zone:
        for wid, m, area, _name, *_rest in wma_rows:
            if m == mapid and area == zone:
                return wid
    best = None
    best_size = None
    for wid, m, area, name, left, right, top, bottom in wma_rows:
        if m != mapid or wid in EXCLUDED_WMA or MICRO_WMA.search(name):
            continue
        if not (bottom <= x <= top and right <= y <= left):
            continue
        size = (top - bottom) * (left - right)
        if best_size is None or size < best_size:
            best, best_size = wid, size
    return best


def resolve_points(wma_rows, entry, drop_log, quest):
    """entry -> [(wma, mapid, x, y)] with instance-entrance re-anchoring."""
    groups = SPAWNS.get(entry)
    if not groups:
        drop_log.append((quest, entry, "no spawn data"))
        return []
    out = []
    for mapid, zone, x, y, n in groups:
        if n == 0:
            drop_log.append((quest, entry, "spawn row without position"))
            continue
        if mapid in ENTRANCES:
            pts = ENTRANCES[mapid]
            emap = pts[0][0]
            ex = sum(p[1] for p in pts) / len(pts)
            ey = sum(p[2] for p in pts) / len(pts)
            mapid, x, y, zone = emap, ex, ey, 0
        wma = resolve_wma(wma_rows, mapid, x, y, zone)
        if wma is None:
            drop_log.append((quest, entry, "map %d has no WorldMapArea" % mapid))
            continue
        out.append((wma, mapid, round(x), round(y)))
    return out


def main():
    wma_rows = load_wma()

    needed_1410 = set()
    for quest, slots in QUESTS.items():
        for e in slots + ENDERS.get(quest, []):
            if e and e not in SPAWNS:
                needed_1410.add(e)
    hyjal = load_hyjal_1410(needed_1410)
    SPAWNS.update(hyjal)

    poi_rows = []     # (quest, id, objIndex, map, wma, x, y)
    skipped = []      # (quest, reason)
    drop_log = []

    for quest in sorted(QUESTS):
        slots = QUESTS[quest]
        rows = []
        next_id = 0

        for entry in ENDERS.get(quest, []):
            for wma, mapid, x, y in resolve_points(wma_rows, entry, drop_log, quest):
                rows.append((quest, next_id, -1, mapid, wma, x, y))
                next_id += 1

        for slot, entry in enumerate(slots):
            if not entry:
                continue
            for wma, mapid, x, y in resolve_points(wma_rows, entry, drop_log, quest):
                rows.append((quest, next_id, slot, mapid, wma, x, y))
                next_id += 1

        if rows:
            poi_rows.extend(rows)
        else:
            skipped.append(quest)

    quest_ids = sorted({r[0] for r in poi_rows})

    lines = []
    lines.append("-- " + "-" * 75)
    lines.append("-- dc_custom_quest_poi_backfill.sql -- GENERATED by generate_custom_quest_pois.py")
    lines.append("-- " + "-" * 75)
    lines.append("-- quest_poi + quest_poi_points for %d custom quests that had none, so the" % len(quest_ids))
    lines.append("-- stock combined world map (POI-driven) could never list them. Turn-in POI")
    lines.append("-- (ObjectiveIndex -1) at the quest ender, objective POIs (0..3) at kill/loot")
    lines.append("-- creature spawn centroids. Instance-map points are anchored at the dungeon")
    lines.append("-- entrance on the outdoor map. Hyjal Frontier rows use the planned map-1410")
    lines.append("-- layout (zone not yet spawned live) -- regenerate when it goes live.")
    lines.append("-- Clients cache POI data per session: relog or /reload after applying.")
    if skipped:
        lines.append("--")
        lines.append("-- %d quests remain without POIs (no resolvable coordinates -- script-only" % len(skipped))
        lines.append("-- NPCs, or maps without a WorldMapArea such as 669/819/820/823/824):")
        for i in range(0, len(skipped), 10):
            lines.append("--   " + ", ".join(str(q) for q in skipped[i:i + 10]))
    lines.append("-- " + "-" * 75)
    lines.append("")

    id_list = ", ".join(str(q) for q in quest_ids)
    lines.append("DELETE FROM `quest_poi` WHERE `QuestID` IN (%s);" % id_list)
    lines.append("DELETE FROM `quest_poi_points` WHERE `QuestID` IN (%s);" % id_list)
    lines.append("")

    lines.append("INSERT INTO `quest_poi` (`QuestID`, `id`, `ObjectiveIndex`, `MapID`, `WorldMapAreaId`, `Floor`, `Priority`, `Flags`, `VerifiedBuild`) VALUES")
    vals = []
    for quest, pid, obj, mapid, wma, _x, _y in poi_rows:
        flags = 1 if obj == -1 else 3
        vals.append("(%d, %d, %d, %d, %d, 0, 0, %d, 0)" % (quest, pid, obj, mapid, wma, flags))
    lines.append(",\n".join(vals) + ";")
    lines.append("")

    lines.append("INSERT INTO `quest_poi_points` (`QuestID`, `Idx1`, `Idx2`, `X`, `Y`, `VerifiedBuild`) VALUES")
    vals = []
    for quest, pid, _obj, _mapid, _wma, x, y in poi_rows:
        vals.append("(%d, %d, 0, %d, %d, 0)" % (quest, pid, x, y))
    lines.append(",\n".join(vals) + ";")
    lines.append("")

    lines.append("-- Verification: every backfilled quest should now have at least one POI row.")
    lines.append("SELECT COUNT(DISTINCT `QuestID`) AS `quests_with_poi` FROM `quest_poi` WHERE `QuestID` IN (%s);" % id_list)

    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print("quests covered : %d" % len(quest_ids))
    print("poi rows       : %d" % len(poi_rows))
    print("quests skipped : %d -> %s" % (len(skipped), skipped))
    print("hyjal-1410 fill: %d entries" % len(hyjal))
    seen = set()
    for quest, entry, why in drop_log:
        key = (entry, why)
        if key not in seen:
            seen.add(key)
            print("dropped: entry %d (%s), first quest %d" % (entry, why, quest))
    print("wrote %s" % OUT)


if __name__ == "__main__":
    main()
