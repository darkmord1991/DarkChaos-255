
CurrentGlueMusic = "GS_LichKing";

GlueCreditsSoundKits = { };
GlueCreditsSoundKits[1] = "Menu-Credits01";
GlueCreditsSoundKits[2] = "Menu-Credits02";
GlueCreditsSoundKits[3] = "Menu-Credits03";


GlueScreenInfo = { };
GlueScreenInfo["login"]			= "AccountLogin";
GlueScreenInfo["charselect"]	= "CharacterSelect";
GlueScreenInfo["realmwizard"]	= "RealmWizard";
GlueScreenInfo["charcreate"]	= "CharacterCreate";
GlueScreenInfo["patchdownload"]	= "PatchDownload";
GlueScreenInfo["trialconvert"]	= "TrialConvert";
GlueScreenInfo["movie"]			= "MovieFrame";
GlueScreenInfo["credits"]		= "CreditsFrame";
GlueScreenInfo["options"]		= "OptionsFrame";

CharModelFogInfo = { };
CharModelFogInfo["HUMAN"] = { r=0.8, g=0.65, b=0.73, far=222 };
CharModelFogInfo["ORC"] = { r=0.5, g=0.5, b=0.5, far=270 };
CharModelFogInfo["DWARF"] = { r=0.85, g=0.88, b=1.0, far=500 };
CharModelFogInfo["NIGHTELF"] = { r=0.25, g=0.22, b=0.55, far=611 };
CharModelFogInfo["TAUREN"] = { r=1.0, g=0.61, b=0.42, far=153 };
CharModelFogInfo["SCOURGE"] = { r=0, g=0.22, b=0.22, far=26 };
CharModelFogInfo["CHARACTERSELECT"] = { r=0.8, g=0.65, b=0.73, far=222 };

CharModelGlowInfo = { };
CharModelGlowInfo["WORGEN"] = 0.0;
CharModelGlowInfo["GOBLIN"] = 0.0;
CharModelGlowInfo["HUMAN"] = 0.15;
CharModelGlowInfo["DWARF"] = 0.15;
CharModelGlowInfo["CHARACTERSELECT"] = 0.3;

GlueAmbienceTracks = { };
GlueAmbienceTracks["HUMAN"] = "GlueScreenHuman";
GlueAmbienceTracks["ORC"] = "GlueScreenOrcTroll";
GlueAmbienceTracks["DWARF"] = "GlueScreenDwarfGnome";
GlueAmbienceTracks["TAUREN"] = "GlueScreenTauren";
GlueAmbienceTracks["SCOURGE"] = "GlueScreenUndead";
GlueAmbienceTracks["NIGHTELF"] = "GlueScreenNightElf";
GlueAmbienceTracks["DRAENEI"] = "GlueScreenDraenei";
GlueAmbienceTracks["BLOODELF"] = "GlueScreenBloodElf";
GlueAmbienceTracks["DARKPORTAL"] = "GlueScreenIntro";
GlueAmbienceTracks["DEATHKNIGHT"] = "GlueScreenIntro";
GlueAmbienceTracks["CHARACTERSELECT"] = "GlueScreenIntro";

