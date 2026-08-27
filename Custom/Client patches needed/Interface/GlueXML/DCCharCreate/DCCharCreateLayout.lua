--[[----------------------------------------------------------------------------------------------
DCCharCreateLayout.lua -- the Shadowlands two-stage create flow, over the stock 3.3.5a frames.

Retail splits character creation into two stages, and it is not decoration: with the model
full-screen there is only room for ONE panel per side, so race info and customization cannot both
occupy the right. Same constraint here, same answer.

    Stage 1  CHOOSE     race grid (left, per faction), class row, gender,
                        stock race/class info panels (right)          [Next ->]
    Stage 2  CUSTOMIZE  categorised customization panel (right),
                        name entry (bottom centre)            [<- Back] [Create]

Nothing is reimplemented. The stock race/class buttons keep their own icons, enable/disable and
checked state - they are only RE-ANCHORED into grids, so CharacterCreateEnumerateRaces and friends
keep working untouched. Stage switching is show/hide plus two function hooks.

Frames are resolved by name with nil guards throughout: this file is injected into the live create
screen, and one nil index would take the whole screen down with it.

Relies on DCCharCreateUI.lua having built DCCharCustomizePanel (it loads first).
------------------------------------------------------------------------------------------------]]

-- 4 columns since Pandaren: 7 races per faction at 3 columns meant 3+3 rows and pushed
-- the class grid off the bottom of the screen; 4 columns keeps each faction at 2 rows.
local RACE_COLUMNS = 4
local RACE_SPACING = 8
-- Race icons are the focal point of stage 1 and the stock size is small on a large display.
-- Set explicitly (not via SetScale) so the grid maths stays in one coordinate space.
local RACE_BUTTON_SIZE = 68

-- CharacterCreateIconButtonTemplate is 38x38 and carries child regions with HARDCODED sizes,
-- anchored CENTER. Only the NormalTexture stretches with the button - the rest keep their original
-- size, so enlarging the button alone leaves a 38px bevel rectangle floating in the middle of a
-- 68px icon (it looked like a stray button drawn on every portrait). Scale them to match.
local ICON_TEMPLATE_BASE = 38
local ICON_CHILD_BASE = {
	Shadow = 58,            -- $parentShadow, drop shadow, deliberately larger than the button
	BevelEdge = 38,         -- $parentBevelEdge, the visible offender
	DisableTexture = 38,
	PushedTexture = 38,
}
-- Must fit the HORDE crest BETWEEN the two grids. The crest is FACTION_ICON_H tall, so a gap
-- sized only for a text caption leaves it overlapping the Alliance grid's last row.
local FACTION_GAP = 70
-- Header baseline below the panel border, and the gap from panel top down to the first grid row.
-- HEADER_TOP must clear the backdrop edge (inset 4) or the caption prints on the border itself.
local HEADER_TOP = -6
-- Must clear the faction crest (FACTION_ICON_H + its top offset), or the race buttons - which
-- are separate frames and therefore draw ABOVE racePanel textures - cover the crest.
local HEADER_INSET = 62
-- Gender and class captions have no crest beside them, so they need only enough room for the
-- caption itself. Reusing HEADER_INSET (sized for the 50px faction crest) left a large dead gap
-- between each caption and its buttons.
local SUB_INSET = 28

local CLASS_COLUMNS = 5
local CLASS_SPACING = 6
local PANEL_PADDING = 10        -- gap between a panel's backdrop border and its content

-- DC runs ARAC (all races / all classes), so every race offers all ten classes and the class grid
-- is always full width. It is also the WIDEST element in the left column, which is why the panels
-- are sized from measured content instead of a fixed width - the first build hardcoded one and the
-- class row grew straight through its border.
local raceGridWidth, classGridWidth = 0, 0

-- Faction crest size. Source art is 184x200, so the ratio is kept to avoid squashing.
local FACTION_ICON_H = 50
local FACTION_ICON_W = 46

-- Y of the HORDE caption inside racePanel, computed by LayoutRaceButtons and reused by
-- BuildFactionIcons so the crest lands on the same line.
local hordeCaptionY = 0

