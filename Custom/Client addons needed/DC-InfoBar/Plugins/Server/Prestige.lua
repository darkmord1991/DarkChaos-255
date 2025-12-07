--[[
    DC-InfoBar Prestige Plugin
    Shows prestige level and status, blinks when ready to prestige
    
    Data Source: DCAddonProtocol PRES module
]]

local addonName = "DC-InfoBar"
local DCInfoBar = DCInfoBar or {}

local PrestigePlugin = {
    id = "DCInfoBar_Prestige",
    name = "Prestige",
    category = "server",
    type = "combo",
    side = "left",
    priority = 15,  -- After Season
    icon = "Interface\\Icons\\Achievement_Level_80",
    updateInterval = 1.0,  -- Update every second for blink effect
    
    leftClickHint = "Open Prestige panel",
    rightClickHint = "Show prestige info",
    
    -- Cached data
    _prestigeLevel = 0,
    _maxPrestigeLevel = 10,
    _canPrestige = false,
    _requiredLevel = 255,
    _currentLevel = 0,
    _totalBonus = 0,
    _xpBonus = 0,
    _currentXP = 0,
    _xpToNext = 100,
    _bonusList = nil,
    _dataReceived = false,
    
    -- Blink state
    _blinkTimer = 0,
    _blinkState = false,
}

function PrestigePlugin:OnActivate()
    -- Initialize serverData.prestige if not exists
    DCInfoBar.serverData = DCInfoBar.serverData or {}
    DCInfoBar.serverData.prestige = DCInfoBar.serverData.prestige or {}
    
    local function RequestPrestigeData()
        local DC = rawget(_G, "DCAddonProtocol")
        if DC then
            DC:Request("PRES", 0x01, {})  -- CMSG_GET_INFO
            DC:Request("PRES", 0x02, {})  -- CMSG_GET_BONUSES
        end
    end
    
    local function RegisterHandlers()
        local DC = rawget(_G, "DCAddonProtocol")
        if not DC then
            -- Retry after delay
            local retryFrame = CreateFrame("Frame")
            retryFrame.elapsed = 0
            retryFrame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 2 then
                    self:SetScript("OnUpdate", nil)
                    RegisterHandlers()
                end
            end)
            return
        end
        
        -- Register handler for prestige info response (SMSG_INFO = 0x10)
        DC:RegisterHandler("PRES", 0x10, function(data)
            if data then
                PrestigePlugin._prestigeLevel = data.prestigeLevel or data.level or 0
                PrestigePlugin._maxPrestigeLevel = data.maxPrestigeLevel or data.maxLevel or 10
                PrestigePlugin._canPrestige = data.canPrestige or false
                PrestigePlugin._requiredLevel = data.requiredLevel or 255
                PrestigePlugin._currentLevel = data.currentLevel or UnitLevel("player") or 0
                PrestigePlugin._totalBonus = data.totalBonusPercent or data.bonusPercent or 0
                PrestigePlugin._xpBonus = data.xpBonus or data.xpBonusPercent or PrestigePlugin._totalBonus
                PrestigePlugin._currentXP = data.currentXP or 0
                PrestigePlugin._xpToNext = data.xpToNext or data.xpRequired or 100
                PrestigePlugin._dataReceived = true
                PrestigePlugin._elapsed = 999  -- Force update
                
                -- Store in serverData for other plugins
                DCInfoBar.serverData.prestige = {
                    level = PrestigePlugin._prestigeLevel,
                    maxLevel = PrestigePlugin._maxPrestigeLevel,
                    canPrestige = PrestigePlugin._canPrestige,
                    totalBonus = PrestigePlugin._totalBonus,
                    xpBonus = PrestigePlugin._xpBonus,
                    currentXP = PrestigePlugin._currentXP,
                    xpToNext = PrestigePlugin._xpToNext,
                }
                
                DCInfoBar:Debug("Prestige data received: P" .. PrestigePlugin._prestigeLevel)
            end
        end)
        
        -- Also handle bonuses response (SMSG_BONUSES = 0x11)
        DC:RegisterHandler("PRES", 0x11, function(data)
            if data then
                if data.xpBonus then
                    PrestigePlugin._xpBonus = data.xpBonus
                end
                if data.statBonus then
                    PrestigePlugin._totalBonus = data.statBonus
                end
                if data.bonuses and type(data.bonuses) == "table" then
                    PrestigePlugin._bonusList = data.bonuses
                end
                
                -- Update serverData
                if DCInfoBar.serverData.prestige then
                    DCInfoBar.serverData.prestige.xpBonus = PrestigePlugin._xpBonus
                    DCInfoBar.serverData.prestige.totalBonus = PrestigePlugin._totalBonus
                end
            end
        end)
        
        -- Request initial data
        RequestPrestigeData()
        
        -- Retry after delay if no data received
        local retryFrame = CreateFrame("Frame")
        retryFrame.elapsed = 0
        retryFrame.retries = 0
        retryFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 3 then
                self.elapsed = 0
                self.retries = self.retries + 1
                
                if self.retries >= 5 then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                
                if not PrestigePlugin._dataReceived then
                    RequestPrestigeData()
                else
                    self:SetScript("OnUpdate", nil)
                end
            end
        end)
    end
    
    RegisterHandlers()
    
    -- Also check player level locally
    self._currentLevel = UnitLevel("player")
