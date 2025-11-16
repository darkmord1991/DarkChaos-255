-- MetaMapWKB
-- Written by MetaHawk - aka Urshurak

WKB_AUTHOR = "MetaMapWKB";

WKB_BUTTON_HEIGHT = 22;
WKB_BUTTON_SHOWN = 24;

WKB_Options = {};
WKB_Data = {};

WKB_Default = {
	["ShowUpdates"]   = false,
	["BoundingBox"]   = false,
	["AutoTrack"]     = false,
	["KBstate"]       = false,
	["NewTargetNote"] = false,
	["SetMapShow"]    = false,
	["Dsearch"]       = true,
	["RangeCheck"]    = 1,
}

WKB_overRide = false;
WKB_ShowAllZones = false;
WKB_ScrollFrameButtonID = 0;
WKB_VarsLoaded = false;
local WKB_SinglePrint = nil;
local WKB_LastSearch = "";
WKB_SearchResults = {};
local WKB_PlayerX = 0;
local WKB_PlayerY = 0;

function WKB_EventFrame_OnLoad()
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("WORLD_MAP_UPDATE");
	this:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	this:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
end

function WKB_OnEvent(self, event, ...)
	local arg1 = ...
	if(event == "ADDON_LOADED" and arg1 == "MetaMapWKB") then
		WKB_LoadZones();
		for option, value in pairs(WKB_Default) do
			if(WKB_Options[option] == nil) then WKB_Options[option] = value; end
		end
		WKB_ToggleSetRange(WKB_Options.RangeCheck);
	end
	if(event == "INSTANCE_MAP_UPDATE" and WorldMapFrame:IsVisible()) then
		if(WKB_DisplayFrame:IsVisible() and not WKB_ShowAllZones) then
			WKB_Search();
		end
	end
	if(event == "WORLD_MAP_UPDATE" and WorldMapFrame:IsVisible()) then
		if(WKB_DisplayFrame:IsVisible() and not WKB_ShowAllZones) then
			WKB_Search();
		end
	end
	if(event == "ZONE_CHANGED_NEW_AREA") then
		if(WKB_DisplayFrame:IsVisible() and not WKB_ShowAllZones) then
			WKB_Search();
		end
	end
	if((event == "UPDATE_MOUSEOVER_UNIT" or event == "PLAYER_TARGET_CHANGED") and WKB_Options.AutoTrack) then
		local target = "target"; if (event == "UPDATE_MOUSEOVER_UNIT") then target = "mouseover" end
		-- if(UnitIsPlayer(target)~=1 and UnitPlayerControlled(target)~=1 and UnitIsDead(target)~=1) then
			-- WKB_AddUnitInfo("mouseover");
		-- end
		if UnitExists(target) and (not UnitIsPlayer(target)) and (not UnitIsGhost(target)) and (not WKB_UnitIsPet(target)) and (not (UnitCreatureType(target) == "Critter")) 
		  and (not (UnitName(target) == "Viper")) and (not WKB_UnitIsTotem(target)) then  --not a snake trap Viper and not a Totem		
				WKB_AddUnitInfo(target) --add mob to MetaMap db
		end
	end
end

function WKB_UnitIsPet(target)
	if UnitPlayerControlled(target) then
		if UnitIsPlayer(target) then
			return false
		end
		return true
	end
end

function WKB_UnitIsTotem(target)
	local name, _ = UnitName(target)
	return (string.find(name, " Totem") and not string.find(name, "Totemic"))
end

function WKB_InitFrame()
	WKB_Header1:SetWidth(WKB_HeaderPanel:GetWidth()*0.26);
	WKB_Header2:SetWidth(WKB_HeaderPanel:GetWidth()*0.38);
	WKB_Header3:SetWidth(WKB_HeaderPanel:GetWidth()*0.16);
	WKB_Header4:SetWidth(WKB_HeaderPanel:GetWidth()*0.20);
	for i=1, WKB_BUTTON_SHOWN,1 do
		getglobal("WKB_ScrollFrameButton"..i):SetWidth(WKB_HeaderPanel:GetWidth());
		getglobal("WKB_ScrollFrameButton"..i.."Name"):SetWidth(WKB_Header1:GetWidth());
		getglobal("WKB_ScrollFrameButton"..i.."Info1"):SetWidth(WKB_Header2:GetWidth());
		getglobal("WKB_ScrollFrameButton"..i.."Info2"):SetWidth(WKB_Header3:GetWidth());
		getglobal("WKB_ScrollFrameButton"..i.."Coords"):SetWidth(WKB_Header4:GetWidth());
	end
