-- DCHotspotXP - Proximity Detection & Timer Module
local ADDON_NAME = "HotspotDisplay"
local HLBG = _G.HLBG or {}
_G.HotspotProximity = _G.HotspotProximity or {}
local Proximity = _G.HotspotProximity

-- Configuration
Proximity.config = {
    checkInterval = 0.5,  -- Check every 0.5 seconds
    alertDistance = 100,  -- Yards to trigger "nearby" alert
    activeDistance = 20,  -- Yards to show timer
    soundOnEntry = "AuctionWindowOpen",
    soundOnExit = "AuctionWindowClose",
    soundOnExpire = "RaidWarning",
}

-- State
Proximity.lastCheck = 0
Proximity.currentHotspot = nil
Proximity.isInHotspot = false
Proximity.nearbyHotspots = {}

-- Timer Frame
local timerFrame = nil

-- Create Timer Frame
local function CreateTimerFrame()
    if timerFrame then return timerFrame end
    
    timerFrame = CreateFrame("Frame", "HotspotProximityTimer", UIParent)
    timerFrame:SetSize(220, 60)
    timerFrame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    timerFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    timerFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    timerFrame:SetBackdropBorderColor(1, 0.84, 0, 1)  -- Gold border
    timerFrame:SetFrameStrata("HIGH")
    timerFrame:Hide()
    
    -- Icon
    timerFrame.icon = timerFrame:CreateTexture(nil, "ARTWORK")
    timerFrame.icon:SetSize(32, 32)
    timerFrame.icon:SetPoint("LEFT", timerFrame, "LEFT", 8, 0)
    timerFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    
    -- Title
    timerFrame.title = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerFrame.title:SetPoint("TOPLEFT", timerFrame.icon, "TOPRIGHT", 8, -4)
    timerFrame.title:SetText("|cFFFFD700XP Hotspot|r")
    
    -- Timer text
    timerFrame.timer = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timerFrame.timer:SetPoint("BOTTOMLEFT", timerFrame.icon, "BOTTOMRIGHT", 8, 4)
    timerFrame.timer:SetText("--:--")
    
    -- Distance text
    timerFrame.distance = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerFrame.distance:SetPoint("TOPRIGHT", timerFrame, "TOPRIGHT", -8, -8)
    timerFrame.distance:SetText("")
    
    -- Pulse animation
    timerFrame.pulseAlpha = 1.0
    timerFrame.pulseDirection = -1
    
    return timerFrame
end

-- Calculate distance to hotspot
local function CalculateDistance(px, py, hx, hy)
    if not (px and py and hx and hy) or (px == 0 and py == 0) then
        return nil
    end
    
    -- Normalize coordinates
    local hx_n = tonumber(hx) or 0
    local hy_n = tonumber(hy) or 0
    if hx_n > 1 then hx_n = hx_n / 100 end
    if hy_n > 1 then hy_n = hy_n / 100 end
    
    local dx = (hx_n - px) * 10000  -- Approximate yards (zone-dependent)
    local dy = (hy_n - py) * 10000
    local distance = math.sqrt(dx * dx + dy * dy)
    
    return distance
end

-- Update timer display
local function UpdateTimer(hotspot)
    if not timerFrame then CreateTimerFrame() end
    if not hotspot then
        timerFrame:Hide()
        return
    end
    
    local remaining = math.max(0, hotspot.expire - GetTime())
    local minutes = math.floor(remaining / 60)
    local seconds = math.floor(remaining % 60)
    
    -- Update timer text
    timerFrame.timer:SetText(string.format("|cFFFFFFFF%02d:%02d|r", minutes, seconds))
    
    -- Update icon if available
    if hotspot.icon and GetSpellTexture then
        local tex = GetSpellTexture(hotspot.icon)
        if tex then
            timerFrame.icon:SetTexture(tex)
        end
    end
    
    -- Pulse animation when expiring soon
    if remaining < 30 then
        timerFrame.pulseAlpha = timerFrame.pulseAlpha + (timerFrame.pulseDirection * 0.03)
        if timerFrame.pulseAlpha >= 1.0 then
            timerFrame.pulseAlpha = 1.0
            timerFrame.pulseDirection = -1
        elseif timerFrame.pulseAlpha <= 0.5 then
            timerFrame.pulseAlpha = 0.5
            timerFrame.pulseDirection = 1
        end
        timerFrame:SetAlpha(timerFrame.pulseAlpha)
    else
        timerFrame:SetAlpha(1.0)
    end
    
    timerFrame:Show()
