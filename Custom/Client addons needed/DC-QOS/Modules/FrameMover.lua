-- ============================================================
-- DC-QoS: FrameMover Module
-- ============================================================
-- Move, scale, and customize UI frames
-- Inspired by MoveAnything and ElvUI
-- ============================================================

local addon = DCQOS

-- ============================================================
-- Module Configuration
-- ============================================================
local FrameMover = {
    displayName = "Frame Mover",
    settingKey = "frameMover",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    defaults = {
        frameMover = {
            enabled = true,
            unlocked = false,
            showAnchors = false,
            editorMode = false,
            showGrid = false,
            snapToGrid = true,
            lockPoints = true,
            clampToScreen = true,
            ignoreFramePositionManager = true,
            gridSize = 10,
            frames = {},
            profiles = {},
            currentProfile = "default",
        },
    },
}

-- Merge defaults
for k, v in pairs(FrameMover.defaults) do
    addon.defaults[k] = v
end

-- ============================================================
-- Movable Frames Registry
-- ============================================================
local MOVABLE_FRAMES = {
    -- Player/Target Frames
    { name = "PlayerFrame", displayName = "Player Frame", defaultScale = 1.0 },
    { name = "TargetFrame", displayName = "Target Frame", defaultScale = 1.0 },
    { name = "TargetFrameToT", displayName = "Target of Target", defaultScale = 1.0 },
    { name = "FocusFrame", displayName = "Focus Frame", defaultScale = 1.0 },
    { name = "PetFrame", displayName = "Pet Frame", defaultScale = 1.0 },
    
    -- Party/Raid
    { name = "PartyMemberFrame1", displayName = "Party Frame 1", defaultScale = 1.0 },
    { name = "PartyMemberFrame2", displayName = "Party Frame 2", defaultScale = 1.0 },
    { name = "PartyMemberFrame3", displayName = "Party Frame 3", defaultScale = 1.0 },
    { name = "PartyMemberFrame4", displayName = "Party Frame 4", defaultScale = 1.0 },
    
    -- Minimap
    { name = "Minimap", displayName = "Minimap", defaultScale = 1.0 },
    { name = "MinimapCluster", displayName = "Minimap Cluster", defaultScale = 1.0 },
    
    -- Buffs/Debuffs
    { name = "BuffFrame", displayName = "Buff Frame", defaultScale = 1.0 },
    
    -- Chat
    { name = "ChatFrame1", displayName = "Chat Frame", defaultScale = 1.0 },
    
    -- Action Bars
    { name = "MainMenuBar", displayName = "Main Action Bar", defaultScale = 1.0 },
    { name = "MultiBarBottomLeft", displayName = "Bottom Left Bar", defaultScale = 1.0 },
    { name = "MultiBarBottomRight", displayName = "Bottom Right Bar", defaultScale = 1.0 },
    { name = "MultiBarRight", displayName = "Right Bar", defaultScale = 1.0 },
    { name = "MultiBarLeft", displayName = "Right Bar 2", defaultScale = 1.0 },
    
    -- Misc (3.3.5a compatible)
    { name = "WatchFrame", displayName = "Quest Tracker", defaultScale = 1.0 },
    { name = "DurabilityFrame", displayName = "Durability", defaultScale = 1.0 },
    { name = "VehicleSeatIndicator", displayName = "Vehicle Seat", defaultScale = 1.0 },
    
    -- Boss Frames (may not exist on all servers)
    { name = "Boss1TargetFrame", displayName = "Boss Frame 1", defaultScale = 1.0 },
    { name = "Boss2TargetFrame", displayName = "Boss Frame 2", defaultScale = 1.0 },
    { name = "Boss3TargetFrame", displayName = "Boss Frame 3", defaultScale = 1.0 },
    { name = "Boss4TargetFrame", displayName = "Boss Frame 4", defaultScale = 1.0 },
}

-- ============================================================
-- State Variables
-- ============================================================
local anchorFrames = {}  -- Overlay frames for moving
local originalPositions = {}  -- Store original positions for reset
local originalFrameState = {}
local pendingPositions = {}
local isUnlocked = false
local editorOverlay
local gridOverlay

