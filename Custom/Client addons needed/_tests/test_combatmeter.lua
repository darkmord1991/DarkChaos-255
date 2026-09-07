dofile("wowsim.lua")
local ROOT = [[K:\Dark-Chaos\DarkChaos-255-Master\Custom\Client addons needed\]]
local pass, fail = 0, 0
local function ok(c, m) if c then pass=pass+1; print("  PASS "..m) else fail=fail+1; print("  FAIL "..m) end end

-- ------------------------------------------------------------------
-- Environment: every global CombatLog.lua reaches for that wowsim does not
-- already provide. Unknown globals are logged, not silently stubbed, so a
-- misspelled API in the module shows up in the output.
-- ------------------------------------------------------------------
local missing = {}
setmetatable(_G, {__index = function(_, k)
    if type(k) == "string" and k:match("^[%u_][%w_]*$") then
        missing[k] = (missing[k] or 0) + 1
        return function() return nil end
    end
    return nil
end})

_G.unpack = _G.unpack or table.unpack
_G.bit = _G.bit or {
    band = function(a, b) return a & b end,
    bor = function(a, b) return a | b end,
    bxor = function(a, b) return a ~ b end,
    lshift = function(a, n) return a << n end,
    rshift = function(a, n) return a >> n end,
}
_G.strsplit = function(sep, s)
    local out = {}
    for piece in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = piece end
    return unpack(out)
end
_G.strfind, _G.strsub, _G.strlower, _G.strupper, _G.format = string.find, string.sub, string.lower, string.upper, string.format
_G.tinsert, _G.tremove, _G.wipe = table.insert, table.remove, function(t) for k in pairs(t) do t[k] = nil end return t end
_G.UIParent = CreateFrame("Frame")
_G.UIParent.GetScale = function() return 1 end
_G.UIParent.GetEffectiveScale = function() return 1 end
_G.UIParent.GetWidth = function() return 1024 end
_G.UIParent.GetHeight = function() return 768 end
_G.GameTooltip = CreateFrame("GameTooltip")
_G.GameTooltip_Hide = function() end
_G.GetScreenWidth = function() return 1024 end
_G.GetScreenHeight = function() return 768 end
_G.UnitGUID = function(u) return u == "player" and "0x0000000000000001" or nil end
_G.UnitName = function(u) return u == "player" and "Tester" or nil end
_G.UnitClass = function(u) return u == "player" and "Warrior" or nil, u == "player" and "WARRIOR" or nil end
_G.RAID_CLASS_COLORS = { WARRIOR = {r = 0.78, g = 0.61, b = 0.43}, MAGE = {r = 0.41, g = 0.8, b = 0.94} }
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.SlashCmdList = {}
_G.EasyMenu = function() end
_G.COMBATLOG_OBJECT_AFFILIATION_MINE = 0x1
_G.COMBATLOG_OBJECT_AFFILIATION_PARTY = 0x2
_G.COMBATLOG_OBJECT_AFFILIATION_RAID = 0x4
_G.COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10
_G.COMBATLOG_OBJECT_CONTROL_PLAYER = 0x100
_G.COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
_G.COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
_G.COMBATLOG_OBJECT_REACTION_NEUTRAL = 0x20
_G.COMBATLOG_OBJECT_TYPE_NPC = 0x800
_G.COMBATLOG_OBJECT_TYPE_PET = 0x1000
_G.COMBATLOG_OBJECT_TYPE_GUARDIAN = 0x2000

-- Record anchors on every widget so the layout can be inspected.
local FrameMethods = getmetatable(CreateFrame("Frame")).__index
local WidgetMethods = getmetatable(CreateFrame("Frame"):CreateFontString()).__index
local function recordPoint(self, point, rel, relPoint, x, y)
    self._points = self._points or {}
    if type(rel) == "number" then x, y, rel, relPoint = rel, relPoint, nil, nil end
    self._points[point] = {rel = rel, relPoint = relPoint, x = x or 0, y = y or 0}