end

function WKB_ToggleFrame(mode)
	if(WKB_DisplayFrame:IsVisible()) then
		MetaMapContainer_ShowFrame();
		if(mode == 1) then
			MetaMap_ToggleFrame(WorldMapFrame);
		end
	else
		if(not WorldMapFrame:IsVisible()) then
			MetaMap_ToggleFrame(WorldMapFrame);
		end
		MetaMapContainer_ShowFrame(WKB_DisplayFrame);
	end
end

function WKB_StripTextColors(textString)
	-- this function is designed to replace
	-- |cff00AA00Colored Text|r with Colored Text
	if(textString ~= nil and textString ~= "") then
		return string.gsub(textString, "|c[%dA-Fa-f][%dA-Fa-f][%dA-Fa-f][%dA-Fa-f][%dA-Fa-f]"..
				"[%dA-Fa-f][%dA-Fa-f][%dA-Fa-f](.*)|r", "%1");
	else
		assert(false, "nil or invalid parameter to StripTextColors");
	end
end

function WKB_ToggleSetRange(range)
	for i=1, 5 do
		local checkButton = getglobal("WKB_RangeCheck_"..i);
		if(i == range) then
			checkButton:SetChecked(true);
		else
			checkButton:SetChecked(false);
		end
	end
	WKB_Options.RangeCheck = range;
end

function WKB_UpdateKeySelectedUnit()
	if (not UnitExists("target")) then
		MetaMap_Print(WKB_NOTARGET, WKB_Options.ShowUpdates);
		return;
	else
		if(IsControlKeyDown()) then
			WKB_overRide = true;
		end
		WKB_AddUnitInfo("target");
			WKB_overRide = false;
	end
end