-- ============================================================
-- Utility Functions
-- ============================================================
local function GetFramePosition(frame)
    if not frame then return nil end
    
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
    if not point then return nil end
    
    return {
        point = point,
        relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
        relativePoint = relativePoint,
        x = xOfs,
        y = yOfs,
        scale = frame:GetScale(),
    }
end

local function ApplyFramePosition(frame, pos)
    if not frame or not pos then return end
    if frame.IsProtected and InCombatLockdown() and frame:IsProtected() then
        pendingPositions[frame:GetName()] = pos
        return
    end

    local settings = addon.settings.frameMover

    if not originalFrameState[frame:GetName()] then
        originalFrameState[frame:GetName()] = {
            movable = frame.IsMovable and frame:IsMovable() or nil,
            userPlaced = frame.IsUserPlaced and frame:IsUserPlaced() or nil,
            clamped = frame.IsClampedToScreen and frame:IsClampedToScreen() or nil,
            ignoreFPM = frame.ignoreFramePositionManager,
        }
    end

    if settings.ignoreFramePositionManager and UIPARENT_MANAGED_FRAME_POSITIONS and UIPARENT_MANAGED_FRAME_POSITIONS[frame:GetName()] then
        frame.ignoreFramePositionManager = true
    end

    if frame.SetMovable then
        frame:SetMovable(true)
    end
    if frame.SetUserPlaced and frame ~= MainMenuBar then
        frame:SetUserPlaced(true)
    end
    if settings.clampToScreen and frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end

    if settings.lockPoints and not frame._dcqosPointHooked and frame.SetPoint then
        frame._dcqosPointHooked = true
        hooksecurefunc(frame, "SetPoint", function(self)
            if self._dcqosLockPoint and not self._dcqosRepositioning then
                local saved = addon.settings.frameMover.frames[self:GetName()]
                if saved then
                    self._dcqosRepositioning = true
                    ApplyFramePosition(self, saved)
                    self._dcqosRepositioning = false
                end
            end
        end)
    end

    frame._dcqosLockPoint = settings.lockPoints or nil

    frame._dcqosRepositioning = true
    frame:ClearAllPoints()
    local relativeTo = _G[pos.relativeTo] or UIParent
    frame:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)

    if pos.scale and pos.scale > 0 then
        frame:SetScale(pos.scale)
    end
    frame._dcqosRepositioning = false
end

local function SaveFramePosition(frameName, posOverride)
    local frame = _G[frameName]
    if not frame then return end
    
    local settings = addon.settings.frameMover
    if not settings.frames then settings.frames = {} end
    
    local pos = posOverride or GetFramePosition(frame)
    if pos then
        settings.frames[frameName] = pos
        frame._dcqosLockPoint = settings.lockPoints or nil
    end
    addon:SaveSettings()
end

local function SnapValue(value, gridSize)
    if not gridSize or gridSize <= 0 then return value end
    return math.floor((value / gridSize) + 0.5) * gridSize
end

local function LoadFramePosition(frameName)
    local frame = _G[frameName]
    if not frame then return end
    
    local settings = addon.settings.frameMover
    if settings.frames and settings.frames[frameName] then
        ApplyFramePosition(frame, settings.frames[frameName])
        return true
    end
    return false
end

local function RestoreFrameState(frameName)
    local frame = _G[frameName]
    local state = frame and originalFrameState[frameName]
    if not frame or not state then return end
    if frame.SetClampedToScreen and state.clamped ~= nil then
        frame:SetClampedToScreen(state.clamped)
    end
    if frame.SetUserPlaced and state.userPlaced ~= nil then
        frame:SetUserPlaced(state.userPlaced)
    end
    if frame.SetMovable and state.movable ~= nil then
        frame:SetMovable(state.movable)
    end
    if state.ignoreFPM ~= nil then
        frame.ignoreFramePositionManager = state.ignoreFPM
    end
    frame._dcqosLockPoint = nil
end

local function ApplyPendingPositions()
    if InCombatLockdown() then return end
    for frameName, pos in pairs(pendingPositions) do
        local frame = _G[frameName]
        if frame then
            ApplyFramePosition(frame, pos)
        end
        pendingPositions[frameName] = nil
    end
end