-- The horde crest texture, once built; a re-layout moves it (and the caption anchored to it).
local hordeCrest

local PANEL_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local STAGE_CHOOSE, STAGE_CUSTOMIZE = 1, 2
local stage = STAGE_CHOOSE

-- Stock art that belongs to the old layout. Regions (textures/fontstrings), not frames, so they
-- are hidden individually rather than by hiding a parent.
local RETIRED_ART = {
	"CharacterCreateBanners",              -- Alliance/Horde banner columns
	"CharacterCreateOuterBorder1",
	"CharacterCreateOuterBorder2",
	"CharacterCreateOuterBorder3",
	"CharacterCreateConfigurationBackground",
	-- Faction captions: this layout draws its own above each grid, and the stock pair stays
	-- anchored to where the banners used to be - they floated at the top of the screen.
	"CharacterCreateAllianceLabel",
	"CharacterCreateHordeLabel",
}

-- The selected race's name. NOT retired: the stock selection code calls :Show() on these, so
-- hiding them once does not stick - the caption reappeared on top of the ALLIANCE header. They are
-- repositioned into the bottom of the race panel instead, mirroring how the class name sits under
-- the class grid.
local RACE_NAME_REGIONS = { "CharacterCreateAllianceRaceLabel", "CharacterCreateHordeRaceLabel" }

-- Shown only while choosing a race/class.
local STAGE1_FRAMES = {
	"CharacterCreateCharacterRace",        -- racial abilities panel
	"CharacterCreateCharacterClass",       -- class description panel
	"CharacterCreateGenderButtonMale",
	"CharacterCreateGenderButtonFemale",
}

local STAGE1_REGIONS = {
	"CharacterCreateGender",
	"CharacterCreateClassName",
	"CharacterCreateClassText",
}

local function Frame(name)
	return _G[name]
end

-- ---------------------------------------------------------------------------------- atlas

-- DCApplyAtlas / DCBuildVignette live in DCGlueAtlas.lua, shared with character select.
local ApplyAtlas = DCApplyAtlas

local function BuildVignette()
	DCBuildVignette(CharacterCreate, "DCCharCreateVignette")
end

-- BuildFactionIcons lives further down, after racePanel and the header FontStrings exist: a
-- function defined above a `local` captures the GLOBAL of that name (nil), not the upvalue.

local function SetShown(object, shown)
	if not object then
		return
	end
	if shown then object:Show() else object:Hide() end
end

-- ---------------------------------------------------------------------------------- containers

local racePanel = CreateFrame("Frame", "DCCharCreateRacePanel", CharacterCreate)
racePanel:SetPoint("TOPLEFT", 28, -20)
racePanel:SetWidth(240)
racePanel:SetHeight(200)

local allianceHeader = racePanel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightLarge")
allianceHeader:SetPoint("TOPLEFT", PANEL_PADDING, HEADER_TOP)
allianceHeader:SetText("|cff7f9fffALLIANCE|r")

local hordeHeader = racePanel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightLarge")
hordeHeader:SetText("|cffff6060HORDE|r")

racePanel:SetBackdrop(PANEL_BACKDROP)
racePanel:SetBackdropColor(0, 0, 0, 0.55)
racePanel:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.8)

-- Gender sits between the race and class grids. The stock buttons keep their own art and OnClick;
-- like the race buttons they are only re-anchored - but they DO have to move, because the class
-- grid now occupies the space they used to own (they collided on the first build).
local genderPanel = CreateFrame("Frame", "DCCharCreateGenderPanel", CharacterCreate)
genderPanel:SetWidth(240)
genderPanel:SetHeight(46)

local genderHeader = genderPanel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightLarge")
genderHeader:SetPoint("TOPLEFT", PANEL_PADDING, HEADER_TOP)
genderHeader:SetText("|cffffd200GENDER|r")

local classPanel = CreateFrame("Frame", "DCCharCreateClassPanel", CharacterCreate)
classPanel:SetWidth(240)
classPanel:SetHeight(90)
classPanel:SetBackdrop(PANEL_BACKDROP)
classPanel:SetBackdropColor(0, 0, 0, 0.55)
classPanel:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.8)

