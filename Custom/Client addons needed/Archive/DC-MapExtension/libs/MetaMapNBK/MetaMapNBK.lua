-- MetaMapNBK
-- Written by MetaHawk - aka Urshurak

NBK_TotalButtons = 0;
NBK_ButtonHeight = 20;

local NBK_NoteList = {};
local NBK_OrigContainerButton;

NBK_Default = {
	["Tooltips"]   = false,
	["ShowGuild"]  = false,
	["PlaySound1"] = false,
	["PlaySound2"] = false,
	["AutoInsert"] = false,
	["FrameScale"] = 1.0,
	["FrameAlpha"] = 1.0,
	["ListColor"]  = {0.95, 0.80, 0.30},
	["HeadColor"]  = {1.0, 1.0, 1.0},
	["TextColor"]  = {0.0, 0.75, 0.75},
	["TtipColor"]  = {0.0, 0.75, 0.75},
}

function NBK_OnLoad()
	this:RegisterEvent("ADDON_LOADED");
	this:RegisterEvent("PLAYER_TARGET_CHANGED");
	this:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
end

function NBK_OnEvent(event)
	if(event == "ADDON_LOADED" and arg1 == "MetaMapNBK") then
		if(NBK_Options == nil) then NBK_Options = {}; end
		for option, value in pairs(NBK_Default) do
			if(NBK_Options[option] == nil) then NBK_Options[option] = value; end
		end
		NBK_Default = nil;
		if(NBK_NoteBookData == nil) then NBK_NoteBookData = {}; end
		if(MetaMapNBK_NoteBook) then NBK_NoteBookData = MetaMapNBK_NoteBook; end
		MetaMapNBK_NoteBook = nil;
		hooksecurefunc("ContainerFrameItemButton_OnClick", NBK_ContainerButton_OnClick);
		NBK_NoteBookFrame:SetScale(NBK_Options.FrameScale);
		NBK_NotesRefresh();
	elseif(event == "PLAYER_TARGET_CHANGED") then
		if(IsShiftKeyDown()) then
			NBK_SetTargetNote(UnitName("target"))
		end
	end
end

function NBK_SortList()
	local tmp = MetaMap_sortType;
	MetaMap_sortType = METAMAP_SORTBY_NAME;
	NBK_NoteList = {};
	for index, value in pairs(NBK_NoteBookData) do
		tinsert(NBK_NoteList, {name = value.Header, Index = index});
	end
  table.sort(NBK_NoteList, MetaMap_SortCriteria);
	MetaMap_sortType = tmp;
end

function NBK_NotesRefresh(current)
	local R, G, B;
	local button;
	local buttonCount = 0;
	NBK_SortList();
	for index, value in pairs(NBK_NoteList) do
		if(getglobal("NBK_NoteButton"..index)) then
			button = getglobal("NBK_NoteButton"..index);
		else
			button = CreateFrame("Button" ,"NBK_NoteButton"..index, NBK_ScrollFrame, "MetaMap_ScrollButtonTemplate");
			NBK_TotalButtons = NBK_TotalButtons +1;
		end
		button:SetScript("OnClick", function() NBK_NoteBookOnClick(this:GetID()); end);
		button:SetWidth(button:GetParent():GetWidth());
		button:SetHeight(NBK_ButtonHeight);
		button:SetID(value.Index);
		R, G, B = unpack(NBK_Options.ListColor);
		getglobal("NBK_NoteButton"..index.."Text"):SetJustifyH("LEFT")
		getglobal("NBK_NoteButton"..index.."Text"):SetTextColor(R, G, B)
		getglobal("NBK_NoteButton"..index.."Text"):SetText(NBK_NoteBookData[value.Index].Header)
		if(index == 1) then
			button:SetPoint("TOPLEFT", "NBK_ScrollFrame", "TOPLEFT", 15, -5);
		else
			button:SetPoint("TOPLEFT", getglobal("NBK_NoteButton"..index -1), "TOPLEFT", 0, -15);
		end
		button:Show();
		buttonCount = index;
	end
	for i=buttonCount+1, NBK_TotalButtons do
		getglobal("NBK_NoteButton"..i):Hide()
	end
	R, G, B = unpack(NBK_Options.HeadColor);
	NBK_NoteTitle:SetTextColor(R, G, B);
	R, G, B = unpack(NBK_Options.TextColor);
	NBK_NoteBody:SetTextColor(R, G, B);
	if(current == -1) then
		NBK_NoteTitle:SetID(0);
		NBK_NoteTitle:SetText("");
		NBK_NoteBody:SetText("");
	elseif(current) then
		NBK_NoteTitle:SetID(current);
		NBK_NoteTitle:SetText(NBK_NoteBookData[current].Header);
		NBK_NoteBody:SetText(NBK_NoteBookData[current].Text);
	end
	NBK_ScrollFrame:SetHeight((NBK_TotalButtons * NBK_ButtonHeight) + NBK_ButtonHeight);
	NBK_ListFrame:UpdateScrollChildRect();
	NBK_NoteList = nil;
end

function NBK_NoteBookOnClick(id)
	NBK_NoteTitle:SetID(id);
	NBK_NoteTitle:SetText(NBK_NoteBookData[id].Header);
	NBK_NoteBody:SetText(NBK_NoteBookData[id].Text);
end

