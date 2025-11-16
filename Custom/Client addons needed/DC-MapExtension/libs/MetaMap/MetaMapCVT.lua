-- MetaKB Import Module
-- Written by MetaHawk aka Urshurak

CVT_DATANAME    = "";

local CVT_TempData = {};
local Import_MetaNotes = false;
local Import_WKB       = false;
local Import_QST       = false;
local Import_TRK       = false;
local Import_NBK       = false;
local Import_QH        = false;
local Import_MapMod    = false;
local Import_MapNotes  = false;

function MetaMapCVT_CheckData()
	local found = false;
	local fileInfo = "MetaMap Imports module loaded."
	if(MetaMap_InstanceData) then
		MetaMap_InstanceImportButton:Enable();
		found = true;
	end
	if(exp_MetaMap_Notes) then
		MetaMap_UserImportButton:Enable();
		Import_MetaNotes = true;
		found = true;
	elseif(exp_TRK_Data) then
		if(not IsAddOnLoaded("MetaMapTRK")) then
			LoadAddOn("MetaMapTRK");
		end
		if(IsAddOnLoaded("MetaMapTRK")) then
			MetaMap_UserImportButton:Enable();
			Import_TRK = true;
			found = true;
		end
	elseif(exp_NBK_NoteBookData) then
		if(not IsAddOnLoaded("MetaMapNBK")) then
			LoadAddOn("MetaMapNBK");
		end
		if(IsAddOnLoaded("MetaMapNBK")) then
			MetaMap_UserImportButton:Enable();
			Import_NBK = true;
			found = true;
		end
	elseif(exp_WKB_Data) then
		if(not IsAddOnLoaded("MetaMapWKB")) then
			LoadAddOn("MetaMapWKB");
		end
		if(IsAddOnLoaded("MetaMapWKB")) then
			MetaMap_UserImportButton:Enable();
			Import_WKB = true;
			found = true;
		end
	elseif(exp_QST_QuestBase) then
		if(not IsAddOnLoaded("MetaMapQST")) then
			LoadAddOn("MetaMapQST");
		end
		if(IsAddOnLoaded("MetaMapQST")) then
			MetaMap_UserImportButton:Enable();
			if(QuestHistory_List) then
				Import_QH = true;
			end
			if(exp_QST_QuestBase) then
				Import_QST = true;
			end
			found = true;
		end
	elseif(QuestHistory_List and not IsAddOnLoaded("QuestHistory")) then
		if(not IsAddOnLoaded("MetaMapQST")) then
			LoadAddOn("MetaMapQST");
		end
		if(IsAddOnLoaded("MetaMapQST")) then
			MetaMap_UserImportButton:Enable();
			if(QuestHistory_List) then
				Import_QH = true;
			end
			if(exp_QST_QuestBase) then
				Import_QST = true;
			end
			found = true;
		end
	elseif(CT_UserMap_Notes and not IsAddOnLoaded("CT_MapMod")) then
		if(not IsAddOnLoaded("MetaMapTRK")) then
			LoadAddOn("MetaMapTRK");
		end
		MetaMap_UserImportButton:Enable();
		Import_MapMod = true;
		found = true;
	elseif(MapNotes_Data_Notes and not IsAddOnLoaded("MapNotes")) then
		MetaMap_UserImportButton:Enable();
		Import_MapNotes = true;
		found = true;
	end
	if(not found) then
		fileInfo = fileInfo.."\nNo data files found";
	end
	MetaMap_OptionsInfo:SetText(fileInfo);
end

