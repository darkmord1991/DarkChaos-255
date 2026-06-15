--[[
    DC-Collection Modules/FormModule.lua
    ====================================

    Shapeshift form customization ("alternate forms"). Lets druids (and, later,
    shaman ghost wolf) pick an alternate creature display for each shapeshift
    form, retail "barbershop forms" style.

    Server contract (COLL module):
        CMSG_GET_FORMS    -> SMSG_FORMS_DATA   (catalog + unlocks + current pick)
        CMSG_SET_FORM     -> SMSG_FORM_RESULT  (apply a skin to a form)
        CMSG_RESET_FORM   -> SMSG_FORM_RESULT  (revert a form to its auto default)

    The model ids exchanged here are CreatureDisplayInfo ids (the same value
    stored in the world DB `player_shapeshift_model.ModelID`), which is exactly
    what the client Model:SetDisplayInfo() widget consumes for preview.

    NOTE: the form/skin *models* are wired server-side later. Until then the
    server reports `available = false` (or an empty form list) and the UI shows
    an informative empty state.

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

-- ============================================================================
-- FORM MODULE
-- ============================================================================

local FormModule = {}
DC.FormModule = FormModule

-- ShapeshiftForm ids (mirror of core UnitDefines.h ShapeshiftForm enum).
DC.SHAPESHIFT_FORMS = {
    CAT        = 1,
    TREE       = 2,
    TRAVEL     = 3,
    AQUA       = 4,
    BEAR       = 5,
    DIREBEAR   = 8,
    GHOSTWOLF  = 16,
    FLIGHT_EPIC = 27,
    FLIGHT     = 29,
    MOONKIN    = 31,
}

-- Fallback display metadata so the UI looks right before the server enriches
-- a form with its own name/icon. Keyed by ShapeshiftForm id.
local FORM_META = {
    [1]  = { name = "Cat Form",       icon = "Interface\\Icons\\Ability_Druid_CatForm" },
    [2]  = { name = "Tree of Life",   icon = "Interface\\Icons\\Ability_Druid_TreeofLife" },
    [3]  = { name = "Travel Form",    icon = "Interface\\Icons\\Ability_Druid_TravelForm" },
    [4]  = { name = "Aquatic Form",   icon = "Interface\\Icons\\Ability_Druid_AquaticForm" },
    [5]  = { name = "Bear Form",      icon = "Interface\\Icons\\Ability_Racial_BearForm" },
    [8]  = { name = "Dire Bear Form", icon = "Interface\\Icons\\Ability_Racial_BearForm" },
    [16] = { name = "Ghost Wolf",     icon = "Interface\\Icons\\Spell_Nature_SpiritWolf" },
    [27] = { name = "Flight Form",    icon = "Interface\\Icons\\Ability_Druid_FlightForm" },
    [29] = { name = "Flight Form",    icon = "Interface\\Icons\\Ability_Druid_FlightForm" },
    [31] = { name = "Moonkin Form",   icon = "Interface\\Icons\\Spell_Nature_ForceOfNature" },
}

-- ============================================================================
-- STATE
-- ============================================================================

-- Ordered list (for stable UI) and id->entry map of the player's forms.
FormModule.formsOrdered = {}
FormModule.formsById = {}
FormModule.available = false
FormModule.loaded = false

function FormModule:Init()
    DC:Debug("FormModule initialized")
end

-- ============================================================================
-- CLASS GATING
-- ============================================================================

-- Classes that have customizable forms. Shaman is reserved for ghost-wolf
-- skins; the server still decides what is actually offered.
local FORM_CLASSES = {
    DRUID = true,
    SHAMAN = true,
}

function FormModule:PlayerHasForms()
    if type(UnitClass) ~= "function" then
        return false
    end
    local _, classFile = UnitClass("player")
    return classFile ~= nil and FORM_CLASSES[classFile] == true
end

-- ============================================================================
-- DATA INGESTION (from SMSG_FORMS_DATA)
-- ============================================================================

-- Normalize one server-sent form entry, filling display metadata fallbacks.
local function NormalizeForm(raw)
    local formId = tonumber(raw.form) or 0
    local meta = FORM_META[formId] or {}

    local skins = {}
    if type(raw.skins) == "table" then
        for _, s in ipairs(raw.skins) do
            local model = tonumber(s.model) or 0
            if model > 0 then
                table.insert(skins, {
                    model = model,
                    name = s.name or ("Model " .. model),
                    unlocked = (s.unlocked ~= false),
                    source = s.source,
                })
            end
        end
    end

    -- Show stock skins first: their display ids (< 500000) exist in every
    -- client and render immediately, whereas custom retroport ids (500000+)
    -- only render once their DBC/M2 patch is deployed. Keeps the working
    -- options at the top instead of buried under undeployed retroports.
    table.sort(skins, function(a, b) return a.model < b.model end)

    return {
        form = formId,
        name = raw.name or meta.name or ("Form " .. formId),
        icon = raw.icon or meta.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        default = tonumber(raw.default) or 0,
        current = tonumber(raw.current) or 0, -- 0 == use auto/default
        skins = skins,
    }
end

function FormModule:SetData(data)
    data = data or {}

    self.available = (data.available == true) or (type(data.forms) == "table" and #data.forms > 0)
    self.formsOrdered = {}
    self.formsById = {}

    if type(data.forms) == "table" then
        for _, raw in ipairs(data.forms) do
            local entry = NormalizeForm(raw)
            if entry.form > 0 then
                table.insert(self.formsOrdered, entry)
                self.formsById[entry.form] = entry
            end
        end
    end

    self.loaded = true
    DC:Debug(string.format("FormModule: loaded %d forms (available=%s)",
        #self.formsOrdered, tostring(self.available)))

    -- Mirror into the generic collection cache so other code can introspect it.
    DC.collections = DC.collections or {}
    DC.collections.forms = self.formsById

    if DC.Forms and type(DC.Forms.Refresh) == "function" then
        DC.Forms:Refresh()
    end
end

-- Apply a server result for a single form (set/reset).
function FormModule:ApplyResult(data)
    data = data or {}
    local formId = tonumber(data.form) or 0
    local entry = self.formsById[formId]

    if data.success == false then
        DC:Print(string.format("|cffff0000Form change failed:|r %s",
            tostring(data.error or "unknown error")))
    elseif entry then
        entry.current = tonumber(data.model) or 0
    end

    if DC.Forms and type(DC.Forms.Refresh) == "function" then
        DC.Forms:Refresh()
    end
end

-- ============================================================================
-- ACCESS
-- ============================================================================

function FormModule:IsAvailable()
    return self.available == true
end

function FormModule:GetForms()
    return self.formsOrdered
end

function FormModule:GetForm(formId)
    return self.formsById[tonumber(formId) or 0]
end

-- The model that is *currently effective* for a form (chosen pick or default).
function FormModule:GetEffectiveModel(formId)
    local entry = self:GetForm(formId)
    if not entry then
        return 0
    end
    if entry.current and entry.current > 0 then
        return entry.current
    end
    return entry.default or 0
end

-- ============================================================================
-- ACTIONS
-- ============================================================================

function FormModule:Request()
    if not self:PlayerHasForms() then
        return false
    end
    return DC:RequestForms()
end

function FormModule:ApplySkin(formId, modelId)
    formId = tonumber(formId)
    modelId = tonumber(modelId)
    if not formId or not modelId then
        return false
    end

    local entry = self:GetForm(formId)
    if entry then
        for _, skin in ipairs(entry.skins) do
            if skin.model == modelId and skin.unlocked == false then
                DC:Print(L["FORM_LOCKED"] or "That form appearance is not unlocked yet.")
                return false
            end
        end
    end

    return DC:RequestSetForm(formId, modelId)
end

function FormModule:ResetForm(formId)
    formId = tonumber(formId)
    if not formId then
        return false
    end
    return DC:RequestResetForm(formId)
end