function WKB_AddUnitInfo(UnitSelect)
	if(MetaMap_TimerDelay) then return; end
	local unitName = UnitName(UnitSelect);
	if(string.find(strlower(unitName), WKB_UNKNOWN)) then return; end
	local mapName = GetRealZoneText();
	if(WKB_Options.RangeCheck ~= 5) then
		if(not CheckInteractDistance(UnitSelect, WKB_Options.RangeCheck)) then return; end
	end
	if(not WKB_Data[mapName]) then
		--MetaMap_Print(METAMAP_INVALIDZONE, WKB_Options.ShowUpdates);
		local zone = GetRealZoneText() or GetZoneText()  or GetMinimapZoneText() or GetSubZoneText()
		if not zone or zone == "" then
			return;
		end
		WKB_Data[zone] = {} --create a new zone
	end
	local icon = 3; --green by default
	local unitName = UnitName(UnitSelect);
	local ncol = 0;
	local desc1 = "";
	local desc2 = "";
	local playerX, playerY = GetPlayerMapPosition("player")

	playerX = MetaMap_round(playerX*10000)
	playerY = MetaMap_round(playerY*10000)
	unitName = WKB_StripTextColors(unitName);

	if(UnitReaction("player", UnitSelect) < 4) then
		if(UnitClassification(UnitSelect) ~= "normal") then
			desc1 = UnitClassification(UnitSelect).." ";
		end
		if(UnitCreatureType(UnitSelect) ~= nil) then
			desc1 = desc1..UnitCreatureType(UnitSelect).." "
		end
		if(UnitClass(UnitSelect) ~= nil) then
			desc1 = desc1..UnitClass(UnitSelect);
		end
		if(UnitLevel(UnitSelect) == "-1") then
			desc2 = WKB_MOB_LEVEL.." ??";
		else
			desc2 = WKB_MOB_LEVEL.." "..UnitLevel(UnitSelect);
		end
		icon = 1;
	elseif(UnitReaction("player", UnitSelect) == 4) then
		if(GameTooltipTextLeft2:GetText() ~= nil) then
			desc1 = string.sub(GameTooltipTextLeft2:GetText(), 9);
		end
		desc2 = WKB_MOB_LEVEL.." "..UnitLevel(UnitSelect);
		icon = 0;
	elseif(UnitReaction("player", UnitSelect) > 4 and UnitIsPlayer(UnitSelect)) then
		unitName = UnitPVPName(UnitSelect);
		desc1 = UnitRace(UnitSelect).." "..UnitClass(UnitSelect);
		desc2 = WKB_MOB_LEVEL.." "..UnitLevel(UnitSelect);
		icon = 7;
	elseif(UnitReaction("player", UnitSelect) < 4 and UnitIsPlayer(UnitSelect)) then
		unitName = UnitPVPName(UnitSelect);
		desc1 = UnitRace(UnitSelect).." "..UnitClass(UnitSelect);
		desc2 = WKB_MOB_LEVEL.." "..UnitLevel(UnitSelect);
		icon = 6;
	else
		local check = GameTooltipTextLeft2:GetText();
		if (check ~= nil) then
			if(string.find(check, WKB_MOB_LEVEL)) then
				if(GameTooltipTextLeft3 ~= "" and GameTooltipTextLeft3 ~= nil) then
					desc1 = GameTooltipTextLeft3:GetText();
					desc2 = GameTooltipTextLeft2:GetText();
				end
			else
				if(GameTooltipTextLeft2 ~= "" and GameTooltipTextLeft2 ~= nil) then
					desc1 = GameTooltipTextLeft2:GetText();
				end
				if(GameTooltipTextLeft3 ~= "" and GameTooltipTextLeft3 ~= nil) then
					desc2 = GameTooltipTextLeft3:GetText();
				end
			end
		end
		icon = 3;
	end
	if(desc1 == nil) then desc1 = ""; end
	if(desc2 == nil) then desc2 = ""; end

	local changedSomething = false;
	local addedSomething = false;
	local updatedSomething = false;
	local currentUnit = WKB_Data[mapName][unitName];
	
	if (not currentUnit) then
		WKB_Data[mapName][unitName] = {};
		currentUnit = WKB_Data[mapName][unitName];
		currentUnit["inf1"] = desc1;
		currentUnit["inf2"] = desc2;
		currentUnit["icon"] = icon;
		currentUnit[1] = 20000;
		currentUnit[2] = -1;
		currentUnit[3] = -1;
		currentUnit[4] = 20000;
		addedSomething = true
		MetaMap_Print(format(TEXT(WKB_DISCOVERED_UNIT), unitName), true);
		WKB_SinglePrint = true
	else
		currentUnit["icon"] = icon;
		if(currentUnit["inf1"] == "") then
			currentUnit["inf1"] = desc1;
			updatedSomething = true;
		end
		if(currentUnit["inf2"] == "") then
			currentUnit["inf2"] = desc2;
			updatedSomething = true;
		end
	end		

	if(playerX < currentUnit[4]) then
		currentUnit[4] = playerX;
		changedSomething = true;
	end
	if(playerY < currentUnit[1]) then
		currentUnit[1] = playerY;
		changedSomething = true;
	end
	if(playerX > currentUnit[2]) then
		currentUnit[2] = playerX;
		changedSomething = true;
	end
	if(playerY > currentUnit[3]) then
		currentUnit[3] = playerY;
		changedSomething = true;
	end

	if(WKB_Options.NewTargetNote or WKB_overRide) then
		WKB_AddMapNotes(unitName, mapName, 0);
	end
	if(WKB_Options.KBstate) then
		if(addedSomething) then
			if WKB_SinglePrint then
				WKB_SinglePrint = nil
			else
				MetaMap_Print(format(TEXT(WKB_ADDED_UNIT_IN_ZONE), unitName, mapName), WKB_Options.ShowUpdates);
			end
		end
		--if(changedSomething and not addedSomething) then
			--MetaMap_Print(format(TEXT(WKB_UPDATED_MINMAX_XY), unitName, mapName), WKB_Options.ShowUpdates);
		--end
		--if(updatedSomething) then
			--MetaMap_Print(format(TEXT(WKB_UPDATED_INFO), unitName, mapName), WKB_Options.ShowUpdates);
		--end
	else
		currentUnit = nil;
	end
end

