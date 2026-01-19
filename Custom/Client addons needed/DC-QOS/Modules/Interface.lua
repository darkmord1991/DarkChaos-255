-- ============================================================
-- DC-QoS: Interface Module
-- ============================================================
-- Interface and UI enhancements
-- Adapted from Leatrix Plus for WoW 3.3.5a compatibility
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local Interface = {
    displayName = "Interface",
    settingKey = "interface",
    icon = "Interface\\Icons\\INV_Misc_EngGizmos_01",
}

-- Event frames storage for cleanup (must be defined before functions that use it)
local eventFrames = {}

-- ============================================================
-- Combat Nameplates
-- ============================================================
local function SetupCombatPlates()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.combatPlates then return end
    
    local frame = CreateFrame("Frame")
    table.insert(eventFrames, frame)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Enter combat
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leave combat
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            SetCVar("nameplateShowEnemies", 1)
        else
            SetCVar("nameplateShowEnemies", 0)
        end
    end)
    
    -- Set initial state based on current combat status
    if UnitAffectingCombat("player") then
        SetCVar("nameplateShowEnemies", 1)
    else
        SetCVar("nameplateShowEnemies", 0)
    end
end

-- ============================================================
-- Auto Quest Watch
-- ============================================================
local function SetupAutoQuestWatch()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.autoQuestWatch then return end
    
    local frame = CreateFrame("Frame")
    table.insert(eventFrames, frame)
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:SetScript("OnEvent", function(self, event, questLogIndex, questId)
        if questLogIndex then
            AddQuestWatch(questLogIndex)
        end
    end)
end

-- ============================================================
-- Quest Level Text
-- ============================================================
local function SetupQuestLevelText()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.questLevelText then return end
    
    -- Hook the quest log title button update
    hooksecurefunc("QuestLog_Update", function()
        local numQuests = QUESTS_DISPLAYED or 6
        for i = 1, numQuests do
            local questLogTitle = _G["QuestLogTitle" .. i]
            if questLogTitle then
                local questIndex = questLogTitle:GetID()
                local title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questIndex)
                
                if title and not isHeader then
                    local levelColor = GetQuestDifficultyColor(level)
                    local newTitle = string.format("[%d] %s", level, title)
                    questLogTitle:SetText(newTitle)
                    questLogTitle:SetNormalFontObject("GameFontNormal")
                end
            end
        end
    end)
end

-- ============================================================
-- Hide Gryphons (MainMenuBar art)
-- ============================================================
local function SetupHideGryphons()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.hideGryphons then return end
    
    if MainMenuBarLeftEndCap then
        MainMenuBarLeftEndCap:Hide()
    end
    if MainMenuBarRightEndCap then
        MainMenuBarRightEndCap:Hide()
    end
end

-- ============================================================
-- Larger World Map
-- ============================================================
local function SetupLargerWorldMap()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.largerWorldMap then return end
    
    -- Make world map movable and resizable
    WorldMapFrame:SetMovable(true)
    WorldMapFrame:EnableMouse(true)
    WorldMapFrame:RegisterForDrag("LeftButton")
    WorldMapFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    WorldMapFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

-- ============================================================
-- Buff/Aura Frame Position
-- ============================================================
local function SetupBuffFramePosition()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.buffFrameMove then return end

    local x = settings.buffFrameOffsetX or 0
    local y = settings.buffFrameOffsetY or 0

    local function ApplyPosition()
        if InCombatLockdown() then return end
        
        if BuffFrame then
            -- Make it movable and prevent Blizzard from overriding
            BuffFrame:SetMovable(true)
            BuffFrame:SetUserPlaced(true)
            BuffFrame:ClearAllPoints()
            BuffFrame:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", x, y)
            
            -- Hook to prevent repositioning
            if not BuffFrame._dcqosHooked then
                BuffFrame._dcqosHooked = true
                hooksecurefunc(BuffFrame, "SetPoint", function(self, ...)
                    if self._dcqosRepositioning then return end
                    self._dcqosRepositioning = true
                    self:ClearAllPoints()
                    self:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", x, y)
                    self._dcqosRepositioning = nil
                end)
            end
        end

        if TemporaryEnchantFrame then
            TemporaryEnchantFrame:ClearAllPoints()
            TemporaryEnchantFrame:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", x, y)
        end
    end
    
    -- Use a frame to handle positioning after combat/loading
    local positioner = CreateFrame("Frame")
    positioner:RegisterEvent("PLAYER_ENTERING_WORLD")
    positioner:RegisterEvent("PLAYER_REGEN_ENABLED")
    positioner:SetScript("OnEvent", ApplyPosition)
    
    -- Apply immediately if not in combat
    if not InCombatLockdown() then
        ApplyPosition()
    end
    
    -- Also try after a short delay for late-loading UI
    addon:DelayedCall(0.5, ApplyPosition)
    addon:DelayedCall(2.0, ApplyPosition)
