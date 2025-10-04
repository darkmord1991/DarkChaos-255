-- HLBG_AIO_Client.lua - Fixed version with proper ShowUI function
-- This file provides AIO integration for the HinterlandAffixHUD addon

local HLBG = _G.HLBG or {}
_G.HLBG = HLBG

-- Initialize SavedVariables
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.disableChatUpdates == nil then 
    HinterlandAffixHUDDB.disableChatUpdates = true 
end

-- UI constants
HLBG.UI = HLBG.UI or {}
HLBG.UI.TAB_LIVE = 1
HLBG.UI.TAB_HISTORY = 2
HLBG.UI.TAB_STATS = 3
HLBG.UI.TAB_SETTINGS = 4

-- History buffer and stats
HLBG._histBuf = HLBG._histBuf or {}
HLBG._cachedStats = HLBG._cachedStats or {}

-- UI Frame reference
local mainFrame = nil

-- Helper function to create main UI frame
local function CreateMainUI()
    if mainFrame then return mainFrame end
    
    mainFrame = CreateFrame("Frame", "HLBG_MainFrame", UIParent)
    mainFrame:SetSize(600, 400)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.8)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    
    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Hinterland Battleground")
    
    -- Tab buttons
    local tabs = {}
    local tabNames = {"Live", "History", "Stats", "Settings"}
    
    for i, name in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, mainFrame, "OptionsFrameTabButtonTemplate")
        tab:SetText(name)
        if i == 1 then
            tab:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 10, 7)
        else
            tab:SetPoint("LEFT", tabs[i-1], "RIGHT", -15, 0)
        end
        tab:SetScript("OnClick", function() HLBG.ShowTab(i) end)
        tabs[i] = tab
    end
    
    mainFrame.tabs = tabs
    
    -- Content frames for each tab
    local contentFrames = {}
    for i = 1, 4 do
        local frame = CreateFrame("Frame", nil, mainFrame)
        frame:SetAllPoints(mainFrame)
        frame:Hide()
        
        local content = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        content:SetPoint("TOPLEFT", 20, -60)
        frame.content = content
        
        contentFrames[i] = frame
    end
    
    mainFrame.contentFrames = contentFrames
    mainFrame.currentTab = 1
    
    -- Initialize content
    contentFrames[1].content:SetText("Live Status:\nWaiting for data...")
    contentFrames[2].content:SetText("History:\nNo data available")
    contentFrames[3].content:SetText("Statistics:\nNo data available")
    contentFrames[4].content:SetText("Settings:\nChat updates: " .. (HinterlandAffixHUDDB.disableChatUpdates and "Disabled" or "Enabled"))
    
    return mainFrame
end

-- Show specific tab
function HLBG.ShowTab(tabIndex)
    local frame = CreateMainUI()
    if not frame or not frame.contentFrames then return end
    
    -- Hide all tabs
    for i, contentFrame in ipairs(frame.contentFrames) do
        contentFrame:Hide()
    end
    
    -- Show selected tab
    if frame.contentFrames[tabIndex] then
        frame.contentFrames[tabIndex]:Show()
        frame.currentTab = tabIndex
        
        -- Update tab appearance (simplified)
        for i, tab in ipairs(frame.tabs) do
            if i == tabIndex then
                tab:SetNormalTexture("Interface/OptionsFrame/UI-OptionsFrame-ActiveTab")
            else
                tab:SetNormalTexture("Interface/OptionsFrame/UI-OptionsFrame-InActiveTab")
            end
        end
    end
end

-- Main ShowUI function that was missing
function HLBG.ShowUI(tabIndex)
    local frame = CreateMainUI()
    if not frame then 
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG]|r Failed to create UI frame")
        end
        return false
    end
    
    frame:Show()
    
    -- Show specific tab if requested
    if tabIndex and type(tabIndex) == "number" and tabIndex >= 1 and tabIndex <= 4 then
        HLBG.ShowTab(tabIndex)
    else
        HLBG.ShowTab(1) -- Default to Live tab
    end
    
    -- Request fresh data when opening UI
    if AIO and AIO.Handle then
        AIO.Handle("HLBG", "RequestStatus")
        AIO.Handle("HLBG", "RequestHistory")
        AIO.Handle("HLBG", "RequestStats")
    end
    
    return true
