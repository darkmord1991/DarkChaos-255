-- DC-MythicPlus Group Finder window (UI/GroupFinderFrame.lua +
-- UI/MatchmakingQueue.lua): builds the retail-style shell against the
-- stubbed 3.3.5 API and drives every view - the Dungeon Finder picker with
-- its expansion headers and tick boxes, the Raid Finder picker, the Premade
-- Groups home and listing rows, the PvP / Mythic+ / Spectate / Hinterland
-- panels, the queue status overlay, the ready-check dialog and the two
-- listing dialogs. wowsim resolves unknown widget methods to no-ops, so this
-- pins logic, data flow and which widgets exist, not the client API surface.
dofile("wowsim.lua")
_G.unpack = _G.unpack or table.unpack   -- 3.3.5 client global; Lua 5.4 moved it
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local ADDON = ROOT .. [[DC-MythicPlus\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end end

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

dofile(ADDON .. [[UI\GroupFinderFrame.lua]])
dofile(ADDON .. [[UI\MatchmakingQueue.lua]])
local GF = DCMythicPlusHUD.GroupFinder

local function shownRows()
    local n = 0
    for _, row in ipairs(GF.compactRowPool or {}) do
        if row:IsShown() then n = n + 1 end
    end
    return n
end

local function shownHeaders()
    local n = 0
    for _, header in ipairs(GF.compactHeaderPool or {}) do
        if header:IsShown() then n = n + 1 end
    end
    return n
end

local function rowFor(mapId)
    for _, row in ipairs(GF.compactRowPool or {}) do
        if row:IsShown() and row.entry and tonumber(row.entry.queueMapId) == mapId then
            return row
        end
    end
end

-- ---------------------------------------------------------------------------
print("== shell ==")
-- ---------------------------------------------------------------------------
local frame = GF:CreateMainFrame()
ok(frame ~= nil and GF.mainFrame == frame, "main frame built")
ok(GF.FRAME_WIDTH == 620 and GF.FRAME_HEIGHT == 500, "window is 620x500 (retail PVEFrame proportions, one size up)")
ok(frame.Portrait ~= nil and frame.TitleText ~= nil, "portrait + title present")
ok(GF.navInset ~= nil and GF.contentInset ~= nil and GF.contentPane ~= nil, "nav inset + content inset + pane")
local canvas = GF.navInset.bgTiles[1]._owner
ok(canvas ~= frame and canvas._level == math.max(frame:GetFrameLevel() - 1, 0),
    "background paint sits on a canvas one level under the window")
local canvasLayers, tilesInRange = {}, true
for _, tex in ipairs(canvas._textures or {}) do
    canvasLayers[tex._layer] = (canvasLayers[tex._layer] or 0) + 1
    if tex._layer ~= "ARTWORK" then
        for _, c in ipairs(tex._texcoord or { 2 }) do
            if c < 0 or c > 1 then tilesInRange = false end
        end
    end
end
ok(canvasLayers.BACKGROUND == 6 and canvasLayers.BORDER == 6 and canvasLayers.ARTWORK == 2,
    "canvas: 6 rock tiles, 6 marble tiles, then nav panel + content shade")
ok(tilesInRange, "fill tiles keep texcoords inside 0..1 (no sampler wrap)")
local discLayer
for _, tex in ipairs(frame._textures or {}) do
    if tex._point and tex._point[2] == frame.Portrait then discLayer = tex._layer end
end
ok(frame.Portrait._layer == "OVERLAY" and discLayer == "ARTWORK", "eye draws a layer above its dark disc")
ok(GF.retailNavButtons.dungeon.icon._layer == "ARTWORK" and GF.retailNavButtons.dungeon.ring._layer == "OVERLAY",
    "nav icon sits a layer under its gold ring")
local navCount = 0
for _ in pairs(GF.retailNavButtons or {}) do navCount = navCount + 1 end
ok(navCount == 4, "4 nav buttons (got " .. navCount .. ")")
local roleCount = 0
for _ in pairs(GF.compactRoleButtons or {}) do roleCount = roleCount + 1 end
ok(roleCount == 4, "4 role buttons (got " .. roleCount .. ")")
ok(GF.compactTypeDropdown ~= nil and GF.compactTypeDropdown._tmpl == "UIDropDownMenuTemplate", "Type is a stock dropdown")
ok(GF.compactDiffDropdown ~= nil and GF.compactDiffDropdown._tmpl == "UIDropDownMenuTemplate", "Difficulty is a stock dropdown")
ok(GF.compactPrimaryButton and GF.compactPrimaryButton._tmpl == "UIPanelButtonTemplate", "action button is a stock UIPanelButton")
local tabCount = 0
for _ in pairs(GF.bottomTabs or {}) do tabCount = tabCount + 1 end
ok(tabCount == 4 and GF.bottomTabs.finder._tmpl == "CharacterFrameTabButtonTemplate", "4 stock bottom tabs")
ok(GF.compactTypeMenu == nil and GF.compactTypeMenuCatcher == nil and GF.compactDiffButton == nil,
    "hand-rolled type menu and difficulty cycle button are gone")
ok(GF.COMPACT_OPTIONS.blizzardLFG == nil and GF.COMPACT_OPTIONS.blizzardPVP == nil
    and #GF.TYPE_MENU_BY_CONTEXT.dungeon == 2 and #GF.TYPE_MENU_BY_CONTEXT.premade == 6,
    "stock LFG / PvP entries dropped from the type menus")
ok(GF.bottomTabs.finder._level == math.max(GF.mainFrame:GetFrameLevel() - 1, 0),
    "bottom tabs sit one level under the frame's bottom border")
ok(GF.mainFrame._eyeFrame == 0 and GF.mainFrame._scripts.OnUpdate ~= nil, "portrait eye is the LFG flipbook")
GF.mainFrame._scripts.OnUpdate(GF.mainFrame, 0.3)
ok(GF.mainFrame._eyeFrame == 6, "eye advances one flipbook frame per 0.05s (got " .. tostring(GF.mainFrame._eyeFrame) .. ")")
ok(GF.compactRewardRow ~= nil and not GF.compactRewardRow:IsShown(), "daily reward line exists and starts hidden")
ok(UISpecialFrames[1] == "DCMythicPlusGroupFinderFrame", "closes on Escape")
ok(GF.compactSelectedKind == "dungeons" and GF.compactBrowserFrame:IsShown(), "opens on the Dungeon Finder picker")
ok(GF.retailContentTitle._text == "Dungeon Finder", "attic title names the view")
ok(GF.compactDiffDropdown:IsShown() and GF.compactTypeDropdown:IsShown(), "Specific Dungeons shows Type + Difficulty")
ok(requests[#requests] == "catalog", "picker asked the server for the queue catalog")

-- ---------------------------------------------------------------------------
print("== dungeon picker ==")
-- ---------------------------------------------------------------------------
GF:OnQueueCatalog({
    dungeons = {
        { mapId = 36,  name = "The Deadmines", expansion = 0, reqLevel = { 15, 15, 80 }, maxLevel = { 25, 25, 0 }, mplus = 0 },
        { mapId = 540, name = "Hellfire Ramparts", expansion = 1, reqLevel = { 60, 70, 80 }, maxLevel = { 65, 0, 0 }, mplus = 0 },
        { mapId = 574, name = "Utgarde Keep", expansion = 2, reqLevel = { 68, 80, 80 }, maxLevel = { 74, 0, 0 }, mplus = 1 },
        { mapId = 576, name = "The Nexus", expansion = 2, reqLevel = { 69, 80, 80 }, maxLevel = { 75, 0, 0 }, mplus = 1,
          lock = { "", "", "Not in this season's Mythic+ rotation" } },
    },
    raids = {
        -- Server raid difficulty enum: 0 = 10N, 1 = 25N, 2 = 10H, 3 = 25H.
        { mapId = 533, name = "Naxxramas", expansion = 2, options = { { d = 0, s = 10 }, { d = 3, s = 25 } } },
        { mapId = 409, name = "Molten Core", expansion = 0, options = { { d = 0, s = 40 } } },
    },
})
ok(shownRows() == 5, "Any Dungeon + 4 dungeons rendered (got " .. shownRows() .. ")")
ok(shownHeaders() == 3, "one expansion header per era (got " .. shownHeaders() .. ")")
local uk = rowFor(574)
ok(uk ~= nil and uk.check ~= nil and uk.check:IsShown(), "dungeon rows carry a checkbox")
ok(uk and uk.name._text == "Utgarde Keep", "row shows the plain dungeon name (no expansion tag)")
ok(uk and uk.meta._text == "68-74", "row shows the level bracket, not the difficulty word")
local any = rowFor(0)
ok(any ~= nil and any.check:IsShown(), "Any Dungeon row is a tick row too")
ok(GF.compactPrimaryButton._text == "Find Random Group", "no ticks = random queue label")
GF:CompactSelectRow(uk, uk.entry)
local ticks = GF:GetDungeonTickList()
ok(#ticks == 1 and ticks[1] == 574, "ticking a dungeon records it")
ok(GF.compactPrimaryButton._text == "Find Group (1 dungeon)", "label counts the ticked dungeons")
ok(uk.check._checked == true and any.check._checked == false, "checkbox states follow the tick set")
ok(not GF.compactCreateButton:IsShown(), "no Start a Group in the finder queue view")

GF:SetQueueDungeonDifficulty(1)
ok(GF.compactDiffDropdown._ddtext == "Heroic", "difficulty dropdown text follows the setting")
ok(rowFor(36) and rowFor(36).meta._text == "15-25", "heroic re-render keeps the level column")

GF:UpdateSystemInfo({ rewardEnabled = true, rewardItemId = 40243, rewardItemCount = 2 })
ok(GF.compactRewardRow:IsShown() and GF.compactRewardRow.text._text == "2x Footwraps of Vile Deceit",
    "daily reward line shows under the picker with the item")
ok(GF.mainFrame.StatusText._text ~= "Daily reward available", "reward no longer hijacks the status line")
ok(GF.compactListFrame._point and GF.compactListFrame._point[5] == GF.LIST_BOTTOM + 22,
    "list gives the reward line its room")

-- ---------------------------------------------------------------------------
print("== mythic+ picker ==")
-- ---------------------------------------------------------------------------
GF:SelectCompactType("mythic")
ok(shownRows() == 3, "Mythic+ lists Any + the 2 rotation dungeons (got " .. shownRows() .. ")")
ok(not GF.compactDiffDropdown:IsShown() and GF.compactTypeDropdown:IsShown(), "Mythic+ hides Difficulty, keeps Type")
local nexus = rowFor(576)
ok(nexus ~= nil and nexus.entry.locked == true, "server lock reason greys the row")
ok(GF.compactTypeDropdown._ddtext == "Mythic+", "type dropdown shows the same label as its menu entry")
ok(GF.compactRewardRow:IsShown(), "daily reward line stays on the Mythic+ picker")

-- ---------------------------------------------------------------------------
print("== raid picker ==")
-- ---------------------------------------------------------------------------
GF:SelectCompactType("raid")
ok(shownRows() == 3, "one row per raid size/difficulty (got " .. shownRows() .. ")")
ok(not GF.compactTypeDropdown:IsShown(), "Raid Finder has no Type row")
ok(GF.retailContentTitle._text == "Raid Finder", "attic title switches to Raid Finder")
local naxx25
for _, row in ipairs(GF.compactRowPool) do
    if row:IsShown() and row.entry.queueMapId == 533 and row.entry.queueSize == 25 then naxx25 = row end
end
ok(naxx25 ~= nil and not (naxx25.check and naxx25.check:IsShown()), "raid rows have no checkbox")
ok(naxx25 and naxx25.meta._text == "25 Heroic", "raid row shows size + difficulty")
GF:CompactSelectRow(naxx25, naxx25.entry)
ok(GF.compactSelectedEntry == naxx25.entry and naxx25.bg:IsShown(), "raid row single-selects with the select bar")
ok(GF.compactPrimaryButton._text == "Find Group", "raid picker keeps the plain Find Group label")

-- ---------------------------------------------------------------------------
print("== premade groups ==")
-- ---------------------------------------------------------------------------
GF:ShowRetailPremadeHome("mythic")
ok(GF.retailHomeFrame:IsShown() and not GF.compactBrowserFrame:IsShown(), "home shows the category list only")
ok(GF.compactPrimaryButton:IsShown() and GF.compactCreateButton:IsShown(), "home offers Find a Group + Start a Group")
ok(GF.compactPrimaryButton._text == "Find a Group", "home primary label")
local catCount = 0
for _ in pairs(GF.premadeCategoryButtons or {}) do catCount = catCount + 1 end
ok(catCount == #GF.PREMADE_CATEGORY_ORDER, "one banner per premade category")

GF:CompactPopulateGroups({
    { id = 11, dungeonName = "Utgarde Keep", leader = "Bob", needTank = 1, needHealer = 0, needDps = 2, level = 7 },
    { id = 12, dungeonName = "The Nexus", leader = "Alice", needTank = 0, needHealer = 1, needDps = 1, note = "chill run" },
}, "mythic")
GF:SelectCompactType("mythic")
ok(GF.retailNavContext == "premade" and GF.compactBrowserFrame:IsShown(), "category click opens the listing browser")
ok(shownRows() == 2 and shownHeaders() == 0, "2 listing rows, no expansion headers")
local first = GF.compactRowPool[1]
ok(first.sub:IsShown() and first.sub._text == "Bob", "listing row shows the leader on line 2")
ok(first.meta._text == "+7", "listing row shows the key level")
ok(first.roles:IsShown(), "listing row shows role counts")
ok(not (first.check and first.check:IsShown()), "listing rows have no checkbox")
ok(GF.retailContentTitle._text == "Premade Groups", "attic title stays Premade Groups in the listing view")
ok(not GF.compactRewardRow:IsShown() and GF.compactListFrame._point[5] == GF.LIST_BOTTOM,
    "no daily reward line on premade listings, list takes the room back")
GF:CompactSelectRow(first, first.entry)
ok(GF.compactPrimaryButton._text == "Apply", "selecting a listing turns the action into Apply")
ok(GF.compactCreateButton:IsShown(), "Start a Group stays available for premade listings")

-- ---------------------------------------------------------------------------
print("== other views ==")
-- ---------------------------------------------------------------------------
GF:ShowPvPPanel()
ok(GF.pvpPanel:IsShown() and not GF.compactBrowserFrame:IsShown(), "PvP panel replaces the browser")
ok(not GF.compactPrimaryButton:IsShown() and not GF.compactCreateButton:IsShown(), "PvP panel hides the action buttons")
ok(GF.retailContentTitle._text == "Player vs Player", "PvP attic title")

GF:ShowMythicPanel()
ok(GF.mythicPanel:IsShown() and not GF.pvpPanel:IsShown(), "Mythic+ panel replaces PvP")
ok(#GF.mythicPanel.runLines == 8, "Mythic+ panel has 8 best-run lines")
ok(not GF.compactPrimaryButton:IsShown(), "Mythic+ panel hides the action buttons")

GF:ShowSpectatePanel()
ok(GF.spectatePanel:IsShown() and not GF.mythicPanel:IsShown(), "Spectate panel replaces Mythic+")
ok(GF.compactPrimaryButton:IsShown() and GF.compactPrimaryButton._text == "Refresh", "Spectate action is Refresh")
local filterCount = 0
for _ in pairs(GF.spectatePanel.filterButtons) do filterCount = filterCount + 1 end
ok(filterCount == 4, "4 spectate filters")

GF:ShowHinterlandPanel()
ok(GF.hlbgPanel:IsShown() and not GF.spectatePanel:IsShown(), "Hinterland panel replaces Spectate")
ok(GF.compactPrimaryButton._text == "Join Queue", "Hinterland action is Join Queue")
ok(GF.bottomTabs.pvp.isActive == true, "Hinterland lights the PvP tab")

GF.retailNavContext = nil
GF:SelectCompactType("dungeons")
ok(GF.compactBrowserFrame:IsShown() and not GF.hlbgPanel:IsShown(), "back to the Dungeon Finder picker")
ok(GF.bottomTabs.finder.isActive == true, "Dungeons & Raids tab active again")

-- ---------------------------------------------------------------------------
print("== queue + ready check ==")
-- ---------------------------------------------------------------------------
GF:OnQueueJoined({ category = 1 })
ok(GF.queueStatusFrame ~= nil and GF.queueStatusFrame:IsShown(), "queue status overlay shown on join")
ok(GF.queueStatusFrame.leaveBtn._tmpl == "UIPanelButtonTemplate", "Leave Queue is a stock button")

GF:OnQueueProposal({ proposalId = 9, category = 1, dungeonId = 574, difficulty = 1, raidSize = 0,
                     role = "Tank", size = 5, accepted = 2, timeout = 40 })
local prop = GF.queueProposalFrame
ok(prop ~= nil and prop:IsShown(), "ready-check dialog shown")
ok(prop.instanceName._text == "Utgarde Keep", "ready check names the dungeon from the catalog")
ok(prop.instanceInfo._text == "Heroic Dungeon", "ready check shows the difficulty")
ok(prop.roleLine._text:find("Tank") ~= nil, "ready check shows the assigned role")
ok(prop.accepted._text == "2 / 5 accepted", "backfilled bots count as accepted")
GF:RespondToQueueProposal(true)
ok(prop.acceptBtn._enabled == false and prop.declineBtn._enabled == false, "accepting locks both buttons")
ok(requests[#requests][1] == "respond" and requests[#requests][2] == 9 and requests[#requests][3] == true,
    "accept reached the server with the proposal id")

GF:OnQueueProposal({ proposalId = 10, category = 2, dungeonId = 533, difficulty = 3, raidSize = 25,
                     role = "Healer", size = 25, accepted = 0, timeout = 40 })
ok(prop.instanceName._text == "Naxxramas" and prop.instanceInfo._text == "25 Heroic", "raid proposal shows size + difficulty")

GF:OnQueueLeft({})
ok(not GF.queueStatusFrame:IsShown(), "leaving hides the overlay")

-- ---------------------------------------------------------------------------
print("== dialogs ==")
-- ---------------------------------------------------------------------------
GF:ShowApplicationDialog(11, "Utgarde Keep")
ok(GF.appDialog ~= nil and GF.appDialog:IsShown(), "apply dialog shown")
ok(GF.appDialog.title._text == "Apply to Utgarde Keep", "apply dialog names the listing")
GF:ShowCompactCreateDialog("mythic")
ok(GF.compactCreateDialog ~= nil and GF.compactCreateDialog:IsShown(), "create dialog shown")
ok(GF.compactCreateDialog.title._text == "Create Mythic+", "create dialog names the category")

print("")
print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
