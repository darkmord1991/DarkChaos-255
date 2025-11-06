--[[
    DarkChaos Item Upgrade - Client-Server Communication (Pure Eluna)
    
    This script handles communication between the DC-ItemUpgrade client addon
    and the server using only Eluna + Database queries (no C++ required).
    
    Commands from client:
    - .dcupgrade init                  - Request player's current tokens/essence
    - .dcupgrade query <bag> <slot>    - Request item upgrade info
    - .dcupgrade perform <bag> <slot> <level> - Perform upgrade
    
    Author: DarkChaos Development Team
    Date: November 6, 2025
]]

-- Helper: Get player currency from database
local function GetPlayerCurrency(player, currencyType)
    local guid = player:GetGUIDLow()
    local query = CharDBQuery(string.format(
        "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = %d AND currency_type = %d",
        guid, currencyType
    ))
    
    if query then
        local amount = query:GetUInt32(0)
        return amount
    end
    return 0
end

-- Helper: Get item upgrade state from database
local function GetItemUpgradeState(itemGUID)
    local query = CharDBQuery(string.format(
        "SELECT upgrade_level, tier FROM dc_item_upgrade_state WHERE item_guid = %d",
        itemGUID
    ))
    
    if query then
        return query:GetUInt32(0), query:GetUInt32(1) -- upgrade_level, tier
    end
    return 0, 1 -- Default: level 0, tier 1
end

-- Helper: Calculate item tier based on item level
local function CalculateItemTier(itemLevel)
    if itemLevel >= 450 then return 5 end
    if itemLevel >= 400 then return 4 end
    if itemLevel >= 350 then return 3 end
    if itemLevel >= 300 then return 2 end
    return 1
end

