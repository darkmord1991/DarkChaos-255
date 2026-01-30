-- ============================================================
-- DarkChaos AoE Loot Settings Addon
-- ============================================================
-- A lightweight WoW 3.3.5a addon for managing AoE loot settings
-- Integrates with Interface -> AddOns menu
-- Uses DCAddonProtocol for server communication (with fallback)
-- ============================================================

-- Create the addon namespace
DCAoELootSettings = DCAoELootSettings or {}
local addon = DCAoELootSettings

-- Addon info
addon.name = "DC-AOESettings"
addon.version = "1.2.0"
addon.prefix = "DCAOE"  -- Legacy prefix (fallback)

-- DCAddonProtocol integration
local DC = rawget(_G, "DCAddonProtocol")
addon.useDCProtocol = (DC ~= nil)

-- Helper function to clamp a value within a range (defined early for use throughout)
local function Clamp(value, minVal, maxVal)
    if value == nil then return minVal end
    if value < minVal then return minVal end
    if value > maxVal then return maxVal end
    return value
end

-- Settings defaults
addon.defaults = {
    enabled = true,
    showMessages = true, -- Toggle for info messages
    minQuality = 0,      -- 0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary
    autoSkin = true,
    smartLoot = true,
    autoVendorPoor = false,
    goldOnly = false,    -- Only loot gold (quest items still looted)
    debugMessages = false, -- Verbose debug messages (sync status etc)
    -- Fast Looting settings (adapted from Leatrix Plus)
    fastLoot = true,         -- Enable faster looting
    fastLootDelay = 0.3,     -- Delay between loot attempts (seconds)
    -- Note: Range is controlled by server config, not per-player
}

-- Current settings (loaded from SavedVariables)
addon.settings = {}

-- Flag to temporarily ignore server sync responses after user changes
-- This prevents the UI from flickering when user clicks a setting
addon.ignoreSync = false
addon.ignoreSyncUntil = 0

-- Quality names for display
addon.qualityNames = {
    [0] = "|cff9d9d9dPoor|r",
    [1] = "|cffffffffCommon|r",
    [2] = "|cff1eff00Uncommon|r",
    [3] = "|cff0070ddRare|r",
    [4] = "|cffa335eeEpic|r",
    [5] = "|cffff8000Legendary|r",
}

-- Loot Filter Presets (quick-switch configurations)
addon.presets = {
    [0] = { name = "Everything",   minQuality = 0, color = "|cff9d9d9d" },
    [1] = { name = "Vendor Trash", minQuality = 1, color = "|cffffffff" },
    [2] = { name = "Adventurer",   minQuality = 2, color = "|cff1eff00" },
    [3] = { name = "Raider",       minQuality = 3, color = "|cff0070dd" },
    [4] = { name = "Collector",    minQuality = 4, color = "|cffa335ee" },
    [5] = { name = "Custom",       minQuality = nil, color = "|cffffd700" },
}

-- Get preset name for display
function addon:GetPresetName(presetId)
    local preset = self.presets[presetId]
    if preset then
        return preset.color .. preset.name .. "|r"
    end
    return "|cff888888Unknown|r"
end

-- Apply preset (sets minQuality based on preset)
function addon:ApplyPreset(presetId)
    local preset = self.presets[presetId]
    if not preset then return end
    
    self.settings.activePreset = presetId
    if preset.minQuality ~= nil then
        self.settings.minQuality = preset.minQuality
    end
    
    self:UpdateUI()
    self:SaveSettingsLocal()
    self:SyncSettingToServer("minQuality", self.settings.minQuality)
    self:Confirm("Loot Preset", self:GetPresetName(presetId))
end

-- UI elements
addon.frame = nil
addon.checkboxes = {}
addon.optionsPanel = nil -- For Interface Options

-- Message helper - respects showMessages setting
function addon:Print(msg, forceShow)
    if forceShow or self.settings.showMessages then
        print("|cff00ff00[DC AoE Loot]|r " .. msg)
    end
end

-- Confirmation message helper - always shows for user actions
function addon:Confirm(settingName, value)
    local valueStr
    if type(value) == "boolean" then
        valueStr = value and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
    elseif type(value) == "number" then
        valueStr = "|cffffd700" .. value .. "|r"
    else
        valueStr = "|cffffd700" .. tostring(value) .. "|r"
    end
    print("|cff00ff00[DC AoE Loot]|r " .. settingName .. " set to " .. valueStr)
end

-- ============================================================
-- 3.3.5a Compatibility - Timer replacement
-- ============================================================
local function DelayedCall(delay, func)
    local frame = CreateFrame("Frame")
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            func()
        end
    end)
end

-- ============================================================
-- SavedVariables Management
-- ============================================================
function addon:LoadSettings()
    -- Load from SavedVariables or use defaults
    if DCAoELootSettingsDB then
        for k, v in pairs(self.defaults) do
            if DCAoELootSettingsDB[k] ~= nil then
                self.settings[k] = DCAoELootSettingsDB[k]
            else
                self.settings[k] = v
            end
        end
    else
        for k, v in pairs(self.defaults) do
            self.settings[k] = v
        end
    end
    
    -- Validate loaded settings to ensure they're within valid ranges
    self.settings.minQuality = Clamp(self.settings.minQuality or 0, 0, 5)
end

function addon:SaveSettingsLocal()
    -- Save to SavedVariables
    if not DCAoELootSettingsDB then
        DCAoELootSettingsDB = {}
    end
    for k, v in pairs(self.settings) do
        DCAoELootSettingsDB[k] = v
    end
end

-- ============================================================
-- Server Command Helpers (send settings via chat commands)
-- ============================================================
function addon:SendServerCommand(cmd)
    -- Execute the command as if the player typed it in chat
    -- This works for server commands starting with . in WoW 3.3.5a
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
        local editBox = DEFAULT_CHAT_FRAME.editBox
        local oldText = editBox:GetText() or ""
        editBox:SetText(cmd)
        ChatEdit_SendText(editBox)
        editBox:SetText(oldText)
    else
        -- Fallback: Try to use ChatFrameEditBox directly
        if ChatFrameEditBox then
            local oldText = ChatFrameEditBox:GetText() or ""
            ChatFrameEditBox:SetText(cmd)
            ChatEdit_SendText(ChatFrameEditBox)
            ChatFrameEditBox:SetText(oldText)
        end
    end
