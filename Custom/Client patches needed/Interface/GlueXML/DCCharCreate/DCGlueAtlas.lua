--[[----------------------------------------------------------------------------------------------
DCGlueAtlas.lua -- shared atlas helper for the DarkChaos glue screens.

Retail draws its chrome from texture ATLASES (one sheet, normalised sub-rects per named element).
3.3.5a has no GetAtlasInfo, so tools/dccc_atlas_art.py cuts each element into its own BLP offline
and emits DCCharCreateAtlas.lua; this is the runtime half.

Lives in its own file because BOTH CharacterCreate.xml and CharacterSelect.xml need it, and
GlueXML.toc decides which of those parses first - a helper defined inside either screen's own files
would be missing from the other depending on load order.
------------------------------------------------------------------------------------------------]]

--- Stand-in for retail's SetAtlas.
--- Elements were padded to a power of two for DXT, so the texcoords are mandatory: without them
--- the transparent padding shows as empty space around the art.
--- Returns false when the art is absent, so every caller can degrade to its plain appearance
--- rather than erroring inside a glue screen.
function DCApplyAtlas(texture, name, useAtlasSize)
	local entry = DCCharCreateAtlas and DCCharCreateAtlas[name]
	if not (texture and entry) then
		return false
	end
	texture:SetTexture(entry.file)
	texture:SetTexCoord(0, entry.right, 0, entry.bottom)
	if useAtlasSize then
		texture:SetWidth(entry.width)
		texture:SetHeight(entry.height)
	end
	return true
end

--- Edge vignette: the most recognisable piece of the Shadowlands glue look, and it costs nothing
--- structurally.
---
--- The textures are created on the SCREEN FRAME ITSELF at the BACKGROUND draw layer, not on a
--- child frame with BACKGROUND strata. The first attempt did the latter and was invisible: these
--- screens are ModelFFX widgets rendering a 3D scene, and a BACKGROUND-strata child sits beneath
--- that render. A frame's own textures draw above its 3D content, and child FRAMES (the panels)
--- draw above those textures - which is exactly the ordering wanted.
---
--- Returns the texture list, also stored globally under `name` for diagnostics.
function DCBuildVignette(parent, name)
	if not (parent and parent.CreateTexture and DCCharCreateAtlas) then
		return nil
	end

	local textures = {}

	-- The source strips are 1px in their stretch direction, so anchoring both ends stretches them
	-- across the screen; only the other dimension needs an explicit size.
	local function edge(atlasName, cornerA, cornerB, vertical)
		local entry = DCCharCreateAtlas[atlasName]
		local texture = parent:CreateTexture(nil, "BACKGROUND")
		if not (entry and DCApplyAtlas(texture, atlasName)) then
			return
		end
		texture:SetPoint(cornerA, parent, cornerA, 0, 0)
		texture:SetPoint(cornerB, parent, cornerB, 0, 0)
		if vertical then
			texture:SetWidth(entry.width)
		else
			texture:SetHeight(entry.height)
		end
		textures[#textures + 1] = texture
	end

	edge("charactercreate-vignette-top", "TOPLEFT", "TOPRIGHT", false)
	edge("charactercreate-vignette-bottom", "BOTTOMLEFT", "BOTTOMRIGHT", false)
	edge("charactercreate-vignette-sides", "TOPLEFT", "BOTTOMLEFT", true)
	edge("charactercreate-vignette-sides", "TOPRIGHT", "BOTTOMRIGHT", true)

	if name then
		_G[name] = textures
	end
	return textures
end

--- The dark translucent panel both screens use behind their content.
DC_GLUE_BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function DCStyleGluePanel(frame)
	if not (frame and frame.SetBackdrop) then
		return false
	end
	frame:SetBackdrop(DC_GLUE_BACKDROP)
	frame:SetBackdropColor(0, 0, 0, 0.55)
	frame:SetBackdropBorderColor(0.5, 0.45, 0.35, 0.8)
	return true
end
