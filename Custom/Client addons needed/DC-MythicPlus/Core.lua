local addonName = ... or "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

-- ============================================================================
-- 3.3.5a Compatibility Polyfills
-- ============================================================================

-- Polyfill SetColorTexture (added in WoD+)
local TextureMeta = getmetatable(CreateFrame("Frame"):CreateTexture()).__index
if not TextureMeta.SetColorTexture then
    -- Use a solid white texture and apply vertex color
    TextureMeta.SetColorTexture = function(self, r, g, b, a)
        self:SetTexture("Interface\\Buttons\\WHITE8x8")
        self:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
end

-- Polyfill C_Timer (added in WoD+)
if not C_Timer then
    C_Timer = {}
    local timerFrame = CreateFrame("Frame")
    local timers = {}
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local i = 1
        while i <= #timers do
            local t = timers[i]
            if now >= t.expires then
                local callback = t.callback
                table.remove(timers, i)
                callback()
            else
                i = i + 1
            end
        end
        if #timers == 0 then
            self:Hide()
        end
    end)
    timerFrame:Hide()
    
    function C_Timer.After(delay, callback)
        table.insert(timers, {
            expires = GetTime() + delay,
            callback = callback
        })
        timerFrame:Show()
    end
end

-- Polyfill SetShown (added in MoP+)
local FrameMeta = getmetatable(CreateFrame("Frame")).__index
if not FrameMeta.SetShown then
    FrameMeta.SetShown = function(self, shown)
        if shown then
            self:Show()
        else
            self:Hide()
        end
    end
end

-- DCAddonProtocol integration
local DC = rawget(_G, "DCAddonProtocol")
namespace.useDCProtocol = (DC ~= nil)
local NATIVE_MPLUS_HUD_CAPABILITY = 0x00001000
local NATIVE_MPLUS_HUD_POLL_INTERVAL = 0.10
local lastNativeHudRevision = 0
local nativeHudPollFrame

local function HasCapabilityBit(mask, capability)
    mask = tonumber(mask) or 0
    capability = tonumber(capability) or 0

    if capability <= 0 then
        return false
    end

    if bit and bit.band then
        return bit.band(mask, capability) ~= 0
    end

    return (mask % (capability * 2)) >= capability
end

local function RefreshDCProtocol()
    local protocol = rawget(_G, "DCAddonProtocol")
    if protocol then
        DC = protocol
    end
    namespace.useDCProtocol = (DC ~= nil)
    return DC
end

RefreshDCProtocol()

local function GetClientCapabilityMask()
    local protocol = RefreshDCProtocol()
    if protocol and type(protocol.GetClientCapabilities) == "function" then
        local ok, capabilities = pcall(protocol.GetClientCapabilities, protocol)
        if ok then
            return tonumber(capabilities) or 0
        end
    end

    return 0
end

local function GetProtocolCapabilitySnapshot()
    local protocol = RefreshDCProtocol()
    if not protocol or type(protocol.GetCapabilitySnapshot) ~= "function" then
        return nil
    end

    local ok, snapshot = pcall(protocol.GetCapabilitySnapshot, protocol)
    if not ok or type(snapshot) ~= "table" then
        return nil
    end

    return snapshot
end

local function IsCapabilityNegotiated(capability)
    local snapshot = GetProtocolCapabilitySnapshot()
    if not snapshot or not snapshot.connected then
        return false
    end

    return HasCapabilityBit(tonumber(snapshot.negotiatedCaps) or 0,
        capability)
end

local function HasNativeMythicPlusHudBridge()
    if type(RequestNativeMythicPlusHud) ~= "function"
        or type(GetNativeMythicPlusHudSnapshot) ~= "function" then
        return false
    end

    local capabilities = GetClientCapabilityMask()
    if capabilities > 0 then
        return HasCapabilityBit(capabilities, NATIVE_MPLUS_HUD_CAPABILITY)
    end

    return true
end

local function ShouldUseNativeMythicPlusHudBridge()
    return HasNativeMythicPlusHudBridge()
        and IsCapabilityNegotiated(NATIVE_MPLUS_HUD_CAPABILITY)
end

local AIO = rawget(_G, "AIO")
if not AIO then
    local ok, mod = pcall(function()
        return require("AIO")
    end)
    if ok then
        AIO = mod
    end
end

if AIO and type(AIO.AddAddon) == "function" then
    if AIO.AddAddon() then
        return
    end
end

local SERVER_ADDON_NAME = "DCMythicPlusHUD"
local SERVER_MESSAGE_KEY = "HUD"
local UPDATE_INTERVAL = 0.25

DCMythicPlusHUDDB = DCMythicPlusHUDDB or {}
DCMythicPlusHUDDB.position = DCMythicPlusHUDDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 }
DCMythicPlusHUDDB.locked = DCMythicPlusHUDDB.locked or false
DCMythicPlusHUDDB.hidden = DCMythicPlusHUDDB.hidden or false
DCMythicPlusHUDDB.firstLoginByChar = DCMythicPlusHUDDB.firstLoginByChar or {}
namespace._vaultLoginNoticeShown = false

-- Cache structure for static/weekly data
DCMythicPlusHUDDB.cache = DCMythicPlusHUDDB.cache or {}
DCMythicPlusHUDDB.cache.affixes = DCMythicPlusHUDDB.cache.affixes or {}
DCMythicPlusHUDDB.cache.affixesTime = DCMythicPlusHUDDB.cache.affixesTime or 0
DCMythicPlusHUDDB.cache.affixesWeek = DCMythicPlusHUDDB.cache.affixesWeek or 0
DCMythicPlusHUDDB.cache.dungeons = DCMythicPlusHUDDB.cache.dungeons or {}
DCMythicPlusHUDDB.cache.dungeonsTime = DCMythicPlusHUDDB.cache.dungeonsTime or 0

-- Cache TTL constants
local CACHE_TTL_AFFIXES = 86400    -- 24 hours (affixes change weekly)
local CACHE_TTL_DUNGEONS = 604800  -- 1 week (dungeons are seasonal)

local localMythicPlusStaticState = {
    loaded = false,
    affixesById = {},
    dungeonsByMapId = {},
    dungeonsByName = {},
    dungeonList = {},
}

local MYTHICPLUS_ICON_BASE =
    "Interface\\AddOns\\DC-MythicPlus\\Media\\Teleporter\\"
local MYTHICPLUS_DUNGEON_ICONS_BASE =
    "Interface\\AddOns\\Icons\\dungeons\\"

