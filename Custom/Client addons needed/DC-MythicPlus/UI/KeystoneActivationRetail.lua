local addonName = "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

namespace.KeystoneUI = namespace.KeystoneUI or {}
local KUI = namespace.KeystoneUI

local MPLUS = "MPLUS"
local CMSG_KEYSTONE_RESPONSE = 0x08
local CMSG_KEYSTONE_CANCEL = 0x09

KUI.STATE = {
    IDLE = 0,
    READY_CHECK = 1,
    COUNTDOWN = 2,
}

KUI.currentState = KUI.STATE.IDLE
KUI.keystoneData = nil
KUI.partyMembers = {}
KUI.isLeader = false
KUI.countdownValue = 0

local BG_FELLEATHER = "Interface\\AddOns\\DC-MythicPlus\\Textures\\Backgrounds\\FelLeather_512.tga"
local KEYSTONE_ICON = "Interface\\Icons\\INV_Misc_Key_14"
local ICON_BASE = "Interface\\AddOns\\DC-MythicPlus\\Media\\Teleporter\\"
local ICONS_DUNGEONS_BASE = "Interface\\AddOns\\Icons\\dungeons\\"
local RETAIL_ATLAS_ROOT = "Interface\\AddOns\\DC-MythicPlus\\Textures\\RetailAtlas\\"
local BG_TINT_ALPHA = 0.78
local ROLE_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"

local RETAIL_ATLAS = {
    ChallengeMode = RETAIL_ATLAS_ROOT .. "ChallengeMode.blp",
    ChallengeModeRunes = RETAIL_ATLAS_ROOT .. "ChallengeModeRunes.blp",
    ChallengeModeHud = RETAIL_ATLAS_ROOT .. "ChallengeModeHud.blp",
}

local function AtlasDescriptor(filePath, left, right, top, bottom)
    return {
        filePath = filePath,
        coords = { left, right, top, bottom },
    }
end

local RETAIL_TEXTURES = {
    KeystoneFrame = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.133789,
        0.522461, 0.390625, 0.925781),
    AffixRing = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.912109,
        0.962891, 0.0537109, 0.104492),
    ThinDivider = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.538086,
        0.894531, 0.375, 0.37793),
    KeystoneSlotBG = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.000976562,
        0.112305, 0.760742, 0.87207),
    KeystoneSlotFrame = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode,
        0.000976562, 0.118164, 0.641602, 0.758789),
    KeystoneSlotFrameGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode,
        0.000976562, 0.118164, 0.522461, 0.639648),
    RuneBG = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.000976562,
        0.694336, 0.000976562, 0.694336),
    RunesBackgroundBurst = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes,
        0.696289, 0.989258, 0.000976562, 0.294922),
    RunesLineGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.524414,
        0.760742, 0.390625, 0.613281),
    RunesInnerCircleGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes,
        0.732422, 0.938477, 0.696289, 0.900391),
    RunesSmallCircleGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode,
        0.000976562, 0.131836, 0.390625, 0.520508),
    RunesShockwave = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.762695,
        0.963867, 0.390625, 0.594727),
    RunesLarge = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode, 0.538086,
        0.910156, 0.000976562, 0.373047),
    RunesSmall = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.257812,
        0.5, 0.696289, 0.938477),
    RunesGlowBurstLarge = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes,
        0.501953, 0.730469, 0.696289, 0.924805),
    RunesCircleGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes,
        0.696289, 0.790039, 0.567383, 0.661133),
    RunesTGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.888672,
        0.964844, 0.902344, 0.978516),
    RunesRGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.810547,
        0.886719, 0.902344, 0.978516),
    RunesBRGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.870117,
        0.946289, 0.567383, 0.643555),
    RunesBLGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.791992,
        0.868164, 0.567383, 0.643555),
    RunesLGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes, 0.732422,
        0.808594, 0.902344, 0.978516),
    RunesGlowLarge = AtlasDescriptor(RETAIL_ATLAS.ChallengeMode,
        0.524414, 0.907227, 0.615234, 0.99707),
    RunesGlowSmall = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeRunes,
        0.000976562, 0.255859, 0.696289, 0.950195),
    CountdownBlackFade = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.387695, 0.712891, 0.431641, 0.550781),
    CountdownTimerBG = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.714844, 0.952148, 0.431641, 0.546875),
    CountdownTimerBorder = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.000976562, 0.180664, 0.802734, 0.847656),
    CountdownBannerShine = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.387695, 0.604492, 0.220703, 0.427734),
    CountdownTimerFrame = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.606445, 0.861328, 0.220703, 0.390625),
    CountdownSoftYellowGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.000976562, 0.202148, 0.00195312, 0.404297),
    CountdownWhiteSpikeyGlow = AtlasDescriptor(RETAIL_ATLAS.ChallengeModeHud,
        0.204102, 0.385742, 0.00195312, 0.410156),
}

local AFFIX_ICONS = {
    [1] = "Interface\\Icons\\Spell_Fire_Immolation",
    [2] = "Interface\\Icons\\Spell_Frost_ChillingBlast",
    [3] = "Interface\\Icons\\Spell_Nature_NatureGuardian",
    [4] = "Interface\\Icons\\Ability_Warrior_BattleShout",
    [5] = "Interface\\Icons\\Spell_Nature_Earthquake",
    [6] = "Interface\\Icons\\Spell_Shadow_SoulGem",
    [7] = "Interface\\Icons\\Spell_Nature_Thorns",
    [8] = "Interface\\Icons\\Inv_Misc_Volatilefire",
}

local ROLE_COORDS = {
    TANK = { 0, 0.296875, 0.34375, 0.640625 },
    HEALER = { 0.296875, 0.59375, 0, 0.296875 },
    DPS = { 0.296875, 0.59375, 0.34375, 0.640625 },
}

local textureExistsCache = {}

local function Truthy(value)
    return value == true or value == 1 or value == "1" or value == "true"
end

local function DecodePayloadTable(value)
    if type(value) ~= "string" then
        return value
    end

    local proto = rawget(_G, "DCAddonProtocol")
    local decodeFn
    if proto and type(proto.DecodeJSON) == "function" then
        decodeFn = function(text)
            return proto:DecodeJSON(text)
        end
    elseif namespace and type(namespace.DecodeJSON) == "function" then
        decodeFn = namespace.DecodeJSON
    end

    if not decodeFn then
        return value
    end

    local ok, decoded = pcall(function()
        return decodeFn(value)
    end)
    if ok and type(decoded) == "table" then
        return decoded
    end

    return value
end

local function ResolveAffixInfo(affix)
    if type(affix) == "table" then
        local id = tonumber(affix.id or affix.affixId or affix.affix_id) or 0
        local descriptor = nil
        if id > 0 and type(namespace.GetMythicPlusAffixDescriptor)
            == "function" then
            descriptor = namespace.GetMythicPlusAffixDescriptor(id)
        end

        local spellId = tonumber(
            affix.spellId or affix.spellID or affix.spell_id
            or (descriptor and descriptor.spellId) or 0) or 0
        local name = (descriptor and descriptor.name) or affix.name
            or affix.affixName or affix.spellName
        local desc = (descriptor and descriptor.description)
            or affix.description or affix.desc or affix.affixDesc
        local icon = affix.icon or (descriptor and descriptor.icon)
        if not icon and spellId > 0 and type(GetSpellTexture) == "function" then
            icon = GetSpellTexture(spellId)
        end
        return id > 0 and id or spellId, name, desc, icon
    end

    if type(affix) == "number" then
        if type(namespace.GetMythicPlusAffixDescriptor) == "function" then
            local descriptor = namespace.GetMythicPlusAffixDescriptor(affix)
            if descriptor then
                return descriptor.id, descriptor.name, descriptor.description,
                    descriptor.icon
            end
        end

        local icon = type(GetSpellTexture) == "function"
            and GetSpellTexture(affix) or nil
        local name = type(GetSpellInfo) == "function"
            and GetSpellInfo(affix) or nil
        return affix, name, nil, icon
    end

    return nil, nil, nil, nil
end

local function Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffKeystone:|r " .. (message or ""))
    end
end

local function ApplyLeaderboardsStyle(frame)
    if not frame or frame.__dcLeaderboardsStyle then
        return
    end

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