local classHeader = classPanel:CreateFontString(nil, "OVERLAY", "GlueFontHighlightLarge")
classHeader:SetPoint("TOPLEFT", PANEL_PADDING, HEADER_TOP)
classHeader:SetText("|cffffd200CLASS|r")

--- Faction crests beside the two grid captions. Defined here, below the headers it anchors to.
--- The crest is placed at the caption's own slot and the caption is pushed right to make room -
--- anchoring the crest to the LEFT of the caption instead put it outside the panel border.
local function BuildFactionIcons()
	for _, item in ipairs({ { "charactercreate-icon-alliance", allianceHeader, HEADER_TOP },
	                        { "charactercreate-icon-horde", hordeHeader, hordeCaptionY } }) do
		local atlasName, header, top = item[1], item[2], item[3]
		local texture = racePanel:CreateTexture(nil, "OVERLAY")
		if header == hordeHeader then
			hordeCrest = texture
		end
		if ApplyAtlas(texture, atlasName) then
			texture:SetWidth(FACTION_ICON_W)
			texture:SetHeight(FACTION_ICON_H)
			-- Source art is 184x200, so keep that aspect or the crest looks squashed.
			texture:SetPoint("TOPLEFT", racePanel, "TOPLEFT",
				PANEL_PADDING, top + 2)
			-- Centred on the crest rather than top-aligned; with a 50px crest a top-aligned
			-- caption floats level with the crest's helmet instead of reading beside it.
			header:ClearAllPoints()
			header:SetPoint("LEFT", texture, "RIGHT", 8, 0)
		end
	end
end

-- ---------------------------------------------------------------------------------- race grid

--- Swap a race button's "selected" highlight for a selection border that follows the icon.
---
--- Retail's own art (charactercreate-ring-select) is a CIRCLE, because retail's race buttons are
--- round; ours are square, so the ring cut across the portrait's corners. This uses a generated
--- rounded-SQUARE outline instead (tools/make_selection_border.py) whose glow falls outward, so the
--- portrait underneath stays fully visible.
---
--- Applied as the CheckedTexture anchored CENTER, which means the stock selection code drives it -
--- nothing here has to track which race is selected. The texture is drawn LARGER than the button
--- because the outline sits at 76% of the art's extent (the rest is glow): 1/0.76 = 1.32, so the
--- outline lands just outside the icon edge. Change one and the other must follow.
local function ApplySelectionRing(button)
	if not (button.GetCheckedTexture and DCCharCreateAtlas) then
		return
	end
	local checked = button:GetCheckedTexture()
	if not (checked and ApplyAtlas(checked, "charactercreate-border-select")) then
		return
	end
	local size = RACE_BUTTON_SIZE * 1.32
	checked:ClearAllPoints()
	checked:SetPoint("CENTER", button, "CENTER", 0, 0)
	checked:SetWidth(size)
	checked:SetHeight(size)
	if checked.SetBlendMode then
		checked:SetBlendMode("ADD")
	end
end

--- Resize an icon button's fixed-size child regions to match an enlarged button.
local function ScaleIconChildren(buttonName)
	local factor = RACE_BUTTON_SIZE / ICON_TEMPLATE_BASE
	for suffix, base in pairs(ICON_CHILD_BASE) do
		local region = Frame(buttonName .. suffix)
		if region and region.SetWidth then
			region:SetWidth(base * factor)
			region:SetHeight(base * factor)
		end
	end
end

--- Re-anchor the stock race buttons into two faction grids.
--- The button index space IS the enumeration index space (button 1 anchors TOP x=-50, button 7
--- TOP x=+50 in the stock XML; GetSelectedRace() returns list index 10 for Troll). The client
--- orders the Alliance block first, then Horde - but the SIZE of each block moved when Pandaren
--- (races 22/23) was added, so the split is resolved per index via GetFactionForRace instead of
--- the old fixed 1-6/7-12 rule (which dropped race 13 into the Horde grid and never re-anchored
--- buttons 13/14 at all).
local function RaceButtonFaction(index)
	local ok, _, faction = pcall(GetFactionForRace, index)
	if ok and (faction == "Alliance" or faction == "Horde") then
		return faction
	end
	return nil
