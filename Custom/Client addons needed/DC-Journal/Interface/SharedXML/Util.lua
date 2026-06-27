--	Filename:	Util.lua
--	Project:	Sirus Game Interface
--	Author:		Nyll
--	E-mail:		nyll@sirus.su
--	Web:		https://sirus.su/

local LOCAL_ToStringAllTemp = {};
function tostringall(...)
    local n = select('#', ...)
    -- Simple versions for common argument counts
    if (n == 1) then
        return tostring(...)
    elseif (n == 2) then
        local a, b = ...
        return tostring(a), tostring(b)
    elseif (n == 3) then
        local a, b, c = ...
        return tostring(a), tostring(b), tostring(c)
    elseif (n == 0) then
        return
    end

    local needfix
    for i = 1, n do
        local v = select(i, ...)
        if (type(v) ~= "string") then
            needfix = i
            break
        end
    end
    if (not needfix) then return ...; end

    wipe(LOCAL_ToStringAllTemp)
    for i = 1, needfix - 1 do
        LOCAL_ToStringAllTemp[i] = select(i, ...)
    end
    for i = needfix, n do
        LOCAL_ToStringAllTemp[i] = tostring(select(i, ...))
    end
    return unpack(LOCAL_ToStringAllTemp)
end


CHARACTER_RACES_INFO = {
	["HUMAN"] = {id = 1, male = "Human", female = "Human", faction = "Alliance"},
	["DWARF"] = {id = 3, male = "Dwarf", female = "Dwarf", faction = "Alliance"},
	["NIGHTELF"] = {id = 4, male = "Night Elf", female = "Night Elf", faction = "Alliance"},
	["GNOME"] = {id = 7, male = "Gnome", female = "Gnome", faction = "Alliance"},
	["DRAENEI"] = {id = 11, male = "Draenei", female = "Draenei", faction = "Alliance"},
	["WORGEN"] = {id = 12, male = "Worgen", female = "Worgen", faction = "Alliance"},
	["QUELDO"] = {id = 15, male = "High Elf", female = "High Elf", faction = "Alliance"},

	["PANDAREN_A"] = {id = 14, male = "Pandaren (Alliance)", female = "Pandaren (Alliance)", faction = "Alliance"},
	["PANDAREN_H"] = {id = 16, male = "Pandaren (Horde)", female = "Pandaren (Horde)", faction = "Horde"},

	["ORC"] = {id = 2, male = "Orc", female = "Orc", faction = "Horde"},
	["SCOURGE"] = {id = 5, male = "Undead", female = "Undead", faction = "Horde"},
	["TAUREN"] = {id = 6, male = "Tauren", female = "Tauren", faction = "Horde"},
	["TROLL"] = {id = 8, male = "Troll", female = "Troll", faction = "Horde"},
	["GOBLIN"] = {id = 9, male = "Goblin", female = "Goblin", faction = "Horde"},
	["BLOODELF"] = {id = 10, male = "Sin'dorei", female = "Sin'dorei", faction = "Horde"},
	["NAGA"] = {id = 13,  male = "Naga", female = "Naga", faction = "Horde"},
}

function GetRaceInfoByLocaleName(raceName)
	raceName = string.upper(raceName)

	for raceNames, arr in pairs(CHARACTER_RACES_INFO) do
		if string.upper(arr.male) == raceName or string.upper(arr.female) == raceName then
			return arr.id, raceNames, arr.male, arr.female, arr.faction
		end
	end
end

function GetRaceInfoByName(raceName)
	raceName = string.upper(raceName)

	if not CHARACTER_RACES_INFO[raceName] then
		error("Error in GetRaceInfoByName. No information for race "..raceName..". Contact Nyll")
		return
	end

	local arr = CHARACTER_RACES_INFO[raceName]
	return arr.id, raceName, arr.male, arr.female, arr.faction
end

