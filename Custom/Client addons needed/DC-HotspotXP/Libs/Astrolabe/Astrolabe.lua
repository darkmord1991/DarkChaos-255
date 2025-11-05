--[[
Name: Astrolabe
Revision: $Rev: 107 $
$Date: 2009-08-05 08:34:29 +0100 (Wed, 05 Aug 2009) $
Author(s): Esamynn (esamynn at wowinterface.com)
Inspired By: Gatherer by Norganna
			 MapLibrary by Kristofer Karlsson (krka at kth.se)
Documentation: http://wiki.esamynn.org/Astrolabe
SVN: http://svn.esamynn.org/astrolabe/
Description:
	This is a library for the World of Warcraft UI system to place
	icons accurately on both the Minimap and on Worldmaps.
	This library also manages and updates the position of Minimap icons
	automatically.
Copyright (C) 2006-2008 James Carrothers
License:
	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Lesser General Public
	License as published by the Free Software Foundation; either
	version 2.1 of the License, or (at your option) any later version.
	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Lesser General Public License for more details.
	You should have received a copy of the GNU Lesser General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
Note:
	This library's source code is specifically designed to work with
	World of Warcraft's interpreted AddOn system.  You have an implicit
	licence to use this library with these facilities since that is its
	designated purpose as per:
	http://www.fsf.org/licensing/licenses/gpl-faq.html#InterpreterIncompat
]] -- WARNING!!!
-- DO NOT MAKE CHANGES TO THIS LIBRARY WITHOUT FIRST CHANGING THE LIBRARY_VERSION_MAJOR
-- STRING (to something unique) OR ELSE YOU MAY BREAK OTHER ADDONS THAT USE THIS LIBRARY!!!
local LIBRARY_VERSION_MAJOR = "Astrolabe-0.4"
local LIBRARY_VERSION_MINOR = tonumber(string.match("$Revision: 107 $", "(%d+)") or 1)
if not DongleStub then
	error(LIBRARY_VERSION_MAJOR .. " requires DongleStub.")
end
if not DongleStub:IsNewerVersion(LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR) then
	return
end
local Astrolabe = {};
-- define local variables for Data Tables (defined at the end of this file)
local WorldMapSize, MinimapSize, ValidMinimapShapes;
function Astrolabe:GetVersion()
	return LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR;
end
--------------------------------------------------------------------------------------------------------------
-- Config Constants
--------------------------------------------------------------------------------------------------------------
local configConstants = {
	MinimapUpdateMultiplier = true
}
-- this constant is multiplied by the current framerate to determine
-- how many icons are updated each frame
Astrolabe.MinimapUpdateMultiplier = 1;
--------------------------------------------------------------------------------------------------------------
-- Working Tables
--------------------------------------------------------------------------------------------------------------
Astrolabe.LastPlayerPosition = {0, 0, 0, 0};
Astrolabe.MinimapIcons = {};
Astrolabe.IconsOnEdge = {};
Astrolabe.IconsOnEdge_GroupChangeCallbacks = {};
Astrolabe.MinimapIconCount = 0
Astrolabe.ForceNextUpdate = false;
Astrolabe.IconsOnEdgeChanged = false;
-- This variable indicates whether we know of a visible World Map or not.
-- The state of this variable is controlled by the AstrolabeMapMonitor library.
Astrolabe.WorldMapVisible = false;
local AddedOrUpdatedIcons = {}
local MinimapIconsMetatable = {
	__index = AddedOrUpdatedIcons
}
--------------------------------------------------------------------------------------------------------------
-- Local Pointers for often used API functions
--------------------------------------------------------------------------------------------------------------
local twoPi = math.pi * 2;
local atan2 = math.atan2;
local sin = math.sin;
local cos = math.cos;
local abs = math.abs;
local sqrt = math.sqrt;
local min = math.min
local max = math.max
local yield = coroutine.yield
local next = next
local GetFramerate = GetFramerate
--------------------------------------------------------------------------------------------------------------
-- Internal Utility Functions
--------------------------------------------------------------------------------------------------------------
local function assert(level, condition, message)
	if not condition then
		error(message, level)
	end
