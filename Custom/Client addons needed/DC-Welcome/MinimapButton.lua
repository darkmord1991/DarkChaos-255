--[[
    DC-Welcome: Minimap Button
    ===========================
    
    Creates a draggable minimap button for easy access to DC-Welcome.
    Click to open welcome screen, right-click for quick menu.
    
    Author: DarkChaos-255
    Date: December 2025
]]

DCWelcome = DCWelcome or {}

-- =============================================================================
-- Minimap Button Configuration
-- =============================================================================

local BUTTON_RADIUS = 80          -- Distance from minimap center
local BUTTON_SIZE = 32            -- Button size in pixels
local ICON_TEXTURE = "Interface\\Icons\\INV_Letter_02"  -- Mail/welcome icon
local HIGHLIGHT_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- =============================================================================
-- Saved Variables for Button Position
-- =============================================================================

local function GetButtonPosition()
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB.minimapButton = DCWelcomeDB.minimapButton or {}
    return DCWelcomeDB.minimapButton.angle or 225  -- Default: bottom-left
end

local function SetButtonPosition(angle)
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB.minimapButton = DCWelcomeDB.minimapButton or {}
    DCWelcomeDB.minimapButton.angle = angle
end

local function IsButtonHidden()
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB.minimapButton = DCWelcomeDB.minimapButton or {}
    return DCWelcomeDB.minimapButton.hidden or false
end

local function SetButtonHidden(hidden)
    DCWelcomeDB = DCWelcomeDB or {}
    DCWelcomeDB.minimapButton = DCWelcomeDB.minimapButton or {}
    DCWelcomeDB.minimapButton.hidden = hidden
end

-- =============================================================================
-- Position Calculation (for circular movement around minimap)
-- =============================================================================

local function UpdateButtonPosition(button, angle)
    local radians = math.rad(angle)
    local x = math.cos(radians) * BUTTON_RADIUS
    local y = math.sin(radians) * BUTTON_RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function GetAngleFromCursor(button)
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    
    local dx = cx - mx
    local dy = cy - my
    
    return math.deg(math.atan2(dy, dx))
end

-- =============================================================================
-- Create the Minimap Button
-- =============================================================================