local function Clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function FormatTimeLimit(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        return "Unknown Timer"
    end

    if type(SecondsToTime) == "function" then
        return SecondsToTime(seconds, false, true)
    end

    local minutes = math.floor(seconds / 60)
    local remain = math.floor(math.fmod(seconds, 60))
    if remain == 0 then
        return string.format("%d Minutes", minutes)
    end
    return string.format("%d:%02d", minutes, remain)
end

local function normalizeDungeonNameToIconKey(name)
    if type(name) ~= "string" then
        return nil
    end

    local raw = name:gsub("^%s+", ""):gsub("%s+$", "")
    local lower = string.lower(raw)

    if lower == "ahn'kahet: the old kingdom" or lower == "ahn'kahet the old kingdom" then
        return "AhnKahet"
    end
    if lower == "gundrak" then
        return "GundrakDungeon"
    end
    if lower == "the nexus" or lower == "nexus" then
        return "TheNexus"
    end
    if lower == "the forge of souls" or lower == "forge of souls" then
        return "ForgeOfSouls"
    end
    if lower == "pit of saron" then
        return "PitOfSaron"
    end
    if lower == "halls of reflection" then
        return "HallsOfReflection"
    end
    if lower == "trial of the champion" then
        return "TrialOfTheChampion"
    end
    if lower == "drak'tharon keep" or lower == "draktharon keep" then
        return "DrakTharonKeep"
    end

    local normalized = raw:gsub("^%s*[Tt]he%s+", "")
    normalized = normalized:gsub("[^%w%s]", "")

    local parts = {}
    for word in normalized:gmatch("%S+") do
        local first = word:sub(1, 1)
        local rest = word:sub(2)
        parts[#parts + 1] = first:upper() .. rest
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, "")
end

local function iconCandidatesForDungeonArtKey(artKey)
    if type(artKey) ~= "string" or artKey == "" then
        return nil
    end

    if artKey == "AhnKahet" then
        return {
            ICON_BASE .. "AhnKahet.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-ahnkalet.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-ahnkalet.png",
        }
    end
    if artKey == "GundrakDungeon" then
        return {
            ICON_BASE .. "GundrakDungeon.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-gundrak.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-gundrak.png",
        }
    end
    if artKey == "TheNexus" then
        return {
            ICON_BASE .. "TheNexus.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-thenexus.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-thenexus.png",
        }
    end

    return { ICON_BASE .. artKey .. ".blp" }
end

local function iconCandidatesForDungeonName(name)
    if type(name) ~= "string" then
        return nil
    end

    local lower = string.lower(name)
    if lower == "ahn'kahet: the old kingdom" or lower == "ahn'kahet the old kingdom" then
        return {
            ICON_BASE .. "AhnKahet.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-ahnkalet.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-ahnkalet.png",
        }
    end
    if lower == "gundrak" then
        return {
            ICON_BASE .. "GundrakDungeon.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-gundrak.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-gundrak.png",
        }
    end
    if lower == "the nexus" or lower == "nexus" then
        return {
            ICON_BASE .. "TheNexus.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-thenexus.blp",
            ICONS_DUNGEONS_BASE .. "ui-lfg-background-thenexus.png",
        }
    end
    return nil
end

local function ResolveDungeonArtCandidates(data)
    local candidates = {}

    local function addCandidate(path)
        if type(path) == "string" and path ~= "" then
            candidates[#candidates + 1] = path
        end
    end

    if type(data) == "table" then
        addCandidate(data.iconPath)

        local keyed = iconCandidatesForDungeonArtKey(data.artKey)
        if keyed then
            for _, path in ipairs(keyed) do
                addCandidate(path)
            end
        end

        local named = iconCandidatesForDungeonName(data.dungeonName)
        if named then
            for _, path in ipairs(named) do
                addCandidate(path)
            end
        end

        local iconKey = normalizeDungeonNameToIconKey(data.dungeonName)
        if iconKey then
            addCandidate(ICON_BASE .. iconKey .. ".blp")
        end
    end

    addCandidate(BG_FELLEATHER)
    return candidates
end

local function ApplyTextureCandidates(texture, candidates)
    if not texture then
        return nil
    end

    for _, path in ipairs(candidates or {}) do
        local cached = textureExistsCache[path]
        if cached ~= false then
            texture:SetTexture(path)
            local exists = texture:GetTexture() ~= nil
            textureExistsCache[path] = exists
            if exists then
                return path
            end
        end
    end

    texture:SetTexture(nil)
    return nil
end

local function SendProtocol(moduleName, opcode, payload)
    local protocol = rawget(_G, "DCAddonProtocol")
    if not protocol then
        return false
    end

    if type(protocol.Request) == "function" then
        protocol:Request(moduleName, opcode, payload or {})
        return true
    end

    if type(protocol.Send) == "function" then
        protocol:Send(moduleName, opcode, payload or {})
        return true
    end

    return false
end

local function SetButtonText(button, text)
    if not button then
        return
    end

    if button.SetText then
        button:SetText(text or "")
        if button.GetTextWidth and button.SetWidth then
            button:SetWidth(math.max(120, button:GetTextWidth() + 60))
        end
        return
    end

    if button.label then
        button.label:SetText(text)
    end
end

local function Lerp(fromValue, toValue, progress)
    return fromValue + ((toValue - fromValue) * Clamp(progress, 0, 1))
end

local function WindowProgress(elapsed, startTime, duration)
    return Clamp((elapsed - startTime) / duration, 0, 1)
end

local function FadeToValue(elapsed, fadeInStart, fadeInDuration, peakValue,
    settleStart, settleDuration, settleValue)
    local fadeIn = WindowProgress(elapsed, fadeInStart, fadeInDuration)
    if fadeIn <= 0 then
        return 0
    end

    local currentValue = Lerp(0, peakValue, fadeIn)
    if elapsed < settleStart then
        return currentValue
    end

    return Lerp(peakValue, settleValue,
        WindowProgress(elapsed, settleStart, settleDuration))
end

local function SetRegionScale(region, scale)
    if not region then
        return
    end

    if region.SetScale then
        region:SetScale(scale)
        return
    end

    local objectType = region.GetObjectType and region:GetObjectType() or nil
    if objectType == "FontString" and region.GetFont and region.SetFont then
        if not region.__dcScaleBaseFontPath then
            local fontPath, fontHeight, fontFlags = region:GetFont()
            region.__dcScaleBaseFontPath = fontPath
            region.__dcScaleBaseFontHeight = fontHeight
            region.__dcScaleBaseFontFlags = fontFlags
        end

        if region.__dcScaleBaseFontPath and region.__dcScaleBaseFontHeight then
            region:SetFont(region.__dcScaleBaseFontPath,
                math.max(1, math.floor(region.__dcScaleBaseFontHeight * scale + 0.5)),
                region.__dcScaleBaseFontFlags)
        end
        return
    end

    if region.SetWidth and region.SetHeight and region.GetWidth and region.GetHeight then
        if not region.__dcScaleBaseWidth or not region.__dcScaleBaseHeight then
            region.__dcScaleBaseWidth = region:GetWidth()
            region.__dcScaleBaseHeight = region:GetHeight()
        end

        if region.__dcScaleBaseWidth and region.__dcScaleBaseHeight then
            region:SetWidth(region.__dcScaleBaseWidth * scale)
            region:SetHeight(region.__dcScaleBaseHeight * scale)
        end
    end
end

local function SetBurstScaleAndAlpha(region, progress, fromScale, toScale,
    peakAlpha)
    if not region then
        return
    end

    if progress <= 0 or progress >= 1 then
        region:SetAlpha(0)
        SetRegionScale(region, progress <= 0 and fromScale or toScale)
        return
    end

    SetRegionScale(region, Lerp(fromScale, toScale, progress))
    region:SetAlpha(peakAlpha * (1 - progress))
end

local function SetRetailTexture(region, descriptor)
    if not region or not descriptor then
        return
    end

    region:SetTexture(descriptor.filePath)
    if region.SetTexCoord then
        local coords = descriptor.coords
        if coords then
            region:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            region:SetTexCoord(0, 1, 0, 1)
        end
    end
end

local function SetRoleCoords(texture, role)
    local coords = ROLE_COORDS[role or "DPS"] or ROLE_COORDS.DPS
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

local function ShortenMemberName(name)
    if type(name) ~= "string" or name == "" then
        return "-"
    end

    local short = name:gsub("%-.+$", "")
    if string.len(short) > 8 then
        return string.sub(short, 1, 8)
    end

    return short
end

local function GetReadyStateTexture(member)
    if Truthy(member and member.declined) then
        return "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
    end
    if Truthy(member and member.ready) then
        return "Interface\\RAIDFRAME\\ReadyCheck-Ready"
    end
    return "Interface\\RAIDFRAME\\ReadyCheck-Waiting"
end

local function GetConfiguredKeystoneItemId(level)
    level = tonumber(level) or 0
    if level <= 0 then
        return nil
    end

    local DCproto = rawget(_G, "DCAddonProtocol")
    local DCCentral = rawget(_G, "DCCentral")
    local ids = (DCCentral and DCCentral.KEYSTONE_ITEM_IDS) or
        (DCproto and DCproto.KEYSTONE_ITEM_IDS)

    if type(ids) ~= "table" then
        return nil
    end

    if tonumber(ids[level]) then
        return tonumber(ids[level])
    end

    if tonumber(ids[level - 1]) then
        return tonumber(ids[level - 1])
    end

    return nil
end

local function ResolveKeystoneItemTexture(itemId, itemLink, bag, slot)
    if type(GetContainerItemInfo) == "function" and bag ~= nil and slot ~= nil then
        local texture = GetContainerItemInfo(bag, slot)
        if texture then
            return texture
        end
    end

    local _, resolvedLink, _, _, _, _, _, _, _, texture = GetItemInfo(itemLink or itemId)
    if texture then
        return texture, resolvedLink or itemLink
    end

    if itemId and type(GetItemIcon) == "function" then
        local icon = GetItemIcon(itemId)
        if icon then
            return icon, itemLink
        end
    end

    return KEYSTONE_ICON, itemLink
end

local function ResolveDisplayedKeystone(level)
    local levelNumber = tonumber(level) or 0
    local inventoryKey = namespace and namespace.inventoryKeystone or nil

    if type(inventoryKey) == "table" and inventoryKey.hasKey then
        local inventoryLevel = tonumber(inventoryKey.level) or 0
        if levelNumber <= 0 or inventoryLevel == levelNumber then
            return inventoryKey
        end
    end

    local itemId = GetConfiguredKeystoneItemId(levelNumber)
    if itemId then
        return {
            itemId = itemId,
            itemLink = select(2, GetItemInfo(itemId)),
        }
    end

    return nil
end

local function CreateRetailButton(parent, text)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(120, 24)
    SetButtonText(button, text)
    return button
end

local function CreateAffixSlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(52, 52)
    slot:Hide()

    slot.Border = slot:CreateTexture(nil, "OVERLAY")
    slot.Border:SetAllPoints()
    SetRetailTexture(slot.Border, RETAIL_TEXTURES.AffixRing)
    slot.Border:SetVertexColor(1, 1, 1, 1)

    slot.Portrait = slot:CreateTexture(nil, "ARTWORK")
    slot.Portrait:SetSize(34, 34)
    slot.Portrait:SetPoint("CENTER", slot.Border, "CENTER")
    slot.Portrait:SetTexCoord(0.16, 0.84, 0.16, 0.84)

    slot.Percent = slot:CreateFontString(nil, "OVERLAY")
    slot.Percent:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE")
    slot.Percent:SetTextColor(1, 0.93, 0.55, 1)
    slot.Percent:SetShadowOffset(1, -1)
    slot.Percent:SetShadowColor(0, 0, 0, 1)
    slot.Percent:SetPoint("BOTTOM", slot.Border, "BOTTOM", 0, -4)
    slot.Percent:Hide()

    slot:EnableMouse(true)
    slot:SetScript("OnEnter", function(self)
        if not self.title then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.title, 1, 1, 1, 1, true)
        if self.description and self.description ~= "" then
            GameTooltip:AddLine(self.description, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return slot
end

local function CreatePartySlot(parent)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetSize(68, 16)
    slot:Hide()

    slot.RoleIcon = slot:CreateTexture(nil, "ARTWORK")
    slot.RoleIcon:SetTexture(ROLE_TEXTURE)
    slot.RoleIcon:SetSize(12, 12)
    slot.RoleIcon:SetPoint("LEFT", 0, 0)
    SetRoleCoords(slot.RoleIcon, "DPS")

    slot.Name = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.Name:SetPoint("LEFT", slot.RoleIcon, "RIGHT", 3, 0)
    slot.Name:SetWidth(42)
    slot.Name:SetJustifyH("LEFT")

    slot.Leader = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.Leader:SetPoint("LEFT", slot.Name, "RIGHT", 1, 0)
    slot.Leader:SetText("*")
    slot.Leader:SetTextColor(1, 0.82, 0.24, 1)
    slot.Leader:Hide()

    slot.Status = slot:CreateTexture(nil, "OVERLAY")
    slot.Status:SetSize(12, 12)
    slot.Status:SetPoint("RIGHT", 0, 0)

    return slot
end

local function CreateRotator(region, degrees, duration)
    if not region or not region.CreateAnimationGroup then
        return nil
    end

    local group = region:CreateAnimationGroup()
    if group.SetLooping then
        group:SetLooping("REPEAT")
    end

    local rotation = group:CreateAnimation("rotation")
    rotation:SetDegrees(degrees)
    rotation:SetDuration(duration)
    rotation:SetSmoothing("NONE")
    return group
end

local function CreateRuneNode(parent, relativeTo, offsetX, offsetY, runeTexture, runeOffsetX)
    local circle = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    SetRetailTexture(circle, RETAIL_TEXTURES.RunesCircleGlow)
    circle:SetSize(48, 48)
    circle:SetPoint("CENTER", relativeTo, "CENTER", offsetX, offsetY)
    circle:SetAlpha(0)

    local rune = parent:CreateTexture(nil, "OVERLAY", nil, 3)
    SetRetailTexture(rune, runeTexture)
    rune:SetSize(40, 40)
    rune:SetPoint("CENTER", circle, "CENTER", runeOffsetX or 0, 0)
    rune:SetAlpha(0)

    return {
        circle = circle,
        rune = rune,
    }
end

function KUI:CreateActivationFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "DCKeystoneActivationRetailFrame", UIParent)
    frame:SetSize(398, 548)
    frame:SetPoint("CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.BG = frame:CreateTexture(nil, "BACKGROUND")
    frame.BG:SetAllPoints()
    SetRetailTexture(frame.BG, RETAIL_TEXTURES.KeystoneFrame)
    frame.BG:SetVertexColor(1, 1, 1, 1)

    frame.BorderGlow = frame:CreateTexture(nil, "ARTWORK")
    frame.BorderGlow:SetAlpha(0)

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", -8, -9)
    frame.CloseButton:SetScript("OnClick", function()
        if KUI.currentState == KUI.STATE.COUNTDOWN then
            KUI:Hide()
        else
            KUI:CancelActivation()
        end
    end)

    frame.DungeonName = frame:CreateFontString(nil, "OVERLAY")
    frame.DungeonName:SetFont("Fonts\\MORPHEUS.TTF", 30, "")
    frame.DungeonName:SetWidth(350)
    frame.DungeonName:SetPoint("BOTTOM", 0, 160)
    frame.DungeonName:SetJustifyH("CENTER")
    frame.DungeonName:SetTextColor(1, 0.86, 0.38, 1)
    frame.DungeonName:Hide()

    frame.PowerLevel = frame:CreateFontString(nil, "OVERLAY")
    frame.PowerLevel:SetFont("Fonts\\MORPHEUS.TTF", 34, "")
    frame.PowerLevel:SetPoint("TOP", 0, -30)
    frame.PowerLevel:SetTextColor(1, 0.92, 0.55, 1)
    frame.PowerLevel:Hide()

    frame.TimeLimit = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.TimeLimit:SetPoint("BOTTOM", frame.DungeonName, "TOP", 0, 4)
    frame.TimeLimit:SetTextColor(0.95, 0.95, 0.95, 1)
    frame.TimeLimit:Hide()

    frame.InstructionBackground = frame:CreateTexture(nil, "ARTWORK")
    frame.InstructionBackground:SetSize(374, 60)
    frame.InstructionBackground:SetPoint("BOTTOM", 0, 80)
    frame.InstructionBackground:SetColorTexture(0, 0, 0, 0.80)

    frame.Divider = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    SetRetailTexture(frame.Divider, RETAIL_TEXTURES.ThinDivider)
    frame.Divider:SetSize(365, 3)
    frame.Divider:SetPoint("BOTTOM", frame.InstructionBackground, "TOP", 0, 0)

    frame.DungeonName:ClearAllPoints()
    frame.DungeonName:SetPoint("BOTTOM", frame.Divider, "TOP", 0, 18)
    frame.TimeLimit:ClearAllPoints()
    frame.TimeLimit:SetPoint("BOTTOM", frame.DungeonName, "TOP", 0, 6)

    frame.RuneBG = frame:CreateTexture(nil, "ARTWORK")
    SetRetailTexture(frame.RuneBG, RETAIL_TEXTURES.RuneBG)
    frame.RuneBG:SetSize(360, 360)
    frame.RuneBG:SetPoint("CENTER", 0, 60)

    frame.BgBurst2 = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    SetRetailTexture(frame.BgBurst2, RETAIL_TEXTURES.RunesBackgroundBurst)
    frame.BgBurst2:SetBlendMode("ADD")
    frame.BgBurst2:SetSize(300, 301)
    frame.BgBurst2:SetPoint("CENTER", 0, 61)
    frame.BgBurst2:SetAlpha(0)

    frame.PentagonLines = frame:CreateTexture(nil, "OVERLAY")
    SetRetailTexture(frame.PentagonLines, RETAIL_TEXTURES.RunesLineGlow)
    frame.PentagonLines:SetSize(242, 228)
    frame.PentagonLines:SetPoint("CENTER", frame.RuneBG, "CENTER", 0, 6)
    frame.PentagonLines:SetAlpha(0)

    frame.LargeCircleGlow = frame:CreateTexture(nil, "OVERLAY")
    SetRetailTexture(frame.LargeCircleGlow, RETAIL_TEXTURES.RunesInnerCircleGlow)
    frame.LargeCircleGlow:SetSize(211, 209)
    frame.LargeCircleGlow:SetPoint("CENTER", frame.RuneBG, "CENTER", 0, 5)
    frame.LargeCircleGlow:SetAlpha(0)

    frame.SmallCircleGlow = frame:CreateTexture(nil, "OVERLAY")
    SetRetailTexture(frame.SmallCircleGlow, RETAIL_TEXTURES.RunesSmallCircleGlow)
    frame.SmallCircleGlow:SetSize(130, 130)
    frame.SmallCircleGlow:SetPoint("CENTER", frame.RuneBG, "CENTER", 0, 1)
    frame.SmallCircleGlow:SetAlpha(0)

    frame.Shockwave = frame:CreateTexture(nil, "OVERLAY")
    SetRetailTexture(frame.Shockwave, RETAIL_TEXTURES.RunesShockwave)
    frame.Shockwave:SetBlendMode("ADD")
    frame.Shockwave:SetSize(206, 209)
    frame.Shockwave:SetPoint("CENTER", 0, 60)
    frame.Shockwave:SetAlpha(0)

    frame.Shockwave2 = frame:CreateTexture(nil, "OVERLAY")
    SetRetailTexture(frame.Shockwave2, RETAIL_TEXTURES.RunesShockwave)
    frame.Shockwave2:SetBlendMode("ADD")
    frame.Shockwave2:SetSize(206, 209)
    frame.Shockwave2:SetPoint("CENTER", 0, 60)
    frame.Shockwave2:SetAlpha(0)

    frame.RunesLarge = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    SetRetailTexture(frame.RunesLarge, RETAIL_TEXTURES.RunesLarge)
    frame.RunesLarge:SetSize(196, 196)
    frame.RunesLarge:SetPoint("CENTER", 0, 61)

    frame.LargeRuneGlow = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    SetRetailTexture(frame.LargeRuneGlow, RETAIL_TEXTURES.RunesGlowLarge)
    frame.LargeRuneGlow:SetBlendMode("ADD")
    frame.LargeRuneGlow:SetSize(198, 199)
    frame.LargeRuneGlow:SetPoint("CENTER", 0, 61)
    frame.LargeRuneGlow:SetAlpha(0)

    frame.GlowBurstLarge = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    SetRetailTexture(frame.GlowBurstLarge, RETAIL_TEXTURES.RunesGlowBurstLarge)
    frame.GlowBurstLarge:SetBlendMode("ADD")
    frame.GlowBurstLarge:SetSize(234, 234)
    frame.GlowBurstLarge:SetPoint("CENTER", frame.RunesLarge, "CENTER", -1, -3)
    frame.GlowBurstLarge:SetAlpha(0)

    frame.RunesSmall = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    SetRetailTexture(frame.RunesSmall, RETAIL_TEXTURES.RunesSmall)
    frame.RunesSmall:SetSize(125, 125)
    frame.RunesSmall:SetPoint("CENTER", 0, 61)

    frame.SmallRuneGlow = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    SetRetailTexture(frame.SmallRuneGlow, RETAIL_TEXTURES.RunesGlowSmall)
    frame.SmallRuneGlow:SetBlendMode("ADD")
    frame.SmallRuneGlow:SetSize(129, 129)
    frame.SmallRuneGlow:SetPoint("CENTER", 0, 61)
    frame.SmallRuneGlow:SetAlpha(0)

    frame.GlowBurstSmall = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    SetRetailTexture(frame.GlowBurstSmall, RETAIL_TEXTURES.RunesGlowBurstLarge)
    frame.GlowBurstSmall:SetBlendMode("BLEND")
    frame.GlowBurstSmall:SetSize(234, 234)
    frame.GlowBurstSmall:SetPoint("CENTER", 0, 60)
    frame.GlowBurstSmall:SetAlpha(0)

    frame.SlotBG = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    SetRetailTexture(frame.SlotBG, RETAIL_TEXTURES.KeystoneSlotBG)
    frame.SlotBG:SetSize(114, 114)
    frame.SlotBG:SetPoint("CENTER", 0, 61)

    frame.KeystoneFrame = frame:CreateTexture(nil, "OVERLAY", nil, 3)
    SetRetailTexture(frame.KeystoneFrame, RETAIL_TEXTURES.KeystoneSlotFrame)
    frame.KeystoneFrame:SetSize(120, 120)
    frame.KeystoneFrame:SetPoint("CENTER", 0, 61)

    frame.KeystoneSlotGlow = frame:CreateTexture(nil, "OVERLAY", nil, 4)
    SetRetailTexture(frame.KeystoneSlotGlow, RETAIL_TEXTURES.KeystoneSlotFrameGlow)
    frame.KeystoneSlotGlow:SetBlendMode("ADD")
    frame.KeystoneSlotGlow:SetSize(120, 120)
    frame.KeystoneSlotGlow:SetPoint("CENTER", 0, 60)
    frame.KeystoneSlotGlow:SetAlpha(0)

    frame.KeystoneSlot = CreateFrame("Button", nil, frame)
    frame.KeystoneSlot:SetSize(48, 48)
    frame.KeystoneSlot:SetPoint("CENTER", frame.SlotBG, "CENTER")
    frame.KeystoneSlot:RegisterForClicks("AnyUp")

    frame.KeystoneTexture = frame.KeystoneSlot:CreateTexture(nil, "OVERLAY")
    frame.KeystoneTexture:SetSize(36, 36)
    frame.KeystoneTexture:SetPoint("CENTER")
    frame.KeystoneTexture:SetTexture(KEYSTONE_ICON)
    frame.KeystoneTexture:SetTexCoord(0.14, 0.86, 0.14, 0.86)

    frame.KeystoneSlot:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" then
            return
        end

        if KUI.currentState ~= KUI.STATE.READY_CHECK then
            return
        end

        KUI:CancelActivation()
    end)

    frame.KeystoneSlot:SetScript("OnEnter", function(self)
        local data = KUI.keystoneData or {}
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.itemLink then
            GameTooltip:SetHyperlink(data.itemLink)
        else
            GameTooltip:SetText(string.format("Mythic Keystone +%d", tonumber(data.level) or 0), 1, 0.82, 0.24, 1)
            if data.dungeonName and data.dungeonName ~= "" then
                GameTooltip:AddLine(data.dungeonName, 0.95, 0.95, 0.95, true)
            end
        end
        if KUI.currentState == KUI.STATE.READY_CHECK then
            GameTooltip:AddLine("Right-click to remove the keystone.", 0.82, 0.82, 0.82, true)
        end
        GameTooltip:Show()
    end)
    frame.KeystoneSlot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.RuneNodes = {
        CreateRuneNode(frame, frame.RuneBG, 0, 126, RETAIL_TEXTURES.RunesTGlow),
        CreateRuneNode(frame, frame.RuneBG, 118, 40, RETAIL_TEXTURES.RunesRGlow, -1),
        CreateRuneNode(frame, frame.RuneBG, 73, -98, RETAIL_TEXTURES.RunesBRGlow, -1),
        CreateRuneNode(frame, frame.RuneBG, -73, -98, RETAIL_TEXTURES.RunesBLGlow, -1),
        CreateRuneNode(frame, frame.RuneBG, -118, 40, RETAIL_TEXTURES.RunesLGlow),
    }

    frame.affixSlots = {}
    for index = 1, 6 do
        frame.affixSlots[index] = CreateAffixSlot(frame)
    end

    frame.PartyContainer = CreateFrame("Frame", nil, frame)
    frame.PartyContainer:SetSize(374, 16)
    frame.PartyContainer:SetPoint("BOTTOM", frame.InstructionBackground, "BOTTOM", 0, 8)
    frame.PartyContainer:Hide()

    frame.partySlots = {}
    for index = 1, 5 do
        local slot = CreatePartySlot(frame.PartyContainer)
        frame.partySlots[index] = slot
    end

    frame.Instructions = frame:CreateFontString(nil, "OVERLAY")
    frame.Instructions:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    frame.Instructions:SetPoint("CENTER", frame.InstructionBackground, "CENTER", 0, 0)
    frame.Instructions:SetTextColor(0.95, 0.95, 0.95, 1)
    frame.Instructions:SetText("Insert Mythic Keystone")

    frame.ReadyProgress = frame:CreateFontString(nil, "OVERLAY")
    frame.ReadyProgress:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    frame.ReadyProgress:SetPoint("TOP", frame.Instructions, "BOTTOM", 0, -2)
    frame.ReadyProgress:SetTextColor(0.82, 0.82, 0.82, 1)
    frame.ReadyProgress:SetText("")

    frame.StartButton = CreateRetailButton(frame, "Activate")
    frame.StartButton:SetPoint("BOTTOM", 0, 20)
    frame.StartButton:SetScript("OnClick", function()
        KUI:SendReady()
    end)

    frame.CountdownShade = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    frame.CountdownShade:SetAllPoints()
    frame.CountdownShade:SetColorTexture(0, 0, 0, 1)
    frame.CountdownShade:SetAlpha(0)
    frame.CountdownShade:Hide()

    frame.CountdownBlackFade = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    SetRetailTexture(frame.CountdownBlackFade, RETAIL_TEXTURES.CountdownBlackFade)
    frame.CountdownBlackFade:SetSize(333, 61)
    frame.CountdownBlackFade:SetPoint("CENTER", 0, 61)
    frame.CountdownBlackFade:SetAlpha(0)
    frame.CountdownBlackFade:Hide()

    frame.CountdownTimerBG = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    SetRetailTexture(frame.CountdownTimerBG, RETAIL_TEXTURES.CountdownTimerBG)
    frame.CountdownTimerBG:SetSize(243, 59)
    frame.CountdownTimerBG:SetPoint("CENTER", 0, 61)
    frame.CountdownTimerBG:SetAlpha(0)
    frame.CountdownTimerBG:Hide()

    frame.CountdownTimerFrame = frame:CreateTexture(nil, "OVERLAY", nil, 8)
    SetRetailTexture(frame.CountdownTimerFrame, RETAIL_TEXTURES.CountdownTimerFrame)
    frame.CountdownTimerFrame:SetSize(261, 87)
    frame.CountdownTimerFrame:SetPoint("CENTER", 0, 61)
    frame.CountdownTimerFrame:SetAlpha(0)
    frame.CountdownTimerFrame:Hide()

    frame.CountdownTimerBorder = frame:CreateTexture(nil, "OVERLAY", nil, 9)
    SetRetailTexture(frame.CountdownTimerBorder, RETAIL_TEXTURES.CountdownTimerBorder)
    frame.CountdownTimerBorder:SetSize(184, 23)
    frame.CountdownTimerBorder:SetPoint("CENTER", 0, 33)
    frame.CountdownTimerBorder:SetAlpha(0)
    frame.CountdownTimerBorder:Hide()

    frame.CountdownSoftGlow = frame:CreateTexture(nil, "OVERLAY", nil, 9)
    SetRetailTexture(frame.CountdownSoftGlow, RETAIL_TEXTURES.CountdownSoftYellowGlow)
    frame.CountdownSoftGlow:SetBlendMode("ADD")
    frame.CountdownSoftGlow:SetSize(206, 206)
    frame.CountdownSoftGlow:SetPoint("CENTER", 0, 61)
    frame.CountdownSoftGlow:SetAlpha(0)
    frame.CountdownSoftGlow:Hide()

    frame.CountdownLaunchGlow = frame:CreateTexture(nil, "OVERLAY", nil, 10)
    SetRetailTexture(frame.CountdownLaunchGlow, RETAIL_TEXTURES.CountdownWhiteSpikeyGlow)
    frame.CountdownLaunchGlow:SetBlendMode("ADD")
    frame.CountdownLaunchGlow:SetSize(186, 209)
    frame.CountdownLaunchGlow:SetPoint("CENTER", 0, 61)
    frame.CountdownLaunchGlow:SetAlpha(0)
    frame.CountdownLaunchGlow:Hide()

    frame.CountdownLaunchShine = frame:CreateTexture(nil, "OVERLAY", nil, 11)
    SetRetailTexture(frame.CountdownLaunchShine, RETAIL_TEXTURES.CountdownBannerShine)
    frame.CountdownLaunchShine:SetBlendMode("ADD")
    frame.CountdownLaunchShine:SetSize(222, 106)
    frame.CountdownLaunchShine:SetPoint("CENTER", 0, 61)
    frame.CountdownLaunchShine:SetAlpha(0)
    frame.CountdownLaunchShine:Hide()

    frame.CountdownText = frame:CreateFontString(nil, "OVERLAY")
    frame.CountdownText:SetFont("Fonts\\MORPHEUS.TTF", 58, "")
    frame.CountdownText:SetPoint("CENTER", 0, 61)
    frame.CountdownText:SetTextColor(1, 0.84, 0.20, 1)
    frame.CountdownText:SetShadowOffset(1, -1)
    frame.CountdownText:SetShadowColor(0, 0, 0, 1)
    frame.CountdownText:SetText("")
    frame.CountdownText:Hide()

    frame.largeRotator = CreateRotator(frame.RunesLarge, -360, 60)
    frame.smallRotator = CreateRotator(frame.RunesSmall, 360, 60)

    tinsert(UISpecialFrames, "DCKeystoneActivationRetailFrame")
    self.frame = frame
    self:ResetVisualState()
    return frame
end

function KUI:ResetVisualState()
    if not self.frame then
        return
    end

    self.frame.KeystoneSlotGlow:SetAlpha(0)
    self.frame.PentagonLines:SetAlpha(0)
    self.frame.LargeCircleGlow:SetAlpha(0)
    self.frame.SmallCircleGlow:SetAlpha(0)
    self.frame.Shockwave:SetAlpha(0)
    SetRegionScale(self.frame.Shockwave, 0.65)
    self.frame.Shockwave2:SetAlpha(0)
    SetRegionScale(self.frame.Shockwave2, 0.50)
    self.frame.LargeRuneGlow:SetAlpha(0)
    self.frame.SmallRuneGlow:SetAlpha(0)
    self.frame.BgBurst2:SetAlpha(0)
    self.frame.GlowBurstLarge:SetAlpha(0)
    SetRegionScale(self.frame.GlowBurstLarge, 0.8)
    self.frame.GlowBurstSmall:SetAlpha(0)
    SetRegionScale(self.frame.GlowBurstSmall, 0.5)
    self.frame.RunesLarge:SetAlpha(0.15)
    self.frame.RunesSmall:SetAlpha(0.15)
    self.frame.CountdownShade:SetAlpha(0)
    self.frame.CountdownBlackFade:SetAlpha(0)
    SetRegionScale(self.frame.CountdownBlackFade, 1)
    self.frame.CountdownTimerBG:SetAlpha(0)
    SetRegionScale(self.frame.CountdownTimerBG, 1)
    self.frame.CountdownTimerFrame:SetAlpha(0)
    SetRegionScale(self.frame.CountdownTimerFrame, 1)
    self.frame.CountdownTimerBorder:SetAlpha(0)
    SetRegionScale(self.frame.CountdownTimerBorder, 1)
    self.frame.CountdownSoftGlow:SetAlpha(0)
    SetRegionScale(self.frame.CountdownSoftGlow, 1)
    self.frame.CountdownLaunchGlow:SetAlpha(0)
    SetRegionScale(self.frame.CountdownLaunchGlow, 0.78)
    self.frame.CountdownLaunchShine:SetAlpha(0)
    SetRegionScale(self.frame.CountdownLaunchShine, 0.92)
    SetRegionScale(self.frame.CountdownText, 1)
    self.frame.CountdownText:SetAlpha(1)
    self:SetCountdownOverlayVisible(false)

    for _, node in ipairs(self.frame.RuneNodes or {}) do
        node.circle:SetAlpha(0)
        node.rune:SetAlpha(0)
    end
end

function KUI:SetCountdownOverlayVisible(visible)
    if not self.frame then
        return
    end

    local keys = {
        "CountdownShade",
        "CountdownBlackFade",
        "CountdownTimerBG",
        "CountdownTimerFrame",
        "CountdownTimerBorder",
        "CountdownSoftGlow",
        "CountdownLaunchGlow",
        "CountdownLaunchShine",
    }

    for _, key in ipairs(keys) do
        local region = self.frame[key]
        if region then
            if visible then
                region:Show()
            else
                region:Hide()
            end
        end
    end
end

function KUI:SetCountdownOverlayBaseState()
    if not self.frame then
        return
    end

    self.frame.CountdownShade:SetAlpha(0.36)
    self.frame.CountdownBlackFade:SetAlpha(0.82)
    SetRegionScale(self.frame.CountdownBlackFade, 1)
    self.frame.CountdownTimerBG:SetAlpha(0.92)
    SetRegionScale(self.frame.CountdownTimerBG, 1)
    self.frame.CountdownTimerFrame:SetAlpha(1)
    SetRegionScale(self.frame.CountdownTimerFrame, 1)
    self.frame.CountdownTimerBorder:SetAlpha(0.60)
    SetRegionScale(self.frame.CountdownTimerBorder, 1)
    self.frame.CountdownSoftGlow:SetAlpha(0.10)
    SetRegionScale(self.frame.CountdownSoftGlow, 1)
    self.frame.CountdownLaunchGlow:SetAlpha(0)
    SetRegionScale(self.frame.CountdownLaunchGlow, 0.78)
    self.frame.CountdownLaunchShine:SetAlpha(0)
    SetRegionScale(self.frame.CountdownLaunchShine, 0.92)
end

function KUI:SetBottomStatusVisible(visible)
    if not self.frame then
        return
    end

    self.frame.InstructionBackground:Hide()
    self.frame.Instructions:Hide()
    self.frame.ReadyProgress:Hide()
    if visible then
        self.frame.Divider:Show()
    else
        self.frame.Divider:Hide()
    end
    self.frame.PartyContainer:Hide()
end

function KUI:StopPulseAnimation()
    if self.pulseDriver then
        self.pulseDriver:SetScript("OnUpdate", nil)
    end
    if self.insertDriver then
        self.insertDriver:SetScript("OnUpdate", nil)
    end
    if self.shockwaveDriver then
        self.shockwaveDriver:SetScript("OnUpdate", nil)
    end
    if self.countdownTextDriver then
        self.countdownTextDriver:SetScript("OnUpdate", nil)
    end
    if self.frame and self.frame.largeRotator then
        self.frame.largeRotator:Stop()
    end
    if self.frame and self.frame.smallRotator then
        self.frame.smallRotator:Stop()
    end
end

function KUI:PlayShockwaveBurst(primaryAlpha, secondaryAlpha)
    if not self.frame then
        return
    end

    local primaryPeak = tonumber(primaryAlpha) or 0.70
    local secondaryPeak = tonumber(secondaryAlpha) or (primaryPeak * 0.75)
    local duration = 0.48
    local delay = 0.10
    local startTime = GetTime()

    SetRegionScale(self.frame.Shockwave, 0.65)
    self.frame.Shockwave:SetAlpha(0)
    SetRegionScale(self.frame.Shockwave2, 0.50)
    self.frame.Shockwave2:SetAlpha(0)

    self.shockwaveDriver = self.shockwaveDriver or CreateFrame("Frame")
    self.shockwaveDriver:SetScript("OnUpdate", function(driver)
        local elapsed = GetTime() - startTime
        local primaryProgress = WindowProgress(elapsed, 0, duration)
        local secondaryProgress = WindowProgress(elapsed, delay, duration)

        SetBurstScaleAndAlpha(KUI.frame.Shockwave, primaryProgress, 0.65, 1.08,
            primaryPeak)
        SetBurstScaleAndAlpha(KUI.frame.Shockwave2, secondaryProgress, 0.50,
            1.22, secondaryPeak)

        if elapsed >= (duration + delay) then
            driver:SetScript("OnUpdate", nil)
            KUI.frame.Shockwave:SetAlpha(0)
            SetRegionScale(KUI.frame.Shockwave, 0.65)
            KUI.frame.Shockwave2:SetAlpha(0)
            SetRegionScale(KUI.frame.Shockwave2, 0.50)
        end
    end)
end

function KUI:PlayCountdownTickAnimation(isLaunch)
    if not self.frame then
        return
    end

    local startScale = isLaunch and 1.32 or 1.16
    local startAlpha = isLaunch and 1 or 0.96
    local panelStartScale = isLaunch and 1.10 or 1.04
    local glowStartScale = isLaunch and 1.18 or 1.08
    local duration = isLaunch and 0.40 or 0.22
    local startTime = GetTime()

    self:SetCountdownOverlayVisible(true)
    self:SetCountdownOverlayBaseState()
    SetRegionScale(self.frame.CountdownText, startScale)
    self.frame.CountdownText:SetAlpha(startAlpha)
    self:PlayShockwaveBurst(isLaunch and 0.92 or 0.62,
        isLaunch and 0.72 or 0.46)

    self.countdownTextDriver = self.countdownTextDriver or CreateFrame("Frame")
    self.countdownTextDriver:SetScript("OnUpdate", function(driver)
        local progress = WindowProgress(GetTime() - startTime, 0, duration)
        SetRegionScale(KUI.frame.CountdownText, Lerp(startScale, 1, progress))
        KUI.frame.CountdownText:SetAlpha(Lerp(startAlpha, 1, progress))

        KUI.frame.CountdownShade:SetAlpha(Lerp(isLaunch and 0.48 or 0.42,
            isLaunch and 0.00 or 0.36, progress))
        KUI.frame.CountdownBlackFade:SetAlpha(Lerp(isLaunch and 0.95 or 0.90,
            isLaunch and 0.00 or 0.82, progress))
        KUI.frame.CountdownTimerBG:SetAlpha(Lerp(1.0,
            isLaunch and 0.00 or 0.92, progress))
        SetRegionScale(KUI.frame.CountdownTimerBG,
            Lerp(panelStartScale, 1, progress))
        KUI.frame.CountdownTimerFrame:SetAlpha(Lerp(1.0,
            isLaunch and 0.12 or 1.0, progress))
        SetRegionScale(KUI.frame.CountdownTimerFrame,
            Lerp(panelStartScale, 1, progress))
        KUI.frame.CountdownTimerBorder:SetAlpha(Lerp(isLaunch and 0.95 or 0.82,
            isLaunch and 0.00 or 0.60, progress))
        SetRegionScale(KUI.frame.CountdownTimerBorder,
            Lerp(panelStartScale + 0.02, 1, progress))
        KUI.frame.CountdownSoftGlow:SetAlpha(Lerp(isLaunch and 0.52 or 0.34,
            isLaunch and 0.00 or 0.10, progress))
        SetRegionScale(KUI.frame.CountdownSoftGlow,
            Lerp(glowStartScale, isLaunch and 1.30 or 1, progress))

        if isLaunch then
            KUI.frame.CountdownLaunchGlow:SetAlpha((1 - progress) * 0.95)
            SetRegionScale(KUI.frame.CountdownLaunchGlow,
                Lerp(0.78, 1.36, progress))
            KUI.frame.CountdownLaunchShine:SetAlpha((1 - progress) * 0.82)
            SetRegionScale(KUI.frame.CountdownLaunchShine,
                Lerp(0.92, 1.14, progress))
        else
            KUI.frame.CountdownLaunchGlow:SetAlpha(0)
            KUI.frame.CountdownLaunchShine:SetAlpha(0)
        end

        if progress >= 1 then
            driver:SetScript("OnUpdate", nil)
            SetRegionScale(KUI.frame.CountdownText, 1)
            KUI.frame.CountdownText:SetAlpha(1)
            if isLaunch then
                KUI.frame.CountdownShade:SetAlpha(0)
                KUI.frame.CountdownBlackFade:SetAlpha(0)
                KUI.frame.CountdownTimerBG:SetAlpha(0)
                KUI.frame.CountdownTimerFrame:SetAlpha(0.10)
                KUI.frame.CountdownTimerBorder:SetAlpha(0)
                KUI.frame.CountdownSoftGlow:SetAlpha(0)
                KUI.frame.CountdownLaunchGlow:SetAlpha(0)
                KUI.frame.CountdownLaunchShine:SetAlpha(0)
            else
                KUI:SetCountdownOverlayBaseState()
            end
        end
    end)
end

function KUI:StartPulseAnimation()
    if not self.frame then
        return
    end

    if self.frame.largeRotator then
        self.frame.largeRotator:Play()
    end
    if self.frame.smallRotator then
        self.frame.smallRotator:Play()
    end

    self.frame.KeystoneSlotGlow:SetAlpha(1)
    self.frame.PentagonLines:SetAlpha(0.55)
    self.frame.LargeCircleGlow:SetAlpha(0.55)
    self.frame.SmallCircleGlow:SetAlpha(0.55)
    self.frame.RunesLarge:SetAlpha(1)
    self.frame.RunesSmall:SetAlpha(1)

    for _, node in ipairs(self.frame.RuneNodes or {}) do
        node.circle:SetAlpha(1)
        node.rune:SetAlpha(1)
    end

    self.pulseDriver = self.pulseDriver or CreateFrame("Frame")
    local elapsedTotal = 0
    self.pulseDriver:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        local cycle = math.fmod(elapsedTotal, 3.0)

        if cycle <= 1.5 then
            KUI.frame.BgBurst2:SetAlpha(Lerp(0, 0.75, cycle / 1.5))
        else
            KUI.frame.BgBurst2:SetAlpha(Lerp(0.75, 0, (cycle - 1.5) / 1.5))
        end
    end)
end

function KUI:PlayInsertAnimation()
    if not self.frame then
        return
    end

    self:StopPulseAnimation()
    self:ResetVisualState()
    self.insertAnimating = true
    self.frame.StartButton:Disable()

    if self.frame.largeRotator then
        self.frame.largeRotator:Play()
    end
    if self.frame.smallRotator then
        self.frame.smallRotator:Play()
    end

    local duration = 1.60
    local startTime = GetTime()
    local firedShockwave = false
    self.insertDriver = self.insertDriver or CreateFrame("Frame")
    self.insertDriver:SetScript("OnUpdate", function(driver)
        local elapsed = GetTime() - startTime
        local ringProgress = WindowProgress(elapsed, 0.35, 0.35)
        local runeProgress = WindowProgress(elapsed, 0.45, 0.45)
        local largeBurstProgress = WindowProgress(elapsed, 0, 0.5)
        local smallBurstProgress = WindowProgress(elapsed, 0, 0.5)

        if not firedShockwave and elapsed >= 0.25 then
            firedShockwave = true
            KUI:PlayShockwaveBurst(0.70, 0.52)
        end

        KUI.frame.KeystoneSlotGlow:SetAlpha(WindowProgress(elapsed, 0, 0.15))
        KUI.frame.PentagonLines:SetAlpha(FadeToValue(elapsed, 0.15, 0.25, 1,
            0.55, 1.0, 0.55))
        KUI.frame.LargeCircleGlow:SetAlpha(FadeToValue(elapsed, 0.05, 0.25, 1,
            0.35, 1.0, 0.55))
        KUI.frame.SmallCircleGlow:SetAlpha(FadeToValue(elapsed, 0.00, 0.25, 1,
            0.25, 1.0, 0.55))
        KUI.frame.LargeRuneGlow:SetAlpha(FadeToValue(elapsed, 0.10, 0.25, 1,
            0.60, 1.0, 0.00))
        KUI.frame.SmallRuneGlow:SetAlpha(FadeToValue(elapsed, 0.00, 0.25, 1,
            0.50, 1.0, 0.00))
        KUI.frame.RunesLarge:SetAlpha(Lerp(0.15, 1,
            WindowProgress(elapsed, 0, 0.25)))
        KUI.frame.RunesSmall:SetAlpha(Lerp(0.15, 1,
            WindowProgress(elapsed, 0, 0.25)))
        KUI.frame.GlowBurstLarge:SetAlpha(FadeToValue(elapsed, 0.25, 0.25, 1,
            0.50, 0.50, 0.00))
        SetRegionScale(KUI.frame.GlowBurstLarge,
            Lerp(0.8, 1.0, largeBurstProgress))
        KUI.frame.GlowBurstSmall:SetAlpha(FadeToValue(elapsed, 0.00, 0.25, 1,
            0.25, 0.50, 0.00))
        SetRegionScale(KUI.frame.GlowBurstSmall,
            Lerp(0.5, 0.65, smallBurstProgress))

        for _, node in ipairs(KUI.frame.RuneNodes or {}) do
            node.circle:SetAlpha(ringProgress)
            node.rune:SetAlpha(runeProgress)
        end

        if elapsed >= duration then
            driver:SetScript("OnUpdate", nil)
            KUI.insertAnimating = false
            KUI:StartPulseAnimation()
            KUI:RefreshButtons()
        end
    end)
end

function KUI:StopCountdown()
    if self.countdownDriver then
        self.countdownDriver:SetScript("OnUpdate", nil)
    end

    if self.currentState == self.STATE.COUNTDOWN then
        self.currentState = self.STATE.READY_CHECK
    end

    if self.frame then
        self:SetCountdownOverlayVisible(false)
        self.frame.CountdownText:Hide()
        SetRegionScale(self.frame.CountdownText, 1)
        self.frame.CountdownText:SetAlpha(1)
    end
end

function KUI:GetReadyProgress()
    local readyCount = 0
    local totalCount = 0

    for _, member in ipairs(self.partyMembers or {}) do
        totalCount = totalCount + 1
        if member.ready then
            readyCount = readyCount + 1
        end
    end

    if self.keystoneData and (tonumber(self.keystoneData.totalCount) or 0) > totalCount then
        totalCount = tonumber(self.keystoneData.totalCount) or totalCount
    end
    if self.keystoneData and (tonumber(self.keystoneData.readyCount) or 0) > readyCount then
        readyCount = tonumber(self.keystoneData.readyCount) or readyCount
    end

    local allReady = self.keystoneData and Truthy(self.keystoneData.allReady) or false
    if totalCount > 0 and readyCount >= totalCount then
        allReady = true
    end

    return readyCount, totalCount, allReady
end

function KUI:HasInsertedKeystone()
    local data = self.keystoneData or {}

    if (tonumber(data.level) or 0) > 0 then
        return true
    end

    return data.itemId ~= nil or
        data.itemTexture ~= nil or
        (type(data.itemLink) == "string" and data.itemLink ~= "")
end

function KUI:IsLocalPlayerReady()
    local playerName = UnitName and UnitName("player") or nil
    if not playerName then
        return false
    end

    for _, member in ipairs(self.partyMembers or {}) do
        if member.name == playerName then
            return Truthy(member.ready)
        end
    end

    return false
end

function KUI:LayoutAffixes(count)
    if not self.frame or count <= 0 then
        return
    end

    local frameWidth = 52
    local spacing = 4
    local offsetX
    if math.fmod(count, 2) == 1 then
        local x = (count - 1) / 2
        offsetX = -((frameWidth / 2) + (frameWidth * x) + (spacing * x))
    else
        local x = count / 2
        offsetX = -((frameWidth * x) + (spacing * (x - 1)) + (spacing / 2))
    end

    self.frame.affixSlots[1]:ClearAllPoints()
    self.frame.affixSlots[1]:SetPoint("TOPLEFT", self.frame.Divider, "TOP", offsetX, -6)

    for index = 2, count do
        self.frame.affixSlots[index]:ClearAllPoints()
        self.frame.affixSlots[index]:SetPoint("LEFT", self.frame.affixSlots[index - 1], "RIGHT", spacing, 0)
    end
end

function KUI:UpdateArt()
    if not self.frame then
        return
    end

    local data = self.keystoneData or {}
    local texture, resolvedLink = ResolveKeystoneItemTexture(data.itemId,
        data.itemLink, data.bag, data.slot)

    if texture and type(SetPortraitToTexture) == "function" then
        SetPortraitToTexture(self.frame.KeystoneTexture, texture)
    else
        self.frame.KeystoneTexture:SetTexture(texture or KEYSTONE_ICON)
    end

    self.frame.KeystoneTexture:SetTexCoord(0.14, 0.86, 0.14, 0.86)

    if not self.frame.KeystoneTexture:GetTexture() then
        self.frame.KeystoneTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.frame.KeystoneTexture:SetTexCoord(0.14, 0.86, 0.14, 0.86)
    end

    self.keystoneData.itemLink = resolvedLink or self.keystoneData.itemLink
end

function KUI:UpdateAffixes()
    if not self.frame then
        return
    end

    local entries = {}
    local data = self.keystoneData or {}

    if (tonumber(data.damagePct) or 0) > 0 then
        entries[#entries + 1] = {
            icon = "Interface\\Icons\\Ability_DualWield",
            label = string.format("+%d%%", tonumber(data.damagePct) or 0),
            title = "Enemy Damage",
            description = string.format("Enemies deal %d%% more damage at this keystone level.", tonumber(data.damagePct) or 0),
        }
    end

    if (tonumber(data.healthPct) or 0) > 0 then
        entries[#entries + 1] = {
            icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
            label = string.format("+%d%%", tonumber(data.healthPct) or 0),
            title = "Enemy Health",
            description = string.format("Enemies have %d%% more health at this keystone level.", tonumber(data.healthPct) or 0),
        }
    end

    for _, affix in ipairs(data.affixes or {}) do
        local id, name, description, icon = ResolveAffixInfo(affix)
        entries[#entries + 1] = {
            icon = icon or AFFIX_ICONS[id] or "Interface\\Icons\\INV_Misc_QuestionMark",
            label = nil,
            title = name or "Affix",
            description = description or "",
        }
    end

    self:LayoutAffixes(math.min(#entries, #self.frame.affixSlots))

    for index, slot in ipairs(self.frame.affixSlots or {}) do
        local entry = entries[index]
        if entry then
            slot.Portrait:SetTexture(entry.icon)
            slot.title = entry.title
            slot.description = entry.description
            if entry.label then
                slot.Percent:SetText(entry.label)
                slot.Percent:Show()
            else
                slot.Percent:Hide()
            end
            slot:Show()
        else
            slot.title = nil
            slot.description = nil
            slot.Percent:Hide()
            slot:Hide()
        end
    end
end

function KUI:UpdatePartyMembers()
    if not self.frame then
        return
    end

    local visibleCount = 0
    for index, slot in ipairs(self.frame.partySlots or {}) do
        local member = self.partyMembers and self.partyMembers[index]
        if member then
            visibleCount = visibleCount + 1
            slot.memberGuid = member.guid
            slot.memberName = member.name
            SetRoleCoords(slot.RoleIcon, member.role)
            slot.Name:SetText(ShortenMemberName(member.name or "-"))
            if Truthy(member.leader) then
                slot.Name:SetTextColor(1, 0.82, 0.24, 1)
                slot.Leader:Show()
            else
                slot.Name:SetTextColor(0.95, 0.95, 0.95, 1)
                slot.Leader:Hide()
            end
            slot.Status:SetTexture(GetReadyStateTexture(member))
            slot:Show()
        else
            slot.memberGuid = nil
            slot.memberName = nil
            slot.Leader:Hide()
            slot:Hide()
        end
    end

    self:LayoutPartyMembers(visibleCount)
    self.frame.PartyContainer:Hide()
end

function KUI:LayoutPartyMembers(count)
    if not self.frame then
        return
    end

    local stride = 76
    local startOffset = -(((count - 1) * stride) / 2)
    local visibleIndex = 0

    for _, slot in ipairs(self.frame.partySlots or {}) do
        if slot:IsShown() then
            local offset = startOffset + (visibleIndex * stride)
            slot:ClearAllPoints()
            slot:SetPoint("CENTER", self.frame.PartyContainer, "CENTER",
                offset, 0)
            visibleIndex = visibleIndex + 1
        end
    end
end

function KUI:RefreshButtons()
    if not self.frame then
        return
    end

    local button = self.frame.StartButton
    local _, _, allReady = self:GetReadyProgress()
    local hasKeystone = self:HasInsertedKeystone()

    if self.currentState == self.STATE.COUNTDOWN then
        button:Hide()
        return
    end

    button:Show()
    button:ClearAllPoints()
    button:SetPoint("BOTTOM", 0, 20)

    if not hasKeystone then
        SetButtonText(button, "Activate")
        button:Disable()
        return
    end

    if self.insertAnimating then
        SetButtonText(button, "Activate")
        button:Disable()
        return
    end

    if allReady then
        SetButtonText(button, "Activating...")
        button:Disable()
        return
    end

    SetButtonText(button, "Activate")
    button:Enable()
end

function KUI:RefreshStatusText()
    if not self.frame then
        return
    end

    local readyCount, totalCount, allReady = self:GetReadyProgress()

    if self.currentState == self.STATE.COUNTDOWN then
        self:SetBottomStatusVisible(false)
        self.frame.Instructions:SetText("")
        self.frame.ReadyProgress:SetText("")
        return
    end

    self:SetBottomStatusVisible(true)

    self.frame.ReadyProgress:SetTextColor(0.82, 0.82, 0.82, 1)

    if not self.keystoneData or not self.keystoneData.dungeonName or self.keystoneData.dungeonName == "" then
        self.frame.Instructions:SetText("Insert Mythic Keystone")
        self.frame.ReadyProgress:SetText("")
        return
    end

    if allReady then
        self.frame.Instructions:SetText("All players activated")
        self.frame.ReadyProgress:SetTextColor(0.50, 0.95, 0.72, 1)
        self.frame.ReadyProgress:SetText("Countdown starting...")
        return
    end

    if totalCount > 0 then
        if self.isLeader then
            self.frame.Instructions:SetText("Activate to begin the challenge")
        elseif self:IsLocalPlayerReady() then
            self.frame.Instructions:SetText("Awaiting party activation")
        else
            self.frame.Instructions:SetText("Activate to join the challenge")
        end
        self.frame.ReadyProgress:SetText(string.format("%d/%d Activated", readyCount, totalCount))
    else
        self.frame.Instructions:SetText("Preparing keystone details")
        self.frame.ReadyProgress:SetText("")
    end
end

function KUI:RefreshTexts()
    if not self.frame then
        return
    end

    local data = self.keystoneData or {}
    local level = tonumber(data.level) or 0
    if level > 0 then
        self.frame.PowerLevel:SetText(string.format("Level +%d", level))
        self.frame.PowerLevel:Show()
    else
        self.frame.PowerLevel:Hide()
    end

    if data.dungeonName and data.dungeonName ~= "" then
        self.frame.DungeonName:SetText(data.dungeonName)
        self.frame.DungeonName:Show()
        self.frame.TimeLimit:SetText(FormatTimeLimit(data.timeLimit))
        self.frame.TimeLimit:Show()
    else
        self.frame.DungeonName:Hide()
        self.frame.TimeLimit:Hide()
    end
end

function KUI:RefreshView()
    self:CreateActivationFrame()
    self:UpdateArt()
    self:UpdateAffixes()
    self:UpdatePartyMembers()
    self:RefreshTexts()
    self:RefreshStatusText()
    self:RefreshButtons()
end

function KUI:SetKeystoneData(data)
    data = data or {}
    local resolvedData = data
    if type(namespace.ApplyMythicPlusDungeonDescriptor) == "function" then
        resolvedData = namespace.ApplyMythicPlusDungeonDescriptor(data)
    end

    self.keystoneData = {
        dungeonName = resolvedData.dungeonName or resolvedData.name
            or resolvedData.dungeon or "",
        shortName = resolvedData.shortName or resolvedData.short,
        mapId = tonumber(resolvedData.mapId or resolvedData.id or 0) or 0,
        level = tonumber(resolvedData.level or resolvedData.keyLevel or 0)
            or 0,
        timeLimit = tonumber(
            resolvedData.timeLimit or resolvedData.baseTimer or 0) or 0,
        countdown = tonumber(resolvedData.countdown or resolvedData.timeout
            or 10) or 10,
        healthPct = tonumber(resolvedData.healthPct or 0) or 0,
        damagePct = tonumber(resolvedData.damagePct or 0) or 0,
        iconPath = resolvedData.iconPath,
        artKey = resolvedData.artKey,
        readyCount = tonumber(resolvedData.readyCount or 0) or 0,
        totalCount = tonumber(resolvedData.totalCount or 0) or 0,
        allReady = Truthy(resolvedData.allReady),
        affixes = DecodePayloadTable(resolvedData.affixes or data.affixes)
            or {},
    }

    local displayedKeystone = ResolveDisplayedKeystone(self.keystoneData.level)
    if displayedKeystone then
        self.keystoneData.itemId = displayedKeystone.itemId
        self.keystoneData.itemLink = displayedKeystone.itemLink
        self.keystoneData.itemTexture = displayedKeystone.itemTexture
        self.keystoneData.bag = displayedKeystone.bag
        self.keystoneData.slot = displayedKeystone.slot
    end

    self.keystoneData.itemTexture, self.keystoneData.itemLink =
        ResolveKeystoneItemTexture(self.keystoneData.itemId,
            self.keystoneData.itemLink, self.keystoneData.bag,
            self.keystoneData.slot)
end

function KUI:SetPartyMembers(members)
    self.partyMembers = {}
    members = DecodePayloadTable(members) or {}

    for _, member in ipairs(members) do
        self.partyMembers[#self.partyMembers + 1] = {
            guid = member.guid or member.playerGuid,
            name = member.name or member.playerName or "Player",
            role = member.role or "DPS",
            ready = Truthy(member.ready),
            declined = Truthy(member.declined),
            leader = Truthy(member.leader),
        }
    end
end

function KUI:Show(data, isLeader)
    self:CreateActivationFrame()
    if type(data) == "table" then
        self:SetKeystoneData(data)
        if data.partyMembers then
            self:SetPartyMembers(data.partyMembers)
        end
    end
    if isLeader ~= nil then
        self.isLeader = Truthy(isLeader)
    end

    local shouldAnimate = not self.frame:IsShown() or self.currentState == self.STATE.IDLE
    self.currentState = self.STATE.READY_CHECK
    self.frame:Show()
    self:RefreshView()
    if shouldAnimate then
        self:PlayInsertAnimation()
    end
end

function KUI:Hide()
    self:StopCountdown()
    self:StopPulseAnimation()
    self.insertAnimating = false
    self.currentState = self.STATE.IDLE
    if self.frame then
        self:ResetVisualState()
        self.frame:Hide()
    end
end

function KUI:SendReadyDecision(accepted)
    if type(namespace.RespondToKeystone) == "function" then
        namespace.RespondToKeystone(accepted)
        return true
    end
    return SendProtocol(MPLUS, CMSG_KEYSTONE_RESPONSE, { accepted = accepted })
end

function KUI:SendCancelRequest()
    if type(namespace.CancelPendingKeystoneActivation) == "function" then
        namespace.CancelPendingKeystoneActivation()
        return true
    end
    return SendProtocol(MPLUS, CMSG_KEYSTONE_CANCEL, { cancel = true })
end

function KUI:SendReady()
    if not self:HasInsertedKeystone() then
        return
    end

    local alreadyReady = self:IsLocalPlayerReady()

    if not self:SendReadyDecision(true) then
        Print("DCAddonProtocol is not available.")
        return
    end

    if alreadyReady then
        return
    end

    local playerName = UnitName and UnitName("player") or nil
    for _, member in ipairs(self.partyMembers or {}) do
        if member.name == playerName then
            member.ready = true
            member.declined = false
            break
        end
    end

    if self.keystoneData then
        local totalCount = tonumber(self.keystoneData.totalCount) or 0
        local readyCount = (tonumber(self.keystoneData.readyCount) or 0) + 1
        if totalCount > 0 then
            readyCount = math.min(readyCount, totalCount)
        end
        self.keystoneData.readyCount = readyCount
    end

    self:RefreshView()
end

function KUI:CancelActivation()
    if self.currentState == self.STATE.COUNTDOWN then
        self:Hide()
        return
    end

    if self.isLeader then
        self:SendCancelRequest()
    else
        self:SendReadyDecision(false)
    end

    self:Hide()
end

function KUI:StartCountdown(seconds)
    self:CreateActivationFrame()
    self.frame:Show()
    self.currentState = self.STATE.COUNTDOWN
    self.insertAnimating = false
    self.countdownValue = tonumber(seconds) or 10

    self:SetCountdownOverlayVisible(true)
    self:SetCountdownOverlayBaseState()
    self.frame.CountdownText:Show()
    self:RefreshButtons()
    self:RefreshStatusText()

    self.countdownDriver = self.countdownDriver or CreateFrame("Frame")
    local countdownEnd = GetTime() + self.countdownValue
    local lastShown = self.countdownValue + 1

    self.countdownDriver:SetScript("OnUpdate", function(driver)
        local remaining = math.max(0, math.ceil(countdownEnd - GetTime()))
        if remaining ~= lastShown then
            lastShown = remaining
            KUI.countdownValue = remaining
            if remaining > 0 then
                local color = remaining <= 3 and "ffff55" or "ffd54a"
                KUI.frame.CountdownText:SetText("|cff" .. color .. remaining .. "|r")
                KUI:PlayCountdownTickAnimation(false)
                KUI:RefreshStatusText()
            else
                driver:SetScript("OnUpdate", nil)
                KUI.frame.CountdownText:SetText("|cff7dff7dGO!|r")
                KUI:PlayCountdownTickAnimation(true)
                KUI.frame.Instructions:SetText("The challenge has begun")
                KUI.frame.ReadyProgress:SetText("")
                C_Timer.After(1.2, function()
                    KUI:Hide()
                end)
            end
        end
    end)

    self.frame.CountdownText:SetText("|cffffd54a" .. self.countdownValue .. "|r")
    self:PlayCountdownTickAnimation(false)
end

function KUI:OnKeystoneReadyCheck(data)
    if type(data) ~= "table" then
        return
    end

    self:StopCountdown()
    self:SetKeystoneData(data)
    self:SetPartyMembers(data.partyMembers)
    self.isLeader = Truthy(data.isLeader)
    self:Show()
end

function KUI:OnPlayerReadyUpdate(data)
    if type(data) ~= "table" then
        return
    end

    local updated = false
    for _, member in ipairs(self.partyMembers or {}) do
        if (data.playerGuid and member.guid == data.playerGuid) or
            (data.playerName and member.name == data.playerName) then
            member.ready = Truthy(data.ready) or tonumber(data.state) == 1
            member.declined = Truthy(data.declined) or tonumber(data.state) == 2
            updated = true
            break
        end
    end

    if not updated and data.playerName then
        self.partyMembers[#self.partyMembers + 1] = {
            guid = data.playerGuid,
            name = data.playerName,
            role = data.role or "DPS",
            ready = Truthy(data.ready) or tonumber(data.state) == 1,
            declined = Truthy(data.declined) or tonumber(data.state) == 2,
        }
    end

    if self.keystoneData then
        if data.readyCount ~= nil then
            self.keystoneData.readyCount = tonumber(data.readyCount) or self.keystoneData.readyCount
        end
        if data.totalCount ~= nil then
            self.keystoneData.totalCount = tonumber(data.totalCount) or self.keystoneData.totalCount
        end
        if data.allReady ~= nil then
            self.keystoneData.allReady = Truthy(data.allReady)
        end
    end

    if self.keystoneData and Truthy(self.keystoneData.allReady) then
        self:Hide()
        return
    end

    self:RefreshView()
end

function KUI:OnCountdownStart(data)
    self:StartCountdown(data and data.seconds or (self.keystoneData and self.keystoneData.countdown) or 10)
end

function KUI:OnActivationCancelled(data)
    Print((type(data) == "table" and data.reason) or "Keystone activation cancelled")
    self:Hide()
end

Print("Keystone Activation Retail UI module loaded")
