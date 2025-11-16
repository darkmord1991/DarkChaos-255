--- MetaMap
--- Written by MetaHawk - aka Urshurak
--- Fan Update (hopefully temporary) by Charroux/Tallspirit

METAMAP_TITLE = "MetaMap";
METAMAP_TOC = 3.3;
METAMAP_VERSION = METAMAP_TOC..".10";

METAMAP_NAME = METAMAP_TITLE.."  v"..METAMAP_VERSION;
METAMAPPOI_NAME = "MetaMapPOI";
METAMAP_ICON = "Interface\\WorldMap\\UI-World-Icon";
METAMAP_MAP_PATH = "Interface\\AddOns\\MetaMap\\Maps\\";
METAMAP_ICON_PATH = "Interface\\AddOns\\MetaMap\\Icons\\";
METAMAP_IMAGE_PATH = "Interface\\AddOns\\MetaMap\\Images\\"
METAMAP_SHADER_PATH = "Interface\\AddOns\\MetaMap\\Shaders\\"
METAMAP_MAPCREDITS = "Maps created by Nifl";
TITAN_METAMAP_ID = METAMAP_TITLE;
TITAN_METAMAP_FREQUENCY = 1;

METAMAP_MENUBUTTON_HEIGHT = 16;
METAMAP_LISTBUTTON_HEIGHT = 20;
METAMAP_LISTBUTTON_SHOWN = 30;
METAMAP_SORTBY_NAME = "name";
METAMAP_SORTBY_DESC = "desc";
METAMAP_SORTBY_LEVEL = "level";
METAMAP_SORTBY_LOCATION = "location";
METAMAP_TT_NAME = nil;
METAMAP_POS_UPDATED = nil;

MetaMap_Details = {
	name = METAMAP_TITLE,
	description = METAMAP_DESC,
	version = METAMAP_VERSION,
	releaseDate = "November 26, 2005",
	author = "MetaHawk",
	email = "admin@metaserve.org.uk",
	website = "",
	category = MYADDONS_CATEGORY_MAP,
}

MetaMapOptions = {};
MetaMap_Continents = {};
MetaMap_Notes = {};
MetaMap_Lines = {};
MetaMap_MiniNote_Data = {};
MetaMap_NoteFilter = {};
local MetaMap_NoteList = {};
local MetaMap_Relocate = {};
local MetaMap_LastLineClick = {};
local MetaMap_PartyNoteData = {};
local MetaMap_ZoneErrata = nil;

MetaMap_ListOffset = 0;
MetaMap_PingTime = 15;
MetaMap_PingPOI = nil;
MetaMap_FullScreenMode = false;
MetaMapContainer_CurrentFrame = nil;
MetaMap_MenuParent = "cursor";
MetaMap_sortDone = true;
MetaMap_sortType = METAMAP_SORTBY_NAME;
MetaMap_OptionsInfo = nil;
MetaMap_Qnote = false;
MetaMap_PartyNoteSet = false;
MetaMap_LastLineClick.time = 0;
MetaMap_TempData_Id = "";
MetaMap_TempData_Zone = "";
MetaMap_TempData_Name = "";
MetaMap_TempData_Creator = "";
MetaMap_TempData_xPos = "";
MetaMap_TempData_yPos = "";
MetaMap_TempData_Icon = "";
MetaMap_TempData_TextColor = "";
MetaMap_TempData_Info1Color = "";
MetaMap_TempData_Info2Color = "";
MetaMap_TempData_LootID = nil;
MetaMap_MiniNote_IsInCity = false;
MetaMap_MiniNote_MapzoomInit = false;
MetaMap_SetNextAsMiniNote = 0;
MetaMap_Orphans = 0;
MetaMap_TimerDelay = nil;

local MetaMap_VarsLoaded = false;
local MetaMap_FilterName = "";
local MetaMap_CurrentSaveSet = 1;
local MetaMap_CurrentShadeSet = 1;
local MetaMap_CurrentAction = false;
local MetaMap_LastNote = 0;
local MetaMap_LastLine = 0;
local MetaMap_OrigChatFrame_OnEvent;
local MetaMap_MinDiff = 7
local MetaMap_vnote_xPos = nil;
local MetaMap_vnote_yPos = nil;
local MetaMap_Drawing = nil;
local MetaMap_ModuleTimer = 5.0;


MetaMap_Default = {
	["SaveSet"] = 1,
	["MetaMapAlpha1"] = 1.0,
	["MetaMapAlpha2"] = 0.60,
	["BDshader1"] = 0.0,
	["BDshader2"] = 0.0,
	["MetaMapScale1"] = 0.75,
	["MetaMapScale2"] = 0.55,
	["MetaMapTTScale1"] = 1.0,
	["MetaMapTTScale2"] = 0.75,
	["ContainerAlpha"] = 0,
	["ActionMode1"] = false,
	["ActionMode2"] = false,
	["MetaMapButtonPosition"] = 138,
	["ShadeSet1"] = 2,
	["ShadeSet2"] = 3,
	["MiniColor"] = 4,
	["MenuFont"] = 10,
	["MetaMapZone"] = nil,
	["MetaMapCoords"] = true,
	["MetaMapMiniCoords"] = true,
	["MetaMapButtonShown"] = true,
	["MetaMapTracker"] = false,
	["TrackerIcon"] = false,
	["TooltipWrap"] = true,
	["ShowCreator"] = true,
	["MenuMode"] = false,
	["ShowMapList"] = true,
	["LastHighlight"] = true,
	["LastMiniHighlight"] = true,
	["NoteSize"] = 16,
	["AcceptIncoming"] = true,
	["MiniParty"] = true,
	["ListColors"] = true,
	["ZoneHeader"] = false,
	["SortList"] = false,
	["UsePOI"] = false,
	["WKBalwaysOn"] = false,
	["QSTalwaysOn"] = false,
	["FWMalwaysOn"] = false,
	["BWPalwaysOn"] = false,
	["NBKalwaysOn"] = false,
	["TRKalwaysOn"] = false,
}
MetaMapOptions.MenuFont = 10;
MetaMap_MainMenuData = {
	[1]  = {text = METAMAP_MENU_MAPCRD, opt = "MetaMapCoords", ksoc = 1, mode = 1},
	[2]  = {text = METAMAP_MENU_MINCRD, opt = "MetaMapMiniCoords", ksoc = 1, mode = 1},
	[3]  = {text = METAMAP_MENU_ACTION, opt = "MetaMap_ActionToggle", ksoc = 1, mode = 2},
	[4]  = {text = METAMAP_MENU_MAPSET, opt = "MetaMapSaveSet_Toggle", ksoc = 1, mode = 2},
	[5]  = {text = METAMAP_MENU_FWMMOD, opt = "MetaMap_LoadFWM", ksoc = 1, mode = 2},
	[6]  = {text = METAMAP_MENU_TRKSET, opt = "MetaMap_SetTracker", ksoc = 1, mode = 2},
	[7]  = {text = "", ksoc = 1, nc = 1},
	[8]  = {text = METAMAP_MENU_FILTER, opt = "", ksoc = 1, ha = 1},
	[9]  = {text = METAMAP_MENU_TRKFILTER, opt = "", ksoc = 1, ha = 1},
	[10]  = {text = "", ksoc = 1, nc = 1},
	[11] = {text = METAMAP_MENU_EXTOPT, opt = "MetaMapExtOptions_Toggle", mode = 2},
	[12] = {text = METAMAP_MENU_FLIGHT, opt = "FlightMapOptions_Toggle", mode = 2},
	[13] = {text = METAMAP_MENU_TRKMOD, opt = "MetaMap_LoadTRK", mode = 2},
	[14] = {text = METAMAP_MENU_BWPMOD, opt = "MetaMap_LoadBWP", mode = 2},
	[15] = {text = METAMAP_MENU_WKBMOD, opt = "MetaMap_LoadWKB", mode = 2},
	[16] = {text = METAMAP_MENU_QSTMOD, opt = "MetaMap_LoadQST", mode = 2},
	[17] = {text = METAMAP_MENU_NBKMOD, opt = "MetaMap_LoadNBK", mode = 2},
};

--local WMCDDB_OldScript;

function MetaMap_SetWorldMap()
	
	--MetaMap_Debug_Print("SetWorldMap",true);
	
	BlackoutWorld:Hide();
	WorldMapZoomOutButton:Hide();
	WorldMapFrame:SetMovable(true);
	WorldMapMagnifyingGlassButton:Hide();
	MiniMapWorldMapButton:Hide();
	WMF_OldScript = WorldMapFrame:GetScript("OnKeyDown");
	WorldMapFrame:SetScript("OnKeyDown", nil);
	UIPanelWindows["WorldMapFrame"] =	{ area = "center",	pushable = 0 };
	UIPanelWindows["WorldMapFrame"].allowOtherPanels = true;
	GTT_OldScript = GameTooltip:GetScript("OnShow");
	if(GTT_OldScript) then
		GameTooltip:SetScript("OnShow", function() METAMAP_TT_NAME = GameTooltipTextLeft1:GetText(); GTT_OldScript(); end);
	else
		GameTooltip:SetScript("OnShow", function() METAMAP_TT_NAME = GameTooltipTextLeft1:GetText(); end);
	end

	WorldMapFrameSizeDownButton:SetScript("OnClick", function() MetaMap_ToggleMapSize() end)
	WorldMapFrameSizeUpButton:SetScript("OnClick", function() MetaMap_ToggleMapSize() end)
	--WorldMapFrame:HookScript("OnUpdate", function () MetaMapWorldMapFrame_OnUpdate() end)
	--WorldMapFrame:HookScript("OnShow", function () MetaMapWorldMapFrame_OnShow() end)
	
	hooksecurefunc(WorldMapFrame,"Show",MetaMapTopFrame_OnShow);
	--hooksecurefunc(MetaMapButton,"Click",MetaMapButton_OnClick);
	MetaMapButton:HookScript("OnClick", function () MetaMapButton_OnClick() end)
	WorldMapQuestShowObjectives:HookScript("OnClick", function () MetaMapQuestShowObjectives_OnClick() end)
	
	--WMCDDB_OldScript = WorldMapContinentDropDownButton:GetScript("OnClick");
	--WorldMapContinentDropDownButton:HookScript("OnClick", function () MetaMapContinentDropDownButton_OnClick(self,button,down) end)
	
	
	--WorldMapFrameSizeDownButton:Hide();
	--WorldMapFrame:SetFrameStrata("DIALOG");
	
	WorldMapFrame:ClearAllPoints();
	WorldMapFrame:SetPoint("CENTER","UIParent", "CENTER",0,0);
	
	--WorldMapFrame:HookScript("OnShow", wmfOnShow)
	--WorldMapFrame:HookScript("OnHide", wmfOnHide)
	WorldMapFrame:SetParent(UIParent);
	
	--WorldMapFrame.bigMap = nil;
	--WORLDMAP_SETTINGS.size=WORLDMAP_QUESTLIST_SIZE;
	
	MetaMap_SetFrameStrata();
	
	SetMapToCurrentZone();
end

function MetaMap_SetFrameStrata()

	if(MetaMapOptions.MetaMapFrameStrata == 2) then
	   strata = "DIALOG";
	elseif (MetaMapOptions.MetaMapFrameStrata == 1)then
	   strata = "HIGH";
	else
	   strata = "MEDIUM";
	end
    WorldMapFrame_ResetFrameLevels();
	WorldMapTooltip:SetFrameStrata("TOOLTIP");
	WorldMapFrame:SetFrameStrata(strata);
	
	--WorldMapBlobFrame:SetFrameLevel(WorldMapPOIFrame:GetFrameLevel()+1);
	--WorldMapBlobFrame:SetFrameStrata("TOOLTIP");
	--WorldMapQuestScrollFrame:SetFrameLevel(MetaMapTopFrame:GetFrameLevel()+6);
	WorldMapCompareTooltip1:SetFrameStrata("TOOLTIP");
	WorldMapCompareTooltip2:SetFrameStrata("TOOLTIP");
	WorldMapTooltip:SetFrameLevel("300");
end

function MetaMapButton_OnClick()
 MetaMap_Debug_Print("MetaMapButton_OnClick",true);
 MetaMap_ToggleFrame(WorldMapFrame);
end

--[[local oldBFMOnUpdate
function wmfOnShow(frame)
	MetaMap_Debug_Print("wmfOnShow",true);
	if BattlefieldMinimap then
		oldBFMOnUpdate = BattlefieldMinimap:GetScript("OnUpdate")
		BattlefieldMinimap:SetScript("OnUpdate", nil)
	end

	WorldMapFrame_SelectQuest(WorldMapQuestScrollChildFrame.selected)
end

function wmfOnHide(frame)
	SetMapToCurrentZone()
	if BattlefieldMinimap then
		BattlefieldMinimap:SetScript("OnUpdate", oldBFMOnUpdate or BattlefieldMinimap_OnUpdate)
	end
end]]--

function MetaMap_OnLoad(self)
	--hooksecurefunc(MetaMap_EventFrame,"Event",MetaMap_OnEvent);
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("WORLD_MAP_UPDATE");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("PLAYER_AURAS_CHANGED");
	self:RegisterEvent("CHAT_MSG_ADDON");
	--self:RegisterEvent("QUEST_LOG_UPDATE");
	--self:RegisterEvent("QUEST_POI_UPDATE");
	if(IsAddOnLoaded("FuBar")) then	MetaMap_FuBar_OnLoad() end
end

function MetaMapContainerFrame_OnLoad(self)
	self:SetWidth(WorldMapButton:GetWidth() - MetaMap_MapListFrame:GetWidth()-1);
	self:SetHeight(WorldMapButton:GetHeight()-41);
	self:SetFrameLevel(self:GetParent():GetFrameLevel()+3);
	MetaMapContainer_Header:SetFrameLevel(self:GetFrameLevel()+2);
	MetaMapContainer_Footer:SetFrameLevel(self:GetFrameLevel()+2);
	MetaMapContainer_CloseButton:SetFrameLevel(MetaMapContainer_Footer:GetFrameLevel()+2);
end

local MetaMap_Reshow_BattlefiedMap

local wmfStartMoving, wmfStopMoving

function MetaMapStartMoving(frame)
	frame:StartMoving()
end

function MetaMapStopMoving(frame)
	frame:StopMovingOrSizing()
	WorldMapFrame_UpdateQuests()
		WorldMapFrame_SetPOIMaxBounds()
	    WorldMapQuestShowObjectives_AdjustPosition()
end

function MetaMapQuestShowObjectives_OnClick()
 MetaMap_SetPointerSize()
end

--function MetaMapContinentDropDownButton_OnClick(self,button,down)
-- MetaMap_ShowInstance(false);
 --WorldMapContinentsDropDown_Update()
 --WMCDDB_OldScript(self,button,down);
--end

function MetaMap_ToggleMapSize()
 
 --MetaMap_Debug_Print("MetaMap_ToggleMapSize:",true);
	MetaMapSaveSet_Toggle()
end



function MetaMapWorldMapFrame_OnUpdate(self,elapsed)

-- MetaMap_Debug_Print("WorldMapFrame_OnUpdate:",true);
--[[
			point, relativeTo, relativePoint, xOfs, yOfs = WorldMapPing:GetPoint()
if(relativeTo ~= nil) then
DEFAULT_CHAT_FRAME:AddMessage("Ping: "..point..","..relativeTo:GetName()..","..relativePoint..","..xOfs..","..yOfs)
end


point, relativeTo, relativePoint, xOfs, yOfs = PlayerArrowFrame:GetPoint()
if(relativeTo ~= nil) then
  DEFAULT_CHAT_FRAME:AddMessage("Arrow: "..point..","..relativeTo:GetName()..","..relativePoint..","..xOfs..","..yOfs) 
  PlayerArrowFrame:ClearAllPoints();
  PositionWorldMapArrowFrame("center","WorldMapDetailFrame","topleft",xOfs,yOfs);
  PlayerArrowFrame:ClearAllPoints();
  PlayerArrowFrame:SetPoint("center","WorldMapDetailFrame","topleft",500,-308);
  UpdateWorldMapArrowFrames();
  point, relativeTo, relativePoint, xOfs, yOfs = PlayerArrowFrame:GetPoint()
  DEFAULT_CHAT_FRAME:AddMessage("ArrowAfter: "..point..","..relativeTo:GetName()..","..relativePoint..","..xOfs..","..yOfs)
  
 end 
]]--
end


 function MetaMapWorldMapFrame_OnShow()
    MetaMap_Debug_Print("MetaMapWorldMapFrame_OnShow", true);
	MetaMapTopFrame_OnShow();

 end
 
 
 
--Called when button on Mini map is called.
function MetaMapTopFrame_OnShow()
	
	MetaMap_Debug_Print("MetaMapTopFrame_OnShow",true);
	
	
	
	if(MetaMap_FullScreenMode) then
	 BlackoutWorld:Show();
	else

		BlackoutWorld:Hide();
		if(WorldMapFrame:IsVisible()) then
		
			ShowUIPanel(WorldMapFrame);
		end
		MetaMap_ToggleDR(1);
		
		
		WorldMapZoomOutButton:Hide();
		WorldMapMagnifyingGlassButton:Hide();
		MiniMapWorldMapButton:Hide();
		
	
		
		WorldMapFrame:EnableMouse(true);
		
	
		
		WorldMapFrame:SetMovable(true);
		WorldMapFrame:RegisterForDrag("LeftButton");
		WorldMapFrame:SetScript("OnDragStart", MetaMapStartMoving);
		WorldMapFrame:SetScript("OnDragStop", MetaMapStopMoving);
		
		--local px, py = GetPlayerMapPosition("player");
		--MetaMap_Debug_Print("px: "..px..", py: "..py, true);
		
		
		--UIParent:Show();
		MetaMapOptions_Init();
		
		UpdateWorldMapArrowFrames();
	

		MetaMapFrame:EnableMouse(true);
		MetaMapFrame:SetFrameLevel(WorldMapFrame:GetFrameLevel()+3);
		MetaMapTopFrame:SetFrameLevel(WorldMapFrame:GetFrameLevel()+2);	
		MetaMap_InfoLineFrame:SetFrameLevel(MetaMapFrame:GetFrameLevel()+1);
		
		
	    MetaMap_Debug_Print("MetaMapTopFrame_OnShow: Updating Quests",true);
		--WORLDMAP_SETTINGS.size=WORLDMAP_QUESTLIST_SIZE;
		WorldMapFrame_UpdateQuests();
		WorldMapQuestShowObjectives_AdjustPosition();
 		
		if(WorldMapQuestShowObjectives:GetChecked()) and WorldMapFrame_UpdateQuests()>0 then
		 		WorldMapFrame_SetQuestMapView();
		end
	end
	

	if(not MetaMap_VarsLoaded) then return; end
	if BattlefieldMinimap and BattlefieldMinimap:IsVisible() then
		if not MetaMap_CombatLockdown_BattlefiedMap then
			MetaMap_Reshow_BattlefiedMap = time()
		else
			MetaMap_CombatLockdown_BattlefiedMap = nil
			MetaMap_Reshow_BattlefiedMap = nil
		end
		BattlefieldMinimap:Hide()
	end
	StaticPopup1:SetFrameStrata("FULLSCREEN");
	if(MetaMap_FullScreenMode) then
		MetaMapNotesEditFrame:SetParent("WorldMapFrame");
		MetaMap_SendFrame:SetParent("WorldMapFrame");
	end
	local _, _, zType = MetaMap_GetZoneTableEntry(GetRealZoneText());
	if(zType == "DN") then
		MetaMapOptions.MetaMapZone = GetRealZoneText();
		MetaMap_ShowInstance(true)
	end
	
	--WorldMapFrame:EnableMouse(false);
	

 
 --ShowWorldMapArrowFrame(0);
	--	PlayerArrowFrame:Hide();
	--	PlayerArrowEffectFrame:Hide();
		
		
end

function MetaMapTopFrame_OnHide()
	MetaMap_HideAll();
	MetaMap_ToggleDR(0);
	StaticPopup1:SetFrameStrata("DIALOG");
	MetaMapNotesEditFrame:SetParent("UIParent");
	MetaMapNotesEditFrame:SetFrameStrata("FULLSCREEN");
	MetaMap_SendFrame:SetParent("UIParent");
	MetaMap_SendFrame:SetFrameStrata("FULLSCREEN");
	SetMapToCurrentZone();
	MetaMapOptions.SaveSet = 1
	--MetaMapOptions_Init()
	if BattlefieldMinimap and MetaMap_Reshow_BattlefiedMap then
		MetaMap_Reshow_BattlefiedMap = nil
		BattlefieldMinimap:Show()
	end
end

