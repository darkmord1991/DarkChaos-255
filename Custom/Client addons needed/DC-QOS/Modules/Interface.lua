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
local zoomSettingHookRegistered = false
local questLevelHookRegistered = false

local combatPlatesState = { active = false, previousShowEnemies = nil }
local gryphonState = { active = false, leftShown = nil, rightShown = nil }
local worldMapState = { active = false, movable = nil, mouseEnabled = nil, onDragStart = nil, onDragStop = nil }
local minimapState = { active = false, mouseWheelEnabled = nil, onMouseWheel = nil, zoomInShown = nil, zoomOutShown = nil }
local cameraZoomState = { active = false, previousMaxFactor = nil }
local buffFrameState = {
    active = false,
    hookInstalled = false,
    pendingRestore = false,
    restoreFrame = nil,
    offsetX = 0,
    offsetY = 0,
    buffPoint = nil,
    tempEnchantPoint = nil,
}

local function GetManagedEventFrame(key)
    if not eventFrames[key] then
        eventFrames[key] = CreateFrame("Frame")
    end
    return eventFrames[key]
end

local function CapturePoint(frame)
    if not frame or not frame.GetPoint then
        return nil
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    if not point then
        return nil
    end

    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x or 0,
        y = y or 0,
    }
end

local function RestorePoint(frame, pointData)
    if not frame or not pointData then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        pointData.point,
        pointData.relativeTo,
        pointData.relativePoint,
        pointData.x or 0,
        pointData.y or 0
    )
end

local function SafeSetCVar(name, value)
    if type(SetCVar) ~= "function" then
        return false
    end

    local ok = pcall(SetCVar, name, value)
    return ok and true or false
end

local function GetClampedZoomFactor(value)
    local zoom = tonumber(value) or 4
    if zoom < 1 then
        zoom = 1
    elseif zoom > 4 then
        zoom = 4
    end
    return math.floor((zoom * 10) + 0.5) / 10
end

-- ============================================================
-- Combat Nameplates
-- ============================================================
local function SetupCombatPlates()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.combatPlates then return end

    if not combatPlatesState.active and type(GetCVar) == "function" then
        combatPlatesState.previousShowEnemies = GetCVar("nameplateShowEnemies")
    end
    combatPlatesState.active = true

    local frame = GetManagedEventFrame("combatPlates")
    frame:UnregisterAllEvents()
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Enter combat
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leave combat
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            SafeSetCVar("nameplateShowEnemies", "1")
        else
            SafeSetCVar("nameplateShowEnemies", "0")
        end
    end)
    
    -- Set initial state based on current combat status
    if UnitAffectingCombat("player") then
        SafeSetCVar("nameplateShowEnemies", "1")
    else
        SafeSetCVar("nameplateShowEnemies", "0")
    end
end