local function CreateMinimapButton()
    -- Main button frame
    local button = CreateFrame("Button", "DCWelcomeMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)
    
    -- Button background (circular border)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(BUTTON_SIZE + 4, BUTTON_SIZE + 4)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    
    -- Main icon
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BUTTON_SIZE - 6, BUTTON_SIZE - 6)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ICON_TEXTURE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- Trim edges
    button.icon = icon
    
    -- Overlay for visual feedback (new notification dot)
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(12, 12)
    overlay:SetPoint("TOPRIGHT", -2, -2)
    overlay:SetTexture("Interface\\COMMON\\Indicator-Green")
    overlay:Hide()
    button.notificationDot = overlay
    
    -- Highlight texture
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE + 8, BUTTON_SIZE + 8)
    highlight:SetPoint("CENTER")
    highlight:SetTexture(HIGHLIGHT_TEXTURE)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.4)
    
    -- Set initial position
    local angle = GetButtonPosition()
    UpdateButtonPosition(button, angle)
    
    -- Dragging state
    button.isDragging = false
    
    -- =============================================================================
    -- Mouse Handlers
    -- =============================================================================
    
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    
    -- Click handler
    button:SetScript("OnClick", function(self, mouseButton)
        if self.isDragging then
            return
        end
        
        if mouseButton == "LeftButton" then
            -- Open welcome screen
            if DCWelcome.ShowWelcome then
                DCWelcome:ShowWelcome(true)
            end
        elseif mouseButton == "RightButton" then
            -- Show quick menu
            DCWelcome:ShowMinimapMenu(self)
        end
    end)
    
    -- Drag start
    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local angle = GetAngleFromCursor(self)
            UpdateButtonPosition(self, angle)
            SetButtonPosition(angle)
        end)
    end)
    
    -- Drag stop
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        -- Delay resetting isDragging to prevent click from firing
        C_Timer_After(0.1, function()
            self.isDragging = false
        end)
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("|cff00ff00DC-Welcome|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffffffffLeft-Click:|r Open Welcome Screen", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffRight-Click:|r Quick Menu", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffffffDrag:|r Move Button", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        
        -- Show server info if available
        local info = DCWelcome:GetServerInfo()
        if info and info.name then
            GameTooltip:AddLine("|cffffd700Server:|r " .. info.name, 0.6, 0.8, 1)
        end
        
        local season = DCWelcome:GetCurrentSeason()
        if season and season.name then
            GameTooltip:AddLine("|cffffd700Season:|r " .. season.name, 0.6, 0.8, 1)
        end
        
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    return button
end

-- =============================================================================
-- Quick Menu (Right-Click)
-- =============================================================================

local quickMenu = nil

function DCWelcome:ShowMinimapMenu(anchor)
    if not quickMenu then
        quickMenu = CreateFrame("Frame", "DCWelcomeMinimapMenu", UIParent, "UIDropDownMenuTemplate")
    end
    
    local menuList = {
        {
            text = "|cff00ff00DC-Welcome|r",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Open Welcome Screen",
            func = function() DCWelcome:ShowWelcome(true) end,
            notCheckable = true,
            icon = "Interface\\Icons\\INV_Letter_02",
        },
        {
            text = "Open FAQ",
            func = function()
                DCWelcome:ShowWelcome(true)
                C_Timer_After(0.1, function()
                    if DCWelcome.WelcomeFrame and DCWelcome.WelcomeFrame.SelectTab then
                        DCWelcome.WelcomeFrame:SelectTab("faq")
                    end
                end)
            end,
            notCheckable = true,
            icon = "Interface\\Icons\\INV_Misc_Book_09",
        },
        {
            text = " ",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Copy Discord Link",
            func = function()
                if ChatFrame1EditBox then
                    ChatFrame1EditBox:SetText("https://discord.gg/pNddMEMbb2")
                    ChatFrame1EditBox:Show()
                    ChatFrame1EditBox:SetFocus()
                    ChatFrame1EditBox:HighlightText()
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r Discord link copied!")
            end,
            notCheckable = true,
            icon = "Interface\\Icons\\INV_Misc_Note_06",
        },
        {
            text = "Open Settings",
            func = function()
                InterfaceOptionsFrame_OpenToCategory(DCWelcome.SettingsPanel)
                InterfaceOptionsFrame_OpenToCategory(DCWelcome.SettingsPanel)
            end,
            notCheckable = true,
            icon = "Interface\\Icons\\Trade_Engineering",
        },
        {
            text = " ",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Hide Minimap Button",
            func = function()
                SetButtonHidden(true)
                if DCWelcomeMinimapButton then
                    DCWelcomeMinimapButton:Hide()
                end
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r Minimap button hidden. Use |cfffff000/welcome show|r to restore.")
            end,
            notCheckable = true,
            icon = "Interface\\Icons\\Spell_Nature_Invisibilty",
        },
        {
            text = " ",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Cancel",
            func = function() end,
            notCheckable = true,
        },
    }
    
    EasyMenu(menuList, quickMenu, "cursor", 0, 0, "MENU")
end

-- =============================================================================
-- Show/Hide Button Commands
-- =============================================================================

local origSlashHandler = SlashCmdList["DCWELCOME"]
SlashCmdList["DCWELCOME"] = function(msg)
    local args = {}
    for word in string.gmatch(msg or "", "%S+") do
        table.insert(args, string.lower(word))
    end
    
    local cmd = args[1] or ""
    
    if cmd == "show" or cmd == "showbutton" then
        SetButtonHidden(false)
        if DCWelcomeMinimapButton then
            DCWelcomeMinimapButton:Show()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r Minimap button shown.")
        return
    elseif cmd == "hide" or cmd == "hidebutton" then
        SetButtonHidden(true)
        if DCWelcomeMinimapButton then
            DCWelcomeMinimapButton:Hide()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[DC-Welcome]|r Minimap button hidden. Use |cfffff000/welcome show|r to restore.")
        return
    end
    
    -- Fall through to original handler
    if origSlashHandler then
        origSlashHandler(msg)
    end
end

-- =============================================================================
-- Notification Functions (for new content alerts)
-- =============================================================================

function DCWelcome:ShowMinimapNotification(show)
    if DCWelcomeMinimapButton and DCWelcomeMinimapButton.notificationDot then
        if show then
            DCWelcomeMinimapButton.notificationDot:Show()
        else
            DCWelcomeMinimapButton.notificationDot:Hide()
        end
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

local function InitializeMinimapButton()
    -- Wait for minimap to be ready
    if not Minimap then
        C_Timer_After(1, InitializeMinimapButton)
        return
    end
    
    local button = CreateMinimapButton()
    
    -- Respect hidden setting
    if IsButtonHidden() then
        button:Hide()
    end
    
    -- Store reference
    DCWelcome.MinimapButton = button
end

-- C_Timer polyfill check (should already exist from Core.lua)
if not C_Timer_After then
    C_Timer_After = function(delay, callback)
        local frame = CreateFrame("Frame")
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
    end
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Small delay to ensure UI is ready
        C_Timer_After(0.5, InitializeMinimapButton)
    end
end)

-- Mark as loaded
DCWelcome.MinimapButtonLoaded = true