function MetaMap_ImportOptions(mode)
	if(mode == 1) then
		CVT_ImportInstanceData();
	elseif(mode == 2) then
		if(Import_MetaNotes) then CVT_ImportButton.value = 1; CVT_DATANAME = "\n\n MetaMap notes"; end
		if(Import_WKB) then CVT_ImportButton.value = 2; CVT_DATANAME = "\n\n MetaMapWKB"; end
		if(Import_QST) then CVT_ImportButton.value = 3; CVT_DATANAME = "\n\n MetaMapQST"; end
		if(Import_TRK) then CVT_ImportButton.value = 4; CVT_DATANAME = "\n\n MetaMapTRK"; end
		if(Import_QH) then CVT_ImportButton.value = 5; CVT_DATANAME = "\n\n QuestHistory"; end
		if(Import_MapMod) then CVT_ImportButton.value = 6; CVT_DATANAME = "\n\n MapMod"; end
		if(Import_NBK) then CVT_ImportButton.value = 7; CVT_DATANAME = "\n\n MetaMapNBK"; end
		if(Import_MapNotes) then CVT_ImportButton.value = 8; CVT_DATANAME = "\n\n MapNotes"; end
		CVT_ConfirmationHeader:SetText(METAMAP_CONFIRM_IMPORT.."|cff00ff00"..CVT_DATANAME);
		if(EXP_ExportFrame) then EXP_ExportFrame:Hide(); end
		if(BKP_BackUpFrame) then BKP_BackUpFrame:Hide(); end
		CVT_ImportFrame:Show();
	end
end

function CVT_SelectedImport(mode)
	MetaMap_LoadImportsButton:Disable();
	if(mode == 1) then
		CVT_ImportMetaNotes();
	elseif(mode == 2) then
		CVT_ImportUserWKB();
	elseif(mode == 3) then
		CVT_ImportQuestBase();
	elseif(mode == 4) then
		CVT_ImportTracks();
	elseif(mode == 5) then
		CVT_ImportQuestHistory();
	elseif(mode == 6) then
		CVT_ImportMapMod();
	elseif(mode == 7) then
		CVT_ImportNBK();
	elseif(mode == 8) then
		CVT_ImportMapNotes();
	end
	CVT_ImportFrame:Hide();
end

function CVT_ImportInstanceData()
	CVT_TempData = {};
	CVT_TempData = MetaMap_Notes;
	MetaMap_Notes = {};
	MetaMap_LoadZones();
	for zone, indexTable in pairs(MetaMap_InstanceData) do
		local zName = MetaMap_GetZoneTableEntry(zone);
		local i = #(MetaMap_Notes[zName])+1;
		for index, value in ipairs(indexTable) do
			MetaMap_Notes[zName][i] = value;
			i = i +1;
		end
	end
	for zone, indexTable in pairs(MetaMap_WorldData) do
		local zName = MetaMap_GetZoneTableEntry(zone);
		local i = #(MetaMap_Notes[zName])+1;
		for index, value in ipairs(indexTable) do
			MetaMap_Notes[zName][i] = value;
			i = i +1;
		end
	end
	for zone, indexTable in pairs(CVT_TempData) do
		if(MetaMap_Notes[zone]) then
			local i = #(MetaMap_Notes[zone])+1;
			for index, value in ipairs(indexTable) do
				if(not value.lootid) then
					MetaMap_Notes[zone][i] = value;
					i = i +1;
				end
			end
		end
	end
	MetaMap_MainMapUpdate();
	MetaMap_OptionsInfo:SetText("Default data imported successfully");
end

function CVT_ImportMapMod()
	local noteTotal = 0;
	local noteImport = 0;
	local noteDupe = 0;
	for zoneName, indexTable in pairs(CT_UserMap_Notes) do
		local zName = MetaMap_GetZoneTableEntry(zoneName);
		for index, value in ipairs(indexTable) do
			noteTotal = noteTotal +1;
			if(value.set < 7) then
				local noteAdded = MetaMap_SetNewNote(zName, value.x, value.y, value.name, value.descript, "", UnitName("Player"), value.set, value.set, 0, 0)
				if(noteAdded) then
					noteImport = noteImport +1;
				else
					noteDupe = noteDupe +1;
				end
			elseif(TRK_Data and (value.set == 7 or value.set == 8)) then
				if(TRK_AddNode(zName, value.name, "MapMod Import", value.x, value.y, 0)) then
					noteImport = noteImport +1;
				else
					noteDupe = noteDupe +1;
				end
			end
		end
	end
	local msg = "Imported "..noteImport.." notes from MapMod from a total of "..noteTotal.." with "..noteDupe.." positions already occupied";
	MetaMap_OptionsInfo:SetText(msg);