-- ============================================================
-- Auto Quest Watch
-- ============================================================
local function SetupAutoQuestWatch()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.autoQuestWatch then return end

    local frame = GetManagedEventFrame("autoQuestWatch")
    frame:UnregisterAllEvents()
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
    if questLevelHookRegistered then return end
    questLevelHookRegistered = true

    -- Hook the quest log title button update
    hooksecurefunc("QuestLog_Update", function()
        local settings = addon.settings and addon.settings.interface
        if not settings or not settings.enabled or not settings.questLevelText then
            return
        end

        local numQuests = QUESTS_DISPLAYED or 6
        for i = 1, numQuests do
            local questLogTitle = _G["QuestLogTitle" .. i]
            if questLogTitle then
                local questIndex = questLogTitle:GetID()
                local title, level, tag, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(questIndex)

                if title and not isHeader then
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

    if not gryphonState.active then
        if MainMenuBarLeftEndCap and MainMenuBarLeftEndCap.IsShown then
            gryphonState.leftShown = MainMenuBarLeftEndCap:IsShown()
        end
        if MainMenuBarRightEndCap and MainMenuBarRightEndCap.IsShown then
            gryphonState.rightShown = MainMenuBarRightEndCap:IsShown()
        end
    end
    gryphonState.active = true
    
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

    if not WorldMapFrame then
        return
    end

    if not worldMapState.active then
        worldMapState.active = true
        worldMapState.movable = WorldMapFrame.IsMovable and WorldMapFrame:IsMovable() or false
        worldMapState.mouseEnabled = WorldMapFrame.IsMouseEnabled and WorldMapFrame:IsMouseEnabled() or true
        worldMapState.onDragStart = WorldMapFrame.GetScript and WorldMapFrame:GetScript("OnDragStart") or nil
        worldMapState.onDragStop = WorldMapFrame.GetScript and WorldMapFrame:GetScript("OnDragStop") or nil
    end
    
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
local function ApplyBuffFramePosition()
    if InCombatLockdown() then return end

    if BuffFrame then
        if not buffFrameState.buffPoint then
            buffFrameState.buffPoint = CapturePoint(BuffFrame)
        end

        BuffFrame:SetMovable(true)
        BuffFrame:SetUserPlaced(true)
        BuffFrame._dcqosRepositioning = true
        BuffFrame:ClearAllPoints()
        BuffFrame:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", buffFrameState.offsetX, buffFrameState.offsetY)
        BuffFrame._dcqosRepositioning = nil

        if not buffFrameState.hookInstalled then
            buffFrameState.hookInstalled = true
            hooksecurefunc(BuffFrame, "SetPoint", function(self, ...)
                if not buffFrameState.active or self._dcqosRepositioning then return end
                self._dcqosRepositioning = true
                self:ClearAllPoints()
                self:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", buffFrameState.offsetX, buffFrameState.offsetY)
                self._dcqosRepositioning = nil
            end)
        end
    end

    if TemporaryEnchantFrame then
        if not buffFrameState.tempEnchantPoint then
            buffFrameState.tempEnchantPoint = CapturePoint(TemporaryEnchantFrame)
        end

        TemporaryEnchantFrame:ClearAllPoints()
        TemporaryEnchantFrame:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", buffFrameState.offsetX, buffFrameState.offsetY)
    end
end

local function RestoreBuffFramePosition()
    if InCombatLockdown() then
        buffFrameState.pendingRestore = true
        if not buffFrameState.restoreFrame then
            buffFrameState.restoreFrame = CreateFrame("Frame")
        end
        buffFrameState.restoreFrame:UnregisterAllEvents()
        buffFrameState.restoreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        buffFrameState.restoreFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
            RestoreBuffFramePosition()
        end)
        return false
    end

    buffFrameState.pendingRestore = false
    if buffFrameState.restoreFrame then
        buffFrameState.restoreFrame:UnregisterAllEvents()
        buffFrameState.restoreFrame:SetScript("OnEvent", nil)
    end

    if BuffFrame then
        BuffFrame._dcqosRepositioning = true
        RestorePoint(BuffFrame, buffFrameState.buffPoint)
        BuffFrame._dcqosRepositioning = nil
        if BuffFrame.SetUserPlaced then
            BuffFrame:SetUserPlaced(false)
        end
    end

    if TemporaryEnchantFrame then
        RestorePoint(TemporaryEnchantFrame, buffFrameState.tempEnchantPoint)
    end

    return true
end

