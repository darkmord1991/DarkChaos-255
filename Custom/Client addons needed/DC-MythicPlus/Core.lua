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
local lastPayload
local lastRequestTime = 0
local REQUEST_COOLDOWN = 1.0

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff32c4ffMythic+ HUD:|r " .. (msg or ""))
    end
end

local function Trim(str)
    return (str and str:match("^%s*(.-)%s*$")) or str
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

local function BuildAffixLine(list)
    if type(list) ~= "table" or #list == 0 then
        return "Affixes: none"
    end
    local names = {}
    for i = 1, #list do
        names[#names + 1] = SafelyGetSpellName(list[i])
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
    if data.failed == 1 then
        return "Status: |cffff5050Failed|r"
    end
    if data.completed == 1 then
        return "Status: |cff50ff7aCompleted|r"
    end
    if data.countdown and data.countdown > 0 then
        return string.format("Status: |cffffff78Countdown %ss|r", data.countdown)
    end
    return "Status: |cff78beffIn progress|r"
end

local function EnsureFrame()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "DCMythicPlusHUDFrame", UIParent)
    frame:SetSize(280, 170)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.85)
    end

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
    headerText:SetPoint("TOP", frame, "TOP", 0, -12)
    headerText:SetText("Mythic+ HUD")

    timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timerText:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
    timerText:SetText("Timer: --")

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusText:SetPoint("TOPLEFT", timerText, "BOTTOMLEFT", 0, -6)
    statusText:SetText("Status: Waiting")

    deathText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    deathText:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -6)
    deathText:SetText("Deaths: 0 | Wipes: 0")

    playerText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    playerText:SetPoint("TOPLEFT", deathText, "BOTTOMLEFT", 0, -6)
    playerText:SetText("Players: 0")

    bossText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bossText:SetPoint("TOPLEFT", playerText, "BOTTOMLEFT", 0, -6)
    bossText:SetText("Bosses: 0")

    enemyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enemyText:SetPoint("TOPLEFT", bossText, "BOTTOMLEFT", 0, -6)
    enemyText:SetText("Enemies: 0")

    affixText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    affixText:SetPoint("TOPLEFT", enemyText, "BOTTOMLEFT", 0, -6)
    affixText:SetWidth(256)
    affixText:SetJustifyH("LEFT")
    affixText:SetText("Affixes: none")

    countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countdownText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    countdownText:SetText("")

    reasonText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reasonText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
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
    -- Ensure we are in an instance and check for mythic or mythic+ difficulty
    if not activeState or not activeState.inProgress then
        return false
    end
    -- If the state indicates a key level, it's a mythic+ run
    if activeState.keyLevel and tonumber(activeState.keyLevel) and tonumber(activeState.keyLevel) > 0 then
        -- Still ensure player is actually inside an instance
        if type(IsInInstance) == "function" then
            local inInstance = select(1, IsInInstance())
            if inInstance then return true end
        end
        return false
    end
    -- Fallback: check instance difficulty (requires GetInstanceInfo)
    if type(GetInstanceInfo) == "function" and type(IsInInstance) == "function" then
        local inInstance = select(1, IsInInstance())
        if not inInstance then return false end
        local _, instanceType, difficultyID, difficultyName = GetInstanceInfo()
        -- First, check difficultyName for 'mythic' (supports localized names)
        if difficultyName and type(difficultyName) == "string" and string.find(string.lower(difficultyName), "mythic") then
            return true
        end
        -- A broader set of difficulty IDs that have been used across expansions for mythic/mythic+ modes
        local mythicDifficultyIds = {
            [8] = true,  -- some expansions
            [16] = true, -- mythic
            [23] = true, -- mythic+ on certain patches
            [15] = true, -- possible mythic mapping
            [14] = true, -- possible mythic mapping
            [6] = true,  -- trial / other
            [24] = true, -- miscellaneous
        }
        if difficultyID and mythicDifficultyIds[difficultyID] then
            return true
        end
        -- As a last resort, assume party-type instances are dungeons; if activeState indicates a run
        if instanceType and instanceType == "party" and activeState and activeState.inProgress then
            return true
        end
    end
    return false
end

