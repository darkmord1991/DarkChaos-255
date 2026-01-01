local addonName, addonTable = ...
addonTable = addonTable or {}
local UI = {}
addonTable.UI = UI

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-Mapupgrades\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.60

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then return end
    frame.__dcLeaderboardsStyle = true

    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetAllPoints()
    bg:SetTexture(BG_FELLEATHER)
    if bg.SetHorizTile then bg:SetHorizTile(false) end
    if bg.SetVertTile then bg:SetVertTile(false) end

    local tint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tint:SetAllPoints()
    tint:SetTexture(0, 0, 0, BG_TINT_ALPHA)

    frame.__dcBg = bg
    frame.__dcTint = tint
end

-- Track whether player is currently in a hotspot (based on server messages)
local playerInHotspot = false
local currentHotspotBonus = 100

local function PlayerCanGainXP()
    if not UnitXPMax then
        return true
    end
    local xpMax = UnitXPMax("player")
    -- On some servers (e.g., custom max level 255), the client can report 0 max XP at
    -- cap. Hotspots can still be useful then, so don't treat 0 as "cannot show".
    if xpMax == 0 then
        return true
    end
    if IsXPUserDisabled and IsXPUserDisabled() then
        return false
    end
    return xpMax and xpMax > 0
end

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

local function NormalizeZoneNameForMatch(name)
    if not name then return nil end
    name = tostring(name)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    return name:lower()
end

local function PlayerZoneNameForMatch()
    local name = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or nil
    return NormalizeZoneNameForMatch(name)
end

function UI:HotspotMatchesPlayerZone(info)
    if type(info) ~= "table" then
        return false
    end

    local playerZone = PlayerZoneNameForMatch()
    if not playerZone then
        return false
    end

    local hotspotZone = NormalizeZoneNameForMatch(info.zone)
    if hotspotZone and hotspotZone == playerZone then
        return true
    end

    if zoneId and GetMapNameByID then
        local zoneName = GetMapNameByID(zoneId)
        if NormalizeZoneNameForMatch(zoneName) == playerZone then
            return true
        end
    end

    return false
end

local function FormatHotspotLine(id, info)
    local remain = info.expire and math.max(0, math.floor(info.expire - GetTime())) or 0
    local zone = info.zone or MapName(info.map)
    local bonus = info.bonus and ("+" .. info.bonus .. "%") or "+XP"
    return string.format("#%d  %s  %s  %ss", id, zone, bonus, remain)
end