end

function addon:SyncSettingToServer(settingKey, value)
    -- Set flag to ignore sync responses for 2 seconds after user makes a change
    -- This prevents the UI from flickering when server sends back the old value
    self.ignoreSync = true
    self.ignoreSyncUntil = GetTime() + 2.0
    
    -- Use DCAddonProtocol if available
    if self.useDCProtocol and DC then
        if settingKey == "enabled" then
            DC.AOE.Toggle(value)
        elseif settingKey == "minQuality" then
            DC.AOE.SetQuality(value)
        elseif settingKey == "autoSkin" then
            DC.AOE.SetAutoSkin(value)
        elseif settingKey == "showMessages" then
            -- TODO: Add showMessages to protocol
            self:SendServerCommand(value and ".lp msg 1" or ".lp msg 0")
        elseif settingKey == "smartLoot" then
            -- TODO: Add smartLoot to protocol
            self:SendServerCommand(".lp smart")
        end
        return
    end
    
    -- Fallback: Map settings to server commands that directly set the state (not toggles)
    if settingKey == "enabled" then
        if value then
            self:SendServerCommand(".lp enable")
        else
            self:SendServerCommand(".lp disable")
        end
    elseif settingKey == "showMessages" then
        if value then
            self:SendServerCommand(".lp msg 1")
        else
            self:SendServerCommand(".lp msg 0")
        end
    elseif settingKey == "minQuality" then
        self:SendServerCommand(".lp quality " .. tostring(value))
    elseif settingKey == "autoSkin" then
        if value then
            self:SendServerCommand(".lp skinset 1")
        else
            self:SendServerCommand(".lp skinset 0")
        end
    elseif settingKey == "smartLoot" then
        self:SendServerCommand(".lp smart")
    elseif settingKey == "goldOnly" then
        if value then
            self:SendServerCommand(".lp goldonly 1")
        else
            self:SendServerCommand(".lp goldonly 0")
        end
    end
end

-- ============================================================
-- Initialization
-- ============================================================
function addon:Initialize()
    -- Load settings from SavedVariables
    self:LoadSettings()
    
    -- Note: In 3.3.5a, RegisterAddonMessagePrefix doesn't exist
    -- Addon messages work without pre-registration in this client version
    
    -- Create main frame (standalone panel)
    self:CreateMainFrame()
    
    -- Create Interface Options panel
    self:CreateOptionsPanel()
    
    -- Register events
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        addon:OnEvent(event, ...)
    end)
    
    -- Request settings from server on load (delayed)
    DelayedCall(2, function()
        addon:RequestSettings()
    end)
    
    self:Print("Settings addon loaded. Type /aoeloot to open or find in Interface → AddOns.", true)
end

-- ============================================================
-- Event Handler
-- ============================================================

-- Flag to prevent double handler registration
local _handlersRegistered = false

function addon:OnEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Load settings and request from server
        self:LoadSettings()
        self:UpdateUI()
        
        -- Try to register DC handlers (DC may have loaded after us)
        if not _handlersRegistered then
            local DC = rawget(_G, "DCAddonProtocol")
            if DC then
                addon:RegisterDCHandlers(DC)
                addon.useDCProtocol = true
                addon:Print("Connected to server via DCAddonProtocol", true)
            end
        end
        
        DelayedCall(2, function()
            addon:RequestSettings()
        end)
    elseif event == "PLAYER_LOGIN" then
        -- Re-check DC availability (in case it loaded after us)
        if not _handlersRegistered then
            local DC = rawget(_G, "DCAddonProtocol")
            if DC then
                addon:RegisterDCHandlers(DC)
                addon.useDCProtocol = true
                addon:Print("Connected to server via DCAddonProtocol", true)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Save settings on logout
        self:SaveSettingsLocal()
    end
end

-- ============================================================
-- DC Handler Registration (called on PLAYER_ENTERING_WORLD/PLAYER_LOGIN)
-- ============================================================
local _lastSyncTime = 0
local _syncDebounce = 2  -- Ignore syncs within 2 seconds of each other