end

-- Update live status
function HLBG.UpdateLiveStatus(data)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[1] then
        local text = "Live Status:\n"
        if data then
            text = text .. string.format("Alliance: %s\nHorde: %s\n", 
                tostring(data.A or "?"), tostring(data.H or "?"))
            if data.affix then
                text = text .. "Affix: " .. tostring(data.affix) .. "\n"
            end
            if data.timeLeft then
                text = text .. "Time Left: " .. tostring(data.timeLeft) .. "\n"
            end
        else
            text = text .. "No data available"
        end
        frame.contentFrames[1].content:SetText(text)
    end
end

-- Update history display
function HLBG.UpdateHistory(historyData)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[2] then
        local text = "Recent History:\n"
        if historyData and type(historyData) == "table" and #historyData > 0 then
            for i, entry in ipairs(historyData) do
                if i > 10 then break end -- Show only last 10
                local line = string.format("%s - %s won\n", 
                    tostring(entry.date or entry.ts or "?"),
                    tostring(entry.winner or "?"))
                text = text .. line
            end
        else
            text = text .. "No history available"
        end
        frame.contentFrames[2].content:SetText(text)
    end
    
    -- Also store in buffer for stats calculation
    if historyData and type(historyData) == "table" then
        HLBG._histBuf = historyData
        HLBG._recomputeStats()
    end
end

-- Update stats display
function HLBG.UpdateStats(statsData)
    local frame = CreateMainUI()
    if frame and frame.contentFrames[3] then
        local text = "Statistics:\n"
        if statsData and type(statsData) == "table" then
            text = text .. string.format("Alliance Wins: %s\n", tostring(statsData.allianceWins or 0))
            text = text .. string.format("Horde Wins: %s\n", tostring(statsData.hordeWins or 0))
            text = text .. string.format("Draws: %s\n", tostring(statsData.draws or 0))
            text = text .. string.format("Total Games: %s\n", tostring(statsData.total or 0))
        else
            text = text .. "No statistics available"
        end
        frame.contentFrames[3].content:SetText(text)
    end
    
    HLBG._cachedStats = statsData or {}
end

-- Recompute stats from history buffer
function HLBG._recomputeStats()
    local stats = {allianceWins = 0, hordeWins = 0, draws = 0, total = 0}
    
    for _, entry in ipairs(HLBG._histBuf or {}) do
        stats.total = stats.total + 1
        local winner = tostring(entry.winner or ""):lower()
        if winner == "alliance" then
            stats.allianceWins = stats.allianceWins + 1
        elseif winner == "horde" then
            stats.hordeWins = stats.hordeWins + 1
        else
            stats.draws = stats.draws + 1
        end
    end
    
    HLBG._cachedStats = stats
    HLBG.UpdateStats(stats)
end

-- Generate test data
function HLBG.GenerateTestData()
    -- Test live status
    HLBG.UpdateLiveStatus({
        A = 350,
        H = 280,
        affix = "Bloodlust",
        timeLeft = "15:30"
    })
    
    -- Test history
    local testHistory = {}
    local winners = {"Alliance", "Horde", "Draw"}
    for i = 1, 12 do
        table.insert(testHistory, {
            id = i,
            date = date("%Y-%m-%d %H:%M:%S", time() - (i * 3600)),
            winner = winners[math.random(1, 3)],
            affix = "Affix" .. math.random(1, 5)
        })
    end
    HLBG.UpdateHistory(testHistory)
end

-- AIO Integration
HLBG.InitializeAfterAIO = function()
    if not AIO then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO not available")
        end
        return false
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG AIO]|r AIO integration active")
    end

    -- Register AIO handlers
    if AIO.AddHandlers then
        local handlers = AIO.AddHandlers("HLBG", {})
        
        -- Status handler
        handlers.Status = function(player, data)
            if type(data) == "table" then
                HLBG.UpdateLiveStatus(data)
            end
        end
        
        -- History handler  
        handlers.History = function(player, data)
            if type(data) == "table" then
                HLBG.UpdateHistory(data)
            end
        end
        
        -- Stats handler
        handlers.Stats = function(player, data)
            if type(data) == "table" then
                HLBG.UpdateStats(data)
            end
        end
        
        -- ShowUI handler
        handlers.ShowUI = function(player, tabIndex)
            HLBG.ShowUI(tabIndex)
        end
    end
    
    return true
