-- MetaMapTRK
-- Written by MetaHawk - aka Urshurak

TRK_NAME = "MetaMapTRK";
TRK_ICON_PATH = "Interface\\AddOns\\MetaMapTRK\\Nodes\\";
TRK_HRB_NAME = "Herb";
TRK_ORE_NAME = "Ore";
TRK_TRS_NAME = "Treasure";
TRK_MSC_NAME = "Misc";
TRK_MSC_HOLDER = "PlaceHolder";

TRK_Options = {};
TRK_Data    = {};
TRK_NodeList = {};
TRK_ZoneList = {};
TRK_Excludes = {};
TRK_MenuList = {};

TRK_Default = {
	["Herbs"]    = false,
	["Ores"]     = false,
	["Treasure"] = false,
	["Unmined"]  = false,
	["ShowAll"]  = false,
	["ShowHerb"] = true,
	["ShowOre"]  = true,
	["ShowTreasure"] = true,
	["ShowMisc"] = true,
	["FilterHerb"] = true,
	["FilterOre"]  = true,
	["FilterTreasure"] = true,
	["FilterMisc"] = true,
	["Sortby"]   = "name",
	["Padding"]  = 10,
}

TRK_FilterMenu = {
	[1] = {TRK_SORT_TITLE,  "Sortbyname"},
	[2] = {TRK_SORT_LEVEL,  "Sortbylevel"},
	[3] = {"", "", 1},
	[4] = {TRK_FILTER_ALL,  "ShowAll"},
	[5] = {TRK_FILTER_HERB, "ShowHerb"},
	[6] = {TRK_FILTER_ORE,  "ShowOre"},
	[7] = {TRK_FILTER_TREASURE, "ShowTreasure"},
	[8] = {TRK_FILTER_MISC, "ShowMisc"},
}

TRK_VarsLoaded  = false;
TRK_LastSearch	= "";
TRK_LastNode    = 0;
TRK_ButtonTotal	= 0;
TRK_HerbTotal = 0;
TRK_OreTotal = 0;
TRK_TreasureTotal = 0;
TRK_MiscTotal = 0;
TRK_ItemTotal = 0;
TRK_NodeCount = false;
TRK_HerbRank = 0;
TRK_OreRank = 0;
TRK_NodeOnMenu = false;
TRK_ZoneExpand = "";

function TRK_OnLoad()
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("WORLD_MAP_UPDATE");
	this:RegisterEvent("UNIT_SPELLCAST_SENT");
	this:RegisterEvent("UI_ERROR_MESSAGE");
end

function TRK_OnEvent(self, event, ...)
	local arg1, arg2 = ...
	if(event == "ADDON_LOADED" and arg1 == "MetaMapTRK") then
		TRK_LoadConfig();
		if(WorldMapFrame:IsVisible()) then MetaMap_MainMapUpdate(); end
		UIDropDownMenu_Initialize(TRK_FilterSelectMenu, TRK_FilterMenuInit, "MENU");
		UIDropDownMenu_Initialize(TRK_QuickMenu, TRK_QuickMenuInit, "MENU");
		UIDropDownMenu_Initialize(TRK_ExclusionMenuMenu, TRK_ExclusionMenuInit, "MENU");
	elseif(event == "WORLD_MAP_UPDATE" and TRK_DisplayFrame:IsVisible()) then
		TRK_DisplayInit();
	elseif(event == "INSTANCE_MAP_UPDATE" and TRK_DisplayFrame:IsVisible()) then
		TRK_DisplayInit();
	elseif(event == "UNIT_SPELLCAST_SENT" and arg1 == "player") then
		TRK_ProcessNode(arg2, 1);
	elseif(event == "UI_ERROR_MESSAGE") then
		TRK_ProcessNode(arg1, 2);
	end
end

function TRK_LoadConfig()
	for option, value in pairs(TRK_Default) do
		if(TRK_Options[option] == nil) then TRK_Options[option] = value; end
	end
	TRK_Default = nil;
	if(TRK_Data == nil) then TRK_Data = {}; end
	if(TRK_Errata == nil) then TRK_Errata = {}; end
	TRK_UpDateDB();
	TRK_HerbRank = TRK_GetSkillRank(TRK_HERBALISM);
	TRK_OreRank = TRK_GetSkillRank(TRK_MINING);
	TRK_VarsLoaded = true;
end

function TRK_GetTTname()
end

function TRK_ToggleFrame(mode)
	if(mode == 2) then return; end
	if(TRK_DisplayFrame:IsVisible()) then
		MetaMapContainer_ShowFrame();
		if(mode == 1) then
			MetaMap_ToggleFrame(WorldMapFrame);
		end
	else
		if(not WorldMapFrame:IsVisible()) then
			MetaMap_ToggleFrame(WorldMapFrame);
		end
		MetaMapContainer_ShowFrame(TRK_DisplayFrame);
		TRK_DisplayInit();
	end
end

function TRK_ProcessNode(msg, mode)
	local x, y = GetPlayerMapPosition("player");
	local zone = GetRealZoneText();
	local name = METAMAP_TT_NAME;
	if(mode == 1) then
		if(string.match(msg, TRK_DETECT_HERB) and TRK_Options.Herbs) then
			if(name and strlen(name) > 0) then
				TRK_NodeCount = true;
				TRK_AddNode(zone, name, UnitName("player"), x, y);
			end
		elseif(string.match(msg, TRK_DETECT_ORE) and TRK_Options.Ores) then
			if(name and strlen(name) > 0) then
				TRK_NodeCount = true;
				TRK_AddNode(zone, name, UnitName("player"), x, y);
			end
		elseif(string.match(msg, TRK_DETECT_TREASURE) and TRK_Options.Treasure) then
			if(name and strlen(name) > 0) then
				TRK_NodeCount = true;
				TRK_AddNode(zone, name, UnitName("player"), x, y);
			end
		end
	elseif(TRK_Options.Unmined) then
		if(name and strlen(name) > 0) then
			if(string.find(msg, TRK_HERBALISM) and TRK_Options.Herbs) then
				TRK_AddNode(zone, name, UnitName("player"), x, y, 0, true);
			elseif(string.find(msg, TRK_MINING) and TRK_Options.Ores) then
				TRK_AddNode(zone, name, UnitName("player"), x, y, 0, true);
			end
		end
	end
	METAMAP_TT_NAME = nil;
end

