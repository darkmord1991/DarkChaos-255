-- MetaMap Export Module
-- Written by MetaHawk aka Urshurak

EXP_USERPATH  = " SavedVariables\\MetaMapEXP.lua";
EXP_USERNOTES = "MetaMapNotes";
EXP_USERWKB   = "MetaMapWKB";
EXP_USERQST   = "MetaMapQST";
EXP_USERTRK   = "MetaMapTRK";
EXP_USERNBK   = "MetaMapNBK";

local Notecount = 0;
local WKBcount  = 0;
local QSTcount  = 0;
local TRKcount  = 0;
local NBKcount  = 0;

function EXP_CheckData()
	MetaMap_OptionsInfo:SetText("MetaMap Exports module loaded");
	EXP_ConfirmationHeader:SetText(METAMAP_CONFIRM_EXPORT);
	EXP_SelectionButton1:SetText(EXP_USERNOTES);
	EXP_SelectionButton2:SetText(EXP_USERWKB);
	EXP_SelectionButton3:SetText(EXP_USERQST);
	EXP_SelectionButton4:SetText(EXP_USERTRK);
	EXP_SelectionButton5:SetText(EXP_USERNBK);
	if(not IsAddOnLoaded("MetaMapWKB")) then
		LoadAddOn("MetaMapWKB");
	end
	if(not IsAddOnLoaded("MetaMapWKB")) then
		EXP_SelectionButton2:Disable();
	end
	if(not IsAddOnLoaded("MetaMapQST")) then
		LoadAddOn("MetaMapQST");
	end
	if(not IsAddOnLoaded("MetaMapQST")) then
		EXP_SelectionButton3:Disable();
	end
	if(not IsAddOnLoaded("MetaMapTRK")) then
		LoadAddOn("MetaMapTRK");
	end
	if(not IsAddOnLoaded("MetaMapTRK")) then
		EXP_SelectionButton4:Disable();
	end
	if(not IsAddOnLoaded("MetaMapNBK")) then
		LoadAddOn("MetaMapNBK");
	end
	if(not IsAddOnLoaded("MetaMapNBK")) then
		EXP_SelectionButton5:Disable();
	end
	if(BKP_BackUpFrame) then BKP_BackUpFrame:Hide(); end
	if(CVT_ImportFrame) then CVT_ImportFrame:Hide(); end
	EXP_ExportFrame:Show();
end

function EXP_SelectedExport(mode)
	local msg = ""; WKBcount = 0; Notecount = 0;
	if(mode == EXP_USERWKB) then
		exp_MetaMap_Notes = nil;
		exp_MetaMap_Lines = nil;
		exp_QST_QuestBase = nil;
		exp_TRK_Data = nil;
		exp_NBK_NoteBookData = nil;
		EXP_ExportWKB();
		msg = format(METAMAPEXP_EXPORTED, WKBcount, EXP_USERWKB)..EXP_USERPATH;		
	elseif(mode == EXP_USERNOTES) then
		exp_WKB_Data = nil;
		exp_QST_QuestBase = nil;
		exp_TRK_Data = nil;
		exp_NBK_NoteBookData = nil;
		EXP_ExportMLN();
		msg = format(METAMAPEXP_EXPORTED, Notecount, EXP_USERNOTES)..EXP_USERPATH;		
	elseif(mode == EXP_USERQST) then
		exp_MetaMap_Notes = nil;
		exp_MetaMap_Lines = nil;
		exp_WKB_Data = nil;
		exp_TRK_Data = nil;
		exp_NBK_NoteBookData = nil;
		EXP_ExportQST();
		msg = format(METAMAPEXP_EXPORTED, QSTcount, EXP_USERQST)..EXP_USERPATH;		
	elseif(mode == EXP_USERTRK) then
		exp_MetaMap_Notes = nil;
		exp_MetaMap_Lines = nil;
		exp_WKB_Data = nil;
		exp_QST_QuestBase = nil;
		exp_NBK_NoteBookData = nil;
		EXP_ExportTRK();
		msg = format(METAMAPEXP_EXPORTED, TRKcount, EXP_USERTRK)..EXP_USERPATH;		
	elseif(mode == EXP_USERNBK) then
		exp_MetaMap_Notes = nil;
		exp_MetaMap_Lines = nil;
		exp_WKB_Data = nil;
		exp_QST_QuestBase = nil;
		exp_TRK_Data = nil;
		EXP_ExportNBK();
		msg = format(METAMAPEXP_EXPORTED, NBKcount, EXP_USERNBK)..EXP_USERPATH;		
	end
	EXP_ExportFrame:Hide();
	MetaMap_LoadExportsButton:Disable();
	MetaMap_OptionsInfo:SetText(msg);
end

function EXP_ExportWKB()
	exp_WKB_Data = {};
	for zone, unitTable in pairs(WKB_Data) do
		exp_WKB_Data[zone] = {};
		for unit, value in pairs(unitTable) do
			exp_WKB_Data[zone][unit] = value;
			WKBcount = WKBcount +1;
		end
	end
end

function EXP_ExportMLN()
	exp_MetaMap_Notes = {};
	exp_MetaMap_Lines = {};
	for zone, indexTable in pairs(MetaMap_Notes) do
		exp_MetaMap_Notes[zone] = {};
		for index, value in pairs(indexTable) do
			exp_MetaMap_Notes[zone][index] = value;
			Notecount = Notecount +1;
		end
	end
	exp_MetaMap_Lines = MetaMap_Lines;
	
end

function EXP_ExportQST()
	exp_QST_QuestBase = {};
	for index, quest in pairs(QST_QuestBase) do
		exp_QST_QuestBase[index] = quest;
		QSTcount = QSTcount +1;
	end
end

function EXP_ExportTRK()
	exp_TRK_Data = {};
	for zone, indexTable in pairs(TRK_Data) do
		exp_TRK_Data[zone] = {};
		for index, value in pairs(indexTable) do
			exp_TRK_Data[zone][index] = value;
			TRKcount = TRKcount +1;
		end
	end
end

function EXP_ExportNBK()
	exp_NBK_NoteBookData = {};
	for index, value in pairs(NBK_NoteBookData) do
		exp_NBK_NoteBookData[index] = value;
		NBKcount = NBKcount +1;
	end
end