-- Create the hotspot active indicator (shows when player is IN a hotspot)
local function CreateHotspotIndicator()
    local frame = CreateFrame("Frame", "DCMapupgradesActiveIndicator", UIParent)
    frame:SetSize(120, 30)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -20)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Icon and other graphics removed as requested
    
    -- Bonus text
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
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

    local xpWatcher = CreateFrame("Frame")
    xpWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    xpWatcher:RegisterEvent("PLAYER_LEVEL_UP")
    xpWatcher:RegisterEvent("PLAYER_XP_UPDATE")
    xpWatcher:SetScript("OnEvent", function()
        if addonTable and addonTable.Pins and addonTable.Pins.Refresh then
            addonTable.Pins:Refresh()
        end

        if not PlayerCanGainXP() then
            playerInHotspot = false
            if UI.indicator then UI.indicator:Hide() end
            if UI.popup then UI.popup:Hide() end
            if UI.listFrame then UI.listFrame:Hide() end
        else
            UI:RefreshList()
        end
    end)

    SLASH_DCMAP1 = "/dcmap"
    SLASH_DCMAP2 = "/dcmapu"
    SLASH_DCHOTSPOT1 = "/dchotspot" -- legacy alias
    SLASH_DCHOTSPOT2 = "/dchs"      -- legacy alias

    local function Print(msg)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[DC-Mapupgrades]|r " .. (msg or ""))
        end
    end

    local function Words(s)
        s = tostring(s or "")
        local out = {}
        for w in s:gmatch("%S+") do
            table.insert(out, w)
        end
        return out
    end

    local function JoinFrom(tbl, startIndex)
        local parts = {}
        for i = startIndex, #tbl do
            table.insert(parts, tbl[i])
        end
        return table.concat(parts, " ")
    end

    local function HandleMapCommand(msg)
        local args = Words(msg)
        local sub = (args[1] or ""):lower()

        if sub == "add" then
            local kind = (args[2] or ""):lower()
            local name = JoinFrom(args, 3)
            local Core = addonTable and addonTable.Core
            if not Core or not Core.AddEntity then
                Print("Core not ready")
                return
            end
            local ent, err = Core:AddEntity(kind, name)
            if not ent then
                Print("Add failed: " .. tostring(err))
                Print("Usage: /dcmap add boss <name>  OR  /dcmap add rare <name>")
                return
            end
            Print(string.format("Added %s #%d: %s", tostring(ent.kind), tonumber(ent.id) or 0, tostring(ent.name)))
            return
        end

        if sub == "list" then
            local db = UI.state and UI.state.db
            local list = db and db.entities and db.entities.list
            if type(list) ~= "table" or #list == 0 then
                Print("No entities saved yet.")
                Print("Tip: /dcmap add boss <name> (adds at your current position)")
                return
            end
            Print("Saved entities:")
            for _, ent in ipairs(list) do
                if ent and ent.id and ent.kind and ent.name then
                    local coordText
                    if ent.mapId and ent.nx and ent.ny then
                        coordText = string.format("map %s @ %.3f, %.3f", tostring(ent.mapId), tonumber(ent.nx) or 0, tonumber(ent.ny) or 0)
                    else
                        coordText = "(no position set)"
                    end
                    local extra = ""
                    if ent.spawnId then extra = extra .. " spawnId=" .. tostring(ent.spawnId) end
                    if ent.entry then extra = extra .. " entry=" .. tostring(ent.entry) end
                    Print(string.format("  #%d  %s  %s  %s%s", ent.id, ent.kind, ent.name, coordText, extra))
                end
            end
            return
        end

        if sub == "setpos" then
            local id = tonumber(args[2] or "")
            if not id then
                Print("Usage: /dcmap setpos <id>")
                return
            end
            local Core = addonTable and addonTable.Core
            if not Core or not Core.SetEntityPosition then
                Print("Core not ready")
                return
            end
            local ok, err = Core:SetEntityPosition(id)
            if ok then
                Print("Updated position for entity #" .. tostring(id))
            else
                Print("Setpos failed: " .. tostring(err))
            end
            return
        end

        if sub == "resolve" then
            local id = tonumber(args[2] or "")
            if not id then
                Print("Usage: /dcmap resolve <id>")
                return
            end
            local Core = addonTable and addonTable.Core
            if not Core or not Core.ResolveEntityPosition then
                Print("Core not ready")
                return
            end
            local ok, err = Core:ResolveEntityPosition(id)
            if ok then
                Print("Requested resolve for entity #" .. tostring(id) .. " (waiting for server response)")
            else
                Print("Resolve request failed: " .. tostring(err))
            end
            return
        end

        if sub == "importbosses" or (sub == "import" and ((args[2] or ""):lower() == "bosses" or (args[2] or ""):lower() == "worldbosses")) then
            local Core = addonTable and addonTable.Core
            if not Core or not Core.ImportWorldBossesFromInfoBar then
                Print("Core not ready")
                return
            end
            local added, err = Core:ImportWorldBossesFromInfoBar()
            if err then
                Print("Import failed: " .. tostring(err))
                Print("DC-InfoBar must be installed and receiving boss data.")
                return
            end
            Print(string.format("Imported world bosses: %d added/updated.", tonumber(added) or 0))
            Print("If a boss shows '(no position set)', stand at its spawn and run /dcmap setpos <id> (optional override).")
            return
        end

        if sub == "del" or sub == "delete" or sub == "remove" then
            local id = tonumber(args[2] or "")
            if not id then
                Print("Usage: /dcmap del <id>")
                return
            end
            local Core = addonTable and addonTable.Core
            if Core and Core.RemoveEntity and Core:RemoveEntity(id) then
                Print("Removed entity #" .. tostring(id))
            else
                Print("Remove failed for #" .. tostring(id))
            end
            return
        end

        if sub == "active" or sub == "inactive" then
            local id = tonumber(args[2] or "")
            if not id then
                Print("Usage: /dcmap active <id>  OR  /dcmap inactive <id>")
                return
            end
            local Core = addonTable and addonTable.Core
            if not Core or not Core.SetEntityActive then
                Print("Core not ready")
                return
            end
            local ok = Core:SetEntityActive(id, sub == "active", "manual")
            if ok then
                Print(string.format("Entity #%d marked %s", id, sub))
            else
                Print("Failed to update entity #" .. tostring(id))
            end
            return
        end

        if sub == "debug" then
            -- Toggle debug mode
            if UI.state and UI.state.db then
                UI.state.db.debug = not UI.state.db.debug
                Print("Debug mode: " .. tostring(UI.state.db.debug))
                -- Force refresh of world pins to trigger debug output
                if addonTable.Pins and addonTable.Pins.UpdateWorldPins then
                    addonTable.Pins:UpdateWorldPins()
                end
            else
                Print("Settings not loaded")
            end
            return
        end

        if sub == "help" or sub == "" then
            Print("Commands:")
            Print("  /dcmap debug             (toggle debug output)")
            Print("  /dcmap add boss <name>   (adds spawn at your position)")
            Print("  /dcmap add rare <name>")
            Print("  /dcmap importbosses      (optional: import boss list/status from DC-InfoBar)")
            Print("  /dcmap list")
            Print("  /dcmap del <id>")
            Print("  /dcmap setpos <id>       (set pin position to your current location)")
            Print("  /dcmap resolve <id>      (ask server to resolve coords via spawnId/entry)")
            Print("  /dcmap active <id>")
            Print("  /dcmap inactive <id>")
            Print("  /dchotspot  (toggle hotspot list; legacy)")
            return
        end

        -- If we don't recognize it, fall back to hotspot command behavior.
        return false
    end

    SlashCmdList["DCMAP"] = function(msg)
        local handled = HandleMapCommand(msg)
        if handled == false then
            -- fallthrough: treat as hotspot UI toggle
            SlashCmdList["DCHOTSPOT"](msg)
        end
    end

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
            print("|cffFFD700[DC-Mapupgrades] Diagnostic:|r")
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
                    print("|cffFFD700[DC-Mapupgrades]|r Indicator hidden")
                else
                    self.indicator:Show()
                    print("|cffFFD700[DC-Mapupgrades]|r Indicator shown (for testing)")
                end
            end
            return
        end

        if not PlayerCanGainXP() then
            if self.indicator then self.indicator:Hide() end
            if self.popup then self.popup:Hide() end
            if self.listFrame then self.listFrame:Hide() end
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
        if not PlayerCanGainXP() then
            return
        end
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
    local frame = CreateFrame("Frame", "DCMapupgradesPopup", UIParent)
    frame:SetSize(320, 90)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(frame)
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
    local f = CreateFrame("Frame", "DCMapupgradesList", UIParent)
    f:SetSize(320, 220)
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ApplyLeaderboardsStyle(f)
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

    if not PlayerCanGainXP() then
        self.listFrame:Hide()
        return
    end

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