end

-- ============================================================
-- Enhanced Minimap
-- ============================================================
local function SetupEnhancedMinimap()
    -- Allow scrolling to zoom minimap
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            MinimapZoomIn:Click()
        else
            MinimapZoomOut:Click()
        end
    end)
    
    -- Hide minimap zoom buttons
    MinimapZoomIn:Hide()
    MinimapZoomOut:Hide()
end

-- ============================================================
-- Player Frame Offset
-- ============================================================
local function SetupPlayerFrameOffset()
    local settings = addon.settings.interface
    if not settings.enabled then return end
    
    local yOffset = settings.playerFrameOffsetY or -3
    
    local function ApplyOffset()
        if InCombatLockdown() then return end
        if not PlayerFrame then return end
        
        -- Get current position and nudge down
        local point, relativeTo, relativePoint, x, y = PlayerFrame:GetPoint()
        if point then
            PlayerFrame:ClearAllPoints()
            PlayerFrame:SetPoint(point, relativeTo, relativePoint, x, (y or 0) + yOffset)
        end
    end
    
    -- Apply after UI loads
    addon:DelayedCall(0.5, ApplyOffset)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function Interface.OnInitialize()
    addon:Debug("Interface module initializing")
end

function Interface.OnEnable()
    addon:Debug("Interface module enabling")
    
    SetupCombatPlates()
    SetupAutoQuestWatch()
    SetupQuestLevelText()
    SetupHideGryphons()
    SetupLargerWorldMap()
    if not (addon.settings.minimap and addon.settings.minimap.enabled) then
        SetupEnhancedMinimap()
    end
    SetupBuffFramePosition()
    SetupPlayerFrameOffset()
end

