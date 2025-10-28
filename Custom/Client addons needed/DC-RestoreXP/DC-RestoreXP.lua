-- DC-RestoreXP.lua
-- Blizzard-like XP bar replacement for servers with max level > 80 (up to 255)
-- Mimics MainMenuExpBar behavior exactly for WoW 3.3.5a

-------------------------------------------------------------------------------
-- Saved Variables
-------------------------------------------------------------------------------
if not DCRestoreXPDB then DCRestoreXPDB = {} end
if DCRestoreXPDB.maxLevel == nil then DCRestoreXPDB.maxLevel = 255 end
if DCRestoreXPDB.debug == nil then DCRestoreXPDB.debug = false end
if DCRestoreXPDB.enabled == nil then DCRestoreXPDB.enabled = true end

-------------------------------------------------------------------------------
-- Early Init Guard
-------------------------------------------------------------------------------
if _G.__DCRestoreXP_Initialized then return end
_G.__DCRestoreXP_Initialized = true

-------------------------------------------------------------------------------
-- Debug Helper (uses DC_DebugUtils if available for deduplication)
-------------------------------------------------------------------------------
local function Debug(...)
    local isEnabled = (DCRestoreXPDB and DCRestoreXPDB.debug)
    
    -- Use DC_DebugUtils if available for deduplication
    if _G.DC_DebugUtils and type(_G.DC_DebugUtils.PrintMulti) == 'function' then
        _G.DC_DebugUtils:PrintMulti("DC-RestoreXP", isEnabled, ...)
    else
        -- Fallback to old method if DC_DebugUtils not loaded
        if not isEnabled then return end
        local parts = {}
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            parts[#parts + 1] = (v == nil) and "nil" or tostring(v)
        end
        local msg = table.concat(parts, " ")
        if DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFFDCRestoreXP:|r " .. msg)
        end
    end
end

-------------------------------------------------------------------------------
-- Find Blizzard's XP Bar
-------------------------------------------------------------------------------
local function FindBlizzardXPBar()
    local names = { "MainMenuExpBar", "MainMenuXPBar", "MainMenuBarExpBar" }
    for _, n in ipairs(names) do
        local f = _G[n]
        if f and type(f) == "table" and type(f.SetMinMaxValues) == "function" then
            return f
        end
    end
    return nil
end

local BlizzardXPBar = FindBlizzardXPBar()

-------------------------------------------------------------------------------
-- XP Bar State
-------------------------------------------------------------------------------
local addonXPBar = nil
local currentLevel = UnitLevel("player") or 1

-------------------------------------------------------------------------------
-- Check if player is at max level
-------------------------------------------------------------------------------
local function IsAtMaxLevel()
    local level = UnitLevel("player") or 1
    local maxLevel = (DCRestoreXPDB and DCRestoreXPDB.maxLevel) or 255
    return level >= maxLevel
end

-------------------------------------------------------------------------------
-- Get XP color based on rested state (mimics Blizzard)
-------------------------------------------------------------------------------
local function GetXPBarColor()
    local restState = GetRestState()
    local exhaustionThreshold = GetXPExhaustion()
    
    -- Rested (blue): restState == 1 and has rested XP
    if restState == 1 and exhaustionThreshold and exhaustionThreshold > 0 then
        return 0.0, 0.39, 0.88, 1.0  -- Blizzard rested blue
    end
    
    -- Normal (purple): default XP color
    return 0.58, 0.0, 0.55, 1.0  -- Blizzard purple
end

-------------------------------------------------------------------------------
-- Create Custom XP Bar (mimics MainMenuExpBar exactly)
-------------------------------------------------------------------------------
local function CreateXPBar()
    if addonXPBar then return addonXPBar end
    
    -- Create status bar
    local bar = CreateFrame("StatusBar", "DCRestoreXPBar", UIParent)
    bar:SetSize(1024, 13)  -- Match Blizzard MainMenuExpBar size
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)  -- Same position as Blizzard bar
    bar:SetFrameStrata("LOW")
    bar:SetFrameLevel(1)
    
    -- Status bar texture
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local r, g, b, a = GetXPBarColor()
    bar:SetStatusBarColor(r, g, b, a)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    
    -- Background
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.5)
    bar.bg = bg
    
    -- XP Text
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    text:SetText("")
    bar.text = text
    
    -- Rested overlay (shows rested XP region)
    local rested = bar:CreateTexture(nil, "OVERLAY")
    rested:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    rested:SetPoint("LEFT", bar, "LEFT")
    rested:SetHeight(13)
    rested:SetWidth(0)
    rested:SetVertexColor(0.0, 0.39, 0.88, 0.25)
    rested:Hide()
    bar.rested = rested
    
    -- Exhaustion tick (marker showing where rested XP ends)
    local tick = CreateFrame("Frame", "DCRestoreXP_ExhaustionTick", bar)
    tick:SetSize(32, 32)
    tick:SetPoint("CENTER", bar, "LEFT", 0, 0)
    local tickTex = tick:CreateTexture(nil, "OVERLAY")
    tickTex:SetTexture("Interface\\MainMenuBar\\UI-ExhaustionTickNormal")
    tickTex:SetAllPoints(tick)
    tick:Hide()
    bar.exhaustionTick = tick
    
    -- Add Blizzard MainMenuBar decorative slices (4 overlay textures)
    local sliceFile = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
    local slices = {
        { offset = -384, texCoords = { 0, 1.0, 0.79296875, 0.83203125 } },
        { offset = -128, texCoords = { 0, 1.0, 0.54296875, 0.58203125 } },
        { offset = 128,  texCoords = { 0, 1.0, 0.29296875, 0.33203125 } },
        { offset = 384,  texCoords = { 0, 1.0, 0.04296875, 0.08203125 } },
    }
    for _, slice in ipairs(slices) do
        local tex = bar:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(sliceFile)
        tex:SetSize(256, 10)
        tex:SetPoint("BOTTOM", bar, "BOTTOM", slice.offset, 3)
        tex:SetTexCoord(unpack(slice.texCoords))
    end
    
    bar:Hide()
    addonXPBar = bar
    Debug("Created custom XP bar")
    return bar