-- RaceLights[] duplicates the 3.2.2 color values in the models. Henceforth, the models no longer contain directional lights
RaceLights = {
    HUMAN =  {
        {1,     0,  0.000000,       0.000000,       -1.000000,   1.0,   0.27,       0.27,       .27,        1.0,    0,          0,          0},
        {1,     0,  -0.45756075,    -0.58900136,    -0.66611975, 1.0,   0.000000,   0.000000,   0.000000,   1.0,    0.19882353, 0.34921569, 0.43588236 },
        {1,     0,  -0.64623469,    0.57582057,     -0.50081086, 1.0,   0.000000,   0.000000,   0.000000,   2.0,    0.52196085, 0.44,       0.29764709 },
    },
    ORC = {         
        {1,     0,  0.00000,        0.00000,        -1.00000,   1.0,    0.15000,    0.15000,    0.15000,    1.0,    0.00000,    0.00000,    0.00000},
        {1,     0,  -0.74919,       0.35208,        -0.56103,   1.0,    0.00000,    0.00000,    0.00000,    1.0,    0.44706,    0.54510,    0.73725},
        {1,     0,  0.53162,        -0.84340,       0.07780,    1.0,    0.00000,    0.00000,    0.00000,    2.0,    0.55,       0.338625,   0.148825},
    },
    DWARF = {
        {1,     0,  -0.00000,       -0.00000,       -1.00000,   1.0,    0.30000,    0.30000,    0.30000,    0.0,    0.00000,    0.00000,    0.00000},
        {1,     0,  -0.88314,       0.42916,        -0.18945,   1.0,    0.00000,    0.00000,    0.00000,    2.0,    0.44706,    0.67451,    0.760785},
    },
    TAUREN = {
        {1,     0,  -0.48073,       0.71827,        -0.50297,   1.0,    0.00000,    0.00000,    0.00000,    2.0,    0.65,       0.397645,   0.2727},
        {1,     0,  -0.49767,       -0.78677,       0.36513,    1.0,    0.00000,    0.00000,    0.00000,    1.0,    0.60000,    0.47059,    0.32471},
    },
    SCOURGE = {
        {1,     0,  0.00000,        0.00000,        -1.00000,   1.0,    0.20000,    0.20000,    0.20000,    1.0,    0.00000,    0.00000,    0.00000},
    },
    NIGHTELF = {
        {1,     0,  -0.00000,       -0.00000,       -1.00000,   1.0,    0.09020,    0.09020,    0.17020,    1.0,    0.00000,    0.00000,    0.00000},
    },
    DRAENEI = {
        {1,     0,  0.61185,        0.62942,        -0.47903,   1.0,    0.00000,    0.00000,    0.00000,    1.0,    0.56941,    0.52000,    0.60000},
        {1,     0,  -0.64345,       -0.31052,       -0.69968,   1.0,    0.00000,    0.00000,    0.00000,    1.0,    0.60941,    0.60392,    0.70000},
        {1,     0,  -0.46481,       -0.14320,       0.87376,    1.0,    0.00000,    0.00000,    0.00000,    2.0,    0.5835,     0.48941,    0.60000},
    },
    BLOODELF = {
        {1,     0,  -0.82249,       -0.54912,       -0.14822,   1.0,    0.00000,    0.00000,    0.00000,    2.0,    0.581175,   0.50588,    0.42588},
        {1,     0,  0.00000,        -0.00000,       -1.00000,   1.0,    0.60392,    0.61490,    0.70000,    1.0,    0.00000,    0.00000,    0.00000},
        {1,     0,  0.02575,        0.86518,        -0.50081,   1.0,    0.00000,    0.00000,    0.00000,    1.0,    0.59137,    0.51745,    0.63471},
    },
    DEATHKNIGHT = {
        {1,     0,  0.00000,        0.00000,        -1.00000,   1.0,    0.38824,    0.66353,    0.76941,    1.0,    0.00000,    0.00000,    0.00000},
    },
    CHARACTERSELECT =  {
        {1,     0,  0.00000,        0.00000,        -1.00000,   1.0,    0.15000,    0.15000,    0.15000,    1.0,    0.00000,    0.00000,    0.00000},
        {1,     0,  -0.74919,       0.35208,        -0.56103,   1.0,    0.00000,    0.00000,    0.00000,    1.0,    0.44706,    0.54510,    0.73725},
        {1,     0,  0.53162,        -0.84340,       0.07780,    1.0,    0.00000,    0.00000,    0.00000,    2.0,    0.55,       0.338625,   0.148825},
    },
}

-- indicies for adding lights ModelFFX:Add*Light
LIGHT_LIVE  = 0;
LIGHT_GHOST = 1;

-- Alpha animation stuff
FADEFRAMES = {};
CURRENT_GLUE_SCREEN = nil;
PENDING_GLUE_SCREEN = nil;
-- Time in seconds to fade
LOGIN_FADE_IN = 1.5;
LOGIN_FADE_OUT = 0.5;
CHARACTER_SELECT_FADE_IN = 0.75;
RACE_SELECT_INFO_FADE_IN = .5;
RACE_SELECT_INFO_FADE_OUT = .5;