local function SetupBuffFramePosition()
    local settings = addon.settings.interface
    if not settings.enabled or not settings.buffFrameMove then return end

    buffFrameState.active = true
    buffFrameState.pendingRestore = false
    if buffFrameState.restoreFrame then
        buffFrameState.restoreFrame:UnregisterAllEvents()
        buffFrameState.restoreFrame:SetScript("OnEvent", nil)
    end
    buffFrameState.offsetX = settings.buffFrameOffsetX or 0
    buffFrameState.offsetY = settings.buffFrameOffsetY or 0

    -- Use a frame to handle positioning after combat/loading
    local positioner = GetManagedEventFrame("buffPositioner")
    positioner:UnregisterAllEvents()
    positioner:RegisterEvent("PLAYER_ENTERING_WORLD")
    positioner:RegisterEvent("PLAYER_REGEN_ENABLED")
    positioner:SetScript("OnEvent", ApplyBuffFramePosition)
    
    -- Apply immediately if not in combat
    if not InCombatLockdown() then
        ApplyBuffFramePosition()
    end
    
    -- Also try after a short delay for late-loading UI
    addon:DelayedCall(0.5, ApplyBuffFramePosition)
    addon:DelayedCall(2.0, ApplyBuffFramePosition)
end

-- ============================================================
-- Enhanced Minimap
-- ============================================================
local function SetupEnhancedMinimap()
    if not Minimap then
        return
    end

    if not minimapState.active then
        minimapState.active = true
        minimapState.mouseWheelEnabled = Minimap.IsMouseWheelEnabled and Minimap:IsMouseWheelEnabled() or false
        minimapState.onMouseWheel = Minimap.GetScript and Minimap:GetScript("OnMouseWheel") or nil
        minimapState.zoomInShown = MinimapZoomIn and MinimapZoomIn.IsShown and MinimapZoomIn:IsShown() or false
        minimapState.zoomOutShown = MinimapZoomOut and MinimapZoomOut.IsShown and MinimapZoomOut:IsShown() or false
    end

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
-- Camera Zoom Distance
-- ============================================================
local function ApplyCameraZoomDistance()
    local settings = addon.settings.interface
    if not settings or not settings.enabled then return end

    if settings.extendedCameraZoom then
        local zoomFactor = GetClampedZoomFactor(settings.maxZoomFactor)
        SafeSetCVar("cameraDistanceMaxFactor", tostring(zoomFactor))
    else
        SafeSetCVar("cameraDistanceMaxFactor", "1")
    end
end

local function SetupCameraZoomDistance()
    local settings = addon.settings.interface
    if not settings or not settings.enabled then return end

    if not cameraZoomState.active and type(GetCVar) == "function" then
        cameraZoomState.previousMaxFactor = GetCVar("cameraDistanceMaxFactor")
    end
    cameraZoomState.active = true

    ApplyCameraZoomDistance()

    local frame = GetManagedEventFrame("cameraZoom")
    frame:UnregisterAllEvents()
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
        ApplyCameraZoomDistance()
    end)

    addon:DelayedCall(1.0, ApplyCameraZoomDistance)

    if not zoomSettingHookRegistered then
        zoomSettingHookRegistered = true
        addon:RegisterEvent("SETTING_CHANGED", function(path)
            if path == "interface.enabled" or path == "interface.extendedCameraZoom" or path == "interface.maxZoomFactor" then
                ApplyCameraZoomDistance()
            end
        end)
    end
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
    SetupCameraZoomDistance()
    SetupBuffFramePosition()
    SetupPlayerFrameOffset()
end

