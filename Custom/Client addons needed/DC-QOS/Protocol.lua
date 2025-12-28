-- ============================================================
-- DC-QoS: Server Communication Protocol
-- ============================================================
-- Handles communication with the DarkChaos server via DCAddonProtocol
-- Module ID: QOS
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Protocol Configuration
-- ============================================================
addon.protocol = {
    MODULE_ID = "QOS",
    connected = false,
    DC = nil,  -- DCAddonProtocol reference
}

local protocol = addon.protocol

-- ============================================================
-- Opcodes (must match server-side dc_addon_qos.cpp)
-- ============================================================
protocol.Opcodes = {
    -- Client -> Server (0x01-0x0F)
    CMSG_SYNC_SETTINGS      = 0x01,  -- Request settings sync
    CMSG_UPDATE_SETTING     = 0x02,  -- Update a single setting
    CMSG_GET_ITEM_INFO      = 0x03,  -- Request custom item info (DB data)
    CMSG_GET_NPC_INFO       = 0x04,  -- Request custom NPC info (DB GUID, spawn info)
    CMSG_GET_SPELL_INFO     = 0x05,  -- Request custom spell info
    CMSG_REQUEST_FEATURE    = 0x06,  -- Request specific feature data
    
    -- Server -> Client (0x10-0x1F)
    SMSG_SETTINGS_SYNC      = 0x10,  -- Full settings sync from server
    SMSG_SETTING_UPDATED    = 0x11,  -- Confirmation of setting update
    SMSG_ITEM_INFO          = 0x12,  -- Custom item information
    SMSG_NPC_INFO           = 0x13,  -- Custom NPC information (DB GUID, spawn info)
    SMSG_SPELL_INFO         = 0x14,  -- Custom spell information
    SMSG_FEATURE_DATA       = 0x15,  -- Feature-specific data
    SMSG_NOTIFICATION       = 0x16,  -- Server notification/message
}

-- ============================================================
-- DCAddonProtocol Integration
-- ============================================================

-- Initialize protocol connection
function protocol:Initialize()
    local DC = rawget(_G, "DCAddonProtocol")
    if not DC then
        addon:Debug("DCAddonProtocol not found, waiting...")
        return false
    end
    
    self.DC = DC
    self:RegisterHandlers()
    self.connected = true
    
    addon:Debug("Protocol initialized - Module: " .. self.MODULE_ID)
    return true
end

-- Register message handlers
function protocol:RegisterHandlers()
    if not self.DC then return end
    
    local DC = self.DC
    local Ops = self.Opcodes
    
    -- Handle settings sync from server
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SETTINGS_SYNC, function(...)
        self:HandleSettingsSync(...)
    end)
    
    -- Handle setting update confirmation
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SETTING_UPDATED, function(...)
        self:HandleSettingUpdated(...)
    end)
    
    -- Handle custom item info response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_ITEM_INFO, function(...)
        self:HandleItemInfo(...)
    end)
    
    -- Handle custom NPC info response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_NPC_INFO, function(...)
        self:HandleNpcInfo(...)
    end)
    
    -- Handle custom spell info response
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_SPELL_INFO, function(...)
        self:HandleSpellInfo(...)
    end)
    
    -- Handle server notifications
    DC:RegisterHandler(self.MODULE_ID, Ops.SMSG_NOTIFICATION, function(...)
        self:HandleNotification(...)
    end)
    
    addon:Debug("Registered " .. self.MODULE_ID .. " protocol handlers")
end

-- ============================================================
-- Message Sending
-- ============================================================

-- Send a message to the server
function protocol:Send(opcode, ...)
    if not self.DC or not self.connected then
        addon:Debug("Cannot send - protocol not connected")
        return false
    end
    
    self.DC:Send(self.MODULE_ID, opcode, ...)
    return true
end

-- Send JSON message
function protocol:SendJson(opcode, data)
    if not self.DC or not self.connected then
        addon:Debug("Cannot send - protocol not connected")
        return false
    end

    -- DC-AddonProtocol exposes SendJSON (capital JSON). Keep this wrapper name
    -- for backwards-compat with the rest of DC-QOS.
    if type(self.DC.SendJSON) == "function" then
        self.DC:SendJSON(self.MODULE_ID, opcode, data)
    elseif type(self.DC.SendJson) == "function" then
        self.DC:SendJson(self.MODULE_ID, opcode, data)
    else
        addon:Debug("DCAddonProtocol missing SendJSON/SendJson")
        return false
    end
    return true
end

-- Request settings sync from server
function protocol:RequestSync()
    return self:Send(self.Opcodes.CMSG_SYNC_SETTINGS)
end

-- Update a setting on the server
function protocol:UpdateSetting(settingPath, value)
    return self:SendJson(self.Opcodes.CMSG_UPDATE_SETTING, {
        path = settingPath,
        value = value,
    })
end

-- Request custom item info from server
function protocol:RequestItemInfo(itemId)
    return self:Send(self.Opcodes.CMSG_GET_ITEM_INFO, itemId)
