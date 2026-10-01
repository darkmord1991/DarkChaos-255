--[[
	DC-Talents - texture atlases on 3.3.5.

	3.3.5 has no atlas system. Data/AtlasInfo.lua (generated from retail 11.2.7 Helix/AtlasInfo.lua
	for the sheets we ship) maps atlas names to { file, width, height, left, right, top, bottom,
	tilesHorizontally, tilesVertically }. SetAtlas becomes SetTexture + SetTexCoord (+ SetSize).

	Atlas.Register adds DC-made entries. Sprites that retail rotates freely (edge arrow heads) are
	registered as standalone, padded files with rotatable = true: 3.3.5's Texture:SetRotation rotates
	the texture coordinates of the WHOLE file around its centre, which would pull neighbouring
	sprites of a sheet into view, and it draws the content at 1/sqrt(2) of the region size.
]]

local _, ns = ...
setfenv(1, ns.env)

local Atlas = {}
ns.Atlas = Atlas

local overrides = {}
local lowerIndex

local SQRT2 = math.sqrt(2)

local function BuildLowerIndex()
	lowerIndex = {}
	for name, data in pairs(ns.AtlasInfo or {}) do
		lowerIndex[name:lower()] = data
	end
	for name, data in pairs(overrides) do
		lowerIndex[name:lower()] = data
	end
end

function Atlas.Register(name, file, width, height, left, right, top, bottom, rotatable)
	local data = { file, width, height, left or 0, right or 1, top or 0, bottom or 1, false, false }
	data.rotatable = rotatable or nil
	overrides[name] = data
	if lowerIndex then
		lowerIndex[name:lower()] = data
	end
end

function Atlas.Get(name)
	if type(name) ~= "string" then
		return nil
	end
	local data = overrides[name] or (ns.AtlasInfo and ns.AtlasInfo[name])
	if data then
		return data
	end
	if not lowerIndex then
		BuildLowerIndex()
	end
	return lowerIndex[name:lower()]
end

function Atlas.Exists(name)
	return Atlas.Get(name) ~= nil
end

-- Texture:SetAtlas(name, useAtlasSize)
function Atlas.Apply(texture, name, useAtlasSize)
	-- The natives: prepared textures wrap SetTexture / SetTexCoord to keep atlas-relative coordinates
	-- (Core/Engine.lua WrapAtlasTexture), and the atlas itself is set in sheet coordinates.
	local setTexture = texture.__dcRawSetTexture or texture.SetTexture
	local setTexCoord = texture.__dcRawSetTexCoord or texture.SetTexCoord
	local data = Atlas.Get(name)
	if not data then
		setTexture(texture, nil)
		texture.__dcAtlas = nil
		texture.__dcAtlasRect = nil
		return false
	end

	setTexture(texture, data[1])
	setTexCoord(texture, data[4], data[5], data[6], data[7])
	texture.__dcAtlasRect = { data[4], data[5], data[6], data[7] }
	if useAtlasSize then
		local width, height = data[2], data[3]
		if data.rotatable then
			local side = math.max(width, height) * SQRT2
			width, height = side, side
		end
		texture:SetSize(width, height)
	end
	texture.__dcAtlas = name
	return true
end

-- Retail C_Texture.GetAtlasInfo shape.
function Atlas.GetInfo(name)
	local data = Atlas.Get(name)
	if not data then
		return nil
	end
	return {
		width = data[2],
		height = data[3],
		rawSize = { x = data[2], y = data[3] },
		leftTexCoord = data[4],
		rightTexCoord = data[5],
		topTexCoord = data[6],
		bottomTexCoord = data[7],
		tilesHorizontally = data[8] or false,
		tilesVertically = data[9] or false,
		file = data[1],
		filename = data[1],
	}
end