end

-------------------------------------------------------------------------------
-- Update XP Bar (handles both Blizzard and custom bar)
-------------------------------------------------------------------------------
local function UpdateXPBar()
    if not DCRestoreXPDB.enabled then
        if addonXPBar then addonXPBar:Hide() end
        if BlizzardXPBar then BlizzardXPBar:Show() end
        return
    end
    
    local level = UnitLevel("player") or 1
    currentLevel = level
    
    -- At max level: hide both bars
    if IsAtMaxLevel() then
        Debug("Player at max level " .. level .. ", hiding XP bar")
        if addonXPBar then addonXPBar:Hide() end
        if BlizzardXPBar then BlizzardXPBar:Hide() end
        return
    end
    
    local currentXP = UnitXP("player") or 0
    local maxXP = UnitXPMax("player") or 1
    local exhaustion = GetXPExhaustion() or 0
    
    Debug(string.format("Level %d: %d/%d XP, Rested: %d", level, currentXP, maxXP, exhaustion))
    
    -- Levels 1-79: Use Blizzard bar if it exists
    if level <= 79 and BlizzardXPBar then
        Debug("Level <= 79: using Blizzard XP bar")
        if addonXPBar then addonXPBar:Hide() end
        BlizzardXPBar:Show()
        -- Blizzard handles its own updates
        return
    end
    
    -- Levels 80+: Use custom bar (Blizzard hides at 80+)
    Debug("Level >= 80: using custom XP bar")
    if not addonXPBar then CreateXPBar() end
    if not addonXPBar then
        Debug("ERROR: Failed to create addon XP bar")
        return
    end
    
    -- Hide Blizzard bar if it exists
    if BlizzardXPBar then BlizzardXPBar:Hide() end
    
    -- Update bar values
    addonXPBar:SetMinMaxValues(0, maxXP)
    addonXPBar:SetValue(currentXP)
    
    -- Update colors based on rested state
    local r, g, b, a = GetXPBarColor()
    addonXPBar:SetStatusBarColor(r, g, b, a)
    if addonXPBar.bg then
        addonXPBar.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.5)
    end
    
    -- Update text
    local percent = (maxXP > 0) and ((currentXP / maxXP) * 100) or 0
    local textStr = string.format("Level %d: %d / %d XP (%.1f%%)", level, currentXP, maxXP, percent)
    if exhaustion > 0 then
        textStr = textStr .. string.format(" |cFF4080FF+%d rested|r", exhaustion)
    end
    if addonXPBar.text then
        addonXPBar.text:SetText(textStr)
    end
    
    -- Update rested overlay
    if exhaustion and exhaustion > 0 and maxXP > 0 then
        local restedEnd = currentXP + exhaustion
        if restedEnd > maxXP then restedEnd = maxXP end
        local restedWidth = ((restedEnd - currentXP) / maxXP) * (addonXPBar:GetWidth() or 1024)
        
        if addonXPBar.rested then
            addonXPBar.rested:SetWidth(restedWidth)
            addonXPBar.rested:SetPoint("LEFT", addonXPBar, "LEFT", (currentXP / maxXP) * (addonXPBar:GetWidth() or 1024), 0)
            addonXPBar.rested:Show()
        end
        
        -- Position exhaustion tick
        if addonXPBar.exhaustionTick then
            local tickPos = (restedEnd / maxXP) * (addonXPBar:GetWidth() or 1024)
            addonXPBar.exhaustionTick:ClearAllPoints()
            addonXPBar.exhaustionTick:SetPoint("CENTER", addonXPBar, "LEFT", tickPos, 0)
            addonXPBar.exhaustionTick:Show()
        end
    else
        if addonXPBar.rested then addonXPBar.rested:Hide() end
        if addonXPBar.exhaustionTick then addonXPBar.exhaustionTick:Hide() end
    end
    
    addonXPBar:Show()
    Debug("Updated addon XP bar: " .. textStr)