end

local function LayoutRaceButtons()
	local first = Frame("CharacterCreateRaceButton1")
	if not first then
		return 0
	end

	local step = RACE_BUTTON_SIZE + RACE_SPACING

	local factions, total, allianceCount = {}, 0, 0
	for index = 1, (MAX_RACES or 14) do
		if not Frame("CharacterCreateRaceButton" .. index) then
			break
		end
		total = index
		factions[index] = RaceButtonFaction(index) or ((index <= 6) and "Alliance" or "Horde")
		if factions[index] == "Alliance" then
			allianceCount = allianceCount + 1
		end
	end

	local allianceRows = math.ceil(math.max(allianceCount, 1) / RACE_COLUMNS)
	local hordeRows = math.ceil(math.max(total - allianceCount, 1) / RACE_COLUMNS)
	local allianceTop = -HEADER_INSET
	local hordeTop = allianceTop - allianceRows * step - FACTION_GAP

	-- Sit the caption just above its own grid. The first attempt added a row step here, which put
	-- HORDE on top of the Alliance second row instead.
	hordeCaptionY = hordeTop + HEADER_INSET + HEADER_TOP
	if hordeCrest then
		-- Re-layout (OnShow): the caption is anchored LEFT of the crest, so moving the
		-- crest carries it. Re-anchoring the caption itself would stack a second point.
		hordeCrest:ClearAllPoints()
		hordeCrest:SetPoint("TOPLEFT", racePanel, "TOPLEFT", PANEL_PADDING, hordeCaptionY + 2)
	else
		hordeHeader:SetPoint("TOPLEFT", PANEL_PADDING, hordeCaptionY)
	end

	local placed = 0
	local slots = { Alliance = 0, Horde = 0 }
	for index = 1, total do
		local button = Frame("CharacterCreateRaceButton" .. index)
		if button then
			local faction = factions[index]
			local slot = slots[faction]
			slots[faction] = slot + 1
			local top = (faction == "Alliance") and allianceTop or hordeTop
			local column = slot % RACE_COLUMNS
			local row = math.floor(slot / RACE_COLUMNS)

			button:SetWidth(RACE_BUTTON_SIZE)
			button:SetHeight(RACE_BUTTON_SIZE)
			ScaleIconChildren("CharacterCreateRaceButton" .. index)
			ApplySelectionRing(button)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", racePanel, "TOPLEFT",
				PANEL_PADDING + column * step, top - row * step)

			-- Each race button carries its own name FontString child, which stock fills in for the
			-- selected race (CharacterCreate.lua: CharacterCreateRaceButton<i>Text). In the stock
			-- single-column layout it had empty space beside it; in a grid it prints straight over
			-- the neighbouring icon. Hidden here - the race info panel on the right already names
			-- the selection. Only SetText is ever called on it, so Hide() sticks.
			local caption = Frame("CharacterCreateRaceButton" .. index .. "Text")
			if caption then
				caption:Hide()
			end
			placed = placed + 1
		end
	end

	-- Park the race-name captions inside the panel, under the Horde grid.
	local captionTop = hordeTop - hordeRows * step - 4
	for _, name in ipairs(RACE_NAME_REGIONS) do
		local caption = Frame(name)
		if caption and caption.ClearAllPoints then
			caption:ClearAllPoints()
			caption:SetPoint("TOPLEFT", racePanel, "TOPLEFT", PANEL_PADDING, captionTop)
		end
	end

	raceGridWidth = RACE_COLUMNS * step - RACE_SPACING
	racePanel:SetHeight(math.abs(captionTop) + 22)

	genderPanel:ClearAllPoints()
	genderPanel:SetPoint("TOPLEFT", racePanel, "BOTTOMLEFT", 0, -8)
	classPanel:ClearAllPoints()
	classPanel:SetPoint("TOPLEFT", genderPanel, "BOTTOMLEFT", 0, -8)
	return placed
