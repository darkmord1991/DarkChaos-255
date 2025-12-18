local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

-- Seasonal Dungeon Portal UI via DCAddonProtocol (module MPLUS)
-- Server: SMSG_SEASONAL_PORTAL_OPEN (0x90), SMSG_SEASONAL_PORTAL_RESULT (0x92)
-- Client: CMSG_SEASONAL_PORTAL_TELEPORT (0x91)

local DC
local didWarnMissingProtocol = false
local handlersRegistered = false

local function EnsureProtocol()
    if DC then
        return true
    end

    DC = rawget(_G, "DCAddonProtocol")
    if DC then
        return true
    end

    if not didWarnMissingProtocol and DEFAULT_CHAT_FRAME then
        didWarnMissingProtocol = true
        DEFAULT_CHAT_FRAME:AddMessage("DC-MythicPlus: DC-AddonProtocol is not loaded. Seasonal Portal UI requires DC-AddonProtocol.")
    end
    return false
end

local MPLUS = "MPLUS"

namespace.SeasonalPortalUI = namespace.SeasonalPortalUI or {}
local UI = namespace.SeasonalPortalUI

local frame
local state = {
    seasonId = 0,
    dungeons = {},
    difficulty = 3, -- 1=Normal,2=Heroic,3=Mythic
    page = 1,
}

local ICON_BASE = "Interface\\AddOns\\DC-MythicPlus\\Media\\Teleporter\\"

