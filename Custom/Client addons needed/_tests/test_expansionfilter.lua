-- Mount/pet expansion filter (DC-Collection/UI/MainFrame.lua).
--
-- Mounts and pets imported from the Ascension client own the id band
-- 350000-359999 (mount spells / pet teaching items; retroport_tools/
-- dc_mount_ascension_pipeline.py and dc_pet_ascension_pipeline.py). They must
-- show under the "Ascension" filter only: not under "WotLK+ (Downports)",
-- which is the retail downport bucket, and not under "Classic - WotLK".
--
-- ToPositiveNumber and the EXPANSION FILTER section are lifted out of
-- MainFrame.lua by pattern (same approach as test_petdrag.lua).

local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local SRC = ROOT .. [[DC-Collection\UI\MainFrame.lua]]

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

_G.DC = {}

local src = assert(io.open(SRC, "r")):read("*a")
local helperStart = assert(src:find("local function ToPositiveNumber", 1, true), "ToPositiveNumber not found")
local helperEnd = assert(src:find("\nend\n", helperStart, true), "ToPositiveNumber end not found")
local filterStart = assert(src:find("DC.WOTLK_MAX_ITEM_ID", 1, true), "EXPANSION FILTER section not found")
local filterEnd = assert(src:find("-- MAIN FRAME CREATION", filterStart, true), "MAIN FRAME CREATION marker not found")

local chunk = src:sub(helperStart, helperEnd + 4) .. src:sub(filterStart, filterEnd - 1)
assert((loadstring or load)(chunk, "expansion_filter_block"))()

local function passes(mode, collType, id, def)
    DC.selectedExpansionFilter = mode
    return DC:EntryPassesExpansionFilter(collType, id, def)
end

-- an option per bucket, offered on both the Mounts and the Pets tab
local ids = {}
for _, e in ipairs(DC.EXPANSION_FILTERS) do
    ids[e.id] = e
end
ok(ids.all and ids.classic and ids.wotlkplus and ids.ascension, "all four filter options exist")
ok(ids.ascension and not ids.ascension.mountsOnly, "Ascension option is no longer restricted to mounts")

local STOCK, RETAIL, ASC_LO, ASC_HI = 458, 303063, 350000, 350409

ok(DC:IsMountAscension(ASC_LO) and DC:IsMountAscension(ASC_HI) and DC:IsMountAscension("350100"),
   "spells 350000..350409 (and string ids) classify as Ascension")
ok(not DC:IsMountAscension(STOCK) and not DC:IsMountAscension(RETAIL) and not DC:IsMountAscension(360000),
   "stock, retail-downport and out-of-band spells are not Ascension")

ok(passes("ascension", "mounts", ASC_LO), "Ascension filter shows an Ascension mount")
ok(not passes("ascension", "mounts", RETAIL), "Ascension filter hides a retail downport")
ok(not passes("ascension", "mounts", STOCK), "Ascension filter hides a stock mount")

ok(not passes("wotlkplus", "mounts", ASC_LO), "WotLK+ (Downports) no longer lists Ascension mounts")
ok(passes("wotlkplus", "mounts", RETAIL), "WotLK+ (Downports) still lists retail downports")
ok(not passes("wotlkplus", "mounts", STOCK), "WotLK+ (Downports) still hides stock mounts")

ok(not passes("classic", "mounts", ASC_LO), "Classic hides Ascension mounts")
ok(passes("classic", "mounts", STOCK), "Classic still shows stock mounts")

ok(passes("all", "mounts", ASC_LO) and passes("all", "mounts", STOCK), "All Expansions shows everything")

-- pets: keyed by teaching-item entry; Ascension pets own items 351000..351155
local PET_STOCK, PET_RETAIL, PET_ASC = 4401, 302000, 351000
ok(DC:IsPetAscension(PET_ASC) and DC:IsPetAscension("351155"), "pet items 351000..351155 classify as Ascension")
ok(not DC:IsPetAscension(PET_STOCK) and not DC:IsPetAscension(PET_RETAIL), "stock and retail-downport pets are not Ascension")
ok(passes("ascension", "pets", PET_ASC), "Ascension filter shows an Ascension pet")
ok(not passes("ascension", "pets", PET_RETAIL) and not passes("ascension", "pets", PET_STOCK),
   "Ascension filter hides stock and retail-downport pets")
ok(not passes("wotlkplus", "pets", PET_ASC), "WotLK+ (Downports) does not list Ascension pets")
ok(passes("wotlkplus", "pets", PET_RETAIL), "pet downports still pass WotLK+")
ok(not passes("classic", "pets", PET_ASC), "Classic hides Ascension pets")
ok(passes("classic", "pets", PET_STOCK), "stock pets still pass Classic")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