function Interface.OnDisable()
    addon:Debug("Interface module disabling")
    -- Unregister all event frames to clean up
    for _, frame in pairs(eventFrames) do
        if frame and frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
            frame:SetScript("OnEvent", nil)
        end
    end

    if combatPlatesState.active then
        SafeSetCVar("nameplateShowEnemies", tostring(combatPlatesState.previousShowEnemies or "0"))
        combatPlatesState.active = false
        combatPlatesState.previousShowEnemies = nil
    end

    if cameraZoomState.active then
        SafeSetCVar("cameraDistanceMaxFactor", tostring(cameraZoomState.previousMaxFactor or "1"))
        cameraZoomState.active = false
        cameraZoomState.previousMaxFactor = nil
    end

    if gryphonState.active then
        if MainMenuBarLeftEndCap then
            if gryphonState.leftShown then MainMenuBarLeftEndCap:Show() else MainMenuBarLeftEndCap:Hide() end
        end
        if MainMenuBarRightEndCap then
            if gryphonState.rightShown then MainMenuBarRightEndCap:Show() else MainMenuBarRightEndCap:Hide() end
        end
        gryphonState.active = false
        gryphonState.leftShown = nil
        gryphonState.rightShown = nil
    end

    if worldMapState.active and WorldMapFrame then
        if WorldMapFrame.StopMovingOrSizing then
            WorldMapFrame:StopMovingOrSizing()
        end
        WorldMapFrame:SetMovable(worldMapState.movable and true or false)
        if WorldMapFrame.EnableMouse and worldMapState.mouseEnabled ~= nil then
            WorldMapFrame:EnableMouse(worldMapState.mouseEnabled)
        end
        if WorldMapFrame.SetScript then
            WorldMapFrame:SetScript("OnDragStart", worldMapState.onDragStart)
            WorldMapFrame:SetScript("OnDragStop", worldMapState.onDragStop)
        end
        worldMapState.active = false
        worldMapState.movable = nil
        worldMapState.mouseEnabled = nil
        worldMapState.onDragStart = nil
        worldMapState.onDragStop = nil
    end

    if minimapState.active and Minimap then
        if Minimap.EnableMouseWheel and minimapState.mouseWheelEnabled ~= nil then
            Minimap:EnableMouseWheel(minimapState.mouseWheelEnabled)
        end
        if Minimap.SetScript then
            Minimap:SetScript("OnMouseWheel", minimapState.onMouseWheel)
        end
        if MinimapZoomIn then
            if minimapState.zoomInShown then MinimapZoomIn:Show() else MinimapZoomIn:Hide() end
        end
        if MinimapZoomOut then
            if minimapState.zoomOutShown then MinimapZoomOut:Show() else MinimapZoomOut:Hide() end
        end
        minimapState.active = false
        minimapState.mouseWheelEnabled = nil
        minimapState.onMouseWheel = nil
        minimapState.zoomInShown = nil
        minimapState.zoomOutShown = nil
    end

    if buffFrameState.active then
        buffFrameState.active = false
        RestoreBuffFramePosition()
    end

    if type(QuestLog_Update) == "function" then
        pcall(QuestLog_Update)
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
    -- Camera Section
    -- ============================================================
    local cameraHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cameraHeader:SetPoint("TOPLEFT", 16, yOffset)
    cameraHeader:SetText("Camera")
    yOffset = yOffset - 25

    local zoomCb = addon:CreateCheckbox(parent)
    zoomCb:SetPoint("TOPLEFT", 16, yOffset)
    zoomCb.Text:SetText("Allow further camera zoom out")
    zoomCb:SetChecked(settings.extendedCameraZoom)
    zoomCb:SetScript("OnClick", function(self)
        addon:SetSetting("interface.extendedCameraZoom", self:GetChecked())
        ApplyCameraZoomDistance()
    end)
    yOffset = yOffset - 30

    local zoomSlider = addon:CreateSlider(parent)
    zoomSlider:SetPoint("TOPLEFT", 16, yOffset)
    zoomSlider:SetWidth(220)
    zoomSlider:SetMinMaxValues(1, 4)
    zoomSlider:SetValueStep(0.1)
    zoomSlider.Text:SetText("Camera Max Zoom Factor")
    zoomSlider.Low:SetText("1.0")
    zoomSlider.High:SetText("4.0")
    zoomSlider:SetValue(GetClampedZoomFactor(settings.maxZoomFactor))
    zoomSlider:SetScript("OnValueChanged", function(self, value)
        local rounded = GetClampedZoomFactor(value)
        if self._dcqosLastValue == rounded then return end
        self._dcqosLastValue = rounded
        addon:SetSetting("interface.maxZoomFactor", rounded)
        if settings.extendedCameraZoom then
            ApplyCameraZoomDistance()
        end
    end)
    yOffset = yOffset - 55

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
