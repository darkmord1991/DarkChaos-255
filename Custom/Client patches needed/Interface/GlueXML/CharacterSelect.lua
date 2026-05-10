CHARACTER_SELECT_ROTATION_START_X = nil;
CHARACTER_SELECT_INITIAL_FACING = nil;

CHARACTER_ROTATION_CONSTANT = 0.6;

MAX_CHARACTERS_DISPLAYED = 10;
CHARACTER_SELECT_VISIBLE_BUTTONS = 8;
MAX_CHARACTERS_PER_REALM = 25;

function CharacterSelect_HasExpandedCharacterList()
	return type(DC_HasExpandedCharacterList) == "function" and DC_HasExpandedCharacterList();
end

function CharacterSelect_GetNumCharacters()
	if ( CharacterSelect_HasExpandedCharacterList() and type(DC_GetExpandedCharacterCount) == "function" ) then
		return tonumber(DC_GetExpandedCharacterCount()) or 0;
	end

	return GetNumCharacters();
end

function CharacterSelect_GetExpandedWindowStart()
	if ( CharacterSelect_HasExpandedCharacterList() and type(DC_GetExpandedCharacterWindowStart) == "function" ) then
		return tonumber(DC_GetExpandedCharacterWindowStart()) or 1;
	end

	return 1;
end

function CharacterSelect_SetExpandedWindow(startIndex)
	if ( CharacterSelect_HasExpandedCharacterList() and type(DC_SetExpandedCharacterWindow) == "function" ) then
		return tonumber(DC_SetExpandedCharacterWindow(startIndex)) or 0;
	end

	return 0;
end

function CharacterSelect_MapToNativeIndex(index)
	if ( CharacterSelect_HasExpandedCharacterList() and type(DC_MapExpandedCharacterIndex) == "function" ) then
		return tonumber(DC_MapExpandedCharacterIndex(index)) or 0;
	end

	return index;
end

function CharacterSelect_MapToGlobalIndex(index)
	if ( CharacterSelect_HasExpandedCharacterList() ) then
		return CharacterSelect_GetExpandedWindowStart() + index - 1;
	end

	return index;
end

function CharacterSelect_EnsureNativeWindow(firstDisplayIndex)
	if ( not CharacterSelect_HasExpandedCharacterList() ) then
		return false;
	end

	local numChars = CharacterSelect_GetNumCharacters();
	local previousWindowStart = CharacterSelect_GetExpandedWindowStart();
	local maxWindowStart = max(numChars - MAX_CHARACTERS_DISPLAYED + 1, 1);
	local targetWindowStart = min(max(firstDisplayIndex or 1, 1), maxWindowStart);
	CharacterSelect_SetExpandedWindow(targetWindowStart);

	return CharacterSelect_GetExpandedWindowStart() ~= previousWindowStart;
end

function CharacterSelect_GetCharacterInfoForIndex(index)
	local nativeIndex = CharacterSelect_MapToNativeIndex(index);
	if ( not nativeIndex or nativeIndex < 1 ) then
		return nil;
	end

	return GetCharacterInfo(nativeIndex);
end

function CharacterSelect_GetBackgroundModelForIndex(index)
	local nativeIndex = CharacterSelect_MapToNativeIndex(index);
	if ( not nativeIndex or nativeIndex < 1 ) then
		return nil;
	end

	return GetSelectBackgroundModel(nativeIndex);
end

function CharacterSelect_CanCreateCharacter(numChars)
	return IsConnectedToServer() and numChars < MAX_CHARACTERS_PER_REALM;
end

function CharacterSelect_GetDisplayCount(numChars)
	return numChars;
end

function CharacterSelect_GetMaxScrollOffset(numChars)
	local displayCount = CharacterSelect_GetDisplayCount(numChars or 0);
	return max(displayCount - CHARACTER_SELECT_VISIBLE_BUTTONS, 0);
end

function CharacterSelect_GetDisplayRange(numChars)
	local displayCount = CharacterSelect_GetDisplayCount(numChars or 0);
	local scrollOffset = CharacterSelect.scrollOffset or 0;
	local firstDisplayIndex = scrollOffset + 1;
	local lastDisplayIndex = min(displayCount, scrollOffset + CHARACTER_SELECT_VISIBLE_BUTTONS);

	if ( displayCount == 0 ) then
		firstDisplayIndex = 0;
		lastDisplayIndex = 0;
	end

	return firstDisplayIndex, lastDisplayIndex;
end

