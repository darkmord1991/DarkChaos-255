-- DarkChaos Item Upgrade Addon
-- Retail-like visual interface for item upgrading
-- Author: DarkChaos Development Team
-- Version: 1.0.0

local DarkChaos_ItemUpgrade = {};

-- Constants
local MAX_UPGRADE_LEVEL = 15;
local INVENTORY_SLOTS = {
    {bag = 0, slot = 0}, {bag = 0, slot = 1}, {bag = 0, slot = 2}, {bag = 0, slot = 3},
    {bag = 0, slot = 4}, {bag = 0, slot = 5}, {bag = 0, slot = 6}, {bag = 0, slot = 7},
    {bag = 0, slot = 8}, {bag = 0, slot = 9}, {bag = 0, slot = 10}, {bag = 0, slot = 11},
    {bag = 0, slot = 12}, {bag = 0, slot = 13}, {bag = 0, slot = 14}, {bag = 0, slot = 15},
    {bag = 0, slot = 16}, {bag = 0, slot = 17}, {bag = 0, slot = 18}, {bag = 0, slot = 19},
    {bag = 0, slot = 20}, {bag = 0, slot = 21}, {bag = 0, slot = 22}, {bag = 0, slot = 23},
    {bag = 1, slot = 0}, {bag = 1, slot = 1}, {bag = 1, slot = 2}, {bag = 1, slot = 3},
    {bag = 1, slot = 4}, {bag = 1, slot = 5}, {bag = 1, slot = 6}, {bag = 1, slot = 7},
    {bag = 1, slot = 8}, {bag = 1, slot = 9}, {bag = 1, slot = 10}, {bag = 1, slot = 11},
    {bag = 1, slot = 12}, {bag = 1, slot = 13}, {bag = 1, slot = 14}, {bag = 1, slot = 15},
    {bag = 2, slot = 0}, {bag = 2, slot = 1}, {bag = 2, slot = 2}, {bag = 2, slot = 3},
    {bag = 2, slot = 4}, {bag = 2, slot = 5}, {bag = 2, slot = 6}, {bag = 2, slot = 7},
    {bag = 2, slot = 8}, {bag = 2, slot = 9}, {bag = 2, slot = 10}, {bag = 2, slot = 11},
    {bag = 2, slot = 12}, {bag = 2, slot = 13}, {bag = 2, slot = 14}, {bag = 2, slot = 15},
    {bag = 3, slot = 0}, {bag = 3, slot = 1}, {bag = 3, slot = 2}, {bag = 3, slot = 3},
    {bag = 3, slot = 4}, {bag = 3, slot = 5}, {bag = 3, slot = 6}, {bag = 3, slot = 7},
    {bag = 3, slot = 8}, {bag = 3, slot = 9}, {bag = 3, slot = 10}, {bag = 3, slot = 11},
    {bag = 3, slot = 12}, {bag = 3, slot = 13}, {bag = 3, slot = 14}, {bag = 3, slot = 15},
    {bag = 4, slot = 0}, {bag = 4, slot = 1}, {bag = 4, slot = 2}, {bag = 4, slot = 3},
    {bag = 4, slot = 4}, {bag = 4, slot = 5}, {bag = 4, slot = 6}, {bag = 4, slot = 7},
    {bag = 4, slot = 8}, {bag = 4, slot = 9}, {bag = 4, slot = 10}, {bag = 4, slot = 11},
    {bag = 4, slot = 12}, {bag = 4, slot = 13}, {bag = 4, slot = 14}, {bag = 4, slot = 15}
};

-- Current state
local selectedItem = nil;
local currentItemStats = nil;
local targetUpgradeLevel = 0;
local mainFrame;

local scanTooltip = CreateFrame("GameTooltip", "DC_ItemUpgradeTooltip", UIParent, "GameTooltipTemplate");
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE");

-- Cached frame references (retail-inspired layout)
local frameHeaderItemButton;
local frameHeaderItemName;
local frameHeaderItemDetails;
local frameHeaderCurrentLevel;
local frameHeaderUpgradeDropdown;
local frameHeaderBrowseButton;

local frameCurrentPanelItemLevel;
local frameCurrentPanelUpgradeLevel;
local frameCurrentPanelStatsScroll;
local frameCurrentPanelStatsValue;

local frameUpgradedPanelItemLevel;
local frameUpgradedPanelUpgradeLevel;
local frameUpgradedPanelStatsScroll;
local frameUpgradedPanelStatsValue;
local frameUpgradedPanelDeltaValue;

local frameFooterTotalCostValue;
local frameFooterCostBreakdown;
local frameFooterStatusMessage;
local frameFooterUpgradeButton;
local frameFooterCancelButton;

local frameInventoryTitle;
local frameInventoryStatusText;

local function EnsureMainFrame()
    if not mainFrame then
        mainFrame = _G.DarkChaos_ItemUpgradeFrame;
    end;
    return mainFrame;
end;

local function ConfigureScrollFrame(scrollFrame)
    if not scrollFrame or scrollFrame._dcConfigured then
        return;
    end

    scrollFrame:EnableMouseWheel(true);
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scrollbar = _G[self:GetName() .. "ScrollBar"];
        if not scrollbar then
            return;
        end

        local current = scrollbar:GetValue() or 0;
        local step = (scrollbar.scrollStep or 20) * (delta > 0 and -1 or 1);
        scrollbar:SetValue(current + step);
    end);

    scrollFrame._dcConfigured = true;
end

local function RefreshScrollFrame(scrollFrame, textFontString)
    if not scrollFrame or not textFontString then
        return;
    end

    local padding = 4;
    textFontString._dcBaseWidth = textFontString._dcBaseWidth or textFontString:GetWidth() or 0;
    textFontString._dcBaseHeight = textFontString._dcBaseHeight or textFontString:GetHeight() or 0;

    local width = scrollFrame:GetWidth();
    if width and width > 0 then
        textFontString:SetWidth(width - padding);
    elseif textFontString._dcBaseWidth and textFontString._dcBaseWidth > 0 then
        textFontString:SetWidth(textFontString._dcBaseWidth - padding);
    end

    textFontString:SetHeight(0);
    local contentHeight = textFontString:GetStringHeight() or 0;
    local minHeight = scrollFrame:GetHeight();
    if not minHeight or minHeight <= 0 then
        minHeight = textFontString._dcBaseHeight or contentHeight;
    end
    if contentHeight < minHeight then
        contentHeight = minHeight;
    end
    textFontString:SetHeight(contentHeight + padding);

    if scrollFrame.UpdateScrollChildRect then
        scrollFrame:UpdateScrollChildRect();
    end

    local scrollbar = _G[scrollFrame:GetName() .. "ScrollBar"];
    if scrollbar then
        scrollbar:SetMinMaxValues(0, 0);
        local height = textFontString:GetHeight() or 0;
        local view = scrollFrame:GetHeight() or 0;
        local maxValue = math.max(0, height - view);
        local current = scrollbar:GetValue() or 0;
        scrollbar:SetMinMaxValues(0, maxValue);
        scrollbar:SetValue(math.min(current, maxValue));
    end