end

-------------------------------------------------------------------------------
-- Event Handler
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    Debug("Event: " .. tostring(event))
    
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Small delay to ensure unit data is available
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(0.5, UpdateXPBar)
        else
            -- Fallback for older clients
            local delayFrame = CreateFrame("Frame")
            local elapsed = 0
            delayFrame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed >= 0.5 then
                    self:SetScript("OnUpdate", nil)
                    UpdateXPBar()
                end
            end)
        end
    else
        UpdateXPBar()
    end
end)

-------------------------------------------------------------------------------
-- Interface Options Panel
-------------------------------------------------------------------------------
local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "DCRestoreXPOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "DC-RestoreXP"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DC-RestoreXP")
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(580)
    desc:SetJustifyH("LEFT")
    desc:SetText("Restores XP bar functionality for servers with max level above 80. Mimics Blizzard's MainMenuExpBar exactly.")
    
    -- Enable checkbox
    local enableCB = CreateFrame("CheckButton", "DCRestoreXP_EnableCB", panel, "UICheckButtonTemplate")
    enableCB:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    _G[enableCB:GetName() .. "Text"]:SetText("Enable addon XP bar")
    enableCB:SetChecked(DCRestoreXPDB.enabled)
    enableCB:SetScript("OnClick", function(self)
        DCRestoreXPDB.enabled = self:GetChecked()
        UpdateXPBar()
    end)
    
    -- Max level slider
    local maxLevelSlider = CreateFrame("Slider", "DCRestoreXP_MaxLevelSlider", panel, "OptionsSliderTemplate")
    maxLevelSlider:SetPoint("TOPLEFT", enableCB, "BOTTOMLEFT", 8, -32)
    maxLevelSlider:SetMinMaxValues(80, 255)
    maxLevelSlider:SetValue(DCRestoreXPDB.maxLevel)
    maxLevelSlider:SetValueStep(1)
    -- Note: SetObeyStepOnDrag doesn't exist in 3.3.5a, removed (slider still steps via SetValueStep)
    maxLevelSlider:SetWidth(300)
    _G[maxLevelSlider:GetName() .. "Low"]:SetText("80")
    _G[maxLevelSlider:GetName() .. "High"]:SetText("255")
    _G[maxLevelSlider:GetName() .. "Text"]:SetText("Server Max Level: " .. DCRestoreXPDB.maxLevel)
    maxLevelSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        DCRestoreXPDB.maxLevel = value
        _G[self:GetName() .. "Text"]:SetText("Server Max Level: " .. value)
        UpdateXPBar()
    end)
    
    -- Debug checkbox
    local debugCB = CreateFrame("CheckButton", "DCRestoreXP_DebugCB", panel, "UICheckButtonTemplate")
    debugCB:SetPoint("TOPLEFT", maxLevelSlider, "BOTTOMLEFT", -8, -24)
    _G[debugCB:GetName() .. "Text"]:SetText("Enable debug messages")
    debugCB:SetChecked(DCRestoreXPDB.debug)
    debugCB:SetScript("OnClick", function(self)
        DCRestoreXPDB.debug = self:GetChecked()
    end)
    
    -- Refresh function
    panel.refresh = function()
        enableCB:SetChecked(DCRestoreXPDB.enabled)
        maxLevelSlider:SetValue(DCRestoreXPDB.maxLevel)
        _G[maxLevelSlider:GetName() .. "Text"]:SetText("Server Max Level: " .. DCRestoreXPDB.maxLevel)
        debugCB:SetChecked(DCRestoreXPDB.debug)
    end
    
    InterfaceOptions_AddCategory(panel)
    return panel