-- Realm Split info
SERVER_SPLIT_SHOW_DIALOG = false;
SERVER_SPLIT_CLIENT_STATE = -1;	--	-1 uninitialized; 0 - no choice; 1 - realm 1; 2 - realm 2
SERVER_SPLIT_STATE_PENDING = -1;	--	-1 uninitialized; 0 - no server split; 1 - server split (choice mode); 2 - server split (no choice mode)
SERVER_SPLIT_DATE = nil;

-- Account Messaging info
ACCOUNT_MSG_NUM_AVAILABLE = 0;
ACCOUNT_MSG_PRIORITY = 0;
ACCOUNT_MSG_HEADERS_LOADED = false;
ACCOUNT_MSG_BODY_LOADED = false;
ACCOUNT_MSG_CURRENT_INDEX = nil;

-- Gender Constants
SEX_NONE = 1;
SEX_MALE = 2;
SEX_FEMALE = 3;

local DCBREAKINGNEWS_GLUE_PACKAGE = "dc-breakingnews-glueparent-ui-2026-05-09-r4";
local DCBREAKINGNEWS_FRAME_WIDTH = 400;
local DCBREAKINGNEWS_FRAME_HEIGHT = 240;
local DCBreakingNewsState = {
	appliedRevision = 0,
	updateTimer = 0,
};

local function DCBreakingNews_TryNativeNotify(functionName, ...)
	local callback = _G[functionName];
	if ( type(callback) ~= "function" ) then
		return false;
	end

	local ok = pcall(callback, ...);
	return ok;
end

local function DCBreakingNews_ReportGlueProbeState(applied, revision, stageCode, detail)
	if ( stageCode == 10 ) then
		if ( DCBreakingNews_TryNativeNotify("DCBreakingNews_NotifyGlueLoaded",
				DCBREAKINGNEWS_GLUE_PACKAGE) ) then
			return;
		end
	elseif ( stageCode == 30 ) then
		if ( DCBreakingNews_TryNativeNotify("DCBreakingNews_NotifyGlueHidden",
				detail or "hidden") ) then
			return;
		end
	elseif ( stageCode == 110 ) then
		if ( DCBreakingNews_TryNativeNotify("DCBreakingNews_NotifyGlueApplied",
				revision or 0) ) then
			return;
		end
	elseif ( stageCode == 900 ) then
		if ( DCBreakingNews_TryNativeNotify("DCBreakingNews_NotifyGlueError",
				detail or "glue-error") ) then
			return;
		end
	end

	if ( type(SetBreakingNewsGlueProbeState) ~= "function" ) then
		return;
	end

	SetBreakingNewsGlueProbeState(true, applied and true or false,
		revision or 0, stageCode or 0, detail or "",
		DCBREAKINGNEWS_GLUE_PACKAGE);
end

local function DCBreakingNews_HasClientApi()
	return type(HasBreakingNews) == "function"
		and type(GetBreakingNewsBody) == "function"
		and type(GetBreakingNewsRevision) == "function";
end

local function DCBreakingNews_GetParentFrame()
	if ( CharacterSelect ) then
		return CharacterSelect;
	end

	if ( GlueParent ) then
		return GlueParent;
	end

	return UIParent;
end

local function DCBreakingNews_BuildFallbackText(body)
	if ( not body or body == "" ) then
		return nil;
	end

	body = string.gsub(body, "\r\n", "\n");
	body = string.gsub(body, "\r", "\n");
	body = string.gsub(body, "<[bB][rR]%s*/?>", "\n");
	body = string.gsub(body, "</[pP]>", "\n\n");
	body = string.gsub(body, "<[pP][^>]*>", "");
	body = string.gsub(body, "</[hH][1-6]>", "\n");
	body = string.gsub(body, "<[hH][1-6][^>]*>", "");
	body = string.gsub(body, "</[lL][iI]>", "\n");
	body = string.gsub(body, "<[lL][iI][^>]*>", "* ");
	body = string.gsub(body, "<[^>]+>", "");
	body = string.gsub(body, "\n%s*\n%s*\n+", "\n\n");
	body = string.gsub(body, "^%s+", "");
	body = string.gsub(body, "%s+$", "");
	return body;
end

