--[[----------------------------------------------------------------------------------------------
DCCharSelect.lua -- Shadowlands-style dressing for the 3.3.5a character-select screen.

Deliberately a RESTYLE, not a rebuild. Stock 3.3.5a already puts the character list on the right
and the model centre-left, which is the same silhouette retail uses - so this only adds the SL
framing (edge vignette, dark panel behind the list) and retires the ornamental border art. All
selection, scrolling and paging logic is left completely alone.

TWO THINGS HERE MUST NOT BREAK, both easy to break by accident:

 1. THE BREAKING-NEWS DRIVER. GlueParent.lua owns DCBreakingNews_* and the native side pcalls the
    global DCBreakingNews_OnPayloadUpdated; its OnUpdate is wired from GlueParent.xml. This file
    touches neither GlueParent nor any DCBreakingNews global, and adds no OnUpdate of its own.
    Verify with the DCPatchApiProbe addon: /dctest news should still report glueLoaded/glueApplied.

 2. THE RAISED CHARACTER LIMIT. This realm allows 25 characters but only MAX_CHARACTERS_DISPLAYED
    (10) buttons exist - the list SCROLLS. Anything that assumes "one button per character" or
    re-anchors the buttons into a fixed list would silently hide characters 11-25. So the buttons
    are not moved, not resized and not re-anchored; only a backdrop is placed BEHIND their frame.

Requires DCCharCreateAtlas.lua + DCGlueAtlas.lua to have loaded (both are included ahead of it).
------------------------------------------------------------------------------------------------]]

local function Frame(name)
	return _G[name]
end

-- Ornamental art belonging to the old look. Regions, so hidden individually.
local RETIRED_ART = {
	"CharacterSelectBackground",
}

local function Apply()
	local screen = Frame("CharacterSelect")
	if not screen then
		return
	end

	DCBuildVignette(screen, "DCCharSelectVignette")

	-- A panel behind the character list. The list frame itself is only a container; giving it a
	-- backdrop leaves every button, the scroll behaviour and the realm name untouched.
	local list = Frame("CharacterSelectCharacterFrame")
	if list then
		local panel = CreateFrame("Frame", "DCCharSelectListPanel", screen)
		panel:SetFrameStrata("BACKGROUND")
		-- Sized off the list rather than hardcoded, and inset generously so the buttons sit
		-- comfortably inside rather than flush against the border.
		panel:SetPoint("TOPLEFT", list, "TOPLEFT", -18, 18)
		panel:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 18, -18)
		DCStyleGluePanel(panel)
	end

	for _, name in ipairs(RETIRED_ART) do
		local region = Frame(name)
		if region and region.Hide then
			region:Hide()
		end
	end
end

Apply()
