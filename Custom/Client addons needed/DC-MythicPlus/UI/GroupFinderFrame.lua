-- DC-MythicPlus/UI/GroupFinderFrame.lua
-- Main Group Finder window using the compact Blizzard LFG-style shell.

local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.GroupFinder = namespace.GroupFinder or {}
local GF = namespace.GroupFinder

-- =====================================================================
-- Constants
-- =====================================================================

GF.FRAME_WIDTH = 650
GF.FRAME_HEIGHT = 560
GF.TAB_NAMES = { "Mythic+", "Raids", "World", "Live Runs", "Scheduled", "My Queues" }
GF.TABS = {}
GF.currentTab = 1

GF.CATEGORY_CONFIG = {
    mythic = { category = "dungeon", listingType = 1, title = "Mythic+" },
    raid = { category = "raid", listingType = 2, title = "Raid" },
    pvp = { category = "pvp", listingType = 3, title = "PvP" },
    quest = { category = "quest", listingType = 5, title = "Questing" },
    other = { category = "other", listingType = 4, title = "Other" },
}

GF.COMPACT_OPTION_ORDER = {
    "mythic", "raid", "hlbg", "quest", "other", "live", "queues", "blizzardLFG", "blizzardPVP"
}

GF.PREMADE_CATEGORY_ORDER = {
    "quest", "mythic", "raid", "hlbg", "live", "queues", "other"
}

GF.COMPACT_OPTIONS = {
    mythic = { label = "Mythic+", title = "Dungeon Finder", typeText = "Specific Dungeons", actionText = "Find Group", create = true },
    raid = { label = "Raid Finder", title = "Raid Finder", typeText = "Specific Raids", actionText = "Find Group", create = true },
    quest = { label = "Questing", title = "Questing", typeText = "Questing Groups", actionText = "Find a Group", create = true },
    other = { label = "Custom", title = "Custom", typeText = "Custom Groups", actionText = "Find a Group", create = true },
    live = { label = "Live Runs", title = "Live Runs", typeText = "Spectatable Runs", actionText = "Refresh" },
    queues = { label = "My Queues", title = "My Queues", typeText = "Applications", actionText = "Refresh" },
    hlbg = { label = "Hinterland BG", title = "Battleground Finder", typeText = "Hinterland BG", actionText = "Join Queue" },
    blizzardLFG = { label = "Blizzard LFG", title = "Dungeon Finder", typeText = "Stock LFG/LFM", actionText = "Open" },
    blizzardPVP = { label = "Blizzard PvP", title = "PvP", typeText = "Battlegrounds", actionText = "Open" },
}

local LFG_FRAME_TEXTURE = "Interface\\LFGFrame\\UI-LFG-FRAME"
local LFG_FRAME_FALLBACK = "Interface\\LFGFrame\\LFGParentFrame"
local LFG_THREE_BUTTON_BLANK = "Interface\\LFGFrame\\UI-Frame-ThreeButton-Blank"
local LFG_ROLE_TEXTURE = "Interface\\LFGFrame\\LFGRole"
local LFR_MAIN_TEXTURE = "Interface\\LFGFrame\\UI-LFR-FRAME-MAIN"
local LFR_BROWSE_TEXTURE = "Interface\\LFGFrame\\UI-LFR-FRAME-BROWSE"
local LFG_PORTRAIT_TEXTURE = "Interface\\LFGFrame\\UI-LFG-PORTRAIT"
local LFG_SEPARATOR_TEXTURE = "Interface\\LFGFrame\\UI-LFG-SEPARATOR"
local LFG_DUNGEON_BACKGROUND = "Interface\\LFGFrame\\UI-LFG-BACKGROUND-DUNGEONWALL"
local LFG_REWARD_RING = "Interface\\LFGFrame\\UI-LFG-ICON-REWARDRING"
local RETAIL_TEXTURE_ROOT = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Retail\\"
local RETAIL_BLUE_MENU_RING = RETAIL_TEXTURE_ROOT .. "bluemenuring_335.tga"
local RETAIL_BLUE_MENU_TEXTURES = {
    normal = RETAIL_TEXTURE_ROOT .. "BlueMenu-Normal.tga",
    selected = RETAIL_TEXTURE_ROOT .. "BlueMenu-Selected.tga",
    disabled = RETAIL_TEXTURE_ROOT .. "BlueMenu-Disabled.tga",
}
local RETAIL_GROUPFINDER_BACKGROUND_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Background.tga"
local RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Background-Dungeons.tga"
local RETAIL_GROUPFINDER_BUTTON_COVER_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Button-Cover.tga"
local RETAIL_GROUPFINDER_BUTTON_HIGHLIGHT_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Button-Highlight.tga"
local RETAIL_GROUPFINDER_BUTTON_SELECT_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Button-Select.tga"
local RETAIL_GROUPFINDER_EYE_BACKGLOW_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Eye-Backglow.tga"
local RETAIL_GROUPFINDER_EYE_FRAME_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Eye-Frame.tga"
local RETAIL_GROUPFINDER_EYE_SINGLE_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Eye-Single.tga"
local RETAIL_LFG_ROLE_GENERIC_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Generic.tga"
local RETAIL_LFG_ROLE_GENERIC_DISABLED_TEXTURE = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Generic-Disabled.tga"
local RETAIL_LFG_ROLE_TEXTURES = {
    tank = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Tank.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Tank-Disabled.tga",
    },
    healer = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Healer.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Healer-Disabled.tga",
    },
    dps = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-DPS.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-DPS-Disabled.tga",
    },
    leader = {
        enabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Leader.tga",
        disabled = RETAIL_TEXTURE_ROOT .. "GroupFinder-Role-Leader-Disabled.tga",
    },
}
local RETAIL_GROUPFINDER_NAV_TEXTURES = {
    dungeon = RETAIL_TEXTURE_ROOT .. "GroupFinder-Nav-Dungeons.tga",
    raid = RETAIL_TEXTURE_ROOT .. "GroupFinder-Nav-Raids.tga",
    premade = RETAIL_TEXTURE_ROOT .. "GroupFinder-Nav-Premade.tga",
}

local WOTLK_ROLE_BUTTON_COORDS = {
    tank = { 0.5, 0.75, 0, 1 },
    healer = { 0.75, 1, 0, 1 },
    dps = { 0.25, 0.5, 0, 1 },
    leader = { 0, 0.25, 0, 1 },
}

local function SetTextureOrFallback(texture, primary, fallback)
    if not texture then return end

    local ok = texture:SetTexture(primary)
    if not ok and fallback then
        texture:SetTexture(fallback)
        return false
    end

    return ok and true or false
end

local function SetSolidTexture(texture, red, green, blue, alpha)
    if not texture then return end

    if texture.SetColorTexture then
        texture:SetColorTexture(red, green, blue, alpha)
    else
        texture:SetTexture(red, green, blue, alpha)
        texture:SetAlpha(alpha or 1)
    end
end

local function SetTextureSlice(texture, primary, coords, fallback)
    if not texture then return end

    SetTextureOrFallback(texture, primary, fallback)
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

local function SetRetailBlueMenuBackground(texture, state)
    if not texture then return end

    SetTextureOrFallback(texture, RETAIL_BLUE_MENU_TEXTURES[state or "normal"] or RETAIL_BLUE_MENU_TEXTURES.normal, LFR_MAIN_TEXTURE)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
end

local function UpdateRetailNavButtonArt(button, state)
    if not button then return end

    local isSelected = state == "selected"
    local isHovered = state == "hover"

    if button.card then
        button.card:SetVertexColor(1, 1, 1, isSelected and 1 or 0.95)
    end

    if button.cover then
        button.cover:SetVertexColor(1, 1, 1, isSelected and 0.94 or (isHovered and 0.84 or 0.72))
    end

    if button.hoverOverlay then
        if isHovered and not isSelected then
            button.hoverOverlay:Show()
        else
            button.hoverOverlay:Hide()
        end
    end

    if button.selectOverlay then
        if isSelected then
            button.selectOverlay:Show()
        else
            button.selectOverlay:Hide()
        end
    end

    if button.text then
        if isSelected then
            button.text:SetTextColor(1, 0.90, 0.24)
        else
            button.text:SetTextColor(1, 0.82, 0)
        end
    end
end

local function ApplyCompactRoleButtonArt(button, checked)
    if not button then return end

    local retailRoleTextures = RETAIL_LFG_ROLE_TEXTURES[button.role]
    local fallbackCoords = WOTLK_ROLE_BUTTON_COORDS[button.role] or WOTLK_ROLE_BUTTON_COORDS.dps

    if button.ring then
        SetTextureOrFallback(button.ring, checked and RETAIL_LFG_ROLE_GENERIC_TEXTURE or RETAIL_LFG_ROLE_GENERIC_DISABLED_TEXTURE, LFG_REWARD_RING)
        button.ring:SetTexCoord(0, 1, 0, 1)
        button.ring:SetAlpha(1)
        button.ring:SetVertexColor(1, 1, 1, 1)
    end

    if button.icon and retailRoleTextures then
        local usedRetail = SetTextureOrFallback(button.icon, checked and retailRoleTextures.enabled or retailRoleTextures.disabled, LFG_ROLE_TEXTURE)
        if usedRetail then
            button.icon:SetTexCoord(0, 1, 0, 1)
            button.icon:SetAlpha(1)
        else
            button.icon:SetTexCoord(fallbackCoords[1], fallbackCoords[2], fallbackCoords[3], fallbackCoords[4])
            button.icon:SetAlpha(checked and 1 or 0.55)
        end
        button.icon:SetVertexColor(1, 1, 1, 1)
    end