local function DCBreakingNews_NormalizeBody(format, body)
	if ( not body or body == "" ) then
		return nil;
	end

	if ( format == "plain" ) then
		body = string.gsub(body, "\r\n", "\n");
		body = string.gsub(body, "\r", "\n");
		return body;
	end

	return DCBreakingNews_BuildFallbackText(body);
end

local function DCBreakingNews_ApplyFontStyle(fontString, fontObjectName,
		fontPath, fontSize, r, g, b)
	if ( not fontString ) then
		return;
	end

	local fontObject = fontObjectName and _G[fontObjectName];
	if ( fontObject and fontString.SetFontObject ) then
		fontString:SetFontObject(fontObject);
		return;
	end

	if ( fontString.SetFont ) then
		fontString:SetFont(fontPath, fontSize, "");
	end
	if ( r and g and b and fontString.SetTextColor ) then
		fontString:SetTextColor(r, g, b);
	end
end

local function DCBreakingNews_EnsureFrame()
	if ( DCBreakingNewsFrame ) then
		return DCBreakingNewsFrame;
	end

	local frame = CreateFrame("Frame", "DCBreakingNewsFrame", DCBreakingNews_GetParentFrame());
	frame:SetWidth(DCBREAKINGNEWS_FRAME_WIDTH);
	frame:SetHeight(DCBREAKINGNEWS_FRAME_HEIGHT);
	frame:SetToplevel(true);
	frame:SetFrameStrata("FULLSCREEN_DIALOG");
	if ( frame.SetClampedToScreen ) then
		frame:SetClampedToScreen(true);
	end
	frame:Hide();

	if ( frame.SetBackdrop ) then
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 5, right = 5, top = 5, bottom = 5 },
		});
		frame:SetBackdropColor(0.02, 0.02, 0.02, 0.9);
	end

	local title = frame:CreateFontString(nil, "OVERLAY");
	DCBreakingNews_ApplyFontStyle(title, "GameFontHighlightLarge",
		"Fonts\\FRIZQT__.TTF", 16, 1.0, 0.82, 0.0);
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -18);
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -18);
	title:SetJustifyH("LEFT");

	local body = frame:CreateFontString(nil, "OVERLAY");
	DCBreakingNews_ApplyFontStyle(body, "GameFontHighlight",
		"Fonts\\FRIZQT__.TTF", 13, 1.0, 0.82, 0.0);
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48);
	body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18);
	body:SetJustifyH("LEFT");
	body:SetJustifyV("TOP");
	if ( body.SetNonSpaceWrap ) then
		body:SetNonSpaceWrap(true);
	end

	local closeButton = CreateFrame("Button", nil, frame);
	closeButton:SetWidth(20);
	closeButton:SetHeight(20);
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10);

	local closeText = closeButton:CreateFontString(nil, "OVERLAY");
	DCBreakingNews_ApplyFontStyle(closeText, "GameFontNormal",
		"Fonts\\FRIZQT__.TTF", 14, 1.0, 0.82, 0.0);
	closeText:SetPoint("CENTER", closeButton, "CENTER", 0, 0);
	closeText:SetText("x");

	closeButton:SetScript("OnClick", function()
		frame:Hide();
	end);

	frame.titleText = title;
	frame.bodyText = body;

	return frame;
end

local function DCBreakingNews_ShowFrame(title, body)
	local frame = DCBreakingNews_EnsureFrame();
	local parent = DCBreakingNews_GetParentFrame();

	if ( frame.GetParent and frame:GetParent() ~= parent ) then
		frame:SetParent(parent);
	end

	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -150);
	frame.titleText:SetText(title);
	frame.bodyText:SetText(body);
	frame:Show();
end

local function DCBreakingNews_HideFrame(reason)
	if ( DCBreakingNewsFrame and DCBreakingNewsFrame.Hide ) then
		DCBreakingNewsFrame:Hide();
	end

	DCBreakingNews_ReportGlueProbeState(false,
		DCBreakingNewsState.appliedRevision or 0, 30, reason or "hidden");
end

