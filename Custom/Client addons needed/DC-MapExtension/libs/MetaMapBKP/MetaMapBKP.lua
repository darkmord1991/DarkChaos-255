-- MetaMapBKP (Backup & Restore module for MetaMap)
-- Written by MetaHawk - aka Urshurak

local info;

function BKP_OnShow()
	BKP_Check_NoteData:SetChecked(0);
	BKP_Check_WKBdata:SetChecked(0);
	BKP_Check_QSTdata:SetChecked(0);
	BKP_Check_TRKdata:SetChecked(0);
	if(EXP_ExportFrame) then EXP_ExportFrame:Hide(); end
	if(CVT_ImportFrame) then CVT_ImportFrame:Hide(); end
end

function BKP_Init(mode)
	info = "";
	if(mode == "backup") then
		if(BKP_Check_NoteData:GetChecked()) then
			BKP_BackupNotes();
		end
		if(BKP_Check_WKBdata:GetChecked()) then
			if(not IsAddOnLoaded("MetaMapWKB")) then
				LoadAddOn("MetaMapWKB");
			end
			if(IsAddOnLoaded("MetaMapWKB")) then
				BKP_BackupWKB();
			else
				info = info.."\nMetaMapWKB: |cffff0000"..METAMAP_NOMODULE.."|r";
			end
		end
		if(BKP_Check_QSTdata:GetChecked()) then
			if(not IsAddOnLoaded("MetaMapQST")) then
				LoadAddOn("MetaMapQST");
			end
			if(IsAddOnLoaded("MetaMapQST")) then
				BKP_BackupQST();
			else
				info = info.."\nMetaMapQST: |cffff0000"..METAMAP_NOMODULE.."|r";
			end
		end
		if(BKP_Check_TRKdata:GetChecked()) then
			if(not IsAddOnLoaded("MetaMapTRK")) then
				LoadAddOn("MetaMapTRK");
			end
			if(IsAddOnLoaded("MetaMapTRK")) then
				BKP_BackupTRK();
			else
				info = info.."\nMetaMapTRK: |cffff0000"..METAMAP_NOMODULE.."|r";
			end
		end
	else
		if(BKP_Check_NoteData:GetChecked()) then
			BKP_RestoreNotes();
		end
		if(BKP_Check_WKBdata:GetChecked()) then
			if(not IsAddOnLoaded("MetaMapWKB")) then
				LoadAddOn("MetaMapWKB");
			end
			if(IsAddOnLoaded("MetaMapWKB")) then
				BKP_RestoreWKB();
			else
				info = info.."\nMetaMapWKB: |cffff0000"..METAMAP_NOMODULE.."|r";
			end
		end
		if(BKP_Check_QSTdata:GetChecked()) then
			if(not IsAddOnLoaded("MetaMapQST")) then
				LoadAddOn("MetaMapQST");
			end
			if(IsAddOnLoaded("MetaMapQST")) then
				BKP_RestoreQST();
			else
				info = info.."\nMetaMapQST: |cffff0000"..METAMAP_NOMODULE.."|r";
			end
		end
		if(BKP_Check_TRKdata:GetChecked()) then
			if(not IsAddOnLoaded("MetaMapTRK")) then
				LoadAddOn("MetaMapTRK");
			end
			if(IsAddOnLoaded("MetaMapTRK")) then
				BKP_RestoreTRK();
			else
				info = info.."\nMetaMapTRK: |cffff0000"..METAMAP_NOMODULE.."|r";
			end
		end
	end
	MetaMap_OptionsInfo:SetText(info);
	BKP_Check_NoteData:SetChecked(0);
	BKP_Check_WKBdata:SetChecked(0);
	BKP_Check_QSTdata:SetChecked(0);
	BKP_Check_TRKdata:SetChecked(0);
end

function BKP_BackupNotes()
	BKP_MetaMap_Notes = {};
	BKP_MetaMap_Lines = {};
	BKP_MetaMap_Notes = MetaMap_Notes;
	BKP_MetaMap_Lines = MetaMap_Lines;
	info = info.."MetaMap Notes: |cff00ff00"..METAMAPBKP_BACKUP_DONE.."|r\n";
end

function BKP_BackupWKB()
	BKP_WKB_Data = {};
	BKP_WKB_Data = WKB_Data;
	info = info.."MetaMapWKB: |cff00ff00"..METAMAPBKP_BACKUP_DONE.."|r\n";
end

function BKP_BackupQST()
	BKP_QST_QuestBase = {};
	BKP_QST_QuestBase = QST_QuestBase;
	info = info.."MetaMapQST: |cff00ff00"..METAMAPBKP_BACKUP_DONE.."|r\n";
end

function BKP_BackupTRK()
	BKP_TRK_Data = {};
	BKP_TRK_Data = TRK_Data;
	info = info.."MetaMapTRK: |cff00ff00"..METAMAPBKP_BACKUP_DONE.."|r\n";
end

function BKP_RestoreNotes()
	if(BKP_MetaMap_Notes) then
		MetaMap_Notes = {};
		MetaMap_Notes = BKP_MetaMap_Notes;
		info = "MetaMap Notes: |cff00ff00"..METAMAPBKP_RESTORE_DONE.."|r\n";
	else
		info = "MetaMap Notes: |cffff0000"..METAMAPBKP_RESTORE_FAIL.."|r\n";
	end
	if(BKP_MetaMap_Lines ~= nil) then
		MetaMap_Lines = {};
		MetaMap_Lines = BKP_MetaMap_Lines;
	end
end

function BKP_RestoreWKB()
	if(BKP_WKB_Data) then
		WKB_Data = {};
		WKB_Data = BKP_WKB_Data;
		info = info.."MetaMapWKB: |cff00ff00"..METAMAPBKP_RESTORE_DONE.."|r\n";
	else
		info = info.."MetaMapWKB: |cffff0000"..METAMAPBKP_RESTORE_FAIL.."|r\n";
	end
end

function BKP_RestoreQST()
	if(BKP_QST_QuestBase) then
		QST_QuestBase = {};
		QST_QuestBase = BKP_QST_QuestBase;
		info = info.."MetaMapQST: |cff00ff00"..METAMAPBKP_RESTORE_DONE.."|r\n";
	else
		info = info.."MetaMapQST: |cffff0000"..METAMAPBKP_RESTORE_FAIL.."|r\n";
	end
end

function BKP_RestoreTRK()
	if(BKP_TRK_Data) then
		TRK_Data = {};
		TRK_Data = BKP_TRK_Data;
		info = info.."MetaMapTRK: |cff00ff00"..METAMAPBKP_RESTORE_DONE.."|r\n";
	else
		info = info.."MetaMapTRK: |cffff0000"..METAMAPBKP_RESTORE_FAIL.."|r\n";
	end
end
