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

local function GetItemStatsText(itemLink, upgradeLevel, isUpgraded)
    if not itemLink then return "No item selected" end;

    -- Parse item link to get basic info
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemLink);

    if not itemName then return "Loading item data..." end;

    local statsText = "";

    -- Get item stats using tooltip scanning (simplified for demo)
    local tooltipLines = {};
    DarkChaos_ItemUpgrade.ScanTooltipForStats(itemLink, tooltipLines);

    for _, line in ipairs(tooltipLines) do
        if line ~= "" then
            statsText = statsText .. line .. "\n";
        end
    end

    -- Add upgrade level info
    if upgradeLevel and upgradeLevel > 0 then
        local bonusPercent = math.floor((upgradeLevel / 5) * 25 + 0.5); -- Simplified calculation
        statsText = statsText .. "\n|cff00ff00Upgrade Level: " .. upgradeLevel .. "/15|r";
        if bonusPercent > 0 then
            statsText = statsText .. "\n|cff00ff00Stat Bonus: +" .. bonusPercent .. "%|r";
        end
    end

    return statsText;
end

function DarkChaos_ItemUpgrade.ScanTooltipForStats(itemLink, outputTable)
    -- Create a temporary tooltip to scan item stats
    local tooltip = CreateFrame("GameTooltip", "DC_ItemUpgradeTooltip", UIParent, "GameTooltipTemplate");
    tooltip:SetOwner(UIParent, "ANCHOR_NONE");
    tooltip:SetHyperlink(itemLink);

    for i = 1, tooltip:NumLines() do
        local line = getglobal(tooltip:GetName() .. "TextLeft" .. i);
        if line then
            local text = line:GetText();
            if text and text ~= "" then
                -- Filter out unwanted lines
                if not string.find(text, "Item Level") and
                   not string.find(text, "Requires Level") and
                   not string.find(text, "Unique") and
                   not string.find(text, "Soulbound") then
                    table.insert(outputTable, text);
                end
            end
        end
    end

    tooltip:Hide();
end

-- Main UI functions
function DarkChaos_ItemUpgrade_OnLoad()
    -- Register events
    DarkChaos_ItemUpgradeFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
    DarkChaos_ItemUpgradeFrame:RegisterEvent("BAG_UPDATE");
    DarkChaos_ItemUpgradeFrame:RegisterEvent("UNIT_INVENTORY_CHANGED");

    -- Make frame movable
    DarkChaos_ItemUpgradeFrame:RegisterForDrag("LeftButton");
    DarkChaos_ItemUpgradeFrame:SetScript("OnDragStart", function() this:StartMoving() end);
    DarkChaos_ItemUpgradeFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end);

    -- Initialize UI
    DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_OnHide()
    -- Hide inventory frame when main frame is hidden
    DarkChaos_ItemUpgradeFrameInventoryFrame:Hide();
end

function DarkChaos_ItemUpgrade_ShowFrame()
    DarkChaos_ItemUpgradeFrame:Show();
    DarkChaos_ItemUpgrade_UpdateUI();
end

function DarkChaos_ItemUpgrade_UpdateUI()
    local frame = DarkChaos_ItemUpgradeFrame;

    if selectedItem then
        -- Update item display
        local itemName, itemLink, itemRarity = GetItemInfo(selectedItem.itemLink);
        if itemName then
            frameItemName:SetText(itemName);
            frameItemName:SetTextColor(GetItemQualityColor(itemRarity));
            SetItemButtonTexture(frameItemSlot, GetItemIcon(selectedItem.itemLink));
            frameItemSlot.itemLink = selectedItem.itemLink;
        end

        -- Update item level
        local baseItemLevel = DarkChaos_ItemUpgrade_GetItemLevel(selectedItem.itemLink);
        local currentItemLevel = baseItemLevel;
        if currentItemStats and currentItemStats.upgradeLevel > 0 then
            currentItemLevel = baseItemLevel + math.floor(currentItemStats.upgradeLevel * 1.5); -- Simplified calculation
        end
        frameItemLevel:SetText("Item Level " .. currentItemLevel);

        -- Update current upgrade level
        local currentLevel = (currentItemStats and currentItemStats.upgradeLevel) or 0;
        frameCurrentLevelValue:SetText(currentLevel .. "/15");

        -- Update slider
        frameUpgradeSlider:SetMinMaxValues(currentLevel, MAX_UPGRADE_LEVEL);
        frameUpgradeSlider:SetValue(targetUpgradeLevel);

        -- Update costs
        DarkChaos_ItemUpgrade_UpdateCosts();

        -- Update stats display
        DarkChaos_ItemUpgrade_UpdateStatsDisplay();

    else
        -- No item selected
        frameItemName:SetText("No item selected");
        frameItemName:SetTextColor(0.5, 0.5, 0.5);
        frameItemLevel:SetText("");
        frameCurrentLevelValue:SetText("0/15");
        frameUpgradeSlider:SetMinMaxValues(0, MAX_UPGRADE_LEVEL);
        frameUpgradeSlider:SetValue(0);
        frameCostFrameEssenceCost:SetText("Essence Cost: 0");
        frameCostFrameTokenCost:SetText("Token Cost: 0");
        frameStatsFrameCurrentStatsValue:SetText("Select an item to view stats");
        frameStatsFrameUpgradedStatsValue:SetText("");
        frameUpgradeButton:Disable();
    end