function WKB_Search(searchText, suppressErrors)
	if(searchText == nil) then searchText = WKB_LastSearch; end
	if(suppressErrors == nil) then suppressErrors = false; end
	WKB_LastSearch = searchText;
	WKB_PlayerX, WKB_PlayerY = GetPlayerMapPosition("player");
	WKB_PlayerX = MetaMap_round(WKB_PlayerX * 100);
	WKB_PlayerY = MetaMap_round(WKB_PlayerY * 100);
	FauxScrollFrame_SetOffset(WKB_ScrollFrame, 0);
	WKB_BuildSearchResults();
	WKB_UpdateScrollFrame();
	WKB_SearchBox:SetText(WKB_LastSearch);
end

function WKB_BuildSearchResults()
	WKB_SearchResults = {};
	local nameCount = 0;
	local zoneCount = 0;
	local tempZones = {};
	local mapName = MetaMap_GetCurrentMapInfo();
	for zoneName, nameTable in pairs(WKB_Data) do
		local showThis = MetaMap_CheckRelatedZone(zoneName, mapName);
		for unit, value in pairs(nameTable) do
			local cCode = 1;
			local coordString = ""; local coordString2
			if(showThis or WKB_ShowAllZones) then
				local dataZone = WKB_Data[zoneName][unit];
				local inf1 = dataZone["inf1"];
				local inf2 = dataZone["inf2"];
				local ncol = dataZone["icon"];
				if(ncol == 1) then ncol = 2;
				elseif(ncol == 2) then ncol = 6;
				elseif(ncol == 3) then ncol = 4;
				elseif(ncol == 6) then ncol = 1; end
				if(zoneName == mapName) then
					coordString, cCode = WKB_FormatCoords(dataZone);
					coordString2 = coordString
				else
					coordString = zoneName;
					coordString2, _ = WKB_FormatCoords(dataZone);
				end
				if(string.find(string.lower(unit),string.lower(WKB_LastSearch),1,true)~=nil
					or string.find(string.lower(inf1),string.lower(WKB_LastSearch),1,true)~=nil
					or string.find(string.lower(inf2),string.lower(WKB_LastSearch),1,true)~=nil
					or string.find(string.lower(coordString),string.lower(WKB_LastSearch),1,true)~=nil) then
					tinsert(WKB_SearchResults, {name = unit, zoneName = zoneName, desc = inf1, level = inf2, ncol = ncol, location = coordString, cCode = cCode, location2 =  coordString2});
					nameCount = nameCount + 1;
					if(tempZones[zoneName] == nil and zoneName ~= nil) then
						zoneCount = zoneCount + 1;
						tempZones[zoneName] = 1;
					end
				end
			end
		end
	end
	WKB_HeaderText:SetText(mapName);
	WKB_InfoText1:SetText("Found "..nameCount.." NPC/MoBs in "..zoneCount.." zones");
	WKB_SearchResults.onePastEnd = nameCount +1;
	MetaKBList_SortBy(MetaMap_sortType, MetaMap_sortDone)
end

function WKB_UpdateScrollFrame()
	for iScrollFrameButton = 1, WKB_BUTTON_SHOWN, 1 do
		local buttonIndex = iScrollFrameButton + FauxScrollFrame_GetOffset(WKB_ScrollFrame);
		local scrollFrameButton = getglobal("WKB_ScrollFrameButton"..iScrollFrameButton);
		local NameButton = getglobal("WKB_ScrollFrameButton"..iScrollFrameButton.."Name");
		local Info1Button = getglobal("WKB_ScrollFrameButton"..iScrollFrameButton.."Info1");
		local Info2Button = getglobal("WKB_ScrollFrameButton"..iScrollFrameButton.."Info2");
		local CoordsButton = getglobal("WKB_ScrollFrameButton"..iScrollFrameButton.."Coords");

		if(buttonIndex < WKB_SearchResults.onePastEnd) then
			local currentZone = GetRealZoneText() or GetZoneText() or GetMinimapZoneText() or GetSubZoneText() or ""
			if(WKB_SearchResults[buttonIndex]["zoneName"] == GetRealZoneText()) then
				-- Unit is in the same zone, show in yellow
				NameButton:SetText(WKB_SearchResults[buttonIndex]["name"]);
				Info1Button:SetText(WKB_SearchResults[buttonIndex]["desc"]);
				Info2Button:SetText(WKB_SearchResults[buttonIndex]["level"]);
				CoordsButton:SetText(WKB_SearchResults[buttonIndex]["location"]);
				if(WKB_SearchResults[buttonIndex]["cCode"] == 2) then
					CoordsButton:SetTextColor(0,1,0)
				else
					-- Unit is within range, show in green
					CoordsButton:SetTextColor(1,1,0)
				end
				scrollFrameButton:Show();
			else
				-- Unit is in a different zone, show in red
				NameButton:SetText(WKB_SearchResults[buttonIndex]["name"]);
				Info1Button:SetText(WKB_SearchResults[buttonIndex]["desc"]);
				Info2Button:SetText(WKB_SearchResults[buttonIndex]["level"]);
				CoordsButton:SetText(WKB_SearchResults[buttonIndex]["zoneName"]);
				CoordsButton:SetTextColor(1,0,0)
				scrollFrameButton:Show();
			end
			local ncol = WKB_SearchResults[buttonIndex]["ncol"];
			NameButton:SetTextColor(MetaMap_Colors[ncol].r,MetaMap_Colors[ncol].g,MetaMap_Colors[ncol].b)
			Info1Button:SetTextColor(0.8,0.8,0.8)
			Info2Button:SetTextColor(0.5,0.5,0.8)
		else
			scrollFrameButton:Hide();
		end
	end
	FauxScrollFrame_Update(WKB_ScrollFrame, WKB_SearchResults.onePastEnd - 1, WKB_BUTTON_SHOWN, WKB_BUTTON_HEIGHT)
