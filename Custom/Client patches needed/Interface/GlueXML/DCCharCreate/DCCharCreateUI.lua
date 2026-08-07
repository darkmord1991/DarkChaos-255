--[[----------------------------------------------------------------------------------------------
DCCharCreateUI.lua -- Shadowlands-style customization panel for the 3.3.5a create screen (Stage 1b
skeleton: structure and interaction; the retail art pass comes later).

Replaces the five blind arrow sliders with a categorised panel:

    BODY
      Skin Color      <  3 / 10  >
      [swatch strip]
      Face            <  5 / 12  >
    HAIR
      Hair Style      <  1 / 17  >
      Hair Color      <  2 / 10  >
      [swatch strip]
      Facial Feature  <  4 / 9   >

Everything is driven by DCCharCustomize (the probe/absolute-set bridge). Counts and positions come
from the client's own enumerator, swatch colours from the generated DCCharCustomizeData table.

SAFETY MODEL -- written in the shadow of the 2026-08-06 ERROR #132 crash:
  * Nothing runs at file load beyond creating hidden frames. No probing, no cycling.
  * All refresh work happens one frame later via a dirty flag on an OnUpdate driver that only
    ticks while the create screen is visible. Probes are bounded by the bridge's per-frame budget;
    axes that miss the budget simply fill in on the next frame.
  * If the WXL getters are missing (older DLL), the panel never activates and the stock sliders
    stay exactly as they are.
  * If the probe turns out to be untrustworthy in-client (readback not synchronous), the panel
    deactivates itself and RESTORES the stock sliders -- degradation, not breakage.
  * The stock frames are hidden, never modified; every stock function keeps running against them.

The stock globals this hooks: SetCharacterRace, SetCharacterGender, SetCharacterClass,
CharacterCreate_OnShow, CharacterCreate_Randomize. Each hook only marks the panel dirty.
------------------------------------------------------------------------------------------------]]

-- The panel is free-standing on the right now (it no longer has to fit the old slider footprint),
-- and the screen it renders on is large - so rows get room to breathe rather than staying cramped
-- in a corner. Swatches are big enough to read a colour and to click accurately.
local ROW_WIDTH = 380
local ROW_HEIGHT = 24
local HEADER_HEIGHT = 18
-- Retail draws colour choices as wide pills, not squares: charactercreate-customize-palette is a
-- white mask tinted per choice (source 42x10 at 1x). Keep roughly that ratio so the art is not
-- stretched, and size it so a full 13-colour Death Knight row still fits inside ROW_WIDTH.
local SWATCH_W = 30
local SWATCH_H = 16
local SWATCH_GAP = 3
local SWATCHES_PER_ROW = 11
local MAX_SWATCHES = 33

local AXIS_SKIN, AXIS_FACE, AXIS_HAIR_STYLE, AXIS_HAIR_COLOR, AXIS_FACIAL = 1, 2, 3, 4, 5

-- Panel layout, top to bottom. Swatch strips ride under their owning row.
local LAYOUT = {
	{ header = "BODY" },
	{ axis = AXIS_SKIN, swatches = true },
	{ axis = AXIS_FACE },
	{ header = "HAIR" },
	{ axis = AXIS_HAIR_STYLE },
	{ axis = AXIS_HAIR_COLOR, swatches = true },
	{ axis = AXIS_FACIAL },
}

local panel            -- container frame, child of CharacterCreate
local rows = {}        -- axis -> row frame
local elements = {}    -- headers + rows in draw order, for re-measuring the panel
local dirty = false
local disabled = false -- set once when we give up and hand back to the stock sliders

-- Breathing room inside the panel's backdrop (applied by DCCharCreateLayout); without it the rows
-- and swatches sit directly on the border.
local PANEL_PADDING = 12

-- ---------------------------------------------------------------------------------- stock frames

local function SetStockSlidersShown(shown)
	for i = 1, 5 do
		local frame = _G["CharacterCustomizationButtonFrame" .. i]
		if frame then
			if shown then frame:Show() else frame:Hide() end
		end
	end
end

-- ---------------------------------------------------------------------------------- labels