function addon:RegisterDCHandlers(DC)
    if _handlersRegistered then return end
    if not DC then return end
    
    _handlersRegistered = true
    
    -- Handle settings sync from server (opcode 0x11 = SMSG_SETTINGS_SYNC)
    DC:RegisterHandler("AOE", 0x11, function(...)
        -- Check if we should ignore this sync (user just made a change)
        if addon.ignoreSync and GetTime() < addon.ignoreSyncUntil then
            -- Only show debug message if verbose mode enabled
            if addon.settings.debugMessages then
                addon:Print("Ignoring server sync (user change pending)", false)
            end
            return
        end
        addon.ignoreSync = false
        
        -- Debounce duplicate sync messages (server may send multiple during login)
        local now = GetTime()
        local showMessage = (now - _lastSyncTime) > _syncDebounce
        _lastSyncTime = now
        
        local args = {...}
        
        if type(args[1]) == "table" then
            -- JSON format
            local json = args[1]
            addon.settings.enabled = json.enabled or false
            addon.settings.showMessages = json.showMessages ~= false
            addon.settings.minQuality = Clamp(json.minQuality or json.quality or 0, 0, 5)
            addon.settings.autoSkin = json.autoSkin or false
            addon.settings.smartLoot = json.smartLoot or false
            addon.settings.autoVendorPoor = json.autoVendorPoor or false
            addon.settings.goldOnly = json.goldOnly or false
            if json.range then addon.settings.range = json.range end
        else
            -- Pipe-delimited format
            local enabled, showMessages, minQuality, autoSkin, smartLoot, autoVendorPoor, goldOnly = args[1], args[2], args[3], args[4], args[5], args[6], args[7]
            addon.settings.enabled = (enabled == "1" or enabled == 1 or enabled == true)
            addon.settings.showMessages = (showMessages == "1" or showMessages == 1 or showMessages == true or showMessages == nil)
            addon.settings.minQuality = Clamp(tonumber(minQuality) or 0, 0, 5)
            addon.settings.autoSkin = (autoSkin == "1" or autoSkin == 1 or autoSkin == true)
            addon.settings.smartLoot = (smartLoot == "1" or smartLoot == 1 or smartLoot == true)
            addon.settings.autoVendorPoor = (autoVendorPoor == "1" or autoVendorPoor == 1 or autoVendorPoor == true)
            addon.settings.goldOnly = (goldOnly == "1" or goldOnly == 1 or goldOnly == true)
        end
        
        addon:SaveSettingsLocal()
        addon:UpdateUI()
        -- Only show sync message if not a duplicate (debounced)
        if showMessage then
            addon:Print("Settings synced from server.", true)
        end
    end)
    
    -- Handle stats response (opcode 0x10 = SMSG_STATS)
    DC:RegisterHandler("AOE", 0x10, function(...)
        local args = {...}
        local totalItems, totalGold, vendorGold, upgrades
        
        if type(args[1]) == "table" then
            -- JSON format
            local json = args[1]
            totalItems = json.totalItems or json.items or 0
            totalGold = json.totalGold or json.gold or 0
            vendorGold = json.vendorGold or json.vendor or 0
            upgrades = json.upgrades or 0
        else
            -- Pipe-delimited format
            totalItems = tonumber(args[1]) or 0
            totalGold = tonumber(args[2]) or 0
            vendorGold = tonumber(args[3]) or 0
            upgrades = tonumber(args[4]) or 0
        end
        
        addon:ShowStats(totalItems, totalGold, vendorGold, upgrades)
    end)
    
    -- Handle loot result notification (opcode 0x12 = SMSG_LOOT_RESULT)
    DC:RegisterHandler("AOE", 0x12, function(...)
        local args = {...}
        local itemCount, quality, itemId, itemName
        
        if type(args[1]) == "table" then
            local json = args[1]
            itemCount = json.count or json.itemCount or 0
            quality = json.quality or 0
            itemId = json.itemId
            itemName = json.itemName
        else
            itemCount = tonumber(args[1]) or 0
            quality = tonumber(args[2]) or 0
        end
        
        if addon.settings.showMessages then
            if itemName then
                addon:Print("Looted " .. itemCount .. " items (incl. " .. itemName .. ")", false)
            else
                addon:Print("Looted " .. itemCount .. " items", false)
            end
        end
    end)
    
    -- Handle gold collected notification (opcode 0x13 = SMSG_GOLD_COLLECTED)
    DC:RegisterHandler("AOE", 0x13, function(...)
        local args = {...}
        local copperAmount
        
        if type(args[1]) == "table" then
            local json = args[1]
            copperAmount = json.amount or json.copper or 0
        else
            copperAmount = tonumber(args[1]) or 0
        end
        
        if addon.settings.showMessages and copperAmount > 0 then
            local goldStr = GetCoinTextureString(copperAmount)
            addon:Print("Collected " .. goldStr, false)
        end
    end)
    
    -- Handle upgrade found notification (opcode 0x14 = custom)
    DC:RegisterHandler("AOE", 0x14, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            local json = args[1]
            if json.itemName and json.itemLink then
                addon:Print("Upgrade found: " .. (json.itemLink or json.itemName), true)
            end
        else
            local itemId, itemName, slot = args[1], args[2], args[3]
            if itemName then
                addon:Print("Upgrade found: " .. itemName, true)
            end
        end
    end)
    
    -- Request settings on protocol init (JSON format standard)
    addon.RequestSettingsViaDC = function()
        if DC then
            DC:Request("AOE", 0x06, { action = "get_settings" })  -- CMSG_GET_SETTINGS
        end
    end
    
    -- Test connection (JSON format standard)
    addon.TestConnection = function()
        if not DC then
            addon:Print("DCAddonProtocol not available", true)
            return
        end
        addon:Print("Testing DC Protocol connection (JSON format)...", true)
        DC:Request("AOE", 0x06, { action = "get_settings" })  -- Get settings
        DC:Request("AOE", 0x03, { action = "get_stats" })  -- Get stats
    end
    
    addon:Print("DCAddonProtocol v" .. (DC.VERSION or "?") .. " handlers registered", false)
end

-- ============================================================
-- Server Communication (DCAddonProtocol + Legacy fallback)
-- ============================================================

-- Send message using DCAddonProtocol if available, otherwise legacy
function addon:SendToServer(messageType, data)
    if self.useDCProtocol and DC then
        -- Use new protocol: DC|AOE|opcode|data...
        local opcode = 0x06  -- CMSG_GET_SETTINGS default
        if messageType == "GET_SETTINGS" then
            opcode = 0x06
            DC.AOE.GetSettings()
            return
        elseif messageType == "SAVE_SETTINGS" then
            -- Parse data and send individual settings via protocol
            if data then
                local enabled, showMessages, minQuality, autoSkin, smartLoot, autoVendorPoor = strsplit(",", data)
                -- The new protocol handles individual setting changes
                -- For bulk save, we'll send each setting
                DC.AOE.Toggle(tonumber(enabled) == 1)
                DC.AOE.SetQuality(tonumber(minQuality) or 0)
                DC.AOE.SetAutoSkin(tonumber(autoSkin) == 1)
            end
            return
        elseif messageType == "GET_STATS" then
            opcode = 0x03
            DC.AOE.GetStats()
            return
        end
    end

    self:Print("DCAddonProtocol not available; server sync requires unified protocol.", true)
end

function addon:RequestSettings()
    if self.useDCProtocol and DC then
        DC.AOE.GetSettings()
    else
        self:Print("DCAddonProtocol not available; unable to request settings.", true)
    end
end

function addon:SaveSettings()
    -- Validate and clamp settings before saving
    self.settings.minQuality = Clamp(self.settings.minQuality or 0, 0, 5)
    
    -- Save locally first
    self:SaveSettingsLocal()
    
    -- Then send to server with validated values
    local data = string.format("%d,%d,%d,%d,%d,%d,%d",
        self.settings.enabled and 1 or 0,
        self.settings.showMessages and 1 or 0,
        self.settings.minQuality,
        self.settings.autoSkin and 1 or 0,
        self.settings.smartLoot and 1 or 0,
        self.settings.autoVendorPoor and 1 or 0,
        self.settings.goldOnly and 1 or 0
    )
    self:SendToServer("SAVE_SETTINGS", data)
    self:Print("Settings saved!", true)
