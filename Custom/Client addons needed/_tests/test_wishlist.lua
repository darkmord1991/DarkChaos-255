dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

dofile(ROOT..[[DC-AddonProtocol\DCCompat.lua]])

-- Minimal DC-Collection namespace: only what Wishlist.lua touches.
_G.DCCollection = {
    L = setmetatable({}, {__index = function(_, k) return k end}),
    wishlist = {},
    Print = function(_, m) print("PRINT: "..m) end,
    GetDefinition = function(_, t, id) return {name = "Item "..tostring(id), rarity = 3, icon = "icon", source = "drop"} end,
    FormatSource = function(_, s) return tostring(s) end,
    GetRarityColor = function(_, r) return {r=1, g=0.5, b=0} end,
    RequestRemoveWishlist = function(_, t, id) _G._removed = {t, id} end,
    CreateWishlistUI = function() end,
}
_G.StaticPopupDialogs = {}
_G.YES, _G.NO = "Yes", "No"

dofile(ROOT..[[DC-Collection\Wishlist.lua]])
local DC = _G.DCCollection

-- Stand up the scroll UI the refresh path expects.
local root = CreateFrame("Frame")
local scrollChild = CreateFrame("Frame", nil, root)
DC.WishlistUI = root
root.scrollChild = scrollChild
root.emptyText = scrollChild:CreateFontString()
root.scrollFrame = CreateFrame("Frame", nil, root)
root.Raise = function() end
root:Show()

local function makeWishlist(n)
    local w = {}
    for i = 1, n do
        w[i] = {type = (i % 2 == 0) and "mounts" or "pets", itemId = 1000 + i}
    end
    return w
end

print("== wishlist refresh: frame accumulation ==")
DC.wishlist = makeWishlist(20)
DC:RefreshWishlistUI()
local afterFirst = frameCount
ok(afterFirst > 20, "first refresh built the rows ("..afterFirst.." frames)")

for i = 1, 25 do
    DC.wishlist = makeWishlist(20)
    DC:RefreshWishlistUI()
end
local afterMany = frameCount
ok(afterMany == afterFirst, "25 further refreshes allocated ZERO new frames ("..afterFirst.." -> "..afterMany..")")

print("== growth then shrink ==")
DC.wishlist = makeWishlist(60)
DC:RefreshWishlistUI()
local afterGrow = frameCount
ok(afterGrow > afterMany, "larger list grows the pool on demand ("..afterGrow..")")
DC.wishlist = makeWishlist(5)
DC:RefreshWishlistUI()
ok(frameCount == afterGrow, "shrinking reuses, never reallocates")
local shown = 0
for _ in DC.WishlistUI._rowPool:EnumerateActive() do shown = shown + 1 end
ok(shown == 5, "exactly 5 rows active after shrink (got "..shown..")")

print("== pooled row click reads CURRENT entry ==")
DC.wishlist = {{type = "pets", itemId = 777}}
DC:RefreshWishlistUI()
local firstRow
for f in DC.WishlistUI._rowPool:EnumerateActive() do firstRow = f end
DC.wishlist = {{type = "mounts", itemId = 999}}
DC:RefreshWishlistUI()
firstRow.removeBtn._scripts.OnClick()
ok(_G._removed and _G._removed[2] == 999,
   "reused row removes the entry it currently shows, not the stale one (got "..tostring(_G._removed and _G._removed[2])..")")

print("== empty list ==")
DC.wishlist = {}
DC:RefreshWishlistUI()
local active = 0
for _ in DC.WishlistUI._rowPool:EnumerateActive() do active = active + 1 end
ok(active == 0, "empty wishlist releases every row")
ok(DC.WishlistUI._rowPool:GetNumCreated() == 60, "pool high-water mark stayed at the largest list (60)")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
