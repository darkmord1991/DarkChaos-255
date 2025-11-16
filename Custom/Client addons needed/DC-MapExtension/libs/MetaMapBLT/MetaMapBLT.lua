
MetaMapBLT_ClassSet = "";
MetaMapBLT_ClassName = "";
MetaMapBLT_HeroMode = false;

function MetaMapBLT_OnSelect(lootID, name)
	if(lootID == nil) then return; end
	local info;
	if(lootID and lootID ~= "") then
		local itemName, itemLink, itemQuality, itemLevel, itemType, itemSubType, itemCount, itemEquipLoc, itemTexture, itemColor;
		local iconFrame, nameFrame, extraFrame;
		local text, extra;
		if(string.find(lootID, "SET")) then
			MetaMapBLT_SetMenu(lootID, name);
			info = METAMAPBLT_CLASS_SELECT;
			lootID = nil;
		end
		if(BLT_Data[lootID.."HEROIC"]) then
			MetaMapBLT_ModeButton.id = lootID;
			MetaMapBLT_ModeButton.name = name;
			MetaMapBLT_ModeButton:Show();
			if(MetaMapBLT_HeroMode) then
				lootID = lootID.."HEROIC";
				name = name.. "  ("..BLT_HEROIC..")";
				MetaMapBLT_ModeButton:SetText(BLT_NORMAL);
			else
				MetaMapBLT_ModeButton:SetText(BLT_HEROIC);
			end
		else
			MetaMapBLT_ModeButton:Hide();
		end
		for i = 1, 30, 1 do
			if(BLT_Data[lootID] ~= nil and BLT_Data[lootID][i] ~= nil and BLT_Data[lootID][i][3] ~= "") then
				itemName, itemLink, itemQuality, itemLevel, itemType, itemSubType, itemCount, itemEquipLoc, itemTexture = GetItemInfo(BLT_Data[lootID][i][1]);
				if(GetItemInfo(BLT_Data[lootID][i][1])) then
					_, _, _, itemColor = GetItemQualityColor(itemQuality);
					text = itemColor..itemName;
				else
					text = BLT_Data[lootID][i][3];
					text = MetaMapBLT_FixText(text);
				end
				
				extra = BLT_Data[lootID][i][4];
                extra = MetaMapBLT_FixText(extra)
				if(not GetItemInfo(BLT_Data[lootID][i][1]) and (BLT_Data[lootID][i][1] ~= 0)) then
					extra = extra.." |cffff0000(no iteminfo)";
				end
			
				getglobal("MetaMapBLTItem_"..i.."_Icon"):SetTexture("Interface\\Icons\\"..BLT_Data[lootID][i][2]);
				getglobal("MetaMapBLTItem_"..i.."_Extra"):SetText(extra);
				getglobal("MetaMapBLTItem_"..i.."_Name"):SetText(text);
				getglobal("MetaMapBLTItem_"..i).itemID = BLT_Data[lootID][i][1];
				getglobal("MetaMapBLTItem_"..i).storeID = BLT_Data[lootID][i][1];
				getglobal("MetaMapBLTItem_"..i).droprate = BLT_Data[lootID][i][5];
				getglobal("MetaMapBLTItem_"..i).i = 1;
				getglobal("MetaMapBLTItem_"..i):Show();
				MetaMapContainer_InfoText:Hide();
			else
				getglobal("MetaMapBLTItem_"..i):Hide();
			end
			if(BLT_Data[lootID] == nil and info == nil) then 
				info = METAMAPBLT_NO_DATA;
			end
		end
	else
		for i = 1, 30, 1 do
			getglobal("MetaMapBLTItem_"..i):Hide();
		end            
		info = METAMAPBLT_NO_INFO;
	end
	MetaMapContainer_ShowFrame(MetaMapBLT_SubFrame, name, METAMAPBLT_HINT, info);
end

function MetaMapBLTItem_OnEnter()
	if(this.itemID ~= nil) then
    if(IsAddOnLoaded("LootLink") and GetItemInfo(this.itemID) == nil) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -200, 0);
      LootLink_SetTooltip(GameTooltip, strsub(getglobal("MetaMapBLTItem_"..this:GetID().."_Name"):GetText(), 11), 1);
			if( this.droprate ~= nil) then
				GameTooltip:AddLine("Drop Rate: "..this.droprate, 1, 1, 0);
			end
			GameTooltip:Show();
		elseif(this.itemID ~= nil and GetItemInfo(this.itemID) ~= nil) then
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -200, 0);
			GameTooltip:SetHyperlink("item:"..this.itemID..":0:0:0");
			if(this.droprate ~= nil) then
				GameTooltip:AddLine("Drop Rate: "..this.droprate, 1, 1, 0);
			end
			GameTooltip:Show();
		end
	end
end

function MetaMapBLTItem_OnClick(button)
	local iteminfo = GetItemInfo(this.itemID);
	local color = strsub(getglobal("MetaMapBLTItem_"..this:GetID().."_Name"):GetText(), 1, 10);
	local name = strsub(getglobal("MetaMapBLTItem_"..this:GetID().."_Name"):GetText(), 11);
	local _, itemLink = GetItemInfo(this.itemID);
	if(button == "RightButton") then
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT", -200, 0);
		GameTooltip:SetHyperlink("item:"..this.itemID..":0:0:0");
		if(this.droprate ~= nil) then
			GameTooltip:AddLine("Drop Rate: "..this.droprate, 1, 1, 0);
		end
		GameTooltip:Show();
	else
		if(IsShiftKeyDown() and iteminfo) then
			if(not ChatFrameEditBox:IsVisible()) then ChatFrameEditBox:Show(); end
			ChatFrameEditBox:Insert(itemLink);
		elseif(IsControlKeyDown() and iteminfo) then
			MetaMap_ToggleDR(1)
			DressUpItemLink(itemLink);
			DressUpFrame:Show();
			DressUpItemLink(itemLink);
		end
	end
end
    
function MetaMapBLT_SetMenu(lootID, name)
	MetaMapBLT_ClassSet = string.gsub(lootID, "SET", "")
	MetaMapBLT_ClassName = name;
	MetaMapContainer_ShowFrame(MetaMapBLT_SubFrame, name, METAMAPBLT_HINT, info);
	MetaMapBLT_ClassMenu:Show();
end

function MetaMapBLT_MenuOnClick()
	local className = MetaMapBLT_ClassSet..this.ClassName;
	local header = MetaMapBLT_ClassName.." - "..this:GetText();
	MetaMapBLT_OnSelect(className, header);
end

function MetaMapBLTItem_OnLeave()
	GameTooltip:Hide();
end

function MetaMapBLT_SetClassColors()
	local color;
	color = RAID_CLASS_COLORS["DRUID"];
	MetaMapBLT_ButtonDruidText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["HUNTER"];
	MetaMapBLT_ButtonHunterText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["MAGE"];
	MetaMapBLT_ButtonMageText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["PALADIN"];
	MetaMapBLT_ButtonPaladinText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["PRIEST"];
	MetaMapBLT_ButtonPriestText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["ROGUE"];
	MetaMapBLT_ButtonRogueText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["SHAMAN"];
	MetaMapBLT_ButtonShamanText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["WARLOCK"];
	MetaMapBLT_ButtonWarlockText:SetTextColor(color.r, color.g, color.b);
	color = RAID_CLASS_COLORS["WARRIOR"];
	MetaMapBLT_ButtonWarriorText:SetTextColor(color.r, color.g, color.b);
end