end

-- Match DC-Leaderboards UI style across DC addons
local BG_FELLEATHER = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Backgrounds\\FelLeather_512.tga"
local BG_TINT_ALPHA = 0.78

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

local function ApplyBlizzardFinderStyle(frame)
    if not frame or frame.__dcBlizzardFinderStyle then return end
    frame.__dcBlizzardFinderStyle = true

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        if frame.SetBackdropColor then
            frame:SetBackdropColor(0.02, 0.02, 0.02, 0.94)
        end
    end

    local parchment = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    parchment:SetPoint("TOPLEFT", 10, -24)
    parchment:SetPoint("BOTTOMRIGHT", -10, 8)
    SetTextureOrFallback(parchment, LFG_FRAME_TEXTURE, LFG_FRAME_FALLBACK)
    parchment:SetVertexColor(0.82, 0.78, 0.68, 0.98)

    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    wash:SetPoint("TOPLEFT", 18, -74)
    wash:SetPoint("BOTTOMRIGHT", -18, 38)
    SetSolidTexture(wash, 0.03, 0.025, 0.018, 0.46)

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(60, 60)
    portrait:SetPoint("TOPLEFT", 18, -9)
    SetTextureOrFallback(portrait, LFG_PORTRAIT_TEXTURE,
        "Interface\\LFGFrame\\LFG-Eye")

    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetSize(520, 32)
    separator:SetPoint("TOP", 12, -78)
    SetTextureOrFallback(separator, LFG_SEPARATOR_TEXTURE,
        "Interface\\Common\\UI-TooltipDivider-Transparent")
    separator:SetVertexColor(1, 0.86, 0.45, 0.58)

    frame.__dcParchment = parchment
    frame.__dcWash = wash
    frame.__dcPortrait = portrait
    frame.__dcSeparator = separator
end

local function HasCapabilityBit(mask, capability)
    mask = tonumber(mask) or 0
    capability = tonumber(capability) or 0
    if capability <= 0 then return false end

    if bit and bit.band then
        return bit.band(mask, capability) ~= 0
    end

    return (mask % (capability * 2)) >= capability
end

local function GetDCProtocol()
    return rawget(_G, "DCAddonProtocol")
end

local function CopyTableValues(source, target)
    target = target or {}
    if type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do
        target[key] = value
    end

    return target
end

-- =====================================================================
-- Print Helper
-- =====================================================================

local function Print(selfOrMsg, maybeMsg)
    local text = maybeMsg
    if text == nil then
        text = selfOrMsg
    end

    text = tostring(text or "")

    if GF.SetStatusMessage then
        GF:SetStatusMessage(text)
    end
end
GF.Print = Print

function GF:PrintImportant(msg)
    local text = tostring(msg or "")

    if self.SetStatusMessage then
        self:SetStatusMessage(text)
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffGroup Finder:|r " .. text)
    end
end

function GF:SetStatusMessage(msg)
    self._pendingStatusMessage = tostring(msg or "")

    if not self.mainFrame or not self.mainFrame.StatusText then
        return
    end

    self._statusMessageToken = (self._statusMessageToken or 0) + 1
    local token = self._statusMessageToken

    self.mainFrame.StatusText:SetText(self._pendingStatusMessage)

    if C_Timer and C_Timer.After then
        C_Timer.After(6, function()
            if GF._statusMessageToken == token and GF.mainFrame and GF.mainFrame.StatusText then
                GF.mainFrame.StatusText:SetText("")
            end
        end)
    end
end

local function FormatRoleMask(role)
    local roleValue = tonumber(role) or 0
    local labels = {}

    if bit and bit.band then
        if bit.band(roleValue, 1) ~= 0 then table.insert(labels, "Tank") end
        if bit.band(roleValue, 2) ~= 0 then table.insert(labels, "Healer") end
        if bit.band(roleValue, 4) ~= 0 then table.insert(labels, "DPS") end
    else
        if roleValue >= 4 then
            table.insert(labels, "DPS")
            roleValue = roleValue - 4
        end
        if roleValue >= 2 then
            table.insert(labels, 1, "Healer")
            roleValue = roleValue - 2
        end
        if roleValue >= 1 then
            table.insert(labels, 1, "Tank")
        end
    end

    if #labels == 0 then
        return "Unknown"
    end

    return table.concat(labels, "/")
end

local function GetClassRoleCaps()
    local _, classFilename = UnitClass("player")
    local canTank = classFilename == "WARRIOR" or classFilename == "DEATHKNIGHT"
        or classFilename == "PALADIN" or classFilename == "DRUID"
    local canHeal = classFilename == "PRIEST" or classFilename == "SHAMAN"
        or classFilename == "PALADIN" or classFilename == "DRUID"

    return canTank, canHeal, true
end

function GF:GetCompactRoleMask()
    local state = self.compactRoles or { dps = true }
    local roleMask = 0

    if state.tank then roleMask = roleMask + 1 end
    if state.healer then roleMask = roleMask + 2 end
    if state.dps then roleMask = roleMask + 4 end

    return roleMask
end

function GF:GetCompactRoleFilters()
    local state = self.compactRoles or { dps = true }
    return {
        role = self:GetCompactRoleMask(),
        tank = state.tank and 1 or 0,
        healer = state.healer and 1 or 0,
        dps = state.dps and 1 or 0,
        leader = state.leader and 1 or 0,
    }
end

function GF:UpdateCompactRoleButtons()
    local state = self.compactRoles or { dps = true }

    for role, button in pairs(self.compactRoleButtons or {}) do
        local checked = state[role] and true or false
        ApplyCompactRoleButtonArt(button, checked)
    end
end

function GF:GetCategoryConfig(kind)
    return self.CATEGORY_CONFIG[kind]
end

function GF:SearchCustomCategory(kind, filters)
    local config = self:GetCategoryConfig(kind)
    local DC = GetDCProtocol()
    if not config or not DC or not DC.GroupFinder or not DC.GroupFinder.Search then
        return false
    end

    local roleFilters = self:GetCompactRoleFilters()
    local payload = CopyTableValues(filters, {
        category = config.category,
        listingType = config.listingType,
        role = roleFilters.role,
        tank = roleFilters.tank,
        healer = roleFilters.healer,
        dps = roleFilters.dps,
        leader = roleFilters.leader,
    })
    DC.GroupFinder.Search(payload)
    return true
end

function GF:CreateCustomListing(kind, data)
    local config = self:GetCategoryConfig(kind)
    local DC = GetDCProtocol()
    if not config or not DC or not DC.GroupFinder or not DC.GroupFinder.CreateListing then
        return false
    end

    local payload = CopyTableValues(data, {
        category = config.category,
        listingType = config.listingType,
    })

    local roleFilters = self:GetCompactRoleFilters()
    payload.role = payload.role or roleFilters.role
    payload.roles = payload.roles or {
        tank = roleFilters.tank == 1,
        healer = roleFilters.healer == 1,
        dps = roleFilters.dps == 1,
        leader = roleFilters.leader == 1,
    }

    if not payload.dungeonName or payload.dungeonName == "" then
        payload.dungeonName = config.title
    end

    DC.GroupFinder.CreateListing(payload)
    return true
end

function GF:ToggleBlizzardLFG()
    self._allowStockLFG = true

    if self._originalToggleLFGParentFrame then
        self._originalToggleLFGParentFrame()
        self._allowStockLFG = false
        return true
    end

    if LFDParentFrame then
        if LFDParentFrame:IsShown() then
            HideUIPanel(LFDParentFrame)
        else
            ShowUIPanel(LFDParentFrame)
        end
        self._allowStockLFG = false
        return true
    end

    if LFGParentFrame and ToggleLFGParentFrame then
        ToggleLFGParentFrame()
        self._allowStockLFG = false
        return true
    end

    if ToggleLFDParentFrame then
        ToggleLFDParentFrame()
        self._allowStockLFG = false
        return true
    end

    self._allowStockLFG = false
    return false
end

function GF:ToggleBlizzardPVP()
    if PVPParentFrame then
        if PVPParentFrame:IsShown() then
            HideUIPanel(PVPParentFrame)
        else
            ShowUIPanel(PVPParentFrame)
        end
        return true
    end

    if TogglePVPFrame then
        TogglePVPFrame()
        return true
    end

    return false
end

function GF:JoinHinterlandQueue(joinAsGroup)
    local HLBG = rawget(_G, "HLBG")
    if HLBG and type(HLBG.TryJoinViaBlizzardQueue) == "function"
        and HLBG.TryJoinViaBlizzardQueue(joinAsGroup and true or false) then
        return true
    end

    if HLBG and type(HLBG.JoinQueue) == "function" then
        HLBG.JoinQueue()
        return true
    end

    return false
end