end
local function argcheck(value, num, ...)
	assert(1, type(num) == "number", "Bad argument #2 to 'argcheck' (number expected, got " .. type(level) .. ")")
	for i = 1, select("#", ...) do
		if type(value) == select(i, ...) then
			return
		end
	end
	local types = strjoin(", ", ...)
	local name = string.match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to 'Astrolabe.%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end
local function getContPosition(zoneData, z, x, y)
	if (z ~= 0) then
		zoneData = zoneData[z];
		x = x * zoneData.width + zoneData.xOffset;
		y = y * zoneData.height + zoneData.yOffset;
	else
		x = x * zoneData.width;
		y = y * zoneData.height;
	end
	return x, y;
end
--------------------------------------------------------------------------------------------------------------
-- General Utility Functions
--------------------------------------------------------------------------------------------------------------
function Astrolabe:ComputeDistance(c1, z1, x1, y1, c2, z2, x2, y2)
	--[[
	argcheck(c1, 2, "number");
	assert(3, c1 >= 0, "ComputeDistance: Illegal continent index to c1: "..c1);
	argcheck(z1, 3, "number", "nil");
	argcheck(x1, 4, "number");
	argcheck(y1, 5, "number");
	argcheck(c2, 6, "number");
	assert(3, c2 >= 0, "ComputeDistance: Illegal continent index to c2: "..c2);
	argcheck(z2, 7, "number", "nil");
	argcheck(x2, 8, "number");
	argcheck(y2, 9, "number");
	--]]
	z1 = z1 or 0;
	z2 = z2 or 0;
	local dist, xDelta, yDelta;
	if (c1 == c2 and z1 == z2) then
		-- points in the same zone
		local zoneData = WorldMapSize[c1];
		if (z1 ~= 0) then
			zoneData = zoneData[z1];
		end
		xDelta = (x2 - x1) * zoneData.width;
		yDelta = (y2 - y1) * zoneData.height;
	elseif (c1 == c2) then
		-- points on the same continent
		local zoneData = WorldMapSize[c1];
		x1, y1 = getContPosition(zoneData, z1, x1, y1);
		x2, y2 = getContPosition(zoneData, z2, x2, y2);
		xDelta = (x2 - x1);
		yDelta = (y2 - y1);
	elseif (c1 and c2) then
		local cont1 = WorldMapSize[c1];
		local cont2 = WorldMapSize[c2];
		if (cont1.parentContinent == cont2.parentContinent) then
			x1, y1 = getContPosition(cont1, z1, x1, y1);
			x2, y2 = getContPosition(cont2, z2, x2, y2);
			if (c1 ~= cont1.parentContinent) then
				x1 = x1 + cont1.xOffset;
				y1 = y1 + cont1.yOffset;
			end
			if (c2 ~= cont2.parentContinent) then
				x2 = x2 + cont2.xOffset;
				y2 = y2 + cont2.yOffset;
			end
			xDelta = x2 - x1;
			yDelta = y2 - y1;
		end
	end
	if (xDelta and yDelta) then
		dist = sqrt(xDelta * xDelta + yDelta * yDelta);
	end
	return dist, xDelta, yDelta;