end

-- Request custom NPC info from server (DB GUID)
function protocol:RequestNpcInfo(npcGuid)
    return self:Send(self.Opcodes.CMSG_GET_NPC_INFO, npcGuid)
end

-- Request custom spell info from server
function protocol:RequestSpellInfo(spellId)
    return self:Send(self.Opcodes.CMSG_GET_SPELL_INFO, spellId)
end

-- Request item upgrade info from server (tier, upgrade level, etc.)
function protocol:RequestItemUpgradeInfo(bag, slot)
    return self:SendJson(self.Opcodes.CMSG_GET_ITEM_INFO, {
        bag = bag,
        slot = slot,
        type = "upgrade",  -- Specifies we want upgrade data, not just basic info
    })
end

-- ============================================================
-- Message Handlers
-- ============================================================

-- Handle full settings sync from server
function protocol:HandleSettingsSync(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        -- JSON format - merge server settings
        local serverSettings = args[1]
        
        for category, settings in pairs(serverSettings) do
            if type(settings) == "table" and addon.settings[category] then
                for key, value in pairs(settings) do
                    addon.settings[category][key] = value
                end
            end
        end
        
        addon:SaveSettings()
        addon:FireEvent("SETTINGS_SYNCED", serverSettings)
        addon:Debug("Settings synced from server")
    end
end

-- Handle setting update confirmation
function protocol:HandleSettingUpdated(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local data = args[1]
        addon:Debug("Setting confirmed: " .. tostring(data.path) .. " = " .. tostring(data.value))
        addon:FireEvent("SETTING_CONFIRMED", data.path, data.value)
    end
end

-- Handle custom item info from server
function protocol:HandleItemInfo(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local itemData = args[1]
        addon:FireEvent("ITEM_INFO_RECEIVED", itemData)
        
        -- Check if this is upgrade info (has upgradeLevel or tier)
        if itemData.upgradeLevel ~= nil or itemData.tier ~= nil then
            addon:FireEvent("ITEM_UPGRADE_INFO_RECEIVED", itemData)
        end
        
        -- Cache for tooltip display
        if itemData.itemId and addon.tooltipCache then
            addon.tooltipCache.items[itemData.itemId] = itemData
        end
    end
end

-- Handle custom NPC info from server (DB GUID, spawn info)
function protocol:HandleNpcInfo(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local npcData = args[1]
        addon:FireEvent("NPC_INFO_RECEIVED", npcData)
        
        -- Cache for tooltip display
        if npcData.guid and addon.tooltipCache then
            addon.tooltipCache.npcs[npcData.guid] = npcData
        end
    end
end

-- Handle custom spell info from server
function protocol:HandleSpellInfo(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local spellData = args[1]
        addon:FireEvent("SPELL_INFO_RECEIVED", spellData)
        
        -- Cache for tooltip display
        if spellData.spellId and addon.tooltipCache then
            addon.tooltipCache.spells[spellData.spellId] = spellData
        end
    end
end

-- Handle server notification
function protocol:HandleNotification(...)
    local args = {...}
    
    if type(args[1]) == "table" then
        local notification = args[1]
        local msgType = notification.type or "info"
        local message = notification.message or ""
        
        if msgType == "error" then
            addon:Print("|cffff0000Error:|r " .. message, true)
        elseif msgType == "warning" then
            addon:Print("|cffffd700Warning:|r " .. message, true)
        else
            addon:Print(message, true)
        end
        
        addon:FireEvent("NOTIFICATION_RECEIVED", notification)
    end
end

-- ============================================================
-- Tooltip Data Cache
-- ============================================================
addon.tooltipCache = {
    items = {},
    npcs = {},
    spells = {},
}

-- ============================================================
-- Event Hooks
-- ============================================================

-- Try to initialize on player login
addon:RegisterEvent("PLAYER_LOGIN", function()
    addon:DelayedCall(1, function()
        if not protocol.connected then
            protocol:Initialize()
        end
        
        -- Request initial sync
        if protocol.connected then
            protocol:RequestSync()
        end
    end)
end)

-- Re-try connection on entering world
addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if not protocol.connected then
        addon:DelayedCall(2, function()
            if protocol:Initialize() then
                protocol:RequestSync()
            end
        end)
    end
end)

-- Sync setting changes to server
addon:RegisterEvent("SETTING_CHANGED", function(path, value)
    if addon.settings.communication and addon.settings.communication.autoSync then
        protocol:UpdateSetting(path, value)
    end
end)

-- ============================================================
-- Public API
-- ============================================================

-- Expose protocol functions
function addon:IsConnected()
    return protocol.connected
end

function addon:SyncWithServer()
    return protocol:RequestSync()
end

function addon:RequestItemInfo(itemId)
    return protocol:RequestItemInfo(itemId)
end

function addon:RequestNpcInfo(npcGuid)
    return protocol:RequestNpcInfo(npcGuid)
end

function addon:RequestSpellInfo(spellId)
    return protocol:RequestSpellInfo(spellId)
end