function CharacterSelect_EnsureVisibleIndex(index, numChars)
	if ( not index or index < 1 ) then
		return;
	end

	local maxScrollOffset = CharacterSelect_GetMaxScrollOffset(numChars);
	local scrollOffset = CharacterSelect.scrollOffset or 0;

	if ( index <= scrollOffset ) then
		scrollOffset = index - 1;
	elseif ( index > scrollOffset + CHARACTER_SELECT_VISIBLE_BUTTONS ) then
		scrollOffset = index - CHARACTER_SELECT_VISIBLE_BUTTONS;
	end

	CharacterSelect.scrollOffset = min(max(scrollOffset, 0), maxScrollOffset);
end

function CharacterSelect_EnsurePaginationControls()
	if ( CharSelectCountText ) then
		return;
	end

	if ( not CharacterSelectCharacterFrame or not CreateFrame ) then
		return;
	end

	local countText = CharacterSelectCharacterFrame:CreateFontString("CharSelectCountText", "ARTWORK", "GlueFontDisableSmall");
	countText:SetPoint("TOP", CharSelectChangeRealmButton, "BOTTOM", 0, -8);
	countText:SetWidth(220);
	countText:SetJustifyH("CENTER");
	countText:Hide();

	local scrollBar = CreateFrame("Slider", "CharSelectScrollBar", CharacterSelectCharacterFrame);
	scrollBar:SetWidth(18);
	scrollBar:SetPoint("TOPRIGHT", CharacterSelectCharacterFrame, "TOPRIGHT", -8, -104);
	scrollBar:SetPoint("BOTTOMRIGHT", CharacterSelectCharacterFrame, "BOTTOMRIGHT", -8, 86);
	scrollBar:SetOrientation("VERTICAL");
	scrollBar:SetMinMaxValues(0, 0);
	scrollBar:SetValue(0);
	scrollBar:SetValueStep(1);
	scrollBar:Hide();

	local track = scrollBar:CreateTexture(nil, "BACKGROUND");
	track:SetTexture("Interface\\Buttons\\WHITE8X8");
	track:SetVertexColor(0.08, 0.08, 0.08, 0.85);
	track:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", 5, -8);
	track:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", -5, 8);

	local thumb = scrollBar:CreateTexture(nil, "ARTWORK");
	thumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob");
	thumb:SetWidth(18);
	thumb:SetHeight(24);
	scrollBar:SetThumbTexture(thumb);

	scrollBar:SetScript("OnValueChanged", function(self, value)
		if ( CharacterSelect.updatingScrollBar ) then
			return;
		end

		local scrollOffset = floor(value + 0.5);
		if ( scrollOffset == (CharacterSelect.scrollOffset or 0) ) then
			return;
		end

		CharacterSelect.scrollOffset = scrollOffset;
		UpdateCharacterList();
	end);

	if ( CharacterSelectCharacterFrame.EnableMouseWheel ) then
		CharacterSelectCharacterFrame:EnableMouseWheel(true);
		CharacterSelectCharacterFrame:SetScript("OnMouseWheel", function(_, delta)
			if ( delta > 0 ) then
				CharacterSelect_ChangeScroll(-1);
			elseif ( delta < 0 ) then
				CharacterSelect_ChangeScroll(1);
			end
		end);
	end
end

function CharacterSelect_UpdatePaginationControls(numChars)
	CharacterSelect_EnsurePaginationControls();

	if ( not CharSelectCountText or not CharSelectScrollBar ) then
		return;
	end

	if ( CharSelectCountText ) then
		CharSelectCountText:SetFormattedText("Characters: %d/%d", numChars, MAX_CHARACTERS_PER_REALM);
		CharSelectCountText:Show();
	end

	local maxScrollOffset = CharacterSelect_GetMaxScrollOffset(numChars);
	if ( maxScrollOffset <= 0 ) then
		CharSelectScrollBar:Hide();
		return;
	end

	CharacterSelect.updatingScrollBar = true;
	CharSelectScrollBar:SetMinMaxValues(0, maxScrollOffset);
	CharSelectScrollBar:SetValue(CharacterSelect.scrollOffset or 0);
	CharacterSelect.updatingScrollBar = nil;
	CharSelectScrollBar:Show();
end

