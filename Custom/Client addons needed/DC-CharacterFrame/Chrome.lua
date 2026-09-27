--[[
    DC-CharacterFrame / Chrome.lua
    ==============================
    Builds the retail PortraitFrame chrome on top of the stock CharacterFrame
    and re-lays the PaperDollFrame content (equipment slots, model, header).

    Frame levels (L = CharacterFrame level, P = PaperDollFrame level = L+1):
      chrome            L    outer art, drawn under everything PaperDoll owns
      inset/insetRight  P    inset boxes (marble + borders)
      modelBg           P    race backdrop + inner border around the model
      CharacterModel    P+1  stock PlayerModel, re-anchored
      slot buttons      P+1  stock buttons, re-anchored
      sidebar panes     P+1..P+3
]]

local DCCF = DCCharacterFrame
local Tex, TexH, TexV = DCCF.Tex, DCCF.TexH, DCCF.TexV

local LEFT_SLOTS   = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local RIGHT_SLOTS  = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local WEAPON_SLOTS = { "MainHand", "SecondaryHand", "Ranged" }
local ALL_SLOTS    = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
                       "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
                       "MainHand", "SecondaryHand", "Ranged", "Ammo" }
DCCF.ALL_SLOTS = ALL_SLOTS

-- Char-Paperdoll-Horizontal / -Vertical tiles: { size, coord1, coord2 }
local INNER_H_BOTTOM = { 5, 0.0625, 0.375 }
local INNER_H_TOP    = { 5, 0.5, 0.8125 }
local INNER_V_LEFT   = { 5, 0.0625, 0.375 }
local INNER_V_RIGHT  = { 5, 0.5, 0.8125 }

-- Retail SetPaperDollBackground overlay alpha per race file name.
-- Black overlay over the greyed race art, per race, derived from each background's own brightness
-- so every race lands near the same display brightness (~30/255, what Human/Dwarf had at 0.7):
-- alpha = 1 - 30 / mean. A fixed alpha buried the dark night scenes -- Night Elf showed black at 0.6.
-- Regenerate with retroport_tools/_dressup_backgrounds/tune_overlay.py when art changes.
-- Races 3.3.5 never had art for ship the retail DressUpBackground-<Race>1..4 in patch-5.
local RACE_OVERLAY = {
    HUMAN = 0.75, ORC = 0.55, DWARF = 0.75, NIGHTELF = 0, SCOURGE = 0, TAUREN = 0.65,
    GNOME = 0.65, TROLL = 0.7, BLOODELF = 0.8, DRAENEI = 0.75, GOBLIN = 0.7, WORGEN = 0.45,
    PANDAREN = 0.65, VULPERA = 0.7, ZANDALARITROLL = 0.4, KULTIRAN = 0.65, DARKIRONDWARF = 0.55,
}

-- Weapon row: 3 slots (37 wide, 5 apart) centred in the 328px inset; the
-- 27px ammo slot sits 15px right of the ranged slot when it holds ammo.
local WEAPON_ROW_X_NO_AMMO = 104
local WEAPON_ROW_X_AMMO    = 83
local WEAPON_ROW_Y         = 12

-- ---------------------------------------------------------------------------
-- Outer chrome + insets
-- ---------------------------------------------------------------------------

