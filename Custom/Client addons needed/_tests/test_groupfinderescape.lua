-- DC-MythicPlus Group Finder: texts other players typed (security audit 2026-11-10).
--
-- Listing notes, dungeon names, event titles/descriptions and applicant messages travel through
-- the DC protocol and were rendered with their '|' escape codes live: a screen-sized texture,
-- fake colour-coded status text, or a link that became clickable once "Sign Up" printed the
-- event title. Every such sink now doubles '|' (GF.EscapeText), whatever the server sends.
-- Harness setup copied from test_groupfinderframe.lua.
dofile("wowsim.lua")
_G.unpack = _G.unpack or table.unpack   -- 3.3.5 client global; Lua 5.4 moved it
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local ADDON = ROOT .. [[DC-MythicPlus\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

-- ---------------------------------------------------------------------------
-- Simulator extensions
-- ---------------------------------------------------------------------------
local Methods = getmetatable(CreateFrame("Frame")).__index
local TexMethods = getmetatable(CreateFrame("Frame"):CreateTexture()).__index
function Methods:GetName() return self._name end
function Methods:SetID(id) self._id = id end
function Methods:GetID() return self._id or 0 end
function Methods:SetFrameLevel(l) self._level = l end
function Methods:GetFrameLevel() return self._level or 1 end
function Methods:SetText(t) self._text = t end
function Methods:GetText() return self._text or "" end
function Methods:SetWidth(w) self._w = w end
function Methods:SetHeight(h) self._h = h end
function Methods:SetSize(w, h) self._w, self._h = w, h end
function Methods:GetWidth() return self._w or 300 end
function Methods:GetHeight() return self._h or 100 end
function Methods:SetPoint(...) self._point = { ... } end
function Methods:HookScript(k, fn)
    local prev = self._scripts[k]
    self._scripts[k] = function(...) if prev then prev(...) end; fn(...) end
end
function TexMethods:GetTexture() return self._tex and self._tex[1] end
-- Record each texture's draw layer and owner: the layering tests below need
-- them (3.3.5 has no sublevels, so the layer is the whole draw order).
local simCreateTexture = Methods.CreateTexture
function Methods:CreateTexture(name, layer, ...)
    local tex = simCreateTexture(self, name, layer, ...)
    tex._layer, tex._owner = layer, self
    self._textures = self._textures or {}
    table.insert(self._textures, tex)
    return tex
end

local simCreateFrame = CreateFrame
_G.CreateFrame = function(ftype, name, parent, tmpl)
    local f = simCreateFrame(ftype, name, parent, tmpl)
    f._name = name
    f._tmpl = tmpl
    if name then
        _G[name] = f
        -- Named stock templates expose their label as <name>Text.
        if tmpl == "UICheckButtonTemplate" then
            _G[name .. "Text"] = f:CreateFontString()
        end
    end
    return f
end

-- ---------------------------------------------------------------------------
-- Stock globals
-- ---------------------------------------------------------------------------
_G.UIParent = CreateFrame("Frame", "UIParent")
_G.GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.tinsert = table.insert
_G.PlaySound = function() end
_G.UnitLevel = function() return 80 end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
                     "GameFontNormalLarge", "GameFontDisable", "GameFontDisableSmall" }) do
    _G[n] = { GetFont = function() return "font", 12, "" end }
end
local menuButtons = {}
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function(info, level) table.insert(menuButtons, { info = info, level = level }) end
_G.UIDropDownMenu_Initialize = function(frame, fn) frame._init = fn end
_G.UIDropDownMenu_SetWidth = function() end
_G.UIDropDownMenu_SetText = function(frame, text) frame._ddtext = text end
_G.UIDropDownMenu_JustifyText = function() end
_G.CloseDropDownMenus = function() end
_G.GetItemInfo = function(id)
    if id == 40243 then
        return "Footwraps of Vile Deceit", nil, 4, 200, 80, "Armor", "Cloth", 1, "INVTYPE_FEET",
            "Interface\\Icons\\INV_Boots_Cloth_02"
    end
end
_G.GetCurrencyInfo = function() return nil end

-- Addon namespace + protocol stubs.
local requests = {}
_G.DCMythicPlusHUD = {
    GetMythicPlusDungeonList = function() return { { mapId = 574, name = "Utgarde Keep" } } end,
    ResolveMythicPlusDungeonArtCandidates = function() return nil end,
}
_G.DCAddonProtocol = {
    DecodeJSON = function(_, s) return nil end,
    GroupFinder = {
        GetQueueCatalog = function() table.insert(requests, "catalog") end,
        GetSystemInfo = function() table.insert(requests, "sysinfo") end,
        GetDungeonList = function() table.insert(requests, "dungeons") end,
        JoinQueue = function(...) table.insert(requests, { "join", ... }) end,
        LeaveQueue = function() table.insert(requests, "leave") end,
        RespondToProposal = function(id, accept) table.insert(requests, { "respond", id, accept }) end,
        Search = function(payload) table.insert(requests, { "search", payload }) end,
        GetSpectateList = function() table.insert(requests, "spectate") end,
    },
}