end

function CVT_ImportTracks()
	local noteTotal = 0;
	local noteImport = 0;
	local noteDupe = 0;
	for zoneName, indexTable in pairs(exp_TRK_Data) do
		local zName = MetaMap_GetZoneTableEntry(zoneName);
		for index, value in ipairs(indexTable) do
			noteTotal = noteTotal +1;
			local noteAdded = TRK_AddNode(zName, TRK_TrackerTable[value.ref][MetaMap_Locale], value.creator, value.xPos, value.yPos)
			if(noteAdded) then
				noteImport = noteImport +1;
			else
				noteDupe = noteDupe +1;
			end
		end
	end
	local msg = "Imported "..noteImport.." items from a total of "..noteTotal.." with "..noteDupe.." duplicates not imported";
	MetaMap_OptionsInfo:SetText(msg);
end

function CVT_ImportNBK()
	local noteTotal = 0;
	local noteImport = 0;
	local noteDupe = 0;
	for index, value in ipairs(exp_NBK_NoteBookData) do
		local dupe = false;
		noteTotal = noteTotal +1;
		for i, v in ipairs(NBK_NoteBookData) do
			if(v.Header == value.Header) then
				dupe = true; noteDupe = noteDupe +1;
			end
		end
		if(not dupe) then
			NBK_NoteBookData[#(NBK_NoteBookData)+1] = value;
			noteImport = noteImport +1;
		end
	end
	local msg = "Imported "..noteImport.." items from a total of "..noteTotal.." with "..noteDupe.." duplicates not imported";
	MetaMap_OptionsInfo:SetText(msg);
	NBK_NotesRefresh();
end

function CVT_ImportUserWKB()
	local totalCount = 0;
	local importCount = 0;
	local dupeCount = 0;
	for zoneName, unitTable in pairs(exp_WKB_Data) do
		local zName = MetaMap_GetZoneTableEntry(zoneName);
		for unit, value in pairs(unitTable) do
			if(not zName) then break; end
			local dupe = false;
			totalCount = totalCount +1;
			for name in pairs(WKB_Data[zName]) do
				if(name == unit) then
					dupeCount = dupeCount +1;
					dupe = true; break;
				end
			end
			if(not dupe) then
				WKB_Data[zoneName][unit] = {};
				WKB_Data[zoneName][unit] = value;
				importCount = importCount +1;
			end
		end
	end
	MetaMap_OptionsInfo:SetText(format(WKB_IMPORT_SUCCESSFUL, importCount, totalCount, 0, dupeCount));
end

function CVT_ImportMetaNotes()
	local noteTotal = 0;
	local noteImport = 0;
	local noteDupe = 0;
	for zoneName, indexTable in pairs(exp_MetaMap_Notes) do
		local zName = MetaMap_GetZoneTableEntry(zoneName);
		for index, value in ipairs(indexTable) do
			noteTotal = noteTotal +1;
			local noteAdded = MetaMap_SetNewNote(zName, value.xPos, value.yPos, value.name, value.inf1, value.inf2, value.creator, value.icon, value.ncol, value.in1c, value.in2c)
			if(noteAdded) then
				noteImport = noteImport +1;
				for i, newvalue in ipairs(exp_MetaMap_Lines[zoneName]) do
					if(newvalue.x1 == value.xPos and newvalue.y1 == value.yPos) then
						MetaMap_ToggleLine(zName, newvalue.x1, newvalue.y1, newvalue.x2, newvalue.y2)
					end
				end
			else
				noteDupe = noteDupe +1;
			end
		end
	end
	local msg = "Imported "..noteImport.." notes from MetaNotes from a total of "..noteTotal.." with "..noteDupe.." duplicates not imported";
	MetaMap_OptionsInfo:SetText(msg);
end

function CVT_ImportMapNotes()
	local noteTotal = 0;
	local noteImport = 0;
	local noteDupe = 0;
	for zoneName, indexTable in pairs(MapNotes_Data_Notes) do
		local zName = MetaMap_GetZoneTableEntry(string.gsub(zoneName, "WM ", ""));
		for index, value in ipairs(indexTable) do
			noteTotal = noteTotal +1;
			local noteAdded = MetaMap_SetNewNote(zName, value.xPos, value.yPos, value.name, value.inf1, value.inf2, value.creator, value.icon, value.ncol, value.in1c, value.in2c)
			if(noteAdded) then
				noteImport = noteImport +1;
				for i, newvalue in ipairs(MapNotes_Data_Lines[zoneName]) do
					if(newvalue.x1 == value.xPos and newvalue.y1 == value.yPos) then
						MetaMap_ToggleLine(zName, newvalue.x1, newvalue.y1, newvalue.x2, newvalue.y2)
					end
				end
			else
				noteDupe = noteDupe +1;
			end
		end
	end
	local msg = "Imported "..noteImport.." notes from MapNotes from a total of "..noteTotal.." with "..noteDupe.." duplicates not imported";
	MetaMap_OptionsInfo:SetText(msg);
end

function CVT_ImportQuestBase()
	local total = 0;
	local imported = 0;
	local dupe = 0;
	local updated = 0;
	for index, qData2 in ipairs(exp_QST_QuestBase) do
		total = total +1;
		local qData1 = QST_QuestBase[index];
		if(qData1.qTitle == qData2.qTitle and qData1.qObj == qData2.qObj) then
			if((qData2.qNPC[1] and not qData1.qNPC[1]) or (qData2.qNPC[2] and not qData1.qNPC[2]) or strlen(qData2.qNote) > 0) then
				if(qData2.qNPC[1]) then
					qData1.qNPC[1] = qData2.qNPC[1];
				end
				if(qData2.qNPC[2]) then
					qData1.qNPC[2] = qData2.qNPC[2];
				end
				if(strlen(qData2.qNote) > 0) then
					qData1.qNote = qData1.qNote.."\n\n"..qData2.qNote;
				end
				updated = updated +1;
			else
				dupe = dupe +1;
			end
		else
			QST_QuestBase[index] = qData2;
			QST_QuestBase[index]["qPlayer"] = {};
			imported = imported +1;
		end
	end
	local msg = "Imported "..imported.." quests from a total of "..total.." with "..dupe.." duplicates not imported, and "..updated.." quests updated";
	MetaMap_OptionsInfo:SetText(msg);
end

function CVT_ImportQuestHistory()
	local total = 0;
	local imported = 0;
	local dupe = 0;
	local noinfo = 0;
	local newfound = true;
	for realm, playerTable in pairs(QuestHistory_List) do
		for player, questTable in pairs(playerTable) do
			for index, quest in ipairs(questTable) do
				total = total +1;
				if(not quest.t or not quest.o or not quest.l or not quest.c) then
					noinfo = noinfo +1;
					newfound = false;
				else
					for qIndex, value in ipairs(QST_QuestBase) do
						if(quest.c == value.qTitle and quest.o == value.qObj) then
							dupe = dupe +1;
							newfound = false;
							break;
						end
					end
				end
				if(newfound) then
					local n = #(QST_QuestBase)+1;
					QST_QuestBase[n] = {};
					local qData = QST_QuestBase[n];
					local status = QST_OVERVIEWCOLOUR..QST_QUEST_UNKNOWN;
					if(quest.tc) then
						status = QST_COMPLETEDCOLOUR..QST_QUEST_DONE;
					elseif(quest.a) then
						status = QST_INITIALCOLOUR..QST_QUEST_ABANDON;
					elseif(quest.f) then
						status = QST_INITIALCOLOUR..QST_QUEST_FAILED;
					end
					qData["qPlayer"] = {};
					qData["qPlayer"][player.." of "..realm] = {};
					qData["qPlayer"][player.." of "..realm]["qStatus"] = status;
					qData["qTitle"] = quest.t;
					qData["qObj"] = quest.o;
					qData["qLevel"] = quest.l;
					qData["qZone"] = quest.c;
					qData["qTag"] = quest.y;
					qData["qNPC"] = {};
					qData["qNote"] = "";
					if(QST_Options.SaveDesc) then
						qData["qDesc"] = quest.d;
					end
					if(quest.m) then
						qData["qMoney"] = quest.m;
					else
						qData["qMoney"] = 0;
					end
					if(quest.n) then
						qData["qNote"] = quest.n;
					end
					if(quest.os) then
						qData["qItems"] = {};
						for i, items in ipairs(quest.os) do
							qData["qItems"][i] = items.t;
						end
					end
					if(quest.r and QST_Options.SaveRew) then
						qData["qReward"] = {};
						for i, items in ipairs(quest.r) do
							qData["qReward"][i] = {};
							qData["qReward"][i]["qLink"] = items.l;
							qData["qReward"][i]["qTex"] = items.t;
							qData["qReward"][i]["qAmount"] = items.a;
						end
					end
					if(quest.i and QST_Options.SaveRew) then
						qData["qChoice"] = {};
						for i, items in ipairs(quest.i) do
							qData["qChoice"][i] = {};
							qData["qChoice"][i]["qLink"] = items.l;
							qData["qChoice"][i]["qTex"] = items.t;
							qData["qChoice"][i]["qAmount"] = items.a;
						end
					end
					if(quest.s and QST_Options.SaveRew) then
						qData["qSpell"] = {};
						for i, items in ipairs(quest.s) do
							qData["qSpell"][i] = {};
							qData["qSpell"][i]["qLink"] = items.n;
							qData["qSpell"][i]["qTex"] = items.t;
						end
					end
					if(quest.g) then
						qData["qNPC"][1] = {};
						qData["qNPC"][1]["qName"] = quest.g;
						qData["qNPC"][1]["qZone"] = quest.az;
						qData["qNPC"][1]["qX"] = quest.ax;
						qData["qNPC"][1]["qY"] = quest.ay;
					end
					if(quest.w) then
						qData["qNPC"][2] = {};
						qData["qNPC"][2]["qName"] = quest.g;
						qData["qNPC"][2]["qZone"] = quest.cz;
						qData["qNPC"][2]["qX"] = quest.cx;
						qData["qNPC"][2]["qY"] = quest.cy;
					end
					if(quest.tl) then
						local y, z, d, h, m, s = string.find(quest.tl, "(%d+)%s*[:]%s*(%d+)%s*[:]%s*(%d+)%s*[:]%s*(%d+)%s*");
						qData["qLogged"] = time() - (d * 79200)+(h * 3600)+(m * 60)+s;
					else
						qData["qLogged"] = time();
					end
					if(quest.tc) then
						local y, z, d, h, m, s = string.find(quest.tc, "(%d+)%s*[:]%s*(%d+)%s*[:]%s*(%d+)%s*[:]%s*(%d+)%s*");
						qData["qEnded"] = time() - (d * 79200)+(h * 3600)+(m * 60)+s;
					else
						qData["qEnded"] = time();
					end
					imported = imported +1;
				end
				newfound = true;
			end
		end
	end
	local msg = "Imported "..imported.." quests from a total of "..total.." with "..dupe.." duplicates not imported. "..noinfo.." entries discarded due to lack of data.";
	MetaMap_OptionsInfo:SetText(msg);
end