local function RetireStockPaperDollArt()
    local pdf = PaperDollFrame
    for _, region in ipairs({ pdf:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local path = region:GetTexture()
            if type(path) == "string" and string.find(string.lower(path), "charactertab", 1, true) then
                region:Hide()
            end
        end
    end
    for _, name in ipairs({ "CharacterAttributesFrame", "CharacterResistanceFrame", "PlayerTitleFrame",
                            "PlayerTitlePickerFrame", "GearManagerToggleButton", "GearManagerDialog" }) do
        local f = _G[name]
        if f then
            f:Hide()
            -- Stock PlayerTitleFrame_UpdateTitles re-shows the title dropdown
            -- whenever the player owns a title; titles live in the sidebar now.
            f:HookScript("OnShow", function(frame)
                frame:Hide()
            end)
        end
    end
    pdf:SetHitRectInsets(0, 0, 0, 0)
end

-- Invisible strip over the title bar: drag to move, right-click to snap back
-- to the default UIPanel slot.
function DCCF:BuildDragHandle()
    local handle = CreateFrame("Frame", "DCCharacterFrameDragHandle", CharacterFrame)
    handle:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 60, 2)
    handle:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -36, 2)
    handle:SetHeight(26)
    handle:SetFrameLevel(CharacterFrame:GetFrameLevel() + 4)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        CharacterFrame:StartMoving()
    end)
    handle:SetScript("OnDragStop", function()
        CharacterFrame:StopMovingOrSizing()
        DCCF:SavePosition()
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            DCCF:ResetPosition()
        end
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(UnitPVPName("player") or "", 1, 1, 1)
        GameTooltip:AddLine("Drag to move the panel. Right-click to reset its position.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.dragHandle = handle
end

function DCCF:BuildChrome()
    local pdf = PaperDollFrame
    local levelP = pdf:GetFrameLevel()
    local levelL = CharacterFrame:GetFrameLevel()
    local F, FH, FV = self.FRAME, self.FRAME_H, self.FRAME_V

    RetireStockPaperDollArt()

    -- Outer frame (PortraitFrameTemplate look).
    local chrome = CreateFrame("Frame", "DCCharacterFrameChrome", pdf)
    chrome:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT")
    chrome:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT")
    chrome:SetFrameLevel(levelL)
    self.chrome = chrome

    -- Strip lengths follow from the fixed retail geometry (540x424).
    local W, H = self.RETAIL_WIDTH, self.RETAIL_HEIGHT
    local ringW, ringH = F.Portrait[1], F.Portrait[2]
    local topRightW, topRightH = F.TopCornerRight[1], F.TopCornerRight[2]
    local botLeftW, botLeftH = F.BotCornerLeft[1], F.BotCornerLeft[2]
    local botRightW, botRightH = F.BotCornerRight[1], F.BotCornerRight[2]

    chrome:SetBackdrop({ bgFile = self.TEX_ROCK, tile = true, tileSize = 256,
        insets = { left = 2, right = 2, top = 21, bottom = 2 } })

    local titleBg = self.StripH(chrome, "BACKGROUND", self.TEX_FRAME_H, FH.TitleTileBG, W - 2 - 25)
    titleBg[1]:SetPoint("TOPLEFT", 2, -3)

    local ring = Tex(chrome, "OVERLAY", self.TEX_FRAME, F.Portrait)
    ring:SetPoint("TOPLEFT", -14, 11)
    local topRight = Tex(chrome, "OVERLAY", self.TEX_FRAME, F.TopCornerRight)
    topRight:SetPoint("TOPRIGHT", 0, 1)
    local titleTile = self.StripH(chrome, "OVERLAY", self.TEX_FRAME_H, FH.TitleTile,
        (W - topRightW) - (ringW - 14))
    titleTile[1]:SetPoint("TOPLEFT", ring, "TOPRIGHT", 0, -10)

    local streaks = self.StripH(chrome, "BORDER", self.TEX_FRAME_H, FH.TopTileStreaks, W - 2)
    streaks[1]:SetPoint("TOPLEFT", 0, -21)
    local botLeft = Tex(chrome, "BORDER", self.TEX_FRAME, F.BotCornerLeft)
    botLeft:SetPoint("BOTTOMLEFT", -6, -5)
    local botRight = Tex(chrome, "BORDER", self.TEX_FRAME, F.BotCornerRight)
    botRight:SetPoint("BOTTOMRIGHT", 0, -5)
    local bottom = self.StripH(chrome, "BORDER", self.TEX_FRAME_H, FH.Bot,
        (W - botRightW) - (botLeftW - 6))
    bottom[1]:SetPoint("BOTTOMLEFT", botLeft, "BOTTOMRIGHT")
    local left = self.StripV(chrome, "BORDER", self.TEX_FRAME_V, FV.LeftTile,
        (H + 5 - botLeftH) - (ringH - 11))
    left[1]:SetPoint("TOPLEFT", ring, "BOTTOMLEFT", 8, 0)
    local right = self.StripV(chrome, "BORDER", self.TEX_FRAME_V, FV.RightTile,
        (H + 5 - botRightH) - (topRightH - 1))
    right[1]:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT", 1, 0)

    local portrait = chrome:CreateTexture(nil, "ARTWORK")
    portrait:SetWidth(60)
    portrait:SetHeight(60)
    portrait:SetPoint("TOPLEFT", -6, 7)
    chrome.Portrait = portrait

    -- Left inset: model + equipment.
    local inset = CreateFrame("Frame", "DCCharacterFrameInset", pdf)
    inset:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", self.PANEL_WIDTH - 6, 4)
    inset:SetFrameLevel(levelP)
    self.AddMarble(inset)
    local panelBg = inset:CreateTexture(nil, "BACKGROUND", nil, -5)
    panelBg:SetTexture(self.TEX_PANELBG)
    panelBg:SetTexCoord(unpack(self.PANELBG_COORDS))
    panelBg:SetAllPoints(inset)
    self.AddInsetBorder(inset, "BORDER")
    self.inset = inset

    -- Right inset: sidebar panes.
    local insetRight = CreateFrame("Frame", "DCCharacterFrameInsetRight", pdf)
    insetRight:SetPoint("TOPLEFT", inset, "TOPRIGHT", 1, 0)
    insetRight:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -4, 4)
    insetRight:SetFrameLevel(levelP)
    self.AddMarble(insetRight)
    self.AddInsetBorder(insetRight, "BORDER")
    self.insetRight = insetRight

    self:BuildModelBackdrop()
    self:UpdatePortrait()
end

-- ---------------------------------------------------------------------------
-- Model backdrop (race dress-up art, desaturated, inner border)
-- ---------------------------------------------------------------------------

function DCCF:BuildModelBackdrop()
    local pdf, inset = PaperDollFrame, self.inset
    local levelP = pdf:GetFrameLevel()
    local P = self.PARTS

    local bg = CreateFrame("Frame", "DCCharacterFrameModelBackdrop", pdf)
    bg:SetPoint("TOPLEFT", inset, "TOPLEFT", 48, -6)
    bg:SetWidth(231)
    bg:SetHeight(320)
    bg:SetFrameLevel(levelP)
    self.modelBg = bg

    local tl = bg:CreateTexture(nil, "BACKGROUND")
    tl:SetPoint("TOPLEFT")
    tl:SetWidth(212)
    tl:SetHeight(245)
    tl:SetTexCoord(0.171875, 1, 0.0392156862745098, 1)
    local tr = bg:CreateTexture(nil, "BACKGROUND")
    tr:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    tr:SetWidth(19)
    tr:SetHeight(245)
    tr:SetTexCoord(0, 0.296875, 0.0392156862745098, 1)
    local bl = bg:CreateTexture(nil, "BACKGROUND")
    bl:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    bl:SetWidth(212)
    bl:SetHeight(75)
    bl:SetTexCoord(0.171875, 1, 0, 75 / 128)
    local br = bg:CreateTexture(nil, "BACKGROUND")
    br:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    br:SetWidth(19)
    br:SetHeight(75)
    br:SetTexCoord(0, 0.296875, 0, 75 / 128)
    bg.bgTextures = { tl, tr, bl, br }

    local overlay = bg:CreateTexture(nil, "BORDER")
    overlay:SetTexture(0, 0, 0, 1)
    overlay:SetAllPoints(bg)
    overlay:SetAlpha(0.7)
    bg.Overlay = overlay

    -- Inner border box around the model (anchored to the inset like retail).
    local ul = Tex(bg, "OVERLAY", self.TEX_PARTS, P.CornerUpperLeft)
    ul:SetPoint("TOPLEFT", inset, "TOPLEFT", 46, -4)
    local ur = Tex(bg, "OVERLAY", self.TEX_PARTS, P.CornerUpperRight)
    ur:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -47, -4)
    local ll = Tex(bg, "OVERLAY", self.TEX_PARTS, P.CornerLowerLeft)
    ll:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 46, 31)
    local lr = Tex(bg, "OVERLAY", self.TEX_PARTS, P.CornerLowerRight)
    lr:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -47, 31)
    local lTile = TexV(bg, "OVERLAY", self.TEX_VERT, INNER_V_LEFT)
    lTile:SetPoint("TOPLEFT", ul, "BOTTOMLEFT", -1, 0)
    lTile:SetPoint("BOTTOMLEFT", ll, "TOPLEFT", -1, 0)
    local rTile = TexV(bg, "OVERLAY", self.TEX_VERT, INNER_V_RIGHT)
    rTile:SetPoint("TOPRIGHT", ur, "BOTTOMRIGHT", 1, 0)
    rTile:SetPoint("BOTTOMRIGHT", lr, "TOPRIGHT", 1, 0)
    local tTile = TexH(bg, "OVERLAY", self.TEX_HORIZ, INNER_H_TOP)
    tTile:SetPoint("TOPLEFT", ul, "TOPRIGHT", 0, 1)
    tTile:SetPoint("TOPRIGHT", ur, "TOPLEFT", 0, 1)
    local bTile = TexH(bg, "OVERLAY", self.TEX_HORIZ, INNER_H_BOTTOM)
    bTile:SetPoint("BOTTOMLEFT", ll, "BOTTOMRIGHT", 0, -1)
    bTile:SetPoint("BOTTOMRIGHT", lr, "BOTTOMLEFT", 0, -1)
    local bTile2 = TexH(bg, "OVERLAY", self.TEX_HORIZ, INNER_H_BOTTOM)
    bTile2:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 0, 27)
    bTile2:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 27)

    -- Stock PlayerModel re-anchored over the backdrop.
    local model = CharacterModelFrame
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", bg, "TOPLEFT")
    model:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT")
    model:SetFrameLevel(levelP + 1)

    -- Drag to rotate, wheel to zoom (retail ModelScene behaviour). Rotation
    -- goes through model.rotation + SetRotation like the stock rotate buttons.
    model:EnableMouseWheel(true)
    model:HookScript("OnMouseDown", function(frame, button)
        if button == "LeftButton" then
            frame.dccfDragX = GetCursorPosition()
        end
    end)
    model:HookScript("OnMouseUp", function(frame)
        frame.dccfDragX = nil
    end)
    model:HookScript("OnHide", function(frame)
        frame.dccfDragX = nil
    end)
    model:HookScript("OnShow", function(frame)
        frame.dccfZoom = 0
    end)
    model:HookScript("OnUpdate", function(frame)
        if frame.dccfDragX then
            local x = GetCursorPosition()
            local delta = (x - frame.dccfDragX) / (UIParent:GetEffectiveScale() * 60)
            if delta ~= 0 then
                frame.rotation = (frame.rotation or 0) + delta
                frame:SetRotation(frame.rotation)
                frame.dccfDragX = x
            end
        end
    end)
    if model.SetPosition then
        model:SetScript("OnMouseWheel", function(frame, delta)
            frame.dccfZoom = math.max(-1, math.min(2.5, (frame.dccfZoom or 0) + delta * 0.2))
            frame:SetPosition(frame.dccfZoom, 0, 0)
        end)
    end

    -- Rotate buttons: small, bottom-left of the model.
    local rl, rr = CharacterModelFrameRotateLeftButton, CharacterModelFrameRotateRightButton
    rl:ClearAllPoints()
    rl:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 4, 4)
    rl:SetWidth(26)
    rl:SetHeight(26)
    rr:ClearAllPoints()
    rr:SetPoint("LEFT", rl, "RIGHT", 0, 0)
    rr:SetWidth(26)
    rr:SetHeight(26)
    rl:SetAlpha(0.6)
    rr:SetAlpha(0.6)