function CharacterSelect_ChangeScroll(delta)
	local numChars = CharacterSelect_GetNumCharacters();
	local maxScrollOffset = CharacterSelect_GetMaxScrollOffset(numChars);
	if ( maxScrollOffset <= 0 ) then
		return;
	end

	local currentScrollOffset = CharacterSelect.scrollOffset or 0;
	local targetScrollOffset = min(max(currentScrollOffset + delta, 0), maxScrollOffset);
	if ( targetScrollOffset == currentScrollOffset ) then
		return;
	end

	CharacterSelect.scrollOffset = targetScrollOffset;

	UpdateCharacterList();
end

function CharacterSelect_UpdateSelectedCharacter()
	if ( CharacterSelect.selectedIndex == 0 ) then
		CharSelectCharacterName:SetText("");
		return;
	end

	local name = CharacterSelect_GetCharacterInfoForIndex(CharacterSelect.selectedIndex);
	if ( not name ) then
		CharSelectCharacterName:SetText("");
		return;
	end

	CharSelectCharacterName:SetText(name);
	CharacterSelect.currentModel = CharacterSelect_GetBackgroundModelForIndex(CharacterSelect.selectedIndex);
	if ( CharacterSelect.currentModel ) then
		SetBackgroundModel(CharacterSelect, CharacterSelect.currentModel);
	end
end

function CharacterSelect_OnLoad(self)
	self:SetSequence(0);
	self:SetCamera(0);

	self.createIndex = 0;
	self.selectedIndex = 0;
	self.selectLast = 0;
	self.currentModel = nil;
	self.scrollOffset = 0;
	self:RegisterEvent("ADDON_LIST_UPDATE");
	self:RegisterEvent("CHARACTER_LIST_UPDATE");
	self:RegisterEvent("UPDATE_SELECTED_CHARACTER");
	self:RegisterEvent("SELECT_LAST_CHARACTER");
	self:RegisterEvent("SELECT_FIRST_CHARACTER");
	self:RegisterEvent("SUGGEST_REALM");
	self:RegisterEvent("FORCE_RENAME_CHARACTER");

	SetCharSelectModelFrame("CharacterSelect");

	-- Color edit box backdrops
	local backdropColor = DEFAULT_TOOLTIP_COLOR;
	CharacterSelectCharacterFrame:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	CharacterSelectCharacterFrame:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6], 0.85);

	CharacterSelect_EnsurePaginationControls();
end

