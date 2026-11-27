#!/usr/bin/env python3
"""Downport the 185 Cata items map 751 references but 3.3.5 does not have.

WHY THE SOURCE IS THE CLIENT AND NOT A DATABASE
Every server-side option was checked and none has these items:
    cata_world          -- has no item_template at all
    nelt_world          -- has item_template, but only 2 of the 185
    cata_hotfix         -- item / item_sparse are HOTFIX tables, 208 rows, 1 of the 185
    bfa_hotfixes        -- same shape, 147 rows, 0 of the 185
So the data comes from the Cata 4.3.4 client's own DB2s, which do have all of them:
    DBFilesClient\\Item.db2          64,771 records, 8 fields   -- the "physical" half
    DBFilesClient\\Item-sparse.db2   54,082 records, 133 fields -- everything else

READING WDB2 IS NOT READING WDBC
The header is 48 bytes, not 20, and when maxId != 0 there is an index block between
header and records -- (maxId-minId+1) uint32 offsets then the same count of uint16
string lengths. Item-sparse has one (minId 17, maxId 78930); Item.db2 does not.
Skipping it reads records at the wrong offset and yields plausible-looking garbage
rather than an error. String offsets are relative to the START OF THE STRING BLOCK,
not the file -- confirmed because sb_off + stringTableSize == file length exactly.

THE FIELD LAYOUT WAS DERIVED AND VERIFIED, NOT ASSUMED
No 4.3.4 definition file was available locally (the ItemSparse CSVs on disk are
retail-era). The layout below was pinned by probing known items and confirmed by
three independent facts:
  * field 99 on item 6948 decodes to "Hearthstone", and field 98 is 1 = bind-on-pickup
  * field 93 on the same row is 1800000 -- the Hearthstone's 30-minute cooldown,
    landing exactly where SpellCategoryCooldown[0] is predicted to be
  * Material agrees between Item.db2 field 4 and Item-sparse field 109 on every
    sample checked -- two independently-derived layouts pointing at the same value

WHAT CATA'S item-sparse DOES NOT CONTAIN: armor, weapon damage and durability. 4.3.4 computes
both at runtime from ItemArmorQuality/Total/Shield and ItemDamage*.dbc using item
level, quality and slot. There are **no weapons at all** in this set, so damage is
moot. Armor matters for 24 cloaks and 2 chests, and rather than port Cata's scaling
curve -- which is not the curve a WotLK client and its gear sit on -- the emitted SQL
derives it from OUR OWN stock items with the same class/subclass/slot/quality/ilvl.
Verified that this is deterministic: across the relevant range every such group in
item_template has min(armor) == max(armor).

Emits Plaguelands/94_item_template.sql. Nothing is applied and no client file is
touched; the 77 missing ItemDisplayInfo rows are reported for a separate pass.
"""
import ctypes, os, sys, glob, struct, csv
from ctypes import wintypes

sys.path.insert(0, r"K:/Dark-Chaos/wow.export-main/tools")
from mpq_stormlib_locate import load, open_archive

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CATA = r"K:/UntouchedClients/Cata/Data"
OUT = os.path.join(ROOT, "Custom feature SQLs", "worlddb", "Plaguelands", "94_item_template.sql")
OUT_DBC = os.path.join(ROOT, "Custom feature SQLs", "worlddb", "Plaguelands", "95_item_dbc.sql")
CSVDIR = os.path.join(ROOT, "CSV DBC")
IDS_FILE = os.environ.get("ITEM_IDS", os.path.join(os.environ.get("SCRATCH", "."), "missing_items.txt"))