local function CopySimpleTable(source)
    local result = {}

    if type(source) ~= "table" then
        return result
    end

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function NormalizeDungeonLookupKey(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalized = string.lower(name)
    normalized = normalized:gsub("[^%w]+", "")
    if normalized == "" then
        return nil
    end

    return normalized
end

local function NormalizeLocalMythicPlusAffixRow(row)
    if type(row) ~= "table" then
        return nil
    end

    local affixId = tonumber(row.id or row.affixId or row.affix_id) or 0
    if affixId <= 0 then
        return nil
    end

    local descriptor = {
        id = affixId,
        spellId = tonumber(row.spellId or row.spellID or row.spell_id or 0)
            or 0,
        enabled = tonumber(row.enabled or 0) or 0,
        type = row.type,
        token = row.token,
        name = row.name,
        description = row.description,
        icon = row.icon,
    }

    if (not descriptor.icon or descriptor.icon == "")
        and descriptor.spellId > 0 and type(GetSpellTexture) == "function" then
        descriptor.icon = GetSpellTexture(descriptor.spellId)
    end

    return descriptor
end

local function NormalizeLocalMythicPlusDungeonRow(row, defaultSortOrder)
    if type(row) ~= "table" then
        return nil
    end

    local mapId = tonumber(row.mapId or row.map_id or row.id) or 0
    if mapId <= 0 then
        return nil
    end

    local shortName = row.shortName or row.short or row.short_name or ""
    local timeLimit = tonumber(
        row.timeLimit or row.baseTimer or row.timer or row.timer_seconds or 0)
        or 0

    return {
        id = mapId,
        mapId = mapId,
        name = row.name or row.dungeonName or row.dungeon_name
            or ("Map " .. tostring(mapId)),
        shortName = shortName,
        short = shortName,
        timeLimit = timeLimit,
        baseTimer = timeLimit,
        difficulty = tonumber(row.difficulty or row.difficulty_rating or 0)
            or 0,
        minLevel = tonumber(row.minLevel or row.min_level or 0) or 0,
        enabled = tonumber(row.enabled or 0) or 0,
        sortOrder = tonumber(row.sortOrder or defaultSortOrder or 0) or 0,
        artKey = row.artKey,
    }
end

local function LoadLocalMythicPlusStaticData()
    if localMythicPlusStaticState.loaded then
        return
    end

    wipe(localMythicPlusStaticState.affixesById)
    wipe(localMythicPlusStaticState.dungeonsByMapId)
    wipe(localMythicPlusStaticState.dungeonsByName)
    wipe(localMythicPlusStaticState.dungeonList)

    if type(GetDCMythicPlusAffixes) == "function" then
        local ok, rows = pcall(GetDCMythicPlusAffixes)
        if ok and type(rows) == "table" then
            for _, row in ipairs(rows) do
                local descriptor = NormalizeLocalMythicPlusAffixRow(row)
                if descriptor then
                    localMythicPlusStaticState.affixesById[descriptor.id] =
                        descriptor
                end
            end
        end
    end

    if type(GetDCMythicPlusDungeons) == "function" then
        local ok, rows = pcall(GetDCMythicPlusDungeons)
        if ok and type(rows) == "table" then
            for index, row in ipairs(rows) do
                local descriptor = NormalizeLocalMythicPlusDungeonRow(row,
                    index)
                if descriptor then
                    localMythicPlusStaticState.dungeonsByMapId[
                        descriptor.mapId] = descriptor

                    local key = NormalizeDungeonLookupKey(descriptor.name)
                    if key then
                        localMythicPlusStaticState.dungeonsByName[key] =
                            descriptor
                    end

                    table.insert(localMythicPlusStaticState.dungeonList,
                        descriptor)
                end
            end

            table.sort(localMythicPlusStaticState.dungeonList,
                function(left, right)
                    local leftOrder = tonumber(left.sortOrder) or 0
                    local rightOrder = tonumber(right.sortOrder) or 0
                    if leftOrder ~= rightOrder then
                        return leftOrder < rightOrder
                    end

                    return (tonumber(left.mapId) or 0)
                        < (tonumber(right.mapId) or 0)
                end)
        end
    end

    localMythicPlusStaticState.loaded = true
end

local function GetLocalMythicPlusAffixDescriptor(affixId)
    LoadLocalMythicPlusStaticData()

    local descriptor = localMythicPlusStaticState.affixesById[
        tonumber(affixId) or 0]
    if not descriptor then
        return nil
    end

    return CopySimpleTable(descriptor)
end

local function GetLocalMythicPlusDungeonDescriptor(mapId, name)
    LoadLocalMythicPlusStaticData()

    local numericMapId = tonumber(mapId) or 0
    if numericMapId > 0 then
        local descriptor = localMythicPlusStaticState.dungeonsByMapId[
            numericMapId]
        if descriptor then
            return CopySimpleTable(descriptor)
        end
    end

    local key = NormalizeDungeonLookupKey(name)
    if not key then
        return nil
    end

    local descriptor = localMythicPlusStaticState.dungeonsByName[key]
    if not descriptor then
        return nil
    end

    return CopySimpleTable(descriptor)
end

local function GetLocalMythicPlusDungeonList()
    LoadLocalMythicPlusStaticData()

    local result = {}
    for index, descriptor in ipairs(localMythicPlusStaticState.dungeonList) do
        result[index] = CopySimpleTable(descriptor)
    end

    return result
end

local function NormalizeMythicPlusAffixPayload(affix)
    if type(affix) == "table" then
        local affixId = tonumber(affix.id or affix.affixId or affix.affix_id)
            or 0
        local descriptor = affixId > 0
            and GetLocalMythicPlusAffixDescriptor(affixId)
            or nil
        local normalized = descriptor or {}

        normalized.id = affixId > 0 and affixId or normalized.id
        normalized.spellId = tonumber(
            affix.spellId or affix.spellID or affix.spell_id
            or normalized.spellId or 0) or 0
        normalized.enabled = tonumber(affix.enabled or normalized.enabled or 0)
            or 0
        normalized.type = affix.type or normalized.type
        normalized.token = affix.token or normalized.token
        normalized.name = normalized.name or affix.name or affix.affixName
            or affix.spellName
        normalized.description = normalized.description
            or affix.description or affix.desc or affix.affixDesc
        normalized.icon = affix.icon or normalized.icon

        if (not normalized.icon or normalized.icon == "")
            and normalized.spellId > 0
            and type(GetSpellTexture) == "function" then
            normalized.icon = GetSpellTexture(normalized.spellId)
        end

        return normalized
    end

    if type(affix) == "number" then
        local descriptor = GetLocalMythicPlusAffixDescriptor(affix)
        if descriptor then
            return descriptor
        end
    end

    return affix
end

local function ApplyMythicPlusDungeonDescriptor(data)
    if type(data) ~= "table" then
        return data
    end

    local descriptor = GetLocalMythicPlusDungeonDescriptor(
        data.mapId or data.map_id or data.id,
        data.name or data.dungeonName or data.dungeon or data.dungeon_name)
    if not descriptor then
        return data
    end

    local merged = CopySimpleTable(descriptor)
    for key, value in pairs(data) do
        if value ~= nil and value ~= "" then
            merged[key] = value
        end
    end

    merged.id = tonumber(merged.id or descriptor.id or merged.mapId or 0) or 0
    merged.mapId = tonumber(merged.mapId or descriptor.mapId or 0) or 0
    merged.name = descriptor.name
    merged.dungeonName = descriptor.name
    merged.dungeon = descriptor.name
    merged.shortName = descriptor.shortName or merged.shortName or merged.short
    merged.short = descriptor.shortName or merged.short or merged.shortName
    merged.timeLimit = tonumber(
        merged.timeLimit or merged.baseTimer or descriptor.timeLimit or 0)
        or 0
    merged.baseTimer = tonumber(
        merged.baseTimer or merged.timeLimit or descriptor.baseTimer or 0)
        or 0
    merged.difficulty = tonumber(
        merged.difficulty or descriptor.difficulty or 0) or 0
    merged.minLevel = tonumber(
        merged.minLevel or descriptor.minLevel or 0) or 0
    merged.enabled = tonumber(merged.enabled or descriptor.enabled or 0) or 0
    merged.sortOrder = tonumber(
        merged.sortOrder or descriptor.sortOrder or 0) or 0
    merged.artKey = merged.artKey or descriptor.artKey

    return merged
end

local function ResolveMythicPlusAffixInfo(affix)
    if type(affix) == "table" then
        local affixId = tonumber(affix.id or affix.affixId or affix.affix_id)
            or 0
        local descriptor = affixId > 0
            and GetLocalMythicPlusAffixDescriptor(affixId)
            or nil
        local spellId = tonumber(
            affix.spellId or affix.spellID or affix.spell_id
            or (descriptor and descriptor.spellId) or 0)
            or 0
        local name = (descriptor and descriptor.name) or affix.name
            or affix.affixName or affix.spellName
        local description = (descriptor and descriptor.description)
            or affix.description or affix.desc or affix.affixDesc
        local icon = affix.icon or (descriptor and descriptor.icon)

        if (not icon or icon == "") and spellId > 0
            and type(GetSpellTexture) == "function" then
            icon = GetSpellTexture(spellId)
        end

        return affixId > 0 and affixId or spellId, name, description, icon
    end

    if type(affix) == "number" then
        local descriptor = GetLocalMythicPlusAffixDescriptor(affix)
        if descriptor then
            return descriptor.id, descriptor.name, descriptor.description,
                descriptor.icon
        end

        local icon = type(GetSpellTexture) == "function"
            and GetSpellTexture(affix) or nil
        local name = type(GetSpellInfo) == "function"
            and GetSpellInfo(affix) or nil
        return affix, name, nil, icon
    end

    if type(affix) == "string" then
        local numericAffix = tonumber(affix)
        if numericAffix then
            return ResolveMythicPlusAffixInfo(numericAffix)
        end

        return nil, affix, nil, nil
    end

    return nil, nil, nil, nil
end

local function AddUniqueMythicPlusCandidate(candidates, seen, value)
    if type(value) ~= "string" or value == "" or seen[value] then
        return
    end

    seen[value] = true
    candidates[#candidates + 1] = value
end

local function BuildDungeonArtCandidatesForArtKey(artKey)
    if type(artKey) ~= "string" or artKey == "" then
        return nil
    end

    if artKey == "AhnKahet" then
        return {
            MYTHICPLUS_ICON_BASE .. "AhnKahet.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-ahnkalet.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-ahnkalet.png",
            MYTHICPLUS_ICON_BASE .. "AzjolNerub.blp",
        }
    end

    if artKey == "GundrakDungeon" then
        return {
            MYTHICPLUS_ICON_BASE .. "GundrakDungeon.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-gundrak.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-gundrak.png",
        }
    end

    if artKey == "TheNexus" then
        return {
            MYTHICPLUS_ICON_BASE .. "TheNexus.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-thenexus.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-thenexus.png",
            MYTHICPLUS_ICON_BASE .. "EyeOfEternity.blp",
        }
    end

    return { MYTHICPLUS_ICON_BASE .. artKey .. ".blp" }
end

local function BuildDungeonArtCandidatesForName(name)
    if type(name) ~= "string" then
        return nil
    end

    local raw = name:gsub("^%s+", ""):gsub("%s+$", "")
    local lower = string.lower(raw)

    if lower == "ahn'kahet: the old kingdom"
        or lower == "ahn'kahet the old kingdom"
        or lower == "ahn'kahet" then
        return {
            MYTHICPLUS_ICON_BASE .. "AhnKahet.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-ahnkalet.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-ahnkalet.png",
            MYTHICPLUS_ICON_BASE .. "AzjolNerub.blp",
        }
    end

    if lower == "gundrak" then
        return {
            MYTHICPLUS_ICON_BASE .. "GundrakDungeon.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-gundrak.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-gundrak.png",
        }
    end

    if lower == "the nexus" or lower == "nexus" then
        return {
            MYTHICPLUS_ICON_BASE .. "TheNexus.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-thenexus.blp",
            MYTHICPLUS_DUNGEON_ICONS_BASE .. "ui-lfg-background-thenexus.png",
            MYTHICPLUS_ICON_BASE .. "EyeOfEternity.blp",
        }
    end

    return nil
end

local function NormalizeDungeonNameToArtKey(name)
    if type(name) ~= "string" then
        return nil
    end

    local raw = name:gsub("^%s+", ""):gsub("%s+$", "")
    local lower = string.lower(raw)

    if lower == "ahn'kahet: the old kingdom"
        or lower == "ahn'kahet the old kingdom" then
        return "AhnKahet"
    end
    if lower == "gundrak" then
        return "GundrakDungeon"
    end
    if lower == "the nexus" or lower == "nexus" then
        return "TheNexus"
    end
    if lower == "the oculus" or lower == "oculus" then
        return "EyeOfEternity"
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

local function ResolveMythicPlusDungeonArtCandidates(dungeon, fallbackTexture)
    local resolved = nil

    if type(dungeon) == "table" then
        resolved = ApplyMythicPlusDungeonDescriptor(dungeon)
    elseif type(dungeon) == "number" then
        resolved = GetLocalMythicPlusDungeonDescriptor(dungeon)
    elseif type(dungeon) == "string" then
        resolved = GetLocalMythicPlusDungeonDescriptor(nil, dungeon)
            or { name = dungeon, dungeonName = dungeon }
    end

    if type(resolved) ~= "table" then
        resolved = {}
    end

    local candidates = {}
    local seen = {}

    AddUniqueMythicPlusCandidate(candidates, seen, resolved.iconPath)

    local keyed = BuildDungeonArtCandidatesForArtKey(resolved.artKey)
    if keyed then
        for _, path in ipairs(keyed) do
            AddUniqueMythicPlusCandidate(candidates, seen, path)
        end
    end

    local dungeonName = resolved.dungeonName or resolved.name or resolved.dungeon
    local named = BuildDungeonArtCandidatesForName(dungeonName)
    if named then
        for _, path in ipairs(named) do
            AddUniqueMythicPlusCandidate(candidates, seen, path)
        end
    end

    local iconKey = NormalizeDungeonNameToArtKey(dungeonName)
    if iconKey then
        AddUniqueMythicPlusCandidate(candidates, seen,
            MYTHICPLUS_ICON_BASE .. iconKey .. ".blp")
    end

    AddUniqueMythicPlusCandidate(candidates, seen, fallbackTexture)

    if #candidates == 0 then
        return nil
    end

    return candidates
end

namespace.GetMythicPlusAffixDescriptor = GetLocalMythicPlusAffixDescriptor
namespace.GetMythicPlusDungeonDescriptor = GetLocalMythicPlusDungeonDescriptor
namespace.GetMythicPlusDungeonList = GetLocalMythicPlusDungeonList
namespace.NormalizeMythicPlusAffixPayload = NormalizeMythicPlusAffixPayload
namespace.ApplyMythicPlusDungeonDescriptor = ApplyMythicPlusDungeonDescriptor
namespace.ResolveMythicPlusAffixInfo = ResolveMythicPlusAffixInfo
namespace.ResolveMythicPlusDungeonArtCandidates =
    ResolveMythicPlusDungeonArtCandidates

local activeState
local frame
local countdownText
local headerText
local timerText
local statusText
local deathText
local affixText
local playerText
local bossText
local enemyText
local reasonText
local resultFrame
local resultTitleText
local resultDungeonText
local resultDurationText
local resultBossesText
local resultDeathsText
local resultRewardsText
local resultKeystoneText
local centerCountdownFrame
local centerCountdownText
local lastCenterCountdownValue
local lastPayload
local lastResultPopupKey
local vaultToastFrame
local vaultToastTitleText
local vaultToastBodyText
local vaultToastVersion = 0
local lastRequestTime = 0
local REQUEST_COOLDOWN = 1.0
local VAULT_TOAST_DURATION = 12
local questTrackerSuppression = {
    active = false,
    watchFrameShown = nil,
    watchShowObjectives = nil,
    questWatchFrameShown = nil,
    objectiveTrackerShown = nil,
}

local function GetCharacterKey()
    local name = (type(UnitName) == "function" and UnitName("player")) or "Unknown"
    local realm = (type(GetRealmName) == "function" and GetRealmName()) or ""
    if realm ~= "" then
        return realm .. ":" .. name
    end
    return name
end

local function ClearFirstLoginSuppression()
    if namespace._suppressHudThisSession then
        namespace._suppressHudThisSession = false
    end
end

-- =====================================================================
-- LOCAL RUN TIMER (non-Mythic runs)
-- Tracks time spent in any party/raid instance, even without Mythic+.
-- =====================================================================

-- Keep disabled so the HUD only appears for active Mythic+ runs.
local ENABLE_LOCAL_RUN_HUD_FALLBACK = false

local localRun = {
    active = false,
    finished = false,
    startedAt = 0,
    finishedElapsed = 0,
    instanceKey = nil,
    instanceName = nil,
    instanceType = nil,
    difficultyID = nil,
}

local function NowSeconds()
    if type(GetTime) == "function" then
        return GetTime() or 0
    end
    if type(time) == "function" then
        return time() or 0
    end
    return 0
end

local function IsMythicDifficulty(id, label)
    id = tonumber(id) or 0
    if id == 3 or id == 16 or id == 23 then
        return true
    end

    if type(label) == "string" then
        local lowered = string.lower(label)
        if string.find(lowered, "mythic") or string.find(lowered, "epic") then
            return true
        end
    end

    return false
end

local function GetTrackableInstanceInfo()
    if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
        return nil
    end

    local inInstance = select(1, IsInInstance())
    if not inInstance then
        return nil
    end

    local name, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then
        return nil
    end

    -- Local timer is strictly for non-Mythic runs.
    if IsMythicDifficulty(difficultyID, difficultyName) then
        return nil
    end

    name = name or "Instance"
    difficultyID = tonumber(difficultyID) or 0
    local key = tostring(name) .. ":" .. tostring(instanceType) .. ":" .. tostring(difficultyID)
    return {
        key = key,
        name = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
    }
end

local function IsFlagSet(value)
    return value == true or value == 1 or value == "1"
end

local function IsRunInProgress(data)
    if type(data) ~= "table" then
        return false
    end

    if IsFlagSet(data.completed) or IsFlagSet(data.failed) then
        return false
    end

    local countdown = tonumber(data.countdown or 0) or 0
    if countdown > 0 then
        return true
    end

    if IsFlagSet(data.inProgress) then
        return true
    end

    local started = tonumber(data.started or 0) or 0
    return started > 0
end

local function IsMythicRunActive()
    return IsRunInProgress(activeState)
end

local function ShouldHideQuestObjectivesForMythicPlus()
    if not activeState or not IsRunInProgress(activeState) then
        return false
    end

    local keyLevel = tonumber(activeState.keystone or activeState.keyLevel
        or activeState.keystoneLevel or activeState.level or 0) or 0
    if keyLevel <= 0 then
        return false
    end

    if type(IsInInstance) == "function" then
        local inInstance = select(1, IsInInstance())
        if not inInstance then
            return false
        end
    end

    return true
end

local function RefreshQuestTrackerDisplay()
    if type(QuestWatch_Update) == "function" then
        pcall(QuestWatch_Update)
    end
    if type(WatchFrame_Update) == "function" then
        pcall(WatchFrame_Update)
    end
end

local function ApplyMythicQuestTrackerSuppression()
    if WatchFrame then
        WatchFrame.showObjectives = false
        WatchFrame:Hide()
    end

    if QuestWatchFrame and QuestWatchFrame ~= WatchFrame then
        QuestWatchFrame:Hide()
    end

    if ObjectiveTrackerFrame then
        ObjectiveTrackerFrame:Hide()
    end
end

local function EnsureQuestTrackerSuppressionHooks()
    namespace._questTrackerOnShowHooks = namespace._questTrackerOnShowHooks or {}
    local onShowHooks = namespace._questTrackerOnShowHooks

    if not namespace._questTrackerUpdateHooksInstalled and type(hooksecurefunc) == "function" then
        if type(WatchFrame_Update) == "function" then
            hooksecurefunc("WatchFrame_Update", function()
                if questTrackerSuppression.active then
                    ApplyMythicQuestTrackerSuppression()
                end
            end)
        end

        if type(QuestWatch_Update) == "function" then
            hooksecurefunc("QuestWatch_Update", function()
                if questTrackerSuppression.active then
                    ApplyMythicQuestTrackerSuppression()
                end
            end)
        end

        namespace._questTrackerUpdateHooksInstalled = true
    end

    local function HookFrameOnShow(frameRef, key)
        if not frameRef or onShowHooks[key] or type(frameRef.HookScript) ~= "function" then
            return
        end

        local ok = pcall(function()
            frameRef:HookScript("OnShow", function(self)
                if questTrackerSuppression.active then
                    self:Hide()
                end
            end)
        end)

        if ok then
            onShowHooks[key] = true
        end
    end

    HookFrameOnShow(WatchFrame, "WatchFrame")
    HookFrameOnShow(QuestWatchFrame, "QuestWatchFrame")
    HookFrameOnShow(ObjectiveTrackerFrame, "ObjectiveTrackerFrame")
end

local function UpdateQuestTrackerSuppression()
    EnsureQuestTrackerSuppressionHooks()

    if ShouldHideQuestObjectivesForMythicPlus() then
        if not questTrackerSuppression.active then
            questTrackerSuppression.watchFrameShown = WatchFrame and WatchFrame:IsShown() or nil
            questTrackerSuppression.watchShowObjectives = WatchFrame and (WatchFrame.showObjectives ~= false) or nil
            questTrackerSuppression.questWatchFrameShown = (QuestWatchFrame and QuestWatchFrame ~= WatchFrame and QuestWatchFrame:IsShown()) or nil
            questTrackerSuppression.objectiveTrackerShown = ObjectiveTrackerFrame and ObjectiveTrackerFrame:IsShown() or nil
            questTrackerSuppression.active = true
        end

        ApplyMythicQuestTrackerSuppression()
        return
    end

    if not questTrackerSuppression.active then
        return
    end

    if WatchFrame and questTrackerSuppression.watchShowObjectives ~= nil then
        WatchFrame.showObjectives = questTrackerSuppression.watchShowObjectives
    end

    RefreshQuestTrackerDisplay()

    if WatchFrame and questTrackerSuppression.watchFrameShown == false then
        WatchFrame:Hide()
    end

    if QuestWatchFrame and QuestWatchFrame ~= WatchFrame and questTrackerSuppression.questWatchFrameShown == false then
        QuestWatchFrame:Hide()
    end

    if ObjectiveTrackerFrame and questTrackerSuppression.objectiveTrackerShown == false then
        ObjectiveTrackerFrame:Hide()
    end

    questTrackerSuppression.active = false
    questTrackerSuppression.watchFrameShown = nil
    questTrackerSuppression.watchShowObjectives = nil
    questTrackerSuppression.questWatchFrameShown = nil
    questTrackerSuppression.objectiveTrackerShown = nil
end

local function ResetLocalRunTimer(keepActiveIfInInstance)
    local now = NowSeconds()
    local info = GetTrackableInstanceInfo()
    localRun.startedAt = now
    localRun.finishedElapsed = 0
    localRun.finished = false
    localRun.active = keepActiveIfInInstance and (info ~= nil) or false
    localRun.instanceKey = info and info.key or nil
    localRun.instanceName = info and info.name or nil
    localRun.instanceType = info and info.instanceType or nil
    localRun.difficultyID = info and info.difficultyID or nil
end

local function StartLocalRunTimer(info)
    local now = NowSeconds()
    localRun.active = true
    localRun.finished = false
    localRun.startedAt = now
    localRun.finishedElapsed = 0
    localRun.instanceKey = info and info.key or nil
    localRun.instanceName = info and info.name or "Instance"
    localRun.instanceType = info and info.instanceType or nil
    localRun.difficultyID = info and info.difficultyID or nil
end

local function FinishLocalRunTimer()
    if not localRun.active then
        return
    end
    local now = NowSeconds()
    localRun.finishedElapsed = math.max(0, (now or 0) - (localRun.startedAt or 0))
    localRun.active = false
    localRun.finished = true
end

local function UpdateLocalRunTrackingFromInstance()
    -- If Mythic+ is active, don't run the local timer to avoid double timers.
    if IsMythicRunActive() then
        if localRun.active then
            FinishLocalRunTimer()
        end
        return
    end

    local info = GetTrackableInstanceInfo()
    if info then
        if (not localRun.active and not localRun.finished) or (localRun.instanceKey and localRun.instanceKey ~= info.key) then
            StartLocalRunTimer(info)
        elseif localRun.active then
            -- Keep info fresh
            localRun.instanceKey = info.key
            localRun.instanceName = info.name
            localRun.instanceType = info.instanceType
            localRun.difficultyID = info.difficultyID
        end
    else
        -- Left instance
        if localRun.active then
            FinishLocalRunTimer()
        end
    end
end

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffMythic+ HUD:|r " .. (msg or ""))
    end
end

local function FormatUnixTimestampLocal(ts)
    ts = tonumber(ts or 0) or 0
    if ts <= 0 then
        return "Unknown"
    end
    return date("%Y-%m-%d %H:%M", ts)
end

local function EnsureVaultToastFrame()
    if vaultToastFrame then
        return vaultToastFrame
    end

    vaultToastFrame = CreateFrame("Frame", "DCMythicPlusVaultToastFrame", UIParent)
    vaultToastFrame:SetSize(520, 112)
    vaultToastFrame:SetPoint("TOP", UIParent, "TOP", 0, -155)
    vaultToastFrame:SetFrameStrata("DIALOG")
    vaultToastFrame:EnableMouse(false)

    if vaultToastFrame.SetBackdrop then
        vaultToastFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        vaultToastFrame:SetBackdropColor(0.04, 0.06, 0.12, 0.96)
        vaultToastFrame:SetBackdropBorderColor(0.28, 0.48, 0.90, 0.95)
    end

    local titleBar = vaultToastFrame:CreateTexture(nil, "ARTWORK")
    titleBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleBar:SetVertexColor(0.13, 0.20, 0.34, 0.96)
    titleBar:SetPoint("TOPLEFT", vaultToastFrame, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", vaultToastFrame, "TOPRIGHT", -4, -4)
    titleBar:SetHeight(24)

    local icon = vaultToastFrame:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_15")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", vaultToastFrame, "TOPLEFT", 10, -8)

    vaultToastTitleText = vaultToastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    vaultToastTitleText:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    vaultToastTitleText:SetJustifyH("LEFT")
    vaultToastTitleText:SetTextColor(1.00, 0.87, 0.35, 1)

    vaultToastBodyText = vaultToastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    vaultToastBodyText:SetPoint("TOPLEFT", vaultToastFrame, "TOPLEFT", 12, -34)
    vaultToastBodyText:SetWidth(496)
    vaultToastBodyText:SetJustifyH("LEFT")
    vaultToastBodyText:SetJustifyV("TOP")
    vaultToastBodyText:SetTextColor(0.88, 0.93, 1.00, 1)

    vaultToastFrame:Hide()
    return vaultToastFrame
end

local function ShowVaultToast(title, body)
    local f = EnsureVaultToastFrame()
    if vaultToastTitleText then
        vaultToastTitleText:SetText(title or "Great Vault")
    end
    if vaultToastBodyText then
        vaultToastBodyText:SetText(body or "")
    end

    f:Show()
    vaultToastVersion = (vaultToastVersion or 0) + 1
    local thisToastVersion = vaultToastVersion

    C_Timer.After(VAULT_TOAST_DURATION, function()
        if vaultToastVersion ~= thisToastVersion then
            return
        end
        if vaultToastFrame then
            vaultToastFrame:Hide()
        end
    end)
end

-- Trace is intentionally runtime-only: always start disabled on load.
DCMythicPlusHUDDB.debugTrace = false

local function Trace(msg)
    if not DCMythicPlusHUDDB.debugTrace then
        return
    end
    Print("|cffffaa00[trace]|r " .. tostring(msg or ""))
end

local TRACE_TICK_INTERVAL_SECONDS = 10
local lastTimerTickTraceAt = 0

local function ShouldTraceTimerPayload(reason)
    if not DCMythicPlusHUDDB.debugTrace then
        return false
    end

    if reason ~= "tick" then
        return true
    end

    local now = (type(GetTime) == "function" and tonumber(GetTime())) or 0
    if now <= 0 then
        return false
    end

    if (now - lastTimerTickTraceAt) >= TRACE_TICK_INTERVAL_SECONDS then
        lastTimerTickTraceAt = now
        return true
    end

    return false
end

local lastVisibilityTraceKey
local function TraceVisibility(reason, shown)
    if not DCMythicPlusHUDDB.debugTrace then
        return
    end

    local key = tostring(reason) .. "|" .. (shown and "1" or "0")
    if key == lastVisibilityTraceKey then
        return
    end
    lastVisibilityTraceKey = key

    local runActive = activeState and IsRunInProgress(activeState) or false
    local countdown = activeState and (tonumber(activeState.countdown or 0) or 0) or 0
    Trace(string.format(
        "visibility=%s reason=%s run=%s countdown=%d suppress=%s hidden=%s",
        shown and "show" or "hide",
        tostring(reason),
        tostring(runActive),
        countdown,
        tostring(namespace._suppressHudThisSession == true),
        tostring(DCMythicPlusHUDDB.hidden == true)
    ))
end

local function Trim(str)
    return (str and str:match("^%s*(.-)%s*$")) or str
end

local function TruncateForHudTitle(text, maxChars)
    text = tostring(text or "")
    maxChars = tonumber(maxChars) or 30
    if maxChars < 4 then
        maxChars = 4
    end
    if string.len(text) <= maxChars then
        return text
    end
    return string.sub(text, 1, maxChars - 3) .. "..."
end

-- 3.3.5a safety: wipe/CopyTable may not exist in some client builds
if type(wipe) ~= "function" then
    function wipe(t)
        if type(t) ~= "table" then
            return
        end
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

local function CopyTableShallow(src)
    if type(src) ~= "table" then
        return {}
    end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

local function FormatSeconds(seconds)
    if not seconds or seconds <= 0 then
        return "00:00"
    end
    local s = math.floor(seconds)
    local minutes = math.floor(s / 60)
    local remain = s % 60
    return string.format("%02d:%02d", minutes, remain)
end

local function IsOnGMIsland()
    -- Prefer numeric IDs (stable), fallback to zone text.
    local worldMapShown = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
    if type(SetMapToCurrentZone) == "function" and not worldMapShown then
        pcall(SetMapToCurrentZone)
    end
    if type(GetCurrentMapAreaID) == "function" then
        local ok, areaId = pcall(GetCurrentMapAreaID)
        areaId = ok and tonumber(areaId) or nil
        -- WotLK: GM Island area id is typically 876.
        if areaId == 876 then
            return true
        end
    end
    local zone = (GetZoneText and GetZoneText()) or ""
    if type(zone) == "string" and string.find(string.lower(zone), "gm island") then
        return true
    end
    return false
end

local function ParseTimeSeconds(input)
    if not input or input == "" then
        return nil
    end
    input = Trim(tostring(input))
    local mm, ss = input:match("^(%d+)%s*:%s*(%d+)$")
    if mm and ss then
        mm = tonumber(mm)
        ss = tonumber(ss)
        if mm and ss then
            return (mm * 60) + ss
        end
    end
    local n = tonumber(input)
    if n then
        return math.floor(n)
    end
    return nil
end

local function GetCharKey()
    local name = UnitName("player") or "?"
    local realm = (type(GetRealmName) == "function" and GetRealmName()) or ""
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function EnsurePersonalDB()
    DCMythicPlusHUDDB.personal = DCMythicPlusHUDDB.personal or {}
    local charKey = GetCharKey()
    DCMythicPlusHUDDB.personal[charKey] = DCMythicPlusHUDDB.personal[charKey] or {}
    local db = DCMythicPlusHUDDB.personal[charKey]
    db.pb = db.pb or {}
    db.goals = db.goals or {}
    return db
end

local function GetMapIdFromState(data)
    return data and (data.map or data.mapId or data.dungeonId)
end

local function GetKeystoneFromState(data)
    return data and (data.keystone or data.keyLevel or data.keystoneLevel or data.level)
end

local function GetRunKey(mapId, keystone)
    if not mapId or not keystone then
        return nil
    end
    return tostring(mapId) .. ":" .. tostring(keystone)
end

local function GetCurrentRunKey()
    local mapId = GetMapIdFromState(activeState) or GetMapIdFromState(lastPayload)
    local keystone = GetKeystoneFromState(activeState) or GetKeystoneFromState(lastPayload)
    return GetRunKey(mapId, keystone), mapId, keystone
end

-- Override the minimap instance difficulty badge text with M0 or M+key.
local function GetActiveMythicKeyForMinimapBadge()
    if not IsRunInProgress(activeState) then
        return nil
    end

    local keyLevel = tonumber(GetKeystoneFromState(activeState) or 0) or 0
    if keyLevel <= 0 then
        return nil
    end

    return keyLevel
end

local function GetMythicMinimapBadgeDisplay()
    if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
        return nil
    end

    local inInstance = select(1, IsInInstance())
    if not inInstance then
        return nil
    end

    local _, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then
        return nil
    end

    local keyLevel = GetActiveMythicKeyForMinimapBadge()
    if keyLevel then
        return "M+" .. tostring(keyLevel)
    end

    if IsMythicDifficulty(difficultyID, difficultyName) then
        return "M0"
    end

    return nil
end

local function RefreshBlizzardMinimapInstanceBadge()
    local badge = _G.MiniMapInstanceDifficulty
    local onEvent = _G.MiniMapInstanceDifficulty_OnEvent
    if badge and type(onEvent) == "function" then
        pcall(onEvent, badge, "PLAYER_DIFFICULTY_CHANGED")
    end
end

local function UpdateMinimapMythicKeyBadge()
    local badge = _G.MiniMapInstanceDifficulty
    local text = _G.MiniMapInstanceDifficultyText
    if not badge or not text or type(text.SetText) ~= "function" then
        return
    end

    local display = GetMythicMinimapBadgeDisplay()
    if display then
        if text:GetText() ~= display then
            text:SetText(display)
        end
        badge:Show()
        namespace._minimapMythicBadgeOverride = true
        return
    end

    if namespace._minimapMythicBadgeOverride then
        namespace._minimapMythicBadgeOverride = false
        RefreshBlizzardMinimapInstanceBadge()
    end
end

local function EnsureMinimapMythicKeyBadgeHook()
    if namespace._minimapMythicBadgeHooked then
        return
    end

    if type(hooksecurefunc) ~= "function" then
        return
    end

    if type(_G.MiniMapInstanceDifficulty_OnEvent) ~= "function" then
        return
    end

    hooksecurefunc("MiniMapInstanceDifficulty_OnEvent", function()
        UpdateMinimapMythicKeyBadge()
    end)
    namespace._minimapMythicBadgeHooked = true
end

-- =====================================================================
-- RUN TRACKING: per-player deaths + death locations, PB + goals
-- =====================================================================

local runTracker = {
    active = false,
    endLogged = false,
    runKey = nil,
    mapId = nil,
    keystone = nil,
    startedAt = 0,
    deathSeq = 0,
    deathsByGuid = {},
    deathsByName = {},
    deathLocations = {},
    lastRun = nil,
}

local groupGuidToName = {}

local function UpdateGroupRosterCache()
    wipe(groupGuidToName)

    local function addUnit(unit)
        if not unit or not UnitExists(unit) then
            return
        end
        local guid = UnitGUID(unit)
        local name = UnitName(unit)
        if guid and name then
            groupGuidToName[guid] = name
        end
    end

    addUnit("player")
    if UnitInRaid and UnitInRaid("player") then
        for i = 1, 40 do
            addUnit("raid" .. i)
        end
    else
        for i = 1, 4 do
            addUnit("party" .. i)
        end
    end
end

local function FindUnitIdByGUID(guid)
    if not guid then
        return nil
    end
    local function check(unit)
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
        return nil
    end
    local unit = check("player")
    if unit then
        return unit
    end
    if UnitInRaid and UnitInRaid("player") then
        for i = 1, 40 do
            unit = check("raid" .. i)
            if unit then
                return unit
            end
        end
    else
        for i = 1, 4 do
            unit = check("party" .. i)
            if unit then
                return unit
            end
        end
    end
    return nil
end

local function ResetRunTracking(runKey, mapId, keystone)
    runTracker.active = true
    runTracker.endLogged = false
    lastResultPopupKey = nil
    runTracker.runKey = runKey
    runTracker.mapId = mapId
    runTracker.keystone = keystone
    runTracker.startedAt = time()
    runTracker.deathSeq = 0
    wipe(runTracker.deathsByGuid)
    wipe(runTracker.deathsByName)
    wipe(runTracker.deathLocations)
    runTracker._lastHit = {}
    if namespace and type(namespace.ScheduleDeathPinUpdate) == "function" then
        namespace.ScheduleDeathPinUpdate()
    end
end

local function StopRunTracking(success, elapsedSeconds)
    runTracker.active = false
    runTracker.endLogged = true
    runTracker.lastRun = {
        runKey = runTracker.runKey,
        mapId = runTracker.mapId,
        keystone = runTracker.keystone,
        success = success and true or false,
        elapsed = elapsedSeconds,
        endedAt = time(),
        deathsByName = CopyTableShallow(runTracker.deathsByName),
        deathLocations = CopyTableShallow(runTracker.deathLocations),
    }
    if namespace and type(namespace.ScheduleDeathPinUpdate) == "function" then
        namespace.ScheduleDeathPinUpdate()
    end
end

local function AddPersonalBestIfImproved(mapId, keystone, elapsedSeconds)
    if not mapId or not keystone or not elapsedSeconds or elapsedSeconds <= 0 then
        return false
    end
    local db = EnsurePersonalDB()
    local key = GetRunKey(mapId, keystone)
    local prev = tonumber(db.pb[key] or 0) or 0
    if prev == 0 or elapsedSeconds < prev then
        db.pb[key] = math.floor(elapsedSeconds)
        return true
    end
    return false
end

local function GetPersonalBest(mapId, keystone)
    local db = EnsurePersonalDB()
    return tonumber(db.pb[GetRunKey(mapId, keystone)] or 0) or 0
end

local function GetGoal(mapId, keystone)
    local db = EnsurePersonalDB()
    return tonumber(db.goals[GetRunKey(mapId, keystone)] or 0) or 0
end

local function SetGoal(mapId, keystone, goalSeconds)
    local db = EnsurePersonalDB()
    local key = GetRunKey(mapId, keystone)
    if not key then
        return false
    end
    if not goalSeconds or goalSeconds <= 0 then
        db.goals[key] = nil
    else
        db.goals[key] = math.floor(goalSeconds)
    end
    return true
end

local function GetTopDeathSummary(maxPlayers)
    maxPlayers = maxPlayers or 3
    local rows = {}
    for name, count in pairs(runTracker.deathsByName) do
        if count and count > 0 then
            table.insert(rows, { name = name, count = count })
        end
    end
    table.sort(rows, function(a, b)
        if a.count == b.count then
            return a.name < b.name
        end
        return a.count > b.count
    end)
    local parts = {}
    for i = 1, math.min(maxPlayers, #rows) do
        table.insert(parts, string.format("%s(%d)", rows[i].name, rows[i].count))
    end
    return table.concat(parts, " ")
end

local trackerFrame = CreateFrame("Frame")
trackerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
trackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
trackerFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
trackerFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        UpdateGroupRosterCache()
        return
    end

    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
        return
    end
    if not runTracker.active then
        return
    end

    -- COMBAT_LOG_EVENT_UNFILTERED signature differs slightly across clients,
    -- but for 3.3.5 we can rely on positional args.
    local timestamp, subevent, hideCaster,
        sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags = ...

    -- Track recent damage to attribute likely killing blow on UNIT_DIED.
    -- (UNIT_DIED itself does not include killer/spell.)
    runTracker._lastHit = runTracker._lastHit or {}
    local lastHit = runTracker._lastHit

    local function isGroupMember(guid)
        return guid and groupGuidToName[guid]
    end

    local function rememberHit(destGuid, hit)
        if not destGuid then
            return
        end
        hit.t = time()
        lastHit[destGuid] = hit
    end

    if (subevent == "SWING_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "ENVIRONMENTAL_DAMAGE") and isGroupMember(destGUID) then
        local spellName
        local amount
        local overkill
        local school

        if subevent == "SWING_DAMAGE" then
            -- ... destRaidFlags, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
            amount, overkill, school = select(10, ...)
            spellName = "Melee"
        elseif subevent == "ENVIRONMENTAL_DAMAGE" then
            -- ... destRaidFlags, environmentalType, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
            local envType
            envType, amount, overkill, school = select(10, ...)
            spellName = tostring(envType or "Environmental")
        else
            -- ... destRaidFlags, spellId, spellName, spellSchool, amount, overkill, ...
            local spellId
            spellId, spellName, school, amount, overkill = select(10, ...)
        end

        rememberHit(destGUID, {
            event = subevent,
            sourceName = sourceName,
            sourceGUID = sourceGUID,
            spellName = spellName,
            amount = tonumber(amount),
            overkill = tonumber(overkill),
            school = school,
        })
        return
    end

    if subevent ~= "UNIT_DIED" then
        return
    end

    if not isGroupMember(destGUID) then
        return
    end

    local name = destName or groupGuidToName[destGUID] or "?"
    runTracker.deathsByGuid[destGUID] = (runTracker.deathsByGuid[destGUID] or 0) + 1
    runTracker.deathsByName[name] = (runTracker.deathsByName[name] or 0) + 1
    runTracker.deathSeq = (runTracker.deathSeq or 0) + 1

    local worldMapShown = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
    local unit = FindUnitIdByGUID(destGUID)
    local x, y = 0, 0
    local mapId
    if unit and type(GetPlayerMapPosition) == "function" then
        if type(SetMapToCurrentZone) == "function" and not worldMapShown then
            pcall(SetMapToCurrentZone)
        end
        x, y = GetPlayerMapPosition(unit)
        if type(GetCurrentMapAreaID) == "function" then
            mapId = GetCurrentMapAreaID()
        end
    end

    local killer
    local hit = lastHit[destGUID]
    if hit and hit.t and (time() - hit.t) <= 5 then
        killer = hit
    end

    table.insert(runTracker.deathLocations, 1, {
        id = runTracker.deathSeq,
        runKey = runTracker.runKey,
        t = time(),
        elapsed = activeState and activeState.elapsed or nil,
        name = name,
        guid = destGUID,
        mapId = mapId,
        zone = GetZoneText and GetZoneText() or nil,
        subzone = GetSubZoneText and GetSubZoneText() or nil,
        x = x,
        y = y,
        killer = killer,
    })
    if #runTracker.deathLocations > 200 then
        table.remove(runTracker.deathLocations)
    end

    if namespace and type(namespace.ScheduleDeathPinUpdate) == "function" then
        namespace.ScheduleDeathPinUpdate()
    end
end)

-- =====================================================================
-- WorldMap death pins (simple overlay like DC-Mapupgrades)
-- =====================================================================

local function ActiveWorldMapId()
    if WorldMapFrame then
        if WorldMapFrame.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
            if ok and mapId and mapId ~= 0 then
                return mapId
            end
        end
        if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetMapID then
            local ok, mapId = pcall(WorldMapFrame.ScrollContainer.GetMapID, WorldMapFrame.ScrollContainer)
            if ok and mapId and mapId ~= 0 then
                return mapId
            end
        end
    end
    if type(GetCurrentMapAreaID) == "function" then
        local mapId = GetCurrentMapAreaID()
        if mapId and mapId ~= 0 then
            return mapId
        end
    end
    if WorldMapFrame and WorldMapFrame.mapID and WorldMapFrame.mapID ~= 0 then
        return WorldMapFrame.mapID
    end
    return nil
end

local function WorldMapParent()
    return WorldMapButton or (WorldMapFrame and WorldMapFrame.ScrollContainer) or WorldMapFrame
end

local deathPins = {
    pins = {},
    pending = false,
    elapsed = 0,
    lastMapId = nil,
}

local function DestroyDeathPin(id)
    local pin = deathPins.pins[id]
    if not pin then
        return
    end
    pin:Hide()
    pin:SetScript("OnEnter", nil)
    pin:SetScript("OnLeave", nil)
    pin:SetParent(nil)
    deathPins.pins[id] = nil
end

local function AcquireDeathPin(id)
    local pin = deathPins.pins[id]
    if pin then
        return pin
    end
    if not WorldMapFrame then
        return nil
    end
    local parent = WorldMapParent()
    if not parent then
        return nil
    end
    pin = CreateFrame("Button", "DCMythicPlusDeathPin" .. tostring(id), parent)
    pin:SetSize(18, 18)
    pin.texture = pin:CreateTexture(nil, "OVERLAY")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8")
    pin:SetFrameStrata("HIGH")
    pin:Hide()
    pin.deathId = id

    pin:SetScript("OnEnter", function(self)
        local entry
        for _, e in ipairs(runTracker.deathLocations or {}) do
            if e and e.id == self.deathId then
                entry = e
                break
            end
        end
        if not entry then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Death #" .. tostring(entry.id or "?"), 1, 0.2, 0.2)
        GameTooltip:AddLine(string.format("Victim: %s", tostring(entry.name or "?")), 1, 1, 1)

        if entry.killer and (entry.killer.sourceName or entry.killer.spellName) then
            local killerName = entry.killer.sourceName or "Unknown"
            local spell = entry.killer.spellName or ""
            local amount = entry.killer.amount
            local extra = ""
            if amount and amount > 0 then
                extra = string.format(" (%d)", amount)
            end
            if spell ~= "" then
                GameTooltip:AddLine(string.format("Killing blow: %s - %s%s", tostring(killerName), tostring(spell), extra), 1, 0.82, 0)
            else
                GameTooltip:AddLine(string.format("Killing blow: %s%s", tostring(killerName), extra), 1, 0.82, 0)
            end
        else
            GameTooltip:AddLine("Killing blow: (unknown)", 0.8, 0.8, 0.8)
        end

        if entry.elapsed then
            GameTooltip:AddLine("Time: " .. FormatSeconds(entry.elapsed), 0.7, 0.9, 1)
        end
        local place = entry.subzone and entry.subzone ~= "" and entry.subzone or entry.zone
        if place and place ~= "" then
            GameTooltip:AddLine("Location: " .. tostring(place), 0.7, 0.7, 0.9)
        end
        if entry.x and entry.y and (entry.x > 0 or entry.y > 0) then
            GameTooltip:AddLine(string.format("Coords: %.1f, %.1f", entry.x * 100, entry.y * 100), 0.7, 0.7, 0.9)
        end

        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

    deathPins.pins[id] = pin
    return pin
end

local function UpdateDeathPinsInternal()
    if not WorldMapFrame or not (WorldMapFrame.IsShown and WorldMapFrame:IsShown()) then
        for _, pin in pairs(deathPins.pins) do
            pin:Hide()
        end
        return
    end

    -- Only show pins for the currently active run.
    if not runTracker.active or not runTracker.runKey then
        for _, pin in pairs(deathPins.pins) do
            pin:Hide()
        end
        return
    end

    local parent = WorldMapParent()
    if not parent then
        return
    end

    local activeMapId = ActiveWorldMapId()
    if activeMapId == deathPins.lastMapId and not deathPins.forceUpdate then
        return
    end
    deathPins.lastMapId = activeMapId
    deathPins.forceUpdate = nil

    local shown = {}
    local shownCount = 0
    local maxPins = 30
    for i = 1, #runTracker.deathLocations do
        local e = runTracker.deathLocations[i]
        if e and e.id and e.runKey == runTracker.runKey and e.mapId and tonumber(e.mapId) == tonumber(activeMapId) and e.x and e.y and (e.x > 0 or e.y > 0) then
            local pin = AcquireDeathPin(e.id)
            if pin then
                local px = e.x * (parent:GetWidth() or 0)
                local py = e.y * (parent:GetHeight() or 0)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", parent, "TOPLEFT", px, -py)
                pin:Show()
                shown[e.id] = true
                shownCount = shownCount + 1
                if shownCount >= maxPins then
                    break
                end
            end
        end
    end

    for id, pin in pairs(deathPins.pins) do
        if not shown[id] then
            pin:Hide()
        end
    end
end

function namespace.ScheduleDeathPinUpdate()
    deathPins.pending = true
    deathPins.elapsed = 0
    deathPins.forceUpdate = true
end

local deathPinWatcher = CreateFrame("Frame")
deathPinWatcher:RegisterEvent("WORLD_MAP_UPDATE")
deathPinWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
deathPinWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
deathPinWatcher:SetScript("OnEvent", function()
    namespace.ScheduleDeathPinUpdate()
end)

if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() namespace.ScheduleDeathPinUpdate() end)
    WorldMapFrame:HookScript("OnSizeChanged", function() namespace.ScheduleDeathPinUpdate() end)
end

local deathPinTicker = CreateFrame("Frame")
deathPinTicker:SetScript("OnUpdate", function(_, elapsed)
    if not deathPins.pending then
        return
    end
    deathPins.elapsed = deathPins.elapsed + elapsed
    if deathPins.elapsed >= 0.1 then
        deathPins.elapsed = 0
        deathPins.pending = false
        UpdateDeathPinsInternal()
    end
end)

local function SafelyGetSpellName(spellId)
    if not spellId then
        return nil
    end
    local name = GetSpellInfo and GetSpellInfo(spellId)
    if name and name ~= "" then
        return name
    end
    return tostring(spellId)
end

local function CountTableValues(t)
    if type(t) ~= "table" then
        return 0
    end
    local count = 0
    for _ in ipairs(t) do
        count = count + 1
    end
    return count
end

local function MapNameForId(id)
    if not id then
        return "Unknown"
    end
    if type(GetMapNameByID) == "function" then
        local ok, result = pcall(GetMapNameByID, id)
        if ok and result and result ~= "" then
            return result
        end
    end
    if type(GetDungeonInfo) == "function" then
        for i = 1, GetNumDungeonMapIDs and GetNumDungeonMapIDs() or 0 do
            local name, mapId = GetDungeonInfo(i)
            if mapId == id and name and name ~= "" then
                return name
            end
        end
    end
    return string.format("Map %d", id)
end

local function GetAffixDisplayName(affix)
    if type(affix) == "table" then
        local name = affix.name or affix.affixName or affix.spellName
        if name and name ~= "" then
            return name
        end
        local id = affix.spellId or affix.spellID or affix.id or affix.affixId
        return SafelyGetSpellName(id)
    end
    if type(affix) == "number" then
        return SafelyGetSpellName(affix)
    end
    if type(affix) == "string" then
        local num = tonumber(affix)
        if num then
            return SafelyGetSpellName(num)
        end
        return affix
    end
    return "Unknown"
end

local function BuildAffixLine(list)
    if type(list) ~= "table" or #list == 0 then
        return "Affixes: none"
    end
    local names = {}
    for i = 1, #list do
        names[#names + 1] = GetAffixDisplayName(list[i])
    end
    return "Affixes: " .. table.concat(names, ", ")
end

local function BuildBossLine(killed, total)
    if not total or total == 0 then
        return string.format("Bosses: %d", killed or 0)
    end
    return string.format("Bosses: %d / %d", killed or 0, total)
end

local function BuildStatus(data)
    if IsFlagSet(data.failed) then
        return "Status: |cffff5050Failed|r"
    end
    if IsFlagSet(data.completed) then
        return "Status: |cff50ff7aCompleted|r"
    end
    local countdown = tonumber(data.countdown or 0) or 0
    if countdown > 0 then
        return "Status: |cffffff78Preparing|r"
    end
    return "Status: |cff78beffIn progress|r"
end

local function GetClientNowSeconds()
    if type(GetTime) == "function" then
        local now = tonumber(GetTime()) or 0
        if now > 0 then
            return now
        end
    end
    return 0
end

local function BuildTimerLine(data)
    local elapsedSec = tonumber(data and data.elapsed or 0) or 0
    local remainingSec = tonumber(data and data.remaining or 0) or 0

    local maxSec = tonumber(data and (data.duration or data.timeLimit) or 0) or 0
    if maxSec <= 0 then
        maxSec = elapsedSec + remainingSec
    end

    -- Smooth timer rendering client-side between server snapshots.
    -- Server remains authoritative for run validation and final result.
    local countdown = tonumber(data and data.countdown or 0) or 0
    if data and IsRunInProgress(data) and countdown <= 0 then
        local anchorAt = tonumber(data._timerAnchorClient or 0) or 0
        if anchorAt > 0 then
            local baseElapsed = tonumber(data._timerElapsedBase or elapsedSec) or elapsedSec
            local baseRemaining = tonumber(data._timerRemainingBase or remainingSec) or remainingSec
            local anchoredMax = tonumber(data._timerMax or maxSec) or maxSec
            local delta = math.floor(math.max(0, GetClientNowSeconds() - anchorAt))

            if delta > 0 then
                elapsedSec = baseElapsed + delta
                if anchoredMax > 0 then
                    maxSec = anchoredMax
                    remainingSec = math.max(0, maxSec - elapsedSec)
                else
                    remainingSec = math.max(0, baseRemaining - delta)
                    maxSec = elapsedSec + remainingSec
                end
            end
        end
    end

    if maxSec < elapsedSec then
        maxSec = elapsedSec
    end

    local line = string.format(
        "Timer: |cff99ff99%s|r / |cffffd27a%s|r",
        FormatSeconds(elapsedSec),
        FormatSeconds(maxSec)
    )

    if remainingSec > 0 then
        line = line .. string.format("  |cff8fd0ff(%s left)|r", FormatSeconds(remainingSec))
    end

    return line
end

local function BuildFullTimerLine(data)
    local timerLine = BuildTimerLine(data)
    if data.bestTime and data.bestTime > 0 then
        timerLine = timerLine .. string.format(" | Best: %s", FormatSeconds(data.bestTime))
    end

    local mapId = GetMapIdFromState(data)
    local keystone = GetKeystoneFromState(data)
    if mapId and keystone then
        local pb = GetPersonalBest(mapId, keystone)
        if pb and pb > 0 then
            timerLine = timerLine .. string.format(" | PB: %s", FormatSeconds(pb))
        end
        local goal = GetGoal(mapId, keystone)
        if goal and goal > 0 then
            timerLine = timerLine .. string.format(" | Goal: %s", FormatSeconds(goal))
        end
    end

    return timerLine
end

local function BuildResultPopupKey(data, success)
    if type(data) ~= "table" then
        return nil
    end

    local mapId = GetMapIdFromState(data) or GetMapIdFromState(activeState) or GetMapIdFromState(lastPayload) or "?"
    local keystone = GetKeystoneFromState(data) or GetKeystoneFromState(activeState) or GetKeystoneFromState(lastPayload) or "?"
    local elapsed = tonumber(data.elapsed or data.timeElapsed or 0) or 0
    local successFlag = success and 1 or 0
    return tostring(mapId) .. ":" .. tostring(keystone) .. ":" .. tostring(elapsed) .. ":" .. tostring(successFlag)
end

local function BuildKeystoneResultLine(data, keyLevel)
    local oldLevel = tonumber(keyLevel or 0) or 0
    local newLevel = tonumber(data.upgradeLevel or oldLevel) or oldLevel
    local keyChange = tonumber(data.keyChange)
    if not keyChange then
        keyChange = newLevel - oldLevel
    end

    if keyChange > 0 then
        return string.format("Keystone: +%d -> +%d (+%d)", oldLevel, newLevel, keyChange)
    end
    if keyChange < 0 then
        return string.format("Keystone: +%d -> +%d (%d)", oldLevel, newLevel, keyChange)
    end
    return string.format("Keystone: +%d", newLevel)
end

local function EnsureResultFrame()
    if resultFrame then
        return resultFrame
    end

    resultFrame = CreateFrame("Frame", "DCMythicPlusResultFrame", UIParent)
    resultFrame:SetSize(420, 238)
    resultFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    resultFrame:SetFrameStrata("DIALOG")
    resultFrame:EnableMouse(true)
    resultFrame:SetMovable(true)
    resultFrame:RegisterForDrag("LeftButton")
    resultFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    resultFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    if resultFrame.SetBackdrop then
        resultFrame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        resultFrame:SetBackdropColor(0.04, 0.05, 0.10, 0.95)
        resultFrame:SetBackdropBorderColor(0.30, 0.48, 0.90, 0.95)
    end

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "DCMythicPlusResultFrame")
    end

    local titleBg = resultFrame:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleBg:SetVertexColor(0.10, 0.16, 0.28, 0.90)
    titleBg:SetPoint("TOPLEFT", resultFrame, "TOPLEFT", 4, -4)
    titleBg:SetPoint("TOPRIGHT", resultFrame, "TOPRIGHT", -4, -4)
    titleBg:SetHeight(34)

    local closeBtn = CreateFrame("Button", nil, resultFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", resultFrame, "TOPRIGHT", 1, 1)

    resultTitleText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    resultTitleText:SetPoint("TOP", resultFrame, "TOP", 0, -14)
    resultTitleText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    resultTitleText:SetText("MYTHIC+ COMPLETE")

    resultDungeonText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultDungeonText:SetPoint("TOPLEFT", resultFrame, "TOPLEFT", 14, -52)
    resultDungeonText:SetWidth(392)
    resultDungeonText:SetJustifyH("LEFT")

    resultDurationText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultDurationText:SetPoint("TOPLEFT", resultDungeonText, "BOTTOMLEFT", 0, -10)
    resultDurationText:SetWidth(392)
    resultDurationText:SetJustifyH("LEFT")

    resultBossesText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultBossesText:SetPoint("TOPLEFT", resultDurationText, "BOTTOMLEFT", 0, -10)
    resultBossesText:SetWidth(392)
    resultBossesText:SetJustifyH("LEFT")

    resultDeathsText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultDeathsText:SetPoint("TOPLEFT", resultBossesText, "BOTTOMLEFT", 0, -10)
    resultDeathsText:SetWidth(392)
    resultDeathsText:SetJustifyH("LEFT")

    resultRewardsText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultRewardsText:SetPoint("TOPLEFT", resultDeathsText, "BOTTOMLEFT", 0, -10)
    resultRewardsText:SetWidth(392)
    resultRewardsText:SetJustifyH("LEFT")

    resultKeystoneText = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    resultKeystoneText:SetPoint("TOPLEFT", resultRewardsText, "BOTTOMLEFT", 0, -10)
    resultKeystoneText:SetWidth(392)
    resultKeystoneText:SetJustifyH("LEFT")

    local okBtn = CreateFrame("Button", nil, resultFrame, "UIPanelButtonTemplate")
    okBtn:SetSize(92, 22)
    okBtn:SetPoint("BOTTOM", resultFrame, "BOTTOM", 0, 12)
    okBtn:SetText("Close")
    okBtn:SetScript("OnClick", function()
        if resultFrame then
            resultFrame:Hide()
        end
    end)

    resultFrame:Hide()
    return resultFrame
end

local function ShowRunResultPopup(data, success)
    if type(data) ~= "table" then
        return
    end

    local popupKey = BuildResultPopupKey(data, success)
    if popupKey and popupKey == lastResultPopupKey then
        return
    end
    lastResultPopupKey = popupKey

    local f = EnsureResultFrame()
    local mapId = GetMapIdFromState(data) or GetMapIdFromState(activeState) or GetMapIdFromState(lastPayload)
    local keyLevel = tonumber(GetKeystoneFromState(data) or GetKeystoneFromState(activeState) or GetKeystoneFromState(lastPayload) or 0) or 0
    local mapName = data.mapName or data.dungeonName or MapNameForId(mapId)
    local elapsed = tonumber(data.elapsed or data.timeElapsed or 0) or 0
    local bossesKilled = tonumber(data.bossesKilled or 0) or 0
    local bossesTotal = tonumber(data.bossesTotal or 0) or 0
    local deaths = tonumber(data.deaths or 0) or 0
    local wipes = tonumber(data.wipes or 0) or 0
    local tokensAwarded = tonumber(data.tokensAwarded or 0) or 0

    if success then
        resultTitleText:SetText("MYTHIC+ COMPLETE")
        resultTitleText:SetTextColor(0.40, 1.00, 0.45, 1)
    else
        resultTitleText:SetText("MYTHIC+ FAILED")
        resultTitleText:SetTextColor(1.00, 0.45, 0.38, 1)
    end

    resultDungeonText:SetText(string.format("Dungeon: %s  |  Keystone: +%d", mapName or "Unknown", keyLevel))
    resultDurationText:SetText("Duration: " .. FormatSeconds(elapsed))
    resultBossesText:SetText(string.format("Bosses: %d / %d", bossesKilled, bossesTotal))
    resultDeathsText:SetText(string.format("Deaths: %d  |  Wipes: %d", deaths, wipes))

    if success then
        resultRewardsText:SetText(string.format("Tokens Awarded: %d", tokensAwarded))
        resultRewardsText:SetTextColor(1.00, 0.85, 0.35, 1)
        resultKeystoneText:SetText(BuildKeystoneResultLine(data, keyLevel))
        resultKeystoneText:SetTextColor(0.75, 0.92, 1.00, 1)
    else
        resultRewardsText:SetText("Rewards: Not awarded")
        resultRewardsText:SetTextColor(1.00, 0.60, 0.60, 1)
        resultKeystoneText:SetText("Run failed before full completion")
        resultKeystoneText:SetTextColor(1.00, 0.75, 0.45, 1)
    end

    f:Show()
end

local function EnsureCenterCountdownOverlay()
    if centerCountdownText then
        return
    end

    centerCountdownFrame = CreateFrame("Frame", "DCMythicPlusCenterCountdown", UIParent)
    centerCountdownFrame:SetAllPoints(UIParent)
    centerCountdownFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    centerCountdownFrame:EnableMouse(false)

    centerCountdownText = centerCountdownFrame:CreateFontString(nil, "OVERLAY")
    centerCountdownText:SetFont("Fonts\\FRIZQT__.TTF", 56, "OUTLINE")
    centerCountdownText:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    centerCountdownText:SetText("")
    centerCountdownText:Hide()
end

local function EnsureFrame()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "DCMythicPlusHUDFrame", UIParent)
    frame:SetSize(340, 206)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    
    -- Background (WotLK/Retail style)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.02, 0.06, 0.16, 0.92)
        frame:SetBackdropBorderColor(0.26, 0.52, 0.90, 0.95)
    end

    local headerBg = frame:CreateTexture(nil, "ARTWORK")
    headerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    headerBg:SetVertexColor(0.09, 0.20, 0.40, 0.72)
    headerBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    headerBg:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    headerBg:SetHeight(28)

    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetVertexColor(0.20, 0.45, 0.80, 0.85)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -34)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -34)
    divider:SetHeight(1)

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not DCMythicPlusHUDDB.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        DCMythicPlusHUDDB.position = {
            point = point or "CENTER",
            relativePoint = relativePoint or "CENTER",
            x = math.floor(x + 0.5),
            y = math.floor(y + 0.5),
        }
    end)

    headerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    headerText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    headerText:SetWidth(250)
    headerText:SetJustifyH("LEFT")
    headerText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    headerText:SetText("Mythic+ HUD")
    headerText:SetTextColor(1, 0.84, 0.24, 1)

    -- Close button (hides HUD until re-enabled)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetSize(52, 20)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        DCMythicPlusHUDDB.hidden = true
        if frame then frame:Hide() end
    end)

    timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timerText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    timerText:SetText("Timer: --:-- / --:--")

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", timerText, "BOTTOMLEFT", 0, -8)
    statusText:SetText("Status: Waiting")

    deathText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    deathText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -7)
    deathText:SetText("Deaths: 0 | Wipes: 0")

    playerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    playerText:SetPoint("TOPLEFT", deathText, "BOTTOMLEFT", 0, -7)
    playerText:SetText("Players: 0")

    bossText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bossText:SetPoint("TOPLEFT", playerText, "BOTTOMLEFT", 0, -7)
    bossText:SetText("Bosses: 0")

    enemyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enemyText:SetPoint("TOPLEFT", bossText, "BOTTOMLEFT", 0, -7)
    enemyText:SetText("Enemies: 0")

    affixText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    affixText:SetPoint("TOPLEFT", enemyText, "BOTTOMLEFT", 0, -7)
    affixText:SetWidth(314)
    affixText:SetJustifyH("LEFT")
    affixText:SetText("Affixes: none")

    countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countdownText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 8)
    countdownText:SetText("")

    reasonText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reasonText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    reasonText:SetText("")

    frame:Hide()
    return frame
