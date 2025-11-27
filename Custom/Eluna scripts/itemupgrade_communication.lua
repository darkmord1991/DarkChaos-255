--[[
    DarkChaos Item Upgrade - Communication Handler
    
    NOTE: Main command handling has been moved to C++ (src/server/scripts/DC/ItemUpgrades/ItemUpgradeAddonHandler.cpp)
    
    This script handles:
    - DCUPGRADE:PACKAGE:<id> addon messages (package selection sync)
    - Player login notifications for heirloom state
    
    The .dcupgrade and .dcheirloom commands are handled by:
    - ItemUpgradeAddonHandler.cpp (C++ command handler)
    
    Author: DarkChaos Development Team
    Date: November 7, 2025
    Updated: November 26, 2025 (Added addon message handler for heirloom packages)
]]

print(">> DC-ItemUpgrade: Communication handler loaded")

-- Store selected packages per player (temporary, refreshed on login)
local PlayerPackageSelections = {}

-- Handle addon messages from client
local function OnAddonMessage(event, sender, messageType, prefix, msg, target)
    -- Only handle DCUPGRADE prefix
    if prefix ~= "DCUPGRADE" then
        return
    end
    
    -- Parse message format: PACKAGE:<packageId>
    local command, value = string.match(msg, "^(%w+):(%d+)$")
    
    if command == "PACKAGE" then
        local packageId = tonumber(value)
        local playerGuid = sender:GetGUIDLow()
        
        -- Validate package ID (1-12)
        if not packageId or packageId < 1 or packageId > 12 then
            sender:SendBroadcastMessage("|cffff0000Invalid package ID.|r")
            return
        end
        
        -- Store selection for this player
        PlayerPackageSelections[playerGuid] = packageId
        
        -- Debug logging
        print(string.format(">> DC-ItemUpgrade: Player %s selected package %d", 
            sender:GetName(), packageId))
    end
end

-- Clear player data on logout
local function OnPlayerLogout(event, player)
    local playerGuid = player:GetGUIDLow()
    PlayerPackageSelections[playerGuid] = nil
end

-- Send heirloom state on login
local function OnPlayerLogin(event, player)
    -- Query for any heirloom upgrades this player has
    local playerGuid = player:GetGUIDLow()
    
    -- Initialize player's package selection to nil
    PlayerPackageSelections[playerGuid] = nil
    
    -- Note: Detailed heirloom state is sent via .dcheirloom query when addon requests it
    -- This is just for initialization
end

-- Get player's selected package (used by other Eluna scripts if needed)
function GetPlayerSelectedPackage(player)
    if not player then return nil end
    local playerGuid = player:GetGUIDLow()
    return PlayerPackageSelections[playerGuid]
end

-- Register event handlers
RegisterPlayerEvent(30, OnAddonMessage)   -- PLAYER_EVENT_ON_WHISPER (for addon messages to self)
RegisterPlayerEvent(3, OnPlayerLogout)    -- PLAYER_EVENT_ON_LOGOUT
RegisterPlayerEvent(3, OnPlayerLogin)     -- PLAYER_EVENT_ON_LOGIN

print(">> DC-ItemUpgrade: Addon message handler registered")