class Wdb2:
    def __init__(self, data):
        if data[:4] != b"WDB2":
            raise ValueError("not WDB2: %r" % data[:4])
        (self.rc, self.fc, self.rs, self.sts, self.hash, self.build,
         self.ts, self.minId, self.maxId, self.locale, self.copy) = struct.unpack_from("<11I", data, 4)
        off = 48
        if self.maxId:                       # index block -- see the note above
            n = self.maxId - self.minId + 1
            off += n * 4 + n * 2
        self.base = off
        self.sb = off + self.rc * self.rs
        assert self.sb + self.sts == len(data), "string block does not reach EOF -- layout wrong"
        self.d = data
        self.rows = {}
        for i in range(self.rc):
            self.rows[struct.unpack_from("<I", data, self.base + i * self.rs)[0]] = i

    def f(self, rid):
        i = self.rows[rid]
        r = self.d[self.base + i * self.rs: self.base + (i + 1) * self.rs]
        return [struct.unpack_from("<I", r, k * 4)[0] for k in range(self.fc)]

    def s(self, off, lim=512):
        if off <= 0:
            return ""
        p = self.sb + off
        if p >= len(self.d):
            return ""
        e = self.d.find(b"\0", p)
        return self.d[p:e].decode("utf-8", "replace") if 0 <= e - p <= lim else ""


def i32(v):
    return struct.unpack("<i", struct.pack("<I", v))[0]


def f32(v):
    return struct.unpack("<f", struct.pack("<I", v))[0]


