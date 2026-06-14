--[[
    DC-Collection UI/FormFrame.lua
    ==============================

    Embedded "Forms" tab UI: pick an alternate creature display for each
    shapeshift form. Mirrors the wardrobe embed pattern (DC.Wardrobe:ShowEmbedded).

    Layout:
        [ form list ] [ 3D preview ] [ skin list ]
                                      [ Apply ] [ Reset ]

    The 3D preview uses a Model widget's SetDisplayInfo(), which takes a
    CreatureDisplayInfo id -- exactly the value the server sends per skin.

    Author: DarkChaos-255
    Version: 1.0.0
]]

local DC = DCCollection
local L = DC.L

local Forms = {}
DC.Forms = Forms

local FORM_LIST_WIDTH = 150
local PREVIEW_WIDTH = 240
local ROW_HEIGHT = 22

-- Currently selected form id and the model id being previewed (may differ from
-- the committed selection until "Apply" is pressed).
Forms.selectedForm = nil
Forms.previewModel = nil

-- ============================================================================
-- BUILD
-- ============================================================================

local function SetPreviewDisplay(model, displayId)
    if not model then
        return
    end
    displayId = tonumber(displayId) or 0
    if displayId <= 0 then
        model:Hide()
        return
    end
    model:Show()
    pcall(function()
        model:SetDisplayInfo(displayId)
    end)
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

    -- --- 3D preview (center) ----------------------------------------------
    local preview = CreateFrame("Model", nil, frame)
    preview:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 6, 0)
    preview:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMRIGHT", 6, 0)
    preview:SetWidth(PREVIEW_WIDTH)
    local previewBg = preview:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints()
    previewBg:SetTexture(0, 0, 0, 0.5)
    frame.preview = preview

    local previewLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewLabel:SetPoint("BOTTOM", preview, "BOTTOM", 0, 8)
    frame.previewLabel = previewLabel

    -- --- Skin list (right) -------------------------------------------------
    local skinScroll = CreateFrame("ScrollFrame", "DCCollectionFormsSkinScroll", frame,
        "FauxScrollFrameTemplate")
    skinScroll:SetPoint("TOPLEFT", preview, "TOPRIGHT", 8, 0)
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
    local entry = DC.FormModule:GetForm(formId)
    if entry then
        -- Preview the currently effective model by default.
        self.previewModel = DC.FormModule:GetEffectiveModel(formId)
    end
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
    local maxRows = 12
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
            row.lock:SetShown(skin.unlocked == false)

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
    SetPreviewDisplay(frame.preview, self.previewModel)

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
        frame.skinScroll:Hide()
        frame.applyBtn:Hide()
        frame.resetBtn:Hide()
        return
    end

    frame.empty:Hide()
    frame.listFrame:Show()
    frame.skinScroll:Show()
    frame.applyBtn:Show()
    frame.resetBtn:Show()

    -- Default-select the first form if nothing chosen (or selection is stale).
    if not self.selectedForm or not DC.FormModule:GetForm(self.selectedForm) then
        self.selectedForm = DC.FormModule:GetForms()[1].form
        self.previewModel = DC.FormModule:GetEffectiveModel(self.selectedForm)
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