end

-- Slash commands
local function RegisterSlashCommands()
    SLASH_HLBG1 = "/hlbg"
    SLASH_HLBG2 = "/hinterland"
    SlashCmdList["HLBG"] = function(msg)
        local args = {}
        for arg in msg:gmatch("%S+") do
            table.insert(args, arg:lower())
        end
        
        if args[1] == "test" then
            HLBG.GenerateTestData()
            HLBG.ShowUI(1)
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[HLBG]|r Test data loaded")
            end
        else
            HLBG.ShowUI()
        end
    end
end

-- Initialize when AIO is ready
if AIO and AIO.Handle then
    HLBG.InitializeAfterAIO()
else
    -- Wait for AIO to load
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "AIO_Client" or addonName == "AIO" then
            HLBG.InitializeAfterAIO()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Register slash commands immediately
RegisterSlashCommands()

if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG]|r Client loaded - Use /hlbg or /hinterland to open")
end
    if s:find('\t') then return nil, 'tsv' end
    -- id
    local id, rest = s:match('^(%d+)%s*(.*)$')
    if not id then return nil end
    -- optional literal word 'season <n>'
    local sea
    local rest2 = rest:match('^season%s+(%d+)%s*(.*)$')
    if rest2 then
        sea = rest:match('^season%s+(%d+)')
        rest = rest:sub(#('season '..sea) + 1):gsub('^%s+','')
    end
    -- timestamp yyyy-mm-dd HH:MM:SS
    local d, t, after = rest:match('^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d:%d%d)%s*(.*)$')
    if not d then return nil end
    local ts = d .. ' ' .. t
    -- winner
    local win, after2 = after:match('^(Alliance|Horde|Draw|DRAW)%s*(.*)$')
    if not win then return nil end
    if win == 'Draw' then win = 'DRAW' end
    -- affix id (number)
    local aff, after3 = after2:match('^(%d+)%s*(.*)$')
    aff = aff or '0'
    local reason = after3 and after3:gsub('^%s+','') or '-' 
    return { id = id, season = sea and tonumber(sea) or nil, ts = ts, winner = win, affix = aff, reason = reason }
end

function HLBG._recomputeStatsFromBuf()
    local buf = HLBG._histBuf or {}
    local a,h,d = 0,0,0
    for i=1,#buf do
        local w = tostring(buf[i].winner or ''):upper()
        if w == 'ALLIANCE' then a=a+1 elseif w == 'HORDE' then h=h+1 else d=d+1 end
    end
    local stats = { counts = { Alliance = a, Horde = h }, draws = d, avgDuration = 0 }
    if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, stats) end
end