def read_client(path):
    dll = load()
    dll.SFileReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                  ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    dll.SFileGetFileSize.argtypes = [ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
    dll.SFileGetFileSize.restype = wintypes.DWORD
    best = None
    arcs = [a for a in sorted(glob.glob(CATA + "/*.MPQ")) + sorted(glob.glob(CATA + "/enUS/*.MPQ"))
            if "wow-update" not in os.path.basename(a).lower()]   # PTCH deltas, not files
    for a in arcs:
        h = open_archive(dll, a)
        if not h:
            continue
        fh = ctypes.c_void_p()
        ctypes.set_last_error(0)
        dll.SFileOpenFileEx(h, path.encode(), 0, ctypes.byref(fh))
        if ctypes.get_last_error() != 0 or not fh:
            continue
        sz = dll.SFileGetFileSize(fh, None)
        buf = ctypes.create_string_buffer(sz)
        got = wintypes.DWORD(0)
        dll.SFileReadFile(fh, buf, sz, ctypes.byref(got), None)
        d = buf.raw[:got.value]
        dll.SFileCloseFile(fh)
        if d[:4] in (b"WDB2", b"WDBC"):
            best = d
    return best


# ---- Item-sparse 4.3.4 field map (see header for how this was pinned) -------
SP = dict(Quality=1, Flags=2, Flags2=3, BuyCount=6, BuyPrice=7, SellPrice=8, InventoryType=9,
          AllowableClass=10, AllowableRace=11, ItemLevel=12, RequiredLevel=13, RequiredSkill=14,
          RequiredSkillRank=15, RequiredSpell=16, RequiredHonorRank=17, RequiredCityRank=18,
          RequiredRepFaction=19, RequiredRepRank=20, MaxCount=21, Stackable=22, ContainerSlots=23,
          StatType=24, StatValue=34, ScalingStatDistribution=64, DamageType=65, Delay=66,
          RangedModRange=67, SpellId=68, SpellTrigger=73, SpellCharges=78, SpellCooldown=83,
          SpellCategory=88, SpellCategoryCooldown=93, Bonding=98, Name=99, Description=103,
          PageText=104, LanguageID=105, PageMaterial=106, StartQuest=107, LockID=108, Material=109,
          Sheath=110, RandomProperty=111, RandomSuffix=112, ItemSet=113,
          # NO MaxDurability -- it does not exist in Item-sparse (see header). Assuming
          # one here at 114 shifted EVERY field below it by one, which shipped Area's
          # value as MaxDurability and a bitmask as Map (MySQL 1264 out-of-range).
          Area=114, Map=115, BagFamily=116, TotemCategory=117, SocketColor=118, SocketContent=121,
          SocketBonus=124, GemProperties=125, ArmorDamageModifier=126, Duration=127,
          ItemLimitCategory=128, HolidayId=129)

COLS = ["entry","class","subclass","SoundOverrideSubclass","name","displayid","Quality","Flags",
    "FlagsExtra","BuyCount","BuyPrice","SellPrice","InventoryType","AllowableClass","AllowableRace",
    "ItemLevel","RequiredLevel","RequiredSkill","RequiredSkillRank","requiredspell","requiredhonorrank",
    "RequiredCityRank","RequiredReputationFaction","RequiredReputationRank","maxcount","stackable",
    "ContainerSlots"] + \
    [f"stat_{a}{n}" for n in range(1, 11) for a in ("type", "value")] + \
    ["ScalingStatDistribution","ScalingStatValue","dmg_min1","dmg_max1","dmg_type1","dmg_min2",
     "dmg_max2","dmg_type2","armor","holy_res","fire_res","nature_res","frost_res","shadow_res",
     "arcane_res","delay","ammo_type","RangedModRange"] + \
    [f"spell{a}_{n}" for n in range(1, 6)
     for a in ("id", "trigger", "charges", "ppmRate", "cooldown", "category", "categorycooldown")] + \
    ["bonding","description","PageText","LanguageID","PageMaterial","startquest","lockid","Material",
     "sheath","RandomProperty","RandomSuffix","block","itemset","MaxDurability","area","Map",
     "BagFamily","TotemCategory","socketColor_1","socketContent_1","socketColor_2","socketContent_2",
     "socketColor_3","socketContent_3","socketBonus","GemProperties","RequiredDisenchantSkill",
     "ArmorDamageModifier","duration","ItemLimitCategory","HolidayId","ScriptName","DisenchantID",
     "FoodType","minMoneyLoot","maxMoneyLoot","flagsCustom","VerifiedBuild"]
# our stat columns are stat_type1..10 / stat_value1..10, interleaved
COLS[27:47] = [f"stat_{a}{n}" for n in range(1, 11) for a in ("type", "value")]


# ---- armor / durability, resolved from OUR OWN stock curve -------------------
# Cata's Item-sparse has neither (4.3.4 computes both from scaling DBCs), so they
# are looked up from stock 3.3.5 items with the same class/subclass/slot/quality at
# the nearest item level. Verified deterministic first: min(col)==max(col) for every
# group in range, so this is a lookup and not an average.
#
# BAKED AS LITERALS ON PURPOSE. The obvious spelling -- an UPDATE with a correlated
# subquery over item_template -- is rejected by MySQL with 1093 'You can't specify
# target table for update in FROM clause'. Resolving the 23 combos up front also
# makes the numbers reviewable in the diff instead of depending on DB state at
# apply time. Regenerate with tools/probe (see 00_EXTENSION_PLAN.md 5r) if the
# stock item set ever changes.
#
# key: (class, subclass, InventoryType, Quality, ItemLevel) -> (armor, MaxDurability)
# A combo absent here, or present with 0, genuinely has no stock donor: necks and
# rings carry no armor in 3.3.5, subclass-0 cloaks have no precedent, and heirlooms
# (quality 7) derive theirs from ScalingStatDistribution.
CURVE = {
    (4, 1, 16, 1,  8): (7,  0),
    (4, 1, 16, 2, 11): (11, 0),
    (4, 1, 16, 2, 15): (14, 0),
    (4, 1, 16, 2, 16): (15, 0),
    (4, 1, 16, 2, 21): (17, 0),
    (4, 1, 16, 2, 24): (19, 0),
    (4, 1, 16, 2, 27): (20, 0),
    (4, 1, 16, 2, 28): (21, 0),
    (4, 1, 16, 2, 36): (24, 0),
    (4, 1, 16, 3, 24): (21, 0),
    (4, 1, 16, 3, 28): (23, 0),
    (4, 1, 16, 3, 40): (29, 0),
    (4, 2,  5, 2, 33): (98, 85),
}
# Slots that carry armor at all. Rings (11) and necks (2) are excluded deliberately:
# a handful of stock rings do carry a stray armor value and copying one would invent
# armor on a slot that has none.
ARMOR_SLOTS = {1, 3, 5, 6, 7, 8, 9, 10, 14, 16, 20}


# ---- column range guard ------------------------------------------------------
# item_template column types, so a mis-derived field cannot ship a value the column
# cannot hold. This exists because it already happened: assuming a MaxDurability
# field shifted the tail by one and sent a BagFamily bitmask (32768) into `Map`,
# a signed smallint -- MySQL 1264 at apply time, after the file had been handed over.
COLTYPE = {
    "AllowableClass": "int",
    "AllowableRace": "int",
    "BagFamily": "int",
    "BuyCount": "tinyint unsigned",
    "BuyPrice": "bigint",
    "ContainerSlots": "tinyint unsigned",
    "DisenchantID": "int unsigned",
    "Flags": "int unsigned",
    "FlagsExtra": "int unsigned",
    "FoodType": "tinyint unsigned",
    "GemProperties": "int",
    "HolidayId": "int unsigned",
    "InventoryType": "tinyint unsigned",
    "ItemLevel": "smallint unsigned",
    "ItemLimitCategory": "smallint",
    "LanguageID": "tinyint unsigned",
    "Map": "smallint",
    "Material": "tinyint",
    "MaxDurability": "smallint unsigned",
    "PageMaterial": "tinyint unsigned",
    "PageText": "int unsigned",
    "Quality": "tinyint unsigned",
    "RandomProperty": "int",
    "RandomSuffix": "int unsigned",
    "RequiredCityRank": "int unsigned",
    "RequiredDisenchantSkill": "smallint",
    "RequiredLevel": "tinyint unsigned",
    "RequiredReputationFaction": "smallint unsigned",
    "RequiredReputationRank": "smallint unsigned",
    "RequiredSkill": "smallint unsigned",
    "RequiredSkillRank": "smallint unsigned",
    "ScalingStatDistribution": "smallint",
    "ScalingStatValue": "int unsigned",
    "SellPrice": "int unsigned",
    "SoundOverrideSubclass": "tinyint",
    "TotemCategory": "int",
    "VerifiedBuild": "int",
    "ammo_type": "tinyint unsigned",
    "arcane_res": "smallint",
    "area": "int unsigned",
    "armor": "int unsigned",
    "block": "int unsigned",
    "bonding": "tinyint unsigned",
    "class": "tinyint unsigned",
    "delay": "smallint unsigned",
    "displayid": "int unsigned",
    "dmg_type1": "tinyint unsigned",
    "dmg_type2": "tinyint unsigned",
    "duration": "int unsigned",
    "entry": "int unsigned",
    "fire_res": "smallint",
    "flagsCustom": "int unsigned",
    "frost_res": "smallint",
    "holy_res": "smallint",
    "itemset": "int unsigned",
    "lockid": "int unsigned",
    "maxMoneyLoot": "int unsigned",
    "maxcount": "int",
    "minMoneyLoot": "int unsigned",
    "nature_res": "smallint",
    "requiredhonorrank": "int unsigned",
    "requiredspell": "int unsigned",
    "shadow_res": "smallint",
    "sheath": "tinyint unsigned",
    "socketBonus": "int",
    "socketColor_1": "tinyint",
    "socketColor_2": "tinyint",
    "socketColor_3": "tinyint",
    "socketContent_1": "int",
    "socketContent_2": "int",
    "socketContent_3": "int",
    "spellcategory_1": "smallint unsigned",
    "spellcategory_2": "smallint unsigned",
    "spellcategory_3": "smallint unsigned",
    "spellcategory_4": "smallint unsigned",
    "spellcategory_5": "smallint unsigned",
    "spellcategorycooldown_1": "int",
    "spellcategorycooldown_2": "int",
    "spellcategorycooldown_3": "int",
    "spellcategorycooldown_4": "int",
    "spellcategorycooldown_5": "int",
    "spellcharges_1": "smallint",
    "spellcharges_2": "smallint",
    "spellcharges_3": "smallint",
    "spellcharges_4": "smallint",
    "spellcharges_5": "smallint",
    "spellcooldown_1": "int",
    "spellcooldown_2": "int",
    "spellcooldown_3": "int",
    "spellcooldown_4": "int",
    "spellcooldown_5": "int",
    "spellid_1": "int",
    "spellid_2": "int",
    "spellid_3": "int",
    "spellid_4": "int",
    "spellid_5": "int",
    "spelltrigger_1": "tinyint unsigned",
    "spelltrigger_2": "tinyint unsigned",
    "spelltrigger_3": "tinyint unsigned",
    "spelltrigger_4": "tinyint unsigned",
    "spelltrigger_5": "tinyint unsigned",
    "stackable": "int",
    "startquest": "int unsigned",
    "stat_type1": "tinyint unsigned",
    "stat_type10": "tinyint unsigned",
    "stat_type2": "tinyint unsigned",
    "stat_type3": "tinyint unsigned",
    "stat_type4": "tinyint unsigned",
    "stat_type5": "tinyint unsigned",
    "stat_type6": "tinyint unsigned",
    "stat_type7": "tinyint unsigned",
    "stat_type8": "tinyint unsigned",
    "stat_type9": "tinyint unsigned",
    "stat_value1": "int",
    "stat_value10": "int",
    "stat_value2": "int",
    "stat_value3": "int",
    "stat_value4": "int",
    "stat_value5": "int",
    "stat_value6": "int",
    "stat_value7": "int",
    "stat_value8": "int",
    "stat_value9": "int",
    "subclass": "tinyint unsigned",
}
LIMITS = {"tinyint": (-128, 127), "tinyint unsigned": (0, 255),
          "smallint": (-32768, 32767), "smallint unsigned": (0, 65535),
          "int": (-2147483648, 2147483647), "int unsigned": (0, 4294967295),
          "bigint": (-2**63, 2**63 - 1)}


def check_ranges(cols, rows):
    """Abort rather than emit a row MySQL will reject with 1264."""
    bad = []
    for r in rows:
        for c, v in zip(cols, r):
            lim = LIMITS.get(COLTYPE.get(c, ''))
            if lim and isinstance(v, int) and not (lim[0] <= v <= lim[1]):
                bad.append((r[0], c, COLTYPE[c], v))
    if bad:
        for b in bad[:20]:
            print("  OUT OF RANGE entry=%s %s (%s) = %s" % b)
        raise SystemExit("%d value(s) exceed their column type -- refusing to write" % len(bad))


def q(v):
    if isinstance(v, str):
        return "'" + v.replace("\\", "\\\\").replace("'", "''") + "'"
    if isinstance(v, float):
        return "0" if v == 0 else repr(round(v, 6))
    return str(v)


def main():
    ids = sorted({int(x) for x in open(IDS_FILE).read().split()})
    it = Wdb2(read_client("DBFilesClient\\Item.db2"))
    sp = Wdb2(read_client("DBFilesClient\\Item-sparse.db2"))
    print(f"Item.db2 {it.rc} recs (build {it.build})   Item-sparse {sp.rc} recs, {sp.fc} fields")

    rows, skipped = [], []
    for e in ids:
        if e not in it.rows:
            skipped.append((e, "absent from Item.db2"))
            continue
        if e not in sp.rows:
            skipped.append((e, "absent from Item-sparse"))
            continue
        I = it.f(e)
        F = sp.f(e)
        g = lambda k: F[SP[k]]
        _ck = (I[1], I[2], I[6], g("Quality"), g("ItemLevel"))
        _armor, _dur = CURVE.get(_ck, (0, 0))
        if I[6] not in ARMOR_SLOTS:
            _armor = 0
        v = [e, I[1], I[2], i32(I[3]), sp.s(g("Name")), I[5], g("Quality"), g("Flags"), g("Flags2"),
             g("BuyCount"), g("BuyPrice"), g("SellPrice"), I[6], i32(g("AllowableClass")),
             i32(g("AllowableRace")), g("ItemLevel"), g("RequiredLevel"), g("RequiredSkill"),
             g("RequiredSkillRank"), g("RequiredSpell"), g("RequiredHonorRank"), g("RequiredCityRank"),
             g("RequiredRepFaction"), g("RequiredRepRank"), g("MaxCount"), g("Stackable"),
             g("ContainerSlots")]
        for n in range(10):                      # stat type -1 means "no stat" -> 0
            st = i32(F[SP["StatType"] + n])
            v += [st if st > 0 else 0, i32(F[SP["StatValue"] + n]) if st > 0 else 0]
        v += [g("ScalingStatDistribution"), 0,   # ScalingStatValue: no Cata equivalent
              0.0, 0.0, g("DamageType"), 0.0, 0.0, 0,   # damage: none of these 185 are weapons
              _armor,                             # from CURVE -- see the table above
              0, 0, 0, 0, 0, 0,                   # resistances: Cata dropped per-item resists
              g("Delay"), 0, f32(g("RangedModRange"))]
        for n in range(5):
            v += [F[SP["SpellId"] + n], F[SP["SpellTrigger"] + n], i32(F[SP["SpellCharges"] + n]),
                  0.0, i32(F[SP["SpellCooldown"] + n]), F[SP["SpellCategory"] + n],
                  i32(F[SP["SpellCategoryCooldown"] + n])]
        v += [g("Bonding"), sp.s(g("Description")), g("PageText"), g("LanguageID"), g("PageMaterial"),
              g("StartQuest"), g("LockID"), i32(g("Material")), g("Sheath"), g("RandomProperty"),
              g("RandomSuffix"), 0, g("ItemSet"), _dur, g("Area"), g("Map"),   # MaxDurability from CURVE
              g("BagFamily"), g("TotemCategory")]
        for n in range(3):
            v += [F[SP["SocketColor"] + n], F[SP["SocketContent"] + n]]
        v += [g("SocketBonus"), g("GemProperties"), -1, f32(g("ArmorDamageModifier")),
              g("Duration"), g("ItemLimitCategory"), g("HolidayId"), "", 0, 0, 0, 0, 0, 0]
        assert len(v) == len(COLS), f"{e}: built {len(v)} values for {len(COLS)} columns"
        rows.append(v)

    # ---- client-side gap report --------------------------------------------
    disp = {r[0]: r[5] for r in rows}
    have = set()
    p = os.path.join(CSVDIR, "ItemDisplayInfo.csv")
    if os.path.exists(p):
        have = {int(x["ID"]) for x in csv.DictReader(open(p, encoding="utf-8-sig"))}
    need = sorted({d for d in disp.values() if d})
    miss = [d for d in need if d not in have]

    idlist = ",".join(str(r[0]) for r in rows)
    from collections import Counter
    c = Counter(r[1] for r in rows)
    CLS = {0: "Consumable", 1: "Container", 4: "Armor", 7: "TradeGoods", 9: "Recipe", 12: "Quest", 15: "Misc"}
    check_ranges(COLS, rows)
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("-- 94_item_template.sql -- map 751 Lordaeron extension, DB step 33.\n--\n")
        w("-- GENERATED by Custom/Documentation/scripts/gen_map751_item_template.py --\n")
        w("-- do not hand-edit; re-run the generator instead.\n--\n")
        w("-- The %d Cata items the map-751 content references and 3.3.5 does not have.\n" % len(rows))
        w("-- They are the cause of ~200 boot lines of the form\n")
        w("--   \"Quest 26240 has `StartItem` = 57920 but item with entry 57920 does not\n")
        w("--    exist, quest can't be done\"\n")
        w("-- and of the 67 vendor rows 91_ had to drop.\n--\n")
        w("-- SOURCE: the Cata 4.3.4 CLIENT, because no database has them -- cata_world has\n")
        w("-- no item_template, nelt_world has 2 of the 185, and cata_hotfix/bfa_hotfixes are\n")
        w("-- hotfix-only tables holding 1 and 0 of them. Item.db2 + Item-sparse.db2 have all.\n--\n")
        w("-- The Item-sparse field layout was derived by probing and confirmed three ways --\n")
        w("-- see the generator header. Two consequences worth knowing:\n")
        w("--   * Cata's item-sparse carries NO armor, NO weapon damage and NO durability;\n")
        w("--     4.3.4 computes them from scaling DBCs. None of these 185 is a weapon, so\n")
        w("--     damage is moot. Armor and durability are resolved from OUR OWN stock\n")
        w("--     curve and BAKED IN as literals -- the natural UPDATE spelling is rejected\n")
        w("--     by MySQL 1093. The durability gap was PROVEN by probing all 133 fields,\n")
        w("--     not assumed -- and assuming a field for it there shifted every column\n")
        w("--     below by one, which is what made Map arrive as a bitmask (MySQL 1264).\n")
        w("--   * Material: the client writes 0 where 3.3.5 conventionally writes -1. Copied\n")
        w("--     verbatim rather than remapped -- across 149 items present in both versions\n")
        w("--     the live rows use BOTH 0 and -1 for the same client value, so there is no\n")
        w("--     safe rule. Material only selects the pickup/drop sound.\n")
        w("--   * Cata dropped per-item resistances, so holy_res..arcane_res are 0. That is\n")
        w("--     correct for this era, not a gap.\n--\n")
        w("-- Class mix: " + ", ".join("%s %s" % (v, CLS.get(k, k)) for k, v in sorted(c.items(), key=lambda kv: -kv[1])) + ".\n")
        w("-- CLIENT-SIDE HALF, NOT DONE HERE: %d of the %d distinct displayids these items\n" % (len(miss), len(need)))
        w("-- use are missing from our ItemDisplayInfo, so those items show a default icon\n")
        w("-- until the display rows and their icon BLPs are ported. The server side below is\n")
        w("-- independent of that -- the quests become completable either way.\n")
        if skipped:
            w("--\n-- NOT BUILT (%d): %s\n" % (len(skipped), "; ".join(f"{e} {r}" for e, r in skipped)))
        w("\nDELETE FROM `item_template` WHERE `entry` IN (%s);\n\n" % idlist)
        w("INSERT INTO `item_template` (%s) VALUES\n" % ", ".join("`%s`" % c for c in COLS))
        w(",\n".join("(" + ", ".join(q(x) for x in r) + ")" for r in rows) + ";\n")
        w("""
-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
SELECT 'items added (want %d)' AS what, COUNT(*) AS n FROM `item_template` WHERE `entry` IN (%s)
UNION ALL SELECT 'with an empty name (want 0)', COUNT(*) FROM `item_template`
  WHERE `entry` IN (%s) AND (`name` IS NULL OR `name` = '')
UNION ALL SELECT 'armour-slot pieces that got an armor value', COUNT(*) FROM `item_template`
  WHERE `entry` IN (%s) AND `class` = 4 AND `InventoryType` IN (1,3,5,6,7,8,9,10,14,16,20) AND `armor` > 0
UNION ALL SELECT 'chest/weapon pieces that got a durability value (want 2)', COUNT(*)
  FROM `item_template` WHERE `entry` IN (%s) AND `class` IN (2,4) AND `MaxDurability` > 0
UNION ALL SELECT 'quest refs still pointing at a missing item (want 0)', COUNT(*) FROM (
    SELECT `StartItem` AS i FROM `quest_template` WHERE `StartItem` > 0
    UNION ALL SELECT `RequiredItemId1` FROM `quest_template` WHERE `RequiredItemId1` > 0
    UNION ALL SELECT `RequiredItemId2` FROM `quest_template` WHERE `RequiredItemId2` > 0
    UNION ALL SELECT `RequiredItemId3` FROM `quest_template` WHERE `RequiredItemId3` > 0
    UNION ALL SELECT `ItemDrop1` FROM `quest_template` WHERE `ItemDrop1` > 0
    UNION ALL SELECT `RewardItem1` FROM `quest_template` WHERE `RewardItem1` > 0
    UNION ALL SELECT `RewardChoiceItemID1` FROM `quest_template` WHERE `RewardChoiceItemID1` > 0
  ) z WHERE NOT EXISTS (SELECT 1 FROM `item_template` i WHERE i.`entry` = z.i);

-- must be empty: an item whose spell trigger references a spell we do not have --
-- the core logs "Item (Entry: N) has wrong spellid" and drops the effect
SELECT 'PROBLEM: item spell missing from spell_dbc' AS problem, i.`entry`, i.`name`, z.s
FROM `item_template` i
JOIN (SELECT `entry` e, `spellid_1` s FROM `item_template` WHERE `spellid_1` > 0
      UNION ALL SELECT `entry`, `spellid_2` FROM `item_template` WHERE `spellid_2` > 0
      UNION ALL SELECT `entry`, `spellid_3` FROM `item_template` WHERE `spellid_3` > 0) z
  ON z.e = i.`entry`
WHERE i.`entry` IN (%s)
  AND z.s >= 70000
  AND NOT EXISTS (SELECT 1 FROM `spell_dbc` d WHERE d.`ID` = z.s);
""" % (len(rows), idlist, idlist, idlist, idlist, idlist))

    print(f"\nwrote {OUT}")
    print(f"  item_template rows : {len(rows)} x {len(COLS)} columns")
    if skipped:
        print(f"  NOT BUILT          : {skipped}")
    print(f"  displayids needed  : {len(need)}   missing from our ItemDisplayInfo: {len(miss)}")

    # ---- 95_: the server-side Item.dbc half -------------------------------
    # item_dbc is a runtime overlay merged over data/dbc/Item.dbc at load, exactly
    # like spell_dbc. So the server can be taught these items in SQL, with no DBC
    # rebuild and no risk of plain-copying over a merged server file.
    # Its 8 columns ARE Item.dbc's 8 fields, and Item.db2 carries the same eight,
    # so this is a straight copy -- no derivation and nothing to get wrong.
    drows = []
    for e in ids:
        if e not in it.rows or e not in sp.rows:
            continue
        I = it.f(e)
        drows.append((e, I[1], I[2], i32(I[3]), i32(I[4]), I[5], I[6], I[7]))
    dids = ','.join(str(r[0]) for r in drows)
    with open(OUT_DBC, "w", encoding="utf-8", newline="\n") as fh:
        w = fh.write
        w("-- 95_item_dbc.sql -- map 751 Lordaeron extension, DB step 34.\n--\n")
        w("-- GENERATED by Custom/Documentation/scripts/gen_map751_item_template.py.\n--\n")
        w("-- The Item.dbc half of the %d items 94_ adds to item_template.\n" % len(drows))
        w("--\n")
        w("-- WHY THIS IS SQL AND NOT A DBC REBUILD: item_dbc is a runtime overlay merged\n")
        w("-- over data/dbc/Item.dbc at startup, the same mechanism spell_dbc uses. Adding\n")
        w("-- rows here teaches the SERVER these items without touching the file -- which\n")
        w("-- also avoids the standing trap that the server Item.dbc must never be plain-\n")
        w("-- copied from the client one.\n--\n")
        w("-- THE CLIENT HALF IS STILL SEPARATE. The client reads its own Item.dbc from\n")
        w("-- patch-4.MPQ, and ItemDisplayInfo for the icon. 77 of the 142 displayids these\n")
        w("-- items use have no ItemDisplayInfo row yet, so those show a default icon until\n")
        w("-- that pass is done. Neither blocks quest completion.\n--\n")
        w("-- Columns are copied verbatim from Item.db2, whose 8 fields are Item.dbc's 8.\n")
        w("\nDELETE FROM `item_dbc` WHERE `ID` IN (%s);\n\n" % dids)
        w("INSERT INTO `item_dbc` (`ID`, `ClassID`, `SubclassID`, `Sound_Override_Subclassid`, "
          "`Material`, `DisplayInfoID`, `InventoryType`, `SheatheType`) VALUES\n")
        w(",\n".join("(%d, %d, %d, %d, %d, %d, %d, %d)" % r for r in drows) + ";\n")
        w("\n-- Verification\n")
        w("SELECT 'item_dbc rows added (want %d)' AS what, COUNT(*) AS n\n" % len(drows))
        w("  FROM `item_dbc` WHERE `ID` IN (%s)\n" % dids)
        w("UNION ALL SELECT '  ...with a displayid of 0 (they would show no icon)', COUNT(*)\n")
        w("  FROM `item_dbc` WHERE `ID` IN (%s) AND `DisplayInfoID` = 0;\n" % dids)
        w("\n-- must be empty: an item_template row 94_ added with no item_dbc row\n")
        w("SELECT 'PROBLEM: item_template row without an item_dbc row' AS problem, i.`entry`, i.`name`\n")
        w("FROM `item_template` i WHERE i.`entry` IN (%s)\n" % dids)
        w("  AND NOT EXISTS (SELECT 1 FROM `item_dbc` d WHERE d.`ID` = i.`entry`);\n")
    print("  also wrote %s (%d item_dbc rows)" % (OUT_DBC, len(drows)))

    print("  class mix          : " + ", ".join(f"{CLS.get(k,k)}={v}" for k, v in sorted(c.items(), key=lambda kv: -kv[1])))


main()