end

function DCCF:UpdateModelBackground()
    local bg = self.modelBg
    if not bg then
        return
    end
    local _, raceFile = UnitRace("player")
    raceFile = raceFile or "Human"
    local base = "Interface\\DressUpFrame\\DressUpBackground-" .. raceFile
    local ok = bg.bgTextures[1]:SetTexture(base .. "1")
    if not ok then
        -- Custom race without dress-up art: fall back to the faction capital look.
        local faction = UnitFactionGroup("player")
        base = "Interface\\DressUpFrame\\DressUpBackground-" .. ((faction == "Horde") and "Orc" or "Human")
    end
    for i, tex in ipairs(bg.bgTextures) do
        tex:SetTexture(base .. i)
        tex:SetDesaturated(true)
    end
    bg.Overlay:SetAlpha(RACE_OVERLAY[string.upper(raceFile)] or 0.7)
end

function DCCF:UpdatePortrait()
    if self.chrome and self.chrome.Portrait then
        SetPortraitTexture(self.chrome.Portrait, "player")
    end
    local tab = self.sidebarTabs and self.sidebarTabs[1]
    if tab and tab.isPortrait then
        SetPortraitTexture(tab.Icon, "player")
    end
end

-- ---------------------------------------------------------------------------
-- Header: level line (class coloured) + guild line in the attic
-- ---------------------------------------------------------------------------