function HLBG._pushHistoryRow(row)
    if type(row) ~= 'table' then return end
    local per = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5
    table.insert(HLBG._histBuf, 1, row)
    while #HLBG._histBuf > per do table.remove(HLBG._histBuf) end
    if type(HLBG.History) == 'function' then pcall(HLBG.History, HLBG._histBuf, 1, per, #HLBG._histBuf, 'id', 'DESC') end
    HLBG._recomputeStatsFromBuf()
end

-- System-chat fallback: parse server broadcast lines like [HLBG_STATUS], [HLBG_HISTORY_TSV], etc.
do
    local function parseHLBG(msg)
        if type(msg) ~= 'string' then return end
        -- STATUS
        local b = msg:match('%[HLBG_STATUS%]%s*(.*)')
        if b then
            local A = tonumber(b:match('%f[%w]A=(%d+)'))
            local H = tonumber(b:match('%f[%w]H=(%d+)'))
            local ENDTS = tonumber(b:match('%f[%w]END=(%d+)'))
            local LOCK = tonumber(b:match('%f[%w]LOCK=(%d+)'))
            local AFF = b:match('%f[%w]AFF=([^|]+)') or b:match('%f[%w]AFFIX=([^|]+)')
            local DUR = tonumber(b:match('%f[%w]DURATION=(%d+)')) or tonumber(b:match('%f[%w]MATCH_TOTAL=(%d+)'))
            local AP = tonumber(b:match('%f[%w]APLAYERs=(%d+)')) or tonumber(b:match('%f[%w]APLAYER%(s%)=(%d+)')) or tonumber(b:match('%f[%w]APLAYER=(%d+)')) or tonumber(b:match('%f[%w]APC=(%d+)'))
            local HP = tonumber(b:match('%f[%w]HPLAYERS=(%d+)')) or tonumber(b:match('%f[%w]HPLAYERs=(%d+)')) or tonumber(b:match('%f[%w]HPC=(%d+)'))
            HLBG._lastStatus = HLBG._lastStatus or {}
            if A then HLBG._lastStatus.A = A end
            if H then HLBG._lastStatus.H = H end
            if ENDTS then HLBG._lastStatus.ENDTS = ENDTS end
            if LOCK ~= nil then HLBG._lastStatus.LOCK = LOCK end
            if AFF then HLBG._lastStatus.AFF = AFF end
            if DUR then HLBG._lastStatus.DURATION = DUR end
            if AP then HLBG._lastStatus.APlayers = AP; HLBG._lastStatus.APC = AP end
            if HP then HLBG._lastStatus.HPlayers = HP; HLBG._lastStatus.HPC = HP end
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- HISTORY TSV fallback
        local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)') or msg:match('%[HLBG_DUMP%]%s*(.*)') or msg:match('%[HLBG_DBG_TSV%]%s*(.*)')
        if htsv then
            local per = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5
            -- Extract TOTAL meta if present then convert row separator '||' to newlines for HistoryStr
            local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or 0)) or 0
            if total and total > 0 then htsv = htsv:gsub('^TOTAL=%d+%s*%|%|','') end
            if htsv:find('%|%|') then htsv = htsv:gsub('%|%|','\n') end
            if htsv:find('\t') then
                if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, per, total, 'id', 'DESC') end
            else
                -- No tabs present (some servers strip them). Parse each line flexibly.
                local rows = {}
                for line in htsv:gmatch('[^\n]+') do
                    if line and line ~= '' and type(HLBG._parseHistLineFlexible) == 'function' then
                        local r = HLBG._parseHistLineFlexible(line)
                        if r then table.insert(rows, r) end
                    end
                end
                if #rows > 0 then
                    if type(HLBG.History) == 'function' then
                        pcall(HLBG.History, rows, 1, per, total, 'id', 'DESC')
                    else
                        -- fallback: push first row
                        pcall(HLBG._pushHistoryRow, rows[1])
                    end
                end
            end
            return
        end
        
        -- AFFIX broadcast
        local aff = msg:match('%[HLBG_AFFIX%]%s*(.+)')
        if aff then
            HLBG._lastStatus = HLBG._lastStatus or {}
            HLBG._lastStatus.AFF = aff
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- WARMUP
        local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
        if warm then
            local ts = tonumber(warm:match('%f[%w]START=(%d+)'))
            local dur = tonumber(warm:match('%f[%w]DURATION=(%d+)'))
            HLBG._lastStatus = HLBG._lastStatus or {}
            if ts then HLBG._lastStatus.START = ts end
            if dur then HLBG._lastStatus.WARMUP = dur end
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- Return false to indicate no match
        return false
    end
    
    -- Hook the chat frame addmessage to watch for system broadcasts
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local old = DEFAULT_CHAT_FRAME.AddMessage
        DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, r, g, b, id, ...)
            if type(msg) == 'string' then
                local handled = parseHLBG(msg)
                if not handled then return old(self, msg, r, g, b, id, ...) end
            else
                return old(self, msg, r, g, b, id, ...)
            end
        end
    end
end

-- Safe slash command registration helper
function HLBG.safeRegisterSlash(key, prefix, handler)
    if type(key) ~= 'string' or type(prefix) ~= 'string' or type(handler) ~= 'function' then return end
    if type(SlashCmdList) == 'table' and SlashCmdList[key] then
        -- already registered
        return
    end
    
    -- Convert /command to just 'command'
    local cmd = prefix:match('^/([%w_]+)') or prefix
    
    -- Register in global table
    _G['SLASH_'..key..'1'] = '/'..cmd
    SlashCmdList[key] = handler
