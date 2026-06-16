--[[
    DC-Collection UI/FormFrame.lua
    ==============================

    Embedded "Forms" tab UI: pick an alternate creature display for each
    shapeshift form. Mirrors the wardrobe embed pattern (DC.Wardrobe:ShowEmbedded).

    Layout:
        [ form list ] [ 3D preview ] [ skin list ]
                                      [ Apply ] [ Reset ]

    The 3D preview uses a DressUpModel's SetDisplayInfo() (CreatureDisplayInfo
    id) + SetCamera/SetPosition/SetFacing so the model is framed (a bare model
    renders black). Mirrors the mount/pet preview setup in MainFrame.lua.

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

local Forms = {}
DC.Forms = Forms

local FORM_LIST_WIDTH = 150
local PREVIEW_HEIGHT = 260   -- wide-but-short preview banner across the top
local ROW_HEIGHT = 22

-- Currently selected form id and the model id being previewed (may differ from
-- the committed selection until "Apply" is pressed).
Forms.selectedForm = nil
Forms.previewModel = nil

-- ============================================================================
-- BUILD
-- ============================================================================

-- Apply a shapeshift-form skin to the preview model.
--
-- IMPORTANT: on this 3.3.5a client a CreatureDisplayInfo id does NOT render via
-- Model:SetDisplayInfo (unreliable / no model) or Model:SetCreature (that wants
-- a creature_template ENTRY, not a display id) — that's why mounts pass a real
-- creature entry and forms (display id only) showed black. The reliable path is
-- Model:SetModel(<m2 path>), exactly how DC-Housing renders its doodads, using
-- the generated DC.FormModelPaths[displayId] lookup. SetDisplayInfo/SetCreature
-- remain as fallbacks for any id missing from the path table.
--
-- onResult(ok) is invoked after load verification so the caller can show a
-- "preview unavailable" state when a display id resolves to no model.
local function SetPreviewDisplay(model, displayId, onResult)
    local function finish(ok)
        if type(onResult) == "function" then
            onResult(ok and true or false)
        end
    end
    if not model then
        finish(false)
        return
    end
    displayId = tonumber(displayId) or 0
    if displayId <= 0 then
        if type(model.ClearModel) == "function" then
            pcall(model.ClearModel, model)
        end
        model:Hide()
        finish(false)
        return
    end
    model:Show()

    local function ResetModelPose()
        if type(model.SetFacing) == "function" then
            pcall(model.SetFacing, model, model.rotation or 0)
        end
        if type(model.SetModelScale) == "function" then
            pcall(model.SetModelScale, model, model.modelZoom or 1.0)
        end
        if type(model.SetPosition) == "function" then
            pcall(model.SetPosition, model, 0, 0, 0)
        end
    end

    local function HasLoadedModel()
        if type(model.GetModel) ~= "function" then
            return true
        end
        local cur = model:GetModel()
        return cur ~= nil and cur ~= ""
    end

    local function TrySetModelPath(path)
        if type(path) ~= "string" or path == ""
            or type(model.SetModel) ~= "function" then
            return false
        end
        if pcall(model.SetModel, model, path) then
            -- A raw SetModel'd creature M2 can render unlit/black without an
            -- explicit light (same as the bare-Model housing preview).
            if type(model.SetLight) == "function" then
                pcall(model.SetLight, model, 1, 0, 0, 0, -1,
                    1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
            end
            ResetModelPose()
            return true
        end
        return false
    end

    local function TrySetDisplay(id)
        if not id or id <= 0 or type(model.SetDisplayInfo) ~= "function" then
            return false
        end
        if pcall(model.SetDisplayInfo, model, id) then
            ResetModelPose()
            return true
        end
        return false
    end

    local function TrySetCreature(id)
        if not id or id <= 0 or type(model.SetCreature) ~= "function" then
            return false
        end
        if pcall(model.SetCreature, model, id) then
            ResetModelPose()
            return true
        end
        return false
    end

    -- Clear stale model state FIRST (the step whose absence black-screened the
    -- preview when switching skins).
    if type(model.ClearModel) == "function" then
        pcall(model.ClearModel, model)
    end

    -- Preferred: SetModel with the resolved M2 path; fall back to the (less
    -- reliable) display/creature setters only if the path is unknown.
    local path = DC and DC.FormModelPaths and DC.FormModelPaths[displayId]
    local shown = TrySetModelPath(path)
    if not shown then
        shown = TrySetDisplay(displayId)
    end
    if not shown then
        shown = TrySetCreature(displayId)
    end

    -- pcall-success does not prove a model loaded. Re-verify shortly after and
    -- report the real outcome so the caller can flag it as unavailable rather
    -- than leaving a blank frame.
    local function VerifyLoaded()
        if HasLoadedModel() then
            finish(true)
            return
        end
        local recovered = TrySetModelPath(path)
        if not recovered then
            recovered = TrySetCreature(displayId)
        end
        finish(recovered and HasLoadedModel())
    end
    if DC and type(DC.After) == "function" then
        DC.After(0.12, VerifyLoaded)
    else
        VerifyLoaded()
    end
end

-- Custom retroport display ids live at >= 500000; their client model/DBC may
-- not be installed, so they can render empty. When defaulting a form's preview
-- (no committed pick), prefer a stock skin that is guaranteed to render so the
-- form doesn't open to an "unavailable" frame when a renderable option exists.
local CUSTOM_MODEL_MIN = 500000

local function PickDefaultModel(formId)
    local entry = DC.FormModule:GetForm(formId)
    if not entry then
        return 0
    end
    -- Always honour the player's committed pick, even a custom one (the overlay
    -- explains if its model isn't installed).
    if entry.current and entry.current > 0 then
        return entry.current
    end
    if entry.default and entry.default > 0 and entry.default < CUSTOM_MODEL_MIN then
        return entry.default
    end
    for _, skin in ipairs(entry.skins or {}) do
        if skin.unlocked ~= false and skin.model
            and skin.model < CUSTOM_MODEL_MIN then
            return skin.model
        end
    end
    if entry.default and entry.default > 0 then
        return entry.default
    end
    local first = entry.skins and entry.skins[1]
    return first and first.model or 0
end

function Forms:Build(host)
    if self.frame then
        self.frame:SetParent(host)
        self.frame:ClearAllPoints()
        self.frame:SetAllPoints(host)
        return self.frame
    end

    local frame = CreateFrame("Frame", "DCCollectionFormsFrame", host)
    frame:SetAllPoints(host)
    self.frame = frame

    -- --- Empty state -------------------------------------------------------
    local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    empty:SetText(L["FORM_EMPTY"] or "No customizable forms available for this character yet.")
    empty:Hide()
    frame.empty = empty

    -- --- Form list (left rail) --------------------------------------------
    local listFrame = CreateFrame("Frame", nil, frame)
    listFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    listFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 6)
    listFrame:SetWidth(FORM_LIST_WIDTH)
    local listBg = listFrame:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints()
    listBg:SetTexture(0.04, 0.05, 0.07, 0.6)
    frame.listFrame = listFrame
    frame.formButtons = {}

    -- --- 3D preview (wide banner across the top) --------------------------
    -- DressUpModel (not Model) is what the mount/pet previews use and is what
    -- frames a creature display correctly on 3.3.5a. Spans the full width right
    -- of the form list, with the skin list filling the area below it.
    local preview = CreateFrame("DressUpModel", "DCCollectionFormsModel", frame)
    preview:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 8, 0)
    preview:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -6)
    preview:SetHeight(PREVIEW_HEIGHT)
    preview:EnableMouse(true)
    preview:EnableMouseWheel(true)
    preview.rotation = 0
    preview.modelZoom = 1.0
    local previewBg = preview:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints()
    previewBg:SetTexture(0, 0, 0, 0.5)
    frame.preview = preview

    -- Drag to rotate + scroll to zoom (mirrors the mount preview).
    preview:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.rotating = true
            self.prevX = GetCursorPosition()
        end
    end)
    preview:SetScript("OnMouseUp", function(self)
        self.rotating = false
    end)
    preview:SetScript("OnUpdate", function(self)
        if self.rotating then
            local x = GetCursorPosition()
            self.rotation = (self.rotation or 0) + (x - (self.prevX or x)) * 0.01
            self:SetFacing(self.rotation)
            self.prevX = x
        end
    end)
    preview:SetScript("OnMouseWheel", function(self, delta)
        local s = (self.modelZoom or 1.0) + delta * 0.1
        s = math.max(0.5, math.min(2.5, s))
        self.modelZoom = s
        if self.SetModelScale then
            self:SetModelScale(s)
        end
    end)

    local previewLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("BOTTOM", preview, "BOTTOM", 0, 8)
    frame.previewLabel = previewLabel

    -- Shown when the selected skin's model fails to load (e.g. a custom display
    -- id whose client model patch isn't installed) so the pane reads as
    -- "unavailable" rather than a confusing empty/black frame.
    local unavailable = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    unavailable:SetPoint("CENTER", preview, "CENTER", 0, 0)
    unavailable:SetWidth(360)
    unavailable:SetJustifyH("CENTER")
    unavailable:SetText(L["FORM_PREVIEW_UNAVAILABLE"] or "Preview unavailable")
    unavailable:Hide()
    frame.previewUnavailable = unavailable

    -- --- Skin list (fills the area below the preview) ----------------------
    local skinScroll = CreateFrame("ScrollFrame", "DCCollectionFormsSkinScroll", frame,
        "FauxScrollFrameTemplate")
    skinScroll:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10)
    skinScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 34)
    frame.skinScroll = skinScroll
    frame.skinRows = {}

    skinScroll:SetScript("OnVerticalScroll", function(scrollSelf, offset)
        FauxScrollFrame_OnVerticalScroll(scrollSelf, offset, ROW_HEIGHT, function()
            Forms:RefreshSkins()
        end)
    end)

    -- --- Apply / Reset buttons --------------------------------------------
    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(110, 24)
    applyBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 6)
    applyBtn:SetText(L["FORM_APPLY"] or "Apply")
    applyBtn:SetScript("OnClick", function()
        Forms:CommitSelection()
    end)
    frame.applyBtn = applyBtn

    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 24)
    resetBtn:SetPoint("RIGHT", applyBtn, "LEFT", -6, 0)
    resetBtn:SetText(L["FORM_RESET"] or "Reset to Default")
    resetBtn:SetScript("OnClick", function()
        if Forms.selectedForm then
            DC.FormModule:ResetForm(Forms.selectedForm)
        end
    end)
    frame.resetBtn = resetBtn

    return frame