local function SetFrameVisibility(shouldShow)
    if not frame then
        return
    end
    -- Only show if explicitly requested AND user hasn't hidden it AND a run is actually active
    -- AND the player is in a mythic or mythic+ dungeon instance
    if shouldShow and not DCMythicPlusHUDDB.hidden and IsInMythicOrMythicPlusInstance() then
        frame:Show()
    else
        frame:Hide()
    end
end

-- =====================================================================
-- Inventory Keystone Detection (fallback)
-- =====================================================================
namespace.inventoryKeystone = namespace.inventoryKeystone or nil

local function KeystoneEqual(a, b)
    if a == b then
        return true
    end
    if (not a) ~= (not b) then
        return false
    end
    return (a.hasKey == b.hasKey)
        and (a.level == b.level)
        and (a.dungeonName == b.dungeonName)
        and (a.itemLink == b.itemLink)
        and (a.bag == b.bag)
        and (a.slot == b.slot)
end

local function ScanInventoryForKeystone()
    -- Scan all bags (0-4) for keystone-like items; try to parse level/dungeon
    local found = nil
    -- Determine ID mapping from central DC addon protocol if available (fallback to small hardcoded set)
    local DCproto = rawget(_G, "DCAddonProtocol")
    local DCCentral = rawget(_G, "DCCentral")
    local KEYSTONE_IDS = (DCCentral and DCCentral.KEYSTONE_ITEM_IDS) or (DCproto and DCproto.KEYSTONE_ITEM_IDS) or { [60000] = true, [60001] = true, [60002] = true }
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemId = GetContainerItemID(bag, slot)
            if itemId then
                local itemName, itemLink = GetItemInfo(itemId)
                -- Fast path: check known keystone item IDs
                local isKeystoneId = KEYSTONE_IDS[itemId]
                if isKeystoneId or (itemName and string.find(itemName, "Keystone")) then
                    -- Attempt to extract level
                    local level = tonumber((itemName and (string.match(itemName, "%+(%d+)") or string.match(itemName, "Level (%d+)"))) or nil) or nil
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
                            local text = line:GetText()
                            if text then
                                local lvl = string.match(text, "Level:?%s*(%d+)") or string.match(text, "%+(%d+)")
                                if lvl then tooltipLevel = tonumber(lvl) end
                                local dng = string.match(text, "Dungeon:?%s*(.+)") or string.match(text, "Instance:?%s*(.+)")
                                if dng then tooltipDungeon = dng end
                            end
                        end
                    end
                    if not level and tooltipLevel then level = tooltipLevel end
                    if not dungeon and tooltipDungeon then dungeon = tooltipDungeon end
                    found = {
                        hasKey = true,
                        level = level or 0,
                        dungeonName = dungeon or "Unknown",
                        itemLink = itemLink,
                        bag = bag,
                        slot = slot,
                    }
                    break
                end
            end
        end
        if found then break end
    end

    local changed = not KeystoneEqual(namespace.inventoryKeystone, found)
    namespace.inventoryKeystone = found
    if changed then
        if found then
            Print("Inventory keystone detected: +" .. (found.level or 0) .. " " .. (found.dungeonName or "Unknown"))
        else
            Print("No inventory keystone detected")
        end
    end
    -- If GroupFinder UI exists, update the keystone panel display immediately
    if namespace.GroupFinder and type(namespace.GroupFinder.UpdateKeystoneDisplay) == "function" then
        namespace.GroupFinder:UpdateKeystoneDisplay(found or {})
    end
    return found
end

local scanFrame = CreateFrame("Frame")
scanFrame:RegisterEvent("BAG_UPDATE")
scanFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
scanFrame:SetScript("OnEvent", function(self, event, ...)
    ScanInventoryForKeystone()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Request canonical keystone mapping from server to ensure client knows IDs
        if DC and DC.MythicPlus and type(DC.MythicPlus.GetKeystoneList) == 'function' then
            DC.MythicPlus.GetKeystoneList()
        end
    end
end)

-- Expose scanner function on namespace for other modules to call
namespace.ScanInventoryForKeystone = ScanInventoryForKeystone


local function ShowIdleState()
    local f = EnsureFrame()
    if not f then
        return
    end
    activeState = nil
    lastPayload = nil
    headerText:SetText("Mythic+ HUD")
    timerText:SetText("Timer: --")
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
end