end
FrameMethods.SetPoint = recordPoint
WidgetMethods.SetPoint = recordPoint
FrameMethods.SetHeight = function(self, h) self._height = h end
FrameMethods.GetHeight = function(self) return self._height or 100 end
FrameMethods.SetSize = function(self, w, h) self._width, self._height = w, h end
FrameMethods.GetWidth = function(self) return self._width or 300 end

-- ------------------------------------------------------------------
-- Minimal DCQOS core: only what CombatLog.lua touches.
-- ------------------------------------------------------------------
local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end
_G.DCQOS = {
    defaults = {}, settings = {}, modules = {}, moduleOrder = {},
    Print = function(_, m) end,
    Debug = function() end,
    FireEvent = function() end,
    SaveSettings = function() end,
    PromptReloadUI = function() end,
    DeepCopy = function(_, t) return deepcopy(t) end,
    RegisterSettingsKeywords = function() end,
}
function DCQOS:MergeModuleDefaults(d)
    for k, v in pairs(d) do
        if self.defaults[k] == nil then self.defaults[k] = deepcopy(v) end
    end
end
function DCQOS:RegisterModule(name, config)
    self.modules[name] = config
    if config.defaults then self:MergeModuleDefaults(config.defaults) end
end
function DCQOS:SetSetting(path, value)
    local parts = {strsplit(".", path)}
    local cur = self.settings
    for i = 1, #parts - 1 do cur = cur[parts[i]] end
    cur[parts[#parts]] = value
end

_G.UnitExists = function(u) return u == "player" end
_G.UnitIsPlayer = function(u) return u == "player" end
local sent = {}
_G.SendChatMessage = function(msg, chatType, lang, target) sent[#sent + 1] = { msg = msg, chatType = chatType, target = target } end

-- Every global the module CREATES (slash registration aside) is a leak.
local leaked = {}
getmetatable(_G).__newindex = function(t, k, v)
    if type(k) == "string" and not k:match("^SLASH_") then leaked[#leaked + 1] = k end
    rawset(t, k, v)
end

dofile(ROOT..[[DC-QOS\Modules\CombatLog.lua]])
DCQOS.settings = deepcopy(DCQOS.defaults)
local CombatLog = DCQOS.modules.CombatLog
ok(CombatLog ~= nil, "CombatLog module registered")

CombatLog.OnInitialize()
CombatLog.OnEnable()

-- Find the meter window: the UIParent child that owns a title bar.
local frame
for _, child in ipairs(UIParent._children) do
    if child.titleBar then frame = child end
end
ok(frame ~= nil, "combat frame created on enable")

local function bars()
    local out = {}
    for _, child in ipairs(frame._children) do
        if child._type == "StatusBar" then out[#out + 1] = child end
    end
    return out
end
local function shownBars()
    local n = 0
    for _, b in ipairs(bars()) do if b._shown then n = n + 1 end end
    return n
end

-- Layout constants mirrored from the module.
local INSET, TITLE, TOTALS, FOOTER, GAP = 3, 22, 13, 18, 2

-- ------------------------------------------------------------------
-- Feed a fight with 12 party members through the real event handler.
-- ------------------------------------------------------------------
-- The module registers COMBAT_LOG_EVENT_UNFILTERED on a parentless frame
-- created at file scope. Re-run enable with a SetScript hook to capture it.
local handler
local captured
local origSetScript = FrameMethods.SetScript
FrameMethods.SetScript = function(self, k, v)
    if k == "OnEvent" then captured = self end
    return origSetScript(self, k, v)
end
CombatLog.OnEnable()
FrameMethods.SetScript = origSetScript
ok(captured ~= nil and captured._scripts.OnEvent ~= nil, "found the combat event frame")
handler = captured._scripts.OnEvent

local PARTY = 0x2 | 0x10 | 0x100 | 0x400
local MINE = 0x1 | 0x10 | 0x100 | 0x400
handler(captured, "PLAYER_REGEN_DISABLED")
advance(1)
for i = 1, 12 do
    local guid = string.format("0x%016X", i)
    local flags = (i == 1) and MINE or PARTY
    handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SWING_DAMAGE",
        guid, (i == 1) and "Tester" or ("Member" .. i), flags,
        "0xF130000001000001", "Target Dummy", 0x10A48,
        1000 * (13 - i), 0, 1, 0, 0, 0, nil, nil, nil)
end
advance(1)

print("== bar count follows the available height ==")
local function layoutCheck(height, totalsMode, expectBars)
    DCQOS.settings.combatLog.totalsDisplay = totalsMode
    frame:SetSize(200, height)
    CombatLog.UpdateFrame()
    local n = shownBars()
    ok(n == expectBars, string.format("height %d, totals '%s': %d bars shown (expected %d)", height, totalsMode, n, expectBars))

    local contentTop = INSET + TITLE + GAP + ((totalsMode == "line") and TOTALS or 0)
    local contentBottom = INSET + FOOTER + GAP
    local barHeight = DCQOS.settings.combatLog.barHeight
    local overflow = 0
    for _, b in ipairs(bars()) do
        if b._shown then
            local p = b._points.TOPLEFT
            local top = -p.y
            if top < contentTop or (top + barHeight) > (height - contentBottom) then overflow = overflow + 1 end
        end
    end
    ok(overflow == 0, "  every shown bar sits between the header and the footer")
end
layoutCheck(250, "line", 9)
layoutCheck(250, "off", 10)     -- 11 would fit; maxBars (10) caps it
layoutCheck(100, "line", 2)
layoutCheck(100, "off", 2)
layoutCheck(60, "off", 0)       -- nothing fits: nothing drawn, nothing overflows

print("== texts are boxed so they truncate instead of overlapping ==")
local first = bars()[1]
ok(first.nameText._points.RIGHT and first.nameText._points.RIGHT.rel == first.valueText,
    "bar name is anchored RIGHT to the value text")
ok(first.nameText._points.LEFT and first.nameText._points.LEFT.rel == first.rank,
    "bar name is anchored LEFT to the rank")
ok(frame.title._points.RIGHT and frame.title._points.RIGHT.rel == frame.timerText,
    "title is anchored RIGHT to the timer (cannot run under the buttons)")
ok(frame.totalsText._points.TOPLEFT and frame.totalsText._points.TOPRIGHT,
    "totals line is anchored on both sides")
ok(first._points.RIGHT and first._points.RIGHT.rel == frame,
    "bars stretch with the window (RIGHT anchored to the frame)")

print("== value text carries the share of the total ==")
frame:SetSize(200, 250)
CombatLog.UpdateFrame()
ok(type(first.valueText._text) == "string" and first.valueText._text:find("%%%)$") ~= nil,
    "damage row shows '<total> (<per second>, <share>%)': " .. tostring(first.valueText._text))

print("== footer tabs track the mode ==")
local tabs = frame.modeTabs
ok(#tabs == 3, "three mode tabs")
ok(tabs[1].underline:IsShown() and not tabs[2].underline:IsShown(), "damage tab active by default")
tabs[2]._scripts.OnClick(tabs[2])
CombatLog.UpdateFrame()
ok(DCQOS.settings.combatLog.meterMode == "healing", "clicking the Heal tab switches the mode")
ok(tabs[2].underline:IsShown() and not tabs[1].underline:IsShown(), "heal tab is now the active one")
tabs[1]._scripts.OnClick(tabs[1])
CombatLog.UpdateFrame()

print("== lock hides the grip and restores it ==")
CombatLog.ToggleLock()
ok(frame.resizeGrip._shown == false, "locked: resize grip hidden")
CombatLog.ToggleLock()
ok(frame.resizeGrip._shown == true, "unlocked: resize grip back")

print("== size clamp on resize ==")
frame:SetSize(50, 30)
frame.resizeGrip._scripts.OnMouseUp(frame.resizeGrip)
ok(DCQOS.settings.combatLog.frameWidth >= 180 and DCQOS.settings.combatLog.frameHeight >= 100,
    string.format("undersized drag is clamped to %dx%d", DCQOS.settings.combatLog.frameWidth, DCQOS.settings.combatLog.frameHeight))

print("== fight lifecycle ==")
local DUMMY, DUMMY_FLAGS = "0xF130000001000001", 0x10A48
local function swing(srcGuid, srcName, srcFlags, dstGuid, dstName, dstFlags, amount, absorbed)
    handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SWING_DAMAGE", srcGuid, srcName, srcFlags,
        dstGuid, dstName, dstFlags, amount, 0, 1, 0, 0, absorbed or 0, nil, nil, nil)
end
local function rowNames()
    CombatLog.UpdateFrame()
    local names = {}
    for _, b in ipairs(bars()) do
        if b._shown then names[#names + 1] = b.nameText._text end
    end
    return names
end
local function hasRow(name)
    for _, n in ipairs(rowNames()) do
        if n == name then return true end
    end
    return false
end
local function setMode(m)
    DCQOS.settings.combatLog.meterMode = m
    CombatLog.UpdateFrame()
end
local function firstValue()
    return tostring(bars()[1] and bars()[1].valueText._text)
end

-- Close the first fight (2s: too short for a segment) and open a new one.
handler(captured, "PLAYER_REGEN_ENABLED")
advance(4)
handler(captured, "PLAYER_REGEN_DISABLED")
setMode("damage")
ok(#rowNames() == 0, "new fight starts empty")

-- Pet damage lands on the owner (3.3.5 has no IsInRaid; MINE flag path)
local PET = 0x1 | 0x10 | 0x100 | 0x1000
swing("0xF140000000000099", "Ghoul", PET, DUMMY, "Target Dummy", DUMMY_FLAGS, 3000)
ok(hasRow("Tester") and not hasRow("Ghoul"), "own pet damage is credited to the owner, no pet row")

swing("0x0000000000000001", "Tester", MINE, DUMMY, "Target Dummy", DUMMY_FLAGS, 3000)

-- Shield on Member2, then a partially absorbed hit: credit goes to the caster
handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SPELL_AURA_APPLIED", "0x0000000000000001", "Tester", MINE,
    "0x0000000000000002", "Member2", PARTY, 17, "Power Word: Shield", 2, "BUFF")
swing(DUMMY, "Target Dummy", DUMMY_FLAGS, "0x0000000000000002", "Member2", PARTY, 1000, 500)
setMode("absorbs")
ok(rowNames()[1] == "Tester" and firstValue():find("^500"), "partial absorb on Member2 is credited to the shield caster: " .. firstValue())

-- A dodged attack: once on the attacker's spell, once on the victim's avoidance
handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SWING_MISSED", "0x0000000000000001", "Tester", MINE, DUMMY, "Target Dummy", DUMMY_FLAGS, "DODGE")
handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SWING_MISSED", DUMMY, "Target Dummy", DUMMY_FLAGS, "0x0000000000000001", "Tester", MINE, "DODGE")
setMode("damage")
local testerBar
for _, b in ipairs(bars()) do
    if b._shown and b.nameText._text == "Tester" then testerBar = b end
end
ok(testerBar and testerBar.data.dodges == 1 and testerBar.data.spells[0].dodges == 1,
    "attacker-side dodge stays on the spell; victim-side dodge counts as avoidance")

-- Potion use comes from SPELL_CAST_SUCCESS (potions never apply an aura)
handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SPELL_CAST_SUCCESS", "0x0000000000000001", "Tester", MINE,
    "0x0000000000000001", "Tester", MINE, 43185, "Runic Healing Potion", 2)
setMode("consumables")
ok(hasRow("Tester") and firstValue() == "1", "potion use is counted from SPELL_CAST_SUCCESS: " .. firstValue())

-- Enemy mode
setMode("enemyDamageTaken")
ok(rowNames()[1] == "Target Dummy" and firstValue():find("^6.0K"), "enemy damage taken lists the dummy with 6.0K: " .. firstValue())
ok(bars()[1].enemy ~= nil and bars()[1].enemy.creatureId == 1, "enemy row carries the creature id parsed from the 3.3.5 GUID")

-- Drill-down
setMode("damage")
CombatLog.OnBarClick(bars()[1], "LeftButton")
ok(CombatLog.IsInDetailView(), "left-click opens the breakdown")
ok(rowNames()[1] == "Melee", "breakdown rows are the player's spells: " .. tostring(rowNames()[1]))
ok(tostring(frame.title._text):find("^|cffFFCC00<|r Tester") ~= nil, "title shows the drilled player: " .. tostring(frame.title._text))
CombatLog.OnBarClick(bars()[1], "LeftButton")
ok(not CombatLog.IsInDetailView() and rowNames()[1] == "Tester", "second click returns to the overview")

-- Report
sent = {}
ok(CombatLog.Report("say", 3), "report to say succeeds")
ok(#sent == 2 and sent[1].chatType == "SAY" and sent[1].msg:find("^DC Combat %- Damage") ~= nil and sent[2].msg:find("^1%. Tester") ~= nil,
    "report posts header + rows: " .. tostring(sent[1] and sent[1].msg) .. " / " .. tostring(sent[2] and sent[2].msg))
ok(not CombatLog.Report("party"), "party report is refused when not grouped")

-- End the fight after 6s: segment named after the enemy
advance(6)
handler(captured, "PLAYER_REGEN_ENABLED")
local segs = CombatLog.GetSegments()
ok(#segs == 1 and tostring(segs[1].name):find("Target Dummy") ~= nil, "fight saved as a segment named after the enemy: " .. tostring(segs[1] and segs[1].name))

-- Out of combat, a heal 4s later must not wipe the last fight...
advance(4)
handler(captured, "COMBAT_LOG_EVENT_UNFILTERED", GetTime(), "SPELL_HEAL", "0x0000000000000001", "Tester", MINE,
    "0x0000000000000001", "Tester", MINE, 2050, "Holy Light", 2, 500, 0, 0, nil)
setMode("damage")
ok(hasRow("Tester") and firstValue():find("^6.0K"), "a heal after combat keeps the last fight on screen: " .. firstValue())
-- ...but hostile damage starts a new fight, keeping the triggering hit
swing("0x0000000000000002", "Member2", PARTY, DUMMY, "Target Dummy", DUMMY_FLAGS, 1500)
local names = rowNames()
ok(#names == 1 and names[1] == "Member2" and firstValue():find("^1.5K"), "hostile damage after the grace period starts a new fight with that hit: " .. firstValue())

-- Viewing the saved segment uses the segment's duration and shows it on the timer
SlashCmdList["DCCOMBAT"]("segment 1")
ok(rowNames()[1] == "Tester" and firstValue() == "6.0K (1.0K, 100%)", "segment view: 6.0K over 6s = 1.0K/s: " .. firstValue())
ok(frame.timerText._text == "6s", "timer shows the segment duration: " .. tostring(frame.timerText._text))
SlashCmdList["DCCOMBAT"]("segment 0")
ok(rowNames()[1] == "Member2", "back to the current fight")

ok(#leaked == 0, "module leaks no globals: " .. table.concat(leaked, ", "))

local unexpected = {}
for k in pairs(missing) do unexpected[#unexpected + 1] = k end
table.sort(unexpected)
print("globals resolved by the fallback: " .. table.concat(unexpected, ", "))

print(string.format("RESULT: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