end

-- ============================================================================
-- FORM LIST
-- ============================================================================

function Forms:RefreshFormList()
    local frame = self.frame
    if not frame then
        return
    end

    -- Reuse / hide existing buttons.
    for _, btn in ipairs(frame.formButtons) do
        btn:Hide()
    end

    local forms = DC.FormModule:GetForms()
    for i, entry in ipairs(forms) do
        local btn = frame.formButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, frame.listFrame)
            btn:SetHeight(28)
            btn:SetPoint("TOPLEFT", frame.listFrame, "TOPLEFT", 2, -2 - (i - 1) * 30)
            btn:SetPoint("TOPRIGHT", frame.listFrame, "TOPRIGHT", -2, -2 - (i - 1) * 30)

            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetTexture(0.12, 0.14, 0.18, 0.85)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(20, 20)
            btn.icon:SetPoint("LEFT", btn, "LEFT", 4, 0)

            btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
            btn.label:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
            btn.label:SetJustifyH("LEFT")

            frame.formButtons[i] = btn
        end

        btn.formId = entry.form
        btn.icon:SetTexture(entry.icon)
        btn.label:SetText(entry.name)
        btn.bg:SetTexture(
            self.selectedForm == entry.form and 0.20 or 0.12,
            self.selectedForm == entry.form and 0.33 or 0.14,
            self.selectedForm == entry.form and 0.48 or 0.18,
            0.9)
        btn:SetScript("OnClick", function()
            Forms:SelectForm(entry.form)
        end)
        btn:Show()
    end
