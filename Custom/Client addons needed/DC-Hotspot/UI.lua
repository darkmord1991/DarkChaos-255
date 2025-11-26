local addonName, addonTable = ...
addonTable = addonTable or {}
local UI = {}
addonTable.UI = UI

-- Track whether player is currently in a hotspot (based on server messages)
local playerInHotspot = false
local currentHotspotBonus = 100

local function SafePlaySound(sound)
    if not sound then return end
    local ok = pcall(PlaySound, sound)
    if not ok and type(sound) == "number" then
        pcall(PlaySound, sound, "Master")
    end
end

local function MapName(mapId)
    if not mapId then return "Unknown" end
    if GetMapNameByID then
        local name = GetMapNameByID(mapId)
        if name and name ~= "" then return name end
    end
    return string.format("Map %d", mapId)
end

local function FormatHotspotLine(id, info)
    local remain = info.expire and math.max(0, math.floor(info.expire - GetTime())) or 0
    local zone = info.zone or MapName(info.map)
    local bonus = info.bonus and ("+" .. info.bonus .. "%") or "+XP"
    return string.format("#%d  %s  %s  %ss", id, zone, bonus, remain)
end

-- Create the hotspot active indicator (shows when player is IN a hotspot)
local function CreateHotspotIndicator()
    local frame = CreateFrame("Frame", "DCHotspotActiveIndicator", UIParent)
    frame:SetSize(80, 80)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -20)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Background glow
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetSize(90, 90)
    frame.glow:SetPoint("CENTER")
    frame.glow:SetTexture("Interface\\Buttons\\CheckButtonGlow")
    frame.glow:SetVertexColor(1, 0.84, 0, 0.8)
    
    -- Icon
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(48, 48)
    frame.icon:SetPoint("TOP", frame, "TOP", 0, -4)
    frame.icon:SetTexture("Interface\\Icons\\Spell_Holy_SurgeOfLight")
    
    -- Border around icon
    frame.border = frame:CreateTexture(nil, "OVERLAY")
    frame.border:SetSize(52, 52)
    frame.border:SetPoint("CENTER", frame.icon, "CENTER")
    frame.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    frame.border:SetBlendMode("ADD")
    frame.border:SetVertexColor(1, 0.84, 0, 0.8)
    
    -- Bonus text
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("BOTTOM", frame, "BOTTOM", 0, 2)
    frame.text:SetText("|cFFFFD700+100% XP|r")
    frame.text:SetShadowColor(0, 0, 0, 1)
    frame.text:SetShadowOffset(1, -1)
    
    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFFFD700XP Hotspot Active|r", 1, 0.84, 0)
        GameTooltip:AddLine("You are inside an XP Hotspot zone!", 1, 1, 1)
        GameTooltip:AddLine(string.format("All XP gains are increased by %d%%", currentHotspotBonus), 0, 1, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Drag to move this indicator", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    -- Pulsing animation
    frame.pulseTime = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        self.pulseTime = self.pulseTime + elapsed
        local alpha = 0.5 + 0.3 * math.sin(self.pulseTime * 2)
        self.glow:SetAlpha(alpha)
    end)
    
    frame:Hide()
    return frame
end

-- Parse server messages to detect hotspot entry/exit
local function ParseHotspotMessages(message)
    -- Check for entry message: "[Hotspot] You have entered an XP Hotspot! +X% experience from kills!"
    local bonus = message:match("%[Hotspot%].*%+(%d+)%% experience")
    if bonus then
        return "enter", tonumber(bonus)
    end
    
    -- Also check for debug message that indicates entry
    local debugBonus = message:match("%[Hotspot DEBUG%].*applied buff")
    if debugBonus then
        return "enter", currentHotspotBonus
    end
    
    -- Check for exit message: "[Hotspot Notice] You have left the XP Hotspot zone"
    if message:match("%[Hotspot.*%] You have left") then
        return "exit", 0
    end
    
    -- Check for XP gain message to confirm we're in hotspot
    local xpBonus = message:match("%[Hotspot XP%].*%+(%d+) XP")
    if xpBonus then
        return "xpgain", currentHotspotBonus
    end
    
    return nil, nil
end

