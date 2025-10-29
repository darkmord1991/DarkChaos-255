-- DCHotspotXP - Enhanced Announcements Module
local ADDON_NAME = "HotspotDisplay"
_G.HotspotAnnouncements = _G.HotspotAnnouncements or {}
local Announcer = _G.HotspotAnnouncements

-- Configuration
Announcer.config = {
    enableChat = true,
    enablePopup = true,
    enableSound = true,
    enableRaidWarning = false,  -- Disabled by default (can be spam)
    popupDuration = 5,
    soundSpawn = "RaidWarning",
    soundExpire = "AuctionWindowClose",
}

-- Zone name lookup (WoW 3.3.5a map IDs)
local zoneNames = {
    [0] = "Eastern Kingdoms",
    [1] = "Kalimdor",
    [530] = "Outland",
    [571] = "Northrend",
    -- Add more as needed
}

-- Get zone name from map ID
local function GetZoneName(mapID)
    if not mapID then return "Unknown Zone" end
    
    -- Try to get zone name from current map
    local currentMap = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
    if currentMap == mapID then
        local zoneName = GetZoneText()
        if zoneName and zoneName ~= "" then
            return zoneName
        end
    end
    
    -- Fallback to lookup table
    return zoneNames[mapID] or string.format("Zone %d", mapID)
end

-- Get subzone/area name
local function GetAreaName()
    local subzone = GetSubZoneText()
    if subzone and subzone ~= "" then
        return subzone
    end
    return GetZoneText() or "Unknown Area"
end

-- Popup frame
local popupFrame = nil

-- Create popup notification frame
local function CreatePopupFrame()
    if popupFrame then return popupFrame end
    
    popupFrame = CreateFrame("Frame", "HotspotAnnouncementPopup", UIParent)
    popupFrame:SetSize(350, 100)
    popupFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
    popupFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    popupFrame:SetBackdropColor(0, 0, 0, 0.85)
    popupFrame:SetBackdropBorderColor(1, 0.84, 0, 1)
    popupFrame:SetFrameStrata("DIALOG")
    popupFrame:SetAlpha(0)
    popupFrame:Hide()
    
    -- Icon
    popupFrame.icon = popupFrame:CreateTexture(nil, "ARTWORK")
    popupFrame.icon:SetSize(48, 48)
    popupFrame.icon:SetPoint("LEFT", popupFrame, "LEFT", 12, 0)
    popupFrame.icon:SetTexture("Interface\\Icons\\Spell_Holy_BorrowedTime")
    
    -- Title
    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    popupFrame.title:SetPoint("TOPLEFT", popupFrame.icon, "TOPRIGHT", 12, -4)
    popupFrame.title:SetWidth(260)
    popupFrame.title:SetJustifyH("LEFT")
    popupFrame.title:SetText("|cFFFFD700XP Hotspot Spawned!|r")
    
    -- Location
    popupFrame.location = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popupFrame.location:SetPoint("TOPLEFT", popupFrame.title, "BOTTOMLEFT", 0, -4)
    popupFrame.location:SetWidth(260)
    popupFrame.location:SetJustifyH("LEFT")
    popupFrame.location:SetText("Location: Unknown")
    
    -- Coordinates
    popupFrame.coords = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popupFrame.coords:SetPoint("TOPLEFT", popupFrame.location, "BOTTOMLEFT", 0, -2)
    popupFrame.coords:SetWidth(260)
    popupFrame.coords:SetJustifyH("LEFT")
    popupFrame.coords:SetText("Coords: --.--, --.-")
    
    -- Duration
    popupFrame.duration = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    popupFrame.duration:SetPoint("BOTTOMLEFT", popupFrame.icon, "BOTTOMRIGHT", 12, 4)
    popupFrame.duration:SetWidth(260)
    popupFrame.duration:SetJustifyH("LEFT")
    popupFrame.duration:SetText("Duration: -- minutes")
    
    -- Close timer
    popupFrame.closeTimer = 0
    
    return popupFrame
end

-- Show popup notification
local function ShowPopup(hotspot)
    if not Announcer.config.enablePopup then return end
    if not popupFrame then CreatePopupFrame() end
    
    -- Update icon
    if hotspot.icon and GetSpellTexture then
        local tex = GetSpellTexture(hotspot.icon)
        if tex then
            popupFrame.icon:SetTexture(tex)
        end
    end
    
    -- Update location
    local zoneName = GetZoneName(hotspot.map)
    local areaName = hotspot.zone or GetAreaName()
    popupFrame.location:SetText(string.format("|cFFFFFFFFLocation:|r %s (%s)", areaName, zoneName))
    
    -- Update coordinates
    popupFrame.coords:SetText(string.format("|cFFFFFFFFCoords:|r |cFFFFD700%.1f, %.1f|r", hotspot.x, hotspot.y))
    
    -- Update duration
    local durationSec = math.max(0, hotspot.expire - GetTime())
    local durationMin = math.floor(durationSec / 60)
    popupFrame.duration:SetText(string.format("|cFFFFFFFFDuration:|r %d minute%s", durationMin, durationMin ~= 1 and "s" or ""))
    
    -- Fade in animation
    popupFrame.closeTimer = Announcer.config.popupDuration
    popupFrame:Show()
    
    -- Animate fade in
    UIFrameFadeIn(popupFrame, 0.3, 0, 1)
