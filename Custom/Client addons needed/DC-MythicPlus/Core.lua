local addonName = ... or "DC-MythicPlus"
local namespace = _G.DCMythicPlusHUD or {}
_G.DCMythicPlusHUD = namespace

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

local function SetFrameVisibility(shouldShow)
    if not frame then
        return
    end
    if shouldShow and not DCMythicPlusHUDDB.hidden then
        frame:Show()
    else
        frame:Hide()
    end
end

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
    SetFrameVisibility(true)
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
SlashCmdList.DCM = function(msg)
    msg = Trim((msg or "")):lower()
    if msg == "lock" then
        ToggleLock()
    elseif msg == "unlock" then
        DCMythicPlusHUDDB.locked = false
        Print("Frame unlocked")
    elseif msg == "show" then
        DCMythicPlusHUDDB.hidden = false
        if not activeState then
            ShowIdleState()
        end
        SetFrameVisibility(true)
        Print("HUD shown")
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
    else
        ToggleVisibility()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event)
    EnsureFrame()
    ApplySavedPosition()
    if not TryRegisterHandlers() then
        BeginRetryLoop()
    else
        RequestServerSnapshot(event or "event")
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if activeState then
            UpdateFrameFromState(activeState)
        else
            ShowIdleState()
        end
    end
end)

-- =====================================================================
-- DC ADDON PROTOCOL HANDLERS (lightweight alternative to AIO)
-- =====================================================================

-- Settings toggle for JSON vs pipe-delimited
DCMythicPlusHUDDB = DCMythicPlusHUDDB or {}
DCMythicPlusHUDDB.useDCProtocolJSON = DCMythicPlusHUDDB.useDCProtocolJSON or true  -- Prefer JSON by default