function CharacterSelect_OnShow()
	CharacterSelect_EnsurePaginationControls();
	ReadyForAccountDataTimes();

	local currentModel = CharacterSelect.currentModel;
	if ( currentModel ) then
		SetBackgroundModel(CharacterSelect, currentModel);
		PlayGlueAmbience(GlueAmbienceTracks[strupper(currentModel)], 4.0);
	end

	UpdateAddonButton();

	local serverName, isPVP, isRP = GetServerName();
	local connected = IsConnectedToServer();
	local serverType = "";
	if ( serverName ) then
		if( not connected ) then
			serverName = serverName.."\n("..SERVER_DOWN..")";
		end
		if ( isPVP ) then
			if ( isRP ) then
				serverType = RPPVP_PARENTHESES;
			else
				serverType = PVP_PARENTHESES;
			end
		elseif ( isRP ) then
			serverType = RP_PARENTHESES;
		end
		CharSelectRealmName:SetText(serverName.." "..serverType);
		CharSelectRealmName:Show();
	else
		CharSelectRealmName:Hide();
	end

	if ( connected ) then
		GetCharacterListUpdate();
	else
		UpdateCharacterList();
	end

	-- Gameroom billing stuff (For Korea and China only)
	if ( SHOW_GAMEROOM_BILLING_FRAME ) then
		local paymentPlan, hasFallBackBillingMethod, isGameRoom = GetBillingPlan();
		if ( paymentPlan == 0 ) then
			-- No payment plan
			GameRoomBillingFrame:Hide();
			CharacterSelectRealmSplitButton:ClearAllPoints();
			CharacterSelectRealmSplitButton:SetPoint("TOP", CharacterSelectLogo, "BOTTOM", 0, -5);
		else
			local billingTimeLeft = GetBillingTimeRemaining();
			-- Set default text for the payment plan
			local billingText = _G["BILLING_TEXT"..paymentPlan];
			if ( paymentPlan == 1 ) then
				-- Recurring account
				billingTimeLeft = ceil(billingTimeLeft/(60 * 24));
				if ( billingTimeLeft == 1 ) then
					billingText = BILLING_TIME_LEFT_LAST_DAY;
				end
			elseif ( paymentPlan == 2 ) then
				-- Free account
				if ( billingTimeLeft < (24 * 60) ) then
					billingText = format(BILLING_FREE_TIME_EXPIRE, billingTimeLeft.." "..MINUTES_ABBR);
				end
			elseif ( paymentPlan == 3 ) then
				-- Fixed but not recurring
				if ( isGameRoom == 1 ) then
					if ( billingTimeLeft <= 30 ) then
						billingText = BILLING_GAMEROOM_EXPIRE;
					else
						billingText = format(BILLING_FIXED_IGR, MinutesToTime(billingTimeLeft, 1));
					end
				else
					-- personal fixed plan
					if ( billingTimeLeft < (24 * 60) ) then
						billingText = BILLING_FIXED_LASTDAY;
					else
						billingText = format(billingText, MinutesToTime(billingTimeLeft));
					end
				end
			elseif ( paymentPlan == 4 ) then
				-- Usage plan
				if ( isGameRoom == 1 ) then
					-- game room usage plan
					if ( billingTimeLeft <= 600 ) then
						billingText = BILLING_GAMEROOM_EXPIRE;
					else
						billingText = BILLING_IGR_USAGE;
					end
				else
					-- personal usage plan
					if ( billingTimeLeft <= 30 ) then
						billingText = BILLING_TIME_LEFT_30_MINS;
					else
						billingText = format(billingText, billingTimeLeft);
					end
				end
			end
			-- If fallback payment method add a note that says so
			if ( hasFallBackBillingMethod == 1 ) then
				billingText = billingText.."\n\n"..BILLING_HAS_FALLBACK_PAYMENT;
			end
			GameRoomBillingFrameText:SetText(billingText);
			GameRoomBillingFrame:SetHeight(GameRoomBillingFrameText:GetHeight() + 26);
			GameRoomBillingFrame:Show();
			CharacterSelectRealmSplitButton:ClearAllPoints();
			CharacterSelectRealmSplitButton:SetPoint("TOP", GameRoomBillingFrame, "BOTTOM", 0, -10);
		end
	end

	if ( CharacterSelectUpgradeAccountButton ) then
		if ( IsTrialAccount() ) then
			CharacterSelectUpgradeAccountButton:Show();
		else
			CharacterSelectUpgradeAccountButton:Hide();
		end
	end

	-- fadein the character select ui
	GlueFrameFadeIn(CharacterSelectUI, CHARACTER_SELECT_FADE_IN)

	RealmSplitCurrentChoice:Hide();
	RequestRealmSplitInfo();

	--Clear out the addons selected item
	GlueDropDownMenu_SetSelectedValue(AddonCharacterDropDown, ALL);
end

function CharacterSelect_OnHide()
	CharacterDeleteDialog:Hide();
	CharacterRenameDialog:Hide();
	if ( DeclensionFrame ) then
		DeclensionFrame:Hide();
	end
	SERVER_SPLIT_STATE_PENDING = -1;
end

function CharacterSelect_OnUpdate(elapsed)
	if ( SERVER_SPLIT_STATE_PENDING > 0 ) then
		CharacterSelectRealmSplitButton:Show();

		if ( SERVER_SPLIT_CLIENT_STATE > 0 ) then
			RealmSplit_SetChoiceText();
			RealmSplitPending:SetPoint("TOP", RealmSplitCurrentChoice, "BOTTOM", 0, -10);
		else
			RealmSplitPending:SetPoint("TOP", CharacterSelectRealmSplitButton, "BOTTOM", 0, 0);
			RealmSplitCurrentChoice:Hide();
		end

		if ( SERVER_SPLIT_STATE_PENDING > 1 ) then
			CharacterSelectRealmSplitButton:Disable();
			CharacterSelectRealmSplitButtonGlow:Hide();
			RealmSplitPending:SetText( SERVER_SPLIT_PENDING );
		else
			CharacterSelectRealmSplitButton:Enable();
			CharacterSelectRealmSplitButtonGlow:Show();
			local datetext = SERVER_SPLIT_CHOOSE_BY.."\n"..SERVER_SPLIT_DATE;
			RealmSplitPending:SetText( datetext );
		end

		if ( SERVER_SPLIT_SHOW_DIALOG and not GlueDialog:IsShown() ) then
			SERVER_SPLIT_SHOW_DIALOG = false;
			local dialogString = format(SERVER_SPLIT,SERVER_SPLIT_DATE);
			if ( SERVER_SPLIT_CLIENT_STATE > 0 ) then
				local serverChoice = RealmSplit_GetFormatedChoice(SERVER_SPLIT_REALM_CHOICE);
				local stringWithDate = format(SERVER_SPLIT,SERVER_SPLIT_DATE);
				dialogString = stringWithDate.."\n\n"..serverChoice;
				GlueDialog_Show("SERVER_SPLIT_WITH_CHOICE", dialogString);
			else
				GlueDialog_Show("SERVER_SPLIT", dialogString);
			end
		end
	else
		CharacterSelectRealmSplitButton:Hide();
	end

	-- Account Msg stuff
	if ( (ACCOUNT_MSG_NUM_AVAILABLE > 0) and not GlueDialog:IsShown() ) then
		if ( ACCOUNT_MSG_HEADERS_LOADED ) then
			if ( ACCOUNT_MSG_BODY_LOADED ) then
				local dialogString = AccountMsg_GetHeaderSubject( ACCOUNT_MSG_CURRENT_INDEX ).."\n\n"..AccountMsg_GetBody();
				GlueDialog_Show("ACCOUNT_MSG", dialogString);
			end
		end
	end