end

local function ApplySavedPosition()
    local f = EnsureFrame()
    local pos = DCMythicPlusHUDDB.position
    if not pos then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        return
    end
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 120)
end

local function IsInMythicOrMythicPlusInstance()
    -- Server-driven HUD should only show for active keystone runs.
    if not activeState or not IsRunInProgress(activeState) then
        return false
    end

    local keyLevel = tonumber(GetKeystoneFromState(activeState))
    if keyLevel and keyLevel > 0 then
        if type(IsInInstance) == "function" then
            local inInstance = select(1, IsInInstance())
            if inInstance then return true end
        end
        return false
    end

    return false
end

local function SetFrameVisibility(shouldShow)
    if not frame then
        return
    end

    if namespace._suppressHudThisSession then
        TraceVisibility("suppressed_session", false)
        frame:Hide()
        return
    end

    if IsOnGMIsland() then
        TraceVisibility("gm_island", false)
        frame:Hide()
        return
    end

    if DCMythicPlusHUDDB.hidden and not (activeState and IsRunInProgress(activeState)) then
        TraceVisibility("user_hidden", false)
        frame:Hide()
        return
    end

    -- Mythic/Mythic+ server-driven HUD
    if IsInMythicOrMythicPlusInstance() and activeState and IsRunInProgress(activeState) then
        TraceVisibility("mythic_active", true)
        frame:Show()
        return
    end

    -- Optional local timer fallback. Disabled by default so the HUD does
    -- not appear from plain dungeon entry without an active Mythic+ run.
    if ENABLE_LOCAL_RUN_HUD_FALLBACK then
        local trackable = GetTrackableInstanceInfo()
        if (localRun.active or localRun.finished) and trackable then
            TraceVisibility("local_timer", true)
            frame:Show()
            return
        end

        if shouldShow then
            TraceVisibility("fallback", true)
            frame:Show()
            return
        end
    end

    TraceVisibility("inactive", false)
    frame:Hide()