end

local function CacheFrameReferences()
    EnsureMainFrame();
    frameHeaderItemButton = _G.DarkChaos_ItemUpgradeFrameHeaderItemButton;
    frameHeaderItemName = _G.DarkChaos_ItemUpgradeFrameHeaderItemName;
    frameHeaderItemDetails = _G.DarkChaos_ItemUpgradeFrameHeaderItemDetails;
    frameHeaderCurrentLevel = _G.DarkChaos_ItemUpgradeFrameHeaderCurrentLevel;
    frameHeaderUpgradeDropdown = _G.DarkChaos_ItemUpgradeFrameHeaderUpgradeDropdown;
    frameHeaderBrowseButton = _G.DarkChaos_ItemUpgradeFrameHeaderBrowseButton;

    frameCurrentPanelItemLevel = _G.DarkChaos_ItemUpgradeFrameCurrentPanelItemLevel;
    frameCurrentPanelUpgradeLevel = _G.DarkChaos_ItemUpgradeFrameCurrentPanelUpgradeLevel;
    frameCurrentPanelStatsScroll = _G.DarkChaos_ItemUpgradeFrameCurrentPanelStatsScroll;
    frameCurrentPanelStatsValue = _G.DarkChaos_ItemUpgradeFrameCurrentPanelStatsValue;

    frameUpgradedPanelItemLevel = _G.DarkChaos_ItemUpgradeFrameUpgradedPanelItemLevel;
    frameUpgradedPanelUpgradeLevel = _G.DarkChaos_ItemUpgradeFrameUpgradedPanelUpgradeLevel;
    frameUpgradedPanelStatsScroll = _G.DarkChaos_ItemUpgradeFrameUpgradedPanelStatsScroll;
    frameUpgradedPanelStatsValue = _G.DarkChaos_ItemUpgradeFrameUpgradedPanelStatsValue;
    frameUpgradedPanelDeltaValue = _G.DarkChaos_ItemUpgradeFrameUpgradedPanelDeltaValue;

    frameFooterTotalCostValue = _G.DarkChaos_ItemUpgradeFrameFooterTotalCostValue;
    frameFooterCostBreakdown = _G.DarkChaos_ItemUpgradeFrameFooterCostBreakdown;
    frameFooterStatusMessage = _G.DarkChaos_ItemUpgradeFrameFooterStatusMessage;
    frameFooterUpgradeButton = _G.DarkChaos_ItemUpgradeFrameFooterUpgradeButton;
    frameFooterCancelButton = _G.DarkChaos_ItemUpgradeFrameFooterCancelButton;

    frameInventoryTitle = _G.DarkChaos_ItemUpgradeFrameInventoryFrameTitle;
    frameInventoryStatusText = _G.DarkChaos_ItemUpgradeFrameInventoryFrameStatusText;

    if frameHeaderUpgradeDropdown then
        UIDropDownMenu_SetWidth(frameHeaderUpgradeDropdown, 170);
    end

    ConfigureScrollFrame(frameCurrentPanelStatsScroll);
    ConfigureScrollFrame(frameUpgradedPanelStatsScroll);

    if frameCurrentPanelStatsValue then
        frameCurrentPanelStatsValue:SetSpacing(2);
    end
    if frameUpgradedPanelStatsValue then
        frameUpgradedPanelStatsValue:SetSpacing(2);
    end
    if frameUpgradedPanelDeltaValue then
        frameUpgradedPanelDeltaValue:SetSpacing(2);
    end
end;

local function IsItemLinkUpgradable(itemLink)
    if not itemLink then
        return false;
    end;

    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink);
    return equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG";
end

local function BuildLocalInventoryList()
    local items = {};

    if NUM_BAG_SLOTS and GetContainerNumSlots and GetContainerItemLink then
        for bag = 0, NUM_BAG_SLOTS do
            local numSlots = GetContainerNumSlots(bag);
            if numSlots then
                for slot = 1, numSlots do
                    local itemLink = GetContainerItemLink(bag, slot);
                    if itemLink and IsItemLinkUpgradable(itemLink) then
                        table.insert(items, {
                            itemGuid = string.format("bag%d-slot%d", bag, slot),
                            itemLink = itemLink,
                            bag = bag,
                            slot = slot
                        });
                    end;
                end
            end
        end
    end

    if INVSLOT_FIRST_EQUIPPED and INVSLOT_LAST_EQUIPPED and GetInventoryItemLink then
        for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
            local itemLink = GetInventoryItemLink("player", slot);
            if itemLink and IsItemLinkUpgradable(itemLink) then
                table.insert(items, {
                    itemGuid = string.format("equip-%d", slot),
                    itemLink = itemLink,
                    equipSlot = slot
                });
            end
        end
    end

    return items;
end

local function EnsureTargetLevelAtLeast(currentLevel)
    if targetUpgradeLevel < currentLevel then
        targetUpgradeLevel = currentLevel;
    end
end