end

-- Check proximity to all active hotspots
function Proximity.CheckProximity()
    if not (HotspotDisplayDB and HotspotDisplayDB.enabled) then return end
    if not _G.activeHotspots or type(_G.activeHotspots) ~= "table" then return end
    
    local px, py = GetPlayerMapPosition("player")
    if not px or not py or (px == 0 and py == 0) then
        -- Try to get position from current map
        SetMapToCurrentZone()
        px, py = GetPlayerMapPosition("player")
    end
    
    if not px or not py or (px == 0 and py == 0) then
        return  -- Can't determine position
    end
    
    local playerMap = GetCurrentMapAreaID and GetCurrentMapAreaID() or nil
    local closestHotspot = nil
    local closestDistance = 999999
    
    -- Clear nearby list
    Proximity.nearbyHotspots = {}
    
    -- Check each hotspot
    for id, hotspot in pairs(_G.activeHotspots) do
        -- Only check hotspots in same zone
        if hotspot.map and playerMap and tonumber(hotspot.map) == tonumber(playerMap) then
            local distance = CalculateDistance(px, py, hotspot.x, hotspot.y)
            
            if distance and distance < Proximity.config.alertDistance then
                table.insert(Proximity.nearbyHotspots, {
                    id = id,
                    hotspot = hotspot,
                    distance = distance
                })
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestHotspot = hotspot
                    closestHotspot.id = id
                    closestHotspot.distance = distance
                end
            end
        end
    end
    
    -- Handle entry/exit from active zone
    if closestHotspot and closestDistance < Proximity.config.activeDistance then
        if not Proximity.isInHotspot or (Proximity.currentHotspot and Proximity.currentHotspot.id ~= closestHotspot.id) then
            -- Entering hotspot or switching hotspots
            Proximity.isInHotspot = true
            Proximity.currentHotspot = closestHotspot
            
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFD700[Hotspot]|r Entered XP Hotspot! Bonus active for %d seconds",
                    math.floor(closestHotspot.expire - GetTime())))
            end
            
            if Proximity.config.soundOnEntry then
                PlaySound(Proximity.config.soundOnEntry)
            end
        end
        
        -- Update timer
        UpdateTimer(closestHotspot)
        
        -- Update distance display
        if timerFrame and timerFrame.distance then
            timerFrame.distance:SetText(string.format("|cFFAAFFAA%.0f yds|r", closestDistance))
        end
    else
        -- Not in active hotspot
        if Proximity.isInHotspot then
            -- Just left hotspot
            Proximity.isInHotspot = false
            
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r Left XP Hotspot zone")
            end
            
            if Proximity.config.soundOnExit then
                PlaySound(Proximity.config.soundOnExit)
            end
        end
        
        Proximity.currentHotspot = nil
        UpdateTimer(nil)  -- Hide timer
    end
end

-- OnUpdate handler
local proximityFrame = CreateFrame("Frame")
proximityFrame:SetScript("OnUpdate", function(self, elapsed)
    Proximity.lastCheck = Proximity.lastCheck + elapsed
    
    if Proximity.lastCheck >= Proximity.config.checkInterval then
        Proximity.lastCheck = 0
        Proximity.CheckProximity()
    end
end)

-- Initialize
CreateTimerFrame()

-- Slash command to toggle timer
SLASH_HOTSPOTTIMER1 = "/hotspottimer"
SlashCmdList["HOTSPOTTIMER"] = function(msg)
    msg = string.lower(msg or "")
    
    if msg == "show" then
        if timerFrame then timerFrame:Show() end
    elseif msg == "hide" then
        if timerFrame then timerFrame:Hide() end
    elseif msg == "test" then
        -- Test mode: create fake hotspot
        local testHotspot = {
            id = 999,
            map = GetCurrentMapAreaID(),
            zone = "Test Zone",
            x = 50,
            y = 50,
            expire = GetTime() + 300,
            icon = 23768,
            distance = 15
        }
        UpdateTimer(testHotspot)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot]|r Test timer shown for 5 minutes")
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD700[Hotspot Timer]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspottimer show - Show timer")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspottimer hide - Hide timer")
        DEFAULT_CHAT_FRAME:AddMessage("  /hotspottimer test - Show test timer")
    end
end

return Proximity
