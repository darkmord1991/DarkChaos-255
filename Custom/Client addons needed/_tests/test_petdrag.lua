-- Action-bar pickup for collection items (DC-Collection/UI/MainFrame.lua).
--
-- Pets could not be dragged onto an action bar the way mounts could: the picker
-- hard-rejected anything that was not a mount. This pins the pet path and, just
-- as importantly, pins that the mount path did not change.
--
-- The helper block is lifted out of MainFrame.lua by pattern rather than by line
-- number, so this keeps working when the file moves around. Everything it needs
-- is file-local, which is why it can be loaded in isolation.

local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local SRC = ROOT .. [[DC-Collection\UI\MainFrame.lua]]

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

-- ---------------------------------------------------------------- stub client
-- companion rows: {creatureId, name, spellId}
local MOUNTS = { {1001, "Gryphon", 60001}, {1002, "Kodo", 60002} }
local CRITTERS = { {2001, "Mini Diablo", 70001}, {2002, "Crab", 70002}, {2003, "Whelp", 70003} }

local cursor, picked

_G.GetNumCompanions = function(t) return (t == "MOUNT") and #MOUNTS or #CRITTERS end
_G.GetCompanionInfo = function(t, i)
    local e = (t == "MOUNT") and MOUNTS[i] or CRITTERS[i]
    if not e then return end
    return e[1], e[2], e[3]
end
_G.PickupCompanion = function(t, i) picked = {"companion", t, i}; cursor = "companion" end
_G.PickupSpell = function(id) picked = {"spell", id}; cursor = "spell" end
_G.GetCursorInfo = function() if cursor then return cursor, 1 end end
_G.CursorHasItem = function() return cursor ~= nil end
_G.ClearCursor = function() cursor = nil end
_G.DC = {}

local function reset() cursor, picked = nil, nil end

-- ------------------------------------------------------------- load the block
local src = assert(io.open(SRC, "r")):read("*a")
local first = assert(src:find("local function ToPositiveNumber", 1, true),
                     "ToPositiveNumber not found -- did MainFrame.lua change?")
local last = assert(src:find("\nfunction DC:PickupCollectionItemForActionBar", first, true),
                    "the exposed DC:PickupCollectionItemForActionBar wrapper is gone")

local chunk = src:sub(first, last) .. [[
return {
    Pickup = PickupCollectionItemForActionBar,
    ResolvePetIds = ResolvePetIds,
    GetCritterIndex = GetCritterCompanionIndex,
}
]]

local loader = assert((loadstring or load)(chunk, "pickup_block"))
local M = loader()

-- --------------------------------------------------------------------- tests
print("== mounts still behave exactly as before ==")
reset()
ok(M.Pickup({type = "mounts", collected = true, id = 60001}) == true, "mount picked up")
ok(picked[1] == "spell" and picked[2] == 60001, "mount still tries PickupSpell first")

print("== pets: matched by spell id ==")
reset()
ok(M.Pickup({type = "pets", collected = true, definition = {spellId = 70002}}) == true,
   "pet picked up via definition.spellId")
ok(picked[1] == "companion" and picked[2] == "CRITTER" and picked[3] == 2,
   "used PickupCompanion(\"CRITTER\", 2)")

print("== pets: matched by creature id ==")
reset()
ok(M.Pickup({type = "pets", collected = true, definition = {creatureId = 2003}}) == true,
   "pet picked up via definition.creatureId")
ok(picked[3] == 3, "resolved to CRITTER slot 3")

print("== pets: bare collection key, kind not known up front ==")
reset()
ok(M.Pickup({type = "pets", collected = true, id = 70001}) == true, "item.id used as a spell id")
ok(picked[3] == 1, "slot 1")
reset()
ok(M.Pickup({type = "pets", collected = true, id = 2002}) == true, "item.id used as a creature id")
ok(picked[3] == 2, "slot 2")

print("== forcedType: Pet Journal rows carry no .type field ==")
reset()
ok(M.Pickup({collected = true, id = 70003}) == false, "no type and no override -> refuses")
reset()
ok(M.Pickup({collected = true, id = 70003}, "pets") == true, "explicit \"pets\" override works")

print("== guard rails ==")
reset()
ok(M.Pickup({type = "pets", collected = false, id = 70001}) == false, "uncollected pet refused")
reset()
ok(M.Pickup({type = "pets", collected = true, id = 999999}) == false,
   "a pet the character has not learned is refused")
ok(cursor == nil, "...and nothing is left on the cursor")
reset(); cursor = "something"
ok(M.Pickup({type = "pets", collected = true, id = 70001}) == false,
   "will not clobber a payload already on the cursor")
reset()
ok(M.Pickup(nil) == false and M.Pickup("x") == false, "non-table input refused")

print("== degrades when PickupCompanion is unavailable ==")
reset()
local saved = _G.PickupCompanion
_G.PickupCompanion = nil
ok(M.Pickup({type = "pets", collected = true, definition = {spellId = 70002}}) == true,
   "falls back to PickupSpell")
ok(picked[1] == "spell" and picked[2] == 70002, "used the companion's own spell id")
_G.PickupCompanion = saved

print("")
print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