-- Blizzard's own label for a few of these says almost nothing about what the slider does - the
-- worgen/goblin axis is FACIAL_HAIR_FEATURES, "Features", which could mean anything. These are the
-- clearer wordings; anything not listed keeps the stock string. Declared here rather than by
-- overriding GlueStrings.lua, which would mean owning a whole locale file for a handful of words.
local FACIAL_TAG_LABEL = {
	FEATURES  = "Facial Features",     -- worgen: snout, ears, scars
	NORMAL    = "Facial Hair",
	MARKINGS  = "Face Markings",
	PIERCINGS = "Face Piercings",
}

--- Mirrors the stock CharacterCreate_UpdateHairCustomization label logic, with fallbacks for the
--- known blank case (worgen FACIAL_HAIR_<tag> has no GlueStrings entry -> stock shows nothing).
local function AxisLabel(axis)
	local text
	if axis == AXIS_HAIR_STYLE and GetHairCustomization then
		text = _G["HAIR_" .. tostring(GetHairCustomization()) .. "_STYLE"]
	elseif axis == AXIS_HAIR_COLOR and GetHairCustomization then
		text = _G["HAIR_" .. tostring(GetHairCustomization()) .. "_COLOR"]
	elseif axis == AXIS_FACIAL and GetFacialHairCustomization then
		local tag = tostring(GetFacialHairCustomization())
		text = FACIAL_TAG_LABEL[tag] or _G["FACIAL_HAIR_" .. tag]
	end
	if not text or text == "" then
		text = _G[DCCharCustomize.AXIS_LABEL_KEY[axis]]
	end
	if not text or text == "" then
		text = "Feature"
	end
	return text
end

-- ---------------------------------------------------------------------------------- widgets

local function MarkDirty()
	dirty = true
end

local function CreateArrow(parent, direction, axis)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(24)
	button:SetHeight(24)
	local tex = (direction > 0) and "Right" or "Left"
	button:SetNormalTexture("Interface\\Glues\\Common\\Glue-" .. tex .. "Arrow-Button-Up")
	button:SetPushedTexture("Interface\\Glues\\Common\\Glue-" .. tex .. "Arrow-Button-Down")
	button:SetHighlightTexture("Interface\\Glues\\Common\\Glue-" .. tex .. "Arrow-Button-Highlight")
	button:SetScript("OnClick", function()
		DCCharCustomize.CycleAxis(axis, direction)
		if PlaySound then pcall(PlaySound, "gsCharacterCreationLook") end
		MarkDirty()
	end)
	return button
end

local function CreateHeader(text)
	local frame = CreateFrame("Frame", nil, panel)
	frame:SetWidth(ROW_WIDTH)
	frame:SetHeight(HEADER_HEIGHT)
	local label = frame:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	label:SetPoint("LEFT", 2, -2)
	label:SetText("|cffffd200" .. text .. "|r")
	return frame
end

local function CreateRow(axis, withSwatches)
	local row = CreateFrame("Frame", nil, panel)
	row:SetWidth(ROW_WIDTH)
	row:SetHeight(ROW_HEIGHT + (withSwatches and (SWATCH_H + SWATCH_GAP * 2) or 0))

	row.label = row:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	row.label:SetPoint("TOPLEFT", 2, -4)
	row.label:SetJustifyH("LEFT")

	row.rightArrow = CreateArrow(row, 1, axis)
	row.rightArrow:SetPoint("TOPRIGHT", 0, 2)
	row.leftArrow = CreateArrow(row, -1, axis)
	-- Was +12, which shoved the left arrow a half-width INTO the right one. Small negative gap.
	row.leftArrow:SetPoint("RIGHT", row.rightArrow, "LEFT", -2, 0)

	row.value = row:CreateFontString(nil, "OVERLAY", "GlueFontHighlightSmall")
	row.value:SetPoint("RIGHT", row.leftArrow, "LEFT", 2, 0)
	row.value:SetJustifyH("RIGHT")

	if withSwatches then
		row.swatches = {}
	end
	row.axis = axis
	return row
end