function SetItemButtonQuality(button, quality, itemIDOrLink)
	if itemIDOrLink and IsArtifactRelicItem(itemIDOrLink) then
		button.IconBorder:SetTexture([[Interface\Artifacts\RelicIconFrame]]);
	else
		button.IconBorder:SetTexture([[Interface\Common\WhiteIconFrame]]);
	end

	if quality then
		if quality >= LE_ITEM_QUALITY_COMMON and BAG_ITEM_QUALITY_COLORS[quality] then
			button.IconBorder:Show();
			button.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b);
		else
			button.IconBorder:Hide();
		end
	else
		button.IconBorder:Hide();
	end
end

function GetFinalNameFromTextureKit(fmt, textureKit)
	return fmt:format(textureKit);
end

function SetClampedTextureRotation(texture, rotationDegrees)
	if (rotationDegrees ~= 0 and rotationDegrees ~= 90 and rotationDegrees ~= 180 and rotationDegrees ~= 270) then
		error("SetRotation: rotationDegrees must be 0, 90, 180, or 270");
		return;
	end

	if not (texture.rotationDegrees) then
		texture.origTexCoords = {texture:GetTexCoord()};
		texture.origWidth = texture:GetWidth();
		texture.origHeight = texture:GetHeight();
	end

	if (texture.rotationDegrees == rotationDegrees) then
		return;
	end

	texture.rotationDegrees = rotationDegrees;

	if (rotationDegrees == 0 or rotationDegrees == 180) then
		texture:SetWidth(texture.origWidth);
		texture:SetHeight(texture.origHeight);
	else
		texture:SetWidth(texture.origHeight);
		texture:SetHeight(texture.origWidth);
	end

	if (rotationDegrees == 0) then
		texture:SetTexCoord( texture.origTexCoords[1], texture.origTexCoords[2],
											texture.origTexCoords[3], texture.origTexCoords[4],
											texture.origTexCoords[5], texture.origTexCoords[6],
											texture.origTexCoords[7], texture.origTexCoords[8] );
	elseif (rotationDegrees == 90) then
		texture:SetTexCoord( texture.origTexCoords[3], texture.origTexCoords[4],
											texture.origTexCoords[7], texture.origTexCoords[8],
											texture.origTexCoords[1], texture.origTexCoords[2],
											texture.origTexCoords[5], texture.origTexCoords[6] );
	elseif (rotationDegrees == 180) then
		texture:SetTexCoord( texture.origTexCoords[7], texture.origTexCoords[8],
											texture.origTexCoords[5], texture.origTexCoords[6],
											texture.origTexCoords[3], texture.origTexCoords[4],
											texture.origTexCoords[1], texture.origTexCoords[2] );
	elseif (rotationDegrees == 270) then
		texture:SetTexCoord( texture.origTexCoords[5], texture.origTexCoords[6],
											texture.origTexCoords[1], texture.origTexCoords[2],
											texture.origTexCoords[7], texture.origTexCoords[8],
											texture.origTexCoords[3], texture.origTexCoords[4] );
	end
end

function GetTexCoordsByGrid(xOffset, yOffset, textureWidth, textureHeight, gridWidth, gridHeight)
	local widthPerGrid = gridWidth/textureWidth;
	local heightPerGrid = gridHeight/textureHeight;
	return (xOffset-1)*widthPerGrid, (xOffset)*widthPerGrid, (yOffset-1)*heightPerGrid, (yOffset)*heightPerGrid;
end

function GetTexCoordsForRole(role)
	local textureHeight, textureWidth = 256, 256;
	local roleHeight, roleWidth = 67, 67;

	if ( role == "GUIDE" ) then
		return GetTexCoordsByGrid(1, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "TANK" ) then
		return GetTexCoordsByGrid(1, 2, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "HEALER" ) then
		return GetTexCoordsByGrid(2, 1, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "DAMAGER" ) then
		return GetTexCoordsByGrid(2, 2, textureWidth, textureHeight, roleWidth, roleHeight);
	elseif ( role == "RANGEDAMAGER" ) then
		return GetTexCoordsByGrid(3, 3, textureWidth, textureHeight, roleWidth, roleHeight);
	else
		error("Unknown role: "..tostring(role));
	end
