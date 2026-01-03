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
    
    -- Misc
    { name = "ObjectiveTrackerFrame", displayName = "Quest Tracker", defaultScale = 1.0 },
    { name = "WatchFrame", displayName = "Watch Frame", defaultScale = 1.0 },
    { name = "DurabilityFrame", displayName = "Durability", defaultScale = 1.0 },
    { name = "VehicleSeatIndicator", displayName = "Vehicle Seat", defaultScale = 1.0 },
    
    -- Boss Frames
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
local isUnlocked = false

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
    
    frame:ClearAllPoints()
    local relativeTo = _G[pos.relativeTo] or UIParent
    frame:SetPoint(pos.point, relativeTo, pos.relativePoint, pos.x, pos.y)
    
    if pos.scale and pos.scale > 0 then
        frame:SetScale(pos.scale)
    end
end

local function SaveFramePosition(frameName)
    local frame = _G[frameName]
    if not frame then return end
    
    local settings = addon.settings.frameMover
    if not settings.frames then settings.frames = {} end
    
    settings.frames[frameName] = GetFramePosition(frame)
    addon:SaveSettings()
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
            targetFrame:ClearAllPoints()
            targetFrame:SetPoint(point, UIParent, point, x, y)
            
            -- Save position
            SaveFramePosition(frameInfo.name)
            
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
    end)
    
    -- Register slash commands
    SLASH_DCMOVE1 = "/dcmove"
    SLASH_DCMOVE2 = "/dcm"
    SlashCmdList["DCMOVE"] = function(msg)
        msg = msg and strlower(strtrim(msg)) or ""
        
        if msg == "" or msg == "toggle" then
            ToggleLock()
        elseif msg == "lock" then
            LockFrames()
        elseif msg == "unlock" then
            UnlockFrames()
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