end

--- Move the stock gender buttons (and their caption) into the gender row.
local function LayoutGenderButtons()
	local previous
	for _, name in ipairs({ "CharacterCreateGenderButtonMale", "CharacterCreateGenderButtonFemale" }) do
		local button = Frame(name)
		if button then
			button:ClearAllPoints()
			if previous then
				button:SetPoint("LEFT", previous, "RIGHT", CLASS_SPACING, 0)
			else
				button:SetPoint("TOPLEFT", genderPanel, "TOPLEFT", PANEL_PADDING, -SUB_INSET)
			end
			previous = button
		end
	end

	-- The caption is a region on another frame, so it is repositioned rather than reparented.
	local caption = Frame("CharacterCreateGender")
	if caption and previous and caption.ClearAllPoints then
		caption:ClearAllPoints()
		caption:SetPoint("LEFT", previous, "RIGHT", 10, 0)
	end

	local height = previous and previous:GetHeight() or 32
	genderPanel:SetHeight(SUB_INSET + height + 6)
end

--- Class buttons into a compact grid under the races (stock ships two rows of five).
local function LayoutClassButtons()
	local first = Frame("CharacterCreateClassButton1")
	if not first then
		return
	end

	local size = first:GetWidth()
	if not size or size <= 0 then
		size = 48
	end
	local step = size + CLASS_SPACING

	for index = 1, 10 do
		local button = Frame("CharacterCreateClassButton" .. index)
		if button then
			local slot = index - 1
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", classPanel, "TOPLEFT",
				PANEL_PADDING + (slot % CLASS_COLUMNS) * step,
				-SUB_INSET - math.floor(slot / CLASS_COLUMNS) * step)
		end
	end

	-- The hovered class name is a region anchored to the old layout; it was drawing on top of the
	-- class icons. Park it under the grid.
	local className = Frame("CharacterCreateClassName")
	if className and className.ClearAllPoints then
		className:ClearAllPoints()
		className:SetPoint("TOPLEFT", classPanel, "TOPLEFT",
			PANEL_PADDING, -SUB_INSET - 2 * step - 6)
	end

	classGridWidth = CLASS_COLUMNS * step - CLASS_SPACING
	-- Room for the class-name caption UNDER the second row, inside the border.
	classPanel:SetHeight(SUB_INSET + 2 * step + 26)
end

--- Size each panel to its own content. A shared width (taken from the 5-wide ARAC class row) left
--- the 3-wide race grid with a large empty gutter; matching left edges is enough to line up.
local function SizePanels()
	racePanel:SetWidth(raceGridWidth + PANEL_PADDING * 2)
	genderPanel:SetWidth(raceGridWidth + PANEL_PADDING * 2)
	classPanel:SetWidth(classGridWidth + PANEL_PADDING * 2)
end

-- ---------------------------------------------------------------------------------- stages

local function SetRaceAndClassShown(shown)
	for index = 1, (MAX_RACES or 14) do
		SetShown(Frame("CharacterCreateRaceButton" .. index), shown)
	end
	for index = 1, 10 do
		SetShown(Frame("CharacterCreateClassButton" .. index), shown)
	end
	for _, name in ipairs(STAGE1_FRAMES) do
		SetShown(Frame(name), shown)
	end
	for _, name in ipairs(STAGE1_REGIONS) do
		SetShown(Frame(name), shown)
	end
	-- Race-name captions belong to stage 1 only; stock re-Shows them on selection, so stage 2 has
	-- to hide them explicitly or one lingers over the customization panel.
	if not shown then
		for _, name in ipairs(RACE_NAME_REGIONS) do
			SetShown(Frame(name), false)
		end
	end
	SetShown(racePanel, shown)
	SetShown(genderPanel, shown)
	SetShown(classPanel, shown)
end

