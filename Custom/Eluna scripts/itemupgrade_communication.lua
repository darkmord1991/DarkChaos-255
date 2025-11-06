--[[
    DarkChaos Item Upgrade - Client-Server Communication
    
    This script handles communication between the DC-ItemUpgrade client addon
    and the server-side C++ Item Upgrade system.
    
    Commands from client:
    - .dcupgrade init          - Request player's current tokens/essence
    - .dcupgrade query <slot>  - Request item upgrade info for equipped slot
    - .dcupgrade perform <slot> <target_level> - Perform upgrade
    
    Author: DarkChaos Development Team
    Date: November 6, 2025
]]

-- Register command handler
local function OnCommand(event, player, command)
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
        
        -- Query player's upgrade tokens
        local tokens = QueryTokens(player, 1)  -- 1 = CURRENCY_UPGRADE_TOKEN
        local essence = QueryTokens(player, 2) -- 2 = CURRENCY_ARTIFACT_ESSENCE
        
        player:SendBroadcastMessage(string.format("DCUPGRADE_INIT:%d:%d", tokens, essence))
        return true
        
    elseif subcommand == "query" then
        -- Query item upgrade info
        -- Format: .dcupgrade query <bag> <slot>
        local bag = tonumber(args[3]) or 0
        local slot = tonumber(args[4]) or 0
        
        local item = player:GetItemByPos(bag, slot)
        if not item then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Item not found")
            return true
        end
        
        -- Query item's current upgrade level from C++
        -- This calls the C++ ItemUpgradeManager
        local itemGUID = item:GetGUIDLow()
        local upgradeLevel = QueryItemUpgradeLevel(player, itemGUID)
        local tier = QueryItemTier(player, itemGUID)
        local baseItemLevel = item:GetItemLevel()
        
        -- Send response
        -- Format: DCUPGRADE_QUERY:<item_guid>:<upgrade_level>:<tier>:<base_ilvl>
        player:SendBroadcastMessage(string.format("DCUPGRADE_QUERY:%d:%d:%d:%d", 
            itemGUID, upgradeLevel, tier, baseItemLevel))
        return true
        
    elseif subcommand == "perform" then
        -- Perform item upgrade
        -- Format: .dcupgrade perform <bag> <slot> <target_level>
        local bag = tonumber(args[3]) or 0
        local slot = tonumber(args[4]) or 0
        local targetLevel = tonumber(args[5]) or 0
        
        local item = player:GetItemByPos(bag, slot)
        if not item then
            player:SendBroadcastMessage("DCUPGRADE_ERROR:Item not found")
            return true
        end
        
        local itemGUID = item:GetGUIDLow()
        
        -- Call C++ upgrade function
        local success, error = PerformItemUpgrade(player, itemGUID, targetLevel)
        
        if success then
            -- Send success response
            -- Format: DCUPGRADE_SUCCESS:<item_guid>:<new_level>
            player:SendBroadcastMessage(string.format("DCUPGRADE_SUCCESS:%d:%d", itemGUID, targetLevel))
            
            -- Refresh item to show new stats
            player:SendItemQueryPacket(item:GetEntry())
        else
            -- Send error response
            player:SendBroadcastMessage(string.format("DCUPGRADE_ERROR:%s", error or "Unknown error"))
        end
        
        return true
    end
    
    return false
end

-- Helper function to query player's tokens (calls C++ code)
function QueryTokens(player, currencyType)
    -- This would ideally call the C++ UpgradeManager directly
    -- For now, we'll use a workaround through player data
    
    -- Execute C++ command to get tokens
    local playerGUID = player:GetGUIDLow()
    
    -- We need to call the C++ function GetCurrency
    -- In Eluna, we can use CharDBQuery to check the characters database
    local query = CharDBQuery(string.format(
        "SELECT amount FROM dc_item_upgrade_currency WHERE player_guid = %d AND currency_type = %d",
        playerGUID, currencyType
    ))
    
    if query then
        local amount = query:GetUInt32(0)
        return amount
    end
    
    return 0
end

-- Helper function to query item's upgrade level
function QueryItemUpgradeLevel(player, itemGUID)
    local query = CharDBQuery(string.format(
        "SELECT upgrade_level FROM dc_item_upgrade_state WHERE item_guid = %d",
        itemGUID
    ))
    
    if query then
        return query:GetUInt8(0)
    end
    
    return 0
end

-- Helper function to query item's tier
function QueryItemTier(player, itemGUID)
    local query = CharDBQuery(string.format(
        "SELECT tier_id FROM dc_item_upgrade_state WHERE item_guid = %d",
        itemGUID
    ))
    
    if query then
        return query:GetUInt8(0)
    end
    
    -- If not in database, determine tier from item level
    -- This is a fallback - ideally C++ determines this
    return 1  -- Default to TIER_LEVELING
end

-- Helper function to perform upgrade (calls C++ code)
function PerformItemUpgrade(player, itemGUID, targetLevel)
    -- This should call the C++ ItemUpgradeManager::UpgradeItem function
    -- For now, we'll use a workaround through GM commands
    
    local playerName = player:GetName()
    
    -- Execute upgrade command as if GM typed it
    -- This assumes there's a C++ command: .upgrade item <itemGUID> <level>
    local command = string.format("upgrade item %d %d", itemGUID, targetLevel)
    
    -- We need to execute this through the C++ command system
    -- In Eluna, we can use PerformIngameCommand
    -- However, this requires GM level access
    
    -- Better approach: Directly update database and let C++ reload
    -- (This is a simplified version - real implementation should call C++ directly)
    
    -- Check if player has enough currency
    local currentLevel = QueryItemUpgradeLevel(player, itemGUID)
    if targetLevel <= currentLevel then
        return false, "Target level must be higher than current level"
    end
    
    -- Calculate cost (simplified - should call C++ for accurate cost)
    local tokensNeeded = (targetLevel - currentLevel) * 10
    local currentTokens = QueryTokens(player, 1)
    
    if currentTokens < tokensNeeded then
        return false, string.format("Not enough Upgrade Tokens (need %d, have %d)", tokensNeeded, currentTokens)
    end
    
    -- Deduct tokens
    CharDBExecute(string.format(
        "UPDATE dc_item_upgrade_currency SET amount = amount - %d WHERE player_guid = %d AND currency_type = 1",
        tokensNeeded, player:GetGUIDLow()
    ))
    
    -- Update item upgrade state
    CharDBExecute(string.format(
        "INSERT INTO dc_item_upgrade_state (item_guid, player_guid, upgrade_level, tokens_invested, last_upgraded_at) " ..
        "VALUES (%d, %d, %d, %d, UNIX_TIMESTAMP()) " ..
        "ON DUPLICATE KEY UPDATE upgrade_level = %d, tokens_invested = tokens_invested + %d, last_upgraded_at = UNIX_TIMESTAMP()",
        itemGUID, player:GetGUIDLow(), targetLevel, tokensNeeded, targetLevel, tokensNeeded
    ))
    
    return true, nil
end

-- Register the command handler
RegisterPlayerEvent(42, OnCommand)  -- PLAYER_EVENT_ON_COMMAND

print(">> ItemUpgrade Communication Script Loaded")
