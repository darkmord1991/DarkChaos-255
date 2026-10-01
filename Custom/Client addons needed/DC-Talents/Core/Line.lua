--[[
	DC-Talents - retail Line regions on 3.3.5.

	Retail talent edges are Line regions (SetStartPoint / SetEndPoint / SetThickness). 3.3.5 has no
	Line type, so a line is a texture on its owner drawn as a rotated quad with the stock 3.3.5
	DrawRouteLine technique (the taxi map's flight path lines): the bounding box and eight texture
	coordinates are computed so a horizontal line image appears rotated. That needs a line image with
	a transparent 1px border inside a 32px texture (the 32/30 factor below), so retail line atlases
	are mapped onto Textures/Line plus a vertex colour (Line.atlasStyles, filled by the DC layer).

	Endpoints are resolved from the anchored regions' rects. Rects are not valid until the client
	has laid the frames out, so lines whose endpoints are not ready are retried on the next frames.
	The quad is anchored to the start region, not to the line's owner: retail lines do not depend
	on their owner's rect, and talent edge frames are never anchored at all.
]]

local _, ns = ...
setfenv(1, ns.env)

local Line = {}
ns.Line = Line

local LINE_FACTOR = 32 / 30
local LINE_FACTOR_2 = LINE_FACTOR / 2

Line.DEFAULT_TEXTURE = "Interface\\AddOns\\DC-Talents\\Textures\\Line"

-- atlas or file name -> { texture = path, r, g, b, a }
Line.atlasStyles = {}

local pending = {}
local allLines = setmetatable({}, { __mode = "k" })
local driver

local function PointPosition(region, point)
	local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
	if not (left and right and top and bottom) then
		return nil
	end

	local x, y
	point = point or "CENTER"
	if point:find("LEFT") then
		x = left
	elseif point:find("RIGHT") then
		x = right
	else
		x = (left + right) / 2
	end
	if point:find("TOP") then
		y = top
	elseif point:find("BOTTOM") then
		y = bottom
	else
		y = (top + bottom) / 2
	end

	local scale = ns.Engine.EffectiveScaleOf(region)
	return x * scale, y * scale
end

-- Stock 3.3.5 TaxiFrame.lua DrawRouteLine (Daniel Stephens), with our line factor.
local function DrawRotatedQuad(texture, canvas, sx, sy, ex, ey, width)
	local dx, dy = ex - sx, ey - sy
	local cx, cy = (sx + ex) / 2, (sy + ey) / 2

	if dx < 0 then
		dx, dy = -dx, -dy
	end

	local length = math.sqrt((dx * dx) + (dy * dy))
	texture.__dcNativeClearAllPoints(texture)
	if length == 0 then
		texture:SetTexCoord(0, 0, 0, 0, 0, 0, 0, 0)
		texture.__dcNativeSetPoint(texture, "BOTTOMLEFT", canvas, "BOTTOMLEFT", cx, cy)
		texture.__dcNativeSetPoint(texture, "TOPRIGHT", canvas, "BOTTOMLEFT", cx, cy)
		return
	end

	local s, c = -dy / length, dx / length
	local sc = s * c

	local boxWidth, boxHeight, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
	if dy >= 0 then
		boxWidth = ((length * c) - (width * s)) * LINE_FACTOR_2
		boxHeight = ((width * c) - (length * s)) * LINE_FACTOR_2
		BLx, BLy, BRy = (width / length) * sc, s * s, (length / width) * sc
		BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
		TRy = BRx
	else
		boxWidth = ((length * c) + (width * s)) * LINE_FACTOR_2
		boxHeight = ((width * c) + (length * s)) * LINE_FACTOR_2
		BLx, BLy, BRx = s * s, -(length / width) * sc, 1 + (width / length) * sc
		BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
		TRx = TLy
	end

	texture:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
	texture.__dcNativeSetPoint(texture, "BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - boxWidth, cy - boxHeight)
	texture.__dcNativeSetPoint(texture, "TOPRIGHT", canvas, "BOTTOMLEFT", cx + boxWidth, cy + boxHeight)
end

local function Draw(line)
	local startInfo, endInfo = line.__dcStart, line.__dcEnd
	if not (startInfo and endInfo) then
		return true
	end

	local canvas = startInfo.region
	local canvasLeft, canvasBottom = canvas:GetLeft(), canvas:GetBottom()
	local sx, sy = PointPosition(startInfo.region, startInfo.point)
	local ex, ey = PointPosition(endInfo.region, endInfo.point)
	if not (canvasLeft and canvasBottom and sx and ex) then
		return false
	end

	-- Everything in the line's own units (its owner's scale), relative to the canvas' bottom left.
	local lineScale = line:GetParent():GetEffectiveScale()
	local canvasScale = ns.Engine.EffectiveScaleOf(canvas)
	local baseX, baseY = canvasLeft * canvasScale, canvasBottom * canvasScale
	sx = (sx - baseX) / lineScale + (startInfo.x or 0)
	sy = (sy - baseY) / lineScale + (startInfo.y or 0)
	ex = (ex - baseX) / lineScale + (endInfo.x or 0)
	ey = (ey - baseY) / lineScale + (endInfo.y or 0)

	DrawRotatedQuad(line, canvas, sx, sy, ex, ey, line.__dcThickness or 1)
	return true
end

local function OnDriverUpdate(self)
	local anyLeft = false
	for line in pairs(pending) do
		if Draw(line) then
			pending[line] = nil
		else
			anyLeft = true
		end
	end
	if not anyLeft then
		self:Hide()
	end
end

local function Schedule(line)
	if not Draw(line) then
		if not driver then
			driver = ns.realG.CreateFrame("Frame")
			driver:SetScript("OnUpdate", OnDriverUpdate)
		end
		pending[line] = true
		driver:Show()
	else
		pending[line] = nil
	end
end

-- Redraws every line (after frames were re-laid out, e.g. the window was rescaled).
function Line.RefreshAll()
	for line in pairs(allLines) do
		if line.__dcStart and line.__dcEnd then
			Schedule(line)
		end
	end
end

local LineMethods = {}

function LineMethods:SetStartPoint(relativePoint, relativeTo, offsetX, offsetY)
	self.__dcStart = { point = relativePoint, region = relativeTo or self:GetParent(), x = offsetX, y = offsetY }
	Schedule(self)
end

function LineMethods:SetEndPoint(relativePoint, relativeTo, offsetX, offsetY)
	self.__dcEnd = { point = relativePoint, region = relativeTo or self:GetParent(), x = offsetX, y = offsetY }
	Schedule(self)
end

function LineMethods:GetStartPoint()
	local info = self.__dcStart
	if info then
		return info.point, info.region, info.x or 0, info.y or 0
	end
end

function LineMethods:GetEndPoint()
	local info = self.__dcEnd
	if info then
		return info.point, info.region, info.x or 0, info.y or 0
	end
end

function LineMethods:SetThickness(thickness)
	self.__dcThickness = thickness
	if self.__dcStart and self.__dcEnd then
		Schedule(self)
	end
end

function LineMethods:GetThickness()
	return self.__dcThickness or 1
end

function LineMethods:ClearAllPoints()
	self.__dcStart = nil
	self.__dcEnd = nil
	pending[self] = nil
	self.__dcNativeClearAllPoints(self)
end

local function ApplyStyle(line, style)
	line.__dcNativeSetTexture(line, style.texture or Line.DEFAULT_TEXTURE)
	if style.r then
		line:SetVertexColor(style.r, style.g, style.b, style.a or 1)
	end
end

function LineMethods:SetAtlas(atlasName)
	local style = Line.atlasStyles[atlasName]
	if style then
		ApplyStyle(self, style)
	else
		self.__dcNativeSetTexture(self, Line.DEFAULT_TEXTURE)
	end
	self.__dcAtlas = atlasName
	if self.__dcStart and self.__dcEnd then
		Schedule(self)
	end
	return true
end

function LineMethods:SetTexture(file, ...)
	if type(file) == "number" then
		-- SetTexture(r, g, b, a) solid colour line.
		self.__dcNativeSetTexture(self, Line.DEFAULT_TEXTURE)
		self:SetVertexColor(file, ...)
		return
	end
	local style = file and Line.atlasStyles[file]
	if style then
		ApplyStyle(self, style)
	else
		self.__dcNativeSetTexture(self, Line.DEFAULT_TEXTURE)
	end
end

function LineMethods:SetColorTexture(r, g, b, a)
	self.__dcNativeSetTexture(self, Line.DEFAULT_TEXTURE)
	self:SetVertexColor(r, g, b, a or 1)
end

function LineMethods:GetObjectType()
	return "Line"
end

function Line.Create(owner, name, layer, sublevel)
	local texture = owner.__dcNativeCreateTexture and owner.__dcNativeCreateTexture(owner, name, layer or "ARTWORK")
		or owner:CreateTexture(name, layer or "ARTWORK")
	ns.Engine.PrepareRegion(texture)

	-- The raw setter: the atlas-aware SetTexture would forget the line's atlas name.
	texture.__dcNativeSetTexture = texture.__dcRawSetTexture or texture.SetTexture
	texture.__dcNativeClearAllPoints = texture.ClearAllPoints
	texture.__dcNativeSetPoint = texture.__dcNativeSetPoint or texture.SetPoint
	for methodName, func in pairs(LineMethods) do
		texture[methodName] = func
	end

	texture.__dcNativeSetTexture(texture, Line.DEFAULT_TEXTURE)
	texture.__dcThickness = 1
	allLines[texture] = true
	return texture
end