end

function CharacterSelect_OnKeyDown(self,key)
	if ( key == "ESCAPE" ) then
		CharacterSelect_Exit();
	elseif ( key == "ENTER" ) then
		CharacterSelect_EnterWorld();
	elseif ( key == "PRINTSCREEN" ) then
		Screenshot();
	elseif ( key == "UP" or key == "LEFT" ) then
		local numChars = CharacterSelect_GetNumCharacters();
		if ( numChars > 1 ) then
			if ( self.selectedIndex > 1 ) then
				CharacterSelect_SelectCharacter(self.selectedIndex - 1);
			else
				CharacterSelect_SelectCharacter(numChars);
			end
		end
	elseif ( key == "DOWN" or key == "RIGHT" ) then
		local numChars = CharacterSelect_GetNumCharacters();
		if ( numChars > 1 ) then
			if ( self.selectedIndex < numChars ) then
				CharacterSelect_SelectCharacter(self.selectedIndex + 1);
			else
				CharacterSelect_SelectCharacter(1);
			end
		end
	end
end

function CharacterSelect_OnEvent(self, event, ...)
	if ( event == "ADDON_LIST_UPDATE" ) then
		UpdateAddonButton();
	elseif ( event == "CHARACTER_LIST_UPDATE" ) then
		UpdateCharacterList();
	elseif ( event == "UPDATE_SELECTED_CHARACTER" ) then
		local index = ...;
		if ( index == 0 ) then
			self.selectedIndex = 0;
			CharSelectCharacterName:SetText("");
		else
			if ( CharacterSelect_HasExpandedCharacterList() ) then
				index = CharacterSelect_MapToGlobalIndex(index);
			end
			local previousScrollOffset = self.scrollOffset or 0;
			local numChars = CharacterSelect_GetNumCharacters();
			self.selectedIndex = index;
			CharacterSelect_EnsureVisibleIndex(index, numChars);
			if ( (self.scrollOffset or 0) ~= previousScrollOffset ) then
				UpdateCharacterList();
				return;
			end
			CharacterSelect_UpdateSelectedCharacter();
			UpdateCharacterSelection(self);
			return;
		end
		UpdateCharacterSelection(self);
	elseif ( event == "SELECT_LAST_CHARACTER" ) then
		self.selectLast = 1;
	elseif ( event == "SELECT_FIRST_CHARACTER" ) then
		CharacterSelect_SelectCharacter(1, 1);
	elseif ( event == "SUGGEST_REALM" ) then
		local category, id = ...;
		local name = GetRealmInfo(category, id);
		if ( name ) then
			SetGlueScreen("charselect");
			ChangeRealm(category, id);
		else
			if ( RealmList:IsShown() ) then
				RealmListUpdate();
			else
				RealmList:Show();
			end
		end
	elseif ( event == "FORCE_RENAME_CHARACTER" ) then
		local message = ...;
		CharacterRenameDialog:Show();
		CharacterRenameText1:SetText(_G[message]);
	end
end

function CharacterSelect_UpdateModel(self)
	UpdateSelectionCustomizationScene();
	self:AdvanceTime();
end

function UpdateCharacterSelection(self)
	for i=1, MAX_CHARACTERS_DISPLAYED, 1 do
		local button = _G["CharSelectCharacterButton"..i];
		if ( button ) then
			button:UnlockHighlight();
			if ( button:GetID() == self.selectedIndex ) then
				button:LockHighlight();
			end
		end
	end
end