function TRK_AddNode(zone, name, creator, x, y, count, skipCount)
	if(TRK_Excludes[name] or not MetaMap_GetZoneTableEntry(zone)) then return; end
	if(count == nil) then count = 1; end
	if(TRK_Data[zone]) then
		for index, value in ipairs(TRK_Data[zone]) do
			if(abs(value.xPos-x) <= 0.01 and abs(value.yPos-y) <= 0.01) then
				if(not skipCount and TRK_NodeCount and name == TRK_TrackerTable[value.ref][MetaMap_Locale]) then
					value.count = value.count +1;
				end
				TRK_NodeCount = false; return;
			end
		end
	end
	TRK_NodeCount = false;
	local _, entry = TRK_GetTrackerEntry(name);
	if(not entry) then
		tinsert(TRK_TrackerTable, {cat = TRK_MSC_NAME, en = name, de = name, fr = name, level = 0, icon = "Misc_Generic"});
		_, entry = TRK_GetTrackerEntry(name);
		TRK_Errata[name] = {};
		TRK_Errata[name].ref = entry;
	end
	if(not TRK_Data[zone]) then
		TRK_Data[zone] = {};
	end
	tinsert(TRK_Data[zone], {ref = entry, creator = creator, xPos = x, yPos = y, count = count});
	MetaMap_Print(name.." "..TRK_NODE_ADDED, true)
	return true;
end

function TRK_DisplayNodes(mapName)
	for i=1, TRK_LastNode, 1 do
		getglobal("TRK_Node"..i):Hide();
	end
	if(not TRK_Data[mapName]) then return; end
	local buttonID = 1;
	for index, value in ipairs(TRK_Data[mapName]) do
		if(value.xPos == 0) then return; end
		local showThis = false;
		local cat = TRK_TrackerTable[value.ref].cat;
		if(cat == TRK_HRB_NAME and TRK_Options.FilterHerb) then showThis = true; end
		if(cat == TRK_ORE_NAME and TRK_Options.FilterOre) then showThis = true; end
		if(cat == TRK_TRS_NAME and TRK_Options.FilterTreasure) then showThis = true; end
		if(cat == TRK_MSC_NAME and TRK_Options.FilterMisc) then showThis = true; end
		if(showThis) then
			local temp = TRK_CreateNodeObject(buttonID);
			local x = value.xPos * WorldMapButton:GetWidth();
			local y = -value.yPos * WorldMapButton:GetHeight();
			temp:SetParent("WorldMapButton");
			temp:SetPoint("CENTER", "WorldMapButton", "TOPLEFT", x, y);
			getglobal("TRK_Node"..buttonID.."Texture"):SetTexture(TRK_ICON_PATH..TRK_TrackerTable[value.ref].icon);
			temp.ref = value.ref;
			temp.node = index;
			temp:Show();
			buttonID = buttonID +1;
		end
	end
end

function TRK_NodeOnEnter(ref, noteID)
	local cLevel = {r=0, g=1, b=0};
	local cTitle = {r=0.9, g=0.8, b=0};
	local mapName = MetaMap_GetCurrentMapInfo();
	if(TRK_TrackerTable[ref].cat == TRK_HRB_NAME) then
		cTitle = {r=0, g=0.8, b=0.4};
		if(not TRK_HerbRank or TRK_TrackerTable[ref].level > TRK_HerbRank) then
			cLevel = {r=1, g=0, b=0};
		end
	elseif(TRK_TrackerTable[ref].cat == TRK_ORE_NAME)then
		cTitle = {r=0.9, g=0.7, b=0.4};
	 	if(not TRK_OreRank or TRK_TrackerTable[ref].level > TRK_OreRank) then
	 		cLevel = {r=1, g=0, b=0};
	 	end
	end
	WorldMapTooltip:SetOwner(this, "ANCHOR_LEFT");
	WorldMapTooltip:AddDoubleLine(TRK_TrackerTable[ref][MetaMap_Locale], TRK_TrackerTable[ref].cat, cTitle.r, cTitle.g, cTitle.b, 0.6, 0.6, 0.6);
	WorldMapTooltip:AddDoubleLine(TRK_HEADER_LEVEL, TRK_TrackerTable[ref].level, 0.75, 0.85, 0, cLevel.r, cLevel.g, cLevel.b, 1);
	WorldMapTooltip:AddDoubleLine(TRK_HEADER_COUNT, TRK_Data[mapName][noteID].count, 0.75, 0.85, 0, 0.75, 0.85, 0, 1);
	WorldMapTooltip:AddDoubleLine(TRK_CREATOR, TRK_Data[mapName][noteID].creator, 0, 0.75, 0.85, 0, 0.75, 0.85, 1);
	WorldMapPOIFrame.allowBlobTooltip = false;
	WorldMapTooltip:Show();
end