end

local function UpdateFrameFromLocalRun()
    if not frame then
        return
    end

    if not ENABLE_LOCAL_RUN_HUD_FALLBACK then
        return
    end

    if IsOnGMIsland() then
        frame:Hide()
        return
    end

    if DCMythicPlusHUDDB.hidden then
        frame:Hide()
        return
    end
    if IsMythicRunActive() then
        return
    end
    if not (localRun.active or localRun.finished) then
        return
    end

    local trackable = GetTrackableInstanceInfo()
    if not trackable then
        SetFrameVisibility(false)
        return
    end

    local f = EnsureFrame()
    ApplySavedPosition()

    local name = TruncateForHudTitle(localRun.instanceName or "Run Timer", 24)
    headerText:SetText(string.format("%s |cffffaa33Run|r", name))

    local elapsed
    if localRun.active then
        elapsed = math.max(0, NowSeconds() - (localRun.startedAt or 0))
    else
        elapsed = localRun.finishedElapsed or 0
    end
    timerText:SetText(string.format("Timer: %s / --:--", FormatSeconds(elapsed)))
    statusText:SetText(localRun.active and "Status: |cff78beffTracking|r" or "Status: |cff50ff7aFinished|r")

    -- Keep the rest minimal for non-Mythic runs
    deathText:SetText("")
    playerText:SetText("")
    bossText:SetText("")
    if enemyText then enemyText:SetText("") end
    affixText:SetText("")
    countdownText:SetText("")
    reasonText:SetText("")
    lastCenterCountdownValue = nil
    if centerCountdownText then
        centerCountdownText:Hide()
    end

    SetFrameVisibility(true)