end

function addon:HandleServerMessage(message)
    local msgType, data = strsplit(":", message, 2)
    
    if msgType == "SETTINGS" and data then
        -- Check if we should ignore this sync (user just made a change)
        if self.ignoreSync and GetTime() < self.ignoreSyncUntil then
            -- Only show debug message if verbose mode enabled
            if self.settings.debugMessages then
                self:Print("Ignoring server sync (user change pending)", false)
            end
            return
        end
        self.ignoreSync = false
        
        -- Parse settings: enabled,showMessages,minQuality,autoSkin,smartLoot,autoVendorPoor,goldOnly
        local enabled, showMessages, minQuality, autoSkin, smartLoot, autoVendorPoor, goldOnly = strsplit(",", data)
        
        self.settings.enabled = tonumber(enabled) == 1
        self.settings.showMessages = tonumber(showMessages) == 1 or (showMessages == nil)
        -- Clamp minQuality to valid range 0-5 (Poor to Legendary)
        self.settings.minQuality = Clamp(tonumber(minQuality) or 0, 0, 5)
        self.settings.autoSkin = tonumber(autoSkin) == 1
        self.settings.smartLoot = tonumber(smartLoot) == 1
        self.settings.autoVendorPoor = tonumber(autoVendorPoor) == 1
        self.settings.goldOnly = tonumber(goldOnly) == 1
        
        self:SaveSettingsLocal()
        self:UpdateUI()
        -- Note: Don't print here - the RegisterHandler callback already prints
        
    elseif msgType == "SAVED" then
        self:Print("Settings saved to server!", true)
        
    elseif msgType == "STATS" and data then
        -- Parse stats: totalItems,totalGold,vendorGold,upgrades
        local totalItems, totalGold, vendorGold, upgrades = strsplit(",", data)
        self:ShowStats(tonumber(totalItems), tonumber(totalGold), tonumber(vendorGold), tonumber(upgrades))
        
    elseif msgType == "ERROR" then
        print("|cffff0000[DC AoE Loot]|r Error: " .. (data or "Unknown error"))
    end
end