end

function GetTexCoordsByMask(ws, hs, x, y, w, h)
    return {x/ws, x/ws + w/ws, y/hs, y/hs + h/hs}
end

function GetSpriteFromImage(x, y, w, h, iw, ih)
    return (x*w)/iw, ((x+1)*w)/iw, (y*h)/ih, ((y+1)*h)/ih
end

function PercentageBetween(value, startValue, endValue)
	if startValue == endValue then
		return 0.0;
	end
	return (value - startValue) / (endValue - startValue);
end

function ClampedPercentageBetween(value, startValue, endValue)
	return Saturate(PercentageBetween(value, startValue, endValue));
end

function GetTexCoordsForRoleSmallCircle(role)
	if ( role == "TANK" ) then
		return 0, 19/64, 22/64, 41/64;
	elseif ( role == "HEALER" ) then
		return 20/64, 39/64, 1/64, 20/64;
	elseif ( role == "DAMAGER" ) then
		return 20/64, 39/64, 22/64, 41/64;
	else
		error("Unknown role: "..tostring(role));
	end
end

function GetTexCoordsForRoleSmall(role)
	if ( role == "TANK" ) then
		return 0.5, 0.75, 0, 1;
	elseif ( role == "HEALER" ) then
		return 0.75, 1, 0, 1;
	elseif ( role == "DAMAGER" ) then
		return 0.25, 0.5, 0, 1;
	else
		error("Unknown role: "..tostring(role));
	end
end

function tDeleteItem(table, item)
	local index = 1;
	while table[index] do
		if ( item == table[index] ) then
			tremove(table, index);
		else
			index = index + 1;
		end
	end
end

function tCount( t )
	t = t or {}
	local i = 0
	for k in pairs(t) do i = i + 1 end
	return i
end

function tDifference(a, b)
    local ai = {}
    local r = {}
    for k,v in pairs(a) do r[k] = v; ai[v]=true end
    for k,v in pairs(b) do
        if ai[v]~=nil then   r[k] = nil   end
    end
    return r
end

function tIndexOf(tbl, item)
	for i, v in ipairs(tbl) do
		if item == v then
			return i;
		end
	end
end

function tContains(table, item)
	local index = 1;
	while table[index] do
		if (item and item == table[index] ) then
			return true;
		end
		index = index + 1;
	end
	return false;
end

function tContainsWithReturn(table, item)
	local index = 1;
	while table[index] do
		if (item and item == table[index] ) then
			return item;
		end
		index = index + 1;
	end
	return false;
end

-- This is a deep compare on the values of the table (based on depth) but not a deep comparison
-- of the keys, as this would be an expensive check and won't be necessary in most cases.
function tCompare(lhsTable, rhsTable, depth)
	depth = depth or 1;
	for key, value in pairs(lhsTable) do
		if type(value) == "table" then
			local rhsValue = rhsTable[key];
			if type(rhsValue) ~= "table" then
				return false;
			end
			if depth > 1 then
				if not tCompare(value, rhsValue, depth - 1) then
					return false;
				end
			end
		elseif value ~= rhsTable[key] then
			return false;
		end
	end

	-- Check for any keys that are in rhsTable and not lhsTable.
	for key, value in pairs(rhsTable) do
		if lhsTable[key] == nil then
			return false;
		end
	end

	return true;
end

function tInvert(tbl)
	local inverted = {};
	for k, v in pairs(tbl) do
		inverted[v] = k;
	end
	return inverted;
end

function tAppendAll(table, addedArray)
	for i, element in ipairs(addedArray) do
		tinsert(table, element);
	end
end