end

-- =====================================================================
-- Inventory Keystone Detection (fallback)
-- =====================================================================
namespace.inventoryKeystone = namespace.inventoryKeystone or nil

local function StripColorCodes(s)
    if not s then
        return s
    end
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    return s
end

local function KeystoneEqual(a, b)
    if a == b then
        return true
    end
    if (not a) ~= (not b) then
        return false
    end
    -- Dungeon assignment is optional in DC (generic keystone per level).
    -- Treat keys as equal based on level + link; ignore dungeonName to avoid spam.
    return (a.hasKey == b.hasKey)
        and (a.level == b.level)
        and (a.itemLink == b.itemLink)
end

local function KeystoneSig(k)
    if not k then
        return "none"
    end
    return tostring(k.hasKey) .. ":" .. tostring(k.level) .. ":" .. tostring(k.itemLink)
end

local function ScanInventoryForKeystone()
    -- Scan all bags (0-4) for keystone-like items; try to parse level/dungeon
    local found = nil
    -- Determine ID mapping from the shared DC addon protocol if available.
    local DCproto = rawget(_G, "DCAddonProtocol")
    local DCCentral = rawget(_G, "DCCentral")
    local KEYSTONE_IDS = (DCCentral and DCCentral.KEYSTONE_ITEM_IDS) or
        (DCproto and DCproto.KEYSTONE_ITEM_IDS)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemId = GetContainerItemID(bag, slot)
            if itemId then
                local itemName, itemLink = GetItemInfo(itemId)
                -- Fast path: check known keystone item IDs
                local isKeystoneId = KEYSTONE_IDS and KEYSTONE_IDS[itemId]
                if isKeystoneId or (itemName and string.find(itemName, "Keystone")) then
                    -- Attempt to extract level
                    local level = tonumber((itemName and (string.match(itemName, "%+(%d+)") or string.match(itemName, "Level (%d+)") or string.match(itemName, "%((%d+)%)")))) or nil
                    local dungeon = (itemName and (string.match(itemName, ":%s*(.+)%s*%+") or string.match(itemName, "Keystone:%s*(.+)"))) or nil
                    -- Fallback to tooltip parsing for more detailed info
                    local tooltipLevel, tooltipDungeon
                    -- Reuse a shared tooltip if available (DCCentral / DC addon-protocol), otherwise fallback to namespace local tooltip
                    local tooltip
                    if DCproto and type(DCproto.GetScanTooltip) == 'function' then
                        tooltip = DCproto:GetScanTooltip()
                    else
                        tooltip = rawget(_G, "DCScanTooltip")
                    end
                    if not tooltip then
                        if not namespace.keystoneTooltip then
                            namespace.keystoneTooltip = CreateFrame("GameTooltip", "DCMythicPlusKeystoneScanTooltip", nil, "GameTooltipTemplate")
                        end
                        tooltip = namespace.keystoneTooltip
                    end
                    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
                    tooltip:ClearLines()
                    tooltip:SetBagItem(bag, slot)
                    local tooltipName = tooltip.GetName and tooltip:GetName() or nil
                    for i = 1, tooltip:NumLines() do
                        local line
                        if tooltipName then
                            line = _G[tooltipName .. "TextLeft" .. i]
                        end
                        if line then
                            local text = StripColorCodes(line:GetText())
                            if text then
                                local lvl = string.match(text, "Level:?%s*(%d+)") or string.match(text, "%+(%d+)") or string.match(text, "Mythic Level (%d+)") or string.match(text, "Keystone Level (%d+)")
                                if lvl then tooltipLevel = tonumber(lvl) end
                                local dng = string.match(text, "Dungeon:?%s*(.+)") or string.match(text, "Instance:?%s*(.+)") or string.match(text, "Map:?%s*(.+)")
                                if dng then tooltipDungeon = dng end
                            end
                        end

                        local rline
                        if tooltipName then
                            rline = _G[tooltipName .. "TextRight" .. i]
                        end
                        if rline then
                            local rtext = StripColorCodes(rline:GetText())
                            if rtext then
                                local lvl = string.match(rtext, "Level:?%s*(%d+)") or string.match(rtext, "%+(%d+)") or string.match(rtext, "Mythic Level (%d+)") or string.match(rtext, "Keystone Level (%d+)")
                                if lvl then tooltipLevel = tonumber(lvl) end
                                local dng = string.match(rtext, "Dungeon:?%s*(.+)") or string.match(rtext, "Instance:?%s*(.+)") or string.match(rtext, "Map:?%s*(.+)")
                                if dng then tooltipDungeon = dng end
                            end
                        end
                    end
                    if not level and tooltipLevel then level = tooltipLevel end
                    if not dungeon and tooltipDungeon then dungeon = tooltipDungeon end

                    -- DC currently uses generic keystones per level (not per dungeon).
                    -- Keep dungeonName only if we can confidently parse it.
                    if dungeon == "Unknown" or dungeon == "" then
                        dungeon = nil
                    end
                    
                    -- Only accept if we found a valid level
                    if level and level > 0 then
                        local itemTexture = nil
                        if type(GetContainerItemInfo) == "function" then
                            itemTexture = GetContainerItemInfo(bag, slot)
                        end

                        found = {
                            hasKey = true,
                            level = level or 0,
                            dungeonName = dungeon,
                            itemId = itemId,
                            itemLink = itemLink,
                            itemTexture = itemTexture,
                            bag = bag,
                            slot = slot,
                        }
                        break
                    end
                end
            end
        end
        if found then break end
    end

    local changed = not KeystoneEqual(namespace.inventoryKeystone, found)
    namespace.inventoryKeystone = found
    if changed then
        local sig = KeystoneSig(found)
        local lastSig = namespace._lastInvKeyAnnouncedSig

        -- Avoid the common "startup flicker" where bags aren't ready yet.
        -- Only announce "none" if we previously had a key, or if we've been in-world for a few seconds.
        local now = (GetTime and GetTime()) or 0
        local inWorldFor = now - (namespace._enteredWorldAt or 0)
        local runActive = IsRunInProgress(activeState)

        if sig ~= lastSig then
            if sig == "none" then
                if runActive then
                    namespace._lastInvKeyAnnouncedSig = sig
                elseif lastSig and lastSig ~= "none" then
                    Print("No inventory keystone detected")
                    namespace._lastInvKeyAnnouncedSig = sig
                elseif inWorldFor >= 5 then
                    Print("No inventory keystone detected")
                    namespace._lastInvKeyAnnouncedSig = sig
                end
            else
                local msg = "Inventory keystone detected: +" .. (found.level or 0)
                if found.dungeonName then
                    msg = msg .. " " .. tostring(found.dungeonName)
                end
                Print(msg)
                namespace._lastInvKeyAnnouncedSig = sig
            end
        end
    end
    -- If GroupFinder UI exists, update the keystone panel display immediately
    if namespace.GroupFinder and type(namespace.GroupFinder.UpdateKeystoneDisplay) == "function" then
        namespace.GroupFinder:UpdateKeystoneDisplay(found or {})
    end
    return found
end

local scanFrame = CreateFrame("Frame")
local inventoryScanQueued = false

local function ScheduleInventoryScan(delay)
    if inventoryScanQueued then
        return
    end

    inventoryScanQueued = true
    C_Timer.After(delay or 0.15, function()
        inventoryScanQueued = false
        ScanInventoryForKeystone()
    end)
end

scanFrame:RegisterEvent("BAG_UPDATE")
scanFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
scanFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        namespace._enteredWorldAt = (GetTime and GetTime()) or 0
        ScanInventoryForKeystone()
        -- Request canonical keystone mapping from server to ensure client knows IDs
        local protocol = RefreshDCProtocol()
        if protocol and protocol.MythicPlus and type(protocol.MythicPlus.GetKeystoneList) == 'function' then
            protocol.MythicPlus.GetKeystoneList()
        end
        return
    end

    -- BAG_UPDATE can fire many times per single loot/swap; batch into one scan.
    ScheduleInventoryScan(0.15)
end)

-- Expose scanner function on namespace for other modules to call
namespace.ScanInventoryForKeystone = ScanInventoryForKeystone


local function ShowIdleState()
    local f = EnsureFrame()
    if not f then
        return
    end
    EnsureCenterCountdownOverlay()
    activeState = nil
    UpdateQuestTrackerSuppression()
    lastPayload = nil
    headerText:SetText("Mythic+ HUD")
    timerText:SetText("Timer: --:-- / --:--")
    statusText:SetText("Status: Waiting for server data")
    deathText:SetText("Deaths: 0 | Wipes: 0")
    playerText:SetText("Players: 0")
    bossText:SetText("Bosses: 0")
    if enemyText then
        enemyText:SetText("Enemies: 0")
    end
    affixText:SetText("Affixes: none")
    countdownText:SetText("")
    reasonText:SetText("")
    lastCenterCountdownValue = nil
    if centerCountdownText then
        centerCountdownText:Hide()
    end

    UpdateMinimapMythicKeyBadge()

    -- Re-evaluate visibility when server reports no active Mythic+ snapshot.
    -- This prevents stale run payloads from keeping the HUD visible/running.
    UpdateLocalRunTrackingFromInstance()
    SetFrameVisibility(false)
end

local function UpdateCountdown(data)
    if not countdownText then
        return
    end
    EnsureCenterCountdownOverlay()

    local countdown = tonumber(data and data.countdown or 0) or 0
    if countdown > 0 then
        countdownText:SetText("")
        local color = countdown <= 3 and "|cffff4040" or "|cffffff00"
        centerCountdownText:SetText(string.format("%s%d|r", color, countdown))
        centerCountdownText:Show()
        lastCenterCountdownValue = countdown
    else
        countdownText:SetText("")
        if lastCenterCountdownValue then
            centerCountdownText:SetText("|cff00ff00GO!|r")
            centerCountdownText:Show()
            C_Timer.After(1.0, function()
                if centerCountdownText then
                    centerCountdownText:Hide()
                end
            end)
            lastCenterCountdownValue = nil
        elseif centerCountdownText then
            centerCountdownText:Hide()
        end
    end
end

local function UpdateReason(reason)
    if reasonText then
        if reason and reason ~= "" and reason ~= "tick" then
            reasonText:SetText("Reason: " .. reason)
        else
            reasonText:SetText("")
        end
    end
end

local function RequestServerSnapshot(reason)
    local protocol = RefreshDCProtocol()
    local reqReason = reason or "client"

    if ShouldUseNativeMythicPlusHudBridge() then
        local now = (type(GetTime) == "function" and GetTime()) or 0
        if now <= 0 and type(time) == "function" then
            now = time()
        end
        if REQUEST_COOLDOWN > 0 and lastRequestTime > 0 and now > 0 then
            if (now - lastRequestTime) < REQUEST_COOLDOWN then
                return
            end
        end
        lastRequestTime = now > 0 and now or lastRequestTime
        Trace("RequestHUD via native bridge, reason=" .. tostring(reqReason))
        RequestNativeMythicPlusHud(reqReason)
        return
    end

    -- Try DCAddonProtocol first (new C++ backend)
    if namespace.useDCProtocol and protocol and protocol.MythicPlus and protocol.MythicPlus.RequestHUD then
        local now = (type(GetTime) == "function" and GetTime()) or 0
        if now <= 0 and type(time) == "function" then
            now = time()
        end
        if REQUEST_COOLDOWN > 0 and lastRequestTime > 0 and now > 0 then
            if (now - lastRequestTime) < REQUEST_COOLDOWN then
                return
            end
        end
        lastRequestTime = now > 0 and now or lastRequestTime
        Trace("RequestHUD via DC wrapper, reason=" .. tostring(reqReason))
        protocol.MythicPlus.RequestHUD(reqReason)
        return
    end

    -- Fallback for DC protocol environments without MythicPlus helper wrappers.
    if namespace.useDCProtocol and protocol and type(protocol.Send) == "function" then
        local now = (type(GetTime) == "function" and GetTime()) or 0
        if now <= 0 and type(time) == "function" then
            now = time()
        end
        if REQUEST_COOLDOWN > 0 and lastRequestTime > 0 and now > 0 then
            if (now - lastRequestTime) < REQUEST_COOLDOWN then
                return
            end
        end
        lastRequestTime = now > 0 and now or lastRequestTime
        Trace("RequestHUD via DC:Send, reason=" .. tostring(reqReason))
        protocol:Send("MPLUS", 0x05, reqReason)
        return
    end
    
    -- Fallback to AIO (old Lua backend)
    if not AIO or type(AIO.Handle) ~= "function" then
        Trace("RequestHUD skipped: no DC or AIO transport available")
        return
    end
    local now = (type(GetTime) == "function" and GetTime()) or 0
    if now <= 0 and type(time) == "function" then
        now = time()
    end
    if REQUEST_COOLDOWN > 0 and lastRequestTime > 0 and now > 0 then
        if (now - lastRequestTime) < REQUEST_COOLDOWN then
            return
        end
    end
    lastRequestTime = now > 0 and now or lastRequestTime
    Trace("RequestHUD via AIO, reason=" .. tostring(reqReason))
    local ok, err = pcall(function()
        AIO.Handle(SERVER_ADDON_NAME, "RequestHud", reqReason)
    end)
    if not ok then
        Print("Failed to request HUD data: " .. tostring(err))
    end
end

local JsonDecoder
JsonDecoder = {}

local function skipWhitespace(str, idx)
    local len = #str
    while idx <= len do
        local byte = str:byte(idx)
        if not byte then
            break
        end
        if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
            break
        end
        idx = idx + 1
    end
    return idx
end