-- Chat message handler for .dcupgrade commands
local function OnChat(event, player, msg, type, lang)
    -- Only process SAY messages (type 0)
    if type ~= 0 then return end
    
    -- Check if message starts with .dcupgrade
    if not msg:match("^%.dcupgrade") then return end
    
    -- Extract the command (remove leading '.')
    local command = msg:sub(2) -- "dcupgrade init" etc.
    
    -- Parse it
    local args = {}
    for word in command:gmatch("%S+") do
        table.insert(args, word)
    end
    
    if args[1] ~= "dcupgrade" then
        return false
    end
    
    local subcommand = args[2]
    
    if subcommand == "init" then
        -- Send player's current currency balances
        -- Format: DCUPGRADE_INIT:<upgrade_tokens>:<artifact_essence>
        local tokens = GetPlayerCurrency(player, 1)   -- 1 = CURRENCY_UPGRADE_TOKEN
        local essence = GetPlayerCurrency(player, 2)  -- 2 = CURRENCY_ARTIFACT_ESSENCE
        
        print(string.format("[DC-ItemUpgrade] Init request from %s - Tokens: %d, Essence: %d", player:GetName(), tokens, essence))
        player:SendBroadcastMessage(string.format("DCUPGRADE_INIT:%d:%d", tokens, essence))
        return false -- Suppress message from appearing in chat
        
    elseif subcommand == "query" then
        -- Query item upgrade info
        -- Format: .dcupgrade query <bag> <slot>
        local bag = tonumber(args[3])
        local slot = tonumber(args[4])
        
        if not bag or not slot then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Invalid bag/slot")
            return false
        end
        
        local item = player:GetItemByPos(bag, slot)
        if not item then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Item not found in bag " .. bag .. " slot " .. slot)
            return false
        end
        
        local itemGUID = item:GetGUIDLow()
        local baseItemLevel = item:GetItemLevel(player)
        local upgradeLevel, tier = GetItemUpgradeState(itemGUID)
        
        if tier == 0 then
            tier = CalculateItemTier(baseItemLevel)
        end
        
        -- Format: DCUPGRADE_QUERY:<item_guid>:<upgrade_level>:<tier>:<base_ilvl>
        player:SendBroadcastMessage(string.format("DCUPGRADE_QUERY:%d:%d:%d:%d", 
            itemGUID, upgradeLevel, tier, baseItemLevel))
        return false
        
    elseif subcommand == "perform" then
        -- Perform item upgrade
        -- Format: .dcupgrade perform <bag> <slot> <target_level>
        local bag = tonumber(args[3])
        local slot = tonumber(args[4])
        local targetLevel = tonumber(args[5])
        
        if not bag or not slot or not targetLevel then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Invalid parameters")
            return false
        end
        
        local item = player:GetItemByPos(bag, slot)
        if not item then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Item not found")
            return false
        end
        
        local itemGUID = item:GetGUIDLow()
        local currentLevel, tier = GetItemUpgradeState(itemGUID)
        
        if targetLevel <= currentLevel then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Target level must be higher than current")
            return false
        end
        
        if targetLevel > 15 then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Maximum upgrade level is 15")
            return false
        end
        
        local costQuery = WorldDBQuery(string.format(
            "SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs WHERE tier = %d AND upgrade_level = %d",
            tier, targetLevel
        ))
        
        if not costQuery then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Cannot determine upgrade cost")
            return false
        end
        
        local tokensNeeded = costQuery:GetUInt32(0)
        local essenceNeeded = costQuery:GetUInt32(1)
        
        local currentTokens = GetPlayerCurrency(player, 1)
        local currentEssence = GetPlayerCurrency(player, 2)
        
        if currentTokens < tokensNeeded then
            player:SendBroadcastMessage(string.format("DCUPGRADE_ERROR:Not enough Upgrade Tokens (need %d, have %d)", 
                tokensNeeded, currentTokens))
            return false
        end
        
        if currentEssence < essenceNeeded then
            player:SendBroadcastMessage(string.format("DCUPGRADE_ERROR:Not enough Artifact Essence (need %d, have %d)", 
                essenceNeeded, currentEssence))
            return false
        end
        
        local guid = player:GetGUIDLow()
        
        -- Deduct tokens
        CharDBExecute(string.format(
            "UPDATE dc_item_upgrade_currency SET amount = amount - %d WHERE player_guid = %d AND currency_type = 1",
            tokensNeeded, guid
        ))
        
        -- Deduct essence
        CharDBExecute(string.format(
            "UPDATE dc_item_upgrade_currency SET amount = amount - %d WHERE player_guid = %d AND currency_type = 2",
            essenceNeeded, guid
        ))
        
        -- Update item upgrade state
        CharDBExecute(string.format(
            "INSERT INTO dc_item_upgrade_state (item_guid, player_guid, upgrade_level, tier, tokens_invested) " ..
            "VALUES (%d, %d, %d, %d, %d) " ..
            "ON DUPLICATE KEY UPDATE upgrade_level = %d, tokens_invested = tokens_invested + %d",
            itemGUID, guid, targetLevel, tier, tokensNeeded, targetLevel, tokensNeeded
        ))
        
        player:SendBroadcastMessage(string.format("DCUPGRADE_SUCCESS:%d:%d", itemGUID, targetLevel))
        player:SendBroadcastMessage("|cff00ff00Item upgraded to level " .. targetLevel .. "!|r")
        player:SendBroadcastMessage("|cffff9900Note: Relog to see stat changes (C++ integration pending)|r")
        
        return false
    end
    
    return false
end