end

-- Try to execute a slash command by name
function HLBG.trySlash(cmd, args)
    if type(cmd) ~= 'string' then return false end
    local verb = cmd:match('^/*([^%s/]+)')
    local rest = cmd:match('^/+[^%s/]+%s+(.+)$') or args or ''
    local key = verb:upper()
    if SlashCmdList and type(SlashCmdList[key]) == 'function' then pcall(SlashCmdList[key], rest or '') ; return true end
    
    -- Special handling for our main command - try aliases
    if verb:lower() == 'hlbghud' then
        if SlashCmdList and type(SlashCmdList['HLBGHUD']) == 'function' then
            pcall(SlashCmdList['HLBGHUD'], rest or '') ; return true
        end
    end
    if verb:lower() == 'hlbg' and SlashCmdList and type(SlashCmdList['HLBG']) == 'function' then pcall(SlashCmdList['HLBG'], rest or '') ; return true end
    return false
end

-- Register as initialization handler for AIO_Check
HLBG.InitializeAfterAIO = function()
    -- Skip AIO handler registration to avoid conflicts - just set up commands
    if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Skipping handler registration to avoid namespace conflicts")
    end
    
    -- Add SendCommand function - simplified approach
    HLBG.SendCommand = function(command, ...)
        local args = {...}  -- Capture varargs into a table
        
        if not AIO or type(AIO.Handle) ~= "function" then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO.Handle not available")
            end
            return false
        end
        
        if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00EEFF[HLBG AIO]|r Sending command: " .. tostring(command))
        end
        
        -- Only use the original namespace since that's what the server expects
        local success, err = pcall(function()
            AIO.Handle("HinterlandBG", "Command", command, unpack(args))
        end)
        
        if not success then
            if DEFAULT_CHAT_FRAME and _G.HLBG_Debug then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r Failed to send command: " .. tostring(err))
            end
            return false
        end
        
        return true
    end
    
    -- Set up our main slash command handlers when AIO is ready
    
    -- Main slash command handler (only need one version of this)
    function HLBG._MainSlashHandler(msg)
        if type(msg) ~= 'string' then msg = '' end
        -- Check for subcommands
        local cmd, args = msg:match('^(%S+)%s*(.*)$')
        if not cmd then 
            -- No command given, show UI or help
            if type(HLBG.ShowUI) == 'function' then
                return pcall(HLBG.ShowUI)
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Missing ShowUI handler') end
                return
            end
        end
        
        -- Handle common commands
        cmd = cmd:lower()
        if cmd == 'help' or cmd == '?' then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88Hinterland Battleground HUD Commands:|r')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg - Show the UI')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg history - Show the battle history')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg stats - Show statistics')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg status - Show current match status')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg season <n> - Show data for season <n> (0=all)')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg reload - Reload all data')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg options - Show options')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg affix - Show today\'s affix')
                DEFAULT_CHAT_FRAME:AddMessage('/hlbg test - Test HUD')
            end
            return
        elseif cmd == 'stats' then
            HLBG.SendCommand('RequestStats')
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_STATS)
            end
            return
        elseif cmd == 'status' or cmd == 'live' then
            HLBG.SendCommand('RequestStatus')
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_LIVE)
            end
            return
        elseif cmd == 'history' or cmd == 'matches' then
            HLBG.SendCommand('RequestHistory')
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_HISTORY)
            end
            return
        elseif cmd == 'season' then
            local s = tonumber(args) or 0
            if s < 0 then s = 0 end
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.desiredSeason = s
            if DEFAULT_CHAT_FRAME then
                if s == 0 then
                    DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Now showing data for all seasons')
                else
                    DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF88AA88HLBG:|r Now showing data for season %d', s))
                end
            end
            -- Request reload of data for new season
            HLBG.SendCommand('RequestStats')
            HLBG.SendCommand('RequestHistory')
            HLBG.SendCommand('RequestStatus')
            return
        elseif cmd == 'reload' or cmd == 'refresh' then
            HLBG.SendCommand('RequestStats')
            HLBG.SendCommand('RequestHistory')
            HLBG.SendCommand('RequestStatus')
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Reloading data')
            end
            return
        elseif cmd == 'options' or cmd == 'settings' or cmd == 'config' then
            if type(HLBG.ShowUI) == 'function' and type(HLBG.UI) == 'table' then
                pcall(HLBG.ShowUI, HLBG.UI.TAB_SETTINGS)
            end
            return
        elseif cmd == 'affix' or cmd == 'affixes' then
            HLBG.SendCommand('RequestStatus')
            if type(HLBG.ShowAffix) == 'function' then
                pcall(HLBG.ShowAffix)
            end
            return
        elseif cmd == 'diag' or cmd == 'diagnostic' then
            -- Run diagnostic command
            if SlashCmdList and SlashCmdList["HLBGDIAG"] then
                SlashCmdList["HLBGDIAG"]("")
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Diagnostic tool not available') end
            end
            return
        elseif cmd == 'test' then
            if type(HLBG.Test) == 'function' then
                pcall(HLBG.Test)
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Test mode not available') end
            end
            return
        elseif cmd == 'dev' then
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            if args == 'on' then
                HLBG._devMode = true
                HinterlandAffixHUDDB.devMode = true
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Developer mode enabled') end
            elseif args == 'off' then
                HLBG._devMode = false
                HinterlandAffixHUDDB.devMode = false
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Developer mode disabled') end
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cFF88AA88HLBG:|r Developer mode is ' .. (HLBG._devMode and 'ON' or 'OFF')) end
            end
            return
        end
        
        -- No valid command given, show UI
        if type(HLBG.ShowUI) == 'function' then
            return pcall(HLBG.ShowUI)
        end
    end
    
    -- Register slash commands (only once)
    -- Main command
    SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler
    _G["SLASH_HLBGHUD1"] = "/hlbg"
    -- Alternative command 
    SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler
    _G["SLASH_ZHLBG1"] = "/hlbghud"
    
    -- Register more aliases for convenience
    HLBG.safeRegisterSlash('HINTERLAND', '/hinterland', HLBG._MainSlashHandler)
    HLBG.safeRegisterSlash('HBG', '/hbg', HLBG._MainSlashHandler)
    HLBG.safeRegisterSlash('ZZHLBG', '/zhlbg', HLBG._MainSlashHandler)
    HLBG.safeRegisterSlash('HLBGUI', '/hlbgui', HLBG._MainSlashHandler)
    
    -- Fallback AIO listener removed to prevent errors with AIO.unpack
    -- The main AIO handlers should be sufficient for receiving events
    
    -- When client first loads, request data
    C_Timer.After(2, function()
        HLBG.SendCommand('RequestStats')
        HLBG.SendCommand('RequestHistory')
        HLBG.SendCommand('RequestStatus')
        HLBG.SendCommand('ClientHello', '1.5.7')  -- Pass version as simple string instead of table
    end)
    
    -- Inform user that AIO integration is working
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage('|cFF00FF00HLBG:|r AIO integration active with fallback listener')
    end