-- ============================================================
-- Interface Options Panel (appears in Interface -> AddOns)
-- ============================================================
function addon:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "DCAoELootOptionsPanel", UIParent)
    panel.name = "DC AoE Loot"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DarkChaos|r AoE Loot Settings")
    
    -- Version
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    version:SetText("Version " .. self.version)
    
    local yPos = -60
    local xPos = 20
    
    -- Enable AoE Loot checkbox
    local enableCB = self:CreateOptionsCheckbox(panel, "Enable AoE Loot", 
        "Disable to loot only the corpse you click (no nearby corpse merging).",
        xPos, yPos, "enabled")
    yPos = yPos - 30
    
    -- Show Messages checkbox
    local messagesCB = self:CreateOptionsCheckbox(panel, "Show Messages", 
        "Show info messages like 'merged X corpses'. Disable to hide spam.",
        xPos, yPos, "showMessages")
    yPos = yPos - 30
    
    -- Auto Skin checkbox
    local skinCB = self:CreateOptionsCheckbox(panel, "Auto-Skin/Mine/Herb", 
        "Automatically skin, mine, or herb corpses when looting.",
        xPos, yPos, "autoSkin")
    yPos = yPos - 30
    
    -- Smart Loot checkbox
    local smartCB = self:CreateOptionsCheckbox(panel, "Smart Loot (Upgrade Detection)", 
        "Prioritize gear upgrades when looting.",
        xPos, yPos, "smartLoot")
    yPos = yPos - 30
    
    -- Auto Vendor Poor checkbox
    local vendorCB = self:CreateOptionsCheckbox(panel, "Auto-Vendor Poor Items", 
        "Automatically vendor gray/poor quality items.",
        xPos, yPos, "autoVendorPoor")
    yPos = yPos - 30
    
    -- Gold Only checkbox
    local goldOnlyCB = self:CreateOptionsCheckbox(panel, "Gold Only (Quest Items Still Looted)", 
        "Only loot gold from corpses. Quest items will still be picked up automatically.",
        xPos, yPos, "goldOnly")
    yPos = yPos - 40
    
    -- Fast Loot Section Header
    local fastLootHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fastLootHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    fastLootHeader:SetText("|cffffd700Fast Looting (Client-Side)|r")
    yPos = yPos - 25
    
    -- Fast Loot Enable checkbox
    local fastLootCB = self:CreateOptionsCheckbox(panel, "Enable Fast Looting", 
        "Speed up looting by automatically clicking loot items. Works alongside AoE Loot.",
        xPos, yPos, "fastLoot")
    yPos = yPos - 30
    
    -- Fast Loot Info
    local fastLootInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fastLootInfo:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    fastLootInfo:SetWidth(300)
    fastLootInfo:SetJustifyH("LEFT")
    fastLootInfo:SetText("|cff888888Automatically loots items when you open a corpse. Works with Auto-Loot enabled.|r")
    yPos = yPos - 30

    -- Minimum Quality Label
    local qualityLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    qualityLabel:SetText("Minimum Quality to Loot:")
    yPos = yPos - 20
    
    -- Quality buttons for Interface Options panel
    self.optionQualityButtons = {}
    for i = 0, 5 do
        local btn = CreateFrame("Button", "DCAoELootOptQuality" .. i, panel)
        btn:SetWidth(75)
        btn:SetHeight(18)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + (i % 3) * 80, yPos - math.floor(i / 3) * 20)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetAllPoints()
        btn.text:SetText(self.qualityNames[i])
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        
        btn.quality = i
        btn:SetScript("OnClick", function()
            local quality = Clamp(i, 0, 5)
            self.settings.minQuality = quality
            self:UpdateOptionsQualityButtons()
            self:UpdateQualityButtons()
            self:Confirm("Minimum Quality", self.qualityNames[quality])
            self:SaveSettingsLocal()
            self:SyncSettingToServer("minQuality", quality)
        end)
        btn:SetScript("OnEnter", function()
            btn.bg:SetTexture(0.4, 0.4, 0.4, 0.8)
        end)
        btn:SetScript("OnLeave", function()
            if self.settings.minQuality == i then
                btn.bg:SetTexture(0, 0.5, 0, 0.8)
            else
                btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.optionQualityButtons[i] = btn
    end
    yPos = yPos - 50
    
    -- Note about server override
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    note:SetWidth(350)
    note:SetJustifyH("LEFT")
    note:SetText("|cffff8800Note:|r Disabling AoE Loot will make you loot only the clicked corpse. The server must be recompiled for this to take effect.")
    yPos = yPos - 50
    
    -- Open Full Panel button
    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetWidth(200)
    openBtn:SetHeight(25)
    openBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    openBtn:SetText("Open Full Settings Panel")
    openBtn:SetScript("OnClick", function()
        InterfaceOptionsFrame:Hide()
        addon:Toggle()
    end)
    
    -- Register with Interface Options
    InterfaceOptions_AddCategory(panel)
    self.optionsPanel = panel
    
    -- Create Communication sub-panel
    self:CreateCommunicationPanel(panel)
end

-- ============================================================
-- Communication Settings Sub-Panel
-- ============================================================
function addon:CreateCommunicationPanel(parentPanel)
    local panel = CreateFrame("Frame", "DCAoELootCommPanel", UIParent)
    panel.name = "Communication"
    panel.parent = parentPanel.name
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ff00DC AoE Loot|r - Communication")
    
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Manage server communication protocols and test connectivity.")
    
    local yPos = -70
    local xPos = 20
    
    -- Protocol Status Section
    local statusHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    statusHeader:SetText("|cffffd700Protocol Status|r")
    yPos = yPos - 20
    
    -- DCAddonProtocol status
    local dcStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    dcStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.dcStatus = dcStatus
    yPos = yPos - 18
    
    -- Connection status
    local connStatus = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    connStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.connStatus = connStatus
    yPos = yPos - 18
    
    -- Server version
    local serverVer = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    serverVer:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    panel.serverVer = serverVer
    yPos = yPos - 30
    
    -- Test Buttons Section
    local testHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    testHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    testHeader:SetText("|cffffd700Test Communication|r")
    yPos = yPos - 25
    
    -- Test Connection button
    local testBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    testBtn:SetWidth(150)
    testBtn:SetHeight(22)
    testBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    testBtn:SetText("Test Connection")
    testBtn:SetScript("OnClick", function()
        if addon.TestConnection then
            addon.TestConnection()
        elseif DC then
            DC:Request("AOE", 0x06, { action = "get_settings" })  -- CMSG_GET_SETTINGS
            DC:Request("AOE", 0x03, { action = "get_stats" })  -- CMSG_GET_STATS
            addon:Print("Test messages sent (JSON format)", true)
        else
            addon:Print("DC Protocol not available", true)
        end
    end)
    
    -- Request Settings button
    local reqBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reqBtn:SetWidth(150)
    reqBtn:SetHeight(22)
    reqBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    reqBtn:SetText("Request Settings")
    reqBtn:SetScript("OnClick", function()
        addon:RequestSettings()
        addon:Print("Settings requested from server", true)
    end)
    yPos = yPos - 30
    
    -- Get Stats button
    local statsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    statsBtn:SetWidth(150)
    statsBtn:SetHeight(22)
    statsBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    statsBtn:SetText("Get Loot Stats")
    statsBtn:SetScript("OnClick", function()
        if DC then
            DC:Request("AOE", 0x03, { action = "get_stats" })  -- CMSG_GET_STATS
        else
            SendChatMessage(".lp stats", "SAY")
        end
    end)
    
    -- Reconnect button
    local reconBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reconBtn:SetWidth(150)
    reconBtn:SetHeight(22)
    reconBtn:SetPoint("LEFT", statsBtn, "RIGHT", 10, 0)
    reconBtn:SetText("Reconnect")
    reconBtn:SetScript("OnClick", function()
        if DC then
            DC._connected = false
            DC._handshakeSent = false
            DC:Request("CORE", 1, { version = DC.VERSION })
            addon:Print("Reconnection handshake sent (JSON)", true)
        else
            addon:Print("DC Protocol not available", true)
        end
    end)
    yPos = yPos - 40
    
    -- Info Section
    local infoHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
    infoHeader:SetText("|cffffd700Information|r")
    yPos = yPos - 20
    
    local infoText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 10, yPos)
    infoText:SetWidth(450)
    infoText:SetJustifyH("LEFT")
    infoText:SetText("DC-AOESettings uses DCAddonProtocol for efficient server communication.\n" ..
        "If DCAddonProtocol is not available, settings are synced via chat commands.\n\n" ..
        "Slash commands: /aoeloot, /dcaoe")
    
    -- Update function
    local function UpdateStatus()
        local dcAvail = rawget(_G, "DCAddonProtocol")
        panel.dcStatus:SetText("DCAddonProtocol: " .. (dcAvail and "|cff00ff00Available v" .. (dcAvail.VERSION or "?") .. "|r" or "|cffff0000Not Loaded|r"))
        if dcAvail then
            panel.connStatus:SetText("Connected: " .. (dcAvail._connected and "|cff00ff00Yes|r" or "|cffff0000No|r"))
            panel.serverVer:SetText("Server Version: " .. (dcAvail._serverVersion or "|cff888888Unknown|r"))
        else
            panel.connStatus:SetText("Connected: |cff888888N/A|r")
            panel.serverVer:SetText("Server Version: |cff888888N/A|r")
        end
    end
    
    panel:SetScript("OnShow", UpdateStatus)
    
    InterfaceOptions_AddCategory(panel)
    self.commPanel = panel
end

function addon:CreateOptionsCheckbox(parent, label, tooltip, x, y, settingKey)
    -- Need a unique name for 3.3.5a template to work properly
    local cbName = "DCAoELootOptCB_" .. settingKey
    local cb = CreateFrame("CheckButton", cbName, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    
    -- In 3.3.5a, the text is accessed via global name pattern, not .Text
    local textObj = _G[cbName .. "Text"]
    if textObj then
        textObj:SetText(label)
    end
    
    cb.tooltipText = tooltip
    
    -- Set initial value
    cb:SetChecked(self.settings[settingKey])
    
    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        addon.settings[settingKey] = checked
        addon:Confirm(label, checked)
        addon:SaveSettingsLocal()
        addon:SyncSettingToServer(settingKey, checked)
        addon:UpdateUI()
    end)
    
    -- Store reference for updating
    if not self.optionCheckboxes then self.optionCheckboxes = {} end
    self.optionCheckboxes[settingKey] = cb
    
    return cb