function UpdateCharacterList()
	local numChars = CharacterSelect_GetNumCharacters();
	local maxScrollOffset = CharacterSelect_GetMaxScrollOffset(numChars);
	local previousNumChars = CharacterSelect.lastNumChars or 0;
	local reselectionRequired = previousNumChars ~= numChars;

	if ( CharacterSelect.selectLast == 1 ) then
		CharacterSelect.selectLast = 0;
		if ( CharacterSelect.selectedIndex ~= numChars ) then
			CharacterSelect.selectedIndex = numChars;
			reselectionRequired = true;
		end
	end

	if ( numChars > 0 ) then
		if ( CharacterSelect.selectedIndex > numChars ) then
			CharacterSelect.selectedIndex = numChars;
			reselectionRequired = true;
		end
		CharacterSelect.scrollOffset = min(max(CharacterSelect.scrollOffset or 0, 0), maxScrollOffset);

		local firstDisplayIndex, lastDisplayIndex = CharacterSelect_GetDisplayRange(numChars);
		local firstCharacterOnPage = firstDisplayIndex;
		if ( CharacterSelect.selectedIndex == 0 ) then
			if ( firstCharacterOnPage <= numChars ) then
				CharacterSelect.selectedIndex = firstCharacterOnPage;
				reselectionRequired = true;
			end
		end
	else
		CharacterSelect.scrollOffset = 0;
		CharacterSelect.selectedIndex = 0;
		reselectionRequired = false;
	end

	local visibleIndex = 1;
	local startDisplayIndex, endDisplayIndex = CharacterSelect_GetDisplayRange(numChars);
	if ( numChars > 0 and CharacterSelect_EnsureNativeWindow(startDisplayIndex) ) then
		reselectionRequired = true;
	end
	local startIndex = startDisplayIndex;
	local endIndex = min(numChars, endDisplayIndex);
	if ( startIndex > 0 and endIndex >= startIndex ) then
	for charIndex = startIndex, endIndex, 1 do
		local name, race, class, level, zone, sex, ghost, PCC, PRC, PFC = CharacterSelect_GetCharacterInfoForIndex(charIndex);
		local button = _G["CharSelectCharacterButton"..visibleIndex];
		local customizeButton = _G["CharSelectCharacterCustomize"..visibleIndex];
		local raceChangeButton = _G["CharSelectRaceChange"..visibleIndex];
		local factionChangeButton = _G["CharSelectFactionChange"..visibleIndex];

		button:SetID(charIndex);
		if ( not name ) then
			button:Hide();
		else
			if ( not zone ) then
				zone = "";
			end
			_G["CharSelectCharacterButton"..visibleIndex.."ButtonTextName"]:SetText(name);
			if( ghost ) then
				_G["CharSelectCharacterButton"..visibleIndex.."ButtonTextInfo"]:SetFormattedText(CHARACTER_SELECT_INFO_GHOST, level, class);
			else
				_G["CharSelectCharacterButton"..visibleIndex.."ButtonTextInfo"]:SetFormattedText(CHARACTER_SELECT_INFO, level, class);
			end
			_G["CharSelectCharacterButton"..visibleIndex.."ButtonTextLocation"]:SetText(zone);
		end
		button:Show();

		if ( customizeButton ) then
			customizeButton:SetID(charIndex);
			customizeButton:Hide();
		end
		if ( raceChangeButton ) then
			raceChangeButton:SetID(charIndex);
			raceChangeButton:Hide();
		end
		if ( factionChangeButton ) then
			factionChangeButton:SetID(charIndex);
			factionChangeButton:Hide();
		end

		if ( PFC ) then
			if ( factionChangeButton ) then
				factionChangeButton:Show();
			end
		elseif ( PRC ) then
			if ( raceChangeButton ) then
				raceChangeButton:Show();
			end
		elseif ( PCC ) then
			if ( customizeButton ) then
				customizeButton:Show();
			end
		end

		visibleIndex = visibleIndex + 1;
	end
	end

	for i = visibleIndex, MAX_CHARACTERS_DISPLAYED, 1 do
		local button = _G["CharSelectCharacterButton"..i];
		local customizeButton = _G["CharSelectCharacterCustomize"..i];
		local raceChangeButton = _G["CharSelectRaceChange"..i];
		local factionChangeButton = _G["CharSelectFactionChange"..i];

		if ( customizeButton ) then
			customizeButton:Hide();
		end
		if ( raceChangeButton ) then
			raceChangeButton:Hide();
		end
		if ( factionChangeButton ) then
			factionChangeButton:Hide();
		end
		button:Hide();
	end

	if ( numChars == 0 or CharacterSelect.selectedIndex == 0 ) then
		CharacterSelectDeleteButton:Disable();
		CharSelectEnterWorldButton:Disable();
	else
		CharacterSelectDeleteButton:Enable();
		CharSelectEnterWorldButton:Enable();
	end

	CharacterSelect.createIndex = 0;
	CharSelectCreateCharacterButton:Hide();

	if ( CharacterSelect_CanCreateCharacter(numChars) ) then
		CharacterSelect.createIndex = numChars + 1;
		CharSelectCreateCharacterButton:SetID(CharacterSelect.createIndex);
		CharSelectCreateCharacterButton:Show();
	end

	CharacterSelect_UpdatePaginationControls(numChars);
	CharacterSelect.lastNumChars = numChars;

	if ( numChars == 0 ) then
		CharacterSelect.selectedIndex = 0;
		CharSelectCharacterName:SetText("");
		UpdateCharacterSelection(CharacterSelect);
		return;
	end

	if ( reselectionRequired ) then
		CharacterSelect_SelectCharacter(CharacterSelect.selectedIndex, 1, 1);
	else
		CharacterSelect_UpdateSelectedCharacter();
	end
	UpdateCharacterSelection(CharacterSelect);