local function parseLiteral(str, idx, literal, value)
    if str:sub(idx, idx + #literal - 1) == literal then
        return value, idx + #literal
    end
    error("invalid literal")
end

local function parseNumber(str, idx)
    local startIdx = idx
    local len = #str
    while idx <= len do
        local c = str:sub(idx, idx)
        if not c:match("[0-9%+%-%eE%.]") then
            break
        end
        idx = idx + 1
    end
    local num = tonumber(str:sub(startIdx, idx - 1))
    if not num then
        error("invalid number")
    end
    return num, idx
end

local function parseString(str, idx)
    idx = idx + 1
    local len = #str
    local buffer = {}
    while idx <= len do
        local char = str:sub(idx, idx)
        if char == '"' then
            return table.concat(buffer), idx + 1
        elseif char == '\\' then
            local esc = str:sub(idx + 1, idx + 1)
            if esc == 'u' then
                local hex = str:sub(idx + 2, idx + 5)
                local code = tonumber(hex, 16)
                if not code then
                    error("invalid unicode escape")
                end
                if code <= 0x7F then
                    buffer[#buffer + 1] = string.char(code)
                else
                    buffer[#buffer + 1] = "?"
                end
                idx = idx + 6
            else
                local map = {
                    ["\\"] = "\\",
                    ['"'] = '"',
                    ['/'] = '/',
                    ['b'] = string.char(8),
                    ['f'] = string.char(12),
                    ['n'] = "\n",
                    ['r'] = "\r",
                    ['t'] = "\t",
                }
                buffer[#buffer + 1] = map[esc] or esc
                idx = idx + 2
            end
        else
            buffer[#buffer + 1] = char
            idx = idx + 1
        end
    end
    error("unterminated string")
end

local parseValue

local function parseArray(str, idx)
    idx = idx + 1
    local result = {}
    idx = skipWhitespace(str, idx)
    if str:sub(idx, idx) == ']' then
        return result, idx + 1
    end
    local n = 1
    while true do
        local value
        value, idx = parseValue(str, idx)
        result[n] = value
        n = n + 1
        idx = skipWhitespace(str, idx)
        local char = str:sub(idx, idx)
        if char == ']' then
            return result, idx + 1
        end
        if char ~= ',' then
            error("expected comma in array")
        end
        idx = skipWhitespace(str, idx + 1)
    end
end

local function parseObject(str, idx)
    idx = idx + 1
    local result = {}
    idx = skipWhitespace(str, idx)
    if str:sub(idx, idx) == '}' then
        return result, idx + 1
    end
    while true do
        local key
        if str:sub(idx, idx) ~= '"' then
            error("expected string key")
        end
        key, idx = parseString(str, idx)
        idx = skipWhitespace(str, idx)
        if str:sub(idx, idx) ~= ':' then
            error("expected colon")
        end
        idx = skipWhitespace(str, idx + 1)
        local value
        value, idx = parseValue(str, idx)
        result[key] = value
        idx = skipWhitespace(str, idx)
        local char = str:sub(idx, idx)
        if char == '}' then
            return result, idx + 1
        end
        if char ~= ',' then
            error("expected comma in object")
        end
        idx = skipWhitespace(str, idx + 1)
    end
end

function parseValue(str, idx)
    idx = skipWhitespace(str, idx)
    local char = str:sub(idx, idx)
    if char == '{' then
        return parseObject(str, idx)
    elseif char == '[' then
        return parseArray(str, idx)
    elseif char == '"' then
        return parseString(str, idx)
    elseif char == '-' or char:match("%d") then
        return parseNumber(str, idx)
    elseif char == 't' then
        return parseLiteral(str, idx, "true", true)
    elseif char == 'f' then
        return parseLiteral(str, idx, "false", false)
    elseif char == 'n' then
        return parseLiteral(str, idx, "null", nil)
    end
    error("unexpected character in JSON")
end

local function DecodeJSON(input)
    if type(input) ~= "string" then
        return nil
    end
    local success, result = pcall(function()
        local value, position = parseValue(input, 1)
        position = skipWhitespace(input, position)
        if position <= #input then
            -- ignore trailing commas/spaces gracefully
        end
        return value
    end)
    if success then
        return result
    end
    return nil
end

namespace.DecodeJSON = DecodeJSON

local function NormalizeHudState(data)
    if type(data) ~= "table" then
        return data
    end

    data.countdown = tonumber(data.countdown or 0) or 0

    local keyLevel = tonumber(data.keystone)
        or tonumber(data.keyLevel)
        or tonumber(data.keystoneLevel)
        or tonumber(data.level)
    if keyLevel then
        data.keystone = keyLevel
        data.keyLevel = keyLevel
    end

    if not data.mapName and data.dungeonName then
        data.mapName = data.dungeonName
    end

    data.inProgress = IsRunInProgress(data)

    if data.inProgress and data.countdown <= 0 then
        data._timerAnchorClient = GetClientNowSeconds()
        data._timerElapsedBase = tonumber(data.elapsed or 0) or 0
        data._timerRemainingBase = tonumber(data.remaining or 0) or 0

        local maxSec = tonumber(data.duration or data.timeLimit or 0) or 0
        if maxSec <= 0 then
            maxSec = data._timerElapsedBase + data._timerRemainingBase
        end
        data._timerMax = maxSec
    end

    return data
end

local function UpdateFrameFromState(data)
    data = NormalizeHudState(data)
    activeState = data
    UpdateQuestTrackerSuppression()
    if IsRunInProgress(data) then
        if DCMythicPlusHUDDB.hidden then
            DCMythicPlusHUDDB.hidden = false
            Trace("Auto-cleared hidden flag because active Mythic+ run data arrived")
        end
        ClearFirstLoginSuppression()
    end
    local f = EnsureFrame()
    ApplySavedPosition()

    -- If we get server state updates, prefer Mythic+ HUD and stop local tracking display.
    UpdateLocalRunTrackingFromInstance()

    local mapId = GetMapIdFromState(data)
    local keystone = GetKeystoneFromState(data)
    local runKey = GetRunKey(mapId, keystone)
    if IsRunInProgress(data) then
        if not runTracker.active then
            ResetRunTracking(runKey or "unknown", mapId, keystone)
        elseif runKey and runTracker.runKey ~= runKey then
            ResetRunTracking(runKey, mapId, keystone)
        end
    elseif runTracker.active and not runTracker.endLogged and not IsFlagSet(data.completed) and not IsFlagSet(data.failed) then
        StopRunTracking(false, data and data.elapsed or nil)
    end

    local mapName = TruncateForHudTitle(data.mapName or MapNameForId(mapId), 22)
    local keystoneDisplay = tonumber(keystone) or 0
    headerText:SetText(string.format("%s |cffffaa33+%d|r", mapName, keystoneDisplay))

    timerText:SetText(BuildFullTimerLine(data))

    statusText:SetText(BuildStatus(data))

    deathText:SetText(string.format("Deaths: %d | Wipes: %d", data.deaths or 0, data.wipes or 0))

    local playerCount = CountTableValues(data.participants)
    local playerLine = string.format("Players: %d", playerCount)
    if IsRunInProgress(data) and runTracker.active then
        local top = GetTopDeathSummary(3)
        if top and top ~= "" then
            playerLine = playerLine .. " | Deaths: " .. top
        end
    end
    playerText:SetText(playerLine)

    bossText:SetText(BuildBossLine(data.bossesKilled or 0, data.bossesTotal or 0))

    if enemyText then
        enemyText:SetText(string.format("Enemies: %d", data.enemiesKilled or 0))
    end

    affixText:SetText(BuildAffixLine(data.affixes))

    UpdateCountdown(data)
    UpdateReason(data.reason)

    lastPayload = data
    -- Update visibility based on current state (mythic or local)
    SetFrameVisibility(IsRunInProgress(data))
    UpdateMinimapMythicKeyBadge()

    if IsFlagSet(data.completed) and runTracker.active and not runTracker.endLogged then
        ShowRunResultPopup(data, true)
        if mapId and keystone then
            local improved = AddPersonalBestIfImproved(mapId, keystone, data.elapsed)
            if improved then
                Print(string.format("New Personal Best for %s +%d: %s", mapName or "Dungeon", tonumber(keystone) or 0, FormatSeconds(data.elapsed)))
            end
        end
        StopRunTracking(true, data.elapsed)
    elseif IsFlagSet(data.failed) and runTracker.active and not runTracker.endLogged then
        ShowRunResultPopup(data, false)
        StopRunTracking(false, data.elapsed)
    end
end

local function HandleIncomingPayload(payload)
    local data = payload
    if type(payload) == "string" then
        if payload == "" then
            return
        end
        data = DecodeJSON(payload)
    end
    if type(data) ~= "table" then
        return
    end
    local op = data.op or "hud"
    if op ~= "hud" then
        if op == "idle" then
            ShowIdleState()
        end
        return
    end
    UpdateFrameFromState(data)
end

local function ConsumeNativeHudSnapshot()
    if not ShouldUseNativeMythicPlusHudBridge() then
        return false
    end

    local ok, revision, payload = pcall(GetNativeMythicPlusHudSnapshot)
    if not ok or revision == nil then
        return false
    end

    revision = tonumber(revision) or 0
    if revision <= 0 or revision == lastNativeHudRevision then
        return false
    end

    lastNativeHudRevision = revision
    if type(payload) ~= "string" or payload == "" then
        return false
    end

    Trace("Consumed native HUD snapshot rev=" .. tostring(revision))
    HandleIncomingPayload(payload)
    return true
end

local function EnsureNativeHudPollFrame()
    if nativeHudPollFrame then
        return
    end

    nativeHudPollFrame = CreateFrame("Frame")
    nativeHudPollFrame.elapsed = 0
    nativeHudPollFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < NATIVE_MPLUS_HUD_POLL_INTERVAL then
            return
        end

        self.elapsed = 0
        ConsumeNativeHudSnapshot()
    end)
end

local function HandleTimerUpdatePayload(...)
    local args = {...}
    local payload = args[1]

    -- Preferred path: use shared HUD payload handler for both tables and JSON strings.
    if type(payload) == "table" then
        local reason = tostring(payload.reason or "")
        if ShouldTraceTimerPayload(reason) then
            Trace("MPLUS 0x15 received payloadType=table")
            Trace(string.format(
                "MPLUS 0x15 table inProgress=%s countdown=%s started=%s remaining=%s elapsed=%s reason=%s",
                tostring(payload.inProgress),
                tostring(payload.countdown),
                tostring(payload.started),
                tostring(payload.remaining),
                tostring(payload.elapsed),
                reason
            ))
        end
        HandleIncomingPayload(payload)
        return
    end

    if type(payload) == "string" and payload ~= "" then
        local decoded = DecodeJSON(payload)
        if type(decoded) == "table" then
            local reason = tostring(decoded.reason or "")
            if ShouldTraceTimerPayload(reason) then
                Trace("MPLUS 0x15 received payloadType=string")
                Trace(string.format(
                    "MPLUS 0x15 json inProgress=%s countdown=%s started=%s remaining=%s elapsed=%s reason=%s",
                    tostring(decoded.inProgress),
                    tostring(decoded.countdown),
                    tostring(decoded.started),
                    tostring(decoded.remaining),
                    tostring(decoded.elapsed),
                    reason
                ))
            end
            HandleIncomingPayload(decoded)
            return
        end
        if ShouldTraceTimerPayload("decode_error") then
            Trace("MPLUS 0x15 string payload not decodable as JSON")
        end
    end

    -- Legacy fallback: pipe-delimited format (elapsed, timeLimit, deaths).
    local elapsed, timeLimit, deaths = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if ShouldTraceTimerPayload("legacy") then
        Trace(string.format(
            "MPLUS 0x15 legacy elapsed=%s timeLimit=%s deaths=%s activeState=%s",
            tostring(elapsed),
            tostring(timeLimit),
            tostring(deaths),
            tostring(activeState ~= nil)
        ))
    end
    if activeState then
        activeState.elapsed = elapsed
        activeState.timeLimit = timeLimit
        activeState.deaths = deaths or activeState.deaths
        activeState.inProgress = IsRunInProgress(activeState)
        UpdateFrameFromState(activeState)
    end
end

local retryTicker
local function TryRegisterHandlers()
    local protocol = RefreshDCProtocol()
    local dcReady = namespace.useDCProtocol and protocol and type(protocol.RegisterHandler) == "function"

    if HasNativeMythicPlusHudBridge() then
        EnsureNativeHudPollFrame()
    end

    if dcReady and not namespace._dcRuntimeHudHandlerBound then
        local okBind, bindErr = pcall(function()
            protocol:RegisterHandler("MPLUS", 0x15, HandleTimerUpdatePayload)
        end)
        if okBind then
            namespace._dcRuntimeHudHandlerBound = true
            Trace("Runtime-bound MPLUS 0x15 handler")
        else
            Trace("Failed runtime bind MPLUS 0x15: " .. tostring(bindErr))
        end
    end

    if namespace.handlersRegistered then
        return true
    end

    local function DecodeAioPayload(payload)
        if type(payload) == "table" then
            return payload
        end
        if type(payload) == "string" and payload ~= "" then
            return DecodeJSON(payload)
        end
        return nil
    end

    local aioReady = false
    if AIO and type(AIO.AddHandlers) == "function" then
        local ok, handlers = pcall(function()
            return AIO.AddHandlers(SERVER_ADDON_NAME, {})
        end)
        if ok and type(handlers) == "table" then
            handlers[SERVER_MESSAGE_KEY] = function(_, payload)
                HandleIncomingPayload(payload)
            end

            local okMplus, mplusHandlers = pcall(function()
                return AIO.AddHandlers("MPLUS", {})
            end)
            if okMplus and type(mplusHandlers) == "table" then
                mplusHandlers.KEYSTONE_ACTIVATE = function(_, payload)
                    local data = DecodeAioPayload(payload) or {}
                    if namespace.KeystoneUI and type(namespace.KeystoneUI.OnKeystoneReadyCheck) == "function" then
                        namespace.KeystoneUI:OnKeystoneReadyCheck(data)
                    end
                end

                mplusHandlers.KEYSTONE_STATUS = function(_, payload)
                    local data = DecodeAioPayload(payload) or {}
                    if namespace.KeystoneUI and type(namespace.KeystoneUI.OnPlayerReadyUpdate) == "function" then
                        namespace.KeystoneUI:OnPlayerReadyUpdate(data)
                    end
                end

                mplusHandlers.KEYSTONE_COUNTDOWN = function(_, payload)
                    local data = DecodeAioPayload(payload) or {}
                    if namespace.KeystoneUI and type(namespace.KeystoneUI.OnCountdownStart) == "function" then
                        namespace.KeystoneUI:OnCountdownStart(data)
                    end
                end

                mplusHandlers.KEYSTONE_CANCEL = function(_, payload)
                    local data = DecodeAioPayload(payload) or {}
                    if namespace.KeystoneUI and type(namespace.KeystoneUI.OnActivationCancelled) == "function" then
                        namespace.KeystoneUI:OnActivationCancelled(data)
                    end
                end
            end

            aioReady = true
        end
    end

    Trace(string.format(
        "TryRegisterHandlers aioReady=%s dcReady=%s useDC=%s",
        tostring(aioReady),
        tostring(dcReady),
        tostring(namespace.useDCProtocol)
    ))

    if not aioReady and not dcReady then
        Trace("TryRegisterHandlers waiting for transport")
        return false
    end

    namespace.handlersRegistered = true
    if retryTicker then
        retryTicker:SetScript("OnUpdate", nil)
    end
    if DCMythicPlusHUDDB.debugTrace then
        if aioReady then
            Print("AIO handler ready")
        elseif dcReady then
            Print("DC protocol handler ready")
        end
    end
    RequestServerSnapshot("register")
    if lastPayload then
        HandleIncomingPayload(lastPayload)
    end
    return true
end

local function BeginRetryLoop()
    if retryTicker then
        return
    end
    retryTicker = CreateFrame("Frame")
    retryTicker.elapsed = 0
    retryTicker:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= UPDATE_INTERVAL then
            self.elapsed = 0
            if TryRegisterHandlers() then
                self:SetScript("OnUpdate", nil)
            end
        end
    end)
end

local function ToggleLock()
    DCMythicPlusHUDDB.locked = not DCMythicPlusHUDDB.locked
    Print(DCMythicPlusHUDDB.locked and "Frame locked" or "Frame unlocked")
end

local function ToggleVisibility()
    DCMythicPlusHUDDB.hidden = not DCMythicPlusHUDDB.hidden
    if DCMythicPlusHUDDB.hidden then
        SetFrameVisibility(false)
        Print("HUD hidden. Use /dcm to show again.")
    else
        ClearFirstLoginSuppression()
        if IsRunInProgress(activeState) then
            Print("HUD shown.")
        else
            Print("HUD enabled. It will appear when a Mythic+ run is active.")
        end
        if not activeState then
            ShowIdleState()
        end
        SetFrameVisibility(true)
        RequestServerSnapshot("toggle")
    end
end

SLASH_DCM1 = "/dcm"
SLASH_DCM2 = "/dcmplus"
SLASH_DCGF1 = "/dcgf"
SLASH_DCGF2 = "/groupfinder"

-- Group Finder slash command
SlashCmdList.DCGF = function(msg)
    msg = Trim((msg or "")):lower()
    if namespace.GroupFinder then
        namespace.GroupFinder:Toggle()
    else
        Print("Group Finder not loaded yet")
    end
end

SlashCmdList.DCM = function(msg)
    local raw = Trim(msg or "")
    local lowered = raw:lower()
    local cmd, rest = lowered:match("^(%S+)%s*(.-)$")

    if raw == "" then
        ToggleVisibility()
        return
    end

    if cmd == "lock" then
        ToggleLock()
    elseif cmd == "unlock" then
        DCMythicPlusHUDDB.locked = false
        Print("Frame unlocked")
    elseif cmd == "show" then
        DCMythicPlusHUDDB.hidden = false
        ClearFirstLoginSuppression()
        UpdateLocalRunTrackingFromInstance()
        SetFrameVisibility(true)
        if IsRunInProgress(activeState) then
            Print("HUD shown")
        else
            Print("HUD will show when a Mythic+ run is active")
        end
        RequestServerSnapshot("slash")
    elseif cmd == "hide" then
        DCMythicPlusHUDDB.hidden = true
        SetFrameVisibility(false)
        Print("HUD hidden")
    elseif cmd == "refresh" or cmd == "sync" then
        RequestServerSnapshot("slash")
        Print("Requested latest HUD snapshot")
    elseif cmd == "reset" then
        DCMythicPlusHUDDB.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 }
        ApplySavedPosition()
        Print("HUD position reset")
    elseif cmd == "json" then
        DCMythicPlusHUDDB.useDCProtocolJSON = not (DCMythicPlusHUDDB.useDCProtocolJSON == true)
        Print("DC Protocol JSON mode: " .. (DCMythicPlusHUDDB.useDCProtocolJSON and "ON" or "OFF"))
    elseif cmd == "key" then
        if namespace.RequestKeyInfo then
            namespace.RequestKeyInfo()
            Print("Requesting keystone info...")
        else
            Print("DC protocol not available")
        end
    elseif cmd == "affixes" then
        if namespace.RequestAffixes then
            namespace.RequestAffixes()
            Print("Requesting weekly affixes...")
        else
            Print("DC protocol not available")
        end
    elseif cmd == "best" or cmd == "runs" then
        if namespace.RequestBestRuns then
            namespace.RequestBestRuns()
            Print("Requesting best runs...")
        else
            Print("DC protocol not available")
        end
    elseif cmd == "pb" then
        local sub = rest and rest:match("^(%S+)") or ""
        if sub == "clear" then
            local db = EnsurePersonalDB()
            wipe(db.pb)
            Print("Personal bests cleared")
        elseif sub == "all" then
            local db = EnsurePersonalDB()
            Print("Personal bests:")
            local rows = {}
            for key, val in pairs(db.pb) do
                table.insert(rows, { key = key, val = tonumber(val) or 0 })
            end
            table.sort(rows, function(a, b) return a.key < b.key end)
            for _, r in ipairs(rows) do
                local mapIdStr, keyLvlStr = tostring(r.key):match("^(.-):(.-)$")
                local name = (mapIdStr and MapNameForId and MapNameForId(tonumber(mapIdStr))) or ("Dungeon " .. (mapIdStr or "?"))
                Print(string.format("  %s +%s: %s", name, keyLvlStr or "?", FormatSeconds(r.val)))
            end
            if #rows == 0 then
                Print("  (none)")
            end
        else
            local runKeyNow, mapId, keyLevel = GetCurrentRunKey()
            if not runKeyNow then
                Print("No active dungeon/key context for PB")
                return
            end
            local pb = GetPersonalBest(mapId, keyLevel)
            if pb and pb > 0 then
                Print(string.format("PB for %s +%d: %s", (MapNameForId and MapNameForId(mapId)) or "Dungeon", tonumber(keyLevel) or 0, FormatSeconds(pb)))
            else
                Print("No PB recorded yet for this dungeon/key")
            end
        end
    elseif cmd == "goal" then
        local sub = rest and Trim(rest) or ""
        local runKeyNow, mapId, keyLevel = GetCurrentRunKey()
        if not runKeyNow then
            Print("No active dungeon/key context for goal")
            return
        end
        if sub == "" then
            local goal = GetGoal(mapId, keyLevel)
            if goal and goal > 0 then
                Print(string.format("Goal for %s +%d: %s", (MapNameForId and MapNameForId(mapId)) or "Dungeon", tonumber(keyLevel) or 0, FormatSeconds(goal)))
            else
                Print("No goal set for this dungeon/key")
            end
        elseif sub == "clear" then
            SetGoal(mapId, keyLevel, 0)
            Print("Goal cleared")
        else
            local goalSeconds = ParseTimeSeconds(sub)
            if not goalSeconds or goalSeconds <= 0 then
                Print("Invalid goal time. Use mm:ss (e.g. 12:34) or seconds")
                return
            end
            SetGoal(mapId, keyLevel, goalSeconds)
            Print(string.format("Goal set for %s +%d: %s", (MapNameForId and MapNameForId(mapId)) or "Dungeon", tonumber(keyLevel) or 0, FormatSeconds(goalSeconds)))
        end
    elseif cmd == "deaths" or cmd == "death" then
        local sub, arg = rest:match("^(%S+)%s*(.-)$")
        sub = sub or ""
        if sub == "loc" or sub == "location" or sub == "locations" then
            local n = tonumber(arg) or 10
            n = math.max(1, math.min(n, 50))
            Print("Death locations (latest " .. n .. "):")
            for i = 1, math.min(n, #runTracker.deathLocations) do
                local e = runTracker.deathLocations[i]
                local xy = ""
                if e.x and e.y and (e.x > 0 or e.y > 0) then
                    xy = string.format(" (%.0f%%, %.0f%%)", e.x * 100, e.y * 100)
                end
                local when = e.elapsed and FormatSeconds(e.elapsed) or "--:--"
                local zone = e.subzone and e.subzone ~= "" and e.subzone or (e.zone or "")
                Print(string.format("  %s %s - %s%s", when, e.name or "?", zone, xy))
            end
            if #runTracker.deathLocations == 0 then
                Print("  (no deaths recorded)")
            end
        else
            Print("Deaths by player (this run):")
            local rows = {}
            for name, count in pairs(runTracker.deathsByName) do
                table.insert(rows, { name = name, count = count })
            end
            table.sort(rows, function(a, b)
                if a.count == b.count then
                    return a.name < b.name
                end
                return a.count > b.count
            end)
            for i = 1, #rows do
                if rows[i].count and rows[i].count > 0 then
                    Print(string.format("  %s: %d", rows[i].name, rows[i].count))
                end
            end
            if #rows == 0 then
                Print("  (no deaths recorded)")
            end
        end
    elseif cmd == "protocol" then
        local dcAvail = rawget(_G, "DCAddonProtocol") and "YES" or "NO"
        local aioAvail = rawget(_G, "AIO") and "YES" or "NO"
        Print("Protocol status:")
        Print("  DCAddonProtocol: " .. dcAvail)
        Print("  AIO: " .. aioAvail)
        Print("  JSON mode: " .. (DCMythicPlusHUDDB.useDCProtocolJSON and "ON" or "OFF"))
        Print("  Trace: " .. (DCMythicPlusHUDDB.debugTrace and "ON" or "OFF"))
    elseif cmd == "trace" then
        local sub = rest and Trim(rest) or ""
        if sub == "on" then
            DCMythicPlusHUDDB.debugTrace = true
        elseif sub == "off" then
            DCMythicPlusHUDDB.debugTrace = false
        else
            DCMythicPlusHUDDB.debugTrace = not DCMythicPlusHUDDB.debugTrace
        end
        lastVisibilityTraceKey = nil
        Print("Trace " .. (DCMythicPlusHUDDB.debugTrace and "enabled" or "disabled"))
    elseif cmd == "vault" then
        if namespace.GreatVault then
            namespace.GreatVault:Toggle()
        else
            Print("Great Vault UI not loaded")
        end
    elseif cmd == "finder" or cmd == "gf" then
        if namespace.GroupFinder then
            namespace.GroupFinder:Toggle()
        else
            Print("Group Finder not loaded yet")
        end
    elseif cmd == "keystone" or cmd == "activation" then
        if namespace.KeystoneUI and type(namespace.KeystoneUI.Show) == "function" then
            namespace.KeystoneUI:Show({
                dungeon = "Test Dungeon",
                level = 15,
                timeLimit = 1800,
                affixes = {
                    { id = 1, name = "Fortified", description = "Non-boss enemies have more health and damage." },
                    { id = 3, name = "Bolstering", description = "Non-boss enemies buff nearby allies on death." },
                }
            }, true)
        else
            Print("Keystone UI not loaded")
        end
    elseif cmd == "help" then
        Print("Commands:")
        Print("  /dcm - Toggle HUD visibility")
        Print("  /dcm lock/unlock - Lock/unlock HUD position")
        Print("  /dcm show/hide - Show/hide HUD")
        Print("  /dcm refresh - Request latest data")
        Print("  /dcm reset - Reset position to center")
        Print("  /dcm json - Toggle JSON protocol mode")
        Print("  /dcm key - Show your keystone info")
        Print("  /dcm affixes - Show weekly affixes")
        Print("  /dcm best - Show your best runs")
        Print("  /dcm pb [all|clear] - Show/clear personal bests")
        Print("  /dcm goal [mm:ss|clear] - Set/clear goal for current dungeon/key")
        Print("  /dcm deaths - Show deaths by player")
        Print("  /dcm deaths loc [n] - Show last death locations")
        Print("  /dcm protocol - Show protocol status")
        Print("  /dcm trace [on|off] - Toggle temporary debug trace")
        Print("  /dcm finder - Open Group Finder")
        Print("  /dcgf - Open Group Finder (shortcut)")
    else
        ToggleVisibility()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("ZONE_CHANGED_NEW_AREA")
loader:SetScript("OnEvent", function(self, event)
    RefreshDCProtocol()
    EnsureMinimapMythicKeyBadgeHook()
    Trace("loader event=" .. tostring(event) .. " useDC=" .. tostring(namespace.useDCProtocol))

    -- Clear any stale activeState on login
    if event == "PLAYER_LOGIN" then
        local key = GetCharacterKey()
        if key and DCMythicPlusHUDDB.firstLoginByChar and not DCMythicPlusHUDDB.firstLoginByChar[key] then
            DCMythicPlusHUDDB.firstLoginByChar[key] = true
            namespace._suppressHudThisSession = true
        end
        namespace._vaultLoginNoticeShown = false
        activeState = nil
        UpdateMinimapMythicKeyBadge()
    end
    
    EnsureFrame()
    ApplySavedPosition()
    frame:Hide()  -- Hide on startup; only show when run is active
    if not TryRegisterHandlers() then
        BeginRetryLoop()
    else
        RequestServerSnapshot(event or "event")
        -- Also scan inventory for keystone on startup
        if ScanInventoryForKeystone then ScanInventoryForKeystone() end
    end
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateLocalRunTrackingFromInstance()
        if IsRunInProgress(activeState) then
            UpdateFrameFromState(activeState)
        else
            UpdateFrameFromLocalRun()
            SetFrameVisibility(false)
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        UpdateLocalRunTrackingFromInstance()
        if IsRunInProgress(activeState) then
            UpdateFrameFromState(activeState)
        else
            UpdateFrameFromLocalRun()
            SetFrameVisibility(false)
        end
    end
    UpdateMinimapMythicKeyBadge()
end)

-- Lightweight ticker: keep local run timer text updated.
local localTicker = CreateFrame("Frame")
localTicker.elapsed = 0
localTicker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.25 then
        return
    end
    self.elapsed = 0

    if activeState and IsRunInProgress(activeState) and timerText then
        timerText:SetText(BuildFullTimerLine(activeState))
    end

    UpdateLocalRunTrackingFromInstance()
    UpdateFrameFromLocalRun()
end)

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS (lightweight alternative to AIO)
-- =====================================================================

-- Settings toggle for JSON vs pipe-delimited
DCMythicPlusHUDDB.useDCProtocolJSON = (DCMythicPlusHUDDB.useDCProtocolJSON ~= false)  -- Prefer JSON by default

RefreshDCProtocol()
if DC then
    -- Helper to get value from table or raw args depending on format
    -- In JSON mode, DC protocol passes the decoded object directly to handlers
    local function HandleMPlusData(args, jsonFields, pipeFields)
        local data = args[1]
        
        -- If first arg is a table, it's already decoded JSON
        if type(data) == "table" then
            local result = {}
            for _, field in ipairs(jsonFields) do
                result[field] = data[field]
            end
            return result
        end
        
        -- Otherwise it's pipe-delimited args
        local result = {}
        for i, field in ipairs(pipeFields) do
            result[field] = args[i]
        end
        return result
    end

    -- SMSG_RUN_START (0x13) - Mythic+ run started
    DC:RegisterHandler("MPLUS", 0x13, function(...)
        local args = {...}
        local data
        
        if type(args[1]) == "table" then
            -- JSON format (DC protocol decodes before calling handler)
            data = args[1]
        else
            -- Pipe-delimited format
            data = {
                keyLevel = tonumber(args[1]),
                dungeonId = tonumber(args[2]),
                affixes = args[3],
                timeLimit = tonumber(args[4]),
            }
        end
        
        Print("Mythic+" .. (data.keyLevel or "?") .. " started!")
        activeState = {
            inProgress = true,
            keyLevel = data.keyLevel,
            mapId = data.dungeonId,
            dungeonName = data.dungeonName,
            timeLimit = data.timeLimit,
            elapsed = 0,
            deaths = 0,
            wipes = 0,
        }
        SetFrameVisibility(true)
        UpdateFrameFromState(activeState)
    end)
    
    -- SMSG_RUN_END (0x14) - Mythic+ run ended
    DC:RegisterHandler("MPLUS", 0x14, function(...)
        local args = {...}
        local data
        
        if type(args[1]) == "table" then
            data = args[1]
        else
            data = {
                success = (args[1] == "1" or args[1] == 1),
                timeElapsed = tonumber(args[2]),
                keyChange = tonumber(args[3]),
            }
        end
        
        if IsFlagSet(data.success) then
            Print("Run completed! Key upgraded by " .. (data.keyChange or 0))
            if data.score then
                Print("Score: " .. data.score)
            end
            ShowRunResultPopup(data, true)
        else
            Print("Run failed.")
            ShowRunResultPopup(data, false)
        end

        -- Event-driven Vault refresh: runs affect Vault progress
        if namespace.GreatVault and namespace.GreatVault.IsShown and namespace.GreatVault:IsShown() then
            if namespace.RequestVaultInfo then
                namespace.RequestVaultInfo()
            end
        end
        activeState = nil
        ShowIdleState()
    end)
    
    -- SMSG_TIMER_UPDATE (0x15) - Timer sync / HUD update
    DC:RegisterHandler("MPLUS", 0x15, function(...)
        HandleTimerUpdatePayload(...)
    end)
    namespace._dcRuntimeHudHandlerBound = true
    
    -- SMSG_OBJECTIVE_UPDATE (0x16) - Boss/enemy count update
    DC:RegisterHandler("MPLUS", 0x16, function(...)
        local args = {...}
        local bossesKilled, bossesTotal, enemyCount, enemyRequired
        
        if type(args[1]) == "table" then
            local json = args[1]
            bossesKilled = json.bossesKilled
            bossesTotal = json.bossesTotal
            enemyCount = json.enemyCount
            enemyRequired = json.enemyRequired
        else
            bossesKilled = tonumber(args[1])
            bossesTotal = tonumber(args[2])
            enemyCount = tonumber(args[3])
            enemyRequired = tonumber(args[4])
        end
        
        if activeState then
            activeState.bossesKilled = bossesKilled
            activeState.bossesTotal = bossesTotal
            activeState.enemyCount = enemyCount
            activeState.enemyRequired = enemyRequired
            UpdateFrameFromState(activeState)
        end
    end)
    
    -- SMSG_KEY_INFO (0x10) - Key info response
    DC:RegisterHandler("MPLUS", 0x10, function(...)
        local args = {...}
        local data = {}
        
        if type(args[1]) == "table" then
            local json = args[1]
            data.hasKeystone = json.hasKey or false
            data.keystoneLevel = json.level or json.keyLevel or 0
            data.keystoneDungeonName = json.dungeonName or json.dungeon
            data.depleted = json.depleted
            if data.hasKeystone then
                -- Print("Your key: +" .. (data.keystoneLevel or "?") .. " " .. (data.keystoneDungeonName or ""))
                if data.depleted then
                    -- Print("(Depleted)")
                end
            else
                -- Print("No keystone in inventory")
            end
        else
            -- Pipe-delimited format
            local hasKey, dungeonId, mapName, keyLevel, depleted = args[1], args[2], args[3], args[4], args[5]
            if hasKey == "1" or hasKey == 1 then
                data.hasKeystone = true
                data.keystoneLevel = tonumber(keyLevel) or 0
                data.keystoneDungeonName = mapName
                data.depleted = (depleted == "1" or depleted == 1)
                -- Print("Your key: +" .. (data.keystoneLevel or "?") .. " " .. (data.keystoneDungeonName or ""))
            else
                data.hasKeystone = false
                -- Print("No keystone in inventory")
            end
        end
        -- Store latest server-provided keystone data and update UI
        namespace.serverKeystone = data
        if namespace.GroupFinder and type(namespace.GroupFinder.UpdateKeystoneDisplay) == "function" then
            namespace.GroupFinder:UpdateKeystoneDisplay(data)
        end
    end)
    
    -- SMSG_AFFIXES (0x11) - Current week's affixes
    DC:RegisterHandler("MPLUS", 0x11, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            local json = args[1]
            local weekNum = json.weekNumber or 0
            Print("Week " .. weekNum .. " affixes:")
            -- Parse affixes array if present
            local affixesToCache = {}
            if json.affixes and type(json.affixes) == "table" then
                local affixNames = {}
                for _, affix in ipairs(json.affixes) do
                    local normalizedAffix =
                        NormalizeMythicPlusAffixPayload(affix)

                    if type(normalizedAffix) == "table"
                        and normalizedAffix.name then
                        table.insert(affixNames, normalizedAffix.name)
                        table.insert(affixesToCache, normalizedAffix)
                    elseif type(affix) == "string" then
                        table.insert(affixNames, affix)
                        table.insert(affixesToCache, { name = affix })
                    end
                end
                if #affixNames > 0 then
                    Print("  " .. table.concat(affixNames, ", "))
                end
            end
            
            -- Persist to SavedVariables
            if DCMythicPlusHUDDB and DCMythicPlusHUDDB.cache then
                DCMythicPlusHUDDB.cache.affixes = affixesToCache
                DCMythicPlusHUDDB.cache.affixesTime = time()
                DCMythicPlusHUDDB.cache.affixesWeek = weekNum
            end
        else
            -- Pipe-delimited format: id:name:desc;id:name:desc;...
            local affixData = args[1]
            if affixData then
                local affixNames = {}
                for entry in tostring(affixData):gmatch('[^;]+') do
                    local name = entry:match(':([^:]+):')
                    if name then
                        table.insert(affixNames, name)
                    end
                end
                if #affixNames > 0 then
                    Print("This week's affixes: " .. table.concat(affixNames, ", "))
                end
            end
        end
    end)
    
    -- SMSG_BEST_RUNS (0x12) - Player's best runs
    DC:RegisterHandler("MPLUS", 0x12, function(...)
        local args = {...}
        
        if type(args[1]) == "table" then
            local json = args[1]
            local count = json.count or 0
            Print("Best runs (" .. count .. "):")
            -- Parse runs array if present
            if json.runs and type(json.runs) == "table" then
                for idx, run in ipairs(json.runs) do
                    if type(run) == "table" then
                        local name = run.dungeonName or ("Dungeon " .. (run.dungeonId or "?"))
                        local level = run.level or "?"
                        local timeStr = run.time and FormatSeconds(run.time) or "?"
                        Print("  " .. idx .. ". " .. name .. " +" .. level .. " (" .. timeStr .. ")")
                    end
                end
            end
        else
            -- Pipe-delimited format: dungeonId:level:time:deaths:season;...
            local runData = args[1]
            if runData then
                Print("Best runs:")
                local idx = 1
                for entry in tostring(runData):gmatch('[^;]+') do
                    local parts = {}
                    for part in entry:gmatch('[^:]+') do
                        table.insert(parts, part)
                    end
                    if #parts >= 3 then
                        local dungeonId, level, time = parts[1], parts[2], parts[3]
                        local timeStr = FormatSeconds(tonumber(time))
                        Print("  " .. idx .. ". Dungeon " .. dungeonId .. " +" .. level .. " (" .. timeStr .. ")")
                        idx = idx + 1
                    end
                end
            end
        end
    end)

    -- SMSG_VAULT_INFO (0x18) - Great Vault Data
    DC:RegisterHandler("MPLUS", 0x18, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GreatVault then
                namespace.GreatVault:Update(data)
            end
        end
    end)

    -- SMSG_VAULT_REWARD_CLAIMED (0x19) - Reward Claimed Confirmation
    DC:RegisterHandler("MPLUS", 0x19, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if data.success then
                Print("Reward claimed successfully!")
                -- Refresh Vault state after claim
                if namespace.RequestVaultInfo then
                    namespace.RequestVaultInfo()
                end
                if namespace.GreatVault and namespace.GreatVault.Hide then
                    namespace.GreatVault:Hide()
                end
            else
                Print("Failed to claim reward.")
            end
        end
    end)

    -- SMSG_VAULT_AVAILABLE (0x1A) - Login reminder for unclaimed rewards
    DC:RegisterHandler("MPLUS", 0x1A, function(...)
        local args = {...}
        if type(args[1]) ~= "table" then
            return
        end

        local data = args[1]
        if not IsFlagSet(data.available) then
            return
        end

        if namespace._vaultLoginNoticeShown then
            return
        end
        namespace._vaultLoginNoticeShown = true

        local unlockedCount = tonumber(data.unlockedCount or 0) or 0
        local claimWindowStart = tonumber(data.claimWindowStart or data.claimWeekStart or 0) or 0
        local claimWindowEnd = tonumber(data.claimWindowEnd or data.weeklyResetAt or 0) or 0
        local weeklyResetAt = tonumber(data.weeklyResetAt or claimWindowEnd or 0) or 0
        local nextWeeklyResetAt = tonumber(data.nextWeeklyResetAt or 0) or 0

        local rewardLine
        if unlockedCount > 1 then
            rewardLine = string.format("Great Vault rewards available (%d choices)!", unlockedCount)
        else
            rewardLine = "Great Vault reward available!"
        end

        local claimLine = nil
        if claimWindowStart > 0 and claimWindowEnd > 0 then
            claimLine = string.format(
                "Claim window: %s -> %s",
                FormatUnixTimestampLocal(claimWindowStart),
                FormatUnixTimestampLocal(claimWindowEnd)
            )
        end

        local resetLine = nil
        if weeklyResetAt > 0 then
            resetLine = "Weekly reset: " .. FormatUnixTimestampLocal(weeklyResetAt)
        end

        local nextResetLine = nil
        if nextWeeklyResetAt > 0 then
            nextResetLine = "Next reset: " .. FormatUnixTimestampLocal(nextWeeklyResetAt)
        end

        Print(rewardLine .. " Use /dcm vault.")
        if claimLine then
            Print(claimLine)
        end
        if resetLine then
            Print(resetLine)
        end

        local toastLines = {
            "Use /dcm vault to open rewards.",
        }
        if claimLine then
            table.insert(toastLines, claimLine)
        end
        if resetLine then
            table.insert(toastLines, resetLine)
        end
        if nextResetLine then
            table.insert(toastLines, nextResetLine)
        end

        ShowVaultToast(rewardLine, table.concat(toastLines, "\n"))
    end)
    
    -- =========================================================================
    -- Keystone Activation Integration (integrated KeystoneUI)
    -- =========================================================================
    
    -- SMSG_KEYSTONE_ACTIVATE (0x50) - Server requesting keystone activation UI
    DC:RegisterHandler("MPLUS", 0x50, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            -- Use integrated KeystoneUI
            if namespace.KeystoneUI then
                namespace.KeystoneUI:OnKeystoneReadyCheck(data)
            else
                Print("Keystone activation requested for: " .. (data.dungeonName or "Unknown") .. " +" .. (data.level or "?"))
            end
        end
    end)
    
    -- SMSG_KEYSTONE_STATUS (0x51) - Player ready state update
    DC:RegisterHandler("MPLUS", 0x51, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.KeystoneUI then
                namespace.KeystoneUI:OnPlayerReadyUpdate(data)
            end
        end
    end)
    
    -- SMSG_KEYSTONE_COUNTDOWN (0x52) - Countdown update
    DC:RegisterHandler("MPLUS", 0x52, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.KeystoneUI then
                namespace.KeystoneUI:OnCountdownStart(data)
            end
        end
    end)
    
    -- SMSG_KEYSTONE_CANCEL (0x53) - Activation cancelled
    DC:RegisterHandler("MPLUS", 0x53, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.KeystoneUI then
                namespace.KeystoneUI:OnActivationCancelled(data)
            else
                Print("Keystone activation cancelled: " .. (data.reason or "Unknown reason"))
            end
        end
    end)
    
    -- =========================================================================
    -- Group Finder Protocol Handlers
    -- =========================================================================
    
    -- SMSG_LIVE_RUNS (0x20) - List of spectatable runs
    DC:RegisterHandler("MPLUS", 0x20, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:PopulateLiveRuns(data.runs or {})
            end
        end
    end)
    
    -- SMSG_SPECTATOR_UPDATE (0x24) - Update spectator HUD
    DC:RegisterHandler("MPLUS", 0x24, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateSpectatorHUD(data)
            end
        end
    end)
    
    -- =========================================================================
    -- GRPF (Group Finder) Protocol Handlers
    -- =========================================================================
    
    local GFOpcodes = DC.GroupFinderOpcodes or {}

    local function PrintGroupFinder(msg, important)
        if namespace.GroupFinder then
            if important and namespace.GroupFinder.PrintImportant then
                namespace.GroupFinder:PrintImportant(msg)
                return
            end

            if namespace.GroupFinder.Print then
                namespace.GroupFinder:Print(msg)
                return
            end
        end

        Print("Group Finder: " .. tostring(msg or ""))
    end

    -- SMSG_SCHEDULED_EVENTS (0x72) - List of scheduled events
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SCHEDULED_EVENTS or 0x72, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local events = data.events or {}
            if type(events) == "string" and type(DC.DecodeJSON) == "function" then
                events = DC:DecodeJSON(events) or {}
            end
            if namespace.GroupFinder then
                namespace.GroupFinder:PopulateScheduledEvents(events)
            end
        end
    end)
    
    -- SMSG_LISTING_CREATED (0x30) - Confirm listing created
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_LISTING_CREATED or 0x30, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            PrintGroupFinder("Group listing created! ID: " .. (data.listingId or "?"), false)
            if namespace.GroupFinder then
                namespace.GroupFinder:OnListingCreated(data)
            end
        end
    end)
    
    -- SMSG_SEARCH_RESULTS (0x31) - Search results
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SEARCH_RESULTS or 0x31, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local groups = data.groups or {}
            if type(groups) == "string" and type(DC.DecodeJSON) == "function" then
                groups = DC:DecodeJSON(groups) or {}
            end

            local category = data.category
            if namespace.GroupFinder then
                if category == "raid" and namespace.GroupFinder.PopulateRaidGroups then
                    namespace.GroupFinder:PopulateRaidGroups(groups)
                elseif (category == "world" or category == "other" or category == "quest") and namespace.GroupFinder.UpdateWorldGroups then
                    namespace.GroupFinder:UpdateWorldGroups(groups, category)
                else
                    namespace.GroupFinder:PopulateMythicGroups(groups)
                end
            end
        end
    end)
    
    -- SMSG_APPLICATION_STATUS (0x32) - Application accepted/declined
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_APPLICATION_STATUS or 0x32, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local status = data.status or "unknown"
            if status == "accepted" then
                PrintGroupFinder("|cff00ff00Your application was accepted!|r", true)
            elseif status == "declined" or status == "rejected" then
                PrintGroupFinder("|cffff0000Your application was declined.|r", true)
            elseif status == "cancelled" then
                PrintGroupFinder("|cffffff00Your application was withdrawn or the listing closed.|r", true)
            else
                PrintGroupFinder("Application status: " .. status, false)
            end

            if namespace.GroupFinder and namespace.GroupFinder.OnApplicationStatusChanged then
                namespace.GroupFinder:OnApplicationStatusChanged(data)
            end
        end
    end)
    
    -- SMSG_NEW_APPLICATION (0x33) - Leader: new applicant
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_NEW_APPLICATION or 0x33, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            PrintGroupFinder("|cffffff00New applicant:|r " .. (data.playerName or "Unknown") .. " (" .. (data.role or "?") .. ")", true)
            if namespace.GroupFinder and namespace.GroupFinder.OnNewApplication then
                namespace.GroupFinder:OnNewApplication(data)
            end
        end
    end)
    
    -- SMSG_GROUP_UPDATED (0x34) - Group composition changed
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_GROUP_UPDATED or 0x34, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:OnGroupUpdated(data)
            end
        end
    end)

    -- SMSG_MY_APPLICATIONS (0x35) - My active applications
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_MY_APPLICATIONS or 0x35, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local applications = data.applications or {}
            if type(applications) == "string" and type(DC.DecodeJSON) == "function" then
                applications = DC:DecodeJSON(applications) or {}
            end

            if namespace.GroupFinder and namespace.GroupFinder.UpdateMyApplications then
                namespace.GroupFinder:UpdateMyApplications(applications)
            end
        end
    end)
    
    -- SMSG_KEYSTONE_INFO (0x40) - Player's keystone data
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_KEYSTONE_INFO or 0x40, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateKeystoneDisplay(data)
            end
        end
    end)
    
    -- SMSG_DUNGEON_LIST (0x42) - M+ dungeon list from server
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_DUNGEON_LIST or 0x42, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            -- Parse the dungeons JSON array
            local dungeons = data.dungeons
            if type(dungeons) == "string" then
                -- Need to parse JSON string
                dungeons = DC:DecodeJSON(dungeons) or {}
            end
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateDungeonList(dungeons)
            end
        end
    end)
    
    -- SMSG_RAID_LIST (0x43) - Raid list from server
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_RAID_LIST or 0x43, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            -- Parse the raids JSON array
            local raids = data.raids
            if type(raids) == "string" then
                -- Need to parse JSON string
                raids = DC:DecodeJSON(raids) or {}
            end
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateRaidList(raids)
            end
        end
    end)

    -- SMSG_SYSTEM_INFO (0x44) - System config (rewards, etc)
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SYSTEM_INFO or 0x44, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateSystemInfo(data)
            end
        end
    end)
    
    -- SMSG_SPECTATE_DATA (0x45) - Spectator live data
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SPECTATE_DATA or 0x45, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateSpectatorHUD(data)
            end
        end
    end)
    
    -- SMSG_SPECTATE_LIST (0x47) - Available runs to spectate
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SPECTATE_LIST or 0x47, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:PopulateLiveRuns(data.runs or {})
            end
        end
    end)

    -- SMSG_SPECTATE_STARTED (0x48) - Spectating started successfully
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SPECTATE_STARTED or 0x48, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            PrintGroupFinder(data.message or "Now spectating the run", false)
            if namespace.GroupFinder and namespace.GroupFinder.BeginSpectateSession then
                namespace.GroupFinder:BeginSpectateSession(data)
            end
        end
    end)

    -- SMSG_SPECTATE_ENDED (0x49) - Spectating ended or was cancelled
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_SPECTATE_ENDED or 0x49, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            PrintGroupFinder(data.message or "Stopped spectating", false)
            if namespace.GroupFinder and namespace.GroupFinder.EndSpectateSession then
                namespace.GroupFinder:EndSpectateSession(data)
            end
        end
    end)

    -- SMSG_OPEN_UI (0x50) - Open Group Finder UI from server
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_OPEN_UI or 0x50, function(...)
        local args = {...}
        if type(args[1]) == "table" or args[1] == nil then
            if namespace.GroupFinder and namespace.GroupFinder.Show then
                namespace.GroupFinder:Show()
            end
        end
    end)

    -- SMSG_ERROR (0x5F) - Group Finder error response
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_ERROR or 0x5F, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local err = data.error or data.message or "Unknown Group Finder error"
            PrintGroupFinder("|cffff4444" .. err .. "|r", true)

            if namespace.GroupFinder and namespace.GroupFinder.MythicCreatePanel and namespace.GroupFinder.MythicCreatePanel.statusText then
                namespace.GroupFinder.MythicCreatePanel.statusText:SetText("|cffff4444Group Finder: " .. err .. "|r")
            end
        end
    end)
    
    -- SMSG_DIFFICULTY_CHANGED (0x51) - Confirm difficulty changed
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_DIFFICULTY_CHANGED or 0x51, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local diffName = data.difficultyName or "Unknown"
            PrintGroupFinder("Difficulty changed to: |cff32c4ff" .. diffName .. "|r", false)
            if namespace.GroupFinder then
                namespace.GroupFinder:UpdateDifficultyDisplay(data.difficultyId, diffName)
            end
        end
    end)
    
    -- Helper functions exposed on namespace for slash commands and external use
    namespace.RequestKeyInfo = function()
        if DC then
            DC:Send("MPLUS", 0x01)  -- CMSG_GET_KEY_INFO
        end
    end
    
    namespace.RequestAffixes = function()
        if DC then
            DC:Send("MPLUS", 0x02)  -- CMSG_GET_AFFIXES
        end
    end
    
    namespace.RequestBestRuns = function()
        if DC then
            DC:Send("MPLUS", 0x03)  -- CMSG_GET_BEST_RUNS
        end
    end

    namespace.RequestVaultInfo = function()
        if DC then
            DC:Send("MPLUS", 0x06)  -- CMSG_GET_VAULT_INFO
        end
    end

    namespace.ClaimVaultReward = function(slotIndex, itemId)
        if DC then
            DC:Send("MPLUS", 0x07, { slot = slotIndex, item = itemId })  -- CMSG_CLAIM_VAULT_REWARD
        end
    end
    
    -- Respond to keystone activation
    namespace.RespondToKeystone = function(accepted)
        if DC then
            if type(DC.Request) == "function" then
                DC:Request("MPLUS", 0x08, { accepted = accepted })  -- CMSG_KEYSTONE_RESPONSE
            else
                DC:Send("MPLUS", 0x08, { accepted = accepted })  -- CMSG_KEYSTONE_RESPONSE
            end
        end
    end

    namespace.CancelPendingKeystoneActivation = function()
        if DC then
            if type(DC.Request) == "function" then
                DC:Request("MPLUS", 0x09, { cancel = true })  -- CMSG_KEYSTONE_CANCEL
            else
                DC:Send("MPLUS", 0x09, { cancel = true })  -- CMSG_KEYSTONE_CANCEL
            end
        end
    end
    
    -- Test connection by sending all requests
    namespace.TestConnection = function()
        if not DC then
            Print("DCAddonProtocol not available")
            return
        end
        Print("Testing DC Protocol connection...")
        DC:Send("MPLUS", 0x01)  -- Key info
        DC:Send("MPLUS", 0x02)  -- Affixes
        DC:Send("MPLUS", 0x03)  -- Best runs
    end
    
    Print("DCAddonProtocol v" .. (DC.VERSION or "?") .. " handlers registered")