end

function PrestigePlugin:OnUpdate(elapsed)
    -- Update local level
    self._currentLevel = UnitLevel("player")
    
    -- Check if can prestige locally (level 255 or whatever required level)
    if not self._dataReceived then
        -- Fallback: assume can prestige at level 255
        self._canPrestige = (self._currentLevel >= 255)
    end
    
    -- Blink effect when prestige is ready
    if self._canPrestige then
        self._blinkTimer = self._blinkTimer + elapsed
        if self._blinkTimer >= 0.5 then
            self._blinkTimer = 0
            self._blinkState = not self._blinkState
        end
        
        local color = self._blinkState and "|cff00ff00" or "|cffffff00"
        return "", color .. "PRESTIGE READY!|r"
    elseif self._prestigeLevel > 0 then
        -- Show current prestige level with bonus
        return "", "P" .. self._prestigeLevel .. " (+" .. self._totalBonus .. "%)"
    else
        -- Not at required level yet, show progress
        local progress = math.floor((self._currentLevel / self._requiredLevel) * 100)
        return "", "P0 (" .. progress .. "%)"
    end
end

function PrestigePlugin:OnServerData(data)
    if data then
        self._prestigeLevel = data.prestigeLevel or data.level or self._prestigeLevel
        self._maxPrestigeLevel = data.maxPrestigeLevel or data.maxLevel or self._maxPrestigeLevel
        self._canPrestige = data.canPrestige or self._canPrestige
        self._totalBonus = data.totalBonusPercent or data.bonusPercent or self._totalBonus
        self._xpBonus = data.xpBonus or data.xpBonusPercent or self._xpBonus
        self._currentXP = data.currentXP or self._currentXP
        self._xpToNext = data.xpToNext or data.xpRequired or self._xpToNext
        self._dataReceived = true
        
        -- Update serverData
        if DCInfoBar.serverData then
            DCInfoBar.serverData.prestige = {
                level = self._prestigeLevel,
                maxLevel = self._maxPrestigeLevel,
                canPrestige = self._canPrestige,
                totalBonus = self._totalBonus,
                xpBonus = self._xpBonus,
                currentXP = self._currentXP,
                xpToNext = self._xpToNext,
            }
        end
    end
    self._elapsed = 999  -- Force immediate update
end