local function ApplyStage()
	local choosing = (stage == STAGE_CHOOSE)

	SetRaceAndClassShown(choosing)
	SetShown(Frame("DCCharCustomizePanel"), not choosing)
	SetShown(Frame("CharacterCreateNameEdit"), not choosing)
	SetShown(Frame("CharCreateRandomizeButton"), not choosing)

	local okay = Frame("CharCreateOkayButton")
	if okay and okay.SetText then
		okay:SetText(choosing and CONTINUE or (CHAR_CREATE_ACCEPT or ACCEPT or "Create"))
	end

	-- Framing lives in DCGlueCamera (body baseline both stages, face zoom per axis); this call
	-- mainly eases back out of a face zoom when the player leaves customization. Guarded - the
	-- camera module is optional and disables itself if SetPosition misbehaves.
	if DCGlueCamera then
		DCGlueCamera.OnStageChanged(not choosing)
	end
end

local function SetStage(next)
	stage = next
	ApplyStage()
end

-- ---------------------------------------------------------------------------------- hooks

-- Accept advances to customization first; only the second press creates the character.
local stockOkay = CharacterCreate_Okay
function CharacterCreate_Okay(...)
	if stage == STAGE_CHOOSE then
		SetStage(STAGE_CUSTOMIZE)
		return
	end
	if stockOkay then
		return stockOkay(...)
	end
end

-- Back steps out of customization before leaving the screen.
local stockBack = CharacterCreate_Back
function CharacterCreate_Back(...)
	if stage == STAGE_CUSTOMIZE then
		SetStage(STAGE_CHOOSE)
		return
	end
	if stockBack then
		return stockBack(...)
	end
end

local stockOnShow = CharacterCreate_OnShow
function CharacterCreate_OnShow(...)
	local a, b, c, d
	if stockOnShow then
		a, b, c, d = stockOnShow(...)
	end
	-- Stock re-Shows race/class buttons here, so the stage must be re-applied afterwards.
	-- Re-run the race grid too: enumeration has now happened, so the per-index faction
	-- lookup is authoritative (at file-load it may fall back to the legacy 6/6 split).
	LayoutRaceButtons()
	stage = STAGE_CHOOSE
	ApplyStage()
	return a, b, c, d
end

-- A paid customization/race change enters mid-flow with the race already fixed: go straight to
-- customization, and let Back leave the screen rather than offering a race grid that is not
-- editable.
local stockFixup = CharacterChangeFixup
function CharacterChangeFixup(...)
	local a, b, c, d
	if stockFixup then
		a, b, c, d = stockFixup(...)
	end
	if PAID_SERVICE_TYPE then
		stage = STAGE_CUSTOMIZE
		ApplyStage()
	end
	return a, b, c, d
end

-- ---------------------------------------------------------------------------------- activation

-- Same guard as the customization panel: without the readback natives that panel never activates,
-- and a two-stage flow whose second stage is empty would be worse than the stock screen.
if not (DCCharCustomize and DCCharCustomize.IsAvailable() and _G["DCCharCustomizePanel"]) then
	return
end

for _, name in ipairs(RETIRED_ART) do
	local region = Frame(name)
	if region and region.Hide then
		region:Hide()
	end
end