function TRK_DisplayInit()
	TRK_NodeList.Herbs = {}; TRK_NodeList.Ores = {}; TRK_NodeList.Treasure = {}; TRK_NodeList.Misc = {}; TRK_ZoneList = {};
	TRK_HerbTotal, TRK_OreTotal, TRK_TreasureTotal, TRK_MiscTotal, TRK_ItemTotal = 0,0,0,0,0;
	local mapName = MetaMap_GetCurrentMapInfo();
	for zoneName, iTable in pairs(TRK_Data) do
		TRK_ItemTotal = TRK_ItemTotal + #(iTable);
		if(MetaMap_CheckRelatedZone(zoneName, mapName) or TRK_Options.ShowAll) then
			for index, value in ipairs(iTable) do
				local showThis = false;
				local name = TRK_TrackerTable[value.ref][MetaMap_Locale];
				local level = TRK_TrackerTable[value.ref].level;
				local cat = TRK_TrackerTable[value.ref].cat;
				if(not TRK_ZoneList[name]) then TRK_ZoneList[name] = {}; end
				if(cat == TRK_HRB_NAME and TRK_Options.ShowHerb) then showThis = true; end
				if(cat == TRK_ORE_NAME and TRK_Options.ShowOre) then showThis = true; end
				if(cat == TRK_TRS_NAME and TRK_Options.ShowTreasure) then showThis = true; end
				if(cat == TRK_MSC_NAME and TRK_Options.ShowMisc) then showThis = true; end
				if(showThis and string.find(string.lower(name),string.lower(TRK_LastSearch),1,true)) then
					if(cat == TRK_HRB_NAME) then
						local id = TRK_FindMatch(TRK_NodeList.Herbs, name);
						if(id) then
							TRK_NodeList.Herbs[id].nodes = TRK_NodeList.Herbs[id].nodes +1;
							TRK_NodeList.Herbs[id].count = TRK_NodeList.Herbs[id].count + value.count;
						else
							tinsert(TRK_NodeList.Herbs, {name = name, nodes = 1, index = value.ref, zone = zoneName, noteID = index, level = level, count = value.count});
						end
						TRK_HerbTotal = TRK_HerbTotal +1;
					elseif(cat == TRK_ORE_NAME) then
						local id = TRK_FindMatch(TRK_NodeList.Ores, name);
						if(id) then
							TRK_NodeList.Ores[id].nodes = TRK_NodeList.Ores[id].nodes +1;
							TRK_NodeList.Ores[id].count = TRK_NodeList.Ores[id].count + value.count;
						else
							tinsert(TRK_NodeList.Ores, {name = name, nodes = 1, index = value.ref, zone = zoneName, noteID = index, level = level, count = value.count});
						end
						TRK_OreTotal = TRK_OreTotal +1;
					elseif(cat == TRK_TRS_NAME) then
						local id = TRK_FindMatch(TRK_NodeList.Treasure, name);
						if(id) then
							TRK_NodeList.Treasure[id].nodes = TRK_NodeList.Treasure[id].nodes +1;
							TRK_NodeList.Treasure[id].count = TRK_NodeList.Treasure[id].count + value.count;
						else
							tinsert(TRK_NodeList.Treasure, {name = name, nodes = 1, index = value.ref, zone = zoneName, noteID = index, level = level, count = value.count});
						end
						TRK_TreasureTotal = TRK_TreasureTotal +1;
					elseif(cat == TRK_MSC_NAME) then
						local id = TRK_FindMatch(TRK_NodeList.Misc, name);
						if(id) then
							TRK_NodeList.Misc[id].nodes = TRK_NodeList.Misc[id].nodes +1;
							TRK_NodeList.Misc[id].count = TRK_NodeList.Misc[id].count + value.count;
						else
							tinsert(TRK_NodeList.Misc, {name = name, nodes = 1, index = value.ref, zone = zoneName, noteID = index, level = level, count = value.count});
						end
						TRK_MiscTotal = TRK_MiscTotal +1;
					end
					if(TRK_ZoneList[name][zoneName]) then
						TRK_ZoneList[name][zoneName].nodes = TRK_ZoneList[name][zoneName].nodes +1;
					else
						TRK_ZoneList[name][zoneName] = {};
						TRK_ZoneList[name][zoneName].nodes = 1;
					end
				end
			end
		end
	end
	TRK_SortTrackerList(TRK_Options.Sortby);
	TRK_HeaderText:SetText(mapName);
	TRK_InfoText1:SetText("Total items: |cffffff00"..TRK_ItemTotal.."|r   Displayed: |cffffff00"..TRK_HerbTotal+TRK_OreTotal+TRK_TreasureTotal+TRK_MiscTotal);
	local text = "";
	local rank, maxrank = TRK_GetSkillRank(TRK_HERBALISM);
	if(rank) then
		text = TRK_HERBALISM..": |cffffff00"..rank.."/"..maxrank;
	else
		rank, maxrank = TRK_GetSkillRank(TRK_MINING);
		if(rank) then
			text = TRK_MINING..": |cffffff00"..rank.."/"..maxrank;
		end
	end
	TRK_InfoText2:SetText(text);
	TRK_RefreshDisplay();
end

function TRK_SortTrackerList(sort)
	local tmp = MetaMap_sortType;
	MetaMap_sortType = sort;
  table.sort(TRK_NodeList.Herbs, MetaMap_SortCriteria);
  table.sort(TRK_NodeList.Ores, MetaMap_SortCriteria);
  table.sort(TRK_NodeList.Treasure, MetaMap_SortCriteria);
  table.sort(TRK_NodeList.Misc, MetaMap_SortCriteria);
	MetaMap_sortType = tmp;
end