function UI:Init(state)
    self.state = state
    self:EnsurePopup()
    self:EnsureListFrame()
    self:EnsureHotspotIndicator()
    self:SetupMessageListener()

    SLASH_DCHOTSPOT1 = "/dchotspot"
    SLASH_DCHOTSPOT2 = "/dchs"
    SlashCmdList["DCHOTSPOT"] = function(msg)
        local command = (msg or ""):lower()
        if command == "options" or command == "config" or command == "settings" then
            if addonTable.Options and addonTable.Options.Open then
                addonTable.Options:Open()
            elseif addonTable.Options and addonTable.Options.panel and InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory(addonTable.Options.panel)
                InterfaceOptionsFrame_OpenToCategory(addonTable.Options.panel)
            end
            return
        end
        if command == "test" or command == "diag" or command == "debug" then
            -- Quick diagnostic
            local count = 0
            if UI.state and UI.state.hotspots then
                for id in pairs(UI.state.hotspots) do count = count + 1 end
            end
            print("|cffFFD700[DC-Hotspot] Diagnostic:|r")
            print(string.format("  Active hotspots: %d", count))
            print(string.format("  In hotspot: %s", tostring(playerInHotspot)))
            print(string.format("  Settings loaded: %s", tostring(UI.state and UI.state.db ~= nil)))
            if UI.state and UI.state.db then
                print(string.format("  Show world pins: %s", tostring(UI.state.db.showWorldPins)))
                print(string.format("  Show minimap pins: %s", tostring(UI.state.db.showMinimapPins)))
                print(string.format("  Debug mode: %s", tostring(UI.state.db.debug)))
            end
            if addonTable.Pins and addonTable.Pins.worldPins then
                local pinCount = 0
                for id in pairs(addonTable.Pins.worldPins) do pinCount = pinCount + 1 end
                print(string.format("  World pins created: %d", pinCount))
            end
            if count > 0 and UI.state and UI.state.hotspots then
                print("  Hotspot list:")
                for id, hs in pairs(UI.state.hotspots) do
                    print(string.format("    #%d: Continent %s, Zone %s, Pos (%.1f, %.1f)", 
                        id, tostring(hs.map), tostring(hs.zoneId), hs.x or 0, hs.y or 0))
                end
            end
            return
        end
        if command == "indicator" or command == "buff" then
            -- Toggle indicator visibility
            if self.indicator then
                if self.indicator:IsShown() then
                    self.indicator:Hide()
                    print("|cffFFD700[DC-Hotspot]|r Indicator hidden")
                else
                    self.indicator:Show()
                    print("|cffFFD700[DC-Hotspot]|r Indicator shown (for testing)")
                end
            end
            return
        end
        if self.listFrame:IsShown() then
            self.listFrame:Hide()
        else
            self.listFrame:Show()
            self:RefreshList()
        end
    end
end

-- Setup listener for server messages to detect hotspot entry/exit
function UI:SetupMessageListener()
    local messageFrame = CreateFrame("Frame")
    messageFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    messageFrame:SetScript("OnEvent", function(self, event, message)
        if event == "CHAT_MSG_SYSTEM" then
            local action, bonus = ParseHotspotMessages(message)
            if action == "enter" then
                playerInHotspot = true
                currentHotspotBonus = bonus or 100
                UI:ShowHotspotIndicator(bonus)
            elseif action == "exit" then
                playerInHotspot = false
                UI:HideHotspotIndicator()
            elseif action == "xpgain" and not playerInHotspot then
                -- We got XP bonus but weren't tracking - sync state
                playerInHotspot = true
                UI:ShowHotspotIndicator(currentHotspotBonus)
            end
        end
    end)
end

-- Ensure the hotspot indicator frame exists
function UI:EnsureHotspotIndicator()
    if self.indicator then return end
    self.indicator = CreateHotspotIndicator()
end

-- Show the hotspot indicator when player enters a hotspot
function UI:ShowHotspotIndicator(bonus)
    if not self.indicator then
        self:EnsureHotspotIndicator()
    end
    currentHotspotBonus = bonus or 100
    self.indicator.text:SetText(string.format("|cFFFFD700+%d%% XP|r", currentHotspotBonus))
    self.indicator:Show()
    
    -- Play a subtle sound
    SafePlaySound(SOUNDKIT and SOUNDKIT.UI_GARRISON_MISSION_COMPLETE or "PVPFLAGTAKEN")
end

-- Hide the hotspot indicator when player leaves a hotspot
function UI:HideHotspotIndicator()
    if self.indicator then
        self.indicator:Hide()
    end
end

-- Check if player is in hotspot (for external queries)
function UI:IsPlayerInHotspot()
    return playerInHotspot
end

function UI:EnsurePopup()
    if self.popup then return end
    local frame = CreateFrame("Frame", "DCHotspotPopup", UIParent)
    frame:SetSize(320, 90)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.85)
    frame:SetBackdropBorderColor(1, 0.84, 0, 1)
    frame:Hide()

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(48, 48)
    frame.icon:SetPoint("LEFT", frame, "LEFT", 10, 0)
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -6)
    frame.title:SetText("XP Hotspot Discovered")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)

    frame.timer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.timer:SetPoint("TOPLEFT", frame.subtitle, "BOTTOMLEFT", 0, -6)

    frame.closeTime = 0
    frame.remaining = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() then return end
        self.remaining = self.remaining - elapsed
        if self.remaining <= 0 then
            self:Hide()
        end
    end)

    self.popup = frame