local function RefreshUpgradeDropdown(currentLevel)
    if not frameHeaderUpgradeDropdown then
        return;
    end;

    EnsureTargetLevelAtLeast(currentLevel or 0);

    UIDropDownMenu_Initialize(frameHeaderUpgradeDropdown, function(self, level)
        if level ~= 1 then
            return;
        end

        local startLevel = currentLevel or 0;
        for upgradeLevel = startLevel, MAX_UPGRADE_LEVEL do
            local info = UIDropDownMenu_CreateInfo();
            info.text = (upgradeLevel == startLevel)
                and string.format("Current Level (%d)", upgradeLevel)
                or string.format("Upgrade to Level %d", upgradeLevel);
            info.value = upgradeLevel;
            info.arg1 = upgradeLevel;
            info.func = function(_, levelValue)
                DarkChaos_ItemUpgrade_SetTargetUpgradeLevel(levelValue);
            end;
            info.checked = (upgradeLevel == targetUpgradeLevel);
            info.disabled = (upgradeLevel == startLevel);
            UIDropDownMenu_AddButton(info, level);
        end
    end);

    if UIDropDownMenu_EnableDropDown then
        UIDropDownMenu_EnableDropDown(frameHeaderUpgradeDropdown);
    else
        frameHeaderUpgradeDropdown:Enable();
    end
    UIDropDownMenu_SetSelectedValue(frameHeaderUpgradeDropdown, targetUpgradeLevel);
    UIDropDownMenu_SetText(frameHeaderUpgradeDropdown, string.format("Target Level: %d / %d", targetUpgradeLevel, MAX_UPGRADE_LEVEL));
end

local function DisableUpgradeDropdown()
    if not frameHeaderUpgradeDropdown then
        return;
    end;

    UIDropDownMenu_SetText(frameHeaderUpgradeDropdown, "Target Level: --");
    if UIDropDownMenu_ClearAll then
        UIDropDownMenu_ClearAll(frameHeaderUpgradeDropdown);
    else
        UIDropDownMenu_SetSelectedValue(frameHeaderUpgradeDropdown, nil);
    end
    if UIDropDownMenu_DisableDropDown then
        UIDropDownMenu_DisableDropDown(frameHeaderUpgradeDropdown);
    else
        frameHeaderUpgradeDropdown:Disable();
    end
end

function DarkChaos_ItemUpgrade_SetTargetUpgradeLevel(levelValue)
    if not levelValue then
        return;
    end;

    targetUpgradeLevel = math.min(math.max(levelValue, 0), MAX_UPGRADE_LEVEL);
    DarkChaos_ItemUpgrade_UpdateUI();
end

-- Utility functions
local function FormatNumber(num)
    if not num then return "0" end;
    local formatted = tostring(num);
    local k = 0;
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2');
        if k == 0 then break end;
    end
    return formatted;
end

local function CalculateBonusPercent(level)
    if not level or level <= 0 then
        return 0;
    end
    return math.floor((level / 5) * 25 + 0.5);
end

local function GetItemStatsText(itemLink, upgradeLevel, isUpgraded, currentLevel)
    if not itemLink then return "No item selected" end;

    -- Parse item link to get basic info
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink);

    if not itemName then return "Loading item data..." end;

    -- Get item stats using tooltip scanning (simplified for demo)
    local tooltipLines = {};
    DarkChaos_ItemUpgrade.ScanTooltipForStats(itemLink, tooltipLines);

    local displayLines = {};

    if isUpgraded then
        for _, line in ipairs(tooltipLines) do
            if line ~= "" then
                table.insert(displayLines, "|cff00ff00" .. line .. "|r");
            end
        end

        if #displayLines == 0 then
            table.insert(displayLines, "|cff00ff00No stat lines available for preview.|r");
        end

        local baseLevel = currentLevel or 0;
        local targetLevel = upgradeLevel or baseLevel;
        local levelDelta = math.max(targetLevel - baseLevel, 0);

        table.insert(displayLines, "");
        if levelDelta > 0 then
            table.insert(displayLines, string.format("|cff00ff00Upgrade Levels: +%d|r", levelDelta));
            local basePercent = CalculateBonusPercent(baseLevel);
            local targetPercent = CalculateBonusPercent(targetLevel);
            local bonusDelta = targetPercent - basePercent;
            if bonusDelta > 0 then
                table.insert(displayLines, string.format("|cff00ff00Additional Stat Bonus: +%d%%%%|r", bonusDelta));
            end
            table.insert(displayLines, string.format("|cff00ff00Final Upgrade Level: %d / %d|r", targetLevel, MAX_UPGRADE_LEVEL));
        else
            table.insert(displayLines, "|cff00ff00Select a higher upgrade level to preview changes.|r");
        end

        return table.concat(displayLines, "\n");
    end

    for _, line in ipairs(tooltipLines) do
        if line ~= "" then
            table.insert(displayLines, line);
        end
    end

    if #displayLines == 0 then
        table.insert(displayLines, "No stat data available.");
    end

    table.insert(displayLines, "");
    -- Add upgrade level info
    if upgradeLevel and upgradeLevel > 0 then
        local bonusPercent = CalculateBonusPercent(upgradeLevel);
        table.insert(displayLines, string.format("Upgrade Level: %d / %d", upgradeLevel, MAX_UPGRADE_LEVEL));
        if bonusPercent > 0 then
            table.insert(displayLines, string.format("Stat Bonus: +%d%%%%", bonusPercent));
        end
    else
        table.insert(displayLines, string.format("Upgrade Level: 0 / %d", MAX_UPGRADE_LEVEL));
    end

    return table.concat(displayLines, "\n");
end

function DarkChaos_ItemUpgrade.ScanTooltipForStats(itemLink, outputTable)
    -- Create a temporary tooltip to scan item stats
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    scanTooltip:ClearLines();
    scanTooltip:SetHyperlink(itemLink);

    local foundStats = false;
    local skipPatterns = {
        "^Item Level",
        "^Requires Level",
        "^Classes:",
        "^Races:",
        "^Unique",
        "^Binds",
        "^Bind",
        "^Duration:",
        "^Cooldown:",
        "Sell Price:",
        "^%s*$",  -- Empty lines
    };
    
    -- Debug: Print total lines
    local numLines = scanTooltip:NumLines();
    --print("Scanning tooltip for " .. itemLink .. " - " .. numLines .. " lines");
    
    for i = 1, numLines do
        local leftLine = _G["DC_ItemUpgradeTooltipTextLeft" .. i];
        
        if leftLine then
            local text = leftLine:GetText();
            if text and text ~= "" then
                -- Check if we should skip this line
                local shouldSkip = false;
                for _, pattern in ipairs(skipPatterns) do
                    if string.find(text, pattern) then
                        shouldSkip = true;
                        break;
                    end
                end
                
                -- Skip the item name line (usually first line)
                if i == 1 then
                    shouldSkip = true;
                end
                
                -- Debug output
                --print("Line " .. i .. ": " .. text .. (shouldSkip and " [SKIP]" or " [KEEP]"));
                
                if not shouldSkip then
                    table.insert(outputTable, text);
                    foundStats = true;
                end
            end
        end
    end
    
    if not foundStats then
        table.insert(outputTable, "(No stats to display)");
    end

    scanTooltip:Hide();