if LayoutRaceButtons() > 0 then
	LayoutGenderButtons()
	LayoutClassButtons()
	SizePanels()
	BuildVignette()
	BuildFactionIcons()

	-- Customization moves to the right, where the race/class panels sat in stage 1.
	-- Anchored BELOW the WoW logo rather than at a guessed offset from the top: the logo lives in
	-- that corner and a fixed -110 put the panel straight through it.
	local panel = Frame("DCCharCustomizePanel")
	local logo = Frame("CharacterCreateWoWLogo")
	panel:ClearAllPoints()
	if logo then
		panel:SetPoint("TOPRIGHT", logo, "BOTTOMRIGHT", 0, -16)
	else
		panel:SetPoint("TOPRIGHT", CharacterCreate, "TOPRIGHT", -40, -200)
	end
	if panel.SetBackdrop then
		panel:SetBackdrop(PANEL_BACKDROP)
		panel:SetBackdropColor(0, 0, 0, 0.55)
		panel:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.8)
	end

	-- Ascension-style in-place race switching: a compact flyout of the race icons INSIDE
	-- customization ("should just show the races and not fully go back"). The flyout buttons
	-- borrow the stock buttons' textures/ids and drive the stock CharacterRace_OnClick, then
	-- re-apply the stage so the race-name regions stock re-Shows get hidden again. Parented to
	-- the customization panel, so everything vanishes with stage 2 for free. Paid-service flows
	-- lock the race, so the toggle stays inert there.
	local flyout = CreateFrame("Frame", "DCCharCreateRaceFlyout", panel)
	flyout:SetFrameStrata("DIALOG")
	flyout:SetBackdrop(PANEL_BACKDROP)
	flyout:SetBackdropColor(0, 0, 0, 0.8)
	flyout:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.8)
	flyout:SetPoint("TOPRIGHT", panel, "TOPLEFT", -8, 0)
	flyout:Hide()

	local FLYOUT_COLS, FLYOUT_CELL, FLYOUT_PAD = 2, 40, 12
	local flyoutButtons = {}
	local function RefreshFlyout()
		local count = 0
		for index = 1, 12 do
			local stock = Frame("CharacterCreateRaceButton" .. index)
			local texture = stock and _G["CharacterCreateRaceButton" .. index .. "NormalTexture"]
			if stock and texture then
				count = count + 1
				local button = flyoutButtons[count]
				if not button then
					button = CreateFrame("CheckButton", nil, flyout)
					button:SetWidth(34)
					button:SetHeight(34)
					local icon = button:CreateTexture(nil, "ARTWORK")
					icon:SetAllPoints()
					button.icon = icon
					-- Gold ring around the selected race, like the stage-1 grid's selection look.
					button:SetBackdrop({
						edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
						edgeSize = 12,
						insets = { left = 2, right = 2, top = 2, bottom = 2 },
					})
					button:SetHighlightTexture(
						"Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Highlights", "ADD")
					button:SetCheckedTexture(
						"Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Highlights", "ADD")
					button:SetScript("OnClick", function(self)
						self:SetChecked(1)
						local target = Frame("CharacterCreateRaceButton" .. self.stockIndex)
						if target and target.enable then
							-- Stock's first guard bounces unchecked buttons, so pre-check it.
							target:SetChecked(1)
							CharacterRace_OnClick(target, target:GetID())
							ApplyStage()   -- stock re-Shows stage-1 regions; put stage 2 back
						end
						RefreshFlyout()
					end)
					flyoutButtons[count] = button
				end
				button.stockIndex = index
				button.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races")
				button.icon:SetTexCoord(texture:GetTexCoord())
				-- Alpha rather than SetDesaturated: the glue widget API is a subset.
				button.icon:SetAlpha(stock.enable and 1 or 0.35)
				button:SetChecked(stock:GetChecked())
				if stock:GetChecked() then
					button:SetBackdropBorderColor(1, 0.82, 0, 1)
				else
					button:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.7)
				end
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", flyout, "TOPLEFT",
					FLYOUT_PAD + ((count - 1) % FLYOUT_COLS) * FLYOUT_CELL,
					-FLYOUT_PAD - math.floor((count - 1) / FLYOUT_COLS) * FLYOUT_CELL)
				button:Show()
			end
		end
		for i = count + 1, #flyoutButtons do
			flyoutButtons[i]:Hide()
		end
		flyout:SetWidth(FLYOUT_PAD * 2 + FLYOUT_COLS * FLYOUT_CELL - 6)
		flyout:SetHeight(FLYOUT_PAD * 2 + math.ceil(count / FLYOUT_COLS) * FLYOUT_CELL - 6)
	end

	local changeRace = CreateFrame("Button", "DCCharCreateChangeRace", panel, "GlueButtonSmallTemplate")
	changeRace:SetWidth(110)
	changeRace:SetHeight(26)
	changeRace:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 6)
	changeRace:SetText("Race")
	changeRace:SetScript("OnClick", function()
		if PAID_SERVICE_TYPE then
			return
		end
		if flyout:IsShown() then
			flyout:Hide()
		else
			RefreshFlyout()
			flyout:Show()
		end
	end)

	ApplyStage()
end