function DCCF:UpdateHeader()
    local level = UnitLevel("player")
    local race = UnitRace("player") or ""
    local className, classFile = UnitClass("player")
    local color = classFile and RAID_CLASS_COLORS[classFile]
    local hex = "ffffff"
    if color then
        hex = string.format("%02x%02x%02x", math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5),
            math.floor(color.b * 255 + 0.5))
    end
    CharacterLevelText:SetFormattedText(PLAYER_LEVEL, level, race, "|cff" .. hex .. (className or "") .. "|r")

    local guildName, rank = GetGuildInfo("player")
    if guildName then
        CharacterGuildText:SetFormattedText(GUILD_TITLE_TEMPLATE, rank or "", guildName)
        CharacterGuildText:Show()
    else
        CharacterGuildText:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- Equipment slot layout
-- ---------------------------------------------------------------------------

local function SlotButton(key)
    return _G["Character" .. key .. "Slot"]
end

function DCCF:DecorateSlot(btn)
    if btn.dccfQuality then
        return
    end
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture(self.TEX_WHITEFRAME)
    border:SetAllPoints(btn)
    border:Hide()
    btn.dccfQuality = border
end

function DCCF:UpdateSlotOverlay(btn)
    if not btn or not btn.dccfQuality or not btn.GetID then
        return
    end
    local id = btn:GetID()
    local quality = GetInventoryItemTexture("player", id) and GetInventoryItemQuality("player", id)
    local color = quality and quality >= 2 and ITEM_QUALITY_COLORS[quality]
    if color then
        btn.dccfQuality:SetVertexColor(color.r, color.g, color.b, 1)
        btn.dccfQuality:Show()
    else
        btn.dccfQuality:Hide()
    end
    if self.UpdateSlotItemLevel then
        self:UpdateSlotItemLevel(btn)
    end