function MetaMap_OnEvent(self, event, ...)
	local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11 = ...
	if(event == "ADDON_LOADED" and arg1 == "MetaMap") then
	
	 	
		MetaMap_SetWorldMap();
		for option, value in pairs(MetaMap_Default) do
			if(MetaMapOptions[option] == nil) then MetaMapOptions[option] = value; end
		end
		MetaMap_Default = nil;
		MetaMap_LoadZones();
		UIDropDownMenu_Initialize(MetaMap_MainMenu, MetaMap_MainMenu_Initialize, "MENU");
		UIDropDownMenu_Initialize(MetaMap_InstanceMenu, MetaMap_InstanceMenu_Initialize);
		--- Set the instance menu size
		UIDropDownMenu_SetWidth(MetaMap_InstanceMenu, 65);
	elseif(event == "VARIABLES_LOADED") then
		-- Prevents taint from expanding menus past blizzard's MAXBUTTONS, also fixes an init issue with menus longer than 17.
	    if ( UIDROPDOWNMENU_MAXBUTTONS < 29 ) then
		local toggle;
		 if ( not WorldMapFrame:IsVisible() ) then
			ToggleFrame(WorldMapFrame);
			toggle = true;
		 end
		 SetMapZoom(2);
		 if ( toggle ) then
			ToggleFrame(WorldMapFrame);
		 end
		end
	
	
		MetaMap_CurrentSaveSet = MetaMapOptions.SaveSet;
		if(myAddOnsFrame_Register) then
			myAddOnsFrame_Register(MetaMap_Details);
		end
		if MetaMap_MiniNote_Data.icon == "party" then
			MetaMap_ClearMiniNote(true);
		end
		if MetaMap_MiniNote_Data.icon ~= nil then
			MetaMap_MiniNoteTexture:SetTexture(METAMAP_ICON_PATH.."Icon"..MetaMap_MiniNote_Data.icon);
		end
		MetaMap_CommandsInit();
		MetaMap_OrigWorldMapButton_OnClick = WorldMapButton_OnClick;
		WorldMapButton_OnClick = MetaMap_WorldMapButton_OnClick;
		MetaMap_OrigChatFrame_OnEvent = ChatFrame_MessageEventHandler;
		ChatFrame_MessageEventHandler = MetaMap_ChatFrame_OnEvent;
		MetaMap_MiniNote.TimeSinceLastUpdate = 0;
		for i=0, 9, 1 do
			if(MetaMap_NoteFilter[i] == nil) then MetaMap_NoteFilter[i] = true; end
		end
		if(not MetaMapOptions.MetaMapZone) then
			MetaMapOptions.MetaMapZone = MetaMap_ZoneTable[80][MetaMap_Locale];
		end
		MetaMap_ZoneCapture = nil;
		MetaMapOptions_Init();
		MetaMap_VarsLoaded = true;
	elseif(event == "INSTANCE_MAP_UPDATE" and MetaMapTopFrame:IsVisible()) then
		if(not MetaMap_VarsLoaded) then return; end
		if(IsAddOnLoaded("MetaMapWKB") and WKB_DisplayFrame:IsVisible()) then
			WKB_OnEvent("INSTANCE_MAP_UPDATE");
		elseif(IsAddOnLoaded("MetaMapQST") and QST_DisplayFrame:IsVisible()) then
			QST_OnEvent("INSTANCE_MAP_UPDATE");
		elseif(IsAddOnLoaded("MetaMapTRK") and TRK_DisplayFrame:IsVisible()) then
			TRK_OnEvent("INSTANCE_MAP_UPDATE");
		else
			MetaMapContainer_ShowFrame();
		end
		if(MetaMap_InfoLineFrame:IsVisible()) then MetaMap_InfoLineUpdate(); end
		if(MetaMapFrame:IsVisible()) then MetaMap_Refresh(); end
		MetaMap_MainMapUpdate();
		MetaMap_ZoneSearch();
		MetaMap_HideAll();
		if(MetaMap_PingPOI) then
			MetaMapPing_OnUpdate(1);
		end
	elseif(event == "WORLD_MAP_UPDATE") then
		--MetaMap_Debug_Print("WORLD_MAP_UPDATE:"..GetRealZoneText().." : "..MetaMap_GetCurrentMapInfo(),true);
		if(not MetaMap_VarsLoaded) then return; end
		if(MetaMapOptions.UsePOI) then MetaMapPOI_OnEvent(1); end
		if(not MetaMapTopFrame:IsVisible()) then return; end
		
		local _, _, zType = MetaMap_GetZoneTableEntry(GetRealZoneText());
		local mapName = MetaMap_GetCurrentMapInfo()
		if((zType ~= "DN" and MetaMapFrame:IsVisible())  ) then
			--MetaMap_Debug_Print("WORLD_MAP_UPDATE:ShowInstance(false)",true);
			MetaMap_ShowInstance(false);
		elseif(zType ~= "DNI" and UIDropDownMenu_GetSelectedID(WorldMapContinentDropDown)) then
		    --MetaMap_Debug_Print("WORLD_MAP_UPDATE:ShowInstance(false)",true);
			MetaMapOptions.ShowDNI=false;
			MetaMapOptions.MetaMapZone=nil;
			UIDropDownMenu_ClearAll(MetaMap_InstanceMenu);
		end
		
		
		
	
		if(IsAddOnLoaded("MetaMapWKB") and WKB_DisplayFrame:IsVisible()) then
			WKB_OnEvent("INSTANCE_MAP_UPDATE");
		elseif(IsAddOnLoaded("MetaMapQST") and QST_DisplayFrame:IsVisible()) then
			QST_OnEvent("INSTANCE_MAP_UPDATE");
		elseif(IsAddOnLoaded("MetaMapTRK") and TRK_DisplayFrame:IsVisible()) then
			--- Maintain the display.
		else
			MetaMapContainer_ShowFrame();
		end
		if(MetaMap_InfoLineFrame:IsVisible()) then
			MetaMap_InfoLineUpdate();
		end
		MetaMap_MainMapUpdate();
		MetaMap_ZoneSearch();
		MetaMapOptions_Init();
		if(MetaMap_PingPOI) then
			MetaMapPing_OnUpdate(1);
		end
	elseif(event == "ZONE_CHANGED_NEW_AREA") or (event == "ZONE_CHANGED") then
	  --MetaMap_Debug_Print("Zone_Changed_New_Area",true);
		if(not MetaMap_VarsLoaded) then return; end
		SetMapToCurrentZone();
		MetaMap_MiniNote_OnUpdate(0);
		if(MetaMapOptions.UsePOI) then
			MetaMapPOI_OnEvent(2);
		end
		if(WorldMapFrame:IsVisible()) then
			MetaMap_MainMapUpdate();
		end
		MetaMap_ZoneDisplay:SetText(METAMAP_CURZONE..GetRealZoneText());
		MetaMap_HideAll();
		MetaMap_TimerDelay = 5.0;
	elseif(event == "PLAYER_ENTERING_WORLD") then
		if(not MetaMap_VarsLoaded) then return; end
		local _, _, zType = MetaMap_GetZoneTableEntry(GetRealZoneText());
		if(zType == "DN") then
			MetaMapOptions.MetaMapZone = GetRealZoneText();
			MetaMap_ShowInstance(true)
		end
		MetaMap_ZoneDisplay:SetText(METAMAP_CURZONE..GetRealZoneText());
		MetaMap_TimerDelay = 5.0;
	elseif(event == "MINIMAP_UPDATE_ZOOM") then
		MetaMap_MinimapUpdateZoom();
	elseif(event == "PLAYER_AURAS_CHANGED") then
		MetaMap_SetTrackIcon();
	elseif (event == "CHAT_MSG_ADDON" and arg1 == "MetaMap:MN") then
		MetaMap_GetNoteFromChat(arg2, arg4);
	elseif ( ( event == "QUEST_LOG_UPDATE" or event == "QUEST_POI_UPDATE" ) and self:IsShown() ) then
      WorldMapFrame_DisplayQuests();
      WorldMapQuestFrame_UpdateMouseOver();
    end
end

function MetaMap_ChatFrame_OnEvent(self, event, ...)
	local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12 = ...
	if(event == "CHAT_MSG_WHISPER" and string.find(arg1, "<MetaMap:MN>")) then
		if (arg2 ~= UnitName("player")) then
			MetaMap_GetNoteFromChat(arg1, arg2);
		end
	elseif (event == "CHAT_MSG_WHISPER_INFORM" and string.find(arg1, "<MetaMap:MN>")) then
		--- Discard the return info
	else
		MetaMap_OrigChatFrame_OnEvent(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12);
	end
end

function MetaMap_OnUpdate(self, arg1)
	if(not MetaMap_VarsLoaded) then return; end
	if(MetaMap_TimerDelay and MetaMap_TimerDelay > 0) then
		MetaMap_TimerDelay = MetaMap_TimerDelay - arg1;
	else
		MetaMap_TimerDelay = nil;
	end
	if(MetaMap_ModuleTimer) then
		MetaMap_LoadModules(arg1);
	end
	if(MetaMapOptions.MetaMapMiniCoords) then
		MetaMap_MiniCoordsUpdate();
	end
	if(MetaMapOptions.MetaMapCoords and WorldMapFrame:IsVisible()) then
		MetaMap_MainCoordsUpdate();
	end
	if(MetaMap_MiniNote_Data.xPos) then
		MetaMap_MiniNote_OnUpdate(arg1);
	end
	if(MetaMap_PingPOI) then
		MetaMapPing_OnUpdate();
	end
	


end

function MetaMap_LoadZones()
	if(MetaMap_Notes == nil) then MetaMap_Notes = {}; end
	if(MetaMap_Lines == nil) then MetaMap_Lines = {}; end
	for index, zoneTable in pairs(MetaMap_ZoneTable) do
		if(zoneTable.ztype == "DN" or zoneTable.ztype == "DNI") then
			if(MetaMap_Notes[zoneTable[MetaMap_Locale]] == nil) then
				MetaMap_Notes[zoneTable[MetaMap_Locale]] = {};
			end
			if(MetaMap_Lines[zoneTable[MetaMap_Locale]] == nil) then
				MetaMap_Lines[zoneTable[MetaMap_Locale]] = {};
			end
		elseif(zoneTable.ztype == "BG") then
			if(MetaMap_Notes[zoneTable[MetaMap_Locale]] == nil) then
				MetaMap_Notes[zoneTable[MetaMap_Locale]] = {};
			end
			if(MetaMap_Lines[zoneTable[MetaMap_Locale]] == nil) then
				MetaMap_Lines[zoneTable[MetaMap_Locale]] = {};
			end
		end
	end
	MetaMap_Continents[-1] = "The Cosmos";
	MetaMap_Continents[0] = "Azeroth";
	for cKey, cName in ipairs{GetMapContinents()} do
		MetaMap_Continents[cKey] = cName;
		for zKey, zName in ipairs{GetMapZones(cKey)} do
			if(MetaMap_Notes[zName] == nil) then
				MetaMap_Notes[zName] = {};
			end
			if(MetaMap_Lines[zName] == nil) then
				MetaMap_Lines[zName] = {};
			end
			MetaMap_ZoneTableUpdate(zName);
		end
	end
end

function MetaMap_ZoneTableUpdate(zoneName)
	local found = false;
	for index, zoneTable in pairs(MetaMap_ZoneTable) do
		if(zoneTable.ztype == "SZ" and zoneTable[MetaMap_Locale] == zoneName) then
			found = true; break;
		end
	end
	if(not found) then
		local index = #(MetaMap_ZoneTable) + 50; --fixme!
		MetaMap_ZoneTable[index] = {ztype = "SZ", en = zoneName, de = zoneName, fr = zoneName, es = zoneName, ru = zoneName, llvl = 0, hlvl = 0, faction = "Unknown", scale = 0, xoffset = 0, yoffset = 0};
	end
end

function MetaMap_NameToZoneID(zoneText)
	local _, _, zType, mapid = MetaMap_GetZoneTableEntry(zoneText);
	if(zType == "DNI") or (zType == "BG") then
	 --MetaMap_Debug_Print("NameToZoneID(DNI):"..zoneText.." id:"..mapid,true);
	 return -1, mapid
	else

	for cKey, cName in ipairs{GetMapContinents()} do
		for zKey,zName in ipairs{GetMapZones(cKey)} do
		    
			if(zoneText == zName) then
				return cKey, zKey;
			end
		end
	end
	for index, cName in pairs(MetaMap_Continents) do
		if(zoneText == cName) then
			return index, 0;
		end
	end
	return -1, zoneText;
	end
end

function MetaMap_ZoneIDToName(continentKey, zoneKey)
	for index, zoneTable in pairs(MetaMap_ZoneTable) do
		if((zoneTable.ztype == "BG") or (zoneTable.ztype == "DNI")) then
			if(zoneTable[MetaMap_Locale] == GetRealZoneText() and continentKey == -1 and zoneKey == 0) then
				return zoneTable[MetaMap_Locale];
			end
		end
	end
	for index, cName in pairs(MetaMap_Continents) do
		if(continentKey == index and zoneKey == 0) then
			return cName;
		end
	end
	for zKey, zName in ipairs{GetMapZones(continentKey)} do
		if(zKey == zoneKey) then
			return zName;
		end
	end
	return zoneKey;
end

function MetaMap_GetCurrentMapInfo()
	local mapName, dataZone;
	
	if(MetaMapFrame:IsVisible() or MetaMapOptions.ShowDNI) then
		mapName = MetaMapOptions.MetaMapZone;
	else
		mapName = MetaMap_ZoneIDToName(GetCurrentMapContinent(), GetCurrentMapZone());
	end
	return mapName, MetaMap_Notes[mapName];
end

function MetaMap_GetZoneTableEntry(zoneName)
 --MetaMap_Debug_Print("GetZoneTableEntry: " ..zoneName,true);
  local mapid =0;
	for index, zoneTable in pairs(MetaMap_ZoneTable) do
		if(zoneTable.en == zoneName or zoneTable.de == zoneName or zoneTable.fr == zoneName or zoneTable.es == zoneName or zoneTable.ru == zoneName) then
		    if(zoneTable.mapid ~= nil) then
			  mapid = zoneTable.mapid
			end
		
			return zoneTable[MetaMap_Locale], index, zoneTable.ztype,mapid ;
		end
	end
end

function MetaMap_CheckValidZone(zoneName)
	local _, _, zType = MetaMap_GetZoneTableEntry(zoneName)
	if(zType == "BG" or zType == "DN" or zType == "DNI") then
		return true;
	end
	for cKey, cName in pairs{GetMapContinents()} do
		for zKey, zName in ipairs{GetMapZones(cKey)} do
			if(zName == zoneName) then
				return true;
			end
		end
	end
	return false;
end

function MetaMap_CheckRelatedZone(zoneName, mapName)
	local related = false;
	local continent = MetaMap_NameToZoneID(zoneName);
	local _, zIndex, zType = MetaMap_GetZoneTableEntry(zoneName)
	if(zType == "DN") then
		continent = MetaMap_ZoneTable[zIndex].Continent;
		if(MetaMap_ZoneTable[zIndex].Location == mapName) then related = true; end
	end
	if(zoneName == mapName) then related = true;
	elseif(MetaMap_Continents[-1] == mapName) then related = true; --"The Cosmos"
	elseif(MetaMap_Continents[continent or ""] == mapName) then related = true;
	elseif(MetaMap_Continents[0] == mapName and continent and (continent == 1 or continent == 2 or continent == 3)) then related = true; end
	return related;
end

function MetaMap_ZoneCheckButton_OnClick()
	local errata = "";
	if(MetaMap_Orphans == 0) then
		MetaMap_LoadWKB(3);
		MetaMap_LoadTRK(2);
		MetaMap_LoadQST(2);
		errata = MetaMap_CheckZones();
		if(MetaMap_Orphans > 0) then
			MetaMap_ZoneShiftDisplay:Show();
			MetaMap_ZoneCheckButton:SetText(METAMAP_ZONEMOVE_BUTTON);
			MetaMap_OptionsInfo:SetText(METAMAP_ZONE_ERROR..errata);
			for zone, value in pairs(MetaMap_ZoneErrata) do
				MetaMap_OrphanFrameText:SetText(zone);
				MetaMap_OrphanText1:SetText(format(METAMAP_ORPHAN_TEXT1, 1, MetaMap_Orphans));
				break;
			end
		else
			MetaMap_ZoneShiftDisplay:Hide();
			MetaMap_OptionsInfo:SetText(METAMAP_ZONE_NOSHIFT);
			MetaMap_ZoneCheckButton:SetText(METAMAP_ZONECHECK_BUTTON);
		end
	elseif(MetaMap_Orphans > 0) then
		MetaMap_ShiftZones();
		if(MetaMap_Orphans > 0) then
			MetaMap_ZoneShiftDisplay:Show();
			MetaMap_ZoneCheckButton:SetText(METAMAP_ZONEMOVE_BUTTON);
			for zone, value in pairs(MetaMap_ZoneErrata) do
				MetaMap_OrphanFrameText:SetText(zone);
				MetaMap_OrphanText1:SetText(format(METAMAP_ORPHAN_TEXT1, 1, MetaMap_Orphans));
				break;
			end
		else
			MetaMap_ZoneShiftDisplay:Hide();
			MetaMap_OptionsInfo:SetText(METAMAP_ZONE_NOSHIFT);
			MetaMap_ZoneCheckButton:SetText(METAMAP_ZONECHECK_BUTTON);
		end
	end
	MetaMap_ZoneCheckButton:Disable();
end

function MetaMap_CheckZones()
	MetaMap_ZoneErrata = {};
	local found = "|cffff0000\n\n";
	for zone, indexTable in pairs(MetaMap_Notes) do
		if(not MetaMap_CheckValidZone(zone)) then
			if(not MetaMap_ZoneErrata[zone]) then
				MetaMap_ZoneErrata[zone] = true;
			end
			found = found.."MetaMap";
		end
	end
	if(WKB_Data) then
		for zone, indexTable in pairs(WKB_Data) do
			if(not MetaMap_CheckValidZone(zone)) then
				if(not MetaMap_ZoneErrata[zone]) then
					MetaMap_ZoneErrata[zone] = true;
				end
				found = found.." - MetaMapWKB";
			end
		end
	end
	if(TRK_Data) then
		for zone, indexTable in pairs(TRK_Data) do
			if(not MetaMap_CheckValidZone(zone)) then
				if(not MetaMap_ZoneErrata[zone]) then
					MetaMap_ZoneErrata[zone] = true;
				end
				found = found.." - MetaMapTRK";
			end
		end
	end
	if(QST_QuestLog) then
		for index, value in ipairs(QST_QuestLog) do
			if(value.qArea and value.qArea ~= "Unknown") then
				if(not MetaMap_CheckValidZone(value.qArea)) then
					if(not MetaMap_ZoneErrata[value.qArea]) then
						MetaMap_ZoneErrata[value.qArea] = true;
					end
					found = found.." - MetaMapQSTlog";
				end
			end
		end
		for index, value in ipairs(QST_QuestBase) do
			if(value.qArea) then
				if(value.qArea ~= "Unknown" and not MetaMap_CheckValidZone(value.qArea)) then
					if(not MetaMap_ZoneErrata[value.qArea]) then
						MetaMap_ZoneErrata[value.qArea] = true;
					end
					found = found.." - MetaMapQSTbase";
				end
			elseif(not MetaMap_CheckValidZone(value.qZone)) then
				if(not MetaMap_ZoneErrata[value.qZone]) then
					MetaMap_ZoneErrata[value.qZone] = true;
				end
				found = found.." - MetaMapQSTbase";
			end
		end
	end
	for zone, value in pairs(MetaMap_ZoneErrata) do
		MetaMap_Orphans = MetaMap_Orphans +1;
	end
	return found;
end

function MetaMap_ShiftZones()
	local oldZone = MetaMap_OrphanFrameText:GetText();
	local newZone = UIDropDownMenu_GetText(MetaMap_ZoneCheckMenu);
	if(MetaMap_Notes[oldZone]) then
		for index, value in ipairs(MetaMap_Notes[oldZone]) do
			local noteAdded = MetaMap_SetNewNote(newZone, value.xPos, value.yPos, value.name, value.inf1, value.inf2, value.creator, value.icon, value.ncol, value.in1c, value.in2c)
			if(noteAdded and MetaMap_Lines[oldZone]) then
				for i, lines in ipairs(MetaMap_Lines[oldZone]) do
					if(lines.x1 == value.xPos and lines.y1 == value.yPos) then
						MetaMap_ToggleLine(newZone, lines.x1, lines.y1, lines.x2, lines[i].y2)
					end
				end
			end
		end
		MetaMap_Notes[oldZone] = nil;
		MetaMap_Lines[oldZone] = nil;
	end
	if(WKB_Data and WKB_Data[oldZone]) then
		if(not WKB_Data[newZone]) then WKB_Data[newZone] = {}; end
		for unit, value in pairs(WKB_Data[oldZone]) do
			WKB_Data[newZone][unit] = value;
		end
		WKB_Data[oldZone] = nil;
	end
	if(TRK_Data and TRK_Data[oldZone]) then
		if(not TRK_Data[newZone]) then TRK_Data[newZone] = {}; end
		for index, value in ipairs(TRK_Data[oldZone]) do
			TRK_Data[newZone][index] = value;
		end
		TRK_Data[oldZone] = nil;
	end
	if(QST_QuestLog) then
		for index, value in ipairs(QST_QuestLog) do
			if(value.qArea == oldZone) then
				value.qArea = newZone;
			end
			if(value.qNPC[1] and value.qNPC[1].qZone == oldZone) then
				value.qNPC[1].qZone = newZone;
			end
			if(value.qNPC[2] and value.qNPC[2].qZone == oldZone) then
				value.qNPC[2].qZone = newZone;
			end
		end
	end
	if(QST_QuestBase) then
		for index, value in ipairs(QST_QuestBase) do
			if(value.qArea == oldZone) then
				value.qArea = newZone;
			elseif(value.qZone == oldZone) then
				value.qZone = newZone;
			end
			if(value.qNPC[1] and value.qNPC[1].qZone == oldZone) then
				value.qNPC[1].qZone = newZone;
			end
			if(value.qNPC[2] and value.qNPC[2].qZone == oldZone) then
				value.qNPC[2].qZone = newZone;
			end
		end
	end
	MetaMap_ZoneErrata[oldZone] = nil;
	MetaMap_Orphans = MetaMap_Orphans -1;
	if(MetaMap_Orphans == 0) then MetaMap_ZoneErrata = nil; end
	MetaMap_OptionsInfo:SetText(format(METAMAP_ZONE_SHIFTED, oldZone, newZone));
	UIDropDownMenu_SetText(MetaMap_ZoneCheckMenu, "");
end

-- function MetaMap_ToggleFrame(frame)
	-- if frame:IsVisible() then
		-- HideUIPanel(frame);
	-- else
		-- ShowUIPanel(frame);
	-- end
-- end

local UseBattlefieldMiniMapInCombat = true --use Battlefield minimap during combat lockdown
local MetaMap_CombatLockdown_BattlefiedMap = nil

function MetaMap_ToggleFrame(frame)
   if(frame==nil)then
     frame=WorldMapFrame
	end

	MetaMap_Debug_Print("MetaMap: MetaMap_ToggleFrame("..tostring(frame)..")")
	if UseBattlefieldMiniMapInCombat and InCombatLockdown() and frame == WorldMapFrame then --combat lockdown
		if not BattlefieldMinimap then BattlefieldMinimap_LoadUI() end
		if BattlefieldMinimap and BattlefieldMinimap:IsVisible() then
			if MetaMap_CombatLockdown_BattlefiedMap then --wasn't on before combat
				BattlefieldMinimap:Hide()
				-- MetaMap_Reshow_BattlefiedMap = true
			end
			MetaMap_CombatLockdown_BattlefiedMap = nil
		elseif BattlefieldMinimap then
			MetaMap_CombatLockdown_BattlefiedMap = true
			BattlefieldMinimap:Show()
		end
	elseif MetaMap_CombatLockdown_BattlefiedMap and frame == WorldMapFrame then
		MetaMap_CombatLockdown_BattlefiedMap = nil
		BattlefieldMinimap:Hide()
	end
	if frame:IsVisible() then
		HideUIPanel(frame);
	else
		ShowUIPanel(frame);
	end
end


function MetaMapContainer_ShowFrame(frame, header, footer, info)
	if(frame == nil) then
		if(MetaMapContainer_CurrentFrame) then
			MetaMapContainer_CurrentFrame:Hide();
		end
		MetaMapContainerFrame:Hide();
		return;
	end
	if(MetaMapContainer_CurrentFrame) then
		MetaMapContainer_CurrentFrame:Hide();
	end
	if(header ~= nil) then
		MetaMapContainer_HeaderText:SetText(header);
		MetaMapContainer_HeaderText:Show();
	else
		MetaMapContainer_HeaderText:Hide();
	end
	if(footer ~= nil) then
		MetaMapContainer_FooterText:SetText(footer);
		MetaMapContainer_FooterText:Show();
	else
		MetaMapContainer_FooterText:Hide();
	end
	if(info ~= nil) then
		MetaMapContainer_InfoText:SetText(info);
		MetaMapContainer_InfoText:Show();
	else
		MetaMapContainer_InfoText:Hide();
	end
	if(MetaMapContainer_CurrentFrame ~= nil) then
		MetaMapContainer_CurrentFrame:Hide();
	end
	MetaMapContainer_CurrentFrame = frame;
	MetaMapContainer_CurrentFrame:Show();
	MetaMapContainerFrame:Show();
	frame:SetAlpha(MetaMapContainerFrame:GetAlpha());
end

function MetaMap_LoadModules(elapsed)
	if(MetaMap_ModuleTimer > 0) then
		MetaMap_ModuleTimer = MetaMap_ModuleTimer - elapsed;
	else
		if(MetaMapOptions.NBKalwaysOn) then MetaMap_LoadNBK(1); end
		if(MetaMapOptions.WKBalwaysOn) then MetaMap_LoadWKB(3); end
		if(MetaMapOptions.BWPalwaysOn) then MetaMap_LoadBWP(0, 3); end
		if(MetaMapOptions.FWMalwaysOn) then MetaMap_LoadFWM(); end
		if(MetaMapOptions.QSTalwaysOn) then MetaMap_LoadQST(2); end
		if(MetaMapOptions.TRKalwaysOn) then MetaMap_LoadTRK(2); end
		MetaMap_ModuleTimer = nil;
	end
end

function MetaMap_LoadHLP()
	if(not IsAddOnLoaded("MetaMapHLP")) then
		LoadAddOn("MetaMapHLP");
	end
	if(IsAddOnLoaded("MetaMapHLP")) then
		MetaMap_LoadHLPButton:Hide();
		return true;
	else
		MetaMap_OptionsInfo:SetText("MetaMapHLP "..METAMAP_NOMODULE);
	end
end

function MetaMap_LoadCVT()
	if(not IsAddOnLoaded("MetaMapCVT")) then
		LoadAddOn("MetaMapCVT");
	end
	if(IsAddOnLoaded("MetaMapCVT")) then
		MetaMapCVT_CheckData();
	else
		MetaMap_OptionsInfo:SetText("MetaMapCVT "..METAMAP_NOMODULE);
	end
end

function MetaMap_LoadEXP()
	if(not IsAddOnLoaded("MetaMapEXP")) then
		LoadAddOn("MetaMapEXP");
	end
	if(IsAddOnLoaded("MetaMapEXP")) then
		EXP_CheckData();
	else
		MetaMap_OptionsInfo:SetText("MetaMapEXP "..METAMAP_NOMODULE);
	end