end

-- =====================================================================
-- Blizzard LFG integration (add Mythic+ button to default Dungeon Finder)
-- =====================================================================

do
    if not namespace._dcMplusLfgButtonInstallerStarted then
        namespace._dcMplusLfgButtonInstallerStarted = true

        local function GetBlizzardLFGFrame()
            return _G.LFDParentFrame or _G.LookingForGroupFrame or _G.LFGParentFrame
        end

        local function InstallButton()
            if namespace._dcMplusLfgButtonInstalled then
                return true
            end

            local parent = GetBlizzardLFGFrame()
            if not parent then
                return false
            end

            local btn = _G.DCMythicPlus_LFG_MythicButton
            if not btn then
                btn = CreateFrame("Button", "DCMythicPlus_LFG_MythicButton", parent, "UIPanelButtonTemplate")
            end

            btn:SetSize(110, 22)
            btn:SetText("Mythic+")
            btn:ClearAllPoints()

            -- Anchor near the close button to avoid overlapping the bottom action buttons
            local closeBtn = parent.CloseButton
                or (parent.GetName and _G[parent:GetName() .. "CloseButton"])
                or _G.LFDParentFrameCloseButton
                or _G.LookingForGroupFrameCloseButton
                or _G.LFGParentFrameCloseButton

            if closeBtn and closeBtn.GetObjectType then
                btn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -6, -2)
            else
                btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -52, -28)
            end

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Mythic+ Dungeon Finder", 1, 1, 1)
                GameTooltip:AddLine("Open the Mythic+ Group Finder UI", 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btn:SetScript("OnClick", function()
                if namespace.GroupFinder and namespace.GroupFinder.Show then
                    namespace.GroupFinder:Show()
                elseif SlashCmdList and SlashCmdList["DCGF"] then
                    SlashCmdList["DCGF"]("")
                end
            end)

            namespace._dcMplusLfgButtonInstalled = true
            return true
        end

        local function TryInstallWithRetry(attempt)
            attempt = (attempt or 0) + 1
            if InstallButton() then
                return
            end
            if attempt < 20 then
                C_Timer.After(1.0, function() TryInstallWithRetry(attempt) end)
            end
        end

        local installerFrame = CreateFrame("Frame")
        installerFrame:RegisterEvent("PLAYER_LOGIN")
        installerFrame:RegisterEvent("ADDON_LOADED")
        installerFrame:SetScript("OnEvent", function()
            C_Timer.After(0.2, function() TryInstallWithRetry(0) end)
        end)
    end
end

-- Fallback definitions if DC is not available
if not namespace.RequestVaultInfo then
    namespace.RequestVaultInfo = function()
        print("DC-MythicPlus: DCAddonProtocol not loaded, cannot request vault info.")
    end
end

if not namespace.ClaimVaultReward then
    namespace.ClaimVaultReward = function()
        print("DC-MythicPlus: DCAddonProtocol not loaded, cannot claim reward.")
    end
end