local function ApplySettingsToFrames()
    local settings = addon.settings.frameMover
    for _, frameInfo in ipairs(MOVABLE_FRAMES) do
        local frame = _G[frameInfo.name]
        if frame then
            if settings.lockPoints then
                frame._dcqosLockPoint = true
            else
                frame._dcqosLockPoint = nil
            end

            if not settings.clampToScreen and originalFrameState[frameInfo.name] and originalFrameState[frameInfo.name].clamped ~= nil and frame.SetClampedToScreen then
                frame:SetClampedToScreen(originalFrameState[frameInfo.name].clamped)
            end

            if not settings.ignoreFramePositionManager and originalFrameState[frameInfo.name] and originalFrameState[frameInfo.name].ignoreFPM ~= nil then
                frame.ignoreFramePositionManager = originalFrameState[frameInfo.name].ignoreFPM
            end
        end
    end
end

local function ApplyAllSavedPositions()
    local settings = addon.settings.frameMover
    if settings and settings.frames then
        for frameName in pairs(settings.frames) do
            LoadFramePosition(frameName)
        end
    end
end

-- ============================================================
-- Anchor Frame Creation
-- ============================================================
local function CreateAnchorFrame(frameInfo)
    local targetFrame = _G[frameInfo.name]
    if not targetFrame then return nil end
    
    local anchor = CreateFrame("Frame", "DCQoS_Anchor_" .. frameInfo.name, UIParent)
    anchor:SetFrameStrata("DIALOG")
    anchor:SetFrameLevel(100)
    anchor:EnableMouse(true)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:Hide()
    
    -- Store reference to target
    anchor.targetFrame = targetFrame
    anchor.frameInfo = frameInfo
    
    -- Background
    local bg = anchor:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(0.1, 0.6, 0.1, 0.8)
    anchor.bg = bg
    
    -- Border
    anchor:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    anchor:SetBackdropBorderColor(0.2, 1, 0.2, 1)
    
    -- Label
    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText(frameInfo.displayName)
    label:SetTextColor(1, 1, 1)
    anchor.label = label
    
    -- Scale indicator
    local scaleText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleText:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 4)
    scaleText:SetTextColor(0.8, 0.8, 0.8)
    anchor.scaleText = scaleText
    
    -- Update function
    local function UpdateAnchor()
        if not targetFrame:IsShown() and not addon.settings.frameMover.showAnchors then
            anchor:Hide()
            return
        end
        
        local width = targetFrame:GetWidth()
        local height = targetFrame:GetHeight()
        
        if width < 50 then width = 100 end
        if height < 20 then height = 40 end
        
        anchor:SetSize(width, height)
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", targetFrame, "CENTER", 0, 0)
        
        local scale = targetFrame:GetScale()
        scaleText:SetText(string.format("Scale: %.0f%%", scale * 100))
    end
    
    anchor.Update = UpdateAnchor
    
    -- Drag handlers
    anchor:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            self:StartMoving()
        elseif button == "RightButton" then
            -- Right-click for context menu (reset)
            local menu = {
                { text = frameInfo.displayName, isTitle = true },
                { text = "Reset Position", func = function()
                    local origPos = originalPositions[frameInfo.name]
                    if origPos then
                        ApplyFramePosition(targetFrame, origPos)
                        addon.settings.frameMover.frames[frameInfo.name] = nil
                        addon:SaveSettings()
                        RestoreFrameState(frameInfo.name)
                        UpdateAnchor()
                    end
                end },
                { text = "Scale: 80%", func = function()
                    targetFrame:SetScale(0.8)
                    SaveFramePosition(frameInfo.name)
                    UpdateAnchor()
                end },
                { text = "Scale: 100%", func = function()
                    targetFrame:SetScale(1.0)
                    SaveFramePosition(frameInfo.name)
                    UpdateAnchor()
                end },
                { text = "Scale: 120%", func = function()
                    targetFrame:SetScale(1.2)
                    SaveFramePosition(frameInfo.name)
                    UpdateAnchor()
                end },
            }
            EasyMenu(menu, CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")
        end
    end)
    
    anchor:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isDragging then
            self:StopMovingOrSizing()
            self.isDragging = false
            
            -- Move the target frame to match anchor position
            local point, _, _, x, y = self:GetPoint()
            local settings = addon.settings.frameMover
            if settings and settings.snapToGrid then
                local gridSize = settings.gridSize or 10
                x = SnapValue(x, gridSize)
                y = SnapValue(y, gridSize)
            end
            local pos = {
                point = point,
                relativeTo = "UIParent",
                relativePoint = point,
                x = x,
                y = y,
                scale = targetFrame:GetScale(),
            }

            ApplyFramePosition(targetFrame, pos)

            -- Save position
            SaveFramePosition(frameInfo.name, pos)
            
            -- Update anchor to match
            UpdateAnchor()
        end
    end)
    
    -- Mouse wheel for scaling
    anchor:EnableMouseWheel(true)
    anchor:SetScript("OnMouseWheel", function(self, delta)
        local currentScale = targetFrame:GetScale()
        local newScale = currentScale + (delta * 0.05)
        
        -- Clamp scale between 0.5 and 2.0
        newScale = math.max(0.5, math.min(2.0, newScale))
        
        targetFrame:SetScale(newScale)
        SaveFramePosition(frameInfo.name)
        UpdateAnchor()
    end)
    
    -- Tooltip
    anchor:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(frameInfo.displayName, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff00ff00Left-click|r to drag", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Right-click|r for options", 1, 1, 1)
        GameTooltip:AddLine("|cff00ff00Mouse wheel|r to scale", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    anchor:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return anchor
end

-- ============================================================
-- Lock/Unlock Functions
-- ============================================================
local function UnlockFrames()
    if isUnlocked then return end
    isUnlocked = true
    addon.settings.frameMover.unlocked = true
    
    for _, frameInfo in ipairs(MOVABLE_FRAMES) do
        local targetFrame = _G[frameInfo.name]
        if targetFrame then
            -- Store original position if not already stored
            if not originalPositions[frameInfo.name] then
                originalPositions[frameInfo.name] = GetFramePosition(targetFrame)
            end
            
            -- Create or update anchor
            if not anchorFrames[frameInfo.name] then
                anchorFrames[frameInfo.name] = CreateAnchorFrame(frameInfo)
            end
            
            local anchor = anchorFrames[frameInfo.name]
            if anchor then
                anchor:Update()
                anchor:Show()
            end
        end
    end
    
    addon:Print("Frames UNLOCKED. Drag to move, scroll to scale, right-click for options.", true)
end

local function LockFrames()
    if not isUnlocked then return end
    isUnlocked = false
    addon.settings.frameMover.unlocked = false
    
    for name, anchor in pairs(anchorFrames) do
        anchor:Hide()
    end
    
    addon:Print("Frames LOCKED.", true)
end

local function ToggleLock()
    if isUnlocked then
        LockFrames()
    else
        UnlockFrames()
    end
end

local function EnsureGridOverlay()
    if gridOverlay then return end
    gridOverlay = CreateFrame("Frame", "DCQOS_GridOverlay", UIParent)
    gridOverlay:SetAllPoints(UIParent)
    gridOverlay:SetFrameStrata("BACKGROUND")
    gridOverlay:Hide()
    gridOverlay.lines = {}
end

local function UpdateGridOverlay()
    local settings = addon.settings.frameMover
    if not settings or not settings.showGrid then
        if gridOverlay then gridOverlay:Hide() end
        return
    end

    EnsureGridOverlay()
    local gridSize = settings.gridSize or 10
    local width = UIParent:GetWidth()
    local height = UIParent:GetHeight()
    local lines = gridOverlay.lines

    for _, line in ipairs(lines) do
        line:Hide()
    end

    local index = 1
    for x = gridSize, width, gridSize do
        local line = lines[index]
        if not line then
            line = gridOverlay:CreateTexture(nil, "BACKGROUND")
            lines[index] = line
        end
        line:SetTexture(0.2, 0.7, 0.2, 0.12)
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", gridOverlay, "TOPLEFT", x, -height)
        line:SetWidth(1)
        line:Show()
        index = index + 1
    end

    for y = gridSize, height, gridSize do
        local line = lines[index]
        if not line then
            line = gridOverlay:CreateTexture(nil, "BACKGROUND")
            lines[index] = line
        end
        line:SetTexture(0.2, 0.7, 0.2, 0.12)
        line:SetPoint("TOPLEFT", gridOverlay, "TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", gridOverlay, "TOPLEFT", width, -y)
        line:SetHeight(1)
        line:Show()
        index = index + 1
    end

    gridOverlay:Show()
end

local function EnsureEditorOverlay()
    if editorOverlay then return end

    editorOverlay = CreateFrame("Frame", "DCQOS_EditorOverlay", UIParent)
    editorOverlay:SetPoint("TOP", UIParent, "TOP", 0, -20)
    editorOverlay:SetSize(460, 34)
    editorOverlay:SetFrameStrata("DIALOG")
    editorOverlay:Hide()

    editorOverlay.bg = editorOverlay:CreateTexture(nil, "BACKGROUND")
    editorOverlay.bg:SetAllPoints()
    editorOverlay.bg:SetTexture(0, 0, 0, 0.55)

    local title = editorOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 10, 0)
    title:SetText("DC-QoS Editor Mode")

    local lockBtn = CreateFrame("Button", nil, editorOverlay, "UIPanelButtonTemplate")
    lockBtn:SetPoint("LEFT", title, "RIGHT", 10, 0)
    lockBtn:SetSize(70, 20)
    lockBtn:SetText("Lock")
    lockBtn:SetScript("OnClick", function()
        ToggleLock()
        lockBtn:SetText(isUnlocked and "Lock" or "Unlock")
    end)
    editorOverlay.lockBtn = lockBtn

    local gridBtn = CreateFrame("Button", nil, editorOverlay, "UIPanelButtonTemplate")
    gridBtn:SetPoint("LEFT", lockBtn, "RIGHT", 6, 0)
    gridBtn:SetSize(70, 20)
    gridBtn:SetText("Grid")
    gridBtn:SetScript("OnClick", function()
        addon.settings.frameMover.showGrid = not addon.settings.frameMover.showGrid
        addon:SaveSettings()
        UpdateGridOverlay()
    end)

    local snapBtn = CreateFrame("Button", nil, editorOverlay, "UIPanelButtonTemplate")
    snapBtn:SetPoint("LEFT", gridBtn, "RIGHT", 6, 0)
    snapBtn:SetSize(70, 20)
    snapBtn:SetText("Snap")
    snapBtn:SetScript("OnClick", function()
        addon.settings.frameMover.snapToGrid = not addon.settings.frameMover.snapToGrid
        addon:SaveSettings()
    end)

    local resetBtn = CreateFrame("Button", nil, editorOverlay, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", snapBtn, "RIGHT", 6, 0)
    resetBtn:SetSize(70, 20)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        ResetAllFrames()
    end)

    local closeBtn = CreateFrame("Button", nil, editorOverlay, "UIPanelButtonTemplate")
    closeBtn:SetPoint("LEFT", resetBtn, "RIGHT", 6, 0)
    closeBtn:SetSize(70, 20)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        addon.settings.frameMover.editorMode = false
        addon:SaveSettings()
        editorOverlay:Hide()
        if gridOverlay then gridOverlay:Hide() end
        LockFrames()
    end)
