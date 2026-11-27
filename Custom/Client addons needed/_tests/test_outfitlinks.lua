-- DC-Collection outfit sharing from other players (security audit 2026-11-10).
--
-- 1. A dc:outfit chat link can be posted by anyone with any label. Shift-click used to APPLY it
--    (wiping the victim's transmog on every slot) and right-click too, with no question asked.
--    Now shift-click quotes it into chat like the mount/pet links, a plain click previews, and
--    right-click only opens a confirmation popup that names the outfit.
-- 2. DCOUTFIT addon-message shares are sent as whispers; a GUILD/RAID/BATTLEGROUND copy used to
--    pop the share dialog for every member at once.
-- Setup follows test_loginoutfit.lua.
dofile("wowsim.lua")
local ROOT = os.getenv("DC_ADDON_ROOT") or [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local LIBROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m)
    if c then pass = pass + 1; print("  PASS " .. m) else fail = fail + 1; print("  FAIL " .. m) end
end

_G.unpack = _G.unpack or table.unpack
math.pow = math.pow or function(a, b) return a ^ b end
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
_G.IsAddOnLoaded = function() return false end
_G.LoadAddOn = function() return false, 2 end
_G.RegisterAddonMessagePrefix = function() end
_G.InterfaceOptions_AddCategory = function() end
_G.GameTooltip = CreateFrame("Frame")
_G.tinsert, _G.tremove = table.insert, table.remove
_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
_G.strlower = string.lower
_G.hooksecurefunc = function() end
_G.SendAddonMessage = function() end
_G.GetItemInfo = function() return nil end
_G.InCombatLockdown = function() return false end
_G.UnitAffectingCombat = function() return false end
_G.UnitClass = function() return "Mage", "MAGE" end
_G.UnitRace = function() return "Human", "Human" end
_G.UnitLevel = function() return 80 end
_G.UnitFactionGroup = function() return "Alliance" end
_G.GetNumCompanions = function() return 0 end
_G.GetDCClientCapabilities = function() return 0 end
_G.ACCEPT, _G.CANCEL = "Accept", "Cancel"
_G.strsplit = function(sep, str)
    local out, pos = {}, 1
    while true do
        local s, e = string.find(str, sep, pos, true)
        if not s then out[#out + 1] = string.sub(str, pos); break end
        out[#out + 1] = string.sub(str, pos, s - 1)
        pos = e + 1
    end
    return (unpack or table.unpack)(out)
end

local FrameMethods = getmetatable(CreateFrame("Frame")).__index
function FrameMethods:RegisterEvent(e) self._events = self._events or {}; self._events[e] = true end
local created = {}
local simCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local f = simCreateFrame(...)
    created[#created + 1] = f
    return f
end

-- Chat edit box and popups.
local inserted, popups = {}, {}
_G.ChatEdit_GetActiveWindow = function() return true end
_G.ChatEdit_InsertLink = function(link) inserted[#inserted + 1] = link; return true end
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(which, a1, a2, data)
    local d = { which = which, a1 = a1, a2 = a2, data = data }
    popups[#popups + 1] = d
    return d
end
local modifier
_G.IsModifiedClick = function(action) return modifier == action end
_G.IsShiftKeyDown = function() return modifier == "CHATLINK" end
local stockCalls = {}
_G.SetItemRef = function(link) stockCalls[#stockCalls + 1] = link end

dofile(LIBROOT .. [[DC-AddonProtocol\DCCompat.lua]])
dofile(LIBROOT .. [[DC-AddonProtocol\DCAddonProtocol.lua]])
dofile(LIBROOT .. [[DC-AddonProtocol\DCOpcodes.lua]])
for _, file in ipairs({ "Localization.lua", "Core.lua", "Modules\\CollectionLinks.lua",
        "Modules\\TransmogModule.lua", "UI\\Wardrobe\\WardrobeShare.lua" }) do
    local okLoad, err = pcall(dofile, ROOT .. [[DC-Collection\]] .. file)
    ok(okLoad, file .. " loads" .. (okLoad and "" or (": " .. tostring(err))))
end
local DC = _G.DCCollection

local printed, applied, previewed = {}, {}, {}
DC.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
DC.ApplyTransmogBatchByEquipmentSlot = function(_, entries) applied[#applied + 1] = entries end
local realPreview = DC.PreviewOutfitFromLink
DC.PreviewOutfitFromLink = function(self, link) previewed[#previewed + 1] = link end

local function reset() inserted, popups, printed, applied, previewed, stockCalls = {}, {}, {}, {}, {}, {} end

-- An outfit link as a player would post it: the label claims to be Thunderfury.
local DATA = "dc:outfit:1:0:Raid Look:1f-0-2a"
local FAKE = "|cffff8000|H" .. DATA .. "|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"

print("== shift-click quotes, never applies ==")
reset()
modifier = "CHATLINK"
SetItemRef(DATA, FAKE, "LeftButton", nil)
ok(#applied == 0 and #popups == 0, "shift-click does not apply or prompt")
ok(#inserted == 1, "shift-click inserts the link into chat")
ok(inserted[1] and inserted[1]:find("|H" .. DATA .. "|h", 1, true) ~= nil, "quoted link keeps the link data")
ok(inserted[1] and inserted[1]:find("[Outfit: Raid Look]", 1, true) ~= nil,
    "quoted link uses our own label, not the poster's")
ok(inserted[1] and not inserted[1]:find("Thunderfury", 1, true), "the fake item label is dropped")

reset()
SetItemRef(DATA, FAKE, "RightButton", nil)
ok(#applied == 0 and #popups == 0 and #inserted == 1, "shift+right-click also only quotes")

print("== plain click previews ==")
reset()
modifier = nil
SetItemRef(DATA, FAKE, "LeftButton", nil)
ok(#previewed == 1 and #applied == 0 and #popups == 0, "left click previews only")

print("== right-click asks first ==")
reset()
SetItemRef(DATA, FAKE, "RightButton", nil)
ok(#applied == 0, "right-click does not apply by itself")
ok(#popups == 1 and popups[1].which == "DC_COLLECTION_APPLY_OUTFIT_LINK", "right-click opens the confirmation")
ok(popups[1] and popups[1].a1 == "Raid Look", "the popup names the outfit")
ok(popups[1] and popups[1].data == DATA, "the popup carries the link data")
local dialog = StaticPopupDialogs.DC_COLLECTION_APPLY_OUTFIT_LINK
ok(dialog and dialog.text:find("%s", 1, true) ~= nil, "popup text formats the outfit name")
ok(dialog and dialog.hideOnEscape and dialog.timeout == 0, "popup closes on Escape and does not time out")
if dialog and popups[1] then dialog.OnAccept(nil, popups[1].data) end
ok(#applied == 1, "Accept applies the outfit")
local cleared, set = 0, {}
for _, e in ipairs(applied[1] or {}) do
    if e.clear then cleared = cleared + 1 else set[#set + 1] = e.appearanceId end
end
ok(cleared > 0 and #set == 2, "Accept sends the parsed outfit (clears + 2 appearances)")

print("== hostile names are neutralised ==")
reset()
local EVIL = "dc:outfit:1:0:|TInterface\\Buttons\\WHITE8X8:900:1600|t[GM]:1f"
SetItemRef(EVIL, "[x]", "RightButton", nil)
ok(popups[1] and not popups[1].a1:find("|", 1, true), "popup name has no escape codes")
modifier = "CHATLINK"
SetItemRef(EVIL, "[x]", "LeftButton", nil)
ok(#inserted == 0, "a link whose data holds escape codes is not quoted")
modifier = nil
DC.PreviewOutfitFromLink = realPreview
_G.DressUpFrame, _G.DressUpModel = nil, nil
DC.PreviewOutfitFromLink(DC, "dc:outfit:1:0:|cffff0000Fake|r:1f")
local last = printed[#printed] or ""
ok(not last:find("|c", 1, true), "preview message strips colour codes from the name")

print("== other link types are untouched ==")
reset()
SetItemRef("item:19019:0:0:0", "[Thunderfury]", "LeftButton", nil)
ok(#stockCalls == 1, "item links still reach the stock handler")

print("== dc:wishlist links only ask ==")
-- Any player can post a dc:wishlist link; a click must not send anything by itself (audit 2026-11-18)
reset()
local wished = {}
DC.RequestAddWishlist = function(_, kind, id) wished[#wished + 1] = { kind = kind, id = id } end
SetItemRef("dc:wishlist:12345", "[Some Epic]", "LeftButton", nil)
ok(#wished == 0, "a left click sends no wishlist request")
ok(#popups == 1 and popups[1].which == "DC_COLLECTION_ADD_WISHLIST_LINK", "a left click opens the confirmation")
ok(popups[1] and popups[1].data == 12345, "the popup carries the item id")
modifier = "CHATLINK"
SetItemRef("dc:wishlist:12345", "[Some Epic]", "LeftButton", nil)
modifier = nil
ok(#wished == 0, "a shift-click sends no wishlist request either")
local wishDialog = _G.StaticPopupDialogs and _G.StaticPopupDialogs.DC_COLLECTION_ADD_WISHLIST_LINK
if wishDialog and popups[1] then wishDialog.OnAccept(nil, popups[1].data) end
ok(#wished == 1 and wished[1].kind == 6 and wished[1].id == 12345, "accepting adds the item (transmog)")
reset()
SetItemRef("dc:wishlist:abc", "[x]", "LeftButton", nil)
ok(#popups == 0 and #wished == 1, "a malformed wishlist link is ignored")

print("== DCOUTFIT shares: WHISPER only ==")
local listener
for _, f in ipairs(created) do
    if f._events and f._events.CHAT_MSG_ADDON and f._scripts.OnEvent and DC.Wardrobe
        and DC.Wardrobe._shareListener == f then
        listener = f
    end
end
ok(listener ~= nil, "WardrobeShare registers its CHAT_MSG_ADDON listener")
local received = {}
DC.Wardrobe.OnOutfitReceived = function(_, msg, sender) received[#received + 1] = sender end
local clock = 1000
_G.GetTime = function() return clock end
local function share(dist, sender)
    clock = clock + 100
    listener._scripts.OnEvent(listener, "CHAT_MSG_ADDON", "DCOUTFIT", "1|0.1f|Look", dist, sender)
end
if listener then
    share("GUILD", "Spammer")
    share("RAID", "Spammer2")
    share("BATTLEGROUND", "Spammer3")
    share("PARTY", "Spammer4")
    ok(#received == 0, "GUILD/RAID/BATTLEGROUND/PARTY shares are ignored")
    share("WHISPER", "Friend")
    ok(#received == 1 and received[1] == "Friend", "a whispered share still opens the dialog")
end

print(string.format("RESULT: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