end

-- Main UI functions
function DarkChaos_ItemUpgrade_OnLoad(frame)
    mainFrame = frame or EnsureMainFrame();
    CacheFrameReferences();

    -- Apply custom textures if available
    DarkChaos_ItemUpgrade_ApplyCustomTextures();

    -- Register slash commands
    SLASH_DCUPGRADE1 = "/dcupgrade";
    SLASH_DCUPGRADE2 = "/itemupgrade";
    SlashCmdList["DCUPGRADE"] = function(msg)
        DarkChaos_ItemUpgrade_ShowFrame();
    end;

    -- Register events
    if frame then
        frame:RegisterEvent("PLAYER_ENTERING_WORLD");
        frame:RegisterEvent("BAG_UPDATE");
        frame:RegisterEvent("UNIT_INVENTORY_CHANGED");
        frame:RegisterEvent("CHAT_MSG_GUILD");  -- Listen for server responses
        frame:RegisterEvent("CHAT_MSG_OFFICER");
        frame:RegisterEvent("CHAT_MSG_WHISPER");
        frame:SetScript("OnEvent", DarkChaos_ItemUpgrade_OnEvent);
        frame:RegisterForDrag("LeftButton");
        frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
    end;

    -- Make frame movable

    -- Initialize UI
    DarkChaos_ItemUpgrade_UpdateUI();
    
    -- Request initial currency balance from server
    SendChatMessage(".dcupgrade init", "GUILD");
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd700DC-ItemUpgrade addon loaded! Use /dcupgrade to open.|r");
end

-- Custom texture support function
function DarkChaos_ItemUpgrade_ApplyCustomTextures()
    -- Button Glow (optional - for upgrade button glow effect)
    local upgradeButton = _G.DarkChaos_ItemUpgradeFrameUpgradeButton;
    local buttonGlow = _G.DarkChaos_ItemUpgradeFrameUpgradeButtonGlow;
    if buttonGlow then
        -- Try to load custom button glow texture
        -- Example path: Interface\AddOns\DC-ItemUpgrade\Textures\itemupgrade_fx_buttonglow
        local glowTexture = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\itemupgrade_fx_buttonglow";
        if buttonGlow.SetTexture then
            local success = pcall(function()
                buttonGlow:SetTexture(glowTexture);
                buttonGlow:SetBlendMode("ADD");
                buttonGlow:SetAlpha(0.7);
            end);
            if not success then
                -- Texture doesn't exist yet, hide the glow
                buttonGlow:Hide();
            end
        end
    end
    
    -- Cost Frame Background (optional)
    local costFrameBG = _G.DarkChaos_ItemUpgradeFrameCostFrameBG;
    if costFrameBG then
        local bgTexture = "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\ItemUpgrade_TotalCostBar";
        local success = pcall(function()
            costFrameBG:SetTexture(bgTexture);
        end);
        if not success then
            costFrameBG:Hide();
        end
    end
    
    -- You can add more texture paths here when you download the retail textures:
    -- "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\ItemUpgrade_BottomPanel"
    -- "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\ItemUpgrade_TopPanel"
    -- "Interface\\AddOns\\DC-ItemUpgrade\\Textures\\itemupgrade_slotborder"
    -- etc.
end

function DarkChaos_ItemUpgrade_OnHide(frame)
    -- Hide inventory frame when main frame is hidden
    local inventoryFrame = _G.DarkChaos_ItemUpgradeFrameInventoryFrame;
    if inventoryFrame then
        inventoryFrame:Hide();
    end;
end