end

local function EnableEditorMode()
    EnsureEditorOverlay()
    editorOverlay:Show()
    if not isUnlocked then
        UnlockFrames()
    end
    UpdateGridOverlay()
    addon.settings.frameMover.editorMode = true
    addon:SaveSettings()
end

local function DisableEditorMode()
    if editorOverlay then editorOverlay:Hide() end
    if gridOverlay then gridOverlay:Hide() end
    addon.settings.frameMover.editorMode = false
    addon:SaveSettings()
end

-- ============================================================
-- Profile Management
-- ============================================================
local function SaveProfile(profileName)
    local settings = addon.settings.frameMover
    if not settings.profiles then settings.profiles = {} end
    
    settings.profiles[profileName] = addon:DeepCopy(settings.frames)
    addon:SaveSettings()
    addon:Print("Profile '" .. profileName .. "' saved.", true)
end

local function LoadProfile(profileName)
    local settings = addon.settings.frameMover
    if not settings.profiles or not settings.profiles[profileName] then
        addon:Print("Profile '" .. profileName .. "' not found.", true)
        return false
    end
    
    settings.frames = addon:DeepCopy(settings.profiles[profileName])
    settings.currentProfile = profileName
    
    -- Apply all positions
    for frameName, pos in pairs(settings.frames) do
        local frame = _G[frameName]
        if frame then
            ApplyFramePosition(frame, pos)
        end
    end
    
    addon:SaveSettings()
    addon:Print("Profile '" .. profileName .. "' loaded.", true)
    return true