local function GetSwatchButton(row, slot)
	local button = row.swatches[slot]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, row)
	button:SetWidth(SWATCH_W)
	button:SetHeight(SWATCH_H)

	-- The retail palette shape is a white mask tinted to the choice colour. Falls back to a plain
	-- filled rectangle with a border when the art is not deployed.
	button.color = button:CreateTexture(nil, "ARTWORK")
	button.color:SetAllPoints()
	button.usesAtlas = DCApplyAtlas and DCApplyAtlas(button.color, "charactercreate-customize-palette")
	if not button.usesAtlas then
		button.color:ClearAllPoints()
		button.color:SetPoint("TOPLEFT", 1, -1)
		button.color:SetPoint("BOTTOMRIGHT", -1, 1)
		button.border = button:CreateTexture(nil, "BACKGROUND")
		button.border:SetAllPoints()
		button.border:SetTexture(1, 1, 1, 1)
	end

	-- Selection frame, drawn over the swatch and slightly proud of it (retail insets it by 4).
	button.selected = button:CreateTexture(nil, "OVERLAY")
	if DCApplyAtlas and DCApplyAtlas(button.selected, "charactercreate-customize-palette-selected") then
		button.selected:SetPoint("CENTER")
		button.selected:SetWidth(SWATCH_W + 12)
		button.selected:SetHeight(SWATCH_H + 12)
	else
		button.selected = nil
	end
	button:SetScript("OnClick", function()
		DCCharCustomize.SetSlot(row.axis, button.slot)
		if PlaySound then pcall(PlaySound, "gsCharacterCreationLook") end
		MarkDirty()
	end)
	local col = (slot - 1) % SWATCHES_PER_ROW
	local line = math.floor((slot - 1) / SWATCHES_PER_ROW)
	button:SetPoint("TOPLEFT", row, "TOPLEFT",
		2 + col * (SWATCH_W + SWATCH_GAP),
		-(ROW_HEIGHT - 2) - line * (SWATCH_H + SWATCH_GAP))
	row.swatches[slot] = button
	return button
end

-- ---------------------------------------------------------------------------------- refresh

local function RefreshRow(row)
	local axis = row.axis
	local info = DCCharCustomize.GetAxisInfo(axis)
	if info.deferred then
		row.value:SetText("...")
		return false                 -- not settled; keep the panel dirty
	end

	if info.count <= 1 then
		-- Nothing to choose (or a genuinely one-choice axis): hide the controls, keep the space.
		row.label:SetText("|cff808080" .. AxisLabel(axis) .. "|r")
		row.value:SetText("")
		row.leftArrow:Hide()
		row.rightArrow:Hide()
	else
		row.label:SetText(AxisLabel(axis))
		row.value:SetText(DCCharCustomize.GetCurrentSlot(axis) .. " / " .. info.count)
		row.leftArrow:Show()
		row.rightArrow:Show()
	end

	if row.swatches then
		local currentSlot = DCCharCustomize.GetCurrentSlot(axis)
		local shown = math.min(info.count, MAX_SWATCHES)
		-- A Death Knight can unlock enough extra tones to wrap onto a second swatch line; grow the
		-- row so it never overlaps the one below (the anchor chain shifts the rest automatically).
		local lines = math.max(1, math.ceil(shown / SWATCHES_PER_ROW))
		row:SetHeight(ROW_HEIGHT + lines * (SWATCH_H + SWATCH_GAP) + SWATCH_GAP)
		for slot = 1, shown do
			local button = GetSwatchButton(row, slot)
			button.slot = slot
			local r, g, b = DCCharCustomize.GetSwatch(axis, slot)
			if not r then
				r, g, b = 0.35, 0.35, 0.35
			end
			if button.usesAtlas then
				-- The palette art is a white mask: tint it rather than replacing the texture.
				button.color:SetVertexColor(r, g, b)
			else
				button.color:SetTexture(r, g, b, 1)
			end

			local isSelected = (slot == currentSlot)
			if button.selected then
				if isSelected then button.selected:Show() else button.selected:Hide() end
			elseif button.border then
				button.border:SetTexture(isSelected and 1 or 0, isSelected and 1 or 0,
					isSelected and 1 or 0, isSelected and 1 or 0.6)
			end
			button:SetAlpha(isSelected and 1 or 0.85)
			button:Show()
		end
		for slot = shown + 1, #row.swatches do
			row.swatches[slot]:Hide()
		end
	end
	return true