end

-- Register with AIO_Check system if available
if _G.HLBG_RegisterAIOCallback then
    _G.HLBG_RegisterAIOCallback(HLBG.InitializeAfterAIO, "HLBG_AIO_Client.InitializeAfterAIO")
else
    -- Fallback: execute immediately if AIO is available
    if AIO and type(AIO.Handle) == "function" then
        HLBG.InitializeAfterAIO()
    else
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[HLBG AIO]|r AIO not available and no callback system found")
        end
    end
end
    
-- Helper functions from the original file

function HLBG._getSeason()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local s = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
    if s < 0 then s = 0 end
    return s
end

-- Flexible chat-history parser and rolling buffer (used when servers broadcast single-line rows)
HLBG._histBuf = HLBG._histBuf or {}

-- _parseHistLineFlexible is used to parse history lines
function HLBG._parseHistLineFlexible(line)
    if type(line) ~= 'string' or line == '' then return nil end
    local s = line
    -- Strip leading TOTAL=...|| if present
    s = s:gsub('^TOTAL=%d+%s*%|%|', '')
    -- Try TSV first
    if s:find('\t') then return nil, 'tsv' end
    -- id
    local id, rest = s:match('^(%d+)%s*(.*)$')
    if not id then return nil end
    -- optional literal word 'season <n>'
    local sea
    local rest2 = rest:match('^season%s+(%d+)%s*(.*)$')
    if rest2 then
        sea = rest:match('^season%s+(%d+)')
        rest = rest:sub(#('season '..sea) + 1):gsub('^%s+','')
    end
    -- timestamp yyyy-mm-dd HH:MM:SS
    local d, t, after = rest:match('^(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d:%d%d)%s*(.*)$')
    if not d then return nil end
    local ts = d .. ' ' .. t
    -- winner
    local win, after2 = after:match('^(Alliance|Horde|Draw|DRAW)%s*(.*)$')
    if not win then return nil end
    if win == 'Draw' then win = 'DRAW' end
    -- affix id (number)
    local aff, after3 = after2:match('^(%d+)%s*(.*)$')
    aff = aff or '0'
    local reason = after3 and after3:gsub('^%s+','') or '-' 
    return { id = id, season = sea and tonumber(sea) or nil, ts = ts, winner = win, affix = aff, reason = reason }
end

function HLBG._recomputeStatsFromBuf()
    local buf = HLBG._histBuf or {}
    local a,h,d = 0,0,0
    for i=1,#buf do
        local w = tostring(buf[i].winner or ''):upper()
        if w == 'ALLIANCE' then a=a+1 elseif w == 'HORDE' then h=h+1 else d=d+1 end
    end
    local stats = { counts = { Alliance = a, Horde = h }, draws = d, avgDuration = 0 }
    if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, stats) end