end

function WKB_FormatCoords(dataSet, mode)
	local cleanCoords = {};
	local coordString = "";
	for i=1,4 do
		cleanCoords[i] = MetaMap_round(dataSet[i]/100, 0);
	end
	local dx = dataSet[2]/100 - dataSet[4]/100;
	local dy = dataSet[3]/100 - dataSet[1]/100;
	local centerx = dataSet[4]/100 + dx/2;
	local centery = dataSet[1]/100 + dy/2;
	-- truncate to two digits after the decimal again
	centerx = MetaMap_round(centerx, 0);
	centery = MetaMap_round(centery, 0);
	if(mode == nil) then
		if dx >= 3 or dy >= 3 then
		-- if the NPC has a range of 3 map units or greater, show ranges
			coordString = " ("..cleanCoords[4].."-"..cleanCoords[2].."),"..
 	                          " ("..cleanCoords[1].."-"..cleanCoords[3]..")"
		else
			-- otherwise just show an averaged point
			coordString = " ("..centerx..", "..centery..")"
		end
		if(centerx > (WKB_PlayerX +3) or centerx < (WKB_PlayerX -3) and centery > (WKB_PlayerY +3) or centery < (WKB_PlayerY -3)) then
			cCode = 1;
		else
			cCode = 2;
		end
		return coordString, cCode;
	elseif(mode == 1) then
		if(centerx == 0 and centery == 0) then
			centerx = 75;
			centery = 95;
		end
		centerx = centerx/100;
		centery = centery/100;
		return centerx, centery, dx, dy;
	end
	return centerx, centery;
end

function MetaKBList_SortBy(aSortType, aSortDone)
	MetaMap_sortType = aSortType;
	MetaMap_sortDone = aSortDone;
    table.sort(WKB_SearchResults, MetaMap_SortCriteria);
	if(not MetaMap_sortDone)then
		local count = WKB_SearchResults.onePastEnd;
		WKB_SearchResults = MetaMap_InvertList(WKB_SearchResults);
		WKB_SearchResults.onePastEnd = count;
	end
	WKB_UpdateScrollFrame();
end

function WKB_ScrollFrameButtonOnClick(self, button)
	if (button == "LeftButton") then
		WKB_ScrollFrameButtonID = this:GetID();
		local x, y = GetCursorPosition();
		x = x / UIParent:GetEffectiveScale();
		y = y / UIParent:GetEffectiveScale();
		MetaKBMenu:SetPoint("TOP", "UIParent", "BOTTOMLEFT", x , y + 10);
		MetaKBMenu:Show(self);
	elseif (button == "RightButton") then
		if(IsControlKeyDown()) then
			MetaKBMenu_CRBSelect(this:GetID(), self);
		elseif(IsShiftKeyDown()) then
			MetaKBMenu_SRBSelect(this:GetID(), self);
		else
			MetaMap_LoadBWP(this:GetID(), 1);
		end
	end
