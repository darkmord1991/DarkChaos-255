local HLBG = _G.HLBG or {}; _G.HLBG = HLBG
-- Clean, single-definition History implementation.
-- Exposes: HLBG.History(rows, page, per, total, sortKey, sortDir)
--          HLBG.HistoryStr(tsv, page, per, total, sortKey, sortDir)
--          HLBG.HistoryApplySort(key)
-- Ensure UI table exists
HLBG.UI = HLBG.UI or {}
HLBG.UI.History = HLBG.UI.History or {}
local function ensure_ui()
    HLBG.UI = HLBG.UI or {}
    HLBG.UI.History = HLBG.UI.History or {}
    return HLBG.UI.History
end
-- Helper: sanitize and preserve valid UTF-8; adapted from prior implementation
local function keep_valid_utf8(s)
    if type(s) ~= 'string' then return s end
    local out = {}
    local i = 1; local n = #s
    while i <= n do
        local b = string.byte(s, i)
        if not b then break end
        if b < 0x80 then
            if b == 9 or b == 10 or b >= 32 then out[#out+1] = string.char(b) else out[#out+1] = ' ' end
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
local function sanitize_tsv(tsv)
    if type(tsv) ~= 'string' then return tsv end
    tsv = tsv:gsub('\r\n','\n'):gsub('\r','\n')
    -- convert pipe-only payloads into tab-separated fields on a single line
    if tsv:find('|') and not tsv:find('\n') then
        -- replace pipes (optionally surrounded by whitespace) with a single tab
        tsv = tsv:gsub('%s*%|%s*', '\t')
    end
    tsv = keep_valid_utf8(tsv)
    return tsv
end
-- Main History renderer
HLBG.History = HLBG.History or function(rows, page, per, total, sortKey, sortDir)
    local ui = ensure_ui()
    if type(rows) ~= 'table' then rows = {} end
    ui.page = tonumber(page) or ui.page or 1
    ui.per  = tonumber(per)  or ui.per  or 25
    ui.total= tonumber(total)or ui.total or #rows
    ui.sortKey = sortKey or ui.sortKey or 'id'
    ui.sortDir = sortDir or ui.sortDir or 'DESC'
    -- Normalize rows into an array of tables
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
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFFFF3333HLBG Debug|r History.Content missing! UI=%s History=%s',
                tostring(HLBG.UI ~= nil), tostring(HLBG.UI and HLBG.UI.History ~= nil)))
        end
        -- Dev: schedule a one-shot retry to render if UI appears shortly after
        if not HLBG._historyDeferredRetryScheduled then
            HLBG._historyDeferredRetryScheduled = true
            C_Timer.After(1.0, function()
                HLBG._historyDeferredRetryScheduled = false
                if HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.Content and HLBG.UI.History.lastRows then
                    -- Re-invoke with preserved lastRows
                    pcall(HLBG.History, HLBG.UI.History.lastRows, HLBG.UI.History.page or 1, HLBG.UI.History.per or 15, HLBG.UI.History.total or #HLBG.UI.History.lastRows, HLBG.UI.History.sortKey or 'id', HLBG.UI.History.sortDir or 'DESC')
                    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                        DEFAULT_CHAT_FRAME:AddMessage('|cFF33FF99HLBG Debug|r Deferred history render invoked')
                    end
                end
            end)
        end
        return
    end
    -- EXTENSIVE DEBUG: Log Content frame state
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local isShown = cont:IsShown() and "YES" or "NO"
        local width, height = cont:GetSize()
        local parent = cont:GetParent()
        local parentName = parent and parent:GetName() or "nil"
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFFAA00FF[History Content]|r Shown=%s Size=%.0fx%.0f Parent=%s',
            isShown, width, height, parentName))
    end
    ui.rows = ui.rows or {}
    -- hide old
    for i,r in ipairs(ui.rows) do if r.Hide then r:Hide() end end
    local function Row(i)
        local r = ui.rows[i]; if r then return r end
        r = CreateFrame('Frame', 'HLBG_HistoryRow_'..i, cont)
        r:SetSize(550, 22)  -- FIX: Set width=550px height=22px (was missing width!)
        r:SetBackdrop({
            bgFile='Interface/Tooltips/UI-Tooltip-Background',
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        local fields = {'id','sea','ts','win','aff','dur','rea'}
        local widths = {40,40,135,65,65,55,80}  -- Adjusted widths for better fit
        local prev
        for idx,name in ipairs(fields) do
            local fs = r:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
            r[name]=fs
            if idx==1 then
                fs:SetPoint('LEFT', r,'LEFT',8,0)  -- Increased left padding
            else
                fs:SetPoint('LEFT', prev,'RIGHT',3,0)  -- Reduced spacing between columns
            end
            fs:SetWidth(widths[idx])
            fs:SetTextColor(1,1,1,1) -- Force white text
            fs:SetJustifyH("LEFT")  -- Left-align text
            if fs.SetFont then fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE") end  -- Slightly smaller font
            prev=fs
        end
        ui.rows[i]=r
        return r
    end
    local y = -10  -- Start slightly below top using negative coordinates (standard ScrollFrame)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Starting to render %d rows, Content=%s', #rows, tostring(cont ~= nil)))
    end
    for i,row in ipairs(rows) do
        local r = Row(i)
        r:ClearAllPoints(); r:SetPoint('TOPLEFT', cont,'TOPLEFT',5,y)
        r.rowData=row; r.rowIndex=i
        -- EXTENSIVE DEBUG: Log row frame state
        if i == 1 and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            local rShown = r:IsShown() and "YES" or "NO"
            local rWidth, rHeight = r:GetSize()
            local rParent = r:GetParent()
            local rParentName = rParent and rParent:GetName() or "nil"
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFFAA00FF[History Row1]|r Shown=%s Size=%.0fx%.0f Parent=%s Y=%d',
                rShown, rWidth, rHeight, rParentName, y))
        end
        if i % 2 == 0 then
            r:SetBackdropColor(0.10,0.10,0.10,0.50)
        else
            r:SetBackdropColor(0.05,0.05,0.05,0.30)
        end
        local ts_num = tonumber(row.ts)
        local tsText
        if ts_num and ts_num > 0 then
            tsText = date('%Y-%m-%d %H:%M', ts_num)
        else
            -- If row.ts is a non-empty string (e.g. parsed '2025-10-07 20:05:44'), display it directly
            if type(row.ts) == 'string' and row.ts:match('%S') then tsText = row.ts else tsText = '-' end
        end
        r.id:SetText(row.id or '-')
        r.sea:SetText(row.season or row.seasonName or '-')
        r.ts:SetText(tsText)
        local winTxt = row.winner or '-'
        if row.winner_tid==67 then winTxt='|cFFFF0000Horde|r' elseif row.winner_tid==469 then winTxt='|cFF0000FFAlliance|r' end
        r.win:SetText(winTxt)
        r.aff:SetText(HLBG.GetAffixName and HLBG.GetAffixName(row.affix) or (row.affix or '-'))
        local dur = tonumber(row.dur) or 0; r.dur:SetText(dur>0 and SecondsToTime(dur) or '-')
        r.rea:SetText(row.reason or '-')
        -- Debug: print row text
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Row %d text: id=%s sea=%s ts=%s win=%s aff=%s dur=%s rea=%s',
                i, tostring(row.id or '-'), tostring(row.season or row.seasonName or '-'), tsText, winTxt, tostring(row.affix or '-'), tostring(dur>0 and SecondsToTime(dur) or '-'), tostring(row.reason or '-')))
        end
        r:Show()
        y = y - 22  -- Move down for next row (more negative = further down in TOPLEFT anchor)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r Row %d: created and shown at y=%d', i, y))
        end
    end
    cont:SetHeight(math.max(120, (#rows*22)+40))  -- Extra padding
    -- Ensure scroll is reset to top so the first rows are visible
    pcall(function()
        if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Scroll and HLBG.UI.History.Scroll.SetVerticalScroll then
            HLBG.UI.History.Scroll:SetVerticalScroll(0)
        end
    end)
    -- Hide the "Loading..." text when we have data
    if ui.EmptyText then
        if #rows > 0 then
            ui.EmptyText:Hide()
        else
            ui.EmptyText:Show()
        end
    end
    -- Debug success message
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF00FF33HLBG Debug|r History rendered %d rows successfully! Content height set to %.0f', #rows, cont:GetHeight()))
    end
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
        tsv = sanitize_tsv(tsv)
        HLBG._lastSanitizedTSV = tsv
        pcall(function()
            local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
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
        pcall(function()
            local dev = HLBG._devMode or (DCHLBGDB and DCHLBGDB.devMode)
            local escN = 0; tsv, escN = tsv:gsub('\\n', '\n')
            local escT = 0; tsv, escT = tsv:gsub('\\t', '\t')
            if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage and (escN > 0 or escT > 0) then
                DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr converted escaped seqs: \n=%d \t=%d', escN, escT))
            end
            local pipeCount = 0; for _ in tsv:gmatch('%|') do pipeCount = pipeCount + 1 end
            local hasNewline = tsv:find('\n') and true or false
            if pipeCount > 0 and not hasNewline then
                tsv = tsv:gsub('%s*%|%s*', '\n')
                HLBG._lastSanitizedTSV = tsv
                if dev and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format('|cFF33FF99HLBG Debug|r HistoryStr fallback: converted %d pipes into newlines', pipeCount))
                end
            end
            HLBG._lastSanitizedTSV = tsv
        end)
        local meta = tsv:match('^TOTAL=(%d+)%s*%|%|') or tsv:match('^TOTAL=(%d+)%s*')
        if meta then reportedTotal=tonumber(meta) or reportedTotal; tsv = tsv:gsub('^TOTAL=%d+%s*%|%|',''):gsub('^TOTAL=%d+%s*','') end
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
        if not HLBG._parseHistLineFlexible then
            HLBG._parseHistLineFlexible = function(line)
                if type(line) ~= 'string' then return nil end
                local s = line:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
                local ts = s:match('(%d%d%d%d%-%d%d%-%d%d% %d%d:%d%d:%d%d)') or s:match('(%d%d%d%d%-%d%d%-%d%d% %d%d:%d%d)')
                if ts then
                    local before, after = s:match('^(.-)'..ts..'(.*)$')
                    before = before or ''
                    after = after or ''
                    local id = before:match('(%d+)%s*$') or before:match('(%S+)') or ''
                    local winner = after:match('%s*(%a+)%s+') or after:match('^%s*(%a+)') or ''
                    local aff = after:match('%s+(%d+)%s+') or after:match('%s+(%d+)$') or ''
                    local reason = (aff ~= '') and (after:match('%d+%s+(.*)$') or after) or after
                    reason = reason and reason:gsub('^%s+','') or '-'
                    return { id = tostring(id), ts = tostring(ts), winner = tostring(winner or '-'), affix = tostring(aff or '-'), reason = tostring(reason or '-') }
                else
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
            line = line:gsub('^%s+',''):gsub('%s+$','')
            if line ~= '' then
                local cols = split_fields(line)
                for i=1,#cols do cols[i] = (cols[i] or ''):gsub('^%s+',''):gsub('%s+$','') end
                if #cols >= 7 and cols[4] and cols[4]:match('^%d%d%d%d%-%d%d%-%d%d') then
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
-- Sorting API
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
            ui.sortDir = 'DESC'
        end
        if ui.lastRows then
            HLBG.History(ui.lastRows, ui.page, ui.per, ui.total, ui.sortKey, ui.sortDir)
        end
    end
end
-- Debug announce
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FF00HLBG Debug:|r History functions defined - History: %s, HistoryStr: %s", type(HLBG.History), type(HLBG.HistoryStr)))
end