function NBK_NoteSave()
	local id = NBK_NoteTitle:GetID();
	if(strlen(NBK_NoteTitle:GetText()) < 1) then return; end
	if(not NBK_NoteBookData[id]) then
		id = #(NBK_NoteBookData)+1;
		NBK_NoteBookData[id] = {};
	end
	NBK_NoteTitle:SetID(id);
	NBK_NoteBookData[id].Header = NBK_NoteTitle:GetText();
	NBK_NoteBookData[id].Text = NBK_NoteBody:GetText();
	NBK_NotesRefresh(id);
end

function NBK_NoteDelete()
	local id = NBK_NoteTitle:GetID();
	if(not id) then return; end
	if(NBK_NoteBookData[id]) then
		NBK_NoteBookData[id] = nil;
	end
	local TmpData = {};
	local new = 1;
	for index, value in pairs(NBK_NoteBookData) do
		TmpData[new] = {};
		TmpData[new] = value;
		new = new +1;
	end
	NBK_NoteBookData = {};
	NBK_NoteBookData = TmpData;
	TmpData = nil;
	NBK_NotesRefresh(-1);
end

function NBK_OnShow(mode)
	if(not NBK_Options) then return; end
	local firstLine;
	local found;
	local added = false;
	local NBK_DeadTip = string.sub(CORPSE_TOOLTIP, 0, string.len(CORPSE_TOOLTIP)-2);
	if(mode == 1 and NBK_Options.ShowGuild) then
		local guildname = GetGuildInfo("mouseover");
		if(guildname) then
			GameTooltip:AddLine("<"..guildname..">", 0, 1.0, 0);
			added = true;
		end
	end
	if(mode == 1 and UnitExists("mouseover")) then
		firstLine = UnitName("mouseover");
	else
		if(mode == 1) then
			firstLine = getglobal("GameTooltipTextLeft1"):GetText();
		else
			firstLine = getglobal("WorldMapTooltipTextLeft1"):GetText();
		end
		if string.find(firstLine, NBK_DeadTip) then
			firstLine = string.sub(firstLine, string.len(NBK_DeadTip)+1);
		end
	end
	if(firstLine and NBK_Options.Tooltips) then
		local index = NBK_CheckExisting(firstLine);
		if(index) then
			if(mode == 1 and UnitExists("mouseover") and NBK_Options.PlaySound1) then
				PlaySound("FriendJoinGame");
			elseif(mode == 2 and NBK_Options.PlaySound2) then
				PlaySound("FriendJoinGame");
			end
			local info = "\n"..NBK_NoteBookData[index].Text;
			local oneLine = 0;
			local R, G, B = unpack(NBK_Options.TtipColor);
			while oneLine do
				info = string.sub(info, oneLine+1);
				oneLine = NBK_FormaTText(info);
				firstLine = string.sub(info, 0, oneLine);
				if(mode == 1) then
					GameTooltip:AddLine(firstLine, R, G, B);
				else
					WorldMapTooltip:AddLine(firstLine, R, G, B);
				end
			end
			added = true;
		end
	end
	if(added) then
		if(mode == 1) then
			GameTooltip:Show();
		else
			WorldMapPOIFrame.allowBlobTooltip = false;
			WorldMapTooltip:Show();
		end
	end
end

function NBK_FormaTText(text)
	local LineSpace = string.find(text, " " , 40);
	local LineFeed = string.find(text, "\n");
	if(LineFeed == nil) then
		return LineSpace;
	end
	if(LineSpace == nil) then
		return LineFeed;
	end
	if(LineSpace < LineFeed) then
		return LineSpace;
	else
		return LineFeed;
	end
end

function NBK_CheckExisting(name)
	local found;
	for index, value in pairs(NBK_NoteBookData) do
		if(value.Header == name) then found = index; break; end
	end
	return found;
end

function NBK_SetAlpha(value)
	NBK_NoteBookFrame:SetAlpha(value);
	for i=1, NBK_TotalButtons do
		getglobal("NBK_NoteButton"..i):SetAlpha(value +0.2)
	end
	NBK_NoteTitle:SetAlpha(value +0.2)
	NBK_NoteBody:SetAlpha(value +0.2)
end

function NBK_ToggleOptions(key, value)
	if(value) then
		NBK_Options[key] = value;
	else
		NBK_Options[key] = not NBK_Options[key];
	end
	return NBK_Options[key];
end

function NBK_SetTextColor(option, R, G, B)
	NBK_ToggleOptions(option, {R, G, B})
	getglobal("NBK_Check_"..option.."BG"):SetTexture(R, G, B);
	NBK_NotesRefresh();
end

function NBK_ContainerButton_OnClick(button)
	if(button == "RightButton" and IsShiftKeyDown()) then
		local name = getglobal("GameTooltipTextLeft1"):GetText();
		NBK_SetTargetNote(name);
		return;
	end
end

function NBK_SetTargetNote(name)
	if(not name or name == "" or not NBK_Options.AutoInsert) then return; end
	local index = NBK_CheckExisting(name);
	if(index) then
		NBK_NoteTitle:SetID(index);
		NBK_NoteTitle:SetText(NBK_NoteBookData[index].Header);
		NBK_NoteBody:SetText(NBK_NoteBookData[index].Text);
	else
		NBK_NoteTitle:SetID(0);
		NBK_NoteTitle:SetText(name);
		NBK_NoteBody:SetText("");
	end
	NBK_NoteBookFrame:Show();
	NBK_NoteBody:SetFocus();
end