end

local function ResetAllFrames()
    for frameName, origPos in pairs(originalPositions) do
        local frame = _G[frameName]
        if frame and origPos then
            ApplyFramePosition(frame, origPos)
            RestoreFrameState(frameName)
        end
    end
    
    addon.settings.frameMover.frames = {}
    addon:SaveSettings()
    addon:Print("All frames reset to default positions.", true)
end

-- ============================================================
-- Module Callbacks
-- ============================================================
function FrameMover.OnInitialize()
    addon:Debug("FrameMover module initializing")
    
    -- Store original positions for all frames
    for _, frameInfo in ipairs(MOVABLE_FRAMES) do
        local frame = _G[frameInfo.name]
        if frame then
            originalPositions[frameInfo.name] = GetFramePosition(frame)
        end
    end
end

function FrameMover.OnEnable()
    addon:Debug("FrameMover module enabling")
    
    -- Apply saved positions after a short delay (ensure frames are loaded)
    addon:DelayedCall(1, function()
        local settings = addon.settings.frameMover
        if settings.frames then
            for frameName, pos in pairs(settings.frames) do
                LoadFramePosition(frameName)
            end
        end
        if settings.editorMode then
            EnableEditorMode()
        end
    end)

    if not FrameMover.eventFrame then
        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_ENTERING_WORLD")
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        ev:RegisterEvent("UNIT_ENTERED_VEHICLE")
        ev:RegisterEvent("UNIT_EXITED_VEHICLE")
        ev:RegisterEvent("GROUP_ROSTER_UPDATE")
        ev:SetScript("OnEvent", function(_, event, unit)
            if event == "PLAYER_REGEN_ENABLED" then
                ApplyPendingPositions()
                return
            end
            if unit and unit ~= "player" then return end
            addon:DelayedCall(0.3, function()
                ApplyAllSavedPositions()
                ApplyPendingPositions()
                ApplySettingsToFrames()
                if addon.settings.frameMover.editorMode then
                    UpdateGridOverlay()
                end
            end)
        end)
        FrameMover.eventFrame = ev
    end
    
    -- Register slash commands
    SLASH_DCMOVE1 = "/dcmove"
    SLASH_DCMOVE2 = "/dcm"
    SlashCmdList["DCMOVE"] = function(msg)
        msg = msg and strlower(strtrim(msg)) or ""
        
        if msg == "" or msg == "toggle" then
            ToggleLock()
        elseif msg == "editor" then
            if addon.settings.frameMover.editorMode then
                DisableEditorMode()
                LockFrames()
            else
                EnableEditorMode()
            end
        elseif msg == "lock" then
            LockFrames()
        elseif msg == "unlock" then
            UnlockFrames()
        elseif msg == "grid" then
            addon.settings.frameMover.showGrid = not addon.settings.frameMover.showGrid
            addon:SaveSettings()
            UpdateGridOverlay()
        elseif msg == "snap" then
            addon.settings.frameMover.snapToGrid = not addon.settings.frameMover.snapToGrid
            addon:SaveSettings()
        elseif msg == "reset" then
            ResetAllFrames()
        elseif msg:match("^save%s+") then
            local profileName = msg:match("^save%s+(.+)$")
            if profileName then
                SaveProfile(profileName)
            end
        elseif msg:match("^load%s+") then
            local profileName = msg:match("^load%s+(.+)$")
            if profileName then
                LoadProfile(profileName)
            end
        elseif msg == "help" then
            addon:Print("Frame Mover Commands:", true)
            print("  |cffffd700/dcmove|r - Toggle frame unlock")
            print("  |cffffd700/dcmove editor|r - Toggle editor mode")
            print("  |cffffd700/dcmove grid|r - Toggle grid overlay")
            print("  |cffffd700/dcmove snap|r - Toggle snap to grid")
            print("  |cffffd700/dcmove lock|r - Lock all frames")
            print("  |cffffd700/dcmove unlock|r - Unlock all frames")
            print("  |cffffd700/dcmove reset|r - Reset all frames to default")
            print("  |cffffd700/dcmove save <name>|r - Save current layout")
            print("  |cffffd700/dcmove load <name>|r - Load saved layout")
        else
            addon:Print("Unknown command. Type |cffffd700/dcmove help|r for help.", true)
        end
    end