local function UpdateCountdown(data)
    if not countdownText then
        return
    end
    if data.countdown and data.countdown > 0 then
        countdownText:SetText(string.format("Countdown: %ss", data.countdown))
    else
        countdownText:SetText("")
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
    -- Try DCAddonProtocol first (new C++ backend)
    if namespace.useDCProtocol and DC and DC.MythicPlus and DC.MythicPlus.RequestHUD then
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
        DC.MythicPlus.RequestHUD(reason or "client")
        return
    end
    
    -- Fallback to AIO (old Lua backend)
    if not AIO or type(AIO.Handle) ~= "function" then
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
    local ok, err = pcall(function()
        AIO.Handle(SERVER_ADDON_NAME, "RequestHud", reason or "client")
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

local function UpdateFrameFromState(data)
    activeState = data
    local f = EnsureFrame()
    ApplySavedPosition()

    local mapName = data.mapName or MapNameForId(data.map)
    local keystone = data.keystone or 0
    headerText:SetText(string.format("%s |cffffaa33+%d|r", mapName, keystone))

    local elapsed = FormatSeconds(data.elapsed)
    local remaining = FormatSeconds(data.remaining)
    local timerLine = string.format("Timer: %s elapsed | %s left", elapsed, remaining)
    if data.bestTime and data.bestTime > 0 then
        timerLine = timerLine .. string.format(" | Best: %s", FormatSeconds(data.bestTime))
    end
    timerText:SetText(timerLine)

    statusText:SetText(BuildStatus(data))

    deathText:SetText(string.format("Deaths: %d | Wipes: %d", data.deaths or 0, data.wipes or 0))

    local playerCount = CountTableValues(data.participants)
    playerText:SetText(string.format("Players: %d", playerCount))

    bossText:SetText(BuildBossLine(data.bossesKilled or 0, data.bossesTotal or 0))

    if enemyText then
        enemyText:SetText(string.format("Enemies: %d", data.enemiesKilled or 0))
    end

    affixText:SetText(BuildAffixLine(data.affixes))

    UpdateCountdown(data)
    UpdateReason(data.reason)

    lastPayload = data
    -- Only show frame if the data indicates an active run
    if data and data.inProgress then
        SetFrameVisibility(true)
    else
        SetFrameVisibility(false)
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

local retryTicker
local function TryRegisterHandlers()
    if namespace.handlersRegistered then
        return true
    end
    if not AIO or type(AIO.AddHandlers) ~= "function" then
        return false
    end
    local ok, handlers = pcall(function()
        return AIO.AddHandlers(SERVER_ADDON_NAME, {})
    end)
    if not ok or type(handlers) ~= "table" then
        return false
    end
    handlers[SERVER_MESSAGE_KEY] = function(_, payload)
        HandleIncomingPayload(payload)
    end
    namespace.handlersRegistered = true
    if retryTicker then
        retryTicker:SetScript("OnUpdate", nil)
    end
    Print("AIO handler ready")
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
        Print("HUD shown.")
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
    msg = Trim((msg or "")):lower()
    if msg == "lock" then
        ToggleLock()
    elseif msg == "unlock" then
        DCMythicPlusHUDDB.locked = false
        Print("Frame unlocked")
    elseif msg == "show" then
        DCMythicPlusHUDDB.hidden = false
        -- Only show if a run is active
        if IsInMythicOrMythicPlusInstance() then
            SetFrameVisibility(true)
            Print("HUD shown")
        else
            Print("HUD will show when you enter a Mythic/Mythic+ dungeon with an active run")
        end
        RequestServerSnapshot("slash")
    elseif msg == "hide" then
        DCMythicPlusHUDDB.hidden = true
        SetFrameVisibility(false)
        Print("HUD hidden")
    elseif msg == "refresh" or msg == "sync" then
        RequestServerSnapshot("slash")
        Print("Requested latest HUD snapshot")
    elseif msg == "reset" then
        DCMythicPlusHUDDB.position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 }
        ApplySavedPosition()
        Print("HUD position reset")
    elseif msg == "json" then
        -- Toggle JSON mode for DC protocol
        DCMythicPlusHUDDB.useDCProtocolJSON = not (DCMythicPlusHUDDB.useDCProtocolJSON == true)
        Print("DC Protocol JSON mode: " .. (DCMythicPlusHUDDB.useDCProtocolJSON and "ON" or "OFF"))
    elseif msg == "key" then
        -- Request keystone info via DC protocol
        if namespace.RequestKeyInfo then
            namespace.RequestKeyInfo()
            Print("Requesting keystone info...")
        else
            Print("DC protocol not available")
        end
    elseif msg == "affixes" then
        -- Request affixes via DC protocol
        if namespace.RequestAffixes then
            namespace.RequestAffixes()
            Print("Requesting weekly affixes...")
        else
            Print("DC protocol not available")
        end
    elseif msg == "best" or msg == "runs" then
        -- Request best runs via DC protocol
        if namespace.RequestBestRuns then
            namespace.RequestBestRuns()
            Print("Requesting best runs...")
        else
            Print("DC protocol not available")
        end
    elseif msg == "protocol" then
        -- Show protocol status
        local dcAvail = rawget(_G, "DCAddonProtocol") and "YES" or "NO"
        local aioAvail = rawget(_G, "AIO") and "YES" or "NO"
        Print("Protocol status:")
        Print("  DCAddonProtocol: " .. dcAvail)
        Print("  AIO: " .. aioAvail)
        Print("  JSON mode: " .. (DCMythicPlusHUDDB.useDCProtocolJSON and "ON" or "OFF"))
    elseif msg == "vault" then
        if namespace.GreatVault then
            namespace.GreatVault:Toggle()
        else
            Print("Great Vault UI not loaded")
        end
    elseif msg == "finder" or msg == "gf" then
        -- Open Group Finder
        if namespace.GroupFinder then
            namespace.GroupFinder:Toggle()
        else
            Print("Group Finder not loaded yet")
        end
    elseif msg == "keystone" or msg == "activation" then
        -- Show keystone activation UI (for testing)
        if namespace.KeystoneUI then
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
    elseif msg == "help" then
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
        Print("  /dcm protocol - Show protocol status")
        Print("  /dcm finder - Open Group Finder")
        Print("  /dcgf - Open Group Finder (shortcut)")
    else
        ToggleVisibility()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event)
    -- Clear any stale activeState on login
    if event == "PLAYER_LOGIN" then
        activeState = nil
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
        if activeState and activeState.inProgress then
            UpdateFrameFromState(activeState)
        else
            -- Don't show idle state - only show when a run is active
            frame:Hide()
        end
    end