end
function Astrolabe:TranslateWorldMapPosition(C, Z, xPos, yPos, nC, nZ)
	--[[
	argcheck(C, 2, "number");
	argcheck(Z, 3, "number", "nil");
	argcheck(xPos, 4, "number");
	argcheck(yPos, 5, "number");
	argcheck(nC, 6, "number");
	argcheck(nZ, 7, "number", "nil");
	--]]
	Z = Z or 0;
	nZ = nZ or 0;
	if (nC < 0) then
		return;
	end
	local zoneData;
	if (C == nC and Z == nZ) then
		return xPos, yPos;
	elseif (C == nC) then
		-- points on the same continent
		zoneData = WorldMapSize[C];
		xPos, yPos = getContPosition(zoneData, Z, xPos, yPos);
		if (nZ ~= 0) then
			zoneData = WorldMapSize[C][nZ];
			xPos = xPos - zoneData.xOffset;
			yPos = yPos - zoneData.yOffset;
		end
	elseif (C and nC) and (WorldMapSize[C].parentContinent == WorldMapSize[nC].parentContinent) then
		-- different continents, same world
		zoneData = WorldMapSize[C];
		local parentContinent = zoneData.parentContinent;
		xPos, yPos = getContPosition(zoneData, Z, xPos, yPos);
		if (C ~= parentContinent) then
			-- translate up to world map if we aren't there already
			xPos = xPos + zoneData.xOffset;
			yPos = yPos + zoneData.yOffset;
			zoneData = WorldMapSize[parentContinent];
		end
		if (nC ~= parentContinent) then
			-- translate down to the new continent
			zoneData = WorldMapSize[nC];
			xPos = xPos - zoneData.xOffset;
			yPos = yPos - zoneData.yOffset;
			if (nZ ~= 0) then
				zoneData = zoneData[nZ];
				xPos = xPos - zoneData.xOffset;
				yPos = yPos - zoneData.yOffset;
			end
		end
	else
		return;
	end
	return (xPos / zoneData.width), (yPos / zoneData.height);
end
-- *****************************************************************************
-- This function will do its utmost to retrieve some sort of valid position
-- for the specified unit, including changing the current map zoom (if needed).
-- Map Zoom is returned to its previous setting before this function returns.
-- *****************************************************************************
function Astrolabe:GetUnitPosition(unit, noMapChange)
	local x, y = GetPlayerMapPosition(unit);
	if (x <= 0 and y <= 0) then
		if (noMapChange) then
			-- no valid position on the current map, and we aren't allowed
			-- to change map zoom, so return
			return;
		end
		local lastCont, lastZone = GetCurrentMapContinent(), GetCurrentMapZone();
		SetMapToCurrentZone();
		x, y = GetPlayerMapPosition(unit);
		if (x <= 0 and y <= 0) then
			SetMapZoom(GetCurrentMapContinent());
			x, y = GetPlayerMapPosition(unit);
			if (x <= 0 and y <= 0) then
				-- we are in an instance or otherwise off the continent map
				return;
			end
		end
		local C, Z = GetCurrentMapContinent(), GetCurrentMapZone();
		if (C ~= lastCont or Z ~= lastZone) then
			SetMapZoom(lastCont, lastZone); -- set map zoom back to what it was before
		end
		return C, Z, x, y;
	end
	return GetCurrentMapContinent(), GetCurrentMapZone(), x, y;
end
-- *****************************************************************************
-- This function will do its utmost to retrieve some sort of valid position
-- for the specified unit, including changing the current map zoom (if needed).
-- However, if a monitored WorldMapFrame (See AstrolabeMapMonitor.lua) is
-- visible, then will simply return nil if the current zoom does not provide
-- a valid position for the player unit.  Map Zoom is returned to its previous
-- setting before this function returns, if it was changed.
-- *****************************************************************************
function Astrolabe:GetCurrentPlayerPosition()
	local x, y = GetPlayerMapPosition("player");
	if (x <= 0 and y <= 0) then
		if (self.WorldMapVisible) then
			-- we know there is a visible world map, so don't cause
			-- WORLD_MAP_UPDATE events by changing map zoom
			return;
		end
		local lastCont, lastZone = GetCurrentMapContinent(), GetCurrentMapZone();
		SetMapToCurrentZone();
		x, y = GetPlayerMapPosition("player");
		if (x <= 0 and y <= 0) then
			SetMapZoom(GetCurrentMapContinent());
			x, y = GetPlayerMapPosition("player");
			if (x <= 0 and y <= 0) then
				-- we are in an instance or otherwise off the continent map
				return;
			end
		end
		local C, Z = GetCurrentMapContinent(), GetCurrentMapZone();
		if (C ~= lastCont or Z ~= lastZone) then
			SetMapZoom(lastCont, lastZone); -- set map zoom back to what it was before
		end
		return C, Z, x, y;
	end
	return GetCurrentMapContinent(), GetCurrentMapZone(), x, y;