local function DCBreakingNews_ApplyCurrent(reason)
	DCBreakingNews_ReportGlueProbeState(false, 0, 40, reason or "apply-start");

	if ( not DCBreakingNews_HasClientApi() ) then
		DCBreakingNews_ReportGlueProbeState(false, 0, 50, "api-missing");
		return;
	end

	if ( not HasBreakingNews() ) then
		DCBreakingNews_HideFrame("payload-missing");
		return;
	end

	local revision = tonumber(GetBreakingNewsRevision and GetBreakingNewsRevision()) or 0;
	if ( revision ~= 0 and DCBreakingNewsState.appliedRevision == revision ) then
		DCBreakingNews_ReportGlueProbeState(true, revision, 70,
			"already-applied revision=" .. tostring(revision));
		return;
	end

	local title = "Breaking News";
	if ( type(GetBreakingNewsTitle) == "function" ) then
		local value = GetBreakingNewsTitle();
		if ( value and value ~= "" ) then
			title = value;
		end
	end

	local format = type(GetBreakingNewsFormat) == "function"
		and GetBreakingNewsFormat()
		or "simplehtml";
	local body = DCBreakingNews_NormalizeBody(format, GetBreakingNewsBody());
	if ( not body ) then
		DCBreakingNews_ReportGlueProbeState(false, revision, 80,
			"body-missing format=" .. tostring(format));
		return;
	end

	DCBreakingNews_ReportGlueProbeState(false, revision, 90,
		"show-frame reason=" .. tostring(reason or "charselect"));
	DCBreakingNews_ShowFrame(title, body);
	DCBreakingNewsState.appliedRevision = revision;
	DCBreakingNews_ReportGlueProbeState(true, revision, 110,
		"applied revision=" .. tostring(revision));
end

local function DCBreakingNews_TryApplyCurrent(reason)
	local ok, err = pcall(DCBreakingNews_ApplyCurrent, reason);
	if ( not ok ) then
		DCBreakingNews_ReportGlueProbeState(false,
			DCBreakingNewsState.appliedRevision or 0, 900, tostring(err));
	end
	return ok;
end

function DCBreakingNews_OnPayloadUpdated(revision, reason)
	local callbackReason = reason;
	if ( not callbackReason or callbackReason == "" ) then
		if ( revision and revision ~= 0 ) then
			callbackReason = "revision=" .. tostring(revision);
		else
			callbackReason = "payload-updated";
		end
	end

	if ( type(HasBreakingNews) == "function" and not HasBreakingNews() ) then
		DCBreakingNews_HideFrame("native-callback-" .. tostring(callbackReason));
		return;
	end

	DCBreakingNews_TryApplyCurrent(
		"native-callback-" .. tostring(callbackReason));
end

function DCBreakingNews_OnUpdate(elapsed)
	if ( GetCurrentGlueScreenName and GetCurrentGlueScreenName() ~= "charselect" ) then
		return;
	end

	DCBreakingNewsState.updateTimer =
		(DCBreakingNewsState.updateTimer or 0) + (tonumber(elapsed) or 0);
	if ( DCBreakingNewsState.updateTimer < 0.25 ) then
		return;
	end
	DCBreakingNewsState.updateTimer = 0;

	if ( not DCBreakingNews_HasClientApi() or not HasBreakingNews() ) then
		return;
	end

	local revision = tonumber(GetBreakingNewsRevision and GetBreakingNewsRevision()) or 0;
	if ( revision == 0 or DCBreakingNewsState.appliedRevision == revision ) then
		return;
	end

	DCBreakingNews_TryApplyCurrent(
		"onupdate-revision=" .. tostring(revision));
end


function SetGlueScreen(name)
	local newFrame;
	for index, value in pairs(GlueScreenInfo) do
		local frame = _G[value];
		if ( frame ) then
			frame:Hide();
			if ( index == name ) then
				newFrame = frame;
			end
		end
	end
	
	if ( newFrame ) then
		newFrame:Show();
		SetCurrentScreen(name);
		SetCurrentGlueScreenName(name);
		if ( name == "charselect" ) then
			DCBreakingNews_TryApplyCurrent("setgluescreen-charselect");
		else
			DCBreakingNews_HideFrame("screen=" .. tostring(name));
		end
		if ( name == "credits" ) then
			PlayCreditsMusic( GlueCreditsSoundKits[CreditsFrame.creditsType] );
			StopGlueAmbience();
		elseif ( name ~= "movie" ) then
			PlayGlueMusic(CurrentGlueMusic);
			if (name == "login") then
				PlayGlueAmbience(GlueAmbienceTracks["DARKPORTAL"], 4.0);
			end
		end
	end
