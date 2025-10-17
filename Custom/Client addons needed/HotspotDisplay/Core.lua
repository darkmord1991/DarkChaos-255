--[[
    HotspotDisplay - Simple and Clean
    Shows "XP+" text on map when player is in a hotspot
    
    Author: DarkChaos Team
    Version: 1.0
]]--

local ADDON_NAME = "HotspotDisplay"
local ADDON_VERSION = "1.0"

-- Configuration (must match server settings)
local CONFIG = {
    HOTSPOT_BUFF_SPELL_ID = 23768,  -- Sayge's Dark Fortune of Strength
    HOTSPOT_BUFF_NAME = "Sayge's Dark Fortune of Strength",
    XP_BONUS_PERCENT = 100,  -- Default bonus percentage
    TEXT_COLOR = {1, 0.84, 0},  -- Gold color (RGB)
    PULSE_ENABLED = true,
    CHECK_INTERVAL = 1.0,  -- Check every 1 second
}

-- Saved variables (default settings)
HotspotDisplayDB = HotspotDisplayDB or {
    enabled = true,
    showText = true,
    showMinimap = true,
    textSize = 16,
    xpBonus = 100,
}

-- Local variables
local overlayFrame = nil
local overlayText = nil
local lastCheckTime = 0
local playerInHotspot = false
local pulseDirection = 1
local pulseAlpha = 1.0

-- Helper: Print messages to chat
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot Display]|r " .. msg)
end

-- Helper: Check if player has hotspot buff
local function PlayerHasHotspotBuff()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        if spellId == CONFIG.HOTSPOT_BUFF_SPELL_ID then
            return true
        end
    end
    return false
end

-- Create overlay text on WorldMapFrame
local function CreateOverlay()
    if not WorldMapFrame then return end
    
    -- Create overlay frame if it doesn't exist
    if not overlayFrame then
        overlayFrame = CreateFrame("Frame", "HotspotDisplayOverlay", WorldMapFrame)
        overlayFrame:SetFrameStrata("TOOLTIP")
        overlayFrame:SetAllPoints(WorldMapFrame)
        overlayFrame:Hide()
    end
    
    -- Create text if it doesn't exist
    if not overlayText then
        overlayText = overlayFrame:CreateFontString(nil, "OVERLAY")
        overlayText:SetFont("Fonts\\FRIZQT__.TTF", HotspotDisplayDB.textSize, "OUTLINE")
        overlayText:SetTextColor(unpack(CONFIG.TEXT_COLOR))
    end
end

-- Update overlay position (center of player on map)
local function UpdateOverlayPosition()
    if not overlayFrame or not overlayText then return end
    if not HotspotDisplayDB.enabled or not HotspotDisplayDB.showText then
        overlayFrame:Hide()
        return
    end
    
    -- Only show if player is in hotspot
    if not playerInHotspot then
        overlayFrame:Hide()
        return
    end
    
    -- Get player position on map (0-1 coordinates)
    local x, y = GetPlayerMapPosition("player")
    
    if not x or not y or (x == 0 and y == 0) then
        overlayFrame:Hide()
        return
    end
    
    -- Convert to pixel coordinates
    local frameWidth = WorldMapFrame:GetWidth()
    local frameHeight = WorldMapFrame:GetHeight()
    local pixelX = x * frameWidth
    local pixelY = -y * frameHeight
    
    -- Position text
    overlayText:ClearAllPoints()
    overlayText:SetPoint("CENTER", WorldMapFrame, "TOPLEFT", pixelX, pixelY)
    
    -- Set text with XP bonus
    local bonusText = string.format("XP+%d%%", HotspotDisplayDB.xpBonus)
    overlayText:SetText("|cFFFFD700" .. bonusText .. "|r")
    
    -- Apply pulse effect
    if CONFIG.PULSE_ENABLED then
        overlayText:SetAlpha(pulseAlpha)
    else
        overlayText:SetAlpha(1.0)
    end
    
    overlayFrame:Show()
end

-- Pulse animation
local function UpdatePulse(elapsed)
    if not CONFIG.PULSE_ENABLED or not playerInHotspot then return end
    
    pulseAlpha = pulseAlpha + (pulseDirection * elapsed * 0.5)
    
    if pulseAlpha >= 1.0 then
        pulseAlpha = 1.0
        pulseDirection = -1
    elseif pulseAlpha <= 0.6 then
        pulseAlpha = 0.6
        pulseDirection = 1
    end