end

function MetaMap_LoadBKP()
	if(not IsAddOnLoaded("MetaMapBKP")) then
		LoadAddOn("MetaMapBKP");
	end
	if(IsAddOnLoaded("MetaMapBKP")) then
		BKP_BackUpFrame:Show();
	else
		if MetaMap_LoadBKP then MetaMap_LoadBKP:Disable() end;
		if(MetaMap_GeneralDialog:IsVisible()) then
			MetaMap_OptionsInfo:SetText("MetaMapBKP "..METAMAP_NOMODULE);
		else
			MetaMap_Print("MetaMapBKP "..METAMAP_NOMODULE, true);
		end
	end
end

function MetaMap_LoadBLT(lootID, Name)
	if(not IsAddOnLoaded("MetaMapBLT")) then
		LoadAddOn("MetaMapBLT");
	end
	if(IsAddOnLoaded("MetaMapBLT")) then
		MetaMapBLT_ClassMenu:Hide();
		MetaMapBLT_OnSelect(lootID, Name);
	else
		MetaMap_Print("MetaMapBLT "..METAMAP_NOMODULE, true);
	end
end
	
function MetaMap_LoadBWP(id, mode)
	if(not IsAddOnLoaded("MetaMapBWP")) then
		LoadAddOn("MetaMapBWP");
	end
	if(IsAddOnLoaded("MetaMapBWP")) then
		if(mode == nil) then
			MetaMapBWPMenu_Init();
		elseif(mode == 1) then
			MetaKBMenu_RBSelect(id);
		elseif(mode == 2) then
			MetaMapNotes_RBSelect(id);
		end
	else
		MetaMap_Print("MetaMapBWP "..METAMAP_NOMODULE, true);
	end
end

function MetaMap_LoadWKB(mode)
	if(not IsAddOnLoaded("MetaMapWKB")) then
		LoadAddOn("MetaMapWKB");
	end
	if(IsAddOnLoaded("MetaMapWKB")) then
		if(mode == nil or mode == 1) then
			WKB_ToggleFrame(mode);
		elseif(mode == 2) then
			WKB_UpdateKeySelectedUnit();
		end
	else
		MetaMap_Print("MetaMapWKB "..METAMAP_NOMODULE, true);
	end
end

function MetaMap_LoadQST(mode)
	if(not IsAddOnLoaded("MetaMapQST")) then
		LoadAddOn("MetaMapQST");
	end
	if(IsAddOnLoaded("MetaMapQST")) then
		QST_ToggleFrame(mode);
	else
		MetaMap_Print("MetaMapQST "..METAMAP_NOMODULE, true);
	end
end

function MetaMap_LoadNBK(mode)
	if(not IsAddOnLoaded("MetaMapNBK")) then
		LoadAddOn("MetaMapNBK");
	end
	if(IsAddOnLoaded("MetaMapNBK")) then
		if(not mode) then
			MetaMap_ToggleFrame(NBK_NoteBookFrame);
		end
		return true;
	else
		MetaMap_Print("MetaMapNBK "..METAMAP_NOMODULE, true);
		return false;
	end
end

function MetaMap_LoadTRK(mode)
	if(not IsAddOnLoaded("MetaMapTRK")) then
		LoadAddOn("MetaMapTRK");
	end
	if(IsAddOnLoaded("MetaMapTRK")) then
		TRK_ToggleFrame(mode);
		return true;
	else
		MetaMap_Print("MetaMapTRK "..METAMAP_NOMODULE, true);
		return false;
	end
end

function MetaMap_LoadFWM(mode)
	if(not IsAddOnLoaded("MetaMapFWM")) then
		LoadAddOn("MetaMapFWM");
	end
	if(IsAddOnLoaded("MetaMapFWM")) then
		if(mode == nil) then
			FWM_ShowUnexplored = not FWM_ShowUnexplored;
		else
			FWM_ShowUnexplored = true;
		end 
		WorldMapFrame_Update();
	else
		if(MetaMap_ModulesDialog:IsVisible()) then
			MetaMap_OptionsInfo:SetText("MetaMapFWM "..METAMAP_NOMODULE);
		else
			MetaMap_Print("MetaMapFWM "..METAMAP_NOMODULE, true);
		end
	end
end

---  #### Init the tracker activation
function MetaMap_SetTracker()
	if(not MetaMapOptions.MetaMapTracker) then
		MetaMap_LoadTRK(2);
		if(MetaMap_GetSpell("Find Herbs")) then
			CastSpellByName("Find Herbs");
		elseif(MetaMap_GetSpell("Find Minerals")) then
			CastSpellByName("Find Minerals");
		end
	else
		---CancelTrackingBuff();
	end
end

function MetaMap_SetTrackIcon()
	if(not MetaMapOptions.TrackerIcon) then return; end
	local iconTexture = GetTrackingTexture();
	if(iconTexture) then
		getglobal("MetaMapButtonIcon"):SetTexture(iconTexture);
		if(IsAddOnLoaded("FuBar")) then
			MetaMapFu:SetIcon(iconTexture);
		end
		if(IsAddOnLoaded("Titan")) then
			TitanPanelMetaMapButton.registry.icon = iconTexture;
			MiniMapTracking:Hide();
		end
		MetaMapOptions.MetaMapTracker = true;
	else
		getglobal("MetaMapButtonIcon"):SetTexture(METAMAP_ICON);
		if(IsAddOnLoaded("Titan")) then
			TitanPanelMetaMapButton.registry.icon = METAMAP_ICON;
		end
		if(IsAddOnLoaded("FuBar")) then
			MetaMapFu:SetIcon(METAMAP_ICON);
		end
		MetaMapOptions.MetaMapTracker = false;
	end
end

function MetaMap_GetSpell(name)
	local index = 1; local spellName = "";
	while spellName do
		spellName = GetSpellName(index, BOOKTYPE_SPELL);
		if(name == spellName) then return index; end
		index = index + 1;
	end
end

function MetaMap_CommandsInit()
	SlashCmdList["MAPNOTE"] = MetaMap_GetNoteBySlashCommand;
	for i = 1, #(METAMAP_ENABLE_COMMANDS) do
		setglobal("SLASH_MAPNOTE"..i, METAMAP_ENABLE_COMMANDS[i]);
	end
	SlashCmdList["MININOTE"] = MetaMap_NextMiniNote;
	for i = 1, #(METAMAP_MININOTE_COMMANDS) do
		setglobal("SLASH_MININOTE"..i, METAMAP_MININOTE_COMMANDS[i]);
	end
	SlashCmdList["MININOTEONLY"] = MetaMap_NextMiniNoteOnly;
	for i = 1, #(METAMAP_MININOTEONLY_COMMANDS) do
		setglobal("SLASH_MININOTEONLY"..i, METAMAP_MININOTEONLY_COMMANDS[i]);
	end
	SlashCmdList["MININOTEOFF"] = MetaMap_ClearMiniNote;
	for i = 1, #(METAMAP_MININOTEOFF_COMMANDS) do
		setglobal("SLASH_MININOTEOFF"..i, METAMAP_MININOTEOFF_COMMANDS[i]);
	end
	SlashCmdList["QUICKNOTE"] = MetaMap_Quicknote;
	for i = 1, #(METAMAP_QUICKNOTE_COMMANDS) do
		setglobal("SLASH_QUICKNOTE"..i, METAMAP_QUICKNOTE_COMMANDS[i]);
	end
end

function MetaMap_FullScreenToggle()
	local mMap = false;
	local continent = GetCurrentMapContinent();
	local zone = GetCurrentMapZone();
	if(MetaMapFrame:IsVisible()) then
		MetaMapShown = true;
	end
	if(MetaMap_FullScreenMode) then
		WorldMapFrame:SetScript("OnKeyDown", nil);
		WorldMapFrame:SetScript("OnKeyUp", nil);
		UIPanelWindows["WorldMapFrame"] =	{ area = "center",	pushable = 9 };
		MetaMap_FullScreenMode = false;
		BlackoutWorld:Hide();
		if(WorldMapFrame:IsVisible()) then
			CloseAllWindows();
			ShowUIPanel(WorldMapFrame);
		end
		MetaMapOptions_Init();
	else
		WorldMapFrame:SetScale(1.0);
		WorldMapFrame:SetScript("OnKeyDown", WMF_OldScript);
		WorldMapFrame:SetScript("OnKeyUp", function(self, arg1) if(arg1	== GetBindingKey("METAMAP_FSTOGGLE") or	arg1 ==	GetBindingKey("METAMAP_SAVESET"))	then MetaMap_FullScreenToggle(); end end);
		UIPanelWindows["WorldMapFrame"] =	{ area = "full",	pushable = 0 };
		BlackoutWorld:Show();
		MetaMap_FullScreenMode = true;
		if(WorldMapFrame:IsVisible()) then
			CloseAllWindows();
			ShowUIPanel(WorldMapFrame);
		end
	end
	SetMapZoom(continent, zone);
	if(MetaMapShown) then MetaMap_ShowInstance(true); end
end

function MetaMap_ShowInstance(show)
   
    --MetaMap_Debug_Print("ShowInstance-start:".. MetaMapOptions.MetaMapZone,true);
    local _, _, zType = MetaMap_GetZoneTableEntry( MetaMapOptions.MetaMapZone);
	
	MetaMapOptions.ShowDNI = show;
	
	if (zType == "DNI") or (zType == "BG") then
		
	   	HideUIPanel(MetaMapFrame);
		ShowUIPanel(WorldMapDetailFrame);
		ShowUIPanel(WorldMapButton);
		ShowWorldMapArrowFrame(1);
	    --MetaMap_Debug_Print("ShowInstance-DNI/BG",true);
   	
		local _,instance =MetaMap_NameToZoneID(MetaMapOptions.MetaMapZone);
		--SetMapZoom(-1,"Cosmos");
		--MetaMap_Debug_Print("ShowInstance-about to SetMAp",true);
	    SetMapByID(instance);
	    
		 --MetaMap_Debug_Print("ResetingShowObj",true);
		 --WorldMapFrame.bigMap = true;
 		 --WorldMapFrame_AdjustMapAndQuestList();
		
		 if(WorldMapQuestShowObjectives:GetChecked()) and WorldMapFrame_UpdateQuests()>0 then
		 		WorldMapFrame_SetQuestMapView();
		 end
		
		WorldMapQuestShowObjectives:Show();
		
		UIDropDownMenu_ClearAll(WorldMapContinentDropDown);
		UIDropDownMenu_ClearAll(WorldMapZoneDropDown);
	else
	
	   if(show) then
		ShowUIPanel(MetaMapFrame);
		MetaMapFrame:SetPoint("BOTTOMRIGHT",WorldMapPOIFrame, "BOTTOMRIGHT", 0, 0);
		HideUIPanel(WorldMapDetailFrame);
		HideUIPanel(WorldMapButton);
		ShowWorldMapArrowFrame(0);
		WorldMapFrame_SetFullMapView();
		WorldMapBlobFrame:Hide();
		WorldMapPOIFrame:Hide();
		WorldMapTrackQuest:Hide();
		WorldMapQuestShowObjectives:Hide();
		
		UIDropDownMenu_ClearAll(WorldMapContinentDropDown);
		UIDropDownMenu_ClearAll(WorldMapZoneDropDown);
	   else
	      --MetaMap_Debug_Print("ShowInstance-hide:".. MetaMapOptions.MetaMapZone,true);
		  
		   UIDropDownMenu_ClearAll(MetaMap_InstanceMenu);
		   MetaMapOptions.MetaMapZone = nil;
		HideUIPanel(MetaMapFrame);
		ShowUIPanel(WorldMapDetailFrame);
		ShowUIPanel(WorldMapButton);
		ShowWorldMapArrowFrame(1);
		WorldMapQuestShowObjectives_Toggle();
		if(WorldMapQuestShowObjectives:GetChecked()) and WorldMapFrame_UpdateQuests()>0 then
		 		WorldMapFrame_SetQuestMapView();
		end
		WorldMapQuestShowObjectives:Show();
		
	   end
	   MetaMap_OnEvent(this, "INSTANCE_MAP_UPDATE");
	end

	
end

function MetaMap_MiniCoordsUpdate()
	if(WorldMapFrame:IsVisible()) then MetaMap_MainCoordsUpdate(); return; end
	local px, py = GetPlayerMapPosition("player");
	if(px == 0 and py == 0) then
		local _, _, zType = MetaMap_GetZoneTableEntry(GetRealZoneText());
		if(zType == "DN") then
			MetaMapMiniCoords:SetText(METAMAP_INSTANCE);
		else
			MetaMapMiniCoords:SetText("Dead Zone");
		end
	else
		MetaMapMiniCoords:SetText(format("%d, %d", px * 100, py * 100));
	end

end

-- Sets coords at the bottom of the map
function MetaMap_MainCoordsUpdate()
	--local x, y = GetCursorPosition();
	local px, py = GetPlayerMapPosition("player");
	
	--local OFFSET_X = 0.0022;
	--local OFFSET_Y = -0.0262;
	local OFFSET_X = 0;
	local OFFSET_Y = 0;
	--local centerX, centerY = WorldMapFrame:GetCenter();
	--local width = WorldMapButton:GetWidth();
	--local height = WorldMapButton:GetHeight();
	--x = x / WorldMapFrame:GetEffectiveScale();
	--y = y / WorldMapFrame:GetEffectiveScale();
	
	--if(centerX == nil) then
	--	centerX = 0;
	--end
	
	--if(centerY == nil) then
	--	centerY = 0;
	--end
	
	--local adjustedX = (x - (centerX - (width/2))) / width;
	--local adjustedY = (centerY + (height/2) - y ) / height;
	--x = 100 * (adjustedX + OFFSET_X);
	--y = 100 * (adjustedY + OFFSET_Y);
	
			local centerX, centerY = WorldMapButton:GetCenter()
			local width = WorldMapButton:GetWidth()
			local height = WorldMapButton:GetHeight()
			local x, y = GetCursorPosition()
			x = x / WorldMapButton:GetEffectiveScale()
			y = y / WorldMapButton:GetEffectiveScale()
			
			if(centerX == nil) then
				centerX = 0;
			end
	
			if(centerY == nil) then
				centerY = 0;
			end
			
			local adjustedY = (centerY + height/2 - y) / height
			local adjustedX = (x - (centerX - width/2)) / width
			x = 100 * (adjustedX + OFFSET_X);
			y = 100 * (adjustedY + OFFSET_Y);
	       
	--MetaMap_Debug_Print("MainCoordsUpdate"..format("%d, %d", x, y),true);
	
	
	if(x < 0 or y < 0 or x > 100 or y > 100) then
		MetaMapCoordsCursor:SetText("");
	else
		MetaMapCoordsCursor:SetText("|cffffffff"..format("%d, %d", x, y));
	end
	if(MetaMapFrame:IsVisible()) then
		MetaMapCoordsPlayer:SetText(METAMAP_INSTANCE_1);
	elseif(px == 0 and py == 0) then
		local _, _, zType = MetaMap_GetZoneTableEntry(GetRealZoneText());
		local continent, zone = MetaMap_NameToZoneID(GetRealZoneText());
		if(zType == "DN") then
			MetaMapCoordsPlayer:SetText(METAMAP_INSTANCE_1);
		elseif(GetCurrentMapContinent() ~= continent or GetCurrentMapZone() ~= zone) then
			MetaMapCoordsPlayer:SetText("");
		else
			MetaMapCoordsPlayer:SetText("|cff00ff00Dead Zone");
		end
	else
		MetaMapCoordsPlayer:SetText("|cff00ff00"..format("%d, %d", px * 100, py * 100));
	end
	MetaMapCoordsPlayer:Show()
	MetaMapCoordsCursor:Show()
end

function MetaMap_UpdateBackDrop()
	--MetaMap_Debug_Print("UpdateBackDrop",true);
	

	
	
	if(MetaMapOptions.SaveSet == 1) then
		MetaMapOptions.BDshader1 = MetaMap_BackDropSlider:GetValue();
		MetaMap_MapBackDrop:SetAlpha(MetaMapOptions.BDshader1);
	else
		MetaMapOptions.BDshader2 = MetaMap_BackDropSlider:GetValue();
		MetaMap_MapBackDrop:SetAlpha(MetaMapOptions.BDshader2);
	end
	MetaMap_MapBackDrop:SetWidth(MetaMapFrame:GetWidth());
	MetaMap_MapBackDrop:SetHeight(MetaMapFrame:GetHeight());
	MetaMap_MapBackDrop:SetTexture(METAMAP_SHADER_PATH.."Shader"..MetaMap_CurrentShadeSet);
	
	--Interface\AddOns\MetaMap\Shaders\Shader1
	--Interface/Tooltips/UI-Tooltip-Background
	--bgFile = "Interface/Tooltips/UI-Tooltip-Background"
	
	MetaMapFrame:SetBackdrop({bgFile = "Interface\\Addons\\MetaMap\\Images\\instancebk", 
                                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
                                            tile = true, tileSize = 16, edgeSize = 16, 
                                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});
	MetaMapFrame:SetBackdropColor(1,1,1,1);
	
end

function MetaMap_UpdateAlpha()
	if(MetaMapOptions.SaveSet == 1) then
		MetaMapOptions.MetaMapAlpha1 = MetaMapAlphaSlider:GetValue();
		WorldMapFrame:SetAlpha(MetaMapOptions.MetaMapAlpha1);
	else
		MetaMapOptions.MetaMapAlpha2 = MetaMapAlphaSlider:GetValue();
		WorldMapFrame:SetAlpha(MetaMapOptions.MetaMapAlpha2);
	end
	MetaMap_MainCoords:SetAlpha(MetaMapAlphaSlider:GetValue() + 0.2);
	WorldMapButton:SetAlpha(MetaMapAlphaSlider:GetValue() + 0.2);
end

function MetaMap_UpdateScale()
	MetaMap_Debug_Print("MetaMap_UpdateScale",true);
	if(not MetaMap_FullScreenMode) then
		MetaMap_Debug_Print("MetaMap_UpdateScale-NoFullScreen",true);
		if(MetaMapOptions.SaveSet == 1) then
			MetaMapOptions.MetaMapScale1 = MetaMapScaleSlider:GetValue();
			SetEffectiveScale(WorldMapFrame, MetaMapOptions.MetaMapScale1);
		else
			MetaMapOptions.MetaMapScale2 = MetaMapScaleSlider:GetValue();
			SetEffectiveScale(WorldMapFrame, MetaMapOptions.MetaMapScale2);
		end
		
		MetaMapTopFrame:SetWidth(WorldMapButton:GetWidth());
		MetaMapTopFrame:SetHeight(WorldMapButton:GetHeight());
		

		
		WorldMapFrame:SetWidth(WorldMapPositioningGuide:GetWidth());
		WorldMapFrame:SetHeight(WorldMapPositioningGuide:GetHeight());
		
	

	    WorldMapFrame_UpdateQuests()
		--WorldMapFrame_SetPOIMaxBounds()
	    WorldMapQuestShowObjectives_AdjustPosition()
		
		MetaMap_SetPointerSize()
		
	end
end


function MetaMap_SetPointerSize()

  --MetaMap_Debug_Print("SetPointerSize",true);
			if (WorldMapQuestScrollFrame:IsVisible()) then
			  PlayerArrowFrame:SetModelScale(.75);
			  PlayerArrowEffectFrame:SetModelScale(.75);
			 
			else
			  PlayerArrowFrame:SetModelScale(1.0);
			  PlayerArrowEffectFrame:SetModelScale(1.0);
			 
			end
end


function MetaMap_UpdateTTScale()
	if(MetaMapOptions.SaveSet == 1) then
		MetaMapOptions.MetaMapTTScale1 = MetaMapTTScaleSlider:GetValue();
		WorldMapTooltip:SetScale(MetaMapOptions.MetaMapTTScale1);
	else
		MetaMapOptions.MetaMapTTScale2 = MetaMapTTScaleSlider:GetValue();
		WorldMapTooltip:SetScale(MetaMapOptions.MetaMapTTScale2);
	end
end

function MetaMap_Refresh()
	local zName, zIndex = MetaMap_GetZoneTableEntry(MetaMapOptions.MetaMapZone);
	MetaMap_MapImage:SetTexture(METAMAP_MAP_PATH..MetaMap_ZoneTable[zIndex]["texture"]);
	MetaMapText_Instance:SetText("|cffffffff"..zName);
	MetaMap_MainMapUpdate();
end

function MetaMap_InstanceMenu_Initialize()
    --MetaMap_Debug_Print("MetaMap_InstanceMenu_Initialize",true);
	if(UIDROPDOWNMENU_MENU_LEVEL == 2) then
		local menuVal = MetaMap_SubMenuFix();
		local menuList = {};
		for index, value in pairs(MetaMap_ZoneTable) do
			if((value.ztype == "DN" or value.ztype == "DNI" ) and value.Continent == menuVal) then
				table.insert(menuList, {location = value[MetaMap_Locale]});
			end
		end
		local sort = MetaMap_sortType;
		MetaMap_sortType = METAMAP_SORTBY_LOCATION;
		table.sort(menuList, MetaMap_SortCriteria);
		MetaMap_sortType = sort;
		for zKey, zName in pairs(menuList) do
			local info = {};
			info.checked = nil;
			info.notCheckable = 1;
			info.text = zName.location;
			info.textHeight = MetaMapOptions.MenuFont;
			info.value = zName.location;
			info.disabled = false;
			info.notClickable = false;
			info.isTitle = false;
			
			info.func = MetaMap_InstanceMenu_OnClick;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		end
		
		menuList = {};
		for index, value in pairs(MetaMap_ZoneTable) do
		   if(value.ztype == "BG" and menuVal == 999) then
		     table.insert(menuList, {location = value[MetaMap_Locale]});
		   end
		 end
		local sort = MetaMap_sortType;
		MetaMap_sortType = METAMAP_SORTBY_LOCATION;
		table.sort(menuList, MetaMap_SortCriteria);
		MetaMap_sortType = sort;
		for zKey, zName in pairs(menuList) do
			 local info = {};
			 info.checked = nil;
			 info.notCheckable = 1;
			 info.text = zName.location;
			 info.textHeight = MetaMapOptions.MenuFont;
			 info.value = zName.location;
			 info.func = MetaMap_InstanceMenu_OnClick;
			-- info.func = MetaMap_Print("No Battleground Map file.", true)
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		end
		menuList = nil;
	else
		for index, cName in pairs(MetaMap_Continents) do
			if(index > 0) then
				local info = {};
				info.text = cName;
				info.hasArrow = 1;
				info.value = index;
				info.notCheckable = 1;
				info.textHeight = MetaMapOptions.MenuFont;
				UIDropDownMenu_AddButton(info);
			end
		end
		local info = {
			text = METAMAP_BATTLEGROUNDS,
			textHeight = MetaMapOptions.MenuFont,
			value = "BG",
			hasArrow = 1,
			checked = nil,
			notCheckable = 1,
			value = 999
		}
		UIDropDownMenu_AddButton(info);
	end
end

function MetaMap_InstanceMenu_OnClick(self)
	UIDropDownMenu_SetText(MetaMap_InstanceMenu, this.value);
	MetaMapOptions.MetaMapZone = this.value;
	MetaMap_ShowInstance(true);
end

function MetaMap_MainMenuSelect(parent, level)
	local x, y = 0, 0;
	if(parent) then
		MetaMap_MenuParent = parent;
		if(parent == "FuBarPluginMetaMapFrame") then y = -10; end
	else
		MetaMap_MenuParent = "cursor";
	end
	ToggleDropDownMenu(nil, nil, MetaMap_MainMenu, MetaMap_MenuParent, x, y);
end

