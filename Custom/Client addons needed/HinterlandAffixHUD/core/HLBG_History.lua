local HLBG = _G.HLBG or {}; _G.HLBG = HLBG

-- Debug: Announce that this file is loading
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00HLBG Debug:|r HLBG_History.lua loading...")
end

-- History module (extracted from monolithic UI file)
-- Responsibilities:
--  * Parse history payloads (table or TSV)
--  * Normalize rows
--  * Apply client-side pagination fallback when server sends full set
--  * Render History UI (expects HLBG.UI.History frame prepared elsewhere)

HLBG.History = HLBG.History or function(a,b,c,d,e,f,g)
    -- Debug: announce invocation and record into debug buffer
    pcall(function()
        local msg = string.format('HLBG.History invoked rows=%d page=%s per=%s total=%s', (#(a or {}) or 0), tostring(b), tostring(c), tostring(d))
        if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
        table.insert(HinterlandAffixHUD_DebugLog, 1, msg)
        while #HinterlandAffixHUD_DebugLog > 400 do table.remove(HinterlandAffixHUD_DebugLog) end
        if DEFAULT_CHAT_FRAME and (HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)) then
            DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG:|r '..msg)
        end
    end)
    if not (HLBG._ensureUI and HLBG._ensureUI('History')) then return end
    local rows, page, per, total, col, dir, secondsAgo
    local function looksLikeRows(v)
        if type(v) ~= 'table' then return false end
        if #v > 0 then return true end
        if v.id or v.ts or v.winner or v.affix or v.reason then return true end
        return false
    end
    if looksLikeRows(a) then rows,page,per,total,col,dir,secondsAgo = a,b,c,d,e,f,g
    elseif looksLikeRows(b) then rows,page,per,total,col,dir,secondsAgo = b,c,d,e,f,g
    else page,per,rows,total,col,dir,secondsAgo = a,b,c,d,e,f,g end
    if type(rows) ~= 'table' then rows = {} end

    -- Apply pagination values
    local ui = HLBG.UI.History
    if page ~= nil then ui.page = tonumber(page) or ui.page end
    if per  ~= nil then ui.per  = tonumber(per)  or ui.per  end
    if total~= nil then ui.total= tonumber(total)or ui.total end
    ui.page  = ui.page or 1
    ui.per   = ui.per  or 15
    ui.total = ui.total or 0
    ui.sortKey = col or ui.sortKey or 'id'
    ui.sortDir = dir or ui.sortDir or 'DESC'

    -- Normalize
    local normalized = {}
    if #rows > 0 then normalized = rows else
        local tmp = {}
        for _,v in pairs(rows) do if type(v)=='table' then tmp[#tmp+1]=v end end
        if #tmp==0 and (rows.id or rows.ts or rows.winner) then tmp[1]=rows end
        normalized = tmp
    end
    for _,r in ipairs(normalized) do
        r.id     = r.id     or r[1]
        r.ts     = r.ts     or r[2]
        r.winner = r.winner or r[3]
        if not r.winner_tid and r.winner then
            local W = tostring(r.winner):upper()
            if W=='HORDE' then r.winner_tid=67 elseif W=='ALLIANCE' then r.winner_tid=469 end
        end
        r.affix  = r.affix  or r[4]
        r.dur    = r.dur    or r[5]
        r.reason = r.reason or r[6]
    end
    rows = normalized

    -- Sort
    local asc = (tostring(ui.sortDir):upper()=='ASC')
    local key = tostring(ui.sortKey or 'id'):lower()
    table.sort(rows, function(a,b)
        local function val(r)
            if key=='id' then return tonumber(r.id) or 0 end
            if key=='ts' then return tonumber(r.ts) or 0 end
            return tostring(r[key] or '')
        end
        local av,bv=val(a),val(b)
        if asc then return av<bv else return av>bv end
    end)

    -- Save lastRows early so UI can render later when created
    HLBG.UI = HLBG.UI or {}
    HLBG.UI.History = HLBG.UI.History or {}
    HLBG.UI.History.lastRows = rows

    -- Client-side pagination fallback
    local fullCount = #rows
    local needSlice = (ui.total==0) or (ui.total==fullCount and fullCount>ui.per)
    if needSlice then
        ui.total = fullCount
        local maxPage = math.max(1, math.ceil(fullCount / ui.per))
        if ui.page>maxPage then ui.page=maxPage end
        local s = (ui.page-1)*ui.per + 1
        local e = math.min(fullCount, s + ui.per - 1)
        local slice = {}
        for i=s,e do slice[#slice+1]=rows[i] end
        rows = slice
    end

    -- Render
    local cont = ui.Content
    if not cont then
        -- UI content not yet created; leave lastRows stored and return so UI can pick it up later
        -- Dev: schedule a one-shot retry to render if UI appears shortly after
        if not HLBG._historyDeferredRetryScheduled then
            HLBG._historyDeferredRetryScheduled = true
            C_Timer.After(1.0, function()
                HLBG._historyDeferredRetryScheduled = false
                if HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.Content and HLBG.UI.History.lastRows then
                    -- Re-invoke with preserved lastRows
                    pcall(HLBG.History, HLBG.UI.History.lastRows, HLBG.UI.History.page or 1, HLBG.UI.History.per or 15, HLBG.UI.History.total or #HLBG.UI.History.lastRows, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')
                    if (HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)) and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug|r Deferred history render invoked')
                    end
                end
            end)
        end
        return
    end
    ui.rows = ui.rows or {}
    -- hide old
    for i,r in ipairs(ui.rows) do if r.Hide then r:Hide() end end

    local function Row(i)
        local r = ui.rows[i]; if r then return r end
        r = CreateFrame('Frame', 'HLBG_HistoryRow_'..i, cont)
        r:SetHeight(22)
        r:SetBackdrop({ bgFile='Interface/Tooltips/UI-Tooltip-Background'})
        local fields = {'id','sea','ts','win','aff','dur','rea'}
        local widths = {40,40,120,70,70,60,70}
        local prev
        for idx,name in ipairs(fields) do
            local fs = r:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
            r[name]=fs
            if idx==1 then fs:SetPoint('LEFT', r,'LEFT',5,0) else fs:SetPoint('LEFT', prev,'RIGHT',5,0) end
            fs:SetWidth(widths[idx])
            prev=fs
        end
        ui.rows[i]=r
        return r
    end

    local y=-22
    for i,row in ipairs(rows) do
        local r = Row(i)
        r:ClearAllPoints(); r:SetPoint('TOPLEFT', cont,'TOPLEFT',5,y)
        r.rowData=row; r.rowIndex=i
        r:SetBackdropColor((i%2==0) and 0.10,0.10,0.10,0.50 or 0.05,0.05,0.05,0.30)
        if i % 2 == 0 then
            r:SetBackdropColor(0.10,0.10,0.10,0.50)
        else
            r:SetBackdropColor(0.05,0.05,0.05,0.30)
        end
        local ts = tonumber(row.ts) or 0
        local tsText = ts>0 and date('%Y-%m-%d %H:%M', ts) or '-'
        r.id:SetText(row.id or '-')
        r.sea:SetText(row.season or row.seasonName or '-')
        r.ts:SetText(tsText)
        local winTxt = row.winner or '-'
        if row.winner_tid==67 then winTxt='|cFFFF0000Horde|r' elseif row.winner_tid==469 then winTxt='|cFF0000FFAlliance|r' end
        r.win:SetText(winTxt)
        r.aff:SetText(HLBG.GetAffixName and HLBG.GetAffixName(row.affix) or (row.affix or '-'))
        local dur = tonumber(row.dur) or 0; r.dur:SetText(dur>0 and SecondsToTime(dur) or '-')
        r.rea:SetText(row.reason or '-')
        r:Show(); y = y - 22
    end
    cont:SetHeight(math.max(120, (#rows*22)+30))

    -- Pager display
    local maxPage = math.max(1, math.ceil((ui.total or #rows)/ui.per))
    if ui.Nav and ui.Nav.PageText then
        ui.Nav.PageText:SetText(string.format('Page %d / %d', ui.page, maxPage))
        if ui.Nav.Prev and ui.Nav.Prev.SetEnabled then ui.Nav.Prev:SetEnabled(ui.page>1) end
        if ui.Nav.Next and ui.Nav.Next.SetEnabled then ui.Nav.Next:SetEnabled(ui.page<maxPage) end
    end
end

-- TSV variant
HLBG.HistoryStr = HLBG.HistoryStr or function(a,b,c,d,e,f,g)
    local tsv, page, per, total, col, dir
    if type(a)=='string' then tsv,page,per,total,col,dir = a,b,c,d,e,f else tsv,page,per,total,col,dir = b,c,d,e,f,g end
    local rows = {}
    local reportedTotal = tonumber(total or 0) or 0
    if type(tsv)=='string' and tsv~='' then
        -- Aggressive sanitization:
        --  - Normalize CRLF to LF
        --  - Convert common chat multi-row marker '||' into newlines
        --  - Preserve tabs and newlines, replace other control chars with space
        --  - Strip high-bytes (>= 0x80) which frequently appear as garbled separators in chat
        local function keep_valid_utf8(s)
            if type(s) ~= 'string' then return s end
            local out = {}
            local i = 1; local n = #s
            while i <= n do
                local b = string.byte(s, i)
                if not b then break end
                if b < 0x80 then
                    -- Preserve printable ASCII and TAB (9) and LF (10); replace other control chars with space
                    if b == 9 or b == 10 or b >= 32 then
                        out[#out+1] = string.char(b)
                    else
                        out[#out+1] = ' '
                    end
                    i = i + 1
                elseif b >= 0xC2 and b <= 0xDF and i+1 <= n then
                    local b2 = string.byte(s, i+1)
                    if b2 and b2 >= 0x80 and b2 <= 0xBF then out[#out+1] = s:sub(i, i+1); i = i + 2 else out[#out+1] = '?'; i = i + 1 end
                elseif b >= 0xE0 and b <= 0xEF and i+2 <= n then
                    local b2,b3 = string.byte(s, i+1, i+2)
                    if b2 and b3 and b2>=0x80 and b2<=0xBF and b3>=0x80 and b3<=0xBF then out[#out+1] = s:sub(i,i+2); i = i + 3 else out[#out+1] = '?'; i = i + 1 end
                elseif b >= 0xF0 and b <= 0xF4 and i+3 <= n then
                    local b2,b3,b4 = string.byte(s, i+1, i+3)
                    if b2 and b3 and b4 and b2>=0x80 and b2<=0xBF and b3>=0x80 and b3<=0xBF and b4>=0x80 and b4<=0xBF then out[#out+1] = s:sub(i,i+3); i = i + 4 else out[#out+1] = '?'; i = i + 1 end
                else
                    out[#out+1] = '?'; i = i + 1
                end
            end
            return table.concat(out)
        end
        local function sanitize(s)
            if type(s) ~= 'string' then return s end
            -- Some transports escape control sequences into literal '\n' or '\t'. Convert those first
            s = s:gsub('\\r\\n', '\n'):gsub('\\r', '\n')
            s = s:gsub('\\n', '\n'):gsub('\\t', '\t')
            -- Normalize CRLF -> LF
            s = s:gsub('\r\n', '\n'):gsub('\r', '\n')
            -- Convert visible chat multi-row separators into real newlines
            s = s:gsub('%|%|', '\n')
            -- Ensure UTF-8 validity while replacing control chars (except TAB/LF) with spaces
            s = keep_valid_utf8(s)
            return s
        end
    tsv = sanitize(tsv)
    -- store sanitized sample for client debug command
    HLBG._lastSanitizedTSV = tsv
    -- Dev-only diagnostics: report how many newline-separated lines we see after sanitization
    pcall(function()
        local dev = HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local cnt = 0
            local preview = {}
            for line in tsv:gmatch('[^\n]+') do
                cnt = cnt + 1
                if cnt <= 5 then table.insert(preview, line) end
            end
            local spreview = table.concat(preview, ' | ')
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr sanitized lines=%d preview=%s', cnt, (spreview or '[none]')))
        end
    end)

    -- Final aggressive fallback: if there are pipe separators but no newlines, convert pipes (with optional spaces) to newlines
    pcall(function()
        local dev = HLBG._devMode or (HinterlandAffixHUDDB and HinterlandAffixHUDDB.devMode)
        -- Convert literal escaped sequences that may have been preserved (e.g. '\n' => actual newline)
        local escN = 0; tsv, escN = tsv:gsub('\\n', '\n')
        local escT = 0; tsv, escT = tsv:gsub('\\t', '\t')
        if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and (escN > 0 or escT > 0) then
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr converted escaped seqs: \n=%d \t=%d', escN, escT))
        end
        -- Count pipes correctly (previous code had an incorrect pattern)
        local pipeCount = 0 for _ in tsv:gmatch('%|') do pipeCount = pipeCount + 1 end
        local hasNewline = tsv:find('\n') and true or false
        if pipeCount > 0 and not hasNewline then
            tsv = tsv:gsub('%s*%|%s*', '\n')
            HLBG._lastSanitizedTSV = tsv
            if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr fallback: converted %d pipes into newlines', pipeCount))
            end
        end
        -- Ensure we always update the last sanitized sample after conversions
        HLBG._lastSanitizedTSV = tsv
    end)
        -- Support optional TOTAL= prefix used by some chat fallbacks (already stripped by handlers in many cases)
        local meta = tsv:match('^TOTAL=(%d+)%s*%|%|') or tsv:match('^TOTAL=(%d+)%s*')
        if meta then reportedTotal=tonumber(meta) or reportedTotal; tsv = tsv:gsub('^TOTAL=%d+%s*%|%|',''):gsub('^TOTAL=%d+%s*','') end

        -- Robust split by newline into lines
        local function split_fields(line)
            local cols = {}
            local last = 1
            while true do
                local s,e = string.find(line, '\t', last, true)
                if not s then
                    table.insert(cols, line:sub(last))
                    break
                else
                    table.insert(cols, line:sub(last, s-1))
                    last = e + 1
                end
            end
            return cols
        end

        -- Flexible fallback parser for single-line rows that lost tabs in transit
        if not HLBG._parseHistLineFlexible then
            HLBG._parseHistLineFlexible = function(line)
                if type(line) ~= 'string' then return nil end
                -- collapse repeated whitespace
                local s = line:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
                -- Try to extract an ISO-like timestamp (YYYY-MM-DD HH:MM:SS or YYYY-MM-DD HH:MM)
                local ts = s:match('(%d%d%d%d%-%d%d%-%d%d% %d%d:%d%d:%d%d)') or s:match('(%d%d%d%d%-%d%d%-%d%d% %d%d:%d%d)')
                if ts then
                    local before, after = s:match('^(.-)'..ts..'(.*)$')
                    before = before or ''
                    after = after or ''
                    local id = before:match('(%d+)%s*$') or before:match('(%S+)') or ''
                    -- after typically: <space>Winner<space>Affix<space>Reason...
                    local winner = after:match('%s*(%a+)%s+') or after:match('^%s*(%a+)') or ''
                    local aff = after:match('%s+(%d+)%s+') or after:match('%s+(%d+)$') or ''
                    local reason = (aff ~= '') and (after:match('%d+%s+(.*)$') or after) or after
                    reason = reason and reason:gsub('^%s+','') or '-'
                    return { id = tostring(id), ts = tostring(ts), winner = tostring(winner or '-'), affix = tostring(aff or '-'), reason = tostring(reason or '-') }
                else
                    -- Fallback tokenization: split on '|' or ';' or spaces, prefer first 5 meaningful tokens
                    local tokens = {}
                    for tok in line:gmatch('[^%|;%s]+') do table.insert(tokens, tok) end
                    if #tokens >= 5 then
                        local reason = table.concat(tokens, ' ', 5)
                        return { id = tokens[1], ts = tokens[2], winner = tokens[3], affix = tokens[4], reason = reason }
                    elseif #tokens >= 4 then
                        return { id = tokens[1], ts = tokens[2], winner = tokens[3], affix = tokens[4], reason = '-' }
                    end
                end
                return nil
            end
        end

        for line in tsv:gmatch('[^\n]+') do
            -- Trim line
            line = line:gsub('^%s+',''):gsub('%s+$','')
            if line ~= '' then
                local cols = split_fields(line)
                -- Trim each column
                for i=1,#cols do cols[i] = (cols[i] or ''):gsub('^%s+',''):gsub('%s+$','') end
                if #cols >= 7 and cols[4]:match('^%d%d%d%d%-%d%d%-%d%d') then
                    -- Extended format: id, season, seasonName, timestamp, winner, affix, reason
                    rows[#rows+1] = {
                        id = cols[1],
                        season = tonumber(cols[2]) or cols[2],
                        seasonName = cols[3],
                        ts = cols[4],
                        winner = cols[5],
                        affix = cols[6],
                        reason = cols[7]
                    }
                elseif #cols >= 5 then
                    rows[#rows+1] = { id=cols[1], ts=cols[2], winner=cols[3], affix=cols[4], reason=cols[5] }
                else
                    -- Try splitting on '||' or '|' (some server dumps used these), or use flexible parser
                    local added = false
                    local alt = line
                    if alt:find('%|') then
                        local parts = {}
                        for part in alt:gmatch('[^%|]+') do parts[#parts+1] = (part or ''):gsub('^%s+',''):gsub('%s+$','') end
                        if #parts >= 5 then
                            rows[#rows+1] = { id=parts[1], ts=parts[2], winner=parts[3], affix=parts[4], reason=parts[5] }
                            added = true
                        end
                    end
                    if not added then
                        if HLBG._parseHistLineFlexible then
                            local parsed = HLBG._parseHistLineFlexible(line)
                            if parsed then rows[#rows+1] = parsed end
                        end
                    end
                end
            end
        end
    end
    return HLBG.History(rows, page, per, reportedTotal, col, dir)
end

-- Sorting API so the UI buttons don't reimplement toggling logic
if not HLBG.HistoryApplySort then
    function HLBG.HistoryApplySort(key)
        if not (HLBG and HLBG.UI and HLBG.UI.History) then return end
        local ui = HLBG.UI.History
        key = tostring(key or '')
        if key == '' then return end
        if ui.sortKey == key then
            ui.sortDir = (ui.sortDir == 'ASC') and 'DESC' or 'ASC'
        else
            ui.sortKey = key
            ui.sortDir = 'DESC' -- default new key to DESC
        end
        if ui.lastRows then
            HLBG.History(ui.lastRows, ui.page, ui.per, ui.total, ui.sortKey, ui.sortDir)
        end
    end
end

-- Debug: Announce that functions are defined
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FF00HLBG Debug:|r History functions defined - History: %s, HistoryStr: %s", type(HLBG.History), type(HLBG.HistoryStr)))
end
