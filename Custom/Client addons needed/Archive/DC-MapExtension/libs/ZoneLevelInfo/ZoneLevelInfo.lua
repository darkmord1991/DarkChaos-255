-- Initialise

local savedZoneName = "";
local savedMapText = "";

local savedScale = 1;
local indentX = 60;
local indentY = -40;

local ZLI_fontRatio = 0.75;

ZoneLevelInfoSettings = {};
local ZoneLevelInfoDefaults = {["fontLarge"] = 20};

local ZoneLevelInfo_Frame = CreateFrame("frame");
ZoneLevelInfo_Frame:RegisterEvent("ADDON_LOADED");



-------------------------------
-- OnUpdate
function ZoneLevelInfo_OnUpdate(self, elapsed)

		local x, y = GetCursorPosition();
		local scale = WorldMapDetailFrame:GetEffectiveScale();
		x = x / scale;
		y = y / scale;
		local width = WorldMapDetailFrame:GetWidth();
		local height = WorldMapDetailFrame:GetHeight();
		local centerX, centerY = WorldMapDetailFrame:GetCenter();
		local topleftX = centerX - (width/2);
		local topleftY = centerY + (height/2);
		x = (x - topleftX) / width;
		y = (topleftY - y) / height;
		if ( x > 1 ) then x = 1 elseif ( x < 0 ) then x = 0 end
		if ( y > 1 ) then y = 1 elseif ( y < 0 ) then y = 0 end

		local zoneName, fileName, texCoordX, texCoordY, textureX, textureY, scrollChildX, scrollChildY = UpdateMapHighlight(x, y);

		if ( zoneName and not zones[zoneName] ) then
			zoneName = nil;
		end

		if (zoneName == nil) then
			local currentZoneIndex = GetCurrentMapZone();
			if ( currentZoneIndex > 0 ) then
				local currentContinentIndex = GetCurrentMapContinent();
				if ( currentContinentIndex > 0 ) then
					zoneName = zoneNumberTable[currentContinentIndex][currentZoneIndex];
				end
			end
		end

		local mapText = WorldMapFrameAreaLabel:GetText();

		if (scale ~= savedScale) then
			savedScale = scale;
			ZoneLevelInfoFrame_Text1:SetPoint("TOPLEFT","WorldMapDetailFrame","TOPLEFT",floor(indentX*savedScale), floor(indentY*savedScale));
		end

		if (zoneName == savedZoneName and mapText == savedMapText) then
			return
		else
			savedZoneName = zoneName;
			savedMapText  = mapText;

			if (savedZoneName == nil) then
				ZoneLevelInfoFrame_Text1:SetTextColor(1, 1, 0.2);
				ZoneLevelInfoFrame_Text1:SetText(savedMapText);
				ZoneLevelInfoFrame_Text2:SetText("");
				ZoneLevelInfoFrame_Text3:SetText("");
			else
				local zoneInfo = zones[savedZoneName];
				local controlInfo = "";
				ZoneLevelInfoFrame_Text1:SetTextColor(1, 1, 0.2);
				ZoneLevelInfoFrame_Text2:SetTextColor(1, 1, 0.2);
				if (zoneInfo[3] == "H") then
					controlInfo = " ("..L["Horde"]..")";
					ZoneLevelInfoFrame_Text1:SetTextColor(1, 0, 0);
					ZoneLevelInfoFrame_Text3:SetTextColor(1, 0, 0);
				elseif (zoneInfo[3] == "A") then
					controlInfo = " ("..L["Alliance"]..")";
					ZoneLevelInfoFrame_Text1:SetTextColor(0, 0, 1);
					ZoneLevelInfoFrame_Text3:SetTextColor(0, 0, 1);
				end
					
				ZoneLevelInfoFrame_Text1:SetText(savedZoneName..controlInfo);

				if (savedMapText ~= nil and savedMapText ~= "BLAH!" and (not zones[savedMapText] or (zones[savedMapText][3]~="C" and zoneInfo[3]=="C" and savedMapText~=savedZoneName))) then
					ZoneLevelInfoFrame_Text2:SetText(savedMapText);
				elseif (zoneInfo[3]~="C") then
					ZoneLevelInfoFrame_Text2:SetText(savedZoneName);
				else
					ZoneLevelInfoFrame_Text2:SetText("");
				end

				local setColour = ZoneLevelInfo_LevelColour(zoneInfo[2], zoneInfo[1]);
				local levelRange = "";
				if (zoneInfo[1] == 0 and zoneInfo[2] > 0) then
					levelRange = L["Capital City"];
					if (zoneInfo[3] == "S") then
						levelRange = levelRange.." - "..L["Sanctuary"];
					end
				elseif (zoneInfo[1] > 0) then
					levelRange = "["..zoneInfo[1].."-"..zoneInfo[2].."]";
				elseif (zoneInfo[1] < 0) then
					levelRange = "["..L["unknown zone"].."]";
				end
				ZoneLevelInfoFrame_Text3:SetTextColor(setColour["R"],setColour["G"],setColour["B"]);
				ZoneLevelInfoFrame_Text3:SetText(levelRange);
			end
		end
end