end
--------------------------------------------------------------------------------------------------------------
-- Working Table Cache System
--------------------------------------------------------------------------------------------------------------
local tableCache = {};
tableCache["__mode"] = "v";
setmetatable(tableCache, tableCache);
local function GetWorkingTable(icon)
	if (tableCache[icon]) then
		return tableCache[icon];
	else
		local T = {};
		tableCache[icon] = T;
		return T;
	end
end
--------------------------------------------------------------------------------------------------------------
-- Minimap Icon Placement
--------------------------------------------------------------------------------------------------------------
-- *****************************************************************************
-- local variables specifically for use in this section
-- *****************************************************************************
local minimapRotationEnabled = false;
local minimapShape = false;
local minimapRotationOffset = GetPlayerFacing();
local function placeIconOnMinimap(minimap, minimapZoom, mapWidth, mapHeight, icon, dist, xDist, yDist)
	local mapDiameter;
	if (Astrolabe.minimapOutside) then
		mapDiameter = MinimapSize.outdoor[minimapZoom];
	else
		mapDiameter = MinimapSize.indoor[minimapZoom];
	end
	local mapRadius = mapDiameter / 2;
	local xScale = mapDiameter / mapWidth;
	local yScale = mapDiameter / mapHeight;
	local iconDiameter = ((icon:GetWidth() / 2) + 3) * xScale;
	local iconOnEdge = nil;
	local isRound = true;
	if (minimapRotationEnabled) then
		local sinTheta = sin(minimapRotationOffset)
		local cosTheta = cos(minimapRotationOffset)
		--[[
		Math Note
		The math that is acutally going on in the next 3 lines is:
			local dx, dy = xDist, -yDist
			xDist = (dx * cosTheta) + (dy * sinTheta)
			yDist = -((-dx * sinTheta) + (dy * cosTheta))
		This is because the origin for map coordinates is the top left corner
		of the map, not the bottom left, and so we have to reverse the vertical
		distance when doing the our rotation, and then reverse the result vertical
		distance because this rotation formula gives us a result with the origin based
		in the bottom left corner (of the (+, +) quadrant).
		The actual code is a simplification of the above.
		]]
		local dx, dy = xDist, yDist
		xDist = (dx * cosTheta) - (dy * sinTheta)
		yDist = (dx * sinTheta) + (dy * cosTheta)
	end
	if (minimapShape and not (xDist == 0 or yDist == 0)) then
		isRound = (xDist < 0) and 1 or 3;
		if (yDist < 0) then
			isRound = minimapShape[isRound];
		else
			isRound = minimapShape[isRound + 1];
		end
	end
	-- for non-circular portions of the Minimap edge
	if not (isRound) then
		dist = max(abs(xDist), abs(yDist))
	end
	if ((dist + iconDiameter) > mapRadius) then
		-- position along the outside of the Minimap
		iconOnEdge = true;
		local factor = (mapRadius - iconDiameter) / dist;
		xDist = xDist * factor;
		yDist = yDist * factor;
	end
	if (Astrolabe.IconsOnEdge[icon] ~= iconOnEdge) then
		Astrolabe.IconsOnEdge[icon] = iconOnEdge;
		Astrolabe.IconsOnEdgeChanged = true;
	end
	icon:ClearAllPoints();
	icon:SetPoint("CENTER", minimap, "CENTER", xDist / xScale, -yDist / yScale);
