dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c,m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- Support the addon's custom `enum:NAME {...}` construct and mixin helper.
_G.enum = setmetatable({}, {__index = function(_, name)
    return function(_, list)
        local t = {}
        for i, k in ipairs(list) do t[k] = i end
        _G[name] = t
        return t
    end
end})
_G.CreateFromMixins = function(m)
    local o = {}
    for k, v in pairs(m) do o[k] = v end
    return o
end
_G.GetLocale = function() return "enUS" end
_G.GetItemInfo = function() return nil end        -- client knows nothing: force the fallback
_G.GetItemQualityColor = function() return 1, 1, 1 end
_G.SHARED_INVTYPE_BY_ID = {}
_G.ITEM_CLASS_2 = "Weapon"

-- Track LoadAddOn calls the way the client would.
local loadCalls = {}
_G.LoadAddOn = function(name)
    loadCalls[#loadCalls+1] = name
    if name == "DC-JournalData" then
        dofile(ROOT..[[DC-JournalData\ItemsCache.lua]])
        return true
    end
    return false, 2
end

print("== login: cache must NOT be resident ==")
dofile(ROOT..[[DC-Journal\Interface\FrameXML\Utils\C_Item.lua]])
ok(_G.ItemsCache == nil, "ItemsCache absent after addon load (28 MB not paid at login)")
ok(#loadCalls == 0, "no LoadAddOn call during load")

print("== first lookup pulls it in ==")
local info = C_Item:GetItemInfoFromCache(25)
ok(#loadCalls == 1 and loadCalls[1] == "DC-JournalData", "first lookup triggers LoadAddOn once")
ok(_G.ItemsCache ~= nil, "cache now resident")
ok(info and info.name == "Worn Shortsword", "returned correct data (got "..tostring(info and info.name)..")")

print("== subsequent lookups do not re-load ==")
C_Item:GetItemInfoFromCache(26)
C_Item:GetItemInfoFromCache(27)
ok(#loadCalls == 1, "still exactly one LoadAddOn call")

print("== addon missing: degrade, do not error ==")
_G.ItemsCache = nil
package.loaded = {}
local calls2 = {}
_G.LoadAddOn = function(n) calls2[#calls2+1]=n; return false, 2 end
dofile(ROOT..[[DC-Journal\Interface\FrameXML\Utils\C_Item.lua]])
local okCall, res = pcall(function() return C_Item:GetItemInfoFromCache(25) end)
ok(okCall, "missing data addon does not raise")
ok(res == nil, "returns nil, exactly as a cache miss always did")
local okCall2 = pcall(function() return C_Item:GetItemInfoFromCache(26) end)
ok(okCall2 and #calls2 == 1, "failed load is not retried on every lookup (attempts: "..#calls2..")")

print("== EJ_GetItemInfo still works end to end ==")
local n = EJ_GetItemInfo(25)
ok(n == nil, "no client data + no addon -> nil, no crash")

print(string.format("\nRESULT: %d passed, %d failed", pass, fail))
os.exit(fail==0 and 0 or 1)