end

function SetCurrentGlueScreenName(name)
	CURRENT_GLUE_SCREEN = name;
end

function GetCurrentGlueScreenName()
	return CURRENT_GLUE_SCREEN;
end

function SetPendingGlueScreenName(name)
	PENDING_GLUE_SCREEN = name;
end

function GetPendingGlueScreenName()
	return PENDING_GLUE_SCREEN;
end

function GlueParent_OnLoad(self)
	local width = GetScreenWidth();
	local height = GetScreenHeight();
	
	if ( width / height > 16 / 9) then
		local maxWidth = height * 16 / 9;
		local barWidth = ( width - maxWidth ) / 2;
		self:ClearAllPoints();
		self:SetPoint("TOPLEFT", barWidth, 0); 
		self:SetPoint("BOTTOMRIGHT", -barWidth, 0);
	end
	
	self:RegisterEvent("FRAMES_LOADED");
	self:RegisterEvent("SET_GLUE_SCREEN");
	self:RegisterEvent("START_GLUE_MUSIC");
	self:RegisterEvent("DISCONNECTED_FROM_SERVER");
	self:RegisterEvent("GET_PREFERRED_REALM_INFO");
	self:RegisterEvent("SERVER_SPLIT_NOTICE");
	self:RegisterEvent("ACCOUNT_MESSAGES_AVAILABLE");
	self:RegisterEvent("ACCOUNT_MESSAGES_HEADERS_LOADED");
	self:RegisterEvent("ACCOUNT_MESSAGES_BODY_LOADED");
	DCBreakingNews_ReportGlueProbeState(false, 0, 10, "driver-loaded");
end

function GlueParent_OnEvent(event, arg1, arg2, arg3)
	if ( event == "FRAMES_LOADED" ) then
		LocalizeFrames();
	elseif ( event == "SET_GLUE_SCREEN" ) then
		GlueScreenExit(GetCurrentGlueScreenName(), arg1);
	elseif ( event == "START_GLUE_MUSIC" ) then
		PlayGlueMusic(CurrentGlueMusic);
		PlayGlueAmbience(GlueAmbienceTracks["DARKPORTAL"], 4.0);
	elseif ( event == "DISCONNECTED_FROM_SERVER" ) then
		TokenEntry_Cancel(TokenEnterDialog);
		SetGlueScreen("login");
		if ( arg1 == 4 ) then
			GlueDialog_Show("PARENTAL_CONTROL");
		else
			GlueDialog_Show("DISCONNECTED");
		end
		AddonList:Hide();
	elseif ( event == "GET_PREFERRED_REALM_INFO" ) then
		if( arg1 == 1) then
			SetPreferredInfo(1);
		else
			SetGlueScreen("realmwizard");
			PlayGlueAmbience(GlueAmbienceTracks["DARKPORTAL"], 4.0);
		end
	elseif ( event == "SERVER_SPLIT_NOTICE" ) then
		CharacterSelectRealmSplitButton:Show();
		if ( SERVER_SPLIT_STATE_PENDING == -1 and arg1 == 0 and arg2 == 1 ) then
			SERVER_SPLIT_SHOW_DIALOG = true;
		end
		SERVER_SPLIT_CLIENT_STATE = arg1;
		SERVER_SPLIT_STATE_PENDING = arg2;
		SERVER_SPLIT_DATE = arg3;
	elseif ( event == "ACCOUNT_MESSAGES_AVAILABLE" ) then