end)

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS (lightweight alternative to AIO)
-- =====================================================================

-- Settings toggle for JSON vs pipe-delimited
DCMythicPlusHUDDB.useDCProtocolJSON = (DCMythicPlusHUDDB.useDCProtocolJSON ~= false)  -- Prefer JSON by default

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
        
        if data.success then
            Print("Run completed! Key upgraded by " .. (data.keyChange or 0))
            if data.score then
                Print("Score: " .. data.score)
            end
        else
            Print("Run failed.")
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
        local args = {...}
        
        if type(args[1]) == "table" then
            -- JSON format with full run state
            local json = args[1]
            if not activeState then
                activeState = { inProgress = true }
            end
            activeState.elapsed = json.elapsed or activeState.elapsed
            activeState.timeLimit = json.remaining and (json.elapsed + json.remaining) or activeState.timeLimit
            activeState.deaths = json.deaths or activeState.deaths
            activeState.bossesKilled = json.bossesKilled or activeState.bossesKilled
            activeState.bossesTotal = json.bossesTotal or activeState.bossesTotal
            activeState.enemyCount = json.enemyCount or activeState.enemyCount
            activeState.enemyRequired = json.enemyRequired or activeState.enemyRequired
            
            if json.failed then
                Print("Run failed!")
                activeState = nil
                ShowIdleState()
                return
            end
            
            if json.completed then
                Print("Run completed!")

                -- Event-driven Vault refresh: completion affects Vault progress
                if namespace.GreatVault and namespace.GreatVault.IsShown and namespace.GreatVault:IsShown() then
                    if namespace.RequestVaultInfo then
                        namespace.RequestVaultInfo()
                    end
                end
            end
            
            UpdateFrameFromState(activeState)
        else
            -- Pipe-delimited format
            local elapsed, timeLimit, deaths = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
            if activeState then
                activeState.elapsed = elapsed
                activeState.timeLimit = timeLimit
                activeState.deaths = deaths or activeState.deaths
                UpdateFrameFromState(activeState)
            end
        end
    end)
    
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
            local weekNum = json.weekNumber or "?"
            Print("Week " .. weekNum .. " affixes:")
            -- Parse affixes array if present
            if json.affixes and type(json.affixes) == "table" then
                local affixNames = {}
                for _, affix in ipairs(json.affixes) do
                    if type(affix) == "table" and affix.name then
                        table.insert(affixNames, affix.name)
                    elseif type(affix) == "string" then
                        table.insert(affixNames, affix)
                    end
                end
                if #affixNames > 0 then
                    Print("  " .. table.concat(affixNames, ", "))
                end
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
    
    -- =========================================================================
    -- Keystone Activation Integration (integrated KeystoneUI)
    -- =========================================================================
    
    -- SMSG_KEYSTONE_ACTIVATE (0x40) - Server requesting keystone activation UI
    DC:RegisterHandler("MPLUS", 0x40, function(...)
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
    
    -- SMSG_KEYSTONE_STATUS (0x41) - Player ready state update
    DC:RegisterHandler("MPLUS", 0x41, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.KeystoneUI then
                namespace.KeystoneUI:OnPlayerReadyUpdate(data)
            end
        end
    end)
    
    -- SMSG_KEYSTONE_COUNTDOWN (0x43) - Countdown update
    DC:RegisterHandler("MPLUS", 0x43, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.KeystoneUI then
                namespace.KeystoneUI:OnCountdownStart(data)
            end
        end
    end)
    
    -- SMSG_KEYSTONE_CANCEL (0x44) - Activation cancelled
    DC:RegisterHandler("MPLUS", 0x44, function(...)
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
    
    -- SMSG_GROUP_LIST (0x13) - List of available groups
    DC:RegisterHandler("MPLUS", 0x13, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:PopulateMythicGroups(data.groups or {})
            end
        end
    end)
    
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
    
    -- SMSG_SCHEDULED_EVENTS (0x30) - List of scheduled events
    DC:RegisterHandler("MPLUS", 0x30, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            if namespace.GroupFinder then
                namespace.GroupFinder:PopulateScheduledEvents(data.events or {})
            end
        end
    end)
    
    -- =========================================================================
    -- GRPF (Group Finder) Protocol Handlers
    -- =========================================================================
    
    local GFOpcodes = DC.GroupFinderOpcodes or {}
    
    -- SMSG_LISTING_CREATED (0x30) - Confirm listing created
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_LISTING_CREATED or 0x30, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            Print("Group listing created! ID: " .. (data.listingId or "?"))
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
            if namespace.GroupFinder then
                namespace.GroupFinder:PopulateMythicGroups(data.groups or {})
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
                Print("|cff00ff00Your application was accepted!|r")
            elseif status == "declined" then
                Print("|cffff0000Your application was declined.|r")
            else
                Print("Application status: " .. status)
            end
            if namespace.GroupFinder then
                namespace.GroupFinder:OnApplicationStatusChanged(data)
            end
        end
    end)
    
    -- SMSG_NEW_APPLICATION (0x33) - Leader: new applicant
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_NEW_APPLICATION or 0x33, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            Print("|cffffff00New applicant:|r " .. (data.playerName or "Unknown") .. " (" .. (data.role or "?") .. ")")
            if namespace.GroupFinder then
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
    
    -- SMSG_DIFFICULTY_CHANGED (0x51) - Confirm difficulty changed
    DC:RegisterHandler("GRPF", GFOpcodes.SMSG_DIFFICULTY_CHANGED or 0x51, function(...)
        local args = {...}
        if type(args[1]) == "table" then
            local data = args[1]
            local diffName = data.difficultyName or "Unknown"
            Print("Difficulty changed to: |cff32c4ff" .. diffName .. "|r")
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
            DC:Send("MPLUS", 0x42, { accepted = accepted })  -- CMSG_KEYSTONE_RESPOND
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

