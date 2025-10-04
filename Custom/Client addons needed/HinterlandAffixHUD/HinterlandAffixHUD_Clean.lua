-- HinterlandAffixHUD_Clean.lua - Consolidated main addon file
-- Compatible with WotLK 3.3.5a client

local ADDON_NAME = "HinterlandAffixHUD"

-- Initialize namespace
local HLBG = {}
_G.HLBG = HLBG

-- Initialize saved variables
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {
    disableChatUpdates = true,
    showHUD = true,
    hudPosition = {point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -50, y = -150},
    hudScale = 1.0,
    affixPosition = {point = "TOPLEFT", relPoint = "TOPLEFT", x = 30, y = -150}
}

-- Constants
local AFFIX_WORLDSTATE = 0xDD1010
local ZONE_HINTERLANDS = "The Hinterlands"

-- Affix data
local AFFIX_DATA = {
    [1] = {name = "Bloodlust", icon = "Interface\\Icons\\Spell_Nature_BloodLust"},
    [2] = {name = "Storms", icon = "Interface\\Icons\\Spell_Nature_Lightning"},
    [3] = {name = "Frenzy", icon = "Interface\\Icons\\Ability_Druid_Berserk"},
    [4] = {name = "Plague", icon = "Interface\\Icons\\Spell_Shadow_CallofBone"},
    [5] = {name = "Blight", icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion"}
}

-- Utility functions
local function GetAffixName(code)
    local num = tonumber(code)
    if num and AFFIX_DATA[num] then
        return AFFIX_DATA[num].name
    end
    return tostring(code or "Unknown")
end

local function GetAffixIcon(code)
    local num = tonumber(code)
    if num and AFFIX_DATA[num] then
        return AFFIX_DATA[num].icon
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function IsInHinterlands()
    local zone = GetRealZoneText()
    return zone == ZONE_HINTERLANDS
end

local function SecondsToClock(seconds)
    if not seconds or seconds < 0 then return "0:00" end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

-- HUD Frame for resource display
local hudFrame = CreateFrame("Frame", "HLBG_HUD", UIParent)
hudFrame:SetSize(240, 92)
hudFrame:SetMovable(true)
hudFrame:EnableMouse(true)
hudFrame:RegisterForDrag("LeftButton")
hudFrame:SetClampedToScreen(true)

-- Set HUD backdrop (3.3.5a compatible)
hudFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
hudFrame:SetBackdropColor(0, 0, 0, 0.8)

-- HUD positioning
local pos = HinterlandAffixHUDDB.hudPosition
hudFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
hudFrame:SetScale(HinterlandAffixHUDDB.hudScale)

-- HUD drag scripts
hudFrame:SetScript("OnDragStart", function(self)
    if not HinterlandAffixHUDDB.locked then
        self:StartMoving()
    end
end)

hudFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    HinterlandAffixHUDDB.hudPosition = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y
    }
end)

-- HUD text elements
hudFrame.allianceText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
hudFrame.allianceText:SetPoint("TOPRIGHT", -8, -8)
hudFrame.allianceText:SetText("|TInterface/TargetingFrame/UI-PVP-ALLIANCE:16|t Alliance: 0/450")

hudFrame.hordeText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
hudFrame.hordeText:SetPoint("TOPRIGHT", hudFrame.allianceText, "BOTTOMRIGHT", 0, -6)
hudFrame.hordeText:SetText("|TInterface/TargetingFrame/UI-PVP-HORDE:16|t Horde: 0/450")

hudFrame.timerText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
hudFrame.timerText:SetPoint("TOPRIGHT", hudFrame.hordeText, "BOTTOMRIGHT", 0, -6)
hudFrame.timerText:SetText("Time: --:--")

-- Affix display frame
local affixFrame = CreateFrame("Frame", "HLBG_AffixDisplay", UIParent)
affixFrame:SetSize(320, 40)
affixFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
affixFrame:SetBackdropColor(0.1, 0.1, 0.4, 0.8)

local affixPos = HinterlandAffixHUDDB.affixPosition
affixFrame:SetPoint(affixPos.point, UIParent, affixPos.relPoint, affixPos.x, affixPos.y)

affixFrame.icon = affixFrame:CreateTexture(nil, "OVERLAY")
affixFrame.icon:SetSize(32, 32)
affixFrame.icon:SetPoint("LEFT", 8, 0)

affixFrame.text = affixFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
affixFrame.text:SetPoint("LEFT", affixFrame.icon, "RIGHT", 8, 0)
affixFrame.text:SetText("No Affix Active")

-- Hide frames initially
hudFrame:Hide()
affixFrame:Hide()

-- Data storage
HLBG.currentStatus = {
    alliance = 0,
    horde = 0,
    timeLeft = 0,
    affix = nil,
    inProgress = false
}

-- Update HUD display
local function UpdateHUD()
    if not HinterlandAffixHUDDB.showHUD then
        hudFrame:Hide()
        return
    end

    local status = HLBG.currentStatus
    hudFrame.allianceText:SetText(string.format("|TInterface/TargetingFrame/UI-PVP-ALLIANCE:16|t Alliance: %d/450", status.alliance))
    hudFrame.hordeText:SetText(string.format("|TInterface/TargetingFrame/UI-PVP-HORDE:16|t Horde: %d/450", status.horde))
    
    if status.timeLeft and status.timeLeft > 0 then
        hudFrame.timerText:SetText("Time Left: " .. SecondsToClock(status.timeLeft))
    else
        hudFrame.timerText:SetText("Time: --:--")
    end
    
    hudFrame:Show()