--		ACCOUNT_MSG_NUM_AVAILABLE = arg1;
		ACCOUNT_MSG_HEADERS_LOADED = false;
		ACCOUNT_MSG_BODY_LOADED = false;
		ACCOUNT_MSG_CURRENT_INDEX = nil;
		AccountMsg_LoadHeaders();
	elseif ( event == "ACCOUNT_MESSAGES_HEADERS_LOADED" ) then
		ACCOUNT_MSG_HEADERS_LOADED = true;
		ACCOUNT_MSG_NUM_AVAILABLE = AccountMsg_GetNumUnreadMsgs();
		ACCOUNT_MSG_CURRENT_INDEX = AccountMsg_GetIndexNextUnreadMsg();
		if ( ACCOUNT_MSG_NUM_AVAILABLE > 0 ) then
			AccountMsg_LoadBody( ACCOUNT_MSG_CURRENT_INDEX );
		end
	elseif ( event == "ACCOUNT_MESSAGES_BODY_LOADED" ) then
		ACCOUNT_MSG_BODY_LOADED = true;
	end
end

-- Glue screen animation handling
function GlueScreenExit(currentFrame, pendingFrame)
	if ( currentFrame == "login" and pendingFrame == "charselect" ) then
		GlueFrameFadeOut(AccountLoginUI, LOGIN_FADE_OUT, GoToPendingGlueScreen);
		SetPendingGlueScreenName(pendingFrame);
	else
		SetGlueScreen(pendingFrame);
	end
end

function GoToPendingGlueScreen()
	SetGlueScreen(GetPendingGlueScreenName());
end

-- Generic fade function
function GlueFrameFade(frame, timeToFade, mode, finishedFunction)
	if ( frame ) then
		frame.fadeTimer = 0;
		frame.timeToFade = timeToFade;
		frame.mode = mode;
		-- finishedFunction is an optional function that is called when the animation is complete
		if ( finishedFunction ) then
			frame.finishedFunction = finishedFunction;
		end
		tinsert(FADEFRAMES, frame);
	end
end

-- Fade in function
function GlueFrameFadeIn(frame, timeToFade, finishedFunction)
	GlueFrameFade(frame, timeToFade, "IN", finishedFunction);
end

-- Fade out function
function GlueFrameFadeOut(frame, timeToFade, finishedFunction)
	GlueFrameFade(frame, timeToFade, "OUT", finishedFunction);
end

-- Function that actually performs the alpha change
function GlueFrameFadeUpdate(elapsed)
	local index = 1;
	while FADEFRAMES[index] do
		local frame = FADEFRAMES[index];
		frame.fadeTimer = frame.fadeTimer + elapsed;
		if ( frame.fadeTimer < frame.timeToFade ) then
			if ( frame.mode == "IN" ) then
				frame:SetAlpha(frame.fadeTimer / frame.timeToFade);
			elseif ( frame.mode == "OUT" ) then
				frame:SetAlpha((frame.timeToFade - frame.fadeTimer) / frame.timeToFade);
			end
		else
			if ( frame.mode == "IN" ) then
				frame:SetAlpha(1.0);
			elseif ( frame.mode == "OUT" ) then
				frame:SetAlpha(0);
			end
			GlueFrameFadeRemoveFrame(frame);
			if ( frame.finishedFunction ) then
				frame.finishedFunction();
				frame.finishedFunction = nil;
			end
		end
		index = index + 1;
	end
end

function GlueFrameRemoveFrame(frame, list)
	local index = 1;
	while list[index] do
		if ( frame == list[index] ) then
			tremove(list, index);
		end
		index = index + 1;
	end
end

function GlueFrameFadeRemoveFrame(frame)
	GlueFrameRemoveFrame(frame, FADEFRAMES);
end

function SetLighting(model, race)
	model:SetSequence(0);
	model:SetCamera(0);
	local fogInfo = CharModelFogInfo[race];
	if ( fogInfo ) then
		model:SetFogColor(fogInfo.r, fogInfo.g, fogInfo.b);
		model:SetFogNear(0);
		model:SetFogFar(fogInfo.far);
	else
		model:ClearFog();
    end

    local glowInfo = CharModelGlowInfo[race];
    if ( glowInfo ) then
        model:SetGlow(glowInfo);
    else
        model:SetGlow(0.3);
    end

    model:ResetLights();
	--[[ 
	ResetLights() sets all 6 light sets to default for the background. The six sets are:

		background - live
		background - ghost
		character - live
		character - ghost
		pet - live
		pet - ghost

	If you add a light to any one of these, NONE of the default lights are used for that set (most backgrounds have 3).

	You can add up to four lights per light set in the current version. They are merged in the engine.

    The current version only supports setting directional lights, and pulls the default point lights from the models.
	]]
	local LightValues = RaceLights[race];
	if(LightValues) then 
		for index, Array in pairs (LightValues) do
			if (Array[1]==1) then	-- is this light enabled?
				for j, f in pairs ({model.AddCharacterLight, model.AddLight, model.AddPetLight }) do
					f(model, LIGHT_LIVE, unpack(Array));
				end
			end
		end
	end
