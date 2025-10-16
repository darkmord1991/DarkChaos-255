-- Standalone harness for testing HLBG.HistoryStr and HLBG._parseHistLineFlexible
-- This file runs outside WoW using standard Lua (luac/lua).

-- Minimal stubs for WoW API used by the module
DEFAULT_CHAT_FRAME = { AddMessage = function(...) print(... ) end }
C_Timer = { After = function(sec, fn) fn() end }
function CreateFrame() return { SetHeight=function() end, CreateFontString=function() return { SetPoint=function() end, SetWidth=function() end, SetTextColor=function() end, SetFont=function() end } end } end
function SecondsToTime(s) return tostring(s) end

-- Load the History file from the addon
local path = [[Custom\Client addons needed\HinterlandAffixHUD\HLBG_History.lua]]
local f,err = loadfile(path)
if not f then
    print('Failed to load HLBG_History.lua:', err)
    os.exit(1)
end
f()

local tests = {
    {name = 'TSV basic', input = '1\t1697470000\tAlliance\t0\tmanual'},
    {name = 'Pipe payload', input = '1|1697470000|Alliance|0|manual'},
    {name = 'Escaped sequences', input = '1\\t1697470000\\tAlliance\\t0\\tmanual'},
    {name = 'TOTAL header', input = 'TOTAL=3 || 1\t1697470000\tAlliance\t0\tmanual\n2\t1697471000\tHorde\t0\tmanual\n3\t1697472000\tDraw\t0\tmanual'},
    {name = 'Flexible date parse', input = '4 2025-10-07 20:05:44 Alliance 0 manual'},
    {name = 'Incomplete tokens', input = '5 1697473000 Alliance'},
}

-- Additional edge cases and expected outcomes
local extra = {
    -- pipe-only payload with no newline should still parse a single line
    {name = 'Pipe single no newline', input = '6|1697474000|Horde|1|objective', expectCount = 1, sample = {id='6', winner='Horde'}},
    -- TSV with escaped \n sequences should unescape into two lines
    {name = 'Escaped newline payload', input = '7\\n8\\t1697475000\\tAlliance\\t0\\tmanual', expectCount = 1},
    -- Empty input should produce zero rows
    {name = 'Empty input', input = '', expectCount = 0},
    -- Malformed header only
    {name = 'Header only TOTAL', input = 'TOTAL=0 ||', expectCount = 0},
}

for _,tc in ipairs(extra) do table.insert(tests, tc) end

for _,tc in ipairs(tests) do
    print('\n--- Test:', tc.name)
    local rows_before = HLBG._lastSanitizedTSV
    local res = HLBG.HistoryStr(tc.input)
    print('Returned:', type(res))
    -- Since HLBG.History will attempt to render UI, it returns nil; instead we inspect HLBG.UI.History.lastRows
    local last = HLBG.UI and HLBG.UI.History and HLBG.UI.History.lastRows
    local got = (last and #last) or 0
    if tc.expectCount ~= nil then
        local pass = (got == tc.expectCount)
        print(string.format('Expected rows=%d, got=%d => %s', tc.expectCount, got, pass and 'PASS' or 'FAIL'))
        if not pass then
            print('Full lastRows dump:')
            if last then for i,r in ipairs(last) do print(require('inspect') and inspect(r) or (string.format('Row %d: id=%s ts=%s winner=%s', i, tostring(r.id), tostring(r.ts), tostring(r.winner)))) end end
            os.exit(2)
        end
        if tc.sample and got>0 then
            local ok = true
            for k,v in pairs(tc.sample) do if tostring(last[1][k]) ~= tostring(v) then ok = false end end
            print('Sample field check =>', ok and 'PASS' or 'FAIL')
            if not ok then os.exit(3) end
        end
    else
        if last then
            for i,r in ipairs(last) do
                print(string.format('Row %d: id=%s ts=%s winner=%s affix=%s reason=%s', i, tostring(r.id), tostring(r.ts), tostring(r.winner), tostring(r.affix), tostring(r.reason)))
            end
        else
            print('No parsed rows stored in HLBG.UI.History.lastRows')
        end
    end
end

print('\nHarness finished')