end

local function Deactivate(reason)
	disabled = true
	if panel then panel:Hide() end
	SetStockSlidersShown(true)
	-- Loud enough to find in a session log, quiet enough not to bother a player.
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage("DCCharCreate: " .. reason .. " - stock sliders restored.")
	end
end

--- Resize the panel to whatever the rows currently occupy.
---
--- Must run on every refresh, not once at build time: a row grows when its swatches wrap onto a
--- second line, and how many lines that is depends on the race, gender AND class being previewed.
--- Draenei has 12 skin tones against SWATCHES_PER_ROW = 11, so it wraps the moment you select it,
--- and a panel still sized for one line pushed the last row (Horn Style) outside its own backdrop.
local function UpdatePanelHeight()
	if not panel or not elements then
		return
	end
	local total = 0
	for _, element in ipairs(elements) do
		total = total + element:GetHeight() + 1
	end
	panel:SetHeight(total + PANEL_PADDING * 2)
end

local function Refresh()
	if disabled then
		return
	end

	local settled = true
	for _, row in pairs(rows) do
		if not RefreshRow(row) then
			settled = false
		end
	end
	UpdatePanelHeight()

	if settled then
		-- Checked on EVERY settled refresh, not once: if the readback is (or becomes) frozen,
		-- every probe collapses to "1 / 1" and this panel is a broken palette. Hand back to the
		-- stock sliders instead. The check is a handful of table lookups, so always-on is free.
		if not DCCharCustomize.IsProbeTrustworthy() then
			Deactivate("appearance readback is not synchronous on this client")
			return
		end
		dirty = false
	end
end

-- ---------------------------------------------------------------------------------- build

local function Build()
	panel = CreateFrame("Frame", "DCCharCustomizePanel", CharacterCreate)
	panel:SetWidth(ROW_WIDTH + PANEL_PADDING * 2)

	-- Anchored where the stock slider stack sat: directly above the Randomize button.
	panel:SetPoint("BOTTOM", CharCreateRandomizeButton, "TOP", -6, 4)

	local previous
	local totalHeight = 0
	for _, entry in ipairs(LAYOUT) do
		local element
		if entry.header then
			element = CreateHeader(entry.header)
		else
			element = CreateRow(entry.axis, entry.swatches)
			rows[entry.axis] = element
		end
		if previous then
			element:SetPoint("TOP", previous, "BOTTOM", 0, -1)
		else
			element:SetPoint("TOP", panel, "TOP", 0, -PANEL_PADDING)
		end
		elements[#elements + 1] = element
		totalHeight = totalHeight + element:GetHeight() + 1
		previous = element
	end
	panel:SetHeight(totalHeight + PANEL_PADDING * 2)

	-- The driver: refreshes one frame after anything marks the panel dirty. Child of the panel,
	-- so it only ever ticks while the create screen (and the panel) is visible.
	panel:SetScript("OnUpdate", function()
		if dirty then
			Refresh()
		end
	end)

	SetStockSlidersShown(false)
end

-- ---------------------------------------------------------------------------------- hooks

local function Hook(name)
	local old = _G[name]
	_G[name] = function(...)
		local a, b, c, d
		if old then
			a, b, c, d = old(...)
		end
		if not disabled then
			-- Deliberately NOT DCCharCustomize.Invalidate(): the probe cache is keyed by
			-- race/sex/class, so a selection change lands in a different bucket by itself.
			-- Wiping the cache here meant flipping between two races re-paid the full probe
			-- cost (~45 costly cycles) on every single switch - the user felt it.
			MarkDirty()
		end
		return a, b, c, d
	end
end

-- ---------------------------------------------------------------------------------- activation

-- Guard: on an older DLL without the readback getters, do nothing at all.
if not (DCCharCustomize and DCCharCustomize.IsAvailable()) then
	return
end

Build()

Hook("SetCharacterRace")
Hook("SetCharacterGender")
Hook("SetCharacterClass")
Hook("CharacterCreate_OnShow")
Hook("CharacterCreate_Randomize")

-- First fill. The screen may already be visible when this file loads; a dirty flag costs nothing
-- if it is not.
MarkDirty()