end

-- Function to set the background model for character select and create screens
function SetBackgroundModel(model, name)
    local nameupper = strupper(name);
    local path = "Interface\\Glues\\Models\\UI_"..name.."\\UI_"..name..".m2";
	if ( model == CharacterCreate ) then
		SetCharCustomizeBackground(path);
	else
		SetCharSelectBackground(path);
	end
	PlayGlueAmbience(GlueAmbienceTracks[nameupper], 4.0);
	SetLighting(model, nameupper)
end

function SecondsToTime(seconds, noSeconds)
	local time = "";
	local count = 0;
	local tempTime;
	seconds = floor(seconds);
	if ( seconds >= 86400  ) then
		tempTime = floor(seconds / 86400);
		time = tempTime.." "..DAYS_ABBR.." ";
		seconds = mod(seconds, 86400);
		count = count + 1;
	end
	if ( seconds >= 3600  ) then
		tempTime = floor(seconds / 3600);
		time = time..tempTime.." "..HOURS_ABBR.." ";
		seconds = mod(seconds, 3600);
		count = count + 1;
	end
	if ( count < 2 and seconds >= 60  ) then
		tempTime = floor(seconds / 60);
		time = time..tempTime.." "..MINUTES_ABBR.." ";
		seconds = mod(seconds, 60);
		count = count + 1;
	end
	if ( count < 2 and seconds > 0 and not noSeconds ) then
		seconds = format("%d", seconds);
		time = time..seconds.." "..SECONDS_ABBR.." ";
	end
	return time;
end

function MinutesToTime(mins, hideDays)
	local time = "";
	local count = 0;
	local tempTime;
	-- only show days if hideDays is false
	if ( mins > 1440 and not hideDays ) then
		tempTime = floor(mins / 1440);
		time = tempTime.." "..DAYS_ABBR.." ";
		mins = mod(mins, 1440);
		count = count + 1;
	end
	if ( mins > 60  ) then
		tempTime = floor(mins / 60);
		time = time..tempTime.." "..HOURS_ABBR.." ";
		mins = mod(mins, 60);
		count = count + 1;
	end
	if ( count < 2 ) then
		tempTime = mins;
		time = time..tempTime.." "..MINUTES_ABBR.." ";
		count = count + 1;
	end
	return time;
end

function TriStateCheckbox_SetState(checked, checkButton)
	local checkedTexture = _G[checkButton:GetName().."CheckedTexture"];
	if ( not checkedTexture ) then
		message("Can't find checked texture");
	end
	if ( not checked or checked == 0 ) then
		-- nil or 0 means not checked
		checkButton:SetChecked(nil);
		checkButton.state = 0;
	elseif ( checked == 2 ) then
		-- 2 is a normal
		checkButton:SetChecked(1);
		checkedTexture:SetVertexColor(1, 1, 1);
		checkedTexture:SetDesaturated(0);
		checkButton.state = 2;
	else
		-- 1 is a gray check
		checkButton:SetChecked(1);
		local shaderSupported = checkedTexture:SetDesaturated(1);
		if ( not shaderSupported ) then
			checkedTexture:SetVertexColor(0.5, 0.5, 0.5);
		end
		checkButton.state = 1;
	end
end

function SetStateRequestInfo( choice )
	if ( SERVER_SPLIT_CLIENT_STATE ~= choice ) then
		SERVER_SPLIT_CLIENT_STATE = choice;
		SetRealmSplitState(choice);
		RealmSplit_SetChoiceText();
--		RequestRealmSplitInfo();
	end
end

function UpgradeAccount()
	PlaySound("gsLoginNewAccount");
	LaunchURL(AUTH_NO_TIME_URL);
end