function Interface.OnDisable()
    addon:Debug("Interface module disabling")
    -- Unregister all event frames to clean up
    for _, frame in ipairs(eventFrames) do
        if frame and frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
            frame:SetScript("OnEvent", nil)
        end
    end
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function Interface.CreateSettings(parent)
    local settings = addon.settings.interface
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Interface Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Configure interface enhancements and UI modifications.")
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    
    local yOffset = -70
    
    -- ============================================================
    -- Combat Section
    -- ============================================================
    local combatHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    combatHeader:SetPoint("TOPLEFT", 16, yOffset)
    combatHeader:SetText("Combat")
    yOffset = yOffset - 25
    
    -- Combat Nameplates
    local combatPlatesCb = addon:CreateCheckbox(parent)
    combatPlatesCb:SetPoint("TOPLEFT", 16, yOffset)
    combatPlatesCb.Text:SetText("Show Enemy Nameplates in Combat Only")
    combatPlatesCb:SetChecked(settings.combatPlates)
    combatPlatesCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.combatPlates", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Quest Section
    -- ============================================================
    local questHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    questHeader:SetPoint("TOPLEFT", 16, yOffset)
    questHeader:SetText("Quests")
    yOffset = yOffset - 25
    
    -- Auto Quest Watch
    local autoQuestCb = addon:CreateCheckbox(parent)
    autoQuestCb:SetPoint("TOPLEFT", 16, yOffset)
    autoQuestCb.Text:SetText("Auto-add Quests to Watch List")
    autoQuestCb:SetChecked(settings.autoQuestWatch)
    autoQuestCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.autoQuestWatch", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 25

    -- ============================================================
    -- Buff/Aura Frame Section
    -- ============================================================
    local auraHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    auraHeader:SetPoint("TOPLEFT", 16, yOffset)
    auraHeader:SetText("Buff/Aura Frame")
    yOffset = yOffset - 25

    local moveBuffCb = addon:CreateCheckbox(parent)
    moveBuffCb:SetPoint("TOPLEFT", 16, yOffset)
    moveBuffCb.Text:SetText("Move Buff/Aura frame")
    moveBuffCb:SetChecked(settings.buffFrameMove)
    moveBuffCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.buffFrameMove", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 30

    local offsetXSlider = addon:CreateSlider(parent)
    offsetXSlider:SetPoint("TOPLEFT", 16, yOffset)
    offsetXSlider:SetWidth(200)
    offsetXSlider:SetMinMaxValues(-400, 200)
    offsetXSlider:SetValueStep(5)
    offsetXSlider.Text:SetText("Buff Frame X Offset")
    offsetXSlider.Low:SetText("-400")
    offsetXSlider.High:SetText("200")
    offsetXSlider:SetValue(settings.buffFrameOffsetX or 0)
    offsetXSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("interface.buffFrameOffsetX", math.floor(value + 0.5))
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 50

    local offsetYSlider = addon:CreateSlider(parent)
    offsetYSlider:SetPoint("TOPLEFT", 16, yOffset)
    offsetYSlider:SetWidth(200)
    offsetYSlider:SetMinMaxValues(-200, 200)
    offsetYSlider:SetValueStep(5)
    offsetYSlider.Text:SetText("Buff Frame Y Offset")
    offsetYSlider.Low:SetText("-200")
    offsetYSlider.High:SetText("200")
    offsetYSlider:SetValue(settings.buffFrameOffsetY or 0)
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("interface.buffFrameOffsetY", math.floor(value + 0.5))
        addon:PromptReloadUI()
    end)
    yOffset = yOffset - 50
    
    -- Quest Level Text
    local questLevelCb = addon:CreateCheckbox(parent)
    questLevelCb:SetPoint("TOPLEFT", 16, yOffset)
    questLevelCb.Text:SetText("Show Quest Levels in Quest Log")
    questLevelCb:SetChecked(settings.questLevelText)
    questLevelCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.questLevelText", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Appearance Section
    -- ============================================================
    local appearanceHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    appearanceHeader:SetPoint("TOPLEFT", 16, yOffset)
    appearanceHeader:SetText("Appearance")
    yOffset = yOffset - 25
    
    -- Hide Gryphons
    local hideGryphonsCb = addon:CreateCheckbox(parent)
    hideGryphonsCb:SetPoint("TOPLEFT", 16, yOffset)
    hideGryphonsCb.Text:SetText("Hide Action Bar Gryphons")
    hideGryphonsCb:SetChecked(settings.hideGryphons)
    hideGryphonsCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.hideGryphons", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 25
    
    -- Larger World Map
    local largerMapCb = addon:CreateCheckbox(parent)
    largerMapCb:SetPoint("TOPLEFT", 16, yOffset)
    largerMapCb.Text:SetText("Movable World Map")
    largerMapCb:SetChecked(settings.largerWorldMap)
    largerMapCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.largerWorldMap", self:GetChecked())
        addon:Print("Requires /reload to take effect", true)
    end)
    yOffset = yOffset - 35
    
    -- ============================================================
    -- Info Section
    -- ============================================================
    local infoHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", 16, yOffset)
    infoHeader:SetText("Minimap")
    yOffset = yOffset - 25
    
    local minimapInfo = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    minimapInfo:SetPoint("TOPLEFT", 16, yOffset)
    minimapInfo:SetText("• Mouse scroll to zoom minimap\n• Zoom buttons are automatically hidden")
    minimapInfo:SetTextColor(0.7, 0.7, 0.7)
    minimapInfo:SetJustifyH("LEFT")
    
    return yOffset - 60
end

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("Interface", Interface)