function DarkChaos_ItemUpgrade_ShowFrame()
    local frame = EnsureMainFrame();
    if not frame then return end;
    frame:Show();
    DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_UpdateUI()
    if not frameHeaderItemName then
        CacheFrameReferences();
    end;

    local frame = EnsureMainFrame();
    if not frame then
        return;
    end;

    if not selectedItem then
        -- Reset header
        if frameHeaderItemName then
            frameHeaderItemName:SetText("Item Upgrade");
            frameHeaderItemName:SetTextColor(1, 1, 1);
        end
        if frameHeaderItemDetails then
            frameHeaderItemDetails:SetText("Drop an item here or browse your bags.");
        end
        if frameHeaderCurrentLevel then
            frameHeaderCurrentLevel:SetText(string.format("Upgrade Level: 0 / %d", MAX_UPGRADE_LEVEL));
        end
        if frameHeaderItemButton then
            frameHeaderItemButton.itemLink = nil;
            SetItemButtonTexture(frameHeaderItemButton, nil);
        end
        DisableUpgradeDropdown();

        -- Reset current panel
        if frameCurrentPanelItemLevel then
            frameCurrentPanelItemLevel:SetText("");
        end
        if frameCurrentPanelUpgradeLevel then
            frameCurrentPanelUpgradeLevel:SetText(string.format("Upgrade Level: 0 / %d", MAX_UPGRADE_LEVEL));
        end
        if frameCurrentPanelStatsValue then
            frameCurrentPanelStatsValue:SetText("Select an item to view its current stats.");
            RefreshScrollFrame(frameCurrentPanelStatsScroll, frameCurrentPanelStatsValue);
        end

        -- Reset upgraded panel
        if frameUpgradedPanelItemLevel then
            frameUpgradedPanelItemLevel:SetText("");
        end
        if frameUpgradedPanelUpgradeLevel then
            frameUpgradedPanelUpgradeLevel:SetText(string.format("Upgrade Level: 0 / %d", MAX_UPGRADE_LEVEL));
        end
        if frameUpgradedPanelStatsValue then
            frameUpgradedPanelStatsValue:SetText("");
            RefreshScrollFrame(frameUpgradedPanelStatsScroll, frameUpgradedPanelStatsValue);
        end
        if frameUpgradedPanelDeltaValue then
            frameUpgradedPanelDeltaValue:SetText("No changes");
        end

        -- Reset footer
        if frameFooterTotalCostValue then
            frameFooterTotalCostValue:SetText("0");
        end
        if frameFooterCostBreakdown then
            frameFooterCostBreakdown:SetText("Essence: 0  Tokens: 0");
        end
        if frameFooterStatusMessage then
            frameFooterStatusMessage:SetText("Choose an item to begin upgrading.");
        end
        if frameFooterUpgradeButton then
            frameFooterUpgradeButton:Disable();
        end

        return;
    end

    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, _, itemEquipLoc = GetItemInfo(selectedItem.itemLink);
    if not itemName then
        if frameHeaderItemName then
            frameHeaderItemName:SetText("Loading item data...");
            frameHeaderItemName:SetTextColor(1, 1, 1);
        end
        if frameFooterStatusMessage then
            frameFooterStatusMessage:SetText("Fetching item information...");
        end
        return;
    end

    local r, g, b = GetItemQualityColor(itemRarity or 1);
    local baseItemLevel = DarkChaos_ItemUpgrade_GetItemLevel(selectedItem.itemLink);
    local currentLevel = (currentItemStats and currentItemStats.upgradeLevel) or 0;
    EnsureTargetLevelAtLeast(currentLevel);

    -- Header state
    if frameHeaderItemName then
        frameHeaderItemName:SetText(itemName);
        frameHeaderItemName:SetTextColor(r, g, b);
    end
    if frameHeaderItemDetails then
        local equipText = itemEquipLoc and _G[itemEquipLoc] or itemType or "";
        local typeText = itemSubType or itemType or "";
        if equipText ~= "" and typeText ~= "" then
            frameHeaderItemDetails:SetText(equipText .. " • " .. typeText);
        else
            frameHeaderItemDetails:SetText(typeText ~= "" and typeText or equipText);
        end
    end
    if frameHeaderCurrentLevel then
        frameHeaderCurrentLevel:SetText(string.format("Upgrade Level: %d / %d", currentLevel, MAX_UPGRADE_LEVEL));
    end
    if frameHeaderItemButton then
        frameHeaderItemButton.itemLink = selectedItem.itemLink;
        SetItemButtonTexture(frameHeaderItemButton, GetItemIcon(selectedItem.itemLink));
        if frameHeaderItemButton.SetNormalTexture then
            frameHeaderItemButton:SetNormalTexture(nil);
        end
        if frameHeaderItemButton.SetPushedTexture then
            frameHeaderItemButton:SetPushedTexture(nil);
        end
        if frameHeaderItemButton.SetHighlightTexture then
            frameHeaderItemButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD");
        end
    end

    RefreshUpgradeDropdown(currentLevel);

    -- Left panel (current stats)
    local currentItemLevel = baseItemLevel + math.floor(currentLevel * 1.5);
    if frameCurrentPanelItemLevel then
        frameCurrentPanelItemLevel:SetText("Item Level " .. currentItemLevel);
        frameCurrentPanelItemLevel:SetTextColor(r, g, b);
    end
    if frameCurrentPanelUpgradeLevel then
        frameCurrentPanelUpgradeLevel:SetText(string.format("Upgrade Level: %d / %d", currentLevel, MAX_UPGRADE_LEVEL));
        frameCurrentPanelUpgradeLevel:SetTextColor(1.0, 0.82, 0);
    end
    if frameCurrentPanelStatsValue then
        frameCurrentPanelStatsValue:SetText(GetItemStatsText(selectedItem.itemLink, currentLevel, false, currentLevel));
        RefreshScrollFrame(frameCurrentPanelStatsScroll, frameCurrentPanelStatsValue);
    end

    -- Right panel (preview)
    local targetItemLevel = baseItemLevel + math.floor(targetUpgradeLevel * 1.5);
    if frameUpgradedPanelItemLevel then
        frameUpgradedPanelItemLevel:SetText("Item Level " .. targetItemLevel);
        -- Use green for upgraded item level
        frameUpgradedPanelItemLevel:SetTextColor(0.0, 1.0, 0.0);
    end
    if frameUpgradedPanelUpgradeLevel then
        frameUpgradedPanelUpgradeLevel:SetText(string.format("Upgrade Level: %d / %d", targetUpgradeLevel, MAX_UPGRADE_LEVEL));
        -- Use green for upgraded level
        frameUpgradedPanelUpgradeLevel:SetTextColor(0.0, 1.0, 0.0);
    end
    if frameUpgradedPanelStatsValue then
        if targetUpgradeLevel > currentLevel then
            frameUpgradedPanelStatsValue:SetText(GetItemStatsText(selectedItem.itemLink, targetUpgradeLevel, true, currentLevel));
        else
            frameUpgradedPanelStatsValue:SetText("Select a higher upgrade to preview changes.");
        end
        RefreshScrollFrame(frameUpgradedPanelStatsScroll, frameUpgradedPanelStatsValue);
    end

    DarkChaos_ItemUpgrade_UpdateCosts();
    DarkChaos_ItemUpgrade_UpdateStatChanges();

    if frameFooterUpgradeButton then
        if targetUpgradeLevel > currentLevel then
            frameFooterUpgradeButton:Enable();
            if frameFooterStatusMessage then
                frameFooterStatusMessage:SetText("Ready to upgrade.");
            end
        else
            frameFooterUpgradeButton:Disable();
            if frameFooterStatusMessage then
                if currentLevel >= MAX_UPGRADE_LEVEL then
                    frameFooterStatusMessage:SetText("Item is already at maximum upgrade.");
                else
                    frameFooterStatusMessage:SetText("Select a higher upgrade level to enable the upgrade.");
                end
            end
        end
    end
end

function DarkChaos_ItemUpgrade_GetItemLevel(itemLink)
    local itemName, itemLink, itemRarity, itemLevel = GetItemInfo(itemLink);
    return itemLevel or 1;
end

