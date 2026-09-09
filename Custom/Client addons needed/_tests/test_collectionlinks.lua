-- Mount/pet chat links (DC-Collection/Modules/CollectionLinks.lua).
--
-- Loads the real module against wowsim plus a stub DCCollection, and pins the
-- wire format both halves depend on: a sender builds |Hdc:mount:...|h, an
-- unrelated receiver parses it back to the same definition key. Everything
-- here is client-to-client, so a format change that only one side knows about
-- is exactly the bug this suite exists to catch.

local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local SRC = ROOT .. [[DC-Collection\Modules\CollectionLinks.lua]]

dofile("wowsim.lua")

local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m)
    else fail = fail + 1; print("  FAIL " .. m) end
end

-- ---------------------------------------------------------------- stub client
_G.strsplit = function(sep, str)
    local out = {}
    local pattern = "([^" .. sep .. "]*)" .. sep .. "?"
    local pos = 1
    while pos <= #str do
        local s, e, cap = string.find(str, pattern, pos)
        if not s or e < s then break end
        out[#out + 1] = cap
        pos = e + 1
    end
    if string.sub(str, -1) == sep then out[#out + 1] = "" end
    return (unpack or table.unpack)(out)
end

local modifier = nil
_G.IsModifiedClick = function(action) return modifier == action end

local inserted, chatOpened, chatActive
_G.ChatEdit_InsertLink = function(link)
    if not chatActive then return false end
    inserted = link
    return true
end
_G.ChatEdit_GetActiveWindow = function() return chatActive or nil end
_G.ChatFrame_OpenChat = function() chatOpened = true; chatActive = true end

local tooltipLines
_G.GameTooltip = {
    SetOwner = function() end,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show = function() end,
    Hide = function() end,
}

_G.UIParent = {}
_G.NUM_CHAT_WINDOWS = 2
_G.UIDropDownMenu_SetText = function() end
_G.hooksecurefunc = function() end

-- ------------------------------------------------------------ stub DCCollection
local MOUNT_DEFS = {
    [60001] = {name = "Swift |cffff0000Gryphon|r: Fast", rarity = 4, itemId = 1234, mountType = 2,
               source = "Vendor"},
    [60002] = {name = "Brown Kodo", rarity = 2, mountType = 1},
}
local PET_DEFS = {
    [8485] = {name = "Mini Diablo", rarity = 3, spellId = 70001, creatureId = 2001},
    [8486] = {name = "Crab", rarity = 1, creatureId = 2002},
}

local DC
local printed, focused, shown

local function reset()
    inserted, printed, focused, shown = nil, {}, nil, false
    chatOpened, chatActive = false, true
    DC.isGM = false
    tooltipLines = {}
    modifier = nil
    DC.definitions = {mounts = MOUNT_DEFS, pets = PET_DEFS}
    DC.collections = {mounts = {[60001] = {}}, pets = {}}
    DC.selectedExpansionFilter = "all"
    DC.MainFrame.FilterBar.searchBox._text = ""
    DC.MainFrame.FilterBar.collectedCheck._checked = true
    DC.MainFrame.FilterBar.notCollectedCheck._checked = true
end

local searchBox = {
    _text = "",
    GetText = function(self) return self._text end,
    SetText = function(self, t) self._text = t end,
}
local function checkbox()
    return {
        _checked = true,
        GetChecked = function(self) return self._checked end,
        SetChecked = function(self, v) self._checked = v end,
    }
end

DC = {
    L = {},
    EXPANSION_FILTERS = {{id = "all", text = "All Expansions"}},
    RarityColors = {
        [1] = {r = 1, g = 1, b = 1, hex = "|cffffffff"},
        [2] = {r = 0.12, g = 1, b = 0, hex = "|cff1eff00"},
        [3] = {r = 0, g = 0.44, b = 0.87, hex = "|cff0070dd"},
        [4] = {r = 0.64, g = 0.21, b = 0.93, hex = "|cffa335ee"},
    },
    MainFrame = {FilterBar = {searchBox = searchBox, collectedCheck = checkbox(),
                              notCollectedCheck = checkbox()}},
}
_G.DCCollection = DC

function DC:GetRarityColor(rarity) return self.RarityColors[rarity] or self.RarityColors[1] end
function DC:GetDefinition(collType, id) return (self.definitions[collType] or {})[tonumber(id) or id] end
function DC:Print(msg) printed[#printed + 1] = msg end
function DC:FormatSource(source) return source end
function DC:ShowMainFrame() shown = true end
function DC:FocusCollectionEntry(data) focused = data end
function DC:OnFilterChanged() end
function DC:RequestDefinitions() end

-- The retry loop runs inline so a test does not have to pump a clock.
DC.After = function(_, fn) fn() end

-- Stands in for MainFrame's real filtered list: definitions, minus anything the
-- search box hides.
function DC:GetFilteredItems()
    local out = {}
    local needle = string.lower(self.MainFrame.FilterBar.searchBox:GetText() or "")
    for id, def in pairs(self.definitions.mounts) do
        if needle == "" or string.find(string.lower(def.name), needle, 1, true) then
            out[#out + 1] = {id = id, name = def.name, definition = def}
        end
    end
    return out
end

DC.PetJournal = {
    filteredPets = {},
    UpdatePetList = function(self)
        self.filteredPets = {}
        for id, def in pairs(DC.definitions.pets) do
            self.filteredPets[#self.filteredPets + 1] = {id = id, name = def.name, definition = def}
        end
    end,
}

reset()
dofile(SRC)

-- --------------------------------------------------------------------- tests
print("== link generation ==")
reset()
local link = DC:GenerateMountLink(60001)
ok(type(link) == "string", "mount link built")
ok(string.sub(link, 1, 10) == "|cffa335ee", "epic mount is coloured by rarity")
local data = string.match(link, "|H(.-)|h")
ok(data == "dc:mount:1:60001:i1234:Swift Gryphon Fast",
   "payload is dc:mount:<ver>:<id>:i<itemId>:<name>, name stripped of | and :")
ok(string.match(link, "|h%[(.-)%]|h") == "Swift Gryphon Fast", "display text matches the name")

reset()
local petLink = DC:GeneratePetLink(8485)
ok(string.match(petLink, "|H(.-)|h") == "dc:pet:1:8485:s70001:Mini Diablo",
   "pet alt id is tagged as a spell id")
ok(string.match(DC:GeneratePetLink(8486), "|H(.-)|h") == "dc:pet:1:8486:c2002:Crab",
   "pet with no spell id falls back to a tagged creature id")
ok(string.match(DC:GenerateMountLink(60002), "|H(.-)|h") == "dc:mount:1:60002:0:Brown Kodo",
   "no secondary key encodes as 0")
ok(DC:GenerateCollectionLink("titles", 5) == nil, "only mounts and pets are linkable")

print("== parsing (receiver side) ==")
reset()
local collType, id, altId, altField, name = DC:ParseCollectionLink("dc:mount:1:60001:i1234:Swift Gryphon")
ok(collType == "mounts" and id == 60001, "mount link round-trips to its definition key")
ok(altId == 1234 and altField == "itemId", "tagged alt id parses to the field it came from")
ok(name == "Swift Gryphon", "name survives")
local _, _, petAlt, petField = DC:ParseCollectionLink("dc:pet:1:8485:s70001:Mini Diablo")
ok(petAlt == 70001 and petField == "spellId", "pet alt id parses as a spell id")
ok(DC:ParseCollectionLink("item:1234:0:0:0:0:0:0:0") == nil, "item links are not ours")
ok(DC:ParseCollectionLink("dc:outfit:1:0:Name:0-0-0") == nil, "outfit links stay with TransmogModule")

print("== clicking a link ==")
reset()
DC:HandleCollectionLinkClick("dc:mount:1:60001:i1234:Swift Gryphon")
ok(shown == true, "collection window opens")
ok(focused and focused.type == "mounts" and focused.id == 60001, "focuses the linked mount")
ok(focused.itemId == 1234, "passes the secondary key through under its own field name")

reset()
DC.PetJournal:UpdatePetList()
DC:HandleCollectionLinkClick("dc:pet:1:8485:s70001:Mini Diablo")
ok(focused and focused.type == "pets" and focused.id == 8485, "pet links focus the Pet Journal row")
ok(focused.spellId == 70001, "pet secondary key lands on spellId, not itemId")

print("== shift-click re-links instead of opening the window ==")
reset()
modifier = "CHATLINK"
DC:HandleCollectionLinkClick("dc:mount:1:60001:i1234:Swift Gryphon")
ok(inserted ~= nil and string.find(inserted, "dc:mount:1:60001", 1, true) ~= nil,
   "link goes back into the chat edit box")
ok(shown == false and focused == nil, "and the collection window is left alone")

print("== linking with the chat box closed ==")
reset()
chatActive = false
ok(DC:LinkCollectionEntryToChat("mounts", 60001) == true, "link still lands")
ok(chatOpened == true, "chat edit box was opened for it")

print("== a link the receiver has filtered out ==")
reset()
DC.MainFrame.FilterBar.searchBox:SetText("kodo")
DC:HandleCollectionLinkClick("dc:mount:1:60001:i1234:Swift Gryphon")
ok(DC.MainFrame.FilterBar.searchBox:GetText() == "", "search filter is cleared to reveal the target")
ok(focused and focused.id == 60001, "target is then focused")

reset()
DC:HandleCollectionLinkClick("dc:mount:1:99999:0:Ghost Mount")
ok(focused == nil, "an unknown entry focuses nothing")
ok(#printed == 1 and string.find(printed[1], "Ghost Mount", 1, true) ~= nil,
   "and the player is told why, once")

print("== hover tooltip ==")
reset()
DC:ShowCollectionLinkTooltip(nil, "dc:mount:1:60001:i1234:Swift Gryphon")
ok(tooltipLines[1] == "Swift |cffff0000Gryphon|r: Fast", "tooltip titles with the local definition name")
ok(tooltipLines[2] == "Flying Mount", "mount type line")
local joined = table.concat(tooltipLines, "\n")
ok(string.find(joined, "Source: Vendor", 1, true) ~= nil, "source line")
ok(string.find(joined, "Collected", 1, true) ~= nil, "collected state for the viewer, not the sender")

reset()
DC:ShowCollectionLinkTooltip(nil, "dc:pet:1:8485:s70001:Mini Diablo")
ok(string.find(table.concat(tooltipLines, "\n"), "Not collected", 1, true) ~= nil,
   "an uncollected pet reads as not collected")

print("== the GM-only grant hint ==")
reset()
DC:ShowCollectionLinkTooltip(nil, "dc:mount:1:60001:i1234:Swift Gryphon")
ok(string.find(table.concat(tooltipLines, " "), ".collection grant", 1, true) == nil,
   "a normal player never sees the grant line")

reset()
DC.isGM = true
DC:ShowCollectionLinkTooltip(nil, "dc:mount:1:60001:i1234:Swift Gryphon")
ok(string.find(table.concat(tooltipLines, " "), ".collection grant mount 60001", 1, true) ~= nil,
   "a GM gets the mount command with the spell id the link carries")

reset()
DC.isGM = true
DC:ShowCollectionLinkTooltip(nil, "dc:pet:1:8485:s70001:Mini Diablo")
ok(string.find(table.concat(tooltipLines, " "), ".collection grant pet 8485", 1, true) ~= nil,
   "and the pet command with the teaching item id, not the summon spell")

reset()
DC.definitions.mounts = {}
DC:ShowCollectionLinkTooltip(nil, "dc:mount:1:60001:i1234:Swift Gryphon")
ok(tooltipLines[1] == "Swift Gryphon", "with no definitions loaded the link's own name is used")
ok(string.find(table.concat(tooltipLines, "\n"), "not loaded", 1, true) ~= nil,
   "and the tooltip says the data is missing")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