end

function FrameMover.OnDisable()
    addon:Debug("FrameMover module disabling")
    LockFrames()
    DisableEditorMode()
end

-- ============================================================
-- Settings Panel Creation
-- ============================================================
function FrameMover.CreateSettings(parent)
    local settings = addon.settings.frameMover
    
    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Frame Mover Settings")
    
    -- Description
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(450)
    desc:SetJustifyH("LEFT")
    desc:SetText("Move and scale UI frames to customize your interface. Use |cffffd700/dcmove|r to toggle frame unlocking.")
    
    local yOffset = -70
    
    -- Toggle Unlock Button
    local unlockBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    unlockBtn:SetSize(150, 25)
    unlockBtn:SetPoint("TOPLEFT", 16, yOffset)
    unlockBtn:SetText(isUnlocked and "Lock Frames" or "Unlock Frames")
    unlockBtn:SetScript("OnClick", function(self)
        ToggleLock()
        self:SetText(isUnlocked and "Lock Frames" or "Unlock Frames")
    end)
    yOffset = yOffset - 35

    -- Editor Mode Button
    local editorBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    editorBtn:SetSize(150, 25)
    editorBtn:SetPoint("TOPLEFT", 16, yOffset)
    editorBtn:SetText(settings.editorMode and "Exit Editor" or "Enter Editor")
    editorBtn:SetScript("OnClick", function(self)
        if addon.settings.frameMover.editorMode then
            DisableEditorMode()
            LockFrames()
        else
            EnableEditorMode()
        end
        self:SetText(addon.settings.frameMover.editorMode and "Exit Editor" or "Enter Editor")
    end)
    yOffset = yOffset - 35

    local showGridCb = addon:CreateCheckbox(parent)
    showGridCb:SetPoint("TOPLEFT", 16, yOffset)
    showGridCb.Text:SetText("Show grid overlay")
    showGridCb:SetChecked(settings.showGrid)
    showGridCb:SetScript("OnClick", function(self)
        addon:SetSetting("frameMover.showGrid", self:GetChecked())
        UpdateGridOverlay()
    end)
    yOffset = yOffset - 22

    local snapCb = addon:CreateCheckbox(parent)
    snapCb:SetPoint("TOPLEFT", 16, yOffset)
    snapCb.Text:SetText("Snap frames to grid")
    snapCb:SetChecked(settings.snapToGrid)
    snapCb:SetScript("OnClick", function(self)
        addon:SetSetting("frameMover.snapToGrid", self:GetChecked())
    end)
    yOffset = yOffset - 22

    local lockPointsCb = addon:CreateCheckbox(parent)
    lockPointsCb:SetPoint("TOPLEFT", 16, yOffset)
    lockPointsCb.Text:SetText("Lock frame points")
    lockPointsCb:SetChecked(settings.lockPoints)
    lockPointsCb:SetScript("OnClick", function(self)
        addon:SetSetting("frameMover.lockPoints", self:GetChecked())
        ApplySettingsToFrames()
    end)
    yOffset = yOffset - 22

    local clampCb = addon:CreateCheckbox(parent)
    clampCb:SetPoint("TOPLEFT", 16, yOffset)
    clampCb.Text:SetText("Clamp frames to screen")
    clampCb:SetChecked(settings.clampToScreen)
    clampCb:SetScript("OnClick", function(self)
        addon:SetSetting("frameMover.clampToScreen", self:GetChecked())
        ApplySettingsToFrames()
        ApplyAllSavedPositions()
    end)
    yOffset = yOffset - 22

    local ignoreManagerCb = addon:CreateCheckbox(parent)
    ignoreManagerCb:SetPoint("TOPLEFT", 16, yOffset)
    ignoreManagerCb.Text:SetText("Ignore Blizzard position manager")
    ignoreManagerCb:SetChecked(settings.ignoreFramePositionManager)
    ignoreManagerCb:SetScript("OnClick", function(self)
        addon:SetSetting("frameMover.ignoreFramePositionManager", self:GetChecked())
        ApplySettingsToFrames()
        ApplyAllSavedPositions()
    end)
    yOffset = yOffset - 22

    local gridSizeSlider = addon:CreateSlider(parent)
    gridSizeSlider:SetPoint("TOPLEFT", 16, yOffset)
    gridSizeSlider:SetWidth(200)
    gridSizeSlider:SetMinMaxValues(5, 40)
    gridSizeSlider:SetValueStep(1)
    gridSizeSlider.Text:SetText("Grid Size")
    gridSizeSlider.Low:SetText("5")
    gridSizeSlider.High:SetText("40")
    gridSizeSlider:SetValue(settings.gridSize or 10)
    gridSizeSlider:SetScript("OnValueChanged", function(self, value)
        addon:SetSetting("frameMover.gridSize", math.floor(value + 0.5))
        if addon.settings.frameMover.showGrid then
            UpdateGridOverlay()
        end
    end)
    yOffset = yOffset - 50
    
    -- Reset All Button
    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(150, 25)
    resetBtn:SetPoint("TOPLEFT", 16, yOffset)
    resetBtn:SetText("Reset All Frames")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("DCQOS_RESET_FRAMES")
    end)
    yOffset = yOffset - 45
    
    -- Create reset confirmation dialog
    if not StaticPopupDialogs["DCQOS_RESET_FRAMES"] then
        StaticPopupDialogs["DCQOS_RESET_FRAMES"] = {
            text = "Reset all frame positions to default?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                ResetAllFrames()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    
    -- Show Hidden Frames Checkbox
    local showHiddenCb = addon:CreateCheckbox(parent)
    showHiddenCb:SetPoint("TOPLEFT", 16, yOffset)
    showHiddenCb.Text:SetText("Show anchors for hidden frames")
    showHiddenCb:SetChecked(settings.showAnchors or false)
    showHiddenCb:SetScript("OnClick", function(self)
        addon:SetSetting("frameMover.showAnchors", self:GetChecked())
    end)
    yOffset = yOffset - 35
    
    -- Profile Section
    local profileHeader = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileHeader:SetPoint("TOPLEFT", 16, yOffset)
    profileHeader:SetText("Profiles")
    yOffset = yOffset - 25
    
    -- Profile name input
    local profileEdit = CreateFrame("EditBox", "DCQoS_ProfileEdit", parent, "InputBoxTemplate")
    profileEdit:SetSize(150, 20)
    profileEdit:SetPoint("TOPLEFT", 20, yOffset)
    profileEdit:SetAutoFocus(false)
    profileEdit:SetText("default")
    yOffset = yOffset - 30
    
    -- Save Profile Button
    local saveProfileBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    saveProfileBtn:SetSize(70, 22)
    saveProfileBtn:SetPoint("TOPLEFT", 16, yOffset)
    saveProfileBtn:SetText("Save")
    saveProfileBtn:SetScript("OnClick", function()
        local name = profileEdit:GetText()
        if name and name ~= "" then
            SaveProfile(name)
        end
    end)
    
    -- Load Profile Button
    local loadProfileBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    loadProfileBtn:SetSize(70, 22)
    loadProfileBtn:SetPoint("LEFT", saveProfileBtn, "RIGHT", 10, 0)
    loadProfileBtn:SetText("Load")
    loadProfileBtn:SetScript("OnClick", function()
        local name = profileEdit:GetText()
        if name and name ~= "" then
            LoadProfile(name)
        end
    end)
    yOffset = yOffset - 40
    
    -- Info text
    local infoText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 16, yOffset)
    infoText:SetWidth(450)
    infoText:SetJustifyH("LEFT")
    infoText:SetTextColor(0.7, 0.7, 0.7)
    infoText:SetText("Tip: When frames are unlocked, left-click and drag to move, use mouse wheel to scale, and right-click for more options.")
    
    return yOffset - 60
end

-- ============================================================
-- Expose Functions
-- ============================================================
FrameMover.ToggleLock = ToggleLock
FrameMover.LockFrames = LockFrames
FrameMover.UnlockFrames = UnlockFrames
FrameMover.ResetAllFrames = ResetAllFrames
FrameMover.SaveProfile = SaveProfile
FrameMover.LoadProfile = LoadProfile

-- ============================================================
-- Register Module
-- ============================================================
addon:RegisterModule("FrameMover", FrameMover)