end

function DCCF:UpdateAllSlotOverlays()
    for _, key in ipairs(ALL_SLOTS) do
        local btn = SlotButton(key)
        if btn then
            self:UpdateSlotOverlay(btn)
        end
    end
end

function DCCF:UpdateWeaponRow()
    local inset = self.inset
    if not inset then
        return
    end
    local ammo = CharacterAmmoSlot
    local showAmmo = ammo and (not UnitHasRelicSlot("player")) and GetInventoryItemTexture("player", 0) ~= nil
    if ammo then
        if showAmmo then
            ammo:Show()
        else
            ammo:Hide()
        end
    end
    CharacterMainHandSlot:ClearAllPoints()
    CharacterMainHandSlot:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT",
        showAmmo and WEAPON_ROW_X_AMMO or WEAPON_ROW_X_NO_AMMO, WEAPON_ROW_Y)
end

function DCCF:LayoutPaperDoll()
    local pdf, inset = PaperDollFrame, self.inset
    local P = self.PARTS

    -- Attic text.
    CharacterLevelText:ClearAllPoints()
    CharacterLevelText:SetPoint("TOP", pdf, "TOP", 0, -25)
    CharacterLevelText:SetFontObject(GameFontNormal)
    CharacterGuildText:ClearAllPoints()
    CharacterGuildText:SetPoint("TOP", CharacterLevelText, "BOTTOM", 0, -2)

    local prev
    for i, key in ipairs(LEFT_SLOTS) do
        local btn = SlotButton(key)
        btn:ClearAllPoints()
        if i == 1 then
            btn:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -2)
        else
            btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
        end
        local art = Tex(btn, "BACKGROUND", self.TEX_PARTS, P.LeftSlot, -1)
        art:SetPoint("TOPLEFT", -4, 0)
        self:DecorateSlot(btn)
        prev = btn
    end

    for i, key in ipairs(RIGHT_SLOTS) do
        local btn = SlotButton(key)
        btn:ClearAllPoints()
        if i == 1 then
            btn:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -4, -2)
        else
            btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
        end
        local art = Tex(btn, "BACKGROUND", self.TEX_PARTS, P.RightSlot, -1)
        art:SetPoint("TOPRIGHT", 4, 0)
        self:DecorateSlot(btn)
        prev = btn
    end

    for i, key in ipairs(WEAPON_SLOTS) do
        local btn = SlotButton(key)
        btn:ClearAllPoints()
        if i > 1 then
            btn:SetPoint("LEFT", prev, "RIGHT", 5, 0)
        end
        local art = Tex(btn, "BACKGROUND", self.TEX_PARTS, P.BottomSlot, -1)
        art:SetPoint("TOPLEFT", -4, 8)
        btn.dccfFrame = art
        self:DecorateSlot(btn)
        prev = btn
    end
    local capLeft = Tex(CharacterMainHandSlot, "BACKGROUND", self.TEX_PARTS, P.SlotBottomLeft, -1)
    capLeft:SetPoint("TOPRIGHT", CharacterMainHandSlot.dccfFrame, "TOPLEFT")
    local capRight = Tex(CharacterRangedSlot, "BACKGROUND", self.TEX_PARTS, P.SlotBottomRight, -1)
    capRight:SetPoint("TOPLEFT", CharacterRangedSlot.dccfFrame, "TOPRIGHT")

    if CharacterAmmoSlot then
        CharacterAmmoSlot:ClearAllPoints()
        CharacterAmmoSlot:SetPoint("LEFT", CharacterRangedSlot, "RIGHT", 15, 0)
        self:DecorateSlot(CharacterAmmoSlot)
    end
    self:UpdateWeaponRow()

    hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
        DCCF:UpdateSlotOverlay(btn)
    end)
    self:UpdateAllSlotOverlays()
    self:UpdateModelBackground()
    self:UpdateHeader()
end