local function normalizeDungeonNameToIconKey(name)
    if type(name) ~= "string" then
        return nil
    end

    local raw = name:gsub("^%s+", ""):gsub("%s+$", "")
    local lower = string.lower(raw)

    -- Explicit aliases (preferred over generic normalization)
    if lower == "ahn'kahet: the old kingdom" or lower == "ahn'kahet the old kingdom" then
        return "AhnKahet"
    end
    if lower == "the nexus" or lower == "nexus" then
        return "EyeOfEternity"
    end
    if lower == "the oculus" or lower == "oculus" then
        return "EyeOfEternity"
    end

    -- Match existing portal selector naming style:
    -- e.g. "Halls of Lightning" -> "HallsOfLightning", "Azjol-Nerub" -> "AzjolNerub"
    local s = raw

    -- Strip leading article if present in DB
    s = s:gsub("^%s*[Tt]he%s+", "")

    -- Remove everything except letters/numbers/spaces
    s = s:gsub("[^%w%s]", "")

    -- Title-case chunks and concatenate
    local parts = {}
    for word in s:gmatch("%S+") do
        local first = word:sub(1, 1)
        local rest = word:sub(2)
        parts[#parts + 1] = first:upper() .. rest
    end
    if #parts == 0 then
        return nil
    end

    return table.concat(parts, "")
end

local function iconPathForDungeonName(name)
    local key = normalizeDungeonNameToIconKey(name)
    if not key then
        return nil
    end
    return ICON_BASE .. key .. ".blp"
end

local iconExistsCache = {}

local function clamp(n, minV, maxV)
    if n < minV then return minV end
    if n > maxV then return maxV end
    return n
end

local function setButtonEnabled(button, enabled)
    if not button then
        return
    end
    if button.SetEnabled then
        button:SetEnabled(enabled and true or false)
        return
    end
    if enabled then
        if button.Enable then button:Enable() end
    else
        if button.Disable then button:Disable() end
    end
end

local function ensureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "DCMP_SeasonalPortalFrame", UIParent)
    frame:SetSize(760, 540)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Background (WotLK/Retail style)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    -- Close Button
    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -8, -8)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -15)
    frame.title:SetText("Seasonal Mythic+ Dungeons")
    frame.title:SetTextColor(1, 0.82, 0, 1)

    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.sub:SetPoint("TOPLEFT", 12, -32)
    frame.sub:SetJustifyH("LEFT")
    frame.sub:SetText("")
    frame.sub:SetTextColor(1, 0.82, 0, 1)

    frame.diffLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.diffLabel:SetPoint("TOPLEFT", 12, -58)
    frame.diffLabel:SetText("Difficulty")
    frame.diffLabel:SetTextColor(1, 0.82, 0, 1)

    frame.diffDrop = CreateFrame("Frame", "DCMP_SeasonalPortalDifficultyDrop", frame, "UIDropDownMenuTemplate")
    frame.diffDrop:SetPoint("TOPLEFT", -6, -76)
    UIDropDownMenu_SetWidth(frame.diffDrop, 140)

    UIDropDownMenu_Initialize(frame.diffDrop, function(self, level)
        local function add(text, value)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function()
                state.difficulty = value
                UIDropDownMenu_SetText(frame.diffDrop, text)
            end
            UIDropDownMenu_AddButton(info, level)
        end

        add("Normal", 1)
        add("Heroic", 2)
        add("Mythic", 3)
    end)

    UIDropDownMenu_SetText(frame.diffDrop, "Mythic")

    frame.gridLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.gridLabel:SetPoint("TOPLEFT", 12, -120)
    frame.gridLabel:SetText("Dungeons")
    frame.gridLabel:SetTextColor(1, 0.82, 0, 1)

    frame.grid = CreateFrame("Frame", nil, frame)
    frame.grid:SetPoint("TOPLEFT", 12, -140)
    frame.grid:SetPoint("BOTTOMRIGHT", -12, 68)

    frame.buttons = {}
    for i = 1, 6 do
        local b = CreateFrame("Button", nil, frame.grid)
        b:SetSize(352, 105)

        b.bgFrame = b:CreateTexture(nil, "BACKGROUND")
        b.bgFrame:SetAllPoints()
        b.bgFrame:SetColorTexture(0.1, 0.1, 0.1, 0.8)
        
        b.border = b:CreateTexture(nil, "BORDER")
        b.border:SetAllPoints()
        b.border:SetColorTexture(0.3, 0.3, 0.3, 1)
        b.border:SetDrawLayer("BORDER", -1)
        
        local bInner = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        bInner:SetPoint("TOPLEFT", 1, -1)
        bInner:SetPoint("BOTTOMRIGHT", -1, 1)
        bInner:SetColorTexture(0.1, 0.1, 0.1, 0.8)

        b.bg = b:CreateTexture(nil, "ARTWORK")
        b.bg:SetPoint("TOPLEFT", 5, -5)
        b.bg:SetPoint("BOTTOMRIGHT", -5, 5)
        b.bg:SetTexture(nil)
        b.bg:Hide()

        b.highlight = b:CreateTexture(nil, "HIGHLIGHT")
        b.highlight:SetAllPoints(b.bg)
        b.highlight:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        b.highlight:SetBlendMode("ADD")
        b.highlight:SetAlpha(0.25)

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        b.text:SetPoint("CENTER", 0, 0)
        b.text:SetJustifyH("CENTER")
        b.text:SetJustifyV("MIDDLE")
        b.text:SetText("-")
        b.text:SetTextColor(1, 0.82, 0, 1)

        b:SetScript("OnClick", function(self)
            if not self.mapId then return end
            if not EnsureProtocol() then
                return
            end
            DC:Request(MPLUS, 0x91, { mapId = self.mapId, difficulty = state.difficulty })
        end)
        
        b:SetScript("OnEnter", function(self)
            self.border:SetColorTexture(1, 0.82, 0, 1)
        end)
        b:SetScript("OnLeave", function(self)
            self.border:SetColorTexture(0.3, 0.3, 0.3, 1)
        end)

        frame.buttons[i] = b
    end

    local function CreateStyledButton(parent, text, width)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(width, 24)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(text)
        btn:SetFontString(btn.text)
        
        btn:SetScript("OnEnter", function(self)
            if self:IsEnabled() then
                self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if self:IsEnabled() then
                self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            else
                self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
            end
        end)
        btn:SetScript("OnEnable", function(self)
            self.bg:SetColorTexture(0.2, 0.2, 0.2, 1)
            self.text:SetTextColor(1, 1, 1, 1)
        end)
        btn:SetScript("OnDisable", function(self)
            self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
            self.text:SetTextColor(0.5, 0.5, 0.5, 1)
        end)
        
        return btn
    end

    frame.prev = CreateStyledButton(frame, "Previous", 110)
    frame.prev:SetPoint("BOTTOMLEFT", 12, 38)

    frame.next = CreateStyledButton(frame, "Next", 110)
    frame.next:SetPoint("BOTTOMRIGHT", -12, 38)

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.pageText:SetPoint("BOTTOM", 0, 42)
    frame.pageText:SetText("")
    frame.pageText:SetTextColor(1, 0.82, 0, 1)

    frame.result = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.result:SetPoint("BOTTOMLEFT", 12, 12)
    frame.result:SetJustifyH("LEFT")
    frame.result:SetText("")
    frame.result:SetTextColor(1, 0.82, 0, 1)

    return frame