function DarkChaos_ItemUpgrade_UpdateCosts()
    if not frameFooterTotalCostValue then
        CacheFrameReferences();
    end;

    if not selectedItem or not currentItemStats then
        if frameFooterTotalCostValue then
            frameFooterTotalCostValue:SetText("0");
        end
        if frameFooterCostBreakdown then
            frameFooterCostBreakdown:SetText("Essence: 0  Tokens: 0");
        end
        return;
    end

    local currentLevel = currentItemStats.upgradeLevel or 0;
    local levelsToUpgrade = math.max(targetUpgradeLevel - currentLevel, 0);

    if levelsToUpgrade <= 0 then
        if frameFooterTotalCostValue then
            frameFooterTotalCostValue:SetText("0");
        end
        if frameFooterCostBreakdown then
            frameFooterCostBreakdown:SetText("Essence: 0  Tokens: 0");
        end
        return;
    end

    local totalEssence = 0;
    local totalTokens = 0;

    for level = currentLevel + 1, targetUpgradeLevel do
        local isArtifact = (currentItemStats.tierId == 5);
        if isArtifact then
            totalEssence = totalEssence + (level * 50);
        else
            totalTokens = totalTokens + (level * 25);
        end
    end

    if frameFooterTotalCostValue then
        local headlineCost = totalEssence > 0 and totalEssence or totalTokens;
        local currencyLabel = (totalEssence > 0) and "Essence" or "Tokens";
        -- Use gold color for cost like retail
        frameFooterTotalCostValue:SetText(string.format("|cffffd700%s %s|r", FormatNumber(headlineCost), currencyLabel));
    end

    if frameFooterCostBreakdown then
        -- More subtle color for breakdown
        frameFooterCostBreakdown:SetText(string.format("|cffaaaaaa%d Essence  %d Tokens|r", totalEssence, totalTokens));
    end
end

function DarkChaos_ItemUpgrade_UpdateStatChanges()
    if not frameUpgradedPanelDeltaValue then
        CacheFrameReferences();
    end;

    if not selectedItem or not currentItemStats then
        if frameUpgradedPanelDeltaValue then
            frameUpgradedPanelDeltaValue:SetText("No changes");
        end
        return;
    end

    local currentLevel = currentItemStats.upgradeLevel or 0;
    local levelsToUpgrade = targetUpgradeLevel - currentLevel;

    if levelsToUpgrade <= 0 then
        if frameUpgradedPanelDeltaValue then
            frameUpgradedPanelDeltaValue:SetText("No changes");
        end
        return;
    end

    local lines = {};
    local bonusPercent = math.floor((levelsToUpgrade / 5) * 25 + 0.5);
    if bonusPercent > 0 then
        table.insert(lines, string.format("|cff00ff00+%d%% stats|r", bonusPercent));
    end

    local levelIncrease = math.floor(levelsToUpgrade * 1.5);
    if levelIncrease > 0 then
        table.insert(lines, string.format("|cff00ff00+%d item levels|r", levelIncrease));
    end

    if frameUpgradedPanelDeltaValue then
        if #lines == 0 then
            frameUpgradedPanelDeltaValue:SetText("No changes");
        else
            frameUpgradedPanelDeltaValue:SetText(table.concat(lines, "\n"));
        end
    end
end

-- Item slot interactions
function DarkChaos_ItemUpgrade_OnItemSlotClick()
    DarkChaos_ItemUpgrade_ShowInventoryFrame();
end

function DarkChaos_ItemUpgrade_OnItemSlotReceiveDrag()
    local infoType, itemId, itemLink = GetCursorInfo();
    if infoType == "item" and itemLink then
        -- Generate a mock itemGuid for the dragged item (in real implementation, this would come from server)
        local itemGuid = "mock_guid_" .. itemId .. "_" .. GetTime(); -- Mock GUID for testing
        DarkChaos_ItemUpgrade_SelectItemByGuid(itemGuid, itemLink);
        ClearCursor();
    end
end

function DarkChaos_ItemUpgrade_SelectItem(itemLink)
    if not itemLink then return end;

    -- Generate a mock itemGuid for the selected item
    local itemName, itemLinkFull, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(itemLink);
    local itemGuid = "mock_guid_" .. (itemSellPrice or 0) .. "_" .. GetTime(); -- Mock GUID for testing

    DarkChaos_ItemUpgrade_SelectItemByGuid(itemGuid, itemLink);
end

function DarkChaos_ItemUpgrade_GetItemUpgradeStats(itemLink)
    -- Send request to server for item upgrade stats
    if not itemLink then return nil end;

    -- Extract item GUID from item link (simplified - would need proper parsing)
    -- For now, return mock data until server communication is implemented
    return {
        upgradeLevel = 0,
        tierId = 1,
        essenceInvested = 0,
        tokensInvested = 0,
        statMultiplier = 1.0,
        baseItemLevel = DarkChaos_ItemUpgrade_GetItemLevel(itemLink),
        upgradedItemLevel = DarkChaos_ItemUpgrade_GetItemLevel(itemLink)
    };
end

-- Server Communication Functions
local SERVER_OPCODES = {
    CMSG_ITEM_UPGRADE_REQUEST_INFO = 1001,
    SMSG_ITEM_UPGRADE_INFO_RESPONSE = 1002,
    CMSG_ITEM_UPGRADE_PERFORM = 1003,
    SMSG_ITEM_UPGRADE_RESULT = 1004,
    CMSG_ITEM_UPGRADE_INVENTORY_SCAN = 1005,
    SMSG_ITEM_UPGRADE_INVENTORY_LIST = 1006,
    SMSG_ITEM_UPGRADE_OPEN_INTERFACE = 1007, -- New opcode to open interface from server
};

function DarkChaos_ItemUpgrade_SendPacket(opcode, data)
    -- This would send a packet to the server
    -- For now, we'll simulate responses
    if opcode == SERVER_OPCODES.CMSG_ITEM_UPGRADE_REQUEST_INFO then
        -- Simulate server response
        DarkChaos_ItemUpgrade_HandleInfoResponse(data);
    elseif opcode == SERVER_OPCODES.CMSG_ITEM_UPGRADE_PERFORM then
        -- Simulate upgrade
        DarkChaos_ItemUpgrade_HandleUpgradeResponse(data);
    elseif opcode == SERVER_OPCODES.CMSG_ITEM_UPGRADE_INVENTORY_SCAN then
        -- Simulate inventory scan (fallback to local bag scan)
        local response = data or {};
        if not response.items or #response.items == 0 then
            response.items = BuildLocalInventoryList();
        end
        DarkChaos_ItemUpgrade_HandleInventoryResponse(response);
    end
end