end

function Forms:SelectForm(formId)
    self.selectedForm = formId
    -- Default to the committed pick, else a renderable stock skin.
    self.previewModel = PickDefaultModel(formId)
    self:RefreshFormList()
    self:RefreshSkins()
    self:UpdatePreview()
end

-- ============================================================================
-- SKIN LIST
-- ============================================================================

function Forms:RefreshSkins()
    local frame = self.frame
    if not frame then
        return
    end

    local entry = self.selectedForm and DC.FormModule:GetForm(self.selectedForm)
    local skins = entry and entry.skins or {}

    local scroll = frame.skinScroll
    -- Fill the available height so the list isn't half-empty and the scrollbar
    -- reflects real content (only appears when there are more rows than fit).
    local h = scroll:GetHeight() or 0
    if h < ROW_HEIGHT then
        h = 440
    end
    local maxRows = math.max(1, math.floor(h / ROW_HEIGHT))
    FauxScrollFrame_Update(scroll, #skins, maxRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scroll)

    for i = 1, maxRows do
        local row = frame.skinRows[i]
        if not row then
            row = CreateFrame("Button", nil, scroll)
            row:SetHeight(ROW_HEIGHT)
            if i == 1 then
                row:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -2)
                row:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -2, -2)
            else
                row:SetPoint("TOPLEFT", frame.skinRows[i - 1], "BOTTOMLEFT", 0, -1)
                row:SetPoint("TOPRIGHT", frame.skinRows[i - 1], "BOTTOMRIGHT", 0, -1)
            end

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.label:SetPoint("LEFT", row, "LEFT", 6, 0)

            row.lock = row:CreateTexture(nil, "OVERLAY")
            row.lock:SetSize(14, 14)
            row.lock:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            row.lock:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")

            frame.skinRows[i] = row
        end

        local idx = i + offset
        local skin = skins[idx]
        if skin then
            row.model = skin.model
            row.label:SetText(skin.name)
            -- 3.3.5a has no SetShown(bool); use explicit Show/Hide.
            if skin.unlocked == false then
                row.lock:Show()
            else
                row.lock:Hide()
            end

            local selected = (self.previewModel == skin.model)
            if skin.unlocked == false then
                row.label:SetTextColor(0.5, 0.5, 0.5)
                row.bg:SetTexture(0.1, 0.05, 0.05, 0.6)
            else
                row.label:SetTextColor(1, 1, 1)
                row.bg:SetTexture(selected and 0.20 or 0.08, selected and 0.33 or 0.10,
                    selected and 0.48 or 0.13, 0.85)
            end

            row:SetScript("OnClick", function()
                Forms.previewModel = skin.model
                Forms:RefreshSkins()
                Forms:UpdatePreview()
            end)
            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================================================
