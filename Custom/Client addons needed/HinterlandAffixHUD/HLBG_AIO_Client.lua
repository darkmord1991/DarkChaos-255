local HLBG = _G.HLBG or {}
_G.HLBG = HLBG
-- Developer mode flag: when true, extra test slash commands will be registered.
HLBG._devMode = HLBG._devMode or false
-- If user saved a persistent devMode, honor it on load
HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
if HinterlandAffixHUDDB.devMode ~= nil then HLBG._devMode = HinterlandAffixHUDDB.devMode and true or false end
-- Default to 1 to match many legacy DBs; user can change via "/hlbg season <n>"
HinterlandAffixHUDDB.desiredSeason = HinterlandAffixHUDDB.desiredSeason or 1
function HLBG._getSeason()
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    local s = tonumber(HinterlandAffixHUDDB.desiredSeason or 0) or 0
    if s < 0 then s = 0 end
    return s
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

            safeRegisterSlash('HLBGJSONTestrun', '/hlbgjsontestrun', function(msg) pcall(HLBG.PrintJsonTestRun, (msg and msg:match("%d+")) and tonumber(msg:match("%d+")) or 1) end)
        end
    -- small debug to surface incoming argument shapes when things go wrong
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        local function shortType(v) if v == nil then return "nil" end return type(v) end
        local sampleInfo = ""
        if type(rows) == "table" then
            local n = #rows
            if n > 0 and type(rows[1]) == "table" then
                local first = rows[1]
                local keys = {}
                for k,_ in pairs(first) do table.insert(keys, tostring(k)) end
                sampleInfo = string.format(" sampleRowKeys=%s", table.concat(keys, ","))
            elseif n > 0 then
                sampleInfo = string.format(" sampleRow0=%s", tostring(rows[1]))
            end
        end
        -- debug trace
        if type(DEFAULT_CHAT_FRAME.AddMessage) == "function" then
            local newH = math.max(300, 8 + #rows * 28)
            local n = (#rows) or 0
            DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: History handler invoked (rowsType=%s, n=%d)%s", shortType(rows), n, sampleInfo))
        end
    end
    -- If rows is not a table but we received a TSV string in one of the args, try the TSV fallback parser
    if type(rows) ~= "table" then
        -- detect a TSV payload among args (usually first or second arg)
        local tsv = nil
        if type(a) == "string" and a:find("\t") then tsv = a end
        if not tsv and type(b) == "string" and b:find("\t") then tsv = b end
        if tsv and type(HLBG.HistoryStr) == "function" then
            DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: No table rows received, attempting TSV fallback")
            return HLBG.HistoryStr(a,b,c,d,e,f,g)
        end
        rows = {}
    end
    HLBG.UI.History.page = page or HLBG.UI.History.page or 1
    HLBG.UI.History.per = per or HLBG.UI.History.per or 25
    HLBG.UI.History.total = total or HLBG.UI.History.total or 0
    HLBG.UI.History.sortKey = col or HLBG.UI.History.sortKey or "id"
    HLBG.UI.History.sortDir = dir or HLBG.UI.History.sortDir or "DESC"

    -- Normalize rows: some transports may send a map rather than a sequence
    local normalized = {}
    if type(rows) == "table" then
        -- Fast path: already sequence-like
        if #rows and #rows > 0 then
            normalized = rows
        else
            -- Collect values which are tables (likely row objects) and sort by numeric key if present
            local tmp = {}
            for k,v in pairs(rows) do
                if type(v) == "table" then
                    local nk = tonumber(k)
                    if nk then
                        tmp[nk] = v
                    else
                        table.insert(tmp, v)
                    end
                end
            end
            -- If tmp has numeric indices, build dense array in numeric order
            local hasNumeric = false
            for k,_ in pairs(tmp) do if type(k) == "number" then hasNumeric = true; break end end
            if hasNumeric then
                local i = 1
                while tmp[i] do table.insert(normalized, tmp[i]); i = i + 1 end
            else
                -- fallback: take insertion order
                for _,v in ipairs(tmp) do table.insert(normalized, v) end
            end
        end
    end
    -- If we still have nothing, ensure rows is at least an empty array
    if #normalized == 0 and type(rows) == "table" then
        -- maybe rows is a single map representing one row
        if type(rows.id) ~= "nil" or type(rows.ts) ~= "nil" then
            table.insert(normalized, rows)
        end
    end

    -- debug: report normalized shapes
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG DBG: Normalized rows count=%d (origType=%s)", #normalized, type(rows)))
    end

    rows = normalized

    -- persist last received history rows for debugging/replay
    if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
    HLBG.UI.History.lastRows = rows
    -- store a compact sample line (timestamp + count + first row summary) to saved buffer
    do
        local sample = ""
        if #rows > 0 and type(rows[1]) == 'table' then
            local r = rows[1]
            local id = tostring(r[1] or r.id or "")
            local ts = tostring(r[2] or r.ts or "")
            local win = tostring(r[3] or r.winner or "")
            sample = string.format("%s\t%s\t%s\t%s", id, ts, win, tostring(r[4] or r.affix or ""))
        end
        table.insert(HinterlandAffixHUD_DebugLog, 1, string.format("[%s] HISTORY N=%d sample=%s", date("%Y-%m-%d %H:%M:%S"), #rows, sample))
        while #HinterlandAffixHUD_DebugLog > 200 do table.remove(HinterlandAffixHUD_DebugLog) end
    end

    -- send a compact sample to server-side log for easier debugging (if helper available)
    local okSend, sendFn = pcall(function() return _G.HLBG_SendClientLog end)
    local send = (okSend and type(_G.HLBG_SendClientLog) == "function") and _G.HLBG_SendClientLog or ((type(HLBG) == "table" and type(HLBG.SendClientLog) == "function") and HLBG.SendClientLog or nil)
    if send then
        local sample = ""
        if #rows > 0 and type(rows[1]) == "table" then
            local r = rows[1]
            local id = tostring(r[1] or r.id or "")
            local ts = tostring(r[2] or r.ts or "")
            local win = tostring(r[3] or r.winner or "")
            local aff = tostring(r[4] or r.affix or "")
            sample = string.format("%s\t%s\t%s\t%s", id, ts, win, aff)
        end
        pcall(function() send(string.format("HISTORY_CLIENT N=%d sample=%s", #rows, sample)) end)
    end

    -- Additional local debug: print first-row keys/values and force UI visible so we can inspect rendering
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG DBG: After normalize rows=%d total=%s", #rows, tostring(HLBG.UI.History.total)))
        if #rows > 0 and type(rows[1]) == "table" then
            local keys = {}
            for k,v in pairs(rows[1]) do table.insert(keys, tostring(k)..":"..tostring(v)) end
            DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: firstRow="..table.concat(keys, ", "))
        end
    end

    -- Ensure the UI is visible so the user can inspect whether rows were created
    if HLBG.UI and HLBG.UI.Frame then HLBG.UI.Frame:Show(); ShowTab(2) end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Content then HLBG.UI.History.Content:Show() end
    if HLBG.UI and HLBG.UI.History and HLBG.UI.History.Scroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end

    -- Render with a simple row widget pool
    local function getRow(i)
        local r = HLBG.UI.History.rows[i]
        if not r then
            r = CreateFrame("Frame", nil, HLBG.UI.History.Content)
                if r.SetFrameStrata then r:SetFrameStrata("DIALOG") end
            r:SetSize(420, 14)
            r.id = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.sea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.ts = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.win = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.aff = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            r.rea = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                -- force visible text color for debugging
                if r.id.SetTextColor then r.id:SetTextColor(1,1,1,1) end
                if r.sea.SetTextColor then r.sea:SetTextColor(1,1,1,1) end
                if r.ts.SetTextColor then r.ts:SetTextColor(1,1,1,1) end
                if r.win.SetTextColor then r.win:SetTextColor(1,1,1,1) end
                if r.aff.SetTextColor then r.aff:SetTextColor(1,1,1,1) end
                if r.rea.SetTextColor then r.rea:SetTextColor(1,1,1,1) end
            -- layout mirrors headers: ID(50), SEASON(50), TS(120), WIN(80), AFF(70), REASON(50) with 6px spacing
            r.id:SetPoint("LEFT", r, "LEFT", 0, 0)
            r.id:SetWidth(50); HLBG.safeSetJustify(r.id, "LEFT")
            r.sea:SetPoint("LEFT", r.id, "RIGHT", 6, 0)
            r.sea:SetWidth(50); HLBG.safeSetJustify(r.sea, "LEFT")
            r.ts:SetPoint("LEFT", r.sea, "RIGHT", 6, 0)
            r.ts:SetWidth(120); HLBG.safeSetJustify(r.ts, "LEFT")
            r.win:SetPoint("LEFT", r.ts, "RIGHT", 6, 0)
            r.win:SetWidth(80); HLBG.safeSetJustify(r.win, "LEFT")
            r.aff:SetPoint("LEFT", r.win, "RIGHT", 6, 0)
            r.aff:SetWidth(70); HLBG.safeSetJustify(r.aff, "LEFT")
            r.rea:SetPoint("LEFT", r.aff, "RIGHT", 6, 0)
            r.rea:SetWidth(50); HLBG.safeSetJustify(r.rea, "LEFT")
            HLBG.UI.History.rows[i] = r
        end
        return r
    end

    -- hide all previously visible rows
    for i=1,#HLBG.UI.History.rows do HLBG.UI.History.rows[i]:Hide() end

    local y = -22
    local hadRows = false
    for i, row in ipairs(rows) do
        local r = getRow(i)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", HLBG.UI.History.Content, "TOPLEFT", 0, y)
        -- Prefer named fields; fallback to compact array rows.
        -- Common server compact shape: { id, timestamp, winner, affix, reason }
        local id = row.id or row[1]
        local sea = row.season
        local sname = row.seasonName or row.sname or nil
        -- Detect array-like compact shapes and map indices to named fields
        local compact_len = (type(row) == 'table' and #row) or 0
        local ts, win, affix, reas
        if compact_len >= 5 then
            -- server: { id, ts, winner, affix, reason }
            ts = row[2]
            win = row[3]
            affix = row[4]
            reas = row[5]
        elseif compact_len == 4 then
            -- maybe { id, ts, winner, affix }
            ts = row[2]
            win = row[3]
            affix = row[4]
            reas = row.reason or row[5]
        elseif compact_len == 3 then
            ts = row[2]
            win = row[3]
            affix = row.affix or row[4]
            reas = row.reason or row[5]
        else
            -- fallback to existing heuristics using named fields or shifted indices
            ts = row.ts or row[3] or row[2]
            win = row.winner or row[4] or row[3]
            affix = row.affix or row[5] or row[4]
            reas = row.reason or row[6] or row[5]
        end
        local who = (win == "Alliance" or win == "ALLIANCE") and "|cff1e90ffAlliance|r" or (win == "Horde" or win == "HORDE") and "|cffff0000Horde|r" or "|cffffff00Draw|r"
    -- Show id as-is (don't coerce to 0 when it's non-numeric)
    r.id:SetText(tostring(id or ""))
    if sname and sname ~= "" then
        r.sea:SetText(tostring(sname))
    else
        r.sea:SetText(tostring(sea or ""))
    end
    r.ts:SetText(ts or "")
    r.win:SetText(who)
    r.aff:SetText(HLBG.GetAffixName(affix))
    r.rea:SetText(reas or "-")
        if not r._hlbgHover then
            r._hlbgHover = true
            r:SetScript('OnEnter', function(self)
                self:SetBackdrop({ bgFile = 'Interface/Tooltips/UI-Tooltip-Background' })
                self:SetBackdropColor(1,1,0.4,0.10)
            end)
            r:SetScript('OnLeave', function(self)
                self:SetBackdrop(nil)
            end)
        end
        r:Show()
        y = y - 14
        hadRows = true
    end

    local maxPage = (HLBG.UI.History.total and HLBG.UI.History.total > 0) and math.max(1, math.ceil(HLBG.UI.History.total/(HLBG.UI.History.per or 25))) or (HLBG.UI.History.page or 1)
    HLBG.UI.History.Nav.PageText:SetText(string.format("Page %d / %d", HLBG.UI.History.page, maxPage))
    local hasPrev = (HLBG.UI.History.page or 1) > 1
    local hasNext = (HLBG.UI.History.page or 1) < maxPage
    if HLBG.UI.History.Nav.Prev then if hasPrev then HLBG.UI.History.Nav.Prev:Enable() else HLBG.UI.History.Nav.Prev:Disable() end end
    if HLBG.UI.History.Nav.Next then if hasNext then HLBG.UI.History.Nav.Next:Enable() else HLBG.UI.History.Nav.Next:Disable() end end

    -- Resize scroll child to the content and reset scroll to top
    local visibleCount = (type(rows) == "table" and #rows) or 0
    local base = 22 -- header area height used above
    local rowH = 14
    local minH = 300
    local newH = math.max(minH, base + visibleCount * rowH + 8)
    HLBG.UI.History.Content:SetHeight(newH)
    if HLBG.UI.History.Scroll and HLBG.UI.History.Scroll.SetVerticalScroll then HLBG.UI.History.Scroll:SetVerticalScroll(0) end
    if HLBG.UI.History.EmptyText then
        if hadRows then HLBG.UI.History.EmptyText:Hide() else HLBG.UI.History.EmptyText:Show() end
    end

    -- optional debug
    DEFAULT_CHAT_FRAME:AddMessage(string.format("HLBG: History received rows=%d total=%s", visibleCount, tostring(HLBG.UI.History.total)))
end

function HLBG.Stats(player, stats)
    if not HLBG._ensureUI('Stats') then return end
    -- Accept being called as (stats) or (player, stats)
    if type(player) ~= "string" and type(player) ~= "userdata" then
        stats = player
    end
    stats = stats or {}
    HLBG._lastStats = stats

    -- Debounce heavy formatting to avoid UI stalls when multiple updates arrive quickly.
    -- Schedule a short deferred update (150ms). If another update arrives before the timer
    -- fires, it will replace the pending stats and only the last will be processed.
    local delay = 0.15
    local pending = HLBG.UI.Stats
    pending._pendingStats = stats
    pending._pending = true
    if not pending._timer then
        pending._timer = CreateFrame("Frame")
        pending._timer._elapsed = 0
        pending._timer:SetScript("OnUpdate", function(self, elapsed)
            pending._timer._elapsed = pending._timer._elapsed + (elapsed or 0)
            if pending._timer._elapsed < delay then return end
            -- consume the pending stats and clear timer
            pending._timer._elapsed = 0
            self:SetScript("OnUpdate", nil)
            pending._pending = false
            local s = pending._pendingStats or {}

            -- Formatting logic (same output as before) but executed once after debounce
            local counts = s.counts or {}
            local a = (counts["Alliance"] or counts["ALLIANCE"] or 0)
            local h = (counts["Horde"] or counts["HORDE"] or 0)
            local d = s.draws or 0
            local ssz = tonumber(s.season or s.Season or 0) or 0
            local sname = s.seasonName or s.SeasonName
            local seasonStr
            if sname and sname ~= "" then
                seasonStr = "  Season: "..tostring(sname)
            elseif ssz and ssz > 0 then
                seasonStr = "  Season: "..tostring(ssz)
            else
                seasonStr = ""
            end
            local lines = { string.format("Alliance: %d  Horde: %d  Draws: %d  Avg: %d min%s", a, h, d, math.floor((s.avgDuration or 0)/60), seasonStr) }

            -- local helpers
            local safeGetAffix = HLBG.GetAffixName
            local function top3Flexible(v)
                local items = {}
                if type(v) == 'table' then
                    if #v > 0 then
                        for i=1,#v do
                            local row = v[i]
                            local total = (tonumber(row.Alliance or row.alliance or row.A or 0) or 0)
                                        + (tonumber(row.Horde or row.horde or row.H or 0) or 0)
                                        + (tonumber(row.DRAW or row.draw or row.D or 0) or 0)
                            local label = row.weather or (row.affix and safeGetAffix(row.affix)) or tostring(i)
                            table.insert(items, {label=label, total=total})
                        end
                    else
                        for k,row in pairs(v) do
                            local total = (tonumber(row.Alliance or 0) or 0) + (tonumber(row.Horde or 0) or 0) + (tonumber(row.DRAW or 0) or 0)
                            table.insert(items, {label=tostring(k), total=total})
                        end
                    end
                end
                table.sort(items, function(a,b) return a.total > b.total end)
                local out = {}
                for i=1,math.min(3,#items) do table.insert(out, string.format("%s:%d", items[i].label, items[i].total)) end
                return table.concat(out, ", ")
            end

            if s.byAffix and next(s.byAffix) then table.insert(lines, "Top Affixes: "..top3Flexible(s.byAffix)) end
            if s.byWeather and next(s.byWeather) then table.insert(lines, "Top Weather: "..top3Flexible(s.byWeather)) end

            local function top3avg(map)
                local arr = {}
                for k,v in pairs(map or {}) do table.insert(arr, {k=k, v=tonumber(v.avg or 0)}) end
                table.sort(arr, function(x,y) return x.v>y.v end)
                local out = {}
                for i=1,math.min(3,#arr) do table.insert(out, string.format("%s:%d min", arr[i].k, math.floor((arr[i].v or 0)/60))) end
                return table.concat(out, ", ")
            end
            if s.affixDur and next(s.affixDur) then table.insert(lines, "Slowest Affixes (avg): "..top3avg(s.affixDur)) end
            if s.weatherDur and next(s.weatherDur) then table.insert(lines, "Slowest Weather (avg): "..top3avg(s.weatherDur)) end

            -- Single UI update
            if HLBG.UI and HLBG.UI.Stats and HLBG.UI.Stats.Text then
                HLBG.UI.Stats.Text:SetText(table.concat(lines, "\n"))
            end
        end)
    else
        -- reset timer (another update arrived); restart OnUpdate
        pending._timer._elapsed = 0
        pending._timer:SetScript("OnUpdate", pending._timer:GetScript("OnUpdate"))
    end
end

-- Provide uppercase aliases in case the dispatcher normalizes names
HLBG.HISTORY = function(...) return HLBG.History(...) end
HLBG.STATS = function(...) return HLBG.Stats(...) end
function HLBG.DBG(msg)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("HLBG DBG: "..tostring(msg)) end
end

-- Warmup notice handler: server can notify client warmup has begun
function HLBG.Warmup(info)
    if not HLBG._ensureUI('Warmup') then return end
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if not HinterlandAffixHUDDB.enableWarmupCTA then return end
    local txt = "Warmup has begun! Use the Queue tab to join from safe areas."
    if type(info) == 'string' and info ~= '' then txt = info end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00HLBG|r: "..txt) end
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText("Warmup active — join now!") end
end

-- Queue status updates (e.g., position in queue, joined, left)
function HLBG.QueueStatus(status)
    if not HLBG._ensureUI('QueueStatus') then return end
    local s = (type(status) == 'string' and status) or (type(status) == 'table' and (status.text or status.state)) or 'Unknown'
    if HLBG.UI and HLBG.UI.Queue and HLBG.UI.Queue.Status then HLBG.UI.Queue.Status:SetText("Queue status: "..tostring(s)) end
end

-- Results payload from server after match completion
function HLBG.Results(summary)
    if not HLBG._ensureUI('Results') then return end
    local lines = { "Results will appear after each match." }
    if type(summary) == 'table' then
        local win = summary.winner or summary.Win or summary.result
        local aff = summary.affix or summary.Affix
        local dur = summary.duration or summary.Duration
        table.insert(lines, string.format("Winner: %s", tostring(win or "?")))
        if aff then table.insert(lines, "Affix: "..HLBG.GetAffixName(aff)) end
        if dur then table.insert(lines, string.format("Duration: %s", SecondsToClock(tonumber(dur) or 0))) end
        if summary.rewards then table.insert(lines, "Rewards: "..tostring(summary.rewards)) end
        if summary.special then table.insert(lines, "Special: "..tostring(summary.special)) end
    end
    if HLBG.UI and HLBG.UI.Results and HLBG.UI.Results.Text then HLBG.UI.Results.Text:SetText(table.concat(lines, "\n")) end
    -- switch to Results tab if user has window open
    if HLBG.UI and HLBG.UI.Frame and HLBG.UI.Frame:IsShown() then ShowTab(6) end
end

-- Send a client log line to server for file-backed logging via AIO
-- Provide a stable global SendClientLog function so slash handlers work even if HLBG table is replaced
local function SendClientLogLocal(msg)
    if not msg then return end
    local payload = string.format("[%s] %s", date("%Y-%m-%d %H:%M:%S"), tostring(msg))
    if _G.AIO and _G.AIO.Handle then
        pcall(function() _G.AIO.Handle("HLBG", "Request", "CLIENTLOG", payload) end)
    else
        -- fallback: store in saved buffer for later
        if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
        table.insert(HinterlandAffixHUD_DebugLog, 1, payload)
        while #HinterlandAffixHUD_DebugLog > 200 do table.remove(HinterlandAffixHUD_DebugLog) end
    end
end

-- Attach both to HLBG (if present) and a global name to avoid timing issues when AIO.AddHandlers swaps the HLBG table
if type(HLBG) == "table" then HLBG.SendClientLog = SendClientLogLocal end
_G.HLBG_SendClientLog = SendClientLogLocal


-- Slash to send most recent saved debug line to server log
safeRegisterSlash('HLBGLOG', '/hlbglog', function()
    local line = (HinterlandAffixHUD_DebugLog and HinterlandAffixHUD_DebugLog[1])
    if not line then
        -- assemble diagnostic snapshot
        local ver = (GetAddOnMetadata and GetAddOnMetadata("HinterlandAffixHUD", "Version")) or "?"
        local aio = (_G.AIO and _G.AIO.Handle) and "yes" or "no"
        local lastHistN = (HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows and #HLBG.UI.History.lastRows) or 0
        local lastStats = (HLBG and HLBG._lastStats) or nil
        local statsJson = "{}"
        if type(lastStats) == 'table' then
            -- try to stringify minimal fields
            local counts = lastStats.counts or {}
            statsJson = string.format('{"Alliance":%d,"Horde":%d,"draws":%d}', tonumber(counts.Alliance or counts.ALLIANCE or 0) or 0, tonumber(counts.Horde or counts.HORDE or 0) or 0, tonumber(lastStats.draws or 0) or 0)
        end
        line = string.format("HLBG client snapshot: ver=%s aio=%s lastHistoryN=%d stats=%s", tostring(ver), tostring(aio), tonumber(lastHistN) or 0, tostring(statsJson))
    end
    HLBG.SendClientLog(line)
    DEFAULT_CHAT_FRAME:AddMessage("HLBG: Sent client log to server (check /home/wowcore/azeroth-server/logs/hlbg_client.log)")
end)
-- Fallback: parse History from TSV string payload
function HLBG.HistoryStr(a, b, c, d, e, f, g)
    if not HLBG._ensureUI('HistoryStr') then return end
    local tsv, page, per, total, col, dir
    if type(a) == "string" then
        tsv, page, per, total, col, dir = a, b, c, d, e, f
    else
        tsv, page, per, total, col, dir = b, c, d, e, f, g
    end
    -- Normalize payload: convert CRLF to LF, convert our backup '||' line sep to newlines,
    -- and convert '|' field separators to tabs in case the client stripped real tabs.
    if type(tsv) == 'string' then
        tsv = tsv:gsub('\r', '')
        tsv = tsv:gsub('%|%|', '\n')
        tsv = tsv:gsub('%|', '\t')
        -- Replace any remaining control chars (except newline and tab) with tab as a safe field sep
        tsv = tsv:gsub('[\001-\008\011\012\014-\031]', '\t')
        -- Strip WoW color codes if present (|cAARRGGBB ... |r)
        tsv = tsv:gsub('%|c%x%x%x%x%x%x%x%x', ''):gsub('%|r', '')
    end
    local rows = {}
    if type(tsv) == "string" and tsv ~= "" then
        for line in tsv:gmatch("[^\n]+") do
            -- Try strict 7-col TAB format first
            local id7, season7, sname7, ts7, win7, aff7, rea7 = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
            if id7 and ts7 and win7 and aff7 and rea7 then
                table.insert(rows, { id = id7 or "", season = tonumber(season7) or season7, seasonName = sname7, ts = ts7 or "", winner = win7 or "", affix = aff7 or "", reason = rea7 or "" })
            else
                -- Tokenize by tabs (after normalization control chars -> tabs)
                local cols = {}
                for fld in string.gmatch(line, "([^\t]+)") do cols[#cols+1] = fld end
                if #cols >= 7 then
                    table.insert(rows, { id = cols[1] or "", season = tonumber(cols[2]) or cols[2], seasonName = cols[3], ts = cols[4] or "", winner = cols[5] or "", affix = cols[6] or "", reason = cols[7] or "" })
                elseif #cols == 6 then
                    -- Two possibilities:
                    --  a) {id, season, ts, winner, affix, reason}
                    --  b) {id, seasonName(="Season X"), ts, winner, affix, reason}
                    local seasonNum = tonumber(cols[2])
                    local seasonName = nil
                    if not seasonNum and type(cols[2]) == 'string' then
                        local n = tonumber((cols[2]):match("Season%s+(%d+)") or '')
                        if n then seasonNum = n; seasonName = cols[2] end
                    end
                    table.insert(rows, { id = cols[1] or "", season = seasonNum or cols[2], seasonName = seasonName, ts = cols[3] or "", winner = cols[4] or "", affix = cols[5] or "", reason = cols[6] or "" })
                elseif #cols == 5 then
                    table.insert(rows, { id = cols[1] or "", ts = cols[2] or "", winner = cols[3] or "", affix = cols[4] or "", reason = cols[5] or "" })
                else
                    -- Best-effort: split by whitespace
                    local parts = {}
                    for w in string.gmatch(line, "(%S+)") do parts[#parts+1] = w end
                    if #parts >= 5 then
                        -- attempt to rejoin 'Season X' if present
                        local sname, sidx = nil, nil
                        for i=1,#parts-1 do if parts[i] == 'Season' and tonumber(parts[i+1]) then sname = parts[i] .. ' ' .. parts[i+1]; sidx = i; break end end
                        if sidx then table.remove(parts, sidx); parts[sidx] = sname end
                        if #parts >= 7 then
                            table.insert(rows, { id = parts[1], season = tonumber(parts[2]) or parts[2], seasonName = parts[3], ts = parts[4], winner = parts[5], affix = parts[6], reason = parts[7] })
                        elseif #parts == 6 then
                            local seasonNum = tonumber(parts[2]) or tonumber((parts[2] or ''):match('Season%s+(%d+)') or '')
                            table.insert(rows, { id = parts[1], season = seasonNum or parts[2], ts = parts[3], winner = parts[4], affix = parts[5], reason = parts[6] })
                        else
                            table.insert(rows, { id = parts[1], ts = parts[2], winner = parts[3], affix = parts[4], reason = parts[5] })
                        end
                    end
                end
            end
        end
    end
    return HLBG.History(rows, page, per, total, col, dir)
end

-- Support addon-channel STATUS & AFFIX messages to drive HUD
-- CHAT_MSG_ADDON and PvP helpers are now in HLBG_Handlers.lua

    -- Warmup notice
    local warm = msg:match('%[HLBG_WARMUP%]%s*(.*)')
    if warm then
        if type(HLBG.Warmup) == 'function' then pcall(HLBG.Warmup, warm) end
        return
    end

    -- Queue status
    local q = msg:match('%[HLBG_QUEUE%]%s*(.*)')
    if q then
        if type(HLBG.QueueStatus) == 'function' then pcall(HLBG.QueueStatus, q) end
        return
    end

    -- Results JSON
    local rj = msg:match('%[HLBG_RESULTS_JSON%]%s*(.*)')
    if rj then
        local ok, decoded = pcall(function() return json_decode(rj) end)
        if ok and type(decoded) == 'table' and type(HLBG.Results) == 'function' then pcall(HLBG.Results, decoded) end
        return
    end

    -- History TSV fallback
    local htsv = msg:match('%[HLBG_HISTORY_TSV%]%s*(.*)')
    if htsv then
        -- Support optional TOTAL=NN meta at the start
        local total = tonumber((htsv:match('^TOTAL=(%d+)%s*%|%|') or 0)) or 0
        htsv = htsv:gsub('^TOTAL=%d+%s*%|%|', '')
        -- Convert our '||' line placeholders back to real newlines and reuse HistoryStr
        htsv = htsv:gsub('%|%|', '\n')
        if type(HLBG.HistoryStr) == 'function' then pcall(HLBG.HistoryStr, htsv, 1, (HLBG.UI and HLBG.UI.History and HLBG.UI.History.per) or 5, total, 'id', 'DESC') end
        return
    end

    -- Stats JSON fallback
    local sj = msg:match('%[HLBG_STATS_JSON%]%s*(.*)')
    if sj then
        local ok, decoded = pcall(function()
            return (HLBG.json_decode and HLBG.json_decode(sj)) or (type(json_decode) == 'function' and json_decode(sj)) or nil
        end)
        if ok and type(decoded) == 'table' then
            -- If server included { total: N } and we have History UI, record it
            if decoded.total and HLBG.UI and HLBG.UI.History then HLBG.UI.History.total = tonumber(decoded.total) or HLBG.UI.History.total end
            if type(HLBG.Stats) == 'function' then pcall(HLBG.Stats, decoded) end
        end
        return
    end
end)

do
    local parent = (HLBG and HLBG.UI and HLBG.UI.Frame) or (UI and UI.Frame) or UIParent
    HLBG.UI.Refresh = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    HLBG.UI.Refresh:SetSize(80, 22)
    HLBG.UI.Refresh:SetPoint("TOPRIGHT", parent or UIParent, "TOPRIGHT", -18, -10)
    HLBG.UI.Refresh:SetText("Refresh")
    HLBG.UI.Refresh:SetScript("OnClick", function()
        if _G.AIO and _G.AIO.Handle then
            local h = (HLBG and HLBG.UI and HLBG.UI.History) or nil
            local p = (h and h.page) or 1
            local per = (h and h.per) or 5
            local sk = (h and h.sortKey) or "id"
            local sd = (h and h.sortDir) or "DESC"
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            -- Try multiple server call patterns for broad compatibility
            _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sk, sd)
            _G.AIO.Handle("HLBG", "Request", "HISTORY", p, per, sv, sk, sd)
            _G.AIO.Handle("HLBG", "History", p, per, sk, sd)
            _G.AIO.Handle("HLBG", "History", p, per, sv, sk, sd)
            _G.AIO.Handle("HLBG", "HISTORY", p, per, sk, sd)
            _G.AIO.Handle("HLBG", "HISTORY", p, per, sv, sk, sd)
            _G.AIO.Handle("HLBG", "Request", "STATS")
            _G.AIO.Handle("HLBG", "Request", "STATS", sv)
            _G.AIO.Handle("HLBG", "Stats")
            _G.AIO.Handle("HLBG", "Stats", sv)
            _G.AIO.Handle("HLBG", "STATS")
            _G.AIO.Handle("HLBG", "STATS", sv)
        end
        -- Also use chat fallbacks so refresh works without server-side AIO
        local h = (HLBG and HLBG.UI and HLBG.UI.History) or nil
        local p = (h and h.page) or 1
        local per = (h and h.per) or 5
        local sk = (h and h.sortKey) or "id"
        local sd = (h and h.sortDir) or "DESC"
    local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
    local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
    if sendDot then sendDot(string.format(".hlbg historyui %d %d %s %s", p, per, sk, sd)) end
    if sendDot then sendDot(string.format(".hlbg historyui %d %d %d %s %s", p, per, sv, sk, sd)) end
    if sendDot then sendDot(".hlbg statsui") end
    if sendDot then sendDot(string.format(".hlbg statsui %d", sv)) end
    end)
end

if HLBG and HLBG.UI and HLBG.UI.History and HLBG.UI.History.Columns then
    for i,h in ipairs(HLBG.UI.History.Columns) do
        h:SetScript("OnClick", function()
            local keyMap = { ID = "id", Season = "season", Timestamp = "occurred_at", Winner = "winner", Affix = "affix", Reason = "reason" }
            local sk = keyMap[h.Text:GetText()] or "id"
            local hist = HLBG.UI.History
            if hist.sortKey == sk then
                hist.sortDir = (hist.sortDir == "ASC") and "DESC" or "ASC"
            else
                hist.sortKey = sk; hist.sortDir = "DESC"
            end
            if _G.AIO and _G.AIO.Handle then
                local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
                _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page or 1, hist.per or 5, hist.sortKey, hist.sortDir)
                _G.AIO.Handle("HLBG", "Request", "HISTORY", hist.page or 1, hist.per or 5, sv, hist.sortKey, hist.sortDir)
            end
            -- Fallback: ask server via chat endpoints too
            local sendDot = (HLBG and HLBG.SendServerDot) or _G.HLBG_SendServerDot
            local sv = (HLBG and HLBG._getSeason and HLBG._getSeason()) or 0
            if sendDot then sendDot(string.format(".hlbg historyui %d %d %s %s", hist.page or 1, hist.per or 5, hist.sortKey or "id", hist.sortDir or "DESC")) end
            if sendDot then sendDot(string.format(".hlbg historyui %d %d %d %s %s", hist.page or 1, hist.per or 5, sv, hist.sortKey or "id", hist.sortDir or "DESC")) end
        end)
    end
end

-- Options in Interface panel to control addon HUD usage
local opt = CreateFrame("Frame", "HLBG_AIO_Options", InterfaceOptionsFramePanelContainer)
opt.name = "HLBG HUD"
opt:Hide()
opt:SetScript("OnShow", function(self)
  if self.init then return end; self.init = true
  local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 16, -16); title:SetText("HLBG HUD")
  local cb = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    -- 3.3.5: InterfaceOptionsCheckButtonTemplate may not expose .Text reliably; create our own label
    local cbLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText("Use addon HUD instead of Blizzard WG HUD")
    cb._label = cbLabel
  cb:SetChecked(HinterlandAffixHUDDB.useAddonHud)
    cb:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.useAddonHud = s:GetChecked() and true or false
        UpdateHUD()
    end)

    -- AFK warning toggle
    local cbAFK = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    cbAFK:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -12)
    local cbAFKLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbAFKLabel:SetPoint("LEFT", cbAFK, "RIGHT", 4, 0)
    cbAFKLabel:SetText("Enable AFK warning (combat-safe)")
    cbAFK._label = cbAFKLabel
    cbAFK:SetChecked(HinterlandAffixHUDDB.enableAFKWarning)
    cbAFK:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.enableAFKWarning = s:GetChecked() and true or false
    end)

    -- Warmup CTA toggle
    local cbWarm = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    cbWarm:SetPoint("TOPLEFT", cbAFK, "BOTTOMLEFT", 0, -12)
    local cbWarmLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbWarmLabel:SetPoint("LEFT", cbWarm, "RIGHT", 4, 0)
    cbWarmLabel:SetText("Enable warmup join prompt")
    cbWarm._label = cbWarmLabel
    cbWarm:SetChecked(HinterlandAffixHUDDB.enableWarmupCTA)
    cbWarm:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.enableWarmupCTA = s:GetChecked() and true or false
    end)
    -- Dev mode toggle
    local cbDev = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    cbDev:SetPoint("TOPLEFT", cbWarm, "BOTTOMLEFT", 0, -12)
    local cbDevLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbDevLabel:SetPoint("LEFT", cbDev, "RIGHT", 4, 0)
    cbDevLabel:SetText("Developer mode (enables test commands)")
    cbDev._label = cbDevLabel
    cbDev:SetChecked(HinterlandAffixHUDDB.devMode or HLBG._devMode)
    cbDev:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.devMode = s:GetChecked() and true or false
        HLBG._devMode = HinterlandAffixHUDDB.devMode
        if HLBG._devMode then
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: devmode enabled. Reloading UI to activate dev commands.")
            -- ReloadUI is safe to call from an options checkbox; this applies new slash registrations immediately
            if type(ReloadUI) == 'function' then pcall(ReloadUI) end
        else
            DEFAULT_CHAT_FRAME:AddMessage("HLBG: devmode disabled.")
        end
    end)
    -- Dev: button to run API probe
    local btnProbe = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    btnProbe:SetSize(180, 22)
    btnProbe:SetPoint("TOPLEFT", cbDev, "BOTTOMLEFT", 0, -16)
    btnProbe:SetText("Run API probe (dev)")
    btnProbe:SetScript("OnClick", function()
        if type(HLBG.RunStartupApiProbe) == 'function' then pcall(HLBG.RunStartupApiProbe) end
    end)
    local scale = CreateFrame("Slider", nil, self, "OptionsSliderTemplate"); scale:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -24)
    scale:SetMinMaxValues(0.8, 1.6); if scale.SetValueStep then scale:SetValueStep(0.05) end
    if scale.SetObeyStepOnDrag then scale:SetObeyStepOnDrag(true) end
    if scale.Low then scale.Low:SetText("0.8") end
    if scale.High then scale.High:SetText("1.6") end
    if scale.Text then scale.Text:SetText("HUD Scale") end
    scale:SetValue(HinterlandAffixHUDDB.scaleHud or 1.0)
    scale:SetScript("OnValueChanged", function(s,val) HinterlandAffixHUDDB.scaleHud = tonumber(string.format("%.2f", val)); HLBG.UI.HUD:SetScale(HinterlandAffixHUDDB.scaleHud) end)
    -- Debug log preview (last 5 lines)
    local dbgTitle = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dbgTitle:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -12)
    dbgTitle:SetText("Recent Debug Log (last 5):")
    local dbgBox = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    dbgBox:SetPoint("TOPLEFT", dbgTitle, "BOTTOMLEFT", 0, -6)
    dbgBox:SetWidth(520)
    dbgBox:SetHeight(100)
    HLBG.safeSetJustify(dbgBox, "LEFT")
    self.debugPreview = dbgBox
    -- Timestamp under preview
    local dbgTs = self:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    dbgTs:SetPoint("TOPLEFT", dbgBox, "BOTTOMLEFT", 0, -2)
    dbgTs:SetText("(last refresh: -)")
    self.debugPreviewTs = dbgTs
    -- Auto-refresh controls
    HinterlandAffixHUDDB = HinterlandAffixHUDDB or {}
    if HinterlandAffixHUDDB.debugAutoRefresh == nil then HinterlandAffixHUDDB.debugAutoRefresh = true end
    if not tonumber(HinterlandAffixHUDDB.debugAutoRefreshInterval) then HinterlandAffixHUDDB.debugAutoRefreshInterval = 0.5 end
    local cbAuto = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    cbAuto:SetPoint("TOPLEFT", dbgBox, "BOTTOMLEFT", 0, -8)
    local cbAutoLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbAutoLabel:SetPoint("LEFT", cbAuto, "RIGHT", 4, 0)
    cbAutoLabel:SetText("Auto refresh debug preview")
    cbAuto._label = cbAutoLabel
    cbAuto:SetChecked(HinterlandAffixHUDDB.debugAutoRefresh)
    cbAuto:SetScript("OnClick", function(s)
        HinterlandAffixHUDDB.debugAutoRefresh = s:GetChecked() and true or false
    end)
    local slAuto = CreateFrame("Slider", nil, self, "OptionsSliderTemplate")
    slAuto:SetPoint("TOPLEFT", cbAuto, "BOTTOMLEFT", 0, -16)
    slAuto:SetMinMaxValues(0.2, 5.0)
    if slAuto.SetValueStep then slAuto:SetValueStep(0.1) end
    if slAuto.SetObeyStepOnDrag then slAuto:SetObeyStepOnDrag(true) end
    if slAuto.Low then slAuto.Low:SetText("0.2s") end
    if slAuto.High then slAuto.High:SetText("5.0s") end
    if slAuto.Text then slAuto.Text:SetText("Refresh interval (seconds)") end
    slAuto:SetValue(HinterlandAffixHUDDB.debugAutoRefreshInterval)
    local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
    slAuto:SetScript("OnValueChanged", function(_, val)
        HinterlandAffixHUDDB.debugAutoRefreshInterval = tonumber(string.format("%.1f", clamp(val or 0.5, 0.2, 5.0)))
    end)
    -- Refresh preview when panel shown
    local function refreshDebugPreview()
        if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
        local lines = {}
        for i=1, math.min(5, #HinterlandAffixHUD_DebugLog) do table.insert(lines, HinterlandAffixHUD_DebugLog[i]) end
        if #lines == 0 then dbgBox:SetText("(no debug entries yet)") else dbgBox:SetText(table.concat(lines, "\n")) end
        if dbgTs and type(date) == 'function' then dbgTs:SetText(string.format("(last refresh: %s)", date("%Y-%m-%d %H:%M:%S"))) end
    end
    self:SetScript("OnShow", function(s) pcall(refreshDebugPreview) end)
    -- Copy-to-chat button: try to insert into chat edit box, otherwise print to chat frame
    local btnCopy = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    btnCopy:SetSize(120, 20)
    btnCopy:SetPoint("TOPLEFT", dbgBox, "BOTTOMLEFT", 0, -8)
    btnCopy:SetText("Copy to chat")
    btnCopy:SetScript("OnClick", function()
        pcall(function()
            if not HinterlandAffixHUD_DebugLog then HinterlandAffixHUD_DebugLog = {} end
            local lines = {}
            for i=1, math.min(5, #HinterlandAffixHUD_DebugLog) do table.insert(lines, HinterlandAffixHUD_DebugLog[i]) end
            local text = (#lines == 0) and "(no debug entries)" or table.concat(lines, " \n ")
            -- Prefer inserting into chat edit when available so user can edit before sending
            if type(ChatEdit_ActivateChat) == 'function' and type(ChatEdit_InsertText) == 'function' then
                pcall(function()
                    ChatEdit_ActivateChat(false)
                    ChatEdit_InsertText(text)
                end)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("HLBG: debug preview inserted into chat edit box") end
                return
            end
            -- Fallback: print to chat frame as separate lines for manual copy
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("HLBG: debug preview:")
                for i=1, math.min(5, #HinterlandAffixHUD_DebugLog) do DEFAULT_CHAT_FRAME:AddMessage(HinterlandAffixHUD_DebugLog[i]) end
            end
        end)
    end)
    -- Refresh now button
    local btnRefreshNow = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    btnRefreshNow:SetSize(100, 20)
    btnRefreshNow:SetPoint("LEFT", btnCopy, "RIGHT", 8, 0)
    btnRefreshNow:SetText("Refresh now")
    -- Runtime status section (AIO + slash registrations)
    local statusTitle = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusTitle:SetPoint("TOPLEFT", btnCopy, "BOTTOMLEFT", 0, -14)
    statusTitle:SetText("Runtime Status:")
    local statusLine = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusLine:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -4)
    statusLine:SetWidth(520)
    HLBG.safeSetJustify(statusLine, "LEFT")
    local slashesLine = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slashesLine:SetPoint("TOPLEFT", statusLine, "BOTTOMLEFT", 0, -2)
    slashesLine:SetWidth(520)
    HLBG.safeSetJustify(slashesLine, "LEFT")
    local function refreshRuntimeStatus()
        local haveAIO = (_G.AIO and _G.AIO.AddHandlers) and true or false
        local handlersBound = (type(HLBG) == 'table' and (type(HLBG.History) == 'function' or type(HLBG.HISTORY) == 'function')) and true or false
        local uiPresent = (type(HLBG) == 'table' and type(HLBG.UI) == 'table') or false
        statusLine:SetText(string.format("AIO: %s   Handlers: %s   UI: %s", tostring(haveAIO), tostring(handlersBound), tostring(uiPresent)))
        local regs, skips = {}, {}
        if HLBG._registered_slashes then for _,s in ipairs(HLBG._registered_slashes) do table.insert(regs, tostring(s.cmd)) end end
        if HLBG._skipped_slashes then for _,s in ipairs(HLBG._skipped_slashes) do table.insert(skips, string.format("%s (%s)", tostring(s.cmd), tostring(s.reason))) end end
        local regTxt = (#regs > 0) and ("Registered: "..table.concat(regs, ", ")) or "Registered: (none)"
        local skipTxt = (#skips > 0) and ("  |  Skipped: "..table.concat(skips, ", ")) or ""
        slashesLine:SetText(regTxt .. skipTxt)
    end
    btnRefreshNow:SetScript("OnClick", function()
        pcall(refreshDebugPreview)
        pcall(refreshRuntimeStatus)
    end)
    -- Initial status
    pcall(refreshRuntimeStatus)
    -- Auto-refresh the debug preview while the panel is visible (every 0.5s)
    local acc = 0
    self:SetScript('OnUpdate', function(_, elapsed)
        if not self:IsShown() then return end
        if not HinterlandAffixHUDDB or not HinterlandAffixHUDDB.debugAutoRefresh then return end
        acc = acc + (elapsed or 0)
        local period = tonumber(HinterlandAffixHUDDB.debugAutoRefreshInterval or 0.5) or 0.5
        if period < 0.2 then period = 0.2 end
        if period > 5.0 then period = 5.0 end
        if acc < period then return end
        acc = 0
        pcall(refreshDebugPreview)
    end)
end)
InterfaceOptions_AddCategory(opt)

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
            _G.AIO.Handle("HLBG", "Request", "HISTORY", 1, HLBG.UI and HLBG.UI.History and HLBG.UI.History.per or 5, "id", "DESC")
            _G.AIO.Handle("HLBG", "Request", "STATS")
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