function DarkChaos_ItemUpgrade_HandleServerPacket(opcode, data)
    -- Handle packets received from server
    if opcode == SERVER_OPCODES.SMSG_ITEM_UPGRADE_OPEN_INTERFACE then
        -- Server is instructing us to open the interface
        DarkChaos_ItemUpgrade_ShowFrame();
    elseif opcode == SERVER_OPCODES.SMSG_ITEM_UPGRADE_INFO_RESPONSE then
        DarkChaos_ItemUpgrade_HandleInfoResponse(data);
    elseif opcode == SERVER_OPCODES.SMSG_ITEM_UPGRADE_RESULT then
        DarkChaos_ItemUpgrade_HandleUpgradeResponse(data);
    elseif opcode == SERVER_OPCODES.SMSG_ITEM_UPGRADE_INVENTORY_LIST then
        DarkChaos_ItemUpgrade_HandleInventoryResponse(data);
    end
end

function DarkChaos_ItemUpgrade_HandleInfoResponse(data)
    -- Handle server response with item upgrade info
    -- Update currentItemStats with server data
    if data and selectedItem then
        currentItemStats = {
            upgradeLevel = data.upgradeLevel or 0,
            tierId = data.tierId or 1,
            essenceInvested = data.essenceInvested or 0,
            tokensInvested = data.tokensInvested or 0,
            statMultiplier = data.statMultiplier or 1.0,
            baseItemLevel = data.baseItemLevel or 1,
            upgradedItemLevel = data.upgradedItemLevel or 1
        };
        targetUpgradeLevel = math.max(targetUpgradeLevel, currentItemStats.upgradeLevel or 0);
        DarkChaos_ItemUpgrade_UpdateUI();
    end
end

function DarkChaos_ItemUpgrade_HandleUpgradeResponse(data)
    -- Handle upgrade result from server
    if data.success then
        DEFAULT_CHAT_FRAME:AddMessage("Item upgraded successfully!", 0, 1, 0);
        -- Update local stats
        if currentItemStats then
            currentItemStats.upgradeLevel = data.newLevel;
            currentItemStats.essenceInvested = currentItemStats.essenceInvested + (data.essenceCost or 0);
            currentItemStats.tokensInvested = currentItemStats.tokensInvested + (data.tokenCost or 0);
        end
        targetUpgradeLevel = data.newLevel or targetUpgradeLevel;
        DarkChaos_ItemUpgrade_UpdateUI();
    else
        DEFAULT_CHAT_FRAME:AddMessage("Upgrade failed: " .. (data.error or "Unknown error"), 1, 0, 0);
    end
end

function DarkChaos_ItemUpgrade_HandleInventoryResponse(data)
    -- Handle inventory scan response
    -- This would populate the inventory frame with upgradable items
    local items = data and data.items or nil;
    if not items or #items == 0 then
        items = BuildLocalInventoryList();
    end

    DarkChaos_ItemUpgrade_PopulateInventoryFrame(items or {});
end

function DarkChaos_ItemUpgrade_PopulateInventoryFrame(items)
    -- Clear existing buttons
    for i = 1, 100 do
        local button = getglobal("DC_ItemUpgrade_InvButton" .. i);
        if button then button:Hide(); end
    end

    local hasItems = items and #items > 0;

    if frameInventoryTitle then
        frameInventoryTitle:SetText("Select Item to Upgrade");
    end

    if frameInventoryStatusText then
        if hasItems then
            frameInventoryStatusText:SetText("Click an item to preview its upgrades.");
        else
            frameInventoryStatusText:SetText("No eligible items found. Drag an item into the upgrade slot.");
        end
    end

    -- Create buttons for each upgradable item
    if hasItems then
        for index, itemData in ipairs(items) do
            if index > 100 then
                break;
            end
            local button = DarkChaos_ItemUpgrade_CreateInventoryButton(index, itemData.bag, itemData.slot, itemData.itemLink, itemData.itemGuid, itemData.equipSlot);
            if button then
                button:Show();
            end
        end
    end
end

function DarkChaos_ItemUpgrade_SelectItemByGuid(itemGuid, itemLink, bag, slot, equipSlot)
    selectedItem = {
        itemGuid = itemGuid,
        itemLink = itemLink,
        bag = bag,
        slot = slot,
        equipSlot = equipSlot
    };

    -- Request upgrade info from server
    if bag and slot then
        local command = string.format(".dcupgrade query %d %d", bag, slot);
        SendChatMessage(command, "GUILD");
    end

    -- For now, set default stats until server responds
    currentItemStats = {
        upgradeLevel = 0,
        tierId = 1,
        essenceInvested = 0,
        tokensInvested = 0,
        statMultiplier = 1.0,
        baseItemLevel = DarkChaos_ItemUpgrade_GetItemLevel(itemLink),
        upgradedItemLevel = DarkChaos_ItemUpgrade_GetItemLevel(itemLink)
    };

    targetUpgradeLevel = 0;
    DarkChaos_ItemUpgrade_UpdateUI();
end

-- Inventory frame functions
function DarkChaos_ItemUpgrade_ShowInventoryFrame()
    local inventoryFrame = DarkChaos_ItemUpgradeFrameInventoryFrame;
    if not inventoryFrame then return end;

    inventoryFrame:Show();

    if frameInventoryTitle then
        frameInventoryTitle:SetText("Browse Items");
    end
    if frameInventoryStatusText then
        frameInventoryStatusText:SetText("Scanning your bags for upgradable items...");
    end

    -- Populate immediately with a local scan so players can click items without dragging
    local localItems = BuildLocalInventoryList() or {};
    DarkChaos_ItemUpgrade_PopulateInventoryFrame(localItems);

    -- Request upgradable items from server (will overwrite the local list when data arrives)
    DarkChaos_ItemUpgrade_SendPacket(SERVER_OPCODES.CMSG_ITEM_UPGRADE_INVENTORY_SCAN, {});
end

