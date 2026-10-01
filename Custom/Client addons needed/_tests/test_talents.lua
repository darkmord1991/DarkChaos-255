--[[
	DC-Talents headless test: the real addon on a strict 3.3.5a client (talents_sim.lua + talents_client.lua).

	Run from this directory:  lua test_talents.lua        (-v prints errors as they happen)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local CLIENT = SIM.client
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors

-- ----------------------------------------------------------------------------
-- The character: level 80 warrior, dual spec, a partial Arms build in group 1
-- ----------------------------------------------------------------------------

CLIENT.player.class = "WARRIOR"
CLIENT.player.level = 80

local function Learn(talentID, ranks, group)
	CLIENT.ranks[group or 1][talentID] = ranks
end

local warriorTabs = CLIENT.Tabs(false)
ok(#warriorTabs == 3 and warriorTabs[1].name == "Arms", "the simulated warrior has Arms / Fury / Protection")

-- Tier 1 of Arms: fill the first talent(s) up to 5 points.
do
	local spent = 0
	for _, talentID in ipairs(warriorTabs[1].talents) do
		local data = SIM.TalentData[talentID]
		if data[2] == 0 and spent < 5 then
			local ranks = math.min(CLIENT.MaxRank(talentID), 5 - spent)
			Learn(talentID, ranks)
			spent = spent + ranks
		end
	end
	ok(CLIENT.Spent(false, 1) == 5, "group 1 starts with 5 points in Arms tier 1")
end

-- ----------------------------------------------------------------------------
-- Load: DC-AddonProtocol's compat layer, DC-Journal's shared metatable patches, DC-Talents
-- ----------------------------------------------------------------------------

section("load")

local ns = T.Boot()
noNewErrors("DCCompat, SharedExtendedMethods and DC-Talents load; start-up events")
ok(getmetatable(CreateFrame("Frame"):CreateTexture()).__index.SetAtlas ~= nil, "DC-Journal's SetAtlas is on the shared texture metatable (as in game)")
ok(ns.Traits ~= nil and ns.XML ~= nil and ns.UI ~= nil, "namespace has Traits / XML / UI")
ok(rawget(_G, "PlayerSpellsFrame") == nil, "the window is not built at load")
ok(rawget(_G, "TalentFrameBaseMixin") == nil and rawget(_G, "CreateFramePool") == nil, "retail globals stay out of _G")
ok(type(DCTalentsDB) == "table" and type(DCTalentsCharDB) == "table", "saved variables are real globals")
ok(ns.Server.IsAvailable(), "the TLNT server module answered HELLO")

-- ----------------------------------------------------------------------------
-- Open the window the way players do (N key / micro button)
-- ----------------------------------------------------------------------------

section("open")

ToggleTalentFrame()
SIM.Run(0.5)
noNewErrors("ToggleTalentFrame builds and opens the window")
local frame = rawget(_G, "PlayerSpellsFrame")
ok(frame ~= nil and frame:IsVisible(), "PlayerSpellsFrame is shown")
local env = ns.env
local talents = frame.TalentsFrame
ok(talents:IsVisible(), "the talents tab is the one shown")
ok(not frame:IsTabAvailable(frame.petTabID), "a warrior gets no Pet tab")

-- ----------------------------------------------------------------------------
-- Layout: the window fits, three trees side by side, every talent has a button
-- ----------------------------------------------------------------------------

section("layout")

do
	local L, B, R, T = SIM.Rect(frame)
	ok(L and L >= 0 and R <= SIM.SCREEN_W + 0.5 and B >= 0 and T <= SIM.SCREEN_H + 0.5,
		("the window fits the %dx%d UI (%.0f,%.0f - %.0f,%.0f)"):format(SIM.SCREEN_W, SIM.SCREEN_H, L or -1, B or -1, R or -1, T or -1))
end

local function ButtonFor(talentID)
	return talents:GetTalentButtonByNodeID(talentID)
end

local function NodeRank(talentID)
	local button = ButtonFor(talentID)
	local info = button and button:GetNodeInfo()
	return info and info.currentRank
end

local function TalentsOf(tabIndex, tier0)
	local list = {}
	for _, talentID in ipairs(warriorTabs[tabIndex].talents) do
		if tier0 == nil or SIM.TalentData[talentID][2] == tier0 then
			list[#list + 1] = talentID
		end
	end
	return list
end

do
	local missing, invisible = 0, 0
	local minX, maxX = {}, {}
	local centers = {}
	for tabIndex = 1, 3 do
		for _, talentID in ipairs(TalentsOf(tabIndex)) do
			local button = ButtonFor(talentID)
			if not button then
				missing = missing + 1
			elseif not button:IsVisible() then
				invisible = invisible + 1
			else
				local x, y = SIM.Rect(button)
				local l, b, r, t = SIM.Rect(button)
				local cx = l and (l + r) / 2
				if cx then
					minX[tabIndex] = math.min(minX[tabIndex] or math.huge, cx)
					maxX[tabIndex] = math.max(maxX[tabIndex] or -math.huge, cx)
					centers[#centers + 1] = { id = talentID, x = cx, y = (b + t) / 2 }
				end
			end
		end
	end
	ok(missing == 0, ("every warrior talent has a button (%d missing)"):format(missing))
	ok(invisible == 0, ("every talent button is visible (%d hidden)"):format(invisible))
	ok(maxX[1] and minX[2] and maxX[1] < minX[2] and maxX[2] < minX[3], "Arms, Fury and Protection sit side by side, left to right")
	local overlaps = 0
	for i = 1, #centers do
		for j = i + 1, #centers do
			if math.abs(centers[i].x - centers[j].x) < 20 and math.abs(centers[i].y - centers[j].y) < 20 then
				overlaps = overlaps + 1
			end
		end
	end
	ok(overlaps == 0, ("no two talent buttons overlap (%d pairs do)"):format(overlaps))
	local fL, fB, fR, fT = SIM.Rect(frame)
	local outside = 0
	for _, center in ipairs(centers) do
		if center.x < fL or center.x > fR or center.y < fB or center.y > fT then
			outside = outside + 1
		end
	end
	ok(outside == 0, ("every talent button lies inside the window (%d outside)"):format(outside))
end

do
	local prereqs = 0
	for tabIndex = 1, 3 do
		for _, talentID in ipairs(TalentsOf(tabIndex)) do
			if SIM.TalentData[talentID][5] ~= 0 then
				prereqs = prereqs + 1
			end
		end
	end
	ok(talents.edgePool:GetNumActive() == prereqs, ("one arrow per prerequisite (%d arrows, %d prerequisites)"):format(talents.edgePool:GetNumActive(), prereqs))

	-- Each arrow's line is drawn (a rotated quad needs a rect) and spans its two buttons.
	local drawn, spanning = 0, 0
	for edge in talents.edgePool:EnumerateActive() do
		local line = edge.Line
		local l, b, r, t = SIM.Rect(line)
		if l and SIM.IsVisible(line) then
			drawn = drawn + 1
			local sl, sb, sr, st = SIM.Rect(edge:GetStartButton())
			local el, eb, er, et = SIM.Rect(edge:GetEndButton())
			-- The line ends short of the second button's centre, at the arrow head.
			local _, _, offsetX, offsetY = line:GetEndPoint()
			local scale = SIM.EffectiveScale(line)
			local sx, sy = (sl + sr) / 2, (sb + st) / 2
			local ex, ey = (el + er) / 2 + offsetX * scale, (eb + et) / 2 + offsetY * scale
			local function Inside(x, y)
				return x >= l - 4 and x <= r + 4 and y >= b - 4 and y <= t + 4
			end
			if Inside(sx, sy) and Inside(ex, ey) then
				spanning = spanning + 1
			end
		end
	end
	ok(drawn == prereqs, ("every arrow's line is drawn (%d of %d)"):format(drawn, prereqs))
	ok(spanning == prereqs, ("every line runs from its first button towards the second (%d of %d)"):format(spanning, prereqs))
end

do
	-- Retail clips the border sheen to the node with a mask; 3.3.5 has none, so it must stay off.
	local sheens = 0
	for button in talents:EnumerateAllTalentButtons() do
		if button.BorderSheen and SIM.IsVisible(button.BorderSheen) then
			sheens = sheens + 1
		end
	end
	ok(sheens == 0, ("no talent shows the unmasked border sheen (%d do)"):format(sheens))

	-- A region retail gives no anchors fills its parent (the overlay that dims a busy tree).
	local overlay = talents.DisabledOverlay
	local ol, ob, orr, ot = SIM.Rect(overlay.GrayOverlay)
	local pl, pb, pr, pt = SIM.Rect(talents.ButtonsParent)
	ok(ol and math.abs(ol - pl) < 1 and math.abs(ot - pt) < 1 and math.abs(orr - pr) < 1 and math.abs(ob - pb) < 1,
		"the tree's dimming overlay fills the tree (retail's anchorless region)")

	-- The points counter: laid out, inside the bottom bar, clear of the tree headers.
	local display = talents.ClassCurrencyDisplay
	local dl, db, dr, dt = SIM.Rect(display)
	local ll, lb, lr, lt = SIM.Rect(display.CurrencyLabel)
	local al, ab, ar, at = SIM.Rect(display.CurrencyAmount)
	ok(display:IsVisible() and ll and al and (lr - ll) > 40 and (ar - al) > 4, "the points counter shows its label and amount")
	local bl, bb, br, bt = SIM.Rect(talents.BottomBar)
	ok(dl and dl >= bl and dr <= br and db >= bb - 6 and dt <= bt + 6, "the points counter sits in the bottom bar")
	local clash = 0
	for _, header in ipairs(talents.dcTreeHeaders) do
		local hl, hb, hr, ht = SIM.Rect(header)
		if hl and dl and hl < dr and hr > dl and hb < dt and ht > db then
			clash = clash + 1
		end
	end
	ok(clash == 0, "the points counter does not overlap a tree header")
end

do
	local headers = talents.dcTreeHeaders
	ok(headers and headers[1]:IsVisible() and headers[1].Name:GetText() == "ARMS" and headers[1].Points:GetText() == "5",
		"the Arms header reads ARMS / 5")
	ok(headers and headers[3].Name:GetText() == "PROTECTION" and headers[3].Points:GetText() == "0", "the Protection header reads PROTECTION / 0")
	local points = talents.treeCurrencyInfo and talents.treeCurrencyInfo[1]
	ok(points and points.quantity == CLIENT.TotalPoints() - 5, "71 - 5 = 66 talent points available")
end
noNewErrors("layout")

-- ----------------------------------------------------------------------------
-- Spend, apply, refund
-- ----------------------------------------------------------------------------

section("spend and apply")

local fury1 = TalentsOf(2, 0)[1]
ButtonFor(fury1):Click("LeftButton")
SIM.Run(0.2)
ok(NodeRank(fury1) == 1, "a left click stages one rank")
ok(CLIENT.ranks[1][fury1] == nil, "nothing is learned before Apply")
ok(talents:HasAnyConfigChanges(), "the frame knows it has staged changes")
ok(talents.ApplyButton:IsEnabled(), "Apply Changes is enabled")
ok(talents.treeCurrencyInfo[1].quantity == CLIENT.TotalPoints() - 6, "the staged rank costs a point")

local sentBefore = #DCAddonProtocol.sent
talents.ApplyButton:Click("LeftButton")
SIM.Run(1)
local request = DCAddonProtocol.sent[sentBefore + 1]
ok(request and request.module == "TLNT" and request.opcode == 0x02, "Apply sends one APPLY_BUILD")
ok(CLIENT.ranks[1][fury1] == 1, "the server learned the staged rank")
ok(not talents:HasAnyConfigChanges(), "nothing is staged after the commit")
ok(NodeRank(fury1) == 1, "the button shows the learned rank")
noNewErrors("spend and apply")

section("refund")

ButtonFor(fury1):Click("RightButton")
SIM.Run(0.2)
ok(NodeRank(fury1) == 0, "a right click on a learned rank stages its refund (free respec)")
talents.ApplyButton:Click("LeftButton")
SIM.Run(1)
ok(CLIENT.ranks[1][fury1] == nil, "the server unlearned it")
ok(CLIENT.Spent(false, 1) == 5, "the other talents are untouched")
noNewErrors("refund")

section("gates and prerequisites")

local prot2 = TalentsOf(3, 1)[1]
local prot2Info = ButtonFor(prot2):GetNodeInfo()
ok(prot2Info and not prot2Info.isAvailable and not prot2Info.canPurchaseRank, "a tier-2 Protection talent is locked with 0 points in Protection")
ButtonFor(prot2):Click("LeftButton")
SIM.Run(0.2)
ok(NodeRank(prot2) == 0, "clicking a locked talent does nothing")
do
	local gates, texts = 0, {}
	for gate in talents.gatePool:EnumerateActive() do
		gates = gates + 1
		texts[#texts + 1] = gate.GateText:GetText()
	end
	ok(gates == 3, ("one gate per tree (%d shown: %s)"):format(gates, table.concat(texts, ",")))
end

do
	local withPrereq
	for _, talentID in ipairs(TalentsOf(1)) do
		local data = SIM.TalentData[talentID]
		if data[5] ~= 0 and (CLIENT.ranks[1][data[5]] or 0) < data[6] then
			withPrereq = talentID
			break
		end
	end
	local info = withPrereq and ButtonFor(withPrereq):GetNodeInfo()
	ok(info and not info.meetsEdgeRequirements and not info.canPurchaseRank, "a talent whose prerequisite is not maxed cannot be bought")
end
noNewErrors("gates and prerequisites")

section("tooltip")

do
	local arms1 = TalentsOf(1, 0)[1]
	local button = ButtonFor(arms1)
	SIM.CallScript(button, "OnEnter")
	local text = SIM.TooltipText(GameTooltip)
	ok(GameTooltip:IsShown() and text:find("Talent" .. arms1, 1, true), "hovering a talent shows its name")
	ok(text:find("does something useful", 1, true) ~= nil, "the tooltip carries the rank's spell description")
	SIM.CallScript(button, "OnLeave")
	ok(not GameTooltip:IsShown(), "leaving the button hides the tooltip")
end
noNewErrors("tooltip")

-- ----------------------------------------------------------------------------
-- Loadouts: create, export, import, load, the per-loadout submenu
-- ----------------------------------------------------------------------------

section("loadouts")

local loadSystem = talents.LoadSystem
local dropdown = loadSystem:GetDropdown()

local function OpenLoadoutMenu()
	CloseDropDownMenus()
	dropdown:OpenMenu()
	return SIM.MenuEntries(1)
end

local function EntryTexts(level)
	local texts = {}
	for _, entry in ipairs(SIM.MenuEntries(level)) do
		texts[#texts + 1] = tostring(entry.text)
	end
	return table.concat(texts, " | ")
end

OpenLoadoutMenu()
ok(SIM.FindMenuEntry(1, env.TALENT_FRAME_DROP_DOWN_NEW_LOADOUT) ~= nil, "the dropdown offers New Loadout (" .. EntryTexts(1) .. ")")
ok(SIM.FindMenuEntry(1, env.TALENT_FRAME_DROP_DOWN_IMPORT) ~= nil, "the dropdown offers Import")
SIM.ClickMenuEntry(1, env.TALENT_FRAME_DROP_DOWN_NEW_LOADOUT)
SIM.Run(0.1)
local createDialog = env.ClassTalentLoadoutCreateDialog
ok(createDialog and createDialog:IsShown(), "New Loadout opens the create dialog")
-- Retail only clears the name on hide, so Accept starts enabled; an empty name disables it.
createDialog.NameControl:GetEditBox():SetText("   ")
ok(not createDialog.AcceptButton:IsEnabled(), "a blank name disables Accept")
createDialog.NameControl:GetEditBox():SetText("Arms PvE")
ok(createDialog.AcceptButton:IsEnabled(), "typing a name enables Accept")
createDialog.AcceptButton:Click("LeftButton")
SIM.Run(0.5)
noNewErrors("create a loadout")

local classData = DCTalentsDB.classes and DCTalentsDB.classes.WARRIOR
local firstID = classData and classData.order[1]
local firstLoadout = firstID and classData.loadouts[firstID]
ok(firstLoadout and firstLoadout.name == "Arms PvE", "the loadout is saved per class")
ok(firstLoadout and firstLoadout.ranks[TalentsOf(1, 0)[1]] ~= nil, "it holds the current build")
ok(firstLoadout and loadSystem:GetSelectionID() == ns.Traits.CONFIG_LOADOUT_BASE + firstID, "the new loadout is selected")
ok(not createDialog:IsShown(), "the create dialog closed")

-- Export through Share > Copy to Clipboard: the copy dialog shows the string.
OpenLoadoutMenu()
local shareEntry = SIM.FindMenuEntry(1, env.TALENT_FRAME_DROP_DOWN_EXPORT)
ok(shareEntry and shareEntry.hasArrow, "Share opens a submenu")
local exported
if shareEntry then
	SIM.OpenSubmenu(1, env.TALENT_FRAME_DROP_DOWN_EXPORT)
	ok(SIM.FindMenuEntry(2, env.TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK) == nil, "no Link to Chat (3.3.5 servers drop unknown hyperlinks)")
	SIM.ClickMenuEntry(2, env.TALENT_FRAME_DROP_DOWN_EXPORT_CLIPBOARD)
	local _, copyDialog = StaticPopup_Visible("DC_TALENTS_COPY")
	exported = copyDialog and copyDialog.wideEditBox:GetText()
	ok(exported and #exported > 20, "the copy dialog holds the loadout string")
	if copyDialog then
		SIM.ClickPopup("DC_TALENTS_COPY", 1)
	end
end
noNewErrors("export")

-- Retail saves an Apply into the selected loadout. Make a second loadout, change the build there,
-- then load the first one back: the server gets the old build.
local exportedRanks = CopyTable(firstLoadout and firstLoadout.ranks or {})
OpenLoadoutMenu()
SIM.ClickMenuEntry(1, env.TALENT_FRAME_DROP_DOWN_NEW_LOADOUT)
createDialog.NameControl:GetEditBox():SetText("Fury test")
createDialog.AcceptButton:Click("LeftButton")
SIM.Run(0.5)
ok(#classData.order == 2 and loadSystem:GetSelectionID() == ns.Traits.CONFIG_LOADOUT_BASE + classData.order[2], "a second loadout is created and selected")
ButtonFor(fury1):Click("LeftButton")
talents.ApplyButton:Click("LeftButton")
SIM.Run(1)
ok(CLIENT.ranks[1][fury1] == 1, "the build changed")
ok(classData.loadouts[classData.order[2]].ranks[fury1] == 1, "Apply saved the change into the selected loadout (retail)")
ok(firstLoadout.ranks[fury1] == nil, "the first loadout is untouched")

OpenLoadoutMenu()
ok(SIM.FindMenuEntry(1, "Arms PvE") ~= nil, "the loadout is listed (" .. EntryTexts(1) .. ")")
SIM.ClickMenuEntry(1, "Arms PvE")
SIM.Run(1)
noNewErrors("load a loadout")
ok(CLIENT.ranks[1][fury1] == nil, "loading the loadout unlearned the Fury point (free respec)")
ok(CLIENT.Spent(false, 1) == 5, "and restored the saved 5-point build")

-- Import the exported string as a second loadout.
OpenLoadoutMenu()
SIM.ClickMenuEntry(1, env.TALENT_FRAME_DROP_DOWN_IMPORT)
local importDialog = env.ClassTalentLoadoutImportDialog
ok(importDialog and importDialog:IsShown(), "Import opens the import dialog")
if importDialog and exported then
	importDialog.ImportControl:GetEditBox():SetText(exported)
	importDialog.NameControl:GetEditBox():SetText("Imported")
	ok(importDialog.AcceptButton:IsEnabled(), "a string and a name enable Accept")
	importDialog.AcceptButton:Click("LeftButton")
	SIM.Run(0.5)
	local importedID = classData.order[3]
	local imported = importedID and classData.loadouts[importedID]
	ok(imported and imported.name == "Imported", "the string became a new loadout")
	local same = imported ~= nil and next(exportedRanks) ~= nil
	for talentID, rank in pairs(exportedRanks) do
		if not imported or imported.ranks[talentID] ~= rank then
			same = false
		end
	end
	for talentID, rank in pairs(imported and imported.ranks or {}) do
		if exportedRanks[talentID] ~= rank then
			same = false
		end
	end
	ok(same, "the imported loadout has exactly the exported ranks")
end
noNewErrors("import")

-- The loadout submenu: Edit (retail's gear button) plus the DC extras.
OpenLoadoutMenu()
local loadoutEntry = SIM.FindMenuEntry(1, "Arms PvE")
ok(loadoutEntry and loadoutEntry.hasArrow, "a loadout entry has a submenu")
if loadoutEntry and loadoutEntry.hasArrow then
	SIM.OpenSubmenu(1, "Arms PvE")
	ok(SIM.FindMenuEntry(2, env.TALENT_FRAME_DROP_DOWN_TOOLTIP_EDIT) ~= nil, "the submenu offers Edit (" .. EntryTexts(2) .. ")")
	ok(SIM.FindMenuEntry(2, ns.L.MENU_DUPLICATE) ~= nil, "and Duplicate")
	SIM.ClickMenuEntry(2, ns.L.MENU_DUPLICATE)
	SIM.Run(0.2)
	ok(#classData.order == 4 and classData.loadouts[classData.order[4]].name == "Arms PvE (2)", "Duplicate adds 'Arms PvE (2)'")
end
noNewErrors("loadout submenu")
CloseDropDownMenus()

-- ----------------------------------------------------------------------------
-- Specialization tab: the two talent groups, dual-spec activation
-- ----------------------------------------------------------------------------

section("specialization tab")

local FrameTabs = env.PlayerSpellsUtil.FrameTabs
frame:TrySetTab(FrameTabs.ClassSpecializations)
SIM.Run(0.3)
local specFrame = frame.SpecFrame
ok(specFrame:IsVisible() and not talents:IsVisible(), "the Specialization tab replaces the talents")
local cards = {}
for card in specFrame.SpecContentFramePool:EnumerateActive() do
	cards[card.specIndex] = card
end
ok(cards[1] ~= nil and cards[2] ~= nil and cards[3] == nil, "one card per talent group")
ok(cards[1] and cards[1].SpecName:GetText() == "Arms", "group 1 is named after its primary tree (" .. tostring(cards[1] and cards[1].SpecName:GetText()) .. ")")
ok(cards[1] and (cards[1].Description:GetText() or ""):find("Arms 5", 1, true) ~= nil, "its description shows the point split")
ok(cards[1] and cards[1].SpecImage:GetAtlas() == "spec-thumbnail-warrior-arms", "and retail's Arms thumbnail")
ok(cards[1] and cards[1].ActivatedText:IsShown() and not cards[1].ActivateButton:IsShown(), "the active group shows as activated")
ok(cards[2] and cards[2].ActivateButton:IsShown() and cards[2].ActivateButton:IsEnabled(), "the other group offers Activate")

do
	-- Retail mirrors atlas art with TexCoords (1, 0, 0, 1) relative to the atlas: the coordinates
	-- that reach the client must stay inside the atlas' part of the sheet, or the card shows
	-- whatever else the sheet holds (the yellow slabs).
	local checked, outside = 0, {}
	SIM.Walk(specFrame, function(object)
		local st = SIM.S[object]
		local rect = object.__dcAtlasRect
		if st and st.type == "Texture" and rect and st.texCoord and SIM.IsVisible(object) then
			checked = checked + 1
			local c = st.texCoord
			local us = #c == 8 and { c[1], c[3], c[5], c[7] } or { c[1], c[2] }
			local vs = #c == 8 and { c[2], c[4], c[6], c[8] } or { c[3], c[4] }
			local uMin, uMax = math.min(rect[1], rect[2]), math.max(rect[1], rect[2])
			local vMin, vMax = math.min(rect[3], rect[4]), math.max(rect[3], rect[4])
			for _, u in ipairs(us) do
				if u < uMin - 1e-4 or u > uMax + 1e-4 then
					outside[#outside + 1] = SIM.Describe(object)
					return
				end
			end
			for _, v in ipairs(vs) do
				if v < vMin - 1e-4 or v > vMax + 1e-4 then
					outside[#outside + 1] = SIM.Describe(object)
					return
				end
			end
		end
	end)
	ok(checked > 0 and #outside == 0, ("atlas art on the cards stays inside its atlas (%d checked; outside: %s)"):format(checked, table.concat(outside, ", ")))

	local roleTextures, wrongSheet = 0, 0
	SIM.Walk(specFrame, function(object)
		local atlas = object.__dcAtlas
		if type(atlas) == "string" and atlas:find("^UI%-LFG%-RoleIcon") and SIM.IsVisible(object) then
			roleTextures = roleTextures + 1
			if SIM.S[object].texture ~= "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES" then
				wrongSheet = wrongSheet + 1
			end
		end
	end)
	ok(roleTextures > 0 and wrongSheet == 0, ("the role icons use the small round role sheet (%d icons, %d wrong)"):format(roleTextures, wrongSheet))
end
noNewErrors("specialization tab")

if cards[2] then
	cards[2].ActivateButton:Click("LeftButton")
	SIM.Run(0.5)
	ok(CLIENT.player.casting ~= nil, "Activate casts the dual-spec spell")
	SIM.Run(6)
	ok(CLIENT.player.activeGroup == 2, "after the cast, group 2 is active")
	ok(cards[2].ActivatedText:IsShown() and cards[1].ActivateButton:IsShown(), "the cards follow the switch")
	noNewErrors("dual-spec switch")

	frame:TrySetTab(FrameTabs.ClassTalents)
	SIM.Run(0.3)
	ok(talents.treeCurrencyInfo[1].quantity == CLIENT.TotalPoints(), "group 2 starts with all points free")
	ok(talents.dcTreeHeaders[1].Points:GetText() == "0", "and empty trees")
	ok(NodeRank(TalentsOf(1, 0)[1]) == 0, "the talent buttons show group 2")

	-- Switch back through the spec tab, interrupted once.
	frame:TrySetTab(FrameTabs.ClassSpecializations)
	SIM.Run(0.2)
	cards[1].ActivateButton:Click("LeftButton")
	SIM.Run(0.5)
	SIM.InterruptCast()
	SIM.Run(0.2)
	ok(not specFrame:IsActivateInProgress(), "an interrupted activation clears the pending state (3.3.5 events carry names)")
	cards[1].ActivateButton:Click("LeftButton")
	SIM.Run(6)
	ok(CLIENT.player.activeGroup == 1, "group 1 is active again")
	noNewErrors("switch back")
end

-- ----------------------------------------------------------------------------
-- Glyphs tab: the stock glyph frame, borrowed
-- ----------------------------------------------------------------------------

section("glyphs tab")

frame:TrySetTab(FrameTabs.Glyphs)
SIM.Run(0.2)
ok(GlyphFrame and GlyphFrame:IsVisible() and GlyphFrame:GetParent() == DCTalentsGlyphPage, "the Glyphs tab shows the stock glyph frame inside the window")
ok(frame.TitleContainer.TitleText:GetText() == GLYPHS, "the title reads Glyphs")
do
	local page = DCTalentsGlyphPage
	ok(SIM.IsVisible(page.Art) and page.Art.__dcAtlas == "talents-background-warrior-arms" and SIM.IsVisible(page.BottomBar),
		"the glyph tab shows the class art over the bottom bar, like the talents tab")
	ok(SIM.IsVisible(page.Portrait) and SIM.S[page.Portrait].texture == "portrait:player", "the glyph frame's portrait hole shows the player")
	local cl, cb, cr, ct = SIM.Rect(page.CloseButton)
	local gl, gb, gr, gt = SIM.Rect(GlyphFrame)
	ok(page.CloseButton:IsVisible() and cl and cl > gl and cr < gr and ct < gt and cb > (gt - 80)
		and page.CloseButton:GetFrameLevel() > GlyphFrame:GetFrameLevel(), "and its close-button slot holds a close button")
end
frame:TrySetTab(FrameTabs.ClassTalents)
SIM.Run(0.2)
ok(GlyphFrame and not GlyphFrame:IsShown(), "leaving the tab puts the glyph frame away")
noNewErrors("glyphs tab")

-- ----------------------------------------------------------------------------
-- Closing, the stock frame, combat, a server without the module
-- ----------------------------------------------------------------------------

section("close and stock frame")

do
	-- The X sits in the top-right corner, above the metal border that covers that corner.
	local close = frame.CloseButton
	local cl, cb, cr, ct = SIM.Rect(close)
	local fl, fb, fr, ft = SIM.Rect(frame)
	ok(close:IsVisible() and cl and cr > fr - 40 and ct > ft - 40 and close:GetFrameLevel() > frame.NineSlice:GetFrameLevel()
		and SIM.S[close:GetNormalTexture()].texture ~= nil, "the window has a visible close button in its top-right corner")
	close:Click("LeftButton")
	ok(not frame:IsShown(), "the close button closes the window")
	SlashCmdList.DCTALENTS("")
end
CloseSpecialWindows()
ok(not frame:IsShown(), "Escape closes the window")
SIM.keys.shift = true
ToggleTalentFrame()
SIM.keys.shift = false
ok(PlayerTalentFrame and PlayerTalentFrame:IsShown() and not frame:IsShown(), "Shift+N opens the stock talent frame")
HideUIPanel(PlayerTalentFrame)
SlashCmdList.DCTALENTS("")
ok(frame:IsShown() and talents:IsVisible(), "/talents opens the talents tab")
local chatBefore = #SIM.chat
SlashCmdList.DCTALENTS("debug")
local gateLines = 0
for i = chatBefore + 1, #SIM.chat do
	if tostring(SIM.chat[i]):find("gate %d+: shown y visible y") then
		gateLines = gateLines + 1
	end
end
ok(#SIM.chat > chatBefore and gateLines > 0, ("/talents debug reports the layering and the shown gates (%d)"):format(gateLines))
noNewErrors("close and stock frame")

section("combat")

CLIENT.player.inCombat = true
SIM.FireEvent("PLAYER_REGEN_DISABLED")
SIM.Run(0.1)
local sentInCombat = #DCAddonProtocol.sent
ButtonFor(fury1):Click("LeftButton")
talents.ApplyButton:Click("LeftButton")
SIM.Run(1)
ok(#DCAddonProtocol.sent == sentInCombat, "nothing is sent to the server in combat")
ok(CLIENT.ranks[1][fury1] == nil, "and nothing is learned")
CLIENT.player.inCombat = false
SIM.FireEvent("PLAYER_REGEN_ENABLED")
SIM.Run(0.1)
if talents:HasAnyConfigChanges() then
	talents.UndoButton:Click("LeftButton")
	SIM.Run(0.2)
end
ok(not talents:HasAnyConfigChanges(), "nothing is left staged")
noNewErrors("combat")

section("server without the module")

ns.Server.state.hello = nil
SIM.FireEvent("PLAYER_TALENT_UPDATE")
SIM.Run(0.3)
local arms1 = TalentsOf(1, 0)[1]
local armsInfo = ButtonFor(arms1):GetNodeInfo()
ok(armsInfo and not armsInfo.canRefundRank, "learned ranks cannot be refunded without the server module")
local sentNoServer = #DCAddonProtocol.sent
ButtonFor(fury1):Click("LeftButton")
SIM.Run(0.2)
talents.ApplyButton:Click("LeftButton")
SIM.Run(1)
ok(#DCAddonProtocol.sent == sentNoServer, "additions do not go to the missing module")
ok(CLIENT.ranks[1][fury1] == 1, "they are learned through the stock preview-talent path")
ok(not talents:HasAnyConfigChanges(), "and the commit completes")
noNewErrors("server without the module")

T.Finish()
