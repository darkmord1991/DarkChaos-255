--[[
    DC-QOS NameplatesPlus (Modules/NameplatesPlus.lua) with the native client's nameplate API, on the strict 3.3.5a
    client. The native client gives every shown plate a unit token (frame.namePlateUnitToken = "nameplateN"),
    C_NamePlate.GetNamePlateForUnit, and NAME_PLATE_CREATED / NAME_PLATE_UNIT_ADDED / NAME_PLATE_UNIT_REMOVED. Pins
    that a plate is hooked from those events alone (the plates here are not WorldFrame children, so the scanner
    cannot find them), that every plate resolves to its own token, so two mobs with the same name, level and health
    each show their own debuffs and cast bar and not only the target does, that UNIT_AURA for a token refreshes that
    plate at once, that a plate handed to another unit under the same token drops the old unit's debuffs at once, that
    the target highlight follows UnitIsUnit, and that with the tokens off (nameplateUnitTokens 0) the name, level and
    health matching takes over again.

    test_nameplates_old.lua is the old client: no C_NamePlate, the NAME_PLATE_* events are never registered (3.3.5
    throws on an event it does not know), the WorldFrame scanner hooks the plates, and only the matched target gets a
    unit.

    Run from this directory:  lua test_nameplates.lua        (-v prints every check)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local CLIENT = SIM.client
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors
local NATIVE = not OLD_CLIENT

-- ----------------------------------------------------------------------------
-- Units: token -> record. On the native client the nameplate tokens resolve too.
-- ----------------------------------------------------------------------------

local tokens = {}

local function U(unit)
    return unit and tokens[unit]
end

local stock = {
    UnitExists = UnitExists, UnitName = UnitName, UnitGUID = UnitGUID, UnitLevel = UnitLevel,
    UnitIsUnit = UnitIsUnit, UnitAffectingCombat = UnitAffectingCombat,
}

function UnitExists(unit)
    if U(unit) then
        return 1
    end
    return stock.UnitExists(unit)
end

function UnitName(unit)
    local u = U(unit)
    if u then
        return u.name
    end
    return stock.UnitName(unit)
end

function UnitGUID(unit)
    local u = U(unit)
    if u then
        return u.guid
    end
    return stock.UnitGUID(unit)
end

function UnitLevel(unit)
    local u = U(unit)
    if u then
        return u.level
    end
    return stock.UnitLevel(unit)
end

function UnitHealth(unit)
    local u = U(unit)
    return u and u.health or 0
end

function UnitHealthMax(unit)
    local u = U(unit)
    return u and u.maxHealth or 0
end

function UnitIsUnit(a, b)
    local x, y = U(a), U(b)
    if x or y then
        return x ~= nil and x == y and 1 or nil
    end
    return stock.UnitIsUnit(a, b)
end

function UnitAffectingCombat(unit)
    if U(unit) then
        return nil
    end
    return stock.UnitAffectingCombat(unit)
end

function UnitDebuff(unit, index)
    local u = U(unit)
    local aura = u and u.debuffs and u.debuffs[index]
    if aura then
        return aura.name, "", aura.icon, 0, nil, aura.duration, aura.expires, "player"
    end
end

function UnitBuff()
    return nil
end

function UnitCastingInfo(unit)
    local u = U(unit)
    local cast = u and u.cast
    if cast then
        return cast.name, "", cast.name, cast.icon, cast.start, cast.stop, nil, 1, nil
    end
end

function UnitChannelInfo()
    return nil
end

function UnitIsFriend()
    return nil
end

function UnitIsEnemy()
    return 1
end

function UnitReaction()
    return 2
end

function UnitCanAttack()
    return 1
end

function UnitDetailedThreatSituation()
    return nil
end

function UnitClassification()
    return "normal"
end

GetShapeshiftForm = GetShapeshiftForm or function()
    return 0
end

GetQuestDifficultyColor = GetQuestDifficultyColor or function()
    return { r = 1, g = 0.82, b = 0 }
end

-- ----------------------------------------------------------------------------
-- The native client's nameplate API
-- ----------------------------------------------------------------------------

local platesByToken = {}

if NATIVE then
    for _, event in ipairs({ "NAME_PLATE_CREATED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
        SIM.KNOWN_EVENTS[event] = true
    end
    CLIENT.cvars.nameplateUnitTokens = "1"

    C_NamePlate = {}

    function C_NamePlate.GetNamePlates()
        local list = {}
        for index = 1, 40 do
            if platesByToken["nameplate" .. index] then
                list[#list + 1] = platesByToken["nameplate" .. index]
            end
        end
        return list
    end

    function C_NamePlate.GetNamePlateForUnit(unit)
        local u = U(unit)
        if not u then
            return nil
        end
        for token, frame in pairs(platesByToken) do
            if tokens[token] == u then
                return frame
            end
        end
    end
end

-- The stock plate: a health bar and a cast bar, then its regions (glow, borders, shield, spell icon, highlight, the
-- name, the level, the boss, raid and elite icons). On the native client the plates sit under a frame of their own
-- here, so that only the native events can hand them to the module.
local plateHolder = NATIVE and CreateFrame("Frame", "TestNamePlateHolder", UIParent) or WorldFrame
local plateCount = 0

local function NewPlate(announce)
    plateCount = plateCount + 1
    local plate = CreateFrame("Frame", nil, plateHolder)
    plate:SetWidth(120)
    plate:SetHeight(30)
    plate:SetPoint("CENTER", plateHolder, "CENTER", plateCount * 130 - 300, 100)

    local health = CreateFrame("StatusBar", nil, plate)
    health:SetWidth(110)
    health:SetHeight(10)
    health:SetPoint("TOP", plate, "TOP", 0, -8)
    health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")

    local cast = CreateFrame("StatusBar", nil, plate)
    cast:SetWidth(110)
    cast:SetHeight(8)
    cast:SetPoint("TOP", health, "BOTTOM", 0, -4)
    cast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    cast:Hide()

    for _ = 1, 6 do
        plate:CreateTexture(nil, "BORDER"):SetTexture("Interface\\Tooltips\\Nameplate-Border")
    end
    local name = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local level = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    for _ = 1, 3 do
        plate:CreateTexture(nil, "OVERLAY")
    end

    plate.test = { health = health, name = name, level = level }
    plate:Hide()
    if NATIVE and announce then
        SIM.FireEvent("NAME_PLATE_CREATED", plate)
    end
    return plate
end

local function Display(plate, record)
    plate.test.name:SetText(record.name)
    plate.test.level:SetText(tostring(record.level))
    plate.test.health:SetMinMaxValues(0, record.maxHealth)
    plate.test.health:SetValue(record.health)
end

-- The client shows a plate for a unit; the native one assigns its token and announces it
local function ShowUnit(plate, token, record)
    Display(plate, record)
    plate:Show()
    if NATIVE then
        tokens[token] = record
        platesByToken[token] = plate
        if CLIENT.cvars.nameplateUnitTokens ~= "0" then
            plate.namePlateUnitToken = token
            SIM.FireEvent("NAME_PLATE_UNIT_ADDED", token)
        end
    end
end

-- REMOVED arrives while the token still resolves; the token is cleared after it
local function HideUnit(plate, token)
    if NATIVE and plate.namePlateUnitToken then
        SIM.FireEvent("NAME_PLATE_UNIT_REMOVED", token)
        plate.namePlateUnitToken = nil
    end
    tokens[token] = nil
    platesByToken[token] = nil
    plate:Hide()
end

-- One plate update pass (the module refreshes plates every 0.05 s and debuffs every 0.25 s)
local function Pass()
    SIM.Tick(0.06)
end

local function DebuffIcon(plate, index)
    local icons = plate.dcDebuffFrame and plate.dcDebuffFrame.icons
    local icon = icons and icons[index or 1]
    if icon and icon:IsShown() and plate.dcDebuffFrame:IsShown() then
        return icon.texture:GetTexture()
    end
end

local function CastName(plate)
    local overlay = plate.dcCastBarOverlay
    if overlay and overlay:IsShown() then
        return overlay.spellName:GetText()
    end
end

local MOONFIRE = "Interface\\Icons\\Spell_Nature_StarFall"
local REND = "Interface\\Icons\\Ability_Gouge"

local function Raptor(guid, health, extra)
    local record = { name = "Ravasaur", level = 80, health = health or 5000, maxHealth = 10000, guid = guid, debuffs = {} }
    for key, value in pairs(extra or {}) do
        record[key] = value
    end
    return record
end

-- ----------------------------------------------------------------------------
-- DC-QOS, just the module
-- ----------------------------------------------------------------------------

local notes = {}

DCQOS = { defaults = {}, modules = {}, settings = {} }

function DCQOS:RegisterModule(name, module)
    self.modules[name] = module
end

function DCQOS:Debug()
end

function DCQOS:Print(message)
    notes[#notes + 1] = message
end

function DCQOS:SetSetting(path, value)
    local key, field = path:match("^(%w+)%.(%w+)$")
    self.settings[key][field] = value
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = DeepCopy(item)
    end
    return copy
end

section("load")
SIM.LoadFile(SIM.ADDONS_DIR .. "DC-QOS/Modules/NameplatesPlus.lua", "DC-QOS", {})
local Nameplates = DCQOS.modules.NameplatesPlus
DCQOS.settings.nameplatesPlus = DeepCopy(DCQOS.defaults.nameplatesPlus)
Nameplates.OnInitialize()
Nameplates.OnEnable()
noNewErrors("the module loads and enables")

local updateFrame = _G.DCQoS_NameplatesFrame
local registered = updateFrame:IsEventRegistered("NAME_PLATE_UNIT_ADDED") and true or false
local warned = false
for _, warning in ipairs(SIM.warnings) do
    if warning:find("NAME_PLATE", 1, true) then
        warned = true
    end
end
ok(not warned, "no event unknown to this client was registered")

if not NATIVE then
    section("old client: the scanner and the matching")
    ok(not registered and not updateFrame:IsEventRegistered("NAME_PLATE_CREATED")
        and not updateFrame:IsEventRegistered("NAME_PLATE_UNIT_REMOVED"), "the NAME_PLATE_* events are not registered")

    local raptorA = Raptor("0xF130000001", 5000, {
        debuffs = { { name = "Moonfire", icon = MOONFIRE, duration = 12, expires = SIM.now + 10 } },
    })
    local raptorB = Raptor("0xF130000002", 7000, { cast = { name = "Fireball", start = 0, stop = 0 } })
    local p1, p2 = NewPlate(), NewPlate()
    ShowUnit(p1, "nameplate1", raptorA)
    ShowUnit(p2, "nameplate2", raptorB)
    SIM.Tick(0.11)
    ok(p1.dcHealthBar ~= nil and p2.dcHealthBar ~= nil, "the WorldFrame scanner hooks the plates")

    tokens.target = raptorA
    SIM.FireEvent("PLAYER_TARGET_CHANGED")
    Pass()
    ok(p1.dcResolvedUnit == "target", "the target's plate is matched by name, level and health: "
        .. tostring(p1.dcResolvedUnit))
    ok(DebuffIcon(p1) == MOONFIRE, "and shows the target's debuffs")
    ok(p2.dcResolvedUnit == nil, "another plate has no unit: " .. tostring(p2.dcResolvedUnit))
    ok(CastName(p2) == nil and DebuffIcon(p2) == nil, "so it has no cast bar and no debuffs")
    ok(p1.dcIsTarget == true, "the target is highlighted")

    noNewErrors("the old client's plates ran")
    T.Finish()
end

section("plates are hooked from the native events")
ok(registered and updateFrame:IsEventRegistered("NAME_PLATE_CREATED")
    and updateFrame:IsEventRegistered("NAME_PLATE_UNIT_REMOVED"), "the NAME_PLATE_* events are registered")
local p1 = NewPlate(true)
ok(p1.dcHealthBar ~= nil, "NAME_PLATE_CREATED hooks the plate")
-- a plate created before the module was enabled: its first NAME_PLATE_UNIT_ADDED hooks it
local p2 = NewPlate(false)
ok(p2.dcHealthBar == nil, "a plate nobody announced is not hooked yet")

section("every plate has its own unit")
local raptorA = Raptor("0xF130000001", 5000, {
    debuffs = { { name = "Moonfire", icon = MOONFIRE, duration = 12, expires = SIM.now + 10 } },
})
local raptorB = Raptor("0xF130000002", 5000, {
    cast = { name = "Fireball", icon = "Interface\\Icons\\Spell_Fire_FlameBolt", start = SIM.now * 1000,
        stop = (SIM.now + 3) * 1000 },
})
ShowUnit(p1, "nameplate1", raptorA)
ShowUnit(p2, "nameplate2", raptorB)
ok(p2.dcHealthBar ~= nil, "NAME_PLATE_UNIT_ADDED hooks it through C_NamePlate.GetNamePlateForUnit")
Pass()
ok(p1.dcResolvedUnit == "nameplate1" and p2.dcResolvedUnit == "nameplate2",
    "each plate resolves to its token: " .. tostring(p1.dcResolvedUnit) .. ", " .. tostring(p2.dcResolvedUnit))
ok(DebuffIcon(p1) == MOONFIRE, "the first mob shows its debuff, without being the target")
ok(DebuffIcon(p2) == nil, "the second, alike in name, level and health, does not show it")
ok(CastName(p2) == "Fireball", "the second shows its own cast: " .. tostring(CastName(p2)))
ok(CastName(p1) == nil, "the first casts nothing")
noNewErrors("the plates updated")

section("UNIT_AURA for a token refreshes that plate at once")
raptorB.debuffs = { { name = "Rend", icon = REND, duration = 15, expires = SIM.now + 15 } }
SIM.FireEvent("UNIT_AURA", "nameplate2")
Pass()
ok(DebuffIcon(p2) == REND, "the new debuff shows on the next pass, not after the 0.25 s refresh")

section("a plate handed to another unit drops the old unit's debuffs at once")
HideUnit(p1, "nameplate1")
local raptorC = Raptor("0xF130000003", 5000)
ShowUnit(p1, "nameplate1", raptorC)
Pass()
ok(p1.dcResolvedUnit == "nameplate1", "the plate has the same token again")
ok(DebuffIcon(p1) == nil, "and the new unit's (no) debuffs, not the old unit's Moonfire")

section("the target highlight follows the target's token")
tokens.target = raptorB
SIM.FireEvent("PLAYER_TARGET_CHANGED")
Pass()
ok(p2.dcIsTarget == true, "the target's plate is highlighted")
ok(p1.dcIsTarget == false, "the other is not")

section("tokens off: the matching takes over")
CLIENT.cvars.nameplateUnitTokens = "0"
p1.namePlateUnitToken = nil
p2.namePlateUnitToken = nil
raptorB.health = 7000
Display(p2, raptorB)
SIM.FireEvent("PLAYER_TARGET_CHANGED")
Pass()
ok(p2.dcResolvedUnit == "target", "the target's plate is matched again: " .. tostring(p2.dcResolvedUnit))
ok(p1.dcResolvedUnit == nil, "the other has no unit: " .. tostring(p1.dcResolvedUnit))
ok(DebuffIcon(p2) == REND, "the target still shows its debuffs")

noNewErrors("the native plates ran")
T.Finish()