if DC then
    -- Helper to decode JSON from DC protocol
    local function DecodeJSON(jsonStr)
        if type(DC.DecodeJSON) == 'function' then
            return DC:DecodeJSON(jsonStr)
        end
        -- Fallback simple JSON decoder if DC doesn't have one
        local ok, result = pcall(function()
            if type(jsonStr) ~= 'string' then return nil end
            local obj = {}
            -- Simple key:value parser for flat objects
            for key, val in jsonStr:gmatch('"([^"]+)":([^,}]+)') do
                val = val:gsub('^%s*', ''):gsub('%s*$', '')
                if val == 'true' then obj[key] = true
                elseif val == 'false' then obj[key] = false
                elseif val:match('^"') then obj[key] = val:gsub('^"', ''):gsub('"$', '')
                else obj[key] = tonumber(val) or val end
            end
            return obj
        end)
        return ok and result or nil
    end

    -- Check if message is JSON format (starts with "J" marker)
    local function IsJSONMessage(...)
        local args = {...}
        return args[1] == "J"
    end

    -- SMSG_RUN_START (0x13) - Mythic+ run started
    DC:RegisterHandler("MPLUS", 0x13, function(...)
        local args = {...}
        local keyLevel, mapId, dungeonName, timeLimit, affixes
        
        if IsJSONMessage(...) then
            -- JSON format: J, jsonString
            local json = DecodeJSON(args[2])
            if json then
                keyLevel = json.keyLevel
                mapId = json.dungeonId
                dungeonName = json.dungeonName
                timeLimit = json.timeLimit
                affixes = json.affixes
            end
        else
            -- Pipe-delimited format
            keyLevel = args[1]
            mapId = args[2]
            affixes = args[3]
            timeLimit = args[4]
        end
        
        Print("Mythic+" .. (keyLevel or "?") .. " started!")
        activeState = {
            inProgress = true,
            keyLevel = keyLevel,
            mapId = mapId,
            dungeonName = dungeonName,
            timeLimit = timeLimit,
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
        local success, timeElapsed, keyUpgrade, score, newKeyLevel
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                success = json.success
                timeElapsed = json.timeElapsed
                keyUpgrade = json.keyChange
                score = json.score
                newKeyLevel = json.newKeyLevel
            end
        else
            success = args[1]
            timeElapsed = args[2]
            keyUpgrade = args[3]
        end
        
        if success then
            Print("Run completed! Key upgraded by " .. (keyUpgrade or 0))
            if score then
                Print("Score: " .. score)
            end
        else
            Print("Run failed.")
        end
        activeState = nil
        ShowIdleState()
    end)
    
    -- SMSG_TIMER_UPDATE (0x15) - Timer sync / HUD update
    DC:RegisterHandler("MPLUS", 0x15, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            -- JSON format with full run state
            local json = DecodeJSON(args[2])
            if json then
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
                end
                
                UpdateFrameFromState(activeState)
            end
        else
            -- Pipe-delimited format
            local elapsed, timeLimit, deaths, deathPenalty = args[1], args[2], args[3], args[4]
            if activeState then
                activeState.elapsed = elapsed
                activeState.timeLimit = timeLimit
                activeState.deaths = deaths or activeState.deaths
                UpdateFrameFromState(activeState)
            end
        end
    end)
    
    -- SMSG_OBJECTIVE_UPDATE (0x16) - Boss/enemy count update
    DC:RegisterHandler("MPLUS", 0x16, function(bossesKilled, bossesTotal, enemyCount, enemyRequired)
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
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                if json.hasKey then
                    Print("Your key: +" .. (json.level or "?") .. " " .. (json.dungeonName or ""))
                    if json.depleted then
                        Print("(Depleted)")
                    end
                else
                    Print("No keystone in inventory")
                end
            end
        else
            -- Pipe-delimited format
            local hasKey, dungeonId, mapName, keyLevel, depleted = args[1], args[2], args[3], args[4], args[5]
            if hasKey == "1" or hasKey == 1 then
                Print("Your key: +" .. (keyLevel or "?") .. " " .. (mapName or ""))
            else
                Print("No keystone in inventory")
            end
        end
    end)
    
    -- SMSG_AFFIXES (0x11) - Current week's affixes
    DC:RegisterHandler("MPLUS", 0x11, function(...)
        local args = {...}
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                local weekNum = json.weekNumber or "?"
                Print("Week " .. weekNum .. " affixes:")
                -- Parse affixes JSON array if present
                if json.affixes and type(json.affixes) == 'string' then
                    -- Affixes is encoded as a JSON array string within the object
                    local affixList = {}
                    for entry in json.affixes:gmatch('%{[^}]+%}') do
                        local name = entry:match('"name":"([^"]+)"')
                        if name then
                            table.insert(affixList, name)
                        end
                    end
                    if #affixList > 0 then
                        Print("  " .. table.concat(affixList, ", "))
                    end
                end
            end
        else
            -- Pipe-delimited format
            local affixData = args[1] -- Format: id:name:desc;id:name:desc;...
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
        
        if IsJSONMessage(...) then
            local json = DecodeJSON(args[2])
            if json then
                local count = json.count or 0
                Print("Best runs (" .. count .. "):")
                -- Parse runs JSON array if present
                if json.runs and type(json.runs) == 'string' then
                    local idx = 1
                    for entry in json.runs:gmatch('%{[^}]+%}') do
                        local name = entry:match('"dungeonName":"([^"]+)"')
                        local level = entry:match('"level":(%d+)')
                        local time = entry:match('"time":(%d+)')
                        if name and level then
                            local timeStr = time and FormatSeconds(tonumber(time)) or "?"
                            Print("  " .. idx .. ". " .. name .. " +" .. level .. " (" .. timeStr .. ")")
                            idx = idx + 1
                        end
                    end
                end
            end
        else
            -- Pipe-delimited format
            local runData = args[1] -- Format: dungeonId:level:time:deaths:season;...
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
    
    -- Helper to request data via protocol
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
end