end

function HLBG._pushHistoryRow(row)
    if type(row) ~= 'table' then return end
    local per = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5
    table.insert(HLBG._histBuf, 1, row)
    while #HLBG._histBuf > per do table.remove(HLBG._histBuf) end
    if type(HLBG.History) == 'function' then pcall(HLBG.History, HLBG._histBuf, 1, per, #HLBG._histBuf, 'id', 'DESC') end
    HLBG._recomputeStatsFromBuf()
end

-- System-chat fallback: parse server broadcast lines like [HLBG_STATUS], [HLBG_HISTORY_TSV], etc.
do
    local function parseHLBG(msg)
        if type(msg) ~= 'string' then return end
        -- STATUS
        local b = msg:match('%[HLBG_STATUS%]%s*(.*)')
        if b then
            local A = tonumber(b:match('%f[%w]A=(%d+)'))
            local H = tonumber(b:match('%f[%w]H=(%d+)'))
            local ENDTS = tonumber(b:match('%f[%w]END=(%d+)'))
            local LOCK = tonumber(b:match('%f[%w]LOCK=(%d+)'))
            local AFF = b:match('%f[%w]AFF=([^|]+)') or b:match('%f[%w]AFFIX=([^|]+)')
            local DUR = tonumber(b:match('%f[%w]DURATION=(%d+)')) or tonumber(b:match('%f[%w]MATCH_TOTAL=(%d+)'))
            local AP = tonumber(b:match('%f[%w]APLAYERs=(%d+)')) or tonumber(b:match('%f[%w]APLAYER%(s%)=(%d+)')) or tonumber(b:match('%f[%w]APLAYER=(%d+)')) or tonumber(b:match('%f[%w]APC=(%d+)'))
            local HP = tonumber(b:match('%f[%w]HPLAYERS=(%d+)')) or tonumber(b:match('%f[%w]HPLAYERs=(%d+)')) or tonumber(b:match('%f[%w]HPC=(%d+)'))
            HLBG._lastStatus = HLBG._lastStatus or {}
            if A then HLBG._lastStatus.A = A end
            if H then HLBG._lastStatus.H = H end
            if ENDTS then HLBG._lastStatus.ENDTS = ENDTS end
            if LOCK ~= nil then HLBG._lastStatus.LOCK = LOCK end
            if AFF then HLBG._lastStatus.AFF = AFF end
            if DUR then HLBG._lastStatus.DURATION = DUR end
            if AP then HLBG._lastStatus.APlayers = AP; HLBG._lastStatus.APC = AP end
            if HP then HLBG._lastStatus.HPlayers = HP; HLBG._lastStatus.HPC = HP end
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- HISTORY TSV fallback
        local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)') or msg:match('%[HLBG_DUMP%]%s*(.*)') or msg:match('%[HLBG_DBG_TSV%]%s*(.*)')
        if htsv then
            local per = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5
            -- Extract TOTAL meta if present then convert row separator '||' to newlines for HistoryStr
            local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or 0)) or 0
            if total and total > 0 then htsv = htsv:gsub('^TOTAL=%d+%s*%|%|','') end
            if htsv:find('%|%|') then htsv = htsv:gsub('%|%|','\n') end
            if htsv:find('\t') then
                if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, per, total, 'id', 'DESC') end
            else
                -- No tabs present (some servers strip them). Parse each line flexibly.
                local rows = {}
                for line in htsv:gmatch('[^\n]+') do
                    if line and line ~= '' and type(HLBG._parseHistLineFlexible) == 'function' then
                        local r = HLBG._parseHistLineFlexible(line)
                        if r then table.insert(rows, r) end
                    end
                end
                if #rows > 0 then
                    if type(HLBG.History) == 'function' then
                        pcall(HLBG.History, rows, 1, per, total, 'id', 'DESC')
                    else
                        -- fallback: push first row
                        pcall(HLBG._pushHistoryRow, rows[1])
                    end
                end
            end
            return
        end
        
        -- AFFIX broadcast
        local aff = msg:match('%[HLBG_AFFIX%]%s*(.+)')
        if aff then
            HLBG._lastStatus = HLBG._lastStatus or {}
            HLBG._lastStatus.AFF = aff
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- WARMUP
        local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
        if warm then
            local ts = tonumber(warm:match('%f[%w]START=(%d+)'))
            local dur = tonumber(warm:match('%f[%w]DURATION=(%d+)'))
            HLBG._lastStatus = HLBG._lastStatus or {}
            if ts then HLBG._lastStatus.START = ts end
            if dur then HLBG._lastStatus.WARMUP = dur end
            if type(HLBG.UpdateLiveFromStatus) == 'function' then pcall(HLBG.UpdateLiveFromStatus) end
            return
        end
        
        -- Return false to indicate no match
        return false
    end
    
    -- Hook the chat frame addmessage to watch for system broadcasts
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local old = DEFAULT_CHAT_FRAME.AddMessage
        DEFAULT_CHAT_FRAME.AddMessage = function(self, msg, r, g, b, id, ...)
            if type(msg) == 'string' then
                local handled = parseHLBG(msg)
                if not handled then return old(self, msg, r, g, b, id, ...) end
            else
                return old(self, msg, r, g, b, id, ...)
            end
        end
    end