-- Every font string the Group Finder creates, so the checks can scan all rendered text.
local fontStrings = {}
local simCreateFontString = Methods.CreateFontString
function Methods:CreateFontString(...)
    local fs = simCreateFontString(self, ...)
    fontStrings[#fontStrings + 1] = fs
    return fs
end
local frames = {}
local recCreateFrame = CreateFrame
_G.CreateFrame = function(...)
    local f = recCreateFrame(...)
    frames[#frames + 1] = f
    return f
end
local tooltipLines = {}
function Methods:AddLine(text) tooltipLines[#tooltipLines + 1] = text end
_G.time = os.time
_G.date = os.date
_G.UnitName = function() return "Tester" end
_G.GetNumFriends = function() return 0 end
_G.IsInGuild = function() return false end
_G.GetNumGuildMembers = function() return 0 end
_G.SEARCH = "Search"
function Methods:GetFontString()
    self._fontString = self._fontString or self:CreateFontString()
    return self._fontString
end

dofile(ADDON .. [[UI\GroupFinderFrame.lua]])
dofile(ADDON .. [[UI\MatchmakingQueue.lua]])
local GF = DCMythicPlusHUD.GroupFinder
ok(type(GF.EscapeText) == "function", "GF.EscapeText exists")
if type(GF.EscapeText) ~= "function" then
    print(string.format("RESULT: %d passed, %d failed", pass, fail))
    os.exit(1)
end

-- A player-typed listing text: a screen-sized texture plus a clickable link.
local EVIL = "EVIL|TInterface\\Buttons\\WHITE8X8:900:1600|t|Hdc:outfit:1:0:x:1|h[Free Gold]|h"
local SAFE = "EVIL||TInterface\\Buttons\\WHITE8X8:900:1600||t||Hdc:outfit:1:0:x:1||h[Free Gold]||h"

print("== helper ==")
ok(GF.EscapeText(EVIL) == SAFE, "every '|' is doubled")
ok(GF.EscapeText("plain text") == "plain text", "plain text is unchanged")
ok(GF.EscapeText(nil) == nil, "nil stays nil")
ok(GF.EscapeText(25) == "25", "numbers become strings")

-- Scan rendered text: anything carrying the payload must carry it escaped.
local function scan(label, extra)
    local seen, raw = 0, 0
    local function check(text)
        if type(text) == "string" and text:find("EVIL", 1, true) then
            seen = seen + 1
            local i = text:find("EVIL", 1, true)
            if text:sub(i, i + #SAFE - 1) ~= SAFE then raw = raw + 1 end
        end
    end
    for _, fs in ipairs(fontStrings) do check(fs._text) end
    for _, t in ipairs(extra or {}) do check(t) end
    ok(seen > 0, label .. ": the listing text is rendered (" .. seen .. " strings)")
    ok(raw == 0, label .. ": none of it is rendered with live escape codes")
end
local function clear()
    for _, fs in ipairs(fontStrings) do fs._text = nil end
    tooltipLines = {}
end

print("== compact listing rows (GroupFinderFrame) ==")
GF:CreateMainFrame()
GF:ShowRetailPremadeHome("mythic")
GF:CompactPopulateGroups({
    { id = 21, dungeonName = EVIL, leader = "Bob", needTank = 1, needHealer = 0, needDps = 2, level = 7, note = EVIL },
}, "mythic")
GF:SelectCompactType("mythic")
scan("compact rows")
local row = GF.compactRowPool and GF.compactRowPool[1]
if row and row.entry then
    local shownName = (row.name and row.name._text) or ""
    clear()
    GF:CompactSelectRow(row, row.entry)
    GF:ShowApplicationDialog(21, shownName)
    scan("apply dialog title")
end

print("== Mythic+ tab ==")
clear()
dofile(ADDON .. [[UI\MythicTab.lua]])
GF.compactMode = false
GF:CreateMythicBrowsePanel(UIParent)
GF:PopulateMythicGroups({ { id = 31, dungeon = EVIL, leader = "Bob", level = 12, note = EVIL } })
scan("Mythic+ browse rows")

clear()
GF:OnListingCreated({ listingId = 31 })
GF:OnNewApplication({ listingId = 31, playerName = "Applicant", role = "dps", message = EVIL })
GF:RefreshApplicantPanel()
local hovered = false
for _, f in ipairs(frames or {}) do
    if f._scripts and f._scripts.OnEnter and f.msgIcon then
        f._scripts.OnEnter(f)
        hovered = true
    end
end
ok(hovered, "an applicant row with a message has a hover tooltip")
scan("applicant message tooltip", tooltipLines)

print("== Raid tab ==")
clear()
dofile(ADDON .. [[UI\RaidTab.lua]])
GF:CreateRaidBrowsePanel(UIParent)
GF:PopulateRaidGroups({ { id = 41, raid = EVIL, difficulty = EVIL, progress = EVIL, leader = "Bob", spots = 3,
    note = "x" .. EVIL } })
scan("raid rows")

print("== World tab ==")
clear()
DCAddonProtocol.RegisterHandler = function() end
DCAddonProtocol.Request = function() end
dofile(ADDON .. [[UI\WorldTab.lua]])
GF:CreateWorldContentEntry(UIParent, { dungeonName = EVIL, leader = "Bob", note = EVIL }, "quest")
GF:CreateWorldContentEntry(UIParent, { name = "Event", description = EVIL }, "event")
scan("world entries")

print("== Scheduled tab ==")
clear()
_G.C_Timer = _G.C_Timer or { After = function() end }
dofile(ADDON .. [[UI\ScheduledTab.lua]])
GF:CreateScheduledTab()
GF:PopulateScheduledEvents({ { id = 51, title = EVIL, description = EVIL, organizer = "Bob", maxSignups = 10 } })
scan("scheduled event rows")
local signup
for _, f in ipairs(frames or {}) do
    if f._scripts and f._scripts.OnClick and f._tmpl == "UIPanelButtonTemplate" and f._text == "Sign Up" then
        signup = f
    end
end
ok(signup ~= nil, "the event row has a Sign Up button")
if signup then
    clear()
    signup._scripts.OnClick(signup)
    scan("Sign Up message", { GF._pendingStatusMessage })
end

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