end
function Astrolabe:PlaceIconOnMinimap(icon, continent, zone, xPos, yPos)
	-- check argument types
	argcheck(icon, 2, "table");
	assert(3, icon.SetPoint and icon.ClearAllPoints, "Usage Message");
	argcheck(continent, 3, "number");
	argcheck(zone, 4, "number", "nil");
	argcheck(xPos, 5, "number");
	argcheck(yPos, 6, "number");
	-- if the positining system is currently active, just use the player position used by the last incremental (or full) update
	-- otherwise, make sure we base our calculations off of the most recent player position (if one is available)
	local lC, lZ, lx, ly;
	if (self.processingFrame:IsShown()) then
		lC, lZ, lx, ly = unpack(self.LastPlayerPosition);
	else
		lC, lZ, lx, ly = self:GetCurrentPlayerPosition();
		if (lC and lC >= 0) then
			local lastPosition = self.LastPlayerPosition;
			lastPosition[1] = lC;
			lastPosition[2] = lZ;
			lastPosition[3] = lx;
			lastPosition[4] = ly;
		else
			lC, lZ, lx, ly = unpack(self.LastPlayerPosition);
		end
	end
	local dist, xDist, yDist = self:ComputeDistance(lC, lZ, lx, ly, continent, zone, xPos, yPos);
	if not (dist) then
		-- icon's position has no meaningful position relative to the player's current location
		return -1;
	end
	local iconData = GetWorkingTable(icon);
	if (self.MinimapIcons[icon]) then
		self.MinimapIcons[icon] = nil;
	else
		self.MinimapIconCount = self.MinimapIconCount + 1
	end
	AddedOrUpdatedIcons[icon] = iconData
	iconData.continent = continent;
	iconData.zone = zone;
	iconData.xPos = xPos;
	iconData.yPos = yPos;
	iconData.dist = dist;
	iconData.xDist = xDist;
	iconData.yDist = yDist;
	minimapRotationEnabled = GetCVar("rotateMinimap") ~= "0"
	if (minimapRotationEnabled) then
		minimapRotationOffset = GetPlayerFacing();
	end
	-- check Minimap Shape
	minimapShape = GetMinimapShape and ValidMinimapShapes[GetMinimapShape()];
	-- place the icon on the Minimap and :Show() it
	local map = Minimap
	placeIconOnMinimap(map, map:GetZoom(), map:GetWidth(), map:GetHeight(), icon, dist, xDist, yDist);
	icon:Show()
	-- We know this icon's position is valid, so we need to make sure the icon placement system is active.
	self.processingFrame:Show()
	return 0;
end
function Astrolabe:RemoveIconFromMinimap(icon)
	if not (self.MinimapIcons[icon]) then
		return 1;
	end
	AddedOrUpdatedIcons[icon] = nil
	self.MinimapIcons[icon] = nil;
	self.IconsOnEdge[icon] = nil;
	icon:Hide();
	local MinimapIconCount = self.MinimapIconCount - 1
	if (MinimapIconCount <= 0) then
		-- no icons left to manage
		self.processingFrame:Hide()
		MinimapIconCount = 0 -- because I'm paranoid
	end
	self.MinimapIconCount = MinimapIconCount
	return 0;
end
function Astrolabe:RemoveAllMinimapIcons()
	self:DumpNewIconsCache()
	local MinimapIcons = self.MinimapIcons;
	local IconsOnEdge = self.IconsOnEdge;
	for k, v in pairs(MinimapIcons) do
		MinimapIcons[k] = nil;
		IconsOnEdge[k] = nil;
		k:Hide();
	end
	self.MinimapIconCount = 0
	self.processingFrame:Hide()
