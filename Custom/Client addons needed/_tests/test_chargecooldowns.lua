--[[
    The recharge sweep for spell charges on the stock action buttons (DC-QOS/Modules/Cooldowns.lua, "Spell
    Charges"), on the strict 3.3.5a client with the native client's GetActionCharges and SPELL_UPDATE_CHARGES. The
    count needs nothing (GetActionCount answers it natively). Pins that a button whose spell recharges a charge
    (0 < current < max) gets a second, edge-style cooldown, button.dcChargeCooldown, with the recharge's start and
    duration, below the button's own cooldown so the spell's cooldown and the GCD draw over it, and without the
    cooldown-text timer the module hangs on CooldownFrame_SetTimer; that it hides with all charges back, with none
    left (the button's own cooldown shows that recharge), for a spell without charges and for an emptied slot;
    that SPELL_UPDATE_CHARGES refreshes the visible buttons; and that the module's switches turn it off.
    test_chargecooldowns_old.lua is the old client: no GetActionCharges, so nothing is hooked, registered or created.

    Run from this directory:  lua test_chargecooldowns.lua        (-v prints every check)
]]

dofile("talents_sim.lua")
dofile("talents_client.lua")
local T = dofile("talents_testlib.lua")
local ok, section, noNewErrors = T.ok, T.section, T.noNewErrors
local NATIVE = not OLD_CLIENT

-- ----------------------------------------------------------------------------
-- Action slots and the stock button code (ActionButton.lua / Cooldown.lua, 3.3.5a, the parts that run here)
-- ----------------------------------------------------------------------------

local slots = {}     -- slot -> { charges = { current, max, start, duration } or nil, cooldown = { start, duration } }

function HasAction(slot)
    return slots[slot] and 1 or nil
end

function GetActionCooldown(slot)
    local cooldown = slots[slot] and slots[slot].cooldown
    if cooldown then
        return cooldown[1], cooldown[2], 1
    end
    return 0, 0, 1
end

function CooldownFrame_SetTimer(self, start, duration, enable)
    if start > 0 and duration > 0 and enable > 0 then
        self:SetCooldown(start, duration)
        self:Show()
    else
        self:Hide()
    end
end

function ActionButton_UpdateCooldown(self)
    local cooldown = _G[self:GetName() .. "Cooldown"]
    local start, duration, enable = GetActionCooldown(self.action)
    CooldownFrame_SetTimer(cooldown, start, duration, enable)
end

function ActionButton_Update(self)
    if HasAction(self.action) then
        ActionButton_UpdateCooldown(self)
    end
end

local stockUpdateCooldown, stockUpdate = ActionButton_UpdateCooldown, ActionButton_Update

local function NewButton(index)
    local button = CreateFrame("CheckButton", "ActionButton" .. index, UIParent)
    button:SetWidth(36)
    button:SetHeight(36)
    button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", index * 40, 10)
    local cooldown = CreateFrame("Cooldown", "ActionButton" .. index .. "Cooldown", button)
    cooldown:SetWidth(36)
    cooldown:SetHeight(36)
    cooldown:SetPoint("CENTER", button, "CENTER", 0, -1)
    cooldown:Hide()
    button.action = index
    return button
end

-- What a Cooldown was last given
local cooldownMethods = getmetatable(CreateFrame("Cooldown")).__index
local stockSetCooldown = cooldownMethods.SetCooldown
cooldownMethods.SetCooldown = function(self, start, duration)
    self.testStart, self.testDuration = start, duration
    return stockSetCooldown(self, start, duration)
end

-- ----------------------------------------------------------------------------
-- The native client
-- ----------------------------------------------------------------------------

if NATIVE then
    SIM.KNOWN_EVENTS.SPELL_UPDATE_CHARGES = true
    -- Cooldown:SetDrawEdge is a client method (CGCooldown_Scripts) that the 3.x reference this simulator is built
    -- from leaves out
    cooldownMethods.SetDrawEdge = function(self, edge)
        self.testDrawEdge = edge
    end

    function GetActionCharges(slot)
        local charges = slots[slot] and slots[slot].charges
        if charges then
            return charges[1], charges[2], charges[3], charges[4]
        end
    end
end

-- ----------------------------------------------------------------------------
-- DC-QOS, just the module
-- ----------------------------------------------------------------------------

DCQOS = {
    defaults = {},
    modules = {},
    settings = { cooldowns = { enabled = true, minDuration = 2, fontSize = 18 } },
}

function DCQOS:RegisterModule(name, module)
    self.modules[name] = module
    for key, values in pairs(module.defaults or {}) do
        for field, value in pairs(values) do
            if self.settings[key][field] == nil then
                self.settings[key][field] = value
            end
        end
    end
end

function DCQOS:Debug()
end

section("load")
local buttons = { NewButton(1), NewButton(2) }
SIM.LoadFile(SIM.ADDONS_DIR .. "DC-QOS/Modules/Cooldowns.lua", "DC-QOS", {})
local Cooldowns = DCQOS.modules.Cooldowns
Cooldowns.OnInitialize()
Cooldowns.OnEnable()
noNewErrors("the module loads and enables")
local warned = false
for _, warning in ipairs(SIM.warnings) do
    warned = warned or warning:find("SPELL_UPDATE_CHARGES", 1, true) ~= nil
end
ok(not warned, "no event unknown to this client was registered")

local button = buttons[1]
local main = ActionButton1Cooldown

if not NATIVE then
    section("old client: no charges")
    ok(ActionButton_UpdateCooldown == stockUpdateCooldown and ActionButton_Update == stockUpdate,
        "the stock button functions are not hooked")
    slots[1] = { charges = { 1, 2, SIM.now, 8 } }
    ActionButton_Update(button)
    SIM.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
    ok(button.dcChargeCooldown == nil, "no charge cooldown is created")
    noNewErrors("the old client's buttons ran")
    T.Finish()
end

section("a charge recharging")
ok(ActionButton_UpdateCooldown ~= stockUpdateCooldown, "ActionButton_UpdateCooldown is hooked")
slots[1] = { charges = { 1, 2, SIM.now - 2, 8 } }
ActionButton_Update(button)
local sweep = button.dcChargeCooldown
ok(sweep ~= nil and sweep:IsShown(), "one of two charges left: the recharge sweep shows")
ok(sweep and sweep.testStart == SIM.now - 2 and sweep.testDuration == 8,
    "with the recharge's start and duration: " .. tostring(sweep and sweep.testStart) .. ", "
    .. tostring(sweep and sweep.testDuration))
ok(sweep and sweep.testDrawEdge == true, "edge-style")
ok(sweep and sweep:GetFrameLevel() < main:GetFrameLevel(), "below the button's own cooldown, which draws over it")
ok(sweep and sweep:GetFrameLevel() > button:GetFrameLevel(), "above the button's icon")
ok(not main:IsShown(), "the button's own cooldown stays free (no spell cooldown now)")
ok(sweep and sweep.timer == nil, "no cooldown-text timer on the sweep: the count is the text there")

slots[1].cooldown = { SIM.now, 1.5 }
SIM.FireEvent("ACTIONBAR_UPDATE_COOLDOWN")
ActionButton_UpdateCooldown(button)
ok(main:IsShown() and sweep:IsShown(), "the global cooldown shows on the button's own cooldown, over the sweep")
slots[1].cooldown = nil
ActionButton_UpdateCooldown(button)

section("SPELL_UPDATE_CHARGES refreshes the buttons")
slots[1].charges = { 2, 2, 0, 0 }
SIM.FireEvent("SPELL_UPDATE_CHARGES")
ok(not sweep:IsShown(), "all charges back: the sweep hides")
slots[1].charges = { 1, 2, SIM.now, 8 }
SIM.FireEvent("SPELL_UPDATE_CHARGES")
ok(sweep:IsShown() and sweep.testStart == SIM.now, "a charge spent: it shows the new recharge")
slots[1].charges = { 0, 2, SIM.now, 8 }
SIM.FireEvent("SPELL_UPDATE_CHARGES")
ok(not sweep:IsShown(), "no charge left: hidden, the button's own cooldown shows that recharge")
ok(button.dcChargeCooldown == sweep, "the sweep is created once")

section("spells without charges and empty slots")
slots[2] = { cooldown = { SIM.now, 30 } }
ActionButton_Update(buttons[2])
ok(buttons[2].dcChargeCooldown == nil, "a spell without charges gets no sweep")
slots[1].charges = { 1, 2, SIM.now, 8 }
ActionButton_Update(button)
ok(sweep:IsShown(), "shown again")
slots[1] = nil
ActionButton_Update(button)
ok(not sweep:IsShown(), "emptying the slot hides it (ActionButton_Update runs without ActionButton_UpdateCooldown)")

section("the module's switches")
slots[1] = { charges = { 1, 2, SIM.now, 8 } }
ActionButton_Update(button)
ok(sweep:IsShown(), "on")
DCQOS.settings.cooldowns.chargeSweep = false
SIM.FireEvent("SPELL_UPDATE_CHARGES")
ok(not sweep:IsShown(), "its setting off hides it")
DCQOS.settings.cooldowns.chargeSweep = true
SIM.FireEvent("SPELL_UPDATE_CHARGES")
ok(sweep:IsShown(), "and on shows it again")
Cooldowns.OnDisable()
ok(not sweep:IsShown(), "disabling the Cooldowns module hides it")
Cooldowns.OnEnable()
ok(sweep:IsShown(), "enabling brings it back")

noNewErrors("the charge sweep ran")
T.Finish()