-- Register server command hook for .dcupgrade commands
local function HandleDCUpgradeCommand(player, args)
    if not player then return false end
    
    -- Parse the command arguments
    -- args format: "init" or "query 0 4" or "perform 0 4 5"
    local parts = {}
    for word in args:gmatch("%S+") do
        table.insert(parts, word)
    end
    
    if #parts < 1 then return false end
    
    local subcommand = parts[1]
    
    if subcommand == "init" then
        local tokens = GetPlayerCurrency(player, 1)
        local essence = GetPlayerCurrency(player, 2)
        player:SendBroadcastMessage(string.format("DCUPGRADE_INIT:%d:%d", tokens, essence))
        return true
        
    elseif subcommand == "query" then
        local bag = tonumber(parts[2])
        local slot = tonumber(parts[3])
        
        if not bag or not slot then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Invalid bag/slot")
            return true
        end
        
        local item = player:GetItemByPos(bag, slot)
        if not item then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Item not found in bag " .. bag .. " slot " .. slot)
            return true
        end
        
        local itemGUID = item:GetGUIDLow()
        local baseItemLevel = item:GetItemLevel(player)
        local upgradeLevel, tier = GetItemUpgradeState(itemGUID)
        
        if tier == 0 then
            tier = CalculateItemTier(baseItemLevel)
        end
        
        player:SendBroadcastMessage(string.format("DCUPGRADE_QUERY:%d:%d:%d:%d", 
            itemGUID, upgradeLevel, tier, baseItemLevel))
        return true
        
    elseif subcommand == "perform" then
        local bag = tonumber(parts[2])
        local slot = tonumber(parts[3])
        local targetLevel = tonumber(parts[4])
        
        if not bag or not slot or not targetLevel then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Invalid parameters")
            return true
        end
        
        local item = player:GetItemByPos(bag, slot)
        if not item then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Item not found")
            return true
        end
        
        local itemGUID = item:GetGUIDLow()
        local currentLevel, tier = GetItemUpgradeState(itemGUID)
        
        if targetLevel <= currentLevel then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Target level must be higher than current")
            return true
        end
        
        if targetLevel > 15 then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Maximum upgrade level is 15")
            return true
        end
        
        local costQuery = WorldDBQuery(string.format(
            "SELECT upgrade_tokens, artifact_essence FROM dc_item_upgrade_costs WHERE tier = %d AND upgrade_level = %d",
            tier, targetLevel
        ))
        
        if not costQuery then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Cannot determine upgrade cost")
            return true
        end
        
        local tokensNeeded = costQuery:GetUInt32(0)
        local essenceNeeded = costQuery:GetUInt32(1)
        
        local currentTokens = GetPlayerCurrency(player, 1)
        local currentEssence = GetPlayerCurrency(player, 2)
        
        if currentTokens < tokensNeeded then
            player:SendBroadcastMessage(string.format("DCUPGRADE_ERROR:Not enough Upgrade Tokens (need %d, have %d)", 
                tokensNeeded, currentTokens))
            return true
        end
        
        if currentEssence < essenceNeeded then
            player:SendBroadcastMessage(string.format("DCUPGRADE_ERROR:Not enough Artifact Essence (need %d, have %d)", 
                essenceNeeded, currentEssence))
            return true
        end
        
        local guid = player:GetGUIDLow()
        
        CharDBExecute(string.format(
            "UPDATE dc_item_upgrade_currency SET amount = amount - %d WHERE player_guid = %d AND currency_type = 1",
            tokensNeeded, guid
        ))
        
        CharDBExecute(string.format(
            "UPDATE dc_item_upgrade_currency SET amount = amount - %d WHERE player_guid = %d AND currency_type = 2",
            essenceNeeded, guid
        ))
        
        CharDBExecute(string.format(
            "INSERT INTO dc_item_upgrade_state (item_guid, player_guid, upgrade_level, tier, tokens_invested) " ..
            "VALUES (%d, %d, %d, %d, %d) " ..
            "ON DUPLICATE KEY UPDATE upgrade_level = %d, tokens_invested = tokens_invested + %d",
            itemGUID, guid, targetLevel, tier, tokensNeeded, targetLevel, tokensNeeded
        ))
        
        player:SendBroadcastMessage(string.format("DCUPGRADE_SUCCESS:%d:%d", itemGUID, targetLevel))
        player:SendBroadcastMessage("|cff00ff00Item upgraded to level " .. targetLevel .. "!|r")
        player:SendBroadcastMessage("|cffff9900Note: Relog to see stat changes (C++ integration pending)|r")
        
        return true
    end
    
    return false
end

-- Register the command hook using AddSC_Commands approach for AzerothCore
-- This needs to be called as a command that the server recognizes
if CreateCommand then
    CreateCommand("dcupgrade", HandleDCUpgradeCommand, 0)
elseif RegisterCommand then
    RegisterCommand("dcupgrade", 0, HandleDCUpgradeCommand, 0)
else
    -- Fallback: try using chat event hook
    RegisterPlayerEvent(18, OnChat)  -- PLAYER_EVENT_ON_CHAT
end

print(">> DC-ItemUpgrade Communication Script Loaded")
