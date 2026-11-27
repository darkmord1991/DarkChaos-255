-- DC-GM Core/AzerothAdmin.lua SYSTEM-line parser (security audit 2026-11-10).
--
-- ".ticket viewid" echoes a player's ticket text as a SYSTEM line, and the chat hook matched every
-- SYSTEM line against unanchored patterns with several greedy captures. A long crafted ticket made
-- them backtrack for minutes and froze the GM's client. Now lines over 512 bytes skip the pattern
-- parsers (only a linear-time ticket capture runs), and the account-info / ticket-list patterns run
-- only while the GM asked for that output. Legitimate ticket views must keep working.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local LIBROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

-- ------------------------------------------------------------------ load stubs
local function lenient()
    return setmetatable({}, { __index = function() return function() return lenient() end end })
end
local addon = setmetatable({}, { __index = function() return function() end end })
local strings
_G.getfenv = _G.getfenv or function() return _G end
_G.time = os.time
_G.GetAddOnMetadata = function() return "3.0" end
_G.LibStub = function(name)
    if name == "AceAddon-3.0" then
        return { NewAddon = function() return addon end }
    elseif name == "AceLocale-3.0" then
        return {
            NewLocale = function(_, appName)
                if appName == "AzerothAdmin-Strings" then
                    strings = strings or {}
                    return strings
                end
                return {}
            end,
            GetLocale = function(_, appName)
                if appName == "AzerothAdmin-Strings" then
                    strings = strings or {}
                    return strings
                end
                return setmetatable({}, { __index = function(_, k) return k end })
            end,
        }
    end
    return lenient()
end

dofile(LIBROOT .. [[DC-GM\Locales\enUS\strings_enUS.lua]])
local okLoad, err = pcall(dofile, ROOT .. [[DC-GM\Core\AzerothAdmin.lua]])
ok(okLoad, "AzerothAdmin.lua loads" .. (okLoad and "" or (": " .. tostring(err))))
ok(type(strings) == "table" and strings.ma_GmatchTickets ~= nil, "enUS patterns are loaded")
if type(rawget(addon, "AddMessage")) ~= "function" then
    print("RESULT: " .. pass .. " passed, " .. (fail + 1) .. " failed (AddMessage not defined)")
    os.exit(1)
end

-- ------------------------------------------------------------- runtime stubs
local function textWidget()
    local w = { _text = "" }
    function w:SetText(t) self._text = t or "" end
    function w:GetText() return self._text end
    function w:SetCursorPosition() end
    function w:ClearFocus() end
    function w:SetVerticalScroll() end
    function w:IsVisible() return false end
    return w
end
_G.ma_popupframe = textWidget()
_G.ma_ticketdetail = textWidget()
_G.ma_ticketdetailscrollframe = textWidget()
_G.ma_ticketid = textWidget()
_G.ma_tpinfo_text = textWidget()
_G.PlaySoundFile = function() end

local linkified = 0
_G.MangLinkifier_ProcessServerLine = function(t) linkified = linkified + 1; return t end