end

-- Hide popup
local function HidePopup()
    if not popupFrame then return end
    UIFrameFadeOut(popupFrame, 0.5, 1, 0)
    C_Timer.After(0.6, function()
        if popupFrame then popupFrame:Hide() end
    end)
end

-- Announce hotspot spawn
function Announcer.AnnounceSpawn(id, hotspot)
    if not (HotspotDisplayDB and HotspotDisplayDB.enabled) then return end
    if not hotspot then return end
    
    local zoneName = GetZoneName(hotspot.map)
    local areaName = hotspot.zone or "Unknown Area"
    local durationMin = math.floor((hotspot.expire - GetTime()) / 60)
    
    -- Chat announcement
    if Announcer.config.enableChat and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700═══════════════════════════════════|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700    XP HOTSPOT SPAWNED!    |r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700═══════════════════════════════════|r")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFFFFFLocation:|r %s (%s)", areaName, zoneName))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFFFFFCoordinates:|r |cFFFFD700%.1f, %.1f|r", hotspot.x, hotspot.y))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFFFFFDuration:|r %d minute%s", durationMin, durationMin ~= 1 and "s" or ""))
        DEFAULT_CHAT_FRAME:AddMessage("|cFFAAFFAAHead there now for bonus XP!|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700═══════════════════════════════════|r")
    end
    
    -- Popup notification
    ShowPopup(hotspot)
    
    -- Sound alert
    if Announcer.config.enableSound and Announcer.config.soundSpawn then
        PlaySound(Announcer.config.soundSpawn)
    end
    
    -- Raid warning (if enabled)
    if Announcer.config.enableRaidWarning then
        RaidNotice_AddMessage(RaidWarningFrame, 
            string.format("XP Hotspot: %s (%.1f, %.1f)", areaName, hotspot.x, hotspot.y),
            ChatTypeInfo["RAID_WARNING"])
    end
end

-- Announce hotspot expiration
function Announcer.AnnounceExpire(id, hotspot)
    if not (HotspotDisplayDB and HotspotDisplayDB.enabled) then return end
    
    -- Chat announcement
    if Announcer.config.enableChat and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[Hotspot]|r XP Hotspot expired!")
    end
    
    -- Sound alert
    if Announcer.config.enableSound and Announcer.config.soundExpire then
        PlaySound(Announcer.config.soundExpire)
    end
    
    HidePopup()
end

-- Announce hotspot warning (30 seconds left)
function Announcer.AnnounceWarning(id, hotspot, secondsLeft)
    if not (HotspotDisplayDB and HotspotDisplayDB.enabled) then return end
    
    if Announcer.config.enableChat and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFAA00[Hotspot]|r XP Hotspot expiring in %d seconds!", secondsLeft))
    end
end

-- Update popup timer
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not popupFrame or not popupFrame:IsShown() then return end
    
    popupFrame.closeTimer = popupFrame.closeTimer - elapsed
    if popupFrame.closeTimer <= 0 then
        HidePopup()
    end
end)

-- Slash commands for testing
SLASH_HOTSPOTANNOUNCE1 = "/hotspotannounce"
SlashCmdList["HOTSPOTANNOUNCE"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "test" then
        local testHotspot = {
            id = 999,
            map = GetCurrentMapAreaID(),
            zone = GetAreaName(),
            x = 45.5,
            y = 67.2,
            expire = GetTime() + 600,
            icon = 23768,
        }
        Announcer.AnnounceSpawn(999, testHotspot)
    elseif msg == "expire" then
        Announcer.AnnounceExpire(999, {})
    elseif msg == "toggle chat" then
        Announcer.config.enableChat = not Announcer.config.enableChat
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[Hotspot]|r Chat announcements: %s",
            Announcer.config.enableChat and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif msg == "toggle popup" then
        Announcer.config.enablePopup = not Announcer.config.enablePopup
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[Hotspot]|r Popup notifications: %s",
            Announcer.config.enablePopup and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    elseif msg == "toggle sound" then
        Announcer.config.enableSound = not Announcer.config.enableSound
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[Hotspot]|r Sound alerts: %s",
            Announcer.config.enableSound and "|cFF00FF00enabled|r" or "|cFFFF0000disabled|r"))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot Announcements]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspotannounce test - Show test announcement")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspotannounce expire - Test expiration")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspotannounce toggle chat - Toggle chat announcements")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspotannounce toggle popup - Toggle popup notifications")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspotannounce toggle sound - Toggle sound alerts")
    end
end

-- Initialize
CreatePopupFrame()

return Announcer