end

function MetaKBMenu_Select(id)
	local tUpdate = WKB_Options.ShowUpdates;
	local unit = getglobal("WKB_ScrollFrameButton"..WKB_ScrollFrameButtonID.."Name"):GetText();
	local zoneName = getglobal("WKB_ScrollFrameButton"..WKB_ScrollFrameButtonID.."Coords"):GetText();
	if(string.find(zoneName, "%(%d+\.?-?%d*%)?, %(?%d+\.?-?%d*%)")) then
		zoneName = GetRealZoneText();
	end
	if(id == 1) then
		WKB_Options.ShowUpdates = true;
		PlaySound("MapPing");
		WKB_AddMapNotes(unit, zoneName, 0);
		PlaySound("igMiniMapClose");
	elseif(id == 2) then
		WKB_Options.ShowUpdates = true;
		PlaySound("MapPing");
		WKB_AddMapNotes(unit, zoneName, 2);
		PlaySound("igMainMenuOption")
	elseif(id == 3) then
		WKB_Options.ShowUpdates = true;
		MetaMap_DeleteNotes(WKB_AUTHOR, unit);
	elseif(id == 4) then
		WKB_Options.ShowUpdates = true;
		PlaySound("igQuestLogAbandonQuest");
		MetaMap_DeleteNotes(WKB_AUTHOR);
	elseif(id == 5) then
		WKB_Data[zoneName][unit] = nil;
		PlaySound("Deathbind Sound");
		MetaMap_Print(format(TEXT(WKB_REMOVED_FROM_DATABASE), unit, zoneName), true);
		WKB_Search(WKB_LastSearch, true);
	elseif(id == 6) then
			StaticPopupDialogs["Trim_Dbase"] = {
				text = TEXT(WKB_TRIM_DBASE),
				button1 = TEXT(ACCEPT),
				button2 = TEXT(DECLINE),
				OnAccept = function()
					WKB_TrimDatabase();
				end,
				timeout = 60,
				showAlert = 1,
			};
			StaticPopup_Show("Trim_Dbase");
	elseif(id == 7) then
		if(not ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Show(); end
		local dataZone = WKB_Data[zoneName][unit];
		local centerx, centery = WKB_FormatCoords(dataZone, 2)
		local mInfo = " "; if(dataZone.inf1 ~= "") then mInfo = " ["..dataZone.inf1.."] "; end
		ChatFrameEditBox:Insert(unit..mInfo.."("..zoneName.." - "..centerx..", "..centery..")");
	elseif(id == 8) then
		local noteID;
		if(WKB_Options.SetMapShow) then
			_, noteID = WKB_AddMapNotes(unit, zoneName, 0);
		end
		MetaMap_ShowLocation(zoneName, unit, noteID);
	elseif(id == 9) then
		MetaMap_LoadBWP(0, 3);
		if(IsAddOnLoaded("MetaMapBWP")) then
			--MyPrint("QuestHelper Icon Set as the MetaMap Waypoint.")
			local dataZone = WKB_Data[zoneName][unit];
			local centerx, centery = WKB_FormatCoords(dataZone, 2)
			BWP_LocCommand(format("%d, %d", centerx, centery)..unit); --set BWP waypoint
		end
	end
	WKB_Options.ShowUpdates = tUpdate;
end

function MetaKBMenu_OnUpdate()
	if (MetaKBMenu:IsVisible()) then
		if (not MouseIsOver(MetaKBMenu)) then
			MetaKBMenu:Hide();
		end
	end
end

function WKB_TrimDatabase()
	local nameCount = 0;
	for i=1, #(WKB_SearchResults) do
		local zoneName = WKB_SearchResults[i].zoneName;
		local Name = WKB_SearchResults[i].name;
		WKB_Data[zoneName][Name] = nil;
		nameCount = nameCount + 1
	end
	if(strlen(WKB_LastSearch) > 0) then
		MetaMap_Print("Removed "..nameCount.." entries from database linked to '"..WKB_LastSearch.."'", true);
	else
		MetaMap_Print("Removed ALL entries from database", true);
	end
	WKB_Search(WKB_LastSearch, true);
end

function WKB_AddMapNotes(unit, zoneName, mininote)
	if(mininote == nil) then mininote = 0; end
	local dataZone = WKB_Data[zoneName][unit];
	local coordSets = {
	[1] = { ["n"] = TEXT(WKB_MAPNOTES_NW_BOUND), ["x"] = 4, ["y"] = 1, },
	[2] = { ["n"] = TEXT(WKB_MAPNOTES_NE_BOUND), ["x"] = 2, ["y"] = 1, },
	[3] = { ["n"] = TEXT(WKB_MAPNOTES_SE_BOUND), ["x"] = 2, ["y"] = 3, },
	[4] = { ["n"] = TEXT(WKB_MAPNOTES_SW_BOUND), ["x"] = 4, ["y"] = 3, }, };
	local infoOne = dataZone["inf1"];
	local infoTwo = dataZone["inf2"];
	local icon = dataZone["icon"];
	local namecol = icon;
	if(icon == 1) then namecol = 2;
	elseif(icon == 2) then namecol = 6;
	elseif(icon == 3) then namecol = 4;
	elseif(icon == 6) then namecol = 1; end
	local centerx, centery, dx, dy = WKB_FormatCoords(dataZone, 1)
	local noteAdded, noteID = MetaMap_SetNewNote(zoneName, centerx, centery, unit, infoOne, infoTwo, WKB_AUTHOR, icon, namecol, 9, 6, mininote);
	if(noteAdded) then
		if(mininote ~= 2) then
			MetaMap_Print(format(METAMAP_ACCEPT_NOTE, zoneName), WKB_Options.ShowUpdates);
		end
	else
		MetaMap_Print(format(METAMAP_DECLINE_NOTE, MetaMap_Notes[zoneName][noteID].name, zoneName), WKB_Options.ShowUpdates);
	end
	if(mininote > 0) then
		MetaMap_Print(format(METAMAP_ACCEPT_MININOTE, zoneName), true);
	end
	if(noteAdded and mininote == 0 and (dx >= 3 or dy >= 3) and WKB_Options.BoundingBox) then
		local x2 = dataZone[coordSets[4].x]/10000
		local y2 = dataZone[coordSets[4].y]/10000
		local skipNext = false
		for i in ipairs(coordSets) do
			local x1 = dataZone[coordSets[i].x]/10000
			local y1 = dataZone[coordSets[i].y]/10000
			local noteSet = MetaMap_SetNewNote(zoneName, x1, y1, unit, infoOne, infoTwo, WKB_AUTHOR, 10, namecol, 9, 6);
			if(noteSet) then
				if(not skipNext) then
					MetaMap_ToggleLine(zoneName, x2, y2, x1, y1);
					MetaMap_ToggleLine(zoneName, centerx, centery, x1, y1);
				end
				skipNext = false;
			else
				skipNext = true;
			end
			x2,y2 = x1,y1;
		end
	end
	return noteAdded, noteID;
end

function WKB_HintTooltip()
	WorldMapTooltip:SetOwner(this, "ANCHOR_TOPLEFT");
	WorldMapTooltip:SetText(WKB_TTHINT_H0, 0.2, 0.5, 1, 1);
	WorldMapTooltip:AddDoubleLine("LeftClick", WKB_TTHINT_T0, 1, 1, 1, 1);
	WorldMapTooltip:AddDoubleLine("RightClick", WKB_TTHINT_T1, 1, 1, 1, 1);
	WorldMapPOIFrame.allowBlobTooltip = false;
	WorldMapTooltip:Show();
end

function WKB_ToggleAllZones()
	WKB_ShowAllZones = not WKB_ShowAllZones;
	if WKB_ShowAllZones then
		this:SetText(WKB_SHOW_LOCALZONE);
		PlaySound("igMainMenuOptionCheckBoxOn");
	else
		this:SetText(WKB_SHOW_ALLZONES);
		PlaySound("igMainMenuOptionCheckBoxOff");
	end
	WKB_Search();
end

function WKB_LoadZones()
	if(WKB_Data == nil) then WKB_Data = {}; end
	for Key in pairs(MetaMap_Notes) do
		if(WKB_Data[Key] == nil) then
			WKB_Data[Key] = {};
		end
	end
end

function WKB_ToggleOptions(key, value)
	if(value) then
		WKB_Options[key] = value;
	else
		WKB_Options[key] = not WKB_Options[key];
	end
	return WKB_Options[key];
end