end

function CharacterSelectButton_OnClick(self)
	local id = self:GetID();
	if ( id ~= CharacterSelect.selectedIndex ) then
		CharacterSelect_SelectCharacter(id);
	end
end

function CharacterSelectButton_OnDoubleClick(self)
	local id = self:GetID();
	if ( id ~= CharacterSelect.selectedIndex ) then
		CharacterSelect_SelectCharacter(id);
	end
	if ( id and id > 0 ) then
		CharacterSelect_EnterWorld();
	end
end

function CharacterSelect_TabResize(self)
	local buttonMiddle = _G[self:GetName().."Middle"];
	local buttonMiddleDisabled = _G[self:GetName().."MiddleDisabled"];
	local width = self:GetTextWidth() - 8;
	local leftWidth = _G[self:GetName().."Left"]:GetWidth();
	buttonMiddle:SetWidth(width);
	buttonMiddleDisabled:SetWidth(width);
	self:SetWidth(width + (2 * leftWidth));
end

function CharacterSelect_SelectCharacter(id, noCreate, skipListRefresh)
	if ( id == CharacterSelect.createIndex ) then
		if ( not noCreate ) then
			PlaySound("gsCharacterSelectionCreateNew");
			SetGlueScreen("charcreate");
		end
		return;
	end

	local numChars = CharacterSelect_GetNumCharacters();
	if ( id < 1 or id > numChars ) then
		return;
	end

	CharacterSelect.selectedIndex = id;
	CharacterSelect_EnsureVisibleIndex(id, numChars);
	local firstDisplayIndex = CharacterSelect_GetDisplayRange(numChars);
	CharacterSelect_EnsureNativeWindow(firstDisplayIndex);
	local nativeIndex = CharacterSelect_MapToNativeIndex(id);
	if ( not nativeIndex or nativeIndex < 1 ) then
		return;
	end

	CharacterSelect.currentModel = CharacterSelect_GetBackgroundModelForIndex(id);
	if ( CharacterSelect.currentModel ) then
		SetBackgroundModel(CharacterSelect, CharacterSelect.currentModel);
	end
	SelectCharacter(nativeIndex);
	if ( not skipListRefresh ) then
		UpdateCharacterList();
	end
end

function CharacterDeleteDialog_OnShow()
	local name, race, class, level = CharacterSelect_GetCharacterInfoForIndex(CharacterSelect.selectedIndex);
	CharacterDeleteText1:SetFormattedText(CONFIRM_CHAR_DELETE, name, level, class);
	CharacterDeleteBackground:SetHeight(16 + CharacterDeleteText1:GetHeight() + CharacterDeleteText2:GetHeight() + 23 + CharacterDeleteEditBox:GetHeight() + 8 + CharacterDeleteButton1:GetHeight() + 16);
	CharacterDeleteButton1:Disable();
end

function CharacterSelect_EnterWorld()
	PlaySound("gsCharacterSelectionEnterWorld");
	StopGlueAmbience();
	EnterWorld();
end

function CharacterSelect_Exit()
	PlaySound("gsCharacterSelectionExit");
	DisconnectFromServer();
	SetGlueScreen("login");