function DarkChaos_ItemUpgrade_CreateInventoryButton(index, bag, slot, itemLink, itemGuid, equipSlot)
    local buttonName = "DC_ItemUpgrade_InvButton" .. index;
    local button = getglobal(buttonName);

    if not button then
        button = CreateFrame("Button", buttonName, DarkChaos_ItemUpgradeFrameInventoryFrame, "ItemButtonTemplate");
        button:SetScript("OnClick", function(self)
            if not self.itemLink then
                return;
            end

            local guid = self.itemGuid or self.itemLink;
            DarkChaos_ItemUpgrade_SelectItemByGuid(guid, self.itemLink, self.itemBag, self.itemSlot, self.equipSlot);
            DarkChaos_ItemUpgradeFrameInventoryFrame:Hide();
        end);
        button:SetScript("OnEnter", function(self)
            if not self.itemLink then
                return;
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetHyperlink(self.itemLink);
            GameTooltip:Show();
        end);
        button:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
    end

    button.itemLink = itemLink;
    button.itemGuid = itemGuid;
    button.itemBag = bag;
    button.itemSlot = slot;
    button.equipSlot = equipSlot;

    -- Position button
    local buttonsPerRow = 8;
    local buttonSize = 36;
    local spacing = 4;
    local row = math.floor((index - 1) / buttonsPerRow);
    local col = (index - 1) % buttonsPerRow;

    button:SetPoint("TOPLEFT", DarkChaos_ItemUpgradeFrameInventoryFrame, "TOPLEFT",
                   20 + col * (buttonSize + spacing),
                   -40 - row * (buttonSize + spacing));
    button:SetWidth(buttonSize);
    button:SetHeight(buttonSize);

    -- Set item texture
    local texture;
    if bag and slot then
        texture = GetContainerItemInfo(bag, slot);
        if type(texture) == "table" then
            texture = texture.icon;
        end
    elseif equipSlot then
        texture = GetInventoryItemTexture("player", equipSlot);
    end

    if not texture and itemLink then
        texture = GetItemIcon(itemLink);
    end
    SetItemButtonTexture(button, texture);

    return button;
end

-- Dropdown interaction
function DarkChaos_ItemUpgrade_OnUpgradeDropdownOpened()
    if not frameHeaderUpgradeDropdown or not selectedItem or not currentItemStats then
        return;
    end

    RefreshUpgradeDropdown(currentItemStats.upgradeLevel or 0);
end

-- Backwards compatibility for legacy slider-based scripts/tests
function DarkChaos_ItemUpgrade_OnSliderValueChanged(_, value)
    DarkChaos_ItemUpgrade_SetTargetUpgradeLevel(value);
end

-- Upgrade button
function DarkChaos_ItemUpgrade_OnUpgradeClick()
    if not selectedItem or not currentItemStats then return end;

    local currentLevel = currentItemStats.upgradeLevel or 0;
    local levelsToUpgrade = targetUpgradeLevel - currentLevel;

    if levelsToUpgrade <= 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No upgrade levels selected.|r", 1, 0, 0);
        return;
    end

    -- Send upgrade request to server via chat command
    -- Format: .dcupgrade perform <bag> <slot> <target_level>
    if selectedItem.bag and selectedItem.slot then
        local command = string.format(".dcupgrade perform %d %d %d", 
            selectedItem.bag, selectedItem.slot, targetUpgradeLevel);
        SendChatMessage(command, "GUILD");  -- Using GUILD channel as hidden command channel
        
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Sending upgrade request to server...|r");
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Error: Item location unknown. Please re-select the item.|r");
    end
end

-- Server communication event handler
function DarkChaos_ItemUpgrade_OnChatMessage(event, message, sender)
    -- Check if message is from server (system message or from self)
    if not string.match(message, "^DCUPGRADE_") then
        return false;
    end
    
    -- Parse server response
    local parts = {};
    for part in string.gmatch(message, "[^:]+") do
        table.insert(parts, part);
    end
    
    local msgType = parts[1];
    
    if msgType == "DCUPGRADE_INIT" then
        -- Received initial currency balance
        local tokens = tonumber(parts[2]) or 0;
        local essence = tonumber(parts[3]) or 0;
        
        -- Update UI to show player's currencies
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffd700You have %d Upgrade Tokens and %d Artifact Essence|r", 
            tokens, essence));
        
    elseif msgType == "DCUPGRADE_QUERY" then
        -- Received item upgrade info
        local itemGUID = tonumber(parts[2]);
        local upgradeLevel = tonumber(parts[3]) or 0;
        local tier = tonumber(parts[4]) or 1;
        local baseIlvl = tonumber(parts[5]) or 0;
        
        -- Update current item stats if this matches our selected item
        if selectedItem and selectedItem.itemGuid == itemGUID then
            if not currentItemStats then
                currentItemStats = {};
            end
            currentItemStats.upgradeLevel = upgradeLevel;
            currentItemStats.tier = tier;
            currentItemStats.baseItemLevel = baseIlvl;
            
            -- Refresh UI
            DarkChaos_ItemUpgrade_UpdateUI();
        end
        
    elseif msgType == "DCUPGRADE_SUCCESS" then
        -- Upgrade successful!
        local itemGUID = tonumber(parts[2]);
        local newLevel = tonumber(parts[3]);
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00Item upgraded to level %d!|r", newLevel));
        
        -- Refresh the item display
        if selectedItem then
            -- Query updated stats from server
            local command = string.format(".dcupgrade query %d %d", 
                selectedItem.bag or 0, selectedItem.slot or 0);
            SendChatMessage(command, "GUILD");
        end
        
        -- Refresh UI
        DarkChaos_ItemUpgrade_UpdateUI();
        
    elseif msgType == "DCUPGRADE_ERROR" then
        -- Error from server
        local errorMsg = parts[2] or "Unknown error";
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Upgrade Error: " .. errorMsg .. "|r");
    end
    
    return false;  -- Don't block the message
end

-- Event handlers
function DarkChaos_ItemUpgrade_OnEvent(self, event, arg1, arg2)
    if event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" then
        -- Refresh inventory display if inventory frame is shown
        if DarkChaos_ItemUpgradeFrameInventoryFrame and DarkChaos_ItemUpgradeFrameInventoryFrame:IsShown() then
            DarkChaos_ItemUpgrade_ShowInventoryFrame();
        end
    elseif event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_OFFICER" or event == "CHAT_MSG_WHISPER" then
        -- Check for server responses
        DarkChaos_ItemUpgrade_OnChatMessage(event, arg1, arg2);
    end
end

-- Expose addon table globally for testing and external access
_G.DarkChaos_ItemUpgrade = DarkChaos_ItemUpgrade;