end

-- ============================================================
-- UI Creation (3.3.5a Compatible) - Standalone Panel
-- ============================================================
function addon:CreateMainFrame()
    -- Create base frame without template (3.3.5a doesn't have BasicFrameTemplateWithInset)
    local frame = CreateFrame("Frame", "DCAoELootSettingsFrame", UIParent)
    frame:SetWidth(350)
    frame:SetHeight(430)  -- Increased height for Fast Loot section
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    
    -- Create background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 0)

    do
        local BG_FELLEATHER = "Interface\\AddOns\\DC-AOESettings\\Textures\\Backgrounds\\FelLeather_512.tga"
        local BG_TINT_ALPHA = 0.60

        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        bg:SetAllPoints()
        bg:SetTexture(BG_FELLEATHER)
        if bg.SetHorizTile then bg:SetHorizTile(false) end
        if bg.SetVertTile then bg:SetVertTile(false) end

        local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        tint:SetAllPoints()
        tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

        frame.__dcBg = bg
        frame.__dcTint = tint
    end
    
    -- Create close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Title
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -15)
    frame.title:SetText("|cff00ff00DarkChaos|r AoE Loot Settings")
    
    self.frame = frame
    
    local yPos = -45
    local xPos = 20
    
    -- Enable checkbox
    self.checkboxes.enabled = self:CreateCheckbox(frame, "Enable AoE Loot", xPos, yPos, 
        function(checked) 
            self.settings.enabled = checked 
            self:Confirm("Enable AoE Loot", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("enabled", checked)
        end)
    yPos = yPos - 30
    
    -- Show Messages checkbox (NEW)
    self.checkboxes.showMessages = self:CreateCheckbox(frame, "Show Messages (debug output)", xPos, yPos,
        function(checked) 
            self.settings.showMessages = checked 
            self:Confirm("Show Messages", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("showMessages", checked)
        end)
    yPos = yPos - 30
    
    -- Auto Skin checkbox
    self.checkboxes.autoSkin = self:CreateCheckbox(frame, "Auto-Skin/Mine/Herb", xPos, yPos,
        function(checked) 
            self.settings.autoSkin = checked 
            self:Confirm("Auto-Skin/Mine/Herb", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("autoSkin", checked)
        end)
    yPos = yPos - 30
    
    -- Smart Loot checkbox
    self.checkboxes.smartLoot = self:CreateCheckbox(frame, "Smart Loot (Upgrade Detection)", xPos, yPos,
        function(checked) 
            self.settings.smartLoot = checked 
            self:Confirm("Smart Loot", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("smartLoot", checked)
        end)
    yPos = yPos - 30
    
    -- Auto Vendor Poor checkbox
    self.checkboxes.autoVendorPoor = self:CreateCheckbox(frame, "Auto-Vendor Poor Items", xPos, yPos,
        function(checked) 
            self.settings.autoVendorPoor = checked 
            self:Confirm("Auto-Vendor Poor Items", checked)
            self:SaveSettingsLocal()
        end)
    yPos = yPos - 30
    
    -- Gold Only checkbox
    self.checkboxes.goldOnly = self:CreateCheckbox(frame, "Gold Only (Quest Items Still Looted)", xPos, yPos,
        function(checked) 
            self.settings.goldOnly = checked 
            self:Confirm("Gold Only", checked)
            self:SaveSettingsLocal()
            self:SyncSettingToServer("goldOnly", checked)
        end)
    yPos = yPos - 35
    
    -- Fast Loot Section
    local fastLootLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fastLootLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
    fastLootLabel:SetText("|cffffd700Fast Looting:|r")
    yPos = yPos - 25
    
    -- Fast Loot checkbox
    self.checkboxes.fastLoot = self:CreateCheckbox(frame, "Enable Fast Looting (Client-Side)", xPos, yPos,
        function(checked) 
            self.settings.fastLoot = checked 
            self:Confirm("Fast Looting", checked)
            self:SaveSettingsLocal()
        end)
    yPos = yPos - 30

    -- Minimum Quality dropdown label
    local qualityLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
    qualityLabel:SetText("Minimum Quality to Loot:")
    yPos = yPos - 25
    
    -- Quality buttons (radio-style)
    self.qualityButtons = {}
    for i = 0, 5 do
        local btn = CreateFrame("Button", nil, frame)
        btn:SetWidth(80)
        btn:SetHeight(20)
        btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos + (i % 3) * 90, yPos - math.floor(i / 3) * 22)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetAllPoints()
        btn.text:SetText(self.qualityNames[i])
        
        -- Use SetTexture instead of SetColorTexture (3.3.5a compatible)
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        
        btn.quality = i
        btn:SetScript("OnClick", function()
            -- Clamp quality to valid range 0-5
            local quality = Clamp(i, 0, 5)
            self.settings.minQuality = quality
            self:UpdateQualityButtons()
            self:Confirm("Minimum Quality", self.qualityNames[quality])
            self:SaveSettingsLocal()
            self:SyncSettingToServer("minQuality", quality)
        end)
        btn:SetScript("OnEnter", function()
            btn.bg:SetTexture(0.4, 0.4, 0.4, 0.8)
        end)
        btn:SetScript("OnLeave", function()
            if self.settings.minQuality == i then
                btn.bg:SetTexture(0, 0.5, 0, 0.8)
            else
                btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
            end
        end)
        
        self.qualityButtons[i] = btn
    end
    yPos = yPos - 60
    
    -- Info label about server-controlled range
    local rangeInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rangeInfo:SetPoint("TOPLEFT", frame, "TOPLEFT", xPos, yPos)
    rangeInfo:SetWidth(280)
    rangeInfo:SetJustifyH("LEFT")
    rangeInfo:SetText("|cff888888Note: Loot range is controlled by server (default: 30 yards)|r")
    yPos = yPos - 30
    
    -- Save button
    local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    saveBtn:SetWidth(120)
    saveBtn:SetHeight(25)
    saveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 15)
    saveBtn:SetText("Save Settings")
    saveBtn:SetScript("OnClick", function()
        self:SaveSettings()
    end)
    
    -- Stats button
    local statsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    statsBtn:SetWidth(120)
    statsBtn:SetHeight(25)
    statsBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 15)
    statsBtn:SetText("Show Stats")
    statsBtn:SetScript("OnClick", function()
        -- Try server command first (more reliable than addon message)
        SendChatMessage(".lp stats", "SAY")
    end)
end

function addon:CreateCheckbox(parent, label, x, y, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.text:SetText(label)
    cb:SetScript("OnClick", function()
        if onChange then onChange(cb:GetChecked()) end
    end)
    return cb
end

function addon:UpdateUI()
    if not self.frame then return end
    
    if self.checkboxes.enabled then
        self.checkboxes.enabled:SetChecked(self.settings.enabled)
    end
    if self.checkboxes.showMessages then
        self.checkboxes.showMessages:SetChecked(self.settings.showMessages)
    end
    if self.checkboxes.autoSkin then
        self.checkboxes.autoSkin:SetChecked(self.settings.autoSkin)
    end
    if self.checkboxes.smartLoot then
        self.checkboxes.smartLoot:SetChecked(self.settings.smartLoot)
    end
    if self.checkboxes.autoVendorPoor then
        self.checkboxes.autoVendorPoor:SetChecked(self.settings.autoVendorPoor)
    end
    if self.checkboxes.goldOnly then
        self.checkboxes.goldOnly:SetChecked(self.settings.goldOnly)
    end
    if self.checkboxes.fastLoot then
        self.checkboxes.fastLoot:SetChecked(self.settings.fastLoot)
    end
    
    self:UpdateQualityButtons()
    self:UpdateOptionsQualityButtons()
    
    -- Also update options panel checkboxes if they exist
    if self.optionCheckboxes then
        for key, cb in pairs(self.optionCheckboxes) do
            if self.settings[key] ~= nil then
                cb:SetChecked(self.settings[key])
            end
        end
    end
end

function addon:UpdateQualityButtons()
    if not self.qualityButtons then return end
    for i, btn in pairs(self.qualityButtons) do
        if self.settings.minQuality == i then
            btn.bg:SetTexture(0, 0.5, 0, 0.8)
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
end

function addon:UpdateOptionsQualityButtons()
    if not self.optionQualityButtons then return end
    for i, btn in pairs(self.optionQualityButtons) do
        if self.settings.minQuality == i then
            btn.bg:SetTexture(0, 0.5, 0, 0.8)
        else
            btn.bg:SetTexture(0.2, 0.2, 0.2, 0.8)
        end
    end
end

function addon:ShowStats(totalItems, totalGold, vendorGold, upgrades)
    local goldStr = GetCoinTextureString(totalGold or 0)
    local vendorStr = GetCoinTextureString(vendorGold or 0)
    
    print("|cff00ff00========== AoE Loot Statistics ==========|r")
    print("|cffffd700Total Items Looted:|r " .. (totalItems or 0))
    print("|cffffd700Total Gold Looted:|r " .. goldStr)
    print("|cffffd700Gold from Auto-Vendor:|r " .. vendorStr)
    print("|cffffd700Gear Upgrades Found:|r " .. (upgrades or 0))
    print("|cff00ff00==========================================|r")
end

function addon:Toggle()
    -- Ensure frame exists before trying to use it
    if not self.frame then
        self:CreateMainFrame()
    end
    
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:RequestSettings()
        self.frame:Show()
    end
end

-- ============================================================
-- Slash Commands
-- ============================================================
SLASH_DCAOELOOT1 = "/aoeloot"
SLASH_DCAOELOOT2 = "/dcaoe"
SlashCmdList["DCAOELOOT"] = function(msg)
    msg = strlower(msg or "")
    
    if msg == "stats" then
        -- Use DC protocol if available (JSON format), otherwise server command
        if DCAoELootSettings.useDCProtocol and DC then
            DC:Request("AOE", 0x03, { action = "get_stats" })  -- CMSG_GET_STATS
        else
            SendChatMessage(".lp stats", "SAY")
        end
    elseif msg == "reload" or msg == "sync" or msg == "refresh" then
        DCAoELootSettings:RequestSettings()
    elseif msg == "testconn" then
        if DCAoELootSettings.TestConnection then
            DCAoELootSettings.TestConnection()
        else
            DCAoELootSettings:Print("DC Protocol not available", true)
        end
    elseif msg == "protocol" or msg == "status" then
        local dcAvail = rawget(_G, "DCAddonProtocol") and "|cff00ff00YES|r" or "|cffff0000NO|r"
        DCAoELootSettings:Print("Protocol status:", true)
        print("  DCAddonProtocol: " .. dcAvail)
        print("  Enabled: " .. (DCAoELootSettings.settings.enabled and "|cff00ff00YES|r" or "|cffff0000NO|r"))
        print("  Min Quality: " .. (DCAoELootSettings.qualityNames[DCAoELootSettings.settings.minQuality] or "?"))
        print("  Auto-Skin: " .. (DCAoELootSettings.settings.autoSkin and "YES" or "NO"))
        print("  Smart Loot: " .. (DCAoELootSettings.settings.smartLoot and "YES" or "NO"))
    elseif msg == "config" or msg == "options" then
        InterfaceOptionsFrame_OpenToCategory(DCAoELootSettings.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(DCAoELootSettings.optionsPanel) -- Call twice for WoW bug
    elseif msg == "enable" then
        DCAoELootSettings.settings.enabled = true
        DCAoELootSettings:SaveSettingsLocal()
        DCAoELootSettings:SyncSettingToServer("enabled", true)
        DCAoELootSettings:UpdateUI()
        DCAoELootSettings:Confirm("AoE Loot", true)
    elseif msg == "disable" then
        DCAoELootSettings.settings.enabled = false
        DCAoELootSettings:SaveSettingsLocal()
        DCAoELootSettings:SyncSettingToServer("enabled", false)
        DCAoELootSettings:UpdateUI()
        DCAoELootSettings:Confirm("AoE Loot", false)
    elseif msg:match("^quality%s+%d$") then
        local quality = tonumber(msg:match("%d"))
        if quality and quality >= 0 and quality <= 5 then
            DCAoELootSettings.settings.minQuality = quality
            DCAoELootSettings:SaveSettingsLocal()
            DCAoELootSettings:SyncSettingToServer("minQuality", quality)
            DCAoELootSettings:UpdateUI()
            DCAoELootSettings:Confirm("Min Quality", DCAoELootSettings.qualityNames[quality])
        end
    elseif msg == "help" then
        print("|cff00ff00[DC AoE Loot] Commands:|r")
        print("  /aoeloot - Open settings panel")
        print("  /aoeloot config - Open Interface Options panel")
        print("  /aoeloot stats - Show loot statistics")
        print("  /aoeloot reload - Reload settings from server")
        print("  /aoeloot status - Show protocol status")
        print("  /aoeloot testconn - Test DC protocol")
        print("  /aoeloot enable/disable - Toggle AoE loot")
        print("  /aoeloot quality <0-5> - Set min quality")
        print("  /aoeloot help - Show this help")
    else
        DCAoELootSettings:Toggle()
    end
end

-- Initialize on load
DCAoELootSettings:Initialize()

-- ============================================================
-- FAST LOOTING SYSTEM (Adapted from Leatrix Plus)
-- ============================================================
-- Speeds up looting by automatically clicking loot buttons
-- Works with both regular looting and AoE loot
-- ============================================================

do
    local addon = DCAoELootSettings
    
    -- Fast loot state
    local fastLootFrame = CreateFrame("Frame", "DCAoEFastLootFrame", UIParent)
    local isLooting = false
    local lootDelay = 0
    local lastLootTime = 0
    
    -- Sound files for errors
    local errorSounds = {
        ["Interface\\AddOns\\DC-AOESettings\\Sounds\\error.ogg"] = true,
    }
    
    -- Function to perform fast looting
    local function ProcessLoot()
        local settings = addon.settings
        if not settings.fastLoot then return end
        
        -- Check if enough time has passed since last loot
        local now = GetTime()
        local delay = settings.fastLootDelay or 0.3
        if now - lastLootTime < delay then
            return
        end
        lastLootTime = now
        
        -- Get number of loot items
        local numItems = GetNumLootItems()
        if numItems == 0 then return end
        
        -- Check if we have bag space
        local hasBagSpace = false
        for bag = 0, 4 do
            local numFreeSlots = GetContainerNumFreeSlots(bag)
            if numFreeSlots and numFreeSlots > 0 then
                hasBagSpace = true
                break
            end
        end
        
        -- If no bag space, only loot gold/currency
        if not hasBagSpace then
            for i = numItems, 1, -1 do
                local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i)
                local slotType = GetLootSlotType(i)
                
                -- Only loot currency (gold) if no bag space
                if slotType == LOOT_SLOT_MONEY or currencyID then
                    LootSlot(i)
                end
            end
        else
            -- Normal fast looting - loot all items
            for i = numItems, 1, -1 do
                local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem, questId, isActive = GetLootSlotInfo(i)
                
                -- Skip locked items (need roll, etc)
                if not locked then
                    LootSlot(i)
                end
            end
        end
    end
    
    -- Event handler for loot window opening
    fastLootFrame:RegisterEvent("LOOT_READY")
    fastLootFrame:RegisterEvent("LOOT_OPENED")
    fastLootFrame:RegisterEvent("LOOT_CLOSED")
    
    fastLootFrame:SetScript("OnEvent", function(self, event, ...)
        local settings = addon.settings
        if not settings.fastLoot then return end
        
        if event == "LOOT_READY" or event == "LOOT_OPENED" then
            -- Auto loot is handled by WoW's auto-loot setting
            -- We just speed up the looting process
            isLooting = true
            
            -- Process loot immediately
            ProcessLoot()
            
        elseif event == "LOOT_CLOSED" then
            isLooting = false
        end
    end)
    
    -- OnUpdate for continuous looting (some items may not loot on first try)
    local updateElapsed = 0
    fastLootFrame:SetScript("OnUpdate", function(self, elapsed)
        if not isLooting then return end
        if not addon.settings.fastLoot then return end
        
        updateElapsed = updateElapsed + elapsed
        if updateElapsed >= (addon.settings.fastLootDelay or 0.3) then
            updateElapsed = 0
            ProcessLoot()
        end
    end)
    
    -- Function to add fast loot UI to the options panel
    function addon:AddFastLootOptions(panel, yPos, xPos)
        -- Fast Loot Section Header
        local fastLootHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fastLootHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
        fastLootHeader:SetText("|cffffd700Fast Looting|r")
        yPos = yPos - 25
        
        -- Fast Loot Enable checkbox
        local fastLootCB = self:CreateOptionsCheckbox(panel, "Enable Fast Looting", 
            "Speed up looting by automatically clicking loot items.",
            xPos, yPos, "fastLoot")
        yPos = yPos - 30
        
        -- Fast Loot Delay slider
        local delayLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        delayLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos, yPos)
        delayLabel:SetText("Loot Speed:")
        
        local delaySlider = CreateFrame("Slider", "DCAoEFastLootDelaySlider", panel, "OptionsSliderTemplate")
        delaySlider:SetPoint("TOPLEFT", panel, "TOPLEFT", xPos + 80, yPos + 5)
        delaySlider:SetWidth(150)
        delaySlider:SetMinMaxValues(0.1, 0.5)
        delaySlider:SetValueStep(0.05)
        delaySlider:SetObeyStepOnDrag(true)
        delaySlider:SetValue(self.settings.fastLootDelay or 0.3)
        
        local low = _G["DCAoEFastLootDelaySliderLow"]
        local high = _G["DCAoEFastLootDelaySliderHigh"]
        local text = _G["DCAoEFastLootDelaySliderText"]
        
        if low then low:SetText("Fast") end
        if high then high:SetText("Slow") end
        if text then text:SetText(string.format("%.2fs", self.settings.fastLootDelay or 0.3)) end
        
        delaySlider:SetScript("OnValueChanged", function(self, value)
            addon.settings.fastLootDelay = value
            addon:SaveSettingsLocal()
            if text then text:SetText(string.format("%.2fs", value)) end
        end)
        
        return yPos - 40
    end
    
    addon:Print("Fast Looting system loaded", false)
end