function TRK_RefreshDisplay()
	local buttonID = 1;
	local ScrollHeight = 0;
	local button, buttonText;
	if(#(TRK_NodeList.Herbs) > 0) then
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Header");
		buttontext:SetText(TRK_HERBALISM.." - "..TRK_HerbTotal.." "..TRK_HEADER_NODES);
		buttontext:SetTextColor(0.75, 0.75, 1);
		if(buttonID == 1) then
			button:SetPoint("TOPLEFT", "TRK_ScrollChild", "TOPLEFT", 10, -15);
		else
			button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		end
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		button:Show();
	end
	for index, mList in ipairs(TRK_NodeList.Herbs) do
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Text");
		buttontext:SetText(mList.name);
		buttontext:SetTextColor(0, 0.8, 0.4);
		getglobal("TRKButton"..buttonID.."Nodes"):SetText(mList.nodes);
		getglobal("TRKButton"..buttonID.."Level"):SetText(TRK_TrackerTable[mList.index].level);
		getglobal("TRKButton"..buttonID.."Count"):SetText(mList.count);
		if(not TRK_HerbRank or TRK_TrackerTable[mList.index].level > TRK_HerbRank) then
			getglobal("TRKButton"..buttonID.."Level"):SetTextColor(1, 0, 0);
		else
			getglobal("TRKButton"..buttonID.."Level"):SetTextColor(0, 1, 0);
		end
		button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		button.ref = mList.index;
		button:Show();
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		if(TRK_ZoneExpand == mList.name) then
			buttonID, ScrollHeight = TRK_ExpandZones(mList.name, buttonID, ScrollHeight);
		end
	end
	if(#(TRK_NodeList.Ores) > 0) then
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Header");
		buttontext:SetText(TRK_MINING.." - "..TRK_OreTotal.." "..TRK_HEADER_NODES);
		buttontext:SetTextColor(0.75, 0.75, 1);
		if(buttonID == 1) then
			button:SetPoint("TOPLEFT", "TRK_ScrollChild", "TOPLEFT", 10, -15);
		else
			button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		end
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		button:Show();
	end
	for index, mList in ipairs(TRK_NodeList.Ores) do
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Text");
		buttontext:SetText(mList.name);
		buttontext:SetTextColor(0.9, 0.7, 0.4);
		getglobal("TRKButton"..buttonID.."Nodes"):SetText(mList.nodes);
		getglobal("TRKButton"..buttonID.."Level"):SetText(TRK_TrackerTable[mList.index].level);
		getglobal("TRKButton"..buttonID.."Count"):SetText(mList.count);
		if(not TRK_OreRank or TRK_TrackerTable[mList.index].level > TRK_OreRank) then
			getglobal("TRKButton"..buttonID.."Level"):SetTextColor(1, 0, 0);
		else
			getglobal("TRKButton"..buttonID.."Level"):SetTextColor(0, 1, 0);
		end
		button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		button.ref = mList.index;
		button:Show();
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		if(TRK_ZoneExpand == mList.name) then
			buttonID, ScrollHeight = TRK_ExpandZones(mList.name, buttonID, ScrollHeight);
		end
	end
	if(#(TRK_NodeList.Treasure) > 0) then
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Header");
		buttontext:SetText(TRK_TREASURE.." - "..TRK_TreasureTotal.." "..TRK_HEADER_NODES);
		buttontext:SetTextColor(0.75, 0.75, 1);
		if(buttonID == 1) then
			button:SetPoint("TOPLEFT", "TRK_ScrollChild", "TOPLEFT", 10, -15);
		else
			button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		end
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		button:Show();
	end
	for index, mList in ipairs(TRK_NodeList.Treasure) do
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Text");
		buttontext:SetText(mList.name);
		buttontext:SetTextColor(0.9, 0.8, 0);
		getglobal("TRKButton"..buttonID.."Nodes"):SetText(mList.nodes);
		getglobal("TRKButton"..buttonID.."Level"):SetText(TRK_TrackerTable[mList.index].level);
		getglobal("TRKButton"..buttonID.."Count"):SetText(mList.count);
		getglobal("TRKButton"..buttonID.."Level"):SetTextColor(0, 1, 0);
		button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		button.ref = mList.index;
		button:Show();
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		if(TRK_ZoneExpand == mList.name) then
			buttonID, ScrollHeight = TRK_ExpandZones(mList.name, buttonID, ScrollHeight);
		end
	end
	if(#(TRK_NodeList.Misc) > 0) then
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Header");
		buttontext:SetText(TRK_MISC.." - "..TRK_MiscTotal.." "..TRK_HEADER_NODES);
		buttontext:SetTextColor(0.75, 0.75, 1);
		if(buttonID == 1) then
			button:SetPoint("TOPLEFT", "TRK_ScrollChild", "TOPLEFT", 10, -15);
		else
			button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		end
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		button:Show();
	end
	for index, mList in ipairs(TRK_NodeList.Misc) do
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Text");
		buttontext:SetText(mList.name);
		buttontext:SetTextColor(0.9, 0.8, 0);
		getglobal("TRKButton"..buttonID.."Nodes"):SetText(mList.nodes);
		getglobal("TRKButton"..buttonID.."Level"):SetText(TRK_TrackerTable[mList.index].level);
		getglobal("TRKButton"..buttonID.."Count"):SetText(mList.count);
		getglobal("TRKButton"..buttonID.."Level"):SetTextColor(0.8, 0.8, 0.8);
		button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		button:SetHeight(buttontext:GetHeight() + TRK_Options.Padding);
		button.ref = mList.index;
		button:Show();
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
		if(TRK_ZoneExpand == mList.name) then
			buttonID, ScrollHeight = TRK_ExpandZones(mList.name, buttonID, ScrollHeight);
		end
	end
	for i=buttonID, TRK_ButtonTotal, 1 do
		getglobal("TRKButton"..i):Hide()
	end
	TRK_ScrollChild:SetHeight(ScrollHeight);
	TRK_ScrollFrame:UpdateScrollChildRect()
end

function TRK_ExpandZones(nodeName, buttonID, ScrollHeight)
	for zone, value in pairs(TRK_ZoneList[nodeName]) do
		button = TRK_CreateButton(buttonID);
		buttontext = getglobal("TRKButton"..buttonID.."Zones");
		buttontext:SetText(zone);
		buttontext:SetTextColor(0.75, 0.75, 1);
		getglobal("TRKButton"..buttonID.."Nodes"):SetText(TRK_ZoneList[nodeName][zone].nodes);
		button:SetPoint("TOP", getglobal("TRKButton"..buttonID-1), "BOTTOM", 0, 0)
		button.ref = zone;
		button:Show();
		ScrollHeight = ScrollHeight + button:GetHeight();
		buttonID = buttonID +1;
	end
	return buttonID, ScrollHeight;
end

function TRK_FilterMenuInit()
	for index, menuItem in ipairs(TRK_FilterMenu) do
		local check = nil;
		local spacer = nil;
		if(menuItem[3]) then spacer = 1; end
		if(TRK_Options.Sortby == string.gsub(menuItem[2], "Sortby", "")) then
			check = 1;
		elseif(TRK_Options[menuItem[2]]) then
			check = 1;
		end
		local info = {};
		info.isTitle = spacer;
		info.notClickable = spacer;
		info.checked = check;
		info.text = menuItem[1];
		info.value = menuItem[2];
		info.func = TRK_FilterMenuOnClick;
		UIDropDownMenu_AddButton(info);
	end
  UIDropDownMenu_SetText(TRK_FilterSelect, TRK_FILTER_DISP);
end

function TRK_FilterMenuOnClick()
	if(string.match(this.value, "Sortby")) then
		TRK_Options.Sortby = string.gsub(this.value, "Sortby", "");
		TRK_SortTrackerList(TRK_Options.Sortby);
		TRK_RefreshDisplay();
		return;
	else
		TRK_ToggleOptions(this.value);
	end
  UIDropDownMenu_SetText(TRK_FilterSelect, TRK_FILTER_DISP);
	TRK_DisplayInit();
end

function TRK_MetaMapMenuOnClick()
	local txt = this:GetText();
	TRK_ToggleOptions(this.value);
	TRK_DisplayInit();
	MetaMap_MainMapUpdate();
	if(string.find(txt, "|cff00ff00On|r")) then
		txt = string.gsub(txt, "|cff00ff00On|r", "|cffff0000Off|r");
	else
		txt = string.gsub(txt, "|cffff0000Off|r", "|cff00ff00On|r");
	end
	this:SetText(txt);
	this.checked = not this.checked;
end

function TRK_QuickMenuInit()
	local info, zone, node; local item = ""; local cat = "";
	if(UIDROPDOWNMENU_MENU_VALUE and UIDROPDOWNMENU_MENU_VALUE[2]) then
		zone = UIDROPDOWNMENU_MENU_VALUE[1];
		node = UIDROPDOWNMENU_MENU_VALUE[2];
		if(TRK_NodeOnMenu) then
			item = TRK_TrackerTable[TRK_Data[zone][node].ref][MetaMap_Locale];
			cat = TRK_TrackerTable[TRK_Data[zone][node].ref].cat;
		else
			item = TRK_TrackerTable[node][MetaMap_Locale];
			cat = TRK_TrackerTable[node].cat;
		end
	end
	if(TRK_NodeOnMenu) then
		info = {};
		info.notCheckable = 1;
		info.checked = nil;
		info.text = TRK_DELETE_NODE;
		info.value = 1;
		info.func = TRK_DeleteConfirm;
		info.arg1 = zone;
		info.arg2 = node;
		UIDropDownMenu_AddButton(info);
	end
	info = {};
	info.notCheckable = 1;
	info.checked = nil;
	info.text = TRK_DELETE_ALL.." |cFFFFD100"..item.."|r";
	info.value = 2;
	info.func = TRK_DeleteConfirm;
	info.arg1 = zone;
	info.arg2 = item;
	UIDropDownMenu_AddButton(info);
	info = {};
	info.notCheckable = 1;
	info.checked = nil;
	info.text = TRK_DELETE_ALL.." |cFFFFD100"..cat.."|r";
	info.value = 3;
	info.func = TRK_DeleteConfirm;
	info.arg1 = zone;
	info.arg2 = cat;
	UIDropDownMenu_AddButton(info);
	info = {};
	info.notCheckable = 1;
	info.checked = nil;
	info.text = TRK_OPTIONS_EXIT;
	info.value = nil;
	info.func = TRK_DeleteConfirm;
	UIDropDownMenu_AddButton(info);
end

function TRK_DeleteConfirm(zone, id, mode)
	if(not zone or not id) then return; end
	if(mode) then
		if(TRK_NodeOnMenu) then
			TRK_DeleteNodes(zone, id, mode)
		else
			for zoneName, iTable in pairs(TRK_Data) do
				if(MetaMap_CheckRelatedZone(zoneName, zone)) then
					TRK_DeleteNodes(zoneName, id, mode)
				end
			end
		end
	end
	local val = this.value;
	if(val == 1) then
		TRK_DeleteNodes(zone, id, val);
	else
		StaticPopupDialogs["Delete_Nodes"] = {
			text = this:GetText().." "..TRK_DELETE_FROM.." \n|cFFFFD100"..zone.."?",
			button1 = TEXT(ACCEPT),
			button2 = TEXT(DECLINE),
			OnAccept = function()
				TRK_DeleteConfirm(zone, id, val);
			end,
			timeout = 60,
			showAlert = 1,
		};
		StaticPopup_Show("Delete_Nodes");
	end
end

function TRK_ExclusionMenuInit()
	TRK_SetMenuList();
	if(UIDROPDOWNMENU_MENU_LEVEL == 2) then
		local menuVal = MetaMap_SubMenuFix();
		local menuItems = {};
		if(menuVal == "TRK_MenuList") then
			menuItems = getglobal(menuVal);
		elseif(menuVal and (TRK_MenuListSub and TRK_MenuListSub[menuVal])) then
			menuItems = TRK_MenuListSub[menuVal];
		elseif(not menuVal) then
			menuItems = TRK_MenuList;
		end
		if(menuItems) then
			for index, value in pairs(menuItems) do
				local info = {};
				info.text = menuItems[index].name;
				info.func = TRK_SetExclude;
				info.value = menuItems[index].name;
				info.checked = TRK_Excludes[menuItems[index].name];
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
		end
	else
		local info = {};
		info.text = TRK_SetMenuTitle(TRK_MenuList);
		info.hasArrow = 1;
		info.value = "TRK_MenuList";
		info.notCheckable = 1;
		UIDropDownMenu_AddButton(info);
		if(TRK_MenuListSub) then
			for index, value in ipairs(TRK_MenuListSub) do
				if(TRK_SetMenuTitle(value)) then
					local info = {};
					info.text = TRK_SetMenuTitle(value);
					info.hasArrow = 1;
					info.value = index;
					info.notCheckable = 1;
					UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
				end
			end
		end
	end	
  UIDropDownMenu_SetText(TRK_ExclusionMenu, TRK_OPTIONS_EXC);
end

function TRK_SetMenuList()
	TRK_MenuList = {};
	for index, value in pairs(TRK_Errata) do
    table.insert(TRK_MenuList, {name = index});
	end
	local sort = MetaMap_sortType;
	MetaMap_sortType = METAMAP_SORTBY_NAME;
	table.sort(TRK_MenuList, MetaMap_SortCriteria);
	MetaMap_sortType = sort;
	if(#(TRK_MenuList) > 20) then
		local tmpList = {};
		TRK_MenuListSub = {};
		TRK_MenuListSub[1] = {}; TRK_MenuListSub[2] = {};
		TRK_MenuListSub[3] = {}; TRK_MenuListSub[4] = {};
		TRK_MenuListSub[5] = {}; TRK_MenuListSub[6] = {};
		TRK_MenuListSub[7] = {}; TRK_MenuListSub[8] = {};
		local listCount = 0;
		for index, value in ipairs(TRK_MenuList) do
			listCount = listCount + 1;
			if(listCount < 21) then
				tinsert(tmpList, value)
			elseif(listCount < 42) then 
				tinsert(TRK_MenuListSub[1], value);
			elseif(listCount < 63) then 
				tinsert(TRK_MenuListSub[2], value);
			elseif(listCount < 84) then 
				tinsert(TRK_MenuListSub[3], value);
			elseif(listCount < 105) then 
				tinsert(TRK_MenuListSub[4], value);
			elseif(listCount < 126) then 
				tinsert(TRK_MenuListSub[5], value);
			elseif(listCount < 147) then 
				tinsert(TRK_MenuListSub[6], value);
			elseif(listCount < 168) then 
				tinsert(TRK_MenuListSub[7], value);
			elseif(listCount < 189) then 
				tinsert(TRK_MenuListSub[8], value);
			end
		end
		TRK_MenuList = tmpList;
	end
end

function TRK_SetMenuTitle(MList)
	local firstword, lastword, tempstring;
	for index, value in pairs(MList) do
		if(not tempstring) then
			if(value.name) then 
				tempstring = value.name;
			end
			firstword = tempstring;
		else
			if(value.name) then 
				tempstring = value.name;
			end
		end
	end
	if(tempstring and firstword) then
		lastword = strsub(tempstring, 1, string.find(tempstring, " "));
		firstword = strsub(firstword, 1, string.find(firstword, " "));
		return firstword.."- "..lastword;
	else return nil end
end

function TRK_SetExclude()
	if(TRK_Excludes[this.value]) then
		TRK_Excludes[this.value] = nil;
	else
		TRK_Excludes[this.value] = true;
	end
end

function TRK_NodeOnClick(node)
	if(not node) then return; end
	local nodeInfo = {MetaMap_GetCurrentMapInfo(), node};
	TRK_NodeOnMenu = true;
	ToggleDropDownMenu(nil, nodeInfo, TRK_QuickMenu, this, 0, 0);
end

function TRK_DisplayButtonOnClick(ref)
	if(not ref) then return; end
	if(arg1 == "LeftButton") then
		if(ref == getglobal(this:GetName().."Zones"):GetText()) then
			MetaMap_ShowLocation(ref);
			return;
		end
		if(TRK_ZoneExpand == getglobal(this:GetName().."Text"):GetText()) then
			TRK_ZoneExpand = "";
		else
			TRK_ZoneExpand = getglobal(this:GetName().."Text"):GetText();
		end
		TRK_RefreshDisplay();
	else
		local nodeInfo = {MetaMap_GetCurrentMapInfo(), ref};
		TRK_NodeOnMenu = false;
		ToggleDropDownMenu(nil, nodeInfo, TRK_QuickMenu, this, 0, 0);
	end
end

function TRK_DeleteNodes(zone, id, mode)
	if(not TRK_Data[zone]) then return; end
	local TempData = {};
	TempData[zone] = TRK_Data[zone];
	TRK_Data[zone] = {};
	for index, value in ipairs(TempData[zone]) do
		local size = #(TRK_Data[zone]) +1;
		if(mode == 1 and id ~= index) then
			TRK_Data[zone][size] = value;
		elseif(mode == 2 and id ~= TRK_TrackerTable[value.ref][MetaMap_Locale]) then
			TRK_Data[zone][size] = value;
		elseif(mode == 3 and id ~= TRK_TrackerTable[value.ref].cat) then
			TRK_Data[zone][size] = value;
		end
	end
	TempData = nil;
	if(TRK_DisplayFrame:IsVisible()) then
		TRK_DisplayInit();
	end
	if(WorldMapFrame:IsVisible()) then
		MetaMap_MainMapUpdate();
	end
end

function TRK_CreateNodeObject(id)
	local button;
	if(getglobal("TRK_Node"..id)) then
		button = getglobal("TRK_Node"..id);
		button.index = nil;
	else
		button = CreateFrame("Button" ,"TRK_Node"..id, WorldMapButton, "TRK_NodeTemplate");
		TRK_LastNode = TRK_LastNode +1;
	end
	return button;
end

function TRK_CreateButton(id)
	local button;
	if(getglobal("TRKButton"..id)) then
		button = getglobal("TRKButton"..id);
		getglobal("TRKButton"..id.."Header"):SetText("");
		getglobal("TRKButton"..id.."Text"):SetText("");
		getglobal("TRKButton"..id.."Nodes"):SetText("");
		getglobal("TRKButton"..id.."Level"):SetText("");
		getglobal("TRKButton"..id.."Count"):SetText("");
		getglobal("TRKButton"..id.."Zones"):SetText("");
		button.ref = nil;
	else
		button = CreateFrame("Button" ,"TRKButton"..id, TRK_ScrollChild, "TRK_ButtonTemplate");
		button:SetWidth(TRK_ScrollChild:GetWidth());
		TRK_ButtonTotal = TRK_ButtonTotal +1;
	end
	button:SetID(id);
	return button;
end

function TRK_GetTrackerEntry(mName)
	for index, mTable in pairs(TRK_TrackerTable) do
		if(string.lower(mName) == string.lower(mTable.en) or string.lower(mName) == string.lower(mTable.de) or string.lower(mName) == string.lower(mTable.fr)) then
			return mTable[MetaMap_Locale], index, mTable.cat;
		end
	end
end

function TRK_FindMatch(table, name)
	for index, value in pairs(table) do
		if(value.name == name) then
			return index;
		end
	end
end

function TRK_GetSkillRank(skill)
	for skillIndex = 1, GetNumSkillLines() do
		skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(skillIndex);
		if(not isHeader and skillName == skill) then
			return skillRank, skillMaxRank;
		end
	end
end

function TRK_UpDateDB()
	for zone, indexTable in pairs(TRK_Data) do
		for index, value in ipairs(indexTable) do
			if(not value.count or type(value.count) == "boolean") then
				value.count = 0;
			end
		end
	end
	for mName, item in pairs(TRK_Errata) do
		local name, entry = TRK_GetTrackerEntry(mName);
		if(entry) then
			for zone, indexTable in pairs(TRK_Data) do
				for index, value in ipairs(indexTable) do
					if(value.ref == item.ref) then
						value.ref = entry;
					end
				end
			end
			TRK_Errata[mName] = nil;
		end
	end
	for mName, value in pairs(TRK_Errata) do
		TRK_TrackerTable[value.ref] = {};
		TRK_TrackerTable[value.ref].cat = TRK_MSC_NAME;
		TRK_TrackerTable[value.ref].en = mName;
		TRK_TrackerTable[value.ref].de = mName;
		TRK_TrackerTable[value.ref].fr = mName;
		TRK_TrackerTable[value.ref].level = 0;
		TRK_TrackerTable[value.ref].icon = "Misc_Generic";
	end
end

function TRK_HintTooltip()
	WorldMapTooltip:SetOwner(this, "ANCHOR_TOPLEFT");
	WorldMapTooltip:SetText(TRK_TTHINT_H0, 0.2, 0.5, 1, 1);
	WorldMapTooltip:AddDoubleLine("Left-Click", TRK_TTHINT_T1, 1, 1, 1, 1);
	WorldMapTooltip:AddDoubleLine("Right-Click", TRK_TTHINT_T2, 1, 1, 1, 1);
	WorldMapPOIFrame.allowBlobTooltip = false;
	WorldMapTooltip:Show();
end

function TRK_ToggleOptions(key, value)
	if(value) then
		TRK_Options[key] = value;
	else
		TRK_Options[key] = not TRK_Options[key];
	end
	return TRK_Options[key];
end

TRK_TrackerTable = {
	--- Herbs
	[1]  = {cat = TRK_HRB_NAME, en = "Silverleaf", de = "Silberblatt", fr = "Feuillargent", level = 1, icon = "Herb_Silverleaf"},
	[2]  = {cat = TRK_HRB_NAME, en = "Peacebloom", de = "Friedensblume", fr = "Pacifique", level = 1, icon = "Herb_Peacebloom"},
	[3]  = {cat = TRK_HRB_NAME, en = "Earthroot", de = "Erdwurzel", fr = "Terrestrine", level = 15, icon = "Herb_Earthroot"},
	[4]  = {cat = TRK_HRB_NAME, en = "Mageroyal", de = "Magusk\195\182nigskraut", fr = "Mage Royal", level = 50, icon = "Herb_Mageroyal"},
	[5]  = {cat = TRK_HRB_NAME, en = "Swiftthistle", de = "Flitzdistel", fr = "Chardonnier", level = 50, icon = "Herb_Swiftthistle"},
	[6]  = {cat = TRK_HRB_NAME, en = "Briarthorn", de = "Wilddornrose", fr = "Eglantine", level = 75, icon = "Herb_Briarthorn"},
	[7]  = {cat = TRK_HRB_NAME, en = "Stranglekelp", de = "W\195\188rgetang", fr = "Etouffante", level = 85, icon = "Herb_Stranglekelp"},
	[8]  = {cat = TRK_HRB_NAME, en = "Bruiseweed", de = "Beulengras", fr = "Doulourante", level = 100, icon = "Herb_Bruiseweed"},
	[9]  = {cat = TRK_HRB_NAME, en = "Wild Steelbloom", de = "Wildstahlblume", fr = "Aci\195\169rite Sauvage", level = 115, icon = "Herb_WildSteelbloom"},
	[10] = {cat = TRK_HRB_NAME, en = "Grave Moss", de = "Grabmoos", fr = "Tombeline", level = 120, icon = "Herb_GraveMoss"},
	[11] = {cat = TRK_HRB_NAME, en = "Kingsblood", de = "K\195\182nigsblut", fr = "Sang-Royal", level = 125, icon = "Herb_Kingsblood"},
	[12] = {cat = TRK_HRB_NAME, en = "Liferoot", de = "Lebenswurz", fr = "Viet\195\169rule", level = 150, icon = "Herb_Liferoot"},
	[13] = {cat = TRK_HRB_NAME, en = "Fadeleaf", de = "Blassblatt", fr = "P\195\162lerette", level = 160, icon = "Herb_Fadeleaf"},
	[14] = {cat = TRK_HRB_NAME, en = "Goldthorn", de = "Golddorn", fr = "Dor\195\169pine", level = 175, icon = "Herb_Goldthorn"},
	[15] = {cat = TRK_HRB_NAME, en = "Khadgar's Whisker", de = "Khadgars Schnurrbart", fr = "Moustache de Khadgar", level = 185, icon = "Herb_KhadgarsWhisker"},
	[16] = {cat = TRK_HRB_NAME, en = "Wintersbite", de = "Winterbiss", fr = "Hivernale", level = 195, icon = "Herb_Wintersbite"},
	[17] = {cat = TRK_HRB_NAME, en = "Firebloom", de = "Feuerbl\195\188te", fr = "Fleur de Feu", level = 205, icon = "Herb_Firebloom"},
	[18] = {cat = TRK_HRB_NAME, en = "Purple Lotus", de = "Lila Lotus", fr = "Lotus Pourpre", level = 210, icon = "Herb_PurpleLotus"},
	[19] = {cat = TRK_HRB_NAME, en = "Wildvine", de = "Wildranke", fr = "Sauvageonne", level = 210, icon = "Herb_Generic"},
	[20] = {cat = TRK_HRB_NAME, en = "Arthas' Tears", de = "Arthas\226\128\153 Tr\195\164nen", fr = "Larmes d'Arthas", level = 220, icon = "Herb_ArthasTears"},
	[21] = {cat = TRK_HRB_NAME, en = "Sungrass", de = "Sonnengras", fr = "Soleillette", level = 230, icon = "Herb_Sungrass"},
	[22] = {cat = TRK_HRB_NAME, en = "Blindweed", de = "Blindkraut", fr = "Aveuglette", level = 235, icon = "Herb_Blindweed"},
	[23] = {cat = TRK_HRB_NAME, en = "Ghost Mushroom", de = "Geisterpilz", fr = "Champignon Fant\195\180me", level = 245, icon = "Herb_GhostMushroom"},
	[24] = {cat = TRK_HRB_NAME, en = "Gromsblood", de = "Gromsblut", fr = "Gromsang", level = 250, icon = "Herb_Gromsblood"},
	[25] = {cat = TRK_HRB_NAME, en = "Golden Sansam", de = "Goldener Sansam", fr = "Sansam Dor\195\169", level = 260, icon = "Herb_GoldenSansam"},
	[26] = {cat = TRK_HRB_NAME, en = "Dreamfoil", de = "Traumblatt", fr = "Feuiller\195\170ve", level = 270, icon = "Herb_Dreamfoil"},
	[27] = {cat = TRK_HRB_NAME, en = "Mountain Silversage", de = "Bergsilberweisling", fr = "Sauge-Argent des Montagnes", level = 280, icon = "Herb_MountainSilversage"},
	[28] = {cat = TRK_HRB_NAME, en = "Plaguebloom", de = "Pestbl\195\188te", fr = "Fleur de Peste", level = 285, icon = "Herb_Plaguebloom"},
	[29] = {cat = TRK_HRB_NAME, en = "Icecap", de = "Eiskappe", fr = "Calot de Glace", level = 290, icon = "Herb_Icecap"},
	[30] = {cat = TRK_HRB_NAME, en = "Black Lotus", de = "Schwarzer Lotus", fr = "Lotus Noir", level = 300, icon = "Herb_BlackLotus"},
	[31] = {cat = TRK_HRB_NAME, en = "Felweed", de = "Teufelsgras", fr = "Unknown", level = 300, icon = "Herb_Felweed"},
	[32] = {cat = TRK_HRB_NAME, en = "Dreaming Glory", de = "Traumwinde", fr = "Unknown", level = 315, icon = "Herb_DreamingGlory"},
	[33] = {cat = TRK_HRB_NAME, en = "Terocone", de = "Terozapfen", fr = "Unknown", level = 325, icon = "Herb_Terocone"},
	[34] = {cat = TRK_HRB_NAME, en = "Ragveil", de = "Zottelkappe", fr = "Unknown", level = 325, icon = "Herb_Ragveil"},
	[35] = {cat = TRK_HRB_NAME, en = "Netherbloom", de = "Netherbl\195\188te", fr = "Unknown", level = 350, icon = "Herb_Netherbloom"},
	[36] = {cat = TRK_HRB_NAME, en = "Flame Cap", de = "Flammenkappe", fr = "Unknown", level = 335, icon = "Herb_FlameCap"},
	[37] = {cat = TRK_HRB_NAME, en = "Fel Lotus", de = "Teufelslotus", fr = "Unknown", level = 360, icon = "Herb_FelLotus"},
	[38] = {cat = TRK_HRB_NAME, en = "Mana Thistle", de = "Manadistel", fr = "Unknown", level = 360, icon = "Herb_ManaThistle"},
	[39] = {cat = TRK_HRB_NAME, en = "Nightmare Vine", de = "Alptraumranke", fr = "Unknown", level = 375, icon = "Herb_NightmareVine"},
	[40] = {cat = TRK_HRB_NAME, en = "Ancient Lichen", de = "Urflechte", fr = "Unknown", level = 340, icon = "Herb_AncientLichen"},
	--- Ores
	[50] = {cat = TRK_ORE_NAME, en = "Copper Vein", de = "Kupfervorkommen", fr = "Filon de cuivre", level = 1, icon = "Ore_Copper"},
	[51] = {cat = TRK_ORE_NAME, en = "Tin Vein", de = "Zinnvorkommen", fr = "Filon d'\195\169tain", level = 65, icon = "Ore_Tin"},
	[52] = {cat = TRK_ORE_NAME, en = "Silver Vein", de = "Silbervorkommen", fr = "Filon d'Argent", level = 75, icon = "Ore_Silver"},
	[53] = {cat = TRK_ORE_NAME, en = "Iron Deposit", de = "Eisenvorkommen", fr = "Gisement de fer", level = 125, icon = "Ore_Iron"},
	[54] = {cat = TRK_ORE_NAME, en = "Gold Vein", de = "Goldvorkommen", fr = "Filon d'or", level = 155, icon = "Ore_Gold"},
	[55] = {cat = TRK_ORE_NAME, en = "Mithril Deposit", de = "Mithrilablagerung", fr = "Gisement de mithril", level = 175, icon = "Ore_Mithril"},
	[56] = {cat = TRK_ORE_NAME, en = "Truesilver Deposit", de = "Echtsilberablagerung", fr = "Gisement de vrai-argent", level = 230, icon = "Ore_Truesilver"},
	[57] = {cat = TRK_ORE_NAME, en = "Dark Iron Deposit", de = "Dunkeleisenablagerung", fr = "Gisement de sombrefer", level = 230, icon = "Ore_DarkIron"},
	[58] = {cat = TRK_ORE_NAME, en = "Small Thorium Vein", de = "Kleines Thoriumvorkommen", fr = "Petit filon de thorium", level = 245, icon = "Ore_Thorium"},
	[59] = {cat = TRK_ORE_NAME, en = "Rich Thorium Vein", de = "Reiches Thoriumvorkommen", fr = "Riche filon de thorium", level = 275, icon = "Ore_Thorium"},
	[60] = {cat = TRK_ORE_NAME, en = "Fel Iron Deposit", de = "Teufelseisenvorkommen", fr = "Gisement de Gangrefer", level = 300, icon = "Ore_FelIron"},
	[61] = {cat = TRK_ORE_NAME, en = "Adamantite Vein", de = "Adamantitvorkommen", fr = "Gisement d'adamantite", level = 325, icon = "Ore_Adamantite"},
	[62] = {cat = TRK_ORE_NAME, en = "Rich Adamantite Deposit", de = "Reiche Adamantitablagerung", fr = "Riche gisement d'adamantite", level = 375, icon = "Ore_Adamantite"},
	[63] = {cat = TRK_ORE_NAME, en = "Khorium Vein", de = "Khoriumvorkommen", fr = "Filon de khorium", level = 375, icon = "Ore_Khorium"},
	[64] = {cat = TRK_ORE_NAME, en = "Adamantite Deposit", de = "Adamantitablagerung", fr = "Unknown", level = 325, icon = "Ore_Adamantite"},
	[65] = {cat = TRK_ORE_NAME, en = "Lesser Bloodstone Deposit", de = "Geringe Blutsteinablagerung", fr = "Unknown", level = 1, icon = "Ore_LesserBloodstone"},
	[66] = {cat = TRK_ORE_NAME, en = "Hakkari Thorium Vein", de = "Hakkari Thoriumvorkommen", fr = "Filon de thorium Hakkari", level = 1, icon = "Ore_Thorium"},
	--- Treasure
	[80] = {cat = TRK_TRS_NAME, en = "Alliance Chest", de = "Truhe der Allianz", fr = "Coffre de l'Alliance", level = 0, icon = "Treasure_Chest"},
	[81] = {cat = TRK_TRS_NAME, en = "Horde Chest", de = "Truhe der Horde", fr = "Coffre de la Horde", level = 0, icon = "Treasure_Chest"},
	[82] = {cat = TRK_TRS_NAME, en = "Battered Chest", de = "Ramponierte Truhe", fr = "Coffre endommag\195\169", level = 0, icon = "Treasure_Chest"},
	[83] = {cat = TRK_TRS_NAME, en = "Locked Chest", de = "Verschlossene Truhe", fr = "Unknown", level = 0, icon = "Treasure_Chest"},
	[84] = {cat = TRK_TRS_NAME, en = "Rusty Chest", de = "Rostige Truhe", fr = "Unknown", level = 0, icon = "Treasure_Chest"},
	[85] = {cat = TRK_TRS_NAME, en = "Solid Chest", de = "Robuste Truhe", fr = "Coffre solide", level = 0, icon = "Treasure_Chest"},
	[86] = {cat = TRK_TRS_NAME, en = "Armor Crate", de = "R\195\188stungskiste", fr = "Caisse d'armures", level = 0, icon = "Treasure_Crate"},
	[87] = {cat = TRK_TRS_NAME, en = "Food Crate", de = "Nahrungsmittelkiste", fr = "Caisse de nourriture", level = 0, icon = "Treasure_Crate"},
	[88] = {cat = TRK_TRS_NAME, en = "Horde Supply Crate", de = "Vorratskiste der Horde", fr = "Caisse de ravitaillement de la Horde", level = 0, icon = "Treasure_Crate"},
	[89] = {cat = TRK_TRS_NAME, en = "Box of Assorted Parts", de = "Kasten mit verschiedenen Ersatzteilen", fr = "Bo\195\174te de pi\195\168ces assorties", level = 0, icon = "Treasure_Crate"},
	[90] = {cat = TRK_TRS_NAME, en = "Hidden Strongbox", de = "Versteckte Geldkassette", fr = "Coffre dissimul\195\169", level = 0, icon = "Treasure_Crate"},
	[91] = {cat = TRK_TRS_NAME, en = "Weapon Crate", de = "Waffenkiste", fr = "Caisse d'armes", level = 0, icon = "Treasure_Crate"},
	[92] = {cat = TRK_TRS_NAME, en = "Battered Footlocker", de = "Ramponierte Schlie\195\159kiste", fr = "Cantine endommag\195\169e", level = 0, icon = "Treasure_Footlocker"},
	[93] = {cat = TRK_TRS_NAME, en = "Blood of Heroes", de = "Blut von Helden", fr = "Sang des H\195\169ros", level = 0, icon = "Treasure_BloodHero"},
	[94] = {cat = TRK_TRS_NAME, en = "Shellfish Trap", de = "Schalentierfalle", fr = "Casier \195\160 Crustac\195\169s", level = 0, icon = "Treasure_ShellfishTrap"},
	[95] = {cat = TRK_TRS_NAME, en = "Giant Clam", de = "Riesenmuschel", fr = "Palourde", level = 0, icon = "Treasure_Clam"},
	[96] = {cat = TRK_TRS_NAME, en = "Red Power Crystal", de = "Roter Machtkristall", fr = "Cristal de Puissance", level = 0, icon = "Treasure_PowerCrystal"},
	[97] = {cat = TRK_TRS_NAME, en = "Blue Power Crystal", de = "Blauer Machtkristall", fr = "Cristal de Puissance", level = 0, icon = "Treasure_PowerCrystal"},
	[98] = {cat = TRK_TRS_NAME, en = "Green Power Crystal", de = "Gr\195\188ner Machtkristall", fr = "Cristal de Puissance", level = 0, icon = "Treasure_PowerCrystal"},
	[99] = {cat = TRK_TRS_NAME, en = "Yellow Power Crystal", de = "Gelber Machtkristall", fr = "Cristal de Puissance", level = 0, icon = "Treasure_PowerCrystal"},
	[100] = {cat = TRK_TRS_NAME, en = "Un'Goro Dirt Pile", de = "Un'Goro-Erdhaufen", fr = "Unknown", level = 0, icon = "Treasure_DirtPile"},
	[101] = {cat = TRK_TRS_NAME, en = "Bloodpetal Sprout", de = "Blutbl\195\188tenspr\195\182ssling", fr = "Pousse de P\195\169tale de Sang", level = 0, icon = "Treasure_Sprout"},
	--- Misc
	[102] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[103] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[104] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[105] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[106] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[107] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[108] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
	[109] = {cat = TRK_MSC_NAME, en = TRK_MSC_HOLDER, de = TRK_MSC_HOLDER, fr = TRK_MSC_HOLDER, level = 0, icon = "Misc_Generic"},
}