local shown = {}
local frame = {}
addon.hooks = { [frame] = { AddMessage = function(_, text) shown[#shown + 1] = text end } }
addon.db = {
    profile = { style = { showchat = false }, buffer = { tickets = {} } },
    char = { requests = { ticket = false, tpinfo = false, toggle = false, ticketbody = 0 }, functionQueue = {} },
}
local requests = addon.db.char.requests
local buffer = addon.db.profile.buffer

local realPrint = print
local function feed(text)
    shown, linkified = {}, 0
    _G.print = function() end
    local t0 = os.clock()
    local okCall, callErr = pcall(addon.AddMessage, addon, frame, text, 1, 1, 1, 1)
    local dt = os.clock() - t0
    _G.print = realPrint
    if not okCall then realPrint("    error: " .. tostring(callErr)) end
    return dt, okCall
end

local function rep(unit, len)
    return string.rep(unit, math.ceil(len / #unit)):sub(1, len)
end

-- ------------------------------------------------------------- crafted lines
print("== crafted ticket text cannot freeze the hook ==")
requests.ticket = true
local crafted = rep("Ticket:Created by:", 3000)
local dt, called = feed(crafted)
ok(called and dt < 0.25, string.format("3000-byte crafted line with the ticket list open: %.3fs", dt))
ok(shown[1] == crafted, "an over-long line is still shown, unchanged")
ok(linkified == 0, "an over-long line is not linkified")

dt, called = feed(rep("Ticket:Created by:", 600))
ok(called and dt < 0.25, string.format("600-byte crafted line (just over the cap): %.3fs", dt))

requests.ticket = false
dt, called = feed(rep("Ticket:Created by:", 500))
ok(called and dt < 0.25, string.format("500-byte crafted line, ticket list not requested: %.3fs", dt))
ok(#buffer.tickets == 0, "crafted text adds no ticket rows")

requests.tpinfo = false
local before = ma_tpinfo_text:GetText()
feed("Player Bob (guid: 1) Account: x (id: 1) Email: x GMLevel: 3 Last IP: 1.2.3.4 Last login: now Latency: 5ms")
ok(ma_tpinfo_text:GetText() == before, "account-info lines are not parsed unless player info was requested")

-- ------------------------------------------------------------- legitimate use
print("== legitimate ticket output still parses ==")
requests.ticket = true
local listLine = "|cffaaffaaTicket|r:|cffaaccff 5.|r |cff00ff00Created by|r:|cff00ccff Bob|r "
    .. "|cff00ff00Created|r:|cff00ccff 1h ago|r |cff00ff00Last change|r:|cff00ccff 1h ago|r "
feed(listLine)
ok(#buffer.tickets == 1 and buffer.tickets[1].tNumber == "5", "ticket list row is parsed while requested")
ok(#shown == 0, "the parsed ticket row is hidden (showchat off)")

requests.ticket = false
local message = rep("please help me with my quest ", 480)
local viewLine = listLine .. "|cff00ff00Ticket Message|r: [" .. message .. "]|r"
ok(#viewLine > 512, "a 480-character ticket view line is over the cap (" .. #viewLine .. " bytes)")
ma_ticketdetail:SetText("")
feed(viewLine)
ok(ma_ticketdetail:GetText() == "|cffffff00" .. message, "long single-line ticket still fills the ticket panel")
ok(#shown == 0, "captured ticket line is hidden like before (showchat off)")

ma_ticketdetail:SetText("")
local shortView = listLine .. "|cff00ff00Ticket Message|r: [short one]|r"
feed(shortView)
ok(ma_ticketdetail:GetText() == "|cffffff00short one", "short ticket fills the ticket panel")

ma_ticketdetail:SetText("")
ma_ticketid:SetText("5")
feed(listLine .. "|cff00ff00Ticket Message|r: [line one")
ok(buffer.ticketMessageBuffer == "line one", "multi-line ticket: first line is buffered")
feed("line two")
feed("line three]|r")
ok(ma_ticketdetail:GetText() == "|cffffff00line one\nline two\nline three", "multi-line ticket is joined")
ok(buffer.ticketMessageBuffer == nil, "buffer is cleared after the closing bracket")

print("== other lines are untouched ==")
feed("Hello from the server")
ok(shown[1] == "Hello from the server" and linkified == 1, "ordinary SYSTEM lines are linkified and shown")
shown = {}
pcall(addon.AddMessage, addon, frame, rep("x", 2000), 1, 1, 1, nil)
ok(shown[1] ~= nil, "non-SYSTEM lines pass through")

print("== world chat lines are player text ==")
-- mod-world-chat sends player text as SYSTEM lines behind "[World][...]" (security audit 2026-11-18)
local worldLine = "[World][][|cffC79C6E|Hplayer:Bob|hBob|h|r]: |cffFFFFFFGUID: 4567 ID: 180000|r"
feed(worldLine)
ok(linkified == 0, "a world-chat SYSTEM line is not linkified")
ok(shown[1] == worldLine, "a world-chat line is shown unchanged")
requests.ticket = false
ma_ticketdetail:SetText("")
feed("[World][][|Hplayer:Bob|hBob|h|r]: |cffFFFFFFTicket Message: [fake ticket|r")
ok(ma_ticketdetail:GetText() == "", "a world-chat line cannot fill the ticket panel")
ok(buffer.ticketMessageBuffer == nil, "a world-chat line does not start a ticket buffer")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
