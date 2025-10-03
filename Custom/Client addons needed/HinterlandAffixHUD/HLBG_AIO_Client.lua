local HLBG = _G.HLBG or {}
_G.HLBG = HLBG
-- Developer mode flag: when true, extra test slash commands will be registered.
HLBG._devMode = HLBG._devMode or false
-- If user saved a persistent devMode, honor it on load
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.devMode ~= nil then HLBG._devMode = HinterlandAffixHUDDB.devMode and true or false end
-- Default to 0 (current/all). User can change via "/hlbg season <n>"
HinterlandAffixHUDDB.desiredSeason = HinterlandAffixHUDDB.desiredSeason or 0
-- Disable periodic chat updates by default (user can re-enable in options)
if HinterlandAffixHUDDB.disableChatUpdates == nil then HinterlandAffixHUDDB.disableChatUpdates = true end
function HLBG._getSeason()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local s = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
    if s < 0 then s = 0 end
    return s
end

-- Flexible chat-history parser and rolling buffer (used when servers broadcast single-line rows)
HLBG._histBuf = HLBG._histBuf or {}

-- Minimal JSON decode fallback (very limited: handles objects with string keys and number/string/bool/null values, arrays of same)
if type(_G.json_decode) ~= 'function' and type(HLBG.json_decode) ~= 'function' then
    local function jerr() return nil end
    local function parse_value(s, i)
        i = i or 1
        i = s:match('^%s*()', i) or i
        local c = s:sub(i,i)
        if c == '"' then
            local j = i+1; local out = {}
            while j <= #s do
                local ch = s:sub(j,j)
                if ch == '"' then return table.concat(out), j+1 end
                if ch == '\\' then j = j + 1; ch = s:sub(j,j) end
                table.insert(out, ch); j = j + 1
            end
            return jerr()
        elseif c == '{' then
            local obj = {}; i = i+1
            i = s:match('^%s*()', i) or i
            if s:sub(i,i) == '}' then return obj, i+1 end
            while i <= #s do
                local key; key, i = parse_value(s, i); if type(key) ~= 'string' then return jerr() end
                i = s:match('^%s*:%s*()', i) or i
                local val; val, i = parse_value(s, i)
                obj[key] = val
                i = s:match('^%s*()', i) or i
                local ch = s:sub(i,i)
                if ch == '}' then return obj, i+1 end
                if ch ~= ',' then return jerr() end
                i = i + 1
            end
            return jerr()
        elseif c == '[' then
            local arr = {}; i = i+1
            i = s:match('^%s*()', i) or i
            if s:sub(i,i) == ']' then return arr, i+1 end
            local idx = 1
            while i <= #s do
                local val; val, i = parse_value(s, i)
                arr[idx] = val; idx = idx + 1
                i = s:match('^%s*()', i) or i
                local ch = s:sub(i,i)
                if ch == ']' then return arr, i+1 end
                if ch ~= ',' then return jerr() end
                i = i + 1
            end
            return jerr()
        else
            local lit, j = s:match('^([%-%d%.]+)()', i)
            if lit then return tonumber(lit), j end
            if s:find('^true', i) then return true, i+4 end
            if s:find('^false', i) then return false, i+5 end
            if s:find('^null', i) then return nil, i+4 end
            return jerr()
        end
    end
    function HLBG.json_decode(str)
        if type(str) ~= 'string' then return nil end
        local v, pos = parse_value(str, 1)
        if not pos then return nil end
        return v
    end
end
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
            if warm and type(HLBG.Warmup) == 'function' then pcall(HLBG.Warmup, warm) ; return end
            -- QUEUE
            local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
            if q and type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) ; return end
            -- STATS JSON fallback
            local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
            if sj then
                local ok, decoded = pcall(function()
                    if type(json_decode) == 'function' then return json_decode(sj) end
                    if type(HLBG) == 'table' and type(HLBG.json_decode) == 'function' then return HLBG.json_decode(sj) end
                    return nil
                end)
                if ok and type(decoded) == 'table' and type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, decoded) end
                return
            end
        end
        local fsys = CreateFrame('Frame')
        fsys:RegisterEvent('CHAT_MSG_SYSTEM')
        fsys:SetScript('OnEvent', function(_, _, msg)
            pcall(parseHLBG, msg)
        end)
    end
-- Provide a stable global alias so callers can still obtain the season even if AIO swaps the HLBG table
_G.HLBG_GetSeason = HLBG._getSeason

-- Utility: safely register a SLASH_* command without stomping existing registrations.
local function safeRegisterSlash(key, cmd, handler)
    if type(key) ~= 'string' or type(cmd) ~= 'string' or type(handler) ~= 'function' then return false end
    -- If another addon already registered the named SlashCmdList entry, warn and don't overwrite
    if type(SlashCmdList) == 'table' and SlashCmdList[key] then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: cannot register slash '%s' (%s) - name already used", cmd, key))
        end
        -- record skipped
        HLBG._skipped_slashes = HLBG._skipped_slashes or {}
        table.insert(HLBG._skipped_slashes, { key = key, cmd = cmd, reason = 'in use' })
        return false
    end
    -- create global SLASH_<KEY>1 token and attach handler
    _G["SLASH_"..key.."1"] = cmd
    SlashCmdList[key] = handler
    -- record registration
    HLBG._registered_slashes = HLBG._registered_slashes or {}
    table.insert(HLBG._registered_slashes, { key = key, cmd = cmd })
    return true
end