end

function UI:ShowPopup(info)
    if not self.state or not self.state.db then return end
    if self.state.db.showPopup == false then return end
    local frame = self.popup
    if not frame then return end
    frame.icon:SetTexture(info.texture or "Interface\\Icons\\INV_Misc_Map_01")
    local zone = info.zone or MapName(info.map)
    frame.subtitle:SetText(zone)
    local remain = info.expire and math.max(0, math.floor(info.expire - GetTime())) or 0
    frame.timer:SetText(string.format("Expires in %s sec", remain))
    frame:SetAlpha(1)
    frame.remaining = self.state.db.popupDuration or 4
    frame:Show()
end

function UI:EnsureListFrame()
    if self.listFrame then return end
    local f = CreateFrame("Frame", "DCHotspotList", UIParent)
    f:SetSize(320, 220)
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(1, 0.84, 0, 1)
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -12)
    f.title:SetText("Active Hotspots")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.close:SetScript("OnClick", function() f:Hide() end)

    f.rows = {}
    for i = 1, 8 do
        local row = CreateFrame("Button", nil, f)
        row:SetSize(280, 20)
        row:SetPoint("TOP", f, "TOP", 0, -34 - (i - 1) * 24)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text:SetJustifyH("LEFT")
        row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight", "ADD")
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", function()
            if not row.hotspotId then return end
            UI:CenterOnHotspot(row.hotspotId)
        end)
        f.rows[i] = row
    end

    self.listFrame = f
end

function UI:CenterOnHotspot(id)
    if not self.state then return end
    local data = self.state.hotspots[id]
    if not data then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then ToggleWorldMap() end
    if SetMapByID and data.map then
        pcall(SetMapByID, data.map)
    end
    if not WorldMapFrame then return end
    local nx, ny = data.nx, data.ny
    if not nx or not ny then return end
    local scroll = WorldMapFrame.ScrollContainer
    if scroll and scroll.ScrollToNormalized and scroll.SetPanTarget then
        scroll:ScrollToNormalized(nx, ny)
    elseif scroll and scroll.SetHorizontalScroll then
        local canvas = scroll:GetCanvas()
        if canvas then
            local width, height = canvas:GetWidth(), canvas:GetHeight()
            scroll:SetHorizontalScroll(nx * width - WorldMapFrame:GetWidth() / 2)
            scroll:SetVerticalScroll(ny * height - WorldMapFrame:GetHeight() / 2)
        end
    end
end

function UI:RefreshList()
    if not self.state then return end
    if not self.listFrame or not self.listFrame:IsShown() then return end
    local sorted = {}
    for id, info in pairs(self.state.hotspots) do
        table.insert(sorted, { id = id, info = info })
    end
    table.sort(sorted, function(a, b)
        local ea = a.info.expire or 0
        local eb = b.info.expire or 0
        if ea == eb then return a.id < b.id end
        return ea < eb
    end)

    for i, row in ipairs(self.listFrame.rows) do
        local entry = sorted[i]
        if entry then
            row.hotspotId = entry.id
            row.text:SetText(FormatHotspotLine(entry.id, entry.info))
            row:Show()
        else
            row.hotspotId = nil
            row.text:SetText("")
            row:Hide()
        end
    end
end

function UI:OnHotspotSpawn(id, info)
    if not self.state or not self.state.db then
        return
    end
    if self.state.db.announce then
        local zone = info.zone or MapName(info.map)
        local bonus = info.bonus or (self.state.config and self.state.config.experienceBonus) or 0
        local message = string.format("|cFFFFD700[Hotspot]|r %s (+%d%% XP)", zone, bonus)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end
        if RaidNotice_AddMessage then
            RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
        end
        SafePlaySound(self.state.db.spawnSound)
    end
    self:ShowPopup({
        zone = info.zone or MapName(info.map),
        map = info.map,
        expire = info.expire,
        texture = info.tex and info.tex or (info.icon and GetSpellTexture and GetSpellTexture(info.icon)),
    })
    self:RefreshList()
end

function UI:OnHotspotExpire(id)
    if not self.state or not self.state.db then
        return
    end
    if self.state.db.announceExpire and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFA000[Hotspot]|r One of the XP hotspots expired.")
    end
    SafePlaySound(self.state.db.expireSound)
    self:RefreshList()
end

function UI:OnHotspotsChanged()
    self:RefreshList()
end

return UI
