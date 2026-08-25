dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c,m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- extra API the protocol core touches at load
_G.UIParent = CreateFrame("Frame")
_G.SlashCmdList = {}
_G.time = os.time
_G.date = os.date
_G.GetLocale = function() return "enUS" end
_G.UnitName = function() return "Tester" end
_G.UnitGUID = function() return "0x123" end
_G.GetRealmName = function() return "DC" end
_G.GetBuildInfo = function() return "3.3.5", "12340", "date", 30300 end
_G.GetAddOnMetadata = function() return "2.0.0" end
_G.IsAddOnLoaded = function(n) return _G._loaded and _G._loaded[n] end
_G.RegisterAddonMessagePrefix = function() end
_G.SendAddonMessage = function() end
_G.InterfaceOptions_AddCategory = function() end
_G.InterfaceOptionsFrame_OpenToCategory = function(p) _G._opened = p end
_G.InterfaceOptionsFrame = CreateFrame("Frame")
_G.GameTooltip = CreateFrame("Frame")
_G.NORMAL_FONT_COLOR = {r=1,g=1,b=1}
_G.tinsert, _G.tremove = table.insert, table.remove
_G.strsplit = function(sep, s) local t={} for w in string.gmatch(s,"([^"..sep.."]+)") do t[#t+1]=w end return unpack(t) end
_G.strjoin = function(sep, ...) return table.concat({...}, sep) end
_G.strtrim = function(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end
_G.hooksecurefunc = function() end
_G.securecall = function(f, ...) return f(...) end

local loadedFiles = {}
_G._loaded = {}
_G.LoadAddOn = function(name)
    if name == "DC-AddonProtocolUI" then
        dofile(ROOT..[[DC-AddonProtocolUI\Panels.lua]])
        dofile(ROOT..[[DC-AddonProtocolUI\LogPanel.lua]])
        _G._loaded[name] = true
        loadedFiles[#loadedFiles+1] = name
        return true
    end
    return false, 2
end

print("== load DC-AddonProtocol in TOC order ==")
dofile(ROOT..[[DC-AddonProtocol\DCCompat.lua]])
dofile(ROOT..[[DC-AddonProtocol\DCAddonProtocol.lua]])
dofile(ROOT..[[DC-AddonProtocol\DCOpcodes.lua]])
local DC = _G.DCAddonProtocol
ok(DC ~= nil, "DCAddonProtocol global exists")

print("== the wire contract survived the split ==")
ok(type(DC.Module) == "table" and DC.Module.CORE == "CORE", "DC.Module intact")
local nmod = 0; for _ in pairs(DC.Module) do nmod = nmod + 1 end
ok(nmod == 24, "all 24 module ids present (got "..nmod..")")
ok(type(DC.Opcode) == "table" and type(DC.Opcode.Core) == "table", "DC.Opcode.Core intact")
for _, ns in ipairs({"AOE","Hotspot","Upgrade","Spectator","MythicPlus","Season",
                     "Hinterland","Duel","Prestige","Leaderboard","Welcome","GroupFinder"}) do
    if type(DC[ns]) ~= "table" then ok(false, "DC."..ns.." helper table present") end
end
ok(type(DC.AOE.Toggle) == "function" and type(DC.Hotspot.Teleport) == "function"
   and type(DC.GroupFinder) == "table", "all 12 per-module helper tables present")

print("== core transport untouched ==")
for _, fn in ipairs({"Send","SendJSON","Request","RegisterHandler","EncodeJSON",
                     "DecodeJSON","UpdateStats","CountTable","IsConnected"}) do
    if type(DC[fn]) ~= "function" then ok(false, "DC:"..fn.." still in core") end
end
ok(true, "transport, JSON, dispatch, UpdateStats and CountTable all still in core")

print("== UI is NOT loaded at login ==")
ok(DC.SettingsPanel == nil, "SettingsPanel absent")
ok(DC.DiagnosticsPanel == nil, "DiagnosticsPanel absent")
ok(type(DC.ShowLogPanel) ~= "function", "log panel renderer absent")
ok(#loadedFiles == 0, "no LoadAddOn during login")
ok(type(DC.EnsureUIAddon) == "function", "loader shim present in core")
ok(type(SlashCmdList["DCPANEL"]) == "function", "/dcpanel registered without the UI addon")

print("== opening a panel pulls the UI in ==")
SlashCmdList["DCPANEL"]()
ok(#loadedFiles == 1, "slash command triggered LoadAddOn")
ok(DC.SettingsPanel ~= nil, "SettingsPanel now built")
ok(DC.DiagnosticsPanel ~= nil, "DiagnosticsPanel now built")
ok(type(DC.ShowLogPanel) == "function", "log panel renderer now available")
ok(_G._opened == DC.SettingsPanel, "options frame opened to the right category")

SlashCmdList["DCDIAG"]()
ok(_G._opened == DC.DiagnosticsPanel, "/dcdiag opens diagnostics")
ok(#loadedFiles == 1, "UI addon not re-loaded")

print("== stats collection works even if the viewer is never opened ==")
-- UpdateStats runs on the logging path for every request; it deliberately
-- stayed in core when the renderer moved out.
DC._stats.totalRequests = 0
DC:UpdateStats("request", {module = "COLL", opcode = 1})
DC:UpdateStats("request", {module = "COLL", opcode = 2})
ok(DC._stats.totalRequests == 2, "UpdateStats still counts (got "..DC._stats.totalRequests..")")
ok(DC._stats.moduleStats.COLL ~= nil, "per-module stats still collected")

print("")
print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
