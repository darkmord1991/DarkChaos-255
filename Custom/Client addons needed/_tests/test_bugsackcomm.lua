-- BugSack peer bug reports (security audit 2026-11-10).
--
-- BugSack registered the AceComm prefix "BugSack" and stored whatever any player sent, on any
-- channel, as persistent error entries (no opt-in, no size limit); AceComm also spooled the
-- multipart chunks of that prefix without a cap. The prefix is no longer registered and the
-- "Send bugs" button (whose reports nobody can receive any more) is gone.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

local registered, stored, namedFrames = {}, {}, {}
local aceComm = {
    Embed = function(_, target)
        target.RegisterComm = function(_, prefix, handler) registered[#registered + 1] = prefix end
        target.SendCommMessage = function() end
    end,
}
local aceSerializer = {
    Embed = function(_, target)
        target.Serialize = function(_, t) return t end
        target.Deserialize = function(_, s) return true, s end
    end,
}
local locale = setmetatable({}, { __index = function(_, k) return k end })
local aceLocale = { GetLocale = function() return locale end }
local libs = { ["AceComm-3.0"] = aceComm, ["AceSerializer-3.0"] = aceSerializer, ["AceLocale-3.0"] = aceLocale }
_G.LibStub = setmetatable({ GetLibrary = function(_, name) return libs[name] end },
    { __call = function(_, name) return libs[name] end })

_G.BugGrabber = {
    GetSessionId = function() return 7 end,
    StoreError = function(_, err) stored[#stored + 1] = err end,
    GetDB = function() return {} end,
    RegisterCallback = function() end,
    RegisterAddonActionEvents = function() end,
    UnregisterAddonActionEvents = function() end,
}
_G.StaticPopupDialogs = {}
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.SlashCmdList = {}
_G.CLOSE = "Close"
_G.UIParent = CreateFrame("Frame")
_G.InterfaceOptionsFrame_OpenToCategory = function() end
_G.ShowUIPanel = function(f) if f and f.Show then f:Show() end end
_G.HideUIPanel = function(f) if f and f.Hide then f:Hide() end end
_G.UISpecialFrames = {}
_G.UIPanelWindows = {}
_G.PanelTemplates_TabResize = function() end
_G.PanelTemplates_DeselectTab = function() end
_G.PlaySound = function() end
_G.IsShiftKeyDown = function() return false end
_G.GameFontHighlight, _G.GameFontNormal, _G.ChatFontNormal = {}, {}, {}
local Methods = getmetatable(CreateFrame("Frame")).__index
function Methods:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
local simCreateFrame = CreateFrame
_G.CreateFrame = function(ftype, name, ...)
    local f = simCreateFrame(ftype, name, ...)
    if name then
        namedFrames[name] = f
        _G[name] = f
    end
    return f
end

local okLoad, err = pcall(dofile, ROOT .. [[BugSack\BugSack.lua]])
ok(okLoad, "BugSack.lua loads" .. (okLoad and "" or (": " .. tostring(err))))
local BugSack = _G.BugSack
local onEvent = BugSack and BugSack._scripts.OnEvent
ok(type(onEvent) == "function", "BugSack has its event handler")

if onEvent then
    onEvent(BugSack, "ADDON_LOADED", "BugSack")
    onEvent(BugSack, "PLAYER_LOGIN")
end
ok(BugSack.Deserialize ~= nil, "the serializer is still embedded (load path ran)")
local hasPrefix = false
for _, p in ipairs(registered) do if p == "BugSack" then hasPrefix = true end end
ok(not hasPrefix, "the BugSack comm prefix is not registered")

-- Build the sack window with one local error and look for the send button.
BugSack.GetErrors = function() return { { message = "x", type = "error", session = 7, counter = 1, time = "now" } } end
BugGrabber.GetDB = BugSack.GetErrors
local okOpen, openErr = pcall(BugSack.OpenSack, BugSack)
ok(okOpen, "the sack window opens" .. (okOpen and "" or (": " .. tostring(openErr))))
ok(namedFrames.BugSackFrame ~= nil, "the sack window was built")
ok(namedFrames.BugSackSendButton == nil, "there is no Send bugs button")

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