-- PREVIEW + COMMIT
-- ============================================================================

function Forms:UpdatePreview()
    local frame = self.frame
    if not frame then
        return
    end

    -- Hide the "unavailable" overlay up front; the async load result below
    -- shows it again only if the model genuinely fails to load. (The model id
    -- is a CreatureDisplayInfo id — custom retroport ids >= 500000 render fine
    -- AS LONG AS their client patch is deployed; we no longer assume they
    -- aren't, and rely on the real load result instead.)
    if frame.previewUnavailable then
        frame.previewUnavailable:Hide()
    end

    if frame.preview then
        frame.preview:Show()
    end

    local requested = self.previewModel
    SetPreviewDisplay(frame.preview, requested, function(ok)
        -- Ignore stale async results if the selection changed meanwhile.
        if self.previewModel ~= requested then
            return
        end
        if frame.previewUnavailable then
            if ok then
                frame.previewUnavailable:Hide()
            else
                frame.previewUnavailable:Show()
            end
        end
    end)

    local entry = self.selectedForm and DC.FormModule:GetForm(self.selectedForm)
    if entry then
        frame.previewLabel:SetText(entry.name)
    else
        frame.previewLabel:SetText("")
    end
end

function Forms:CommitSelection()
    if not self.selectedForm or not self.previewModel then
        return
    end
    DC.FormModule:ApplySkin(self.selectedForm, self.previewModel)
end

-- ============================================================================
-- SHOW / HIDE / REFRESH
-- ============================================================================

function Forms:Refresh()
    local frame = self.frame
    if not frame or not frame:IsShown() then
        return
    end

    local hasForms = DC.FormModule:IsAvailable() and #DC.FormModule:GetForms() > 0
    if not hasForms then
        frame.empty:Show()
        frame.listFrame:Hide()
        frame.preview:Hide()
        frame.previewLabel:SetText("")
        if frame.previewUnavailable then
            frame.previewUnavailable:Hide()
        end
        frame.skinScroll:Hide()
        frame.applyBtn:Hide()
        frame.resetBtn:Hide()
        return
    end

    frame.preview:Show()

    frame.empty:Hide()
    frame.listFrame:Show()
    frame.skinScroll:Show()
    frame.applyBtn:Show()
    frame.resetBtn:Show()

    -- Default-select the first form if nothing chosen (or selection is stale).
    if not self.selectedForm or not DC.FormModule:GetForm(self.selectedForm) then
        self.selectedForm = DC.FormModule:GetForms()[1].form
        self.previewModel = PickDefaultModel(self.selectedForm)
    end

    self:RefreshFormList()
    self:RefreshSkins()
    self:UpdatePreview()
end

function Forms:ShowEmbedded(host)
    self:Build(host)
    self.frame:Show()

    -- Always re-request on open so unlocks/picks reflect the latest server state.
    DC.FormModule:Request()
    self:Refresh()
end

function Forms:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