function CopyTable(settings)
	local copy = {};
	for k, v in pairs(settings) do
		if ( type(v) == "table" ) then
			copy[k] = CopyTable(v);
		else
			copy[k] = v;
		end
	end
	return copy;
end

function reverse(t)
    local nt = {}
    local size = #t + 1
    for k, v in ipairs(t) do
        nt[size - k] = v
    end
    return nt
end

function toBits(num)
    local t = {}
    while num > 0 do
        rest = math.fmod(num, 2)
        t[#t + 1] = rest
        num = (num - rest) / 2
    end
    return reverse(t)
end

function rgb( r, g, b )
	return r / 255, g / 255, b / 255
end

function ConvertRGBtoColorString(color)
	local colorString = "|cff";
	local r = color.r * 255;
	local g = color.g * 255;
	local b = color.b * 255;
	colorString = colorString..string.format("%2x%2x%2x", r, g, b);
	return colorString;
end

function SetLargeGuildTabardTextures( frame, id )
	local emblemSize = 64 / 1024
	local columns = 16
	local offset = 0

	local xCoord = mod(id, columns) * emblemSize
	local yCoord = floor(id / columns) * emblemSize
	frame:SetTexCoord(xCoord + offset, xCoord + emblemSize - offset, yCoord + offset, yCoord + emblemSize - offset)
end

function SetSmallGuildTabardTextures( frame, id )
	local emblemSize = 18 / 256
	local columns = 14
	local offset = 1 / 256

	local xCoord = mod(id, columns) * emblemSize
	local yCoord = floor(id / columns) * emblemSize
	frame:SetTexCoord(xCoord + offset, xCoord + emblemSize - offset, yCoord + offset, yCoord + emblemSize - offset)
end

function CreateTextureMarkup(file, fileWidth, fileHeight, width, height, left, right, top, bottom)
	return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
		  file
		, height
		, width
		, fileWidth
		, fileHeight
		, left * fileWidth
		, right * fileWidth
		, top * fileHeight
		, bottom * fileHeight
	);
end

function CreateAtlasMarkup(atlasName, width, height, offsetX, offsetY, fileWidth, fileHeight)
	if S_ATLAS_STORAGE[atlasName] then
		local atlasWidth, atlasHeight, left, right, top, bottom, _, _, texturePath = unpack(S_ATLAS_STORAGE[atlasName])
		width = width or atlasWidth
		height = height or atlasHeight
		return ("|T%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(
			  texturePath
			, width
			, height
			, offsetX
			, offsetY
			, fileWidth
			, fileHeight
			, math.ceil(left * fileWidth)
			, math.ceil(right * fileWidth)
			, math.ceil(top * fileHeight)
			, math.ceil(bottom * fileHeight)
		);
	else
		return ""
	end
end

-- https://gist.github.com/gdeglin/4128882
-- returns the number of bytes used by the UTF-8 character at byte i in s
-- also doubles as a UTF-8 character validator
function utf8charbytes(s, i)
    -- argument defaults
    i = i or 1
    local c = string.byte(s, i)
    -- determine bytes needed for character, based on RFC 3629
    if c > 0 and c <= 127 then
        -- UTF8-1
        return 1
    elseif c >= 194 and c <= 223 then
        -- UTF8-2
        local c2 = string.byte(s, i + 1)
        return 2
    elseif c >= 224 and c <= 239 then
        -- UTF8-3
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        return 3
    elseif c >= 240 and c <= 244 then
        -- UTF8-4
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        local c4 = s:byte(i + 3)
        return 4
    end
end

-- returns the number of characters in a UTF-8 string
function utf8len(s)
    local pos = 1
    local bytes = string.len(s)
    local len = 0

    while pos <= bytes and len ~= chars do
        local c = string.byte(s,pos)
        len = len + 1

        pos = pos + utf8charbytes(s, pos)
    end

    if chars ~= nil then
        return pos - 1
    end

    return len