function ZoneLevelInfo_LevelColour(maxLevelZone, minLevelZone) 

		local playerLevel = UnitLevel("player");
		local levelNull = maxLevelZone + 3;
		local levelVeryHard = minLevelZone - 1;
		if (playerLevel < 60) then
			levelVeryHard = minLevelZone - 2;
		end
		local levelHard = minLevelZone;
		local levelLow = maxLevelZone;
		local colour = {["R"]=1, ["G"]=1, ["B"]=1};

		if ( minLevelZone <= 0 ) then	-- capital city / unknown area
			colour = {["R"]=0.5, ["G"]=0.5, ["B"]=0.5};
		elseif ( playerLevel < levelVeryHard ) then	-- solid red, hard going
			colour = {["R"]=1, ["G"]=0, ["B"]=0};
		elseif ( playerLevel > levelNull ) then	-- grey, little/no xp
			colour = {["R"]=0.5, ["G"]=0.5, ["B"]=0.5};
		elseif ( playerLevel >= levelLow and playerLevel <= levelNull ) then -- green, on the easy side
			colour = {["R"]=0, ["G"]=1, ["B"]=0.2};
		elseif ( playerLevel > levelHard and playerLevel < levelLow ) then -- yellow, the 'sweetspot'
			colour = {["R"]=1, ["G"]=1, ["B"]=0.2};
		elseif ( playerLevel >= levelVeryHard and playerLevel <= levelHard ) then
			colour = {["R"]=1, ["G"]=0.6, ["B"]=0.2};
		end

		return colour;
end


function ZoneLevelInfo_SetFonts(fontLarge,fontRatio)

		local minSize = ceil(fontRatio*12);
		local maxSize = 24;

		if (fontLarge>maxSize) then fontLarge=maxSize elseif (fontLarge<minSize) then fontLarge=minSize end;
		local fontSmall = floor(fontLarge * fontRatio);

		local theFont,theSize = GameFontHighlight:GetFont();
		
		ZoneLevelInfoFrame_Text1:SetFont(theFont,fontLarge);
		ZoneLevelInfoFrame_Text2:SetFont(theFont,fontSmall);
		ZoneLevelInfoFrame_Text3:SetFont(theFont,fontSmall);
		ZoneLevelInfoFrame_Text2:SetPoint("BOTTOMLEFT", "ZoneLevelInfoFrame_Text1", "BOTTOMLEFT", 0, (fontLarge * -1));
		ZoneLevelInfoFrame_Text3:SetPoint("BOTTOMLEFT", "ZoneLevelInfoFrame_Text2", "BOTTOMLEFT", 0, (fontLarge * -1));
end



--============================
--= Register the Slash Command
--============================
SlashCmdList["ZLI"] = function(_msg)
	if (_msg) then
		local _, _, cmd, arg1 = string.find(string.upper(_msg), "([%w]+)%s*(.*)$");
		if ("DEFAULT" == cmd) then		-- reset the list
			ZoneLevelInfoSettings = ZoneLevelInfoDefaults;
			ZoneLevelInfo_SetFonts(ZoneLevelInfoSettings.fontLarge,ZLI_fontRatio);
			local confirmMsg = "ZoneLevelInfo: defaults reset";
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00".. confirmMsg);

		elseif ("SIZE" == cmd) then		-- set the text size
			local confirmMsg = "ZoneLevelInfo size ";
			local setSize = arg1:match("^%s*(%d+)%s*$");
			if (setSize ~= nil and tonumber(setSize)>=16 and tonumber(setSize)<=24) then
				ZoneLevelInfoSettings.fontLarge = floor(tonumber(setSize));
				ZoneLevelInfo_SetFonts(ZoneLevelInfoSettings.fontLarge,ZLI_fontRatio);
				confirmMsg = confirmMsg .. "set to " ..ZoneLevelInfoSettings.fontLarge;
			else
				confirmMsg = confirmMsg .. "currently " ..ZoneLevelInfoSettings.fontLarge..". Settable range: 16-24.";
				if (arg1 ~= "") then
					confirmMsg = confirmMsg .. " (Option unknown: '"..arg1.."')";
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00" .. confirmMsg);

		else -- either a gap command or an incorrect option
			local badCmd = "";
			if (_msg ~= "" and _msg ~= "?" and _msg ~= "HELP") then badCmd = " Unknown command: '" .. _msg .. "'"; end;

			local helpMsg = "/ZoneLevelInfo or /ZLI " .. badCmd .. "\n" ..
				"default: sets zone text size to default of 20.\n" ..
				"size: shows current zone text size.\n" ..
				"size n: sets zone text size to 'n', where 'n' is 16-24.";
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00" .. helpMsg);
		end
	end
end

SLASH_ZLI1 = "/zonelevelinfo";
SLASH_ZLI2 = "/zli";	



--============================
--= Loaded
--============================

local function ZoneLevelInfo_OnEvent(self, event, arg1, ...)
	if ( event == "ADDON_LOADED" and arg1:lower() == "zonelevelinfo" ) then

		WorldMapFrameAreaLabel:Hide();

		for ZLI_default_key,ZLI_default_value in next,ZoneLevelInfoDefaults do
			if (ZoneLevelInfoSettings[ZLI_default_key] == nil) then
				ZoneLevelInfoSettings[ZLI_default_key] = ZLI_default_value;
			end
		end

		ZoneLevelInfo_SetFonts(ZoneLevelInfoSettings.fontLarge,ZLI_fontRatio);
		ZoneLevelInfoFrame_Text1:SetPoint("TOPLEFT","WorldMapDetailFrame","TOPLEFT",floor(indentX*savedScale),floor(indentY*savedScale));

		local okMessage = "OK";
		if (missingZones) then
			okMessage = "with errors, see above..";
		end
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00ZoneLevelInfo 1.1 loaded for ["..currentLocale.."] "..okMessage..".");
	end
end
ZoneLevelInfo_Frame:SetScript("OnEvent", ZoneLevelInfo_OnEvent);