function GF:GetBlizzardSideStatus()
    local DC = GetDCProtocol()
    local capabilities = 0
    if DC and type(DC.GetClientCapabilities) == "function" then
        local ok, value = pcall(DC.GetClientCapabilities, DC)
        if ok then
            capabilities = tonumber(value) or 0
        end
    end

    local genericEnvelopeCap = DC and DC.Capability
        and DC.Capability.GENERIC_NATIVE_ENVELOPE or 0x00100000

    return {
        legacyLFG = type(GetLookingForGroup) == "function"
            and type(GetNumLFGResults) == "function",
        legacyLFM = type(SetLookingForMore) == "function"
            or type(ClearLookingForMore) == "function",
        pvpQueue = type(GetBattlegroundInfo) == "function"
            and type(JoinBattlefield) == "function",
        nativeEnvelope = HasCapabilityBit(capabilities, genericEnvelopeCap),
        hinterlandBG = rawget(_G, "HLBG") ~= nil,
    }
end

local function NormalizeCompactEntries(entries)
    if type(entries) == "string" then
        local DC = GetDCProtocol()
        if DC and type(DC.DecodeJSON) == "function" then
            entries = DC:DecodeJSON(entries)
        end
    end

    if type(entries) == "table" and type(entries.groups) == "string" then
        local DC = GetDCProtocol()
        if DC and type(DC.DecodeJSON) == "function" then
            entries.groups = DC:DecodeJSON(entries.groups)
        end
    end

    if type(entries) == "table" and type(entries.groups) == "table" then
        entries = entries.groups
    elseif type(entries) == "table" and type(entries.runs) == "table" then
        entries = entries.runs
    elseif type(entries) == "table" and type(entries.applications) == "table" then
        entries = entries.applications
    end

    if type(entries) ~= "table" then
        return {}
    end

    if entries[1] ~= nil then
        return entries
    end

    local normalized = {}
    for _, entry in pairs(entries) do
        if type(entry) == "table" then
            table.insert(normalized, entry)
        end
    end

    return normalized
end

local function CompactEntryName(entry, kind)
    if kind == "live" then
        return entry.dungeon or entry.dungeonName or entry.mapName
            or entry.name or "Live Run"
    end

    if kind == "queues" then
        return entry.dungeonName or entry.dungeon or entry.raid
            or entry.name or "Application"
    end

    return entry.dungeonName or entry.dungeon or entry.raid
        or entry.name or "Group Listing"
end

local function CompactEntryMeta(entry, kind)
    if kind == "live" then
        local timer = entry.timer or entry.elapsed or entry.time or ""
        local level = tonumber(entry.level or entry.keystoneLevel or entry.keyLevel or 0) or 0
        if level > 0 then
            return string.format("+%d  %s", level, tostring(timer))
        end
        return tostring(timer ~= "" and timer or "Spectatable")
    end

    if kind == "queues" then
        return entry.status or entry.difficultyName or "Pending"
    end

    local parts = {}
    local level = tonumber(entry.level or entry.keystoneLevel or entry.keyLevel or 0) or 0
    if level > 0 then
        table.insert(parts, "+" .. level)
    end
    if entry.difficultyName and entry.difficultyName ~= "" then
        table.insert(parts, entry.difficultyName)
    elseif entry.difficulty and tostring(entry.difficulty) ~= "" then
        table.insert(parts, tostring(entry.difficulty))
    end
    if entry.note and entry.note ~= "" then
        table.insert(parts, entry.note)
    end

    if #parts == 0 then
        return "Available"
    end

    return table.concat(parts, "  ")
end