end

function DarkChaos_ItemUpgrade_GetItemLevel(itemLink)
    local itemName, itemLink, itemRarity, itemLevel = GetItemInfo(itemLink);
    return itemLevel or 1;
end

function DarkChaos_ItemUpgrade_UpdateCosts()
    if not selectedItem or not currentItemStats then return end;

    local currentLevel = currentItemStats.upgradeLevel;
    local levelsToUpgrade = targetUpgradeLevel - currentLevel;

    if levelsToUpgrade <= 0 then
        DarkChaos_ItemUpgradeFrameCostFrameEssenceCost:SetText("Essence Cost: 0");
        DarkChaos_ItemUpgradeFrameCostFrameTokenCost:SetText("Token Cost: 0");
        return;
    end

    -- Calculate costs (simplified - would need server-side calculation for accuracy)
    local totalEssence = 0;
    local totalTokens = 0;

    for i = currentLevel + 1, targetUpgradeLevel do
        -- Tier 5 (Artifacts) use essence, others use tokens
        local isArtifact = (currentItemStats.tierId == 5);
        if isArtifact then
            totalEssence = totalEssence + (i * 50); -- Simplified scaling
        else
            totalTokens = totalTokens + (i * 25); -- Simplified scaling
        end
    end

    DarkChaos_ItemUpgradeFrameCostFrameEssenceCost:SetText("Essence Cost: " .. FormatNumber(totalEssence));
    DarkChaos_ItemUpgradeFrameCostFrameTokenCost:SetText("Token Cost: " .. FormatNumber(totalTokens));
end

function DarkChaos_ItemUpgrade_UpdateStatsDisplay()
    if not selectedItem then return end;

    -- Current stats
    local currentStatsText = GetItemStatsText(selectedItem.itemLink, currentItemStats and currentItemStats.upgradeLevel or 0, false);
    DarkChaos_ItemUpgradeFrameStatsFrameCurrentStatsValue:SetText(currentStatsText);

    -- Upgraded stats
    if targetUpgradeLevel > (currentItemStats and currentItemStats.upgradeLevel or 0) then
        local upgradedStatsText = GetItemStatsText(selectedItem.itemLink, targetUpgradeLevel, true);
        DarkChaos_ItemUpgradeFrameStatsFrameUpgradedStatsValue:SetText(upgradedStatsText);
    else
        DarkChaos_ItemUpgradeFrameStatsFrameUpgradedStatsValue:SetText("No upgrade selected");
    end
end

-- Item slot interactions
function DarkChaos_ItemUpgrade_OnItemSlotClick()
    DarkChaos_ItemUpgrade_ShowInventoryFrame();
end

function DarkChaos_ItemUpgrade_OnItemSlotReceiveDrag()
    local infoType, itemId, itemLink = GetCursorInfo();
    if infoType == "item" and itemLink then
        DarkChaos_ItemUpgrade_SelectItem(itemLink);
        ClearCursor();
    end
end

function DarkChaos_ItemUpgrade_SelectItem(itemLink)
    if not itemLink then return end;

    selectedItem = {
        itemLink = itemLink,
        bag = nil,
        slot = nil
    };

    -- Get current item stats from server (simplified - would need server communication)
    currentItemStats = DarkChaos_ItemUpgrade_GetItemUpgradeStats(itemLink);

    targetUpgradeLevel = currentItemStats and currentItemStats.upgradeLevel or 0;

    DarkChaos_ItemUpgrade_UpdateUI();
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
        -- Simulate inventory scan
        DarkChaos_ItemUpgrade_HandleInventoryResponse(data);
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
        DarkChaos_ItemUpgrade_UpdateUI();
    else
        DEFAULT_CHAT_FRAME:AddMessage("Upgrade failed: " .. (data.error or "Unknown error"), 1, 0, 0);
    end
end

function DarkChaos_ItemUpgrade_HandleInventoryResponse(data)
    -- Handle inventory scan response
    -- This would populate the inventory frame with upgradable items
    if data.items then
        -- Update inventory display with server-provided items
        DarkChaos_ItemUpgrade_PopulateInventoryFrame(data.items);
    end
end

function DarkChaos_ItemUpgrade_PopulateInventoryFrame(items)
    -- Clear existing buttons
    for i = 1, 100 do
        local button = getglobal("DC_ItemUpgrade_InvButton" .. i);
        if button then button:Hide(); end
    end

    -- Create buttons for each upgradable item
    for index, itemData in ipairs(items) do
        local button = DarkChaos_ItemUpgrade_CreateInventoryButton(index, nil, nil, itemData.itemLink);
        if button then
            button.itemGuid = itemData.itemGuid;
            button:SetScript("OnClick", function()
                DarkChaos_ItemUpgrade_SelectItemByGuid(itemData.itemGuid, itemData.itemLink);
                DarkChaos_ItemUpgradeFrameInventoryFrame:Hide();
            end);
        end
    end