end

function BitMaskCalculate( ... )
	local value = {...}
	local mask = 0

	for i = 1, #value do
		local data = value[i]

		if data then
			mask = bit.bor(mask, data)
		end
	end

	return mask
end

local totable = string.ToTable
local string_sub = string.sub
local string_find = string.find
local string_len = string.len

function string.Explode(separator, str, withpattern)
    if ( separator == "" ) then return totable( str ) end
    if ( withpattern == nil ) then withpattern = false end

    local ret = {}
    local current_pos = 1

    for i = 1, string_len( str ) do
        local start_pos, end_pos = string_find( str, separator, current_pos, not withpattern )
        if ( not start_pos ) then break end
        ret[ i ] = string_sub( str, current_pos, start_pos - 1 )
        if ret[ i ] == "" then
            ret[ i ] = nil
        end
        current_pos = end_pos + 1
    end

    ret[ #ret + 1 ] = string_sub( str, current_pos )
    if ret[ #ret ] == "" then
        ret[ #ret ] = nil
    end

    return ret
end

function C_Split( str, delimiter )
    return string.Explode( delimiter, str )
end

function printf( msg, ... )
	print( string.format( msg, ... ) )
end

function C_InRange( value, min, max )
	return value and value >= min and value <= max or false
end

function Lerp(startValue, endValue, amount)
	return (1 - amount) * startValue + amount * endValue;
end

function Clamp(value, min, max)
	if value > max then
		return max;
	elseif value < min then
		return min;
	end
	return value;
end

function Saturate(value)
	return Clamp(value, 0.0, 1.0);
end

function GetClassFile( classFileLocale )
	local classFileName

	for classfileMale, classlocaleMale in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		if classfileMale and classlocaleMale == classFileLocale then
			classFileName = classfileMale
			break
		end
	end

	for classfileFemale, classlocaleFemale in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		if classfileFemale and classlocaleFemale == classFileLocale then
			classFileName = classfileFemale
			break
		end
	end

	return classFileName
end

function WrapTextInColorCode(text, colorHexString)
	return ("|c%s%s|r"):format(colorHexString, text);
end

-- ################ Mixins ################

ColorMixin = {}

function CreateColor(r, g, b, a)
	local color = CreateFromMixins(ColorMixin)
	color:OnLoad(r, g, b, a)
	return color
end

function AreColorsEqual(left, right)
	if left and right then
		return left:IsEqualTo(right)
	end
	return left == right
end

function ColorMixin:OnLoad(r, g, b, a)
	self:SetRGBA(r, g, b, a)
end

function ColorMixin:IsEqualTo(otherColor)
	return self.r == otherColor.r
		and self.g == otherColor.g
		and self.b == otherColor.b
		and self.a == otherColor.a
end

function ColorMixin:GetRGB()
	return self.r, self.g, self.b
end

function ColorMixin:GetRGBAsBytes()
	return math.Round(self.r * 255), math.Round(self.g * 255), math.Round(self.b * 255)
end

function ColorMixin:GetRGBA()
	return self.r, self.g, self.b, self.a
end

function ColorMixin:GetRGBAAsBytes()
	return math.Round(self.r * 255), math.Round(self.g * 255), math.Round(self.b * 255), math.Round((self.a or 1) * 255)
end

function ColorMixin:SetRGBA(r, g, b, a)
	self.r = r
	self.g = g
	self.b = b
	self.a = a
end

function ColorMixin:SetRGB(r, g, b)
	self:SetRGBA(r, g, b, nil)
end

function ColorMixin:ConvertToGameRGB()
	self:SetRGBA(self.r / 255, self.g / 255, self.b / 255, self.a)
	return self
end

function ColorMixin:GenerateHexColor()
	return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes())
end

function ColorMixin:GenerateHexColorMarkup()
	return "|c"..self:GenerateHexColor()
end

function ColorMixin:WrapTextInColorCode(text)
	return WrapTextInColorCode(text, self:GenerateHexColor())
end

local RAID_CLASS_COLORS = {
	["HUNTER"] = CreateColor(0.67, 0.83, 0.45),
	["WARLOCK"] = CreateColor(0.58, 0.51, 0.79),
	["PRIEST"] = CreateColor(1.0, 1.0, 1.0),
	["PALADIN"] = CreateColor(0.96, 0.55, 0.73),
	["MAGE"] = CreateColor(0.41, 0.8, 0.94),
	["ROGUE"] = CreateColor(1.0, 0.96, 0.41),
	["DRUID"] = CreateColor(1.0, 0.49, 0.04),
	["SHAMAN"] = CreateColor(0.0, 0.44, 0.87),
	["WARRIOR"] = CreateColor(0.78, 0.61, 0.43),
	["DEATHKNIGHT"] = CreateColor(0.77, 0.12 , 0.23),
	["MONK"] = CreateColor(0.0, 1.00 , 0.59),
	["DEMONHUNTER"] = CreateColor(0.64, 0.19, 0.79),
};

for _, v in pairs(RAID_CLASS_COLORS) do
	v.colorStr = v:GenerateHexColor()
end

function GetClassColor(classFilename)
	local color = RAID_CLASS_COLORS[classFilename]
	if color then
		return color.r, color.g, color.b, color.colorStr
	end

	return 1, 1, 1, "ffffffff";
end

function GetClassColorObj(classFilename)
	return RAID_CLASS_COLORS[classFilename]
end

function GetFactionColor(factionGroupTag)
	return PLAYER_FACTION_COLORS[PLAYER_FACTION_GROUP[factionGroupTag]]
end

function SendServerMessage( Header, ... )
	 --printec("Send ->", Header, ...)
	SendAddonMessage(Header, strjoin(" ", tostringall(...)), "WHISPER", UnitName("player"))
end

function AnimateTexCoordsBFA(texture, textureWidth, textureHeight, frameWidth, frameHeight, numFrames, elapsed, throttle)
	if ( not texture.frame ) then
		-- initialize everything
		texture.frame = 1;
		texture.throttle = throttle;
		texture.numColumns = floor(textureWidth/frameWidth);
		texture.numRows = floor(textureHeight/frameHeight);
		texture.columnWidth = frameWidth/textureWidth;
		texture.rowHeight = frameHeight/textureHeight;
	end
	local frame = texture.frame;
	if ( not texture.throttle or texture.throttle > throttle ) then
		local framesToAdvance = floor(texture.throttle / throttle);
		while ( frame + framesToAdvance > numFrames ) do
			frame = frame - numFrames;
		end
		frame = frame + framesToAdvance;
		texture.throttle = 0;
		local left = mod(frame-1, texture.numColumns)*texture.columnWidth;
		local right = left + texture.columnWidth;
		local bottom = ceil(frame/texture.numColumns)*texture.rowHeight;
		local top = bottom - texture.rowHeight;
		texture:SetTexCoord(left, right, top, bottom);

		texture.frame = frame;
	else
		texture.throttle = texture.throttle + elapsed;
	end
end

function CreateScaleAnim(group, order, duration, x, y, delay, smoothing)
	local scale = group:CreateAnimation("Scale")

	scale:SetOrder(order)
	scale:SetDuration(duration)
	scale:SetScale(x, y)

	if(delay) then
		scale:SetStartDelay(delay)
	end

	if(smoothing) then
		scale:SetSmoothing(smoothing)
	end
end

function TriStateCheckbox_SetState(checked, checkButton)
	local checkedTexture = _G[checkButton:GetName().."CheckedTexture"];
	if ( not checkedTexture ) then
		message("Can't find checked texture");
	end
	if ( not checked or checked == 0 ) then
		-- nil or 0 means not checked
		checkButton:SetChecked(false);
		checkButton.state = 0;
	elseif ( checked == 2 ) then
		-- 2 is a normal
		checkButton:SetChecked(true);
		checkedTexture:SetVertexColor(1, 1, 1);
		checkedTexture:SetDesaturated(false);
		checkButton.state = 2;
	else
		-- 1 is a gray check
		checkButton:SetChecked(true);
		checkedTexture:SetDesaturated(true);
		checkButton.state = 1;
	end
end

-- Time --
function SecondsToClock(seconds, displayZeroHours)
	local hours = math.floor(seconds / 3600);
	local minutes = math.floor(seconds / 60);
	if hours > 0 or displayZeroHours then
		return format(HOURS_MINUTES_SECONDS, hours, minutes, seconds % 60);
	else
		return format(MINUTES_SECONDS, minutes, seconds % 60);
	end
end

function SecondsToTime(seconds, noSeconds, notAbbreviated, maxCount, roundUp)
	local time = "";
	local count = 0;
	local tempTime;
	seconds = roundUp and ceil(seconds) or floor(seconds);
	maxCount = maxCount or 2;
	if ( seconds >= 86400  ) then
		count = count + 1;
		if ( count == maxCount and roundUp ) then
			tempTime = ceil(seconds / 86400);
		else
			tempTime = floor(seconds / 86400);
		end
		if ( notAbbreviated ) then
			time = D_DAYS:format(tempTime);
		else
			time = DAYS_ABBR:format(tempTime);
		end
		seconds = mod(seconds, 86400);
	end
	if ( count < maxCount and seconds >= 3600  ) then
		count = count + 1;
		if ( time ~= "" ) then
			time = time..TIME_UNIT_DELIMITER;
		end
		if ( count == maxCount and roundUp ) then
			tempTime = ceil(seconds / 3600);
		else
			tempTime = floor(seconds / 3600);
		end
		if ( notAbbreviated ) then
			time = time..D_HOURS:format(tempTime);
		else
			time = time..HOURS_ABBR:format(tempTime);
		end
		seconds = mod(seconds, 3600);
	end
	if ( count < maxCount and seconds >= 60  ) then
		count = count + 1;
		if ( time ~= "" ) then
			time = time..TIME_UNIT_DELIMITER;
		end
		if ( count == maxCount and roundUp ) then
			tempTime = ceil(seconds / 60);
		else
			tempTime = floor(seconds / 60);
		end
		if ( notAbbreviated ) then
			time = time..D_MINUTES:format(tempTime);
		else
			time = time..MINUTES_ABBR:format(tempTime);
		end
		seconds = mod(seconds, 60);
	end
	if ( count < maxCount and seconds > 0 and not noSeconds ) then
		if ( time ~= "" ) then
			time = time..TIME_UNIT_DELIMITER;
		end
		if ( notAbbreviated ) then
			time = time..D_SECONDS:format(seconds);
		else
			time = time..SECONDS_ABBR:format(seconds);
		end
	end
	return time;
end

function SecondsToTimeAbbrev(seconds)
	local tempTime;
	if ( seconds >= 86400  ) then
		tempTime = ceil(seconds / 86400);
		return DAY_ONELETTER_ABBR, tempTime;
	end
	if ( seconds >= 3600  ) then
		tempTime = ceil(seconds / 3600);
		return HOUR_ONELETTER_ABBR, tempTime;
	end
	if ( seconds >= 60  ) then
		tempTime = ceil(seconds / 60);
		return MINUTE_ONELETTER_ABBR, tempTime;
	end
	return SECOND_ONELETTER_ABBR, seconds;
end

function FormatShortDate(day, month, year)
	if (year) then
		if (LOCALE_enGB) then
			return SHORTDATE_EU:format(day, month, year);
		else
			return SHORTDATE:format(day, month, year);
		end
	else
		if (LOCALE_enGB) then
			return SHORTDATENOYEAR_EU:format(day, month);
		else
			return SHORTDATENOYEAR:format(day, month);
		end
	end
end

function GetRemainingTime( _time, daysformat )
	local time = _time
	local dayInSeconds = 86400
	local days = ""

	if daysformat then
		if time > 86400 then
			return math.floor(time / dayInSeconds)..string.format(" |4day:days;", time % 10)
		else
			return date("!%X", time)
		end
	else
		if time > dayInSeconds then
			days = math.floor(time / dayInSeconds) .. "d "
			time = time % dayInSeconds
		end

		if time and time >= 0 then
			return days .. date("!%X", time)
		end
	end
end

function SetParentArray(frame, parentArray, value)
	assert(frame)

	if not frame:GetParent()[parentArray] then
		frame:GetParent()[parentArray] = {}
	end

	table.insert(frame:GetParent()[parentArray], value)
	return frame:GetParent()[parentArray]
end

function printc(...)
	if S_Print then
    	S_Print(strjoin(" ", tostringall(...)))
    end
end

function printec( ... )
	if S_PrintConsole then
		S_PrintConsole(strjoin(" ", tostringall(...)))
	end
end

function AnimationStopAndPlay( object, ... )
	local animationObject = {...}

	if animationObject then
		for _, stopObject in pairs(animationObject) do
			if stopObject then
				if stopObject:IsPlaying() then
					stopObject:Stop()
				end
			end
		end
	end

	if object then
		if object:IsPlaying() then
			object:Stop()
		end

		object:Play()
	end
end

function HookFunction(name, callback)
    if not _G[name] then
        error(("No such method '%s' in '_G' table"):format(name or "N/A"))
    end

    local method = _G[name]
    _G[name] = function(...)
        local args = {callback(...)}
        return method(unpack(args))
    end
end

function isOneOf(val, ...)
    for k,v in pairs({...}) do
        if val == v then
            return true
        end
    end
    return false
end

function IsDevClient()
	return S_IsDevClient and S_IsDevClient()
end

function IsNyllClient()
	return S_IsNyllClient and S_IsNyllClient()
end

function GetSafeCVar(cvar, dafault)
	local isSuccess, pCallValue = pcall(function() return GetCVar(cvar) end)

	if isSuccess and pCallValue then
		return pCallValue
	elseif dafault then
		return dafault
	end
end

function SetSafeCVar(cvar, value, raiseEvent)
    local isCVar = GetSafeCVar(cvar)

    if isCVar then
        SetCVar(cvar, value , raiseEvent)
    end
end

---@param value
---@return boolean
function isset( value )
	return value and true or false
end

function PackNumber(n1, n2)
	return bit.bor(n1, bit.lshift(n2, 16))
end

function UnpackNumber(n)
	local n1 = bit.band(n, 0xFFFF)
	local n2 = bit.band(bit.rshift(n, 16), 0xFFFF)

	return n1, n2
end

---@param varName string
---@return string localeKey
function GetLocalizedName(varName)
	return varName.."_"..GetLocale():upper()
end

-- TEEMP -_-
function inRealmScourge()
	-- local realmName = GetServerName()

	-- if realmName then
	-- 	return realmName == "Scourge x2 - 3.3.5a+"
	-- end

	return true
end

function SendPacket( opcode, ... )
    local val = {...}
    local size = 4

    -- printc("SendPacket", opcode, ..., time())

    SetRealmSplitState(2)
    SetRealmSplitState(2)
    for o = 1, string.len(opcode) do
        local subs = tostring(opcode):sub(o, o)
        SetRealmSplitState(tonumber(subs))
    end
    SetRealmSplitState(2)

    for v = 1, #val do
        local bits = toBits(val[v])
        for i = 0, size - #bits - 1 do
            SetRealmSplitState(0)
        end

        for s = 1, #bits do
            SetRealmSplitState(bits[s])
        end
    end
end