function MetaMap_MainMenu_Initialize(self)
	if(UIDROPDOWNMENU_MENU_LEVEL == 2) then
		local _, menuText = MetaMap_SubMenuFix();
		if(menuText == METAMAP_MENU_FILTER) then
			local menuFrame = getglobal("DropDownList"..2);
			local menuName = menuFrame:GetName();
			local cText;
			for i=0, 9, 1 do
				if(MetaMap_NoteFilter[i]) then
					cText = METAMAP_MAP_ICON_ON;
				else
					cText = METAMAP_MAP_ICON_OFF;
				end
				local info = {
					checked = nil,
					notCheckable = 1,
					keepShownOnClick = 1,
					text = cText,
					textHeight = MetaMapOptions.MenuFont,
					icon = METAMAP_ICON_PATH.."Icon"..i;
					value = {mode = 2, func = "MetaMap_FilterNotes", cText = cText, args = i},
					func = MetaMap_MainMenu_OnClick;
				};
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
			local info = {
				checked = nil;
				keepShownOnClick = 1,
				text = METAMAP_MENU_FILTER1;
				textHeight = MetaMapOptions.MenuFont,
				value = {mode = 2, func = "MetaMap_FilterNotes", args = 11};
				func = MetaMap_MainMenu_OnClick;
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			local info = {
				checked = nil;
				keepShownOnClick = 1,
				text = METAMAP_MENU_FILTER2;
				textHeight = MetaMapOptions.MenuFont,
				value = {mode = 2, func = "MetaMap_FilterNotes", args = 12};
				func = MetaMap_MainMenu_OnClick;
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		elseif(menuText == METAMAP_MENU_TRKFILTER) then
			local cText = "|cffff0000Off|r   ";
			if(TRK_Options.FilterHerb) then cText = "|cff00ff00On|r   "; end
			local info = {
				checked = nil;
				notCheckable = 1,
				keepShownOnClick = 1,
				text = cText..TRK_FILTER_HERB;
				textHeight = MetaMapOptions.MenuFont,
				value = "FilterHerb";
				func = TRK_MetaMapMenuOnClick;
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			cText = "|cffff0000Off|r   ";
			if(TRK_Options.FilterOre) then cText = "|cff00ff00On|r   "; end
			local info = {
				checked = nil;
				notCheckable = 1,
				keepShownOnClick = 1,
				text = cText..TRK_FILTER_ORE;
				textHeight = MetaMapOptions.MenuFont,
				value = "FilterOre";
				func = TRK_MetaMapMenuOnClick;
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			cText = "|cffff0000Off|r   ";
			if(TRK_Options.FilterTreasure) then cText = "|cff00ff00On|r   "; end
			local info = {
				checked = nil;
				notCheckable = 1,
				keepShownOnClick = 1,
				text = cText..TRK_FILTER_TREASURE;
				textHeight = MetaMapOptions.MenuFont,
				value = "FilterTreasure";
				func = TRK_MetaMapMenuOnClick;
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			cText = "|cffff0000Off|r   ";
			if(TRK_Options.FilterMisc) then cText = "|cff00ff00On|r   "; end
			local info = {
				checked = nil;
				notCheckable = 1,
				keepShownOnClick = 1,
				text = cText..TRK_FILTER_MISC;
				textHeight = MetaMapOptions.MenuFont,
				value = "FilterMisc";
				func = TRK_MetaMapMenuOnClick;
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		end
	else
		local info = {
			isTitle = 1,
			text = METAMAP_NAME.."\n\n",
			textHeight = MetaMapOptions.MenuFont +1,
		}
		UIDropDownMenu_AddButton(info);
		for index, value in ipairs(MetaMap_MainMenuData) do
			local toggle = ""; local showitem = true;
			local cText = value.text;
			if(cText == METAMAP_MENU_TRKFILTER and not IsAddOnLoaded("MetaMapTRK")) then showitem = false; end
			if(cText == METAMAP_MENU_FLIGHT and not IsAddOnLoaded("FlightMap")) then showitem = false; end
			if(cText == METAMAP_MENU_ACTION and MetaMap_CurrentAction) then
				cText = "|cff00ff00On|r    "..value.text;
			elseif(cText == METAMAP_MENU_ACTION and not MetaMap_CurrentAction) then
				cText = "|cffff0000Off|r    "..value.text;
			elseif(cText == METAMAP_MENU_FWMMOD and FWM_ShowUnexplored) then
				cText = "|cff00ff00On|r    "..value.text;
			elseif(cText == METAMAP_MENU_FWMMOD and not FWM_ShowUnexplored) then
				cText = "|cffff0000Off|r    "..value.text;
			elseif(cText == METAMAP_MENU_TRKSET) then
				if(GetTrackingTexture()) then
					cText = "|cff00ff00On|r    "..value.text;
					MetaMapOptions.MetaMapTracker = true;
				else
					cText = "|cffff0000Off|r    "..value.text;
					MetaMapOptions.MetaMapTracker = false;
				end
			elseif(cText == METAMAP_MENU_MAPSET) then
				cText = "|cff00FFFF  "..MetaMap_CurrentSaveSet.."|r     "..value.text;
			elseif(value.mode == 1 and MetaMapOptions[value.opt]) then
				cText = "|cff00ff00On|r    "..value.text;
			elseif(value.mode == 1 and not MetaMapOptions[value.opt]) then
				cText = "|cffff0000Off|r   "..value.text;
			end
			if(showitem) then
				local info = {
					keepShownOnClick = value.ksoc,
					checked = nil,
					notCheckable = 1,
					hasArrow = value.ha,
					notClickable = value.nc,
					text = cText,
					textHeight = MetaMapOptions.MenuFont,
					value = {mode = value.mode, func = value.opt, args = ""},
					func = MetaMap_MainMenu_OnClick,
				}
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
		end
	end
end

function MetaMap_MainMenu_OnClick()
	if(not this.value.mode) then return; end
	local button;
	if(this.value.mode == 1) then
		MetaMap_ToggleOptions(this.value.func);
	else
		RunScript(this.value.func.."("..this.value.args..")");
	end
	local txt = this:GetText();
	if(string.find(txt, "|cff00ff00On|r")) then
		txt = string.gsub(txt, "|cff00ff00On|r", "|cffff0000Off|r");
	elseif(string.find(txt, "|cffff0000Off|r")) then
		txt = string.gsub(txt, "|cffff0000Off|r", "|cff00ff00On|r");
	elseif(string.find(txt, "1")) then
		txt = string.gsub(txt, "1", "2");
		button = getglobal(this:GetParent():GetName().."Button"..this:GetID() -1);
	elseif(string.find(txt, "2")) then
		txt = string.gsub(txt, "2", "1");
		button = getglobal(this:GetParent():GetName().."Button"..this:GetID() -1);
	end
	if(button and MetaMap_CurrentAction) then
		button:SetText("|cff00ff00On|r    "..METAMAP_MENU_ACTION);
	elseif(button and not MetaMap_CurrentAction) then
		button:SetText("|cffff0000Off|r    "..METAMAP_MENU_ACTION);
	end
	this:SetText(txt);
	this.checked = not this.checked;
end

function MetaMap_FilterNotes(args)
	if(args == 11) then
		for i=0, 9, 1 do
			local index = i +1;
			local button = getglobal("DropDownList2Button"..index);
			button:SetText(string.gsub(button:GetText(), "|cffff0000Off|r", "|cff00ff00On|r"));
			MetaMap_NoteFilter[i] = true;
		end
	elseif(args == 12) then
		for i=0, 9, 1 do
			local index = i +1;
			local button = getglobal("DropDownList2Button"..index);
			button:SetText(string.gsub(button:GetText(), "|cff00ff00On|r", "|cffff0000Off|r"));
			MetaMap_NoteFilter[i] = false;
		end
	else
		MetaMap_NoteFilter[args] = not MetaMap_NoteFilter[args];
	end
	MetaMap_MainMapUpdate();
end

function MetaMap_ZoneCheckMenu_Initialize(self)
	if(UIDROPDOWNMENU_MENU_LEVEL == 1) then
		for index, cName in pairs(MetaMap_Continents) do
			if(index > 0) then
				local info = {
					text = cName,
					textHeight = MetaMapOptions.MenuFont,
					value = index,
					hasArrow = 1,
					checked = nil,
					notCheckable = 1,
				}
				UIDropDownMenu_AddButton(info);
			end
		end
		local info = {
			text = METAMAP_BATTLEGROUNDS,
			textHeight = MetaMapOptions.MenuFont,
			value = "BG",
			hasArrow = 1,
			checked = nil,
			notCheckable = 1,
		}
		UIDropDownMenu_AddButton(info);
		local info = {
			text = METAMAP_INSTANCES,
			textHeight = MetaMapOptions.MenuFont,
			value = "DN",
			hasArrow = 1,
			checked = nil,
			notCheckable = 1,
		}
		UIDropDownMenu_AddButton(info);
	end
	if (UIDROPDOWNMENU_MENU_LEVEL == 2) then
		local menuVal, _ = MetaMap_SubMenuFix();
		if (menuVal == "BG") then
			for index, value in pairs(MetaMap_ZoneTable) do
				if(value.ztype == "BG") then
					local info = {
						checked = nil;
						notCheckable = 1;
						text = value[MetaMap_Locale];
						textHeight = MetaMapOptions.MenuFont,
						value = value[MetaMap_Locale];
						func = MetaMap_ZoneCheckMenu_OnClick;
					};
					UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
				end
			end
		elseif(menuVal == "DN") then
			for index, cName in pairs(MetaMap_Continents) do
				if(index > 0) then
					local info = {
						text = cName,
						textHeight = MetaMapOptions.MenuFont,
						value = index,
						hasArrow = 1,
						checked = nil,
						notCheckable = 1,
					}
					UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
				end
			end
		else
			for zKey, zName in ipairs{GetMapZones(menuVal)} do
				local info = {
					checked = nil;
					notCheckable = 1;
					text = zName;
					textHeight = MetaMapOptions.MenuFont,
					value = zName;
					func = MetaMap_ZoneCheckMenu_OnClick;
				};
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
		end
	end
	if(UIDROPDOWNMENU_MENU_LEVEL == 3) then
		local menuVal = MetaMap_SubMenuFix();
		local menuList = {};
		for index, value in pairs(MetaMap_ZoneTable) do
			if(value.ztype == "DN" and value.Continent == menuVal) then
		    table.insert(menuList, {location = value[MetaMap_Locale]});
			end
		end
		local sort = MetaMap_sortType;
		MetaMap_sortType = METAMAP_SORTBY_LOCATION;
		table.sort(menuList, MetaMap_SortCriteria);
		MetaMap_sortType = sort;
		for zKey, zName in pairs(menuList) do
			local info = {
				checked = nil,
				notCheckable = 1,
				text = zName.location,
				textHeight = MetaMapOptions.MenuFont,
				value = zName.location,
				func = MetaMap_ZoneCheckMenu_OnClick,
			};
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
		end
		menuList = nil;
	end
end

function MetaMap_ZoneCheckMenu_OnClick()
	UIDropDownMenu_SetText(MetaMap_ZoneCheckMenu, this.value);
	MetaMap_ZoneCheckButton:Enable();
end

function MetaMap_ToggleDialog(tab)
	local subFrame = getglobal(tab);
	MetaMap_OptionsInfo:SetText("");
	MetaMap_GeneralDialog:Hide();
	MetaMap_NotesDialog:Hide();
	MetaMap_ModulesDialog:Hide();
	MetaMap_ImportDialog:Hide();
	MetaMap_ZoneShiftDialog:Hide();
	MetaMap_HelpDialog:Hide();
	if(BKP_BackUpFrame) then BKP_BackUpFrame:Hide(); end
	if(EXP_ExportFrame) then EXP_ExportFrame:Hide(); end
	if(CVT_ImportFrame) then CVT_ImportFrame:Hide(); end
	if(subFrame) then
		if(MetaMap_DialogFrame:IsVisible()) then
			PlaySound("igCharacterInfoTab");
			getglobal(tab):Show();
		else
			ShowUIPanel(MetaMap_DialogFrame);
			getglobal(tab):Show();
		end
	end
end

function MetaMap_OptionsTab_OnClick(self)
	if(this:GetName() == "MetaMap_DialogFrameTab1") then
		MetaMap_ToggleDialog("MetaMap_GeneralDialog");
	elseif(this:GetName() == "MetaMap_DialogFrameTab2") then
		MetaMap_ToggleDialog("MetaMap_NotesDialog");
	elseif(this:GetName() == "MetaMap_DialogFrameTab3") then
		MetaMap_ToggleDialog("MetaMap_ModulesDialog");
	elseif(this:GetName() == "MetaMap_DialogFrameTab4") then
		MetaMap_ToggleDialog("MetaMap_ImportDialog");
	elseif(this:GetName() == "MetaMap_DialogFrameTab5") then
		MetaMap_ToggleDialog("MetaMap_ZoneShiftDialog");
	elseif(this:GetName() == "MetaMap_DialogFrameTab6") then
		MetaMap_ToggleDialog("MetaMap_HelpDialog");
	end
	PlaySound("igCharacterInfoTab");
end

function MetaMapExtOptions_Toggle()
	if(MetaMap_DialogFrame:IsVisible()) then
		HideUIPanel(MetaMap_DialogFrame);
	else
		if(MetaMap_FullScreenMode) then
			MetaMap_DialogFrame:SetParent("WorldMapFrame");
		else
			MetaMap_DialogFrame:SetParent("UIParent");
			MetaMap_DialogFrame:SetFrameStrata("FULLSCREEN");
		end
		ShowUIPanel(MetaMap_DialogFrame);
	end
end

function MetaMapSaveSet_Toggle()
	if(MetaMapOptions.SaveSet == 1) then
		WorldMapFrameSizeDownButton:Hide();
		WorldMapFrameSizeUpButton:Show();
 
		MetaMapOptions.SaveSet = 2;
	else
		WorldMapFrameSizeDownButton:Show();
		WorldMapFrameSizeUpButton:Hide();
		MetaMapOptions.SaveSet = 1;
	end
	MetaMapOptions_Init();
end

function MetaMap_MapModeToggle(mode)
	MetaMapOptions.SaveSet = mode;
	MetaMap_ToggleFrame(WorldMapFrame);
end

function MetaMap_ActionToggle()
	MetaMap_ToggleOptions("ActionMode"..MetaMapOptions.SaveSet);
end

function MetaMapShadeSet_Toggle()
	if(MetaMapOptions.SaveSet == 1) then
		if(MetaMapOptions.ShadeSet1 == 4) then
			MetaMapOptions.ShadeSet1 = 1;
		else
			MetaMapOptions.ShadeSet1 = MetaMapOptions.ShadeSet1 +1;
		end
	else
		if(MetaMapOptions.ShadeSet2 == 4) then
			MetaMapOptions.ShadeSet2 = 1;
		else
			MetaMapOptions.ShadeSet2 = MetaMapOptions.ShadeSet2 +1;
		end
	end
	MetaMapOptions_Init();
end

function MetaMapOptions_Init()
	--MetaMap_Debug_Print("MetaMapOptions_Init",true);
	if(MetaMapOptions.SaveSet == 1) then
		if(MetaMapOptions.MetaMapAlpha1 < 0.15) then MetaMapOptions.MetaMapAlpha1 = 0.15; end
		MetaMapScaleSlider:SetValue(MetaMapOptions.MetaMapScale1);
		MetaMap_BackDropSlider:SetValue(MetaMapOptions.BDshader1);
		MetaMapAlphaSlider:SetValue(MetaMapOptions.MetaMapAlpha1);
		MetaMapTTScaleSlider:SetValue(MetaMapOptions.MetaMapTTScale1);
		MetaMap_CurrentAction = MetaMapOptions.ActionMode1;
		MetaMap_CurrentShadeSet = MetaMapOptions.ShadeSet1;
	else
		if(MetaMapOptions.MetaMapAlpha2 < 0.15) then MetaMapOptions.MetaMapAlpha2 = 0.15; end
		MetaMapScaleSlider:SetValue(MetaMapOptions.MetaMapScale2);
		MetaMap_BackDropSlider:SetValue(MetaMapOptions.BDshader2);
		MetaMapAlphaSlider:SetValue(MetaMapOptions.MetaMapAlpha2);
		MetaMapTTScaleSlider:SetValue(MetaMapOptions.MetaMapTTScale2);
		MetaMap_CurrentAction = MetaMapOptions.ActionMode2;
		MetaMap_CurrentShadeSet = MetaMapOptions.ShadeSet2;
	end
	if(MetaMap_CurrentAction) then
		WorldMapButton:EnableMouse(false);
		MetaMapTopFrame:EnableMouse(false);
		MetaMapFrame:EnableMouse(false);
	else
		WorldMapButton:EnableMouse(true);
		MetaMapTopFrame:EnableMouse(true);
		MetaMapFrame:EnableMouse(true);
	end
	if(MetaMapOptions.MetaMapButtonShown) then
		MetaMapButton_UpdatePosition();
		MetaMapButton:Show();
	else
		MetaMapButton:Hide();
		--WorldMapButton:Show()
	end
	if(MetaMapOptions.MetaMapCoords) then
		MetaMap_MainCoords:Show();
	else
		MetaMap_MainCoords:Hide();
	end
	if(MetaMapOptions.MetaMapMiniCoords) then
		MetaMap_MiniCoords:Show();
	else
		MetaMap_MiniCoords:Hide();
	end
	if(MetaMapOptions.ShowMapList) then
		MetaMapList_Init();
	else
		MetaMap_MapListFrame:Hide();
	end
	MetaMap_UpdateAlpha();
	MetaMap_UpdateScale();
	MetaMap_UpdateTTScale();
	MetaMap_UpdateBackDrop();
	MetaMapContainerFrame:SetBackdropColor(0,0,0,MetaMapOptions.ContainerAlpha);
	MetaMap_MapListFrame:SetBackdropColor(0,0,0,MetaMapOptions.ContainerAlpha);
	MetaMap_CurrentSaveSet = MetaMapOptions.SaveSet;
	MetaMapButtonSlider:SetValue(MetaMapOptions.MetaMapButtonPosition);
	MetaMapMiniCoords:SetTextColor(MetaMap_Colors[MetaMapOptions.MiniColor].r, MetaMap_Colors[MetaMapOptions.MiniColor].g, MetaMap_Colors[MetaMapOptions.MiniColor].b);
	getglobal("MetaMap_Check_ShadeSetCheck"):SetTexture(METAMAP_IMAGE_PATH.."Color"..MetaMap_CurrentShadeSet);
	MetaMap_MapModeText:SetText(METAMAP_MENU_MAPSET.." "..MetaMapOptions.SaveSet);
end

function MetaMapButton_UpdatePosition()
	if MetaMapOptions.MetaMapButtonPosition_Old ~= MetaMapOptions.MetaMapButtonPosition or not MetaMapOptions.MetaMapButtonPositionXY then
		MetaMapButton:ClearAllPoints()
		MetaMapButton:SetPoint("TOPLEFT", "Minimap", "TOPLEFT",
			52 - (80 * cos(MetaMapOptions.MetaMapButtonPosition)),
			(80 * sin(MetaMapOptions.MetaMapButtonPosition)) - 52
		);
		MetaMapOptions.MetaMapButtonPositionXY = nil
		MetaMapOptions.MetaMapButtonPosition_Old = MetaMapOptions.MetaMapButtonPosition

	end
end

function MMTest()
	local cx, cy = GetCursorPosition()
	local cz = UIParent:GetEffectiveScale()
	MetaMapOptions.MetaMapButtonPositionX = cx
	MetaMapOptions.MetaMapButtonPositionY = cy
	MetaMapButton_UpdatePosition();
end

function MetaMap_ButtonTooltip()
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent);
	GameTooltip:SetText(METAMAP_TITLE, 0, 1, 0);
	GameTooltip:AddLine(METAMAP_BUTTON_TOOLTIP1, 1, 1, 1);
	if(MetaMapOptions.MenuMode) then
		GameTooltip:AddLine(METAMAP_BUTTON_TOOLTIP2, 1, 1, 1);
	end
	GameTooltip:Show();
end

function MetaMap_round(num, idp)
  local mult = 10^(idp or 0);
  return (math.floor(num * mult + 0.5) / mult);
end

function SetEffectiveScale(frame, scale)
	--frame.scale = scale;
	local parent = frame:GetParent();
	if(parent) then
		scale = scale / parent:GetEffectiveScale();
	end
	frame:SetScale(scale);
	return scale;
end

function MiniMapCoords_OnClick(button)
	if(IsShiftKeyDown()) then
		if(not ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Show(); end
		local msg = METAMAP_MYLOCATION..GetRealZoneText().." ("..MetaMapMiniCoords:GetText()..")";
		ChatFrameEditBox:Insert(msg);
	elseif(IsControlKeyDown()) then
		if(MetaMapOptions.MiniColor == 9) then
			MetaMapOptions.MiniColor = 0;
		else
			MetaMapOptions.MiniColor = MetaMapOptions.MiniColor +1;
		end
		MetaMapMiniCoords:SetTextColor(MetaMap_Colors[MetaMapOptions.MiniColor].r, MetaMap_Colors[MetaMapOptions.MiniColor].g, MetaMap_Colors[MetaMapOptions.MiniColor].b);
	end
end

function MiniMapCoords_OnEnter()
	MetaMap_SetTTInfoLine(GetRealZoneText(), this, GameTooltip);
	GameTooltip:AddLine(METAMAP_INFOLINE_HINT5, 0.75, 0, 0.75, false);
	GameTooltip:AddLine(METAMAP_INFOLINE_HINT6, 0.75, 0, 0.75, false);
	GameTooltip:Show()
end

function MetaMap_ShowLocation(zoneName, noteName, noteID)
	local _, _, zType = MetaMap_GetZoneTableEntry(zoneName);
	MetaMapContainer_ShowFrame();
	ShowUIPanel(WorldMapFrame);
	if(zType == "DN") or (zType == "DNI") then
		MetaMapOptions.MetaMapZone = zoneName;
		MetaMap_ShowInstance(true);
	else
		MetaMap_ShowInstance(false);
		SetMapZoom(MetaMap_NameToZoneID(zoneName));
	end
	if(not noteName) then return; end
	local dataZone = MetaMap_Notes[zoneName];
	if(not noteID) then
		for index, value in ipairs(dataZone) do
			if(dataZone[index].name == noteName) then
				noteID = index;
				break;
			end
		end
	end
	if(noteID) then
		MetaMapPing_SetPing(dataZone, noteID);
	end
end

function MetaMapList_Init()
	if(not MetaMapOptions.ShowMapList) then
		return;
	end
	if(MetaMapOptions.SortList) then
		MetaMapList_Header:SetText(METAMAPLIST_UNSORTED);
	else
		MetaMapList_Header:SetText(METAMAPLIST_SORTED);
	end
	MetaMap_MapListFrame:Show();
	FauxScrollFrame_SetOffset(MetaMapList_ScrollFrame, MetaMap_ListOffset);
	MetaMapList_BuildList();
	if(not MetaMap_NoteList[1]) then
		MetaMap_MapListFrame:Hide();
		return;
	end
	MetaMapList_UpdateScroll();
end

local oldProcessMapClick = ProcessMapClick;
function ProcessMapClick(...)
	--MetaMap_Debug_Print("ProcessMapClick",true);
	-- This gets called from WorldMapFrame.lua when user left clicks on the map.
	
		local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	
    if (not MetaMap_FramesHidden()) then return; end
	if BattlefieldMinimap and BattlefieldMinimap:IsVisible() and not MetaMapFrame:IsVisible() then
		if not MetaMap_CombatLockdown_BattlefiedMap then
			MetaMap_Reshow_BattlefiedMap = time()
		end
		MetaMap_CombatLockdown_BattlefiedMap = nil
		BattlefieldMinimap:Hide() --BattlefieldMinimap screws up the map selection
	end
	
	if(mapName and MetaMap_Relocate.id) then
		if(not IsControlKeyDown() and not IsShiftKeyDown()) then
			MetaMap_MoveNote(MetaMap_Relocate.mapName, MetaMap_Relocate.id)
			MetaMap_Relocate = {};
			return;
		end
	end
	
	
	if(mapName) then 
	 local _,_,ztype = MetaMap_GetZoneTableEntry(mapName);
	 if (not (ztype == "SZ")) then
	 
	   MetaMap_Debug_Print("mapName: " .. tostring(mapName) , true);
	   MetaMap_Debug_Print("dataZone: " .. tostring(dataZone) , true);
	   MetaMap_Debug_Print("realZoneText: " .. tostring(GetRealZoneText()) , true);
	  
	   MetaMap_Debug_Print("MetaMapOptions.MetaMapZone:"..tostring(MetaMapOptions.MetaMapZone), true);
	 end
	else
		 MetaMap_Debug_Print("realZoneText: " .. tostring(GetRealZoneText()) , true);
		 
	end
	 

	 
	if((IsControlKeyDown() or IsShiftKeyDown() or IsAltKeyDown()) and mapName and dataZone ) then
		if(mapName or MetaMapFrame:IsVisible() or MetaMapOptions.ShowDNI) then
			local centerX, centerY = WorldMapButton:GetCenter()
			local width = WorldMapButton:GetWidth()
			local height = WorldMapButton:GetHeight()
			local x, y = GetCursorPosition()
			x = x / WorldMapButton:GetEffectiveScale()
			y = y / WorldMapButton:GetEffectiveScale()
			
			if(centerX == nil) then
				centerX = 0;
			end
	
			if(centerY == nil) then
				centerY = 0;
			end
			
			local adjustedY = (centerY + height/2 - y) / height
			local adjustedX = (x - (centerX - width/2)) / width
		
			if(IsShiftKeyDown()) then
				MetaMap_SetPartyNote(adjustedX, adjustedY);
			elseif(IsControlKeyDown()) then
				local _, dataZone = MetaMap_GetCurrentMapInfo();
				if dataZone then MetaMap_EditNewNote(adjustedX, adjustedY) end
			elseif(IsAltKeyDown() and MetaMap_GetCurrentMapInfo() == GetRealZoneText()) then
				MetaMap_LoadBWP(0, 3);
				if(IsAddOnLoaded("MetaMapBWP")) then
					BWP_LocCommand(format("%d, %d", 100 * adjustedX, 100 * adjustedY));
				end
			end
		end
	elseif(MetaMapFrame:IsVisible()) then
		MetaMap_Debug_Print("--------click mark-------",true);
		oldProcessMapClick(...);
	else
		MetaMap_Debug_Print("--------click mark-------",true);
		oldProcessMapClick(...);
	end
end


function MetaMapList_OnClick(self, button, id)
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	if(button	== "LeftButton") then
		if(IsControlKeyDown()) then
			local LootID = dataZone[id].lootid;
			local Name = dataZone[id].name;
			MetaMap_LoadBLT(LootID, Name);
		elseif(IsShiftKeyDown()) then
			if(not dataZone) then return; end
			if(not ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Show(); end
			local tinf1 = dataZone[id].inf1;
			local coords = format("%d, %d", dataZone[id].xPos *100, dataZone[id].yPos *100)
			if(strlen(tinf1) > 0) then tinf1 = " ["..tinf1.."] "; end
			local msg = dataZone[id].name.." "..tinf1.." ("..mapName.." - "..coords..")";
			ChatFrameEditBox:Insert(msg);
		elseif(id == 0) then
			MetaMapPing_SetPing(dataZone, id);
		else
			MetaMapPing_SetPing(dataZone, MetaMap_NoteList[this:GetID() + MetaMap_ListOffset].id);
		end
	elseif(button == "RightButton")	then
		if(IsControlKeyDown()) then
			MetaMap_LoadBWP(id, 2);
		elseif(IsShiftKeyDown() and MetaMap_LoadNBK(1)) then
			NBK_SetTargetNote(dataZone[id].name);
		else
			MetaMap_MapNote_OnClick(self,"LeftButton", id);
		end
	end
end

function MetaMapList_BuildList()
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	MetaMap_NoteList = {};
	MetaMapList_InfoText:Hide();
	MetaMapList_PlayerButton:Hide();
	if(mapName == GetRealZoneText() and not MetaMapFrame:IsVisible()) then
		getglobal("MetaMapList_PlayerButton".."Name"):SetText(UnitName("Player"));
		MetaMapList_PlayerButton:Show();
	elseif(MetaMapFrame:IsVisible()) then
		MetaMapList_InfoText:Show();
	end
	if(not dataZone) then
		MetaMap_MapListFrame:Hide();
	else
		local index = 1;
		for i, value in ipairs(dataZone) do
			if(MetaMap_NoteFilter[dataZone[i].icon]) then
	 			MetaMap_NoteList[index] = {};
				MetaMap_NoteList[index]["name"] = dataZone[i]["name"];
				MetaMap_NoteList[index]["xPos"] = dataZone[i]["xPos"];
				MetaMap_NoteList[index]["yPos"] = dataZone[i]["yPos"];
				MetaMap_NoteList[index]["ncol"] = dataZone[i]["ncol"];
				MetaMap_NoteList[index]["icon"] = dataZone[i]["icon"];
				MetaMap_NoteList[index]["id"] = i;
				MetaMap_NoteList.lastEntry = index;
				index = index +1;
			end
		end
		if(MetaMapOptions.SortList) then
			local sort = MetaMap_sortType;
			MetaMap_sortType = METAMAP_SORTBY_NAME;
		  table.sort(MetaMap_NoteList, MetaMap_SortCriteria);
			MetaMap_sortType = sort;
		end
	end
end

function MetaMapList_UpdateScroll()
	for i = 1, METAMAP_LISTBUTTON_SHOWN, 1 do
		local buttonIndex = i + FauxScrollFrame_GetOffset(MetaMapList_ScrollFrame);
		local scrollFrameButton = getglobal("MetaMapList_ScrollFrameButton"..i);
		local NameButton = getglobal("MetaMapList_ScrollFrameButton"..i.."Name");
		if(buttonIndex < MetaMap_NoteList.lastEntry +1) then
			MetaMap_ListOffset = buttonIndex - i;
			NameButton:SetText(MetaMap_NoteList[buttonIndex]["name"]);
			getglobal("MetaMapList_ScrollFrameButton"..i.."NoteID"):SetText(MetaMap_NoteList[buttonIndex]["id"]);
			if(MetaMapOptions.ListColors) then
				local cNr = MetaMap_NoteList[buttonIndex]["ncol"]
				NameButton:SetTextColor(MetaMap_Colors[cNr].r, MetaMap_Colors[cNr].g, MetaMap_Colors[cNr].b);
			else
				NameButton:SetTextColor(MetaMap_Colors[0].r, MetaMap_Colors[0].g, MetaMap_Colors[0].b);
			end
			scrollFrameButton:Show();
		else
			scrollFrameButton:Hide();
		end
	end
	FauxScrollFrame_Update(MetaMapList_ScrollFrame, MetaMap_NoteList.lastEntry, METAMAP_LISTBUTTON_SHOWN, METAMAP_LISTBUTTON_HEIGHT);
end

function MetaMapPing_SetPing(dataZone, id)
	if(id == 0) then
		if(WorldMapPing:IsShown()) then
			WorldMapPing:Hide();
		else
			WorldMapPing:Show();
		end
		return
	end
	if(MetaMap_PingPOI and MetaMap_PingPOI:IsShown()) then
		MetaMapPing_OnUpdate(1);
		return;
	end
	MetaMap_PingPOI = getglobal("MetaMapNotesPOI"..id.."Ping");
	MetaMap_PingPOI:SetTexture(METAMAP_ICON_PATH.."IconPing")
	MetaMap_PingPOI:Show();
	MetaMap_PingPOI:SetAlpha(255);
	UIFrameFlash(MetaMap_PingPOI, 0.25, 0.25, 30, true, 0.15, 0.15);
	PlaySound("MapPing");
end

function MetaMapPing_OnUpdate(rem)
	if(rem or not UIFrameIsFading(MetaMap_PingPOI)) then
		UIFrameFlashRemoveFrame(MetaMap_PingPOI);
		MetaMap_PingPOI:Hide();
		MetaMap_PingPOI = nil;
	end
end

function MetaMap_ZoneSearch()
	if(MetaMap_NotesDialog:IsVisible()) then
		local mapName = MetaMap_GetCurrentMapInfo();
		MetaMap_ZoneSearchResult:SetText(format(METAMAP_ZONESEARCH_TEXT, mapName));
	end
end

function MetaMap_HelpOnEnter(header, args)
	local myArgs = {args};
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
	GameTooltip:SetText(header, 0.2, 0.5, 1, true);
	for i,string in pairs(myArgs) do
		GameTooltip:AddLine(string, 1, 1, 1, true);
	end
	GameTooltip:Show();
end

function MetaMap_Print(msg, display, r, g, b)
	if(not display) then return; end
	if(msg == nil) then msg = "Nil Value"; end
	if(type(msg) == "table") then msg = "Table Value"; end
	msg = "<"..METAMAP_TITLE..">: "..msg;
	if DEFAULT_CHAT_FRAME then
		if(r == nil or g == nil or b == nil) then
			r = 0.60; g = 0.80; b = 1.00;
		end
		DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
	end
end

function MetaMap_Debug_Print(msg, display, r, g, b)
	if(not MetaMapOptions["Debug"]) then return; end
	if(not display) then return; end
	if(msg == nil) then msg = "Nil Value"; end
	if(type(msg) == "table") then msg = "Table Value"; end
	msg = "["..date("%m/%d/%y %H:%M:%S").."]".."<"..METAMAP_TITLE..">: "..msg;
	if DEFAULT_CHAT_FRAME then
		if(r == nil or g == nil or b == nil) then
			r = 0.60; g = 0.80; b = 1.00;
		end
		DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
	end
end

function MetaMap_ToggleDR(mode)
	if(mode == 1) then
		DressUpFrame:SetMovable(true);
		DressUpFrame:SetFrameStrata("FULLSCREEN_DIALOG");
		DressUpFrame:SetScript("OnMouseDown", function() if(arg1	== "LeftButton") then this:StartMoving(); this.isMoving	=	true; end end);
		DressUpFrame:SetScript("OnMouseUp", function() if(this.isMoving) then this:StopMovingOrSizing(); this.isMoving	=	false; end end);
	else
		DressUpFrame:SetMovable(false);
		DressUpFrame:SetFrameStrata("HIGH");
		DressUpFrame:SetScript("OnMouseDown", nil);
		DressUpFrame:SetScript("OnMouseUp", nil);
	end
end

local function MetaMap_CreateNoteObject(noteNumber)
	local button;
	if(getglobal("MetaMapNotesPOI"..noteNumber)) then
		button = getglobal("MetaMapNotesPOI"..noteNumber);
	else
		button = CreateFrame("Button" ,"MetaMapNotesPOI"..noteNumber, WorldMapButton, "MetaMapNotes_NoteTemplate");
		MetaMap_LastNote = MetaMap_LastNote +1;
	end
	button:SetWidth(MetaMapOptions.NoteSize);
	button:SetHeight(MetaMapOptions.NoteSize);
	button:SetID(noteNumber);
	return button;
end

local function MetaMap_CreateLineObject(lineNumber)
	local line;
	if(getglobal("MetaMapNotesLines_"..lineNumber)) then
		line = getglobal("MetaMapNotesLines_"..lineNumber);
	else
		MetaMapNotesLinesFrame:CreateTexture("MetaMapNotesLines_"..lineNumber, "ARTWORK");
		line = getglobal("MetaMapNotesLines_"..lineNumber);
		MetaMap_LastLine = MetaMap_LastLine +1;
	end
	return line
end

local function MetaMap_AddMiniNote(id, mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c)
	local dataZone = MetaMap_Notes[mapName][id];
	MetaMap_MiniNote_Data.id = id;
	MetaMap_MiniNote_Data.zonetext = mapName;
	MetaMap_MiniNote_Data.inf1 = "";
	MetaMap_MiniNote_Data.inf2 = "";
	MetaMap_MiniNote_Data.in1c = 1;
	MetaMap_MiniNote_Data.in2c = 1;
	MetaMap_MiniNote_Data.color = 0;
	MetaMap_MiniNote_Data.creator = creator;
	if(id == 0) then
		MetaMap_MiniNote_Data.xPos = xPos;
		MetaMap_MiniNote_Data.yPos = yPos;
		MetaMap_MiniNote_Data.name = name;
		MetaMap_MiniNote_Data.inf1 = inf1;
		MetaMap_MiniNote_Data.inf2 = inf2;
		MetaMap_MiniNote_Data.in1c = in1c;
		MetaMap_MiniNote_Data.in2c = in2c;
		MetaMap_MiniNote_Data.color = ncol;
		MetaMap_MiniNote_Data.icon = icon;
	elseif(id == -1) then
		MetaMap_MiniNote_Data.xPos = MetaMap_PartyNoteData.xPos;
		MetaMap_MiniNote_Data.yPos = MetaMap_PartyNoteData.yPos;
		MetaMap_MiniNote_Data.name = METAMAP_PARTYNOTE;
		MetaMap_MiniNote_Data.icon = "party";
	elseif(id > 0) then
		MetaMap_MiniNote_Data.xPos = dataZone.xPos;
		MetaMap_MiniNote_Data.yPos = dataZone.yPos;
		MetaMap_MiniNote_Data.name = dataZone.name;
		MetaMap_MiniNote_Data.inf1 = dataZone.inf1;
		MetaMap_MiniNote_Data.inf2 = dataZone.inf2;
		MetaMap_MiniNote_Data.in1c = dataZone.in1c;
		MetaMap_MiniNote_Data.in2c = dataZone.in2c;
		MetaMap_MiniNote_Data.color = dataZone.ncol;
		MetaMap_MiniNote_Data.icon = dataZone.icon;
		MetaMap_MiniNote_Data.creator = dataZone.creator;
	end
	MetaMap_MiniNoteTexture:SetTexture(METAMAP_ICON_PATH.."Icon"..MetaMap_MiniNote_Data.icon);
	MetaMap_MiniNote:Show();
	MetaMap_SetNextAsMiniNote = 0;
	MetaMapNotesButtonMiniNoteOff:Enable();
	MetaMap_MainMapUpdate();
end

local function MetaMap_CheckNearNotes(mapName, xPos, yPos)
	local dataZone = MetaMap_Notes[mapName];
	if(dataZone == nil) then return; end
	for i, value in pairs(dataZone) do
		local deltax = abs(dataZone[i].xPos - xPos);
		local deltay = abs(dataZone[i].yPos - yPos);
		if(deltax <= 0.0009765625 * MetaMap_MinDiff and deltay <= 0.0013020833 * MetaMap_MinDiff) then
			return i;
		end
	end
	return false;
end

local function MetaMap_AddNewNote(mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c, mininote,mLevel)
	if(xPos == 0 and yPos == 0) then
		MetaMap_Print(METAMAP_INVALIDZONE, true);
		return;
	end
	if(not MetaMap_Notes[mapName] or name == nil) then return false; end
	if(inf1 == nil) then inf1 = ""; end
	if(inf2 == nil) then inf2 = ""; end
	if(icon == nil) then icon = 0; end
	if(ncol == nil) then ncol = 0; end
	if(in1c == nil) then in1c = 0; end
	if(in2c == nil) then in2c = 0; end
	if(mLevel == nil) then mLevel = 0; end
	if(creator == nil) then creator = UnitName("player"); end
	local id = 0;
	local checkNote;
	local returnValue = true;
	local dataZone = MetaMap_Notes[mapName];
	local index = #(dataZone);
	if(mininote == 0 or mininote == nil) then
		MetaMap_SetNextAsMiniNote = 0;
	elseif(mininote == 1) then
		MetaMap_SetNextAsMiniNote = 1;
	elseif(mininote == 2) then
		MetaMap_SetNextAsMiniNote = 2;
	end		

	if(MetaMap_SetNextAsMiniNote ~= 2) then
		checkNote = MetaMap_CheckNearNotes(mapName, xPos, yPos);
		if(checkNote) then
			returnValue = false;
		else
			MetaMap_TempData_Id = index + 1
			dataZone[MetaMap_TempData_Id] = {};
			dataZone[MetaMap_TempData_Id].name = name;
			dataZone[MetaMap_TempData_Id].ncol = ncol;
			dataZone[MetaMap_TempData_Id].inf1 = inf1;
			dataZone[MetaMap_TempData_Id].in1c = in1c;
			dataZone[MetaMap_TempData_Id].inf2 = inf2;
			dataZone[MetaMap_TempData_Id].in2c = in2c;
			dataZone[MetaMap_TempData_Id].creator = creator;
			dataZone[MetaMap_TempData_Id].icon = icon;
			dataZone[MetaMap_TempData_Id].xPos = xPos;
			dataZone[MetaMap_TempData_Id].yPos = yPos;
			dataZone[MetaMap_TempData_Id].mLevel = mLevel;
			id = MetaMap_TempData_Id;
			if(MetaMap_MiniNote_Data ~= nil and MetaMap_MiniNote_Data.name == name) then
				MetaMap_MiniNote_Data.id = id;
			end
			returnValue = true;
			checkNote = id;
		end
	end
	if(MetaMap_SetNextAsMiniNote ~= 0) then
		for i=0, index, 1 do
		if(dataZone[i] ~= nil) then
			if(dataZone[i].name == name and dataZone[i].xPos == xPos and dataZone[i].yPos == yPos) then
				id = i;
				break;
			end
		end
		end
		MetaMap_AddMiniNote(id, mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c);
		returnValue = returnValue;
	end
	MetaMap_MainMapUpdate();
	return returnValue, checkNote;
end

local function MetaMap_DeleteMapNote(id, mapName)
	MetaMap_HideAll()
	if id == 0 then
		MetaMap_vnote_xPos = nil;
		MetaMap_vnote_yPos = nil;
		MetaMap_MainMapUpdate();
		return;
	elseif id == -1 then
		MetaMap_PartyNoteData.xPos = nil;
		MetaMap_PartyNoteData.yPos = nil;
		MetaMap_PartyNoteData.mapName = nil;
		if(MetaMap_MiniNote_Data.id == -1) then
			MetaMap_MiniNote_Data = {};
		end
		MetaMap_MainMapUpdate();
		return;
	end

	local TempData = {};
	TempData[mapName] = {};
	local dataZone = MetaMap_Notes[mapName][id];
	local lastEntry = #(MetaMap_Notes[mapName]);
	if(dataZone) then
		MetaMap_DeleteLines(mapName, dataZone.xPos, dataZone.yPos);
	end
	if(lastEntry ~= 0 and id <= lastEntry) then
		TempData[mapName] = MetaMap_Notes[mapName];
		MetaMap_Notes[mapName] = {};
		local newZone = TempData[mapName];
		for index, indexTable in ipairs(newZone) do
			if(index ~= id) then
				local oldData = newZone[index];
				MetaMap_AddNewNote(mapName, oldData.xPos, oldData.yPos, oldData.name, oldData.inf1, oldData.inf2, oldData.creator, oldData.icon, oldData.ncol, oldData.in1c, oldData.in2c,nil,oldData.mLevel)
			end
		end
	end
	if(MetaMap_MiniNote_Data.id == id) then
		MetaMap_ClearMiniNote(true);
	end
	MetaMap_MainMapUpdate();
end

function MetaMap_GenerateSendString(version)
-- <MetaMap:MN> z<1> x<0.123123> y<0.123123> t<> i1<> i2<> cr<> i<8> tf<3> i1f<5> i2f<6>
	local text = ""
	local pName = UnitName("player");
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	if(not dataZone) then return; end
	if(version == 1) then text = "<MetaMap:MN>"; end
	text = text.." z<"..mapName..">";

	if(MetaMap_PartyNoteSet) then
		local xPos = floor(MetaMap_PartyNoteData.xPos * 1000000)/1000000;
		local yPos = floor(MetaMap_PartyNoteData.yPos * 1000000)/1000000;
		text = text.." x<"..xPos.."> y<"..yPos..">";
		text = text.." t<"..METAMAP_PARTYNOTE..">";
		text = text.." i1<>";
		text = text.." i2<>";
		text = text.." cr<"..pName..">";
		text = text.." i<0>";
		text = text.." tf<0>";
		text = text.." i1f<0>";
		text = text.." i2f<0>";
		text = text.." p<1>";
	elseif(MetaMap_MiniNote_Data.id == 0) then
		local xPos = floor(MetaMap_MiniNote_Data.xPos * 1000000)/1000000;
		local yPos = floor(MetaMap_MiniNote_Data.yPos * 1000000)/1000000;
		text = text.." x<"..xPos.."> y<"..yPos..">";
		text = text.." t<"..MetaMap_EliminateUsedChars(MetaMap_MiniNote_Data.name)..">";
		text = text.." i1<"..MetaMap_EliminateUsedChars(MetaMap_MiniNote_Data.inf1)..">";
		text = text.." i2<"..MetaMap_EliminateUsedChars(MetaMap_MiniNote_Data.inf2)..">";
		text = text.." cr<"..MetaMap_MiniNote_Data.creator..">";
		text = text.." i<"..MetaMap_MiniNote_Data.icon..">";
		text = text.." tf<"..MetaMap_MiniNote_Data.color..">";
		text = text.." i1f<"..MetaMap_MiniNote_Data.in1c..">";
		text = text.." i2f<"..MetaMap_MiniNote_Data.in2c..">";
	else
		if(not dataZone[MetaMap_TempData_Id].creator) then
			dataZone[MetaMap_TempData_Id].creator = pName;
		end
		local xPos = floor(dataZone[MetaMap_TempData_Id].xPos * 1000000)/1000000; --cut to six digits behind the 0
		local yPos = floor(dataZone[MetaMap_TempData_Id].yPos * 1000000)/1000000;
		text = text.." x<"..xPos.."> y<"..yPos..">";
		text = text.." t<"..MetaMap_EliminateUsedChars(dataZone[MetaMap_TempData_Id].name)..">";
		text = text.." i1<"..MetaMap_EliminateUsedChars(dataZone[MetaMap_TempData_Id].inf1)..">";
		text = text.." i2<"..MetaMap_EliminateUsedChars(dataZone[MetaMap_TempData_Id].inf2)..">";
		text = text.." cr<"..dataZone[MetaMap_TempData_Id].creator..">";
		text = text.." i<"..dataZone[MetaMap_TempData_Id].icon..">";
		text = text.." tf<"..dataZone[MetaMap_TempData_Id].ncol..">";
		text = text.." i1f<"..dataZone[MetaMap_TempData_Id].in1c..">";
		text = text.." i2f<"..dataZone[MetaMap_TempData_Id].in2c..">";
	end
	MetaMap_PartyNoteSet = false;
	return text;
end

function MetaMap_EliminateUsedChars(text)
	text = string.gsub(text, "<", "")
	text = string.gsub(text, ">", "")
	return text
end

function MetaMap_GetSendString(msg, who)
	local zone = gsub(msg,".*<MetaMap:MN> z<([^>]*)>.*","%1",1);
	local xPos = gsub(msg,".*<MetaMap:MN>%s+%w+.*x<([^>]*)>.*","%1",1)+0;
	local yPos = gsub(msg,".*<MetaMap:MN>%s+%w+.*y<([^>]*)>.*","%1",1)+0;
	local name = gsub(msg,".*<MetaMap:MN>%s+%w+.*t<([^>]*)>.*","%1",1);
	local inf1 = gsub(msg,".*<MetaMap:MN>%s+%w+.*i1<([^>]*)>.*","%1",1);
	local inf2 = gsub(msg,".*<MetaMap:MN>%s+%w+.*i2<([^>]*)>.*","%1",1);
	local creator = gsub(msg,".*<MetaMap:MN>%s+%w+.*cr<([^>]*)>.*","%1",1);
	local icon = gsub(msg,".*<MetaMap:MN>%s+%w+.*i<([^>]*)>.*","%1",1)+0;
	local ncol = gsub(msg,".*<MetaMap:MN>%s+%w+.*tf<([^>]*)>.*","%1",1)+0;
	local in1c = gsub(msg,".*<MetaMap:MN>%s+%w+.*i1f<([^>]*)>.*","%1",1)+0;
	local in2c = gsub(msg,".*<MetaMap:MN>%s+%w+.*i2f<([^>]*)>.*","%1",1)+0;
	local mLevel = gsub(msg,".*<MetaMap:MN>%s+%w+.*m<([^>]*)>.*","%1",1)+0;
	
	local mapName = MetaMap_GetZoneTableEntry(zone);
	local noteAdded, noteID = MetaMap_AddNewNote(mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c, MetaMap_SetNextAsMiniNote,mLevel);
	if(who == nil) then
		if(noteAdded) then
			MetaMap_Print(format(METAMAP_ACCEPT_NOTE, mapName), true);
		else
			MetaMap_Print(format(METAMAP_DECLINE_NOTE, MetaMap_Notes[mapName][noteID].name, mapName), true);
		end
	else
		if(noteAdded) then
			MetaMap_Print(format(METAMAP_ACCEPT_GET, who, mapName), true);
		else
			MetaMap_Print(format(METAMAP_DECLINE_GET, who, mapName, MetaMap_Notes[mapName][noteID].name), true);
		end
	end
	return noteAdded;
end

function MetaMap_Quicknote(msg)
	SetMapToCurrentZone();
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	local px, py = GetPlayerMapPosition("player");
	if(not dataZone or px == 0 or px == nil) then
		MetaMap_Print(METAMAP_INVALIDZONE, true);
		return;
	end
	local name = METAMAP_QUICKNOTE_DEFAULTNAME;
	if(msg ~= "" and msg ~= nil) then
		if(strlen(msg) == 1) then
			mode = tonumber(strsub(msg, 1, 1));
			msg = "";
		else
			local mCheck = strsub(msg, 1, 2);
			if(mCheck == "1 " or mCheck == "2 " or mCheck == "3 ") then
				mode = tonumber(strsub(msg, 1, 1));
				msg = strsub(msg, 3);
			else
				mode = MetaMap_SetNextAsMiniNote;
			end
		end
	else
		mode = MetaMap_SetNextAsMiniNote;
	end
	local i,j,x,y,tmp = string.find(msg,"%s*(%d+)%s*[,.]%s*(%d+)%s*([^%c]*)");
	if(x ~= nil and y ~= nil) then
		px = x / 100;
		py = y / 100;
		msg = tmp;
	end
	if(mode == 3) then
		MetaMap_vnote_xPos = px;
		MetaMap_vnote_yPos = py;
		MetaMap_Print(METAMAP_VNOTE_SET, true);
		return;
	end
	if msg ~= "" and msg ~= nil then
		name = string.sub(msg,string.find(msg,"%s*([^%c]*)"));
	end
	local noteAdded, noteID = MetaMap_AddNewNote(mapName, px, py, name, "", "", UnitName("player"), 0, 0, 0, 0, mode,GetCurrentMapDungeonLevel());
	if(noteAdded) then
		if(mode ~= 2) then
			MetaMap_Print(format(METAMAP_ACCEPT_NOTE, GetRealZoneText()), true);
		end
	else
		MetaMap_Print(format(METAMAP_DECLINE_NOTE, dataZone[noteID].name, GetRealZoneText()), true);
	end
	if(mode > 0) then
		MetaMap_Print(format(METAMAP_ACCEPT_MININOTE, GetRealZoneText()), true);
	end
	MetaMap_Qnote = false;
end

function MetaMap_QuickNoteShow()
	local x, y = GetPlayerMapPosition("player");
	local coords = format("%d, %d", x * 100, y * 100);
	Coords_EditBox:SetText(coords);
	MiniNote_CheckButton:SetChecked(false);
	MetaMap_Qnote = true;
end

function MetaMap_SetQuickNote(mode)
	local msg;
	if(mode == 1) then
		msg = Coords_EditBox:GetText().." "..Note_EditBox:GetText();
	else
		msg = "3 "..Coords_EditBox:GetText();
	end
	MetaMap_Quicknote(msg);
end

function MetaMap_GetNoteFromChat(msg, who)
	if(not MetaMapOptions.AcceptIncoming) then
		MetaMap_Print(format(METAMAP_DISABLED_GET, who), true)
		return;
	end
	if(gsub(msg,".*<MetaMap:MN>%s+%w+.*p<([^>]*)>.*","%1",1) == "1") then -- Party Note
		local id = -1;
		local zone = gsub(msg,".*<MetaMap:MN>%s+%w+.*z<([^>]*)>.*","%1",1);
		local xPos = gsub(msg,".*<MetaMap:MN>%s+%w+.*x<([^>]*)>.*","%1",1)+0;
		local yPos = gsub(msg,".*<MetaMap:MN>%s+%w+.*y<([^>]*)>.*","%1",1)+0;
		local icon = "party";
		local mapName = MetaMap_GetZoneTableEntry(zone);
		MetaMap_PartyNoteData.zone = mapName;
		MetaMap_PartyNoteData.xPos = xPos;
		MetaMap_PartyNoteData.yPos = yPos;
		if(MetaMapOptions.MiniParty) then
			MetaMap_AddMiniNote(id, mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c);
			MetaMap_Print(format(METAMAP_PARTY_GET, who, mapName), true)
		end
	else
		MetaMap_GetSendString(msg, who);
	end
end

function MetaMap_GetNoteBySlashCommand(msg)
	if(msg and msg ~= "") then
		msg = "<MetaMap:MN> "..msg;
		return MetaMap_GetSendString(msg);
	else
		MetaMap_Print(METAMAP_MAPNOTEHELP, true);
		return false;
	end
end



function MetaMap_Misc_OnClick(self, button)
	if(not MetaMap_FramesHidden()) then return; end
	if button == "LeftButton" then
		if(this:GetID() == 0) then
			MetaMap_TempData_Id = 0;
			MetaMap_EditExistingNote(MetaMap_TempData_Id);
		elseif(this:GetID() == 1) then
			MetaMap_PartyNoteSet = true;
			MetaMap_TempData_Id = -1;
			MetaMap_ShowSendFrame(0);
		end
	end
end

function MetaMap_NextMiniNote(msg)
	msg = string.lower(msg)
	if msg == "on" then
		MetaMap_SetNextAsMiniNote = 1
	elseif msg == "off" then
		MetaMap_SetNextAsMiniNote = 0
	elseif MetaMap_SetNextAsMiniNote == 1 then
		MetaMap_SetNextAsMiniNote = 0
	else
		MetaMap_SetNextAsMiniNote = 1
	end
end

function MetaMap_NextMiniNoteOnly(msg)
	msg = string.lower(msg)
	if msg == "on" then
		MetaMap_SetNextAsMiniNote = 2
	elseif msg == "off" then
		MetaMap_SetNextAsMiniNote = 0
	elseif MetaMap_SetNextAsMiniNote == 2 then
		MetaMap_SetNextAsMiniNote = 0
	else
		MetaMap_SetNextAsMiniNote = 2
	end
end

function MetaMap_MinimapUpdateZoom()
	if MetaMap_MiniNote_MapzoomInit then
		if MetaMap_MiniNote_IsInCity then
			MetaMap_MiniNote_IsInCity = false
		else
			MetaMap_MiniNote_IsInCity = true
		end
	else
		local tempzoom = 0
		if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
			if GetCVar("minimapInsideZoom")+0 >= 3 then
				Minimap:SetZoom(Minimap:GetZoom() - 1)
				tempzoom = 1
			else
				Minimap:SetZoom(Minimap:GetZoom() + 1)
				tempzoom = -1
			end
		end

		if GetCVar("minimapInsideZoom")+0 == Minimap:GetZoom() then
			MetaMap_MiniNote_IsInCity = true
		else
			MetaMap_MiniNote_IsInCity = false
		end

		Minimap:SetZoom(Minimap:GetZoom() + tempzoom)
		MetaMap_MiniNote_MapzoomInit = true
	end
end

function MetaMap_MiniNote_OnUpdate(elapsed)
	if(GetRealZoneText() ~= MetaMap_MiniNote_Data.zonetext) then
		MetaMap_MiniNote:Hide();
		return;
	end
	local zName, zIndex = MetaMap_GetZoneTableEntry(GetRealZoneText());
	local continent, zone = MetaMap_NameToZoneID(GetRealZoneText());
	if(not zIndex or continent ~= GetCurrentMapContinent() or zone ~= GetCurrentMapZone()) then return; end
	local x, y = GetPlayerMapPosition("player");
	if(x == 0 and y == 0) then return; end
	local currentSet = MetaMap_ZoneTable[zIndex];
	local currentZoom = Minimap:GetZoom();
	local xscale, yscale;
	if(zone >= 0) then
		xscale = MetaMap_MapScale[continent][currentZoom].xscale;
		yscale = MetaMap_MapScale[continent][currentZoom].yscale;
	else
		xscale = currentSet.xscale;
		yscale = currentSet.yscale;
	end
	if(MetaMap_MiniNote_IsInCity) then
		xscale = xscale * MetaMap_MapScale.cityscale[currentZoom].cityscale;
		yscale = yscale * MetaMap_MapScale.cityscale[currentZoom].cityscale;
	end
	local xpos = MetaMap_MiniNote_Data.xPos * currentSet.scale + currentSet.xoffset;
	local ypos = MetaMap_MiniNote_Data.yPos * currentSet.scale + currentSet.yoffset;
	x = x * currentSet.scale + currentSet.xoffset;
	y = y * currentSet.scale + currentSet.yoffset;
	local deltax = (xpos - x) * xscale;
	local deltay = (ypos - y) * yscale;
	if sqrt( (deltax * deltax) + (deltay * deltay) ) > 56.5 then
		local adjust = 1;
		if deltax == 0 then
			deltax = deltax + 0.0000000001;
		elseif deltax < 0 then
			adjust = -1;
		end
		local m = math.atan(deltay / deltax);
		deltax = math.cos(m) * 57 * adjust;
		deltay = math.sin(m) * 57 * adjust;
	end
	MetaMap_MiniNote:SetPoint("CENTER", "MinimapCluster", "TOPLEFT", 105 + deltax, -93 - deltay);
	MetaMap_MiniNote:Show();
end

function MetaMap_MiniNote_OnClick(self, arg1)
	if(arg1 == "LeftButton" and IsShiftKeyDown()) then
		if(not ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Show(); end
		local coords = format("%d, %d", MetaMap_MiniNote_Data.xPos *100, MetaMap_MiniNote_Data.yPos *100);
		local msg = MetaMap_MiniNote_Data.name.." ("..GetRealZoneText().." - "..coords..")";
		ChatFrameEditBox:Insert(msg);
	else
		if(MetaMap_MiniNote_Data.id > 0) then
			SetMapToCurrentZone();
			if(not WorldMapFrame:IsVisible()) then
				MetaMapNotesEditFrame:SetParent("UIParent");
			end
			MetaMap_EditExistingNote(MetaMap_MiniNote_Data.id);
		elseif(MetaMap_MiniNote_Data.id == 0) then
			MetaMap_TempData_Id = 0;
			MetaMap_ShowSendFrame(0);
		else
			MetaMap_PartyNoteSet = true;
			MetaMap_TempData_Id = -1;
			MetaMap_ShowSendFrame(0);
		end
	end
end

function MetaMap_EditNewNote(ax, ay)
	if(not MetaMap_FramesHidden()) then return; end
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	local width = WorldMapButton:GetWidth();
	local height = WorldMapButton:GetHeight();
	local xOffset,yOffset;
	MetaMap_TempData_xPos = ax;
	MetaMap_TempData_yPos = ay;
	MetaMap_TempData_Id = nil;
	if ax*1002 >= (1002 - 195) then
		xOffset = ax * width - 176;
	else
		xOffset = ax * width;
	end
	if ay*668 <= (668 - 156) then
		yOffset = -(ay * height) - 75;
		else
		yOffset = -(ay * height) + 87;
	end
	if(MetaMap_TempData_Id == 0) then
		MetaMap_vnote_xPos = nil;
		MetaMap_vnote_yPos = nil;
	end
	MetaMap_TempData_Id = #(dataZone)+1;
	MetaMap_TempData_Creator = UnitName("player");
	MetaMap_Edit_SetIcon(0);
	MetaMap_Edit_SetTextColor(0);
	MetaMap_Edit_SetInfo1Color(0);
	MetaMap_Edit_SetInfo2Color(0);
	TitleWideEditBox:SetText("");
	Info1WideEditBox:SetText("");
	Info2WideEditBox:SetText("");
	if(MetaMapOptions["AutoFillCoords"]) then
	
	TitleWideEditBox:SetText(format("%d, %d", ax*100, ay *100));
	
	else
	
	TitleWideEditBox:SetText("");
	
	end
	
	CreatorWideEditBox:SetText(MetaMap_TempData_Creator);
	MetaMap_HideAll();
	MetaMapNotesButtonMiniNoteOff:Disable();
	MetaMapNotesButtonMiniNoteOn:Disable();
	MetaMapNotesButtonDeleteNote:Disable();
	MetaMapNotesButtonToggleLine:Disable();
	MetaMap_SendNoteButton:Disable();
	MetaMapNotesButtonMoveNote:Disable();
	MetaMapNotesEditFrameTitle:SetText(METAMAP_NEW_NOTE);
	MetaMapNotesEditFrame:Show();
end

function MetaMap_EditExistingNote(id)
	MetaMap_HideAll();
	MetaMapNotesEditFrameTitle:SetText(METAMAP_EDIT_NOTE);
	if(MetaMap_MiniNote_Data.xPos == nil) then
		MetaMapNotesButtonMiniNoteOff:Disable();
	else
		MetaMapNotesButtonMiniNoteOff:Enable();
	end
	MetaMapNotesButtonMiniNoteOn:Enable();
	MetaMapNotesButtonDeleteNote:Enable();
	MetaMapNotesButtonToggleLine:Enable();
	MetaMapNotesButtonMoveNote:Enable();

	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	MetaMap_TempData_Id = id

	if(id == 0) then
		WorldMapPOIFrame.allowBlobTooltip = true;
		WorldMapTooltip:Hide();
		MetaMap_EditNewNote(MetaMap_vnote_xPos, MetaMap_vnote_yPos);
		return;
	elseif(id == -1) then
		WorldMapPOIFrame.allowBlobTooltip = true;
		WorldMapTooltip:Hide();
		MetaMap_EditNewNote(MetaMap_PartyNoteData.xPos, MetaMap_PartyNoteData.yPos);
		return;
	end
	MetaMap_TempData_LootID = nil;
	if(dataZone[MetaMap_TempData_Id].lootid ~= nil)then
		MetaMap_TempData_LootID = dataZone[MetaMap_TempData_Id].lootid
	end
	MetaMap_TempData_Zone = mapName;
	MetaMap_TempData_Name = dataZone[MetaMap_TempData_Id].name;
	MetaMap_TempData_Creator = dataZone[MetaMap_TempData_Id].creator;
	MetaMap_TempData_xPos = dataZone[MetaMap_TempData_Id].xPos;
	MetaMap_TempData_yPos = dataZone[MetaMap_TempData_Id].yPos;
	MetaMap_Edit_SetIcon(dataZone[MetaMap_TempData_Id].icon);
	MetaMap_Edit_SetTextColor(dataZone[MetaMap_TempData_Id].ncol);
	MetaMap_Edit_SetInfo1Color(dataZone[MetaMap_TempData_Id].in1c);
	MetaMap_Edit_SetInfo2Color(dataZone[MetaMap_TempData_Id].in2c);
	TitleWideEditBox:SetText(dataZone[MetaMap_TempData_Id].name);
	Info1WideEditBox:SetText(dataZone[MetaMap_TempData_Id].inf1);
	Info2WideEditBox:SetText(dataZone[MetaMap_TempData_Id].inf2);
	CreatorWideEditBox:SetText(dataZone[MetaMap_TempData_Id].creator);
	MetaMapNotesEditFrame:Show();
end

function MetaMap_NoteEditorSave()
	MetaMap_HideAll();
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	if(not dataZone) then return; end
	dataZone[MetaMap_TempData_Id] = {};
	dataZone[MetaMap_TempData_Id].name = TitleWideEditBox:GetText();
	dataZone[MetaMap_TempData_Id].ncol = MetaMap_TempData_TextColor;
	dataZone[MetaMap_TempData_Id].inf1 = Info1WideEditBox:GetText();
	dataZone[MetaMap_TempData_Id].in1c = MetaMap_TempData_Info1Color;
	dataZone[MetaMap_TempData_Id].inf2 = Info2WideEditBox:GetText();
	dataZone[MetaMap_TempData_Id].in2c = MetaMap_TempData_Info2Color;
	dataZone[MetaMap_TempData_Id].creator = CreatorWideEditBox:GetText();
	dataZone[MetaMap_TempData_Id].icon = MetaMap_TempData_Icon;
	dataZone[MetaMap_TempData_Id].xPos = MetaMap_TempData_xPos;
	dataZone[MetaMap_TempData_Id].yPos = MetaMap_TempData_yPos;
	dataZone[MetaMap_TempData_Id].mLevel = GetCurrentMapDungeonLevel();

	if(MetaMap_TempData_LootID ~= nil)then
		dataZone[MetaMap_TempData_Id].lootid = MetaMap_TempData_LootID;
		MetaMap_TempData_LootID = nil;
	end
	if(mapName == MetaMap_MiniNote_Data.zonetext and MetaMap_MiniNote_Data.id == MetaMap_TempData_Id) then
		MetaMap_MiniNote_Data.zonetext = mapName;
		MetaMap_MiniNote_Data.name = TitleWideEditBox:GetText();
		MetaMap_MiniNote_Data.icon = MetaMap_TempData_Icon;
		MetaMap_MiniNoteTexture:SetTexture(METAMAP_ICON_PATH.."Icon"..MetaMap_MiniNote_Data.icon);
		MetaMap_MiniNote_Data.inf1 = Info1WideEditBox:GetText();
		MetaMap_MiniNote_Data.inf2 = Info2WideEditBox:GetText();
		MetaMap_MiniNote_Data.in1c = MetaMap_TempData_Info1Color;
		MetaMap_MiniNote_Data.in2c = MetaMap_TempData_Info2Color;
		MetaMap_MiniNote_Data.color = MetaMap_TempData_TextColor;
		MetaMap_MiniNote_Data.creator = CreatorWideEditBox:GetText();
	end
	if(MetaMap_vnote_xPos == MetaMap_TempData_xPos and MetaMap_vnote_yPos == MetaMap_TempData_yPos) then
		MetaMap_vnote_xPos = nil;
		MetaMap_vnote_yPos = nil;
	end
	MetaMap_MainMapUpdate();
end

function MetaMap_ShowSendFrame(mode)
	MetaMap_SendPlayer:Disable();
	MetaMap_SendParty:Disable();
	MetaMap_SendGuild:Disable();
	MetaMap_ChangeSendFrame:Enable();
	SendWideEditBox:Show();
	MetaMap_SendFramePlayer:Show();
	MetaMap_DeletePartyNote:Hide();
	if(mode == 0) then
		if(GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) then MetaMap_SendParty:Enable(); end
		if(IsInGuild()) then MetaMap_SendGuild:Enable(); end
		MetaMap_DeletePartyNote:Show();
		MetaMap_ChangeSendFrame:Disable();
		MetaMap_SendFramePlayer:Hide();
		SendWideEditBox:Hide();
	elseif(mode == 1) then
		MetaMap_ToggleSendValue = 2;
		if(GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) then MetaMap_SendParty:Enable(); end
		if(IsInGuild()) then MetaMap_SendGuild:Enable(); end
		SendWideEditBox:SetText("");
		MetaMap_SendFrameTitle:SetText(METAMAP_SEND_NOTE);
		MetaMap_SendFrameTip:SetText(METAMAP_SEND_TIP);
		MetaMap_SendFramePlayer:SetText(METAMAP_SEND_PLAYER);
		MetaMap_ChangeSendFrame:SetText(METAMAP_SLASHCOMMAND);
	elseif(mode == 2) then
		MetaMap_ToggleSendValue = 1;
		MetaMap_SendFrameTitle:SetText(METAMAP_SEND_SLASHTITLE);
		MetaMap_SendFrameTip:SetText(METAMAP_SEND_SLASHTIP);
		MetaMap_SendFramePlayer:SetText(METAMAP_SEND_SLASHCOMMAND);
		MetaMap_ChangeSendFrame:SetText(METAMAP_SHOWSEND);
		SendWideEditBox:SetText("/mapnote"..MetaMap_GenerateSendString(2));
	end
	if(not MetaMap_SendFrame:IsVisible()) then
		MetaMap_HideAll();
		MetaMap_SendFrame:Show();
	end
end

function MetaMap_Edit_SetIcon(icon)
	MetaMap_TempData_Icon = icon;
	IconOverlay:SetPoint("TOPLEFT", "EditIcon"..icon, "TOPLEFT", -3, 3);
end

function MetaMap_Edit_SetTextColor(color)
	MetaMap_TempData_TextColor = color
	TextColorOverlay:SetPoint("TOPLEFT", "TextColor"..color, "TOPLEFT", -3, 3)
end

function MetaMap_Edit_SetInfo1Color(color)
	MetaMap_TempData_Info1Color = color
	Info1ColorOverlay:SetPoint("TOPLEFT", "Info1Color"..color, "TOPLEFT", -3, 3)
end

function MetaMap_Edit_SetInfo2Color(color)
	MetaMap_TempData_Info2Color = color
	Info2ColorOverlay:SetPoint("TOPLEFT", "Info2Color"..color, "TOPLEFT", -3, 3)
end

function MetaMap_SendNote(mode)
	if(mode == 1) then
		if(strlen(SendWideEditBox:GetText()) > 1) then
			SendChatMessage(MetaMap_GenerateSendString(1), "WHISPER", this.language, SendWideEditBox:GetText())
			MetaMap_Print(format(METAMAP_NOTE_SENT, SendWideEditBox:GetText()), true);
		else
			MetaMap_Print(METAMAP_NOPLAYER, true);
		end
	elseif(mode == 2) then
		if(GetNumRaidMembers() > 0) then
			SendAddonMessage("MetaMap:MN", MetaMap_GenerateSendString(1), "RAID");
			MetaMap_Print(METAMAP_RAIDSENT, true);
		elseif(GetNumPartyMembers() > 0) then
			SendAddonMessage("MetaMap:MN", MetaMap_GenerateSendString(1), "PARTY");
			MetaMap_Print(METAMAP_PARTYSENT, true);
		else
			MetaMap_Print(METAMAP_NOPARTY, true);
		end
	elseif(mode == 3) then
		if(IsInGuild()) then
			SendAddonMessage("MetaMap:MN", MetaMap_GenerateSendString(1), "GUILD");
			MetaMap_Print(METAMAP_GUILDSENT, true);
		else
			MetaMap_Print(METAMAP_NOGUILD, true);
		end
	end
	MetaMap_HideAll()
end

function MetaMap_ClearMiniNote(skipMapUpdate)
	MetaMap_MiniNote_Data = {};
	if(MetaMap_PartyNoteData ~= nil) then
		MetaMap_DeleteMapNote(-1)
	end
	MetaMap_MiniNote:Hide();
	MetaMapNotesButtonMiniNoteOff:Disable();
	if not skipMapUpdate then
		MetaMap_MainMapUpdate();
	end
end

function MetaMap_MainMapUpdate()
	if(WorldMapButton:IsVisible() or MetaMapFrame:IsVisible()) then
		MetaMap_WorldMapButton_OnUpdate();
	end
	if(Minimap:IsVisible()) then
		MinimapPing_OnUpdate(Minimap, 0); --3.0.2
	end
end

function MetaMap_HideAll()
	MetaMapNotesEditFrame:Hide()
	MetaMap_SendFrame:Hide()
	MetaMap_QuickNoteFrame:Hide()
	MetaMap_ClearGUI()
end

function MetaMap_FramesHidden()
	if(MetaMapNotesEditFrame:IsVisible() or MetaMap_SendFrame:IsVisible()
			or  MetaMap_QuickNoteFrame:IsVisible()) then
		return false;
	else
		return true;
	end
end

function MetaMap_MapNoteOnEnter(id)
    --MetaMap_Debug_Print("MapNoteOnEnter", true);
	if MetaMap_FramesHidden() then
	   
		--MetaMap_Debug_Print("MapNoteOnEnter:Showing", true);
		local x, y = this:GetCenter()
		local x2, y2 = WorldMapButton:GetCenter()
		local anchor = ""
		if x > x2 then
			anchor = "ANCHOR_LEFT"
		else
			anchor = "ANCHOR_RIGHT"
		end
		WorldMapTooltip:SetOwner(this, anchor)
		if id	== 0 then
			WorldMapTooltip:SetText(METAMAP_VNOTE_DEFAULTNAME)
		elseif id	== -1 then
			WorldMapTooltip:SetText(METAMAP_PARTYNOTE)
		else
			local mapName, dataZone = MetaMap_GetCurrentMapInfo();
			if(not dataZone) then return; end
			local blt = "";
			local cNr = dataZone[id].ncol
			if(dataZone[id].lootid ~= nil and dataZone[id].lootid ~= "") then
				blt = "|cffff00ffBLT";
			end
			WorldMapTooltip:AddDoubleLine(dataZone[id].name, blt, MetaMap_Colors[cNr].r, MetaMap_Colors[cNr].g, MetaMap_Colors[cNr].b, MetaMapOptions.TooltipWrap)
			if dataZone[id].inf1 ~= nil and dataZone[id].inf1 ~= "" then
				cNr = dataZone[id].in1c
				WorldMapTooltip:AddLine(dataZone[id].inf1, MetaMap_Colors[cNr].r, MetaMap_Colors[cNr].g, MetaMap_Colors[cNr].b, MetaMapOptions.TooltipWrap)
			end
			if dataZone[id].inf2 ~= nil and dataZone[id].inf2 ~= "" then
				cNr = dataZone[id].in2c
				WorldMapTooltip:AddLine(dataZone[id].inf2, MetaMap_Colors[cNr].r, MetaMap_Colors[cNr].g, MetaMap_Colors[cNr].b, MetaMapOptions.TooltipWrap)
			end
			if(dataZone[id].creator ~= nil and dataZone[id].creator ~= "" and MetaMapOptions.ShowCreator) then
				WorldMapTooltip:AddDoubleLine(METAMAP_CREATEDBY, dataZone[id].creator, 0, 0.75, 0.85, 0, 0.75, 0.85);
			end
		end
		WorldMapPOIFrame.allowBlobTooltip = false;
		WorldMapTooltip:Show();
	else
		WorldMapPOIFrame.allowBlobTooltip = true;
		WorldMapTooltip:Hide();
	end
end

function MetaMap_MiniNote_OnEnter()
	GameTooltip:SetOwner(this, "ANCHOR_CURSOR");
	if(MetaMap_MiniNote_Data.id == -1) then
		GameTooltip:SetText(METAMAP_PARTYNOTE);
	else
		GameTooltip:SetText(MetaMap_MiniNote_Data.name,
		MetaMap_Colors[MetaMap_MiniNote_Data.color].r,
		MetaMap_Colors[MetaMap_MiniNote_Data.color].g,
		MetaMap_Colors[MetaMap_MiniNote_Data.color].b, MetaMapOptions.TooltipWrap);

		GameTooltip:AddLine(MetaMap_MiniNote_Data.inf1,
		MetaMap_Colors[MetaMap_MiniNote_Data.in1c].r,
		MetaMap_Colors[MetaMap_MiniNote_Data.in1c].g,
		MetaMap_Colors[MetaMap_MiniNote_Data.in1c].b, MetaMapOptions.TooltipWrap);

		GameTooltip:AddLine(MetaMap_MiniNote_Data.inf2,
		MetaMap_Colors[MetaMap_MiniNote_Data.in2c].r,
		MetaMap_Colors[MetaMap_MiniNote_Data.in2c].g,
		MetaMap_Colors[MetaMap_MiniNote_Data.in2c].b, MetaMapOptions.TooltipWrap);
		if(MetaMap_MiniNote_Data.creator ~= nil and MetaMap_MiniNote_Data.creator ~= "" and MetaMapOptions.ShowCreator) then
			GameTooltip:AddDoubleLine(METAMAP_CREATEDBY, MetaMap_MiniNote_Data.creator, 0, 0.75, 0.85, 0, 0.75, 0.85);
		end
	end
	GameTooltip:Show();
end

function MetaMap_MapNote_OnClick(self, button, id)
	if(not MetaMap_FramesHidden()) then return; end
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	if(not dataZone) then return; end

	if MetaMap_LastLineClick.GUIactive then
		id = id + 0
		local ax = dataZone[id].xPos
		local ay = dataZone[id].yPos
		if (MetaMap_LastLineClick.x ~= ax or MetaMap_LastLineClick.y ~= ay) and MetaMap_LastLineClick.mapName == mapName then
			MetaMap_ToggleLine(mapName, ax, ay, MetaMap_LastLineClick.x, MetaMap_LastLineClick.y)
		end
		MetaMap_ClearGUI()
	elseif(button == "LeftButton") then
		if(IsShiftKeyDown()) then
			if(not ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Show(); end
			local mode = 1;
			if(MetaMapFrame:IsVisible()) then mode = 2; end
			local tinf1 = dataZone[id].inf1;
			local coords = format("%d, %d", dataZone[id].xPos *100, dataZone[id].yPos *100);
			if(strlen(tinf1) > 0) then tinf1 = " ["..tinf1.."] "; end
			local msg = dataZone[id].name.." "..tinf1.." ("..mapName.." - "..coords..")";
			ChatFrameEditBox:Insert(msg);
		elseif(IsControlKeyDown()) then
			local LootID = dataZone[id].lootid;
			local Name = dataZone[id].name;
			MetaMap_LoadBLT(LootID, Name);
		elseif(dataZone[id].icon ~= 10) then
			local width = WorldMapButton:GetWidth()
			local height = WorldMapButton:GetHeight()
			id = id + 0
			MetaMap_TempData_Id = id
			local ax = dataZone[id].xPos
			local ay = dataZone[id].yPos
			if ax*1002 >= (1002 - 195) then
				xOffset = ax * width - 176
			else
				xOffset = ax * width
			end
			if ay*668 <= (668 - 156) then
				yOffset = -(ay * height) - 75
			else
				yOffset = -(ay * height) + 113
			end
			MetaMap_SendNoteButton:Enable()
			WorldMapPOIFrame.allowBlobTooltip = true;			
			WorldMapTooltip:Hide()
			MetaMap_EditExistingNote(MetaMap_TempData_Id)
		end
	elseif(button == "RightButton") then
		if(IsControlKeyDown()) then
			MetaMapNotes_CRBSelect(id);
		elseif(IsShiftKeyDown() and MetaMap_LoadNBK(1)) then
			NBK_SetTargetNote(dataZone[id].name);
		elseif(not MetaMapFrame:IsVisible()) then
			MetaMap_LoadBWP(this:GetID(), 2);
		end
	end
end

function MetaMap_StartGUIToggleLine()
	MetaMap_HideAll()
	MetaMapText_NoteTotals:SetText("|cffffffff"..METAMAP_CLICK_ON_SECOND_NOTE)
	MetaMap_LastLineClick.GUIactive = true
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	MetaMap_LastLineClick.x = dataZone[MetaMap_TempData_Id].xPos
	MetaMap_LastLineClick.y = dataZone[MetaMap_TempData_Id].yPos
	MetaMap_LastLineClick.mapName = mapName;
end

function MetaMap_StartMoveNote(ID)
	MetaMap_HideAll()
	MetaMapText_NoteTotals:SetText("|cffffffff"..METAMAP_CLICK_ON_LOCATION);
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	MetaMap_Relocate.mapName = mapName;
	MetaMap_Relocate.id = ID;
end

function MetaMap_MoveNote(mapName, id)
	local zoneTable = MetaMap_Lines[mapName]
	local lineCount = #(zoneTable)
	local currentX = MetaMap_Notes[mapName][id].xPos;
	local currentY = MetaMap_Notes[mapName][id].yPos;
	local centerX, centerY = WorldMapButton:GetCenter();
	local width = WorldMapButton:GetWidth();
	local height = WorldMapButton:GetHeight();
	local x, y = GetCursorPosition();
	x = x / WorldMapButton:GetEffectiveScale();
	y = y / WorldMapButton:GetEffectiveScale();
	
	if(centerX == nil) then
		centerX = 0;
	end
	
	if(centerY == nil) then
		centerY = 0;
	end
	
	local adjustedY = (centerY + height/2 - y) / height;
	local adjustedX = (x - (centerX - width/2)) / width;
	MetaMap_Notes[mapName][id].xPos = adjustedX;
	MetaMap_Notes[mapName][id].yPos = adjustedY;
	if(MetaMap_MiniNote_Data.id == id) then
		MetaMap_MiniNote_Data.xPos = adjustedX;
		MetaMap_MiniNote_Data.yPos = adjustedY;
	end
	for i = 1, lineCount, 1 do
		if i <= lineCount then
			if(zoneTable[i].x1 == currentX and zoneTable[i].y1 == currentY) then
				zoneTable[i].x1 = adjustedX;
				zoneTable[i].y1 = adjustedY;
			elseif(zoneTable[i].x2 == currentX and zoneTable[i].y2 == currentY) then
				zoneTable[i].x2 = adjustedX;
				zoneTable[i].y2 = adjustedY;
			end
		end
	end
	MetaMap_MainMapUpdate();
end

function MetaMap_ClearGUI()
	MetaMap_LastLineClick.GUIactive = false;
	MetaMap_Relocate = {};
end

function MetaMap_DrawLine(id, x1, y1, x2, y2)
	assert(x1 and y1 and x2 and y2)
	local MetaMapNotesLine = MetaMap_CreateLineObject(id);
	local positiveSlopeTexture = METAMAP_IMAGE_PATH.."LineTemplatePositive256"
	local negativeSlopeTexture = METAMAP_IMAGE_PATH.."LineTemplateNegative256"
	local width = WorldMapDetailFrame:GetWidth()
	local height = WorldMapDetailFrame:GetHeight()
	local deltax = math.abs((x1 - x2) * width)
	local deltay = math.abs((y1 - y2) * height)
	local xOffset = math.min(x1,x2) * width
	local yOffset = -(math.min(y1,y2) * height)
	local lowerpixel = math.min(deltax, deltay)
	lowerpixel = lowerpixel / 256
	if lowerpixel > 1 then
		lowerpixel = 1
	end
	if deltax == 0 then
		deltax = 2
		MetaMapNotesLine:SetTexture(0, 0, 0)
		MetaMapNotesLine:SetTexCoord(0, 1, 0, 1)
	elseif deltay == 0 then
		deltay = 2
		MetaMapNotesLine:SetTexture(0, 0, 0)
		MetaMapNotesLine:SetTexCoord(0, 1, 0, 1)
	elseif x1 - x2 < 0 then
		if y1 - y2 < 0 then
			MetaMapNotesLine:SetTexture(negativeSlopeTexture)
			MetaMapNotesLine:SetTexCoord(0, lowerpixel, 0, lowerpixel)
		else
			MetaMapNotesLine:SetTexture(positiveSlopeTexture)
			MetaMapNotesLine:SetTexCoord(0, lowerpixel, 1-lowerpixel, 1)
		end
	else
		if y1 - y2 < 0 then
			MetaMapNotesLine:SetTexture(positiveSlopeTexture)
			MetaMapNotesLine:SetTexCoord(0, lowerpixel, 1-lowerpixel, 1)
		else
			MetaMapNotesLine:SetTexture(negativeSlopeTexture)
			MetaMapNotesLine:SetTexCoord(0, lowerpixel, 0, lowerpixel)
		end
	end

	if(MetaMapFrame:IsVisible()) then
		MetaMapNotesLine:SetPoint("TOPLEFT", "MetaMapFrame", "TOPLEFT", xOffset, yOffset)
	else
		MetaMapNotesLine:SetPoint("TOPLEFT", "WorldMapDetailFrame", "TOPLEFT", xOffset, yOffset)
	end
	MetaMapNotesLine:SetWidth(deltax)
	MetaMapNotesLine:SetHeight(deltay)
	MetaMapNotesLine:Show()
end

function MetaMap_ToggleLine(mapName, x1, y1, x2, y2)
	local newline = true;
	local lineTable = MetaMap_Lines[mapName];
	local lineCount = #(lineTable);

	for i = 1, lineCount, 1 do
		if i <= lineCount then
			if (lineTable[i].x1 == x1 and lineTable[i].y1 == y1 and
					lineTable[i].x2 == x2 and lineTable[i].y2 == y2) or
					(lineTable[i].x1 == x2 and lineTable[i].y1 == y2 and
					lineTable[i].x2 == x1 and lineTable[i].y2 == y1) then
				for j = i, lineCount-1, 1 do
					lineTable[j].x1 = lineTable[j+1].x1
					lineTable[j].x2 = lineTable[j+1].x2
					lineTable[j].y1 = lineTable[j+1].y1
					lineTable[j].y2 = lineTable[j+1].y2
				end
				lineTable[lineCount] = nil
				PlaySound("igMainMenuOption")
				newline = false
				lineCount = lineCount - 1
			end
		end
	end
	if(newline) then
		lineTable[lineCount+1] = {}
		lineTable[lineCount+1].x1 = x1
		lineTable[lineCount+1].x2 = x2
		lineTable[lineCount+1].y1 = y1
		lineTable[lineCount+1].y2 = y2
	end
	MetaMap_LastLineClick.zone = 0
	MetaMap_MainMapUpdate()
end

function MetaMap_SetPartyNote(xPos, yPos)
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	xPos = floor(xPos * 1000000) / 1000000
	yPos = floor(yPos * 1000000) / 1000000
	MetaMap_PartyNoteData.mapName = mapName;
	MetaMap_PartyNoteData.xPos = xPos;
	MetaMap_PartyNoteData.yPos = yPos;
	if MetaMap_MiniNote_Data.icon == "party" or MetaMapOptions.MiniParty then
		MetaMap_MiniNote_Data.zonetext = mapName;
		MetaMap_MiniNote_Data.id = -1;
		MetaMap_MiniNote_Data.xPos = xPos;
		MetaMap_MiniNote_Data.yPos = yPos;
		MetaMap_MiniNote_Data.name = METAMAP_PARTYNOTE;
		MetaMap_MiniNote_Data.color = 0;
		MetaMap_MiniNote_Data.icon = "party"
		MetaMap_MiniNoteTexture:SetTexture(METAMAP_ICON_PATH.."Icon"..MetaMap_MiniNote_Data.icon)
		MetaMap_MiniNote:Show()
	end
	MetaMap_MainMapUpdate()
end

function MetaMap_WorldMapButton_OnClick(frame, button)
    MetaMap_Debug_Print("MetaMap_WorldMapButton_OnClick",true);

	if (not MetaMap_FramesHidden()) then return; end
	if BattlefieldMinimap and BattlefieldMinimap:IsVisible() and not MetaMapFrame:IsVisible() then
		if not MetaMap_CombatLockdown_BattlefiedMap then
			MetaMap_Reshow_BattlefiedMap = time()
		end
		MetaMap_CombatLockdown_BattlefiedMap = nil
		BattlefieldMinimap:Hide() --BattlefieldMinimap screws up the map selection
	end
	local mapName = MetaMap_GetCurrentMapInfo();
	if(mapName and MetaMap_Relocate.id) then
		if(button == "LeftButton" and not IsControlKeyDown() and not IsShiftKeyDown()) then
			MetaMap_MoveNote(MetaMap_Relocate.mapName, MetaMap_Relocate.id)
			MetaMap_Relocate = {};
			return;
		end
	end
	
	if(button == "LeftButton" and (IsControlKeyDown() or IsShiftKeyDown() or IsAltKeyDown())) then
		if(mapName or MetaMapFrame:IsVisible() or MetaMapOptions.ShowDNI) then
			local centerX, centerY = WorldMapButton:GetCenter()
			local width = WorldMapButton:GetWidth()
			local height = WorldMapButton:GetHeight()
			local x, y = GetCursorPosition()
			x = x / WorldMapButton:GetEffectiveScale()
			y = y / WorldMapButton:GetEffectiveScale()
			
			if(centerX == nil) then
				centerX = 0;
			end
	
			if(centerY == nil) then
				centerY = 0;
			end
			
			local adjustedY = (centerY + height/2 - y) / height
			local adjustedX = (x - (centerX - width/2)) / width
		
			if(IsShiftKeyDown()) then
				MetaMap_SetPartyNote(adjustedX, adjustedY);
			elseif(IsControlKeyDown()) then
				local _, dataZone = MetaMap_GetCurrentMapInfo();
				if dataZone then MetaMap_EditNewNote(adjustedX, adjustedY) end
			elseif(IsAltKeyDown() and MetaMap_GetCurrentMapInfo() == GetRealZoneText()) then
				MetaMap_LoadBWP(0, 3);
				if(IsAddOnLoaded("MetaMapBWP")) then
					BWP_LocCommand(format("%d, %d", 100 * adjustedX, 100 * adjustedY));
				end
			end
		end
	elseif(button == "LeftButton" and MetaMapFrame:IsVisible()) then
		-- MetaMap_OrigWorldMapButton_OnClick(WorldMapFrame, button);
		 --WorldMapFrame_DisplayQuests();
      --WorldMapQuestFrame_UpdateMouseOver();
		return;
	elseif(button == "RightButton" and MetaMapFrame:IsVisible()) then
		MetaMap_ShowInstance(false);
	else
	 
		MetaMap_OrigWorldMapButton_OnClick(frame, button);
	end
end

function MetaMap_WorldMapButton_OnUpdate(self, elapsed)
	if(not MetaMap_VarsLoaded or MetaMap_Drawing) then return; end
	local lastNote = 0;
	local lastLine = 0;
	local showLine = true;
	local xOffset,yOffset = 0;
	local currentLineZone;
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	MetaMap_Drawing = true;
	if(dataZone) then
		currentLineZone = MetaMap_Lines[mapName];
		if(currentLineZone) then
			for i,line in ipairs(currentLineZone) do
				MetaMap_DrawLine(i, line.x1, line.y1, line.x2, line.y2)
				lastLine = i;
			end
		end
		for i, value in ipairs(dataZone) do
		 
		 
			local temp = MetaMap_CreateNoteObject(i);
			local xPos = dataZone[i].xPos;
			local yPos = dataZone[i].yPos;
			local xOffset = xPos * WorldMapButton:GetWidth();
			local yOffset = -yPos * WorldMapButton:GetHeight();
			if(MetaMapFrame:IsVisible()) then
				temp:SetParent("MetaMapFrame");
				temp:SetPoint("CENTER", "MetaMapFrame", "TOPLEFT", xOffset, yOffset)
			else
				temp:SetParent("WorldMapButton");
				temp:SetPoint("CENTER", "WorldMapButton", "TOPLEFT", xOffset, yOffset)
			end
			getglobal("MetaMapNotesPOI"..i.."Texture"):SetTexture(METAMAP_ICON_PATH.."Icon"..dataZone[i].icon)
			getglobal("MetaMapNotesPOI"..i.."Highlight"):Hide();
			for landmarkIndex = 1, GetNumMapLandmarks(), 1 do
				local worldMapPOI = getglobal("WorldMapFramePOI"..landmarkIndex);
				if(worldMapPOI == nil) then break; end
				local metaMapPOI = getglobal("MetaMapNotesPOI"..i);
				local name, unknown, textureIndex, x, y = GetMapLandmarkInfo(landmarkIndex);
				local xPosmin = xPos - 2; local xPosmax = xPos + 2;
				local yPosmin = yPos - 2; local yPosmax = yPos + 2;
				if((x > xPosmin and x < xPosmax) and (y > yPosmin and y < yPosmax)) then
					metaMapPOI:SetFrameLevel(worldMapPOI:GetFrameLevel() +1);
				end
			end
			
			
			if(dataZone[i].icon == 10) then
				if(dataZone[i].name == MetaMap_FilterName) then
					temp:Hide();
					showLine = false;
				else
					temp:Show();
				end
			elseif(MetaMap_NoteFilter[dataZone[i].icon]) then
				temp:Show();
			else
				MetaMap_FilterName = dataZone[i].name;
				temp:Hide();
				showLine = false;
			end
			if(not showLine) then
				for line = 1, lastLine, 1 do
					if(currentLineZone[line].x1 == xPos and currentLineZone[line].y1 == yPos) then
						getglobal("MetaMapNotesLines_"..line):Hide();
					elseif(currentLineZone[line].x2 == xPos and currentLineZone[line].y2 == yPos) then
						getglobal("MetaMapNotesLines_"..line):Hide();
					end
				end
			end
			
			if(dataZone[i].mLevel == nil or dataZone[i].mLevel == GetCurrentMapDungeonLevel()) then
			  temp:Show();
			else
			  temp:Hide();
			end 
			lastNote = i;
			showLine = true;
		 
		end
		if(MetaMapOptions.LastHighlight and lastNote ~= 0 and dataZone[lastNote].icon ~= 10) then
			if getglobal("MetaMapNotesPOI"..lastNote):IsVisible() then
				getglobal("MetaMapNotesPOI"..lastNote.."Highlight"):SetTexture(METAMAP_ICON_PATH.."IconGlowRed")
				getglobal("MetaMapNotesPOI"..lastNote.."Highlight"):Show();
			end
		end
		if(MetaMapOptions.LastMiniHighlight and MetaMap_MiniNote_Data.zonetext == mapName and MetaMap_MiniNote_Data.id > 0) then
			getglobal("MetaMapNotesPOI"..MetaMap_MiniNote_Data.id.."Highlight"):SetTexture(METAMAP_ICON_PATH.."IconGlowBlue")
			getglobal("MetaMapNotesPOI"..MetaMap_MiniNote_Data.id.."Highlight"):Show();
		end
		for i=lastNote+1, MetaMap_LastNote, 1 do
			getglobal("MetaMapNotesPOI"..i):Hide()
		end
		for i=lastLine+1, MetaMap_LastLine, 1 do
			getglobal("MetaMapNotesLines_"..i):Hide()
		end
	else
		for i=1, MetaMap_LastNote, 1 do
			getglobal("MetaMapNotesPOI"..i):Hide();
		end

		for i=1, MetaMap_LastLine, 1 do
			getglobal("MetaMapNotesLines_"..i):Hide();
		end
	end

	if(dataZone) then
		-- vNote button
		if(mapName and MetaMap_vnote_xPos ~= nil) then
			xOffset = MetaMap_vnote_xPos * WorldMapButton:GetWidth();
			yOffset = -MetaMap_vnote_yPos * WorldMapButton:GetHeight();
			if(MetaMapFrame:IsVisible()) then
				MetaMapNotesPOIvNote:SetPoint("CENTER", "MetaMapFrame", "TOPLEFT", xOffset, yOffset)
			else
				MetaMapNotesPOIvNote:SetPoint("CENTER", "WorldMapButton", "TOPLEFT", xOffset, yOffset)
			end
			MetaMapNotesPOIvNote:Show()
		else
			MetaMapNotesPOIvNote:Hide()
		end

	-- party note
		if(MetaMap_PartyNoteData.xPos ~= nil and mapName == MetaMap_PartyNoteData.mapName) then
			if MetaMapOptions.LastMiniHighlight and MetaMap_MiniNote_Data.icon == "party" then
				MetaMapNotesPOIpartyTexture:SetTexture(METAMAP_ICON_PATH.."Iconpartyblue")
			else
				MetaMapNotesPOIpartyTexture:SetTexture(METAMAP_ICON_PATH.."Iconparty")
			end
			xOffset = MetaMap_PartyNoteData.xPos * WorldMapButton:GetWidth();
			yOffset = -MetaMap_PartyNoteData.yPos * WorldMapButton:GetHeight();
			if(MetaMapFrame:IsVisible()) then
				MetaMapNotesPOIparty:SetParent("MetaMapFrame");
				MetaMapNotesPOIparty:SetPoint("CENTER", "MetaMapFrame", "TOPLEFT", xOffset, yOffset)
			else
				MetaMapNotesPOIparty:SetParent("WorldMapButton");
				MetaMapNotesPOIparty:SetPoint("CENTER", "WorldMapButton", "TOPLEFT", xOffset, yOffset)
			end
			MetaMapNotesPOIparty:Show()
		else
			MetaMapNotesPOIparty:Hide()
		end
	end
	MetaMap_Drawing = nil
	MetaMapText_NoteTotals:SetText("|cff00ff00"..METAMAP_NOTES_SHOWN..": ".."|cffffffff"..(lastNote).."  ".."|cff00ff00"..METAMAP_LINES_SHOWN..": ".."|cffffffff"..(lastLine));
	MetaMapText_NoteTotals:Show();
	MetaMapList_Init();
	MetaMap_FilterName = "";
	if(IsAddOnLoaded("MetaMapTRK")) then
		TRK_DisplayNodes(mapName);
	end
	
	
end

function MetaMap_NotesListInit()
	local Temp_List = {};
	for mapName, indexTable in pairs(MetaMap_Notes) do
		for index, value in pairs(indexTable) do
			if(Temp_List[value.creator] == nil) then
				Temp_List[value.creator] = value.creator;
			end
		end
	end
	for index, creators in pairs(Temp_List) do
		local uText;
		if(Temp_List[index] == "") then
			uText = "Unsigned";
		else
			uText = Temp_List[index];
		end
		local info = {};
		info.checked = nil;
		info.notCheckable = 1;
		info.text = uText;
		info.value = uText;
		info.func = MetaMap_NotesList_OnClick;
		UIDropDownMenu_AddButton(info);
	end
end

function MetaMap_NotesList_OnClick()
	local creator = this.value;
	local button = UIDROPDOWNMENU_MENU_VALUE;
	button:SetText(creator);
	if(creator == "Unsigned") then
		cFlag = "";
	else
		cFlag = creator;
	end	
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	StaticPopupDialogs["Delete_Notes"] = {
		text = TEXT(format(METAMAP_BATCHDELETE, mapName, creator)),
		button1 = TEXT(ACCEPT),
		button2 = TEXT(DECLINE),
		OnAccept = function()
			MetaMap_DeleteNotes(cFlag, nil, mapName);
			button:SetText(METAMAP_OPTIONS_CCREATOR);
		end,
		OnCancel = function()
			button:SetText(METAMAP_OPTIONS_CCREATOR);
		end,
		timeout = 60,
		showAlert = 1,
	};
	StaticPopup_Show("Delete_Notes");
end

function MetaMap_DeleteNotes(creator, name, mapName)
	if(not creator) then return; end
	local continent;
	if(mapName) then
		for key, value in pairs(MetaMap_Continents) do
			if(mapName == value) then continent = key; end
		end
	end
	if(continent ~= nil or mapName == nil) then
		for zone, indexTable in pairs(MetaMap_Notes) do
			local cKey = MetaMap_NameToZoneID(zone);
			if(continent == cKey or continent == 0 or continent == -1 or continent == nil) then
				for id=#(indexTable), 1, -1 do
					if(creator == indexTable[id].creator and (name == indexTable[id].name or name == nil)) then
						MetaMap_DeleteMapNote(id, zone)
					end
				end
			end
		end
	else
		for id=#(MetaMap_Notes[mapName]), 1, -1 do
			if(creator == MetaMap_Notes[mapName][id].creator) then
				MetaMap_DeleteMapNote(id, mapName);
			end
		end
	end
	if(creator == "") then creator = "Unsigned"; end
	if(mapName ~= nil) then
		if(MetaMap_NotesDialog:IsVisible()) then
			MetaMap_OptionsInfo:SetText(format(METAMAP_DELETED_BY_ZONE, mapName, creator), true);
		else
			MetaMap_Print(format(METAMAP_DELETED_BY_ZONE, mapName, creator), true);
		end
	elseif(name ~= nil) then
		MetaMap_Print(format(METAMAP_DELETED_BY_NAME, creator, name), true);
	else
		MetaMap_Print(format(METAMAP_DELETED_BY_CREATOR, creator), true);
	end
end

function MetaMap_CheckLinks(id)
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	local name = dataZone[id].name;
	local count = 0;
	for i=1, 4, 1 do
		if(dataZone[id+i] ~= nil and dataZone[id+i].name == name and dataZone[id+i].icon == 10) then
			count = count +1;
		end
	end
	for i=1, count +1, 1 do
		MetaMap_DeleteMapNote(id, mapName);
	end
end

function MetaMap_DeleteLines(mapName, x, y)
	if(not x or not y) then return; end
	local lineTable = MetaMap_Lines[mapName]
	local lineCount = #(lineTable)
	local offset = 0

	for i = 1, lineCount, 1 do
		if (lineTable[i-offset].x1 == x and lineTable[i-offset].y1 == y) or (lineTable[i-offset].x2 == x and lineTable[i-offset].y2 == y) then
			for j = i, lineCount-1, 1 do
				lineTable[j-offset].x1 = lineTable[j+1-offset].x1
				lineTable[j-offset].x2 = lineTable[j+1-offset].x2
				lineTable[j-offset].y1 = lineTable[j+1-offset].y1
				lineTable[j-offset].y2 = lineTable[j+1-offset].y2
			end
			lineTable[lineCount-offset] = nil
			offset = offset + 1
		end
	end
	MetaMap_LastLineClick.zone = 0
end

function MetaMapPOI_OnEvent(mode)
	if(GetCurrentMapZone() == 0) then return; end
	local mapName, dataZone = MetaMap_GetCurrentMapInfo();
	local noteAdded1, noteAdded2;
	local name, unknown, textureIndex, x, y;
	local icon = 7; --was 8
	for landmarkIndex = 1, GetNumMapLandmarks(), 1 do
		name, unknown, textureIndex, x, y = GetMapLandmarkInfo(landmarkIndex);
		if (textureIndex == 15) then
			icon = 7; --was 5
		elseif (textureIndex == 6) then
			icon = 6;
		end
		if(mode == 1) then
			if(textureIndex==6) then
				noteAdded1 = MetaMap_AddNewNote(mapName, x, y, name, "", "", METAMAPPOI_NAME, icon, 6, 0, 0,nil,GetCurrentMapDungeonLevel());
			end
		else
			noteAdded2 = MetaMap_AddNewNote(mapName, x, y, name, "", "", METAMAPPOI_NAME, icon, 6, 0, 0,nil,GetCurrentMapDungeonLevel());
		end
	end
	if(noteAdded1 and noteAdded2) then
		MetaMap_Print("MetaMapPOI updated map notes for "..GetRealZoneText(), true);
	else
		if(noteAdded2) then
			MetaMap_Print("MetaMapPOI updated map notes for "..GetRealZoneText(), true);
		end
		if(noteAdded1) then
			MetaMap_Print("MetaMapPOI set Guard note for "..name, true);
		end
	end
end

function MetaMap_SortCriteria(a, b)
	if(MetaMap_sortType == METAMAP_SORTBY_NAME) then
		if (a.name < b.name) then
			return true;
		elseif (a.name > b.name) then
			return false;
		end
	elseif(MetaMap_sortType == METAMAP_SORTBY_DESC) then
		if (a.desc < b.desc) then
			return true;
		elseif (a.desc > b.desc) then
			return false;
		end
	elseif(MetaMap_sortType == METAMAP_SORTBY_LEVEL) then
		if (a.level < b.level) then
			return true;
		elseif (a.level > b.level) then
			return false;
		end
	elseif(MetaMap_sortType == METAMAP_SORTBY_LOCATION) then
		if (a.location < b.location) then
			return true;
		elseif (a.location > b.location) then
			return false;
		end
	else
		if (a < b) then
			return true;
		elseif (a > b) then
			return false;
		end
		if (a == nil) then
			if (b == nil) then
				return false;
			else
				return true;
			end
		elseif (b == nil) then
			return false;
		end
	end
end

function MetaMap_InvertList(list)
  local newlist = {};
  local count = #(list);
  for i=1,count
  do
    table.insert(newlist, list[(count +1) -i]);
  end
  return newlist;
end

function MetaMap_InfoLine(button)
	if(button == "RightButton") then
		MetaMapOptions.ShowMapList = not MetaMapOptions.ShowMapList;
		MetaMapOptions_Init();
		return;
	end
	if(MetaMap_InfoLineFrame:IsVisible()) then
		MetaMapContainer_ShowFrame();
		return;
	end
	MetaMap_InfoLineUpdate();
end

function MetaMap_InfoLineUpdate()
	local header = "";
	local zName, zIndex, zType = MetaMap_GetZoneTableEntry(MetaMap_GetCurrentMapInfo());
	if(zType == "DN") or (zType == "DNI") then
		header = METAMAP_STRING_LOCATION..": ".."|cffffffff"..MetaMap_ZoneTable[zIndex].Location.."|r";
		header = header.."   "..METAMAP_STRING_LEVELRANGE..": ".."|cffffffff"..MetaMap_ZoneTable[zIndex].LevelRange.."|r";
		header = header.."   "..METAMAP_STRING_PLAYERLIMIT..": ".."|cffffffff"..MetaMap_ZoneTable[zIndex].PlayerLimit.."|r";
		MetaMap_InfoLineFrameText:SetText(MetaMap_ZoneTable[zIndex].infoline);
	else
		header = "|cffffffff"..MetaMap_GetCurrentMapInfo().."|r";
		MetaMap_InfoLineFrameText:SetText(METAMAP_FURINF);
	end
	MetaMapContainer_ShowFrame(MetaMap_InfoLineFrame, header);
end

function MetaMap_InfoLineOnEnter()
	MetaMap_SetTTInfoLine(MetaMap_GetCurrentMapInfo(), this, WorldMapTooltip);
	WorldMapTooltip:AddLine(METAMAP_INFOLINE_HINT1, 0.75, 0, 0.75, false);
	WorldMapTooltip:AddLine(METAMAP_INFOLINE_HINT2, 0.75, 0, 0.75, false);
	WorldMapTooltip:AddLine(" ");
	WorldMapTooltip:AddLine(METAMAP_INFOLINE_HINT3, 0.40, 0.40, 0.40, false);
	WorldMapTooltip:AddLine(METAMAP_INFOLINE_HINT4, 0.40, 0.40, 0.40, false);
	
	WorldMapPOIFrame.allowBlobTooltip = false;
	WorldMapTooltip:Show()
	--WorldMapTooltip:SetFrameLevel(WorldMapFrame:GetFrameLevel()+20);
end

function MetaMap_SetTTInfoLine(zoneName, Button, Tooltip)
	local zName, zIndex, zType = MetaMap_GetZoneTableEntry(zoneName);
	Tooltip:SetOwner(Button, "ANCHOR_BOTTOMLEFT");
	if(zType == "DN" or zType == "DNI") then
		Tooltip:SetText(zName, 1, 1, 0, false);
		Tooltip:AddLine(METAMAP_STRING_LOCATION..": ".."|cffffffff"..MetaMap_ZoneTable[zIndex].Location, 1, 1, 0, false);
		Tooltip:AddLine(METAMAP_STRING_LEVELRANGE..": ".."|cffffffff"..MetaMap_ZoneTable[zIndex].LevelRange, 1, 1, 0, false);
		Tooltip:AddLine(METAMAP_STRING_PLAYERLIMIT..": ".."|cffffffff"..MetaMap_ZoneTable[zIndex].PlayerLimit, 1, 1, 0, false);
		Tooltip:AddLine(" ");
		Tooltip:AddDoubleLine(METAMAP_SEVEDINSTANCES, "ID:");
		if(GetNumSavedInstances() > 0) then
			for i=1, GetNumSavedInstances() do
				local name, ID, remaining = GetSavedInstanceInfo(i);
				remaining = SecondsToTime(remaining);
				Tooltip:AddDoubleLine(name, "|cffffffff"..ID, 0, 1, 0, false);
				Tooltip:AddLine("|cffffffff"..remaining);
			end
		else
			Tooltip:AddLine(METAMAP_NO_SAVED_INSTANCES);
		end
	elseif(zType == "SZ" or zType == "BG") then
		local fColor = {}; local lColor = {};
		local Neutral = { r = 0.9, g = 0.8, b = 0.2 };
		local Friendly = { r = 0.2, g = 0.9, b = 0.2 };
		local Hostile = { r = 0.9, g = 0.2, b = 0.2 };
		local Contested = { r = 0.8, g = 0.6, b = 0.4 };
		local _, faction = UnitFactionGroup("player");
		if(MetaMap_ZoneTable[zIndex].faction == "Contested") then
			fColor = Contested;				
		elseif(MetaMap_ZoneTable[zIndex].faction == "Neutral") then
			fColor = Neutral;
		elseif(MetaMap_ZoneTable[zIndex].faction == faction) then
			fColor = Friendly;
		else
			fColor = Hostile;
		end
		if(UnitLevel("player") > MetaMap_ZoneTable[zIndex].hlvl) then
			lColor = { r = 0.5, g = 0.5, b = 0.5 };				
		elseif(UnitLevel("player") < MetaMap_ZoneTable[zIndex].llvl) then
			lColor = Hostile;
		else
			lColor = Friendly;
		end
		Tooltip:AddDoubleLine(zName, MetaMap_ZoneTable[zIndex].faction, fColor.r, fColor.g, fColor.b, fColor.r, fColor.g, fColor.b, false);
		Tooltip:AddDoubleLine(METAMAP_STRING_LEVELRANGE, MetaMap_ZoneTable[zIndex].llvl.." - "..MetaMap_ZoneTable[zIndex].hlvl, 1, 1, 0, lColor.r, lColor.g, lColor.b, false);
	else
		Tooltip:SetText(zoneName, 1, 1, 1, false);
	end
	Tooltip:AddLine(" ");

	Tooltip:Show();
end

function MetaMap_ToggleOptions(key, value)
	if(value) then
		MetaMapOptions[key] = value;
	else
		MetaMapOptions[key] = not MetaMapOptions[key];
	end
	MetaMapOptions_Init();
	return MetaMapOptions[key];
end

function MetaMap_SubMenuFix()
	local value, text;
	--MyPrint("this="..tostring(this:GetName()))
	if(not this.value) then
		 value = this:GetParent().value;
		 text = this:GetParent():GetName();
	else
		value = this.value;
		text = this:GetText();
	end
	return value, text;
end

function MetaMap_ColorSelect()
	local R, G, B = unpack(this.color)
	ColorPickerFrame.func = MetaMap_SetColor;
	ColorPickerFrame.cancelFunc = MetaMap_CancelColor;
	ColorPickerFrame.func2 = this.func;
	ColorPickerFrame.option = this.option;
	ColorPickerFrame.previousValues = {R, G, B};
	ColorPickerFrame:SetFrameStrata("FULLSCREEN");
	ColorPickerFrame:Show();
	ColorPickerFrame:SetColorRGB(R, G, B);
end

function MetaMap_SetColor()
	local R, G, B = ColorPickerFrame:GetColorRGB();
	ColorPickerFrame.func2(ColorPickerFrame.option, R, G, B);
end

function MetaMap_CancelColor(prevColors)
	local R, G, B = unpack(prevColors);
	ColorPickerFrame.func2(ColorPickerFrame.option, R, G, B);
end

function MetaMap_ContextHelp(title)
	if(not MetaMap_DialogFrame:IsVisible()) then
		MetaMapExtOptions_Toggle();
	end
	PanelTemplates_SetTab(MetaMap_DialogFrame,	6);
	if(MetaMap_LoadHLP()) then
		MetaMap_ToggleDialog("MetaMap_HelpDialog");
		HLP_DisplayOption(HLP_HelpData.Modules[title], 2, title);
	  UIDropDownMenu_SetText(HLP_MenuSelect, title);
  end
end

function MetaMap_CaptureZones()
	MetaMap_ZoneCapture = {};
	for continentKey,continentName in ipairs{GetMapContinents()} do
		MetaMap_ZoneCapture[continentKey] = {};
		for zoneKey,zoneName in ipairs{GetMapZones(continentKey)} do
			if(MetaMap_ZoneCapture[continentKey][zoneKey] == nil) then
				MetaMap_ZoneCapture[continentKey][zoneKey] = {};
			end
			MetaMap_ZoneCapture[continentKey][zoneKey] = zoneName;
		end
	end
	MetaMap_Print("New Zones captured to SavedVariables\\MetaMap.lua", true);
end

function MetaMap_DevTools()
	if(not IsAddOnLoaded("MetaMapXTM")) then
		LoadAddOn("MetaMapXTM");
	end
	if(IsAddOnLoaded("MetaMapXTM")) then
		XTM_MenuSelect();
	end
end

----------------
-- FuBar Support
----------------
function MetaMap_FuBar_OnLoad()
	if(AceLibrary("AceAddon-2.0") == nil) then return; end
	MetaMapFu = AceLibrary("AceAddon-2.0"):new("FuBarPlugin-2.0")
	MetaMapFu.hasIcon = METAMAP_ICON
	MetaMapFu.name = METAMAP_TITLE
	MetaMapFu.version = METAMAP_VERSION
	MetaMapFu.description = METAMAP_DESC
	MetaMapFu.category = "Map"
	MetaMapFu.hasNoText = true
	MetaMapFu.description = METAMAP_DESC

	function MetaMapFu:OnInitialize()
		if(FuBar2DB.profiles.Default.detached.MetaMap) then
			MetaMapFu.hideWithoutStandby = true;
		end
	end

	function MetaMapFu:OnClick()
		if(IsControlKeyDown()) then
			MetaMap_DevTools();
		else
			MetaMap_ToggleFrame(WorldMapFrame);
		end
	end

	function MetaMapFu:OnTooltipUpdate()
		GameTooltip:Hide();
		MetaMap_MainMenuSelect("FuBarPluginMetaMapFrame");
	end
end

----------------
-- Titan Support
----------------
function TitanPanelMetaMapButton_OnLoad()
	this.registry = { 
		id = TITAN_METAMAP_ID,
		version = METAMAP_VERSION,
		menuText = METAMAP_TITLE,
		category = METAMAP_CATEGORY,
		tooltipTitle = METAMAP_TITLE ,
		tooltipTextFunction = "TitanPanelMetaMapButton_GetTooltipText",
		frequency = TITAN_METAMAP_FREQUENCY, 
		icon = METAMAP_ICON,
		iconWidth = 16,
		savedVariables = {
		ShowIcon = 1,
		}
	};
end

function TitanPanelMetaMapButton_GetTooltipText()
	if(MetaMapOptions.MenuMode) then
		retText = METAMAP_BUTTON_TOOLTIP1.."\n"..METAMAP_BUTTON_TOOLTIP2;
		return retText;
	end
end

function TitanPanelMetaMapButton_OnClick(button)
	if ( button == "LeftButton" ) then
		MetaMap_ToggleFrame(WorldMapFrame);
	end
end

-----------
-- FlightMap
-----------
function FlightMapOptions_Toggle()
	FlightMapOptionsFrame:SetFrameStrata("FULLSCREEN");
	MetaMap_ToggleFrame(FlightMapOptionsFrame);
end

------------------------------------------------------------
--- The following functions are available for external calls
--- It is global so, simply CALL the function.
--- No need for hooking, unless stated otherwise. :)
------------------------------------------------------------
function MetaMap_SetNewNote(mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c, mininote,mLevel)
	local noteAdded, noteID = MetaMap_AddNewNote(mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c, mininote,mLevel);
	return noteAdded, noteID;
--[[Note accepted: noteAdded is returned as true, noteID  returns the NEW note index number.
		Note rejected: noteAdded is returned as false, noteID returns the NEAR note index number.
		The optional [mininote] parameter sets a Mininote as follows:
		0 - Sets Mapnote only
		1 - Sets Mapnote + Mininote
		2 - Sets Mininote only
		Nil or any other value defaults to value 0
]]
end

function MetaMap_SetMiniNote(id, mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c)
	MetaMap_AddMiniNote(id, mapName, xPos, yPos, name, inf1, inf2, creator, icon, ncol, in1c, in2c);
end

function MetaMap_RemoveMapNote(id, mapName)
	MetaMap_DeleteMapNote(id, mapName);
end

function MetaKBMenu_RBSelect(id)
	-- Initiated when RightClicking on KB display item.
	-- Slot assigned to MetaMapBWP.
end

function MetaKBMenu_CRBSelect(id)
	-- Available for other mods to run their own routine.
	-- Initiated when CTRL+RightClicking on KB display item.
	-- Usage: MetaKBMenu_CRBSelect = MyFunction
end

function MetaKBMenu_SRBSelect(id)
	-- Available for other mods to run their own routine.
	-- Initiated when Shift+RightClicking on KB display item.
	-- Usage: MetaKBMenu_SRBSelect = MyFunction
end

function MetaMapNotes_RBSelect(id)
	-- Initiated when RightClicking on a map note.
	-- Slot assigned to MetaMapBWP.
end

function MetaMapNotes_CRBSelect(id)
	-- Available for other mods to run their own routine.
	-- Initiated when CTRL+RightClicking on a map note.
	-- Usage: MetaMapNotes_CRBSelect = MyFunction
end

function MetaMapNotes_SRBSelect(id)
	-- Available for other mods to run their own routine.
	-- Initiated when Shift+RightClicking on a map note.
	-- Usage: MetaMapNotes_SRBSelect = MyFunction
end

-- manual fix for re-positioning of Stormwind City notes
-- ONLY EXECUTE THE FOLLOWING SLASH COMMAND IF YOU NEED -ALL- OF YOUR STORMWIND CITY NOTES ADJUSTING
-- Your Stormwind City note positions will be scaled and shifted to account for the new city map
-- This function for Stormwind map adjustments was borrowed from MapNotes
function MetaMapStormwindFix(again)
	if again and again ~= "again" then again = nil end
	if not again and MetaMap_Notes and MetaMap_Notes.StormwindFixed then
		MetaMap_Print(" The Stormwind City map notes were previously adjusted.", 1)
		MetaMap_Print(" If you are absolutely sure of what you are doing, you can force the adjustment again by typing"..
			" \'/script MetaMapStormwindFix(\"again\")\'", 1);	
		return
	end
	local x, y;	local moved = 0;
	if (MetaMap_Notes == nil) then MetaMap_Notes = {}; end
	for i, n in pairs(MetaMap_Notes["Stormwind City"]) do
		x = n.xPos * 0.76 + 0.203;
		if ( x > 0.9999 ) then x = 0.9999; end
		y = n.yPos * 0.76 + 0.253;
		if ( y > 0.9999 ) then y = 0.9999; end
		n.xPos = x;	n.yPos = y;
		moved = moved + 1;
	end
	MetaMap_Print(moved.." Stormwind City map notes were adjusted.", 1); -- msg, display, r, g, b
	MetaMap_Notes.StormwindFixed = nil --removed due to it causeing MetaMapEXP errors
end

function MetaMapStormwindUnfix(again)
	if again and again ~= "again" then again = nil end
	if not again and MetaMap_Notes and MetaMap_Notes.StormwindFixed then
		MetaMap_Print(" The Stormwind City map notes were previously un-adjusted.", 1)
		MetaMap_Print(" If you are absolutely sure of what you are doing, you can force the un-adjustment again by typing"..
			" \'/script MetaMapStormwindunfix(\"again\")\'", 1);	
		return
	end
	local x, y;	local moved = 0;
	if (MetaMap_Notes == nil) then MetaMap_Notes = {}; end
	for i, n in pairs(MetaMap_Notes["Stormwind City"]) do
		x = (n.xPos - 0.203 ) / 0.76;
		if ( x > 0.9999 ) then x = 0.9999; end
		y = (n.yPos - 0.253) / 0.76;
		if ( y > 0.9999 ) then y = 0.9999; end
		n.xPos = x;	n.yPos = y;
		moved = moved + 1;
	end
	MetaMap_Print(moved.." Stormwind City map notes were un-adjusted.", 1); -- msg, display, r, g, b
	MetaMap_Notes.StormwindFixed = nil --removed due to it causeing MetaMapEXP errors
end


--[[
continent, zone = MetaMap_NameToZoneID(zoneText)
Returns continent and zone IDs.

mapName, dataZone = MetaMap_GetCurrentMapInfo();
mapName returns currently displayed map.
dataZone returns 'MetaMap_Notes[mapNameIndex]'

There is also a 'Container' frame available for displaying data etc, within the WorldMap,
in the same format as the MetaMapWKB, MetaMapBLT, and MetaMapQST displays.
Referenced and parented as 'MetaMapContainerFrame'.
]]