function GF:CompactClearRows()
    if not self.compactScrollChild then return end

    for _, child in ipairs({ self.compactScrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end
end

function GF:CompactSelectRow(row, entry)
    if self.compactSelectedRow and self.compactSelectedRow.bg then
        SetRetailBlueMenuBackground(self.compactSelectedRow.bg, "normal")
    end

    self.compactSelectedRow = row
    self.compactSelectedEntry = entry

    if row and row.bg then
        SetRetailBlueMenuBackground(row.bg, "selected")
    end

    self:UpdateCompactButtons()
end

function GF:CompactRenderRows(entries, emptyTitle, emptySubtext)
    if not self.compactScrollChild then return end

    entries = NormalizeCompactEntries(entries)
    self:CompactClearRows()
    self.compactSelectedRow = nil
    self.compactSelectedEntry = nil

    local scrollChild = self.compactScrollChild
    local kind = self.compactSelectedKind or "mythic"

    if #entries == 0 then
        local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        empty:SetPoint("TOP", 0, -92)
        empty:SetText(emptyTitle or "No groups found")
        empty:SetTextColor(0.6, 0.6, 0.6)

        local sub = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        sub:SetPoint("TOP", empty, "BOTTOM", 0, -8)
        sub:SetText(emptySubtext or "Choose a type and click Find Group.")

        scrollChild:SetHeight(220)
        if self.compactResultsText then
            self.compactResultsText:SetText("Results: 0")
        end
        self:UpdateCompactButtons()
        return
    end

    local yOffset = 0
    local rowHeight = 48
    local rowWidth = self.compactRowWidth or 312

    for _, entry in ipairs(entries) do
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(rowWidth, rowHeight - 2)
        row:SetPoint("TOPLEFT", 4, -yOffset)
        row.entry = entry

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        SetRetailBlueMenuBackground(row.bg, "normal")

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOPLEFT", 10, -7)
        name:SetWidth(158)
        name:SetJustifyH("LEFT")
        name:SetText(CompactEntryName(entry, kind))

        local leader = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        leader:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
        leader:SetWidth(158)
        leader:SetJustifyH("LEFT")
        leader:SetText(entry.leader or entry.leaderName or entry.owner or "")

        local meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        meta:SetPoint("TOPRIGHT", -8, -8)
        meta:SetWidth(116)
        meta:SetJustifyH("RIGHT")
        meta:SetText(CompactEntryMeta(entry, kind))

        local roles = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        roles:SetPoint("BOTTOMRIGHT", -8, 7)
        roles:SetText(string.format("T:%s H:%s D:%s",
            tostring(entry.needTank or entry.tanks or entry.tank or 0),
            tostring(entry.needHealer or entry.healers or entry.healer or 0),
            tostring(entry.needDps or entry.dps or 0)))

        row:SetScript("OnEnter", function(self)
            if self ~= GF.compactSelectedRow and self.bg then
                SetRetailBlueMenuBackground(self.bg, "selected")
            end
        end)
        row:SetScript("OnLeave", function(self)
            if self ~= GF.compactSelectedRow and self.bg then
                SetRetailBlueMenuBackground(self.bg, "normal")
            end
        end)
        row:SetScript("OnClick", function(self)
            GF:CompactSelectRow(self, self.entry)
        end)

        yOffset = yOffset + rowHeight
    end

    scrollChild:SetHeight(math.max(yOffset, 220))
    if self.compactResultsText then
        self.compactResultsText:SetText("Results: " .. #entries)
    end
    self:UpdateCompactButtons()
end

function GF:UpdateCompactButtons()
    if not self.compactPrimaryButton then return end

    if self.retailHomeShown then
        local selectedKind = self.premadeSelectedKind or "mythic"
        local homeOption = self.COMPACT_OPTIONS[selectedKind] or self.COMPACT_OPTIONS.mythic
        self.compactPrimaryButton:SetText("Find a Group")
        if self.compactCreateButton then
            if homeOption.create then
                self.compactCreateButton:SetText("Start a Group")
                self.compactCreateButton:Show()
            else
                self.compactCreateButton:Hide()
            end
        end
        return
    end

    local kind = self.compactSelectedKind or "mythic"
    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    local selected = self.compactSelectedEntry

    if selected and (kind == "mythic" or kind == "raid" or kind == "quest" or kind == "other") then
        self.compactPrimaryButton:SetText("Apply")
    elseif selected and kind == "live" then
        self.compactPrimaryButton:SetText("Spectate")
    else
        self.compactPrimaryButton:SetText(option.actionText or "Find Group")
    end

    if self.compactCreateButton then
        if option.create then
            self.compactCreateButton:SetText("Start a Group")
            self.compactCreateButton:Show()
        else
            self.compactCreateButton:Hide()
        end
    end
end

function GF:SelectCompactType(kind)
    kind = kind or "mythic"
    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    self.compactSelectedKind = kind
    self.compactSelectedEntry = nil
    self.retailHomeShown = false

    if self.compactTypeMenu then
        self.compactTypeMenu:Hide()
    end

    if self.retailHomeFrame then
        self.retailHomeFrame:Hide()
    end
    if self.compactBrowserFrame then
        self.compactBrowserFrame:Show()
    end
    if self.compactListFrame then
        self.compactListFrame:Show()
    end
    if self.retailContentTitle then
        self.retailContentTitle:SetText(option.title or option.label or "Group Finder")
    end
    if self.SetRetailNavSelection then
        if self.retailNavContext == "premade" then
            self:SetRetailNavSelection("premade")
        elseif kind == "mythic" then
            self:SetRetailNavSelection("dungeon")
        elseif kind == "raid" then
            self:SetRetailNavSelection("raid")
        else
            self:SetRetailNavSelection("premade")
        end
    end

    if self.mainFrame then
        self.mainFrame.TitleText:SetText(option.title or "Dungeon Finder")
    end
    if self.compactCategoryButton then
        self.compactCategoryButton:SetText(option.label or "Mythic+")
    end
    if self.compactTypeButtonText then
        self.compactTypeButtonText:SetText(option.typeText or option.label or "Specific Dungeons")
    end

    self:CompactRenderRows(self.compactData and self.compactData[kind] or {},
        kind == "queues" and "No active applications" or "No groups found",
        kind == "hlbg" and "Click Join Queue to enter Hinterland BG."
            or "Click Find Group to refresh this list.")
end

function GF:ToggleCompactTypeMenu()
    if not self.compactTypeMenu then return end

    if self.compactTypeMenu:IsShown() then
        self.compactTypeMenu:Hide()
    else
        self.compactTypeMenu:Show()
    end
end

function GF:CompactPrimaryAction()
    if self.retailHomeShown then
        self.retailNavContext = "premade"
        self:SelectCompactType(self.premadeSelectedKind or "mythic")
        self:CompactPrimaryAction()
        return
    end

    local kind = self.compactSelectedKind or "mythic"
    local selected = self.compactSelectedEntry

    if selected and (kind == "mythic" or kind == "raid" or kind == "quest" or kind == "other") then
        local listingId = selected.id or selected.listingId
        if listingId then
            self:ShowApplicationDialog(listingId, CompactEntryName(selected, kind))
        end
        return
    end

    if selected and kind == "live" then
        local runId = selected.runId or selected.id or selected.instanceId
        local DC = GetDCProtocol()
        if runId and DC and DC.GroupFinder and DC.GroupFinder.StartSpectate then
            DC.GroupFinder.StartSpectate(runId)
        end
        return
    end

    if kind == "hlbg" then
        if not self:JoinHinterlandQueue(false) then
            self:SetStatusMessage("Hinterland BG queue helper is not available.")
        end
    elseif kind == "blizzardLFG" then
        self:ToggleBlizzardLFG()
    elseif kind == "blizzardPVP" then
        self:ToggleBlizzardPVP()
    elseif kind == "live" then
        local DC = GetDCProtocol()
        if DC and DC.GroupFinder and DC.GroupFinder.GetSpectateList then
            DC.GroupFinder.GetSpectateList()
        end
    elseif kind == "queues" then
        self:RefreshMyQueues()
    else
        self:SearchCustomCategory(kind)
    end
end

function GF:ShowCompactCreateDialog(kind)
    local option = self.COMPACT_OPTIONS[kind] or self.COMPACT_OPTIONS.mythic
    if not option.create then return end

    if not self.compactCreateDialog then
        local frame = CreateFrame("Frame", "DCCompactGroupCreateDialog", UIParent)
        frame:SetSize(320, 210)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        frame.title = title

        local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("TOPLEFT", 24, -52)
        nameLabel:SetText("Name:")

        local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        nameBox:SetSize(220, 20)
        nameBox:SetPoint("TOPLEFT", 78, -50)
        nameBox:SetAutoFocus(false)
        frame.nameBox = nameBox

        local levelLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        levelLabel:SetPoint("TOPLEFT", 24, -82)
        levelLabel:SetText("Level:")

        local levelBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        levelBox:SetSize(60, 20)
        levelBox:SetPoint("TOPLEFT", 78, -80)
        levelBox:SetAutoFocus(false)
        levelBox:SetNumeric(true)
        levelBox:SetText("0")
        frame.levelLabel = levelLabel
        frame.levelBox = levelBox

        local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noteLabel:SetPoint("TOPLEFT", 24, -112)
        noteLabel:SetText("Note:")

        local noteBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        noteBox:SetSize(220, 20)
        noteBox:SetPoint("TOPLEFT", 78, -110)
        noteBox:SetAutoFocus(false)
        frame.noteBox = noteBox

        local createBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        createBtn:SetSize(100, 24)
        createBtn:SetPoint("BOTTOMLEFT", 42, 20)
        createBtn:SetText("Create")
        createBtn:SetScript("OnClick", function()
            local dialogKind = frame.kind or "mythic"
            local isRaid = dialogKind == "raid"
            local payload = {
                dungeonName = frame.nameBox:GetText() or option.label,
                keyLevel = tonumber(frame.levelBox:GetText()) or 0,
                needTank = isRaid and 2 or 1,
                needHealer = isRaid and 5 or 1,
                needDps = isRaid and 18 or 3,
                note = frame.noteBox:GetText() or "",
            }

            if GF:CreateCustomListing(dialogKind, payload) then
                frame:Hide()
                GF:SetStatusMessage("Creating listing...")
                C_Timer.After(0.5, function()
                    GF:SearchCustomCategory(dialogKind)
                end)
            end
        end)

        local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -42, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() frame:Hide() end)

        self.compactCreateDialog = frame
    end

    local dialog = self.compactCreateDialog
    dialog.kind = kind
    dialog.title:SetText("Create " .. (option.label or "Group"))
    dialog.nameBox:SetText(option.label or "Group")
    dialog.noteBox:SetText("")
    dialog.levelBox:SetText("0")
    if kind == "mythic" then
        dialog.levelLabel:Show()
        dialog.levelBox:Show()
    else
        dialog.levelLabel:Hide()
        dialog.levelBox:Hide()
    end
    dialog:Show()
end

function GF:CompactPopulateGroups(groups, kind)
    kind = kind or self.compactSelectedKind or "mythic"
    groups = NormalizeCompactEntries(groups)
    self.compactData = self.compactData or {}
    self.compactData[kind] = groups

    if self.compactMode and self.compactSelectedKind == kind then
        self:CompactRenderRows(groups)
    end
end

function GF:CompactPopulateApplications(applications)
    applications = NormalizeCompactEntries(applications)
    self.compactData = self.compactData or {}
    self.compactData.queues = applications

    if self.compactMode and self.compactSelectedKind == "queues" then
        self:CompactRenderRows(applications, "No active applications", "Applications appear here after you apply.")
    end
end

function GF:CompactPopulateLiveRuns(runs)
    runs = NormalizeCompactEntries(runs)
    self.compactData = self.compactData or {}
    self.compactData.live = runs

    if self.compactMode and self.compactSelectedKind == "live" then
        self:CompactRenderRows(runs, "No live runs", "Click Refresh to request spectatable runs.")
    end
end

function GF:CreateCompactRoleButton(parent, role, xOffset, checked, tooltip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(72, 60)
    button:SetPoint("TOPLEFT", xOffset, 0)
    button.role = role

    local ring = button:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(54, 54)
    ring:SetPoint("TOP", 0, -1)
    button.ring = ring

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(50, 50)
    icon:SetPoint("CENTER", ring, "CENTER", 0, 0)
    button.icon = icon

    ApplyCompactRoleButtonArt(button, checked)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(tooltip or role)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        GF.compactRoles = GF.compactRoles or { dps = true }
        GF.compactRoles[self.role] = not GF.compactRoles[self.role]
        GF:UpdateCompactRoleButtons()
    end)

    self.compactRoleButtons = self.compactRoleButtons or {}
    self.compactRoleButtons[role] = button
end

function GF:SetRetailNavSelection(selection)
    self.retailNavSelection = selection

    for key, button in pairs(self.retailNavButtons or {}) do
        UpdateRetailNavButtonArt(button, key == selection and "selected" or "normal")
    end
end

function GF:RefreshRetailPremadeSelection()
    local selectedKind = self.premadeSelectedKind or "mythic"

    for kind, button in pairs(self.premadeCategoryButtons or {}) do
        SetRetailBlueMenuBackground(button.bg, kind == selectedKind and "selected" or "normal")
    end

    local option = self.COMPACT_OPTIONS[selectedKind] or self.COMPACT_OPTIONS.mythic
    if self.compactTypeButtonText then
        self.compactTypeButtonText:SetText(option.typeText or option.label)
    end

    self:UpdateCompactButtons()
end

function GF:ShowRetailPremadeHome(kind)
    self.retailNavContext = "premade"
    self.retailHomeShown = true
    self.premadeSelectedKind = kind or self.premadeSelectedKind or "mythic"
    self.compactSelectedKind = self.premadeSelectedKind
    self.compactSelectedEntry = nil

    if self.compactTypeMenu then
        self.compactTypeMenu:Hide()
    end

    if self.compactBrowserFrame then
        self.compactBrowserFrame:Hide()
    end
    if self.compactListFrame then
        self.compactListFrame:Hide()
    end
    if self.retailHomeFrame then
        self.retailHomeFrame:Show()
    end
    if self.retailContentTitle then
        self.retailContentTitle:SetText("Premade Groups")
    end
    if self.mainFrame and self.mainFrame.TitleText then
        self.mainFrame.TitleText:SetText("Dungeon Finder")
    end

    self:SetRetailNavSelection("premade")
    self:RefreshRetailPremadeSelection()
end

function GF:CreateRetailNavButton(parent, key, label, iconTexture, yOffset, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(198, 96)
    button:SetPoint("TOPLEFT", 8, yOffset)
    button.key = key

    local card = button:CreateTexture(nil, "BACKGROUND")
    card:SetSize(188, 60)
    card:SetPoint("TOPLEFT", 6, -18)
    button.card = card
    button.bg = card
    SetTextureOrFallback(card, RETAIL_GROUPFINDER_NAV_TEXTURES[key] or RETAIL_GROUPFINDER_NAV_TEXTURES.dungeon, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE)
    card:SetTexCoord(0, 1, 0, 1)

    local cover = button:CreateTexture(nil, "ARTWORK")
    cover:SetSize(198, 72)
    cover:SetPoint("CENTER", card, "CENTER", 0, 0)
    SetTextureOrFallback(cover, RETAIL_GROUPFINDER_BUTTON_COVER_TEXTURE, LFG_THREE_BUTTON_BLANK)
    cover:SetTexCoord(0, 1, 0, 1)
    button.cover = cover

    local hoverOverlay = button:CreateTexture(nil, "ARTWORK", nil, 1)
    hoverOverlay:SetSize(194, 64)
    hoverOverlay:SetPoint("CENTER", card, "CENTER", 0, 0)
    SetTextureOrFallback(hoverOverlay, RETAIL_GROUPFINDER_BUTTON_HIGHLIGHT_TEXTURE, RETAIL_GROUPFINDER_BUTTON_COVER_TEXTURE)
    hoverOverlay:SetTexCoord(0, 1, 0, 1)
    hoverOverlay:SetVertexColor(1, 1, 1, 0.84)
    hoverOverlay:Hide()
    button.hoverOverlay = hoverOverlay

    local selectOverlay = button:CreateTexture(nil, "ARTWORK", nil, 2)
    selectOverlay:SetSize(194, 64)
    selectOverlay:SetPoint("CENTER", card, "CENTER", 0, 0)
    SetTextureOrFallback(selectOverlay, RETAIL_GROUPFINDER_BUTTON_SELECT_TEXTURE, RETAIL_GROUPFINDER_BUTTON_COVER_TEXTURE)
    selectOverlay:SetTexCoord(0, 1, 0, 1)
    selectOverlay:SetVertexColor(1, 1, 1, 0.95)
    selectOverlay:Hide()
    button.selectOverlay = selectOverlay

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", 92, 0)
    text:SetWidth(90)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    button.text = text

    UpdateRetailNavButtonArt(button, "normal")

    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        if GF.retailNavSelection ~= self.key then
            UpdateRetailNavButtonArt(self, "hover")
        end
    end)
    button:SetScript("OnLeave", function(self)
        UpdateRetailNavButtonArt(self, GF.retailNavSelection == self.key and "selected" or "normal")
    end)

    self.retailNavButtons = self.retailNavButtons or {}
    self.retailNavButtons[key] = button
    return button
end

function GF:CreateRetailPremadeCategoryButton(parent, kind, label, yOffset)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(math.max((parent:GetWidth() or 0) - 8, 318), 40)
    button:SetPoint("TOPLEFT", 0, yOffset)
    button.kind = kind

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    button.bg = bg
    SetRetailBlueMenuBackground(bg, "normal")

    local image = button:CreateTexture(nil, "BORDER")
    image:SetPoint("TOPLEFT", 5, -5)
    image:SetPoint("BOTTOMRIGHT", -5, 5)
    SetTextureOrFallback(image, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE, LFG_DUNGEON_BACKGROUND)
    image:SetTexCoord(0, 1, 0, 1)
    image:SetVertexColor(1, 1, 1, 0.32)

    local cover = button:CreateTexture(nil, "ARTWORK")
    cover:SetAllPoints()
    SetTextureOrFallback(cover, RETAIL_GROUPFINDER_BUTTON_COVER_TEXTURE, LFG_THREE_BUTTON_BLANK)
    cover:SetTexCoord(0, 1, 0, 1)
    cover:SetVertexColor(1, 1, 1, 0.68)

    local labelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", 18, 0)
    labelText:SetWidth(button:GetWidth() - 40)
    labelText:SetJustifyH("LEFT")
    labelText:SetText(label)

    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    button:SetScript("OnClick", function(self)
        GF.premadeSelectedKind = self.kind
        GF:RefreshRetailPremadeSelection()
        GF:SelectCompactType(self.kind)
    end)

    self.premadeCategoryButtons = self.premadeCategoryButtons or {}
    self.premadeCategoryButtons[kind] = button
    return button
end

function GF:CreateCompactMainFrame()
    if self.mainFrame then return self.mainFrame end

    local frame = CreateFrame("Frame", "DCMythicPlusGroupFinderFrame", UIParent)
    frame:SetSize(self.FRAME_WIDTH, self.FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.02, 0.02, 0.02, 0.86)
    end

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    SetSolidTexture(bg, 0.01, 0.01, 0.01, 0.62)

    local portraitBackglow = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    portraitBackglow:SetSize(66, 66)
    portraitBackglow:SetPoint("TOPLEFT", 8, -10)
    SetTextureOrFallback(portraitBackglow, RETAIL_GROUPFINDER_EYE_BACKGLOW_TEXTURE, LFG_PORTRAIT_TEXTURE)
    portraitBackglow:SetVertexColor(1, 1, 1, 0.9)

    local portraitRing = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    portraitRing:SetSize(52, 52)
    portraitRing:SetPoint("CENTER", portraitBackglow, "CENTER", 0, 0)
    SetTextureOrFallback(portraitRing, RETAIL_GROUPFINDER_EYE_FRAME_TEXTURE, LFG_PORTRAIT_TEXTURE)

    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(44, 44)
    portrait:SetPoint("CENTER", portraitRing, "CENTER", 0, 0)
    SetTextureOrFallback(portrait, RETAIL_GROUPFINDER_EYE_SINGLE_TEXTURE, "Interface\\LFGFrame\\LFG-Eye")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Dungeon Finder")
    title:SetTextColor(1, 0.82, 0)
    frame.TitleText = title

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local navPanel = CreateFrame("Frame", nil, frame)
    navPanel:SetPoint("TOPLEFT", 18, -64)
    navPanel:SetPoint("BOTTOMLEFT", 18, 18)
    navPanel:SetWidth(214)
    navPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    if navPanel.SetBackdropColor then
        navPanel:SetBackdropColor(0, 0, 0, 0.14)
    end

    local navInset = navPanel:CreateTexture(nil, "BACKGROUND")
    navInset:SetAllPoints()
    SetTextureOrFallback(navInset, RETAIL_GROUPFINDER_BACKGROUND_TEXTURE, LFG_DUNGEON_BACKGROUND)
    navInset:SetTexCoord(0, 1, 0, 1)
    navInset:SetVertexColor(0.90, 0.90, 0.90, 0.44)

    local navShade = navPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    navShade:SetAllPoints()
    SetSolidTexture(navShade, 0.01, 0.02, 0.04, 0.03)

    local navLowerBand = navPanel:CreateTexture(nil, "BACKGROUND", nil, 2)
    navLowerBand:SetPoint("BOTTOMLEFT", 10, 14)
    navLowerBand:SetPoint("BOTTOMRIGHT", -10, 14)
    navLowerBand:SetHeight(96)
    SetTextureOrFallback(navLowerBand, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE, LFG_DUNGEON_BACKGROUND)
    navLowerBand:SetTexCoord(0, 1, 0, 1)
    navLowerBand:SetVertexColor(1, 1, 1, 0.28)

    self:CreateRetailNavButton(navPanel, "dungeon", "Dungeon\nFinder", "Interface\\Icons\\INV_Helmet_08", -24, function()
        GF.retailNavContext = nil
        GF:SelectCompactType("mythic")
    end)
    self:CreateRetailNavButton(navPanel, "raid", "Raid Finder", "Interface\\LFGFrame\\UI-LFR-PORTRAIT", -180, function()
        GF.retailNavContext = nil
        GF:SelectCompactType("raid")
    end)
    self:CreateRetailNavButton(navPanel, "premade", "Premade\nGroups", "Interface\\Icons\\Achievement_General_StayClassy", -336, function()
        GF:ShowRetailPremadeHome(GF.premadeSelectedKind or "mythic")
    end)

    local contentPanel = CreateFrame("Frame", nil, frame)
    contentPanel:SetPoint("TOPLEFT", navPanel, "TOPRIGHT", 16, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", -18, 18)
    contentPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    if contentPanel.SetBackdropColor then
        contentPanel:SetBackdropColor(0, 0, 0, 0.10)
    end

    local contentInset = contentPanel:CreateTexture(nil, "BACKGROUND")
    contentInset:SetAllPoints()
    SetTextureOrFallback(contentInset, RETAIL_GROUPFINDER_BACKGROUND_TEXTURE, LFG_DUNGEON_BACKGROUND)
    contentInset:SetTexCoord(0, 1, 0, 1)
    contentInset:SetVertexColor(1, 1, 1, 0.84)

    local contentShade = contentPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    contentShade:SetAllPoints()
    SetSolidTexture(contentShade, 0, 0, 0, 0.04)

    local contentTitle = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    contentTitle:SetPoint("TOPLEFT", 16, -16)
    contentTitle:SetText("Dungeon Finder")
    contentTitle:SetTextColor(1, 0.82, 0)
    self.retailContentTitle = contentTitle

    local browserFrame = CreateFrame("Frame", nil, contentPanel)
    browserFrame:SetPoint("TOPLEFT", 6, -42)
    browserFrame:SetPoint("BOTTOMRIGHT", -6, 68)
    self.compactBrowserFrame = browserFrame

    local browserHeaderBg = browserFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    browserHeaderBg:SetPoint("TOPLEFT", 10, -4)
    browserHeaderBg:SetPoint("TOPRIGHT", -10, -4)
    browserHeaderBg:SetHeight(96)
    SetTextureOrFallback(browserHeaderBg, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE, LFG_DUNGEON_BACKGROUND)
    browserHeaderBg:SetTexCoord(0, 1, 0, 1)
    browserHeaderBg:SetVertexColor(1, 1, 1, 0.78)

    local rolePanel = CreateFrame("Frame", nil, browserFrame)
    rolePanel:SetPoint("TOPLEFT", 0, -4)
    rolePanel:SetPoint("TOPRIGHT", 0, -4)
    rolePanel:SetHeight(70)

    local roleBg = rolePanel:CreateTexture(nil, "BACKGROUND")
    roleBg:SetPoint("TOPLEFT", 10, -4)
    roleBg:SetPoint("TOPRIGHT", -10, -4)
    roleBg:SetHeight(58)
    SetTextureOrFallback(roleBg, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE, LFG_THREE_BUTTON_BLANK)
    roleBg:SetTexCoord(0, 1, 0, 1)
    roleBg:SetVertexColor(1, 1, 1, 0.72)

    local roleCover = rolePanel:CreateTexture(nil, "ARTWORK")
    roleCover:SetPoint("TOPLEFT", roleBg, "TOPLEFT", -6, 6)
    roleCover:SetPoint("BOTTOMRIGHT", roleBg, "BOTTOMRIGHT", 6, -6)
    SetTextureOrFallback(roleCover, RETAIL_GROUPFINDER_BUTTON_COVER_TEXTURE, LFG_THREE_BUTTON_BLANK)
    roleCover:SetTexCoord(0, 1, 0, 1)
    roleCover:SetVertexColor(1, 1, 1, 0.46)

    self.compactRoles = self.compactRoles or { dps = true }
    local canTank, canHeal = GetClassRoleCaps()
    if not canTank then self.compactRoles.tank = false end
    if not canHeal then self.compactRoles.healer = false end
    self.compactRoleButtons = {}
    self:CreateCompactRoleButton(rolePanel, "tank", 24, self.compactRoles.tank, "Tank")
    self:CreateCompactRoleButton(rolePanel, "healer", 112, self.compactRoles.healer, "Healer")
    self:CreateCompactRoleButton(rolePanel, "dps", 200, self.compactRoles.dps, "Damage")
    self:CreateCompactRoleButton(rolePanel, "leader", 288, self.compactRoles.leader, "Leader")
    if not canTank and self.compactRoleButtons.tank then
        self.compactRoleButtons.tank:Disable()
        self.compactRoleButtons.tank:SetAlpha(0.45)
    end
    if not canHeal and self.compactRoleButtons.healer then
        self.compactRoleButtons.healer:Disable()
        self.compactRoleButtons.healer:SetAlpha(0.45)
    end
    self:UpdateCompactRoleButtons()

    local typeLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    typeLabel:SetPoint("TOPLEFT", rolePanel, "BOTTOMLEFT", 18, -18)
    typeLabel:SetText("Type:")
    typeLabel:SetTextColor(1, 0.82, 0)

    local typeButton = CreateFrame("Button", nil, browserFrame, "UIPanelButtonTemplate")
    typeButton:SetSize(250, 28)
    typeButton:SetPoint("LEFT", typeLabel, "RIGHT", 10, 0)
    typeButton:SetScript("OnClick", function() GF:ToggleCompactTypeMenu() end)
    self.compactTypeButton = typeButton

    local typeText = typeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    typeText:SetPoint("CENTER", -8, 0)
    typeText:SetText("Specific Dungeons")
    self.compactTypeButtonText = typeText

    local arrow = typeButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")

    local menu = CreateFrame("Frame", "DCCompactGroupFinderTypeMenu", contentPanel)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(frame:GetFrameLevel() + 30)
    menu:SetSize(220, 22 * #self.COMPACT_OPTION_ORDER + 8)
    menu:SetPoint("TOPRIGHT", typeButton, "BOTTOMRIGHT", 0, -2)
    menu:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    menu:Hide()
    self.compactTypeMenu = menu

    local menuY = -4
    for _, kind in ipairs(self.COMPACT_OPTION_ORDER) do
        local option = self.COMPACT_OPTIONS[kind]
        local item = CreateFrame("Button", nil, menu)
        item:SetSize(206, 20)
        item:SetPoint("TOPLEFT", 7, menuY)
        item:SetNormalFontObject("GameFontHighlightSmall")
        item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        item:SetText(option.label)
        item:SetScript("OnClick", function()
            GF.compactTypeMenu:Hide()
            GF:SelectCompactType(kind)
        end)
        menuY = menuY - 22
    end

    local listFrame = CreateFrame("Frame", nil, browserFrame)
    listFrame:SetPoint("TOPLEFT", 6, -134)
    listFrame:SetPoint("BOTTOMRIGHT", -6, 0)
    listFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    if listFrame.SetBackdropColor then
        listFrame:SetBackdropColor(0, 0, 0, 0.08)
    end
    self.compactListFrame = listFrame

    local listBg = listFrame:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    SetTextureOrFallback(listBg, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE, LFG_DUNGEON_BACKGROUND)
    listBg:SetTexCoord(0, 1, 0, 1)
    listBg:SetVertexColor(1, 1, 1, 0.36)

    for bandIndex = 0, 2 do
        local band = listFrame:CreateTexture(nil, "BACKGROUND", nil, bandIndex + 1)
        band:SetPoint("TOPLEFT", 10, -12 - (bandIndex * 88))
        band:SetPoint("TOPRIGHT", -10, -12 - (bandIndex * 88))
        band:SetHeight(96)
        SetTextureOrFallback(band, RETAIL_GROUPFINDER_BACKGROUND_DUNGEONS_TEXTURE, LFG_DUNGEON_BACKGROUND)
        band:SetTexCoord(0, 1, 0, 1)
        band:SetVertexColor(1, 1, 1, bandIndex == 0 and 0.62 or 0.48)
    end

    local listShade = listFrame:CreateTexture(nil, "BORDER")
    listShade:SetAllPoints()
    SetSolidTexture(listShade, 0, 0, 0, 0.05)

    local scroll = CreateFrame("ScrollFrame", "DCCompactGroupFinderScroll", listFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 28)
    local child = CreateFrame("Frame")
    child:SetSize(316, 220)
    scroll:SetScrollChild(child)
    self.compactScrollChild = child
    self.compactRowWidth = 312

    local results = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    results:SetPoint("BOTTOMLEFT", 10, 8)
    results:SetText("Results: 0")
    self.compactResultsText = results

    local homeFrame = CreateFrame("Frame", nil, contentPanel)
    homeFrame:SetPoint("TOPLEFT", 6, -42)
    homeFrame:SetPoint("BOTTOMRIGHT", -6, 64)
    homeFrame:Hide()
    self.retailHomeFrame = homeFrame
    if homeFrame.SetBackdropColor then
        homeFrame:SetBackdropColor(0, 0, 0, 0.08)
    end

    local homeBg = homeFrame:CreateTexture(nil, "BACKGROUND")
    homeBg:SetAllPoints()
    SetTextureOrFallback(homeBg, RETAIL_GROUPFINDER_BACKGROUND_TEXTURE, LFG_DUNGEON_BACKGROUND)
    homeBg:SetTexCoord(0, 1, 0, 1)
    homeBg:SetVertexColor(1, 1, 1, 0.84)

    local homeShade = homeFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    homeShade:SetAllPoints()
    SetSolidTexture(homeShade, 0, 0, 0, 0.04)

    local categoryY = -6
    for _, kind in ipairs(self.PREMADE_CATEGORY_ORDER) do
        local option = self.COMPACT_OPTIONS[kind]
        if option then
            self:CreateRetailPremadeCategoryButton(homeFrame, kind, option.label, categoryY)
            categoryY = categoryY - 44
        end
    end

    local primary = CreateFrame("Button", nil, contentPanel, "UIPanelButtonTemplate")
    primary:SetSize(118, 28)
    primary:SetPoint("BOTTOMLEFT", 10, 16)
    primary:SetText("Find Group")
    primary:SetScript("OnClick", function() GF:CompactPrimaryAction() end)
    self.compactPrimaryButton = primary

    local create = CreateFrame("Button", nil, contentPanel, "UIPanelButtonTemplate")
    create:SetSize(126, 28)
    create:SetPoint("BOTTOM", 0, 16)
    create:SetText("Start Group")
    create:SetScript("OnClick", function()
        GF:ShowCompactCreateDialog(GF.retailHomeShown and GF.premadeSelectedKind or GF.compactSelectedKind or "mythic")
    end)
    self.compactCreateButton = create

    local close = CreateFrame("Button", nil, contentPanel, "UIPanelButtonTemplate")
    close:SetSize(100, 28)
    close:SetPoint("BOTTOMRIGHT", -10, 16)
    close:SetText("Close")
    close:SetScript("OnClick", function() frame:Hide() end)

    local statusText = contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOM", 0, 52)
    statusText:SetWidth(340)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("")
    frame.StatusText = statusText

    self.mainFrame = frame
    self.compactMode = true
    self.compactData = self.compactData or {}
    self.compactCategoryButton = nil
    self:SelectCompactType("mythic")

    tinsert(UISpecialFrames, "DCMythicPlusGroupFinderFrame")
    return frame
end

-- =====================================================================
-- Main Frame Creation
-- =====================================================================

function GF:CreateMainFrame()
    return self:CreateCompactMainFrame()
end

-- =====================================================================
-- Tab System
-- =====================================================================

function GF:CreateTabButtons()
    local tabWidth = (self.FRAME_WIDTH - 40) / #self.TAB_NAMES
    
    for i, tabName in ipairs(self.TAB_NAMES) do
        local btn = CreateFrame("Button", "DCGroupFinderTab" .. i, self.mainFrame.tabContainer)
        btn:SetSize(tabWidth - 4, 28)
        btn:SetPoint("LEFT", (i - 1) * tabWidth + 10, 0)
        
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        SetTextureOrFallback(btn.bg, LFR_MAIN_TEXTURE,
            "Interface\\Buttons\\UI-Listbox-Highlight")
        btn.bg:SetVertexColor(0.22, 0.18, 0.12, 0.86)
        
        btn.accent = btn:CreateTexture(nil, "ARTWORK")
        btn.accent:SetPoint("BOTTOMLEFT", 0, 0)
        btn.accent:SetPoint("BOTTOMRIGHT", 0, 0)
        btn.accent:SetHeight(3)
        SetSolidTexture(btn.accent, 1, 0.82, 0, 1) -- Gold
        btn.accent:Hide()
        
        -- Text
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("CENTER", 0, 1)
        btn.text:SetText(tabName)
        btn.text:SetTextColor(0.75, 0.68, 0.52)
        
        btn:SetScript("OnEnter", function(self)
            if GF.currentTab ~= self.tabIndex then
                self.bg:SetVertexColor(0.42, 0.32, 0.18, 0.92)
                self.text:SetTextColor(1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if GF.currentTab ~= self.tabIndex then
                self.bg:SetVertexColor(0.22, 0.18, 0.12, 0.86)
                self.text:SetTextColor(0.75, 0.68, 0.52)
            end
        end)
        
        btn.tabIndex = i
        btn:SetScript("OnClick", function(self)
            GF:SelectTab(self.tabIndex)
        end)
        
        self.TABS[i] = btn
    end
end

function GF:SelectTab(index)
    if self.compactMode then
        local compactMap = { "mythic", "raid", "quest", "live", "queues" }
        self.currentTab = index or 1
        self:SelectCompactType(compactMap[index or 1] or "mythic")
        return
    end

    self.currentTab = index
    
    -- Update tab visuals
    for i, btn in ipairs(self.TABS) do
        if i == index then
            btn.bg:SetVertexColor(0.55, 0.39, 0.16, 0.96)
            btn.text:SetTextColor(1, 1, 1)
            btn.accent:Show()
        else
            btn.bg:SetVertexColor(0.22, 0.18, 0.12, 0.86)
            btn.text:SetTextColor(0.75, 0.68, 0.52)
            btn.accent:Hide()
        end
    end
    
    -- Hide all content frames
    if self.MythicTabContent then self.MythicTabContent:Hide() end
    if self.RaidTabContent then self.RaidTabContent:Hide() end
    if self.WorldTabContent then self.WorldTabContent:Hide() end
    if self.LiveRunsTabContent then self.LiveRunsTabContent:Hide() end
    if self.ScheduledTabContent then self.ScheduledTabContent:Hide() end
    if self.MyQueuesTabContent then self.MyQueuesTabContent:Hide() end
    
    -- Show selected tab content
    if index == 1 then
        self:ShowMythicTab()
    elseif index == 2 then
        self:ShowRaidTab()
    elseif index == 3 then
        self:ShowWorldTab()
    elseif index == 4 then
        self:ShowLiveRunsTab()
    elseif index == 5 then
        self:ShowScheduledTab()
    elseif index == 6 then
        self:ShowMyQueuesTab()
    end
end

-- =====================================================================
-- Toggle & Visibility
-- =====================================================================

function GF:Toggle()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:SelectTab(1) -- Default to Mythic+ tab
        
        local DC = rawget(_G, "DCAddonProtocol")
        if DC and DC.GroupFinder and DC.GroupFinder.GetSystemInfo then
            DC.GroupFinder.GetSystemInfo()
        end
    end
end

function GF:Show()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    self.mainFrame:Show()
    self:SelectTab(1)
    
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetSystemInfo then
        DC.GroupFinder.GetSystemInfo()
    end
end

function GF:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

function GF:InstallBlizzardLFGReplacement()
    if self._blizzardLFGReplacementInstalled then return end

    if type(ToggleLFGParentFrame) == "function" then
        self._originalToggleLFGParentFrame = ToggleLFGParentFrame
        ToggleLFGParentFrame = function(tab)
            if GF._allowStockLFG then
                return GF._originalToggleLFGParentFrame(tab)
            end

            if GF.mainFrame and GF.mainFrame:IsShown() then
                GF:Hide()
            else
                if LFGParentFrame and LFGParentFrame:IsShown() then
                    HideUIPanel(LFGParentFrame)
                end
                GF:Show()
                if tab == 2 then
                    GF:SelectCompactType("other")
                else
                    GF:SelectCompactType("mythic")
                end
            end

            if UpdateMicroButtons then
                UpdateMicroButtons()
            end
        end
    end

    if LFGParentFrame and LFGParentFrame.HookScript then
        LFGParentFrame:HookScript("OnShow", function(frame)
            if GF._allowStockLFG then return end
            frame:Hide()
            GF:Show()
        end)
    end

    self._blizzardLFGReplacementInstalled = true
end

local replacementInstaller = CreateFrame("Frame")
replacementInstaller:RegisterEvent("PLAYER_LOGIN")
replacementInstaller:SetScript("OnEvent", function()
    GF:InstallBlizzardLFGReplacement()
end)
if type(ToggleLFGParentFrame) == "function" then
    GF:InstallBlizzardLFGReplacement()
end

-- =====================================================================
-- Placeholder Tab Content (populated by tab-specific files)
-- =====================================================================

function GF:ShowMythicTab()
    if not self.MythicTabContent and self.CreateMythicTab then
        self:CreateMythicTab()
    end
    if self.MythicTabContent then
        self.MythicTabContent:Show()
        -- Select browse sub-tab and refresh groups if this is first show
        if self.MythicBrowsePanel and not self.MythicBrowsePanel.hasInitialized then
            self.MythicBrowsePanel.hasInitialized = true
            self:SelectMythicSubTab(1)
            self:RefreshMythicGroups()
        end
    end
end

function GF:ShowRaidTab()
    if not self.RaidTabContent and self.CreateRaidTab then
        self:CreateRaidTab()
    end
    if self.RaidTabContent then
        self.RaidTabContent:Show()
        if self.RefreshRaidGroups then
            self:RefreshRaidGroups()
        end
    end
end

function GF:ShowWorldTab()
    if not self.WorldTabContent and self.CreateWorldTab then
        self:CreateWorldTab()
    end
    if self.WorldTabContent then
        self.WorldTabContent:Show()
        -- Refresh world content when tab is shown
        if self.RefreshWorldContent then
            self:RefreshWorldContent()
        end
    end
end

function GF:ShowLiveRunsTab()
    if not self.LiveRunsTabContent and self.CreateLiveRunsTab then
        self:CreateLiveRunsTab()
    end
    if self.LiveRunsTabContent then
        self.LiveRunsTabContent:Show()
    end
end

function GF:ShowScheduledTab()
    if not self.ScheduledTabContent and self.CreateScheduledTab then
        self:CreateScheduledTab()
    end
    if self.ScheduledTabContent then
        self.ScheduledTabContent:Show()
        -- Refresh events when tab is shown
        if self.RefreshScheduledEvents then
            self:RefreshScheduledEvents()
        end
    end
end

function GF:ShowMyQueuesTab()
    if not self.MyQueuesTabContent then
        self:CreateMyQueuesTab()
    end
    if self.MyQueuesTabContent then
        self.MyQueuesTabContent:Show()
        self:RefreshMyQueues()
    end
end

function GF:CreateMyQueuesTab()
    local frame = CreateFrame("Frame", nil, self.mainFrame.contentFrame)
    frame:SetAllPoints()
    frame:Hide()
    
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("My Active Applications")

    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("TOPRIGHT", -10, -6)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        GF:RefreshMyQueues()
    end)
    frame.refreshBtn = refreshBtn

    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", 0, 0)
    emptyText:SetText("No active applications.")
    frame.emptyText = emptyText
    
    -- Scroll frame for applications
    local scrollFrame = CreateFrame("ScrollFrame", "DCGroupFinderMyQueuesScroll", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)
    
    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    self.myApplications = self.myApplications or {}
    
    self.MyQueuesTabContent = frame
end

function GF:RefreshMyQueues()
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.GetMyApplications then
        DC.GroupFinder.GetMyApplications()
    end
end

function GF:UpdateMyApplications(applications)
    if type(applications) ~= "table" then
        applications = {}
    elseif applications[1] == nil then
        local normalized = {}
        for _, entry in pairs(applications) do
            if type(entry) == "table" then
                table.insert(normalized, entry)
            end
        end
        applications = normalized
    end

    self.myApplications = applications
    self:CompactPopulateApplications(applications)
    self:RenderMyQueues()
end

function GF:CancelMyApplication(listingId)
    local DC = rawget(_G, "DCAddonProtocol")
    if DC and DC.GroupFinder and DC.GroupFinder.CancelApplication then
        DC.GroupFinder.CancelApplication(listingId)
    end
end

function GF:RenderMyQueues()
    if not self.MyQueuesTabContent or not self.MyQueuesTabContent.scrollChild then
        return
    end

    local frame = self.MyQueuesTabContent
    local scrollChild = frame.scrollChild
    local applications = self.myApplications or {}

    for _, child in ipairs({ scrollChild:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    if #applications == 0 then
        frame.emptyText:Show()
        scrollChild:SetHeight(1)
        return
    end

    frame.emptyText:Hide()

    local yOffset = 0
    local rowHeight = 58

    for index, app in ipairs(applications) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(scrollChild:GetWidth() - 8, rowHeight - 4)
        row:SetPoint("TOPLEFT", 4, -yOffset)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        if index % 2 == 0 then
            SetSolidTexture(row.bg, 0.08, 0.08, 0.10, 1)
        else
            SetSolidTexture(row.bg, 0.06, 0.06, 0.08, 1)
        end

        local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 10, -8)
        title:SetText((app.dungeonName or app.dungeon or "Unknown Listing") .. "  |cff888888(" .. (app.difficultyName or "Unknown") .. ")|r")

        local info = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
        info:SetText(string.format("Leader: %s  |  Role: %s", app.leader or "Unknown", FormatRoleMask(app.role)))

        local status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPRIGHT", -100, -8)
        status:SetText("|cff00ff00Pending|r")

        if app.note and app.note ~= "" then
            local note = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            note:SetPoint("BOTTOMLEFT", 10, 8)
            note:SetText(app.note)
        elseif tonumber(app.keystoneLevel or 0) > 0 then
            local meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            meta:SetPoint("BOTTOMLEFT", 10, 8)
            meta:SetText("Key Level: +" .. tonumber(app.keystoneLevel or 0))
        end

        local cancelBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        cancelBtn:SetSize(80, 22)
        cancelBtn:SetPoint("RIGHT", -10, 0)
        cancelBtn:SetText("Withdraw")
        cancelBtn:SetScript("OnClick", function()
            GF:CancelMyApplication(app.listingId)
        end)

        yOffset = yOffset + rowHeight
    end

    scrollChild:SetHeight(math.max(yOffset, 1))
end

-- Application Dialog
function GF:ShowApplicationDialog(listingId, dungeonName)
    if not self.appDialog then
        local frame = CreateFrame("Frame", "DCGroupFinderAppDialog", UIParent)
        frame:SetSize(300, 250)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        
        -- Background
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        ApplyLeaderboardsStyle(frame)
        
        -- Title
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Apply to Group")
        title:SetTextColor(1, 0.82, 0) -- Gold
        frame.title = title
        
        -- Role Checkboxes
        local tankCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleTank", frame, "UICheckButtonTemplate")
        tankCb:SetPoint("TOPLEFT", 40, -50)
        _G[tankCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:0:19:22:41|t Tank")
        frame.tankCb = tankCb
        
        local healerCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleHealer", frame, "UICheckButtonTemplate")
        healerCb:SetPoint("TOPLEFT", 120, -50)
        _G[healerCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:1:20|t Healer")
        frame.healerCb = healerCb
        
        local dpsCb = CreateFrame("CheckButton", "DCGroupFinderAppDialogRoleDPS", frame, "UICheckButtonTemplate")
        dpsCb:SetPoint("TOPLEFT", 200, -50)
        _G[dpsCb:GetName().."Text"]:SetText("|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:16:16:0:0:64:64:20:39:22:41|t Damage")
        frame.dpsCb = dpsCb
        
        -- Note EditBox
        local noteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noteLabel:SetPoint("TOPLEFT", 20, -90)
        noteLabel:SetText("Note (optional):")
        noteLabel:SetTextColor(1, 0.82, 0) -- Gold
        
        local noteBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        noteBox:SetSize(260, 20)
        noteBox:SetPoint("TOPLEFT", 25, -110)
        noteBox:SetAutoFocus(false)
        frame.noteBox = noteBox
        
        -- Buttons
        local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        applyBtn:SetSize(100, 25)
        applyBtn:SetPoint("BOTTOMLEFT", 40, 20)
        applyBtn:SetText("Apply")
        applyBtn:SetScript("OnClick", function()
            local roleMask = 0
            if frame.tankCb:GetChecked() then roleMask = roleMask + 1 end
            if frame.healerCb:GetChecked() then roleMask = roleMask + 2 end
            if frame.dpsCb:GetChecked() then roleMask = roleMask + 4 end
            
            if roleMask == 0 then
                GF.Print("Please select at least one role.")
                return
            end
            
            local note = frame.noteBox:GetText()
            local DC = rawget(_G, "DCAddonProtocol")
            if DC and DC.GroupFinder then
                DC.GroupFinder.Apply(frame.listingId, roleMask, note)
            end
            frame:Hide()
        end)
        
        local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 25)
        cancelBtn:SetPoint("BOTTOMRIGHT", -40, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() frame:Hide() end)
        
        self.appDialog = frame
    end
    
    -- Update role checkboxes based on class
    local _, classFilename = UnitClass("player")
    local canTank = false
    local canHeal = false
    local canDPS = true -- Everyone can DPS
    
    if classFilename == "WARRIOR" or classFilename == "DEATHKNIGHT" or classFilename == "PALADIN" or classFilename == "DRUID" then
        canTank = true
    end
    
    if classFilename == "PRIEST" or classFilename == "SHAMAN" or classFilename == "PALADIN" or classFilename == "DRUID" then
        canHeal = true
    end
    
    -- Configure checkboxes
    if canTank then
        self.appDialog.tankCb:Enable()
        self.appDialog.tankCb:SetAlpha(1)
    else
        self.appDialog.tankCb:Disable()
        self.appDialog.tankCb:SetChecked(false)
        self.appDialog.tankCb:SetAlpha(0.5)
    end
    
    if canHeal then
        self.appDialog.healerCb:Enable()
        self.appDialog.healerCb:SetAlpha(1)
    else
        self.appDialog.healerCb:Disable()
        self.appDialog.healerCb:SetChecked(false)
        self.appDialog.healerCb:SetAlpha(0.5)
    end
    
    local selectedRoles = self.compactRoles or { dps = true }
    self.appDialog.tankCb:SetChecked(canTank and selectedRoles.tank or false)
    self.appDialog.healerCb:SetChecked(canHeal and selectedRoles.healer or false)
    self.appDialog.dpsCb:SetChecked(selectedRoles.dps ~= false)

    if not self.appDialog.tankCb:GetChecked() and not self.appDialog.healerCb:GetChecked() and not self.appDialog.dpsCb:GetChecked() then
        if canTank then self.appDialog.tankCb:SetChecked(true)
        elseif canHeal then self.appDialog.healerCb:SetChecked(true)
        else self.appDialog.dpsCb:SetChecked(true) end
    end
    
    self.appDialog.listingId = listingId
    self.appDialog.title:SetText("Apply to " .. (dungeonName or "Group"))
    self.appDialog.noteBox:SetText("")
    self.appDialog:Show()
end

-- =====================================================================
-- Reward Display
-- =====================================================================

function GF:CreateRewardFrame()
    if self.rewardFrame then return end
    
    local frame = CreateFrame("Frame", nil, self.mainFrame)
    frame:SetSize(300, 30)
    frame:SetPoint("BOTTOMLEFT", 14, 10)
    frame:SetFrameLevel(self.mainFrame:GetFrameLevel() + 20)
    
    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetText("Daily Reward:")
    label:SetTextColor(1, 0.82, 0) -- Gold
    frame.label = label
    
    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", label, "RIGHT", 5, 0)
    frame.icon = icon
    
    -- Count
    local count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    frame.count = count
    
    self.rewardFrame = frame
    self.rewardFrame:Hide() -- Hide until data received
end

function GF:UpdateSystemInfo(data)
    if not self.mainFrame then return end

    if self.compactMode then
        if data.rewardEnabled and self.mainFrame.StatusText then
            self.mainFrame.StatusText:SetText("Daily reward available")
        end
        return
    end

    if not self.rewardFrame then self:CreateRewardFrame() end
    
    if data.rewardEnabled then
        self.rewardFrame:Show()
        
        local text = ""
        local iconTexture = "Interface\\Icons\\INV_Misc_QuestionMark"
        
        local rewardItemId = tonumber(data.rewardItemId) or 0
        local rewardItemCount = tonumber(data.rewardItemCount) or 1

        -- Prefer central Upgrade Token if server is still sending a placeholder (commonly 49426 = Emblem of Frost)
        local centralTokenId = (rawget(_G, "DCAddonProtocol") and rawget(_G, "DCAddonProtocol").TOKEN_ITEM_ID) or 0
        if centralTokenId > 0 and (rewardItemId == 0 or rewardItemId == 49426) then
            rewardItemId = centralTokenId
            rewardItemCount = 1
        end

        if rewardItemId > 0 then
            local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(rewardItemId)
            if itemIcon then
                iconTexture = itemIcon
            end
            text = (rewardItemCount or 1) .. "x " .. (itemName or "Item")
            
            -- If item info not cached, query it
            if not itemName then
                -- WotLK doesn't have Item:CreateFromItemID mixin usually, just rely on GetItemInfo returning nil first time
                -- We can try to query it again later or just show ID
                text = (rewardItemCount or 1) .. "x Item " .. rewardItemId
            end
        elseif data.rewardCurrencyId > 0 then
            -- Currency handling
            local name, _, icon = GetCurrencyInfo(data.rewardCurrencyId)
            if icon then
                iconTexture = icon
            end
            text = (data.rewardCurrencyCount or 1) .. "x " .. (name or "Currency")
        end
        
        self.rewardFrame.icon:SetTexture(iconTexture)
        self.rewardFrame.count:SetText(text)
    else
        self.rewardFrame:Hide()
    end
end

Print("Group Finder UI module loaded")