function UI:OnHotspotSpawn(id, info, shouldAnnounce)
    if not self.state or not self.state.db then
        return
    end

    if not PlayerCanGainXP() then
        return
    end
    
    -- Only announce if explicitly allowed (prevents spam on login)
    if shouldAnnounce and self.state.db.announce and self:HotspotMatchesPlayerZone(info) then
        local zone = info.zone or MapName(info.map)
        local bonus = info.bonus or (self.state.config and self.state.config.experienceBonus) or 0

        local message = string.format("|cFFFFD700[Hotspot]|r %s (+%d%% XP)", zone, bonus)

        -- Show in chat
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(message)
        end

        -- Center announce (RaidWarning)
        if RaidNotice_AddMessage then
            RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
        end
        SafePlaySound(self.state.db.spawnSound)
        
        -- Only show popup for truly new hotspots (not on login)
        self:ShowPopup({
            zone = info.zone or MapName(info.map),
            map = info.map,
            expire = info.expire,
            texture = info.tex and info.tex or (info.icon and GetSpellTexture and GetSpellTexture(info.icon)),
        })
    end
    
    self:RefreshList()

    if addonTable and addonTable.Pins and addonTable.Pins.Refresh then
        addonTable.Pins:Refresh()
    end
end

function UI:OnHotspotExpire(id, info)
    if not self.state or not self.state.db then
        return
    end

    if not PlayerCanGainXP() then
        return
    end
    if self.state.db.announceExpire and DEFAULT_CHAT_FRAME and self:HotspotMatchesPlayerZone(info) then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFA000[Hotspot]|r One of the XP hotspots expired.")
    end

    if self:HotspotMatchesPlayerZone(info) then
        SafePlaySound(self.state.db.expireSound)
    end
    self:RefreshList()

    if addonTable and addonTable.Pins and addonTable.Pins.Refresh then
        addonTable.Pins:Refresh()
    end
end

function UI:OnHotspotsChanged()
    if not PlayerCanGainXP() then
        return
    end
    self:RefreshList()

    if addonTable and addonTable.Pins and addonTable.Pins.Refresh then
        addonTable.Pins:Refresh()
    end
end

return UI