end

-- Update affix display
local function UpdateAffix(affixCode)
    if not affixCode then
        affixFrame:Hide()
        return
    end
    
    local name = GetAffixName(affixCode)
    local icon = GetAffixIcon(affixCode)
    
    affixFrame.text:SetText("Active Affix: " .. name)
    affixFrame.icon:SetTexture(icon)
    affixFrame:Show()
    
    HLBG.currentStatus.affix = affixCode
end

-- Hide default Blizzard HUD
local function HideBlizzardHUD()
    if WorldStateAlwaysUpFrame then
        WorldStateAlwaysUpFrame:Hide()
        
        if not WorldStateAlwaysUpFrame.hlbgHooked then
            WorldStateAlwaysUpFrame.hlbgHooked = true
            WorldStateAlwaysUpFrame:HookScript("OnShow", function(self)
                if HinterlandAffixHUDDB.showHUD then
                    self:Hide()
                end
            end)
        end
    end
end

-- Show default Blizzard HUD
local function ShowBlizzardHUD()
    if WorldStateAlwaysUpFrame then
        WorldStateAlwaysUpFrame:Show()
    end
end

-- Zone change handler
local function OnZoneChanged()
    if IsInHinterlands() then
        if HLBG.currentStatus.inProgress then
            UpdateHUD()
        end
        if HLBG.currentStatus.affix then
            UpdateAffix(HLBG.currentStatus.affix)
        end
        if HinterlandAffixHUDDB.showHUD then
            HideBlizzardHUD()
        end
    else
        hudFrame:Hide()
        affixFrame:Hide()
        ShowBlizzardHUD()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            -- Addon loaded, set up saved variables
            if not HinterlandAffixHUDDB.initialized then
                HinterlandAffixHUDDB.initialized = true
                print("|cFF00FF00[HLBG]|r Hinterland Battleground HUD loaded")
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" or 
           event == "ZONE_CHANGED_NEW_AREA" or 
           event == "ZONE_CHANGED" or 
           event == "ZONE_CHANGED_INDOORS" then
        OnZoneChanged()
    end
end)

-- Public API
function HLBG.UpdateStatus(data)
    if type(data) ~= "table" then return end
    
    local status = HLBG.currentStatus
    status.alliance = tonumber(data.A) or status.alliance
    status.horde = tonumber(data.H) or status.horde
    status.timeLeft = tonumber(data.timeLeft) or tonumber(data.END) and (tonumber(data.END) - time()) or 0
    status.inProgress = true
    
    if data.affix then
        UpdateAffix(data.affix)
    end
    
    UpdateHUD()
end

function HLBG.SetAffix(affixCode)
    UpdateAffix(affixCode)
end

function HLBG.ToggleHUD()
    HinterlandAffixHUDDB.showHUD = not HinterlandAffixHUDDB.showHUD
    if HinterlandAffixHUDDB.showHUD then
        UpdateHUD()
        if IsInHinterlands() then
            HideBlizzardHUD()
        end
    else
        hudFrame:Hide()
        ShowBlizzardHUD()
    end
    print("|cFF00FF00[HLBG]|r HUD " .. (HinterlandAffixHUDDB.showHUD and "enabled" or "disabled"))
end

function HLBG.ResetPosition()
    HinterlandAffixHUDDB.hudPosition = {point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -50, y = -150}
    HinterlandAffixHUDDB.affixPosition = {point = "TOPLEFT", relPoint = "TOPLEFT", x = 30, y = -150}
    
    local hudPos = HinterlandAffixHUDDB.hudPosition
    local affixPos = HinterlandAffixHUDDB.affixPosition
    
    hudFrame:ClearAllPoints()
    hudFrame:SetPoint(hudPos.point, UIParent, hudPos.relPoint, hudPos.x, hudPos.y)
    
    affixFrame:ClearAllPoints()
    affixFrame:SetPoint(affixPos.point, UIParent, affixPos.relPoint, affixPos.x, affixPos.y)
    
    print("|cFF00FF00[HLBG]|r Positions reset to default")
end

-- Slash commands
SLASH_HLBGHUD1 = "/hlbghud"
SlashCmdList["HLBGHUD"] = function(msg)
    local command = string.lower(msg or "")
    
    if command == "toggle" then
        HLBG.ToggleHUD()
    elseif command == "reset" then
        HLBG.ResetPosition()
    elseif command == "test" then
        HLBG.UpdateStatus({A = 250, H = 180, timeLeft = 900})
        HLBG.SetAffix(1)
        print("|cFF00FF00[HLBG]|r Test data loaded")
    else
        print("|cFF00FF00[HLBG]|r Commands:")
        print("  /hlbghud toggle - Toggle HUD display")
        print("  /hlbghud reset - Reset positions")
        print("  /hlbghud test - Load test data")
    end
end

-- Export functions for AIO client
_G.HLBG = HLBG

if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG]|r Core loaded - Use /hlbghud for commands")
end