end

-- Safe slash command registration helper
function HLBG.safeRegisterSlash(key, prefix, handler)
    if type(key) ~= 'string' or type(prefix) ~= 'string' or type(handler) ~= 'function' then return end
    if type(SlashCmdList) == 'table' and SlashCmdList[key] then
        -- already registered
        return
    end
    
    -- Convert /command to just 'command'
    local cmd = prefix:match('^/([%w_]+)') or prefix
    
    -- Register in global table
    _G['SLASH_'..key..'1'] = '/'..cmd
    SlashCmdList[key] = handler
end

-- Try to execute a slash command by name
function HLBG.trySlash(cmd, args)
    if type(cmd) ~= 'string' then return false end
    local verb = cmd:match('^/*([^%s/]+)')
    local rest = cmd:match('^/+[^%s/]+%s+(.+)$') or args or ''
    local key = verb:upper()
    if SlashCmdList and type(SlashCmdList[key]) == 'function' then pcall(SlashCmdList[key], rest or '') ; return true end
    
    -- Special handling for our main command - try aliases
    if verb:lower() == 'hlbghud' then
        if SlashCmdList and type(SlashCmdList['HLBGHUD']) == 'function' then
            pcall(SlashCmdList['HLBGHUD'], rest or '') ; return true
        end
    end
    if verb:lower() == 'hlbg' and SlashCmdList and type(SlashCmdList['HLBG']) == 'function' then pcall(SlashCmdList['HLBG'], rest or '') ; return true end
    return false
end