end

local function rebuildGrid()
    if not frame or not frame:IsShown() then return end

    local perPage = 6
    local total = #state.dungeons
    local totalPages = math.max(1, math.ceil(total / perPage))
    state.page = clamp(tonumber(state.page) or 1, 1, totalPages)

    local leftX = 0
    local rightX = 372
    local topY = -2
    local rowH = 116

    for i = 1, 6 do
        local b = frame.buttons[i]
        b:Hide()

        local row = math.floor((i - 1) / 2)
        local col = (i - 1) % 2
        local x = (col == 0) and leftX or rightX
        local y = topY - row * rowH
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, y)

        local idx = (state.page - 1) * perPage + i
        local d = state.dungeons[idx]
        if d then
            local label = tostring(d.name or ("Map " .. tostring(d.mapId)))
            b.text:SetText(label)
            b.mapId = d.mapId

            -- Use the dungeon image as the button background if available.
            local iconPath = iconPathForDungeonName(label)
            local hasIcon = false
            if iconPath then
                local cached = iconExistsCache[iconPath]
                if cached == nil then
                    b.bg:SetTexture(iconPath)
                    cached = (b.bg:GetTexture() ~= nil)
                    iconExistsCache[iconPath] = cached
                else
                    if cached then
                        b.bg:SetTexture(iconPath)
                    end
                end
                hasIcon = cached == true
            end

            if hasIcon then
                b.bg:Show()
            else
                b.bg:SetTexture(nil)
                b.bg:Hide()
            end

            b:Enable()
            b:Show()
        else
            b.mapId = nil
            b:Disable()
        end
    end

    setButtonEnabled(frame.prev, state.page > 1)
    setButtonEnabled(frame.next, state.page < totalPages)
    frame.pageText:SetText(string.format("Page %d / %d", state.page, totalPages))
end

function UI:Show()
    ensureFrame():Show()
    UI:Refresh()
end

function UI:Hide()
    if frame then frame:Hide() end
end

function UI:Refresh()
    if not frame or not frame:IsShown() then return end
    frame.sub:SetText(string.format("Season: %s", tostring(state.seasonId or 0)))
    rebuildGrid()
end

local function SetPage(newPage)
    state.page = tonumber(newPage) or 1
    UI:Refresh()
end

local function RegisterProtocolHandlers()
    if handlersRegistered or not EnsureProtocol() then
        return
    end
    handlersRegistered = true

    DC:RegisterHandler(MPLUS, 0x90, function(payload)
        if type(payload) ~= "table" then return end

        state.seasonId = payload.seasonId or 0
        state.dungeons = payload.dungeons or {}
        state.page = 1

        ensureFrame()
        UI:Show()
    end)

    DC:RegisterHandler(MPLUS, 0x92, function(payload)
        if type(payload) ~= "table" then return end
        ensureFrame()
        if payload.message then
            frame.result:SetText(tostring(payload.message))
        end
    end)
end

-- Wire paging buttons once the frame exists.
do
    local f = ensureFrame()
    f.prev:SetScript("OnClick", function()
        SetPage((tonumber(state.page) or 1) - 1)
    end)
    f.next:SetScript("OnClick", function()
        SetPage((tonumber(state.page) or 1) + 1)
    end)
end

-- Attempt registration immediately, but also retry in case DC-AddonProtocol loads later.
RegisterProtocolHandlers()
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        RegisterProtocolHandlers()
        if handlersRegistered then
            f:UnregisterAllEvents()
            f:SetScript("OnEvent", nil)
        end
    end)
end

-- Debug/manual open: lets you verify the UI loads even if the server isn't sending OPEN packets.
SLASH_DCMPPORTAL1 = "/dcmportal"
SLASH_DCMPPORTAL2 = "/dcmpportal"
SlashCmdList["DCMPPORTAL"] = function()
    ensureFrame()
    UI:Show()

    if not EnsureProtocol() then
        return
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("DC-MythicPlus: Seasonal Portal UI opened locally (waiting for server data).")
    end
end