end

-- Create options panel on load
if type(InterfaceOptions_AddCategory) == "function" then
    CreateOptionsPanel()
else
    -- Delay creation if Interface API not ready
    local regFrame = CreateFrame("Frame")
    regFrame:RegisterEvent("PLAYER_LOGIN")
    regFrame:SetScript("OnEvent", function()
        if type(InterfaceOptions_AddCategory) == "function" then
            CreateOptionsPanel()
            regFrame:UnregisterAllEvents()
        end
    end)
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
SLASH_DCRXP1 = "/dcrxp"
SlashCmdList["DCRXP"] = function(msg)
    msg = (msg or ""):lower():trim()
    
    if msg == "" or msg == "help" then
        print("|cFF00FFFFDCRestoreXP Commands:|r")
        print("  /dcrxp options - Open settings")
        print("  /dcrxp enable - Enable addon")
        print("  /dcrxp disable - Disable addon")
        print("  /dcrxp debug on|off - Toggle debug")
        print("  /dcrxp status - Show current status")
    elseif msg == "options" then
        if InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory("DC-RestoreXP")
        end
    elseif msg == "enable" then
        DCRestoreXPDB.enabled = true
        UpdateXPBar()
        print("|cFF00FFFFDCRestoreXP:|r Enabled")
    elseif msg == "disable" then
        DCRestoreXPDB.enabled = false
        if addonXPBar then addonXPBar:Hide() end
        if BlizzardXPBar then BlizzardXPBar:Show() end
        print("|cFF00FFFFDCRestoreXP:|r Disabled")
    elseif msg == "debug on" then
        DCRestoreXPDB.debug = true
        print("|cFF00FFFFDCRestoreXP:|r Debug enabled")
    elseif msg == "debug off" then
        DCRestoreXPDB.debug = false
        print("|cFF00FFFFDCRestoreXP:|r Debug disabled")
    elseif msg == "status" then
        print("|cFF00FFFFDCRestoreXP Status:|r")
        print("  Enabled: " .. tostring(DCRestoreXPDB.enabled))
        print("  Max Level: " .. DCRestoreXPDB.maxLevel)
        print("  Current Level: " .. (UnitLevel("player") or 0))
        print("  Debug: " .. tostring(DCRestoreXPDB.debug))
        print("  Blizzard Bar Found: " .. tostring(BlizzardXPBar ~= nil))
        print("  Custom Bar Created: " .. tostring(addonXPBar ~= nil))
    else
        print("|cFF00FFFFDCRestoreXP:|r Unknown command. Use '/dcrxp help'")
    end
end

-------------------------------------------------------------------------------
-- Initialize saved variables after addon loads
-------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DC-RestoreXP" then
        -- Initialize saved variables with defaults
        if not DCRestoreXPDB then DCRestoreXPDB = {} end
        if DCRestoreXPDB.maxLevel == nil then DCRestoreXPDB.maxLevel = 255 end
        if DCRestoreXPDB.debug == nil then DCRestoreXPDB.debug = false end
        if DCRestoreXPDB.enabled == nil then DCRestoreXPDB.enabled = true end
        Debug("DC-RestoreXP initialized: maxLevel=" .. DCRestoreXPDB.maxLevel)
    elseif event == "PLAYER_LOGIN" then
        -- Delayed initial update after player fully loaded
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(1.0, UpdateXPBar)
        else
            local elapsed = 0
            local updateFrame = CreateFrame("Frame")
            updateFrame:SetScript("OnUpdate", function(selfUpdate, dt)
                elapsed = elapsed + dt
                if elapsed >= 1.0 then
                    selfUpdate:SetScript("OnUpdate", nil)
                    UpdateXPBar()
                end
            end)
        end
    end
end)

Debug("DC-RestoreXP loaded successfully")