end

function CharacterSelect_AccountOptions()
	PlaySound("gsCharacterSelectionAcctOptions");
end

function CharacterSelect_TechSupport()
	PlaySound("gsCharacterSelectionAcctOptions");
	LaunchURL(TECH_SUPPORT_URL);
end

function CharacterSelect_Delete()
	PlaySound("gsCharacterSelectionDelCharacter");
	if ( CharacterSelect.selectedIndex > 0 ) then
		CharacterDeleteDialog:Show();
	end
end

function CharacterSelect_ChangeRealm()
	PlaySound("gsCharacterSelectionDelCharacter");
	RequestRealmList(1);
end

function CharacterSelectFrame_OnMouseDown(button)
	if ( button == "LeftButton" ) then
		CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
		CHARACTER_SELECT_INITIAL_FACING = GetCharacterSelectFacing();
	end
end

function CharacterSelectFrame_OnMouseUp(button)
	if ( button == "LeftButton" ) then
		CHARACTER_SELECT_ROTATION_START_X = nil
	end
end

function CharacterSelectFrame_OnUpdate()
	if ( CHARACTER_SELECT_ROTATION_START_X ) then
		local x = GetCursorPosition();
		local diff = (x - CHARACTER_SELECT_ROTATION_START_X) * CHARACTER_ROTATION_CONSTANT;
		CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
		SetCharacterSelectFacing(GetCharacterSelectFacing() + diff);
	end
end

function CharacterSelectRotateRight_OnUpdate(self)
	if ( self:GetButtonState() == "PUSHED" ) then
		SetCharacterSelectFacing(GetCharacterSelectFacing() + CHARACTER_FACING_INCREMENT);
	end
end

function CharacterSelectRotateLeft_OnUpdate(self)
	if ( self:GetButtonState() == "PUSHED" ) then
		SetCharacterSelectFacing(GetCharacterSelectFacing() - CHARACTER_FACING_INCREMENT);
	end
end

function CharacterSelect_ManageAccount()
	PlaySound("gsCharacterSelectionAcctOptions");
	LaunchURL(AUTH_NO_TIME_URL);
end

function RealmSplit_GetFormatedChoice(formatText)
	if ( SERVER_SPLIT_CLIENT_STATE == 1 ) then
		realmChoice = SERVER_SPLIT_SERVER_ONE;
	else
		realmChoice = SERVER_SPLIT_SERVER_TWO;
	end
	return format(formatText, realmChoice);
end

function RealmSplit_SetChoiceText()
	RealmSplitCurrentChoice:SetText( RealmSplit_GetFormatedChoice(SERVER_SPLIT_CURRENT_CHOICE) );
	RealmSplitCurrentChoice:Show();
end

function CharacterSelect_PaidServiceOnClick(self, button, down, service)
	local index = self:GetID();
	if ( not index or index < 1 or index > CharacterSelect_GetNumCharacters() ) then
		return;
	end

	CharacterSelect_SelectCharacter(index, 1, 1);
	PAID_SERVICE_CHARACTER_ID = CharacterSelect_MapToNativeIndex(index);
	PAID_SERVICE_TYPE = service;
	PlaySound("gsCharacterSelectionCreateNew");
	SetGlueScreen("charcreate");
end

function CharacterSelect_Customize(self, button, down)
	CharacterSelect_PaidServiceOnClick(self, button, down, PAID_CHARACTER_CUSTOMIZATION);
end

function CharacterSelect_RaceChange(self, button, down)
	CharacterSelect_PaidServiceOnClick(self, button, down, PAID_RACE_CHANGE);
end

function CharacterSelect_FactionChange(self, button, down)
	CharacterSelect_PaidServiceOnClick(self, button, down, PAID_FACTION_CHANGE);
end

function CharacterSelect_DeathKnightSwap(self)
	if ( CharacterSelect.currentModel == "DEATHKNIGHT" ) then
		if (self.currentModel ~= "DEATHKNIGHT") then
			self.currentModel = "DEATHKNIGHT";
			self:SetNormalTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Up-Blue");
			self:SetPushedTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Down-Blue");
			self:SetHighlightTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Highlight-Blue");
		end
	else
		if (self.currentModel == "DEATHKNIGHT") then
			self.currentModel = nil;
			self:SetNormalTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Up");
			self:SetPushedTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Down");
			self:SetHighlightTexture("Interface\\Glues\\Common\\Glue-Panel-Button-Highlight");
		end
	end
end