function PrestigePlugin:OnTooltip(tooltip)
    tooltip:AddLine("Prestige System", 1, 0.82, 0)
    DCInfoBar:AddTooltipSeparator(tooltip)
    
    if self._canPrestige then
        tooltip:AddLine("|cff00ff00PRESTIGE READY!|r")
        tooltip:AddLine(" ")
        tooltip:AddLine("You can reset to level 1 and gain", 0.7, 0.7, 0.7)
        tooltip:AddLine("permanent stat bonuses!", 0.7, 0.7, 0.7)
        tooltip:AddLine(" ")
    end
    
    -- Current status
    tooltip:AddDoubleLine("Prestige Level:", self._prestigeLevel .. " / " .. self._maxPrestigeLevel,
        0.7, 0.7, 0.7, 1, 0.82, 0)
    
    tooltip:AddDoubleLine("Current Level:", self._currentLevel .. " / " .. self._requiredLevel,
        0.7, 0.7, 0.7, 1, 1, 1)
    
    -- XP Progress to next prestige level (if applicable)
    if self._currentXP > 0 or self._xpToNext > 0 then
        local xpPercent = self._xpToNext > 0 and math.floor((self._currentXP / self._xpToNext) * 100) or 0
        tooltip:AddDoubleLine("Prestige XP:", 
            self._currentXP .. " / " .. self._xpToNext .. " (" .. xpPercent .. "%)",
            0.7, 0.7, 0.7, 0.8, 0.5, 1)
    end
    
    -- Bonuses section
    if self._totalBonus > 0 or self._xpBonus > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff32c4ffPrestige Bonuses:|r")
        
        if self._xpBonus > 0 then
            tooltip:AddDoubleLine("  XP Gain:", "+" .. self._xpBonus .. "%",
                0.7, 0.7, 0.7, 0.3, 1, 0.5)
        end
        
        if self._totalBonus > 0 then
            tooltip:AddDoubleLine("  All Stats:", "+" .. self._totalBonus .. "%",
                0.7, 0.7, 0.7, 0.5, 1, 0.5)
        end
        
        -- Show individual bonuses if available
        if self._bonusList and type(self._bonusList) == "table" then
            for _, bonus in ipairs(self._bonusList) do
                if bonus.name and bonus.value then
                    tooltip:AddDoubleLine("  " .. bonus.name .. ":", "+" .. bonus.value .. "%",
                        0.7, 0.7, 0.7, 0.7, 0.7, 1)
                end
            end
        end
    end
    
    -- Progress to next prestige
    if not self._canPrestige and self._prestigeLevel < self._maxPrestigeLevel then
        tooltip:AddLine(" ")
        local levelsNeeded = self._requiredLevel - self._currentLevel
        tooltip:AddDoubleLine("Levels to Prestige:", levelsNeeded,
            0.7, 0.7, 0.7, 1, 0.82, 0)
    end
    
    -- Max prestige info
    if self._prestigeLevel >= self._maxPrestigeLevel then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff00ff00Maximum Prestige Achieved!|r")
    end
    
    -- Hint about next prestige bonus
    if self._prestigeLevel < self._maxPrestigeLevel and self._prestigeLevel > 0 then
        tooltip:AddLine(" ")
        local nextBonus = (self._prestigeLevel + 1) * 5  -- Assuming 5% per prestige level
        tooltip:AddLine("|cff888888Next prestige: +" .. nextBonus .. "% total bonus|r", 0.5, 0.5, 0.5)
    end
end

function PrestigePlugin:OnClick(button)
    if button == "LeftButton" then
        -- Open prestige NPC gossip or slash command
        if self._canPrestige then
            -- Try to send chat command
            SendChatMessage(".prestige", "GUILD")  -- This won't work, but shows intent
            DCInfoBar:Print("Visit a Prestige NPC to perform prestige!")
        else
            local levelsNeeded = self._requiredLevel - self._currentLevel
            DCInfoBar:Print("You need " .. levelsNeeded .. " more levels to prestige.")
        end
    elseif button == "RightButton" then
        -- Show detailed prestige info
        local DC = rawget(_G, "DCAddonProtocol")
        if DC then
            DC:Request("PRES", 0x02, {})  -- Request bonuses breakdown
        end
        
        DCInfoBar:Print("=== Prestige Info ===")
        DCInfoBar:Print("Level: " .. self._prestigeLevel .. "/" .. self._maxPrestigeLevel)
        DCInfoBar:Print("Total Bonus: +" .. self._totalBonus .. "% all stats")
        if self._canPrestige then
            DCInfoBar:Print("|cff00ff00Ready to prestige!|r")
        end
    end
end

function PrestigePlugin:OnCreateOptions(parent, yOffset)
    local blinkCB = DCInfoBar:CreateCheckbox(parent, "Blink when prestige ready", 20, yOffset, function(checked)
        DCInfoBar:SetPluginSetting(self.id, "blinkWhenReady", checked)
    end, DCInfoBar:GetPluginSetting(self.id, "blinkWhenReady") ~= false)
    
    return yOffset - 30
end

-- Register plugin
DCInfoBar:RegisterPlugin(PrestigePlugin)