-- expose helper so UI modules can register safely when loaded earlier/later
HLBG.safeRegisterSlash = safeRegisterSlash
-- Safe exec for slash-like client commands. Prefer calling registered SlashCmdList handlers
-- (useful on older clients where SendChatCommand isn't available).
function HLBG.safeExecSlash(cmd)
    if type(cmd) ~= 'string' then return false end
    local orig = cmd
    local s = cmd:gsub('^%s+', '')
    -- strip leading dot used in some callsites
    if s:sub(1,1) == '.' then s = s:sub(2) end
    -- split verb and rest
    local verb, rest = s:match('^(%S+)%s*(.*)$')
    if not verb then return false end
    -- prefer direct SlashCmdList lookup
    local key = verb:upper()
    if SlashCmdList and type(SlashCmdList[key]) == 'function' then pcall(SlashCmdList[key], rest or '') ; return true end
    -- try our unique token first to avoid collisions
    if SlashCmdList and type(SlashCmdList['HLBGHUD']) == 'function' then
        local lower = verb:lower()
        if lower == 'hlbg' or lower == 'hinterland' or lower == 'hbg' or lower == 'hlbghud' or lower == 'zhlbg' then
            pcall(SlashCmdList['HLBGHUD'], rest or '') ; return true
        end
    end
    -- common HLBG alias
    if verb:lower() == 'hlbg' and SlashCmdList and type(SlashCmdList['HLBG']) == 'function' then pcall(SlashCmdList['HLBG'], rest or '') ; return true end
    -- last resort: call our main handler directly if present
    if type(HLBG._MainSlashHandler) == 'function' and (verb:lower() == 'hlbg' or verb:lower() == 'hinterland' or verb:lower()=='hbg') then
        pcall(HLBG._MainSlashHandler, rest or '')
        return true
    end
    -- fallback: try sending as a chat message so server-side handler can catch it (e.g., .hlbg ...)
    if type(SendChatMessage) == 'function' then
        local ok = pcall(SendChatMessage, orig, "SAY")
        if ok then return true end
    end
    -- optional: try RunScript (rarely useful for dot-commands but harmless)
    if type(RunScript) == 'function' then pcall(RunScript, s) ; return true end
    -- last fallback: notify user
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('HLBG: cannot execute command: '..tostring(cmd)) end
    return false
end
-- Send a raw dot-command to the server without invoking our local SlashCmdList
function HLBG.SendServerDot(cmd)
    if type(cmd) ~= 'string' or cmd == '' then return false end
    local out = cmd
    if out:sub(1,1) ~= '.' then out = '.'..out end
    if type(SendChatMessage) == 'function' then
        local ok = pcall(SendChatMessage, out, "SAY")
        return ok and true or false
    end
    return false
end
-- Provide a stable global alias so calls still work if the HLBG table is replaced by AIO
_G.HLBG_SendServerDot = HLBG.SendServerDot
-- Note: AIO handlers are registered after all functions are defined (see bottom)

-- Ensure a UI container table exists early to avoid nil-index errors from blocks that attach UI elements.
HLBG.UI = HLBG.UI or {}

-- Chat helper honoring the "disable chat updates" option
function HLBG._chat(msg, force)
    if not msg then return end
    if HinterlandAffixHUDDB and HinterlandAffixHUDDB.disableChatUpdates and not force then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(tostring(msg)) end
end

-- Minimal UI bootstrap (fallback) so handlers can render when a separate UI module isn't loaded
function HLBG._bootstrapUI()
    if HLBG.UI and HLBG.UI._boot then return true end
    HLBG.UI = HLBG.UI or {}
    -- Main frame
    local f = CreateFrame('Frame', 'HLBG_FallbackFrame', UIParent)
    f:SetSize(520, 360)
    f:SetPoint('CENTER')
    f:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background', edgeFile = 'Interface/Tooltips/UI-Tooltip-Border', tile = true, tileSize = 16, edgeSize = 16, insets = { left=4, right=4, top=4, bottom=4 } })
    f:SetBackdropColor(0,0,0,0.5)
    f:Hide()
    -- Title and close
    local title = f:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', 16, -12)
    title:SetText('Hinterland Battleground')
    local close = CreateFrame('Button', nil, f, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', f, 'TOPRIGHT', 0, 0)
    if type(UISpecialFrames) == 'table' then table.insert(UISpecialFrames, f:GetName()) end
    HLBG.UI.Frame = f

    -- Tabs (Live/History/Stats/Queue/Affixes)
    -- IMPORTANT: PanelTemplates_* APIs expect tabs to be named FrameName.."Tab"..index
    -- so for frame name HLBG_FallbackFrame the buttons must be HLBG_FallbackFrameTab1..N
    local tabs = {}
    local function makeTab(idx, text)
        local b = CreateFrame('Button', f:GetName()..'Tab'..idx, f, 'OptionsFrameTabButtonTemplate')
        if idx == 1 then b:SetPoint('TOPLEFT', f, 'BOTTOMLEFT', 10, 7) else b:SetPoint('LEFT', tabs[idx-1], 'RIGHT') end
        b:SetText(text)
        tabs[idx] = b
        return b
    end
    makeTab(1, 'Live'); makeTab(2, 'History'); makeTab(3, 'Stats'); makeTab(4, 'Queue'); makeTab(5, 'Affixes')
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, 5); PanelTemplates_SetTab(f, 1) end

    -- Containers
    local function makePane()
        local p = CreateFrame('Frame', nil, f)
        p:SetPoint('TOPLEFT', 12, -40)
        p:SetPoint('BOTTOMRIGHT', -12, 12)
        p:Hide()
        return p
    end
    -- Live
    HLBG.UI.Live = HLBG.UI.Live or makePane()
    -- plug in Live widgets if not present yet
    pcall(function() if type(HLBG.EnsureLiveUI) == 'function' then HLBG.EnsureLiveUI() end end)
    -- History
    if not HLBG.UI.History then
        local h = makePane()
        HLBG.UI.History = h
        -- Scroll area
        h.Scroll = CreateFrame('ScrollFrame', 'HLBG_FallbackHistoryScroll', h, 'UIPanelScrollFrameTemplate')
        h.Scroll:SetPoint('TOPLEFT', 0, 0)
        h.Scroll:SetPoint('BOTTOMRIGHT', -28, 0)
        h.Content = CreateFrame('Frame', nil, h.Scroll)
        h.Content:SetSize(460, 300)
        h.Scroll:SetScrollChild(h.Content)
        h.rows = {}
        -- Pager
        h.Nav = CreateFrame('Frame', nil, h)
        h.Nav:SetSize(200, 22)
        h.Nav:SetPoint('BOTTOMRIGHT', -6, -2)
        h.Nav.Prev = CreateFrame('Button', nil, h.Nav, 'UIPanelButtonTemplate')
        h.Nav.Prev:SetSize(60, 22)
        h.Nav.Prev:SetPoint('LEFT')
        h.Nav.Prev:SetText('Prev')
        h.Nav.Next = CreateFrame('Button', nil, h.Nav, 'UIPanelButtonTemplate')
        h.Nav.Next:SetSize(60, 22)
        h.Nav.Next:SetPoint('LEFT', h.Nav.Prev, 'RIGHT', 8, 0)
        h.Nav.Next:SetText('Next')
        h.Nav.PageText = h.Nav:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        h.Nav.PageText:SetPoint('LEFT', h.Nav.Next, 'RIGHT', 8, 0)
    h.per = h.per or 10
        h.Nav.Prev:SetScript('OnClick', function()
            local p = tonumber(h.page or 1) or 1; if p > 1 then p = p - 1 end
            if _G.AIO and _G.AIO.Handle then
                local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
                local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
                local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
                _G.AIO.Handle('HLBG','Request','HISTORY', p, h.per or 10, h.sortKey or 'id', h.sortDir or 'ASC', wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            end
        end)
        h.Nav.Next:SetScript('OnClick', function()
            local p = (tonumber(h.page or 1) or 1) + 1
            if _G.AIO and _G.AIO.Handle then
                local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
                local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
                local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
                _G.AIO.Handle('HLBG','Request','HISTORY', p, h.per or 10, h.sortKey or 'id', h.sortDir or 'ASC', wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            end
        end)
    end
    -- Stats
    if not HLBG.UI.Stats then
        local s = makePane()
        HLBG.UI.Stats = s
        s.Text = s:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        s.Text:SetPoint('TOPLEFT', 0, 0)
        s.Text:SetWidth(480)
    end
    -- Queue (top-level)
    if not HLBG.UI.QueuePane then
        local q = makePane()
        HLBG.UI.QueuePane = q
        q.Title = q:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        q.Title:SetPoint('TOPLEFT', 0, 0)
        q.Title:SetText('Queue')
        q.Status = q:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
        q.Status:SetPoint('TOPLEFT', q.Title, 'BOTTOMLEFT', 0, -8)
        q.Status:SetText('Queue status: -')
        q.Counts = q:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        q.Counts:SetPoint('TOPLEFT', q.Status, 'BOTTOMLEFT', 0, -6)
        q.Counts:SetText('Queued: Alliance 0 | Horde 0 | Total 0')
        q.Join = CreateFrame('Button', nil, q, 'UIPanelButtonTemplate')
        q.Join:SetSize(90, 20)
        q.Join:SetPoint('LEFT', q.Status, 'RIGHT', 12, 0)
        q.Join:SetText('Join')
        q.Leave = CreateFrame('Button', nil, q, 'UIPanelButtonTemplate')
        q.Leave:SetSize(90, 20)
        q.Leave:SetPoint('LEFT', q.Join, 'RIGHT', 8, 0)
        q.Leave:SetText('Leave')
        q.Join:SetScript('OnClick', function()
            if HLBG and type(HLBG.RequestQueue) == 'function' then HLBG.RequestQueue('JOIN') end
            if q.Status then q.Status:SetText('Queue status: requesting join…') end
        end)
        q.Leave:SetScript('OnClick', function()
            if HLBG and type(HLBG.RequestQueue) == 'function' then HLBG.RequestQueue('LEAVE') end
            if q.Status then q.Status:SetText('Queue status: requesting leave…') end
        end)
    end
    -- Affixes (top-level)
    if not HLBG.UI.AffixPane then
        local a = makePane()
        HLBG.UI.AffixPane = a
        a.Title = a:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
        a.Title:SetPoint('TOPLEFT', 0, 0)
        a.Title:SetText('Affixes')
        -- Search box
        a.Search = CreateFrame('EditBox', nil, a, 'InputBoxTemplate')
        a.Search:SetAutoFocus(false)
        a.Search:SetSize(200, 20)
        a.Search:SetPoint('TOPLEFT', a.Title, 'BOTTOMLEFT', 0, -8)
        a.Search:SetText(HinterlandAffixHUDDB and (HinterlandAffixHUDDB.affixSearch or '') or '')
        a.SearchLbl = a:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        a.SearchLbl:SetPoint('RIGHT', a.Search, 'LEFT', -6, 0)
        a.SearchLbl:SetText('Search:')
        a.Search:SetScript('OnEnterPressed', function(self)
            HinterlandAffixHUDDB.affixSearch = self:GetText() or ''
            self:ClearFocus()
            if HLBG and type(HLBG.RequestAffixes) == 'function' then HLBG.RequestAffixes() end
        end)
        -- Scroll content
        a.Scroll = CreateFrame('ScrollFrame', nil, a, 'UIPanelScrollFrameTemplate')
        a.Scroll:SetPoint('TOPLEFT', a.Search, 'BOTTOMLEFT', 0, -6)
        a.Scroll:SetPoint('BOTTOMRIGHT', -26, 0)
        a.Content = CreateFrame('Frame', nil, a.Scroll)
        a.Content:SetSize(440, 300)
        a.Scroll:SetScrollChild(a.Content)
        a.Rows = {}
    end

    -- Tab switching
    local function showTab(i)
        if PanelTemplates_SetTab then PanelTemplates_SetTab(f, i) end
        if HLBG.UI.Live then HLBG.UI.Live:SetShown(i==1) end
        if HLBG.UI.History then HLBG.UI.History:SetShown(i==2) end
        if HLBG.UI.Stats then HLBG.UI.Stats:SetShown(i==3) end
        if HLBG.UI.QueuePane then HLBG.UI.QueuePane:SetShown(i==4) end
        if HLBG.UI.AffixPane then HLBG.UI.AffixPane:SetShown(i==5) end
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.lastInnerTab = i
        if i == 1 then
            if _G.AIO and _G.AIO.Handle then _G.AIO.Handle('HLBG','Request','STATUS') end
        elseif i == 4 then
            -- ask server for current queue status when the tab is shown
            if HLBG and type(HLBG.RequestQueue) == 'function' then HLBG.RequestQueue('STATUS') end
        elseif i == 2 then
            -- ensure history loads when History tab is shown
            if _G.AIO and _G.AIO.Handle then
                local h = HLBG.UI.History
                local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
                _G.AIO.Handle('HLBG','Request','HISTORY', h.page or 1, h.per or 10, h.sortKey or 'id', h.sortDir or 'ASC')
            end
        elseif i == 3 then
            -- ensure stats loads when Stats tab is shown
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle('HLBG','Request','STATS')
            end
        elseif i == 5 then
            if HLBG and type(HLBG.RequestAffixes) == 'function' then HLBG.RequestAffixes() end
        end
    end
    for i=1,#tabs do tabs[i]:SetScript('OnClick', function() showTab(i) end) end
    HLBG.ShowTab = showTab
    -- Only set the global if it's not already provided by the full UI module
    if type(_G.ShowTab) ~= 'function' then _G.ShowTab = showTab end
    HLBG.UI._boot = true
    return true
end

function HLBG._ensureUI(kind)
    -- Prefer the full UI if it already constructed a frame/tabs
    if HLBG.UI and HLBG.UI.Frame and (HLBG.UI.Tabs and #HLBG.UI.Tabs > 0 or HLBG.UI.Live or HLBG.UI.History or HLBG.UI.Stats) then
        return true
    end
    -- Otherwise build the minimal fallback once
    return HLBG._bootstrapUI()
end

-- Safe helpers used throughout the UI code (stubs when APIs are missing on older clients)
function HLBG.safeSetJustify(fs, dir)
    if not fs or type(fs) ~= 'table' then return end
    local ok = pcall(function()
        if fs.SetJustifyH and (dir == 'LEFT' or dir == 'CENTER' or dir == 'RIGHT') then fs:SetJustifyH(dir) end
    end)
    return ok and true or false
end

-- Zone helpers used by AFK/warmup logic
local function InHinterlands()
    local z = (type(GetRealZoneText) == 'function' and (GetRealZoneText() or '')) or ''
    return z == 'The Hinterlands'
end
HLBG.safeGetRealZoneText = function()
    return (type(GetRealZoneText) == 'function' and (GetRealZoneText() or '')) or ''
end

-- Safe affix-name lookup using maps populated by server AFFIXES or local defaults
if type(HLBG.GetAffixName) ~= 'function' then
    function HLBG.GetAffixName(code)
        if code == nil then return '-' end
        local names = _G.HLBG_AFFIX_NAMES or {}
        local n = names[code]
        if n then return tostring(n) end
        -- try numeric key as string
        local num = tonumber(code)
        if num and names[num] then return tostring(names[num]) end
        -- last resort: echo the code
        return tostring(code)
    end
end

-- Map position helper (gracefully degrades to nil)
function HLBG.safeGetPlayerMapPosition(unit)
    unit = unit or 'player'
    if type(GetPlayerMapPosition) == 'function' then
        local x, y = GetPlayerMapPosition(unit)
        return x, y
    end
    return nil, nil
end

-- Dev helper: probe a list of WoW API globals and write availability into saved debug log
function HLBG.RunStartupApiProbe()
    if not HLBG._devMode then return end
    HinterlandAffixHUD_DebugLog = HinterlandAffixHUD_DebugLog or {}
    local apis = {
        'IsInInstance', 'GetInstanceType', 'GetInstanceInfo', 'GetRealZoneText', 'GetZoneText',
        'GetNumWorldStateUI', 'GetWorldStateUIInfo', 'GetPlayerMapPosition', 'SendChatMessage'
    }
    local out = { ts = date('%Y-%m-%d %H:%M:%S'), results = {} }
    for _, name in ipairs(apis) do
        local ok, available = pcall(function() return type(_G[name]) == 'function' end)
        table.insert(out.results, { api = name, available = ok and available or false })
    end
    do
        local parts = {}
        for i, r in ipairs(out.results) do parts[#parts+1] = r.api .. '=' .. (r.available and '1' or '0') end
        table.insert(HinterlandAffixHUD_DebugLog, 1, string.format('[%s] API_PROBE %s', out.ts, table.concat(parts, ',')))
    end
    while #HinterlandAffixHUD_DebugLog > 200 do table.remove(HinterlandAffixHUD_DebugLog) end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('HLBG: RunStartupApiProbe written to HinterlandAffixHUD_DebugLog') end
end

-- Run a probe at load if devMode is enabled (helps catch missing APIs quickly)
pcall(function() if HLBG._devMode then HLBG.RunStartupApiProbe() end end)

-- Attempt to load split modules early when running in a dev environment where files are present.
-- In-game WoW loads files according to the .toc order, but this helps the VSCode workflow.
pcall(function()
    -- UI is now extracted into HLBG_UI.lua. Provide light bridge helpers in case the module wasn't loaded yet.
    if type(_G.ShowTab) ~= 'function' then
        -- Define a non-recursive bridge and assign it to the global; the real ShowTab from UI will override this later
        local function showtab_bridge(i)
            if HLBG and HLBG.UI and HLBG.UI.Frame and type(HLBG.UI.Frame.Show) == 'function' then HLBG.UI.Frame:Show() end
            HinterlandAffixHUDDB.lastInnerTab = i
        end
        _G.ShowTab = showtab_bridge
    end
    local function quickRegister()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then return false end
        reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
        reg.Warmup     = HLBG.Warmup
        reg.QueueStatus= HLBG.QueueStatus
        reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
        reg.HISTORY    = reg.History
    end

    -- Guarded tweak of Info text if UI is already present
    if HLBG and HLBG.UI and HLBG.UI.Info and HLBG.UI.Info.Text then
        HLBG.safeSetJustify(HLBG.UI.Info.Text, "LEFT")
        HLBG.UI.Info.Text:SetWidth(460)
    end
    -- Close the pcall started above; the following helpers are defined outside of this guarded block
end)
local function BuildInfoText()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local minLevel = HinterlandAffixHUDDB.minLevel or 1
    local rewards = HinterlandAffixHUDDB.rewardsText or "Honor, XP, custom tokens"
    local settings = {
        string.format("Addon HUD: %s", HinterlandAffixHUDDB.useAddonHud and "On" or "Off"),
        string.format("AFK warning: %s", HinterlandAffixHUDDB.enableAFKWarning and "On" or "Off"),
        string.format("Warmup prompt: %s", HinterlandAffixHUDDB.enableWarmupCTA and "On" or "Off"),
    }
    local lines = {
        "Hinterland Battleground (HLBG)",
        " ",
        "Features:",
        "- Movable worldstate HUD (resources/timer/affix)",
    }
    if HLBG._devMode then
            safeRegisterSlash('HLBGFAKE', '/hlbgfake', function()
                local fakeRows = {
                    { id = "101", ts = date("%Y-%m-%d %H:%M:%S"), winner = "Alliance", affix = "3", reason = "Score", duration = 1200 },
                    { id = "100", ts = date("%Y-%m-%d %H:%M:%S"), winner = "Horde", affix = "5", reason = "Timer", duration = 900 },
                }
                HLBG.History(fakeRows, 1, 3, 11, "id", "DESC")
                if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.Show then HLBG.UI.Frame:Show() end; ShowTab(2)
            end)

            -- Dump last LIVE payload saved to saved-variables for offline inspection
            safeRegisterSlash('HLBGLIVEDUMP', '/hlbglivedump', function()
                local dump = HinterlandAffixHUD_LastLive
                if not dump then
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: no saved LIVE payload")
                    return
                end
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: LastLive ts=%s rows=%d", tostring(dump.ts or "?"), tonumber(dump.rows and #dump.rows or 0) or 0))
                if dump.rows and type(dump.rows) == "table" then
                    for i,row in ipairs(dump.rows) do
                        local name = row.name or row[3] or row[1] or "?"
                        local score = row.score or row[5] or row[2] or 0
                        DEFAULT_CHAT_FRAME:AddMessage(string.format("%d: %s = %s", i, tostring(name), tostring(score)))
                    end
                end
            end)

            -- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
            function HLBG.RunJsonDecodeTests()
                if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

                -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
                local largeN = 200
                local parts = {}
                for i=1,largeN do parts[#parts+1] = tostring(i) end
                local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

                local tests = {
                    { name = 'null', input = 'null', expectError = false, expected = nil },
                    { name = 'true', input = 'true', expectError = false, expected = true },
                    { name = 'false', input = 'false', expectError = false, expected = false },
                    { name = 'number', input = '123', expectError = false, expected = 123 },
                    { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
                    { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
                    { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
                    { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
                    { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
                    { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
                    { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
                    { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
                    { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
                    { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
                }

                local function deepEqual(a,b)
                    if type(a) ~= type(b) then return false end
                    if type(a) ~= 'table' then return a == b end
                    local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
                    local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
                    table.sort(ka); table.sort(kb)
                    if #ka ~= #kb then return false end
                    for i=1,#ka do if ka[i] ~= kb[i] then return false end end
                    for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
                    return true
                end

                local function shortRepr(v)
                    local t = type(v)
                    if t == 'nil' then return 'nil' end
                    if t == 'string' then return string.format('"%s"', tostring(v)) end
                    if t == 'number' or t == 'boolean' then return tostring(v) end
                    if t == 'table' then
                        if #v and #v > 0 then return string.format('<array len=%d>', #v) end
                        return '<object>'
                    end
                    return '<'..t..'>'
                end

                -- saved variable container for persisted test results
                HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
                local run = { ts = time(), results = {} }

                local passed = 0
                for i, t in ipairs(tests) do
                    local res, err = json_decode(t.input)
                    local ok
                    if t.expectError then
                        ok = (err ~= nil)
                    else
                        if err ~= nil then ok = false else
                            if t.expectedLen then
                                ok = (type(res) == 'table' and #res == t.expectedLen)
                            else
                                ok = deepEqual(res, t.expected)
                            end
                        end
                    end
                    if ok then passed = passed + 1 end
                    local out = shortRepr(res)
                    table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
                    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
                end

                run.summary = string.format('%d/%d', passed, #tests)
                table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
                -- keep last 20 runs
                while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

                DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
            end

            safeRegisterSlash('HLBGJSONTEST', '/hlbgjsontest', function() pcall(HLBG.RunJsonDecodeTests) end)

            -- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
            function HLBG.PrintJsonTestRun(n)
                n = tonumber(n) or 1
                if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
                    return
                end
                if n < 1 then n = 1 end
                if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
                local run = HinterlandAffixHUD_JsonTestResults[n]
                if not run then
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
                    return
                end
                local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
                    for i, r in ipairs(run.results or {}) do
                        local ok = r.pass and "PASS" or "FAIL"
                        local info = string.format("%d) %s: %s", i, r.name or "?", ok)
                        if r.error then info = info .. " - error: " .. tostring(r.error) end
                        if r.output then info = info .. " - output: " .. tostring(r.output) end
                        if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
                        DEFAULT_CHAT_FRAME:AddMessage(info)
                    end
                end
            end

            -- Debug: local fake data to validate rendering path without server
            -- (dev) /hlbgfake registered above via safeRegisterSlash

            -- Dump last LIVE payload saved to saved-variables for offline inspection
            -- (dev) /hlbglivedump registered above via safeRegisterSlash

            -- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
            function HLBG.RunJsonDecodeTests()
                if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

                -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
                local largeN = 200
                local parts = {}
                for i=1,largeN do parts[#parts+1] = tostring(i) end
                local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

                local tests = {
                    { name = 'null', input = 'null', expectError = false, expected = nil },
                    { name = 'true', input = 'true', expectError = false, expected = true },
                    { name = 'false', input = 'false', expectError = false, expected = false },
                    { name = 'number', input = '123', expectError = false, expected = 123 },
                    { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
                    { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
                    { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
                    { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
                    { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
                    { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
                    { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
                    { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
                    { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
                    { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
                }

                local function deepEqual(a,b)
                    if type(a) ~= type(b) then return false end
                    if type(a) ~= 'table' then return a == b end
                    local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
                    local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
                    table.sort(ka); table.sort(kb)
                    if #ka ~= #kb then return false end
                    for i=1,#ka do if ka[i] ~= kb[i] then return false end end
                    for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
                    return true
                end

                local function shortRepr(v)
                    local t = type(v)
                    if t == 'nil' then return 'nil' end
                    if t == 'string' then return string.format('"%s"', tostring(v)) end
                    if t == 'number' or t == 'boolean' then return tostring(v) end
                    if t == 'table' then
                        if #v and #v > 0 then return string.format('<array len=%d>', #v) end
                        return '<object>'
                    end
                    return '<'..t..'>'
                end

                -- saved variable container for persisted test results
                HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
                local run = { ts = time(), results = {} }

                local passed = 0
                for i, t in ipairs(tests) do
                    local res, err = json_decode(t.input)
                    local ok
                    if t.expectError then
                        ok = (err ~= nil)
                    else
                        if err ~= nil then ok = false else
                            if t.expectedLen then
                                ok = (type(res) == 'table' and #res == t.expectedLen)
                            else
                                ok = deepEqual(res, t.expected)
                            end
                        end
                    end
                    if ok then passed = passed + 1 end
                    local out = shortRepr(res)
                    table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
                    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
                end

                run.summary = string.format('%d/%d', passed, #tests)
                table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
                -- keep last 20 runs
                while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

                DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
            end

            safeRegisterSlash('HLBGJSONTEST', '/hlbgjsontest', function() pcall(HLBG.RunJsonDecodeTests) end)

            -- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
            function HLBG.PrintJsonTestRun(n)
                n = tonumber(n) or 1
                if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
                    return
                end
                if n < 1 then n = 1 end
                if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
                local run = HinterlandAffixHUD_JsonTestResults[n]
                if not run then
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
                    return
                end
                local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
                    for i, r in ipairs(run.results or {}) do
                        local ok = r.pass and "PASS" or "FAIL"
                        local info = string.format("%d) %s: %s", i, r.name or "?", ok)
                        if r.error then info = info .. " - error: " .. tostring(r.error) end
                        if r.output then info = info .. " - output: " .. tostring(r.output) end
                        if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
                        DEFAULT_CHAT_FRAME:AddMessage(info)
                    end
                end
            end

            -- Debug: local fake data to validate rendering path without server
            -- (dev) /hlbgfake registered above via safeRegisterSlash

            -- Dump last LIVE payload saved to saved-variables for offline inspection
            -- (dev) /hlbglivedump registered above via safeRegisterSlash

            -- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
            function HLBG.RunJsonDecodeTests()
                if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

                -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
                local largeN = 200
                local parts = {}
                for i=1,largeN do parts[#parts+1] = tostring(i) end
                local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

                local tests = {
                    { name = 'null', input = 'null', expectError = false, expected = nil },
                    { name = 'true', input = 'true', expectError = false, expected = true },
                    { name = 'false', input = 'false', expectError = false, expected = false },
                    { name = 'number', input = '123', expectError = false, expected = 123 },
                    { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
                    { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
                    { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
                    { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
                    { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
                    { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
                    { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
                    { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
                    { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
                    { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
                }

                local function deepEqual(a,b)
                    if type(a) ~= type(b) then return false end
                    if type(a) ~= 'table' then return a == b end
                    local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
                    local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
                    table.sort(ka); table.sort(kb)
                    if #ka ~= #kb then return false end
                    for i=1,#ka do if ka[i] ~= kb[i] then return false end end
                    for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
                    return true
                end

                local function shortRepr(v)
                    local t = type(v)
                    if t == 'nil' then return 'nil' end
                    if t == 'string' then return string.format('"%s"', tostring(v)) end
                    if t == 'number' or t == 'boolean' then return tostring(v) end
                    if t == 'table' then
                        if #v and #v > 0 then return string.format('<array len=%d>', #v) end
                        return '<object>'
                    end
                    return '<'..t..'>'
                end

                -- saved variable container for persisted test results
                HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
                local run = { ts = time(), results = {} }

                local passed = 0
                for i, t in ipairs(tests) do
                    local res, err = json_decode(t.input)
                    local ok
                    if t.expectError then
                        ok = (err ~= nil)
                    else
                        if err ~= nil then ok = false else
                            if t.expectedLen then
                                ok = (type(res) == 'table' and #res == t.expectedLen)
                            else
                                ok = deepEqual(res, t.expected)
                            end
                        end
                    end
                    if ok then passed = passed + 1 end
                    local out = shortRepr(res)
                    table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
                    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
                end

                run.summary = string.format('%d/%d', passed, #tests)
                table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
                -- keep last 20 runs
                while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

                DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
            end

            safeRegisterSlash('HLBGJSONTEST', '/hlbgjsontest', function() pcall(HLBG.RunJsonDecodeTests) end)

            -- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
            function HLBG.PrintJsonTestRun(n)
                n = tonumber(n) or 1
                if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
                    return
                end
                if n < 1 then n = 1 end
                if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
                local run = HinterlandAffixHUD_JsonTestResults[n]
                if not run then
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
                    return
                end
                local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
                    for i, r in ipairs(run.results or {}) do
                        local ok = r.pass and "PASS" or "FAIL"
                        local info = string.format("%d) %s: %s", i, r.name or "?", ok)
                        if r.error then info = info .. " - error: " .. tostring(r.error) end
                        if r.output then info = info .. " - output: " .. tostring(r.output) end
                        if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
                        DEFAULT_CHAT_FRAME:AddMessage(info)
                    end
                end
            end
        end
    end

-- /hlbgjsontest registered above via safeRegisterSlash

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end

-- Debug: local fake data to validate rendering path without server
-- (dev) /hlbgfake registered above via safeRegisterSlash

-- Dump last LIVE payload saved to saved-variables for offline inspection
-- (dev) /hlbglivedump registered above via safeRegisterSlash

-- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }

    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end

    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end

    -- saved variable container for persisted test results
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
    local run = { ts = time(), results = {} }

    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
    end

    run.summary = string.format('%d/%d', passed, #tests)
    table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
end

-- /hlbgjsontest registered above via safeRegisterSlash

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end

-- Debug: local fake data to validate rendering path without server
-- (dev) /hlbgfake registered above via safeRegisterSlash

-- Dump last LIVE payload saved to saved-variables for offline inspection
-- (dev) /hlbglivedump registered above via safeRegisterSlash

-- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }

    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end

    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end

    -- saved variable container for persisted test results
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
    local run = { ts = time(), results = {} }

    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
    end

    run.summary = string.format('%d/%d', passed, #tests)
    table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
end

-- /hlbgjsontest registered above via safeRegisterSlash

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end

-- Startup diagnostic: print a compact status line so it's easy to see what initialized
do
    local function startupDiag()
        local haveAIO = (_G.AIO and _G.AIO.AddHandlers) and true or false
        local handlersBound = (type(HLBG) == 'table' and (type(HLBG.History) == 'function' or type(HLBG.HISTORY) == 'function')) and true or false
        local uiPresent = (type(HLBG) == 'table' and type(HLBG.UI) == 'table') or (type(UI) == 'table')
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG STARTUP: AIO=%s handlers=%s UI=%s", tostring(haveAIO), tostring(handlersBound), tostring(uiPresent)))
        if not uiPresent and type(UI) == 'table' then DEFAULT_CHAT_FRAME:AddMessage("HLBG STARTUP: attaching local UI to HLBG") ; HLBG.UI = UI end
        -- Print and persist slash registration summary if available
        local regParts = {}
        if HLBG._registered_slashes and #HLBG._registered_slashes > 0 then
            for _,s in ipairs(HLBG._registered_slashes) do table.insert(regParts, tostring(s.cmd)) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: registered slashes -> " .. table.concat(regParts, ", "))
        end
        local skipParts = {}
        if HLBG._skipped_slashes and #HLBG._skipped_slashes > 0 then
            for _,s in ipairs(HLBG._skipped_slashes) do table.insert(skipParts, string.format("%s (%s)", tostring(s.cmd), tostring(s.reason))) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: skipped slashes -> " .. table.concat(skipParts, ", "))
        end
        -- Persist a compact startup summary for later inspection (keep last 20)
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.startupHistory = HinterlandAffixHUDDB.startupHistory or {}
        local entry = { ts = time(), aio = haveAIO, handlers = handlersBound, ui = uiPresent, registered = regParts, skipped = skipParts }
        table.insert(HinterlandAffixHUDDB.startupHistory, 1, entry)
        while #HinterlandAffixHUDDB.startupHistory > 20 do table.remove(HinterlandAffixHUDDB.startupHistory) end
        -- provide helper to print startup history
        function HLBG.PrintStartupHistory(n)
            n = tonumber(n) or 1
            local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory or nil
            if not hist or #hist == 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('HLBG: no startup history saved') end
                return
            end
            if n < 1 then n = 1 end
            if n > #hist then n = #hist end
            local e = hist[n]
            if not e then return end
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
                if e.registered and #e.registered > 0 then DEFAULT_CHAT_FRAME:AddMessage(' registered: '..table.concat(e.registered, ', ')) end
                if e.skipped and #e.skipped > 0 then DEFAULT_CHAT_FRAME:AddMessage(' skipped: '..table.concat(e.skipped, ', ')) end
            end
        end
        -- add a small button in Interface Options to show the last startup history
        if opt and type(opt.CreateFontString) == 'function' then
            local btn = CreateFrame('Button', nil, opt, 'UIPanelButtonTemplate')
            btn:SetSize(160, 22)
            btn:SetPoint('TOPLEFT', cbDev, 'BOTTOMLEFT', 0, -16)
            btn:SetText('Show startup history')
            btn:SetScript('OnClick', function() pcall(HLBG.PrintStartupHistory, 1) end)
        end
    end
    -- Delay a tick so ADDON_LOADED messages can arrive first
    local tfr = CreateFrame('Frame')
    local t = 0
    tfr:SetScript('OnUpdate', function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 0.5 then
            startupDiag()
            self:SetScript('OnUpdate', nil)
        end
    end)
end

-- Ensure we have a valid UI parent for the main frame (UIParent as fallback)
if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.SetParent then
    HLBG.UI.Frame:SetParent(UIParent)
end

-- Request initial data from server (HISTORY/STATS/AFFIXES/QUEUE STATUS)
if _G.AIO and _G.AIO.Handle then
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
    local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
    _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
    _G.AIO.Handle("HLBG", "Request", "STATS")
    _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
    _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
    _G.AIO.Handle("HLBG", "Request", "STATUS")
end

-- Minimal AFK warning stub (client-side only, non-invasive)
do
    local afkTimer, afkAccum = nil, 0
    local lastX, lastY, lastTime = nil, nil, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
        if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.enableAFKWarning then return end
        afkAccum = afkAccum + (elapsed or 0)
        if afkAccum < 5.0 then return end -- check every 5s
        afkAccum = 0
        local inBG = InHinterlands()
        if not inBG then return end
        -- approximate movement using map position if available (use safe wrapper when present)
        local x,y = 0,0
        if type(HLBG) == 'table' and type(HLBG.safeGetPlayerMapPosition) == 'function' then
            local px, py = HLBG.safeGetPlayerMapPosition("player")
            if px and py then x,y = px,py end
        end
        local moved = (lastX == nil or math.abs((x - (lastX or 0))) > 0.001 or math.abs((y - (lastY or 0))) > 0.001)
        local now = time()
        if moved then lastX, lastY, lastTime = x, y, now; return end
        -- no movement; if more than N seconds, warn
        local idleSec = now - (lastTime or now)
        local threshold = (HinterlandAffixHUDDB.afkWarnSeconds or 120)
        if idleSec >= threshold then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00HLBG|r: You seem AFK. Please move or you may be removed.")
            -- reset timer to avoid spamming
            lastTime = now - (threshold/2)
        end
    end)
end

-- Slash to open HLBG window even if server AIO command isn't available
-- Provide a minimal OpenUI fallback if not defined by UI module
if type(HLBG.OpenUI) ~= 'function' then
    function HLBG.OpenUI()
        if HLBG and HLBG.UI and HLBG.UI.Frame and type(HLBG.UI.Frame.Show) == 'function' then HLBG.UI.Frame:Show() end
        local last = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastInnerTab) or 1
        if type(_G.ShowTab) == 'function' then pcall(_G.ShowTab, last) end
        if _G.AIO and _G.AIO.Handle then _G.AIO.Handle('HLBG','Request','STATUS') end
    end
end

-- Minimal Live handler: render resources and timer from last status payload
if type(HLBG.Live) ~= 'function' then
function HLBG.Live(payload)
    -- Accept either raw status or rows list; prefer status already collected via chat/AIO
    HLBG._ensureUI('Live')
    HLBG.UpdateLiveFromStatus()
end
end

-- AIO Status handler: update RES/_affixText and refresh HUD + Live summary
if type(HLBG.Status) ~= 'function' then
function HLBG.Status(payload)
    if type(payload) ~= 'table' then return end
    _G.RES = _G.RES or {}
    RES.A = tonumber(payload.A or payload.a or 0) or 0
    RES.H = tonumber(payload.H or payload.h or 0) or 0
    RES.END = tonumber(payload.END or payload.End or payload.end_ts or 0) or 0
    RES.LOCK = tonumber(payload.LOCK or payload.lock or 0) or 0
    HLBG._affixText = payload.AFF or payload.affix or HLBG._affixText
    HLBG._lastStatus = payload
    -- Normalize aliases for player counts
    if payload.APlayers or payload.APC then HLBG._lastStatus.APlayers = tonumber(payload.APlayers or payload.APC) or HLBG._lastStatus.APlayers end
    if payload.HPlayers or payload.HPC then HLBG._lastStatus.HPlayers = tonumber(payload.HPlayers or payload.HPC) or HLBG._lastStatus.HPlayers end
    -- draw
    if type(HLBG.UpdateLiveFromStatus) == 'function' then
        pcall(HLBG.UpdateLiveFromStatus)
    else
        -- Minimal Live mirror if HUD bridge isn't loaded yet
        local nowts = (type(date)=="function" and date("%Y-%m-%d %H:%M:%S")) or ""
        local rows = {
            { id = "A", ts = nowts, name = "Alliance", team = "Alliance", score = tonumber(RES.A or 0) or 0 },
            { id = "H", ts = nowts, name = "Horde", team = "Horde", score = tonumber(RES.H or 0) or 0 },
        }
        if type(HLBG.Live) == 'function' then pcall(HLBG.Live, rows) end
    end
end
end

-- Minimal Stats handler: show counts if provided; otherwise clear text
if type(HLBG.Stats) ~= 'function' then
function HLBG.Stats(stats)
    HLBG._ensureUI('Stats')
    stats = stats or {}
    local counts = stats.counts or {}
    local a = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
    local h = tonumber(counts.Horde or counts.HORDE or 0) or 0
    local d = tonumber(stats.draws or 0) or 0
    local avg = tonumber(stats.avgDuration or 0) or 0
    local lines = { string.format('Alliance: %d  Horde: %d  Draws: %d  Avg: %d min', a, h, d, math.floor(avg/60)) }
    -- Optional extras mirrored from server NPC stats
    if stats.total then table.insert(lines, string.format('Total records: %s', tostring(stats.total))) end
    if stats.currentStreakTeam and stats.currentStreakLen then
        table.insert(lines, string.format('Current streak: %s x%d', tostring(stats.currentStreakTeam), tonumber(stats.currentStreakLen) or 0))
    end
    if stats.longestStreakTeam and stats.longestStreakLen then
        table.insert(lines, string.format('Longest streak: %s x%d', tostring(stats.longestStreakTeam), tonumber(stats.longestStreakLen) or 0))
    end
    if stats.largestMargin then
        local lm = stats.largestMargin
        table.insert(lines, string.format('Largest margin: [%s] %s by %d (A:%d H:%d)', tostring(lm.ts or '?'), tostring(lm.winner or '?'), tonumber(lm.margin or 0) or 0, tonumber(lm.a or 0) or 0, tonumber(lm.h or 0) or 0))
    end
    if stats.medianMargin then
        table.insert(lines, string.format('Median margin: %d', tonumber(stats.medianMargin) or 0))
    end
    if type(stats.reasons) == 'table' then
        local r = stats.reasons
        local parts = {}
        for k,v in pairs(r) do parts[#parts+1] = string.format('%s:%s', tostring(k), tostring(v)) end
        if #parts > 0 then table.insert(lines, 'Reasons: '..table.concat(parts, ', ')) end
    end
    -- Per-affix summaries (compact)
    if type(stats.winRates) == 'table' then
        table.insert(lines, 'Win rates per affix:')
        local shown = 0
        for aff, r in pairs(stats.winRates) do
            if type(r) == 'table' and r.n and r.A and r.H and r.D then
                table.insert(lines, string.format('- %s: A:%.1f%% H:%.1f%% D:%.1f%% (n=%d)', tostring(aff), (r.A*100.0)/r.n, (r.H*100.0)/r.n, (r.D*100.0)/r.n, r.n))
                shown = shown + 1; if shown >= 5 then break end
            end
        end
    end
    local function top3Flexible(v)
        local items = {}
        if type(v) == 'table' then
            if #v > 0 then
                for i=1,#v do
                    local row = v[i]
                    local total = (tonumber(row.Alliance or row.A or 0) or 0) + (tonumber(row.Horde or row.H or 0) or 0) + (tonumber(row.DRAW or row.D or 0) or 0)
                    local label = row.weather or row.affix or tostring(i)
                    items[#items+1] = { label = label, total = total }
                end
            else
                for k,row in pairs(v) do
                    local total = (tonumber(row.Alliance or 0) or 0) + (tonumber(row.Horde or 0) or 0) + (tonumber(row.DRAW or 0) or 0)
                    items[#items+1] = { label = tostring(k), total = total }
                end
            end
        end
        table.sort(items, function(a,b) return a.total > b.total end)
        local out = {}
        for i=1,math.min(3,#items) do out[#out+1] = string.format('%s:%d', tostring(items[i].label), tonumber(items[i].total) or 0) end
        return table.concat(out, ', ')
    end
    if stats.byAffix and next(stats.byAffix) then table.insert(lines, 'Top Affixes: '..top3Flexible(stats.byAffix)) end
    if stats.byWeather and next(stats.byWeather) then table.insert(lines, 'Top Weather: '..top3Flexible(stats.byWeather)) end
    local function top3avg(map)
        local arr = {}
        for k,v in pairs(map or {}) do arr[#arr+1] = { k=k, v=tonumber(v.avg or v.Avg or 0) or 0 } end
        table.sort(arr, function(x,y) return x.v > y.v end)
        local out = {}
        for i=1,math.min(3,#arr) do out[#out+1] = string.format('%s:%d min', tostring(arr[i].k), math.floor((arr[i].v or 0)/60)) end
        return table.concat(out, ', ')
    end
    if stats.affixDur and next(stats.affixDur) then table.insert(lines, 'Slowest Affixes (avg): '..top3avg(stats.affixDur)) end
    if stats.weatherDur and next(stats.weatherDur) then table.insert(lines, 'Slowest Weather (avg): '..top3avg(stats.weatherDur)) end
    if type(stats.topWinners) == 'table' and #stats.topWinners > 0 then
        local items = {}
        for i=1,math.min(3,#stats.topWinners) do
            local r = stats.topWinners[i]
            items[#items+1] = string.format('%s:%d', tostring(r.name or r.Name or '?'), tonumber(r.wins or r.Wins or 0) or 0)
        end
        if #items > 0 then table.insert(lines, 'Top winners: '..table.concat(items, ', ')) end
    end
    if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then HLBG.UI.Stats.Text:SetText(table.concat(lines, '\n')) end
end
end

-- Minimal History handler: draws basic rows as received from server (id, ts, winner, affix, reason)
if type(HLBG.History) ~= 'function' then
function HLBG.History(rows, page, per, total, col, dir)
    if not HLBG._ensureUI('History') then return end
    rows = rows or {}
    -- Normalize array-of-rows: server sends named fields; fallback accepts array indices
    local h = HLBG.UI.History
    h.page = tonumber(page) or 1; h.per = tonumber(per) or 10; h.total = tonumber(total) or #rows; h.sortKey = col or 'id'; h.sortDir = dir or 'ASC'
    -- hide old rows
    for i=1,#h.rows do h.rows[i]:Hide() end
    local function getRow(i)
        local r = h.rows[i]
        if not r then
            r = CreateFrame('Frame', nil, h.Content)
            r:SetSize(460, 18)
            r.id = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.ts = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.win = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.aff = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.rea = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.id:SetPoint('LEFT', r, 'LEFT', 0, 0); r.id:SetWidth(50)
            r.ts:SetPoint('LEFT', r.id, 'RIGHT', 6, 0); r.ts:SetWidth(156)
            r.win:SetPoint('LEFT', r.ts, 'RIGHT', 6, 0); r.win:SetWidth(80)
            r.aff:SetPoint('LEFT', r.win, 'RIGHT', 6, 0); r.aff:SetWidth(90)
            r.rea:SetPoint('LEFT', r.aff, 'RIGHT', 6, 0); r.rea:SetWidth(60)
            HLBG.safeSetJustify(r.id, 'LEFT')
            HLBG.safeSetJustify(r.ts, 'LEFT')
            HLBG.safeSetJustify(r.win, 'LEFT')
            HLBG.safeSetJustify(r.aff, 'LEFT')
            HLBG.safeSetJustify(r.rea, 'LEFT')
            h.rows[i] = r
        end
        return r
    end
    local y = -22
    for i, row in ipairs(rows) do
    local r = getRow(i)
        r:ClearAllPoints(); r:SetPoint('TOPLEFT', h.Content, 'TOPLEFT', 0, y)
        local id = row.id or row[1]
        local ts = row.ts or row[2]
        local win = row.winner or row[3]
        local aff = row.affix or row[4]
        local rea = row.reason or row[5]
        r.id:SetText(tostring(id or ''))
        r.ts:SetText(tostring(ts or ''))
        r.win:SetText(tostring(win or ''))
        r.aff:SetText(HLBG.GetAffixName(aff))
        r.rea:SetText(tostring(rea or ''))
        r:Show(); y = y - 18
    end
    h.Content:SetHeight(math.max(300, -y + 8))
    -- Update pager text and buttons if present
    local totalRows = tonumber(h.total or #rows) or #rows
    local perPage = tonumber(h.per or 10) or 10
    local maxPage = math.max(1, math.ceil((totalRows > 0 and totalRows or #rows)/perPage))
    if h.Nav and h.Nav.PageText then h.Nav.PageText:SetText(string.format('Page %d / %d', h.page or 1, maxPage)) end
    if h.Nav and h.Nav.Prev then if (h.page or 1) > 1 then h.Nav.Prev:Enable() else h.Nav.Prev:Disable() end end
    if h.Nav and h.Nav.Next then if (h.page or 1) < maxPage then h.Nav.Next:Enable() else h.Nav.Next:Disable() end end
    if HLBG.UI and HLBG.UI.Frame and not HLBG.UI.Frame:IsShown() then HLBG.UI.Frame:Show() end
end
end

-- Unified main slash handler (parses subcommands like 'devmode')
function HLBG._MainSlashHandler(msg)
    msg = tostring(msg or ""):gsub("^%s+","")
    local sub = msg:match("^(%S+)")
    -- season selector: /hlbg season <n|0>
    if sub and sub:lower() == 'season' then
        local arg = tonumber(msg:match('^%S+%s+(%S+)') or '')
        if not arg then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: season is %s (0 = all/current). Usage: /hlbg season <n>', tostring(HinterlandAffixHUDDB.desiredSeason or 0))) end
        else
            HinterlandAffixHUDDB.desiredSeason = arg
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: season set to %d', arg)) end
        end
        return
    end
    if sub and sub:lower() == "devmode" then
        local arg = msg:match("^%S+%s+(%S+)")
        if arg and arg:lower() == 'on' then
            HLBG._devMode = true
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.devMode = true
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('HLBG: devmode enabled') end
        elseif arg and arg:lower() == 'off' then
            HLBG._devMode = false
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.devMode = false
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('HLBG: devmode disabled') end
        else
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: devmode is %s (use /hlbg devmode on|off)', HLBG._devMode and 'ON' or 'OFF')) end
        end
        return
    end

    -- queue subcommands: /hlbg queue join|leave
    if sub and sub:lower() == 'queue' then
        local act = (msg:match('^%S+%s+(%S+)') or ''):lower()
        if act == 'join' or act == 'leave' then
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle('HLBG', 'Request', act == 'join' and 'QUEUE_JOIN' or 'QUEUE_LEAVE')
                _G.AIO.Handle('HLBG', act == 'join' and 'QueueJoin' or 'QueueLeave')
                _G.AIO.Handle('HLBG', 'QUEUE', act:upper())
            end
            local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
            if sendDot then
                if act == 'join' then sendDot('.hlbg queue join'); sendDot('.hlbg join') else sendDot('.hlbg queue leave'); sendDot('.hlbg leave') end
            end
            if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText('Queue status: requested '..act..'…') end
            return
        end
    end

    -- call helpers defensively: prefer HLBG.* then global fallback
    if type(HLBG.EnsurePvPTab) == 'function' then pcall(HLBG.EnsurePvPTab) elseif type(_G.EnsurePvPTab) == 'function' then pcall(_G.EnsurePvPTab) end
    if type(HLBG.EnsurePvPHeaderButton) == 'function' then pcall(HLBG.EnsurePvPHeaderButton) elseif type(_G.EnsurePvPHeaderButton) == 'function' then pcall(_G.EnsurePvPHeaderButton) end
    HLBG.OpenUI()
    local hist = (HLBG and HLBG.UI and HLBG.UI.History) or nil
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 5
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "DESC"
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (type(_G.HLBG_GetSeason) == 'function' and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        -- Broad calls for compatibility
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "STATS")
        _G.AIO.Handle("HLBG", "Stats")
        _G.AIO.Handle("HLBG", "STATS")
        -- Some servers expose *UI variants
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "StatsUI")
    end
    -- Always also use chat-dot fallbacks so data loads even if AIO is present but server ignores it
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if sendDot then
            sendDot(string.format(".hlbg historyui %d %d %s %s", p, per, sk, sd))
            sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, sv, sk, sd))
            sendDot(string.format(".hlbg history %d %d %s %s", p, per, sk, sd))
            sendDot(string.format(".hlbg history %d %d %d %s %s", p, per, sv, sk, sd))
            sendDot(".hlbg statsui")
            sendDot(string.format(".hlbg statsui %d", sv))
            sendDot(".hlbg stats")
        end
    end
end

-- Primary unique token to avoid collisions with other addons
SlashCmdList = SlashCmdList or {}
SLASH_HLBGHUD1 = "/hlbg"; _G.SLASH_HLBGHUD1 = SLASH_HLBGHUD1
SLASH_HLBGHUD2 = "/hinterland"; _G.SLASH_HLBGHUD2 = SLASH_HLBGHUD2
SLASH_HLBGHUD3 = "/hbg"; _G.SLASH_HLBGHUD3 = SLASH_HLBGHUD3
SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler
-- Backup aliases under a different key to avoid any table-key collisions
SLASH_ZHLBG1 = "/hlbghud"; _G.SLASH_ZHLBG1 = SLASH_ZHLBG1
SLASH_ZHLBG2 = "/zhlbg"; _G.SLASH_ZHLBG2 = SLASH_ZHLBG2
SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler

-- Also try our safeRegisterSlash for redundancy (won't overwrite existing)
pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HINTERLAND'] then safeRegisterSlash('HINTERLAND', '/hinterland', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HBG'] then safeRegisterSlash('HBG', '/hbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZZHLBG'] then safeRegisterSlash('ZZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)

-- Round-trip ping test
function HLBG.PONG()
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server")
end
safeRegisterSlash('HLBGPING', '/hlbgping', function()
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
end)
safeRegisterSlash('HLBGUI', '/hlbgui', function(msg) if SlashCmdList and SlashCmdList['HLBG'] then SlashCmdList['HLBG'](msg) else HLBG._MainSlashHandler(msg) end end)

-- Note: devmode is now parsed inside the main /hlbg handler (use: /hlbg devmode on|off)

-- Register handlers once all functions exist; bind when AIO loads (or immediately if already loaded)
do
    local function register()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        -- Request a fresh table and then assign handlers for maximum compatibility
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then
            local errmsg = tostring(reg or "")
            -- If AddHandlers asserted because the name is already registered, try to attach to any existing global HLBG table
            if errmsg:find("an event is already registered") or errmsg:find("already registered") then
                if type(_G.HLBG) == "table" then
                    local existing = _G.HLBG
                    -- merge our handlers into the existing table only when missing to avoid stomping
                    existing.OpenUI = existing.OpenUI or HLBG.OpenUI
                    existing.History = existing.History or HLBG.History
                    existing.Stats = existing.Stats or HLBG.Stats
                    existing.PONG = existing.PONG or HLBG.PONG
                    existing.DBG = existing.DBG or HLBG.DBG
                    existing.HistoryStr = existing.HistoryStr or HLBG.HistoryStr
                    existing.HISTORY = existing.HISTORY or existing.History
                    existing.STATS = existing.STATS or existing.Stats
                    existing.Warmup = existing.Warmup or HLBG.Warmup
                    existing.QueueStatus = existing.QueueStatus or HLBG.QueueStatus
                    existing.Results = existing.Results or HLBG.Results
                    _G.HLBG = existing; HLBG = existing
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; attached to existing HLBG table")
                    return true
                else
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; handlers may belong to another addon — using fallback")
                    -- Treat as terminal (don't spam retries) but not a success for AIO binding
                    return true
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO.AddHandlers returned unexpected value; retrying")
            return false
        end
    -- preserve some helper functions and UI from the current HLBG table so we don't lose pointers
    local preservedSendLog = (type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil
    local preservedUI = (type(HLBG) == "table" and type(HLBG.UI) == "table") and HLBG.UI or nil
    -- Preserve UI bootstrap helpers so subsequent calls continue to work after table swap
    local preservedBootstrap = (type(HLBG) == "table" and type(HLBG._bootstrapUI) == "function") and HLBG._bootstrapUI or nil
    local preservedEnsure = (type(HLBG) == "table" and type(HLBG._ensureUI) == "function") and HLBG._ensureUI or nil
    -- preserve safe helpers that UI and handlers rely on (these can be lost when HLBG table is swapped by AIO)
    local preservedSafe = {}
    if type(HLBG) == "table" then
        for _, k in ipairs({
            'safeExecSlash','safeRegisterSlash','safeSetJustify','safeIsInInstance',
            'safeGetRealZoneText','safeGetNumWorldStateUI','safeGetWorldStateUIInfo','safeGetPlayerMapPosition'
        }) do
            if type(HLBG[k]) == 'function' then preservedSafe[k] = HLBG[k] end
        end
    end
    reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
    reg.Status     = HLBG.Status
    reg.Affixes    = HLBG.Affixes
    reg.Warmup     = HLBG.Warmup
    reg.QueueStatus= HLBG.QueueStatus
    reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
        reg.HISTORY    = reg.History
        reg.STATS      = reg.Stats
        -- Also register some lowercase/alternate aliases; some AIO builds normalize names differently
        reg.history = reg.History
        reg.historystr = reg.HistoryStr
        reg.stats = reg.Stats
        reg.live = reg.Live
    reg.affixes = reg.Affixes
    reg.results = reg.Results
    reg.warmup = reg.Warmup
    reg.queuestatus = reg.QueueStatus
    reg.pong = reg.PONG
    reg.status = reg.Status
    -- reattach preserved helpers to the new reg table if present
    if preservedSendLog then reg.SendClientLog = preservedSendLog end
    if preservedUI then reg.UI = preservedUI end
    if preservedBootstrap and not reg._bootstrapUI then reg._bootstrapUI = preservedBootstrap end
    if preservedEnsure and not reg._ensureUI then reg._ensureUI = preservedEnsure end
    for k, fn in pairs(preservedSafe) do reg[k] = reg[k] or fn end
    _G.HLBG = reg; HLBG = reg
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: Handlers successfully registered (History/Stats/PONG/OpenUI)")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "HLBG: Registered handlers -> History=%s, Stats=%s, PONG=%s, OpenUI=%s",
            tostring(type(HLBG.History)), tostring(type(HLBG.Stats)), tostring(type(HLBG.PONG)), tostring(type(HLBG.OpenUI))
        ))
        -- Prime first page
        if _G.AIO and _G.AIO.Handle then
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
        end
        return true
    end

    -- Try immediate register; if it fails, poll for AIO for a few seconds and also listen to ADDON_LOADED
    if not register() then
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO not available yet; starting registration poll")
        local attempts = 0
        local maxAttempts = 20
        local pollT = 0
        local fr = CreateFrame("Frame")
        fr:SetScript("OnUpdate", function(self, elapsed)
            pollT = pollT + (elapsed or 0)
            if pollT < 0.25 then return end
            pollT = 0
            attempts = attempts + 1
            if register() then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: registration succeeded after %d attempts", attempts))
                self:SetScript("OnUpdate", nil)
                return
            end
            if attempts >= maxAttempts then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration failed after multiple attempts; handlers not bound")
                self:SetScript("OnUpdate", nil)
            end
        end)
        fr:RegisterEvent("ADDON_LOADED")
        fr:SetScript("OnEvent", function(self, _, name)
            if name == "AIO_Client" or name == "AIO" or name == "RochetAio" then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: ADDON_LOADED signaled AIO; attempting register")
                if register() then
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration succeeded from ADDON_LOADED")
                    fr:SetScript("OnUpdate", nil); fr:UnregisterAllEvents(); fr:SetScript("OnEvent", nil)
                end
            end
        end)
    end
end

-- Debug: local fake data to validate rendering path without server
-- (dev) /hlbgfake registered above via safeRegisterSlash

-- Dump last LIVE payload saved to saved-variables for offline inspection
-- (dev) /hlbglivedump registered above via safeRegisterSlash

-- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }

    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end

    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end

    -- saved variable container for persisted test results
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
    local run = { ts = time(), results = {} }

    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
    end

    run.summary = string.format('%d/%d', passed, #tests)
    table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
end

-- /hlbgjsontest registered above via safeRegisterSlash

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end

-- Startup diagnostic: print a compact status line so it's easy to see what initialized
do
    local function startupDiag()
        local haveAIO = (_G.AIO and _G.AIO.AddHandlers) and true or false
        local handlersBound = (type(HLBG) == 'table' and (type(HLBG.History) == 'function' or type(HLBG.HISTORY) == 'function')) and true or false
        local uiPresent = (type(HLBG) == 'table' and type(HLBG.UI) == 'table') or (type(UI) == 'table')
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG STARTUP: AIO=%s handlers=%s UI=%s", tostring(haveAIO), tostring(handlersBound), tostring(uiPresent)))
        if not uiPresent and type(UI) == 'table' then DEFAULT_CHAT_FRAME:AddMessage("HLBG STARTUP: attaching local UI to HLBG") ; HLBG.UI = UI end
        -- Print and persist slash registration summary if available
        local regParts = {}
        if HLBG._registered_slashes and #HLBG._registered_slashes > 0 then
            for _,s in ipairs(HLBG._registered_slashes) do table.insert(regParts, s.cmd) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: registered slashes -> " .. table.concat(regParts, ", "))
        end
        local skipParts = {}
        if HLBG._skipped_slashes and #HLBG._skipped_slashes > 0 then
            for _,s in ipairs(HLBG._skipped_slashes) do table.insert(skipParts, string.format("%s (%s)", tostring(s.cmd), tostring(s.reason))) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: skipped slashes -> " .. table.concat(skipParts, ", "))
        end
        -- Persist a compact startup summary for later inspection (keep last 20)
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.startupHistory = HinterlandAffixHUDDB.startupHistory or {}
        local entry = { ts = time(), aio = haveAIO, handlers = handlersBound, ui = uiPresent, registered = regParts, skipped = skipParts }
        table.insert(HinterlandAffixHUDDB.startupHistory, 1, entry)
        while #HinterlandAffixHUDDB.startupHistory > 20 do table.remove(HinterlandAffixHUDDB.startupHistory) end
        -- provide helper to print startup history
        function HLBG.PrintStartupHistory(n)
            n = tonumber(n) or 1
            local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory or nil
            if not hist or #hist == 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('HLBG: no startup history saved') end
                return
            end
            if n < 1 then n = 1 end
            if n > #hist then n = #hist end
            local e = hist[n]
            if not e then return end
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
                if e.registered and #e.registered > 0 then DEFAULT_CHAT_FRAME:AddMessage(' registered: '..table.concat(e.registered, ', ')) end
                if e.skipped and #e.skipped > 0 then DEFAULT_CHAT_FRAME:AddMessage(' skipped: '..table.concat(e.skipped, ', ')) end
            end
        end
        -- add a small button in Interface Options to show the last startup history
        if opt and type(opt.CreateFontString) == 'function' then
            local btn = CreateFrame('Button', nil, opt, 'UIPanelButtonTemplate')
            btn:SetSize(160, 22)
            btn:SetPoint('TOPLEFT', cbDev, 'BOTTOMLEFT', 0, -16)
            btn:SetText('Show startup history')
            btn:SetScript('OnClick', function() pcall(HLBG.PrintStartupHistory, 1) end)
        end
    end
    -- Delay a tick so ADDON_LOADED messages can arrive first
    local tfr = CreateFrame('Frame')
    local t = 0
    tfr:SetScript('OnUpdate', function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 0.5 then
            startupDiag()
            self:SetScript('OnUpdate', nil)
        end
    end)
end

-- Ensure we have a valid UI parent for the main frame (UIParent as fallback)
if HLBG and HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame.SetParent then
    HLBG.UI.Frame:SetParent(UIParent)
end

-- Request initial data from server (HISTORY/STATS/AFFIXES/QUEUE STATUS)
if _G.AIO and _G.AIO.Handle then
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
    local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
    _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
    _G.AIO.Handle("HLBG", "Request", "STATS")
    _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
    _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
end

-- Minimal AFK warning stub (client-side only, non-invasive)
do
    local afkTimer, afkAccum = nil, 0
    local lastX, lastY, lastTime = nil, nil, 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
        if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.enableAFKWarning then return end
        afkAccum = afkAccum + (elapsed or 0)
        if afkAccum < 5.0 then return end -- check every 5s
        afkAccum = 0
        local inBG = InHinterlands()
        if not inBG then return end
        -- approximate movement using map position if available (use safe wrapper when present)
        local x,y = 0,0
        if type(HLBG) == 'table' and type(HLBG.safeGetPlayerMapPosition) == 'function' then
            local px, py = HLBG.safeGetPlayerMapPosition("player")
            if px and py then x,y = px,py end
        end
        local moved = (lastX == nil or math.abs((x - (lastX or 0))) > 0.001 or math.abs((y - (lastY or 0))) > 0.001)
        local now = time()
        if moved then lastX, lastY, lastTime = x, y, now; return end
        -- no movement; if more than N seconds, warn
        local idleSec = now - (lastTime or now)
        local threshold = (HinterlandAffixHUDDB.afkWarnSeconds or 120)
        if idleSec >= threshold then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00HLBG|r: You seem AFK. Please move or you may be removed.")
            -- reset timer to avoid spamming
            lastTime = now - (threshold/2)
        end
    end)
end

-- Slash to open HLBG window even if server AIO command isn't available
-- Provide a minimal OpenUI fallback if not defined by UI module
if type(HLBG.OpenUI) ~= 'function' then
    function HLBG.OpenUI()
        if HLBG and HLBG.UI and HLBG.UI.Frame and type(HLBG.UI.Frame.Show) == 'function' then HLBG.UI.Frame:Show() end
        local last = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.lastInnerTab) or 1
        if type(_G.ShowTab) == 'function' then pcall(_G.ShowTab, last) end
        if _G.AIO and _G.AIO.Handle then _G.AIO.Handle('HLBG','Request','STATUS') end
    end
end

-- Minimal Live handler: render resources and timer from last status payload
if type(HLBG.Live) ~= 'function' then
function HLBG.Live(payload)
    -- Accept either raw status or rows list; prefer status already collected via chat/AIO
    HLBG._ensureUI('Live')
    HLBG.UpdateLiveFromStatus()
end
end

-- Minimal Stats handler: show counts if provided; otherwise clear text
if type(HLBG.Stats) ~= 'function' then
function HLBG.Stats(stats)
    HLBG._ensureUI('Stats')
    stats = stats or {}
    local counts = stats.counts or {}
    local a = tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0
    local h = tonumber(counts.Horde or counts.HORDE or 0) or 0
    local d = tonumber(stats.draws or 0) or 0
    local avg = tonumber(stats.avgDuration or 0) or 0
    local lines = { string.format('Alliance: %d  Horde: %d  Draws: %d  Avg: %d min', a, h, d, math.floor(avg/60)) }
    if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then HLBG.UI.Stats.Text:SetText(table.concat(lines, '\n')) end
end
end

-- Minimal History handler: draws basic rows as received from server (id, ts, winner, affix, reason)
if type(HLBG.History) ~= 'function' then
function HLBG.History(rows, page, per, total, col, dir)
    if not HLBG._ensureUI('History') then return end
    rows = rows or {}
    local h = HLBG.UI.History
    h.page = page or 1; h.per = per or 10; h.total = total or #rows; h.sortKey = col or 'id'; h.sortDir = dir or 'DESC'
    -- hide old rows
    for i=1,#h.rows do h.rows[i]:Hide() end
    local function getRow(i)
        local r = h.rows[i]
        if not r then
            r = CreateFrame('Frame', nil, h.Content)
            r:SetSize(420, 14)
            r.id = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.ts = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.win = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.aff = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.rea = r:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            r.id:SetPoint('LEFT', r, 'LEFT', 0, 0); r.id:SetWidth(50)
            r.ts:SetPoint('LEFT', r.id, 'RIGHT', 6, 0); r.ts:SetWidth(120)
            r.win:SetPoint('LEFT', r.ts, 'RIGHT', 6, 0); r.win:SetWidth(80)
            r.aff:SetPoint('LEFT', r.win, 'RIGHT', 6, 0); r.aff:SetWidth(70)
            r.rea:SetPoint('LEFT', r.aff, 'RIGHT', 6, 0); r.rea:SetWidth(50)
            h.rows[i] = r
        end
        return r
    end
    local y = -22
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:ClearAllPoints(); r:SetPoint('TOPLEFT', h.Content, 'TOPLEFT', 0, y)
        local id = row.id or row[1]
        local ts = row.ts or row[2]
        local win = row.winner or row[3]
        local aff = row.affix or row[4]
        local rea = row.reason or row[5]
        r.id:SetText(tostring(id or ''))
        r.ts:SetText(tostring(ts or ''))
        r.win:SetText(tostring(win or ''))
        r.aff:SetText(HLBG.GetAffixName(aff))
        r.rea:SetText(tostring(rea or ''))
        r:Show(); y = y - 14
    end
    h.Content:SetHeight(math.max(300, -y + 8))
    -- Update pager text and nav if available in fallback UI
    if h.Nav and h.Nav.PageText then
        local totalRows = tonumber(h.total or #rows) or #rows
        local perPage = tonumber(h.per or 10) or 10
        local maxPage = math.max(1, math.ceil((totalRows > 0 and totalRows or #rows)/perPage))
        h.Nav.PageText:SetText(string.format('Page %d / %d', h.page or 1, maxPage))
        if h.Nav.Prev then if (h.page or 1) > 1 then h.Nav.Prev:Enable() else h.Nav.Prev:Disable() end end
        if h.Nav.Next then if (h.page or 1) < maxPage then h.Nav.Next:Enable() else h.Nav.Next:Disable() end end
    end
    if HLBG.UI and HLBG.UI.Frame and not HLBG.UI.Frame:IsShown() then HLBG.UI.Frame:Show() end
end
end

-- TSV fallback handler for history (AIO older builds or chat broadcast)
if type(HLBG.HistoryStr) ~= 'function' then
function HLBG.HistoryStr(tsv, page, per, total, col, dir)
    local rows = {}
    if type(tsv) == 'string' and tsv ~= '' then
        -- Support custom separator '||' -> newline
        if tsv:find('%|%|') then tsv = tsv:gsub('%|%|','\n') end
        for line in tsv:gmatch('[^\n]+') do
            local id, ts, win, aff, rea = line:match('^(.-)\t(.-)\t(.-)\t(.-)\t(.*)$')
            if id then table.insert(rows, { id = id, ts = ts, winner = win, affix = aff, reason = rea }) end
        end
    end
    HLBG.History(rows, page, per, total, col, dir)
end
end

-- Queue status handler and request helper
if type(HLBG.QueueStatus) ~= 'function' then
function HLBG.QueueStatus(payload)
    HLBG._ensureUI('Queue')
    local q = HLBG.UI and HLBG.UI.QueuePane
    if not q then return end
    if type(payload) == 'string' then
        -- parse chat fallback: key=value|key=value
        local data = {}
        for kv in payload:gmatch('[^|]+') do
            local k,v = kv:match('^(%w+)%=(.+)$')
            if k then data[k] = v end
        end
        payload = data
    end
    payload = payload or {}
    local team = payload.team or '?'
    local pos = tonumber(payload.pos or 0) or 0
    local size = tonumber(payload.size or 0) or 0
    local eta = tonumber(payload.eta or 0) or 0
    local aCount = tonumber(payload.countA or 0) or 0
    local hCount = tonumber(payload.countH or 0) or 0
    if q.Status then q.Status:SetText(string.format('Queue: %s — position %d of %d (ETA %s)', tostring(team), pos, size, HLBG._fmtETA and HLBG._fmtETA(eta) or tostring(eta)..'s')) end
    if q.Counts then q.Counts:SetText(string.format('Queued: Alliance %d | Horde %d | Total %d', aCount, hCount, aCount + hCount)) end
end
end

function HLBG._fmtETA(sec)
    sec = tonumber(sec or 0) or 0
    local m = math.floor(sec/60); local s = sec%60
    return string.format('%d:%02d', m, s)
end

function HLBG.RequestQueue(action)
    action = tostring(action or 'STATUS'):upper()
    if _G.AIO and _G.AIO.Handle then
        if action == 'JOIN' then _G.AIO.Handle('HLBG','Request','QUEUE','join')
        elseif action == 'LEAVE' then _G.AIO.Handle('HLBG','Request','QUEUE','leave')
        else _G.AIO.Handle('HLBG','Request','QUEUE','status') end
    end
end

-- Affixes handler and request helper
if type(HLBG.Affixes) ~= 'function' then
function HLBG.Affixes(rows)
    HLBG._ensureUI('Affixes')
    local a = HLBG.UI and HLBG.UI.AffixPane
    if not a then return end
    rows = rows or {}
    -- Build name map for affix code -> name
    _G.HLBG_AFFIX_NAMES = _G.HLBG_AFFIX_NAMES or {}
    for i=1,#rows do
        local r = rows[i]
        local id = r.id or r[1]
        local name = r.name or r[2]
        if id and name then _G.HLBG_AFFIX_NAMES[id] = name end
    end
    -- Render simple list
    if not a.Rows then return end
    for i=1,#a.Rows do a.Rows[i]:Hide() end
    a.Rows = a.Rows or {}
    local function getRow(i)
        local fr = a.Rows[i]
        if not fr then
            fr = CreateFrame('Frame', nil, a.Content)
            fr:SetSize(420, 16)
            fr.name = fr:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
            fr.effect = fr:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
            fr.name:SetPoint('LEFT', fr, 'LEFT', 0, 0)
            fr.name:SetWidth(200)
            fr.effect:SetPoint('LEFT', fr.name, 'RIGHT', 8, 0)
            fr.effect:SetWidth(200)
            a.Rows[i] = fr
        end
        return fr
    end
    local y = -4
    for i=1,#rows do
        local r = rows[i]
        local fr = getRow(i)
        fr:ClearAllPoints(); fr:SetPoint('TOPLEFT', a.Content, 'TOPLEFT', 0, y)
        local nm = r.name or r[2] or '?'
        local eff = r.effect or r[3] or ''
        fr.name:SetText(nm)
        fr.effect:SetText(eff)
        fr:Show(); y = y - 16
    end
    a.Content:SetHeight(math.max(300, -y + 8))
end
end

function HLBG.RequestAffixes()
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    local search = HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or ''
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle('HLBG','Request','AFFIXES', sv, search) end
end

-- Lightweight debug message
if type(HLBG.DBG) ~= 'function' then
function HLBG.DBG(msg)
    HLBG._lastDBG = tostring(msg or '')
end
end

-- Unified main slash handler (parses subcommands like 'devmode')
function HLBG._MainSlashHandler(msg)
    msg = tostring(msg or ""):gsub("^%s+","")
    local sub = msg:match("^(%S+)")
    -- season selector: /hlbg season <n|0>
    if sub and sub:lower() == 'season' then
        local arg = tonumber(msg:match('^%S+%s+(%S+)') or '')
        if not arg then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: season is %s (0 = all/current). Usage: /hlbg season <n>', tostring(HinterlandAffixHUDDB.desiredSeason or 0))) end
        else
            HinterlandAffixHUDDB.desiredSeason = arg
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: season set to %d', arg)) end
        end
        return
    end
    if sub and sub:lower() == "devmode" then
        local arg = msg:match("^%S+%s+(%S+)")
        if arg and arg:lower() == 'on' then
            HLBG._devMode = true
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.devMode = true
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('HLBG: devmode enabled') end
        elseif arg and arg:lower() == 'off' then
            HLBG._devMode = false
            HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
            HinterlandAffixHUDDB.devMode = false
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('HLBG: devmode disabled') end
        else
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG: devmode is %s (use /hlbg devmode on|off)', HLBG._devMode and 'ON' or 'OFF')) end
        end
        return
    end

    -- queue subcommands: /hlbg queue join|leave
    if sub and sub:lower() == 'queue' then
        local act = (msg:match('^%S+%s+(%S+)') or ''):lower()
        if act == 'join' or act == 'leave' then
            if _G.AIO and _G.AIO.Handle then
                _G.AIO.Handle('HLBG', 'Request', act == 'join' and 'QUEUE_JOIN' or 'QUEUE_LEAVE')
                _G.AIO.Handle('HLBG', act == 'join' and 'QueueJoin' or 'QueueLeave')
                _G.AIO.Handle('HLBG', 'QUEUE', act:upper())
            end
            local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
            if sendDot then
                if act == 'join' then sendDot('.hlbg queue join'); sendDot('.hlbg join') else sendDot('.hlbg queue leave'); sendDot('.hlbg leave') end
            end
            if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText('Queue status: requested '..act..'…') end
            return
        end
    end

    -- call helpers defensively: prefer HLBG.* then global fallback
    if type(HLBG.EnsurePvPTab) == 'function' then pcall(HLBG.EnsurePvPTab) elseif type(_G.EnsurePvPTab) == 'function' then pcall(_G.EnsurePvPTab) end
    if type(HLBG.EnsurePvPHeaderButton) == 'function' then pcall(HLBG.EnsurePvPHeaderButton) elseif type(_G.EnsurePvPHeaderButton) == 'function' then pcall(_G.EnsurePvPHeaderButton) end
    HLBG.OpenUI()
    local hist = (HLBG and HLBG.UI and HLBG.UI.History) or nil
    local p = (hist and hist.page) or 1
    local per = (hist and hist.per) or 5
    local sk = (hist and hist.sortKey) or "id"
    local sd = (hist and hist.sortDir) or "DESC"
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or (type(_G.HLBG_GetSeason) == 'function' and _G.HLBG_GetSeason()) or 0
    if _G.AIO and _G.AIO.Handle then
        -- Broad calls for compatibility
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "STATS")
        _G.AIO.Handle("HLBG", "Stats")
        _G.AIO.Handle("HLBG", "STATS")
        -- Some servers expose *UI variants
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "StatsUI")
    end
    -- Always also use chat-dot fallbacks so data loads even if AIO is present but server ignores it
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if sendDot then
            sendDot(string.format(".hlbg historyui %d %d %s %s", p, per, sk, sd))
            sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, sv, sk, sd))
            sendDot(string.format(".hlbg history %d %d %s %s", p, per, sk, sd))
            sendDot(string.format(".hlbg history %d %d %d %s %s", p, per, sv, sk, sd))
            sendDot(".hlbg statsui")
            sendDot(string.format(".hlbg statsui %d", sv))
            sendDot(".hlbg stats")
        end
    end
end

-- Primary unique token to avoid collisions with other addons
SlashCmdList = SlashCmdList or {}
SLASH_HLBGHUD1 = "/hlbg"; _G.SLASH_HLBGHUD1 = SLASH_HLBGHUD1
SLASH_HLBGHUD2 = "/hinterland"; _G.SLASH_HLBGHUD2 = SLASH_HLBGHUD2
SLASH_HLBGHUD3 = "/hbg"; _G.SLASH_HLBGHUD3 = SLASH_HLBGHUD3
SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler
-- Backup aliases under a different key to avoid any table-key collisions
SLASH_ZHLBG1 = "/hlbghud"; _G.SLASH_ZHLBG1 = SLASH_ZHLBG1
SLASH_ZHLBG2 = "/zhlbg"; _G.SLASH_ZHLBG2 = SLASH_ZHLBG2
SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler

-- Also try our safeRegisterSlash for redundancy (won't overwrite existing)
pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HINTERLAND'] then safeRegisterSlash('HINTERLAND', '/hinterland', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HBG'] then safeRegisterSlash('HBG', '/hbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZZHLBG'] then safeRegisterSlash('ZZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)

-- Round-trip ping test
function HLBG.PONG()
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server")
end
safeRegisterSlash('HLBGPING', '/hlbgping', function()
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
end)
safeRegisterSlash('HLBGUI', '/hlbgui', function(msg) if SlashCmdList and SlashCmdList['HLBG'] then SlashCmdList['HLBG'](msg) else HLBG._MainSlashHandler(msg) end end)

-- Note: devmode is now parsed inside the main /hlbg handler (use: /hlbg devmode on|off)

-- Register handlers once all functions exist; bind when AIO loads (or immediately if already loaded)
do
    local function register()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        -- Request a fresh table and then assign handlers for maximum compatibility
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then
            local errmsg = tostring(reg or "")
            -- If AddHandlers asserted because the name is already registered, try to attach to any existing global HLBG table
            if errmsg:find("an event is already registered") or errmsg:find("already registered") then
                if type(_G.HLBG) == "table" then
                    local existing = _G.HLBG
                    -- merge our handlers into the existing table only when missing to avoid stomping
                    existing.OpenUI = existing.OpenUI or HLBG.OpenUI
                    existing.History = existing.History or HLBG.History
                    existing.Stats = existing.Stats or HLBG.Stats
                    existing.PONG = existing.PONG or HLBG.PONG
                    existing.DBG = existing.DBG or HLBG.DBG
                    existing.HistoryStr = existing.HistoryStr or HLBG.HistoryStr
                    existing.Status = existing.Status or HLBG.Status
                    existing.HISTORY = existing.HISTORY or existing.History
                    existing.STATS = existing.STATS or existing.Stats
                    existing.Warmup = existing.Warmup or HLBG.Warmup
                    existing.QueueStatus = existing.QueueStatus or HLBG.QueueStatus
                    existing.Results = existing.Results or HLBG.Results
                    _G.HLBG = existing; HLBG = existing
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; attached to existing HLBG table")
                    return true
                else
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; handlers may belong to another addon — using fallback")
                    -- Treat as terminal (don't spam retries) but not a success for AIO binding
                    return true
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO.AddHandlers returned unexpected value; retrying")
            return false
        end
    -- preserve some helper functions and UI from the current HLBG table so we don't lose pointers
    local preservedSendLog = (type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil
    local preservedUI = (type(HLBG) == "table" and type(HLBG.UI) == "table") and HLBG.UI or nil
    -- preserve safe helpers that UI and handlers rely on (these can be lost when HLBG table is swapped by AIO)
    local preservedSafe = {}
    if type(HLBG) == "table" then
        for _, k in ipairs({
            'safeExecSlash','safeRegisterSlash','safeSetJustify','safeIsInInstance',
            'safeGetRealZoneText','safeGetNumWorldStateUI','safeGetWorldStateUIInfo','safeGetPlayerMapPosition'
        }) do
            if type(HLBG[k]) == 'function' then preservedSafe[k] = HLBG[k] end
        end
    end
    reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
    reg.Status     = HLBG.Status
    reg.Affixes    = HLBG.Affixes
    reg.Warmup     = HLBG.Warmup
    reg.QueueStatus= HLBG.QueueStatus
    reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
        reg.HISTORY    = reg.History
        reg.STATS      = reg.Stats
        -- Also register some lowercase/alternate aliases; some AIO builds normalize names differently
        reg.history = reg.History
        reg.historystr = reg.HistoryStr
        reg.stats = reg.Stats
        reg.live = reg.Live
    reg.status = reg.Status
    reg.affixes = reg.Affixes
    reg.results = reg.Results
    reg.warmup = reg.Warmup
    reg.queuestatus = reg.QueueStatus
        reg.pong = reg.PONG
    -- reattach preserved helpers to the new reg table if present
    if preservedSendLog then reg.SendClientLog = preservedSendLog end
    if preservedUI then reg.UI = preservedUI end
    for k, fn in pairs(preservedSafe) do reg[k] = reg[k] or fn end
    _G.HLBG = reg; HLBG = reg
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: Handlers successfully registered (History/Stats/PONG/OpenUI)")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "HLBG: Registered handlers -> History=%s, Stats=%s, PONG=%s, OpenUI=%s",
            tostring(type(HLBG.History)), tostring(type(HLBG.Stats)), tostring(type(HLBG.PONG)), tostring(type(HLBG.OpenUI))
        ))
        -- Prime first page
        if _G.AIO and _G.AIO.Handle then
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
        end
        return true
    end

    -- Try immediate register; if it fails, poll for AIO for a few seconds and also listen to ADDON_LOADED
    if not register() then
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO not available yet; starting registration poll")
        local attempts = 0
        local maxAttempts = 20
        local pollT = 0
        local fr = CreateFrame("Frame")
        fr:SetScript("OnUpdate", function(self, elapsed)
            pollT = pollT + (elapsed or 0)
            if pollT < 0.25 then return end
            pollT = 0
            attempts = attempts + 1
            if register() then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: registration succeeded after %d attempts", attempts))
                self:SetScript("OnUpdate", nil)
                return
            end
            if attempts >= maxAttempts then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration failed after multiple attempts; handlers not bound")
                self:SetScript("OnUpdate", nil)
            end
        end)
        fr:RegisterEvent("ADDON_LOADED")
        fr:SetScript("OnEvent", function(self, _, name)
            if name == "AIO_Client" or name == "AIO" or name == "RochetAio" then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: ADDON_LOADED signaled AIO; attempting register")
                if register() then
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration succeeded from ADDON_LOADED")
                    fr:SetScript("OnUpdate", nil); fr:UnregisterAllEvents(); fr:SetScript("OnEvent", nil)
                end
            end
        end)
    end
end

-- Debug: local fake data to validate rendering path without server
-- (dev) /hlbgfake registered above via safeRegisterSlash

-- Dump last LIVE payload saved to saved-variables for offline inspection
-- (dev) /hlbglivedump registered above via safeRegisterSlash

-- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }

    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end

    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end

    -- saved variable container for persisted test results
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
    local run = { ts = time(), results = {} }

    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "History", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "HISTORY", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "Request", "STATS")
        _G.AIO.Handle("HLBG", "Stats")
        _G.AIO.Handle("HLBG", "STATS")
        -- Some servers expose *UI variants
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, sk, sd)
        _G.AIO.Handle("HLBG", "HistoryUI", p, per, sv, sk, sd)
        _G.AIO.Handle("HLBG", "StatsUI")
    end
    -- Always also use chat-dot fallbacks so data loads even if AIO is present but server ignores it
    do
        local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
        if sendDot then
            sendDot(string.format(".hlbg historyui %d %d %s %s", p, per, sk, sd))
            sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, sv, sk, sd))
            sendDot(string.format(".hlbg history %d %d %s %s", p, per, sk, sd))
            sendDot(string.format(".hlbg history %d %d %d %s %s", p, per, sv, sk, sd))
            sendDot(".hlbg statsui")
            sendDot(string.format(".hlbg statsui %d", sv))
            sendDot(".hlbg stats")
        end
    end
end

-- Primary unique token to avoid collisions with other addons
SlashCmdList = SlashCmdList or {}
SLASH_HLBGHUD1 = "/hlbg"; _G.SLASH_HLBGHUD1 = SLASH_HLBGHUD1
SLASH_HLBGHUD2 = "/hinterland"; _G.SLASH_HLBGHUD2 = SLASH_HLBGHUD2
SLASH_HLBGHUD3 = "/hbg"; _G.SLASH_HLBGHUD3 = SLASH_HLBGHUD3
SlashCmdList["HLBGHUD"] = HLBG._MainSlashHandler
-- Backup aliases under a different key to avoid any table-key collisions
SLASH_ZHLBG1 = "/hlbghud"; _G.SLASH_ZHLBG1 = SLASH_ZHLBG1
SLASH_ZHLBG2 = "/zhlbg"; _G.SLASH_ZHLBG2 = SLASH_ZHLBG2
SlashCmdList["ZHLBG"] = HLBG._MainSlashHandler

-- Also try our safeRegisterSlash for redundancy (won't overwrite existing)
pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HINTERLAND'] then safeRegisterSlash('HINTERLAND', '/hinterland', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HBG'] then safeRegisterSlash('HBG', '/hbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZZHLBG'] then safeRegisterSlash('ZZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['HLBGHUD'] then safeRegisterSlash('HLBGHUD', '/hlbghud', HLBG._MainSlashHandler) end end)
pcall(function() if not SlashCmdList['ZHLBG'] then safeRegisterSlash('ZHLBG', '/zhlbg', HLBG._MainSlashHandler) end end)

-- Round-trip ping test
function HLBG.PONG()
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: PONG from server")
end
safeRegisterSlash('HLBGPING', '/hlbgping', function()
    if _G.AIO and _G.AIO.Handle then _G.AIO.Handle("HLBG", "Request", "PING") else DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO client not available") end
end)
safeRegisterSlash('HLBGUI', '/hlbgui', function(msg) if SlashCmdList and SlashCmdList['HLBG'] then SlashCmdList['HLBG'](msg) else HLBG._MainSlashHandler(msg) end end)

-- Note: devmode is now parsed inside the main /hlbg handler (use: /hlbg devmode on|off)

-- Register handlers once all functions exist; bind when AIO loads (or immediately if already loaded)
do
    local function register()
        if not (_G.AIO and _G.AIO.AddHandlers) then return false end
        -- Request a fresh table and then assign handlers for maximum compatibility
        local ok, reg = pcall(function() return _G.AIO.AddHandlers("HLBG", {}) end)
        if not ok or type(reg) ~= "table" then
            local errmsg = tostring(reg or "")
            -- If AddHandlers asserted because the name is already registered, try to attach to any existing global HLBG table
            if errmsg:find("an event is already registered") or errmsg:find("already registered") then
                if type(_G.HLBG) == "table" then
                    local existing = _G.HLBG
                    -- merge our handlers into the existing table only when missing to avoid stomping
                    existing.OpenUI = existing.OpenUI or HLBG.OpenUI
                    existing.History = existing.History or HLBG.History
                    existing.Stats = existing.Stats or HLBG.Stats
                    existing.PONG = existing.PONG or HLBG.PONG
                    existing.DBG = existing.DBG or HLBG.DBG
                    existing.HistoryStr = existing.HistoryStr or HLBG.HistoryStr
                    existing.HISTORY = existing.HISTORY or existing.History
                    existing.STATS = existing.STATS or existing.Stats
                    existing.Warmup = existing.Warmup or HLBG.Warmup
                    existing.QueueStatus = existing.QueueStatus or HLBG.QueueStatus
                    existing.Results = existing.Results or HLBG.Results
                    _G.HLBG = existing; HLBG = existing
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; attached to existing HLBG table")
                    return true
                else
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO name already registered; handlers may belong to another addon — using fallback")
                    -- Treat as terminal (don't spam retries) but not a success for AIO binding
                    return true
                end
            end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO.AddHandlers returned unexpected value; retrying")
            return false
        end
    -- preserve some helper functions and UI from the current HLBG table so we don't lose pointers
    local preservedSendLog = (type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil
    local preservedUI = (type(HLBG) == "table" and type(HLBG.UI) == "table") and HLBG.UI or nil
    -- preserve safe helpers that UI and handlers rely on (these can be lost when HLBG table is swapped by AIO)
    local preservedSafe = {}
    if type(HLBG) == "table" then
        for _, k in ipairs({
            'safeExecSlash','safeRegisterSlash','safeSetJustify','safeIsInInstance',
            'safeGetRealZoneText','safeGetNumWorldStateUI','safeGetWorldStateUIInfo','safeGetPlayerMapPosition'
        }) do
            if type(HLBG[k]) == 'function' then preservedSafe[k] = HLBG[k] end
        end
    end
    reg.OpenUI     = HLBG.OpenUI
        reg.History    = HLBG.History
        reg.Stats      = HLBG.Stats
        reg.Live       = HLBG.Live
        reg.LIVE       = reg.Live
    reg.Affixes    = HLBG.Affixes
    reg.Warmup     = HLBG.Warmup
    reg.QueueStatus= HLBG.QueueStatus
    reg.Results    = HLBG.Results
        reg.PONG       = HLBG.PONG
        reg.DBG        = HLBG.DBG
        reg.HistoryStr = HLBG.HistoryStr
        reg.HISTORY    = reg.History
        reg.STATS      = reg.Stats
        -- Also register some lowercase/alternate aliases; some AIO builds normalize names differently
        reg.history = reg.History
        reg.historystr = reg.HistoryStr
        reg.stats = reg.Stats
        reg.live = reg.Live
    reg.affixes = reg.Affixes
    reg.results = reg.Results
    reg.warmup = reg.Warmup
    reg.queuestatus = reg.QueueStatus
        reg.pong = reg.PONG
    -- reattach preserved helpers to the new reg table if present
    if preservedSendLog then reg.SendClientLog = preservedSendLog end
    if preservedUI then reg.UI = preservedUI end
    for k, fn in pairs(preservedSafe) do reg[k] = reg[k] or fn end
    _G.HLBG = reg; HLBG = reg
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: Handlers successfully registered (History/Stats/PONG/OpenUI)")
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "HLBG: Registered handlers -> History=%s, Stats=%s, PONG=%s, OpenUI=%s",
            tostring(type(HLBG.History)), tostring(type(HLBG.Stats)), tostring(type(HLBG.PONG)), tostring(type(HLBG.OpenUI))
        ))
        -- Prime first page
        if _G.AIO and _G.AIO.Handle then
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            local wf = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histWinner) or 'ALL'
            local af = (HinterlandAffixHUDDB and HinterlandAffixHUDDB.histAffix) or ''
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 15, "id", "ASC", wf, HLBG.ResolveAffixFilter and HLBG.ResolveAffixFilter(af) or af, sv)
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "AFFIXES", sv, HinterlandAffixHUDDB and HinterlandAffixHUDDB.affixSearch or '')
            _G.AIO.Handle("HLBG", "Request", "QUEUE", "STATUS")
        end
        return true
    end

    -- Try immediate register; if it fails, poll for AIO for a few seconds and also listen to ADDON_LOADED
    if not register() then
        DEFAULT_CHAT_FRAME:AddMessage("HLBG: AIO not available yet; starting registration poll")
        local attempts = 0
        local maxAttempts = 20
        local pollT = 0
        local fr = CreateFrame("Frame")
        fr:SetScript("OnUpdate", function(self, elapsed)
            pollT = pollT + (elapsed or 0)
            if pollT < 0.25 then return end
            pollT = 0
            attempts = attempts + 1
            if register() then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: registration succeeded after %d attempts", attempts))
                self:SetScript("OnUpdate", nil)
                return
            end
            if attempts >= maxAttempts then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration failed after multiple attempts; handlers not bound")
                self:SetScript("OnUpdate", nil)
            end
        end)
        fr:RegisterEvent("ADDON_LOADED")
        fr:SetScript("OnEvent", function(self, _, name)
            if name == "AIO_Client" or name == "AIO" or name == "RochetAio" then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: ADDON_LOADED signaled AIO; attempting register")
                if register() then
                    DEFAULT_CHAT_FRAME:AddMessage("HLBG: registration succeeded from ADDON_LOADED")
                    fr:SetScript("OnUpdate", nil); fr:UnregisterAllEvents(); fr:SetScript("OnEvent", nil)
                end
            end
        end)
    end
end

-- Debug: local fake data to validate rendering path without server
-- (dev) /hlbgfake registered above via safeRegisterSlash

-- Dump last LIVE payload saved to saved-variables for offline inspection
-- (dev) /hlbglivedump registered above via safeRegisterSlash

-- In-game JSON decoder test runner. Run with /hlbgjsontest to exercise the addon's json_decode implementation
function HLBG.RunJsonDecodeTests()
    if not DEFAULT_CHAT_FRAME or not DEFAULT_CHAT_FRAME.AddMessage then return end

    -- prepare a few expanded tests: unicode escapes, malformed JSON, and a large array
    local largeN = 200
    local parts = {}
    for i=1,largeN do parts[#parts+1] = tostring(i) end
    local largeArrayStr = "[" .. table.concat(parts, ",") .. "]"

    local tests = {
        { name = 'null', input = 'null', expectError = false, expected = nil },
        { name = 'true', input = 'true', expectError = false, expected = true },
        { name = 'false', input = 'false', expectError = false, expected = false },
        { name = 'number', input = '123', expectError = false, expected = 123 },
        { name = 'string', input = '"hello"', expectError = false, expected = 'hello' },
        { name = 'array_small', input = '[1,2,3]', expectError = false, expected = {1,2,3} },
        { name = 'object', input = '{"a":1,"b":"x"}', expectError = false, expected = { a=1, b='x' } },
        { name = 'nested', input = '{"nested":{"k":true}}', expectError = false, expected = { nested = { k = true } } },
        { name = 'unicode_latin1', input = '"caf\\u00e9"', expectError = false, expected = 'café' },
        { name = 'unicode_euro', input = '"price\\u20ac"', expectError = false, expected = 'price€' },
        { name = 'malformed_trailing_comma', input = '{"a":1,}', expectError = true },
        { name = 'malformed_missing_comma', input = '{"a":1 "b":2}', expectError = true },
        { name = 'malformed_unclosed_string', input = '"unclosed', expectError = true },
        { name = 'large_array', input = largeArrayStr, expectError = false, expectedLen = largeN },
    }

    local function deepEqual(a,b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= 'table' then return a == b end
        local ka = {}; for k,_ in pairs(a) do ka[#ka+1]=k end
        local kb = {}; for k,_ in pairs(b) do kb[#kb+1]=k end
        table.sort(ka); table.sort(kb)
        if #ka ~= #kb then return false end
        for i=1,#ka do if ka[i] ~= kb[i] then return false end end
        for k,_ in pairs(a) do if not deepEqual(a[k], b[k]) then return false end end
        return true
    end

    local function shortRepr(v)
        local t = type(v)
        if t == 'nil' then return 'nil' end
        if t == 'string' then return string.format('"%s"', tostring(v)) end
        if t == 'number' or t == 'boolean' then return tostring(v) end
        if t == 'table' then
            if #v and #v > 0 then return string.format('<array len=%d>', #v) end
            return '<object>'
        end
        return '<'..t..'>'
    end

    -- saved variable container for persisted test results
    HinterlandAffixHUD_JsonTestResults = HinterlandAffixHUD_JsonTestResults or {}
    local run = { ts = time(), results = {} }

    local passed = 0
    for i, t in ipairs(tests) do
        local res, err = json_decode(t.input)
        local ok
        if t.expectError then
            ok = (err ~= nil)
        else
            if err ~= nil then ok = false else
                if t.expectedLen then
                    ok = (type(res) == 'table' and #res == t.expectedLen)
                else
                    ok = deepEqual(res, t.expected)
                end
            end
        end
        if ok then passed = passed + 1 end
        local out = shortRepr(res)
        table.insert(run.results, { name = t.name, pass = ok, error = err and tostring(err) or nil, output = out, expected = t.expectedLen and ('len='..t.expectedLen) or (t.expected ~= nil and shortRepr(t.expected) or nil) })
        DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON Test %d (%s): %s', i, t.name, ok and 'PASS' or ('FAIL'..(err and (': '..tostring(err)) or ''))))
    end

    run.summary = string.format('%d/%d', passed, #tests)
    table.insert(HinterlandAffixHUD_JsonTestResults, 1, run)
    -- keep last 20 runs
    while #HinterlandAffixHUD_JsonTestResults > 20 do table.remove(HinterlandAffixHUD_JsonTestResults) end

    DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG JSON tests finished: %s passed (saved to HinterlandAffixHUD_JsonTestResults)', run.summary))
end

-- /hlbgjsontest registered above via safeRegisterSlash

-- Print saved JSON test run(s) to chat. Usage: /hlbgjsontestrun [n]
function HLBG.PrintJsonTestRun(n)
    n = tonumber(n) or 1
    if not HinterlandAffixHUD_JsonTestResults or #HinterlandAffixHUD_JsonTestResults == 0 then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: no saved runs found") end
        return
    end
    if n < 1 then n = 1 end
    if n > #HinterlandAffixHUD_JsonTestResults then n = #HinterlandAffixHUD_JsonTestResults end
    local run = HinterlandAffixHUD_JsonTestResults[n]
    if not run then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG JSON tests: run not found") end
        return
    end
    local when = (type(date) == 'function' and date("%Y-%m-%d %H:%M:%S", run.ts)) or tostring(run.ts)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG JSON Test Run #%d - %s (summary: %s)", n, when, run.summary or ""))
        for i, r in ipairs(run.results or {}) do
            local ok = r.pass and "PASS" or "FAIL"
            local info = string.format("%d) %s: %s", i, r.name or "?", ok)
            if r.error then info = info .. " - error: " .. tostring(r.error) end
            if r.output then info = info .. " - output: " .. tostring(r.output) end
            if r.expected then info = info .. " - expected: " .. tostring(r.expected) end
            DEFAULT_CHAT_FRAME:AddMessage(info)
        end
    end
end

-- /hlbgjsontestrun registered above via safeRegisterSlash

-- Startup diagnostic: print a compact status line so it's easy to see what initialized
do
    local function startupDiag()
        local haveAIO = (_G.AIO and _G.AIO.AddHandlers) and true or false
        local handlersBound = (type(HLBG) == 'table' and (type(HLBG.History) == 'function' or type(HLBG.HISTORY) == 'function')) and true or false
        local uiPresent = (type(HLBG) == 'table' and type(HLBG.UI) == 'table') or (type(UI) == 'table')
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG STARTUP: AIO=%s handlers=%s UI=%s", tostring(haveAIO), tostring(handlersBound), tostring(uiPresent)))
        if not uiPresent and type(UI) == 'table' then DEFAULT_CHAT_FRAME:AddMessage("HLBG STARTUP: attaching local UI to HLBG") ; HLBG.UI = UI end
        -- Print and persist slash registration summary if available
        local regParts = {}
        if HLBG._registered_slashes and #HLBG._registered_slashes > 0 then
            for _,s in ipairs(HLBG._registered_slashes) do table.insert(regParts, s.cmd) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: registered slashes -> " .. table.concat(regParts, ", "))
        end
        local skipParts = {}
        if HLBG._skipped_slashes and #HLBG._skipped_slashes > 0 then
            for _,s in ipairs(HLBG._skipped_slashes) do table.insert(skipParts, s.cmd .. " (" .. s.reason .. ")") end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: skipped slashes -> " .. table.concat(skipParts, ", "))
        end
        -- Persist a compact startup summary for later inspection (keep last 20)
        HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
        HinterlandAffixHUDDB.startupHistory = HinterlandAffixHUDDB.startupHistory or {}
        local entry = { ts = time(), aio = haveAIO, handlers = handlersBound, ui = uiPresent, registered = regParts, skipped = skipParts }
        table.insert(HinterlandAffixHUDDB.startupHistory, 1, entry)
        while #HinterlandAffixHUDDB.startupHistory > 20 do table.remove(HinterlandAffixHUDDB.startupHistory) end
        -- provide helper to print startup history
        function HLBG.PrintStartupHistory(n)
            n = tonumber(n) or 1
            local hist = HinterlandAffixHUDDB and HinterlandAffixHUDDB.startupHistory or nil
            if not hist or #hist == 0 then
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage('HLBG: no startup history saved') end
                return
            end
            if n < 1 then n = 1 end
            if n > #hist then n = #hist end
            local e = hist[n]
            if not e then return end
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('HLBG startup @ %s: AIO=%s handlers=%s ui=%s', date('%Y-%m-%d %H:%M:%S', e.ts), tostring(e.aio), tostring(e.handlers), tostring(e.ui)))
                if e.registered and #e.registered > 0 then DEFAULT_CHAT_FRAME:AddMessage(' registered: '..table.concat(e.registered, ', ')) end
                if e.skipped and #e.skipped > 0 then DEFAULT_CHAT_FRAME:AddMessage(' skipped: '..table.concat(e.skipped, ', ')) end
            end
        end
        -- add a small button in Interface Options to show the last startup history
        if opt and type(opt.CreateFontString) == 'function' then
            local btn = CreateFrame('Button', nil, opt, 'UIPanelButtonTemplate')
            btn:SetSize(160, 22)
            btn:SetPoint('TOPLEFT', cbDev, 'BOTTOMLEFT', 0, -16)
            btn:SetText('Show startup history')
            btn:SetScript('OnClick', function() pcall(HLBG.PrintStartupHistory, 1) end)
        end
    end
    -- Delay a tick so ADDON_LOADED messages can arrive first
    local tfr = CreateFrame('Frame')
    local t = 0
    tfr:SetScript('OnUpdate', function(self, elapsed)
        t = t + (elapsed or 0)
        if t > 0.5 then
            startupDiag()
            self:SetScript('OnUpdate', nil)
        end
    end)
end