end
local lastZoom; -- to remember the last seen Minimap zoom level
-- local variables to track the status of the two update coroutines
local fullUpdateInProgress = true
local resetIncrementalUpdate = false
local resetFullUpdate = false
-- Incremental Update Code
do
	-- local variables to track the incremental update coroutine
	local incrementalUpdateCrashed = true
	local incrementalUpdateThread
	local function UpdateMinimapIconPositions(self)
		yield()
		while (true) do
			self:DumpNewIconsCache() -- put new/updated icons into the main datacache
			resetIncrementalUpdate = false -- by definition, the incremental update is reset if it is here
			local C, Z, x, y = self:GetCurrentPlayerPosition();
			if (C and C >= 0) then
				local Minimap = Minimap;
				local lastPosition = self.LastPlayerPosition;
				local lC, lZ, lx, ly = unpack(lastPosition);
				minimapRotationEnabled = GetCVar("rotateMinimap") ~= "0"
				if (minimapRotationEnabled) then
					minimapRotationOffset = GetPlayerFacing();
				end
				-- check current frame rate
				local numPerCycle = min(50, GetFramerate() * (self.MinimapUpdateMultiplier or 1))
				-- check Minimap Shape
				minimapShape = GetMinimapShape and ValidMinimapShapes[GetMinimapShape()];
				if (lC == C and lZ == Z and lx == x and ly == y) then
					-- player has not moved since the last update
					if (lastZoom ~= Minimap:GetZoom() or self.ForceNextUpdate or minimapRotationEnabled) then
						local currentZoom = Minimap:GetZoom();
						lastZoom = currentZoom;
						local mapWidth = Minimap:GetWidth();
						local mapHeight = Minimap:GetHeight();
						numPerCycle = numPerCycle * 2
						local count = 0
						for icon, data in pairs(self.MinimapIcons) do
							placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, data.dist, data.xDist,
								data.yDist);
							count = count + 1
							if (count > numPerCycle) then
								count = 0
								yield()
								-- check if the incremental update cycle needs to be reset
								-- because a full update has been run
								if (resetIncrementalUpdate) then
									break
								end
							end
						end
						self.ForceNextUpdate = false;
					end
				else
					local dist, xDelta, yDelta = self:ComputeDistance(lC, lZ, lx, ly, C, Z, x, y);
					if (dist) then
						local currentZoom = Minimap:GetZoom();
						lastZoom = currentZoom;
						local mapWidth = Minimap:GetWidth();
						local mapHeight = Minimap:GetHeight();
						local count = 0
						for icon, data in pairs(self.MinimapIcons) do
							local xDist = data.xDist - xDelta;
							local yDist = data.yDist - yDelta;
							local dist = sqrt(xDist * xDist + yDist * yDist);
							placeIconOnMinimap(Minimap, currentZoom, mapWidth, mapHeight, icon, dist, xDist, yDist);
							data.dist = dist;
							data.xDist = xDist;
							data.yDist = yDist;
							count = count + 1
							if (count >= numPerCycle) then
								count = 0
								yield()
								-- check if the incremental update cycle needs to be reset
								-- because a full update has been run
								if (resetIncrementalUpdate) then
									break
								end
							end
						end
						if not (resetIncrementalUpdate) then
							lastPosition[1] = C;
							lastPosition[2] = Z;
							lastPosition[3] = x;
							lastPosition[4] = y;
						end
					else
						self:RemoveAllMinimapIcons()
						lastPosition[1] = C;
						lastPosition[2] = Z;
						lastPosition[3] = x;
						lastPosition[4] = y;
					end
				end
			else
				if not (self.WorldMapVisible) then
					self.processingFrame:Hide();
				end
			end
			-- if we've been reset, then we want to start the new cycle immediately
			if not (resetIncrementalUpdate) then
				yield()
			end
		end
	end
	function Astrolabe:UpdateMinimapIconPositions()
		if (fullUpdateInProgress) then
			-- if we're in the middle a a full update, we want to finish that first
			self:CalculateMinimapIconPositions()
		else
			if (incrementalUpdateCrashed) then
				incrementalUpdateThread = coroutine.wrap(UpdateMinimapIconPositions)
				incrementalUpdateThread(self) -- initialize the thread
			end
			incrementalUpdateCrashed = true
			incrementalUpdateThread()
			incrementalUpdateCrashed = false
		end
	end
end