end

-- Main update function
local function OnUpdate(self, elapsed)
    lastCheckTime = lastCheckTime + elapsed
    
    -- Check hotspot status periodically
    if lastCheckTime >= CONFIG.CHECK_INTERVAL then
        lastCheckTime = 0
        
        local wasInHotspot = playerInHotspot
        playerInHotspot = PlayerHasHotspotBuff()
        
        -- Notify player when entering/leaving hotspot
        if playerInHotspot and not wasInHotspot then
            Print("You are in an XP Hotspot! Check your map.")
            PlaySound("AuctionWindowOpen")
        elseif not playerInHotspot and wasInHotspot then
            if overlayFrame then
                overlayFrame:Hide()
            end
        end
    end
    
    -- Update pulse animation
    UpdatePulse(elapsed)
    
    -- Update overlay if map is open
    if WorldMapFrame:IsShown() then
        UpdateOverlayPosition()
    end
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Print("Loaded v" .. ADDON_VERSION)
        Print("Type |cFFFFD700/hotspot|r for options")
        CreateOverlay()
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        CreateOverlay()
        playerInHotspot = PlayerHasHotspotBuff()
        
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        -- Parse world announcements about hotspots
        if string.match(message, "%[Hotspot%]") then
            if string.match(message, "appeared") then
                -- Parse XP bonus if mentioned
                local bonus = string.match(message, "%+(%d+)%%%% XP")
                if bonus then
                    HotspotDisplayDB.xpBonus = tonumber(bonus) or 100
                end
                Print("Hotspot spawned! Look for the buff icon.")
            elseif string.match(message, "expired") then
                playerInHotspot = false
                if overlayFrame then
                    overlayFrame:Hide()
                end
            end
        end
        
    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" then
            -- Recheck hotspot status when buffs change
            playerInHotspot = PlayerHasHotspotBuff()
        end
    end
end)

-- Hook WorldMapFrame to update overlay
eventFrame:SetScript("OnUpdate", OnUpdate)

-- Slash command
SLASH_HOTSPOT1 = "/hotspot"
SLASH_HOTSPOT2 = "/hotspots"
SlashCmdList["HOTSPOT"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "" or msg == "help" then
        Print("Commands:")
        Print("  |cFFFFD700/hotspot toggle|r - Enable/disable addon")
        Print("  |cFFFFD700/hotspot text|r - Toggle map text display")
        Print("  |cFFFFD700/hotspot size <number>|r - Set text size (10-30)")
        Print("  |cFFFFD700/hotspot status|r - Show current status")
        Print("  |cFFFFD700/hotspot reset|r - Reset to defaults")
        
    elseif msg == "toggle" then
        HotspotDisplayDB.enabled = not HotspotDisplayDB.enabled
        Print("Addon " .. (HotspotDisplayDB.enabled and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        UpdateOverlayPosition()
        
    elseif msg == "text" then
        HotspotDisplayDB.showText = not HotspotDisplayDB.showText
        Print("Map text " .. (HotspotDisplayDB.showText and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
        UpdateOverlayPosition()
        
    elseif string.match(msg, "^size%s+(%d+)") then
        local size = tonumber(string.match(msg, "^size%s+(%d+)"))
        if size and size >= 10 and size <= 30 then
            HotspotDisplayDB.textSize = size
            if overlayText then
                overlayText:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
            end
            Print("Text size set to " .. size)
            UpdateOverlayPosition()
        else
            Print("Invalid size. Use a number between 10 and 30.")
        end
        
    elseif msg == "status" then
        Print("Status:")
        Print("  Enabled: " .. (HotspotDisplayDB.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        Print("  Show Text: " .. (HotspotDisplayDB.showText and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        Print("  Text Size: " .. HotspotDisplayDB.textSize)
        Print("  XP Bonus: +" .. HotspotDisplayDB.xpBonus .. "%")
        Print("  In Hotspot: " .. (playerInHotspot and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
        
    elseif msg == "reset" then
        HotspotDisplayDB = {
            enabled = true,
            showText = true,
            showMinimap = true,
            textSize = 16,
            xpBonus = 100,
        }
        if overlayText then
            overlayText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        end
        Print("Settings reset to defaults")
        UpdateOverlayPosition()
        
    else
        Print("Unknown command. Type |cFFFFD700/hotspot help|r for commands.")
    end
end

-- Initialize
Print("Initializing...")