end

function DarkChaos_ItemUpgrade_SelectItemByGuid(itemGuid, itemLink)
    selectedItem = {
        itemGuid = itemGuid,
        itemLink = itemLink,
        bag = nil,
        slot = nil
    };

    -- Request upgrade info from server
    DarkChaos_ItemUpgrade_SendPacket(SERVER_OPCODES.CMSG_ITEM_UPGRADE_REQUEST_INFO, { itemGuid = itemGuid });

    -- For now, set default stats until server responds
    currentItemStats = {
        upgradeLevel = 0,
        tierId = 1,
        essenceInvested = 0,
        tokensInvested = 0,
        statMultiplier = 1.0
    };

    targetUpgradeLevel = 0;
    DarkChaos_ItemUpgrade_UpdateUI();
end

-- Inventory frame functions
function DarkChaos_ItemUpgrade_ShowInventoryFrame()
    local inventoryFrame = DarkChaos_ItemUpgradeFrameInventoryFrame;

    -- Request upgradable items from server
    DarkChaos_ItemUpgrade_SendPacket(SERVER_OPCODES.CMSG_ITEM_UPGRADE_INVENTORY_SCAN, {});

    -- Show loading message
    DarkChaos_ItemUpgradeFrameInventoryFrameTitle:SetText("Loading upgradable items...");

    inventoryFrame:Show();
end

function DarkChaos_ItemUpgrade_CreateInventoryButton(index, bag, slot, itemLink)
    local buttonName = "DC_ItemUpgrade_InvButton" .. index;
    local button = getglobal(buttonName);

    if not button then
        button = CreateFrame("Button", buttonName, DarkChaos_ItemUpgradeFrameInventoryFrame, "ItemButtonTemplate");
        button:SetScript("OnClick", function()
            DarkChaos_ItemUpgrade_SelectItem(itemLink);
            DarkChaos_ItemUpgradeFrameInventoryFrame:Hide();
        end);
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT");
            GameTooltip:SetHyperlink(itemLink);
            GameTooltip:Show();
        end);
        button:SetScript("OnLeave", function()
            GameTooltip:Hide();
        end);
    end

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
    local texture = GetContainerItemInfo(bag, slot);
    SetItemButtonTexture(button, texture);

    button:Show();
    return button;
end

-- Slider functions
function DarkChaos_ItemUpgrade_OnSliderValueChanged()
    targetUpgradeLevel = DarkChaos_ItemUpgradeFrameUpgradeSlider:GetValue();
    getglobal(DarkChaos_ItemUpgradeFrameUpgradeSlider:GetName() .. "Text"):SetText("Target Level: " .. targetUpgradeLevel);

    DarkChaos_ItemUpgrade_UpdateCosts();
    DarkChaos_ItemUpgrade_UpdateStatsDisplay();

    -- Enable/disable upgrade button
    if selectedItem and targetUpgradeLevel > (currentItemStats and currentItemStats.upgradeLevel or 0) then
        DarkChaos_ItemUpgradeFrameUpgradeButton:Enable();
    else
        DarkChaos_ItemUpgradeFrameUpgradeButton:Disable();
    end
end

-- Upgrade button
function DarkChaos_ItemUpgrade_OnUpgradeClick()
    if not selectedItem or not currentItemStats then return end;

    local currentLevel = currentItemStats.upgradeLevel;
    local levelsToUpgrade = targetUpgradeLevel - currentLevel;

    if levelsToUpgrade <= 0 then
        DEFAULT_CHAT_FRAME:AddMessage("No upgrade levels selected.", 1, 0, 0);
        return;
    end

    -- Send upgrade request to server
    DarkChaos_ItemUpgrade_SendPacket(SERVER_OPCODES.CMSG_ITEM_UPGRADE_PERFORM, {
        itemGuid = selectedItem.itemGuid,
        targetLevel = targetUpgradeLevel
    });

    DEFAULT_CHAT_FRAME:AddMessage("Sending upgrade request to server...", 0, 1, 0);
end

-- Event handlers
function DarkChaos_ItemUpgrade_OnEvent(event, arg1)
    if event == "BAG_UPDATE" or event == "UNIT_INVENTORY_CHANGED" then
        -- Refresh inventory display if inventory frame is shown
        if DarkChaos_ItemUpgradeFrameInventoryFrame:IsShown() then
            DarkChaos_ItemUpgrade_ShowInventoryFrame();
        end
    end
end

-- Hook into the frame's event handler
DarkChaos_ItemUpgradeFrame:SetScript("OnEvent", DarkChaos_ItemUpgrade_OnEvent);